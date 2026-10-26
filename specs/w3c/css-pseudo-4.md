## 1. Introduction

*This section is informative.*

[Pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) represent abstract elements of the document beyond
those elements explicitly created by the document language. Since they
are not restricted to fitting into the document tree, they can be used
to select and style portions of the document that do not necessarily map
to the document's tree structure. For instance, the
[::first-line](#selectordef-first-line) pseudo-element can select content on the first
formatted line of an element *after* text wrapping, allowing just that
line to be styled differently from the rest of the paragraph.

Each pseudo-element is associated with an [originating
element](https://drafts.csswg.org/selectors-4/#originating-element) and has syntax of the form [::name-of-pseudo].
This module defines the pseudo-elements that exist in CSS and how they
can be styled. For more information on pseudo-elements in general, and
on their syntax and interaction with other
[selectors](https://drafts.csswg.org/selectors-4/#selector), see
[\[SELECTORS-4\]](#biblio-selectors-4 "Selectors Level 4").

 As a reminder, pseudo-elements cannot be chained
together unless explicitly allowed. For example,
[::marker::before] is not allowed; but [::before::marker]
is.

 Level 4 is the first version of the CSS Pseudo
specification under this name. It was branched from the Selectors 3
[\[SELECTORS-3\]](#biblio-selectors-3 "Selectors Level 3")
specification, and thus started at level 4, with the remainder of
Selectors 3 becoming Selectors 4
[\[SELECTORS-4\]](#biblio-selectors-4 "Selectors Level 4").

## 2. Typographic Pseudo-elements

### 2.1. First-Line Text: the [::first-line pseudo-element]
The [::first-line]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) represents the contents of the [first formatted
line](#first-formatted-line) of its [originating
element](https://drafts.csswg.org/selectors-4/#originating-element).

Tests

- [first-line-marquee-crash.html](https://wpt.fyi/results/css/css-pseudo/crashtests/first-line-marquee-crash.html "css/css-pseudo/crashtests/first-line-marquee-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/crashtests/first-line-marquee-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/crashtests/first-line-marquee-crash.html)
- [first-line-allowed-properties.html](https://wpt.fyi/results/css/css-pseudo/first-line-allowed-properties.html "css/css-pseudo/first-line-allowed-properties.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-allowed-properties.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-allowed-properties.html)
- [first-line-and-marker.html](https://wpt.fyi/results/css/css-pseudo/first-line-and-marker.html "css/css-pseudo/first-line-and-marker.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-and-marker.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-and-marker.html)
- [first-line-and-placeholder.html](https://wpt.fyi/results/css/css-pseudo/first-line-and-placeholder.html "css/css-pseudo/first-line-and-placeholder.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-and-placeholder.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-and-placeholder.html)
- [first-line-change-inline-color-nested.html](https://wpt.fyi/results/css/css-pseudo/first-line-change-inline-color-nested.html "css/css-pseudo/first-line-change-inline-color-nested.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-change-inline-color-nested.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-change-inline-color-nested.html)
- [first-line-change-inline-color.html](https://wpt.fyi/results/css/css-pseudo/first-line-change-inline-color.html "css/css-pseudo/first-line-change-inline-color.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-change-inline-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-change-inline-color.html)
- [first-line-first-letter-insert-crash.html](https://wpt.fyi/results/css/css-pseudo/first-line-first-letter-insert-crash.html "css/css-pseudo/first-line-first-letter-insert-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-first-letter-insert-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-first-letter-insert-crash.html)
- [first-line-float-mapped-attribute-crash.html](https://wpt.fyi/results/css/css-pseudo/first-line-float-mapped-attribute-crash.html "css/css-pseudo/first-line-float-mapped-attribute-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-float-mapped-attribute-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-float-mapped-attribute-crash.html)
- [first-line-inherited-no-transition.html](https://wpt.fyi/results/css/css-pseudo/first-line-inherited-no-transition.html "css/css-pseudo/first-line-inherited-no-transition.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-inherited-no-transition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-inherited-no-transition.html)
- [first-line-inherited-transition-crash.html](https://wpt.fyi/results/css/css-pseudo/first-line-inherited-transition-crash.html "css/css-pseudo/first-line-inherited-transition-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-inherited-transition-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-inherited-transition-crash.html)
- [first-line-inherited-with-transition.html](https://wpt.fyi/results/css/css-pseudo/first-line-inherited-with-transition.html "css/css-pseudo/first-line-inherited-with-transition.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-inherited-with-transition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-inherited-with-transition.html)
- [first-line-input-image-crash.html](https://wpt.fyi/results/css/css-pseudo/first-line-input-image-crash.html "css/css-pseudo/first-line-input-image-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-input-image-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-input-image-crash.html)
- [first-line-line-height-001.html](https://wpt.fyi/results/css/css-pseudo/first-line-line-height-001.html "css/css-pseudo/first-line-line-height-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-line-height-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-line-height-001.html)
- [first-line-line-height-002.html](https://wpt.fyi/results/css/css-pseudo/first-line-line-height-002.html "css/css-pseudo/first-line-line-height-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-line-height-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-line-height-002.html)
- [first-line-nested-gcs.html](https://wpt.fyi/results/css/css-pseudo/first-line-nested-gcs.html "css/css-pseudo/first-line-nested-gcs.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-nested-gcs.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-nested-gcs.html)
- [first-line-on-ancestor-block.html](https://wpt.fyi/results/css/css-pseudo/first-line-on-ancestor-block.html "css/css-pseudo/first-line-on-ancestor-block.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-on-ancestor-block.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-on-ancestor-block.html)
- [first-line-opacity-001-ref.html](https://wpt.fyi/results/css/css-pseudo/first-line-opacity-001-ref.html "css/css-pseudo/first-line-opacity-001-ref.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-opacity-001-ref.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-opacity-001-ref.html)
- [first-line-opacity-001.html](https://wpt.fyi/results/css/css-pseudo/first-line-opacity-001.html "css/css-pseudo/first-line-opacity-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-opacity-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-opacity-001.html)
- [first-line-replaced-001.html](https://wpt.fyi/results/css/css-pseudo/first-line-replaced-001.html "css/css-pseudo/first-line-replaced-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-replaced-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-replaced-001.html)
- [first-line-with-before-after.html](https://wpt.fyi/results/css/css-pseudo/first-line-with-before-after.html "css/css-pseudo/first-line-with-before-after.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-with-before-after.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-with-before-after.html)
- [first-line-with-inline-block-before.html](https://wpt.fyi/results/css/css-pseudo/first-line-with-inline-block-before.html "css/css-pseudo/first-line-with-inline-block-before.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-with-inline-block-before.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-with-inline-block-before.html)
- [first-line-with-inline-block.html](https://wpt.fyi/results/css/css-pseudo/first-line-with-inline-block.html "css/css-pseudo/first-line-with-inline-block.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-with-inline-block.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-with-inline-block.html)
- [first-line-with-out-of-flow-and-nested-div.html](https://wpt.fyi/results/css/css-pseudo/first-line-with-out-of-flow-and-nested-div.html "css/css-pseudo/first-line-with-out-of-flow-and-nested-div.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-with-out-of-flow-and-nested-div.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-with-out-of-flow-and-nested-div.html)
- [first-line-with-out-of-flow-and-nested-span.html](https://wpt.fyi/results/css/css-pseudo/first-line-with-out-of-flow-and-nested-span.html "css/css-pseudo/first-line-with-out-of-flow-and-nested-span.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-with-out-of-flow-and-nested-span.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-with-out-of-flow-and-nested-span.html)
- [first-line-with-out-of-flow.html](https://wpt.fyi/results/css/css-pseudo/first-line-with-out-of-flow.html "css/css-pseudo/first-line-with-out-of-flow.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-with-out-of-flow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-with-out-of-flow.html)

The rule below means "change the
letters of the first line of every `p` element to
uppercase":

```
p::first-line { text-transform: uppercase }
```

The selector [p::first-line] does not match any real document
element. It instead matches a pseudo-element that the user agent will
automatically insert at the beginning of every `p` element.

 Note that the length of the first line depends on a
number of factors, including the width of the page, the font size, etc.

For example, given an ordinary HTML
[\[HTML5\]](#biblio-html5 "HTML5") paragraph such
as:

```
<P>This is a somewhat long HTML paragraph
that will be broken into several lines.
The first line will be styled
by the ‘::first-line’ pseudo-element.
The other lines will be treated
as ordinary lines in the paragraph.</P>
```

Depending on the width of the element, its lines might be broken as
follows:

```
THIS IS A SOMEWHAT LONG HTML PARAGRAPH THAT
will be broken into several lines. The first
line will be styled by the ‘::first-line’
pseudo-element. The other lines will be
treated as ordinary lines in the paragraph.
```

or alternately as follows:

```
THIS IS A SOMEWHAT LONG
HTML paragraph that will
be broken into several
lines. The first line will
be styled by the
‘::first-line’ pseudo-
element. The other lines
will be treated as ordinary
lines in the paragraph.
```

#### 2.1.1. Finding the First Formatted Line

In CSS, the
[::first-line](#selectordef-first-line)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) can only have an effect when attached to a [block
container](https://drafts.csswg.org/css-display-4/#block-container):

- The [first formatted line] of a [block
 container](https://drafts.csswg.org/css-display-4/#block-container) that establishes an [inline formatting
 context](https://drafts.csswg.org/css-display-4/#inline-formatting-context) represents the
 [inline-level](https://drafts.csswg.org/css-display-4/#inline-level) content of its first [line
 box](https://drafts.csswg.org/css-inline-3/#line-box).

- The [first formatted
 line](#first-formatted-line) of a [block
 container](https://drafts.csswg.org/css-display-4/#block-container) or [multi-column
 container](https://drafts.csswg.org/css-multicol-2/#multi-column-container) that contains
 [block-level](https://drafts.csswg.org/css-display-4/#block-level) content (and is not a [table wrapper
 box](https://drafts.csswg.org/css-tables-3/#table-wrapper-box)) is the [first formatted
 line] of its first
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) [block-level] child. If no
 such line exists, it has no [first formatted
 line].

 The [first formatted
line](#first-formatted-line) can be an empty line. For example, the first line of
the `p` in `<p><br>First…` doesn't
contain any letters. Thus the word "First" is not on the first formatted
line, and will not be affected by [p::first-line].

 The first line of a [block
container](https://drafts.csswg.org/css-display-4/#block-container) that does not itself participate in a [block formatting
context](https://drafts.csswg.org/css-display-4/#block-formatting-context) cannot be the first formatted line of an ancestor
element. Thus, in
`<DIV><P STYLE="display: inline-block">Hello<BR>Goodbye</P> etcetera</DIV>` the first formatted line of the `DIV` is not
the line "Hello", but rather the line that contains that entire inline
block.

When a [first formatted
line](#first-formatted-line) is represented by multiple
[::first-line](#selectordef-first-line) pseudo-elements, they are nested in the same
order as their [originating
elements](https://drafts.csswg.org/selectors-4/#originating-element). The
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) contents of this line---​including its [root inline
box](https://drafts.csswg.org/css-inline-3/#root-inline-box) fragment---​are nested within the innermost
[::first-line]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element).

Tests

- [first-line-below-float.html](https://wpt.fyi/results/css/css-pseudo/first-line-below-float.html "css/css-pseudo/first-line-below-float.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-below-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-below-float.html)
- [first-line-on-list-item-with-block-children.html](https://wpt.fyi/results/css/css-pseudo/first-line-on-list-item-with-block-children.html "css/css-pseudo/first-line-on-list-item-with-block-children.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-line-on-list-item-with-block-children.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-line-on-list-item-with-block-children.html)

Consider the following markup:

```
<DIV>
 <P>First paragraph</P>
 <P>Second paragraph</P>
</DIV>
```

If we assume a [fictional tag
sequence](#fictional-tag-sequence) to represent the elements'
[::first-line](#selectordef-first-line) pseudo-elements, it would be something like:

```
<DIV>
 <P><DIV::first-line><P::first-line>First paragraph</P::first-line></DIV::first-line></P>
 <P><P::first-line>Second paragraph</P::first-line></P>
</DIV>
```

#### 2.1.2. Styling the [::first-line Pseudo-element]
The
[::first-line](#selectordef-first-line) pseudo-element's generated box behaves similar
to that of an [inline-level
box](https://drafts.csswg.org/css-display-4/#inline-level-box), but with certain restrictions. The following CSS
properties apply to a [::first-line]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element):

- all font properties (see
 [\[CSS-FONTS-4\]](#biblio-css-fonts-4 "CSS Fonts Module Level 4"))
- the
 [color](https://drafts.csswg.org/css-color-4/#propdef-color) and
 [opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity) properties (see
 [\[CSS-COLOR-4\]](#biblio-css-color-4 "CSS Color Module Level 4"))
- all background properties (see
 [\[CSS-BACKGROUNDS-3\]](#biblio-css-backgrounds-3 "CSS Backgrounds and Borders Module Level 3"))
- any typesetting properties that apply to inline elements (see
 [\[CSS-TEXT-4\]](#biblio-css-text-4 "CSS Text Module Level 4"))
- all text decoration properties (see
 [\[CSS-TEXT-DECOR-4\]](#biblio-css-text-decor-4 "CSS Text Decoration Module Level 4"))
- the
 [ruby-position](https://drafts.csswg.org/css-ruby-1/#propdef-ruby-position) property (see
 [\[CSS-RUBY-1\]](#biblio-css-ruby-1 "CSS Ruby Annotation Layout Module Level 1"))
- any inline layout properties that apply to inline elements (see
 [\[CSS-INLINE-3\]](#biblio-css-inline-3 "CSS Inline Layout Module Level 3"))
- any other properties defined to apply to
 [::first-line](#selectordef-first-line) by their respective specifications

User agents may apply other properties as well except for the following
excluded properties:

- [writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode)
- [direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction)
- [text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation)

 Setting
[line-height](https://drafts.csswg.org/css2/#propdef-line-height) on
[::first-line](#selectordef-first-line) inherits to the fragment of the [root inline
box](https://drafts.csswg.org/css-inline-3/#root-inline-box) that wraps the contents of the first line, and
therefore can both increase and decrease the height of the first line
box.

#### 2.1.3. Inheritance and the [::first-line Pseudo-element]
During CSS
[inheritance](https://drafts.csswg.org/css-cascade-5/#css-inheritance), the
[fragment](https://drafts.csswg.org/css-break-4/#box-fragment) of a child that occurs on the first line inherits any
standard [inherited
properties](https://drafts.csswg.org/css-cascade-5/#inherited-property)---​except the properties excluded above---​from the
[::first-line](#selectordef-first-line)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element). For all other properties, including all [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property)
[\[CSS-VARIABLES-1\]](#biblio-css-variables-1 "CSS Custom Properties for Cascading Variables Module Level 1"),
inheritance is from the non-pseudo parent. (The portion of a child
element that does not occur on the first line always inherits from the
non-pseudo parent.)

In the common case (of standard
inherited CSS properties),
[inheritance](https://drafts.csswg.org/css-cascade-5/#css-inheritance) into and from a
[::first-line](#selectordef-first-line) pseudo-element can be understood by writing out
a [fictional tag sequence] to represent
[::first-line]. Consider the
[earlier example](#first-line-example); in case of the first rendering,
the fictional tag sequence would be:

```
<P><p::first-line>This is a somewhat long HTML paragraph
that</p::first-line> will be broken into several lines.
The first line will be styled
by the ‘::first-line’ pseudo-element.
The other lines will be treated
as ordinary lines in the paragraph.</p>
```

And in the case of the second rendering:

```
<p><p::first-line>This is a somewhat long</p::first-line> HTML paragraph
that will be broken into several lines.
The first line will be styled
by the ‘::first-line’ pseudo-element.
The other lines will be treated
as ordinary lines in the paragraph.</p>
```

If a pseudo-element breaks up a real
element, the effect can often be described by a [fictional tag
sequence](#fictional-tag-sequence) that closes and then re-opens the element. Suppose we
mark up the earlier example with a `span` element
encompassing the first sentence:

```
<p><span>This is a somewhat long HTML paragraph
that will be broken into several lines.</span>
The first line will be styled
by the ‘::first-line’ pseudo-element.
The other lines will be treated
as ordinary lines in the paragraph.</p>
```

The effect of the first rendering would be similar to the following
[fictional tag
sequence](#fictional-tag-sequence):

```
<p><p::first-line><span>This is a somewhat long HTML paragraph
that</span></p::first-line><span> will be broken into several lines.</span>
The first line will be styled
by the ‘::first-line’ pseudo-element.
The other lines will be treated
as ordinary lines in the paragraph.</p>
```

### 2.2. First-Letter Text: [::first-letter pseudo-element and its [::prefix](#selectordef-first-letter-prefix) and [::suffix](#selectordef-first-letter-suffix) children]
Tests

- [first-letter-001.html](https://wpt.fyi/results/css/css-pseudo/first-letter-001.html "css/css-pseudo/first-letter-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-001.html)
- [first-letter-002.html](https://wpt.fyi/results/css/css-pseudo/first-letter-002.html "css/css-pseudo/first-letter-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-002.html)
- [first-letter-003.html](https://wpt.fyi/results/css/css-pseudo/first-letter-003.html "css/css-pseudo/first-letter-003.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-003.html)
- [first-letter-004.html](https://wpt.fyi/results/css/css-pseudo/first-letter-004.html "css/css-pseudo/first-letter-004.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-004.html)
- [first-letter-005.html](https://wpt.fyi/results/css/css-pseudo/first-letter-005.html "css/css-pseudo/first-letter-005.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-005.html)
- [first-letter-allowed-properties.html](https://wpt.fyi/results/css/css-pseudo/first-letter-allowed-properties.html "css/css-pseudo/first-letter-allowed-properties.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-allowed-properties.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-allowed-properties.html)
- [first-letter-and-sibling-display-change.html](https://wpt.fyi/results/css/css-pseudo/first-letter-and-sibling-display-change.html "css/css-pseudo/first-letter-and-sibling-display-change.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-and-sibling-display-change.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-and-sibling-display-change.html)
- [first-letter-and-whitespace.html](https://wpt.fyi/results/css/css-pseudo/first-letter-and-whitespace.html "css/css-pseudo/first-letter-and-whitespace.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-and-whitespace.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-and-whitespace.html)
- [first-letter-background-image-dynamic.html](https://wpt.fyi/results/css/css-pseudo/first-letter-background-image-dynamic.html "css/css-pseudo/first-letter-background-image-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-background-image-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-background-image-dynamic.html)
- [first-letter-background-image.html](https://wpt.fyi/results/css/css-pseudo/first-letter-background-image.html "css/css-pseudo/first-letter-background-image.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-background-image.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-background-image.html)
- [first-letter-bidi-pre-crash.html](https://wpt.fyi/results/css/css-pseudo/first-letter-bidi-pre-crash.html "css/css-pseudo/first-letter-bidi-pre-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-bidi-pre-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-bidi-pre-crash.html)
- [first-letter-block-to-inline.html](https://wpt.fyi/results/css/css-pseudo/first-letter-block-to-inline.html "css/css-pseudo/first-letter-block-to-inline.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-block-to-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-block-to-inline.html)
- [first-letter-crash.html](https://wpt.fyi/results/css/css-pseudo/first-letter-crash.html "css/css-pseudo/first-letter-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-crash.html)
- [first-letter-digraph.html](https://wpt.fyi/results/css/css-pseudo/first-letter-digraph.html "css/css-pseudo/first-letter-digraph.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-digraph.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-digraph.html)
- [first-letter-exclude-block-child-marker.html](https://wpt.fyi/results/css/css-pseudo/first-letter-exclude-block-child-marker.html "css/css-pseudo/first-letter-exclude-block-child-marker.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-exclude-block-child-marker.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-exclude-block-child-marker.html)
- [first-letter-exclude-inline-child-marker.html](https://wpt.fyi/results/css/css-pseudo/first-letter-exclude-inline-child-marker.html "css/css-pseudo/first-letter-exclude-inline-child-marker.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-exclude-inline-child-marker.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-exclude-inline-child-marker.html)
- [first-letter-exclude-inline-marker.html](https://wpt.fyi/results/css/css-pseudo/first-letter-exclude-inline-marker.html "css/css-pseudo/first-letter-exclude-inline-marker.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-exclude-inline-marker.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-exclude-inline-marker.html)
- [first-letter-first-line-dynamic-001-crash.html](https://wpt.fyi/results/css/css-pseudo/first-letter-first-line-dynamic-001-crash.html "css/css-pseudo/first-letter-first-line-dynamic-001-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-first-line-dynamic-001-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-first-line-dynamic-001-crash.html)
- [first-letter-hi-001.html](https://wpt.fyi/results/css/css-pseudo/first-letter-hi-001.html "css/css-pseudo/first-letter-hi-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-hi-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-hi-001.html)
- [first-letter-hi-002.html](https://wpt.fyi/results/css/css-pseudo/first-letter-hi-002.html "css/css-pseudo/first-letter-hi-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-hi-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-hi-002.html)
- [first-letter-list-item-dynamic-001.html](https://wpt.fyi/results/css/css-pseudo/first-letter-list-item-dynamic-001.html "css/css-pseudo/first-letter-list-item-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-list-item-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-list-item-dynamic-001.html)
- [first-letter-of-html-root-refcrash.html](https://wpt.fyi/results/css/css-pseudo/first-letter-of-html-root-refcrash.html "css/css-pseudo/first-letter-of-html-root-refcrash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-of-html-root-refcrash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-of-html-root-refcrash.html)
- [first-letter-opacity-001-ref.html](https://wpt.fyi/results/css/css-pseudo/first-letter-opacity-001-ref.html "css/css-pseudo/first-letter-opacity-001-ref.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-opacity-001-ref.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-opacity-001-ref.html)
- [first-letter-opacity-001.html](https://wpt.fyi/results/css/css-pseudo/first-letter-opacity-001.html "css/css-pseudo/first-letter-opacity-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-opacity-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-opacity-001.html)
- [first-letter-opacity-float-001.html](https://wpt.fyi/results/css/css-pseudo/first-letter-opacity-float-001.html "css/css-pseudo/first-letter-opacity-float-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-opacity-float-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-opacity-float-001.html)
- [first-letter-punctuation-and-space.html](https://wpt.fyi/results/css/css-pseudo/first-letter-punctuation-and-space.html "css/css-pseudo/first-letter-punctuation-and-space.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-punctuation-and-space.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-punctuation-and-space.html)
- [first-letter-punctuation-dynamic.html](https://wpt.fyi/results/css/css-pseudo/first-letter-punctuation-dynamic.html "css/css-pseudo/first-letter-punctuation-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-punctuation-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-punctuation-dynamic.html)
- [first-letter-skip-empty-span-nested.html](https://wpt.fyi/results/css/css-pseudo/first-letter-skip-empty-span-nested.html "css/css-pseudo/first-letter-skip-empty-span-nested.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-skip-empty-span-nested.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-skip-empty-span-nested.html)
- [first-letter-skip-empty-span.html](https://wpt.fyi/results/css/css-pseudo/first-letter-skip-empty-span.html "css/css-pseudo/first-letter-skip-empty-span.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-skip-empty-span.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-skip-empty-span.html)
- [first-letter-skip-marker.html](https://wpt.fyi/results/css/css-pseudo/first-letter-skip-marker.html "css/css-pseudo/first-letter-skip-marker.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-skip-marker.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-skip-marker.html)
- [first-letter-text-and-display-change.html](https://wpt.fyi/results/css/css-pseudo/first-letter-text-and-display-change.html "css/css-pseudo/first-letter-text-and-display-change.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-text-and-display-change.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-text-and-display-change.html)
- [first-letter-width-2.html](https://wpt.fyi/results/css/css-pseudo/first-letter-width-2.html "css/css-pseudo/first-letter-width-2.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-width-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-width-2.html)
- [first-letter-width.html](https://wpt.fyi/results/css/css-pseudo/first-letter-width.html "css/css-pseudo/first-letter-width.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-width.html)
- [first-letter-with-before-after.html](https://wpt.fyi/results/css/css-pseudo/first-letter-with-before-after.html "css/css-pseudo/first-letter-with-before-after.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-with-before-after.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-with-before-after.html)
- [first-letter-with-preceding-new-line.html](https://wpt.fyi/results/css/css-pseudo/first-letter-with-preceding-new-line.html "css/css-pseudo/first-letter-with-preceding-new-line.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-with-preceding-new-line.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-with-preceding-new-line.html)
- [first-letter-with-quote.html](https://wpt.fyi/results/css/css-pseudo/first-letter-with-quote.html "css/css-pseudo/first-letter-with-quote.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-with-quote.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-with-quote.html)
- [first-letter-with-span.html](https://wpt.fyi/results/css/css-pseudo/first-letter-with-span.html "css/css-pseudo/first-letter-with-span.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/first-letter-with-span.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/first-letter-with-span.html)

![A drop-cap initial letter, including the opening quotation mark before
it.](images/first-letter2.gif){height="72" width="114"}

The [::first-letter]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) represents the first Letter, Number, or Symbol (Unicode
category `L*`, `N*`, or `S*`)
[typographic character
unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit) on the [first formatted
line](#first-formatted-line) of its [originating
element](https://drafts.csswg.org/selectors-4/#originating-element) (the [first letter]) as well as its associated punctuation.
Collectively, this text is the [first-letter text]. The
[::first-letter](#selectordef-first-letter) pseudo-element can be used to create "initial
caps" and "drop caps", which are common typographic effects.

For example, the following rule
creates a 2-line drop-letter on every paragraph following a level-2
header, using the
[initial-letter](https://drafts.csswg.org/css-inline-3/#propdef-initial-letter) property defined in
[\[CSS-INLINE-3\]](#biblio-css-inline-3 "CSS Inline Layout Module Level 3"):

```
h2 + p::first-letter { initial-letter: 3; }
```

 The [first letter](#first-letter) may in fact be a digit, e.g., the "6" in "67 million
dollars is a lot of money."

To allow independent styling of the [first
letter](#first-letter) itself
and its adjacent punctuation, associated preceding punctuation is
represented by the [::prefix]
[sub-pseudo-element](https://drafts.csswg.org/selectors-4/#sub-pseudo-element) of the
[::first-letter](#selectordef-first-letter)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) ([::first-letter::prefix]); and associated
following punctuation is represented by the
[::suffix]
[sub-pseudo-element] of the
[::first-letter]
[pseudo-element]
([::first-letter::suffix]). See [§ 2.2.1 First Letters and
Associated Punctuation](#first-letter-pattern), below.

#### 2.2.1. First Letters and Associated Punctuation

As explained in [CSS Text 3 § 1.4 Characters and
Letters](https://drafts.csswg.org/css-text-3/#characters), a
[typographic character
unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit) can include more than one Unicode codepoint. For
example, combining characters must be kept with their base character.
Also, languages may have additional rules about how to treat certain
letter combinations. In Dutch, for example, if the letter combination
\"ij\" appears at the beginning of an element, both letters should be
considered within the
[::first-letter](#selectordef-first-letter)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element).
[\[UAX29\]](#biblio-uax29 "Unicode Text Segmentation")
When selecting the [first letter](#first-letter), the UA should tailor its definition of [typographic
character unit] to reflect the
first-letter traditions of the
[::first-letter]
pseudo-element's *[containing
block](https://drafts.csswg.org/css-display-4/#containing-block)*'s [content
language](https://drafts.csswg.org/css-text-4/#content-language).

Preceding and following punctuation must also be included as part of the
[first-letter text](#first-letter-text) in the
[::first-letter](#selectordef-first-letter) pseudo-element as follows:

- All punctuation---​i.e, characters that belong to the Punctuation
 (`P*`) [Unicode general
 category](https://drafts.csswg.org/css-text-4/#unicode-general-category)
 [\[UAX44\]](#biblio-uax44 "Unicode Character Database")---​that
 precedes the [first letter](#first-letter), as well as any intervening typographic
 space---​characters belonging to the `Zs` Unicode general
 category
 [\[UAX44\]](#biblio-uax44 "Unicode Character Database")
 *other than* U+3000 IDEOGRAPHIC SPACE.
- Any punctuation other than opening punctuation and dashes---​i.e.
 characters that belong to the Punctuation (`P*`) [Unicode
 general
 category](https://drafts.csswg.org/css-text-4/#unicode-general-category), excluding Open Punctuation (`Ps`) and
 Dash Punctuation (`Pd`)---​that follows the [first
 letter](#first-letter), as
 well as any intervening typographic space---​characters belonging to
 the `Zs` Unicode general category
 [\[UAX44\]](#biblio-uax44 "Unicode Character Database")
 *other than* U+3000 IDEOGRAPHIC SPACE or a [word
 separator](https://drafts.csswg.org/css-text-4/#word-separator).

Informally, the [first-letter
text](#first-letter-text)'s
pattern here can be roughly (ignoring the exclusions from
`Zs`) represented as a "regular expression"
` (P (Zs|P)*)? (L|N|S) ((Zs|P−(Ps|Pd))* (P−(Ps|Pd))?`---​or, alternatively,
` ([P] [Zs P]*)? [L N S] ([Zs [P--[Ps Pd]]]* [P--[Ps Pd]])?`---​where the Unicode category abbreviation
represents the set of all [typographic character
units](https://drafts.csswg.org/css-text-4/#typographic-character-unit) belonging to that category.

!(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxMzkiIHZpZXdib3g9IjAgMCA3NzUuMCAxMzkiIHdpZHRoPSI3NzUuMCI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKC41IC41KSI+CiAgICAgICA8Zz4KICAgICAgICA8cGF0aCBkPSJNMjAgMzh2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICA8L2c+CiAgICAgICA8Zz4KICAgICAgICA8cGF0aCBkPSJNNDAgNDhoMC4wIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0yNTUuNSA0OGgwLjAiIC8+CiAgICAgICAgPHBhdGggZD0iTTQwLjAgNDhhMTAgMTAgMCAwIDAgMTAgLTEwdi04YTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTYwLjAgMjBoMTc1LjUiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0yMzUuNSAyMGExMCAxMCAwIDAgMSAxMCAxMHY4YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgIDxwYXRoIGQ9Ik00MC4wIDQ4aDIwIiAvPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNNjAuMCA0OGgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0yMzUuNSA0OGgwLjAiIC8+CiAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgNDhoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTg4LjUgNDhoMC4wIiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjI4LjUiIHg9IjYwIiB5PSIzNyIgLz4KICAgICAgICAgIDx0ZXh0IHg9Ijc0LjI1IiB5PSI1MiI+UDwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNODguNSA0OGgxMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNOTguNSA0OGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMjM1LjUgNDhoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTk4LjUgNDhhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTExOC41IDI4aDk3LjAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMjE1LjUgMjhhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik05OC41IDQ4aDIwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTExOC41IDQ4aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjE1LjUgNDhoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0xMTguNSA0OGgxMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTEyOC41IDQ4aDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTIwNS41IDQ4aDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTEyOC41IDQ4aDIwIiAvPgogICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0xNDguNSA0OGg0LjI1IiAvPgogICAgICAgICAgICAgPHBhdGggZD0iTTE4MS4yNSA0OGg0LjI1IiAvPgogICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjI4LjUiIHg9IjE1Mi43NSIgeT0iMzciIC8+CiAgICAgICAgICAgICA8dGV4dCB4PSIxNjciIHk9IjUyIj5QPC90ZXh0PgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xODUuNSA0OGgyMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTEyOC41IDQ4YTEwIDEwIDAgMCAxIDEwIDEwdjEwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0xNDguNSA3OGgwLjAiIC8+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMTg1LjUgNzhoMC4wIiAvPgogICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjM3IiB4PSIxNDguNSIgeT0iNjciIC8+CiAgICAgICAgICAgICA8dGV4dCB4PSIxNjciIHk9IjgyIj5aczwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMTg1LjUgNzhhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMDUuNSA0OGgxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgNDhhMTAgMTAgMCAwIDAgLTEwIDEwdjI5YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgOTdoNzcuMCIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTIwNS41IDk3YTEwIDEwIDAgMCAwIDEwIC0xMHYtMjlhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yMTUuNSA0OGgyMCIgLz4KICAgICAgICAgPC9nPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMjM1LjUgNDhoMjAiIC8+CiAgICAgICA8L2c+CiAgICAgICA8Zz4KICAgICAgICA8cGF0aCBkPSJNMjU1LjUgNDhoMC4wIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0zMjQuMCA0OGgwLjAiIC8+CiAgICAgICAgPHBhdGggZD0iTTI1NS41IDQ4aDIwIiAvPgogICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNMjc1LjUgNDhoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMzA0LjAgNDhoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMjguNSIgeD0iMjc1LjUiIHk9IjM3IiAvPgogICAgICAgICA8dGV4dCB4PSIyODkuNzUiIHk9IjUyIj5MPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMzA0LjAgNDhoMjAiIC8+CiAgICAgICAgPHBhdGggZD0iTTI1NS41IDQ4YTEwIDEwIDAgMCAxIDEwIDEwdjEwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNMjc1LjUgNzhoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMzA0LjAgNzhoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMjguNSIgeD0iMjc1LjUiIHk9IjY3IiAvPgogICAgICAgICA8dGV4dCB4PSIyODkuNzUiIHk9IjgyIj5OPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMzA0LjAgNzhhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTTI1NS41IDQ4YTEwIDEwIDAgMCAxIDEwIDEwdjQwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNMjc1LjUgMTA4aDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTMwNC4wIDEwOGgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIyOC41IiB4PSIyNzUuNSIgeT0iOTciIC8+CiAgICAgICAgIDx0ZXh0IHg9IjI4OS43NSIgeT0iMTEyIj5TPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMzA0LjAgMTA4YTEwIDEwIDAgMCAwIDEwIC0xMHYtNDBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgPC9nPgogICAgICAgPGc+CiAgICAgICAgPHBhdGggZD0iTTMyNC4wIDQ4aDAuMCIgLz4KICAgICAgICA8cGF0aCBkPSJNNzM1LjAgNDhoMC4wIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0zMjQuMCA0OGExMCAxMCAwIDAgMCAxMCAtMTB2LThhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMzQ0LjAgMjBoMzcxLjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik03MTUuMCAyMGExMCAxMCAwIDAgMSAxMCAxMHY4YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0zMjQuMCA0OGgyMCIgLz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTM0NC4wIDQ4aDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTcxNS4wIDQ4aDAuMCIgLz4KICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICA8cGF0aCBkPSJNMzQ0LjAgNDhoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTQ3NC41IDQ4aDAuMCIgLz4KICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxMzAuNSIgeD0iMzQ0IiB5PSIzNyIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjQwOS4yNSIgeT0iNTIiPlAg4oiSIChQcyDiiKogUGQpPC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik00NzQuNSA0OGgxMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNNDg0LjUgNDhoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTcxNS4wIDQ4aDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik00ODQuNSA0OGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNNTA0LjUgMjhoMTkwLjUiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNNjk1LjAgMjhhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik00ODQuNSA0OGgyMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik01MDQuNSA0OGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTY5NS4wIDQ4aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNNTA0LjUgNDhoMTAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik01MTQuNSA0OGgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik02ODUuMCA0OGgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik01MTQuNSA0OGgyMCIgLz4KICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICA8cGF0aCBkPSJNNTM0LjUgNDhoMC4wIiAvPgogICAgICAgICAgICAgPHBhdGggZD0iTTY2NS4wIDQ4aDAuMCIgLz4KICAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxMzAuNSIgeD0iNTM0LjUiIHk9IjM3IiAvPgogICAgICAgICAgICAgPHRleHQgeD0iNTk5Ljc1IiB5PSI1MiI+UCDiiJIgKFBzIOKIqiBQZCk8L3RleHQ+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTY2NS4wIDQ4aDIwIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNTE0LjUgNDhhMTAgMTAgMCAwIDEgMTAgMTB2MTBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgPHBhdGggZD0iTTUzNC41IDc4aDQ2Ljc1IiAvPgogICAgICAgICAgICAgPHBhdGggZD0iTTYxOC4yNSA3OGg0Ni43NSIgLz4KICAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIzNyIgeD0iNTgxLjI1IiB5PSI2NyIgLz4KICAgICAgICAgICAgIDx0ZXh0IHg9IjU5OS43NSIgeT0iODIiPlpzPC90ZXh0PgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik02NjUuMCA3OGExMCAxMCAwIDAgMCAxMCAtMTB2LTEwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTY4NS4wIDQ4aDEwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik01MTQuNSA0OGExMCAxMCAwIDAgMCAtMTAgMTB2MjlhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik01MTQuNSA5N2gxNzAuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTY4NS4wIDk3YTEwIDEwIDAgMCAwIDEwIC0xMHYtMjlhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik02OTUuMCA0OGgyMCIgLz4KICAgICAgICAgPC9nPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNzE1LjAgNDhoMjAiIC8+CiAgICAgICA8L2c+CiAgICAgICA8cGF0aCBkPSJNIDczNS4wIDQ4IGggMjAgbSAtMTAgLTEwIHYgMjAgbSAxMCAtMjAgdiAyMCIgLz4KICAgICAgPC9nPgogICAgIDwvc3ZnPg==)

See [CSS Text 3 § 1.4 Characters and
Letters](https://drafts.csswg.org/css-text-3/#characters) and [CSS Text
3 § E Characters and
Properties](https://drafts.csswg.org/css-text-3/#character-properties)
for more information on [typographic character
units](https://drafts.csswg.org/css-text-4/#typographic-character-unit) and their Unicode properties.
[\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3")

#### 2.2.2. Finding the First-Letter Text

As with
[::first-line](#selectordef-first-line), the
[::first-letter](#selectordef-first-letter)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) can only have an effect when attached to a [block
container](https://drafts.csswg.org/css-display-4/#block-container). Its [first-letter
text](#first-letter-text)
is the first such [inline-level
content](https://drafts.csswg.org/css-display-4/#inline-level) participating in the [inline formatting
context](https://drafts.csswg.org/css-display-4/#inline-formatting-context) of its [originating
element](https://drafts.csswg.org/selectors-4/#originating-element)'s [first formatted
line](#first-formatted-line), if it is not preceded by any other
[in-flow](https://drafts.csswg.org/css-display-4/#in-flow) content (such as images or inline tables) on its line.

For this purpose, any [marker
boxes](https://drafts.csswg.org/css-lists-3/#marker) are ignored, as if they were
[out-of-flow](https://drafts.csswg.org/css-display-4/#out-of-flow). However, if an element has
[in-flow](https://drafts.csswg.org/css-display-4/#in-flow)
[::before](#selectordef-before) or
[::after](#selectordef-after) content, the [first-letter
text](#first-letter-text)
is selected from the content of the element *including* that generated
content.

Example: After the rule
`p::before {content: "Note: "}`, the selector
[p::first-letter] matches the \"N\" of \"Note\".

If no qualifying text exists, then there is no [first-letter
text](#first-letter-text)
and no
[::first-letter](#selectordef-first-letter) pseudo-element.

 When the [first formatted
line](#first-formatted-line) is empty,
[::first-letter](#selectordef-first-letter) will not match anything. For example, in this
HTML fragment: `<p><br>First...` the first line
doesn't contain any letters, so
[::first-letter] doesn't match
anything. In particular, it does not match the "F" of "First", which is
on the second line.

 As with
[::first-line](#selectordef-first-line), the [first-letter
text](#first-letter-text)
of a [block
container](https://drafts.csswg.org/css-display-4/#block-container) that does not participate in a [block formatting
context](https://drafts.csswg.org/css-display-4/#block-formatting-context) cannot be the [first-letter
text] of an ancestor element. Thus, in
`<DIV><P STYLE="display: inline-block">Hello<BR>Goodbye</P> etcetera</DIV>` the [first letter](#first-letter) of the `DIV` is not the letter "H". In
fact, the `DIV` doesn't have a [first
letter].

Any portion of the [first-letter
text](#first-letter-text)
that is wrapped to the next line no longer forms part of the
[::first-letter](#selectordef-first-letter)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element).

#### 2.2.3. Inheritance and Box Tree Structure of the First-Letter Pseudo-elements

The
[::first-letter](#selectordef-first-letter)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) is wrapped immediately around the [first-letter
text](#first-letter-text)
it represents, even if that text is in a descendant. When a
[first-letter text] is represented by
multiple [::first-letter]
pseudo-elements, they are nested in the same order as their [originating
elements](https://drafts.csswg.org/selectors-4/#originating-element).
[Inheritance](https://drafts.csswg.org/css-cascade-5/#css-inheritance) behaves accordingly.

Consider the following markup:

```
<div>
 <p><span>The first few words</span>
 and the rest of the paragraph.
</div>
```

If we assume a [fictional tag
sequence](#fictional-tag-sequence) to represent the elements'
[::first-letter](#selectordef-first-letter) pseudo-elements, it would be something like:

``` highlight
<div>
 <p><span><div::first-letter><p::first-letter>T</…></…>he first few words</span>
 and the rest of the paragraph.
</div>
```

If any [::first-letter::prefix] or [::first-letter::suffix]
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) exist, they are nested within the innermost
[::first-letter](#selectordef-first-letter), and otherwise interpreted similar to
[::first-letter] itself.

Consider the following markup:

```
<div>
 <p><span>“The first few words</span>
 and the rest of the quotation.
</div>
```

If we assume a [fictional tag
sequence](#fictional-tag-sequence) to represent the elements'
[::first-letter](#selectordef-first-letter) pseudo-elements, it would be something like:

``` highlight
<div>
 <p><span><div::first-letter><p::first-letter><div::first-letter::prefix><p::first-letter::prefix>“</…></…>T</…></…>he first few words</span>
 and the rest of the paragraph.
</div>
```

If the characters that would form the [first-letter
text](#first-letter-text)
are not all in the same element (as the `‘T` in
`<p>‘<em>T...`), the user agent may create the
[::first-letter](#selectordef-first-letter)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) (and its
[::prefix](#selectordef-first-letter-prefix) or
[::suffix](#selectordef-first-letter-suffix) sub-elements, if any) from one of the elements,
or all elements, or simply not create the pseudo-element(s).
Additionally, if the [first-letter text]
is not at the start of the line (for example due to bidirectional
reordering, or due to a [list
item](https://drafts.csswg.org/css-lists-3/#list-item)
[marker](https://drafts.csswg.org/css-lists-3/#marker) with [list-style-position:
inside](https://drafts.csswg.org/css-lists-3/#propdef-list-style-position)), then the user agent is not required to
create the pseudo-element(s).

A
[::first-letter](#selectordef-first-letter) pseudo-element is contained within any
[::first-line](#selectordef-first-line) pseudo-elements, and thus inherits (potentially
indirectly) from [::first-line],
the same as any [inline
box](https://drafts.csswg.org/css-display-4/#inline-box) on the same line.

#### 2.2.4. Styling the First-Letter Pseudo-elements

In CSS a
[::first-letter](#selectordef-first-letter)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) (and its
[::prefix](#selectordef-first-letter-prefix) and
[::suffix](#selectordef-first-letter-suffix) sub-elements) is similar to an [inline
box](https://drafts.csswg.org/css-display-4/#inline-box). The following properties apply to
[::first-letter],
[::first-letter::prefix], and [::first-letter::suffix]
pseudo-elements:

- all font properties (see
 [\[CSS-FONTS-4\]](#biblio-css-fonts-4 "CSS Fonts Module Level 4"))
- the
 [color](https://drafts.csswg.org/css-color-4/#propdef-color) and
 [opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity) properties (see
 [\[CSS-COLOR-4\]](#biblio-css-color-4 "CSS Color Module Level 4"))
- all background properties (see
 [\[CSS-BACKGROUNDS-4\]](#biblio-css-backgrounds-4 "CSS Backgrounds and Borders Module Level 4"))
- any typesetting properties that apply to inline elements (see
 [\[CSS-TEXT-4\]](#biblio-css-text-4 "CSS Text Module Level 4"))
- all text decoration properties (see
 [\[CSS-TEXT-DECOR-4\]](#biblio-css-text-decor-4 "CSS Text Decoration Module Level 4"))
- any inline layout properties that apply to inline elements (see
 [\[CSS-INLINE-3\]](#biblio-css-inline-3 "CSS Inline Layout Module Level 3"))
- margin and padding properties (see
 [\[CSS22\]](#biblio-css22 "Cascading Style Sheets Level 2 Revision 2 (CSS 2.2) Specification"))
- border properties and
 [box-shadow](https://drafts.csswg.org/css-backgrounds-3/#propdef-box-shadow) (see
 [\[CSS-BACKGROUNDS-4\]](#biblio-css-backgrounds-4 "CSS Backgrounds and Borders Module Level 4"))
- any other properties defined to apply to
 [::first-letter](#selectordef-first-letter) by their respective specifications

User agents may apply other properties as well. However, in no case may
the application of such unlisted properties to
[::first-letter](#selectordef-first-letter) change what [first-letter
text](#first-letter-text)
is represented by that
[::first-letter].

 In previous levels of CSS, user agents were allowed to
choose a line height, width, and height based on the shape of the
letter, to approximate font sizes; and to take the glyph outline into
account when performing layout. The possibility of such loosely-defined
magic has been intentionally removed, as it proved to be a poor solution
for the intended use case (drop caps and raised caps), yet caused
interoperability problems. See
[initial-letter](https://drafts.csswg.org/css-inline-3/#propdef-initial-letter) in
[\[CSS-INLINE-3\]](#biblio-css-inline-3 "CSS Inline Layout Module Level 3")
for explicitly handling drop caps and raised caps.

## 3. Highlight Pseudo-elements

### 3.1. Selecting Highlighted Content: the [::selection, [::search-text](#selectordef-search-text), [::target-text](#selectordef-target-text), [::spelling-error](#selectordef-spelling-error), [::grammar-error](#selectordef-grammar-error), and [::highlight()](#selectordef-highlight-highlight-name-selector) pseudo-elements]
Tests

- [grammar-spelling-errors-001.html](https://wpt.fyi/results/css/css-pseudo/grammar-spelling-errors-001.html "css/css-pseudo/grammar-spelling-errors-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/grammar-spelling-errors-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/grammar-spelling-errors-001.html)
- [grammar-spelling-errors-002.html](https://wpt.fyi/results/css/css-pseudo/grammar-spelling-errors-002.html "css/css-pseudo/grammar-spelling-errors-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/grammar-spelling-errors-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/grammar-spelling-errors-002.html)
- [cascade-highlight-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/cascade-highlight-001.html "css/css-pseudo/highlight-cascade/cascade-highlight-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/cascade-highlight-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/cascade-highlight-001.html)
- [cascade-highlight-002.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/cascade-highlight-002.html "css/css-pseudo/highlight-cascade/cascade-highlight-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/cascade-highlight-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/cascade-highlight-002.html)
- [cascade-highlight-004.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/cascade-highlight-004.html "css/css-pseudo/highlight-cascade/cascade-highlight-004.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/cascade-highlight-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/cascade-highlight-004.html)
- [cascade-highlight-005.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/cascade-highlight-005.html "css/css-pseudo/highlight-cascade/cascade-highlight-005.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/cascade-highlight-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/cascade-highlight-005.html)
- [highlight-cascade-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-cascade-001.html "css/css-pseudo/highlight-cascade/highlight-cascade-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-cascade-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-cascade-001.html)
- [highlight-cascade-003.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-cascade-003.html "css/css-pseudo/highlight-cascade/highlight-cascade-003.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-cascade-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-cascade-003.html)
- [highlight-cascade-004.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-cascade-004.html "css/css-pseudo/highlight-cascade/highlight-cascade-004.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-cascade-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-cascade-004.html)
- [highlight-cascade-005.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-cascade-005.html "css/css-pseudo/highlight-cascade/highlight-cascade-005.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-cascade-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-cascade-005.html)
- [highlight-cascade-006.xhtml](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-cascade-006.xhtml "css/css-pseudo/highlight-cascade/highlight-cascade-006.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-cascade-006.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-cascade-006.xhtml)
- [highlight-cascade-007.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-cascade-007.html "css/css-pseudo/highlight-cascade/highlight-cascade-007.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-cascade-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-cascade-007.html)
- [highlight-cascade-008.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-cascade-008.html "css/css-pseudo/highlight-cascade/highlight-cascade-008.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-cascade-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-cascade-008.html)
- [highlight-cascade-009.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-cascade-009.html "css/css-pseudo/highlight-cascade/highlight-cascade-009.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-cascade-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-cascade-009.html)
- [highlight-currentcolor-computed-inheritance.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-currentcolor-computed-inheritance.html "css/css-pseudo/highlight-cascade/highlight-currentcolor-computed-inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-currentcolor-computed-inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-currentcolor-computed-inheritance.html)
- [highlight-currentcolor-computed-visited.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-currentcolor-computed-visited.html "css/css-pseudo/highlight-cascade/highlight-currentcolor-computed-visited.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-currentcolor-computed-visited.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-currentcolor-computed-visited.html)
- [highlight-currentcolor-computed.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-currentcolor-computed.html "css/css-pseudo/highlight-cascade/highlight-currentcolor-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-currentcolor-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-currentcolor-computed.html)
- [highlight-currentcolor-painting-properties-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-properties-001.html "css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-properties-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-properties-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-properties-001.html)
- [highlight-currentcolor-painting-properties-002.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-properties-002.html "css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-properties-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-properties-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-properties-002.html)
- [highlight-currentcolor-painting-text-shadow-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-text-shadow-001.html "css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-text-shadow-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-text-shadow-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-text-shadow-001.html)
- [highlight-currentcolor-painting-text-shadow-002.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-text-shadow-002.html "css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-text-shadow-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-text-shadow-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-currentcolor-painting-text-shadow-002.html)
- [highlight-currentcolor-root-explicit-default-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-currentcolor-root-explicit-default-001.html "css/css-pseudo/highlight-cascade/highlight-currentcolor-root-explicit-default-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-currentcolor-root-explicit-default-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-currentcolor-root-explicit-default-001.html)
- [highlight-currentcolor-root-explicit-default-002.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-currentcolor-root-explicit-default-002.html "css/css-pseudo/highlight-cascade/highlight-currentcolor-root-explicit-default-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-currentcolor-root-explicit-default-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-currentcolor-root-explicit-default-002.html)
- [highlight-currentcolor-root-implicit-default-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-currentcolor-root-implicit-default-001.html "css/css-pseudo/highlight-cascade/highlight-currentcolor-root-implicit-default-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-currentcolor-root-implicit-default-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-currentcolor-root-implicit-default-001.html)
- [highlight-currentcolor-root-implicit-default-002.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-currentcolor-root-implicit-default-002.html "css/css-pseudo/highlight-cascade/highlight-currentcolor-root-implicit-default-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-currentcolor-root-implicit-default-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-currentcolor-root-implicit-default-002.html)
- [highlight-pseudos-computed.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-pseudos-computed.html "css/css-pseudo/highlight-cascade/highlight-pseudos-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-pseudos-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-pseudos-computed.html)
- [highlight-pseudos-inheritance-computed-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-pseudos-inheritance-computed-001.html "css/css-pseudo/highlight-cascade/highlight-pseudos-inheritance-computed-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-pseudos-inheritance-computed-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-pseudos-inheritance-computed-001.html)
- [highlight-pseudos-visited-computed-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-pseudos-visited-computed-001.html "css/css-pseudo/highlight-cascade/highlight-pseudos-visited-computed-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-pseudos-visited-computed-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-pseudos-visited-computed-001.html)
- [highlight-custom-properties-dynamic-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-custom-properties-dynamic-001.html "css/css-pseudo/highlight-custom-properties-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-custom-properties-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-custom-properties-dynamic-001.html)
- [highlight-painting-005-crash.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-005-crash.html "css/css-pseudo/highlight-painting-005-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-005-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-005-crash.html)
- [highlight-painting-currentcolor-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-currentcolor-001.html "css/css-pseudo/highlight-painting-currentcolor-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-currentcolor-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-currentcolor-001.html)
- [highlight-painting-currentcolor-001a.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-currentcolor-001a.html "css/css-pseudo/highlight-painting-currentcolor-001a.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-currentcolor-001a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-currentcolor-001a.html)
- [highlight-painting-currentcolor-002.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-currentcolor-002.html "css/css-pseudo/highlight-painting-currentcolor-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-currentcolor-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-currentcolor-002.html)
- [highlight-painting-currentcolor-002a.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-currentcolor-002a.html "css/css-pseudo/highlight-painting-currentcolor-002a.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-currentcolor-002a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-currentcolor-002a.html)
- [highlight-painting-currentcolor-002b.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-currentcolor-002b.html "css/css-pseudo/highlight-painting-currentcolor-002b.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-currentcolor-002b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-currentcolor-002b.html)
- [highlight-painting-currentcolor-003.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-currentcolor-003.html "css/css-pseudo/highlight-painting-currentcolor-003.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-currentcolor-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-currentcolor-003.html)
- [highlight-painting-currentcolor-003a.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-currentcolor-003a.html "css/css-pseudo/highlight-painting-currentcolor-003a.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-currentcolor-003a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-currentcolor-003a.html)
- [highlight-painting-currentcolor-003b.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-currentcolor-003b.html "css/css-pseudo/highlight-painting-currentcolor-003b.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-currentcolor-003b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-currentcolor-003b.html)
- [highlight-painting-currentcolor-004.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-currentcolor-004.html "css/css-pseudo/highlight-painting-currentcolor-004.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-currentcolor-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-currentcolor-004.html)
- [highlight-painting-currentcolor-004a.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-currentcolor-004a.html "css/css-pseudo/highlight-painting-currentcolor-004a.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-currentcolor-004a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-currentcolor-004a.html)
- [highlight-painting-currentcolor-004b.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-currentcolor-004b.html "css/css-pseudo/highlight-painting-currentcolor-004b.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-currentcolor-004b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-currentcolor-004b.html)
- [highlight-painting-currentcolor-005.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-currentcolor-005.html "css/css-pseudo/highlight-painting-currentcolor-005.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-currentcolor-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-currentcolor-005.html)
- [highlight-painting-shadows-horizontal.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-shadows-horizontal.html "css/css-pseudo/highlight-painting-shadows-horizontal.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-shadows-horizontal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-shadows-horizontal.html)
- [highlight-painting-shadows-vertical.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-shadows-vertical.html "css/css-pseudo/highlight-painting-shadows-vertical.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-shadows-vertical.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-shadows-vertical.html)
- [highlight-painting-soft-hyphens-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-soft-hyphens-001.html "css/css-pseudo/highlight-painting-soft-hyphens-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-soft-hyphens-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-soft-hyphens-001.html)
- [highlight-painting-soft-hyphens-002-crash.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-soft-hyphens-002-crash.html "css/css-pseudo/highlight-painting-soft-hyphens-002-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-soft-hyphens-002-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-soft-hyphens-002-crash.html)
- [highlight-styling-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-styling-001.html "css/css-pseudo/highlight-styling-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-styling-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-styling-001.html)
- [highlight-styling-002.html](https://wpt.fyi/results/css/css-pseudo/highlight-styling-002.html "css/css-pseudo/highlight-styling-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-styling-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-styling-002.html)
- [highlight-pseudos.html](https://wpt.fyi/results/css/css-pseudo/parsing/highlight-pseudos.html "css/css-pseudo/parsing/highlight-pseudos.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/parsing/highlight-pseudos.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/parsing/highlight-pseudos.html)

The [highlight pseudo-elements]
represent portions of a document that have been given a particular
status and are typically styled differently to indicate that status to
the user. For example, selected portions of the document are typically
highlighted (given alternate background and foreground colors, or a
color wash) to indicate their selected status. The following [highlight
pseudo-elements](#highlight-pseudo-element) are defined:

[::selection]
: The
 [::selection](#selectordef-selection)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) represents the portion of a document that has been
 selected as the target or object of some possible future user-agent
 operation(s). It applies, for example, to selected text within an
 editable text field, which would be copied by a copy operation or
 replaced by a paste operation.
 Tests
 - [active-selection-001-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-001-manual.html)
 - [active-selection-002-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-002-manual.html)
 - [active-selection-004-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-004-manual.html)
 - [active-selection-011.html](https://wpt.fyi/results/css/css-pseudo/active-selection-011.html "css/css-pseudo/active-selection-011.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-011.html)
 - [active-selection-012.html](https://wpt.fyi/results/css/css-pseudo/active-selection-012.html "css/css-pseudo/active-selection-012.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-012.html)
 - [active-selection-014.html](https://wpt.fyi/results/css/css-pseudo/active-selection-014.html "css/css-pseudo/active-selection-014.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-014.html)
 - [active-selection-016.html](https://wpt.fyi/results/css/css-pseudo/active-selection-016.html "css/css-pseudo/active-selection-016.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-016.html)
 - [active-selection-018.html](https://wpt.fyi/results/css/css-pseudo/active-selection-018.html "css/css-pseudo/active-selection-018.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-018.html)
 - [active-selection-025.html](https://wpt.fyi/results/css/css-pseudo/active-selection-025.html "css/css-pseudo/active-selection-025.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-025.html)
 - [active-selection-027.html](https://wpt.fyi/results/css/css-pseudo/active-selection-027.html "css/css-pseudo/active-selection-027.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-027.html)
 - [active-selection-056.html](https://wpt.fyi/results/css/css-pseudo/active-selection-056.html "css/css-pseudo/active-selection-056.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-056.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-056.html)
 - [active-selection-057.html](https://wpt.fyi/results/css/css-pseudo/active-selection-057.html "css/css-pseudo/active-selection-057.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-057.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-057.html)
 - [active-selection-063.html](https://wpt.fyi/results/css/css-pseudo/active-selection-063.html "css/css-pseudo/active-selection-063.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-063.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-063.html)
 - [selection-background-color-001.html](https://wpt.fyi/results/css/css-pseudo/selection-background-color-001.html "css/css-pseudo/selection-background-color-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-background-color-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-background-color-001.html)
 - [selection-link-001.html](https://wpt.fyi/results/css/css-pseudo/selection-link-001.html "css/css-pseudo/selection-link-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-link-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-link-001.html)
 - [selection-link-002.html](https://wpt.fyi/results/css/css-pseudo/selection-link-002.html "css/css-pseudo/selection-link-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-link-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-link-002.html)
 - [selection-link-003.html](https://wpt.fyi/results/css/css-pseudo/selection-link-003.html "css/css-pseudo/selection-link-003.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-link-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-link-003.html)
 - [selection-over-highlight-001.html](https://wpt.fyi/results/css/css-pseudo/selection-over-highlight-001.html "css/css-pseudo/selection-over-highlight-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-over-highlight-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-over-highlight-001.html)
 - [selection-universal-shadow-dom.html](https://wpt.fyi/results/css/css-pseudo/selection-universal-shadow-dom.html "css/css-pseudo/selection-universal-shadow-dom.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-universal-shadow-dom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-universal-shadow-dom.html)
 - [selection-contenteditable-011.html](https://wpt.fyi/results/css/css-pseudo/selection-contenteditable-011.html "css/css-pseudo/selection-contenteditable-011.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-contenteditable-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-contenteditable-011.html)
 - [selection-input-011.html](https://wpt.fyi/results/css/css-pseudo/selection-input-011.html "css/css-pseudo/selection-input-011.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-input-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-input-011.html)
 - [selection-textarea-011.html](https://wpt.fyi/results/css/css-pseudo/selection-textarea-011.html "css/css-pseudo/selection-textarea-011.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-textarea-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-textarea-011.html)
 - [svg-text-selection-fill-only.html](https://wpt.fyi/results/css/css-pseudo/svg-text-selection-fill-only.html "css/css-pseudo/svg-text-selection-fill-only.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/svg-text-selection-fill-only.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/svg-text-selection-fill-only.html)
 - [svg-text-selection-shadow.html](https://wpt.fyi/results/css/css-pseudo/svg-text-selection-shadow.html "css/css-pseudo/svg-text-selection-shadow.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/svg-text-selection-shadow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/svg-text-selection-shadow.html)
 - [svg-text-selection-stroke-only.html](https://wpt.fyi/results/css/css-pseudo/svg-text-selection-stroke-only.html "css/css-pseudo/svg-text-selection-stroke-only.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/svg-text-selection-stroke-only.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/svg-text-selection-stroke-only.html)
 - [svg-text-selection-transparent-background.html](https://wpt.fyi/results/css/css-pseudo/svg-text-selection-transparent-background.html "css/css-pseudo/svg-text-selection-transparent-background.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/svg-text-selection-transparent-background.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/svg-text-selection-transparent-background.html)
 - [textpath-selection-011.html](https://wpt.fyi/results/css/css-pseudo/textpath-selection-011.html "css/css-pseudo/textpath-selection-011.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/textpath-selection-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/textpath-selection-011.html)

[::search-text]

: The
 [::search-text](#selectordef-search-text)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) represents text identified by the user agent's
 find-in-page feature. Since not all UAs style matched text in ways
 expressible with the [highlight
 pseudo-elements](#highlight-pseudo-element), this pseudo-element is optional to implement.

 The
 [:current](https://drafts.csswg.org/selectors-5/#current-pseudo)
 [pseudo-class](https://drafts.csswg.org/selectors-4/#pseudo-class) (but not [::current()]) may be combined with
 [::search-text](#selectordef-search-text) to represent the currently focused match
 instance. The
 [:past](https://drafts.csswg.org/selectors-5/#past-pseudo) and
 [:future](https://drafts.csswg.org/selectors-5/#future-pseudo)
 [pseudo-classes](https://www.w3.org/TR/CSS2/selector.html#x23) are reserved for analogous use in the future. Any
 unsupported combination of these pseudo-classes with
 [::search-text] *must* be
 treated as invalid.

[::target-text]

: The
 [::target-text](#selectordef-target-text)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) represents text directly targeted by the document
 URL's
 [fragment](https://url.spec.whatwg.org/#concept-url-fragment), if any.

 When a [URL
 fragment](https://url.spec.whatwg.org/#concept-url-fragment) targets an element, the
 [:target](https://drafts.csswg.org/selectors-4/#target-pseudo) pseudo-element can be used to select it, but
 [::target-text](#selectordef-target-text) does not match anything. It only matches
 text that is itself targeted by the
 \[[fragment]\].

 Tests

 - [target-text-001.html](https://wpt.fyi/results/css/css-pseudo/target-text-001.html "css/css-pseudo/target-text-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-001.html)
 - [target-text-002.html](https://wpt.fyi/results/css/css-pseudo/target-text-002.html "css/css-pseudo/target-text-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-002.html)
 - [target-text-003.html](https://wpt.fyi/results/css/css-pseudo/target-text-003.html "css/css-pseudo/target-text-003.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-003.html)
 - [target-text-004.html](https://wpt.fyi/results/css/css-pseudo/target-text-004.html "css/css-pseudo/target-text-004.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-004.html)
 - [target-text-005.html](https://wpt.fyi/results/css/css-pseudo/target-text-005.html "css/css-pseudo/target-text-005.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-005.html)
 - [target-text-006.html](https://wpt.fyi/results/css/css-pseudo/target-text-006.html "css/css-pseudo/target-text-006.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-006.html)
 - [target-text-007.html](https://wpt.fyi/results/css/css-pseudo/target-text-007.html "css/css-pseudo/target-text-007.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-007.html)
 - [target-text-008.html](https://wpt.fyi/results/css/css-pseudo/target-text-008.html "css/css-pseudo/target-text-008.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-008.html)
 - [target-text-009.html](https://wpt.fyi/results/css/css-pseudo/target-text-009.html "css/css-pseudo/target-text-009.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-009.html)
 - [target-text-010.html](https://wpt.fyi/results/css/css-pseudo/target-text-010.html "css/css-pseudo/target-text-010.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-010.html)
 - [target-text-dynamic-001.html](https://wpt.fyi/results/css/css-pseudo/target-text-dynamic-001.html "css/css-pseudo/target-text-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-dynamic-001.html)
 - [target-text-dynamic-002.html](https://wpt.fyi/results/css/css-pseudo/target-text-dynamic-002.html "css/css-pseudo/target-text-dynamic-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-dynamic-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-dynamic-002.html)
 - [target-text-dynamic-003.html](https://wpt.fyi/results/css/css-pseudo/target-text-dynamic-003.html "css/css-pseudo/target-text-dynamic-003.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-dynamic-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-dynamic-003.html)
 - [target-text-dynamic-004.html](https://wpt.fyi/results/css/css-pseudo/target-text-dynamic-004.html "css/css-pseudo/target-text-dynamic-004.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-dynamic-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-dynamic-004.html)
 - [target-text-shadow-horizontal.html](https://wpt.fyi/results/css/css-pseudo/target-text-shadow-horizontal.html "css/css-pseudo/target-text-shadow-horizontal.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-shadow-horizontal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-shadow-horizontal.html)
 - [target-text-shadow-vertical.html](https://wpt.fyi/results/css/css-pseudo/target-text-shadow-vertical.html "css/css-pseudo/target-text-shadow-vertical.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-shadow-vertical.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-shadow-vertical.html)
 - [target-text-text-decoration-001.html](https://wpt.fyi/results/css/css-pseudo/target-text-text-decoration-001.html "css/css-pseudo/target-text-text-decoration-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/target-text-text-decoration-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/target-text-text-decoration-001.html)

[::spelling-error]
: The
 [::spelling-error](#selectordef-spelling-error)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) represents a portion of text that has been flagged
 by the user agent as misspelled.
 Tests
 - [spelling-error-001.html](https://wpt.fyi/results/css/css-pseudo/spelling-error-001.html "css/css-pseudo/spelling-error-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/spelling-error-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/spelling-error-001.html)
 - [spelling-error-002-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/spelling-error-002-manual.html)
 - [spelling-error-003-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/spelling-error-003-manual.html)
 - [spelling-error-004-crash.html](https://wpt.fyi/results/css/css-pseudo/spelling-error-004-crash.html "css/css-pseudo/spelling-error-004-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/spelling-error-004-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/spelling-error-004-crash.html)
 - [spelling-error-005-crash.html](https://wpt.fyi/results/css/css-pseudo/spelling-error-005-crash.html "css/css-pseudo/spelling-error-005-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/spelling-error-005-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/spelling-error-005-crash.html)
 - [spelling-error-006.html](https://wpt.fyi/results/css/css-pseudo/spelling-error-006.html "css/css-pseudo/spelling-error-006.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/spelling-error-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/spelling-error-006.html)

[::grammar-error]
: The
 [::grammar-error](#selectordef-grammar-error)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) represents a portion of text that has been flagged
 by the user agent as grammatically incorrect.
 Tests
 - [grammar-error-001.html](https://wpt.fyi/results/css/css-pseudo/grammar-error-001.html "css/css-pseudo/grammar-error-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/grammar-error-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/grammar-error-001.html)
 - [grammar-error-002-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/grammar-error-002-manual.html)
 - [grammar-error-003-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/grammar-error-003-manual.html)

[::highlight([\<highlight-name-selector\>](#typedef-highlight-name-selector))]

: The
 [::highlight()](#selectordef-highlight-highlight-name-selector) [functional
 pseudo-element](https://drafts.csswg.org/selectors-4/#functional-pseudo-element) represents the portion of the [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element) associated with the [custom
 highlights](https://drafts.csswg.org/css-highlight-api-1/#custom-highlight) selected by its argument:

 ```
 <highlight-name-selector> = '*' | <custom-ident>
 ```

 A
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) argument selects the single
 [custom
 highlight](https://drafts.csswg.org/css-highlight-api-1/#custom-highlight) whose [custom highlight
 name](https://drafts.csswg.org/css-highlight-api-1/#custom-highlight-name) is that identifier. The
 [\*](https://drafts.csswg.org/selectors-3/#x) argument selects every [custom
 highlight], regardless of its [custom
 highlight name].

 The specificity of a
 [::highlight()](#selectordef-highlight-highlight-name-selector) selector with a
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) argument is equivalent to a [type
 selector](https://drafts.csswg.org/selectors-4/#type-selector). The specificity of a
 [::highlight()] selector with a
 [\*](https://drafts.csswg.org/selectors-3/#x) argument is zero.

 See
 [\[CSS-HIGHLIGHT-API-1\]](#biblio-css-highlight-api-1 "CSS Custom Highlight API Module Level 1")
 for details.

The [highlight
pseudo-elements](#highlight-pseudo-element) do not necessarily fit into the element tree, and can
arbitrarily cross element boundaries without honoring its nesting
structure.

### 3.2. Styling Highlights

The [highlight
pseudo-elements](#highlight-pseudo-element) can only be styled by a limited set of properties that
do not affect layout and can be applied performantly in a highly dynamic
environment---​and additionally (to ensure interoperability) whose
rendering within the [required area](#highlight-bounds) is not dependent
on the exact (UA-determined) bounds of the [highlight
overlay](#highlight-overlay).

The following properties apply to the [highlight
pseudo-elements](#highlight-pseudo-element):

- [color](https://drafts.csswg.org/css-color-4/#propdef-color)
 Tests
 - [active-selection-001-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-001-manual.html)
 - [active-selection-011.html](https://wpt.fyi/results/css/css-pseudo/active-selection-011.html "css/css-pseudo/active-selection-011.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-011.html)
 - [active-selection-016.html](https://wpt.fyi/results/css/css-pseudo/active-selection-016.html "css/css-pseudo/active-selection-016.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-016.html)
 - [active-selection-018.html](https://wpt.fyi/results/css/css-pseudo/active-selection-018.html "css/css-pseudo/active-selection-018.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-018.html)
 - [highlight-styling-003.html](https://wpt.fyi/results/css/css-pseudo/highlight-styling-003.html "css/css-pseudo/highlight-styling-003.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-styling-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-styling-003.html)
 - [highlight-styling-004.html](https://wpt.fyi/results/css/css-pseudo/highlight-styling-004.html "css/css-pseudo/highlight-styling-004.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-styling-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-styling-004.html)
- [background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color)
 Tests
 - [active-selection-002-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-002-manual.html)
 - [active-selection-012.html](https://wpt.fyi/results/css/css-pseudo/active-selection-012.html "css/css-pseudo/active-selection-012.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-012.html)
 - [active-selection-031.html](https://wpt.fyi/results/css/css-pseudo/active-selection-031.html "css/css-pseudo/active-selection-031.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-031.html)
- [text-decoration](https://drafts.csswg.org/css-text-decor-4/#propdef-text-decoration) and its associated properties
 (including
 [text-underline-position](https://drafts.csswg.org/css-text-decor-4/#propdef-text-underline-position) and
 [text-underline-offset](https://drafts.csswg.org/css-text-decor-4/#propdef-text-underline-offset))
 Tests
 - [active-selection-004-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-004-manual.html)
 - [active-selection-014.html](https://wpt.fyi/results/css/css-pseudo/active-selection-014.html "css/css-pseudo/active-selection-014.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-014.html)
 - [active-selection-021.html](https://wpt.fyi/results/css/css-pseudo/active-selection-021.html "css/css-pseudo/active-selection-021.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-021.html)
 - [grammar-error-001.html](https://wpt.fyi/results/css/css-pseudo/grammar-error-001.html "css/css-pseudo/grammar-error-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/grammar-error-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/grammar-error-001.html)
 - [grammar-error-002-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/grammar-error-002-manual.html)
 - [grammar-error-003-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/grammar-error-003-manual.html)
 - [spelling-error-001.html](https://wpt.fyi/results/css/css-pseudo/spelling-error-001.html "css/css-pseudo/spelling-error-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/spelling-error-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/spelling-error-001.html)
 - [spelling-error-002-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/spelling-error-002-manual.html)
 - [spelling-error-003-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/spelling-error-003-manual.html)
- [text-shadow](https://drafts.csswg.org/css-text-decor-4/#propdef-text-shadow)
 Tests
 - [marker-text-shadow.html](https://wpt.fyi/results/css/css-pseudo/marker-text-shadow.html "css/css-pseudo/marker-text-shadow.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-text-shadow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-text-shadow.html)
- [stroke-color](https://drafts.csswg.org/fill-stroke-3/#propdef-stroke-color),
 [fill-color](https://drafts.csswg.org/fill-stroke-3/#propdef-fill-color), and
 [stroke-width](https://drafts.csswg.org/fill-stroke-3/#propdef-stroke-width)
 Tests
 - [highlight-styling-003.html](https://wpt.fyi/results/css/css-pseudo/highlight-styling-003.html "css/css-pseudo/highlight-styling-003.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-styling-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-styling-003.html)
 - [textpath-selection-011.html](https://wpt.fyi/results/css/css-pseudo/textpath-selection-011.html "css/css-pseudo/textpath-selection-011.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/textpath-selection-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/textpath-selection-011.html)
- [custom
 properties](https://drafts.csswg.org/css-variables-2/#custom-property)
 [\[CSS-VARIABLES-1\]](#biblio-css-variables-1 "CSS Custom Properties for Cascading Variables Module Level 1")
 Tests
 - [highlight-styling-005.html](https://wpt.fyi/results/css/css-pseudo/highlight-styling-005.html "css/css-pseudo/highlight-styling-005.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-styling-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-styling-005.html)

Are there any other properties that
should be included here?

 Historically (and at the time of writing) only
[color](https://drafts.csswg.org/css-color-4/#propdef-color) and
[background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color) have been interoperably supported.

 The
[color](https://drafts.csswg.org/css-color-4/#propdef-color) property sets the color of both the
text and all line decorations (underline, overline, line-through) and
emphasis marks
([text-emphasis](https://drafts.csswg.org/css-text-decor-4/#propdef-text-emphasis)) applied to the text by the
[originating
element](https://drafts.csswg.org/selectors-4/#originating-element) and its ancestors and descendants.

For any properties not listed above, but which are required to resolve
the values of applicable properties, their [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value) are copied from those of the [originating
element](https://drafts.csswg.org/selectors-4/#originating-element), ignoring any values specified on the [highlight
pseudo-element](#highlight-pseudo-element) itself. For example:

- [forced-color-adjust](https://drafts.csswg.org/css-color-adjust-1/#propdef-forced-color-adjust) (used in [forced colors
 mode](https://drafts.csswg.org/css-color-adjust-1/#forced-colors-mode) to resolve colors) and
 [color-scheme](https://drafts.csswg.org/css-color-adjust-1/#propdef-color-scheme) (used to resolve
 [\<system-color\>](https://drafts.csswg.org/css-color-4/#typedef-system-color) values)
- [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size),
 [font-family](https://drafts.csswg.org/css-fonts-4/#propdef-font-family), etc. (used to resolve
 [em](https://drafts.csswg.org/css-values-4/#em) and other [font-relative
 lengths](https://drafts.csswg.org/css-values-4/#font-relative-length)).
- [line-height](https://drafts.csswg.org/css2/#propdef-line-height) (used to resolve
 [lh](https://drafts.csswg.org/css-values-4/#lh) units)
- [custom
 properties](https://drafts.csswg.org/css-variables-2/#custom-property)
 [\[CSS-VARIABLES-1\]](#biblio-css-variables-1 "CSS Custom Properties for Cascading Variables Module Level 1")
 (used in
 [var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) substitutions)

If, for a given [highlight
pseudo-element](#highlight-pseudo-element), there are colors specified in the [author
origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-author), those colors must be respected as specified; i.e. the
UA must not apply any extra processing (such as using semi-transparent
washes). However if there are no colors in the [author
origin], the UA may apply additional
color processing.

 This is to ensure that color contrast is preserved
across all user agents interpreting a given author stylesheet.

Vendor-prefixed properties such as
[-webkit-text-fill-color](https://compat.spec.whatwg.org/#propdef--webkit-text-fill-color) are not applicable to the
[highlight
pseudo-elements](#highlight-pseudo-element).

### 3.3. Default UA Styles

The following additions are recommended for the default UA stylesheet:

```
/* Represent default spelling/grammar error styling in an adjustable way */
:root::spelling-error { text-decoration: spelling-error; }
:root::grammar-error { text-decoration: grammar-error; }
```

Some [highlight
pseudo-elements](#highlight-pseudo-element) should have [paired default highlight
colors]---​a default
[color](https://drafts.csswg.org/css-color-4/#propdef-color) and
[background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color) provided by the UA that are either
used or overridden together, see [§ 3.3.1 Paired
Defaults](#paired-defaults). For
[::selection](#selectordef-selection) they should correspond to
[HighlightText](https://drafts.csswg.org/css-color-4/#valdef-color-highlighttext) and
[Highlight](https://drafts.csswg.org/css-color-4/#valdef-color-highlight), while for
[::target-text](#selectordef-target-text) they should correspond to
[MarkText](https://drafts.csswg.org/css-color-4/#valdef-color-marktext) and
[Mark](https://drafts.csswg.org/css-color-4/#valdef-color-mark).

UAs may apply additional effects to enhance the presentation of
highlighted content, for example dimming content other than the
highlighted text or transitioning out a highlight style based on user
interactions or timing. These are not controlled by CSS.

UA tweaks to the presentation of
highlights in ways that *are* controlled by CSS are currently under
discussion in [Issue
6853](https://github.com/w3c/csswg-drafts/issues/6853).

#### 3.3.1. Paired Defaults

For compatibility reasons, [paired default highlight
colors](#paired-default-highlight-colors) must only be
[used](https://drafts.csswg.org/css-cascade-5/#used-value) when neither
[color](https://drafts.csswg.org/css-color-4/#propdef-color) nor
[background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color) yield a [cascaded
value](https://drafts.csswg.org/css-cascade-5/#cascaded-value) from the [author
origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-author) (or inherit their value from the author origin). When a
highlight color is
[revert](https://drafts.csswg.org/css-cascade-5/#valdef-all-revert) or
[revert-layer](https://drafts.csswg.org/css-cascade-5/#valdef-all-revert-layer), the origin *after* rolling back the cascade
determines the [cascaded value]'s
[origin](https://drafts.csswg.org/css-cascade-6/#origin).

 Because this rule is for compatibility reasons, it does
not apply to other similar properties like
[fill-color](https://drafts.csswg.org/fill-stroke-3/#propdef-fill-color) or
[stroke-color](https://drafts.csswg.org/fill-stroke-3/#propdef-stroke-color).

For example, given the following
markup:

```
<p>Highlight this <em>and this</em>.</p>
```

Any of the following rules would suppress the default
[background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color) for
[::selection](#selectordef-selection) in the `<em>` element if given by
the author:

```
em::selection { color: initial; }
em::selection { color: inherit; }
em::selection { color: unset; }
em::selection { color: green; }
p::selection { color: green; }
```

- [highlight-paired-cascade-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-paired-cascade-001.html "css/css-pseudo/highlight-cascade/highlight-paired-cascade-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-paired-cascade-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-paired-cascade-001.html)
- [highlight-paired-cascade-002.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-paired-cascade-002.html "css/css-pseudo/highlight-cascade/highlight-paired-cascade-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-paired-cascade-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-paired-cascade-002.html)
- [highlight-paired-cascade-003.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-paired-cascade-003.html "css/css-pseudo/highlight-cascade/highlight-paired-cascade-003.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-paired-cascade-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-paired-cascade-003.html)
- [highlight-paired-cascade-004.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-paired-cascade-004.html "css/css-pseudo/highlight-cascade/highlight-paired-cascade-004.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-paired-cascade-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-paired-cascade-004.html)
- [highlight-paired-cascade-005.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-paired-cascade-005.html "css/css-pseudo/highlight-cascade/highlight-paired-cascade-005.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-paired-cascade-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-paired-cascade-005.html)
- [highlight-paired-cascade-006.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-paired-cascade-006.html "css/css-pseudo/highlight-cascade/highlight-paired-cascade-006.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-paired-cascade-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-paired-cascade-006.html)

### 3.4. Area of a Highlight

For each type of highlighting (see [§ 3.1 Selecting Highlighted Content:
the ::selection, ::search-text, ::target-text, ::spelling-error,
::grammar-error, and ::highlight()
pseudo-elements](#highlight-selectors)) there exists a single [highlight
overlay] for the entire document, the active portions of which are
represented by the corresponding [highlight
pseudo-element](#highlight-pseudo-element). Each box owns the piece of the overlay corresponding
to any text or replaced content directly contained by the box.

- For text, the corresponding overlay must cover at least the entire em
 box and may extend further above/below the em box to the line box
 edges. Spacing between two characters may also be part of the overlay
 area, in which case it belongs to the innermost element that contains
 both characters and is selected when both characters are selected.
 Tests
 - [selection-intercharacter-011.html](https://wpt.fyi/results/css/css-pseudo/selection-intercharacter-011.html "css/css-pseudo/selection-intercharacter-011.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-intercharacter-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-intercharacter-011.html)
 - [selection-intercharacter-012.html](https://wpt.fyi/results/css/css-pseudo/selection-intercharacter-012.html "css/css-pseudo/selection-intercharacter-012.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-intercharacter-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-intercharacter-012.html)
- For replaced content, the associated overlay must cover at least the
 entire replaced object, and may extend outward to include the
 element's entire content box.
 Tests
 - [active-selection-043.html](https://wpt.fyi/results/css/css-pseudo/active-selection-043.html "css/css-pseudo/active-selection-043.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-043.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-043.html)
- The overlay may also include other areas within the border-box of an
 element; in this case, those areas belong to the innermost such
 element that contains the area.
- For an [inline-level
 box](https://drafts.csswg.org/css-display-4/#inline-level-box), the overlay may extend outside its border edges in
 the [block
 axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) as far as the edges of its [line
 box](https://drafts.csswg.org/css-inline-3/#line-box).

See [F2F
minutes](http://lists.w3.org/Archives/Public/www-style/2008Nov/0022.html),
[dbaron's
message](http://lists.w3.org/Archives/Public/www-style/2008Oct/0268.html),
[Daniel's
thread](http://lists.w3.org/Archives/Public/www-style/2010May/0247.html),
[Gecko
notes](http://lists.w3.org/Archives/Public/www-style/2010May/0261.html),
[Opera
notes](http://lists.w3.org/Archives/Public/www-style/2010May/0366.html),
[Webkit
notes](http://lists.w3.org/Archives/Public/www-style/2010May/0280.html)

Not sure if this is the correct way of
describing the way things work.

### 3.5. Cascading and Per-Element Highlight Styles

Each element draws its own active portions of the [highlight
overlays](#highlight-overlay), which receives the styles specified by the
corresponding [highlight
pseudo-element](#highlight-pseudo-element) styles for which that element is the [originating
element](https://drafts.csswg.org/selectors-4/#originating-element). When multiple styles conflict, the winning style is
determined by the cascade.

When any supported property is not given a value by the cascade, or
given a value of
[inherit](https://drafts.csswg.org/css-cascade-5/#valdef-all-inherit) or
[unset](https://drafts.csswg.org/css-cascade-5/#valdef-all-unset), its [specified
value](https://drafts.csswg.org/css-cascade-5/#specified-value) is determined by inheritance from the corresponding
[highlight
pseudo-element](#highlight-pseudo-element) of its [originating
element](https://drafts.csswg.org/selectors-4/#originating-element)'s parent element. This occurs regardless of whether
that property is an [inherited
property](https://drafts.csswg.org/css-cascade-5/#inherited-property).

Additionally, for [highlight
pseudo-elements](#highlight-pseudo-element) originating from the [root
element](https://drafts.csswg.org/css-display-4/#root-element) the inherited value of
[color](https://drafts.csswg.org/css-color-4/#propdef-color) is
[currentColor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor), not the [initial
value](https://drafts.csswg.org/css-cascade-5/#initial-value).

All [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property) inherit from the [originating
element](https://drafts.csswg.org/selectors-4/#originating-element), regardless of whether that property is a [custom
property] that is registered to
[inherit](https://drafts.csswg.org/css-cascade-5/#css-inheritance) or not.

Tests

- [active-selection-051.html](https://wpt.fyi/results/css/css-pseudo/active-selection-051.html "css/css-pseudo/active-selection-051.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-051.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-051.html)
- [active-selection-052.html](https://wpt.fyi/results/css/css-pseudo/active-selection-052.html "css/css-pseudo/active-selection-052.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-052.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-052.html)
- [active-selection-053.html](https://wpt.fyi/results/css/css-pseudo/active-selection-053.html "css/css-pseudo/active-selection-053.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-053.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-053.html)
- [active-selection-054.html](https://wpt.fyi/results/css/css-pseudo/active-selection-054.html "css/css-pseudo/active-selection-054.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-054.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-054.html)
- [cascade-highlight-004.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/cascade-highlight-004.html "css/css-pseudo/highlight-cascade/cascade-highlight-004.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/cascade-highlight-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/cascade-highlight-004.html)
- [highlight-cascade-010.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-cascade-010.html "css/css-pseudo/highlight-cascade/highlight-cascade-010.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-cascade-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-cascade-010.html)

For example, if the following rules
were applied:

```
p::selection { color: yellow; background: green; }
p > em::selection { color: orange; }
em::selection { color: red; }
```

to the following markup:

```
<p>Highlight this <em>and this</em>.</p>
```

The selection highlight would be green throughout, with yellow text
outside the `<em>` element and orange text inside it.

- [cascade-highlight-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/cascade-highlight-001.html "css/css-pseudo/highlight-cascade/cascade-highlight-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/cascade-highlight-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/cascade-highlight-001.html)

Authors wanting multiple selections styles should use
**[:root::selection]** for their document-wide selection style,
since this will allow clean overriding in descendants.
[::selection](#selectordef-selection) alone applies to every element in the tree,
overriding the more specific styles of any ancestors.

For example, if an author specified

```
::selection { background: blue; }
p.warning::selection { background: red; }
```

and the document included

```
<p class="warning">Some <strong>very important information</strong></p>
```

The highlight would be blue over "very important information" because
the `<strong>` element´s
[::selection](#selectordef-selection) also matches the [::selection { background:
blue; }] rule. (Remember that
[\*](https://drafts.csswg.org/selectors-3/#x) is implied when a tag selector is missing.) The style
rules that would give the intended behavior (red highlight within
`p.warning`, blue elsewhere) are

```
:root::selection { background: blue; }
p.warning::selection { background: red; }
```

- [cascade-highlight-002.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/cascade-highlight-002.html "css/css-pseudo/highlight-cascade/cascade-highlight-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/cascade-highlight-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/cascade-highlight-002.html)

The following example demonstrates the inheritance of [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property).

For example, if an author specified

```
:root {
 --background-color: green;
 --decoration-thickness: 10px;
 --decoration-color: purple;
 }
 ::selection {
 --decoration-thickness: 1px;
 --decoration-color: green;
 }
 div::selection {
 --decoration-color: blue;
 background-color: var(--background-color, red);
 text-decoration-line: underline;
 text-decoration-style: line;
 text-decoration-thickness: var(--decoration-thickness, 5px);
 text-decoration-color: var(--decoration-color, red);
 }
```

The universal
[::selection](#selectordef-selection) uses the user-agent's default styling because it
only defines custom properties, with no properties that influence the
appearance. A div's selection highlight would apply a green background
to the selected content, with a 10px thick blue underline. Since
[\--background-color] and [\--decoration-thickness] custom
properties are not specified on the [div::selection]
peudo-element, they are inherited from its originating
[`div`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-div-element) element, which itself inherits the custom
properties from the root. However since [\--decoration-color] is
specified on the [div::selection] itself, its value from the
[originating
element](https://drafts.csswg.org/selectors-4/#originating-element) is not used.

 This behavior allows control of selection with custom
properties in a way that is compatible with pre-existing
implementations.

Tests

- [highlight-cascade-011.html](https://wpt.fyi/results/css/css-pseudo/highlight-cascade/highlight-cascade-011.html "css/css-pseudo/highlight-cascade/highlight-cascade-011.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-cascade/highlight-cascade-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-cascade/highlight-cascade-011.html)

### 3.6. Painting the Highlight

Tests

- [active-selection-014.html](https://wpt.fyi/results/css/css-pseudo/active-selection-014.html "css/css-pseudo/active-selection-014.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-014.html)
- [active-selection-041.html](https://wpt.fyi/results/css/css-pseudo/active-selection-041.html "css/css-pseudo/active-selection-041.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-041.html)
- [active-selection-045.html](https://wpt.fyi/results/css/css-pseudo/active-selection-045.html "css/css-pseudo/active-selection-045.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/active-selection-045.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/active-selection-045.html)
- [highlight-painting-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-001.html "css/css-pseudo/highlight-painting-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-001.html)
- [highlight-painting-002.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-002.html "css/css-pseudo/highlight-painting-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-002.html)
- [highlight-painting-003.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-003.html "css/css-pseudo/highlight-painting-003.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-003.html)
- [highlight-painting-004.html](https://wpt.fyi/results/css/css-pseudo/highlight-painting-004.html "css/css-pseudo/highlight-painting-004.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-painting-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-painting-004.html)

#### 3.6.1. Backgrounds

Each [highlight
pseudo-element](#highlight-pseudo-element) draws its background over the corresponding portion of
the [highlight overlay](#highlight-overlay), painting it immediately below any positioned
descendants (i.e. just before step 8 in
[CSS2.2§E.2](https://www.w3.org/TR/CSS22/zindex.html#painting-order)).
The
[::selection](#selectordef-selection) overlay is drawn over the
[::target-text](#selectordef-target-text) overlay which is drawn over the
[::spelling-error](#selectordef-spelling-error) overlay which is drawn over the
[::grammar-error](#selectordef-grammar-error) overlay which is drawn over the
[::highlight] overlays. The
[::search-text](#selectordef-search-text) overlay is drawn directly over or below the
[:selection] overlay depending on the UA, and drawn over all other
overlays.

Tests

- [selection-overlay-and-grammar-001.html](https://wpt.fyi/results/css/css-pseudo/selection-overlay-and-grammar-001.html "css/css-pseudo/selection-overlay-and-grammar-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-overlay-and-grammar-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-overlay-and-grammar-001.html)
- [selection-overlay-and-spelling-001.html](https://wpt.fyi/results/css/css-pseudo/selection-overlay-and-spelling-001.html "css/css-pseudo/selection-overlay-and-spelling-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-overlay-and-spelling-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-overlay-and-spelling-001.html)
- [highlight-z-index-001.html](https://wpt.fyi/results/css/css-pseudo/highlight-z-index-001.html "css/css-pseudo/highlight-z-index-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-z-index-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-z-index-001.html)
- [highlight-z-index-002.html](https://wpt.fyi/results/css/css-pseudo/highlight-z-index-002.html "css/css-pseudo/highlight-z-index-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/highlight-z-index-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/highlight-z-index-002.html)
- [selection-background-painting-order.html](https://wpt.fyi/results/css/css-pseudo/selection-background-painting-order.html "css/css-pseudo/selection-background-painting-order.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-background-painting-order.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-background-painting-order.html)

#### 3.6.2. Shadows

Any
[text-shadow](https://drafts.csswg.org/css-text-decor-4/#propdef-text-shadow) applying to a [highlight
pseudo-element](#highlight-pseudo-element) is drawn over its corresponding [highlight
overlay](#highlight-overlay) background. Such text shadows also stack over each
other (and over any original [text-shadow] applied to the text and its decorations, which continues to
apply).

 Since each [highlight
overlay](#highlight-overlay) background is drawn over any shadows belonging to the
layer(s) below, a [highlight overlay]
background can obscure lower-level shadows.

#### 3.6.3. Text and Text Decorations

A [highlight
pseudo-element](#highlight-pseudo-element) suppresses the normal drawing of any associated text,
and the text decorations (other than shadows) that had been applied to
that text. Instead the topmost active [highlight
overlay](#highlight-overlay) redraws that text (and those decorations) over all the
[highlight overlay] backgrounds using that
highlight's own
[color](https://drafts.csswg.org/css-color-4/#propdef-color).

 This means that unlike shadows, line decorations and
emphasis marks won't be obscured by any highlight overlay backgrounds
that are drawn for the associated text.

For this purpose,
[currentColor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor) on a [highlight
pseudo-element](#highlight-pseudo-element)'s
[color](https://drafts.csswg.org/css-color-4/#propdef-color) property represents the
[color] of the next *active*
[highlight pseudo-element] layer
below, falling back finally to the colors that would otherwise have been
used (those applied by the [originating
element](https://drafts.csswg.org/selectors-4/#originating-element) or an intervening
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) such as
[::first-line](#selectordef-first-line) or
[::first-letter](#selectordef-first-letter)).

 The element's own text decorations (both [line
decorations](https://www.w3.org/TR/css-text-decor/#line-decoration) and
[emphasis marks](https://www.w3.org/TR/css-text-decor/#emphasis-marks))
are thus drawn in the pseudo-element's own
[color](https://drafts.csswg.org/css-color-4/#propdef-color) when that is not
[currentColor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor), regardless of their original color or fill
specifications.

Any text decorations introduced by each [highlight
pseudo-element](#highlight-pseudo-element) are stacked in the same order as their backgrounds over
the text's original decorations and are all drawn, each decoration in
its own color. The normal painting order applies, so as per [CSS2
Appendix E](https://www.w3.org/TR/CSS2/zindex.html#painting-order), all
underlines are drawn below overlines which are drawn below the text
which is drawn below any line-throughs. However, text decorations
applied by
[::selection](#selectordef-selection) may instead all be drawn along with the text as
a topmost set of layers above all other decorations.

For example, assuming the original
text has an underline and a strike-through, that
[::selection](#selectordef-selection) applies an underline and
[::target-text](#selectordef-target-text) applies both overline and strike-through, the
following are both conformant painting orders:

::: {style="columns: 20em"}
1. original underline
2. [::selection](#selectordef-selection) underline
3. [::target-text](#selectordef-target-text) overline
4. [::selection](#selectordef-selection)-colored text
5. original strike-through
6. [::target-text](#selectordef-target-text) strike-through

<!-- -->

1. original underline
2. [::target-text](#selectordef-target-text) overline
3. original strike-through
4. [::target-text](#selectordef-target-text) strike-through
5. [::selection](#selectordef-selection) underline
6. [::selection](#selectordef-selection)-colored text

[Line
decorations](https://www.w3.org/TR/css-text-decor/#line-decoration)
introduced by [highlight
pseudo-elements](#highlight-pseudo-element) apply only to the text associated with their
[originating
element](https://drafts.csswg.org/selectors-4/#originating-element), and are not propagated to descendants except via
property
[inheritance](https://drafts.csswg.org/css-cascade-5/#css-inheritance) (as described [above](#highlight-cascade)).

 Unlike the originating element's own decorations,
decorations declared on a highlight pseudo-element propagate to
[out-of-flow
elements](https://drafts.csswg.org/css-display-4/#out-of-flow) and [inline
blocks](https://drafts.csswg.org/css-display-4/#inline-block), with thickness and position varying between
descendants.

Tests

- [selection-originating-underline-order.html](https://wpt.fyi/results/css/css-pseudo/selection-originating-underline-order.html "css/css-pseudo/selection-originating-underline-order.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-originating-underline-order.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-originating-underline-order.html)
- [selection-originating-decoration-color.html](https://wpt.fyi/results/css/css-pseudo/selection-originating-decoration-color.html "css/css-pseudo/selection-originating-decoration-color.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-originating-decoration-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-originating-decoration-color.html)
- [selection-originating-strikethrough-order.html](https://wpt.fyi/results/css/css-pseudo/selection-originating-strikethrough-order.html "css/css-pseudo/selection-originating-strikethrough-order.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-originating-strikethrough-order.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-originating-strikethrough-order.html)

#### 3.6.4. Replaced Elements

For non-replaced content, the UA must honor the
[color](https://drafts.csswg.org/css-color-4/#propdef-color) and
[background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color) (including their alpha channels) as
specified. However, for replaced content, the UA should create a
semi-transparent wash to coat the content so that it can show through
the selection. This wash should be of the specified
[background-color] if that
is not
[transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent), else of the specified
[color]; however the UA may adjust
the alpha channel.

Tests

- [selection-paint-image.html](https://wpt.fyi/results/css/css-pseudo/selection-paint-image.html "css/css-pseudo/selection-paint-image.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/selection-paint-image.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/selection-paint-image.html)

### 3.7. Security Considerations for Highlighting

Because the styling of spelling and grammar errors can leak information
about the contents of a user's dictionary (which can include the user's
name and even includes the contents of their address book!) UAs that
implement
[::spelling-error](#selectordef-spelling-error) and
[::grammar-error](#selectordef-grammar-error) must mitigate the following attacks:

- Pages attempting to directly read the styling of highlighted segments.
- Pages attempting to track performance impacts of styling highlighted
 segments via programatic modification of text fields.

## 4. Tree-Abiding Pseudo-elements

[Tree-abiding pseudo-elements] always fit within the
box tree. They
[inherit](https://drafts.csswg.org/css-cascade-5/#css-inheritance) any inheritable properties from their [originating
element](https://drafts.csswg.org/selectors-4/#originating-element); non-inheritable properties take their [initial
values](https://drafts.csswg.org/css-cascade-5/#initial-value) as usual.
[\[CSS-CASCADE-4\]](#biblio-css-cascade-4 "CSS Cascading and Inheritance Level 4")
A subset of these are the [fully styleable
pseudo-elements]; all properties that apply to a
real element also apply to a [fully styleable
pseudo-element](#fully-styleable).

Tests

- [tree-abiding-pseudo-elements.html](https://wpt.fyi/results/css/css-pseudo/parsing/tree-abiding-pseudo-elements.html "css/css-pseudo/parsing/tree-abiding-pseudo-elements.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/parsing/tree-abiding-pseudo-elements.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/parsing/tree-abiding-pseudo-elements.html)

### 4.1. Generated Content Pseudo-elements: [::before and [::after](#selectordef-after)]
When their computed
[content](https://drafts.csswg.org/css-content-3/#propdef-content) value is not
[none](https://drafts.csswg.org/css-content-3/#valdef-content-none), these
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) generate boxes as if they were immediate children of
their [originating
element](https://drafts.csswg.org/selectors-4/#originating-element), with content as specified by
[content].

[::before]
: Represents a styleable child pseudo-element immediately before the
 [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element)'s actual content.

[::after]
: Represents a styleable child pseudo-element immediately after the
 [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element)'s actual content.

Tests

- [before-after-dynamic-custom-property-001.html](https://wpt.fyi/results/css/css-pseudo/before-after-dynamic-custom-property-001.html "css/css-pseudo/before-after-dynamic-custom-property-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/before-after-dynamic-custom-property-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/before-after-dynamic-custom-property-001.html)
- [before-as-flex-container.html](https://wpt.fyi/results/css/css-pseudo/before-as-flex-container.html "css/css-pseudo/before-as-flex-container.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/before-as-flex-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/before-as-flex-container.html)
- [before-dynamic-display-none.html](https://wpt.fyi/results/css/css-pseudo/before-dynamic-display-none.html "css/css-pseudo/before-dynamic-display-none.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/before-dynamic-display-none.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/before-dynamic-display-none.html)
- [before-in-display-none-thcrash.html](https://wpt.fyi/results/css/css-pseudo/before-in-display-none-thcrash.html "css/css-pseudo/before-in-display-none-thcrash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/before-in-display-none-thcrash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/before-in-display-none-thcrash.html)
- [before-preceding-whitespace-dynamic.html](https://wpt.fyi/results/css/css-pseudo/before-preceding-whitespace-dynamic.html "css/css-pseudo/before-preceding-whitespace-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/before-preceding-whitespace-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/before-preceding-whitespace-dynamic.html)
- [focus-visible-originating-element.html](https://wpt.fyi/results/css/css-pseudo/focus-visible-originating-element.html "css/css-pseudo/focus-visible-originating-element.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/focus-visible-originating-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/focus-visible-originating-element.html)

Both [::before](#selectordef-before) and
[::after](#selectordef-after) are [fully styleable
pseudo-elements](#fully-styleable): there is no restriction on what properties apply to
them.

For example, the following rule
inserts the string "Note: " before the content of every
`<p>` element whose `class` attribute has the
value `note`:

```
p.note::before { content: "Note: " }
```

Since the initial value of
[display](https://drafts.csswg.org/css-display-4/#propdef-display) is
[inline](https://drafts.csswg.org/css-display-4/#valdef-display-inline), this will generate an inline box. Like other
inline children of `<p>`, it will participate in
`<p>`'s inline formatting context, potentially sharing a
line with other content.

As with the content of regular elements, the generated content of
[::before](#selectordef-before) and
[:after](https://drafts.csswg.org/css2/#selectordef-after) pseudo-elements can form part of any
[::first-line](#selectordef-first-line) and
[::first-letter](#selectordef-first-letter) pseudo-elements applied to its [originating
element](https://drafts.csswg.org/selectors-4/#originating-element). Also as with regular child elements, the
[::before] and
[::after](#selectordef-after) pseudo-elements are suppressed when their parent, the
[originating element], is
[replaced](https://drafts.csswg.org/css-display-4/#replaced-element).

Tests

- [pseudo-replaced-elements.html](https://wpt.fyi/results/css/css-pseudo/pseudo-replaced-elements.html "css/css-pseudo/pseudo-replaced-elements.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/pseudo-replaced-elements.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/pseudo-replaced-elements.html)

### 4.2. List Markers: the [::marker pseudo-element]
The [::marker]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) represents the automatically generated [marker
box](https://drafts.csswg.org/css-lists-3/#marker) of a [list
item](https://drafts.csswg.org/css-lists-3/#list-item). (See
[\[CSS-DISPLAY-3\]](#biblio-css-display-3 "CSS Display Module Level 3")
and
[\[CSS-LISTS-3\]](#biblio-css-lists-3 "CSS Lists and Counters Module Level 3").)

Tests

- [marker-and-other-pseudo-elements.html](https://wpt.fyi/results/css/css-pseudo/marker-and-other-pseudo-elements.html "css/css-pseudo/marker-and-other-pseudo-elements.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-and-other-pseudo-elements.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-and-other-pseudo-elements.html)
- [marker-animate-002.html](https://wpt.fyi/results/css/css-pseudo/marker-animate-002.html "css/css-pseudo/marker-animate-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-animate-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-animate-002.html)
- [marker-animate.html](https://wpt.fyi/results/css/css-pseudo/marker-animate.html "css/css-pseudo/marker-animate.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-animate.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-animate.html)
- [marker-color.html](https://wpt.fyi/results/css/css-pseudo/marker-color.html "css/css-pseudo/marker-color.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-color.html)
- [marker-computed-content.html](https://wpt.fyi/results/css/css-pseudo/marker-computed-content.html "css/css-pseudo/marker-computed-content.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-computed-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-computed-content.html)
- [marker-computed-size.html](https://wpt.fyi/results/css/css-pseudo/marker-computed-size.html "css/css-pseudo/marker-computed-size.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-computed-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-computed-size.html)
- [marker-content-001.html](https://wpt.fyi/results/css/css-pseudo/marker-content-001.html "css/css-pseudo/marker-content-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-001.html)
- [marker-content-001b.html](https://wpt.fyi/results/css/css-pseudo/marker-content-001b.html "css/css-pseudo/marker-content-001b.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-001b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-001b.html)
- [marker-content-001c.html](https://wpt.fyi/results/css/css-pseudo/marker-content-001c.html "css/css-pseudo/marker-content-001c.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-001c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-001c.html)
- [marker-content-002.html](https://wpt.fyi/results/css/css-pseudo/marker-content-002.html "css/css-pseudo/marker-content-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-002.html)
- [marker-content-003.html](https://wpt.fyi/results/css/css-pseudo/marker-content-003.html "css/css-pseudo/marker-content-003.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-003.html)
- [marker-content-003b.html](https://wpt.fyi/results/css/css-pseudo/marker-content-003b.html "css/css-pseudo/marker-content-003b.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-003b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-003b.html)
- [marker-content-004.html](https://wpt.fyi/results/css/css-pseudo/marker-content-004.html "css/css-pseudo/marker-content-004.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-004.html)
- [marker-content-005.html](https://wpt.fyi/results/css/css-pseudo/marker-content-005.html "css/css-pseudo/marker-content-005.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-005.html)
- [marker-content-006.html](https://wpt.fyi/results/css/css-pseudo/marker-content-006.html "css/css-pseudo/marker-content-006.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-006.html)
- [marker-content-010.html](https://wpt.fyi/results/css/css-pseudo/marker-content-010.html "css/css-pseudo/marker-content-010.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-010.html)
- [marker-content-012.html](https://wpt.fyi/results/css/css-pseudo/marker-content-012.html "css/css-pseudo/marker-content-012.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-012.html)
- [marker-content-013.html](https://wpt.fyi/results/css/css-pseudo/marker-content-013.html "css/css-pseudo/marker-content-013.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-013.html)
- [marker-content-014.html](https://wpt.fyi/results/css/css-pseudo/marker-content-014.html "css/css-pseudo/marker-content-014.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-014.html)
- [marker-content-015.html](https://wpt.fyi/results/css/css-pseudo/marker-content-015.html "css/css-pseudo/marker-content-015.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-015.html)
- [marker-content-016.html](https://wpt.fyi/results/css/css-pseudo/marker-content-016.html "css/css-pseudo/marker-content-016.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-016.html)
- [marker-content-017.html](https://wpt.fyi/results/css/css-pseudo/marker-content-017.html "css/css-pseudo/marker-content-017.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-017.html)
- [marker-content-018.html](https://wpt.fyi/results/css/css-pseudo/marker-content-018.html "css/css-pseudo/marker-content-018.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-018.html)
- [marker-content-019.html](https://wpt.fyi/results/css/css-pseudo/marker-content-019.html "css/css-pseudo/marker-content-019.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-019.html)
- [marker-content-020.html](https://wpt.fyi/results/css/css-pseudo/marker-content-020.html "css/css-pseudo/marker-content-020.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-020.html)
- [marker-content-021.html](https://wpt.fyi/results/css/css-pseudo/marker-content-021.html "css/css-pseudo/marker-content-021.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-021.html)
- [marker-content-022.html](https://wpt.fyi/results/css/css-pseudo/marker-content-022.html "css/css-pseudo/marker-content-022.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-022.html)
- [marker-content-023.html](https://wpt.fyi/results/css/css-pseudo/marker-content-023.html "css/css-pseudo/marker-content-023.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-023.html)
- [marker-content-024.html](https://wpt.fyi/results/css/css-pseudo/marker-content-024.html "css/css-pseudo/marker-content-024.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-content-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-content-024.html)
- [marker-default-styles.html](https://wpt.fyi/results/css/css-pseudo/marker-default-styles.html "css/css-pseudo/marker-default-styles.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-default-styles.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-default-styles.html)
- [marker-display-computed.html](https://wpt.fyi/results/css/css-pseudo/marker-display-computed.html "css/css-pseudo/marker-display-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-display-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-display-computed.html)
- [marker-display-dynamic-001.html](https://wpt.fyi/results/css/css-pseudo/marker-display-dynamic-001.html "css/css-pseudo/marker-display-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-display-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-display-dynamic-001.html)
- [marker-font-properties.html](https://wpt.fyi/results/css/css-pseudo/marker-font-properties.html "css/css-pseudo/marker-font-properties.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-font-properties.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-font-properties.html)
- [marker-font-variant-numeric-default-ref.html](https://wpt.fyi/results/css/css-pseudo/marker-font-variant-numeric-default-ref.html "css/css-pseudo/marker-font-variant-numeric-default-ref.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-font-variant-numeric-default-ref.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-font-variant-numeric-default-ref.html)
- [marker-font-variant-numeric-default.html](https://wpt.fyi/results/css/css-pseudo/marker-font-variant-numeric-default.html "css/css-pseudo/marker-font-variant-numeric-default.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-font-variant-numeric-default.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-font-variant-numeric-default.html)
- [marker-font-variant-numeric-normal-ref.html](https://wpt.fyi/results/css/css-pseudo/marker-font-variant-numeric-normal-ref.html "css/css-pseudo/marker-font-variant-numeric-normal-ref.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-font-variant-numeric-normal-ref.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-font-variant-numeric-normal-ref.html)
- [marker-font-variant-numeric-normal.html](https://wpt.fyi/results/css/css-pseudo/marker-font-variant-numeric-normal.html "css/css-pseudo/marker-font-variant-numeric-normal.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-font-variant-numeric-normal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-font-variant-numeric-normal.html)
- [marker-hit-testing.html](https://wpt.fyi/results/css/css-pseudo/marker-hit-testing.html "css/css-pseudo/marker-hit-testing.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-hit-testing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-hit-testing.html)
- [marker-hyphens.html](https://wpt.fyi/results/css/css-pseudo/marker-hyphens.html "css/css-pseudo/marker-hyphens.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-hyphens.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-hyphens.html)
- [marker-inherit-line-height.html](https://wpt.fyi/results/css/css-pseudo/marker-inherit-line-height.html "css/css-pseudo/marker-inherit-line-height.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-inherit-line-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-inherit-line-height.html)
- [marker-inherit-values.html](https://wpt.fyi/results/css/css-pseudo/marker-inherit-values.html "css/css-pseudo/marker-inherit-values.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-inherit-values.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-inherit-values.html)
- [marker-intrinsic-contribution-001.html](https://wpt.fyi/results/css/css-pseudo/marker-intrinsic-contribution-001.html "css/css-pseudo/marker-intrinsic-contribution-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-intrinsic-contribution-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-intrinsic-contribution-001.html)
- [marker-intrinsic-contribution-002.html](https://wpt.fyi/results/css/css-pseudo/marker-intrinsic-contribution-002.html "css/css-pseudo/marker-intrinsic-contribution-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-intrinsic-contribution-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-intrinsic-contribution-002.html)
- [marker-letter-spacing.html](https://wpt.fyi/results/css/css-pseudo/marker-letter-spacing.html "css/css-pseudo/marker-letter-spacing.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-letter-spacing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-letter-spacing.html)
- [marker-line-break.html](https://wpt.fyi/results/css/css-pseudo/marker-line-break.html "css/css-pseudo/marker-line-break.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-line-break.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-line-break.html)
- [marker-line-height.html](https://wpt.fyi/results/css/css-pseudo/marker-line-height.html "css/css-pseudo/marker-line-height.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-line-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-line-height.html)
- [marker-list-style-position.html](https://wpt.fyi/results/css/css-pseudo/marker-list-style-position.html "css/css-pseudo/marker-list-style-position.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-list-style-position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-list-style-position.html)
- [marker-overflow-wrap.html](https://wpt.fyi/results/css/css-pseudo/marker-overflow-wrap.html "css/css-pseudo/marker-overflow-wrap.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-overflow-wrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-overflow-wrap.html)
- [marker-reverted-styles.html](https://wpt.fyi/results/css/css-pseudo/marker-reverted-styles.html "css/css-pseudo/marker-reverted-styles.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-reverted-styles.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-reverted-styles.html)
- [marker-tab-size.html](https://wpt.fyi/results/css/css-pseudo/marker-tab-size.html "css/css-pseudo/marker-tab-size.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-tab-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-tab-size.html)
- [marker-text-align-001.html](https://wpt.fyi/results/css/css-pseudo/marker-text-align-001.html "css/css-pseudo/marker-text-align-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-text-align-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-text-align-001.html)
- [marker-text-align-002.html](https://wpt.fyi/results/css/css-pseudo/marker-text-align-002.html "css/css-pseudo/marker-text-align-002.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-text-align-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-text-align-002.html)
- [marker-text-align-003.html](https://wpt.fyi/results/css/css-pseudo/marker-text-align-003.html "css/css-pseudo/marker-text-align-003.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-text-align-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-text-align-003.html)
- [marker-text-combine-upright.html](https://wpt.fyi/results/css/css-pseudo/marker-text-combine-upright.html "css/css-pseudo/marker-text-combine-upright.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-text-combine-upright.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-text-combine-upright.html)
- [marker-text-decoration-skip-ink.html](https://wpt.fyi/results/css/css-pseudo/marker-text-decoration-skip-ink.html "css/css-pseudo/marker-text-decoration-skip-ink.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-text-decoration-skip-ink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-text-decoration-skip-ink.html)
- [marker-text-emphasis.html](https://wpt.fyi/results/css/css-pseudo/marker-text-emphasis.html "css/css-pseudo/marker-text-emphasis.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-text-emphasis.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-text-emphasis.html)
- [marker-text-transform-default.html](https://wpt.fyi/results/css/css-pseudo/marker-text-transform-default.html "css/css-pseudo/marker-text-transform-default.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-text-transform-default.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-text-transform-default.html)
- [marker-text-transform-dynamic.html](https://wpt.fyi/results/css/css-pseudo/marker-text-transform-dynamic.html "css/css-pseudo/marker-text-transform-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-text-transform-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-text-transform-dynamic.html)
- [marker-text-transform-uppercase.html](https://wpt.fyi/results/css/css-pseudo/marker-text-transform-uppercase.html "css/css-pseudo/marker-text-transform-uppercase.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-text-transform-uppercase.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-text-transform-uppercase.html)
- [marker-unicode-bidi-default-ref.html](https://wpt.fyi/results/css/css-pseudo/marker-unicode-bidi-default-ref.html "css/css-pseudo/marker-unicode-bidi-default-ref.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-unicode-bidi-default-ref.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-unicode-bidi-default-ref.html)
- [marker-unicode-bidi-default.html](https://wpt.fyi/results/css/css-pseudo/marker-unicode-bidi-default.html "css/css-pseudo/marker-unicode-bidi-default.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-unicode-bidi-default.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-unicode-bidi-default.html)
- [marker-unicode-bidi-normal-ref.html](https://wpt.fyi/results/css/css-pseudo/marker-unicode-bidi-normal-ref.html "css/css-pseudo/marker-unicode-bidi-normal-ref.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-unicode-bidi-normal-ref.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-unicode-bidi-normal-ref.html)
- [marker-unicode-bidi-normal.html](https://wpt.fyi/results/css/css-pseudo/marker-unicode-bidi-normal.html "css/css-pseudo/marker-unicode-bidi-normal.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-unicode-bidi-normal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-unicode-bidi-normal.html)
- [marker-variable-computed-style.html](https://wpt.fyi/results/css/css-pseudo/marker-variable-computed-style.html "css/css-pseudo/marker-variable-computed-style.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-variable-computed-style.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-variable-computed-style.html)
- [marker-variable.html](https://wpt.fyi/results/css/css-pseudo/marker-variable.html "css/css-pseudo/marker-variable.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-variable.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-variable.html)
- [marker-word-break.html](https://wpt.fyi/results/css/css-pseudo/marker-word-break.html "css/css-pseudo/marker-word-break.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-word-break.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-word-break.html)
- [marker-word-spacing.html](https://wpt.fyi/results/css/css-pseudo/marker-word-spacing.html "css/css-pseudo/marker-word-spacing.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/marker-word-spacing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/marker-word-spacing.html)
- [outside-marker-paint-order.html](https://wpt.fyi/results/css/css-pseudo/outside-marker-paint-order.html "css/css-pseudo/outside-marker-paint-order.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/outside-marker-paint-order.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/outside-marker-paint-order.html)
- [marker-supported-properties-in-animation.html](https://wpt.fyi/results/css/css-pseudo/parsing/marker-supported-properties-in-animation.html "css/css-pseudo/parsing/marker-supported-properties-in-animation.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/parsing/marker-supported-properties-in-animation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/parsing/marker-supported-properties-in-animation.html)
- [marker-supported-properties.html](https://wpt.fyi/results/css/css-pseudo/parsing/marker-supported-properties.html "css/css-pseudo/parsing/marker-supported-properties.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/parsing/marker-supported-properties.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/parsing/marker-supported-properties.html)

The contents of a
[::marker](#selectordef-marker) are ignored (not selected) by
[::first-letter](#selectordef-first-letter).

Interaction of
[::marker](#selectordef-marker) and
[::first-line](#selectordef-first-line) is currently under discussion in [Issue
4506](https://github.com/w3c/csswg-drafts/issues/4506).

[::marker](#selectordef-marker) is a [tree-abiding
pseudo-element](#tree-abiding),
but is not [fully styleable](#fully-styleable); only a limited set of properties can be used on the
[::marker] pseudo-element. This list
is defined in [CSS Lists 3 § 3.1.1 Properties Applying to
::marker](https://drafts.csswg.org/css-lists-3/#marker-properties).

The [::before::marker] or [::after::marker] selectors are
valid and can be used to represent the [marker
boxes](https://drafts.csswg.org/css-lists-3/#marker) of
[::before](#selectordef-before) or
[::after](#selectordef-after) pseudo-elements that happen to be [list
items](https://drafts.csswg.org/css-lists-3/#list-item). However [::marker::marker] is invalid, and the
computed value of
[display](https://drafts.csswg.org/css-display-4/#propdef-display) on
[::marker](#selectordef-marker) always loses any
[list-item](https://drafts.csswg.org/css-display-4/#valdef-display-list-item) aspect.

Should
[::marker](#selectordef-marker) also have
[::prefix](#selectordef-first-letter-prefix) and
[::suffix](#selectordef-first-letter-suffix) sub-elements?

### 4.3. Placeholder Input: the [::placeholder pseudo-element]
The [::placeholder]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) represents placeholder text in an input field: text
that represents the input and provides a hint to the user on how to fill
out the form. For example, a date-input field might have the placeholder
text "YYYY/MM/DD" to clarify that numeric dates are to be entered in
year-month-day order. It is a [tree-abiding
pseudo-element](#tree-abiding).

Tests

- [placeholder-as-multicol-crash.html](https://wpt.fyi/results/css/css-pseudo/placeholder-as-multicol-crash.html "css/css-pseudo/placeholder-as-multicol-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/placeholder-as-multicol-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/placeholder-as-multicol-crash.html)
- [placeholder-excluded-properties.html](https://wpt.fyi/results/css/css-pseudo/placeholder-excluded-properties.html "css/css-pseudo/placeholder-excluded-properties.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/placeholder-excluded-properties.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/placeholder-excluded-properties.html)
- [placeholder-inherit.html](https://wpt.fyi/results/css/css-pseudo/placeholder-inherit.html "css/css-pseudo/placeholder-inherit.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/placeholder-inherit.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/placeholder-inherit.html)
- [placeholder-input-dynamic-crash.html](https://wpt.fyi/results/css/css-pseudo/placeholder-input-dynamic-crash.html "css/css-pseudo/placeholder-input-dynamic-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/placeholder-input-dynamic-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/placeholder-input-dynamic-crash.html)
- [placeholder-input-number.html](https://wpt.fyi/results/css/css-pseudo/placeholder-input-number.html "css/css-pseudo/placeholder-input-number.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/placeholder-input-number.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/placeholder-input-number.html)

For example, according to the
semantics of
[\[HTML\]](#biblio-html "HTML Standard") the
[`placeholder`](https://html.spec.whatwg.org/multipage/input.html#attr-input-placeholder) attribute on the
[`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) and
[`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element) elements provide placeholder text. The
[::placeholder](#selectordef-placeholder)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) represents such text when it is displayed.

 There also exists a
[:placeholder-shown](https://drafts.csswg.org/selectors-4/#placeholder-shown-pseudo) pseudo-*class*, which applies to (real) elements
while they are showing placeholder text, and can be used to style such
elements specially.
[::placeholder](#selectordef-placeholder) specifically represents the placeholder *text*,
and is thus relatively limited in its abilities.

All properties that apply to the
[::first-line](#selectordef-first-line) pseudo-element also apply to the
[::placeholder](#selectordef-placeholder) pseudo-element, except those defined in
[\[CSS-INLINE-3\]](#biblio-css-inline-3 "CSS Inline Layout Module Level 3").

In interactive media, placeholder text is often hidden once the user has
entered input; however this is not a requirement, and both the input
value and the placeholder text may be visible simultaneously. The exact
behavior is UA-defined. Note that in static media (such as print)
placeholder text will be present even after the user has entered input.

Authors seem to want
[text-align](https://drafts.csswg.org/css-text-3/#propdef-text-align) on the list of supported
properties. See e.g. [comments
here](http://css-tricks.com/almanac/selectors/p/placeholder/).

 It's been requested that
[::placeholder](#selectordef-placeholder) also refer to a placeholder which has a
corresponding element in the element tree. It's not clear how this
should work, but it may be worth doing. See [Issue
2417](https://github.com/w3c/csswg-drafts/issues/2517).

### 4.4. Interest Indicators: the [::interest-button pseudo-element]
The [::interest-button]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) represents a button which, when pressed, [shows
interest](https://drafts.csswg.org/selectors-5/#show-interest) in the [originating
element](https://drafts.csswg.org/selectors-4/#originating-element). This pseudo-element only exists on valid [interest
sources](https://drafts.csswg.org/selectors-5/#interest-source). (See
[interest-delay](https://drafts.csswg.org/css-ui-4/#propdef-interest-delay),
[:interest-source](https://drafts.csswg.org/selectors-5/#selectordef-interest-source), and
[:interest-target](https://drafts.csswg.org/selectors-5/#selectordef-interest-target) for more discussion of this feature, and the
HTML `interestfor` attribute.)

Host languages typically allow multiple ways to [show
interest](https://drafts.csswg.org/selectors-5/#show-interest) in an [interest
source](https://drafts.csswg.org/selectors-5/#interest-source), but sometimes the primary interest-showing mechanism
is also used by another interaction; for example, on a touchscreen,
long-pressing a link might [show interest], but
it might also bring up a context menu where [showing
interest] is just one of the several options.

If it's expected that [showing
interest](https://drafts.csswg.org/selectors-5/#show-interest) will be something users often want to do, this conflict
can be avoided with the
[::interest-button](#selectordef-interest-button) pseudo-element. [Showing
interest] in the
[::interest-button], *or*
directly activating it, is treated as [showing
interest] in the [originating
element](https://drafts.csswg.org/selectors-4/#originating-element) instead.

 Using
[::interest-button](#selectordef-interest-button) does not change how the [originating
element](https://drafts.csswg.org/selectors-4/#originating-element) can have [interest
shown](https://drafts.csswg.org/selectors-5/#show-interest); it's an *additional* mechanism to make it easier or
more obvious that the user can [show interest]
in the element to gain some additional information.

[:interest-button] is intentionally *not* focusable (and thus not
keyboard-activatable), nor does it appear in the accessibility tree. All
the information it communicates is already present on the [originating
element](https://drafts.csswg.org/selectors-4/#originating-element).

[::interest-button](#selectordef-interest-button) is a [fully styleable
pseudo-element](#fully-styleable). When its computed
[content](https://drafts.csswg.org/css-content-3/#propdef-content) value is not
[none](https://drafts.csswg.org/css-content-3/#valdef-content-none), it generates boxes as if it were a *following
sibling* of its [originating
element](https://drafts.csswg.org/selectors-4/#originating-element), before any [::scroll-button()] pseudo-elements
that might also be on the [originating
element]. It inherits from the
[originating element] as normal.

 The default UA styles defined for HTML *do not* set a
[content](https://drafts.csswg.org/css-content-3/#propdef-content) value, meaning the author must
opt-in to having the
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) appear in HTML.

The typical glyph used for this purpose is ⓘ (U+24D8 CIRCLED LATIN SMALL
LETTER I), which can be used like:

``` highlight
@media (any-pointer: coarse) {
 a::interest-button {
 content: "ⓘ" / "";
 }
}
```

While not required to be used, note the MQ and selector used here, only
showing the button on links (which definitely bring up a context menu
when long-pressed on touchscreens) and only when the user only has
access to a coarse pointer (such as a finger on a touchscreen). If
desired, tho, there is nothing wrong with showing it more widely, with a
less restrictive selector and/or no [media
query](https://drafts.csswg.org/mediaqueries-5/#media-query).

<figure id="example-c84bfcb1" class="example">
<a href="#example-c84bfcb1" class="self-link"></a> <img
src="images/interest-button.png" width="463" height="442" />
<figcaption>Several examples of <a href="#selectordef-interest-button"
id="ref-for-selectordef-interest-button⑤" class="css"
data->::interest-button</a> rendering with several
combinations of both links and buttons, in a plain usage, alongside <a
href="#selectordef-after" id="ref-for-selectordef-after⑥" class="css"
data->::after</a> to demonstrate their relative
ordering, and inline alongside following text.</figcaption>
</figure>

## 5. Element-backed Pseudo-Elements

The [element-backed pseudo-elements], interact with most
CSS and other platform features as if they were real elements (and, in
fact, often *are* real elements that are not otherwise selectable).

Element-backed pseudo-elements are always
[tree-abiding](#tree-abiding).
Unless otherwise specified, they are [fully
styleable](#fully-styleable)
and inherit from their [originating
element](https://drafts.csswg.org/selectors-4/#originating-element), just like standard [tree-abiding
pseudo-elements]; but they can be defined to
inherit from another element instead. (For example,
[::part()](https://drafts.csswg.org/css-shadow-1/#selectordef-part) inherits from the parent of the element it
represents in the shadow tree.)

All
[pseudo-classes](https://www.w3.org/TR/CSS2/selector.html#x23) and
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) are syntactically allowed after an [element-backed
pseudo-element](#element-backed) (such as [x-button::part(label):hover] or
[x-button::part(label)::before]), just as if the pseudo-element
were a [type
selector](https://drafts.csswg.org/selectors-4/#type-selector); but some are disallowed from matching:

- The [structural
 pseudo-classes](https://drafts.csswg.org/selectors-4/#structural-pseudo-classes),
 [:has()](https://drafts.csswg.org/selectors-4/#has-pseudo) pseudo-class,
 [:scope](https://drafts.csswg.org/selectors-4/#scope-pseudo) pseudo-class, and
 [:host](https://drafts.csswg.org/css-shadow-1/#selectordef-host)/[:host()](https://drafts.csswg.org/css-shadow-1/#selectordef-host-function)/[:host-context()](https://drafts.csswg.org/css-shadow-1/#selectordef-host-context) pseudo-classes never match.

- [::part()](https://drafts.csswg.org/css-shadow-1/#selectordef-part) never matches. (Other [element-backed
 pseudo-elements](#element-backed) can, however.)

An [element-backed
pseudo-element](#element-backed) can define itself as representing a real element
(possibly one not accessible in the current tree). If it does so, all
pseudo-classes and pseudo-elements not otherwise disallowed (see above)
match as they would on that real element. If it does not do so, it must
define which pseudo-classes it matches and when; however, unless
otherwise specified, any pseudo-classes allowed on [tree-abiding
pseudo-elements](#tree-abiding)
are always allowed on [element-backed
pseudo-elements].

### 5.1. File Selector Button: the [::file-selector-button pseudo-element]
The [::file-selector-button]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) targets the [\<button\>] inside an
[\<input\>] element with `type=file`, if the UA
renders such a button.

Tests

- [file-selector-button-001.html](https://wpt.fyi/results/css/css-pseudo/file-selector-button-001.html "css/css-pseudo/file-selector-button-001.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/file-selector-button-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/file-selector-button-001.html)
- [file-selector-button-after-part.html](https://wpt.fyi/results/css/css-pseudo/file-selector-button-after-part.html "css/css-pseudo/file-selector-button-after-part.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/file-selector-button-after-part.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/file-selector-button-after-part.html)
- [file-selector-button-display-none-overflow-crash.html](https://wpt.fyi/results/css/css-pseudo/file-selector-button-display-none-overflow-crash.html "css/css-pseudo/file-selector-button-display-none-overflow-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/file-selector-button-display-none-overflow-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/file-selector-button-display-none-overflow-crash.html)
- [file-selector-button-display-toggle-crash.html](https://wpt.fyi/results/css/css-pseudo/file-selector-button-display-toggle-crash.html "css/css-pseudo/file-selector-button-display-toggle-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/file-selector-button-display-toggle-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/file-selector-button-display-toggle-crash.html)
- [file-selector-button-float.html](https://wpt.fyi/results/css/css-pseudo/file-selector-button-float.html "css/css-pseudo/file-selector-button-float.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/file-selector-button-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/file-selector-button-float.html)
- [file-selector-button-inherit.html](https://wpt.fyi/results/css/css-pseudo/file-selector-button-inherit.html "css/css-pseudo/file-selector-button-inherit.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/file-selector-button-inherit.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/file-selector-button-inherit.html)

There is no restriction on which properties apply to the
[::file-selector-button](#selectordef-file-selector-button) pseudo-element.

For example, the following
example should show a green border around the file selector button:

```
::file-selector-button { border: 3px solid green }
```

### 5.2. Expandable contents of details element: the [::details-content pseudo-element]
The [::details-content]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) targets the additional information in a
[`details`](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-details-element) element that can be expanded or collapsed. It is an
[element-backed
pseudo-element](#element-backed).

Tests

details element

------------------------------------------------------------------------

There is no restriction on which properties apply to the
[::details-content](#selectordef-details-content) pseudo-element.

For example, the following
example would animate the opacity of the additional information when the
[`details`](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-details-element) element opens:

```
details::details-content {
 opacity: 0;
 transition: content-visibility 300ms allow-discrete, opacity 300ms;
}

details[open]::details-content {
 opacity: 1;
}
```

 The default UA stylesheet styles a closed
[::details-content](#selectordef-details-content) with [content-visibility:
hidden](https://drafts.csswg.org/css-contain-2/#propdef-content-visibility), so the contents are still considered present
for the purpose of find-in-page and similar features. This, however,
only suppresses the display of the pseudo-elements's *contents*; if
margin, borders, etc are set on the pseudo-element, they'll still be
visible. Use [\[open\]::details-content] to apply these styles if
that's undesirable.

## 6. Overlapping Pseudo-element Interactions

Recall that

- the contents of
 [::before](#selectordef-before) and
 [::after](#selectordef-after) are selected exactly as if they were normal
 elements in the document source tree
- the
 [::first-letter](#selectordef-first-letter) boundaries are tightly wrapped around the
 first letter text, and
 [::first-letter] is
 constrained to exist solely on the first formatted line.
- the
 [::first-line](#selectordef-first-line) start is inserted just inside the containing
 block's element boundary, and its end after the close of all content
 on the line

The following CSS and HTML example illustrates how overlapping
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) interact:

```
<style>
p { color: red; font-size: 12pt }
p::first-letter { color: green; font-size: 200% }
p::first-line { color: blue }
</style>

<p>Some text that ends up on two lines</p>
```

The first letter of each P element will be green with a font size of
'24pt\'. The rest of the first formatted line will be blue while the
rest of the paragraph will be red.

Assuming that a line break will occur before the word \"ends\", the
[fictional tag
sequence](#fictional-tag-sequence) for this fragment might be:

```
<p>
 <p::first-line>
 <p::first-letter>
 S
 </p::first-letter>
 ome text that
 </p::first-line>
 ends up on two lines
</p>
```

## 7. Additions to the CSS Object Model

Tests

- [idlharness.html](https://wpt.fyi/results/css/css-pseudo/idlharness.html "css/css-pseudo/idlharness.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/idlharness.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/idlharness.html)

### 7.1. [`CSSPseudoElement` Interface]
```
[Exposed=Window]
interface CSSPseudoElement {
 readonly attribute CSSOMString type;
 readonly attribute Element element;
 readonly attribute (Element or CSSPseudoElement) parent;
 readonly attribute CSSOMString selectorText;
 CSSPseudoElement? pseudo(CSSOMString type);
};
```

Tests

- [CSSPseudoElement-identity.html](https://wpt.fyi/results/css/css-pseudo/CSSPseudoElement-identity.html "css/css-pseudo/CSSPseudoElement-identity.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/CSSPseudoElement-identity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/CSSPseudoElement-identity.html)

This interface is under design
development, and this draft is looking for feedback more than
implementation. The CSSWG would particularly appreciate hearing about
use cases and problems.

The [`type`]
attribute is a string representing the type of the pseudo-element. This
can be any standardized [tree-abiding
pseudo-element](#tree-abiding)
that is not an [element-backed
pseudo-element](#element-backed), for example:

`"::before"`
: Represents the
 [::before](#selectordef-before) pseudo-element.

`"::after"`
: Represents the
 [::after](#selectordef-after) pseudo-element.

`"::marker"`
: Represents the
 [::marker](#selectordef-marker) pseudo-element.

`"::backdrop"`
: Represents the
 [::backdrop](https://drafts.csswg.org/css-position-4/#selectordef-backdrop) pseudo-element.

`"::view-transition"`
: Represents the
 [::view-transition](https://drafts.csswg.org/css-view-transitions-2/#selectordef-view-transition) pseudo-element.

The [`element`] attribute is the [ultimate originating
element](https://drafts.csswg.org/selectors-4/#ultimate-originating-element) of the
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element).

The [`parent`] attribute is the [originating
element](https://drafts.csswg.org/selectors-4/#originating-element) of the pseudo-element. For most pseudo-elements
[`parent`](#dom-csspseudoelement-parent) and
[`element`](#dom-csspseudoelement-element) will return the same
[`Element`](https://dom.spec.whatwg.org/#element); for
[sub-pseudo-elements](https://drafts.csswg.org/selectors-4/#sub-pseudo-element),
[`parent`](#dom-csspseudoelement-parent) will return a
[`CSSPseudoElement`](#csspseudoelement) while
[`element`](#dom-csspseudoelement-element) returns an
[`Element`](https://dom.spec.whatwg.org/#element).

The [`selectorText`] attribute is a string representing the full, normalized
selector text used to select the pseudo-element. This includes the
pseudo-element name and any arguments, serialized in a form that can
round-trip. For example, `"::after"` for a
[::after](#selectordef-after) pseudo-element, or
`"::scroll-button(left)"` for a [::scroll-button()]
pseudo-element with a `left` argument.

The [`pseudo(type)`] method returns the
[`CSSPseudoElement`](#csspseudoelement) interface representing the
[sub-pseudo-element](https://drafts.csswg.org/selectors-4/#sub-pseudo-element) referenced in its argument, if such a
[sub-pseudo-element] could exist and would
be valid, and null otherwise. See
[`pseudo()`](#dom-element-pseudo) below.

 This interface may be extended in the future to other
pseudo-element types and/or to allow setting style information through a
[`CSSStyleDeclaration`](https://drafts.csswg.org/cssom-1/#cssstyledeclaration) `style` attribute. The current
functionality is limited to that which is needed to support
[\[web-animations-1\]](#biblio-web-animations-1 "Web Animations").

### 7.2. [`pseudo()` method of the [`Element`](https://dom.spec.whatwg.org/#element) interface]
A new method is added to the
[`Element`](https://dom.spec.whatwg.org/#element) interface to retrieve
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) created by a given element for a given type:

```
partial interface Element {
 CSSPseudoElement? pseudo(CSSOMString type);
};
```

The [`pseudo(CSSOMString type)`] method is used to retrieve the
[`CSSPseudoElement`](#csspseudoelement) instance of the type matching
[`type`](#dom-element-pseudo-type-type) associated with the element. When it is
called, execute the following steps:

1. [Parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) the
 [`type`](#dom-element-pseudo-type-type) argument as a
 [\<pseudo-element-selector\>](https://drafts.csswg.org/selectors-4/#typedef-pseudo-element-selector), and let `type` be the
 result.

2. If `type` is failure, return null.

3. If `type` is an [element-backed
 pseudo-element](#element-backed), return null.

4. If `type` is not a [tree-abiding
 pseudo-element](#tree-abiding), return null.

5. Otherwise, return the
 [`CSSPseudoElement`](#csspseudoelement) object representing the pseudo-element that would
 match the selector `type` with
 [this](https://webidl.spec.whatwg.org/#this) as its [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element).

Return values that represent the same
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) on the same [originating
element](https://drafts.csswg.org/selectors-4/#originating-element) must be, insofar as observable, always the same
[`CSSPseudoElement`](#csspseudoelement) object. (The UA may drop or regenerate the object for
convenience or performance if this is not observable.)

[`CSSPseudoElement`](#csspseudoelement) is returned even when this method is invoked on
elements that can't have the requested pseudo type (e.g.
[::before](#selectordef-before) on
[`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element)). See
[resolution](https://github.com/w3c/csswg-drafts/issues/12159#issuecomment-3005238286)
for more details. Discussion in [Issue
12158](https://github.com/w3c/csswg-drafts/issues/12158) will clarify
how to determine that the requested pseudo doesn't really \"exist\".

The identity, lifetime, and nullness of
the return value (and potential error cases) of the
[`pseudo()`](#dom-csspseudoelement-pseudo-type) method is still under discussion. See [Issue
3607](https://github.com/w3c/csswg-drafts/issues/3607) and [Issue
3603](https://github.com/w3c/csswg-drafts/issues/3603).

### [7.3. ][ [`getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle)]
When the second parameter `pseudoElt` refers to a [highlight
pseudo-element](#highlight-pseudo-element),
[`getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle) returns styles as if that highlight is active and all
other highlights are inactive. This avoids the potential ambiguity and
privacy risks of returning a result that depends on the actual highlight
state.

## 8. Compatibility Syntax

For compatibility with existing style sheets written against CSS Level 2
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
user agents must also accept the previous one-colon notation
(`:before`, `:after`,
`:first-letter`, `:first-line`) for the
[::before](#selectordef-before),
[::after](#selectordef-after),
[::first-letter](#selectordef-first-letter), and
[::first-line](#selectordef-first-line) pseudo-elements.

## [ Security Considerations]
For highlighting, see [§ 3.7 Security Considerations for
Highlighting](#highlight-security).

## [ Privacy Considerations]
No new privacy considerations have been raised against this module.

## [ Changes]
Significant changes since the [30 December 2022 Working
Draft](https://www.w3.org/TR/2022/WD-css-pseudo-4-20221230/) include:

- Defined [element-backed
 pseudo-element](#element-backed) and [fully styleable
 pseudo-element](#fully-styleable) as terms. ([Issue
 10199](https://github.com/w3c/csswg-drafts/pull/10199), [Issue
 10083](https://github.com/w3c/csswg-drafts/issues/10083))
- Reworked the property (and custom property) application and
 inheritance model for [highlight
 pseudo-elements](#highlight-pseudo-element) (Issues
 [7591](https://github.com/w3c/csswg-drafts/issues/7591),
 [7580](https://github.com/w3c/csswg-drafts/issues/7580),
 [6641](https://github.com/w3c/csswg-drafts/issues/6641),
 [11317](https://github.com/w3c/csswg-drafts/issues/11317))
- Defined
 [::highlight()](#selectordef-highlight-highlight-name-selector) and improved cross-referencing to
 [\[CSS-HIGHLIGHT-API-1\]](#biblio-css-highlight-api-1 "CSS Custom Highlight API Module Level 1").
 (Issue [6755](https://github.com/w3c/csswg-drafts/issues/6755))
- Added
 [::search-text](#selectordef-search-text) as a new [highlight
 pseudo-element](#highlight-pseudo-element), and allowed it to combine with
 [:current](https://drafts.csswg.org/selectors-5/#current-pseudo). (Issues
 [10212](https://github.com/w3c/csswg-drafts/issues/10212)
 [10213](https://github.com/w3c/csswg-drafts/issues/10213), and
 [10298](https://github.com/w3c/csswg-drafts/issues/10298))
- Added
 [::details-content](#selectordef-details-content)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) ([Issue
 10379](https://github.com/w3c/csswg-drafts/pull/10379))
- Allow space and no-break space to be part of
 [::first-letter](#selectordef-first-letter) when occuring before the [first
 letter](#first-letter).
 ([Issue 9413](https://github.com/w3c/csswg-drafts/issues/9413))
- Renamed [::postfix] to
 [::suffix](#selectordef-first-letter-suffix). (Issue [Issue
 11949](https://github.com/w3c/csswg-drafts/issues/11949))
- Excluded inline layout properties from
 [::placeholder](#selectordef-placeholder). ([Issue
 5379](https://github.com/w3c/csswg-drafts/issues/5379))
- Clarified that UAs must not tweak author-specified colors for
 [highlight
 pseudo-elements](#highlight-pseudo-element). ([Issue
 6853](https://github.com/w3c/csswg-drafts/issues/6853))
- Clarified that the inherited value of
 [color](https://drafts.csswg.org/css-color-4/#propdef-color) is
 [currentColor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor), not the [initial
 value](https://drafts.csswg.org/css-cascade-5/#initial-value).

Significant changes since the [31 December 2020 Working
Draft](https://www.w3.org/TR/2020/WD-css-pseudo-4-20201231/) include:

- Added [::first-letter::prefix] and
 [::first-letter::postfix]
 [sub-pseudo-elements](https://drafts.csswg.org/selectors-4/#sub-pseudo-element) to address punctuation associated with the
 [::first-letter](#selectordef-first-letter)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element). ([Issue
 2040](https://github.com/w3c/csswg-drafts/issues/2040))
- Fine-tuned the [first-letter
 text](#first-letter-text) pattern:
 - Excluded word-separating spaces from [first-letter
 text](#first-letter-text). ([Issue
 5830](https://github.com/w3c/csswg-drafts/issues/5830))
 - Excluded dashes and opening punctuation from following punctuation.
 ([Issue 5830](https://github.com/w3c/csswg-drafts/issues/5830))
 - Allowed symbols to represent the [first
 letter](#first-letter).
 ([Issue 5099](https://github.com/w3c/csswg-drafts/issues/5099))
 - Clarified that the [first-letter
 text](#first-letter-text) is truncated by a line break. ([Issue
 2254](https://github.com/w3c/csswg-drafts/issues/2254))
- Rewrote and clarified definition of
 [:first-letter](https://drafts.csswg.org/css2/#selectordef-first-letter), and improved examples and notes.
- Rewrote and clarified definition of
 [::first-line](#selectordef-first-line), and improved examples.
- Defined application of
 [line-height](https://drafts.csswg.org/css2/#propdef-line-height) to
 [::first-line](#selectordef-first-line). ([Issue
 2282](https://github.com/w3c/csswg-drafts/issues/2282))
- Defined box structure interaction of
 [::first-line](#selectordef-first-line) and
 [::first-letter](#selectordef-first-letter).
- Defined hierarchy order of
 [::first-line](#selectordef-first-line) and the [root inline
 box](https://drafts.csswg.org/css-inline-3/#root-inline-box). ([Issue
 1384](https://github.com/w3c/csswg-drafts/issues/1384))
- Clarified [paired default](#paired-defaults) behavior of [highlight
 pseudo-element](#highlight-pseudo-element)
 [color](https://drafts.csswg.org/css-color-4/#propdef-color) and
 [background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color). ([Issue
 6386](https://github.com/w3c/csswg-drafts/issues/6386), [Issue
 6774](https://github.com/w3c/csswg-drafts/issues/6774), [Issue
 6779](https://github.com/w3c/csswg-drafts/issues/6779), [Issue
 7837](https://github.com/w3c/csswg-drafts/issues/7837))
- Defined application of [forced colors
 mode](https://drafts.csswg.org/css-color-adjust-1/#forced-colors-mode) to [highlight
 pseudo-elements](#highlight-pseudo-element). ([Issue
 7264](https://github.com/w3c/csswg-drafts/issues/7264))
- Clarified painting order, propagation, and application of [highlight
 pseudo-element](#highlight-pseudo-element) text decorations. ([Issue
 6022](https://github.com/w3c/csswg-drafts/issues/6022), [Issue
 6829](https://github.com/w3c/csswg-drafts/issues/6829), [Issue
 7101](https://github.com/w3c/csswg-drafts/issues/7101))
- Removed
 [caret-color](https://drafts.csswg.org/css-ui-4/#propdef-caret-color) and
 [cursor](https://drafts.csswg.org/css-ui-4/#propdef-cursor) from applying to [highlight
 pseudo-elements](#highlight-pseudo-element). ([Issue
 4100](https://github.com/w3c/csswg-drafts/issues/4100))
- Clarified interaction of [highlight
 pseudo-elements](#highlight-pseudo-element) and
 [`getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle). ([Issue
 6818](https://github.com/w3c/csswg-drafts/issues/6818))
- Clarified application of [custom
 properties](https://drafts.csswg.org/css-variables-2/#custom-property) to
 [pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element). ([Issue
 6264](https://github.com/w3c/csswg-drafts/issues/6264))
-
- Extended the
 [`CSSPseudoElement`](#csspseudoelement) interface with a
 [`parent`](#dom-csspseudoelement-parent) attribute and
 [`pseudo()`](#dom-csspseudoelement-pseudo-type) method to address
 [sub-pseudo-elements](https://drafts.csswg.org/selectors-4/#sub-pseudo-element). ([Issue
 3836](https://github.com/w3c/csswg-drafts/issues/3836))

Significant changes since the [25 February 2019 Working
Draft](https://www.w3.org/TR/2019/WD-css-pseudo-4-20190225/) include:

- Added
 [::target-text](#selectordef-target-text)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element). ([Issue
 5522](https://github.com/w3c/csswg-drafts/issues/5522))
- Removed [::inactive-selection]. ([Issue
 4579](https://github.com/w3c/csswg-drafts/issues/4579))
- Added [::file-selectors-button]
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element). ([Issue
 5049](https://github.com/w3c/csswg-drafts/issues/5049))
- Adjusted rules for inheritance of properties from
 [::first-line](#selectordef-first-line) to handle inheritable vs non-inheritable
 properties differently, specifically excluded applicability of
 properties that control [writing
 mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) because they affect the cascade, and defined
 interaction with custom properties. ([Issue
 1097](https://github.com/w3c/csswg-drafts/issues/1097))
- Added
 [ruby-position](https://drafts.csswg.org/css-ruby-1/#propdef-ruby-position) to properties allowed on
 [::first-line](#selectordef-first-line), analogous with
 [text-emphasis-position](https://drafts.csswg.org/css-text-decor-4/#propdef-text-emphasis-position). ([Issue
 2998](https://github.com/w3c/csswg-drafts/issues/2998))
- Included spaces between the first letter and its surrounding
 punctuation in
 [::first-letter](#selectordef-first-letter). ([Issue
 5154](https://github.com/w3c/csswg-drafts/issues/5154))
- Defined interaction of
 [::marker](#selectordef-marker) and
 [::first-letter](#selectordef-first-letter).
- Made [::before::marker] and [::after::marker] valid.
 ([Issue 1793](https://github.com/w3c/csswg-drafts/issues/1793))
- Moved the [list of
 properties](https://www.w3.org/TR/css-lists-3/#marker-properties)
 applying to
 [::marker](#selectordef-marker) to
 [\[CSS-LISTS-3\]](#biblio-css-lists-3 "CSS Lists and Counters Module Level 3")
 (also adding
 [content](https://drafts.csswg.org/css-content-3/#propdef-content),
 [unicode-bidi](https://drafts.csswg.org/css-writing-modes-3/#propdef-unicode-bidi), and
 [direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction)).
- Added [::marker](#selectordef-marker) to types allowed for
 [`CSSPseudoElement`](#csspseudoelement) interface. ([Issue
 3763](https://github.com/w3c/csswg-drafts/issues/3763))
- Clarified return value of
 [`pseudo()`](#dom-element-pseudo). (Issues
 [3603](https://github.com/w3c/csswg-drafts/issues/3603) and
 [3607](https://github.com/w3c/csswg-drafts/issues/3607))
- Allowed highlight overlay of inline-level boxes to extend to the line
 box edges. (Issues
 [5395](https://github.com/w3c/csswg-drafts/issues/5395) and
 [4624](https://github.com/w3c/csswg-drafts/issues/4624))
- Clarified that
 [currentColor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor) on a [highlight
 pseudo-element](#highlight-pseudo-element) uses the color that would be used if the text were
 not "highlighted", even if that color was provided by a
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) like
 [::first-line](#selectordef-first-line). ([Issue
 4625](https://github.com/w3c/csswg-drafts/issues/4625))
- Defined how
 [text-shadow](https://drafts.csswg.org/css-text-decor-4/#propdef-text-shadow) interacts with [highlight
 pseudo-elements](#highlight-pseudo-element). ([Issue
 3932](https://github.com/w3c/csswg-drafts/issues/3932))
- Improved the [default UA style sheet](#highlight-ua-styles) rules
 applying to highlight pseudo-elements.

Changes since the [7 June 2016 Working
Draft](https://www.w3.org/TR/2016/WD-css-pseudo-4-20160607/) include:

- Specified
 [spelling-error](https://drafts.csswg.org/css-text-decor-4/#valdef-text-decoration-line-spelling-error) and
 [grammar-error](https://drafts.csswg.org/css-text-decor-4/#valdef-text-decoration-line-grammar-error) with
 [::spelling-error](#selectordef-spelling-error) and
 [::grammar-error](#selectordef-grammar-error) in the UA stylesheet.
- Redefined value propagation between parent/child [highlight
 pseudo-elements](#highlight-pseudo-element) to use inheritance rather than cascading. See
 discussion in and linked from [Issue
 2474](https://github.com/w3c/csswg-drafts/issues/2474).
- Refined list of supported properties for [highlight
 pseudo-elements](#highlight-pseudo-element), e.g. adding
 [stroke-color](https://drafts.csswg.org/fill-stroke-3/#propdef-stroke-color)/[fill-color](https://drafts.csswg.org/fill-stroke-3/#propdef-fill-color), removing
 [outline](https://drafts.csswg.org/css-ui-4/#propdef-outline), etc.
- Clarified how text and text decoration colors are painted for
 [highlight
 pseudo-elements](#highlight-pseudo-element).
- Added the
 [`element`](#dom-csspseudoelement-element) attribute to the
 [`CSSPseudoElement`](#csspseudoelement) interface.
- Changed the values of the
 [`type`](#dom-csspseudoelement-type) attribute on the
 [`CSSPseudoElement`](#csspseudoelement) interface to match the corresponding
 [pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element).
- Reduced supported types of
 [`CSSPseudoElement`](#csspseudoelement) and removed unimplemented `style`
 attribute.
- Changed `window.getPseudoElements(elem,type)` to
 `Element.pseudo(type)`.
- Miscellaneous minor clarifications and fixes.

## [ Acknowledgements]
The editors would like to specifically thank the following individuals
for their contributions to this specification: Tab Atkins, Delan
Azabani, David Baron, Oriol Brufau, Razvan Caliman, Stephen Chenney,
Chris Coyier, Anders Grimsrud, Vincent Hardy, François Remy.
