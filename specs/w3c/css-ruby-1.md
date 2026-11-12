## 1. Introduction

### 1.1. What is ruby?

*This subsection is not normative.*

[Ruby] is the
commonly-used name for a run of text that appears alongside another run
of text (referred to as the "base") and serves as an annotation or a
pronunciation guide associated with that run of text.

![A run of Japanese text with phonetic ruby annotations indicating the
pronunciation of each
ideograph.](images/ruby-context.png){a
height="64" width="324"}

The following figures show two examples of Ruby, a simple case and one
with more complicated structure.

In this example, a single annotation
is used to annotate a base text consisting of multiple characters.

![Example of ruby applied on top of a Japanese
expression](images/licence.png){height="66" width="260"}

Example of ruby used in Japanese (simple case)

In Japanese typography, this case is sometimes called taigo ruby
(Japanese: [対語ルビ]{lang="ja"}, i.e. per-word ruby) or group-ruby,
because the annotation as a whole is associated with multi-character
word (as a whole).

In this second example, two levels of
annotations are attached to the base text: the hiragana characters on
top refer to the pronunciation of each of the base kanji characters,
while the words "Keio" and "University" on the bottom are give the
English translation.

![Example showing complex ruby with annotation text over and under the
base characters](images/ruby-univ.gif){height="108" width="277"}

Complex ruby with annotation text over and under the base characters

Notice that to reflect the correct association of hiragana characters
and their corresponding Kanji base characters, the spacing within the
base-level text is adjusted. (This happens around the fourth Kanji
character in the figure above, which has a three-character phonetic
gloss.) To avoid variable spacing of the base text in the example above,
the hiragana annotations can be styled as a [merged
annotation](#merged-annotation), which will look more like the group-ruby example
earlier. However because the base-annotation
[pairings](#pairing) are recorded in
the ruby structure, if the text breaks across lines, the annotation
characters will stay correctly paired with their respective base
characters.

In HTML, ruby structure and markup to represent it is described in the
Ruby Markup Extension specification. This module describes the CSS
rendering model and formatting controls relevant to ruby layout of such
markup.

A more in-depth introduction to [Ruby](#ruby) and its formatting can be found in the "What is Ruby"
article
[\[QA-RUBY\]](#biblio-qa-ruby "What is ruby?").
Extensive information about the main ways [ruby] has
traditionally been formatted in Japanese can be found in JIS X-4051
[\[JIS4051\]](#biblio-jis4051 "Formatting rules for Japanese documents (日本語文書の組版方法).")
(in Japanese) and in ["Ruby and Emphasis
Dots"](https://www.w3.org/TR/jlreq/#ruby_and_emphasis_dots) in
Requirements for Japanese Text Layout
[\[JLREQ\]](#biblio-jlreq "Requirements for Japanese Text Layout 日本語組版処理の要件(日本語版)")
(in English and Japanese); Rules for Simple Placement of Japanese Ruby
[\[SIMPLE-RUBY\]](#biblio-simple-ruby "Rules for Simple Placement of Japanese Ruby")
also describes (in English) one possible approach for Japanese ruby
formatting. ["Interlinear
annotations"](https://www.w3.org/TR/clreq/#interlinear_annotations) in
Requirements for Chinese Text Layout
[\[CLREQ\]](#biblio-clreq "Requirements for Chinese Text Layout - 中文排版需求")
describes the related practices for Chinese typography (in Chinese and
English).

### 1.2. Module interactions

This module extends the inline box model of CSS Level 2
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
to support ruby.

None of the properties in this module apply to the
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line) or
[::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter) pseudo-elements; however
[ruby-position](#propdef-ruby-position) can inherit through
[::first-line] to affect ruby
annotations on the first line.

### 1.3. Value Definitions

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
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords) keywords as their property value. For readability they
have not been repeated explicitly.

### 1.4. Diagram conventions

*This subsection is not normative.*

Many typographical conventions in East Asian typography depend on
whether the character rendered is wide (CJK) or narrow (non-CJK). There
are a number of illustrations in this document for which the following
legend is used:

![Symbolic wide-cell glyph representation](images/fullwidth.gif){height="39" width="39"}
: Wide-cell glyph (e.g. Han) that is the `n`th character in
 the text sequence. They are typically sized to 50% when used as
 annotations.

![Symbolic narrow-cell glyph representation](images/halfwidth.gif){height="39" width="19"}
: Narrow-cell glyph (e.g. Roman) which is the `n`th glyph
 in the text sequence.

The orientation which the above symbols assume in the diagrams
corresponds to the orientation that the glyphs they represent are
intended to assume when rendered by the user agent. Spacing between
these characters in the diagrams is incidental, unless intentionally
changed to make a point.

## 2. Ruby Box Model

The CSS ruby model is based on the [W3C HTML5 Ruby
Markup](https://www.w3.org/TR/html5/text-level-semantics.html#the-ruby-element)
model and the [XHTML Ruby Annotation
Recommendation](https://www.w3.org/TR/ruby/)
[\[RUBY\]](#biblio-ruby "Ruby Annotation"). In this
model, a ruby structure consists of one or more [ruby
base](#ruby-base-box) elements
representing the base (annotated) text, associated with one or more
levels of [ruby
annotation](#ruby-annotation-box) elements representing the annotations. The structure of
ruby is similar to that of a table: there are "rows" (the [base text
level](#base-level), each
[annotation level](#annotation-level)) and "[columns](#ruby-columns)" (each [ruby base] and its
corresponding [ruby annotations]).

![The Japanese compound word "[上手]{lang="ja"}" annotated with its
pronunciation "[じょうず]{lang="ja"}". Each syllable is associated
individually with its base
character.](images/ruby-boxes-simple.png){a
height="94" width="314"}

Sets of consecutive bases and their consecutive annotations are grouped
together into [ruby segments](#ruby-segments). Within a [ruby segment], a
[ruby annotation](#ruby-annotation-box) may span multiple [ruby
bases](#ruby-base-box).

![The Chinese city name "[旧金山]{lang="zh-Hans"}" annotated with its
pronunciation in Pinyin "[jiùjīnshān]{lang="zh-Latn-pinyin"}" and its
English name "San Francisco". Each Pinyin syllable is associated
individually with its base character, however the English name is
associated with the name as a
whole.](images/ruby-boxes-complex.png){a
height="128" width="350"}

 In HTML, a single `<ruby>` element may contain multiple
[ruby segments](#ruby-segments). (In the XHTML Ruby model, a single `<ruby>` element
can only contain one [ruby segment].)

### [2.1. ][ Ruby-specific [display](https://drafts.csswg.org/css-display-4/#propdef-display) Values]
For document languages (such as XML applications) that do not have
pre-defined ruby elements, authors must map document language elements
to ruby elements; this is done with the
[display](https://drafts.csswg.org/css-display-4/#propdef-display) property.

Name:

[display](https://drafts.csswg.org/css-display-4/#propdef-display)

[New values:](https://www.w3.org/TR/css-values/#value-defs)

ruby
[\|](https://drafts.csswg.org/css-values-4/#comb-one) ruby-base [\|] ruby-text
[\|] ruby-base-container [\|]
ruby-text-container

The following new
[display](https://drafts.csswg.org/css-display-4/#propdef-display) values assign ruby layout roles to
an arbitrary element:

[ruby]
: Specifies that an element generates a [ruby container
 box]. (Corresponds to
 HTML/XHTML `<ruby>` elements.)

[ruby-base]
: Specifies that an element generates a [ruby base box]. (Corresponds to
 HTML/XHTML `<rb>` elements.)

[ruby-text]
: Specifies that an element generates a [ruby annotation
 box].
 (Corresponds to HTML/XHTML `<rt>` elements.)

[ruby-base-container]
: Specifies that an element generates a [ruby base container
 box]. (Corresponds to
 XHTML `<rbc>` elements; generated as an anonymous box in HTML.)

[ruby-text-container]
: Specifies that an element generates a [ruby annotation container
 box].
 (Corresponds to HTML/XHTML `<rtc>` elements.)

Authors using a language (such as HTML) that supports dedicated ruby
markup should use that markup rather than styling arbitrary elements
(like `<span>`) with ruby
[display](https://drafts.csswg.org/css-display-4/#propdef-display) values. Using the correct markup
ensures that screen readers and non-CSS renderers can interpret the ruby
structures.

 [Replaced
elements](https://drafts.csswg.org/css-display-4/#replaced-element) with a
[display](https://drafts.csswg.org/css-display-4/#propdef-display) value of
[ruby-base](#valdef-display-ruby-base),
[ruby-text](#valdef-display-ruby-text),
[ruby-base-container](#valdef-display-ruby-base-container), and
[ruby-text-container](#valdef-display-ruby-text-container) are treated as [inline-level
boxes](https://drafts.csswg.org/css-display-4/#inline-level-box), as per [CSS Display 3 § 2.4 Layout-Internal Display
Types: the table-\* and ruby-\*
keywords](https://drafts.csswg.org/css-display-3/#layout-specific-display);
[replaced elements] with a
[display] value of
[ruby](#valdef-display-ruby) or [inline ruby] behave according to their
[outer display
type](https://drafts.csswg.org/css-display-4/#outer-display-type), as per [CSS Display 3 § 2.1 Outer Display Roles for
Flow Layout: the block, inline, and run-in
keywords](https://drafts.csswg.org/css-display-3/#outer-role). (See also
[§ 2.1.2 Non-Inline Ruby](#block-ruby).)

#### 2.1.1. The Ruby Formatting Context

[Ruby containers](#ruby-container) are non-atomic
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) boxes. Like regular [inline
boxes](https://drafts.csswg.org/css-display-4/#inline-box) (see [CSS Inline Layout 3 § 2 Inline Layout
Model](https://drafts.csswg.org/css-inline-3/#model)), they break across
lines, and their [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) is the nearest [block
container](https://drafts.csswg.org/css-display-4/#block-container) ancestor. And just as the contents of an [inline
box] participate in the same [inline formatting
context](https://drafts.csswg.org/css-display-4/#inline-formatting-context) that contains the [inline box]
itself, a [ruby container] and its base-level
contents participate in the same [inline formatting
context] that contains the [ruby
container] itself.

However [ruby containers](#ruby-container) also establish a [ruby formatting
context] that builds further structure around their segment of the
[inline formatting
context](https://drafts.csswg.org/css-display-4/#inline-formatting-context) in order to host their annotations. [Note: this
[formatting
context](https://drafts.csswg.org/css-display-4/#formatting-context) is *not* an [independent formatting
context](https://drafts.csswg.org/css-display-4/#independent-formatting-context).] [Ruby
bases](#ruby-base-box), [ruby
annotations](#ruby-annotation-box), [ruby base
containers](#ruby-base-container-box), and [ruby annotation
containers](#ruby-annotation-container-box) are [internal ruby boxes]: like [internal
table
elements](https://drafts.csswg.org/css-display-4/#internal-table-element), they have specific roles in ruby layout, and
participate in their [ruby container]'s [ruby
formatting
context](#ruby-formatting-context). In addition to their role in the [ruby formatting
context], [ruby
bases] simultaneously participate in the same
base-level [inline formatting
context] as the [ruby
container], while [ruby
annotations] participate in separate
annotation-level [inline formatting
contexts] established by the [ruby
container].

As with the contents of [inline
boxes](https://drafts.csswg.org/css-display-4/#inline-box), the [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) for the contents of a [ruby
container](#ruby-container)
(and all its [internal ruby
boxes](#internal-ruby-boxes)) is the [containing block]
of the [ruby container]. So floats, for
example, are trapped by the [ruby container]'s
[containing block], not any of the ruby box
types.

#### 2.1.2. Non-Inline Ruby

If an element has an [inner display
type](https://drafts.csswg.org/css-display-4/#inner-display-type) of
[ruby](#valdef-display-ruby) and an [outer display
type](https://drafts.csswg.org/css-display-4/#outer-display-type) other than
[inline](https://drafts.csswg.org/css-display-4/#valdef-display-inline), then it generates two boxes: a principal box of
the required [outer display type] type,
and an inline-level [ruby
container](#ruby-container).
All properties specified on the element apply to the principal box (and
if inheritable, inherit to the [ruby container
box]). This allows styling the element as a
block, while correctly maintaining the internal ruby structure.

 Absolute positioning or floating an element causes its
[display](https://drafts.csswg.org/css-display-4/#propdef-display) value to compute to a block-level
equivalent. (See
[\[CSS-DISPLAY-3\]](#biblio-css-display-3 "CSS Display Module Level 3")
or
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
section 9.7.) For the [internal ruby display
types](#internal-ruby-boxes), this causes their [display] value to compute to
[block](https://drafts.csswg.org/css-display-4/#valdef-display-block).

### 2.2. Anonymous Ruby Box Generation

The CSS model does not require that the document language include
elements that correspond to each of these components. Missing parts of
the structure are implied through the anonymous box generation rules
[similar to those used to normalize
tables](https://www.w3.org/TR/CSS2/tables.html#anonymous-boxes).
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")

1. [(#anon-gen-inlinize)**[Inlinify](https://drafts.csswg.org/css-display-4/#inlinify) block-level boxes:** Any
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) boxes directly contained by a [ruby
 container](#ruby-container), [ruby base
 container](#ruby-base-container-box), [ruby annotation
 container](#ruby-annotation-container-box), [ruby base
 box](#ruby-base-box), or
 [ruby annotation
 box](#ruby-annotation-box) are
 "[inlinified](https://drafts.csswg.org/css-display-4/#inlinify)" per
 [\[CSS-DISPLAY-3\]](#biblio-css-display-3 "CSS Display Module Level 3")),
 and their
 [display](https://drafts.csswg.org/css-display-4/#propdef-display) value computed accordingly, so
 that they contain only inline-level content. For example, the
 [display] property of an
 in-flow element with [display: block] parented by an element with [display:
 ruby-text] computes to
 [inline-block](https://drafts.csswg.org/css-display-4/#valdef-display-inline-block).]

2. [(#anon-gen-anon-ruby)**Generate anonymous ruby
 containers:** Any
 [consecutive](https://www.w3.org/TR/CSS2/tables.html#anonymous-boxes)
 sequence of improperly-contained [ruby base
 containers](#ruby-base-container-box), [ruby annotation
 containers](#ruby-annotation-container-box), [ruby
 bases](#ruby-base-box),
 and/or [ruby
 annotations](#ruby-annotation-box) (and any intervening [white
 space](https://drafts.csswg.org/css-text-4/#white-space)) is wrapped in an anonymous [ruby
 container](#ruby-container). For the purpose of this
 step:]
 - an improperly-contained [ruby
 base](#ruby-base-box) is
 one not parented by a [ruby base
 container](#ruby-base-container-box) or [ruby
 container](#ruby-container)
 - an improperly-contained [ruby
 annotation](#ruby-annotation-box) is one not parented by a [ruby annotation
 container](#ruby-annotation-container-box) or [ruby
 container](#ruby-container)
 - an improperly-contained [ruby base
 container](#ruby-base-container-box) or [ruby annotation
 container](#ruby-annotation-container-box) is one not parented by a [ruby
 container](#ruby-container)

3. [(#anon-gen-bare-inlines)**Wrap misparented
 inline-level content:** Any consecutive sequence of text and
 inline-level boxes directly parented by a [ruby
 container](#ruby-container) or [ruby base
 container](#ruby-base-container-box) is wrapped in an anonymous [ruby
 base](#ruby-base-box).
 Similarly, any consecutive sequence of text and inline-level boxes
 directly parented by a [ruby annotation
 container](#ruby-annotation-container-box) is wrapped in an anonymous [ruby
 annotation](#ruby-annotation-box). (For this purpose, misparented [internal table
 elements](https://drafts.csswg.org/css-display-4/#internal-table-element) are treated as [inline-level
 content](https://drafts.csswg.org/css-display-4/#inline-level) since, being parented by ruby boxes, they will be
 ultimately wrapped by an [inline-level]
 [table wrapper
 box](https://drafts.csswg.org/css-tables-3/#table-wrapper-box).)]

 However, if an anonymous box so constructed contains only [white
 space](https://drafts.csswg.org/css-text-4/#white-space), it is considered [intra-ruby white
 space] and is either discarded or preserved as described
 below.

4. [(#anon-gen-trim-space)**Trim leading/trailing white
 space:** Any [intra-ruby white
 space](#intra-ruby-white-space) that is not the sole
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) child of its parent and is the first or last
 [in-flow] child of a [ruby
 container](#ruby-container), [ruby annotation
 container](#ruby-annotation-container-box), or [ruby base
 container](#ruby-base-container-box) is removed, as if it had [display:
 none](https://drafts.csswg.org/css-display-4/#propdef-display)]

5. [(#anon-gen-discard-space)**Remove inter-level white
 space:** Any [intra-ruby white
 space](#intra-ruby-white-space) whose immediately adjacent
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) siblings match one of the patterns below is
 [inter-level white space] and is removed, as if it had [display:
 none](https://drafts.csswg.org/css-display-4/#propdef-display).]
 Previous box
 Next box
 any
 [ruby annotation
 container](#ruby-annotation-container-box)
 not [ruby
 annotation](#ruby-annotation-box)
 [ruby
 annotation](#ruby-annotation-box)

6. [(#anon-gen-interpret-space)**Interpret intra-level
 white space:** Any [intra-ruby white
 space](#intra-ruby-white-space) box whose immediately adjacent
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) siblings match one of the patterns below is
 assigned the box type and subtype defined in the table
 below:]
 Previous box
 Next box
 Box type
 Subtype
 [ruby base](#ruby-base-box)
 [ruby base](#ruby-base-box)
 [ruby base](#ruby-base-box)
 [inter-base white space]
 [ruby
 annotation](#ruby-annotation-box)
 [ruby
 annotation](#ruby-annotation-box)
 [ruby
 annotation](#ruby-annotation-box)
 [inter-annotation white space]
 [ruby
 annotation](#ruby-annotation-box) or [ruby annotation
 container](#ruby-annotation-container-box)
 [ruby base](#ruby-base-box) or [ruby base
 container](#ruby-base-container-box)
 [ruby base](#ruby-base-box)
 [inter-segment white space]
 [ruby base](#ruby-base-box) or [ruby base
 container](#ruby-base-container-box)
 [ruby base
 container](#ruby-base-container-box)
 [ruby base
 container](#ruby-base-container-box)
 [ruby base](#ruby-base-box) or [ruby base
 container](#ruby-base-container-box)
 The [intra-level white space] boxes defined above are
 treated specially for [pairing](#pairing) and layout. See below.

7. [(#anon-gen-unbreak)**Suppress line breaks:** Convert
 all forced line breaks inside [ruby
 annotations](#ruby-annotation-box) (regardless of
 [white-space](https://drafts.csswg.org/css-text-4/#propdef-white-space) value) as defined for
 collapsible segment breaks in [CSS Text Level 3 §
 4.1.2](https://www.w3.org/TR/css-text-3/#line-break-transform).]

 (#issue-f0987196) The goal of this is to simplify the
 layout model by suppressing any line breaks within ruby annotations.
 Alternatively we could try to define some kind of acceptable
 behavior for them.

8. [(#anon-gen-anon-containers)**Generate anonymous level
 containers:** Any consecutive sequence of [ruby
 bases](#ruby-base-box) and
 [inter-base white
 space](#inter-base-white-space) (and not [inter-segment white
 space](#inter-segment-white-space)) not parented by a [ruby base
 container](#ruby-base-container-box) is wrapped in an anonymous [ruby base
 container]. Similarly, any
 consecutive sequence of [ruby
 annotations](#ruby-annotation-box) and [inter-annotation white
 space](#inter-annotation-white-space) not parented by a [ruby annotation
 container](#ruby-annotation-container-box) is wrapped in an anonymous [ruby annotation
 container].]

Once all ruby layout structures are properly parented, the UA can start
to associate bases with their annotations.

 The UA is not required to create any of these anonymous
boxes (or the anonymous empty [intra-level white
space](#intra-level-white-space) boxes in [§ 2.3 Annotation Pairing](#ruby-pairing)) in
its internal structures, as long as
[pairing](#pairing) and layout
behaves as if they existed.

The following markup diagram
representing the various boxes shows where [intra-ruby white
space](#intra-ruby-white-space) is preserved or discarded:

```
<ruby>×<rbc>×<rb></rb>⬕<rb></rb>×</rbc>☒<rtc>×<rt></rt>⬔<rt></rt>×</rtc>◼<rbc>×<rb></rb>…</rtc>×</ruby>
```

where

- × represents [discarded leading/trailing white
 space](#anon-gen-trim-space)

- [x] represents [discarded inter-level white
 space](#anon-gen-discard-space)

- ⬕ represents [inter-base white
 space](#inter-base-white-space)

- ⬔ represents [inter-annotation white
 space](#inter-annotation-white-space)

- ◼ represents [inter-segment white
 space](#inter-segment-white-space)

### 2.3. Annotation Pairing

Annotation [pairing] is the process of associating [ruby
annotations](#ruby-annotation-box) with [ruby
bases](#ruby-base-box). Each
[ruby annotation] is associated with one
or more [ruby bases], and is said to
[span] those bases.
(A [ruby annotation] that
[spans](#span) multiple bases is called a
[spanning annotation].)

A [ruby base](#ruby-base-box)
can be associated with only one [ruby
annotation](#ruby-annotation-box) per [annotation
level](#annotation-level).
However, if there are multiple [annotation
levels], it can be associated with multiple
[ruby annotations].

Once [pairing](#pairing) is complete,
[ruby columns] are defined, each represented by a single
[ruby base](#ruby-base-box)
and one [ruby
annotation](#ruby-annotation-box) (possibly an empty, anonymous one) from each
[interlinear](#interlinear-annotations) [annotation
level](#annotation-level) in
its [ruby segment](#ruby-segments).

#### 2.3.1. Segment Pairing and Annotation Levels

A ruby structure is divided into [ruby segments], each consisting of a single
[ruby base
container](#ruby-base-container-box) followed by one or more [ruby annotation
containers](#ruby-annotation-container-box). Each [ruby annotation
container] in a [ruby
segment](#ruby-segments)
represents one [level] of annotation
for the base text: the first one represents the first level of
annotation, the second one represents the second level of annotation,
and so on. The [ruby base container]
represents the [base level]. The [ruby base
container] in each segment is thus
paired with each of the [ruby annotation
containers] in that segment.

In order to handle degenerate cases, some empty anonymous containers are
assumed:

- If the first child of a [ruby
 container](#ruby-container)
 is a [ruby annotation
 container](#ruby-annotation-container-box), an anonymous, empty [ruby base
 container](#ruby-base-container-box) is assumed to exist before it.
- Similarly, if the [ruby
 container](#ruby-container)
 contains consecutive [ruby base
 containers](#ruby-base-container-box), anonymous, empty [ruby annotation
 containers](#ruby-annotation-container-box) are assumed to exist between them.

[Inter-segment white
space](#inter-segment-white-space) is effectively a [ruby
segment](#ruby-segments) of its
own.

#### 2.3.2. Unit Pairing and Spanning Annotations

Within a [ruby segment](#ruby-segments), each [ruby
base](#ruby-base-box) in the
[ruby base
container](#ruby-base-container-box) is paired with one [ruby
annotation](#ruby-annotation-box) from each [ruby annotation
container](#ruby-annotation-container-box) in its [ruby segment].

If a [ruby annotation
container](#ruby-annotation-container-box) contains only a single, anonymous [ruby
annotation](#ruby-annotation-box), then that [ruby
annotation] is paired with (i.e.
[spans](#span) across) all of the [ruby
bases](#ruby-base-box) in its
[ruby segment](#ruby-segments).

Otherwise, each [ruby
annotation](#ruby-annotation-box) is paired, in document order, with the corresponding
[ruby base](#ruby-base-box) in
that segment. If there are not enough [ruby
annotations] in a [ruby annotation
container](#ruby-annotation-container-box), the remaining [ruby bases]
are paired with anonymous empty annotations inserted at the end of the
[ruby annotation container].
If there are not enough [ruby bases], any
remaining [ruby annotations] pair with
empty, anonymous bases inserted at the end of the [ruby base
container](#ruby-base-container-box).

If an implementation supports ruby markup with explicit spanning (e.g.
XHTML Complex Ruby Annotations), it must adjust the
[pairing](#pairing) rules to pair
[spanning
annotations](#spanning-annotation) to their bases appropriately.

[Intra-level white
space](#intra-level-white-space) does not participate in standard annotation
[pairing](#pairing). However, if the
immediately-adjacent [ruby
bases](#ruby-base-box) or
[ruby annotations](#ruby-annotation-box) are paired

- with two [ruby bases](#ruby-base-box) or
 [annotations](#ruby-annotation-box) that surround corresponding [intra-level white
 space](#intra-level-white-space) in another level, then the so-corresponding
 [intra-level white space] boxes are
 also paired.
- with a single spanning [ruby
 annotation](#ruby-annotation-box), then the [intra-level white
 space](#intra-level-white-space) is also paired to that [ruby
 annotation]
- with two [ruby bases](#ruby-base-box) or
 [annotations](#ruby-annotation-box) with no intervening [intra-level white
 space](#intra-level-white-space), then the [intra-level white
 space] box pairs with an anonymous
 empty [intra-level white space] box
 assumed to exist between them.

The following diagram shows the
pairing of regular [base](#ruby-base-box) and
[annotation](#ruby-annotation-box) boxes as well as the pairing of [intra-ruby white
space](#intra-ruby-white-space) (represented as `ws`):

``` highlight
|[ s p a n n i n g a n n o t a t i o n ]|
|[ a1 ]|[ws]|[ a2 ]|[ ]|[ a3 ]|[ws]|[ a4 ]|
|[ b1 ]|[ws]|[ b2 ]|[ws]|[ b3 ]|[ ]|[ b4 ]|
```

Blue brackets (`[ ]`) represent [base
boxes](#ruby-base-box), red
brackets (`[ ]`) represent [annotation
boxes](#ruby-annotation-box), gray bars (`|`) represent the limits
of [ruby columns](#ruby-columns), `[ws]` represents [intra-ruby white
space](#intra-ruby-white-space), and `` represents an empty anonymous base
or annotation automatically generated to pair with [intra-ruby white
space] in another level. [Ruby
containers](#ruby-container),
[base
containers](#ruby-base-container-box), and [annotation
containers](#ruby-annotation-container-box) are omitted.

### [2.4. ][ Hiding Annotations: [visibility: collapse](https://drafts.csswg.org/css-display-4/#propdef-visibility) and auto-hidden ruby]
A [ruby annotation](#ruby-annotation-box) whose
[visibility](https://drafts.csswg.org/css-display-4/#propdef-visibility) is
[collapse](https://drafts.csswg.org/css-display-4/#valdef-visibility-collapse) is a [hidden annotation].
Additionally, if a [ruby annotation] has
the exact same text content as its base, it is automatically
[hidden](#hidden-annotation)
([auto-hidden]) by the UA.

[Hiding](#hidden-annotation) a [ruby
annotation](#ruby-annotation-box) does not affect annotation
[pairing](#pairing). However the
[hidden annotation] is not visible, and it
has no impact on layout other than to separate adjacent sequences of
[ruby annotation boxes] within its
level, as if they belonged to separate segments and the [hidden
annotation]'s base were not a [ruby
base](#ruby-base-box) but an
intervening inline.

Auto-hiding allows correct inlined
display of annotations for Japanese words that are a mix of kanji and
hiragana. For example, the word [振り仮名]{lang="ja"} should be inlined
as

振り仮名(ふりがな)

and therefore marked up as

``` highlight
<ruby>
 <rb>振</rb><rb>り</rb><rb>仮</rb><rb>名</rb>
 <rp>(</rp><rt>ふ</rt><rt>り</rt><rt>が</rt><rt>な</rt><rp>)</rp>
</ruby>
```

However, when displayed as ruby, the "り" should be hidden

![Hiragana annotations for 振り仮名 appear, each pronunciation above its
kanji base character.](images/furigana-separate.png){height="73"
width="160"}

Hiragana ruby for [振り仮名]{lang="ja"}. Notice there is no hiragana
annotation above [り]{lang="ja"}, since it is already in hiragana.

The Japanese word in this example is
composed of three kanji characters, one of which is taught in first
grade, while the other two are more advanced. (Characters colored to
show base-pair correspondences.)

``` highlight
<ruby><rb>昆<rb>虫<rb>記<rt>こん<rt class=easy>ちゅう<rt>き</ruby>
```

![Fully annotated three-character
word](images/ruby-pairing-full.png){a
height="55" width="122"}

Although some readers might need pronunciation guidance on all three
characters, for other audiences it is more appropriate to hide the
annotation on the easier character. Applying [visibility:
collapse](https://drafts.csswg.org/css-display-4/#propdef-visibility) enables this hiding:

![Middle annotation as [visibility:
collapse](https://drafts.csswg.org/css-display-4/#propdef-visibility)](images/ruby-pairing-collapse.png){a
height="53" width="105"}

The [hiding](#hidden-annotation) behavior of [visibility:
collapse](https://drafts.csswg.org/css-display-4/#propdef-visibility) differs from [visibility:
hidden]---​which makes the annotation
invisible, but does not remove its impact on layout:

![Middle annotation as [visibility:
hidden](https://drafts.csswg.org/css-display-4/#propdef-visibility)](images/ruby-pairing-invisible.png){a
height="55" width="122"}

It also differs from [display:
none](https://drafts.csswg.org/css-display-4/#propdef-display) because [visibility:
collapse](https://drafts.csswg.org/css-display-4/#propdef-visibility) preserves pairing relationships, whereas
[display: none] removes the box from
the tree entirely, disturbing the pairing of any annotations after it:

![Middle annotation as [display:
none](https://drafts.csswg.org/css-display-4/#propdef-display)](images/ruby-pairing-discard.png){a
height="55" width="107"}

When the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
[ruby-merge](#propdef-ruby-merge) on the [annotation
container](#ruby-annotation-container-box) is
[merge](#valdef-ruby-merge-merge),
[hiding](#hidden-annotation) is disabled. When that value is
[auto](#valdef-ruby-merge-auto), the user agent may decide whether to disable
[hiding] of its annotations, but it is
recommended to enable [hiding] if the user
agent's layout algorithm produces the results similar to
[separate](#valdef-ruby-merge-separate).

The content comparison for
[auto-hiding](#auto-hidden) takes
place prior to white space collapsing
([white-space](https://drafts.csswg.org/css-text-4/#propdef-white-space)) and text transformation
([text-transform](https://drafts.csswg.org/css-text-4/#propdef-text-transform)) and ignores elements (considers
only the `textContent` of the boxes).

 Future levels of CSS Ruby may add controls for
[auto-hiding](#auto-hidden), but
in this level it is always forced.

### 2.5. White Space Collapsing

As discussed in [§ 2.2 Anonymous Ruby Box Generation](#box-fixup), white
space within a ruby structure is [discarded](#anon-gen-discard-space):

- at the beginning and end of a [ruby
 container](#ruby-container), [annotation
 container](#ruby-annotation-container-box), or [base
 container](#ruby-base-container-box),
- between a [base
 container](#ruby-base-container-box) and its following [annotation
 container](#ruby-annotation-container-box),
- between [annotation
 containers](#ruby-annotation-container-box).

For example, the following markup will
display without any spaces:

``` highlight
<ruby>
 <rb>東</rb><rb>京</rb>
 <rt>とう</rt><rt>きょう</rt>
 <rtc><rt>Tō</rt><rt>kyō</rt></rtc>
</ruby>
```

Between [ruby segments](#ruby-segments), between [ruby
bases](#ruby-base-box), and
between [ruby
annotations](#ruby-annotation-box), however, white space is not discarded, and is
maintained for rendering as
[inter-base](#inter-base-white-space),
[inter-annotation](#inter-annotation-white-space), or [inter-segment white
space](#inter-segment-white-space). (See [Interpret intra-level white
space](#anon-gen-interpret-space), above.)

The rules preserving white space allow
ruby to be used with space-separated scripts such as Latin. For example,

``` highlight
<ruby>
 <rb>W</rb><rb>W</rb><rb>W</rb>
 <rt>World</rt> <rt>Wide</rt> <rt>Web</rt>
</ruby>
```

They also ensure that annotated white space is preserved. For example,

``` highlight
<ruby>
 <rb>Aerith</rb><rb> </rb><rb>Gainsborough</rb>
 <rt>エアリス</rt><rt>・</rt><rt>ゲインズブール</rt>
</ruby>
```

Where undiscarded white space is
[collapsible](https://drafts.csswg.org/css-text-4/#collapsible-white-space), it will collapse across adjacent boxes in each line
box following the standard [white space processing
rules](https://www.w3.org/TR/css3-text/#white-space-rules)
[\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3").
Annotations in separate [ruby
segments](#ruby-segments) or
separated by [hidden
annotations](#hidden-annotation) are not considered adjacent; however all base-level
content (including [inter-character
annotations](#ruby-position-inter-character-annotation), which are treated as [atomic
inlines](https://drafts.csswg.org/css-display-4/#atomic-inline)) is. For [collapsible white
space] between [ruby
segments] ([inter-segment white
space](#inter-segment-white-space)), the contextual text for determining [segment break
transformations](https://drafts.csswg.org/css-text-3/#line-break-transform)
is thus given by the [ruby
bases](#ruby-base-box) on
either side, not necessarily the text on either side of the white space
in source document order (which could include [interlinear
annotations](#interlinear-annotations)).

Note: The white space processing rules cause a white space sequence
containing a [segment
break](https://drafts.csswg.org/css-text-4/#segment-break) (such as a line feed) to [collapse to
nothing](https://www.w3.org/TR/css3-text/#line-break-transform) between
Han and Kana characters. This means that Chinese and Japanese ruby can
safely use white space for indentation of ruby markup. For example, the
following markup will display without any spaces:

``` highlight
<ruby>
 屋<rt>おく</rt>内<rt>ない</rt>
 禁<rt>きん</rt>煙<rt>えん</rt>
</ruby>
```

However, white space that does not contain a [segment
break](https://drafts.csswg.org/css-text-4/#segment-break) does not collapse completely away, so this markup will
display with a space between the first and second ruby pairs:

``` highlight
<ruby>
 屋<rt>おく</rt> 内<rt>ない</rt>
 禁<rt>きん</rt> 煙<rt>えん</rt>
</ruby>
```

## 3. Ruby Layout

When a ruby structure is laid out, its [base
level](#base-level) is initially
laid out on the line exactly as if its [ruby
bases](#ruby-base-box) were a
regular sequence of [inline
boxes](https://drafts.csswg.org/css-display-4/#inline-box) and the [ruby
container](#ruby-container) a
regular [inline box] wrapped around it.

If a [ruby container](#ruby-container) has any [inter-character
annotations](#ruby-position-inter-character-annotation), they are laid out into the [base
level](#base-level) as detailed in
[§ 3.2 Inter-character Ruby Layout](#inter-character-layout).
Subsequently, the [base
container](#ruby-base-container-box) is sized and [interlinear
annotations](#interlinear-annotations) are laid out as detailed in [§ 3.1 Interlinear Ruby
Layout](#interlinear-layout).

As in other CSS layout models, relative positioning, transforms, and
other graphical effects apply after this layout of the boxes.

### 3.1. Interlinear Ruby Layout

[Interlinear](#interlinear-annotations) [ruby
annotations](#ruby-annotation-box) within a level are initially laid out as if they were
[inline
boxes](https://drafts.csswg.org/css-display-4/#inline-box) participating in the same [inline formatting
context](https://drafts.csswg.org/css-display-4/#inline-formatting-context), effectively establishing a [line
box](https://drafts.csswg.org/css-inline-3/#line-box) for that
[level](#annotation-level)
of annotation in the [ruby
container](#ruby-container).
[Annotations] and
[bases](#ruby-base-box) are
aligned to each other by adjusting their spacing as described below.

#### 3.1.1. Inline-axis Interlinear Layout

In the inline axis,
[interlinear](#interlinear-annotations) [ruby
annotations](#ruby-annotation-box) are aligned with respect to their [ruby base
boxes](#ruby-base-box) in
accordance with their [annotation
container](#ruby-annotation-container-box)'s
[ruby-merge](#propdef-ruby-merge) value.

When [ruby-merge](#propdef-ruby-merge) is
[separate](#valdef-ruby-merge-separate), each [ruby
column](#ruby-columns) is sized
to the widest content ([ruby
base](#ruby-base-box) or [ruby
annotation](#ruby-annotation-box)) in that [column]. In the case
of [spanning
annotations](#spanning-annotation) (whether actually spanning or pretending to span per
[ruby-merge: merge]), if the content
of a [spanning annotation] would be wider
than the [columns] that it spans, then the
difference is distributed equally among the spanned
[columns]. If a [ruby
segment](#ruby-segments)
contains multiple [spanning annotations],
this distribution of additional space is performed starting with the
[spanning annotations] that span the
least number of bases, and then in increasing number of bases spanned.
Each [ruby base] and [ruby
annotation] is then sized to exactly
span its column(s).

 If there are multiple annotations in different levels
spanning the same number of bases that overlap but do not coincide, the
distribution of space is undefined. Note this is not possible with HTML
markup, but can happen in markup languages with explicit spanning such
as in [\[RUBY\]](#biblio-ruby "Ruby Annotation").

If any [ruby
annotation](#ruby-annotation-box) in an [annotation
container](#ruby-annotation-container-box) with [ruby-merge:
auto](#propdef-ruby-merge) is wider than its
[base](#ruby-base-box), then
[ruby annotations] in that [annotation
container] may extend outside
of their [column](#ruby-columns)(s). When they do, their influence on the measure of the
[columns] they intersect is up to the user
agent, provided that the [ruby
segment](#ruby-segments) is
made wide enough to fit all its content.

[Inter-character](#ruby-position-inter-character-annotation) annotations are interleaved between columns: they
factor into measurement of annotations that span both adjacent columns,
but are not included in either column and are never affected by the
sizing or positioning of [interlinear
annotations](#interlinear-annotations).

Within each [base](#ruby-base-box) and
[annotation](#ruby-annotation-box) box, how the extra space is distributed when its
content is narrower than the measure of the box is specified by its
[ruby-align](#propdef-ruby-align) property.

The following diagrams illustrate
these rules, covering typical situations as well as a few more complex
ones. In each case, [base
boxes](#ruby-base-box) and
[annotation boxes](#ruby-annotation-box) are assumed to have [ruby-align:
center](#propdef-ruby-align), while [annotation
containers](#ruby-annotation-container-box) are assumed to have [ruby-align:
space-between].

Blue brackets (`[ ]`) represent [base
boxes](#ruby-base-box), red
brackets (`[ ]`) represent [annotation
boxes](#ruby-annotation-box), and gray bars (`|`) represent the
limits of [ruby columns](#ruby-columns). [Ruby
containers](#ruby-container),
[base
containers](#ruby-base-container-box), and [annotation
containers](#ruby-annotation-container-box) are omitted.

Separate / non-spanning:

: ``` highlight
 |[ a1 ]|[ a2 ]|[annotation-3]|
 |[base 1]|[base 2]|[ base 3 ]|
 ```

 Boxes within each [column](#ruby-columns) are sized to match the widest box of that
 [column]. The value of
 [ruby-align](#propdef-ruby-align) on each [base
 box](#ruby-base-box) and
 [annotation
 box](#ruby-annotation-box) is used to distribute the extra space in each box.

Spanning (short):

: ``` highlight
 |[ a1 ]|[ short span ]|
 |[base 1]|[base 2]|[base 3]|
 ```

 When a [spanning
 annotation](#spanning-annotation) is shorter than the spanned
 [bases](#ruby-base-box),
 there is no extra space to distribute to these
 [bases]. Extra space within the [spanning
 annotation] is distributed according
 to [ruby-align](#propdef-ruby-align) on that [annotation
 box](#ruby-annotation-box), as for non spanning ones.

Spanning (long):

: ``` highlight
 |[ a1 ]|[spanning annotation]|
 |[base 1]|[ base 2 ]|[ base 3 ]|
 ```

 When the [spanning
 annotation](#spanning-annotation) is longer than the spanned [base
 boxes](#ruby-base-box),
 the extra space is distributed equally between them.

Merged (short):

: ``` highlight
 |[merged annotation]|
 |[base 1]|[base 2]|[base 3]|
 ```

 A [merged
 annotation](#merged-annotation) behaves similarly to a
 [spanning](#span) one, except that
 distribution of any extra space in it is determined by the value of
 [ruby-align](#propdef-ruby-align) on the [annotation
 container](#ruby-annotation-container-box), not on any of its [annotation
 boxes](#ruby-annotation-box).

Several levels, with spanning annotation:

: ``` highlight
 |[ a1 ]|[ annotation-2 ]|[ a3 ]|
 |[long annotation spanning all content]|
 |[ base 1 ]|[ base 2 ]|[ base 3 ]|
 ```

 ``` highlight
 |[ xx ]|[annotation spanning bases]|
 |[ a1 ]|[ annotation-2 ]|[ a3 ]|
 |[base 1]|[ base 2 ]|[ base 3 ]|
 ```

 In these two examples with multiple
 [levels](#annotation-level), each
 [column](#ruby-columns) is
 sized to its longest content, and [spanning
 annotations](#spanning-annotation) that are still longer than the sum of the
 [columns] that they span grow them further,
 adding to each equally.

Several levels, with multiple spanning annotations:

: ``` highlight
 |[ xx ]|[ annotation spanning bases ]|
 |[ a1 ]|[ annotation-2 ]|[ a3 ]|
 |[lengthy annotation spanning base content]|
 |[ base 1 ]|[ base 2 ]|[ base 3 ]|
 ```

 When there are multiple [spanning
 annotations](#spanning-annotation), those that span fewest
 [bases](#ruby-base-box)
 are processed first. In this case, the green one, which spans two
 bases, is processed before the orange one, which spans three.
 Changing this order would change the distribution of space.

 To help identify which [spanning
 annotation](#spanning-annotation) is responsible for which extra spacing, in this
 diagram the color of the text in each [spanning
 annotation] is matched with the
 background color of spacing it adds to other boxes.

#### 3.1.2. Block-axis Interlinear Layout

Define the extent to which
[vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align) affects these ruby boxes. See
[Issue 4987](https://github.com/w3c/csswg-drafts/issues/4987).

Each [base
container](#ruby-base-container-box) is then sized and positioned to contain exactly all of
its [ruby bases](#ruby-base-box)' margin boxes---​and all their associated
[inter-character](#ruby-position-inter-character-annotation) [ruby
annotation](#ruby-annotation-box) margin boxes, if any---​as well as the
[base] and [annotation
containers](#ruby-annotation-container-box) of any descendant [ruby
containers](#ruby-container)
also participating in this [inline formatting
context](https://drafts.csswg.org/css-display-4/#inline-formatting-context). (If a [base
container] has no
[in-flow](https://drafts.csswg.org/css-display-4/#in-flow) content, it is sized and positioned as if it contained
a single empty [ruby base].)

Each
[interlinear](#interlinear-annotations) [annotation
container](#ruby-annotation-container-box) is sized and positioned to contain exactly all of its
[ruby annotations](#ruby-annotation-box)' margin boxes as well as the
[base](#ruby-base-container-box) and [annotation
containers] of any descendant
[ruby containers](#ruby-container) also participating in this [annotation
level](#annotation-level)'s
[inline formatting
context](https://drafts.csswg.org/css-display-4/#inline-formatting-context). (If an [annotation
container] has no
[in-flow](https://drafts.csswg.org/css-display-4/#in-flow) content, it is sized and positioned as if it contained
a single empty [ruby annotation].) These
[annotation containers] are
then stacked outward over or under (depending on
[ruby-position](#propdef-ruby-position)) their corresponding [base
container], without any intervening
space, thus determining the block-axis positioning of the [ruby
annotations] with respect to their [ruby
bases](#ruby-base-box).

Should block-axis margins collapse? This
makes layout more robust, but is inconsistent with how inlines behave
along the inline-axis.

### 3.2. Inter-character Ruby Layout

[Inter-character
annotations](#ruby-position-inter-character-annotation) have special layout.
[Inter-character]
[ruby annotation
boxes](#ruby-annotation-box) are spliced into and measured as part of the layout of
the [base level](#base-level).
Each [ruby annotation] is inserted to
the right of the [ruby base](#ruby-base-box) it is paired with; a [spanning](#span) [inter-character
annotation] is
placed after the rightmost of all the bases that it spans.
[Inter-character]
[ruby annotations] are laid out exactly
like [inline
blocks](https://drafts.csswg.org/css-display-4/#inline-block), except as described below.

 As per the definition of
[inter-character](#valdef-ruby-position-inter-character), [inter-character
annotations](#ruby-position-inter-character-annotation) always have a
[vertical-rl](https://drafts.csswg.org/css-writing-modes-4/#valdef-writing-mode-vertical-rl)
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode), and only exist in
[horizontal](https://drafts.csswg.org/css-writing-modes-4/#horizontal-writing-mode) [ruby
containers](#ruby-container).

Each [ruby
annotation](#ruby-annotation-box) is placed immediately to the right of the relevant
[ruby base](#ruby-base-box),
before any [inter-base white
space](#inter-base-white-space) (or [inter-segment white
space](#inter-segment-white-space)). If multiple
[inter-character](#ruby-position-inter-character-annotation) [ruby annotation boxes]
are placed against the same [ruby base], their
[margin
boxes](https://drafts.csswg.org/css-box-4/#margin-box) are stacked rightwards without intervening space, in
increasing [level](#annotation-level) order.

If the [automatic
height](https://drafts.csswg.org/css-sizing-3/#automatic-size) of the [ruby annotation
box](#ruby-annotation-box)'s [content
area](https://drafts.csswg.org/css-box-4/#content-area) would be shorter than the height of the [content
box](https://drafts.csswg.org/css-box-4/#content-box) of the [ruby
base](#ruby-base-box) after
which it is placed, its [content box] height is
increased to match that height exactly.

The alignment of the [ruby annotation
box](#ruby-annotation-box) depends on the
[ruby-align](#propdef-ruby-align) property on the [ruby
annotation]:

- If [ruby-align](#propdef-ruby-align) is
 [start](#valdef-ruby-align-start), the top edge of the [ruby
 annotation](#ruby-annotation-box)'s [content
 box](https://drafts.csswg.org/css-box-4/#content-box) is aligned with the top edge of the [ruby
 base](#ruby-base-box)'s
 [content box].
- Otherwise, the center of the [ruby
 annotation](#ruby-annotation-box)'s [content
 box](https://drafts.csswg.org/css-box-4/#content-box) is vertically aligned with the center of the [ruby
 base](#ruby-base-box)'s
 [content box].

The [ruby annotation container
box](#ruby-annotation-container-box) of an
[inter-character](#ruby-position-inter-character-annotation) annotation is sized and placed so that its content box
coincides exactly with that of the [ruby base container
box](#ruby-base-container-box).

 The size and position of
[inter-character](#ruby-position-inter-character-annotation) [ruby annotation container
boxes](#ruby-annotation-container-box) has no effect on layout. The above definition is merely
so that programmatically inquiring about them produces deterministic
results.

For the purpose of [alignment](#ruby-align-property) and column sizing
(as discussed in [§ 3 Ruby Layout](#ruby-layout)),
[inter-character](#ruby-position-inter-character-annotation) [ruby
annotations](#ruby-annotation-box) are not considered to be part of the same
[column](#ruby-columns) as the
base to with they are attached; rather, they effectively form a
[column] of their own.

### 3.3. Styling Ruby Boxes

[Ruby bases](#ruby-base-box)
and [ruby containers](#ruby-container) are treated as [inline
boxes](https://drafts.csswg.org/css-display-4/#inline-box), and all properties that apply to [inline
boxes], unless otherwise specified, also apply to
them in the same way. However, the [line-relative shift
values](https://drafts.csswg.org/css-inline-3/#line-relative-shift-values) of
[vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align)
([top](https://drafts.csswg.org/css-inline-3/#valdef-baseline-shift-top),
[bottom](https://drafts.csswg.org/css-inline-3/#valdef-baseline-shift-bottom)) must be ignored (treated as zero).

All properties that apply to [inline
boxes](https://drafts.csswg.org/css-display-4/#inline-box), unless otherwise specified, also apply to [ruby
annotations](#ruby-annotation-box) in the same way, except
[line-height](https://drafts.csswg.org/css2/#propdef-line-height), which does not apply. Also, the
[line-relative shift
values](https://drafts.csswg.org/css-inline-3/#line-relative-shift-values) of
[vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align)
([top](https://drafts.csswg.org/css-inline-3/#valdef-baseline-shift-top),
[bottom](https://drafts.csswg.org/css-inline-3/#valdef-baseline-shift-bottom)) must be ignored (treated as zero).

Neither the
[margin](https://drafts.csswg.org/css-box-4/#margin),
[padding](https://drafts.csswg.org/css-box-4/#padding), and
[border](https://drafts.csswg.org/css-box-4/#border) properties nor any of the properties that do not apply
to [inline
boxes](https://drafts.csswg.org/css-display-4/#inline-box) apply to [base
containers](#ruby-base-container-box) or [annotation
containers](#ruby-annotation-container-box). Additionally,
[line-height](https://drafts.csswg.org/css2/#propdef-line-height) does not apply to [annotation
containers].

The UA is not required to support any of the background properties or
outline properties, or any other property that illustrates the bounds of
the box on [ruby base container
boxes](#ruby-base-container-box) or [ruby annotation container
boxes](#ruby-annotation-container-box). The UA may implement these boxes simply as
abstractions for inheritance and control over the layout of their
contents.

### 3.4. Breaking Across Lines

When there is not enough space for an entire [ruby
container](#ruby-container)
to fit on the line, the ruby may be broken wherever all levels
simultaneously allow a break. (See [CSS Text 3 § 5 Line Breaking and
Word Boundaries](https://drafts.csswg.org/css-text-3/#line-breaking) for
details on line breaking.) Ruby most often breaks between
base-annotation sets, but if the line-breaking rules allow it, can also
break within a [ruby base](#ruby-base-box) (and, in parallel, its associated [ruby annotation
boxes](#ruby-annotation-box)).

Whenever ruby breaks across lines, [ruby
annotations](#ruby-annotation-box) must stay with their respective [ruby
bases](#ruby-base-box). The
line *must not* break between a [ruby base]
and its [annotations], even in the case
of [inter-character
annotations](#ruby-position-inter-character-annotation).

![Diagram showing the line breaking opportunity in a \"Bopomofo\"
ruby](images/r-break-b.gif){height="90" width="300"}

[inter-character](#valdef-ruby-position-inter-character) ruby line breaking opportunity

After line-breaking, each fragment is [laid out](#ruby-layout)
independently, and [ruby alignment](#ruby-align-property) takes place
within each fragment.

#### 3.4.1. Breaking Between Bases

In typical cases, [ruby base
boxes](#ruby-base-box) and
[ruby annotation
boxes](#ruby-annotation-box) are styled to forbid internal line wrapping and do not
contain forced breaks. (See [Appendix A](#default-stylesheet).) In such
cases the [ruby container](#ruby-container) can only break between adjacent [ruby
bases], and only if no [ruby
annotations] span those [ruby
bases].

![Diagram showing the line breaking opportunity in a complex
ruby](images/r-break-a.gif){height="201" width="408"}

Ruby line breaking opportunity

Whether ruby can break between two adjacent [ruby
bases](#ruby-base-box) is
controlled by normal line-breaking rules for the base text, exactly as
if the [ruby bases] were adjacent inline
boxes. (The annotations are ignored when determining soft wrap
opportunities for the [base level](#base-level).)

For example, if two adjacent ruby
bases are "蝴" and "蝶", the line may break between them, because lines
are normally allowed to break between two Han characters. However, if
[word-break](https://drafts.csswg.org/css-text-4/#propdef-word-break) is
[keep-all](https://drafts.csswg.org/css-text-4/#valdef-word-break-keep-all), that line break is forbidden.

``` highlight
<ruby>蝴<rt>hú</rt>蝶<rt>dié</rt>
```

Inter-base white space is significant for evaluating line break
opportunities between [ruby
bases](#ruby-base-box). As
with white space between inlines, it collapses when the line breaks
there, following the rules detailed in [CSS Text 3 § 4.1 The White Space
Processing
Rules](https://drafts.csswg.org/css-text-3/#white-space-rules).
Similarly, annotation white space is also trimmed at a line break.

For example, given the following
markup:

``` highlight
<ruby><rb>one</rb> <rb>two</rb> <rt>1</rt> <rt>2</rt></ruby>
```

Due to the space, the line may break between "one" and "two". If the
line breaks there, that space---and the space between "1" and
"2"---disappears, in accordance with standard CSS white space processing
rules.

#### 3.4.2. Breaking Within Bases

For longer base texts, it is sometimes appropriate to allow breaking
within a base-annotation pair. For example, if an English sentence is
annotated with its Japanese translation, allowing the text to wrap
allows for reasonable line breaking behavior in the paragraph.

Insert scanned example so people don't
think this is just the ramblings of an insane spec-writer.

Line-breaking within a [ruby
base](#ruby-base-box) is only
allowed if the
[white-space](https://drafts.csswg.org/css-text-4/#propdef-white-space) property of the [ruby
base] and all its parallel
[annotations](#ruby-annotation-box) allow it, and there exists a [soft wrap
opportunity](https://drafts.csswg.org/css-text-4/#soft-wrap-opportunity) *within* (i.e. not at the start or end) the content of
each base/annotation box. Since there is no structural correspondence
between fragments of content within [ruby
bases] and
[annotations], the UA may break at any
set of opportunities; but it is recommended that the UA attempt to
proportionally balance the amount of content inside each fragment.

There are no line breaking opportunities within [inter-character
annotations](#ruby-position-inter-character-annotation).

### 3.5. Bidi Reordering

The Unicode bidirectional algorithm reorders logically-stored text for
visual presentation when characters from scripts of opposing
directionalities are mixed within a single paragraph.

To preserve the correspondence of [ruby
annotations](#ruby-annotation-box) to their respective [ruby
bases](#ruby-base-box), a few
restrictions must be imposed:

- The contents of a [ruby base](#ruby-base-box) or [ruby
 annotation](#ruby-annotation-box) must remain contiguous.
- [Ruby
 annotations](#ruby-annotation-box) must be reordered together with their [ruby
 bases](#ruby-base-box).
- All [ruby bases](#ruby-base-box) spanned by a single [ruby
 annotation](#ruby-annotation-box) must remain contiguous.

To this end,

- [Bidi
 isolation](https://drafts.csswg.org/css-writing-modes-4/#bidi-isolate) is forced on all [internal ruby
 boxes](#internal-ruby-boxes) and the [ruby
 container](#ruby-container): the
 [normal](https://drafts.csswg.org/css-writing-modes-4/#valdef-unicode-bidi-normal) and
 [embed](https://drafts.csswg.org/css-writing-modes-4/#valdef-unicode-bidi-embed) values of
 [unicode-bidi](https://drafts.csswg.org/css-writing-modes-3/#propdef-unicode-bidi) compute to
 [isolate](https://drafts.csswg.org/css-writing-modes-4/#valdef-unicode-bidi-isolate), and
 [bidi-override](https://drafts.csswg.org/css-writing-modes-4/#valdef-unicode-bidi-bidi-override) computes to
 [isolate-override](https://drafts.csswg.org/css-writing-modes-4/#valdef-unicode-bidi-isolate-override).

 This means that implicit bidi reordering does not
 work across ruby bases, so authors will need to ensure that the [ruby
 container](#ruby-container)'s declared directionality does indeed match its
 contents.

- During layout, [ruby
 segments](#ruby-segments)
 are ordered within the [ruby
 container](#ruby-container)
 by the
 [direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) property of their [ruby
 container].

- Within a segment, [ruby
 bases](#ruby-base-box) and
 [ruby
 annotations](#ruby-annotation-box) that are not
 [merged](#merged-annotation) are ordered within their respective containers by the
 [direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) property of the segment's [ruby
 base
 container](#ruby-base-container-box). [Merged annotations]
 are ordered by the [direction]
 property of their [annotation
 container](#ruby-annotation-container-box), exactly as if they were a sequence of inline boxes
 within their [annotation
 container].

 This means the
 [direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) property on [ruby annotation
 containers](#ruby-annotation-container-box) is ignored for the purpose of layout of
 non-[merged](#merged-annotation) annotations. However, it can still inherit into the
 container's children and thereby affect the [inline base
 direction](https://drafts.csswg.org/css-writing-modes-4/#inline-base-direction) of any [ruby
 annotations](#ruby-annotation-box) it contains.

As with other inline-level content, the bidi reordering of [internal
ruby boxes](#internal-ruby-boxes) happens after line-breaking so that content is divided
across lines according to its logical order.

 It could be useful to adjust these rules slightly so
that when [ruby-merge](#propdef-ruby-merge) is
[merge](#valdef-ruby-merge-merge) on a particular [annotation
container](#ruby-annotation-container-box), [bidi
isolation](https://drafts.csswg.org/css-writing-modes-4/#bidi-isolate) is not forced onto the individual annotations, enabling
them to be processed together. However, this would add complexity to
implementations, which does not seem justified in the absence of demand
to handle this situation. Anyone with a need for this to be handled is
encouraged to contact the CSS Working Group.

See
[\[CSS3-WRITING-MODES\]](#biblio-css3-writing-modes "CSS Writing Modes Level 3")
for a more in-depth discussion of bidirectional text in CSS.

### 3.6. Line Spacing

The
[line-height](https://drafts.csswg.org/css2/#propdef-line-height) property controls spacing between
lines in CSS. When inline content on line is shorter than the
[line-height], half-leading is
added on either side of the content, as specified in [CSS Inline Layout
3 § 5 Logical Heights and Inter-line
Spacing](https://drafts.csswg.org/css-inline-3/#line-height).

In order to ensure consistent spacing of lines, documents with ruby
typically ensure that the
[line-height](https://drafts.csswg.org/css2/#propdef-line-height) is large enough to accommodate ruby
between lines of text. Therefore, ordinarily, [ruby annotation
containers](#ruby-annotation-container-box) and [ruby annotation
boxes](#ruby-annotation-box) do not contribute to the measured height of a line's
inline contents; any alignment (see
[vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align)) and line-height calculations are
performed using only the [ruby base
container](#ruby-base-container-box), exactly as if it were a normal inline.

However, if the
[line-height](https://drafts.csswg.org/css2/#propdef-line-height) specified on the [ruby
container](#ruby-container)
is less than the distance between the top of the top [ruby annotation
container](#ruby-annotation-container-box) and the bottom of the bottom [ruby annotation
container], then additional
leading is added on the appropriate side(s) of the [ruby base
container](#ruby-base-container-box) such that if a block consisted of three lines each
containing ruby identical to this, none of the [ruby
containers] would overlap.

 This does not ensure that the [ruby
annotations](#ruby-annotation-box) remain within the line box. It merely ensures that *if
all lines had equal spacing* and equivalent amounts and positioning of
[ruby annotations], there would be
enough room to avoid overlap.

Authors should ensure appropriate
[line-height](https://drafts.csswg.org/css2/#propdef-line-height) and
[padding](https://drafts.csswg.org/css-box-4/#propdef-padding) to accommodate ruby, and be
particularly careful at the beginning or end of a block and when a line
contains inline-level content (such as images, inline blocks, or
elements shifted with
[vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align)) taller than the paragraph's
default font size.

![The content of each line sits in the middle of its line height; the
additional space on each side is called half-leading. Ruby fits between
lines if it is smaller than twice the half-leading, but this means that
it occupies space belonging to the half-leading of the previous
line.](images/rlh-a.gif){height="138" width="210"}

Ruby annotations will often overflow the line; authors should ensure
content over/under a ruby-annotated line is adequately spaced to leave
room for the ruby.

 More control over how ruby affects alignment and line
layout will be part of the CSS Line Layout Module Level 3. Note, it is
currently in the exploratory stages of development; descriptions of new
features should not yet be relied upon.

## 4. Ruby Formatting Properties

The following properties are introduced to control ruby
[positioning](#rubypos), [text distribution](#collapsed-ruby), and
[alignment](#rubyalign).

### 4.1. Ruby Positioning: the [ruby-position property]
Name:

[ruby-position]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ alternate
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) \[ over
[\|](https://drafts.csswg.org/css-values-4/#comb-one) under \] \] [\|]
inter-character

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

alternate

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

ruby annotation containers

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property controls position of the [ruby
annotation](#ruby-annotation-box) with respect to its base. Values have the following
meanings:

[alternate]

: Different [levels](#annotation-level) of annotations alternate between
 [over](#valdef-ruby-position-over) and
 [under](#valdef-ruby-position-under).

 If the [annotation
 container](#ruby-annotation-container-box) is the first
 [level](#annotation-level) of annotation in its [ruby
 segment](#ruby-segments),
 or if all prior [levels] are
 [inter-character](#ruby-position-inter-character-annotation), then
 [alternate](#valdef-ruby-position-alternate), either on its own or in combination with
 [over](#valdef-ruby-position-over), behaves the same as
 [over], while
 [alternate] in
 combination with
 [under](#valdef-ruby-position-under) behaves the same as
 [under].

 Otherwise, if the previous level of
 [interlinear](#interlinear-annotations) annotation is
 [over](#valdef-ruby-position-over),
 [alternate](#valdef-ruby-position-alternate) behaves like
 [under](#valdef-ruby-position-under), and vice versa. (In this case, whether
 [alternate] is
 specified alone or in combination with
 [over] or
 [under] makes no
 difference.)

[over]
: The ruby annotation appears
 [line-over](https://drafts.csswg.org/css-writing-modes-4/#line-over) the base.
 ::: figure
 ![Diagram of ruby glyph layout in horizontal mode with ruby
 annotation appearing above the
 base](images/shinkansen-top.gif){height="33" width="140"}
 Ruby over Japanese base text in horizontal layout
 :::

 ::: figure
 ![Diagram of ruby glyph layout in vertical mode with ruby annotation
 appearing vertically on the right of the
 base](images/shinkansen-right.gif){height="141" width="33"}
 Ruby to the right of Japanese base text in vertical layout
 :::

[under]
: The ruby annotation appears
 [line-under](https://drafts.csswg.org/css-writing-modes-4/#line-under) the base. This is a relatively rare setting used in
 ideographic East Asian writing systems, most easily found in
 educational text.
 ::: figure
 ![Diagram of ruby glyph layout in horizontal mode with ruby
 annotation appearing below the
 base](images/shinkansen-bottom.gif){height="36" width="142"}
 Ruby under Japanese base text in horizontal layout
 :::

 ::: figure
 ![Diagram of ruby glyph layout in vertical mode with ruby annotation
 appearing vertically on the left of the
 base](images/shinkansen-left.gif){height="141" width="37"}
 Ruby to the left of Japanese base text in vertical layout
 :::

[inter-character]

: If the [writing
 mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the enclosing [ruby
 container](#ruby-container) is
 [vertical](https://drafts.csswg.org/css-writing-modes-4/#vertical-writing-mode), this value has the same effect as
 [over](#valdef-ruby-position-over).

 Otherwise, the ruby annotation becomes an [inter-character
 annotation]. The annotation appears on
 the right of the base in horizontal text. This forces the computed
 value of
 [writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) of the [ruby
 annotation](#ruby-annotation-box) children of this [ruby annotation
 container](#ruby-annotation-container-box) to be
 [vertical-rl](https://drafts.csswg.org/css-writing-modes-4/#valdef-writing-mode-vertical-rl).

 The computed value of
 [writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) on the [ruby annotation
 container](#ruby-annotation-container-box) itself is not affected. This is to avoid circular
 dependencies between computed values on the
 [writing-mode],
 [display](https://drafts.csswg.org/css-display-4/#propdef-display), and
 [ruby-position](#propdef-ruby-position) properties on the same element.

 This value is provided for the special case of traditional Chinese
 as used especially in Taiwan: ruby (made of [bopomofo](#g-bopomofo)
 glyphs) in that context appears vertically along the right side of
 the base glyph, even when the layout of the base characters is
 horizontal:

 ::: figure
 ![Example of Taiwanese-style ruby](images/bopomofo.gif){height="42"
 width="138"}
 "Bopomofo" ruby in traditional Chinese (ruby annotation shown in
 blue for clarity) in horizontal layout
 :::

 ::::
 Note: As inheritance works on the element tree without accounting
 for anonymous boxes created for ruby layout, when using
 [inter-character
 annotations](#ruby-position-inter-character-annotation) authors need to be careful to avoid markup patterns
 involving an element-based [ruby annotation
 container](#ruby-annotation-container-box), an anonymous [ruby
 annotation](#ruby-annotation-box), and further descendant elements, as those
 descendants would inherit their writing mode from the [ruby
 annotation container], and
 not from the [ruby annotation] whose
 [writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) has been changed to
 [vertical-rl](https://drafts.csswg.org/css-writing-modes-4/#valdef-writing-mode-vertical-rl).

 :::
 (#example-af80289a)
 ``` highlight
 ruby { ruby-position: inter-character; }
 ```

 ``` highlight
 <ruby>base<rtc><em>problematic</em> annotation</ruby>
 ```

 In the above markup, an anonymous [ruby
 annotation](#ruby-annotation-box) box is created as a child of the `<rtc>` element to
 wrap the whole "problematic annotation". Since it is a child of an
 [annotation
 container](#ruby-annotation-container-box) whose
 [ruby-position](#propdef-ruby-position) is
 [inter-character](#valdef-ruby-position-inter-character), its
 [writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) will be
 [vertical-rl](https://drafts.csswg.org/css-writing-modes-4/#valdef-writing-mode-vertical-rl), which is expected. However, the `<em>`
 element inherits its [writing-mode] directly from the `<rtc>` element, which has not been
 forced to [vertical-rl].

 In this example, the explicit [ruby annotation
 container](#ruby-annotation-container-box) element was not necessary, so using a [ruby
 annotation](#ruby-annotation-box) element instead would avoid the problem:

 ``` highlight
 <ruby>base<rt><em>problematic</em> annotation</ruby>
 ```

 If an explicit [ruby annotation
 container](#ruby-annotation-container-box) element is needed, then using a [ruby
 annotation](#ruby-annotation-box) element as well would also address the problem:

 ``` highlight
 <ruby>base<rtc><rt><em>problematic</em> annotation</ruby>
 ```
 :::
 ::::

[Annotation
containers](#ruby-annotation-container-box) that are not [inter-character
annotations](#ruby-position-inter-character-annotation) are called [interlinear
annotations].

If multiple [ruby annotation
containers](#ruby-annotation-container-box) have the same
[ruby-position](#propdef-ruby-position), they stack outwards from the base
text.

### 4.2. Sharing Annotation Space: the [ruby-merge property]
Name:

[ruby-merge]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

separate
[\|](https://drafts.csswg.org/css-values-4/#comb-one) merge [\|] auto

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

separate

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[interlinear](#interlinear-annotations) ruby annotation containers

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

This property controls how ruby annotation boxes should be rendered when
there are more than one in a ruby container box: whether each pair
should be kept separate, the annotations should be
[merged] and rendered as a group, or
the separation should be determined based on the space available.

 [Inter-character
annotations](#ruby-position-inter-character-annotation) are always separate, and this property does not apply.

Possible values:

[separate]
: Each ruby annotation box is rendered within the same
 [column](#ruby-columns)(s)
 as its corresponding base box(es), i.e. without overlapping adjacent
 bases on either side. This style is called "mono ruby" in
 [\[JLREQ\]](#biblio-jlreq "Requirements for Japanese Text Layout 日本語組版処理の要件(日本語版)").
 ![[ruby-merge:
 separate](#propdef-ruby-merge) with center
 alignment](images/ruby-mono.png){a
 height="57" width="207"}

 :::
 (#example-4b06efaa) For example, the following two
 lines render the same:
 ``` highlight
 <p><ruby>無<rt>む</ruby><ruby>常<rt>じょう</ruby>
 <p><ruby style="ruby-merge:separate"><rb>無<rb>常<rt>む<rt>じょう</ruby>
 ```
 :::

[merge]
: All [ruby annotation
 boxes](#ruby-annotation-box) within the same [ruby
 segment](#ruby-segments)
 on the same line are concatenated as [inline
 boxes](https://drafts.csswg.org/css-display-4/#inline-box) within their [annotation
 container](#ruby-annotation-container-box), and laid out in a single anonymous [ruby
 annotation box] spanning all their
 associated [ruby base
 boxes](#ruby-base-box).
 When laid out on a single line, this style renders similar to "group
 ruby" in
 [\[JLREQ\]](#biblio-jlreq "Requirements for Japanese Text Layout 日本語組版処理の要件(日本語版)").
 However, when it breaks across lines, [ruby
 annotations] are kept together with
 their respective [ruby bases].
 ![[ruby-merge:
 merge](#propdef-ruby-merge) with center
 alignment](images/ruby-merge.png){a
 height="57" width="189"}

 :::
 (#example-8db84546) The following two lines render the
 same if both characters fit on one line:
 ``` highlight
 <p><ruby>無常<rt>むじょう</ruby>
 <p><ruby style="ruby-merge:merge"><rb>無<rb>常<rt>む<rt>じょう</ruby>
 ```

 However, the second one renders the same as [ruby-position:
 separate](#propdef-ruby-position) when the two bases are split across
 lines.
 :::

[auto]
: The user agent may use any algorithm to determine how each ruby
 annotation box is rendered to its corresponding base box, with the
 intention that if all annotations fit over their respective bases,
 the result is identical to
 [separate](#valdef-ruby-merge-separate), but if some annotations are wider than
 their bases the space is shared in some way to avoid imposing space
 between bases.
 ![[ruby-merge:
 auto](#propdef-ruby-merge) with center
 alignment](images/ruby-jukugo.png){a
 height="57" width="189"}

 :::
 Note: This behavior is intended for compound words, see ["Jukugo
 Ruby" in "What is
 ruby?"](https://www.w3.org/International/questions/qa-ruby#jukugo).
 [\[QA-RUBY\]](#biblio-qa-ruby "What is ruby?")
 There are various conventions for rendering this type of ruby, see
 [Placement of
 Jukugo-ruby](https://www.w3.org/TR/simple-ruby/#placement-of-jukugo-ruby)
 in
 [\[SIMPLE-RUBY\]](#biblio-simple-ruby "Rules for Simple Placement of Japanese Ruby"),
 [Positioning of
 Jukugo-ruby](https://www.w3.org/TR/jlreq/#positioning_of_jukugoruby_with_respect_to_base_characters)
 in
 [\[JLREQ\]](#biblio-jlreq "Requirements for Japanese Text Layout 日本語組版処理の要件(日本語版)"),
 and 4.12.3(c) 熟語ルビの処理 in
 [\[JISX4051\]](#biblio-jisx4051 "Line composition rules for Japanese documents.")
 for examples of varying complexity.

 The simplest of these is to render as
 [separate](#valdef-ruby-merge-separate) if all ruby annotation boxes fit within the
 advances of their corresponding base boxes, and render as
 [merge](#valdef-ruby-merge-merge) otherwise.
 :::

 Text does not shape or form ligatures across [ruby
annotations](#ruby-annotation-box) or [bases](#ruby-base-box), even merged ones, due to [bidi
isolation](https://drafts.csswg.org/css-writing-modes-4/#bidi-isolate). See [§ 3.5 Bidi Reordering](#bidi) and [CSS Text 3
§ 7.3 Shaping Across Element
Boundaries](https://drafts.csswg.org/css-text-3/#boundary-shaping).

### 4.3. Ruby Text Distribution: the [ruby-align property]
Name:

[ruby-align]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

start
[\|](https://drafts.csswg.org/css-values-4/#comb-one) center [\|] space-between
[\|] space-around

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

space-around

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

ruby bases, ruby annotations, ruby base containers, ruby annotation
containers

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

This property specifies how text is distributed within the various ruby
boxes when their contents do not exactly fill their respective boxes.
Note that space distributed by
[ruby-align](#propdef-ruby-align) is unrelated to, and independent of, any
space distributed due to justification.

For
[inter-character](#ruby-position-inter-character-annotation) annotations, this property can also affect the
alignment of the box itself (see [§ 3.2 Inter-character Ruby
Layout](#inter-character-layout)). It otherwise only affects the
alignment of content within the box, not the size or position of the box
itself.

Values have the following meanings:

[start]

: The ruby content is aligned with the start edge of its box.

 ::: figure
 ![Diagram of glyph layout in left aligned ruby when ruby text is
 shorter than base](images/ra-l.gif){height="91" width="145"}
 ![Diagram of glyph layout in left aligned ruby when ruby text is
 longer than base](images/ra-l-rb.gif){height="91" width="145"}
 [start](#valdef-ruby-align-start) ruby distribution
 :::

 (#issue-41435749) \"Katatsuki ruby\" (肩付きルビ) is
 close to, but not quite the same as, this
 [start](#valdef-ruby-align-start) value. In particular, its behavior when
 overhanging its base can differ from start alignment depending on
 surrounding context, see
 [JLREQ](https://www.w3.org/TR/jlreq/#positioning_of_monoruby_with_respect_to_base_characters).
 Also, it's only ever used in vertical writing, and the JLTF
 considers it not particularly important, so it may not be worth the
 effort to make this value smart enough to deal with katatsuki ruby.
 If [start] is needed for
 some other purpose, we should keep it. Otherwise, maybe just drop
 it?

[center]
: The ruby content is centered within its box.
 ::: figure
 ![Diagram of glyph layout in center aligned ruby when ruby text is
 shorter than base](images/ra-c.gif){height="91" width="145"}
 ![Diagram of glyph layout in center aligned ruby when ruby text is
 longer than base](images/ra-c-rb.gif){height="91" width="145"}
 [center](#valdef-ruby-align-center) ruby distribution
 :::

[space-between]
: The ruby content expands as defined for normal text justification
 (as defined by
 [text-justify](https://drafts.csswg.org/css-text-4/#propdef-text-justify)), except that if there are no
 [justification
 opportunities](https://drafts.csswg.org/css-text-4/#justification-opportunity) the content is centered.
 ::: figure
 ![Diagram of glyph layout in distribute-letter aligned ruby when
 ruby text is shorter than base](images/ra-dl.gif){height="91"
 width="145"} ![Diagram of glyph layout in distribute-letter aligned
 ruby when ruby text is longer than
 base](images/ra-dl-rb.gif){height="91" width="145"}
 [space-between](#valdef-ruby-align-space-between) ruby distribution
 :::

[space-around]
: As for
 [space-between](#valdef-ruby-align-space-between) except that there exists an extra
 [justification
 opportunities](https://drafts.csswg.org/css-text-4/#justification-opportunity) whose space is distributed half before and half
 after the ruby content.
 ::: figure
 ![Diagram of glyph layout in auto aligned ruby when ruby text is
 shorter than base](images/ra-ds.gif){height="91" width="145"}
 ![Diagram of glyph layout in auto aligned ruby when ruby text is
 longer than base](images/ra-ds-rb.gif){height="91" width="145"}
 [space-around](#valdef-ruby-align-space-around) ruby distribution
 :::

The [default UA style
sheet](#default-ua-ruby) applies [text-justify:
ruby](https://drafts.csswg.org/css-text-4/#propdef-text-justify) to [ruby
annotations](#ruby-annotation-box), defining [justification
opportunities](https://drafts.csswg.org/css-text-4/#justification-opportunity) between every adjacent pair of CJK
[characters](https://drafts.csswg.org/css-text-3/#character) but not between adjacent pairs of Latin or Bopomofo
[characters]. Thus, the
[space-around](#valdef-ruby-align-space-around) and
[space-between](#valdef-ruby-align-space-between) values will nevertheless result in Latin or
Bopomofo characters centered:

![Diagram of glyph layout in auto aligned ruby when halfwidth ruby text
is shorter than base](images/ra-c-h.gif){height="91" width="145"}
![Diagram of character layout in auto aligned ruby when ruby text is
longer than narrow-width base](images/ra-c-rb-h.gif){height="91"
width="145"}

Non-CJK ruby text in
[space-around](#valdef-ruby-align-space-around) and
[space-between](#valdef-ruby-align-space-between) ruby distribution are centered

The distribution of space can be controlled via
[text-justify](https://drafts.csswg.org/css-text-4/#propdef-text-justify).
[\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3")

Content in [ruby bases](#ruby-base-box) and [ruby
annotations](#ruby-annotation-box), except those that span due to [ruby-merge:
merge](#propdef-ruby-merge), is aligned within its box based on the value of
[ruby-align](#propdef-ruby-align) on that box. Content in [merged
annotations](#merged-annotation) is aligned within the [ruby annotation
container](#ruby-annotation-container-box) based on the value of
[ruby-align] on the
[annotations container],
ignoring the value of [ruby-align] on the individual [ruby
annotations].

What if a [merged
annotation](#merged-annotation) causes the [ruby
segment](#ruby-segments) to be
wider? Does it cause each base to grow as if it were spanning them, as
currently specified? This does not allow e.g. centering the text in a
multi-base base container when its merged annotation is longer. Instead,
maybe we should allow ruby-merge to apply to base containers as well,
but this would require us either to allow a single base to span multiple
annotations (if the base is merged but some annotation levels are not),
or to require that if the base is merged, then all annotation levels
must be merged as well.

The way content is aligned when
[ruby-merge](#propdef-ruby-merge) is
[auto](#valdef-ruby-merge-auto) is up to the user agent, but must be identical to
that of [ruby-merge: separate] when
all annotations fit over their respective bases.

### 4.4. Ruby Text Decoration

Text decoration does not propagate from the base text to the
annotations.

When text decoration is specified on an ancestor of the ruby, it is
drawn across the entire content area of the ruby base container,
including any extra space added on either side of the ruby base contents
to accommodate long annotations. When text decoration is specified on a
ruby base itself, this extra space is not decorated, similar to how a
box's own padding is not decorated when text decoration is specified
directly on that box.
[\[CSS3-TEXT-DECOR\]](#biblio-css3-text-decor "CSS Text Decoration Module Level 3")

Text decoration may be specified directly on ruby base containers and
ruby annotation containers: in such cases it is propagated to all of the
container's bases or annotations (respectively), and is also drawn
between them for continuity.

The positions of ruby annotations may be adjusted to avoid potential
conflicts with overline and underline decorations applied to the base
text. In the basic case of consistent font size and baseline alignment,
an underline or overline is positioned between the [base
level](#base-level) and any
annotations on that side.

This section needs some clarification
about drawing decorations between the content of adjacent
bases/annotations. Depends on if those boxes are as wide as their
[column](#ruby-columns) or not.

## 5. Edge Effects

### 5.1. Overhanging Ruby: the [ruby-overhang property]
Name:

[ruby-overhang]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) spaces

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

ruby annotation containers

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

The
[ruby-overhang](#propdef-ruby-overhang) property controls whether [ruby
annotations](#ruby-annotation-box) may overlap adjacent text outside the [ruby
container](#ruby-container).
Values have the following meanings:

[auto]

: When a [ruby annotation
 container](#ruby-annotation-container-box) is longer than its corresponding [ruby base
 container](#ruby-base-container-box), the [ruby annotation
 container] may partially
 overlap adjacent boxes.

 Whether, how much, and under which conditions to overhang are
 determined by the UA.

[spaces]

: When a [ruby annotation
 container](#ruby-annotation-container-box) is longer than its corresponding [ruby base
 container](#ruby-base-container-box), the [ruby annotation
 container] must not
 overlap adjacent boxes, except over adjacent spaces.

 For this purpose, spaces are any of the following:

 - [preserved white
 space](https://drafts.csswg.org/css-text-4/#preserved-white-space)

 - no-break space (U+00A0)

 - [other space
 separators](https://drafts.csswg.org/css-text-3/#other-space-separators)

 - half of the [advance
 measure](https://drafts.csswg.org/css-values-4/#length-advance-measure) of [fullwidth opening
 punctuation](https://drafts.csswg.org/css-text-4/#fullwidth-opening-punctuation), on the
 [inline-start](https://drafts.csswg.org/css-writing-modes-4/#inline-start) side of the character, unless it has been trimmed
 by
 [text-spacing-trim](https://drafts.csswg.org/css-text-4/#propdef-text-spacing-trim)

 - half of the [advance
 measure](https://drafts.csswg.org/css-values-4/#length-advance-measure) of [fullwidth closing
 punctuation](https://drafts.csswg.org/css-text-4/#fullwidth-closing-punctuation), on the
 [inline-end](https://drafts.csswg.org/css-writing-modes-4/#inline-end) side of the character, unless it has been trimmed
 by
 [text-spacing-trim](https://drafts.csswg.org/css-text-4/#propdef-text-spacing-trim)

 - one quarter of the [advance
 measure](https://drafts.csswg.org/css-values-4/#length-advance-measure) of [fullwidth middle dot
 punctuation](https://drafts.csswg.org/css-text-4/#fullwidth-middle-dot-punctuation), on both the
 [inline-start](https://drafts.csswg.org/css-writing-modes-4/#inline-start) and
 [inline-end](https://drafts.csswg.org/css-writing-modes-4/#inline-end) sides of the character, unless it has been
 trimmed by
 [text-spacing-trim](https://drafts.csswg.org/css-text-4/#propdef-text-spacing-trim)

 Tests

 Not yet tested:

 - \'other spaces separators\' other than ideographic spaces
 - the characters which may or may not be middle dots depending on
 the language
 - interaction with \'text-spacing-trim\'
 - vertical writing modes

 - [ruby-overhang-spaces-001.html](https://wpt.fyi/results/css/css-ruby/ruby-overhang-spaces-001.html "css/css-ruby/ruby-overhang-spaces-001.html")
 [[(live
 test)]](http://wpt.live/css/css-ruby/ruby-overhang-spaces-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-ruby/ruby-overhang-spaces-001.html)
 - [ruby-overhang-spaces-002.html](https://wpt.fyi/results/css/css-ruby/ruby-overhang-spaces-002.html "css/css-ruby/ruby-overhang-spaces-002.html")
 [[(live
 test)]](http://wpt.live/css/css-ruby/ruby-overhang-spaces-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-ruby/ruby-overhang-spaces-002.html)
 - [ruby-overhang-spaces-003.html](https://wpt.fyi/results/css/css-ruby/ruby-overhang-spaces-003.html "css/css-ruby/ruby-overhang-spaces-003.html")
 [[(live
 test)]](http://wpt.live/css/css-ruby/ruby-overhang-spaces-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-ruby/ruby-overhang-spaces-003.html)
 - [ruby-overhang-spaces-004.html](https://wpt.fyi/results/css/css-ruby/ruby-overhang-spaces-004.html "css/css-ruby/ruby-overhang-spaces-004.html")
 [[(live
 test)]](http://wpt.live/css/css-ruby/ruby-overhang-spaces-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-ruby/ruby-overhang-spaces-004.html)
 - [ruby-overhang-spaces-005.html](https://wpt.fyi/results/css/css-ruby/ruby-overhang-spaces-005.html "css/css-ruby/ruby-overhang-spaces-005.html")
 [[(live
 test)]](http://wpt.live/css/css-ruby/ruby-overhang-spaces-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-ruby/ruby-overhang-spaces-005.html)

 ------------------------------------------------------------------------

When [ruby
annotations](#ruby-annotation-box) are not allowed to overhang, the [ruby
container](#ruby-container)
behaves like a traditional inline box, i.e. only its own contents are
rendered within its boundaries and adjacent elements do not cross the
box boundary:

![Diagram showing the ruby boxes interacting with adjacent
text](images/ro-n.gif){height="91" width="220"}

Simple ruby whose text is not allowed to overhang adjacent text

However, if a [ruby annotation
container](#ruby-annotation-container-box) is allowed to overhang, neighbouring content may
overlap the [ruby container
box](#ruby-container),
allowing its [ruby
annotation](#ruby-annotation-box)(s) to partially render over/under surrounding
inline-level content. Overhang is only allowed to the extent that it
does not cause collisions between the neighboring content and the ruby
container's [annotation boxes] or its
overlapped [base](#ruby-base-box)'s contents.

Tests

- [ruby-overhang-no-overlap.html](https://wpt.fyi/results/css/css-ruby/ruby-overhang-no-overlap.html "css/css-ruby/ruby-overhang-no-overlap.html")
 [[(live
 test)]](http://wpt.live/css/css-ruby/ruby-overhang-no-overlap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-ruby/ruby-overhang-no-overlap.html)

![Diagram showing the ruby boxes interacting with adjacent
text](images/ro-a.gif){height="91" width="177"}

Simple ruby whose text is allowed to overhang adjacent text

 Whether [ruby
annotations](#ruby-annotation-box) related to a [ruby
base](#ruby-base-box) can
overhang another [ruby base] is controlled by
[ruby-merge](#propdef-ruby-merge).

Typically, the alignment of the contents of the base or the annotation
is not affected by overhanging behavior: alignment and space
distribution (see
[ruby-align](#propdef-ruby-align)) is achieved the same way regardless of
the overhang allowance, and is computed before the space available for
overlap is determined. However, UAs may consider allowed overhang when
determining space distribution and/or alignment of annotations and
bases.

I suspect overhanging interacts with
alignment in some cases; might need to look into this later.

The user agent may use
[\[JIS4051\]](#biblio-jis4051 "Formatting rules for Japanese documents (日本語文書の組版方法).")
recommendation of using
[[0.5ic]](https://www.w3.org/TR/css-values-4/#ic) (half of a
full-width character) in the annotation's font as the maximum overhang
length. Detailed rules for how ruby text can overhang adjacent
characters for Japanese are described by
[\[JLREQ\]](#biblio-jlreq "Requirements for Japanese Text Layout 日本語組版処理の要件(日本語版)").

Additionally, for compatibility reasons, user agents must support an
additional value of [none] for the
[ruby-overhang](#propdef-ruby-overhang) property, as a [legacy value
alias](https://drafts.csswg.org/css-cascade-5/#css-legacy-value-alias) of
[spaces](#valdef-ruby-overhang-spaces).

Tests

- [ruby-overhang-dynamic.html](https://wpt.fyi/results/css/css-ruby/ruby-overhang-dynamic.html "css/css-ruby/ruby-overhang-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-ruby/ruby-overhang-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-ruby/ruby-overhang-dynamic.html)

### 5.2. Line-edge Alignment

When a [ruby annotation
box](#ruby-annotation-box) that is longer than its [ruby
base](#ruby-base-box) is at
the start or end edge of a line, the user agent *may* force the side of
the [ruby annotation] that touches the
edge of the line to align to the corresponding edge of the base. This
type of alignment is described by
[\[JLREQ\]](#biblio-jlreq "Requirements for Japanese Text Layout 日本語組版処理の要件(日本語版)").

This level of the specification does not provide a mechanism to control
this behavior.

![Diagram of glyph layout in line-edge aligned ruby when ruby text is
shorter than base](images/ra-le-l.gif){height="109" width="146"}
![Diagram of glyph layout in line-edge aligned ruby when ruby text is
longer than base](images/ra-le-r.gif){height="110" width="146"}

Line-edge alignment

## [ Appendix A: Sample Style Sheets]
*This section is informative.*

### [ [A.1] Default UA Style Sheet]
The following represents a default UA style sheet for rendering HTML and
XHTML ruby markup as ruby layout:

``` highlight
ruby { display: ruby; }
rp { display: none; }
rbc { display: ruby-base-container; }
rtc { display: ruby-text-container; }
rb { display: ruby-base; white-space: nowrap; }
rt { display: ruby-text; }
ruby, rb, rt, rbc, rtc { unicode-bidi: isolate; }

rtc, rt {
 font-variant-east-asian: ruby; /* See [[CSS-FONTS-3]] */
 text-justify: ruby; /* See [[CSS-TEXT-4]] */
 text-emphasis: none; /* See [[CSS-TEXT-DECOR-3]] */
 white-space: nowrap;
 line-height: 1; }

rtc, :not(rtc) > rt {
 font-size: 50%; }
rtc:lang(zh-TW), :not(rtc) > rt:lang(zh-TW),
rtc:lang(zh-Hanb), :not(rtc) > rt:lang(zh-Hanb), {
 font-size: 30%; } /* bopomofo */
```

 Authors should not use the above rules: a UA that
supports ruby layout should provide these by default.

UAs implementing a user-controlled "minimum font size" feature should
consider scaling that minimum down for ruby annotations.

### [ [A.2] Inlining Ruby Annotations]
The following represents a sample style sheet for rendering HTML and
XHTML ruby markup as inline annotations:

``` highlight
ruby, rb, rt, rbc, rtc, rp {
 display: inline; white-space: inherit;
 font: inherit; text-emphasis: inherit; }
```

### [ [A.3] Generating Parentheses]
Unfortunately, because Selectors cannot match against text nodes, it's
not possible with CSS to express rules that will automatically and
correctly add parentheses to unparenthesized ruby annotations for all
possible ruby markup patterns in HTML. (This is because HTML ruby allows
implying the [ruby base](#ruby-base-box) from raw text without a corresponding element.)

However, these rules will add parentheses around each annotation
sequence in cases where either `<rb>` or `<rtc>` is used rigorously:

``` highlight
/* Parens around <rtc> */
rtc::before { content: "（"; }
rtc::after { content: "）"; }

/* Parens before first <rt> not inside <rtc> */
rb + rt::before,
rtc + rt::before { content: "（"; }

/* Parens after <rt> not inside <rtc> */
rb ~ rt:last-child::after,
rt + rb::before { content: "）"; }
rt + rtc::before { content: "）（"; }
```

Alternatively, if it is known that a purely alternating style of markup
is used (`<ruby>A<rt>a</rt>B<rt>b</rt>C<rt>c</rt><ruby>`)
where there are no adjacent ruby annotations, the following rules will
add parentheses around each annotation:

``` highlight
/* Parens around each <rt> */
rt::before { content: "（"; }
rt::after { content: "）"; }
```

## 6. Glossary

[Bopomofo] or [Zhuyin Fuhao] (Chinese: [ㄅㄆㄇㄈ]{lang="zh-Bopo"}, [注音符號]{lang="zh-Hant"}, or [注音符号]{lang="zh-Hans"})

: Characters and tone markings developed for use as phonetics in
 Chinese, especially standard Mandarin. These are often, but not
 exclusively, used for ruby annotations.

 ::: figure
 ![Bopomofo characters (in blue) run vertically along the right side
 of each Hanzi character in the horizontal
 text.](images/zhuyin-example.png){height="132" width="349"}
 Example of Bopomofo used as phonetic inter-character annotations in
 Chinese
 :::

 [Bopomofo tone marks] are spacing characters that occur (in
 memory) at the end of each bopomofo syllable. They are typically
 displayed in a separate track to the right of or above the other
 bopomofo characters, and the position of the tone mark depends on
 the number of characters in the syllable. The neutral tone mark,
 however, is placed before (and in line with) the bopomofo, not
 alongside it.

 The user agent and font subsystem are responsible
 for ensuring the correct relative alignment and positioning of
 glyphs, including [bopomofo tone
 marks](#bopomofo-tone-marks), when displaying text---​whether the text occurs in
 ruby annotations or as normal inline content. Such glyph placement
 is not a function of CSS ruby layout.

 Bopomofo
 [letters](https://drafts.csswg.org/css-syntax-3/#letter) belong to the `Bopomofo` [Unicode
 script](https://drafts.csswg.org/css-text-4/#unicode-script) (and are currently mapped in the U+3100--312F and
 U+31A0--31BF blocks); the [Bopomofo tone
 marks](#bopomofo-tone-marks) are U+02C9 (ˉ), U+02CA (ˊ), U+02C7 (ˇ), U+02CB (ˋ),
 U+02EA (˪), U+02EB (˫), U+02D9 (˙). Collectively these are all
 considered [Bopomofo characters] for the purpose of CSS.

Hanja (Korean: [漢字]{lang="ko"})
: Subset of the Korean writing system that utilizes ideographic
 characters borrowed or adapted from the Chinese writing system. Also
 see [Kanji](#g-kanji).

Hiragana (Japanese: [平仮名]{lang="ja"})
: Japanese syllabic script, or character of that script. Rounded and
 cursive in appearance. Subset of the Japanese writing system, used
 together with kanji and katakana. In recent times, mostly used to
 write Japanese words when kanji are not available or appropriate,
 and word endings and particles. Also see [Katakana](#g-katakana).

Ideograph
: A character that is used to represent an idea, word, or word
 component, in contrast to a character from an alphabetic or syllabic
 script. The most well-known ideographic script is used (with some
 variation) in East Asia (China, Japan, Korea,\...).

Kana (Japanese: [仮名]{lang="ja"})
: Collective term for hiragana and katakana.

Kanji (Japanese: [漢字]{lang="ja"})
: Japanese term for ideographs; ideographs used in Japanese. Subset of
 the Japanese writing system, used together with hiragana and
 katakana. Also see [Hanja](#g-hanja).

Katakana (Japanese: [片仮名]{lang="ja"})
: Japanese syllabic script, or character of that script. Angular in
 appearance. Subset of the Japanese writing system, used together
 with kanji and hiragana. In recent times, mainly used to write
 foreign words. Also see [Hiragana](#g-hiragana).

## [ Acknowledgments]
This specification would not have been possible without the help from:

David Baron, Robin Berjon, Susanna Bowen, Stephen Deach, Martin Dürst,
Hideki Hiura ([樋浦 秀樹]{lang="ja"}), Masayasu Ishikawa
([石川雅康]{lang="ja"}), Taichi Kawabata, Chris Pratley, Xidorn Quan,
Takao Suzuki ([鈴木 孝雄]{lang="ja"}), Frank Yung-Fong Tang, Chris
Thrasher, Masafumi Yabe ([家辺勝文]{lang="ja"}), Boris Zbarsky, Steve
Zilles.

Special thanks goes to the previous editors: Michel Suignard and Marcin
Sawicki of Microsoft, and Richard Ishida of W3C.

## [ Changes]
This section documents the changes since previous publications.

### [ Changes since the 2 December 2021 WD]
- Made the computed-value adjustment of
 [writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) on [inter-character
 annotations](#ruby-position-inter-character-annotation) apply to the [ruby annotation
 box](#ruby-annotation-box) rather than the [ruby annotation container
 box](#ruby-annotation-container-box).
- Added `zh-Hant` to rule applying [font-size:
 30%](https://drafts.csswg.org/css-fonts-5/#descdef-font-face-font-size) to [ruby
 annotations](#ruby-annotation-box) in HTML.
- Added `text-justify: ruby` to the UA default style sheet. ([Issue
 771](https://github.com/w3c/csswg-drafts/issues/771) [Issue
 779](https://github.com/w3c/csswg-drafts/issues/779))

### [ Changes since the 29 April 2020 WD]
- Added
 [alternate](#valdef-ruby-position-alternate) keyword to
 [ruby-position](#propdef-ruby-position) and made it the [initial
 value](https://drafts.csswg.org/css-cascade-5/#initial-value).
- Renamed [collapse] value of
 [ruby-merge](#propdef-ruby-merge) to
 [merge](#valdef-ruby-merge-merge). ([Issue
 5004](https://github.com/w3c/csswg-drafts/issues/5004))
- Defined [visibility:
 collapse](https://drafts.csswg.org/css-display-4/#propdef-visibility) to explicitly
 [hide](#hidden-annotation) an annotation the same way
 [auto-hidden](#auto-hidden)
 annotations are hidden. ([Issue
 5927](https://github.com/w3c/csswg-drafts/issues/5927))
- Specified more precisely which properties apply to the various ruby
 display types ([§ 3.3 Styling Ruby Boxes](#box-style)) and defined
 ruby, ruby base, and ruby annotation boxes to behave the same as
 regular [inline
 boxes](https://drafts.csswg.org/css-display-4/#inline-box) except as otherwise specified. ([Issue
 4935](https://github.com/w3c/csswg-drafts/issues/4935), [Issue
 4936](https://github.com/w3c/csswg-drafts/issues/4936), [Issue
 4976](https://github.com/w3c/csswg-drafts/issues/4976), [Issue
 4979](https://github.com/w3c/csswg-drafts/issues/4979))
- Substantially revamped [§ 3 Ruby Layout](#ruby-layout) to more clearly
 define
 [interlinear](#interlinear-annotations) and
 [inter-character](#ruby-position-inter-character-annotation) ruby layout and their interaction with
 [ruby-align](#propdef-ruby-align).
 [Inter-character]
 ruby is now based on [inline
 block](https://drafts.csswg.org/css-display-4/#inline-block) layout, and its interaction with
 [interlinear] ruby is also now
 well-defined. Inline-axis space distribution for
 [interlinear] ruby is now more
 precisely defined for spanning annotations (modeled on
 [max-content](https://drafts.csswg.org/css-grid-2/#valdef-grid-template-columns-max-content) grid tracks).
- Defined handling of nested ruby by accounting for their base and
 annotation containers in the block-axis sizing of
 [interlinear](#interlinear-annotations) ruby. ([Issue
 4986](https://github.com/w3c/csswg-drafts/issues/4986), [Issue
 4980](https://github.com/w3c/csswg-drafts/issues/4980))
- Specified more precisely how
 [ruby-align](#propdef-ruby-align) works.
- Loosened requirement that ruby overhang not affect the alignment of
 ruby contents, added requirement that it not cause ruby content to
 collide with adjacent content.
- Clarified interaction of bidi reordering and [merged
 annotations](#merged-annotation). ([§ 3.5 Bidi Reordering](#bidi))
- Tightened up normative prose throughout.
- Improved [introduction](#intro), examples, and other informative text.

 There remain many open issues, see [Disposition of
Comments](https://drafts.csswg.org/css-ruby-1/issues-wd-2020) and the
[newer
issues](https://github.com/w3c/csswg-drafts/issues?q=is%3Aissue+label%3Acss-ruby-1)
tracked in GitHub.

### [ Changes since the 5 August 2014 WD]
- Add back [ruby-overhang: auto \|
 none](#propdef-ruby-overhang) for basic control over ruby overhang behavior.
- Harmonize inlinification with the [CSS Display
 Module](https://www.w3.org/TR/css-display-3/).
- Allow UA to shift ruby/emphasis marks if they conflict with
 underlines/overlines.
- Disable auto-hiding when the computed value of
 [ruby-merge](#propdef-ruby-merge) is `collapse`.
- Tweak the [default style sheet](#default-stylesheet).
- Add section defining interaction with [text
 decoration](#ruby-text-decoration).
- Defer the [right] and [left] values of
 [ruby-position](#propdef-ruby-position) to the next level.
- Change ruby [pairing](#pairing)
 rules to only apply spanning on anonymous annotations (i.e. content
 directly contained by an
 [`rtc`](https://w3c.github.io/html-ruby/#elementdef-rtc)).
- Pair excess bases / annotations with auto-generated empty anonymous
 bases / annotations.
- Apply
 [ruby-position](#propdef-ruby-position) to
 [::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line). ([Issue
 2998](https://github.com/w3c/csswg-drafts/issues/2998))
- Clarify containing block of ruby boxes and contents is, as in the case
 of other inline boxes, the nearest block container.
- Clarify handling of misparented internal table elements.
- Trim leading/trailing white space in ruby containers, base base
 containers, and annotation containers to prevent it from interfering
 with pairing.
- Define layout effect of empty base and annotation containers.
- Disable margins, padding, and borders on ruby base containers and ruby
 annotation containers (but not on ruby bases and ruby annotations).

### [ Changes since the 19 September 2013 WD]
- Rewrite anonymous box generation rules and white space handling rules,
 defined specialized [pairing](#pairing) of anonymous white space boxes.
- Take nested ruby handling out of [pairing](#pairing). (Will be handling it via sizing/layout.)
- Define bidi layout of ruby structures.

### [ Changes since the 30 June 2011 WD]
Remove `ruby-span` and mentions of `rbspan`.
: Explicit spanning is not used in HTML ruby in favor of implicit
 spanning. This can't handle some pathological double-sided spanning
 cases, but there seems to be no requirement for these at the moment.
 (For implementations that support full complex XHTML Ruby, they can
 imply spanning from the markup the same magic way that we handle
 cell spanning from tables. It doesn't seem necessary to include
 controls this in Level 1.)

Defer `ruby-overhang` and `ruby-align: line-end` to Level 2.
: It's somewhat complicated, advanced feature. Proposal is to make
 this behavior UA-defined and provide some examples of acceptable
 options.

Close issue requesting `display: rp`: use `display: none`.
: The Internationalization WG added an issue requesting a display
 value for
 [`rp`](https://w3c.github.io/html-ruby/#elementdef-rp) elements. They're supposed to be hidden when
 [`ruby`](https://w3c.github.io/html-ruby/#elementdef-ruby) is displayed as ruby. But this is easily
 accomplished already with `display: none`.

Change [ruby-position](#propdef-ruby-position) values to match [text-emphasis-position](https://drafts.csswg.org/css-text-decor-4/#propdef-text-emphasis-position).
: Other than
 [inter-character](#valdef-ruby-position-inter-character), which we need to keep, it makes more sense
 to align ruby positions with
 [text-emphasis-position](https://drafts.csswg.org/css-text-decor-4/#propdef-text-emphasis-position), which can correctly handle
 various combinations of horizontal/vertical preferences.

Remove unused values of [ruby-align](#propdef-ruby-align).
: [left], [right], and [end] are not needed.

Replace [auto], [distribute-letter], and [distribute-space] from [ruby-align](#propdef-ruby-align) with [space-between](#valdef-ruby-align-space-between) and [space-around](#valdef-ruby-align-space-around).
: The [auto] value relied on inspecting content to determine
 behavior; this can be avoided by just using
 [space-around](#valdef-ruby-align-space-around) with standard justification rules (which
 allow spacing between CJK but not between Latin). Replaced
 [distribute-letter] and [distribute-space] with
 [space-between](#valdef-ruby-align-space-between) and
 [space-around] for
 consistency with distribution keywords in
 [\[CSS-FLEXBOX-1\]](#biblio-css-flexbox-1 "CSS Flexible Box Layout Module Level 1")
 and
 [\[CSS-ALIGN-3\]](#biblio-css-align-3 "CSS Box Alignment Module Level 3")
 and to avoid any links to the definition of
 `text-justify: distribute`.

Added [ruby-merge](#propdef-ruby-merge) property to control jukugo rendering.
: This is a stylistic effect, not a structural one; the previous model
 assumed that it was structural and suggested handling it by changing
 markup. :(

Remove [inline] from [ruby-position](#propdef-ruby-position).
: This is do-able via `display: inline` on all the ruby-related
 elements, see [Appendix A](#default-inline).

Added [Default Style](#default-stylesheet) rules
: As requested by Internationalization WG.

Wrote anonymous box generation rules
: And defined [pairing](#pairing)
 of bases and annotations. Should now handle all the crazy proposed
 permutations of HTML ruby markup.

Defined layout of ruby
: Defined in detail space distribution, white space handling, line
 breaking, line stacking, etc. Open issue left for bidi.

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.
