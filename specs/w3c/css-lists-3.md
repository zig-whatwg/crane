## 1. Introduction

This specification defines the
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-element, the
[list-item](#valdef-counter-increment-list-item) [display
type](https://drafts.csswg.org/css-display-4/#display-type) that generates markers, and several properties
controlling the placement and styling of markers.

It also defines [counters](#counter),
which are special numerical objects often used to generate the default
contents of markers.

For instance, the following example
illustrates how markers can be used to add parentheses around each
numbered list item:

``` highlight
<style>
li::marker { content: "(" counter(list-item, lower-roman) ")"; }
li { display: list-item; }
</style>
<ol>
 <li>This is the first item.
 <li>This is the second item.
 <li>This is the third item.
</ol>
```

It should produce something like this:

 (i) This is the first item.
 (ii) This is the second item.
 (iii) This is the third item.

 Note that this example is far more verbose than is
usually needed in HTML, as the UA default style sheet takes care of most
of the necessary styling.

With descendant selectors and child selectors, it's possible to specify
different marker types depending on the depth of embedded lists.

### 1.1. Value Definitions

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

## 2. Declaring a List Item

A [list item] is
any element with its
[display](https://drafts.csswg.org/css-display-4/#propdef-display) property set to
[list-item](https://drafts.csswg.org/css-display-4/#valdef-display-list-item). [List items](#list-item) generate
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-elements; no other elements do.
Additionally, [list items] automatically increment
an implied
[list-item](#valdef-counter-increment-list-item) [counter](#counter) (see [§ 4.6 The Implicit list-item
Counter](#list-item-counter)).

## 3. Markers

The defining feature of the [list item](#list-item) [display
type](https://drafts.csswg.org/css-display-4/#display-type) is its [marker], a symbol or ordinal
that helps denote the beginning of each [list item]
in a list. In the CSS layout model, [list item]
[markers](#marker) are represented by a
[marker box] associated with each [list
item]. The contents of this
[marker] can be controlled with the
[list-style-type](#propdef-list-style-type) and
[list-style-image](#propdef-list-style-image) properties on the [list
item] and by assigning properties to its
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-element.

### [3.1. ][ The [::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) Pseudo-Element]
The [marker box](#marker) is generated
by the
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-element of a [list
item](#list-item) as the [list
item's] first child, before the
[::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) pseudo-element (if it exists on the element). It
is filled with content as defined in [§ 3.2 Generating Marker
Contents](#content-property).

In this example, markers are used to
number paragraphs that are designated as \"notes\":

``` highlight
<style>
p { margin-left: 12 em; }
p.note {
 display: list-item;
 counter-increment: note-counter;
}
p.note::marker {
 content: "Note " counter(note-counter) ":";
}
</style>
<p>This is the first paragraph in this document.
<p class="note">This is a very short document.
<p>This is the end.
```

It should render something like this:

 This is the first paragraph
 in this document.

 Note 1: This is a very short
 document.

 This is the end.

By using the
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-element, a list's markers can be styled
independently from the text of the list item itself:

``` highlight
<style>
p { margin-left: 8em } /* Make space for counters */
li { list-style-type: lower-roman; }
li::marker { color: blue; font-weight:bold; }
</style>
<p>This is a long preceding paragraph ...
<ol>
 <li>This is the first item.
 <li>This is the second item.
 <li>This is the third item.
</ol>
<p>This is a long following paragraph ...
```

The preceding document should render something like this:

 This is a long preceding
 paragraph ...

 i. This is the first item.
 ii. This is the second item.
 iii. This is the third item.

 This is a long following
 paragraph ...

Previously the only way to style a marker was through inheritance; one
had to put the desired marker styling on the list item, and then revert
that on a wrapper element around the list item's actual contents.

[Marker boxes](#marker) only exist for
[list items](#list-item): on any
other element, the
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-element's
[content](https://drafts.csswg.org/css-content-3/#propdef-content) property must compute to
[none](https://drafts.csswg.org/css-content-3/#valdef-content-none), which suppresses its creation.

#### [3.1.1. ][ Properties Applying to [::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker)]
All properties can be set on a
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-element and will have a [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) which will then inherit to its text content.

Inheritable properties that apply to
text can be set on the
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-element: these will inherit to and take
effect on its text contents. Some examples of such properties include:

- [text-transform](https://drafts.csswg.org/css-text-4/#propdef-text-transform),
 [letter-spacing](https://drafts.csswg.org/css-text-4/#propdef-letter-spacing),
 [word-spacing](https://drafts.csswg.org/css-text-4/#propdef-word-spacing) (see
 [\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3"))
- all the font properties (see
 [\[CSS-FONTS-3\]](#biblio-css-fonts-3 "CSS Fonts Module Level 3")
 and its successors)
- the
 [color](https://drafts.csswg.org/css-color-4/#propdef-color) property (see
 [\[CSS-COLOR-3\]](#biblio-css-color-3 "CSS Color Module Level 3"))

However, only the following CSS properties actually apply to a [marker
box](#marker):

- the
 [text-combine-upright](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-combine-upright),
 [unicode-bidi](https://drafts.csswg.org/css-writing-modes-3/#propdef-unicode-bidi), and
 [direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) properties (see
 [\[CSS-WRITING-MODES-3\]](#biblio-css-writing-modes-3 "CSS Writing Modes Level 3"))
- the
 [content](https://drafts.csswg.org/css-content-3/#propdef-content) property (see [§ 3.2 Generating
 Marker Contents](#content-property), below)
- all animation and transition properties (see
 [\[CSS-ANIMATIONS-1\]](#biblio-css-animations-1 "CSS Animations Level 1")
 and
 [\[CSS-TRANSITIONS-1\]](#biblio-css-transitions-1 "CSS Transitions Module Level 1"))

Other properties should not have an effect on the [marker
box](#marker) when declared directly
on
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) in the
[author](https://drafts.csswg.org/css-cascade-5/#cascade-origin-author) or [user
origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-user) of the
[cascade](https://drafts.csswg.org/css-cascade-6/#cascade). UAs may either treat such properties as not applying,
or enforce their value or inheritance from the [originating
element](https://drafts.csswg.org/selectors-4/#originating-element) by setting a [user-agent
origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-ua) [!important] rule.

[NOTE:] It is expected that future specifications will extend
this list of properties and relax the restriction on which properties
can take effect. However at the moment outside marker box layout is not
fully defined, so to avoid future compatibility problems only these
properties are allowed.

Additionally, UAs must add the following rule to their default style
sheet:

 ::marker, ::before::marker, ::after::marker {
 unicode-bidi: isolate;
 font-variant-numeric: tabular-nums;
 white-space: pre;
 text-transform: none;
 }

[white-space:
pre](https://drafts.csswg.org/css-text-4/#propdef-white-space) doesn't have quite the right behavior;
[white-space-collapse:
preserve-spaces](https://drafts.csswg.org/css-text-4/#propdef-white-space-collapse) + [white-space-trim:
discard-after](https://drafts.csswg.org/css-text-4/#propdef-white-space-trim) might be closer to what's needed here. See
discussion in [Issue
4448](https://github.com/w3c/csswg-drafts/issues/4448) and [Issue
4891](https://github.com/w3c/csswg-drafts/issues/4891).

 Although the
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-element can represent the [marker
box](#marker) of a
[::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) or
[::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after) pseudo-element, the [compound
selector](https://drafts.csswg.org/selectors-4/#compound) [::marker], which
expands to [\*::marker]
[\[SELECTORS-4\]](#biblio-selectors-4 "Selectors Level 4"),
will not select these markers---​an [originating
element](https://drafts.csswg.org/selectors-4/#originating-element) that is a
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) needs to be explicitly specified in the
[selector](https://drafts.csswg.org/selectors-4/#selector), e.g. [::before::marker].

### 3.2. Generating Marker Contents

The contents of a [marker box](#marker) are determined by the first of these conditions that is
true:

[content](https://drafts.csswg.org/css-content-3/#propdef-content) on the [::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) itself is not [normal](https://drafts.csswg.org/css-content-3/#valdef-content-normal)
: The contents of the [marker box](#marker) are determined as defined by the
 [content](https://drafts.csswg.org/css-content-3/#propdef-content) property, exactly as for
 [::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before).

[list-style-image](#propdef-list-style-image) on the [originating element](https://drafts.csswg.org/selectors-4/#originating-element) defines a [marker image](#marker-image)
: The [marker box](#marker)
 contains an
 [anonymous](https://drafts.csswg.org/css-display-4/#anonymous)
 [inline](https://drafts.csswg.org/css-display-4/#inline) [replaced
 element](https://drafts.csswg.org/css-display-4/#replaced-element) representing the specified [marker
 image](#marker-image),
 followed by a [text
 sequence](https://drafts.csswg.org/css-display-4/#css-text-sequence) consisting of a single space (U+0020 SPACE).

[list-style-type](#propdef-list-style-type) on the [originating element](https://drafts.csswg.org/selectors-4/#originating-element) defines a [marker string](#marker-string)
: The [marker box](#marker)
 contains a [text
 sequence](https://drafts.csswg.org/css-display-4/#css-text-sequence) consisting of the specified [marker
 string](#marker-string).

otherwise
: The [marker box](#marker) has no
 contents and
 [::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) does not generate a box.

Additionally, the UA may transform into spaces or discard any preserved
[forced line
breaks](https://drafts.csswg.org/css-text-4/#forced-line-break).

### 3.3. Image Markers: the [list-style-image property]
Name:

[list-style-image]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image)
[\|](https://drafts.csswg.org/css-values-4/#comb-one) none

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[list items](#list-item)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[none](#valdef-list-style-image-none)or the computed
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Specifies the [marker image], which is used to fill the [list
item's](#list-item)
[marker](#marker) when its
[content](https://drafts.csswg.org/css-content-3/#propdef-content) is
[normal](https://drafts.csswg.org/css-content-3/#valdef-content-normal). The values are as follows:

[[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image)]
: If the
 [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) represents a [valid
 image](https://drafts.csswg.org/css-images-4/#invalid-image), specifies the element's [marker
 image](#marker-image) as the
 [\<image\>]. Otherwise, the
 element has no [marker image].

[none]
: The element has no [marker
 image](#marker-image).

The [marker image](#marker-image) is sized using the [default sizing
algorithm](https://drafts.csswg.org/css-images-3/#default-sizing-algorithm)
[\[css-images-3\]](#biblio-css-images-3 "CSS Images Module Level 3")
with no [specified
size](https://drafts.csswg.org/css-images-3/#specified-size) and a [default object
size](https://drafts.csswg.org/css-images-3/#default-object-size) of 1em square.

The following example sets the marker
at the beginning of each list item to be the image \"ellipse.png\".

``` highlight
li { list-style-image: url("http://www.example.com/ellipse.png") }
```

### 3.4. Text-based Markers: the [list-style-type property]
Name:

[list-style-type]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<counter-style\>](https://drafts.csswg.org/css-counter-styles-3/#typedef-counter-style)
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value) [\|] none

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

disc

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[list items](#list-item)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Specifies the [marker string], which is used to fill the [list
item](#list-item)'s
[marker](#marker) when its
[content](https://drafts.csswg.org/css-content-3/#propdef-content) value is
[normal](https://drafts.csswg.org/css-content-3/#valdef-content-normal) and there is no [marker
image](#marker-image). The
values are as follows:

[[\<counter-style\>](https://drafts.csswg.org/css-counter-styles-3/#typedef-counter-style)]

: Specifies the element's [marker
 string](#marker-string) as
 the value of the
 [list-item](#valdef-counter-increment-list-item) counter represented using the specified
 [\<counter-style\>](https://drafts.csswg.org/css-counter-styles-3/#typedef-counter-style).

 Specifically, the [marker
 string](#marker-string) is
 the result of [generating a counter
 representation](https://drafts.csswg.org/css-counter-styles-3/#generate-a-counter) of the
 [list-item](#valdef-counter-increment-list-item) counter value using the specified
 [\<counter-style\>](https://drafts.csswg.org/css-counter-styles-3/#typedef-counter-style), prefixed by the
 [prefix](https://drafts.csswg.org/css-counter-styles-3/#descdef-counter-style-prefix) of the
 [\<counter-style\>],
 and followed by the
 [suffix](https://drafts.csswg.org/css-counter-styles-3/#descdef-counter-style-suffix) of the
 [\<counter-style\>]. If
 the specified [\<counter-style\>] does not exist,
 [decimal](https://drafts.csswg.org/css-counter-styles-3/#decimal) is assumed.

[[\<string\>](https://drafts.csswg.org/css-values-4/#string-value)]
: The element's [marker
 string](#marker-string) is
 the specified
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value).

[none]
: The element has no [marker
 string](#marker-string).

The following examples illustrate how
to set markers to various values:

``` highlight
ul { list-style-type: "★"; }
/* Sets the marker to a "star" character */

p.note {
 display: list-item;
 list-style-type: "Note: ";
 list-style-position: inside;
}
/* Gives note paragraphs a marker consisting of the string "Note: " */

ol { list-style-type: upper-roman; }
/* Sets all ordered lists to use the upper-roman counter-style
 (defined in the Counter Styles specification [[CSS-COUNTER-STYLES]]) */

ul { list-style-type: symbols(cyclic '○' '●'); }
/* Sets all unordered list items to alternate between empty and
 filled circles for their markers. */

ul { list-style-type: none; }
/* Suppresses the marker entirely, unless list-style-image is specified
 with a valid image. */
```

### 3.5. Positioning Markers: The [list-style-position property]
Name:

[list-style-position]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

inside
[\|](https://drafts.csswg.org/css-values-4/#comb-one) outside

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

outside

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[list items](#list-item)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

keyword, but see prose

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property dictates whether the
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) is rendered inline, or positioned just outside
of the [list item](#list-item).
The values are as follows:

[inside]
: No special effect. (The
 [::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) is an inline element at the start of the
 [list item's](#list-item)
 contents.)

[outside]

: If the [list item](#list-item)
 is a [block
 container](https://drafts.csswg.org/css-display-4/#block-container): the marker box is a [block
 container] and is placed outside the
 [principal block
 box](https://drafts.csswg.org/css-display-4/#principal-box); however, the position of the list-item marker
 adjacent to floats is undefined. CSS does not specify the precise
 location of the marker box or its position in the painting order,
 but does require that it be placed on the
 [inline-start](https://drafts.csswg.org/css-writing-modes-4/#inline-start) side of the box, using the [writing
 mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the box indicated by
 [marker-side](#propdef-marker-side). The marker box is fixed with
 respect to the principal block box's border and does not scroll with
 the principal box's content. A UA may hide the marker if the
 element's
 [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) is other than
 [visible](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-visible). (This allowance may change in the future.)
 The size or contents of the marker box may affect the height of the
 principal block box and/or the height of its first line box, and in
 some cases may cause the creation of a new line box; this
 interaction is also not defined.

 (#issue-ffa70ac6) This is handwavey nonsense from
 CSS2, and needs a real definition.

 If the [list item](#list-item)
 is an [inline
 box](https://drafts.csswg.org/css-display-4/#inline-box): this value is equivalent to
 [inside](#valdef-list-style-position-inside).

 (#issue-bf311ada) Alternatively,
 [outside](#list-style-position-outside) could lay out the marker as a previous
 sibling of the principal inline box.

For example:

 <style>
 ul.compact { list-style: inside; }
 ul { list-style: outside; }
 </style>
 <ul class=compact>
 <li>first "inside" list item comes first</li>
 <li>second "inside" list item comes first</li>
 </ul>
 <hr>
 <ul>
 <li>first "outside" list item comes first</li>
 <li>second "outside" list item comes first</li>
 </ul>

The above example may be formatted as:

 * first "inside" list
 item comes first
 * second "inside" list
 item comes second

 ========================

 * first "outside" list
 item comes first
 * second "outside" list
 item comes second

### 3.6. Styling Markers: the [list-style shorthand property]
Name:

[list-style]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'list-style-position\'\>](#propdef-list-style-position)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<\'list-style-image\'\>](#propdef-list-style-image) [\|\|]
[\<\'list-style-type\'\>](#propdef-list-style-type)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[list items](#list-item)

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

The [list-style](#propdef-list-style) property is a shorthand notation for
setting the three properties
[list-style-type](#propdef-list-style-type),
[list-style-image](#propdef-list-style-image), and
[list-style-position](#propdef-list-style-position) at the same place in the style
sheet.

For example:

``` highlight
ul { list-style: upper-roman inside } /* Any UL */
ul ul { list-style: circle outside } /* Any UL child of a UL */
```

Using a value of [none] in the shorthand is potentially ambiguous,
as [none] is a valid value for both
[list-style-image](#propdef-list-style-image) and
[list-style-type](#propdef-list-style-type). To resolve this ambiguity, a value
of [none] in the shorthand must be applied to whichever of the two
properties aren't otherwise set by the shorthand.

``` highlight
list-style: none disc;
/* Sets the image to "none" and the type to "disc". */

list-style: none url(bullet.png);
/* Sets the image to "url(bullet.png)" and the type to "none". */

list-style: none;
/* Sets both image and type to "none". */

list-style: none disc url(bullet.png);
/* Syntax error */
```

[\<counter-style\>](https://drafts.csswg.org/css-counter-styles-3/#typedef-counter-style) values of
[list-style-type](#propdef-list-style-type) can also create grammatical
ambiguities. As such values are ultimately
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) values, the parsing rules in
[\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3")
apply.

Although authors may specify
[list-style](#propdef-list-style) information directly on list item
elements (e.g.,
[`li`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-li-element) in HTML), they should do so with care. Consider the
following rules:

``` highlight
ol.alpha li { list-style: lower-alpha; }
ul li { list-style: disc; }
```

The above won't work as expected. If you nest a
[`ul`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-ul-element) into an [ol
class=alpha](https://html.spec.whatwg.org/multipage/grouping-content.html#the-ol-element), the first rule's specificity will make the
[`ul`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-ul-element)'s list items use the lower-alpha style.

``` highlight
ol.alpha > li { list-style: lower-alpha; }
ul > li { list-style: disc; }
```

These work as intended.

``` highlight
ol.alpha { list-style: lower-alpha; }
ul { list-style: disc; }
```

These are even better, since inheritance will transfer the
[list-style](#propdef-list-style) value to the list items.

### 3.7. The [marker-side property]
Name:

[marker-side]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

match-self
[\|](https://drafts.csswg.org/css-values-4/#comb-one) match-parent

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

match-self

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[list items](#list-item)

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

The [marker-side](#propdef-marker-side) property specifies whether an
[outside](#list-style-position-outside) [marker box](#marker) is positioned based on the directionality of the list
item itself (i.e. its [originating
element](https://drafts.csswg.org/selectors-4/#originating-element)) or the directionality of the list container (i.e. the
[originating element]'s parent). In the
first case, the position of the marker can vary across items in the same
list, based on the directionality assigned to each list item
individually; in the second case they will all align on the same side,
as determined by the directionality assigned to the list as a whole.

[match-self]
: The [marker box](#marker) is
 positioned using the directionality of the
 [::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker)'s [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element).

[match-parent]
: The [marker box](#marker) is
 positioned using the directionality of the
 [::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker)'s [originating
 element's](https://drafts.csswg.org/selectors-4/#originating-element) parent element.

By default, elements or
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-elements position themselves according to
their list item's directionality. However, if the list item is grouped
with several other list items which may have different directionality
(for example, multiple \<li\>s with different \"dir\" attributes in an
\<ol\> in HTML), it is sometimes more useful to have all the markers
line up on one side, so the author can specify a single \"gutter\" on
that side and be assured that all the markers will lie in that gutter
and be visible.

Both of the following example renderings are generated from the
following HTML, with the only difference being the value of
[marker-side](#propdef-marker-side) on the list:

``` highlight
<ul>
 <li>english one
 <li dir=rtl>OWT WERBEH
 <li>english three
 <li dir=rtl>RUOF WERBEH
</ul>
```

[match-self](#valdef-marker-side-match-self)

[match-parent](#valdef-marker-side-match-parent)

 * english one
 OWT WERBEH *
 * english three
 RUOF WERBEH *

 * english one
 * OWT WERBEH
 * english three
 * RUOF WERBEH

For this order punctuation inside the
marker correctly, it would also need to take the
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) value of the parent. [\[Issue
#4202\]](https://github.com/w3c/csswg-drafts/issues/4202)

There are issues open on [renaming the
keywords](https://github.com/w3c/csswg-drafts/issues/5308) and on
[merging with
[list-style-position]](https://github.com/w3c/csswg-drafts/issues/4209).

## 4. Automatic Numbering With Counters

A [counter] is a
special numeric tracker used, among other things, to automatically
number list items in CSS. Every element has a collection of zero or more
counters, which are inherited through the document tree in a way similar
to inherited property values. [Counters](#counter) have a [name] and
[creator], which identify the counter, a boolean
[reversed] (false by default), and an integer
[value] (optional when the counter is
[reversed](#css-counter-reversed)). They are created and manipulated with the [counter
properties]
[counter-increment](#propdef-counter-increment),
[counter-set](#propdef-counter-set) and
[counter-reset](#propdef-counter-reset), and used with the
[counter()](#funcdef-counter) and
[counters()](#funcdef-counters) [functional
notations](https://drafts.csswg.org/css-values-4/#functional-notation).

Counters are referred to in CSS syntax using the
[[\<counter-name\>](#typedef-counter-name)] type, which represents their
name as a
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value). A
[\<counter-name\>](#typedef-counter-name) name cannot match the keyword
[none](#valdef-counter-reset-none); such an identifier is
[invalid](https://drafts.csswg.org/css-syntax-3/#css-invalid) as a [\<counter-name\>].

A [reversed](#css-counter-reversed) counter is created with the [reversed()]
[functional
notation](https://drafts.csswg.org/css-values-4/#functional-notation), which is defined as follows:

``` prod
<reversed-counter-name> = reversed( <counter-name> )
```

Resolving [counter](#counter) values
on a given element is a multi-step process:

1. Existing counters are
 [inherited](#inherit-counters) from previous elements.

2. New counters are
 [instantiated](#instantiate-counter)
 ([counter-reset](#propdef-counter-reset)).

3. Counter values are incremented
 ([counter-increment](#propdef-counter-increment)).

4. Counter values are explicitly set
 ([counter-set](#propdef-counter-set)).

5. Counter values are used
 ([counter()](#funcdef-counter)/[counters()](#funcdef-counters)).

UAs may have implementation-specific limits on the maximum or minimum
value of a counter. If a counter reset, set, or increment would push the
value outside of that range, the value must be clamped to that range.

### 4.1. Creating Counters: the [counter-reset property]
Name:

[counter-reset]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[
[\<counter-name\>](#typedef-counter-name)
[\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value)[?](https://drafts.csswg.org/css-values-4/#mult-opt)
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<reversed-counter-name\>](#typedef-reversed-counter-name) [\<integer\>][?]
\][+](https://drafts.csswg.org/css-values-4/#mult-one-plus) [\|] none

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[none](#valdef-counter-reset-none) or a list, each item an identifier or a
[reversed()] function paired with an integer

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

User agents are expected to support this property on all media,
including non-visual ones.

The
[counter-reset](#propdef-counter-reset) property
[instantiates](#instantiate-counter) new [counters](#counter) on an element and sets them to the specified integer
values. Its values are defined as follows:

[none]
: This element does not create any new counters.

[[\<counter-name\>](#typedef-counter-name) [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value)?]
: [Instantiates](#instantiate-counter) a counter of the given
 [\<counter-name\>](#typedef-counter-name) with a starting value of the
 given
 [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value), defaulting to [0].

[[\<reversed-counter-name\>](#typedef-reversed-counter-name) [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value)?]
: [Instantiates](#instantiate-counter) a
 [reversed](#css-counter-reversed) counter of the given
 [\<counter-name\>](#typedef-counter-name) with a starting value of the
 given
 [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value), or no starting value if not
 given.

Note that counter properties follow
the
[cascading](https://drafts.csswg.org/css-cascade-6/#cascade) rules as normal. Thus, due to cascading, the following
style sheet:

``` highlight
h1 { counter-reset: section -1 }
h1 { counter-reset: imagenum 99 }
```

will only reset [imagenum]. To reset both counters, they have to
be specified together:

``` highlight
H1 { counter-reset: section -1 imagenum 99 }
```

The same principles apply to the
[counter-set](#propdef-counter-set) and
[counter-increment](#propdef-counter-increment) properties. See
[\[css-cascade-4\]](#biblio-css-cascade-4 "CSS Cascading and Inheritance Level 4").

If multiple instances of the same
[\<counter-name\>](#typedef-counter-name) occur in the property value, only the
last one is honored.

### 4.2. Manipulating Counter Values: the [counter-increment and [counter-set](#propdef-counter-set) properties]
Name:

[counter-increment]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[
[\<counter-name\>](#typedef-counter-name)
[\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value)[?](https://drafts.csswg.org/css-values-4/#mult-opt)
\][+](https://drafts.csswg.org/css-values-4/#mult-one-plus)
[\|](https://drafts.csswg.org/css-values-4/#comb-one) none

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[none](#valdef-counter-reset-none) or a list, each item an identifier paired with
an integer

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

User agents are expected to support this property on all media,
including non-visual ones.

Name:

[counter-set]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[
[\<counter-name\>](#typedef-counter-name)
[\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value)[?](https://drafts.csswg.org/css-values-4/#mult-opt)
\][+](https://drafts.csswg.org/css-values-4/#mult-one-plus)
[\|](https://drafts.csswg.org/css-values-4/#comb-one) none

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[none](#valdef-counter-reset-none) or a list, each item an identifier paired with
an integer

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

User agents are expected to support this property on all media,
including non-visual ones.

The
[counter-increment](#propdef-counter-increment) and
[counter-set](#propdef-counter-set) properties manipulate the value of
existing [counters](#counter). They
only [instantiate](#instantiate-counter) new counters if there is no counter of the given name
on the element yet. Their values are defined as follows:

[none]
: This element does not alter the value of any counters.

[[\<counter-name\>](#typedef-counter-name) [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value)?]

: Sets (for
 [counter-set](#propdef-counter-set)) or increments (for
 [counter-increment](#propdef-counter-increment)) the value of the named counter
 on the element to/by the specified
 [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value). If the
 [\<integer\>] is omitted, it
 defaults to [1] (for
 [counter-increment])
 or [0] (for [counter-set]).

 If there is not currently a counter of the given name on the
 element, the element
 [instantiates](#instantiate-counter) a new counter of the given name with a starting
 value of [0] before setting or incrementing its value.

This example shows a way to number chapters and sections with \"Chapter
1\", \"1.1\", \"1.2\", etc.

``` highlight
h1::before {
 content: "Chapter " counter(chapter) ". ";
 counter-increment: chapter; /* Add 1 to chapter */
 counter-set: section; /* Set section to 0 */
}
h2::before {
 content: counter(chapter) "." counter(section) " ";
 counter-increment: section;
}
```

If multiple instances of the same
[\<counter-name\>](#typedef-counter-name) occur in the property value, they are
all processed, in order. Thus increments will compound, but only the
last set value will take effect.

### 4.3. Nested Counters and Scope

Counters are "self-nesting";
[instantiating](#instantiate-counter) a new counter on an element which inherited an
identically-named [counter](#counter)
from its parent creates a new counter of the same name, nested inside
the existing counter. This is important for situations like lists in
HTML, where lists can be nested inside lists to arbitrary depth: it
would be impossible to define uniquely named counters for each level.
The [counter()](#funcdef-counter) function only retrieves the
[innermost](#innermost) counter of a
given name on the element, whereas the
[counters()](#funcdef-counters) function uses all counters of a given name that
contain the element.

The [scope] of a
[counter](#counter) therefore starts
at the first element in the document that
[instantiates](#instantiate-counter) that counter and includes the element's descendants and
its following siblings with their descendants. However, it does not
include any elements in the scope of a counter with the same name
created by a
[counter-reset](#propdef-counter-reset) on a later sibling of the element,
allowing such explicit counter instantiations to obscure those earlier
siblings.

See [§ 4.4 Creating and Inheriting Counters](#creating-counters) for the
exact rules governing the scope of counters and their values.

The following code numbers
nested list items. The result is very similar to that of setting
[display:list-item] and [list-style:
inside](#propdef-list-style) on the LI element:

``` highlight
ol { counter-reset: item }
li { display: block }
li::before { content: counter(item) ". "; counter-increment: item }
```

In this example, an
[ol](https://html.spec.whatwg.org/multipage/grouping-content.html#the-ol-element) will create a counter, and all children of the
[ol] will refer to that counter.

If we denote the `n`^th^ instance of the [item] counter
by item~`n`~, then the following HTML fragment will use the
indicated counters.

`<ol>` item~0~ is created, set to 0

`<li>` item~0~ is incremented to 1

`<li>` item~0~ is incremented to 2

`<ol>` item~1~ is created, set to 0, nested in item~0~

`<li>` item~1~ is incremented to 1

`<li>` item~1~ is incremented to 2

`<li>` item~1~ is incremented to 3

`<ol>` item~2~ is created, set to 0, nested in item~1~

`<li>` item~2~ is incremented to 1

`</ol>`

`<li>` item~1~ is incremented to 4

`<ol>` item~3~ is created, set to 0, nested in item~1~

`<li>` item~3~ is incremented to 1

`</ol>`

`<li>` item~1~ is incremented to 5

`</ol>`

`<li>` item~0~ is incremented to 3

`<li>` item~0~ is incremented to 4

`</ol>`

`<ol>` item~4~ is created, set to 0

`<li>` item~4~ is incremented to 1

`<li>` item~4~ is incremented to 2

`</ol>`

### 4.4. Creating and Inheriting Counters

Each element or pseudo-element in a document has a (possibly empty) set
of [counters](#counter) in the
[scope](#counter-scope) of that
element, either through inheritance from another element or through
instantiation on the element directly. These counters are represented as
a [CSS counters set], which is a
[set](https://infra.spec.whatwg.org/#ordered-set) whose values are each a
[tuple](https://infra.spec.whatwg.org/#tuple) of: a
[string](https://infra.spec.whatwg.org/#string) (representing a counter's
[name](#css-counter-name)),
an element (representing the counter's
[creator](#css-counter-creator)), a boolean (representing whether the counter is
[reversed](#css-counter-reversed)), and optionally an integer (representing the counter's
[value](#css-counter-value)). The latest [counter] of a given
name in that set represents the [innermost] counter of that name.

#### 4.4.1. Inheriting Counters

An element [inherits](#inherit-counters) its initial set of counters from its parent and
preceding *sibling*. It then takes the values for those counters from
the values of the matching counters on its preceding *element in [tree
order](https://dom.spec.whatwg.org/#concept-tree-order)* (which might be its parent, its preceding sibling, or
a descendant of its previous sibling). To [inherit
counters] into an `element`:

1. Let `element counters` be an initially empty [CSS
 counters set](#css-counters-set) representing `element`'s own [CSS
 counters set].

2. If `element` is the
 [root](https://dom.spec.whatwg.org/#concept-tree-root) of its document tree, return. (The element has an
 initially-empty counter map and inherits nothing.)

3. Let `counter source` be the [CSS counters
 set](#css-counters-set)
 of `element`'s preceding sibling, if it has one, or else
 of `element`'s parent if it does not.

4. Let `value source` be the [CSS counters
 set](#css-counters-set)
 of the element immediately preceding `element` in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order).

5. [For
 each](https://infra.spec.whatwg.org/#map-iterate) (\|=CSS counter/name=\|,
 `originating element`, \|=value=\|) of
 `value source`:

 1. If `counter source` also
 [contains](https://infra.spec.whatwg.org/#list-contain) a [counter](#counter) with the same \|=CSS counter/name=\| and
 `originating element`, then
 [append](https://infra.spec.whatwg.org/#set-append) a copy of `value source`'s
 [counter] (\|=CSS counter/name=\|,
 `originating element`, \|=value=\|) to
 `element counters`.

Take the following code as
an example:

 <ul style='counter-reset: example 0;'>
 <li id='foo' style='counter-increment: example;'>
 foo
 <div id='bar' style='counter-increment: example;'>bar</div>
 </li>
 <li id='baz'>
 baz
 </li>
 </ul>

Recall that [tree
order](https://dom.spec.whatwg.org/#concept-tree-order) turns a document tree into an ordered list, where an
element comes before its children, and its children come before its next
sibling. In other words, for a language like HTML, it's the order in
which the parser encounters start tags as it reads the document.

In here, the
[`ul`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-ul-element) element establishes a new counter named
[example], and sets its value to [0]. The **#foo** element,
being the first child of the
[`ul`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-ul-element), inherits this counter. Its parent is also its
immediately preceding element in [tree
order](https://dom.spec.whatwg.org/#concept-tree-order), so it inherits the value [0] with it, and then
immediately increments the value to [1].

The same happens with the **#bar** element. It inherits the
[example] counter from **#foo**, and inherits the value [1]
from it as well and increments it to [2].

However, the **#baz** element is a bit different. It inherits the
[example] counter from the **#foo** element, its previous sibling.
However, rather than inheriting the value [1] from **#foo** along
with the counter, in inherits the value [2] from **#bar**, the
previous element in [tree
order](https://dom.spec.whatwg.org/#concept-tree-order).

This behavior allows a single counter to be used throughout a document,
continuously incrementing, without the author having to worry about the
nested structure of their document.

 Counter inheritance, like regular CSS
[inheritance](https://drafts.csswg.org/css-cascade-5/#css-inheritance), operates on the "flattened element tree" in the
context of the
[\[DOM\]](#biblio-dom "DOM Standard").

#### 4.4.2. Instantiating Counters

[Counters](#counter) are
[instantiated](#instantiate-counter) when named in
[counter-reset](#propdef-counter-reset), and also when not otherwise
present if named in
[counter-increment](#propdef-counter-increment),
[counter-set](#propdef-counter-set), or the
[counter()](#funcdef-counter) or
[counters()](#funcdef-counters) notations. (Newly
[instantiated]
[counters] replace identically-named
[counters] originating from previous siblings, but
are added in addition to identically-named
[counters] originating from ancestor elements, see
[§ 4.3 Nested Counters and Scope](#nested-counters).) To [instantiate a
counter] of a given
`name` on an `element`, optionally
`reversed`, with an optional starting `value`:

1. Let `counters` be `element`'s [CSS counters
 set](#css-counters-set).

2. Let `innermost counter` be the last
 [counter](#counter) in
 `counters` with the name `name`. If
 `innermost counter`'s originating element is
 `element` or a previous sibling of `element`,
 [remove](https://infra.spec.whatwg.org/#list-remove) `innermost counter` from
 `counters`.

3. [Append](https://infra.spec.whatwg.org/#set-append) a new [counter](#counter) to `counters` with name
 `name`, originating element `element`,
 reversed being `reversed`, and initial value
 `value` (if given)

When a [counter](#counter) is
[instantiated](#instantiate-counter) without an initial value, the user agent must
dynamically calculate the initial value at layout-time to be the value
returned by the following algorithm:

1. Let `num` be 0.

2. Let `lastNonZeroIncrementNegated` be 0.

3. For each element or pseudo-element `el` that increments
 or sets the same counter in the same
 [scope](#counter-scope):

 1. Let `incrementNegated` be `el`'s
 [counter-increment](#propdef-counter-increment) integer value for this
 counter, multiplied by -1.

 2. If `incrementNegated` is not zero, then set
 `lastNonZeroIncrementNegated` to
 `incrementNegated`.

 3. If `el` sets this counter with
 [counter-set](#propdef-counter-set), then add that integer
 value to `num` and break this loop.

 4. Add `incrementNegated` to `num`.

4. Add `lastNonZeroIncrementNegated` to `num`.

5. Return `num`.

 Only
[reversed](#css-counter-reversed) counters can be instantiated without an initial value.

### 4.5. Counters in elements that do not generate boxes

An element that does not generate a box (for example, an element with
[display](https://drafts.csswg.org/css-display-4/#propdef-display) set to
[none](https://drafts.csswg.org/css-display-4/#valdef-display-none), or a pseudo-element with
[content](https://drafts.csswg.org/css-content-3/#propdef-content) set to
[none](https://drafts.csswg.org/css-content-3/#valdef-content-none)) cannot set, reset, or increment a counter. The
counter properties are still valid on such an element, but they must
have no effect.

For example, with the following style
sheet, H2s with class \"secret\" do not increment [count2].

``` highlight
h2 { counter-increment: count2; }
h2.secret { display: none; }
```

 Other methods of "hiding" elements, such as setting
[visibility](https://drafts.csswg.org/css-display-4/#propdef-visibility) to
[hidden](https://drafts.csswg.org/css-display-4/#valdef-visibility-hidden), still cause the element to generate a box, and
so are not excepted here.

Whether a [replaced
element's](https://drafts.csswg.org/css-display-4/#replaced-element) descendants (such as HTML
[`option`](https://html.spec.whatwg.org/multipage/form-elements.html#the-option-element), or SVG
[`rect`](https://w3c.github.io/svgwg/svg2-draft/shapes.html#elementdef-rect)) can set, reset, or increment a counter is
undefined.

 The behavior on [replaced
element](https://drafts.csswg.org/css-display-4/#replaced-element) descendants is currently undefined due to a lack of
interoperability across implementations.

### 4.6. The Implicit [list-item Counter]
In addition to any explicitly defined
[counters](#counter) that authors
write in their styles, [list items](#list-item) automatically increment a special
[list-item] [counter], which is used
when generating the default [marker
string](#marker-string) on
[list items] (see
[list-style-type](#propdef-list-style-type)).

Specifically, unless the
[counter-increment](#propdef-counter-increment) property explicitly specifies a
different increment for the
[list-item](#valdef-counter-increment-list-item) counter, it must be incremented by 1 on every
[list item](#list-item), or if the
counter is
[reversed](#css-counter-reversed), it must be incremented by -1 on every [list
item] instead, at the same time that
[counters](#counter) are normally
incremented (exactly as if the [list item] had
[list-item 1] or [list-item -1] appended to their
[counter-increment]
value, including side-effects such as possibly
[instantiating](#instantiate-counter) a new [counter], etc). This does
not affect the
[specified](https://drafts.csswg.org/css-cascade-5/#specified-value) or [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value) of
[counter-increment].

Because each [list
item](#list-item) automatically
increments the
[list-item](#valdef-counter-increment-list-item) counter by 1, consecutive [list
items] with a numeric
[list-style-type](#propdef-list-style-type) will be consecutively numbered by
default---​even if the author sets
[counter-increment](#propdef-counter-increment) to another value such as
[counter-increment: itemnumber] or even
[none](#valdef-counter-set-none). This protects the automatic
[list-item] counter
from inadvertently being overridden by declarations intended to address
other counters.

However, since the automatic
[list-item](#valdef-counter-increment-list-item) increment *does not* happen if the [list
item's](#list-item)
[counter-increment](#propdef-counter-increment) explicitly mentions the
[list-item] counter,
[li { counter-increment: list-item 2; }] will increment
[list-item] by 2 as
specified, not by 3 as would happen if [list-item 1] were
unconditionally appended.

This also allows to turn off the automatic
[list-item](#valdef-counter-increment-list-item) counter increment, by overriding it explicitly,
e.g. [counter-increment: list-item
0;](#propdef-counter-increment).

In all other respects, the
[list-item](#valdef-counter-increment-list-item) [counter](#counter) behaves like any other [counter]
and can be used and manipulated by authors to adjust [list
item](#list-item) styling or for
other purposes.

In the following example, the list is modified to count by twos:

 ol.evens > li { counter-increment: list-item 2; }

A three-item list would be rendered as

 2. First Item
 4. Second Item
 6. Third Item

UAs and host languages should ensure that the
[list-item](#valdef-counter-increment-list-item) counter values by default reflect the underlying
numeric value dictated by host language semantics when setting up list
item styling in their UA style sheet and presentational hint style
mappings. See, e.g. [Appendix A: Sample Style Sheet For
HTML](#ua-stylesheet).

In the following example, the
[content](https://drafts.csswg.org/css-content-3/#propdef-content) property is used to create tiered
numbering that hooks into the
[list-item](#valdef-counter-increment-list-item) counter, and thus respects any numbering changes
inflicted through HTML:

 ol > li::marker { content: counters(list-item,'.') '.'; }

Nested lists using this rule would be rendered like

 1. First top-level item
 5. Second top-level item, value=5
 5.3. First second-level item, list start=3
 5.4. Second second-level item, list start=3
 5.4.4. First third-level item in reversed list
 5.4.3. Second third-level item in reversed list
 5.4.2. Third third-level item in reversed list
 5.4.1. Fourth third-level item in reversed list
 5.5. Third second-level item, list start=3
 6. Third top-level item

given markup such as

 <ol>
 <li>First top-level item
 <li value=5>Second top-level item, value=5
 <ol start=3>
 <li>First second-level item, list start=3
 <li>Second second-level item, list start=3
 <ol reversed>
 <li>First third-level item in reversed list
 <li>Second third-level item in reversed list
 <li>Third third-level item in reversed list
 <li>Fourth third-level item in reversed list
 </ol>
 <li>Third second-level item, list start=3
 </ol>
 <li>Third top-level item
 </ol>

### 4.7. Outputting Counters: the [counter() and [counters()](#funcdef-counters) functions]
[Counters](#counter) have no visible
effect by themselves, but their values can be used with the
[counter()] and [counters()] functions, whose [used
values](https://drafts.csswg.org/css-cascade-5/#used-value) represent counter values as strings or images. They are
defined as follows:

``` prod
<counter> = <counter()> | <counters()>
<counter()> = counter( <counter-name>, <counter-style>? )
<counters()> = counters( <counter-name>, <string>, <counter-style>? )
```

where
[\<counter-style\>](https://drafts.csswg.org/css-counter-styles-3/#typedef-counter-style) specifies the [counter
style](https://drafts.csswg.org/css-counter-styles-3/#counter-style) for [generating a
representation](https://drafts.csswg.org/css-counter-styles-3/#generate-a-counter) of the named counter(s) as defined in
[\[css-counter-styles-3\]](#biblio-css-counter-styles-3 "CSS Counter Styles Level 3")
and

counter()
: Represents the value of the
 [innermost](#innermost)
 [counter](#counter) in the
 element's [CSS counters
 set](#css-counters-set)
 named
 [\<counter-name\>](#typedef-counter-name) using the [counter
 style](https://drafts.csswg.org/css-counter-styles-3/#counter-style) named
 [\<counter-style\>](https://drafts.csswg.org/css-counter-styles-3/#typedef-counter-style).

counters()
: Represents the values of all the
 [counters](#counter) in the
 element's [CSS counters
 set](#css-counters-set)
 named
 [\<counter-name\>](#typedef-counter-name) using the [counter
 style](https://drafts.csswg.org/css-counter-styles-3/#counter-style) named
 [\<counter-style\>](https://drafts.csswg.org/css-counter-styles-3/#typedef-counter-style), sorted in outermost-first to
 [innermost](#innermost)-last
 order and joined by the specified
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value).

In both cases, if the
[\<counter-style\>](https://drafts.csswg.org/css-counter-styles-3/#typedef-counter-style) argument is omitted it defaults to
[decimal](https://drafts.csswg.org/css-counter-styles-3/#decimal).

 If the
[\<counter-style\>](https://drafts.csswg.org/css-counter-styles-3/#typedef-counter-style) is one of the predefined symbolic
styles, like
[disc](https://drafts.csswg.org/css-counter-styles-3/#disc), it might look different than when used in
[list-style-type](#propdef-list-style-type). See [CSS Counter Styles 3 § 6.3
Symbolic: disc, circle, square, disclosure-open,
disclosure-closed](https://drafts.csswg.org/css-counter-styles-3/#simple-symbolic).

If no [counter](#counter) named
[\<counter-name\>](#typedef-counter-name) exists on an element where
[counter()](#funcdef-counter) or
[counters()](#funcdef-counters) is used, one is first
[instantiated](#instantiate-counter) with a starting value of [0].

H1::before { content: counter(chno, upper-latin) ". " }
 /* Generates headings like "A. A History of Discontent" */

 H2::before { content: counter(section, upper-roman) " - " }
 /* Generates headings like "II - The Discontent Part" */

 BLOCKQUOTE::after { content: " [" counter(bq, decimal) "]" }
 /* Generates blockquotes that end like "... [3]" */

 DIV.note::before { content: counter(notecntr, disc) " " }
 /* Simply generates a bullet before every div.note */

 P::before { content: counter(p, none) }
 /* inserts nothing */

The following example shows a simple
use of the [counters()](#funcdef-counters) function:

``` highlight
<ul>
 <li>one</li>
 <li>two
 <ul>
 <li>nested one</li>
 <li>nested two</li>
 </ul>
 </li>
 <li>three</li>
</ul>
<style>
li::marker { content: '(' counters(list-item,'.') ') '; }
</style>
```

The preceding document should render something like this:

 (1) one
 (2) two
 (2.1) nested one
 (2.2) nested two
 (3) three

Because counters inherit to siblings
as well, they can be used to number headings and subheadings, which
aren't nested within each other. Unfortunately, this prevents the use of
[counters()](#funcdef-counters) as counters from siblings don't nest, but one can
create multiple counters and manually concatenate them instead:

``` highlight
<h1>First H1</h1>
...
<h2>First H2 in H1</h2>
...
<h2>Second H2 in H1</h2>
...
<h3>First H3 in H2</h3>
...
<h1>Second H1</h1>
...
<h2>First H2 in H1</h2>
...
<style>
body { counter-reset: h1 h2 h3; }
h1 { counter-increment: h1; counter-reset: h2 h3;}
h2 { counter-increment: h2; counter-reset: h3; }
h3 { counter-increment: h3; }
h1::before { content: counter(h1,upper-alpha) ' '; }
h2::before { content: counter(h1,upper-alpha) '.'
 counter(h2,decimal) ' '; }
h3::before { content: counter(h1,upper-alpha) '.'
 counter(h2,decimal) '.'
 counter(h3,lower-roman) ' '; }
</style>
```

The preceding document should render something like this:

 A First H1
 ...
 A.1 First H2 in H1
 ...
 A.2 Second H2 in H1
 ...
 A.2.i First H3 in H2
 ...
 B Second H1
 ...
 B.1 First H2 in H1
 ...

Counters are sometimes useful for things
other than printing markers. In general, they provide the ability to
number elements in sequence, which can be useful for other properties to
reference. For example, using
[order](https://drafts.csswg.org/css-display-4/#propdef-order) to put an element between two other
specific elements currently requires you to explicitly put
[order] on every element before
and/or after the desired insertion point. If you can set the
[order] value of everything to a
counter though, you can more easily insert an element into an arbitrary
spot between two others.

Other use-cases involve nested or sibling elements with transforms that
are meant to be slightly different from each other. Today you have to
use a preprocessor to do this in a reasonable way, but a counter would
make it work well in \"plain\" CSS.

(You can built up successive values in the nested case today by using
[custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property) and stacking up nested
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc)s, but this is a \*little bit\* clumsy, and
doesn't work for siblings.)

Suggestion is to add a
[counter-value([\<counter-name\>](#typedef-counter-name))] function, which returns the
value of the named counter as an integer, rather than returning a
string.

See [Issue 1026](https://github.com/w3c/csswg-drafts/issues/1026).

## [ Appendix A: Sample Style Sheet For HTML]
*This section is informative, not normative. The
[\[HTML\]](#biblio-html "HTML Standard")
[Rendering](https://html.spec.whatwg.org/multipage/rendering.html#lists)
chapter defines the normative default properties that apply to HTML
lists; this sample style sheet is provided to illustrate the CSS
features using familiar markup conventions.*

 /* Set up list items */
 li {
 display: list-item; /* implies 'counter-increment: list-item' */
 }

 /* Set up ol and ul so that they scope the list-item counter */
 ol, ul {
 counter-reset: list-item;
 }

 /* Default list style types for lists */
 ol { list-style-type: decimal; }
 ul { list-style-type: toggle(disc, circle, square); }

 /* The type attribute on ol and ul elements */
 ul[type="disc"] { list-style-type: disc; }
 ul[type="circle"] { list-style-type: circle; }
 ul[type="square"] { list-style-type: square; }
 ol[type="1"] { list-style-type: decimal; }
 ol[type="a"] { list-style-type: lower-alpha; }
 ol[type="A"] { list-style-type: upper-alpha; }
 ol[type="i"] { list-style-type: lower-roman; }
 ol[type="I"] { list-style-type: upper-roman; }

 /* The start attribute on ol elements */
 ol[start] {
 counter-reset: list-item calc(attr(start integer, 1) - 1);
 }

 /* The value attribute on li elements */
 li[value] {
 counter-set: list-item attr(value integer, 1);
 }

 /* Handling reversed lists */
 ol[reversed] {
 counter-reset: reversed(list-item);
 }
 ol[reversed][start] {
 counter-reset: reversed(list-item) calc(attr(start integer) + 1);
 }

 /* Box Model Rules */
 ol, ul {
 display: block;
 margin-block: 1em;
 marker-side: match-parent;
 padding-inline-start: 40px;
 }
 ol ol, ol ul, ul ul, ul ol {
 margin-block: 0;
 }

 li {
 text-align: match-parent;
 }

## [ Acknowledgments]
This specification is made possible by input from Aharon Lanin, Arron
Eicholz, Brad Kemper, David Baron, Emilio Cobos Álvarez, Mats Palmgren,
Oriol Brufau, Simon Sapin, Xidorn Quan

## [Changes]
This section documents the changes since previous publications.

### [Changes since the 9 July 2020 WD]
- Clarified properties that apply to
 [::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) boxes vs. to the contents of
 [::marker] boxes. ([Issue
 4568](https://github.com/w3c/csswg-drafts/issues/4568))
- Added [text-transform:
 none](https://drafts.csswg.org/css-text-4/#propdef-text-transform) to the UA default style sheet for
 [::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker). ([Issue
 4206](https://github.com/w3c/csswg-drafts/issues/4206))
- Changed counter inheritance to take from the parent first, and only
 take from the sibling if it's a new counter. ([Issue
 5477](https://github.com/w3c/csswg-drafts/issues/5477))

### [Changes since the 17 August 2019 WD]
- Specified that
 [outside](#list-style-position-outside) list markers [block
 containers](https://drafts.csswg.org/css-display-4/#block-container). (Their [outer display
 type](https://drafts.csswg.org/css-display-4/#outer-display-type) remains undefined.)
- Stole list of properties applying to
 [::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) from
 [\[CSS-PSEUDO-4\]](#biblio-css-pseudo-4 "CSS Pseudo-Elements Module Level 4")
 and added animations, transitions, and
 [white-space](https://drafts.csswg.org/css-text-4/#propdef-white-space).
- Added [white-space:
 pre](https://drafts.csswg.org/css-text-4/#propdef-white-space) to UA default style sheet for
 [::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker). ([Issue
 4448](https://github.com/w3c/csswg-drafts/issues/4448)) Note, however,
 that the exact white space processing behavior of marker boxes is
 still being worked out.

### [Changes since the 25 April 2019 WD]
- Rewrote the [§ 4 Automatic Numbering With Counters](#auto-numbering)
 section for better precision, editorial clarity, and synchronization
 with CSS2.

### [Changes since the 20 March 2014 WD]
- Use
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) consistently for counter names.
- Dropped [position:
 marker](https://drafts.csswg.org/css-position-3/#propdef-position) (marker positioning is now mostly
 undefined, as in CSS2).
- Completely rewrote chapter on markers to tighten it up, align with
 current expectations, and make editorial improvements.
- Pulled the
 [list-item](#valdef-counter-increment-list-item) counter definition into its own section, added
 examples, and made some clarifications.
- Renamed values of
 [marker-side](#propdef-marker-side) to match conventions from box/text
 alignment.
- Defined that
 [counter-set](#propdef-counter-set) is applied after
 [counter-increment](#propdef-counter-increment) rather than before. ([Issue
 3810](https://github.com/w3c/csswg-drafts/issues/3810))
- Established the canonical order of
 [list-style](#propdef-list-style) serialization to put
 [\<\'list-style-type\'\>](#propdef-list-style-type) last. ([Issue
 2624](https://github.com/w3c/csswg-drafts/issues/2624))

### [Changes From CSS Level 2]
As described in the introduction section, there are significant changes
in this module when compared to CSS2.1.

1. The
 [::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-element has been introduced to allow
 styling of the list marker directly.
2. [list-style-type](#propdef-list-style-type) now accepts a
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value) as well as the extended
 [\<counter-style\>](https://drafts.csswg.org/css-counter-styles-3/#typedef-counter-style) values from
 [\[css-counter-styles-3\]](#biblio-css-counter-styles-3 "CSS Counter Styles Level 3")..
3. The
 [list-item](#valdef-counter-increment-list-item) predefined counter identifier has been
 introduced.
4. The
 [counter-set](#propdef-counter-set) property has been added.
5. Allowed for
 [inline-level](https://drafts.csswg.org/css-display-4/#inline-level) [list items](#list-item), as introduced in
 [\[CSS-DISPLAY-3\]](#biblio-css-display-3 "CSS Display Module Level 3").

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.
