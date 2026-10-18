## 1. Introduction

*This section is not normative.*

In 1997, HTML4
[\[HTML401\]](#biblio-html401 "HTML 4.01 Specification")
defined a mechanism to support media-dependent style sheets, tailored
for different [media types](#media-type). For example, a document may use different style sheets
for screen and for print. In HTML, this can be written as:

<link rel="stylesheet" type="text/css" media="screen" href="style.css">
 <link rel="stylesheet" type="text/css" media="print" href="print.css">

CSS adapted and extended this functionality with its
[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media) and
[\@import](https://www.w3.org/TR/css-cascade-5/#at-ruledef-import) rules, adding the ability to query the value of
individual features:

Inside a CSS style sheet, one can
declare that sections apply to certain [media
types](#media-type):

 @media screen {
 * { font-family: sans-serif }
 }

Similarly, stylesheets can be conditionally imported based on media
queries:

 @import "print-styles.css" print;

[Media queries](#media-query) can
be used with HTML, XHTML, XML
[\[xml-stylesheet\]](#biblio-xml-stylesheet "Associating Style Sheets with XML documents 1.0 (Second Edition)")
and the \@import and \@media rules of CSS.

Here is the same example written in
HTML, XHTML, XML, \@import and \@media:

 <link media="screen and (color), projection and (color)"
 rel="stylesheet" href="example.css">

 <link media="screen and (color), projection and (color)"
 rel="stylesheet" href="example.css" />

 <?xml-stylesheet media="screen and (color), projection and (color)"
 rel="stylesheet" href="example.css" ?>

 @import url(example.css) screen and (color), projection and (color);

 @media screen and (color), projection and (color) { … }

### 1.1. Module interactions

This module extends and supersedes
[\[MEDIAQUERIES-4\]](#biblio-mediaqueries-4 "Media Queries Level 4")
and its predecessor
[\[MEDIAQUERIES-3\]](#biblio-mediaqueries-3 "Media Queries Level 3"),
which themselves built upon and replaced [CSS 2 § 7 Media
types](https://www.w3.org/TR/CSS2/media.html#q7.0).

### 1.2. Values

Value types not defined in this specification, such as
[\<integer\>](https://www.w3.org/TR/css-values-4/#integer-value),
[\<number\>](https://www.w3.org/TR/css-values-4/#number-value) or
[\<resolution\>](https://www.w3.org/TR/css-values-4/#resolution-value), are defined in
[\[CSS-VALUES-4\]](#biblio-css-values-4 "CSS Values and Units Module Level 4").
Other CSS modules may expand the definitions of these value types.

### 1.3. Units

The units used in media queries are the same as in other parts of CSS,
as defined in
[\[CSS-VALUES-4\]](#biblio-css-values-4 "CSS Values and Units Module Level 4").
For example, the pixel unit represents CSS pixels and not physical
pixels.

[Relative
length](https://www.w3.org/TR/css-values-4/#relative-length) units in media queries are based on the [initial
value](https://www.w3.org/TR/css-cascade-5/#initial-value), which means that units are never based on results of
declarations.

 For example, in HTML, the
[em](https://www.w3.org/TR/css-values-4/#em) unit is relative to the [initial
value](https://www.w3.org/TR/css-cascade-5/#initial-value) of
[font-size](https://www.w3.org/TR/css-fonts-4/#propdef-font-size), defined by the user agent or the
user's preferences, not any styling on the page. Note that this will
also take into account additional restrictions the user might apply,
such as minimum font sizes.

## 2. Media Queries

A [media query]
is a method of testing certain aspects of the user agent or device that
the document is being displayed in. [Media
queries](#media-query) are
(almost) always independent of the contents of the document, its
styling, or any other internal aspect; they're only dependent on
"external" information unless another feature explicitly specifies that
it affects the resolution of Media Queries.

The syntax of a [media query](#media-query) consists of an optional [media query
modifier](#media-query-modifier), an optional [media
type](#media-type), and zero or
more [media features](#media-feature):

!(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxMzIiIHZpZXdib3g9IjAgMCA1OTIuMCAxMzIiIHdpZHRoPSI1OTIuMCI+CiAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgPGc+CiAgICAgICA8cGF0aCBkPSJNMjAgMjF2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgIDwvZz4KICAgICAgPGc+CiAgICAgICA8cGF0aCBkPSJNNDAgMzFoMC4wIiAvPgogICAgICAgPHBhdGggZD0iTTU1Mi4wIDMxaDAuMCIgLz4KICAgICAgIDxwYXRoIGQ9Ik00MC4wIDMxaDIwIiAvPgogICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgPHBhdGggZD0iTTYwLjAgMzFoMTYyLjI1IiAvPgogICAgICAgIDxwYXRoIGQ9Ik0zNjkuNzUgMzFoMTYyLjI1IiAvPgogICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxNDcuNSIgeD0iMjIyLjI1IiB5PSIyMCIgLz4KICAgICAgICA8dGV4dCB4PSIyOTYiIHk9IjM1Ij5tZWRpYSBjb25kaXRpb248L3RleHQ+CiAgICAgICA8L2c+CiAgICAgICA8cGF0aCBkPSJNNTMyLjAgMzFoMjAiIC8+CiAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWExMCAxMCAwIDAgMSAxMCAxMHYzMGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgIDxnPgogICAgICAgIDxwYXRoIGQ9Ik02MC4wIDgxaDAuMCIgLz4KICAgICAgICA8cGF0aCBkPSJNNTMyLjAgODFoMC4wIiAvPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNNjAuMCA4MWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0xNTQuMCA4MWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDgxYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik04MC4wIDYxaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMzQuMCA2MWgwLjAiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjU0IiB4PSI4MCIgeT0iNTAiIC8+CiAgICAgICAgICA8dGV4dCB4PSIxMDciIHk9IjY1Ij5vbmx5PC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0xMzQuMCA2MWExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNjAuMCA4MWgyMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNODAuMCA4MWg1NC4wIiAvPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0xMzQuMCA4MWgyMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTYwLjAgODFhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik04MC4wIDEwMWg0LjI1IiAvPgogICAgICAgICAgPHBhdGggZD0iTTEyOS43NSAxMDFoNC4yNSIgLz4KICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iNDUuNSIgeD0iODQuMjUiIHk9IjkwIiAvPgogICAgICAgICAgPHRleHQgeD0iMTA3IiB5PSIxMDUiPm5vdDwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMTM0LjAgMTAxYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTE1NC4wIDgxaDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNMTY0LjAgODFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMjY5LjAgODFoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTA1IiB4PSIxNjQiIHk9IjcwIiAvPgogICAgICAgICA8dGV4dCB4PSIyMTYuNSIgeT0iODUiPm1lZGlhIHR5cGU8L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0yNjkuMCA4MWgxMCIgLz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTI3OS4wIDgxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTUzMi4wIDgxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTI3OS4wIDgxYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNMjk5LjAgNjFoMjEzLjAiIC8+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTUxMi4wIDYxYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0yNzkuMCA4MWgyMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNMjk5LjAgODFoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTUxMi4wIDgxaDAuMCIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTI5OS4wIDgxaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzQ0LjUgODFoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iNDUuNSIgeD0iMjk5IiB5PSI3MCIgLz4KICAgICAgICAgICA8dGV4dCB4PSIzMjEuNzUiIHk9Ijg1Ij5hbmQ8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMzQ0LjUgODFoMTAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMzU0LjUgODFoMTAiIC8+CiAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNMzY0LjUgODFoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik01MTIuMCA4MWgwLjAiIC8+CiAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjE0Ny41IiB4PSIzNjQuNSIgeT0iNzAiIC8+CiAgICAgICAgICAgPHRleHQgeD0iNDM4LjI1IiB5PSI4NSI+bWVkaWEgY29uZGl0aW9uPC90ZXh0PgogICAgICAgICAgPC9nPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik01MTIuMCA4MWgyMCIgLz4KICAgICAgICA8L2c+CiAgICAgICA8L2c+CiAgICAgICA8cGF0aCBkPSJNNTMyLjAgODFhMTAgMTAgMCAwIDAgMTAgLTEwdi0zMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgIDwvZz4KICAgICAgPHBhdGggZD0iTSA1NTIuMCAzMSBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgPC9nPgogICAgPC9zdmc+)

A [media query](#media-query) is
a logical expression that is either true or false. A media query is true
if:

- the [media type](#media-type),
 if specified, matches the media type of the device where the user
 agent is running, and

- the [media condition](#media-condition) is true.

Statements regarding media queries in this section assume the [syntax
section](#mq-syntax) is followed. Media queries that do not conform to
the syntax are discussed in [§ 3.2 Error Handling](#error-handling).
I.e. the syntax takes precedence over requirements in this section.

Here is a simple example written in
HTML:

 <link rel="stylesheet" media="screen and (color)" href="example.css" />

This example expresses that a certain style sheet (`example.css`)
applies to devices of a certain media type
([screen](#valdef-media-screen)) with certain feature (it must be a color screen).

Here is the same media query written in an \@import-rule in CSS:

 @import url(example.css) screen and (color);

User agents must re-evaluate [media
queries](#media-query) in
response to changes in the user environment that they're aware of, for
example if the device is tiled from landscape to portrait orientation,
and change the behavior of any constructs dependent on those [media
queries] accordingly.

Unless another feature explicitly specifies that it affects the
resolution of Media Queries, it is never necessary to apply a style
sheet in order to evaluate expressions.

### 2.1. Combining Media Queries

Several [media queries](#media-query) can be combined into a comma-separated [media query
list].

!(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxMDEiIHZpZXdib3g9IjAgMCAyNTMuNSAxMDEiIHdpZHRoPSIyNTMuNSI+CiAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgPGc+CiAgICAgICA8cGF0aCBkPSJNMjAgMzB2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgIDwvZz4KICAgICAgPGc+CiAgICAgICA8cGF0aCBkPSJNNDAgNDBoMC4wIiAvPgogICAgICAgPHBhdGggZD0iTTIxMy41IDQwaDAuMCIgLz4KICAgICAgIDxwYXRoIGQ9Ik00MC4wIDQwYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgIDxnPgogICAgICAgIDxwYXRoIGQ9Ik02MC4wIDIwaDEzMy41IiAvPgogICAgICAgPC9nPgogICAgICAgPHBhdGggZD0iTTE5My41IDIwYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICA8cGF0aCBkPSJNNDAuMCA0MGgyMCIgLz4KICAgICAgIDxnPgogICAgICAgIDxwYXRoIGQ9Ik02MC4wIDQwaDAuMCIgLz4KICAgICAgICA8cGF0aCBkPSJNMTkzLjUgNDBoMC4wIiAvPgogICAgICAgIDxwYXRoIGQ9Ik02MC4wIDQwaDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNNzAuMCA0MGgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0xODMuNSA0MGgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxMTMuNSIgeD0iNzAiIHk9IjI5IiAvPgogICAgICAgICA8dGV4dCB4PSIxMjYuNzUiIHk9IjQ0Ij5tZWRpYSBxdWVyeTwvdGV4dD4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTE4My41IDQwaDEwIiAvPgogICAgICAgIDxwYXRoIGQ9Ik03MC4wIDQwYTEwIDEwIDAgMCAwIC0xMCAxMHYxMGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNNzAuMCA3MGg0Mi41IiAvPgogICAgICAgICA8cGF0aCBkPSJNMTQxLjAgNzBoNDIuNSIgLz4KICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSIxMTIuNSIgeT0iNTkiIC8+CiAgICAgICAgIDx0ZXh0IHg9IjEyNi43NSIgeT0iNzQiPiw8L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0xODMuNSA3MGExMCAxMCAwIDAgMCAxMCAtMTB2LTEwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICA8L2c+CiAgICAgICA8cGF0aCBkPSJNMTkzLjUgNDBoMjAiIC8+CiAgICAgIDwvZz4KICAgICAgPHBhdGggZD0iTSAyMTMuNSA0MCBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgPC9nPgogICAgPC9zdmc+)

A [media query list](#media-query-list) is true if *any* of its component [media
queries](#media-query) are true,
and false only if *all* of its component [media
queries] are false.

For example, the following [media
query list](#media-query-list) is true if either the [media
type](#media-type) is
[screen](#valdef-media-screen) and it's a color device, **or** the [media
type] is
[projection](#valdef-media-projection) and it's a color device:

 @media screen and (color), projection and (color) { … }

An empty [media query
list](#media-query-list)
evaluates to true.

For example, these are equivalent:

 @media all { … }
 @media { … }

### 2.2. Media Query Modifiers

A [media query](#media-query)
may optionally be prefixed by a single [media query
modifier], which is a single keyword which alters the meaning of the
following [media query].

#### 2.2.1. Negating a Media Query: the [not keyword]
An individual [media query](#media-query) can have its result negated by prefixing it with the
keyword [not]. If the [media
query] would normally evaluate to true,
prefixing it with [not](#valdef-media-not) makes it evaluate to false, and vice versa.

For example, the following will apply
to everything except color-capable screens. Note that the entire media
query is negated, not just the [media
type](#media-type).

 <link rel="stylesheet" media="not screen and (color)" href="example.css" />

#### 2.2.2. Hiding a Media Query From Legacy user agents: the [only keyword]
The concept of [media queries](#media-query) originates from HTML4
[\[HTML401\]](#biblio-html401 "HTML 4.01 Specification").
That specification only defined [media
types](#media-type), but had a
forward-compatible syntax that accommodated the addition of future
concepts like [media features](#media-feature): it would consume the characters of a [media
query] up to the first non-alphanumeric
character, and interpret that as a [media type],
ignoring the rest. For example, the [media
query] [screen and (color)] would be
truncated to just
[screen](#valdef-media-screen).

Unfortunately, this means that legacy user agents using this
error-handling behavior will ignore any [media
features](#media-feature) in a
[media query](#media-query),
even if they're far more important than the [media
type](#media-type) in the query.
This can result in styles accidentally being applied in inappropriate
situations.

To hide these [media queries](#media-query) from legacy user agents, the [media
query] can be prefixed with the keyword
[only]. The
[only](#valdef-media-only) keyword **has no effect** on the [media
query]'s result, but will cause the [media
query] to be parsed by legacy user agents as
specifying the unknown [media type](#media-type) "only", and thus be ignored.

In this example, the stylesheet
specified by the `<link>` element will not be used by legacy user
agents, even if they would normally match the
[screen](#valdef-media-screen) [media type](#media-type).

 <link rel="stylesheet" media="only screen and (color)" href="example.css" />

 Note that the
[only](#valdef-media-only) keyword can only be used before a [media
type](#media-type). A [media
query](#media-query) consisting
only of [media features](#media-feature), or one with another [media query
modifier](#media-query-modifier) like
[not](#valdef-media-not), will be treated as false by legacy user agents
automatically.

 At the time of publishing this specification, such
legacy user agents are extremely rare, and so using the
[only](#valdef-media-only) modifier is rarely, if ever, necessary.

### 2.3. Media Types

A [media type]
is a broad category of user-agent devices on which a document may be
displayed. The original set of [media
types](#media-type) were defined
in HTML4, for the `media` attribute on `<link>` elements.

Unfortunately, [media types](#media-type) have proven insufficient as a way of discriminating
between devices with different styling needs. Some categories which were
originally quite distinct, such as
[screen](#valdef-media-screen) and
[handheld](#valdef-media-handheld), have blended significantly in the years since their
invention. Others, such as
[tty](#valdef-media-tty) or [tv](#valdef-media-tv), expose useful differences from the norm of a
full-featured computer monitor, and so are potentially useful to target
with different styling, but the definition of [media
types] as mutually exclusive makes it difficult
to use them in a reasonable manner; instead, their exclusive aspects are
better expressed as [media
features](#media-feature) such
as [grid](#descdef-media-grid) or
[scan](#descdef-media-scan).

As such, the following [media types](#media-type) are defined for use in [media
queries](#media-query):

[all]
: Matches all devices.

[print]
: Matches printers, and devices intended to reproduce a printed
 display, such as a web browser showing a document in "Print
 Preview".

[screen]
: Matches all devices that aren't matched by
 [print](#valdef-media-print).

In addition, the following **deprecated** [media
types](#media-type) are defined.
Authors must not use these [media types];
instead, it is recommended that they select appropriate [media
features](#media-feature) that
better represent the aspect of the device that they are attempting to
style against.

User agents must recognize the following [media
types](#media-type) as valid, but
must make them match nothing.

- [tty]
- [tv]
- [projection]
- [handheld]
- [braille]
- [embossed]
- [aural]
- [speech]

 It is expected that all of the media types will also be
deprecated in time, as appropriate [media
features](#media-feature) are
defined which capture their important differences.

### 2.4. Media Features

A [media feature] is a more fine-grained test than [media
types](#media-type), testing a
single, specific feature of the user agent or display device.

Syntactically, [media features](#media-feature) resemble CSS properties: they consist of a feature
name, a colon, and a value to test for. They may also be written in
boolean form as just a feature name, or in range form with a comparison
operator.

!(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxMjIiIHZpZXdib3g9IjAgMCA0NDEuMCAxMjIiIHdpZHRoPSI0NDEuMCI+CiAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgPGc+CiAgICAgICA8cGF0aCBkPSJNMjAgMjF2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgIDwvZz4KICAgICAgPGc+CiAgICAgICA8cGF0aCBkPSJNNDAgMzFoMC4wIiAvPgogICAgICAgPHBhdGggZD0iTTQwMS4wIDMxaDAuMCIgLz4KICAgICAgIDxwYXRoIGQ9Ik00MC4wIDMxaDIwIiAvPgogICAgICAgPGc+CiAgICAgICAgPHBhdGggZD0iTTYwLjAgMzFoMC4wIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0zODEuMCAzMWgwLjAiIC8+CiAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDMxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTE4Mi4wIDMxaDAuMCIgLz4KICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjEyMiIgeD0iNjAiIHk9IjIwIiAvPgogICAgICAgICA8dGV4dCB4PSIxMjEiIHk9IjM1Ij5mZWF0dXJlIG5hbWU8L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0xODIuMCAzMWgxMCIgLz4KICAgICAgICA8cGF0aCBkPSJNMTkyLjAgMzFoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTIwMi4wIDMxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTIzMC41IDMxaDAuMCIgLz4KICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSIyMDIiIHk9IjIwIiAvPgogICAgICAgICA8dGV4dCB4PSIyMTYuMjUiIHk9IjM1Ij46PC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMjMwLjUgMzFoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTTI0MC41IDMxaDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNMjUwLjUgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMzgxLjAgMzFoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTMwLjUiIHg9IjI1MC41IiB5PSIyMCIgLz4KICAgICAgICAgPHRleHQgeD0iMzE1Ljc1IiB5PSIzNSI+ZmVhdHVyZSB2YWx1ZTwvdGV4dD4KICAgICAgICA8L2c+CiAgICAgICA8L2c+CiAgICAgICA8cGF0aCBkPSJNMzgxLjAgMzFoMjAiIC8+CiAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWExMCAxMCAwIDAgMSAxMCAxMHYxMGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgIDxwYXRoIGQ9Ik02MC4wIDYxaDk5LjUiIC8+CiAgICAgICAgPHBhdGggZD0iTTI4MS41IDYxaDk5LjUiIC8+CiAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjEyMiIgeD0iMTU5LjUiIHk9IjUwIiAvPgogICAgICAgIDx0ZXh0IHg9IjIyMC41IiB5PSI2NSI+ZmVhdHVyZSBuYW1lPC90ZXh0PgogICAgICAgPC9nPgogICAgICAgPHBhdGggZD0iTTM4MS4wIDYxYTEwIDEwIDAgMCAwIDEwIC0xMHYtMTBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgPHBhdGggZD0iTTQwLjAgMzFhMTAgMTAgMCAwIDEgMTAgMTB2NDBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICA8Zz4KICAgICAgICA8cGF0aCBkPSJNNjAuMCA5MWg1NC41IiAvPgogICAgICAgIDxwYXRoIGQ9Ik0zMjYuNSA5MWg1NC41IiAvPgogICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNMTE0LjUgOTFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMjE5LjUgOTFoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTA1IiB4PSIxMTQuNSIgeT0iODAiIC8+CiAgICAgICAgIDx0ZXh0IHg9IjE2NyIgeT0iOTUiPnJhbmdlIGZvcm08L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0yMTkuNSA5MWgxMCIgLz4KICAgICAgICA8cGF0aCBkPSJNMjI5LjUgOTFoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgIDxwYXRoIGQ9Ik0yMzkuNSA5MWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0zMjYuNSA5MWgwLjAiIC8+CiAgICAgICAgIDx0ZXh0IGNsYXNzPSJjb21tZW50IiB4PSIyODMiIHk9Ijk2Ij4oc2VlIGJlbG93KTwvdGV4dD4KICAgICAgICA8L2c+CiAgICAgICA8L2c+CiAgICAgICA8cGF0aCBkPSJNMzgxLjAgOTFhMTAgMTAgMCAwIDAgMTAgLTEwdi00MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgIDwvZz4KICAgICAgPHBhdGggZD0iTSA0MDEuMCAzMSBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgPC9nPgogICAgPC9zdmc+)

There are, however, several important differences between properties and
media features:

- Properties are used to give information about how to present a
 document. Media features are used to describe requirements of the
 output device.
- Media features are always wrapped in parentheses and combined with the
 [and] or [or] keywords, like [(color) and (min-width:
 600px)], rather than being separated with semicolons.
- A media feature may be given with *only* its name (omitting the colon
 and value) to evaluate the feature in a [boolean
 context](#boolean-context).
 This is a convenient shorthand for features that have a reasonable
 value representing 0 or "none". For example, [(color)] is true
 if the [color](#descdef-media-color) [media
 feature](#media-feature) is
 non-zero.
- [Media features](#media-feature) with "range" type can be written in a [range
 context](#range-context),
 which uses standard mathematical comparison operators rather than a
 colon, or have their feature names [prefixed with "min-" or
 "max-"](#mq-min-max).
- Properties sometimes accept complex values, e.g., calculations that
 involve several other values. [Media
 features](#media-feature)
 only accept single values: one keyword, one number, etc.

If a [media feature](#media-feature) references a concept which does not exist on the device
where the UA is running (for example, speech UAs do not have a concept
of "width"), the [media feature] must always
evaluate to false.

The media feature
[device-aspect-ratio](#descdef-media-device-aspect-ratio) only applies to visual devices. On an
[speech](#valdef-media-speech) device, expressions involving
[device-aspect-ratio] will therefore always be false:

 <link media="speech and (device-aspect-ratio: 16/9)"
 rel="stylesheet" href="example.css">

#### 2.4.1. Media Feature Types: "range" and "discrete"

Every media feature defines its "type" as either "range" or "discrete"
in its definition table.

"Discrete" media features, like
[pointer](#descdef-media-pointer) take their values from a set. The values
may be keywords or boolean numbers (0 and 1), but the common factor is
that there's no intrinsic "order" to them---​none of the values are "less
than" or "greater than" each other.

"Range" media features like
[width](#descdef-media-width), on the other hand, take their values from a
range. Any two values can be compared to see which is lesser and which
is greater.

The only significant difference between the two types is that "range"
[media features](#media-feature) can be evaluated in a [range
context](#range-context) and
accept "min-" and "max-" prefixes on their name. Doing either of these
changes the meaning of the feature---​rather than the [media
feature] being true when the feature exactly
matches the given value, it matches when the feature is greater
than/less than/equal to the given value.

A [(width \>= 600px)] [media
feature](#media-feature) is
true when the viewport's width is [600px] *or more*.

On the other hand, [(width: 600px)] by itself is only true when
the viewport's width is *exactly* [600px]. If it's less or greater
than [600px], it'll be false.

#### 2.4.2. Evaluating Media Features in a Boolean Context

While [media features](#media-feature) normally have a syntax similar to CSS properties, they
can also be written more simply as just the feature name, like
[(color)].

When written like this, the [media
feature](#media-feature) is
evaluated in a [boolean context]. If the feature would be true for any value
*other than* the number [0], a
[\<dimension\>](https://www.w3.org/TR/css-values-4/#typedef-dimension) with the value [0], the keyword
[none](#valdef-media-update-none), or a value explicitly defined by that media feature
to evaluate as false in a boolean context, the [media
feature] evaluates to true. Otherwise, it
evaluates to false.

Some [media
features](#media-feature) are
designed to be written like this.

For example,
[update](#descdef-media-update) is typically written as [(update)] to test
if any kind of updating is available, or [not (update)] to check
for the opposite.

It can still be given an explicit value as well, with [(update: fast) or
(update: slow)] equal to [(update)], and [(update:
none)] equal to [not (update)].

Some numeric [media
features](#media-feature),
like [width](#descdef-media-width), are rarely if ever useful to evaluate
in a [boolean context](#boolean-context), as their values are almost always greater than zero.
Others, like [color](#descdef-media-color), have meaningful zero values:
[(color)] is identical to [(color \> 0)], indicating that
the device is capable of displaying color at all.

Only some of the [media
features](#media-feature) that
accept keywords are meaningful in a [boolean
context](#boolean-context).

For example, [(pointer)] is useful, as
[pointer](#descdef-media-pointer) has a
[none](#valdef-media-pointer-none) value to indicate there's no pointing device at
all on the device. On the other hand, [(scan)] is just always true
or always false (depending on whether it applies at all to the device),
as there's no value that means "false".

#### 2.4.3. Evaluating Media Features in a Range Context

[Media features](#media-feature) with a "range" type can be alternately written in a
[range context] that takes advantage of the fact that their values are
ordered, using ordinary mathematical comparison operators:

!(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIzMDIiIHZpZXdib3g9IjAgMCA2NjAuMCAzMDIiIHdpZHRoPSI2NjAuMCI+CiAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgPGc+CiAgICAgICA8cGF0aCBkPSJNMjAgMTQxdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICA8L2c+CiAgICAgIDxwYXRoIGQ9Ik00MCAxNTFoMTAiIC8+CiAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICA8cGF0aCBkPSJNNTAgMTUxaDAuMCIgLz4KICAgICAgIDxwYXRoIGQ9Ik03OC41IDE1MWgwLjAiIC8+CiAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjUwIiB5PSIxNDAiIC8+CiAgICAgICA8dGV4dCB4PSI2NC4yNSIgeT0iMTU1Ij4oPC90ZXh0PgogICAgICA8L2c+CiAgICAgIDxwYXRoIGQ9Ik03OC41IDE1MWgxMCIgLz4KICAgICAgPGc+CiAgICAgICA8cGF0aCBkPSJNODguNSAxNTFoMC4wIiAvPgogICAgICAgPHBhdGggZD0iTTU3MS41IDE1MWgwLjAiIC8+CiAgICAgICA8cGF0aCBkPSJNODguNSAxNTFoMjAiIC8+CiAgICAgICA8Zz4KICAgICAgICA8cGF0aCBkPSJNMTA4LjUgMTUxaDAuMCIgLz4KICAgICAgICA8cGF0aCBkPSJNNTUxLjUgMTUxaDAuMCIgLz4KICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTEwOC41IDE1MWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0yODEuNSAxNTFoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTczIiB4PSIxMDguNSIgeT0iMTQwIiAvPgogICAgICAgICA8dGV4dCB4PSIxOTUiIHk9IjE1NSI+ZmVhdHVyZSBuYW1lL3ZhbHVlPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMjgxLjUgMTUxaDEwIiAvPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjkxLjUgMTUxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTM2OC41IDE1MWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0yOTEuNSAxNTFhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICA8cGF0aCBkPSJNMzExLjUgMTIxaDQuMjUiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMzQ0LjI1IDEyMWg0LjI1IiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSIzMTUuNzUiIHk9IjExMCIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjMzMCIgeT0iMTI1Ij4mZ3Q7PC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0zNDguNSAxMjFhMTAgMTAgMCAwIDEgMTAgMTB2MTBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0yOTEuNSAxNTFhMTAgMTAgMCAwIDAgMTAgLTEwdi00MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICA8cGF0aCBkPSJNMzExLjUgOTFoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTM0OC41IDkxaDAuMCIgLz4KICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMzciIHg9IjMxMS41IiB5PSI4MCIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjMzMCIgeT0iOTUiPiZsdDs9PC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0zNDguNSA5MWExMCAxMCAwIDAgMSAxMCAxMHY0MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTI5MS41IDE1MWExMCAxMCAwIDAgMCAxMCAtMTB2LTcwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik0zMTEuNSA2MWg0LjI1IiAvPgogICAgICAgICAgPHBhdGggZD0iTTM0NC4yNSA2MWg0LjI1IiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSIzMTUuNzUiIHk9IjUwIiAvPgogICAgICAgICAgPHRleHQgeD0iMzMwIiB5PSI2NSI+Jmx0OzwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMzQ4LjUgNjFhMTAgMTAgMCAwIDEgMTAgMTB2NzBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0yOTEuNSAxNTFhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMDBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgPHBhdGggZD0iTTMxMS41IDMxaDQuMjUiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMzQ0LjI1IDMxaDQuMjUiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjMxNS43NSIgeT0iMjAiIC8+CiAgICAgICAgICA8dGV4dCB4PSIzMzAiIHk9IjM1Ij49PC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0zNDguNSAzMWExMCAxMCAwIDAgMSAxMCAxMHYxMDBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0yOTEuNSAxNTFoMjAiIC8+CiAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICA8cGF0aCBkPSJNMzExLjUgMTUxaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zNDguNSAxNTFoMC4wIiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIzNyIgeD0iMzExLjUiIHk9IjE0MCIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjMzMCIgeT0iMTU1Ij4mZ3Q7PTwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMzQ4LjUgMTUxaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMzY4LjUgMTUxaDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNMzc4LjUgMTUxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTU1MS41IDE1MWgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxNzMiIHg9IjM3OC41IiB5PSIxNDAiIC8+CiAgICAgICAgIDx0ZXh0IHg9IjQ2NSIgeT0iMTU1Ij5mZWF0dXJlIHZhbHVlL25hbWU8L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgPC9nPgogICAgICAgPHBhdGggZD0iTTU1MS41IDE1MWgyMCIgLz4KICAgICAgIDxwYXRoIGQ9Ik04OC41IDE1MWExMCAxMCAwIDAgMSAxMCAxMHYxMGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgIDxnPgogICAgICAgIDxwYXRoIGQ9Ik0xMDguNSAxODFoMS4wIiAvPgogICAgICAgIDxwYXRoIGQ9Ik01NTAuNSAxODFoMS4wIiAvPgogICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNMTA5LjUgMTgxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTE3Mi4wIDE4MWgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI2Mi41IiB4PSIxMDkuNSIgeT0iMTcwIiAvPgogICAgICAgICA8dGV4dCB4PSIxNDAuNzUiIHk9IjE4NSI+dmFsdWU8L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0xNzIuMCAxODFoMTAiIC8+CiAgICAgICAgPGc+CiAgICAgICAgIDxwYXRoIGQ9Ik0xODIuMCAxODFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMjU5LjAgMTgxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTE4Mi4wIDE4MWgyMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik0yMDIuMCAxODFoNC4yNSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yMzQuNzUgMTgxaDQuMjUiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjIwNi4yNSIgeT0iMTcwIiAvPgogICAgICAgICAgPHRleHQgeD0iMjIwLjUiIHk9IjE4NSI+Jmx0OzwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMjM5LjAgMTgxaDIwIiAvPgogICAgICAgICA8cGF0aCBkPSJNMTgyLjAgMTgxYTEwIDEwIDAgMCAxIDEwIDEwdjEwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgPHBhdGggZD0iTTIwMi4wIDIxMWgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMjM5LjAgMjExaDAuMCIgLz4KICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMzciIHg9IjIwMiIgeT0iMjAwIiAvPgogICAgICAgICAgPHRleHQgeD0iMjIwLjUiIHk9IjIxNSI+Jmx0Oz08L3RleHQ+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTIzOS4wIDIxMWExMCAxMCAwIDAgMCAxMCAtMTB2LTEwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTI1OS4wIDE4MWgxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTI2OS4wIDE4MWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0zOTEuMCAxODFoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTIyIiB4PSIyNjkiIHk9IjE3MCIgLz4KICAgICAgICAgPHRleHQgeD0iMzMwIiB5PSIxODUiPmZlYXR1cmUgbmFtZTwvdGV4dD4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTM5MS4wIDE4MWgxMCIgLz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTQwMS4wIDE4MWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik00NzguMCAxODFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAxLjAgMTgxaDIwIiAvPgogICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgPHBhdGggZD0iTTQyMS4wIDE4MWg0LjI1IiAvPgogICAgICAgICAgPHBhdGggZD0iTTQ1My43NSAxODFoNC4yNSIgLz4KICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iNDI1LjI1IiB5PSIxNzAiIC8+CiAgICAgICAgICA8dGV4dCB4PSI0MzkuNSIgeT0iMTg1Ij4mbHQ7PC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik00NTguMCAxODFoMjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik00MDEuMCAxODFhMTAgMTAgMCAwIDEgMTAgMTB2MTBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICA8cGF0aCBkPSJNNDIxLjAgMjExaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik00NTguMCAyMTFoMC4wIiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIzNyIgeD0iNDIxIiB5PSIyMDAiIC8+CiAgICAgICAgICA8dGV4dCB4PSI0MzkuNSIgeT0iMjE1Ij4mbHQ7PTwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNNDU4LjAgMjExYTEwIDEwIDAgMCAwIDEwIC0xMHYtMTBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNDc4LjAgMTgxaDEwIiAvPgogICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICA8cGF0aCBkPSJNNDg4LjAgMTgxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTU1MC41IDE4MWgwLjAiIC8+CiAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI2Mi41IiB4PSI0ODgiIHk9IjE3MCIgLz4KICAgICAgICAgPHRleHQgeD0iNTE5LjI1IiB5PSIxODUiPnZhbHVlPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgIDwvZz4KICAgICAgIDxwYXRoIGQ9Ik01NTEuNSAxODFhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICA8cGF0aCBkPSJNODguNSAxNTFhMTAgMTAgMCAwIDEgMTAgMTB2NzBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICA8Zz4KICAgICAgICA8cGF0aCBkPSJNMTA4LjUgMjQxaDEuMCIgLz4KICAgICAgICA8cGF0aCBkPSJNNTUwLjUgMjQxaDEuMCIgLz4KICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTEwOS41IDI0MWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0xNzIuMCAyNDFoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNjIuNSIgeD0iMTA5LjUiIHk9IjIzMCIgLz4KICAgICAgICAgPHRleHQgeD0iMTQwLjc1IiB5PSIyNDUiPnZhbHVlPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMTcyLjAgMjQxaDEwIiAvPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMTgyLjAgMjQxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTI1OS4wIDI0MWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0xODIuMCAyNDFoMjAiIC8+CiAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICA8cGF0aCBkPSJNMjAyLjAgMjQxaDQuMjUiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMjM0Ljc1IDI0MWg0LjI1IiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSIyMDYuMjUiIHk9IjIzMCIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjIyMC41IiB5PSIyNDUiPiZndDs8L3RleHQ+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTIzOS4wIDI0MWgyMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTE4Mi4wIDI0MWExMCAxMCAwIDAgMSAxMCAxMHYxMGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik0yMDIuMCAyNzFoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTIzOS4wIDI3MWgwLjAiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjM3IiB4PSIyMDIiIHk9IjI2MCIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjIyMC41IiB5PSIyNzUiPiZndDs9PC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0yMzkuMCAyNzFhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0yNTkuMCAyNDFoMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgIDxwYXRoIGQ9Ik0yNjkuMCAyNDFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMzkxLjAgMjQxaDAuMCIgLz4KICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjEyMiIgeD0iMjY5IiB5PSIyMzAiIC8+CiAgICAgICAgIDx0ZXh0IHg9IjMzMCIgeT0iMjQ1Ij5mZWF0dXJlIG5hbWU8L3RleHQ+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0zOTEuMCAyNDFoMTAiIC8+CiAgICAgICAgPGc+CiAgICAgICAgIDxwYXRoIGQ9Ik00MDEuMCAyNDFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDc4LjAgMjQxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQwMS4wIDI0MWgyMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik00MjEuMCAyNDFoNC4yNSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik00NTMuNzUgMjQxaDQuMjUiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjQyNS4yNSIgeT0iMjMwIiAvPgogICAgICAgICAgPHRleHQgeD0iNDM5LjUiIHk9IjI0NSI+Jmd0OzwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNNDU4LjAgMjQxaDIwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAxLjAgMjQxYTEwIDEwIDAgMCAxIDEwIDEwdjEwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgPHBhdGggZD0iTTQyMS4wIDI3MWgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNDU4LjAgMjcxaDAuMCIgLz4KICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMzciIHg9IjQyMSIgeT0iMjYwIiAvPgogICAgICAgICAgPHRleHQgeD0iNDM5LjUiIHk9IjI3NSI+Jmd0Oz08L3RleHQ+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTQ1OC4wIDI3MWExMCAxMCAwIDAgMCAxMCAtMTB2LTEwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTQ3OC4wIDI0MWgxMCIgLz4KICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgPHBhdGggZD0iTTQ4OC4wIDI0MWgwLjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik01NTAuNSAyNDFoMC4wIiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNjIuNSIgeD0iNDg4IiB5PSIyMzAiIC8+CiAgICAgICAgIDx0ZXh0IHg9IjUxOS4yNSIgeT0iMjQ1Ij52YWx1ZTwvdGV4dD4KICAgICAgICA8L2c+CiAgICAgICA8L2c+CiAgICAgICA8cGF0aCBkPSJNNTUxLjUgMjQxYTEwIDEwIDAgMCAwIDEwIC0xMHYtNzBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICA8L2c+CiAgICAgIDxwYXRoIGQ9Ik01NzEuNSAxNTFoMTAiIC8+CiAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICA8cGF0aCBkPSJNNTgxLjUgMTUxaDAuMCIgLz4KICAgICAgIDxwYXRoIGQ9Ik02MTAuMCAxNTFoMC4wIiAvPgogICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSI1ODEuNSIgeT0iMTQwIiAvPgogICAgICAgPHRleHQgeD0iNTk1Ljc1IiB5PSIxNTUiPik8L3RleHQ+CiAgICAgIDwvZz4KICAgICAgPHBhdGggZD0iTTYxMC4wIDE1MWgxMCIgLz4KICAgICAgPHBhdGggZD0iTSA2MjAuMCAxNTEgaCAyMCBtIC0xMCAtMTAgdiAyMCBtIDEwIC0yMCB2IDIwIiAvPgogICAgIDwvZz4KICAgIDwvc3ZnPg==)

 This syntax is new to Level 4 of Mediaqueries, and thus
is not as widely supported at the moment as the
[min-]/[max-] prefixes.

The basic form, consisting of a feature name, a comparison operator, and
a value, returns true if the relationship is true.

For example, [(height \> 600px)]
(or [(600px \< height)]) returns true if the viewport height is
greater than [600px].

The remaining forms, with the feature name nested between two value
comparisons, returns true if both comparisons are true.

For example, [(400px \< width \<
1000px)] returns true if the viewport width is between
[400px] and [1000px] (but not equal to either).

Some media features with a \"range\" type are said to be [false in the
negative range]. This means that negative values are valid
and must be parsed, and that querying whether the media feature is equal
to, less than, or less or equal than any such negative value must
evaluate to false. Querying whether the media feature is greater, or
greater or equal, than a negative value evaluates to true if the
relationship is true.

 If negative values had been rejected at parse time
instead, they would be treated as [unknown] based on the error
handling rules. However, in reality, whether a device's
[resolution](#descdef-media-resolution) is [-300dpi] is not unknown, it is
known to be false. Similarly, for any visual device, the
[width](#descdef-media-width) of the targeted display area is known to be
greater than [-200px] The above rule reflects that, making
intuition match what UAs do.

The following examples result in a
green background on all visual devices:

```
@media not (width <= -100px) {
 body { background: green; }
}
```

```
@media (height > -100px) {
 body { background: green; }
}
```

```
@media not (resolution: -300dpi) {
 body { background: green; }
}
```

This is a behavior change compared to Media Queries Level 3
[\[MEDIAQUERIES-3\]](#biblio-mediaqueries-3 "Media Queries Level 3"),
where negative values on these properties caused a syntax error. In
level 3, syntax errors---including forbidden values---resulted in the
entire [media query](#media-query) being false, rather than the [unknown] treatment
defined in this level. Implementations updating from level 3 should make
sure to change the handling of negative values for the relevant
properties when they add support for the richer syntax defined in [§ 2.5
Combining Media Features](#media-conditions), to avoid introducing
unintended semantics.

#### 2.4.4. Using "min-" and "max-" Prefixes On Range Features

Rather than evaluating a "range" type [media
feature](#media-feature) in a
range context, as described above, the feature may be written as a
normal [media feature], but with a "min-" or
"max-" prefix on the feature name.

This is equivalent to evaluating the feature in a [range
context](#range-context), as
follows:

- Using a "min-" prefix on a feature name is equivalent to using the
 "\>=" operator. For example, [(min-height: 600px)] is equivalent
 to [(height \>= 600px)].
- Using a "max-" prefix on a feature name is equivalent to using the
 "\<=" operator. For example, [(max-width: 40em)] is equivalent
 to [(width \<= 40em)].

 because "min-" and "max-" both equate to range
comparisons that **include** the value, they may be limiting in certain
situations.

For instance, authors trying to define
different styles based on a breakpoint in the viewport width using
"min-" and "max-" would generally offset the values they're comparing,
to ensure that both queries don't evaluate to true simultaneously.
Assuming the breakpoint is at 320px, authors would conceptually use:

 @media (max-width: 320px) { /* styles for viewports <= 320px */ }
 @media (min-width: 321px) { /* styles for viewports >= 321px */ }

While this ensures that the two sets of styles don't apply
simultaneously when the viewport width is 320px, it does not take into
account the possibility of fractional viewport sizes which can occur as
a result of non-integer pixel densities (e.g. on high-dpi displays or as
a result of zooming/scaling). Any viewport widths that fall between
320px and 321px will result in none of the styles being applied.

One approach to work around this problem is to increase the precision of
the values used for the comparison. Using the example above, changing
the second comparison value to 320.01px significantly reduces the chance
that a viewport width on a device would fall between the cracks.

 @media (max-width: 320px) { /* styles for viewports <= 320px */ }
 @media (min-width: 320.01px) { /* styles for viewports >= 320.01px */ }

However, in these situations, [range
context](#range-context)
queries (which are not limited to "\>=" and "\<=" comparisons) offer a
more appropriate solution:

 @media (width <= 320px) { /* styles for viewports <= 320px */ }
 @media (width > 320px) { /* styles for viewports > 320px */ }

"Discrete" type properties do not accept "min-" or "max-" prefixes.
Adding such a prefix to a "discrete" type [media
feature](#media-feature)
simply results in an unknown feature name.

For example, [(min-grid: 1)] is
invalid, because
[grid](#descdef-media-grid) is a "discrete" [media
feature](#media-feature), and
so doesn't accept the prefixes. (Even though the
[grid] [media
feature] appears to be numeric, as it accepts
the values [0] and [1].)

Attempting to evaluate a min/max prefixed [media
feature](#media-feature) in a
[boolean context](#boolean-context) is invalid and a syntax error.

### 2.5. Combining Media Features

Multiple [media features](#media-feature) can be combined together into a [media
condition]
using full boolean algebra (not, and, or).

- Any media feature can be negated by placing
 [not](#valdef-media-not) before it. For example, [not (color)] inverts
 the meaning of [(color)]---​since [(color)] matches a
 device with any kind of color display, [not (color)] matches a
 device *without* any kind of color display.

- Two or more media features can be chained together, such that the
 query is only true if *all* of the media features are true, by placing
 [and] between them. For example, [(width \< 600px) and (height
 \< 600px)] only matches devices whose screens are smaller than
 [600px] wide in both dimensions.

- Alternately, two or more media features can be chained together, such
 that the query is true if *any* of the media features are true, by
 placing [or] between them. For example, [(update: slow) or
 (hover: none)] matches if the device is slow to update the
 screen (such as an e-reader) *or* the primary pointing device has no
 hover capability, perhaps indicating that one should use a layout that
 displays more information rather than compactly hiding it until the
 user hovers.

- [Media conditions](#media-condition) can be grouped by wrapping them in parentheses
 [()] which can then be nested within a condition the same as a
 single media query. For example, [(not (color)) or (hover)] is
 true on devices that are monochrome and/or that have hover
 capabilities. If one instead wanted to query for a device that was
 monochrome and *didn't* have hover capabilities, it must instead be
 written as [not ((color) or (hover))] (or, equivalently, as
 [(not (color)) and (not (hover))]).

It is *invalid* to mix [and] and [or] and
[not](#valdef-media-not) at the same "level" of a media query. For example,
[(color) and (pointer) or (hover)] is illegal, as it's unclear
what was meant. Instead, parentheses can be used to group things using a
particular joining keyword, yielding either [(color) and ((pointer) or
(hover))] or [((color) and (pointer)) or (hover)]. These two
have very different meanings: if only [(hover)] is true, the first
one evaluates to false but the second evaluates to true.

## 3. Syntax

Informal descriptions of the media query syntax appear in the prose and
railroad diagrams in previous sections. The formal media query syntax is
described in this section, with the rule/property grammar syntax defined
in
[\[CSS-SYNTAX-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3")
and
[\[CSS-VALUES-4\]](#biblio-css-values-4 "CSS Values and Units Module Level 4").

To parse a [\<media-query-list\>] production, [parse a
comma-separated list of component
values](https://www.w3.org/TR/css-syntax-3/#parse-a-comma-separated-list-of-component-values), then parse each entry in the returned list as a
[\<media-query\>](#typedef-media-query). Its value is the list of
[\<media-query\>]s so
produced.

 This explicit definition of
[\<media-query-list\>](#typedef-media-query-list) parsing is necessary to make the
error-recovery behavior of [media query
lists](#media-query-list)
well-defined.

 This definition of
[\<media-query-list\>](#typedef-media-query-list) parsing intentionally accepts an
empty list.

 As per
[\[CSS-SYNTAX-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3"),
tokens are [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive).

 <media-query> = <media-condition>
 | [ not | only ]? <media-type> [ and <media-condition-without-or> ]?
 <media-type> = <ident>

 <media-condition> = <media-not> | <media-in-parens> [ <media-and>* | <media-or>* ]
 <media-condition-without-or> = <media-not> | <media-in-parens> <media-and>*
 <media-not> = not <media-in-parens>
 <media-and> = and <media-in-parens>
 <media-or> = or <media-in-parens>
 <media-in-parens> = ( <media-condition> ) | ( <media-feature> ) | <general-enclosed>

 <media-feature> = [ <mf-plain> | <mf-boolean> | <mf-range> ]
 <mf-plain> = <mf-name> : <mf-value>
 <mf-boolean> = <mf-name>
 <mf-range> = <mf-name> <mf-comparison> <mf-value>
 | <mf-value> <mf-comparison> <mf-name>
 | <mf-value> <mf-lt> <mf-name> <mf-lt> <mf-value>
 | <mf-value> <mf-gt> <mf-name> <mf-gt> <mf-value>
 <mf-name> = <ident>
 <mf-value> = <number> | <dimension> | <ident> | <ratio>
 <mf-lt> = '<' '='?
 <mf-gt> = '>' '='?
 <mf-eq> = '='
 <mf-comparison> = <mf-lt> | <mf-gt> | <mf-eq>

 <general-enclosed> = [ <function-token> <any-value>? ) ] | [ ( <any-value>? ) ]

The [\<media-type\>](#typedef-media-type) production does not include the
keywords [only](#valdef-media-only), [not](#valdef-media-not), [and], [or], and [layer].

 The exclusion of [layer] is because it would
otherwise be ambiguous when when used in the
`@import url(…) layer;` syntax for the sake of [cascade
layers](https://www.w3.org/TR/css-cascade-5/#cascade-layers). See
[\[CSS-CASCADE-5\]](#biblio-css-cascade-5 "CSS Cascading and Inheritance Level 5").

No whitespace is allowed between the "\<" or "\>"
[\<delim-token\>](https://www.w3.org/TR/css-syntax-3/#typedef-delim-token)s and the following "="
[\<delim-token\>], if it's
present.

 Whitespace is required between a
[not](#valdef-media-not), [and], or [or] keyword and the following
[(] character, because without it that would instead parse as a
[\<function-token\>](https://www.w3.org/TR/css-syntax-3/#typedef-function-token). This is not made explicitly invalid
because it's already covered by the above grammar. It's fine to have
whitespace between a [)] and a following keyword, however.

When parsing the
[\<media-in-parens\>](#typedef-media-in-parens) production, the
[\<general-enclosed\>](#typedef-general-enclosed) branch must only be chosen if the
input does not match either of the preceding branches.
[[\<general-enclosed\>](#typedef-general-enclosed) exists to allow for future expansion
of the grammar in a reasonably compatible way.]

### 3.1. Evaluating Media Queries

Each of the major subexpression of
[\<media-condition\>](#typedef-media-condition) or
[\<media-condition-without-or\>](#typedef-media-condition-without-or) is associated with a boolean result,
as follows:

[\<media-condition\>](#typedef-media-condition)\
[\<media-condition-without-or\>](#typedef-media-condition-without-or)
: The result is the result of the child subexpression.

[\<media-in-parens\>](#typedef-media-in-parens)
: The result is the result of the child term.

[\<media-not\>](#typedef-media-not)
: The result is the negation of the
 [\<media-in-parens\>](#typedef-media-in-parens) term. The negation of unknown is
 unknown.

[\<media-in-parens\>](#typedef-media-in-parens) [\<media-and\>](#typedef-media-and)\*
: The result is true if the
 [\<media-in-parens\>](#typedef-media-in-parens) child term and all of the
 [\<media-in-parens\>] children of the
 [\<media-and\>](#typedef-media-and) child terms are true, false if at
 least one of these
 [\<media-in-parens\>] terms are false, and unknown otherwise.

[\<media-in-parens\>](#typedef-media-in-parens) [\<media-or\>](#typedef-media-or)\*
: The result is false if the
 [\<media-in-parens\>](#typedef-media-in-parens) child term and all of the
 [\<media-in-parens\>] children of the
 [\<media-or\>](#typedef-media-or) child terms are false, true if at
 least one of these
 [\<media-in-parens\>] terms are true, and unknown otherwise.

[\<general-enclosed\>](#typedef-general-enclosed)

: The result is unknown.

 Authors must not use
 [\<general-enclosed\>](#typedef-general-enclosed) in their stylesheets. [It exists
 only for future-compatibility, so that new syntax additions do not
 invalidate too much of a
 [\<media-condition\>](#typedef-media-condition) in older user agents.]

[\<media-feature\>](#typedef-media-feature)
: The result is the result of evaluating the specified media feature.

If the result of any of the above productions is used in any context
that expects a two-valued boolean, "unknown" must be converted to
"false".

 This means that, for example, when a [media
query](#media-query) is used in
a
[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media) rule, if it resolves to "unknown" it's treated
as "false" and fails to match.

Media Queries use a three-value logic where terms can be "true",
"false", or "unknown". Specifically, it uses the [Kleene 3-valued
logic](http://en.wikipedia.org/wiki/Three-valued_logic#Kleene_and_Priest_logics).
In this logic, "unknown" means "either true or false, but we're not sure
which yet".

In general, an unknown value showing up in a formula will cause the
formula to be unknown as well, as substituting "true" for the unknown
will give the formula a different result than substituting "false". The
only way to eliminate an unknown value is to use it in a formula that
will give the same result whether the unknown is replaced with a true or
false value. This occurs when you have "false AND unknown" (evaluates to
false regardless) and "true OR unknown" (evaluates to true regardless).

This logic was adopted because
[\<general-enclosed\>](#typedef-general-enclosed) needs to be assigned a truth value.
In standard boolean logic, the only reasonable value is "false", but
this means that [not unknown(function)] is true, which can be
confusing and unwanted. Kleene's 3-valued logic ensures that unknown
things will prevent a [media query](#media-query) from matching, unless their value is irrelevant to the
final result.

### 3.2. Error Handling

A media query that does not match the grammar in the previous section
must be replaced by [not all] during parsing.

 Note that a grammar mismatch does **not** wipe out an
entire [media query list](#media-query-list), just the problematic [media
query](#media-query). The
parsing behavior defined above automatically recovers at the next
top-level comma.

@media (example, all,), speech { /* only applicable to speech devices */ }
 @media &test, speech { /* only applicable to speech devices */ }

Both of the above [media query
lists](#media-query-list)
are turned into [not all, speech] during parsing, which has the
same truth value as just
[speech](#valdef-media-speech).

Note that error-recovery only happens at the top-level of a [media
query](#media-query); anything
inside of an invalid parenthesized block will just get turned into [not
all] as a group. For example:

 @media (example, speech { /* rules for speech devices */ }

Because the parenthesized block is unclosed, it will contain the entire
rest of the stylesheet from that point (unless it happens to encounter
an unmatched ")" character somewhere in the stylesheet), and turn the
entire thing into a [not all] [media
query](#media-query).

An unknown
[\<media-type\>](#typedef-media-type) must be treated as not matching.

For example, the media query
[unknown] is false, as [unknown] is an unknown [media
type](#media-type).

But [not unknown] is true, as the
[not](#valdef-media-not) negates the false media type.

Remember that some keywords aren't
allowed as
[\<media-type\>](#typedef-media-type)s and cause parsing to fail entirely: the
media query [or and (color)] is turned into [not all] during
parsing, rather than just treating the [or] as an unknown [media
type](#media-type).

An unknown [\<mf-name\>](#typedef-mf-name) or
[\<mf-value\>](#typedef-mf-value), or a feature value which does not match
the value syntax for that [media
feature](#media-feature),
results in the value "unknown". A
[\<media-query\>](#typedef-media-query) whose value is "unknown" must be
replaced with [not all].

<link media="screen and (max-weight: 3kg) and (color), (color)"
 rel="stylesheet" href="example.css" />

As [max-weight] is an unknown [media
feature](#media-feature), this
[media query list](#media-query-list) is turned into [not all, (color)], which is
equivalent to just [(color)].

@media (min-orientation:portrait) { … }

The
[orientation](#descdef-media-orientation) feature does not accept prefixes, so
this is considered an unknown [media
feature](#media-feature), and
turned into [not all].

The media query
[(color:20example)] specifies an unknown value for the
[color](#descdef-media-color) media feature and is therefore turned into [not
all].

Note that [media queries](#media-query) are also subject to the parsing rules of the host
language. For example, take the following CSS snippet:

 @media test;,all { body { background:lime } }

The media query [test;,all] is, parsed by itself, equivalent to
[not all, all], which is always true. However, CSS's parsing rules
cause the
[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media) rule, and thus the [media
query](#media-query), to end at
the semicolon. The remainder of the text is treated as a style rule with
an invalid selector and contents.

## 4. Viewport/Page Characteristics Media Features

### 4.1. Width: the [width feature]
Name:

[width]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

[\<length\>](https://www.w3.org/TR/css-values-4/#length-value)

Type:

range

The [width](#descdef-media-width) media feature describes the width of the
targeted display area of the output device. For [continuous
media](#continuous-media),
this is the width of the viewport (as described by CSS2, section 9.1.1
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"))
including the size of a rendered scroll bar (if any). For [paged
media](#paged-media), this is the
width of the page box (as described by CSS2, section 13.2
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")).

[\<length\>](https://www.w3.org/TR/css-values-4/#length-value)s are interpreted according to [§ 1.3
Units](#units).

[width](#descdef-media-width) is [false in the negative
range](#false-in-the-negative-range).

For example, this media query
expresses that the style sheet is used on printed output wider than
25cm:

 <link rel="stylesheet" media="print and (min-width: 25cm)" href="http://…" />

This media query expresses that the
style sheet is used on devices with viewport (the part of the
screen/paper where the document is rendered) widths between 400 and 700
pixels:

 @media (400px <= width <= 700px) { … }

This media query expresses that style
sheet is used if the width of the viewport is greater than 20em.

 @media (min-width: 20em) { … }

The [em](https://www.w3.org/TR/css-values-4/#em) value is relative to the [initial
value](https://www.w3.org/TR/css-cascade-5/#initial-value) of
[font-size](https://www.w3.org/TR/css-fonts-4/#propdef-font-size).

### 4.2. Height: the [height feature]
Name:

[height]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

[\<length\>](https://www.w3.org/TR/css-values-4/#length-value)

Type:

range

The [height](#descdef-media-height) media feature describes the height of
the targeted display area of the output device. For [continuous
media](#continuous-media),
this is the height of the viewport including the size of a rendered
scroll bar (if any). For [paged
media](#paged-media), this is the
height of the page box.

[\<length\>](https://www.w3.org/TR/css-values-4/#length-value)s are interpreted according to [§ 1.3
Units](#units).

[height](#descdef-media-height) is [false in the negative
range](#false-in-the-negative-range).

### 4.3. Aspect-Ratio: the [aspect-ratio feature]
Name:

[aspect-ratio]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

[\<ratio\>](https://www.w3.org/TR/css-values-4/#ratio-value)

Type:

range

The
[aspect-ratio](#descdef-media-aspect-ratio) media feature is defined as the ratio of
the value of the
[width](#descdef-media-width) media feature to the value of the
[height](#descdef-media-height) media feature.

### 4.4. Orientation: the [orientation feature]
Name:

[orientation]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

portrait
[\|](https://www.w3.org/TR/css-values-4/#comb-one) landscape

Type:

discrete

[portrait]
: The
 [orientation](#descdef-media-orientation) media feature is
 [portrait](#valdef-media-orientation-portrait) when the value of the
 [height](#descdef-media-height) media feature is greater than or
 equal to the value of the
 [width](#descdef-media-width) media feature.

[landscape]
: Otherwise
 [orientation](#descdef-media-orientation) is
 [landscape](#valdef-media-orientation-landscape).

The following media query tests for
"portrait" orientation, like a phone held upright.

 @media (orientation:portrait) { … }

### 4.5. Block-Axis Overflow: the [overflow-block feature]
Name:

[overflow-block]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) scroll [\|] paged

Type:

discrete

The
[overflow-block](#descdef-media-overflow-block) media feature describes the behavior of
the device when content overflows the initial containing block in the
[block
axis](https://www.w3.org/TR/css-writing-modes-4/#block-axis).

[none]
: There is no affordance for overflow in the [block
 axis](https://www.w3.org/TR/css-writing-modes-4/#block-axis); any overflowing content is simply not displayed.
 Examples: billboards

[scroll]
: Overflowing content in the [block
 axis](https://www.w3.org/TR/css-writing-modes-4/#block-axis) is exposed by allowing users to scroll to it.
 Examples: computer screens

[paged]
: Content is broken up into discrete pages; content that overflows one
 page in the [block
 axis](https://www.w3.org/TR/css-writing-modes-4/#block-axis) is displayed on the following page. Examples:
 printers, ebook readers

Media that match
[none](#valdef-media-overflow-block-none) or
[scroll](#valdef-media-overflow-block-scroll) are said to be [continuous
media],
while those that match
[paged](#valdef-media-overflow-block-paged) are said to be [paged media]

 Additional values for this media feature may be added
in the future to describe classes of user agents with a hybrid behavior
combining aspects of
[continuous](#continuous-media) and [paged media](#paged-media). For example, the Presto layout engine (now
discontinued) shipped with a semi-paginated presentation-mode behavior
similar to [continuous] except that it honored forced page breaks.
Not knowing of any currently-shipping user agent with this type of
behavior, the Working Group has decided not to add such a value in this
level to avoid mischaracterizing any such user agent. Anyone
implementing a user agent not adequately described by any of the values
specified above is encouraged to contact the Working Group so that
extensions to this media feature may be considered.

### 4.6. Inline-Axis Overflow: the [overflow-inline feature]
Name:

[overflow-inline]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) scroll

Type:

discrete

The
[overflow-inline](#descdef-media-overflow-inline) media feature describes the behavior of
the device when content overflows the initial containing block in the
[inline
axis](https://www.w3.org/TR/css-writing-modes-4/#inline-axis).

[none]
: There is no affordance for overflow in the [inline
 axis](https://www.w3.org/TR/css-writing-modes-4/#inline-axis); any overflowing content is simply not displayed.

[scroll]
: Overflowing content in the [inline
 axis](https://www.w3.org/TR/css-writing-modes-4/#inline-axis) is exposed by allowing users to scroll to it.

 There are no known implementations of paged overflow of
inline-overflowing content, and the very concept doesn't seem to make
much sense, so there is intentionally no
[paged](#valdef-media-overflow-block-paged) value for
[overflow-inline](#descdef-media-overflow-inline).

### 4.7. Horizontal Viewport Segments: the [horizontal-viewport-segments feature]
Name:

[horizontal-viewport-segments]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

[\<integer\>](https://www.w3.org/TR/css-values-4/#integer-value)

Type:

range

The
[horizontal-viewport-segments](#descdef-media-horizontal-viewport-segments) media feature describes the number of
logical segments of the viewport in the horizontal direction.

The
[horizontal-viewport-segments](#descdef-media-horizontal-viewport-segments) media feature is [false in the negative
range](#false-in-the-negative-range).

When the viewport is split by one or more hardware features (such as a
fold or a hinge between separate displays) that act as a logical
divider, segments are the regions of the viewport that can be treated as
logically distinct by the page.

### 4.8. Vertical Viewport Segments: the [vertical-viewport-segments feature]
Name:

[vertical-viewport-segments]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

[\<integer\>](https://www.w3.org/TR/css-values-4/#integer-value)

Type:

range

The
[vertical-viewport-segments](#descdef-media-vertical-viewport-segments) media feature describes the number of
logical segments of the viewport in the vertical direction.

The
[vertical-viewport-segments](#descdef-media-vertical-viewport-segments) media feature is [false in the negative
range](#false-in-the-negative-range).

This media query detects a viewport
that has exactly two segments that are side-by-side.

 @media (horizontal-viewport-segments: 2) and (vertical-viewport-segments: 1) { … }

### 4.9. Display Modes: the [display-mode media feature]
Name:

[display-mode]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

application
[\|](https://www.w3.org/TR/css-values-4/#comb-one) fullscreen [\|] standalone
[\|] minimal-ui [\|] browser
[\|] picture-in-picture

Type:

discrete

The
[display-mode](#descdef-media-display-mode) media feature describes the modes in
which the current [browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#browsing-context) is currently being presented to the end user. In child
browsing contexts, the matching values must match those of the
[top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context).

Each value must match if and only if the conditions in its definition
are satisfied. Multiple values can match at the same time.

 For example, an [application
context](https://www.w3.org/TR/appmanifest/#dfn-application-context) displayed fullscreen matches both
[application](#valdef-media-display-mode-application) and
[fullscreen](#valdef-media-display-mode-fullscreen).

This feature is primarily used to determine which [display
mode](https://www.w3.org/TR/appmanifest/#dfn-display-mode) the user agent has applied to an [application
context](https://www.w3.org/TR/appmanifest/#dfn-application-context). As such, the values of this feature correspond to the
[display modes] defined in
[\[APPMANIFEST\]](#biblio-appmanifest "Web Application Manifest").
However, it can also be used in non-application contexts to determine
whether the viewport is in other modes, such as fullscreen or
picture-in-picture.

[application]
: The [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) is an [application
 context](https://www.w3.org/TR/appmanifest/#dfn-application-context).

[fullscreen]

: The browsing context is displayed with browser UI elements hidden
 and takes up the entirety of the available display area. The
 fullscreen context may have been caused by the
 [fullscreen](https://www.w3.org/TR/appmanifest/#dfn-fullscreen) display mode in the [application
 manifest](https://www.w3.org/TR/appmanifest/#dfn-manifest), by the
 [`requestFullscreen()`](https://fullscreen.spec.whatwg.org/#dom-element-requestfullscreen) method of the [Fullscreen
 API](#biblio-fullscreen "Fullscreen API Standard"),
 or through some other means (such as the user manually activating
 fullscreen mode using the user agent's built-in controls).

 Corresponds to the
 [fullscreen](https://www.w3.org/TR/appmanifest/#dfn-fullscreen) display mode.

[standalone]
: The
 [standalone](https://www.w3.org/TR/appmanifest/#dfn-standalone) display mode is in use. Only applicable in an
 [application
 context](https://www.w3.org/TR/appmanifest/#dfn-application-context).

[minimal-ui]
: The
 [minimal-ui](https://www.w3.org/TR/appmanifest/#dfn-minimal-ui) display mode is in use. Only applicable in an
 [application
 context](https://www.w3.org/TR/appmanifest/#dfn-application-context).

[browser]

: The browsing context is displayed using the platform-specific
 convention for opening hyperlinks in the user agent (e.g., in a
 browser tab or web browser window with controls such as an address
 bar). Only applicable in non-[application
 contexts](https://www.w3.org/TR/appmanifest/#dfn-application-context).

 Corresponds to the
 [browser](https://www.w3.org/TR/appmanifest/#dfn-browser) display mode.

[picture-in-picture]
: This mode allows users to continue consuming media while they
 interact with other sites or applications on their device. The
 browsing context is displayed in a floating and always-on-top
 window. A user agent may include other platform specific UI
 elements, such as \"back-to-tab\" and \"site information\" buttons
 or whatever is customary on the platform and user agent.

For example, the [application
manifest](https://www.w3.org/TR/appmanifest/#dfn-manifest) can request the
[standalone](https://www.w3.org/TR/appmanifest/#dfn-standalone) [display
mode](https://www.w3.org/TR/appmanifest/#dfn-display-mode) as follows:

```
{
 "display": "standalone"
}
```

This media query can be used to determine whether the user agent has
actually applied the
[standalone](https://www.w3.org/TR/appmanifest/#dfn-standalone) mode:

```
@media (display-mode: standalone) { … }
```

Note that other
[display-mode](#descdef-media-display-mode) values might also match at the same
time.

[fullscreen](https://www.w3.org/TR/appmanifest/#dfn-fullscreen) [display
mode](https://www.w3.org/TR/appmanifest/#dfn-display-mode) is distinct from the [Fullscreen
API](#biblio-fullscreen "Fullscreen API Standard").

The
[fullscreen](#valdef-media-display-mode-fullscreen) value for
[display-mode](#descdef-media-display-mode) is not directly related to the CSS
[:fullscreen](https://www.w3.org/TR/selectors-4/#selectordef-fullscreen)
[pseudo-class](https://www.w3.org/TR/selectors-4/#pseudo-class). The [:fullscreen] pseudo-class matches an element exclusively when that element is
put into the fullscreen element stack. However, a side effect of calling
the
[`requestFullscreen()`](https://fullscreen.spec.whatwg.org/#dom-element-requestfullscreen) method on an element using the [Fullscreen
API](#biblio-fullscreen "Fullscreen API Standard")
can be that the browser enters a fullscreen mode at the OS-level, in
which case both [:fullscreen] and
[(display-mode: fullscreen)] will match.

On some platforms, it is possible for
a user---​or a [Web Application
Manifest](#biblio-appmanifest "Web Application Manifest")---​to
put a web application into fullscreen without invoking the [Fullscreen
API](#biblio-fullscreen "Fullscreen API Standard").
When this happens, the
[:fullscreen](https://www.w3.org/TR/selectors-4/#selectordef-fullscreen) pseudo-class will not match, but [(display-mode:
fullscreen)] will match. This is exemplified in CSS code below:

```
/* applies when the viewport is fullscreen */
@media (display-mode: fullscreen) { … }

/* applies when an element is fullscreen */
#game:fullscreen { … }
```

 Additional values for this media feature may be added
in the future to match new [display
modes](https://www.w3.org/TR/appmanifest/#dfn-display-mode) added to
[\[APPMANIFEST\]](#biblio-appmanifest "Web Application Manifest").

## 5. Display Quality Media Features

### 5.1. Display Resolution: the [resolution feature]
Name:

[resolution]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

[\<resolution\>](https://www.w3.org/TR/css-values-4/#resolution-value)
[\|](https://www.w3.org/TR/css-values-4/#comb-one) infinite

Type:

range

The
[resolution](#descdef-media-resolution) media feature describes the resolution
of the output device, i.e. the density of the pixels, taking into
account the [page
zoom](https://www.w3.org/TR/cssom-view-1/#page-zoom) but assuming a [scale
factor](https://www.w3.org/TR/cssom-view-1/#scale-factor) of 1.0.

The
[resolution](#descdef-media-resolution) media feature is [false in the negative
range](#false-in-the-negative-range)

When querying media with non-square pixels,
[resolution](#descdef-media-resolution) queries the density in the vertical
dimension.

For printers, this corresponds to the screening resolution (the
resolution for printing dots of arbitrary color). Printers might have a
different resolution for grayscale printing.

For output mediums that have no physical constraints on resolution (such
as outputting to vector graphics), this feature must match the
[infinite] value. For the
purpose of evaluating this media feature in the [range
context](#range-context),
[infinite](#valdef-media-resolution-infinite) must be treated as larger than any possible
[\<resolution\>](https://www.w3.org/TR/css-values-4/#resolution-value). (That is, a query like [(resolution
\> 1000dpi)] will be true for an
[infinite] media.)

This media query simply detects
"high-resolution" screens (those with a hardware pixel to CSS
[px](https://www.w3.org/TR/css-values-4/#px) ratio of at least 2):

 @media (resolution >= 2dppx)

For example, this media query
expresses that a style sheet is used on devices with resolution greater
than 300 dots per CSS
[in](https://www.w3.org/TR/css-values-4/#in):

 @media print and (min-resolution: 300dpi) { … }

This media query is equivalent, but uses the CSS
[cm](https://www.w3.org/TR/css-values-4/#cm) unit:

 @media print and (min-resolution: 118dpcm) { … }

[\<resolution\>](https://www.w3.org/TR/css-values-4/#resolution-value) does not refer to the number of
device pixels per physical length unit, but the number of device pixels
per css unit. This mapping is done by the user agent, so it is always
known to the user agent.

If the user agent either has no knowledge of the geometry of physical
pixels, or knows about the geometry physical pixels and they are (close
enough to) square, it would not map a different number of device pixels
per css pixels along each axis, and the would therefore be no difference
between the vertical and horizontal resolution.

Otherwise, if the UA chooses to map a different number along each axis,
this would be to respond to physical pixels not being square either. How
the UA comes to this knowledge is out of scope, but having enough
information to take this decision, it can invert the mapping should the
device be rotated 90 degrees.

### 5.2. Display Type: the [scan feature]
Name:

[scan]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

interlace
[\|](https://www.w3.org/TR/css-values-4/#comb-one) progressive

Type:

discrete

The [scan](#descdef-media-scan) media feature describes the scanning process of
some output devices.

[interlace]

: CRT and some types of plasma TV screens used "interlaced" rendering,
 where video frames alternated between specifying only the "even"
 lines on the screen and only the "odd" lines, exploiting various
 automatic mental image-correction abilities to produce smooth
 motion. This allowed them to simulate a higher FPS broadcast at half
 the bandwidth cost.

 When displaying on interlaced screens, authors should avoid very
 fast movement across the screen to avoid "combing", and should
 ensure that details on the screen are wider than [1px] to
 avoid
 ["twitter"](https://en.wikipedia.org/wiki/Interlaced_video#Interline_twitter).

[progressive]

: A screen using "progressive" rendering displays each screen fully,
 and needs no special treatment.

 Most modern screens, and all computer screens, use progressive
 rendering.

For example, the "feet" of letters in
serif fonts are very small features that can provoke "twitter" on
interlaced devices. The
[scan](#descdef-media-scan) media feature can be used to detect this, and use
an alternative font with less chance of "twitter":

 @media (scan: interlace) { body { font-family: sans-serif; } }

 At the time of writing, all known implementations match
`scan: progressive` rather than `scan: interlace`.

### 5.3. Detecting Console Displays: the [grid feature]
Name:

[grid]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

[\<mq-boolean\>](#typedef-mq-boolean)

Type:

discrete

The [grid](#descdef-media-grid) media feature is used to query whether the output
device is grid or bitmap. If the output device is grid-based (e.g., a
"tty" terminal, or a phone display with only one fixed font), the value
will be 1. Otherwise, the value will be 0.

The [\<mq-boolean\>] value type is an
[\<integer\>](https://www.w3.org/TR/css-values-4/#integer-value) with the value [0] or
[1]. Any other integer value is invalid. [Note that [-0] is
always equivalent to [0] in CSS, and so is also accepted as a
valid [\<mq-boolean\>](#typedef-mq-boolean) value.]

 The
[\<mq-boolean\>](#typedef-mq-boolean) type exists only for legacy purposes. If
this feature were being designed today, it would instead use proper
named keywords for its values.

Here is an example that detects a
narrow console screen:

 @media (grid) and (max-width: 15em) { … }

 At the time of writing, all known implementations match
`grid: 0` rather than `grid: 1`.

### 5.4. Display Update Frequency: the [update feature]
Name:

[update]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) slow [\|] fast

Type:

discrete

The [update](#descdef-media-update) media feature is used to query the
ability of the output device to modify the appearance of content once it
has been rendered. It accepts the following values:

[none]
: Once it has been rendered, the layout can no longer be updated.
 Example: documents printed on paper.

[slow]
: The layout may change dynamically according to the usual rules of
 CSS, but the output device is not able to render or display changes
 quickly enough for them to be perceived as a smooth animation.
 Example: E-ink screens or severely under-powered devices.

[fast]
: The layout may change dynamically according to the usual rules of
 CSS, and the output device is not unusually constrained in speed, so
 regularly-updating things like CSS Animations can be used. Example:
 computer screens.

For example, if a page styles its
links to only add underlines on hover, it may want to always display
underlines when printed:

 @media (update) {
 a { text-decoration: none; }
 a:hover, a:focus { text-decoration: underline; }
 }
 /* In non-updating UAs, the links get their default underline at all times. */

### 5.5. Detecting the display technology: the [environment-blending feature]
Name:

[environment-blending]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

opaque
[\|](https://www.w3.org/TR/css-values-4/#comb-one) additive [\|] subtractive

Type:

discrete

The
[environment-blending](#descdef-media-environment-blending) media feature is used to query the
characteristics of the user's display so the author can adjust the style
of the document. An author might choose to adjust the visuals and/or
layout of the page depending on the display technology to increase the
appeal or improve legibility.

The following values are valid:

[opaque]
: The document is rendered on an opaque medium, such as a traditional
 monitor or paper. Black is dark and white is 100% light.

[additive]

: The display blends the colors of the canvas with the real world
 using additive mixing. Black is fully transparent and white is 100%
 light.

 For example: a head-up display in a car.

[subtractive]

: The display blends the colors of the canvas with the real world
 using subtractive mixing. White is fully transparent and dark colors
 have the most contrast.

 For example: an LCD display embedded in a bathroom mirror.

Is there a need for the
[subtractive](#valdef-media-environment-blending-subtractive) value?

body { background-color: white; }
 p { color: black; }

 @media(environment-blending: additive) {
 body { background-color: black; }
 p { color: white; font-size: 16px; font-weight: 1000; }
 }

## 6. Color Media Features

### 6.1. Color Depth: the [color feature]
Name:

[color]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

[\<integer\>](https://www.w3.org/TR/css-values-4/#integer-value)

Type:

range

The [color](#descdef-media-color) media feature describes the number of
bits per color component of the output device. If the device is not a
color device, the value is zero.

[color](#descdef-media-color) is [false in the negative
range](#false-in-the-negative-range).

For example, these two media queries
express that a style sheet applies to all color devices:

 @media (color) { … }
 @media (min-color: 1) { … }

This media query expresses that a
style sheet applies to color devices with at least 8 bits per color
component:

 @media (color >= 8) { … }

If different color components are represented by different number of
bits, the smallest number is used.

For instance, if an 8-bit color system
represents the red component with 3 bits, the green component with 3
bits, and the blue component with 2 bits, the
[color](#descdef-media-color) media feature will have a value of 2.

In a device with indexed colors, the minimum number of bits per color
component in the lookup table is used.

 The described functionality is only able to describe
color capabilities at a superficial level.
[color-gamut](#descdef-media-color-gamut), is generally more relevant to authors'
needs. If further functionality is required, RFC2879
[\[RFC2879\]](#biblio-rfc2879 "Content Feature Schema for Internet Fax (V2)")
provides more specific media features which may be supported at a later
stage.

### 6.2. Paletted Color Screens: the [color-index feature]
Name:

[color-index]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

[\<integer\>](https://www.w3.org/TR/css-values-4/#integer-value)

Type:

range

The
[color-index](#descdef-media-color-index) media feature describes the number of
entries in the color lookup table of the output device. If the device
does not use a color lookup table, the value is zero.

[color-index](#descdef-media-color-index) is [false in the negative
range](#false-in-the-negative-range).

For example, here are two ways to
express that a style sheet applies to all color index devices:

 @media (color-index) { … }
 @media (color-index >= 1) { … }

This media query expresses that a
style sheet applies to a color index device with 256 or more entries:

 <?xml-stylesheet media="(min-color-index: 256)"
 href="http://www.example.com/…" ?>

### 6.3. Monochrome Screens: the [monochrome feature]
Name:

[monochrome]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

[\<integer\>](https://www.w3.org/TR/css-values-4/#integer-value)

Type:

range

The
[monochrome](#descdef-media-monochrome) media feature describes the number of
bits per pixel in a monochrome frame buffer. If the device is not a
monochrome device, the output device value will be 0.

[monochrome](#descdef-media-monochrome) is [false in the negative
range](#false-in-the-negative-range).

For example, this is how to express
that a style sheet applies to all monochrome devices:

 @media (monochrome) { … }

Express that a style sheet applies to
monochrome devices with more than 2 bits per pixels:

 @media (monochrome >= 2) { … }

Express that there is one style sheet
for color pages and another for monochrome:

 <link rel="stylesheet" media="print and (color)" href="http://…" />
 <link rel="stylesheet" media="print and (monochrome)" href="http://…" />

### 6.4. Color Display Quality: the [color-gamut feature]
Name:

[color-gamut]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

srgb
[\|](https://www.w3.org/TR/css-values-4/#comb-one) p3 [\|] rec2020

Type:

discrete

The
[color-gamut](#descdef-media-color-gamut) media feature describes the approximate
range of colors that are supported by the UA and output device. That is,
if the UA receives content with colors in the specified space it can
cause the output device to render the appropriate color, or something
appropriately close enough.

 The query uses approximate ranges for a few reasons.
Firstly, there are a lot of differences in display hardware. For
example, a device might claim to support \"Rec. 2020\", but actually
renders a significantly lower range of the full gamut. Secondly, there
are a lot of different color ranges that different devices support, and
enumerating them all would be tedious. In most cases the author does not
need to know the exact capabilities of the display, just whether it is
better than sRGB, or significantly better than sRGB. That way they can
serve appropriate images, tagged with color profiles, to the user.

[srgb]

: The UA and output device can support approximately the sRGB gamut or
 more.

 It is expected that the vast majority of color
 displays will be able to return true to a query of this type.

[p3]

: The UA and output device can support approximately the gamut
 specified by the Display P3
 [\[Display-P3\]](#biblio-display-p3 "Display P3")
 Color Space or more.

 The
 [p3](#valdef-media-color-gamut-p3) gamut is larger than and includes the
 [srgb](#valdef-media-color-gamut-srgb) gamut.

[rec2020]

: The UA and output device can support approximately the gamut
 specified by the ITU-R Recommendation BT.2020 Color Space or more.

 The
 [rec2020](#valdef-media-color-gamut-rec2020) gamut is larger than and includes the
 [p3](#valdef-media-color-gamut-p3) gamut.

The following table lists the primary colors of these color spaces in
terms of their color space chromaticity coordinates, as defined in
[\[COLORIMETRY\]](#biblio-colorimetry "Colorimetry, Fourth Edition. CIE 015:2018").

Color Space

White Point

Primaries

Red

Green

Blue

x~W~

y~W~

x~R~

y~R~

x~G~

y~G~

x~B~

y~B~

srgb

0.3127

0.3290

0.640

0.330

0.300

0.600

0.150

0.060

p3

0.3127

0.3290

0.680

0.320

0.265

0.690

0.150

0.060

rec2020

0.3127

0.3290

0.708

0.292

0.170

0.797

0.131

0.046

 The table above does not contains enough information to
fully describe the color spaces, but is sufficient to determine whether
an output device approximately covers their respective gamuts. See
[\[SRGB\]](#biblio-srgb "Multimedia systems and equipment - Colour measurement and management - Part 2-1: Colour management - Default RGB colour space - sRGB")
for more information on sRGB,
[\[Display-P3\]](#biblio-display-p3 "Display P3")
for more information on Display P3, and
[\[ITU-R-BT-2020-2\]](#biblio-itu-r-bt-2020-2 "Parameter values for ultra-high definition television systems for production and international programme exchange")
for more information on ITU-R Recommendation BT.2020.

For example, this media query applies
when the display supports colors in the range of Display P3:

```
@media (color-gamut: p3) { … }
```

 An output device can return true for multiple values of
this media feature, if its full output gamut is large enough, or one
gamut is a subset of another supported gamut. As a result, this feature
is best used in an \"ascending\" fashion---​set a base value when
[(color-gamut: srgb)] is true, then override it if [(color-gamut:
p3)] is true, etc.

 Some output devices, such as monochrome displays,
cannot support even the
[srgb](#valdef-media-color-gamut-srgb) gamut. To test for these devices, you can use
this feature in a negated boolean-context fashion: [not
(color-gamut)].

### 6.5. Dynamic Range: the [dynamic-range feature]
Name:

[dynamic-range]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

standard
[\|](https://www.w3.org/TR/css-values-4/#comb-one) high

Type:

discrete

[dynamic-range](#descdef-media-dynamic-range) represents the combination of max
brightness, color depth, and contrast ratio that are supported by the
user agent and output device.

[high]

: The user agent and the output device fulfill all of the following
 criteria:

 - they support a [high peak
 brightness](#peak-brightness-high-peak-brightness)

 - they support a [high contrast
 ratio](#contrast-ratio-high-contrast-ratio)

 - the color depth is greater than 24 bit or 8 bit per color
 component of RGB

 Some devices have high dynamic range capabilities
 that are not always on, and that need to be activated (sometimes
 programmatically, sometimes by the user, sometimes based on the
 content). This media feature does not test whether such a mode is
 active, just whether the device is capable of high dynamic range
 visuals.

[standard]
: This value matches on any visual device, and not on devices lacking
 visual capabilities.

 More than one value of this media feature can match
simultaneously: a user agent matching
[high](#valdef-media-dynamic-range-high) will also match
[standard](#valdef-media-dynamic-range-standard).

#### 6.5.1. Determining contrast and brightness of display

[Peak brightness] refers to how bright the brightest point a light-emitting
device such as an LCD screen can produce, or in the case of a light
reflective device such as paper or e-ink, the point at which it least
absorbs light.

 Some devices can only produce their [peak
brightness](#peak-brightness)
for brief periods of time or on a small portion of their surface at any
given time.

The [contrast ratio] is the ratio of the luminance of the brightest color to that
of the darkest color that the system is capable of producing.

This specification does not define precise ways by which these qualities
can be measured; it also lets the user agent determine what counts as a
[high] [contrast ratio](#contrast-ratio) and as a [high] [peak
brightness](#peak-brightness). User agents must nonetheless attempt to conform to the
following intent: a device capable of [high peak
brightness](#peak-brightness-high-peak-brightness) can display "brighter than white" highlights, and a
simultaneous ability to do so while also presenting deep blacks (rather
than an overall bright but washed out image) is indicative of a [high
contrast
ratio](#contrast-ratio-high-contrast-ratio).

 The determination for
[dynamic-range](#descdef-media-dynamic-range) and
[video-dynamic-range](#descdef-media-video-dynamic-range) will be vary depending on the user
agent, but is expected to have broadly dependable semantics.

### 6.6. Detecting inverted colors on the display: the [inverted-colors feature]
Name:

[inverted-colors]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) inverted

Type:

discrete

The
[inverted-colors](#descdef-media-inverted-colors) media feature indicates whether the
content is displayed normally, or whether colors have been inverted.

 This is an indication that the user agent or underlying
operating system has forcibly inverted all colors, not a request to do
so. This is sometimes provided as a simple accessibility feature,
allowing users to switch between light-on-dark and dark-on-light text.
However, this has unpleasant side effects, such as inverting pictures,
or turning shadows into highlights, which reduce the readability of the
content.

[none]
: Colors are displayed normally.

[inverted]

: All pixels within the displayed area have been inverted.

 This value must not match if the user agent has done some kind of
 content aware inversion such as one that preserves the images.

 This is because the goal of this media feature is
 to enable authors to mitigate the undesirable effects of the non
 content aware approach that invert *all* the pixels. If the author
 were to take counter measures even in the content-aware cases, their
 counter measures and the UA's would be at risk of cancelling each
 other.

Depending on their style sheet,
authors may wish to invert images and videos:

```
@media (inverted-colors) {
 img:not(picture > img), picture, video {
 filter: invert(100%);
 }
}
```

Authors may also invert images injected via CSS (such as backgrounds),
or disable shadows:

```
@media (inverted-colors) {
 * {
 text-shadow: none !important;
 box-shadow: none !important;
 }
}
```

## 7. Interaction Media Features

The "interaction" media features reflect various aspects of how the user
interacts with the page.

Typical examples of devices matching combinations of
[pointer](#descdef-media-pointer) and
[hover](#descdef-media-hover):

[pointer: none](#descdef-media-pointer)

[pointer:
coarse](#descdef-media-pointer)

[pointer: fine](#descdef-media-pointer)

[hover: none](#descdef-media-hover)

keyboard-only controls, sequential/spatial (d-pad) focus navigation

smartphones, touch screens

basic stylus digitizers (Cintiq, Wacom, etc)

[hover: hover](#descdef-media-hover)

Nintendo Wii controller, Kinect

mouse, touch pad, advanced stylus digitizers (Surface, Samsung Note,
Wacom Intuos Pro, etc)

The [pointer](#descdef-media-pointer) and
[hover](#descdef-media-hover) features relate to the characteristics of the
"primary" pointing device, while
[any-pointer](#descdef-media-any-pointer) and
[any-hover](#descdef-media-any-hover) can be used to query the properties of
all potentially available pointing devices.

 While this specification does not define how user
agents should decide what the "primary" pointing device is, the
expectation is that user agents should make this determination by
combining knowledge about the device/environment they are running on,
the number and type of pointing devices available, and a notion of which
of these is generally and/or currently being used. In situations where
the primary input mechanism for a device is not a pointing device, but
there is a secondary -- and less frequently used -- input that is a
pointing devices, the user agent may decide to treat the non-pointing
device as the primary (resulting in \'pointer: none\'). user agents may
also decide to dynamically change what type of pointing device is deemed
to be primary, in response to changes in the user environment or in the
way the user is interacting with the UA.

 The
[pointer](#descdef-media-pointer),
[hover](#descdef-media-hover),
[any-pointer](#descdef-media-any-pointer) and
[any-hover](#descdef-media-any-hover) features only relate to the
characteristics, or the complete absence, of pointing devices, and can
not be used to detect the presence of non-pointing device input
mechanisms such as keyboards. Authors should take into account the
potential presence of non-pointing device inputs, regardless of which
values are matched when querying these features.

While [pointer](#descdef-media-pointer) and
[hover](#descdef-media-hover) can be used to design the main style and
interaction mode of the page to suit the primary input mechanism (based
on the characteristics, or complete absence, of the primary pointing
device), authors should strongly consider using
[any-pointer](#descdef-media-any-pointer) and
[any-hover](#descdef-media-any-hover) to take into account all possible types
of pointing devices that have been detected.

### 7.1. Pointing Device Quality: the [pointer feature]
Name:

[pointer]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) coarse [\|] fine

Type:

discrete

The [pointer](#descdef-media-pointer) media feature is used to query the
presence and accuracy of a pointing device such as a mouse. If multiple
pointing devices are present, the
[pointer] media feature must
reflect the characteristics of the "primary" pointing device, as
determined by the user agent. (To query the capabilities of *any*
available pointing devices, see the
[any-pointer](#descdef-media-any-pointer) media feature.)

[none]
: The primary input mechanism of the device does not include a
 pointing device.

[coarse]
: The primary input mechanism of the device includes a pointing device
 of limited accuracy. Examples include touchscreens and
 motion-detection sensors (like the Kinect peripheral for the Xbox.)

[fine]
: The primary input mechanism of the device includes an accurate
 pointing device. Examples include mice, touchpads, and drawing
 styluses.

Both
[coarse](#valdef-media-pointer-coarse) and
[fine](#valdef-media-pointer-fine) indicate the presence of a pointing device, but
differ in accuracy. A pointing device with which it would be difficult
or impossible to reliably pick one of several small adjacent targets at
a zoom factor of 1 would qualify as
[coarse]. Changing the zoom
level does not affect the value of this media feature.

 As the UA may provide the user with the ability to
zoom, or as secondary pointing devices may have a different accuracy,
the user may be able to perform accurate clicks even if the value of
this media feature is
[coarse](#valdef-media-pointer-coarse). This media feature does not indicate that the
user will never be able to click accurately, only that it is
inconvenient for them to do so. Authors are expected to react to a value
of [coarse] by designing
pages that do not rely on accurate clicking to be operated.

For accessibility reasons, even on devices whose pointing device can be
described as
[fine](#valdef-media-pointer-fine), the UA may give a value of
[coarse](#valdef-media-pointer-coarse) or
[none](#valdef-media-pointer-none) to this media query, to indicate that the user
has difficulties manipulating the pointing device accurately or at all.
In addition, even if the primary pointing device has
[fine] pointing accuracy,
there may be additional [coarse] pointing devices available to the user. Authors may wish to query
the
[any-pointer](#descdef-media-any-pointer) media feature to take these other
[coarse] potential pointing
devices into account.

/* Make radio buttons and check boxes larger if we have an inaccurate primary pointing device */
 @media (pointer:coarse) {
 input[type="checkbox"], input[type="radio"] {
 min-width:30px;
 min-height:40px;
 background:transparent;
 }
 }

### 7.2. Hover Capability: the [hover feature]
Name:

[hover]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) hover

Type:

discrete

The [hover](#descdef-media-hover) media feature is used to query the
user's ability to hover over elements on the page with the primary
pointing device. If a device has multiple pointing devices, the
[hover] media feature must
reflect the characteristics of the "primary" pointing device, as
determined by the user agent. (To query the capabilities of *any*
available pointing devices, see the
[any-hover](#descdef-media-any-hover) media feature.)

[none]

: Indicates that the primary pointing device can't hover, or that
 there is no pointing device. Examples include touchscreens and
 screens that use a basic drawing stylus.

 Pointing devices that can hover, but for which doing so is
 inconvenient and not part of the normal way they are used, also
 match this value. For example, a touchscreen where a long press is
 treated as hovering would match [hover:
 none](#descdef-media-hover).

[hover]
: Indicates that the primary pointing device can easily hover over
 parts of the page. Examples include mice and devices that physically
 point at the screen, like the Nintendo Wii controller.

For example, on a touch screen device
that can also be controlled by an optional mouse, the
[hover](#descdef-media-hover) [media
feature](#media-feature)
should match [hover: none], as the
primary pointing device (the touch screen) does not allow the user to
hover.

However, despite this, the optional mouse does allow users to hover.
Authors should therefore be careful not to assume that the
[:hover](https://www.w3.org/TR/selectors-4/#hover-pseudo)
[pseudo-class](https://www.w3.org/TR/selectors-4/#pseudo-class) will never match on a device where \'hover:none\' is
true, but they should design layouts that do not depend on hovering to
be fully usable.

For accessibility reasons, even on devices that do support hovering, the
UA may give a value of [hover:
none](#descdef-media-hover) to this media query, to opt into layouts that work
well without hovering. Note that even if the primary input mechanism has
\'hover: hover\' capability, there may be additional input mechanisms
available to the user that do not provide hover capabilities.

/* Only use a hover-activated drop down menu on devices that can conveniently hover. */
 @media (hover) {
 .menu > li {display:inline-block;}
 .menu ul {display:none; position:absolute;}
 .menu li:hover ul {display:block; list-style:none; padding:0;}
 /* ... */
 }

### 7.3. All Available Interaction Capabilities: the [any-pointer and [any-hover](#descdef-media-any-hover) features]
Name:

[any-pointer]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) coarse [\|] fine

Type:

discrete

Name:

[any-hover]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) hover

Type:

discrete

The
[any-pointer](#descdef-media-any-pointer) and
[any-hover](#descdef-media-any-hover) media features are identical to the
[pointer](#descdef-media-pointer) and
[hover](#descdef-media-hover) media features, but they correspond to the union
of capabilities of all the pointing devices available to the user. In
the case of [any-pointer], more than one of the values can match, if different pointing
devices have different characteristics.

[any-pointer](#descdef-media-any-pointer) and
[any-hover](#descdef-media-any-hover) must only match [none] if *all* of
the pointing devices would match
[none](#valdef-media-pointer-none) for the corresponding query, or there are no
pointing devices at all.

[any-pointer](#descdef-media-any-pointer) is used to query the presence and
accuracy of pointing devices. It does not take into account any
additional non-pointing device inputs, and can not be used to test for
the presence of other input mechanisms, such as d-pads or keyboard-only
controls, that don't move an on-screen pointer. \'any-pointer:none\'
will only evaluate to true if there are no pointing devices at all
present.

On a traditional desktop environment
with a mouse and keyboard, \'any-pointer:none\' will be false (due to
the presence of the mouse), even though a non-pointer input (the
keyboard) is also present.

\'any-hover:none\' will only evaluate to true if there are no pointing
devices, or if all the pointing devices present lack hover capabilities.
As such, it should be understood as a query to test if any hover-capable
pointing devices are present, rather than whether or not any of the
pointing devices is hover-incapable. The latter scenario can currently
not be determined using
[any-hover](#descdef-media-any-hover) or any other interaction media feature.
Additionally, it does not take into account any non-pointing device
inputs, such as d-pads or keyboard-only controls, which by their very
nature are also not hover-capable.

On a touch-enabled laptop with a mouse
and a touchscreen, \'any-hover:none\' will evaluate to false (due to the
presence of the hover-capable mouse), even though a non-hover-capable
pointing device (the touchscreen) is also present. It is currently not
possible to provide different styles for cases where different pointing
devices have different hover capabilities.

Designing a page that relies on hovering or accurate pointing only
because
[any-hover](#descdef-media-any-hover) or
[any-pointer](#descdef-media-any-pointer) indicate that at least one of the
available input mechanisms has these capabilities is likely to result in
a poor experience. However, authors may use this information to inform
their decision about the style and functionality they wish to provide
based on any additional pointing devices that are available to the user.

A number of smart TVs come with a way
to control an on-screen cursor, but it is often fairly basic controller
which is difficult to operate accurately.

A browser in such a smart TV would have
[coarse](#valdef-media-pointer-coarse) as the value of both
[pointer](#descdef-media-pointer) and
[any-pointer](#descdef-media-any-pointer), allowing authors to provide a layout
with large and easy to reach click targets.

The user may also have paired a Bluetooth mouse with the TV, and
occasionally use it for extra convenience, but this mouse is not the
main way the TV is operated.
[pointer](#descdef-media-pointer) still matches
[coarse](#valdef-media-pointer-coarse), while
[any-pointer](#descdef-media-any-pointer) now both matches
[coarse] and
[fine](#valdef-media-pointer-fine).

Switching to small click targets based on the fact that [(any-pointer:
fine)] is now true would not be appropriate. It would not only
surprise the user by providing an experience out of line with what they
expect on a TV, but may also be quite inconvenient: the mouse, not being
the primary way to control the TV, may be out of reach, hidden under one
of the cushions on the sofa\...

By contrast, consider scrolling on the same TV. Scrollbars are difficult
to manipulate without an accurate pointing device. Having prepared an
alternative way to indicate that there is more content to be seen based
on [(pointer: coarse)] being true, an author may want to still
show the scrollbars in addition if [(any-pointer: fine)] is true,
or to hide them altogether to reduce visual clutter if [(any-pointer:
fine)] is false.

### 7.4. Detecting UA-supplied navigation controls: the [nav-controls feature]
Name:

[nav-controls]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) back

Type:

discrete

The
[nav-controls](#descdef-media-nav-controls) media features allows authors to know
whether the user agent is providing [obviously
discoverable](#obviously-discoverable) navigation controls as part of its user interface.

 Traditional browsers typically do provide such controls
and web pages typically have not needed to concern themselves with that,
but in some contexts, web applications are run through so-called
web-views, which do not always feature a full-fledged user interface. It
is thus useful for authors to know what is being supplied by the user
agent, so that they can consider whether they need to provide an easily
discovered alternative.

In this context, [obviously discoverable] refers to controls which are
either directly visible in the user interface, such as buttons, or some
other form of control which is typical of the user interface of that
device and trivially identifiable by the user. In the case of visual
user interfaces, this would typically a *visible* control, although it
could be something else in the case of an audio or tactile user
interface. Importantly, this is not about keyboard shortcuts or
gestures; as convenient as these can be, these are not obviously
discoverable by just looking at (in the case of a visual UI) the user
agent.

The following values are valid:

[none]
: The user agent does not have any [obviously
 discoverable](#obviously-discoverable) navigation controls, and in particular none that
 cause the user agent to move back to the page's previous [session
 history
 entry](https://html.spec.whatwg.org/multipage/browsing-the-web.html#session-history-entry).

[back]
: The user agent provides navigation controls, including at least an
 [obviously
 discoverable](#obviously-discoverable) control causing the user agent to move back to the
 page's previous [session history
 entry](https://html.spec.whatwg.org/multipage/browsing-the-web.html#session-history-entry)
 (typically, a "back" button).

Authors can include a back button in
their web application, and then conditionally hide it if the user agent
already offers that functionality:

```
@media (nav-controls: back) {
 #back-button {
 display: none;
 }
}
```

As this media feature can be used in a [boolean
context](#boolean-context),
the same example can be written with shorter syntax:

```
@media (nav-controls) {
 #back-button {
 display: none;
 }
}
```

 Theoretically, the two are not strictly equivalent, as
there could be new values in a future extension of this media feature
other than
[back](#valdef-media-nav-controls-back) that could match when
[back] doesn't. In that
case, using the
[nav-controls](#descdef-media-nav-controls) feature in a boolean context could be
misleading. However, given that navigation back is arguably the most
fundamental navigation operation, the CSS Working Group does not
anticipate user interfaces with explicit navigation controls but no back
button, so this problem is not expected to occur in practice.

Whether [obviously
discoverable](#obviously-discoverable) controls are active does not impact the evaluation of
this media feature.

If there is no previous [session
history
entry](https://html.spec.whatwg.org/multipage/browsing-the-web.html#session-history-entry)
for the page, a user agent with a "back" button could toggle it to a
disabled state that cannot be interacted with until there actually is
history that can be navigated back to. In such a case,
`@media (nav-controls: back) { … }` would still be expected
to match.

## 8. Video Prefixed Features

Some user agents, including many TVs, render video and graphics in two
separate \"planes\" (bi-plane) with distinct screen characteristics. A
set of video-prefixed features is provided to describe the video plane.

Any bi-plane implementation must return values based on the video plane
for the following features:
[video-color-gamut](#descdef-media-video-color-gamut);
[video-dynamic-range](#descdef-media-video-dynamic-range). All other features must return values
based on the graphics plane.

Non bi-plane implementations must return the same values for
video-prefixed features and their non-prefixed counterparts.

### 8.1. Video Color Display Quality: the [video-color-gamut feature]
Name:

[video-color-gamut]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

srgb
[\|](https://www.w3.org/TR/css-values-4/#comb-one) p3 [\|] rec2020

Type:

discrete

The
[video-color-gamut](#descdef-media-video-color-gamut) media feature describes the approximate
range of colors that are supported by the UA and output device's video
plane. That is, if the UA receives content with colors in the specified
space it can cause the output device to render the appropriate color, or
something appropriately close enough.

Value and color space definitions are the same as
[color-gamut](#descdef-media-color-gamut).

### 8.2. Video Dynamic Range: the [video-dynamic-range feature]
Name:

[video-dynamic-range]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

standard
[\|](https://www.w3.org/TR/css-values-4/#comb-one) high

Type:

discrete

[video-dynamic-range](#descdef-media-video-dynamic-range) represents the combination of max
brightness, color depth, and contrast ratio that are supported by the UA
and output device's video plane.

Supported values are the same as [dynamic-range](#dynamic-range).

## 9. Scripting Media Features

### 9.1. Scripting Support: the [scripting feature]
Name:

[scripting]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) initial-only [\|] enabled

Type:

discrete

The
[scripting](#descdef-media-scripting) media feature is used to query whether
scripting languages, such as JavaScript, are supported on the current
document.

[enabled]
: Indicates that the user agent supports scripting of the page, and
 that scripting in the current document is enabled for the lifetime
 of the document.

[initial-only]

: Indicates that the user agent supports scripting of the page, and
 that scripting in the current document is enabled during the initial
 page load, but is not supported afterwards. Examples are printed
 pages, or pre-rendering network proxies that render a page on a
 server and send a nearly-static version of the page to the user.

 (#issue-168bd904) Should there be an explicit minimum
 threshold to meet before a UA is allowed to claim
 [initial-only](#valdef-media-scripting-initial-only)? Having one would mean authors would know
 what they can depend on, and could tailor their scripts accordingly.
 On the other hand, pinpointing that threshold is difficult: if it is
 set too low, the scripting facilities that authors can depend on may
 be to constrained to be practical, even though actual UAs may
 potentially all support significantly more. But trying to set it
 higher may cause us to exclude UAs that do support scripting at
 loading time, but restrict it in some cases based on complex
 heuristics. For instance, conservative definitions likely include at
 least running all inline scripts and firing the DOMContentLoaded
 event. But it does not seem useful for authors to constrain
 themselves to this if most (or maybe all)
 [initial-only]
 UAs also load external scripts (including [async] and
 [defer]) and fire the load event. On the other hand, requiring
 external scripts to be loaded and the load event to be fired could
 exclude UAs like Opera mini, which typically do run them, but may
 decide not to based on timeouts and other heuristics. [\[Issue
 #503\]](https://github.com/w3c/csswg-drafts/issues/503)

[none]
: Indicates that the user agent will not run scripts for this
 document; either it doesn't support a scripting language, or the
 support isn't active for the current document.

Some user agents have the ability to turn off scripting support on a per
script basis or per domain basis, allowing some, but not all, scripts to
run in a particular document. The
[scripting](#descdef-media-scripting) media feature does not allow fine
grained detection of which script is allowed to run. In this scenario,
the value of the [scripting] media feature should be
[enabled](#valdef-media-scripting-enabled) or
[initial-only](#valdef-media-scripting-initial-only) if scripts originating on the same domain as the
document are allowed to run, and
[none](#valdef-media-scripting-none) otherwise.

 A future level of CSS may extend this media feature to
allow fine-grained detection of which script is allowed to run.

## 10. Custom Media Queries

When designing documents that use media queries, the same media query
may be used in multiple places, such as to qualify multiple
[\@import](https://www.w3.org/TR/css-cascade-5/#at-ruledef-import) statements. Repeating the same media query
multiple times is an editing hazard; an author making a change must edit
every copy in the same way, or suffer from difficult-to-find bugs in
their CSS.

To help ameliorate this, this specification defines a method of defining
[custom media queries](#custom-media-query), which are simply-named aliases for longer and more
complex media queries. In this way, a media query used in multiple
places can instead be assigned to a [custom media
query], which can be used everywhere, and
editing the media query requires touching only one line of code.

A [custom media query] is defined with the
[\@custom-media](#at-ruledef-custom-media) rule:

``` prod
@custom-media = @custom-media <extension-name> [ <media-query-list> | true | false ] ;
```

The
[\<extension-name\>](https://drafts.csswg.org/css-extensions-1/#typedef-extension-name) can then be used in a [media
feature](#media-feature). It
**must** be used in a [boolean
context](#boolean-context);
using them in a normal or [range
context](#range-context) is a
syntax error. If a
[\<media-query-list\>](#typedef-media-query-list) is given, the [custom media
query](#custom-media-query) evaluates to true if the
[\<media-query-list\>]
it represents evaluates to true, and false otherwise. If
[true] or
[false] is given, the
[custom media query] evaluates to true or
false, respectively.

The [custom media
query](#custom-media-query) is evaluated logically, not treated as a textual
substitution. Take the following code snippet for instance:

```
/* --modern targets modern devices that support color or hover */
@custom-media --modern (color), (hover);

@media (--modern) and (width > 1024px) {
 .a { color: green; }
}
```

It is equivalent to:

```
@media ((color) or (hover)) and (width > 1024px) {
 .a { color: green; }
}
```

Processing it as if it meant the following would be incorrect:

```
@media (color), (hover) and (width > 1024px) {
 .a { color: green; }
}
```

[\@custom-media](#at-ruledef-custom-media) rule can refer to other [custom media
queries](#custom-media-query). However, loops are forbidden, and a [custom media
query] must not be defined in terms of
itself or of another [custom media query]
that directly or indirectly refers to it. Any such attempt of defining a
[custom media query] with a circular
dependency must cause all the [custom media
queries] in the loop to fail to be
defined.

If multiple
[\@custom-media](#at-ruledef-custom-media) rules declare the same
[\<extension-name\>](https://drafts.csswg.org/css-extensions-1/#typedef-extension-name), the truth value is based on the last
one alone, ignoring all previous declarations of the same
[\<extension-name\>].

 For error handling purposes, an undefined [media
feature](#media-feature) is
different from a [media feature] that
evaluates to false. See [Media Queries 4 § 3.2 Error
Handling](https://www.w3.org/TR/mediaqueries-4/#error-handling) for
details.

For example, if a responsive site uses
a particular breakpoint in several places, it can alias that with a
reasonable name:

 @custom-media --narrow-window (max-width: 30em);

 @media (--narrow-window) {
 /* narrow window styles */
 }
 @media (--narrow-window) and (script) {
 /* special styles for when script is allowed */
 }
 /* etc */

### 10.1. Script-based Custom Media Queries

Define a map of names to values for JS.
Values can be either a MediaQueryList object or a boolean, in which case
it's treated identically to the above, or can be a number or a string,
in which case it's treated like a normal MQ, and can use the normal or
range context syntax. Like:

 <script>
 CSS.customMedia.set('--foo', 5);
 </script>
 <style>
 @media (_foo: 5) { ... }
 @media (_foo < 10) { ... }
 </style>

## 11. CSSOM

The
[`CSSCustomMediaRule`](#csscustommediarule) interface represents a
[\@custom-media](#at-ruledef-custom-media) rule.

```
typedef (MediaList or boolean) CustomMediaQuery;

[Exposed=Window]
interface CSSCustomMediaRule : CSSRule {
 readonly attribute CSSOMString name;
 readonly attribute CustomMediaQuery query;
};
```

[`name`], of type [CSSOMString](https://www.w3.org/TR/cssom-1/#cssomstring), readonly
: Returns a CSSOMString representing the
 [\<extension-name\>](https://drafts.csswg.org/css-extensions-1/#typedef-extension-name) of the
 [\@custom-media](#at-ruledef-custom-media) rule.

[`query`], of type [CustomMediaQuery](#typedefdef-custommediaquery), readonly
: Represents the value of the [custom media
 query](#custom-media-query). The returned
 [`CustomMediaQuery`](#typedefdef-custommediaquery) will be one of the following:
 - A
 [`MediaList`](https://www.w3.org/TR/cssom-1/#medialist) object, if the rule was defined with a
 [\<media-query-list\>](#typedef-media-query-list).
 - The boolean true, if the rule was defined with the value
 [true](#valdef-custom-media-true).
 - The boolean false, if the rule was defined with the value
 [false](#valdef-custom-media-false).

## 12. User Preference Media Features

### 12.1. Detecting the desire for less motion on the page: the [prefers-reduced-motion feature]
Name:

[prefers-reduced-motion]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

no-preference
[\|](https://www.w3.org/TR/css-values-4/#comb-one) reduce

Type:

discrete

The
[prefers-reduced-motion](#descdef-media-prefers-reduced-motion) media feature is used to detect if the
user has requested the system minimize the amount of non-essential
motion it uses.

[no-preference]
: Indicates that the user has made no preference known to the system.
 This keyword value evaluates as false in the [boolean
 context](#boolean-context).

[reduce]
: Indicates that user has notified the system that they prefer an
 interface that removes or replaces the types of motion-based
 animation that either trigger discomfort for those with vestibular
 motion sensitivity, or distraction for those with attention
 deficits.

### 12.2. Detecting the desire for reduced transparency on the page: the [prefers-reduced-transparency feature]
Name:

[prefers-reduced-transparency]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

no-preference
[\|](https://www.w3.org/TR/css-values-4/#comb-one) reduce

Type:

discrete

The
[prefers-reduced-transparency](#descdef-media-prefers-reduced-transparency) media feature is used to detect if the
user has requested the system minimize the amount of transparent or
translucent layer effects it uses.

[no-preference]
: Indicates that the user has made no preference known to the system.
 This keyword value evaluates as false in the [boolean
 context](#boolean-context).

[reduce]
: Indicates that user has notified the system that they prefer an
 interface that minimizes the amount of transparent or translucent
 layer effects.

How does this interact with preferences
around e.g. pattern fills and backgrounds? They're not about
transparency, but they also interfere with shape recognition.

### 12.3. Detecting the desire for increased or decreased color contrast from elements on the page: the [prefers-contrast feature]
Name:

[prefers-contrast]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

no-preference
[\|](https://www.w3.org/TR/css-values-4/#comb-one) less [\|] more
[\|] custom

Type:

discrete

The
[prefers-contrast](#descdef-media-prefers-contrast) media feature is used to detect if the
user has requested more or less contrast in the page. This could be
responded to, for example, by adjusting the contrast ratio between
adjacent colors, or by changing how much elements stand out visually,
such as by adjusting their borders.

[no-preference]
: Indicates that the user has made no preference known to the system.
 This keyword value evaluates as false in the [boolean
 context](#boolean-context).

[less]
: Indicates that user has notified the system that they prefer an
 interface that has a lower level of contrast.

[more]
: Indicates that user has notified the system that they prefer an
 interface that has a higher level of contrast.

[custom]

: Indicates that the user has indicated wanting a specific set of
 colors to be used, but the contrast implied by these particular
 colors is such that neither
 [more](#valdef-media-prefers-contrast-more) nor
 [less](#valdef-media-prefers-contrast-less) match.

 This value will match for users of [forced colors
 mode](https://www.w3.org/TR/css-color-adjust-1/#forced-colors-mode) who have picked a palette that is neither
 particularly high nor low contrast. See [§ 12.4 Detecting Forced
 Colors Mode: the forced-colors feature](#forced-colors).

 :::
 (#example-fd710249) A user calling for [cyan text over
 a rust background]{style="background: #B64000; color: #00FFFF;"} is
 not---​at least in terms of luminosity---​expressing a need for
 particularly high or low contrast, but this is not a lack of a
 preference either.
 :::

Note: Authors can respond to specific user preferences for more or less
contrast using [prefers-contrast:
more](#descdef-media-prefers-contrast) or [prefers-contrast:
less], as appropriate.

Using an unqualified `@media (prefers-contrast) { … }` to apply high contrast styles is incorrect and user-hostile,
as it would also impose high contrast styles to people who have
requested the exact opposite.

However, it is also common to reduce visual clutter and color complexity
in response to both high and low contrast preferences. In that case, it
is appropriate to use `@media (prefers-contrast) { … }` without specifying
[more](#valdef-media-prefers-contrast-more) or
[less](#valdef-media-prefers-contrast-less), to do things like replacing background images
with plain colors, turning off decorative gradients, or replacing border
images or box shadows with simple solid borders. As [prefers-contrast:
custom](#descdef-media-prefers-contrast)---​like [prefers-contrast:
more] or
[prefers-contrast: less]---​evaluates to true in a [boolean
context](#boolean-context),
such simplifications would also benefit users of [forced colors
mode](https://www.w3.org/TR/css-color-adjust-1/#forced-colors-mode), even when their colors of choice do not result in a
particularly high or low contrast. This is desirable, as the reduced
palette enforced by [forced colors mode]
calls for some visual simplification of the page.

Preference for more or less contrast
may arise from a variety of different situations. Here are some
examples:

- Many users have difficulty reading text that has a small difference in
 contrast to the text background and would prefer a larger contrast.
- People suffering from migraine may find strongly contrasting pages to
 be visually painful and would prefer a low contrast.
- Some people with dyslexia find high contrast text hard to read, as
 they feel that the letters shine / sparkle as if backlit by too bright
 a light, and find low contrast to be more comfortable.
- Environmental factors may also lead a user to prefer more or less
 contrast. See also [§ 12.7 Automatic handling of User
 Preferences](#auto-pref).

This list should be refined and
expanded.

### 12.4. Detecting Forced Colors Mode: the [forced-colors feature]
Name:

[forced-colors]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) active

Type:

discrete

[active]

: Indicates that [forced colors
 mode](https://www.w3.org/TR/css-color-adjust-1/#forced-colors-mode) is active: the user agent enforces a user-chosen
 limited color palette on the page, The UA will provide the color
 palette to authors through the CSS system color keywords. See [CSS
 Color Adjustment 1 § 3 Forced Color
 Palettes](https://www.w3.org/TR/css-color-adjust-1/#forced) for
 details.

 ::: advisement
 This does *not* necessarily indicate a preference for more contrast.
 The colors have been forcibly adjusted to match the preference of
 the user, but that preference can be for less or more contrast, or
 some other arrangement that is neither particularly low or high
 contrast.
 :::

 In addition to [forced-colors:
 active](#descdef-media-forced-colors), the user agent must also match one of
 [prefers-contrast:
 more](#descdef-media-prefers-contrast) or [prefers-contrast:
 less] if it can
 determine that the forced color palette chosen by the user has a
 particularly high or low contrast, and must make [prefers-contrast:
 custom] match
 otherwise.

 Similarly, if the forced color palette chosen by the user fits
 within one of the color schemes described by
 [prefers-color-scheme](#descdef-media-prefers-color-scheme), the corresponding value must also
 match.

[none]
: [Forced colors
 mode](https://www.w3.org/TR/css-color-adjust-1/#forced-colors-mode) is not active.

When [forced colors
mode](https://www.w3.org/TR/css-color-adjust-1/#forced-colors-mode) is active, the only colors that are available to the
author are [system
colors](https://www.w3.org/TR/css-color-4/#css-system-colors). The user agent will enforce this limited palette
automatically, but the author may choose a different way of using these
colors, using the [forced-colors] media feature to detect when it
is appropriate to do so.

### 12.5. Detecting the desire for light or dark color schemes: the [prefers-color-scheme feature]
Name:

[prefers-color-scheme]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

light
[\|](https://www.w3.org/TR/css-values-4/#comb-one) dark

Type:

discrete

The
[prefers-color-scheme](#descdef-media-prefers-color-scheme) media feature reflects the user's desire
that the page use a
[light](https://www.w3.org/TR/css-color-adjust-1/#light-color-scheme) or [dark color
scheme](https://www.w3.org/TR/css-color-adjust-1/#dark-color-scheme).

[light]
: Indicates that the [page color
 scheme](https://drafts.csswg.org/css-color-adjust-1/#page-color-scheme) is a [light color
 scheme](https://www.w3.org/TR/css-color-adjust-1/#light-color-scheme) (dark text on light background).

[dark]
: Indicates that the [page color
 scheme](https://drafts.csswg.org/css-color-adjust-1/#page-color-scheme) is a [dark color
 scheme](https://www.w3.org/TR/css-color-adjust-1/#dark-color-scheme) (light text on dark background).

 The values for this feature might be expanded in the
future (to express preferences for other types of color schemes like
\"sepia\"). As such, the most future-friendly way to use this media
feature is by negation such as [(prefers-color-scheme: dark)] and
[(not (prefers-color-scheme: dark))], which ensures that new
values fall into at least one of the styling blocks.

The method by which the user expresses their preference can vary. It
might be a system-wide setting exposed by the Operating System, or a
setting controlled by the user agent.

 User preferences can also vary by medium. For example,
a user may prefer dark themes on a glowing screen, but light themes when
printing (to save ink and/or because inked text on blank paper prints
better than blank letterforms knocked out of an inked background). UAs
are expected to take such variances into consideration so that
[prefers-color-scheme](#descdef-media-prefers-color-scheme) reflects preferences appropriate to the
medium rather than preferences taken out of context.

#### 12.5.1. Detecting Specifically the User's Preferred Color Scheme: the [ua-color-scheme feature]
Name:

[ua-color-scheme]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

light
[\|](https://www.w3.org/TR/css-values-4/#comb-one) dark

Type:

discrete

The
[prefers-color-scheme](#descdef-media-prefers-color-scheme) media query reflects the [page color
scheme](https://drafts.csswg.org/css-color-adjust-1/#page-color-scheme), which will generally reflect a user's [preferred color
scheme](https://www.w3.org/TR/css-color-adjust-1/#preferred-color-scheme), but might not if the page overrides that. (This is
often done at the user's behest, with a page-specific light/dark-mode
toggle to implement a user's desire for a particular page or origin to
render light or dark, regardless of their *general* color scheme
preference.) Also, embedded documents such as iframes automatically
match the color scheme of the parent document rather than the user's
preference.

There are some use-cases for nevertheless detecting the user's *actual*
general preference, and the
[ua-color-scheme](#descdef-media-ua-color-scheme) [media
feature](#media-feature)
reflects that, ignoring the effect of anything on the page, the effects
of being an embedded document, etc.

[light]

: Indicates that the user's [preferred color
 scheme](https://www.w3.org/TR/css-color-adjust-1/#preferred-color-scheme) is a [light color
 scheme](https://www.w3.org/TR/css-color-adjust-1/#light-color-scheme) (dark text on light background), or that the user
 has no preference.

 (If the user has not expressed an active preference, they will also
 receive the \"web default\" of a light theme).

[dark]
: Indicates that the user's [preferred color
 scheme](https://www.w3.org/TR/css-color-adjust-1/#preferred-color-scheme) is a [dark color
 scheme](https://www.w3.org/TR/css-color-adjust-1/#dark-color-scheme) (light text on dark background).

This feature, like the other [prefers-\*] features, previously had
a [no-preference] value to indicate a user not expressing an
active preference. However, user agents converged on expressing the
\"default\" behavior as a [light color
scheme](https://www.w3.org/TR/css-color-adjust-1/#light-color-scheme) preference, and never matching [no-preference].

If a future user agent wishes to expose a difference between \"no
preference\" and \"really wants a light display\", please contact the
CSSWG to discuss this.

The CSSWG has not officially decided on
a name for this feature, and so it might change in the future.

### 12.6. Detecting the desire for reduced data usage when loading a page: the [prefers-reduced-data feature]
This feature may be an undesired source
of fingerprinting, with a bias towards low income with limited data.
[\[Issue #10076\]](https://github.com/w3c/csswg-drafts/issues/10076)

Name:

[prefers-reduced-data]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

no-preference
[\|](https://www.w3.org/TR/css-values-4/#comb-one) reduce

Type:

discrete

The
[prefers-reduced-data](#descdef-media-prefers-reduced-data) media feature is used to detect if the
user has a preference for being served alternate content that uses less
data for the page to be rendered.

[no-preference]
: Indicates that the user has made no preference known to the system.
 This keyword value evaluates as false in the [boolean
 context](#boolean-context).

[reduce]
: Indicates that user has expressed the preference for lightweight
 alternate content.

The method by which the user expresses their preference can vary. It
might be a system-wide setting exposed by the Operating System, or a
setting controlled by the user agent. User agents may consider setting
this based on the same user or system preference as they use to set the
[Save-Data](https://wicg.github.io/savedata/) HTTP request header.

 User agents are encouraged to use their own user
centered discretion when handling a toggle of this value, whether it's
toggled post page load or during page load. A primary goal could be to
not download unnecessary data. Consider, if a page is already loaded
with high quality assets and the user changes their preference to
reduced, the page could perhaps not update the document right away,
instead wait for an explicit page reload invocation from the user.
Consider also, if a page is taking a long time to download and a user
changes their preference to reduced, this could be a nice point to save
the user's bandwidth and immediately switch to downloading smaller
assets. User agents are free to implement logic as they see appropriate
for situations like these, and also ought to be aware the situations
exist.

For example, a site could honour the
preference of a user who has turned on data-saving mode by serving a
smaller image.

 .image {
 background-image: url("images/heavy.jpg");
 }

 @media (prefers-reduced-data: reduce) {
 /* Save-Data: On */
 .image {
 background-image: url("images/light.jpg");
 }
 }

### 12.7. Automatic handling of User Preferences

User agents may have explicit settings allowing users to indicate their
preferences or may make the determination based on settings in the
underlying operating system. User agents may also automatically infer
the preferences of the user based on knowledge about the device, the
environment, etc. In such case, it is recommended that they also offer a
way for users to opt out of or override the automatically determined
preferences.

In addition to allowing users to
explicitly choose between a preference for a
[light](#valdef-media-prefers-color-scheme-light) or
[dark](#valdef-media-prefers-color-scheme-dark) color scheme, a user agent could have a mode
where the determination is automatically made based on the current time,
expressing a preference for
[dark] between
sunset and dawn.

Depending on the type of display used,
changes in the ambient light level may make the reading experience
difficult or uncomfortable.

For instance, liquid crystal displays can be washed out and very hard to
read in brightly lit environments. A device with such a screen and with
an ambient light sensor could automatically switch
[prefers-contrast](#descdef-media-prefers-contrast) to
[more](#valdef-media-prefers-contrast-more) when it detects conditions that would make the
screen difficult to read. A user agent on a device with an e-ink display
would not make the same adjustment, as such displays remain readable in
bright daylight.

In the opposite situation, user agents running of device with a
light-emitting screen (LCD, OLED, etc.) and an ambient light sensor
could automatically switch
[prefers-contrast](#descdef-media-prefers-contrast) to
[less](#valdef-media-prefers-contrast-less) and
[prefers-color-scheme](#descdef-media-prefers-color-scheme) to
[dark](#valdef-media-prefers-color-scheme-dark) when used in a dim environment where excessive
contrast and brightness would be distracting or uncomfortable to the
reader.

A user agent could automatically
switch between [prefers-reduced-data:
no-preference](#descdef-media-prefers-reduced-data) and
[reduce](#valdef-media-prefers-reduced-data-reduce) depending on whether the network connection in
use allows for unlimited data or is on a metered plan.

## 13. Script Control of User Preferences

It is common for website authors to want to respect the user's system
preferences while also allowing those preferences to be overridden. To
help with this, this specification defines a way for authors to override
the [§ 12 User Preference Media Features](#mf-user-preferences) using
the
[`PreferenceManager`](#preferencemanager) interface.

This override allows the preference to integrate with various platform
features that are affected by these preferences.

### [13.1. ][ Extensions to the [`Navigator`](https://html.spec.whatwg.org/multipage/system-state.html#navigator) interface]
```
[Exposed=Window, SecureContext]
partial interface Navigator {
 [SameObject] readonly attribute PreferenceManager preferences;
};
```

#### 13.1.1. [`preferences` attribute]
When getting the
[`preferences`](#dom-navigator-preferences) attribute always return the same instance of the
[`PreferenceManager`](#preferencemanager) object.

#### 13.1.2. [`PreferenceManager` interface]
```
[Exposed=Window, SecureContext]
interface PreferenceManager {
 readonly attribute PreferenceObject colorScheme;
 readonly attribute PreferenceObject contrast;
 readonly attribute PreferenceObject reducedMotion;
 readonly attribute PreferenceObject reducedTransparency;
 readonly attribute PreferenceObject reducedData;
};
```

#### 13.1.3. [`colorScheme` attribute]
The
[`colorScheme`](#dom-preferencemanager-colorscheme) attribute is a
[`PreferenceObject`](#preferenceobject) used to override the user's preference for the color
scheme of the site. This is modeled after the [§ 12.5 Detecting the
desire for light or dark color schemes: the prefers-color-scheme
feature](#prefers-color-scheme).

The [get valid values for colorScheme] algorithm, when invoked,
must run these steps:

1. Let `validValues` be a new empty
 [sequence](https://webidl.spec.whatwg.org/#idl-sequence).

2. Add \"light\" to `validValues`.

3. Add \"dark\" to `validValues`.

4. Return `validValues`.

If an override is set for this preference:

- The user agent MUST use this override for the [§ 12.5 Detecting the
 desire for light or dark color schemes: the prefers-color-scheme
 feature](#prefers-color-scheme) in all stylesheets applied to an
 [origin](https://dom.spec.whatwg.org/#concept-document-origin) including the UA style sheet.

- The user agent MUST also use this override when queried via
 \`matchMedia()\` from [CSSOM View § 4 Extensions to the Window
 Interface](https://www.w3.org/TR/cssom-view-1/#extensions-to-the-window-interface).

- The user agent MUST also use this override when calculating the [used
 color
 scheme](https://www.w3.org/TR/css-color-adjust-1/#used-color-scheme).

- The user agent MUST also use this override when sending [User
 Preference Media Features Client Hints Headers § 2.5
 Sec-CH-Prefers-Color-Scheme](https://wicg.github.io/user-preference-media-features-headers/#sec-ch-prefers-color-scheme).

- The user agent MUST also use this override for any UA features that
 are normally affected by [§ 12.5 Detecting the desire for light or
 dark color schemes: the prefers-color-scheme
 feature](#prefers-color-scheme).

#### 13.1.4. [`contrast` attribute]
The
[`contrast`](#dom-preferencemanager-contrast) attribute is a
[`PreferenceObject`](#preferenceobject) used to override the user's preference for the contrast
of the site. This is modeled after the [§ 12.3 Detecting the desire for
increased or decreased color contrast from elements on the page: the
prefers-contrast feature](#prefers-contrast).

The [get valid values for contrast] algorithm, when invoked, must
run these steps:

1. Let `validValues` be a new empty
 [sequence](https://webidl.spec.whatwg.org/#idl-sequence).

2. Add
 [more](#valdef-media-prefers-contrast-more) to `validValues`.

3. Add
 [less](#valdef-media-prefers-contrast-less) to `validValues`.

4. Add
 [no-preference](#valdef-media-prefers-contrast-no-preference) to `validValues`.

5. Return `validValues`.

If an override is set for this preference:

- The user agent MUST use this override for the [§ 12.3 Detecting the
 desire for increased or decreased color contrast from elements on the
 page: the prefers-contrast feature](#prefers-contrast) in all
 stylesheets applied to an
 [origin](https://dom.spec.whatwg.org/#concept-document-origin) including the UA style sheet.

- The user agent MUST also use this override when queried via
 \`matchMedia()\` from [CSSOM View § 4 Extensions to the Window
 Interface](https://www.w3.org/TR/cssom-view-1/#extensions-to-the-window-interface).

- The user agent MUST also use this override when sending [User
 Preference Media Features Client Hints Headers § 2.3
 Sec-CH-Prefers-Contrast](https://wicg.github.io/user-preference-media-features-headers/#sec-ch-prefers-contrast).

- The user agent MUST also use this override for any UA features that
 are normally affected by [§ 12.3 Detecting the desire for increased or
 decreased color contrast from elements on the page: the
 prefers-contrast feature](#prefers-contrast).

 Unlike the media feature this preference is NOT able to
be set to
[custom](#valdef-media-prefers-contrast-custom) as this is tightly coupled to the [§ 12.4
Detecting Forced Colors Mode: the forced-colors
feature](#forced-colors).

#### 13.1.5. [`reducedMotion` attribute]
The
[`reducedMotion`](#dom-preferencemanager-reducedmotion) attribute is a
[`PreferenceObject`](#preferenceobject) used to override the user's preference for reduced
motion on the site. This is modeled after the [§ 12.1 Detecting the
desire for less motion on the page: the prefers-reduced-motion
feature](#prefers-reduced-motion).

The [get valid values for
reducedMotion] algorithm, when invoked, must run these
steps:

1. Let `validValues` be a new empty
 [sequence](https://webidl.spec.whatwg.org/#idl-sequence).

2. Add
 [reduce](#valdef-media-prefers-reduced-motion-reduce) to `validValues`.

3. Add
 [no-preference](#valdef-media-prefers-reduced-motion-no-preference) to `validValues`.

4. Return `validValues`.

If an override is set for this preference:

- The user agent MUST use this override for the [§ 12.1 Detecting the
 desire for less motion on the page: the prefers-reduced-motion
 feature](#prefers-reduced-motion) in all stylesheets applied to an
 [origin](https://dom.spec.whatwg.org/#concept-document-origin) including the UA style sheet.

- The user agent MUST also use this override when queried via
 \`matchMedia()\` from [CSSOM View § 4 Extensions to the Window
 Interface](https://www.w3.org/TR/cssom-view-1/#extensions-to-the-window-interface).

- The user agent MUST also use this override when sending [User
 Preference Media Features Client Hints Headers § 2.1
 Sec-CH-Prefers-Reduced-Motion](https://wicg.github.io/user-preference-media-features-headers/#sec-ch-prefers-reduced-motion).

- The user agent MUST also use this override for any UA features that
 are normally affected by [§ 12.1 Detecting the desire for less motion
 on the page: the prefers-reduced-motion
 feature](#prefers-reduced-motion).

 An example of a UA feature that is affected by this
preference could be disabling smooth scrolling, or pausing marquee
elements.

#### 13.1.6. [`reducedTransparency` attribute]
The
[`reducedTransparency`](#dom-preferencemanager-reducedtransparency) attribute is a
[`PreferenceObject`](#preferenceobject) used to override the user's preference for reduced
transparency on the site. This is modeled after the [§ 12.2 Detecting
the desire for reduced transparency on the page: the
prefers-reduced-transparency feature](#prefers-reduced-transparency).

The [get valid values for
reducedTransparency] algorithm, when invoked, must
run these steps:

1. Let `validValues` be a new empty
 [sequence](https://webidl.spec.whatwg.org/#idl-sequence).

2. Add
 [reduce](#valdef-media-prefers-reduced-transparency-reduce) to `validValues`.

3. Add
 [no-preference](#valdef-media-prefers-reduced-transparency-no-preference) to `validValues`.

4. Return `validValues`.

If an override is set for this preference:

- The user agent MUST use this override for the [§ 12.2 Detecting the
 desire for reduced transparency on the page: the
 prefers-reduced-transparency feature](#prefers-reduced-transparency)
 in all stylesheets applied to an
 [origin](https://dom.spec.whatwg.org/#concept-document-origin) including the UA style sheet.

- The user agent MUST also use this override when queried via
 \`matchMedia()\` from [CSSOM View § 4 Extensions to the Window
 Interface](https://www.w3.org/TR/cssom-view-1/#extensions-to-the-window-interface).

- The user agent MUST also use this override when sending [User
 Preference Media Features Client Hints Headers § 2.2
 Sec-CH-Prefers-Reduced-Transparency](https://wicg.github.io/user-preference-media-features-headers/#sec-ch-prefers-reduced-transparency).

- The user agent MUST also use this override for any UA features that
 are normally affected by [§ 12.2 Detecting the desire for reduced
 transparency on the page: the prefers-reduced-transparency
 feature](#prefers-reduced-transparency).

#### 13.1.7. [`reducedData` attribute]
The
[`reducedData`](#dom-preferencemanager-reduceddata) attribute is a
[`PreferenceObject`](#preferenceobject) used to override the user's preference for reduced data
usage on the site. This is modeled after the [§ 12.6 Detecting the
desire for reduced data usage when loading a page: the
prefers-reduced-data feature](#prefers-reduced-data).

The [get valid values for reducedData] algorithm, when invoked,
must run these steps:

1. Let `validValues` be a new empty
 [sequence](https://webidl.spec.whatwg.org/#idl-sequence).

2. Add
 [reduce](#valdef-media-prefers-reduced-data-reduce) to `validValues`.

3. Add
 [no-preference](#valdef-media-prefers-reduced-data-no-preference) to `validValues`.

4. Return `validValues`.

If an override is set for this preference:

- The user agent MUST use this override for the [§ 12.6 Detecting the
 desire for reduced data usage when loading a page: the
 prefers-reduced-data feature](#prefers-reduced-data) in all
 stylesheets applied to an
 [origin](https://dom.spec.whatwg.org/#concept-document-origin) including the UA style sheet.

- The user agent MUST also use this override when queried via
 \`matchMedia()\` from [CSSOM View § 4 Extensions to the Window
 Interface](https://www.w3.org/TR/cssom-view-1/#extensions-to-the-window-interface).

- The user agent MUST also use this override when sending [Save Data API
 § 2.1.1 Save-Data Request Header
 Field](https://wicg.github.io/savedata/#save-data-request-header-field).

- The user agent MUST also use this override when calculating the [Save
 Data API § 2.1 saveData
 attribute](https://wicg.github.io/savedata/#savedata-attribute).

- The user agent MUST also use this override for any UA features that
 are normally affected by [§ 12.6 Detecting the desire for reduced data
 usage when loading a page: the prefers-reduced-data
 feature](#prefers-reduced-data).

#### 13.1.8. [`PreferenceObject` interface]
```
[Exposed=Window, SecureContext]
interface PreferenceObject : EventTarget {
 readonly attribute DOMString? override;
 readonly attribute DOMString value;
 readonly attribute FrozenArray<DOMString> validValues;

 undefined clearOverride();
 Promise<undefined> requestOverride(DOMString? value);

 attribute EventHandler onchange;
};
```

##### 13.1.8.1. [`override` attribute]
The [`override`]
attribute, when accessed, must run these steps:

1. Let `preference` be the preference object's name.

2. Let `override` be null.

3. If an override for `preference` exists, set
 `override` to the value of that override.

4. Return `override`.

##### 13.1.8.2. [`value` attribute]
The [`value`] attribute,
when accessed, must run these steps:

1. Let `preference` be the preference object's name.

2. Let `value` be null.

3. If an override for `preference` exists, set
 `value` to the value of that override.

4. If `value` is null, set `value` to the UA
 value of the preference.

5. Return `value`.

##### 13.1.8.3. [`validValues` attribute]
The [`validValues`]
attribute, when accessed, must run these steps:

1. Let `preference` be the preference object's name.
2. Switch on `preference`:

 \"[`colorScheme`](#dom-preferencemanager-colorscheme)\"
 : Return the result of [get valid values for
 colorScheme](#get-valid-values-for-colorscheme).

 \"[`contrast`](#dom-preferencemanager-contrast)\"
 : Return the result of [get valid values for
 contrast](#get-valid-values-for-contrast).

 \"[`reducedMotion`](#dom-preferencemanager-reducedmotion)\"
 : Return the result of [get valid values for
 reducedMotion](#get-valid-values-for-reducedmotion).

 \"[`reducedTransparency`](#dom-preferencemanager-reducedtransparency)\"
 : Return the result of [get valid values for
 reducedTransparency](#get-valid-values-for-reducedtransparency).

 \"[`reducedData`](#dom-preferencemanager-reduceddata)\"
 : Return the result of [get valid values for
 reducedData](#get-valid-values-for-reduceddata).

##### 13.1.8.4. [`onchange` event handler attribute]
The [`onchange`]
attribute is an [event handler IDL
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) for the
[`onchange`](#dom-preferenceobject-onchange) [event
handler](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers), whose [event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is [change].

Whenever the [user
agent](https://infra.spec.whatwg.org/#user-agent) is aware that the state of a
[`PreferenceObject`](#preferenceobject) instance `value` has changed, it runs the
[[`PreferenceObject`](#preferenceobject) update
steps]:

1. Let `preference` be the
 [`PreferenceObject`](#preferenceobject) object that `value` is associated with.

2. If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) is a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object, then:

 1. Let `document` be `preference`'s [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

 2. If `document` is null or `document` is not
 [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), terminate this algorithm.

3. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named `change` at `preference`.

##### 13.1.8.5. [`requestOverride()` method]
The [`requestOverride(value)`] method, when invoked, must run these steps:

1. Let `result` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

2. Let `allowed` be false.

3. Set `allowed` to the result of executing a UA defined
 algorithm for deciding whether the request is allowed.

4. If `allowed` is false, return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with) a
 \"[`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. Let `value` be the method's argument.

6. Let `result` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

7. If `value` is null or the empty string:

 1. Run
 [`clearOverride`](#dom-preferenceobject-clearoverride).

 2. [Resolve](https://webidl.spec.whatwg.org/#resolve) and return `result`.

8. Let `currentValue` be the preference object's
 `value`.

9. Let `validValues` be null.

10. Switch on `preference`:

 \"[`colorScheme`](#dom-preferencemanager-colorscheme)\"
 : Set `validValues` to the result of [get valid values
 for
 colorScheme](#get-valid-values-for-colorscheme).

 \"[`contrast`](#dom-preferencemanager-contrast)\"
 : Set `validValues` to the result of [get valid values
 for
 contrast](#get-valid-values-for-contrast).

 \"[`reducedMotion`](#dom-preferencemanager-reducedmotion)\"
 : Set `validValues` to the result of [get valid values
 for
 reducedMotion](#get-valid-values-for-reducedmotion).

 \"[`reducedTransparency`](#dom-preferencemanager-reducedtransparency)\"
 : Set `validValues` to the result of [get valid values
 for
 reducedTransparency](#get-valid-values-for-reducedtransparency).

 \"[`reducedData`](#dom-preferencemanager-reduceddata)\"
 : Set `validValues` to the result of [get valid values
 for
 reducedData](#get-valid-values-for-reduceddata).

11. If `value` is not in `validValues`:

 1. [Reject](https://webidl.spec.whatwg.org/#reject) `result` with a
 \"[`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Return `result`.

12. Let `previousOverride` be null.

13. If an override for `preference` exists, set
 `previousOverride` to the value of that override.

14. If `value` is different from
 `previousOverride`:

 1. Set the preference override for `preference` to
 `value`.

15. If `previousOverride` is null, then:

 1. If `value` is the same as `currentValue`,
 then:

 1. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named `change` at
 [this](https://webidl.spec.whatwg.org/#this).

16. [Resolve](https://webidl.spec.whatwg.org/#resolve) and return `result`.

This algorithm needs more detail on what
exactly setting the preference override does.

Is TypeError correct here?

 The \`change\` event is fired when the computed value
changes, but when a new override is set it is also fired if the value
hasn't changed.

##### 13.1.8.6. [`clearOverride()` method]
The [`clearOverride()`] method, when invoked, must run these steps:

1. Let `preference` be the preference object's name.

2. Let `override` be null.

3. If an override for `preference` exists, set
 `override` to the value of that override.

4. If `override` is null, then return.

5. Clear the override for `preference`.

6. Let `newValue` be the preference object's value.

7. If `newValue` is equal to `override`, then:

8. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named `change` at
 [this](https://webidl.spec.whatwg.org/#this).

 The \`change\` event is fired when the computed value
changes, but when an override is cleared it is also fired if the value
hasn't changed.

## [ Appendix A: Deprecated Media Features]
The following [media features](#media-feature) are **deprecated**. They are kept for backward
compatibility, but are not appropriate for newly written style sheets.
Authors must not use them. User agents must support them as specified.

To query for the size of the viewport (or the page box on page media),
the [width](#descdef-media-width),
[height](#descdef-media-height) and
[aspect-ratio](#descdef-media-aspect-ratio) [media
features](#media-feature)
should be used, rather than
[device-width](#descdef-media-device-width),
[device-height](#descdef-media-device-height) and
[device-aspect-ratio](#descdef-media-device-aspect-ratio), which refer to the physical size of the
device regardless of how much space is available for the document being
laid out. The device-\* [media features] are
also sometimes used as a proxy to detect mobile devices. Instead,
authors should use [media features] that
better represent the aspect of the device that they are attempting to
style against.

### [ device-width]
Name:

[device-width]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

[\<length\>](https://www.w3.org/TR/css-values-4/#length-value)

Type:

range

The
[device-width](#descdef-media-device-width) media feature describes the width of the
rendering surface of the output device. For [continuous
media](#continuous-media),
this is the width of the [Web-exposed screen
area](https://www.w3.org/TR/cssom-view-1/#web-exposed-screen-area). For [paged media](#paged-media), this is the width of the page sheet size.

[device-width](#descdef-media-device-width) is [false in the negative
range](#false-in-the-negative-range).

@media (device-width < 800px) { … }

In the example above, the style sheet will apply only to screens less
than [800px] in length. The
[px](https://www.w3.org/TR/css-values-4/#px) unit is of the logical kind, as described in the
[Units](#units) section.

 If a device can be used in multiple orientations, such
as portrait and landscape, the [device-\*] media features reflect
the current orientation.

### [ device-height]
Name:

[device-height]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

[\<length\>](https://www.w3.org/TR/css-values-4/#length-value)

Type:

range

The
[device-height](#descdef-media-device-height) media feature describes the height of
the rendering surface of the output device. For [continuous
media](#continuous-media),
this is the height of the [Web-exposed screen
area](https://www.w3.org/TR/cssom-view-1/#web-exposed-screen-area). For [paged media](#paged-media), this is the height of the page sheet size.

[device-height](#descdef-media-device-height) is [false in the negative
range](#false-in-the-negative-range).

<link rel="stylesheet" media="(device-height > 600px)" />

In the example above, the style sheet will apply only to screens taller
than 600 vertical pixels. Note that the definition of the
[px](https://www.w3.org/TR/css-values-4/#px) unit is the same as in other parts of CSS.

### [ device-aspect-ratio]
Name:

[device-aspect-ratio]

For:

[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media)

Value:

[\<ratio\>](https://www.w3.org/TR/css-values-4/#ratio-value)

Type:

range

The
[device-aspect-ratio](#descdef-media-device-aspect-ratio) media feature is defined as the ratio of
the value of the
[device-width](#descdef-media-device-width) media feature to the value of the
[device-height](#descdef-media-device-height) media feature.

For example, if a screen device with
square pixels has 1280 horizontal pixels and 720 vertical pixels
(commonly referred to as "16:9"), the following media queries will all
match the device:

 @media (device-aspect-ratio: 16/9) { … }
 @media (device-aspect-ratio: 32/18) { … }
 @media (device-aspect-ratio: 1280/720) { … }
 @media (device-aspect-ratio: 2560/1440) { … }

## [ Changes]
*This section is not normative.*

::: non-normative
### [ Changes Since the 18 December 2021 Working Draft]
In addition to editorial changes and minor clarifications, the following
changes and additions were made to this module since the [2021-12-18
Working Draft](https://www.w3.org/TR/2021/WD-mediaqueries-5-20211218/):

- Moved \'display mode\' definition back to
 [\[APPMANIFEST\]](#biblio-appmanifest "Web Application Manifest")
 ([display-mode](#descdef-media-display-mode) media feature remains here). (See
 [Issue 7306](https://github.com/w3c/csswg-drafts/issues/7306))

- Established a normative reference for
 [\[Display-P3\]](#biblio-display-p3 "Display P3")

- Disallowed use of [layer] as a media type, rather than merely
 treat it as an unknown one, for compatibility with [cascade
 layers](https://www.w3.org/TR/css-cascade-5/#cascade-layers).

- Clarified intent of
 [prefers-reduced-motion](#descdef-media-prefers-reduced-motion)

- Made embedded SVGs use the [used color
 scheme](https://www.w3.org/TR/css-color-adjust-1/#used-color-scheme) of the embedding node for
 [prefers-color-scheme](#descdef-media-prefers-color-scheme).

- Added further discussion of fingerprinting vectors.

- Removed the user agent style sheet rule for
 [inverted-colors](#descdef-media-inverted-colors) to avoid problems related to
 semi-transparent images.

- Added
 [picture-in-picture](#valdef-media-display-mode-picture-in-picture) value to
 [display-mode](#descdef-media-display-mode) media feature.

- Added Luke Warlow as an editor.

- Merged the Web Preferences API into this specification.

- Defined
 [`CSSCustomMediaRule`](#csscustommediarule) interface.

### [ Changes Since the 2020-07-31 Working Draft]
In addition to editorial changes and minor clarifications, the following
changes and additions were made to this module since the [2020-07-31
Working Draft](https://www.w3.org/TR/2020/WD-mediaqueries-5-20200731/):

- Adopted \'display mode\' definition and media feature from
 [\[APPMANIFEST\]](#biblio-appmanifest "Web Application Manifest").
 (See [Issue 6343](https://github.com/w3c/csswg-drafts/issues/6343))

- Dropped the media features what were meant to query about the geometry
 of the video plane in [bi-plane
 implementations](#video-prefixed-features): `video-width`,
 `video-height`, and `video-resolution`. (See [Issue
 5044](https://github.com/w3c/csswg-drafts/issues/5044))

- Renamed
 [prefers-contrast](#descdef-media-prefers-contrast) values `high` and `low` to
 [more](#valdef-media-prefers-contrast-more) and [prefers-contrast] less. (See [Issue
 2943](https://github.com/w3c/csswg-drafts/issues/2942))

- Reworked the interaction between
 [prefers-contrast](#descdef-media-prefers-contrast) and
 [forced-colors](#descdef-media-forced-colors), retiring `prefers-contrast: forced`
 and introducing
 [custom](#valdef-media-prefers-contrast-custom). (See [Issue
 5433](https://github.com/w3c/csswg-drafts/issues/5433)) and [Issue
 6036](https://github.com/w3c/csswg-drafts/issues/6036))

- Added the
 [horizontal-viewport-segments](#descdef-media-horizontal-viewport-segments) and
 [vertical-viewport-segments](#descdef-media-vertical-viewport-segments) media feature. (See [Issue
 6234](https://github.com/w3c/csswg-drafts/issues/6234))

- Added the
 [nav-controls](#descdef-media-nav-controls) media feature. (See [Issue
 6234](https://github.com/w3c/csswg-drafts/issues/6234))

- Made it possible for multiple values of
 [dynamic-range](#descdef-media-dynamic-range) to match at the same time. (See [Issue
 6793](https://github.com/w3c/csswg-drafts/issues/6793))

### [ Changes Since the 2020-07-15 Working Draft]
The following additions were made to this module since the [2020-07-15
Working Draft](https://www.w3.org/TR/2020/WD-mediaqueries-5-20200715/):

- Added a UA style sheet rule for
 [inverted-colors](#descdef-media-inverted-colors).
- Added the [prefers-contrast:
 forced](#descdef-media-prefers-contrast) value.
- Removed the `light-level` media feature as it is redundant with
 [prefers-contrast] and [prefers-color-scheme]; add
 examples of how these media features may be automatically inferred by
 the user agent based on the same factors `light-level` was expected to
 respond to.

### [ Changes Since the 2020-06-03 Working Draft]
The following additions were made to this module since the [2020-06-03
Working Draft](https://www.w3.org/TR/2020/WD-mediaqueries-5-20200603/):

- Merged the content of level 4 into this specification. It previously
 was maintained as a delta over level 4.
- Made a few editorial tweaks.

### [ Changes Since the 2020-03-18 Working Draft]
The following additions were made to this module since the [2020-03-18
Working Draft](https://www.w3.org/TR/2020/WD-mediaqueries-5-20200318/):

- Added [video-\*] and
 [dynamic-range](#descdef-media-dynamic-range) media features
- Removed \'prefers-color-scheme: no-preference\'

### [ Changes Since the First Public Working Draft]
The following additions were made to this module since the [2020-03-03
First Public Working
Draft](https://www.w3.org/TR/2020/WD-mediaqueries-5-20200303/):

- Highlighted some known issues inline in the document.

### [ Changes for FPWD (since the Media Queries Level 4)]
The following additions were made to create the First Public Working
Draft of this module, since the [Media Queries Level
4](https://www.w3.org/TR/mediaqueries-4/):

- Reinstated the `light-level`,
 [inverted-colors](#descdef-media-inverted-colors), and Custom Media Queries sections
 from earlier Media Queries Level 4 drafts.
- Added
 [prefers-reduced-motion](#descdef-media-prefers-reduced-motion),
 [prefers-reduced-transparency](#descdef-media-prefers-reduced-transparency),
 [prefers-contrast](#descdef-media-prefers-contrast),
 [prefers-color-scheme](#descdef-media-prefers-color-scheme), and
 [forced-colors](#descdef-media-forced-colors) media features.

### [ Changes Since Media Queries Level 4]
The following additions were made to this module since the [Media
Queries Level 4](https://www.w3.org/TR/mediaqueries-4/):

- Added
 [environment-blending](#descdef-media-environment-blending),
 [horizontal-viewport-segments](#descdef-media-horizontal-viewport-segments),
 [vertical-viewport-segments](#descdef-media-vertical-viewport-segments),
 [display-mode](#descdef-media-display-mode),
 [dynamic-range](#descdef-media-dynamic-range),
 [inverted-colors](#descdef-media-inverted-colors),
 [nav-controls](#descdef-media-nav-controls), and
 [scripting](#descdef-media-scripting) [media
 features](#media-feature).

- Added
 [prefers-reduced-motion](#descdef-media-prefers-reduced-motion),
 [prefers-reduced-transparency](#descdef-media-prefers-reduced-transparency),
 [prefers-contrast](#descdef-media-prefers-contrast),
 [forced-colors](#descdef-media-forced-colors),
 [prefers-color-scheme](#descdef-media-prefers-color-scheme), and
 [prefers-reduced-data](#descdef-media-prefers-reduced-data) [User Preference Media
 Features](#mf-user-preferences) including script control via the
 [`PreferenceManager`](#preferencemanager) interface and related
 [`preferences`](#dom-navigator-preferences) attribute.

- Added
 [video-color-gamut](#descdef-media-video-color-gamut) and
 [video-dynamic-range](#descdef-media-video-dynamic-range) [Video Prefixed
 Features](#video-prefixed-features).

- Added [Custom Media Queries](#custom-mq).

- Allowed media features to define their own values that evaluate to
 false.

## [ Acknowledgments]
*This section is not normative.*

This specification is the product of the W3C Working Group on Cascading
Style Sheets.

Comments from Adam Argyle, Amelia Bellamy-Royds, Andreas Lind, Andres
Galante, Arve Bersvendsen, Björn Höhrmann, Chen Hui Jing, Chris Lilley,
Chris Rebert, Christian Biesinger, Christoph Päper, Elika J. Etemad
(fantasai), Emilio Cobos Álvarez, François Remy, Frédéric Wang, Fuqiao
Xue, Greg Whitworth, Ian Pouncey, James Craig, Jay Harris, Jinfeng Ma,
Kivi Shapiro, L. David Baron, Masataka Yakura, Matt Giuca, Melinda
Grant, Michael Smith, Nicholas C. Zakas Patrick H. Lauke, Philipp
Hoschka, Rick Byers, Rijk van Geijtenbeek, Rik Cabanier, Roger Gimson,
Rossen Atanassov, Sam Sneddon, Sigurd Lerstad, Simon Kissane, Simon
Pieters, Stephen Chenney, Steven Pemberton, Susan Lesch, Tantek Çelik,
Thomas Wisniewski, Vi Nguyen, Xidorn Quan, Yves Lafon, akklesed, and
張俊芝 improved this specification.

## [Privacy Considerations]
*This section is not normative.*

::: non-normative
this section is
[incomplete](https://github.com/w3c/csswg-drafts/issues?q=is%3Aopen+is%3Aissue+label%3Amediaqueries-5+label%3Aprivacy-tracker)

Many media features enable fingerprinting of users based on the display
and interaction characteristics of their device:

- [Colors](#mf-colors):
 [color](#descdef-media-color),
 [color-index](#descdef-media-color-index),
 [monochrome](#descdef-media-monochrome),
 [color-gamut](#descdef-media-color-gamut) and
 [dynamic-range](#descdef-media-dynamic-range)

- [Viewport characteristics](#mf-viewport-characteristics):
 [aspect-ratio](#descdef-media-aspect-ratio),
 [orientation](#descdef-media-orientation),
 [horizontal-viewport-segments](#descdef-media-horizontal-viewport-segments) and
 [vertical-viewport-segments](#descdef-media-vertical-viewport-segments)

- [Display quality](#mf-display-quality):
 [resolution](#descdef-media-resolution),
 [scan](#descdef-media-scan),
 [grid](#descdef-media-grid),
 [update](#descdef-media-update) and
 [environment-blending](#descdef-media-environment-blending)

- [Interaction devices](#mf-interaction):
 [pointer](#descdef-media-pointer),
 [hover](#descdef-media-hover),
 [any-pointer](#descdef-media-any-pointer) and
 [any-hover](#descdef-media-any-hover).

The
[environment-blending](#descdef-media-environment-blending) feature is of particular concern because
it suggests *where* a user may be located, and is likely present in a
small set of devices. Uncommon device properties are stronger
fingerprinting features because they help segment devices into smaller
sets.

Similarly, some devices might allow a user to have their [preferred
color
scheme](https://www.w3.org/TR/css-color-adjust-1/#preferred-color-scheme) automatically change based on the time of
day---​[light](#valdef-media-ua-color-scheme-light) during the day and
[dark](#valdef-media-ua-color-scheme-dark) at night---​which can implicitly reveal location
information based on sunrise/sunset timing. (Longitude, quite easily,
and possibly latitude if tracked over time.) While this might be done at
a higher level than the UA (automatically in the OS, for example), if
possible, care can be taken to make this a less accurate signal, such as
bucketing based on time zone (which is already exposed via JS).

Media features that reflect operating system preferences are a
fingerprinting risk because such preferences are correlated with
characteristics of the user themselves:

- The
 [prefers-reduced-data](#descdef-media-prefers-reduced-data) media feature may be correlated with
 low income and limited data.

- The
 [prefers-reduced-motion](#descdef-media-prefers-reduced-motion),
 [prefers-color-scheme](#descdef-media-prefers-color-scheme),
 [prefers-reduced-transparency](#descdef-media-prefers-reduced-transparency),
 [forced-colors](#descdef-media-forced-colors) and
 [inverted-colors](#descdef-media-inverted-colors) queries reflect affordances for a
 range of special needs.

Properties dependent on one of the above media queries may be accessed
by script:

- Colors and other property values may be directly accessed through
 computed style, though user agents may elect to return constants for
 some colors (see, for example, [CSS Color
 4](https://drafts.csswg.org/css-color-4/#css-system-colors)).

- Layout affecting properties (such as font size) influence lengths,
 positions and sizes available to script.

User agents may disable these media features when users have expressed
sensitivity to tracking. Alternatively, user agents may limit the
combination of features within a single page to reduce the
fingerprinting power of the page.

The
[`PreferenceManager`](#preferencemanager) object allows querying some user-preference [media
features](#media-feature).
This is not a privacy leak, as that information is already trivially
available by using [media features]
themselves.

The
[`PreferenceManager`](#preferencemanager) object also allows overriding these user-preference
[media features](#media-feature); this is also neither a privacy nor accessibility
regression, as the [media features] were
already ignorable by simply not querying them.

## [Security Considerations]
*This section is not normative.*

::: non-normative
(#issue-d67229a5①) this section is
[incomplete](https://github.com/w3c/csswg-drafts/issues?q=is%3Aopen+is%3Aissue+label%3Amediaqueries-5+label%3Asecurity-tracker+)

The
[display-mode](#descdef-media-display-mode) media feature allows an origin access to
aspects of a user's local computing environment and, particularly when
used together with an [application
manifest](https://www.w3.org/TR/appmanifest/#dfn-manifest)
[display](https://www.w3.org/TR/appmanifest/#dfn-display) member
[\[APPMANIFEST\]](#biblio-appmanifest "Web Application Manifest"),
allows an origin some measure of control over a user agent's native UI.
Through a CSS media query, a script can know the display mode of a web
application. An attacker could, in such a case, exploit the fact that an
application is being displayed in fullscreen to mimic the user interface
of another application.
