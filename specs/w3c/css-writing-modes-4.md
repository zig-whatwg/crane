## 1. Introduction to Writing Modes

CSS Writing Modes Level 4 defines CSS features to support for various
international writing modes, such as left-to-right (e.g. Latin or
Indic), right-to-left (e.g. Hebrew or Arabic), bidirectional (e.g. mixed
Latin and Arabic) and vertical (e.g. Asian scripts).

A [writing mode] in CSS is determined by the
[writing-mode](#propdef-writing-mode),
[direction](#propdef-direction), and
[text-orientation](#propdef-text-orientation) properties. It is defined primarily
in terms of its [inline base
direction](#inline-base-direction) and [block flow
direction](#block-flow-direction):

[![Text flowing left to right, Latin glyphs set upright, and lines
stacked top to bottom](diagrams/text-flow-vectors-tb.png)](diagrams/text-flow-vectors-tb.svg)

Latin-based writing mode

[![Text flowing top to bottom, Latin glyphs tipped sideways to the right
(rotated 90° clockwise), and lines stacked left to
right](diagrams/text-flow-vectors-lr-reverse.png)](diagrams/text-flow-vectors-lr-reverse.svg)

Mongolian-based writing mode

[![Text flowing left to right, Latin glyphs set upright, and lines
stacked top to bottom](diagrams/text-flow-vectors-tb.png)](diagrams/text-flow-vectors-tb.svg) [![Text
flowing top to bottom, Latin glyphs tipped sideways to the right
(rotated 90° clockwise), and lines stacked right to
left](diagrams/text-flow-vectors-rl.png)](diagrams/text-flow-vectors-rl.svg)

Han-based writing modes

The [inline base direction] is the primary direction in which content is
ordered on a line and defines on which sides the "start" and "end" of a
line are. The
[direction](#propdef-direction) property specifies the inline base
direction of a box and, together with the
[unicode-bidi](#propdef-unicode-bidi) property and the inherent directionality
of any text content, determines the ordering of inline-level content
within a line.

The [block flow direction] is the direction in which block-level boxes
stack and the direction in which line boxes stack within a [block
container](https://drafts.csswg.org/css-display-4/#block-container). The
[writing-mode](#propdef-writing-mode) property determines the block flow
direction.

Writing systems typically have one or two native writing modes. Some
examples are:

- Latin-based systems are typically written using a left-to-right inline
 direction with a downward (top-to-bottom) block flow direction.
- Arabic-based systems are typically written using a right-to-left
 inline direction with a downward (top-to-bottom) block flow direction.
- Mongolian-based systems are typically written using a top-to-bottom
 inline direction with a rightward (left-to-right) block flow
 direction.
- Han-based systems are commonly written using a left-to-right inline
 direction with a downward (top-to-bottom) block flow direction, **or**
 a top-to-bottom inline direction with a leftward (right-to-left) block
 flow direction. Many magazines and newspapers will mix these two
 writing modes on the same page.

A [horizontal writing mode] is one with horizontal lines of text, i.e. a
downward or upward block flow. A [vertical writing
mode]
is one with vertical lines of text, i.e. a leftward or rightward block
flow.

These terms should not be confused with [vertical block
flow]
(which is a downward or upward block flow) and [horizontal block
flow] (which is leftward or rightward block flow). To avoid
confusion, CSS specifications avoid this latter set of terms.

The [typographic mode] determines whether to use typographic
conventions specific to vertical flow for [vertical
scripts](#vertical-script)
([vertical typographic mode]) or to use the typographic
conventions of [horizontal writing
modes](#horizontal-writing-mode) ([horizontal typographic
mode]). This concept distinguishes vertical typesetting from
rotated horizontal typesetting.

The
[text-orientation](#propdef-text-orientation) component of the writing mode
controls the [glyph orientation] in [vertical
typographic
modes](#vertical-typographic-mode), dictating whether a particular [typographic character
unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit) is [typeset
upright](#typeset-upright) or
[typeset sideways](#typeset-sideways).

See Unicode Technical Note #22
[\[UTN22\]](#biblio-utn22 "Robust Vertical Text Layout")
([HTML
version](http://fantasai.inkedblade.net/style/discuss/vertical-text/paper))
for a more in-depth introduction to writing modes and vertical text.

### 1.1. Module Interactions

This module replaces and extends the
[unicode-bidi](#propdef-unicode-bidi) and
[direction](#propdef-direction) features defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
sections 8.6 and 9.10. The interaction of its features with other text
operations in setting lines of text is described in [CSS Text 3 § A Text
Processing Order of
Operations](https://drafts.csswg.org/css-text-3/#order).

The [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value) of the
[writing-mode](#propdef-writing-mode),
[direction](#propdef-direction), and
[text-orientation](#propdef-text-orientation) properties (even on elements to
which these properties themselves don't apply
[\[CSS-CASCADE-4\]](#biblio-css-cascade-4 "CSS Cascading and Inheritance Level 4"))
are broadly able to influence the computed values of other, unrelated
properties through calculations such as the computation of
[font-relative
lengths](https://drafts.csswg.org/css-values-4/#font-relative-length) or the cascade of [flow-relative
properties](http://www.w3.org/TR/css-logical-1/) which purposefully
depend on the computed [writing
mode](#writing-mode) or on font
metrics that can depend on the [writing mode].

### 1.2. Value Definitions and Terminology

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

Other important terminology and concepts used in this specification are
defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
and
[\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3").

## 2. Inline Direction and Bidirectionality

While the characters in most scripts are written from left to right,
certain scripts are written from right to left. In some documents, in
particular those written with the Arabic or Hebrew script, and in some
mixed-language contexts, text in a single (visually displayed) block may
appear with mixed directionality. This phenomenon is called
[bidirectionality], or \"bidi\" for short.

![An example of bidirectional text is a Latin name in an Arabic
sentence. The sentence overall is typeset right-to-left, but the letters
in the Latin word in the middle are typeset
left-to-right.](diagrams/bidi.png){height="85" width="225"}

Bidirectionality

The Unicode standard ([Unicode Standard Annex
#9](http://www.unicode.org/reports/tr9/)) defines a complex algorithm
for determining the proper ordering of bidirectional text. The algorithm
consists of an implicit part based on character properties, as well as
explicit controls for embeddings and overrides. CSS relies on this
algorithm to achieve proper bidirectional rendering.

Two CSS properties,
[direction](#propdef-direction) and
[unicode-bidi](#propdef-unicode-bidi), provide explicit embedding,
isolation, and override controls in the CSS layer. Because the base
directionality of a text depends on the structure and semantics of the
document, the [direction] and
[unicode-bidi] properties
should in most cases be used only to map bidi information in the markup
to its corresponding CSS styles.

The HTML specifications
([\[HTML401\]](#biblio-html401 "HTML 4.01 Specification"),
section 8.2, and [HTML § 15.3.5 Bidirectional
text](https://html.spec.whatwg.org/multipage/rendering.html#bidi-rendering))
define bidirectionality behavior for HTML elements.

**If a document language provides markup features to control bidi,
authors and users should use those features instead** and not specify
CSS rules to override them.

### 2.1. Specifying Directionality: the [direction property]
Name:

[direction]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

ltr
[\|](https://drafts.csswg.org/css-values-4/#comb-one) rtl

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

ltr

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

n/a

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

Because HTML UAs can turn off CSS styling, **we recommend HTML authors
to use the HTML `dir` attribute and \<bdo\> element** to ensure correct
bidirectional layout in the absence of a style sheet. **Authors *should
not* use [direction](#propdef-direction) in HTML documents.**

This property specifies the [inline base
direction](#inline-base-direction) or directionality of any bidi paragraph, embedding,
isolate, or override established by the box. (See
[unicode-bidi](#propdef-unicode-bidi).) In addition, it informs the
ordering of [table](https://www.w3.org/TR/CSS2/tables.html) column
layout, the direction of horizontal
[overflow](https://www.w3.org/TR/CSS2/visufx.html#overflow), and the
default alignment of text within a line, and other layout effects that
depend on the box's inline base direction.

Values for this property have the following meanings:

[ltr]
: This value sets [inline base
 direction](#inline-base-direction) (bidi directionality) to
 [line-left](#line-left)-to-[line-right](#line-right).

[rtl]
: This value sets [inline base
 direction](#inline-base-direction) (bidi directionality) to
 [line-right](#line-right)-to-[line-left](#line-left).

The [direction](#propdef-direction) property has no effect on bidi
reordering when specified on inline boxes whose
[unicode-bidi](#propdef-unicode-bidi) value is
[normal](#valdef-unicode-bidi-normal), because the box does not open an additional
level of embedding with respect to the bidirectional algorithm.

The [direction](#propdef-direction) property, when specified for table
column boxes, is not inherited by cells in the column since columns are
not the ancestors of the cells in the document tree. Thus, CSS cannot
easily capture the \"dir\" attribute inheritance rules described in
[\[HTML401\]](#biblio-html401 "HTML 4.01 Specification"),
section 11.3.2.1.

### 2.2. Embeddings and Overrides: the [unicode-bidi property]
Name:

[unicode-bidi]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) embed [\|] isolate
[\|] bidi-override [\|]
isolate-override [\|] plaintext

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements, but see prose

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

Because HTML UAs can turn off CSS styling, **we recommend HTML authors
to use the HTML `dir` attribute, \<bdo\> element, and appropriate
distinction of text-level vs. grouping-level HTML element types** to
ensure correct bidirectional layout in the absence of a style sheet.
**Authors *should not* use
[unicode-bidi](#propdef-unicode-bidi) in HTML documents.**

Normally (i.e. when
[unicode-bidi](#propdef-unicode-bidi) is
[normal](#valdef-unicode-bidi-normal)) an inline box is transparent to the unicode
bidi algorithm; content is ordered as if the box's boundaries were not
there. Other values of the [unicode-bidi] property cause inline boxes to create scopes within the
algorithm, and to override the intrinsic directionality of text.

The following informative table summarizes the box-internal and
box-external effects of
[unicode-bidi](#propdef-unicode-bidi):

Effect of
non-[normal](#valdef-unicode-bidi-normal) values of
[unicode-bidi](#propdef-unicode-bidi) on inline boxes

[Outside]

[strong]

[neutral]

[Inside]

[scoped]

[embed](#valdef-unicode-bidi-embed)

[isolate](#valdef-unicode-bidi-isolate)

[override]

[bidi-override](#valdef-unicode-bidi-bidi-override)

[isolate-override](#valdef-unicode-bidi-isolate-override)

[plaintext]

---

[plaintext](#valdef-unicode-bidi-plaintext)

Values for this property have the following (normative) meanings:

[normal]
: The box does not open an additional level of embedding with respect
 to the bidirectional algorithm. For inline boxes, implicit
 reordering works across box boundaries.

[embed]

: If the box is inline, this value creates a [directional
 embedding] by opening an additional level of embedding with respect
 to the bidirectional algorithm. The direction of this embedding
 level is given by the
 [direction](#propdef-direction) property. Inside the box, reordering
 is done implicitly.

 This value has no effect on boxes that are not inline.

[isolate]

: On an inline box, this [bidi-isolates] its
 contents. This is similar to a directional embedding (and increases
 the embedding level accordingly) except that each sequence of
 inline-level boxes uninterrupted by any block boundary or [forced
 paragraph
 break](#forced-paragraph-break) is treated as an [isolated
 sequence]:

 - the content within the sequence is ordered as if inside an
 independent paragraph with the base directionality specified by
 the box's
 [direction](#propdef-direction) property.
 - for the purpose of bidi resolution in its containing bidi
 paragraph, the sequence is treated as if it were a single Object
 Replacement Character (U+FFFC).

 In effect, neither is the content inside the box bidi-affected by
 the content surrounding the box, nor is the content surrounding the
 box bidi-affected by the content or specified directionality of the
 box. However, [forced paragraph
 breaks] within the box still
 create a corresponding break in the containing paragraph.

 This value has no effect on boxes that are not inline.

[bidi-override]
: This value puts the box's immediate inline content in a [directional
 override]. For an inline, this means that the box acts like a
 [directional
 embedding](#directional-embedding) in the bidirectional algorithm, except that
 reordering within it is strictly in sequence according to the
 [direction](#propdef-direction) property; the implicit part of the
 bidirectional algorithm is ignored. For a [block
 container](https://drafts.csswg.org/css-display-4/#block-container), the override is applied to an anonymous inline box
 that surrounds all of its content.

[isolate-override]
: This combines the [isolation](#bidi-isolate) behavior of
 [isolate](#valdef-unicode-bidi-isolate) with the [directional
 override](#directional-override) behavior of
 [bidi-override](#valdef-unicode-bidi-bidi-override): to surrounding content, it is equivalent to
 [isolate], but within
 the box content is ordered as if
 [bidi-override]
 were specified. It effectively nests a [directional
 override] inside an [isolated
 sequence](#isolated-sequence).

[plaintext]

: This value behaves as
 [isolate](#valdef-unicode-bidi-isolate) except that for the purposes of the Unicode
 bidirectional algorithm, the base directionality of each of the
 box's [bidi paragraphs](#bidi-paragraph) (if a [block
 container](https://drafts.csswg.org/css-display-4/#block-container)) or [isolated
 sequences](#isolated-sequence) (if an inline) is determined by following the
 heuristic in rules P2 and P3 of the Unicode bidirectional algorithm
 (rather than by using the
 [direction](#propdef-direction) property of the box).

Following Unicode Bidirectional Algorithm clause HL3
[\[UAX9\]](#biblio-uax9 "Unicode Bidirectional Algorithm"),
values other than
[normal](#valdef-unicode-bidi-normal) effectively insert the corresponding Unicode
bidi control codes into the text stream at the start and end of the
inline element before passing the paragraph to the Unicode bidirectional
algorithm for reordering. (See [§ 2.4.2 CSS--Unicode Bidi Control
Translation, Text Reordering](#bidi-control-codes).)

Bidi control codes injected by
[unicode-bidi](#propdef-unicode-bidi) at the start/end of [display:
inline](https://drafts.csswg.org/css-display-4/#propdef-display) boxes

[unicode-bidi](#propdef-unicode-bidi) value

[direction](#propdef-direction) value

[ltr](#valdef-direction-ltr)

[rtl](#valdef-direction-rtl)

start

end

start

end

[normal](#valdef-unicode-bidi-normal)

---

---

---

---

[embed](#valdef-unicode-bidi-embed)

LRE (U+202A)

PDF (U+202C)

RLE (U+202B)

PDF (U+202C)

[isolate](#valdef-unicode-bidi-isolate)

LRI (U+2066)

PDI (U+2069)

RLI (U+2067)

PDI (U+2069)

[bidi-override](#valdef-unicode-bidi-bidi-override)\*

LRO (U+202D)

PDF (U+202C)

RLO (U+202E)

PDF (U+202C)

[isolate-override](#valdef-unicode-bidi-isolate-override)\*

FSI,LRO (U+2068,U+202D)

PDF,PDI (U+202C,U+2069)

FSI,RLO (U+2068,U+202E)

PDF,PDI (U+202C,U+2069)

[plaintext](#valdef-unicode-bidi-plaintext)

FSI (U+2068)

PDI (U+2069)

FSI (U+2068)

PDI (U+2069)

[\* The LRO/RLO+PDF pairs are also applied to the [root inline
box](https://drafts.csswg.org/css-inline-3/#root-inline-box) of a [block
container](https://drafts.csswg.org/css-display-4/#block-container) if these values of
[unicode-bidi](#propdef-unicode-bidi) were specified on the [block
container].]

Because the
[unicode-bidi](#propdef-unicode-bidi) property does not inherit, setting
[bidi-override](#valdef-unicode-bidi-bidi-override) or
[plaintext](#valdef-unicode-bidi-plaintext) on a block box will not affect any descendant
blocks. Therefore these values are best used on blocks and inlines that
do not contain any block-level structures.

Note that
[unicode-bidi](#propdef-unicode-bidi) does not affect the
[direction](#propdef-direction) property even in the case of
[plaintext](#valdef-unicode-bidi-plaintext), and thus does not affect
[direction]-dependent layout
calculations.

Because the Unicode algorithm has a limit of 125 levels of embedding,
care should be taken not to overuse
[unicode-bidi](#propdef-unicode-bidi) values other than
[normal](#valdef-unicode-bidi-normal). In particular, a value of
[inherit](https://drafts.csswg.org/css-cascade-5/#valdef-all-inherit) should be used with extreme caution in deeply
nested inline markup. However, for elements that are, in general,
intended to be displayed as blocks, a setting of [unicode-bidi:
isolate] is preferred to keep the
element together in case the
[display](https://drafts.csswg.org/css-display-4/#propdef-display) is changed to
[inline](https://drafts.csswg.org/css-display-4/#valdef-display-inline) (see example below).

### 2.3. Example of Bidirectional Text

The following example shows an XML document with bidirectional text. It
illustrates an important design principle: document language designers
should take bidi into account both in the language proper (elements and
attributes) and in any accompanying style sheets. The style sheets
should be designed so that bidi rules are separate from other style
rules, and such rules should not be overridden by other style sheets so
that the document language's bidi behavior is preserved.

In this example, lowercase letters stand for inherently left-to-right
characters and uppercase letters represent inherently right-to-left
characters. The text stream is shown below in logical backing store
order.

``` xml-example
<section dir=rtl>
 <para>HEBREW1 HEBREW2 english3 HEBREW4 HEBREW5</para>
 <para>HEBREW6 <emphasis>HEBREW7</emphasis> HEBREW8</para>
</section>
<section dir=ltr>
 <para>english9 english10 english11 HEBREW12 HEBREW13</para>
 <para>english14 english15 english16</para>
 <para>english17 <quote dir=rtl>HEBREW18 english19 HEBREW20</quote></para>
</section>
```

Since this is arbitrary XML, the style sheet is responsible for setting
the writing direction. This is the style sheet:

 /* Rules for bidi */
 [dir=rtl] {direction: rtl; unicode-bidi: isolate; }
 [dir=ltr] {direction: ltr; unicode-bidi: isolate; }

 /* Rules for presentation */
 section, para {display: block;}
 emphasis {font-weight: bold;}
 quote {font-style: italic;}

If the line length is long, the formatting of this text might look like
this:

``` ascii-art
 5WERBEH 4WERBEH english3 2WERBEH 1WERBEH

 8WERBEH 7WERBEH 6WERBEH

english9 english10 english11 13WERBEH 12WERBEH

english14 english15 english16

english17 20WERBEH english19 18WERBEH
```

The first `<section>` element is a block with a right-to-left base
direction, the second `<section>` element is a block with a
left-to-right base direction. The `<para>`s are blocks that inherit the
base direction from their parents. Thus, the first two `<para>`s are
read starting at the top right, the final three are read starting at the
top left.

The `<emphasis>` element is inline-level, and since its value for
[unicode-bidi](#propdef-unicode-bidi) is
[normal](#valdef-unicode-bidi-normal) (the initial value), it has no effect on the
ordering of the text.

The `<quote>` element, on the other hand, creates an [isolated
sequence](#isolated-sequence) with the given internal directionality. Note that this
causes `HEBREW18` to be to the right of `english19`.

If lines have to be broken, the same text might format like this:

``` ascii-art
 2WERBEH 1WERBEH
 -EH 4WERBEH english3
 5WERB

 -EH 7WERBEH 6WERBEH
 8WERB

english9 english10 en-
glish11 12WERBEH
13WERBEH

english14 english15
english16

english17 18WERBEH
20WERBEH english19
```

Notice that because `HEBREW18` must be read before
`english19`, it is on the line above `english19`. Just
breaking the long line from the earlier formatting would not have
worked.

Note also that the first syllable from `english19` might have
fit on the previous line, but hyphenation of left-to-right words in a
right-to-left context, and vice versa, is usually suppressed to avoid
having to display a hyphen in the middle of a line.

### 2.4. Applying the Bidirectional Reordering Algorithm

User agents that support bidirectional text must apply the Unicode
bidirectional algorithm to every sequence of inline-level boxes
uninterrupted by any block boundary or "[bidi type
B](http://www.unicode.org/reports/tr9/#Bidirectional_Character_Types)"
[forced paragraph break]. This sequence forms the
[paragraph] unit in the bidirectional algorithm.

#### 2.4.1. Bidi Paragraph Embedding Levels

In CSS, the paragraph embedding level must be set (following [UAX9
clause HL1](http://www.unicode.org/reports/tr9/#HL1)) according to the
[direction](#propdef-direction) property of the paragraph's containing
block rather than by the heuristic given in steps
[P2](http://www.unicode.org/reports/tr9/#P2) and
[P3](http://www.unicode.org/reports/tr9/#P2) of the Unicode algorithm.

There is, however, one exception: when the computed
[unicode-bidi](#propdef-unicode-bidi) of the paragraph's containing block
is
[plaintext](#valdef-unicode-bidi-plaintext), the Unicode heuristics in P2 and P3 are used as
described in
[\[UAX9\]](#biblio-uax9 "Unicode Bidirectional Algorithm"),
without the HL1 override.

#### 2.4.2. CSS--Unicode Bidi Control Translation, Text Reordering

The final order of characters within each [bidi
paragraph](#bidi-paragraph) is
the same as if the bidi control codes had been added as described for
[unicode-bidi](#propdef-unicode-bidi) (above), markup had been stripped,
and the resulting character sequence had been passed to an
implementation of the Unicode bidirectional algorithm for plain text
that produced the same line-breaks as the styled text.

Note that bidi control codes in the source text are still honored, and
might not correspond to the document tree structure. This can split
inlines or interfere with bidi start/end control pairing in interesting
ways.

#### 2.4.3. Bidi Treatment of Atomic Inlines

In this process, [replaced
elements](https://drafts.csswg.org/css-display-4/#replaced-element) with [display:
inline](https://drafts.csswg.org/css-display-4/#propdef-display) are treated as neutral characters, unless
their
[unicode-bidi](#propdef-unicode-bidi) property is either
[embed](#valdef-unicode-bidi-embed) or
[bidi-override](#valdef-unicode-bidi-bidi-override), in which case they are treated as strong
characters in the
[direction](#propdef-direction) specified for the element. (This is so
that, in case the replaced element falls back to rendering inlined text
content, its bidi effect on the surrounding text is consistent with its
replaced rendering.)

All other atomic inline-level boxes are treated as neutral characters
always.

#### 2.4.4. Paragraph Breaks Within Embeddings and Isolates

If an inline box is broken around a [bidi
paragraph](#bidi-paragraph)
boundary (e.g. if split by a block or [forced paragraph
break](#forced-paragraph-break)), then the
[HL3](http://www.unicode.org/reports/tr9/#HL3) bidi control codes
assigned to the end of the box are also added before the interruption
and the codes assigned to the start of the box are also added after it.
(In other words, any embedding levels, isolates, or overrides started by
the box are closed at the paragraph break and reopened on the other side
of it.)

For example, where \<BR/\> is a [forced paragraph
break](#forced-paragraph-break) the bidi ordering is identical between

 <para>...<i1><i2>...<BR/>...</i2></i1>...</para>

and

 <para>...<i1><i2>...</i2></i1><BR/><i1><i2>...</i2></i1>...</para>

for all values of
[unicode-bidi](#propdef-unicode-bidi) on inline elements \<i1\> and
\<i2\>.

Note that this behavior is applied by CSS for CSS-declared bidi controls
applied to the box tree; it does not apply to Unicode's bidi formatting
controls, which are defined to terminate their effect at the end of the
bidi paragraph.

#### 2.4.5. Reordering-induced Box Fragmentation

Since bidi reordering can split apart and reorder text that is logically
contiguous, bidirectional text can cause an [inline
box](https://drafts.csswg.org/css-display-4/#inline-box) containing such text to be split and its fragments
reordered within a line.

##### 2.4.5.1. Conditions of Reordering-induced Box Fragmentation

When bidi reordering would split apart an inline box due to intervening
content, the inline box is considered to be broken into multiple [box
fragments](https://drafts.csswg.org/css-break-4/#box-fragment).
[\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3")
The box is considered to be thus
[fragmented](https://drafts.csswg.org/css-break-3/#fragment) if it would be divided by intervening content on an
infinitely long line, even if line breaking happens to result in both
[box fragments] being placed adjacent to each
other on the line. In such cases, the nearest common ancestor of text in
the two [box fragments] (which determines
certain aspects of text formatting such as
[tracking](https://drafts.csswg.org/css-text-4/#tracking) and
[justification](https://www.w3.org/TR/css-text/#text-justify-property)
between the two [box fragments], see
[\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3"))
is considered to be the nearest common ancestor of the two [box
fragments], not the [inline
box](https://drafts.csswg.org/css-display-4/#inline-box) itself. However, an [inline box]
is not considered to be broken into multiple [box
fragments] due to bidi reordering if no
intervening content would force it to split. (These rules maintain the
integrity of an [inline box] where possible, while
keeping bidi-induced fragmentation stable across variations in
line-breaking.)

In the following example, where
lowercase letters represent LTR letters and uppercase letters represent
RTL letters, bidi reordering causes the `<em>`'s [inline
box](https://drafts.csswg.org/css-display-4/#inline-box) to be divided into two [box
fragments](https://drafts.csswg.org/css-break-4/#box-fragment) separated by text outside the `<em>`.

Source code (logical order):

 <p>here is <em>some MIXED</em> TEXT.</p>

Rendering (visual order) in a wide containing block, resulting in two
inline box fragments separated by external content:

 here is some TXET DEXIM.

Rendering (visual order) in a narrow containing block, resulting in two
inline box fragments placed adjacent to each other:

 here is some DEXIM
 TXET.

By contrast, in this example, where
the mixed-direction phrase is kept together with an isolation, only one
fragment is generated---​the surrounding content will never split the
`<em>`'s [inline
box](https://drafts.csswg.org/css-display-4/#inline-box) even inside an infinitely-long containing block:

Source code (logical order):

 <p>here is <em dir=rtl>some MIXED</em> TEXT.</p>

Rendering (visual order) in a wide containing block, resulting in one
fragment:

 here is some DEXIM TXET.

Rendering (visual order) in a narrow containing block, resulting in one
fragment:

 here is some DEXIM
 TXET.

##### 2.4.5.2. Box Model of Reordering-induced Box Fragments

For each line box, UAs must take the fragments of each inline box and
assign the margins, borders and padding in visual order (not logical
order). The [start](#css-start)-most
fragment on the first line box in which the box appears has the
[start] edge's margin, border, and padding; and the
end-most fragment on the last line box in which the box appears has the
[end](#css-end) edge's margin, border,
and padding. For example, in the
[horizontal-tb](#valdef-writing-mode-horizontal-tb) writing mode:

- When the parent's
 [direction](#propdef-direction) property is
 [ltr](#valdef-direction-ltr), the left-most box fragment on the first line box
 in which the box appears has the left margin, left border and left
 padding, and the right-most box fragment on the last line box in which
 the box appears has the right padding, right border and right margin.
- When the parent's
 [direction](#propdef-direction) property is
 [rtl](#valdef-direction-rtl), the right-most fragment of the first line box in
 which the box appears has the right padding, right border and right
 margin, and the left-most fragment of the last line box in which the
 box appears has the left margin, left border and left padding.

Analogous rules hold for vertical writing modes.

The
[box-decoration-break](https://drafts.csswg.org/css-break-4/#propdef-box-decoration-break) property can override this behavior
to draw box decorations on both sides of each fragment.
[\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3")

## 3. Vertical Writing Modes

In addition to extensions to CSS2.1's support for bidirectional text,
this module introduces the rules and properties needed to support
vertical text layout in CSS.

### 3.1. Introduction to Vertical Writing

*This subsection is non-normative.*

Unlike languages that use the Latin script which are primarily laid out
horizontally, Asian languages such as Chinese and Japanese can be laid
out vertically. The Japanese example below shows the same text laid out
horizontally and vertically. In the horizontal case, text is read from
left to right, top to bottom. For the vertical case, the text is read
top to bottom, right to left. Indentation from the left edge in the
left-to-right horizontal case translates to indentation from the top
edge in the top-to-bottom vertical case.

![A comparison of horizontal and vertical Japanese shows that although
the lines rotate, the characters remain upright. Some glyphs, however
change: a period mark shifts from the bottom left of its glyph box to
the top right. Running headers, however, may remain laid out
horizontally across the top of the
page.](images/vert-horiz-comparison.png){height="583" width="811"}

Comparison of vertical and horizontal Japanese: iBunko application (iOS)

For Chinese and Japanese lines are ordered either right to left or top
to bottom, while for Mongolian and Manchu lines are ordered left to
right.

The change from horizontal to vertical writing can affect not just the
layout, but also the typesetting. For example, the position of a
punctuation mark within its spacing box can change from the horizontal
to the vertical case, and in some cases alternate glyphs are used.

Vertical text that includes Latin script text or text from other scripts
normally displayed horizontally can display that text in a number of
ways. For example, Latin words can be rotated sideways, or each letter
can be oriented upright:

![A dictionary definition for ヴィルス might write the English word
\'virus\' rotated 90° clockwise, but stack the letters of the
initialisms \'RNA\' and \'DNA\'
upright.](images/vert-latin-layouts.png){height="597" width="465"}

Examples of Latin in vertical Japanese: Daijirin Viewer 1.4 (iOS)

In some special cases such as two-digit numbers in dates, text is fit
compactly into a single vertical character box:

![An excerpt from MacFan shows several possible vertical layouts for
numbers: the two-digit month and day are written as
horizontal-in-vertical blocks; the years are written with each character
upright; except in the English phrase "for Mac 2011", where the date is
rotated to match the rotated
Latin.](images/vert-number-layouts.png){height="523" width="539"}

Mac Fan, December 2010, p.49

Layouts often involve a mixture of vertical and horizontal elements:

![Magazines often mix horizontal and vertical layout; for example, using
one orientation for the main article text and a different one for
sidebar or illustrative
content.](images/vert-horiz-combination.png){height="436" width="360"}

Mixture of vertical and horizontal elements

Vertical text layouts also need to handle bidirectional text layout;
clockwise-rotated Arabic, for example, is laid out bottom-to-top.

### 3.2. Block Flow Direction: the [writing-mode property]
Name:

[writing-mode]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

horizontal-tb
[\|](https://drafts.csswg.org/css-values-4/#comb-one) vertical-rl [\|] vertical-lr
[\|] sideways-rl [\|]
sideways-lr

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

horizontal-tb

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

All elements except table row groups, table column groups, table rows,
table columns, ruby base containers, ruby annotation containers

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

n/a

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

This property specifies whether lines of text are laid out horizontally
or vertically and the direction in which blocks progress. Possible
values:

[horizontal-tb]
: Top-to-bottom [block flow
 direction](#block-flow-direction). Both the [writing
 mode](#writing-mode) and the
 [typographic mode](#typographic-mode) are horizontal.

[vertical-rl]
: Right-to-left [block flow
 direction](#block-flow-direction). Both the [writing
 mode](#writing-mode) and the
 [typographic mode](#typographic-mode) are vertical.

[vertical-lr]
: Left-to-right [block flow
 direction](#block-flow-direction). Both the [writing
 mode](#writing-mode) and the
 [typographic mode](#typographic-mode) are vertical.

[sideways-rl]
: Right-to-left [block flow
 direction](#block-flow-direction). The [writing
 mode](#writing-mode) is
 vertical, while the [typographic
 mode](#typographic-mode)
 is horizontal.

[sideways-lr]
: Left-to-right [block flow
 direction](#block-flow-direction). The [writing
 mode](#writing-mode) is
 vertical, while the [typographic
 mode](#typographic-mode)
 is horizontal.

The [writing-mode](#propdef-writing-mode) property specifies the [block flow
direction](#block-flow-direction), which determines the ordering direction of block-level
boxes in a block formatting context; the ordering direction of line
boxes in a [block
container](https://drafts.csswg.org/css-display-4/#block-container) that contains inlines; the ordering direction of rows
in a table; etc. By virtue of determining the stacking direction of line
boxes, the [writing-mode]
property also determines whether the line boxes\' orientation (and thus
the [writing mode](#writing-mode)) is horizontal or vertical. The
[text-orientation](#propdef-text-orientation) property then determines how text
is laid out within the line box.

The content of [replaced
elements](https://drafts.csswg.org/css-display-4/#replaced-element) do not rotate due to the writing mode: images and
external content such as from `<iframe>`s, for example, remain upright,
and the [default object
size](https://drafts.csswg.org/css-images-3/#default-object-size) of 300px×150px does not re-orient. However embedded
replaced content involving text (such as MathML content or form
elements) should match the replaced element's writing mode and line
orientation if the UA supports such a vertical writing mode for the
replaced content.

In the following example, two block elements (1 and 3) separated by an
image (2) are presented in various flow writing modes.

Here is a diagram of horizontal writing mode
(`writing-mode: horizontal-tb`):

![Diagram of horizontal layout: blocks 1, 2, and 3 are stacked
top-to-bottom](images/horizontal.png){height="300" width="219"}

Here is a diagram for the right-to-left vertical writing mode commonly
used in East Asia (`writing-mode: vertical-rl`):

![Diagram of a right-to-left vertical layout: blocks 1, 2, and 3 are
arranged side by side from right to
left](images/vertical-rl.png){height="191" width="297"}

And finally, here is a diagram for the left-to-right vertical writing
mode used for Manchu and Mongolian (`writing-mode: vertical-lr`):

![Diagram of left-to-right vertical layout: blocks 1, 2, and 3 are
arranged side by side from left to
right](images/vertical-lr.png){height="191" width="300"}

In the following example, some form controls are rendered inside a block
with
[vertical-rl](#valdef-writing-mode-vertical-rl) writing mode. The form controls are rendered to
match the writing mode.

 <style>
 form { writing-mode: vertical-rl; }
 </style>
 ...
 <form>
 <p><label>姓名　<input value="艾俐俐"></label>
 <p><label>语言　<select><option>English
 <option>français
 <option>فارسی
 <option>中文
 <option>日本語</select></label>
 </form>

![Screenshot of vertical layout: the input element is laid lengthwise
from top to bottom and its contents rendered in a vertical typographic
mode, matching the labels outside it. The drop-down selection control
after it slides out to the side (towards the after edge of the block)
rather than downward as it would in horizontal writing
modes.](images/vertical-form.png){height="266" width="182"}

If a box has a different
[writing-mode](#propdef-writing-mode) value than its parent box (i.e.
nearest ancestor without [display:
contents](https://drafts.csswg.org/css-display-4/#propdef-display)):

- If the box would otherwise become an
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) box with a computed
 [display](https://drafts.csswg.org/css-display-4/#propdef-display) of
 [inline](https://drafts.csswg.org/css-display-4/#valdef-display-inline), its [display] computes instead to
 [inline-block](https://drafts.csswg.org/css-display-4/#valdef-display-inline-block).
- If the box is a [block
 container](https://drafts.csswg.org/css-display-4/#block-container), then it establishes an
 [independent](https://drafts.csswg.org/css-display-4/#independent-formatting-context) [block formatting
 context](https://drafts.csswg.org/css-display-4/#block-formatting-context).
- More generally, if its specified [inner display
 type](https://drafts.csswg.org/css-display-4/#inner-display-type) is
 [flow](https://drafts.csswg.org/css-display-4/#valdef-display-flow), then its computed [inner display
 type] becomes
 [flow-root](https://drafts.csswg.org/css-display-4/#valdef-display-flow-root).
 [\[CSS-DISPLAY-3\]](#biblio-css-display-3 "CSS Display Module Level 3")

As all other inherited CSS properties do, the
[writing-mode](#propdef-writing-mode) property inherits to SVG elements
inlined (rather than linked) into the source document. This could cause
unintentional side effects when, for example, an SVG image designed only
for horizontal flow was embedded into a vertical flow document.

Authors can prevent this from happening by adding the following rule:

svg { writing-mode: initial; }

#### 3.2.1. Obsolete SVG1.1 [writing-mode Values]
SVG1.1
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)")
defines some additional values: [lr], [lr-tb], [rl],
[rl-tb], [tb], and [tb-rl].

These values are *obsolete* in any context except SVG1 documents and are
therefore *optional* for non-SVG UAs.

##### 3.2.1.1. Supporting SVG1.1 [writing-mode values in CSS syntax]
UAs that wish to support these values in the context of CSS must compute
them as follows:

Mapping of Obsolete SVG1.1
[writing-mode](#propdef-writing-mode) values to modern CSS

Specified

Computed

[lr]

[horizontal-tb](#valdef-writing-mode-horizontal-tb)

[lr-tb]

[rl]

[rl-tb]

[tb]

[vertical-rl](#valdef-writing-mode-vertical-rl)

[tb-rl]

The SVG1.1 values were also present in an older of the CSS
[writing-mode](#propdef-writing-mode) specification, which is obsoleted
by this specification. The additional [tb-lr] value of that
revision is replaced by
[vertical-lr](#valdef-writing-mode-vertical-lr).

##### 3.2.1.2. Supporting SVG1.1 [writing-mode values in presentational attributes]
In order to support legacy content with presentational attributes, and
to allow authors to create documents that support older clients, SVG UAs
must add the following style sheet rules to their default UA stylesheet:

``` highlight
@namespace svg "http://www.w3.org/2000/svg";
svg|*[writing-mode=lr], svg|*[writing-mode=lr-tb],
svg|*[writing-mode=rl], svg|*[writing-mode=rl-tb] {
 writing-mode: horizontal-tb; }
svg|*[writing-mode=tb], svg|*[writing-mode=tb-rl] {
 writing-mode: vertical-rl; }
```

Authors who wish to create forwards and backwards-compatible SVG content
in CSS syntax can use the CSS forwards-compatible parsing rules to do
so, e.g.

 svg|text { writing-mode: tb; writing-mode: vertical-rl; }

## 4. Inline-level Alignment

When different kinds of inline-level content are placed together on a
line, the baselines of the content and the settings of the
[vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align) property control how they are
aligned in the transverse direction of the line box. This section
discusses what baselines are, how to find them, and how they are used
together with the [vertical-align] property to determine the alignment of inline-level content.

### 4.1. Introduction to Baselines

*This section is non-normative.*

A [baseline] is
a line along the [inline axis](#inline-axis) of a line box along which individual glyphs of text are
aligned. Baselines guide the design of glyphs in a font (for example,
the bottom of most alphabetic glyphs typically align with the alphabetic
baseline), and they guide the alignment of glyphs from different fonts
or font sizes when typesetting.

![Picture of alphabetic text in two font sizes with the baseline and
em-boxes](images/alphabetic-baseline-in-two-font-sizes.svg){width="480"}

Alphabetic text in two font sizes with the baseline and em-boxes

Different writing systems prefer different baseline tables.

![Latin prefers the alphabetic baseline, on top of which most letters
rest, though some have descenders that dangle below it. Indic scripts
are sometimes typeset with a hanging baseline, since their glyph shapes
appear to be hanging from a horizontal line. Han-based systems, whose
glyphs are designed to fill a square, tend to align on their
bottoms.](images/script-preferred-baselines.gif){height="110"
width="458"}

Preferred baselines in various writing systems

A well-constructed font contains a [baseline table], which indicates the position
of one or more baselines within the font's design coordinate space. (The
design coordinate space is scaled with the font size.)

!(images/baselines.gif){height="102" width="587"}

In a well-designed mixed-script font, the glyphs are positioned in the
coordinate space to harmonize with one another when typeset together.
The baseline table is then constructed to match the shape of the glyphs,
each baseline positioned to match the glyphs from its preferred scripts.

The baseline table is a property of the font, and the positions of the
various baselines apply to all glyphs in the font.

Different baseline tables can be provided for alignment in horizontal
and vertical text. UAs should use the vertical tables in vertical
[typographic modes](#typographic-mode) and the horizontal tables otherwise.

### 4.2. Text Baselines

In this specification, only the following baselines are considered:

alphabetic
: The [alphabetic baseline], which typically aligns with the bottom
 of uppercase Latin glyphs.

central
: The ideographic [central baseline], which typically crosses
 the center of the em box. If the font is missing this baseline, it
 is assumed to be halfway between the ascender
 ([over](#over)) and descender
 ([under](#under)) edges of the
 ideographic em box.

In vertical [typographic
mode](#typographic-mode),
the [central baseline](#central-baseline) is used as the dominant baseline when
[text-orientation](#propdef-text-orientation) is
[mixed](#valdef-text-orientation-mixed) or
[upright](#valdef-text-orientation-upright). Otherwise the [alphabetic
baseline](#alphabetic-baseline) is used.

A future CSS module will deal with baselines in more detail and allow
the choice of other dominant baselines and alignment options.

### 4.3. Atomic Inline Baselines

If an [atomic
inline](https://www.w3.org/TR/CSS2/visuren.html#inline-boxes) (such as
an inline-block, inline-table, or replaced inline element) does not have
a baseline, then the UA synthesizes a baseline table thus:

alphabetic
: The alphabetic baseline is assumed to be at the
 [under](#under) margin edge.

central
: The central baseline is assumed to be halfway between the
 [under](#under) and
 [over](#over) margin edges of the
 box.

The
[vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align) property in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
defines the baseline of inline-table and inline-block boxes with some
exceptions.

### 4.4. Baseline Alignment

The [dominant baseline] (which [can change](#text-baselines) based
on the [typographic mode](#typographic-mode)) is used in CSS for alignment in two cases:

- **Aligning glyphs from different fonts within the same inline box.**
 The glyphs are aligned by matching up the positions of the dominant
 baseline in their corresponding fonts.
- **Aligning a child inline-level box within its parent.** For the
 [vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align) value of
 [baseline](https://drafts.csswg.org/css2/#valdef-vertical-align-baseline), child is aligned to the parent by matching
 the parent's dominant baseline to the same baseline in the child.
 (E.g. if the parent's dominant baseline is alphabetic, then the
 child's alphabetic baseline is matched to the parent's alphabetic
 baseline, even if the child's dominant baseline is something else.)
 For values of
 [sub](https://drafts.csswg.org/css-inline-3/#valdef-baseline-shift-sub),
 [super](https://drafts.csswg.org/css-inline-3/#valdef-baseline-shift-super), [\<length\>], and
 [\<percentage\>], the baselines are aligned as for
 [baseline], but the
 child is shifted according to the offset given by its
 [vertical-align] value.

 ::::
 (#example-a67ec7df)
 Given following sample markup:

 <p><span class="outer">Ap <span class="inner">ਜੀ</span></span></p>

 And the following style rule:

 span.inner { font-size: .75em; }

 The baseline tables of the parent (`.outer`) and the child (`.inner`)
 will not match up due to the font size difference. Since the dominant
 baseline is the alphabetic baseline, the child box is aligned to its
 parent by matching up their alphabetic baselines.

 ::: figure
 !(images/baseline-align-sizes.gif){height="98" width="233"}
 :::
 ::::

 ::::
 (#example-3b107e11)
 If we assign [vertical-align:
 super](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align) to the `.inner` element from the example
 above, the same rules are used to align the `.inner` child to its
 parent; the only difference is in addition to the baseline alignment,
 the child is shifted to the superscript position.

 span.inner { vertical-align: super; font-size: .75em; }

 ::: figure
 ![In this example, the resulting alignment is equivalent to shifting
 the parent baseline table upwards by the superscript offset, and then
 aligning the child\'s alphabetic baseline to the shifted position of
 the parent\'s alphabetic
 baseline.](images/baseline-align-super.gif){height="114" width="305"}
 :::
 ::::

## 5. Introduction to Vertical Text Layout

Each writing system has one or more native orientations. Modern scripts
can therefore be classified into three orientational categories:

[horizontal-only]
: Scripts that have horizontal, but not vertical, native orientation.
 Includes: Latin, Arabic, Hebrew, Devanagari

[vertical-only]
: Scripts that have vertical, but not horizontal, native orientation.
 Includes: Mongolian, Phags Pa

[bi-orientational]
: Scripts that have both vertical and horizontal native orientation.
 Includes: Han, Hangul, Japanese Kana

A [vertical script] is one that has a native vertical orientation: i.e. one
that is either [vertical-only](#vertical-only) or that is
[bi-orientational](#bi-orientational). A [horizontal script] is one that has a native
horizontal orientation: i.e. one that is either
[horizontal-only](#horizontal-only) or that is
[bi-orientational]. (See [Appendix
A](#script-orientations) for a categorization of scripts by native
orientation.)

![A Venn diagram of these distinctions would show two circles: one
labelled \'vertical\', the other \'horizontal\'. The overlapped region
would represent the bi-orientational scripts, while horizontal-only and
vertical-only scripts would occupy their respective circles\' exclusive
regions.](diagrams/script-orientations.png){height="159" width="500"}

In modern typographic systems, all glyphs are assigned a horizontal
orientation, which is used when laying out text horizontally. To lay out
vertical text, the UA needs to transform the text from its horizontal
orientation. This transformation is the [bi-orientational
transform], and there are two types:

rotate
: Rotate the glyph from horizontal to vertical [![Rotate the glyph
 from horizontal to vertical](diagrams/glyph-right.png)](diagrams/glyph-right.svg)

translate
: Translate the glyph from horizontal to vertical [![Translate the
 glyph from horizontal to
 vertical](diagrams/glyph-upright.png)](diagrams/glyph-upright.svg)

Scripts with a native vertical orientation have an intrinsic
[bi-orientational
transform](#bi-orientational-transform), which orients them correctly in vertical text: most
CJK (Chinese/Japanese/Korean) characters translate, that is, they are
always upright. Characters from other scripts, such as Mongolian,
rotate.

Scripts without a native vertical orientation can be either rotated (set
sideways) or translated (set upright): the transform used is a stylistic
preference depending on the text's usage, rather than a matter of
correctness. The
[text-orientation](#propdef-text-orientation) property's
[mixed](#valdef-text-orientation-mixed) and
[upright](#valdef-text-orientation-upright) values are provided to specify rotation vs.
translation of
[horizontal-only](#horizontal-only) text.

### 5.1. Orienting Text: the [text-orientation property]
Name:

[text-orientation]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

mixed
[\|](https://drafts.csswg.org/css-values-4/#comb-one) upright [\|] sideways

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

mixed

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except table row groups, rows, column groups, and columns;
and text

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

n/a

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

This property specifies the orientation of text within a line. Current
values only have an effect in vertical [typographic
modes](#typographic-mode):
the property has no effect in horizontal [typographic
modes].

Values have the following meanings:

[mixed]

: [Typographic character
 units](https://drafts.csswg.org/css-text-4/#typographic-character-unit) from horizontal-only scripts are [typeset
 sideways](#typeset-sideways), i.e. 90°
 clockwise from their standard orientation in horizontal text.
 [Typographic character units]
 from vertical scripts are typeset with their intrinsic orientation.
 See [Vertical Orientations](#vertical-orientations) for further
 details.

 This value is typical for layout of dominantly vertical-script text.

[upright]

: [Typographic character
 units](https://drafts.csswg.org/css-text-4/#typographic-character-unit) from horizontal-only scripts are [typeset
 upright](#typeset-upright), i.e. in their
 standard horizontal orientation. [Typographic character
 units] from vertical scripts
 are typeset with their intrinsic orientation and shaped normally.
 See [Vertical Orientations](#vertical-orientations) for further
 details.

 This value causes the [used
 value](https://drafts.csswg.org/css-cascade-5/#used-value) of
 [direction](#propdef-direction) to be
 [ltr](#valdef-direction-ltr), and for the purposes of bidi reordering, causes
 all characters to be treated as strong LTR.

 The [used
 value](https://drafts.csswg.org/css-cascade-5/#used-value), rather than the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value), of
 [direction](#propdef-direction) is influenced so that
 [rtl](#valdef-direction-rtl) can inherit properly into any descendants (such
 as the contents of a
 [horizontal](#horizontal-writing-mode) inline-block) where this directional override does
 not apply.

[sideways]

: Causes all text to be [typeset
 sideways](#typeset-sideways), as if in a
 horizontal layout, but rotated 90° clockwise.

![text-orientation: mixed](images/text-orientation-vr.png){height="160"
width="64"}

![text-orientation:
upright](images/text-orientation-up.png){height="160" width="64"}

![text-orientation:
sideways](images/text-orientation-sr.png){height="160" width="64"}

[mixed](#valdef-text-orientation-mixed)

[upright](#valdef-text-orientation-upright)

[sideways](#valdef-text-orientation-sideways)

[text-orientation](#propdef-text-orientation) values
([writing-mode](#propdef-writing-mode) is
[vertical-rl](#valdef-writing-mode-vertical-rl))

Changing the value of this property may affect inline-level alignment.
Refer to [Text Baselines](#text-baselines) for more details.

UAs may accept [sideways-right] as a value that computes to
[sideways](#valdef-text-orientation-sideways) if needed for backward compatibility reasons.

As of writing, major implementations do not support the automatic LTR
treatment of RTL characters for
[upright](#valdef-text-orientation-upright) typesetting. In such cases, authors may need to
explicitly specify
[unicode-bidi](#propdef-unicode-bidi) and
[direction](#propdef-direction) as in the following example:

 .vertical-upright-hebrew {
 writing-mode: vertical-rl;
 text-orientation: upright;
 unicode-bidi: bidi-override;
 direction: ltr;
 }

#### 5.1.1. Vertical Typesetting and Font Features

When typesetting text in
[vertical-rl](#valdef-writing-mode-vertical-rl) and
[vertical-lr](#valdef-writing-mode-vertical-lr) modes, text is typeset either "upright" or
"sideways" as defined below:

[upright typesetting]

: [Typographic character
 units](https://drafts.csswg.org/css-text-4/#typographic-character-unit) are individually typeset upright in vertical lines
 with vertical font metrics. The UA must synthesize vertical font
 metrics for fonts that lack them. (This specification does not
 define heuristics for synthesizing such metrics.) Additionally, font
 features (such as alternate glyphs and other transformation)
 intended for use in vertical typesetting must be used. (E.g. the
 OpenType [vert] feature must be enabled.) Furthermore,
 characters from horizontal cursive scripts (such as Arabic) are
 shaped in their isolated forms when typeset upright.

 Note that even when typeset "upright", some glyphs should appear
 rotated. For example, dashes and enclosing punctuation should be
 oriented relative to the [inline
 axis](#inline-axis). In
 OpenType, this is typically handled by glyph substitution, although
 not all fonts have alternate glyphs for all relevant codepoints.
 (East Asian fonts usually provide alternates for East Asian
 codepoints, but Western fonts typically lack any vertical
 typesetting features and East Asian fonts typically lack vertical
 substitutions for Western codepoints.) Unicode published draft data
 on which characters should appear sideways as the SVO property in
 [this data
 file](http://www.unicode.org/reports/tr50/tr50-6.Orientation.txt);
 however, this property has been abandoned for the current revision
 of
 [\[UAX50\]](#biblio-uax50 "Unicode Vertical Text Layout").

 [Typographic character
 units](https://drafts.csswg.org/css-text-4/#typographic-character-unit) which are classified as `Tr` or `Tu` in
 [\[UAX50\]](#biblio-uax50 "Unicode Vertical Text Layout")
 are expected to have alternate glyphs or positioning for typesetting
 upright in vertical text. In the case of `Tr`
 [characters](https://drafts.csswg.org/css-text-3/#character), if such vertical alternate glyphs are missing from
 the font, the UA *may wish to*
 [\[RFC6919\]](#biblio-rfc6919 "Further Key Words for Use in RFCs to Indicate Requirement Levels")
 (but is not expected to) synthesize the missing glyphs by
 [typesetting them
 sideways](#typeset-sideways) etc.

[sideways typesetting]
: [Typographic character
 units](https://drafts.csswg.org/css-text-4/#typographic-character-unit) typeset as a run rotated 90° clockwise from their
 upright orientation, using horizontal metrics and composition, and
 vertical typesetting features are not used. However, if the font has
 features meant to be enabled for sideways text that is typeset in
 vertical lines (e.g. to adjust brush stroke angles or alignment),
 those features are used. (An example of such a feature would be the
 proposed [`vrtr` OpenType font
 feature](http://blogs.adobe.com/CCJKType/2013/08/tale-of-three-features.html).)

#### 5.1.2. Mixed Vertical Orientations

[\[UAX50\]](#biblio-uax50 "Unicode Vertical Text Layout")
defines the `Vertical_Orientation` property for the default glyph
orientation of mixed-orientation vertical text. When
[text-orientation](#propdef-text-orientation) is
[mixed](#valdef-text-orientation-mixed), the UA must determine the orientation of each
[typographic character
unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit) by its `Vertical_Orientation` property: [typesetting it
upright](#typeset-upright) if its orientation
property is `U`, `Tu`, or `Tr`; or [typesetting it
sideways](#typeset-sideways) (90° clockwise
from horizontal) if its orientation property is `R`.

Note that UAX50 does not handle scripts that rotate -90° in vertical
contexts, so they will not be typeset correctly with
[mixed](#valdef-text-orientation-mixed) orientation. Use
[sideways-lr](#valdef-writing-mode-sideways-lr) for such scripts.

The OpenType [vrt2] feature, which is intended for
mixed-orientation typesetting, is not used by CSS. It delegates the
responsibility for orienting glyphs to the font designer. CSS instead
dictates the orientation through
[\[UAX50\]](#biblio-uax50 "Unicode Vertical Text Layout")
and orients glyphs by typesetting them sideways or upright as
appropriate.

#### 5.1.3. Obsolete: the SVG1.1 [glyph-orientation-vertical property]
Name:

[glyph-orientation-vertical]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) 0deg [\|] 90deg
[\|] 0 [\|] 90

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

n/a

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

n/a

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

n/a

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

n/a

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

n/a

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

n/a

Some SVG user agents will need to process documents containing the
obsolete SVG
[glyph-orientation-vertical](#propdef-glyph-orientation-vertical) property, which was defined to
accept an [auto] keyword as well as
[\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) and
[\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value) values representing multiples of 90°.
While supporting this property is *optional*, UAs that do so must alias
[glyph-orientation-vertical] as a shorthand of
[text-orientation](#propdef-text-orientation) as follows:

Shorthand
[glyph-orientation-vertical](#propdef-glyph-orientation-vertical) value

Longhand
[text-orientation](#propdef-text-orientation) value

[auto]

[mixed](#valdef-text-orientation-mixed)

[0deg]

[upright](#valdef-text-orientation-upright)

[0]

[upright](#valdef-text-orientation-upright)

[90deg]

[sideways](#valdef-text-orientation-sideways)

[90]

[sideways](#valdef-text-orientation-sideways)

UAs must ignore and treat as invalid any other values for the
[glyph-orientation-vertical](#propdef-glyph-orientation-vertical) property; and treat as invalid the
[glyph-orientation-horizontal]
property in its entirety.

 The [180deg] and [270deg] values, the
radian and gradian values, and the [glyph-orientation-horizontal] property are not mapped because they
have no known use cases nor significant amounts of dependent content,
and are therefore not part of CSS, and have been likewise dropped from
SVG.

## 6. Abstract Box Terminology

CSS2.1
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
defines the box layout model of CSS in detail, but only for the
[horizontal-tb](#valdef-writing-mode-horizontal-tb) writing mode. Layout is analogous in writing
modes other than
[horizontal-tb];
however directional and dimensional terms in CSS2.1 must be abstracted
and remapped appropriately.

This section defines abstract directional and dimensional terms and
their mappings in order to define box layout for other writing modes,
and to provide terminology for future specs to define their layout
concepts abstractly. (The next section explains how to apply them to
CSS2.1 layout calculations and how to handle [orthogonal
flows](#orthogonal-flows).) Although they derive from the behavior of
text, these abstract mappings exist even for boxes that do not contain
any line boxes: they are calculated directly from the values of the
[writing-mode](#propdef-writing-mode) and
[direction](#propdef-direction) properties.

There are three sets of directional terms in CSS:

[physical]
: Interpreted relative to the page, independent of writing mode. The
 [physical directions] are
 [left], [right],
 [top], and [bottom].

[[flow-relative](#logical-directions)]
: Interpreted relative to the flow of content. The flow-relative
 directions are [start](#css-start) and [end](#css-end), or
 [block-start](#block-start),
 [block-end](#block-end),
 [inline-start](#inline-start), and [inline-end](#inline-end) if the dimension is also ambiguous.

[[line-relative](#line-directions)]
: Interpreted relative to the orientation of the line box. The
 line-relative directions are
 [line-left](#line-left),
 [line-right](#line-right),
 [line-over](#line-over), and
 [line-under](#line-under).

The [physical dimensions] are [width] and [height], which correspond to measurements along the
[x-axis] ([horizontal
dimension]) and [y-axis] ([vertical
dimension]), respectively. [Abstract dimensions](#abstract-axes) are
identical in both flow-relative and line-relative terms, so there is
only one set of these terms.

![Physical & flow-relative terms as applicable to typical English text
layout](diagrams/sizing-ltr-tb.svg)

![Physical & flow-relative terms as applicable to vertical Chinese text
layout](diagrams/sizing-ttb-rl.svg)

Note:
[\[CSS-FLEXBOX-1\]](#biblio-css-flexbox-1 "CSS Flexible Box Layout Module Level 1")
also defines [flex-relative
terms](https://www.w3.org/TR/css-flexbox/#box-model), which are used in
describing flex layout.

### 6.1. Abstract Dimensions

The [abstract dimensions] are defined below:

[block dimension]
: The dimension perpendicular to the flow of text within a line, i.e.
 the [vertical
 dimension](#vertical-dimension) in horizontal writing modes, and the [horizontal
 dimension](#horizontal-dimension) in vertical writing modes.

[inline dimension]
: The dimension parallel to the flow of text within a line, i.e. the
 [horizontal
 dimension](#horizontal-dimension) in horizontal writing modes, and the [vertical
 dimension](#vertical-dimension) in vertical writing modes.

[block axis]
: The axis in the block dimension, i.e. the [vertical
 axis](#y-axis) in horizontal
 writing modes and the [horizontal axis](#x-axis) in vertical writing modes.

[inline axis]
: The axis in the inline dimension, i.e. the [horizontal
 axis](#x-axis) in horizontal
 writing modes and the [vertical axis](#y-axis) in vertical writing modes.

[block size]\
[logical height]
: A measurement in the block dimension: refers to the physical height
 (vertical dimension) in horizontal writing modes, and to the
 physical width (horizontal dimension) in vertical writing modes.

[inline size]\
[logical width]
: A measurement in the inline dimension: refers to the physical width
 (horizontal dimension) in horizontal writing modes, and to the
 physical height (vertical dimension) in vertical writing modes.

### 6.2. Flow-relative Directions

The [flow-relative directions],
[block-start](#block-start),
[block-end](#block-end),
[inline-start](#inline-start),
and [inline-end](#inline-end), are
defined relative to the flow of content on the page. In an [LTR]
[horizontal-tb](#valdef-writing-mode-horizontal-tb) writing mode, they correspond to the top,
bottom, left, and right directions, respectively. They are defined as
follows:

[block-start]
: The side that comes earlier in the [block flow
 direction](#block-flow-direction), as determined by the
 [writing-mode](#propdef-writing-mode) property: the physical top in
 [horizontal-tb](#valdef-writing-mode-horizontal-tb) mode, the right in
 [vertical-rl](#valdef-writing-mode-vertical-rl), and the left in
 [vertical-lr](#valdef-writing-mode-vertical-lr).

[block-end]
: The side opposite [block-start](#block-start).

[inline-start]
: The side from which text of the inline base direction would start.
 For boxes with a used
 [direction](#propdef-direction) value of
 [ltr](#valdef-direction-ltr), this means the
 [line-left](#line-left) side.
 For boxes with a used [direction] value of
 [rtl](#valdef-direction-rtl), this means the
 [line-right](#line-right)
 side.

[inline-end]
: The side opposite [start](#css-start).

Where contextually unambiguous or encompassing both meanings, the terms
[start] and [end] are used in
place of [block-start](#block-start)/[inline-start](#inline-start) and [block-end](#block-end)/[inline-end](#inline-end), respectively.

Note that while determining the
[block-start](#block-start) and
[block-end](#block-end) sides of a
box depends only on the
[writing-mode](#propdef-writing-mode) property, determining the
[inline-start](#inline-start)
and [inline-end](#inline-end)
sides of a box depends not only on the
[writing-mode] property but
also the [direction](#propdef-direction) property.

### 6.3. Line-relative Directions

The [line orientation] determines which side of a line box is the
logical "top" (ascender side). It is given by the
[writing-mode](#propdef-writing-mode) property. Usually the line-relative
"top" corresponds to the
[block-start](#block-start) side,
but this is not always the case: in Mongolian typesetting (and thus by
default in
[vertical-lr](#valdef-writing-mode-vertical-lr) writing modes), the line-relative "top"
corresponds to the [block-end](#block-end) side. Hence the need for distinct terminology.

![Mongolian mixed with English](images/mongolian-lr.jpg){height="430"
width="531"}

A primarily Mongolian document, such as the one above, is written in
vertical lines stacking left to right, but lays its Latin text with the
tops of the glyphs towards the right. This makes the text run in the
same inline direction as Mongolian (top-to-bottom) and face the same
direction it does in other East Asian layouts (which have vertical lines
stacking right to left), but the glyphs\' tops are facing the bottom of
the line stack rather than the top, which in an English paragraph would
be upside-down. (See this [Diagram of Mongolian Text
Layout](diagrams/text-flow-vectors-lr-reverse.svg).)

In addition to a line-relative "top" and "bottom" to map things like
\'vertical-align: top\', CSS also needs to refer to a line-relative
"left" and "right" in order to map things like [text-align:
left](https://drafts.csswg.org/css-text-3/#propdef-text-align). Thus there are four [line-relative
directions], which are defined relative to
the [line orientation](#line-orientation) as follows:

[over] or [line-over]
: Nominally the side that corresponds to the ascender side or "top"
 side of a line box. (The side overlines are typically drawn on.)

[under] or [line-under]
: Opposite of [over](#over): the
 line-relative "bottom" or descender side. (The side underlines are
 typically drawn on.)

[line-left]
: The line-relative \"left\" side of a line box, which is nominally
 the side from which [LTR] text would
 start.

[line-right]
: The line-relative \"right\" side of a line box, which is nominally
 the side from which [RTL] text would
 start. (Opposite of [line-left](#line-left).)

See the [table below](#logical-to-physical) for the exact mappings
between physical and line-relative directions.

[![Line orientation compass](diagrams/line-orient-up.png)](diagrams/line-orient-up.svg)

Line orientation in
[horizontal-tb](#valdef-writing-mode-horizontal-tb)

[![Typical orientation in
vertical](diagrams/line-orient-right.png)](diagrams/line-orient-right.svg)

Line orientation in
[vertical-rl](#valdef-writing-mode-vertical-rl),
[vertical-lr](#valdef-writing-mode-vertical-lr), and
[sideways-rl](#valdef-writing-mode-sideways-rl)

[![Typical orientation in
vertical](diagrams/line-orient-left.png)](diagrams/line-orient-left.svg)

Line orientation in
[sideways-lr](#valdef-writing-mode-sideways-lr)

![Baseline of an upright glyph is drawn vertically from the top
center](images/vertical-upright-baseline.svg){height="176" width="80"}

Vertical baseline of an upright glyph

When [text-orientation:
upright](#propdef-text-orientation), the baseline is still vertical, and the
vertical baseline in the font is used, or the vertical baseline is
synthesized if the font does not provide.

Since the baseline is vertical, the definitions for
[mixed](#valdef-text-orientation-mixed) or
[sideways](#valdef-text-orientation-sideways) above still apply; i.e.,
[line-over](#line-over) is on
right, and [line-under](#line-under) is on left.

This is in line with font systems such as OpenType which defines the
ascender on right and the descender on left in their vertical metrics.

### 6.4. Abstract-to-Physical Mappings

The following table summarizes the abstract-to-physical mappings (based
on the *used*
[direction](#propdef-direction) and
[writing-mode](#propdef-writing-mode)):

Abstract-Physical Mapping

[writing-mode](#propdef-writing-mode)

[horizontal-tb](#valdef-writing-mode-horizontal-tb)

[vertical-rl](#valdef-writing-mode-vertical-rl),
[sideways-rl](#valdef-writing-mode-sideways-rl)

[vertical-lr](#valdef-writing-mode-vertical-lr)

[sideways-lr](#valdef-writing-mode-sideways-lr)

[direction](#propdef-direction)

[ltr](#valdef-direction-ltr)

[rtl](#valdef-direction-rtl)

[ltr](#valdef-direction-ltr)

[rtl](#valdef-direction-rtl)

[ltr](#valdef-direction-ltr)

[rtl](#valdef-direction-rtl)

[ltr](#valdef-direction-ltr)

[rtl](#valdef-direction-rtl)

block-size

height

width

inline-size

width

height

block-start

top

right

left

block-end

bottom

left

right

inline-start

left

right

top

bottom

top

bottom

bottom

top

inline-end

right

left

bottom

top

bottom

top

top

bottom

over

top

right

left

under

bottom

left

right

line-left

left

top

bottom

line-right

right

bottom

top

 The
[used](https://drafts.csswg.org/css-cascade-5/#used-value)
[direction](#propdef-direction) depends on the computed
[writing-mode](#propdef-writing-mode) and
[text-orientation](#propdef-text-orientation): in [vertical writing
modes](#vertical-writing-mode), a
[text-orientation] value
of
[upright](#valdef-text-orientation-upright) forces the used
[direction] to
[ltr](#valdef-direction-ltr).

## 7. Abstract Box Layout

### 7.1. Principles of Layout in Vertical Writing Modes

CSS box layout in vertical writing modes is analogous to layout in the
horizontal writing modes, following the principles outlined below:

Layout calculation rules (such as those in CSS2.1, Section 10.3) that
apply to the horizontal dimension in horizontal writing modes instead
apply to the vertical dimension in vertical writing modes. Likewise,
layout calculation rules (such as those in CSS2.1, Section 10.6) that
apply to the vertical dimension in horizontal writing modes instead
apply to the horizontal dimension in vertical writing modes. Thus:

- Layout rules that refer to the width use the height instead, and vice
 versa.

- Layout rules that refer to the [\*-left] and [\*-right]
 box properties (border, margin, padding, positioning offsets) use
 [\*-top] and [\*-bottom] instead, and vice versa, mapping
 the horizontal writing-mode rules of CSS2.1 into vertical writing-mode
 rules using the [flow-relative
 directions](#flow-relative-direction). The side of the box these properties apply to
 doesn't change: only which values are inputs to which layout
 calculations changes. The
 [margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left) property still affects the
 lefthand margin, for example; however in a
 [vertical-rl](#valdef-writing-mode-vertical-rl) writing mode it takes part in margin
 collapsing in place of
 [margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom).

- Layout rules that depend on the
 [direction](#propdef-direction) property to choose between left and
 right (e.g. overflow, overconstraint resolution, the initial value for
 [text-align](https://drafts.csswg.org/css-text-3/#propdef-text-align), table column ordering) are
 abstracted to the [start](#css-start) and [end](#css-end) sides and applied appropriately.

For example, in vertical writing modes, table rows are vertical and
table columns are horizontal. In a
[vertical-rl](#valdef-writing-mode-vertical-rl)
[mixed](#valdef-text-orientation-mixed)
[rtl](#valdef-direction-rtl) table, the first column would be on the bottom (the
[inline-start](#inline-start)
side), and the first row on the right (the
[block-start](#block-start)
side). The table's
[margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right) and
[margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left) would collapse with margins before
(on the right) and after (on the left) the table, respectively, and if
the table had [auto] values for
[margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top) and
[margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) it would be centered vertically
within its block flow.

[![Diagram of a vertical-rl mixed rtl table in a vertical block
formatting context, showing the ordering of rows, cells, and columns as
described above.](diagrams/vertical-table.png){height="299"
width="441"}](diagrams/vertical-table.svg)

Table in
[vertical-rl](#valdef-writing-mode-vertical-rl) RTL writing mode

For features such as text alignment, floating, and list marker
positioning, that primarily reference the left or right sides of the
line box or its longitudinal parallels and therefore have no top or
bottom equivalent, the [line-left](#line-left) and [line-right](#line-right) sides are used as the reference for the left and right
sides respectively.

Likewise for features such as underlining, overlining, and baseline
alignment (the unfortunately-named
[vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align)), that primarily reference the top
or bottom sides of the linebox or its transversal parallels and
therefore have no left or right equivalent, the
[line-over](#line-over) and
[line-under](#line-under) sides
are used as the reference for the top and bottom sides respectively.

The details of these mappings are provided below.

### 7.2. Dimensional Mapping

Certain properties behave logically as follows:

- The first and second values of the
 [border-spacing](https://drafts.csswg.org/css2/#propdef-border-spacing) property represent spacing
 between columns and rows respectively, not necessarily the horizontal
 and vertical spacing respectively.
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
- The
 [line-height](https://drafts.csswg.org/css2/#propdef-line-height) property always refers to the
 logical height.
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")

The height properties
([height](https://drafts.csswg.org/css-sizing-3/#propdef-height),
[min-height](https://drafts.csswg.org/css2/#propdef-min-height), and
[max-height](https://drafts.csswg.org/css2/#propdef-max-height)) refer to the physical height, and
the width properties
([width](https://drafts.csswg.org/css-sizing-3/#propdef-width),
[min-width](https://drafts.csswg.org/css2/#propdef-min-width), and
[max-width](https://drafts.csswg.org/css2/#propdef-max-width)) refer to the physical width.
However, the rules used to calculate box dimensions and positions are
logical.

For example, the calculation rules in [CSS2.1 Section
10.3](https://www.w3.org/TR/CSS2/visudet.html#Computing_widths_and_margins)
are used for the inline dimension measurements: they apply to the
[inline size](#inline-size) (which
could be either the physical width or physical height) and to the
[inline-start](#inline-start)
and [inline-end](#inline-end)
margins, padding, and border. Likewise the calculation rules in [CSS2.1
Section
10.6](https://www.w3.org/TR/CSS2/visudet.html#Computing_heights_and_margins)
are used in the block dimension: they apply to the [block
size](#block-size) and to the
[block-start](#block-start) and
[block-end](#block-end) margins,
padding, and border.
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")

As a corollary, percentages on the margin and padding properties, which
are always calculated with respect to the containing block width in
CSS2.1, are calculated with respect to the *[inline
size](#inline-size)* of the
containing block in CSS3.

### 7.3. Orthogonal Flows

We appreciate feedback in general, but we are particularly interested in
feedback on this particularly complicated section.

When a box has a different
[writing-mode](#propdef-writing-mode) from its containing block two cases
are possible:

- The two writing modes are parallel to each other. (For example,
 [vertical-rl](#valdef-writing-mode-vertical-rl) and
 [vertical-lr](#valdef-writing-mode-vertical-lr)).
- The two writing modes are perpendicular to each other. (For example,
 [horizontal-tb](#valdef-writing-mode-horizontal-tb) and
 [vertical-rl](#valdef-writing-mode-vertical-rl)).

When a box has a writing mode that is perpendicular to its containing
block it is said to be in, or establish, an [orthogonal
flow].

To handle this case, CSS layout calculations are divided into two
phases: sizing a box, and positioning the box within its flow.

- In the sizing phase---calculating the width and height of the
 box---the dimensions of the box and the containing block are mapped to
 the [inline size](#inline-size)
 and [block size](#block-size)
 and calculations are performed accordingly using the writing mode of
 the box establishing the [orthogonal
 flow](#establish-an-orthogonal-flow).
- In the positioning phase---calculating the positioning offsets,
 margins, borders, and padding---the dimensions of the box and its
 containing block are mapped to the [inline
 size](#inline-size) and [block
 size](#block-size) and
 calculations are performed according to the writing mode of the
 *containing block* of the box establishing the [orthogonal
 flow](#establish-an-orthogonal-flow).

Since [auto] margins are resolved consistent with the containing
block's writing mode, a box establishing an [orthogonal
flow](#establish-an-orthogonal-flow) can, once sized, be aligned or centered within its
containing block just like other block-level boxes by using auto
margins.

![Diagram of a vertical flow box appearing in between two horizontal
flow boxes.](images/orthogonal.svg){width="180"}

An example of orthogonal flow

For example, if a vertical block is placed inside a horizontal block,
then when calculating the physical height (which is the [inline
size](#inline-size)) of the child
block the physical height of the parent block is used as the child's
containing block [inline size], even though the
physical height is the [block size](#block-size), not the [inline size], of the
parent block.

On the other hand, because the containing block is in a horizontal
writing mode, the vertical margins on the child participate in
margin-collapsing, even though they are in the
[inline-axis](#inline-axis) of
the child, and horizontal auto margins will expand to fill the
containing block, even though they are in the
[block-axis](#block-axis) of the
child.

Note that this section
requires that when a child box auto-sized in its block axis establishes
an orthogonal flow, the used block size of the child is calculated to
fit its content; and this resulting content-based size is used as input
to the [inline-axis](#inline-axis) [min-content
size](https://drafts.csswg.org/css-sizing-3/#min-content) and [max-content
size](https://drafts.csswg.org/css-sizing-3/#max-content) of the parent.

This means that when applying shrink-to-fit formula to a box such as an
inline-block, float, or table-cell, if its child establishes an
orthogonal flow, the calculation dependency must be changed so that the
sizing phase of the child runs first and its used [block
size](#block-size) becomes an
input to the [inline-size](#inline-size) shrink-to-fit formula of the parent.

#### 7.3.1. Available Space in Orthogonal Flows

It is common in CSS for a containing block to have a definite [inline
size](#inline-size), but not a
definite [block size](#block-size). This typically happens in CSS2.1 when a containing
block has an
[auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) height, for example: its width is given by the
calculations in
[10.3.3](https://www.w3.org/TR/CSS2/visudet.html#blockwidth), but its
[block size] depends on its contents. In such
cases the [available inline
space](https://drafts.csswg.org/css-sizing-3/#available) is defined as the [inline size]
of the containing block; but the [available block
space], which would otherwise be the [block
size] of the containing block, is infinite.

Putting a box in an [orthogonal
flow](#establish-an-orthogonal-flow) can result in the opposite: for the box's [available
block
space](https://drafts.csswg.org/css-sizing-3/#available) to be definite, but its [available inline
space] to be indefinite. In such cases a percentage
of the containing block's [inline
size](#inline-size) cannot be
defined, and [inline axis](#inline-axis) computations cannot be resolved. In these cases, an
additional constraint is used as a
[fallback](https://drafts.csswg.org/css-sizing-3/#fallback) in place of the [available inline
space] for calculations that require a definite
[available inline space]---​the smallest of

- the size represented by the containing block's inner [max
 size](https://drafts.csswg.org/css-sizing-3/#max-width) (if that is fixed) floored by its inner [min
 size](https://drafts.csswg.org/css-sizing-3/#min-width) (if that is fixed)
- the nearest ancestor
 [scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport)'s inner size if that is fixed, else / capped by its
 inner [max
 size](https://drafts.csswg.org/css-sizing-3/#max-width) if that is fixed, floored by its inner [min
 size](https://drafts.csswg.org/css-sizing-3/#min-width) if that is fixed
- the initial containing block's size

See
[\[CSS3-SIZING\]](#biblio-css3-sizing "CSS Box Sizing Module Level 3")
for further details on CSS sizing terminology and concepts.

#### 7.3.2. Auto-sizing Block Containers in Orthogonal Flows

If a box establishing an [orthogonal
flow](#establish-an-orthogonal-flow) is either a [block
container](https://drafts.csswg.org/css-display-4/#block-container) or a [multi-column
container](https://drafts.csswg.org/css-multicol-2/#multi-column-container), for the case where the box's [inline
size](#inline-size) is
[auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto):

1. **Calculate the used
 [column-width](https://drafts.csswg.org/css-multicol-2/#propdef-column-width):**
 - If
 [column-count](https://drafts.csswg.org/css-multicol-2/#propdef-column-count) and
 [column-width](https://drafts.csswg.org/css-multicol-2/#propdef-column-width) are both
 [auto](https://drafts.csswg.org/css-multicol-2/#valdef-column-width-auto), use the shrink-to-fit formula
 `min(``max-content``, max(``min-content``, ``constraint``))`,
 where:

 `min-content`
 : the [min-content inline
 size](https://drafts.csswg.org/css-sizing-3/#min-content-inline-size) of the box

 `max-content`
 : the [max-content inline
 size](https://drafts.csswg.org/css-sizing-3/#max-content-inline-size) of the box

 `constraint`
 : the [inline-axis](#inline-axis) size that would [stretch
 fit](https://drafts.csswg.org/css-sizing-3/#stretch-fit) into to the smallest of
 - the [available
 space](https://drafts.csswg.org/css-sizing-3/#available): the containing block's size if that is
 fixed, else the size represented by the containing block's
 inner [max
 size](https://drafts.csswg.org/css-sizing-3/#max-width) (if that is fixed) floored by its inner
 [min
 size](https://drafts.csswg.org/css-sizing-3/#min-width) (if that is fixed)
 - the nearest ancestor
 [scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport)'s inner size if that is fixed, else /
 capped by its inner [max
 size](https://drafts.csswg.org/css-sizing-3/#max-width) if that is fixed, floored by its inner [min
 size](https://drafts.csswg.org/css-sizing-3/#min-width) if that is fixed
 - the initial containing block's size

 ::::
 ::: sidefigure
 ![Diagram of automatically triggered multi-column preventing
 T-shaped documents](images/auto-multicol.svg){width="200"}
 :::

 **Note that this requirement automatically triggers multi-column
 flow on all [block
 containers](https://drafts.csswg.org/css-display-4/#block-container).** This is so that overflowing content, instead
 of continuing off the side of the containing block, is wrapped
 into columns in the flow direction of the containing block, thus
 avoiding T-shaped documents. Authors can control the [inline
 size](#inline-size) of
 these columns by setting
 [column-width](https://drafts.csswg.org/css-multicol-2/#propdef-column-width), or disable this behavior by
 setting the [inline size] property to a
 non-[auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) value such as
 [max-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-max-content).\
 ::::
 - If
 [column-count](https://drafts.csswg.org/css-multicol-2/#propdef-column-count) is not
 [auto](https://drafts.csswg.org/css-multicol-2/#valdef-column-count-auto) and
 [column-width](https://drafts.csswg.org/css-multicol-2/#propdef-column-width) is
 [auto], calculate the
 used [column-width] with
 the same formula, except replace `constraint` with
 `constraint` −
 ([column-count] − 1) ×
 [column-gap](https://drafts.csswg.org/css-gaps-1/#propdef-column-gap).
 - If
 [column-count](https://drafts.csswg.org/css-multicol-2/#propdef-column-count) and
 [column-width](https://drafts.csswg.org/css-multicol-2/#propdef-column-width) are both
 non-[auto](https://drafts.csswg.org/css-multicol-2/#valdef-column-count-auto), the used
 [column-width] is the
 computed [column-width].
 (This is not recommended as it can cause overflow; instead it is
 better to set the [column-width] and a max-block-size.)

2. **Calculate the used column length:** If the computed [block
 size](#block-size) is
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) and the specified value of at least one of
 [column-count](https://drafts.csswg.org/css-multicol-2/#propdef-column-count) and
 [column-width](https://drafts.csswg.org/css-multicol-2/#propdef-column-width) was
 [auto](https://drafts.csswg.org/css-multicol-2/#valdef-column-width-auto), use the box's [block
 size] (if that is
 [definite](https://drafts.csswg.org/css-sizing-3/#definite)), else the [stretch-fit block
 size](https://drafts.csswg.org/css-sizing-3/#stretch-fit-block-size) of the box (if that is
 [definite]), else the box's [max-content block
 size](https://drafts.csswg.org/css-sizing-3/#max-content-block-size). Otherwise follow the normal rules for sizing a
 multi-column container.

 (#issue-fae7187e) Should we factor in the box's
 [min-content block
 size](https://drafts.csswg.org/css-sizing-3/#min-content-block-size) in this formula, so that e.g. a large image will
 not overflow the box, but cause the box to overflow the containing
 block?

3. **Calculate the used
 [column-count](https://drafts.csswg.org/css-multicol-2/#propdef-column-count):** If the computed
 [column-count](https://drafts.csswg.org/css-multicol-2/#propdef-column-count) is
 [auto](https://drafts.csswg.org/css-multicol-2/#valdef-column-count-auto), then the used
 [column-count] follows
 from filling the resulting multi-column layout with the box's
 content.

The used [inline size](#inline-size) of the resulting multi-column container is then
calculated:

1. If the content neither line-wraps nor fragments within the
 multi-column container, then the used [inline
 size](#inline-size) is the
 [max-content inline
 size](https://drafts.csswg.org/css-sizing-3/#max-content-inline-size) of the box's contents. This criteria gives the
 shrink-to-fit behavior for short orthogonal flow contents without
 making a large blank space.
2. Otherwise it is calculated from the used
 [column-width](https://drafts.csswg.org/css-multicol-2/#propdef-column-width),
 [column-count](https://drafts.csswg.org/css-multicol-2/#propdef-column-count), and
 [column-gap](https://drafts.csswg.org/css-gaps-1/#propdef-column-gap).

The used [block size](#block-size) of the box is either the used column length (if
multiple columns were used) or the [max-content block
size](https://drafts.csswg.org/css-sizing-3/#max-content-block-size) of the content (if only one column was used). If the UA
does not support CSS Multi-column Layout
[\[CSS3COL\]](#biblio-css3col "CSS Multi-column Layout Module Level 1"),
the UA may instead calculate the box's [block
size] assuming infinite [available block
space](https://drafts.csswg.org/css-sizing-3/#available), thus laying out its contents into a single column.
(Note that this can, however, result in content that is clipped or
otherwise inaccessible if it overflows its containing block.)

The automatic triggering of multi-column flow is at-risk and may be
dropped during CR.

#### 7.3.3. Auto-sizing Other Orthogonal Flow Roots

In order to limit the length of lines, [block
containers](https://drafts.csswg.org/css-display-4/#block-container) have special auto-sizing behavior that triggers
[multi-column
layout](https://drafts.csswg.org/css-multicol-2/#multi-column-layout) when their [available inline
space](https://drafts.csswg.org/css-sizing-3/#available) is infinite (which typically occurs when they establish
an [orthogonal
flow](#establish-an-orthogonal-flow)).

For calculating the [automatic inline
size](https://drafts.csswg.org/css-sizing-3/#automatic-inline-size) for other [display
types](https://drafts.csswg.org/css-display-4/#display-type) when the available inline space is infinite, if the box
is
[block-level](https://drafts.csswg.org/css-display-4/#block-level) or the formatting context otherwise calculates an
[automatic inline size] using its
[max-content](https://drafts.csswg.org/css-sizing-3/#max-content) size, use the same formula used for the [block
containers'](https://drafts.csswg.org/css-display-4/#block-container)
[column-width](https://drafts.csswg.org/css-multicol-2/#propdef-column-width) (see [above](#auto-multicol)) in
place of that [max-content size]:
`min(``max-content``, max(``min-content``, ``constraint``))`.

For example, a table or [flex
container](https://drafts.csswg.org/css-flexbox-2/#flex-container) establishing an [orthogonal
flow](#establish-an-orthogonal-flow) is laid out into its given [available
space](https://drafts.csswg.org/css-sizing-3/#available). However, if its [available inline
space] is infinite (as it when placed into a
[block formatting
context](https://drafts.csswg.org/css-display-4/#block-formatting-context)), then assuming no intervening [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container), this effectively lays the box out at its [max-content
size](https://drafts.csswg.org/css-sizing-3/#max-content), clamped by the [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block)'s size, ensuring that its [inline
size](#inline-size) still fits
within the viewport or page area.

 If the [automatic inline
size](https://drafts.csswg.org/css-sizing-3/#automatic-inline-size) is a [fit-content
size](https://drafts.csswg.org/css-sizing-3/#fit-content-size) (for example, in a [grid
item](https://drafts.csswg.org/css-grid-2/#grid-item)) this can apply multiple maximum constraints on the
[max-content](https://drafts.csswg.org/css-sizing-3/#max-content) size.

 **This can result in T-shaped documents** if the
orthogonal content is too long to fit within its containing block.

#### 7.3.4. Fragmenting Orthogonal Flows

*This section is informative.*

With regards to fragmentation, the rules in CSS2.1 still hold in
vertical writing modes and orthogonal flows: break opportunities do not
occur inside line boxes, only between them. UAs that support
[\[CSS3COL\]](#biblio-css3col "CSS Multi-column Layout Module Level 1")
may break in the (potentially zero-width) gap between columns, however.

Note that if content spills outside the pagination stream established by
the root element, the UA is not required to print such content. Authors
wishing to mix writing modes with long streams of text are thus
encouraged to use CSS columns to keep all content flowing in the
document's pagination direction.

In other words, if your document would require two scrollbars on the
screen it probably won't all print. Fix your layout, e.g. by using
[columns](https://www.w3.org/TR/css3-multicol/) so that it all scrolls
(and therefore paginates) in one direction if you want to make sure
it'll all print. T-shaped documents tend not to print well.

### 7.4. Flow-Relative Mappings

Flow-relative directions are calculated with respect to the writing mode
of the *containing block* of the box and used to abstract layout rules
related to the box properties (margins, borders, padding) and any
properties related to positioning the box within its containing block
([float](https://drafts.csswg.org/css2/#propdef-float),
[clear](https://drafts.csswg.org/css2/#propdef-clear),
[top](https://drafts.csswg.org/css2/#propdef-top),
[bottom](https://drafts.csswg.org/css2/#propdef-bottom),
[left](https://drafts.csswg.org/css2/#propdef-left),
[right](https://drafts.csswg.org/css2/#propdef-right),
[caption-side](https://drafts.csswg.org/css2/#propdef-caption-side)). For inline-level boxes, the
writing mode of the *parent box* is used instead. (The
left/right/top/bottom-named properties and values themselves are still
mapped physically; with a special exception made for
[caption-side], whose
[top](https://drafts.csswg.org/css2/#valdef-caption-side-top)/[top-outside] and
[bottom](https://drafts.csswg.org/css2/#valdef-caption-side-bottom)/[bottom-outside] values are associated to
the [block-start](#block-start)
and [block-end](#block-end) sides
of the table, respectively.)

For example, the margin that is dropped when a box's inline dimension is
[over-constrained](https://www.w3.org/TR/CSS2/visudet.html#blockwidth)
is the end margin as determined by the writing mode of the containing
block.

The [margin collapsing
rules](https://www.w3.org/TR/CSS2/box.html#collapsing-margins) apply
exactly with the *[block-start](#block-start) margin* substituted for the top margin and the
*[block-end](#block-end) margin*
substituted for the bottom margin. Similarly the
[block-start](#block-start)
padding and border are substituted for the top padding and border, and
the [block-end](#block-end) padding
and border substituted for the bottom padding and border. Note this
means only [block-start] and
[block-end] margins ever collapse.

Flow-relative directions are calculated with respect to the writing mode
of the box and used to abstract layout related to the box's contents:

- The initial value of the
 [text-align](https://drafts.csswg.org/css-text-3/#propdef-text-align) property aligns to the
 [start](#css-start) edge of the
 line box.
- The
 [text-indent](https://drafts.csswg.org/css-text-4/#propdef-text-indent) property indents from the
 [start](#css-start) edge of the
 line box.
- For tables, the ordering of columns begins on the
 [inline-start](#inline-start)
 side of the table, and the ordering of rows begins on the
 [block-start](#block-start)
 side of the table.

### 7.5. Line-Relative Mappings

The [line-relative
directions](#line-relative-direction) are [over](#over),
[under](#under),
[line-left](#line-left), and
[line-right](#line-right). In an
[LTR]
[horizontal-tb](#valdef-writing-mode-horizontal-tb) writing mode, they correspond to the top,
bottom, left, and right directions, respectively.

The [line-right](#line-right) and
[line-left](#line-left) directions
are calculated with respect to the writing mode of the box and used to
interpret the [left] and [right] values of the following
properties:

- the
 [text-align](https://drafts.csswg.org/css-text-3/#propdef-text-align) property
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")

The [line-right](#line-right) and
[line-left](#line-left) directions
are calculated with respect to the writing mode of the *containing
block* of the box and used to interpret the [left] and
[right] values of the following properties:

- the
 [float](https://drafts.csswg.org/css2/#propdef-float) property
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
- the
 [clear](https://drafts.csswg.org/css2/#propdef-clear) property
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
- the
 [caption-side](https://drafts.csswg.org/css2/#propdef-caption-side) property
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")

The [over](#over) and
[under](#under) directions are
calculated with respect to the writing mode of the box and used to
define the interpretation of the \"top\" (over) and \"bottom\" (under)
sides of the line box as follows:

- For the
 [vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align) property, the \"top\" of the line
 box is its [over](#over) edge; the
 \"bottom\" of the line box is its under edge. Positive length and
 percentage values shift the baseline towards the
 [line-over](#line-over) edge.
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
- For the
 [text-decoration](https://drafts.csswg.org/css-text-decor-3/#propdef-text-decoration) property, the underline is drawn
 on the [under](#under) side of the
 text; the overline is drawn on the [over](#over) side of the text.
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
 [Note that the CSS Text Decoration Module defines this in more detail
 and provides additional controls for controlling the position of
 underlines and overlines.
 [\[CSS3-TEXT-DECOR\]](#biblio-css3-text-decor "CSS Text Decoration Module Level 3")]

### 7.6. Purely Physical Mappings

The following values are purely physical in their definitions and do not
respond to changes in writing mode:

- the
 [rect()](https://drafts.csswg.org/css-masking-1/#funcdef-clip-rect) notation of the
 [clip](https://drafts.csswg.org/css2/#propdef-clip) property
 [\[CSS-MASKING-1\]](#biblio-css-masking-1 "CSS Masking Module Level 1")
- the background properties
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
 [\[CSS3BG\]](#biblio-css3bg "CSS Backgrounds and Borders Module Level 3")
- the border-image properties
 [\[CSS3BG\]](#biblio-css3bg "CSS Backgrounds and Borders Module Level 3")
- the offsets of the
 [box-shadow](https://drafts.csswg.org/css-borders-4/#propdef-box-shadow) and
 [text-shadow](https://drafts.csswg.org/css-text-decor-4/#propdef-text-shadow) properties

## 8. The Principal Writing Mode

The [principal writing mode] of the document is determined by the
[used](https://drafts.csswg.org/css-cascade-5/#used-value)
[writing-mode](#propdef-writing-mode),
[direction](#propdef-direction), and
[text-orientation](#propdef-text-orientation) values of the root element. This
writing mode is used, for example, to determine the direction of
scrolling and the default [page
progression](https://drafts.csswg.org/css-page-3/#page-progression) direction.

As a special case for handling HTML documents, if the root element has a
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) child element
[\[HTML\]](#biblio-html "HTML Standard") whose
[display](https://drafts.csswg.org/css-display-4/#propdef-display) value is not
[none](#valdef-text-combine-upright-none), the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) of the of
[writing-mode](#propdef-writing-mode) and
[direction](#propdef-direction) properties on root element are taken
from the
[computed](https://drafts.csswg.org/css-cascade-5/#computed-value) [writing-mode] and [direction] of
the first such child element instead of from the root element's own
values. The UA *may* also propagate the value of
[text-orientation](#propdef-text-orientation) in this manner. Note that this does
not affect the computed values of
[writing-mode],
[direction], or
[text-orientation] of the
root element itself.

 Using
[containment](https://drafts.csswg.org/css-contain-2/#containment) disables this special handling of the HTML
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) element. See the [CSS Containment 1 § 2 Strong
Containment: the contain
property](https://drafts.csswg.org/css-contain-1/#contain-property) for
details.

 Propagation is done on used values rather than computed
values to avoid disrupting other aspects of style computation, such as
[inheritance](https://drafts.csswg.org/css-cascade-5/#css-inheritance), [logical property mapping
logic](https://drafts.csswg.org/css-logical-1/#box), or [length value
computation](https://drafts.csswg.org/css-values-4/#lengths).

### 8.1. Propagation to the Initial Containing Block

The [principal writing
mode](#principal-writing-mode) is propagated to the [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block) and to the viewport, thereby affecting the layout of
the root element and the scrolling direction of the viewport.

Does it also propagate to \@page boxes?

### 8.2. Page Flow: the page progression direction

In [paged
media](https://drafts.csswg.org/mediaqueries-5/#paged-media) CSS classifies all pages as either left or right pages.
The [page
progression](https://drafts.csswg.org/css-page-3/#page-progression) direction (see
[\[CSS3PAGE\]](#biblio-css3page "CSS Paged Media Module Level 3")),
which determines whether the left or right page in a spread is first in
the flow and whether the first page is by default a left or right page,
depends on the [principal writing
mode](#principal-writing-mode) as follows:

[principal writing
mode](#principal-writing-mode)

[page
progression](https://drafts.csswg.org/css-page-3/#page-progression)

[horizontal-tb](#valdef-writing-mode-horizontal-tb) and
[ltr](#valdef-direction-ltr)

left-to-right

[horizontal-tb](#valdef-writing-mode-horizontal-tb) and
[rtl](#valdef-direction-rtl)

right-to-left

[vertical-rl](#valdef-writing-mode-vertical-rl) or
[sideways-rl](#valdef-writing-mode-sideways-rl)

right-to-left

[vertical-lr](#valdef-writing-mode-vertical-lr) or
[sideways-lr](#valdef-writing-mode-sideways-lr)

left-to-right

 Unless otherwise overridden, the first page of a
document begins on the second half of a spread, e.g. on the right page
in a left-to-right page progression.

## 9. Glyph Composition

### 9.1. Horizontal-in-Vertical Composition: the [text-combine-upright property]
Name:

[text-combine-upright]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) all [\|] \[ digits \<integer
\[2[,](https://drafts.csswg.org/css-values-4/#comb-comma)4\]\>[?](https://drafts.csswg.org/css-values-4/#mult-opt) \]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[inline
boxes](https://drafts.csswg.org/css-display-4/#inline-box) and text

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword, plus integer if
[digits](https://drafts.csswg.org/css-speech-1/#valdef-speak-as-digits)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

n/a

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

This property specifies the combination of multiple [typographic
character
units](https://drafts.csswg.org/css-text-4/#typographic-character-unit) into the space of a single [typographic character
unit]. If the combined text is
wider than 1em, the UA must fit the contents within 1em, see below. The
resulting composition is treated as a single upright glyph for the
purposes of layout and decoration. This property only has an effect in
vertical writing modes. Values have the following meanings:

[none]
: No special processing.

[all]
: Attempt to typeset horizontally all consecutive [typographic
 character
 units](https://drafts.csswg.org/css-text-4/#typographic-character-unit) within the box and text run such that they take up
 the space of a single [typographic character
 unit] within the vertical
 line box.

[digits [\<integer \[2,4\]\>](https://drafts.csswg.org/css-values-4/#integer-value)?]
: Attempt to typeset horizontally each maximal sequence of consecutive
 ASCII digits (U+0030--U+0039) that has as many or fewer digits than
 the specified integer such that it takes up the space of a single
 [typographic character
 unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit) within the vertical line box. If the integer is
 omitted, it computes to 2. Integers outside the range 2-4 are
 invalid.

In East Asian documents, the [text-combine-upright] effect is
often used to display Latin-based strings such as components of a date
or letters of an initialism, always in a horizontal writing mode
regardless of the writing mode of the line:

![Diagram of tate-chu-yoko, showing the two digits of a date set
halfwidth side-by-side in a vertical column of
text](images/tate-chu-yoko.png){height="326" width="121"}

Example of horizontal-in-vertical *tate-chu-yoko*

The figure is the result of the rules

 date { text-combine-upright: digits 2; }

and the following markup:

 <date>平成20年4月16日に</date>

In Japanese, this effect is known as *tate-chu-yoko*.

The following example shows that applying [text-combine-upright: digits
2](#propdef-text-combine-upright) to an entire document, rather than to a
segment with a known type of numeric content, can have unintended
consequences:

 <p>あれは10,000円ですよ！</p>

![Rendering of the above markup with \'text-combine-upright: digits\':
the first two digits of the number are rendered as tate-chu-yoko while
the rest of the number is rendered
sideways.](images/bad-tate-chu-yoko.png){height="192" width="41"}

Example of mis-applied *tate-chu-yoko*

#### 9.1.1. Text Run Rules

To avoid complexity in the rendering and layout,
[text-combine-upright](#propdef-text-combine-upright) can only combine plain text:
consecutive [typographic character
units](https://drafts.csswg.org/css-text-4/#typographic-character-unit) that are not interrupted by a box boundary.

However, because the property inherits, the UA must ensure that the
contents of the box effecting the combination are not part of an
otherwise-combinable sequence that happens to begin or end outside the
box; if so, then the text is laid out normally, as if
[text-combine-upright](#propdef-text-combine-upright) were
[none](#valdef-text-combine-upright-none). To avoid combining only part of a sequence: if
the boundary of a potentially-combinable run is due only to one or more
inline box boundaries, the UA must inspect any characters that appear
immediately before and immediately after the run, and if these
characters would, without the intervening box, form a sequence that
would (if it were not too long) combine, then the candidate run does not
combine.

The above paragraph is at-risk. Comments from implementors are welcome.

For example, given the rule

 tcy { text-combine-upright: digits 4; }

if the following markup were given:

 <tcy>12<span>34</span></tcy>

no text would combine: the 12 and 34 both share an ancestor with the
same
[text-combine-upright](#propdef-text-combine-upright) value, and therefore are considered
part of a sequence of four combinable digits interrupted by a box
boundary. However in these cases:

 12<tcy><span>34</span></tcy>
 12<tcy><span></span>34</tcy>
 12<tcy>34<span></span></tcy>

The 34 would combine, because the 12 immediately previous does not share
with the 34 an ancestor with a common
[text-combine-upright](#propdef-text-combine-upright), and therefore the 34 is considered
to be the entirety of a sequence of two combinable digits.

If we used the rule

 tcy { text-combine-upright: all; }

the same results would occur: the first case not combining because 1234
forms a sequence of four combinable characters interrupted by a box
boundary, and the second combining 34 because it forms the entirety of a
sequence of two combinable characters.

Note that the value of
[text-combine-upright](#propdef-text-combine-upright)
([all](#valdef-text-combine-upright-all) or
[digits](https://drafts.csswg.org/css-speech-1/#valdef-speak-as-digits)) only affects which types of [typographic
character
unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit) can be combined and what is the maximum length of a
combinable sequence. It does not otherwise change behavior.

#### 9.1.2. Layout Rules

When combining text as for [text-combine-upright:
all](#propdef-text-combine-upright), the glyphs of the combined text are
[bidi-isolated](#bidi-isolate)
and composed horizontally (ignoring
[letter-spacing](https://drafts.csswg.org/css-text-3/#propdef-letter-spacing) and any forced line breaks, but
using the specified font settings), similar to the contents of an
[inline-block](https://drafts.csswg.org/css-display-4/#valdef-display-inline-block) box with a [horizontal writing
mode](#horizontal-writing-mode) and a
[line-height](https://drafts.csswg.org/css2/#propdef-line-height) of [1em]. Any [document white
space](https://drafts.csswg.org/css-text-4/#white-space) included at the start/end of the combined text *is*
[processed](https://drafts.csswg.org/css-text-3/#white-space-processing)
[\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3")
as at the start/end of such an inline block. The effective size of the
composition is assumed to be 1em square; anything outside the square is
not measured for layout purposes. The UA should center the glyphs
horizontally and vertically within the measured 1em square.

The baseline of the resulting composition must be chosen such that the
square is centered between the text-over and text-under baselines of its
parent inline box prior to any baseline alignment shift
([vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align)). For bidi reordering, the
composition is treated the same as a [typographic character
unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit) with [text-orientation:
upright](#propdef-text-orientation). For line breaking before and after the
composition, it is treated as a regular inline with its actual contents.
For other text layout purposes, e.g. emphasis marks, text-decoration,
spacing, etc. the resulting composition is treated as a single glyph
representing the Object Replacement Character U+FFFC.

#### 9.1.3. Compression Rules

The UA must ensure that the combined advance width of the composition
fits within 1em by compressing the combined text if necessary. (This
does not necessarily mean that the glyphs will fit within 1em, as some
glyphs are designed to draw outside their geometric boundaries.)
OpenType implementations *must* use width-specific variants (OpenType
features `hwid`/`twid`/`qwid`; other glyph-width features such as `fwid`
or `pwid` are not included) to compress text in cases where those
variants are available for all [typographic character
units](https://drafts.csswg.org/css-text-4/#typographic-character-unit) in the composition. Otherwise, the UA may use any means
to compress the text, including substituting half-width, third-width,
and/or quarter-width glyphs provided by the font, using other font
features designed to compress text horizontally, scaling the text
geometrically, or any combination thereof.

For example, a simple OpenType-based implementation might compress the
text as follows:

1. Enable 1/`n`-width glyphs for combined text of
 `n` [typographic character
 units](https://drafts.csswg.org/css-text-4/#typographic-character-unit) (i.e. use OpenType `hwid` for 2 [typographic
 character units], `twid` for
 3 [typographic character
 units], etc.) if the number
 of [typographic character
 units] \> 1. Note that the
 number of [typographic character
 units] ≠ number of Unicode
 codepoints!
2. If the result is wider than 1em, horizontally scale the result to
 1em.

A different implementation that utilizes OpenType layout features might
compose the text first with normal glyphs to see if that fits, then
substitute in half-width or third-width forms as available and
necessary, possibly adjusting its approach or combining it with scaling
operations depending on the available glyph substitutions.

In some fonts, the ideographic glyphs are given a compressed design such
that they are 1em wide but shorter than 1em tall. To accommodate such
fonts, the UA may vertically scale the composition to match the advance
height of 水 U+6C34 as rendered according to the specified font
settings. In such a case the resulting composition assumes the advance
height of 水 U+6C34 rather than 1em.

##### 9.1.3.1. Full-width Characters

In order to preserve typographic color when compressing the text to 1em,
when the combined text consists of more than one [typographic character
unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit), then any full-width [typographic character
units] should first be converted
to their non-full-width equivalents by reversing the algorithm defined
for [text-transform:
full-width](https://drafts.csswg.org/css-text-4/#propdef-text-transform) in
[\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3")
before applying other compression techniques.

For example, an author might apply both
[text-transform](https://drafts.csswg.org/css-text-4/#propdef-text-transform) and
[text-combine-upright](#propdef-text-combine-upright) to a date set in vertical text.

 date { text-combine-upright: digits 2; text-transform: full-width; }

Suppose this style rule is applied to a date such as.

 <date>2010年2月23日</date>

The \"2010\" is too long to be combined (4 digits), but the \"2\" and
\"23\" will be affected. Since \"23\" is more than one [typographic
character
unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit), it will not be affected by [text-transform:
full-width](https://drafts.csswg.org/css-text-4/#propdef-text-transform). However since the \"2\" is only one
[typographic character unit], it
will be transformed to a fullwidth \"２\". Since the \"2010\" was not
combined, its digits, too, will be transformed to fullwidth
\"２０１０\"; and being fullwidth, they will be typeset upright, giving
the following result:

``` {style="text-align: center; font-family: MS Gothic, TakaoGothic, sans-serif"}
２
０
１
０
年
２
月
23
日
```

Properties that affect glyph selection, such as the
[font-variant](https://drafts.csswg.org/css-fonts-4/#propdef-font-variant) and
[font-feature-settings](https://drafts.csswg.org/css-fonts-4/#propdef-font-feature-settings) properties defined in
[\[CSS3-FONTS\]](#biblio-css3-fonts "CSS Fonts Module Level 3"),
can potentially affect the selection of variants for characters included
in combined text runs. Authors are advised to use these properties with
care when
[text-combine-upright](#propdef-text-combine-upright) is also used.

## 10. Privacy Considerations

This specification introduces no new privacy leaks beyond "implement it
correctly".

## 11. Security Considerations

This specification introduces no new security considerations beyond
"implement it correctly".

## [Changes]
### [ Changes since the [July 2019 CSS Writing Modes Module Level 4 Candidate Recommendation](https://www.w3.org/TR/2019/CR-css-writing-modes-4-20190730/)]
- Changed the automatic sizing of orthogonal flows that are not [block
 containers](https://drafts.csswg.org/css-display-4/#block-container) to apply the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) size as a constraint on the flow itself like [block
 containers] do, rather than passing
 through an infinite available size to be clamped by descendant [block
 containers]. ([Issue
 4221](https://github.com/w3c/csswg-drafts/issues/4221))
- Specified that a [display:
 none](https://drafts.csswg.org/css-display-4/#propdef-display)
 [`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) element does not influence the [principal writing
 mode](#principal-writing-mode). ([Issue
 3779](https://github.com/w3c/csswg-drafts/issues/3779))
- Updated "Applies to" line for
 [text-combine-upright](#propdef-text-combine-upright) to mention text (since certain
 effects like [display:
 contents](https://drafts.csswg.org/css-display-4/#propdef-display) can strip the box itself).
- Clarified that the [central
 baseline](#central-baseline) is the [ideographic central
 baseline](https://drafts.csswg.org/css-inline-3/#central-baseline). ([Issue
 5177](https://github.com/w3c/csswg-drafts/issues/5177))
- Updated "Computed Value" line for
 [text-orientation](#propdef-text-orientation) and
 [text-combine-upright](#propdef-text-combine-upright) to clarify that they apply to
 text. ([Issue 5303](https://github.com/w3c/csswg-drafts/issues/5303),
 [Issue 9788](https://github.com/w3c/csswg-drafts/issues/9788))
- Reshuffled text in the [§ 1 Introduction to Writing Modes](#intro) and
 improved cross-linking.

### [ Changes since the [May 2018 CSS Writing Modes Module Level 4 Candidate Recommendation](https://www.w3.org/TR/2018/CR-css-writing-modes-4-20180524)]
- Clarified that propagation of the principal writing mode from the body
 element to the initial containing block and viewport does affect the
 used value on root element as well, but not its computed value. Also,
 optionally allow propagating
 [text-orientation](#propdef-text-orientation) as well. This change was also
 applied to level 3. ([Issue
 3066](https://github.com/w3c/csswg-drafts/issues/3066))

- Clarified that white space within---​particularly at the start/end
 of---​a
 [text-combine-upright](#propdef-text-combine-upright) combined text sequence is
 processed the same way as in an inline block. ([Issue
 4139](https://github.com/w3c/csswg-drafts/issues/4139)) This change
 was also applied to level 3.

 > When combining text as for [text-combine-upright:
 > all](#propdef-text-combine-upright), the glyphs of the combined text are
 > [bidi-isolated](#bidi-isolate) and composed horizontally (ignoring
 > [letter-spacing](https://drafts.csswg.org/css-text-3/#propdef-letter-spacing) and any forced line breaks, but
 > using the specified font settings), similar to the contents of an
 > [inline-block](https://drafts.csswg.org/css-display-4/#valdef-display-inline-block) box with a [horizontal writing
 > mode](#horizontal-writing-mode) and a
 > [line-height](https://drafts.csswg.org/css2/#propdef-line-height) of [1em]. [Any [document
 > white
 > space](https://drafts.csswg.org/css-text-4/#white-space) included at the start/end of the combined text *is*
 > [processed](https://drafts.csswg.org/css-text-3/#white-space-processing)
 > [\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3")
 > as at the start/end of such an inline block.]

### [ New in Level 4]
This module is simply a copy of the [2015 Candidate Recommendation of
CSS Writing Modes Level
3](http://www.w3.org/TR/2015/CR-css-writing-modes-3-20151215/). The
difference from the [current CSS Writing Modes Level
3](https://www.w3.org/TR/css-writing-modes-3/) is the set of features
that were deferred from Level 3 due to later implementation uptake:

- Re-introduced
 [sideways-lr](#valdef-writing-mode-sideways-lr) and
 [sideways-rl](#valdef-writing-mode-sideways-rl) values of
 [writing-mode](#propdef-writing-mode)
- Re-introduced the
 [digits](https://drafts.csswg.org/css-speech-1/#valdef-speak-as-digits) value of
 [text-combine-upright](#propdef-text-combine-upright).
- Re-introduced [automatic multi-column behavior](#auto-multicol) of
 orthogonal flows.
- Clarified the [conditions for bidi reordering-induced
 fragmentation](#bidi-fragmentation). ([Issue
 1509](https://github.com/w3c/csswg-drafts/issues/1509))

## [ Acknowledgements]
L. David Baron, Brian Birtles, James Clark, John Daggett, Nami Fujii,
Daisaku Hataoka, Martin Heijdra, Laurentiu Iancu, Richard Ishida,
Jonathan Kew, Yasuo Kida, Tatsuo Kobayashi, Toshi Kobayashi, Ken Lunde,
Shunsuke Matsuki, Nat McCully, Eric Muller, Paul Nelson, Kenzou Onozawa,
Chris Pratley, Xidorn Quan, Florian Rivoal, Dwayne Robinson, Simon
Sapin, Marcin Sawicki, Dirk Schulze, Hajime Shiozawa, Alan Stearns,
Michel Suignard, Takao Suzuki, Gérard Talbot, Masataka Yakura, Taro
Yamamoto, Steve Zilles

## [Appendix A: Vertical Scripts in Unicode]
*This section is informative.*

This appendix lists the
[vertical-only](#vertical-only)
and [bi-orientational](#bi-orientational) scripts in Unicode 6.0
[\[UNICODE\]](#biblio-unicode "The Unicode Standard")
and their transformation from horizontal to vertical orientation. Any
script not listed explicitly is assumed to be
[horizontal-only](#horizontal-only). The script classification of Unicode characters is
given by
[\[UAX24\]](#biblio-uax24 "Unicode Script Property").

Vertical Scripts in Unicode

Code

Name

Transform (Clockwise)

Vertical Intrinsic Direction

Bopo

Bopomofo

0°

ttb

Egyp

Egyptian Hieroglyphs

0°

ttb

Hira

Hiragana

0°

ttb

Kana

Katakana

0°

ttb

Hani

Han

0°

ttb

Hang

Hangul

0°

ttb

Merc

Meroitic Cursive

0°

ttb

Mero

Meroitic Hieroglyphs

0°

ttb

Mong

Mongolian

90°

ttb

Ogam

Ogham

-90°

btt

Orkh

Old Turkic

-90°

ttb

Phag

Phags Pa

90°

ttb

Yiii

Yi

0°

ttb

**Exceptions:** For the purposes of this specification, all fullwidth
(F) and wide (W) characters are treated as belonging to a vertical
script, and halfwidth characters (H) are treated as belonging to a
[horizontal script](#horizontal-script).
[\[UAX11\]](#biblio-uax11 "East Asian Width")

Note that for [vertical-only](#vertical-only) characters (such as Mongolian and Phags Pa letters),
the glyphs in the Unicode code charts are shown in their vertical
orientation. In horizontal text, they are typeset in a 90°
counter-clockwise rotation from this orientation.

Due to limitations in the current feature set of Unicode Technical
Report 50 and CSS Writing Modes, vertical
[mixed](#valdef-text-orientation-mixed) typesetting cannot automatically handle either
Ogham or Old Turkic. For these scripts,
[sideways-lr](#valdef-writing-mode-sideways-lr) can be used to typeset passages.
