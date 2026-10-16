## 1. Introduction

*This section is not normative.*

This module defines the abstract syntax and parsing of CSS stylesheets
and other things which use CSS syntax (such as the HTML `style`
attribute).

It defines algorithms for converting a stream of Unicode [code
points](https://infra.spec.whatwg.org/#code-point) (in other words, text) into a stream of CSS tokens, and
then further into CSS objects such as stylesheets, rules, and
declarations.

### 1.1. Module interactions

This module defines the syntax and parsing of CSS stylesheets. It
supersedes the lexical scanner and grammar defined in CSS 2.1.

## 2. Description of CSS's Syntax

*This section is not normative.*

A CSS document is a series of [style
rules](#style-rule)---​which are
[qualified rules](#qualified-rule) that apply styles to elements in a document---​and
[at-rules](#at-rule)---​which define
special processing rules or values for the CSS document.

A [qualified rule](#qualified-rule) starts with a prelude then has a -wrapped block
containing a sequence of declarations. The meaning of the prelude varies
based on the context that the rule appears in---​for [style
rules](#style-rule), it's a
selector which specifies what elements the declarations will apply to.
Each declaration has a name, followed by a colon and the declaration
value. Declarations are separated by semicolons.

A typical rule might look something like this:

 p > a {
 color: blue;
 text-decoration: underline;
 }

In the above rule, \"`p > a`\" is the selector, which, if the source
document is HTML, selects any
[`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) elements that are children of a
[`p`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-p-element) element.

\"`color: blue`\" is a declaration specifying that, for the elements
that match the selector, their
[color](https://drafts.csswg.org/css-color-4/#propdef-color) property should have the value
[blue](https://drafts.csswg.org/css-color-4/#valdef-color-blue). Similarly, their
[text-decoration](https://drafts.csswg.org/css-text-decor-3/#propdef-text-decoration) property should have the value
[underline](https://drafts.csswg.org/css-text-decor-4/#valdef-text-decoration-line-underline).

[At-rules](#at-rule) are all
different, but they have a basic structure in common. They start with an
\"@\" [code
point](https://infra.spec.whatwg.org/#code-point) followed by their name as a CSS keyword. Some
[at-rules] are simple statements, with their name
followed by more CSS values to specify their behavior, and finally ended
by a semicolon. Others are blocks; they can have CSS values following
their name, but they end with a -wrapped block, similar to a
[qualified rule](#qualified-rule). Even the contents of these blocks are specific to the
given [at-rule]: sometimes they contain a sequence of
declarations, like a [qualified rule]; other
times, they may contain additional blocks, or at-rules, or other
structures altogether.

Here are several examples of [at-rules](#at-rule) that illustrate the varied syntax they may contain.

 @import "my-styles.css";

The
[\@import](https://drafts.csswg.org/css-cascade-6/#at-ruledef-import) [at-rule](#at-rule) is a simple statement. After its name, it takes a
single string or
[url()](https://drafts.csswg.org/css-values-4/#funcdef-url) function to indicate the stylesheet that it
should import.

 @page :left {
 margin-left: 4cm;
 margin-right: 3cm;
 }

The
[\@page](https://drafts.csswg.org/css-page-3/#at-ruledef-page) [at-rule](#at-rule) consists of an optional page selector (the
[:left](https://drafts.csswg.org/css-page-3/#valdef-page-left) pseudoclass), followed by a block of properties
that apply to the page when printed. In this way, it's very similar to a
normal style rule, except that its properties don't apply to any
\"element\", but rather the page itself.

 @media print {
 body { font-size: 10pt }
 }

The
[\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media) [at-rule](#at-rule) begins with a [media
type](https://drafts.csswg.org/mediaqueries-5/#media-type) and a list of optional media queries. Its block
contains entire rules, which are only applied when the
[\@media]s conditions are fulfilled.

Property names and [at-rule](#at-rule) names are always [ident
sequences](#ident-sequence),
which have to start with an [ident-start code
point](#ident-start-code-point), two hyphens, or a hyphen followed by an ident-start
code point, and then can contain zero or more [ident code
points](#ident-code-point).
You can include any [code
point](https://infra.spec.whatwg.org/#code-point) at all, even ones that CSS uses in its syntax, by
[escaping](#escape-codepoint)
it.

The syntax of selectors is defined in the [Selectors
spec](https://www.w3.org/TR/selectors/). Similarly, the syntax of the
wide variety of CSS values is defined in the [Values & Units
spec](https://www.w3.org/TR/css3-values/). The special syntaxes of
individual [at-rules](#at-rule) can
be found in the specs that define them.

### 2.1. Escaping

*This section is not normative.*

Any Unicode [code
point](https://infra.spec.whatwg.org/#code-point) can be included in an [ident
sequence](#ident-sequence) or
quoted string by [escaping] it. CSS escape sequences start with a
backslash (\\), and continue with:

- Any Unicode [code
 point](https://infra.spec.whatwg.org/#code-point) that is not a [hex
 digits](#hex-digit) or a
 [newline](#newline). The escape
 sequence is replaced by that [code point].

- Or one to six [hex digits](#hex-digit), followed by an optional
 [whitespace](#whitespace). The
 escape sequence is replaced by the Unicode [code
 point](https://infra.spec.whatwg.org/#code-point) whose value is given by the hexadecimal digits. This
 optional whitespace allow hexadecimal escape sequences to be followed
 by \"real\" hex digits.

 (#example-cc2d6518) An [ident
 sequence](#ident-sequence)
 with the value \"&B\" could be written as [\\26 B] or
 [\\000026B].

 A \"real\" space after the escape sequence must be doubled.

### 2.2. Error Handling

*This section is not normative.*

When errors occur in CSS, the parser attempts to recover gracefully,
throwing away only the minimum amount of content before returning to
parsing as normal. This is because errors aren't always mistakes---​new
syntax looks like an error to an old parser, and it's useful to be able
to add new syntax to the language without worrying about stylesheets
that include it being completely broken in older UAs.

The precise error-recovery behavior is detailed in the parser itself,
but it's simple enough that a short description is fairly accurate.

- At the \"top level\" of a stylesheet, an
 [\<at-keyword-token\>](#typedef-at-keyword-token) starts an at-rule. Anything else
 starts a qualified rule, and is included in the rule's prelude. This
 may produce an invalid selector, but that's not the concern of the CSS
 parser---​at worst, it means the selector will match nothing.
- Once an at-rule starts, nothing is invalid from the parser's
 standpoint; it's all part of the at-rule's prelude. Encountering a
 [\<semicolon-token\>](#typedef-semicolon-token) ends the at-rule immediately, while
 encountering an opening curly-brace
 [\<{-token\>](#tokendef-open-curly)
 starts the at-rule's body. The at-rule seeks forward, matching blocks
 (content surrounded by (), , or \[\]) until it finds a closing
 curly-brace
 [\<}-token\>](#tokendef-close-curly)
 that isn't matched by anything else or inside of another block. The
 contents of the at-rule are then interpreted according to the
 at-rule's own grammar.
- Qualified rules work similarly, except that semicolons don't end them;
 instead, they are just taken in as part of the rule's prelude. When
 the first block is found, the contents are always interpreted as a
 list of declarations.
- When interpreting a list of declarations, unknown syntax at any point
 causes the parser to throw away whatever declaration it's currently
 building, and seek forward until it finds a semicolon (or the end of
 the block). It then starts fresh, trying to parse a declaration again.
- [(#autoclosing) If the stylesheet ends while any rule,
 declaration, function, string, etc. are still open, everything is
 automatically closed. This doesn't make them invalid, though they may
 be incomplete and thus thrown away when they are verified against
 their grammar.]

 :::
 (#example-84a0b91f) For example, the syntax of the
 [translateX()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-translatex) function is:
 translateX( <translation-value> )

 However, the stylesheet may end with the function unclosed, like:

 .foo { transform: translate(50px

 The CSS parser parses this as a style rule containing one declaration,
 whose value is a function named \"translate\". This matches the above
 grammar, even though the ending token didn't appear in the token
 stream, because by the time the parser is finished, the presence of
 the ending token is no longer possible to determine; all you have is
 the fact that there's a block and a function.
 :::

After each construct (declaration, style rule, at-rule) is parsed, the
user agent checks it against its expected grammar. If it does not match
the grammar, it's [invalid], and gets [ignored] by the UA, which
treats it as if it wasn't there at all.

## 3. Tokenizing and Parsing CSS

User agents must use the parsing rules described in this specification
to generate the
[\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")
trees from text/css resources. Together, these rules define what is
referred to as the CSS parser.

This specification defines the parsing rules for CSS documents, whether
they are syntactically correct or not. Certain points in the parsing
algorithm are said to be [parse errors]. The error handling for
parse errors is well-defined: user agents must either act as described
below when encountering such problems, or must abort processing at the
first error that they encounter for which they do not wish to apply the
rules described below.

Conformance checkers must report at least one parse error condition to
the user if one or more parse error conditions exist in the document and
must not report parse error conditions if none exist in the document.
Conformance checkers may report more than one parse error condition if
more than one parse error condition exists in the document. Conformance
checkers are not required to recover from parse errors, but if they do,
they must recover in the same way as user agents.

Tests

- [trailing-braces.html](https://wpt.fyi/results/css/css-syntax/trailing-braces.html "css/css-syntax/trailing-braces.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/trailing-braces.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/trailing-braces.html)

### 3.1. Overview of the Parsing Model

The input to the CSS parsing process consists of a stream of Unicode
[code
points](https://infra.spec.whatwg.org/#code-point), which is passed through a tokenization stage followed
by a tree construction stage. The output is a CSSStyleSheet object.

 Implementations that do not support scripting do not
have to actually create a CSSOM CSSStyleSheet object, but the CSSOM tree
in such cases is still used as the model for the rest of the
specification.

### 3.2. The input byte stream

When parsing a stylesheet, the stream of Unicode [code
points](https://infra.spec.whatwg.org/#code-point) that comprises the input to the tokenization stage
might be initially seen by the user agent as a stream of bytes
(typically coming over the network or from the local file system). If
so, the user agent must decode these bytes into [code
points] according to a particular character
encoding.

To [decode] a
`stylesheet`'s stream of bytes into a stream of [code
points](https://infra.spec.whatwg.org/#code-point):

1. [Determine the fallback
 encoding](#determine-the-fallback-encoding) of `stylesheet`, and let
 `fallback` be the result.

2. [Decode](https://encoding.spec.whatwg.org/#decode) `stylesheet`'s stream of bytes with
 fallback encoding `fallback`, and return the result.

 The
[decode](https://encoding.spec.whatwg.org/#decode) algorithm gives precedence to a byte order mark (BOM),
and only uses the fallback when none is found.

To [determine the fallback encoding] of a
`stylesheet`:

1. If HTTP or equivalent protocol provides an
 `encoding label` (e.g. via the charset parameter of the
 Content-Type header) for the `stylesheet`, [get an
 encoding](https://encoding.spec.whatwg.org/#concept-encoding-get) from `encoding label`. If that does not
 return failure, return it.

2. Otherwise, check `stylesheet`'s byte stream. If the first
 1024 bytes of the stream begin with the hex sequence

 40 63 68 61 72 73 65 74 20 22 XX* 22 3B

 where each `XX` byte is a value between 0~16~ and 21~16~ inclusive
 or a value between 23~16~ and 7F~16~ inclusive, then [get an
 encoding](https://encoding.spec.whatwg.org/#concept-encoding-get) from a string formed out of the sequence of `XX`
 bytes, interpreted as `ASCII`.

 What does that byte sequence mean?

 The byte sequence above, when decoded as ASCII, is the string
 \"`@charset "…";`\", where the \"...\" is the sequence of bytes
 corresponding to the encoding's label.

 If the return value was `utf-16be` or `utf-16le`, return `utf-8`; if
 it was anything else except failure, return it.

 Why use utf-8 when the declaration says utf-16?

 The bytes of the encoding declaration spell out "`@charset "…";`" in
 ASCII, but UTF-16 is not ASCII-compatible. Either you've typed in
 complete gibberish (like `䁣桡牳整•utf-16be∻`) to get the right
 bytes in the document, which we don't want to encourage, or your
 document is actually in an ASCII-compatible encoding and your
 encoding declaration is lying.

 Either way, defaulting to UTF-8 is a decent answer.

 As well, this mimics the behavior of HTML's `<meta charset>`
 attribute.

 Note that the syntax of an encoding declaration
 *looks like* the syntax of an [at-rule](#at-rule) named
 [\@charset](#at-ruledef-charset), but no such rule actually exists, and the rules
 for how you can write it are much more restrictive than they would
 normally be for recognizing such a rule. A number of things you can
 do in CSS that would produce a valid
 [\@charset] rule (if one
 existed), such as using multiple spaces, comments, or single quotes,
 will cause the encoding declaration to not be recognized. This
 behavior keeps the encoding declaration as simple as possible, and
 thus maximizes the likelihood of it being implemented correctly.

3. Otherwise, if an [environment
 encoding](#environment-encoding) is provided by the referring document, return it.

4. Otherwise, return `utf-8`.

Though UTF-8 is the default encoding for the web, and many newer
web-based file formats assume or require UTF-8 encoding, CSS was created
before it was clear which encoding would win, and thus can't
automatically assume the stylesheet is UTF-8.

Stylesheet authors *should* author their stylesheets in UTF-8, and
ensure that either an HTTP header (or equivalent method) declares the
encoding of the stylesheet to be UTF-8, or that the referring document
declares its encoding to be UTF-8. (In HTML, this is done by adding a
`<meta charset=utf-8>` element to the head of the document.)

If neither of these options are available, authors should begin the
stylesheet with a UTF-8 BOM or the exact characters

 @charset "utf-8";

Document languages that refer to CSS stylesheets that are decoded from
bytes may define an [environment encoding] for each such stylesheet, which
is used as a fallback when other encoding hints are not available or can
not be used.

The concept of [environment
encoding](#environment-encoding) only exists for compatibility with legacy content. New
formats and new linking mechanisms **should not** provide an
[environment encoding], so the
stylesheet defaults to UTF-8 instead in the absence of more explicit
information.

 [\[HTML\]](#biblio-html "HTML")
defines [the environment encoding for
`<link rel=stylesheet>`](https://html.spec.whatwg.org/multipage/links.html#link-type-stylesheet).

[\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")
defines [the environment encoding for
`<xml-stylesheet?>`](https://drafts.csswg.org/cssom/#requirements-on-user-agents-implementing-the-xml-stylesheet-processing-instruction).

[\[CSS-CASCADE-3\]](#biblio-css-cascade-3 "CSS Cascading and Inheritance Level 3")
defines [the environment encoding for
`@import`](https://drafts.csswg.org/css-cascade-6/#at-ruledef-import).

### 3.3. Preprocessing the input stream

The [input stream] consists of the [filtered code
points](#css-filter-code-points) pushed into it as the input byte stream is decoded.

To [filter code points] from a stream
of (unfiltered) [code
points](https://infra.spec.whatwg.org/#code-point) `input`:

- Replace any U+000D CARRIAGE RETURN (CR) [code
 points](https://infra.spec.whatwg.org/#code-point), U+000C FORM FEED (FF) [code
 points], or pairs of U+000D CARRIAGE RETURN
 (CR) followed by U+000A LINE FEED (LF) in `input` by a
 single U+000A LINE FEED (LF) [code point].

- Replace any U+0000 NULL or
 [surrogate](https://infra.spec.whatwg.org/#surrogate) [code
 points](https://infra.spec.whatwg.org/#code-point) in `input` with U+FFFD REPLACEMENT
 CHARACTER (�).

 The only way to produce a
 [surrogate](https://infra.spec.whatwg.org/#surrogate) [code
 point](https://infra.spec.whatwg.org/#code-point) in CSS content is by directly assigning a `DOMString`
 with one in it via an OM operation.

- [input-preprocessing.html](https://wpt.fyi/results/css/css-syntax/input-preprocessing.html "css/css-syntax/input-preprocessing.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/input-preprocessing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/input-preprocessing.html)

## 4. Tokenization

To [tokenize] a stream of [code
points](https://infra.spec.whatwg.org/#code-point) into a stream of CSS tokens `input`,
repeatedly [consume a
token](#tokenizer-consume-a-token) from `input` until an
[\<EOF-token\>](#typedef-eof-token) is reached, pushing each of the returned
tokens into a stream.

 Each call to the [consume a
token](#tokenizer-consume-a-token) algorithm returns a single token, so it can also be
used \"on-demand\" to tokenize a stream of [code
points](https://infra.spec.whatwg.org/#code-point) *during* parsing, if so desired.

The output of tokenization step is a stream of zero or more of the
following tokens: [\<ident-token\>],
[\<function-token\>],
[\<at-keyword-token\>], [\<hash-token\>],
[\<string-token\>],
[\<bad-string-token\>], [\<url-token\>],
[\<bad-url-token\>], [\<delim-token\>],
[\<number-token\>],
[\<percentage-token\>],
[\<dimension-token\>],
[\<unicode-range-token\>],
[\<whitespace-token\>], [\<CDO-token\>],
[\<CDC-token\>], [\<colon-token\>],
[\<semicolon-token\>], [\<comma-token\>],
[\<\[-token\>], [\<\]-token\>],
[\<(-token\>], [\<)-token\>],
[\<{-token\>], and [\<}-token\>].

- [\<ident-token\>](#typedef-ident-token),
 [\<function-token\>](#typedef-function-token),
 [\<at-keyword-token\>](#typedef-at-keyword-token),
 [\<hash-token\>](#typedef-hash-token),
 [\<string-token\>](#typedef-string-token), and
 [\<url-token\>](#typedef-url-token) have a value composed of zero or more
 [code
 points](https://infra.spec.whatwg.org/#code-point). Additionally, hash tokens have a type flag set to
 either \"id\" or \"unrestricted\". The type flag defaults to
 \"unrestricted\" if not otherwise set.

- [\<delim-token\>](#typedef-delim-token) has a value composed of a single
 [code
 point](https://infra.spec.whatwg.org/#code-point).

- [\<number-token\>](#typedef-number-token),
 [\<percentage-token\>](#typedef-percentage-token), and
 [\<dimension-token\>](#typedef-dimension-token) have a numeric value, and an
 optional sign character set to either \"+\" or \"-\" (or nothing).

 [\<number-token\>](#typedef-number-token) and
 [\<dimension-token\>](#typedef-dimension-token) additionally have a type flag set
 to either \"integer\" or \"number\". The type flag defaults to
 \"integer\" if not otherwise set.
 [\<dimension-token\>]
 additionally have a unit composed of one or more [code
 points](https://infra.spec.whatwg.org/#code-point).

- [\<unicode-range-token\>](#typedef-unicode-range-token) has a starting and ending code
 point. It represents an inclusive range of codepoints (including both
 the start and end). If the ending code point is before the starting
 code point, it represents an empty range.

 The type flag of hash tokens is used in the Selectors
syntax
[\[SELECT\]](#biblio-select "Selectors Level 3").
Only hash tokens with the \"id\" type are valid [ID
selectors](https://www.w3.org/TR/selectors/#id-selectors).

### 4.1. Token Railroad Diagrams

*This section is non-normative.*

This section presents an informative view of the tokenizer, in the form
of railroad diagrams. Railroad diagrams are more compact than an
explicit parser, but often easier to read than a regular expression.

These diagrams are *informative* and *incomplete*; they describe the
grammar of \"correct\" tokens, but do not describe error-handling at
all. They are provided solely to make it easier to get an intuitive
grasp of the syntax of each token.

Diagrams with names such as *\<foo-token\>* represent tokens. The rest
are productions referred to by other diagrams.

comment

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSI4MCIgdmlld2JveD0iMCAwIDUxMi4wIDgwIiB3aWR0aD0iNTEyLjAiPgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTIwIDMwdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDAgNDBoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTUwIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTg3LjAgNDBoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjM3IiB4PSI1MCIgeT0iMjkiIC8+CiAgICAgICAgIDx0ZXh0IHg9IjY4LjUiIHk9IjQ0Ij4vKjwvdGV4dD4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTg3LjAgNDBoMTAiIC8+CiAgICAgICAgPGc+CiAgICAgICAgIDxwYXRoIGQ9Ik05Ny4wIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQxNS4wIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTk3LjAgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMTcuMCAyMGgyNzguMCIgLz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMzk1LjAgMjBhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTk3LjAgNDBoMjAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTExNy4wIDQwaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zOTUuMCA0MGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMTE3LjAgNDBoMTAiIC8+CiAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNMTI3LjAgNDBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zODUuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjI1OCIgeD0iMTI3IiB5PSIyOSIgLz4KICAgICAgICAgICA8dGV4dCB4PSIyNTYiIHk9IjQ0Ij5hbnl0aGluZyBidXQgKiBmb2xsb3dlZCBieSAvPC90ZXh0PgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTM4NS4wIDQwaDEwIiAvPgogICAgICAgICAgPHBhdGggZD0iTTEyNy4wIDQwYTEwIDEwIDAgMCAwIC0xMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTEyNy4wIDYwaDI1OC4wIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTM4NS4wIDYwYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTM5NS4wIDQwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDE1LjAgNDBoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTQyNS4wIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQ2Mi4wIDQwaDAuMCIgLz4KICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIzNyIgeD0iNDI1IiB5PSIyOSIgLz4KICAgICAgICAgPHRleHQgeD0iNDQzLjUiIHk9IjQ0Ij4qLzwvdGV4dD4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTQ2Mi4wIDQwaDEwIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0gNDcyLjAgNDAgaCAyMCBtIC0xMCAtMTAgdiAyMCBtIDEwIC0yMCB2IDIwIiAvPgogICAgICAgPC9nPgogICAgICA8L3N2Zz4=)
 :::

newline

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxNTIiIHZpZXdib3g9IjAgMCAxNzQuMCAxNTIiIHdpZHRoPSIxNzQuMCI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMjF2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMTM0LjAgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWgyMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDMxaDguNSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMDUuNSAzMWg4LjUiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjM3IiB4PSI2OC41IiB5PSIyMCIgLz4KICAgICAgICAgIDx0ZXh0IHg9Ijg3IiB5PSIzNSI+XG48L3RleHQ+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTExNC4wIDMxaDIwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWExMCAxMCAwIDAgMSAxMCAxMHYxMGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDYxaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMTQuMCA2MWgwLjAiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjU0IiB4PSI2MCIgeT0iNTAiIC8+CiAgICAgICAgICA8dGV4dCB4PSI4NyIgeT0iNjUiPlxyXG48L3RleHQ+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTExNC4wIDYxYTEwIDEwIDAgMCAwIDEwIC0xMHYtMTBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWExMCAxMCAwIDAgMSAxMCAxMHY0MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDkxaDguNSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMDUuNSA5MWg4LjUiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjM3IiB4PSI2OC41IiB5PSI4MCIgLz4KICAgICAgICAgIDx0ZXh0IHg9Ijg3IiB5PSI5NSI+XHI8L3RleHQ+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTExNC4wIDkxYTEwIDEwIDAgMCAwIDEwIC0xMHYtNDBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWExMCAxMCAwIDAgMSAxMCAxMHY3MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDEyMWg4LjUiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMTA1LjUgMTIxaDguNSIgLz4KICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMzciIHg9IjY4LjUiIHk9IjExMCIgLz4KICAgICAgICAgIDx0ZXh0IHg9Ijg3IiB5PSIxMjUiPlxmPC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0xMTQuMCAxMjFhMTAgMTAgMCAwIDAgMTAgLTEwdi03MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0gMTM0LjAgMzEgaCAyMCBtIC0xMCAtMTAgdiAyMCBtIDEwIC0yMCB2IDIwIiAvPgogICAgICAgPC9nPgogICAgICA8L3N2Zz4=)
 :::

whitespace

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxMjIiIHZpZXdib3g9IjAgMCAxOTkuNSAxMjIiIHdpZHRoPSIxOTkuNSI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMjF2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMTU5LjUgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWgyMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDMxaDguNSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMzEuMCAzMWg4LjUiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjYyLjUiIHg9IjY4LjUiIHk9IjIwIiAvPgogICAgICAgICAgPHRleHQgeD0iOTkuNzUiIHk9IjM1Ij5zcGFjZTwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMTM5LjUgMzFoMjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik00MC4wIDMxYTEwIDEwIDAgMCAxIDEwIDEwdjEwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgNjFoMjEuMjUiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMTE4LjI1IDYxaDIxLjI1IiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIzNyIgeD0iODEuMjUiIHk9IjUwIiAvPgogICAgICAgICAgPHRleHQgeD0iOTkuNzUiIHk9IjY1Ij5cdDwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMTM5LjUgNjFhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik00MC4wIDMxYTEwIDEwIDAgMCAxIDEwIDEwdjQwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDkxaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMzkuNSA5MWgwLjAiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNzkuNSIgeD0iNjAiIHk9IjgwIiAvPgogICAgICAgICAgPHRleHQgeD0iOTkuNzUiIHk9Ijk1Ij5uZXdsaW5lPC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0xMzkuNSA5MWExMCAxMCAwIDAgMCAxMCAtMTB2LTQwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTSAxNTkuNSAzMSBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

hex digit

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSI2MiIgdmlld2JveD0iMCAwIDIzOS4wIDYyIiB3aWR0aD0iMjM5LjAiPgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTIwIDIxdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgIDxwYXRoIGQ9Ik01MCAzMWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0xODkuMCAzMWgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxMzkiIHg9IjUwIiB5PSIyMCIgLz4KICAgICAgICAgPHRleHQgeD0iMTE5LjUiIHk9IjM1Ij4wLTkgYS1mIG9yIEEtRjwvdGV4dD4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTE4OS4wIDMxaDEwIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0gMTk5LjAgMzEgaCAyMCBtIC0xMCAtMTAgdiAyMCBtIDEwIC0yMCB2IDIwIiAvPgogICAgICAgPC9nPgogICAgICA8L3N2Zz4=)
 :::

escape

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxMTYiIHZpZXdib3g9IjAgMCA0NDAuMCAxMTYiIHdpZHRoPSI0NDAuMCI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMjF2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik00MCAzMWgxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNNTAgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNzguNSAzMWgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iNTAiIHk9IjIwIiAvPgogICAgICAgICA8dGV4dCB4PSI2NC4yNSIgeT0iMzUiPlw8L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik03OC41IDMxaDEwIiAvPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNODguNSAzMWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik00MDAuMCAzMWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik04OC41IDMxaDIwIiAvPgogICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMDguNSAzMWgyMy43NSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zNTYuMjUgMzFoMjMuNzUiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMjI0IiB4PSIxMzIuMjUiIHk9IjIwIiAvPgogICAgICAgICAgPHRleHQgeD0iMjQ0LjI1IiB5PSIzNSI+bm90IG5ld2xpbmUgb3IgaGV4IGRpZ2l0PC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0zODAuMCAzMWgyMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTg4LjUgMzFhMTAgMTAgMCAwIDEgMTAgMTB2MTBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTEwOC41IDYxaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zODAuMCA2MWgwLjAiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNMTA4LjUgNjFoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMjUuMCA2MWgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTEwOC41IDYxaDEwIiAvPgogICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICA8cGF0aCBkPSJNMTE4LjUgNjFoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjE1LjAgNjFoMC4wIiAvPgogICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iOTYuNSIgeD0iMTE4LjUiIHk9IjUwIiAvPgogICAgICAgICAgICA8dGV4dCB4PSIxNjYuNzUiIHk9IjY1Ij5oZXggZGlnaXQ8L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMTUuMCA2MWgxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMTE4LjUgNjFhMTAgMTAgMCAwIDAgLTEwIDEwdjdhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xMTguNSA4OGgxMS43NSIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTIwMy4yNSA4OGgxMS43NSIgLz4KICAgICAgICAgICAgPHRleHQgY2xhc3M9ImNvbW1lbnQiIHg9IjE2Ni43NSIgeT0iOTMiPjEtNiB0aW1lczwvdGV4dD4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTIxNS4wIDg4YTEwIDEwIDAgMCAwIDEwIC0xMHYtN2ExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTIyNS4wIDYxaDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTIzNS4wIDYxaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzgwLjAgNjFoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMzUuMCA2MWgyMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTI1NS4wIDYxaDEwNS4wIiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMzYwLjAgNjFoMjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTIzNS4wIDYxYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNTUuMCA4MWgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNjAuMCA4MWgwLjAiIC8+CiAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxMDUiIHg9IjI1NSIgeT0iNzAiIC8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjMwNy41IiB5PSI4NSI+d2hpdGVzcGFjZTwvdGV4dD4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTM2MC4wIDgxYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMzgwLjAgNjFhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0gNDAwLjAgMzEgaCAyMCBtIC0xMCAtMTAgdiAyMCBtIDEwIC0yMCB2IDIwIiAvPgogICAgICAgPC9nPgogICAgICA8L3N2Zz4=)
 :::

[\<whitespace-token\>](#typedef-whitespace-token)

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSI3MSIgdmlld2JveD0iMCAwIDIyNS4wIDcxIiB3aWR0aD0iMjI1LjAiPgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTIwIDIxdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMTAiIC8+CiAgICAgICAgPGc+CiAgICAgICAgIDxwYXRoIGQ9Ik01MCAzMWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0xNzUuMCAzMWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik01MC4wIDMxaDEwIiAvPgogICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDMxaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xNjUuMCAzMWgwLjAiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTA1IiB4PSI2MCIgeT0iMjAiIC8+CiAgICAgICAgICA8dGV4dCB4PSIxMTIuNSIgeT0iMzUiPndoaXRlc3BhY2U8L3RleHQ+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTE2NS4wIDMxaDEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNjAuMCAzMWExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCA1MWgxMDUuMCIgLz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMTY1LjAgNTFhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTE3NS4wIDMxaDEwIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0gMTg1LjAgMzEgaCAyMCBtIC0xMCAtMTAgdiAyMCBtIDEwIC0yMCB2IDIwIiAvPgogICAgICAgPC9nPgogICAgICA8L3N2Zz4=)
 :::

(#ws*-diagram)ws\*

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSI4MCIgdmlld2JveD0iMCAwIDMxMy4wIDgwIiB3aWR0aD0iMzEzLjAiPgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTIwIDMwdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTQwIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTI3My4wIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQwLjAgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDIwaDE5My4wIiAvPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0yNTMuMCAyMGExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCA0MGgyMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCA0MGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMjUzLjAgNDBoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgNDBoMTAiIC8+CiAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNNzAuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTI0My4wIDQwaDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTczIiB4PSI3MCIgeT0iMjkiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMTU2LjUiIHk9IjQ0Ij4mbHQ7d2hpdGVzcGFjZS10b2tlbiZndDs8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMjQzLjAgNDBoMTAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNzAuMCA0MGExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik03MC4wIDYwaDE3My4wIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTI0My4wIDYwYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTI1My4wIDQwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNIDI3My4wIDQwIGggMjAgbSAtMTAgLTEwIHYgMjAgbSAxMCAtMjAgdiAyMCIgLz4KICAgICAgIDwvZz4KICAgICAgPC9zdmc+)
 :::

[\<ident-token\>](#typedef-ident-token)

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxMzAiIHZpZXdib3g9IjAgMCA3OTMuNSAxMzAiIHdpZHRoPSI3OTMuNSI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgNTF2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNNDAgNjFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMzk1LjUgNjFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCA2MWExMCAxMCAwIDAgMCAxMCAtMTB2LTEwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDMxaDEzOS4yNSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yMzYuMjUgMzFoMTM5LjI1IiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIzNyIgeD0iMTk5LjI1IiB5PSIyMCIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjIxNy43NSIgeT0iMzUiPi0tPC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0zNzUuNSAzMWExMCAxMCAwIDAgMSAxMCAxMHYxMGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQwLjAgNjFoMjAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgNjFoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTM3NS41IDYxaDAuMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDYxaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgNjFoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDYxaDIwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNODAuMCA2MWgyOC41IiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMTA4LjUgNjFoMjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTYwLjAgNjFhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgICA8cGF0aCBkPSJNODAuMCA4MWgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xMDguNSA4MWgwLjAiIC8+CiAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iODAiIHk9IjcwIiAvPgogICAgICAgICAgICA8dGV4dCB4PSI5NC4yNSIgeT0iODUiPi08L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0xMDguNSA4MWExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgNjFoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNzUuNSA2MWgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTEyOC41IDYxaDIwIiAvPgogICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICA8cGF0aCBkPSJNMTQ4LjUgNjFoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMzU1LjUgNjFoMC4wIiAvPgogICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMjA3IiB4PSIxNDguNSIgeT0iNTAiIC8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjI1MiIgeT0iNjUiPmEteiBBLVogXyBvciBub24tQVNDSUk8L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNTUuNSA2MWgyMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgNjFhMTAgMTAgMCAwIDEgMTAgMTB2MTBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xNDguNSA5MWg2OC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjg3LjUgOTFoNjguMCIgLz4KICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjcxIiB4PSIyMTYuNSIgeT0iODAiIC8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjI1MiIgeT0iOTUiPmVzY2FwZTwvdGV4dD4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTM1NS41IDkxYTEwIDEwIDAgMCAwIDEwIC0xMHYtMTBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0zNzUuNSA2MWgyMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPGc+CiAgICAgICAgIDxwYXRoIGQ9Ik0zOTUuNSA2MWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik03NTMuNSA2MWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0zOTUuNSA2MWExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTQxNS41IDQxaDMxOC4wIiAvPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik03MzMuNSA0MWExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNMzk1LjUgNjFoMjAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTQxNS41IDYxaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik03MzMuNSA2MWgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNDE1LjUgNjFoMTAiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNNDI1LjUgNjFoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik03MjMuNSA2MWgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTQyNS41IDYxaDIwIiAvPgogICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICA8cGF0aCBkPSJNNDQ1LjUgNjFoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNzAzLjUgNjFoMC4wIiAvPgogICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMjU4IiB4PSI0NDUuNSIgeT0iNTAiIC8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjU3NC41IiB5PSI2NSI+YS16IEEtWiAwLTkgXyAtIG9yIG5vbi1BU0NJSTwvdGV4dD4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTcwMy41IDYxaDIwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik00MjUuNSA2MWExMCAxMCAwIDAgMSAxMCAxMHYxMGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgPHBhdGggZD0iTTQ0NS41IDkxaDkzLjUiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik02MTAuMCA5MWg5My41IiAvPgogICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNzEiIHg9IjUzOSIgeT0iODAiIC8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjU3NC41IiB5PSI5NSI+ZXNjYXBlPC90ZXh0PgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNNzAzLjUgOTFhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNNzIzLjUgNjFoMTAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNDI1LjUgNjFhMTAgMTAgMCAwIDAgLTEwIDEwdjI5YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTQyNS41IDExMGgyOTguMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik03MjMuNSAxMTBhMTAgMTAgMCAwIDAgMTAgLTEwdi0yOWExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik03MzMuNSA2MWgyMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTSA3NTMuNSA2MSBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

[\<function-token\>](#typedef-function-token)

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSI2MiIgdmlld2JveD0iMCAwIDI3OS4wIDYyIiB3aWR0aD0iMjc5LjAiPgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTIwIDIxdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgIDxwYXRoIGQ9Ik01MCAzMWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0xODAuNSAzMWgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxMzAuNSIgeD0iNTAiIHk9IjIwIiAvPgogICAgICAgICA8dGV4dCB4PSIxMTUuMjUiIHk9IjM1Ij4mbHQ7aWRlbnQtdG9rZW4mZ3Q7PC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMTgwLjUgMzFoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTTE5MC41IDMxaDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgIDxwYXRoIGQ9Ik0yMDAuNSAzMWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0yMjkuMCAzMWgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iMjAwLjUiIHk9IjIwIiAvPgogICAgICAgICA8dGV4dCB4PSIyMTQuNzUiIHk9IjM1Ij4oPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMjI5LjAgMzFoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTSAyMzkuMCAzMSBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

[\<at-keyword-token\>](#typedef-at-keyword-token)

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSI2MiIgdmlld2JveD0iMCAwIDI3OS4wIDYyIiB3aWR0aD0iMjc5LjAiPgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTIwIDIxdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTUwIDMxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTc4LjUgMzFoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjUwIiB5PSIyMCIgLz4KICAgICAgICAgPHRleHQgeD0iNjQuMjUiIHk9IjM1Ij5APC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNzguNSAzMWgxMCIgLz4KICAgICAgICA8cGF0aCBkPSJNODguNSAzMWgxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTk4LjUgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMjI5LjAgMzFoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTMwLjUiIHg9Ijk4LjUiIHk9IjIwIiAvPgogICAgICAgICA8dGV4dCB4PSIxNjMuNzUiIHk9IjM1Ij4mbHQ7aWRlbnQtdG9rZW4mZ3Q7PC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMjI5LjAgMzFoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTSAyMzkuMCAzMSBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

[\<hash-token\>](#typedef-hash-token)

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxMDAiIHZpZXdib3g9IjAgMCA0NjYuNSAxMDAiIHdpZHRoPSI0NjYuNSI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMjF2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik00MCAzMWgxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNNTAgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNzguNSAzMWgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iNTAiIHk9IjIwIiAvPgogICAgICAgICA8dGV4dCB4PSI2NC4yNSIgeT0iMzUiPiM8L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik03OC41IDMxaDEwIiAvPgogICAgICAgIDxwYXRoIGQ9Ik04OC41IDMxaDEwIiAvPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNOTguNSAzMWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik00MTYuNSAzMWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik05OC41IDMxaDEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMDguNSAzMWgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNDA2LjUgMzFoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTEwOC41IDMxaDIwIiAvPgogICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTEyOC41IDMxaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzg2LjUgMzFoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIyNTgiIHg9IjEyOC41IiB5PSIyMCIgLz4KICAgICAgICAgICA8dGV4dCB4PSIyNTcuNSIgeT0iMzUiPmEteiBBLVogMC05IF8gLSBvciBub24tQVNDSUk8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMzg2LjUgMzFoMjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMTA4LjUgMzFhMTAgMTAgMCAwIDEgMTAgMTB2MTBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgNjFoOTMuNSIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjkzLjAgNjFoOTMuNSIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNzEiIHg9IjIyMiIgeT0iNTAiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMjU3LjUiIHk9IjY1Ij5lc2NhcGU8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMzg2LjUgNjFhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTQwNi41IDMxaDEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNMTA4LjUgMzFhMTAgMTAgMCAwIDAgLTEwIDEwdjI5YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMDguNSA4MGgyOTguMCIgLz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNNDA2LjUgODBhMTAgMTAgMCAwIDAgMTAgLTEwdi0yOWExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDE2LjUgMzFoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTSA0MjYuNSAzMSBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

[\<string-token\>](#typedef-string-token)

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIyNDYiIHZpZXdib3g9IjAgMCA0NzAuMCAyNDYiIHdpZHRoPSI0NzAuMCI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMzB2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNNDAgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDMwLjAgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCA0MGgyMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCA0MGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNDEwLjAgNDBoMC4wIiAvPgogICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNNjAuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTg4LjUgNDBoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iNjAiIHk9IjI5IiAvPgogICAgICAgICAgIDx0ZXh0IHg9Ijc0LjI1IiB5PSI0NCI+JnF1b3Q7PC90ZXh0PgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTg4LjUgNDBoMTAiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNOTguNSA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTM3MS41IDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNOTguNSA0MGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xMTguNSAyMGgyMzMuMCIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTM1MS41IDIwYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTk4LjUgNDBoMjAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xMTguNSA0MGgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNTEuNSA0MGgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xMTguNSA0MGgxMCIgLz4KICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgNDBoMC4wIiAvPgogICAgICAgICAgICAgPHBhdGggZD0iTTM0MS41IDQwaDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0xMjguNSA0MGgyMCIgLz4KICAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgIDxwYXRoIGQ9Ik0xNDguNSA0MGgwLjAiIC8+CiAgICAgICAgICAgICAgPHBhdGggZD0iTTMyMS41IDQwaDAuMCIgLz4KICAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTczIiB4PSIxNDguNSIgeT0iMjkiIC8+CiAgICAgICAgICAgICAgPHRleHQgeD0iMjM1IiB5PSI0NCI+bm90ICZxdW90OyBcIG9yIG5ld2xpbmU8L3RleHQ+CiAgICAgICAgICAgICA8L2c+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMzIxLjUgNDBoMjAiIC8+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgNDBhMTAgMTAgMCAwIDEgMTAgMTB2MTBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgICA8cGF0aCBkPSJNMTQ4LjUgNzBoNTEuMCIgLz4KICAgICAgICAgICAgICA8cGF0aCBkPSJNMjcwLjUgNzBoNTEuMCIgLz4KICAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNzEiIHg9IjE5OS41IiB5PSI1OSIgLz4KICAgICAgICAgICAgICA8dGV4dCB4PSIyMzUiIHk9Ijc0Ij5lc2NhcGU8L3RleHQ+CiAgICAgICAgICAgICA8L2c+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMzIxLjUgNzBhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgNDBhMTAgMTAgMCAwIDEgMTAgMTB2NDBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgICA8Zz4KICAgICAgICAgICAgICA8cGF0aCBkPSJNMTQ4LjUgMTAwaDIyLjUiIC8+CiAgICAgICAgICAgICAgPHBhdGggZD0iTTI5OS4wIDEwMGgyMi41IiAvPgogICAgICAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICAgICAgIDxwYXRoIGQ9Ik0xNzEuMCAxMDBoMC4wIiAvPgogICAgICAgICAgICAgICA8cGF0aCBkPSJNMTk5LjUgMTAwaDAuMCIgLz4KICAgICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSIxNzEiIHk9Ijg5IiAvPgogICAgICAgICAgICAgICA8dGV4dCB4PSIxODUuMjUiIHk9IjEwNCI+XDwvdGV4dD4KICAgICAgICAgICAgICA8L2c+CiAgICAgICAgICAgICAgPHBhdGggZD0iTTE5OS41IDEwMGgxMCIgLz4KICAgICAgICAgICAgICA8cGF0aCBkPSJNMjA5LjUgMTAwaDEwIiAvPgogICAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgICA8cGF0aCBkPSJNMjE5LjUgMTAwaDAuMCIgLz4KICAgICAgICAgICAgICAgPHBhdGggZD0iTTI5OS4wIDEwMGgwLjAiIC8+CiAgICAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI3OS41IiB4PSIyMTkuNSIgeT0iODkiIC8+CiAgICAgICAgICAgICAgIDx0ZXh0IHg9IjI1OS4yNSIgeT0iMTA0Ij5uZXdsaW5lPC90ZXh0PgogICAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMjEuNSAxMDBhMTAgMTAgMCAwIDAgMTAgLTEwdi00MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTM0MS41IDQwaDEwIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgNDBhMTAgMTAgMCAwIDAgLTEwIDEwdjU5YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICA8Zz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0xMjguNSAxMTloMjEzLjAiIC8+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTM0MS41IDExOWExMCAxMCAwIDAgMCAxMCAtMTB2LTU5YTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNTEuNSA0MGgyMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zNzEuNSA0MGgxMCIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTM4MS41IDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNNDEwLjAgNDBoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iMzgxLjUiIHk9IjI5IiAvPgogICAgICAgICAgIDx0ZXh0IHg9IjM5NS43NSIgeT0iNDQiPiZxdW90OzwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNNDEwLjAgNDBoMjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik00MC4wIDQwYTEwIDEwIDAgMCAxIDEwIDEwdjg3YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDE0N2gwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNDEwLjAgMTQ3aDAuMCIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTYwLjAgMTQ3aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNODguNSAxNDdoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iNjAiIHk9IjEzNiIgLz4KICAgICAgICAgICA8dGV4dCB4PSI3NC4yNSIgeT0iMTUxIj4mIzM5OzwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik04OC41IDE0N2gxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik05OC41IDE0N2gwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTM3MS41IDE0N2gwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTk4LjUgMTQ3YTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTExOC41IDEyN2gyMzMuMCIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTM1MS41IDEyN2ExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik05OC41IDE0N2gyMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTExOC41IDE0N2gwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNTEuNSAxNDdoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMTE4LjUgMTQ3aDEwIiAvPgogICAgICAgICAgICA8Zz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0xMjguNSAxNDdoMC4wIiAvPgogICAgICAgICAgICAgPHBhdGggZD0iTTM0MS41IDE0N2gwLjAiIC8+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgMTQ3aDIwIiAvPgogICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICAgPHBhdGggZD0iTTE0OC41IDE0N2gwLjAiIC8+CiAgICAgICAgICAgICAgPHBhdGggZD0iTTMyMS41IDE0N2gwLjAiIC8+CiAgICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjE3MyIgeD0iMTQ4LjUiIHk9IjEzNiIgLz4KICAgICAgICAgICAgICA8dGV4dCB4PSIyMzUiIHk9IjE1MSI+bm90ICYjMzk7IFwgb3IgbmV3bGluZTwvdGV4dD4KICAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMjEuNSAxNDdoMjAiIC8+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgMTQ3YTEwIDEwIDAgMCAxIDEwIDEwdjEwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICAgPHBhdGggZD0iTTE0OC41IDE3N2g1MS4wIiAvPgogICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNzAuNSAxNzdoNTEuMCIgLz4KICAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNzEiIHg9IjE5OS41IiB5PSIxNjYiIC8+CiAgICAgICAgICAgICAgPHRleHQgeD0iMjM1IiB5PSIxODEiPmVzY2FwZTwvdGV4dD4KICAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMjEuNSAxNzdhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgMTQ3YTEwIDEwIDAgMCAxIDEwIDEwdjQwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICAgPHBhdGggZD0iTTE0OC41IDIwN2gyMi41IiAvPgogICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yOTkuMCAyMDdoMjIuNSIgLz4KICAgICAgICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgICAgICA8cGF0aCBkPSJNMTcxLjAgMjA3aDAuMCIgLz4KICAgICAgICAgICAgICAgPHBhdGggZD0iTTE5OS41IDIwN2gwLjAiIC8+CiAgICAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iMTcxIiB5PSIxOTYiIC8+CiAgICAgICAgICAgICAgIDx0ZXh0IHg9IjE4NS4yNSIgeT0iMjExIj5cPC90ZXh0PgogICAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgICA8cGF0aCBkPSJNMTk5LjUgMjA3aDEwIiAvPgogICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMDkuNSAyMDdoMTAiIC8+CiAgICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMTkuNSAyMDdoMC4wIiAvPgogICAgICAgICAgICAgICA8cGF0aCBkPSJNMjk5LjAgMjA3aDAuMCIgLz4KICAgICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9Ijc5LjUiIHg9IjIxOS41IiB5PSIxOTYiIC8+CiAgICAgICAgICAgICAgIDx0ZXh0IHg9IjI1OS4yNSIgeT0iMjExIj5uZXdsaW5lPC90ZXh0PgogICAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMjEuNSAyMDdhMTAgMTAgMCAwIDAgMTAgLTEwdi00MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTM0MS41IDE0N2gxMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTEyOC41IDE0N2ExMCAxMCAwIDAgMCAtMTAgMTB2NTlhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgIDxnPgogICAgICAgICAgICAgPHBhdGggZD0iTTEyOC41IDIyNmgyMTMuMCIgLz4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMzQxLjUgMjI2YTEwIDEwIDAgMCAwIDEwIC0xMHYtNTlhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTM1MS41IDE0N2gyMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zNzEuNSAxNDdoMTAiIC8+CiAgICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zODEuNSAxNDdoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik00MTAuMCAxNDdoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iMzgxLjUiIHk9IjEzNiIgLz4KICAgICAgICAgICA8dGV4dCB4PSIzOTUuNzUiIHk9IjE1MSI+JiMzOTs8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTQxMC4wIDE0N2ExMCAxMCAwIDAgMCAxMCAtMTB2LTg3YTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTSA0MzAuMCA0MCBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

[\<url-token\>](#typedef-url-token)

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxMDkiIHZpZXdib3g9IjAgMCA5MTAuMCAxMDkiIHdpZHRoPSI5MTAuMCI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMzB2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik00MCA0MGgxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTUwIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTIzMS41IDQwaDAuMCIgLz4KICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjE4MS41IiB4PSI1MCIgeT0iMjkiIC8+CiAgICAgICAgIDx0ZXh0IHg9IjE0MC43NSIgeT0iNDQiPiZsdDtpZGVudC10b2tlbiAmcXVvdDt1cmwmcXVvdDsmZ3Q7PC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMjMxLjUgNDBoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTTI0MS41IDQwaDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgIDxwYXRoIGQ9Ik0yNTEuNSA0MGgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0yODAuMCA0MGgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iMjUxLjUiIHk9IjI5IiAvPgogICAgICAgICA8dGV4dCB4PSIyNjUuNzUiIHk9IjQ0Ij4oPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMjgwLjAgNDBoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTTI5MC4wIDQwaDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNMzAwLjAgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMzQ1LjUgNDBoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iMzAwIiB5PSIyOSIgLz4KICAgICAgICAgPHRleHQgeD0iMzIyLjc1IiB5PSI0NCI+d3MqPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMzQ1LjUgNDBoMTAiIC8+CiAgICAgICAgPGc+CiAgICAgICAgIDxwYXRoIGQ9Ik0zNTUuNSA0MGgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik03NTYuMCA0MGgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0zNTUuNSA0MGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTM3NS41IDIwaDM2MC41IiAvPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik03MzYuMCAyMGExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNMzU1LjUgNDBoMjAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTM3NS41IDQwaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik03MzYuMCA0MGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMzc1LjUgNDBoMTAiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNMzg1LjUgNDBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik03MjYuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTM4NS41IDQwaDIwIiAvPgogICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICA8cGF0aCBkPSJNNDA1LjUgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNzA2LjAgNDBoMC4wIiAvPgogICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMzAwLjUiIHg9IjQwNS41IiB5PSIyOSIgLz4KICAgICAgICAgICAgPHRleHQgeD0iNTU1Ljc1IiB5PSI0NCI+bm90ICZxdW90OyAmIzM5OyAoICkgXCB3cyBvciBub24tcHJpbnRhYmxlPC90ZXh0PgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNNzA2LjAgNDBoMjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTM4NS41IDQwYTEwIDEwIDAgMCAxIDEwIDEwdjEwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICA8cGF0aCBkPSJNNDA1LjUgNzBoMTE0Ljc1IiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNTkxLjI1IDcwaDExNC43NSIgLz4KICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjcxIiB4PSI1MjAuMjUiIHk9IjU5IiAvPgogICAgICAgICAgICA8dGV4dCB4PSI1NTUuNzUiIHk9Ijc0Ij5lc2NhcGU8L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik03MDYuMCA3MGExMCAxMCAwIDAgMCAxMCAtMTB2LTEwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik03MjYuMCA0MGgxMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zODUuNSA0MGExMCAxMCAwIDAgMCAtMTAgMTB2MjlhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNMzg1LjUgODloMzQwLjUiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNNzI2LjAgODlhMTAgMTAgMCAwIDAgMTAgLTEwdi0yOWExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik03MzYuMCA0MGgyMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTc1Ni4wIDQwaDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNNzY2LjAgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNODExLjUgNDBoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iNzY2IiB5PSIyOSIgLz4KICAgICAgICAgPHRleHQgeD0iNzg4Ljc1IiB5PSI0NCI+d3MqPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNODExLjUgNDBoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTTgyMS41IDQwaDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgIDxwYXRoIGQ9Ik04MzEuNSA0MGgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik04NjAuMCA0MGgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iODMxLjUiIHk9IjI5IiAvPgogICAgICAgICA8dGV4dCB4PSI4NDUuNzUiIHk9IjQ0Ij4pPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNODYwLjAgNDBoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTSA4NzAuMCA0MCBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

[\<number-token\>](#typedef-number-token)

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxNjkiIHZpZXdib3g9IjAgMCA2OTEuNSAxNjkiIHdpZHRoPSI2OTEuNSI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgNDF2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNNDAgNTFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMTA4LjUgNTFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCA1MWExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCAzMWgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNODguNSAzMWgwLjAiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjYwIiB5PSIyMCIgLz4KICAgICAgICAgIDx0ZXh0IHg9Ijc0LjI1IiB5PSIzNSI+KzwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNODguNSAzMWExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCA1MWgyMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCA1MWgyOC41IiAvPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik04OC41IDUxaDIwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCA1MWExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgNzFoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTg4LjUgNzFoMC4wIiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSI2MCIgeT0iNjAiIC8+CiAgICAgICAgICA8dGV4dCB4PSI3NC4yNSIgeT0iNzUiPi08L3RleHQ+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTg4LjUgNzFhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTEwOC41IDUxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTM4Mi4wIDUxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTEwOC41IDUxaDIwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMjguNSA1MWgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMzYyLjAgNTFoMC4wIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTEyOC41IDUxaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjExLjAgNTFoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0xMjguNSA1MWgxMCIgLz4KICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgPHBhdGggZD0iTTEzOC41IDUxaDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTIwMS4wIDUxaDAuMCIgLz4KICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjYyLjUiIHg9IjEzOC41IiB5PSI0MCIgLz4KICAgICAgICAgICAgPHRleHQgeD0iMTY5Ljc1IiB5PSI1NSI+ZGlnaXQ8L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMDEuMCA1MWgxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMTM4LjUgNTFhMTAgMTAgMCAwIDAgLTEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xMzguNSA3MWg2Mi41IiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMjAxLjAgNzFhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yMTEuMCA1MWgxMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yMjEuMCA1MWgxMCIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTIzMS4wIDUxaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjU5LjUgNTFoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iMjMxIiB5PSI0MCIgLz4KICAgICAgICAgICA8dGV4dCB4PSIyNDUuMjUiIHk9IjU1Ij4uPC90ZXh0PgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTI1OS41IDUxaDEwIiAvPgogICAgICAgICAgPHBhdGggZD0iTTI2OS41IDUxaDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTI3OS41IDUxaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzYyLjAgNTFoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yNzkuNSA1MWgxMCIgLz4KICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgPHBhdGggZD0iTTI4OS41IDUxaDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTM1Mi4wIDUxaDAuMCIgLz4KICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjYyLjUiIHg9IjI4OS41IiB5PSI0MCIgLz4KICAgICAgICAgICAgPHRleHQgeD0iMzIwLjc1IiB5PSI1NSI+ZGlnaXQ8L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNTIuMCA1MWgxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjg5LjUgNTFhMTAgMTAgMCAwIDAgLTEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yODkuNSA3MWg2Mi41IiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMzUyLjAgNzFhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMzYyLjAgNTFoMjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0xMDguNSA1MWExMCAxMCAwIDAgMSAxMCAxMHYxOWExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgOTBoNzUuNSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yODYuNSA5MGg3NS41IiAvPgogICAgICAgICAgPHBhdGggZD0iTTIwNC4wIDkwaDEwIiAvPgogICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTIxNC4wIDkwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjc2LjUgOTBoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI2Mi41IiB4PSIyMTQiIHk9Ijc5IiAvPgogICAgICAgICAgIDx0ZXh0IHg9IjI0NS4yNSIgeT0iOTQiPmRpZ2l0PC90ZXh0PgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTI3Ni41IDkwaDEwIiAvPgogICAgICAgICAgPHBhdGggZD0iTTIxNC4wIDkwYTEwIDEwIDAgMCAwIC0xMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTIxNC4wIDExMGg2Mi41IiAvPgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTI3Ni41IDExMGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0zNjIuMCA5MGExMCAxMCAwIDAgMCAxMCAtMTB2LTE5YTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTEwOC41IDUxYTEwIDEwIDAgMCAxIDEwIDEwdjU4YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMjguNSAxMjloNTEuMjUiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMzEwLjc1IDEyOWg1MS4yNSIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTE3OS43NSAxMjloMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMDguMjUgMTI5aDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjE3OS43NSIgeT0iMTE4IiAvPgogICAgICAgICAgIDx0ZXh0IHg9IjE5NCIgeT0iMTMzIj4uPC90ZXh0PgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTIwOC4yNSAxMjloMTAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMjE4LjI1IDEyOWgxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMjguMjUgMTI5aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzEwLjc1IDEyOWgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTIyOC4yNSAxMjloMTAiIC8+CiAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMzguMjUgMTI5aDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTMwMC43NSAxMjloMC4wIiAvPgogICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNjIuNSIgeD0iMjM4LjI1IiB5PSIxMTgiIC8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjI2OS41IiB5PSIxMzMiPmRpZ2l0PC90ZXh0PgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMzAwLjc1IDEyOWgxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjM4LjI1IDEyOWExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTIzOC4yNSAxNDloNjIuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTMwMC43NSAxNDlhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMzYyLjAgMTI5YTEwIDEwIDAgMCAwIDEwIC0xMHYtNThhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTM4Mi4wIDUxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTY1MS41IDUxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTM4Mi4wIDUxaDIwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik00MDIuMCA1MWgyMjkuNSIgLz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNNjMxLjUgNTFoMjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0zODIuMCA1MWExMCAxMCAwIDAgMSAxMCAxMHYxOWExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNNDAyLjAgOTBoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTYzMS41IDkwaDAuMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik00MDIuMCA5MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTQ3MC41IDkwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNNDAyLjAgOTBoMjAiIC8+CiAgICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICAgPHBhdGggZD0iTTQyMi4wIDkwaDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTQ1MC41IDkwaDAuMCIgLz4KICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSI0MjIiIHk9Ijc5IiAvPgogICAgICAgICAgICA8dGV4dCB4PSI0MzYuMjUiIHk9Ijk0Ij5lPC90ZXh0PgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNNDUwLjUgOTBoMjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTQwMi4wIDkwYTEwIDEwIDAgMCAxIDEwIDEwdjEwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik00MjIuMCAxMjBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNDUwLjUgMTIwaDAuMCIgLz4KICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSI0MjIiIHk9IjEwOSIgLz4KICAgICAgICAgICAgPHRleHQgeD0iNDM2LjI1IiB5PSIxMjQiPkU8L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik00NTAuNSAxMjBhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNNDcwLjUgOTBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik01MzkuMCA5MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTQ3MC41IDkwYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgICA8cGF0aCBkPSJNNDkwLjUgNzBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNTE5LjAgNzBoMC4wIiAvPgogICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjQ5MC41IiB5PSI1OSIgLz4KICAgICAgICAgICAgPHRleHQgeD0iNTA0Ljc1IiB5PSI3NCI+KzwvdGV4dD4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTUxOS4wIDcwYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTQ3MC41IDkwaDIwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNNDkwLjUgOTBoMjguNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTUxOS4wIDkwaDIwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik00NzAuNSA5MGExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik00OTAuNSAxMTBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNTE5LjAgMTEwaDAuMCIgLz4KICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSI0OTAuNSIgeT0iOTkiIC8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjUwNC43NSIgeT0iMTE0Ij4tPC90ZXh0PgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNNTE5LjAgMTEwYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik01MzkuMCA5MGgxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik01NDkuMCA5MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTYzMS41IDkwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNNTQ5LjAgOTBoMTAiIC8+CiAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik01NTkuMCA5MGgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik02MjEuNSA5MGgwLjAiIC8+CiAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI2Mi41IiB4PSI1NTkiIHk9Ijc5IiAvPgogICAgICAgICAgICA8dGV4dCB4PSI1OTAuMjUiIHk9Ijk0Ij5kaWdpdDwvdGV4dD4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTYyMS41IDkwaDEwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik01NTkuMCA5MGExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTU1OS4wIDExMGg2Mi41IiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNNjIxLjUgMTEwYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTYzMS41IDkwYTEwIDEwIDAgMCAwIDEwIC0xMHYtMTlhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNIDY1MS41IDUxIGggMjAgbSAtMTAgLTEwIHYgMjAgbSAxMCAtMjAgdiAyMCIgLz4KICAgICAgIDwvZz4KICAgICAgPC9zdmc+)
 :::

[\<dimension-token\>](#typedef-dimension-token)

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSI2MiIgdmlld2JveD0iMCAwIDM4OS41IDYyIiB3aWR0aD0iMzg5LjUiPgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTIwIDIxdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgIDxwYXRoIGQ9Ik01MCAzMWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0xODkuMCAzMWgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxMzkiIHg9IjUwIiB5PSIyMCIgLz4KICAgICAgICAgPHRleHQgeD0iMTE5LjUiIHk9IjM1Ij4mbHQ7bnVtYmVyLXRva2VuJmd0OzwvdGV4dD4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTE4OS4wIDMxaDEwIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0xOTkuMCAzMWgxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTIwOS4wIDMxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTMzOS41IDMxaDAuMCIgLz4KICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjEzMC41IiB4PSIyMDkiIHk9IjIwIiAvPgogICAgICAgICA8dGV4dCB4PSIyNzQuMjUiIHk9IjM1Ij4mbHQ7aWRlbnQtdG9rZW4mZ3Q7PC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMzM5LjUgMzFoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTSAzNDkuNSAzMSBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

[\<percentage-token\>](#typedef-percentage-token)

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSI2MiIgdmlld2JveD0iMCAwIDI4Ny41IDYyIiB3aWR0aD0iMjg3LjUiPgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTIwIDIxdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgIDxwYXRoIGQ9Ik01MCAzMWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0xODkuMCAzMWgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxMzkiIHg9IjUwIiB5PSIyMCIgLz4KICAgICAgICAgPHRleHQgeD0iMTE5LjUiIHk9IjM1Ij4mbHQ7bnVtYmVyLXRva2VuJmd0OzwvdGV4dD4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTE4OS4wIDMxaDEwIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0xOTkuMCAzMWgxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNMjA5LjAgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMjM3LjUgMzFoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjIwOSIgeT0iMjAiIC8+CiAgICAgICAgIDx0ZXh0IHg9IjIyMy4yNSIgeT0iMzUiPiU8L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0yMzcuNSAzMWgxMCIgLz4KICAgICAgICA8cGF0aCBkPSJNIDI0Ny41IDMxIGggMjAgbSAtMTAgLTEwIHYgMjAgbSAxMCAtMjAgdiAyMCIgLz4KICAgICAgIDwvZz4KICAgICAgPC9zdmc+)
 :::

[\<CDO-token\>](#typedef-cdo-token)

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSI2MiIgdmlld2JveD0iMCAwIDE1NC4wIDYyIiB3aWR0aD0iMTU0LjAiPgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTIwIDIxdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTUwIDMxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTEwNC4wIDMxaDAuMCIgLz4KICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSI1NCIgeD0iNTAiIHk9IjIwIiAvPgogICAgICAgICA8dGV4dCB4PSI3NyIgeT0iMzUiPiZsdDshLS08L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0xMDQuMCAzMWgxMCIgLz4KICAgICAgICA8cGF0aCBkPSJNIDExNC4wIDMxIGggMjAgbSAtMTAgLTEwIHYgMjAgbSAxMCAtMjAgdiAyMCIgLz4KICAgICAgIDwvZz4KICAgICAgPC9zdmc+)
 :::

[\<CDC-token\>](#typedef-cdc-token)

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSI2MiIgdmlld2JveD0iMCAwIDE0NS41IDYyIiB3aWR0aD0iMTQ1LjUiPgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTIwIDIxdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTUwIDMxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTk1LjUgMzFoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjQ1LjUiIHg9IjUwIiB5PSIyMCIgLz4KICAgICAgICAgPHRleHQgeD0iNzIuNzUiIHk9IjM1Ij4tLSZndDs8L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik05NS41IDMxaDEwIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0gMTA1LjUgMzEgaCAyMCBtIC0xMCAtMTAgdiAyMCBtIDEwIC0yMCB2IDIwIiAvPgogICAgICAgPC9nPgogICAgICA8L3N2Zz4=)
 :::

[\<unicode-range-token\>](#typedef-unicode-range-token)

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIyMDMiIHZpZXdib3g9IjAgMCA1ODAuNSAyMDMiIHdpZHRoPSI1ODAuNSI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMjF2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMTA4LjUgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWgyMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDMxaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik04OC41IDMxaDAuMCIgLz4KICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iNjAiIHk9IjIwIiAvPgogICAgICAgICAgPHRleHQgeD0iNzQuMjUiIHk9IjM1Ij5VPC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik04OC41IDMxaDIwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWExMCAxMCAwIDAgMSAxMCAxMHYxMGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDYxaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik04OC41IDYxaDAuMCIgLz4KICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iNjAiIHk9IjUwIiAvPgogICAgICAgICAgPHRleHQgeD0iNzQuMjUiIHk9IjY1Ij51PC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik04OC41IDYxYTEwIDEwIDAgMCAwIDEwIC0xMHYtMTBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMTA4LjUgMzFoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTExOC41IDMxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTE0Ny4wIDMxaDAuMCIgLz4KICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSIxMTguNSIgeT0iMjAiIC8+CiAgICAgICAgIDx0ZXh0IHg9IjEzMi43NSIgeT0iMzUiPis8L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0xNDcuMCAzMWgxMCIgLz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTE1Ny4wIDMxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTU0MC41IDMxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTE1Ny4wIDMxaDIwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xNzcuMCAzMWgxMTMuNSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik00MDcuMCAzMWgxMTMuNSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yOTAuNSAzMWgxMCIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zMDAuNSAzMWgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTM5Ny4wIDMxaDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iOTYuNSIgeD0iMzAwLjUiIHk9IjIwIiAvPgogICAgICAgICAgIDx0ZXh0IHg9IjM0OC43NSIgeT0iMzUiPmhleCBkaWdpdDwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zOTcuMCAzMWgxMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zMDAuNSAzMWExMCAxMCAwIDAgMCAtMTAgMTB2N2ExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zMDAuNSA1OGgxMS43NSIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzg1LjI1IDU4aDExLjc1IiAvPgogICAgICAgICAgIDx0ZXh0IGNsYXNzPSJjb21tZW50IiB4PSIzNDguNzUiIHk9IjYzIj4xLTYgdGltZXM8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMzk3LjAgNThhMTAgMTAgMCAwIDAgMTAgLTEwdi03YTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTUyMC41IDMxaDIwIiAvPgogICAgICAgICA8cGF0aCBkPSJNMTU3LjAgMzFhMTAgMTAgMCAwIDEgMTAgMTB2NDNhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTE3Ny4wIDk0aDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik01MjAuNSA5NGgwLjAiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNMTc3LjAgOTRoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zMzMuNSA5NGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTE3Ny4wIDk0YTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTE5Ny4wIDc0aDExNi41IiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMzEzLjUgNzRhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMTc3LjAgOTRoMjAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xOTcuMCA5NGgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMTMuNSA5NGgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xOTcuMCA5NGgxMCIgLz4KICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjA3LjAgOTRoMC4wIiAvPgogICAgICAgICAgICAgPHBhdGggZD0iTTMwMy41IDk0aDAuMCIgLz4KICAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI5Ni41IiB4PSIyMDciIHk9IjgzIiAvPgogICAgICAgICAgICAgPHRleHQgeD0iMjU1LjI1IiB5PSI5OCI+aGV4IGRpZ2l0PC90ZXh0PgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMDMuNSA5NGgxMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTIwNy4wIDk0YTEwIDEwIDAgMCAwIC0xMCAxMHY3YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMDcuMCAxMjFoMTEuNzUiIC8+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjkxLjc1IDEyMWgxMS43NSIgLz4KICAgICAgICAgICAgIDx0ZXh0IGNsYXNzPSJjb21tZW50IiB4PSIyNTUuMjUiIHk9IjEyNiI+MS01IHRpbWVzPC90ZXh0PgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMDMuNSAxMjFhMTAgMTAgMCAwIDAgMTAgLTEwdi03YTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zMTMuNSA5NGgyMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zMzMuNSA5NGgxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNDMuNSA5NGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTUyMC41IDk0aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzQzLjUgOTRoMTAiIC8+CiAgICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICAgPHBhdGggZD0iTTM1My41IDk0aDY0LjI1IiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNDQ2LjI1IDk0aDY0LjI1IiAvPgogICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjQxNy43NSIgeT0iODMiIC8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjQzMiIgeT0iOTgiPj88L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik01MTAuNSA5NGgxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzUzLjUgOTRhMTAgMTAgMCAwIDAgLTEwIDEwdjdhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNTMuNSAxMjFoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNTEwLjUgMTIxaDAuMCIgLz4KICAgICAgICAgICAgPHRleHQgY2xhc3M9ImNvbW1lbnQiIHg9IjQzMiIgeT0iMTI2Ij4xIHRvICg2LWRpZ2l0cykgdGltZXM8L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik01MTAuNSAxMjFhMTAgMTAgMCAwIDAgMTAgLTEwdi03YTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTUyMC41IDk0YTEwIDEwIDAgMCAwIDEwIC0xMHYtNDNhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNMTU3LjAgMzFhMTAgMTAgMCAwIDEgMTAgMTB2OTdhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTE3Ny4wIDE0OGgyMS4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTQ5OS41IDE0OGgyMS4wIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTE5OC4wIDE0OGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTMxNC41IDE0OGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTE5OC4wIDE0OGgxMCIgLz4KICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgPHBhdGggZD0iTTIwOC4wIDE0OGgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMDQuNSAxNDhoMC4wIiAvPgogICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iOTYuNSIgeD0iMjA4IiB5PSIxMzciIC8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjI1Ni4yNSIgeT0iMTUyIj5oZXggZGlnaXQ8L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zMDQuNSAxNDhoMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTIwOC4wIDE0OGExMCAxMCAwIDAgMCAtMTAgMTB2N2ExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgPHBhdGggZD0iTTIwOC4wIDE3NWgxMS43NSIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTI5Mi43NSAxNzVoMTEuNzUiIC8+CiAgICAgICAgICAgIDx0ZXh0IGNsYXNzPSJjb21tZW50IiB4PSIyNTYuMjUiIHk9IjE4MCI+MS02IHRpbWVzPC90ZXh0PgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMzA0LjUgMTc1YTEwIDEwIDAgMCAwIDEwIC0xMHYtN2ExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTMxNC41IDE0OGgxMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zMjQuNSAxNDhoMTAiIC8+CiAgICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zMzQuNSAxNDhoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNjMuMCAxNDhoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iMzM0LjUiIHk9IjEzNyIgLz4KICAgICAgICAgICA8dGV4dCB4PSIzNDguNzUiIHk9IjE1MiI+LTwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zNjMuMCAxNDhoMTAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMzczLjAgMTQ4aDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTM4My4wIDE0OGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTQ5OS41IDE0OGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTM4My4wIDE0OGgxMCIgLz4KICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgPHBhdGggZD0iTTM5My4wIDE0OGgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik00ODkuNSAxNDhoMC4wIiAvPgogICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iOTYuNSIgeD0iMzkzIiB5PSIxMzciIC8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjQ0MS4yNSIgeT0iMTUyIj5oZXggZGlnaXQ8L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik00ODkuNSAxNDhoMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTM5My4wIDE0OGExMCAxMCAwIDAgMCAtMTAgMTB2N2ExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgPHBhdGggZD0iTTM5My4wIDE3NWgxMS43NSIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTQ3Ny43NSAxNzVoMTEuNzUiIC8+CiAgICAgICAgICAgIDx0ZXh0IGNsYXNzPSJjb21tZW50IiB4PSI0NDEuMjUiIHk9IjE4MCI+MS02IHRpbWVzPC90ZXh0PgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNNDg5LjUgMTc1YTEwIDEwIDAgMCAwIDEwIC0xMHYtN2ExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik01MjAuNSAxNDhhMTAgMTAgMCAwIDAgMTAgLTEwdi05N2ExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0gNTQwLjUgMzEgaCAyMCBtIC0xMCAtMTAgdiAyMCBtIDEwIC0yMCB2IDIwIiAvPgogICAgICAgPC9nPgogICAgICA8L3N2Zz4=)
 :::

### 4.2. Definitions

This section defines several terms used during the tokenization phase.

[next input code point]
: The first [code
 point](https://infra.spec.whatwg.org/#code-point) in the [input
 stream](#input-stream) that
 has not yet been consumed.

[current input code point]
: The last [code
 point](https://infra.spec.whatwg.org/#code-point) to have been consumed.

[reconsume the current input code point]
: Push the [current input code
 point](#current-input-code-point) back onto the front of the [input
 stream](#input-stream), so
 that the next time you are instructed to consume the [next input
 code point](#next-input-code-point), it will instead reconsume the [current input code
 point].

[EOF code point]
: A conceptual [code
 point](https://infra.spec.whatwg.org/#code-point) representing the end of the [input
 stream](#input-stream).
 Whenever the [input stream] is empty, the
 [next input code
 point](#next-input-code-point) is always an EOF code point.

[digit]
: A [code
 point](https://infra.spec.whatwg.org/#code-point) between U+0030 DIGIT ZERO (0) and U+0039 DIGIT
 NINE (9) inclusive.
 Tests
 - [inclusive-ranges.html](https://wpt.fyi/results/css/css-syntax/inclusive-ranges.html "css/css-syntax/inclusive-ranges.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/inclusive-ranges.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/inclusive-ranges.html)

[hex digit]
: A [digit](#digit), or a [code
 point](https://infra.spec.whatwg.org/#code-point) between U+0041 LATIN CAPITAL LETTER A (A) and
 U+0046 LATIN CAPITAL LETTER F (F) inclusive, or a [code
 point] between U+0061 LATIN SMALL LETTER
 A (a) and U+0066 LATIN SMALL LETTER F (f) inclusive.

[uppercase letter]
: A [code
 point](https://infra.spec.whatwg.org/#code-point) between U+0041 LATIN CAPITAL LETTER A (A) and
 U+005A LATIN CAPITAL LETTER Z (Z) inclusive.

[lowercase letter]
: A [code
 point](https://infra.spec.whatwg.org/#code-point) between U+0061 LATIN SMALL LETTER A (a) and U+007A
 LATIN SMALL LETTER Z (z) inclusive.

[letter]
: An [uppercase letter](#uppercase-letter) or a [lowercase
 letter](#lowercase-letter).

[non-ASCII ident code point]

: A [code
 point](https://infra.spec.whatwg.org/#code-point) whose value is any of:

 - U+00B7

 - between U+00C0 and U+00D6

 - between U+00D8 and U+00F6

 - between U+00F8 and U+037D

 - between U+037F and U+1FFF

 - U+200C

 - U+200D

 - U+203F

 - U+2040

 - between U+2070 and U+218F

 - between U+2C00 and U+2FEF

 - between U+3001 and U+D7FF

 - between U+F900 and U+FDCF

 - between U+FDF0 and U+FFFD

 - greater than or equal to U+10000

 All of these ranges are inclusive.

 Tests

 - [non-ascii-codepoints.html](https://wpt.fyi/results/css/css-syntax/non-ascii-codepoints.html "css/css-syntax/non-ascii-codepoints.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/non-ascii-codepoints.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/non-ascii-codepoints.html)

 Why these character, specifically?

 This matches the list of non-ASCII codepoints allowed to be used in
 HTML [valid custom element
 names](https://html.spec.whatwg.org/multipage/custom-elements.html#valid-custom-element-name). It excludes a number of characters that appear as
 whitespace, or that can cause rendering or parsing issues in some
 tools, such as the direction override codepoints.

 Note that this is a weaker set of restrictions than [UAX
 31](https://unicode.org/reports/tr31/#Figure_Code_Point_Categories_for_Identifier_Parsing)
 recommends for identifiers (used by languages such as JavaScript to
 restrict their identifier syntax), allowing things such as starting
 an identifier with a combining character. Consistency with HTML
 custom element names (and thus, the ability to write selectors for
 all custom elements without having to use escapes) was considered
 valuable, and the set of characters restricted by HTML covers the
 \"high value\" restrictions well.

 These restrictions do not avoid all possible confusing renderings;
 mixing characters from LTR and RTL scripts can still result in
 unexpected visual transposition in most text editors, for example.
 Source text can contain the restricted characters in non-ident
 contexts, as well: most of them are completely valid in strings, for
 example. Even when used in a way that creates invalid CSS, the
 parsing errors they cause might be limited to something unimportant,
 while their effect on rendering the source text in code review tools
 might be significant and/or malicious. For more details on these
 sorts of \"source text attacks\", see [this Rust-lang blog
 post](https://blog.rust-lang.org/2021/11/01/cve-2021-42574.html)
 [[(archived)](https://web.archive.org/web/20220323175009/https://blog.rust-lang.org/2021/11/01/cve-2021-42574.html)].

[ident-start code point]
: A [letter](#letter), a [non-ASCII
 ident code
 point](#non-ascii-ident-code-point), or U+005F LOW LINE (\_).

[ident code point]
: An [ident-start code
 point](#ident-start-code-point), a [digit](#digit), or U+002D HYPHEN-MINUS (-).

[non-printable code point]
: A [code
 point](https://infra.spec.whatwg.org/#code-point) between U+0000 NULL and U+0008 BACKSPACE inclusive,
 or U+000B LINE TABULATION, or a [code point]
 between U+000E SHIFT OUT and U+001F INFORMATION SEPARATOR ONE
 inclusive, or U+007F DELETE.
 Tests
 - [inclusive-ranges.html](https://wpt.fyi/results/css/css-syntax/inclusive-ranges.html "css/css-syntax/inclusive-ranges.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/inclusive-ranges.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/inclusive-ranges.html)

[newline]
: U+000A LINE FEED. [ Note that U+000D CARRIAGE RETURN and U+000C FORM
 FEED are not included in this definition, as they are converted to
 U+000A LINE FEED during [preprocessing](#input-preprocessing).
 ]

[whitespace]
: A [newline](#newline), U+0009
 CHARACTER TABULATION, or U+0020 SPACE.
 Tests
 - [whitespace.html](https://wpt.fyi/results/css/css-syntax/whitespace.html "css/css-syntax/whitespace.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/whitespace.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/whitespace.html)

[maximum allowed code point]
: The greatest [code
 point](https://infra.spec.whatwg.org/#code-point) defined by Unicode: U+10FFFF.

[ident sequence]

: A sequence of [code
 points](https://infra.spec.whatwg.org/#code-point) that has the same syntax as an
 [\<ident-token\>](#typedef-ident-token).

 The part of an
 [\<at-keyword-token\>](#typedef-at-keyword-token) after the \"@\", the part of a
 [\<hash-token\>](#typedef-hash-token) (with the \"id\" type flag) after
 the \"#\", the part of a
 [\<function-token\>](#typedef-function-token) before the \"(\", and the unit of
 a
 [\<dimension-token\>](#typedef-dimension-token) are all [ident
 sequences](#ident-sequence).

### 4.3. Tokenizer Algorithms

The algorithms defined in this section transform a stream of [code
points](https://infra.spec.whatwg.org/#code-point) into a stream of tokens.

#### 4.3.1. Consume a token

This section describes how to [consume a
token] from a stream of [code
points](https://infra.spec.whatwg.org/#code-point). It additionally takes an optional boolean
`unicode ranges allowed`, defaulting to false. It will return
a single token of any type.

[Consume comments](#consume-comments).

Consume the [next input code
point](#next-input-code-point).

[whitespace](#whitespace)
: Consume as much [whitespace](#whitespace) as possible. Return a
 [\<whitespace-token\>](#typedef-whitespace-token).

U+0022 QUOTATION MARK (\")
: [Consume a string
 token](#consume-a-string-token) and return it.

U+0023 NUMBER SIGN (#)

: If the [next input code
 point](#next-input-code-point) is an [ident code
 point](#ident-code-point) or the [next two input code
 points] [are a valid
 escape](#check-if-two-code-points-are-a-valid-escape), then:

 1. Create a
 [\<hash-token\>](#typedef-hash-token).
 2. If the [next 3 input code
 points](#next-input-code-point) [would start an ident
 sequence](#check-if-three-code-points-would-start-an-ident-sequence), set the
 [\<hash-token\>](#typedef-hash-token)'s type flag to \"id\".
 3. [Consume an ident
 sequence](#consume-an-ident-sequence), and set the
 [\<hash-token\>](#typedef-hash-token)'s value to the returned
 string.
 4. Return the
 [\<hash-token\>](#typedef-hash-token).

 Otherwise, return a
 [\<delim-token\>](#typedef-delim-token) with its value set to the
 [current input code
 point](#current-input-code-point).

U+0027 APOSTROPHE (\')
: [Consume a string
 token](#consume-a-string-token) and return it.

U+0028 LEFT PARENTHESIS (()
: Return a
 [\<(-token\>](#tokendef-open-paren).

U+0029 RIGHT PARENTHESIS ())
: Return a
 [\<)-token\>](#tokendef-close-paren).

U+002B PLUS SIGN (+)

: If the input stream [starts with a
 number](#check-if-three-code-points-would-start-a-number), [reconsume the current input code
 point](#reconsume-the-current-input-code-point), [consume a numeric
 token](#consume-a-numeric-token), and return it.

 Otherwise, return a
 [\<delim-token\>](#typedef-delim-token) with its value set to the
 [current input code
 point](#current-input-code-point).

U+002C COMMA (,)
: Return a
 [\<comma-token\>](#typedef-comma-token).

U+002D HYPHEN-MINUS (-)

: If the input stream [starts with a
 number](#check-if-three-code-points-would-start-a-number), [reconsume the current input code
 point](#reconsume-the-current-input-code-point), [consume a numeric
 token](#consume-a-numeric-token), and return it.

 Otherwise, if the [next 2 input code
 points](#next-input-code-point) are U+002D HYPHEN-MINUS U+003E GREATER-THAN SIGN
 (-\>), consume them and return a
 [\<CDC-token\>](#typedef-cdc-token).

 Otherwise, if the input stream [starts with an ident
 sequence](#check-if-three-code-points-would-start-an-ident-sequence), [reconsume the current input code
 point](#reconsume-the-current-input-code-point), [consume an ident-like
 token](#consume-an-ident-like-token), and return it.

 Otherwise, return a
 [\<delim-token\>](#typedef-delim-token) with its value set to the
 [current input code
 point](#current-input-code-point).

U+002E FULL STOP (.)

: If the input stream [starts with a
 number](#check-if-three-code-points-would-start-a-number), [reconsume the current input code
 point](#reconsume-the-current-input-code-point), [consume a numeric
 token](#consume-a-numeric-token), and return it.

 Otherwise, return a
 [\<delim-token\>](#typedef-delim-token) with its value set to the
 [current input code
 point](#current-input-code-point).

U+003A COLON (:)
: Return a
 [\<colon-token\>](#typedef-colon-token).

U+003B SEMICOLON (;)
: Return a
 [\<semicolon-token\>](#typedef-semicolon-token).

U+003C LESS-THAN SIGN (\<)

: If the [next 3 input code
 points](#next-input-code-point) are U+0021 EXCLAMATION MARK U+002D HYPHEN-MINUS
 U+002D HYPHEN-MINUS (!\--), consume them and return a
 [\<CDO-token\>](#typedef-cdo-token).

 Otherwise, return a
 [\<delim-token\>](#typedef-delim-token) with its value set to the
 [current input code
 point](#current-input-code-point).

U+0040 COMMERCIAL AT (@)

: If the [next 3 input code
 points](#next-input-code-point) [would start an ident
 sequence](#check-if-three-code-points-would-start-an-ident-sequence), [consume an ident
 sequence](#consume-an-ident-sequence), create an
 [\<at-keyword-token\>](#typedef-at-keyword-token) with its value set to the
 returned value, and return it.

 Otherwise, return a
 [\<delim-token\>](#typedef-delim-token) with its value set to the
 [current input code
 point](#current-input-code-point).

U+005B LEFT SQUARE BRACKET (\[)
: Return a
 [\<\[-token\>](#tokendef-open-square).

U+005C REVERSE SOLIDUS (\\)

: If the input stream [starts with a valid
 escape](#check-if-two-code-points-are-a-valid-escape), [reconsume the current input code
 point](#reconsume-the-current-input-code-point), [consume an ident-like
 token](#consume-an-ident-like-token), and return it.

 Tests

 - [url-whitespace-consumption.html](https://wpt.fyi/results/css/css-syntax/url-whitespace-consumption.html "css/css-syntax/url-whitespace-consumption.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/url-whitespace-consumption.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/url-whitespace-consumption.html)

 Otherwise, this is a [parse
 error](#parse-error). Return a
 [\<delim-token\>](#typedef-delim-token) with its value set to the
 [current input code
 point](#current-input-code-point).

U+005D RIGHT SQUARE BRACKET (\])
: Return a
 [\<\]-token\>](#tokendef-close-square).

U+007B LEFT CURLY BRACKET ({)
: Return a
 [\<{-token\>](#tokendef-open-curly).

U+007D RIGHT CURLY BRACKET (})
: Return a
 [\<}-token\>](#tokendef-close-curly).

[digit](#digit)
: [Reconsume the current input code
 point](#reconsume-the-current-input-code-point), [consume a numeric
 token](#consume-a-numeric-token), and return it.

U+0055 LATIN CAPITAL LETTER U (U)\
u+0075 LATIN LOWERCASE LETTER U (u)

: If `unicode ranges allowed` is true and the input stream
 [would start a
 unicode-range](#check-if-three-code-points-would-start-a-unicode-range), [reconsume the current input code
 point](#reconsume-the-current-input-code-point), [consume a unicode-range
 token](#consume-a-unicode-range-token), and return it.

 Otherwise, [reconsume the current input code
 point](#reconsume-the-current-input-code-point), [consume an ident-like
 token](#consume-an-ident-like-token), and return it.

[ident-start code point](#ident-start-code-point)
: [Reconsume the current input code
 point](#reconsume-the-current-input-code-point), [consume an ident-like
 token](#consume-an-ident-like-token), and return it.

EOF
: Return an
 [\<EOF-token\>](#typedef-eof-token).

anything else
: Return a
 [\<delim-token\>](#typedef-delim-token) with its value set to the
 [current input code
 point](#current-input-code-point).

Tests

- [cdc-vs-ident-tokens.html](https://wpt.fyi/results/css/css-syntax/cdc-vs-ident-tokens.html "css/css-syntax/cdc-vs-ident-tokens.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/cdc-vs-ident-tokens.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/cdc-vs-ident-tokens.html)
- [escaped-eof.html](https://wpt.fyi/results/css/css-syntax/escaped-eof.html "css/css-syntax/escaped-eof.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/escaped-eof.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/escaped-eof.html)

#### 4.3.2. Consume comments

This section describes how to [consume comments] from a stream of [code
points](https://infra.spec.whatwg.org/#code-point). It returns nothing.

If the [next two input code
point](#next-input-code-point) are U+002F SOLIDUS (/) followed by a U+002A ASTERISK
(\*), consume them and all following [code
points](https://infra.spec.whatwg.org/#code-point) up to and including the first U+002A ASTERISK (\*)
followed by a U+002F SOLIDUS (/), or up to an EOF code point. Return to
the start of this step.

If the preceding paragraph ended by consuming an EOF code point, this is
a [parse error](#parse-error).

Return nothing.

#### 4.3.3. Consume a numeric token

This section describes how to [consume a numeric
token] from a stream of [code
points](https://infra.spec.whatwg.org/#code-point). It returns either a
[\<number-token\>](#typedef-number-token),
[\<percentage-token\>](#typedef-percentage-token), or
[\<dimension-token\>](#typedef-dimension-token).

[Consume a number](#consume-a-number) and let `number` be the result.

If the [next 3 input code
points](#next-input-code-point) [would start an ident
sequence](#check-if-three-code-points-would-start-an-ident-sequence), then:

1. Create a
 [\<dimension-token\>](#typedef-dimension-token) with the same value, type flag,
 and sign character as `number`, and a unit set initially
 to the empty string.
2. [Consume an ident
 sequence](#consume-an-ident-sequence). Set the
 [\<dimension-token\>](#typedef-dimension-token)'s unit to the returned value.
3. Return the
 [\<dimension-token\>](#typedef-dimension-token).

Otherwise, if the [next input code
point](#next-input-code-point) is U+0025 PERCENTAGE SIGN (%), consume it. Create a
[\<percentage-token\>](#typedef-percentage-token) with the same value and sign
character as `number`, and return it.

Otherwise, create a
[\<number-token\>](#typedef-number-token) with the same value, type flag, and
sign character as `number`, and return it.

#### 4.3.4. Consume an ident-like token

This section describes how to [consume an ident-like
token] from a stream of [code
points](https://infra.spec.whatwg.org/#code-point). It returns an
[\<ident-token\>](#typedef-ident-token),
[\<function-token\>](#typedef-function-token),
[\<url-token\>](#typedef-url-token), or
[\<bad-url-token\>](#typedef-bad-url-token).

[Consume an ident
sequence](#consume-an-ident-sequence), and let `string` be the result.

If `string`'s value is an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"url\", and the [next input code
point](#next-input-code-point) is U+0028 LEFT PARENTHESIS ((), consume it. While the
[next two input code points] are
[whitespace](#whitespace), consume
the [next input code point]. If the
[next one or two input code points]
are U+0022 QUOTATION MARK (\"), U+0027 APOSTROPHE (\'), or
[whitespace] followed by U+0022 QUOTATION MARK
(\") or U+0027 APOSTROPHE (\'), then create a
[\<function-token\>](#typedef-function-token) with its value set to
`string` and return it. Otherwise, [consume a url
token](#consume-a-url-token), and return it.

Otherwise, if the [next input code
point](#next-input-code-point) is U+0028 LEFT PARENTHESIS ((), consume it. Create a
[\<function-token\>](#typedef-function-token) with its value set to
`string` and return it.

Otherwise, create an
[\<ident-token\>](#typedef-ident-token) with its value set to
`string` and return it.

#### 4.3.5. Consume a string token

This section describes how to [consume a string
token] from a stream of [code
points](https://infra.spec.whatwg.org/#code-point). It returns either a
[\<string-token\>](#typedef-string-token) or
[\<bad-string-token\>](#typedef-bad-string-token).

This algorithm may be called with an `ending code point`,
which denotes the [code
point](https://infra.spec.whatwg.org/#code-point) that ends the string. If an
`ending code point` is not specified, the [current input code
point](#current-input-code-point) is used.

Initially create a
[\<string-token\>](#typedef-string-token) with its value set to the empty
string.

Repeatedly consume the [next input code
point](#next-input-code-point) from the stream:

`ending code point`
: Return the
 [\<string-token\>](#typedef-string-token).

EOF
: This is a [parse error](#parse-error). Return the
 [\<string-token\>](#typedef-string-token).

[newline](#newline)
: This is a [parse error](#parse-error). [Reconsume the current input code
 point](#reconsume-the-current-input-code-point), create a
 [\<bad-string-token\>](#typedef-bad-string-token), and return it.

U+005C REVERSE SOLIDUS (\\)

: If the [next input code
 point](#next-input-code-point) is EOF, do nothing.

 Otherwise, if the [next input code
 point](#next-input-code-point) is a newline, consume it.

 Otherwise, [(the stream [starts with a valid
 escape](#check-if-two-code-points-are-a-valid-escape))] [consume an escaped code
 point](#consume-an-escaped-code-point) and append the returned [code
 point](https://infra.spec.whatwg.org/#code-point) to the
 [\<string-token\>](#typedef-string-token)'s value.

anything else
: Append the [current input code
 point](#current-input-code-point) to the
 [\<string-token\>](#typedef-string-token)'s value.

Tests

- [escaped-eof.html](https://wpt.fyi/results/css/css-syntax/escaped-eof.html "css/css-syntax/escaped-eof.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/escaped-eof.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/escaped-eof.html)

#### 4.3.6. Consume a url token

This section describes how to [consume a url token] from a stream of [code
points](https://infra.spec.whatwg.org/#code-point). It returns either a
[\<url-token\>](#typedef-url-token) or a
[\<bad-url-token\>](#typedef-bad-url-token).

 This algorithm assumes that the initial \"url(\" has
already been consumed. This algorithm also assumes that it's being
called to consume an \"unquoted\" value, like [url(foo)]. A quoted
value, like [url(\"foo\")], is parsed as a
[\<function-token\>](#typedef-function-token). [Consume an ident-like
token](#consume-an-ident-like-token) automatically handles this distinction; this algorithm
shouldn't be called directly otherwise.

1. Initially create a
 [\<url-token\>](#typedef-url-token) with its value set to the empty
 string.
2. Consume as much [whitespace](#whitespace) as possible.
3. Repeatedly consume the [next input code
 point](#next-input-code-point) from the stream:

 U+0029 RIGHT PARENTHESIS ())
 : Return the
 [\<url-token\>](#typedef-url-token).

 EOF
 : This is a [parse error](#parse-error). Return the
 [\<url-token\>](#typedef-url-token).

 [whitespace](#whitespace)
 : Consume as much [whitespace](#whitespace) as possible. If the [next input code
 point](#next-input-code-point) is U+0029 RIGHT PARENTHESIS ()) or EOF, consume
 it and return the
 [\<url-token\>](#typedef-url-token) (if EOF was encountered, this
 is a [parse error](#parse-error)); otherwise, [consume the remnants of a bad
 url](#consume-the-remnants-of-a-bad-url), create a
 [\<bad-url-token\>](#typedef-bad-url-token), and return it.

 U+0022 QUOTATION MARK (\")\
 U+0027 APOSTROPHE (\')\
 U+0028 LEFT PARENTHESIS (()\
 [non-printable code point](#non-printable-code-point)
 : This is a [parse error](#parse-error). [Consume the remnants of a bad
 url](#consume-the-remnants-of-a-bad-url), create a
 [\<bad-url-token\>](#typedef-bad-url-token), and return it.

 U+005C REVERSE SOLIDUS (\\)

 : If the stream [starts with a valid
 escape](#check-if-two-code-points-are-a-valid-escape), [consume an escaped code
 point](#consume-an-escaped-code-point) and append the returned [code
 point](https://infra.spec.whatwg.org/#code-point) to the
 [\<url-token\>](#typedef-url-token)'s value.

 Otherwise, this is a [parse
 error](#parse-error).
 [Consume the remnants of a bad
 url](#consume-the-remnants-of-a-bad-url), create a
 [\<bad-url-token\>](#typedef-bad-url-token), and return it.

 anything else
 : Append the [current input code
 point](#current-input-code-point) to the
 [\<url-token\>](#typedef-url-token)'s value.

Tests

- [unclosed-url-at-eof.html](https://wpt.fyi/results/css/css-syntax/unclosed-url-at-eof.html "css/css-syntax/unclosed-url-at-eof.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/unclosed-url-at-eof.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/unclosed-url-at-eof.html)

#### 4.3.7. Consume an escaped code point

This section describes how to [consume an escaped code
point]. It assumes that the U+005C REVERSE SOLIDUS (\\) has
already been consumed and that the next input code point has already
been verified to be part of a valid escape. It will return a [code
point](https://infra.spec.whatwg.org/#code-point).

Consume the [next input code
point](#next-input-code-point).

[hex digit](#hex-digit)
: Consume as many [hex digits](#hex-digit) as possible, but no more than 5. [Note that this
 means 1-6 hex digits have been consumed in total.] If the
 [next input code
 point](#next-input-code-point) is [whitespace](#whitespace), consume it as well. Interpret the [hex
 digits] as a hexadecimal number. If this number
 is zero, or is for a
 [surrogate](https://infra.spec.whatwg.org/#surrogate), or is greater than the [maximum allowed code
 point](#maximum-allowed-code-point), return U+FFFD REPLACEMENT CHARACTER (�).
 Otherwise, return the [code
 point](https://infra.spec.whatwg.org/#code-point) with that value.

EOF
: This is a [parse error](#parse-error). Return U+FFFD REPLACEMENT CHARACTER (�).

anything else
: Return the [current input code
 point](#current-input-code-point).

Tests

- [escaped-eof.html](https://wpt.fyi/results/css/css-syntax/escaped-eof.html "css/css-syntax/escaped-eof.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/escaped-eof.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/escaped-eof.html)

#### 4.3.8. Check if two code points are a valid escape

This section describes how to [check if two code points are a valid
escape]. The algorithm described here can be called explicitly with
two [code
points](https://infra.spec.whatwg.org/#code-point), or can be called with the input stream itself. In the
latter case, the two [code points] in question
are the [current input code
point](#current-input-code-point) and the [next input code
point](#next-input-code-point), in that order.

 This algorithm will not consume any additional [code
point](https://infra.spec.whatwg.org/#code-point).

If the first [code
point](https://infra.spec.whatwg.org/#code-point) is not U+005C REVERSE SOLIDUS (\\), return false.

Otherwise, if the second [code
point](https://infra.spec.whatwg.org/#code-point) is a [newline](#newline), return false.

Otherwise, return true.

#### 4.3.9. Check if three code points would start an ident sequence

This section describes how to
[check if three code points would start an [ident
sequence](#ident-sequence)]. The algorithm described here can be called explicitly with
three [code
points](https://infra.spec.whatwg.org/#code-point), or can be called with the input stream itself. In the
latter case, the three [code points] in question
are the [current input code
point](#current-input-code-point) and the [next two input code
points](#next-input-code-point), in that order.

 This algorithm will not consume any additional [code
points](https://infra.spec.whatwg.org/#code-point).

Look at the first [code
point](https://infra.spec.whatwg.org/#code-point):

U+002D HYPHEN-MINUS
: If the second [code
 point](https://infra.spec.whatwg.org/#code-point) is an [ident-start code
 point](#ident-start-code-point) or a U+002D HYPHEN-MINUS, or the second and third
 [code points] [are a valid
 escape](#check-if-two-code-points-are-a-valid-escape), return true. Otherwise, return false.

[ident-start code point](#ident-start-code-point)
: Return true.

U+005C REVERSE SOLIDUS (\\)
: If the first and second [code
 points](https://infra.spec.whatwg.org/#code-point) [are a valid
 escape](#check-if-two-code-points-are-a-valid-escape), return true. Otherwise, return false.

anything else
: Return false.

Tests

- [ident-three-code-points.html](https://wpt.fyi/results/css/css-syntax/ident-three-code-points.html "css/css-syntax/ident-three-code-points.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/ident-three-code-points.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/ident-three-code-points.html)

#### 4.3.10. Check if three code points would start a number

This section describes how to [check if three code points would start a
number]. The algorithm described here can be called explicitly with
three [code
points](https://infra.spec.whatwg.org/#code-point), or can be called with the input stream itself. In the
latter case, the three [code points] in question
are the [current input code
point](#current-input-code-point) and the [next two input code
points](#next-input-code-point), in that order.

 This algorithm will not consume any additional [code
points](https://infra.spec.whatwg.org/#code-point).

Look at the first [code
point](https://infra.spec.whatwg.org/#code-point):

U+002B PLUS SIGN (+)\
U+002D HYPHEN-MINUS (-)

: If the second [code
 point](https://infra.spec.whatwg.org/#code-point) is a [digit](#digit), return true.

 Otherwise, if the second [code
 point](https://infra.spec.whatwg.org/#code-point) is a U+002E FULL STOP (.) and the third [code
 point] is a [digit](#digit), return true.

 Otherwise, return false.

U+002E FULL STOP (.)
: If the second [code
 point](https://infra.spec.whatwg.org/#code-point) is a [digit](#digit), return true. Otherwise, return false.

[digit](#digit)
: Return true.

anything else
: Return false.

#### 4.3.11. Check if three code points would start a unicode-range

This section describes how to [check if three code points would start a
unicode-range]. The algorithm described here can be called explicitly with
three [code
points](https://infra.spec.whatwg.org/#code-point), or can be called with the input stream itself. In the
latter case, the three [code points] in question
are the [current input code
point](#current-input-code-point) and the [next two input code
points](#next-input-code-point), in that order.

 This algorithm will not consume any additional [code
points](https://infra.spec.whatwg.org/#code-point).

If all of the following are true:

- The first code point is either U+0055 LATIN CAPITAL LETTER U (U) or
 U+0075 LATIN SMALL LETTER U (u)

- The second code point is U+002B PLUS SIGN (+).

- The third code point is either U+003F QUESTION MARK (?) or a [hex
 digit](#hex-digit)

then return true.

Otherwise return false.

#### 4.3.12. Consume an ident sequence

This section describes how to [consume an ident sequence] from a stream of [code
points](https://infra.spec.whatwg.org/#code-point). It returns a string containing the largest name that
can be formed from adjacent [code points] in the
stream, starting from the first.

 This algorithm does not do the verification of the
first few [code
points](https://infra.spec.whatwg.org/#code-point) that are necessary to ensure the returned [code
points] would constitute an
[\<ident-token\>](#typedef-ident-token). If that is the intended use, ensure
that the stream [starts with an ident
sequence](#check-if-three-code-points-would-start-an-ident-sequence) before calling this algorithm.

Let `result` initially be an empty string.

Repeatedly consume the [next input code
point](#next-input-code-point) from the stream:

[ident code point](#ident-code-point)
: Append the [code
 point](https://infra.spec.whatwg.org/#code-point) to `result`.

the stream [starts with a valid escape](#check-if-two-code-points-are-a-valid-escape)
: [Consume an escaped code
 point](#consume-an-escaped-code-point). Append the returned [code
 point](https://infra.spec.whatwg.org/#code-point) to `result`.

anything else
: [Reconsume the current input code
 point](#reconsume-the-current-input-code-point). Return `result`.

#### 4.3.13. Consume a number

This section describes how to [consume a number] from a stream of [code
points](https://infra.spec.whatwg.org/#code-point). It returns a numeric `value`, a string
`type` which is either \"integer\" or \"number\", and an
optional `sign character` which is either \"+\", \"-\", or
missing.

 This algorithm does not do the verification of the
first few [code
points](https://infra.spec.whatwg.org/#code-point) that are necessary to ensure a number can be obtained
from the stream. Ensure that the stream [starts with a
number](#check-if-three-code-points-would-start-a-number) before calling this algorithm.

Execute the following steps in order:

1. Let `type` be the string \"integer\". Let
 `number part` and `exponent part` be the empty
 string.

2. If the [next input code
 point](#next-input-code-point) is U+002B PLUS SIGN (+) or U+002D HYPHEN-MINUS (-),
 consume it. Append it to `number part` and set
 `sign character` to it.

3. While the [next input code
 point](#next-input-code-point) is a [digit](#digit), consume it and append it to
 `number part`.

4. If the [next 2 input code
 points](#next-input-code-point) are U+002E FULL STOP (.) followed by a
 [digit](#digit), then:
 1. Consume the [next input code
 point](#next-input-code-point) and append it to `number part`.
 2. While the [next input code
 point](#next-input-code-point) is a [digit](#digit), consume it and append it to
 `number part`.
 3. Set `type` to \"number\".

5. If the [next 2 or 3 input code
 points](#next-input-code-point) are U+0045 LATIN CAPITAL LETTER E (E) or U+0065
 LATIN SMALL LETTER E (e), optionally followed by U+002D HYPHEN-MINUS
 (-) or U+002B PLUS SIGN (+), followed by a
 [digit](#digit), then:
 1. Consume the [next input code
 point](#next-input-code-point).
 2. If the [next input code
 point](#next-input-code-point) is \"+\" or \"-\", consume it and append it to
 `exponent part`.
 3. While the [next input code
 point](#next-input-code-point) is a [digit](#digit), consume it and append it to
 `exponent part`.
 4. Set `type` to \"number\".

6. Let `value` be the result of interpreting
 `number part` as a base-10 number.

 If `exponent part` is non-empty, interpret it as a
 base-10 integer, then raise 10 to the power of the result, multiply
 it by `value`, and set `value` to that result.

7. Return `value`, `type`, and
 `sign character`.

Tests

- [decimal-points-in-numbers.html](https://wpt.fyi/results/css/css-syntax/decimal-points-in-numbers.html "css/css-syntax/decimal-points-in-numbers.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/decimal-points-in-numbers.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/decimal-points-in-numbers.html)

#### 4.3.14. Consume a unicode-range token

This section describes how to [consume a unicode-range
token] from a stream of [code
points](https://infra.spec.whatwg.org/#code-point). It returns a
[\<unicode-range-token\>](#typedef-unicode-range-token).

 This algorithm does not do the verification of the
first few code points that are necessary to ensure the returned code
points would constitute an
[\<unicode-range-token\>](#typedef-unicode-range-token). Ensure that the stream [would start
a
unicode-range](#check-if-three-code-points-would-start-a-unicode-range) before calling this algorithm.

 This token is not produced by the tokenizer under
normal circumstances. This algorithm is only called during [consume the
value of a unicode-range
descriptor](#consume-the-value-of-a-unicode-range-descriptor), which itself is only called as a special case for
parsing the
[unicode-range](https://drafts.csswg.org/css-fonts-4/#descdef-font-face-unicode-range) descriptor; this single invocation in
the entire language is due to a bad syntax design in early CSS.

1. Consume the [next two input code
 points](#next-input-code-point) and discard them.

2. Consume as many [hex digits](#hex-digit) as possible, but no more than 6. If less than 6 hex
 digits were consumed, consume as many U+003F QUESTION MARK (?) code
 points as possible, but no more than enough to make the total of hex
 digits and U+003F QUESTION MARK (?) code points equal to 6.

 Let `first segment` be the consumed code points.

3. If `first segment` contains any question mark code
 points, then:

 1. Replace the question marks in `first segment` with
 U+0030 DIGIT ZERO (0) [code
 points](https://infra.spec.whatwg.org/#code-point), and interpret the result as a hexadecimal
 number. Let this be `start of range`.

 2. Replace the question marks in `first segment` with
 U+0046 LATIN CAPITAL LETTER F (F) [code
 points](https://infra.spec.whatwg.org/#code-point), and interpret the result as a hexadecimal
 number. Let this be `end of range`.

 3. Return a new
 [\<unicode-range-token\>](#typedef-unicode-range-token) starting at
 `start of range` and ending at
 `end of range`.

4. Otherwise, interpret `first segment` as a hexadecimal
 number, and let the result be `start of range`.

5. If the [next 2 input code
 points](#next-input-code-point) are U+002D HYPHEN-MINUS (-) followed by a [hex
 digit](#hex-digit), then:

 1. Consume the [next input code
 point](#next-input-code-point).

 2. Consume as many [hex digits](#hex-digit) as possible, but no more than 6. Interpret the
 consumed code points as a hexadecimal number. Let this be
 `end of range`.

 3. Return a new
 [\<unicode-range-token\>](#typedef-unicode-range-token) starting at
 `start of range` and ending at
 `end of range`.

6. Otherwise, return a new
 [\<unicode-range-token\>](#typedef-unicode-range-token) both starting and ending at
 `start of range`.

#### 4.3.15. Consume the remnants of a bad url

This section describes how to [consume the remnants of a bad
url] from a stream of [code
points](https://infra.spec.whatwg.org/#code-point), \"cleaning up\" after the tokenizer realizes that it's
in the middle of a
[\<bad-url-token\>](#typedef-bad-url-token) rather than a
[\<url-token\>](#typedef-url-token). It returns nothing; its sole use is to
consume enough of the input stream to reach a recovery point where
normal tokenizing can resume.

Repeatedly consume the [next input code
point](#next-input-code-point) from the stream:

U+0029 RIGHT PARENTHESIS ())\
EOF
: Return.

the input stream [starts with a valid escape](#check-if-two-code-points-are-a-valid-escape)
: [Consume an escaped code
 point](#consume-an-escaped-code-point). [This allows an escaped right parenthesis
 (\"\\)\") to be encountered without ending the
 [\<bad-url-token\>](#typedef-bad-url-token). This is otherwise identical to
 the \"anything else\" clause.]

anything else
: Do nothing.

## 5. Parsing

The CSS parser converts a [token
stream](#css-token-stream)
(produced by the tokenization process, defined earlier in this spec)
into one or more of several CSS constructs (depending on which parsing
algorithm is invoked).

### 5.1. Parser Railroad Diagrams

*This section is non-normative.*

This section presents an informative view of the parser, in the form of
railroad diagrams.

These diagrams are *informative* and *incomplete*; they describe the
grammar of \"correct\" stylesheets, but do not describe error-handling
at all. They are provided solely to make it easier to get an intuitive
grasp of the syntax.

Stylesheet

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxOTgiIHZpZXdib3g9IjAgMCAzNTMuMCAxOTgiIHdpZHRoPSIzNTMuMCI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMTE5djIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTQwIDEyOWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0zMTMuMCAxMjloMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAxMjlhMTAgMTAgMCAwIDAgMTAgLTEwdi04OWExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgMjBoMjMzLjAiIC8+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTI5My4wIDIwYTEwIDEwIDAgMCAxIDEwIDEwdjg5YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAxMjloMjAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgMTI5aDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yOTMuMCAxMjloMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgMTI5aDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTcwLjAgMTI5aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjgzLjAgMTI5aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNNzAuMCAxMjlhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik05MC4wIDk5aDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTI2My4wIDk5aDAuMCIgLz4KICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjE3MyIgeD0iOTAiIHk9Ijg4IiAvPgogICAgICAgICAgICA8dGV4dCB4PSIxNzYuNSIgeT0iMTAzIj4mbHQ7d2hpdGVzcGFjZS10b2tlbiZndDs8L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yNjMuMCA5OWExMCAxMCAwIDAgMSAxMCAxMHYxMGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNNzAuMCAxMjlhMTAgMTAgMCAwIDAgMTAgLTEwdi00MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik05MC4wIDY5aDI5Ljc1IiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjMzLjI1IDY5aDI5Ljc1IiAvPgogICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTEzLjUiIHg9IjExOS43NSIgeT0iNTgiIC8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjE3Ni41IiB5PSI3MyI+Jmx0O0NEQy10b2tlbiZndDs8L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yNjMuMCA2OWExMCAxMCAwIDAgMSAxMCAxMHY0MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNNzAuMCAxMjlhMTAgMTAgMCAwIDAgMTAgLTEwdi03MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik05MC4wIDM5aDI5Ljc1IiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjMzLjI1IDM5aDI5Ljc1IiAvPgogICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTEzLjUiIHg9IjExOS43NSIgeT0iMjgiIC8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjE3Ni41IiB5PSI0MyI+Jmx0O0NETy10b2tlbiZndDs8L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yNjMuMCAzOWExMCAxMCAwIDAgMSAxMCAxMHY3MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNNzAuMCAxMjloMjAiIC8+CiAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik05MC4wIDEyOWgxNy4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjQ2LjAgMTI5aDE3LjAiIC8+CiAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxMzkiIHg9IjEwNyIgeT0iMTE4IiAvPgogICAgICAgICAgICA8dGV4dCB4PSIxNzYuNSIgeT0iMTMzIj5RdWFsaWZpZWQgcnVsZTwvdGV4dD4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTI2My4wIDEyOWgyMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNNzAuMCAxMjlhMTAgMTAgMCAwIDEgMTAgMTB2MTBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik05MC4wIDE1OWg0Ni43NSIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTIxNi4yNSAxNTloNDYuNzUiIC8+CiAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI3OS41IiB4PSIxMzYuNzUiIHk9IjE0OCIgLz4KICAgICAgICAgICAgPHRleHQgeD0iMTc2LjUiIHk9IjE2MyI+QXQtcnVsZTwvdGV4dD4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTI2My4wIDE1OWExMCAxMCAwIDAgMCAxMCAtMTB2LTEwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yODMuMCAxMjloMTAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNzAuMCAxMjlhMTAgMTAgMCAwIDAgLTEwIDEwdjI5YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTcwLjAgMTc4aDIxMy4wIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTI4My4wIDE3OGExMCAxMCAwIDAgMCAxMCAtMTB2LTI5YTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTI5My4wIDEyOWgyMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTSAzMTMuMCAxMjkgaCAyMCBtIC0xMCAtMTAgdiAyMCBtIDEwIC0yMCB2IDIwIiAvPgogICAgICAgPC9nPgogICAgICA8L3N2Zz4=)
 :::

At-rule

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxMDEiIHZpZXdib3g9IjAgMCA2MDguNSAxMDEiIHdpZHRoPSI2MDguNSI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMzB2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik00MCA0MGgxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTUwIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTIyMy4wIDQwaDAuMCIgLz4KICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjE3MyIgeD0iNTAiIHk9IjI5IiAvPgogICAgICAgICA8dGV4dCB4PSIxMzYuNSIgeT0iNDQiPiZsdDthdC1rZXl3b3JkLXRva2VuJmd0OzwvdGV4dD4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTIyMy4wIDQwaDEwIiAvPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjMzLjAgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDQwLjUgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMjMzLjAgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yNTMuMCAyMGgxNjcuNSIgLz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNNDIwLjUgMjBhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTIzMy4wIDQwaDIwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yNTMuMCA0MGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNDIwLjUgNDBoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTI1My4wIDQwaDEwIiAvPgogICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTI2My4wIDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNNDEwLjUgNDBoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxNDcuNSIgeD0iMjYzIiB5PSIyOSIgLz4KICAgICAgICAgICA8dGV4dCB4PSIzMzYuNzUiIHk9IjQ0Ij5Db21wb25lbnQgdmFsdWU8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNNDEwLjUgNDBoMTAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMjYzLjAgNDBhMTAgMTAgMCAwIDAgLTEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNMjYzLjAgNjBoMTQ3LjUiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNNDEwLjUgNjBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNNDIwLjUgNDBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNNDQwLjUgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNTY4LjUgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDQwLjUgNDBoMjAiIC8+CiAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgPHBhdGggZD0iTTQ2MC41IDQwaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik01NDguNSA0MGgwLjAiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iODgiIHg9IjQ2MC41IiB5PSIyOSIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjUwNC41IiB5PSI0NCI+e30gYmxvY2s8L3RleHQ+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTU0OC41IDQwaDIwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDQwLjUgNDBhMTAgMTAgMCAwIDEgMTAgMTB2MTBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICA8cGF0aCBkPSJNNDYwLjUgNzBoMjkuNzUiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNTE4Ljc1IDcwaDI5Ljc1IiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSI0OTAuMjUiIHk9IjU5IiAvPgogICAgICAgICAgPHRleHQgeD0iNTA0LjUiIHk9Ijc0Ij47PC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik01NDguNSA3MGExMCAxMCAwIDAgMCAxMCAtMTB2LTEwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTSA1NjguNSA0MCBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

Qualified rule

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSI4MCIgdmlld2JveD0iMCAwIDM5NS41IDgwIiB3aWR0aD0iMzk1LjUiPgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTIwIDMwdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTQwIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTI0Ny41IDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQwLjAgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDIwaDE2Ny41IiAvPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0yMjcuNSAyMGExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCA0MGgyMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCA0MGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMjI3LjUgNDBoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgNDBoMTAiIC8+CiAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNNzAuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTIxNy41IDQwaDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTQ3LjUiIHg9IjcwIiB5PSIyOSIgLz4KICAgICAgICAgICA8dGV4dCB4PSIxNDMuNzUiIHk9IjQ0Ij5Db21wb25lbnQgdmFsdWU8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMjE3LjUgNDBoMTAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNzAuMCA0MGExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik03MC4wIDYwaDE0Ny41IiAvPgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTIxNy41IDYwYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTIyNy41IDQwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMjQ3LjUgNDBoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgIDxwYXRoIGQ9Ik0yNTcuNSA0MGgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0zNDUuNSA0MGgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI4OCIgeD0iMjU3LjUiIHk9IjI5IiAvPgogICAgICAgICA8dGV4dCB4PSIzMDEuNSIgeT0iNDQiPnt9IGJsb2NrPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMzQ1LjUgNDBoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTSAzNTUuNSA0MCBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

block

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxNjEiIHZpZXdib3g9IjAgMCA1NzAuMCAxNjEiIHdpZHRoPSI1NzAuMCI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMzB2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik00MCA0MGgxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNNTAgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNzguNSA0MGgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iNTAiIHk9IjI5IiAvPgogICAgICAgICA8dGV4dCB4PSI2NC4yNSIgeT0iNDQiPns8L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik03OC41IDQwaDEwIiAvPgogICAgICAgIDxwYXRoIGQ9Ik04OC41IDQwaDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNOTguNSA0MGgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0xNDQuMCA0MGgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI0NS41IiB4PSI5OC41IiB5PSIyOSIgLz4KICAgICAgICAgPHRleHQgeD0iMTIxLjI1IiB5PSI0NCI+d3MqPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMTQ0LjAgNDBoMTAiIC8+CiAgICAgICAgPGc+CiAgICAgICAgIDxwYXRoIGQ9Ik0xNTQuMCA0MGgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik00MTYuMCA0MGgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0xNTQuMCA0MGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTE3NC4wIDIwaDIyMi4wIiAvPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0zOTYuMCAyMGExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNMTU0LjAgNDBoMjAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTE3NC4wIDQwaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zOTYuMCA0MGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMTc0LjAgNDBoMTAiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNMTg0LjAgNDBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zODYuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTE4NC4wIDQwaDIwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMjA0LjAgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMzY2LjAgNDBoMC4wIiAvPgogICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMDQuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMzE3LjUgNDBoMC4wIiAvPgogICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjExMy41IiB4PSIyMDQiIHk9IjI5IiAvPgogICAgICAgICAgICAgPHRleHQgeD0iMjYwLjc1IiB5PSI0NCI+RGVjbGFyYXRpb248L3RleHQ+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTMxNy41IDQwaDEwIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMzI3LjUgNDBoMTAiIC8+CiAgICAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMzM3LjUgNDBoMC4wIiAvPgogICAgICAgICAgICAgPHBhdGggZD0iTTM2Ni4wIDQwaDAuMCIgLz4KICAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iMzM3LjUiIHk9IjI5IiAvPgogICAgICAgICAgICAgPHRleHQgeD0iMzUxLjc1IiB5PSI0NCI+OzwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMzY2LjAgNDBoMjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTE4NC4wIDQwYTEwIDEwIDAgMCAxIDEwIDEwdjEwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICA8cGF0aCBkPSJNMjA0LjAgNzBoNDEuMjUiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMjQuNzUgNzBoNDEuMjUiIC8+CiAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI3OS41IiB4PSIyNDUuMjUiIHk9IjU5IiAvPgogICAgICAgICAgICA8dGV4dCB4PSIyODUiIHk9Ijc0Ij5BdC1ydWxlPC90ZXh0PgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMzY2LjAgNzBhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTE4NC4wIDQwYTEwIDEwIDAgMCAxIDEwIDEwdjQwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICA8cGF0aCBkPSJNMjA0LjAgMTAwaDExLjUiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNTQuNSAxMDBoMTEuNSIgLz4KICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjEzOSIgeD0iMjE1LjUiIHk9Ijg5IiAvPgogICAgICAgICAgICA8dGV4dCB4PSIyODUiIHk9IjEwNCI+UXVhbGlmaWVkIHJ1bGU8L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNjYuMCAxMDBhMTAgMTAgMCAwIDAgMTAgLTEwdi00MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMzg2LjAgNDBoMTAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMTg0LjAgNDBhMTAgMTAgMCAwIDAgLTEwIDEwdjcwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTE4NC4wIDEzMGg3OC4yNSIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzA3Ljc1IDEzMGg3OC4yNSIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iMjYyLjI1IiB5PSIxMTkiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMjg1IiB5PSIxMzQiPndzKjwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zODYuMCAxMzBhMTAgMTAgMCAwIDAgMTAgLTEwdi03MGExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0zOTYuMCA0MGgyMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTQxNi4wIDQwaDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNNDI2LjAgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDcxLjUgNDBoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iNDI2IiB5PSIyOSIgLz4KICAgICAgICAgPHRleHQgeD0iNDQ4Ljc1IiB5PSI0NCI+d3MqPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDcxLjUgNDBoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTTQ4MS41IDQwaDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgIDxwYXRoIGQ9Ik00OTEuNSA0MGgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik01MjAuMCA0MGgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iNDkxLjUiIHk9IjI5IiAvPgogICAgICAgICA8dGV4dCB4PSI1MDUuNzUiIHk9IjQ0Ij59PC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNTIwLjAgNDBoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTSA1MzAuMCA0MCBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

Declaration

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSI5MSIgdmlld2JveD0iMCAwIDY5Ny4wIDkxIiB3aWR0aD0iNjk3LjAiPgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTIwIDMwdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDAgNDBoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgIDxwYXRoIGQ9Ik01MCA0MGgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0xODAuNSA0MGgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxMzAuNSIgeD0iNTAiIHk9IjI5IiAvPgogICAgICAgICA8dGV4dCB4PSIxMTUuMjUiIHk9IjQ0Ij4mbHQ7aWRlbnQtdG9rZW4mZ3Q7PC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMTgwLjUgNDBoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTTE5MC41IDQwaDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNMjAwLjUgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMjQ2LjAgNDBoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iMjAwLjUiIHk9IjI5IiAvPgogICAgICAgICA8dGV4dCB4PSIyMjMuMjUiIHk9IjQ0Ij53cyo8L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0yNDYuMCA0MGgxMCIgLz4KICAgICAgICA8cGF0aCBkPSJNMjU2LjAgNDBoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTI2Ni4wIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTI5NC41IDQwaDAuMCIgLz4KICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSIyNjYiIHk9IjI5IiAvPgogICAgICAgICA8dGV4dCB4PSIyODAuMjUiIHk9IjQ0Ij46PC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMjk0LjUgNDBoMTAiIC8+CiAgICAgICAgPGc+CiAgICAgICAgIDxwYXRoIGQ9Ik0zMDQuNSA0MGgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik01MTIuMCA0MGgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0zMDQuNSA0MGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTMyNC41IDIwaDE2Ny41IiAvPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik00OTIuMCAyMGExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNMzA0LjUgNDBoMjAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTMyNC41IDQwaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik00OTIuMCA0MGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMzI0LjUgNDBoMTAiIC8+CiAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNMzM0LjUgNDBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik00ODIuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjE0Ny41IiB4PSIzMzQuNSIgeT0iMjkiIC8+CiAgICAgICAgICAgPHRleHQgeD0iNDA4LjI1IiB5PSI0NCI+Q29tcG9uZW50IHZhbHVlPC90ZXh0PgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTQ4Mi4wIDQwaDEwIiAvPgogICAgICAgICAgPHBhdGggZD0iTTMzNC41IDQwYTEwIDEwIDAgMCAwIC0xMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTMzNC41IDYwaDE0Ny41IiAvPgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTQ4Mi4wIDYwYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTQ5Mi4wIDQwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTUxMi4wIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTY1Ny4wIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTUxMi4wIDQwaDIwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik01MzIuMCA0MGgxMDUuMCIgLz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNNjM3LjAgNDBoMjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik01MTIuMCA0MGExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik01MzIuMCA2MGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNjM3LjAgNjBoMC4wIiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjEwNSIgeD0iNTMyIiB5PSI0OSIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjU4NC41IiB5PSI2NCI+IWltcG9ydGFudDwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNNjM3LjAgNjBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNIDY1Ny4wIDQwIGggMjAgbSAtMTAgLTEwIHYgMjAgbSAxMCAtMjAgdiAyMCIgLz4KICAgICAgIDwvZz4KICAgICAgPC9zdmc+)
 :::

(#!important-diagram)!important

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSI2MiIgdmlld2JveD0iMCAwIDUxMi4wIDYyIiB3aWR0aD0iNTEyLjAiPgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTIwIDIxdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTUwIDMxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTc4LjUgMzFoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjUwIiB5PSIyMCIgLz4KICAgICAgICAgPHRleHQgeD0iNjQuMjUiIHk9IjM1Ij4hPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNzguNSAzMWgxMCIgLz4KICAgICAgICA8cGF0aCBkPSJNODguNSAzMWgxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTk4LjUgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMTQ0LjAgMzFoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iOTguNSIgeT0iMjAiIC8+CiAgICAgICAgIDx0ZXh0IHg9IjEyMS4yNSIgeT0iMzUiPndzKjwvdGV4dD4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTE0NC4wIDMxaDEwIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0xNTQuMCAzMWgxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTE2NC4wIDMxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTM5Ni41IDMxaDAuMCIgLz4KICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjIzMi41IiB4PSIxNjQiIHk9IjIwIiAvPgogICAgICAgICA8dGV4dCB4PSIyODAuMjUiIHk9IjM1Ij4mbHQ7aWRlbnQtdG9rZW4gJnF1b3Q7aW1wb3J0YW50JnF1b3Q7Jmd0OzwvdGV4dD4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTM5Ni41IDMxaDEwIiAvPgogICAgICAgIDxwYXRoIGQ9Ik00MDYuNSAzMWgxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTQxNi41IDMxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQ2Mi4wIDMxaDAuMCIgLz4KICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjQ1LjUiIHg9IjQxNi41IiB5PSIyMCIgLz4KICAgICAgICAgPHRleHQgeD0iNDM5LjI1IiB5PSIzNSI+d3MqPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDYyLjAgMzFoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTSA0NzIuMCAzMSBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

Component value

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxMjIiIHZpZXdib3g9IjAgMCAyNjcuNSAxMjIiIHdpZHRoPSIyNjcuNSI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMjF2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMjI3LjUgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWgyMCIgLz4KICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCAzMWgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMjA3LjUgMzFoMC4wIiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjE0Ny41IiB4PSI2MCIgeT0iMjAiIC8+CiAgICAgICAgICA8dGV4dCB4PSIxMzMuNzUiIHk9IjM1Ij5QcmVzZXJ2ZWQgdG9rZW48L3RleHQ+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTIwNy41IDMxaDIwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWExMCAxMCAwIDAgMSAxMCAxMHYxMGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCA2MWgxMi43NSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xOTQuNzUgNjFoMTIuNzUiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTIyIiB4PSI3Mi43NSIgeT0iNTAiIC8+CiAgICAgICAgICA8dGV4dCB4PSIxMzMuNzUiIHk9IjY1Ij5TaW1wbGUgYmxvY2s8L3RleHQ+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTIwNy41IDYxYTEwIDEwIDAgMCAwIDEwIC0xMHYtMTBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWExMCAxMCAwIDAgMSAxMCAxMHY0MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCA5MWg0LjI1IiAvPgogICAgICAgICAgPHBhdGggZD0iTTIwMy4yNSA5MWg0LjI1IiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjEzOSIgeD0iNjQuMjUiIHk9IjgwIiAvPgogICAgICAgICAgPHRleHQgeD0iMTMzLjc1IiB5PSI5NSI+RnVuY3Rpb24gYmxvY2s8L3RleHQ+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTIwNy41IDkxYTEwIDEwIDAgMCAwIDEwIC0xMHYtNDBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNIDIyNy41IDMxIGggMjAgbSAtMTAgLTEwIHYgMjAgbSAxMCAtMjAgdiAyMCIgLz4KICAgICAgIDwvZz4KICAgICAgPC9zdmc+)
 :::

Simple block

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxNzYiIHZpZXdib3g9IjAgMCA0MDQuNSAxNzYiIHdpZHRoPSI0MDQuNSI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMzB2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNNDAgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMzY0LjUgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCA0MGgyMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCA0MGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMzQ0LjUgNDBoMC4wIiAvPgogICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNNjAuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTg4LjUgNDBoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iNjAiIHk9IjI5IiAvPgogICAgICAgICAgIDx0ZXh0IHg9Ijc0LjI1IiB5PSI0NCI+ezwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik04OC41IDQwaDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTk4LjUgNDBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zMDYuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTk4LjUgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMTE4LjUgMjBoMTY3LjUiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yODYuMCAyMGExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik05OC41IDQwaDIwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMTE4LjUgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjg2LjAgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMTE4LjUgNDBoMTAiIC8+CiAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgPHBhdGggZD0iTTEyOC41IDQwaDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNzYuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTQ3LjUiIHg9IjEyOC41IiB5PSIyOSIgLz4KICAgICAgICAgICAgIDx0ZXh0IHg9IjIwMi4yNSIgeT0iNDQiPkNvbXBvbmVudCB2YWx1ZTwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMjc2LjAgNDBoMTAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xMjguNSA0MGExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgNjBoMTQ3LjUiIC8+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTI3Ni4wIDYwYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yODYuMCA0MGgyMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zMDYuMCA0MGgxMCIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTMxNi4wIDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzQ0LjUgNDBoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iMzE2IiB5PSIyOSIgLz4KICAgICAgICAgICA8dGV4dCB4PSIzMzAuMjUiIHk9IjQ0Ij59PC90ZXh0PgogICAgICAgICAgPC9nPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0zNDQuNSA0MGgyMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQwLjAgNDBhMTAgMTAgMCAwIDEgMTAgMTB2MjhhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgODhoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTM0NC41IDg4aDAuMCIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTYwLjAgODhoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik04OC41IDg4aDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjYwIiB5PSI3NyIgLz4KICAgICAgICAgICA8dGV4dCB4PSI3NC4yNSIgeT0iOTIiPig8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNODguNSA4OGgxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik05OC41IDg4aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzA2LjAgODhoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik05OC41IDg4YTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTExOC41IDY4aDE2Ny41IiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMjg2LjAgNjhhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNOTguNSA4OGgyMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTExOC41IDg4aDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTI4Ni4wIDg4aDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTExOC41IDg4aDEwIiAvPgogICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0xMjguNSA4OGgwLjAiIC8+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjc2LjAgODhoMC4wIiAvPgogICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjE0Ny41IiB4PSIxMjguNSIgeT0iNzciIC8+CiAgICAgICAgICAgICA8dGV4dCB4PSIyMDIuMjUiIHk9IjkyIj5Db21wb25lbnQgdmFsdWU8L3RleHQ+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTI3Ni4wIDg4aDEwIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgODhhMTAgMTAgMCAwIDAgLTEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgIDxnPgogICAgICAgICAgICAgPHBhdGggZD0iTTEyOC41IDEwOGgxNDcuNSIgLz4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMjc2LjAgMTA4YTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yODYuMCA4OGgyMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zMDYuMCA4OGgxMCIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTMxNi4wIDg4aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzQ0LjUgODhoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iMzE2IiB5PSI3NyIgLz4KICAgICAgICAgICA8dGV4dCB4PSIzMzAuMjUiIHk9IjkyIj4pPC90ZXh0PgogICAgICAgICAgPC9nPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0zNDQuNSA4OGExMCAxMCAwIDAgMCAxMCAtMTB2LTI4YTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQwLjAgNDBhMTAgMTAgMCAwIDEgMTAgMTB2NzZhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgMTM2aDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zNDQuNSAxMzZoMC4wIiAvPgogICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNNjAuMCAxMzZoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik04OC41IDEzNmgwLjAiIC8+CiAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSI2MCIgeT0iMTI1IiAvPgogICAgICAgICAgIDx0ZXh0IHg9Ijc0LjI1IiB5PSIxNDAiPls8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNODguNSAxMzZoMTAiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNOTguNSAxMzZoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zMDYuMCAxMzZoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik05OC41IDEzNmExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xMTguNSAxMTZoMTY3LjUiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yODYuMCAxMTZhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNOTguNSAxMzZoMjAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xMTguNSAxMzZoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjg2LjAgMTM2aDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTExOC41IDEzNmgxMCIgLz4KICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgMTM2aDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNzYuMCAxMzZoMC4wIiAvPgogICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjE0Ny41IiB4PSIxMjguNSIgeT0iMTI1IiAvPgogICAgICAgICAgICAgPHRleHQgeD0iMjAyLjI1IiB5PSIxNDAiPkNvbXBvbmVudCB2YWx1ZTwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMjc2LjAgMTM2aDEwIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMTI4LjUgMTM2YTEwIDEwIDAgMCAwIC0xMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICA8Zz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0xMjguNSAxNTZoMTQ3LjUiIC8+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTI3Ni4wIDE1NmExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMjg2LjAgMTM2aDIwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTMwNi4wIDEzNmgxMCIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTMxNi4wIDEzNmgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTM0NC41IDEzNmgwLjAiIC8+CiAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSIzMTYiIHk9IjEyNSIgLz4KICAgICAgICAgICA8dGV4dCB4PSIzMzAuMjUiIHk9IjE0MCI+XTwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMzQ0LjUgMTM2YTEwIDEwIDAgMCAwIDEwIC0xMHYtNzZhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNIDM2NC41IDQwIGggMjAgbSAtMTAgLTEwIHYgMjAgbSAxMCAtMjAgdiAyMCIgLz4KICAgICAgIDwvZz4KICAgICAgPC9zdmc+)
 :::

Function block

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSI4MCIgdmlld2JveD0iMCAwIDUxMi4wIDgwIiB3aWR0aD0iNTEyLjAiPgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTIwIDMwdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDAgNDBoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgIDxwYXRoIGQ9Ik01MCA0MGgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0yMDYuMCA0MGgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxNTYiIHg9IjUwIiB5PSIyOSIgLz4KICAgICAgICAgPHRleHQgeD0iMTI4IiB5PSI0NCI+Jmx0O2Z1bmN0aW9uLXRva2VuJmd0OzwvdGV4dD4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTIwNi4wIDQwaDEwIiAvPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjE2LjAgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDIzLjUgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMjE2LjAgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yMzYuMCAyMGgxNjcuNSIgLz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNNDAzLjUgMjBhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTIxNi4wIDQwaDIwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yMzYuMCA0MGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNDAzLjUgNDBoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTIzNi4wIDQwaDEwIiAvPgogICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTI0Ni4wIDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzkzLjUgNDBoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxNDcuNSIgeD0iMjQ2IiB5PSIyOSIgLz4KICAgICAgICAgICA8dGV4dCB4PSIzMTkuNzUiIHk9IjQ0Ij5Db21wb25lbnQgdmFsdWU8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMzkzLjUgNDBoMTAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMjQ2LjAgNDBhMTAgMTAgMCAwIDAgLTEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNMjQ2LjAgNjBoMTQ3LjUiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMzkzLjUgNjBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNNDAzLjUgNDBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik00MjMuNSA0MGgxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNNDMzLjUgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDYyLjAgNDBoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjQzMy41IiB5PSIyOSIgLz4KICAgICAgICAgPHRleHQgeD0iNDQ3Ljc1IiB5PSI0NCI+KTwvdGV4dD4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTQ2Mi4wIDQwaDEwIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0gNDcyLjAgNDAgaCAyMCBtIC0xMCAtMTAgdiAyMCBtIDEwIC0yMCB2IDIwIiAvPgogICAgICAgPC9nPgogICAgICA8L3N2Zz4=)
 :::

### 5.2. CSS Parsing Results

The result of parsing can be any of the following (or lists of these):

[stylesheet]

: A stylesheet has a list of [rules](#css-rule).

[rule]

: A [rule](#css-rule) is either an
 [at-rule](#at-rule) or a
 [qualified rule](#qualified-rule).

[at-rule](#at-rule)
: An [at-rule](#at-rule) has a
 name which is a
 [string](https://infra.spec.whatwg.org/#string), a prelude consisting of a list of [component
 values](#component-value).
 [Block at-rules](#block-at-rule) (ending in a -block) will additionally have a
 list of [declarations](#declaration) and a list of child
 [rules](#css-rule). ([Statement
 at-rules](#statement-at-rule), ending in a semicolon, will not.)

[qualified rule]

: A qualified rule has a prelude consisting of a list of component
 values, a list of declarations, and a list of child rules.

 Most qualified rules will be style rules, where the
 prelude is a selector
 [\[selectors-4\]](#biblio-selectors-4 "Selectors Level 4")
 and its declarations are
 [properties](https://drafts.csswg.org/css-cascade-5/#css-property).

[declaration]

: A declaration has a name which is a
 [string](https://infra.spec.whatwg.org/#string), a value consisting of a list of [component
 values](#component-value), and an `important` flag which is
 initially unset. It also has an optional `original text`
 which is a [string] (captured for only a few
 declarations).

 Declarations are further categorized as [property
 declarations] or [descriptor
 declarations], with the former setting CSS
 [properties](https://drafts.csswg.org/css-cascade-5/#css-property) and appearing most often in [qualified
 rules](#qualified-rule)
 and the latter setting CSS
 [descriptors](#css-descriptor), which appear only in
 [at-rules](#at-rule). (This
 categorization does not occur at the Syntax level; instead, it is a
 product of where the declaration appears, and is defined by the
 respective specifications defining the given rule.)

[component value]
: A component value is one of the [preserved
 tokens](#preserved-tokens), a [function](#function), or a [simple
 block](#simple-block).

[preserved tokens]

: Any token produced by the tokenizer except for
 [\<function-token\>](#typedef-function-token)s,
 [\<{-token\>](#tokendef-open-curly)s,
 [\<(-token\>](#tokendef-open-paren)s,
 and
 [\<\[-token\>](#tokendef-open-square)s.

 The non-[preserved
 tokens](#preserved-tokens) listed above are always consumed into higher-level
 objects, either functions or simple blocks, and so never appear in
 any parser output themselves.

 The tokens
 [\<}-token\>](#tokendef-close-curly)s,
 [\<)-token\>](#tokendef-close-paren)s,
 [\<\]-token\>](#tokendef-close-square),
 [\<bad-string-token\>](#typedef-bad-string-token), and
 [\<bad-url-token\>](#typedef-bad-url-token) are always parse errors, but they
 are preserved in the token stream by this specification to allow
 other specs, such as Media Queries, to define more fine-grained
 error-handling than just dropping an entire declaration or block.

[function]
: A function has a name and a value consisting of a list of [component
 values](#component-value).

[simple block]\
[-block]\
[\[\]-block]\
[()-block]

: A simple block has an associated token (either a
 [\<\[-token\>](#tokendef-open-square),
 [\<(-token\>](#tokendef-open-paren),
 or
 [\<{-token\>](#tokendef-open-curly))
 and a value consisting of a list of component values.

 [-block](#curly-block),
 [\[\]-block](#square-block),
 and [()-block](#paren-block)
 refer specifically to a [simple
 block](#simple-block) with
 that corresponding associated token.

Tests

- [parse-invalid-input.html](https://wpt.fyi/results/css/css-syntax/parse-invalid-input.html "css/css-syntax/parse-invalid-input.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/parse-invalid-input.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/parse-invalid-input.html)

### 5.3. Token Streams

A [token stream] is a
[struct](https://infra.spec.whatwg.org/#struct) representing a stream of
[tokens](#token-stream-tokens) and/or [component
values](#component-value). It
has the following
[items](https://infra.spec.whatwg.org/#struct-item):

[tokens]

: A [list](https://infra.spec.whatwg.org/#list) of
 [tokens](#token-stream-tokens) and/or [component
 values](#component-value).

 This specification assumes, for simplicity, that
 the input stream has been fully tokenized before parsing begins.
 However, the parsing algorithms only use one token of \"lookahead\",
 so in practice tokenization and parsing can be done in lockstep.

[index]

: An index into the
 [tokens](#token-stream-tokens), representing the progress of parsing. It starts at
 0 initially.

 Aside from
 [marking](#token-stream-mark), the
 [index](#token-stream-index) never goes backwards. Thus the already-processed
 prefix of
 [tokens](#token-stream-tokens) can be eagerly discarded as it's processed.

[marked indexes]

: A [stack](https://infra.spec.whatwg.org/#stack) of index values, representing points that the
 parser might return to. It starts empty initially.

CSS has a small number of places that require referencing the precise
text that was parsed for a declaration's value (not just what tokens
were produced from that text). This is not explicitly described in the
algorithmic structure here, but the [token
stream](#css-token-stream)
must, thus, have the ability to reproduce the original text of
declarations on demand. See [consume a
declaration](#consume-a-declaration) for details on when this is required.

Several operations can be performed on a [token
stream](#css-token-stream):

[next token]

: The item of
 [tokens](#token-stream-tokens) at
 [index](#token-stream-index).

 If that index would be out-of-bounds past the end of the list, it's
 instead an
 [\<eof-token\>](#typedef-eof-token).

[empty]

: A token stream is
 [empty](#token-stream-empty) if the [next
 token](#token-stream-next-token) is an
 [\<eof-token\>](#typedef-eof-token).

[consume a token]

: Let `token` be the [next
 token](#token-stream-next-token). Increment
 [index](#token-stream-index), then return `token`.

[discard a token]

: If the [token stream](#css-token-stream) is not
 [empty](#token-stream-empty), increment
 [index](#token-stream-index).

[mark]

: Append [index](#token-stream-index) to [marked
 indexes](#token-stream-marked-indexes).

[restore a mark]

: [Pop](https://infra.spec.whatwg.org/#stack-pop) from [marked
 indexes](#token-stream-marked-indexes), and set
 [index](#token-stream-index) to the popped value.

[discard a mark]

: [Pop](https://infra.spec.whatwg.org/#stack-pop) from [marked
 indexes](#token-stream-marked-indexes), and do nothing with the popped value.

[discard whitespace]

: While the [next
 token](#token-stream-next-token) is a
 [\<whitespace-token\>](#typedef-whitespace-token), [discard a
 token](#token-stream-discard-a-token).

[process]

: To [process](#token-stream-process), given a following list of token types and
 associated actions, perform the action associated with the [next
 token](#token-stream-next-token). Repeat until one of the actions returns something,
 then return that.

An [[\<eof-token\>](#typedef-eof-token)] is a conceptual token, not actually produced
by the tokenizer, used to indicate that the [token
stream](#css-token-stream)
has been exhausted.

### 5.4. Parser Entry Points

The algorithms defined in this section produce high-level CSS objects
from lists of CSS tokens.

The algorithms here operate on a token stream as input, but for
convenience can also be invoked with a number of other value types.

To [normalize into a token stream] a given
`input`:

1. If `input` is already a [token
 stream](#css-token-stream), return it.

2. If `input` is a list of CSS
 [tokens](#token-stream-tokens) and/or [component
 values](#component-value), create a new [token
 stream](#css-token-stream) with `input` as its
 [tokens], and return it.

3. If `input` is a
 [string](https://infra.spec.whatwg.org/#string), then [filter code
 points](#css-filter-code-points) from `input`,
 [tokenize](#css-tokenize) the
 result, and return the stream of tokens.

4. Assert: Only the preceding types should be passed as
 `input`.

 Other specs can define additional entry points for
their own purposes.

The following notes should probably be translated into normative text in
the relevant specs, hooking this spec's terms:

- \"[Parse a
 stylesheet](#parse-a-stylesheet)\" is intended to be the normal parser entry point,
 for parsing stylesheets.
- \"[Parse a stylesheet's
 contents](#parse-a-stylesheets-contents)\" is intended for use by the
 [`CSSStyleSheet replace()`](https://drafts.csswg.org/cssom-1/#dom-cssstylesheet-replace) method, and similar, which parse text into the
 contents of an existing stylesheet.
- \"[Parse a rule](#parse-a-rule)\" is intended for use by the
 [`CSSStyleSheet insertRule()`](https://drafts.csswg.org/cssom-1/#dom-cssstylesheet-insertrule) method, and similar, which parse text into a single
 rule. `CSSStyleSheet#insertRule` method, and similar functions which
 might exist, which parse text into a single rule.
- \"[Parse a
 declaration](#parse-a-declaration)\" is used in
 [\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports) conditions.
 [\[CSS3-CONDITIONAL\]](#biblio-css3-conditional "CSS Conditional Rules Module Level 3")
- \"[Parse a list of
 declarations](#parse-a-list-of-declarations)\" is intended for parsing anything that expects just
 a sequence of declaration, such as the HTML
 [`style`](https://html.spec.whatwg.org/multipage/dom.html#attr-style) attribute, and APIs such as
 [`the CSSStyleDeclaration cssText attribute`](https://drafts.csswg.org/cssom-1/#dom-cssstyledeclaration-csstext).
- \"[Parse a style attribute]\" is similar to [parse a
 block's
 contents](https://www.w3.org/TR/css-syntax-3/#parse-a-blocks-contents), but is intended for the HTML `style` attribute or
 similar contexts, where there's no wrapping block (so a `}` character
 doesn't close anything) and nested [qualified
 rules](#qualified-rule)
 aren't supported.
- \"[Parse a component
 value](#parse-a-component-value)\" is for things that need to consume a single value,
 like the parsing rules for
 [attr()](https://drafts.csswg.org/css-values-5/#funcdef-attr).
- \"[Parse a list of component
 values](#parse-a-list-of-component-values)\" is for the contents of presentational attributes,
 which parse text into a single declaration's value, or for parsing a
 stand-alone selector
 [\[SELECT\]](#biblio-select "Selectors Level 3")
 or list of Media Queries
 [\[MEDIAQ\]](#biblio-mediaq "Media Queries Level 4"),
 as in [Selectors API](https://www.w3.org/TR/selectors-api/) or the
 `media` HTML attribute.

#### 5.4.1. Parse something according to a CSS grammar

It is often desirable to parse a string or token list to see if it
matches some CSS grammar, and if it does, to destructure it according to
the grammar. This section provides a generic hook for this kind of
operation. It should be invoked like [\"parse `foo` as a CSS
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)\"], or similar.

This algorithm returns either failure, if the input does not match the
provided grammar, or the result of parsing the input according to the
grammar, which is an unspecified structure corresponding to the provided
grammar specification. The return value must only be interacted with by
specification prose, where the representation ambiguity is not
problematic. If it is meant to be exposed outside of spec language, the
spec using the result must explicitly translate it into a well-specified
representation, such as, for example, by invoking a CSS serialization
algorithm [(like \"serialize as a CSS
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value) value\").]

 This algorithm, and [parse a comma-separated list
according to a CSS
grammar](#css-parse-a-comma-separated-list-according-to-a-css-grammar), are *usually* the only parsing algorithms other specs
will want to call. The remaining parsing algorithms are meant mostly for
[\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")
and related \"explicitly constructing CSS structures\" cases. Consult
the CSSWG for guidance first if you think you need to use one of the
other algorithms.

To [parse something according to a CSS
grammar] (aka simply
[parse](#css-parse-something-according-to-a-css-grammar)) given an `input` and a CSS
`grammar` production:

1. [Normalize](#normalize-into-a-token-stream) `input`, and set `input` to
 the result.
2. [Parse a list of component
 values](#parse-a-list-of-component-values) from `input`, and let
 `result` be the return value.
3. Attempt to match `result` against `grammar`.
 If this is successful, return the matched result; otherwise, return
 failure.

#### 5.4.2. Parse a comma-separated list according to a CSS grammar

While one can definitely
[parse](#css-parse-something-according-to-a-css-grammar) a value according to a grammar with commas in it, if
*any* part of the value fails to parse, the entire thing doesn't parse,
and returns failure.

Sometimes that's what's desired (such as in list-valued CSS properties);
other times, it's better to let each comma-separated sub-part of the
value parse separately, dealing with the parts that parse successfully
one way, and the parts that fail to parse another way (typically
ignoring them, such as in
[`<img sizes>`](https://html.spec.whatwg.org/multipage/embedded-content.html#attr-img-sizes)).

This algorithm provides an easy hook to accomplish exactly that. It
returns a list of values split by \"top-level\" commas, where each
values is either failure (if it failed to parse) or the result of
parsing (an unspecified structure, as described in the
[parse](#css-parse-something-according-to-a-css-grammar) algorithm).

To [parse a comma-separated list according to a CSS
grammar]
(aka [parse a
list](#css-parse-a-comma-separated-list-according-to-a-css-grammar)) given an `input` and a CSS
`grammar` production:

1. [Normalize](#normalize-into-a-token-stream) `input`, and set `input` to
 the result.
2. If `input` contains only
 [\<whitespace-token\>](#typedef-whitespace-token)s, return an empty
 [list](https://infra.spec.whatwg.org/#list).
3. [Parse a comma-separated list of component
 values](#parse-a-comma-separated-list-of-component-values) from `input`, and let `list`
 be the return value.
4. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `item` of `list`, replace
 `item` with the result of
 [parsing](#css-parse-something-according-to-a-css-grammar) `item` with `grammar`.
5. Return `list`.

#### 5.4.3. Parse a stylesheet

To [parse a stylesheet] from an `input` given an optional
[url](https://url.spec.whatwg.org/#concept-url) `location`:

1. If `input` is a byte stream for a stylesheet, [decode
 bytes](#css-decode-bytes)
 from `input`, and set `input` to the result.

2. [Normalize](#normalize-into-a-token-stream) `input`, and set `input` to
 the result.

3. Create a new stylesheet, with its
 [location](https://drafts.csswg.org/cssom-1/#concept-css-style-sheet-location) set to `location` (or null, if
 `location` was not passed).

4. [Consume a stylesheet's
 contents](#consume-a-stylesheets-contents) from `input`, and set the stylesheet's
 rules to the result.

 [Consume a stylesheet's
 contents](#consume-a-stylesheets-contents) always consumes the entire stream.

5. Return the stylesheet.

#### 5.4.4. Parse a stylesheet's contents

To [parse a stylesheet's contents] from `input`:

1. [Normalize](#normalize-into-a-token-stream) `input`, and set `input` to
 the result.

2. [Consume a stylesheet's
 contents](#consume-a-stylesheets-contents) from `input`, and return the result.

 [Consume a stylesheet's
 contents](#consume-a-stylesheets-contents) always consumes the entire stream.

#### 5.4.5. Parse a list of declarations

To [parse a list of declarations] from `input`:

1. [Normalize](#normalize-into-a-token-stream) `input`, and set `input` to
 the result.

2. Let `decls` be an empty
 [list](https://infra.spec.whatwg.org/#list).

3. While `input` is not
 [empty](#token-stream-empty):

 [Discard
 whitespace](#token-stream-discard-whitespace) from `input`.

 - If the [next
 token](#token-stream-next-token) from `input` is a
 [\<semicolon-token\>](#typedef-semicolon-token), [discard a
 token](#token-stream-discard-a-token) from `input`.

 - Otherwise, if the [next
 token](#token-stream-next-token) from `input` is an
 [\<at-keyword-token\>](#typedef-at-keyword-token), [consume an
 at-rule](#consume-an-at-rule) from `input` and discard the result.

 - Otherwise, [consume a
 declaration](#consume-a-declaration). If anything was returned,
 [append](https://infra.spec.whatwg.org/#list-append) it to `decls`.

4. Return `decls`.

 The entire stream is consumed by this algorithm.

#### 5.4.6. Parse a rule

To [parse a rule] from `input`:

1. [Normalize](#normalize-into-a-token-stream) `input`, and set `input` to
 the result.

2. [Discard
 whitespace](#token-stream-discard-whitespace) from `input`.

3. If `input` is
 [empty](#token-stream-empty), return a syntax error.

 Otherwise, if the [next
 token](#token-stream-next-token) from `input` is an
 [\<at-keyword-token\>](#typedef-at-keyword-token), [consume an
 at-rule](#consume-an-at-rule) from `input`, and let `rule`
 be the return value.

 Otherwise, [consume a qualified
 rule](#consume-a-qualified-rule) from `input` and let `rule`
 be the return value. If nothing or an [invalid rule
 error](#invalid-rule-error) was returned, return a syntax error.

4. [Discard
 whitespace](#token-stream-discard-whitespace) from `input`.

5. If `input` is
 [empty](#token-stream-empty), return `rule`. Otherwise, return a
 syntax error.

#### 5.4.7. Parse a declaration

To [parse a declaration] from `input`:

1. [Normalize](#normalize-into-a-token-stream) `input`, and set `input` to
 the result.
2. [Discard
 whitespace](#token-stream-discard-whitespace) from `input`.
3. If `input` is
 [empty](#token-stream-empty), return a syntax error.
4. [Consume a
 declaration](#consume-a-declaration) from `input`. If anything was returned,
 let `value` be the return value. Otherwise, return a
 syntax error.
5. [Discard
 whitespace](#token-stream-discard-whitespace) from `input`.
6. If `input` is
 [empty](#token-stream-empty), return `value`. Otherwise, return a
 syntax error.

#### 5.4.8. Parse a component value

To [parse a component value] from `input`:

1. [Normalize](#normalize-into-a-token-stream) `input`, and set `input` to
 the result.
2. [Discard
 whitespace](#token-stream-discard-whitespace) from `input`.
3. If `input` is
 [empty](#token-stream-empty), return a syntax error.
4. [Consume a component
 value](#consume-a-component-value) from `input` and let `value`
 be the return value.
5. [Discard
 whitespace](#token-stream-discard-whitespace) from `input`.
6. If `input` is
 [empty](#token-stream-empty), return `value`. Otherwise, return a
 syntax error.

#### 5.4.9. Parse a list of component values

To [parse a list of component values] from `input`:

1. [Normalize](#normalize-into-a-token-stream) `input`, and set `input` to
 the result.

2. [Consume a list of component
 values](#consume-a-list-of-component-values) from `input`, and return the result.

 The entire stream is consumed by this algorithm.

#### 5.4.10. Parse a comma-separated list of component values

To [parse a comma-separated list of component
values] from `input`:

1. [Normalize](#normalize-into-a-token-stream) `input`, and set `input` to
 the result.

2. Let `groups` be an empty
 [list](https://infra.spec.whatwg.org/#list).

3. While `input` is not
 [empty](#token-stream-empty):

 1. [Consume a list of component
 values](#consume-a-list-of-component-values) from `input`, with
 [\<comma-token\>](#typedef-comma-token) as the stop token, and append
 the result to `groups`.

 2. [Discard a
 token](#token-stream-discard-a-token) from `input`.

4. Return `groups`.

 The entire stream is consumed by this algorithm.

### 5.5. Parser Algorithms

The following algorithms comprise the parser. They are called by the
parser entry points above, and generally should not be called directly
by other specifications.

Note that CSS parsing is case-sensitive, and checking the validity of
constructs in a given context must be done *during* parsing in at least
some circumstances. This specification intentionally does not specify
*how* sufficient context should be passed around to enable
validity-checking.

#### 5.5.1. Consume a stylesheet's contents

To [consume a stylesheet's contents] from a [token
stream](#css-token-stream)
`input`:

Let `rules` be an initially empty
[list](https://infra.spec.whatwg.org/#list) of rules.

[Process](#token-stream-process) `input`:

[\<whitespace-token\>](#typedef-whitespace-token)
: [Discard a
 token](#token-stream-discard-a-token) from `input`.

[\<EOF-token\>](#typedef-eof-token)
: Return `rules`.

[\<CDO-token\>](#typedef-cdo-token)\
[\<CDC-token\>](#typedef-cdc-token)

: [Discard a
 token](#token-stream-discard-a-token) from `input`.

 What's this for?

 Back when CSS was first being introduced, the
 [`style`](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element) element was treated as an unknown element by
 older browsers. To avoid having its contents displayed in the page
 for these legacy browsers, it became common practice to wrap the
 stylesheet in an HTML comment, and newer browsers would simply
 ignore the HTML comment syntax. This requirement carries over to
 today, decades later.

 The same practice was done for
 [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) elements, where HTML comment syntax is treated
 as a line comment in JS (similar to `//`) for the same reason.

[\<at-keyword-token\>](#typedef-at-keyword-token)
: [Consume an
 at-rule](#consume-an-at-rule) from `input`. If anything is returned,
 append it to `rules`.

anything else
: [Consume a qualified
 rule](#consume-a-qualified-rule) from `input`. If a
 [rule](#css-rule) is returned,
 append it to `rules`.

#### 5.5.2. Consume an at-rule

To [consume an at-rule] from a [token
stream](#css-token-stream)
`input`, given an optional bool `nested` (default
false):

Assert: The [next
token](#token-stream-next-token) is an
[\<at-keyword-token\>](#typedef-at-keyword-token).

[Consume a
token](#token-stream-consume-a-token) from `input`, and let `rule` be a
new [at-rule](#at-rule) with its
name set to the returned token's value, its prelude initially set to an
empty [list](https://infra.spec.whatwg.org/#list), and no declarations or child rules.

[Process](#token-stream-process) `input`:

[\<semicolon-token\>](#typedef-semicolon-token)\
[\<EOF-token\>](#typedef-eof-token)
: [Discard a
 token](#token-stream-discard-a-token) from `input`. If `rule` is
 valid in the current context, return it; otherwise return nothing.

[\<}-token\>](#tokendef-close-curly)

: If `nested` is true:

 - If `rule` is valid in the current context, return it.

 - Otherwise, return nothing.

 Otherwise, [consume a
 token](#token-stream-consume-a-token) and append the result to `rule`'s
 prelude.

[\<{-token\>](#tokendef-open-curly)

: [Consume a block](#consume-a-block) from `input`, and assign the result to
 `rule`'s child [rules](#css-rule).

 If the result contains
 [lists](https://infra.spec.whatwg.org/#list) of
 [declarations](#declaration),
 how they're materialized in the CSSOM depends on the rule. Some turn
 them all into [nested declarations
 rules](https://drafts.csswg.org/css-nesting-1/#nested-declarations-rule), others will treat them all as declarations, and
 others will treat the first item differently from the rest.

 If `rule` is valid in the current context, return it.
 Otherwise, return nothing.

anything else
: [Consume a component
 value](#consume-a-component-value) from `input` and append the returned
 value to `rule`'s prelude.

#### 5.5.3. Consume a qualified rule

To [consume a qualified rule], from a [token
stream](#css-token-stream)
`input`, given an optional
[token](#token-stream-tokens) `stop token` and an optional bool
`nested` (default false):

Let `rule` be a new [qualified
rule](#qualified-rule) with
its prelude, declarations, and child rules all initially set to empty
[lists](https://infra.spec.whatwg.org/#list).

[Process](#token-stream-process) `input`:

[\<EOF-token\>](#typedef-eof-token)\
`stop token` (if passed)
: This is a [parse error](#parse-error). Return nothing.

[\<}-token\>](#tokendef-close-curly)
: This is a [parse error](#parse-error). If `nested` is true, return nothing.
 Otherwise, [consume a
 token](#token-stream-consume-a-token) and append the result to `rule`'s
 prelude.

[\<{-token\>](#tokendef-open-curly)

: If the first two
 non-[\<whitespace-token\>](#typedef-whitespace-token) values of `rule`'s
 prelude are an
 [\<ident-token\>](#typedef-ident-token) whose value starts with \"\--\"
 followed by a
 [\<colon-token\>](#typedef-colon-token), then:

 - If `nested` is true, [consume the remnants of a bad
 declaration](#consume-the-remnants-of-a-bad-declaration) from `input`, with `nested`
 set to true, and return nothing.

 - If `nested` is false, [consume a
 block](#consume-a-block) from `input`, and return nothing.

 What's this check for?

 [Declarations](#declaration)
 and [qualified rules](#qualified-rule) don't *generally* overlap in their allowed syntax.
 No currently-defined CSS property allows -blocks in its value, so
 `foo:bar ;` is definitely a rule, and `foo: bar;` is definitely a
 property. Even if a future CSS property allows -blocks in its
 value, the allowed syntax is restricted to the -block being the
 whole value, such as `foo: ;`, which is guaranteed to not be a
 valid rule, since the [:] doesn't have an ident or function
 following it to mark it as a pseudo-class.

 This allows us to mix declarations and rules in the same context: we
 first try to parse something as a declaration, and if that doesn't
 result in a valid declaration, we reparse it as a rule instead. An
 accidentally-invalid declaration will parse as a rule instead, but
 that's fine: the parser will stop at the declaration's ending
 semicolon and consider it an invalid rule. (Or in the case of a
 property containing a -block, will stop just \*before\* the
 semicolon, still considering it an invalid rule, and then the next
 attempt to parse something will throw out the lone semicolon as
 invalid.) So the total amount of tokens consumed is the same
 regardless.

 [Custom
 properties](https://drafts.csswg.org/css-variables-2/#custom-property), however, don't have the CSSWG carefully vetting
 their syntax. Authors *can* write a custom property that takes a
 -block in its value, even combined with other things; if that
 custom property is then invalid (due to an invalidly-written
 [var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) function, for example), when it's reparsed
 as a rule it will stop early, at the -block. The remaining tokens
 of the custom property's value will then get parsed as a fresh
 construct, potentially causing unexpected declarations or rules to
 be created.

 To avoid this (admittedly very niche) corner-case, we subtract the
 syntax of a [custom
 property](https://drafts.csswg.org/css-variables-2/#custom-property) from that of a [qualified
 rule](#qualified-rule); if
 you're in a context that allows properties and rules to be mixed,
 and you somehow end up parsing a rule that looks like a [custom
 property], you've messed up, and need to
 instead consume an entire custom property (all the way to the ending
 semicolon).

 (If we're in a context that doesn't allow properties, we just throw
 away the rule if it looks like a custom property. This ensures that
 `--foo:hover { color: blue; }` is consistently invalid everywhere,
 without potentially consuming a ton of a stylesheet looking for the
 non-existent ending semicolon.)

 Otherwise, [consume a
 block](#consume-a-block)
 from `input`, and let `child rules` be the
 result. If the first item of `child rules` is a
 [list](https://infra.spec.whatwg.org/#list) of
 [declarations](#declaration),
 remove it from `child rules` and assign it to
 `rule`'s declarations. If any remaining items of
 `child rules` are [lists] of
 [declarations], replace them with [nested
 declarations
 rules](https://drafts.csswg.org/css-nesting-1/#nested-declarations-rule) containing the [list] as its sole
 child. Assign `child rules` to `rule`'s child
 [rules](#css-rule).

 If `rule` is valid in the current context, return it;
 otherwise return an [invalid rule error].

 Tests

 - [invalid-nested-rules.html](https://wpt.fyi/results/css/css-syntax/invalid-nested-rules.html "css/css-syntax/invalid-nested-rules.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/invalid-nested-rules.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/invalid-nested-rules.html)

anything else
: [Consume a component
 value](#consume-a-component-value) from `input` and append the result to
 `rule`'s prelude.

Tests

- [custom-property-rule-ambiguity.html](https://wpt.fyi/results/css/css-syntax/custom-property-rule-ambiguity.html "css/css-syntax/custom-property-rule-ambiguity.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/custom-property-rule-ambiguity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/custom-property-rule-ambiguity.html)
- [invalid-nested-rules.html](https://wpt.fyi/results/css/css-syntax/invalid-nested-rules.html "css/css-syntax/invalid-nested-rules.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/invalid-nested-rules.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/invalid-nested-rules.html)

#### 5.5.4. Consume a block

To [consume a block], from a [token
stream](#css-token-stream)
`input`:

Assert: The [next
token](#token-stream-next-token) is a
[\<{-token\>](#tokendef-open-curly).

[Discard a
token](#token-stream-discard-a-token) from `input`. [Consume a block's
contents](#consume-a-blocks-contents) from `input` and let `rules` be
the result. [Discard a token]
from `input`.

Return `rules`.

#### 5.5.5. Consume a block's contents

To [consume a block's contents] from a [token
stream](#css-token-stream)
`input`:

 This algorithm returns a
[list](https://infra.spec.whatwg.org/#list), consisting of [rules](#css-rule) and [lists] of
[declarations](#declaration).
Depending on the parent context, a [list] of
[declarations] might be materialized in the CSSOM
as either a
[`CSSStyleDeclaration`](https://drafts.csswg.org/cssom-1/#cssstyledeclaration), or as a
[`CSSNestedDeclarations`](https://drafts.csswg.org/css-nesting-1/#cssnesteddeclarations) rule.

Let `rules` be an empty
[list](https://infra.spec.whatwg.org/#list), containing either
[rules](#css-rule) or
[lists] of
[declarations](#declaration).

Let `decls` be an empty
[list](https://infra.spec.whatwg.org/#list) of [declarations](#declaration).

[Process](#token-stream-process) `input`:

[\<whitespace-token\>](#typedef-whitespace-token)\
[\<semicolon-token\>](#typedef-semicolon-token)
: [Discard a
 token](#token-stream-discard-a-token) from `input`.

[\<EOF-token\>](#typedef-eof-token)\
[\<}-token\>](#tokendef-close-curly)
: Return `rules`.

[\<at-keyword-token\>](#typedef-at-keyword-token)

: If `decls` is not empty, append it to `rules`,
 and set `decls` to a fresh empty
 [list](https://infra.spec.whatwg.org/#list) of
 [declarations](#declaration).

 [Consume an
 at-rule](#consume-an-at-rule) from `input`, with `nested`
 set to true. If a [rule](#css-rule) was returned, append it to `rules`.

anything else

: [Mark](#token-stream-mark) `input`.

 [Consume a
 declaration](#consume-a-declaration) from `input`, with `nested`
 set to true. If a [declaration](#declaration) was returned, append it to `decls`, and
 [discard a
 mark](#token-stream-discard-a-mark) from `input`.

 Otherwise, [restore a
 mark](#token-stream-restore-a-mark) from `input`, then [consume a qualified
 rule](#consume-a-qualified-rule) from `input`, with `nested`
 set to true, and
 [\<semicolon-token\>](#typedef-semicolon-token) as the `stop token`.

 If nothing was returned

 : Do nothing

 If an [invalid rule error](#invalid-rule-error) was returned

 : If `decls` is not empty, append `decls` to
 `rules`, and set `decls` to a fresh empty
 [list](https://infra.spec.whatwg.org/#list) of
 [declarations](#declaration). (Otherwise, do nothing.)

 If a [rule](#css-rule) was returned

 : If `decls` is not empty, append `decls` to
 `rules`, and set `decls` to a fresh empty
 [list](https://infra.spec.whatwg.org/#list) of
 [declarations](#declaration). Append the
 [rule](#css-rule) to
 `rules`.

Implementation note

This spec, as with many CSS specs, has been written to prioritize
understandability over efficiency. A number of algorithms, notably the
above \"parse as a declaration, then parse as a rule\" behavior can be
fairly inefficient if implemented naively as described.

However, the behavior has been carefully written to allow \"early
exits\" as much as possible. In particular, and roughly in order of when
the exit can occur:

- If the first non-whitespace token isn't an
 [\<ident-token\>](#typedef-ident-token) for a recognized property name (or
 a custom property name), you can immediately stop parsing as a
 declaration and reparse as a rule instead. If the *next*
 non-whitespace token isn't a
 [\<colon-token\>](#typedef-colon-token), you can similarly immediately stop
 parsing as a declaration.

 (That is, [font+ \...] is guaranteed to not be a property, nor
 is [not-a-prop-name: \...].)

- If the first two non-whitespace tokens are a custom property name and
 a colon, it's definitely a custom property and won't ever produce a
 valid rule, so even if the custom property ends up invalid there's no
 need to try and reparse as a rule.

 (That is, [\--foo:hover {\...}] is guaranteed to be a custom
 property, not a rule.)

- If the first three non-whitespace tokens are a valid property name, a
 colon, and anything other than a
 [\<{-token\>](#tokendef-open-curly), and then while parsing the
 declaration's value you encounter a
 [\<{-token\>], you can
 immediately stop parsing as a declaration and reparse as a rule
 instead.

 (That is, [font:bar {\...] is guaranteed to be an invalid
 property.)

- If you see a recognized property name, a colon, and a -block, but
 the first non-whitespace tokens following that block isn't either
 immediately the final semicolon, or the !important followed by the
 semicolon, you can immediately stop parsing as a declaration and
 reparse as a rule instead.

 (That is, [font: bar
 \...](https://drafts.csswg.org/css-fonts-4/#propdef-font) is guaranteed to be an invalid property;
 you don't need to keep parsing until you hit a semicolon.)

Similarly, even tho the parsing requirements are specified to rely on
checking the grammar of the declarations as you parse, a *generic*
processor trying to implement a non-CSS language on top of the generic
CSS *syntax* can still get away with just verifying that declarations
start with an ident, a colon, and then either contain solely a -block
or no -block at all. They'll just spent a little more time on parsing
than an implementation with grammar knowledge in cases like [foo:hover
\... ], since they can't early-exit on the first token.

Tests

- [at-rule-in-declaration-list.html](https://wpt.fyi/results/css/css-syntax/at-rule-in-declaration-list.html "css/css-syntax/at-rule-in-declaration-list.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/at-rule-in-declaration-list.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/at-rule-in-declaration-list.html)

#### 5.5.6. Consume a declaration

To [consume a declaration] from a [token
stream](#css-token-stream)
`input`, given an optional bool `nested` (default
false):

Let `decl` be a new
[declaration](#declaration),
with an initially empty name and a value set to an empty
[list](https://infra.spec.whatwg.org/#list).

1. If the [next
 token](#token-stream-next-token) is an
 [\<ident-token\>](#typedef-ident-token), [consume a
 token](#token-stream-consume-a-token) from `input` and set
 `decl`\'s name to the token's value.

 Otherwise, [consume the remnants of a bad
 declaration](#consume-the-remnants-of-a-bad-declaration) from `input`, with `nested`,
 and return nothing.

2. [Discard
 whitespace](#token-stream-discard-whitespace) from `input`.

3. If the [next
 token](#token-stream-next-token) is a
 [\<colon-token\>](#typedef-colon-token), [discard a
 token](#token-stream-discard-a-token) from `input`.

 Otherwise, [consume the remnants of a bad
 declaration](#consume-the-remnants-of-a-bad-declaration) from `input`, with `nested`,
 and return nothing.

4. [Discard
 whitespace](#token-stream-discard-whitespace) from `input`.

5. [Consume a list of component
 values](#consume-a-list-of-component-values) from `input`, with `nested`,
 and with
 [\<semicolon-token\>](#typedef-semicolon-token) as the stop token, and set
 `decl`'s value to the result.

6. If the last two
 non-[\<whitespace-token\>](#typedef-whitespace-token)s in `decl`'s value are
 a
 [\<delim-token\>](#typedef-delim-token) with the value \"!\" followed by
 an
 [\<ident-token\>](#typedef-ident-token) with a value that is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"important\", remove them from
 `decl`'s value and set `decl`'s
 `important` flag.

7. While the last item in `decl`'s value is a
 [\<whitespace-token\>](#typedef-whitespace-token),
 [remove](https://infra.spec.whatwg.org/#list-remove) that token.

8. If `decl`'s name is a [custom property name
 string](https://drafts.css-houdini.org/css-typed-om-1/#custom-property-name-string), then set `decl`'s
 `original text` to the segment of the original source
 text string corresponding to the tokens of `decl`'s
 value.

 Otherwise, if `decl`'s value contains a top-level [simple
 block](#simple-block) with
 an associated token of
 [\<{-token\>](#tokendef-open-curly), and also contains *any other*
 non-[\<whitespace-token\>](#typedef-whitespace-token) value, return nothing. (That is,
 a top-level -block is only allowed as the entire value of a
 non-custom property.)

 Otherwise, if `decl`'s name is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"unicode-range\", [consume the value of
 a unicode-range
 descriptor](#consume-the-value-of-a-unicode-range-descriptor) from the segment of the original source text string
 corresponding to the tokens returned by the [consume a list of
 component
 values](#consume-a-list-of-component-values) call, and replace `decl`'s value with
 the result.

 Tests

 - [var-with-blocks.html](https://wpt.fyi/results/css/css-syntax/var-with-blocks.html "css/css-syntax/var-with-blocks.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/var-with-blocks.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/var-with-blocks.html)

9. If `decl` is valid in the current context, return it;
 otherwise return nothing.

To [consume the remnants of a bad
declaration] from a [token
stream](#css-token-stream)
`input`, given a bool `nested`:

[Process](#token-stream-process) `input`:

[\<eof-token\>](#typedef-eof-token)\
[\<semicolon-token\>](#typedef-semicolon-token)

: [Discard a
 token](#token-stream-discard-a-token) from `input`, and return nothing.

[\<}-token\>](#tokendef-close-curly)

: If `nested` is true, return nothing. Otherwise, [discard
 a
 token](#token-stream-discard-a-token).

anything else

: [Consume a component
 value](#consume-a-component-value) from `input`, and do nothing.

#### 5.5.7. Consume a list of component values

To [consume a list of component
values] from a [token
stream](#css-token-stream)
`input`, given an optional
[token](#token-stream-tokens) `stop token` and an optional boolean
`nested` (default false):

Let `values` be an empty
[list](https://infra.spec.whatwg.org/#list) of [component
values](#component-value).

[Process](#token-stream-process) `input`:

[\<eof-token\>](#typedef-eof-token)\
`stop token` (if passed)

: Return `values`.

[\<}-token\>](#tokendef-close-curly)

: If `nested` is true, return `values`.

 Otherwise, this is a [parse
 error](#parse-error).
 [Consume a
 token](#token-stream-consume-a-token) from `input` and append the result to
 `values`.

anything else

: [Consume a component
 value](#consume-a-component-value) from `input`, and append the result to
 `values`.

Tests

- [declarations-trim-whitespace.html](https://wpt.fyi/results/css/css-syntax/declarations-trim-whitespace.html "css/css-syntax/declarations-trim-whitespace.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/declarations-trim-whitespace.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/declarations-trim-whitespace.html)

#### 5.5.8. Consume a component value

To [consume a component value] from a [token
stream](#css-token-stream)
`input`:

[Process](#token-stream-process) `input`:

[\<{-token\>](#tokendef-open-curly)\
[\<\[-token\>](#tokendef-open-square)\
[\<(-token\>](#tokendef-open-paren)

: [Consume a simple
 block](#consume-a-simple-block) from `input` and return the result.

[\<function-token\>](#typedef-function-token)

: [Consume a
 function](#consume-a-function) from `input` and return the result.

anything else

: [Consume a
 token](#token-stream-consume-a-token) from `input` and return the result.

#### 5.5.9. Consume a simple block

To [consume a simple block] from a [token
stream](#css-token-stream)
`input`:

Assert: the [next
token](#token-stream-next-token) of `input` is
[\<{-token\>](#tokendef-open-curly),
[\<\[-token\>](#tokendef-open-square),
or [\<(-token\>](#tokendef-open-paren).

Let `ending token` be the mirror variant of the [next
token](#token-stream-next-token). (E.g. if it was called with
[\<\[-token\>](#tokendef-open-square),
the `ending token` is
[\<\]-token\>](#tokendef-close-square).)

Let `block` be a new [simple
block](#simple-block) with its
associated token set to the [next
token](#token-stream-next-token) and with its value initially set to an empty
[list](https://infra.spec.whatwg.org/#list).

[Discard a
token](#token-stream-discard-a-token) from `input`.

[Process](#token-stream-process) `input`:

[\<eof-token\>](#typedef-eof-token)\
`ending token`

: [Discard a
 token](#token-stream-discard-a-token) from `input`. Return `block`.

anything else

: [Consume a component
 value](#consume-a-component-value) from `input` and append the result to
 `block`'s value.

#### 5.5.10. Consume a function

To [consume a function] from a [token
stream](#css-token-stream)
`input`:

Assert: The [next
token](#token-stream-next-token) is a
[\<function-token\>](#typedef-function-token).

[Consume a
token](#token-stream-consume-a-token) from `input`, and let `function`
be a new function with its name equal the returned token's value, and a
value set to an empty
[list](https://infra.spec.whatwg.org/#list).

[Process](#token-stream-process) `input`:

[\<eof-token\>](#typedef-eof-token)\
[\<)-token\>](#tokendef-close-paren)

: [Discard a
 token](#token-stream-discard-a-token) from `input`. Return
 `function`.

anything else

: [Consume a component
 value](#consume-a-component-value) from `input` and append the result to
 `function`'s value.

#### [5.5.11. ][ Consume a [unicode-range](https://drafts.csswg.org/css-fonts-4/#descdef-font-face-unicode-range) value]
To [consume the value of a unicode-range
descriptor] from a string
`input string`:

1. Let `tokens` be the result of
 [tokenizing](#css-tokenize)
 `input string` with `unicode ranges allowed`
 set to true.

2. [Consume a list of component
 values](#consume-a-list-of-component-values) from `tokens`, and return the result.

 The existence of this algorithm is due to a design
mistake in early CSS. It should never be reproduced.

## 6. The `An+B` microsyntax

Several things in CSS, such as the
[[:nth-child()](https://drafts.csswg.org/selectors-4/#nth-child-pseudo)] pseudoclass, need to indicate
indexes in a list. The `An+B` microsyntax is useful for this,
allowing an author to easily indicate single elements or all elements at
regularly-spaced intervals in a list.

The [An+B] notation
defines an integer step (`A`) and offset (`B`),
and represents the `An+B`th elements in a list, for every
positive integer or zero value of `n`, with the first element
in the list having index 1 (not 0).

For values of `A` and `B` greater than 0, this
effectively divides the list into groups of `A` elements (the
last group taking the remainder), and selecting the `B`th
element of each group.

The `An+B` notation also accepts the [even] and
[odd] keywords, which have the same meaning as [2n] and
[2n+1], respectively.

Examples:

 2n+0 /* represents all of the even elements in the list */
 even /* same */
 4n+1 /* represents the 1st, 5th, 9th, 13th, etc. elements in the list */

The values of `A` and `B` can be negative, but
only the positive results of `An+B`, for `n` ≥ 0,
are used.

Example:

 -1n+6 /* represents the first 6 elements of the list */
 -4n+10 /* represents the 2nd, 6th, and 10th elements of the list */

If both `A` and `B` are 0, the pseudo-class
represents no element in the list.

### 6.1. Informal Syntax Description

*This section is non-normative.*

When `A` is 0, the `An` part may be omitted
(unless the `B` part is already omitted). When
`An` is not included and `B` is non-negative, the
[+](https://drafts.csswg.org/selectors-4/#selectordef-adjacent) sign before `B` (when allowed) may
also be omitted. In this case the syntax simplifies to just
`B`.

Examples:

 0n+5 /* represents the 5th element in the list */
 5 /* same */

When `A` is 1 or -1, the `1` may be omitted from the rule.

Examples:

The following notations are therefore equivalent:

 1n+0 /* represents all elements in the list */
 n+0 /* same */
 n /* same */

If `B` is 0, then every `A`th element is picked.
In such a case, the `+B` (or `-B`) part may be
omitted unless the `A` part is already omitted.

Examples:

 2n+0 /* represents every even element in the list */
 2n /* same */

When B is negative, its minus sign replaces the
[+](https://drafts.csswg.org/selectors-4/#selectordef-adjacent) sign.

Valid example:

 3n-6

Invalid example:

 3n + -6

Whitespace is permitted on either side of the
[+](https://drafts.csswg.org/selectors-4/#selectordef-adjacent) or [-] that separates the `An`
and `B` parts when both are present.

Valid Examples with white space:

 3n + 1
 +3n - 2
 -n+ 6
 +6

Invalid Examples with white space:

 3 n
 + 2n
 + 2

### 6.2. The `<a-n-plus-b>` type

The `An+B` notation was originally defined using a slightly
different tokenizer than the rest of CSS, resulting in a somewhat odd
definition when expressed in terms of CSS tokens. This section describes
how to recognize the `An+B` notation in terms of CSS tokens
(thus defining the `<a-n-plus-b>` type for CSS grammar
purposes), and how to interpret the CSS tokens to obtain values for
`A` and `B`.

Tests

- [anb-parsing.html](https://wpt.fyi/results/css/css-syntax/anb-parsing.html "css/css-syntax/anb-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/anb-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/anb-parsing.html)
- [anb-serialization.html](https://wpt.fyi/results/css/css-syntax/anb-serialization.html "css/css-syntax/anb-serialization.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/anb-serialization.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/anb-serialization.html)

The `<a-n-plus-b>` type is defined (using the [Value
Definition Syntax in the Values & Units
spec](https://www.w3.org/TR/css3-values/#value-defs)) as:

``` prod
<a-n-plus-b> =
 odd | even |
 <integer> |

 <n-dimension> |
 '+'?† n |
 -n |

 <ndashdigit-dimension> |
 '+'?† <ndashdigit-ident> |
 <dashndashdigit-ident> |

 <n-dimension> <signed-integer> |
 '+'?† n <signed-integer> |
 -n <signed-integer> |

 <ndash-dimension> <signless-integer> |
 '+'?† n- <signless-integer> |
 -n- <signless-integer> |

 <n-dimension> ['+' | '-'] <signless-integer> |
 '+'?† n ['+' | '-'] <signless-integer> |
 -n ['+' | '-'] <signless-integer>
```

where:

- [`<n-dimension>`] is a
 [\<dimension-token\>](#typedef-dimension-token) with its type flag set to
 \"integer\", and a unit that is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"n\"
- [`<ndash-dimension>`] is a
 [\<dimension-token\>](#typedef-dimension-token) with its type flag set to
 \"integer\", and a unit that is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"n-\"
- [`<ndashdigit-dimension>`] is a
 [\<dimension-token\>](#typedef-dimension-token) with its type flag set to
 \"integer\", and a unit that is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"n-\*\", where \"\*\" is a series of one
 or more [digits](#digit)
- [`<ndashdigit-ident>`] is an
 [\<ident-token\>](#typedef-ident-token) whose value is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"n-\*\", where \"\*\" is a series of one
 or more [digits](#digit)
- [`<dashndashdigit-ident>`] is an
 [\<ident-token\>](#typedef-ident-token) whose value is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"-n-\*\", where \"\*\" is a series of one
 or more [digits](#digit)
- [`<integer>`] is a
 [\<number-token\>](#typedef-number-token) with its type flag set to
 \"integer\"
- [`<signed-integer>`] is a
 [\<number-token\>](#typedef-number-token) with its type flag set to
 \"integer\", and a sign character
- [`<signless-integer>`] is a
 [\<number-token\>](#typedef-number-token) with its type flag set to
 \"integer\", and no sign character

^†^: When a plus sign (+) precedes an ident starting with \"n\", as in
the cases marked above, there must be no whitespace between the two
tokens, or else the tokens do not match the above grammar. Whitespace is
valid (and ignored) between any other two tokens.

The clauses of the production are interpreted as follows:

[odd]
: `A` is 2, `B` is 1.

[even]
: `A` is 2, `B` is 0.

`<integer>`
: `A` is 0, `B` is the integer's value.

`<n-dimension>`\
`'+'? n`\
`-n`
: `A` is the dimension's value, 1, or -1, respectively.
 `B` is 0.

`<ndashdigit-dimension>`\
`'+'? ``<ndashdigit-ident>`
: `A` is the dimension's value or 1, respectively.
 `B` is the dimension's unit or ident's value,
 respectively, with the first [code
 point](https://infra.spec.whatwg.org/#code-point) removed and the remainder interpreted as a base-10
 number. [B is negative.]

`<dashndashdigit-ident>`
: `A` is -1. `B` is the ident's value, with the
 first two [code
 points](https://infra.spec.whatwg.org/#code-point) removed and the remainder interpreted as a base-10
 number. [B is negative.]

`<n-dimension>`` ``<signed-integer>`\
`'+'? n ``<signed-integer>`\
`-n ``<signed-integer>`
: `A` is the dimension's value, 1, or -1, respectively.
 `B` is the integer's value.

`<ndash-dimension>`` ``<signless-integer>`\
`'+'? n- ``<signless-integer>`\
`-n- ``<signless-integer>`
: `A` is the dimension's value, 1, or -1, respectively.
 `B` is the negation of the integer's value.

`<n-dimension>`` ['+' | '-'] ``<signless-integer>`\
`'+'? n ['+' | '-'] ``<signless-integer>`\
`-n ['+' | '-'] ``<signless-integer>`
: `A` is the dimension's value, 1, or -1, respectively.
 `B` is the integer's value. If a `'-'` was provided
 between the two, `B` is instead the negation of the
 integer's value.

## 7. Defining Grammars for Rules and Other Values

[CSS Values 4 § 2 Value Definition
Syntax](https://drafts.csswg.org/css-values-4/#value-defs) defines how
to specify a grammar for properties and other CSS syntactic
constructions.

Tests

- [unclosed-constructs.html](https://wpt.fyi/results/css/css-syntax/unclosed-constructs.html "css/css-syntax/unclosed-constructs.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/unclosed-constructs.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/unclosed-constructs.html)

### 7.1. Defining Block Contents: the [\<block-contents\>, [\<declaration-list\>](#typedef-declaration-list), [\<qualified-rule-list\>](#typedef-qualified-rule-list), [\<declaration-rule-list\>](#typedef-declaration-rule-list), and [\<rule-list\>](#typedef-rule-list) productions]
The CSS parser is agnostic as to the contents of blocks---​they're all
[parsed with the same
algorithm](#consume-a-blocks-contents), and differentiate themselves solely by what constructs
are valid.

When writing a rule grammar,
[\<block-contents\>] represents this agnostic parsing. It must
only be used as the sole value in a block, and represents that no
restrictions are implicitly placed on what the block can contain.

Accompanying prose must define what is valid and invalid in this
context. If any [declarations](#declaration) are valid, and are [property
declarations](#css-property-declarations), it must define whether they interact with the cascade;
if they do, it must define their specificity and how they use
`!important`.

In many cases, however, a block can't validly contain *any* constructs
of a given type. To represent these cases more explicitly, the following
productions may be used

- [\<declaration-list\>]: only
 [declarations](#declaration)
 are allowed; [at-rules](#at-rule)
 and [qualified rules](#qualified-rule) are automatically invalid.

- [\<qualified-rule-list\>]: only [qualified
 rules](#qualified-rule) are
 allowed; [declarations](#declaration) and [at-rules](#at-rule) are automatically invalid.

- [\<at-rule-list\>]: only
 [at-rules](#at-rule) are allowed;
 [declarations](#declaration)
 and [qualified rules](#qualified-rule) are automatically invalid.

- [\<declaration-rule-list\>]:
 [declarations](#declaration)
 and [at-rules](#at-rule) are
 allowed; [qualified rules](#qualified-rule) are automatically invalid.

- [\<rule-list\>]: [qualified
 rules](#qualified-rule) and
 [at-rules](#at-rule) are allowed;
 [declarations](#declaration)
 are automatically invalid.

All of these are exactly equivalent to
[\<block-contents\>](#typedef-block-contents) in terms of parsing, but the
accompanying prose only has to define validity for the categories that
aren't automatically invalid.

Some examples of the various
productions:

- A top-level
 [\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media) uses
 [\<rule-list\>](#typedef-rule-list) for its block, while a nested one
 [\[CSS-NESTING-1\]](#biblio-css-nesting-1 "CSS Nesting Module Level 1")
 uses
 [\<block-contents\>](#typedef-block-contents).

- [Style rules](#style-rule) use
 [\<block-contents\>](#typedef-block-contents).

- [\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) uses
 [\<declaration-list\>](#typedef-declaration-list).

- [\@page](https://drafts.csswg.org/css-page-3/#at-ruledef-page) uses
 [\<declaration-rule-list\>](#typedef-declaration-rule-list).

- [\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) uses
 [\<qualified-rule-list\>](#typedef-qualified-rule-list)

For example, the grammar for
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) can be written as:

 <@font-face> = @font-face { <declaration-list> }

and then accompanying prose defines the valid
[descriptors](#css-descriptor)
allowed in the block.

The grammar for
[\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) can be written as:

 <@keyframes> = @keyframes { <qualified-rule-list> }
 <keyframe-rule> = <keyframe-selector> { <declaration-list> }

and then accompanying prose defines that only [\<keyframe-rule\>]s are allowed in
[\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes), and that [\<keyframe-rule\>]s
accept all animatable CSS properties, plus the
[animation-timing-function](https://drafts.csswg.org/css-animations-1/#propdef-animation-timing-function) property, but they do not interact
with the cascade.

### 7.2. Defining Arbitrary Contents: the [\<declaration-value\> and [\<any-value\>](#typedef-any-value) productions]
In some grammars, it is useful to accept any reasonable input in the
grammar, and do more specific error-handling on the contents manually
(rather than simply invalidating the construct, as grammar mismatches
tend to do).

[For example, [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property) allow any reasonable value, as they can contain
arbitrary pieces of other CSS properties, or be used for things that
aren't part of existing CSS at all. For another example, the
[\<general-enclosed\>](https://drafts.csswg.org/mediaqueries-5/#typedef-general-enclosed) production in Media Queries defines
the bounds of what future syntax MQs will allow, and uses special logic
to deal with \"unknown\" values.]

To aid in this, two additional productions are defined:

The [\<declaration-value\>] production matches *any*
sequence of one or more tokens, so long as the sequence does not contain
[\<bad-string-token\>](#typedef-bad-string-token),
[\<bad-url-token\>](#typedef-bad-url-token), unmatched
[\<)-token\>](#tokendef-close-paren),
[\<\]-token\>](#tokendef-close-square), or
[\<}-token\>](#tokendef-close-curly), or top-level
[\<semicolon-token\>](#typedef-semicolon-token) tokens or
[\<delim-token\>](#typedef-delim-token) tokens with a value of \"!\". It
represents the entirety of what a valid declaration can have as its
value.

The [\<any-value\>] production is identical to
[\<declaration-value\>](#typedef-declaration-value), but also allows top-level
[\<semicolon-token\>](#typedef-semicolon-token) tokens and
[\<delim-token\>](#typedef-delim-token) tokens with a value of \"!\". It
represents the entirety of what valid CSS can be in any context.

## 8. CSS stylesheets

To [parse a CSS stylesheet], first [parse a
stylesheet](#parse-a-stylesheet). Interpret all of the resulting top-level [qualified
rules](#qualified-rule) as
[style rules](#style-rule),
defined below.

If any style rule is [invalid](#css-invalid), or any at-rule is not recognized or is invalid
according to its grammar or context, it's a [parse
error](#parse-error). Discard
that rule.

### 8.1. Style rules

A [style rule]
is a [qualified rule](#qualified-rule) that associates a [selector
list](https://drafts.csswg.org/selectors-4/#selector-list) with a list of property declarations and possibly a
list of nested rules. They are also called [rule
sets](https://www.w3.org/TR/CSS2/syndata.html#rule-sets) in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").
CSS Cascading and Inheritance
[\[CSS-CASCADE-3\]](#biblio-css-cascade-3 "CSS Cascading and Inheritance Level 3")
defines how the declarations inside of style rules participate in the
cascade.

The prelude of the qualified rule is
[parsed](#css-parse-something-according-to-a-css-grammar) as a
[\<selector-list\>](https://drafts.csswg.org/selectors-4/#typedef-selector-list). If this returns failure, the entire
style rule is [invalid](#css-invalid).

The content of the qualified rule's block is parsed as a
[\<declaration-list\>](#typedef-declaration-list). Qualified rules in this block are
also [style rules](#style-rule).
Unless defined otherwise by another specification or a future level of
this specification, at-rules in that list are
[invalid](#css-invalid) and must
be ignored.

[\[CSS-NESTING-1\]](#biblio-css-nesting-1 "CSS Nesting Module Level 1")
defines that [conditional group
rules](https://drafts.csswg.org/css-conditional-3/#conditional-group-rule) and some other [at-rules](#at-rule) are allowed inside of [style
rules](#style-rule).

Declarations for an unknown CSS property or whose value does not match
the syntax defined by the property are
[invalid](#css-invalid) and must
be ignored. The validity of the style rule's contents have no effect on
the validity of the style rule itself. Unless otherwise specified,
property names are [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive).

 The names of Custom Properties
[\[CSS-VARIABLES\]](#biblio-css-variables "CSS Custom Properties for Cascading Variables Module Level 1")
are case-sensitive.

[Qualified rules](#qualified-rule) at the top-level of a CSS stylesheet are [style
rules](#style-rule). Qualified
rules in other contexts may or may not be style rules, as defined by the
context.

For example, qualified rules inside
[\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media) rules
[\[CSS3-CONDITIONAL\]](#biblio-css3-conditional "CSS Conditional Rules Module Level 3")
are style rules, but qualified rules inside
[\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) rules
[\[CSS3-ANIMATIONS\]](#biblio-css3-animations "CSS Animations Level 1")
are not.

### 8.2. At-rules

An [at-rule] is a
rule that begins with an at-keyword, and can thus be distinguished from
[style rules](#style-rule) in the
same context.

[At-rules](#at-rule) are used to:

- group and structure style rules and other at-rules such as in
 [conditional group
 rules](https://drafts.csswg.org/css-conditional-3/#conditional-group-rule)

- declare style information that is not associated with a particular
 element, such as defining [counter
 styles](https://drafts.csswg.org/css-counter-styles-3/#counter-style)

- manage syntactic constructs such as
 [imports](https://drafts.csswg.org/css-cascade-3/#at-import) and
 [namespaces](#biblio-css-namespaces-3 "CSS Namespaces Module Level 3")
 keyword mappings

- and serve other miscellaneous purposes not served by a [style
 rule](#style-rule)

At-rules take many forms, depending on the specific rule and its
purpose, but broadly speaking there are two kinds: [statement
at-rules] which are simpler constructs that end in a
semicolon, and [block at-rules] which end in a
[-block](#curly-block) that can
contain nested [qualified
rules](#qualified-rule),
[at-rules](#at-rule), or
[declarations](#declaration).

[Block at-rules](#block-at-rule) will typically contain a collection of (generic or
[at-rule](#at-rule)--specific)
[at-rules], [qualified
rules](#qualified-rule),
and/or [descriptor
declarations](#css-descriptor-declarations) subject to limitations defined by the
[at-rule]. [Descriptors] are
similar to
[properties](https://drafts.csswg.org/css-cascade-5/#css-property) (and are declared with the same syntax) but are
associated with a particular type of [at-rule]
rather than with elements and boxes in the tree.

### 8.3. The [\@charset Rule]
The algorithm used to [determine the fallback
encoding](#determine-the-fallback-encoding) for a stylesheet looks for a specific byte sequence as
the very first few bytes in the file, which has the syntactic form of an
[at-rule](#at-rule) named
\"@charset\".

Tests

- [page-utf16-css-bomless-utf16.html](https://wpt.fyi/results/css/css-syntax/charset/page-utf16-css-bomless-utf16.html "css/css-syntax/charset/page-utf16-css-bomless-utf16.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-utf16-css-bomless-utf16.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-utf16-css-bomless-utf16.html)
- [page-utf16-css-bomless-utf16be.html](https://wpt.fyi/results/css/css-syntax/charset/page-utf16-css-bomless-utf16be.html "css/css-syntax/charset/page-utf16-css-bomless-utf16be.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-utf16-css-bomless-utf16be.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-utf16-css-bomless-utf16be.html)
- [page-utf16-css-no-decl-ascii-only.html](https://wpt.fyi/results/css/css-syntax/charset/page-utf16-css-no-decl-ascii-only.html "css/css-syntax/charset/page-utf16-css-no-decl-ascii-only.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-utf16-css-no-decl-ascii-only.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-utf16-css-no-decl-ascii-only.html)
- [page-utf16-css-no-decl.html](https://wpt.fyi/results/css/css-syntax/charset/page-utf16-css-no-decl.html "css/css-syntax/charset/page-utf16-css-no-decl.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-utf16-css-no-decl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-utf16-css-no-decl.html)
- [page-windows-1251-charset-attribute-bogus.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1251-charset-attribute-bogus.html "css/css-syntax/charset/page-windows-1251-charset-attribute-bogus.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1251-charset-attribute-bogus.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1251-charset-attribute-bogus.html)
- [page-windows-1251-charset-attribute-empty.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1251-charset-attribute-empty.html "css/css-syntax/charset/page-windows-1251-charset-attribute-empty.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1251-charset-attribute-empty.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1251-charset-attribute-empty.html)
- [page-windows-1251-css-at-charset-1250-charset-attribute-windows-1253.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1251-css-at-charset-1250-charset-attribute-windows-1253.html "css/css-syntax/charset/page-windows-1251-css-at-charset-1250-charset-attribute-windows-1253.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1251-css-at-charset-1250-charset-attribute-windows-1253.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1251-css-at-charset-1250-charset-attribute-windows-1253.html)
- [page-windows-1251-css-at-charset-bogus-charset-attribute-windows-1250.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1251-css-at-charset-bogus-charset-attribute-windows-1250.html "css/css-syntax/charset/page-windows-1251-css-at-charset-bogus-charset-attribute-windows-1250.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1251-css-at-charset-bogus-charset-attribute-windows-1250.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1251-css-at-charset-bogus-charset-attribute-windows-1250.html)
- [page-windows-1251-css-at-charset-bogus.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1251-css-at-charset-bogus.html "css/css-syntax/charset/page-windows-1251-css-at-charset-bogus.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1251-css-at-charset-bogus.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1251-css-at-charset-bogus.html)
- [page-windows-1251-css-at-charset-utf16-ascii-only.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1251-css-at-charset-utf16-ascii-only.html "css/css-syntax/charset/page-windows-1251-css-at-charset-utf16-ascii-only.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1251-css-at-charset-utf16-ascii-only.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1251-css-at-charset-utf16-ascii-only.html)
- [page-windows-1251-css-at-charset-utf16.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1251-css-at-charset-utf16.html "css/css-syntax/charset/page-windows-1251-css-at-charset-utf16.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1251-css-at-charset-utf16.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1251-css-at-charset-utf16.html)
- [page-windows-1251-css-at-charset-utf16be.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1251-css-at-charset-utf16be.html "css/css-syntax/charset/page-windows-1251-css-at-charset-utf16be.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1251-css-at-charset-utf16be.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1251-css-at-charset-utf16be.html)
- [page-windows-1251-css-at-charset-windows-1250-in-utf16.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1251-css-at-charset-windows-1250-in-utf16.html "css/css-syntax/charset/page-windows-1251-css-at-charset-windows-1250-in-utf16.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1251-css-at-charset-windows-1250-in-utf16.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1251-css-at-charset-windows-1250-in-utf16.html)
- [page-windows-1251-css-at-charset-windows-1250-in-utf16be.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1251-css-at-charset-windows-1250-in-utf16be.html "css/css-syntax/charset/page-windows-1251-css-at-charset-windows-1250-in-utf16be.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1251-css-at-charset-windows-1250-in-utf16be.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1251-css-at-charset-windows-1250-in-utf16be.html)
- [page-windows-1251-css-http-bogus-at-charset-windows-1250.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1251-css-http-bogus-at-charset-windows-1250.html "css/css-syntax/charset/page-windows-1251-css-http-bogus-at-charset-windows-1250.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1251-css-http-bogus-at-charset-windows-1250.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1251-css-http-bogus-at-charset-windows-1250.html)
- [page-windows-1251-css-http-bogus.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1251-css-http-bogus.html "css/css-syntax/charset/page-windows-1251-css-http-bogus.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1251-css-http-bogus.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1251-css-http-bogus.html)
- [page-windows-1251-css-http-windows-1250-at-charset-windows-1253.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1251-css-http-windows-1250-at-charset-windows-1253.html "css/css-syntax/charset/page-windows-1251-css-http-windows-1250-at-charset-windows-1253.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1251-css-http-windows-1250-at-charset-windows-1253.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1251-css-http-windows-1250-at-charset-windows-1253.html)
- [page-windows-1251-css-no-decl.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1251-css-no-decl.html "css/css-syntax/charset/page-windows-1251-css-no-decl.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1251-css-no-decl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1251-css-no-decl.html)
- [page-windows-1251-css-utf8-bom.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1251-css-utf8-bom.html "css/css-syntax/charset/page-windows-1251-css-utf8-bom.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1251-css-utf8-bom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1251-css-utf8-bom.html)
- [page-windows-1252-http-windows-1251-css-utf8-bom.html](https://wpt.fyi/results/css/css-syntax/charset/page-windows-1252-http-windows-1251-css-utf8-bom.html "css/css-syntax/charset/page-windows-1252-http-windows-1251-css-utf8-bom.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/page-windows-1252-http-windows-1251-css-utf8-bom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/page-windows-1252-http-windows-1251-css-utf8-bom.html)
- [xml-stylesheet-page-windows-1251-charset-attribute-windows-1250.xhtml](https://wpt.fyi/results/css/css-syntax/charset/xml-stylesheet-page-windows-1251-charset-attribute-windows-1250.xhtml "css/css-syntax/charset/xml-stylesheet-page-windows-1251-charset-attribute-windows-1250.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset/xml-stylesheet-page-windows-1251-charset-attribute-windows-1250.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset/xml-stylesheet-page-windows-1251-charset-attribute-windows-1250.xhtml)

However, there is no actual [at-rule](#at-rule) named [\@charset]. When a stylesheet is
actually parsed, any occurrences of an
[\@charset](#at-ruledef-charset) rule must be treated as an unrecognized rule, and
thus dropped as invalid when the stylesheet is grammar-checked.

 In CSS 2.1,
[\@charset](#at-ruledef-charset) was a valid rule. Some legacy specs may still refer
to a [\@charset] rule, and explicitly
talk about its presence in the stylesheet.

Tests

- [charset-is-not-a-rule.html](https://wpt.fyi/results/css/css-syntax/charset-is-not-a-rule.html "css/css-syntax/charset-is-not-a-rule.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/charset-is-not-a-rule.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/charset-is-not-a-rule.html)

## 9. Serialization

The tokenizer described in this specification does not produce tokens
for comments, or otherwise preserve them in any way. Implementations may
preserve the contents of comments and their location in the token
stream. If they do, this preserved information must have no effect on
the parsing step.

This specification does not define how to serialize CSS in general,
leaving that task to the
[\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")
and individual feature specifications. In particular, the serialization
of comments and whitespace is not defined.

The only requirement for serialization is that it must \"round-trip\"
with parsing, that is, parsing the stylesheet must produce the same data
structures as parsing, serializing, and parsing again, except for
consecutive
[\<whitespace-token\>](#typedef-whitespace-token)s, which may be collapsed into a
single token.

 This exception can exist because CSS grammars always
interpret any amount of whitespace as identical to a single space.

To satisfy this requirement:

- A
 [\<delim-token\>](#typedef-delim-token) containing U+005C REVERSE SOLIDUS
 (\\) must be serialized as U+005C REVERSE SOLIDUS followed by a
 [newline](#newline). (The tokenizer
 only ever emits such a token followed by a
 [\<whitespace-token\>](#typedef-whitespace-token) that starts with a newline.)

- A [\<hash-token\>](#typedef-hash-token) with the \"unrestricted\" type flag
 may not need as much escaping as the same token with the \"id\" type
 flag.

- The unit of a
 [\<dimension-token\>](#typedef-dimension-token) may need escaping to disambiguate
 with scientific notation.

- For any consecutive pair of tokens, if the first token shows up in the
 row headings of the following table, and the second token shows up in
 the column headings, and there's a ✗ in the cell denoted by the
 intersection of the chosen row and column, the pair of tokens must be
 serialized with a comment between them.

 If the tokenizer preserves comments, and there were comments
 originally between the token pair, the preserved comment(s) should be
 used; otherwise, an empty comment (`/**/`) must be inserted.
 (Preserved comments may be reinserted even if the following tables
 don't require a comment between two tokens.)

 Single characters in the row and column headings represent a
 [\<delim-token\>](#typedef-delim-token) with that value, except for
 \"`(`\", which represents a
 [(-token](#tokendef-open-paren).

ident

function

url

bad url

\-

number

percentage

dimension

CDC

(

\*

\%

ident

✗

✗

✗

✗

✗

✗

✗

✗

✗

✗

at-keyword

✗

✗

✗

✗

✗

✗

✗

✗

✗

hash

✗

✗

✗

✗

✗

✗

✗

✗

✗

dimension

✗

✗

✗

✗

✗

✗

✗

✗

✗

\#

✗

✗

✗

✗

✗

✗

✗

✗

✗

\-

✗

✗

✗

✗

✗

✗

✗

✗

✗

number

✗

✗

✗

✗

✗

✗

✗

✗

✗

@

✗

✗

✗

✗

✗

✗

.

✗

✗

✗

\+

✗

✗

✗

/

✗

- [serialize-consecutive-tokens.html](https://wpt.fyi/results/css/css-syntax/serialize-consecutive-tokens.html "css/css-syntax/serialize-consecutive-tokens.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/serialize-consecutive-tokens.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/serialize-consecutive-tokens.html)
- [serialize-escape-identifiers.html](https://wpt.fyi/results/css/css-syntax/serialize-escape-identifiers.html "css/css-syntax/serialize-escape-identifiers.html")
 [[(live
 test)]](http://wpt.live/css/css-syntax/serialize-escape-identifiers.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-syntax/serialize-escape-identifiers.html)

### 9.1. Serializing `<a-n-plus-b>`

To [serialize an
[\<a-n-plus-b\>](#anb-production) value], with integer values
`A` and `B`:

1. If `A` is zero, return the serialization of
 `B`.

2. Otherwise, let `result` initially be an empty
 [string](https://infra.spec.whatwg.org/#string).

3.

 `A` is `1`

 : Append \"n\" to `result`.

 `A` is `-1`

 : Append \"-n\" to `result`.

 `A` is non-zero

 : Serialize `A` and append it to `result`,
 then append \"n\" to `result`.

4.

 `B` is greater than zero

 : Append \"+\" to `result`, then append the
 serialization of `B` to `result`.

 `B` is less than zero

 : Append the serialization of `B` to
 `result`.

5. Return `result`.

## 10. Privacy Considerations

This specification introduces no new privacy concerns.

## 11. Security Considerations

This specification improves security, in that CSS parsing is now
unambiguously defined for all inputs.

Insofar as old parsers, such as whitelists/filters, parse differently
from this specification, they are somewhat insecure, but the previous
parsing specification left a lot of ambiguous corner cases which
browsers interpreted differently, so those filters were potentially
insecure already, and this specification does not worsen the situation.

## 12. Changes

*This section is non-normative.*

### 12.1. Changes from the 24 December 2021 Candidate Recommendation Draft

The following substantive changes were made:

- Rename \<an+b\> to \<a-n-plus-b\>
 ([9473](https://github.com/w3c/csswg-drafts/issues/9473))

- Remove duplicate token stream creations ([PR
 11129](https://github.com/w3c/csswg-drafts/pull/11129))

- Consolidate valdef syntax definition

- Retire \@nest, introduce the \'nested declarations rule\'
 ([10386](https://github.com/w3c/csswg-drafts/pull/10386))

- Change block-contents parsing to maintain relative order of
 interleaved declarations and rules. Add \@nest to Nesting to represent
 them ([8738](https://github.com/w3c/csswg-drafts/issues/8738))

- Blocks are only allowed as the entire value of a property
 ([9317](https://github.com/w3c/csswg-drafts/issues/9317))

- Don't apply the hungry custom-prop-lookalike behavior if you're not in
 a context that allows properties in the first place
 ([9336](https://github.com/w3c/csswg-drafts/issues/9336))

- Clarified that surrogates can only be produced by directly assigning a
 DOMString containing one, via a CSS Object Model operation ([PR
 7997](https://github.com/w3c/csswg-drafts/pull/7997))

- The definition of [non-ASCII code point] was restricted to
 omit some potentially troublesome codepoints.
 ([7129](https://github.com/w3c/csswg-drafts/issues/7129))

- Defined the `<foo()>` and `<@foo>` productions.
 ([5728](https://github.com/w3c/csswg-drafts/issues/5728))

- Allow nested style rules.
 ([7961](https://github.com/w3c/csswg-drafts/issues/7961#issuecomment-1514955984)).

- As part of allowing Nesting, significantly rewrote the entire parsing
 section. Notably, removed \"parse a list of rules\" and \"parse a list
 of declarations\" in favor of \"parse a stylesheet's contents\" and
 \"parse a block's contents\". Only additional normative change is that
 semicolons trigger slightly different error-recovery now in some
 contexts, so that parsing of things like
 [\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media) blocks is identical whether they're nested or
 not. ([8834](https://github.com/w3c/csswg-drafts/issues/8834)).

- Removed the attempt at a `<urange>` production in terms of existing
 tokens, instead relying on a special re-parse from source specifically
 when you're parsing the
 [unicode-range](https://drafts.csswg.org/css-fonts-4/#descdef-font-face-unicode-range) descriptor.
 ([8835](https://github.com/w3c/csswg-drafts/issues/8835))

- Since the above removed the main need to preserve a token's
 \"representation\" (the original string it was parsed from), removed
 the rest of the references to \"representation\" in the An+B section
 and instead just recorded the few bits of information necessary for
 that (whether or not the number had an explicit sign).

- Explicitly noted that some uses ([custom
 properties](https://drafts.csswg.org/css-variables-2/#custom-property), the [unicode-range] descriptor) require access
 to the original string of a declaration's entire value, and marked
 where that occurs in the parser.

- When [consuming a block's
 contents](#consume-a-blocks-contents), rather than grouping all declarations together,
 regardless of where they appear relative to other rules, declarations
 now maintain their relative position wrt surrounding rules. It's up to
 individual rules to determine what they actually do with that
 information.

### 12.2. Changes from the 16 August 2019 Candidate Recommendation

The following substantive changes were made:

- Added a new [§ 5.4.2 Parse a comma-separated list according to a CSS
 grammar](#parse-comma-list) algorithm.

- Added a new \"Parse a style block's content\" algorithm and a
 corresponding [\<style-block\>] production, and defined
 that [style rules](#style-rule)
 use it.

- Aligned [parse a
 stylesheet](#parse-a-stylesheet) with the Fetch-related shenanigans. (See
 [commit](https://github.com/w3c/csswg-drafts/commit/64becb59fe678760608a6f2a8d6bfb3a334500c9#diff-9d409f899ee6e2cc8cd87356d0e2a0ff739c5aa9663d83f49c951c379a38f1f6).)

 > To [parse a
 > stylesheet](#parse-a-stylesheet) from an `input` [given an optional
 > [url](https://url.spec.whatwg.org/#concept-url) `location`] :
 >
 > 1. \...
 > 2. Create a new stylesheet [, with its
 > [location](https://drafts.csswg.org/cssom-1/#concept-css-style-sheet-location) set to `location` (or null, if
 > `location` was not passed).]
 > 3. \...

The following editorial changes were made:

- Added [§ 8.2 At-rules](#at-rules) to provide definitions for
 [at-rules](#at-rule), [statement
 at-rules](#statement-at-rule), [block
 at-rules](#block-at-rule),
 and [descriptors](#css-descriptor).
 ([5633](https://github.com/w3c/csswg-drafts/issues/5633))

- Improved the definition text for
 [declaration](#declaration),
 and added definitions for [property
 declarations](#css-property-declarations) and [descriptor
 declarations](#css-descriptor-declarations).

- Switched to consistently refer to [ident
 sequence](#ident-sequence),
 rather than sometimes using the term "name".

- Explicitly named several of the pre-tokenizing processes, and
 explicitly referred to them in the parsing entry points (rather than
 relying on a blanket \"do X at the start of these algorithms\"
 statement).

- Added more entries to the \"put a comment between them\" table, to
 properly handle the fact that idents can now start with `--`.
 ([6874](https://github.com/w3c/csswg-drafts/pull/6874))

### 12.3. Changes from the 20 February 2014 Candidate Recommendation

The following substantive changes were made:

- Removed
 [\<unicode-range-token\>](#typedef-unicode-range-token), in favor of creating a
 [\<urange\>] production.

- url() functions that contain a string are now parsed as normal
 [\<function-token\>](#typedef-function-token)s. url() functions that contain
 \"raw\" URLs are still specially parsed as
 [\<url-token\>](#typedef-url-token)s.

- Fixed a bug in the \"Consume a URL token\" algorithm, where it didn't
 consume the quote character starting a string before attempting to
 consume the string.

- Fixed a bug in several of the parser algorithms related to the
 current/next token and things getting consumed early/late.

- Fix several bugs in the tokenization and parsing algorithms.

- Change the definition of ident-like tokens to allow \"\--\" to start
 an ident. As part of this, rearrange the ordering of the clauses in
 the \"-\" step of [consume a
 token](#tokenizer-consume-a-token) so that
 [\<CDC-token\>](#typedef-cdc-token)s are recognized as such instead of
 becoming a [\--]
 [\<ident-token\>](#typedef-ident-token).

- Don't serialize the digit in an
 [\<a-n-plus-b\>](#anb-production) when A is 1 or -1.

- Define all tokens to have a representation.

- Fixed minor bug in [check if two code points are a valid
 escape](#check-if-two-code-points-are-a-valid-escape)---​a `\` followed by an EOF is now correctly reported
 as *not* a valid escape. A final `\` in a stylesheet now just emits
 itself as a
 [\<delim-token\>](#typedef-delim-token).

- \@charset is no longer a valid CSS rule (there's just an encoding
 declaration that *looks* like a rule named \@charset)

- Trimmed whitespace from the beginning/ending of a declaration's value
 during parsing.

- Removed the Selectors-specific tokens, per WG resolution.

- Filtered
 [surrogates](https://infra.spec.whatwg.org/#surrogate) from the input stream, per WG resolution. Now the
 entire specification operates only on [scalar
 values](https://infra.spec.whatwg.org/#scalar-value).

The following editorial changes were made:

- The \"Consume a string token\" algorithm was changed to allow calling
 it without specifying an explicit ending token, so that it uses the
 current token instead. The three call-sites of the algorithm were
 changed to use that form.

- Minor editorial restructuring of algorithms.

- Added the
 [parse](#css-parse-something-according-to-a-css-grammar) and [parse a comma-separated list of component
 values](#parse-a-comma-separated-list-of-component-values) API entry points.

- Added the
 [\<declaration-value\>](#typedef-declaration-value) and
 [\<any-value\>](#typedef-any-value) productions.

- Removed \"code point\" and \"surrogate code point\" in favor of the
 identical definitions in the Infra Standard.

- Clarified on every range that they are inclusive.

- Added a column to the comment-insertion table to handle a number token
 appearing next to a \"%\" delim token.

[A Disposition of Comments is
available.](https://github.com/w3c/csswg-drafts/milestone/5?closed=1)

### 12.4. Changes from the 5 November 2013 Last Call Working Draft

- The [Serialization](#serialization) section has been rewritten to make
 only the \"round-trip\" requirement normative, and move the details of
 how to achieve it into a note. Some corner cases in these details have
 been fixed.

- [\[ENCODING\]](#biblio-encoding "Encoding Standard")
 has been added to the list of normative references. It was already
 referenced in normative text before, just not listed as such.

- In the algorithm to [determine the fallback
 encoding](#determine-the-fallback-encoding) of a stylesheet, limit the `@charset` byte sequence
 to 1024 bytes. This aligns with what HTML does for `<meta charset>`
 and makes sure the size of the sequence is bounded. This only makes a
 difference with leading or trailing whitespace in the encoding label:

 @charset " (lots of whitespace) utf-8";

### 12.5. Changes from the 19 September 2013 Working Draft

- The concept of [environment
 encoding](#environment-encoding) was added. The behavior does not change, but some of
 the definitions should be moved to the relevant specs.

### 12.6. Changes from CSS 2.1 and Selectors Level 3

 The point of this spec is to match reality; changes
from CSS2.1 are nearly always because CSS 2.1 specified something that
doesn't match actual browser behavior, or left something unspecified. If
some detail doesn't match browsers, please let me know as it's almost
certainly unintentional.

Changes in decoding from a byte stream:

- Only detect
 [\@charset](#at-ruledef-charset) rules in ASCII-compatible byte patterns.
- Ignore [\@charset](#at-ruledef-charset) rules that specify an ASCII-incompatible
 encoding, as that would cause the rule itself to not decode properly.
- Refer to
 [\[ENCODING\]](#biblio-encoding "Encoding Standard")
 rather than the IANA registry for character encodings.

Tokenization changes:

- Any U+0000 NULL [code
 point](https://infra.spec.whatwg.org/#code-point) in the CSS source is replaced with U+FFFD REPLACEMENT
 CHARACTER.

- Any hexadecimal escape sequence such as [\\0] that evaluates to
 zero produce U+FFFD REPLACEMENT CHARACTER rather than U+0000 NULL.

- The definition of [non-ASCII ident code
 point](#non-ascii-ident-code-point) was changed to be consistent with HTML's [valid
 custom element
 names](https://html.spec.whatwg.org/multipage/custom-elements.html#valid-custom-element-name).

- Tokenization does not emit COMMENT or BAD_COMMENT tokens anymore.
 BAD_COMMENT is now considered the same as a normal token (not an
 error). [Serialization](#serialization) is responsible for inserting
 comments as necessary between tokens that need to be separated, e.g.
 two consecutive
 [\<ident-token\>](#typedef-ident-token)s.

- The
 [\<unicode-range-token\>](#typedef-unicode-range-token) was removed, as it was low value
 and occasionally actively harmful. ([u+a { font-weight: bold; }]
 was an invalid selector, for example\...)

 Instead, a [\<urange\>] production was added, based on
 token patterns. It is technically looser than what 2.1 allowed (any
 number of digits and ? characters), but not in any way that should
 impact its use in practice.

- Apply the [EOF error handling
 rule](https://www.w3.org/TR/CSS2/syndata.html#unexpected-eof) in the
 tokenizer and emit normal
 [\<string-token\>](#typedef-string-token) and
 [\<url-token\>](#typedef-url-token) rather than BAD_STRING or BAD_URI on
 EOF.

- The BAD_URI token (now
 [\<bad-url-token\>](#typedef-bad-url-token)) is \"self-contained\". In other
 words, once the tokenizer realizes it's in a
 [\<bad-url-token\>]
 rather than a
 [\<url-token\>](#typedef-url-token), it just seeks forward to look for the
 closing ), ignoring everything else. This behavior is simpler than
 treating it like a
 [\<function-token\>](#typedef-function-token) and paying attention to opened
 blocks and such. Only WebKit exhibits this behavior, but it doesn't
 appear that we've gotten any compat bugs from it.

- The
 [\<comma-token\>](#typedef-comma-token) has been added.

- [\<number-token\>](#typedef-number-token),
 [\<percentage-token\>](#typedef-percentage-token), and
 [\<dimension-token\>](#typedef-dimension-token) have been changed to include the
 preceding +/- sign as part of their value (rather than as a separate
 [\<delim-token\>](#typedef-delim-token) that needs to be manually handled
 every time the token is mentioned in other specs). The only
 consequence of this is that comments can no longer be inserted between
 the sign and the number.

- Scientific notation is supported for numbers/percentages/dimensions to
 match SVG, per WG resolution.

- Hexadecimal escape for
 [surrogate](https://infra.spec.whatwg.org/#surrogate) now emit a replacement character rather than the
 surrogate. This allows implementations to safely use UTF-16
 internally.

Parsing changes:

- Any list of declarations now also accepts at-rules, like
 [\@page](https://drafts.csswg.org/css-page-3/#at-ruledef-page), per WG resolution. This makes a difference in
 error handling even if no such at-rules are defined yet: an at-rule,
 valid or not, ends at a block without a
 [\<semicolon-token\>](#typedef-semicolon-token) and lets the next declaration
 begin.
- The handling of some miscellaneous \"special\" tokens (like an
 unmatched
 [\<}-token\>](#tokendef-close-curly))
 showing up in various places in the grammar has been specified with
 some reasonable behavior shown by at least one browser. Previously,
 stylesheets with those tokens in those places just didn't match the
 stylesheet grammar at all, so their handling was totally undefined.
 Specifically:
 - \[\] blocks, () blocks and functions can now contain blocks,
 [\<at-keyword-token\>](#typedef-at-keyword-token)s or
 [\<semicolon-token\>](#typedef-semicolon-token)s
 - Qualified rule preludes can now contain semicolons
 - Qualified rule and at-rule preludes can now contain
 [\<at-keyword-token\>](#typedef-at-keyword-token)s

`An+B` changes from Selectors Level 3
[\[SELECT\]](#biblio-select "Selectors Level 3"):

- The `An+B` microsyntax has now been formally defined in
 terms of CSS tokens, rather than with a separate tokenizer. This has
 resulted in minor differences:
 - In some cases, minus signs or digits can be escaped (when they
 appear as part of the unit of a
 [\<dimension-token\>](#typedef-dimension-token) or
 [\<ident-token\>](#typedef-ident-token)).

## [ Acknowledgments]
Thanks for feedback and contributions from Anne van Kesteren, David
Baron, Elika J. Etemad (fantasai), Henri Sivonen, Johannes Koch, 呂康豪
(Kang-Hao Lu), Marc O'Morain, Raffaello Giulietti, Simon Pieter, Tyler
Karaszewski, and Zack Weinberg.
