
[![W3C](https://www.w3.org/StyleSheets/TR/2021/logos/W3C){crossorigin=""
height="48" width="72"}](https://www.w3.org/)

# MathML Core

[W3C Editor\'s Draft](https://www.w3.org/standards/types#ED) 01 October
2026

More details about this document

This version:
: [https://w3c.github.io/mathml-core/](https://w3c.github.io/mathml-core/)

Latest published version:
: <https://www.w3.org/TR/mathml-core/>

Latest editor\'s draft:
: <https://w3c.github.io/mathml-core/>

History:
: <https://www.w3.org/standards/history/mathml-core/>
: [Commit history](https://github.com/w3c/mathml-core/commits/)

Test suite:
: <https://github.com/web-platform-tests/wpt/tree/master/mathml/>

Implementation report:
: <https://wpt.fyi/results/?label=master&label=experimental&aligned&q=feature%3Amathml>

Editors:
: [David Carlisle](https://github.com/davidcarlisle) ([NAG])
: [Frédéric Wang](https://frederic-wang.fr)
 ([Igalia])

Former editors:
: [Patrick Ion](http://www-personal.umich.edu/~pion/) ([Mathematical Reviews, American Mathematical
 Society])
: [Robert Miner (deceased)] ([Design Science,
 Inc.])

Feedback:
: [GitHub w3c/mathml-core](https://github.com/w3c/mathml-core/) ([pull
 requests](https://github.com/w3c/mathml-core/pulls/), [new
 issue](https://github.com/w3c/mathml-core/issues/new/choose), [open
 issues](https://github.com/w3c/mathml-core/issues/))

[Copyright](https://www.w3.org/policies/#copyright) © 2026 [World Wide
Web Consortium](https://www.w3.org/). [W3C]^®^
[liability](https://www.w3.org/policies/#Legal_Disclaimer),
[trademark](https://www.w3.org/policies/#W3C_Trademarks) and [permissive
document
license](https://www.w3.org/copyright/software-license-2023/ "W3C Software and Document Notice and License"){rel="license"}
rules apply.

------------------------------------------------------------------------

## Abstract

This specification defines a core subset of Mathematical Markup
Language, or MathML, that is suitable for browser implementation. MathML
is a markup language for describing mathematical notation and capturing
both its structure and content. The goal of MathML is to enable
mathematics to be served, received, and processed on the World Wide Web,
just as HTML has enabled this functionality for text.

## Status of This Document

*This section describes the status of this document at the time of its
publication. A list of current [W3C] publications and the latest revision
of this technical report can be found in the [[W3C] standards and drafts
index](https://www.w3.org/TR/).*

This document was published by the [Math Working
Group](https://www.w3.org/groups/wg/math) as an Editor\'s Draft.

Publication as an Editor\'s Draft does not imply endorsement by
[W3C] and its Members.

This is a draft document and may be updated, replaced, or obsoleted by
other documents at any time. It is inappropriate to cite this document
as other than a work in progress.

This document was produced by a group operating under the [[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/). [W3C] maintains a [public list of any
patent
disclosures](https://www.w3.org/groups/wg/math/ipr){rel="disclosure"}
made in connection with the deliverables of the group; that page also
includes instructions for disclosing a patent. An individual who has
actual knowledge of a patent that the individual believes contains
[Essential
Claim(s)](https://www.w3.org/policies/patent-policy/#def-essential) must
disclose the information in accordance with [section 6 of the
[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/#sec-Disclosure).

This document is governed by the [18 August 2025 [W3C] Process
Document](https://www.w3.org/policies/process/20250818/).

## Table of Contents

1. [Abstract](#abstract)
2. [Status of This Document](#sotd)
3. [1. Introduction](#introduction)
4. [2. MathML Fundamentals](#mathml-fundamentals)
 1. [2.1 Elements and
 attributes](#mathml-elements-and-attributes)
 1. [2.1.1 The Top-Level `<math>`
 Element](#the-top-level-math-element)
 2. [2.1.2 Types for MathML Attribute
 Values](#types-for-mathml-attribute-values)
 3. [2.1.3 Global Attributes](#global-attributes)
 4. [2.1.4 Attributes common to HTML and MathML
 elements](#attributes-common-to-html-and-mathml-elements)
 5. [2.1.5 Legacy MathML Style
 Attributes](#legacy-mathml-style-attributes)
 6. [2.1.6 The `displaystyle` and `scriptlevel`
 attributes](#the-displaystyle-and-scriptlevel-attributes)
 7. [2.1.7 Attributes Reserved as
 Valid](#other-valid-attributes)
 2. [2.2 Integration in the Web
 Platform](#integration-in-the-web-platform)
 1. [2.2.1 HTML and SVG](#html-and-svg)
 2. [2.2.2 CSS styling](#css-styling)
 3. [2.2.3 DOM and JavaScript](#dom-and-javascript)
 4. [2.2.4 Text layout](#text-layout)
 5. [2.2.5 Focus](#focus)
5. [3. Presentation Markup](#presentation-markup)
 1. [3.1 Visual formatting
 model](#visual-formatting-model)
 1. [3.1.1 Box Model](#box-model)
 2. [3.1.2 Layout Algorithms](#layout-algorithms)
 3. [3.1.3 Anonymous \<mrow\>
 boxes](#anonymous-mrow-boxes)
 4. [3.1.4 Stacking contexts](#stacking-contexts)
 2. [3.2 Token Elements](#token-elements)
 1. [3.2.1 Text `<mtext>`](#text-mtext)
 1. [3.2.1.1 Layout of
 `<mtext>`](#layout-of-mtext)
 2. [3.2.2 Identifier `<mi>`](#the-mi-element)
 3. [3.2.3 Number `<mn>`](#number-mn)
 4. [3.2.4 Operator, Fence, Separator or Accent
 `<mo>`](#operator-fence-separator-or-accent-mo)
 1. [3.2.4.1 Embellished
 operators](#embellished-operators)
 2. [3.2.4.2 Dictionary-based
 attributes](#dictionary-based-attributes)
 3. [3.2.4.3 Layout of
 operators](#layout-of-operators)
 5. [3.2.5 Space `<mspace>`](#space-mspace)
 1. [3.2.5.1 Definition of space-like
 elements](#definition-of-space-like-elements)
 6. [3.2.6 String Literal `<ms>`](#string-literal-ms)
 3. [3.3 General Layout
 Schemata](#general-layout-schemata)
 1. [3.3.1 Group Sub-Expressions
 `<mrow>`](#horizontally-group-sub-expressions-mrow)
 1. [3.3.1.1 Algorithm for stretching operators along the
 block
 axis](#algorithm-for-stretching-operators-along-the-block-axis)
 2. [3.3.1.2 Layout of `<mrow>`](#layout-of-mrow)
 2. [3.3.2 Fractions `<mfrac>`](#fractions-mfrac)
 1. [3.3.2.1 Fraction with nonzero line
 thickness](#fraction-with-nonzero-line-thickness)
 2. [3.3.2.2 Fraction with zero line
 thickness](#fraction-with-zero-line-thickness)
 3. [3.3.3 Radicals `<msqrt>`,
 `<mroot>`](#radicals-msqrt-mroot)
 1. [3.3.3.1 Radical symbol](#radical-symbol)
 2. [3.3.3.2 Square root](#square-root)
 3. [3.3.3.3 Root with index](#root-with-index)
 4. [3.3.4 Style Change
 `<mstyle>`](#style-change-mstyle)
 5. [3.3.5 Error Message
 `<merror>`](#error-message-merror)
 6. [3.3.6 Adjust Space Around Content
 `<mpadded>`](#adjust-space-around-content-mpadded)
 1. [3.3.6.1 Inner box and requested
 parameters](#inner-box-and-requested-parameters)
 2. [3.3.6.2 Layout of
 `<mpadded>`](#layout-of-mpadded)
 7. [3.3.7 Making Sub-Expressions Invisible
 `<mphantom>`](#making-sub-expressions-invisible-mphantom)
 4. [3.4 Script and Limit
 Schemata](#script-and-limit-schemata)
 1. [3.4.1 Subscripts and Superscripts `<msub>`, `<msup>`,
 `<msubsup>`](#subscripts-and-superscripts-msub-msup-msubsup)
 1. [3.4.1.1 Children of `<msub>`, `<msup>`,
 `<msubsup>`](#children-of-msub-msup-msubsup)
 2. [3.4.1.2 Base with
 subscript](#base-with-subscript)
 3. [3.4.1.3 Base with
 superscript](#base-with-superscript)
 4. [3.4.1.4 Base with subscript and
 superscript](#base-with-subscript-and-superscript)
 2. [3.4.2 Underscripts and Overscripts `<munder>`, `<mover>`,
 `<munderover>`](#underscripts-and-overscripts-munder-mover-munderover)
 1. [3.4.2.1 Children of `<munder>`, `<mover>`,
 `<munderover>`](#children-of-munder-mover-munderover)
 2. [3.4.2.2 Algorithm for stretching operators along the
 inline
 axis](#algorithm-for-stretching-operators-along-the-inline-axis)
 3. [3.4.2.3 Base with
 underscript](#base-with-underscript)
 4. [3.4.2.4 Base with
 overscript](#base-with-overscript)
 5. [3.4.2.5 Base with underscript and
 overscript](#base-with-underscript-and-overscript)
 3. [3.4.3 Prescripts and Tensor Indices
 `<mmultiscripts>`](#prescripts-and-tensor-indices-mmultiscripts)
 1. [3.4.3.1 Base with prescripts and
 postscripts](#base-with-prescripts-and-postscripts)
 4. [3.4.4 Displaystyle, scriptlevel and math-shift in
 scripts](#displaystyle-and-scriptlevel-in-scripts)
 5. [3.5 Tabular Math](#tabular-math)
 1. [3.5.1 Table or Matrix
 `<mtable>`](#table-or-matrix-mtable)
 2. [3.5.2 Row in Table or Matrix
 `<mtr>`](#row-in-table-or-matrix-mtr)
 3. [3.5.3 Entry in Table or Matrix
 `<mtd>`](#entry-in-table-or-matrix-mtd)
 6. [3.6 Linking `<a>`](#the-a-element)
 7. [3.7 Enlivening Expressions](#enlivening-expressions)
 8. [3.8 Semantics and
 Presentation](#semantics-and-presentation)
6. [4. CSS Extensions for Math
 Layout](#css-extensions-for-math-layout)
 1. [4.1 The `display: block math` and `display: inline math`
 value](#new-display-math-value)
 2. [4.2 The `math-auto` transform](#math-auto-transform)
 3. [4.3 The `math-style`
 property](#the-math-style-property)
 4. [4.4 The `math-shift` property](#the-math-shift)
 5. [4.5 The `math-depth`
 property](#the-math-script-level-property)
7. [5. OpenType `MATH` table](#opentype-math-table)
 1. [5.1 Layout constants
 (`MathConstants`)](#layout-constants-mathconstants)
 2. [5.2 Glyph information
 (`MathGlyphInfo`)](#glyph-information-mathglyphinfo)
 3. [5.3 Size variants for operators
 (`MathVariants`)](#size-variants-for-operators-mathvariants)
 1. [5.3.1 The `GlyphAssembly`
 table](#the-glyphassembly-table)
 2. [5.3.2 Algorithms for glyph
 stretching](#algorithms-for-glyph-stretching)
8. [A. User Agent Stylesheet](#user-agent-stylesheet)
9. [B. Operator Tables](#operator-tables)
 1. [B.1 Operator Dictionary](#operator-dictionary)
 2. [B.2 Operator Dictionary
 (human-readable)](#operator-dictionary-human)
 3. [B.3 Combining Character
 Equivalences](#combining-character-equivalences)
 4. [B.4 Unicode-based Glyph
 Assemblies](#unicode-based-glyph-assemblies)
10. [C. Mathematical Alphanumeric
 Symbols](#new-text-transform-mappings)
 1. [C.1 `italic` mappings](#italic-mappings)
11. [D. Acknowledgments](#acknowledgments)
12. [E. Security Considerations](#security-considerations)
13. [F. Privacy Considerations](#privacy-considerations)
14. [G. Conformance](#conformance)
15. [H. References](#references)
 1. [H.1 Normative references](#normative-references)
 2. [H.2 Informative references](#informative-references)

::: header-wrapper
## 1. Introduction

*This section is non-normative.*

The
\[[MATHML3](#bib-mathml3 "Mathematical Markup Language (MathML) Version 3.0 2nd Edition")\] specification has several shortcomings that make
it hard to implement consistently across web rendering engines or to
extend with user-defined constructions, e.g.:

- It is a huge and standalone specification.
- It does not contain any detailed rendering rules.
- It is not driven by browser-implementation.
- It lacks automated testing.

This MathML Core specification intends to address these issues by being
as accurate as possible on the visual rendering of mathematical formulas
using additional rules from the TeXBook's Appendix G
\[[TEXBOOK](#bib-texbook "The TeXBook")\]
and from the Open Font Format
\[[OPEN-FONT-FORMAT](#bib-open-font-format "Information technology — Coding of audio-visual objects — Part 22: Open Font Format")\],
\[[OPEN-TYPE-MATH-ILLUMINATED](#bib-open-type-math-illuminated "OpenType Math Illuminated")\]. It also relies on modern browser implementations
and web technologies \[[HTML](#bib-html "HTML Standard")\]
\[[SVG](#bib-svg "Scalable Vector Graphics (SVG) 1.0 Specification")\]
\[[CSS2](#bib-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")\] \[[DOM](#bib-dom "DOM Standard")\], clarifying interactions with them when needed or
introducing new low-level primitives to improve the web platform
layering.

Parts of MathML3 that do not fit well in this framework or are less
fundamental have been omitted. Instead, they are described in a separate
and larger
\[[MATHML4](#bib-mathml4 "Mathematical Markup Language (MathML) Version 4.0")\] specification. The details of which math feature
will be included in future versions of MathML Core or implemented as
polyfills is still open. This question and other potential improvements
are [tracked on
GitHub](https://github.com/w3c/mathml/issues?q=is%3Aissue+is%3Aopen+label%3A%22MathML+Core%22).

By increasing the level of implementation details, focusing on a
workable subset, following a browser-driven design and relying on
automated web platform tests, this specification is expected to greatly
improve MathML interoperability. Moreover, effort on MathML layering
will enable users to implement the rest of the MathML 4 specification,
or more generally to extend MathML Core, using modern web technologies
such as [shadow
trees](https://dom.spec.whatwg.org/#concept-shadow-tree),
[custom
elements](https://html.spec.whatwg.org/multipage/custom-elements.html#custom-element)
or APIs from
\[[HOUDINI](#bib-houdini "CSS-TAG Houdini Editor Drafts")\].

::: header-wrapper
## 2. MathML Fundamentals

::: header-wrapper
### 2.1 Elements and attributes

The term [MathML element] refers to any element in the [MathML
namespace](https://infra.spec.whatwg.org/#mathml-namespace).
The MathML elements defined in this specification are called the [MathML
Core elements] and are listed below. Any MathML element that is not
listed below is called an [Unknown MathML
element].

1. [`a`](#dfn-a)
2. [`annotation`](#dfn-annotation)
3. [`annotation-xml`](#dfn-annotation-xml)
4. [`maction`](#dfn-maction)
5. [`math`](#dfn-math)
6. [`merror`](#dfn-merror)
7. [`mfrac`](#dfn-mfrac)
8. [`mi`](#dfn-mi)
9. [`mmultiscripts`](#dfn-mmultiscripts)
10. [`mn`](#dfn-mn)
11. [`mo`](#dfn-mo)
12. [`mover`](#dfn-mover)
13. [`mpadded`](#dfn-mpadded)
14. [`mphantom`](#dfn-mphantom)
15. [`mprescripts`](#dfn-mprescripts)
16. [`mroot`](#dfn-mroot)
17. [`mrow`](#dfn-mrow)
18. [`ms`](#dfn-ms)
19. [`mspace`](#dfn-mspace)
20. [`msqrt`](#dfn-msqrt)
21. [`mstyle`](#dfn-mstyle)
22. [`msub`](#dfn-msub)
23. [`msubsup`](#dfn-msubsup)
24. [`msup`](#dfn-msup)
25. [`mtable`](#dfn-mtable)
26. [`mtd`](#dfn-mtd)
27. [`mtext`](#dfn-mtext)
28. [`mtr`](#dfn-mtr)
29. [`munder`](#dfn-munder)
30. [`munderover`](#dfn-munderover)
31. [`semantics`](#dfn-semantics)

The [grouping elements] are [`a`](#dfn-a), [`maction`](#dfn-maction),
[`math`](#dfn-math), [`merror`](#dfn-merror),
[`mphantom`](#dfn-mphantom),
[`mprescripts`](#dfn-mprescripts),
[`mrow`](#dfn-mrow), [`mstyle`](#dfn-mstyle),
[`semantics`](#dfn-semantics) and [unknown MathML
elements](#dfn-unknown-mathml-element).

The [scripted elements] are
[`mmultiscripts`](#dfn-mmultiscripts),
[`mover`](#dfn-mover), [`msub`](#dfn-msub),
[`msubsup`](#dfn-msubsup), [`msup`](#dfn-msup),
[`munder`](#dfn-munder) and
[`munderover`](#dfn-munderover).

The [radical elements] are
[`mroot`](#dfn-mroot) and [`msqrt`](#dfn-msqrt).

The attributes defined in this specification have no namespace and are
called [MathML attributes]:

- [Global attributes](#global-attributes)
- [Legacy `maction` attributes](#legacy-maction-attributes)
- [`mo` attributes](#mo-attributes)
- [`mpadded` attributes](#mpadded-attributes)
- [`mspace` attributes](#mspace-attributes)
- [`munderover` attributes](#munderover-attributes)
- [`mtd` attributes](#mtd-attributes)
- [`encoding`](#dfn-encoding)
- [`display`](#dfn-display)
- [`linethickness`](#dfn-linethickness)

::: header-wrapper
#### 2.1.1 The Top-Level `<math>` Element

MathML specifies a single top-level or root [math] element, which encapsulates each instance of MathML markup
within a document. All other MathML content must be contained in a
`<math>` element.

The `<math>` element accepts the attributes described in [2.1.3 Global
Attributes](#global-attributes) as well as the following
attributes:

- [`display`](#dfn-display)
- [`alttext`](#dfn-alttext)

The [display]
attribute, if present, must be an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
match to `block` or `inline`. The user agent stylesheet described in [A.
User Agent Stylesheet](#user-agent-stylesheet) contains rules
for this attribute that affect the default values for the
[`display`](#dfn-display) (`block math` or `inline math`) and
[`math-style`](#propdef-math-style) (`normal` or `compact`) properties. If the
`display` attribute is absent or has an invalid value, the User Agent
stylesheet treats it the same as `inline`.

This specification does not define any observable behavior that is
specific to the [alttext]
attribute.

The [`alttext`](#dfn-alttext) attribute may be used as alternative text by
some legacy systems that do not implement math layout.

If the `<math>` element does not have its computed
[`display`](#dfn-display) property equal to `block math` or
`inline math` then it is laid out according to the CSS specification
where the corresponding value is described. Otherwise the layout
algorithm of the [`mrow`](#dfn-mrow) element is used to produce a [math content
box](#dfn-math-content-box). That [math content
box](#dfn-math-content-box) is used as the content for the layout of the element,
as described by CSS for `display: block` (if the computed value is
`block math`) or `display: inline` (if the computed value is
`inline math`). Additionally, if the computed
[`display`](#dfn-display) property is equal to `block math` then that
[math content
box](#dfn-math-content-box) is rendered horizontally centered within the content
box.

T~E~X\'s display mode `$$...$$` and inline mode `$...$` correspond to
`display="block"` and `display="inline"` respectively.

In the following example, a [`math`](#dfn-math) formula is rendered in display mode on
a new line and taking full width, with the math content centered within
the container:

``` {aria-busy="false"}
<div style="width: 15em;">
 This mathematical formula with a big summation and the number pi
 <math display="block" style="border: 1px dotted black;">
 <mrow>
 <munderover>
 <mo>∑</mo>
 <mrow><mi>n</mi><mo>=</mo><mn>1</mn></mrow>
 <mrow><mo>+</mo><mn>∞</mn></mrow>
 </munderover>
 <mfrac>
 <mn>1</mn>
 <msup><mi>n</mi><mn>2</mn></msup>
 </mfrac>
 </mrow>
 <mo>=</mo>
 <mfrac>
 <msup><mi>π</mi><mn>2</mn></msup>
 <mn>6</mn>
 </mfrac>
 </math>
 is easy to prove.
</div>
```

![math example (display)](examples/example-math-display-block.png)

As a comparison, the same formula would look as follows in inline mode.
The formula is embedded in the paragraph of text without forced line
breaking. The baselines specified by the layout algorithm of the
[`mrow`](#dfn-mrow) are used for vertical alignment. Note that the
middle of sum and equal symbols or fractions are all aligned, but not
with the alphabetical baseline of the surrounding text.

![math example (inline)](examples/example-math-display-inline.png)

Because good mathematical rendering requires use of mathematical fonts,
the [user agent
stylesheet](#dfn-user-agent-stylesheet) should set the
[font-family](https://www.w3.org/TR/css-fonts-4/#propdef-font-family)
to the
[math](https://www.w3.org/TR/css-fonts-4/#valdef-font-family-math)
value on the `<math>` element instead of inheriting it. Additionally,
several CSS properties that can be set on a parent container such as
`font-style`, `font-weight`, `direction` or `text-indent` etc are not
expected to apply to the math formula and so the [user agent
stylesheet](#dfn-user-agent-stylesheet) has rules to reset them by default.

``` {aria-busy="false"}
math {
 direction: ltr;
 text-indent: 0;
 letter-spacing: normal;
 line-height: normal;
 word-spacing: normal;
 font-family: math;
 font-size: inherit;
 font-style: normal;
 font-weight: normal;
 display: inline math;
 math-shift: normal;
 math-style: compact;
 math-depth: 0;
}
math[display="block" i] {
 display: block math;
 math-style: normal;
}
math[display="inline" i] {
 display: inline math;
 math-style: compact;
}
```

::: header-wrapper
#### 2.1.2 Types for MathML Attribute Values

In addition to CSS data types, some MathML attributes rely on the
following MathML-specific types:

[unsigned-integer]
: An [\<integer\>](https://www.w3.org/TR/css-values-4/#integer-value)
 value as defined in
 \[[CSS-VALUES-4](#bib-css-values-4 "CSS Values and Units Module Level 4")\], whose first character is neither U+002D
 HYPHEN-MINUS character (-) nor U+002B PLUS SIGN (+).

[boolean]
: A string that is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
 match to `true` or `false`.

::: header-wrapper
#### 2.1.3 Global Attributes

The following attributes are common to and may be specified on all
MathML elements:

- [`autofocus`](#dfn-autofocus)
- [`class`](#dfn-class)
- [`data-*`](#dfn-data)
- [`dir`](#dfn-dir)
- [`displaystyle`](#dfn-displaystyle)
- [`id`](#dfn-id)
- [`mathbackground`](#dfn-mathbackground)
- [`mathcolor`](#dfn-mathcolor)
- [`mathsize`](#dfn-mathsize)
- [`nonce`](#dfn-nonce)
- [`scriptlevel`](#dfn-scriptlevel)
- [`style`](#dfn-style)
- [`tabindex`](#dfn-tabindex)
- [`on*` event handler attributes](#event-handler-content-attributes)
- additional attributes, as described in [2.1.7 Attributes Reserved as
 Valid](#other-valid-attributes)

::: header-wrapper
#### 2.1.4 Attributes common to HTML and MathML elements

The [id], [class], [style], [`data-*`], [autofocus] and [nonce] and [tabindex] attributes have the same syntax and semantics as
defined for [`id`](#dfn-id), [`class`](#dfn-class),
[`style`](#dfn-style),
[data-\*](https://html.spec.whatwg.org/#embedding-custom-non-visible-data-with-the-data-*-attributes),
[`autofocus`](#dfn-autofocus), [`nonce`](#dfn-nonce) and
[`tabindex`](#dfn-tabindex) attributes on HTML elements.

The [dir] attribute, if present,
must be an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
match to `ltr` or `rtl`. In that case, the user agent is expected to
treat the attribute as a [presentational
hint](https://html.spec.whatwg.org/#presentational-hints) setting the
element\'s
[direction](https://www.w3.org/TR/css-writing-modes-4/#propdef-direction)
property to the corresponding value. More precisely, an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
match to `rtl` is mapped to `rtl` while an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
match to `ltr` is mapped to `ltr`.

The [dir](#dfn-dir)
attribute is used to set the directionality of math formulas, which is
often `rtl` in Arabic speaking world. However, languages written from
right to left often embed math written from left to right and so the
[user agent
stylesheet](#dfn-user-agent-stylesheet) resets the
[direction](https://www.w3.org/TR/css-writing-modes-4/#propdef-direction)
property accordingly on the [`math`](#dfn-math) elements.

In the following example, the [dir](#dfn-dir) attribute is used to render \"𞸎 plus 𞸑
raised to the power of (٢ over, 𞸟 plus ١)\" from right-to-left.

``` {aria-busy="false"}
<math dir="rtl">
 <mrow>
 <mi>𞸎</mi>
 <mo>+</mo>
 <msup>
 <mi>𞸑</mi>
 <mfrac>
 <mn>٢</mn>
 <mrow>
 <mi>𞸟</mi>
 <mo>+</mo>
 <mn>١</mn>
 </mrow>
 </mfrac>
 </msup>
 </mrow>
</math>
```

![dir example](examples/example-dir.png)

All MathML elements support event handler content attributes, as
described in [event handler content
attributes](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-content-attributes)
in HTML.

All event handler content attributes [noted by HTML as being supported
by all
HTMLElements](https://html.spec.whatwg.org/#event-handlers-on-elements,-document-objects,-and-window-objects)
are supported by all MathML elements as well, as defined in the
[MathMLElement IDL](#dom-and-javascript).

::: header-wrapper
#### 2.1.5 Legacy MathML Style Attributes

The [mathcolor]
and [mathbackground]
attributes, if present, must have a value that is a
[\<color\>](https://www.w3.org/TR/css-color-4/#propdef-color). In that
case, the user agent is expected to treat these attributes as a
[presentational
hint](https://html.spec.whatwg.org/#presentational-hints) setting the
element\'s
[color](https://www.w3.org/TR/css-color-4/#propdef-color)
and
[background-color](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-color)
properties to the corresponding values. The `mathcolor` attribute
describes the foreground fill color of MathML text, bars etc while the
`mathbackground` attribute describes the background color of an element.

The [mathsize] attribute, if present,
must have a value that is a valid
[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage).
In that case, the user agent is expected to treat the attribute as a
[presentational
hint](https://html.spec.whatwg.org/#presentational-hints) setting the
element\'s
[font-size](https://www.w3.org/TR/css-fonts-4/#propdef-font-size)
property to the corresponding value. The `mathsize` property indicates
the desired height of glyphs in math formulas but also scales other
parts (spacing, shifts, line thickness of bars etc) accordingly.

The above attributes are implemented for compatibility with full MathML.
Authors whose only target is MathML Core are encouraged to use CSS for
styling.

::: header-wrapper
#### 2.1.6 The `displaystyle` and `scriptlevel` attributes

The [displaystyle]
attribute, if present, must have a value that is a
[boolean](#dfn-boolean). In that case, the user agent is expected to treat the
attribute as a [presentational
hint](https://html.spec.whatwg.org/#presentational-hints) setting the
element\'s
[`math-style`](#propdef-math-style) property to the corresponding value. More
precisely, an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
match to `true` is mapped to `normal` while an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
match to `false` is mapped to `compact`. This attribute indicates
whether formulas should try to minimize the logical height (value is
`false`) or not (value is `true`) e.g. by changing the size of content
or the layout of scripts.

The [scriptlevel]
attribute, if present, must have value `+<U>`, `-<U>` or `<U>` where
`<U>` is an
[unsigned-integer](#dfn-unsigned-integer). In that case the user agent is expected
to treat the `scriptlevel` attribute as a [presentational
hint](https://html.spec.whatwg.org/#presentational-hints) setting the
element\'s
[`math-depth`](#propdef-math-depth) property to the corresponding value. More
precisely, `+<U>`, `-<U>` and `<U>` are respectively mapped to
`add(<U>)` `add(<-U>)` and `<U>`.

[`displaystyle`](#dfn-displaystyle) and
[`scriptlevel`](#dfn-scriptlevel) values are automatically adjusted within
MathML elements. To fully implement these attributes, additional CSS
properties must be specified in the user agent stylesheet as described
in [A. User Agent Stylesheet](#user-agent-stylesheet). In
particular, for all MathML elements a default `font-size: math` is
specified to ensure that `scriptlevel` changes are taken into account.

In this example, an [`munder`](#dfn-munder) element is used to attach a script
\"A\" to a base \"∑\". By default, the summation symbol is rendered with
the font-size inherited from its parent and the A as a scaled down
subscript. If
[displaystyle](#dfn-displaystyle) is true, the summation symbol is drawn
bigger and the \"A\" becomes an underscript. If
[scriptlevel](#dfn-scriptlevel) is reset to 0 on the \"A\", then it will use the same
font-size as the top-level `math` root.

``` {aria-busy="false"}
<math>
 <munder>
 <mo>∑</mo>
 <mi>A</mi>
 </munder>
 <munder displaystyle="true">
 <mo>∑</mo>
 <mi>A</mi>
 </munder>
 <munder>
 <mo>∑</mo>
 <mi script>A</mi>
 </munder>
</math>
```

![displaystyle-scriptlevel
example](examples/example-displaystyle-scriptlevel.png)

T~E~X\'s `\displaystyle`, `\textstyle`, `\scriptstyle`, and
`\scriptscriptstyle` correspond to
[`displaystyle`](#dfn-displaystyle) and
[`scriptlevel`](#dfn-scriptlevel) as `true` and `0`, `false` and `0`,
`false` and `1`, and `false` and 2, respectively.

::: header-wrapper
#### 2.1.7 Attributes Reserved as Valid

The attributes [intent]
and [arg] are reserved as valid
attributes.

This specification does not define any observable behavior that is
specific to the [`intent`](#dfn-intent) and [`arg`](#dfn-arg) attributes.

These attributes are described in
\[[MATHML4](#bib-mathml4 "Mathematical Markup Language (MathML) Version 4.0")\] and future versions of this specification may or
may not define them. Authors should be aware that they are currently in
development and subject to change.

::: header-wrapper
### 2.2 Integration in the Web Platform

::: header-wrapper
#### 2.2.1 HTML and SVG

MathML can be mixed with HTML and SVG as described in the relevant
specifications \[[HTML](#bib-html "HTML Standard")\]
\[[SVG](#bib-svg "Scalable Vector Graphics (SVG) 1.0 Specification")\].

When evaluating the SVG
[requiredExtensions](https://www.w3.org/TR/SVG/#RequiredExtensionsAttribute%22)
attribute, user agents must claim support for the language extension
identified by the [MathML
namespace](https://infra.spec.whatwg.org/#mathml-namespace).

In this example, inline MathML and SVG elements are used inside an HTML
document. SVG elements `<switch>` and `<foreignObject>` (with proper
`<requiredExtensions>`) are used to embed a MathML formula with a text
fallback, inside a diagram. HTML `input` element is used within the
[`mtext`](#dfn-mtext) to include an interactive input field inside a
mathematical formula. See also [3.8 Semantics and
Presentation](#semantics-and-presentation) for an example of
SVG and HTML inside an
[`annotation-xml`](#dfn-annotation-xml) element.

``` {aria-busy="false"}
<svg style="font-size: 20px" width="400px" height="220px" viewBox="0 0 200 110">
 <g transform="translate(10,80)">
 <path d="M 0 0 L 150 0 A 75 75 0 0 0 0 0
 M 30 0 L 30 -60 M 30 -10 L 40 -10 L 40 0"
 fill="none" stroke="black"></path>
 <text transform="translate(10,20)">1</text>
 <switch transform="translate(35,-40)">
 <foreignObject width="200" height="50"
 requiredExtensions="http://www.w3.org/1998/Math/MathML">
 <math>
 <msqrt>
 <mn>2</mn>
 <mi>r</mi>
 <mo>−</mo>
 <mn>1</mn>
 </msqrt>
 </math>
 </foreignObject>
 <text>\sqrt{2r - 1}</text>
 </switch>
 </g>
</svg>

<p>
 Fill the blank:
 <math>
 <msqrt>
 <mn>2</mn>
 <mtext><input onchange="..." size="2" type="text"></mtext>
 <mo>−</mo>
 <mn>1</mn>
 </msqrt>
 <mo>=</mo>
 <mn>3</mn>
 </math>
</p>
```

![html-svg example](examples/example-html-svg.png)

::: header-wrapper
#### 2.2.2 CSS styling

User agents must support various CSS features mentioned in this
specification, including new ones described in [4. CSS Extensions for
Math Layout](#css-extensions-for-math-layout). They must
follow the computation rule for [display:
contents](https://www.w3.org/TR/css-display-3/#unbox-mathml).

In this example, the MathML formula inherits the CSS color of its parent
and uses the `font-family` specified via the
[style](#dfn-style)
attribute.

``` {aria-busy="false"}
<div style="width: 15em; color: blue">
 This mathematical formula with a big summation and the number pi
 <math display="block" style="font-family: STIX Two Math">
 <mrow>
 <munderover>
 <mo>∑</mo>
 <mrow><mi>n</mi><mo>=</mo><mn>1</mn></mrow>
 <mrow><mo>+</mo><mn>∞</mn></mrow>
 </munderover>
 <mfrac>
 <mn>1</mn>
 <msup><mi>n</mi><mn>2</mn></msup>
 </mfrac>
 </mrow>
 <mo>=</mo>
 <mfrac>
 <msup><mi>π</mi><mn>2</mn></msup>
 <mn>6</mn>
 </mfrac>
 </math>
 is easy to prove.
</div>
```

![style example](examples/example-style.png)

All documents containing [MathML Core
elements](#dfn-mathml-core-elements) must include CSS rules described in [A.
User Agent Stylesheet](#user-agent-stylesheet) as part of
user-agent level style sheet defaults. In particular, this adds
`!important` rules to force [writing
mode](https://www.w3.org/TR/css-writing-modes-4/#writing-mode)
to `horizontal-lr` on all MathML elements.

The [float](https://www.w3.org/TR/CSS22/visuren.html#float-position)
property does not create floating of elements whose parent\'s computed
`display` value is `block math` or `inline math`, and does not take them
out-of-flow.

The
[::first-line](https://www.w3.org/TR/css-pseudo-4/#selectordef-first-line)
and
[::first-letter](https://www.w3.org/TR/css-pseudo-4/#selectordef-first-letter)
pseudo-elements do not apply to elements whose computed `display` value
is `block math` or `inline math`, and such elements do not contribute a
first formatted line or first letter to their ancestors.

The following CSS features are not supported and must be ignored:

- Line breaking inside math formulas: `white-space` is treated as
 `nowrap` on all MathML elements.
- Alignment properties: `align-content`, `justify-content`,
 `align-self`, `justify-self` have no effects on MathML elements.

These features might be handled in future versions of this document. For
now, authors are discouraged from setting a different value for these
properties as that might lead to backward incompatibility issues.

::: header-wrapper
#### 2.2.3 DOM and JavaScript

User agents supporting [Web application
APIs](https://html.spec.whatwg.org/#webappapis) must ensure that they
keep the visual rendering of MathML synchronized with the
\[[DOM](#bib-dom "DOM Standard")\] tree, in
particular perform necessary updates when [MathML
attributes](#dfn-mathml-attributes) are modified dynamically.

All the nodes representing [MathML
elements](#dfn-mathml-element) in the DOM must implement, and expose to
scripts, the following [`MathMLElement`] interface, unless otherwise specified.

```
WebIDL[Exposed=Window]
interface MathMLElement : Element ;
MathMLElement includes GlobalEventHandlers;
MathMLElement includes HTMLOrSVGOrMathMLElement;
```

The
[`GlobalEventHandlers`](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers) and
[[`HTMLOrSVGOrMathMLElement`](https://html.spec.whatwg.org/#htmlorsvgelement)] interfaces are
defined in \[[HTML](#bib-html "HTML Standard")\].

The
[`style`](https://www.w3.org/TR/cssom-1/#dom-elementcssinlinestyle-style)
IDL attribute is defined in
\[[CSSOM](#bib-cssom "CSS Object Model (CSSOM)")\].

In the following example, a MathML formula is used to render the
fraction \"α over 2\". When clicking the red α, it is changed into a
blue β.

``` {aria-busy="false"}
<script>
 function ModifyMath(mi) {
 mi.style.color = 'blue';
 mi.textContent = 'β';
 }
</script>
<math>
 <mrow>
 <mfrac>
 <mi style="color: red" onclick="ModifyMath(this)">α</mi>
 <mn>2</mn>
 </mfrac>
 </mrow>
</math>
```

![dom-idl example](examples/example-dom-idl.png)

::: header-wrapper
#### 2.2.4 Text layout

Because math fonts generally contain very tall glyphs such as big
integrals, using typographic metrics is important to avoid excessive
line spacing of text. As a consequence, user agents must take into
account the USE_TYPO_METRICS flag from the OS/2 table
\[[OPEN-FONT-FORMAT](#bib-open-font-format "Information technology — Coding of audio-visual objects — Part 22: Open Font Format")\] when performing text layout.

::: header-wrapper
#### 2.2.5 Focus

MathML provides the ability for authors to allow for interactivity in
supporting interactive user agents using the same concepts, approach and
guidance to [`Focus`](https://html.spec.whatwg.org/#focus) as described
in HTML, with modifications or clarifications regarding application for
MathML as described in this section.

When an element is focused, all applicable CSS focus-related
pseudo-classes as defined in [Selectors Level
3](https://www.w3.org/TR/selectors-3/#title) apply, as defined in that
specification.

The contents of embedded [`math`](#dfn-math) elements (including HTML elements
inside token elements) contribute to the sequential focus order of the
containing owner HTML document (combined sequential focus order).

::: header-wrapper
## 3. Presentation Markup

::: header-wrapper
### 3.1 Visual formatting model

::: header-wrapper
#### 3.1.1 Box Model

The default [`display`](#dfn-display) property is described in [A. User
Agent Stylesheet](#user-agent-stylesheet):

- For the `<math>` root, it is equal to `inline math` or `block math`
 according to the value of the
 [`display`](#dfn-display) attribute.
- For [Tabular MathML elements](#tabular-math)
 [`mtable`](#dfn-mtable), [`mtr`](#dfn-mtr),
 [`mtd`](#dfn-mtd)
 it is respectively equal to `inline-table`, `table-row` and
 `table-cell`.
- For all but the first children of the
 [`maction`](#dfn-maction) and
 [`semantics`](#dfn-semantics) elements, it is equal to `none`.
- For all the other [MathML
 elements](#dfn-mathml-element) it is equal to `block math`.

In order to specify math layout in different [writing
modes](https://www.w3.org/TR/css-writing-modes-4/#writing-mode),
this specification uses concepts from
\[[CSS-WRITING-MODES-4](#bib-css-writing-modes-4 "CSS Writing Modes Level 4")\]:

- [abstract
 dimensions](https://www.w3.org/TR/css-writing-modes-4/#abstract-dimensions):
 [block
 dimension](https://www.w3.org/TR/css-writing-modes-4/#block-dimension),
 [inline
 dimension](https://www.w3.org/TR/css-writing-modes-4/#inline-dimension),
 [block
 axis](https://www.w3.org/TR/css-writing-modes-4/#block-axis),
 [inline
 axis](https://www.w3.org/TR/css-writing-modes-4/#inline-axis),
 [block size](https://www.w3.org/TR/css-writing-modes-4/#block-size),
 [inline size](https://www.w3.org/TR/css-writing-modes-4/#inline-size).
- [flow-relative
 directions](https://www.w3.org/TR/css-writing-modes-4/#flow-relative-direction):
 [inline-start](https://www.w3.org/TR/css-writing-modes-4/#inline-start),
 [inline-end](https://www.w3.org/TR/css-writing-modes-4/#inline-end),
 [block-start](https://www.w3.org/TR/css-writing-modes-4/#block-start).
- [line-relative
 directions](https://www.w3.org/TR/css-writing-modes-4/#line-relative-direction):
 [line-left](https://www.w3.org/TR/css-writing-modes-4/#line-left),
 [line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over),
 [line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under).

Unless specified otherwise, the figures in this specification use a
[writing
mode](https://www.w3.org/TR/css-writing-modes-4/#writing-mode)
of `horizontal-lr` and `ltr`. See [Figure
4](#box-model-horizontal-tb-rtl "Box model for writing mode horizontal-tb and rtl that may be used in e.g. Arabic math."),
[Figure
5](#box-model-vertical-lr "Box model for writing mode vertical-lr and ltr that may be used in e.g. Mongolian math.")
and [Figure
6](#box-model-vertical-rl "Box model for writing mode vertical-rl and ltr that may be used in e.g. Japanese math.")
for examples of other writing modes that are sometimes used for math
layout.

Boxes used for MathML elements rely on several parameters in order to
perform layout in a way that is compatible with CSS but also to take
into account very accurate positions and spacing within math formulas:

1. Inline metrics. [min-content inline
 size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size),
 [max-content inline
 size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size)
 and [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) from
 CSS. See [Figure
 1](#box-model-generic "Generic Box Model for MathML elements").
 ![[Figure 1](#box-model-generic) [Generic Box Model for
 MathML
 elements]](figures/horizontal-tb-ltr.svg)

2. Block metrics. The [block
 size](https://www.w3.org/TR/css-writing-modes-4/#block-size), [first
 baseline
 set](https://www.w3.org/TR/css-align-3/#first-baseline-set)
 and [last baseline
 set](https://www.w3.org/TR/css-align-3/#last-baseline-set).
 The following
 [baselines](https://www.w3.org/TR/SVG/text.html#TermBaseline)
 are defined for MathML boxes:

 1. The [alphabetic baseline] which typically aligns
 with the bottom of uppercase Latin glyphs. The algebraic
 distance from the [alphabetic
 baseline](#dfn-alphabetic-baseline) to the
 [line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over)
 edge of the box is called the [line-ascent]. The algebraic distance from the
 [line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under)
 edge to the [alphabetic
 baseline](#dfn-alphabetic-baseline) of the box is called the
 [line-descent].
 2. The [mathematical baseline], also called
 [math axis], which typically aligns
 with the fraction bar, middle of fences and binary operators. It
 is shifted away from the [alphabetic
 baseline](#dfn-alphabetic-baseline) by
 [AxisHeight](#dfn-axisheight) towards the
 [line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over).
 3. The [ink-over baseline], indicating the
 [line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over)
 theorical limit of the math content drawn, excluding any extra
 space. If not specified, it is aligned with the
 [line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over)
 edge. The algebraic distance from the [alphabetic
 baseline](#dfn-alphabetic-baseline) to the [ink-over
 baseline](#dfn-ink-over-baseline) is called the [ink
 line-ascent].
 4. The [ink-under baseline], indicating
 the
 [line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under)
 theorical limit of the math content drawn, excluding any extra
 space. If not specified, it is aligned with the
 [line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under)
 edge. The algebraic distance from the [ink-under
 baseline](#dfn-ink-under-baseline) to the [alphabetic
 baseline](#dfn-alphabetic-baseline) is called the [ink
 line-descent].

 :::::
 :::
 Note
 :::

 :::
 For math layout, it is very important to rely on the ink extent when
 positioning text. This is not the case for more complex notations
 (e.g. square root). Although ink-ascent and ink-descent are defined
 for all MathML elements they are really only used for the token
 elements. In other cases, they just match normal ascent and descent.
 :::
 :::::

 Unless specified otherwise, the [last baseline
 set](https://www.w3.org/TR/css-align-3/#last-baseline-set)
 is equal to the [first baseline
 set](https://www.w3.org/TR/css-align-3/#first-baseline-set)
 for MathML boxes.

3. An optional [italic correction] which provides a
 measure of how much the text of a box is slanted along the [inline
 axis](https://www.w3.org/TR/css-writing-modes-4/#inline-axis).
 See [Figure
 2](#figure-italic-correction "Examples of italic correction for italic f and large integral").
 ![[Figure 2](#figure-italic-correction) [Examples of
 italic correction for italic f and large
 integral]](figures/italcorr.svg)

 If it is requested during calculation of [min-content inline
 size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
 and [max-content inline
 size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size)
 or during layout then 0 is used as a fallback value.

4. An optional [top accent attachment] which provides a
 reference offset on the [inline
 axis](https://www.w3.org/TR/css-writing-modes-4/#inline-axis)
 of a box that should be used when positioning that box as an accent.
 See [Figure
 3](#figure-top-accent-attachment "Example of top accent attachment for a circumflex accent").
 ![[Figure 3](#figure-top-accent-attachment) [Example of
 top accent attachment for a circumflex
 accent]](figures/topaccent.svg)

 If it is requested during calculation of [min-content inline
 size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
 (respectively [max-content inline
 size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
 then half the [min-content inline
 size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
 (respectively [max-content inline
 size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
 is used as a fallback value. If it is requested during layout then
 half the inline size of the box is used as a fallback value.

Given a MathML box, the following offsets are defined:

- The [inline offset] of a child box is
 the offset between the
 [inline-start](https://www.w3.org/TR/css-writing-modes-4/#inline-start)
 edge of the parent box and the
 [inline-start](https://www.w3.org/TR/css-writing-modes-4/#inline-start)
 edge of the child box.
- The [block offset] of a child box is the offset
 between the
 [block-start](https://www.w3.org/TR/css-writing-modes-4/#block-start)
 edge of the parent box and the
 [block-start](https://www.w3.org/TR/css-writing-modes-4/#block-start)
 edge of the child box.
- The [line-left offset] of a child box is the offset
 between the
 [line-left](https://www.w3.org/TR/css-writing-modes-4/#line-left)
 edge of the parent box and the
 [line-left](https://www.w3.org/TR/css-writing-modes-4/#line-left)
 edge of the child box.

![[Figure 4](#box-model-horizontal-tb-rtl) [Box model for
writing mode `horizontal-tb` and `rtl` that may be used in e.g. Arabic
math.]](figures/horizontal-tb-rtl.svg)

![[Figure 5](#box-model-vertical-lr) [Box model for writing
mode `vertical-lr` and `ltr` that may be used in e.g. Mongolian
math.]](figures/vertical-lr.svg)

![[Figure 6](#box-model-vertical-rl) [Box model for writing
mode `vertical-rl` and `ltr` that may be used in e.g. Japanese
math.]](figures/vertical-rl.svg)

The position of child boxes and graphical items inside a MathML box are
expressed using the [inline
offset](#dfn-inline-offset) and [block
offset](#dfn-block-offset). For convenience, the layout algorithms may describe
offsets using flow-relative directions, line-relative directions or the
[alphabetic
baseline](#dfn-alphabetic-baseline). It is always possible to pass from one
description to the other because position of child boxes is always
performed after the metrics of the box and of its child boxes are
calculated.

Here are examples of offsets obtained from line-relative metrics:

- The [inline offset](#dfn-inline-offset) of a child box is the [line-left
 offset](#dfn-line-left-offset) if the CSS property
 [direction](https://www.w3.org/TR/css-writing-modes-4/#propdef-direction)
 is `ltr` and is the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
 box − ([line-left
 offset](#dfn-line-left-offset) + [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
 child box) otherwise.
- The [block offset](#dfn-block-offset) of the [alphabetic
 baseline](#dfn-alphabetic-baseline) of a box is the
 [line-ascent](#dfn-line-ascent) if the CSS property
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)
 is `horizontal-lr`, `vertical-rl` or `sideways-rl` and is the
 [line-descent](#dfn-line-descent) otherwise.

[[Issue
78]](https://github.com/w3c/mathml-core/issues/78)[: Ink
ascent/descent
[opentype/tex](https://github.com/w3c/mathml-core/issues/?q=is%3Aissue+is%3Aopen+label%3A%22opentype%2Ftex%22)[needs-tests](https://github.com/w3c/mathml-core/issues/?q=is%3Aissue+is%3Aopen+label%3A%22needs-tests%22)]

Improve definition of ink ascent/descent?

::: header-wrapper
#### 3.1.2 Layout Algorithms

Each MathML element has an associated [math content
box], which is calculated as described in this chapter\'s
layout algorithms using the following structure:

1. Calculation of [min-content inline
 size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
 and [max-content inline
 size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size)
 of the math content.
2. Box layout:
 1. Layout of
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 child boxes.
 2. Calculation of [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size),
 [ink
 line-ascent](#dfn-ink-line-ascent), [ink
 line-descent](#dfn-ink-line-descent),
 [line-ascent](#dfn-line-ascent) and
 [line-ascent](#dfn-line-ascent) of the math content.
 3. Calculation of offsets of child boxes within the [math content
 box](#dfn-math-content-box) as well as sizes and offsets of
 extra graphical items (bars, radical symbol, etc).
 4. Layout and positioning of
 [absolutely-positioned](https://www.w3.org/TR/css-position-3/#absolute-position)
 and
 [fixed-positioned](https://www.w3.org/TR/css-position-3/#fixed-position)
 boxes, as described in
 \[[CSS-POSITION-3](#bib-css-position-3 "CSS Positioned Layout Module Level 3")\].

The following extra steps must be performed:

- After calculating the
 [line-ascent](#dfn-line-ascent) and
 [line-descent](#dfn-line-descent) of a [math content
 box](#dfn-math-content-box), its [block
 size](https://www.w3.org/TR/css-writing-modes-4/#block-size) is set to
 their sum.

- By default, the box metrics, offsets,
 [baselines](https://www.w3.org/TR/SVG/text.html#TermBaseline),
 [italic
 correction](#dfn-italic-correction) and [top accent
 attachment](#dfn-top-accent-attachment) of the [content
 box](https://www.w3.org/TR/css-box-4/#content-box)
 are set to the one calculated for the [math content
 box](#dfn-math-content-box). However if a different size is
 specified for the [content
 box](https://www.w3.org/TR/css-box-4/#content-box)
 (via
 [width](https://www.w3.org/TR/css-sizing-3/#propdef-width),
 [height](https://www.w3.org/TR/css-sizing-3/#propdef-height)
 or related properties), that size is used instead and the inline-start
 and block-start edges of the [math content
 box](#dfn-math-content-box) are aligned with the ones of the
 [content
 box](https://www.w3.org/TR/css-box-4/#content-box),
 unless otherwise specified in a specific layout algorithm.

- The box metrics and offsets of the [padding
 box](https://www.w3.org/TR/css-box-4/#padding-box)
 are obtained from the [content
 box](https://www.w3.org/TR/css-box-4/#content-box) by
 taking into account the corresponding
 [padding](https://www.w3.org/TR/css-box-4/#padding)
 properties as described in CSS.

 The
 [baselines](https://www.w3.org/TR/SVG/text.html#TermBaseline)
 of the [padding
 box](https://www.w3.org/TR/css-box-4/#padding-box)
 are the same as the one of the [content
 box](https://www.w3.org/TR/css-box-4/#content-box).

 If the [content
 box](https://www.w3.org/TR/css-box-4/#content-box)
 has a [top accent
 attachment](#dfn-top-accent-attachment) then the [padding
 box](https://www.w3.org/TR/css-box-4/#padding-box)
 has the same property, increased by the inline-start padding. If the
 [content
 box](https://www.w3.org/TR/css-box-4/#content-box)
 has an [italic
 correction](#dfn-italic-correction) then the [padding
 box](https://www.w3.org/TR/css-box-4/#padding-box)
 has the same property, increased by the
 [inline-end](https://www.w3.org/TR/css-writing-modes-4/#inline-end)
 padding.

- The box metrics and offsets of the [border
 box](https://www.w3.org/TR/css-box-4/#border-box) are
 obtained from the [padding
 box](https://www.w3.org/TR/css-box-4/#padding-box) by
 taking into account the corresponding
 [border-width](https://www.w3.org/TR/css-backgrounds-3/#propdef-border-width)
 property as described in CSS.

 In general, the
 [baselines](https://www.w3.org/TR/SVG/text.html#TermBaseline)
 of the [border
 box](https://www.w3.org/TR/css-box-4/#border-box) are
 the same as the one of the [padding
 box](https://www.w3.org/TR/css-box-4/#padding-box).
 However, if the
 [line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over)
 border is positive then the [ink-over
 baseline](#dfn-ink-over-baseline) is set to the
 [line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over)
 edge of the [border
 box](https://www.w3.org/TR/css-box-4/#border-box) and
 if the
 [line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under)
 border is positive then the [ink-under
 baseline](#dfn-ink-under-baseline) is set to the
 [line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under)
 edge of the [border
 box](https://www.w3.org/TR/css-box-4/#border-box).

 If the [padding
 box](https://www.w3.org/TR/css-box-4/#padding-box)
 has a [top accent
 attachment](#dfn-top-accent-attachment) then the [border
 box](https://www.w3.org/TR/css-box-4/#border-box) has
 the same property, increased by the border-width of its inline-start
 egde. If the [padding
 box](https://www.w3.org/TR/css-box-4/#padding-box)
 has an [italic
 correction](#dfn-italic-correction) then the [border
 box](https://www.w3.org/TR/css-box-4/#border-box) has
 the same property, increased by the border-width of its
 [inline-end](https://www.w3.org/TR/css-writing-modes-4/#inline-end)
 egde.

- The box metrics and offsets of the [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) are
 obtained from the [border
 box](https://www.w3.org/TR/css-box-4/#border-box) by
 taking into account the corresponding
 [margin](https://www.w3.org/TR/css-box-4/#propdef-margin)
 properties as described in CSS.

 The
 [baselines](https://www.w3.org/TR/SVG/text.html#TermBaseline)
 of the [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) are
 the same as the one of the [border
 box](https://www.w3.org/TR/css-box-4/#border-box).

 If the [padding
 box](https://www.w3.org/TR/css-box-4/#padding-box)
 has a [top accent
 attachment](#dfn-top-accent-attachment) then the [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) has
 the same property, increased by the inline-start margin. If the
 [padding
 box](https://www.w3.org/TR/css-box-4/#padding-box)
 has an [italic
 correction](#dfn-italic-correction) then the [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) has
 the same property, increased by the
 [inline-end](https://www.w3.org/TR/css-writing-modes-4/#inline-end)
 margin.

Per the description above,
[margin-collapsing](https://www.w3.org/TR/CSS2/box.html#collapsing-margins)
does not apply to MathML elements.

During box layout, optional [inline stretch size
constraint] and [block stretch size
constraint] parameters may be used on
[embellished
operators](#dfn-embellished-operator). The former indicates a target size that a
[core operator](#dfn-core-operator) stretched along the [inline
axis](https://www.w3.org/TR/css-writing-modes-4/#inline-axis)
should cover. The latter indicates an [ink
line-ascent](#dfn-ink-line-ascent) and [ink
line-descent](#dfn-ink-line-descent) that a [core
operator](#dfn-core-operator) stretched along the [block
axis](https://www.w3.org/TR/css-writing-modes-4/#block-axis)
should cover. Unless specified otherwise, these parameters are ignored
during box layout and child boxes are laid out without any stretch size
constraint.

[[Issue
76]](https://github.com/w3c/mathml-core/issues/76)[:
Define what inline percentages resolve against.
[css/html5](https://github.com/w3c/mathml-core/issues/?q=is%3Aissue+is%3Aopen+label%3A%22css%2Fhtml5%22)[need specification
update](https://github.com/w3c/mathml-core/issues/?q=is%3Aissue+is%3Aopen+label%3A%22need+specification+update%22)[needs-tests](https://github.com/w3c/mathml-core/issues/?q=is%3Aissue+is%3Aopen+label%3A%22needs-tests%22)]

Define what inline percentages resolve against

[[Issue
77]](https://github.com/w3c/mathml-core/issues/77)[:
Define what block percentages resolve against.
[css/html5](https://github.com/w3c/mathml-core/issues/?q=is%3Aissue+is%3Aopen+label%3A%22css%2Fhtml5%22)[need specification
update](https://github.com/w3c/mathml-core/issues/?q=is%3Aissue+is%3Aopen+label%3A%22need+specification+update%22)[needs-tests](https://github.com/w3c/mathml-core/issues/?q=is%3Aissue+is%3Aopen+label%3A%22needs-tests%22)]

Define what block percentages resolve against

::: header-wrapper
#### 3.1.3 Anonymous \<mrow\> boxes

An [anonymous box] is a box without any associated
element in the DOM tree and which is generated for layout purpose only.
The properties of anonymous boxes are inherited from the enclosing
non-anonymous box while non-inherited properties have their initial
value. An [anonymous \<mrow\> box] is an [anonymous
box](#dfn-anonymous-box) with `display` equal to `block math` and which is laid
out as described in section [3.3.1.2 Layout of
`<mrow>`](#layout-of-mrow).

If a MathML element [generates an anonymous \<mrow\>
box] then it wraps its children in an
anonymous \<mrow\> box. I.e., its subtree in the visual formatting model
is made of an [anonymous \<mrow\>
box](#dfn-anonymous-mrow-box) which itself contains the boxes associated
to the children of this MathML element.

In the following example, the [`math`](#dfn-math) and
[`mrow`](#dfn-mrow) elements are laid out as described in section
[3.3.1.2 Layout of `<mrow>`](#layout-of-mrow). In particular,
the `<math>` element adds proper spacing around its `<mo>≠</mo>` child
and the `<mrow>` element stretches its `<mo>|</mo>` children vertically.

The [`mtd`](#dfn-mtd) element has `display: table-cell` and the
[`msqrt`](#dfn-msqrt) element displays a radical symbol around its
children. However, they also place their children in a way that is
similar to what is described in section [3.3.1.2 Layout of
`<mrow>`](#layout-of-mrow): the `<msqrt>` element adds proper
spacing around its `<mo>+</mo>` child while the `<mtd>` element
stretches its `<mo>` children vertically. In order to make this
possible, each of these two elements [generates an anonymous \<mrow\>
box](#dfn-generates-an-anonymous-mrow-box).

``` {aria-busy="false"}
<math>
 <mrow>
 <mo>|</mo>
 <mtable>
 <mtr>
 <mtd>
 <mi>x</mi>
 </mtd>
 <mtd>
 <mo>(</mo>
 <mfrac linethickness="0">
 <mn>5</mn>
 <mn>3</mn>
 </mfrac>
 <mo>)</mo>
 </mtd>
 </mtr>
 <mtr>
 <mtd>
 <msqrt>
 <mn>7</mn>
 <mo>+</mo>
 <mn>2</mn>
 </msqrt>
 </mtd>
 <mtd>
 <mi>y</mi>
 </mtd>
 </mtr>
 </mtable>
 <mo>|</mo>
 </mrow>
 <mo>≠</mo>
 <mn>0</mn>
</math>
```

![math example (display)](examples/example-anonymous-mrow-nodes.png)

::: header-wrapper
#### 3.1.4 Stacking contexts

MathML elements can overlap due to various spacing rules. They can as
well contain extra graphical items (bars, radical symbol, etc). A MathML
element with computed style `display: block math` or
`display: inline math` generates a new stacking context. The [painting
order](https://www.w3.org/TR/CSS2/zindex.html#painting-order) of
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children of such a MathML element is exactly the same as block elements.
The extra graphical items are painted after text and background (right
after step 7.2.4 for `display: inline math` and right after step 7.2 for
`display: block math`).

::: header-wrapper
### 3.2 Token Elements

Token elements in presentation markup are broadly intended to represent
the smallest units of mathematical notation which carry meaning. Tokens
are roughly analogous to words in text. However, because of the precise,
symbolic nature of mathematical notation, the various categories and
properties of token elements figure prominently in MathML markup. By
contrast, in textual data, individual words rarely need to be marked up
or styled specially.

In practice, most MathML token elements just contain simple text for
variables, numbers, operators etc and don\'t need sophisticated layout.
However, it can contain text with line breaks or arbitrary HTML5
phrasing elements.

::: header-wrapper
#### 3.2.1 Text `<mtext>`

The [mtext] element is used to represent arbitrary
text that should be rendered as itself. In general, the `<mtext>`
element is intended to denote commentary text.

The `<mtext>` element accepts the attributes described in [2.1.3 Global
Attributes](#global-attributes).

In the following example, [`mtext`](#dfn-mtext) is used to put conditional words in a
definition:

``` {aria-busy="false"}
<math>
 <mi>y</mi>
 <mo>=</mo>
 <mrow>
 <msup>
 <mi>x</mi>
 <mn>2</mn>
 </msup>
 <mtext>&nbsp;if&nbsp;</mtext>
 <mrow>
 <mi>x</mi>
 <mo>≥</mo>
 <mn>1</mn>
 </mrow>
 <mtext>&nbsp;and&nbsp;</mtext>
 <mn>2</mn>
 <mtext>&nbsp;otherwise.</mtext>
 </mrow>
</math>
```

![mtext example](examples/example-mtext.png)

::: header-wrapper
##### 3.2.1.1 Layout of `<mtext>`

If the element does not have its computed
[`display`](#dfn-display) property equal to `block math` or
`inline math` then it is laid out according to the CSS specification
where the corresponding value is described. Otherwise, the layout below
is performed.

If the `<mtext>` element contains only text content without [forced line
break](https://www.w3.org/TR/css-text-3/#forced-line-break)
or [soft wrap
opportunity](https://www.w3.org/TR/css-text-3/#soft-wrap-opportunity)
then, the anonymous child node generated for that text is laid out as
defined in the relevant CSS specification and:

- The [min-content inline
 size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size),
 [max-content inline
 size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size)
 and [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
 [math content
 box](#dfn-math-content-box) are equal to the one of the anonymous
 child.
- The [ink
 line-ascent](#dfn-ink-line-ascent) and [ink
 line-descent](#dfn-ink-line-descent) of the [math content
 box](#dfn-math-content-box) are set so that its [ink-over
 baseline](#dfn-ink-over-baseline), [ink-under
 baseline](#dfn-ink-under-baseline) and [alphabetic
 baseline](#dfn-alphabetic-baseline) match the one of the ink bounding box of
 the text.
- The [line-ascent](#dfn-line-ascent) (respectively
 [line-descent](#dfn-line-descent)) of the [math content
 box](#dfn-math-content-box) is set to the [ink
 line-ascent](#dfn-ink-line-ascent) (respectively [ink
 line-descent](#dfn-ink-line-descent)).
- If the text content is made of a single glyph and this glyph has an
 entry in the
 [MathItalicsCorrectionInfo](#dfn-mathitalicscorrectioninfo) table then the specified value is used
 as the [italic
 correction](#dfn-italic-correction).
- If the text content is made of a single glyph and this glyph has an
 entry in the
 [MathTopAccentAttachment](#dfn-mathtopaccentattachment) table then the specified value is used
 as the top accent attachment of the `<mtext>` element.

Otherwise, the `mtext` element is laid out as a [block
box](https://www.w3.org/TR/css-display-3/#block-box)
and corresponding [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size),
[max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size),
[inline size](https://www.w3.org/TR/css-writing-modes-4/#inline-size),
[block size](https://www.w3.org/TR/css-writing-modes-4/#block-size),
[first baseline
set](https://www.w3.org/TR/css-align-3/#first-baseline-set)
and [last baseline
set](https://www.w3.org/TR/css-align-3/#last-baseline-set)
are used for the [math content
box](#dfn-math-content-box).

::: header-wrapper
#### 3.2.2 Identifier `<mi>`

The [mi] element represents a symbolic name or
arbitrary text that should be rendered as an identifier. Identifiers can
include variables, function names, and symbolic constants.

The `<mi>` element accepts the attributes described in [2.1.3 Global
Attributes](#global-attributes) as well as the following
attribute:

- [`mathvariant`](#dfn-mathvariant)

The layout algorithm is the same as the
[`mtext`](#dfn-mtext) element. The [user agent
stylesheet](#dfn-user-agent-stylesheet) must contain the following property in
order to implement automatic italic via the text-transform value
introduced in [4.2 The `math-auto`
transform](#math-auto-transform):

``` {aria-busy="false"}
mi {
 text-transform: math-auto;
}
```

The [mathvariant]
attribute, if present, must be an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
match of `normal`. In that case, the user agent is expected to treat the
attribute as a [presentational
hint](https://html.spec.whatwg.org/#presentational-hints) setting the
element\'s
[text-transform](https://www.w3.org/TR/css-text-3/#propdef-text-transform)
property to `none`. Otherwise it has no effects.

\[[MathML3](#bib-mathml3 "Mathematical Markup Language (MathML) Version 3.0 2nd Edition")\], the `mathvariant` attribute was used to define
logical classes of token elements, each class providing a collection of
typographically-related symbolic tokens with specific meaning within a
given mathematical expression.

In MathML Core, this attribute is only used to cancel automatic italic
of the [`mi`](#dfn-mi) element. For other use cases, the proper
Mathematical Alphanumeric Symbols
\[[UNICODE](#bib-unicode "The Unicode Standard")\] should be used instead. See also section [C.
Mathematical Alphanumeric
Symbols](#new-text-transform-mappings).

In the following example, [`mi`](#dfn-mi) is used to render variables and function names.
Note that per [4.2 The `math-auto`
transform](#math-auto-transform) the default style
`text-transform: math-auto` has no effect on the first `<mi>` (\"cos\"
is made of three characters), makes the second `<mi>` render as math
italic (\"c\" is made of a single character U+0063 Latin Small Letter C
which is mapped to U+1D450 Mathematical Italic Small C per the
[italic](#italic-mappings) table), has no effect on the third `<mi>`
(overridden by `mathvariant="normal"`, setting `text-transform` to none)
or on the fourth `<mi>` (no mapping defined for U+221E Infinity in the
[italic](#italic-mappings) table).

``` {aria-busy="false"}
<math>
 <mi>cos</mi>
 <mo>,</mo>
 <mi>c</mi>
 <mo>,</mo>
 <mi mathvariant="normal">c</mi>
 <mo>,</mo>
 <mi>∞</mi>
</math>
```

![mi example](examples/example-mi.png)

::: header-wrapper
#### 3.2.3 Number `<mn>`

The [mn] element represents a \"numeric
literal\" or other data that should be rendered as a numeric literal.
Generally speaking, a numeric literal is a sequence of digits, perhaps
including a decimal point, representing an unsigned integer or real
number.

The `<mn>` element accepts the attributes described in [2.1.3 Global
Attributes](#global-attributes). Its layout algorithm is the
same as the [`mtext`](#dfn-mtext) element.

In the following example, [`mn`](#dfn-mn) is used to write a decimal number.

``` {aria-busy="false"}
<math>
 <mn>3.141592653589793</mn>
</math>
```

![mn example](examples/example-mn.png)

::: header-wrapper
#### 3.2.4 Operator, Fence, Separator or Accent `<mo>`

The [mo] element represents an operator or
anything that should be rendered as an operator. In general, the
notational conventions for mathematical operators are quite complicated,
and therefore MathML provides a relatively sophisticated mechanism for
specifying the rendering behavior of an `<mo>` element.

As a consequence, in MathML the list of things that should \"render as
an operator\" includes a number of notations that are not mathematical
operators in the ordinary sense. Besides ordinary operators with infix,
prefix, or postfix forms, these include fence characters such as braces,
parentheses, and \"absolute value\" bars; separators such as comma and
semicolon; and mathematical accents such as a bar or tilde over a
symbol. This chapter uses the term \"operator\" to refer to operators in
this broad sense.

The `<mo>` element accepts the attributes described in [2.1.3 Global
Attributes](#global-attributes) as well as the following
attributes:

- [`form`](#dfn-form)
- [`fence`](#dfn-fence)
- [`separator`](#dfn-separator)
- [`lspace`](#dfn-lspace-0)
- [`rspace`](#dfn-rspace-0)
- [`stretchy`](#dfn-stretchy-0)
- [`symmetric`](#dfn-symmetric-0)
- [`maxsize`](#dfn-maxsize-0)
- [`minsize`](#dfn-minsize-0)
- [`largeop`](#dfn-largeop-0)
- [`movablelimits`](#dfn-movablelimits-0)

This specification does not define any observable behavior that is
specific to the [fence]
and [separator]
attributes.

Authors may use the [`fence`](#dfn-fence) and
[`separator`](#dfn-separator) to describe specific semantics of operators.
The default values may be determined from the
[`Operators_fence`](#operator-dictionary-compact-special-tables) and
[`Operators_separator`](#operator-dictionary-compact-special-tables)
tables, or equivalently the [human-readable
version](#operator-dictionary-human) of the operator dictionary.

In the following example, the [`mo`](#dfn-mo) element is used for the binary
operator +. Default spacing is symmetric around that operator. A tighter
spacing is used if you rely on the
[`form`](#dfn-form) attribute to force it to be treated as a
prefix operator. Spacing can also be specified explicitly using the
[`lspace`](#dfn-lspace-0) and
[`rspace`](#dfn-rspace-0) attributes.

``` {aria-busy="false"}
<math>
 <mn>1</mn>
 <mo>+</mo>
 <mn>2</mn>
 <mo form="prefix">+</mo>
 <mn>3</mn>
 <mo lspace="2em">+</mo>
 <mn>4</mn>
 <mo rspace="3em">+</mo>
 <mn>5</mn>
</math>
```

![mo example 1](examples/example-mo-1.png)

Another use case is for big operators such as summation. When
[displaystyle](#dfn-displaystyle) is true, such an operator is drawn larger
but one can change that with the
[`largeop`](#dfn-largeop-0) attribute. When
[displaystyle](#dfn-displaystyle) is false, underscripts are actually
rendered as subscripts but one can change that with the
[`movablelimits`](#dfn-movablelimits-0) attribute.

``` {aria-busy="false"}
<math>
 <mrow displaystyle="true">
 <munder>
 <mo>∑</mo>
 <mn>5</mn>
 </munder>
 <munder>
 <mo largeop="false">∑</mo>
 <mn>6</mn>
 </munder>
 </mrow>
 <mrow>
 <munder>
 <mo>∑</mo>
 <mn>5</mn>
 </munder>
 <munder>
 <mo movablelimits="false">∑</mo>
 <mn>7</mn>
 </munder>
 </mrow>
</math>
```

![mo example 2](examples/example-mo-2.png)

Operators are also used for stretchy symbols such as fences, accents,
arrows etc. In the following example, the vertical arrow stretches to
the height of the [`mspace`](#dfn-mspace) element. One can override default
stretch behavior with the
[`stretchy`](#dfn-stretchy-0) attribute e.g. to force an unstretched arrow.
The [`symmetric`](#dfn-symmetric-0) attribute allows to indicate
whether the operator should stretch symmetrically above and below the
math axis (fraction bar). Finally the
[`minsize`](#dfn-minsize-0) and
[`maxsize`](#dfn-maxsize-0) attributes add additional constraints over the
stretch size.

``` {aria-busy="false"}
<math>
 <mfrac>
 <mspace height="50px" depth="50px" width="10px" style="background: blue"/>
 <mspace height="25px" depth="25px" width="10px" style="background: green"/>
 </mfrac>
 <mo>↑</mo>
 <mo stretchy="false">↑</mo>
 <mo symmetric="true">↑</mo>
 <mo minsize="250px">↑</mo>
 <mo maxsize="50px">↑</mo>
</math>
```

![mo example 3](examples/example-mo-3.png)

Note that the default properties of operators are dictionary-based, as
explained in [3.2.4.2 Dictionary-based
attributes](#dictionary-based-attributes). For example a
binary operator typically has default symmetric spacing around it while
a fence is generally stretchy by default.

::: header-wrapper
##### 3.2.4.1 Embellished operators

A [MathML Core
element](#dfn-mathml-core-elements) is an [embellished
operator] if it is:

1. An [`mo`](#dfn-mo) element;
2. a [scripted
 element](#dfn-scripted-elements) or an
 [`mfrac`](#dfn-mfrac), whose first
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 child exists and is an [embellished
 operator](#dfn-embellished-operator);
3. a [grouping
 element](#dfn-grouping-elements) or
 [`mpadded`](#dfn-mpadded), whose
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 children consist (in any order) of one [embellished
 operator](#dfn-embellished-operator) and zero or more
 [space-like](#dfn-space-like) elements.

The [core operator] of an [embellished
operator](#dfn-embellished-operator) is the `<mo>` element defined recursively
as follows:

1. The core operator of an [`mo`](#dfn-mo) element; is the element itself.
2. The core operator of an embellished [scripted
 element](#dfn-scripted-elements) or
 [`mfrac`](#dfn-mfrac) element is the core operator of its first
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 child.
3. The core operator of an embellished [grouping
 element](#dfn-grouping-elements) or
 [`mpadded`](#dfn-mpadded) is the core operator of its unique [embellished
 operator](#dfn-embellished-operator)
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 child.

The [stretch axis] of an [embellished
operator](#dfn-embellished-operator) is *inline* if its [core
operator](#dfn-core-operator) contains only text content made of a single
character `c`, and that character has inline [intrinsic stretch
axis](#dfn-intrinsic-stretch-axis). Otherwise, the stretch axis of the
[embellished
operator](#dfn-embellished-operator) is *block*.

The same definitions apply for boxes in the visual formatting model
where an [anonymous \<mrow\>
box](#dfn-anonymous-mrow-box) is treated as a [grouping
element](#dfn-grouping-elements).

::: header-wrapper
##### 3.2.4.2 Dictionary-based attributes

The `form` property of an [embellished
operator](#dfn-embellished-operator) is either `infix`, `prefix` or `postfix`.
The corresponding [form]
attribute on the [`mo`](#dfn-mo) element, if present, must be an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
match to one of these values.

The [algorithm for determining the `form` of an [embellished
operator](#dfn-embellished-operator)] is as follows:

1. If the `form` attribute is present and valid on the [core
 operator](#dfn-core-operator), then its [ASCII
 lowercased
 value](https://infra.spec.whatwg.org/#ascii-lowercase) is used.
2. If the embellished operator is the first
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 child of a [grouping
 element](#dfn-grouping-elements),
 [`mpadded`](#dfn-mpadded) or [`msqrt`](#dfn-msqrt) with more than one
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 child (ignoring all
 [space-like](#dfn-space-like) children) then it has form `prefix`.
3. Or, if the embellished operator is the last
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 child of a [grouping
 element](#dfn-grouping-elements),
 [`mpadded`](#dfn-mpadded) or [`msqrt`](#dfn-msqrt) with more than one
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 child (ignoring all
 [space-like](#dfn-space-like) children) then it has form `postfix`.
4. Or, if the embellished operator is an
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 child of a [scripted
 element](#dfn-scripted-elements), other than the first
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 child, then it has form `postfix`.
5. Otherwise, the embellished operator has form `infix`.

The [`stretchy`],
[`symmetric`],
[`largeop`],
[`movablelimits`] properties of an
[embellished
operator](#dfn-embellished-operator) are either `false` or `true`. In the
latter case, it is said that the [embellished
operator](#dfn-embellished-operator) *has* the property. The corresponding
[stretchy],
[symmetric],
[largeop],
[movablelimits]
attributes on the [`mo`](#dfn-mo) element, if present, must be a
[boolean](#dfn-boolean).

The [`lspace`],
[`rspace`], [`minsize`] properties of an [embellished
operator](#dfn-embellished-operator) are
[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage).
The [`maxsize`] property of an [embellished
operator](#dfn-embellished-operator) is either a
[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)
or ∞. The [lspace],
[rspace],
[minsize]
and [maxsize]
attributes on the [`mo`](#dfn-mo) element, if present, must be a
[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage).

The [algorithm for determining the properties of an [embellished
operator](#dfn-embellished-operator)] is as follows:

1. If the corresponding `stretchy`, `symmetric`, `largeop`,
 `movablelimits`, `lspace`, `rspace`, `maxsize` or `minsize`
 attribute is present and valid on the [core
 operator](#dfn-core-operator), then the [ASCII
 lowercased
 value](https://infra.spec.whatwg.org/#ascii-lowercase) of this property is used.
2. Otherwise, run the [algorithm for determining the `form` of an
 embellished
 operator](#dfn-algorithm-for-determining-the-form-of-an-embellished-operator).
3. If the [core
 operator](#dfn-core-operator) contains only text content
 `Content`, then set `Category` to the result of the [algorithm to
 determine the category of an
 operator](#dfn-algorithm-to-determine-the-category-of-an-operator) `(Content, Form)` where `Form` is the
 [`form`](https://html.spec.whatwg.org/multipage/forms.html#the-form-element)
 calculated at the previous step.
4. If `Category` is `Default` and the
 [`form`](https://html.spec.whatwg.org/multipage/forms.html#the-form-element)
 of [embellished
 operator](#dfn-embellished-operator) was not explicitly specified as an
 attribute on its [core
 operator](#dfn-core-operator):
 1. Set `Category` to the result of the [algorithm to determine the
 category of an
 operator](#dfn-algorithm-to-determine-the-category-of-an-operator) `(Content, Form)` where `Form` is
 `infix`.
 2. If `Category` is `Default`, then run the algorithm again with
 `Form` set to `postfix`.
 3. If `Category` is `Default`, then run the algorithm again with
 `Form` set to `prefix`.
5. Run the [algorithm to set the properties of an operator from its
 category](#dfn-algorithm-to-set-the-properties-of-an-operator-from-its-category) `Category`.

When used during layout, the values of
[`stretchy`](#dfn-stretchy),
[`symmetric`](#dfn-symmetric),
[`largeop`](#dfn-largeop),
[`movablelimits`](#dfn-movablelimits),
[`lspace`](#dfn-lspace),
[`rspace`](#dfn-rspace),
[`minsize`](#dfn-minsize) are obtained by the [algorithm for
determining the properties of an embellished
operator](#algorithm-for-determining-the-properties-of-an-embellished-operator) with the following extra resolutions:

- Percentage values for `lspace`, `rspace` are interpreted relative to
 the value read from the dictionary or to the fallback value above.
- Interpretation of percentage values for `minsize` and `maxsize` are
 described in [3.2.4.3 Layout of
 operators](#layout-of-operators).
- Font-relative lengths for `lspace`, `rspace`, `minsize` and `maxsize`
 rely on the font style of the [core
 operator](#dfn-core-operator), not the one of the
 [embellished
 operator](#dfn-embellished-operator).

::: header-wrapper
##### 3.2.4.3 Layout of operators

If the `<mo>` element does not have its computed
[`display`](#dfn-display) property equal to `block math` or
`inline math` then it is laid out according to the CSS specification
where the corresponding value is described. Otherwise, the layout below
is performed.

The text of the operator must only be painted if the
[visibility](https://www.w3.org/TR/css-display-3/#propdef-visibility)
of the `<mo>` element is `visible`. In that case, it must be painted
with the
[color](https://www.w3.org/TR/css-color-4/#propdef-color)
of the `<mo>` element.

Let `dir` be the element\'s computed
[direction](https://www.w3.org/TR/css-writing-modes-4/#propdef-direction).

Operators are laid out as follows:

1. If the content of the `<mo>` element is not made of a single
 character `c` then fall back to the layout algorithm of [3.2.1.1
 Layout of `<mtext>`](#layout-of-mtext). If it is not
 possible to [get a
 glyph](#dfn-get-a-glyph) corresponding to `c` given directionality `dir`,
 then fall back to the layout algorithm of [3.2.1.1 Layout of
 `<mtext>`](#layout-of-mtext). Otherwise, let `g` be the
 result of running [get a
 glyph](#dfn-get-a-glyph) corresponding to `c` given directionality `dir`.
2. If the operator has the
 [`stretchy`](#dfn-stretchy) property:
 - If the [stretch
 axis](#dfn-stretch-axis) of the operator is inline:
 1. If it is not possible to [shape a stretchy
 glyph](#dfn-shape-a-stretchy-glyph) `g` in the inline direction with
 the [first available
 font](https://www.w3.org/TR/css-fonts-4/#first-available-font)
 then fall back to the layout algorithm of [3.2.1.1 Layout of
 `<mtext>`](#layout-of-mtext).
 2. The [min-content inline
 size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
 and [max-content inline
 size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size)
 of the math content are set to the one obtained by the layout
 algorithm of [3.2.1.1 Layout of
 `<mtext>`](#layout-of-mtext).
 3. If there is not any [inline stretch size
 constraint](#dfn-inline-stretch-size-constraint) `T`~`inline`~ then fall back to
 the layout algorithm of [3.2.1.1 Layout of
 `<mtext>`](#layout-of-mtext).
 4. The [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size)
 and (ink) block metrics of the math content are given by
 algorithm to [shape a stretchy
 glyph](#dfn-shape-a-stretchy-glyph) `g` to [inline
 dimension](https://www.w3.org/TR/css-writing-modes-4/#inline-dimension)
 `T`~`inline`~.
 5. The painting of the operator is performed by the algorithm to
 [shape a stretchy
 glyph](#dfn-shape-a-stretchy-glyph) `g` stretched to [inline
 dimension](https://www.w3.org/TR/css-writing-modes-4/#inline-dimension)
 `T`~`inline`~ and at position determined by the previous box
 metrics.
 - Otherwise, the [stretch
 axis](#dfn-stretch-axis) of the operator is block. The
 following steps are performed:
 1. If it is not possible to [shape a stretchy
 glyph](#dfn-shape-a-stretchy-glyph) `g` in the block direction with
 the [first available
 font](https://www.w3.org/TR/css-fonts-4/#first-available-font)
 then fall back to the layout algorithm of [3.2.1.1 Layout of
 `<mtext>`](#layout-of-mtext).
 2. The [min-content inline
 size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
 and [max-content inline
 size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size)
 of the math content are set to the [preferred inline size of a
 glyph stretched along the block
 axis](#dfn-preferred-inline-size-of-a-glyph-stretched-along-the-block-axis).
 3. If there is not any [block stretch size
 constraint](#dfn-block-stretch-size-constraint)
 `(U`~`ascent`~`, U`~`descent`~`)` then fall back to the layout
 algorithm of [3.2.1.1 Layout of
 `<mtext>`](#layout-of-mtext).
 4. If the operator has the
 [`symmetric`](#dfn-symmetric) property then set
 the target sizes `T`~`ascent`~ and `T`~`descent`~ to
 `S`~`ascent`~ and `S`~`descent`~ respectively:
 - `S`~`ascent`~ = max( `U`~`ascent`~ −
 [AxisHeight](#dfn-axisheight), `U`~`descent`~ +
 [AxisHeight](#dfn-axisheight) ) +
 [AxisHeight](#dfn-axisheight)
 - `S`~`descent`~ = max( `U`~`ascent`~ −
 [AxisHeight](#dfn-axisheight), `U`~`descent`~ +
 [AxisHeight](#dfn-axisheight) ) −
 [AxisHeight](#dfn-axisheight)

 Otherwise set them to `U`~`ascent`~ and `U`~`descent`~
 respectively.

 :::::
 :::
 Note
 :::

 :::
 The property `T`~`ascent`~ −
 [AxisHeight](#dfn-axisheight) = `T`~`descent`~ +
 [AxisHeight](#dfn-axisheight) means that an operator
 stretching exactly `T`~`ascent`~ above the baseline and
 `T`~`descent`~ below the baseline would actually stretch
 symmetrically above and below the [math
 axis](#dfn-math-axis). `S`~`ascent`~ and `S`~`descent`~ are the
 minimal values, that are respectively not less than
 `U`~`ascent`~ and `U`~`descent`~, which satisfy this property.
 :::
 :::::
 5. Let `minsize` and `maxsize` be the
 [`minsize`](#dfn-minsize) and
 [`maxsize`](#dfn-maxsize) properties on the operator.
 Percentage values are interpreted relative to the height of
 `g`. Let `T` = `T`~`ascent`~ + `T`~`descent`~ be the target
 size. If `minsize` \< 0 then set `minsize` to 0. If `maxsize`
 \< `minsize` then set `maxsize` to `minsize`. With 0 ≤
 `minsize` ≤ `maxsize`:
 - If `T` ≤ 0 then set `T`~`ascent`~ to `minsize` / 2 +
 [AxisHeight](#dfn-axisheight) and then set `T`~`descent`~ to
 `minsize` − `T`~`ascent`~.
 - Otherwise, if 0 \< `T` \< `minsize` then set `T`~`ascent`~
 to max(0, (`T`~`ascent`~ −
 [AxisHeight](#dfn-axisheight)) × `minsize` / `T` +
 [AxisHeight](#dfn-axisheight)) and `T`~`descent`~ to
 `minsize` − `T`~`ascent`~.
 - Otherwise, if `maxsize` \< `T` then set `T`~`ascent`~ to
 max(0, (`T`~`ascent`~ −
 [AxisHeight](#dfn-axisheight)) × `maxsize` / `T` +
 [AxisHeight](#dfn-axisheight)) and `T`~`descent`~ to
 `maxsize` − `T`~`ascent`~.

 :::::
 :::
 Note
 :::

 :::
 The default `maxsize` is value ∞ is interpreted above as being
 larger than any other size, i.e. `minsize ≤ maxsize` is always
 true while `maxsize < minsize` and `maxsize < T` are always
 false.
 :::
 :::::

 :::::
 :::
 Note
 :::

 :::
 This step ensures that the condition `minsize` ≤ `T` ≤
 `maxsize` holds. Additionnally, if the target values
 correspond to symmetric stretching with respect to the [math
 axis](#dfn-math-axis) then property `T`~`ascent`~ −
 [AxisHeight](#dfn-axisheight) = `T`~`descent`~ +
 [AxisHeight](#dfn-axisheight) is preserved.
 :::
 :::::
 6. The [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size),
 [ink
 line-ascent](#dfn-ink-line-ascent), [ink
 line-descent](#dfn-ink-line-descent),
 [line-ascent](#dfn-line-ascent) and
 [line-descent](#dfn-line-descent) of the math content are obtained
 by the algorithm to [shape a stretchy
 glyph](#dfn-shape-a-stretchy-glyph) `g` to [block
 dimension](https://www.w3.org/TR/css-writing-modes-4/#block-dimension)
 `T`~`ascent`~ + `T`~`descent`~. The [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size)
 of the math content is the width of the stretchy glyph. The
 stretchy glyph is shifted towards the
 [line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under)
 by a value Δ so that its center aligns with the center of the
 target: the ink ascent of the math content is the ascent of
 the stretchy glyph − Δ and the ink descent of the math content
 is the descent of the stretchy glyph + Δ. These centers have
 coordinates \"½(ascent − descent)\" so Δ = \[(ascent of
 stretchy glyph − descent of stretchy glyph) − (`T`~`ascent`~ −
 `T`~`descent`~)\] / 2.
 7. The painting of the operator is performed by the algorithm to
 [shape a stretchy
 glyph](#dfn-shape-a-stretchy-glyph) `g` stretched to [block
 dimension](https://www.w3.org/TR/css-writing-modes-4/#block-dimension)
 `T`~`ascent`~ + `T`~`descent`~ and at position determined by
 the previous box metrics shifted by Δ towards the
 [line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over).

 ![[Figure 7](#figure-base-variants-and-assembly) [Base
 size, size variants and glyph assembly for the left
 brace]](figures/bracesize.svg)
3. If the operator has the
 [`largeop`](#dfn-largeop) property and if
 [`math-style`](#propdef-math-style) on the `<mo>` element is `normal`,
 then:
 1. If it is not possible to [shape a stretchy
 glyph](#dfn-shape-a-stretchy-glyph) `g` in the block direction with
 the [first available
 font](https://www.w3.org/TR/css-fonts-4/#first-available-font)
 then fall back to the layout algorithm of [3.2.1.1 Layout of
 `<mtext>`](#layout-of-mtext).

 :::::
 :::
 Note
 :::

 :::
 Here we treat a
 non-[`stretchy`](#dfn-stretchy)
 [`largeop`](#dfn-largeop) glyph as stretchy with target
 dimension
 [DisplayOperatorMinHeight](#dfn-displayoperatorminheight).
 :::
 :::::
 2. The [min-content inline
 size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
 and [max-content inline
 size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size)
 of the math content are set to the [preferred inline size of a
 glyph stretched along the block
 axis](#dfn-preferred-inline-size-of-a-glyph-stretched-along-the-block-axis).
 3. The [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size),
 [ink
 line-ascent](#dfn-ink-line-ascent), [ink
 line-descent](#dfn-ink-line-descent),
 [line-ascent](#dfn-line-ascent) and
 [line-descent](#dfn-line-descent) of the math content are obtained
 by the algorithm to [shape a stretchy
 glyph](#dfn-shape-a-stretchy-glyph) `g` to [block
 dimension](https://www.w3.org/TR/css-writing-modes-4/#block-dimension)
 [DisplayOperatorMinHeight](#dfn-displayoperatorminheight). The [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of
 the math content is the width of the stretchy glyph. The
 stretchy glyph is shifted towards the
 [line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under)
 by a value Δ so that its center aligns with the center of the
 target when
 [`symmetric`](#dfn-symmetric): the ink ascent of the
 math content is the ascent of the stretchy glyph − Δ and the ink
 descent of the math content is the descent of the stretchy
 glyph + Δ.
 - If the operator has the
 [`symmetric`](#dfn-symmetric) property, then Δ =
 \[(ascent of stretchy glyph − descent of stretchy glyph) − 2
 \* [AxisHeight](#dfn-axisheight)\] / 2.
 - Otherwise, Δ = 0.

 :::::
 :::
 Note
 :::

 :::
 The point of Δ here is simply to vertically align the operator
 when [`symmetric`](#dfn-symmetric).
 :::
 :::::
 4. The painting of the operator is performed by the algorithm to
 [shape a stretchy
 glyph](#dfn-shape-a-stretchy-glyph) `g` stretched to [block
 dimension](https://www.w3.org/TR/css-writing-modes-4/#block-dimension)
 [DisplayOperatorMinHeight](#dfn-displayoperatorminheight) and at position determined by the
 previous box metrics shifted by Δ towards the
 [line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over).

 ![[Figure 8](#figure-sum-base-and-displastyle-sizes)
 [Base and displaystyle sizes of the summation
 symbol]](figures/sumsize.svg)
4. Otherwise fall back to the layout algorithm of [3.2.1.1 Layout of
 `<mtext>`](#layout-of-mtext).

If the algorithm to [shape a stretchy
glyph](#dfn-shape-a-stretchy-glyph) has been used for one of the step above,
then the [italic
correction](#dfn-italic-correction) of the math content is set to the value
returned by that algorithm.

::: header-wrapper
#### 3.2.5 Space `<mspace>`

The [mspace] empty element represents a blank space
of any desired size, as set by its attributes.

The `<mspace>` element accepts the attributes described in [2.1.3 Global
Attributes](#global-attributes) as well as the following
attributes:

- [`width`](#attribute-mspace-width)
- [`height`](#attribute-mspace-height)
- [`depth`](#attribute-mspace-depth)

The [width],
[height],
[depth],
if present, must have a value that is a valid
[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage).

- If the `width` attribute is present, valid and not a percentage then
 that attribute is used as a [presentational
 hint](https://html.spec.whatwg.org/#presentational-hints) setting the
 element\'s
 [width](https://www.w3.org/TR/css-sizing-3/#propdef-width)
 property to the corresponding value.
- If the `height` attribute is absent, invalid or a percentage then the
 requested line-ascent is `0`. Otherwise the requested line-ascent is
 the resolved value of the `height` attribute, clamping negative values
 to `0`.
- If both the `height` and `depth` attributes are present, valid and not
 a percentage then they are used as a [presentational
 hint](https://html.spec.whatwg.org/#presentational-hints) setting the
 element\'s
 [height](https://www.w3.org/TR/css-sizing-3/#propdef-height)
 property to the concatenation of the strings \"`calc(`\", the `height`
 attribute value, \"` + `\", the `depth` attribute value, and \"`)`\".
 If only one of these attributes is present, valid and not a percentage
 then it is treated as a [presentational
 hint](https://html.spec.whatwg.org/#presentational-hints) setting the
 element\'s
 [height](https://www.w3.org/TR/css-sizing-3/#propdef-height)
 property to the corresponding value.

In the following example, [`mspace`](#dfn-mspace) is used to force spacing within the
formula (a 1px blue border is added to easily visualize the space):

``` {aria-busy="false"}
<math>
 <mn>1</mn>
 <mspace width="1em"
 style="border-top: 1px solid blue"/>
 <mfrac>
 <mrow>
 <mn>2</mn>
 <mspace depth="1em"
 style="border-left: 1px solid blue"/>
 </mrow>
 <mrow>
 <mn>3</mn>
 <mspace height="2em"
 style="border-left: 1px solid blue"/>
 </mrow>
 </mfrac>
</math>
```

![mspace example](examples/example-mspace.png)

If the `<mspace>` element does not have its computed
[`display`](#dfn-display) property equal to `block math` or
`inline math` then it is laid out according to the CSS specification
where the corresponding value is described. Otherwise, the `<mspace>`
element is laid out as shown on [Figure
9](#figure-box-mspace "Box model for the <mspace> element").
The [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size),
[max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size)
and [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content are equal to the resolved value of the
[width](https://www.w3.org/TR/css-sizing-3/#propdef-width)
property. The [block
size](https://www.w3.org/TR/css-writing-modes-4/#block-size) of the math
content is equal to the resolved value of the
[height](https://www.w3.org/TR/css-sizing-3/#propdef-height)
property. The [line-ascent](#dfn-line-ascent) of the math content is equal to the
requested line-ascent determined above.

![[Figure 9](#figure-box-mspace) [Box model for the
`<mspace>`
element]](figures/mspacebox.svg)

The terminology height/depth comes from
\[[MATHML3](#bib-mathml3 "Mathematical Markup Language (MathML) Version 3.0 2nd Edition")\], itself inspired from
\[[TEXBOOK](#bib-texbook "The TeXBook")\].

::: header-wrapper
##### 3.2.5.1 Definition of space-like elements

A number of MathML presentation elements are \"space-like\" in the sense
that they typically render as whitespace, and do not affect the
mathematical meaning of the expressions in which they appear. As a
consequence, these elements often function in somewhat exceptional ways
in other MathML expressions.

A [MathML Core
element](#dfn-mathml-core-elements) is a [space-like element] if it is:

1. an [`mtext`](#dfn-mtext) or
 [`mspace`](#dfn-mspace);
2. or a [grouping
 element](#dfn-grouping-elements) or
 [`mpadded`](#dfn-mpadded) all of whose
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 children are [space-like](#dfn-space-like).

The same definitions apply for boxes in the visual formatting model
where an [anonymous \<mrow\>
box](#dfn-anonymous-mrow-box) is treated as a [grouping
element](#dfn-grouping-elements).

Note that an [`mphantom`](#dfn-mphantom) is not automatically defined to be
space-like, unless its content is space-like. This is because operator
spacing is affected by whether adjacent elements are space-like. Since
the `<mphantom>` element is primarily intended as an aid in aligning
expressions, operators adjacent to an `<mphantom>` should behave as if
they were adjacent to the contents of the `<mphantom>`, rather than to
an equivalently sized area of whitespace.

::: header-wrapper
#### 3.2.6 String Literal `<ms>`

[ms] element is used to represent \"string
literals\" in expressions meant to be interpreted by computer algebra
systems or other systems containing \"programming languages\".

The `<ms>` element accepts the attributes described in [2.1.3 Global
Attributes](#global-attributes). Its layout algorithm is the
same as the [`mtext`](#dfn-mtext) element.

In the following example, [`ms`](#dfn-ms) is used to write a literal string of characters:

``` {aria-busy="false"}
<math>
 <mi>s</mi>
 <mo>=</mo>
 <ms>"hello world"</ms>
</math>
```

![ms example](examples/example-ms.png)

In MathML3, it was possible to use the `lquote` and `rquote` attributes
to respectively specify the strings to use as opening and closing
quotes. These are no longer supported and the quotes must instead be
specified as part of the text of the `<ms>` element. One can add CSS
rules to legacy documents in order to preserve visual rendering. For
example, in left-to-right direction:

``` {aria-busy="false"}
ms:before, ms:after {
 content: "\0022";
}
ms[lquote]:before {
 content: attr(lquote);
}
ms[rquote]:after {
 content: attr(rquote);
}
```

::: header-wrapper
### 3.3 General Layout Schemata

Besides tokens there are several families of MathML presentation
elements. One family of elements deals with various \"scripting\"
notations, such as subscript and superscript. Another family is
concerned with matrices and tables. The remainder of the elements,
discussed in this section, describe other basic notations such as
fractions and radicals, or deal with general functions such as setting
style properties and error handling.

::: header-wrapper
#### 3.3.1 Group Sub-Expressions `<mrow>`

The [mrow] element is used to group together any
number of sub-expressions, usually consisting of one or more `<mo>`
elements acting as \"operators\" on one or more other expressions that
are their \"operands\".

In the following example, [`mrow`](#dfn-mrow) is used to group a sum \"1 + 2/3\" as
a fraction numerator (first child of
[`mfrac`](#dfn-mfrac)) and to construct a fenced expression (first child
of [`msup`](#dfn-msup)) that is raised to the power of 5. Note that
[`mrow`](#dfn-mrow) alone does not add visual fences around its grouped
content, one has to explicitly specify them using the
[`mo`](#dfn-mo)
element.

Within the [`mrow`](#dfn-mrow) elements, one can see that vertical alignment of
children (according to the [alphabetic
baseline](#dfn-alphabetic-baseline) or the [mathematical
baseline](#dfn-mathematical-baseline)) is properly performed, fences are
vertically stretched and spacing around the binary + operator
automatically calculated.

``` {aria-busy="false"}
<math>
 <msup>
 <mrow>
 <mo>(</mo>
 <mfrac>
 <mrow>
 <mn>1</mn>
 <mo>+</mo>
 <mfrac>
 <mn>2</mn>
 <mn>3</mn>
 </mfrac>
 </mrow>
 <mn>4</mn>
 </mfrac>
 <mo>)</mo>
 </mrow>
 <mn>5</mn>
 </msup>
</math>
```

![mrow example](examples/example-mrow.png)

The `<mrow>` element accepts the attributes described in [2.1.3 Global
Attributes](#global-attributes). An `<mrow>` element with
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children child~1~, child~2~, ..., child~N~ is laid out as shown on
[Figure
10](#figure-box-mrow "Box model for the <mrow> element"). The
child boxes are put in a row one after the other with all their
[alphabetic
baselines](#dfn-alphabetic-baseline) aligned.

![[Figure 10](#figure-box-mrow) [Box model for the `<mrow>`
element]](figures/mrowbox.svg)

Because the box model ensures alignment of [alphabetic
baselines](#dfn-alphabetic-baseline), fraction bars or symmetric stretchy
operators will also be aligned along the [math
axis](#dfn-math-axis) in the typical case when
[AxisHeight](#dfn-axisheight) is the same for all
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children.

::: header-wrapper
##### 3.3.1.1 Algorithm for stretching operators along the block axis

![[Figure
11](#symmetric-and-non-symmetric-vertical-stretching)
[Symmetric and non-symmetric stretching of operators along the [block
axis](https://www.w3.org/TR/css-writing-modes-4/#block-axis)]](figures/vstretch.svg)

The [algorithm for stretching operators along the block
axis] consists in the following steps:

1. If there is a [block stretch size
 constraint](#dfn-block-stretch-size-constraint) or an [inline stretch size
 constraint](#dfn-inline-stretch-size-constraint) then the element being laid out is an
 [embellished
 operator](#dfn-embellished-operator). Lay out the one
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 child that is an [embellished
 operator](#dfn-embellished-operator) with the same stretch size constraint
 and all the other
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 children without any stretch size constraint and stop.
2. Otherwise, split the list of
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 children into a first list `L`~`ToStretch`~ containing [embellished
 operators](#dfn-embellished-operator) with a
 [`stretchy`](#dfn-stretchy) property and block [stretch
 axis](#dfn-stretch-axis); and a second list `L`~`NotToStretch`~.
3. Perform layout without any stretch size constraint on all the items
 of `L`~`NotToStretch`~. If `L`~`ToStretch`~ is empty then stop. If
 `L`~`NotToStretch`~ is empty, perform layout with [block stretch
 size
 constraint](#dfn-block-stretch-size-constraint) `(0, 0)` for all the items of
 `L`~`ToStretch`~.
4. Calculate the unconstrained target sizes `U`~`ascent`~ and
 `U`~`descent`~ as respectively the maximum ink ascent and maximum
 ink descent of the [margin
 boxes](https://www.w3.org/TR/css-box-4/#margin-box)
 of
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 children that have been laid out in the previous step.
5. Lay out or relayout all the elements of `L`~`ToStretch`~ with [block
 stretch size
 constraint](#dfn-block-stretch-size-constraint) `(U`~`ascent`~`, U`~`descent`~`)`.

::: header-wrapper
##### 3.3.1.2 Layout of `<mrow>`

If the box is not an [anonymous \<mrow\>
box](#dfn-anonymous-mrow-box) and the associated element does not have
its computed [`display`](#dfn-display) property equal to `block math` or
`inline math` then it is laid out according to the CSS specification
where the corresponding value is described. Otherwise, the layout below
is performed.

A child box is [slanted] if it is not an [embellished
operator](#dfn-embellished-operator) and has nonzero [italic
correction](#dfn-italic-correction).

Large operators may have nonzero [italic
correction](#dfn-italic-correction) but that one is used when attaching
scripts. More generally, all [embellished
operators](#dfn-embellished-operator) are treated as non-slanted since the
spacing around them is calculated as specified by
[`lspace`](#dfn-lspace) and
[`rspace`](#dfn-rspace).

The [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
are calculated using the following algorithm:

1. Set `add-space` to true if the box corresponds to a
 [`math`](#dfn-math) element or is not an [embellished
 operator](#dfn-embellished-operator); and to false otherwise.
2. Set `inline-offset` to 0.
3. Set `previous-italic-correction` to 0.
4. For each
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 child:
 1. If the child is not
 [slanted](#dfn-slanted), then increment `inline-offset` by
 `previous-italic-correction`.
 2. If the child is an [embellished
 operator](#dfn-embellished-operator) and `add-space` is true then
 increment `inline-offset` by its
 [`lspace`](#dfn-lspace) property.
 3. Increment `inline-offset` by the [min-content inline
 size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
 (respectively [max-content inline
 size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
 of the child\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
 4. If the child is [slanted](#dfn-slanted) then set
 `previous-italic-correction` to its [italic
 correction](#dfn-italic-correction). Otherwise set it to 0.
 5. If the child is an [embellished
 operator](#dfn-embellished-operator) and `add-space` is true then
 increment `inline-offset` by its
 [`rspace`](#dfn-rspace) property.
5. Increment `inline-offset` by `previous-italic-correction`.
6. Return `inline-offset`.

The
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children are laid out using the [algorithm for stretching operators
along the block
axis](#dfn-algorithm-for-stretching-operators-along-the-block-axis).

The [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content is calculated like the [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
and [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size)
of the math content, using the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children\'s [margin
boxes](https://www.w3.org/TR/css-box-4/#margin-box)
instead.

The [ink
line-ascent](#dfn-ink-line-ascent) (respectively
[line-ascent](#dfn-line-ascent)) of the math content is the maximum of the [ink
line-ascents](#dfn-ink-line-ascent) (respectively
[line-ascents](#dfn-line-ascent)) of all the
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children\'s [margin
boxes](https://www.w3.org/TR/css-box-4/#margin-box).
Similarly, the [ink
line-descent](#dfn-ink-line-descent) (respectively
[line-descent](#dfn-line-descent)) of the math content is the maximum of the
[ink
line-descents](#dfn-ink-line-descent) (respectively [ink
line-ascents](#dfn-ink-line-ascent)) of all the
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children\'s [margin
boxes](https://www.w3.org/TR/css-box-4/#margin-box).

The
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children are positioned using the following algorithm:

1. Set `add-space` to true if the box corresponds to a
 [`math`](#dfn-math) element or is not an [embellished
 operator](#dfn-embellished-operator); and to false otherwise.
2. Set `inline-offset` to 0.
3. Set `previous-italic-correction` to 0.
4. For each
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 child:
 1. If the child is not
 [slanted](#dfn-slanted), then increment `inline-offset` by
 `previous-italic-correction`.
 2. If the child is an [embellished
 operator](#dfn-embellished-operator) and `add-space` is true then
 increment `inline-offset` by its
 [`lspace`](#dfn-lspace) property.
 3. Set the [inline
 offset](#dfn-inline-offset) of the child to `inline-offset`
 and its [block
 offset](#dfn-block-offset) such that the [alphabetic
 baseline](#dfn-alphabetic-baseline) of the child is aligned with the
 [alphabetic
 baseline](#dfn-alphabetic-baseline).
 4. Increment `inline-offset` by the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of
 the child\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
 5. If the child is [slanted](#dfn-slanted) then set
 `previous-italic-correction` to its [italic
 correction](#dfn-italic-correction). Otherwise set it to 0.
 6. If the child is an [embellished
 operator](#dfn-embellished-operator) and `add-space` is true then
 increment `inline-offset` by its
 [`rspace`](#dfn-rspace) property.

The [italic
correction](#dfn-italic-correction) of the math content is set to the italic
correction of the last
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child, which is the final value of `previous-italic-correction`.

::: header-wrapper
#### 3.3.2 Fractions `<mfrac>`

The [mfrac] element is used for fractions. It can
also be used to mark up fraction-like objects such as binomial
coefficients and Legendre symbols.

If the `<mfrac>` element does not have its computed
[`display`](#dfn-display) property equal to `block math` or
`inline math` then it is laid out according to the CSS specification
where the corresponding value is described. Otherwise, the layout below
is performed.

The `<mfrac>` element accepts the attributes described in [2.1.3 Global
Attributes](#global-attributes) as well as the following
attribute:

- [`linethickness`](#dfn-linethickness)

The [linethickness] attribute indicates the [fraction line
thickness] to use for the fraction bar. If
present, it must have a value that is a valid
[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage).
If the attribute is absent or has an invalid value,
[FractionRuleThickness](#dfn-fractionrulethickness) is used as the default value. A percentage
is interpreted relative to that default value. A negative value is
interpreted as 0.

The following example contains four fractions with different
[`linethickness`](#dfn-linethickness) values. The bars are always
aligned with the middle of plus and minus signs. The numerator and
denominator are horizontally centered. The fractions that are not in
[displaystyle](#dfn-displaystyle) use smaller gaps and font-size.

``` {aria-busy="false"}
<math>
 <mn>0</mn>
 <mo>+</mo>
 <mfrac displaystyle="true">
 <mn>1</mn>
 <mn>2</mn>
 </mfrac>
 <mo>−</mo>
 <mfrac>
 <mn>1</mn>
 <mn>2</mn>
 </mfrac>
 <mo>+</mo>
 <mfrac linethickness="200%">
 <mn>1</mn>
 <mn>234</mn>
 </mfrac>
 <mo>−</mo>
 <mrow>
 <mo>(</mo>
 <mfrac linethickness="0">
 <mn>123</mn>
 <mn>4</mn>
 </mfrac>
 <mo>)</mo>
 </mrow>
</math>
```

![mfrac example](examples/example-mfrac.png)

The `<mfrac>` element sets
[`displaystyle`](#dfn-displaystyle) to `false`, or if it was already `false`
increments [`scriptlevel`](#dfn-scriptlevel) by 1, within its children. It sets
[math-shift](#propdef-math-shift) to `compact` within its second child. To
avoid visual confusion between the fraction bar and another adjacent
items (e.g. minus sign or another fraction\'s bar), a default 1-pixel
space is added around the element. The [user agent
stylesheet](#dfn-user-agent-stylesheet) must contain the following rules:

``` {aria-busy="false"}
mfrac {
 padding-inline: 1px;
}
mfrac > * {
 math-depth: auto-add;
 math-style: compact;
}
mfrac > :nth-child(2) {
 math-shift: compact;
}
```

If the `<mfrac>` element has less or more than two
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children, its layout algorithm is the same as the
[`mrow`](#dfn-mrow) element. Otherwise, the first
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called [numerator], the second
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called [denominator] and the layout algorithm is
explained below.

In practice, an `<mfrac>` element has two children that are
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow).
Hence the CSS rules basically perform
[`scriptlevel`](#dfn-scriptlevel),
[`displaystyle`](#dfn-displaystyle) and
[math-shift](#propdef-math-shift) changes for the
[numerator](#dfn-numerator) and
[denominator](#dfn-denominator).

::: header-wrapper
##### 3.3.2.1 Fraction with nonzero line thickness

If the [fraction line
thickness](#dfn-fraction-line-thickness) is nonzero, the `<mfrac>` element is laid
out as shown on [Figure
12](#figure-box-mfrac "Box model for the <mfrac> element").
The fraction bar must only be painted if the
[visibility](https://www.w3.org/TR/css-display-3/#propdef-visibility)
of the `<mfrac>` element is `visible`. In that case, the fraction bar
must be painted with the
[color](https://www.w3.org/TR/css-color-4/#propdef-color)
of the `<mfrac>` element.

![[Figure 12](#figure-box-mfrac) [Box model for the
`<mfrac>` element]](figures/mfracbox.svg)

The [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of content is the maximum between the [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the [numerator](#dfn-numerator)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) and
the [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the [denominator](#dfn-denominator)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box).

If there is an [inline stretch size
constraint](#dfn-inline-stretch-size-constraint) or a [block stretch size
constraint](#dfn-block-stretch-size-constraint) then the
[numerator](#dfn-numerator) is also laid out with the same stretch size constraint,
otherwise it is laid out without any stretch size constraint. The
[denominator](#dfn-denominator) is always laid out without any stretch size constraint.

The [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content is the maximum between the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[numerator](#dfn-numerator)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) and
the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[denominator](#dfn-denominator)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box).

`NumeratorShift` is the maximum between:

- [FractionNumeratorShiftUp](#dfn-fractionnumeratorshiftup) (respectively
 [FractionNumeratorDisplayStyleShiftUp](#dfn-fractionnumeratordisplaystyleshiftup)) if the
 [math-style](#propdef-math-style) is `compact` (respectively `normal`).
- The [AxisHeight](#dfn-axisheight) + half the [fraction line
 thickness](#dfn-fraction-line-thickness) +
 [FractionNumeratorGapMin](#dfn-fractionnumeratorgapmin) (respectively
 [FractionNumDisplayStyleGapMin](#dfn-fractionnumdisplaystylegapmin)) if the
 [math-style](#propdef-math-style) is `compact` (respectively `normal`) +
 the [ink
 line-descent](#dfn-ink-line-descent) of the
 [numerator](#dfn-numerator)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).

`DenominatorShift` is the maximum between:

- [FractionDenominatorShiftDown](#dfn-fractiondenominatorshiftdown) (respectively
 [FractionDenominatorDisplayStyleShiftDown](#dfn-fractiondenominatordisplaystyleshiftdown)) if the
 [math-style](#propdef-math-style) is `compact` (respectively `normal`).
- Half the [fraction line
 thickness](#dfn-fraction-line-thickness) +
 [FractionDenominatorGapMin](#dfn-fractiondenominatorgapmin) (respectively
 [FractionDenomDisplayStyleGapMin](#dfn-fractiondenomdisplaystylegapmin)) if the
 [math-style](#propdef-math-style) is `compact` (respectively `normal`) +
 the [ink
 line-ascent](#dfn-ink-line-ascent) of the
 [denominator](#dfn-denominator)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) −
 the [AxisHeight](#dfn-axisheight).

The [line-ascent](#dfn-line-ascent) of the math content is the maximum
between:

- `Numerator Shift` + the
 [line-ascent](#dfn-line-ascent) of the
 [numerator](#dfn-numerator)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- −`Denominator Shift` + the
 [line-ascent](#dfn-line-ascent) of the
 [denominator](#dfn-denominator)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box)
- [AxisHeight](#dfn-axisheight) plus half the [fraction line
 thickness](#dfn-fraction-line-thickness).

The [line-descent](#dfn-line-descent) of the math content is the maximum
between:

- −`Numerator Shift` + the
 [line-descent](#dfn-line-descent) of the
 [numerator](#dfn-numerator)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- `Denominator Shift` + the
 [line-descent](#dfn-line-descent) of the
 [denominator](#dfn-denominator)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- −[AxisHeight](#dfn-axisheight) plus half the [fraction line
 thickness](#dfn-fraction-line-thickness).
- 0

The [inline offset](#dfn-inline-offset) of the
[numerator](#dfn-numerator) (respectively
[denominator](#dfn-denominator)) is half the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content − half the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[numerator](#dfn-numerator)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box)
(respectively [denominator](#dfn-denominator)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box)).

The [alphabetic
baseline](#dfn-alphabetic-baseline) of the
[numerator](#dfn-numerator) (respectively
[denominator](#dfn-denominator)) is shifted away from the [alphabetic
baseline](#dfn-alphabetic-baseline) by a distance of `NumeratorShift`
(respectively `DenominatorShift`) towards the
[line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over)
(respectively
[line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under)).

The [math content
box](#dfn-math-content-box) is placed within the [content
box](https://www.w3.org/TR/css-box-4/#content-box) so
that their block-start edges are aligned and the middles of these edges
are at the same position.

The [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
fraction bar is the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[content
box](https://www.w3.org/TR/css-box-4/#content-box) and
its inline-start edge is the aligned with the one the [content
box](https://www.w3.org/TR/css-box-4/#content-box). The
center of the fraction bar is shifted away from the [alphabetic
baseline](#dfn-alphabetic-baseline) of the [math content
box](#dfn-math-content-box) by a distance of
[AxisHeight](#dfn-axisheight) towards the
[line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over).
Its [block size](https://www.w3.org/TR/css-writing-modes-4/#block-size)
is the [fraction line
thickness](#dfn-fraction-line-thickness).

::: header-wrapper
##### 3.3.2.2 Fraction with zero line thickness

If the [fraction line
thickness](#dfn-fraction-line-thickness) is zero, the `<mfrac>` element is instead
laid out as shown on [Figure
13](#figure-box-mfrac-without-bar "Box model for the <mfrac> element without bar").

![[Figure 13](#figure-box-mfrac-without-bar) [Box model for
the `<mfrac>` element without
bar]](figures/mfracnobarbox.svg)

The [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size),
[max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size)
and [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content are calculated the same as in [3.3.2.1 Fraction with
nonzero line
thickness](#fraction-with-nonzero-line-thickness).

If there is an [inline stretch size
constraint](#dfn-inline-stretch-size-constraint) or a [block stretch size
constraint](#dfn-block-stretch-size-constraint) then the
[numerator](#dfn-numerator) is also laid out with the same stretch size constraint
and otherwise it is laid out without any stretch size constraint. The
[denominator](#dfn-denominator) is always laid out without any stretch size constraint.

If the [math-style](#propdef-math-style) is `compact` then `TopShift` and
`BottomShift` are respectively set to
[StackTopShiftUp](#dfn-stacktopshiftup) and
[StackBottomShiftDown](#dfn-stackbottomshiftdown). Otherwise
[math-style](#propdef-math-style) is `normal` and they are respectively set
to
[StackTopDisplayStyleShiftUp](#dfn-stacktopdisplaystyleshiftup) and
[StackBottomDisplayStyleShiftDown](#dfn-stackbottomdisplaystyleshiftdown).

The `Gap` is defined to be (`BottomShift` − the [ink
line-ascent](#dfn-ink-line-ascent) of the
[denominator](#dfn-denominator)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box)) +
(`TopShift` − the [ink
line-descent](#dfn-ink-line-descent) of the
[numerator](#dfn-numerator)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box)). If
[math-style](#propdef-math-style) is `compact` then `GapMin` is
[StackGapMin](#dfn-stackgapmin), otherwise
[math-style](#propdef-math-style) is `normal` and it is
[StackDisplayStyleGapMin](#dfn-stackdisplaystylegapmin). If Δ = `GapMin` − `Gap` is positive then
`TopShift` and `BottomShift` are respectively increased by Δ/2 and Δ −
Δ/2.

The [line-ascent](#dfn-line-ascent) of the math content is the maximum
between:

- `TopShift` + the
 [line-ascent](#dfn-line-ascent) of the
 [numerator](#dfn-numerator)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- −`BottomShift` + the
 [line-ascent](#dfn-line-ascent) of the
 [denominator](#dfn-denominator)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).

The [line-descent](#dfn-line-descent) of the math content is the maximum
between:

- −`TopShift` + the
 [line-descent](#dfn-line-descent) of the
 [numerator](#dfn-numerator)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- `BottomShift` + the
 [line-descent](#dfn-line-descent) of the
 [denominator](#dfn-denominator)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- 0

The [inline offsets](#dfn-inline-offset) of the
[numerator](#dfn-numerator) and
[denominator](#dfn-denominator) are calculated the same as in [3.3.2.1 Fraction with
nonzero line
thickness](#fraction-with-nonzero-line-thickness).

The [alphabetic
baseline](#dfn-alphabetic-baseline) of the
[numerator](#dfn-numerator) (respectively
[denominator](#dfn-denominator)) is shifted away from the [alphabetic
baseline](#dfn-alphabetic-baseline) by a distance of `TopShift` (respectively
− `BottomShift`) towards the
[line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over)
(respectively
[line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under)).

The [math content
box](#dfn-math-content-box) is placed within the [content
box](https://www.w3.org/TR/css-box-4/#content-box) so
that their block-start edges are aligned and the middles of these edges
are at the same position.

::: header-wrapper
#### 3.3.3 Radicals `<msqrt>`, `<mroot>`

The [radical
elements](#dfn-radical-elements) construct an expression with a root symbol
√ with a line over the content. The [msqrt]
element is used for square roots, while the [mroot] element is used to draw radicals with indices, e.g. a cube
root.

The `<msqrt>` and `<mroot>` elements accept the attributes described in
[2.1.3 Global Attributes](#global-attributes).

The following example contains a square root written with
[`msqrt`](#dfn-msqrt) and a cube root written with
[`mroot`](#dfn-mroot). Note that
[`msqrt`](#dfn-msqrt) has several children and the square root applies to
all of them. [`mroot`](#dfn-mroot) has exactly two children: it is a root of index the
second child (the number 3), applied to the first child (the square
root). Also note these elements only change the font-size within the
[`mroot`](#dfn-mroot) index, but it is scaled down more than within the
numerator and denumerator of the fraction.

``` {aria-busy="false"}
<math>
 <mroot>
 <msqrt>
 <mfrac>
 <mn>1</mn>
 <mn>2</mn>
 </mfrac>
 <mo>+</mo>
 <mn>4</mn>
 </msqrt>
 <mn>3</mn>
 </mroot>
 <mo>+</mo>
 <mn>0</mn>
</math>
```

![msqrt-mroot example](examples/example-msqrt-mroot.png)

The `<msqrt>` and `<mroot>` elements sets
[math-shift](#propdef-math-shift) to `compact`. The `<mroot>` element
increments [`scriptlevel`](#dfn-scriptlevel) by 2, and sets
[`displaystyle`](#dfn-displaystyle) to \"false\" in all but its first child.
The [user agent
stylesheet](#dfn-user-agent-stylesheet) must contain the following rule in order
to implement that behavior:

``` {aria-busy="false"}
mroot > :not(:first-child) {
 math-depth: add(2);
 math-style: compact;
}
mroot, msqrt {
 math-shift: compact;
}
```

If the `<msqrt>` or `<mroot>` element do not have their computed
[`display`](#dfn-display) property equal to `block math` or
`inline math` then they are laid out according to the CSS specification
where the corresponding value is described. Otherwise, the layout below
is performed.

If the `<mroot>` has less or more than two
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children, its layout algorithm is the same as the
[`mrow`](#dfn-mrow) element. Otherwise, the first
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called [mroot base] and the second
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called [mroot index] and its layout algorithm is
explained below.

In practice, an `<mroot>` element has two children that are
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow).
Hence the CSS rules basically perform
[`scriptlevel`](#dfn-scriptlevel) and
[`displaystyle`](#dfn-displaystyle) changes for the index.

The `<msqrt>` element [generates an anonymous \<mrow\>
box](#dfn-generates-an-anonymous-mrow-box) called the [msqrt base].

::: header-wrapper
##### 3.3.3.1 Radical symbol

The radical symbol must only be painted if the
[visibility](https://www.w3.org/TR/css-display-3/#propdef-visibility)
of the `<msqrt>` or `<mroot>` element is `visible`. In that case, the
radical symbol must be painted with the
[color](https://www.w3.org/TR/css-color-4/#propdef-color)
of that element.

Let `dir` be the computed
[direction](https://www.w3.org/TR/css-writing-modes-4/#propdef-direction)
of the `<msqrt>` or `<mroot>` element. The [radical
glyph] is the glyph obtained as a result of running [get a
glyph](#dfn-get-a-glyph) corresponding to the U+221A SQUARE ROOT character given
`dir`.

The [radical gap] is given by
[RadicalVerticalGap](#dfn-radicalverticalgap) if the
[math-style](#propdef-math-style) is `compact` and
[RadicalDisplayStyleVerticalGap](#dfn-radicaldisplaystyleverticalgap) if the
[math-style](#propdef-math-style) is `normal`.

The radical target size for the stretchy radical glyph is the sum of
[RadicalRuleThickness](#dfn-radicalrulethickness), [radical
gap](#dfn-radical-gap) and the ink height of the base.

The [box metrics of the radical
glyph] and [painting of the
surd] are given by the algorithm to [shape a stretchy
glyph](#dfn-shape-a-stretchy-glyph) to the target size for the radical glyph
in the [block
dimension](https://www.w3.org/TR/css-writing-modes-4/#block-dimension).

::: header-wrapper
##### 3.3.3.2 Square root

The `<msqrt>` element is laid out as shown on [Figure
14](#figure-box-msqrt "Box model for the <msqrt> element").

![[Figure 14](#figure-box-msqrt) [Box model for the
`<msqrt>` element]](figures/msqrtbox.svg)

The [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the math content is the sum of the [preferred inline size of a glyph
stretched along the block
axis](#dfn-preferred-inline-size-of-a-glyph-stretched-along-the-block-axis) for the [radical
glyph](#dfn-radical-glyph) and of the [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the [msqrt base](#dfn-msqrt-base)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box).

The [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content is the sum of the advance width of the [box metrics of the
radical
glyph](#dfn-box-metrics-of-the-radical-glyph) and of the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[msqrt base](#dfn-msqrt-base)\'s margin\'s box.

The [line-ascent](#dfn-line-ascent) of the math content is the maximum
between:

- The [line-ascent](#dfn-line-ascent) of the [msqrt
 base](#dfn-msqrt-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- The sum of the [ink
 line-ascent](#dfn-ink-line-ascent) of the [msqrt
 base](#dfn-msqrt-base), the [radical
 gap](#dfn-radical-gap), the
 [RadicalRuleThickness](#dfn-radicalrulethickness) and
 [RadicalExtraAscender](#dfn-radicalextraascender).

The [line-descent](#dfn-line-descent) of the math content is the maximum
between:

- The [line-descent](#dfn-line-descent) of the [msqrt
 base](#dfn-msqrt-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- The sum of the
 [line-ascent](#dfn-line-ascent) and
 [line-descent](#dfn-line-descent) for the [box metrics of the radical
 glyph](#dfn-box-metrics-of-the-radical-glyph) and of the
 [RadicalExtraAscender](#dfn-radicalextraascender), minus the
 [line-ascent](#dfn-line-ascent) of the math content.

The [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
overbar is the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[msqrt base](#dfn-msqrt-base)\'s margin\'s box. The [inline
offsets](#dfn-inline-offset) of the [msqrt
base](#dfn-msqrt-base) and overbar are also the same and equal to the width of
the [box metrics of the radical
glyph](#dfn-box-metrics-of-the-radical-glyph).

The [alphabetic
baseline](#dfn-alphabetic-baseline) of the [msqrt
base](#dfn-msqrt-base) is aligned with the [alphabetic
baseline](#dfn-alphabetic-baseline). The [block
size](https://www.w3.org/TR/css-writing-modes-4/#block-size) of the
overbar is
[RadicalRuleThickness](#dfn-radicalrulethickness). Its vertical center is shifted away from
the [alphabetic
baseline](#dfn-alphabetic-baseline) by a distance towards the
[line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over)
equal to the [line-ascent](#dfn-line-ascent) of the math content, minus the
[RadicalExtraAscender](#dfn-radicalextraascender), minus half the
[RadicalRuleThickness](#dfn-radicalrulethickness).

Finally, the [painting of the
surd](#dfn-painting-of-the-surd) is performed:

- At [inline offset](#dfn-inline-offset) 0.
- At [block offset](#dfn-block-offset) shifted away from the
 [line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over)
 edge of the overbar towards the
 [line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under)
 by a distance given by the ascent of the [box metrics of the radical
 glyph](#dfn-box-metrics-of-the-radical-glyph).

::: header-wrapper
##### 3.3.3.3 Root with index

The `<mroot>` element is laid out as shown on [Figure
15](#figure-box-mroot "Box model for the <mroot> element").
The [mroot index](#dfn-mroot-index) is first ignored and the [mroot
base](#dfn-mroot-base) and radical glyph are laid out as shown on figure
[Figure
14](#figure-box-msqrt "Box model for the <msqrt> element")
using the same algorithm as in [3.3.3.2 Square
root](#square-root) in order to produce a margin box B
(represented in green).

![[Figure 15](#figure-box-mroot) [Box model for the
`<mroot>` element]](figures/mrootbox.svg)

The [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the math content is the sum of max(0,
[RadicalKernBeforeDegree](#dfn-radicalkernbeforedegree)), the [mroot
index](#dfn-mroot-index)\'s [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the [mroot index](#dfn-mroot-index)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box),
max(−[min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size),
[RadicalKernAfterDegree](#dfn-radicalkernafterdegree)) (respectively max(−[max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size)
of the [mroot index](#dfn-mroot-index)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box),
[RadicalKernAfterDegree](#dfn-radicalkernafterdegree))) and of the [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of B.

Using the same clamping,
[AdjustedRadicalKernBeforeDegree] and
[AdjustedRadicalKernAfterDegree] are
respectively defined as max(0,
[RadicalKernBeforeDegree](#dfn-radicalkernbeforedegree)) and is max(−[inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
index\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box),
[RadicalKernAfterDegree](#dfn-radicalkernafterdegree)).

The [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content is the sum of
[AdjustedRadicalKernBeforeDegree](#dfn-adjustedradicalkernbeforedegree), the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
index\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box),
[AdjustedRadicalKernAfterDegree](#dfn-adjustedradicalkernafterdegree) and of the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of B.

The [line-ascent](#dfn-line-ascent) of the math content is the maximum
between:

- −the [line-descent](#dfn-line-descent) of B +
 [RadicalDegreeBottomRaisePercent](#dfn-radicaldegreebottomraisepercent) × the [block
 size](https://www.w3.org/TR/css-writing-modes-4/#block-size) of B +
 the [line-ascent](#dfn-line-ascent) of the index\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box)
- The [line-ascent](#dfn-line-ascent) of B

The [line-descent](#dfn-line-descent) of the math content is the maximum
between:

- the [line-descent](#dfn-line-descent) of B −
 [RadicalDegreeBottomRaisePercent](#dfn-radicaldegreebottomraisepercent) × the [block
 size](https://www.w3.org/TR/css-writing-modes-4/#block-size) of B +
 the [line-ascent](#dfn-line-ascent) of the index\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box)
- The [line-descent](#dfn-line-descent) of B

The [inline offset](#dfn-inline-offset) of the index is
[AdjustedRadicalKernBeforeDegree](#dfn-adjustedradicalkernbeforedegree). The inline-offset of the [mroot
base](#dfn-mroot-base) is the same + the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
index\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box).

The [alphabetic
baseline](#dfn-alphabetic-baseline) of B is aligned with the [alphabetic
baseline](#dfn-alphabetic-baseline). The [alphabetic
baseline](#dfn-alphabetic-baseline) of the index is shifted away from the
[line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under)
edge by a distance of
[RadicalDegreeBottomRaisePercent](#dfn-radicaldegreebottomraisepercent) × the [block
size](https://www.w3.org/TR/css-writing-modes-4/#block-size) of B + the
[line-descent](#dfn-line-descent) of the index\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box).

In general, the kerning before the root index is positive while the
kerning after it is negative, which means that the root element will
have some inline-start space and that the root index will overlap the
surd.

::: header-wrapper
#### 3.3.4 Style Change `<mstyle>`

Historically, the [mstyle] element was introduced to
make style changes that affect the rendering of its contents.

The `<mstyle>` element accepts the attributes described in [2.1.3 Global
Attributes](#global-attributes). Its layout algorithm is the
same as the [`mrow`](#dfn-mrow) element.

`<mstyle>` is implemented for compatibility with full MathML. Authors
whose only target is MathML Core are encouraged to use CSS for styling.

In the following example, [`mstyle`](#dfn-mstyle) is used to set the
[scriptlevel](#dfn-scriptlevel) and
[displaystyle](#dfn-displaystyle). Observe this is respectively affecting
the font-size and placement of subscripts of their descendants. In
MathML Core, one could just have used
[`mrow`](#dfn-mrow) elements instead.

``` {aria-busy="false"}
<math>
 <munder>
 <mo movablelimits="true">*</mo>
 <mi>A</mi>
 </munder>
 <mstyle script>
 <mstyle displaystyle="true">
 <munder>
 <mo movablelimits="true">*</mo>
 <mi>B</mi>
 </munder>
 <munder>
 <mo movablelimits="true">*</mo>
 <mi>C</mi>
 </munder>
 </mstyle>
 <munder>
 <mo movablelimits="true">*</mo>
 <mi>D</mi>
 </munder>
 </mstyle>
</math>
```

![mstyle example](examples/example-mstyle.png)

::: header-wrapper
#### 3.3.5 Error Message `<merror>`

The [merror] element displays its contents as an
"error message". The intent of this element is to provide a standard way
for programs that generate MathML from other input to report syntax
errors in their input.

In the following example, [`merror`](#dfn-merror) is used to indicate a parsing error
for some LaTeX-like input:

``` {aria-busy="false"}
<math>
 <mfrac>
 <merror>
 <mtext>Syntax error: \frac{1}</mtext>
 </merror>
 <mn>3</mn>
 </mfrac>
</math>
```

![merror example](examples/example-merror.png)

The `<merror>` element accepts the attributes described in [2.1.3 Global
Attributes](#global-attributes). Its layout algorithm is the
same as the [`mrow`](#dfn-mrow) element. The [user agent
stylesheet](#dfn-user-agent-stylesheet) must contain the following rule in order
to visually highlight the error message:

``` {aria-busy="false"}
merror {
 border: 1px solid red;
 background-color: lightYellow;
}
```

::: header-wrapper
#### 3.3.6 Adjust Space Around Content `<mpadded>`

The [mpadded] element renders the same as its
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child content, but with the size and relative positioning point of its
content modified according to `<mpadded>`'s attributes.

The `<mpadded>` element accepts the attributes described in [2.1.3
Global Attributes](#global-attributes) as well as the
following attributes:

- [`width`](#attribute-mpadded-width)
- [`height`](#attribute-mpadded-height)
- [`depth`](#attribute-mpadded-depth)
- [`lspace`](#attribute-mpadded-lspace)
- [`voffset`](#attribute-mpadded-voffset)

The [width], [height],
[depth],
[lspace]
and [voffset] if present, must have a value that is
a valid
[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage).

In the following example,
[`mpadded`](#dfn-mpadded) is used to tweak spacing around a fraction (a blue
background is used to visualize it). Without attributes, it behaves like
an [`mrow`](#dfn-mrow) but the attributes allow to specify the size of the
box (width, height, depth) and position of the fraction within that box
(lspace and voffset).

``` {aria-busy="false"}
<math>
 <mrow>
 <mn>1</mn>
 <mpadded style="background: lightblue;">
 <mfrac>
 <mn>23456</mn>
 <mn>78</mn>
 </mfrac>
 </mpadded>
 <mn>9</mn>
 </mrow>
 <mo>+</mo>
 <mrow>
 <mn>1</mn>
 <mpadded lspace="2em" voffset="-1em" height="1em" depth="3em" width="7em"
 style="background: lightblue;">
 <mfrac>
 <mn>23456</mn>
 <mn>78</mn>
 </mfrac>
 </mpadded>
 <mn>9</mn>
 </mrow>
</math>
```

![mpadded example](examples/example-mpadded.png)

::: header-wrapper
##### 3.3.6.1 Inner box and requested parameters

The [`mpadded`](#dfn-mpadded) element [generates an anonymous \<mrow\>
box](#dfn-generates-an-anonymous-mrow-box) called the [mpadded inner
box] with parameters called inner inline size, inner
[line-ascent](#dfn-line-ascent) and inner line-descent.

The requested `<mpadded>` parameters are determined as follows:

- The requested width is the resolved value of the
 [width](https://www.w3.org/TR/css-sizing-3/#propdef-width)
 property. If the `width` attribute is present, valid and not a
 percentage then that attribute is used as a [presentational
 hint](https://html.spec.whatwg.org/#presentational-hints) setting the
 element\'s
 [width](https://www.w3.org/TR/css-sizing-3/#propdef-width)
 property to the corresponding value.
- If the `height` attribute is absent, invalid or a percentage then the
 requested height is the inner
 [line-ascent](#dfn-line-ascent). Otherwise the requested height is the
 resolved value of the `height` attribute, clamping negative values to
 `0`.
- If the `depth` attribute is absent, invalid or a percentage then the
 requested depth is the inner
 [line-ascent](#dfn-line-ascent). Otherwise the requested depth is the
 resolved value of the `depth` attribute, clamping negative values to
 `0`.
- If the `lspace` attribute is absent, invalid or a percentage then the
 requested lspace is 0. Otherwise the requested lspace is the resolved
 value of the `lspace` attribute, clamping negative values to `0`.
- If the `voffset` attribute is absent, invalid or a percentage then the
 requested voffset is 0. Otherwise the requested voffset is the
 resolved value of the `voffset` attribute.

 :::::
 :::
 Note
 :::

 :::
 Negative `voffset` values are not clamped to `0`.
 :::
 :::::

::: header-wrapper
##### 3.3.6.2 Layout of `<mpadded>`

If the `<mpadded>` element does not have its computed
[`display`](#dfn-display) property equal to `block math` or
`inline math` then it is laid out according to the CSS specification
where the corresponding value is described. Otherwise, it is laid out as
shown on [Figure
16](#figure-box-mpadded "Box model for the <mpadded> element").

![[Figure 16](#figure-box-mpadded) [Box model for the
`<mpadded>`
element]](figures/mpaddedbox.svg)

The [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the math content is the requested width calculated in [3.3.6.1 Inner
box and requested
parameters](#inner-box-and-requested-parameters) but using the
[min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the [mpadded inner
box](#dfn-mpadded-inner-box) instead of the \"inner inline size\".

The [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content is the requested width calculated in [3.3.6.1 Inner box and
requested parameters](#inner-box-and-requested-parameters).

The [line-ascent](#dfn-line-ascent) of the math content is the requested
height. The
[line-descent](#dfn-line-descent) of the math content is the requested
depth.

The [mpadded inner
box](#dfn-mpadded-inner-box) is placed so that its [alphabetic
baseline](#dfn-alphabetic-baseline) is shifted away from the [alphabetic
baseline](#dfn-alphabetic-baseline) by the requested voffset towards the
[line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over).

::: header-wrapper
#### 3.3.7 Making Sub-Expressions Invisible `<mphantom>`

Historically, the [mphantom]
element was introduced to render its content invisibly, but with the
same metrics size and other dimensions, including [alphabetic
baseline](#dfn-alphabetic-baseline) position that its contents would have if
they were rendered normally.

In the following example,
[`mphantom`](#dfn-mphantom) is used to ensure alignment of corresponding parts
of the numerator and denominator of a fraction:

``` {aria-busy="false"}
<math>
 <mfrac>
 <mrow>
 <mi>x</mi>
 <mo>+</mo>
 <mi>y</mi>
 <mo>+</mo>
 <mi>z</mi>
 </mrow>
 <mrow>
 <mi>x</mi>
 <mphantom>
 <mo form="infix">+</mo>
 <mi>y</mi>
 </mphantom>
 <mo>+</mo>
 <mi>z</mi>
 </mrow>
 </mfrac>
</math>
```

![mphantom example](examples/example-mphantom.png)

The `<mphantom>` element accepts the attributes described in [2.1.3
Global Attributes](#global-attributes). Its layout algorithm
is the same as the [`mrow`](#dfn-mrow) element. The [user agent
stylesheet](#dfn-user-agent-stylesheet) must contain the following rule in order
to hide the content:

``` {aria-busy="false"}
mphantom {
 visibility: hidden;
}
```

`<mphantom>` is implemented for compatibility with full MathML. Authors
whose only target is MathML Core are encouraged to use CSS for styling.

::: header-wrapper
### 3.4 Script and Limit Schemata

The elements described in this section position one or more scripts
around a base. Attaching various kinds of scripts and embellishments to
symbols is a very common notational device in mathematics. For purely
visual layout, a single general-purpose element could suffice for
positioning scripts and embellishments in any of the traditional script
locations around a given base. However, in order to capture the abstract
structure of common notation better, MathML provides several more
specialized scripting elements.

In addition to sub-/superscript elements, MathML has overscript and
underscript elements that place scripts above and below the base. These
elements can be used to place limits on large operators, or for placing
accents and lines above or below the base.

::: header-wrapper
#### 3.4.1 Subscripts and Superscripts `<msub>`, `<msup>`, `<msubsup>`

The [msub], [msup] and
[msubsup] elements are used to attach subscript
and superscript to a MathML expression. They accept the attributes
described in [2.1.3 Global Attributes](#global-attributes).

The following example shows basic use of subscripts and superscripts.
The font-size is automatically scaled down within the scripts.

``` {aria-busy="false"}
<math>
 <msub>
 <mn>1</mn>
 <mn>2</mn>
 </msub>
 <mo>+</mo>
 <msup>
 <mn>3</mn>
 <mn>4</mn>
 </msup>
 <mo>+</mo>
 <msubsup>
 <mn>5</mn>
 <mn>6</mn>
 <mn>7</mn>
 </msubsup>
</math>
```

![msub-msup-msubsup example](examples/example-msub-msup-msubsup.png)

If the `<msub>`, `<msup>` or `<msubsup>` elements do not have their
computed [`display`](#dfn-display) property equal to `block math` or
`inline math` then they are laid out according to the CSS specification
where the corresponding value is described. Otherwise, the layout below
is performed.

::: header-wrapper
##### 3.4.1.1 Children of `<msub>`, `<msup>`, `<msubsup>`

If the `<msub>` element has less or more than two
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children, its layout algorithm is the same as the
[`mrow`](#dfn-mrow) element. Otherwise, the first
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called the [msub base], the second
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called the [msub subscript] and the layout
algorithm is explained in [3.4.1.2 Base with
subscript](#base-with-subscript).

If the `<msup>` element has less or more than two
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children, its layout algorithm is the same as the
[`mrow`](#dfn-mrow) element. Otherwise, the first
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called the [msup base], the second
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called the [msup superscript] and the layout
algorithm is explained in [3.4.1.3 Base with
superscript](#base-with-superscript).

If the `<msubsup>` element has less or more than three
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children, its layout algorithm is the same as the
[`mrow`](#dfn-mrow) element. Otherwise, the first
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called the [msubsup base], the second
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called the [msubsup subscript], its third
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called the [msubsup superscript] and the layout
algorithm is explained in [3.4.1.4 Base with subscript and
superscript](#base-with-subscript-and-superscript).

::: header-wrapper
##### 3.4.1.2 Base with subscript

The `<msub>` element is laid out as shown on [Figure
17](#figure-box-msub "Box model for the <msub> element").
`LargeOpItalicCorrection` is the [italic
correction](#dfn-italic-correction) of the [msub
base](#dfn-msub-base) if it is an [embellished
operator](#dfn-embellished-operator) with the
[`largeop`](#dfn-largeop) property and 0 otherwise.

![[Figure 17](#figure-box-msub) [Box model for the `<msub>`
element]](figures/msubbox.svg)

The [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the math content is the [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the [msub base](#dfn-msub-base)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) −
`LargeOpItalicCorrection` + [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the [msub
subscript](#dfn-msub-subscript)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) +
[SpaceAfterScript](#dfn-spaceafterscript).

If there is an [inline stretch size
constraint](#dfn-inline-stretch-size-constraint) or a [block stretch size
constraint](#dfn-block-stretch-size-constraint) then the [msub
base](#dfn-msub-base) is also laid out with the same stretch size constraint
and otherwise it is laid out without any stretch size constraint. The
scripts are always laid out without any stretch size constraint.

The [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content is the inline size of the [msub
base](#dfn-msub-base)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) −
`LargeOpItalicCorrection` + the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[msub subscript](#dfn-msub-subscript)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) +
[SpaceAfterScript](#dfn-spaceafterscript).

`SubShift` is the maximum between:

- [SubscriptShiftDown](#dfn-subscriptshiftdown)
- the [ink
 line-ascent](#dfn-ink-line-ascent) of the subscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) −
 [SubscriptTopMax](#dfn-subscripttopmax)
- [SubscriptBaselineDropMin](#dfn-subscriptbaselinedropmin) + the [ink
 line-descent](#dfn-ink-line-descent) of the [msub
 base](#dfn-msub-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box)

The [line-ascent](#dfn-line-ascent) of the math content is the maximum
between:

- The [line-ascent](#dfn-line-ascent) of the [msub
 base](#dfn-msub-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- The [line-ascent](#dfn-line-ascent) of the subscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) −
 `SubShift`.

The [line-descent](#dfn-line-descent) of the math content is the maximum
between:

- The [line-descent](#dfn-line-descent) of the [msub
 base](#dfn-msub-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- The [line-descent](#dfn-line-descent) of the subscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) +
 `SubShift`.

The [inline offset](#dfn-inline-offset) of the [msub
base](#dfn-msub-base) is 0 and the [inline
offset](#dfn-inline-offset) of the [msub
subscript](#dfn-msub-subscript) is the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[msub base](#dfn-msub-base)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) −
`LargeOpItalicCorrection`.

The [msub base](#dfn-msub-base) is placed so that its [alphabetic
baseline](#dfn-alphabetic-baseline) matches the [alphabetic
baseline](#dfn-alphabetic-baseline). The [msub
subscript](#dfn-msub-subscript) is placed so that its [alphabetic
baseline](#dfn-alphabetic-baseline) is shifted away from the [alphabetic
baseline](#dfn-alphabetic-baseline) by `SubShift` towards the
[line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under).

::: header-wrapper
##### 3.4.1.3 Base with superscript

The `<msup>` element is laid out as shown on [Figure
18](#figure-box-msup "Box model for the <msup> element").
`ItalicCorrection` is the [italic
correction](#dfn-italic-correction) of the [msup
base](#dfn-msup-base) if it is not an [embellished
operator](#dfn-embellished-operator) with the
[`largeop`](#dfn-largeop) property and 0 otherwise.

![[Figure 18](#figure-box-msup) [Box model for the `<msup>`
element]](figures/msupbox.svg)

The [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the math content is the [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the [msup base](#dfn-msup-base)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) +
`ItalicCorrection` + the [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the [msup
superscript](#dfn-msup-superscript)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) +
[SpaceAfterScript](#dfn-spaceafterscript).

If there is an [inline stretch size
constraint](#dfn-inline-stretch-size-constraint) or a [block stretch size
constraint](#dfn-block-stretch-size-constraint) then the [msup
base](#dfn-msup-base) is also laid out with the same stretch size constraint
and otherwise it is laid out without any stretch size constraint. The
scripts are always laid out without any stretch size constraint.

The [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content is the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[msup base](#dfn-msup-base)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) +
`ItalicCorrection` + the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[msup
superscript](#dfn-msup-superscript)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) +
[SpaceAfterScript](#dfn-spaceafterscript).

`SuperShift` is the maximum between:

- The value
 [SuperscriptShiftUpCramped](#dfn-superscriptshiftupcramped) if the element has a computed
 [math-shift](#propdef-math-shift) property equal to `compact`, or
 [SuperscriptShiftUp](#dfn-superscriptshiftup) otherwise.
- [SuperscriptBottomMin](#dfn-superscriptbottommin) + the [ink
 line-descent](#dfn-ink-line-descent) of the superscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box)
- The [ink
 line-ascent](#dfn-ink-line-ascent) of the [msup
 base](#dfn-msup-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) −
 [SuperscriptBaselineDropMax](#dfn-superscriptbaselinedropmax)

The [line-ascent](#dfn-line-ascent) of the math content is the maximum
between:

- The [line-ascent](#dfn-line-ascent) of the [msup
 base](#dfn-msup-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- The [line-ascent](#dfn-line-ascent) of the superscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) +
 `SuperShift`.

The [line-descent](#dfn-line-descent) of the math content is the maximum
between:

- The [line-descent](#dfn-line-descent) of the [msup
 base](#dfn-msup-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- The [line-descent](#dfn-line-descent) of the superscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) −
 `SuperShift`.

The [inline offset](#dfn-inline-offset) of the [msup
base](#dfn-msup-base) is 0 and the [inline
offset](#dfn-inline-offset) of [msup
superscript](#dfn-msup-superscript) is the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[msup base](#dfn-msup-base)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) +
`ItalicCorrection`.

The [msup base](#dfn-msup-base) is placed so that its [alphabetic
baseline](#dfn-alphabetic-baseline) matches the [alphabetic
baseline](#dfn-alphabetic-baseline). The [msup
superscript](#dfn-msup-superscript) is placed so that its [alphabetic
baseline](#dfn-alphabetic-baseline) is shifted away from the [alphabetic
baseline](#dfn-alphabetic-baseline) by `SuperShift` towards the
[line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over).

::: header-wrapper
##### 3.4.1.4 Base with subscript and superscript

The `<msubsup>` element is laid out as shown on [Figure
18](#figure-box-msup "Box model for the <msup> element").
`LargeOpItalicCorrection` and `SubShift` are set as in [3.4.1.2 Base
with subscript](#base-with-subscript). `ItalicCorrection` and
`SuperShift` are set as in [3.4.1.3 Base with
superscript](#base-with-superscript).

![[Figure 19](#figure-box-msubsup) [Box model for the
`<msubsup>`
element]](figures/msubsupbox.svg)

The [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size)
and [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size)) of the
math content is the maximum between the [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size)
and [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size)) of the
math content calculated in [3.4.1.2 Base with
subscript](#base-with-subscript) and [3.4.1.3 Base with
superscript](#base-with-superscript).

If there is an [inline stretch size
constraint](#dfn-inline-stretch-size-constraint) or a [block stretch size
constraint](#dfn-block-stretch-size-constraint) then the [msubsup
base](#dfn-msubsup-base) is also laid out with the same stretch size constraint
and otherwise it is laid out without any stretch size constraint. The
scripts are always laid out without any stretch size constraint.

If there is an [inline stretch size
constraint](#dfn-inline-stretch-size-constraint) or a [block stretch size
constraint](#dfn-block-stretch-size-constraint) then the [msubsup
base](#dfn-msubsup-base) is also laid out with the same stretch size constraint
and otherwise it is laid out without any stretch size constraint. The
scripts are always laid out without any stretch size constraint.

`SubSuperGap` is the gap between the two scripts along the [block
axis](https://www.w3.org/TR/css-writing-modes-4/#block-axis)
and is defined by (`SubShift` − the [ink
line-ascent](#dfn-ink-line-ascent) of the [msubsup
subscript](#dfn-msubsup-subscript)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box)) +
(`SuperShift` − the [ink
line-descent](#dfn-ink-line-descent) of the [msubsup
superscript](#dfn-msubsup-superscript)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box)). If
`SubSuperGap` is not at least
[SubSuperscriptGapMin](#dfn-subsuperscriptgapmin) then the following steps are performed to
ensure that the condition holds:

1. Let Δ be
 [SuperscriptBottomMaxWithSubscript](#dfn-superscriptbottommaxwithsubscript) − (`SuperShift` − the [ink
 line-descent](#dfn-ink-line-descent) of the [msubsup
 superscript](#dfn-msubsup-superscript)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box)).
 If Δ \> 0 then set Δ to the minimum between Δ set
 [SubSuperscriptGapMin](#dfn-subsuperscriptgapmin) − `SubSuperGap` and increase
 `SuperShift` (and so `SubSuperGap` too) by Δ.
2. Let Δ be
 [SubSuperscriptGapMin](#dfn-subsuperscriptgapmin) − `SubSuperGap`. If Δ \> 0 then
 increase `SubscriptShift` (and so `SubSuperGap` too) by Δ.

The [ink
line-ascent](#dfn-ink-line-ascent) (respectively
[line-ascent](#dfn-line-ascent), [ink
line-descent](#dfn-ink-line-descent),
[line-descent](#dfn-line-descent)) of the math content is set to the maximum
of the [ink
line-ascent](#dfn-ink-line-ascent) (respectively
[line-ascent](#dfn-line-ascent), [ink
line-descent](#dfn-ink-line-descent),
[line-descent](#dfn-line-descent)) of the math content calculated in
[3.4.1.2 Base with subscript](#base-with-subscript) and
[3.4.1.3 Base with superscript](#base-with-superscript) but
using the adjusted values `SubShift` and `SuperShift` above.

The [inline offset](#dfn-inline-offset) and [block
offset](#dfn-block-offset) of the [msubsup
base](#dfn-msubsup-base) and scripts are performed the same as described in
[3.4.1.2 Base with subscript](#base-with-subscript) and
[3.4.1.3 Base with superscript](#base-with-superscript).

Even when the [msubsup
subscript](#dfn-msubsup-subscript) (respectively [msubsup
superscript](#dfn-msubsup-superscript)) is an empty box, `<msubsup>` does not
generally render the same as [3.4.1.3 Base with
superscript](#base-with-superscript) (respectively [3.4.1.2
Base with subscript](#base-with-subscript)) because of the
additional constraint on `SubSuperGap`. Moreover, positioning the empty
[msubsup
subscript](#dfn-msubsup-subscript) (respectively [msubsup
superscript](#dfn-msubsup-superscript)) may also change the total size.

In order to keep the algorithm simple, no attempt is made to handle
empty scripts in a special way.

::: header-wrapper
#### 3.4.2 Underscripts and Overscripts `<munder>`, `<mover>`, `<munderover>`

The [munder], [mover] and
[munderover] elements are used to
attach accents or limits placed under or over a MathML expression.

The `<munderover>` element accepts the attribute described in [2.1.3
Global Attributes](#global-attributes) as well as the
following attributes:

- [`accent`](#dfn-accent)
- [`accentunder`](#dfn-accentunder)

Similarly, the `<mover>` element (respectively `<munder>` element)
accepts the attribute described in [2.1.3 Global
Attributes](#global-attributes) as well as the
[`accent`](#dfn-accent) attribute (respectively the
[`accentunder`](#dfn-accentunder) attribute).

[accent], [accentunder] attributes, if present,
must have values that are
[booleans](#dfn-boolean). If these attributes are absent or invalid, they are
treated as equal to `false`. User agents must implement them as
described in [3.4.4 Displaystyle, scriptlevel and math-shift in
scripts](#displaystyle-and-scriptlevel-in-scripts).

The following example shows basic use of under- and overscripts. The
font-size is automatically scaled down within the scripts, unless they
are meant to be accents.

``` {aria-busy="false"}
<math>
 <munder>
 <mn>1</mn>
 <mn>2</mn>
 </munder>
 <mo>+</mo>
 <mover>
 <mn>3</mn>
 <mn>4</mn>
 </mover>
 <mo>+</mo>
 <munderover>
 <mn>5</mn>
 <mn>6</mn>
 <mn>7</mn>
 </munderover>
 <mo>+</mo>
 <munderover accent="true">
 <mn>8</mn>
 <mn>9</mn>
 <mn>10</mn>
 </munderover>
 <mo>+</mo>
 <munderover accentunder="true">
 <mn>11</mn>
 <mn>12</mn>
 <mn>13</mn>
 </munderover>
</math>
```

![munder-over-munderover
example](examples/example-munder-mover-munderover.png)

If the `<munder>`, `<mover>` or `<munderover>` elements do not have
their computed [`display`](#dfn-display) property equal to `block math` or
`inline math` then they are laid out according to the CSS specification
where the corresponding value is described. Otherwise, the layout below
is performed.

::: header-wrapper
##### 3.4.2.1 Children of `<munder>`, `<mover>`, `<munderover>`

If the `<munder>` element has less or more than two
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children, its layout algorithm is the same as the
[`mrow`](#dfn-mrow) element. Otherwise, the first
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called the [munder base] and the second
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called the [munder underscript].

If the `<mover>` element has less or more than two
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children, its layout algorithm is the same as the
[`mrow`](#dfn-mrow) element. Otherwise, the first
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called the [mover base] and the second
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called the [mover overscript].

If the `<munderover>` element has less or more than three
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children, its layout algorithm is the same as the
[`mrow`](#dfn-mrow) element. Otherwise, the first
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called the [munderover base], the second
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called the [munderover underscript] and its third
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
child is called the [munderover overscript].

If the `<munder>`, `<mover>` or `<munderover>` elements have a computed
[math-style](#propdef-math-style) property equal to `compact` and their base
is an [embellished
operator](#dfn-embellished-operator) with the
[`movablelimits`](#dfn-movablelimits) property, then their layout
algorithms are respectively the same as the ones described for `<msub>`,
`<msup>` and `<msubsup>` in [3.4.1.2 Base with
subscript](#base-with-subscript), [3.4.1.3 Base with
superscript](#base-with-superscript) and [3.4.1.4 Base with
subscript and
superscript](#base-with-subscript-and-superscript).

Otherwise, the `<munder>`, `<mover>` and `<munderover>` layout
algorithms are respectively described in [3.4.2.3 Base with
underscript](#base-with-underscript), [3.4.2.4 Base with
overscript](#base-with-overscript) and [3.4.2.5 Base with
underscript and
overscript](#base-with-underscript-and-overscript).

::: header-wrapper
##### 3.4.2.2 Algorithm for stretching operators along the inline axis

The [algorithm for stretching operators along the inline
axis] is as follows.

1. If there is an [inline stretch size
 constraint](#dfn-inline-stretch-size-constraint) or [block stretch size
 constraint](#dfn-block-stretch-size-constraint) then the element being laid out is an
 [embellished
 operator](#dfn-embellished-operator). Lay out the base with the same
 stretch size constraint.
2. Split the list of
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 children that have not been laid out yet into a first list
 `L`~`ToStretch`~ containing [embellished
 operators](#dfn-embellished-operator) with a
 [`stretchy`](#dfn-stretchy) property and inline [stretch
 axis](#dfn-stretch-axis); and a second list `L`~`NotToStretch`~.
3. Perform layout without any stretch size constraint on all the items
 of `L`~`NotToStretch`~. If `L`~`ToStretch`~ is empty then stop. If
 `L`~`NotToStretch`~ is empty, perform layout with [inline stretch
 size
 constraint](#dfn-inline-stretch-size-constraint) 0 for all the items of
 `L`~`ToStretch`~.
4. Calculate the target size `T` to the maximum [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
 [margin
 boxes](https://www.w3.org/TR/css-box-4/#margin-box)
 of child boxes that have been laid out in the previous step.
5. Lay out or relayout all the elements of `L`~`ToStretch`~ with
 [inline stretch size
 constraint](#dfn-inline-stretch-size-constraint) `T`.

::: header-wrapper
##### 3.4.2.3 Base with underscript

The `<munder>` element is laid out as shown on [Figure
20](#figure-box-munder "Box model for the <munder> element").
`LargeOpItalicCorrection` is the [italic
correction](#dfn-italic-correction) of the [munder
base](#dfn-munder-base) if it is an [embellished
operator](#dfn-embellished-operator) with the
[`largeop`](#dfn-largeop) property and 0 otherwise.

![[Figure 20](#figure-box-munder) [Box model for the
`<munder>`
element]](figures/munderbox.svg)

The [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the math content are calculated like the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content below but replacing the [inline
sizes](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[munder base](#dfn-munder-base)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) and
[munder
underscript](#dfn-munder-underscript)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) with
the [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the [munder base](#dfn-munder-base)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) and
[munder
underscript](#dfn-munder-underscript)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box).

The
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children are laid out using the [algorithm for stretching operators
along the inline
axis](#dfn-algorithm-for-stretching-operators-along-the-inline-axis).

The [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content is calculated by determining the absolute difference
between:

- The maximum of:
 - Half the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
 [munder base](#dfn-munder-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
 - Half the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
 [munder
 underscript](#dfn-munder-underscript)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) −
 half `LargeOpItalicCorrection`.
- The minimum of:
 - −half the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
 [munder base](#dfn-munder-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
 - −half the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
 [munder
 underscript](#dfn-munder-underscript)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) −
 half `LargeOpItalicCorrection`.

If m is the minimum calculated in the second item above then the [inline
offset](#dfn-inline-offset) of the [munder
base](#dfn-munder-base) is −m − half the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
base\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box). The
[inline offset](#dfn-inline-offset) of the [munder
underscript](#dfn-munder-underscript) is −m − half the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[munder
underscript](#dfn-munder-underscript)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) −
half `LargeOpItalicCorrection`.

Parameters `UnderShift` and `UnderExtraDescender` are determined by
considering three cases in the following order:

1. The [munder base](#dfn-munder-base) is an [embellished
 operator](#dfn-embellished-operator) with the
 [`largeop`](#dfn-largeop) property. `UnderShift` is the maximum
 of

 - [LowerLimitBaselineDropMin](#dfn-lowerlimitbaselinedropmin)
 - [LowerLimitGapMin](#dfn-lowerlimitgapmin) + the ascent of the [munder
 underscript](#dfn-munder-underscript).

 `UnderExtraDescender` is 0.

2. The [munder base](#dfn-munder-base) is an [embellished
 operator](#dfn-embellished-operator) with the
 [`stretchy`](#dfn-stretchy) property and [stretch
 axis](#dfn-stretch-axis) inline. `UnderShift` is the maximum of:

 - [StretchStackBottomShiftDown](#dfn-stretchstackbottomshiftdown)
 - [StretchStackGapAboveMin](#dfn-stretchstackgapabovemin) + the ascent of the [munder
 underscript](#dfn-munder-underscript).

 `UnderExtraDescender` is 0.

3. Otherwise, `UnderShift` is equal to
 [UnderbarVerticalGap](#dfn-underbarverticalgap) if the
 [`accentunder`](#dfn-accentunder) attribute is not an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
 match to `true` and to zero otherwise. `UnderExtraAscender` is
 [UnderbarExtraDescender](#dfn-underbarextradescender).

The [line-ascent](#dfn-line-ascent) of the math content is the maximum
between:

- The [line-ascent](#dfn-line-ascent) of the [munder
 base](#dfn-munder-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- The [line-ascent](#dfn-line-ascent) of the [munder
 underscript](#dfn-munder-underscript)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) −
 `UnderShift`.

The [line-descent](#dfn-line-descent) of the math content is the maximum
between:

- The [line-descent](#dfn-line-descent) of the [munder
 base](#dfn-munder-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- The [line-descent](#dfn-line-descent) of the [munder
 underscript](#dfn-munder-underscript)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) +
 `UnderShift` + `UnderExtraAscender`.

The [alphabetic
baseline](#dfn-alphabetic-baseline) of the [munder
base](#dfn-munder-base) is aligned with the [alphabetic
baseline](#dfn-alphabetic-baseline). The [alphabetic
baseline](#dfn-alphabetic-baseline) of the [munder
underscript](#dfn-munder-underscript) is shifted away from the [alphabetic
baseline](#dfn-alphabetic-baseline) and towards the
[line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under)
by a distance equal to the [ink
line-descent](#dfn-ink-line-descent) of the [munder
base](#dfn-munder-base)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) +
`UnderShift`.

The [math content
box](#dfn-math-content-box) is placed within the [content
box](https://www.w3.org/TR/css-box-4/#content-box) so
that their block-start edges are aligned and the middles of these edges
are at the same position.

::: header-wrapper
##### 3.4.2.4 Base with overscript

The `<mover>` element is laid out as shown on [Figure
21](#figure-box-mover "Box model for the <mover> element").
`LargeOpItalicCorrection` is the [italic
correction](#dfn-italic-correction) of the [mover
base](#dfn-mover-base) if it is an [embellished
operator](#dfn-embellished-operator) with the
[`largeop`](#dfn-largeop) property and 0 otherwise.

![[Figure 21](#figure-box-mover) [Box model for the
`<mover>` element]](figures/moverbox.svg)

The [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the math content are calculated like the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content below but replacing the [inline
sizes](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[mover base](#dfn-mover-base)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) and
[mover
overscript](#dfn-mover-overscript)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) with
the [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the [mover base](#dfn-mover-base)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) and
[mover
overscript](#dfn-mover-overscript)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box).

The
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children are laid out using the [algorithm for stretching operators
along the inline
axis](#dfn-algorithm-for-stretching-operators-along-the-inline-axis).

The `TopAccentAttachment` is the [top accent
attachment](#dfn-top-accent-attachment) of the [mover
overscript](#dfn-mover-overscript) or half the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[mover
overscript](#dfn-mover-overscript)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) if it
is undefined.

The [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content is calculated by applying the [algorithm for stretching
operators along the inline
axis](#dfn-algorithm-for-stretching-operators-along-the-inline-axis) for layout and determining the absolute
difference between:

- The maximum of:
 - Half the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
 [mover base](#dfn-mover-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
 - The [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
 [mover
 overscript](#dfn-mover-overscript)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) −
 `TopAccentAttachment` + half `LargeOpItalicCorrection`.
- The minimum of:
 - −half the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
 [mover base](#dfn-mover-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
 - −`TopAccentAttachment` + half `LargeOpItalicCorrection`.

If m is the minimum calculated in the second item above then the [inline
offset](#dfn-inline-offset) of the [mover
base](#dfn-mover-base) is −m − half the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
base\'s margin. The [inline
offset](#dfn-inline-offset) of the [mover
overscript](#dfn-mover-overscript) is −m − half the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
[mover
overscript](#dfn-mover-overscript)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) +
half `LargeOpItalicCorrection`.

Parameters `OverShift` and `OverExtraDescender` are determined by
considering three cases in the following order:

1. The [mover base](#dfn-mover-base) is an [embellished
 operator](#dfn-embellished-operator) with the
 [`largeop`](#dfn-largeop) property. `OverShift` is the maximum of

 - [UpperLimitBaselineRiseMin](#dfn-upperlimitbaselinerisemin)
 - [UpperLimitGapMin](#dfn-upperlimitgapmin) + the descent of the [mover
 overscript](#dfn-mover-overscript).

 `OverExtraAscender` is 0.

2. The [mover base](#dfn-mover-base) is an [embellished
 operator](#dfn-embellished-operator) with the
 [`stretchy`](#dfn-stretchy) property and [stretch
 axis](#dfn-stretch-axis) inline. `OverShift` is the maximum of:

 - [StretchStackTopShiftUp](#dfn-stretchstacktopshiftup)
 - [StretchStackGapBelowMin](#dfn-stretchstackgapbelowmin) + the descent of the [mover
 overscript](#dfn-mover-overscript).

 `OverExtraDescender` is 0.

3. Otherwise, `OverShift` is equal to

 1. [OverbarVerticalGap](#dfn-overbarverticalgap) if the
 [`accent`](#dfn-accent) attribute is not an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
 match to `true`.
 2. Or
 [AccentBaseHeight](#dfn-accentbaseheight) minus the
 [line-ascent](#dfn-line-ascent) of the [mover
 base](#dfn-mover-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box)
 if this difference is nonnegative.
 3. Or 0 otherwise.

 `OverExtraAscender` is
 [OverbarExtraAscender](#dfn-overbarextraascender).

For accent overscripts and bases with
[line-ascents](#dfn-line-ascent) that are at most
[AccentBaseHeight](#dfn-accentbaseheight), the rule from
\[[OPEN-FONT-FORMAT](#bib-open-font-format "Information technology — Coding of audio-visual objects — Part 22: Open Font Format")\] \[[TEXBOOK](#bib-texbook "The TeXBook")\] is actually to align the [alphabetic
baselines](#dfn-alphabetic-baseline) of the overscripts and of the bases. This
assumes that accent glyphs are designed in such a way that their ink
bottoms are more or less
[AccentBaseHeight](#dfn-accentbaseheight) above their [alphabetic
baselines](#dfn-alphabetic-baseline). Hence, the previous rule will guarantee
that all the overscript bottoms are aligned while still avoiding
collision with the bases. However, MathML can have arbitrary accent
overscripts, so a more general and simpler rule is provided above:
Ensure that the bottom of overscript is at least
[AccentBaseHeight](#dfn-accentbaseheight) above the [alphabetic
baseline](#dfn-alphabetic-baseline) of the base.

The [line-ascent](#dfn-line-ascent) of the math content is the maximum
between:

- The [line-ascent](#dfn-line-ascent) of the [mover
 base](#dfn-mover-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- The [line-ascent](#dfn-line-ascent) of the [mover
 overscript](#dfn-mover-overscript)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) +
 `OverShift` + `OverExtraAscender`.

The [line-descent](#dfn-line-descent) of the math content is the maximum
between:

- The [line-descent](#dfn-line-descent) of the [mover
 base](#dfn-mover-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
- The [line-descent](#dfn-line-descent) of the [mover
 overscript](#dfn-mover-overscript)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) −
 `OverShift`.

The [alphabetic
baseline](#dfn-alphabetic-baseline) of the [mover
base](#dfn-mover-base) is aligned with the [alphabetic
baseline](#dfn-alphabetic-baseline). The [alphabetic
baseline](#dfn-alphabetic-baseline) of the [mover
overscript](#dfn-mover-overscript) is shifted away from the [alphabetic
baseline](#dfn-alphabetic-baseline) and towards the
[line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over)
by a distance equal to the [ink
line-ascent](#dfn-ink-line-ascent) of the base + `OverShift`.

The [math content
box](#dfn-math-content-box) is placed within the [content
box](https://www.w3.org/TR/css-box-4/#content-box) so
that their block-start edges are aligned and the middles of these edges
are at the same position.

::: header-wrapper
##### 3.4.2.5 Base with underscript and overscript

The general layout of `<munderover>` is shown on [Figure
22](#figure-box-munderover "Box model for the <munderover> element").
The `LargeOpItalicCorrection`, `UnderShift`, `UnderExtraDescender`,
`OverShift`, `OverExtraDescender` parameters are calculated the same as
in [3.4.2.3 Base with underscript](#base-with-underscript) and
[3.4.2.4 Base with overscript](#base-with-overscript).

![[Figure 22](#figure-box-munderover) [Box model for the
`<munderover>`
element]](figures/munderoverbox.svg)

The [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size),
[max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size)
and [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content are calculated as an absolute difference between a maximum
[inline offset](#dfn-inline-offset) and minimum [inline
offset](#dfn-inline-offset). These extrema are calculated by taking the extremum
value of the corresponding extrema calculated in [3.4.2.3 Base with
underscript](#base-with-underscript) and [3.4.2.4 Base with
overscript](#base-with-overscript). The [inline
offsets](#dfn-inline-offset) of the [munderover
base](#dfn-munderover-base), [munderover
underscript](#dfn-munderover-underscript) and [munderover
overscript](#dfn-munderover-overscript) are calculated as in these sections but
using the new minimum m (minimum of the corresponding minima).

Like in these sections, the
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children are laid out using the [algorithm for stretching operators
along the inline
axis](#dfn-algorithm-for-stretching-operators-along-the-inline-axis).

The [line-ascent](#dfn-line-ascent) and
[line-descent](#dfn-line-descent) of the math content are also calculated by
taking the extremum value of the extrema calculated in [3.4.2.3 Base
with underscript](#base-with-underscript) and [3.4.2.4 Base
with overscript](#base-with-overscript).

Finally, the [alphabetic
baselines](#dfn-alphabetic-baseline) of the [munderover
base](#dfn-munderover-base), [munderover
underscript](#dfn-munderover-underscript) and [munderover
overscript](#dfn-munderover-overscript) are calculated as in sections [3.4.2.3
Base with underscript](#base-with-underscript) and [3.4.2.4
Base with overscript](#base-with-overscript).

The [math content
box](#dfn-math-content-box) is placed within the [content
box](https://www.w3.org/TR/css-box-4/#content-box) so
that their block-start edges are aligned and the middles of these edges
are at the same position.

When the underscript (respectively overscript) is an empty box, the base
and overscript (respectively underscript) are laid out similarly to
[3.4.2.4 Base with overscript](#base-with-overscript)
(respectively [3.4.2.3 Base with
underscript](#base-with-underscript)) but the position of the
empty underscript (respectively overscript) may add extra space. In
order to keep the algorithm simple, no attempt is made to handle empty
scripts in a special way.

::: header-wrapper
#### 3.4.3 Prescripts and Tensor Indices `<mmultiscripts>`

Presubscripts and tensor notations are represented by the
[mmultiscripts] element. The
[mprescripts] element is used as a
separator between the postscripts and prescripts. These two elements
accept the attributes described in [2.1.3 Global
Attributes](#global-attributes).

The following example shows basic use of prescripts and postscripts,
involving a [`mprescripts`](#dfn-mprescripts). Empty
[`mrow`](#dfn-mrow) elements are used at positions where no scripts are
rendered. The font-size is automatically scaled down within the scripts.

``` {aria-busy="false"}
<math>
 <mmultiscripts>
 <mn>1</mn>
 <mn>2</mn>
 <mn>3</mn>
 <mrow></mrow>
 <mn>5</mn>
 <mprescripts/>
 <mn>6</mn>
 <mrow></mrow>
 <mn>8</mn>
 <mn>9</mn>
 </mmultiscripts>
</math>
```

![mmultiscripts example](examples/example-mmultiscripts.png)

If the `<mmultiscripts>` or `<mprescripts>` elements do not have their
computed [`display`](#dfn-display) property equal to `block math` or
`inline math` then they are laid out according to the CSS specification
where the corresponding value is described. Otherwise, the layout below
is performed.

The `<mprescripts>` element is laid out as an
[`mrow`](#dfn-mrow) element.

A valid `<mmultiscripts>` element contains the following
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children:

- A first
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 child, called the [mmultiscripts base], that is not an
 [`mprescripts`](#dfn-mprescripts) element.
- Followed by an even number of
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 children called [mmultiscripts
 postscripts], none of them being a
 [`mprescripts`](#dfn-mprescripts) element. These scripts form a
 (possibly empty) list subscript, superscript, subscript, superscript,
 subscript, superscript, etc. Each consecutive couple of children
 subscript, superscript is called a [subscript/superscript
 pair].
- Optionally followed by an
 [`mprescripts`](#dfn-mprescripts) element and an even number of
 [in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
 children called [mmultiscripts
 prescripts], none of them being a
 [`mprescripts`](#dfn-mprescripts) element. These scripts form a
 (possibly empty) list of [subscript/superscript
 pair](#dfn-subscript-superscript-pair).

If an `<mmultiscripts>` element is not valid then it is laid out the
same as the [`mrow`](#dfn-mrow) element. Otherwise the layout algorithm is
performed as in [3.4.3.1 Base with prescripts and
postscripts](#base-with-prescripts-and-postscripts).

::: header-wrapper
##### 3.4.3.1 Base with prescripts and postscripts

The `<mmultiscripts>` element is laid out as shown on [Figure
23](#figure-box-mmultiscripts "Box model for the <mmultiscripts> element").
For each [subscript/superscript
pair](#dfn-subscript-superscript-pair) of [mmultiscripts
postscripts](#dfn-mmultiscripts-postscripts), the `ItalicCorrection`
`LargeOpItalicCorrection` are defined as in [3.4.1.2 Base with
subscript](#base-with-subscript) and [3.4.1.3 Base with
superscript](#base-with-superscript).

![[Figure 23](#figure-box-mmultiscripts) [Box model for the
`<mmultiscripts>`
element]](figures/mmultiscriptsbox.svg)

The [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)
(respectively [max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size))
of the math content is calculated the same as the [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content below, but replacing \"[inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size)\" with
\"[min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size)\"
(respectively \"[max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size)\")
for the [mmultiscripts
base](#dfn-mmultiscripts-base)\'s [margin
box](https://www.w3.org/TR/css-box-4/#margin-box) and
scripts\' [margin
boxes](https://www.w3.org/TR/css-box-4/#margin-box).

If there is an [inline stretch size
constraint](#dfn-inline-stretch-size-constraint) or a [block stretch size
constraint](#dfn-block-stretch-size-constraint) the [mmultiscripts
base](#dfn-mmultiscripts-base) is also laid out with the same stretch
size constraint. Otherwise it is laid out without any stretch size
constraint. The other elements are always laid out without any stretch
size constraint.

The [inline
size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
math content is calculated with the following algorithm:

1. Set `inline-offset` to 0.

2. For each [subscript/superscript
 pair](#dfn-subscript-superscript-pair) of [mmultiscripts
 prescripts](#dfn-mmultiscripts-prescripts), increment `inline-offset` by
 [SpaceAfterScript](#dfn-spaceafterscript) + the maximum of

 - The [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of
 the subscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
 - The inline size of the superscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).

3. Increment `inline-offset` by the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of the
 [mmultiscripts
 base](#dfn-mmultiscripts-base)\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box)
 and set `inline-size` to `inline-offset`.

4. For each [subscript/superscript
 pair](#dfn-subscript-superscript-pair) of [mmultiscripts
 postscripts](#dfn-mmultiscripts-postscripts), modify `inline-size` to be at least:

 - x + the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of
 the subscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box) +
 `LargeOpItalicCorrection`.
 - x + the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of
 the superscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box)
 − `ItalicCorrection`.

 Increment `inline-offset` to the maximum of:

 - the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of
 the subscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
 - the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of
 the superscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).

 Increment `inline-offset` by
 [SpaceAfterScript](#dfn-spaceafterscript).

5. Return `inline-size`.

`SubShift` (respectively `SuperShift`) is calculated by taking the
maximum of all subshifts (respectively supershifts) of each
[subscript/superscript
pair](#dfn-subscript-superscript-pair) as described in [3.4.1.4 Base with
subscript and
superscript](#base-with-subscript-and-superscript).

The [line-ascent](#dfn-line-ascent) of the math content is calculated by
taking the maximum of all the
[line-ascent](#dfn-line-ascent) of each [subscript/superscript
pair](#dfn-subscript-superscript-pair) as described in [3.4.1.4 Base with
subscript and
superscript](#base-with-subscript-and-superscript) but using
the `SubShift` and `SuperShift` values calculated above.

The [line-descent](#dfn-line-descent) of the math content is calculated by
taking the maximum of all the
[line-descent](#dfn-line-descent) of each [subscript/superscript
pair](#dfn-subscript-superscript-pair) as described in [3.4.1.4 Base with
subscript and
superscript](#base-with-subscript-and-superscript) but using
the `SubShift` and `SuperShift` values calculated above.

Finally, the placement of the
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children is performed using the following algorithm:

1. Set `inline-offset` to 0.

2. For each [subscript/superscript
 pair](#dfn-subscript-superscript-pair) of [mmultiscripts
 prescripts](#dfn-mmultiscripts-prescripts):

 1. Increment `inline-offset` by
 [SpaceAfterScript](#dfn-spaceafterscript).
 2. Set `pair-inline-size` to the maximum of
 - the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size)
 of the subscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
 - the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size)
 of the superscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
 3. Place the subscript at inline-start position `inline-offset` +
 `pair-inline-size` − the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of
 the subscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
 4. Place the superscript at inline-start position `inline-offset` +
 `pair-inline-size` − the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size) of
 the superscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
 5. Place the subscript (respectively superscript) so its
 [alphabetic
 baseline](#dfn-alphabetic-baseline) is shifted away from the
 [alphabetic
 baseline](#dfn-alphabetic-baseline) by `SubShift` (respectively
 `SuperShift`) towards the
 [line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under)
 (respectively
 [line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over)).
 6. Increment `inline-offset` by `pair-inline-size`.

3. Place the [mmultiscripts
 base](#dfn-mmultiscripts-base) and `<mprescripts>` boxes at [inline
 offsets](#dfn-inline-offset) `inline-offset` and with their
 [alphabetic
 baselines](#dfn-alphabetic-baseline) aligned with the [alphabetic
 baseline](#dfn-alphabetic-baseline).

4. For each [subscript/superscript
 pair](#dfn-subscript-superscript-pair) of [mmultiscripts
 postscripts](#dfn-mmultiscripts-postscripts):

 1. Set `pair-inline-size` to the maximum of
 - the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size)
 of the subscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
 - the [inline
 size](https://www.w3.org/TR/css-writing-modes-4/#inline-size)
 of the superscript\'s [margin
 box](https://www.w3.org/TR/css-box-4/#margin-box).
 2. Place the subscript at inline-start position `inline-offset` −
 `LargeOpItalicCorrection`.
 3. Place the superscript at inline-start position `inline-offset` +
 `ItalicCorrection`.
 4. Place the subscript (superscript) so its [alphabetic
 baseline](#dfn-alphabetic-baseline) is shifted away from the
 [alphabetic
 baseline](#dfn-alphabetic-baseline) by `SubShift` (respectively
 `SuperShift`) towards the
 [line-under](https://www.w3.org/TR/css-writing-modes-4/#line-under)
 (respectively
 [line-over](https://www.w3.org/TR/css-writing-modes-4/#line-over)).
 5. Increment `inline-offset` by `pair-inline-size`.
 6. Increment `inline-offset` by
 [SpaceAfterScript](#dfn-spaceafterscript).

An `<mmultiscripts>` with only one [subscript/superscript
pair](#dfn-subscript-superscript-pair) of [mmultiscripts
postscripts](#dfn-mmultiscripts-postscripts) is laid out the same as a `<msubsup>` with
the same
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
children. However, as [noticed for
`<msubsup>`](#msubsup-with-empty-scripts), if additionally the subscript
(respectively superscript) is an empty box then it is not necessarily
laid out the same as an `<msub>` (respectively `<msup>`) element. In
order to keep the algorithm simple, no attempt is made to handle empty
scripts in a special way.

::: header-wrapper
#### 3.4.4 Displaystyle, scriptlevel and math-shift in scripts

For all [scripted
elements](#dfn-scripted-elements), the rule of thumb is to set
[`displaystyle`](#dfn-displaystyle) to `false` and to increment
[`scriptlevel`](#dfn-scriptlevel) in all child elements but the first one.
However, an [`mover`](#dfn-mover) (respectively
[`munderover`](#dfn-munderover)) element with an
[`accent`](#dfn-accent) attribute that is an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
match to `true` does not increment scriptlevel within its second child
(respectively third child). Similarly,
[`mover`](#dfn-mover) and
[`munderover`](#dfn-munderover) elements with an
[`accentunder`](#dfn-accentunder) attribute that is an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
match to `true` do not increment scriptlevel within their second child.

`<mmultiscripts>` sets
[`math-shift`](#propdef-math-shift) to `compact` on its children at even
position if they are before an
[`mprescripts`](#dfn-mprescripts), and on those at odd position if they
are after an
[`mprescripts`](#dfn-mprescripts). The `<msub>` and `<msubsup>` elements
set [`math-shift`](#propdef-math-shift) to `compact` on their second child.
[`mover`](#dfn-mover) and
[`munderover`](#dfn-munderover) elements with an
[`accent`](#dfn-accent) attribute that is an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
match to `true` also set
[`math-shift`](#propdef-math-shift) to `compact` within their first child.

The [A. User Agent Stylesheet](#user-agent-stylesheet) must
contain the following style in order to implement this behavior:

``` {aria-busy="false"}
msub > :not(:first-child),
msup > :not(:first-child),
msubsup > :not(:first-child),
mmultiscripts > :not(:first-child),
munder > :not(:first-child),
mover > :not(:first-child),
munderover > :not(:first-child) {
 math-depth: add(1);
 math-style: compact;
}
munder[accentunder="true" i] > :nth-child(2),
mover[accent="true" i] > :nth-child(2),
munderover[accentunder="true" i] > :nth-child(2),
munderover[accent="true" i] > :nth-child(3) {
 font-size: inherit;
}
msub > :nth-child(2),
msubsup > :nth-child(2),
mmultiscripts > :nth-child(even),
mmultiscripts > mprescripts ~ :nth-child(odd),
mover[accent="true" i] > :first-child,
munderover[accent="true" i] > :first-child {
 math-shift: compact;
}
mmultiscripts > mprescripts ~ :nth-child(even) {
 math-shift: inherit;
}
```

In practice, all the children of the MathML elements described in this
section are
[in-flow](https://www.w3.org/TR/css-display-3/#in-flow)
and the `<mprescripts>` is empty. Hence the CSS rules essentially
perform automatic
[`displaystyle`](#dfn-displaystyle) and
[`scriptlevel`](#dfn-scriptlevel) changes for the scripts; and
[`math-shift`](#propdef-math-shift) changes for subscripts and sometimes the
base.

::: header-wrapper
### 3.5 Tabular Math

Matrices, arrays and other table-like mathematical notation are marked
up using [`mtable`](#dfn-mtable) [`mtr`](#dfn-mtr) [`mtd`](#dfn-mtd) elements. These elements are similar to the
[`table`](https://html.spec.whatwg.org/multipage/tables.html#the-table-element),
[`tr`](https://html.spec.whatwg.org/multipage/tables.html#the-tr-element)
and
[`td`](https://html.spec.whatwg.org/multipage/tables.html#the-td-element)
elements of \[[HTML](#bib-html "HTML Standard")\].

The following example shows how tabular layout allows to write a matrix.
Note that it is vertically centered with the fraction bar and the middle
of the equal sign.

``` {aria-busy="false"}
<math>
 <mfrac>
 <mi>A</mi>
 <mn>2</mn>
 </mfrac>
 <mo>=</mo>
 <mrow>
 <mo>(</mo>
 <mtable>
 <mtr>
 <mtd><mn>1</mn></mtd>
 <mtd><mn>2</mn></mtd>
 <mtd><mn>3</mn></mtd>
 </mtr>
 <mtr>
 <mtd><mn>4</mn></mtd>
 <mtd><mn>5</mn></mtd>
 <mtd><mn>6</mn></mtd>
 </mtr>
 <mtr>
 <mtd><mn>7</mn></mtd>
 <mtd><mn>8</mn></mtd>
 <mtd><mn>9</mn></mtd>
 </mtr>
 </mtable>
 <mo>)</mo>
 </mrow>
</math>
```

![tables example](examples/example-tables.png)

::: header-wrapper
#### 3.5.1 Table or Matrix `<mtable>`

The [mtable] is laid out as an `inline-table` and
sets `displaystyle` to `false`. Note that `false` is intended for tables
used for matrices and similar constructs. Tables used for vertical
layout of aligned equations will typically require `displaystyle` set to
`true`.

The [user agent
stylesheet](#dfn-user-agent-stylesheet) must contain the following rules in order
to implement these properties:

``` {aria-busy="false"}
mtable {
 display: inline-table;
 math-style: compact;
}
```

The `mtable` element is as a CSS
[table](https://www.w3.org/TR/css-display-3/#valdef-display-table)
and the [min-content inline
size](https://www.w3.org/TR/css-sizing-3/#min-content-inline-size),
[max-content inline
size](https://www.w3.org/TR/css-sizing-3/#max-content-inline-size),
[inline size](https://www.w3.org/TR/css-writing-modes-4/#inline-size),
[block size](https://www.w3.org/TR/css-writing-modes-4/#block-size),
[first baseline
set](https://www.w3.org/TR/css-align-3/#first-baseline-set)
and [last baseline
set](https://www.w3.org/TR/css-align-3/#last-baseline-set)
sets are determined accordingly. The center of the table is aligned with
the [math axis](#dfn-math-axis).

The `<mtable>` accepts the attributes described in [2.1.3 Global
Attributes](#global-attributes).

::: header-wrapper
#### 3.5.2 Row in Table or Matrix `<mtr>`

The [mtr] is laid out as `table-row`. The [user
agent
stylesheet](#dfn-user-agent-stylesheet) must contain the following rules in order
to implement that behavior:

``` {aria-busy="false"}
mtr {
 display: table-row;
}
```

The `<mtr>` accepts the attributes described in [2.1.3 Global
Attributes](#global-attributes).

::: header-wrapper
#### 3.5.3 Entry in Table or Matrix `<mtd>`

The [mtd] is laid out as a `table-cell` with
content centered in the cell and a default padding. The [user agent
stylesheet](#dfn-user-agent-stylesheet) must contain the following rules:

``` {aria-busy="false"}
mtd {
 display: table-cell;
 /* Centering inside table cells should rely on box alignment properties.
 See https://github.com/w3c/mathml-core/issues/156 */
 text-align: center;
 padding: 0.5ex 0.4em;
}
```

The `<mtd>` accepts the attributes described in [2.1.3 Global
Attributes](#global-attributes) as well as the following
attributes:

- [`columnspan`](#dfn-columnspan)
- [`rowspan`](#dfn-rowspan)

The [`columnspan`] (respectively
[`rowspan`]) attribute has the same syntax and semantics as the
[`colspan`](https://html.spec.whatwg.org/multipage/tables.html#attr-tdth-colspan)
(respectively [`rowspan`](#dfn-rowspan)) attribute on the `<td>` element
from \[[HTML](#bib-html "HTML Standard")\].
In particular, the parsing of these attributes is handled as described
in the [algorithm for processing
rows](https://html.spec.whatwg.org/#algorithm-for-processing-rows),
always reading \"`colspan`\" as \"`columnspan`\".

The name of the column spanning attribute in
\[[MathML3](#bib-mathml3 "Mathematical Markup Language (MathML) Version 3.0 2nd Edition")\] and earlier versions is `columnspan` and is
preserved for backward compatibility reasons.

The `<mtd>` element [generates an anonymous \<mrow\>
box](#dfn-generates-an-anonymous-mrow-box).

::: header-wrapper
### 3.6 Linking `<a>`

The [a] element is used to group together any
number of sub-expressions equivalently to
[`mrow`](#dfn-mrow). It\'s main purpose is to enable the specification
of hyperlinks via the use of the `href` attribute.

The `<a>` element accepts the attributes described in [2.1.3 Global
Attributes](#global-attributes) as well as corresponding
attributes of the [HTML `<a>`
element](https://html.spec.whatwg.org/multipage/#the-a-element):

- [`href`](#dfn-href)
- [`target`](#dfn-target)
- [`download`](#dfn-download)
- [`ping`](#dfn-ping)
- [`rel`](#dfn-rel)
- [`hreflang`](#dfn-hreflang)
- [`type`](#dfn-type)
- [`referrerpolicy`](#dfn-referrerpolicy)

The [href], [target], [download], [ping],
[rel], [hreflang], [type]
and [referrerpolicy]
attributes have the same syntax and semantics as defined for the [HTML
`<a>` element](https://html.spec.whatwg.org/multipage/#the-a-element).

The layout algorithm of the `<a>` element is the same as the `<mrow>`
element.

Note that this means that in the absence of an `href` attribute, `<a>`
may be seen as equivalent to `<mrow>`.

The `<a>` element must implement, and expose to scripts, the following
[`MathMLAnchorElement`] interface.

```
WebIDL[Exposed=Window]
interface MathMLAnchorElement : MathMLElement {
 [ReflectSetter] attribute USVString href;
 [Reflect] attribute DOMString target;
};
MathMLAnchorElement includes HyperlinkElementUtils;
```

[href](#dom-mathmlanchorelement-href)
getter steps are:

1. [Reinitialize url](HTML/../#reinitialise-url).
2. Let `url` be
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [url](https://html.spec.whatwg.org/#concept-hyperlink-url).
3. If `url` is null and
 [this](https://webidl.spec.whatwg.org/#this) has no
 [`href`](#dfn-href) content attribute, then return the empty
 string.
4. Otherwise, if `url` is null, then return
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [`href`](#dfn-href) content attribute\'s value.
5. Return `url`, serialized.

The [[set the
url](https://html.spec.whatwg.org/#concept-hyperlink-url-set)] algorithm for a
`MathMLAnchorElement` are:

1. If [this](https://webidl.spec.whatwg.org/#this)
 element\'s [`href`](#dfn-href) content attribute is absent, then return.
2. Let `url` be the result of [encoding-parsing a
 URL](HTML/../#encoding-parsing-a-url) given
 [this](https://webidl.spec.whatwg.org/#this)
 element\'s [`href`](#dfn-href) content attribute\'s value, relative to
 [this](https://webidl.spec.whatwg.org/#this)
 element\'s [node document](DOM/../#concept-node-document).
3. If `url` is not failure, then set
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [url](https://html.spec.whatwg.org/#concept-hyperlink-url)
 to `url`.

To [[update
href](https://html.spec.whatwg.org/#update-href)] for a `MathMLAnchorElement`,
set the element\'s [`href`](#dfn-href) content attribute\'s value to the element\'s
[[url](https://html.spec.whatwg.org/#concept-hyperlink-url)],
[[serialized](https://url.spec.whatwg.org/#concept-url-serializer)].

::: header-wrapper
### 3.7 Enlivening Expressions

Historically, the [maction]
element provides a mechanism for binding actions to expressions.

The `<maction>` element accepts the attributes described in [2.1.3
Global Attributes](#global-attributes) as well as the
following attributes:

- [`actiontype`](#dfn-actiontype)
- [`selection`](#dfn-selection)

This specification does not define any observable behavior that is
specific to the [actiontype] and [selection] attributes.

The following example shows the \"toggle\" action type from
\[[MathML3](#bib-mathml3 "Mathematical Markup Language (MathML) Version 3.0 2nd Edition")\] where the renderer alternately displays the
selected subexpression, starting from \"one third\" and cycling through
them when there is a click on the selected subexpression (\"one
quarter\", \"one half\", \"one third\", etc). This is not part of MathML
Core but can be implemented using JavaScript and CSS polyfills. The
default behavior is just to render the first child.

``` {aria-busy="false"}
<math>
 <maction actiontype="toggle" selection="2">
 <mfrac>
 <mn>1</mn>
 <mn>2</mn>
 </mfrac>
 <mfrac>
 <mn>1</mn>
 <mn>3</mn>
 </mfrac>
 <mfrac>
 <mn>1</mn>
 <mn>4</mn>
 </mfrac>
 </maction>
</math>
```

![maction example](examples/example-maction.png)

The layout algorithm of the `<maction>` element is the same as the
`<mrow>` element. The [user agent
stylesheet](#dfn-user-agent-stylesheet) must contain the following rules in order
to hide all but its first child element, which is the default behavior
for the legacy actiontype values:

``` {aria-busy="false"}
maction > :not(:first-child) {
 display: none;
}
```

`<maction>` is implemented for compatibility with full MathML. Authors
whose only target is MathML Core are encouraged to use other HTML, CSS
and JavaScript mechanisms to implement custom actions. They may rely on
maction attributes defined in
\[[MathML3](#bib-mathml3 "Mathematical Markup Language (MathML) Version 3.0 2nd Edition")\].

::: header-wrapper
### 3.8 Semantics and Presentation

The [semantics] element is the container
element that associates annotations with a MathML expression. Typically,
the `<semantics>` element has as its first child element a MathML
expression to be annotated while subsequent child elements represent
text annotations within an [annotation]
element, or more complex markup annotations within an
[annotation-xml] element.

The following example shows how the fraction \"one half\" can be
annotated with a textual annotation (LaTeX) or an XML annotation
(content MathML), which are not intended to be rendered by the user
agent. This fraction is also annotated with equivalent SVG and HTML
markup.

``` {aria-busy="false"}
<math>
 <semantics>
 <mfrac>
 <mn>1</mn>
 <mn>2</mn>
 </mfrac>
 <annotation encoding="application/x-tex">\frac{1}{2}</annotation>
 <annotation-xml encoding="application/mathml-content+xml">
 <apply>
 <divide/>
 <cn>1</cn>
 <cn>2</cn>
 </apply>
 </annotation-xml>
 <annotation-xml>
 <svg width="25" height="75" xmlns="http://www.w3.org/2000/svg">
 <path stroke-width="5.8743"
 d="m5.9157 27.415h6.601v-22.783l-7.1813 1.4402v-3.6805l7.1408
 -1.4402h4.0406v26.464h6.601v3.4005h-17.203z"/>
 <path stroke="#000000" stroke-width="2.3409"
 d="m0.83496 39.228h23.327"/>
 <path stroke-width="5.8743"
 d="m8.696 70.638h14.102v3.4005h-18.963v-3.4005q2.3004-2.3804
 6.2608-6.3813 3.9806-4.0206 5.0007-5.1808 1.9403-2.1803
 2.7004-3.6805 0.78011-1.5202 0.78011-2.9804 0-2.3804
 -1.6802-3.8806-1.6603-1.5002-4.3406-1.5002-1.9003 0-4.0206
 0.6601-2.1003 0.6601-4.5007 2.0003v-4.0806q2.4404-0.98013
 4.5607-1.4802 2.1203-0.50007 3.8806-0.50007 4.6407 0 7.401
 2.3203 2.7604 2.3203 2.7604 6.2009 0 1.8403-0.7001 3.5006
 -0.68013 1.6402-2.5004 3.8806-0.50007 0.58009-3.1805 3.3605
 -2.6804 2.7604-7.5614 7.7412z"/>
 </svg>
 </annotation-xml>
 <annotation-xml encoding="application/xhtml+xml">
 <div style="display: inline-flex;
 flex-direction: column; align-items: center;">
 <div>1</div>
 <div>―</div>
 <div>2</div>
 </div>
 </annotation-xml>
 </semantics>
</math>
```

![semantics example](examples/example-semantics.png)

The `<semantics>` element accepts the attributes described in [2.1.3
Global Attributes](#global-attributes). Its layout algorithm
is the same as the [`mrow`](#dfn-mrow) element. The [user agent
stylesheet](#dfn-user-agent-stylesheet) must contain the following rule in order
to only render the annotated MathML expression:

``` {aria-busy="false"}
semantics > :not(:first-child) {
 display: none;
}
```

The `<annotation-xml>` and `<annotation>` element accepts the attributes
described in [2.1.3 Global Attributes](#global-attributes) as
well as the following attribute:

- [`encoding`](#dfn-encoding)

This specification does not define any observable behavior that is
specific to the [encoding] attribute.

The layout algorithm of the `<annotation-xml>` and `<annotation>`
element is the same as the [`mtext`](#dfn-mtext) element.

Authors can use the [`encoding`](#dfn-encoding) attribute to distinguish
annotations for [HTML integration
point](https://html.spec.whatwg.org/#html-integration-point), clipboard
copy, alternative rendering, etc. In particular, CSS can be used to
render alternative annotations, e.g.

``` {aria-busy="false"}
/* Hide the annotated child. */
semantics > :first-child { display: none; }
 /* Show all text annotations. */
semantics > annotation { display: inline; }
/* Show all HTML annotations. */
semantics > annotation-xml[encoding="text/html" i],
semantics > annotation-xml[encoding="application/xhtml+xml" i] {
 display: inline-block;
}
```

::: header-wrapper
## 4. CSS Extensions for Math Layout

::: header-wrapper
### 4.1 The `display: block math` and `display: inline math` value

The `display` property from [CSS Display Module Level
3](https://www.w3.org/TR/css-display-3/) is extended with a new inner
display type:

 --------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Name: [display](https://www.w3.org/TR/css-display-3/#propdef-display)
 [New values:](https://www.w3.org/TR/css-values-4/#value-defs) [\<display-outside\>](https://www.w3.org/TR/css-display-3/#typedef-display-outside) [\|\|](https://www.w3.org/TR/css-values-4/#comb-any) \[ [\<display-inside\>](https://www.w3.org/TR/css-display-3/#typedef-display-inside) [\|](https://www.w3.org/TR/css-values-4/#comb-one) math \]
 --------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

For elements that are not [MathML
elements](#dfn-mathml-element), if the specified value of `display` is
`block math` or `inline math` then the computed value is `block flow`
and `inline flow` respectively. For the
[`mtable`](#dfn-mtable) element the computed value is `block table` and
`inline table` respectively. For the
[`mtr`](#dfn-mtr)
element, the computed value is `table-row`. For the
[`mtd`](#dfn-mtd)
element, the computed value is `table-cell`.

[MathML elements](#dfn-mathml-element) with a computed `display` value equal to
`block math` or `inline math` control box generation and layout
according to their tag name, as described in the relevant sections.
[Unknown MathML
elements](#dfn-unknown-mathml-element) behave the same as the
[`mrow`](#dfn-mrow) element.

The `display: block math` and `display: inline math` values provide a
default layout for MathML elements while at the same time allowing to
override it with either native display values or [custom
values](https://www.w3.org/TR/css-layout-api-1/#registering-layout).
This allows authors or polyfills to define their own custom notations to
tweak or extend MathML Core.

In the following example, the default layout of the MathML
[`mrow`](#dfn-mrow) element is overridden to render its content as a
grid.

``` {aria-busy="false"}
<math>
 <msup>
 <mrow>
 <mo symmetric="false">[</mo>
 <mrow style="display: block; width: 4.5em;">
 <mrow style="display: grid;
 grid-template-columns: 1.5em 1.5em 1.5em;
 grid-template-rows: 1.5em 1.5em;
 justify-items: center;
 align-items: center;">
 <mn>12</mn>
 <mn>34</mn>
 <mn>56</mn>
 <mn>7</mn>
 <mn>8</mn>
 <mn>9</mn>
 </mrow>
 </mrow>
 <mo symmetric="false">]</mo>
 </mrow>
 <mi>α</mi>
 </msup>
</math>
```

![display example](examples/example-display.png)

::: header-wrapper
### 4.2 The `math-auto` transform

[text-transform](https://www.w3.org/TR/css-text-3/#propdef-text-transform)
property from [CSS Text Module Level
4](https://www.w3.org/TR/css-text-4/) has a new value `math-auto`. On
text nodes containing a single character, if the computed value is
`math-auto` and the character is present in the \"Original\" column of
[C.1 `italic` mappings](#italic-mappings) then it is converted
to the corresponding character from the \"italic\" column.

A common style convention is to render identifiers with multiple letters
(e.g. the function name \"exp\") with normal style and identifiers with
a single letter (e.g. the variable \"n\") with italic style. The
`math-auto` property is intended to implement this default behavior,
which can be overridden by authors if necessary. Note that mathematical
fonts are designed with a special kind of italic glyphs located at the
Unicode positions of [C.1 `italic`
mappings](#italic-mappings), which differ from the shaping
obtained via italic font style. Compare this mathematical formula
rendered with the Latin Modern Math font using `font-style: italic`
(left) and `text-transform: math-auto` (right):

![font-style: italic VS text-transform:
math-auto](examples/example-text-transform-math-auto.png)

::: header-wrapper
### 4.3 The `math-style` property

--------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------
 Name: [math-style]
 [Value:](https://www.w3.org/TR/css-values-4/#value-defs) normal [\|](https://www.w3.org/TR/css-values-4/#comb-one) compact
 [Initial:](https://www.w3.org/TR/css-cascade-4/#initial-values) normal
 [Applies to:](https://www.w3.org/TR/css-cascade-4/#applies-to) All elements
 [Inherited:](https://www.w3.org/TR/css-cascade-4/#inherited-property) yes
 [Percentages:](https://www.w3.org/TR/css-values/#percentages) n/a
 [Computed value:](https://www.w3.org/TR/css-cascade-4/#computed) specified keyword
 [Canonical order:](https://www.w3.org/TR/cssom-1/#serializing-css-values) n/a
 [Animation type:](https://www.w3.org/TR/web-animations/#animation-type) by computed value type
 Media: visual
 --------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------

When `math-style` is `compact`, the math layout on descendants tries to
minimize the [logical
height](https://www.w3.org/TR/css-writing-modes-4/#logical-height)
by applying the following rules:

- The
 [font-size](https://www.w3.org/TR/css-fonts-4/#propdef-font-size)
 is scaled down when its specified value is `math` and the computed
 value of
 [`math-depth`](#propdef-math-depth) is `auto-add` (default for
 [`mfrac`](#dfn-mfrac)) as described in [4.5 The `math-depth`
 property](#the-math-script-level-property).
- Operators with the [`largeop`](#dfn-largeop) property do not follow rules
 from [3.2.4.3 Layout of operators](#layout-of-operators) to
 make them bigger.
- Under-/overscripts attached to an operator with the
 [`movablelimits`](#dfn-movablelimits) property are actually drawn
 as sub-/superscripts as described in [3.4.2.1 Children of `<munder>`,
 `<mover>`,
 `<munderover>`](#children-of-munder-mover-munderover).
- Smaller vertical gaps and shifts from the [OpenType MATH
 table](#opentype-math-table) are used for fractions and radicals, as
 described in [3.3.2.1 Fraction with nonzero line
 thickness](#fraction-with-nonzero-line-thickness), [3.3.2.2
 Fraction with zero line
 thickness](#fraction-with-zero-line-thickness) and [3.3.3.1
 Radical symbol](#radical-symbol).

The following example shows a mathematical formula rendered with its
[`math`](#dfn-math) root styled with `math-style: compact` (left) and
`math-style: normal` (right). In the former case, the font-size is
automatically scaled down within the fractions and the summation limits
are rendered as subscript and superscript of the ∑. In the latter case,
the ∑ is drawn bigger than normal text and vertical gaps within
fractions (even relative to current font-size) are larger.

![math-style example](examples/example-math-style.png)

These two `math-style` values typically correspond to mathematical
expressions in inline and display mode respectively
\[[TeXBook](#bib-texbook "The TeXBook")\]. A
mathematical formula in display mode may automatically switch to inline
mode within some subformulas (e.g. scripts, matrix elements, numerators
and denominators, etc) and it is sometimes desirable to override this
default behavior. The
[math-style](#propdef-math-style) property allows to easily implement these
features for MathML in the [user agent
stylesheet](#dfn-user-agent-stylesheet) and with the
[displaystyle](#dfn-displaystyle) attribute; and also exposes them to
polyfills.

::: header-wrapper
### 4.4 The `math-shift` property

--------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------
 Name: [math-shift]
 [Value:](https://www.w3.org/TR/css-values-4/#value-defs) normal [\|](https://www.w3.org/TR/css-values-4/#comb-one) compact
 [Initial:](https://www.w3.org/TR/css-cascade-4/#initial-values) normal
 [Applies to:](https://www.w3.org/TR/css-cascade-4/#applies-to) All elements
 [Inherited:](https://www.w3.org/TR/css-cascade-4/#inherited-property) yes
 [Percentages:](https://www.w3.org/TR/css-values/#percentages) n/a
 [Computed value:](https://www.w3.org/TR/css-cascade-4/#computed) specified keyword
 [Canonical order:](https://www.w3.org/TR/cssom-1/#serializing-css-values) n/a
 [Animation type](https://www.w3.org/TR/web-animations/#animation-type): by computed value type
 Media: visual
 --------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------

If the value of `math-shift` is `compact`, the math layout on
descendants will use the
[superscriptShiftUpCramped](#dfn-superscriptshiftupcramped) parameter to place superscript. If the
value of `math-shift` is `normal`, the math will use the
[superscriptShiftUp](#dfn-superscriptshiftup) parameter instead.

This property is used for positioning superscript during the layout of
MathML [scripted
elements](#dfn-scripted-elements). See § [3.4.1 Subscripts and Superscripts
`<msub>`, `<msup>`,
`<msubsup>`](#subscripts-and-superscripts-msub-msup-msubsup),
[3.4.3 Prescripts and Tensor Indices
`<mmultiscripts>`](#prescripts-and-tensor-indices-mmultiscripts)
and [3.4.2 Underscripts and Overscripts `<munder>`, `<mover>`,
`<munderover>`](#underscripts-and-overscripts-munder-mover-munderover).

In the following example, the two \"x squared\" are rendered with
compact [math-style](#propdef-math-style) and the same `font-size`. However, the one
within the square root is rendered with compact `math-shift` while the
other one is rendered with normal `math-shift`, leading to subtle
different shift of the superscript \"2\".

![math-shift example](examples/example-math-shift.png)

Per \[[TeXBook](#bib-texbook "The TeXBook")\], a mathematical formula uses normal style by
default but may switch to compact style (\"cramped\" in TeX\'s
terminology) within some subformulas (e.g. radicals, fraction
denominators, etc). The
[math-shift](#propdef-math-shift) property allows to easily implement these
rules for MathML in the [user agent
stylesheet](#dfn-user-agent-stylesheet). Page authors or developers of polyfills
may also benefit from having access to this property to tweak or refine
the default implementation.

::: header-wrapper
### 4.5 The `math-depth` property

A new [math-depth](#propdef-math-depth) property is introduced to describe a
notion of \"depth\" for each element of a mathematical formula, with
respect to the top-level container of that formula. Concretely, this is
used to determine the computed value of the
[font-size](https://www.w3.org/TR/css-fonts-4/#propdef-font-size)
property when its specified value is `math`.

 --------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Name: [math-depth]
 [Value:](https://www.w3.org/TR/css-values-4/#value-defs) auto-add [\|](https://www.w3.org/TR/css-values-4/#comb-one) add(\<integer\>) [\|](https://www.w3.org/TR/css-values-4/#comb-one) \<integer\>
 [Initial:](https://www.w3.org/TR/css-cascade-4/#initial-values) 0
 [Applies to:](https://www.w3.org/TR/css-cascade-4/#applies-to) All elements
 [Inherited:](https://www.w3.org/TR/css-cascade-4/#inherited-property) yes
 [Percentages:](https://www.w3.org/TR/css-values/#percentages) n/a
 [Computed value:](https://www.w3.org/TR/css-cascade-4/#computed) an integer, see below
 [Canonical order:](https://www.w3.org/TR/cssom-1/#serializing-css-values) n/a
 [Animation type:](https://www.w3.org/TR/web-animations/#animation-type) by computed value type
 Media: visual
 --------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

The computed value of the
[math-depth](#propdef-math-depth) value is determined as follows:

- If the specified value of
 [math-depth](#propdef-math-depth) is `auto-add` and the inherited value of
 [math-style](#propdef-math-style) is `compact` then the computed value of
 [math-depth](#propdef-math-depth) of the element is its inherited value
 plus one.
- If the specified value of
 [math-depth](#propdef-math-depth) is of the form `add(<integer>)` then the
 computed value of
 [math-depth](#propdef-math-depth) of the element is its inherited value
 plus the specified integer.
- If the specified value of
 [math-depth](#propdef-math-depth) is of the form `<integer>` then the
 computed value of
 [math-depth](#propdef-math-depth) of the element is the specified integer.
- Otherwise, the computed value of
 [math-depth](#propdef-math-depth) of the element is the inherited one.

If the specified value of
[font-size](https://www.w3.org/TR/css-fonts-4/#propdef-font-size)
is `math` then the computed value of
[font-size](https://www.w3.org/TR/css-fonts-4/#propdef-font-size)
is obtained by multiplying the inherited value of
[font-size](https://www.w3.org/TR/css-fonts-4/#propdef-font-size)
by a nonzero scale factor calculated by the following procedure:

1. Let A be the inherited
 [math-depth](#propdef-math-depth) value, B the computed
 [math-depth](#propdef-math-depth) value, C be 0.71 and S be 1.0
2. - If A = B then return S.
 - If B \< A, swap A and B and set `InvertScaleFactor` to true.
 - Otherwise B \> A and set `InvertScaleFactor` to false.
3. Let E be B - A, which is positive.
4. If the inherited [first available
 font](https://www.w3.org/TR/css-fonts-4/#first-available-font)
 has an OpenType MATH table:
 - If A ≤ 0 and B ≥ 2 then multiply S by
 [scriptScriptPercentScaleDown](#dfn-scriptscriptpercentscaledown) and decrement E by 2.
 - Otherwise if A = 1 then multiply S by
 [scriptScriptPercentScaleDown](#dfn-scriptscriptpercentscaledown) /
 [scriptPercentScaleDown](#dfn-scriptpercentscaledown) and decrement E by 1.
 - Otherwise if B = 1 then multiply S by
 [scriptPercentScaleDown](#dfn-scriptpercentscaledown) and decrement E by 1.
5. Multiply S by C^E^.
6. Return S if `InvertScaleFactor` is false and 1/S otherwise.

The following example shows a mathematical formula with normal
[math-style](#propdef-math-style) rendered with the Latin Modern Math font.
When entering subexpressions like scripts or fractions, the font-size is
automatically scaled down according to the values of MATH table
contained in that font. Note that font-size is scaled down when entering
the superscripts but even faster when entering a root\'s prescript. Also
it is scaled down when entering the inner fraction but not when entering
the outer one, due to automatic change of
[math-style](#propdef-math-style) in fractions.

![font-size-scriptlevel
example](examples/example-font-size-scriptlevel.png)

These rules from \[[TeXBook](#bib-texbook "The TeXBook")\] are subtle and it\'s worth having a separate
`math-depth` mechanism to express and handle them. They can be
implemented in MathML using the [user agent
stylesheet](#dfn-user-agent-stylesheet). Page authors or developers of polyfills
may also benefit from having access to this property to tweak or refine
the default implementation. In particular, the
[scriptlevel](#dfn-scriptlevel) attribute from MathML provides a way to perform
`math-depth` changes.

::: header-wrapper
## 5. OpenType `MATH` table

This chapter describes features provided by `MATH` table of an OpenType
font
\[[OPEN-FONT-FORMAT](#bib-open-font-format "Information technology — Coding of audio-visual objects — Part 22: Open Font Format")\]. Throughout this chapter, a C-like notation
`Table.Subtable1[index].Subtable2.Parameter` is used to denote OpenType
parameters. Such parameters may not be available (e.g. if the font lacks
one of the subtable, has an invalid offset, etc) and so fallback options
are provided.

It is strongly encouraged to render MathML with a math font with the
proper OpenType features. There is no guarantee that the fallback
options provided will provide good enough rendering.

OpenType values expressed in design units (perhaps indirectly via a
`MathValueRecord` entry) are scaled to appropriate values for layout
purpose, taking into account `head.unitsPerEm`, CSS
[font-size](https://www.w3.org/TR/css-fonts-4/#propdef-font-size)
or zoom level.

::: header-wrapper
### 5.1 Layout constants (`MathConstants`)

These are global layout constants for the [first available
font](https://www.w3.org/TR/css-fonts-4/#first-available-font):

[Default fallback constant]
: 0

[Default rule thickness]
: `post.underlineThickness` or [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[scriptPercentScaleDown]
: `MATH.MathConstants.scriptPercentScaleDown / 100` or 0.71 if
 `MATH.MathConstants.scriptPercentScaleDown` is null or not
 available.

[scriptScriptPercentScaleDown]
: `MATH.MathConstants.scriptScriptPercentScaleDown / 100` or 0.5041 if
 `MATH.MathConstants.scriptScriptPercentScaleDown` is null or not
 available.

[displayOperatorMinHeight]
: `MATH.MathConstants.displayOperatorMinHeight` or [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[axisHeight]
: `MATH.MathConstants.axisHeight` or half `OS/2.sxHeight` if the
 constant is not available.

[accentBaseHeight]
: `MATH.MathConstants.accentBaseHeight` or `OS/2.sxHeight` if the
 constant is not available.

[subscriptShiftDown]
: `MATH.MathConstants.subscriptShiftDown` or `OS/2.ySubscriptYOffset`
 if the constant is not available.

[subscriptTopMax]
: `MATH.MathConstants.subscriptTopMax` or ⅘ × `OS/2.sxHeight` if the
 constant is not available.

[subscriptBaselineDropMin]
: `MATH.MathConstants.subscriptBaselineDropMin` or [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[superscriptShiftUp]
: `MATH.MathConstants.superscriptShiftUp` or
 `OS/2.ySuperscriptYOffset` if the constant is not available.

[superscriptShiftUpCramped]
: `MATH.MathConstants.superscriptShiftUpCramped` or [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[superscriptBottomMin]
: `MATH.MathConstants.superscriptBottomMin` or ¼ × `OS/2.sxHeight` if
 the constant is not available.

[superscriptBaselineDropMax]
: `MATH.MathConstants.superscriptBaselineDropMax` or [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[subSuperscriptGapMin]
: `MATH.MathConstants.subSuperscriptGapMin` or 4 × [default rule
 thickness](#dfn-default-rule-thickness) if the constant is not available.

[superscriptBottomMaxWithSubscript]
: `MATH.MathConstants.superscriptBottomMaxWithSubscript` or ⅘ ×
 `OS/2.sxHeight` if the constant is not available.

[spaceAfterScript]
: `MATH.MathConstants.spaceAfterScript` or 1/24em if the constant is
 not available.

[upperLimitGapMin]
: `MATH.MathConstants.upperLimitGapMin` or [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[upperLimitBaselineRiseMin]
: `MATH.MathConstants.upperLimitBaselineRiseMin` or [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[lowerLimitGapMin]
: `MATH.MathConstants.lowerLimitGapMin` or [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[lowerLimitBaselineDropMin]
: `MATH.MathConstants.lowerLimitBaselineDropMin` or [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[stackTopShiftUp]
: `MATH.MathConstants.stackTopShiftUp` or [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[stackTopDisplayStyleShiftUp]
: `MATH.MathConstants.stackTopDisplayStyleShiftUp` or [Default
 fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[stackBottomShiftDown]
: `MATH.MathConstants.stackBottomShiftDown` or [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[stackBottomDisplayStyleShiftDown]
: `MATH.MathConstants.stackBottomDisplayStyleShiftDown` or [Default
 fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[stackGapMin]
: `MATH.MathConstants.stackGapMin` or 3 × [default rule
 thickness](#dfn-default-rule-thickness) if the constant is not available.

[stackDisplayStyleGapMin]
: `MATH.MathConstants.stackDisplayStyleGapMin` or 7 × [default rule
 thickness](#dfn-default-rule-thickness) if the constant is not available.

[stretchStackTopShiftUp]
: `MATH.MathConstants.stretchStackTopShiftUp` or [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[stretchStackBottomShiftDown]
: `MATH.MathConstants.stretchStackBottomShiftDown` or [Default
 fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[stretchStackGapAboveMin]
: `MATH.MathConstants.stretchStackGapAboveMin` or [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[stretchStackGapBelowMin]
: `MATH.MathConstants.stretchStackGapBelowMin` or [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[fractionNumeratorShiftUp]
: `MATH.MathConstants.fractionNumeratorShiftUp` or [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[fractionNumeratorDisplayStyleShiftUp]
: `MATH.MathConstants.fractionNumeratorDisplayStyleShiftUp` or
 [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[fractionDenominatorShiftDown]
: `MATH.MathConstants.fractionDenominatorShiftDown` or [Default
 fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[fractionDenominatorDisplayStyleShiftDown]
: `MATH.MathConstants.fractionDenominatorDisplayStyleShiftDown` or
 [Default fallback
 constant](#dfn-default-fallback-constant) if the constant is not available.

[fractionNumeratorGapMin]
: `MATH.MathConstants.fractionNumeratorGapMin` or [default rule
 thickness](#dfn-default-rule-thickness) if the constant is not available.

[fractionNumDisplayStyleGapMin]
: `MATH.MathConstants.fractionNumDisplayStyleGapMin` or 3 × [default
 rule
 thickness](#dfn-default-rule-thickness) if the constant is not available.

[fractionRuleThickness]
: `MATH.MathConstants.fractionRuleThickness` or [default rule
 thickness](#dfn-default-rule-thickness) if the constant is not available.

[fractionDenominatorGapMin]
: `MATH.MathConstants.fractionDenominatorGapMin` or [default rule
 thickness](#dfn-default-rule-thickness) if the constant is not available.

[fractionDenomDisplayStyleGapMin]
: `MATH.MathConstants.fractionDenomDisplayStyleGapMin` or 3 × [default
 rule
 thickness](#dfn-default-rule-thickness) if the constant is not available.

[overbarVerticalGap]
: `MATH.MathConstants.overbarVerticalGap` or 3 × [default rule
 thickness](#dfn-default-rule-thickness) if the constant is not available.

[overbarExtraAscender]
: `MATH.MathConstants.overbarExtraAscender` or [default rule
 thickness](#dfn-default-rule-thickness) if the constant is not available.

[underbarVerticalGap]
: `MATH.MathConstants.underbarVerticalGap` or 3 × [default rule
 thickness](#dfn-default-rule-thickness) if the constant is not available.

[underbarExtraDescender]
: `MATH.MathConstants.underbarExtraDescender` or [default rule
 thickness](#dfn-default-rule-thickness) if the constant is not available.

[radicalVerticalGap]
: `MATH.MathConstants.radicalVerticalGap` or 1¼ × [default rule
 thickness](#dfn-default-rule-thickness) if the constant is not available.

[radicalDisplayStyleVerticalGap]
: `MATH.MathConstants.radicalDisplayStyleVerticalGap` or [default rule
 thickness](#dfn-default-rule-thickness) + ¼ `OS/2.sxHeight` if the constant is
 not available.

[radicalRuleThickness]
: `MATH.MathConstants.radicalRuleThickness` or [default rule
 thickness](#dfn-default-rule-thickness) if the constant is not available.

[radicalExtraAscender]
: `MATH.MathConstants.radicalExtraAscender` or [default rule
 thickness](#dfn-default-rule-thickness) if the constant is not available.

[radicalKernBeforeDegree]
: `MATH.MathConstants.radicalKernBeforeDegree` or 5/18em if the
 constant is not available.

[radicalKernAfterDegree]
: `MATH.MathConstants.radicalKernAfterDegree` or −10/18em if the
 constant is not available.

[radicalDegreeBottomRaisePercent]
: `MATH.MathConstants.radicalDegreeBottomRaisePercent / 100.0` or 0.6
 if the constant is not available.

::: header-wrapper
### 5.2 Glyph information (`MathGlyphInfo`)

MathTopAccentAttachment is at risk.

These are per-glyph tables for the [first available
font](https://www.w3.org/TR/css-fonts-4/#first-available-font):

[MathItalicsCorrectionInfo]
: The subtable `MATH.MathGlyphInfo.MathItalicsCorrectionInfo` of
 italics correction values. Use the corresponding value in
 `MATH.MathGlyphInfo.MathItalicsCorrectionInfo.italicsCorrection` if
 there is one for the requested glyph or `0` otherwise.

[MathTopAccentAttachment]
: The subtable `MATH.MathGlyphInfo.MathTopAccentAttachment` of
 positioning top math accents along the [inline
 axis](https://www.w3.org/TR/css-writing-modes-4/#inline-axis).
 Use the corresponding value in
 `MATH.MathGlyphInfo.MathTopAccentAttachment.topAccentAttachment` if
 there is one for the requested glyph or half the advance width of
 the glyph otherwise.

::: header-wrapper
### 5.3 Size variants for operators (`MathVariants`)

This section describes how to handle stretchy glyphs of arbitrary size
using the `MATH.MathVariants` table.

::: header-wrapper
#### 5.3.1 The `GlyphAssembly` table

This section is based on
\[[OPEN-TYPE-MATH-IN-HARFBUZZ](#bib-open-type-math-in-harfbuzz "OpenType MATH in HarfBuzz")\]. For convenience, the following definitions are
used:

- [o~min~] is `MATH.MathVariant.minConnectorOverlap`.
- A `GlyphPartRecord` is an *extender* if and only if
 `GlyphPartRecord.partFlags` has the `fExtender` flag set.
- A `GlyphAssembly` is *horizontal* if it is obtained from
 `MathVariant.horizGlyphConstructionOffsets`. Otherwise it is
 *vertical* (and obtained from
 `MathVariant.vertGlyphConstructionOffsets`).
- For a given `GlyphAssembly` table, [N~Ext~] (respectively
 [N~NonExt~]) is the number of extenders (respectively
 non-extenders) in `GlyphAssembly.partRecords`.
- For a given `GlyphAssembly` table, [S~Ext~] (respectively
 [S~NonExt~]) is the sum of `GlyphPartRecord.fullAdvance` for all
 extenders (respectively non-extenders) in `GlyphAssembly.partRecords`.
- [S~Ext,NonOverlapping~] =
 [S~Ext~](#dfn-sext)
 − [o~min~](#dfn-omin) [N~Ext~](#dfn-next) is the sum of maximum non overlapping parts of
 extenders.

User agents must treat the `GlyphAssembly` as invalid if the following
conditions are not satisfied:

- [N~Ext~](#dfn-next)
 \> 0. Otherwise, the assembly cannot be grown by repeating extenders.
- [S~Ext,NonOverlapping~](#dfn-sext-nonoverlapping) \> 0. Otherwise, the assembly does not
 grow when joining extenders.
- For each `GlyphPartRecord` in `GlyphAssembly.partRecords`, the values
 of `GlyphPartRecord.startConnectorLength` and
 `GlyphPartRecord.endConnectorLength` must be at least
 [o~min~](#dfn-omin).
 Otherwise, it is not possible to satisfy the condition of
 `MathVariant.minConnectorOverlap`.

In this specification, a glyph assembly is built by repeating each
extender r times and using the same overlap value o between each glyph.
The number of glyphs in such an assembly is
[AssemblyGlyphCount](r) =
[N~NonExt~](#dfn-nnonext) + r [N~Ext~](#dfn-next) while the stretch size is
[AssembySize](o, r) = [S~NonExt~](#dfn-snonext) + r
[S~Ext~](#dfn-sext) −
o
([AssemblyGlyphCount](#dfn-assemblyglyphcount)(r) − 1).

[r~min~] is the minimal number of repetitions needed to obtain an
assembly of size at least T, i.e. the minimal r such that
[AssembySize](#dfn-assembysize)([o~min~](#dfn-omin), r) ≥ T. It is defined as the maximum between 0 and the
ceiling of ((T − [S~NonExt~](#dfn-snonext) + [o~min~](#dfn-omin)
([N~NonExt~](#dfn-nnonext) − 1)) /
[S~Ext,NonOverlapping~](#dfn-sext-nonoverlapping)).

[o~max,theorical~] =
([AssembySize](#dfn-assembysize)(0, [r~min~](#dfn-rmin)) − T) /
([AssemblyGlyphCount](#dfn-assemblyglyphcount)([r~min~](#dfn-rmin)) − 1) is the theorical overlap obtained by
splitting evenly the extra size of an assembly built with null overlap.

[o~max~] is the maximum overlap possible to build an assembly of
size at least T by repeating each extender
[r~min~](#dfn-rmin)
times. If
[AssemblyGlyphCount](#dfn-assemblyglyphcount)([r~min~](#dfn-rmin)) ≤ 1, then the actual overlap value is
irrelevant. Otherwise, o~max~ is defined to be the minimum of:

- [o~max,theorical~](#dfn-omax-theorical).
- `GlyphPartRecord.startConnectorLength` for all the entries in
 `GlyphAssembly.partRecords`, excluding the last one if it is not an
 extender.
- `GlyphPartRecord.endConnectorLength` for all the entries in
 `GlyphAssembly.partRecords`, excluding the first one if it is not an
 extender.

The [glyph assembly stretch size] for a target size T
is [AssembySize](#dfn-assembysize)([o~max~](#dfn-omax), [r~min~](#dfn-rmin)).

The [glyph assembly width], [glyph assembly
ascent] and [glyph assembly
descent] are defined as follows:

- If `GlyphAssembly` is vertical, the width is the maximum advance width
 of the glyphs of ID `GlyphPartRecord.glyphID` for all the
 `GlyphPartRecord` in `GlyphAssembly.partRecords`, the ascent is the
 [glyph assembly stretch
 size](#dfn-glyph-assembly-stretch-size) for a given target size `T` and the
 descent is 0.
- Otherwise, the `GlyphAssembly` is horizontal, the width is [glyph
 assembly stretch
 size](#dfn-glyph-assembly-stretch-size) for a given target size `T` while the
 ascent (respectively descent) is the maximum ascent (respectively
 descent) of the glyphs of ID `GlyphPartRecord.glyphID` for all the
 `GlyphPartRecord` in `GlyphAssembly.partRecords`.

The [glyph assembly height] is the sum of the [glyph assembly
ascent](#dfn-glyph-assembly-ascent) and [glyph assembly
descent](#dfn-glyph-assembly-descent).

The horizontal (respectively vertical) metrics for a vertical
(respectively horizontal) glyph assembly do not depend on the target
size `T`.

The [shaping of the glyph assembly] is performed
with the following algorithm:

1. Calculate [r~min~](#dfn-rmin) and [o~max~](#dfn-omax).
2. Set `(x, y)` to `(0, 0)`, `RepetitionCounter` to 0 and `PartIndex`
 to -1.
3. Repeat the following steps:
 1. If `RepetitionCounter` is 0:
 1. Increment `PartIndex`.
 2. If `PartIndex` is `GlyphAssembly.partCount` then stop.
 3. Otherwise, set `Part` to
 `GlyphAssembly.partRecords[PartIndex]`. Set
 `RepetitionCounter` to
 [r~min~](#dfn-rmin) if `Part` is an extender and to 1
 otherwise.
 2. - If the glyph assembly is horizontal then draw the glyph of ID
 `Part.glyphID` so that its (left, baseline) coordinates are at
 position `(x, y)`. Set `x` to
 `x + Part.fullAdvance − `[`o`~`max`~](#dfn-omax)`.`
 - Otherwise (if the glyph assembly is vertical), then draw the
 glyph of id `Part.glyphID` so that its (left, bottom)
 coordinates are at position `(x, y)`. Set `y` to
 `y − Part.fullAdvance + `[`o`~`max`~](#dfn-omax)`.`
 3. Decrement `RepetitionCounter`.

::: header-wrapper
#### 5.3.2 Algorithms for glyph stretching

The [preferred inline size of a glyph stretched along the block
axis] is calculated
using the following algorithm:

1. Set `S` to the glyph\'s advance width.
2. If there is a `MathGlyphConstruction` table in the
 `MathVariants.vertGlyphConstructionOffsets` table for the given
 glyph:
 1. For each `MathGlyphVariantRecord` in
 `MathGlyphConstruction.mathGlyphVariantRecord`, ensure that `S`
 is at least the advance width of the glyph of id
 `MathGlyphVariantRecord.variantGlyph`.
 2. If there is valid `GlyphAssembly` subtable, then ensure that `S`
 is at least the [glyph assembly
 width](#dfn-glyph-assembly-width).
3. Return `S`.

The [preferred inline size of a glyph stretched along the block
axis](#dfn-preferred-inline-size-of-a-glyph-stretched-along-the-block-axis) will return the maximum width of all
possible vertical constructions for that glyph. In practice, math fonts
are designed so that vertical constructions are almost constant width,
so possible over-estimation of the actual width is small.

The algorithm to [shape a stretchy glyph] to inline
(respectively block) dimension `T` is the following:

1. If there is not any `MathGlyphConstruction` table in the
 `MathVariants.horizGlyphConstructionOffsets` table (respectively
 `MathVariants.vertGlyphConstructionOffsets` table) for the given
 glyph then exit with failure.
2. If the glyph\'s advance width (respectively height) is at least `T`
 then use normal shaping and bounding box for that glyph, the
 [MathItalicsCorrectionInfo](#dfn-mathitalicscorrectioninfo) for that glyph as italic correction
 and exit with success.
3. Browse the list of `MathGlyphVariantRecord` in
 `MathGlyphConstruction.mathGlyphVariantRecord`. If one
 `MathGlyphVariantRecord.advanceMeasurement` is at least `T` then use
 normal shaping and bounding box for
 `MathGlyphVariantRecord.variantGlyph`, the
 [MathItalicsCorrectionInfo](#dfn-mathitalicscorrectioninfo) for that glyph as italic correction
 and exit with success.
4. If there is valid `GlyphAssembly` subtable then use the bounding box
 given by [glyph assembly
 width](#dfn-glyph-assembly-width), [glyph assembly
 height](#dfn-glyph-assembly-height), [glyph assembly
 ascent](#dfn-glyph-assembly-ascent), [glyph assembly
 descent](#dfn-glyph-assembly-descent), the value
 `GlyphAssembly.italicsCorrection` as italic correction, perform
 [shaping of the glyph
 assembly](#dfn-shaping-of-the-glyph-assembly) and exit with success.
5. If none of the stretch options above allowed to cover the target
 size `T`, then choose last one that was tried and exit with success.

If a font does not provide tables for stretchy constructions, User
Agents may use their own internal constructions as a fallback such as
the one suggested in [B.4 Unicode-based Glyph
Assemblies](#unicode-based-glyph-assemblies).

The algorithm to [get a glyph] corresponding to a character `c`
given a directionality `dir` is the following:

- Let `g` be the glyph corresponding to `c` in the [first available
 font](https://www.w3.org/TR/css-fonts-4/#first-available-font).
 If it is not possible to find such a glyph, then exit with failure.
- If `dir` is `rtl`:
 - If there exists an OpenType rtlm variant of `g` in the [first
 available
 font](https://www.w3.org/TR/css-fonts-4/#first-available-font),
 then return it and exit with success.
 \[[OPEN-FONT-FORMAT](#bib-open-font-format "Information technology — Coding of audio-visual objects — Part 22: Open Font Format")\]
 - Otherwise, if `c` has the Bidi_Mirrored property
 \[[BIDI](#bib-bidi "Unicode Bidirectional Algorithm")\]:
 - If `c` has a corresponding mirrored codepoint, `c'`, then return
 the glyph corresponding to `c'` and exit with success. If it is
 not possible to find such a glyph, then exit with failure.
 - Otherwise, exit with failure.

 :::::
 :::
 Note
 :::

 :::
 These failure cases are for when a character should be mirrored
 according to its Bidi_Mirrored property, but no corresponding
 codepoint or glyph exists.
 :::
 :::::
 - Otherwise, return `g` and exit with success.
- Assert: `dir` is `ltr`.
- Return `g` and exit with success.

::: header-wrapper
## A. [User Agent Stylesheet]

``` {aria-busy="false"}
@namespace url(http://www.w3.org/1998/Math/MathML);

/* Universal rules */
* {
 font-size: math;
 display: block math;
 writing-mode: horizontal-tb !important;
}

/* The <math> element */
math {
 direction: ltr;
 text-indent: 0;
 letter-spacing: normal;
 line-height: normal;
 word-spacing: normal;
 font-family: math;
 font-size: inherit;
 font-style: normal;
 font-weight: normal;
 display: inline math;
 math-shift: normal;
 math-style: compact;
 math-depth: 0;
}
math[display="block" i] {
 display: block math;
 math-style: normal;
}
math[display="inline" i] {
 display: inline math;
 math-style: compact;
}

/* <mrow>-like elements */
semantics > :not(:first-child) {
 display: none;
}
maction > :not(:first-child) {
 display: none;
}
merror {
 border: 1px solid red;
 background-color: lightYellow;
}
mphantom {
 visibility: hidden;
}

/* Token elements */
mi {
 text-transform: math-auto;
}

/* Tables */
mtable {
 display: inline-table;
 math-style: compact;
}
mtr {
 display: table-row;
}
mtd {
 display: table-cell;
 /* Centering inside table cells should rely on box alignment properties.
 See https://github.com/w3c/mathml-core/issues/156 */
 text-align: center;
 padding: 0.5ex 0.4em;
}

/* Fractions */
mfrac {
 padding-inline: 1px;
}
mfrac > * {
 math-depth: auto-add;
 math-style: compact;
}
mfrac > :nth-child(2) {
 math-shift: compact;
}

/* Other rules for scriptlevel, displaystyle and math-shift */
mroot > :not(:first-child) {
 math-depth: add(2);
 math-style: compact;
}
mroot, msqrt {
 math-shift: compact;
}
msub > :not(:first-child),
msup > :not(:first-child),
msubsup > :not(:first-child),
mmultiscripts > :not(:first-child),
munder > :not(:first-child),
mover > :not(:first-child),
munderover > :not(:first-child) {
 math-depth: add(1);
 math-style: compact;
}
munder[accentunder="true" i] > :nth-child(2),
mover[accent="true" i] > :nth-child(2),
munderover[accentunder="true" i] > :nth-child(2),
munderover[accent="true" i] > :nth-child(3) {
 font-size: inherit;
}
msub > :nth-child(2),
msubsup > :nth-child(2),
mmultiscripts > :nth-child(even),
mmultiscripts > mprescripts ~ :nth-child(odd),
mover[accent="true" i] > :first-child,
munderover[accent="true" i] > :first-child {
 math-shift: compact;
}
mmultiscripts > mprescripts ~ :nth-child(even) {
 math-shift: inherit;
}
```

::: header-wrapper
## B. Operator Tables

::: header-wrapper
### B.1 Operator Dictionary

This section describes how to determine values of [3.2.4.2
Dictionary-based attributes](#dictionary-based-attributes) and
[stretch axis](#dfn-stretch-axis) of operators. Compact tables
below are suitable for computer manipulation, see [B.2 Operator
Dictionary (human-readable)](#operator-dictionary-human) for
an alternative presentation.

The [algorithm to set the properties of an operator from its
category] is as follows:

- Set `minsize` to `100%`.
- Set `maxsize` to `∞`.
- Find the row corresponding to the specified category on [Figure
 26](#operator-dictionary-categories-values "Operators values for each category.The third column provides a 4-bit encoding of the categorieswhere the 2 least significant bits encode the form infix (0), prefix (1) and postfix (2).").
- Set `lspace` and `rspace` to the value specified in the corresponding
 column.
- For each property `stretchy`, `symmetric`, `largeop`, `movablelimits`,
 set that property to `true` if it is listed in the last column or to
 `false` otherwise.

The [algorithm to determine the category of an
operator] (`Content`, `Form`) is as folllows:

1. If `Content` as an UTF-16 string does not have length or 1 or 2 then
 exit with category `Default`.
2. If `Content` is a single character in the range U+0320--U+03FF then
 exit with category `Default`. Otherwise, if it has two characters:
 - If `Content` is the surrogate pairs corresponding to U+1EEF0
 ARABIC MATHEMATICAL OPERATOR MEEM WITH HAH WITH TATWEEL or U+1EEF1
 ARABIC MATHEMATICAL OPERATOR HAH WITH DAL and `Form` is `postfix`,
 exit with category `I`.
 - If the second character is U+0338 COMBINING LONG SOLIDUS OVERLAY
 or U+20D2 COMBINING LONG VERTICAL LINE OVERLAY then replace
 `Content` with the first character and move to step 3.
 - Otherwise, if `Content` is listed in
 [`Operators_2_ascii_chars`](#operator-dictionary-compact-special-tables)
 then replace `Content` with the Unicode character \"U+0320 plus
 the index of `Content` in `Operators_2_ascii_chars`\" and move to
 step 3.
 - Otherwise exit with category `Default`.
3. If `Form` is infix and `Content` corresponds to one of U+007C
 VERTICAL LINE or U+223C TILDE OPERATOR then exit with category
 `ForceDefault`. If the category of (`Content`, `Form`) provided by
 table [Figure
 25](#operator-dictionary-category-table "Mapping from operator (Content, Form) to a category.Total size: 725 entries, 639 bytes(assuming characters are UTF-16 and 1-byte range lengths).")
 has N/A encoding in table [Figure
 26](#operator-dictionary-categories-values "Operators values for each category.The third column provides a 4-bit encoding of the categorieswhere the 2 least significant bits encode the form infix (0), prefix (1) and postfix (2).")
 (namely if it has category `L` or `M`), then exit with that
 category. Otherwise:
 - Set `Key` to `Content` if it is in range U+0000--U+03FF; or to
 `Content` − 0x1C00 if it is in range U+2000--U+2BFF. Otherwise,
 exit with category `Default`.
 - Add 0x0000, 0x1000, 0x2000 to `Key` according to whether `Form` is
 `infix`, `prefix`, `postfix` respectively.
 - [Assert](https://infra.spec.whatwg.org/#assert): `Key` is at most
 0x2FFF.
 - Search an `Entry` in table [Figure
 27](#operator-dictionary-categories-hexa-table "List of entries for the largest categories, sorted by key.Key is Entry % 0x4000, category encoding is Entry / 0x1000.Total size: 716 entries, 590 bytes(assuming 4 bits for range lengths).")
 such that `Entry` % 0x4000 is equal to `Key`. If one is found then
 return the category corresponding to encoding `Entry` / 0x1000 in
 [Figure
 26](#operator-dictionary-categories-values "Operators values for each category.The third column provides a 4-bit encoding of the categorieswhere the 2 least significant bits encode the form infix (0), prefix (1) and postfix (2).").
 Otherwise, return category `Default`.

<figure id="operator-dictionary-compact-special-tables">
<table>
<tbody>
<tr>
<th>Special Table</th>
<th>Entries</th>
</tr>

<tr>
<td><code>Operators_2_ascii_chars</code></td>
<td>18 entries (2-characters ASCII strings):
<code>'!!', '!=', '&amp;&amp;', '**', '*=', '++', '+=', '--', '-=', '-&gt;', '//', '/=', ':=', '&lt;=', '&lt;&gt;', '==', '&gt;=', '||', </code></td>
</tr>
<tr>
<td><code>Operators_fence</code></td>
<td>61 entries (16 Unicode ranges):
<code>[U+0028–U+0029], {U+005B}, {U+005D}, [U+007B–U+007D], {U+0331}, {U+2016}, [U+2018–U+2019], [U+201C–U+201D], [U+2308–U+230B], [U+2329–U+232A], [U+2772–U+2773], [U+27E6–U+27EF], {U+2980}, [U+2983–U+2999], [U+29D8–U+29DB], [U+29FC–U+29FD], </code></td>
</tr>
<tr>
<td><code>Operators_separator</code></td>
<td>3 entries: <code>U+002C, U+003B, U+2063, </code></td>
</tr>
</tbody>
</table>
<figcaption><a href="#operator-dictionary-compact-special-tables"
class="self-link">Figure 24</a> <span class="fig-title">Special tables
for the operator dictionary.<br />
Total size: 82 entries, 90 bytes<br />
(assuming characters are UTF-16 and 1-byte range
lengths).</span></figcaption>
</figure>

<figure id="operator-dictionary-category-table">
<table>
<tbody>
<tr>
<th>(Content, Form) keys</th>
<th>Category</th>
</tr>

<tr>
<td>313 entries (35 Unicode ranges) in <strong>infix</strong> form:
<code>[U+2190–U+2195], [U+219A–U+21AE], [U+21B0–U+21B5], {U+21B9}, [U+21BC–U+21D5], [U+21DA–U+21F0], [U+21F3–U+21FF], {U+2794}, {U+2799}, [U+279B–U+27A1], [U+27A5–U+27A6], [U+27A8–U+27AF], {U+27B1}, {U+27B3}, {U+27B5}, {U+27B8}, [U+27BA–U+27BE], [U+27F0–U+27F1], [U+27F4–U+27FF], [U+2900–U+2920], [U+2934–U+2937], [U+2942–U+2975], [U+297C–U+297F], [U+2B04–U+2B07], [U+2B0C–U+2B11], [U+2B30–U+2B3E], [U+2B40–U+2B4C], [U+2B60–U+2B65], [U+2B6A–U+2B6D], [U+2B70–U+2B73], [U+2B7A–U+2B7D], [U+2B80–U+2B87], {U+2B95}, [U+2BA0–U+2BAF], {U+2BB8}, </code></td>
<td>A</td>
</tr>
<tr>
<td>108 entries (31 Unicode ranges) in <strong>infix</strong> form:
<code>{U+002B}, {U+002D}, {U+00B1}, {U+00F7}, {U+0322}, {U+2044}, [U+2212–U+2216], [U+2227–U+222A], {U+2236}, {U+2238}, [U+228C–U+228E], [U+2293–U+2296], {U+2298}, [U+229D–U+229F], [U+22BB–U+22BD], [U+22CE–U+22CF], [U+22D2–U+22D3], [U+2795–U+2797], {U+29B8}, {U+29BC}, [U+29C4–U+29C5], [U+29F5–U+29FB], [U+2A1F–U+2A2E], [U+2A38–U+2A3A], {U+2A3E}, [U+2A40–U+2A4F], [U+2A51–U+2A63], {U+2ADB}, {U+2AF6}, {U+2AFB}, {U+2AFD}, </code></td>
<td>B</td>
</tr>
<tr>
<td>64 entries (33 Unicode ranges) in <strong>infix</strong> form:
<code>{U+0025}, {U+002A}, {U+002E}, [U+003F–U+0040], {U+005E}, {U+00B7}, {U+00D7}, {U+0323}, {U+032E}, {U+2022}, {U+2043}, [U+2217–U+2219], {U+2240}, {U+2297}, [U+2299–U+229B], [U+22A0–U+22A1], {U+22BA}, [U+22C4–U+22C7], [U+22C9–U+22CC], [U+2305–U+2306], {U+27CB}, {U+27CD}, [U+29C6–U+29C8], [U+29D4–U+29D7], {U+29E2}, [U+2A1D–U+2A1E], [U+2A2F–U+2A37], [U+2A3B–U+2A3D], {U+2A3F}, {U+2A50}, [U+2A64–U+2A65], [U+2ADC–U+2ADD], {U+2AFE}, </code></td>
<td>C</td>
</tr>
<tr>
<td>52 entries (22 Unicode ranges) in <strong>prefix</strong> form:
<code>{U+0021}, {U+002B}, {U+002D}, {U+00AC}, {U+00B1}, {U+0331}, {U+2018}, {U+201C}, [U+2200–U+2201], [U+2203–U+2204], {U+2207}, [U+2212–U+2213], [U+221F–U+2222], [U+2234–U+2235], {U+223C}, [U+22BE–U+22BF], {U+2310}, {U+2319}, [U+2795–U+2796], {U+27C0}, [U+299B–U+29AF], [U+2AEC–U+2AED], </code></td>
<td>D</td>
</tr>
<tr>
<td>40 entries (21 Unicode ranges) in <strong>postfix</strong> form:
<code>[U+0021–U+0022], [U+0025–U+0027], {U+0060}, {U+00A8}, {U+00B0}, [U+00B2–U+00B4], [U+00B8–U+00B9], [U+02CA–U+02CB], [U+02D8–U+02DA], {U+02DD}, {U+0311}, {U+0320}, {U+0325}, {U+0327}, {U+0331}, [U+2019–U+201B], [U+201D–U+201F], [U+2032–U+2037], {U+2057}, [U+20DB–U+20DC], {U+23CD}, </code></td>
<td>E</td>
</tr>
<tr>
<td>30 entries in <strong>prefix</strong> form:
<code>U+0028, U+005B, U+007B, U+007C, U+2016, U+2308, U+230A, U+2329, U+2772, U+27E6, U+27E8, U+27EA, U+27EC, U+27EE, U+2980, U+2983, U+2985, U+2987, U+2989, U+298B, U+298D, U+298F, U+2991, U+2993, U+2995, U+2997, U+2999, U+29D8, U+29DA, U+29FC, </code></td>
<td>F</td>
</tr>
<tr>
<td>30 entries in <strong>postfix</strong> form:
<code>U+0029, U+005D, U+007C, U+007D, U+2016, U+2309, U+230B, U+232A, U+2773, U+27E7, U+27E9, U+27EB, U+27ED, U+27EF, U+2980, U+2984, U+2986, U+2988, U+298A, U+298C, U+298E, U+2990, U+2992, U+2994, U+2996, U+2998, U+2999, U+29D9, U+29DB, U+29FD, </code></td>
<td>G</td>
</tr>
<tr>
<td>27 entries (2 Unicode ranges) in <strong>prefix</strong> form:
<code>[U+222B–U+2233], [U+2A0B–U+2A1C], </code></td>
<td>H</td>
</tr>
<tr>
<td>22 entries (13 Unicode ranges) in <strong>postfix</strong> form:
<code>[U+005E–U+005F], {U+007E}, {U+00AF}, [U+02C6–U+02C7], {U+02C9}, {U+02CD}, {U+02DC}, {U+02F7}, {U+0302}, {U+203E}, [U+2322–U+2323], [U+23B4–U+23B5], [U+23DC–U+23E1], </code></td>
<td>I</td>
</tr>
<tr>
<td>22 entries (6 Unicode ranges) in <strong>prefix</strong> form:
<code>[U+220F–U+2211], [U+22C0–U+22C3], [U+2A00–U+2A0A], [U+2A1D–U+2A1E], {U+2AFC}, {U+2AFF}, </code></td>
<td>J</td>
</tr>
<tr>
<td>8 entries (5 Unicode ranges) in <strong>infix</strong> form:
<code>{U+002F}, {U+005C}, {U+005F}, [U+2061–U+2064], {U+2206}, </code></td>
<td>K</td>
</tr>
<tr>
<td>6 entries (3 Unicode ranges) in <strong>prefix</strong> form:
<code>[U+2145–U+2146], {U+2202}, [U+221A–U+221C], </code></td>
<td>L</td>
</tr>
<tr>
<td>3 entries in <strong>infix</strong> form:
<code>U+002C, U+003A, U+003B, </code></td>
<td>M</td>
</tr>
</tbody>
</table>
<figcaption><a href="#operator-dictionary-category-table"
class="self-link">Figure 25</a> <span class="fig-title">Mapping from
operator (Content, Form) to a category.<br />
Total size: 725 entries, 639 bytes<br />
(assuming characters are UTF-16 and 1-byte range
lengths).</span></figcaption>
</figure>

<figure id="operator-dictionary-categories-values">
<table>
<tbody>
<tr>
<th>Category</th>
<th>Form</th>
<th>Encoding</th>
<th>lspace</th>
<th>rspace</th>
<th>properties</th>
</tr>

<tr>
<td>Default</td>
<td>N/A</td>
<td>N/A</td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>ForceDefault</td>
<td>N/A</td>
<td>N/A</td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>A</td>
<td>infix</td>
<td>0x0</td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>B</td>
<td>infix</td>
<td>0x4</td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>C</td>
<td>infix</td>
<td>0x8</td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>D</td>
<td>prefix</td>
<td>0x1</td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>E</td>
<td>postfix</td>
<td>0x2</td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>F</td>
<td>prefix</td>
<td>0x5</td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric</td>
</tr>
<tr>
<td>G</td>
<td>postfix</td>
<td>0x6</td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric</td>
</tr>
<tr>
<td>H</td>
<td>prefix</td>
<td>0x9</td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>I</td>
<td>postfix</td>
<td>0xA</td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>J</td>
<td>prefix</td>
<td>0xD</td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>K</td>
<td>infix</td>
<td>0xC</td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>L</td>
<td>prefix</td>
<td>N/A</td>
<td><code>0.16666666666666666em</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>M</td>
<td>infix</td>
<td>N/A</td>
<td><code>0</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
</tbody>
</table>
<figcaption><a href="#operator-dictionary-categories-values"
class="self-link">Figure 26</a> <span class="fig-title">Operators values
for each category.<br />
The third column provides a 4-bit encoding of the categories<br />
where the 2 least significant bits encode the form infix (0), prefix (1)
and postfix (2).</span></figcaption>
</figure>

<figure id="operator-dictionary-categories-hexa-table">
716 entries (236 ranges of length at most 16):
<code>{0x8025}, {0x802A}, {0x402B}, {0x402D}, {0x802E}, {0xC02F}, [0x803F–0x8040], {0xC05C}, {0x805E}, {0xC05F}, {0x40B1}, {0x80B7}, {0x80D7}, {0x40F7}, {0x4322}, {0x8323}, {0x832E}, {0x8422}, {0x8443}, {0x4444}, [0xC461–0xC464], [0x0590–0x0595], [0x059A–0x05A9], [0x05AA–0x05AE], [0x05B0–0x05B5], {0x05B9}, [0x05BC–0x05CB], [0x05CC–0x05D5], [0x05DA–0x05E9], [0x05EA–0x05F0], [0x05F3–0x05FF], {0xC606}, [0x4612–0x4616], [0x8617–0x8619], [0x4627–0x462A], {0x4636}, {0x4638}, {0x8640}, [0x468C–0x468E], [0x4693–0x4696], {0x8697}, {0x4698}, [0x8699–0x869B], [0x469D–0x469F], [0x86A0–0x86A1], {0x86BA}, [0x46BB–0x46BD], [0x86C4–0x86C7], [0x86C9–0x86CC], [0x46CE–0x46CF], [0x46D2–0x46D3], [0x8705–0x8706], {0x0B94}, [0x4B95–0x4B97], {0x0B99}, [0x0B9B–0x0BA1], [0x0BA5–0x0BA6], [0x0BA8–0x0BAF], {0x0BB1}, {0x0BB3}, {0x0BB5}, {0x0BB8}, [0x0BBA–0x0BBE], {0x8BCB}, {0x8BCD}, [0x0BF0–0x0BF1], [0x0BF4–0x0BFF], [0x0D00–0x0D0F], [0x0D10–0x0D1F], {0x0D20}, [0x0D34–0x0D37], [0x0D42–0x0D51], [0x0D52–0x0D61], [0x0D62–0x0D71], [0x0D72–0x0D75], [0x0D7C–0x0D7F], {0x4DB8}, {0x4DBC}, [0x4DC4–0x4DC5], [0x8DC6–0x8DC8], [0x8DD4–0x8DD7], {0x8DE2}, [0x4DF5–0x4DFB], [0x8E1D–0x8E1E], [0x4E1F–0x4E2E], [0x8E2F–0x8E37], [0x4E38–0x4E3A], [0x8E3B–0x8E3D], {0x4E3E}, {0x8E3F}, [0x4E40–0x4E4F], {0x8E50}, [0x4E51–0x4E60], [0x4E61–0x4E63], [0x8E64–0x8E65], {0x4EDB}, [0x8EDC–0x8EDD], {0x4EF6}, {0x4EFB}, {0x4EFD}, {0x8EFE}, [0x0F04–0x0F07], [0x0F0C–0x0F11], [0x0F30–0x0F3E], [0x0F40–0x0F4C], [0x0F60–0x0F65], [0x0F6A–0x0F6D], [0x0F70–0x0F73], [0x0F7A–0x0F7D], [0x0F80–0x0F87], {0x0F95}, [0x0FA0–0x0FAF], {0x0FB8}, {0x1021}, {0x5028}, {0x102B}, {0x102D}, {0x505B}, [0x507B–0x507C], {0x10AC}, {0x10B1}, {0x1331}, {0x5416}, {0x1418}, {0x141C}, [0x1600–0x1601], [0x1603–0x1604], {0x1607}, [0xD60F–0xD611], [0x1612–0x1613], [0x161F–0x1622], [0x962B–0x9633], [0x1634–0x1635], {0x163C}, [0x16BE–0x16BF], [0xD6C0–0xD6C3], {0x5708}, {0x570A}, {0x1710}, {0x1719}, {0x5729}, {0x5B72}, [0x1B95–0x1B96], {0x1BC0}, {0x5BE6}, {0x5BE8}, {0x5BEA}, {0x5BEC}, {0x5BEE}, {0x5D80}, {0x5D83}, {0x5D85}, {0x5D87}, {0x5D89}, {0x5D8B}, {0x5D8D}, {0x5D8F}, {0x5D91}, {0x5D93}, {0x5D95}, {0x5D97}, {0x5D99}, [0x1D9B–0x1DAA], [0x1DAB–0x1DAF], {0x5DD8}, {0x5DDA}, {0x5DFC}, [0xDE00–0xDE0A], [0x9E0B–0x9E1A], [0x9E1B–0x9E1C], [0xDE1D–0xDE1E], [0x1EEC–0x1EED], {0xDEFC}, {0xDEFF}, [0x2021–0x2022], [0x2025–0x2027], {0x6029}, {0x605D}, [0xA05E–0xA05F], {0x2060}, [0x607C–0x607D], {0xA07E}, {0x20A8}, {0xA0AF}, {0x20B0}, [0x20B2–0x20B4], [0x20B8–0x20B9], [0xA2C6–0xA2C7], {0xA2C9}, [0x22CA–0x22CB], {0xA2CD}, [0x22D8–0x22DA], {0xA2DC}, {0x22DD}, {0xA2F7}, {0xA302}, {0x2311}, {0x2320}, {0x2325}, {0x2327}, {0x2331}, {0x6416}, [0x2419–0x241B], [0x241D–0x241F], [0x2432–0x2437], {0xA43E}, {0x2457}, [0x24DB–0x24DC], {0x6709}, {0x670B}, [0xA722–0xA723], {0x672A}, [0xA7B4–0xA7B5], {0x27CD}, [0xA7DC–0xA7E1], {0x6B73}, {0x6BE7}, {0x6BE9}, {0x6BEB}, {0x6BED}, {0x6BEF}, {0x6D80}, {0x6D84}, {0x6D86}, {0x6D88}, {0x6D8A}, {0x6D8C}, {0x6D8E}, {0x6D90}, {0x6D92}, {0x6D94}, {0x6D96}, [0x6D98–0x6D99], {0x6DD9}, {0x6DDB}, {0x6DFD}, </code>
<figcaption><a href="#operator-dictionary-categories-hexa-table"
class="self-link">Figure 27</a> <span class="fig-title">List of entries
for the largest categories, sorted by key.<br />
<code>Key</code> is <code>Entry</code> % 0x4000, category encoding is
<code>Entry</code> / 0x1000.<br />
Total size: 716 entries, 590 bytes<br />
(assuming 4 bits for range lengths).</span></figcaption>
</figure>

- Tables of [Figure
 25](#operator-dictionary-category-table "Mapping from operator (Content, Form) to a category.Total size: 725 entries, 639 bytes(assuming characters are UTF-16 and 1-byte range lengths).")
 and [Figure
 27](#operator-dictionary-categories-hexa-table "List of entries for the largest categories, sorted by key.Key is Entry % 0x4000, category encoding is Entry / 0x1000.Total size: 716 entries, 590 bytes(assuming 4 bits for range lengths).")
 are encoded as ranges to take profit of the presence of many
 contiguous Unicode blocks.
- To quickly find an entry in these tables, one can still perform a
 binary search over the range starts, followed by an extra check on the
 range length.
- Since log is concave, it is more efficient to perform one binary
 search on the whole table of [Figure
 27](#operator-dictionary-categories-hexa-table "List of entries for the largest categories, sorted by key.Key is Entry % 0x4000, category encoding is Entry / 0x1000.Total size: 716 entries, 590 bytes(assuming 4 bits for range lengths).")
 rather than on each large subtable of [Figure
 25](#operator-dictionary-category-table "Mapping from operator (Content, Form) to a category.Total size: 725 entries, 639 bytes(assuming characters are UTF-16 and 1-byte range lengths).").

The [intrinsic stretch axis] a Unicode character
`c` is *inline* if it belongs to the list below. Otherwise, the
intrinsic stretch axis of `c` is *block*.

<figure id="inline-stretch-axis">
<code>U+003D, U+005E, U+005F, U+007E, U+00AF, U+02C6, U+02C7, U+02C9, U+02CD, U+02DC, U+02F7, U+0302, U+0332, U+203E, U+20D0, U+20D1, U+20D6, U+20D7, U+20E1, U+2190, U+2192, U+2194, U+2198, U+2199, U+219A, U+219B, U+219C, U+219D, U+219E, U+21A0, U+21A2, U+21A3, U+21A4, U+21A6, U+21A9, U+21AA, U+21AB, U+21AC, U+21AD, U+21AE, U+21B4, U+21B9, U+21BC, U+21BD, U+21C0, U+21C1, U+21C4, U+21C6, U+21C7, U+21C9, U+21CB, U+21CC, U+21CD, U+21CE, U+21CF, U+21D0, U+21D2, U+21D4, U+21DA, U+21DB, U+21DC, U+21DD, U+21E0, U+21E2, U+21E4, U+21E5, U+21E6, U+21E8, U+21F0, U+21F4, U+21F6, U+21F7, U+21F8, U+21F9, U+21FA, U+21FB, U+21FC, U+21FD, U+21FE, U+21FF, U+2322, U+2323, U+23B4, U+23B5, U+23DC, U+23DD, U+23DE, U+23DF, U+23E0, U+23E1, U+2500, U+2794, U+2799, U+279B, U+279C, U+279D, U+279E, U+279F, U+27A0, U+27A1, U+27A5, U+27A6, U+27A8, U+27A9, U+27AA, U+27AB, U+27AC, U+27AD, U+27AE, U+27AF, U+27B1, U+27B3, U+27B5, U+27B8, U+27BA, U+27BB, U+27BC, U+27BD, U+27BE, U+27F4, U+27F5, U+27F6, U+27F7, U+27F8, U+27F9, U+27FA, U+27FB, U+27FC, U+27FD, U+27FE, U+27FF, U+2900, U+2901, U+2902, U+2903, U+2904, U+2905, U+2906, U+2907, U+290C, U+290D, U+290E, U+290F, U+2910, U+2911, U+2914, U+2915, U+2916, U+2917, U+2918, U+2919, U+291A, U+291B, U+291C, U+291D, U+291E, U+291F, U+2920, U+2942, U+2943, U+2944, U+2945, U+2946, U+2947, U+2948, U+294A, U+294B, U+294E, U+2950, U+2952, U+2953, U+2956, U+2957, U+295A, U+295B, U+295E, U+295F, U+2962, U+2964, U+2966, U+2967, U+2968, U+2969, U+296A, U+296B, U+296C, U+296D, U+2970, U+2971, U+2972, U+2973, U+2974, U+2975, U+297C, U+297D, U+2B04, U+2B05, U+2B0C, U+2B30, U+2B31, U+2B32, U+2B33, U+2B34, U+2B35, U+2B36, U+2B37, U+2B38, U+2B39, U+2B3A, U+2B3B, U+2B3C, U+2B3D, U+2B3E, U+2B40, U+2B41, U+2B42, U+2B43, U+2B44, U+2B45, U+2B46, U+2B47, U+2B48, U+2B49, U+2B4A, U+2B4B, U+2B4C, U+2B60, U+2B62, U+2B64, U+2B6A, U+2B6C, U+2B70, U+2B72, U+2B7A, U+2B7C, U+2B80, U+2B82, U+2B84, U+2B86, U+2B95, U+FE35, U+FE36, U+FE37, U+FE38, U+1EEF0, U+1EEF1, </code>
<figcaption><a href="#inline-stretch-axis" class="self-link">Figure
28</a> <span class="fig-title">Sorted list of Unicode code points
corresponding to operators with inline stretch axis.<br />
Total size: 246 entries, 492 bytes (assuming 16 bits for all but the
non-BMP entries).</span></figcaption>
</figure>

The intrinsic stretch axis could be included as a boolean property of
the operator dictionary. But since it does not depend on the form and
since very few operators can stretch along the [inline
axis](https://www.w3.org/TR/css-writing-modes-4/#inline-axis),
it is better implemented as a separate sorted array. Each entry can be
encoded with 16 bytes if U+1EEF0 ARABIC MATHEMATICAL OPERATOR MEEM WITH
HAH WITH TATWEEL and U+1EEF1 ARABIC MATHEMATICAL OPERATOR HAH WITH DAL
are tested separately.

::: header-wrapper
### B.2 Operator Dictionary (human-readable)

*This section is non-normative.*

The following dictionary provides a human-readable version of [B.1
Operator Dictionary](#operator-dictionary). Please refer to
[3.2.4.2 Dictionary-based
attributes](#dictionary-based-attributes) for explanation
about how to use this dictionary and how to determine the values
`Content` and `Form` indexing together the dictionary.

The values for [`rspace`](#dfn-rspace) and
[`lspace`](#dfn-lspace) are indicated in the corresponding columns.
The values of [`stretchy`](#dfn-stretchy),
[`symmetric`](#dfn-symmetric),
[`largeop`](#dfn-largeop),
[`movablelimits`](#dfn-movablelimits) are `true` if they are listed
in the \"properties\" column.

<figure id="operator-dictionary-table">
<table class="sortable">
<thead>
<tr>
<th>Content</th>
<th>Stretch Axis</th>
<th>form</th>
<th>lspace</th>
<th>rspace</th>
<th>properties</th>
</tr>
</thead>
<tbody>
<tr>
<td>&lt; U+003C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>= U+003D</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>&gt; U+003E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>| U+007C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>fence</td>
</tr>
<tr>
<td>↖ U+2196</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>↗ U+2197</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>↘ U+2198</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>↙ U+2199</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>↯ U+21AF</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>↶ U+21B6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>↷ U+21B7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>↸ U+21B8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>↺ U+21BA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>↻ U+21BB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⇖ U+21D6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⇗ U+21D7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⇘ U+21D8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⇙ U+21D9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⇱ U+21F1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⇲ U+21F2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∈ U+2208</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∉ U+2209</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∊ U+220A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∋ U+220B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∌ U+220C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∍ U+220D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∝ U+221D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∣ U+2223</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∤ U+2224</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∥ U+2225</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∦ U+2226</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∷ U+2237</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∹ U+2239</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∺ U+223A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∻ U+223B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∼ U+223C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∽ U+223D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∾ U+223E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≁ U+2241</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≂ U+2242</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≃ U+2243</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≄ U+2244</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≅ U+2245</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≆ U+2246</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≇ U+2247</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≈ U+2248</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≉ U+2249</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≊ U+224A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≋ U+224B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≌ U+224C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≍ U+224D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≎ U+224E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≏ U+224F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≐ U+2250</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≑ U+2251</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≒ U+2252</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≓ U+2253</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≔ U+2254</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≕ U+2255</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≖ U+2256</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≗ U+2257</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≘ U+2258</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≙ U+2259</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≚ U+225A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≛ U+225B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≜ U+225C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≝ U+225D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≞ U+225E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≟ U+225F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≠ U+2260</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≡ U+2261</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≢ U+2262</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≣ U+2263</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≤ U+2264</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≥ U+2265</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≦ U+2266</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≧ U+2267</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≨ U+2268</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≩ U+2269</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≪ U+226A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≫ U+226B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≬ U+226C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≭ U+226D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≮ U+226E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≯ U+226F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≰ U+2270</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≱ U+2271</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≲ U+2272</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≳ U+2273</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≴ U+2274</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≵ U+2275</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≶ U+2276</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≷ U+2277</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≸ U+2278</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≹ U+2279</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≺ U+227A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≻ U+227B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≼ U+227C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≽ U+227D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≾ U+227E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≿ U+227F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊀ U+2280</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊁ U+2281</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊂ U+2282</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊃ U+2283</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊄ U+2284</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊅ U+2285</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊆ U+2286</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊇ U+2287</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊈ U+2288</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊉ U+2289</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊊ U+228A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊋ U+228B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊏ U+228F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊐ U+2290</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊑ U+2291</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊒ U+2292</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊜ U+229C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊢ U+22A2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊣ U+22A3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊦ U+22A6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊧ U+22A7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊨ U+22A8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊩ U+22A9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊪ U+22AA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊫ U+22AB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊬ U+22AC</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊭ U+22AD</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊮ U+22AE</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊯ U+22AF</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊰ U+22B0</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊱ U+22B1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊲ U+22B2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊳ U+22B3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊴ U+22B4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊵ U+22B5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊶ U+22B6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊷ U+22B7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊸ U+22B8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋈ U+22C8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋍ U+22CD</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋐ U+22D0</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋑ U+22D1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋔ U+22D4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋕ U+22D5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋖ U+22D6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋗ U+22D7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋘ U+22D8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋙ U+22D9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋚ U+22DA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋛ U+22DB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋜ U+22DC</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋝ U+22DD</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋞ U+22DE</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋟ U+22DF</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋠ U+22E0</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋡ U+22E1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋢ U+22E2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋣ U+22E3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋤ U+22E4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋥ U+22E5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋦ U+22E6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋧ U+22E7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋨ U+22E8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋩ U+22E9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋪ U+22EA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋫ U+22EB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋬ U+22EC</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋭ U+22ED</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋲ U+22F2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋳ U+22F3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋴ U+22F4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋵ U+22F5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋶ U+22F6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋷ U+22F7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋸ U+22F8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋹ U+22F9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋺ U+22FA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋻ U+22FB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋼ U+22FC</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋽ U+22FD</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋾ U+22FE</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋿ U+22FF</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⌁ U+2301</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⍼ U+237C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⎋ U+238B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>➘ U+2798</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>➚ U+279A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>➧ U+27A7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>➲ U+27B2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>➴ U+27B4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>➶ U+27B6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>➷ U+27B7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>➹ U+27B9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⟂ U+27C2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⟲ U+27F2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⟳ U+27F3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤡ U+2921</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤢ U+2922</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤣ U+2923</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤤ U+2924</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤥ U+2925</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤦ U+2926</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤧ U+2927</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤨ U+2928</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤩ U+2929</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤪ U+292A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤫ U+292B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤬ U+292C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤭ U+292D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤮ U+292E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤯ U+292F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤰ U+2930</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤱ U+2931</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤲ U+2932</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤳ U+2933</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤸ U+2938</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤹ U+2939</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤺ U+293A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤻ U+293B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤼ U+293C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤽ U+293D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤾ U+293E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⤿ U+293F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⥀ U+2940</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⥁ U+2941</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⥶ U+2976</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⥷ U+2977</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⥸ U+2978</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⥹ U+2979</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⥺ U+297A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⥻ U+297B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦁ U+2981</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦂ U+2982</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦶ U+29B6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦷ U+29B7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦹ U+29B9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧀ U+29C0</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧁ U+29C1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧎ U+29CE</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧏ U+29CF</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧐ U+29D0</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧑ U+29D1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧒ U+29D2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧓ U+29D3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧟ U+29DF</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧡ U+29E1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧣ U+29E3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧤ U+29E4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧥ U+29E5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧦ U+29E6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧴ U+29F4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩦ U+2A66</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩧ U+2A67</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩨ U+2A68</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩩ U+2A69</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩪ U+2A6A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩫ U+2A6B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩬ U+2A6C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩭ U+2A6D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩮ U+2A6E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩯ U+2A6F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩰ U+2A70</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩱ U+2A71</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩲ U+2A72</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩳ U+2A73</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩴ U+2A74</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩵ U+2A75</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩶ U+2A76</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩷ U+2A77</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩸ U+2A78</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩹ U+2A79</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩺ U+2A7A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩻ U+2A7B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩼ U+2A7C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩽ U+2A7D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩾ U+2A7E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩿ U+2A7F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪀ U+2A80</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪁ U+2A81</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪂ U+2A82</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪃ U+2A83</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪄ U+2A84</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪅ U+2A85</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪆ U+2A86</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪇ U+2A87</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪈ U+2A88</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪉ U+2A89</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪊ U+2A8A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪋ U+2A8B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪌ U+2A8C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪍ U+2A8D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪎ U+2A8E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪏ U+2A8F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪐ U+2A90</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪑ U+2A91</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪒ U+2A92</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪓ U+2A93</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪔ U+2A94</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪕ U+2A95</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪖ U+2A96</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪗ U+2A97</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪘ U+2A98</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪙ U+2A99</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪚ U+2A9A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪛ U+2A9B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪜ U+2A9C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪝ U+2A9D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪞ U+2A9E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪟ U+2A9F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪠ U+2AA0</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪡ U+2AA1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪢ U+2AA2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪣ U+2AA3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪤ U+2AA4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪥ U+2AA5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪦ U+2AA6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪧ U+2AA7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪨ U+2AA8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪩ U+2AA9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪪ U+2AAA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪫ U+2AAB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪬ U+2AAC</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪭ U+2AAD</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪮ U+2AAE</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪯ U+2AAF</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪰ U+2AB0</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪱ U+2AB1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪲ U+2AB2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪳ U+2AB3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪴ U+2AB4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪵ U+2AB5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪶ U+2AB6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪷ U+2AB7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪸ U+2AB8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪹ U+2AB9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪺ U+2ABA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪻ U+2ABB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪼ U+2ABC</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪽ U+2ABD</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪾ U+2ABE</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⪿ U+2ABF</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫀ U+2AC0</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫁ U+2AC1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫂ U+2AC2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫃ U+2AC3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫄ U+2AC4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫅ U+2AC5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫆ U+2AC6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫇ U+2AC7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫈ U+2AC8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫉ U+2AC9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫊ U+2ACA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫋ U+2ACB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫌ U+2ACC</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫍ U+2ACD</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫎ U+2ACE</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫏ U+2ACF</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫐ U+2AD0</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫑ U+2AD1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫒ U+2AD2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫓ U+2AD3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫔ U+2AD4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫕ U+2AD5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫖ U+2AD6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫗ U+2AD7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫘ U+2AD8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫙ U+2AD9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫚ U+2ADA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫞ U+2ADE</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫟ U+2ADF</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫠ U+2AE0</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫡ U+2AE1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫢ U+2AE2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫣ U+2AE3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫤ U+2AE4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫥ U+2AE5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫦ U+2AE6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫧ U+2AE7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫨ U+2AE8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫩ U+2AE9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫪ U+2AEA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫫ U+2AEB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫮ U+2AEE</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫲ U+2AF2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫳ U+2AF3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫴ U+2AF4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫵ U+2AF5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫷ U+2AF7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫸ U+2AF8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫹ U+2AF9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫺ U+2AFA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⬀ U+2B00</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⬁ U+2B01</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⬂ U+2B02</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⬃ U+2B03</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⬈ U+2B08</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⬉ U+2B09</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⬊ U+2B0A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⬋ U+2B0B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⬿ U+2B3F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭍ U+2B4D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭎ U+2B4E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭏ U+2B4F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭚ U+2B5A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭛ U+2B5B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭜ U+2B5C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭝ U+2B5D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭞ U+2B5E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭟ U+2B5F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭦ U+2B66</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭧ U+2B67</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭨ U+2B68</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭩ U+2B69</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭮ U+2B6E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭯ U+2B6F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭶ U+2B76</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭷ U+2B77</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭸ U+2B78</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⭹ U+2B79</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮈ U+2B88</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮉ U+2B89</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮊ U+2B8A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮋ U+2B8B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮌ U+2B8C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮍ U+2B8D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮎ U+2B8E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮏ U+2B8F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮔ U+2B94</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮰ U+2BB0</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮱ U+2BB1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮲ U+2BB2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮳ U+2BB3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮴ U+2BB4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮵ U+2BB5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮶ U+2BB6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⮷ U+2BB7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⯑ U+2BD1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String != U+0021 U+003D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String *= U+002A U+003D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String += U+002B U+003D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String -= U+002D U+003D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String -&gt; U+002D U+003E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String // U+002F U+002F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String /= U+002F U+003D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String := U+003A U+003D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String &lt;= U+003C U+003D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String == U+003D U+003D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String &gt;= U+003E U+003D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String || U+007C U+007C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>fence</td>
</tr>
<tr>
<td>← U+2190</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↑ U+2191</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>→ U+2192</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↓ U+2193</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↔︎ U+2194</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↕ U+2195</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↚ U+219A</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↛ U+219B</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↜ U+219C</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↝ U+219D</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↞ U+219E</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↟ U+219F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↠ U+21A0</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↡ U+21A1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↢ U+21A2</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↣ U+21A3</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↤ U+21A4</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↥ U+21A5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↦ U+21A6</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↧ U+21A7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↨ U+21A8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↩︎ U+21A9</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↪ U+21AA</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↫ U+21AB</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↬ U+21AC</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↭ U+21AD</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↮ U+21AE</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↰ U+21B0</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↱ U+21B1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↲ U+21B2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↳ U+21B3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↴ U+21B4</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↵ U+21B5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↹ U+21B9</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↼ U+21BC</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↽ U+21BD</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↾ U+21BE</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>↿ U+21BF</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇀ U+21C0</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇁ U+21C1</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇂ U+21C2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇃ U+21C3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇄ U+21C4</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇅ U+21C5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇆ U+21C6</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇇ U+21C7</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇈ U+21C8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇉ U+21C9</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇊ U+21CA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇋ U+21CB</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇌ U+21CC</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇍ U+21CD</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇎ U+21CE</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇏ U+21CF</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇐ U+21D0</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇑ U+21D1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇒ U+21D2</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇓ U+21D3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇔ U+21D4</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇕ U+21D5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇚ U+21DA</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇛ U+21DB</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇜ U+21DC</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇝ U+21DD</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇞ U+21DE</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇟ U+21DF</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇠ U+21E0</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇡ U+21E1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇢ U+21E2</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇣ U+21E3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇤ U+21E4</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇥ U+21E5</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇦ U+21E6</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇧ U+21E7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇨ U+21E8</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇩ U+21E9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇪ U+21EA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇫ U+21EB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇬ U+21EC</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇭ U+21ED</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇮ U+21EE</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇯ U+21EF</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇰ U+21F0</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇳ U+21F3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇴ U+21F4</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇵ U+21F5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇶ U+21F6</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇷ U+21F7</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇸ U+21F8</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇹ U+21F9</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇺ U+21FA</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇻ U+21FB</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇼ U+21FC</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇽ U+21FD</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇾ U+21FE</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⇿ U+21FF</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➔ U+2794</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➙ U+2799</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➛ U+279B</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➜ U+279C</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➝ U+279D</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➞ U+279E</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➟ U+279F</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➠ U+27A0</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➡ U+27A1</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➥ U+27A5</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➦ U+27A6</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➨ U+27A8</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➩ U+27A9</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➪ U+27AA</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➫ U+27AB</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➬ U+27AC</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➭ U+27AD</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➮ U+27AE</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➯ U+27AF</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➱ U+27B1</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➳ U+27B3</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➵ U+27B5</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➸ U+27B8</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➺ U+27BA</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➻ U+27BB</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➼ U+27BC</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➽ U+27BD</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>➾ U+27BE</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⟰ U+27F0</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⟱ U+27F1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⟴ U+27F4</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⟵ U+27F5</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⟶ U+27F6</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⟷ U+27F7</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⟸ U+27F8</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⟹ U+27F9</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⟺ U+27FA</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⟻ U+27FB</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⟼ U+27FC</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⟽ U+27FD</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⟾ U+27FE</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⟿ U+27FF</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤀ U+2900</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤁ U+2901</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤂ U+2902</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤃ U+2903</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤄ U+2904</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤅ U+2905</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤆ U+2906</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤇ U+2907</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤈ U+2908</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤉ U+2909</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤊ U+290A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤋ U+290B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤌ U+290C</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤍ U+290D</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤎ U+290E</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤏ U+290F</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤐ U+2910</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤑ U+2911</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤒ U+2912</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤓ U+2913</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤔ U+2914</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤕ U+2915</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤖ U+2916</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤗ U+2917</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤘ U+2918</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤙ U+2919</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤚ U+291A</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤛ U+291B</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤜ U+291C</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤝ U+291D</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤞ U+291E</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤟ U+291F</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤠ U+2920</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤴ U+2934</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤵ U+2935</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤶ U+2936</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⤷ U+2937</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥂ U+2942</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥃ U+2943</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥄ U+2944</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥅ U+2945</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥆ U+2946</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥇ U+2947</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥈ U+2948</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥉ U+2949</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥊ U+294A</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥋ U+294B</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥌ U+294C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥍ U+294D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥎ U+294E</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥏ U+294F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥐ U+2950</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥑ U+2951</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥒ U+2952</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥓ U+2953</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥔ U+2954</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥕ U+2955</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥖ U+2956</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥗ U+2957</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥘ U+2958</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥙ U+2959</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥚ U+295A</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥛ U+295B</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥜ U+295C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥝ U+295D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥞ U+295E</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥟ U+295F</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥠ U+2960</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥡ U+2961</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥢ U+2962</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥣ U+2963</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥤ U+2964</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥥ U+2965</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥦ U+2966</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥧ U+2967</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥨ U+2968</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥩ U+2969</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥪ U+296A</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥫ U+296B</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥬ U+296C</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥭ U+296D</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥮ U+296E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥯ U+296F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥰ U+2970</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥱ U+2971</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥲ U+2972</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥳ U+2973</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥴ U+2974</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥵ U+2975</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥼ U+297C</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥽ U+297D</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥾ U+297E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⥿ U+297F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬄ U+2B04</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬅ U+2B05</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬆ U+2B06</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬇ U+2B07</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬌ U+2B0C</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬍ U+2B0D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬎ U+2B0E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬏ U+2B0F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬐ U+2B10</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬑ U+2B11</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬰ U+2B30</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬱ U+2B31</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬲ U+2B32</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬳ U+2B33</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬴ U+2B34</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬵ U+2B35</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬶ U+2B36</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬷ U+2B37</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬸ U+2B38</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬹ U+2B39</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬺ U+2B3A</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬻ U+2B3B</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬼ U+2B3C</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬽ U+2B3D</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⬾ U+2B3E</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭀ U+2B40</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭁ U+2B41</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭂ U+2B42</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭃ U+2B43</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭄ U+2B44</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭅ U+2B45</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭆ U+2B46</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭇ U+2B47</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭈ U+2B48</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭉ U+2B49</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭊ U+2B4A</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭋ U+2B4B</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭌ U+2B4C</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭠ U+2B60</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭡ U+2B61</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭢ U+2B62</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭣ U+2B63</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭤ U+2B64</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭥ U+2B65</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭪ U+2B6A</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭫ U+2B6B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭬ U+2B6C</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭭ U+2B6D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭰ U+2B70</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭱ U+2B71</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭲ U+2B72</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭳ U+2B73</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭺ U+2B7A</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭻ U+2B7B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭼ U+2B7C</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⭽ U+2B7D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮀ U+2B80</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮁ U+2B81</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮂ U+2B82</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮃ U+2B83</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮄ U+2B84</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮅ U+2B85</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮆ U+2B86</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮇ U+2B87</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮕ U+2B95</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮠ U+2BA0</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮡ U+2BA1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮢ U+2BA2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮣ U+2BA3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮤ U+2BA4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮥ U+2BA5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮦ U+2BA6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮧ U+2BA7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮨ U+2BA8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮩ U+2BA9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮪ U+2BAA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮫ U+2BAB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮬ U+2BAC</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮭ U+2BAD</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮮ U+2BAE</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮯ U+2BAF</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⮸ U+2BB8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2777777777777778em</code></td>
<td><code>0.2777777777777778em</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>+ U+002B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>- U+002D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>± U+00B1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>÷ U+00F7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⁄ U+2044</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>− U+2212</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∓ U+2213</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∔ U+2214</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∕ U+2215</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∖ U+2216</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∧ U+2227</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∨ U+2228</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∩ U+2229</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∪ U+222A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∶ U+2236</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∸ U+2238</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊌ U+228C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊍ U+228D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊎ U+228E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊓ U+2293</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊔ U+2294</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊕ U+2295</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊖ U+2296</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊘ U+2298</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊝ U+229D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊞ U+229E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊟ U+229F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊻ U+22BB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊼ U+22BC</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊽ U+22BD</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋎ U+22CE</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋏ U+22CF</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋒ U+22D2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋓ U+22D3</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>➕ U+2795</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>➖ U+2796</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>➗ U+2797</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦸ U+29B8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦼ U+29BC</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧄ U+29C4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧅ U+29C5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧵ U+29F5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧶ U+29F6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧷ U+29F7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧸ U+29F8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧹ U+29F9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧺ U+29FA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧻ U+29FB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨟ U+2A1F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨠ U+2A20</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨡ U+2A21</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨢ U+2A22</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨣ U+2A23</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨤ U+2A24</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨥ U+2A25</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨦ U+2A26</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨧ U+2A27</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨨ U+2A28</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨩ U+2A29</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨪ U+2A2A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨫ U+2A2B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨬ U+2A2C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨭ U+2A2D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨮ U+2A2E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨸ U+2A38</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨹ U+2A39</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨺ U+2A3A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨾ U+2A3E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩀ U+2A40</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩁ U+2A41</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩂ U+2A42</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩃ U+2A43</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩄ U+2A44</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩅ U+2A45</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩆ U+2A46</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩇ U+2A47</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩈ U+2A48</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩉ U+2A49</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩊ U+2A4A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩋ U+2A4B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩌ U+2A4C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩍ U+2A4D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩎ U+2A4E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩏ U+2A4F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩑ U+2A51</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩒ U+2A52</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩓ U+2A53</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩔ U+2A54</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩕ U+2A55</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩖ U+2A56</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩗ U+2A57</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩘ U+2A58</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩙ U+2A59</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩚ U+2A5A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩛ U+2A5B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩜ U+2A5C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩝ U+2A5D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩞ U+2A5E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩟ U+2A5F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩠ U+2A60</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩡ U+2A61</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩢ U+2A62</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩣ U+2A63</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫛ U+2ADB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫶ U+2AF6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫻ U+2AFB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫽ U+2AFD</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String &amp;&amp; U+0026 U+0026</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.2222222222222222em</code></td>
<td><code>0.2222222222222222em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>% U+0025</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>* U+002A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>. U+002E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>? U+003F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>@ U+0040</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>^ U+005E</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>· U+00B7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>× U+00D7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>• U+2022</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⁃ U+2043</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∗ U+2217</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∘ U+2218</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∙ U+2219</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>≀ U+2240</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊗ U+2297</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊙ U+2299</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊚ U+229A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊛ U+229B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊠ U+22A0</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊡ U+22A1</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊺ U+22BA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋄ U+22C4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋅ U+22C5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋆ U+22C6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋇ U+22C7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋉ U+22C9</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋊ U+22CA</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋋ U+22CB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⋌ U+22CC</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⌅ U+2305</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⌆ U+2306</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⟋ U+27CB</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⟍ U+27CD</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧆ U+29C6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧇ U+29C7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧈ U+29C8</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧔ U+29D4</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧕ U+29D5</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧖ U+29D6</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧗ U+29D7</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⧢ U+29E2</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨝ U+2A1D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨞ U+2A1E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨯ U+2A2F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨰ U+2A30</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨱ U+2A31</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨲ U+2A32</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨳ U+2A33</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨴ U+2A34</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨵ U+2A35</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨶ U+2A36</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨷ U+2A37</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨻ U+2A3B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨼ U+2A3C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨽ U+2A3D</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⨿ U+2A3F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩐ U+2A50</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩤ U+2A64</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⩥ U+2A65</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫝̸ U+2ADC</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫝ U+2ADD</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫾ U+2AFE</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String ** U+002A U+002A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String &lt;&gt; U+003C U+003E</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>! U+0021</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>+ U+002B</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>- U+002D</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>¬ U+00AC</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>± U+00B1</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>‘ U+2018</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>fence</td>
</tr>
<tr>
<td>“ U+201C</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>fence</td>
</tr>
<tr>
<td>∀ U+2200</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∁ U+2201</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∃ U+2203</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∄ U+2204</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∇ U+2207</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>− U+2212</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∓ U+2213</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∟ U+221F</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∠ U+2220</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∡ U+2221</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∢ U+2222</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∴ U+2234</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∵ U+2235</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∼ U+223C</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊾ U+22BE</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⊿ U+22BF</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⌐ U+2310</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⌙ U+2319</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>➕ U+2795</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>➖ U+2796</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⟀ U+27C0</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦛ U+299B</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦜ U+299C</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦝ U+299D</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦞ U+299E</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦟ U+299F</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦠ U+29A0</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦡ U+29A1</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦢ U+29A2</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦣ U+29A3</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦤ U+29A4</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦥ U+29A5</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦦ U+29A6</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦧ U+29A7</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦨ U+29A8</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦩ U+29A9</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦪ U+29AA</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦫ U+29AB</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦬ U+29AC</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦭ U+29AD</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦮ U+29AE</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⦯ U+29AF</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫬ U+2AEC</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⫭ U+2AED</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String || U+007C U+007C</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>fence</td>
</tr>
<tr>
<td>! U+0021</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>" U+0022</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>% U+0025</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>&amp; U+0026</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>' U+0027</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>` U+0060</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>¨ U+00A8</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>° U+00B0</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>² U+00B2</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>³ U+00B3</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>´ U+00B4</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>¸ U+00B8</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>¹ U+00B9</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>ˊ U+02CA</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>ˋ U+02CB</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>˘ U+02D8</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>˙ U+02D9</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>˚ U+02DA</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>˝ U+02DD</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>̑ U+0311</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>’ U+2019</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>fence</td>
</tr>
<tr>
<td>‚ U+201A</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>‛ U+201B</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>” U+201D</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>fence</td>
</tr>
<tr>
<td>„ U+201E</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>‟ U+201F</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>′ U+2032</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>″ U+2033</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>‴ U+2034</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>‵ U+2035</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>‶ U+2036</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>‷ U+2037</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⁗ U+2057</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⃛ U+20DB</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⃜ U+20DC</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⏍ U+23CD</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String !! U+0021 U+0021</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String ++ U+002B U+002B</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String -- U+002D U+002D</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr style="background: lightblue">
<td>String || U+007C U+007C</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>fence</td>
</tr>
<tr>
<td>( U+0028</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>[ U+005B</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>{ U+007B</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>| U+007C</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>‖ U+2016</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⌈ U+2308</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⌊ U+230A</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>〈 U+2329</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>❲ U+2772</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⟦ U+27E6</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⟨ U+27E8</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⟪ U+27EA</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⟬ U+27EC</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⟮ U+27EE</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦀ U+2980</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦃ U+2983</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦅ U+2985</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦇ U+2987</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦉ U+2989</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦋ U+298B</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦍ U+298D</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦏ U+298F</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦑ U+2991</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦓ U+2993</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦕ U+2995</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦗ U+2997</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦙ U+2999</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⧘ U+29D8</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⧚ U+29DA</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⧼ U+29FC</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>) U+0029</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>] U+005D</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>| U+007C</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>} U+007D</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>‖ U+2016</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⌉ U+2309</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⌋ U+230B</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>〉 U+232A</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>❳ U+2773</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⟧ U+27E7</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⟩ U+27E9</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⟫ U+27EB</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⟭ U+27ED</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⟯ U+27EF</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦀ U+2980</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦄ U+2984</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦆ U+2986</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦈ U+2988</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦊ U+298A</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦌ U+298C</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦎ U+298E</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦐ U+2990</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦒ U+2992</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦔ U+2994</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦖ U+2996</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦘ U+2998</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⦙ U+2999</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⧙ U+29D9</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⧛ U+29DB</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>⧽ U+29FD</td>
<td>block</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy symmetric fence</td>
</tr>
<tr>
<td>∫ U+222B</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>∬ U+222C</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>∭ U+222D</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>∮ U+222E</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>∯ U+222F</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>∰ U+2230</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>∱ U+2231</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>∲ U+2232</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>∳ U+2233</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨋ U+2A0B</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨌ U+2A0C</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨍ U+2A0D</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨎ U+2A0E</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨏ U+2A0F</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨐ U+2A10</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨑ U+2A11</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨒ U+2A12</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨓ U+2A13</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨔ U+2A14</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨕ U+2A15</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨖ U+2A16</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨗ U+2A17</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨘ U+2A18</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨙ U+2A19</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨚ U+2A1A</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨛ U+2A1B</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>⨜ U+2A1C</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop</td>
</tr>
<tr>
<td>^ U+005E</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>_ U+005F</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>~ U+007E</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>¯ U+00AF</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>ˆ U+02C6</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>ˇ U+02C7</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>ˉ U+02C9</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>ˍ U+02CD</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>˜ U+02DC</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>˷ U+02F7</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>̂ U+0302</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>‾ U+203E</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⌢ U+2322</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⌣ U+2323</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⎴ U+23B4</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⎵ U+23B5</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⏜ U+23DC</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⏝ U+23DD</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⏞ U+23DE</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⏟ U+23DF</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⏠ U+23E0</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>⏡ U+23E1</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr style="background: lightyellow;">
<td>𞻰 U+1EEF0</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr style="background: lightyellow;">
<td>𞻱 U+1EEF1</td>
<td>inline</td>
<td><code>postfix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>stretchy</td>
</tr>
<tr>
<td>∏ U+220F</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>∐ U+2210</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>∑ U+2211</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⋀ U+22C0</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⋁ U+22C1</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⋂ U+22C2</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⋃ U+22C3</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⨀ U+2A00</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⨁ U+2A01</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⨂ U+2A02</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⨃ U+2A03</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⨄ U+2A04</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⨅ U+2A05</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⨆ U+2A06</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⨇ U+2A07</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⨈ U+2A08</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⨉ U+2A09</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⨊ U+2A0A</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⨝ U+2A1D</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⨞ U+2A1E</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⫼ U+2AFC</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>⫿ U+2AFF</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0.16666666666666666em</code></td>
<td>symmetric largeop movablelimits</td>
</tr>
<tr>
<td>/ U+002F</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>\ U+005C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>_ U+005F</td>
<td>inline</td>
<td><code>infix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⁡ U+2061</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⁢ U+2062</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>⁣ U+2063</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>separator</td>
</tr>
<tr>
<td>⁤ U+2064</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∆ U+2206</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>ⅅ U+2145</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>ⅆ U+2146</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∂ U+2202</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>√ U+221A</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∛ U+221B</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>∜ U+221C</td>
<td>block</td>
<td><code>prefix</code></td>
<td><code>0.16666666666666666em</code></td>
<td><code>0</code></td>
<td>N/A</td>
</tr>
<tr>
<td>, U+002C</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0</code></td>
<td><code>0.16666666666666666em</code></td>
<td>separator</td>
</tr>
<tr>
<td>: U+003A</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0</code></td>
<td><code>0.16666666666666666em</code></td>
<td>N/A</td>
</tr>
<tr>
<td>; U+003B</td>
<td>block</td>
<td><code>infix</code></td>
<td><code>0</code></td>
<td><code>0.16666666666666666em</code></td>
<td>separator</td>
</tr>
</tbody>
</table>
<figcaption><a href="#operator-dictionary-table"
class="self-link">Figure 29</a> <span class="fig-title">Mapping from
operator (Content, Form) to properties.<br />
Total size: 1177 entries, ≥ 3679 bytes<br />
(assuming 'Content' uses at least one UTF-16 character, 'Stretch Axis' 1
bit, 'Form' 2 bits, the different combinations of 'rspace' and 'space'
at least 3 bits, and the different combinations of properties 3
bits).</span></figcaption>
</figure>

::: header-wrapper
### B.3 Combining Character Equivalences

*This section is non-normative.*

The following table gives mappings between spacing and non spacing
characters when used in MathML accent constructs.

+-------+-------------------------------+------------------------------+
| Style | Non Combining | Combining |
+=======+=========+=====================+========+=====================+
| below | U+002B | plus sign | U+031F | combining plus sign |
| | | | | below |
+-------+---------+---------------------+--------+---------------------+
| above | U+002D | hyphen-minus | U+0305 | combining overline |
+-------+---------+---------------------+--------+---------------------+
| below | U+002D | hyphen-minus | U+0320 | combining minus |
| | | | | sign below |
+-------+---------+---------------------+--------+---------------------+
| below | U+002D | hyphen-minus | U+0332 | combining low line |
+-------+---------+---------------------+--------+---------------------+
| above | U+002E | full stop | U+0307 | combining dot above |
+-------+---------+---------------------+--------+---------------------+
| below | U+002E | full stop | U+0323 | combining dot below |
+-------+---------+---------------------+--------+---------------------+
| above | U+005E | circumflex accent | U+0302 | combining |
| | | | | circumflex accent |
+-------+---------+---------------------+--------+---------------------+
| below | U+005E | circumflex accent | U+032D | combining |
| | | | | circumflex accent |
| | | | | below |
+-------+---------+---------------------+--------+---------------------+
| below | U+005F | low line | U+0332 | combining low line |
+-------+---------+---------------------+--------+---------------------+
| above | U+0060 | grave accent | U+0300 | combining grave |
| | | | | accent |
+-------+---------+---------------------+--------+---------------------+
| below | U+0060 | grave accent | U+0316 | combining grave |
| | | | | accent below |
+-------+---------+---------------------+--------+---------------------+
| above | U+007E | tilde | U+0303 | combining tilde |
+-------+---------+---------------------+--------+---------------------+
| below | U+007E | tilde | U+0330 | combining tilde |
| | | | | below |
+-------+---------+---------------------+--------+---------------------+
| above | U+00A8 | diaeresis | U+0308 | combining diaeresis |
+-------+---------+---------------------+--------+---------------------+
| below | U+00A8 | diaeresis | U+0324 | combining diaeresis |
| | | | | below |
+-------+---------+---------------------+--------+---------------------+
| above | U+00AF | macron | U+0304 | combining macron |
+-------+---------+---------------------+--------+---------------------+
| above | U+00AF | macron | U+0305 | combining overline |
+-------+---------+---------------------+--------+---------------------+
| above | U+00B4 | acute accent | U+0301 | combining acute |
| | | | | accent |
+-------+---------+---------------------+--------+---------------------+
| below | U+00B4 | acute accent | U+0317 | combining acute |
| | | | | accent below |
+-------+---------+---------------------+--------+---------------------+
| below | U+00B8 | cedilla | U+0327 | combining cedilla |
+-------+---------+---------------------+--------+---------------------+
| above | U+02C6 | modifier letter | U+0302 | combining |
| | | circumflex accent | | circumflex accent |
+-------+---------+---------------------+--------+---------------------+
| above | U+02C7 | caron | U+030C | combining caron |
+-------+---------+---------------------+--------+---------------------+
| below | U+02C7 | caron | U+032C | combining caron |
| | | | | below |
+-------+---------+---------------------+--------+---------------------+
| above | U+02D8 | breve | U+0306 | combining breve |
+-------+---------+---------------------+--------+---------------------+
| below | U+02D8 | breve | U+032E | combining breve |
| | | | | below |
+-------+---------+---------------------+--------+---------------------+
| above | U+02D9 | dot above | U+0307 | combining dot above |
+-------+---------+---------------------+--------+---------------------+
| below | U+02D9 | dot above | U+0323 | combining dot below |
+-------+---------+---------------------+--------+---------------------+
| below | U+02DB | ogonek | U+0328 | combining ogonek |
+-------+---------+---------------------+--------+---------------------+
| above | U+02DC | small tilde | U+0303 | combining tilde |
+-------+---------+---------------------+--------+---------------------+
| below | U+02DC | small tilde | U+0330 | combining tilde |
| | | | | below |
+-------+---------+---------------------+--------+---------------------+
| above | U+02DD | double acute accent | U+030B | combining double |
| | | | | acute accent |
+-------+---------+---------------------+--------+---------------------+
| above | U+203E | overline | U+0305 | combining overline |
+-------+---------+---------------------+--------+---------------------+
| above | U+2190 | leftwards arrow | U+20D6 | combining left |
| | | | | arrow above |
+-------+---------+---------------------+--------+---------------------+
| above | U+2192 | rightwards arrow | U+20D7 | combining right |
| | | | | arrow above |
+-------+---------+---------------------+--------+---------------------+
| above | U+2192 | rightwards arrow | U+20EF | combining right |
| | | | | arrow below |
+-------+---------+---------------------+--------+---------------------+
| above | U+2212 | minus sign | U+0305 | combining overline |
+-------+---------+---------------------+--------+---------------------+
| below | U+2212 | minus sign | U+0332 | combining low line |
+-------+---------+---------------------+--------+---------------------+
| above | U+27F6 | long rightwards | U+20D7 | combining right |
| | | arrow | | arrow above |
+-------+---------+---------------------+--------+---------------------+
| above | U+27F6 | long rightwards | U+20EF | combining right |
| | | arrow | | arrow below |
+-------+---------+---------------------+--------+---------------------+

::: header-wrapper
### B.4 Unicode-based Glyph Assemblies

*This section is non-normative.*

The following table provides fallback that user agents may use for
stretching a given *base character* when the font does not provide a
`MATH.MathVariants` table. The algorithms of [5.3 Size variants for
operators
(`MathVariants`)](#size-variants-for-operators-mathvariants)
work the same except with some adjustments:

- Entries are indexed by the base character.
- All the glyph IDs and metrics have to be deduced from Unicode code
 points.
- If the *glyph construction* is horizontal then the entry corresponds
 to a `MathVariants.horizGlyphConstructionOffsets` item; if it is
 vertical it corresponds to a
 `MathVariants.vertGlyphConstructionOffsets` item.
- The `MathGlyphConstruction.mathGlyphVariantRecord` is always empty.
- The `MathVariants.minConnectorOverlap`,
 `GlyphPartRecord.startConnectorLength` and
 `GlyphPartRecord.endConnectorLength` are treated as 0.
- The array of `MathGlyphConstruction.GlyphAssembly.partRecords` is
 built from each table row as follows:
 1. A (non-extender) *bottom/left* character
 2. Followed by an *extender* character.
 3. Optionally followed by this:
 - Optionally, a (non-extender) *middle* character and the same
 extender character previously mentioned.
 - A (non-extender) *top/right* character.

 Base Character Glyph Construction Extender Character Bottom/Left Character Middle Character Top/Right Character
 ---------------- -------------------- -------------------- ----------------------- ------------------ ---------------------
 U+0028 ( Vertical U+239C ⎜ U+239D ⎝ N/A U+239B ⎛
 U+0029 ) Vertical U+239F ⎟ U+23A0 ⎠ N/A U+239E ⎞
 U+003D = Horizontal U+003D = U+003D = N/A N/A
 U+005B \[ Vertical U+23A2 ⎢ U+23A3 ⎣ N/A U+23A1 ⎡
 U+005D \] Vertical U+23A5 ⎥ U+23A6 ⎦ N/A U+23A4 ⎤
 U+005F \_ Horizontal U+005F \_ U+005F \_ N/A N/A
 U+007B { Vertical U+23AA ⎪ U+23A9 ⎩ U+23A8 ⎨ U+23A7 ⎧
 U+007C \| Vertical U+007C \| U+007C \| N/A N/A
 U+007D } Vertical U+23AA ⎪ U+23AD ⎭ U+23AC ⎬ U+23AB ⎫
 U+00AF ¯ Horizontal U+00AF ¯ U+00AF ¯ N/A N/A
 U+2016 ‖ Vertical U+2016 ‖ U+2016 ‖ N/A N/A
 U+203E ‾ Horizontal U+203E ‾ U+203E ‾ N/A N/A
 U+2190 ← Horizontal U+23AF ⎯ U+2190 ← N/A U+23AF ⎯
 U+2191 ↑ Vertical U+23D0 ⏐ U+23D0 ⏐ N/A U+2191 ↑
 U+2192 → Horizontal U+23AF ⎯ U+23AF ⎯ N/A U+2192 →
 U+2193 ↓ Vertical U+23D0 ⏐ U+2193 ↓ N/A U+23D0 ⏐
 U+2194 ↔ Horizontal U+23AF ⎯ U+2190 ← N/A U+2192 →
 U+2195 ↕ Vertical U+23D0 ⏐ U+2193 ↓ N/A U+2191 ↑
 U+21A4 ↤ Horizontal U+23AF ⎯ U+2190 ← N/A U+22A3 ⊣
 U+21A6 ↦ Horizontal U+23AF ⎯ U+22A2 ⊢ N/A U+2192 →
 U+21BC ↼ Horizontal U+23AF ⎯ U+21BC ↼ N/A U+23AF ⎯
 U+21BD ↽ Horizontal U+23AF ⎯ U+21BD ↽ N/A U+23AF ⎯
 U+21C0 ⇀ Horizontal U+23AF ⎯ U+23AF ⎯ N/A U+21C0 ⇀
 U+21C1 ⇁ Horizontal U+23AF ⎯ U+23AF ⎯ N/A U+21C1 ⇁
 U+2223 ∣ Vertical U+2223 ∣ U+2223 ∣ N/A N/A
 U+2225 ∥ Vertical U+2225 ∥ U+2225 ∥ N/A N/A
 U+2308 ⌈ Vertical U+23A2 ⎢ U+23A2 ⎢ N/A U+23A1 ⎡
 U+2309 ⌉ Vertical U+23A5 ⎥ U+23A5 ⎥ N/A U+23A4 ⎤
 U+230A ⌊ Vertical U+23A2 ⎢ U+23A3 ⎣ N/A N/A
 U+230B ⌋ Vertical U+23A5 ⎥ U+23A6 ⎦ N/A N/A
 U+23B0 ⎰ Vertical U+23AA ⎪ U+23AD ⎭ N/A U+23A7 ⎧
 U+23B1 ⎱ Vertical U+23AA ⎪ U+23A9 ⎩ N/A U+23AB ⎫
 U+27F5 ⟵ Horizontal U+23AF ⎯ U+2190 ← N/A U+23AF ⎯
 U+27F6 ⟶ Horizontal U+23AF ⎯ U+23AF ⎯ N/A U+2192 →
 U+27F7 ⟷ Horizontal U+23AF ⎯ U+2190 ← N/A U+2192 →
 U+294E ⥎ Horizontal U+23AF ⎯ U+21BC ↼ N/A U+21C0 ⇀
 U+2950 ⥐ Horizontal U+23AF ⎯ U+21BD ↽ N/A U+21C1 ⇁
 U+295A ⥚ Horizontal U+23AF ⎯ U+21BC ↼ N/A U+22A3 ⊣
 U+295B ⥛ Horizontal U+23AF ⎯ U+22A2 ⊢ N/A U+21C0 ⇀
 U+295E ⥞ Horizontal U+23AF ⎯ U+21BD ↽ N/A U+22A3 ⊣
 U+295F ⥟ Horizontal U+23AF ⎯ U+22A2 ⊢ N/A U+21C1 ⇁

::: header-wrapper
## C. Mathematical Alphanumeric Symbols

*This section is non-normative.*

As detailed in
\[[xml-entity-names](#bib-xml-entity-names "XML Entity Definitions for Characters (3rd Edition)")\] mathematical alphanumeric symbols with form bold,
italic, fraktur, monospace, double-struck etc are available in Unicode.

These alphanumeric symbols should be accessed using their Unicode code
points. It is sometimes needed to distinguish between Chancery and
Roundhand style for MATHEMATICAL SCRIPT characters. These are notably
used in LaTeX for the `\mathcal` and `\mathscr` commands. One way to do
that is to rely on Chapter 23.4 Variation Selectors of Unicode which
describes a way to specify selection of particular glyph variants
\[[UNICODE](#bib-unicode "The Unicode Standard")\]. Indeed, the `StandardizedVariants.txt` file from
the Unicode Character Database indicates that variant selectors U+FE00
and U+FE01 can be used on capital script to specify Chancery and
Roundhand respectively.

Alternatively, some mathematical fonts rely on `salt` or `ssXY`
properties from
\[[OPEN-FONT-FORMAT](#bib-open-font-format "Information technology — Coding of audio-visual objects — Part 22: Open Font Format")\] to provide both styles. Page authors may use the
[font-variant-alternates](https://www.w3.org/TR/css-fonts-4/#propdef-font-variant-alternates)
property with corresponding OpenType font features to access these
glyphs.

In addition, the `italic` math alphanumeric characters may be accessed
as described above using the CSS `text-transform: math-auto` transform
which is applied by default to single character `<mi>` elements. As a
convenience the mapping to math italic is shown below.

::: header-wrapper
### C.1 `italic` mappings

---------- ----------- ----------------
 Original italic Δ~code\ point~
 A U+0041 𝐴 U+1D434 1D3F3
 B U+0042 𝐵 U+1D435 1D3F3
 C U+0043 𝐶 U+1D436 1D3F3
 D U+0044 𝐷 U+1D437 1D3F3
 E U+0045 𝐸 U+1D438 1D3F3
 F U+0046 𝐹 U+1D439 1D3F3
 G U+0047 𝐺 U+1D43A 1D3F3
 H U+0048 𝐻 U+1D43B 1D3F3
 I U+0049 𝐼 U+1D43C 1D3F3
 J U+004A 𝐽 U+1D43D 1D3F3
 K U+004B 𝐾 U+1D43E 1D3F3
 L U+004C 𝐿 U+1D43F 1D3F3
 M U+004D 𝑀 U+1D440 1D3F3
 N U+004E 𝑁 U+1D441 1D3F3
 O U+004F 𝑂 U+1D442 1D3F3
 P U+0050 𝑃 U+1D443 1D3F3
 Q U+0051 𝑄 U+1D444 1D3F3
 R U+0052 𝑅 U+1D445 1D3F3
 S U+0053 𝑆 U+1D446 1D3F3
 T U+0054 𝑇 U+1D447 1D3F3
 U U+0055 𝑈 U+1D448 1D3F3
 V U+0056 𝑉 U+1D449 1D3F3
 W U+0057 𝑊 U+1D44A 1D3F3
 X U+0058 𝑋 U+1D44B 1D3F3
 Y U+0059 𝑌 U+1D44C 1D3F3
 Z U+005A 𝑍 U+1D44D 1D3F3
 a U+0061 𝑎 U+1D44E 1D3ED
 b U+0062 𝑏 U+1D44F 1D3ED
 c U+0063 𝑐 U+1D450 1D3ED
 d U+0064 𝑑 U+1D451 1D3ED
 e U+0065 𝑒 U+1D452 1D3ED
 f U+0066 𝑓 U+1D453 1D3ED
 g U+0067 𝑔 U+1D454 1D3ED
 h U+0068 ℎ U+0210E 20A6
 i U+0069 𝑖 U+1D456 1D3ED
 j U+006A 𝑗 U+1D457 1D3ED
 k U+006B 𝑘 U+1D458 1D3ED
 l U+006C 𝑙 U+1D459 1D3ED
 m U+006D 𝑚 U+1D45A 1D3ED
 n U+006E 𝑛 U+1D45B 1D3ED
 o U+006F 𝑜 U+1D45C 1D3ED
 p U+0070 𝑝 U+1D45D 1D3ED
 q U+0071 𝑞 U+1D45E 1D3ED
 r U+0072 𝑟 U+1D45F 1D3ED
 s U+0073 𝑠 U+1D460 1D3ED
 t U+0074 𝑡 U+1D461 1D3ED
 u U+0075 𝑢 U+1D462 1D3ED
 v U+0076 𝑣 U+1D463 1D3ED
 w U+0077 𝑤 U+1D464 1D3ED
 x U+0078 𝑥 U+1D465 1D3ED
 y U+0079 𝑦 U+1D466 1D3ED
 z U+007A 𝑧 U+1D467 1D3ED
 ı U+0131 𝚤 U+1D6A4 1D573
 ȷ U+0237 𝚥 U+1D6A5 1D46E
 Α U+0391 𝛢 U+1D6E2 1D351
 Β U+0392 𝛣 U+1D6E3 1D351
 Γ U+0393 𝛤 U+1D6E4 1D351
 Δ U+0394 𝛥 U+1D6E5 1D351
 Ε U+0395 𝛦 U+1D6E6 1D351
 Ζ U+0396 𝛧 U+1D6E7 1D351
 Η U+0397 𝛨 U+1D6E8 1D351
 Θ U+0398 𝛩 U+1D6E9 1D351
 Ι U+0399 𝛪 U+1D6EA 1D351
 Κ U+039A 𝛫 U+1D6EB 1D351
 Λ U+039B 𝛬 U+1D6EC 1D351
 Μ U+039C 𝛭 U+1D6ED 1D351
 Ν U+039D 𝛮 U+1D6EE 1D351
 Ξ U+039E 𝛯 U+1D6EF 1D351
 Ο U+039F 𝛰 U+1D6F0 1D351
 Π U+03A0 𝛱 U+1D6F1 1D351
 Ρ U+03A1 𝛲 U+1D6F2 1D351
 ϴ U+03F4 𝛳 U+1D6F3 1D2FF
 Σ U+03A3 𝛴 U+1D6F4 1D351
 Τ U+03A4 𝛵 U+1D6F5 1D351
 Υ U+03A5 𝛶 U+1D6F6 1D351
 Φ U+03A6 𝛷 U+1D6F7 1D351
 Χ U+03A7 𝛸 U+1D6F8 1D351
 Ψ U+03A8 𝛹 U+1D6F9 1D351
 Ω U+03A9 𝛺 U+1D6FA 1D351
 ∇ U+2207 𝛻 U+1D6FB 1B4F4
 α U+03B1 𝛼 U+1D6FC 1D34B
 β U+03B2 𝛽 U+1D6FD 1D34B
 γ U+03B3 𝛾 U+1D6FE 1D34B
 δ U+03B4 𝛿 U+1D6FF 1D34B
 ε U+03B5 𝜀 U+1D700 1D34B
 ζ U+03B6 𝜁 U+1D701 1D34B
 η U+03B7 𝜂 U+1D702 1D34B
 θ U+03B8 𝜃 U+1D703 1D34B
 ι U+03B9 𝜄 U+1D704 1D34B
 κ U+03BA 𝜅 U+1D705 1D34B
 λ U+03BB 𝜆 U+1D706 1D34B
 μ U+03BC 𝜇 U+1D707 1D34B
 ν U+03BD 𝜈 U+1D708 1D34B
 ξ U+03BE 𝜉 U+1D709 1D34B
 ο U+03BF 𝜊 U+1D70A 1D34B
 π U+03C0 𝜋 U+1D70B 1D34B
 ρ U+03C1 𝜌 U+1D70C 1D34B
 ς U+03C2 𝜍 U+1D70D 1D34B
 σ U+03C3 𝜎 U+1D70E 1D34B
 τ U+03C4 𝜏 U+1D70F 1D34B
 υ U+03C5 𝜐 U+1D710 1D34B
 φ U+03C6 𝜑 U+1D711 1D34B
 χ U+03C7 𝜒 U+1D712 1D34B
 ψ U+03C8 𝜓 U+1D713 1D34B
 ω U+03C9 𝜔 U+1D714 1D34B
 ∂ U+2202 𝜕 U+1D715 1B513
 ϵ U+03F5 𝜖 U+1D716 1D321
 ϑ U+03D1 𝜗 U+1D717 1D346
 ϰ U+03F0 𝜘 U+1D718 1D328
 ϕ U+03D5 𝜙 U+1D719 1D344
 ϱ U+03F1 𝜚 U+1D71A 1D329
 ϖ U+03D6 𝜛 U+1D71B 1D345
 ---------- ----------- ----------------

::: header-wrapper
## D. Acknowledgments

*This section is non-normative.*

MathML Core is based on MathML3. See the [appendix
E](https://www.w3.org/TR/MathML3/appendixe.html) of
\[[MathML3](#bib-mathml3 "Mathematical Markup Language (MathML) Version 3.0 2nd Edition")\] for the people that contributed to that
specification.

MathML Core was initially developed by the MathML Community Group, and
then by the Math Working Group. Working Group or Community Group members
who regularly participated in MathML Core meetings during the
development of this specification: Brian Kardell, Bruce Miller, Daniel
Marques, David Carlisle, David Farmer, Deyan Ginev, Frédéric Wang, Louis
Mahler, Moritz Schubotz, Murray Sargent, Neil Soiffer, Patrick Ion, Rob
Buis, Steve Noble and Sam Dooley.

In addition, we would like to extend special thanks to Brian Kardell,
Neil Soiffer and Rob Buis for help with the editing.

Many thanks also to the following people for their help with the test
suite: Brian Kardell, Frédéric Wang, Neil Soiffer and Rob Buis. Several
tests are also based on MathML tests from browser repositories and we
are grateful to the Mozilla and WebKit contributors.

We would like to thank the people who, through their input and feedback
on public communication channels, have helped us with the creation of
this specification: André Greiner-Petter, Anne van Kesteren, Boris
Zbarsky, Brian Smith, Elika Etemad, Emilio Cobos Álvarez, ExE Boss, Ian
Kilpatrick, Koji Ishii, L. David Baron, Michael Kohlhase, Michael Smith,
Ryosuke Niwa, Sergey Malkin, Tab Atkins Jr., Viktor Yaffle and frankvel.

::: header-wrapper
## E. Security Considerations

*This section is non-normative.*

This specification adds script execution mechanisms via the MathML event
handler attributes described in [2.1.3 Global
Attributes](#global-attributes). UAs may decide to prevent
execution of scripts specified in these attributes, following the same
security restrictions as those applying to HTML or SVG elements.

\[[MathML3](#bib-mathml3 "Mathematical Markup Language (MathML) Version 3.0 2nd Edition")\], it was possible to make any element linkable via
`href` or `xlink:href` attributes, with an URL pointing to an untrusted
resource or even `javascript:` execution. These attributes are not
available in MathML Core. However, as described in [2.2.1 HTML and
SVG](#html-and-svg) it is possible to embed HTML or SVG
content inside MathML, including HTML or SVG links.

\[[MathML3](#bib-mathml3 "Mathematical Markup Language (MathML) Version 3.0 2nd Edition")\], it was possible to use the
[`maction`](#dfn-maction) element with the `actiontype` value set to
`"statusline"` in order to override the text of the browser statusline.
In particular, an attacker could use this to hide the URL text of an
untrusted link e.g.

``` {aria-busy="false"}
<math>
 <maction actiontype="statusline">
 <mtext><a href="javascript:alert('JS execution')">Click me!</a></mtext>
 <mtext>./this-is-a-safe-link.html</mtext>
 </maction>
</math>
```

This feature is not available in MathML Core, where the
[`maction`](#dfn-maction) element essentially behaves like an
[`mrow`](#dfn-mrow) container with extra style.

An attacker can try to hang the UA by inserting very large stretchy
operators, effectively making the algorithm [shaping of the glyph
assembly](#dfn-shaping-of-the-glyph-assembly) deal with a huge amount of glyphs. UAs may
work around this issue by limiting
[r~min~](#dfn-rmin)
and `GlyphAssembly.partCount` to maximum values.

As described in [CSS Fonts
Module](https://www.w3.org/TR/css-fonts-4/#security), an attacker can
try to rely on malformed or malicious fonts to exploit potential
security faults in browser implementations. Because the [OpenType MATH
table](#opentype-math-table) is used extensively in this specification,
UAs should ensure their font sanitization mechanisms are able to deal
with that table.

Finally, in order to reduce attack surface, some UAs expose runtime
options to disable part of the web platform. Disabling MathML layout can
essentially be achieved by forcing elements in the DOM tree to be put in
the HTML namespace and disabling [4. CSS Extensions for Math
Layout](#css-extensions-for-math-layout).

::: header-wrapper
## F. Privacy Considerations

*This section is non-normative.*

As explained in [2.2.1 HTML and SVG](#html-and-svg), MathML
can be embedded into an SVG image via the
[`<foreignObject>`](https://www.w3.org/TR/SVG/embedded.html#ForeignObjectElement)
element which can thus be used in a
[`canvas`](https://html.spec.whatwg.org/multipage/canvas.html#canvas)
element. UA may decide to implement any measure to prevent potential
[information
leakage](https://html.spec.whatwg.org/#security-with-canvas-elements)
such as tainting the canvas and returning a
\"[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror)\"
when one tries to access the canvas\' content via JavaScript APIs.

In the following example, the canvas image is set to the image of some
MathML content with an HTML link to `https://example.org/`. It should
not be possible for an attacker to determine whether that link was
visited by reading pixels via
`context.`[`getImageData`](https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-getimagedata)`()`. For more about links in MathML, see [E.
Security Considerations](#security-considerations).

``` {aria-busy="false"}
let svg = `
 <svg xmlns="http://www.w3.org/2000/svg" width="100px" height="100px">
 <foreignObject width="100" height="100"
 requiredExtensions="http://www.w3.org/1998/Math/MathML">
 <math xmlns="http://www.w3.org/1998/Math/MathML">
 <msqrt style="font-size: 25px">
 <mtext>&#x25a0;</mtext>
 <mtext><a href="https://example.org/">&#x25a0;</a></mtext>
 </msqrt>
 </math>
 </foreignObject>
 </svg>`;
let image = new Image();
image.width = 100;
image.height = 100;
image.onload = () => {
 let canvas = document.createElement('canvas');
 canvas.width = 100;
 canvas.height = 100;
 canvas.style = "border: 1px solid black";
 document.body.appendChild(canvas);
 let context = canvas.getContext("2d");
 context.drawImage(image, 0, 0);
};
image.src = `data:image/svg+xml;base64,${window.btoa(svg)}`;
```

This specification describes layout of DOM
[elements](https://dom.spec.whatwg.org/#concept-element)
which may involve system fonts. Like for HTML/CSS layout, it is thus
possible to use JavaScript APIs (e.g.
`context.`[`getImageData`](https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-getimagedata)`()` on content embedded in a canvas context, or
even just
[`getBoundingClientRect`](https://www.w3.org/TR/cssom-view-1/#dom-element-getboundingclientrect)`()`) to measure box sizes and positions
and infer data from system fonts. By combining miscellaneous tests on
such fonts and comparing measurements against results of well-known
fonts, an attacker can try and determine the default fonts of the user.

The following HTML+CSS+JavaScript document relies on a Web font with
exotic metrics to try and determine whether `A Well Known System Font`
is available by default.

``` {aria-busy="false"}
<style>
 @font-face {
 font-family: MyWebFontWithVeryWideGlyphs;
 src: url("/fonts/my-web-fonts-with-very-wide-glyphs.woff");
 }
 #container {
 font-family: AWellKnownSystemFont, MyWebFontWithVeryWideGlyphs;
 }
</style>
<div id="container">SOMETEXT</div>
<div id="reference">SOMETEXT</div>
<script>
document.fonts.ready.then(() => {
 let containerWidth =
 document.getElementById("container").getBoundingClientRect().width;
 let referenceWidth =
 document.getElementById("reference").getBoundingClientRect().width;
 let isWellKnownSystemFontAvailable =
 Math.abs(containerWidth - referenceWidth) < 1;
});
</script>
```

The following HTML+CSS+JavaScript document tries to determine whether
the UI serif font provides Asian glyphs:

``` {aria-busy="false"}
<style>
 @font-face {
 font-family: MyWebFontWithVeryWideAsianGlyphs;
 src: url("/fonts/my-web-fonts-with-very-wide-asian-glyphs.woff");
 }
 #container {
 font-family: ui-serif, MyWebFontWithVeryWideAsianGlyphs
 }
 #reference {
 font-family: MyWebFontWithVeryWideAsianGlyphs;
 }
</style>
<div id="container">王</div>
<div id="reference">王</div>
<script>
document.fonts.ready.then(() => {
 let containerWidth =
 document.getElementById("container").getBoundingClientRect().width;
 let referenceWidth =
 document.getElementById("reference").getBoundingClientRect().width;
 let uiSerifFontDoesNotContainAsianGlyph =
 Math.abs(containerWidth - referenceWidth) < 1;
});
</script>
```

The following HTML+CSS document contains the same text rendered with
[text-decoration-thickness](https://www.w3.org/TR/css-text-decor-4/#propdef-text-decoration-thickness)
set to `from-font` and `1em` (here 100 pixels) respectively. By
comparing the heights of the two underlines, one can calculate a good
approximation of the `underlineThickness` value from the PostScript
Table
\[[OPEN-FONT-FORMAT](#bib-open-font-format "Information technology — Coding of audio-visual objects — Part 22: Open Font Format")\].

``` {aria-busy="false"}
<style>
 #test {
 font-size: 100px;
 }
 #container {
 text-decoration-line: underline;
 text-decoration-thickness: from-font;
 }
 #reference {
 text-decoration-line: underline;
 text-decoration-thickness: 1em;
 }
</style>
<div id="test">
 <div id="container">SOMETEXT</div>
 <div id="reference">SOMETEXT</div>
</div>
```

This specification relies on information from [5. OpenType `MATH`
table](#opentype-math-table) to render MathML content. One can
get good approximation of most layout parameters from `MathConstants`
and `MathGlyphInfo` using measurement techniques similar to what is
described above for HTML+CSS+JavaScript document. The use of the
`MathVariants` table for MathML rendering can also be observed by
putting stretchy operators of different sizes inside a `canvas` context.

Although none of these parameters taken individually are personal,
implementing this specification increases the set of exposed font
information that can be used by an attacker to implement fingerprinting
techniques. Typically, they could help determine available and preferred
math fonts for a user.

::: header-wrapper
## G. Conformance

Conformance requirements are expressed with a combination of descriptive
assertions and RFC 2119 terminology. The key words "*MUST*", "*MUST
NOT*", "*REQUIRED*", "*SHALL*", "*SHALL NOT*", "*SHOULD*", "*SHOULD
NOT*", "*RECOMMENDED*", "*MAY*", and "*OPTIONAL*" in the normative parts
of this document are to be interpreted as described in RFC 2119.
However, for readability, these words do not appear in all uppercase
letters in this specification.

All of the text of this specification is normative except sections
explicitly marked as non-normative, examples, and notes.
\[[RFC2119](#bib-rfc2119 "Key words for use in RFCs to Indicate Requirement Levels")\]

Examples in this specification are introduced with the words "for
example" or are set apart from the normative text with
`class="example"`, like this:

This is an example of an informative example.

Informative notes begin with the word "Note" and are set apart from the
normative text with `class="note"`, like this:

Note, this is an informative note.

Advisements are normative sections styled to evoke special attention and
are set apart from other normative text with
`<strong class="advisement">`, like this: **UAs *MUST* provide an
accessible alternative.**

[Permalink](#dfn-mathml-element)

**Referenced in:**

- [§ 2.2.3 DOM and
 JavaScript](#ref-for-dfn-mathml-element-1 "§ 2.2.3 DOM and JavaScript")
- [§ 3.1.1 Box Model](#ref-for-dfn-mathml-element-2 "§ 3.1.1 Box Model")
- [§ 4.1 The display: block math and display: inline math
 value](#ref-for-dfn-mathml-element-3 "§ 4.1 The display: block math and display: inline math value")
 [(2)](#ref-for-dfn-mathml-element-4 "Reference 2")

[Permalink](#dfn-mathml-core-elements)

**Referenced in:**

- [§ 2.2.2 CSS
 styling](#ref-for-dfn-mathml-core-elements-1 "§ 2.2.2 CSS styling")
- [§ 3.2.4.1 Embellished
 operators](#ref-for-dfn-mathml-core-elements-2 "§ 3.2.4.1 Embellished operators")
- [§ 3.2.5.1 Definition of space-like
 elements](#ref-for-dfn-mathml-core-elements-3 "§ 3.2.5.1 Definition of space-like elements")

[Permalink](#dfn-unknown-mathml-element)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-unknown-mathml-element-1 "§ 2.1 Elements and attributes")
- [§ 4.1 The display: block math and display: inline math
 value](#ref-for-dfn-unknown-mathml-element-2 "§ 4.1 The display: block math and display: inline math value")

[Permalink](#dfn-grouping-elements)

**Referenced in:**

- [§ 3.2.4.1 Embellished
 operators](#ref-for-dfn-grouping-elements-1 "§ 3.2.4.1 Embellished operators")
 [(2)](#ref-for-dfn-grouping-elements-2 "Reference 2")
 [(3)](#ref-for-dfn-grouping-elements-3 "Reference 3")
- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-grouping-elements-4 "§ 3.2.4.2 Dictionary-based attributes")
 [(2)](#ref-for-dfn-grouping-elements-5 "Reference 2")
- [§ 3.2.5.1 Definition of space-like
 elements](#ref-for-dfn-grouping-elements-6 "§ 3.2.5.1 Definition of space-like elements")
 [(2)](#ref-for-dfn-grouping-elements-7 "Reference 2")

[Permalink](#dfn-scripted-elements)

**Referenced in:**

- [§ 3.2.4.1 Embellished
 operators](#ref-for-dfn-scripted-elements-1 "§ 3.2.4.1 Embellished operators")
 [(2)](#ref-for-dfn-scripted-elements-2 "Reference 2")
- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-scripted-elements-3 "§ 3.2.4.2 Dictionary-based attributes")
- [§ 3.4.4 Displaystyle, scriptlevel and math-shift in
 scripts](#ref-for-dfn-scripted-elements-4 "§ 3.4.4 Displaystyle, scriptlevel and math-shift in scripts")
- [§ 4.4 The math-shift
 property](#ref-for-dfn-scripted-elements-5 "§ 4.4 The math-shift property")

[Permalink](#dfn-radical-elements)

**Referenced in:**

- [§ 3.3.3 Radicals \<msqrt\>,
 \<mroot\>](#ref-for-dfn-radical-elements-1 "§ 3.3.3 Radicals <msqrt>, <mroot>")

[Permalink](#dfn-mathml-attributes)

**Referenced in:**

- [§ 2.2.3 DOM and
 JavaScript](#ref-for-dfn-mathml-attributes-1 "§ 2.2.3 DOM and JavaScript")

[Permalink](#dfn-math)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-math-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-math-2 "Reference 2")
- [§ 2.1.1 The Top-Level \<math\>
 Element](#ref-for-dfn-math-3 "§ 2.1.1 The Top-Level <math> Element")
- [§ 2.1.4 Attributes common to HTML and MathML
 elements](#ref-for-dfn-math-4 "§ 2.1.4 Attributes common to HTML and MathML elements")
- [§ 2.2.5 Focus](#ref-for-dfn-math-5 "§ 2.2.5 Focus")
- [§ 3.1.3 Anonymous \<mrow\>
 boxes](#ref-for-dfn-math-6 "§ 3.1.3 Anonymous <mrow> boxes")
- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-math-7 "§ 3.3.1.2 Layout of <mrow>")
 [(2)](#ref-for-dfn-math-8 "Reference 2")
- [§ 4.3 The math-style
 property](#ref-for-dfn-math-9 "§ 4.3 The math-style property")

[Permalink](#dfn-display)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-display-1 "§ 2.1 Elements and attributes")
- [§ 2.1.1 The Top-Level \<math\>
 Element](#ref-for-dfn-display-2 "§ 2.1.1 The Top-Level <math> Element")
 [(2)](#ref-for-dfn-display-3 "Reference 2")
 [(3)](#ref-for-dfn-display-4 "Reference 3")
 [(4)](#ref-for-dfn-display-5 "Reference 4")
- [§ 3.1.1 Box Model](#ref-for-dfn-display-6 "§ 3.1.1 Box Model")
 [(2)](#ref-for-dfn-display-7 "Reference 2")
- [§ 3.2.1.1 Layout of
 \<mtext\>](#ref-for-dfn-display-8 "§ 3.2.1.1 Layout of <mtext>")
- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-display-9 "§ 3.2.4.3 Layout of operators")
- [§ 3.2.5 Space
 \<mspace\>](#ref-for-dfn-display-10 "§ 3.2.5 Space <mspace>")
- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-display-11 "§ 3.3.1.2 Layout of <mrow>")
- [§ 3.3.2 Fractions
 \<mfrac\>](#ref-for-dfn-display-12 "§ 3.3.2 Fractions <mfrac>")
- [§ 3.3.3 Radicals \<msqrt\>,
 \<mroot\>](#ref-for-dfn-display-13 "§ 3.3.3 Radicals <msqrt>, <mroot>")
- [§ 3.3.6.2 Layout of
 \<mpadded\>](#ref-for-dfn-display-14 "§ 3.3.6.2 Layout of <mpadded>")
- [§ 3.4.1 Subscripts and Superscripts \<msub\>, \<msup\>,
 \<msubsup\>](#ref-for-dfn-display-15 "§ 3.4.1 Subscripts and Superscripts <msub>, <msup>, <msubsup>")
- [§ 3.4.2 Underscripts and Overscripts \<munder\>, \<mover\>,
 \<munderover\>](#ref-for-dfn-display-16 "§ 3.4.2 Underscripts and Overscripts <munder>, <mover>, <munderover>")
- [§ 3.4.3 Prescripts and Tensor Indices
 \<mmultiscripts\>](#ref-for-dfn-display-17 "§ 3.4.3 Prescripts and Tensor Indices <mmultiscripts>")

[Permalink](#dfn-alttext)

**Referenced in:**

- [§ 2.1.1 The Top-Level \<math\>
 Element](#ref-for-dfn-alttext-1 "§ 2.1.1 The Top-Level <math> Element")
 [(2)](#ref-for-dfn-alttext-2 "Reference 2")

[Permalink](#dfn-unsigned-integer)

**Referenced in:**

- [§ 2.1.6 The displaystyle and scriptlevel
 attributes](#ref-for-dfn-unsigned-integer-1 "§ 2.1.6 The displaystyle and scriptlevel attributes")

[Permalink](#dfn-boolean)

**Referenced in:**

- [§ 2.1.6 The displaystyle and scriptlevel
 attributes](#ref-for-dfn-boolean-1 "§ 2.1.6 The displaystyle and scriptlevel attributes")
- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-boolean-2 "§ 3.2.4.2 Dictionary-based attributes")
- [§ 3.4.2 Underscripts and Overscripts \<munder\>, \<mover\>,
 \<munderover\>](#ref-for-dfn-boolean-3 "§ 3.4.2 Underscripts and Overscripts <munder>, <mover>, <munderover>")

[Permalink](#dfn-id)

**Referenced in:**

- [§ 2.1.3 Global
 Attributes](#ref-for-dfn-id-1 "§ 2.1.3 Global Attributes")
- [§ 2.1.4 Attributes common to HTML and MathML
 elements](#ref-for-dfn-id-2 "§ 2.1.4 Attributes common to HTML and MathML elements")

[Permalink](#dfn-class)

**Referenced in:**

- [§ 2.1.3 Global
 Attributes](#ref-for-dfn-class-1 "§ 2.1.3 Global Attributes")
- [§ 2.1.4 Attributes common to HTML and MathML
 elements](#ref-for-dfn-class-2 "§ 2.1.4 Attributes common to HTML and MathML elements")

[Permalink](#dfn-style)

**Referenced in:**

- [§ 2.1.3 Global
 Attributes](#ref-for-dfn-style-1 "§ 2.1.3 Global Attributes")
- [§ 2.1.4 Attributes common to HTML and MathML
 elements](#ref-for-dfn-style-2 "§ 2.1.4 Attributes common to HTML and MathML elements")
- [§ 2.2.2 CSS styling](#ref-for-dfn-style-3 "§ 2.2.2 CSS styling")

[Permalink](#dfn-data)

**Referenced in:**

- [§ 2.1.3 Global
 Attributes](#ref-for-dfn-data-1 "§ 2.1.3 Global Attributes")

[Permalink](#dfn-autofocus)

**Referenced in:**

- [§ 2.1.3 Global
 Attributes](#ref-for-dfn-autofocus-1 "§ 2.1.3 Global Attributes")
- [§ 2.1.4 Attributes common to HTML and MathML
 elements](#ref-for-dfn-autofocus-2 "§ 2.1.4 Attributes common to HTML and MathML elements")

[Permalink](#dfn-nonce)

**Referenced in:**

- [§ 2.1.3 Global
 Attributes](#ref-for-dfn-nonce-1 "§ 2.1.3 Global Attributes")
- [§ 2.1.4 Attributes common to HTML and MathML
 elements](#ref-for-dfn-nonce-2 "§ 2.1.4 Attributes common to HTML and MathML elements")

[Permalink](#dfn-tabindex)

**Referenced in:**

- [§ 2.1.3 Global
 Attributes](#ref-for-dfn-tabindex-1 "§ 2.1.3 Global Attributes")
- [§ 2.1.4 Attributes common to HTML and MathML
 elements](#ref-for-dfn-tabindex-2 "§ 2.1.4 Attributes common to HTML and MathML elements")

[Permalink](#dfn-dir)

**Referenced in:**

- [§ 2.1.3 Global
 Attributes](#ref-for-dfn-dir-1 "§ 2.1.3 Global Attributes")
- [§ 2.1.4 Attributes common to HTML and MathML
 elements](#ref-for-dfn-dir-2 "§ 2.1.4 Attributes common to HTML and MathML elements")
 [(2)](#ref-for-dfn-dir-3 "Reference 2")

[Permalink](#dfn-mathcolor)

**Referenced in:**

- [§ 2.1.3 Global
 Attributes](#ref-for-dfn-mathcolor-1 "§ 2.1.3 Global Attributes")

[Permalink](#dfn-mathbackground)

**Referenced in:**

- [§ 2.1.3 Global
 Attributes](#ref-for-dfn-mathbackground-1 "§ 2.1.3 Global Attributes")

[Permalink](#dfn-mathsize)

**Referenced in:**

- [§ 2.1.3 Global
 Attributes](#ref-for-dfn-mathsize-1 "§ 2.1.3 Global Attributes")

[Permalink](#dfn-displaystyle)

**Referenced in:**

- [§ 2.1.3 Global
 Attributes](#ref-for-dfn-displaystyle-1 "§ 2.1.3 Global Attributes")
- [§ 2.1.6 The displaystyle and scriptlevel
 attributes](#ref-for-dfn-displaystyle-2 "§ 2.1.6 The displaystyle and scriptlevel attributes")
 [(2)](#ref-for-dfn-displaystyle-3 "Reference 2")
 [(3)](#ref-for-dfn-displaystyle-4 "Reference 3")
- [§ 3.2.4 Operator, Fence, Separator or Accent
 \<mo\>](#ref-for-dfn-displaystyle-5 "§ 3.2.4 Operator, Fence, Separator or Accent <mo>")
 [(2)](#ref-for-dfn-displaystyle-6 "Reference 2")
- [§ 3.3.2 Fractions
 \<mfrac\>](#ref-for-dfn-displaystyle-7 "§ 3.3.2 Fractions <mfrac>")
 [(2)](#ref-for-dfn-displaystyle-8 "Reference 2")
 [(3)](#ref-for-dfn-displaystyle-9 "Reference 3")
- [§ 3.3.3 Radicals \<msqrt\>,
 \<mroot\>](#ref-for-dfn-displaystyle-10 "§ 3.3.3 Radicals <msqrt>, <mroot>")
 [(2)](#ref-for-dfn-displaystyle-11 "Reference 2")
- [§ 3.3.4 Style Change
 \<mstyle\>](#ref-for-dfn-displaystyle-12 "§ 3.3.4 Style Change <mstyle>")
- [§ 3.4.4 Displaystyle, scriptlevel and math-shift in
 scripts](#ref-for-dfn-displaystyle-13 "§ 3.4.4 Displaystyle, scriptlevel and math-shift in scripts")
 [(2)](#ref-for-dfn-displaystyle-14 "Reference 2")
- [§ 4.3 The math-style
 property](#ref-for-dfn-displaystyle-15 "§ 4.3 The math-style property")

[Permalink](#dfn-scriptlevel)

**Referenced in:**

- [§ 2.1.3 Global
 Attributes](#ref-for-dfn-scriptlevel-1 "§ 2.1.3 Global Attributes")
- [§ 2.1.6 The displaystyle and scriptlevel
 attributes](#ref-for-dfn-scriptlevel-2 "§ 2.1.6 The displaystyle and scriptlevel attributes")
 [(2)](#ref-for-dfn-scriptlevel-3 "Reference 2")
 [(3)](#ref-for-dfn-scriptlevel-4 "Reference 3")
- [§ 3.3.2 Fractions
 \<mfrac\>](#ref-for-dfn-scriptlevel-5 "§ 3.3.2 Fractions <mfrac>")
 [(2)](#ref-for-dfn-scriptlevel-6 "Reference 2")
- [§ 3.3.3 Radicals \<msqrt\>,
 \<mroot\>](#ref-for-dfn-scriptlevel-7 "§ 3.3.3 Radicals <msqrt>, <mroot>")
 [(2)](#ref-for-dfn-scriptlevel-8 "Reference 2")
- [§ 3.3.4 Style Change
 \<mstyle\>](#ref-for-dfn-scriptlevel-9 "§ 3.3.4 Style Change <mstyle>")
- [§ 3.4.4 Displaystyle, scriptlevel and math-shift in
 scripts](#ref-for-dfn-scriptlevel-10 "§ 3.4.4 Displaystyle, scriptlevel and math-shift in scripts")
 [(2)](#ref-for-dfn-scriptlevel-11 "Reference 2")
- [§ 4.5 The math-depth
 property](#ref-for-dfn-scriptlevel-12 "§ 4.5 The math-depth property")

[Permalink](#dfn-intent)

**Referenced in:**

- [§ 2.1.7 Attributes Reserved as
 Valid](#ref-for-dfn-intent-1 "§ 2.1.7 Attributes Reserved as Valid")

[Permalink](#dfn-arg)

**Referenced in:**

- [§ 2.1.7 Attributes Reserved as
 Valid](#ref-for-dfn-arg-1 "§ 2.1.7 Attributes Reserved as Valid")

[Permalink](#dom-mathmlelement)
[exported]
[IDL](#webidl-1298971770 "Jump to IDL declaration")

**Referenced in:**

- [§ 2.2.3 DOM and
 JavaScript](#ref-for-dom-mathmlelement-1 "§ 2.2.3 DOM and JavaScript")
 [(2)](#ref-for-dom-mathmlelement-2 "Reference 2")
 [(3)](#ref-for-dom-mathmlelement-3 "Reference 3")
- [§ 3.6 Linking
 \<a\>](#ref-for-dom-mathmlelement-4 "§ 3.6 Linking <a>")

[Permalink](#dfn-alphabetic-baseline)

**Referenced in:**

- [§ 3.1.1 Box
 Model](#ref-for-dfn-alphabetic-baseline-1 "§ 3.1.1 Box Model")
 [(2)](#ref-for-dfn-alphabetic-baseline-2 "Reference 2")
 [(3)](#ref-for-dfn-alphabetic-baseline-3 "Reference 3")
 [(4)](#ref-for-dfn-alphabetic-baseline-4 "Reference 4")
 [(5)](#ref-for-dfn-alphabetic-baseline-5 "Reference 5")
 [(6)](#ref-for-dfn-alphabetic-baseline-6 "Reference 6")
 [(7)](#ref-for-dfn-alphabetic-baseline-7 "Reference 7")
- [§ 3.2.1.1 Layout of
 \<mtext\>](#ref-for-dfn-alphabetic-baseline-8 "§ 3.2.1.1 Layout of <mtext>")
- [§ 3.3.1 Group Sub-Expressions
 \<mrow\>](#ref-for-dfn-alphabetic-baseline-9 "§ 3.3.1 Group Sub-Expressions <mrow>")
 [(2)](#ref-for-dfn-alphabetic-baseline-10 "Reference 2")
 [(3)](#ref-for-dfn-alphabetic-baseline-11 "Reference 3")
- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-alphabetic-baseline-12 "§ 3.3.1.2 Layout of <mrow>")
 [(2)](#ref-for-dfn-alphabetic-baseline-13 "Reference 2")
- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-alphabetic-baseline-14 "§ 3.3.2.1 Fraction with nonzero line thickness")
 [(2)](#ref-for-dfn-alphabetic-baseline-15 "Reference 2")
 [(3)](#ref-for-dfn-alphabetic-baseline-16 "Reference 3")
- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-alphabetic-baseline-17 "§ 3.3.2.2 Fraction with zero line thickness")
 [(2)](#ref-for-dfn-alphabetic-baseline-18 "Reference 2")
- [§ 3.3.3.2 Square
 root](#ref-for-dfn-alphabetic-baseline-19 "§ 3.3.3.2 Square root")
 [(2)](#ref-for-dfn-alphabetic-baseline-20 "Reference 2")
 [(3)](#ref-for-dfn-alphabetic-baseline-21 "Reference 3")
- [§ 3.3.3.3 Root with
 index](#ref-for-dfn-alphabetic-baseline-22 "§ 3.3.3.3 Root with index")
 [(2)](#ref-for-dfn-alphabetic-baseline-23 "Reference 2")
 [(3)](#ref-for-dfn-alphabetic-baseline-24 "Reference 3")
- [§ 3.3.6.2 Layout of
 \<mpadded\>](#ref-for-dfn-alphabetic-baseline-25 "§ 3.3.6.2 Layout of <mpadded>")
 [(2)](#ref-for-dfn-alphabetic-baseline-26 "Reference 2")
- [§ 3.3.7 Making Sub-Expressions Invisible
 \<mphantom\>](#ref-for-dfn-alphabetic-baseline-27 "§ 3.3.7 Making Sub-Expressions Invisible <mphantom>")
- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-alphabetic-baseline-28 "§ 3.4.1.2 Base with subscript")
 [(2)](#ref-for-dfn-alphabetic-baseline-29 "Reference 2")
 [(3)](#ref-for-dfn-alphabetic-baseline-30 "Reference 3")
 [(4)](#ref-for-dfn-alphabetic-baseline-31 "Reference 4")
- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-alphabetic-baseline-32 "§ 3.4.1.3 Base with superscript")
 [(2)](#ref-for-dfn-alphabetic-baseline-33 "Reference 2")
 [(3)](#ref-for-dfn-alphabetic-baseline-34 "Reference 3")
 [(4)](#ref-for-dfn-alphabetic-baseline-35 "Reference 4")
- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-alphabetic-baseline-36 "§ 3.4.2.3 Base with underscript")
 [(2)](#ref-for-dfn-alphabetic-baseline-37 "Reference 2")
 [(3)](#ref-for-dfn-alphabetic-baseline-38 "Reference 3")
 [(4)](#ref-for-dfn-alphabetic-baseline-39 "Reference 4")
- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-alphabetic-baseline-40 "§ 3.4.2.4 Base with overscript")
 [(2)](#ref-for-dfn-alphabetic-baseline-41 "Reference 2")
 [(3)](#ref-for-dfn-alphabetic-baseline-42 "Reference 3")
 [(4)](#ref-for-dfn-alphabetic-baseline-43 "Reference 4")
 [(5)](#ref-for-dfn-alphabetic-baseline-44 "Reference 5")
 [(6)](#ref-for-dfn-alphabetic-baseline-45 "Reference 6")
 [(7)](#ref-for-dfn-alphabetic-baseline-46 "Reference 7")
- [§ 3.4.2.5 Base with underscript and
 overscript](#ref-for-dfn-alphabetic-baseline-47 "§ 3.4.2.5 Base with underscript and overscript")
- [§ 3.4.3.1 Base with prescripts and
 postscripts](#ref-for-dfn-alphabetic-baseline-48 "§ 3.4.3.1 Base with prescripts and postscripts")
 [(2)](#ref-for-dfn-alphabetic-baseline-49 "Reference 2")
 [(3)](#ref-for-dfn-alphabetic-baseline-50 "Reference 3")
 [(4)](#ref-for-dfn-alphabetic-baseline-51 "Reference 4")
 [(5)](#ref-for-dfn-alphabetic-baseline-52 "Reference 5")
 [(6)](#ref-for-dfn-alphabetic-baseline-53 "Reference 6")

[Permalink](#dfn-line-ascent)

**Referenced in:**

- [§ 3.1.1 Box Model](#ref-for-dfn-line-ascent-1 "§ 3.1.1 Box Model")
- [§ 3.1.2 Layout
 Algorithms](#ref-for-dfn-line-ascent-2 "§ 3.1.2 Layout Algorithms")
 [(2)](#ref-for-dfn-line-ascent-3 "Reference 2")
 [(3)](#ref-for-dfn-line-ascent-4 "Reference 3")
- [§ 3.2.1.1 Layout of
 \<mtext\>](#ref-for-dfn-line-ascent-5 "§ 3.2.1.1 Layout of <mtext>")
- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-line-ascent-6 "§ 3.2.4.3 Layout of operators")
 [(2)](#ref-for-dfn-line-ascent-7 "Reference 2")
- [§ 3.2.5 Space
 \<mspace\>](#ref-for-dfn-line-ascent-8 "§ 3.2.5 Space <mspace>")
- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-line-ascent-9 "§ 3.3.1.2 Layout of <mrow>")
 [(2)](#ref-for-dfn-line-ascent-10 "Reference 2")
- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-line-ascent-11 "§ 3.3.2.1 Fraction with nonzero line thickness")
 [(2)](#ref-for-dfn-line-ascent-12 "Reference 2")
 [(3)](#ref-for-dfn-line-ascent-13 "Reference 3")
- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-line-ascent-14 "§ 3.3.2.2 Fraction with zero line thickness")
 [(2)](#ref-for-dfn-line-ascent-15 "Reference 2")
 [(3)](#ref-for-dfn-line-ascent-16 "Reference 3")
- [§ 3.3.3.2 Square
 root](#ref-for-dfn-line-ascent-17 "§ 3.3.3.2 Square root")
 [(2)](#ref-for-dfn-line-ascent-18 "Reference 2")
 [(3)](#ref-for-dfn-line-ascent-19 "Reference 3")
 [(4)](#ref-for-dfn-line-ascent-20 "Reference 4")
 [(5)](#ref-for-dfn-line-ascent-21 "Reference 5")
- [§ 3.3.3.3 Root with
 index](#ref-for-dfn-line-ascent-22 "§ 3.3.3.3 Root with index")
 [(2)](#ref-for-dfn-line-ascent-23 "Reference 2")
 [(3)](#ref-for-dfn-line-ascent-24 "Reference 3")
 [(4)](#ref-for-dfn-line-ascent-25 "Reference 4")
- [§ 3.3.6.1 Inner box and requested
 parameters](#ref-for-dfn-line-ascent-26 "§ 3.3.6.1 Inner box and requested parameters")
 [(2)](#ref-for-dfn-line-ascent-27 "Reference 2")
 [(3)](#ref-for-dfn-line-ascent-28 "Reference 3")
- [§ 3.3.6.2 Layout of
 \<mpadded\>](#ref-for-dfn-line-ascent-29 "§ 3.3.6.2 Layout of <mpadded>")
- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-line-ascent-30 "§ 3.4.1.2 Base with subscript")
 [(2)](#ref-for-dfn-line-ascent-31 "Reference 2")
 [(3)](#ref-for-dfn-line-ascent-32 "Reference 3")
- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-line-ascent-33 "§ 3.4.1.3 Base with superscript")
 [(2)](#ref-for-dfn-line-ascent-34 "Reference 2")
 [(3)](#ref-for-dfn-line-ascent-35 "Reference 3")
- [§ 3.4.1.4 Base with subscript and
 superscript](#ref-for-dfn-line-ascent-36 "§ 3.4.1.4 Base with subscript and superscript")
 [(2)](#ref-for-dfn-line-ascent-37 "Reference 2")
- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-line-ascent-38 "§ 3.4.2.3 Base with underscript")
 [(2)](#ref-for-dfn-line-ascent-39 "Reference 2")
 [(3)](#ref-for-dfn-line-ascent-40 "Reference 3")
- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-line-ascent-41 "§ 3.4.2.4 Base with overscript")
 [(2)](#ref-for-dfn-line-ascent-42 "Reference 2")
 [(3)](#ref-for-dfn-line-ascent-43 "Reference 3")
 [(4)](#ref-for-dfn-line-ascent-44 "Reference 4")
 [(5)](#ref-for-dfn-line-ascent-45 "Reference 5")
- [§ 3.4.2.5 Base with underscript and
 overscript](#ref-for-dfn-line-ascent-46 "§ 3.4.2.5 Base with underscript and overscript")
- [§ 3.4.3.1 Base with prescripts and
 postscripts](#ref-for-dfn-line-ascent-47 "§ 3.4.3.1 Base with prescripts and postscripts")
 [(2)](#ref-for-dfn-line-ascent-48 "Reference 2")

[Permalink](#dfn-line-descent)

**Referenced in:**

- [§ 3.1.1 Box Model](#ref-for-dfn-line-descent-1 "§ 3.1.1 Box Model")
- [§ 3.1.2 Layout
 Algorithms](#ref-for-dfn-line-descent-2 "§ 3.1.2 Layout Algorithms")
- [§ 3.2.1.1 Layout of
 \<mtext\>](#ref-for-dfn-line-descent-3 "§ 3.2.1.1 Layout of <mtext>")
- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-line-descent-4 "§ 3.2.4.3 Layout of operators")
 [(2)](#ref-for-dfn-line-descent-5 "Reference 2")
- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-line-descent-6 "§ 3.3.1.2 Layout of <mrow>")
- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-line-descent-7 "§ 3.3.2.1 Fraction with nonzero line thickness")
 [(2)](#ref-for-dfn-line-descent-8 "Reference 2")
 [(3)](#ref-for-dfn-line-descent-9 "Reference 3")
- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-line-descent-10 "§ 3.3.2.2 Fraction with zero line thickness")
 [(2)](#ref-for-dfn-line-descent-11 "Reference 2")
 [(3)](#ref-for-dfn-line-descent-12 "Reference 3")
- [§ 3.3.3.2 Square
 root](#ref-for-dfn-line-descent-13 "§ 3.3.3.2 Square root")
 [(2)](#ref-for-dfn-line-descent-14 "Reference 2")
 [(3)](#ref-for-dfn-line-descent-15 "Reference 3")
- [§ 3.3.3.3 Root with
 index](#ref-for-dfn-line-descent-16 "§ 3.3.3.3 Root with index")
 [(2)](#ref-for-dfn-line-descent-17 "Reference 2")
 [(3)](#ref-for-dfn-line-descent-18 "Reference 3")
 [(4)](#ref-for-dfn-line-descent-19 "Reference 4")
 [(5)](#ref-for-dfn-line-descent-20 "Reference 5")
- [§ 3.3.6.2 Layout of
 \<mpadded\>](#ref-for-dfn-line-descent-21 "§ 3.3.6.2 Layout of <mpadded>")
- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-line-descent-22 "§ 3.4.1.2 Base with subscript")
 [(2)](#ref-for-dfn-line-descent-23 "Reference 2")
 [(3)](#ref-for-dfn-line-descent-24 "Reference 3")
- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-line-descent-25 "§ 3.4.1.3 Base with superscript")
 [(2)](#ref-for-dfn-line-descent-26 "Reference 2")
 [(3)](#ref-for-dfn-line-descent-27 "Reference 3")
- [§ 3.4.1.4 Base with subscript and
 superscript](#ref-for-dfn-line-descent-28 "§ 3.4.1.4 Base with subscript and superscript")
 [(2)](#ref-for-dfn-line-descent-29 "Reference 2")
- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-line-descent-30 "§ 3.4.2.3 Base with underscript")
 [(2)](#ref-for-dfn-line-descent-31 "Reference 2")
 [(3)](#ref-for-dfn-line-descent-32 "Reference 3")
- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-line-descent-33 "§ 3.4.2.4 Base with overscript")
 [(2)](#ref-for-dfn-line-descent-34 "Reference 2")
 [(3)](#ref-for-dfn-line-descent-35 "Reference 3")
- [§ 3.4.2.5 Base with underscript and
 overscript](#ref-for-dfn-line-descent-36 "§ 3.4.2.5 Base with underscript and overscript")
- [§ 3.4.3.1 Base with prescripts and
 postscripts](#ref-for-dfn-line-descent-37 "§ 3.4.3.1 Base with prescripts and postscripts")
 [(2)](#ref-for-dfn-line-descent-38 "Reference 2")

[Permalink](#dfn-mathematical-baseline)

**Referenced in:**

- [§ 3.3.1 Group Sub-Expressions
 \<mrow\>](#ref-for-dfn-mathematical-baseline-1 "§ 3.3.1 Group Sub-Expressions <mrow>")

[Permalink](#dfn-math-axis)

**Referenced in:**

- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-math-axis-1 "§ 3.2.4.3 Layout of operators")
 [(2)](#ref-for-dfn-math-axis-2 "Reference 2")
- [§ 3.3.1 Group Sub-Expressions
 \<mrow\>](#ref-for-dfn-math-axis-3 "§ 3.3.1 Group Sub-Expressions <mrow>")
- [§ 3.5.1 Table or Matrix
 \<mtable\>](#ref-for-dfn-math-axis-4 "§ 3.5.1 Table or Matrix <mtable>")

[Permalink](#dfn-ink-over-baseline)

**Referenced in:**

- [§ 3.1.1 Box
 Model](#ref-for-dfn-ink-over-baseline-1 "§ 3.1.1 Box Model")
- [§ 3.1.2 Layout
 Algorithms](#ref-for-dfn-ink-over-baseline-2 "§ 3.1.2 Layout Algorithms")
- [§ 3.2.1.1 Layout of
 \<mtext\>](#ref-for-dfn-ink-over-baseline-3 "§ 3.2.1.1 Layout of <mtext>")

[Permalink](#dfn-ink-line-ascent)

**Referenced in:**

- [§ 3.1.2 Layout
 Algorithms](#ref-for-dfn-ink-line-ascent-1 "§ 3.1.2 Layout Algorithms")
 [(2)](#ref-for-dfn-ink-line-ascent-2 "Reference 2")
- [§ 3.2.1.1 Layout of
 \<mtext\>](#ref-for-dfn-ink-line-ascent-3 "§ 3.2.1.1 Layout of <mtext>")
 [(2)](#ref-for-dfn-ink-line-ascent-4 "Reference 2")
- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-ink-line-ascent-5 "§ 3.2.4.3 Layout of operators")
 [(2)](#ref-for-dfn-ink-line-ascent-6 "Reference 2")
- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-ink-line-ascent-7 "§ 3.3.1.2 Layout of <mrow>")
 [(2)](#ref-for-dfn-ink-line-ascent-8 "Reference 2")
 [(3)](#ref-for-dfn-ink-line-ascent-9 "Reference 3")
- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-ink-line-ascent-10 "§ 3.3.2.1 Fraction with nonzero line thickness")
- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-ink-line-ascent-11 "§ 3.3.2.2 Fraction with zero line thickness")
- [§ 3.3.3.2 Square
 root](#ref-for-dfn-ink-line-ascent-12 "§ 3.3.3.2 Square root")
- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-ink-line-ascent-13 "§ 3.4.1.2 Base with subscript")
- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-ink-line-ascent-14 "§ 3.4.1.3 Base with superscript")
- [§ 3.4.1.4 Base with subscript and
 superscript](#ref-for-dfn-ink-line-ascent-15 "§ 3.4.1.4 Base with subscript and superscript")
 [(2)](#ref-for-dfn-ink-line-ascent-16 "Reference 2")
 [(3)](#ref-for-dfn-ink-line-ascent-17 "Reference 3")
- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-ink-line-ascent-18 "§ 3.4.2.4 Base with overscript")

[Permalink](#dfn-ink-under-baseline)

**Referenced in:**

- [§ 3.1.1 Box
 Model](#ref-for-dfn-ink-under-baseline-1 "§ 3.1.1 Box Model")
- [§ 3.1.2 Layout
 Algorithms](#ref-for-dfn-ink-under-baseline-2 "§ 3.1.2 Layout Algorithms")
- [§ 3.2.1.1 Layout of
 \<mtext\>](#ref-for-dfn-ink-under-baseline-3 "§ 3.2.1.1 Layout of <mtext>")

[Permalink](#dfn-ink-line-descent)

**Referenced in:**

- [§ 3.1.2 Layout
 Algorithms](#ref-for-dfn-ink-line-descent-1 "§ 3.1.2 Layout Algorithms")
 [(2)](#ref-for-dfn-ink-line-descent-2 "Reference 2")
- [§ 3.2.1.1 Layout of
 \<mtext\>](#ref-for-dfn-ink-line-descent-3 "§ 3.2.1.1 Layout of <mtext>")
 [(2)](#ref-for-dfn-ink-line-descent-4 "Reference 2")
- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-ink-line-descent-5 "§ 3.2.4.3 Layout of operators")
 [(2)](#ref-for-dfn-ink-line-descent-6 "Reference 2")
- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-ink-line-descent-7 "§ 3.3.1.2 Layout of <mrow>")
 [(2)](#ref-for-dfn-ink-line-descent-8 "Reference 2")
- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-ink-line-descent-9 "§ 3.3.2.1 Fraction with nonzero line thickness")
- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-ink-line-descent-10 "§ 3.3.2.2 Fraction with zero line thickness")
- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-ink-line-descent-11 "§ 3.4.1.2 Base with subscript")
- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-ink-line-descent-12 "§ 3.4.1.3 Base with superscript")
- [§ 3.4.1.4 Base with subscript and
 superscript](#ref-for-dfn-ink-line-descent-13 "§ 3.4.1.4 Base with subscript and superscript")
 [(2)](#ref-for-dfn-ink-line-descent-14 "Reference 2")
 [(3)](#ref-for-dfn-ink-line-descent-15 "Reference 3")
 [(4)](#ref-for-dfn-ink-line-descent-16 "Reference 4")
- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-ink-line-descent-17 "§ 3.4.2.3 Base with underscript")

[Permalink](#dfn-italic-correction)

**Referenced in:**

- [§ 3.1.2 Layout
 Algorithms](#ref-for-dfn-italic-correction-1 "§ 3.1.2 Layout Algorithms")
 [(2)](#ref-for-dfn-italic-correction-2 "Reference 2")
 [(3)](#ref-for-dfn-italic-correction-3 "Reference 3")
 [(4)](#ref-for-dfn-italic-correction-4 "Reference 4")
- [§ 3.2.1.1 Layout of
 \<mtext\>](#ref-for-dfn-italic-correction-5 "§ 3.2.1.1 Layout of <mtext>")
- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-italic-correction-6 "§ 3.2.4.3 Layout of operators")
- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-italic-correction-7 "§ 3.3.1.2 Layout of <mrow>")
 [(2)](#ref-for-dfn-italic-correction-8 "Reference 2")
 [(3)](#ref-for-dfn-italic-correction-9 "Reference 3")
 [(4)](#ref-for-dfn-italic-correction-10 "Reference 4")
 [(5)](#ref-for-dfn-italic-correction-11 "Reference 5")
- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-italic-correction-12 "§ 3.4.1.2 Base with subscript")
- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-italic-correction-13 "§ 3.4.1.3 Base with superscript")
- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-italic-correction-14 "§ 3.4.2.3 Base with underscript")
- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-italic-correction-15 "§ 3.4.2.4 Base with overscript")

[Permalink](#dfn-top-accent-attachment)

**Referenced in:**

- [§ 3.1.2 Layout
 Algorithms](#ref-for-dfn-top-accent-attachment-1 "§ 3.1.2 Layout Algorithms")
 [(2)](#ref-for-dfn-top-accent-attachment-2 "Reference 2")
 [(3)](#ref-for-dfn-top-accent-attachment-3 "Reference 3")
 [(4)](#ref-for-dfn-top-accent-attachment-4 "Reference 4")
- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-top-accent-attachment-5 "§ 3.4.2.4 Base with overscript")

[Permalink](#dfn-inline-offset)

**Referenced in:**

- [§ 3.1.1 Box Model](#ref-for-dfn-inline-offset-1 "§ 3.1.1 Box Model")
 [(2)](#ref-for-dfn-inline-offset-2 "Reference 2")
- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-inline-offset-3 "§ 3.3.1.2 Layout of <mrow>")
- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-inline-offset-4 "§ 3.3.2.1 Fraction with nonzero line thickness")
- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-inline-offset-5 "§ 3.3.2.2 Fraction with zero line thickness")
- [§ 3.3.3.2 Square
 root](#ref-for-dfn-inline-offset-6 "§ 3.3.3.2 Square root")
 [(2)](#ref-for-dfn-inline-offset-7 "Reference 2")
- [§ 3.3.3.3 Root with
 index](#ref-for-dfn-inline-offset-8 "§ 3.3.3.3 Root with index")
- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-inline-offset-9 "§ 3.4.1.2 Base with subscript")
 [(2)](#ref-for-dfn-inline-offset-10 "Reference 2")
- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-inline-offset-11 "§ 3.4.1.3 Base with superscript")
 [(2)](#ref-for-dfn-inline-offset-12 "Reference 2")
- [§ 3.4.1.4 Base with subscript and
 superscript](#ref-for-dfn-inline-offset-13 "§ 3.4.1.4 Base with subscript and superscript")
- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-inline-offset-14 "§ 3.4.2.3 Base with underscript")
 [(2)](#ref-for-dfn-inline-offset-15 "Reference 2")
- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-inline-offset-16 "§ 3.4.2.4 Base with overscript")
 [(2)](#ref-for-dfn-inline-offset-17 "Reference 2")
- [§ 3.4.2.5 Base with underscript and
 overscript](#ref-for-dfn-inline-offset-18 "§ 3.4.2.5 Base with underscript and overscript")
 [(2)](#ref-for-dfn-inline-offset-19 "Reference 2")
 [(3)](#ref-for-dfn-inline-offset-20 "Reference 3")
- [§ 3.4.3.1 Base with prescripts and
 postscripts](#ref-for-dfn-inline-offset-21 "§ 3.4.3.1 Base with prescripts and postscripts")

[Permalink](#dfn-block-offset)

**Referenced in:**

- [§ 3.1.1 Box Model](#ref-for-dfn-block-offset-1 "§ 3.1.1 Box Model")
 [(2)](#ref-for-dfn-block-offset-2 "Reference 2")
- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-block-offset-3 "§ 3.3.1.2 Layout of <mrow>")
- [§ 3.3.3.2 Square
 root](#ref-for-dfn-block-offset-4 "§ 3.3.3.2 Square root")
- [§ 3.4.1.4 Base with subscript and
 superscript](#ref-for-dfn-block-offset-5 "§ 3.4.1.4 Base with subscript and superscript")

[Permalink](#dfn-line-left-offset)

**Referenced in:**

- [§ 3.1.1 Box
 Model](#ref-for-dfn-line-left-offset-1 "§ 3.1.1 Box Model")
 [(2)](#ref-for-dfn-line-left-offset-2 "Reference 2")

[Permalink](#dfn-math-content-box)

**Referenced in:**

- [§ 2.1.1 The Top-Level \<math\>
 Element](#ref-for-dfn-math-content-box-1 "§ 2.1.1 The Top-Level <math> Element")
 [(2)](#ref-for-dfn-math-content-box-2 "Reference 2")
 [(3)](#ref-for-dfn-math-content-box-3 "Reference 3")
- [§ 3.1.2 Layout
 Algorithms](#ref-for-dfn-math-content-box-4 "§ 3.1.2 Layout Algorithms")
 [(2)](#ref-for-dfn-math-content-box-5 "Reference 2")
 [(3)](#ref-for-dfn-math-content-box-6 "Reference 3")
 [(4)](#ref-for-dfn-math-content-box-7 "Reference 4")
- [§ 3.2.1.1 Layout of
 \<mtext\>](#ref-for-dfn-math-content-box-8 "§ 3.2.1.1 Layout of <mtext>")
 [(2)](#ref-for-dfn-math-content-box-9 "Reference 2")
 [(3)](#ref-for-dfn-math-content-box-10 "Reference 3")
 [(4)](#ref-for-dfn-math-content-box-11 "Reference 4")
- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-math-content-box-12 "§ 3.3.2.1 Fraction with nonzero line thickness")
 [(2)](#ref-for-dfn-math-content-box-13 "Reference 2")
- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-math-content-box-14 "§ 3.3.2.2 Fraction with zero line thickness")
- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-math-content-box-15 "§ 3.4.2.3 Base with underscript")
- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-math-content-box-16 "§ 3.4.2.4 Base with overscript")
- [§ 3.4.2.5 Base with underscript and
 overscript](#ref-for-dfn-math-content-box-17 "§ 3.4.2.5 Base with underscript and overscript")

[Permalink](#dfn-inline-stretch-size-constraint)

**Referenced in:**

- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-inline-stretch-size-constraint-1 "§ 3.2.4.3 Layout of operators")
- [§ 3.3.1.1 Algorithm for stretching operators along the block
 axis](#ref-for-dfn-inline-stretch-size-constraint-2 "§ 3.3.1.1 Algorithm for stretching operators along the block axis")
- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-inline-stretch-size-constraint-3 "§ 3.3.2.1 Fraction with nonzero line thickness")
- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-inline-stretch-size-constraint-4 "§ 3.3.2.2 Fraction with zero line thickness")
- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-inline-stretch-size-constraint-5 "§ 3.4.1.2 Base with subscript")
- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-inline-stretch-size-constraint-6 "§ 3.4.1.3 Base with superscript")
- [§ 3.4.1.4 Base with subscript and
 superscript](#ref-for-dfn-inline-stretch-size-constraint-7 "§ 3.4.1.4 Base with subscript and superscript")
 [(2)](#ref-for-dfn-inline-stretch-size-constraint-8 "Reference 2")
- [§ 3.4.2.2 Algorithm for stretching operators along the inline
 axis](#ref-for-dfn-inline-stretch-size-constraint-9 "§ 3.4.2.2 Algorithm for stretching operators along the inline axis")
 [(2)](#ref-for-dfn-inline-stretch-size-constraint-10 "Reference 2")
 [(3)](#ref-for-dfn-inline-stretch-size-constraint-11 "Reference 3")
- [§ 3.4.3.1 Base with prescripts and
 postscripts](#ref-for-dfn-inline-stretch-size-constraint-12 "§ 3.4.3.1 Base with prescripts and postscripts")

[Permalink](#dfn-block-stretch-size-constraint)

**Referenced in:**

- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-block-stretch-size-constraint-1 "§ 3.2.4.3 Layout of operators")
- [§ 3.3.1.1 Algorithm for stretching operators along the block
 axis](#ref-for-dfn-block-stretch-size-constraint-2 "§ 3.3.1.1 Algorithm for stretching operators along the block axis")
 [(2)](#ref-for-dfn-block-stretch-size-constraint-3 "Reference 2")
 [(3)](#ref-for-dfn-block-stretch-size-constraint-4 "Reference 3")
- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-block-stretch-size-constraint-5 "§ 3.3.2.1 Fraction with nonzero line thickness")
- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-block-stretch-size-constraint-6 "§ 3.3.2.2 Fraction with zero line thickness")
- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-block-stretch-size-constraint-7 "§ 3.4.1.2 Base with subscript")
- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-block-stretch-size-constraint-8 "§ 3.4.1.3 Base with superscript")
- [§ 3.4.1.4 Base with subscript and
 superscript](#ref-for-dfn-block-stretch-size-constraint-9 "§ 3.4.1.4 Base with subscript and superscript")
 [(2)](#ref-for-dfn-block-stretch-size-constraint-10 "Reference 2")
- [§ 3.4.2.2 Algorithm for stretching operators along the inline
 axis](#ref-for-dfn-block-stretch-size-constraint-11 "§ 3.4.2.2 Algorithm for stretching operators along the inline axis")
- [§ 3.4.3.1 Base with prescripts and
 postscripts](#ref-for-dfn-block-stretch-size-constraint-12 "§ 3.4.3.1 Base with prescripts and postscripts")

[Permalink](#dfn-anonymous-box)

**Referenced in:**

- [§ 3.1.3 Anonymous \<mrow\>
 boxes](#ref-for-dfn-anonymous-box-1 "§ 3.1.3 Anonymous <mrow> boxes")

[Permalink](#dfn-anonymous-mrow-box)

**Referenced in:**

- [§ 3.1.3 Anonymous \<mrow\>
 boxes](#ref-for-dfn-anonymous-mrow-box-1 "§ 3.1.3 Anonymous <mrow> boxes")
- [§ 3.2.4.1 Embellished
 operators](#ref-for-dfn-anonymous-mrow-box-2 "§ 3.2.4.1 Embellished operators")
- [§ 3.2.5.1 Definition of space-like
 elements](#ref-for-dfn-anonymous-mrow-box-3 "§ 3.2.5.1 Definition of space-like elements")
- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-anonymous-mrow-box-4 "§ 3.3.1.2 Layout of <mrow>")

[Permalink](#dfn-generates-an-anonymous-mrow-box)

**Referenced in:**

- [§ 3.1.3 Anonymous \<mrow\>
 boxes](#ref-for-dfn-generates-an-anonymous-mrow-box-1 "§ 3.1.3 Anonymous <mrow> boxes")
- [§ 3.3.3 Radicals \<msqrt\>,
 \<mroot\>](#ref-for-dfn-generates-an-anonymous-mrow-box-2 "§ 3.3.3 Radicals <msqrt>, <mroot>")
- [§ 3.3.6.1 Inner box and requested
 parameters](#ref-for-dfn-generates-an-anonymous-mrow-box-3 "§ 3.3.6.1 Inner box and requested parameters")
- [§ 3.5.3 Entry in Table or Matrix
 \<mtd\>](#ref-for-dfn-generates-an-anonymous-mrow-box-4 "§ 3.5.3 Entry in Table or Matrix <mtd>")

[Permalink](#dfn-mtext)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mtext-1 "§ 2.1 Elements and attributes")
- [§ 2.2.1 HTML and SVG](#ref-for-dfn-mtext-2 "§ 2.2.1 HTML and SVG")
- [§ 3.2.1 Text \<mtext\>](#ref-for-dfn-mtext-3 "§ 3.2.1 Text <mtext>")
- [§ 3.2.2 Identifier
 \<mi\>](#ref-for-dfn-mtext-4 "§ 3.2.2 Identifier <mi>")
- [§ 3.2.3 Number \<mn\>](#ref-for-dfn-mtext-5 "§ 3.2.3 Number <mn>")
- [§ 3.2.5.1 Definition of space-like
 elements](#ref-for-dfn-mtext-6 "§ 3.2.5.1 Definition of space-like elements")
- [§ 3.2.6 String Literal
 \<ms\>](#ref-for-dfn-mtext-7 "§ 3.2.6 String Literal <ms>")
- [§ 3.8 Semantics and
 Presentation](#ref-for-dfn-mtext-8 "§ 3.8 Semantics and Presentation")

[Permalink](#dfn-mi)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mi-1 "§ 2.1 Elements and attributes")
- [§ 3.2.2 Identifier
 \<mi\>](#ref-for-dfn-mi-2 "§ 3.2.2 Identifier <mi>")
 [(2)](#ref-for-dfn-mi-3 "Reference 2")

[Permalink](#dfn-mathvariant)

**Referenced in:**

- [§ 3.2.2 Identifier
 \<mi\>](#ref-for-dfn-mathvariant-1 "§ 3.2.2 Identifier <mi>")

[Permalink](#dfn-mn)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mn-1 "§ 2.1 Elements and attributes")
- [§ 3.2.3 Number \<mn\>](#ref-for-dfn-mn-2 "§ 3.2.3 Number <mn>")

[Permalink](#dfn-mo)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mo-1 "§ 2.1 Elements and attributes")
- [§ 3.2.4 Operator, Fence, Separator or Accent
 \<mo\>](#ref-for-dfn-mo-2 "§ 3.2.4 Operator, Fence, Separator or Accent <mo>")
- [§ 3.2.4.1 Embellished
 operators](#ref-for-dfn-mo-3 "§ 3.2.4.1 Embellished operators")
 [(2)](#ref-for-dfn-mo-4 "Reference 2")
- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-mo-5 "§ 3.2.4.2 Dictionary-based attributes")
 [(2)](#ref-for-dfn-mo-6 "Reference 2")
 [(3)](#ref-for-dfn-mo-7 "Reference 3")
- [§ 3.3.1 Group Sub-Expressions
 \<mrow\>](#ref-for-dfn-mo-8 "§ 3.3.1 Group Sub-Expressions <mrow>")

[Permalink](#dfn-fence)

**Referenced in:**

- [§ 3.2.4 Operator, Fence, Separator or Accent
 \<mo\>](#ref-for-dfn-fence-1 "§ 3.2.4 Operator, Fence, Separator or Accent <mo>")
 [(2)](#ref-for-dfn-fence-2 "Reference 2")

[Permalink](#dfn-separator)

**Referenced in:**

- [§ 3.2.4 Operator, Fence, Separator or Accent
 \<mo\>](#ref-for-dfn-separator-1 "§ 3.2.4 Operator, Fence, Separator or Accent <mo>")
 [(2)](#ref-for-dfn-separator-2 "Reference 2")

[Permalink](#dfn-embellished-operator)

**Referenced in:**

- [§ 3.1.2 Layout
 Algorithms](#ref-for-dfn-embellished-operator-1 "§ 3.1.2 Layout Algorithms")
- [§ 3.2.4.1 Embellished
 operators](#ref-for-dfn-embellished-operator-2 "§ 3.2.4.1 Embellished operators")
 [(2)](#ref-for-dfn-embellished-operator-3 "Reference 2")
 [(3)](#ref-for-dfn-embellished-operator-4 "Reference 3")
 [(4)](#ref-for-dfn-embellished-operator-5 "Reference 4")
 [(5)](#ref-for-dfn-embellished-operator-6 "Reference 5")
 [(6)](#ref-for-dfn-embellished-operator-7 "Reference 6")
- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-embellished-operator-8 "§ 3.2.4.2 Dictionary-based attributes")
 [(2)](#ref-for-dfn-embellished-operator-9 "Reference 2")
 [(3)](#ref-for-dfn-embellished-operator-10 "Reference 3")
 [(4)](#ref-for-dfn-embellished-operator-11 "Reference 4")
 [(5)](#ref-for-dfn-embellished-operator-12 "Reference 5")
 [(6)](#ref-for-dfn-embellished-operator-13 "Reference 6")
 [(7)](#ref-for-dfn-embellished-operator-14 "Reference 7")
 [(8)](#ref-for-dfn-embellished-operator-15 "Reference 8")
 [(9)](#ref-for-dfn-embellished-operator-16 "Reference 9")
- [§ 3.3.1.1 Algorithm for stretching operators along the block
 axis](#ref-for-dfn-embellished-operator-17 "§ 3.3.1.1 Algorithm for stretching operators along the block axis")
 [(2)](#ref-for-dfn-embellished-operator-18 "Reference 2")
 [(3)](#ref-for-dfn-embellished-operator-19 "Reference 3")
- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-embellished-operator-20 "§ 3.3.1.2 Layout of <mrow>")
 [(2)](#ref-for-dfn-embellished-operator-21 "Reference 2")
 [(3)](#ref-for-dfn-embellished-operator-22 "Reference 3")
 [(4)](#ref-for-dfn-embellished-operator-23 "Reference 4")
 [(5)](#ref-for-dfn-embellished-operator-24 "Reference 5")
 [(6)](#ref-for-dfn-embellished-operator-25 "Reference 6")
 [(7)](#ref-for-dfn-embellished-operator-26 "Reference 7")
 [(8)](#ref-for-dfn-embellished-operator-27 "Reference 8")
- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-embellished-operator-28 "§ 3.4.1.2 Base with subscript")
- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-embellished-operator-29 "§ 3.4.1.3 Base with superscript")
- [§ 3.4.2.1 Children of \<munder\>, \<mover\>,
 \<munderover\>](#ref-for-dfn-embellished-operator-30 "§ 3.4.2.1 Children of <munder>, <mover>, <munderover>")
- [§ 3.4.2.2 Algorithm for stretching operators along the inline
 axis](#ref-for-dfn-embellished-operator-31 "§ 3.4.2.2 Algorithm for stretching operators along the inline axis")
 [(2)](#ref-for-dfn-embellished-operator-32 "Reference 2")
- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-embellished-operator-33 "§ 3.4.2.3 Base with underscript")
 [(2)](#ref-for-dfn-embellished-operator-34 "Reference 2")
 [(3)](#ref-for-dfn-embellished-operator-35 "Reference 3")
- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-embellished-operator-36 "§ 3.4.2.4 Base with overscript")
 [(2)](#ref-for-dfn-embellished-operator-37 "Reference 2")
 [(3)](#ref-for-dfn-embellished-operator-38 "Reference 3")

[Permalink](#dfn-core-operator)

**Referenced in:**

- [§ 3.1.2 Layout
 Algorithms](#ref-for-dfn-core-operator-1 "§ 3.1.2 Layout Algorithms")
 [(2)](#ref-for-dfn-core-operator-2 "Reference 2")
- [§ 3.2.4.1 Embellished
 operators](#ref-for-dfn-core-operator-3 "§ 3.2.4.1 Embellished operators")
- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-core-operator-4 "§ 3.2.4.2 Dictionary-based attributes")
 [(2)](#ref-for-dfn-core-operator-5 "Reference 2")
 [(3)](#ref-for-dfn-core-operator-6 "Reference 3")
 [(4)](#ref-for-dfn-core-operator-7 "Reference 4")
 [(5)](#ref-for-dfn-core-operator-8 "Reference 5")

[Permalink](#dfn-stretch-axis)

**Referenced in:**

- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-stretch-axis-1 "§ 3.2.4.3 Layout of operators")
 [(2)](#ref-for-dfn-stretch-axis-2 "Reference 2")
- [§ 3.3.1.1 Algorithm for stretching operators along the block
 axis](#ref-for-dfn-stretch-axis-3 "§ 3.3.1.1 Algorithm for stretching operators along the block axis")
- [§ 3.4.2.2 Algorithm for stretching operators along the inline
 axis](#ref-for-dfn-stretch-axis-4 "§ 3.4.2.2 Algorithm for stretching operators along the inline axis")
- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-stretch-axis-5 "§ 3.4.2.3 Base with underscript")
- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-stretch-axis-6 "§ 3.4.2.4 Base with overscript")
- [§ B.1 Operator
 Dictionary](#ref-for-dfn-stretch-axis-7 "§ B.1 Operator Dictionary")

[Permalink](#dfn-form)

**Referenced in:**

- [§ 3.2.4 Operator, Fence, Separator or Accent
 \<mo\>](#ref-for-dfn-form-1 "§ 3.2.4 Operator, Fence, Separator or Accent <mo>")
 [(2)](#ref-for-dfn-form-2 "Reference 2")

[Permalink](#dfn-algorithm-for-determining-the-form-of-an-embellished-operator)

**Referenced in:**

- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-algorithm-for-determining-the-form-of-an-embellished-operator-1 "§ 3.2.4.2 Dictionary-based attributes")

[Permalink](#dfn-stretchy)

**Referenced in:**

- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-stretchy-1 "§ 3.2.4.2 Dictionary-based attributes")
- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-stretchy-2 "§ 3.2.4.3 Layout of operators")
 [(2)](#ref-for-dfn-stretchy-3 "Reference 2")
- [§ 3.3.1.1 Algorithm for stretching operators along the block
 axis](#ref-for-dfn-stretchy-4 "§ 3.3.1.1 Algorithm for stretching operators along the block axis")
- [§ 3.4.2.2 Algorithm for stretching operators along the inline
 axis](#ref-for-dfn-stretchy-5 "§ 3.4.2.2 Algorithm for stretching operators along the inline axis")
- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-stretchy-6 "§ 3.4.2.3 Base with underscript")
- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-stretchy-7 "§ 3.4.2.4 Base with overscript")
- [§ B.2 Operator Dictionary
 (human-readable)](#ref-for-dfn-stretchy-8 "§ B.2 Operator Dictionary (human-readable)")

[Permalink](#dfn-symmetric)

**Referenced in:**

- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-symmetric-1 "§ 3.2.4.2 Dictionary-based attributes")
- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-symmetric-2 "§ 3.2.4.3 Layout of operators")
 [(2)](#ref-for-dfn-symmetric-3 "Reference 2")
 [(3)](#ref-for-dfn-symmetric-4 "Reference 3")
 [(4)](#ref-for-dfn-symmetric-5 "Reference 4")
- [§ B.2 Operator Dictionary
 (human-readable)](#ref-for-dfn-symmetric-6 "§ B.2 Operator Dictionary (human-readable)")

[Permalink](#dfn-largeop)

**Referenced in:**

- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-largeop-1 "§ 3.2.4.2 Dictionary-based attributes")
- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-largeop-2 "§ 3.2.4.3 Layout of operators")
 [(2)](#ref-for-dfn-largeop-3 "Reference 2")
- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-largeop-4 "§ 3.4.1.2 Base with subscript")
- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-largeop-5 "§ 3.4.1.3 Base with superscript")
- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-largeop-6 "§ 3.4.2.3 Base with underscript")
 [(2)](#ref-for-dfn-largeop-7 "Reference 2")
- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-largeop-8 "§ 3.4.2.4 Base with overscript")
 [(2)](#ref-for-dfn-largeop-9 "Reference 2")
- [§ 4.3 The math-style
 property](#ref-for-dfn-largeop-10 "§ 4.3 The math-style property")
- [§ B.2 Operator Dictionary
 (human-readable)](#ref-for-dfn-largeop-11 "§ B.2 Operator Dictionary (human-readable)")

[Permalink](#dfn-movablelimits)

**Referenced in:**

- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-movablelimits-1 "§ 3.2.4.2 Dictionary-based attributes")
- [§ 3.4.2.1 Children of \<munder\>, \<mover\>,
 \<munderover\>](#ref-for-dfn-movablelimits-2 "§ 3.4.2.1 Children of <munder>, <mover>, <munderover>")
- [§ 4.3 The math-style
 property](#ref-for-dfn-movablelimits-3 "§ 4.3 The math-style property")
- [§ B.2 Operator Dictionary
 (human-readable)](#ref-for-dfn-movablelimits-4 "§ B.2 Operator Dictionary (human-readable)")

[Permalink](#dfn-stretchy-0)

**Referenced in:**

- [§ 3.2.4 Operator, Fence, Separator or Accent
 \<mo\>](#ref-for-dfn-stretchy-0-1 "§ 3.2.4 Operator, Fence, Separator or Accent <mo>")
 [(2)](#ref-for-dfn-stretchy-0-2 "Reference 2")

[Permalink](#dfn-symmetric-0)

**Referenced in:**

- [§ 3.2.4 Operator, Fence, Separator or Accent
 \<mo\>](#ref-for-dfn-symmetric-0-1 "§ 3.2.4 Operator, Fence, Separator or Accent <mo>")
 [(2)](#ref-for-dfn-symmetric-0-2 "Reference 2")

[Permalink](#dfn-largeop-0)

**Referenced in:**

- [§ 3.2.4 Operator, Fence, Separator or Accent
 \<mo\>](#ref-for-dfn-largeop-0-1 "§ 3.2.4 Operator, Fence, Separator or Accent <mo>")
 [(2)](#ref-for-dfn-largeop-0-2 "Reference 2")

[Permalink](#dfn-movablelimits-0)

**Referenced in:**

- [§ 3.2.4 Operator, Fence, Separator or Accent
 \<mo\>](#ref-for-dfn-movablelimits-0-1 "§ 3.2.4 Operator, Fence, Separator or Accent <mo>")
 [(2)](#ref-for-dfn-movablelimits-0-2 "Reference 2")

[Permalink](#dfn-lspace)

**Referenced in:**

- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-lspace-1 "§ 3.2.4.2 Dictionary-based attributes")
- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-lspace-2 "§ 3.3.1.2 Layout of <mrow>")
 [(2)](#ref-for-dfn-lspace-3 "Reference 2")
 [(3)](#ref-for-dfn-lspace-4 "Reference 3")
- [§ B.2 Operator Dictionary
 (human-readable)](#ref-for-dfn-lspace-5 "§ B.2 Operator Dictionary (human-readable)")

[Permalink](#dfn-rspace)

**Referenced in:**

- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-rspace-1 "§ 3.2.4.2 Dictionary-based attributes")
- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-rspace-2 "§ 3.3.1.2 Layout of <mrow>")
 [(2)](#ref-for-dfn-rspace-3 "Reference 2")
 [(3)](#ref-for-dfn-rspace-4 "Reference 3")
- [§ B.2 Operator Dictionary
 (human-readable)](#ref-for-dfn-rspace-5 "§ B.2 Operator Dictionary (human-readable)")

[Permalink](#dfn-minsize)

**Referenced in:**

- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-minsize-1 "§ 3.2.4.2 Dictionary-based attributes")
- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-minsize-2 "§ 3.2.4.3 Layout of operators")

[Permalink](#dfn-maxsize)

**Referenced in:**

- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-maxsize-1 "§ 3.2.4.3 Layout of operators")

[Permalink](#dfn-lspace-0)

**Referenced in:**

- [§ 3.2.4 Operator, Fence, Separator or Accent
 \<mo\>](#ref-for-dfn-lspace-0-1 "§ 3.2.4 Operator, Fence, Separator or Accent <mo>")
 [(2)](#ref-for-dfn-lspace-0-2 "Reference 2")

[Permalink](#dfn-rspace-0)

**Referenced in:**

- [§ 3.2.4 Operator, Fence, Separator or Accent
 \<mo\>](#ref-for-dfn-rspace-0-1 "§ 3.2.4 Operator, Fence, Separator or Accent <mo>")
 [(2)](#ref-for-dfn-rspace-0-2 "Reference 2")

[Permalink](#dfn-minsize-0)

**Referenced in:**

- [§ 3.2.4 Operator, Fence, Separator or Accent
 \<mo\>](#ref-for-dfn-minsize-0-1 "§ 3.2.4 Operator, Fence, Separator or Accent <mo>")
 [(2)](#ref-for-dfn-minsize-0-2 "Reference 2")

[Permalink](#dfn-maxsize-0)

**Referenced in:**

- [§ 3.2.4 Operator, Fence, Separator or Accent
 \<mo\>](#ref-for-dfn-maxsize-0-1 "§ 3.2.4 Operator, Fence, Separator or Accent <mo>")
 [(2)](#ref-for-dfn-maxsize-0-2 "Reference 2")

[Permalink](#algorithm-for-determining-the-properties-of-an-embellished-operator)

**Referenced in:**

- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-algorithm-for-determining-the-properties-of-an-embellished-operator-1 "§ 3.2.4.2 Dictionary-based attributes")

[Permalink](#dfn-mspace)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mspace-1 "§ 2.1 Elements and attributes")
- [§ 3.2.4 Operator, Fence, Separator or Accent
 \<mo\>](#ref-for-dfn-mspace-2 "§ 3.2.4 Operator, Fence, Separator or Accent <mo>")
- [§ 3.2.5 Space
 \<mspace\>](#ref-for-dfn-mspace-3 "§ 3.2.5 Space <mspace>")
- [§ 3.2.5.1 Definition of space-like
 elements](#ref-for-dfn-mspace-4 "§ 3.2.5.1 Definition of space-like elements")

[Permalink](#attribute-mspace-width)

**Referenced in:**

- [§ 3.2.5 Space
 \<mspace\>](#ref-for-attribute-mspace-width-1 "§ 3.2.5 Space <mspace>")

[Permalink](#attribute-mspace-height)

**Referenced in:**

- [§ 3.2.5 Space
 \<mspace\>](#ref-for-attribute-mspace-height-1 "§ 3.2.5 Space <mspace>")

[Permalink](#attribute-mspace-depth)

**Referenced in:**

- [§ 3.2.5 Space
 \<mspace\>](#ref-for-attribute-mspace-depth-1 "§ 3.2.5 Space <mspace>")

[Permalink](#dfn-space-like)

**Referenced in:**

- [§ 3.2.4.1 Embellished
 operators](#ref-for-dfn-space-like-1 "§ 3.2.4.1 Embellished operators")
- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-space-like-2 "§ 3.2.4.2 Dictionary-based attributes")
 [(2)](#ref-for-dfn-space-like-3 "Reference 2")
- [§ 3.2.5.1 Definition of space-like
 elements](#ref-for-dfn-space-like-4 "§ 3.2.5.1 Definition of space-like elements")

[Permalink](#dfn-ms)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-ms-1 "§ 2.1 Elements and attributes")
- [§ 3.2.6 String Literal
 \<ms\>](#ref-for-dfn-ms-2 "§ 3.2.6 String Literal <ms>")

[Permalink](#dfn-mrow)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mrow-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-mrow-2 "Reference 2")
- [§ 2.1.1 The Top-Level \<math\>
 Element](#ref-for-dfn-mrow-3 "§ 2.1.1 The Top-Level <math> Element")
 [(2)](#ref-for-dfn-mrow-4 "Reference 2")
- [§ 3.1.3 Anonymous \<mrow\>
 boxes](#ref-for-dfn-mrow-5 "§ 3.1.3 Anonymous <mrow> boxes")
- [§ 3.3.1 Group Sub-Expressions
 \<mrow\>](#ref-for-dfn-mrow-6 "§ 3.3.1 Group Sub-Expressions <mrow>")
 [(2)](#ref-for-dfn-mrow-7 "Reference 2")
 [(3)](#ref-for-dfn-mrow-8 "Reference 3")
- [§ 3.3.2 Fractions
 \<mfrac\>](#ref-for-dfn-mrow-9 "§ 3.3.2 Fractions <mfrac>")
- [§ 3.3.3 Radicals \<msqrt\>,
 \<mroot\>](#ref-for-dfn-mrow-10 "§ 3.3.3 Radicals <msqrt>, <mroot>")
- [§ 3.3.4 Style Change
 \<mstyle\>](#ref-for-dfn-mrow-11 "§ 3.3.4 Style Change <mstyle>")
 [(2)](#ref-for-dfn-mrow-12 "Reference 2")
- [§ 3.3.5 Error Message
 \<merror\>](#ref-for-dfn-mrow-13 "§ 3.3.5 Error Message <merror>")
- [§ 3.3.6 Adjust Space Around Content
 \<mpadded\>](#ref-for-dfn-mrow-14 "§ 3.3.6 Adjust Space Around Content <mpadded>")
- [§ 3.3.7 Making Sub-Expressions Invisible
 \<mphantom\>](#ref-for-dfn-mrow-15 "§ 3.3.7 Making Sub-Expressions Invisible <mphantom>")
- [§ 3.4.1.1 Children of \<msub\>, \<msup\>,
 \<msubsup\>](#ref-for-dfn-mrow-16 "§ 3.4.1.1 Children of <msub>, <msup>, <msubsup>")
 [(2)](#ref-for-dfn-mrow-17 "Reference 2")
 [(3)](#ref-for-dfn-mrow-18 "Reference 3")
- [§ 3.4.2.1 Children of \<munder\>, \<mover\>,
 \<munderover\>](#ref-for-dfn-mrow-19 "§ 3.4.2.1 Children of <munder>, <mover>, <munderover>")
 [(2)](#ref-for-dfn-mrow-20 "Reference 2")
 [(3)](#ref-for-dfn-mrow-21 "Reference 3")
- [§ 3.4.3 Prescripts and Tensor Indices
 \<mmultiscripts\>](#ref-for-dfn-mrow-22 "§ 3.4.3 Prescripts and Tensor Indices <mmultiscripts>")
 [(2)](#ref-for-dfn-mrow-23 "Reference 2")
 [(3)](#ref-for-dfn-mrow-24 "Reference 3")
- [§ 3.6 Linking \<a\>](#ref-for-dfn-mrow-25 "§ 3.6 Linking <a>")
- [§ 3.8 Semantics and
 Presentation](#ref-for-dfn-mrow-26 "§ 3.8 Semantics and Presentation")
- [§ 4.1 The display: block math and display: inline math
 value](#ref-for-dfn-mrow-27 "§ 4.1 The display: block math and display: inline math value")
 [(2)](#ref-for-dfn-mrow-28 "Reference 2")
- [§ E. Security
 Considerations](#ref-for-dfn-mrow-29 "§ E. Security Considerations")

[Permalink](#dfn-algorithm-for-stretching-operators-along-the-block-axis)

**Referenced in:**

- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-algorithm-for-stretching-operators-along-the-block-axis-1 "§ 3.3.1.2 Layout of <mrow>")

[Permalink](#dfn-slanted)

**Referenced in:**

- [§ 3.3.1.2 Layout of
 \<mrow\>](#ref-for-dfn-slanted-1 "§ 3.3.1.2 Layout of <mrow>")
 [(2)](#ref-for-dfn-slanted-2 "Reference 2")
 [(3)](#ref-for-dfn-slanted-3 "Reference 3")
 [(4)](#ref-for-dfn-slanted-4 "Reference 4")

[Permalink](#dfn-mfrac)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mfrac-1 "§ 2.1 Elements and attributes")
- [§ 3.2.4.1 Embellished
 operators](#ref-for-dfn-mfrac-2 "§ 3.2.4.1 Embellished operators")
 [(2)](#ref-for-dfn-mfrac-3 "Reference 2")
- [§ 3.3.1 Group Sub-Expressions
 \<mrow\>](#ref-for-dfn-mfrac-4 "§ 3.3.1 Group Sub-Expressions <mrow>")
- [§ 4.3 The math-style
 property](#ref-for-dfn-mfrac-5 "§ 4.3 The math-style property")

[Permalink](#dfn-linethickness)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-linethickness-1 "§ 2.1 Elements and attributes")
- [§ 3.3.2 Fractions
 \<mfrac\>](#ref-for-dfn-linethickness-2 "§ 3.3.2 Fractions <mfrac>")
 [(2)](#ref-for-dfn-linethickness-3 "Reference 2")

[Permalink](#dfn-fraction-line-thickness)

**Referenced in:**

- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-fraction-line-thickness-1 "§ 3.3.2.1 Fraction with nonzero line thickness")
 [(2)](#ref-for-dfn-fraction-line-thickness-2 "Reference 2")
 [(3)](#ref-for-dfn-fraction-line-thickness-3 "Reference 3")
 [(4)](#ref-for-dfn-fraction-line-thickness-4 "Reference 4")
 [(5)](#ref-for-dfn-fraction-line-thickness-5 "Reference 5")
 [(6)](#ref-for-dfn-fraction-line-thickness-6 "Reference 6")
- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-fraction-line-thickness-7 "§ 3.3.2.2 Fraction with zero line thickness")

[Permalink](#dfn-numerator)

**Referenced in:**

- [§ 3.3.2 Fractions
 \<mfrac\>](#ref-for-dfn-numerator-1 "§ 3.3.2 Fractions <mfrac>")
- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-numerator-2 "§ 3.3.2.1 Fraction with nonzero line thickness")
 [(2)](#ref-for-dfn-numerator-3 "Reference 2")
 [(3)](#ref-for-dfn-numerator-4 "Reference 3")
 [(4)](#ref-for-dfn-numerator-5 "Reference 4")
 [(5)](#ref-for-dfn-numerator-6 "Reference 5")
 [(6)](#ref-for-dfn-numerator-7 "Reference 6")
 [(7)](#ref-for-dfn-numerator-8 "Reference 7")
 [(8)](#ref-for-dfn-numerator-9 "Reference 8")
 [(9)](#ref-for-dfn-numerator-10 "Reference 9")
- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-numerator-11 "§ 3.3.2.2 Fraction with zero line thickness")
 [(2)](#ref-for-dfn-numerator-12 "Reference 2")
 [(3)](#ref-for-dfn-numerator-13 "Reference 3")
 [(4)](#ref-for-dfn-numerator-14 "Reference 4")
 [(5)](#ref-for-dfn-numerator-15 "Reference 5")
 [(6)](#ref-for-dfn-numerator-16 "Reference 6")

[Permalink](#dfn-denominator)

**Referenced in:**

- [§ 3.3.2 Fractions
 \<mfrac\>](#ref-for-dfn-denominator-1 "§ 3.3.2 Fractions <mfrac>")
- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-denominator-2 "§ 3.3.2.1 Fraction with nonzero line thickness")
 [(2)](#ref-for-dfn-denominator-3 "Reference 2")
 [(3)](#ref-for-dfn-denominator-4 "Reference 3")
 [(4)](#ref-for-dfn-denominator-5 "Reference 4")
 [(5)](#ref-for-dfn-denominator-6 "Reference 5")
 [(6)](#ref-for-dfn-denominator-7 "Reference 6")
 [(7)](#ref-for-dfn-denominator-8 "Reference 7")
 [(8)](#ref-for-dfn-denominator-9 "Reference 8")
 [(9)](#ref-for-dfn-denominator-10 "Reference 9")
- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-denominator-11 "§ 3.3.2.2 Fraction with zero line thickness")
 [(2)](#ref-for-dfn-denominator-12 "Reference 2")
 [(3)](#ref-for-dfn-denominator-13 "Reference 3")
 [(4)](#ref-for-dfn-denominator-14 "Reference 4")
 [(5)](#ref-for-dfn-denominator-15 "Reference 5")
 [(6)](#ref-for-dfn-denominator-16 "Reference 6")

[Permalink](#dfn-msqrt)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-msqrt-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-msqrt-2 "Reference 2")
- [§ 3.1.3 Anonymous \<mrow\>
 boxes](#ref-for-dfn-msqrt-3 "§ 3.1.3 Anonymous <mrow> boxes")
- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-msqrt-4 "§ 3.2.4.2 Dictionary-based attributes")
 [(2)](#ref-for-dfn-msqrt-5 "Reference 2")
- [§ 3.3.3 Radicals \<msqrt\>,
 \<mroot\>](#ref-for-dfn-msqrt-6 "§ 3.3.3 Radicals <msqrt>, <mroot>")
 [(2)](#ref-for-dfn-msqrt-7 "Reference 2")

[Permalink](#dfn-mroot)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mroot-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-mroot-2 "Reference 2")
- [§ 3.3.3 Radicals \<msqrt\>,
 \<mroot\>](#ref-for-dfn-mroot-3 "§ 3.3.3 Radicals <msqrt>, <mroot>")
 [(2)](#ref-for-dfn-mroot-4 "Reference 2")
 [(3)](#ref-for-dfn-mroot-5 "Reference 3")

[Permalink](#dfn-mroot-base)

**Referenced in:**

- [§ 3.3.3.3 Root with
 index](#ref-for-dfn-mroot-base-1 "§ 3.3.3.3 Root with index")
 [(2)](#ref-for-dfn-mroot-base-2 "Reference 2")

[Permalink](#dfn-mroot-index)

**Referenced in:**

- [§ 3.3.3.3 Root with
 index](#ref-for-dfn-mroot-index-1 "§ 3.3.3.3 Root with index")
 [(2)](#ref-for-dfn-mroot-index-2 "Reference 2")
 [(3)](#ref-for-dfn-mroot-index-3 "Reference 3")
 [(4)](#ref-for-dfn-mroot-index-4 "Reference 4")

[Permalink](#dfn-msqrt-base)

**Referenced in:**

- [§ 3.3.3.2 Square
 root](#ref-for-dfn-msqrt-base-1 "§ 3.3.3.2 Square root")
 [(2)](#ref-for-dfn-msqrt-base-2 "Reference 2")
 [(3)](#ref-for-dfn-msqrt-base-3 "Reference 3")
 [(4)](#ref-for-dfn-msqrt-base-4 "Reference 4")
 [(5)](#ref-for-dfn-msqrt-base-5 "Reference 5")
 [(6)](#ref-for-dfn-msqrt-base-6 "Reference 6")
 [(7)](#ref-for-dfn-msqrt-base-7 "Reference 7")
 [(8)](#ref-for-dfn-msqrt-base-8 "Reference 8")

[Permalink](#dfn-radical-glyph)

**Referenced in:**

- [§ 3.3.3.2 Square
 root](#ref-for-dfn-radical-glyph-1 "§ 3.3.3.2 Square root")

[Permalink](#dfn-radical-gap)

**Referenced in:**

- [§ 3.3.3.1 Radical
 symbol](#ref-for-dfn-radical-gap-1 "§ 3.3.3.1 Radical symbol")
- [§ 3.3.3.2 Square
 root](#ref-for-dfn-radical-gap-2 "§ 3.3.3.2 Square root")

[Permalink](#dfn-box-metrics-of-the-radical-glyph)

**Referenced in:**

- [§ 3.3.3.2 Square
 root](#ref-for-dfn-box-metrics-of-the-radical-glyph-1 "§ 3.3.3.2 Square root")
 [(2)](#ref-for-dfn-box-metrics-of-the-radical-glyph-2 "Reference 2")
 [(3)](#ref-for-dfn-box-metrics-of-the-radical-glyph-3 "Reference 3")
 [(4)](#ref-for-dfn-box-metrics-of-the-radical-glyph-4 "Reference 4")

[Permalink](#dfn-painting-of-the-surd)

**Referenced in:**

- [§ 3.3.3.2 Square
 root](#ref-for-dfn-painting-of-the-surd-1 "§ 3.3.3.2 Square root")

[Permalink](#dfn-adjustedradicalkernbeforedegree)

**Referenced in:**

- [§ 3.3.3.3 Root with
 index](#ref-for-dfn-adjustedradicalkernbeforedegree-1 "§ 3.3.3.3 Root with index")
 [(2)](#ref-for-dfn-adjustedradicalkernbeforedegree-2 "Reference 2")

[Permalink](#dfn-adjustedradicalkernafterdegree)

**Referenced in:**

- [§ 3.3.3.3 Root with
 index](#ref-for-dfn-adjustedradicalkernafterdegree-1 "§ 3.3.3.3 Root with index")

[Permalink](#dfn-mstyle)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mstyle-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-mstyle-2 "Reference 2")
- [§ 3.3.4 Style Change
 \<mstyle\>](#ref-for-dfn-mstyle-3 "§ 3.3.4 Style Change <mstyle>")

[Permalink](#dfn-merror)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-merror-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-merror-2 "Reference 2")
- [§ 3.3.5 Error Message
 \<merror\>](#ref-for-dfn-merror-3 "§ 3.3.5 Error Message <merror>")

[Permalink](#dfn-mpadded)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mpadded-1 "§ 2.1 Elements and attributes")
- [§ 3.2.4.1 Embellished
 operators](#ref-for-dfn-mpadded-2 "§ 3.2.4.1 Embellished operators")
 [(2)](#ref-for-dfn-mpadded-3 "Reference 2")
- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-mpadded-4 "§ 3.2.4.2 Dictionary-based attributes")
 [(2)](#ref-for-dfn-mpadded-5 "Reference 2")
- [§ 3.2.5.1 Definition of space-like
 elements](#ref-for-dfn-mpadded-6 "§ 3.2.5.1 Definition of space-like elements")
- [§ 3.3.6 Adjust Space Around Content
 \<mpadded\>](#ref-for-dfn-mpadded-7 "§ 3.3.6 Adjust Space Around Content <mpadded>")
- [§ 3.3.6.1 Inner box and requested
 parameters](#ref-for-dfn-mpadded-8 "§ 3.3.6.1 Inner box and requested parameters")

[Permalink](#attribute-mpadded-width)

**Referenced in:**

- [§ 3.3.6 Adjust Space Around Content
 \<mpadded\>](#ref-for-attribute-mpadded-width-1 "§ 3.3.6 Adjust Space Around Content <mpadded>")

[Permalink](#attribute-mpadded-height)

**Referenced in:**

- [§ 3.3.6 Adjust Space Around Content
 \<mpadded\>](#ref-for-attribute-mpadded-height-1 "§ 3.3.6 Adjust Space Around Content <mpadded>")

[Permalink](#attribute-mpadded-depth)

**Referenced in:**

- [§ 3.3.6 Adjust Space Around Content
 \<mpadded\>](#ref-for-attribute-mpadded-depth-1 "§ 3.3.6 Adjust Space Around Content <mpadded>")

[Permalink](#attribute-mpadded-lspace)

**Referenced in:**

- [§ 3.3.6 Adjust Space Around Content
 \<mpadded\>](#ref-for-attribute-mpadded-lspace-1 "§ 3.3.6 Adjust Space Around Content <mpadded>")

[Permalink](#attribute-mpadded-voffset)

**Referenced in:**

- [§ 3.3.6 Adjust Space Around Content
 \<mpadded\>](#ref-for-attribute-mpadded-voffset-1 "§ 3.3.6 Adjust Space Around Content <mpadded>")

[Permalink](#dfn-mpadded-inner-box)

**Referenced in:**

- [§ 3.3.6.2 Layout of
 \<mpadded\>](#ref-for-dfn-mpadded-inner-box-1 "§ 3.3.6.2 Layout of <mpadded>")
 [(2)](#ref-for-dfn-mpadded-inner-box-2 "Reference 2")

[Permalink](#dfn-mphantom)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mphantom-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-mphantom-2 "Reference 2")
- [§ 3.2.5.1 Definition of space-like
 elements](#ref-for-dfn-mphantom-3 "§ 3.2.5.1 Definition of space-like elements")
- [§ 3.3.7 Making Sub-Expressions Invisible
 \<mphantom\>](#ref-for-dfn-mphantom-4 "§ 3.3.7 Making Sub-Expressions Invisible <mphantom>")

[Permalink](#dfn-msub)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-msub-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-msub-2 "Reference 2")

[Permalink](#dfn-msup)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-msup-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-msup-2 "Reference 2")
- [§ 3.3.1 Group Sub-Expressions
 \<mrow\>](#ref-for-dfn-msup-3 "§ 3.3.1 Group Sub-Expressions <mrow>")

[Permalink](#dfn-msubsup)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-msubsup-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-msubsup-2 "Reference 2")

[Permalink](#dfn-msub-base)

**Referenced in:**

- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-msub-base-1 "§ 3.4.1.2 Base with subscript")
 [(2)](#ref-for-dfn-msub-base-2 "Reference 2")
 [(3)](#ref-for-dfn-msub-base-3 "Reference 3")
 [(4)](#ref-for-dfn-msub-base-4 "Reference 4")
 [(5)](#ref-for-dfn-msub-base-5 "Reference 5")
 [(6)](#ref-for-dfn-msub-base-6 "Reference 6")
 [(7)](#ref-for-dfn-msub-base-7 "Reference 7")
 [(8)](#ref-for-dfn-msub-base-8 "Reference 8")
 [(9)](#ref-for-dfn-msub-base-9 "Reference 9")
 [(10)](#ref-for-dfn-msub-base-10 "Reference 10")

[Permalink](#dfn-msub-subscript)

**Referenced in:**

- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-msub-subscript-1 "§ 3.4.1.2 Base with subscript")
 [(2)](#ref-for-dfn-msub-subscript-2 "Reference 2")
 [(3)](#ref-for-dfn-msub-subscript-3 "Reference 3")
 [(4)](#ref-for-dfn-msub-subscript-4 "Reference 4")

[Permalink](#dfn-msup-base)

**Referenced in:**

- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-msup-base-1 "§ 3.4.1.3 Base with superscript")
 [(2)](#ref-for-dfn-msup-base-2 "Reference 2")
 [(3)](#ref-for-dfn-msup-base-3 "Reference 3")
 [(4)](#ref-for-dfn-msup-base-4 "Reference 4")
 [(5)](#ref-for-dfn-msup-base-5 "Reference 5")
 [(6)](#ref-for-dfn-msup-base-6 "Reference 6")
 [(7)](#ref-for-dfn-msup-base-7 "Reference 7")
 [(8)](#ref-for-dfn-msup-base-8 "Reference 8")
 [(9)](#ref-for-dfn-msup-base-9 "Reference 9")
 [(10)](#ref-for-dfn-msup-base-10 "Reference 10")

[Permalink](#dfn-msup-superscript)

**Referenced in:**

- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-msup-superscript-1 "§ 3.4.1.3 Base with superscript")
 [(2)](#ref-for-dfn-msup-superscript-2 "Reference 2")
 [(3)](#ref-for-dfn-msup-superscript-3 "Reference 3")
 [(4)](#ref-for-dfn-msup-superscript-4 "Reference 4")

[Permalink](#dfn-msubsup-base)

**Referenced in:**

- [§ 3.4.1.4 Base with subscript and
 superscript](#ref-for-dfn-msubsup-base-1 "§ 3.4.1.4 Base with subscript and superscript")
 [(2)](#ref-for-dfn-msubsup-base-2 "Reference 2")
 [(3)](#ref-for-dfn-msubsup-base-3 "Reference 3")

[Permalink](#dfn-msubsup-subscript)

**Referenced in:**

- [§ 3.4.1.4 Base with subscript and
 superscript](#ref-for-dfn-msubsup-subscript-1 "§ 3.4.1.4 Base with subscript and superscript")
 [(2)](#ref-for-dfn-msubsup-subscript-2 "Reference 2")
 [(3)](#ref-for-dfn-msubsup-subscript-3 "Reference 3")

[Permalink](#dfn-msubsup-superscript)

**Referenced in:**

- [§ 3.4.1.4 Base with subscript and
 superscript](#ref-for-dfn-msubsup-superscript-1 "§ 3.4.1.4 Base with subscript and superscript")
 [(2)](#ref-for-dfn-msubsup-superscript-2 "Reference 2")
 [(3)](#ref-for-dfn-msubsup-superscript-3 "Reference 3")
 [(4)](#ref-for-dfn-msubsup-superscript-4 "Reference 4")

[Permalink](#dfn-munder)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-munder-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-munder-2 "Reference 2")
- [§ 2.1.6 The displaystyle and scriptlevel
 attributes](#ref-for-dfn-munder-3 "§ 2.1.6 The displaystyle and scriptlevel attributes")

[Permalink](#dfn-mover)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mover-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-mover-2 "Reference 2")
- [§ 3.4.4 Displaystyle, scriptlevel and math-shift in
 scripts](#ref-for-dfn-mover-3 "§ 3.4.4 Displaystyle, scriptlevel and math-shift in scripts")
 [(2)](#ref-for-dfn-mover-4 "Reference 2")
 [(3)](#ref-for-dfn-mover-5 "Reference 3")

[Permalink](#dfn-munderover)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-munderover-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-munderover-2 "Reference 2")
- [§ 3.4.4 Displaystyle, scriptlevel and math-shift in
 scripts](#ref-for-dfn-munderover-3 "§ 3.4.4 Displaystyle, scriptlevel and math-shift in scripts")
 [(2)](#ref-for-dfn-munderover-4 "Reference 2")
 [(3)](#ref-for-dfn-munderover-5 "Reference 3")

[Permalink](#dfn-accent)

**Referenced in:**

- [§ 3.4.2 Underscripts and Overscripts \<munder\>, \<mover\>,
 \<munderover\>](#ref-for-dfn-accent-1 "§ 3.4.2 Underscripts and Overscripts <munder>, <mover>, <munderover>")
 [(2)](#ref-for-dfn-accent-2 "Reference 2")
- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-accent-3 "§ 3.4.2.4 Base with overscript")
- [§ 3.4.4 Displaystyle, scriptlevel and math-shift in
 scripts](#ref-for-dfn-accent-4 "§ 3.4.4 Displaystyle, scriptlevel and math-shift in scripts")
 [(2)](#ref-for-dfn-accent-5 "Reference 2")

[Permalink](#dfn-accentunder)

**Referenced in:**

- [§ 3.4.2 Underscripts and Overscripts \<munder\>, \<mover\>,
 \<munderover\>](#ref-for-dfn-accentunder-1 "§ 3.4.2 Underscripts and Overscripts <munder>, <mover>, <munderover>")
 [(2)](#ref-for-dfn-accentunder-2 "Reference 2")
- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-accentunder-3 "§ 3.4.2.3 Base with underscript")
- [§ 3.4.4 Displaystyle, scriptlevel and math-shift in
 scripts](#ref-for-dfn-accentunder-4 "§ 3.4.4 Displaystyle, scriptlevel and math-shift in scripts")

[Permalink](#dfn-munder-base)

**Referenced in:**

- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-munder-base-1 "§ 3.4.2.3 Base with underscript")
 [(2)](#ref-for-dfn-munder-base-2 "Reference 2")
 [(3)](#ref-for-dfn-munder-base-3 "Reference 3")
 [(4)](#ref-for-dfn-munder-base-4 "Reference 4")
 [(5)](#ref-for-dfn-munder-base-5 "Reference 5")
 [(6)](#ref-for-dfn-munder-base-6 "Reference 6")
 [(7)](#ref-for-dfn-munder-base-7 "Reference 7")
 [(8)](#ref-for-dfn-munder-base-8 "Reference 8")
 [(9)](#ref-for-dfn-munder-base-9 "Reference 9")
 [(10)](#ref-for-dfn-munder-base-10 "Reference 10")
 [(11)](#ref-for-dfn-munder-base-11 "Reference 11")
 [(12)](#ref-for-dfn-munder-base-12 "Reference 12")

[Permalink](#dfn-munder-underscript)

**Referenced in:**

- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-munder-underscript-1 "§ 3.4.2.3 Base with underscript")
 [(2)](#ref-for-dfn-munder-underscript-2 "Reference 2")
 [(3)](#ref-for-dfn-munder-underscript-3 "Reference 3")
 [(4)](#ref-for-dfn-munder-underscript-4 "Reference 4")
 [(5)](#ref-for-dfn-munder-underscript-5 "Reference 5")
 [(6)](#ref-for-dfn-munder-underscript-6 "Reference 6")
 [(7)](#ref-for-dfn-munder-underscript-7 "Reference 7")
 [(8)](#ref-for-dfn-munder-underscript-8 "Reference 8")
 [(9)](#ref-for-dfn-munder-underscript-9 "Reference 9")
 [(10)](#ref-for-dfn-munder-underscript-10 "Reference 10")
 [(11)](#ref-for-dfn-munder-underscript-11 "Reference 11")

[Permalink](#dfn-mover-base)

**Referenced in:**

- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-mover-base-1 "§ 3.4.2.4 Base with overscript")
 [(2)](#ref-for-dfn-mover-base-2 "Reference 2")
 [(3)](#ref-for-dfn-mover-base-3 "Reference 3")
 [(4)](#ref-for-dfn-mover-base-4 "Reference 4")
 [(5)](#ref-for-dfn-mover-base-5 "Reference 5")
 [(6)](#ref-for-dfn-mover-base-6 "Reference 6")
 [(7)](#ref-for-dfn-mover-base-7 "Reference 7")
 [(8)](#ref-for-dfn-mover-base-8 "Reference 8")
 [(9)](#ref-for-dfn-mover-base-9 "Reference 9")
 [(10)](#ref-for-dfn-mover-base-10 "Reference 10")
 [(11)](#ref-for-dfn-mover-base-11 "Reference 11")
 [(12)](#ref-for-dfn-mover-base-12 "Reference 12")

[Permalink](#dfn-mover-overscript)

**Referenced in:**

- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-mover-overscript-1 "§ 3.4.2.4 Base with overscript")
 [(2)](#ref-for-dfn-mover-overscript-2 "Reference 2")
 [(3)](#ref-for-dfn-mover-overscript-3 "Reference 3")
 [(4)](#ref-for-dfn-mover-overscript-4 "Reference 4")
 [(5)](#ref-for-dfn-mover-overscript-5 "Reference 5")
 [(6)](#ref-for-dfn-mover-overscript-6 "Reference 6")
 [(7)](#ref-for-dfn-mover-overscript-7 "Reference 7")
 [(8)](#ref-for-dfn-mover-overscript-8 "Reference 8")
 [(9)](#ref-for-dfn-mover-overscript-9 "Reference 9")
 [(10)](#ref-for-dfn-mover-overscript-10 "Reference 10")
 [(11)](#ref-for-dfn-mover-overscript-11 "Reference 11")
 [(12)](#ref-for-dfn-mover-overscript-12 "Reference 12")

[Permalink](#dfn-munderover-base)

**Referenced in:**

- [§ 3.4.2.5 Base with underscript and
 overscript](#ref-for-dfn-munderover-base-1 "§ 3.4.2.5 Base with underscript and overscript")
 [(2)](#ref-for-dfn-munderover-base-2 "Reference 2")

[Permalink](#dfn-munderover-underscript)

**Referenced in:**

- [§ 3.4.2.5 Base with underscript and
 overscript](#ref-for-dfn-munderover-underscript-1 "§ 3.4.2.5 Base with underscript and overscript")
 [(2)](#ref-for-dfn-munderover-underscript-2 "Reference 2")

[Permalink](#dfn-munderover-overscript)

**Referenced in:**

- [§ 3.4.2.5 Base with underscript and
 overscript](#ref-for-dfn-munderover-overscript-1 "§ 3.4.2.5 Base with underscript and overscript")
 [(2)](#ref-for-dfn-munderover-overscript-2 "Reference 2")

[Permalink](#dfn-algorithm-for-stretching-operators-along-the-inline-axis)

**Referenced in:**

- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-algorithm-for-stretching-operators-along-the-inline-axis-1 "§ 3.4.2.3 Base with underscript")
- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-algorithm-for-stretching-operators-along-the-inline-axis-2 "§ 3.4.2.4 Base with overscript")
 [(2)](#ref-for-dfn-algorithm-for-stretching-operators-along-the-inline-axis-3 "Reference 2")
- [§ 3.4.2.5 Base with underscript and
 overscript](#ref-for-dfn-algorithm-for-stretching-operators-along-the-inline-axis-4 "§ 3.4.2.5 Base with underscript and overscript")

[Permalink](#dfn-mmultiscripts)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mmultiscripts-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-mmultiscripts-2 "Reference 2")

[Permalink](#dfn-mprescripts)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mprescripts-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-mprescripts-2 "Reference 2")
- [§ 3.4.3 Prescripts and Tensor Indices
 \<mmultiscripts\>](#ref-for-dfn-mprescripts-3 "§ 3.4.3 Prescripts and Tensor Indices <mmultiscripts>")
 [(2)](#ref-for-dfn-mprescripts-4 "Reference 2")
 [(3)](#ref-for-dfn-mprescripts-5 "Reference 3")
 [(4)](#ref-for-dfn-mprescripts-6 "Reference 4")
 [(5)](#ref-for-dfn-mprescripts-7 "Reference 5")
- [§ 3.4.4 Displaystyle, scriptlevel and math-shift in
 scripts](#ref-for-dfn-mprescripts-8 "§ 3.4.4 Displaystyle, scriptlevel and math-shift in scripts")
 [(2)](#ref-for-dfn-mprescripts-9 "Reference 2")

[Permalink](#dfn-mmultiscripts-base)

**Referenced in:**

- [§ 3.4.3.1 Base with prescripts and
 postscripts](#ref-for-dfn-mmultiscripts-base-1 "§ 3.4.3.1 Base with prescripts and postscripts")
 [(2)](#ref-for-dfn-mmultiscripts-base-2 "Reference 2")
 [(3)](#ref-for-dfn-mmultiscripts-base-3 "Reference 3")
 [(4)](#ref-for-dfn-mmultiscripts-base-4 "Reference 4")

[Permalink](#dfn-mmultiscripts-postscripts)

**Referenced in:**

- [§ 3.4.3.1 Base with prescripts and
 postscripts](#ref-for-dfn-mmultiscripts-postscripts-1 "§ 3.4.3.1 Base with prescripts and postscripts")
 [(2)](#ref-for-dfn-mmultiscripts-postscripts-2 "Reference 2")
 [(3)](#ref-for-dfn-mmultiscripts-postscripts-3 "Reference 3")
 [(4)](#ref-for-dfn-mmultiscripts-postscripts-4 "Reference 4")

[Permalink](#dfn-subscript-superscript-pair)

**Referenced in:**

- [§ 3.4.3 Prescripts and Tensor Indices
 \<mmultiscripts\>](#ref-for-dfn-subscript-superscript-pair-1 "§ 3.4.3 Prescripts and Tensor Indices <mmultiscripts>")
- [§ 3.4.3.1 Base with prescripts and
 postscripts](#ref-for-dfn-subscript-superscript-pair-2 "§ 3.4.3.1 Base with prescripts and postscripts")
 [(2)](#ref-for-dfn-subscript-superscript-pair-3 "Reference 2")
 [(3)](#ref-for-dfn-subscript-superscript-pair-4 "Reference 3")
 [(4)](#ref-for-dfn-subscript-superscript-pair-5 "Reference 4")
 [(5)](#ref-for-dfn-subscript-superscript-pair-6 "Reference 5")
 [(6)](#ref-for-dfn-subscript-superscript-pair-7 "Reference 6")
 [(7)](#ref-for-dfn-subscript-superscript-pair-8 "Reference 7")
 [(8)](#ref-for-dfn-subscript-superscript-pair-9 "Reference 8")
 [(9)](#ref-for-dfn-subscript-superscript-pair-10 "Reference 9")

[Permalink](#dfn-mmultiscripts-prescripts)

**Referenced in:**

- [§ 3.4.3.1 Base with prescripts and
 postscripts](#ref-for-dfn-mmultiscripts-prescripts-1 "§ 3.4.3.1 Base with prescripts and postscripts")
 [(2)](#ref-for-dfn-mmultiscripts-prescripts-2 "Reference 2")

[Permalink](#dfn-mtable)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mtable-1 "§ 2.1 Elements and attributes")
- [§ 3.1.1 Box Model](#ref-for-dfn-mtable-2 "§ 3.1.1 Box Model")
- [§ 3.5 Tabular Math](#ref-for-dfn-mtable-3 "§ 3.5 Tabular Math")
- [§ 4.1 The display: block math and display: inline math
 value](#ref-for-dfn-mtable-4 "§ 4.1 The display: block math and display: inline math value")

[Permalink](#dfn-mtr)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mtr-1 "§ 2.1 Elements and attributes")
- [§ 3.1.1 Box Model](#ref-for-dfn-mtr-2 "§ 3.1.1 Box Model")
- [§ 3.5 Tabular Math](#ref-for-dfn-mtr-3 "§ 3.5 Tabular Math")
- [§ 4.1 The display: block math and display: inline math
 value](#ref-for-dfn-mtr-4 "§ 4.1 The display: block math and display: inline math value")

[Permalink](#dfn-mtd)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-mtd-1 "§ 2.1 Elements and attributes")
- [§ 3.1.1 Box Model](#ref-for-dfn-mtd-2 "§ 3.1.1 Box Model")
- [§ 3.1.3 Anonymous \<mrow\>
 boxes](#ref-for-dfn-mtd-3 "§ 3.1.3 Anonymous <mrow> boxes")
- [§ 3.5 Tabular Math](#ref-for-dfn-mtd-4 "§ 3.5 Tabular Math")
- [§ 4.1 The display: block math and display: inline math
 value](#ref-for-dfn-mtd-5 "§ 4.1 The display: block math and display: inline math value")

[Permalink](#dfn-columnspan)

**Referenced in:**

- [§ 3.5.3 Entry in Table or Matrix
 \<mtd\>](#ref-for-dfn-columnspan-1 "§ 3.5.3 Entry in Table or Matrix <mtd>")

[Permalink](#dfn-rowspan)

**Referenced in:**

- [§ 3.5.3 Entry in Table or Matrix
 \<mtd\>](#ref-for-dfn-rowspan-1 "§ 3.5.3 Entry in Table or Matrix <mtd>")
 [(2)](#ref-for-dfn-rowspan-2 "Reference 2")

[Permalink](#dfn-a)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-a-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-a-2 "Reference 2")

[Permalink](#dfn-href)

**Referenced in:**

- [§ 3.6 Linking \<a\>](#ref-for-dfn-href-1 "§ 3.6 Linking <a>")
 [(2)](#ref-for-dfn-href-2 "Reference 2")
 [(3)](#ref-for-dfn-href-3 "Reference 3")
 [(4)](#ref-for-dfn-href-4 "Reference 4")
 [(5)](#ref-for-dfn-href-5 "Reference 5")
 [(6)](#ref-for-dfn-href-6 "Reference 6")

[Permalink](#dfn-target)

**Referenced in:**

- [§ 3.6 Linking \<a\>](#ref-for-dfn-target-1 "§ 3.6 Linking <a>")

[Permalink](#dfn-download)

**Referenced in:**

- [§ 3.6 Linking \<a\>](#ref-for-dfn-download-1 "§ 3.6 Linking <a>")

[Permalink](#dfn-ping)

**Referenced in:**

- [§ 3.6 Linking \<a\>](#ref-for-dfn-ping-1 "§ 3.6 Linking <a>")

[Permalink](#dfn-rel)

**Referenced in:**

- [§ 3.6 Linking \<a\>](#ref-for-dfn-rel-1 "§ 3.6 Linking <a>")

[Permalink](#dfn-hreflang)

**Referenced in:**

- [§ 3.6 Linking \<a\>](#ref-for-dfn-hreflang-1 "§ 3.6 Linking <a>")

[Permalink](#dfn-type)

**Referenced in:**

- [§ 3.6 Linking \<a\>](#ref-for-dfn-type-1 "§ 3.6 Linking <a>")

[Permalink](#dfn-referrerpolicy)

**Referenced in:**

- [§ 3.6 Linking
 \<a\>](#ref-for-dfn-referrerpolicy-1 "§ 3.6 Linking <a>")

[Permalink](#dom-mathmlanchorelement)
[exported]
[IDL](#webidl-617025194 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.6 Linking
 \<a\>](#ref-for-dom-mathmlanchorelement-1 "§ 3.6 Linking <a>")
 [(2)](#ref-for-dom-mathmlanchorelement-2 "Reference 2")

[Permalink](#dom-mathmlanchorelement-href)
[exported]

**Referenced in:**

- [§ 3.6 Linking
 \<a\>](#ref-for-dom-mathmlanchorelement-href-1 "§ 3.6 Linking <a>")

[Permalink](#dom-mathmlanchorelement-target)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-maction)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-maction-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-maction-2 "Reference 2")
- [§ 3.1.1 Box Model](#ref-for-dfn-maction-3 "§ 3.1.1 Box Model")
- [§ E. Security
 Considerations](#ref-for-dfn-maction-4 "§ E. Security Considerations")
 [(2)](#ref-for-dfn-maction-5 "Reference 2")

[Permalink](#dfn-actiontype)

**Referenced in:**

- [§ 3.7 Enlivening
 Expressions](#ref-for-dfn-actiontype-1 "§ 3.7 Enlivening Expressions")

[Permalink](#dfn-selection)

**Referenced in:**

- [§ 3.7 Enlivening
 Expressions](#ref-for-dfn-selection-1 "§ 3.7 Enlivening Expressions")

[Permalink](#dfn-semantics)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-semantics-1 "§ 2.1 Elements and attributes")
 [(2)](#ref-for-dfn-semantics-2 "Reference 2")
- [§ 3.1.1 Box Model](#ref-for-dfn-semantics-3 "§ 3.1.1 Box Model")

[Permalink](#dfn-annotation)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-annotation-1 "§ 2.1 Elements and attributes")

[Permalink](#dfn-annotation-xml)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-annotation-xml-1 "§ 2.1 Elements and attributes")
- [§ 2.2.1 HTML and
 SVG](#ref-for-dfn-annotation-xml-2 "§ 2.2.1 HTML and SVG")

[Permalink](#dfn-encoding)

**Referenced in:**

- [§ 2.1 Elements and
 attributes](#ref-for-dfn-encoding-1 "§ 2.1 Elements and attributes")
- [§ 3.8 Semantics and
 Presentation](#ref-for-dfn-encoding-2 "§ 3.8 Semantics and Presentation")
 [(2)](#ref-for-dfn-encoding-3 "Reference 2")

[Permalink](#propdef-math-style)
[exported]

**Referenced in:**

- [§ 2.1.1 The Top-Level \<math\>
 Element](#ref-for-propdef-math-style-1 "§ 2.1.1 The Top-Level <math> Element")
- [§ 2.1.6 The displaystyle and scriptlevel
 attributes](#ref-for-propdef-math-style-2 "§ 2.1.6 The displaystyle and scriptlevel attributes")
- [§ 3.2.4.3 Layout of
 operators](#ref-for-propdef-math-style-3 "§ 3.2.4.3 Layout of operators")
- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-propdef-math-style-4 "§ 3.3.2.1 Fraction with nonzero line thickness")
 [(2)](#ref-for-propdef-math-style-5 "Reference 2")
 [(3)](#ref-for-propdef-math-style-6 "Reference 3")
 [(4)](#ref-for-propdef-math-style-7 "Reference 4")
- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-propdef-math-style-8 "§ 3.3.2.2 Fraction with zero line thickness")
 [(2)](#ref-for-propdef-math-style-9 "Reference 2")
 [(3)](#ref-for-propdef-math-style-10 "Reference 3")
 [(4)](#ref-for-propdef-math-style-11 "Reference 4")
- [§ 3.3.3.1 Radical
 symbol](#ref-for-propdef-math-style-12 "§ 3.3.3.1 Radical symbol")
 [(2)](#ref-for-propdef-math-style-13 "Reference 2")
- [§ 3.4.2.1 Children of \<munder\>, \<mover\>,
 \<munderover\>](#ref-for-propdef-math-style-14 "§ 3.4.2.1 Children of <munder>, <mover>, <munderover>")
- [§ 4.3 The math-style
 property](#ref-for-propdef-math-style-15 "§ 4.3 The math-style property")
- [§ 4.4 The math-shift
 property](#ref-for-propdef-math-style-16 "§ 4.4 The math-shift property")
- [§ 4.5 The math-depth
 property](#ref-for-propdef-math-style-17 "§ 4.5 The math-depth property")
 [(2)](#ref-for-propdef-math-style-18 "Reference 2")
 [(3)](#ref-for-propdef-math-style-19 "Reference 3")

[Permalink](#propdef-math-shift)
[exported]

**Referenced in:**

- [§ 3.3.2 Fractions
 \<mfrac\>](#ref-for-propdef-math-shift-1 "§ 3.3.2 Fractions <mfrac>")
 [(2)](#ref-for-propdef-math-shift-2 "Reference 2")
- [§ 3.3.3 Radicals \<msqrt\>,
 \<mroot\>](#ref-for-propdef-math-shift-3 "§ 3.3.3 Radicals <msqrt>, <mroot>")
- [§ 3.4.1.3 Base with
 superscript](#ref-for-propdef-math-shift-4 "§ 3.4.1.3 Base with superscript")
- [§ 3.4.4 Displaystyle, scriptlevel and math-shift in
 scripts](#ref-for-propdef-math-shift-5 "§ 3.4.4 Displaystyle, scriptlevel and math-shift in scripts")
 [(2)](#ref-for-propdef-math-shift-6 "Reference 2")
 [(3)](#ref-for-propdef-math-shift-7 "Reference 3")
 [(4)](#ref-for-propdef-math-shift-8 "Reference 4")
- [§ 4.4 The math-shift
 property](#ref-for-propdef-math-shift-9 "§ 4.4 The math-shift property")

[Permalink](#propdef-math-depth)
[exported]

**Referenced in:**

- [§ 2.1.6 The displaystyle and scriptlevel
 attributes](#ref-for-propdef-math-depth-1 "§ 2.1.6 The displaystyle and scriptlevel attributes")
- [§ 4.3 The math-style
 property](#ref-for-propdef-math-depth-2 "§ 4.3 The math-style property")
- [§ 4.5 The math-depth
 property](#ref-for-propdef-math-depth-3 "§ 4.5 The math-depth property")
 [(2)](#ref-for-propdef-math-depth-4 "Reference 2")
 [(3)](#ref-for-propdef-math-depth-5 "Reference 3")
 [(4)](#ref-for-propdef-math-depth-6 "Reference 4")
 [(5)](#ref-for-propdef-math-depth-7 "Reference 5")
 [(6)](#ref-for-propdef-math-depth-8 "Reference 6")
 [(7)](#ref-for-propdef-math-depth-9 "Reference 7")
 [(8)](#ref-for-propdef-math-depth-10 "Reference 8")
 [(9)](#ref-for-propdef-math-depth-11 "Reference 9")
 [(10)](#ref-for-propdef-math-depth-12 "Reference 10")
 [(11)](#ref-for-propdef-math-depth-13 "Reference 11")

[Permalink](#dfn-default-fallback-constant)

**Referenced in:**

- [§ 5.1 Layout constants
 (MathConstants)](#ref-for-dfn-default-fallback-constant-1 "§ 5.1 Layout constants (MathConstants)")
 [(2)](#ref-for-dfn-default-fallback-constant-2 "Reference 2")
 [(3)](#ref-for-dfn-default-fallback-constant-3 "Reference 3")
 [(4)](#ref-for-dfn-default-fallback-constant-4 "Reference 4")
 [(5)](#ref-for-dfn-default-fallback-constant-5 "Reference 5")
 [(6)](#ref-for-dfn-default-fallback-constant-6 "Reference 6")
 [(7)](#ref-for-dfn-default-fallback-constant-7 "Reference 7")
 [(8)](#ref-for-dfn-default-fallback-constant-8 "Reference 8")
 [(9)](#ref-for-dfn-default-fallback-constant-9 "Reference 9")
 [(10)](#ref-for-dfn-default-fallback-constant-10 "Reference 10")
 [(11)](#ref-for-dfn-default-fallback-constant-11 "Reference 11")
 [(12)](#ref-for-dfn-default-fallback-constant-12 "Reference 12")
 [(13)](#ref-for-dfn-default-fallback-constant-13 "Reference 13")
 [(14)](#ref-for-dfn-default-fallback-constant-14 "Reference 14")
 [(15)](#ref-for-dfn-default-fallback-constant-15 "Reference 15")
 [(16)](#ref-for-dfn-default-fallback-constant-16 "Reference 16")
 [(17)](#ref-for-dfn-default-fallback-constant-17 "Reference 17")
 [(18)](#ref-for-dfn-default-fallback-constant-18 "Reference 18")
 [(19)](#ref-for-dfn-default-fallback-constant-19 "Reference 19")
 [(20)](#ref-for-dfn-default-fallback-constant-20 "Reference 20")
 [(21)](#ref-for-dfn-default-fallback-constant-21 "Reference 21")

[Permalink](#dfn-default-rule-thickness)

**Referenced in:**

- [§ 5.1 Layout constants
 (MathConstants)](#ref-for-dfn-default-rule-thickness-1 "§ 5.1 Layout constants (MathConstants)")
 [(2)](#ref-for-dfn-default-rule-thickness-2 "Reference 2")
 [(3)](#ref-for-dfn-default-rule-thickness-3 "Reference 3")
 [(4)](#ref-for-dfn-default-rule-thickness-4 "Reference 4")
 [(5)](#ref-for-dfn-default-rule-thickness-5 "Reference 5")
 [(6)](#ref-for-dfn-default-rule-thickness-6 "Reference 6")
 [(7)](#ref-for-dfn-default-rule-thickness-7 "Reference 7")
 [(8)](#ref-for-dfn-default-rule-thickness-8 "Reference 8")
 [(9)](#ref-for-dfn-default-rule-thickness-9 "Reference 9")
 [(10)](#ref-for-dfn-default-rule-thickness-10 "Reference 10")
 [(11)](#ref-for-dfn-default-rule-thickness-11 "Reference 11")
 [(12)](#ref-for-dfn-default-rule-thickness-12 "Reference 12")
 [(13)](#ref-for-dfn-default-rule-thickness-13 "Reference 13")
 [(14)](#ref-for-dfn-default-rule-thickness-14 "Reference 14")
 [(15)](#ref-for-dfn-default-rule-thickness-15 "Reference 15")
 [(16)](#ref-for-dfn-default-rule-thickness-16 "Reference 16")

[Permalink](#dfn-scriptpercentscaledown)

**Referenced in:**

- [§ 4.5 The math-depth
 property](#ref-for-dfn-scriptpercentscaledown-1 "§ 4.5 The math-depth property")
 [(2)](#ref-for-dfn-scriptpercentscaledown-2 "Reference 2")

[Permalink](#dfn-scriptscriptpercentscaledown)

**Referenced in:**

- [§ 4.5 The math-depth
 property](#ref-for-dfn-scriptscriptpercentscaledown-1 "§ 4.5 The math-depth property")
 [(2)](#ref-for-dfn-scriptscriptpercentscaledown-2 "Reference 2")

[Permalink](#dfn-displayoperatorminheight)

**Referenced in:**

- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-displayoperatorminheight-1 "§ 3.2.4.3 Layout of operators")
 [(2)](#ref-for-dfn-displayoperatorminheight-2 "Reference 2")
 [(3)](#ref-for-dfn-displayoperatorminheight-3 "Reference 3")

[Permalink](#dfn-axisheight)

**Referenced in:**

- [§ 3.1.1 Box Model](#ref-for-dfn-axisheight-1 "§ 3.1.1 Box Model")
- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-axisheight-2 "§ 3.2.4.3 Layout of operators")
 [(2)](#ref-for-dfn-axisheight-3 "Reference 2")
 [(3)](#ref-for-dfn-axisheight-4 "Reference 3")
 [(4)](#ref-for-dfn-axisheight-5 "Reference 4")
 [(5)](#ref-for-dfn-axisheight-6 "Reference 5")
 [(6)](#ref-for-dfn-axisheight-7 "Reference 6")
 [(7)](#ref-for-dfn-axisheight-8 "Reference 7")
 [(8)](#ref-for-dfn-axisheight-9 "Reference 8")
 [(9)](#ref-for-dfn-axisheight-10 "Reference 9")
 [(10)](#ref-for-dfn-axisheight-11 "Reference 10")
 [(11)](#ref-for-dfn-axisheight-12 "Reference 11")
 [(12)](#ref-for-dfn-axisheight-13 "Reference 12")
 [(13)](#ref-for-dfn-axisheight-14 "Reference 13")
 [(14)](#ref-for-dfn-axisheight-15 "Reference 14")
 [(15)](#ref-for-dfn-axisheight-16 "Reference 15")
 [(16)](#ref-for-dfn-axisheight-17 "Reference 16")
- [§ 3.3.1 Group Sub-Expressions
 \<mrow\>](#ref-for-dfn-axisheight-18 "§ 3.3.1 Group Sub-Expressions <mrow>")
- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-axisheight-19 "§ 3.3.2.1 Fraction with nonzero line thickness")
 [(2)](#ref-for-dfn-axisheight-20 "Reference 2")
 [(3)](#ref-for-dfn-axisheight-21 "Reference 3")
 [(4)](#ref-for-dfn-axisheight-22 "Reference 4")
 [(5)](#ref-for-dfn-axisheight-23 "Reference 5")

[Permalink](#dfn-accentbaseheight)

**Referenced in:**

- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-accentbaseheight-1 "§ 3.4.2.4 Base with overscript")
 [(2)](#ref-for-dfn-accentbaseheight-2 "Reference 2")
 [(3)](#ref-for-dfn-accentbaseheight-3 "Reference 3")
 [(4)](#ref-for-dfn-accentbaseheight-4 "Reference 4")

[Permalink](#dfn-subscriptshiftdown)

**Referenced in:**

- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-subscriptshiftdown-1 "§ 3.4.1.2 Base with subscript")

[Permalink](#dfn-subscripttopmax)

**Referenced in:**

- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-subscripttopmax-1 "§ 3.4.1.2 Base with subscript")

[Permalink](#dfn-subscriptbaselinedropmin)

**Referenced in:**

- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-subscriptbaselinedropmin-1 "§ 3.4.1.2 Base with subscript")

[Permalink](#dfn-superscriptshiftup)

**Referenced in:**

- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-superscriptshiftup-1 "§ 3.4.1.3 Base with superscript")
- [§ 4.4 The math-shift
 property](#ref-for-dfn-superscriptshiftup-2 "§ 4.4 The math-shift property")

[Permalink](#dfn-superscriptshiftupcramped)

**Referenced in:**

- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-superscriptshiftupcramped-1 "§ 3.4.1.3 Base with superscript")
- [§ 4.4 The math-shift
 property](#ref-for-dfn-superscriptshiftupcramped-2 "§ 4.4 The math-shift property")

[Permalink](#dfn-superscriptbottommin)

**Referenced in:**

- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-superscriptbottommin-1 "§ 3.4.1.3 Base with superscript")

[Permalink](#dfn-superscriptbaselinedropmax)

**Referenced in:**

- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-superscriptbaselinedropmax-1 "§ 3.4.1.3 Base with superscript")

[Permalink](#dfn-subsuperscriptgapmin)

**Referenced in:**

- [§ 3.4.1.4 Base with subscript and
 superscript](#ref-for-dfn-subsuperscriptgapmin-1 "§ 3.4.1.4 Base with subscript and superscript")
 [(2)](#ref-for-dfn-subsuperscriptgapmin-2 "Reference 2")
 [(3)](#ref-for-dfn-subsuperscriptgapmin-3 "Reference 3")

[Permalink](#dfn-superscriptbottommaxwithsubscript)

**Referenced in:**

- [§ 3.4.1.4 Base with subscript and
 superscript](#ref-for-dfn-superscriptbottommaxwithsubscript-1 "§ 3.4.1.4 Base with subscript and superscript")

[Permalink](#dfn-spaceafterscript)

**Referenced in:**

- [§ 3.4.1.2 Base with
 subscript](#ref-for-dfn-spaceafterscript-1 "§ 3.4.1.2 Base with subscript")
 [(2)](#ref-for-dfn-spaceafterscript-2 "Reference 2")
- [§ 3.4.1.3 Base with
 superscript](#ref-for-dfn-spaceafterscript-3 "§ 3.4.1.3 Base with superscript")
 [(2)](#ref-for-dfn-spaceafterscript-4 "Reference 2")
- [§ 3.4.3.1 Base with prescripts and
 postscripts](#ref-for-dfn-spaceafterscript-5 "§ 3.4.3.1 Base with prescripts and postscripts")
 [(2)](#ref-for-dfn-spaceafterscript-6 "Reference 2")
 [(3)](#ref-for-dfn-spaceafterscript-7 "Reference 3")
 [(4)](#ref-for-dfn-spaceafterscript-8 "Reference 4")

[Permalink](#dfn-upperlimitgapmin)

**Referenced in:**

- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-upperlimitgapmin-1 "§ 3.4.2.4 Base with overscript")

[Permalink](#dfn-upperlimitbaselinerisemin)

**Referenced in:**

- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-upperlimitbaselinerisemin-1 "§ 3.4.2.4 Base with overscript")

[Permalink](#dfn-lowerlimitgapmin)

**Referenced in:**

- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-lowerlimitgapmin-1 "§ 3.4.2.3 Base with underscript")

[Permalink](#dfn-lowerlimitbaselinedropmin)

**Referenced in:**

- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-lowerlimitbaselinedropmin-1 "§ 3.4.2.3 Base with underscript")

[Permalink](#dfn-stacktopshiftup)

**Referenced in:**

- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-stacktopshiftup-1 "§ 3.3.2.2 Fraction with zero line thickness")

[Permalink](#dfn-stacktopdisplaystyleshiftup)

**Referenced in:**

- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-stacktopdisplaystyleshiftup-1 "§ 3.3.2.2 Fraction with zero line thickness")

[Permalink](#dfn-stackbottomshiftdown)

**Referenced in:**

- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-stackbottomshiftdown-1 "§ 3.3.2.2 Fraction with zero line thickness")

[Permalink](#dfn-stackbottomdisplaystyleshiftdown)

**Referenced in:**

- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-stackbottomdisplaystyleshiftdown-1 "§ 3.3.2.2 Fraction with zero line thickness")

[Permalink](#dfn-stackgapmin)

**Referenced in:**

- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-stackgapmin-1 "§ 3.3.2.2 Fraction with zero line thickness")

[Permalink](#dfn-stackdisplaystylegapmin)

**Referenced in:**

- [§ 3.3.2.2 Fraction with zero line
 thickness](#ref-for-dfn-stackdisplaystylegapmin-1 "§ 3.3.2.2 Fraction with zero line thickness")

[Permalink](#dfn-stretchstacktopshiftup)

**Referenced in:**

- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-stretchstacktopshiftup-1 "§ 3.4.2.4 Base with overscript")

[Permalink](#dfn-stretchstackbottomshiftdown)

**Referenced in:**

- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-stretchstackbottomshiftdown-1 "§ 3.4.2.3 Base with underscript")

[Permalink](#dfn-stretchstackgapabovemin)

**Referenced in:**

- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-stretchstackgapabovemin-1 "§ 3.4.2.3 Base with underscript")

[Permalink](#dfn-stretchstackgapbelowmin)

**Referenced in:**

- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-stretchstackgapbelowmin-1 "§ 3.4.2.4 Base with overscript")

[Permalink](#dfn-fractionnumeratorshiftup)

**Referenced in:**

- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-fractionnumeratorshiftup-1 "§ 3.3.2.1 Fraction with nonzero line thickness")

[Permalink](#dfn-fractionnumeratordisplaystyleshiftup)

**Referenced in:**

- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-fractionnumeratordisplaystyleshiftup-1 "§ 3.3.2.1 Fraction with nonzero line thickness")

[Permalink](#dfn-fractiondenominatorshiftdown)

**Referenced in:**

- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-fractiondenominatorshiftdown-1 "§ 3.3.2.1 Fraction with nonzero line thickness")

[Permalink](#dfn-fractiondenominatordisplaystyleshiftdown)

**Referenced in:**

- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-fractiondenominatordisplaystyleshiftdown-1 "§ 3.3.2.1 Fraction with nonzero line thickness")

[Permalink](#dfn-fractionnumeratorgapmin)

**Referenced in:**

- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-fractionnumeratorgapmin-1 "§ 3.3.2.1 Fraction with nonzero line thickness")

[Permalink](#dfn-fractionnumdisplaystylegapmin)

**Referenced in:**

- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-fractionnumdisplaystylegapmin-1 "§ 3.3.2.1 Fraction with nonzero line thickness")

[Permalink](#dfn-fractionrulethickness)

**Referenced in:**

- [§ 3.3.2 Fractions
 \<mfrac\>](#ref-for-dfn-fractionrulethickness-1 "§ 3.3.2 Fractions <mfrac>")

[Permalink](#dfn-fractiondenominatorgapmin)

**Referenced in:**

- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-fractiondenominatorgapmin-1 "§ 3.3.2.1 Fraction with nonzero line thickness")

[Permalink](#dfn-fractiondenomdisplaystylegapmin)

**Referenced in:**

- [§ 3.3.2.1 Fraction with nonzero line
 thickness](#ref-for-dfn-fractiondenomdisplaystylegapmin-1 "§ 3.3.2.1 Fraction with nonzero line thickness")

[Permalink](#dfn-overbarverticalgap)

**Referenced in:**

- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-overbarverticalgap-1 "§ 3.4.2.4 Base with overscript")

[Permalink](#dfn-overbarextraascender)

**Referenced in:**

- [§ 3.4.2.4 Base with
 overscript](#ref-for-dfn-overbarextraascender-1 "§ 3.4.2.4 Base with overscript")

[Permalink](#dfn-underbarverticalgap)

**Referenced in:**

- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-underbarverticalgap-1 "§ 3.4.2.3 Base with underscript")

[Permalink](#dfn-underbarextradescender)

**Referenced in:**

- [§ 3.4.2.3 Base with
 underscript](#ref-for-dfn-underbarextradescender-1 "§ 3.4.2.3 Base with underscript")

[Permalink](#dfn-radicalverticalgap)

**Referenced in:**

- [§ 3.3.3.1 Radical
 symbol](#ref-for-dfn-radicalverticalgap-1 "§ 3.3.3.1 Radical symbol")

[Permalink](#dfn-radicaldisplaystyleverticalgap)

**Referenced in:**

- [§ 3.3.3.1 Radical
 symbol](#ref-for-dfn-radicaldisplaystyleverticalgap-1 "§ 3.3.3.1 Radical symbol")

[Permalink](#dfn-radicalrulethickness)

**Referenced in:**

- [§ 3.3.3.1 Radical
 symbol](#ref-for-dfn-radicalrulethickness-1 "§ 3.3.3.1 Radical symbol")
- [§ 3.3.3.2 Square
 root](#ref-for-dfn-radicalrulethickness-2 "§ 3.3.3.2 Square root")
 [(2)](#ref-for-dfn-radicalrulethickness-3 "Reference 2")
 [(3)](#ref-for-dfn-radicalrulethickness-4 "Reference 3")

[Permalink](#dfn-radicalextraascender)

**Referenced in:**

- [§ 3.3.3.2 Square
 root](#ref-for-dfn-radicalextraascender-1 "§ 3.3.3.2 Square root")
 [(2)](#ref-for-dfn-radicalextraascender-2 "Reference 2")
 [(3)](#ref-for-dfn-radicalextraascender-3 "Reference 3")

[Permalink](#dfn-radicalkernbeforedegree)

**Referenced in:**

- [§ 3.3.3.3 Root with
 index](#ref-for-dfn-radicalkernbeforedegree-1 "§ 3.3.3.3 Root with index")
 [(2)](#ref-for-dfn-radicalkernbeforedegree-2 "Reference 2")

[Permalink](#dfn-radicalkernafterdegree)

**Referenced in:**

- [§ 3.3.3.3 Root with
 index](#ref-for-dfn-radicalkernafterdegree-1 "§ 3.3.3.3 Root with index")
 [(2)](#ref-for-dfn-radicalkernafterdegree-2 "Reference 2")
 [(3)](#ref-for-dfn-radicalkernafterdegree-3 "Reference 3")

[Permalink](#dfn-radicaldegreebottomraisepercent)

**Referenced in:**

- [§ 3.3.3.3 Root with
 index](#ref-for-dfn-radicaldegreebottomraisepercent-1 "§ 3.3.3.3 Root with index")
 [(2)](#ref-for-dfn-radicaldegreebottomraisepercent-2 "Reference 2")
 [(3)](#ref-for-dfn-radicaldegreebottomraisepercent-3 "Reference 3")

[Permalink](#dfn-mathitalicscorrectioninfo)

**Referenced in:**

- [§ 3.2.1.1 Layout of
 \<mtext\>](#ref-for-dfn-mathitalicscorrectioninfo-1 "§ 3.2.1.1 Layout of <mtext>")
- [§ 5.3.2 Algorithms for glyph
 stretching](#ref-for-dfn-mathitalicscorrectioninfo-2 "§ 5.3.2 Algorithms for glyph stretching")
 [(2)](#ref-for-dfn-mathitalicscorrectioninfo-3 "Reference 2")

[Permalink](#dfn-mathtopaccentattachment)

**Referenced in:**

- [§ 3.2.1.1 Layout of
 \<mtext\>](#ref-for-dfn-mathtopaccentattachment-1 "§ 3.2.1.1 Layout of <mtext>")

[Permalink](#dfn-omin)

**Referenced in:**

- [§ 5.3.1 The GlyphAssembly
 table](#ref-for-dfn-omin-1 "§ 5.3.1 The GlyphAssembly table")
 [(2)](#ref-for-dfn-omin-2 "Reference 2")
 [(3)](#ref-for-dfn-omin-3 "Reference 3")
 [(4)](#ref-for-dfn-omin-4 "Reference 4")

[Permalink](#dfn-next)

**Referenced in:**

- [§ 5.3.1 The GlyphAssembly
 table](#ref-for-dfn-next-1 "§ 5.3.1 The GlyphAssembly table")
 [(2)](#ref-for-dfn-next-2 "Reference 2")
 [(3)](#ref-for-dfn-next-3 "Reference 3")

[Permalink](#dfn-nnonext)

**Referenced in:**

- [§ 5.3.1 The GlyphAssembly
 table](#ref-for-dfn-nnonext-1 "§ 5.3.1 The GlyphAssembly table")
 [(2)](#ref-for-dfn-nnonext-2 "Reference 2")

[Permalink](#dfn-sext)

**Referenced in:**

- [§ 5.3.1 The GlyphAssembly
 table](#ref-for-dfn-sext-1 "§ 5.3.1 The GlyphAssembly table")
 [(2)](#ref-for-dfn-sext-2 "Reference 2")

[Permalink](#dfn-snonext)

**Referenced in:**

- [§ 5.3.1 The GlyphAssembly
 table](#ref-for-dfn-snonext-1 "§ 5.3.1 The GlyphAssembly table")
 [(2)](#ref-for-dfn-snonext-2 "Reference 2")

[Permalink](#dfn-sext-nonoverlapping)

**Referenced in:**

- [§ 5.3.1 The GlyphAssembly
 table](#ref-for-dfn-sext-nonoverlapping-1 "§ 5.3.1 The GlyphAssembly table")
 [(2)](#ref-for-dfn-sext-nonoverlapping-2 "Reference 2")

[Permalink](#dfn-assemblyglyphcount)

**Referenced in:**

- [§ 5.3.1 The GlyphAssembly
 table](#ref-for-dfn-assemblyglyphcount-1 "§ 5.3.1 The GlyphAssembly table")
 [(2)](#ref-for-dfn-assemblyglyphcount-2 "Reference 2")
 [(3)](#ref-for-dfn-assemblyglyphcount-3 "Reference 3")

[Permalink](#dfn-assembysize)

**Referenced in:**

- [§ 5.3.1 The GlyphAssembly
 table](#ref-for-dfn-assembysize-1 "§ 5.3.1 The GlyphAssembly table")
 [(2)](#ref-for-dfn-assembysize-2 "Reference 2")
 [(3)](#ref-for-dfn-assembysize-3 "Reference 3")

[Permalink](#dfn-rmin)

**Referenced in:**

- [§ 5.3.1 The GlyphAssembly
 table](#ref-for-dfn-rmin-1 "§ 5.3.1 The GlyphAssembly table")
 [(2)](#ref-for-dfn-rmin-2 "Reference 2")
 [(3)](#ref-for-dfn-rmin-3 "Reference 3")
 [(4)](#ref-for-dfn-rmin-4 "Reference 4")
 [(5)](#ref-for-dfn-rmin-5 "Reference 5")
 [(6)](#ref-for-dfn-rmin-6 "Reference 6")
 [(7)](#ref-for-dfn-rmin-7 "Reference 7")
- [§ E. Security
 Considerations](#ref-for-dfn-rmin-8 "§ E. Security Considerations")

[Permalink](#dfn-omax-theorical)

**Referenced in:**

- [§ 5.3.1 The GlyphAssembly
 table](#ref-for-dfn-omax-theorical-1 "§ 5.3.1 The GlyphAssembly table")

[Permalink](#dfn-omax)

**Referenced in:**

- [§ 5.3.1 The GlyphAssembly
 table](#ref-for-dfn-omax-1 "§ 5.3.1 The GlyphAssembly table")
 [(2)](#ref-for-dfn-omax-2 "Reference 2")
 [(3)](#ref-for-dfn-omax-3 "Reference 3")
 [(4)](#ref-for-dfn-omax-4 "Reference 4")

[Permalink](#dfn-glyph-assembly-stretch-size)

**Referenced in:**

- [§ 5.3.1 The GlyphAssembly
 table](#ref-for-dfn-glyph-assembly-stretch-size-1 "§ 5.3.1 The GlyphAssembly table")
 [(2)](#ref-for-dfn-glyph-assembly-stretch-size-2 "Reference 2")

[Permalink](#dfn-glyph-assembly-width)

**Referenced in:**

- [§ 5.3.2 Algorithms for glyph
 stretching](#ref-for-dfn-glyph-assembly-width-1 "§ 5.3.2 Algorithms for glyph stretching")
 [(2)](#ref-for-dfn-glyph-assembly-width-2 "Reference 2")

[Permalink](#dfn-glyph-assembly-ascent)

**Referenced in:**

- [§ 5.3.1 The GlyphAssembly
 table](#ref-for-dfn-glyph-assembly-ascent-1 "§ 5.3.1 The GlyphAssembly table")
- [§ 5.3.2 Algorithms for glyph
 stretching](#ref-for-dfn-glyph-assembly-ascent-2 "§ 5.3.2 Algorithms for glyph stretching")

[Permalink](#dfn-glyph-assembly-descent)

**Referenced in:**

- [§ 5.3.1 The GlyphAssembly
 table](#ref-for-dfn-glyph-assembly-descent-1 "§ 5.3.1 The GlyphAssembly table")
- [§ 5.3.2 Algorithms for glyph
 stretching](#ref-for-dfn-glyph-assembly-descent-2 "§ 5.3.2 Algorithms for glyph stretching")

[Permalink](#dfn-glyph-assembly-height)

**Referenced in:**

- [§ 5.3.2 Algorithms for glyph
 stretching](#ref-for-dfn-glyph-assembly-height-1 "§ 5.3.2 Algorithms for glyph stretching")

[Permalink](#dfn-shaping-of-the-glyph-assembly)

**Referenced in:**

- [§ 5.3.2 Algorithms for glyph
 stretching](#ref-for-dfn-shaping-of-the-glyph-assembly-1 "§ 5.3.2 Algorithms for glyph stretching")
- [§ E. Security
 Considerations](#ref-for-dfn-shaping-of-the-glyph-assembly-2 "§ E. Security Considerations")

[Permalink](#dfn-preferred-inline-size-of-a-glyph-stretched-along-the-block-axis)

**Referenced in:**

- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-preferred-inline-size-of-a-glyph-stretched-along-the-block-axis-1 "§ 3.2.4.3 Layout of operators")
 [(2)](#ref-for-dfn-preferred-inline-size-of-a-glyph-stretched-along-the-block-axis-2 "Reference 2")
- [§ 3.3.3.2 Square
 root](#ref-for-dfn-preferred-inline-size-of-a-glyph-stretched-along-the-block-axis-3 "§ 3.3.3.2 Square root")
- [§ 5.3.2 Algorithms for glyph
 stretching](#ref-for-dfn-preferred-inline-size-of-a-glyph-stretched-along-the-block-axis-4 "§ 5.3.2 Algorithms for glyph stretching")

[Permalink](#dfn-shape-a-stretchy-glyph)

**Referenced in:**

- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-shape-a-stretchy-glyph-1 "§ 3.2.4.3 Layout of operators")
 [(2)](#ref-for-dfn-shape-a-stretchy-glyph-2 "Reference 2")
 [(3)](#ref-for-dfn-shape-a-stretchy-glyph-3 "Reference 3")
 [(4)](#ref-for-dfn-shape-a-stretchy-glyph-4 "Reference 4")
 [(5)](#ref-for-dfn-shape-a-stretchy-glyph-5 "Reference 5")
 [(6)](#ref-for-dfn-shape-a-stretchy-glyph-6 "Reference 6")
 [(7)](#ref-for-dfn-shape-a-stretchy-glyph-7 "Reference 7")
 [(8)](#ref-for-dfn-shape-a-stretchy-glyph-8 "Reference 8")
 [(9)](#ref-for-dfn-shape-a-stretchy-glyph-9 "Reference 9")
 [(10)](#ref-for-dfn-shape-a-stretchy-glyph-10 "Reference 10")
- [§ 3.3.3.1 Radical
 symbol](#ref-for-dfn-shape-a-stretchy-glyph-11 "§ 3.3.3.1 Radical symbol")

[Permalink](#dfn-get-a-glyph)

**Referenced in:**

- [§ 3.2.4.3 Layout of
 operators](#ref-for-dfn-get-a-glyph-1 "§ 3.2.4.3 Layout of operators")
 [(2)](#ref-for-dfn-get-a-glyph-2 "Reference 2")
- [§ 3.3.3.1 Radical
 symbol](#ref-for-dfn-get-a-glyph-3 "§ 3.3.3.1 Radical symbol")

[Permalink](#dfn-user-agent-stylesheet)

**Referenced in:**

- [§ 2.1.1 The Top-Level \<math\>
 Element](#ref-for-dfn-user-agent-stylesheet-1 "§ 2.1.1 The Top-Level <math> Element")
 [(2)](#ref-for-dfn-user-agent-stylesheet-2 "Reference 2")
- [§ 2.1.4 Attributes common to HTML and MathML
 elements](#ref-for-dfn-user-agent-stylesheet-3 "§ 2.1.4 Attributes common to HTML and MathML elements")
- [§ 3.2.2 Identifier
 \<mi\>](#ref-for-dfn-user-agent-stylesheet-4 "§ 3.2.2 Identifier <mi>")
- [§ 3.3.2 Fractions
 \<mfrac\>](#ref-for-dfn-user-agent-stylesheet-5 "§ 3.3.2 Fractions <mfrac>")
- [§ 3.3.3 Radicals \<msqrt\>,
 \<mroot\>](#ref-for-dfn-user-agent-stylesheet-6 "§ 3.3.3 Radicals <msqrt>, <mroot>")
- [§ 3.3.5 Error Message
 \<merror\>](#ref-for-dfn-user-agent-stylesheet-7 "§ 3.3.5 Error Message <merror>")
- [§ 3.3.7 Making Sub-Expressions Invisible
 \<mphantom\>](#ref-for-dfn-user-agent-stylesheet-8 "§ 3.3.7 Making Sub-Expressions Invisible <mphantom>")
- [§ 3.5.1 Table or Matrix
 \<mtable\>](#ref-for-dfn-user-agent-stylesheet-9 "§ 3.5.1 Table or Matrix <mtable>")
- [§ 3.5.2 Row in Table or Matrix
 \<mtr\>](#ref-for-dfn-user-agent-stylesheet-10 "§ 3.5.2 Row in Table or Matrix <mtr>")
- [§ 3.5.3 Entry in Table or Matrix
 \<mtd\>](#ref-for-dfn-user-agent-stylesheet-11 "§ 3.5.3 Entry in Table or Matrix <mtd>")
- [§ 3.7 Enlivening
 Expressions](#ref-for-dfn-user-agent-stylesheet-12 "§ 3.7 Enlivening Expressions")
- [§ 3.8 Semantics and
 Presentation](#ref-for-dfn-user-agent-stylesheet-13 "§ 3.8 Semantics and Presentation")
- [§ 4.3 The math-style
 property](#ref-for-dfn-user-agent-stylesheet-14 "§ 4.3 The math-style property")
- [§ 4.4 The math-shift
 property](#ref-for-dfn-user-agent-stylesheet-15 "§ 4.4 The math-shift property")
- [§ 4.5 The math-depth
 property](#ref-for-dfn-user-agent-stylesheet-16 "§ 4.5 The math-depth property")

[Permalink](#dfn-algorithm-to-set-the-properties-of-an-operator-from-its-category)

**Referenced in:**

- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-algorithm-to-set-the-properties-of-an-operator-from-its-category-1 "§ 3.2.4.2 Dictionary-based attributes")

[Permalink](#dfn-algorithm-to-determine-the-category-of-an-operator)

**Referenced in:**

- [§ 3.2.4.2 Dictionary-based
 attributes](#ref-for-dfn-algorithm-to-determine-the-category-of-an-operator-1 "§ 3.2.4.2 Dictionary-based attributes")
 [(2)](#ref-for-dfn-algorithm-to-determine-the-category-of-an-operator-2 "Reference 2")

[Permalink](#dfn-intrinsic-stretch-axis)

**Referenced in:**

- [§ 3.2.4.1 Embellished
 operators](#ref-for-dfn-intrinsic-stretch-axis-1 "§ 3.2.4.1 Embellished operators")

::: header-wrapper
## H. References

::: header-wrapper
### H.1 Normative references

\[BIDI\]
: [Unicode Bidirectional
 Algorithm](https://www.unicode.org/reports/tr9/tr9-52.html). Manish
 Goregaokar मनीष गोरेगांवकर; Robin Leroy. Unicode Consortium. 1
 September 2026. Unicode Standard Annex #9. URL:
 <https://www.unicode.org/reports/tr9/tr9-52.html>

\[css-align-3\]
: [CSS Box Alignment Module Level
 3](https://www.w3.org/TR/css-align-3/). Elika Etemad; Tab Atkins Jr.
 W3C. 30 January 2026. W3C Working Draft. URL:
 <https://www.w3.org/TR/css-align-3/>

\[css-backgrounds-3\]
: [CSS Backgrounds and Borders Module Level
 3](https://www.w3.org/TR/css-backgrounds-3/). Elika Etemad; Brad
 Kemper. W3C. 11 March 2024. CRD. URL:
 <https://www.w3.org/TR/css-backgrounds-3/>

\[css-box-4\]
: [CSS Box Model Module Level 4](https://www.w3.org/TR/css-box-4/).
 Elika Etemad. W3C. 4 August 2024. W3C Working Draft. URL:
 <https://www.w3.org/TR/css-box-4/>

\[CSS-CASCADE-4\]
: [CSS Cascading and Inheritance Level
 4](https://www.w3.org/TR/css-cascade-4/). Elika Etemad; Tab Atkins
 Jr. W3C. 13 January 2022. W3C Candidate Recommendation. URL:
 <https://www.w3.org/TR/css-cascade-4/>

\[css-color-4\]
: [CSS Color Module Level 4](https://www.w3.org/TR/css-color-4/). Tab
 Atkins Jr.; Chris Lilley; Lea Verou. W3C. 30 September 2026. CRD.
 URL: <https://www.w3.org/TR/css-color-4/>

\[CSS-DISPLAY-3\]
: [CSS Display Module Level 3](https://www.w3.org/TR/css-display-3/).
 Tab Atkins Jr.; Elika Etemad. W3C. 5 June 2026. CRD. URL:
 <https://www.w3.org/TR/css-display-3/>

\[CSS-FONTS-4\]
: [CSS Fonts Module Level 4](https://www.w3.org/TR/css-fonts-4/).
 Chris Lilley. W3C. 13 September 2026. W3C Working Draft. URL:
 <https://www.w3.org/TR/css-fonts-4/>

\[CSS-POSITION-3\]
: [CSS Positioned Layout Module Level
 3](https://www.w3.org/TR/css-position-3/). Elika Etemad; Tab Atkins
 Jr. W3C. 7 October 2025. W3C Working Draft. URL:
 <https://www.w3.org/TR/css-position-3/>

\[css-pseudo-4\]
: [CSS Pseudo-Elements Module Level
 4](https://www.w3.org/TR/css-pseudo-4/). Elika Etemad; Alan Stearns.
 W3C. 27 June 2025. W3C Working Draft. URL:
 <https://www.w3.org/TR/css-pseudo-4/>

\[css-sizing-3\]
: [CSS Box Sizing Module Level
 3](https://www.w3.org/TR/css-sizing-3/). Tab Atkins Jr.; Elika
 Etemad. W3C. 4 September 2026. W3C Working Draft. URL:
 <https://www.w3.org/TR/css-sizing-3/>

\[css-text-3\]
: [CSS Text Module Level 3](https://www.w3.org/TR/css-text-3/). Elika
 Etemad; Koji Ishii; Florian Rivoal. W3C. 14 August 2026. CRD. URL:
 <https://www.w3.org/TR/css-text-3/>

\[CSS-TEXT-4\]
: [CSS Text Module Level 4](https://www.w3.org/TR/css-text-4/). Elika
 Etemad; Koji Ishii; Alan Stearns; Florian Rivoal. W3C. 14
 August 2026. W3C Working Draft. URL:
 <https://www.w3.org/TR/css-text-4/>

\[CSS-VALUES-4\]
: [CSS Values and Units Module Level
 4](https://www.w3.org/TR/css-values-4/). Tab Atkins Jr.; Elika
 Etemad. W3C. 12 March 2024. W3C Working Draft. URL:
 <https://www.w3.org/TR/css-values-4/>

\[CSS-WRITING-MODES-4\]
: [CSS Writing Modes Level
 4](https://www.w3.org/TR/css-writing-modes-4/). Elika Etemad; Koji
 Ishii. W3C. 30 July 2019. W3C Candidate Recommendation. URL:
 <https://www.w3.org/TR/css-writing-modes-4/>

\[CSS2\]
: [Cascading Style Sheets Level 2 Revision 1 (CSS 2.1)
 Specification](https://www.w3.org/TR/CSS2/). Bert Bos; Tantek Çelik;
 Ian Hickson; Håkon Wium Lie. W3C. 7 June 2011. W3C Recommendation.
 URL: <https://www.w3.org/TR/CSS2/>

\[CSSOM\]
: [CSS Object Model (CSSOM)](https://www.w3.org/TR/cssom-1/). Daniel
 Glazman; Emilio Cobos Álvarez. W3C. 26 August 2021. W3C Working
 Draft. URL: <https://www.w3.org/TR/cssom-1/>

\[DOM\]
: [DOM Standard](https://dom.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://dom.spec.whatwg.org/>

\[HTML\]
: [HTML Standard](https://html.spec.whatwg.org/multipage/). Anne van
 Kesteren; Domenic Denicola; Dominic Farolino; Ian Hickson; Philip
 Jägenstedt; Simon Pieters. WHATWG. Living Standard. URL:
 <https://html.spec.whatwg.org/multipage/>

\[INFRA\]
: [Infra Standard](https://infra.spec.whatwg.org/). Anne van Kesteren;
 Domenic Denicola. WHATWG. Living Standard. URL:
 <https://infra.spec.whatwg.org/>

\[OPEN-FONT-FORMAT\]
: [Information technology --- Coding of audio-visual objects --- Part
 22: Open Font Format](https://www.iso.org/standard/74461.html).
 ISO/IEC. January 2019. Published. URL:
 <https://www.iso.org/standard/74461.html>

\[RFC2119\]
: [Key words for use in RFCs to Indicate Requirement
 Levels](https://www.rfc-editor.org/info/rfc2119/). S. Bradner. IETF.
 March 1997. Best Current Practice. URL:
 <https://www.rfc-editor.org/info/rfc2119/>

\[SELECT\]
: [Selectors Level 3](https://www.w3.org/TR/selectors-3/). Tantek
 Çelik; Elika Etemad; Daniel Glazman; Ian Hickson; Peter Linss; John
 Williams. W3C. 6 November 2018. W3C Recommendation. URL:
 <https://www.w3.org/TR/selectors-3/>

\[SVG\]
: [Scalable Vector Graphics (SVG) 1.0
 Specification](https://www.w3.org/TR/SVG/). Jon Ferraiolo. W3C. 4
 September 2001. W3C Recommendation. URL:
 <https://www.w3.org/TR/SVG/>

\[URL\]
: [URL Standard](https://url.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://url.spec.whatwg.org/>

\[webidl\]
: [Web IDL Standard](https://webidl.spec.whatwg.org/). Edgar Chen;
 Timothy Gu. WHATWG. Living Standard. URL:
 <https://webidl.spec.whatwg.org/>

::: header-wrapper
### H.2 Informative references

\[CSS-LAYOUT-API-1\]
: [CSS Layout API Level 1](https://www.w3.org/TR/css-layout-api-1/).
 Greg Whitworth; Ian Kilpatrick; Tab Atkins Jr.; Shane Stephens;
 Robert O\'Callahan; Rossen Atanassov. W3C. 12 April 2018. FPWD. URL:
 <https://www.w3.org/TR/css-layout-api-1/>

\[css-text-decor-4\]
: [CSS Text Decoration Module Level
 4](https://www.w3.org/TR/css-text-decor-4/). Elika Etemad; Koji
 Ishii. W3C. 4 May 2022. W3C Working Draft. URL:
 <https://www.w3.org/TR/css-text-decor-4/>

\[cssom-view\]
: [CSSOM View Module](https://www.w3.org/TR/cssom-view-1/). Simon
 Fraser; Emilio Cobos Álvarez. W3C. 16 September 2025. W3C Working
 Draft. URL: <https://www.w3.org/TR/cssom-view-1/>

\[HOUDINI\]
: [CSS-TAG Houdini Editor Drafts](https://drafts.css-houdini.org/).
 URL: <https://drafts.css-houdini.org/>

\[MATHML3\]
: [Mathematical Markup Language (MathML) Version 3.0 2nd
 Edition](https://www.w3.org/TR/MathML3/). David Carlisle; Patrick D
 F Ion; Robert R Miner. W3C. 10 April 2014. W3C Recommendation. URL:
 <https://www.w3.org/TR/MathML3/>

\[MATHML4\]
: [Mathematical Markup Language (MathML) Version
 4.0](https://w3c.github.io/mathml/). David Carlisle et al.W3C
 Editor\'s Draft. URL: <https://w3c.github.io/mathml/>

\[OPEN-TYPE-MATH-ILLUMINATED\]
: [OpenType Math
 Illuminated](https://www.tug.org/TUGboat/tb30-1/tb94vieth.pdf).
 Ulrik Vieth. 2009. URL:
 <https://www.tug.org/TUGboat/tb30-1/tb94vieth.pdf>

\[OPEN-TYPE-MATH-IN-HARFBUZZ\]
: [OpenType MATH in
 HarfBuzz](https://frederic-wang.fr/2016/04/16/opentype-math-in-harfbuzz/).
 Frédéric Wang. URL:
 <https://frederic-wang.fr/2016/04/16/opentype-math-in-harfbuzz/>

\[TEXBOOK\]
: The TeXBook. Knuth, Donald E. Addison-Wesley Professional. 1984.

\[UNICODE\]
: [The Unicode Standard](https://www.unicode.org/versions/latest/).
 Unicode Consortium. URL: <https://www.unicode.org/versions/latest/>

\[xml-entity-names\]
: [XML Entity Definitions for Characters (3rd
 Edition)](https://www.w3.org/TR/xml-entity-names/). Patrick D F Ion;
 David Carlisle. W3C. 7 March 2023. W3C Recommendation. URL:
 <https://www.w3.org/TR/xml-entity-names/>

[[↑]](#title)
