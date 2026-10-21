## [ Introduction]

Authors sometimes want user agents to render content that does not come
from the document tree. One familiar example of this is numbered
headings; the author does not want to mark the numbers up explicitly,
they want the user agent to generate them automatically. Counters and
markers are used to achieve these effects.

``` highlight
h1::before { content: counter(section) ": "; }
```

Similarly, authors may want the user agent to insert the word \"Figure\"
before the caption of a figure, or \"Chapter 7\" on a line before the
seventh chapter title.

``` highlight
chapter { counter-increment: chapter; }
chapter > title::before { content: "Chapter " counter(chapter) "\A"; }
```

Another common effect is replacing elements with images or other
multimedia content. Since not all user agents support all multimedia
formats, fallbacks may have to be provided.

``` highlight
/* Replace <logo> elements with the site's logo, using a format
 * supported by the UA */
logo { content: url(logo.mov), url(logo.mng), url(logo.png), none; }

/* Replace <figure> elements with the referenced document, or,
 * failing that, with either the contents of the alt attribute or the
 * contents of the element itself if there is no alt attribute */
figure[alt] { content: attr(href url), attr(alt); }
figure:not([alt]) { content: attr(href url), contents; }
```

General tests for generated content

- [inheritance.html](https://wpt.fyi/results/css/css-content/inheritance.html "css/css-content/inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-content/inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/inheritance.html)

------------------------------------------------------------------------

### [ Value Definitions]

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

## 1. Inserting and Replacing Content: the [content property]
Name:

[content]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) none [\|] \[
[\<content-replacement\>](#typedef-content-replacement) [\|]
[\<content-list\>](#typedef-content-list) \] \[/
[\<alt-text\>](#typedef-alt-text)
\][?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements, tree-abiding pseudo-elements, and page margin boxes

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

See prose below

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Tests

- [attr-case-sensitivity-001.html](https://wpt.fyi/results/css/css-content/attr-case-sensitivity-001.html "css/css-content/attr-case-sensitivity-001.html")
 [[(live
 test)]](http://wpt.live/css/css-content/attr-case-sensitivity-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/attr-case-sensitivity-001.html)
- [attr-case-sensitivity-002.html](https://wpt.fyi/results/css/css-content/attr-case-sensitivity-002.html "css/css-content/attr-case-sensitivity-002.html")
 [[(live
 test)]](http://wpt.live/css/css-content/attr-case-sensitivity-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/attr-case-sensitivity-002.html)
- [attr-case-sensitivity-003.html](https://wpt.fyi/results/css/css-content/attr-case-sensitivity-003.html "css/css-content/attr-case-sensitivity-003.html")
 [[(live
 test)]](http://wpt.live/css/css-content/attr-case-sensitivity-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/attr-case-sensitivity-003.html)
- [computed-value.html](https://wpt.fyi/results/css/css-content/computed-value.html "css/css-content/computed-value.html")
 [[(live
 test)]](http://wpt.live/css/css-content/computed-value.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/computed-value.html)
- [content-animation.html](https://wpt.fyi/results/css/css-content/content-animation.html "css/css-content/content-animation.html")
 [[(live
 test)]](http://wpt.live/css/css-content/content-animation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/content-animation.html)
- [content-no-interpolation.html](https://wpt.fyi/results/css/css-content/content-no-interpolation.html "css/css-content/content-no-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-content/content-no-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/content-no-interpolation.html)
- [content-none-select-1.html](https://wpt.fyi/results/css/css-content/content-none-select-1.html "css/css-content/content-none-select-1.html")
 [[(live
 test)]](http://wpt.live/css/css-content/content-none-select-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/content-none-select-1.html)
- [element-replacement-alt.html](https://wpt.fyi/results/css/css-content/element-replacement-alt.html "css/css-content/element-replacement-alt.html")
 [[(live
 test)]](http://wpt.live/css/css-content/element-replacement-alt.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/element-replacement-alt.html)
- [element-replacement-display-contents.html](https://wpt.fyi/results/css/css-content/element-replacement-display-contents.html "css/css-content/element-replacement-display-contents.html")
 [[(live
 test)]](http://wpt.live/css/css-content/element-replacement-display-contents.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/element-replacement-display-contents.html)
- [element-replacement-display-none.html](https://wpt.fyi/results/css/css-content/element-replacement-display-none.html "css/css-content/element-replacement-display-none.html")
 [[(live
 test)]](http://wpt.live/css/css-content/element-replacement-display-none.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/element-replacement-display-none.html)
- [element-replacement-dynamic.html](https://wpt.fyi/results/css/css-content/element-replacement-dynamic.html "css/css-content/element-replacement-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-content/element-replacement-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/element-replacement-dynamic.html)
- [element-replacement-gradient.html](https://wpt.fyi/results/css/css-content/element-replacement-gradient.html "css/css-content/element-replacement-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-content/element-replacement-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/element-replacement-gradient.html)
- [element-replacement-image-alt.html](https://wpt.fyi/results/css/css-content/element-replacement-image-alt.html "css/css-content/element-replacement-image-alt.html")
 [[(live
 test)]](http://wpt.live/css/css-content/element-replacement-image-alt.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/element-replacement-image-alt.html)
- [element-replacement.html](https://wpt.fyi/results/css/css-content/element-replacement.html "css/css-content/element-replacement.html")
 [[(live
 test)]](http://wpt.live/css/css-content/element-replacement.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/element-replacement.html)
- [content-computed.html](https://wpt.fyi/results/css/css-content/parsing/content-computed.html "css/css-content/parsing/content-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-content/parsing/content-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/parsing/content-computed.html)
- [content-counter-valid.html](https://wpt.fyi/results/css/css-content/parsing/content-counter-valid.html "css/css-content/parsing/content-counter-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-content/parsing/content-counter-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/parsing/content-counter-valid.html)
- [content-invalid.html](https://wpt.fyi/results/css/css-content/parsing/content-invalid.html "css/css-content/parsing/content-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-content/parsing/content-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/parsing/content-invalid.html)
- [content-valid.html](https://wpt.fyi/results/css/css-content/parsing/content-valid.html "css/css-content/parsing/content-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-content/parsing/content-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/parsing/content-valid.html)

*User agents are expected to support this property on all media,
including non-visual ones.*

The [content](#propdef-content) property specifies the box's contents for
stylistic purposes. It can replace the box with an image (turning it
into a [replaced
element](https://drafts.csswg.org/css-display-4/#replaced-element)), or provide it with arbitrary inline-level content
(text and images). It can also, for some types of boxes, control whether
the box renders at all.

```
<content-replacement> = <image>
<content-list> = [ <string> | <image> | <attr()> | contents
 | <quote> | <leader()> | <target> | <string()> | <content()>
 | <counter> | <symbolic-glyph> ]+
<alt-text> = [ <string> | <counter> | <attr()> ]+
```

Values have the following meanings:

[normal]

: For a regular element or [page-margin
 box](https://drafts.csswg.org/css-page-3/#page-margin-boxes), this computes to
 [contents](#valdef-content-contents).

 For
 [::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) and
 [::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after), this computes to
 [none](#valdef-content-none).

 For
 [::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker),
 [::placeholder](https://drafts.csswg.org/css-pseudo-4/#selectordef-placeholder), and
 [::file-selector-button](https://drafts.csswg.org/css-pseudo-4/#selectordef-file-selector-button), this computes to itself
 ([normal](#valdef-content-normal)).

[none]

: On regular elements, this behaves as
 [normal](#valdef-content-normal).

 On
 [pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) it inhibits the creation of the pseudo-element as
 if it had [display:
 none](https://drafts.csswg.org/css-display-4/#propdef-display).

 In neither case does it prevent any pseudo-elements which have this
 element or pseudo-element as an [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element) from being generated.

[[\<content-replacement\>](#typedef-content-replacement)]

: Makes the element or
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) a [replaced
 element](https://drafts.csswg.org/css-display-4/#replaced-element), filled with the specified
 [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image). (In effect, it becomes
 equivalent to an HTML
 [`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element) element.) Its normal contents are suppressed
 and do not generate boxes, as if they were [display:
 none](https://drafts.csswg.org/css-display-4/#propdef-display).

 If the
 [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) represents an [invalid
 image](https://drafts.csswg.org/css-images-4/#invalid-image), the behavior is undefined.

 (#issue-470ff419) Possible ways of handling an invalid
 image include a) render it as an image with zero
 [natural](https://drafts.csswg.org/css-images-3/#natural-dimensions) width and height, filled with transparent black, b)
 render a broken image icon, c) render the alt text, if any, or the
 contents, if not. [\[Issue
 #218\]](https://github.com/w3c/csswg-drafts/issues/218)

 Replaced elements do not have
 [::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) or
 [::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after)
 [pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element); the
 [content](#propdef-content) property replaces their entire contents.

 (#issue-5248885e) This value has historically been
 treated as
 [\<content-list\>](#typedef-content-list) on
 [::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) and
 [::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after). There might be a Web-compat requirement on
 this, so these pseudo-elements might need an exception. It might be
 possible to limit this exception to cases without \"alt text\".
 [\[Issue #2889\]](https://github.com/w3c/csswg-drafts/issues/2889)

[[\<content-list\>](#typedef-content-list)]

: On regular elements, this value has no effect.

 On
 [pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) and [page-margin
 boxes](https://drafts.csswg.org/css-page-3/#page-margin-boxes), it replaces the box's contents with the specified
 content. (Its normal contents are suppressed, as if they were
 [display:
 none](https://drafts.csswg.org/css-display-4/#propdef-display).)

 Each value specified contributes an [inline-level
 box](https://drafts.csswg.org/css-display-4/#inline-level-box) to the element's contents, in the order specified.
 For
 [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image), this is an inline anonymous
 replaced element; for the others, it's an anonymous inline run of
 text.

 If the value of
 [\<content-list\>](#typedef-content-list) is a single
 [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image), it must instead be interpreted
 as a
 [\<content-replacement\>](#typedef-content-replacement).

 Tests

 - [pseudo-element-inline-box.html](https://wpt.fyi/results/css/css-content/pseudo-element-inline-box.html "css/css-content/pseudo-element-inline-box.html")
 [[(live
 test)]](http://wpt.live/css/css-content/pseudo-element-inline-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/pseudo-element-inline-box.html)

[[\<alt-text\>](#typedef-alt-text)]
: Specifies the "alternative content" for the element, which is
 supplied to the accessibility tree for rendering to speech, braille,
 etc. instead of the "visual content" provided before the slash. See
 [§ 1.2 Alternative Text for Accessibility](#alt) for details. If
 omitted, the element has no "alternative content"; the main content
 is used for all media.

To correctly use
[\<counter\>](https://drafts.csswg.org/css-lists-3/#typedef-counter) in \"alt text\" in unsupported
browsers one should specify
[content](#propdef-content) property twice. First, a fallback without counter
in \"alt text\". Second, use counter in \"alt text\".

``` highlight
::before {
 content: "Chapter" counter(chapter);
 content: "Chapter" counter(chapter) / "Chapter" counter(chapter);
}
```

Should the contents keyword be replaced
with [content()](#funcdef-content)?

### 1.1. Accessibility of Generated Content

Generated content should be searchable, selectable, and available to
assistive technologies. The
[content](#propdef-content) property applies to speech and generated content
must be rendered for speech output.
[\[CSS3-SPEECH\]](#biblio-css3-speech "CSS Speech Module Level 1")

Start work on an AAM for CSS.

### 1.2. Alternative Text for Accessibility

Content intended for visual media sometimes needs alternative text for
speech output or other non-visual mediums. The
[content](#propdef-content) property thus accepts alternative text to be
specified after a slash ([/]) after the last
[\<content-list\>](#typedef-content-list). If such alternative text is
provided, it must be used for speech output instead.

This allows, for example, purely decorative text to be elided in speech
output (by providing the empty string as alternative text), and allows
authors to provide more readable alternatives to images, icons, or
text-encoded symbols.

Here the content property is an image,
so the alt value is required to provide alternative text.

``` highlight
.new::before {
 content: url(./img/star.png) / "New!";
 /* or a localized attribute from the DOM: attr("data-alt") */
}
```

If the
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) is purely decorative and its function is covered
elsewhere, setting alt to the empty string can avoid reading out the
decorative element. Here the ARIA attribute will be spoken as
\"collapsed\". Without the empty string alt value, the content would
also be spoken as \"Black right-pointing pointer\".

``` highlight
.expandable::before {
 content: "\25BA" / "";
/* a.k.a. ► */
 /* aria-expanded="false" already in DOM,
 so this pseudo-element is decorative */
}
```

## [2. ][ Basic Strings and Images: [\<string\>](https://drafts.csswg.org/css-values-4/#string-value), [\<attr()\>](https://drafts.csswg.org/css-values-5/#funcdef-attr), [\<counter\>](https://drafts.csswg.org/css-lists-3/#typedef-counter), [\<symbolic-glyph\>](https://drafts.csswg.org/css-counter-styles-3/#typedef-symbolic-glyph), and [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) values]
[[\<string\>](https://drafts.csswg.org/css-values-4/#string-value)]

: Represents an anonymous inline box filled with the specified text.

 [White
 space](https://drafts.csswg.org/css-text-4/#white-space) in the string is handled the same as in literal
 text, and controlled by the properties in
 [\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3")
 and elsewhere. In particular, [white space]
 character can collapse, even across multiple strings, such as in
 [content: \"First \" \"
 Second\";](#propdef-content), which by default will render similar to
 `"First Second"` (with a single visible space between
 the two words).

[\<attr()\>](https://drafts.csswg.org/css-values-5/#funcdef-attr)

: The [attr()]
 functional notation represents the string stored as the specified
 attribute's value. Its argument is a [CSS qualified
 name](https://drafts.csswg.org/css-namespaces-3/#css-qualified-name) (`qname`) representing the attribute
 name and namespace, if any. See
 [\[CSS3-NAMESPACE\]](#biblio-css3-namespace "CSS Namespaces Module Level 3").

 As in [attribute
 selectors](https://drafts.csswg.org/selectors-4/#attrnmsp),
 attribute names without an explicit namespace do not associate with
 any default namespace.

[\<counter\>](https://drafts.csswg.org/css-lists-3/#typedef-counter)
: See [CSS Lists 3 § 4 Automatic Numbering With
 Counters](https://drafts.csswg.org/css-lists-3/#auto-numbering).

[\<symbolic-glyph\>](https://drafts.csswg.org/css-counter-styles-3/#typedef-symbolic-glyph)

: The [predefined symbolic counter
 style](https://drafts.csswg.org/css-counter-styles-3/#predefined-symbolic-counter-style), without its
 [prefix](https://drafts.csswg.org/css-counter-styles-3/#descdef-counter-style-prefix) or
 [suffix](https://drafts.csswg.org/css-counter-styles-3/#descdef-counter-style-suffix), as drawn by the UA for
 [list-style-type](https://drafts.csswg.org/css-lists-3/#propdef-list-style-type).

 :::
 (#example-5f2461d5) A disclosure widget can point its
 marker at the widget's state without involving a
 [counter](https://drafts.csswg.org/css-lists-3/#counter):
 ``` highlight
 summary::marker { content: disclosure-closed; }
 details[open] > summary::marker { content: disclosure-open; }
 ```
 :::

 Only the \"symbolic\" counter styles are allowed,
 as they're the only styles that don't depend on a counter value at
 all. Only the predefined ones are allowed, as an author-defined
 symbolic style can just be copied over as a string or image, while
 the predefined ones might be UA-specific images that can't be
 directly referenced.

[[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image)]

: Represents an anonymous inline replaced element filled with the
 specified
 [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image).

 If an
 [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) represents an [invalid
 image](https://drafts.csswg.org/css-images-4/#invalid-image), the user agent must (consistently) do one of the
 following:

 - "Skip" the
 [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image), generating nothing for it.

 - Display some indication that the image can't be displayed in place
 of the
 [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image), such as a "broken image" icon.

## 3. Elemental Content: the [contents keyword]
[contents]
: The element's descendants. Since this can only be used once per
 element (you can't duplicate the children if, e.g., one is a plugin
 or form control), it is handled as follows:

 If set on the element:

 : Always honoured. Note that this is the default, since the
 initial value of
 [content](#propdef-content) is
 [normal](#valdef-content-normal) and
 [normal] computes to
 [contents](#valdef-content-contents) on an element.

 If set on one of the element's other [pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element):

 : Check to see that it is not set on a \"previous\"
 pseudo-element, in the following order, depth first:

 1. the element itself

 2. ::before

 3. ::after

 (#issue-bf2f178e) Should this behave as an empty
 string on pseudo-elements?

 If it is already used, then it evaluates to nothing (like
 [none](#valdef-content-none)). Only pseudo-elements that are actually
 generated are checked.

In the following case:

``` highlight
foo { content: normal; } /* this is the initial value */
foo::after { content: contents; }
```

\...the element's [content](#propdef-content) property would compute to
[contents](#valdef-content-contents) and the
[::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) would have no contents (equivalent to
[none](#valdef-content-none)) and thus would not appear.

``` highlight
foo { content: none; }
foo::after { content: contents; }
```

But in this example, the ::after pseudo-element will contain the
contents of the foo element.

Use cases for suppressing the content on
the element and using it in a pseudo-element would be welcome.

 While it is useless to include
[contents](#valdef-content-contents) twice in a single
[content](#propdef-content) property, that is not a parse error. The second
occurrence simply has no effect, as it has already been used. It is also
not a parse error to use it on a
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-element, it is only during the rendering
stage that it gets treated like
[none](#valdef-content-none).

Do we need the statement about marker
pseudo-elements here? Or is this legacy from the old version of the
spec?

## 4. Quotation Marks

The [quotes] property, which defines the [quotation mark
system](#quotation-mark-system) of an element, in conjunction with the various
[\*-quote] values of the
[content](#propdef-content) property, which insert corresponding quotation
marks as generated content, can be used to automatically insert opening
and closing quotation marks, such as for the HTML
[`q`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-q-element) element.

### 4.1. Quotation Mark System: the [quotes property]
Name:

[quotes]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) none [\|] bikeshed-this
[\|] \[
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value) [\<string\>]
\][+](https://drafts.csswg.org/css-values-4/#mult-one-plus)

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

the keyword [none](#valdef-quotes-none), the keyword
[auto](#valdef-quotes-auto), a [content
language](https://drafts.csswg.org/css-text-4/#content-language), or a list, each item a pair of string values

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Tests

- [quotes-001.html](https://wpt.fyi/results/css/css-content/quotes-001.html "css/css-content/quotes-001.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-001.html)
- [quotes-002.html](https://wpt.fyi/results/css/css-content/quotes-002.html "css/css-content/quotes-002.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-002.html)
- [quotes-003.html](https://wpt.fyi/results/css/css-content/quotes-003.html "css/css-content/quotes-003.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-003.html)
- [quotes-004.html](https://wpt.fyi/results/css/css-content/quotes-004.html "css/css-content/quotes-004.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-004.html)
- [quotes-005.html](https://wpt.fyi/results/css/css-content/quotes-005.html "css/css-content/quotes-005.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-005.html)
- [quotes-006.html](https://wpt.fyi/results/css/css-content/quotes-006.html "css/css-content/quotes-006.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-006.html)
- [quotes-007.html](https://wpt.fyi/results/css/css-content/quotes-007.html "css/css-content/quotes-007.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-007.html)
- [quotes-008.html](https://wpt.fyi/results/css/css-content/quotes-008.html "css/css-content/quotes-008.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-008.html)
- [quotes-009.html](https://wpt.fyi/results/css/css-content/quotes-009.html "css/css-content/quotes-009.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-009.html)
- [quotes-010.html](https://wpt.fyi/results/css/css-content/quotes-010.html "css/css-content/quotes-010.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-010.html)
- [quotes-011.html](https://wpt.fyi/results/css/css-content/quotes-011.html "css/css-content/quotes-011.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-011.html)
- [quotes-012.html](https://wpt.fyi/results/css/css-content/quotes-012.html "css/css-content/quotes-012.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-012.html)
- [quotes-013.html](https://wpt.fyi/results/css/css-content/quotes-013.html "css/css-content/quotes-013.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-013.html)
- [quotes-014.html](https://wpt.fyi/results/css/css-content/quotes-014.html "css/css-content/quotes-014.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-014.html)
- [quotes-015.html](https://wpt.fyi/results/css/css-content/quotes-015.html "css/css-content/quotes-015.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-015.html)
- [quotes-016.html](https://wpt.fyi/results/css/css-content/quotes-016.html "css/css-content/quotes-016.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-016.html)
- [quotes-017.html](https://wpt.fyi/results/css/css-content/quotes-017.html "css/css-content/quotes-017.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-017.html)
- [quotes-018.html](https://wpt.fyi/results/css/css-content/quotes-018.html "css/css-content/quotes-018.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-018.html)
- [quotes-019.html](https://wpt.fyi/results/css/css-content/quotes-019.html "css/css-content/quotes-019.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-019.html)
- [quotes-020.html](https://wpt.fyi/results/css/css-content/quotes-020.html "css/css-content/quotes-020.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-020.html)
- [quotes-021.html](https://wpt.fyi/results/css/css-content/quotes-021.html "css/css-content/quotes-021.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-021.html)
- [quotes-022.html](https://wpt.fyi/results/css/css-content/quotes-022.html "css/css-content/quotes-022.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-022.html)
- [quotes-023.html](https://wpt.fyi/results/css/css-content/quotes-023.html "css/css-content/quotes-023.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-023.html)
- [quotes-024.html](https://wpt.fyi/results/css/css-content/quotes-024.html "css/css-content/quotes-024.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-024.html)
- [quotes-025.html](https://wpt.fyi/results/css/css-content/quotes-025.html "css/css-content/quotes-025.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-025.html)
- [quotes-026.html](https://wpt.fyi/results/css/css-content/quotes-026.html "css/css-content/quotes-026.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-026.html)
- [quotes-027.html](https://wpt.fyi/results/css/css-content/quotes-027.html "css/css-content/quotes-027.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-027.html)
- [quotes-028.html](https://wpt.fyi/results/css/css-content/quotes-028.html "css/css-content/quotes-028.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-028.html)
- [quotes-029.html](https://wpt.fyi/results/css/css-content/quotes-029.html "css/css-content/quotes-029.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-029.html)
- [quotes-030.html](https://wpt.fyi/results/css/css-content/quotes-030.html "css/css-content/quotes-030.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-030.html)
- [quotes-031.html](https://wpt.fyi/results/css/css-content/quotes-031.html "css/css-content/quotes-031.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-031.html)
- [quotes-032.html](https://wpt.fyi/results/css/css-content/quotes-032.html "css/css-content/quotes-032.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-032.html)
- [quotes-033.html](https://wpt.fyi/results/css/css-content/quotes-033.html "css/css-content/quotes-033.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-033.html)
- [quotes-034.html](https://wpt.fyi/results/css/css-content/quotes-034.html "css/css-content/quotes-034.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-034.html)
- [quotes-035.html](https://wpt.fyi/results/css/css-content/quotes-035.html "css/css-content/quotes-035.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-035.html)
- [quotes-first-letter-001.html](https://wpt.fyi/results/css/css-content/quotes-first-letter-001.html "css/css-content/quotes-first-letter-001.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-first-letter-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-first-letter-001.html)
- [quotes-first-letter-002.html](https://wpt.fyi/results/css/css-content/quotes-first-letter-002.html "css/css-content/quotes-first-letter-002.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-first-letter-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-first-letter-002.html)
- [quotes-first-letter-003.html](https://wpt.fyi/results/css/css-content/quotes-first-letter-003.html "css/css-content/quotes-first-letter-003.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-first-letter-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-first-letter-003.html)
- [quotes-first-letter-004.html](https://wpt.fyi/results/css/css-content/quotes-first-letter-004.html "css/css-content/quotes-first-letter-004.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-first-letter-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-first-letter-004.html)
- [quotes-first-letter-005.html](https://wpt.fyi/results/css/css-content/quotes-first-letter-005.html "css/css-content/quotes-first-letter-005.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-first-letter-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-first-letter-005.html)
- [quotes-first-line.html](https://wpt.fyi/results/css/css-content/quotes-first-line.html "css/css-content/quotes-first-line.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-first-line.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-first-line.html)
- [quotes-lang-dynamic-001.html](https://wpt.fyi/results/css/css-content/quotes-lang-dynamic-001.html "css/css-content/quotes-lang-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-lang-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-lang-dynamic-001.html)

*User agents are expected to support this property on all media,
including non-visual ones.*

This property specifies the [quotation mark
system] for the element, defining how the
[content](#propdef-content) property's
[open-quote](#valdef-content-open-quote) and
[close-quote](#valdef-content-close-quote) values behave. See [§ 4.2 Inserting Quotation
Marks: the \*-quote keywords](#quote-values). Values have the following
meanings:

[none]
: The
 [open-quote](#valdef-content-open-quote) and
 [close-quote](#valdef-content-close-quote) values of the
 [content](#propdef-content) property produce no quotations
 marks, as if they were
 [no-open-quote](#valdef-content-no-open-quote) and
 [no-close-quote](#valdef-content-no-close-quote) respectively.

[auto]

: A typographically appropriate [quotation mark
 system](#quotation-mark-system) is automatically chosen by the UA based on the
 [content
 language](https://drafts.csswg.org/css-text-4/#content-language) of the parent (or, if there is no parent, of the
 element itself). Computes to itself (the keyword
 [auto](#valdef-quotes-auto)).

 The Unicode Common Locale Data Repository
 [\[CLDR\]](#biblio-cldr "Unicode Common Locale Data Repository")
 maintains information on typographically appropriate quotation
 marks. UAs can use other sources of information as well,
 particularly as typographic preferences can vary; however it is
 encouraged to submit any improvements to Unicode so that the entire
 software ecosystem can benefit.

[bikeshed-this]

: If the [inherited
 value](https://drafts.csswg.org/css-cascade-5/#inherited-value) is
 [auto](#valdef-quotes-auto), computes to the [content
 language](https://drafts.csswg.org/css-text-4/#content-language) of the parent, which behaves like
 [auto] as resolved by that
 [content language]. Otherwise, computes
 to the [inherited value].

 A [content
 language](https://drafts.csswg.org/css-text-4/#content-language) [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) serializes as
 [bikeshed-this](#valdef-quotes-bikeshed-this).

 (#issue-7c41b9f7) This needs a name. Maybe
 [match-parent]? [\[Issue
 #5478\]](https://github.com/w3c/csswg-drafts/issues/5478)

\[ [\<string\>](https://drafts.csswg.org/css-values-4/#string-value) [\<string\>] \]+
: The [quotation mark
 system](#quotation-mark-system) is defined as the specified list of pairs of
 quotation marks (opening and closing). The first pair represents the
 outermost level of quotation, the second pair the next level of
 embedding, etc. Within a pair, the
 [open-quote](#valdef-content-open-quote) value refers to the first
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value),
 [close-quote](#valdef-content-close-quote) refers to the second.

### [4.2. ][ Inserting Quotation Marks: the [\*-quote] keywords]
```
<quote> = open-quote | close-quote | no-open-quote | no-close-quote
```

Tests

- [quotes-slot-scoping.html](https://wpt.fyi/results/css/css-content/quotes-slot-scoping.html "css/css-content/quotes-slot-scoping.html")
 [[(live
 test)]](http://wpt.live/css/css-content/quotes-slot-scoping.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-content/quotes-slot-scoping.html)

[open-quote]\
[close-quote]
: These values are replaced by the appropriate string as defined by
 the [quotes](#propdef-quotes) property, and increments (for
 [open-quote](#valdef-content-open-quote)) or decrements (for
 [close-quote](#valdef-content-close-quote)) the level of nesting for quotes.

[no-open-quote]\
[no-close-quote]
: Inserts nothing (as in
 [none](#valdef-content-none)), but increments (for
 [no-open-quote](#valdef-content-no-open-quote)) or decrements (for
 [no-close-quote](#valdef-content-no-close-quote)) the level of nesting for quotes.

Quotation marks can be inserted in appropriate places in a document with
the
[open-quote](#valdef-content-open-quote) and
[close-quote](#valdef-content-close-quote) values of the
[content](#propdef-content) property. Each occurrence of
[open-quote] or
[close-quote] is replaced by
a quotation mark string as defined by the [quotation mark
system](#quotation-mark-system) specified by the
[quotes](#propdef-quotes) property, based on the [depth of
nesting](#quote-depth).

Which pair of quotes is used depends on the nesting level of quotes (the
[quote depth]): the number of occurrences of
[open-quote](#valdef-content-open-quote) in all generated text before the current
occurrence, minus the number of occurrences of
[close-quote](#valdef-content-close-quote) in all generated text before and including the
current occurence. If the depth is 0, the first pair is used, if the
depth is 1, the second pair is used, etc. If the depth is greater than
the number of pairs, the last pair is repeated.

 [Quote depth](#quote-depth) is independent of the nesting of the source document or
the formatting structure. Also, like [counter
inheritance](https://drafts.csswg.org/css-lists-3/#inheriting-counters),
it operates on the "flattened element tree" in the context of the
[\[DOM\]](#biblio-dom "DOM Standard").

A
[close-quote](#valdef-content-close-quote) or
[no-close-quote](#valdef-content-no-close-quote) that would make the [quote
depth](#quote-depth) negative is
in error and is ignored (at rendering time): the depth stays at 0 and no
quote mark is inserted (although the rest of the
[content](#propdef-content) property's value is still inserted).

Some typographic styles require open
quotation marks to be repeated before every paragraph of a quote
spanning several paragraphs, but only the last paragraph ends with a
closing quotation mark. In CSS, this can be achieved by inserting
\"phantom\" closing quotes. The keyword
[no-close-quote](#valdef-content-no-close-quote) decrements the quoting level, but does not
insert a quotation mark.

The following style sheet puts opening quotation marks on every
paragraph in a `blockquote`, and inserts a single closing
quote at the end:

``` highlight
blockquote p::before { content: open-quote }
blockquote p::after { content: no-close-quote }
blockquote p:last-child::after { content: close-quote }
```

For symmetry, there is also a
[no-open-quote](#valdef-content-no-open-quote) keyword, which inserts nothing, but increments
the quotation depth by one.

 If a quotation is in a different language than the
surrounding text, it is customary to quote the text with the quote marks
of the language of the surrounding text, not the language of the
quotation itself.

For example, French inside English:

> The device of the order of the garter is "Honi soit qui mal y pense."

English inside French:

> Il disait: « Il faut mettre l'action en ‹ fast forward ›. »

A style sheet like the following will set the
[quotes](#propdef-quotes) property so that
[open-quote](#valdef-content-open-quote) and
[close-quote](#valdef-content-close-quote) will work correctly on all elements. These rules
are for documents that contain only English, French, or both. One rule
is needed for every additional language. Note the use of the child
combinator (\"\>\") to set quotes on elements based on the language of
the surrounding text:

``` highlight
:lang(fr) > * { quotes: "\00AB\2005" "\2005\00BB" "\2039\2005" "\2005\203A" }
:lang(en) > * { quotes: "\201C" "\201D" "\2018" "\2019" }
```

The quotation marks are shown here in a form that most people will be
able to type. If you can type them directly, they will look like this:

``` highlight
:lang(fr) > * { quotes: "« " " »" "‹ " " ›" }
:lang(en) > * { quotes: "“" "”" "‘" "’" }
```

For example, applying the following
style sheet:

``` highlight
/* Specify pairs of quotes for two levels in two languages */
:lang(en) > q { quotes: '"' '"' "'" "'" }
:lang(no) > q { quotes: "«" "»" "’" "’" }

/* Insert quotes before and after Q element content */
q::before { content: open-quote }
q::after { content: close-quote }
```

to the following HTML fragment:

```
<html lang="en">
 <head>
 <title>Quotes</title>
 </head>
 <body>
 <p><q>Quote me!</q></p>
 </body>
</html>
```

would allow a user agent to produce:

``` highlight
"Quote me!"
```

while this HTML fragment:

```
<html lang="no">
 <head>
 <title>Quotes</title>
 </head>
 <body>
 <p><q>Trøndere gråter når <q>Vinsjan på kaia</q> blir deklamert.</q></p>
 </body>
</html>
```

would produce:

``` highlight
«Trøndere gråter når ’Vinsjan på kaia’ blir deklamert.»
```

## 5. Leaders

A leader, sometimes known as a tab leader or a dot leader, is a
repeating pattern used to visually connect content across horizontal
spaces. They are most commonly used in tables of contents, between
titles and page numbers. The
[leader()](#funcdef-leader) function, as a value for the content property, is
used to create leaders in CSS. This function takes a string (the leader
string), which describes the repeating pattern for the leader.

### 5.1. The [leader() function]
[leader( [\<leader-type\>](#typedef-leader-type) )]
: Inserts a leader. See the section on [leaders](#leaders) for more
 information.

```
leader() = leader( <leader-type> )
<leader-type> = dotted | solid | space | <string>
```

Three keywords are shorthand values for common strings:

[dotted]
: Equivalent to [leader(\".\")]

[solid]
: Equivalent to [leader(\"\_\")]

[space]
: Equivalent to [leader(\" \")]

[[\<string\>](https://drafts.csswg.org/css-values-4/#string-value)]
: Issue: Define this.

``` highlight
ol.toc a::after {
 content: leader('.') target-counter(attr(href), page);
}

<h1>Table of Contents</h1>
<ol class="toc">
<li><a href="#chapter1">Loomings</a></li>
<li><a href="#chapter2">The Carpet-Bag</a></li>
<li><a href="#chapter3">The Spouter-Inn</a></li>
</ol>
```

This might result in:

``` highlight
Table of Contents

1. Loomings.....................1
2. The Carpet-Bag...............9
3. The Spouter-Inn.............13
```

Do leaders depend on the assumption that
the content after the leader is right-aligned (end-aligned)?

### 5.2. Rendering leaders

Consider a line which contains the content before the leader (the
"before content"), the leader, and the content after the leader (the
"after content"). Leaders obey the following rules:

1. The leader string must appear in full at least once.

2. The leader should be as long as possible

3. Visible characters in leaders should vertically align with each
 other when possible.

4. Line break characters in the leader string must be ignored.

5. White space in the leader string follows normal CSS rules.

6. A leader only appears between the start content and the end content.

7. A leader only appears on a single line, even if the before content
 and after content are on different lines.

8. A leader can't be the only thing on a line.

### 5.3. Procedure for rendering leaders

1. Lay out the `before content`, until reaching the line
 where the `before content` ends.

 ``` highlight
 BBBBBBBBBB
 BBB
 ```

2. The leader string consists of one or more glyphs, and is thus an
 inline box. A leader is a row of these boxes, drawn from the end
 edge to the start edge, where only those boxes not overlaid by the
 before or after content. On this line, draw the leader string,
 starting from the end edge, repeating as many times as possible
 until reaching the start edge.

 ``` highlight
 BBBBBBBBBB
 ..........
 ```

3. Draw the before and after content on top of the leader. If any part
 of the `before content` or `after content`
 overlaps a glyph in a leader string box, that glyph is not
 displayed.

 ``` highlight
 BBBBBBBBBB
 BBB....AAA
 ```

4. If one full copy of the leader string is not visible:

 ``` highlight
 BBBBBBB
 BBBBBBA
 ```

 Insert a line break after the `before content`, draw the
 leader on the next line, and draw the `after content` on
 top, and hide any leader strings that are not fully displayed.

 ``` highlight
 BBBBBBB
 BBBBBB
 ......A
 ```

what to do if `after content`
is wider than the line box?

Leaders don't quite work in table
layouts. How can we fix this?

![Procedure for drawing
leaders](images/leader.001.jpg){a width="480"}

![Procedure for drawing leaders when the content doesn't fit on a single
line](images/leader.002.jpg){a width="480"}

## 6. Cross References

Many documents contain internal references:

- See chapter 7

- in section 4.1

- on page 23

Three new values for the content property are used to automatically
create these types of cross-references:
[target-counter()](#funcdef-target-counter),
[target-counters()](#funcdef-target-counters), and
[target-text()](#target-text-function). Each of these displays information obtained
from the target end of a link.

```
<target> = <target-counter()> | <target-counters()> | <target-text()>
```

See sections below for details on each of these.

### 6.1. The [target-counter() function]
```
target-counter() = target-counter( [ <string> | <url> ] , <custom-ident> , <counter-style>? )
```

The
[target-counter()](#funcdef-target-counter) function retrieves the value of the innermost
counter with a given name. The required arguments are the url of the
target and the name of the counter. An optional counter-style argument
can be used to format the result.

These functions only take a fragment URL which points to a location in
the current document. If there's no fragment, if the ID referenced isn't
there, or if the URL points to an outside document, the user agent must
treat that as an error.

what should error handling be?

restrict syntactically to local
references for now.

HTML:

``` highlight
…which will be discussed on page <a href="#chapter4_sec2"></a>.
```

CSS:

``` highlight
a::after { content: target-counter(attr(href url), page) }
```

Result:

``` highlight
…which will be discussed on page 137.
```

Page numbers in tables of contents can
be generated automatically:

HTML:

``` highlight
<nav>
 <ol>
 <li class="frontmatter"><a href="#pref_01">Preface</a></li>
 <li class="frontmatter"><a href="#intr_01">Introduction</a></li>
 <li class="bodymatter"><a href="#chap_01">Chapter One</a></li>
 </ol>
</nav>
```

CSS:

``` highlight
.frontmatter a::after { content: leader('.') target-counter(attr(href url), page, lower-roman) }
.bodymatter a::after { content: leader('.') target-counter(attr(href url), page, decimal) }
```

Result:

``` highlight
Preface.............vii
Introduction.........xi
Chapter One...........1
```

### 6.2. The [target-counters() function]
This functions fetches the value of all counters of a given name from
the end of a link, and formats them by inserting a given string between
the value of each nested counter.

```
target-counters() = target-counters( [ <string> | <url> ] , <custom-ident> , <string> , <counter-style>? )
```

``` highlight
I have not found a compelling example for target-counters() yet.
```

found a compelling example, in CSS
specs. Do something.

### 6.3. The [target-text() function]
The
[target-text()](#target-text-function) function retrieves the text value of the element
referred to by the URL. An optional second argument specifies what
content is retrieved, using the same values as the
[string-set](#propdef-string-set) property above.

```
target-text() = target-text( [ <string> | <url> ] , [ content | before | after | first-letter ]? )
```

A simpler syntax has been proposed by
fantasai:
<http://lists.w3.org/Archives/Public/www-style/2012Feb/0745.html>

``` highlight
…which will be discussed <a href="#chapter_h1_1">later</a>.

a::after { content: ", in the chapter entitled " target-text(attr(href url)) }
```

Result: ...which will be discussed later, in the chapter entitled
Loomings.

## 7. Named Strings

This section introduces [named strings], which are the textual
equivalent of counters and which have a distinct namespace from
counters. Named strings follow the same nesting rules as counters. The
[string-set](#propdef-string-set) property accepts values similar to the
[content](#propdef-content) property, including the extraction of the current
value of counters.

Named strings are a convenient way to pull metadata out of the document
for insertion into headers and footers. In HTML, for example, META
elements contained in the document HEAD can set the value of named
strings. In conjunction with attribute selectors, this can be a powerful
mechanism:

``` highlight
meta[author] { string-set: author attr(author); }
head > title { string-set: title contents; }
@page:left {
 @top {
 text-align: left;
 vertical-align: middle;
 content: string(title);
 }
}
@page:right {
 @top {
 text-align: right;
 vertical-align: middle;
 content: string(author);
 }
}
```

### 7.1. Naming Strings: the [string-set property]
Name:

[string-set]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value)
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value)[+](https://drafts.csswg.org/css-values-4/#mult-one-plus)
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements, but not
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[none](#valdef-string-set-none) or a list, each item an identifier paired with a list
of string values

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

*User agents are expected to support this property on all media,
including non-visual ones.*

The [string-set](#propdef-string-set) property copies the text content of an
element into a [named string], which functions as a variable. The
text content of this named string can be retrieved using the
[string()](#funcdef-string) function. Since these variables may change on a given
page, an optional second value for the
[string()] function allows authors to
choose which value on a page is used.

[none]
: The element does not set any named strings.

`[ `[`<custom-ident>`](https://drafts.csswg.org/css-values-4/#identifier-value)` `[`<string>`](https://drafts.csswg.org/css-values-4/#string-value)`+ ]#`

: The element establishes one or more named strings, corresponding to
 each comma-separated entry in the list.

 For each entry, the
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) gives the name of the named
 string. It's followed by one or more
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value) values, which are concatenated
 together to form the value of the named string.

If an element has [style
containment](https://drafts.csswg.org/css-contain-2/#style-containment), the
[string-set](#propdef-string-set) property must have no effects on
descendants of that element.

The following example captures the
contents of H1 elements, which represent chapter names in this
hypothetical document.

``` highlight
H1 { string-set: chapter contents; }
```

When an H1 element is encountered, the [chapter] string is set to
the element's textual contents, and the previous value of
[chapter], if any, is overwritten.

### 7.2. Inserting Named Strings: the [string() function]
```
string() = string( <custom-ident> , [ first | start | last | first-except ]? )
```

The [string()](#funcdef-string) function is used to copy the value of a named string
to the document, via the
[content](#propdef-content) property. This function requires one argument, the
name of the named string. Since the value of a named string may change
several times on a page (as multiple elements defining the string can
appear) an optional second argument indicates which value of the named
string should be used.

The second argument of the
[string()](#funcdef-string) function is one of the following keywords:

[first]
: The value of the first assignment on the page is used. If there is
 no assignment on the page, the [entry
 value](#entry-value) is used.
 If no second argument is provided, this is the default value.

[start]
: If the element is the first element on the page, the value of the
 first assignment is used. Otherwise the [entry
 value](#entry-value) is used.
 The [entry value] may be empty if the [named
 string](#named-string) hasn't
 yet appeared.

[last]
: The [exit value](#exit-value)
 of the named string is used.

[first-except]

: This is identical to
 [first](#valdef-string-first), except that the empty string is used on the page
 where the value is assigned.

 (#issue-c24bc3d7) we may need to kill the entire
 content string. Is this necessary?

The content values of named strings are assigned at the point when the
content box of the element is first created (or would have been created
if the element's display value is none). The [entry value] for a page is the
assignment in effect at the end of the previous page. The [exit
value] for a
page is the assignment in effect at the end of the current page.

CSS:

``` highlight
@page {
 size: 15cm 10cm;
 margin: 1.5cm;

 @top-left {
 content: "first: " string(heading, first);
 }
 @top-center {
 content: "start: " string(heading, start);
 }
 @top-right {
 content: "last: " string(heading, last);
 }
 }

h2 { string-set: heading content() }
```

The following figures show the first, start, and last assignments of the
"heading" string on various pages.

![The [start] value is empty, as the string had not yet been set
at the start of the page.](images/using-strings-1.jpg){width="480"}

![Since the page starts with an h2, the [start] value is the value
of that head.](images/using-strings-2.jpg){width="480"}

![Since there's not an h2 at the top of this page, the [start]
value is the [exit value](#exit-value) of the previous
page.](images/using-strings-3.jpg){width="480"}

### 7.3. The [content() function]
```
content() = content( [ text | before | after | first-letter | marker ]? )
```

[text]
: The string value of the element. If no value is specified in
 [content()](#funcdef-content), it acts as if
 [text](#valdef-content-text) were specified.

[before]
: The string value of the
 [::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element).

[after]
: The string value of the
 [::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element).

[first-letter]
: The first letter of the element, as defined for the
 [::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element)

[marker]
: The string value of the
 [::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element).

HTML:

``` highlight
<h1>Loomings</h1>
```

CSS:

``` highlight
h1::before { content: 'Chapter ' counter(chapter); }
h1 { string-set: header content(before) ':' content(text); }
h1::after { content: '.'; }
```

The value of the named string "header" will be "Chapter 1: Loomings".

HTML:

``` highlight
<section title="Loomings">
```

CSS:

``` highlight
section { string-set: header attr(title) }
```

The value of the "header" string will be "Loomings".

## 8. Bookmarks

Some document formats, most notably PDF, allow the use of
[bookmarks] as an
aid to navigation. Bookmarks provide a list of links to document
elements, as well as text to label the links and a level value. A
bookmark has three properties:
[bookmark-level](#propdef-bookmark-level),
[bookmark-label](#propdef-bookmark-label), and
[bookmark-state](#propdef-bookmark-state).

When a user activates a bookmark, the user agent must bring that
reference point to the user's attention, exactly as if navigating to
that element by fragment URL. [This will also trigger matching the
[:target](https://drafts.csswg.org/selectors-4/#target-pseudo) pseudo-class.]

If an element has [style
containment](https://drafts.csswg.org/css-contain-2/#style-containment), the
[bookmark-level](#propdef-bookmark-level),
[bookmark-label](#propdef-bookmark-label), and
[bookmark-state](#propdef-bookmark-state) properties must have no effect on
descendants of the element.

### 8.1. Setting a Bookmark: the [bookmark-level property ]
The
[bookmark-level](#propdef-bookmark-level) property determines if a bookmark
is created, and at what level. If this property is absent, or has value
[none](#valdef-bookmark-level-none), no bookmark should be generated, regardless of
the values of
[bookmark-label](#propdef-bookmark-label) or
[bookmark-state](#propdef-bookmark-state).

Name:

[bookmark-level]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<integer
\[1,∞\]\>](https://drafts.csswg.org/css-values-4/#integer-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[none](#valdef-bookmark-level-none) or the specified integer

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[[\<integer \[1,∞\]\>](https://drafts.csswg.org/css-values-4/#integer-value)]
: defines the level of the bookmark, with the top level being 1
 (negative and zero values are invalid).

[none]
: no bookmark is generated.

``` highlight
section h1 { bookmark-level: 1; }
section section h1 { bookmark-level: 2; }
section section section h1 { bookmark-level: 3; }
```

 Bookmarks do not need to create a strict hierarchy of
levels.

Should a bookmark be created for
elements with `display: none`?

### 8.2. Labelling a Bookmark: the [bookmark-label property]
Name:

[bookmark-label]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<content-list\>](#typedef-content-list)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

content(text)

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

[[\<content-list\>](#typedef-content-list)]
: [\<content-list\>](#typedef-content-list) is defined above, in the section
 on the
 [string-set](#propdef-string-set) property. The value of
 [\<content-list\>]
 becomes the text content of the bookmark label.

HTML:

``` highlight
<h1>Loomings</h1>
```

CSS:

``` highlight
h1 {
bookmark-label: content(text);
bookmark-level: 1;
}
```

The bookmark label will be "Loomings".

### 8.3. Initial Bookmark Toggle State: the [bookmark-state property]
The
[bookmark-state](#propdef-bookmark-state) may be open or closed. The user
must be able to toggle the bookmark state.

Name:

[bookmark-state]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

open
[\|](https://drafts.csswg.org/css-values-4/#comb-one) closed

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

open

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

block-level elements

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

[open]
: Subsequent bookmarks with
 [bookmark-level](#propdef-bookmark-level) greater than the given bookmark
 are displayed, until reaching another bookmark of the same level or
 lower. If one of subsequent bookmark is closed, apply the same test
 to determine if its subsequent bookmarks should be displayed.

[closed]
: Subsequent bookmarks of bookmark-level greater than the given
 bookmark are not displayed, until reaching another bookmark of the
 same level or lower.

Is the initial bookmark state, or the
bookmark state updated by the UA as appropriate?

## 9. Changes

Significant changes since the [4 December 2025 Working
Draft](https://www.w3.org/TR/2025/WD-css-content-3-20251204/) include:

- Replacing the [match-parent] value of
 [quotes](#propdef-quotes) with [bikeshed-this]. ([Issue
 5478](https://github.com/w3c/csswg-drafts/issues/5478))

Significant changes since the [2 August 2019 Working
Draft](https://www.w3.org/TR/2019/WD-css-content-3-20190802/) consist
primarily of:

- Updated [auto](#valdef-quotes-auto) to reference the *parent* [content
 language](https://drafts.csswg.org/css-text-4/#content-language) rather than the [content
 language] of the element itself. ([Issue
 5478](https://github.com/w3c/csswg-drafts/issues/5478))
- Added
 [match-parent](https://www.w3.org/TR/css-content-3/#valdef-quotes-match-parent) value to
 [quotes](#propdef-quotes). ([Issue
 5478](https://github.com/w3c/csswg-drafts/issues/5478))
- Prevent negative [quote depth](#quote-depth) by ignoring excess closing quotes, consistent with
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").
 ([Issue 2034](https://github.com/w3c/csswg-drafts/issues/2038))
- Defined computed value of [content:
 normal](#propdef-content) for
 [::placeholder](https://drafts.csswg.org/css-pseudo-4/#selectordef-placeholder) and
 [::file-selector-button](https://drafts.csswg.org/css-pseudo-4/#selectordef-file-selector-button). ([Issue
 6124](https://github.com/w3c/csswg-drafts/issues/6124))
- Fixed an off-by-one error for the [quote
 depth](#quote-depth) of closing
 quotes. ([Issue
 2506](https://github.com/w3c/csswg-drafts/issues/2506))
- Inlined the definition of
 [attr()](#valdef-content-attr), since it has been dropped from
 [\[CSS-VALUES-4\]](#biblio-css-values-4 "CSS Values and Units Module Level 4").
- Added Web Platform Tests coverage.
- Allowed the predefined symbolic counter style keywords
 ([disc](https://drafts.csswg.org/css-counter-styles-3/#disc),
 [circle](https://drafts.csswg.org/css-counter-styles-3/#circle),
 [square](https://drafts.csswg.org/css-counter-styles-3/#square),
 [disclosure-open](https://drafts.csswg.org/css-counter-styles-3/#disclosure-open),
 [disclosure-closed](https://drafts.csswg.org/css-counter-styles-3/#disclosure-closed)) directly in
 [\<content-list\>](#typedef-content-list). ([Issue
 14003](https://github.com/w3c/csswg-drafts/issues/14003))
- Miscellaneous editorial spec clean up.

See also [previous
changes](https://www.w3.org/TR/2019/WD-css-content-3-20190802/#changes).

## [Acknowledgements]
Stuart Ballard, David Baron, Bert Bos, [Tantek Çelik]{lang="tr"}, and
James Craig provided invaluable suggestions used in this specification.

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.
