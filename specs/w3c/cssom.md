## 1. Introduction

This document formally specifies the core features of the CSS Object
Model (CSSOM). Other documents in the CSSOM family of specifications as
well as other CSS related specifications define extensions to these core
features.

The core features of the CSSOM are oriented towards providing basic
capabilities to author-defined scripts to permit access to and
manipulation of style related state information and processes.

The features defined below are fundamentally based on prior
specifications of the W3C DOM Working Group, primarily
[\[DOM\]](#biblio-dom "DOM Standard"). The purposes
of the present document are (1) to improve on that prior work by
providing more technical specificity (so as to improve testability and
interoperability), (2) to deprecate or remove certain less-widely
implemented features no longer considered to be essential in this
context, and (3) to newly specify certain extensions that have been or
expected to be widely implemented.

Tests

Basic CSSOM tests

- [idlharness.html](https://wpt.fyi/results/css/cssom/idlharness.html "css/cssom/idlharness.html")
 [[(live
 test)]](http://wpt.live/css/cssom/idlharness.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/idlharness.html)
- [invalid-pseudo-elements.html](https://wpt.fyi/results/css/cssom/invalid-pseudo-elements.html "css/cssom/invalid-pseudo-elements.html")
 [[(live
 test)]](http://wpt.live/css/cssom/invalid-pseudo-elements.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/invalid-pseudo-elements.html)
- [historical.html](https://wpt.fyi/results/css/cssom/historical.html "css/cssom/historical.html")
 [[(live
 test)]](http://wpt.live/css/cssom/historical.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/historical.html)
- [stylesheet-replacedata-dynamic.html](https://wpt.fyi/results/css/cssom/stylesheet-replacedata-dynamic.html "css/cssom/stylesheet-replacedata-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/cssom/stylesheet-replacedata-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/stylesheet-replacedata-dynamic.html)
- [xml-stylesheet-pi-in-doctype.xhtml](https://wpt.fyi/results/css/cssom/xml-stylesheet-pi-in-doctype.xhtml "css/cssom/xml-stylesheet-pi-in-doctype.xhtml")
 [[(live
 test)]](http://wpt.live/css/cssom/xml-stylesheet-pi-in-doctype.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/xml-stylesheet-pi-in-doctype.xhtml)

------------------------------------------------------------------------

## 2. Terminology

This specification employs certain terminology from the following
documents: DOM, HTML, CSS Syntax, Encoding, URL, Fetch, Associating
Style Sheets with XML documents and XML.
[\[DOM\]](#biblio-dom "DOM Standard")
[\[HTML\]](#biblio-html "HTML Standard")
[\[CSS3SYN\]](#biblio-css3syn "CSS Syntax Module Level 3")
[\[ENCODING\]](#biblio-encoding "Encoding Standard")
[\[URL\]](#biblio-url "URL Standard")
[\[FETCH\]](#biblio-fetch "Fetch Standard")
[\[XML-STYLESHEET\]](#biblio-xml-stylesheet "Associating Style Sheets with XML documents 1.0 (Second Edition)")
[\[XML\]](#biblio-xml "Extensible Markup Language (XML) 1.0 (Fifth Edition)")

When this specification talks about object `A` where
`A` is actually an interface, it generally means an object
implementing interface `A`.

The terms [set] and
[unset] to refer to
the true and false values of binary flags or variables, respectively.
These terms are also used as verbs in which case they refer to mutating
some value to make it true or false, respectively.

The term [supported styling language] refers to CSS.

 If another styling language becomes supported in user
agents, this specification is expected to be updated as necessary.

The term [supported CSS property] refers to a CSS property that the
user agent implements, including any vendor-prefixed properties, but
excluding [custom
properties](https://drafts.csswg.org/css-variables-1/#custom-property). A [supported CSS
property](#supported-css-property) must be in its lowercase form for the purpose of
comparisons in this specification.

In this specification the
[::before](https://drafts.csswg.org/selectors-3/#sel-before) and
[::after](https://drafts.csswg.org/selectors-3/#sel-after) pseudo-elements are assumed to exist for all
elements even if no box is generated for them.

When a method or an attribute is said to call another method or
attribute, the user agent must invoke its internal API for that
attribute or method so that e.g. the author can't change the behavior by
overriding attributes or methods with custom properties or functions in
ECMAScript.

Unless otherwise stated, string comparisons are done in a
[case-sensitive](https://w3c.github.io/i18n-glossary/#dfn-case-sensitive) manner.

### 2.1. Common Serializing Idioms

To [escape a character] means to create a string of \"`\`\" (U+005C),
followed by the character.

To [escape a character as code point]
means to create a string of \"`\`\" (U+005C), followed by the Unicode
code point as the smallest possible number of hexadecimal digits in the
range 0-9 a-f (U+0030 to U+0039 and U+0061 to U+0066) to represent the
code point in base 16, followed by a single SPACE (U+0020).

To [serialize an identifier] means to create a string represented by the
concatenation of, for each character of the identifier:

- If the character is NULL (U+0000), then the REPLACEMENT CHARACTER
 (U+FFFD).
- If the character is in the range \[\\1-\\1f\] (U+0001 to U+001F) or is
 U+007F, then the character [escaped as code
 point](#escape-a-character-as-code-point).
- If the character is the first character and is in the range \[0-9\]
 (U+0030 to U+0039), then the character [escaped as code
 point](#escape-a-character-as-code-point).
- If the character is the second character and is in the range \[0-9\]
 (U+0030 to U+0039) and the first character is a \"`-`\" (U+002D), then
 the character [escaped as code
 point](#escape-a-character-as-code-point).
- If the character is the first character and is a \"`-`\" (U+002D), and
 there is no second character, then the
 [escaped](#escape-a-character) character.
- If the character is not handled by one of the above rules and is
 greater than or equal to U+0080, is \"`-`\" (U+002D) or \"`_`\"
 (U+005F), or is in one of the ranges \[0-9\] (U+0030 to U+0039),
 \[A-Z\] (U+0041 to U+005A), or \[a-z\] (U+0061 to U+007A), then the
 character itself.
- Otherwise, the
 [escaped](#escape-a-character) character.

To [serialize a function] `func`, returning a
[string](https://infra.spec.whatwg.org/#string):

1. Let `s` be an empty
 [string](https://infra.spec.whatwg.org/#string).

2. [Serialize an
 identifier](#serialize-an-identifier) from `func`'s name, ASCII lowercased,
 and append the result to `s`.

3. Append \"(\" (U+0028) to `s`.

4. Serialize `func`'s contents, either as specified by the
 definition of `func`, or in the shortest form possible
 (akin to the principles captured by [serialize a CSS
 value](#serialize-a-css-value)). Append the result to `s`.

5. Append \")\" (U+0029) to `s`.

6. Return `s`.

To [serialize a string]
means to create a string represented by \'\"\' (U+0022), followed by the
result of applying the rules below to each character of the given
string, followed by \'\"\' (U+0022):

- If the character is NULL (U+0000), then the REPLACEMENT CHARACTER
 (U+FFFD).
- If the character is in the range \[\\1-\\1f\] (U+0001 to U+001F) or is
 U+007F, the character [escaped as code
 point](#escape-a-character-as-code-point).
- If the character is \'\"\' (U+0022) or \"`\`\" (U+005C), the
 [escaped](#escape-a-character) character.
- Otherwise, the character itself.

 \"`'`\" (U+0027) is not escaped because strings are
always serialized with \'\"\' (U+0022).

To [serialize a URL] means to create a string represented by \"`url(`\", followed
by the [serialization](#serialize-a-string) of the URL as a string, followed by \"`)`\".

To [serialize a LOCAL] means to create a string represented by
\"`local(`\", followed by the
[serialization](#serialize-a-string) of the LOCAL as a string, followed by \"`)`\".

To [serialize a comma-separated list] concatenate all items of the
list in list order while separating them by \"`, `\", i.e., COMMA
(U+002C) followed by a single SPACE (U+0020).

To [serialize a whitespace-separated
list] concatenate all items of the list in list
order while separating them by \"` `\", i.e., a single SPACE (U+0020).

 When serializing a list according to the above rules,
extraneous whitespace is not inserted prior to the first item or
subsequent to the last item. Unless otherwise specified, an empty list
is serialized as the empty string.

## 3. CSSOMString

Most strings in CSSOM interfaces use the [`CSSOMString`] type. Each
implementation chooses to define it as either
[`USVString`](https://webidl.spec.whatwg.org/#idl-USVString) or
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString):

```
typedef USVString CSSOMString;
```

Or, alternatively:

```
typedef DOMString CSSOMString;
```

The difference is only observable from web content when
[surrogate](https://infra.spec.whatwg.org/#surrogate) code units are involved.
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) would preserve them, whereas
[`USVString`](https://webidl.spec.whatwg.org/#idl-USVString) would replace them with U+FFFD REPLACEMENT CHARACTER.

This choice effectively allows implementations to do this replacement,
but does not require it.

Using
[`USVString`](https://webidl.spec.whatwg.org/#idl-USVString) enables an implementation to use UTF-8 internally to
represent strings in memory. Since well-formed UTF-8 specifically
disallows
[surrogate](https://infra.spec.whatwg.org/#surrogate) code points, it effectively requires this replacement.

On the other hand, implementations that internally represent strings as
16-bit [code
units](https://infra.spec.whatwg.org/#code-unit) might prefer to avoid the cost of doing this
replacement.

## 4. Media Queries

[Media
queries](https://drafts.csswg.org/mediaqueries-5/#media-query) are defined by
[\[MEDIAQUERIES\]](#biblio-mediaqueries "Media Queries Level 4").
This section defines various concepts around [media
queries], including their API and serialization
form.

### 4.1. Parsing Media Queries

To [parse a media query list] for a given string `s`
into a [media query
list](https://drafts.csswg.org/mediaqueries-5/#media-query-list) is defined in the Media Queries specification. Return
the list of media queries that the algorithm defined there gives.

 A media query that ends up being \"ignored\" will turn
into \"`not all`\".

To [parse a media query] for a given string `s` means to
follow the [parse a media query
list](#parse-a-media-query-list) steps and return null if more than one media query is
returned or a media query if a single media query is returned.

 Again, a media query that ends up being \"ignored\"
will turn into \"`not all`\".

### 4.2. Serializing Media Queries

To [serialize a media query list] run these steps:

1. If the [media query
 list](https://drafts.csswg.org/mediaqueries-5/#media-query-list) is empty, then return the empty string.
2. [Serialize](#serialize-a-media-query) each media query in the list of media queries, in
 the same order as they appear in the [media query
 list](https://drafts.csswg.org/mediaqueries-5/#media-query-list), and then
 [serialize](#serialize-a-comma-separated-list) the list.

To [serialize a media query] let `s` be the empty string, run
the steps below:

1. If the [media
 query](https://drafts.csswg.org/mediaqueries-5/#media-query) is negated append \"`not`\", followed by a single
 SPACE (U+0020), to `s`.
2. Let `type` be the [serialization as an
 identifier](#serialize-an-identifier) of the [media
 type](https://drafts.csswg.org/mediaqueries-5/#media-type) of the [media
 query](https://drafts.csswg.org/mediaqueries-5/#media-query), [converted to ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase).
3. If the [media
 query](https://drafts.csswg.org/mediaqueries-5/#media-query) does not contain [media
 features](https://drafts.csswg.org/mediaqueries-5/#media-feature) append `type`, to `s`, then
 return `s`.
4. If `type` is not \"`all`\" or if the media query is
 negated append `type`, followed by a single SPACE
 (U+0020), followed by \"`and`\", followed by a single SPACE
 (U+0020), to `s`.
5. Then, for each [media
 feature](https://drafts.csswg.org/mediaqueries-5/#media-feature):
 1. Append a \"`(`\" (U+0028), followed by the [media
 feature](https://drafts.csswg.org/mediaqueries-5/#media-feature) name, [converted to ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase), to `s`.
 2. If a value is given append a \"`:`\" (U+003A), followed by a
 single SPACE (U+0020), followed by the [serialized media feature
 value](#serialize-a-media-feature-value), to `s`.
 3. Append a \"`)`\" (U+0029) to `s`.
 4. If this is not the last [media
 feature](https://drafts.csswg.org/mediaqueries-5/#media-feature) append a single SPACE (U+0020), followed by
 \"`and`\", followed by a single SPACE (U+0020), to
 `s`.
6. Return `s`.

Here are some examples of input (first
column) and output (second column):

Input

Output

 not screen and (min-WIDTH:5px) AND (max-width:40px)

 not screen and (min-width: 5px) and (max-width: 40px)

 all and (color) and (color)

 (color) and (color)

- [mediaquery-sort-dedup.html](https://wpt.fyi/results/css/cssom/mediaquery-sort-dedup.html "css/cssom/mediaquery-sort-dedup.html")
 [[(live
 test)]](http://wpt.live/css/cssom/mediaquery-sort-dedup.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/mediaquery-sort-dedup.html)

#### 4.2.1. Serializing Media Feature Values

This should probably be done in terms of
mapping it to serializing CSS values as media features are defined in
terms of CSS values after all.

To [serialize a media feature value] named `v` locate
`v` in the first column of the table below and use the
serialization format described in the second column:

Media Feature

Serialization

[width](https://drafts.csswg.org/mediaqueries-5/#descdef-media-width)

\...

[height](https://drafts.csswg.org/mediaqueries-5/#descdef-media-height)

\...

[device-width](https://drafts.csswg.org/mediaqueries-5/#descdef-media-device-width)

\...

[device-height](https://drafts.csswg.org/mediaqueries-5/#descdef-media-device-height)

\...

[orientation](https://drafts.csswg.org/mediaqueries-5/#descdef-media-orientation)

If the value is [portrait]: \"`portrait`\". If the value is
[landscape]: \"`landscape`\".

[aspect-ratio](https://drafts.csswg.org/mediaqueries-5/#descdef-media-aspect-ratio)

\...

[device-aspect-ratio](https://drafts.csswg.org/mediaqueries-5/#descdef-media-device-aspect-ratio)

\...

[color](https://drafts.csswg.org/mediaqueries-5/#descdef-media-color)

\...

[color-index](https://drafts.csswg.org/mediaqueries-5/#descdef-media-color-index)

\...

[monochrome](https://drafts.csswg.org/mediaqueries-5/#descdef-media-monochrome)

\...

[resolution](https://drafts.csswg.org/mediaqueries-5/#descdef-media-resolution)

\...

[scan](https://drafts.csswg.org/mediaqueries-5/#descdef-media-scan)

If the value is [progressive]: \"`progressive`\". If the value is
[interlace]: \"`interlace`\".

[grid](https://drafts.csswg.org/mediaqueries-5/#descdef-media-grid)

\...

Other specifications can extend this table and vendor-prefixed media
features can have custom serialization formats as well.

### 4.3. Comparing Media Queries

To [compare media queries] `m1` and `m2` means to
[serialize](#serialize-a-media-query) them both and return true if they are a
[case-sensitive](https://w3c.github.io/i18n-glossary/#dfn-case-sensitive) match and false if they are not.

### 4.4. The [`MediaList` Interface]
An object that implements the `MediaList` interface has an associated
[collection of media queries].

```
[Exposed=Window]
interface MediaList {
 stringifier attribute [LegacyNullToEmptyString] CSSOMString mediaText;
 readonly attribute unsigned long length;
 getter CSSOMString? item(unsigned long index);
 undefined appendMedium(CSSOMString medium);
 undefined deleteMedium(CSSOMString medium);
};
```

The object's [supported property
indices](http://heycam.github.io/webidl/#dfn-supported-property-indices) are the numbers in the range zero to one less than the
number of media queries in the [collection of media
queries](#medialist-collection-of-media-queries) represented by the collection. If there are no such
media queries, then there are no [supported property
indices].

Tests

- [medialist-dynamic-001.html](https://wpt.fyi/results/css/cssom/medialist-dynamic-001.html "css/cssom/medialist-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom/medialist-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/medialist-dynamic-001.html)
- [medialist-interfaces-001.html](https://wpt.fyi/results/css/cssom/medialist-interfaces-001.html "css/cssom/medialist-interfaces-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom/medialist-interfaces-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/medialist-interfaces-001.html)
- [medialist-interfaces-002.html](https://wpt.fyi/results/css/cssom/medialist-interfaces-002.html "css/cssom/medialist-interfaces-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom/medialist-interfaces-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/medialist-interfaces-002.html)
- [medialist-interfaces-004.html](https://wpt.fyi/results/css/cssom/medialist-interfaces-004.html "css/cssom/medialist-interfaces-004.html")
 [[(live
 test)]](http://wpt.live/css/cssom/medialist-interfaces-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/medialist-interfaces-004.html)
- [MediaList.html](https://wpt.fyi/results/css/cssom/MediaList.html "css/cssom/MediaList.html")
 [[(live
 test)]](http://wpt.live/css/cssom/MediaList.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/MediaList.html)
- [MediaList2.xhtml](https://wpt.fyi/results/css/cssom/MediaList2.xhtml "css/cssom/MediaList2.xhtml")
 [[(live
 test)]](http://wpt.live/css/cssom/MediaList2.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/MediaList2.xhtml)

To [create a `MediaList` object] with a string `text`,
run the following steps:

1. Create a new `MediaList` object.
2. Set its
 [`mediaText`](#dom-medialist-mediatext) attribute to `text`.
3. Return the newly created `MediaList` object.

The [`mediaText`] attribute, on
getting, must return a
[serialization](#serialize-a-media-query-list) of the [collection of media
queries](#medialist-collection-of-media-queries). Setting the
[`mediaText`](#dom-medialist-mediatext) attribute must run these steps:

1. Empty the [collection of media
 queries](#medialist-collection-of-media-queries).
2. If the given value is the empty string, then return.
3. Append all the media queries as a result of
 [parsing](#parse-a-media-query-list) the given value to the [collection of media
 queries](#medialist-collection-of-media-queries).

The [`item(``index``)`] method must
return a
[serialization](#serialize-a-media-query) of the media query in the [collection of media
queries](#medialist-collection-of-media-queries) given by `index`, or null, if
`index` is greater than or equal to the number of media
queries in the [collection of media
queries].

The [`length`] attribute must
return the number of media queries in the [collection of media
queries](#medialist-collection-of-media-queries).

The [`appendMedium(``medium``)`] method must run these steps:

1. Let `m` be the result of
 [parsing](#parse-a-media-query) the given value.
2. If `m` is null, then return.
3. If
 [comparing](#compare-media-queries) `m` with any of the media queries in the
 [collection of media
 queries](#medialist-collection-of-media-queries) returns true, then return.
4. Append `m` to the [collection of media
 queries](#medialist-collection-of-media-queries).

The [`deleteMedium(``medium``)`] method must run these steps:

1. Let `m` be the result of
 [parsing](#parse-a-media-query) the given value.
2. If `m` is null, then return.
3. Remove any media query from the [collection of media
 queries](#medialist-collection-of-media-queries) for which
 [comparing](#compare-media-queries) the media query with `m` returns true.
 If nothing was removed, then
 [throw](http://heycam.github.io/webidl/#dfn-throw) a
 [`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror) exception.

## 5. Selectors

Selectors are defined in the Selectors specification. This section
mainly defines how to serialize them.

### 5.1. Parsing Selectors

To [parse a group of selectors] means to parse the value using
the `selectors_group` production defined in the Selectors specification
and return either a group of selectors if parsing did not fail or null
if parsing did fail.

### 5.2. Serializing Selectors

To [serialize a group of selectors]
[serialize](#serialize-a-selector) each selector in the group of selectors and then
[serialize](#serialize-a-comma-separated-list) a comma-separated list of these serializations.

To [serialize a selector] let `s` be the empty string, run
the steps below for each part of the chain of the selector, and finally
return `s`:

1. If there is only one [simple
 selector](https://drafts.csswg.org/selectors-4/#simple) in the [compound
 selectors](https://drafts.csswg.org/selectors-4/#compound) which is a [universal
 selector](https://drafts.csswg.org/selectors-4/#universal-selector), append the result of
 [serializing](#serialize-a-simple-selector) the [universal
 selector] to `s`.
2. Otherwise, for each [simple
 selector](https://drafts.csswg.org/selectors-4/#simple) in the [compound
 selectors](https://drafts.csswg.org/selectors-4/#compound) that is not a universal selector of which the
 [namespace
 prefix](https://drafts.csswg.org/css-namespaces-3/#namespace-prefix) maps to a namespace that is not the [default
 namespace](https://drafts.csswg.org/css-namespaces-3/#default-namespace)
 [serialize](#serialize-a-simple-selector) the [simple selector] and append
 the result to `s`.
3. If this is not the last part of the chain of the selector append a
 single SPACE (U+0020), followed by the combinator \"`>`\", \"`+`\",
 \"`~`\", \"`>>`\", \"`||`\", as appropriate, followed by another
 single SPACE (U+0020) if the combinator was not whitespace, to
 `s`.
4. If this is the last part of the chain of the selector and there is a
 pseudo-element, append \"`::`\" followed by the name of the
 pseudo-element, to `s`.

Tests

- [selectorSerialize.html](https://wpt.fyi/results/css/cssom/selectorSerialize.html "css/cssom/selectorSerialize.html")
 [[(live
 test)]](http://wpt.live/css/cssom/selectorSerialize.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/selectorSerialize.html)
- [serialize-namespaced-type-selectors.html](https://wpt.fyi/results/css/cssom/serialize-namespaced-type-selectors.html "css/cssom/serialize-namespaced-type-selectors.html")
 [[(live
 test)]](http://wpt.live/css/cssom/serialize-namespaced-type-selectors.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/serialize-namespaced-type-selectors.html)

To [serialize a simple selector] let `s` be the empty
string, run the steps below, and finally return `s`:

type selector\
universal selector

: 1. If the [namespace
 prefix](https://drafts.csswg.org/css-namespaces-3/#namespace-prefix) maps to a namespace that is not the [default
 namespace](https://drafts.csswg.org/css-namespaces-3/#default-namespace) and is not the null namespace (not in a
 namespace) append the
 [serialization](#serialize-an-identifier) of the [namespace
 prefix] as an identifier, followed
 by a \"`|`\" (U+007C) to `s`.
 2. If the [namespace
 prefix](https://drafts.csswg.org/css-namespaces-3/#namespace-prefix) maps to a namespace that is the null namespace
 (not in a namespace) append \"`|`\" (U+007C) to `s`.
 3. If this is a type selector append the
 [serialization](#serialize-an-identifier) of the element name as an identifier to
 `s`.
 4. If this is a universal selector append \"`*`\" (U+002A) to
 `s`.

attribute selector

: 1. Append \"`[`\" (U+005B) to `s`.
 2. If the [namespace
 prefix](https://drafts.csswg.org/css-namespaces-3/#namespace-prefix) maps to a namespace that is not the null
 namespace (not in a namespace) append the
 [serialization](#serialize-an-identifier) of the [namespace
 prefix] as an identifier, followed
 by a \"`|`\" (U+007C) to `s`.
 3. Append the
 [serialization](#serialize-an-identifier) of the attribute name as an identifier to
 `s`.
 4. If there is an attribute value specified, append \"`=`\",
 \"`~=`\", \"`|=`\", \"`^=`\", \"`$=`\", or \"`*=`\" as
 appropriate (depending on the type of attribute selector),
 followed by the
 [serialization](#serialize-a-string) of the attribute value as a string, to
 `s`.
 5. If the attribute selector has the case-sensitivity flag present,
 append \"` i`\" (U+0020 U+0069) to `s`.
 6. Append \"`]`\" (U+005D) to `s`.

class selector
: Append a \"`.`\" (U+002E), followed by the
 [serialization](#serialize-an-identifier) of the class name as an identifier to
 `s`.

ID selector
: Append a \"`#`\" (U+0023), followed by the
 [serialization](#serialize-an-identifier) of the ID as an identifier to `s`.

pseudo-class

: If the pseudo-class does not accept arguments append \"`:`\"
 (U+003A), followed by the name of the pseudo-class, to
 `s`.

 Otherwise, append \"`:`\" (U+003A), followed by the name of the
 pseudo-class, followed by \"`(`\" (U+0028), followed by the value of
 the pseudo-class argument(s) determined as per below, followed by
 \"`)`\" (U+0029), to `s`.

 `:lang()`
 : The [serialization of a comma-separated
 list](#serialize-a-comma-separated-list) of each argument's [serialization as a
 string](#serialize-a-string), preserving relative order.

 `:nth-child()`\
 `:nth-last-child()`\
 `:nth-of-type()`\
 `:nth-last-of-type()`
 : The result of serializing the value using the rules to
 [serialize an \<a-n-plus-b\>
 value](https://drafts.csswg.org/css-syntax-3/#serialize-an-a-n-plus-b-value).

 `:not()`
 : The result of serializing the value using the rules for
 [serializing a group of
 selectors](#serialize-a-group-of-selectors).

## 6. CSS

### 6.1. CSS Style Sheets

A [CSS style sheet] is an abstract concept that represents a style sheet as
defined by the CSS specification. In the CSSOM a [CSS style
sheet](#css-style-sheet) is
represented as a
[`CSSStyleSheet`](#cssstylesheet) object.

[`CSSStyleSheet(``options``)`]
: When called, execute the steps to [create a constructed
 CSSStyleSheet](#create-a-constructed-cssstylesheet) given `options` and return the result.

To [create a constructed [`CSSStyleSheet`](#cssstylesheet)]

: 1. Construct a new
 [`CSSStyleSheet`](#cssstylesheet) object `sheet`.
 2. Set `sheet`'s
 [location](https://drafts.csswg.org/cssom-1/#concept-css-style-sheet-location) to the [base URL] of the
 [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) for the [current global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object).
 3. Set `sheet`'s [stylesheet base
 URL](#concept-css-style-sheet-stylesheet-base-url) to the
 [`baseURL`](#dom-cssstylesheetinit-baseurl) attribute value from `options`.
 4. Set `sheet`'s [parent CSS style
 sheet](#concept-css-style-sheet-parent-css-style-sheet) to null.
 5. Set `sheet`'s [owner
 node](#concept-css-style-sheet-owner-node) to null.
 6. Set `sheet`'s [owner CSS
 rule](#concept-css-style-sheet-owner-css-rule) to null.
 7. Set `sheet`'s
 [title](#concept-css-style-sheet-title) to the empty string.
 8. Unset `sheet`'s [alternate
 flag](#concept-css-style-sheet-alternate-flag).
 9. Set `sheet`'s [origin-clean
 flag](#concept-css-style-sheet-origin-clean-flag).
 10. Set `sheet`'s [constructed
 flag](#concept-css-style-sheet-constructed-flag).
 11. Set `sheet`'s [Constructor
 document](#concept-css-style-sheet-constructor-document) to the [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) for the [current global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object).
 12. If the
 [`media`](#dom-cssstylesheetinit-media) attribute of `options` is a string,
 [create a MediaList
 object](#create-a-medialist-object) from the string and assign it as
 `sheet`'s
 [media](#concept-css-style-sheet-media). Otherwise, [serialize a media query
 list](#serialize-a-media-query-list) from the attribute and then [create a MediaList
 object] from the resulting
 string and set it as `sheet`'s
 [media].
 13. If the
 [`disabled`](#dom-cssstylesheetinit-disabled) attribute of `options` is true, set
 `sheet`'s [disabled
 flag](#concept-css-style-sheet-disabled-flag).
 14. Return `sheet`.

Tests

- [CSSStyleSheet-constructable-baseURL.html](https://wpt.fyi/results/css/cssom/CSSStyleSheet-constructable-baseURL.html "css/cssom/CSSStyleSheet-constructable-baseURL.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleSheet-constructable-baseURL.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleSheet-constructable-baseURL.html)
- [CSSStyleSheet-constructable-concat.html](https://wpt.fyi/results/css/cssom/CSSStyleSheet-constructable-concat.html "css/cssom/CSSStyleSheet-constructable-concat.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleSheet-constructable-concat.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleSheet-constructable-concat.html)
- [CSSStyleSheet-constructable-cssRules.html](https://wpt.fyi/results/css/cssom/CSSStyleSheet-constructable-cssRules.html "css/cssom/CSSStyleSheet-constructable-cssRules.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleSheet-constructable-cssRules.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleSheet-constructable-cssRules.html)
- [CSSStyleSheet-constructable-disabled-regular-sheet-insertion.html](https://wpt.fyi/results/css/cssom/CSSStyleSheet-constructable-disabled-regular-sheet-insertion.html "css/cssom/CSSStyleSheet-constructable-disabled-regular-sheet-insertion.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleSheet-constructable-disabled-regular-sheet-insertion.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleSheet-constructable-disabled-regular-sheet-insertion.html)
- [CSSStyleSheet-constructable-disallow-import.tentative.html](https://wpt.fyi/results/css/cssom/CSSStyleSheet-constructable-disallow-import.tentative.html "css/cssom/CSSStyleSheet-constructable-disallow-import.tentative.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleSheet-constructable-disallow-import.tentative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleSheet-constructable-disallow-import.tentative.html)
- [CSSStyleSheet-constructable-duplicate.html](https://wpt.fyi/results/css/cssom/CSSStyleSheet-constructable-duplicate.html "css/cssom/CSSStyleSheet-constructable-duplicate.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleSheet-constructable-duplicate.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleSheet-constructable-duplicate.html)
- [CSSStyleSheet-constructable-insertRule-base-uri.html](https://wpt.fyi/results/css/cssom/CSSStyleSheet-constructable-insertRule-base-uri.html "css/cssom/CSSStyleSheet-constructable-insertRule-base-uri.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleSheet-constructable-insertRule-base-uri.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleSheet-constructable-insertRule-base-uri.html)
- [CSSStyleSheet-constructable-invalidation.html](https://wpt.fyi/results/css/cssom/CSSStyleSheet-constructable-invalidation.html "css/cssom/CSSStyleSheet-constructable-invalidation.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleSheet-constructable-invalidation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleSheet-constructable-invalidation.html)
- [CSSStyleSheet-constructable-replace-cssRules.html](https://wpt.fyi/results/css/cssom/CSSStyleSheet-constructable-replace-cssRules.html "css/cssom/CSSStyleSheet-constructable-replace-cssRules.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleSheet-constructable-replace-cssRules.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleSheet-constructable-replace-cssRules.html)
- [CSSStyleSheet-constructable-replace-on-regular-sheet.html](https://wpt.fyi/results/css/cssom/CSSStyleSheet-constructable-replace-on-regular-sheet.html "css/cssom/CSSStyleSheet-constructable-replace-on-regular-sheet.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleSheet-constructable-replace-on-regular-sheet.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleSheet-constructable-replace-on-regular-sheet.html)
- [CSSStyleSheet-constructable.html](https://wpt.fyi/results/css/cssom/CSSStyleSheet-constructable.html "css/cssom/CSSStyleSheet-constructable.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleSheet-constructable.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleSheet-constructable.html)
- [CSSStyleSheet-modify-after-removal.html](https://wpt.fyi/results/css/cssom/CSSStyleSheet-modify-after-removal.html "css/cssom/CSSStyleSheet-modify-after-removal.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleSheet-modify-after-removal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleSheet-modify-after-removal.html)
- [CSSStyleSheet-template-adoption.html](https://wpt.fyi/results/css/cssom/CSSStyleSheet-template-adoption.html "css/cssom/CSSStyleSheet-template-adoption.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleSheet-template-adoption.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleSheet-template-adoption.html)
- [CSSStyleSheet.html](https://wpt.fyi/results/css/cssom/CSSStyleSheet.html "css/cssom/CSSStyleSheet.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleSheet.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleSheet.html)
- [style-sheet-interfaces-001.html](https://wpt.fyi/results/css/cssom/style-sheet-interfaces-001.html "css/cssom/style-sheet-interfaces-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom/style-sheet-interfaces-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/style-sheet-interfaces-001.html)
- [style-sheet-interfaces-002.html](https://wpt.fyi/results/css/cssom/style-sheet-interfaces-002.html "css/cssom/style-sheet-interfaces-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom/style-sheet-interfaces-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/style-sheet-interfaces-002.html)

A [CSS style sheet](#css-style-sheet) has a number of associated state items:

[type]
: The literal string \"`text/css`\".

[location]
: Specified when created. The [absolute-URL
 string](https://url.spec.whatwg.org/#absolute-url-string) of the first request of the [CSS style
 sheet](#css-style-sheet)
 or null if the [CSS style sheet] was
 embedded. Does not change during the lifetime of the [CSS style
 sheet].

[parent CSS style sheet]
: Specified when created. The [CSS style
 sheet](#css-style-sheet)
 that is the parent of the [CSS style
 sheet] or null if there is no associated
 parent.

[owner node]
: Specified when created. The DOM node associated with the [CSS style
 sheet](#css-style-sheet)
 or null if there is no associated DOM node.

[owner CSS rule]
: Specified when created. The [CSS rule](#css-rule) in the [parent CSS style
 sheet](#concept-css-style-sheet-parent-css-style-sheet) that caused the inclusion of the [CSS style
 sheet](#css-style-sheet)
 or null if there is no associated rule.

[media]

: Specified when created. The
 [`MediaList`](#medialist)
 object associated with the [CSS style
 sheet](#css-style-sheet).

 If this property is specified to a string, the
 [media](#concept-css-style-sheet-media) must be set to the return value of invoking [create
 a `MediaList`
 object](#create-a-medialist-object) steps for that string.

 If this property is specified to an attribute of the [owner
 node](#concept-css-style-sheet-owner-node), the
 [media](#concept-css-style-sheet-media) must be set to the return value of invoking [create
 a `MediaList`
 object](#create-a-medialist-object) steps for the value of that attribute. Whenever the
 attribute is set, changed or removed, the
 [media]'s
 [`mediaText`](#dom-medialist-mediatext) attribute must be set to the new value of the
 attribute, or to null if the attribute is absent.

 Changing the
 [media](#concept-css-style-sheet-media)'s
 [`mediaText`](#dom-medialist-mediatext) attribute does not change the corresponding
 attribute on the [owner
 node](#concept-css-style-sheet-owner-node).

 The [owner
 node](#concept-css-style-sheet-owner-node) of a [CSS style
 sheet](#css-style-sheet), if non-null, is the node whose [associated CSS
 style
 sheet](#associated-css-style-sheet) is the [CSS style
 sheet] in question, when the [CSS style
 sheet] is
 [added](#add-a-css-style-sheet).

[title]

: Specified when created. The title of the [CSS style
 sheet](#css-style-sheet), which can be the empty string.

 :::
 (#example-a945fdba) In the following, the
 [title](#concept-css-style-sheet-title) is non-empty for the first style sheet, but is
 empty for the second and third style sheets.
 <style title="papaya whip">
 body { background: #ffefd5; }
 </style>

 <style title="">
 body { background: orange; }
 </style>

 <style>
 body { background: brown; }
 </style>
 :::

 If this property is specified to an attribute of the [owner
 node](#concept-css-style-sheet-owner-node), the
 [title](#concept-css-style-sheet-title) must be set to the value of that attribute.
 Whenever the attribute is set, changed or removed, the
 [title] must be set to the
 new value of the attribute, or to the empty string if the attribute
 is absent.

 HTML only
 [specifies](https://html.spec.whatwg.org/#the-style-element:concept-css-style-sheet-title)
 [title](#concept-css-style-sheet-title) to be an attribute of the [owner
 node](#concept-css-style-sheet-owner-node) if the node is in [in a document
 tree](https://dom.spec.whatwg.org/#in-a-document-tree).

[alternate flag]
: Specified when created. Either set or unset. Unset by default.
 :::
 (#example-cd0d9c55) The following [CSS style
 sheets](#css-style-sheet) have their [alternate
 flag](#concept-css-style-sheet-alternate-flag) set:
 <?xml-stylesheet alternate="yes" title="x" href="data:text/css,…"?>

 <link rel="alternate stylesheet" title="x" href="data:text/css,…">
 :::

[disabled flag]

: Either set or unset. Unset by default.

 Even when unset it does not necessarily mean that
 the [CSS style sheet](#css-style-sheet) is actually used for rendering.

[CSS rules]
: The CSS rules associated with the [CSS style
 sheet](#css-style-sheet).

[origin-clean flag]
: Specified when created. Either set or unset. If it is set, the API
 allows reading and modifying of the [CSS
 rules](#concept-css-style-sheet-css-rules).

[constructed flag]
: Specified when created. Either set or unset. Unset by default.
 Signifies whether this stylesheet was created by invoking the
 IDL-defined constructor.

[disallow modification flag]
: Either set or unset. Unset by default. If set, modification of the
 stylesheet's rules is not allowed.

[constructor document]
: Specified when created. The
 [`Document`](https://dom.spec.whatwg.org/#document) a constructed stylesheet is associated with. Null
 by default. Only non-null for stylesheets that have [constructed
 flag](#concept-css-style-sheet-constructed-flag) set.

[stylesheet base URL]
: The base URL to use when resolving relative URLs in the stylesheet.
 Null by default. Only non-null for stylesheets that have
 [constructed
 flag](#concept-css-style-sheet-constructed-flag) set.

Tests

- [base-uri.html](https://wpt.fyi/results/css/cssom/base-uri.html "css/cssom/base-uri.html")
 [[(live
 test)]](http://wpt.live/css/cssom/base-uri.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/base-uri.html)

#### 6.1.1. The [`StyleSheet` Interface]
The [`StyleSheet`](#stylesheet) interface represents an abstract, base style sheet.

```
[Exposed=Window]
interface StyleSheet {
 readonly attribute CSSOMString type;
 readonly attribute USVString? href;
 readonly attribute (Element or ProcessingInstruction)? ownerNode;
 readonly attribute CSSStyleSheet? parentStyleSheet;
 readonly attribute DOMString? title;
 [SameObject, PutForwards=mediaText] readonly attribute MediaList media;
 attribute boolean disabled;
};
```

The [`type`] attribute must
return the
[type](#concept-css-style-sheet-type).

The [`href`] attribute must
return the
[location](#concept-css-style-sheet-location).

The [`ownerNode`] attribute must
return the [owner
node](#concept-css-style-sheet-owner-node).

The [`parentStyleSheet`] attribute must return the [parent CSS style
sheet](#concept-css-style-sheet-parent-css-style-sheet).

The [`title`] attribute must
return the
[title](#concept-css-style-sheet-title) or null if
[title] is the empty string.

The [`media`] attribute must
return the
[media](#concept-css-style-sheet-media).

The [`disabled`] attribute, on
getting, must return true if the [disabled
flag](#concept-css-style-sheet-disabled-flag) is set, or false otherwise. On setting, the
[`disabled`](#dom-stylesheet-disabled) attribute must set the [disabled
flag] if the new value
is true, or unset the [disabled
flag] otherwise.

Tests

- [link-element-stylesheet-title.html](https://wpt.fyi/results/css/cssom/link-element-stylesheet-title.html "css/cssom/link-element-stylesheet-title.html")
 [[(live
 test)]](http://wpt.live/css/cssom/link-element-stylesheet-title.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/link-element-stylesheet-title.html)
- [stylesheet-same-origin.sub.html](https://wpt.fyi/results/css/cssom/stylesheet-same-origin.sub.html "css/cssom/stylesheet-same-origin.sub.html")
 [[(live
 test)]](http://wpt.live/css/cssom/stylesheet-same-origin.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/stylesheet-same-origin.sub.html)
- [stylesheet-title.html](https://wpt.fyi/results/css/cssom/stylesheet-title.html "css/cssom/stylesheet-title.html")
 [[(live
 test)]](http://wpt.live/css/cssom/stylesheet-title.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/stylesheet-title.html)

#### 6.1.2. The [`CSSStyleSheet` Interface]
The [`CSSStyleSheet`](#cssstylesheet) interface represents a [CSS style
sheet](#css-style-sheet).

```
[Exposed=Window]
interface CSSStyleSheet : StyleSheet {
 constructor(optional CSSStyleSheetInit options = );

 readonly attribute CSSRule? ownerRule;
 [SameObject] readonly attribute CSSRuleList cssRules;
 unsigned long insertRule(CSSOMString rule, optional unsigned long index = 0);
 undefined deleteRule(unsigned long index);

 Promise<CSSStyleSheet> replace(USVString text);
 undefined replaceSync(USVString text);
};

dictionary CSSStyleSheetInit {
 DOMString? baseURL = null;
 (MediaList or DOMString) media = "";
 boolean disabled = false;
};
```

The [`ownerRule`]
attribute must return the [owner CSS
rule](#concept-css-style-sheet-owner-css-rule). If a value other than null is ever returned, then that
same value must always be returned on each get access.

The [`cssRules`] attribute must
follow these steps:

1. If the [origin-clean
 flag](#concept-css-style-sheet-origin-clean-flag) is unset,
 [throw](http://heycam.github.io/webidl/#dfn-throw) a
 [`SecurityError`](https://webidl.spec.whatwg.org/#securityerror) exception.

2. Return a read-only, live
 [`CSSRuleList`](#cssrulelist) object representing the [CSS
 rules](#concept-css-style-sheet-css-rules).

 Even though the returned
 [`CSSRuleList`](#cssrulelist) object is read-only (from the perspective of
 client-authored script), it can nevertheless change over time due to
 its liveness status. For example, invoking the
 [`insertRule()`](#dom-cssstylesheet-insertrule) or
 [`deleteRule()`](#dom-cssstylesheet-deleterule) methods can result in mutations reflected in the
 returned object.

The
[`insertRule(``rule``, ``index``)`] method must run
the following steps:

1. If the [origin-clean
 flag](#concept-css-style-sheet-origin-clean-flag) is unset,
 [throw](http://heycam.github.io/webidl/#dfn-throw) a
 [`SecurityError`](https://webidl.spec.whatwg.org/#securityerror) exception.
2. If the [disallow modification
 flag](#concept-css-style-sheet-disallow-modification-flag) is set, throw a
 [`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).
3. Let `parsed rule` be the return value of invoking [parse
 a
 rule](https://drafts.csswg.org/css-syntax-3/#parse-a-rule) with `rule`.
4. If `parsed rule` is a syntax error, throw a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).
5. If `parsed rule` is an
 [\@import](https://drafts.csswg.org/css-cascade-6/#at-ruledef-import) rule, and the [constructed
 flag](#concept-css-style-sheet-constructed-flag) is set, throw a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).
6. Return the result of invoking [insert a CSS
 rule](#insert-a-css-rule) `rule` in the [CSS
 rules](#concept-css-style-sheet-css-rules) at `index`.

Tests

- [insert-dir-rule-crash.html](https://wpt.fyi/results/css/cssom/insert-dir-rule-crash.html "css/cssom/insert-dir-rule-crash.html")
 [[(live
 test)]](http://wpt.live/css/cssom/insert-dir-rule-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/insert-dir-rule-crash.html)
- [insert-dir-rule-in-iframe-crash.html](https://wpt.fyi/results/css/cssom/insert-dir-rule-in-iframe-crash.html "css/cssom/insert-dir-rule-in-iframe-crash.html")
 [[(live
 test)]](http://wpt.live/css/cssom/insert-dir-rule-in-iframe-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/insert-dir-rule-in-iframe-crash.html)
- [insert-invalid-where-rule-crash.html](https://wpt.fyi/results/css/cssom/insert-invalid-where-rule-crash.html "css/cssom/insert-invalid-where-rule-crash.html")
 [[(live
 test)]](http://wpt.live/css/cssom/insert-invalid-where-rule-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/insert-invalid-where-rule-crash.html)
- [insertRule-across-context.html](https://wpt.fyi/results/css/cssom/insertRule-across-context.html "css/cssom/insertRule-across-context.html")
 [[(live
 test)]](http://wpt.live/css/cssom/insertRule-across-context.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/insertRule-across-context.html)
- [insertRule-charset-no-index.html](https://wpt.fyi/results/css/cssom/insertRule-charset-no-index.html "css/cssom/insertRule-charset-no-index.html")
 [[(live
 test)]](http://wpt.live/css/cssom/insertRule-charset-no-index.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/insertRule-charset-no-index.html)
- [insertRule-from-script.html](https://wpt.fyi/results/css/cssom/insertRule-from-script.html "css/cssom/insertRule-from-script.html")
 [[(live
 test)]](http://wpt.live/css/cssom/insertRule-from-script.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/insertRule-from-script.html)
- [insertRule-import-no-index.html](https://wpt.fyi/results/css/cssom/insertRule-import-no-index.html "css/cssom/insertRule-import-no-index.html")
 [[(live
 test)]](http://wpt.live/css/cssom/insertRule-import-no-index.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/insertRule-import-no-index.html)
- [insertRule-import-no-sheet-crash.html](https://wpt.fyi/results/css/cssom/insertRule-import-no-sheet-crash.html "css/cssom/insertRule-import-no-sheet-crash.html")
 [[(live
 test)]](http://wpt.live/css/cssom/insertRule-import-no-sheet-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/insertRule-import-no-sheet-crash.html)
- [insertRule-import-trailing-garbage-crash.html](https://wpt.fyi/results/css/cssom/insertRule-import-trailing-garbage-crash.html "css/cssom/insertRule-import-trailing-garbage-crash.html")
 [[(live
 test)]](http://wpt.live/css/cssom/insertRule-import-trailing-garbage-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/insertRule-import-trailing-garbage-crash.html)
- [insertRule-namespace-no-index.html](https://wpt.fyi/results/css/cssom/insertRule-namespace-no-index.html "css/cssom/insertRule-namespace-no-index.html")
 [[(live
 test)]](http://wpt.live/css/cssom/insertRule-namespace-no-index.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/insertRule-namespace-no-index.html)
- [insertRule-no-index.html](https://wpt.fyi/results/css/cssom/insertRule-no-index.html "css/cssom/insertRule-no-index.html")
 [[(live
 test)]](http://wpt.live/css/cssom/insertRule-no-index.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/insertRule-no-index.html)
- [insertRule-syntax-error-01.html](https://wpt.fyi/results/css/cssom/insertRule-syntax-error-01.html "css/cssom/insertRule-syntax-error-01.html")
 [[(live
 test)]](http://wpt.live/css/cssom/insertRule-syntax-error-01.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/insertRule-syntax-error-01.html)

The [`deleteRule(``index``)`] method must run the following steps:

1. If the [origin-clean
 flag](#concept-css-style-sheet-origin-clean-flag) is unset,
 [throw](http://heycam.github.io/webidl/#dfn-throw) a
 [`SecurityError`](https://webidl.spec.whatwg.org/#securityerror) exception.
2. If the [disallow modification
 flag](#concept-css-style-sheet-disallow-modification-flag) is set, throw a
 [`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).
3. [Remove a CSS rule](#remove-a-css-rule) in the [CSS
 rules](#concept-css-style-sheet-css-rules) at `index`.

The
[`replace(`[`text`](#concept-css-rule-text)`)`] method
must run the following steps:

1. Let `promise` be a promise.
2. If the [constructed
 flag](#concept-css-style-sheet-constructed-flag) is not set, or the [disallow modification
 flag](#concept-css-style-sheet-disallow-modification-flag) is set, reject `promise` with a
 [`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and return `promise`.
3. Set the [disallow modification
 flag](#concept-css-style-sheet-disallow-modification-flag).
4. [In
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel), do these steps:
 1. Let `rules` be the result of running [parse a
 stylesheet's
 contents](https://drafts.csswg.org/css-syntax-3/#parse-a-stylesheets-contents) from `text`.
 2. If `rules` contains one or more
 [\@import](https://drafts.csswg.org/css-cascade-6/#at-ruledef-import) rules, [remove those
 rules](#remove-a-css-rule) from `rules`.
 3. Set `sheet`'s [CSS
 rules](#concept-css-style-sheet-css-rules) to `rules`.
 4. Unset `sheet`'s [disallow modification
 flag](#concept-css-style-sheet-disallow-modification-flag).
 5. Resolve `promise` with `sheet`.
5. Return `promise`.

The
[`replaceSync(`[`text`](#concept-css-rule-text)`)`] method
must run the steps to [synchronously replace the rules of a
CSSStyleSheet](#synchronously-replace-the-rules-of-a-cssstylesheet) on this
[`CSSStyleSheet`](#cssstylesheet) given `text`.

To [synchronously replace the rules of a
CSSStyleSheet] on `sheet` given
`text`, run these steps:

1. If the [constructed
 flag](#concept-css-style-sheet-constructed-flag) is not set, or the [disallow modification
 flag](#concept-css-style-sheet-disallow-modification-flag) is set, throw a
 [`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).
2. Let `rules` be the result of running [parse a
 stylesheet's
 contents](https://drafts.csswg.org/css-syntax-3/#parse-a-stylesheets-contents) from `text`.
3. If `rules` contains one or more
 [\@import](https://drafts.csswg.org/css-cascade-6/#at-ruledef-import) rules, [remove those
 rules](#remove-a-css-rule) from `rules`.
4. Set `sheet`'s [CSS
 rules](#concept-css-style-sheet-css-rules) to `rules`.

##### 6.1.2.1. Deprecated CSSStyleSheet members

 These members are required for compatibility with
existing sites.

```
partial interface CSSStyleSheet {
 [SameObject] readonly attribute CSSRuleList rules;
 long addRule(optional DOMString selector = "undefined", optional DOMString style = "undefined", optional unsigned long index);
 undefined removeRule(optional unsigned long index = 0);
};
```

The [`rules`] attribute must
follow the same steps as
[`cssRules`](#dom-cssstylesheet-cssrules), and return the same object
[`cssRules`](#dom-cssstylesheet-cssrules) would return.

The [`removeRule(``index``)`] method must run the same
steps as
[`deleteRule()`](#dom-cssstylesheet-deleterule).

The
[`addRule(``selector``, ``block``, ``optionalIndex``)`]
method must run the following steps:

1. Let `rule` be an empty string.
2. Append `selector` to `rule`.
3. Append `" { "` to `rule`.
4. If `block` is not empty, append `block`,
 followed by a space, to `rule`.
5. Append `"}"` to `rule`
6. Let `index` be `optionalIndex` if provided, or
 the number of [CSS
 rules](#concept-css-style-sheet-css-rules) in the stylesheet otherwise.
7. Call
 [`insertRule()`](#dom-cssstylesheet-insertrule), with `rule` and `index` as
 arguments.
8. Return `-1`.

Authors should not use these members and should instead use and teach
the standard
[`CSSStyleSheet`](#cssstylesheet) interface defined earlier, which is consistent with
[`CSSGroupingRule`](#cssgroupingrule).

Tests

- [removerule-invalidation-crash.html](https://wpt.fyi/results/css/cssom/removerule-invalidation-crash.html "css/cssom/removerule-invalidation-crash.html")
 [[(live
 test)]](http://wpt.live/css/cssom/removerule-invalidation-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/removerule-invalidation-crash.html)

### 6.2. CSS Style Sheet Collections

Below various new concepts are defined that are associated with each
[`DocumentOrShadowRoot`](https://dom.spec.whatwg.org/#documentorshadowroot) object.

Each
[`DocumentOrShadowRoot`](https://dom.spec.whatwg.org/#documentorshadowroot) has an associated list of zero or more [CSS style
sheets](#css-style-sheet),
named the [document or shadow root CSS style
sheets]. This is an ordered list that contains:

1. Any [CSS style sheets](#css-style-sheet) created from HTTP `Link` headers, in header order
2. Any [CSS style sheets](#css-style-sheet) associated with the
 [`DocumentOrShadowRoot`](https://dom.spec.whatwg.org/#documentorshadowroot), in [tree
 order](https://html.spec.whatwg.org/multipage/infrastructure.html#tree-order)

Each
[`DocumentOrShadowRoot`](https://dom.spec.whatwg.org/#documentorshadowroot) has an associated list of zero or more [CSS style
sheets](#css-style-sheet),
named the [final CSS style
sheets]. This is an
ordered list that contains:

1. The [document or shadow root CSS style
 sheets](#documentorshadowroot-document-or-shadow-root-css-style-sheets).
2. The contents of
 [`DocumentOrShadowRoot`](https://dom.spec.whatwg.org/#documentorshadowroot)'s
 [`adoptedStyleSheets`](#dom-documentorshadowroot-adoptedstylesheets)\' [backing
 list](https://webidl.spec.whatwg.org/#observable-array-attribute-backing-list), in array order.

To [create a CSS style sheet], run these steps:

1. Create a new [CSS style
 sheet](#css-style-sheet)
 object and set its properties as specified.

2. Then run the [add a CSS style
 sheet](#add-a-css-style-sheet) steps for the newly created [CSS style
 sheet](#css-style-sheet).

 If the [origin-clean
 flag](#concept-css-style-sheet-origin-clean-flag) is unset, this can expose information from the
 user's intranet.

To [add a CSS style sheet], run these steps:

1. Add the [CSS style
 sheet](#css-style-sheet)
 to the list of [document or shadow root CSS style
 sheets](#documentorshadowroot-document-or-shadow-root-css-style-sheets) at the appropriate location.

2. If the [CSS style
 sheet](#css-style-sheet)'s [owner
 node](#concept-css-style-sheet-owner-node) [contributes a script-blocking style
 sheet](https://html.spec.whatwg.org/multipage/semantics.html#contributes-a-script-blocking-style-sheet), then user agents must
 [append](https://infra.spec.whatwg.org/#list-append) the [owner
 node] to its [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s [script-blocking style sheet
 set](https://html.spec.whatwg.org/multipage/semantics.html#script-blocking-style-sheet-set).

 The remainder of these steps deal with the [disabled
 flag](#concept-css-style-sheet-disabled-flag).

3. If the [disabled
 flag](#concept-css-style-sheet-disabled-flag) is set, then return.

4. If the
 [title](#concept-css-style-sheet-title) is not the empty string, the [alternate
 flag](#concept-css-style-sheet-alternate-flag) is unset, and [preferred CSS style sheet set
 name](#preferred-css-style-sheet-set-name) is the empty string [change the preferred CSS style
 sheet set
 name](#change-the-preferred-css-style-sheet-set-name) to the
 [title].

5. If any of the following is true, then unset the [disabled
 flag](#concept-css-style-sheet-disabled-flag) and return:
 - The
 [title](#concept-css-style-sheet-title) is the empty string.
 - The [last CSS style sheet set
 name](#last-css-style-sheet-set-name) is null and the
 [title](#concept-css-style-sheet-title) is a
 [case-sensitive](https://w3c.github.io/i18n-glossary/#dfn-case-sensitive) match for the [preferred CSS style sheet set
 name](#preferred-css-style-sheet-set-name).
 - The
 [title](#concept-css-style-sheet-title) is a
 [case-sensitive](https://w3c.github.io/i18n-glossary/#dfn-case-sensitive) match for the [last CSS style sheet set
 name](#last-css-style-sheet-set-name).

6. Set the [disabled
 flag](#concept-css-style-sheet-disabled-flag).

Tests

- [preferred-stylesheet-order.html](https://wpt.fyi/results/css/cssom/preferred-stylesheet-order.html "css/cssom/preferred-stylesheet-order.html")
 [[(live
 test)]](http://wpt.live/css/cssom/preferred-stylesheet-order.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/preferred-stylesheet-order.html)
- [preferred-stylesheet-reversed-order.html](https://wpt.fyi/results/css/cssom/preferred-stylesheet-reversed-order.html "css/cssom/preferred-stylesheet-reversed-order.html")
 [[(live
 test)]](http://wpt.live/css/cssom/preferred-stylesheet-reversed-order.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/preferred-stylesheet-reversed-order.html)

To [remove a CSS style sheet], run these steps:

1. Remove the [CSS style
 sheet](#css-style-sheet)
 from the list of [document or shadow root CSS style
 sheets](#documentorshadowroot-document-or-shadow-root-css-style-sheets).
2. Set the [CSS style
 sheet](#css-style-sheet)'s [parent CSS style
 sheet](#concept-css-style-sheet-parent-css-style-sheet), [owner
 node](#concept-css-style-sheet-owner-node) and [owner CSS
 rule](#concept-css-style-sheet-owner-css-rule) to null.

Tests

- [delete-namespace-rule-when-child-rule-exists.html](https://wpt.fyi/results/css/cssom/delete-namespace-rule-when-child-rule-exists.html "css/cssom/delete-namespace-rule-when-child-rule-exists.html")
 [[(live
 test)]](http://wpt.live/css/cssom/delete-namespace-rule-when-child-rule-exists.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/delete-namespace-rule-when-child-rule-exists.html)

A [persistent CSS style sheet] is a [CSS style
sheet](#css-style-sheet)
from the [document or shadow root CSS style
sheets](#documentorshadowroot-document-or-shadow-root-css-style-sheets) whose
[title](#concept-css-style-sheet-title) is the empty string and whose [alternate
flag](#concept-css-style-sheet-alternate-flag) is unset.

A [CSS style sheet set] is an ordered collection of one or more [CSS
style sheets](#css-style-sheet) from the [document or shadow root CSS style
sheets](#documentorshadowroot-document-or-shadow-root-css-style-sheets) which have an identical
[title](#concept-css-style-sheet-title) that is not the empty string.

A [CSS style sheet set name] is the
[title](#concept-css-style-sheet-title) the [CSS style sheet
set](#css-style-sheet-set)
has in common.

An [enabled CSS style sheet set] is a [CSS style sheet
set](#css-style-sheet-set) of which each [CSS style
sheet](#css-style-sheet) has
its [disabled
flag](#concept-css-style-sheet-disabled-flag) unset.

To [enable a CSS style sheet set] with name `name`, run
these steps:

1. If `name` is the empty string, set the [disabled
 flag](#concept-css-style-sheet-disabled-flag) for each [CSS style
 sheet](#css-style-sheet)
 that is in a [CSS style sheet
 set](#css-style-sheet-set) and return.
2. Unset the [disabled
 flag](#concept-css-style-sheet-disabled-flag) for each [CSS style
 sheet](#css-style-sheet)
 in a [CSS style sheet
 set](#css-style-sheet-set) whose [CSS style sheet set
 name](#css-style-sheet-set-name) is a
 [case-sensitive](https://w3c.github.io/i18n-glossary/#dfn-case-sensitive) match for `name` and set it for all
 other [CSS style sheets] in a [CSS style
 sheet set].

To [select a CSS style sheet set] with name `name`, run
these steps:

1. [enable a CSS style sheet
 set](#enable-a-css-style-sheet-set) with name `name`.
2. Set [last CSS style sheet set
 name](#last-css-style-sheet-set-name) to `name`.

A [last CSS style sheet set name] is a concept to determine what
[CSS style sheet
set](#css-style-sheet-set) was last
[selected](#select-a-css-style-sheet-set). Initially its value is null.

A [preferred CSS style sheet set
name] is a concept to determine which [CSS style
sheets](#css-style-sheet)
need to have their [disabled
flag](#concept-css-style-sheet-disabled-flag) unset. Initially its value is the empty string.

To [change the preferred CSS style sheet set
name] with name `name`, run these steps:

1. Let `current` be the [preferred CSS style sheet set
 name](#preferred-css-style-sheet-set-name).
2. Set [preferred CSS style sheet set
 name](#preferred-css-style-sheet-set-name) to `name`.
3. If `name` is not a
 [case-sensitive](https://w3c.github.io/i18n-glossary/#dfn-case-sensitive) match for `current` and [last CSS style
 sheet set
 name](#last-css-style-sheet-set-name) is null [enable a CSS style sheet
 set](#enable-a-css-style-sheet-set) with name `name`.

#### 6.2.1. The HTTP Default-Style Header

The HTTP
[Default-Style](#http-default-style) header can be used to set the [preferred CSS style
sheet set
name](#preferred-css-style-sheet-set-name) influencing which [CSS style sheet
set](#css-style-sheet-set) is (initially) the [enabled CSS style sheet
set](#enabled-css-style-sheet-set).

For each HTTP
[Default-Style](#http-default-style) header, in header order, the user agent must [change
the preferred CSS style sheet set
name](#change-the-preferred-css-style-sheet-set-name) with name being the value of the header.

#### 6.2.2. The [`StyleSheetList` Interface]
The [`StyleSheetList`](#stylesheetlist) interface represents an ordered collection of [CSS
style sheets](#css-style-sheet).

```
[Exposed=Window]
interface StyleSheetList {
 getter CSSStyleSheet? item(unsigned long index);
 readonly attribute unsigned long length;
};
```

The object's [supported property
indices](http://heycam.github.io/webidl/#dfn-supported-property-indices) are the numbers in the range zero to one less than the
number of [CSS style
sheets](#css-style-sheet)
represented by the collection. If there are no such [CSS style
sheets], then there are no [supported
property indices].

The [`item(``index``)`] method must return the `index`th [CSS style
sheet](#css-style-sheet) in
the collection. If there is no `index`th object in the
collection, then the method must return null.

The [`length`] attribute must
return the number of [CSS style
sheets](#css-style-sheet)
represented by the collection.

Tests

- [StyleSheetList-constructable-with-style-recalc.html](https://wpt.fyi/results/css/cssom/StyleSheetList-constructable-with-style-recalc.html "css/cssom/StyleSheetList-constructable-with-style-recalc.html")
 [[(live
 test)]](http://wpt.live/css/cssom/StyleSheetList-constructable-with-style-recalc.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/StyleSheetList-constructable-with-style-recalc.html)
- [StyleSheetList-constructable.html](https://wpt.fyi/results/css/cssom/StyleSheetList-constructable.html "css/cssom/StyleSheetList-constructable.html")
 [[(live
 test)]](http://wpt.live/css/cssom/StyleSheetList-constructable.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/StyleSheetList-constructable.html)
- [StyleSheetList.html](https://wpt.fyi/results/css/cssom/StyleSheetList.html "css/cssom/StyleSheetList.html")
 [[(live
 test)]](http://wpt.live/css/cssom/StyleSheetList.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/StyleSheetList.html)

#### [6.2.3. ][Extensions to the [`DocumentOrShadowRoot`](https://dom.spec.whatwg.org/#documentorshadowroot) Interface Mixin]
```
partial interface mixin DocumentOrShadowRoot {
 [SameObject] readonly attribute StyleSheetList styleSheets;
 attribute ObservableArray<CSSStyleSheet> adoptedStyleSheets;
};
```

The [`styleSheets`] attribute must return a
[`StyleSheetList`](#stylesheetlist) collection representing the [document or shadow root
CSS style
sheets](#documentorshadowroot-document-or-shadow-root-css-style-sheets).

The [set an indexed
value](https://webidl.spec.whatwg.org/#observable-array-attribute-set-an-indexed-value) algorithm for
[`adoptedStyleSheets`], given `value` and
`index`, is the following:

1. If `value`'s [constructed
 flag](#concept-css-style-sheet-constructed-flag) is not set, or its [constructor
 document](#concept-css-style-sheet-constructor-document) is not equal to this
 [`DocumentOrShadowRoot`](https://dom.spec.whatwg.org/#documentorshadowroot)'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document), throw a
 \"[`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

Tests

- [adoptedstylesheets-modify-array-and-sheet.html](https://wpt.fyi/results/css/cssom/adoptedstylesheets-modify-array-and-sheet.html "css/cssom/adoptedstylesheets-modify-array-and-sheet.html")
 [[(live
 test)]](http://wpt.live/css/cssom/adoptedstylesheets-modify-array-and-sheet.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/adoptedstylesheets-modify-array-and-sheet.html)
- [adoptedstylesheets-observablearray.html](https://wpt.fyi/results/css/cssom/adoptedstylesheets-observablearray.html "css/cssom/adoptedstylesheets-observablearray.html")
 [[(live
 test)]](http://wpt.live/css/cssom/adoptedstylesheets-observablearray.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/adoptedstylesheets-observablearray.html)
- [ttwf-cssom-doc-ext-load-count.html](https://wpt.fyi/results/css/cssom/ttwf-cssom-doc-ext-load-count.html "css/cssom/ttwf-cssom-doc-ext-load-count.html")
 [[(live
 test)]](http://wpt.live/css/cssom/ttwf-cssom-doc-ext-load-count.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/ttwf-cssom-doc-ext-load-count.html)
- [ttwf-cssom-doc-ext-load-tree-order.html](https://wpt.fyi/results/css/cssom/ttwf-cssom-doc-ext-load-tree-order.html "css/cssom/ttwf-cssom-doc-ext-load-tree-order.html")
 [[(live
 test)]](http://wpt.live/css/cssom/ttwf-cssom-doc-ext-load-tree-order.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/ttwf-cssom-doc-ext-load-tree-order.html)
- [ttwf-cssom-document-extension.html](https://wpt.fyi/results/css/cssom/ttwf-cssom-document-extension.html "css/cssom/ttwf-cssom-document-extension.html")
 [[(live
 test)]](http://wpt.live/css/cssom/ttwf-cssom-document-extension.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/ttwf-cssom-document-extension.html)

### 6.3. Style Sheet Association

This section defines the interface an [owner
node](#concept-css-style-sheet-owner-node) of a [CSS style
sheet](#css-style-sheet) has
to implement and defines the requirements for [xml-stylesheet processing
instructions](https://www.w3.org/TR/xml-stylesheet/#dt-xml-stylesheet) and HTTP `Link` headers when the link relation type is
an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"`stylesheet`\".

#### 6.3.1. Fetching CSS style sheets

To [fetch a CSS style sheet] with parsed URL `parsed URL`,
referrer `referrer`, document `document`,
optionally a set of parameters `parameters` (used as input to
creating a
[request](https://fetch.spec.whatwg.org/#concept-request)), and an algorithm for handling the response result
`processTheResponse` that takes a response, follow these
steps:

1. Let `origin` be `document`'s
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin).
2. Let `request` be a new
 [request](https://fetch.spec.whatwg.org/#concept-request), with the
 [url](https://fetch.spec.whatwg.org/#concept-request-url) `parsed URL`,
 [origin](https://fetch.spec.whatwg.org/#concept-request-origin) `origin`,
 [referrer](https://fetch.spec.whatwg.org/#concept-request-referrer) `referrer`, and if specified the set of
 parameters `parameters`.
3. [Fetch](https://fetch.spec.whatwg.org/#concept-fetch) `request`, with
 `processResponseEndOfBody`, given `response`,
 being the following steps:
 1. If `response` is a [network
 error](https://fetch.spec.whatwg.org/#concept-network-error), return.
 2. If `document` is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), `response` is
 [CORS-same-origin](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#cors-same-origin) and the [Content-Type
 metadata](https://html.spec.whatwg.org/multipage/infrastructure.html#content-type) of `response` is not a [supported
 styling
 language](#supported-styling-language) change the [Content-Type
 metadata] of `response` to
 `text/css`.
 3. If `response` is not in a [supported styling
 language](#supported-styling-language), return.
 4. Execute `processTheResponse` given
 `response`

#### 6.3.2. The [`LinkStyle` Interface]
The [associated CSS style sheet] of a node is the [CSS style
sheet](#css-style-sheet) in
the list of [document or shadow root CSS style
sheets](#documentorshadowroot-document-or-shadow-root-css-style-sheets) of which the [owner
node](#concept-css-style-sheet-owner-node) is said node. This node must also implement the
[`LinkStyle`](#linkstyle)
interface.

```
interface mixin LinkStyle {
 readonly attribute CSSStyleSheet? sheet;
};
```

The [`sheet`] attribute must
return the [associated CSS style
sheet](#associated-css-style-sheet) for the node or null if there is no [associated CSS
style sheet].

In the following fragment, the first
[`style`](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element) element has a
[`sheet`](#dom-linkstyle-sheet) attribute that returns a
[`StyleSheet`](#stylesheet)
object representing the style sheet, but for the second
[`style`](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element) element, the
[`sheet`](#dom-linkstyle-sheet) attribute returns null, assuming the user agent
supports CSS (`text/css`), but does not support the (hypothetical)
ExampleSheets (`text/example-sheets`).

 <style type="text/css">
 body { background:lime }
 </style>

 <style type="text/example-sheets">
 $(body).background := lime
 </style>

 Whether or not the node refers to a style sheet is
defined by the specification that defines the semantics of said node.

Tests

- [HTMLLinkElement-disabled-001.html](https://wpt.fyi/results/css/cssom/HTMLLinkElement-disabled-001.html "css/cssom/HTMLLinkElement-disabled-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom/HTMLLinkElement-disabled-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/HTMLLinkElement-disabled-001.html)
- [HTMLLinkElement-disabled-002.html](https://wpt.fyi/results/css/cssom/HTMLLinkElement-disabled-002.html "css/cssom/HTMLLinkElement-disabled-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom/HTMLLinkElement-disabled-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/HTMLLinkElement-disabled-002.html)
- [HTMLLinkElement-disabled-003.html](https://wpt.fyi/results/css/cssom/HTMLLinkElement-disabled-003.html "css/cssom/HTMLLinkElement-disabled-003.html")
 [[(live
 test)]](http://wpt.live/css/cssom/HTMLLinkElement-disabled-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/HTMLLinkElement-disabled-003.html)
- [HTMLLinkElement-disabled-004.html](https://wpt.fyi/results/css/cssom/HTMLLinkElement-disabled-004.html "css/cssom/HTMLLinkElement-disabled-004.html")
 [[(live
 test)]](http://wpt.live/css/cssom/HTMLLinkElement-disabled-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/HTMLLinkElement-disabled-004.html)
- [HTMLLinkElement-disabled-005.html](https://wpt.fyi/results/css/cssom/HTMLLinkElement-disabled-005.html "css/cssom/HTMLLinkElement-disabled-005.html")
 [[(live
 test)]](http://wpt.live/css/cssom/HTMLLinkElement-disabled-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/HTMLLinkElement-disabled-005.html)
- [HTMLLinkElement-disabled-006.html](https://wpt.fyi/results/css/cssom/HTMLLinkElement-disabled-006.html "css/cssom/HTMLLinkElement-disabled-006.html")
 [[(live
 test)]](http://wpt.live/css/cssom/HTMLLinkElement-disabled-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/HTMLLinkElement-disabled-006.html)
- [HTMLLinkElement-disabled-007.html](https://wpt.fyi/results/css/cssom/HTMLLinkElement-disabled-007.html "css/cssom/HTMLLinkElement-disabled-007.html")
 [[(live
 test)]](http://wpt.live/css/cssom/HTMLLinkElement-disabled-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/HTMLLinkElement-disabled-007.html)
- [HTMLLinkElement-disabled-alternate.html](https://wpt.fyi/results/css/cssom/HTMLLinkElement-disabled-alternate.html "css/cssom/HTMLLinkElement-disabled-alternate.html")
 [[(live
 test)]](http://wpt.live/css/cssom/HTMLLinkElement-disabled-alternate.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/HTMLLinkElement-disabled-alternate.html)
- [HTMLLinkElement-load-event-002.html](https://wpt.fyi/results/css/cssom/HTMLLinkElement-load-event-002.html "css/cssom/HTMLLinkElement-load-event-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom/HTMLLinkElement-load-event-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/HTMLLinkElement-load-event-002.html)
- [HTMLLinkElement-load-event.html](https://wpt.fyi/results/css/cssom/HTMLLinkElement-load-event.html "css/cssom/HTMLLinkElement-load-event.html")
 [[(live
 test)]](http://wpt.live/css/cssom/HTMLLinkElement-load-event.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/HTMLLinkElement-load-event.html)
- [HTMLStyleElement-load-event.html](https://wpt.fyi/results/css/cssom/HTMLStyleElement-load-event.html "css/cssom/HTMLStyleElement-load-event.html")
 [[(live
 test)]](http://wpt.live/css/cssom/HTMLStyleElement-load-event.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/HTMLStyleElement-load-event.html)

#### 6.3.3. Requirements on specifications

Specifications introducing new ways of associating style sheets through
the DOM should define which nodes implement the
[`LinkStyle`](#linkstyle)
interface. When doing so, they must also define when a [CSS style
sheet](#css-style-sheet) is
[created](#create-a-css-style-sheet).

#### 6.3.4. Requirements on user agents Implementing the xml-stylesheet processing instruction

```
ProcessingInstruction includes LinkStyle;
```

The [prolog]
refers to
[nodes](https://dom.spec.whatwg.org/#concept-node) that are children of the
[`Document`](https://dom.spec.whatwg.org/#document) and are not
[following](https://dom.spec.whatwg.org/#concept-tree-following) the
[`Element`](https://dom.spec.whatwg.org/#element) child of the
[`Document`](https://dom.spec.whatwg.org/#document), if any.

When a `ProcessingInstruction`
[node](https://dom.spec.whatwg.org/#boundary-point-node) `node` becomes part of the
[prolog](#prolog), is no longer part of
the [prolog], or has its
[data](https://dom.spec.whatwg.org/#concept-cd-data) changed, these steps must be run:

1. If an instance of this algorithm is currently running for
 `node`, abort that instance, and stop the associated
 [fetching](https://fetch.spec.whatwg.org/#concept-fetch) if applicable.
2. If `node` has an [associated CSS style
 sheet](#associated-css-style-sheet),
 [remove](#remove-a-css-style-sheet) it.
3. If `node` is not an [xml-stylesheet processing
 instruction](https://www.w3.org/TR/xml-stylesheet/#dt-xml-stylesheet), then return.
4. If `node` does not have an `href`
 [pseudo-attribute](https://www.w3.org/TR/xml-stylesheet/#dt-pseudo-attribute), then return.
5. Let `title` be the value of the `title`
 [pseudo-attribute](https://www.w3.org/TR/xml-stylesheet/#dt-pseudo-attribute) or the empty string if the `title`
 [pseudo-attribute] is not specified.
6. If there is an `alternate`
 [pseudo-attribute](https://www.w3.org/TR/xml-stylesheet/#dt-pseudo-attribute) whose value is a
 [case-sensitive](https://w3c.github.io/i18n-glossary/#dfn-case-sensitive) match for \"`yes`\" and `title` is the
 empty string, then return.
7. If there is a `type`
 [pseudo-attribute](https://www.w3.org/TR/xml-stylesheet/#dt-pseudo-attribute) whose value is not a [supported styling
 language](#supported-styling-language) the user agent may return.
8. Let `input URL` be the value specified by the `href`
 [pseudo-attribute](https://www.w3.org/TR/xml-stylesheet/#dt-pseudo-attribute).
9. Let `document` be `node`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)
10. Let `base URL` be `document`'s [document base
 URL](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#document-base-url).
11. Let `referrer` be `document`'s
 [address](https://dom.spec.whatwg.org/#concept-document-url).
12. Let `parsed URL` be the return value of invoking the [URL
 parser](https://url.spec.whatwg.org/#concept-url-parser) with the string `input URL` and the base
 URL `base URL`.
13. If `parsed URL` is failure, then return.
14. [Fetch a CSS style
 sheet](#fetch-a-css-style-sheet) with parsed URL `parsed URL`, referrer
 `referrer`, document `document`, and
 `processTheResponse` given `response` being
 the following steps:
 1. [Create a CSS style
 sheet](#create-a-css-style-sheet) with the following properties:

 [location](#concept-css-style-sheet-location)
 : The result of invoking the [URL
 serializer](https://url.spec.whatwg.org/#concept-url-serializer) with `parsed URL`.

 [parent CSS style sheet](#concept-css-style-sheet-parent-css-style-sheet)
 : null.

 [owner node](#concept-css-style-sheet-owner-node)
 : `node`.

 [owner CSS rule](#concept-css-style-sheet-owner-css-rule)
 : null.

 [media](#concept-css-style-sheet-media)
 : The value of the `media`
 [pseudo-attribute](https://www.w3.org/TR/xml-stylesheet/#dt-pseudo-attribute) if any, or the empty string otherwise.

 [title](#concept-css-style-sheet-title)
 : `title`.

 [alternate flag](#concept-css-style-sheet-alternate-flag)
 : Set if the `alternate`
 [pseudo-attribute](https://www.w3.org/TR/xml-stylesheet/#dt-pseudo-attribute) value is a
 [case-sensitive](https://w3c.github.io/i18n-glossary/#dfn-case-sensitive) match for \"`yes`\", or unset otherwise.

 [origin-clean flag](#concept-css-style-sheet-origin-clean-flag)
 : Set if `response` is
 [CORS-same-origin](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#cors-same-origin), or unset otherwise.

 The CSS [environment
 encoding](https://drafts.csswg.org/css-syntax-3/#environment-encoding) is the result of running the following steps:

 1. If the element has a `charset`
 [pseudo-attribute](https://www.w3.org/TR/xml-stylesheet/#dt-pseudo-attribute), [get an
 encoding](https://encoding.spec.whatwg.org/#concept-encoding-get) from that pseudo-attribute's value. If that
 succeeds, return the resulting encoding and abort these
 steps.
 2. Otherwise, return the [document's character
 encoding](https://dom.spec.whatwg.org/#concept-document-encoding).
 [\[DOM\]](#biblio-dom "DOM Standard")

#### 6.3.5. Requirements on user agents Implementing the HTTP Link Header

For each HTTP `Link` header of which one of the link relation types is
an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"`stylesheet`\" these steps must be run:

1. Let `title` be the value of the first of all the `title`
 parameters. If there are no such parameters it is the empty string.

2. If one of the (other) link relation types is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"`alternate`\" and `title` is
 the empty string, then return.

3. Let `input URL` be the value specified.

 (#issue-d4a93110) Be more specific

4. Let `base URL` be the document's [document base
 URL](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#document-base-url).

 (#issue-af048285) Is there a document at this point?

5. Let `referrer` be the document's
 [address](https://dom.spec.whatwg.org/#concept-document-url).

6. Let `parsed URL` be the return value of invoking the [URL
 parser](https://url.spec.whatwg.org/#concept-url-parser) with the string `input URL` and the base
 URL `base URL`.

7. If `parsed URL` is failure, then return.

8. [Fetch a CSS style
 sheet](#fetch-a-css-style-sheet) with parsed URL `parsed URL`, referrer
 `referrer`, document being the document, and
 `processTheResponse`, given `response`, being
 the following steps:

 (#issue-45012e41) What if the HTML parser hasn't
 decided on quirks/non-quirks yet?

 1. [Create a CSS style
 sheet](#create-a-css-style-sheet) with the following properties:

 [location](#concept-css-style-sheet-location)
 : The result of invoking the [URL
 serializer](https://url.spec.whatwg.org/#concept-url-serializer) with `parsed URL`.

 [owner node](#concept-css-style-sheet-owner-node)
 : null.

 [parent CSS style sheet](#concept-css-style-sheet-parent-css-style-sheet)
 : null.

 [owner CSS rule](#concept-css-style-sheet-owner-css-rule)
 : null.

 [media](#concept-css-style-sheet-media)
 : The value of the first `media` parameter.

 [title](#concept-css-style-sheet-title)
 : `title`.

 [alternate flag](#concept-css-style-sheet-alternate-flag)
 : Set if one of the specified link relation type for this HTTP
 `Link` header is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"`alternate`\", or false
 otherwise.

 [origin-clean flag](#concept-css-style-sheet-origin-clean-flag)
 : Set if `response` is
 [CORS-same-origin](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#cors-same-origin), or unset otherwise.

A style sheet referenced by a HTTP `Link` header using the rules in this
section is said to be [a style sheet that is blocking
scripts](https://html.spec.whatwg.org/multipage/semantics.html#a-style-sheet-that-is-blocking-scripts) if the style sheet was enabled when created, and the
user agent hasn't given up on that particular style sheet yet. A user
agent may give up on such a style sheet at any time.

### 6.4. CSS Rules

A [CSS rule] is an
abstract concept that denotes a rule as defined by the CSS
specification. A [CSS rule](#css-rule) is represented as an object that implements a subclass
of the [`CSSRule`](#cssrule)
interface, and which has the following associated state items:

[type]
: A non-negative integer associated with a particular type of rule.
 This item is initialized when a rule is created and cannot change.

[text]
: A text representation of the rule suitable for direct use in a style
 sheet. This item is initialized when a rule is created and can be
 changed.

[parent CSS rule]
: A reference to an enclosing [CSS rule](#css-rule) or null. If the rule has an enclosing rule when it
 is created, then this item is initialized to the enclosing rule;
 otherwise it is null. It can be changed to null.

[parent CSS style sheet]
: A reference to a parent [CSS style
 sheet](#css-style-sheet)
 or null. This item is initialized to reference an associated style
 sheet when the rule is created. It can be changed to null.

[child CSS rules]
: A list of child [CSS rules](#css-rule). The list can be mutated.

In addition to the above state, each [CSS
rule](#css-rule) may be associated
with other state in accordance with its
[type](#concept-css-rule-type).

To [parse a CSS rule] from a string `string`, run the following steps:

1. Let `rule` be the return value of invoking [parse a
 rule](https://drafts.csswg.org/css-syntax-3/#parse-a-rule) with `string`.
2. If `rule` is a syntax error, return `rule`.
3. Let `parsed rule` be the result of parsing
 `rule` according to the appropriate CSS specifications,
 dropping parts that are said to be ignored. If the whole
 `rule` is dropped, return a syntax error.
4. Return `parsed rule`.

To [serialize a CSS rule], perform one of the following in accordance
with the [CSS rule](#css-rule)'s
[type](#concept-css-rule-type):

[`CSSStyleRule`](#cssstylerule)
: Return the result of the following steps:
 1. Let `s` initially be the result of performing
 [serialize a group of
 selectors](#serialize-a-group-of-selectors) on the rule's associated selectors, followed by
 the string \"` {`\", i.e., a single SPACE (U+0020), followed by
 LEFT CURLY BRACKET (U+007B).
 2. Let `decls` be the result of performing [serialize a
 CSS declaration
 block](#serialize-a-css-declaration-block) on the rule's associated declarations, or null
 if there are no such declarations.
 3. Let `rules` be the result of performing [serialize a
 CSS rule](#serialize-a-css-rule) on each rule in the rule's
 [`cssRules`] list, or null if there are no
 such rules.
 4. If `decls` and `rules` are both null,
 append \" }\" to `s` (i.e. a single SPACE (U+0020)
 followed by RIGHT CURLY BRACKET (U+007D)) and return
 `s`.
 5. If `rules` is null:
 1. Append a single SPACE (U+0020) to `s`
 2. Append `decls` to `s`
 3. Append \" }\" to `s` (i.e. a single SPACE
 (U+0020) followed by RIGHT CURLY BRACKET (U+007D)).
 4. Return `s`.
 6. Otherwise:
 1. If `decls` is not null, prepend it to
 `rules`.
 2. For each `rule` in `rules`:
 - If `rule` is the empty string, do nothing.
 - Otherwise:
 1. Append a newline followed by two spaces to
 `s`.
 2. Append `rule` to `s`.
 3. Append a newline followed by RIGHT CURLY BRACKET (U+007D) to
 `s`.
 4. Return `s`.

[`CSSImportRule`](#cssimportrule)
: The result of concatenating the following:
 1. The string \"`@import`\" followed by a single SPACE (U+0020).
 2. The result of performing [serialize a
 URL](#serialize-a-url)
 on the rule's location.
 3. If the rule's associated media list is not empty, a single SPACE
 (U+0020) followed by the result of performing [serialize a media
 query
 list](#serialize-a-media-query-list) on the media list.
 4. The string \"`;`\", i.e., SEMICOLON (U+003B).

 :::
 (#example-844003e0)
 @import url("import.css");

 @import url("print.css") print;
 :::

[`CSSMediaRule`](https://drafts.csswg.org/css-conditional-3/#cssmediarule)
: The result of concatenating the following:
 1. The string \"`@media`\", followed by a single SPACE (U+0020).
 2. The result of performing [serialize a media query
 list](#serialize-a-media-query-list) on rule's media query list.
 3. A single SPACE (U+0020), followed by the string \"{\", i.e.,
 LEFT CURLY BRACKET (U+007B), followed by a newline.
 4. The result of performing [serialize a CSS
 rule](#serialize-a-css-rule) on each rule in the rule's
 [`cssRules`](#dom-cssgroupingrule-cssrules) list, filtering out empty strings, indenting
 each item with two spaces, all joined with newline.
 5. A newline, followed by the string \"}\", i.e., RIGHT CURLY
 BRACKET (U+007D)

[`CSSFontFaceRule`](https://drafts.csswg.org/css-fonts-5/#cssfontfacerule)

: The result of concatenating the following:

 1. The string \"`@font-face {`\".
 2. If the
 [font-family](https://drafts.csswg.org/css-fonts-4/#descdef-font-face-font-family) descriptor is present:
 1. A single SPACE (U+0020), followed by the string
 \"`font-family:`\", followed by a single SPACE (U+0020).
 2. The result of performing [serialize a
 string](#serialize-a-string) on the rule's font family name.
 3. The string \"`;`\", i.e., SEMICOLON (U+003B).
 3. If the rule's associated source list is not empty, follow these
 substeps:
 1. A single SPACE (U+0020), followed by the string \"`src:`\",
 followed by a single SPACE (U+0020).
 2. The result of invoking [serialize a comma-separated
 list](#serialize-a-comma-separated-list) on performing [serialize a
 URL](#serialize-a-url) or [serialize a
 LOCAL](#serialize-a-local) for each source on the source list.
 3. The string \"`;`\", i.e., SEMICOLON (U+003B).
 4. If rule's associated
 [unicode-range](https://drafts.csswg.org/css-fonts-4/#descdef-font-face-unicode-range) descriptor is present, a single
 SPACE (U+0020), followed by the string \"`unicode-range:`\",
 followed by a single SPACE (U+0020), followed by the result of
 performing serialize a
 [\<\'unicode-range\'\>], followed by the string \"`;`\", i.e., SEMICOLON
 (U+003B).
 5. If rule's associated
 [font-variant](https://drafts.csswg.org/css-fonts-4/#propdef-font-variant) descriptor is present, a
 single SPACE (U+0020), followed by the string
 \"`font-variant:`\", followed by a single SPACE (U+0020),
 followed by the result of performing serialize a
 [\<\'font-variant\'\>], followed by the string \"`;`\", i.e., SEMICOLON
 (U+003B).
 6. If rule's associated
 [font-feature-settings](https://drafts.csswg.org/css-fonts-4/#propdef-font-feature-settings) descriptor is present, a
 single SPACE (U+0020), followed by the string
 \"`font-feature-settings:`\", followed by a single SPACE
 (U+0020), followed by the result of performing serialize a
 [\<\'font-feature-settings\'\>], followed by the string \"`;`\", i.e., SEMICOLON
 (U+003B).
 7. If rule's associated
 [font-stretch](https://drafts.csswg.org/css-fonts-4/#propdef-font-stretch) descriptor is present, a
 single SPACE (U+0020), followed by the string
 \"`font-stretch:`\", followed by a single SPACE (U+0020),
 followed by the result of performing serialize a
 [\<\'font-stretch\'\>], followed by the string \"`;`\", i.e., SEMICOLON
 (U+003B).
 8. If rule's associated
 [font-weight](https://drafts.csswg.org/css-fonts-4/#propdef-font-weight) descriptor is present, a
 single SPACE (U+0020), followed by the string
 \"`font-weight:`\", followed by a single SPACE (U+0020),
 followed by the result of performing serialize a
 [\<\'font-weight\'\>], followed by the string \"`;`\", i.e., SEMICOLON
 (U+003B).
 9. If rule's associated
 [font-style](https://drafts.csswg.org/css-fonts-4/#propdef-font-style) descriptor is present, a
 single SPACE (U+0020), followed by the string \"`font-style:`\",
 followed by a single SPACE (U+0020), followed by the result of
 performing serialize a
 [\<\'font-style\'\>],
 followed by the string \"`;`\", i.e., SEMICOLON (U+003B).
 10. A single SPACE (U+0020), followed by the string \"}\", i.e.,
 RIGHT CURLY BRACKET (U+007D).

 (#issue-f92cf3b3) Need to define how the
 [`CSSFontFaceRule`](https://drafts.csswg.org/css-fonts-5/#cssfontfacerule) descriptors\' values are serialized.

[`CSSPageRule`](#csspagerule)

: (#issue-be6dc86c) Need to define how
 [`CSSPageRule`](#csspagerule) is serialized.

[`CSSNamespaceRule`](#cssnamespacerule)
: The literal string \"`@namespace`\", followed by a single SPACE
 (U+0020), followed by the [serialization as an
 identifier](#serialize-an-identifier) of the
 [`prefix`](#dom-cssnamespacerule-prefix) attribute (if any), followed by a single SPACE
 (U+0020) if there is a prefix, followed by the [serialization as
 URL](#serialize-a-url) of
 the
 [`namespaceURI`](#dom-cssnamespacerule-namespaceuri) attribute, followed the character \"`;`\" (U+003B).

[`CSSKeyframesRule`](https://drafts.csswg.org/css-animations-1/#csskeyframesrule)
: The result of concatenating the following:
 1. The literal string \"`@keyframes`\", followed by a single SPACE
 (U+0020).
 2. The serialization of the
 [`name`](https://drafts.csswg.org/css-animations-1/#dom-csskeyframesrule-name) attribute. If the attribute is a CSS wide
 keyword, or the value [default], or the value
 [none], then it is [serialized as a
 string](#serialize-a-string). Otherwise, it is [serialized as an
 identifier](#serialize-an-identifier).
 3. The string \"` { `\", i.e., a single SPACE (U+0020), followed by
 LEFT CURLY BRACKET (U+007B), followed by a single SPACE
 (U+0020).
 4. The result of performing [serialize a CSS
 rule](#serialize-a-css-rule) on each rule in the rule's
 [`cssRules`](https://drafts.csswg.org/css-animations-1/#dom-csskeyframesrule-cssrules) list, separated by a newline and indented by
 two spaces.
 5. A newline, followed by the string \"}\", i.e., RIGHT CURLY
 BRACKET (U+007D)

[`CSSKeyframeRule`](https://drafts.csswg.org/css-animations-1/#csskeyframerule)
: The result of concatenating the following:
 1. The
 [`keyText`](https://drafts.csswg.org/css-animations-1/#dom-csskeyframerule-keytext).
 2. The string \"` { `\", i.e., a single SPACE (U+0020), followed by
 LEFT CURLY BRACKET (U+007B), followed by a single SPACE
 (U+0020).
 3. The result of performing [serialize a CSS declaration
 block](#serialize-a-css-declaration-block) on the rule's associated declarations.
 4. If the rule is associated with one or more declarations, the
 string \"` `\", i.e., a single SPACE (U+0020).
 5. The string \"`}`\", RIGHT CURLY BRACKET (U+007D).

The \"indented by two spaces\" bit
matches browsers, but needs work, see
[#5494](https://github.com/w3c/csswg-drafts/issues/5494)

To [insert a CSS rule] `rule` in a CSS rule list
`list` at index `index`, with a flag
`nested`, follow these steps:

1. Set `length` to the number of items in `list`.

2. If `index` is greater than `length`, then
 [throw](http://heycam.github.io/webidl/#dfn-throw) an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception.

3. Set `new rule` to the results of performing [parse a CSS
 rule](#parse-a-css-rule)
 on argument `rule`.

4. If `new rule` is a syntax error, and `nested`
 is set, perform the following substeps:
 - Set `declarations` to the results of performing [parse
 a CSS declaration
 block](#parse-a-css-declaration-block), on argument `rule`.
 - If `declarations` is empty,
 [throw](http://heycam.github.io/webidl/#dfn-throw) a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror) exception.
 - Otherwise, set `new rule` to a new [nested declarations
 rule](https://drafts.csswg.org/css-nesting-1/#nested-declarations-rule) with `declarations` as it contents.

5. If `new rule` is a syntax error,
 [throw](http://heycam.github.io/webidl/#dfn-throw) a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror) exception.

6. If `new rule` cannot be inserted into `list`
 at the zero-indexed position `index` due to constraints
 specified by CSS, then
 [throw](http://heycam.github.io/webidl/#dfn-throw) a
 [`HierarchyRequestError`](https://webidl.spec.whatwg.org/#hierarchyrequesterror) exception.
 [\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")

 For example, a CSS style sheet cannot contain an
 `@import` at-rule after a style rule.

7. If `new rule` is an `@namespace` at-rule, and
 `list` contains anything other than `@import` at-rules,
 and `@namespace` at-rules,
 [throw](http://heycam.github.io/webidl/#dfn-throw) an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception.

8. Insert `new rule` into `list` at the
 zero-indexed position `index`.

9. Return `index`.

Tests

- [serialize-media-rule.html](https://wpt.fyi/results/css/cssom/serialize-media-rule.html "css/cssom/serialize-media-rule.html")
 [[(live
 test)]](http://wpt.live/css/cssom/serialize-media-rule.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/serialize-media-rule.html)

To [remove a CSS rule] from a CSS rule list `list` at
index `index`, follow these steps:

1. Set `length` to the number of items in `list`.
2. If `index` is greater than or equal to
 `length`, then
 [throw](http://heycam.github.io/webidl/#dfn-throw) an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception.
3. Set `old rule` to the `index`th item in
 `list`.
4. If `old rule` is an `@namespace` at-rule, and
 `list` contains anything other than `@import` at-rules,
 and `@namespace` at-rules,
 [throw](http://heycam.github.io/webidl/#dfn-throw) an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception.
5. Remove rule `old rule` from `list` at the
 zero-indexed position `index`.
6. Set `old rule`'s [parent CSS
 rule](#concept-css-rule-parent-css-rule) and [parent CSS style
 sheet](#concept-css-rule-parent-css-style-sheet) to null.

#### 6.4.1. The [`CSSRuleList` Interface]
The [`CSSRuleList`](#cssrulelist) interface represents an ordered collection of [CSS
rules](#concept-css-style-sheet-css-rules).

```
[Exposed=Window]
interface CSSRuleList {
 getter CSSRule? item(unsigned long index);
 readonly attribute unsigned long length;
};
```

Tests

- [CSSRuleList.html](https://wpt.fyi/results/css/cssom/CSSRuleList.html "css/cssom/CSSRuleList.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSRuleList.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSRuleList.html)

The object's [supported property
indices](http://heycam.github.io/webidl/#dfn-supported-property-indices) are the numbers in the range zero to one less than the
number of [`CSSRule`](#cssrule)
objects represented by the collection. If there are no such
[`CSSRule`](#cssrule) objects,
then there are no [supported property
indices].

The [`item(``index``)`] method must return the `index`th
[`CSSRule`](#cssrule) object in
the collection. If there is no `index`th object in the
collection, then the method must return null.

The [`length`] attribute must
return the number of [`CSSRule`](#cssrule) objects represented by the collection.

#### 6.4.2. The [`CSSRule` Interface]
The [`CSSRule`](#cssrule)
interface represents an abstract, base [CSS
rule](#css-rule). Each distinct CSS
rule type is represented by a distinct interface that inherits from this
interface.

```
[Exposed=Window]
interface CSSRule {
 attribute CSSOMString cssText;
 readonly attribute CSSRule? parentRule;
 readonly attribute CSSStyleSheet? parentStyleSheet;

 // the following attribute and constants are historical
 readonly attribute unsigned short type;
 const unsigned short STYLE_RULE = 1;
 const unsigned short CHARSET_RULE = 2;
 const unsigned short IMPORT_RULE = 3;
 const unsigned short MEDIA_RULE = 4;
 const unsigned short FONT_FACE_RULE = 5;
 const unsigned short PAGE_RULE = 6;
 const unsigned short MARGIN_RULE = 9;
 const unsigned short NAMESPACE_RULE = 10;
};
```

The [`cssText`] attribute must return
a [serialization](#serialize-a-css-rule) of the [CSS rule](#css-rule). On setting the
[`cssText`](#dom-cssrule-csstext) attribute must do nothing.

Tests

- [css-style-reparse.html](https://wpt.fyi/results/css/cssom/css-style-reparse.html "css/cssom/css-style-reparse.html")
 [[(live
 test)]](http://wpt.live/css/cssom/css-style-reparse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/css-style-reparse.html)
- [cssom-cssText-serialize.html](https://wpt.fyi/results/css/cssom/cssom-cssText-serialize.html "css/cssom/cssom-cssText-serialize.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssom-cssText-serialize.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssom-cssText-serialize.html)
- [cssom-ruleTypeAndOrder.html](https://wpt.fyi/results/css/cssom/cssom-ruleTypeAndOrder.html "css/cssom/cssom-ruleTypeAndOrder.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssom-ruleTypeAndOrder.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssom-ruleTypeAndOrder.html)
- [declaration-block-all-crash.html](https://wpt.fyi/results/css/cssom/declaration-block-all-crash.html "css/cssom/declaration-block-all-crash.html")
 [[(live
 test)]](http://wpt.live/css/cssom/declaration-block-all-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/declaration-block-all-crash.html)

The [`parentRule`] attribute must return
the [parent CSS
rule](#concept-css-rule-parent-css-rule).

 For example, `@media` can enclose a rule, in which case
[`parentRule`](#dom-cssrule-parentrule) would be non-null; in cases where there is no enclosing
rule,
[`parentRule`](#dom-cssrule-parentrule) will be null.

The [`parentStyleSheet`] attribute
must return the [parent CSS style
sheet](#concept-css-rule-parent-css-style-sheet).

 The only circumstance where null is returned when a
rule has been [removed](#remove-a-css-rule).

 Removing a `Node` that implements the `LinkStyle`
interface from a
[`Document`](https://dom.spec.whatwg.org/#document) instance does not (by itself) cause the `CSSStyleSheet`
referenced by a `CSSRule` to be unreachable.

The [`type`] attribute is
deprecated. It must return an integer, as follows:

If the object is a [`CSSStyleRule`](#cssstylerule)
: Return 1.

If the object is a [`CSSImportRule`](#cssimportrule)
: Return 3.

If the object is a [`CSSMediaRule`](https://drafts.csswg.org/css-conditional-3/#cssmediarule)
: Return 4.

If the object is a [`CSSFontFaceRule`](https://drafts.csswg.org/css-fonts-5/#cssfontfacerule)
: Return 5.

If the object is a [`CSSPageRule`](#csspagerule)
: Return 6.

If the object is a [`CSSKeyframesRule`](https://drafts.csswg.org/css-animations-1/#csskeyframesrule)
: Return 7.

If the object is a [`CSSKeyframeRule`](https://drafts.csswg.org/css-animations-1/#csskeyframerule)
: Return 8.

If the object is a [`CSSMarginRule`](#cssmarginrule)
: Return 9.

If the object is a [`CSSNamespaceRule`](#cssnamespacerule)
: Return 10.

If the object is a [`CSSCounterStyleRule`](https://drafts.csswg.org/css-counter-styles-3/#csscounterstylerule)
: Return 11.

If the object is a [`CSSSupportsRule`](https://drafts.csswg.org/css-conditional-3/#csssupportsrule)
: Return 12.

If the object is a [`CSSFontFeatureValuesRule`](https://drafts.csswg.org/css-fonts-4/#om-fontfeaturevalues)
: Return 14.

Otherwise
: Return 0.

 The practice of using an integer enumeration and
several constants to *identify* the integers is a legacy design practice
that is no longer used in Web APIs. Instead, to tell what type of rule a
given object is, it is recommended to check
`rule.constructor.name`, which will return a string like
`"CSSStyleRule"`. This enumeration is thus frozen in its
current state, and no new new values will be added to reflect additional
at-rules; all at-rules beyond the ones listed above will return 0.

#### 6.4.3. The [`CSSStyleRule` Interface]
The `CSSStyleRule` interface represents a style rule.

```
[Exposed=Window]
interface CSSStyleRule : CSSGroupingRule {
 attribute CSSOMString selectorText;
 [SameObject, PutForwards=cssText] readonly attribute CSSStyleProperties style;
};
```

The [`selectorText`]
attribute, on getting, must return the result of
[serializing](#serialize-a-group-of-selectors) the rule's associated [selector
list](https://drafts.csswg.org/selectors-4/#selector-list). On setting the
[`selectorText`](#dom-cssstylerule-selectortext) attribute these steps must be run:

1. Run the [parse a group of
 selectors](#parse-a-group-of-selectors) algorithm on the given value.
2. If the algorithm returns a non-null value replace the associated
 [selector
 list](https://drafts.csswg.org/selectors-4/#selector-list) with the returned value.
3. Otherwise, if the algorithm returns a null value, do nothing.

Tests

- [CSSStyleRule.html](https://wpt.fyi/results/css/cssom/CSSStyleRule.html "css/cssom/CSSStyleRule.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleRule.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleRule.html)
- [CSSStyleRule-set-selectorText.html](https://wpt.fyi/results/css/cssom/CSSStyleRule-set-selectorText.html "css/cssom/CSSStyleRule-set-selectorText.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleRule-set-selectorText.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleRule-set-selectorText.html)
- [CSSStyleRule-set-selectorText-namespace.html](https://wpt.fyi/results/css/cssom/CSSStyleRule-set-selectorText-namespace.html "css/cssom/CSSStyleRule-set-selectorText-namespace.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSStyleRule-set-selectorText-namespace.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSStyleRule-set-selectorText-namespace.html)
- [selectorText-modification-restyle-001.html](https://wpt.fyi/results/css/cssom/selectorText-modification-restyle-001.html "css/cssom/selectorText-modification-restyle-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom/selectorText-modification-restyle-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/selectorText-modification-restyle-001.html)
- [selectorText-modification-restyle-002.html](https://wpt.fyi/results/css/cssom/selectorText-modification-restyle-002.html "css/cssom/selectorText-modification-restyle-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom/selectorText-modification-restyle-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/selectorText-modification-restyle-002.html)
- [set-selector-text-attachment.html](https://wpt.fyi/results/css/cssom/set-selector-text-attachment.html "css/cssom/set-selector-text-attachment.html")
 [[(live
 test)]](http://wpt.live/css/cssom/set-selector-text-attachment.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/set-selector-text-attachment.html)

The [`style`] attribute must
return a
[`CSSStyleProperties`](#cssstyleproperties) object for the style rule, with the following
properties:

[computed flag](#cssstyledeclaration-computed-flag)
: Unset.

[readonly flag](#cssstyledeclaration-readonly-flag)
: Unset.

[declarations](#cssstyledeclaration-declarations)
: The declared declarations in the rule, in [specified
 order](#concept-declarations-specified-order).

[parent CSS rule](#cssstyledeclaration-parent-css-rule)
: [this](https://webidl.spec.whatwg.org/#this).

[owner node](#cssstyledeclaration-owner-node)
: Null.

The [specified order] for declarations is the same as
specified, but with shorthand properties expanded into their longhand
properties, in canonical order. If a property is specified more than
once (after shorthand expansion), only the one with greatest cascading
order must be represented, at the same relative position as it was
specified.
[\[CSS3CASCADE\]](#biblio-css3cascade "CSS Cascading and Inheritance Level 3")

#### 6.4.4. The [`CSSImportRule` Interface]
The `CSSImportRule` interface represents an `@import` at-rule.

```
[Exposed=Window]
interface CSSImportRule : CSSRule {
 readonly attribute USVString href;
 [SameObject, PutForwards=mediaText] readonly attribute MediaList media;
 [SameObject] readonly attribute CSSStyleSheet? styleSheet;
 readonly attribute CSSOMString? layerName;
 readonly attribute CSSOMString? supportsText;
};
```

The [`href`] attribute must
return the
[URL](https://url.spec.whatwg.org/#concept-url) specified by the `@import` at-rule.

 To get the resolved
[URL](https://url.spec.whatwg.org/#concept-url) use the
[`href`](#dom-stylesheet-href) attribute of the associated [CSS style
sheet](#css-style-sheet).

The [`media`] attribute must
return the value of the
[`media`](#dom-stylesheet-media) attribute of the associated [CSS style
sheet](#css-style-sheet).

The [`styleSheet`]
attribute must return the associated [CSS style
sheet](#css-style-sheet), if
any, or null otherwise.

The [`layerName`]
attribute must return the [layer
name](https://drafts.csswg.org/css-cascade-5/#layer-name) declared in the at-rule itself, or an empty string if
the layer is anonymous, or null if the at-rule does not declare a layer.

The [`supportsText`]
attribute must return the
[\<supports-condition\>](https://drafts.csswg.org/css-conditional-3/#typedef-supports-condition) declared in the at-rule itself, or
null if the at-rule does not declare a supports condition.

 An `@import` at-rule might not have an associated [CSS
style sheet](#css-style-sheet) (e.g., if it has a non-matching `supports()`
condition).

Tests

- [cssimportrule.html](https://wpt.fyi/results/css/cssom/cssimportrule.html "css/cssom/cssimportrule.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssimportrule.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssimportrule.html)
- [cssimportrule-parent.html](https://wpt.fyi/results/css/cssom/cssimportrule-parent.html "css/cssom/cssimportrule-parent.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssimportrule-parent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssimportrule-parent.html)
- [cssimportrule-sheet-identity.html](https://wpt.fyi/results/css/cssom/cssimportrule-sheet-identity.html "css/cssom/cssimportrule-sheet-identity.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssimportrule-sheet-identity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssimportrule-sheet-identity.html)

#### 6.4.5. The [`CSSGroupingRule` Interface]
The `CSSGroupingRule` interface represents an at-rule that contains
other rules nested inside itself.

```
[Exposed=Window]
interface CSSGroupingRule : CSSRule {
 [SameObject] readonly attribute CSSRuleList cssRules;
 unsigned long insertRule(CSSOMString rule, optional unsigned long index = 0);
 undefined deleteRule(unsigned long index);
};
```

The [`cssRules`]
attribute must return a `CSSRuleList` object for the [child CSS
rules](#concept-css-rule-child-css-rules).

The
[`insertRule(``rule``, ``index``)`] method must
return the result of invoking [insert a CSS
rule](#insert-a-css-rule)
`rule` into the [child CSS
rules](#concept-css-rule-child-css-rules) at `index`, with the `nested`
flag set.

The [`deleteRule(``index``)`] method must [remove a CSS
rule](#remove-a-css-rule)
from the [child CSS
rules](#concept-css-rule-child-css-rules) at `index`.

Tests

- [CSSGroupingRule-cssRules.html](https://wpt.fyi/results/css/cssom/CSSGroupingRule-cssRules.html "css/cssom/CSSGroupingRule-cssRules.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSGroupingRule-cssRules.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSGroupingRule-cssRules.html)
- [CSSGroupingRule-insertRule.html](https://wpt.fyi/results/css/cssom/CSSGroupingRule-insertRule.html "css/cssom/CSSGroupingRule-insertRule.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSGroupingRule-insertRule.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSGroupingRule-insertRule.html)

#### [6.4.6. ][The [`CSSMediaRule`](https://drafts.csswg.org/css-conditional-3/#cssmediarule) Interface]
The
[`CSSMediaRule`](https://drafts.csswg.org/css-conditional-3/#cssmediarule) interface is defined in CSS Conditional Rules.
[\[CSS3-CONDITIONAL\]](#biblio-css3-conditional "CSS Conditional Rules Module Level 3")

#### 6.4.7. The [`CSSPageRule` Interface]
The `CSSPageRule` interface represents an `@page` at-rule.

Need to define the rules for [parse a
list of CSS page selectors] and [serialize a list of CSS page
selectors].

```
[Exposed=Window]
interface CSSPageDescriptors : CSSStyleDeclaration {
 attribute [LegacyNullToEmptyString] CSSOMString margin;
 attribute [LegacyNullToEmptyString] CSSOMString marginTop;
 attribute [LegacyNullToEmptyString] CSSOMString marginRight;
 attribute [LegacyNullToEmptyString] CSSOMString marginBottom;
 attribute [LegacyNullToEmptyString] CSSOMString marginLeft;
 attribute [LegacyNullToEmptyString] CSSOMString margin-top;
 attribute [LegacyNullToEmptyString] CSSOMString margin-right;
 attribute [LegacyNullToEmptyString] CSSOMString margin-bottom;
 attribute [LegacyNullToEmptyString] CSSOMString margin-left;
 attribute [LegacyNullToEmptyString] CSSOMString size;
 attribute [LegacyNullToEmptyString] CSSOMString pageOrientation;
 attribute [LegacyNullToEmptyString] CSSOMString page-orientation;
 attribute [LegacyNullToEmptyString] CSSOMString marks;
 attribute [LegacyNullToEmptyString] CSSOMString bleed;
};

[Exposed=Window]
interface CSSPageRule : CSSGroupingRule {
 attribute CSSOMString selectorText;
 [SameObject, PutForwards=cssText] readonly attribute CSSPageDescriptors style;
};
```

The [`selectorText`]
attribute, on getting, must return the result of
[serializing](#serialize-a-list-of-css-page-selectors) the associated [selector
list](https://drafts.csswg.org/selectors-4/#selector-list). On setting the
[`selectorText`](#dom-csspagerule-selectortext) attribute these steps must be run:

1. Run the [parse a list of CSS page
 selectors](#parse-a-list-of-css-page-selectors) algorithm on the given value.
2. If the algorithm returns a non-null value replace the associated
 [selector
 list](https://drafts.csswg.org/selectors-4/#selector-list) with the returned value.
3. Otherwise, if the algorithm returns a null value, do nothing.

The [`style`] attribute must
return a `CSSPageDescriptors` object for the `@page` at-rule, with the
following properties:

[computed flag](#cssstyledeclaration-computed-flag)
: Unset.

[readonly flag](#cssstyledeclaration-readonly-flag)
: Unset.

[declarations](#cssstyledeclaration-declarations)
: The declared descriptors in the rule, in [specified
 order](#concept-declarations-specified-order).

[parent CSS rule](#cssstyledeclaration-parent-css-rule)
: [this](https://webidl.spec.whatwg.org/#this).

[owner node](#cssstyledeclaration-owner-node)
: Null.

Tests

- [cssom-pagerule.html](https://wpt.fyi/results/css/cssom/cssom-pagerule.html "css/cssom/cssom-pagerule.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssom-pagerule.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssom-pagerule.html)

#### 6.4.8. The [`CSSMarginRule` Interface]
The `CSSMarginRule` interface represents a margin at-rule (e.g.
`@top-left`) in an `@page` at-rule.
[\[CSS3PAGE\]](#biblio-css3page "CSS Paged Media Module Level 3")

```
[Exposed=Window]
interface CSSMarginRule : CSSRule {
 readonly attribute CSSOMString name;
 [SameObject, PutForwards=cssText] readonly attribute CSSMarginDescriptors style;
};
```

The [`name`] attribute must
return the name of the margin at-rule. The `@` character is not included
in the name.
[\[CSS3SYN\]](#biblio-css3syn "CSS Syntax Module Level 3")

The [`style`] attribute must
return a `CSSMarginDescriptors` object for the margin at-rule, with the
following properties:

[computed flag](#cssstyledeclaration-computed-flag)
: Unset.

[readonly flag](#cssstyledeclaration-readonly-flag)
: Unset.

[declarations](#cssstyledeclaration-declarations)
: The declared declarations in the rule, in [specified
 order](#concept-declarations-specified-order).

[parent CSS rule](#cssstyledeclaration-parent-css-rule)
: [this](https://webidl.spec.whatwg.org/#this).

[owner node](#cssstyledeclaration-owner-node)
: Null.

#### 6.4.9. The [`CSSNamespaceRule` Interface]
The `CSSNamespaceRule` interface represents an `@namespace` at-rule.

```
[Exposed=Window]
interface CSSNamespaceRule : CSSRule {
 readonly attribute CSSOMString namespaceURI;
 readonly attribute CSSOMString prefix;
};
```

The [`namespaceURI`] attribute must return the namespace of the `@namespace`
at-rule.

The [`prefix`] attribute
must return the prefix of the `@namespace` at-rule or the empty string
if there is no prefix.

Tests

- [at-namespace.html](https://wpt.fyi/results/css/cssom/at-namespace.html "css/cssom/at-namespace.html")
 [[(live
 test)]](http://wpt.live/css/cssom/at-namespace.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/at-namespace.html)
- [CSSNamespaceRule.html](https://wpt.fyi/results/css/cssom/CSSNamespaceRule.html "css/cssom/CSSNamespaceRule.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSSNamespaceRule.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSSNamespaceRule.html)

### 6.5. CSS Declarations

A [CSS declaration] is an abstract concept that is not exposed as an object in
the DOM. A [CSS declaration](#css-declaration) has the following associated properties:

[property name]
: The property name of the declaration.

[value]
: The value of the declaration represented as a list of component
 values.

[important flag]
: Either set or unset. Can be changed.

[case-sensitive flag]
: Set if the [property
 name](#css-declaration-property-name) is defined to be case-sensitive according to its
 specification, otherwise unset.

### 6.6. CSS Declaration Blocks

A [CSS declaration block] is an ordered collection of CSS properties
with their associated values, also named [CSS
declarations](#css-declaration). In the DOM a [CSS declaration
block](#css-declaration-block) is a `CSSStyleDeclaration` object. A [CSS declaration
block] has the following associated
properties:

[computed flag]
: Set if the object is a computed style declaration, rather than a
 specified style. Unless otherwise stated it is unset.

[readonly flag]
: Set if the object is not modifiable.

[declarations]
: The [CSS declarations](#css-declaration) associated with the object.

[parent CSS rule]
: The [CSS rule](#css-rule) that
 the [CSS declaration
 block](#css-declaration-block) is associated with, if any, or null otherwise.

[owner node]
: The
 [`Element`](https://dom.spec.whatwg.org/#element) that the [CSS declaration
 block](#css-declaration-block) is associated with, if any, or null otherwise.

[updating flag]
: Unset by default. Set when the [CSS declaration
 block](#css-declaration-block) is updating the [owner
 node](#cssstyledeclaration-owner-node)'s `style` attribute.

To [parse a CSS declaration block] from a string
`string`, follow these steps:

1. Let `declarations` be the returned declarations from
 invoking [parse a block's
 contents](https://drafts.csswg.org/css-syntax-3/#parse-a-blocks-contents) with `string`.
2. Let `parsed declarations` be a new empty list.
3. For each item `declaration` in `declarations`,
 follow these substeps:
 1. Let `parsed declaration` be the result of parsing
 `declaration` according to the appropriate CSS
 specifications, dropping parts that are said to be ignored. If
 the whole declaration is dropped, let
 `parsed declaration` be null.
 2. If `parsed declaration` is not null, append it to
 `parsed declarations`.
4. Return `parsed declarations`.

To [serialize a CSS declaration] with property name
`property`, value `value` and optionally an
*important* flag set, follow these steps:

1. Let `s` be the empty string.
2. Append `property` to `s`.
3. Append \"`: `\" (U+003A U+0020) to `s`.
4. If `value` contains any non-whitespace characters, append
 `value` to `s`.
5. If the *important* flag is set, append \"` !important`\" (U+0020
 U+0021 U+0069 U+006D U+0070 U+006F U+0072 U+0074 U+0061 U+006E
 U+0074) to `s`.
6. Append \"`;`\" (U+003B) to `s`.
7. Return `s`.

Tests

- [serialization-CSSDeclaration-with-important.html](https://wpt.fyi/results/css/cssom/serialization-CSSDeclaration-with-important.html "css/cssom/serialization-CSSDeclaration-with-important.html")
 [[(live
 test)]](http://wpt.live/css/cssom/serialization-CSSDeclaration-with-important.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/serialization-CSSDeclaration-with-important.html)

To [serialize a CSS declaration
block] `declaration block`, run the
following steps. It will return a
[string](https://infra.spec.whatwg.org/#string) representing the serialization of all the declarations
in `declaration block`.

1. Let `serialized props` initially be the empty
 [list](https://infra.spec.whatwg.org/#list).

2. Let `already serialized` initially be the empty
 [set](#set).

3. Let `decls` be `declaration block`'s
 [declarations](#cssstyledeclaration-declarations).

4. For each [CSS
 declaration](#css-declaration) `decl` in `decls`:

 1. Let `name` be `decl`'s [property
 name](#css-declaration-property-name).

 2. If `name` is in `already serialized`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. Attempt to [serialize into a shorthand
 form](#serialize-into-a-shorthand-form) `name`, given `decls` and
 `already serialized`. If this returns a string,
 [append](https://infra.spec.whatwg.org/#list-append) it to `serialized props` and
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 4. Otherwise, [serialize a CSS
 declaration](#serialize-a-css-declaration) with property name `name`, value the
 result of [serializing a CSS
 value](#serialize-a-css-value) from `decl`, and the [important
 flag](#css-declaration-important-flag) set if `decl` has it set.
 [Append](https://infra.spec.whatwg.org/#list-append) the result to `serialized props`.

 5. [Append](https://infra.spec.whatwg.org/#set-append) `name` to
 `already serialized`.

5. Return the result of
 [concatenating](https://infra.spec.whatwg.org/#string-concatenate) `serialized props`, with separator
 \"` `\" (U+0020 SPACE).

To [serialize into a shorthand form] a property
`property`, given a
[list](https://infra.spec.whatwg.org/#list) of [CSS
declarations](#css-declaration) `decls` and a [set](#set) of already-serialized declarations
`already serialized`, run the following steps. It will return
either a
[string](https://infra.spec.whatwg.org/#string) representing the serialization of a shorthand that
`property` is part of, or
[failure](https://infra.spec.whatwg.org/#failure), and will mutate `already serialized`.

1. Let `possible shorthands` be a list of shorthand
 declaration names that `property` is a longhand for, in
 [preferred shorthand
 order](#concept-shorthands-preferred-order).

2. [For each] `shorthand` in
 `possible shorthands`:

 1. Let `needed longhand names` be the names of the
 longhands that `shorthand` maps to.

 2. If any of `needed longhand names` is not in
 `decls`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. If any of `needed longhand names` is in
 `already serialized`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 4. Let `used longhands` be the declarations from
 `decls` corresponding to the property names in
 `needed longhand names`.

 5. If there is at least one declaration in
 `used longhands` with its [important
 flag](#css-declaration-important-flag) set, and at least one without it set,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 6. If any of the [intermixed
 properties](#intermixed-properties) in `decls` between
 `used longhands` belong to the same [logical property
 group](https://drafts.csswg.org/css-logical-1/#logical-property-group) as a longhand in `used longhands`
 but have a different [mapping
 logic](https://drafts.csswg.org/css-logical-1/#mapping-logic), and are not in `used longhands`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 7. [Serialize a CSS
 value](#serialize-a-css-value) with `used longhands`, and let
 `value` be the result.

 8. If `value` is the empty string,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 9. [Append](https://infra.spec.whatwg.org/#set-append) the property names of all the items in
 `used longhands` to `already serialized`.

 10. [Serialize a CSS
 declaration](#serialize-a-css-declaration) with property name `shorthand`,
 value `value`, and the [important
 flag](#css-declaration-important-flag) set if all the `used longhands` have
 it set. Return the result.

3. Return
 [failure](https://infra.spec.whatwg.org/#failure).

To get a list of [intermixed properties] in a list of declarations
`decls` between a set of properties `props`:

1. Find the first and last declarations in `decls` that
 belong to `props`.

2. Return the slice of `decls` between (and including) those
 two declarations.

 The serialization of an empty CSS declaration block is
the empty string.

 The serialization of a non-empty CSS declaration block
does not include any surrounding whitespace, i.e., no whitespace appears
before the first property name and no whitespace appears after the final
semicolon delimiter that follows the last property value.

Tests

- [border-shorthand-serialization.html](https://wpt.fyi/results/css/cssom/border-shorthand-serialization.html "css/cssom/border-shorthand-serialization.html")
 [[(live
 test)]](http://wpt.live/css/cssom/border-shorthand-serialization.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/border-shorthand-serialization.html)
- [css-style-attr-decl-block.html](https://wpt.fyi/results/css/cssom/css-style-attr-decl-block.html "css/cssom/css-style-attr-decl-block.html")
 [[(live
 test)]](http://wpt.live/css/cssom/css-style-attr-decl-block.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/css-style-attr-decl-block.html)
- [font-family-serialization-001.html](https://wpt.fyi/results/css/cssom/font-family-serialization-001.html "css/cssom/font-family-serialization-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom/font-family-serialization-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/font-family-serialization-001.html)
- [font-shorthand-serialization.html](https://wpt.fyi/results/css/cssom/font-shorthand-serialization.html "css/cssom/font-shorthand-serialization.html")
 [[(live
 test)]](http://wpt.live/css/cssom/font-shorthand-serialization.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/font-shorthand-serialization.html)
- [font-variant-shorthand-serialization.html](https://wpt.fyi/results/css/cssom/font-variant-shorthand-serialization.html "css/cssom/font-variant-shorthand-serialization.html")
 [[(live
 test)]](http://wpt.live/css/cssom/font-variant-shorthand-serialization.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/font-variant-shorthand-serialization.html)
- [shorthand-serialization.html](https://wpt.fyi/results/css/cssom/shorthand-serialization.html "css/cssom/shorthand-serialization.html")
 [[(live
 test)]](http://wpt.live/css/cssom/shorthand-serialization.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/shorthand-serialization.html)
- [shorthand-values.html](https://wpt.fyi/results/css/cssom/shorthand-values.html "css/cssom/shorthand-values.html")
 [[(live
 test)]](http://wpt.live/css/cssom/shorthand-values.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/shorthand-values.html)

A [CSS declaration
block](#css-declaration-block) has these [attribute change
steps](https://dom.spec.whatwg.org/#concept-element-attributes-change-ext) for its [owner
node](#cssstyledeclaration-owner-node) with `localName`, `value`, and
`namespace`:

1. If the [computed
 flag](#cssstyledeclaration-computed-flag) is set, then return.
2. If the [updating
 flag](#cssstyledeclaration-updating-flag) is set, then return.
3. If `localName` is not \"`style`\", or
 `namespace` is not null, then return.
4. If `value` is null, empty the
 [declarations](#cssstyledeclaration-declarations).
5. Otherwise, let the
 [declarations](#cssstyledeclaration-declarations) be the result of [parse a CSS declaration
 block](#parse-a-css-declaration-block) from a string `value`.

When a [CSS declaration
block](#css-declaration-block) object is created, then:

1. Let `owner node` be the [owner
 node](#cssstyledeclaration-owner-node).
2. If `owner node` is null, or the [computed
 flag](#cssstyledeclaration-computed-flag) is set, then return.
3. Let `value` be the result of [getting an
 attribute](https://dom.spec.whatwg.org/#concept-element-attributes-get-by-namespace) given null, \"`style`\", and
 `owner node`.
4. If `value` is not null, let the
 [declarations](#cssstyledeclaration-declarations) be the result of [parse a CSS declaration
 block](#parse-a-css-declaration-block) from a string `value`.

To [update style attribute for] `declaration block`
means to run the steps below:

1. Assert: `declaration block`'s [computed
 flag](#cssstyledeclaration-computed-flag) is unset.
2. Let `owner node` be `declaration block`'s
 [owner
 node](#cssstyledeclaration-owner-node).
3. If `owner node` is null, then return.
4. Set `declaration block`'s [updating
 flag](#cssstyledeclaration-updating-flag).
5. [Set an attribute
 value](https://dom.spec.whatwg.org/#concept-element-attributes-set-value) for `owner node` using \"`style`\" and
 the result of
 [serializing](#serialize-a-css-declaration-block) `declaration block`.
6. Unset `declaration block`'s [updating
 flag](#cssstyledeclaration-updating-flag).

The [preferred shorthand order] of a list of shorthand properties
`shorthands` is as follows:

1. Order `shorthands` lexicographically.

2. Remove all items in `shorthands` that are [legacy
 shorthands](https://drafts.csswg.org/css-cascade-5/#legacy-shorthand) but do not begin with \"`-`\" (U+002D).

3. Move all items in `shorthands` that begin with
 \"`-webkit-`\" (U+002D) last in the list, retaining their relative
 order.

4. Move all items in `shorthands` that begin with \"`-`\"
 (U+002D) but do not begin with \"`-webkit-`\" last in the list,
 retaining their relative order.

5. Order `shorthands` by the number of longhand properties
 that map to it, with the greatest number first,

retaining their relative order.

#### 6.6.1. The [`CSSStyleDeclaration` Interface]
The `CSSStyleDeclaration` interface represents a [CSS declaration
block](#css-declaration-block), including its underlying state, where this underlying
state depends upon the source of the `CSSStyleDeclaration` instance.

```
[Exposed=Window]
interface CSSStyleDeclaration {
 [CEReactions] attribute CSSOMString cssText;
 readonly attribute unsigned long length;
 getter CSSOMString item(unsigned long index);
 CSSOMString getPropertyValue(CSSOMString property);
 CSSOMString getPropertyPriority(CSSOMString property);
 [CEReactions] undefined setProperty(CSSOMString property, [LegacyNullToEmptyString] CSSOMString value, optional [LegacyNullToEmptyString] CSSOMString priority = "");
 [CEReactions] CSSOMString removeProperty(CSSOMString property);
 readonly attribute CSSRule? parentRule;
};

[Exposed=Window]
interface CSSStyleProperties : CSSStyleDeclaration {
 [CEReactions] attribute [LegacyNullToEmptyString] CSSOMString cssFloat;
};
```

Tests

- [css-style-declaration-modifications.html](https://wpt.fyi/results/css/cssom/css-style-declaration-modifications.html "css/cssom/css-style-declaration-modifications.html")
 [[(live
 test)]](http://wpt.live/css/cssom/css-style-declaration-modifications.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/css-style-declaration-modifications.html)
- [cssom-cssstyledeclaration-set.html](https://wpt.fyi/results/css/cssom/cssom-cssstyledeclaration-set.html "css/cssom/cssom-cssstyledeclaration-set.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssom-cssstyledeclaration-set.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssom-cssstyledeclaration-set.html)
- [cssstyledeclaration-all-shorthand.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-all-shorthand.html "css/cssom/cssstyledeclaration-all-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-all-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-all-shorthand.html)
- [cssstyledeclaration-cssfontrule.tentative.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-cssfontrule.tentative.html "css/cssom/cssstyledeclaration-cssfontrule.tentative.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-cssfontrule.tentative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-cssfontrule.tentative.html)
- [cssstyledeclaration-csstext-all-shorthand.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-csstext-all-shorthand.html "css/cssom/cssstyledeclaration-csstext-all-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-csstext-all-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-csstext-all-shorthand.html)
- [cssstyledeclaration-csstext-final-delimiter.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-csstext-final-delimiter.html "css/cssom/cssstyledeclaration-csstext-final-delimiter.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-csstext-final-delimiter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-csstext-final-delimiter.html)
- [cssstyledeclaration-csstext-important.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-csstext-important.html "css/cssom/cssstyledeclaration-csstext-important.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-csstext-important.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-csstext-important.html)
- [cssstyledeclaration-csstext.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-csstext.html "css/cssom/cssstyledeclaration-csstext.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-csstext.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-csstext.html)
- [cssstyledeclaration-custom-properties.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-custom-properties.html "css/cssom/cssstyledeclaration-custom-properties.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-custom-properties.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-custom-properties.html)
- [cssstyledeclaration-mutability.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-mutability.html "css/cssom/cssstyledeclaration-mutability.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-mutability.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-mutability.html)
- [cssstyledeclaration-mutationrecord-001.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-mutationrecord-001.html "css/cssom/cssstyledeclaration-mutationrecord-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-mutationrecord-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-mutationrecord-001.html)
- [cssstyledeclaration-mutationrecord-002.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-mutationrecord-002.html "css/cssom/cssstyledeclaration-mutationrecord-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-mutationrecord-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-mutationrecord-002.html)
- [cssstyledeclaration-mutationrecord-003.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-mutationrecord-003.html "css/cssom/cssstyledeclaration-mutationrecord-003.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-mutationrecord-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-mutationrecord-003.html)
- [cssstyledeclaration-mutationrecord-004.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-mutationrecord-004.html "css/cssom/cssstyledeclaration-mutationrecord-004.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-mutationrecord-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-mutationrecord-004.html)
- [cssstyledeclaration-mutationrecord-005.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-mutationrecord-005.html "css/cssom/cssstyledeclaration-mutationrecord-005.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-mutationrecord-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-mutationrecord-005.html)
- [cssstyledeclaration-properties.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-properties.html "css/cssom/cssstyledeclaration-properties.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-properties.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-properties.html)
- [cssstyledeclaration-registered-custom-properties.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-registered-custom-properties.html "css/cssom/cssstyledeclaration-registered-custom-properties.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-registered-custom-properties.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-registered-custom-properties.html)
- [cssstyledeclaration-removeProperty-all.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-removeProperty-all.html "css/cssom/cssstyledeclaration-removeProperty-all.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-removeProperty-all.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-removeProperty-all.html)
- [cssstyledeclaration-setter-attr.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-setter-attr.html "css/cssom/cssstyledeclaration-setter-attr.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-setter-attr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-setter-attr.html)
- [cssstyledeclaration-setter-declarations.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-setter-declarations.html "css/cssom/cssstyledeclaration-setter-declarations.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-setter-declarations.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-setter-declarations.html)
- [cssstyledeclaration-setter-form-controls.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-setter-form-controls.html "css/cssom/cssstyledeclaration-setter-form-controls.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-setter-form-controls.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-setter-form-controls.html)
- [cssstyledeclaration-setter-logical.html](https://wpt.fyi/results/css/cssom/cssstyledeclaration-setter-logical.html "css/cssom/cssstyledeclaration-setter-logical.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-setter-logical.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-setter-logical.html)
- [page-descriptors.html](https://wpt.fyi/results/css/cssom/page-descriptors.html "css/cssom/page-descriptors.html")
 [[(live
 test)]](http://wpt.live/css/cssom/page-descriptors.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/page-descriptors.html)
- [property-accessors.html](https://wpt.fyi/results/css/cssom/property-accessors.html "css/cssom/property-accessors.html")
 [[(live
 test)]](http://wpt.live/css/cssom/property-accessors.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/property-accessors.html)

The object's [supported property
indices](http://heycam.github.io/webidl/#dfn-supported-property-indices) are the numbers in the range zero to one less than the
number of [CSS declarations](#css-declaration) in the
[declarations](#cssstyledeclaration-declarations). If there are no such [CSS
declarations], then there are no [supported
property indices].

Getting the [`cssText`] attribute must run these steps:

1. If the [computed
 flag](#cssstyledeclaration-computed-flag) is set, then return the empty string.

2. Return the result of
 [serializing](#serialize-a-css-declaration-block) the
 [declarations](#cssstyledeclaration-declarations).

Setting the
[`cssText`](#dom-cssstyledeclaration-csstext) attribute must run these steps:

1. If the [readonly
 flag](#cssstyledeclaration-readonly-flag) is set, then
 [throw](http://heycam.github.io/webidl/#dfn-throw) a
 [`NoModificationAllowedError`](https://webidl.spec.whatwg.org/#nomodificationallowederror) exception.
2. Empty the
 [declarations](#cssstyledeclaration-declarations).
3. [Parse](#parse-a-css-declaration-block) the given value and, if the return value is not the
 empty list, insert the items in the list into the
 [declarations](#cssstyledeclaration-declarations), in [specified
 order](#concept-declarations-specified-order).
4. [Update style attribute
 for](#update-style-attribute-for) the [CSS declaration
 block](#css-declaration-block).

The [`length`]
attribute must return the number of [CSS
declarations](#css-declaration) in the
[declarations](#cssstyledeclaration-declarations).

The [`item(``index``)`] method must return the [property
name](#css-declaration-property-name) of the [CSS
declaration](#css-declaration) at position `index`. If there is no
`index`th object in the collection, then the method must
return the empty string.

The
[`getPropertyValue(``property``)`] method must run these steps:

1. If `property` is not a [custom
 property](https://drafts.csswg.org/css-variables-1/#custom-property), follow these substeps:
 1. Let `property` be `property` [converted to
 ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase).
 2. If `property` is a shorthand property, then follow
 these substeps:
 1. Let `list` be a new empty array.
 2. For each longhand property `longhand` that
 `property` maps to, in canonical order, follow
 these substeps:
 1. If `longhand` is a
 [case-sensitive](https://w3c.github.io/i18n-glossary/#dfn-case-sensitive) match for a [property
 name](#css-declaration-property-name) of a [CSS
 declaration](#css-declaration) in the
 [declarations](#cssstyledeclaration-declarations), let `declaration` be that
 [CSS declaration], or null
 otherwise.
 2. If `declaration` is null, then return the
 empty string.
 3. Append the `declaration` to
 `list`.
 3. If [important
 flags](#css-declaration-important-flag) of all declarations in `list`
 are same, then return the
 [serialization](#serialize-a-css-value) of `list`.
 4. Return the empty string.
2. If `property` is a
 [case-sensitive](https://w3c.github.io/i18n-glossary/#dfn-case-sensitive) match for a [property
 name](#css-declaration-property-name) of a [CSS
 declaration](#css-declaration) in the
 [declarations](#cssstyledeclaration-declarations), then return the result of invoking [serialize a
 CSS value](#serialize-a-css-value) of that declaration.
3. Return the empty string.

Tests

- [cssom-getPropertyValue-common-checks.html](https://wpt.fyi/results/css/cssom/cssom-getPropertyValue-common-checks.html "css/cssom/cssom-getPropertyValue-common-checks.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssom-getPropertyValue-common-checks.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssom-getPropertyValue-common-checks.html)
- [serialize-all-longhands.html](https://wpt.fyi/results/css/cssom/serialize-all-longhands.html "css/cssom/serialize-all-longhands.html")
 [[(live
 test)]](http://wpt.live/css/cssom/serialize-all-longhands.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/serialize-all-longhands.html)

The
[`getPropertyPriority(``property``)`] method must run these steps:

1. If `property` is not a [custom
 property](https://drafts.csswg.org/css-variables-1/#custom-property), follow these substeps:
 1. Let `property` be `property` [converted to
 ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase).
 2. If `property` is a shorthand property, follow these
 substeps:
 1. Let `list` be a new array.
 2. For each longhand property `longhand` that
 `property` maps to, append the result of invoking
 [`getPropertyPriority()`](#dom-cssstyledeclaration-getpropertypriority) with `longhand` as argument to
 `list`.
 3. If all items in `list` are the string
 \"`important`\", then return the string \"`important`\".
2. If `property` is a
 [case-sensitive](https://w3c.github.io/i18n-glossary/#dfn-case-sensitive) match for a [property
 name](#css-declaration-property-name) of a [CSS
 declaration](#css-declaration) in the
 [declarations](#cssstyledeclaration-declarations) that has the [important
 flag](#css-declaration-important-flag) set, return the string \"`important`\".
3. Return the empty string.

E.g. for
`background-color:lime !IMPORTANT` the return value would be
\"`important`\".

[`setProperty(``property``, ``value``, ``priority``)`]
method must run these steps:

1. If the [readonly
 flag](#cssstyledeclaration-readonly-flag) is set, then
 [throw](http://heycam.github.io/webidl/#dfn-throw) a
 [`NoModificationAllowedError`](https://webidl.spec.whatwg.org/#nomodificationallowederror) exception.

2. If `property` is not a [custom
 property](https://drafts.csswg.org/css-variables-1/#custom-property), follow these substeps:
 1. Let `property` be `property` [converted to
 ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase).
 2. If `property` is not a
 [case-sensitive](https://w3c.github.io/i18n-glossary/#dfn-case-sensitive) match for a [supported CSS
 property](#supported-css-property), then return.

3. If `value` is the empty string, invoke
 [`removeProperty()`](#dom-cssstyledeclaration-removeproperty) with `property` as argument and return.

4. If `priority` is not the empty string and is not an
 [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for the string \"`important`\", then return.

5. Let `component value list` be the result of
 [parsing](#parse-a-css-value) `value` for property
 `property`.

 `value` can not include
 \"`!important`\".

6. If `component value list` is null, then return.

7. Let `updated` be false.

8. If `property` is a shorthand property, then for each
 longhand property `longhand` that `property`
 maps to, in canonical order, follow these substeps:
 1. Let `longhand result` be the result of [set the CSS
 declaration](#set-a-css-declaration) `longhand` with the appropriate
 value(s) from `component value list`, with the
 *important* flag set if `priority` is not the empty
 string, and unset otherwise, and with the list of declarations
 being the
 [declarations](#cssstyledeclaration-declarations).
 2. If `longhand result` is true, let
 `updated` be true.

9. Otherwise, let `updated` be the result of [set the CSS
 declaration](#set-a-css-declaration) `property` with value
 `component value list`, with the *important* flag set if
 `priority` is not the empty string, and unset otherwise,
 and with the list of declarations being the
 [declarations](#cssstyledeclaration-declarations).

10. If `updated` is true, [update style attribute
 for](#update-style-attribute-for) the [CSS declaration
 block](#css-declaration-block).

Tests

- [cssom-setProperty-shorthand.html](https://wpt.fyi/results/css/cssom/cssom-setProperty-shorthand.html "css/cssom/cssom-setProperty-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/cssom/cssom-setProperty-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssom-setProperty-shorthand.html)
- [MutationObserver-style.html](https://wpt.fyi/results/css/cssom/MutationObserver-style.html "css/cssom/MutationObserver-style.html")
 [[(live
 test)]](http://wpt.live/css/cssom/MutationObserver-style.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/MutationObserver-style.html)
- [rule-restrictions.html](https://wpt.fyi/results/css/cssom/rule-restrictions.html "css/cssom/rule-restrictions.html")
 [[(live
 test)]](http://wpt.live/css/cssom/rule-restrictions.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/rule-restrictions.html)
- [setproperty-null-undefined.html](https://wpt.fyi/results/css/cssom/setproperty-null-undefined.html "css/cssom/setproperty-null-undefined.html")
 [[(live
 test)]](http://wpt.live/css/cssom/setproperty-null-undefined.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/setproperty-null-undefined.html)

To [set a CSS declaration] `property` with a value
`component value list` and optionally with an *important*
flag set, in a list of declarations `declarations`, the user
agent must ensure the following constraints hold after its steps:

- Exactly one [CSS
 declaration](#css-declaration) whose [property
 name](#css-declaration-property-name) is a
 [case-sensitive](https://w3c.github.io/i18n-glossary/#dfn-case-sensitive) match of `property` must exist in
 `declarations`. Such declaration is referenced as the
 `target declaration` below.
- The `target declaration` must have value being
 `component value list`, and
 `target declaration`'s [important
 flag](#css-declaration-important-flag) must be [set](#set) if
 *important* flag is set, and [unset](#unset) otherwise.
- Any [CSS declaration](#css-declaration) which is not the `target declaration` must
 not be changed, inserted, or removed from `declarations`.
- If there are [CSS
 declarations](#css-declaration) in `declarations` whose [property
 name](#css-declaration-property-name) is in the same [logical property
 group](https://drafts.csswg.org/css-logical-1/#logical-property-group) as `property`, but has a different
 [mapping
 logic](https://drafts.csswg.org/css-logical-1/#mapping-logic), `target declaration` must be at an index
 after all of those [CSS declarations].
- The steps must return true if the serialization of
 `declarations` was changed as result of the steps. It may
 return false otherwise.

Should we add something like \"Any
observable side effect must not be made outside
`declarations`\"? The current constraints sound like a hole
for undefined behavior.

 The steps of [set a CSS
declaration](#set-a-css-declaration) are not defined in this level of CSSOM. User agents may
use different algorithms as long as the constraints above hold.

The simplest way to conform with the
constraints would be to always remove any existing declaration matching
`property`, and append the new declaration to the end. But
based on implementation feedback, this approach would likely regress
performance.

Another possible algorithm is:

1. If `property` is a
 [case-sensitive](https://w3c.github.io/i18n-glossary/#dfn-case-sensitive) match for a [property
 name](#css-declaration-property-name) of a [CSS
 declaration](#css-declaration) in `declarations`, follow these
 substeps:
 1. Let `target declaration` be such [CSS
 declaration](#css-declaration).
 2. Let `needs append` be false.
 3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `declaration` in
 `declarations` after `target declaration`:
 1. If `declaration`'s [property
 name](#css-declaration-property-name) is not in the same [logical property
 group](https://drafts.csswg.org/css-logical-1/#logical-property-group) as `property`, then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).
 2. If `declaration`' [property
 name](#css-declaration-property-name) has the same [mapping
 logic](https://drafts.csswg.org/css-logical-1/#mapping-logic) as `property`, then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).
 3. Let `needs append` be true.
 4. [Break](https://drafts.csswg.org/css-break-4/#break).
 4. If `needs append` is false, then:
 1. Let `needs update` be false.
 2. If `target declaration`'s
 [value](#css-declaration-value) is not equal to
 `component value list`, then let
 `needs update` be true.
 3. If `target declaration`'s [important
 flag](#css-declaration-important-flag) is not equal to whether *important* flag is
 set, then let `needs update` be true.
 4. If `needs update` is false, then return false.
 5. Set `target declaration`'s
 [value](#css-declaration-value) to `component value list`.
 6. If *important* flag is set, then set
 `target declaration`'s [important
 flag](#css-declaration-important-flag), otherwise unset it.
 7. Return true.
 5. Otherwise, remove `target declaration` from
 `declarations`.
2. Append a new [CSS
 declaration](#css-declaration) with [property
 name](#css-declaration-property-name) `property`,
 [value](#css-declaration-value) `component value list`, and [important
 flag](#css-declaration-important-flag) set if *important* flag is set to
 `declarations`.
3. Return true.

[`removeProperty(``property``)`] method must run these steps:

1. If the [readonly
 flag](#cssstyledeclaration-readonly-flag) is set, then
 [throw](http://heycam.github.io/webidl/#dfn-throw) a
 [`NoModificationAllowedError`](https://webidl.spec.whatwg.org/#nomodificationallowederror) exception.
2. If `property` is not a [custom
 property](https://drafts.csswg.org/css-variables-1/#custom-property), let `property` be `property`
 [converted to ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase).
3. Let `value` be the return value of invoking
 [`getPropertyValue()`](#dom-cssstyledeclaration-getpropertyvalue) with `property` as argument.
4. Let `removed` be false.
5. If `property` is a shorthand property, for each longhand
 property `longhand` that `property` maps to:
 1. If `longhand` is not a [property
 name](#css-declaration-property-name) of a [CSS
 declaration](#css-declaration) in the
 [declarations](#cssstyledeclaration-declarations),
 [continue](https://infra.spec.whatwg.org/#iteration-continue).
 2. Remove that [CSS
 declaration](#css-declaration) and let `removed` be true.
6. Otherwise, if `property` is a
 [case-sensitive](https://w3c.github.io/i18n-glossary/#dfn-case-sensitive) match for a [property
 name](#css-declaration-property-name) of a [CSS
 declaration](#css-declaration) in the
 [declarations](#cssstyledeclaration-declarations), remove that [CSS
 declaration] and let
 `removed` be true.
7. If `removed` is true, [Update style attribute
 for](#update-style-attribute-for) the [CSS declaration
 block](#css-declaration-block).
8. Return `value`.

The [`parentRule`]
attribute must return the [parent CSS
rule](#cssstyledeclaration-parent-css-rule).

The [`cssFloat`]
attribute, on getting, must return the result of invoking
[`getPropertyValue()`](#dom-cssstyledeclaration-getpropertyvalue) with `float` as argument. On setting, the attribute
must invoke
[`setProperty()`](#dom-cssstyledeclaration-setproperty) with `float` as first argument, as second argument the
given value, and no third argument. Any exceptions thrown must be
re-thrown.

For each CSS property `property` that is a [supported CSS
property](#supported-css-property), the following partial interface applies where
[`camel-cased attribute`] is obtained by running the [CSS property
to IDL
attribute](#css-property-to-idl-attribute) algorithm for `property`.

Tests

- [change-rule-with-layers-crash.html](https://wpt.fyi/results/css/cssom/change-rule-with-layers-crash.html "css/cssom/change-rule-with-layers-crash.html")
 [[(live
 test)]](http://wpt.live/css/cssom/change-rule-with-layers-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/change-rule-with-layers-crash.html)
- [style-attr-update-across-documents.html](https://wpt.fyi/results/css/cssom/style-attr-update-across-documents.html "css/cssom/style-attr-update-across-documents.html")
 [[(live
 test)]](http://wpt.live/css/cssom/style-attr-update-across-documents.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/style-attr-update-across-documents.html)

```
partial interface CSSStyleProperties {
 [CEReactions] attribute [LegacyNullToEmptyString] CSSOMString _camel_cased_attribute;
};
```

The
[`camel-cased attribute`](#dom-cssstyleproperties-camel-cased-attribute) attribute, on getting, must return the
result of invoking
[`getPropertyValue()`](#dom-cssstyledeclaration-getpropertyvalue) with the argument being the result of running the [IDL
attribute to CSS
property](#idl-attribute-to-css-property) algorithm for `camel-cased attribute`.

Setting the
[`camel-cased attribute`](#dom-cssstyleproperties-camel-cased-attribute) attribute must invoke
[`setProperty()`](#dom-cssstyledeclaration-setproperty) with the first argument being the result of running the
[IDL attribute to CSS
property](#idl-attribute-to-css-property) algorithm for `camel-cased attribute`, as
second argument the given value, and no third argument. Any exceptions
thrown must be re-thrown.

For example, for the
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) property there would be a
`fontSize` IDL attribute.

For each CSS property `property` that is a [supported CSS
property](#supported-css-property) and that begins with the string `-webkit-`, the
following partial interface applies where
`webkit-cased attribute` is obtained by running the [CSS
property to IDL
attribute](#css-property-to-idl-attribute) algorithm for `property`, with the
*lowercase first* flag set.

```
partial interface CSSStyleProperties {
 [CEReactions] attribute [LegacyNullToEmptyString] CSSOMString _webkit_cased_attribute;
};
```

The
[`webkit-cased attribute`] attribute, on getting, must return the
result of invoking
[`getPropertyValue()`](#dom-cssstyledeclaration-getpropertyvalue) with the argument being the result of running the [IDL
attribute to CSS
property](#idl-attribute-to-css-property) algorithm for `webkit-cased attribute`, with
the *dash prefix* flag set.

Setting the
[`webkit-cased attribute`](https://www.w3.org/TR/cssom-1/#dom-cssstyledeclaration-webkit-cased-attribute) attribute must invoke
[`setProperty()`](#dom-cssstyledeclaration-setproperty) with the first argument being the result of running the
[IDL attribute to CSS
property](#idl-attribute-to-css-property) algorithm for `webkit-cased attribute`, with
the *dash prefix* flag set, as second argument the given value, and no
third argument. Any exceptions thrown must be re-thrown.

For example, if the user agent supports
the
[-webkit-transform](https://compat.spec.whatwg.org/#propdef--webkit-transform) property, there would be a
`webkitTransform` IDL attribute. There would also be a `WebkitTransform`
IDL attribute because of the rules for camel-cased attributes.

For each CSS property `property` that is a [supported CSS
property](#supported-css-property), except for properties that have no \"`-`\" (U+002D) in
the property name, the following partial interface applies where
`dashed attribute` is `property`.

```
partial interface CSSStyleProperties {
 [CEReactions] attribute [LegacyNullToEmptyString] CSSOMString _dashed_attribute;
};
```

The
[`dashed attribute`] attribute, on getting, must return the
result of invoking
[`getPropertyValue()`](#dom-cssstyledeclaration-getpropertyvalue) with the argument being `dashed attribute`.

Setting the
[`dashed attribute`](#dom-cssstyleproperties-dashed-attribute) attribute must invoke
[`setProperty()`](#dom-cssstyledeclaration-setproperty) with the first argument being
`dashed attribute`, as second argument the given value, and
no third argument. Any exceptions thrown must be re-thrown.

For example, for the
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) property there would be a
`font-size` IDL attribute. In JavaScript, the property can be accessed
as follows, assuming `element` is an [HTML
element](https://html.spec.whatwg.org/multipage/infrastructure.html#html-elements):

 element.style['font-size'];

The [CSS property to IDL attribute] algorithm for
`property`, optionally with a *lowercase first* flag set, is
as follows:

1. Let `output` be the empty string.
2. Let `uppercase next` be unset.
3. If the *lowercase first* flag is set, remove the first character
 from `property`.
4. For each character `c` in `property`:
 1. If `c` is \"`-`\" (U+002D), let
 `uppercase next` be set.
 2. Otherwise, if `uppercase next` is set, let
 `uppercase next` be unset and append `c`
 [converted to ASCII
 uppercase](https://infra.spec.whatwg.org/#ascii-uppercase) to `output`.
 3. Otherwise, append `c` to `output`.
5. Return `output`.

The [IDL attribute to CSS property] algorithm for
`attribute`, optionally with a *dash prefix* flag set, is as
follows:

1. Let `output` be the empty string.
2. If the *dash prefix* flag is set, append \"`-`\" (U+002D) to
 `output`.
3. For each character `c` in `attribute`:
 1. If `c` is in the range U+0041 to U+005A (ASCII
 uppercase), append \"`-`\" (U+002D) followed by `c`
 [converted to ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase) to `output`.
 2. Otherwise, append `c` to `output`.
4. Return `output`.

### 6.7. CSS Values

#### 6.7.1. Parsing CSS Values

To [parse a CSS value] `value` for a given
`property` means to follow these steps:

1. Let `list` be the value returned by invoking [parse a
 list of component
 values](https://drafts.csswg.org/css-syntax-3/#parse-a-list-of-component-values) from `value`.
2. Match `list` against the grammar for the property
 `property` in the CSS specification.
3. If the above step failed, return null.
4. Return `list`.

 \"`!important`\" declarations are not part of the
property value space and will therefore cause [parse a CSS
value](#parse-a-css-value)
to return null.

#### 6.7.2. Serializing CSS Values

To [serialize a CSS value] of a [CSS
declaration](#css-declaration) `declaration` or a list of longhand [CSS
declarations] `list`, follow
these rules:

1. If this algorithm is invoked with a
 [list](https://infra.spec.whatwg.org/#list) `list`:

 1. Let `shorthand` be the first shorthand property, in
 [preferred shorthand
 order](#concept-shorthands-preferred-order), that exactly maps to all of the longhand
 properties in `list`.

 2. If there is no such shorthand or `shorthand` cannot
 exactly represent the values of all the properties in
 `list`, return the empty string.

 3. Otherwise, [serialize a CSS
 value](#serialize-a-css-value) from a hypothetical declaration of the property
 `shorthand` with its value representing the combined
 values of the declarations in `list`.

2. Represent the value of the `declaration` as a
 [list](https://infra.spec.whatwg.org/#list) of CSS component values `components`
 that, when
 [parsed](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) according to the property's grammar, would
 represent that value. Additionally, unless otherwise specified:

 - If certain component values can appear in any order without
 changing the meaning of the value (a pattern typically represented
 by a double bar
 [\|\|](https://drafts.csswg.org/css-values-4/#comb-any) in the value syntax), reorder the component
 values to use the canonical order of component values as given in
 the property definition table.

 - If component values can be omitted or replaced with a shorter
 representation without changing the meaning of the value,
 omit/replace them.

 - If either of the above syntactic translations would be less
 backwards-compatible, do not perform them.

 The rules described here outline the *general
 principles* of serialization. For legacy reasons, some properties
 serialize in a different manner, which is intentionally undefined
 here due to lack of resources. Please consult that property's
 specification and/or your local reverse-engineer for details.

3. Remove any
 [\<whitespace-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-whitespace-token)s from `components`.

4. Replace each component value in `components` with the
 result of invoking [serialize a CSS component
 value](#serialize-a-css-component-value).

5. Join the items of `components` into a single string,
 inserting \" \" (U+0020 SPACE) between each pair of items unless the
 second item is a \",\" (U+002C COMMA) Return the result.

Tests

- [flex-serialization.html](https://wpt.fyi/results/css/cssom/flex-serialization.html "css/cssom/flex-serialization.html")
 [[(live
 test)]](http://wpt.live/css/cssom/flex-serialization.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/flex-serialization.html)
- [overflow-serialization.html](https://wpt.fyi/results/css/cssom/overflow-serialization.html "css/cssom/overflow-serialization.html")
 [[(live
 test)]](http://wpt.live/css/cssom/overflow-serialization.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/overflow-serialization.html)
- [serialize-values.html](https://wpt.fyi/results/css/cssom/serialize-values.html "css/cssom/serialize-values.html")
 [[(live
 test)]](http://wpt.live/css/cssom/serialize-values.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/serialize-values.html)

To [serialize a CSS component value] depends on the component, as
follows:

[keyword](https://drafts.csswg.org/css-values-4/#css-keyword)
: The keyword [converted to ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase).

[\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value)

: The \<number\> component serialized as per \<number\> followed by
 the unit in canonical form as defined in its respective
 specification.

 (#issue-87977b18) Probably should distinguish between
 declared and computed / resolved values.

[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)

: If \<color\> is a component of a resolved value, see [CSS Color 4
 §  15. Resolving \<color\>
 Values](https://drafts.csswg.org/css-color-4/#resolving-color-values).

 If \<color\> is a component of a computed value, see [CSS Color 4
 §  16. Serializing \<color\>
 Values](https://drafts.csswg.org/css-color-4/#serializing-color-values).

 If
 [\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) is a component of a declared
 value, then for sRGB values, see [CSS Color 4 § 15.1 Resolving sRGB
 values](https://drafts.csswg.org/css-color-4/#resolving-sRGB-values).
 For other color functions, see [CSS Color 4 §  15. Resolving
 \<color\>
 Values](https://drafts.csswg.org/css-color-4/#resolving-color-values).

[\<alpha-value\>](https://drafts.csswg.org/css-color-4/#typedef-color-alpha-value)
: See [CSS Color 4 § 16.1 Serializing alpha
 values](https://drafts.csswg.org/css-color-4/#serializing-alpha-values).

[\<counter\>](https://drafts.csswg.org/css-lists-3/#typedef-counter)
: The return value of the following algorithm:
 1. Let `s` be the empty string.
 2. If \<counter\> has three CSS component values append the string
 \"`counters(`\" to `s`.
 3. If \<counter\> has two CSS component values append the string
 \"`counter(`\" to `s`.
 4. Let `list` be a list of CSS component values
 belonging to \<counter\>, omitting the last CSS component value
 if it is \"decimal\".
 5. Let each item in `list` be the result of invoking
 [serialize a CSS component
 value](#serialize-a-css-component-value) on that item.
 6. Append the result of invoking [serialize a comma-separated
 list](#serialize-a-comma-separated-list) on `list` to `s`.
 7. Append \"`)`\" (U+0029) to `s`.
 8. Return `s`.

[\<frequency\>](https://drafts.csswg.org/css-values-4/#frequency-value)

: The \<number\> component serialized as per \<number\> followed by
 the unit in its canonical form as defined in its respective
 specification.

 (#issue-87977b18①) Probably should distinguish between
 declared and computed / resolved values.

[\<identifier\>](https://drafts.csswg.org/css2/#value-def-identifier)
: The identifier [serialized as an
 identifier](#serialize-an-identifier).

[\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value)
: A base-ten integer using digits 0-9 (U+0030 to U+0039) in the
 shortest form possible, preceded by \"`-`\" (U+002D) if it is
 negative.

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

: The \<number\> component serialized as per \<number\> followed by
 the unit in its canonical form as defined in its respective
 specification.

 (#issue-87977b18②) Probably should distinguish between
 declared and computed / resolved values.

[\<number\>](https://drafts.csswg.org/css-values-4/#number-value)

: A base-ten number using digits 0-9 (U+0030 to U+0039) in the
 shortest form possible, using \"`.`\" to separate decimals (if any),
 rounding the value if necessary to not produce more than 6 decimals,
 preceded by \"`-`\" (U+002D) if it is negative.

 scientific notation is not used.

[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)
: The \<number\> component serialized as per \<number\> followed by
 the literal string \"`%`\" (U+0025).

[\<resolution\>](https://drafts.csswg.org/css-values-4/#resolution-value)
: The resolution in dots per [CSS
 pixel](https://drafts.csswg.org/css-values-4/#px) serialized as per \<number\> followed by the
 literal string \"`dppx`\".

[\<ratio\>](https://drafts.csswg.org/css-values-4/#ratio-value)
: The numerator serialized as per \<number\> followed by the literal
 string \"` / `\", followed by the denominator serialized as per
 \<number\>.

[\<shape\>](https://drafts.csswg.org/css2/#value-def-shape)
: The return value of the following algorithm:
 1. Let `s` be the string \"`rect(`\".
 2. Let `list` be a list of the CSS component values
 belonging to \<shape\>.
 3. Let each item in `list` be the result of invoking
 [serialize a CSS component
 value](#serialize-a-css-component-value) of that item.
 4. Append the result of invoking [serialize a comma-separated
 list](#serialize-a-comma-separated-list) on `list` to `s`.
 5. Append \"`)`\" (U+0029) to `s`.
 6. Return `s`.

[\<string\>](https://drafts.csswg.org/css-values-4/#string-value)\
[\<font-family-name\>](https://drafts.csswg.org/css-fonts-4/#font-family-name-value)
: The string [serialized as a
 string](#serialize-a-string).

[\<time\>](https://drafts.csswg.org/css-values-4/#time-value)
: The time in seconds serialized as per \<number\> followed by the
 literal string \"`s`\".

[\<url\>](https://drafts.csswg.org/css-values-4/#url-value)

: The [absolute-URL
 string](https://url.spec.whatwg.org/#absolute-url-string) [serialized as
 URL](#serialize-a-url).

 (#issue-c9f9e4e6) This should differentiate declared
 and computed
 [\<url\>](https://drafts.csswg.org/css-values-4/#url-value) values, see
 [#3195](https://github.com/w3c/csswg-drafts/issues/3195).

\<absolute-size\>, \<border-width\>, \<border-style\>, \<bottom\>,
\<generic-font-family\>, \<generic-voice\>, \<left\>, \<margin-width\>,
\<padding-width\>, \<relative-size\>, \<right\>, and \<top\>, are
considered macros by this specification. They all represent instances of
components outlined above.

One idea is that we can remove this
section somewhere in the CSS3/CSS4 timeline by moving the above
definitions to the drafts that define the CSS components.

Tests

- [serialize-custom-props.html](https://wpt.fyi/results/css/cssom/serialize-custom-props.html "css/cssom/serialize-custom-props.html")
 [[(live
 test)]](http://wpt.live/css/cssom/serialize-custom-props.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/serialize-custom-props.html)

##### 6.7.2.1. Examples

Here are some examples of before and after results on declared values.
The before column could be what the author wrote in a style sheet, while
the after column shows what querying the DOM would return.

Before

After

`background: none`

`background: rgba(0, 0, 0, 0)`

`outline: none`

`outline: invert`

`border: none`

`border: medium`

`list-style: none`

`list-style: disc`

`margin: 0 1px 1px 1px`

`margin: 0px 1px 1px`

`azimuth: behind left`

`azimuth: 220deg`

`font-family: a, 'b"', serif`

`font-family: "a", "b\"", serif`

`content: url('h)i') '\[\]'`

`content: url("h)i") ""`

`azimuth: leftwards`

`azimuth: leftwards`

`color: rgb(18, 52, 86)`

`color: #123456`

`color: rgba(000001, 0, 0, 1)`

`color: #000000`

Some of these need to be updated per the
new rules.

## 7. DOM Access to CSS Declaration Blocks

### 7.1. The [`ElementCSSInlineStyle` Mixin]
The `ElementCSSInlineStyle` mixin provides access to inline style
properties of an element.

```
interface mixin ElementCSSInlineStyle {
 [SameObject, PutForwards=cssText] readonly attribute CSSStyleProperties style;
};
```

The [`style`] attribute must return a
[`CSSStyleProperties`](#cssstyleproperties) object whose [readonly
flag](#cssstyledeclaration-readonly-flag) is unset, whose [parent CSS
rule](#cssstyledeclaration-parent-css-rule) is null, and whose [owner
node](#cssstyledeclaration-owner-node) is
[this](https://webidl.spec.whatwg.org/#this).

If the user agent supports HTML, the following IDL applies:
[\[HTML\]](#biblio-html "HTML Standard")

```
HTMLElement includes ElementCSSInlineStyle;
```

If the user agent supports SVG, the following IDL applies:
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)")

```
SVGElement includes ElementCSSInlineStyle;
```

If the user agent supports MathML, the following IDL applies:
[\[MathML-Core\]](#biblio-mathml-core "MathML Core")

```
MathMLElement includes ElementCSSInlineStyle;
```

Tests

- [css-style-attribute-modifications.html](https://wpt.fyi/results/css/cssom/css-style-attribute-modifications.html "css/cssom/css-style-attribute-modifications.html")
 [[(live
 test)]](http://wpt.live/css/cssom/css-style-attribute-modifications.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/css-style-attribute-modifications.html)
- [inline-style-001.html](https://wpt.fyi/results/css/cssom/inline-style-001.html "css/cssom/inline-style-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom/inline-style-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/inline-style-001.html)

### [7.2. ][Extensions to the [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) Interface]
```
partial interface Window {
 [NewObject] CSSStyleProperties getComputedStyle(Element elt, optional CSSOMString? pseudoElt);
};
```

The
[`getComputedStyle(``elt``, ``pseudoElt``)`] method must
run these steps:

1. Let `doc` be `elt`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

2. Let `obj` be `elt`.

3. If `pseudoElt` is provided, is not the empty string, and
 starts with a colon, then:

 1. [Parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) `pseudoElt` as a
 [\<pseudo-element-selector\>](https://drafts.csswg.org/selectors-4/#typedef-pseudo-element-selector), and let `type` be
 the result.
 2. If `type` is failure, or is a
 [::slotted()](https://drafts.csswg.org/css-shadow-1/#selectordef-slotted) or
 [::part()](https://drafts.csswg.org/css-shadow-1/#selectordef-part) pseudo-element, let `obj` be
 null.
 3. Otherwise let `obj` be the given pseudo-element of
 `elt`.

 CSS2 pseudo-elements should match both the double
 and single-colon versions. That is, both `:before` and `::before`
 should match above.

4. Let `decls` be an empty list of [CSS
 declarations](#css-declaration).

5. If `obj` is not null, and `elt` is
 [connected](https://dom.spec.whatwg.org/#connected), part of the [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree), and its [shadow-including
 root](https://dom.spec.whatwg.org/#concept-shadow-including-root) has a [browsing
 context](https://html.spec.whatwg.org/multipage/browsers.html#browsing-context) which either doesn't have a [browsing context
 container], or whose [browsing context
 container] is [being
 rendered](https://html.spec.whatwg.org/multipage/rendering.html#being-rendered), set `decls` to a list of all longhand
 properties that are [supported CSS
 properties](#supported-css-property), in lexicographical order, with the value being the
 [resolved value](#resolved-value) computed for `obj` using the style rules
 associated with `doc`. Additionally, append to
 `decls` all the [custom
 properties](https://drafts.csswg.org/css-variables-1/#custom-property) whose [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) for `obj` is not the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value).

 (#issue-28428295) There are UAs that handle
 shorthands, and all UAs handle shorthands that used to be longhands
 like
 [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow), see
 [#2529](https://github.com/w3c/csswg-drafts/issues/2529).

 (#issue-0b704bc1) Order of custom properties is
 currently undefined, see
 [#4947](https://github.com/w3c/csswg-drafts/issues/4947).

6. Return a live
 [`CSSStyleProperties`](#cssstyleproperties) object with the following properties:

 [computed flag](#cssstyledeclaration-computed-flag)
 : Set.

 [readonly flag](#cssstyledeclaration-readonly-flag)
 : Set.

 [declarations](#cssstyledeclaration-declarations)
 : `decls`.

 [parent CSS rule](#cssstyledeclaration-parent-css-rule)
 : Null.

 [owner node](#cssstyledeclaration-owner-node)
 : `obj`.

The
[`getComputedStyle()`](#dom-window-getcomputedstyle) method exposes information from [CSS style
sheets](#css-style-sheet)
with the [origin-clean
flag](#concept-css-style-sheet-origin-clean-flag) unset.

Tests

- [getComputedStyle-animations-replaced-into-ib-split.html](https://wpt.fyi/results/css/cssom/getComputedStyle-animations-replaced-into-ib-split.html "css/cssom/getComputedStyle-animations-replaced-into-ib-split.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-animations-replaced-into-ib-split.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-animations-replaced-into-ib-split.html)
- [getComputedStyle-detached-subtree.html](https://wpt.fyi/results/css/cssom/getComputedStyle-detached-subtree.html "css/cssom/getComputedStyle-detached-subtree.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-detached-subtree.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-detached-subtree.html)
- [getComputedStyle-display-none-001.html](https://wpt.fyi/results/css/cssom/getComputedStyle-display-none-001.html "css/cssom/getComputedStyle-display-none-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-display-none-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-display-none-001.html)
- [getComputedStyle-display-none-002.html](https://wpt.fyi/results/css/cssom/getComputedStyle-display-none-002.html "css/cssom/getComputedStyle-display-none-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-display-none-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-display-none-002.html)
- [getComputedStyle-display-none-003.html](https://wpt.fyi/results/css/cssom/getComputedStyle-display-none-003.html "css/cssom/getComputedStyle-display-none-003.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-display-none-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-display-none-003.html)
- [getComputedStyle-dynamic-subdoc.html](https://wpt.fyi/results/css/cssom/getComputedStyle-dynamic-subdoc.html "css/cssom/getComputedStyle-dynamic-subdoc.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-dynamic-subdoc.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-dynamic-subdoc.html)
- [getComputedStyle-getter-v-properties.tentative.html](https://wpt.fyi/results/css/cssom/getComputedStyle-getter-v-properties.tentative.html "css/cssom/getComputedStyle-getter-v-properties.tentative.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-getter-v-properties.tentative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-getter-v-properties.tentative.html)
- [getComputedStyle-insets-absolute-crash.html](https://wpt.fyi/results/css/cssom/getComputedStyle-insets-absolute-crash.html "css/cssom/getComputedStyle-insets-absolute-crash.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-insets-absolute-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-insets-absolute-crash.html)
- [getComputedStyle-insets-absolute-logical-crash.html](https://wpt.fyi/results/css/cssom/getComputedStyle-insets-absolute-logical-crash.html "css/cssom/getComputedStyle-insets-absolute-logical-crash.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-insets-absolute-logical-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-insets-absolute-logical-crash.html)
- [getComputedStyle-insets-absolute-roundtrip.html](https://wpt.fyi/results/css/cssom/getComputedStyle-insets-absolute-roundtrip.html "css/cssom/getComputedStyle-insets-absolute-roundtrip.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-insets-absolute-roundtrip.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-insets-absolute-roundtrip.html)
- [getComputedStyle-insets-absolute.html](https://wpt.fyi/results/css/cssom/getComputedStyle-insets-absolute.html "css/cssom/getComputedStyle-insets-absolute.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-insets-absolute.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-insets-absolute.html)
- [getComputedStyle-insets-fixed.html](https://wpt.fyi/results/css/cssom/getComputedStyle-insets-fixed.html "css/cssom/getComputedStyle-insets-fixed.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-insets-fixed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-insets-fixed.html)
- [getComputedStyle-insets-grid.html](https://wpt.fyi/results/css/cssom/getComputedStyle-insets-grid.html "css/cssom/getComputedStyle-insets-grid.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-insets-grid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-insets-grid.html)
- [getComputedStyle-insets-multicol-absolute-crash.html](https://wpt.fyi/results/css/cssom/getComputedStyle-insets-multicol-absolute-crash.html "css/cssom/getComputedStyle-insets-multicol-absolute-crash.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-insets-multicol-absolute-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-insets-multicol-absolute-crash.html)
- [getComputedStyle-insets-nobox.html](https://wpt.fyi/results/css/cssom/getComputedStyle-insets-nobox.html "css/cssom/getComputedStyle-insets-nobox.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-insets-nobox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-insets-nobox.html)
- [getComputedStyle-insets-relative.html](https://wpt.fyi/results/css/cssom/getComputedStyle-insets-relative.html "css/cssom/getComputedStyle-insets-relative.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-insets-relative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-insets-relative.html)
- [getComputedStyle-insets-relpos-inline.html](https://wpt.fyi/results/css/cssom/getComputedStyle-insets-relpos-inline.html "css/cssom/getComputedStyle-insets-relpos-inline.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-insets-relpos-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-insets-relpos-inline.html)
- [getComputedStyle-insets-static.html](https://wpt.fyi/results/css/cssom/getComputedStyle-insets-static.html "css/cssom/getComputedStyle-insets-static.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-insets-static.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-insets-static.html)
- [getComputedStyle-insets-sticky-container-for-abspos.html](https://wpt.fyi/results/css/cssom/getComputedStyle-insets-sticky-container-for-abspos.html "css/cssom/getComputedStyle-insets-sticky-container-for-abspos.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-insets-sticky-container-for-abspos.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-insets-sticky-container-for-abspos.html)
- [getComputedStyle-insets-sticky.html](https://wpt.fyi/results/css/cssom/getComputedStyle-insets-sticky.html "css/cssom/getComputedStyle-insets-sticky.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-insets-sticky.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-insets-sticky.html)
- [getComputedStyle-layout-dependent-removed-ib-sibling.html](https://wpt.fyi/results/css/cssom/getComputedStyle-layout-dependent-removed-ib-sibling.html "css/cssom/getComputedStyle-layout-dependent-removed-ib-sibling.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-layout-dependent-removed-ib-sibling.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-layout-dependent-removed-ib-sibling.html)
- [getComputedStyle-layout-dependent-replaced-into-ib-split.html](https://wpt.fyi/results/css/cssom/getComputedStyle-layout-dependent-replaced-into-ib-split.html "css/cssom/getComputedStyle-layout-dependent-replaced-into-ib-split.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-layout-dependent-replaced-into-ib-split.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-layout-dependent-replaced-into-ib-split.html)
- [getComputedStyle-line-height.html](https://wpt.fyi/results/css/cssom/getComputedStyle-line-height.html "css/cssom/getComputedStyle-line-height.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-line-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-line-height.html)
- [getComputedStyle-logical-enumeration.html](https://wpt.fyi/results/css/cssom/getComputedStyle-logical-enumeration.html "css/cssom/getComputedStyle-logical-enumeration.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-logical-enumeration.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-logical-enumeration.html)
- [getComputedStyle-margins-roundtrip.html](https://wpt.fyi/results/css/cssom/getComputedStyle-margins-roundtrip.html "css/cssom/getComputedStyle-margins-roundtrip.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-margins-roundtrip.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-margins-roundtrip.html)
- [getComputedStyle-property-order.html](https://wpt.fyi/results/css/cssom/getComputedStyle-property-order.html "css/cssom/getComputedStyle-property-order.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-property-order.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-property-order.html)
- [getComputedStyle-pseudo-checkmark.html](https://wpt.fyi/results/css/cssom/getComputedStyle-pseudo-checkmark.html "css/cssom/getComputedStyle-pseudo-checkmark.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-pseudo-checkmark.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-pseudo-checkmark.html)
- [getComputedStyle-pseudo-picker-icon.html](https://wpt.fyi/results/css/cssom/getComputedStyle-pseudo-picker-icon.html "css/cssom/getComputedStyle-pseudo-picker-icon.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-pseudo-picker-icon.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-pseudo-picker-icon.html)
- [getComputedStyle-pseudo-with-argument.html](https://wpt.fyi/results/css/cssom/getComputedStyle-pseudo-with-argument.html "css/cssom/getComputedStyle-pseudo-with-argument.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-pseudo-with-argument.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-pseudo-with-argument.html)
- [getComputedStyle-pseudo.html](https://wpt.fyi/results/css/cssom/getComputedStyle-pseudo.html "css/cssom/getComputedStyle-pseudo.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-pseudo.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-pseudo.html)
- [getComputedStyle-resolved-colors.html](https://wpt.fyi/results/css/cssom/getComputedStyle-resolved-colors.html "css/cssom/getComputedStyle-resolved-colors.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-resolved-colors.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-resolved-colors.html)
- [getComputedStyle-resolved-min-max-clamping.html](https://wpt.fyi/results/css/cssom/getComputedStyle-resolved-min-max-clamping.html "css/cssom/getComputedStyle-resolved-min-max-clamping.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-resolved-min-max-clamping.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-resolved-min-max-clamping.html)
- [getComputedStyle-resolved-min-size-auto.html](https://wpt.fyi/results/css/cssom/getComputedStyle-resolved-min-size-auto.html "css/cssom/getComputedStyle-resolved-min-size-auto.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-resolved-min-size-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-resolved-min-size-auto.html)
- [getComputedStyle-special-chars-crash.html](https://wpt.fyi/results/css/cssom/getComputedStyle-special-chars-crash.html "css/cssom/getComputedStyle-special-chars-crash.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-special-chars-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-special-chars-crash.html)
- [getComputedStyle-sticky-pos-percent.html](https://wpt.fyi/results/css/cssom/getComputedStyle-sticky-pos-percent.html "css/cssom/getComputedStyle-sticky-pos-percent.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-sticky-pos-percent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-sticky-pos-percent.html)
- [getComputedStyle-width-scroll.tentative.html](https://wpt.fyi/results/css/cssom/getComputedStyle-width-scroll.tentative.html "css/cssom/getComputedStyle-width-scroll.tentative.html")
 [[(live
 test)]](http://wpt.live/css/cssom/getComputedStyle-width-scroll.tentative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/getComputedStyle-width-scroll.tentative.html)

## 8. Utility APIs

### 8.1. The `CSS.escape()` Method-method)

The `CSS` namespace holds useful CSS-related functions that do not
belong elsewhere.

```
[Exposed=Window]
namespace CSS {
 CSSOMString escape(CSSOMString ident);
};
```

Tests

- [CSS-namespace-object-class-string.html](https://wpt.fyi/results/css/cssom/CSS-namespace-object-class-string.html "css/cssom/CSS-namespace-object-class-string.html")
 [[(live
 test)]](http://wpt.live/css/cssom/CSS-namespace-object-class-string.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/CSS-namespace-object-class-string.html)

This was previously specified as an IDL
interface that only held static methods. Switching to an IDL namespace
is \*nearly\* identical, so it's expected that there won't be any compat
concerns. If any are discovered, please report so we can consider
reverting this change.

The [`escape(``ident``)`] operation must
return the result of invoking [serialize an
identifier](#serialize-an-identifier) of `ident`.

For example, to serialize a string for
use as part of a selector, the
[`escape()`](#dom-css-escape) method can be used:

 var element = document.querySelector('#' + CSS.escape(id) + ' > img');

The
[`escape()`](#dom-css-escape) method can also be used for escaping strings, although
it escapes characters that don't strictly need to be escaped:

 var element = document.querySelector('a[href="#' + CSS.escape(fragment) + '"]');

Specifications that define operations on the
[`CSS`](#namespacedef-css) namespace and want to store some state should store the
state on the [current global
object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object)'s [associated
`Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

Tests

- [escape.html](https://wpt.fyi/results/css/cssom/escape.html "css/cssom/escape.html")
 [[(live
 test)]](http://wpt.live/css/cssom/escape.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/escape.html)

## 9. Resolved Values

[`getComputedStyle()`](#dom-window-getcomputedstyle) was historically defined to return the \"computed
value\" of an element or pseudo-element. However, the concept of
\"computed value\" changed between revisions of CSS while the
implementation of
[`getComputedStyle()`](#dom-window-getcomputedstyle) had to remain the same for compatibility with deployed
scripts. To address this issue this specification introduces the concept
of a [resolved value].

The [resolved value](#resolved-value) for a given longhand property can be determined as
follows:

[background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color)\
[border-block-end-color](https://drafts.csswg.org/css-borders-4/#propdef-border-block-end-color)\
[border-block-start-color](https://drafts.csswg.org/css-borders-4/#propdef-border-block-start-color)\
[border-bottom-color](https://drafts.csswg.org/css-borders-4/#propdef-border-bottom-color)\
[border-inline-end-color](https://drafts.csswg.org/css-borders-4/#propdef-border-inline-end-color)\
[border-inline-start-color](https://drafts.csswg.org/css-borders-4/#propdef-border-inline-start-color)\
[border-left-color](https://drafts.csswg.org/css-borders-4/#propdef-border-left-color)\
[border-right-color](https://drafts.csswg.org/css-borders-4/#propdef-border-right-color)\
[border-top-color](https://drafts.csswg.org/css-borders-4/#propdef-border-top-color)\
[box-shadow](https://drafts.csswg.org/css-borders-4/#propdef-box-shadow)\
[caret-color](https://drafts.csswg.org/css-ui-4/#propdef-caret-color)\
[color](https://drafts.csswg.org/css-color-4/#propdef-color)\
[outline-color](https://drafts.csswg.org/css-ui-4/#propdef-outline-color)\
A [resolved value special case property like [color](https://drafts.csswg.org/css-color-4/#propdef-color)] defined in another specification
: The [resolved value](#resolved-value) is the [used
 value](https://drafts.csswg.org/css-cascade-5/#used-value).

[line-height](https://drafts.csswg.org/css2/#propdef-line-height)
: The [resolved value](#resolved-value) is
 [normal](https://drafts.csswg.org/css-inline-3/#valdef-line-height-normal) if the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) is [normal], or the [used
 value](https://drafts.csswg.org/css-cascade-5/#used-value) otherwise.

[block-size](https://drafts.csswg.org/css-logical-1/#propdef-block-size)\
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height)\
[inline-size](https://drafts.csswg.org/css-logical-1/#propdef-inline-size)\
[margin-block-end](https://drafts.csswg.org/css-logical-1/#propdef-margin-block-end)\
[margin-block-start](https://drafts.csswg.org/css-logical-1/#propdef-margin-block-start)\
[margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom)\
[margin-inline-end](https://drafts.csswg.org/css-logical-1/#propdef-margin-inline-end)\
[margin-inline-start](https://drafts.csswg.org/css-logical-1/#propdef-margin-inline-start)\
[margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left)\
[margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right)\
[margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top)\
[padding-block-end](https://drafts.csswg.org/css-logical-1/#propdef-padding-block-end)\
[padding-block-start](https://drafts.csswg.org/css-logical-1/#propdef-padding-block-start)\
[padding-bottom](https://drafts.csswg.org/css-box-4/#propdef-padding-bottom)\
[padding-inline-end](https://drafts.csswg.org/css-logical-1/#propdef-padding-inline-end)\
[padding-inline-start](https://drafts.csswg.org/css-logical-1/#propdef-padding-inline-start)\
[padding-left](https://drafts.csswg.org/css-box-4/#propdef-padding-left)\
[padding-right](https://drafts.csswg.org/css-box-4/#propdef-padding-right)\
[padding-top](https://drafts.csswg.org/css-box-4/#propdef-padding-top)\
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width)\
A [resolved value special case property like [height](https://drafts.csswg.org/css-sizing-3/#propdef-height)] defined in another specification
: If the property applies to the element or pseudo-element and the
 [resolved value](#resolved-value) of the
 [display](https://drafts.csswg.org/css-display-4/#propdef-display) property is not
 [none](https://drafts.csswg.org/css-display-4/#valdef-display-none) or
 [contents](https://drafts.csswg.org/css-display-4/#valdef-display-contents), then the [resolved
 value] is the [used
 value](https://drafts.csswg.org/css-cascade-5/#used-value). Otherwise the [resolved
 value] is the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value).

[bottom](https://drafts.csswg.org/css-position-3/#propdef-bottom)\
[left](https://drafts.csswg.org/css-position-3/#propdef-left)\
[inset-block-end](https://drafts.csswg.org/css-position-3/#propdef-inset-block-end)\
[inset-block-start](https://drafts.csswg.org/css-position-3/#propdef-inset-block-start)\
[inset-inline-end](https://drafts.csswg.org/css-position-3/#propdef-inset-inline-end)\
[inset-inline-start](https://drafts.csswg.org/css-position-3/#propdef-inset-inline-start)\
[right](https://drafts.csswg.org/css-position-3/#propdef-right)\
[top](https://drafts.csswg.org/css-position-3/#propdef-top)\
A [resolved value special case property like [top](https://drafts.csswg.org/css-position-3/#propdef-top)] defined in another specification
: If the property applies to a positioned element and the [resolved
 value](#resolved-value) of
 the
 [display](https://drafts.csswg.org/css-display-4/#propdef-display) property is not
 [none](https://drafts.csswg.org/css-display-4/#valdef-display-none) or
 [contents](https://drafts.csswg.org/css-display-4/#valdef-display-contents), and the property is not over-constrained,
 then the [resolved value] is the [used
 value](https://drafts.csswg.org/css-cascade-5/#used-value). Otherwise the [resolved
 value] is the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value).

A [resolved value special case property] defined in another specification
: As defined in the relevant specification.

Any other property
: The [resolved value](#resolved-value) is the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value).

Tests

- [computed-style-001.html](https://wpt.fyi/results/css/cssom/computed-style-001.html "css/cssom/computed-style-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom/computed-style-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/computed-style-001.html)
- [computed-style-002.html](https://wpt.fyi/results/css/cssom/computed-style-002.html "css/cssom/computed-style-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom/computed-style-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/computed-style-002.html)
- [computed-style-003.html](https://wpt.fyi/results/css/cssom/computed-style-003.html "css/cssom/computed-style-003.html")
 [[(live
 test)]](http://wpt.live/css/cssom/computed-style-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/computed-style-003.html)
- [computed-style-004.html](https://wpt.fyi/results/css/cssom/computed-style-004.html "css/cssom/computed-style-004.html")
 [[(live
 test)]](http://wpt.live/css/cssom/computed-style-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/computed-style-004.html)
- [computed-style-005.html](https://wpt.fyi/results/css/cssom/computed-style-005.html "css/cssom/computed-style-005.html")
 [[(live
 test)]](http://wpt.live/css/cssom/computed-style-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/computed-style-005.html)
- [resolved-border-width.html](https://wpt.fyi/results/css/cssom/resolved-border-width.html "css/cssom/resolved-border-width.html")
 [[(live
 test)]](http://wpt.live/css/cssom/resolved-border-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/resolved-border-width.html)

## 10. IANA Considerations

### 10.1. Default-Style

This section describes a header field for registration in the Permanent
Message Header Field Registry.

Header field name
: [Default-Style]

Applicable protocol
: http

Status
: standard

Author/Change controller
: W3C

Specification document(s)
: This document is the relevant specification.

Related information
: None.

## 11. Change History

This section documents some of the changes between publications of this
specification. This section is not exhaustive. Bug fixes and editorial
changes are generally not listed.

### 11.1. Changes From 17 March 2016

- Serialization of
 [\<resolution\>](https://drafts.csswg.org/css-values-4/#resolution-value) is changed.

- `[CEReactions]` IDL extended attributes are added.

- Resolved value for logical properties are added.

- `getComputedStyle` for
 [display](https://drafts.csswg.org/css-display-4/#propdef-display):
 [contents](https://drafts.csswg.org/css-display-4/#valdef-display-contents) is changed.

- `MediaList.item` now returns serialization.

- `MediaList.item` does not serialize shorthand if importance differs.

- Other specifications are allowed to specify resolved value.

- `index` argument in `insertRule` is now optional.

- `href` attribute of `Stylesheet` and `CSSImportRule` now uses
 `USVString`.

- `CSSOMString` is introduced.

- Serialization of `CSSMediaRule` and `CSSFontFaceRule` is added.

- [Updating
 flag](#cssstyledeclaration-updating-flag) is added to CSS declaration block to avoid
 serialize-and-reparse on style attribute.

- Serialization of a declaration value is now properly defined.

- `getComputedStyle` now returns the style rules of the node's document.

- A
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) is thrown when the pseudo-element passed to
 `getComputedStyle` is unknown or
 [::slotted()](https://drafts.csswg.org/css-shadow-1/#selectordef-slotted).

- [`CSS`](#namespacedef-css) is switched from interface to namespace.

- `setPropertyValue` and `setPropertyPriority` are removed from
 [`CSSStyleDeclaration`](#cssstyledeclaration) due to lack of interest from implementations.

- The `styleSheets` IDL attribute is moved from
 [`Document`](https://dom.spec.whatwg.org/#document) to
 [`DocumentOrShadowRoot`](https://dom.spec.whatwg.org/#documentorshadowroot).

- LinkStyle.sheet now returns `CSSStyleSheet` instead of `StyleSheet`

- Deprecated CSSStyleSheet members are defined.

- The `CSSRule.type` attribute is deprecated.

- Serialization of
 [\<ratio\>](https://drafts.csswg.org/css-values-4/#ratio-value) is added.

- `CSSStyleDeclaration.cssText` now returns the empty string for
 computed style.

- [Custom
 properties](https://drafts.csswg.org/css-variables-1/#custom-property) are included in `getComputedStyle`.

- MathML IDL is introduced.

- Serialization of
 [`CSSKeyframesRule`](https://drafts.csswg.org/css-animations-1/#csskeyframesrule) and
 [`CSSKeyframeRule`](https://drafts.csswg.org/css-animations-1/#csskeyframerule) is added.

- Serialization of media query is changed.

- A shorthand is not serialized if there are longhands with other
 property group / mapping logic in between the longhands of that
 shorthand.

- [`CSSStyleRule`](#cssstylerule) serialization is aware of nesting now.

- Constructable stylesheets is introduced.

### 11.2. Changes From 5 December 2013

- API for alternative stylesheets is removed: `selectedStyleSheetSet`,
 `lastStyleSheetSet`, `preferredStyleSheetSet`, `styleSheetSets`,
 `enableStyleSheetsForSet()` on
 [`Document`](https://dom.spec.whatwg.org/#document).

- The `pseudo()` method on
 [`Element`](https://dom.spec.whatwg.org/#element) and the `PseudoElement` interface is removed.

- The `cascadedStyle`, `defaultStyle`, `rawComputedStyle` and
 `usedStyle` IDL attributes on
 [`Element`](https://dom.spec.whatwg.org/#element) are removed.

- The
 [`cssText`](#dom-cssrule-csstext) IDL attribute's setter on
 [`CSSRule`](#cssrule) is
 changed to do nothing.

- IDL attributes of the form `webkitFoo` (with lowercase `w`) on
 [`CSSStyleDeclaration`](#cssstyledeclaration) are added.

- [`CSSNamespaceRule`](#cssnamespacerule) is changed back to readonly.

- Handling of `@charset` in
 [`insertRule()`](#dom-cssstylesheet-insertrule) is removed.

- `CSSCharsetRule` is removed again.

- Serialization of identifiers and strings is changed.

- Serialization of selectors now supports combinators \"\>\>\" and
 \"\|\|\" and the \"i\" flag in attribute selectors.

- Serialization of :lang() is changed.

- Serialization of
 [\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) and
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) is changed.

- [`setProperty()`](#dom-cssstyledeclaration-setproperty) on
 [`CSSStyleDeclaration`](#cssstyledeclaration) is changed.

### 11.3. Changes From 12 July 2011 To 5 December 2013

- Cross-origin stylesheets are not allowed to be read or changed.
- `CSSCharsetRule` is re-introduced.
- `CSSGroupingRule` and `CSSMarginRule` are introduced.
- `CSSNamespaceRule` is now mutable.
- [Parse](#parse-a-css-declaration-block) and
 [serialize](#serialize-a-css-declaration-block) a CSS declaration block is now defined.
- Shorthands are now supported in
 [`setProperty()`](#dom-cssstyledeclaration-setproperty),
 [`getPropertyValue()`](#dom-cssstyledeclaration-getpropertyvalue), et al.
- `setPropertyValue` and `setPropertyPriority` are added to
 [`CSSStyleDeclaration`](#cssstyledeclaration).
- The `style` and `media` attributes of various interfaces are annotated
 with the `[PutForwards]` WebIDL extended attribute.
- The `pseudo()` method on `Element` is introduced.
- The `PseudoElement` interface is introduced.
- The `cascadedStyle`, `rawComputedStyle` and `usedStyle` attributes on
 `Element` and `PseudoElement` are introduced.
- The [CSS.escape()](#dom-css-escape) static method is introduced.

## 12. Security Considerations

No new security considerations have been reported on this specification.

## 13. Privacy Considerations

No new privacy considerations have been reported on this specification.

## 14. Acknowledgments

The editors would like to thank Alexey Feldgendler, Benjamin Poulain,
Björn Höhrmann, Boris Zbasky, Brian Kardell, Chris Dumez, Christian
Krebs, Daniel Glazman, David Baron, Domenic Denicola, Dominique
Hazael-Massieux, *fantasai*, Hallvord R. M. Steen, Ian Hickson, John
Daggett, Lachlan Hunt, Mike Sherov, Myles C. Maxfield, Morten
Stenshorne, Ms2ger, Nazım Can Altınova, Øyvind Stenhaug, Peter Sloetjes,
Philip Jägenstedt, Philip Taylor, Richard Gibson, Robert O'Callahan,
Simon Sapin, Sjoerd Visscher, Sylvain Galineau, Tarquin Wilton-Jones,
Xidorn Quan, and Zack Weinberg for contributing to this specification.

Additional thanks to Ian Hickson for writing the initial version of the
alternative style sheets API and canonicalization (now serialization)
rules for CSS values.

Tests

- [cssstyledeclaration-csstext-setter.window.js](https://wpt.fyi/results/css/cssom/cssstyledeclaration-csstext-setter.window.js "css/cssom/cssstyledeclaration-csstext-setter.window.js")
 [[(live
 test)]](http://wpt.live/css/cssom/cssstyledeclaration-csstext-setter.window.js)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom/cssstyledeclaration-csstext-setter.window.js)
