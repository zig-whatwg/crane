## 1. Introduction

*This subsection is non-normative.*

This module covers text decoration, i.e. decorating the glyphs of the
text once typeset according to font and typographic rules. (See
[\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3")
and
[\[CSS-FONTS-3\]](#biblio-css-fonts-3 "CSS Fonts Module Level 3").)
Such features are traditionally used not only for purely decorative
purposes, but also in some cases to show emphasis, for honorifics, and
to indicate editorial changes such as insertions, deletions, and
misspellings.

CSS Levels 1 and 2 only defined very basic [line
decorations](#line-decoration) (underlines, overlines, and
strike-throughs) appropriate to Western typographical traditions. Level
3 of this module adds the ability to change the color, style, position,
and continuity of these decorations, and also introduces [emphasis
marks](#emphasis-marks) (traditionally used in East Asian typography),
and [shadows](#text-shadow-property) (which were proposed then deferred
from Level 2).

### 1.1. Module Interactions

This module replaces and extends the text-decorating features defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
chapter 16.

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

### 1.3. Terminology

The terms
[character](https://www.w3.org/TR/css-text-3/#grapheme-cluster),
[letter](https://www.w3.org/TR/css-text-3/#letter), and [content
language](https://www.w3.org/TR/css-text-3/#content-language) as used in
this specification are defined in
[\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3").
Other terminology and concepts used in this specification are defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
and
[\[CSS-WRITING-MODES-4\]](#biblio-css-writing-modes-4 "CSS Writing Modes Level 4").

## 2. Line Decoration: Underline, Overline, and Strike-Through

The following properties describe line decorations that are added to the
content of an element. When specified on or propagated to an [inline
box](https://drafts.csswg.org/css-display-4/#inline-box), that
[box](https://drafts.csswg.org/css-display-4/#box) becomes a [decorating box] for that decoration, applying
the decoration to all its
[fragments](https://drafts.csswg.org/css-break-3/#fragment). The decoration is then further propagated to any
[in-flow](https://drafts.csswg.org/css-display-4/#in-flow)
[block-level](https://drafts.csswg.org/css-display-4/#block-level) boxes that split the inline (see [CSS2.1 section
9.2.1.1](https://www.w3.org/TR/CSS21/visuren.html#anonymous-block-level)).
When specified on or propagated to a [block
container](https://drafts.csswg.org/css-display-4/#block-container) that establishes an [inline formatting
context](https://drafts.csswg.org/css-display-4/#inline-formatting-context), the decorations are propagated to an
[anonymous](https://drafts.csswg.org/css-display-4/#anonymous) inline box that wraps all the
[in-flow]
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) children of the [block
container]. When specified on or propagated
to a [ruby
container](https://drafts.csswg.org/css-ruby-1/#ruby-container), the decorations are propagated only to the [ruby
base](https://drafts.csswg.org/css-ruby-1/#ruby-base-box). For all other box types, the decorations are
propagated to all [in-flow] children.

Note that text decorations are not propagated to any
[out-of-flow](https://drafts.csswg.org/css-display-4/#out-of-flow) descendants, nor to the contents of atomic inline-level
descendants such as inline blocks and inline tables. They are also not
propagated to inline children of inline boxes, although the decoration
is *applied* to such boxes.

Underlines, overlines, and line-throughs are drawn only for
[non-replaced](https://drafts.csswg.org/css-display-4/#non-replaced) [inline
boxes](https://drafts.csswg.org/css-display-4/#inline-box), and are drawn across all text (including white space,
letter spacing, and word spacing) except spacing (white space, letter
spacing, and word spacing) at the beginning and end of a line. [Atomic
inlines](https://drafts.csswg.org/css-display-4/#atomic-inline), such as images and inline blocks, are not decorated.
Margins, borders, and padding of the [decorating
box](#decorating-box) are
always skipped, however the margins, border, and padding of descendant
[inline boxes] are not.

Note that CSS 2.1 required skipping margins, borders, and padding
always. In this level, by default only the margins, borders, and padding
of the [decorating box](#decorating-box) are skipped. In the future CSS2.1 may be updated to
match this new default. Also, control over decorating leading/trailing
spaces is expected in Level 4, and will be applied by default to the
HTML
[`ins`](https://html.spec.whatwg.org/multipage/edits.html#the-ins-element) and
[`del`](https://html.spec.whatwg.org/multipage/edits.html#the-del-element) elements.

UAs *may* interrupt underlines and overlines where the line would cross
glyph ink and to some distance to either side of the glyph outline; this
behavior is not controllable in this level, but will be further defined
in Level 4. Line-throughs must remain continuous, however.

![An alphabetic underline through Myanmar text skips around descenders
and the vertical strokes of combining characters that drop below the
alphabetic
baseline.](images/decoration-skip-ink.png "Skipping Descenders When Drawing an Underline"){height="77"
width="223"}

Skipping Glyph Ink

When the UA interrupts underlines or overlines at glyph boundaries, the
shape of the line at that boundary should follow the shape of the glyph.

Note, this specification intentionally does not mandate a particular
method for "following the shape" of the glyph so that UAs can take
appropriate measures to handle aesthetic and performance considerations.
For example, a UA could assume square line endings below a certain size
threshold for performance reasons; or use trapezoidal endings to
approximate curves, especially on thinner line decorations. In terms of
aesthetic considerations, the UA might also consider what happens when
the glyph boundary intersects only part of the line thickness or is
slanted close to the horizontal---​following the curve exactly could
result in typographically-awkward wisps of underline. Whether to show
the line within enclosed areas of a glyph is yet another consideration.

![Take, for example, the word "goal" with an underline striking through
the bottom loop of the "g". Depending on the position and thickness of
the underline, we might see the entire thickness of the underline, or
only part of it within the "g". This example shows a masked-out
underline in two positions. In the left pair the underline passes
through the center of the bowl of the "g": the full thickness of the
underline shows through the center, filling it. In the right pair the
underline is slightly lower, and thus the portion of the underline
within the "g" can only show a partial
thickness.](images/skip-ink-wisp.png "Wispy Leftovers of a Masked-Out Underline"){height="206"
width="600"}

Hiding the portion of the underline within the bowl gives a cleaner look
to the type, while the curved ends of the underline outside it suggest
the continuity of the underline through the letter by hugging its outer
contour.

Relatively positioning a descendant moves all text decorations applied
to it along with the descendant's text; it does not affect calculation
of the decoration's initial position on that line. The
[visibility](https://drafts.csswg.org/css-display-4/#propdef-visibility) property,
[text-shadow](#propdef-text-shadow), filters, and other graphical
transformations likewise also affect all text decorations applied to
that box---​including decorations propagated from an ancestor box---​and
do not affect the calculation of their initial positions or thicknesses.
(In the case of line decorations drawn over an atomic inline or across
the margins/borders/padding of a non-replaced inline box, they are
analogously associated with the affected atomic inline / non-replaced
inline box rather than with the [decorating
box](#decorating-box).)

In the following style sheet and
document fragment:

 blockquote { text-decoration: underline; color: blue; }
 em { display: block; }
 cite { color: fuchsia; }

 <blockquote>
 <p>
 <span>
 Help, help!
 <em> I am under a hat! </em>

 <cite> —GwieF </cite>
 </span>
 </p>
 </blockquote>

\...the underlining for the blockquote element is propagated to an
anonymous inline box that surrounds the span element, causing the text
\"Help, help!\" to be blue, with the blue underlining from the anonymous
inline underneath it, the color being taken from the blockquote element.
The `<em>text</em>` in the em block is also underlined, as it is in an
in-flow block to which the underline is propagated. The final line of
text is fuchsia, but the underline underneath it is still the blue
underline from the anonymous inline element. ![Sample rendering of the
above underline example](images/underline-example.png){height="182"
width="267"} This diagram shows the boxes involved in the example above.
The rounded aqua line represents the anonymous inline element wrapping
the inline contents of the paragraph element, the rounded blue line
represents the span element, and the orange lines represent the blocks.

In the following style sheet and
document fragment:

 div { color: black; font-size: 48px; text-decoration: underline; text-shadow: blue 0px 50px 0px; }
 span { font-size: 20px; vertical-align: top; text-shadow: green 0px 100px 0px; }

 <div>Help, help! <span>I am under a hat!</span></div>

\...the \<div\> is the [decorating
box](#decorating-box) for its
underline (in black), which is rendered uninterrupted through both the
\<div\> and the \<span\>. Unlike line decorations, however,
\`text-shadow\` is inherited as a property; therefore the green text
shadow on the \<span\> overrides the blue text shadow on the \<div\>. As
a result, when the shadows are painted, the shadow of the \<div\>'s
underline is disjoint across the two elements. ![Sample rendering of the
above underline example](images/underline-example-2.png){height="165"
width="380"}

 Line decorations are propagated through the box tree,
not through inheritance, and thus have no effect on descendants when
specified on an element with [display:
contents](https://drafts.csswg.org/css-display-3/#propdef-display).

### 2.1. Text Decoration Lines: the [text-decoration-line property]
Name:

[text-decoration-line]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[ underline
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) overline [\|\|] line-through
[\|\|] blink \]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no (but see prose, above)

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword(s)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Specifies what line decorations, if any, are added to the element.
Values have the following meanings:

[none]
: Neither produces nor inhibits text decoration.

[underline]
: Each line of text is underlined.

[overline]
: Each line of text has a line over it (i.e. on the opposite side from
 an underline).

[line-through]
: Each line of text has a line through the middle.

[blink]
: The text blinks (alternates between visible and invisible).
 Conforming user agents may simply not blink the text. Note that not
 blinking the text is one technique to satisfy [checkpoint 3.3 of
 WAI-UAAG](https://www.w3.org/TR/UAAG/guidelines.html#tech-on-off-blinking-text).
 This value is **deprecated** in favor of Animations
 [\[CSS-ANIMATIONS-1\]](#biblio-css-animations-1 "CSS Animations Level 1").

 In [vertical writing
modes](https://drafts.csswg.org/css-writing-modes-4/#vertical-writing-mode),
[text-underline-position](#propdef-text-underline-position) can cause the underline and
overline to switch sides. This allows the position of underlines to key
off of language-specific preferences automatically.

### 2.2. Text Decoration Style: the [text-decoration-style property]
Name:

[text-decoration-style]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

solid
[\|](https://drafts.csswg.org/css-values-4/#comb-one) double [\|] dotted
[\|] dashed [\|] wavy

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

solid

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property specifies the style of the line(s) drawn for text
decoration specified on the element. Values have the same meaning as for
the [border-style
properties](https://www.w3.org/TR/css-backgrounds-3/#the-border-style)
[\[CSS-BACKGROUNDS-3\]](#biblio-css-backgrounds-3 "CSS Backgrounds and Borders Module Level 3").
[wavy](https://drafts.csswg.org/css-text-decor-4/#valdef-text-decoration-style-wavy) indicates a wavy line.

The style of text decorations must remain the same on all decorations
originating from a given element, even if descendant boxes have
different specified styles.

### 2.3. Text Decoration Color: the [text-decoration-color property]
Name:

[text-decoration-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

currentcolor

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

computed color

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

This property specifies the color of text decoration (underlines
overlines, and line-throughs) set on the element with
[text-decoration-line](#propdef-text-decoration-line).

The color of text decorations must remain the same on all decorations
originating from a given element, even if descendant boxes have
different specified colors.

### 2.4. Text Decoration Shorthand: the [text-decoration property]
Name:

[text-decoration]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'text-decoration-line\'\>](#propdef-text-decoration-line)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<\'text-decoration-style\'\>](#propdef-text-decoration-style) [\|\|]
[\<\'text-decoration-color\'\>](#propdef-text-decoration-color)

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

This property is a shorthand for setting
[text-decoration-line](#propdef-text-decoration-line),
[text-decoration-color](#propdef-text-decoration-color), and
[text-decoration-style](#propdef-text-decoration-style) in one declaration. Omitted values
are set to their initial values.

 A
[text-decoration](#propdef-text-decoration) declaration that omits both the
[text-decoration-color](#propdef-text-decoration-color) and
[text-decoration-style](#propdef-text-decoration-style) values is backwards-compatible with
CSS Levels 1 and 2.

The following example underlines
unvisited links with a solid blue underline in CSS1 and CSS2 UAs and a
navy dotted underline in CSS3 UAs.

 :link {
 color: blue;
 text-decoration: underline;
 text-decoration: navy dotted underline; /* Ignored in CSS1/CSS2 UAs */
 }

 The shorthand purposefully omits the
[text-underline-position](#propdef-text-underline-position) property, which is a
language/writing-system--dependent setting that keys off the content, so
that it can cascade and inherit independently from the (uninherited)
stylistic settings of the
[text-decoration](#propdef-text-decoration) shorthand.

### 2.5. Text Underline Position: the [text-underline-position property]
Name:

[text-underline-position]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[ under
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) \[ left [\|] right \] \]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword(s)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property sets the position of an underline specified on the
element. (It does not affect underlines specified by ancestor elements.)
If [left](#underline-left) or [right](#underline-right) is specified alone,
[auto](#underline-auto)
is also implied.

The following example styles modern
Chinese, Japanese, and Korean texts with the appropriate underline
positions in both horizontal and vertical text:

 :root:lang(ja), [lang|=ja], :root:lang(ko), [lang|=ko] { text-underline-position: under right; }
 :root:lang(zh), [lang|=zh] { text-underline-position: under left; }

Values have the following meanings:

[auto]

: The user agent may use any algorithm to determine the underline's
 position; however it must be placed at or under the alphabetic
 baseline.

 It is suggested that the default underline position
 be close to the alphabetic baseline, unless that would either cross
 subscripted (or otherwise lowered) text or draw over glyphs from
 Asian scripts such as Han or Tibetan for which an alphabetic
 underline is too high: in such cases, shifting the underline lower
 or aligning to the em box edge as described for
 [under](#underline-under) may be more appropriate.

 ::: figure
 ![In a typical Latin font, the underline is positioned slightly
 below the alphabetic baseline, leaving a gap between the line and
 the bottom of most Latin letters, but crossing through descenders
 such as the stem of a
 \'p\'.](images/underline-position-alphabetic.png "text-underline-position: alphabetic"){height="61"
 width="231"}
 A typical "alphabetic" underline is positioned just below the
 alphabetic baseline
 :::

[under]

: The underline is positioned
 [under](https://drafts.csswg.org/css-writing-modes-4/#under) the element's text content. In this case the
 underline usually does not cross the descenders. (This is sometimes
 called "accounting" underline.) This value can be combined with
 [left](#underline-left) or
 [right](#underline-right) if a particular side is preferred in vertical
 [typographic
 modes](https://drafts.csswg.org/css-writing-modes-4/#typographic-mode).

 ::: figure
 ![In a typical Latin font, the underline is far enough below the
 text that it does not cross the bottom of a
 \'g\'.](images/underline-position-under.png "text-underline-position: under"){height="68"
 width="405"}
 [text-underline-position:
 under](#propdef-text-underline-position)
 :::

 :::
 (#example-95685877) Because
 [text-underline-position](#propdef-text-underline-position) inherits, and is not reset by
 the
 [text-decoration](#propdef-text-decoration) shorthand, the following
 example switches the document to use
 [under](#underline-under) underlining, which can be more appropriate for
 writing systems with long, complicated descenders. It is also often
 useful for mathematical or chemical texts that use many subscripts.
 :root { text-underline-position: under; }
 :::

 The [under] value does not guarantee that the
 underline will not conflict with glyphs, as some fonts have
 descenders or diacritics that extend below the font's descent
 metrics.

[left]
: In vertical [typographic
 modes](https://drafts.csswg.org/css-writing-modes-4/#typographic-mode), the underline is aligned as for
 [under](#underline-under), except it is always aligned to the left edge of
 the text. If this causes the underline to be drawn on the \"over\"
 side of the text, then an overline also switches sides and is drawn
 on the \"under\" side.

[right]
: In vertical [typographic
 modes](https://drafts.csswg.org/css-writing-modes-4/#typographic-mode), the underline is aligned as for
 [under](#underline-under), except it is always aligned to the right edge of
 the text. If this causes the underline to be drawn on the \"over\"
 side of the text, then an overline also switches sides and is drawn
 on the \"under\" side.

![In mixed Japanese-Latin vertical text, \'text-underline-position:
left\' places the underline on the left side of the
text.](images/underline-position-left.png "text-underline-position: left"){height="168"
width="40"}

![In mixed Japanese-Latin vertical text, \'text-underline-position:
right\' places the underline on the right side of the
text.](images/underline-position-right.png "text-underline-position: right"){height="168"
width="40"}

[left](#underline-left)

[right](#underline-right)

In vertical [typographic
modes](https://drafts.csswg.org/css-writing-modes-4/#typographic-mode), the
[text-underline-position](#propdef-text-underline-position) values
[left](#underline-left)
and [right](#underline-right) allow placing the underline on either side of the
text. (In horizontal [typographic modes],
both values are treated as
[auto](#underline-auto).)

The exact position and thickness of line decorations is UA-defined in
this level. However, for underlines and overlines the UA must use a
single thickness and position on each line for the decorations deriving
from a single [decorating box](#decorating-box).

![A single underline drawn under varying font sizes and vertical
positions must be a single
line.](images/underline-single.png){height="81" width="125"} vs.
![Drawing multiple line segments, each with the position and thickness
appropriate to the decorated text, is
incorrect.](images/underline-broken.png){height="80" width="120"}

Correct and incorrect rendering of `<u>A<sup>B</sup><big>C</big>D</u>`

Note, since line decorations can span elements with varying font sizes
and vertical alignments, the best position for a line decoration is not
necessarily the ideal position dictated by the [decorating
box](#decorating-box). For
example, an overline positioned to a small font will effectively become
a line-through if the element contains text in a significantly larger
font-size. Even for underlines, if the text is not aligned to the
alphabetic baseline (for example, in vertical typesetting styles, text
is aligned by its central baseline by default
[\[CSS-WRITING-MODES-4\]](#biblio-css-writing-modes-4 "CSS Writing Modes Level 4"))
an underline will cut through descendant text of a larger font-size. UA
consideration of descendant content will therefore result in better
typography.

!(images/leftline-cross.png){height="219" width="80"}
!(images/leftline-under.png){height="219" width="80"}

Due to the central baseline alignment of vertical text, a left-side
underline on small vertical text will cut through the text of a child
with a larger font size. The underline is not allowed to be broken, but
adjusting its position further to the left properly accommodates all of
the underlined text.

UAs *must* adjust line positions to match the shifted metrics of
[decorating boxes](#decorating-box) shifted with
[vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align) values other than
[baseline](https://drafts.csswg.org/css2/#valdef-vertical-align-baseline)
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
or subscripted/superscripted via
[font-variant-position](https://drafts.csswg.org/css-fonts-4/#propdef-font-variant-position)
[\[CSS-FONTS-3\]](#biblio-css-fonts-3 "CSS Fonts Module Level 3"),
but *must not* adjust the line position or thickness in response to
descendants of a [decorating box] that are so
styled. This allows superscripts and subscripts to be properly decorated
(underlined, struck through, etc.) but prevents them from distorting or
breaking the positioning of such decorations on their ancestors.

![An underline for just the superscript \'st\' in \'1st\' is drawn just
below the superscript, whereas an underline for the entire text is drawn
at the appropriate position for full-size
text.](images/underline-superscript.png){height="38" width="80"}

Example of underline applied to [superscripted text]
vs. underline applied to [text containing a superscript]

Some font formats (such as OpenType) can offer information about the
appropriate position of a line decoration. The UA should use such
information (such as the underline thickness, or appropriate alphabetic
underline position) from the font wherever appropriate.

 Typically, OpenType font metrics give the position of
an [alphabetic] underline; in some cases (especially in CJK
fonts), it gives the position of a [under left] underline. (In
this case, the font's underline metrics typically touch the bottom edge
of the em box). The UA may but is not required to correct for incorrect
font metrics.

## 3. Emphasis Marks

East Asian documents traditionally use small symbols next to each glyph
to emphasize a run of text. For example:

![Example of emphasis in Japanese appearing over the
text](images/text-emphasis-ja.png){height="39" width="208"}

Accent emphasis (shown in blue for clarity) applied to Japanese text

[text-emphasis](#propdef-text-emphasis) shorthand, and its
[text-emphasis-style](#propdef-text-emphasis-style) and
[text-emphasis-color](#propdef-text-emphasis-color) longhands, can be used to apply
such marks to the text. The
[text-emphasis-position](#propdef-text-emphasis-position) property, which inherits
separately, allows setting the emphasis marks' position with respect to
the text.

### 3.1. Emphasis Mark Style: the [text-emphasis-style property]
Name:

[text-emphasis-style]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[ \[ filled [\|] open \]
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) \[ dot [\|] circle
[\|] double-circle [\|]
triangle [\|] sesame \] \]
[\|]
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[none](#valdef-text-emphasis-style-none), a pair of keywords representing the shape and
fill, or a string

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property applies emphasis marks to the element's text. Values have
the following meanings:

[none]
: No emphasis marks.

[filled]
: The shape is filled with solid color.

[open]
: The shape is hollow.

[dot]
: Display small circles as marks. The filled dot is U+2022 \'•\', and
 the open dot is U+25E6 \'◦\'.

[circle]
: Display large circles as marks. The filled circle is U+25CF \'●\',
 and the open circle is U+25CB \'○\'.

[double-circle]
: Display double circles as marks. The filled double-circle is U+25C9
 \'◉\', and the open double-circle is U+25CE \'◎\'.

[triangle]
: Display triangles as marks. The filled triangle is U+25B2 \'▲\', and
 the open triangle is U+25B3 \'△\'.

[sesame]
: Display sesames as marks. The filled sesame is U+FE45 \'﹅\', and
 the open sesame is U+FE46 \'﹆\'.

[[\<string\>](https://drafts.csswg.org/css-values-4/#string-value)]
: Display the given string as marks. Authors should not specify more
 than one
 [character](https://drafts.csswg.org/css-text-4/#character) in \<string\>. The UA may truncate or ignore
 strings consisting of more than one grapheme cluster.

If a shape keyword is specified but neither of
[filled](#valdef-text-emphasis-style-filled) nor
[open](#valdef-text-text-emphasis-open) is specified,
[filled] is assumed.
If only [filled] or
[open] is specified, the
shape keyword computes to
[circle](#valdef-text-emphasis-style-circle) in horizontal [typographic
modes](https://drafts.csswg.org/css-writing-modes-4/#typographic-mode) and
[sesame](#valdef-text-emphasis-style-sesame) in vertical [typographic
modes].

The marks should be drawn using the element's font settings with the
addition of the
[ruby](https://drafts.csswg.org/css-fonts-4/#valdef-font-variant-east-asian-ruby) feature and the size scaled down 50%. However,
since not all fonts have all these glyphs, and some fonts use
inappropriate sizes for emphasis marks in these code points, the UA may
opt to use a font known to be good for emphasis marks, or the marks may
instead be synthesized by the UA. Marks must remain upright in vertical
[typographic
modes](https://drafts.csswg.org/css-writing-modes-4/#typographic-mode): like CJK characters, they do not rotate to match the
writing mode. The orientation of marks in horizontal [typographic
modes] of vertical [writing
modes](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) is undefined in this level (but may be defined in a
future level if definitive use cases arise).

 One example of good fonts for emphasis marks is Adobe's
open source [Kenten Generic OpenType
Font](https://github.com/adobe-fonts/kenten-generic), which is specially
designed for the emphasis marks.

The marks are drawn once for each [typographic character
unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit). However, emphasis marks are *not* drawn for:

- [Word separators](https://www.w3.org/TR/css-text-3/#word-separator) or
 other
 [characters](https://drafts.csswg.org/css-text-4/#character) that belong to the Unicode separator classes (Z\*).
 (But note that emphasis marks *are* drawn for a space that combines
 with any combining characters.)
- Punctuation\--specifically, any
 [characters](https://drafts.csswg.org/css-text-4/#character) that belong to the Unicode P\* [general
 category](https://drafts.csswg.org/css-text-4/#unicode-general-category) and do not `NFKD` normalize
 [\[UAX15\]](#biblio-uax15 "Unicode Normalization Forms")
 to any of the following symbols:
 \#
 U+0023
 NUMBER SIGN
 \%
 U+0025
 PERCENT SIGN
 ‰
 U+2030
 PER MILLE SIGN
 ‱
 U+2031
 PER TEN THOUSAND SIGN
 ٪
 U+066A
 ARABIC PERCENT SIGN
 ؉
 U+0609
 ARABIC-INDIC PER MILLE SIGN
 ؊
 U+060A
 ARABIC-INDIC PER TEN THOUSAND SIGN
 &
 U+0026
 AMPERSAND
 ⁊
 U+204A
 TIRONIAN SIGN ET
 @
 U+0040
 COMMERCIAL AT
 §
 U+00A7
 SECTION SIGN
 ¶
 U+00B6
 PILCROW SIGN
 ⁋
 U+204B
 REVERSED PILCROW SIGN
 ⁓
 U+2053
 SWUNG DASH
 〽️
 U+303D
 PART ALTERNATION MARK
- Characters belonging to the Unicode classes for control codes and
 unassigned characters (Cc, Cf, Cn).

 Control over which characters are marked will be added
in Level 4. (The list of punctuation may also be further refined,
particularly for non-CJK punctuation.)

### 3.2. Emphasis Mark Color: the [text-emphasis-color property]
Name:

[text-emphasis-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

currentcolor

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

computed color

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

This property specifies the foreground color of the emphasis marks.

[currentcolor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor) keyword computes to itself and is resolved to
the value of [color] after inheritance is performed. This
means
[text-emphasis-color](#propdef-text-emphasis-color) by default matches the text
[color] even as [color] changes across elements.

### 3.3. Emphasis Mark Shorthand: the [text-emphasis property]
Name:

[text-emphasis]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'text-emphasis-style\'\>](#propdef-text-emphasis-style)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<\'text-emphasis-color\'\>](#propdef-text-emphasis-color)

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

This property is a shorthand for setting
[text-emphasis-style](#propdef-text-emphasis-style) and
[text-emphasis-color](#propdef-text-emphasis-color) in one declaration. Omitted values
are set to their initial values.

Note that
[text-emphasis-position](#propdef-text-emphasis-position) is not reset in this shorthand.
This is because typically the shape and color vary, but the position is
consistent for a particular language throughout the document. Therefore
the position should inherit independently.

### 3.4. Emphasis Mark Position: the [text-emphasis-position property]
Name:

[text-emphasis-position]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ over
[\|](https://drafts.csswg.org/css-values-4/#comb-one) under \]
[&&](https://drafts.csswg.org/css-values-4/#comb-all) \[ right [\|] left
\][?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

over right

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword(s)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property describes where emphasis marks are drawn at. If [\[ right
\| left \]] is omitted, it defaults to
[right](#valdef-text-emphasis-position-right). The values have following meanings:

[over]
: Draw marks over the text in horizontal [typographic
 modes](https://drafts.csswg.org/css-writing-modes-4/#typographic-mode).

[under]
: Draw marks under the text in horizontal [typographic
 modes](https://drafts.csswg.org/css-writing-modes-4/#typographic-mode).

[right]
: Draw marks to the right of the text in vertical [typographic
 modes](https://drafts.csswg.org/css-writing-modes-4/#typographic-mode).

[left]
: Draw marks to the left of the text in vertical [typographic
 modes](https://drafts.csswg.org/css-writing-modes-4/#typographic-mode).

Emphasis marks are drawn exactly as if each character was assigned the
mark as its ruby annotation text with the ruby position given by
[text-emphasis-position](#propdef-text-emphasis-position) and the ruby alignment as centered.
Note that this position may be adjusted if it would conflict with
underline or overline decorations.

The effect of emphasis marks on the line height is the same as for ruby
text.

Note, the preferred position of emphasis marks depends on the language.
In Japanese for example, the preferred position is [over right].
In Chinese, on the other hand, the preferred position is [under
right]. The informative table below summarizes the preferred
emphasis mark positions for Chinese and Japanese:

Preferred emphasis mark and ruby position

Language

Preferred position

Illustration

Horizontal

Vertical

Japanese

over

right

![Emphasis marks appear over each emphasized character in horizontal
Japanese
text.](images/text-emphasis-ja.png "Emphasis (shown in blue for clarity) applied above a fragment of Japanese text"){height="39"
width="209"}

![Emphasis marks appear on the right of each emphasized character in
vertical Japanese
text.](images/text-emphasis-v.gif "Emphasis applied on the right of a fragment of Japanese text"){height="79"
width="34"}

Korean

Mongolian

Chinese

under

right

![Emphasis marks appear below each emphasized character in horizontal
Simplified Chinese
text.](images/text-emphasis-zh.png "Emphasis (shown in blue for clarity) applied below a fragment of Chinese text"){height="39"
width="140"}

If emphasis marks are applied to characters for which ruby is drawn in
the same position as the emphasis mark, the emphasis marks are placed
outside the ruby. This includes
[auto-hidden](https://www.w3.org/TR/css-ruby-1/#autohide) and empty
[ruby
annotations](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-box).

![In this example, emphasis marks are applied to 4 characters, two of
which have ruby. The dots are placed above each character (aligned with
the ruby) for the bare characters, and above the ruby text for the
annotated characters.](images/text-emphasis-ruby.png){height="50"
width="134"}

Emphasis marks applied to 4 characters, with ruby also on 2 of them

Some editors prefer to hide emphasis
marks when they conflict with ruby. In HTML, this can be done with the
following style rule:

 ruby { text-emphasis: none; }

Some other editors prefer to hide ruby when they conflict with emphasis
marks. In HTML, this can be done with the following pattern:

 em { text-emphasis: dot; } /* Set text-emphasis for <em> elements */
 em rt { display: none; } /* Hide ruby inside <em> elements */

## 4. Text Shadows: the [text-shadow property]
Name:

[text-shadow]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)[?](https://drafts.csswg.org/css-values-4/#mult-opt)
[&&](https://drafts.csswg.org/css-values-4/#comb-all) \[
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)[{2}](https://drafts.csswg.org/css-values-4/#mult-num) [\<length \[0,∞\]\>][?] \]
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

either the keyword
[none](https://drafts.csswg.org/css-backgrounds-3/#box-shadow-none) or a list, each item consisting of three
absolute lengths plus a computed color

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

[as shadow
list](https://www.w3.org/TR/web-animations-1/#animating-shadow-lists)

This property accepts a comma-separated list of shadow effects to be
applied to the text of the element. Values are interpreted as for
[box-shadow](https://drafts.csswg.org/css-backgrounds-3/#propdef-box-shadow)
[\[CSS-BACKGROUNDS-3\]](#biblio-css-backgrounds-3 "CSS Backgrounds and Borders Module Level 3").
(But note that spread values and the [inset] keyword are not
allowed.) Each layer shadows the element's text and all its text
decorations (composited together).

The shadow effects are applied front-to-back: the first shadow is on
top. The shadows may thus overlay each other, but they never overlay the
text itself. The shadow must be painted at a stack level between the
element's border and/or background (if present) and the elements text
and text decoration. UAs should avoid painting text shadows over text in
adjacent elements belonging to the same stack level and stacking
context. (This may mean that the exact stack level of the shadows
depends on whether the element has a border or background: the exact
stacking behavior of text shadows is thus UA-defined.) It is undefined
whether a given shadow layer shadows each glyph or decoration
independently or if the text and/or decorations are flattened and then
shadowed.

Unlike
[box-shadow](https://drafts.csswg.org/css-backgrounds-3/#propdef-box-shadow), text shadows are not clipped to
the shadowed shape and may show through if the text is
partially-transparent. Like [box-shadow], text shadows do not influence layout, and do not trigger
scrolling or increase the size of the [scrollable overflow
area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region).

 The painting order of shadows defined here is the
opposite of that defined in the 1998 [CSS2
Recommendation](https://www.w3.org/TR/1998/REC-CSS2-19980512).

The [text-shadow] property applies to both the `::first-line` and
`::first-letter` pseudo-elements.

## 5. Painting Text Decorations

### 5.1. Painting Order of Text Decorations

As in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
text decorations are drawn immediately over/under the text they
decorate, in the following order (bottommost first):

- shadows
 ([text-shadow](#propdef-text-shadow))
- underlines
 ([text-decoration](#propdef-text-decoration))
- overlines
 ([text-decoration](#propdef-text-decoration))
- text
- emphasis marks
 ([text-emphasis](#propdef-text-emphasis))
- line-through
 ([text-decoration](#propdef-text-decoration))

Where line decorations are drawn across box decorations or atomic
inlines, they are drawn over non-positioned content and just below any
positioned descendants (immediately below layer #8 in CSS2.1 Appendix
E).

### 5.2. Overflow of Text Decorations

Text decorations that leak outside a
[box](https://drafts.csswg.org/css-display-4/#box) are considered [ink
overflow](https://drafts.csswg.org/css-overflow-3/#ink-overflow): they do not extend the [scrollable overflow
area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region).
[\[css-overflow-3\]](#biblio-css-overflow-3 "CSS Overflow Module Level 3")

## [ Appendix A: Acknowledgements]
This specification would not have been possible without the help from:
Ayman Aldahleh, Bert Bos, Tantek Çelik, Stephen Deach, John Daggett,
Martin Dürst, Laurie Anna Edlund, Ben Errez, Yaniv Feinberg, Arye
Gittelman, Ian Hickson, Martin Heijdra, Richard Ishida, Masayasu
Ishikawa, Michael Jochimsen, Eric LeVine, Ambrose Li, Håkon Wium Lie,
Chris Lilley, Ken Lunde, Nat McCully, Shinyu Murakami, Paul Nelson,
Chris Pratley, Marcin Sawicki, Arnold Schrijver, Rahul Sonnad, Michel
Suignard, Takao Suzuki, Frank Tang, Chris Thrasher, Etan Wexler, Chris
Wilson, Masafumi Yabe and Steve Zilles.

## [ Appendix B: Default UA Stylesheet]
This appendix is informative, and is to help UA developers to implement
default stylesheet, but UA developers are free to ignore or change.

``` css
/* typical styling of HTML */
blink {
 text-decoration-line: blink;
}
s, strike, del {
 text-decoration: line-through;
}
u, ins, :link, :visited {
 text-decoration: underline;
}
abbr[title], acronym[title] {
 text-decoration: dotted underline;
}

/* disable inheritance of text-emphasis marks to ruby text:
 emphasis marks should only apply to base text */
rt { text-emphasis: none; }

/* set language-appropriate default emphasis mark position */
:root:lang(zh), [lang|=zh] { text-emphasis-position: under right; }
[lang|=ja], [lang|=ko] { text-emphasis-position: over right; }

/* set language-appropriate default underline position */
:root:lang(ja), [lang|=ja],
:root:lang(mn), [lang|=mn],
:root:lang(ko), [lang|=ko] { text-underline-position: right; }
:root:lang(zh), [lang|=zh] { text-underline-position: left; }
/* auto is chosen (implied) above instead of under
 due to content-compatibility concerns */
```

If you find any issues, recommendations
to add, or corrections, please send the information to
<www-style@w3.org> with [\[css-text-decor\]] in the subject line.

While [text-decoration-line:
blink](#propdef-text-decoration-line) can't be fully reproduced with other existing
properties, authors can achieve a very similar effect with the following
CSS:

 @keyframes blink {
 0% {
 visibility: hidden;
 animation-timing-function: step-end;
 }
 25%, 100% {
 visibility: visible;
 }
 }
 blink {
 animation: blink 1s infinite;
 }

## [Appendix C: Changes]
### [ Changes since the [August 2019 Candidate Recommendation](https://www.w3.org/TR/2019/CR-css-text-decor-3-20190813/)]
Changes include:

- Clarify that
 [text-shadow](#propdef-text-shadow) animates as a [shadow
 list] like
 [box-shadow](https://drafts.csswg.org/css-backgrounds-3/#propdef-box-shadow). ([Issue
 4375](https://github.com/w3c/csswg-drafts/pull/4375))
- Be explicit about properties that apply to text. ([Issue
 5303](https://github.com/w3c/csswg-drafts/issues/5303))
- Minor editorial fixes.

### [ Changes since the [July 2018 Candidate Recommendation](https://www.w3.org/TR/2018/CR-css-text-decor-3-20180703/)]
Changes include:

- Clarified that text decoration overflow is [ink
 overflow](https://drafts.csswg.org/css-overflow-3/#ink-overflow). ([Issue
 3272](https://github.com/w3c/csswg-drafts/issues/3272))
- Fixed inconsistencies in sample
 [text-underline-position](#propdef-text-underline-position) rules. ([Issue
 3441](https://github.com/w3c/csswg-drafts/issues/3441))
- Cleaned up "Computed value" lines to match new conventions.

A [Disposition of
Comments](https://drafts.csswg.org/css-text-decor-3/issues-cr-2018) is
available.

### [ Changes since the [August 2013 Candidate Recommendation](https://www.w3.org/TR/2013/CR-css-text-decor-3-20130801/)]
Significant changes include:

- Deferred [text-decoration-skip] to Level 4 to allow for major
 changes. Defined behavioral defaults in prose. ([Issue
 1](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-1),
 [Issue
 22](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-22),
 [Issue
 26](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-26))

- Specified that line-throughs are unaffected by ink-skipping feature.
 ([Issue
 24](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-24))

- Recommended that when ink is skipped, line endings conform to the
 glyph shape. ([Issue
 30](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-30))

- Updated writing-mode--sensitive conditions to depend on [typographic
 mode](https://drafts.csswg.org/css-writing-modes-4/#typographic-mode), to account for addition of
 [sideways-lr](https://drafts.csswg.org/css-writing-modes-4/#valdef-writing-mode-sideways-lr) and
 [sideways-rl](https://drafts.csswg.org/css-writing-modes-4/#valdef-writing-mode-sideways-rl) values to
 [writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) property. Marked orientation of
 emphasis marks under
 [sideways-lr] and
 [sideways-rl]
 undefined. ([Issue
 10](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-10),
 [Issue
 20](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-20))

- Made [\[ right \| left \]] option of
 [text-emphasis-position](#propdef-text-emphasis-position) optional, defaulting to
 [right](#valdef-text-emphasis-position-right). ([Issue
 17](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-17))

- Made
 [text-underline-position](#propdef-text-underline-position) imply
 [auto](#underline-auto) instead of
 [under](#underline-under) when only
 [left](#underline-left) or
 [right](#underline-right) is specified. ([Issue
 18](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-18))

- Changed text decoration to skip leading and trailing spaces. ([Issue
 6](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-6))

- Noted that the positions of ruby annotations may be adjusted to avoid
 conflicts with text decorations. ([Issue
 21](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-21))

- Changed initial value of
 [text-shadow](#propdef-text-shadow) to be `currentColor`. ([Issue
 28](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-28))

- Fixed error in "Computed value" line for
 [text-shadow](#propdef-text-shadow). ([Issue
 7](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-7))

- Fixed canonical order of
 [text-shadow](#propdef-text-shadow) values to match implementations.
 ([Issue
 35](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-35))

- Defined positioning of emphasis marks with respect to auto-hidden and
 empty ruby annotations. ([Issue
 9](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-9))

 > If emphasis marks are applied to characters for which ruby is drawn
 > in the same position as the emphasis mark, the emphasis marks are
 > placed outside the ruby. [This includes
 > [auto-hidden](https://www.w3.org/TR/css-ruby-1/#autohide) and empty
 > [ruby
 > annotations](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-box).]

- Made
 [text-emphasis](#propdef-text-emphasis) skip punctuation by default.
 ([Issue
 16](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-16))

- Added rule to apply
 [ruby](https://drafts.csswg.org/css-fonts-4/#valdef-font-variant-east-asian-ruby) to emphasis marks\' font. ([Issue
 13](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-13))

- Various corrections and improvements to the default UA rules for
 [text-emphasis-position](#propdef-text-emphasis-position) and
 [text-underline-position](#propdef-text-underline-position). ([Issue
 11](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-11),
 [Issue
 12](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-12),
 [Issue
 18](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-18),
 [Issue
 19](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-19),
 [Issue
 36](https://drafts.csswg.org/css-text-decor-3/issues-cr-2013#issue-36))

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.
