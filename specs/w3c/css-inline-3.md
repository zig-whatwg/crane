## 1. Introduction

This module defines [inline
layout](#inline-layout), the CSS
model for laying out a mixed stream of text and
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) boxes, and defines controls for the
[block-axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) alignment and sizing of this content within each line.
It also adds a [special layout mode for drop caps and similar initial
letter styling](#initial-letter-styling).

 Line-breaking, justification, and other aspects of
inline-axis positioning of
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) content are handled in the [CSS Text
Module](https://www.w3.org/TR/css-text/).

Many aspects of layout here depend on
font metrics. While the relevant metrics exist in OpenType for
Latin/Cyrillic/Greek and for [CJK], they are missing for many other
writing systems. For example, the visual top metric for Hebrew has no
metric in the OpenType tables. For this module to work well for the
world, we need fonts to provide the relevant metrics for all writing
systems, and that means both that OpenType needs to allow such metrics
and font designers need to provide accurate numbers. See
[issue](https://github.com/w3c/csswg-drafts/issues/5244) and [liaison
statement](https://lists.w3.org/Archives/Public/www-archive/2020Feb/att-0005/CSS-SC29-20200113.pdf).

### 1.1. Module Interactions

This module replaces and extends the CSS inline layout model and
features defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
section 10.8.

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

## 2. Inline Layout Model

In [inline layout], a mixed, recursive stream of text and [inline-level
boxes](https://drafts.csswg.org/css-display-3/#inline-level-box) forming an [inline formatting
context] within a [block
container](https://drafts.csswg.org/css-display-4/#block-container) are laid out by
[fragmenting](https://drafts.csswg.org/css-break-3/#fragment) them into a stack of [line
boxes](#line-box). Within each [line
box], [inline-level
boxes] are [aligned to each
other](#alignment) along the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis), typically by the
[baselines](#baseline) of their text.

Any [block
container](https://drafts.csswg.org/css-display-4/#block-container) that directly contains
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) content---​such as [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box), [atomic
inlines](https://drafts.csswg.org/css-display-4/#atomic-inline), and [text
sequences](https://drafts.csswg.org/css-display-4/#css-text-sequence)---​establishes an [inline formatting
context](#inline-formatting-context) to lay out its contents using [inline
layout](#inline-layout). The
[block container]'s [content
edges](https://drafts.csswg.org/css-box-3/#content-edge) form the [containing
block](https://drafts.csswg.org/css-display-3/#containing-block) for each of the [inline-level
boxes](https://drafts.csswg.org/css-display-3/#inline-level-box) participating in its [inline formatting
context].

The [block
container](https://drafts.csswg.org/css-display-4/#block-container) also generates a [root inline box], which is an
[anonymous](https://drafts.csswg.org/css-display-4/#anonymous) [inline
box](https://drafts.csswg.org/css-display-3/#inline-box) that holds all of its
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) contents. (Thus, all text in an [inline formatting
context](#inline-formatting-context) is directly contained by an [inline
box], whether the [root inline
box](#root-inline-box) or one
of its descendants.) The [root inline box]
inherits from its parent [block container],
but is otherwise unstyleable.

In an [inline formatting
context](#inline-formatting-context), content is laid out along the [inline
axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis), ordered according to the [Unicode bidirectional
algorithm and its
controls](https://www.w3.org/TR/css-writing-modes-3/#text-direction)
[\[CSS-WRITING-MODES-3\]](#biblio-css-writing-modes-3 "CSS Writing Modes Level 3")
and distributed according to the typesetting controls in
[\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3").
[Inline-axis]
[margins](https://drafts.csswg.org/css-box-4/#margin),
[borders](https://drafts.csswg.org/css-box-4/#border), and
[padding](https://drafts.csswg.org/css-box-4/#padding) are respected between [inline-level
boxes](https://drafts.csswg.org/css-display-3/#inline-level-box) (and their margins do not
[collapse](https://www.w3.org/TR/CSS2/box.html#collapsing-margins)). The
resulting rectangular area that contains the boxes that form a single
line of [inline-level
content](https://drafts.csswg.org/css-display-4/#inline-level) is called a [line box].

 [Line boxes](#line-box) and [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box) and [inline-level
boxes](https://drafts.csswg.org/css-display-3/#inline-level-box) are each different things! See
[\[CSS-DISPLAY-3\]](#biblio-css-display-3 "CSS Display Module Level 3")
for an in-depth discussion of box types and related terminology.

### 2.1. Layout of Line Boxes

[Line boxes](#line-box) are created
as needed to hold
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) content within an [inline formatting
context](#inline-formatting-context). When an [inline
box](https://drafts.csswg.org/css-display-3/#inline-box) exceeds the [logical
width](https://drafts.csswg.org/css-writing-modes-4/#logical-width) of a [line box], or contains a
[forced line
break](https://drafts.csswg.org/css-text-3/#forced-line-break), it is split (see [CSS Text 3 § 5 Line Breaking and
Word Boundaries](https://drafts.csswg.org/css-text-3/#line-breaking))
into several
[fragments](https://drafts.csswg.org/css-break-3/#fragment)
[\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3"),
which are partitioned across multiple [line boxes].
Like [column
boxes](https://drafts.csswg.org/css-multicol-2/#column-box) in [multi-column
layout](https://drafts.csswg.org/css-multicol-2/#multi-column-layout)
[\[CSS-MULTICOL-1\]](#biblio-css-multicol-1 "CSS Multi-column Layout Module Level 1"),
[line boxes] are [fragmentation
containers](https://drafts.csswg.org/css-break-4/#fragmentation-container) generated by their [formatting
context](https://drafts.csswg.org/css-display-4/#formatting-context), and are not part of the CSS [box
tree](https://drafts.csswg.org/css-display-4/#box-tree).

 [Inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box) can also be [split into several fragments within the
same line box due to bidirectional text
processing](https://www.w3.org/TR/css-writing-modes-3/#bidi-box-model).
See
[\[CSS-WRITING-MODES-3\]](#biblio-css-writing-modes-3 "CSS Writing Modes Level 3").

[Line boxes](#line-box) are stacked
as the direct contents of the [block container
box](https://drafts.csswg.org/css-display-4/#block-container) in its [block flow
direction](https://drafts.csswg.org/css-writing-modes-4/#block-flow-direction) and aligned within this container as specified by
[align-content](https://drafts.csswg.org/css-align-3/#propdef-align-content)
[\[CSS-ALIGN-3\]](#biblio-css-align-3 "CSS Box Alignment Module Level 3").
Thus, an [inline formatting
context](#inline-formatting-context) consists of a stack of [line
boxes]. [Line boxes] are stacked
with no separation (except as specified elsewhere, e.g. for
[float](https://drafts.csswg.org/css-page-floats-3/#float)
[clearance](https://www.w3.org/TR/CSS2/visuren.html#clearance)) and they
never overlap.

In general, the
[line-left](https://drafts.csswg.org/css-writing-modes-4/#line-left) edge of a [line box](#line-box) touches the [line-left] edge of
its [containing
block](https://drafts.csswg.org/css-display-3/#containing-block) and the
[line-right](https://drafts.csswg.org/css-writing-modes-4/#line-right) edge touches the [line-right]
edge of its [containing block], and thus the
[logical
width](https://drafts.csswg.org/css-writing-modes-4/#logical-width) of a line box is equal to the
[inner](https://drafts.csswg.org/css-sizing-3/#inner-size) [logical width] of its
[containing block] (i.e. the [block
container](https://drafts.csswg.org/css-display-4/#block-container)'s [content
box](https://drafts.csswg.org/css-box-4/#content-box)). However, floating boxes or [initial letter
boxes](#initial-letter) can
come between the [containing block] edge and
the [line box] edge, reducing the space available
to, and thus the [logical width] of, any such
impacted [line boxes]. (See [CSS 2 § 9.4.2 Inline
formatting
contexts](https://www.w3.org/TR/CSS2/visuren.html#inline-formatting)/[CSS
2 § 9.5 Floats](https://www.w3.org/TR/CSS2/visuren.html#floats) and [§ 7
Initial Letters](#initial-letter-styling).)

The [logical
height](https://drafts.csswg.org/css-writing-modes-4/#logical-height) of a [line box](#line-box) is fitted to its contents once they have been
[block-axis aligned](#alignment). This fit is controlled by
[line-height](#propdef-line-height) and
[line-fit-edge](#propdef-line-fit-edge). The first/last line boxes in a
[block
container](https://drafts.csswg.org/css-display-4/#block-container) may additionally be trimmed by
[text-box-trim](#propdef-text-box-trim).

![Inline Layout Box
Model](images/box-model.png){a
height="258" width="500"}

### 2.2. Layout Within Line Boxes

As described [above](#model), user agents flow [inline-level
boxes](https://drafts.csswg.org/css-display-3/#inline-level-box) into a stack of [line
boxes](#line-box). Layout within
each [line box] is performed, sizing and
positioning each [box
fragment](https://drafts.csswg.org/css-break-4/#box-fragment) and [line box] independently, as
follows:

1. **Baseline Alignment:** All
 [in-flow](https://drafts.csswg.org/css-display-3/#in-flow) [inline-level
 boxes](https://drafts.csswg.org/css-display-3/#inline-level-box) in the [line box](#line-box) are aligned to each other in the [block
 axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) according to
 [dominant-baseline](#propdef-dominant-baseline) and
 [vertical-align](#propdef-vertical-align). This is referred to as
 [baseline alignment](#alignment). Those with [line-relative
 values](#line-relative-shift-values) for
 [baseline-shift](#propdef-baseline-shift) are assumed to be aligned so as
 to minimize the line box height.

2. **Content Size Contribution Calculation:** The [layout
 bounds](#layout-bounds)
 (i.e. the size contributions) of each [inline-level
 box](https://drafts.csswg.org/css-display-3/#inline-level-box) in the [line box](#line-box) are calculated:

 - For [atomic
 inlines](https://drafts.csswg.org/css-display-4/#atomic-inline) such as [replaced
 elements](https://drafts.csswg.org/css-display-4/#replaced-element) and [inline
 blocks](https://drafts.csswg.org/css-display-4/#inline-block): this is their [margin
 box](https://drafts.csswg.org/css-box-3/#margin-box).
 - For the [root inline
 box](#root-inline-box),
 and for [inline
 boxes](https://drafts.csswg.org/css-display-3/#inline-box) with [line-fit-edge:
 leading](#propdef-line-fit-edge): this derived from their used
 [line-height](#propdef-line-height), ignoring any
 [margin](https://drafts.csswg.org/css-box-4/#margin)/[border](https://drafts.csswg.org/css-box-4/#border)/[padding](https://drafts.csswg.org/css-box-4/#padding); see [§ 5.3 Calculating the Logical Height
 Contributions ("Layout Bounds") of Inline Boxes](#inline-height).
 - For other [inline
 boxes](https://drafts.csswg.org/css-display-3/#inline-box): this is derived from their
 [line-fit-edge](#propdef-line-fit-edge) metrics, and includes any
 [margin](https://drafts.csswg.org/css-box-4/#margin)/[border](https://drafts.csswg.org/css-box-4/#border)/[padding](https://drafts.csswg.org/css-box-4/#padding); see [§ 5.3 Calculating the Logical Height
 Contributions ("Layout Bounds") of Inline Boxes](#inline-height).

3. **Line Box Sizing:** The [line box](#line-box)'s [logical
 height](https://drafts.csswg.org/css-writing-modes-4/#logical-height) is sized to exactly include the aligned [layout
 bounds](#layout-bounds) of
 all its [inline-level
 boxes](https://drafts.csswg.org/css-display-3/#inline-level-box).

4. **Content Positioning:** The [root inline
 box](#root-inline-box)'s
 [aligned subtree](#aligned-subtree) and boxes [line-relative
 values](#line-relative-shift-values) for
 [baseline-shift](#propdef-baseline-shift) are positioned within the [line
 box](#line-box).

 (#issue-e2d22611) Define what to do for
 top/bottom/center aligned boxes that are taller than the rest of the
 content.

 Empty [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box) still have
[margins](https://drafts.csswg.org/css-box-4/#margin),
[padding](https://drafts.csswg.org/css-box-4/#padding),
[borders](https://drafts.csswg.org/css-box-4/#border), and a
[line-height](#propdef-line-height), and thus influence these calculations
just like boxes with content.

### 2.3. Phantom Line Boxes

[Line boxes](#line-box) that
contain no text, no [preserved white
space](https://drafts.csswg.org/css-text-4/#preserved-white-space), no [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box) with non-zero inline-axis
[margins](https://drafts.csswg.org/css-box-4/#margin),
[padding](https://drafts.csswg.org/css-box-4/#padding), or
[borders](https://drafts.csswg.org/css-box-4/#border), and no other
[in-flow](https://drafts.csswg.org/css-display-3/#in-flow) content (such as [atomic
inlines](https://drafts.csswg.org/css-display-4/#atomic-inline) or [ruby
annotations](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-box)), and do not end with a [forced line
break](https://drafts.csswg.org/css-text-4/#forced-line-break) are [phantom line boxes]. Such
boxes must be treated as
zero-[height](https://drafts.csswg.org/css-writing-modes-4/#logical-height) [line boxes] for the purposes of
determining the positions of any descendant content (such as [absolutely
positioned
boxes](https://drafts.csswg.org/css-position-3/#absolute-position)), and both the [line box] and its
[in-flow] content must be treated as not existing for
any other layout or rendering purpose.

What's invisible?

Such [phantom line boxes](#phantom-line-box), which can still contain unstyled empty [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box),
[out-of-flow](https://drafts.csswg.org/css-display-4/#out-of-flow) boxes, and/or collapsed [document white
space](https://drafts.csswg.org/css-text-4/#white-space), are ignored, for example, for:

- [margin
 collapsing](https://www.w3.org/TR/CSS2/box.html#collapsing-margins)

- finding the [first formatted
 line](https://drafts.csswg.org/css-pseudo-4/#first-formatted-line)

- applying
 [text-box-trim](#propdef-text-box-trim)

- [fragmentation break
 propagation](https://drafts.csswg.org/css-break-4/#break-propagation)

- etc.

Firefox allows the inline boxes within a
[phantom line box](#phantom-line-box) to accept
[outline](https://drafts.csswg.org/css-ui-4/#propdef-outline),which allows it to make focus rings
visible. As in other browsers, all other properties that could make the
element visible (e.g.
[box-shadow](https://drafts.csswg.org/css-backgrounds-3/#propdef-box-shadow)) seem to be ignored.

### 2.4. Painting Order

Except as specified for [positioned
boxes](https://drafts.csswg.org/css-position-3/#positioned-box) (see
[\[CSS-POSITION-3\]](#biblio-css-position-3 "CSS Positioned Layout Module Level 3"))
[inline-level
boxes](https://drafts.csswg.org/css-display-3/#inline-level-box) are painted in [document
order](https://drafts.csswg.org/css-display-4/#document-order); the
[z-index](https://drafts.csswg.org/css2/#propdef-z-index) property does not generally apply.

## 3. Baselines and Alignment Metrics

### 3.1. Introduction to Baselines

A [baseline] is a
line along the [inline
axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) of a line box along which individual glyphs of text are
aligned. [Baselines](#baseline)
guide the design of glyphs in a font (for example, the bottom of most
alphabetic glyphs typically align with the alphabetic baseline), and
they guide the alignment of glyphs from different fonts or font sizes
when typesetting.

![Alphabetic text in two font sizes with the baseline and
em-boxes](images/alphabetic-baseline-in-two-font-sizes.svg){a
height="132" width="480"}

Different writing systems prefer different
[baselines](#baseline).

![Preferred baselines in various writing
systems](images/script-preferred-baselines.gif){a
height="110" width="458"}

A well-constructed font contains a [baseline table], which indicates the position
of one or more [baselines](#baseline) within the font's design coordinate space. (The design
coordinate space is scaled with the font size.)

![In a well-designed mixed-script font, the glyphs are positioned in the
coordinate space to harmonize with one another when typeset together.
The baseline table is then constructed to match the shape of the glyphs,
each baseline positioned to match the glyphs from its preferred
scripts.](images/baselines.gif){height="102" width="587"}

The [baseline table](#baseline-table) is a property of the font, and the positions of the
various baselines apply to all glyphs in the font.

Different [baseline tables](#baseline-table) can be provided for alignment in horizontal and
vertical text. UAs should use the vertical tables in vertical
[typographic
modes](https://drafts.csswg.org/css-writing-modes-4/#typographic-mode) and the horizontal tables otherwise.

 Fonts can have more than one [baseline
table](#baseline-table) in
each axis; the UA is responsible for choosing the appropriate table in
consideration of
[font-language-override](https://drafts.csswg.org/css-fonts-4/#propdef-font-language-override) and the [content
language](https://drafts.csswg.org/css-text-4/#content-language).

### 3.2. Baselines and Metrics

CSS uses the following text-based metrics as
[baselines](#baseline) for [inline
layout](#inline-layout)
functions such as alignment, box sizing, and initial letter layout.

The CSSWG would like to know which
baseline values are necessary for each property that uses them
([dominant-baseline](#propdef-dominant-baseline),
[alignment-baseline](#propdef-alignment-baseline),
[text-box-edge](#propdef-text-box-edge),
[line-fit-edge](#propdef-line-fit-edge),
[initial-letter-align](#propdef-initial-letter-align)): if any can be dropped, or any
need to be added. See [Issue
859](https://github.com/w3c/csswg-drafts/issues/859).

[alphabetic]
: Used in writing Latin, Cyrillic, Greek, and many other scripts,
 corresponds to the bottom of most, but not all, their characters,
 (such as "m", "Ш", "Δ"). Often represented as zero in font design
 coordinate systems; assigned to `romn` in OpenType and to `bsln`
 value zero in TrueType AAT.

[cap-height]
: Corresponds to the top of capital letters (such as "T", "Б", "Σ") in
 Latin, Cyrillic, Greek, etc. Calculated using `sCapHeight` in
 OpenType.

[x-height]
: Corresponds to the top of short lowercase letters (such as "m", "л",
 "α") in Latin, Cyrillic, Greek, etc. Calculated using `sxHeight` in
 OpenType.

[x-middle]
: Corresponds to halfway between the
 [alphabetic](#alphabetic-baseline) and
 [x-height](#x-height-baseline) baselines.

[ideographic-over]
: Corresponds to the
 [line-over](https://drafts.csswg.org/css-writing-modes-4/#line-over) design edge of CJK (Han/Hangul/Kana) text. Assigned
 to `idtp` in OpenType.

[ideographic-under]
: Corresponds to the
 [line-under](https://drafts.csswg.org/css-writing-modes-4/#line-under) design edge of CJK (Han/Hangul/Kana) text. Assigned
 to `ideo` in OpenType.

[central]
: Corresponds to the ideographic central baseline, halfway between the
 [ideographic-under](#ideographic-under-baseline) and
 [ideographic-over](#ideographic-over-baseline) baselines. Assigned to `bsln` value 1 in TrueType
 AAT.

[ideographic-ink-over]
: Corresponds to the
 [line-over](https://drafts.csswg.org/css-writing-modes-4/#line-over) ink edge of CJK (Han/Hangul/Kana) text. Assigned to
 `icft` in OpenType.

[ideographic-ink-under]
: Corresponds to the line-under ink edge of CJK (Han/Hangul/Kana)
 text. Assigned `icfb` in OpenType.

[hanging]
: Corresponds to hanging baseline from which characters in Tibetan and
 similar unicameral scripts with a strong but not absolute top edge
 seem to "hang". Assigned to `hang` in OpenType and to `bsln` value 3
 in TrueType AAT.

[math]
: Corresponds to center baseline around which mathematical characters
 are designed. Assigned to `math` in OpenType and `bsln` value 4 in
 TrueType AAT.

[text-over]
: Corresponds to the metric used as the
 [line-over](https://drafts.csswg.org/css-writing-modes-4/#line-over) edge of an
 [inline](https://drafts.csswg.org/css-display-3/#inline-box)'s [content
 box](https://drafts.csswg.org/css-box-4/#content-box) per
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").

[text-under]
: Corresponds to the metric used as the
 [line-under](https://drafts.csswg.org/css-writing-modes-4/#line-under) edge of an
 [inline](https://drafts.csswg.org/css-display-3/#inline-box)'s [content
 box](https://drafts.csswg.org/css-box-4/#content-box) per
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").

[em-over]
: Corresponds to a conceptual
 [ascent](#ascent-metric)
 normalized to ensure 1em between
 [em-over](#em-over-baseline) and
 [em-under](#em-under-baseline). See [A.1: Calculating Em-over and
 Em-under](#baseline-synthesis-em).

[em-under]
: Corresponds to a conceptual
 [descent](#descent-metric)
 normalized to ensure 1em between
 [em-over](#em-over-baseline) and
 [em-under](#em-under-baseline). See [A.1: Calculating Em-over and
 Em-under](#baseline-synthesis-em).

 These metrics are optical design metrics, and therefore
do not necessarily correspond exactly to actual glyph outlines.

In general, these metrics are taken from the appropriate font, but if
they are missing or need to be derived from a box rather than text, they
must be synthesized, see [§ 3.3 Baselines of Glyphs and
Boxes](#baseline-tables) and [Appendix A: Synthesizing Alignment
Metrics](#baseline-synthesis).

#### 3.2.1. Ascent and Descent Metrics

CSS assumes that every font has font metrics that specify a
characteristic height above the baseline---​called the [ascent
metric]---​and a characteristic depth below
it---​called the [descent metric]---​which CSS uses for
laying out text and boxes in an [inline formatting
context](#inline-formatting-context). Note that these are metrics of the font as a whole and
need not correspond to the ascender and descender of any individual
glyph.

 It is recommended that implementations that use
OpenType or TrueType fonts use the metrics `sTypoAscender` and
`sTypoDescender` from the font's OS/2 table (after scaling to the
current element's font size) to find the [ascent
metric](#ascent-metric) and
[descent metric](#descent-metric) for CSS layout. In the absence of these metrics, the
\"Ascent\" and \"Descent\" metrics from the HHEA table should be used.

#### 3.2.2. Line Gap Metrics

Font formats can allow for a font-recommended "line gap" or "external
leading" metric. This metric is referred to as the [line gap
metric],
and may be incorporated into the [line
box](#line-box) [logical
height](https://drafts.csswg.org/css-writing-modes-4/#logical-height) calculations when
[line-height](#propdef-line-height) is
[normal](#valdef-line-height-normal) as described in [§ 5.3 Calculating the Logical
Height Contributions ("Layout Bounds") of Inline Boxes](#inline-height).

 In OpenType, the [line gap
metric](#line-gap-metric) can
be found as `sTypoLineGap` or `hhea.lineGap`.

UAs must floor the [line gap
metric](#line-gap-metric) at
zero.

### 3.3. Baselines of Glyphs and Boxes

Each font, glyph, and [inline-level
box](https://drafts.csswg.org/css-display-3/#inline-level-box) is assumed to have a
[baseline](#baseline) coordinate for
each [baseline] type indicating that
[baseline]'s position on its [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis). The set of such [baselines] is
called its [baseline set]. The [baseline] from this set that is
used to align the box or glyph within its [alignment
context](https://drafts.csswg.org/css-align-3/#shared-alignment-context) is called its [alignment
baseline](#alignment-baseline); the [baseline] used to align its
content within itself is called its [dominant
baseline](#dominant-baseline).

For an individual glyph, the [baseline
set](#baseline-set) derives from
the font's [baseline table](#baseline-table). For an [inline
box](https://drafts.csswg.org/css-display-3/#inline-box), it derives from its [first available
font](https://drafts.csswg.org/css-fonts-4/#first-available-font) regardless of whether the box actually contains any
glyphs from that font. If the requisite metrics are missing from a font,
the UA must synthesize them, see [A.2: Synthesizing Baselines (and Other
Font Metrics) for Text](#baseline-synthesis-fonts).

For other
[boxes](https://drafts.csswg.org/css-display-4/#box), its [baseline
set](#baseline-set) is nominally
derived from its contents in accordance with
[baseline-source](#propdef-baseline-source) and the rules of the [formatting
context](https://drafts.csswg.org/css-display-4/#formatting-context) in which it participates. For an [atomic inline
box](https://drafts.csswg.org/css-display-4/#atomic-inline) with no [baseline set] in the
[inline formatting
context](#inline-formatting-context)'s [inline
axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) its [alignment
baselines](#alignment-baseline) are
[synthesized](https://drafts.csswg.org/css-align-3/#synthesize-baseline) from its [margin
box](https://drafts.csswg.org/css-box-3/#margin-box), see [A.3: Synthesizing Baselines for Atomic
Inlines](#baseline-synthesis-box).

## 4. Baseline Alignment

While most CSS [formatting
contexts](https://drafts.csswg.org/css-display-4/#formatting-context) position content by aligning boxes with respect to
their container's edges, [inline
layout](#inline-layout)
positions boxes in the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) by aligning them with respect to each other using their
[baselines](#baseline).

More specifically, (unless using a [line-relative shift
value](#line-relative-shift-values)) each glyph or [inline-level
box](https://drafts.csswg.org/css-display-3/#inline-level-box) is aligned in the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) by positioning its [alignment
baseline](#alignment-baseline) to match the *corresponding*
[baseline](#baseline) of its parent
(which is its [alignment
context](https://drafts.csswg.org/css-align-3/#shared-alignment-context)), and then is potentially shifted from that position
according to its [post-alignment
shift](#post-alignment-shift).

 Baseline alignment always matches corresponding
baselines: alphabetic to alphabetic, hanging to hanging, mathematical to
mathematical, etc.

When aligning a
[box](https://drafts.csswg.org/css-display-4/#box), the [alignment
baseline](#alignment-baseline) is chosen according to its
[alignment-baseline](#propdef-alignment-baseline) and
[baseline-source](#propdef-baseline-source) values (see shorthand
[vertical-align](#propdef-vertical-align)), and defaults to matching the
parent's
[dominant-baseline](#propdef-dominant-baseline). For a glyph, the [alignment
baseline] is always determined by the
parent's [dominant
baseline](#dominant-baseline).

Given following sample markup:

``` highlight
<p><span class="outer">Ap <span class="inner">ਜੀ</span></span></p>
```

And the following style rule:

``` highlight
.inner { font-size: 75%; }
```

The [baseline sets](#baseline-set) of the parent (`.outer`) and the child (`.inner`) will
not match up due to the font size difference. The child box is aligned
to its parent by matching up their [alphabetic
baselines](#alphabetic-baseline).

!(images/baseline-align-sizes.gif){a
height="98" width="233"}

The [alphabetic
baseline](#alphabetic-baseline) is used here because by default a box's [alignment
baseline](#alignment-baseline) matches the [dominant
baseline](#dominant-baseline) of its parent, and in horizontal [typographic
mode](https://drafts.csswg.org/css-writing-modes-4/#typographic-mode), the [dominant baseline]
itself defaults to the [alphabetic
baseline].

If we add [vertical-align:
super](#propdef-vertical-align) to the `.inner` element from the example above,
the same rules are used to align the `.inner` child to its parent; but
in addition to the baseline alignment, the child is shifted to the
superscript position.

<figure>
<p><img src="images/baseline-align-super.gif" width="305" height="114"
a /></p>
</figure>

### 4.1. Dominant Baselines: the [dominant-baseline property]
Name:

[dominant-baseline]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<baseline-metric\>](#typedef-baseline-metric)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

block containers, inline boxes, table rows, grid containers, flex
containers, and SVG [text content
elements](https://w3c.github.io/svgwg/svg2-draft/text.html#TermTextContentElement)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property specifies the [dominant baseline], which is the default baseline
type used to align content within the box.

For [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box), the [dominant
baseline](#dominant-baseline) is used to align the box's text (and, unless otherwise
specified by
[vertical-align](#propdef-vertical-align), any
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) child boxes) by aligning each glyph/box's corresponding
baseline to the box's own [dominant
baseline]. For other boxes, it indicates
the default [alignment
baseline](#alignment-baseline) of any boxes participating in [baseline
alignment](https://drafts.csswg.org/css-align-3/#baseline-alignment) in the box's [alignment
context](https://drafts.csswg.org/css-align-3/#shared-alignment-context); see ([alignment-baseline:
baseline](#propdef-alignment-baseline) and
[\[CSS-ALIGN-3\]](#biblio-css-align-3 "CSS Box Alignment Module Level 3")).

The
[[\<baseline-metric\>](#typedef-baseline-metric)] value, which identifies specific
baseline metrics, expands to

``` prod
<baseline-metric> = text-bottom | alphabetic | ideographic | middle
 | central | mathematical | hanging | text-top
```

Values have the following meanings:

[auto]

: Equivalent to
 [alphabetic](#valdef-dominant-baseline-alphabetic) in [horizontal writing
 modes](https://drafts.csswg.org/css-writing-modes-4/#horizontal-writing-mode) and in [vertical writing
 modes](https://drafts.csswg.org/css-writing-modes-4/#vertical-writing-mode) when
 [text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation) is
 [sideways](https://drafts.csswg.org/css-writing-modes-4/#valdef-text-orientation-sideways). Equivalent to
 [central](#valdef-dominant-baseline-central) in [vertical writing
 modes] when
 [text-orientation] is
 [mixed](https://drafts.csswg.org/css-writing-modes-4/#valdef-text-orientation-mixed) or
 [upright](https://drafts.csswg.org/css-writing-modes-4/#valdef-text-orientation-upright).

 However, in SVG text, the origin point of glyphs (used for
 coordinate-based glyph positioning) is always handled as for
 [central](#valdef-dominant-baseline-central) in [vertical writing
 modes](https://drafts.csswg.org/css-writing-modes-4/#vertical-writing-mode).

[text-bottom]
: Use the [text-under
 baselines](#text-under-baseline).

[alphabetic]
: Use the [alphabetic
 baselines](#alphabetic-baseline).

[ideographic]
: Use the [ideographic-under
 baselines](#ideographic-under-baseline).

[middle]
: Use the [x-middle
 baselines](#x-middle-baseline); except under [text-orientation:
 upright](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation) (where the
 [alphabetic](#alphabetic-baseline) and
 [x-height](#x-height-baseline) baselines are essentially meaningless) use the
 [central baseline](#central-baseline).

[central]
: Use the [central
 baselines](#central-baseline).

[mathematical]
: Use the [math baselines](#math-baseline).

[hanging]
: Use the [hanging
 baselines](#hanging-baseline).

[text-top]
: Use the [text-over
 baselines](#text-over-baseline).

See
[\[CSS-WRITING-MODES-3\]](#biblio-css-writing-modes-3 "CSS Writing Modes Level 3")
for an introduction to dominant baselines.

Define behavior for mixed vertical
orientations that isn't nonsensical when specified baseline isn't
[central](#valdef-dominant-baseline-central).

### 4.2. Transverse Box Alignment: the [vertical-align property]
Name:

[vertical-align]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ first
[\|](https://drafts.csswg.org/css-values-4/#comb-one) last\]
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<\'alignment-baseline\'\>](#propdef-alignment-baseline) [\|\|]
[\<\'baseline-shift\'\>](#propdef-baseline-shift)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

baseline

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

This
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) property specifies how an inline-level box is aligned
within the line by specifying its [alignment
baseline](#alignment-baseline) type
([alignment-baseline](#propdef-alignment-baseline)), [baseline alignment
preference](#baseline-alignment-preference)
([baseline-source](#propdef-baseline-source)), and [post-alignment
shift](#post-alignment-shift)
([baseline-shift](#propdef-baseline-shift)) in a single declaration.

If
[first](#valdef-baseline-source-first) or
[last](#valdef-baseline-source-last) is specified, it sets
[baseline-source](#propdef-baseline-source) (which is otherwise reset to
[auto](#valdef-baseline-source-auto)). Other values are as for the corresponding
longhand properties, see below.

Authors should use this shorthand
([vertical-align](#propdef-vertical-align)) instead of its longhands, unless
specifically needing to cascade its longhands independently or (on SVG
elements) to support legacy SVG implementations.

[vertical-align](#propdef-vertical-align) can also affect the alignment of
table cells when
[align-content](https://drafts.csswg.org/css-align-3/#propdef-align-content) is
[normal](https://drafts.csswg.org/css-align-3/#valdef-justify-content-normal). Specifically,
[top](#valdef-baseline-shift-top) ([baseline-shift:
top](#propdef-baseline-shift)) maps it to
[start](https://drafts.csswg.org/css-align-3/#valdef-self-position-start),
[bottom](#valdef-baseline-shift-bottom) ([baseline-shift:
bottom]) to
[end](https://drafts.csswg.org/css-align-3/#valdef-self-position-end), and otherwise
[middle](https://drafts.csswg.org/css2/#valdef-vertical-align-middle) ([alignment-baseline:
middle](#propdef-alignment-baseline)) to
[center](https://drafts.csswg.org/css-align-3/#valdef-self-position-center). See [CSS Box Alignment 3 § 5.1.1 Block
Containers (Including Table
Cells)](https://drafts.csswg.org/css-align-3/#distribution-block).

#### 4.2.1. Alignment Baseline Source: the [baseline-source longhand]
Name:

[baseline-source]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) first [\|] last

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[inline-level
boxes](https://drafts.csswg.org/css-display-3/#inline-level-box) that establish an [independent formatting
context](https://drafts.csswg.org/css-display-4/#independent-formatting-context)

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

When an inline-level box has more than one possible source for baseline
information (such as for a multi-line inline block or inline flex
container) this property specifies whether the [first baseline
set](https://drafts.csswg.org/css-align-3/#first-baseline-set) or [last baseline
set](https://drafts.csswg.org/css-align-3/#last-baseline-set) is preferred for alignment, indicating the box's
[baseline alignment preference]. Values have the following
meanings:

[auto]
: Specifies [last-baseline
 alignment](https://drafts.csswg.org/css-align-3/#last-baseline-alignment) for
 [inline-block](https://drafts.csswg.org/css-display-4/#valdef-display-inline-block), [first-baseline
 alignment](https://drafts.csswg.org/css-align-3/#first-baseline-alignment) for everything else.

[first]
: Specifies [first-baseline
 alignment](https://drafts.csswg.org/css-align-3/#first-baseline-alignment).

[last]
: Specifies [last-baseline
 alignment](https://drafts.csswg.org/css-align-3/#last-baseline-alignment).

See [CSS Box Alignment 3 § 9.1 Determining the Baselines of a
Box](https://drafts.csswg.org/css-align-3/#baseline-export) for how to
find the baselines of boxes other than [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box).

#### 4.2.2. Alignment Baseline Type: the [alignment-baseline longhand]
Name:

[alignment-baseline]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

baseline
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<baseline-metric\>](#typedef-baseline-metric)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

baseline

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

inline-level boxes, flex items, grid items, table cells, and SVG [text
content
elements](https://w3c.github.io/svgwg/svg2-draft/text.html#TermTextContentElement)

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

This property specifies the box's [alignment
baseline]: the [baseline](#baseline) used to align the box prior to applying its
[post-alignment
shift](#post-alignment-shift) (if applicable). Values have the same meanings as for
[dominant-baseline](#propdef-dominant-baseline); the
[baseline] keyword uses
the [dominant baseline](#dominant-baseline) choice of the parent.

When performing [baseline
alignment](https://drafts.csswg.org/css-align-3/#baseline-alignment), these values specify which
[baseline](#baseline) of the box is
aligned to the corresponding [baseline] of its
[alignment
context](https://drafts.csswg.org/css-align-3/#shared-alignment-context). (In an [inline formatting
context](#inline-formatting-context),
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) [box
fragments](https://drafts.csswg.org/css-break-4/#box-fragment) and glyphs share an [alignment
context] established by their parent
[inline
box](https://drafts.csswg.org/css-display-3/#inline-box) [fragment] along its [inline
axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis). For other [formatting
contexts](https://drafts.csswg.org/css-display-4/#formatting-context), see [CSS Box Alignment 3 § 9.2 Baseline Alignment
Grouping](https://drafts.csswg.org/css-align-3/#baseline-terms).) In SVG
text layout, these values instead specify the
[baseline] that is aligned to the SVG [current text
position](https://w3c.github.io/svgwg/svg2-draft/text.html#TermCurrentTextPosition).

##### 4.2.2.1. Legacy Values for SVG

SVG implementations *may* support the following aliases in order to
support legacy content:

- [text-before-edge] aliasing
 [text-top](https://www.w3.org/TR/css-inline-3/#valdef-alignment-baseline-text-top)

- [text-after-edge]
 aliasing
 [text-bottom](https://www.w3.org/TR/css-inline-3/#valdef-alignment-baseline-text-bottom)

These values are not allowed in the
[vertical-align](#propdef-vertical-align) shorthand.

#### 4.2.3. Post-Alignment Shift: the [baseline-shift longhand]
Name:

[baseline-shift]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)
[\|](https://drafts.csswg.org/css-values-4/#comb-one) sub [\|] super
[\|] top [\|] center
[\|] bottom

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

inline-level boxes and SVG [text content
elements](https://w3c.github.io/svgwg/svg2-draft/text.html#TermTextContentElement)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to the used value of
[line-height](#propdef-line-height)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the specified keyword or a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

This property specifies the box's [post-alignment
shift]. The [baseline-relative shift
values]
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage),
[sub](#valdef-baseline-shift-sub),
[super](#valdef-baseline-shift-super) shift the box relative to its baseline-aligned
position, whereas the [line-relative shift
values]
[top](#valdef-baseline-shift-top),
[center](#valdef-baseline-shift-center), and
[bottom](#valdef-baseline-shift-bottom) shift the [inline
box](https://drafts.csswg.org/css-display-3/#inline-box) and its contents relative to the bounds of its [line
box](#line-box).

Authors should use the
[vertical-align](#propdef-vertical-align) shorthand, which has existed since
CSS1, instead of this
[baseline-shift](#propdef-baseline-shift) longhand (except in SVG content,
where conversely [baseline-shift] is more widely-supported in legacy user agents).

Values have the following meanings:

[[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)]
: Raise (positive value) or lower (negative value) by the specified
 length.

[[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)]
: Raise (positive value) or lower (negative value) by the specified
 percentage of the
 [line-height](#propdef-line-height).

[sub]
: Lower by the offset appropriate for subscripts of the parent's box.
 The UA may use the parent's font metrics to find this offset;
 otherwise it defaults to dropping by one fifth of the parent's used
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size).

[super]
: Raise by the offset appropriate for superscripts of the parent's
 box. The UA may use the parent's font metrics to find this offset;
 otherwise it defaults to raising by one third of the parent's used
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size).

[top]
: Align the
 [line-over](https://drafts.csswg.org/css-writing-modes-4/#line-over) edge of the [aligned
 subtree](#aligned-subtree) with the [line-over] edge of
 the [line box](#line-box).

[center]
: Align the center of the [aligned
 subtree](#aligned-subtree) with the center of the [line
 box](#line-box).

[bottom]
: Align the
 [line-under](https://drafts.csswg.org/css-writing-modes-4/#line-under) edge of the [aligned
 subtree](#aligned-subtree) with the [line-under] edge of
 the [line box](#line-box).

The [aligned subtree] of an [inline
box](https://drafts.csswg.org/css-display-3/#inline-box) contains the [layout
bounds](#layout-bounds) of that
box and the [aligned
subtrees](#aligned-subtree)
of all child [inline boxes] whose computed
[alignment-baseline](#propdef-alignment-baseline) value is not itself a
[line-relative shift
value](#line-relative-shift-values). The
[line-over](https://drafts.csswg.org/css-writing-modes-4/#line-over) edge of the [aligned
subtree] is the highest
[over](https://drafts.csswg.org/css-writing-modes-4/#over) edge of the [layout bounds] in
the subtree, and the
[line-under](https://drafts.csswg.org/css-writing-modes-4/#line-under) edge is analogously the lowest.

The [line-relative shift
values](#line-relative-shift-values) don't fit perfectly in the dichotomy between
[alignment-baseline](#propdef-alignment-baseline) and
[baseline-shift](#propdef-baseline-shift). There's
[decent](https://github.com/w3c/csswg-drafts/issues/5180)
[arguments](https://github.com/w3c/csswg-drafts/issues/5234) for either
option. They're currently drafted here, but if there's a strong argument
to move them, please file an issue for consideration.

##### 4.2.3.1. Legacy Values for SVG

User agents *may* additionally support the keyword
[baseline] as computing to
[0] if is necessary for them to support legacy SVG content. This
value is not allowed in the
[vertical-align](#propdef-vertical-align) shorthand.

We would prefer to remove the
[baseline](#valdef-baseline-shift-baseline) value, and are looking for feedback from SVG
user agents as to whether it's necessary.

## 5. Logical Heights and Inter-line Spacing

The
[block-axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) sizing of a [line box](#line-box) depends on the sizes and [alignment](#alignment) of its
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) contents. This sizing is controlled by the
[line-height](#propdef-line-height) and
[line-fit-edge](#propdef-line-fit-edge) properties.

### 5.1. Line Spacing: the [line-height property]
Name:

[line-height]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<number
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value) [\|]
[\<length-percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

non-replaced inline boxes and SVG [text content
elements](https://w3c.github.io/svgwg/svg2-draft/text.html#TermTextContentElement)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

computed relative to [1em]

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the specified keyword, a number, or a computed
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

This property specifies the box's [preferred line
height], which is used in calculating its "[layout
bounds](#layout-bounds)", i.e.
its contribution to the [logical
height](https://drafts.csswg.org/css-writing-modes-4/#logical-height) of its [line box](#line-box). (See [§ 5.3 Calculating the Logical Height
Contributions ("Layout Bounds") of Inline Boxes](#inline-height).)

 Because it applies to the [root inline
box](#root-inline-box) when
specified on a [block
container](https://drafts.csswg.org/css-display-4/#block-container),
[line-height](#propdef-line-height) effectively establishes the minimum
height of the block's [line boxes](#line-box).

Values for this property have the following meanings:

[normal]
: Determine the [preferred line
 height](#preferred-line-height) automatically based on the metrics of the used
 font.

[[\<length \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#length-value)]
: The specified length is used as the [preferred line
 height](#preferred-line-height). Negative values are illegal.

[[\<number \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value)]
: The [preferred line
 height](#preferred-line-height) is this number multiplied by the element's used
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size). Negative values are illegal.
 The [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) is the same as the [specified
 value](https://drafts.csswg.org/css-cascade-5/#specified-value).

[[\<percentage \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#percentage-value)]
: The [preferred line
 height](#preferred-line-height) and [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of the property is this percentage of the element's
 computed
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size). Negative values are illegal.

 Metrics from fonts other than the [first available
font](https://drafts.csswg.org/css-fonts-4/#first-available-font) only impact the [layout
bounds](#layout-bounds) of an
[inline
box](https://drafts.csswg.org/css-display-3/#inline-box) with [line-height:
normal](#propdef-line-height).

The three rules in the example below
have the same used line height:

``` highlight
div { line-height: 1.2; font-size: 10pt } /* number */
div { line-height: 1.2em; font-size: 10pt } /* length */
div { line-height: 120%; font-size: 10pt } /* percentage */
```

However, they inherit differently: the first one inherits as a number,
which will lead to different line heights if descendants have different
font sizes; the last two as inherit as absolute lengths, which will not
be influenced by the font size on descendants.

The fact that percentages compute to
lengths is annoying. See also [Issue
3118](https://github.com/w3c/csswg-drafts/issues/3118) and [Issue
2165](https://github.com/w3c/csswg-drafts/issues/2165).

 When
[line-fit-edge](#propdef-line-fit-edge) is
[leading](#valdef-line-fit-edge-leading), the margins, borders, and padding of [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box) do not affect the line box's height calculation.
However, they are still rendered around these boxes. This means that if
the size specified by
[line-height](#propdef-line-height) is less than the size of the box,
backgrounds and borders can "bleed" into adjoining line boxes,
potentially obscuring earlier content.

### 5.2. Text Edge Metrics: the [line-fit-edge property]
Name:

[line-fit-edge]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

leading
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<text-edge\>](#typedef-text-edge)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

leading

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This is an early draft of a proposal,
and might change significantly as design critiques and use cases are
registered and various details and interactions with other properties
are worked out. **Do not ship (yet).**

[Inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box), whose primary purpose is to contain text, are sized in
the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) based on their font metrics. The
[line-fit-edge](#propdef-line-fit-edge) property controls which metrics are
used. These chosen metrics are used as the basis for the [layout
bounds](#layout-bounds) of the
[inline box] (if it is not the [root inline
box](#root-inline-box)); and
also, by default, are the metrics used for
[text-box-trim](#propdef-text-box-trim).

The [[\<text-edge\>](#typedef-text-edge)] value, which identifies specific
font metrics, expands to

``` prod
<text-edge> = [ text | ideographic | ideographic-ink ]
 | [ text | ideographic | ideographic-ink | cap | ex ]
 [ text | ideographic | ideographic-ink | alphabetic ]
```

The first value specifies the text
[over](https://drafts.csswg.org/css-writing-modes-4/#over) edge; the second value specifies the text
[under](https://drafts.csswg.org/css-writing-modes-4/#under) edge. If only one value is specified, both edges are
assigned that same keyword if possible; else [text] is assumed as
the missing value.

Do we need
[longhands](https://drafts.csswg.org/css-cascade-5/#longhand) or is this shorthand enough? [\[Issue
#5236\]](https://github.com/w3c/csswg-drafts/issues/5236)

Values have the following meanings:

[leading]
: Use the [ascent](#ascent-metric)/[descent](#descent-metric) plus any positive
 [half-leading](#half-leading). Margin/padding/border is ignored for the purpose
 of sizing the [line box](#line-box).

[text]
: Use the [text-over
 baseline](#text-over-baseline)/[text-under
 baseline](#text-under-baseline) as the
 [over](https://drafts.csswg.org/css-writing-modes-4/#over)/[under](https://drafts.csswg.org/css-writing-modes-4/#under) edge.

[cap]
: Use the [cap-height
 baseline](#cap-height-baseline) as the
 [over](https://drafts.csswg.org/css-writing-modes-4/#over) edge.

[ex]
: Use the [x-height
 baseline](#x-height-baseline) as the
 [over](https://drafts.csswg.org/css-writing-modes-4/#over) edge.

[ideographic]
: Use the [ideographic-over
 baseline](#ideographic-over-baseline)/[ideographic-under
 baseline](#ideographic-under-baseline) as the
 [over](https://drafts.csswg.org/css-writing-modes-4/#over)/[under](https://drafts.csswg.org/css-writing-modes-4/#under) edge.

[ideographic-ink]
: Use the [ideographic-ink-over
 baseline](#ideographic-ink-over-baseline)/[ideographic-ink-under
 baseline](#ideographic-ink-under-baseline) as the
 [over](https://drafts.csswg.org/css-writing-modes-4/#over)/[under](https://drafts.csswg.org/css-writing-modes-4/#under) edge.

[alphabetic]
: Use the [alphabetic
 baseline](#alphabetic-baseline) as the
 [under](https://drafts.csswg.org/css-writing-modes-4/#under) edge.

Is
[text](#valdef-line-fit-edge-text) a reasonable name for the ascent/descent
metrics, or can we think of something better? Ditto
[leading](#valdef-line-fit-edge-leading) as a keyword. [\[Issue
#8067\]](https://github.com/w3c/csswg-drafts/issues/8067)

Unless
[line-fit-edge](#propdef-line-fit-edge) is
[leading](#valdef-line-fit-edge-leading)---​in which case the box's own
[line-height](#propdef-line-height) is used to add spacing---​the box's
margin, padding, and border also contribute to the [layout
bounds](#layout-bounds).

 The
[leading](#valdef-line-fit-edge-leading) and
[text](#valdef-line-fit-edge-text) values rely on the font
[ascent](#ascent-metric) and
[descent](#descent-metric) to
make sure the text fits. Other values are more likely to result in
overlap or overflow caused by ascents above the specified metrics (such
as for diacritics), so authors using these values need to be careful to
provide sufficient spacing for the text, particularly in multi-lingual
contexts.

![The
[line-fit-edge](#propdef-line-fit-edge) property, showing values for
[leading](#valdef-line-fit-edge-leading),
[cap](#valdef-line-fit-edge-cap), and
[ex](#valdef-line-fit-edge-ex). The red lines indicate the layout bounds of the
inline box.\
This illustration doesn't match actual font metrics, it's actually
illustrating the cap-height, not the ascent. [\[Issue
#11364\]](https://github.com/w3c/csswg-drafts/issues/11364)](images/text-edge.png){a
height="444" width="480"}

[line-fit-edge](#propdef-line-fit-edge) is
[leading](#valdef-line-fit-edge-leading), vertical rhythm can be broken any time there is
a change in font metrics or vertical alignment within a paragraph.

Other values are more likely to give consistent line spacing---​as long
as there is enough leading added that the half-leading on the root
inline is large enough to accommodate the specified metrics of any
descendants. The line box will still grow, however, to accommodate
content that would otherwise overflow, to avoid overlap between lines.

 Although only
[leading](#valdef-line-fit-edge-leading) applies positive
[half-leading](#half-leading),
in order to allow text to be set tightly, all values apply negative
[half-leading], see [§ 5.3 Calculating the
Logical Height Contributions ("Layout Bounds") of Inline
Boxes](#inline-height). Half-leading is applied equally to both sides of
the text; for more precise overlap control authors can use
[line-fit-edge:
text](#propdef-line-fit-edge) together with negative
[margins](https://drafts.csswg.org/css-box-4/#margin) on the affected text.

### 5.3. Calculating the Logical Height Contributions ("Layout Bounds") of Inline Boxes

The contribution of an [inline
box](https://drafts.csswg.org/css-display-3/#inline-box) to the [logical
height](https://drafts.csswg.org/css-writing-modes-4/#logical-height) of its [line box](#line-box), here referred to as its [layout bounds], is always calculated with
respect to its own text metrics, as described below, and is controlled
by
[line-fit-edge](#propdef-line-fit-edge) and
[line-height](#propdef-line-height). The sizes and positions of child boxes
do not influence its [layout
bounds](#layout-bounds) (nor
its own [logical height], for that matter, see
[inline-sizing](#propdef-inline-sizing)).

 The [layout
bounds](#layout-bounds) need
not correspond to the box's
[edges](https://drafts.csswg.org/css-box-4/#box-box-edge).

To find the [layout bounds](#layout-bounds) of an [inline
box](https://drafts.csswg.org/css-display-3/#inline-box), the UA must first align all the glyphs *directly*
contained in the [inline box] to each other by
their [dominant
baselines](#dominant-baseline). (See [§ 3.3 Baselines of Glyphs and
Boxes](#baseline-tables).) If the [inline box]
contains no glyphs at all, or if it contains only glyphs from fallback
fonts, it is considered to contain a "strut" (an invisible glyph of zero
width) with the metrics of the box's [first available
font](https://drafts.csswg.org/css-fonts-4/#first-available-font).

For each glyph (including the "strut"), `A` represents its
ascent above the [baseline](#baseline); `D` represents its descent below. Unless
[line-fit-edge](#propdef-line-fit-edge) specifies a different metric to
use, `A` refers to the [ascent
metric](#ascent-metric) (for
the given font at its given size) and `D` to the [descent
metric](#descent-metric), each
adjusted to account for the [dominant
baseline](#dominant-baseline)'s offset from zero. If
[line-height](#propdef-line-height) computes to
[normal](#valdef-line-height-normal) and either
[line-fit-edge] is
[leading](#valdef-line-fit-edge-leading) or this is the [root inline
box](#root-inline-box), the
font's [line gap metric](#line-gap-metric) may also be incorporated into `A` and
`D` by adding half to each side as
[half-leading](#half-leading).

**When its computed
[line-height](#propdef-line-height) is
[normal](#valdef-line-height-normal)**, the [layout
bounds](#layout-bounds) of an
inline box encloses all its glyphs, going from the highest
`A` to the deepest `D`. (Note that glyphs in a
single box can come from different fonts and thus might not all have the
same `A` and `D`.)

**When its computed
[line-height](#propdef-line-height) is not
[normal](#valdef-line-height-normal)**, its [layout
bounds](#layout-bounds) are
derived solely from metrics of its [first available
font](https://drafts.csswg.org/css-fonts-4/#first-available-font) (ignoring glyphs from other fonts), and
[leading] is used
to adjust the effective `A` and `D` to add up to
the used
[line-height](#propdef-line-height). Calculate the
[leading](#leading) `L` as
`L` = [line-height] - (`A` + `D`). Half the
[leading] (its [half-leading]) is added above `A`
of the first available font, and the other half below `D` of
the first available font, giving an effective ascent above the baseline
of `A′` = `A` + `L`/2, and an effective
descent of `D′` = `D` + `L`/2. However,
if
[line-fit-edge](#propdef-line-fit-edge) is not
[leading](#valdef-line-fit-edge-leading) and this is not the [root inline
box](#root-inline-box), if
the [half-leading](#half-leading) is positive, treat it as zero. The [layout
bounds] exactly encloses this effective
`A′` and `D′`.

 `L` may be negative.

Additionally, when
[line-fit-edge](#propdef-line-fit-edge) is not
[leading](#valdef-line-fit-edge-leading), the [layout
bounds](#layout-bounds) are
inflated by the sum of the
[margin](https://drafts.csswg.org/css-box-4/#margin),
[border](https://drafts.csswg.org/css-box-4/#border), and
[padding](https://drafts.csswg.org/css-box-4/#padding) on each side. In order to allow negative
[margin] values to have an actual effect, negative
[margins] are also accumulated onto the [layout
bounds] of any descendant [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box) participating in the same [inline formatting
context](#inline-formatting-context).

In Quirks Mode
[\[QUIRKS\]](#biblio-quirks "Quirks Mode Standard"),
any [inline
box](https://drafts.csswg.org/css-display-3/#inline-box)
[fragment](https://drafts.csswg.org/css-break-4/#box-fragment) that has zero borders and padding and that does not
directly contain text or [preserved white
space](https://drafts.csswg.org/css-text-4/#preserved-white-space)
[\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3")
is ignored when sizing the [line box](#line-box).

## 6. Trimming Leading Over/Under Text

To ensure consistent spacing in the basic case of running text, CSS line
layout introduces leading both above and below the text content of each
line as needed to ensure its
[line-height](#propdef-line-height). In addition, the ascent and descent
font metrics themselves often include extra space above and below the
most typical glyph shapes in order to accommodate occasional characters
and diacritics that ascend or descend beyond the typical bounds. This
prevents adjacent lines of text from overlapping each other. However,
all this extra spacing interferes with visual alignment and with control
over effective (visually-apparent) spacing.

The [text-box](#propdef-text-box) property allows trimming this additional
space above and below the first and last lines of a block, allowing more
precise control over spacing around the glyphs. By relying on font
metrics rather than hard-coded lengths, this feature allows content to
be resized, rewrapped, and rendered in a variety of fonts while
maintaining that precise spacing.

A common problem is vertical centering. It's easy to vertically center
the text container to an icon, but because the visual boundaries of
Latin text are the cap height and the alphabetic baseline, rather than
the ascent and descent, this often doesn't yield the intended visual
effect.

![Measuring to the top/bottom of the text may yield equal results, but
measuring to the visual bounds shows that it is not visually
centered.](images/leading-trim-centering-fail.png){a
height="130" width="730"}

To center the text visually, it's necessary to assume the cap height and
alphabetic baseline as the top and bottom edges of the text,
respectively.

![Measuring to the cap height / alphabetic baseline instead of the
ascent / descent and equalizing those distances visually centers the
text.](images/leading-trim-centering-goal.png){a
height="130" width="357"}

By using
[text-box-trim](#propdef-text-box-trim) to strip out the spacing above the
cap height and below the alphabetic baseline, centering the box actually
centers the text; and does so reliably, regardless of what font is used
to render it.

![Even though different fonts have different cap heights, by using the
font's metric rather than a magic number, the layout intention is met
even as the font is
changed.](images/leading-trim-centering-variants.gif){height="148"
width="448"}

### 6.1. Shorthand for Text Box Trimming: the [text-box property]
Name:

[text-box]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<\'text-box-trim\'\>](#propdef-text-box-trim)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<\'text-box-edge\'\>](#propdef-text-box-edge)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[block
containers](https://drafts.csswg.org/css-display-4/#block-container), [multi-column
containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container), and [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property is a
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) for setting the
[text-box-trim](#propdef-text-box-trim) and
[text-box-edge](#propdef-text-box-edge) properties in a single declaration.

If the single keyword [normal] is
specified, it sets
[text-box-trim](#propdef-text-box-trim) to
[none](#valdef-text-box-trim-none) and
[text-box-edge](#propdef-text-box-edge) to
[auto](#valdef-text-box-edge-auto). Otherwise, omitting the
[text-box-trim] value sets it
to
[trim-both](#valdef-text-box-trim-trim-both) (not the initial value), while omitting the
[text-box-edge] value sets it
to [auto] (the initial value).

Add examples.

### 6.2. Trimming Over/Under Text: the [text-box-trim property]
Name:

[text-box-trim]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) trim-start [\|] trim-end
[\|] trim-both

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[block
containers](https://drafts.csswg.org/css-display-4/#block-container), [multi-column
containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container), and [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

On [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box), specifies whether to trim the [content
box](https://drafts.csswg.org/css-box-4/#content-box) to match the specified
[text-box-edge](#propdef-text-box-edge) metric. See [§ 5.3 Calculating the
Logical Height Contributions ("Layout Bounds") of Inline
Boxes](#inline-height) for details.

On [block
containers](https://drafts.csswg.org/css-display-4/#block-container), as well as on each column of a [multi-column
container](https://drafts.csswg.org/css-multicol-2/#multi-column-container), specifies whether to trim
[half-leading](#half-leading) at
the start/end of the box's content to better match its [content
edge](https://drafts.csswg.org/css-box-3/#content-edge) to its text content. The trimming edge in this case is
specified by the start/end
[text-box-edge](#propdef-text-box-edge) value of the affected [line
box](#line-box)'s [containing
block](https://drafts.csswg.org/css-display-3/#containing-block).

Values have the following meanings:

[none]

: No special handling of the first/last [line
 box](#line-box) when applied to
 a [block
 container](https://drafts.csswg.org/css-display-4/#block-container).

 When applied to an [inline
 box](https://drafts.csswg.org/css-display-3/#inline-box), specifies that the over/under [content
 edges](https://drafts.csswg.org/css-box-3/#content-edge) coincide with the
 [text-over](#text-over-baseline)/[text-under](#text-under-baseline) baselines regardless of
 [text-box-edge](#propdef-text-box-edge).

[trim-start]

: For [block
 containers](https://drafts.csswg.org/css-display-4/#block-container) and [column
 boxes](https://drafts.csswg.org/css-multicol-2/#column-box): trim the
 [block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start) side of the [first formatted
 line](https://drafts.csswg.org/css-pseudo-4/#first-formatted-line) to the specified metric of its [root inline
 box](#root-inline-box).
 If there is no such line, or if there is intervening non-zero
 padding or borders, there is no effect.

 For [inline
 boxes](https://drafts.csswg.org/css-display-3/#inline-box): trims the
 [block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start) side of the box to match its [content
 edge](https://drafts.csswg.org/css-box-3/#content-edge) to the metric specified by
 [text-box-edge](#propdef-text-box-edge).

[trim-end]

: For [block
 containers](https://drafts.csswg.org/css-display-4/#block-container) and [column
 boxes](https://drafts.csswg.org/css-multicol-2/#column-box): trim the
 [block-end](https://drafts.csswg.org/css-writing-modes-4/#block-end) side of the last formatted line to the specified
 metric of its [root inline
 box](#root-inline-box).
 If there is no such line, or if there is intervening non-zero
 padding or borders, there is no effect.

 For [inline
 boxes](https://drafts.csswg.org/css-display-3/#inline-box): trims the
 [block-end](https://drafts.csswg.org/css-writing-modes-4/#block-end) side of the box to match its [content
 edge](https://drafts.csswg.org/css-box-3/#content-edge) to the metric specified by
 [text-box-edge](#propdef-text-box-edge).

[trim-both]
: Specifies the behavior of
 [trim-start](#valdef-text-box-trim-trim-start) and
 [trim-end](#valdef-text-box-trim-trim-end) simultaneously.

 Like
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line), this property does not apply to, or propagate
through, flex, grid, or table [formatting
contexts](https://drafts.csswg.org/css-display-4/#formatting-context).

 The
[block-end](https://drafts.csswg.org/css-writing-modes-4/#block-end) side does not coincide with the
[line-under](https://drafts.csswg.org/css-writing-modes-4/#line-under) side when
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) is
[vertical-lr](https://drafts.csswg.org/css-writing-modes-4/#valdef-writing-mode-vertical-lr).

If multiple ancestors specify trimming on the same [line
box](#line-box), the metric used is
that of the innermost [block
container](https://drafts.csswg.org/css-display-4/#block-container) that requests trimming on that side of the [line
box].

 Content and ink overflowing a box due to non-initial
values of
[text-box-trim](#propdef-text-box-trim) is handled the same as content that
would overflow the box or line box otherwise.

Unlike
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line), when applying to the first (or last) formatted
line of a [multi-column
container](https://drafts.csswg.org/css-multicol-2/#multi-column-container), this property applies to the first (or last) formatted
lines of *every* column in the [multi-column
container].

What happens if the column is split by a
spanner? [\[Issue
#11363\]](https://github.com/w3c/csswg-drafts/issues/11363)

When the box to which
[text-box-trim](#propdef-text-box-trim) has been applied is split by
[fragmentation](https://drafts.csswg.org/css-break-4/#fragmentation)
[\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3"),
whether trimming is applied per fragment or only to the start/end edges
of its first/last fragments is determined by
[box-decoration-break](https://drafts.csswg.org/css-break-4/#propdef-box-decoration-break).

If, when printing, trimming a [line box](#line-box) would cause its content to be clipped, the UA may
ignore
[text-box-trim](#propdef-text-box-trim) on that edge of that [line
box].

### 6.3. Text Trimming Metrics: the [text-box-edge property]
Name:

[text-box-edge]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<text-edge\>](#typedef-text-edge)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[block
containers](https://drafts.csswg.org/css-display-4/#block-container) and [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property specifies the metrics to use for
[text-box-trim](#propdef-text-box-trim) effects. Values have the same
meanings as for
[line-fit-edge](#propdef-line-fit-edge); the
[auto] keyword uses the
value of [line-fit-edge],
interpreting
[leading](#valdef-line-fit-edge-leading) (the [initial
value](https://drafts.csswg.org/css-cascade-5/#initial-value)) as
[text](#valdef-line-fit-edge-text).

 This property can be set together with
[text-box-trim](#propdef-text-box-trim) in the
[text-box](#propdef-text-box)
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property). Unlike
[line-fit-edge](#propdef-line-fit-edge), it does not inherit; however its
[initial
value](https://drafts.csswg.org/css-cascade-5/#initial-value) copies from
[line-fit-edge], which does
inherit.

### 6.4. Inline Box Drawing Height: the [inline-sizing property]
Name:

[inline-sizing]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) stretch

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box), but not [ruby container
boxes](https://drafts.csswg.org/css-ruby-1/#ruby-container) nor [internal ruby
boxes](https://drafts.csswg.org/css-ruby-1/#internal-ruby-boxes)

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

This has a confusing name. We need a new
name. Alternatively, incorporate this into
[text-box-trim](#propdef-text-box-trim)? [\[Issue
#5189\]](https://github.com/w3c/csswg-drafts/issues/5189)

This property specifies how the [logical
height](https://drafts.csswg.org/css-writing-modes-4/#logical-height) of the [content
area](https://drafts.csswg.org/css-box-4/#content-area) of an [inline
box](https://drafts.csswg.org/css-display-3/#inline-box) is measured in relation to its contents. It has no
effect on the size or position of the box's contents, the line box, or
any other content.

Values have the following meanings:

[normal]

: The [content
 area](https://drafts.csswg.org/css-box-4/#content-area) of the [inline
 box](https://drafts.csswg.org/css-display-3/#inline-box) is sized and positioned to fit (possibly
 hypothetical) text from its [first available
 font](https://drafts.csswg.org/css-fonts-4/#first-available-font). If
 [text-box-trim](#propdef-text-box-trim) indicates trimming, then the
 specified metric must be used. Otherwise, this specification does
 not specify how. A UA may, e.g., use the maximum ascender and
 descender of the font. (This would ensure that glyphs with parts
 above or below the em-box still fall within the content area, but
 leads to differently sized boxes for different fonts.)

 If more than one font is used (which happen when
 glyphs are found in different fonts), the [logical
 height](https://drafts.csswg.org/css-writing-modes-4/#logical-height) of the [content
 area](https://drafts.csswg.org/css-box-4/#content-area) is not affected by the glyphs from the fallback
 fonts, and only depends on the [first available
 font](https://drafts.csswg.org/css-fonts-4/#first-available-font). However, these fallback glyphs can still affect
 the [line box](#line-box) size
 when
 [line-height](#propdef-line-height) is
 [normal](#valdef-line-height-normal); see [§ 5.3 Calculating the Logical Height
 Contributions ("Layout Bounds") of Inline Boxes](#inline-height).

[stretch]
: Once the [line box](#line-box)
 has been sized and its contents positioned as for
 [normal](#valdef-inline-sizing-normal), the [inline
 box](https://drafts.csswg.org/css-display-3/#inline-box)'s [box
 edges](https://drafts.csswg.org/css-box-4/#box-box-edge) are shifted such that its
 [over](https://drafts.csswg.org/css-writing-modes-4/#over)/[under](https://drafts.csswg.org/css-writing-modes-4/#under) [margin
 edges](https://drafts.csswg.org/css-box-3/#margin-edge) coincide with the corresponding [line
 box]'s edges, stretching the [inline
 box]'s
 [inner](https://drafts.csswg.org/css-sizing-3/#inner-size) [logical
 height](https://drafts.csswg.org/css-writing-modes-4/#logical-height) so that its
 [block-axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) [outer
 size](https://drafts.csswg.org/css-sizing-3/#outer-size) fills the [line box]. (The
 sizes and positions of its
 [in-flow](https://drafts.csswg.org/css-display-3/#in-flow) contents are not affected.)

 The
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) property does not apply to [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box).

 The
[line-height](#propdef-line-height) has no impact on the size of an [inline
box](https://drafts.csswg.org/css-display-3/#inline-box), it only [affects its contribution](#inline-height) to
the [logical
height](https://drafts.csswg.org/css-writing-modes-4/#logical-height) of its [line box](#line-box).

## 7. Initial Letters

The editors would appreciate any examples
of drop initials in non-western scripts, especially Indic scripts.

### 7.1. An Introduction to Initial Letters

*This section is non-normative.*

Large, decorative letters have been used to start new sections of text
since before the invention of printing. In fact, their use predates
lowercase letters entirely.

#### 7.1.1. Drop Initial

A [dropped initial] (or "drop cap") is a larger-than-usual letter at the start
of a paragraph, with a baseline at least one line lower than the first
baseline of the paragraph. The size of the drop initial is usually
indicated by how many lines it occupies. Two- and three-line drop
initials are very common.

![Three-line drop initial with E acute. Since the cap-height of the drop
initial aligns with the cap-height of the main text, the accent extends
above the
paragraph.](images/Dropcap-E-acute-3line.png){a
height="160" width="480"}

The exact size and position of a [dropped
initial](#dropped-initial)
depends on the alignment of its glyph. Reference points on the drop cap
must align precisely with reference points in the text. The alignment
constraints for drop initials depend on the writing system.

In Western scripts, the top reference points are the cap height of the
initial letter and of the first line of text. The bottom reference
points are the alphabetic baseline of the initial letter and the
baseline of the Nth line of text. The figure below shows a simple
two-line drop cap, with the relevant reference lines marked.

![Two-line drop cap showing baselines (green lines), cap-height (red
line), and ascender (cyan
line).](images/Dropcap-lines.png){a
height="191" width="600"}

In Han-derived scripts, the initial letter extends from the
[block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start) edge of the glyphs on the first line to the
[block-end](https://drafts.csswg.org/css-writing-modes-4/#block-end) edge of the glyphs on the Nth line.

![Two-line drop initial in vertical writing
mode](images/Initial-2line-JapaneseVertical.png){a
height="417" width="480"}

In certain Indic scripts, the top alignment point is the hanging
baseline, and the bottom alignment point is the text-after-edge.

![Devanagari [initial letter](#initial-letter) aligned with hanging baseline. Alignment points shown
in red.](images/Devangari-Initial.png){a
height="195" width="480"}

#### 7.1.2. Sunken Initial Letters

Some styles of drop initials do not align with the first line of text. A
[sunken initial] (or "sunken cap") both sinks below the first baseline, and
extends above the first line of text.

![Sunken cap. The letter drops two lines, but is the size of a
three-line initial
letter.](images/SunkenCapA.png){a height="184"
width="480"}

#### 7.1.3. Raised Initial Letters

A [raised initial] (often called a "raised cap" or "stick-up cap") "sinks" to
the first text baseline.

 A proper raised initial has several advantages over
simply increasing the font size of a first letter. The line spacing in
the rest of the paragraph will not be altered, but text will still be
excluded around large descenders. And if the size of raised initial is
defined to be an integral number of lines, implicit baseline grids can
be maintained.

![Raised cap. The initial letter is the size of a 3-line initial, but
does not drop.](images/RaisedCap.png){a height="180"
width="480"}

### 7.2. Selecting Initial Letters

*This section is non-normative.*

Initial letters are typically a single letter, although they may include
punctuation or a sequence of characters which are perceived by the user
to be a single typographic unit. The
[::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter) pseudo-element, defined in
[\[SELECT\]](#biblio-select "Selectors Level 3") and
[\[CSS-PSEUDO-4\]](#biblio-css-pseudo-4 "CSS Pseudo-Elements Module Level 4"),
can be used to select the character(s) to be formatted as [initial
letters](#initial-letter).

Authors who need more control over which characters are included in an
initial letter, or who want to apply initial-letter formatting to
replaced elements or multiple words can alternately apply the
[initial-letter](#propdef-initial-letter) property to the first inline-level
child of a block container.

<p>This paragraph has a dropped “T”.
 <p><img a src="illuminated-h.svg">ere we have an illuminated “H”.
 <p><span>Words may also</span> be given initial letter styling at the beginning of a paragraph.

 ::first-letter, /* style first paragraph's T */
 img, /* style illuminated H */
 span /* style phrase inside span */
 { initial-letter: 2; }

Note that since
[::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter) selects punctuation before or after the first
letter, these characters are included in the [initial
letter](#initial-letter) when
[::first-letter] is used.

![The
[::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter) pseudo-element selects the quotation mark as
well as the
"M".](images/initial-letter-punctuation-quote.png){a
height="108" width="604"}

Should there be a way to opt out of this
behavior? See [GitHub Issue
310](https://github.com/w3c/csswg-drafts/issues/310).

### 7.3. Creating Initial Letters: the [initial-letter property]
Name:

[initial-letter]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<number
\[1,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value) [\<integer
\[1,∞\]\>](https://drafts.csswg.org/css-values-4/#integer-value) [\|] [\<number
\[1,∞\]\>]
[&&](https://drafts.csswg.org/css-values-4/#comb-all) \[ drop [\|] raise
\][?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

certain inline-level boxes and [::first-letter] and inside
[::marker] boxes ([see prose](#first-most-inline-level))

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[normal](#valdef-initial-letter-normal) or a number paired with an integer

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

This property specifies the
[size](#initial-letter-initial-letter-size) and
[sink](#initial-letter-initial-letter-sink) for dropped, raised, and sunken initial letters as the
number of lines spanned.

For example, the following code will
create a 2-line dropped initial letter at the beginning of each
paragraph that immediately follows a second-level heading:

 h2 + p::first-letter { initial-letter: 2; }

It takes the following values:

[normal]
: No special initial letter effect. Text behaves as normal.

[[\<number \[1,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value)]
: This first argument defines the
 [size] of the initial letter in terms of how many lines it
 occupies. Values less than one are invalid.

[[\<integer \[1,∞\]\>](https://drafts.csswg.org/css-values-4/#integer-value)]
: This optional second argument defines the number of lines the
 initial letter should [sink]. A value of
 [1] indicates a [raised
 initial](#raised-initial);
 values greater than [1] indicate a [sunken
 initial](#sunken-initial).
 Values less than one are invalid.

[raise]
: Computes to an [initial letter
 sink](#initial-letter-initial-letter-sink) of [1].

[drop]
: Computes to an [initial letter
 sink](#initial-letter-initial-letter-sink) equal to the [initial letter
 size](#initial-letter-initial-letter-size) floored to the nearest positive whole number.

If the [initial letter
sink](#initial-letter-initial-letter-sink) value is omitted,
[drop](#valdef-initial-letter-drop) is assumed.

Values other than
[normal](#valdef-initial-letter-normal) cause the affected box to become an [initial
letter box], which is an
[in-flow](https://drafts.csswg.org/css-display-3/#in-flow) [inline-level
box](https://drafts.csswg.org/css-display-3/#inline-level-box) with special layout behavior.

Here are some examples of
[initial-letter](#propdef-initial-letter) usage:

[initial-letter: 3](#propdef-initial-letter)\
[initial-letter: 3 3](#propdef-initial-letter)\
[initial-letter: 3 drop](#propdef-initial-letter)\
[initial-letter: drop 3](#propdef-initial-letter)

: Represents a [dropped
 initial](#dropped-initial) 3 lines high, 3 lines deep.

 ![3 lines high, 3 lines
 deep](images/InitialLetter33.png){height="152" width="450"}

[initial-letter: 3 2](#propdef-initial-letter)

: Represents a [sunken
 initial](#sunken-initial)
 3 lines high, 2 lines deep.

 ![3 lines high, 2 lines
 deep](images/InitialLetter32.png){height="152" width="450"}

[initial-letter: 3 1](#propdef-initial-letter)\
[initial-letter: 3 raise](#propdef-initial-letter)\
[initial-letter: raise 3](#propdef-initial-letter)

: Represents a [raised
 initial](#raised-initial)
 3 lines high, 1 line deep.

 ![3 lines high, 1 line
 deep](images/InitialLetter31.png){height="152" width="450"}

[initial-letter: 2.51 3](#propdef-initial-letter)

: The size of the initial letter does not have to be an integral
 number of lines. In this case only the top aligns.

 ![Non-integral initial letter that only aligns at
 top](images/non-integer-initial.png){height="152" width="450"}

In conjunction with other CSS
properties, [initial-letter] can be used to create "adjacent
initial letters," where the initial letter is adjacent to the text:

 p::first-letter {
 initial-letter: 3;
 color: red;
 width: 5em;
 text-align: right;
 margin-left: -5em;
 }

 p {
 margin-left: 5em;
 }

!(images/adjacent-initial-letter.png){a
height="219" width="360"}

#### 7.3.1. Applicability

To give authors more control over which characters can be styled as an
[initial letter](#initial-letter) and to allow the possibility of multi-character
[initial letters] (such as for first word or
first phrase styling), the
[initial-letter](#propdef-initial-letter) property applies not just to the
CSS-defined
[::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter) pseudo-element, but also to
[inside](https://drafts.csswg.org/css-lists-3/#valdef-list-style-position-inside)-positioned
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-elements and to [inline-level
boxes](https://drafts.csswg.org/css-display-3/#inline-level-box) that are placed at the start of the first line.
Specifically, [initial-letter] applies to any [inline-level
box]---​including any such
[::first-letter] or
[::marker] box---​that is the first
child of its parent box and whose ancestors (if any) that are
descendants of its [containing
block](https://drafts.csswg.org/css-display-3/#containing-block) are all first-child [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box) that have a
[computed](https://drafts.csswg.org/css-cascade-5/#computed-value) [initial-letter] value of
[normal](#valdef-initial-letter-normal).

For example, the `<span>`, `<em>`, and
`<b>` elements in the following example are \"first-most inline-level
descendants\" of the `<p>`, but the `<strong>` element is not:

 <p><span><em><b>This</b> phrase</em> is styled
 <strong>specially</strong>.</span> …

If we apply the following rules:

 em { initial-letter: 2; }
 b, strong { initial-letter: 3; }

The
[initial-letter](#propdef-initial-letter) property will take effect only on
the `<em>`. The styling on `<b>` is ignored, as it has an ancestor
already styled as an [initial
letter](#initial-letter); and
the styling on `<strong>` is ignored because it is a second sibling.

The result might be rendered as

!(images/firstmost-inline.png){a
height="57" width="428"}

[initial-letter](#propdef-initial-letter) is applied to an [inline-level
box](https://drafts.csswg.org/css-display-3/#inline-level-box) that is not positioned at the start of the line due to
bidi reordering or which is otherwise preceded by other
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) content, its [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) is
[normal](#valdef-initial-letter-normal), and it is not formatted as an [initial
letter](#initial-letter).

The effect of the
[initial-letter](#propdef-initial-letter) property is undefined on children
of [ruby base container
boxes](https://drafts.csswg.org/css-ruby-1/#ruby-base-container-box) and on [ruby container
boxes](https://drafts.csswg.org/css-ruby-1/#ruby-container).

 The
[initial-letter](#propdef-initial-letter) property cannot apply to any
element whose
[float](https://drafts.csswg.org/css2/#propdef-float) is not
[none](https://drafts.csswg.org/css2/#valdef-float-none) or
[position](https://drafts.csswg.org/css-position-3/#propdef-position) is not
[static](https://drafts.csswg.org/css-position-3/#valdef-position-static), because these values cause its
[display](https://drafts.csswg.org/css-display-4/#propdef-display) to compute to
[block](https://drafts.csswg.org/css-display-4/#valdef-display-block).

### 7.4. Alignment of Initial Letters: the [initial-letter-align property]
As mentioned earlier, the alignment of initial letters depends on the
script used. The
[initial-letter-align](#propdef-initial-letter-align) property can be used to specify the
proper alignment.

Name:

[initial-letter-align]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[
border-box[?](https://drafts.csswg.org/css-values-4/#mult-opt) \[ alphabetic
[\|](https://drafts.csswg.org/css-values-4/#comb-one) ideographic [\|] hanging
[\|] leading \][?]
\][!](https://drafts.csswg.org/css-values-4/#mult-req)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

alphabetic

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

certain inline-level boxes and [::first-letter] and inside
[::marker] boxes ([see prose](#first-most-inline-level))

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword(s)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property specifies the alignment points used to size and position
an [initial letter](#initial-letter). Two sets of alignment points are necessary: the
[over](https://drafts.csswg.org/css-writing-modes-4/#over) and
[under](https://drafts.csswg.org/css-writing-modes-4/#under) alignment points of the [initial
letter] are matched to corresponding
[over] and [under] points of the [root
inline box](#root-inline-box).

Values have the following meanings:

[alphabetic]
: Use the
 [cap-height](#cap-height-baseline) and
 [alphabetic](#alphabetic-baseline) baselines of the surrounding text to align the
 [initial letter](#initial-letter).

[ideographic]
: Use the
 [ideographic-ink-over](#ideographic-ink-over-baseline) and
 [ideographic-ink-under](#ideographic-ink-under-baseline) baselines of the surrounding text to align the
 [initial letter](#initial-letter).

[hanging]
: Use the [hanging](#hanging-baseline) and
 [alphabetic](#alphabetic-baseline) baselines of the surrounding text to align the
 [initial letter](#initial-letter).

[leading]

: Use the over/under half-leading edges (i.e.
 [ascent](#ascent-metric)/[descent](#descent-metric) +
 [half-leading](#half-leading)) of the surrounding text to align the [initial
 letter](#initial-letter).

 This will essentially match the edges of the
 [initial letter](#initial-letter) to middle of the line gap above/below the
 first/last impacted lines, which is an effect sometimes used in
 certain types of [Indic
 typesetting](https://www.w3.org/TR/ilreq/#h_scripts_without_hanging_baseline)
 [\[ILREQ\]](#biblio-ilreq "Indic Layout Requirements").

[border-box]
: Use the [initial letter
 box](#initial-letter)'s
 [line-under](https://drafts.csswg.org/css-writing-modes-4/#line-under) and
 [line-over](https://drafts.csswg.org/css-writing-modes-4/#line-over) [border
 edges](https://drafts.csswg.org/css-box-3/#border-edge) as the
 [over](https://drafts.csswg.org/css-writing-modes-4/#over) and
 [under](https://drafts.csswg.org/css-writing-modes-4/#under) alignment points, respectively.

The vertical writing mode example
earlier (in [§ 7.1 An Introduction to Initial
Letters](#initial-letter-intro)) could be coded as:

 span.initial {
 initial-letter: 2;
 initial-letter-align: ideographic;
 }

Except when
[border-box](#valdef-initial-letter-align-border-box) is specified, the alignment points of the
[initial letter](#initial-letter) are automatically determined from its contents:

1. If the [initial letter](#initial-letter) is an atomic inline, use its
 [over](https://drafts.csswg.org/css-writing-modes-4/#over) and
 [under](https://drafts.csswg.org/css-writing-modes-4/#under) content-box edges.
2. Else if the [initial
 letter](#initial-letter)
 contains any character having the Han, Hangul, Kana, or Yi [Unicode
 script](https://drafts.csswg.org/css-text-4/#unicode-script) property, use the
 [ideographic-ink-over](#ideographic-ink-over-baseline) and
 [ideographic-ink-under](#ideographic-ink-under-baseline) baselines.
3. Else if the [initial
 letter](#initial-letter)
 contains any character having the Han, Hangul, Kana, or Yi [Unicode
 script](https://drafts.csswg.org/css-text-4/#unicode-script) property, use the
 [hanging](#hanging-baseline) and
 [alphabetic](#alphabetic-baseline) baselines.
4. Else use the
 [cap-height](#cap-height-baseline) and
 [alphabetic](#alphabetic-baseline) baselines.

Correct alignment of initial letter in
scripts such as Hebrew and Thai is currently not possible because
OpenType lacks corresponding metrics. ([Issue
5244](https://github.com/w3c/csswg-drafts/issues/5244))

!(images/hebrew-initial-letter.png){a
height="165" width="500"}

 The ordering of keywords in this property is fixed in
case
[border-box](#valdef-initial-letter-align-border-box) is expanded to [\[ border-box \| alphabetic \|
ideographic \| hanging \]] to allow explicitly specifying the
[initial letter](#initial-letter)'s alignment points.

#### 7.4.1. UA Default Stylesheet for [initial-letter-align]
In order to provide the better behavior by default, UAs must include in
their default UA style sheet the following rules:

 [lang]:lang(zh, ja, ko, ii) {
 initial-letter-align: ideographic;
 }

 [lang]:lang(hi, mr, ne, pi, kok, brx, mai, sd, sa) {
 initial-letter-align: hanging;
 }
 /* Script tags override language tags */
 [lang]:lang('*-Latn', '*-Cyrl') {
 initial-letter-align: alphabetic;
 }
 [lang]:lang('*-Hani', '*-Hant', '*-Hans') {
 initial-letter-align: ideographic;
 }

This only covers the most common
cross-linguistic transcription systems. Should we include any other /
all script tags in the UA style sheet?

### 7.5. Initial Letter Layout

There are two types of [initial letter
boxes](#initial-letter):
those that arise from non-replaced [inline
boxes](https://drafts.csswg.org/css-display-3/#inline-box) and those that arise from [atomic
inlines](https://drafts.csswg.org/css-display-4/#atomic-inline).

For the non-atomic [inline initial letter], the
box and its contents participate in the same [inline formatting
context](#inline-formatting-context) as the line on which it occurs, and a lot of special
rules apply to give the expected sizing and alignment.

For an [atomic initial letter], however, which is either a [replaced
element](https://drafts.csswg.org/css-display-4/#replaced-element) or which establishes an [independent formatting
context](https://drafts.csswg.org/css-display-4/#independent-formatting-context) for its contents, the sizing of the box (aside from its
[automatic
size](https://drafts.csswg.org/css-sizing-3/#automatic-size) in the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis)) and layout of the contents within the box follows the
usual rules: it is primarily the positioning of the box which is
special.

#### 7.5.1. Properties Applying to Initial Letters

All properties that apply to an [inline
box](https://drafts.csswg.org/css-display-3/#inline-box) also apply to an [inline initial
letter](#inline-initial-letter) except for
[vertical-align](#propdef-vertical-align) and its
[sub-properties](https://drafts.csswg.org/css-cascade-5/#longhand),
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size),
[line-height](#propdef-line-height),
[line-fit-edge](#propdef-line-fit-edge), and
[inline-sizing](#propdef-inline-sizing). Additionally, all of the [sizing
properties](https://drafts.csswg.org/css-sizing-3/#sizing-property) and
[box-sizing](https://drafts.csswg.org/css-sizing-3/#propdef-box-sizing) also apply to [initial
letters](#initial-letter)
(see
[\[css-sizing-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3")).

All properties that apply to an [atomic
inline](https://drafts.csswg.org/css-display-4/#atomic-inline) also apply to the [atomic
inline] when styled as an [initial
letter](#initial-letter),
except for
[vertical-align](#propdef-vertical-align) and its
[sub-properties](https://drafts.csswg.org/css-cascade-5/#longhand).

#### 7.5.2. Margins, Borders, and Padding

Initial letters can be styled with
[margins](https://drafts.csswg.org/css-box-4/#margin),
[padding](https://drafts.csswg.org/css-box-4/#padding), and
[borders](https://drafts.csswg.org/css-box-4/#border) just like any other box. Unless
[initial-letter-align](#propdef-initial-letter-align) is
[border-box](#valdef-initial-letter-align-border-box), its vertical alignment and [font
sizing](#sizing-initial-letter) are not affected. However the effective
exclusion area, which is typically the [initial
letter](#initial-letter)'s
[margin
box](https://drafts.csswg.org/css-box-3/#margin-box) (see
[initial-letter-wrap](#propdef-initial-letter-wrap)) is affected.

When padding and borders are zero, the initial letter may be kerned; see
below.

#### 7.5.3. Font Sizing of Initial Letters

For an [inline initial
letter](#inline-initial-letter), the font size used for sizing the [initial
letter](#initial-letter)
contents is calculated to fulfill its specified
[size](#initial-letter-initial-letter-size) (see
[initial-letter](#propdef-initial-letter)) as anchored by its specified
alignment points (see
[initial-letter-align](#propdef-initial-letter-align)). Note that no layout is required
in this calculation: it is based only on computed values and font
metrics. These
[used](https://drafts.csswg.org/css-cascade-5/#used-value) font size calculations *do not* affect the
[computed](https://drafts.csswg.org/css-cascade-5/#computed-value)
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size), and therefore have no effect on
the computation of
[em](https://drafts.csswg.org/css-values-4/#em) length values, etc.

What about inheritance to descendants?
[\[Issue #4988\]](https://github.com/w3c/csswg-drafts/issues/4988)

The line height used in these calculations is the
[line-height](#propdef-line-height) of the containing block (or, in the case
where a baseline grid is in use, the baseline-to-baseline spacing
required by the baseline grid
[\[CSS-LINE-GRID-1\]](#biblio-css-line-grid-1 "CSS Line Grid Module Level 1")).
The contents of the lines spanned, and therefore any variation in their
heights and positions, is not accounted for.

!(images/infinite-text.png){a
height="225" width="550"}

For an `N`-line drop initial in a Western script, the
cap-height of the letter needs to be (`N` -- 1) times the
line-height, plus the cap-height of the surrounding text. Note this
height is *not* the font size of the drop initial.

Actually calculating this font size is tricky. For an
`N`-line drop initial, we find the drop initial font size to
be:

!(images/InitialCapEquation.png){a
height="46" width="604"}

Update this calculation to be a) generic
across writing systems / alignment points and b) handle non-integer
sizes.

A three-line drop initial in Adobe
Minion Pro would have a font size of 61.2pt given 12pt text, 16pt
line-height, and a cap-height of 651/1000 (from the font's OS/2 table).

For an [atomic initial
letter](#atomic-initial-letter), the used font size is the computed font size as usual.

#### 7.5.4. Shaping and Glyph Selection

When
[initial-letter](#propdef-initial-letter) is not
[normal](#valdef-initial-letter-normal), an [inline initial
letter](#inline-initial-letter) is isolated for glyph shaping; however the text after
it *should* shape across the [inline initial letter
box]'s boundaries, assuming its
presence as part of the first line's text content. (See [CSS Text 3
§ 7.3 Shaping Across Element
Boundaries](https://drafts.csswg.org/css-text-3/#boundary-shaping).) For
example, if the first letter of the word "يحق" were styled with
[initial-letter: 2 1], the first
letter would be styled in its isolated form "ي", as the [initial
letter](#initial-letter),
followed by the medial/final-form "ﺤﻖ", which assumes it is preceded by
the initial letter's contents as normal text.

![Two-line Arabic
"Drop-cap"](images/arabic-drop-cap.png){a
height="82" width="134"}

#### 7.5.5. Sizing the Initial Letter Box

For an [inline initial
letter](#inline-initial-letter), if the [initial
letter](#initial-letter)'s
[preferred
width](https://drafts.csswg.org/css-sizing-3/#width)/[preferred
height](https://drafts.csswg.org/css-sizing-3/#height) is
[definite](https://drafts.csswg.org/css-sizing-3/#definite), use that value (clamped as required by the [min
size](https://drafts.csswg.org/css-sizing-3/#min-width) and [max
size](https://drafts.csswg.org/css-sizing-3/#max-width) properties, and handling
[box-sizing](https://drafts.csswg.org/css-sizing-3/#propdef-box-sizing) as required) for that dimension of
the box.

Otherwise it is considered to have an [automatic
size](https://drafts.csswg.org/css-sizing-3/#automatic-size) in that dimension and its [content
box](https://drafts.csswg.org/css-box-4/#content-box) is sized to fit both:

- The specified
 [sink](#initial-letter-initial-letter-sink) (i.e the space between the over alignment point and
 the under alignment point).
- The glyph outlines of all the glyphs it contains---​excluding any that
 [hang](https://drafts.csswg.org/css-text-3/#hang) (see
 [hanging-punctuation](https://drafts.csswg.org/css-text-4/#propdef-hanging-punctuation))---​as well as the [margin
 boxes](https://drafts.csswg.org/css-box-3/#margin-box) of any [atomic
 inlines](https://drafts.csswg.org/css-display-4/#atomic-inline) it contains.

 :::
 (#initial-letter-exclusions) The glyph(s) of an initial
 letter do not always fit within the specified sink. For example, if an
 initial letter has a descender, it could crash into the (n+1)th line
 of text. This is not desirable.
 ![Incorrect: three-line initial letter ([initial-letter: drop
 3](#propdef-initial-letter)) with descender. In this font, the capital "J"
 extends well below the baseline (shown in
 red).](images/Dropcap-J-3line-crash.png){a
 height="191" width="480"}

 Therefore all [line boxes](#line-box) impacted by the glyph outlines of an [initial
 letter](#initial-letter)
 need to be excluded, not just those within range of the [initial
 letter
 sink](#initial-letter-initial-letter-sink).

 ![Correct: text excluded around glyph bounding
 box](images/Dropcap-J-3line-exclude.png){a
 height="180" width="480"}
 :::

However, if its
[block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start)
[padding](https://drafts.csswg.org/css-box-4/#padding) and
[border](https://drafts.csswg.org/css-box-4/#border) are both zero, then its
[block-start] [content
edge](https://drafts.csswg.org/css-box-3/#content-edge) instead coincides with its
[over](https://drafts.csswg.org/css-writing-modes-4/#over) alignment point exactly, and any content overflowing
above that point is ignored for the purpose of layout.

 If an [inline initial
letter](#inline-initial-letter) has ascenders above its
[over](https://drafts.csswg.org/css-writing-modes-4/#over) alignment point, and the author has not provided
sufficient
[margin](https://drafts.csswg.org/css-box-4/#margin) on either the [initial
letter](#initial-letter)
itself or its [containing
block](https://drafts.csswg.org/css-display-3/#containing-block), then those ascenders might collide with preceding
content.

 It might be nice to automatically provide the necessary
spacing by treating such ascenders as a margin that can collapse with
the margin of the containing block, and thus guarantee the requisite
spacing without imposing any additional space unless it becomes actually
necessary. Depending on implementation complexity, this option may be
explored in the future; but in the meantime, authors need to be careful
to provide the requisite spacing explicitly.

Should the hanging punctuation be
included in the box instead (so that the box is drawn around the
punctuation when it is made visible through borders/background), but
rather only excluded when positioning the box (so that the initial
letter remains flush, with the hanging punctuation properly hanging)?
See [discussion](https://github.com/w3c/csswg-drafts/issues/310).

For [atomic initial
letters](#atomic-initial-letter), sizing follows the usual rules for that type of
[atomic
inline](https://drafts.csswg.org/css-display-4/#atomic-inline). However, if the box has an
[automatic](https://drafts.csswg.org/css-sizing-3/#automatic-size) [block
size](https://drafts.csswg.org/css-sizing-3/#block-size)
([auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto)), then its [block size] is
determined as for an [inline initial
letter](#inline-initial-letter) with
[border-box](#valdef-initial-letter-align-border-box) alignment, and is
[definite](https://drafts.csswg.org/css-sizing-3/#definite).

#### 7.5.6. Alignment Within an Initial Letter Box

By default (i.e. under [automatic
sizing](https://drafts.csswg.org/css-sizing-3/#automatic-size)), the content box of an [inline initial
letter](#inline-initial-letter) is fitted exactly to its content, and alignment
properties like
[text-align](https://drafts.csswg.org/css-text-3/#propdef-text-align) or
[align-content](https://drafts.csswg.org/css-align-3/#propdef-align-content) do not apply. However, if the box
is *not* sized automatically:

- If the [inline
 size](https://drafts.csswg.org/css-sizing-3/#inline-size) is
 [definite](https://drafts.csswg.org/css-sizing-3/#definite),
 [text-align](https://drafts.csswg.org/css-text-3/#propdef-text-align) is honored for aligning the
 contents of the [initial
 letter](#initial-letter)
 within its box in the [inline
 axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) (using its [inline-axis]
 bearings as usual, not the bounding box of its glyph outlines).
- If the [block
 size](https://drafts.csswg.org/css-sizing-3/#block-size) is
 [definite](https://drafts.csswg.org/css-sizing-3/#definite),
 [align-content](https://drafts.csswg.org/css-align-3/#propdef-align-content) is honored for aligning its
 contents in the [block
 axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) (using its [block-axis]
 bearings, synthesizing them if needed).

### 7.6. Initial Letter Positioning and Spacing

#### 7.6.1. Block-axis Positioning

In the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis), the [initial
letter](#initial-letter) is
positioned with respect to the [line box](#line-box) in which it
[originates](#originating-line) as required to satisfy its alignment
([initial-letter-align](#propdef-initial-letter-align)) and specified
[sink](#initial-letter-initial-letter-sink)
([initial-letter](#propdef-initial-letter)):

- If its
 [size](#initial-letter-initial-letter-size) is greater than or equal to its
 [sink](#initial-letter-initial-letter-sink), the [initial
 letter](#initial-letter) is
 positioned to satisfy its
 [under](https://drafts.csswg.org/css-writing-modes-4/#under) alignment, and then shifted by
 ([sink] - 1) ×
 [line-height](#propdef-line-height) of [containing
 block](https://drafts.csswg.org/css-display-3/#containing-block) towards the [containing
 block]'s [block
 end](https://drafts.csswg.org/css-writing-modes-4/#block-end).

- If its
 [size](#initial-letter-initial-letter-size) is less than its
 [sink](#initial-letter-initial-letter-sink), the [initial
 letter](#initial-letter) is
 positioned to satisfy its
 [over](https://drafts.csswg.org/css-writing-modes-4/#over) alignment.

 An [initial
letter](#initial-letter) is
essentially positioned such that it would sink the number of lines
specified by
[initial-letter](#propdef-initial-letter)'s second argument and align to the
requisite
[under](https://drafts.csswg.org/css-writing-modes-4/#under) alignment point (or, if its
[size](#initial-letter-initial-letter-size) is less than its
[sink](#initial-letter-initial-letter-sink), to the requisite
[over](https://drafts.csswg.org/css-writing-modes-4/#over) alignment point instead) if it was assumed that its
containing block held only the [initial
letter] itself followed by an infinite
sequence of plain text as the direct contents of its [root inline
box](#root-inline-box). Its
position is not affected by line height inconsistencies introduced by
the contents of the impacted line boxes.

!(images/infinite-text.png){a
height="225" width="550"}

The [initial letter](#initial-letter) does not increase the [logical
height](https://drafts.csswg.org/css-writing-modes-4/#logical-height) of the [line box](#line-box) in which it participates: it can protrude above or
below it. It must be positioned such that its own
[block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start) [margin
edge](https://drafts.csswg.org/css-box-3/#margin-edge) is below its [containing
block](https://drafts.csswg.org/css-display-3/#containing-block)'s [block-start] [content
edge](https://drafts.csswg.org/css-box-3/#content-edge), and thus can force its [originating line
box](#originating-line) (and
subsequent content) to shift further away from that edge.

#### 7.6.2. Inline Kerning

If the [initial letter](#initial-letter) is a non-atomic inline with an
[automatic](https://drafts.csswg.org/css-sizing-3/#automatic-size) [inline
size](https://drafts.csswg.org/css-sizing-3/#inline-size) and zero padding and borders, its [margin
box](https://drafts.csswg.org/css-box-3/#margin-box) is kerned (negatively inset) by the distance from the
start edge of its content box to the point in the content that would
have been placed at the start edge of the [line
box](#line-box) if it were not an
[initial letter] (i.e. the distance between
its glyph bounding box and its start side bearing). This inset is
effectively an additional
[inline-start](https://drafts.csswg.org/css-writing-modes-4/#inline-start)
[margin](https://drafts.csswg.org/css-box-4/#margin) on the box.

### 7.7. Initial Letter Wrapping: the [initial-letter-wrap property]
[initial-letter-wrap](#propdef-initial-letter-wrap) is at risk.

Name:

[initial-letter-wrap]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) first [\|] all
[\|] grid [\|]
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

certain inline-level boxes and [::first-letter] and inside
[::marker] boxes ([see prose](#first-most-inline-level))

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to [logical
width](https://drafts.csswg.org/css-writing-modes-4/#logical-width) of (last fragment of) initial letter

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword or computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

This property specifies whether lines impacted by an [initial
letter](#initial-letter) are
shortened to fit the rectangular shape of the [initial
letter] box or the contour of its glyph
outline.

[none]
: No contour-fitting is performed: each impacted line is aligned flush
 to the
 [inline-end](https://drafts.csswg.org/css-writing-modes-4/#inline-end) [margin
 edge](https://drafts.csswg.org/css-box-3/#margin-edge) of the [initial
 letter](#initial-letter).

[first]

: Behaves as
 [none](#valdef-initial-letter-wrap-none) if the first [typographic character
 unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit) after the [initial
 letter](#initial-letter)
 belongs to Unicode General Category Zs. Otherwise behaves as for
 [all](#valdef-initial-letter-wrap-all) on the first line of the block containing
 the initial letter and as
 [none] on the rest.

 :::
 (#example-8c68c539) This example shows why
 contour-fitting the first line is necessary, and why it is dropped
 when the [initial letter](#initial-letter) is followed by a space:
 ![In the top paragraph, the initial letter \"A\" has a word space
 after it: the gap between the top of the \"A\" and the next letter
 provides the necessary word separation. In the next paragraph, the
 initial letter \"A\" is part of the first word, and leaving a gap
 between the top of the \"A\" and the next letter would create a
 jarring visual break within the word. In this case, the first line
 of text should be kerned into the initial letter's area, as shown in
 the bottom
 paragraph.](images/OpticalKerning.png){a
 height="280" width="210"}
 :::

 (#issue-58dffa4b) Do we need an unconditional
 [first](#valdef-initial-letter-wrap-first)? (I.e. Should we rename this value to
 [auto] and add a
 [first] value that
 does not check for spaces?) See GitHub issue
 [410](https://github.com/w3c/csswg-drafts/issues/410)

[all]

: For each line of text impacted by the [initial
 letter](#initial-letter),
 the [line box](#line-box)
 adjacent to the [initial letter] starts
 at the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start)-most point that does not overlap the [initial
 letter]'s glyph outline.

 If the value of [shape-outside] is not
 [none](https://drafts.csswg.org/css-shapes-1/#valdef-shape-outside-none), [shape-outside] is used instead of
 the glyph outline.

 In both cases,
 [shape-margin](https://drafts.csswg.org/css-shapes-1/#propdef-shape-margin) is applied to expand the
 outline, and the resulting outline is clipped by the [initial
 letter](#initial-letter)'s [margin
 edges](https://drafts.csswg.org/css-box-3/#margin-edge).

 This value is at-risk.

[grid]

: This value is the same as
 [none](#valdef-initial-letter-wrap-none), except that the exclusion area of the
 impacted lines is increased as necessary for its end-edge to land on
 the character grid, i.e. to be a multiple of ([1ic] +
 [letter-spacing](https://drafts.csswg.org/css-text-4/#propdef-letter-spacing)) as computed on the containing
 block. The
 [justify-self](https://drafts.csswg.org/css-align-3/#propdef-justify-self) property can then be used to
 align the initial letter box within the exclusion area.

 ![Diagram of Japanese initial letter in vertical writing
 mode](images/CJK-Initial.001.png){height="400" width="486"}

 In this example, the exclusion area for the drop
 initial is larger than its glyph in order to preserve inline-axis
 alignment.

 This value is also at-risk.

[[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)]\
[[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)]

: This value behaves the same as
 [first](#valdef-initial-letter-wrap-first) except that the adjustment to the first line
 is given explicitly instead of being inferred from the glyph shape.

 (#issue-645378a9) This really needs font-relative
 lengths to be relative to the used size.

 This value exists because it is easier to
 implement. Authors are encouraged to use the
 [first](#valdef-initial-letter-wrap-first) value and to set margins to control spacing,
 and to use this as a fallback for glyph detection if necessary.

 :::
 (#example-09c7aa2b) In the following example, UAs that
 support
 [first](#valdef-initial-letter-wrap-first) will use the glyph outline plus the
 specified margin in order to place the first line, whereas UAs that
 only support
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) or
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) values will pull in the first
 line by 40% of the initial letter's width (and then add the margin
 to that point).
 h1 + p:first-letter {
 initial-letter: 3; /* 3-line drop-cap */
 initial-letter-wrap: first;
 margin-right: 0.1em;
 }
 @supports (not (initial-letter-wrap: first)) {
 /* Classes auto-generated on paragraphs to match first letter. */
 p.A:first-letter {
 initial-letter-wrap: -40%; /* Start of glyph outline, assuming correct font. */
 }
 }
 :::

 (#issue-e060e05e) These values and related annoyance
 is likely unnecessary if someone submits a patch to Blink to support
 [first](#valdef-initial-letter-wrap-first).

Edit figure to show how auto behaves in
varying contexts

p::first-letter {
 initial-letter: 3;
 initial-letter-wrap: none;
 }

![Ordinary initial letter with no
wrapping.](images/A-wraparound-none.png){a
height="250" width="600"}

p::first-letter {
 initial-letter: 3;
 initial-letter-wrap: all;
 }

![Text follows shape of initial letter. Each line box should just touch
the ink of the letter, with some offset (represented by the shaded
box).](images/A-wraparound.png){a
height="254" width="600"}

p::first-letter {
 initial-letter: 3;
 initial-letter-wrap: first;
 }

![Only the first line is moved up against the ink of the initial
letter.](images/A-wraparound-first.png){a
height="259" width="600"}

p::first-letter {
 initial-letter: 3;
 initial-letter-wrap: all;
 }

![text wrapping around dropcap V](images/V-wraparound.png){height="237"
width="600"}

![text wrapping around dropcap P](images/P-wraparound.png){height="271"
width="600"}

![text wrapping around dropcap W](images/W-wraparound.png){height="234"
width="600"}

### 7.8. Line Layout

An [initial letter box](#initial-letter) is considered
[in-flow](https://drafts.csswg.org/css-display-3/#in-flow) in its [block formatting
context](https://drafts.csswg.org/css-display-4/#block-formatting-context), and is part of the contents of the [line
box](#line-box) in which it
originates (its [originating line box]). Aside from
the vertical axis (see [§ 7.6.1 Block-axis
Positioning](#initial-letter-block-position)), its interaction with the
rest of the contents of the line is as normal for [inline-level
content](https://drafts.csswg.org/css-display-4/#inline-level), except in a few specific details...

#### 7.8.1. Inline Flow Layout: Alignment, Justification, and White Space

An [initial letter box](#initial-letter) is handled similar to any other
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) content participating in its [originating line
box](#originating-line),
including participation in alignment, justification, and white space
processing.

However, to ensure consistent alignment of all the impacted lines,
[collapsible white
space](https://drafts.csswg.org/css-text-4/#collapsible-white-space) between a [sunken
initial](#sunken-initial) and
subsequent content on its [originating
line](#originating-line) is
collapsed away, and any
[letter-spacing](https://drafts.csswg.org/css-text-4/#propdef-letter-spacing) or [justification
opportunity](https://drafts.csswg.org/css-text-4/#justification-opportunity) that would normally be introduced by the juxtaposition
of the contents of a [sunken initial] and the
subsequent contents of the line is suppressed. (Note that this does not
affect
[word-spacing](https://drafts.csswg.org/css-text-4/#propdef-word-spacing) or the [justification
opportunity] introduced by a [word
separator](https://drafts.csswg.org/css-text-4/#word-separator) because that space is provided by the [typographic
character
unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit) alone and not by its juxtaposition with an adjacent
character.)

#### 7.8.2. Edge Effects: Indentation and Hanging Punctuation

[text-indent](https://drafts.csswg.org/css-text-4/#propdef-text-indent) and
[hanging-punctuation](https://drafts.csswg.org/css-text-4/#propdef-hanging-punctuation) apply to an [initial
letter](#initial-letter)'s
[originating line box](#originating-line) as usual, and cause a shift in the start of the line's
contents including the [initial letter]
itself. Subsequent lines affected by the exclusion are shortened as
usual, possibly more or less than otherwise depending on the resulting
position of the [initial letter].

![Initial letter with text
indent.](images/InitialLetterWithTextIndent.png){a
height="136" width="550"}

The interaction of
[initial-letter](#propdef-initial-letter) and
[hanging-punctuation](https://drafts.csswg.org/css-text-4/#propdef-hanging-punctuation) is [under
discussion](https://github.com/w3c/csswg-drafts/issues/310#issuecomment-396765893).

#### 7.8.3. Ancestor Inlines

If the [initial letter box](#initial-letter) is contained by [inline
box](https://drafts.csswg.org/css-display-3/#inline-box) ancestors, the boundaries of those [inline
boxes] are drawn to exclude the [initial letter
box], as if it were outside their startmost
[margin
edge](https://drafts.csswg.org/css-box-3/#margin-edge). This is a purely geometric operation: it does not
affect e.g. property inheritance or the effective
[letter-spacing](https://drafts.csswg.org/css-text-4/#propdef-letter-spacing) between the [initial letter
box] and subsequent content.

#### 7.8.4. Multi-line Initial Letters

If an initial letter is too long to fit on one line, it wraps (according
to the usual text-wrapping rules), each line filled and formatted
exactly as if it were the first line and the initial letter too long to
fit any subsequent normal text. Any normal text after the initial letter
starts on its last line, affected exactly as if that line were the first
line.

![Drop cap extends to two
lines.](images/Multi-line-initial.png){a
height="208" width="300"}

### 7.9. Clearing Initial Letters

#### 7.9.1. Raised and sunken caps

The margin box of an initial letter contributes to the size of its
containing element. Initial letters that extend above the first line of
text, known as "raised caps" or "sunken caps," do not extend up into
previous elements. Since the content box for an initial letter includes
all glyph ink, this also means that accents or other ink above the cap
height of an initial letter will not impinge on previous elements.

![Raised cap (`initial-letter: 3 1`) on right; note that the position of
the "C" is the same in both cases, but on the right all text is moved
down relative to the initial
letter.](images/initial-letter-drop-para-compare.png){a
height="111" width="600"}

Handle glyph ink above cap height of
font. Proposal: Make it an exclusion area for line boxes and border
boxes. Include margin specified on initial-letters as part of exclusion
area in order to control spacing.

Draw a box model diagram here. Does the
margin of the initial letter collapse with its container?

#### 7.9.2. Short paragraphs with initial letters

A paragraph with an initial letter can have fewer lines of text than the
initial letter occupies. In this case, the initial letter's top
alignment is still honored, and its exclusion area continues into any
subsequent blocks. This forces the subsequent inline-level content to
wrap around the initial letter---​exactly as if that block's text were
part of its own containing block. (This is similar to how floats exclude
content in subsequent block boxes.)

![The red text is a short paragraph with an initial letter. Note the
subsequent paragraph wraps around the initial letter just as text in the
paragraph with the initial letter
does.](images/initial-letter-short-para.png){a
height="120" width="600"}

If the subsequent block starts with an initial letter, establishes an
[independent formatting
context](https://drafts.csswg.org/css-display-4/#independent-formatting-context), or specifies
[clear](https://drafts.csswg.org/css2/#propdef-clear) in the initial letter's containing
block's start direction, then it must clear the previous block's initial
letter.

![The red text is a short paragraph with an initial letter. The
subsequent paragraph clears because it also has an initial
letter.](images/initial-letter-short-para-initial.png){a
height="163" width="600"}

#### 7.9.3. Interaction with floats

[Initial letters](#initial-letter) are not
[floats](https://www.w3.org/TR/CSS21/visuren.html#floats): they are
[in-flow](https://drafts.csswg.org/css-display-3/#in-flow)
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) content that belongs to a [line
box](#line-box). Therefore:

- The
 [clear](https://drafts.csswg.org/css2/#propdef-clear) property does not care about
 [initial letters](#initial-letter): it neither applies to [initial
 letters] nor clears them when applied to
 nearby floats.

- Like line boxes or floats, [initial letter
 boxes](#initial-letter)
 must not overlap the [margin
 boxes](https://drafts.csswg.org/css-box-3/#margin-box) of any floats participating in the same [block
 formatting
 context](https://drafts.csswg.org/css-display-4/#block-formatting-context). An overlapping [initial letter
 box] is shifted inward or downward until
 either it fits without overlapping or there are no more floats
 present.

- If a line box's start edge shifts or moves down to clear a float, an
 [initial letter](#initial-letter)
 [originating](#originating-line) in it moves with it; likewise if an [initial
 letter] shifts inward or moves downward to
 clear a float, its [originating line box]
 and subsequent line boxes shorten and/or move accordingly.

- If an
 [inline-start](https://drafts.csswg.org/css-writing-modes-4/#inline-start) float originates in the first line of content
 adjacent to an [initial
 letter](#initial-letter),
 then it moves past the [initial letter]
 towards the containing block edge, exactly as if the [initial
 letter] were any other inline-level
 content.

 However, if such a float originates in subsequent lines of content
 adjacent to a (sunk) [initial
 letter](#initial-letter),
 then that float must clear the [initial
 letter].

![In the absence of an initial letter, the first line of text could abut
the blue float. But the presence of the initial letter requires that the
text move
over.](images/float-interaction.png){a
height="170" width="600"}

See [CSS2§9.5](https://www.w3.org/TR/CSS21/visuren.html#floats) for more
information about the layout of floats and adjacent content.
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")

Whether an inline-end float originating
in subsequent lines must clear the initial letter (as inline-start
floats do) is [still under
discussion](https://lists.w3.org/Archives/Public/www-style/2018Jul/0019.html).
There is no aesthetic reason to require it; however it's yet unclear how
the underlying layout model would distinguish between the two cases.

#### 7.9.4. Interaction with Fragmentation (Pagination)

Since a single glyph cannot be
[fragmented](https://drafts.csswg.org/css-break-3/#fragment) across pages (or columns or other [fragmentation
containers](https://drafts.csswg.org/css-break-4/#fragmentation-container)), an [initial
letter](#initial-letter) is
considered
[monolithic](https://drafts.csswg.org/css-break-3/#monolithic)
[\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3")
for the purpose of block-axis
[fragmentation](https://drafts.csswg.org/css-break-4/#fragmentation) (breaking across pages, columns, regions, etc.).
Additionally, breaks between the
[in-flow](https://drafts.csswg.org/css-display-3/#in-flow) lines alongside an [initial letter
box] are avoided, much as breaks between line
boxes affected be
[widows](https://drafts.csswg.org/css-break-4/#propdef-widows) and
[orphans](https://drafts.csswg.org/css-break-3/#propdef-orphans) are avoided. However, if there is a
[forced
break](https://drafts.csswg.org/css-break-4/#forced-break) alongside the [initial letter
box], then it takes precedence; but has no
effect on the [initial letter box] itself.

As with other
[monolithic](https://drafts.csswg.org/css-break-3/#monolithic) objects, if an [initial letter
box](#initial-letter) occurs
at the top of a [fragmentation
container](https://drafts.csswg.org/css-break-4/#fragmentation-container) and that [fragmentation
container] is too short to contain
it, it may be either truncated or sliced. Adjacent content, however,
must be
[fragmented](https://drafts.csswg.org/css-break-3/#fragment) according to its own rules, not truncated or sliced
along with the [initial letter].

## [ Appendix A: Synthesizing Alignment Metrics]
### [ A.1: Calculating [Em-over](#em-over-baseline) and [Em-under](#em-under-baseline)]
 The
[em-over](#em-over-baseline)
and [em-under](#em-under-baseline) baselines are not used by CSS. Their definitions are
included in this module for consistency with the other metrics used by
[Canvas TextMetrics
API](https://html.spec.whatwg.org/multipage/canvas.html#textmetrics).

The [em-over](#em-over-baseline) and
[em-under](#em-under-baseline) metrics are calculated as follows:

- If any one of [central](#central-baseline),
 [ideographic-over](#ideographic-over-baseline), or
 [ideographic-under](#ideographic-under-baseline) is defined by the font, then
 [em-over](#em-over-baseline) is 0.5em over the
 [central] baseline, and
 [em-under](#em-under-baseline) is 0.5em under it, with the
 [central] baseline derived from the others
 if missing or undefined (see below).

- Otherwise, the [ascent](#ascent-metric) and
 [descent](#descent-metric)
 are both proportionally augmented or reduced to add up to exactly 1em,
 and these normalized metrics are taken as the
 [em-over](#em-over-baseline) and
 [em-under](#em-under-baseline) metrics, respectively.

 This calculation ensures that
[em-over](#em-over-baseline)
and [em-under](#em-under-baseline) are always exactly 1em apart while trying to center the
glyph outlines' "center of gravity" between them.

### [ A.2: Synthesizing Baselines (and Other Font Metrics) for Text]
Some fonts might not contain the metrics information necessary to align
text properly as described in this module. User agents may use the
following strategies in the absence of a required metric:

Use related metrics
: Certain metrics are typically related, and this relationship can be
 used to at least heuristically derive the missing metric. If the
 font format itself does not define any specific calculations, the
 following rules may be used:
 1. The [central
 baseline](#central-baseline) is defined to be halfway between the
 [ideographic-over](#ideographic-over-baseline) and
 [ideographic-under](#ideographic-under-baseline) baselines, so any two of these determines the
 third.
 2. The
 [ideographic-over](#ideographic-over-baseline) and
 [ideographic-under](#ideographic-under-baseline) baselines are typically [1em] apart, so
 if only one of the
 [ideographic-over]/[ideographic-under]/[central](#central-baseline) baselines are provided, this relation can be
 used to calculate the other two.
 3. In CJK fonts the
 [ascent](#ascent-metric) and
 [descent](#descent-metric) typically match the
 [ideographic-over](#ideographic-over-baseline) and
 [ideographic-under](#ideographic-under-baseline) baselines, so can be used as a fallback when
 both are missing.

Measure the font

: Metrics may be derived from the glyph shapes. For example,

 1. The center of the minus sign (U+2212) can be taken as the
 mathematical baseline.

 2. The amount by which the lowercase "o" descends below the
 alphabetic baseline can be subtracted from its highest point to
 [measure the x-height](https://drafts.csswg.org/css-values/#ex).
 ![Measuring the x
 height.](images/measuring-x-height-o.png){a
 height="326" width="420"}

 3. The amount by which the uppercase "O" descends below the
 alphabetic baseline can be subtracted from its highest point to
 measure the cap-height.

 4. The bounding box of 永 (U+6C38) can be used to find the
 ideographic character face edges.

 5. The top edge of the center of the Hebrew He (U+05D4 "ה") can be
 taken as the Hebrew hanging baseline.

 6. The top edge of the center of the letter Ka can be taken as the
 hanging baseline. Which Ka is used should depend on the [content
 language](https://drafts.csswg.org/css-text-4/#content-language):

 Language

 Script

 Letter

 Devanagari

 क U+0915 KA

 Bengali

 ক U+0995

 Gurmukhi

 ਕ U+0A15

 Tibetan

 ཀ U+0F40

 (#issue-2765c39b) Pick a default.

 ![The hanging baseline is at the top edge of the character
 ink.](images/measuring-hanging-baseline-ka.png){a
 height="141" width="280"}

 7. (#issue-73104825) Add more notes here?

 (#issue-6c88f039) Somebody sanity-check these
 heuristics please.

Use fallback values
: The following fallback values are suggested:
 - x-height: .5em;
 - cap-height: .66em;
 - hanging baseline: .6em;

### [ A.3: Synthesizing Baselines for Atomic Inlines]
If an [atomic
inline](https://drafts.csswg.org/css-display-4/#atomic-inline) (such as an inline-block, inline-table, or [replaced
element](https://drafts.csswg.org/css-display-4/#replaced-element)) does not have a content-derived [baseline
set](#baseline-set) in the
[inline
axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) of the [inline formatting
context](#inline-formatting-context) in which it participates, then the UA must synthesize
its [baselines](#baseline) as
follows in order to align it.

These [baselines](#baseline) are
assumed to be **at its
[line-under](https://drafts.csswg.org/css-writing-modes-4/#line-under) [margin
edge](https://drafts.csswg.org/css-box-3/#margin-edge)**:

- [text-under
 baseline](#text-under-baseline)
- [ideographic-under
 baseline](#ideographic-under-baseline)
- [ideographic-ink-under
 baseline](#ideographic-ink-under-baseline)
- [alphabetic
 baseline](#alphabetic-baseline)

These [baselines](#baseline) are
assumed to be **halfway between its
[line-under](https://drafts.csswg.org/css-writing-modes-4/#line-under) and
[line-over](https://drafts.csswg.org/css-writing-modes-4/#line-over) [margin
edges](https://drafts.csswg.org/css-box-3/#margin-edge)**:

- [central baseline](#central-baseline)
- [math baseline](#math-baseline)
- [x-middle baseline](#x-middle-baseline)

These [baselines](#baseline) are
assumed to be **at its
[line-over](https://drafts.csswg.org/css-writing-modes-4/#line-over) [margin
edge](https://drafts.csswg.org/css-box-3/#margin-edge)**:

- [text-over baseline](#text-over-baseline)
- [ideographic-over
 baseline](#ideographic-over-baseline)
- [ideographic-ink-over
 baseline](#ideographic-ink-over-baseline)
- [cap-height
 baseline](#cap-height-baseline)
- [hanging baseline](#hanging-baseline)
- [x-height baseline](#x-height-baseline)

 Authors can use margins (positive or negative) to
adjust the alignment of replaced content within a line.

In this example, the author is using a
set of images to display characters that don't exist.

 img[src^="/text/"] {
 height: 1em; /* Size to match adjacent text */
 margin-bottom: -0.2em; /* Baseline at 20% above bottom */
 }
 ...
 <p>This is some text with words written in an unencoded script:
 <img src="/text/ch3439.png" a>
 <img src="/text/ch3440.png" a>
 <img src="/text/ch3442.png" a>

 A future level of CSS may include a way of specifying a
full [baseline table](#baseline-table) for replaced elements. (This will probably look like a
[baseline-table] property that accepts [\[\<baseline-keyword\>
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)\]+].)

## [ Changes]
Changes since the [18 December 2024 Working
Draft](https://www.w3.org/TR/2024/WD-css-inline-3-20241218/):

- Clarify that
 [baseline-source](#propdef-baseline-source) does not apply to [inline
 boxes](https://drafts.csswg.org/css-display-3/#inline-box). ([Issue
 13277](https://github.com/w3c/csswg-drafts/issues/13277))

Changes since the [12 August 2024 Working
Draft](https://www.w3.org/TR/2024/WD-css-inline-3-20240812/):

- Made both values of
 [\<text-edge\>](#typedef-text-edge) required. ([Issue
 10703](https://github.com/w3c/csswg-drafts/issues/10703))
- Made
 [text-box-edge](#propdef-text-box-edge) inherit;
 [text-box-trim](#propdef-text-box-trim) references the relevant value
 applied to the affected line box(es). ([Issue
 10904](https://github.com/w3c/csswg-drafts/issues/10904))
- Defined behavior of
 [text-box-trim](#propdef-text-box-trim) at
 [fragmentation](https://drafts.csswg.org/css-break-4/#fragmentation) breaks. ([Issue
 5335](https://github.com/w3c/csswg-drafts/issues/5335))
- Defined behavior of
 [text-box-trim](#propdef-text-box-trim) on [multi-column
 containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container), and clarified its application to (and through) other
 formatting contexts. ([Issue
 5335](https://github.com/w3c/csswg-drafts/issues/5335), [Issue
 11038](https://github.com/w3c/csswg-drafts/issues/11038))
- Renamed "invisible line boxes" to [phantom line
 boxes](#phantom-line-box)
 for [consistency with
 CSS2](https://www.w3.org/TR/CSS2/visuren.html#phantom-line-box) and to
 help clarify that they are "invisible" to layout, not just painting.
- Extracted keywords of
 [dominant-baseline](#propdef-dominant-baseline) and
 [alignment-baseline](#propdef-alignment-baseline) (except
 [auto](#valdef-dominant-baseline-auto) and
 [baseline](#valdef-alignment-baseline-baseline)) into
 [\<baseline-metric\>](#typedef-baseline-metric), thereby adding
 [hanging](#valdef-dominant-baseline-hanging) to
 [alignment-baseline].
 ([Issue 13327](https://github.com/w3c/csswg-drafts/issues/13327))

Changes since the [8 August 2024 Working
Draft](https://www.w3.org/TR/2024/WD-css-inline-3-20240808/):

- Some minor clean-up of references to
 [text-box-edge](#propdef-text-box-edge) left over from when it also
 represented
 [line-fit-edge](#propdef-line-fit-edge).
- Adjusted [text-box-edge:
 auto](#propdef-text-box-edge) to reference
 [line-fit-edge](#propdef-line-fit-edge) on the affected [line
 box](#line-box) rather than
 computing to the [line-fit-edge] of the specifying element.

Changes since the [1 April 2023 Working
Draft](https://www.w3.org/TR/2023/WD-css-inline-3-20230401/):

- Split
 [text-box-edge](#propdef-text-box-edge) into two
 properties---​[text-box-edge] for controlling the
 [text-box-trim](#propdef-text-box-trim) edge and
 [line-fit-edge](#propdef-line-fit-edge) for controlling line box
 sizing---​and added the
 [text-box](#propdef-text-box)
 [shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property). (Issues
 [8829](https://github.com/w3c/csswg-drafts/issues/8829) and
 [8696](https://github.com/w3c/csswg-drafts/issues/8696))
- Added [trim-\*] prefix to
 [text-box-trim](#propdef-text-box-trim) keywords so that they make sense
 in the context of the
 [text-box](#propdef-text-box) shorthand. ([Issue
 10675](https://github.com/w3c/csswg-drafts/issues/10675))
- Use the innermost trim edge for
 [text-box-trim](#propdef-text-box-trim) when multiple ancestors request
 trimming. ([Issue
 5426](https://github.com/w3c/csswg-drafts/issues/5426))
- Apply negative
 [block-axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) margins to descendants of [inline
 boxes](https://drafts.csswg.org/css-display-3/#inline-box) when calculating their [layout
 bounds](#layout-bounds) so
 that they can actually have the specified effect. ([Issue
 8182](https://github.com/w3c/csswg-drafts/issues/8182))
- Corrected [phantom line
 boxes](#phantom-line-box)
 to only account for
 [inline-axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) box decorations. ([Issue
 9344](https://github.com/w3c/csswg-drafts/issues/9344))

Changes since the [14 November 2022 Working
Draft](https://www.w3.org/TR/2022/WD-css-inline-3-20221114/):

- Renamed [text-edge] to
 [text-box-edge](#propdef-text-box-edge) and [leading-trim] to
 [text-box-trim](#propdef-text-box-trim), and also renamed their initial
 values. ([Issue
 8067](https://github.com/w3c/csswg-drafts/issues/8067))
- Floor the [line gap
 metric](#line-gap-metric)
 at zero. ([Issue
 5064](https://github.com/w3c/csswg-drafts/issues/5064))

Changes since the [28 August 2020 Working
Draft](https://www.w3.org/TR/2020/WD-css-inline-3-20200827/):

- Fixed
 [inline-sizing](#propdef-inline-sizing) to be
 [inherited](https://drafts.csswg.org/css-cascade-5/#css-inheritance), as was originally intended. ([Issue
 1974](https://github.com/w3c/csswg-drafts/issues/1974))
- Update
 [inline-sizing](#propdef-inline-sizing) "Applies to" to exclude ruby
 boxes.
- Editorial fixes, including missing images.

Changes since the [18 June 2020 Working
Draft](https://www.w3.org/TR/2020/WD-css-inline-3-20200618/) include:

- Added
 [leading](#valdef-initial-letter-align-leading) value to
 [initial-letter-align](#propdef-initial-letter-align) to handle common practices for
 certain Indic scripts. See [Indic Layout
 Requirements](https://www.w3.org/TR/ilreq/#h_scripts_without_hanging_baseline).
 ([Issue 864](https://github.com/w3c/csswg-drafts/issues/864))
- Make non-zero padding and border block effects of [leading-trim]
 from ancestors. ([Issue
 5237](https://github.com/w3c/csswg-drafts/issues/5237))
- Remove
 [hebrew](https://drafts.csswg.org/css-counter-styles-3/#hebrew) value from
 [initial-letter-align](#propdef-initial-letter-align). ([Issue
 5208](https://github.com/w3c/csswg-drafts/issues/5208))
- Use the over alignment point for initial letters whose size is less
 than the sink. ([Issue
 5329](https://github.com/w3c/csswg-drafts/issues/5329))
- Collapse white space adjacent to [dropped
 initials](#dropped-initial). ([Issue
 5120](https://github.com/w3c/csswg-drafts/issues/5120))
- Make [dropped initials](#dropped-initial) behave the same as [raised
 initials](#raised-initial)
 for the purpose of
 [text-align](https://drafts.csswg.org/css-text-3/#propdef-text-align). ([Issue
 5207](https://github.com/w3c/csswg-drafts/issues/5207))
- Altered interaction of
 [shape-margin](https://drafts.csswg.org/css-shapes-1/#propdef-shape-margin),
 [margin](https://drafts.csswg.org/css-box-4/#propdef-margin), and
 [shape-outside](https://drafts.csswg.org/css-shapes-1/#propdef-shape-outside) to match floats (see
 [initial-letter-wrap](#propdef-initial-letter-wrap)). ([Issue
 5119](https://github.com/w3c/csswg-drafts/issues/5119))
- Added definitions for
 [em-over](#em-over-baseline) and
 [em-under](#em-under-baseline) baselines for reference by Canvas 2D. ([Issue
 5312](https://github.com/w3c/csswg-drafts/issues/5312))
- Slight refinements to the (new) syntax of
 [vertical-align](#propdef-vertical-align). ([Issue
 5235](https://github.com/w3c/csswg-drafts/issues/5235))
- Define fallback shift for [baseline-shift: sub \|
 super](#propdef-baseline-shift). ([Issue
 5225](https://github.com/w3c/csswg-drafts/issues/5225))

Changes since the [4 June 2020 Working
Draft](https://www.w3.org/TR/2020/WD-css-inline-3-20200604/) include:

- Reworked the relationship of the earlier [line-sizing] and
 [text-box-trim] proposals to create [text-edge] and a
 differently-structured [leading-trim]. ([Issue
 5168](https://github.com/w3c/csswg-drafts/issues/5168))
- Shifted the [line-relative shift
 values](#line-relative-shift-values) of
 [vertical-align](#propdef-vertical-align) from the
 [alignment-baseline](#propdef-alignment-baseline) longhand to the
 [baseline-shift](#propdef-baseline-shift) longhand. ([Issue
 5180](https://github.com/w3c/csswg-drafts/issues/5180))
- Integrated [text-edge] into [line box height
 calculations](#inline-height).
- Refactored definitions of various baselines into [their own
 section](#css-metrics) and imported introduction and core terminology
 from
 [\[CSS-WRITING-MODES-3\]](#biblio-css-writing-modes-3 "CSS Writing Modes Level 3").
- Imported and updated / integrated remaining baseline alignment and
 line box sizing prose from
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").
- Defined atomic inline baseline synthesis rules for all baselines.
- Defined the [central
 baseline](#central-baseline) definitively as the *ideographic* central baseline.
- Defined white space collapsing between an [initial letter
 box](#initial-letter) and
 subsequent text. ([Issue
 5120](https://github.com/w3c/csswg-drafts/issues/5120))
- Tightened up box model definitions for [initial letter
 boxes](#initial-letter),
 including interaction with its [containing
 block](https://drafts.csswg.org/css-display-3/#containing-block). ([Issue
 719](https://github.com/w3c/csswg-drafts/issues/719))
- Miscellaneous small fixes, clarifications, and editorial improvements.

Changes since the [8 August 2018 Working
Draft](https://www.w3.org/TR/2018/WD-css-inline-3-20180808/) include:

- Added [line-sizing] property to control how inter-line spacing
 is calculated. ([Issue
 3199](https://github.com/w3c/csswg-drafts/issues/3199))
- Added
 [baseline-source](#propdef-baseline-source) property to control whether first
 or last baseline is used for alignment. ([Issue
 861](https://github.com/w3c/csswg-drafts/issues/861))
- Added [leading-trim] proposal to control the metrics used for
 the line-over/line-under edge in line box layout. ([Issue
 3240](https://github.com/w3c/csswg-drafts/issues/3240) and
 [3955](https://github.com/w3c/csswg-drafts/issues/3955))
- Imported
 [line-height](#propdef-line-height) definition and related normative
 prose from
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").
- Improved high-level description of inline layout in [§ 2 Inline Layout
 Model](#model).
- Renamed [initial-letters] back to
 [initial-letter](#propdef-initial-letter). ([Issue
 862](https://github.com/w3c/csswg-drafts/issues/862))
- Added the
 [raise](#valdef-initial-letter-raise) and [sink] keywords for syntactic
 convenience. ([Issue
 2955](https://github.com/w3c/csswg-drafts/issues/2955))
- Specified synthesis of baselines for [atomic
 inlines](https://drafts.csswg.org/css-display-4/#atomic-inline) that have no baseline set.
- Clarified interpretation of
 [middle](https://drafts.csswg.org/css2/#valdef-vertical-align-middle),
 [text-top](https://drafts.csswg.org/css2/#valdef-vertical-align-text-top), and
 [text-bottom](https://drafts.csswg.org/css2/#valdef-vertical-align-text-bottom) in [vertical writing
 modes](https://drafts.csswg.org/css-writing-modes-4/#vertical-writing-mode). ([Issue
 4495](https://github.com/w3c/csswg-drafts/issues/4495))
- Clarified that
 [text-top](https://drafts.csswg.org/css2/#valdef-vertical-align-text-top)/[text-bottom](https://drafts.csswg.org/css2/#valdef-vertical-align-text-bottom)/[text] values should be consistently
 interpreted across
 [vertical-align](#propdef-vertical-align),
 [dominant-baseline](#propdef-dominant-baseline), [leading-trim], and
 drawing the content box of an inline box. ([Issue
 3978](https://github.com/w3c/csswg-drafts/issues/3978))
- Corrected initial value of
 [dominant-baseline](#propdef-dominant-baseline) to
 [auto](#valdef-dominant-baseline-auto). ([Issue
 4115](https://github.com/w3c/csswg-drafts/issues/4115))
- Improved some nuances in authoring advice regarding
 [vertical-align](#propdef-vertical-align) longhands vs. shorthands.
- Clarified interaction of
 [initial-letter](#propdef-initial-letter) and
 [float](https://drafts.csswg.org/css2/#propdef-float)/[position](https://drafts.csswg.org/css-position-3/#propdef-position).
- Reorganized the [§ 7.5 Initial Letter Layout](#initial-letter-layout)
 section for better readability, and tweaked some wording for clarity.
- Defined that
 [shape-margin](https://drafts.csswg.org/css-shapes-1/#propdef-shape-margin) applies to the glyph outline.
- Switched baseline synthesis rules to use 永 (U+6C38) for ideographic
 face edges.
- Specified that an [initial
 letter](#initial-letter) is
 isolated wrt shaping, even though text after it remains in its
 connecting form. ([Issue
 2399](https://github.com/w3c/csswg-drafts/issues/2399#issuecomment-635630662))

See also earlier [changes since the 24 May 2016 Working
Draft](https://www.w3.org/TR/2018/WD-css-inline-3-20180808/).

## [ Acknowledgments]
Special thanks goes to the initial authors, Eric A. Meyer and Michel
Suignard.

In additions to the authors, this specification would not have been
possible without the help from:

David Baron, Mike Bremford, David M Brown, Oriol Brufau, John Daggett,
Stephen Deach, Sylvain Galineau, David Hyatt, Myles Maxfield, Shinyu
Murakami, Jan Nicklas, Tess O'Connor, Sujal Parikh, Florian Rivoal, Alan
Stearns, Weston Thayer, Bobby Tung, Chris Wilson, Grzegorz Zygmunt.

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.
