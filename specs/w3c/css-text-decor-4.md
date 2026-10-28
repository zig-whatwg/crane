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
3 of this module added the ability to change the color, style, position,
and continuity of these decorations, and also introduced [emphasis
marks](#emphasis-marks) (traditionally used in East Asian typography),
and [shadows](#text-shadow-property) (which were proposed then deferred
from Level 2). Level 4 introduces additional controls over these
decorations.

### 1.1. Module Interactions

This module replaces and extends the text-decorating features defined in
[\[CSS-TEXT-DECOR-3\]](#biblio-css-text-decor-3 "CSS Text Decoration Module Level 3").

All of the properties in this module can be applied to the
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line) and
[::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter)
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element).

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

The terms [typographic character
unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit) ([character]), [typographic letter
unit](https://drafts.csswg.org/css-text-4/#typographic-letter-unit)
([letter](https://drafts.csswg.org/css-syntax-3/#letter)), and [content
language](https://drafts.csswg.org/css-text-4/#content-language) as used in this specification are defined in
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
the decoration to all its [box
fragments](https://drafts.csswg.org/css-break-4/#box-fragment). The decoration is then further propagated to any
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
always. In Level 3 and beyond, by default only the margins, borders, and
padding of the [decorating
box](#decorating-box) are
skipped. In the future CSS2.1 may be updated to match this new default.

[Relatively
positioning](https://drafts.csswg.org/css-position-3/#relative-position) a descendant moves all text decorations applied to it
along with the descendant's text; it does not affect calculation of the
decoration's initial position on that line. The
[visibility](https://drafts.csswg.org/css-display-4/#propdef-visibility) property,
[text-shadow](#propdef-text-shadow), filters, and other graphical
transformations likewise also affect all text decorations applied to
that box---​including decorations propagated from an ancestor box---​and
do not affect the calculation of their initial positions or thicknesses.
(In the case of line decorations drawn over an [atomic
inline](https://drafts.csswg.org/css-display-4/#atomic-inline) or across the margins/borders/padding of a
[non-replaced](https://drafts.csswg.org/css-display-4/#non-replaced) [inline
box](https://drafts.csswg.org/css-display-4/#inline-box), they are analogously associated with the affected
atomic inline / non-replaced inline box rather than with the [decorating
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
contents](https://drafts.csswg.org/css-display-4/#propdef-display).

### 2.1. Text Decoration Lines: the [text-decoration-line property]
Name:

[text-decoration-line]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[ underline
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) overline [\|\|] line-through
[\|\|] blink \] [\|]
spelling-error [\|] grammar-error

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

This property, which is a
[sub-property](https://drafts.csswg.org/css-cascade-5/#longhand) of the
[text-decoration](#propdef-text-decoration) shorthand, specifies what line
decorations, if any, are added by the element. Values other than
[none](#valdef-text-decoration-line-none) cause the element to originate the indicated
text decorations, and to apply and propagate it as described
[above](#line-decoration).

 Unless it is desired for the color, style, and
thickness of the lines to be set by declarations lower in the
[cascade](https://drafts.csswg.org/css-cascade-6/#cascade), it is safer to use the
[text-decoration](#propdef-text-decoration)
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) instead of this
[longhand](https://drafts.csswg.org/css-cascade-5/#longhand).

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
 [\[CSS3-ANIMATIONS\]](#biblio-css3-animations "CSS Animations Level 1").

[spelling-error]
: This value indicates the type of text decoration used by the user
 agent to highlight spelling mistakes. Its appearance is UA-defined,
 and may be platform-dependent. [It is often rendered as a red wavy
 underline.]

[grammar-error]
: This value indicates the type of text decoration used by the user
 agent to highlight grammar mistakes. Its appearance is UA defined,
 and may be platform-dependent. [It is often rendered as a green wavy
 underline.]

 In [vertical writing
modes](https://drafts.csswg.org/css-writing-modes-4/#vertical-writing-mode),
[text-underline-position](#propdef-text-underline-position) can cause the underline and
overline to switch sides. This allows the position of underlines to key
off of language-specific preferences automatically.

When
[spelling-error](#valdef-text-decoration-line-spelling-error) or
[grammar-error](#valdef-text-decoration-line-grammar-error) apply, the user agent *must* disregard the other
[sub-properties](https://drafts.csswg.org/css-cascade-5/#longhand) of
[text-decoration](#propdef-text-decoration), as well any other properties
typically affecting the appearance of line decorations (such as
[text-underline-position](#propdef-text-underline-position),
[color](https://drafts.csswg.org/css-color-4/#propdef-color),
[stroke](https://drafts.csswg.org/fill-stroke-3/#propdef-stroke), or
[fill](https://drafts.csswg.org/fill-stroke-3/#propdef-fill)) when rendering these decorations.
However, the user agent may take into account the
[accent-color](https://drafts.csswg.org/css-ui-4/#propdef-accent-color) property.

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

This property, which is a
[sub-property](https://drafts.csswg.org/css-cascade-5/#longhand) of the
[text-decoration](#propdef-text-decoration) shorthand, sets the line-drawing
style of underlines, overlines, and line-throughs specified on the
element with
[text-decoration-line](#propdef-text-decoration-line), and affects all decorations
originating from this element even if descendant boxes specify a
different style.

Values have the same meaning as for the [border-style
properties](https://www.w3.org/TR/css-backgrounds-3/#the-border-style)
[\[CSS-BACKGROUNDS-3\]](#biblio-css-backgrounds-3 "CSS Backgrounds and Borders Module Level 3").
[wavy] indicates a
wavy line.

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

This property, which is a
[sub-property](https://drafts.csswg.org/css-cascade-5/#longhand) of the
[text-decoration](#propdef-text-decoration) shorthand, sets the color of
underlines, overlines, and line-throughs specified on the element with
[text-decoration-line](#propdef-text-decoration-line), and affects all decorations
originating from this element even if descendant boxes specify a
different color.

### 2.4. Text Decoration Line Thickness: the [text-decoration-thickness property]
Name:

[text-decoration-thickness]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) from-font [\|]
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) [\|]
[\<line-width\>](https://drafts.csswg.org/css-backgrounds-3/#typedef-line-width)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, with
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values computed

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

This property, which is a
[sub-property](https://drafts.csswg.org/css-cascade-5/#longhand) of the
[text-decoration](#propdef-text-decoration) shorthand, sets the stroke
thickness of underlines, overlines, and line-throughs specified on the
element with
[text-decoration-line](#propdef-text-decoration-line), and affects all decorations
originating from this element even if descendant boxes specify a
different thickness.

Values have the following meanings:

[auto]
: The UA chooses an appropriate thickness for text decoration lines;
 see below.

[from-font]
: If the [first available
 font](https://drafts.csswg.org/css-fonts-4/#first-available-font) has metrics indicating a preferred underline width,
 use that width, otherwise behaves as
 [auto](#valdef-text-decoration-thickness-auto).

[[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)]\
[[\<line-width\>](https://drafts.csswg.org/css-backgrounds-3/#typedef-line-width)]

: A length value specifies the thickness of text decoration lines as a
 fixed length.

 A length will inherit as a fixed value, and will
 not scale with the font.

 A percentage value specifies the thickness of text decoration lines
 as a percentage of the used
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size).

 A percentage will inherit as a relative value, and
 will therefore scale with changes in the font as it inherits.

 The UA should round the actual value to the nearest integer device
 pixel, and ensure it is at least one device pixel.

#### 2.4.1. Automatic Thickness of Text Decoration Lines

Some font formats (such as OpenType) can offer information about the
appropriate thickness of a line decoration. The UA should use such
font-based information when choosing
[auto](#valdef-text-decoration-thickness-auto) line thicknesses wherever appropriate.

### 2.5. Determining the Position and Thickness of Line Decorations

This section is copied over from early
drafts of Text Decoration Level 3. It is still under review, and needs
integration with
[text-underline-offset](#propdef-text-underline-offset) and
[text-decoration-thickness](#propdef-text-decoration-thickness).

Since line decorations can span elements with varying font sizes and
vertical alignments, the best position for a line decoration is not
necessarily the ideal position dictated by the [decorating
box](#decorating-box).
Instead, it's calculated, per line, from all text decorated by the
[decorating box] on that line, the [considered
text].
However, descendants of the [decorating box]
that are skipped due to
[text-decoration-skip](#propdef-text-decoration-skip), descendant inlines with
[text-decoration-skip: ink], and any descendants that do not participate in the [decorating
box]'s inline formatting context are excluded
from the set of [considered
text](#considered-text).

The line decoration positions are then calculated per line as follows
(treating
[over](https://drafts.csswg.org/css-writing-modes-4/#over)-positioned underlines as [over] lines
and
[under](https://drafts.csswg.org/css-writing-modes-4/#under)-positioned overlines as [under]
lines):

[over](https://drafts.csswg.org/css-writing-modes-4/#over) lines
: Align the line decoration with respect to the highest
 [over](https://drafts.csswg.org/css-writing-modes-4/#over) EM-box edge of the [considered
 text](#considered-text).

alphabetic underlines
: The alphabetic underline position is calculated by taking the ideal
 offset (from the alphabetic baseline) of each run of [considered
 text](#considered-text),
 averaging those, and then using the lowest alphabetic baseline to
 actually position the line. (Alphabetic baselines can differ between
 [baseline](https://drafts.csswg.org/css2/#valdef-vertical-align-baseline)-aligned boxes if the dominant baseline is
 non-alphabetic.) To prevent superscripts and subscripts from
 throwing this position off-kilter, an inline with a non-initial
 computed
 [vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align) is treated as having the ideal
 underline position of its parent.

non-alphabetic [under](https://drafts.csswg.org/css-writing-modes-4/#under) lines
: Position the line decoration with respect to the lowest
 [under](https://drafts.csswg.org/css-writing-modes-4/#under) EM-box edge of the [considered
 text](#considered-text).

line-throughs

: Line-throughs essentially use the same sort of averaging as for
 alphabetic underlines, but recompute the position when drawing
 across a descendant with a different computed
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size). (This ensures that the text
 remains effectively "crossed out" despite any font size changes.)
 For each run of [considered
 text](#considered-text)
 with the same [font-size],
 compute an ideal position averaged from its font metrics. To prevent
 superscripts and subscripts from throwing this position off-kilter,
 an inline with a non-initial computed
 [vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align) is treated as having the ideal
 underline position of its parent. Position the portion of the line
 across each decorated fragment at that position.

 (#issue-3dd812b9) For simplicity, line-throughs should
 draw over each element at that element's preferred/averaged
 position. This can produce some undesirable jumpiness, but there
 doesn't appear to be any way to avoid that which is correct in all
 instances, and all attempts are worryingly complex. What position
 should line-throughs adopt over elements that have a different
 font-size, but no [considered
 text](#considered-text)?

CSS does not define the thickness of line decorations. In determining
the thickness of text decoration lines, user agents may consider the
font sizes, faces, and weights of descendants to provide an
appropriately averaged thickness.

The following figure shows the
averaging for underline:

![In the first rendering of the underlined text \'1st a\' with \'st\' as
a superscript, both the \'1st\' and the \'a\' are rendered in a small
font. In the second rendering, the \'a\' is rendered in a larger font.
In the third, both \'1st\' and \'a\' are
large.](images/underline-averaging.gif){height="105" width="326"}

In the three fragments of underlined text, the underline is drawn
consecutively lower and thicker as the ratio of large text to small text
increases.

Using the same example, a line-through would in the second fragment,
instead of averaging the two font sizes, split the line-through into two
segments:

!(images/linethrough-averaging.gif){height="105" width="354"}

In both cases, however, the superscript, due to the vertical-alignment
shift, has no effect on the position of the line.

### 2.6. Text Decoration Shorthand: the [text-decoration property]
Name:

[text-decoration]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'text-decoration-line\'\>](#propdef-text-decoration-line)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<\'text-decoration-thickness\'\>](#propdef-text-decoration-thickness) [\|\|]
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
[text-decoration-thickness](#propdef-text-decoration-thickness),
[text-decoration-style](#propdef-text-decoration-style), and
[text-decoration-color](#propdef-text-decoration-color) in one declaration. Omitted values
are set to their initial values.

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

### 2.7. Text Underline Position: the [text-underline-position property]
Name:

[text-underline-position]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[ from-font [\|] under \]
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) \[ left [\|] right \]

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

This property, which is *not* a
[sub-property](https://drafts.csswg.org/css-cascade-5/#longhand) of the
[text-decoration](#propdef-text-decoration) shorthand, sets the position of an
underline with respect to the text, and defines its [zero
position](#underline-zero-position) for further adjustment by
[text-underline-offset](#propdef-text-underline-offset). It affects all decorations
originating from this element, even if descendant boxes specify a
different position. It does not affect underlines specified by ancestor
elements.

The following example styles modern
Chinese, Japanese, and Korean texts with the appropriate underline
positions in both horizontal and vertical text:

 :root:lang(ja), [lang|=ja], :root:lang(ko), [lang|=ko] { text-underline-position: under right; }
 :root:lang(zh), [lang|=zh] { text-underline-position: under left; }

If [left](#underline-left) or [right](#underline-right) is specified alone,
[auto](#underline-auto)
is also implied. Values have the following meanings:

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

[from-font]
: If the [first available
 font](https://drafts.csswg.org/css-fonts-4/#first-available-font) has metrics indicating a preferred underline
 offset, use that offset, otherwise behaves as
 [auto](#valdef-text-underline-offset-auto).

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

### 2.8. Text Underline Offset: the [text-underline-offset property]
Name:

[text-underline-offset]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, with
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values computed

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

This property, which is *not* a
[sub-property](https://drafts.csswg.org/css-cascade-5/#longhand) of the
[text-decoration](#propdef-text-decoration) shorthand, sets the offset of
underlines from their [zero
position](#underline-zero-position). Positive offsets represent distances outward from the
text; negative offsets inward. It affects all decorations originating
from this element, even if descendant boxes specify a different
position. It does not affect underlines specified by ancestor elements.

Values have the following meanings:

[auto]

: The UA chooses an appropriate offset for underlines.

 However, this offset must be zero if the computed value of
 [text-underline-position](#propdef-text-underline-position) is
 [from-font](#valdef-text-underline-position-from-font) and the UA was able to extract an
 appropriate metric to use from the font.

[[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)]

: A length value specifies the offset of underlines as a fixed length.

 A length will inherit as a fixed value, and will
 not scale with the font.

 A percentage value specifies the offset of underlines as a
 percentage of the used
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size).

 A percentage will inherit as a relative value, and
 will therefore scale with changes in the font as it inherits.

When the value of the
[text-decoration-line](#propdef-text-decoration-line) property is either
[spelling-error](#valdef-text-decoration-line-spelling-error) or
[grammar-error](#valdef-text-decoration-line-grammar-error), the UA must ignore the value of
[text-underline-position](#propdef-text-underline-position).

#### 2.8.1. Underline Offset Origin (Zero Position)

The [zero position] of the underline depends on the value of
[text-underline-position](#propdef-text-underline-position) as detailed below.

Interaction of
[text-underline-position](#propdef-text-underline-position) and
[text-underline-offset](#propdef-text-underline-offset)

[text-underline-position](#propdef-text-underline-position)

Zero Position

Positive Direction

[auto](#underline-auto)

alphabetic baseline

[under](https://drafts.csswg.org/css-writing-modes-4/#under)

[from-font](#valdef-text-underline-position-from-font)

position specified by the font metrics, falling back to alphabetic
baseline

[under](https://drafts.csswg.org/css-writing-modes-4/#under)

[under](#underline-under)

text-under edge

[under](https://drafts.csswg.org/css-writing-modes-4/#under)

[left](#underline-left)

text-under (left) edge

[under](https://drafts.csswg.org/css-writing-modes-4/#under)

[right](#underline-right)

text-over (right) edge

[over](https://drafts.csswg.org/css-writing-modes-4/#over)

The underline is aligned to the outside of the specified position
(extending its thickness in the positive direction only).

Any automatic adjustments made to accommodate descendant content are
maintained; the
[text-underline-offset](#propdef-text-underline-offset) is in addition to those.

#### 2.8.2. Using Font Metrics for Automatic Positioning

Some font formats (such as OpenType) can offer information about the
appropriate position of a line decoration. The UA should use such
font-based information in its choice of
[auto](#valdef-text-underline-offset-auto) offset wherever appropriate, and must use such
information when
[from-font](#valdef-text-underline-position-from-font) is specified for
[text-underline-position](#propdef-text-underline-position).

 Typically, OpenType font metrics give the position of
an [alphabetic] underline; in some cases (especially in CJK
fonts), it gives the position of a [under left] underline. (In
this case, the font's underline metrics typically touch the bottom edge
of the em box). The UA may but is not required to correct for incorrect
font metrics.

### 2.9. Text Decoration Line Uniformity

The exact position and thickness of line decorations depends on the
values of
[text-underline-position](#propdef-text-underline-position),
[text-underline-offset](#propdef-text-underline-offset), and
[text-decoration-thickness](#propdef-text-decoration-thickness) as defined above, and is otherwise
UA-defined. However, for underlines and overlines the UA must use a
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
styled (even though it *may* adjust the position to accommodate
descendants that are not so styled, such as those merely typeset in a
different font size as noted above). This allows superscripts and
subscripts to be properly decorated (underlined, struck through, etc.)
but prevents them from distorting or breaking the positioning of such
decorations on their ancestors.

![An underline for just the superscript \'st\' in \'1st\' is drawn just
below the superscript, whereas an underline for the entire text is drawn
at the appropriate position for full-size
text.](images/underline-superscript.png){height="38" width="80"}

Example of underline applied to [superscripted text]
vs. underline applied to [text containing a superscript]

#### 2.9.1. Trimming, Expanding, and Shifting Text Decoration Lines: the [text-decoration-inset property]
Name:

[text-decoration-inset]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)[{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)
[\|](https://drafts.csswg.org/css-values-4/#comb-one) auto

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

Depending on the value of
[box-decoration-break](https://drafts.csswg.org/css-break-4/#propdef-box-decoration-break), either refer to the inline size of
the [decorating box](#decorating-box) or of each individual [box
fragment](https://drafts.csswg.org/css-break-4/#box-fragment)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword or absolute length

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

This property adjusts the start and end endpoints of line decorations.
Positive values move an endpoint inward, trimming the decoration;
negative values move it outward, extending the decoration.

It controls all text decoration lines drawn by this [decorating
box](#decorating-box), but
not any text decoration lines drawn by its ancestors. If two component
values are given, the first applies to the
[start](https://drafts.csswg.org/css-writing-modes-4/#css-start) and the second to the
[end](https://drafts.csswg.org/css-writing-modes-4/#css-end). Values have the following meanings:

[[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)]

: Adjusts the start or end endpoint of the affected line decorations.
 Positive values move the endpoint inward (trimming), negative values
 move it outward (extending).

 Percentage values either refer to the total inline size of the
 [decorating box](#decorating-box), if
 [box-decoration-break](https://drafts.csswg.org/css-break-4/#propdef-box-decoration-break) is set to
 [slice](https://drafts.csswg.org/css-break-4/#valdef-box-decoration-break-slice), or to the inline size of each individual
 [box
 fragment](https://drafts.csswg.org/css-break-4/#box-fragment), if it is set to
 [clone](https://drafts.csswg.org/css-break-4/#valdef-box-decoration-break-clone).

 :::
 (#example-f99f1c9e)
 The following example offsets an extra thick underline 1em endwards
 with respect to the text

 h1 {
 text-decoration: underline 0.3em rgb(36 148 187 / 0.25);
 text-decoration-inset: 1em -1em;
 }
 :::

 :::
 (#example-962d633a)
 In this example, the underline is inset 10% of the inline size of
 the [decorating box](#decorating-box) from the start and end of it.

 h1 {
 text-decoration: underline 0.2em rgb(216 148 23);
 text-decoration-inset: 10%;
 }

 This results in the orange underline being inset by 10 percent from
 the start and end of the headline.

 ![Sample rendering of the underline inset
 example](images/underline-inset-percentage.png){height="253"
 width="499"}
 :::

 :::
 (#example-cc759271)
 In this example, the underline is inset 10% of the inline size of
 each [box
 fragment](https://drafts.csswg.org/css-break-4/#box-fragment) from the end of that fragment.

 h1 {
 text-decoration: underline 0.2em rgb(216 148 23);
 text-decoration-inset: 0 10%;
 box-decoration-break: clone;
 }

 This results in the orange underline of each line being inset by 10
 percent from the end.

 ![Sample rendering of the underline inset
 example](images/underline-inset-percentage-clone.png){height="253"
 width="499"}
 :::

[auto]
: The UA chooses an inset amount that ensures that if two identical
 underlined elements appear side-by-side they do not appear to have a
 single underline. (This is important in Chinese, where underlining
 is a form of punctuation.)
 ::: figure
 ![An underline below a series of Chinese characters has a gap
 between two adjacent underlining
 elements.](images/decoration-skip-inset.png "text-decoration-inset: auto"){height="77"
 width="223"}

 [text-decoration-inset:
 auto](#propdef-text-decoration-inset) for `<u>石井</u><u>艾俐俐</u>`
 :::

The adjustment of the text decoration's endpoints is subject to
[box-decoration-break](https://drafts.csswg.org/css-break-4/#propdef-box-decoration-break):

- for
 [slice](https://drafts.csswg.org/css-break-4/#valdef-box-decoration-break-slice) (the default) endpoint adjustment is only
 applied to the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start) edge of the first fragment and the
 [end](https://drafts.csswg.org/css-writing-modes-4/#css-end) edge of the last fragment, and may accumulate to
 other fragments if the amount of the inset is more than the length of
 the fragment.

- for
 [clone](https://drafts.csswg.org/css-break-4/#valdef-box-decoration-break-clone) endpoint adjustment is applied to each
 fragment independently.

### 2.10. Text Decoration Line Continuity: the [text-decoration-skip shorthand and its sub-properties]
The CSSWG resolved to be split skipping
functionality into individual properties along the lines of
[text-decoration-skip-ink](#propdef-text-decoration-skip-ink), to improve its cascading behavior.
See [discussion](https://github.com/w3c/csswg-drafts/issues/843) and
[resolution](https://lists.w3.org/Archives/Public/www-style/2017Feb/0049.html).
This section is a rough draft and has not yet been vetted by the CSSWG

Name:

[text-decoration-skip]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) auto

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

See individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

See individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

The
[text-decoration-skip](#propdef-text-decoration-skip) property and its sub-properties
([text-decoration-skip-self](#propdef-text-decoration-skip-self),
[text-decoration-skip-box](#propdef-text-decoration-skip-box),
[text-decoration-skip-spaces](#propdef-text-decoration-skip-spaces),
[text-decoration-skip-ink](#propdef-text-decoration-skip-ink)) control interruptions in line
decorations for which the element or an ancestor is the [decorating
box](#decorating-box). The
[none] value sets
all sub-properties to
[none](#valdef-text-decoration-skip-none), and the
[auto] value sets
all sub-properties to their initial values.

Is this
[none](#valdef-text-decoration-skip-none) definition Web-compatible? Do we also need to
add an [ink] value for Web-compat?

Note that these properties inherit and that descendant elements can have
a different setting.

The following addition is made to the default UA stylesheet for HTML:

```
ins, del { text-decoration-skip: none; }
```

When the value of the
[text-decoration-line](#propdef-text-decoration-line) property is either
[spelling-error](#valdef-text-decoration-line-spelling-error) or
[grammar-error](#valdef-text-decoration-line-grammar-error), the UA may ignore any or all of these
properties.

#### 2.10.1. Skipping Spaces: the [text-decoration-skip-self property]
Name:

[text-decoration-skip-self]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) skip-all [\|] \[
skip-underline
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) skip-overline [\|\|]
skip-line-through \] [\|] no-skip

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword(s) except for
[skip-all](#valdef-text-decoration-skip-self-skip-all), see below

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property specifies whether any text decoration lines drawn by its
ancestors are propagated to or drawn across the element. Values have the
following meanings:

[auto]
: Skip this element (its entire margin box) if it is an atomic inline
 (such as an image or inline-block).

[skip-all]
: Skip this element (its entire margin box) unconditionally. Don't
 draw across it, don't propagate to it.

[skip-underline]
: Skip this element (its entire margin box) unconditionally when
 drawing ancestor underlines.

[skip-overline]
: Skip this element (its entire margin box) unconditionally when
 drawing ancestor overlines.

[skip-line-through]
: Skip this element (its entire margin box) unconditionally when
 drawing ancestor line-throughs.

[no-skip]
: Line decorations from ancestor [decorating
 boxes](#decorating-box)
 are applied to this box unconditionally: drawn across it as if it
 were text if it is an [atomic
 inline](https://drafts.csswg.org/css-display-4/#atomic-inline), or propagated to it according to the usual rules
 if it is not.

 The
[no-skip](#valdef-text-decoration-skip-self-no-skip) value is provided to treat images as text when
that is necessary, for example when representing glyphs that are not
encoded in Unicode.

The
[skip-all](#valdef-text-decoration-skip-self-skip-all) keyword
[computes](https://drafts.csswg.org/css-cascade-5/#computed-value) to [skip-underline skip-overline
skip-line-through]. Note, however, that this combination will
[serialize](https://www.w3.org/TR/cssom/#serializing-css-values) as
[skip-all]
(shortest serialization).

#### 2.10.2. Skipping Spaces: the [text-decoration-skip-box property]
Name:

[text-decoration-skip-box]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) all

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

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

The CSSWG resolved to split
[text-decoration-skip](#propdef-text-decoration-skip) into sub-properties, but this value
set has not yet been vetted by the CSSWG.

This property specifies what parts of the element's box area any text
decoration affecting the element must skip over. It controls only text
decoration lines drawn by its ancestors. Values have the following
meanings:

[none]
: Skip nothing: line decorations from ancestor [decorating
 boxes](#decorating-box)
 are drawn from margin edge to margin edge.

[all]

: When drawing text decoration lines applied to an ancestor
 [decorating box](#decorating-box), skip over the box's own margin, border, and
 padding areas and only draw line decorations within its content
 area.

 This value only has an effect for decorations imposed by an
 ancestor; a [decorating
 box](#decorating-box)
 never draws over its own box decoration.

#### 2.10.3. Skipping Spaces: the [text-decoration-skip-spaces property]
Name:

[text-decoration-skip-spaces]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) all [\|] \[ start
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) end \]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

start end

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

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

Should the initial value be
[none](#valdef-text-decoration-skip-spaces-none) for Web-compat? If not, INS and DEL at least
should be assigned
[none] in the UA
default stylesheet. See also [Issue
4653](https://github.com/w3c/csswg-drafts/issues/4653).

This property specifies whether text decoration skips any spaces. It
controls all text decoration lines drawn by the element and also any
text decoration lines drawn by its ancestors. Values have the following
meanings:

[none]
: [Spacers](#spacer) are not skipped.
 They are decorated just like any other character.

[all]
: Skip all [spacers](#spacer) and
 all [word
 separators](https://drafts.csswg.org/css-text-4/#word-separator) plus any adjacent
 [letter-spacing](https://drafts.csswg.org/css-text-4/#propdef-letter-spacing) or
 [word-spacing](https://drafts.csswg.org/css-text-4/#propdef-word-spacing).

[start]
: Skip all [spacers](#spacer), plus
 any adjacent
 [letter-spacing](https://drafts.csswg.org/css-text-4/#propdef-letter-spacing) or
 [word-spacing](https://drafts.csswg.org/css-text-4/#propdef-word-spacing), when located at the start of
 the line.

[end]
: Skip all [spacers](#spacer), plus
 any adjacent
 [letter-spacing](https://drafts.csswg.org/css-text-4/#propdef-letter-spacing) or
 [word-spacing](https://drafts.csswg.org/css-text-4/#propdef-word-spacing), when located at the end of the
 line.

For the purpose of this property, a [spacer] is any [typographic character
unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit) from [Unicode General
Category](https://drafts.csswg.org/css-text-4/#unicode-general-category) `Zs` except U+202F NARROW NO-BREAK SPACE.

#### 2.10.4. Skipping Glyphs: the [text-decoration-skip-ink property]
Name:

[text-decoration-skip-ink]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) none [\|] all

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[auto](#valdef-text-decoration-skip-ink-auto)

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

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

This property controls how overlines and underlines are drawn when they
cross over a glyph. It affects all decorations originating from this
element even if descendant boxes specify a different style.

When enabled, decoration lines skip over where glyphs are drawn:
interrupt the decoration line to let the shape of the text show through
where the text decoration would otherwise cross over a glyph. The UA
must also skip a small distance to either side of the glyph outline.

![An alphabetic underline through Myanmar text skips around descenders
and the vertical strokes of combining characters that drop below the
alphabetic
baseline.](images/decoration-skip-ink.png "Skipping Descenders When Drawing an Underline"){height="77"
width="223"}

Skipping Glyph Ink

Ideographic scripts do not want to skip
when
[auto](#valdef-text-decoration-skip-ink-auto). How can we define this behavior? Are there more
scripts wanting not to skip? Need some normative text describe how
[auto] works. See
[telcon
minutes](https://lists.w3.org/Archives/Public/www-style/2017Feb/0069.html),
[alreq#86](https://github.com/w3c/alreq/issues/86),
[csswg#1288](https://github.com/w3c/csswg-drafts/issues/1288)

This property only applies to overlines and underlines; line-throughs
are always continuous.

[auto]
: UAs *may* interrupt underlines and overlines where the line would
 cross glyph ink and to some distance to either side of the glyph
 outline. UAs *should* consider the script of the text (see note
 below) when determining whether to apply ink-skipping behavior to a
 given range of content.

[all]
: UAs *must* interrupt underlines and overlines where the line would
 cross glyph ink and to some distance to either side of the glyph
 outline.

[none]
: UA *must* draw continuous underlines and overlines, without
 interruptions when they cross over a glyph.

Note: Implementation experience shows that ink-skipping behavior often
produces undesirable results when underlined text includes ideographic
characters, as the underline position (depending on the font and user
agent involved) often clashes with almost all the glyphs, such that only
occasional fragments of the line remain to be rendered.

In principle, this could be resolved by authors using
[text-underline-position:
under](#propdef-text-underline-position) (or possibly
[text-underline-offset](#propdef-text-underline-offset)) to move the underline to a lower
position that does not clash with the glyphs, but this is not always
feasible, even if the user agent supports these properties and the
author is aware of their potential. In particular, when a page contains
arbitrary user-generated content, the author responsible for the design
may not know whether CJK content will be present. And with mixed-script
content, an underline position designed to work well for CJK content may
look bad if the majority of the text is non-CJK.

Therefore, when
[auto](#valdef-text-decoration-skip-ink-auto) is in effect, a UA that implements ink-skipping
*should* refrain from doing so in CJK contexts. (Authors who *do* want
ink-skipping applied to CJK content can use the [always] value to
explicitly request this.)

Primarily, this means *not* applying ink-skipping for characters whose
Unicode [Script
property](http://unicode.org/Public/UCD/latest/ucd/Scripts.txt) is any
of the CJK scripts Han, Hiragana, Katakana, Bopomofo, or Hangul, or for
characters whose Script property is Inherited or Common, and whose
[ScriptExtensions
property](http://unicode.org/Public/UCD/latest/ucd/ScriptExtensions.txt)
includes one or more of the CJK scripts.

In addition, characters with a Unicode script property of Common and
Inherited (primarily generic punctuation and symbols) need to be
considered, as these may be used as part of a run of CJK-script content,
and it is desirable to treat all text within a given script run in a
consistent way. Therefore, the UA *should* resolve the text into script
runs as described in the ["Implementation
Notes"](https://www.unicode.org/reports/tr24/#Usage_Model) of
[\[UAX24\]](#biblio-uax24 "Unicode Script Property")
"Unicode Script Property", in particular subsections 5.1 and 5.2. After
applying the heuristics described there (or a similar analysis of
scripts), the UA *should* disable ink-skipping for all ranges of text
that are determined to be in a CJK script.

Are there other (non-CJK) scripts where
it would be preferable to disable ink-skipping by default (when
[auto](#valdef-text-decoration-skip-ink-auto) is in effect)? Perhaps Yi? Arabic? (See also
discussion in [Issue
1288](https://github.com/w3c/csswg-drafts/issues/1288).)

#### 2.10.5. Shaping Interruptions

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

## 3. Additional Controls for Emphasis Marks

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

See also [issue about continuity in
size/position](https://github.com/w3c/csswg-drafts/issues/1892).

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
 than one [character](#character)
 in \<string\>. The UA may truncate or ignore strings consisting of
 more than one grapheme cluster.

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
 other [characters](#character)
 that belong to the Unicode separator classes (Z\*). (But note that
 emphasis marks *are* drawn for a space that combines with any
 combining characters.)
- Punctuation\--specifically, any
 [characters](#character) that
 belong to the Unicode P\* [general
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
 〽
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
the value of
[color](https://drafts.csswg.org/css-color-4/#propdef-color) after inheritance is performed.
This means
[text-emphasis-color](#propdef-text-emphasis-color) by default matches the text
[color] even as
[color] changes across elements.

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

### 3.5. Emphasis Mark Skip: the [text-emphasis-skip property]
This section is under brainstorming. It's
also not yet clear if this property is needed quite yet, despite
differences in desired behavior among publications.

Name:

[text-emphasis-skip]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

spaces
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) punctuation [\|\|] symbols
[\|\|] narrow

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

spaces punctuation

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text

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

This property describes for which characters marks are drawn. The values
have following meanings:

[spaces]
: Skip [word
 separators](https://www.w3.org/TR/css-text/#word-separator) or other
 [characters](#character)
 belonging to the Unicode separator category (Z\*). (But note that
 emphasis marks *are* drawn for a space that combines with any
 combining characters.)

[punctuation]
: Skip punctuation. Punctuation in this definition includes characters
 belonging to the Unicode P\* category that are not defined as
 [symbols](#valdef-text-emphasis-skip-symbols) (see below).

[symbols]
: Skip symbols. Symbols in this definition includes all [typographic
 character
 units](https://drafts.csswg.org/css-text-4/#typographic-character-unit) belonging to the Unicode S\* [general
 category](https://drafts.csswg.org/css-text-4/#unicode-general-category) as well as any which are `NFKD`-equivalent
 [\[UAX15\]](#biblio-uax15 "Unicode Normalization Forms")
 to the following [characters](#character) from the Unicode Po category:
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

[narrow]
: Skip characters where the `East_Asian_Width` property
 [\[UAX11\]](#biblio-uax11 "East Asian Width") of
 the Unicode database
 [\[UAX44\]](#biblio-uax44 "Unicode Character Database")
 is not F (Fullwidth) or W (Wide).

Characters belonging to the Unicode classes for control codes and
unassigned characters (Cc, Cf, Cn) are skipped regardless of the value
of this property.

This syntax requires UA to implement
drawing marks for spaces. Is there any use case for doing so? If not,
should we modify the syntax not to allow drawing marks for spaces?

See also [discussion of the initial
value](https://github.com/w3c/csswg-drafts/issues/839).

## 4. Text Shadows: the [text-shadow property]
Name:

[text-shadow]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<shadow\>](https://drafts.csswg.org/css-backgrounds-3/#typedef-shadow)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

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
[none](https://drafts.csswg.org/css-backgrounds-3/#box-shadow-none) or a list, each item consisting of four absolute
lengths plus a computed color and optionally also an [inset]
keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

[as shadow
list](https://www.w3.org/TR/web-animations-1/#animating-shadow-lists)

This property accepts a comma-separated list of shadow effects to be
applied to the text of the element. Values are interpreted as for
[box-shadow](https://drafts.csswg.org/css-backgrounds-3/#propdef-box-shadow)
[\[CSS-BACKGROUNDS-3\]](#biblio-css-backgrounds-3 "CSS Backgrounds and Borders Module Level 3").
Each layer shadows the element's text and all its text decorations
(composited together). The shadow effects are applied front-to-back: the
first shadow is on top. The shadows may thus overlay each other.

Unlike
[box-shadow](https://drafts.csswg.org/css-backgrounds-3/#propdef-box-shadow), the [spread
distance](https://drafts.csswg.org/css-backgrounds-3/#box-shadow-spread-distance) is strictly interpreted as outset distance from any
point of the glyph outline, and therefore, similar to the blur radius,
creates rounded, rather than sharp, corners. Negative spread values are
invalid.

Leave corner shaping undefined? [\[Issue
#7250\]](https://github.com/w3c/csswg-drafts/issues/7250)

[Outer text shadows] (specified without the [inset]
keyword) shadow the text---​including any text stroke
[\[FILL-STROKE-3\]](#biblio-fill-stroke-3 "CSS Fill and Stroke Module Level 3")---​as
if it were cut and raised above the surrounding canvas. Unlike
[box-shadow](https://drafts.csswg.org/css-backgrounds-3/#propdef-box-shadow), outer text shadows are not clipped
to the shadowed shape and may show through if the text is
partially-transparent.

[Inner text shadows] (specified with the [inset] keyword)
shadow the canvas---​and any text stroke
[\[FILL-STROKE-3\]](#biblio-fill-stroke-3 "CSS Fill and Stroke Module Level 3")---​as
if the text were cut and dropped below the surrounding canvas. They are
therefore only drawn within the inner edge of the stroke.

[Outer text shadows](#outer-text-shadows) must be painted at a stack level between the element's
border/background (if present) and the elements text and text
decoration. [Inner text
shadows](#inner-text-shadows) must be painted over the text and its decorations. UAs
should avoid painting text shadows over text in adjacent elements
belonging to the same stack level and stacking context. (This may mean
that the exact stack level of the shadows depends on whether the element
has a border or background: the exact stacking behavior of text shadows
is thus UA-defined.)

Stacking relationship to stroke?
[\[Issue #7251\]](https://github.com/w3c/csswg-drafts/issues/7251)

Like
[box-shadow](https://drafts.csswg.org/css-backgrounds-3/#propdef-box-shadow), text shadows do not influence
layout, and do not trigger scrolling or increase the size of the
[scrollable overflow
region](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region).

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
region](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region).
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
### [ Changes since the 4 May 2022 Working Draft]
Significant changes since the [4 May 2022 Working
Draft](https://www.w3.org/TR/2022/WD-css-text-decor-4-20220504/):

- Redesigned
 [text-decoration-skip-self](#propdef-text-decoration-skip-self). ([Issue
 2885](https://github.com/w3c/csswg-drafts/issues/2885))
- Replaced [text-decoration-skip-edges] with
 [text-decoration-inset](#propdef-text-decoration-inset). ([Issue
 4557](https://github.com/w3c/csswg-drafts/issues/4557))
- Redefined [spacers](#spacer) for
 [text-decoration-skip-spaces](#propdef-text-decoration-skip-spaces) to reference [Unicode General
 Category](https://drafts.csswg.org/css-text-4/#unicode-general-category) `Zs` and to only additionally include word separators
 when skipping all spaces. ([Issue
 5249](https://github.com/w3c/csswg-drafts/issues/5249))
- Disallowed
 [grammar-error](#valdef-text-decoration-line-grammar-error) and
 [spelling-error](#valdef-text-decoration-line-spelling-error) from being influenced by the other
 [sub-properties](https://drafts.csswg.org/css-cascade-5/#longhand) of
 [text-decoration](#propdef-text-decoration), as well any other properties
 typically affecting the appearance of line decorations.
- Fixed errors in Computed Value lines. ([Issue
 10044](https://github.com/w3c/csswg-drafts/issues/10044))
- Miscellaneous minor clarifications.

### [ Changes since the 6 May 2020 Working Draft]
Significant changes since the [6 May 2020 Working
Draft](https://www.w3.org/TR/2020/WD-css-text-decor-4-20200506/):

- Added [spread
 distance](https://drafts.csswg.org/css-backgrounds-3/#box-shadow-spread-distance) and [inset] to
 [text-shadow](#propdef-text-shadow). ([Issue
 6074](https://github.com/w3c/csswg-drafts/issues/6074), [Issue
 6971](https://github.com/w3c/csswg-drafts/issues/6971))
- Clarified that
 [text-decoration-skip-ink](#propdef-text-decoration-skip-ink) affects only decorations
 initiated by the element. ([Issue
 2817](https://github.com/w3c/csswg-drafts/issues/2817))
- Explicitly noted properties applying to text in "Applies to" line.
 ([Issue 5303](https://github.com/w3c/csswg-drafts/issues/5303))

### [ Additions Since Level 3]
The following features have been added since [Level
3](https://www.w3.org/TR/css-text-decor-3/):

- Added
 [spelling-error](#valdef-text-decoration-line-spelling-error) and
 [grammar-error](#valdef-text-decoration-line-grammar-error) values to
 [text-decoration-line](#propdef-text-decoration-line).
- Added
 [text-decoration-thickness](#propdef-text-decoration-thickness) and
 [text-underline-offset](#propdef-text-underline-offset) properties.
- Added
 [from-font](#valdef-text-underline-position-from-font) value to
 [text-underline-position](#propdef-text-underline-position).
- Drafted
 [text-decoration-skip](#propdef-text-decoration-skip) property and its longhands.
- Drafted
 [text-emphasis-skip](#propdef-text-emphasis-skip) property.
- Added [spread
 distance](https://drafts.csswg.org/css-backgrounds-3/#box-shadow-spread-distance) and [inset] to
 [text-shadow](#propdef-text-shadow).

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.
