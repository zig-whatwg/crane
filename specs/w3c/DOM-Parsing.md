
[![W3C](https://www.w3.org/StyleSheets/TR/2021/logos/W3C){crossorigin=""
height="48" width="72"}](https://www.w3.org/)

# DOM Parsing and Serialization

## DOMParser, XMLSerializer, innerHTML, and similar APIs

[W3C Editor\'s Draft](https://www.w3.org/standards/types#ED) 02
September 2026

More details about this document

This version:
: [https://w3c.github.io/DOM-Parsing/](https://w3c.github.io/DOM-Parsing/)

Latest published version:
: <https://www.w3.org/TR/DOM-Parsing/>

Latest editor\'s draft:
: <https://w3c.github.io/DOM-Parsing/>

History:
: <https://www.w3.org/standards/history/DOM-Parsing/>
: [Commit history](https://github.com/w3c/DOM-Parsing/commits/)

Editor:
: [Travis Leithead](mailto:travis.leithead@microsoft.com)
 ([Microsoft](http://www.microsoft.com))

Feedback:
: [GitHub w3c/DOM-Parsing](https://github.com/w3c/DOM-Parsing/) ([pull
 requests](https://github.com/w3c/DOM-Parsing/pulls/), [new
 issue](https://github.com/w3c/DOM-Parsing/issues/new/choose), [open
 issues](https://github.com/w3c/DOM-Parsing/issues/))
: [www-dom@w3.org](mailto:www-dom@w3.org?subject=DOM-Parsing) with
 subject line [DOM-Parsing]
 ([archives](https://lists.w3.org/Archives/Public/www-dom){rel="discussion"})

Test Suites
: <http://wpt.live/domparsing/>
: <http://wpt.live/html/syntax/>

Participate
: [Bugzilla Bug
 list.](https://www.w3.org/Bugs/Public/buglist.cgi?component=DOM%20Parsing%20and%20Serialization&list_id=44989&product=WebAppsWG&resolution=---)
: [Mailing list.](http://lists.w3.org/Archives/Public/www-dom/)

[Copyright](https://www.w3.org/policies/#copyright) © 2026 [World Wide
Web Consortium](https://www.w3.org/). [W3C]^®^
[liability](https://www.w3.org/policies/#Legal_Disclaimer),
[trademark](https://www.w3.org/policies/#W3C_Trademarks) and [permissive
document
license](https://www.w3.org/copyright/software-license-2023/ "W3C Software and Document Notice and License"){rel="license"}
rules apply.

------------------------------------------------------------------------

## Abstract

This specification defines APIs for the parsing and serializing of HTML
and XML-based DOM nodes for web applications.

## Status of This Document

*This section describes the status of this document at the time of its
publication. A list of current [W3C] publications and the latest revision
of this technical report can be found in the [[W3C] standards and drafts
index](https://www.w3.org/TR/).*

This document was published by the [Web Applications Working
Group](https://www.w3.org/groups/wg/webapps) as an Editor\'s Draft.

Publication as an Editor\'s Draft does not imply endorsement by
[W3C] and its Members.

This is a draft document and may be updated, replaced, or obsoleted by
other documents at any time. It is inappropriate to cite this document
as other than a work in progress.

This document was produced by a group operating under the [[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/). [W3C] maintains a [public list of any
patent
disclosures](https://www.w3.org/groups/wg/webapps/ipr){rel="disclosure"}
made in connection with the deliverables of the group; that page also
includes instructions for disclosing a patent. An individual who has
actual knowledge of a patent that the individual believes contains
[Essential
Claim(s)](https://www.w3.org/policies/patent-policy/#def-essential) must
disclose the information in accordance with [section 6 of the
[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/#sec-Disclosure).

This document is governed by the [18 August 2025 [W3C] Process
Document](https://www.w3.org/policies/process/20250818/).

## Table of Contents

1. [Abstract](#abstract)
2. [Status of This Document](#sotd)
3. [Candidate Recommendation Exit Criteria](#crec)
4. [1. Conformance](#conformance)
5. [2. Extensibility](#extensibility)
6. [3. Introduction](#introduction)
7. [4. APIs for parsing and serializing
 DOM](#apis-for-parsing-and-serializing-dom)
 1. [4.1 The [`DOMParser`]
 interface](#the-domparser-interface)
 2. [4.2 The [`XMLSerializer`]
 interface](#the-xmlserializer-interface)
 3. [4.3 The `InnerHTML` mixin](#the-innerhtml-mixin)
 4. [4.4 Extensions to the [`Element`]
 interface](#extensions-to-the-element-interface)
 5. [4.5 Extensions to the [`Range`]
 interface](#extensions-to-the-range-interface)
8. [5. Algorithms for parsing and
 serializing](#algorithms-for-parsing-and-serializing)
 1. [5.1 Parsing](#parsing)
 2. [5.2 Serializing](#serializing)
 1. [5.2.1 XML Serialization](#xml-serialization)
 1. [5.2.1.1 XML serializing an Element
 node](#xml-serializing-an-element-node)
 1. [5.2.1.1.1 Recording the
 namespace](#recording-the-namespace)
 2. [5.2.1.1.2 The Namespace Prefix
 Map](#the-namespace-prefix-map)
 3. [5.2.1.1.3 Serializing an Element\'s
 attributes](#serializing-an-element-s-attributes)
 4. [5.2.1.1.4 Generating namespace
 prefixes](#generating-namespace-prefixes)
 2. [5.2.1.2 XML serializing a Document
 node](#xml-serializing-a-document-node)
 3. [5.2.1.3 XML serializing a Comment
 node](#xml-serializing-a-comment-node)
 4. [5.2.1.4 XML serializing a CDATASection
 node](#xml-serializing-a-cdatasection-node)
 5. [5.2.1.5 XML serializing a Text
 node](#xml-serializing-a-text-node)
 6. [5.2.1.6 XML serializing a DocumentFragment
 node](#xml-serializing-a-documentfragment-node)
 7. [5.2.1.7 XML serializing a DocumentType
 node](#xml-serializing-a-documenttype-node)
 8. [5.2.1.8 XML serializing a ProcessingInstruction
 node](#xml-serializing-a-processinginstruction-node)
9. [A. Dependencies](#dependencies)
10. [B. Revision History](#revision-history)
11. [C. Acknowledgements](#acknowledgements)
12. [D. References](#references)
 1. [D.1 Normative references](#normative-references)

::: header-wrapper
## Candidate Recommendation Exit Criteria

This specification will not advance to Proposed Recommendation before
the spec\'s [test suite](http://w3c-test.org/domparsing/) is completed
and two or more independent implementations pass each test, although no
single implementation must pass each test. We expect to meet this
criteria no sooner than 24 October 2014. The group will also create an
[Implementation
Report](https://dvcs.w3.org/hg/innerhtml/raw-file/tip/implementationReport.html).

::: header-wrapper
## 1. Conformance

As well as sections marked as non-normative, all authoring guidelines,
diagrams, examples, and notes in this specification are non-normative.
Everything else in this specification is normative.

This specification depends on the Infra Standard.
\[[INFRA](#bib-infra "Infra Standard")\]

The IDL fragments in this specification must be interpreted as required
for conforming IDL fragments, as described in the Web IDL specification.
\[[WEBIDL](#bib-webidl "Web IDL Standard")\]

Requirements phrased in the imperative as part of algorithms (such as
\"strip any leading space characters\" or \"return false and terminate
these steps\") are to be interpreted with the meaning of the key word
(\"must\", \"should\", \"may\", etc) used in introducing the algorithm.

Conformance requirements phrased as algorithms or specific steps may be
implemented in any manner, so long as the end result is equivalent. (In
particular, the algorithms defined in this specification are intended to
be easy to follow, and not intended to be performant.)

User agents may impose implementation-specific limits on otherwise
unconstrained inputs, e.g. to prevent denial of service attacks, to
guard against running out of memory, or to work around platform-specific
limitations.

When a method or an attribute is said to call another method or
attribute, the user agent must invoke its internal API for that
attribute or method so that e.g. the author can\'t change the behavior
by overriding attributes or methods with custom properties or functions
in ECMAScript.
\[[ECMA-262](#bib-ecma-262 "ECMAScript Language Specification")\]

If an algorithm calls into another algorithm, any exception that is
thrown by the latter (unless it is explicitly caught), must cause the
former to terminate, and the exception to be propagated up to its
caller.

::: header-wrapper
## 2. Extensibility

Vendor-specific proprietary extensions to this specification are
strongly discouraged. Authors must not use such extensions, as doing so
reduces interoperability and fragments the user base, allowing only
users of specific user agents to access the content in question.

If vendor-specific extensions are needed, the members should be prefixed
by vendor-specific strings to prevent clashes with future versions of
this specification. Extensions must be defined so that the use of
extensions neither contradicts nor causes the non-conformance of
functionality defined in the specification.

When vendor-neutral extensions to this specification are needed, either
this specification can be updated accordingly, or an extension
specification can be written that overrides the requirements in this
specification. Such an extension specification becomes an [applicable
specification] for the purposes of
conformance requirements in this specification.

::: header-wrapper
## 3. Introduction

A document object model (DOM) is an in-memory representation of various
types of
[`Node`](https://dom.spec.whatwg.org/#node)s where each
[`Node`](https://dom.spec.whatwg.org/#node) is connected in a tree. The
\[[HTML](#bib-html "HTML Standard")\] and
\[[DOM](#bib-dom "DOM Standard")\]
specifications describe DOM and its
[`Node`](https://dom.spec.whatwg.org/#node)s in greater detail.

[Parsing] is the term used for converting a string representation
of a DOM into an actual DOM, and [Serializing] is the term used to
transform a DOM back into a string. This specification concerns itself
with defining various APIs for both parsing and serializing a DOM.

For example: the
[`Element`](https://dom.spec.whatwg.org/#element).[`innerHTML`](#dfn-innerhtml) API is a common way to both parse and
serialize a DOM (it does both). If a particular
[`Node`](https://dom.spec.whatwg.org/#node) has the following in-memory DOM:

``` {aria-busy="false"}
HTMLDivElement (nodeName: "div")
┃
┣━ HTMLSpanElement (nodeName: "span")
┃ ┃
┃ ┗━ Text (data: "some ")
┃
┗━ HTMLElement (nodeName: "em")
 ┃
 ┗━ Text (data: "text!")
```

And the `HTMLDivElement` node is stored in a variable
`myDiv`, then to serialize `myDiv`\'s children
simply *get* (read) the
[`Element`](https://dom.spec.whatwg.org/#element).[`innerHTML`](#dfn-innerhtml) property (this triggers the
serialization):

``` {aria-busy="false"}
var serializedChildren = myDiv.innerHTML;
// serializedChildren has the value:
// "<span>some </span><em>text!</em>"
```

To parse new children for `myDiv` from a string (replacing
its existing children), simply *set* the
[`Element`](https://dom.spec.whatwg.org/#element).[`innerHTML`](#dfn-innerhtml) property (this triggers parsing of the
assigned string):

``` {aria-busy="false"}
myDiv.innerHTML = "<span>new</span><em>children!</em>";
```

This specification describes two flavors of
[parsing](#dfn-parsing) and
[serializing](#dfn-serializing): HTML and XML (with XHTML being a type of XML). Each
follows the rules of its respective markup language. The above example
shows HTML parsing and serialization. The specific algorithms for HTML
parsing and serializing are defined in the
\[[HTML](#bib-html "HTML Standard")\]
specification. This specification contains the algorithm for XML
serializing. The grammar for XML parsing is described in the
\[[XML10](#bib-xml10 "Extensible Markup Language (XML) 1.0 (Fifth Edition)")\] specification.

[Round-tripping] a DOM means to serialize and then
immediately parse the serialized string back into a DOM. Ideally, this
process does not result in any data loss with respect to the identity
and attributes of the
[`Node`](https://dom.spec.whatwg.org/#node) in the DOM.
[Round-tripping](#dfn-round-tripping) is especially tricky for an XML
serialization, which must be concerned with preserving the
[`Node`](https://dom.spec.whatwg.org/#node)\'s namespace identity in the serialization (wereas namespaces
are ignored in HTML).

Consider the XML serialization of the following in-memory DOM:

``` {aria-busy="false"}
Element (nodeName: "root")
┃
┗━ HTMLScriptElement (nodeName: "script")
 ┃
 ┗━ Text (data: "alert('hello world')")
```

An XML serialization must include the
[`HTMLScriptElement`](https://html.spec.whatwg.org/multipage/scripting.html#htmlscriptelement)\'s
[namespace](https://dom.spec.whatwg.org/#concept-element-namespace)
in order to preserve the identity of the
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script)
element, and to allow the serialized string to
[round-trip](#dfn-round-tripping) through an XML parser.
Assuming that `root` is in a variable named `root`:

``` {aria-busy="false"}
var xmlSerialization = new XMLSerializer().serializeToString(root);
// xmlSerialization has the value:
// "<root><script xmlns="http://www.w3.org/1999/xhtml">alert('hello world')</script></root>"
```

::: header-wrapper
## 4. APIs for parsing and serializing DOM

::: header-wrapper
### 4.1 The [`DOMParser`](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#domparser) interface

The definition of
[`DOMParser`](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#domparser) has moved to [the HTML
Standard](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#domparser).

::: header-wrapper
### 4.2 The [`XMLSerializer`](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#xmlserializer) interface

The definition of
[`XMLSerializer`](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#xmlserializer) has moved to [the HTML
Standard](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#xmlserializer).

::: header-wrapper
### 4.3 The `InnerHTML` mixin

The definition of
[`Element`](https://dom.spec.whatwg.org/#element).[`innerHTML`](#dfn-innerhtml) has moved to [the HTML
Standard](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-innerhtml-property).

::: header-wrapper
### 4.4 Extensions to the [`Element`](https://dom.spec.whatwg.org/#element) interface

The definition of
[`Element`](https://dom.spec.whatwg.org/#element).[`outerHTML`](#dfn-outerhtml) has moved to [the HTML
Standard](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-outerhtml-property).

The definition of
[`Element`](https://dom.spec.whatwg.org/#element).[`insertAdjacentHTML`](#dfn-insertadjacenthtml) has moved to [the HTML
Standard](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-insertadjacenthtml()-method).

::: header-wrapper
### 4.5 Extensions to the [`Range`](https://dom.spec.whatwg.org/#range) interface

The definition of
[`Range`](https://dom.spec.whatwg.org/#range).[`createContextualFragment`](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-range-createcontextualfragment)`()` has moved to [the HTML
Standard](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-createcontextualfragment()-method).

::: header-wrapper
## 5. Algorithms for parsing and serializing

::: header-wrapper
### 5.1 Parsing

The definition of [fragment parsing
algorithm](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#fragment-parsing-algorithm-steps) has moved to [the HTML
Standard](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#fragment-parsing-algorithm-steps).

::: header-wrapper
### 5.2 Serializing

The definition of [fragment serializing
algorithm](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#fragment-serializing-algorithm-steps) has moved to [the HTML
Standard](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#fragment-serializing-algorithm-steps).

::: header-wrapper
#### 5.2.1 XML Serialization

An [XML
serialization](#dfn-xml-serialization) differs from an HTML serialization in the
following ways:

- [`Element`](https://dom.spec.whatwg.org/#element)s and
 [attributes](https://dom.spec.whatwg.org/#concept-attribute)
 will always be serialized such that their namespace is preserved. In
 some cases this means that an existing prefix, prefix declaration
 attribute or default namespace declaration attribute might be dropped,
 substituted or changed. An HTML serialization does not attempt to
 preserve the namespace.
- [`Element`](https://dom.spec.whatwg.org/#element)s not in the [HTML
 namespace](https://infra.spec.whatwg.org/#html-namespace)
 containing no
 [children](https://dom.spec.whatwg.org/#concept-tree-child),
 are serialized using the [empty-element
 tag](#dfn-empty-element-tag) syntax (i.e., according to the XML
 [EmptyElemTag](#dfn-emptyelemtag) production).

Otherwise, the algorithm for producing an [XML
serialization](#dfn-xml-serialization) is designed to produce a serialization
that is compatible with the [HTML
parser](#dfn-html-parser). For example, elements in the [HTML
namespace](https://infra.spec.whatwg.org/#html-namespace)
that contain no
[children](https://dom.spec.whatwg.org/#concept-tree-child)
are serialized with an explicit begin and end tag rather than using the
[empty-element
tag](#dfn-empty-element-tag) syntax.

To produce an [XML serialization] of a
[`Node`](https://dom.spec.whatwg.org/#node) `node` given a boolean
`require well-formed`, run the following steps:

1. Let `namespace` be null.

 ::::
 :::
 Note
 :::

 `namespace` tracks the [XML
 serialization](#dfn-xml-serialization) algorithm\'s current default
 namespace. It is changed when either an
 [`Element`](https://dom.spec.whatwg.org/#element) has a default namespace declaration, or the algorithm
 generates a default namespace declaration for the
 [`Element`](https://dom.spec.whatwg.org/#element) to match its own namespace. The algorithm assumes no
 namespace (null) to start.
 ::::

2. Let `prefix map` be «»
 (a [namespace prefix
 map](#dfn-namespace-prefix-map)).

3. [Add](#dfn-add)
 \"`xml`\" to `prefix map` given the [XML
 namespace](https://infra.spec.whatwg.org/#xml-namespace).

4. Let `prefix index` be 1.

 ::::
 :::
 Note
 :::

 `prefix index` is used to generate a
 new unique prefix when no suitable existing namespace prefix is
 available to serialize a node\'s
 [namespace](https://dom.spec.whatwg.org/#concept-element-namespace)
 (or the
 [namespace](https://dom.spec.whatwg.org/#concept-attribute-namespace)
 of one of the
 [attributes](https://dom.spec.whatwg.org/#concept-attribute)
 in `node`\'s [attribute
 list](https://dom.spec.whatwg.org/#concept-element-attribute)).
 See the [generate a
 prefix](#dfn-generating-a-prefix) algorithm.
 ::::

5. Return the result of running the [XML serialization
 algorithm](#dfn-xml-serialization-algorithm) given `node`,
 `namespace`, `prefix map`, a mutable reference to
 `prefix index`, and
 `require well-formed`. If an
 [exception] occurs during the execution
 of the algorithm, then catch that exception and throw an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

The [XML serialization algorithm], given a
[`Node`](https://dom.spec.whatwg.org/#node) `node`, a string
`namespace`, a [namespace prefix
map](#dfn-namespace-prefix-map) `prefix map`, a mutable reference to an integer
`prefix index`,
and a boolean `require well-formed`, must run the following
steps:

1. If `node`\'s interface is:

 [`Element`](https://dom.spec.whatwg.org/#element)
 : Run the algorithm for [XML serializing an Element
 node](#dfn-xml-serializing-an-element-node) given `node`, `namespace`,
 `namespace prefix map`, `prefix index` and
 `require well-formed`.

 [`Document`](https://dom.spec.whatwg.org/#document)
 : Run the algorithm for [XML serializing a Document
 node](#dfn-xml-serializing-a-document-node) given `node`, `namespace`,
 `namespace prefix map`, `prefix index` and
 `require well-formed`.

 [`Comment`](https://dom.spec.whatwg.org/#comment)
 : Run the algorithm for [XML serializing a Comment
 node](#dfn-xml-serializing-a-comment-node) given `node` and `require well-formed`.

 [`CDATASection`](https://dom.spec.whatwg.org/#cdatasection)
 : Run the algorithm for [XML serializing a CDATASection
 node](#dfn-xml-serializing-a-cdatasection-node) given `node` and `require well-formed`.

 [`Text`](https://dom.spec.whatwg.org/#text)
 : Run the algorithm for [XML serializing a Text
 node](#dfn-xml-serializing-a-text-node) given `node` and `require well-formed`.

 [`DocumentFragment`](https://dom.spec.whatwg.org/#documentfragment)
 : Run the algorithm for [XML serializing a DocumentFragment
 node](#dfn-xml-serializing-a-documentfragment-node) given `node`, `namespace`,
 `namespace prefix map`, `prefix index` and
 `require well-formed`.

 [`DocumentType`](https://dom.spec.whatwg.org/#documenttype)
 : Run the algorithm for [XML serializing a DocumentType
 node](#dfn-xml-serializing-a-documenttype-node) given `node` and `require well-formed`.

 [`ProcessingInstruction`](https://dom.spec.whatwg.org/#processinginstruction)
 : Run the algorithm for [XML serializing a ProcessingInstruction
 node](#dfn-xml-serializing-a-processinginstruction-node) given `node` and `require well-formed`.

 [`Attr`](https://dom.spec.whatwg.org/#attr)
 : Return the empty string.

 Anything else
 : Throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror). Only
 [`Node`](https://dom.spec.whatwg.org/#node)s and
 [`Attr`](https://dom.spec.whatwg.org/#attr)s can be serialized by this algorithm.

Each of the above referenced algorithms are detailed in the sections
that follow.

::: header-wrapper
##### 5.2.1.1 XML serializing an Element node

The algorithm for [XML serializing an Element
node], given an
[`Element`](https://dom.spec.whatwg.org/#element) `node`, a string
`namespace`, a [namespace prefix
map](#dfn-namespace-prefix-map) `prefix map`, a mutable reference to an integer
`prefix index`,
and a boolean `require well-formed`, must run the following
steps:

1. If `require well-formed` is true, and `node`\'s [local
 name](https://dom.spec.whatwg.org/#concept-element-local-name)
 contains the character \"`:`\" (U+003A COLON) or does not match the
 XML [Name](#dfn-name) production, then [throw an
 exception](#dfn-throw-an-exception). [(The serialization of
 `node` would not be
 well-formed.)]

2. Let `markup` be \"`<`\" (U+003C
 LESS-THAN SIGN).

3. Let `qualified name` be the empty
 string.

4. Let `skip end tag` be false.

5. Let `ignore namespace definition attribute` be false.

6. Let `map` be the result
 of [copy a namespace prefix
 map](#dfn-copy-a-namespace-prefix-map) given `prefix map`.

7. Let `local prefixes map` be « » (an
 [ordered
 map](https://infra.spec.whatwg.org/#ordered-map)
 from strings to strings).

 ::::
 :::
 Note
 :::

 Its keys will be prefixes, and its values will be namespaces. In
 this map, the null namespace is represented by the empty string.
 ::::

 ::::
 :::
 Note
 :::

 This map is local to each element. It is used to ensure there are no
 conflicting prefixes if a new namespace prefix attribute needs to be
 [generated](#dfn-generating-a-prefix). It is also
 used to enable skipping of duplicate prefix definitions when
 [writing an element\'s
 attributes](#dfn-xml-serialization-of-the-attributes): the map allows the algorithm to distinguish
 between a prefix in the [namespace prefix
 map](#dfn-namespace-prefix-map) that might be locally-defined (to the
 current
 [`Element`](https://dom.spec.whatwg.org/#element)) and one that is not.
 ::::

8. Let `local default namespace` be the result of [recording
 the namespace
 information](#dfn-recording-the-namespace-information) for `node`\'s [attribute
 list](https://dom.spec.whatwg.org/#concept-element-attribute)
 given `map` and
 `local prefixes map`.

 ::::
 :::
 Note
 :::

 The above step will update `map` with any found namespace prefix
 definitions, add the found prefix definitions to
 `local prefixes map` and return the value
 of a default namespace attribute (which can be empty) if one exists.
 Otherwise it returns null.
 ::::

9. Let `inherited ns` be `namespace`.

 ::::
 :::
 Note
 :::

 `inherited ns` will be passed down as the namespace
 argument when serializing `node`\'s
 [children](https://dom.spec.whatwg.org/#concept-tree-child).
 ::::

10. Let `ns` be `node`\'s
 [namespace](https://dom.spec.whatwg.org/#concept-element-namespace).

11. If `inherited ns` is `ns`, then:

 ::::
 :::
 Note
 :::

 `node` is in the current default
 namespace. The steps below serialize `node` without a prefix (even if it had one), and drop
 any default namespace declaration. An exception is made if
 `node` is in the [XML
 namespace](https://infra.spec.whatwg.org/#xml-namespace),
 in which case the \"`xml:`\" prefix is used; this prefix does not
 need to be declared and no effort is made to declare it.
 ::::

 1. If `local default namespace` is not null, then set
 `ignore namespace definition attribute` to true.
 2. If `ns` is the [XML
 namespace](https://infra.spec.whatwg.org/#xml-namespace),
 then append the concatenation of \"`xml:`\" and `node`\'s [local
 name](https://dom.spec.whatwg.org/#concept-element-local-name)
 to `qualified name`.
 3. Otherwise, append `node`\'s
 [local
 name](https://dom.spec.whatwg.org/#concept-element-local-name)
 to `qualified name`.
 4. Append `qualified name` to
 `markup`.

12. Otherwise:

 ::::
 :::
 Note
 :::

 `inherited ns` is not equal to `ns`;
 `node`\'s own
 [namespace](https://dom.spec.whatwg.org/#concept-element-namespace)
 is different from the context namespace. To differentiate
 `node`\'s namespace from the context
 namespace, the steps below will use a namespace prefix if one is
 available; if not, they will use or introduce a default namespace
 declaration.
 ::::

 1. Let `prefix` be `node`\'s [namespace
 prefix](https://dom.spec.whatwg.org/#concept-element-namespace-prefix).
 2. Let `candidate prefix` be the result of [retrieving a
 preferred prefix
 string](#dfn-retrieving-a-preferred-prefix-string) `prefix` from
 `map` given
 `ns`.

 ::::
 :::
 Note
 :::

 `candidate prefix` will be null if no prefix was
 found that maps to `ns` (not even
 `prefix`). In that case, this algorithm will generate
 a new `xmlns` attribute and [add](#dfn-add) any new prefix to `map` below.
 ::::
 3. If `prefix` is \"`xmlns`\", then:
 1. If `require well-formed` is true, then [throw an
 exception](#dfn-throw-an-exception). [An
 [`Element`](https://dom.spec.whatwg.org/#element) with [namespace
 prefix](https://dom.spec.whatwg.org/#concept-element-namespace-prefix)
 \"`xmlns`\" will not legally round-trip in a conforming [XML
 parser](#dfn-xml-parser).]
 2. Set `candidate prefix` to `prefix`.
 4. [Found a suitable namespace
 prefix]: if
 `candidate prefix` is not null, then:

 ::::
 :::
 Note
 :::

 Either `node` or one of its
 ancestors defines that `candidate prefix` maps to
 `node`\'s
 [namespace](https://dom.spec.whatwg.org/#concept-element-namespace).
 ::::

 ::::
 :::
 Note
 :::

 The following could serialize a different prefix than
 `node`\'s existing [namespace
 prefix](https://dom.spec.whatwg.org/#concept-element-namespace-prefix),
 if any. However, this only happens if this prefix does not map
 to the correct namespace, as the [retrieving a preferred prefix
 string](#dfn-retrieving-a-preferred-prefix-string) algorithm already tried to match
 the existing prefix.
 ::::

 ::::::
 :::
 [[Issue
 52]](https://github.com/w3c/DOM-Parsing/issues/52)[:
 XMLSerializer: Should prefer the default namespace to a prefix
 declared in an ancestor
 [xml-serialization](https://github.com/w3c/DOM-Parsing/issues/?q=is%3Aissue+is%3Aopen+label%3A%22xml-serialization%22)]
 :::

 Suppose that we have the following XML document, parse it, and
 serialize it.

 :::
 ```
 <root xmlns:x="uri1">
 <table xmlns="uri1"/>
 </root>
 ```
 :::

 If we follow the current specification, the serialization result
 is:

 :::
 ```
 <root xmlns:x="uri1">
 <x:table xmlns="uri1"/>
 </root>
 ```
 :::

 It\'s incompatible with Edge, Firefox, Safari, and Chrome 73-.\
 (Chrome 74 produces the above result, and we\'re fixing it.)

 I think 12.1 in
 [https://w3c.github.io/DOM-Parsing/#xml-serializing-an-element-node](https://w3c.github.io/DOM-Parsing/#xml-serializing-an-element-node){rel="nofollow"}
 should be changed as following:

 **Original:** Let *candidate prefix* be the result of retrieving
 a preferred prefix string *prefix* from *map* given namespace
 *ns*.

 **Proposed:** Let *candidate prefix* be null if *prefix* is null
 and *ns* equals to *local default namespace*. Otherwise let
 *candidate prefix* be the result of retrieving a preferred
 prefix string *prefix* from *map* given namespace *ns*.

 WPT domparsing/XMLSerializer-serializeToString.html contains a
 testcase for this behavior.\
 \"Check if start tag serialization does NOT apply the default
 namespace if its namespace is declared in an ancestor.\"
 ::::::

 1. Append the concatenation of `candidate prefix`,
 \"`:`\" (U+003A COLON), and `node`\'s [local
 name](https://dom.spec.whatwg.org/#concept-element-local-name)
 to `qualified name`.
 2. If `local default namespace` is not null
 (`node` has a default
 namespace declaration attribute) and is not the [XML
 namespace](https://infra.spec.whatwg.org/#xml-namespace),
 then:
 1. If `local default namespace` is the empty
 string, set `inherited ns` to null.
 2. Otherwise, set `inherited ns` to
 `local default namespace`.

 ::::
 :::
 Note
 :::

 It is possible that `inherited ns` differs from
 `node`\'s
 [namespace](https://dom.spec.whatwg.org/#concept-element-namespace).
 ::::

 ::::
 :::
 Note
 :::

 Any default namespace definitions or namespace prefixes that
 define the [XML
 namespace](https://infra.spec.whatwg.org/#xml-namespace)
 are omitted when serializing
 [attributes](https://dom.spec.whatwg.org/#concept-attribute)
 in `node`\'s [attribute
 list](https://dom.spec.whatwg.org/#concept-element-attribute).
 ::::
 3. Append `qualified name` to
 `markup`.
 5. Otherwise, if `prefix` is not null, then:

 ::::
 :::
 Note
 :::

 By this step, there is no namespace or prefix mapping
 declaration in `node` (or any
 parent
 [`Node`](https://dom.spec.whatwg.org/#node) visited by this algorithm) that defines a prefix that
 maps to `node`\'s
 [namespace](https://dom.spec.whatwg.org/#concept-element-namespace);
 otherwise the step labelled [Found a suitable namespace
 prefix](#dfn-found-a-suitable-namespace-prefix) would have been followed. Ideally
 we would use `node`\'s [namespace
 prefix](https://dom.spec.whatwg.org/#concept-element-namespace-prefix).
 However, it could be the case that `node` already declares its own prefix as mapping
 to something else than its own namespace. In that case we will
 [generate a new
 prefix](#dfn-generating-a-prefix) as a last resort. In either case, the
 sub-steps that follow will serialize a new namespace prefix
 declaration for the prefix we end up using.
 ::::

 1. If `local prefixes map`
 [contains](https://infra.spec.whatwg.org/#map-exists)
 `prefix`, then set `prefix` to the
 result of [generating a
 prefix](#dfn-generating-a-prefix) given `map`, `ns`, and
 `prefix index`.
 2. [Add](#dfn-add) `prefix` to `map` given `ns`.
 3. Append the concatenation of `prefix`, \"`:`\"
 (U+003A COLON), and `node`\'s
 [local
 name](https://dom.spec.whatwg.org/#concept-element-local-name)
 to `qualified name`.
 4. Append `qualified name` to
 `markup`.
 5. Append the following to `markup`, in the order listed:

 ::::
 :::
 Note
 :::

 The following serializes a namespace prefix declaration for
 `prefix` which was just added to `map`.
 ::::

 1. \"` `\" (U+0020 SPACE);
 2. \"`xmlns:`\";
 3. `prefix`;
 4. \"`="`\" (U+003D EQUALS SIGN, U+0022 QUOTATION MARK);
 5. The result of [serializing an attribute
 value](#dfn-serializing-an-attribute-value) given `ns` and
 `require well-formed`;
 6. \"`"`\" (U+0022 QUOTATION MARK).
 6. If `local default namespace` is not null
 (`node` has a default
 namespace declaration attribute), then:
 1. If `local default namespace` is the empty
 string, set `inherited ns` to null.
 2. Otherwise, set `inherited ns` to
 `local default namespace`.
 6. Otherwise, if `local default namespace` is null, or
 `local default namespace` is not null and its value
 is not equal to `ns`, then:

 ::::
 :::
 Note
 :::

 At this point, the namespace for this node still needs to be
 serialized, but there\'s no [namespace
 prefix](https://dom.spec.whatwg.org/#concept-element-namespace-prefix)
 (or `candidate prefix`) available; the following uses
 the default namespace declaration to define the
 namespace---optionally replacing an existing default declaration
 if present.
 ::::

 1. Set `ignore namespace definition attribute` to true.
 2. Append `node`\'s [local
 name](https://dom.spec.whatwg.org/#concept-element-local-name)
 to `qualified name`.
 3. Set `inherited ns` to `ns`.

 ::::
 :::
 Note
 :::

 The new default namespace will be used in the serialization
 to define `node`\'s
 [namespace](https://dom.spec.whatwg.org/#concept-element-namespace)
 and act as the context namespace for its
 [children](https://dom.spec.whatwg.org/#concept-tree-child).
 ::::
 4. Append `qualified name` to
 `markup`.
 5. Append the following to `markup`, in the order listed:

 ::::
 :::
 Note
 :::

 The following serializes the new (or replacement) default
 namespace definition.
 ::::

 1. \"` `\" (U+0020 SPACE);
 2. \"`xmlns`\";
 3. \"`="`\" (U+003D EQUALS SIGN, U+0022 QUOTATION MARK);
 4. The result of [serializing an attribute
 value](#dfn-serializing-an-attribute-value) given `ns` and
 `require well-formed`;
 5. \"`"`\" (U+0022 QUOTATION MARK).
 7. Otherwise:

 ::::
 :::
 Note
 :::

 `local default namespace` is `ns`.
 ::::

 1. Append `node`\'s [local
 name](https://dom.spec.whatwg.org/#concept-element-local-name)
 to `qualified name`.
 2. Set `inherited ns` to `ns`.
 3. Append `qualified name` to
 `markup`.

 ::::
 :::
 Note
 :::

 All of the combinations where `ns` is not equal to
 `inherited ns` are handled above such that
 `node` will be serialized
 preserving its original
 [namespace](https://dom.spec.whatwg.org/#concept-element-namespace).
 ::::

13. Append to `markup` the result of the
 [XML serialization of the
 attributes](#dfn-xml-serialization-of-the-attributes) of `node` given `map`, `prefix index`,
 `local prefixes map`,
 `ignore namespace definition attribute`, and `require well-formed`.

14. If `ns` is the [HTML
 namespace](https://infra.spec.whatwg.org/#html-namespace),
 and `node`\'s
 [children](https://dom.spec.whatwg.org/#concept-tree-child)
 [is
 empty](https://infra.spec.whatwg.org/#list-is-empty),
 and `node`\'s [local
 name](https://dom.spec.whatwg.org/#concept-element-local-name)
 is one of the following: \"`area`\", \"`base`\", \"`basefont`\",
 \"`bgsound`\", \"`br`\", \"`col`\", \"`embed`\", \"`frame`\",
 \"`hr`\", \"`img`\", \"`input`\", \"`keygen`\", \"`link`\",
 \"`menuitem`\", \"`meta`\", \"`param`\", \"`source`\", \"`track`\",
 \"`wbr`\"; then append the following to `markup`, in the order listed:
 1. \"` `\" (U+0020 SPACE);
 2. \"`/`\" (U+002F SOLIDUS).

 and set `skip end tag` to true.

15. If `ns` is not the [HTML
 namespace](https://infra.spec.whatwg.org/#html-namespace),
 and `node`\'s
 [children](https://dom.spec.whatwg.org/#concept-tree-child)
 [is
 empty](https://infra.spec.whatwg.org/#list-is-empty),
 then append \"`/`\" (U+002F SOLIDUS) to `markup` and set `skip end tag` to true.

16. Append \"`>`\" (U+003E GREATER-THAN SIGN) to `markup`.

17. If `skip end tag` is true, then
 return `markup`. [`node` is a leaf node.]

18. If `ns` is the [HTML
 namespace](https://infra.spec.whatwg.org/#html-namespace),
 and `node`\'s [local
 name](https://dom.spec.whatwg.org/#concept-element-local-name)
 is \"`template`\" (this is a
 [`template`](https://html.spec.whatwg.org/multipage/scripting.html#the-template-element)
 element), append to `markup` the
 result of [XML serializing a DocumentFragment
 node](#dfn-xml-serializing-a-documentfragment-node) given `node`\'s [template
 contents](#dfn-template-content) (a
 [`DocumentFragment`](https://dom.spec.whatwg.org/#documentfragment)), `inherited ns`, `map`, `prefix index`, and
 `require well-formed`.

 ::::
 :::
 Note
 :::

 This allows [template
 content](#dfn-template-content) to round-trip, given the rules for
 [parsing XHTML
 documents](#dfn-parsing-xhtml-documents).
 ::::

19. Otherwise, [for
 each](https://infra.spec.whatwg.org/#list-iterate)
 `child` of `node`\'s
 [children](https://dom.spec.whatwg.org/#concept-tree-child):

 1. Append to `markup` the result of
 running the [XML serialization
 algorithm](#dfn-xml-serialization-algorithm) given `child`,
 `inherited ns`, `map`, `prefix index`, and
 `require well-formed`.

20. Append the following to `markup`, in
 the order listed:
 1. \"`</`\" (U+003C LESS-THAN SIGN, U+002F SOLIDUS);
 2. `qualified name`;
 3. \"`>`\" (U+003E GREATER-THAN SIGN).

21. Return `markup`.

::: header-wrapper
###### 5.2.1.1.1 Recording the namespace

This following algorithm will update the [namespace prefix
map](#dfn-namespace-prefix-map) with any found namespace prefix
definitions, add the found prefix definitions to
`local prefixes map`, and return a local default namespace
value defined by a default namespace attribute if one exists. Otherwise
it returns null.

When [recording the namespace
information] for a
[list](https://infra.spec.whatwg.org/#list) of
[attributes](https://dom.spec.whatwg.org/#concept-attribute)
`attributes`, given a [namespace prefix
map](#dfn-namespace-prefix-map) `map` and an [ordered
map](https://infra.spec.whatwg.org/#ordered-map)
`local prefixes map`, run the following steps:

1. Let `default namespace attr value` be null.
2. [For
 each](https://infra.spec.whatwg.org/#list-iterate)
 `attr` of `attributes`:

 ::::
 :::
 Note
 :::

 The following conditional steps find namespace prefixes. Only
 [attributes](https://dom.spec.whatwg.org/#concept-attribute)
 in the [XMLNS
 namespace](https://infra.spec.whatwg.org/#xmlns-namespace)
 are considered (e.g.,
 [attributes](https://dom.spec.whatwg.org/#concept-attribute)
 made to look like namespace declarations via
 [`setAttribute`](https://dom.spec.whatwg.org/#dom-element-setattribute)`(``"xmlns:pretend-prefix"``, ``"pretend-namespace"``)`
 are not included).
 ::::

 1. Let `attribute namespace` be `attr`\'s
 [namespace](https://dom.spec.whatwg.org/#concept-attribute-namespace).
 2. Let `attribute prefix` be `attr`\'s
 [namespace
 prefix](https://dom.spec.whatwg.org/#concept-attribute-namespace-prefix).
 3. If `attribute namespace` is the [XMLNS
 namespace](https://infra.spec.whatwg.org/#xmlns-namespace),
 then:
 1. If `attribute prefix` is null (`attr`
 is a default namespace declaration), set
 `default namespace attr value` to
 `attr`\'s
 [value](https://dom.spec.whatwg.org/#concept-attribute-value),
 and
 [continue](https://infra.spec.whatwg.org/#iteration-continue).
 2. Otherwise:
 1. ::::
 :::
 Note
 :::

 `attribute prefix` is not null and
 `attr` is a namespace prefix definition.
 ::::

 2. Let `prefix definition` be
 `attr`\'s [local
 name](https://dom.spec.whatwg.org/#concept-attribute-local-name).

 3. Let `namespace definition` be
 `attr`\'s
 [value](https://dom.spec.whatwg.org/#concept-attribute-value).

 4. If `namespace definition` is the [XML
 namespace](https://infra.spec.whatwg.org/#xml-namespace),
 then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 ::::
 :::
 Note
 :::

 [XML
 namespace](https://infra.spec.whatwg.org/#xml-namespace)
 definitions in prefixes are completely ignored (in order
 to avoid unnecessary work when there might be prefix
 conflicts).
 [`Element`](https://dom.spec.whatwg.org/#element)s in the [XML
 namespace](https://infra.spec.whatwg.org/#xml-namespace)
 are always handled uniformly by prefixing (and
 overriding if necessary) the element\'s [local
 name](https://dom.spec.whatwg.org/#concept-element-local-name)
 with the reserved \"`xml`\" prefix.
 ::::

 5. If `namespace definition` is the empty string
 (the declarative form of having no namespace), then set
 `namespace definition` to null.

 6. If `prefix definition` is
 [found](#dfn-found) in `map` given
 `namespace definition`, then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 ::::
 :::
 Note
 :::

 This step avoids adding duplicate prefix definitions for
 the same namespace in `map`. This has the
 side-effect of avoiding later serialization of duplicate
 namespace prefix declarations in any descendant nodes.
 ::::

 7. [Add](#dfn-add) `prefix definition` to
 `map` given
 `namespace definition`.

 8. If `namespace definition` is null, then set
 `namespace definition` to the empty string.

 9. Set
 `local prefixes map`\[`prefix definition`\]
 to `namespace definition`.
3. Return `default namespace attr value`.

 ::::
 :::
 Note
 :::

 The empty string is a legitimate return value and is not converted
 to null.
 ::::

::: header-wrapper
###### 5.2.1.1.2 The Namespace Prefix Map

A [namespace prefix map] is an [ordered
map](https://infra.spec.whatwg.org/#ordered-map) from
[strings](https://infra.spec.whatwg.org/#string) or
null to [lists](https://infra.spec.whatwg.org/#list) of
[strings](https://infra.spec.whatwg.org/#string).

The keys are namespaces, with null representing no namespace; the values
are [lists](https://infra.spec.whatwg.org/#list) of
prefixes that map to that namespace.

An empty [namespace prefix
map](#dfn-namespace-prefix-map) will be created at the start of the [XML
serialization](#dfn-xml-serialization) algorithm. Whenever a new
[`Element`](https://dom.spec.whatwg.org/#element) is encountered, the map will be cloned ([copy a namespace
prefix
map](#dfn-copy-a-namespace-prefix-map)) and new associations will be added for
that
[`Element`](https://dom.spec.whatwg.org/#element) (primarily in [recording the namespace
information](#dfn-recording-the-namespace-information), but also when adding new namespace
declarations because no prefix is available for a particular namespace).

The last seen prefix for a given namespace is at the end of its
respective [list](https://infra.spec.whatwg.org/#list).
When serializing, the
[Element](https://dom.spec.whatwg.org/#concept-element)\'s
[namespace
prefix](https://dom.spec.whatwg.org/#concept-element-namespace-prefix)
will be used if it is in the
[list](https://infra.spec.whatwg.org/#list); otherwise
the last prefix in the
[list](https://infra.spec.whatwg.org/#list) is used.
See [retrieve a preferred prefix
string](#dfn-retrieving-a-preferred-prefix-string) for additional details.

To [copy a namespace prefix map] `map`:

1. Let `copy` be a new [namespace prefix
 map](#dfn-namespace-prefix-map).

2. [For
 each](https://infra.spec.whatwg.org/#map-iterate)
 `key` → `value` in `map`:

 1. Set `copy`\[`key`\] to a
 [clone](https://infra.spec.whatwg.org/#list-clone)
 of `value`.

3. Return `copy`.

To [retrieve a preferred prefix
string]
`preferred prefix` (a string or null) from the [namespace
prefix
map](#dfn-namespace-prefix-map) `map` given a namespace
`ns`:

1. If `map` does not
 [contain](https://infra.spec.whatwg.org/#map-exists)
 `ns`, return null.

2. Let `candidates` be `map`\[`ns`\].

3. [Assert](https://infra.spec.whatwg.org/#assert):
 `candidates` [is not
 empty](https://infra.spec.whatwg.org/#list-is-empty).

4. If `prefix` is not null, then:

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate)
 `prefix` of `candidates`:

 1. If `prefix` is `preferred prefix`,
 return `prefix`.

5. Return
 `candidates`\[[size](https://infra.spec.whatwg.org/#list-size)
 of `candidates` - 1\].

To check if a string `prefix` is [found] in a [namespace
prefix
map](#dfn-namespace-prefix-map) `map` given a namespace
`ns`:

1. If `map` does not
 [contain](https://infra.spec.whatwg.org/#map-exists)
 `ns`, return false.
2. Let `candidates` be `map`\[`ns`\].
3. If `candidates`
 [contains](https://infra.spec.whatwg.org/#list-contain)
 `prefix`, return true, otherwise return false.

To [add] a string `prefix` to a [namespace prefix
map](#dfn-namespace-prefix-map) `map` given a namespace
`ns`:

1. If `map` does not
 [contain](https://infra.spec.whatwg.org/#map-exists)
 `ns`:

 1. Let `candidates` be « `prefix` ».
 2. Set `map`\[`ns`\] to
 `candidates`.

2. Otherwise:

 1. Let `candidates` be
 `map`\[`ns`\].
 2. [Append](https://infra.spec.whatwg.org/#list-append)
 `prefix` to `candidates`.

The steps in [retrieve a preferred prefix
string](#dfn-retrieving-a-preferred-prefix-string) use the
[list](https://infra.spec.whatwg.org/#list) to track
the most recently used prefix associated with a given namespace, which
will be the prefix at the end of the list. This list can contain
duplicates of the same prefix seen earlier (and that\'s OK).

::: header-wrapper
###### 5.2.1.1.3 Serializing an Element\'s attributes

The [XML serialization of the
attributes] of an
[`Element`](https://dom.spec.whatwg.org/#element) `element` given a [namespace prefix
map](#dfn-namespace-prefix-map) `map`, a mutable reference to
an integer `prefix index`, an [ordered
map](https://infra.spec.whatwg.org/#ordered-map)
`local prefixes map`, a boolean
`ignore namespace definition attribute`, and a boolean
`require well-formed`, is the result of the following
algorithm:

1. Let `result` be the empty string.
2. Let `localname set` be « » (an empty [ordered
 set](https://infra.spec.whatwg.org/#ordered-set)).

 ::::
 :::
 Note
 :::

 `localname set` will contain tuples of unique attribute
 (namespace, local name) pairs, and is populated as each
 `attr` is processed. If `require well-formed`
 is true, it is used to enforce the well-formed constraint that an
 element cannot have two attributes with the same
 [namespace](https://dom.spec.whatwg.org/#concept-attribute-namespace)
 and [local
 name](https://dom.spec.whatwg.org/#concept-attribute-local-name).
 This can occur when two otherwise identical attributes on the same
 element differ only by their prefix values. If
 `require well-formed` is false,
 `localname set` is unnecessary.
 ::::
3. [For
 each](https://infra.spec.whatwg.org/#list-iterate)
 `attr` of `element`\'s [attribute
 list](https://dom.spec.whatwg.org/#concept-element-attribute):
 1. Let `attribute namespace` be `attr`\'s
 [namespace](https://dom.spec.whatwg.org/#concept-attribute-namespace).
 2. Let `attrName` be a new tuple
 (`attribute namespace`, `attr`\'s [local
 name](https://dom.spec.whatwg.org/#concept-attribute-local-name)).
 3. If `require well-formed` is true, and
 `localname set`
 [contains](https://infra.spec.whatwg.org/#list-contain)
 `attrName`, then [throw an
 exception](#dfn-throw-an-exception). [The serialization of
 `attr` would not be well-formed.]
 4. [Append](https://infra.spec.whatwg.org/#set-append)
 `attrName` to `localname set`.
 5. Let `candidate prefix` be null.
 6. If `attribute namespace` is not null, then:
 1. Let `prefix` be `attr`\'s [namespace
 prefix](https://dom.spec.whatwg.org/#concept-attribute-namespace-prefix).
 2. Set `candidate prefix` to the result of
 [retrieving a preferred prefix
 string](#dfn-retrieving-a-preferred-prefix-string) `prefix` from
 `map` given `attribute namespace`.
 3. If `attribute namespace` is the [XMLNS
 namespace](https://infra.spec.whatwg.org/#xmlns-namespace),
 then:
 1. If any of the following are true, then
 [continue](https://infra.spec.whatwg.org/#iteration-continue):
 - `attr`\'s
 [value](https://dom.spec.whatwg.org/#concept-attribute-value)
 is the [XML
 namespace](https://infra.spec.whatwg.org/#xml-namespace);

 ::::
 :::
 Note
 :::

 The [XML
 namespace](https://infra.spec.whatwg.org/#xml-namespace)
 cannot be redeclared and survive
 [round-tripping](#dfn-round-tripping) (unless it defines the
 prefix \"`xml`\"). To avoid this problem, this
 algorithm always prefixes elements in the [XML
 namespace](https://infra.spec.whatwg.org/#xml-namespace)
 with \"`xml`\" and drops any related definitions as
 seen in the above condition.
 ::::
 - `prefix` is null and
 `ignore namespace definition attribute` is
 true (the
 [`Element`](https://dom.spec.whatwg.org/#element)\'s default namespace attribute is to be
 skipped);
 - `prefix` is not null and either
 - `local prefixes map` does not
 [contain](https://infra.spec.whatwg.org/#map-exists)
 `attr`\'s [local
 name](https://dom.spec.whatwg.org/#concept-attribute-local-name),
 or
 - `local prefixes map` does
 [contain](https://infra.spec.whatwg.org/#map-exists)
 `attr`\'s [local
 name](https://dom.spec.whatwg.org/#concept-attribute-local-name),
 but
 `local prefixes map`\[`attr`\'s
 [local
 name](https://dom.spec.whatwg.org/#concept-attribute-local-name)\]
 is not `attr`\'s
 [value](https://dom.spec.whatwg.org/#concept-attribute-value)

 and furthermore that `attr`\'s [local
 name](https://dom.spec.whatwg.org/#concept-attribute-local-name)
 is [found](#dfn-found) in `map`
 given `attr`\'s
 [value](https://dom.spec.whatwg.org/#concept-attribute-value)
 (the current namespace prefix definition was exactly
 defined previously---on an ancestor element, not
 `element`).
 2. If `require well-formed` is true, and
 `attr`\'s
 [value](https://dom.spec.whatwg.org/#concept-attribute-value)
 is the [XMLNS
 namespace](https://infra.spec.whatwg.org/#xmlns-namespace),
 then [throw an
 exception](#dfn-throw-an-exception). [The
 serialization of this attribute would produce invalid
 XML because the [XMLNS
 namespace](https://infra.spec.whatwg.org/#xmlns-namespace)
 is reserved and cannot be applied as an element\'s
 namespace via XML parsing.]

 ::::
 :::
 Note
 :::

 DOM APIs do allow creation of elements in the [XMLNS
 namespace](https://infra.spec.whatwg.org/#xmlns-namespace)
 but with strict qualifications.
 ::::
 3. If `require well-formed` is true, and
 `attr`\'s
 [value](https://dom.spec.whatwg.org/#concept-attribute-value)
 is the empty string, then [throw an
 exception](#dfn-throw-an-exception). [Namespace
 prefix declarations cannot be used to undeclare a
 namespace (use a default namespace declaration
 instead).]
 4. If `prefix` is \"`xmlns`\", then set
 `candidate prefix` to \"`xmlns`\".
 4. Otherwise (`attribute namespace` is not the
 [XMLNS
 namespace](https://infra.spec.whatwg.org/#xmlns-namespace)),
 if `candidate prefix` is null:
 1. If `prefix` is not null and
 `local prefixes map` does not
 [contain](https://infra.spec.whatwg.org/#map-exists)
 `prefix`, set `candidate prefix`
 to `prefix`.
 2. Otherwise, set `candidate prefix` to the
 result of [generating a
 prefix](#dfn-generating-a-prefix) given `map`,
 `attribute namespace`, and
 `prefix index`.
 3. [Add](#dfn-add)
 `candidate prefix` to `map` given
 `attribute namespace`.
 4. Let `map value` be the empty string if
 `attribute namespace` is null, and
 `attribute namespace` otherwise.
 5. [Set](https://infra.spec.whatwg.org/#map-set)
 `local prefixes map`\[`candidate prefix`\]
 to `map value`.
 6. Append the following to `result`, in the
 order listed:
 1. \"` `\" (U+0020 SPACE);
 2. \"`xmlns:`\";
 3. `candidate prefix`;
 4. \"`="`\" (U+003D EQUALS SIGN, U+0022 QUOTATION
 MARK);
 5. The result of [serializing an attribute
 value](#dfn-serializing-an-attribute-value) given
 `attribute namespace` and
 `require well-formed`;
 6. \"`"`\" (U+0022 QUOTATION MARK).
 7. Append \"` `\" (U+0020 SPACE) to `result`.
 8. If `candidate prefix` is not null, then append to
 `result` the concatenation of
 `candidate prefix` and \"`:`\" (U+003A COLON).
 9. If `require well-formed` is true, and
 `attr`\'s [local
 name](https://dom.spec.whatwg.org/#concept-attribute-local-name)
 contains the character \"`:`\" (U+003A COLON) or does not match
 the XML [Name](#dfn-name) production or equals \"`xmlns`\" and
 `attribute namespace` is null, then [throw an
 exception](#dfn-throw-an-exception). [The serialization of
 `attr` would not be well-formed.]
 10. Append the following to `result`, in the order
 listed:
 1. `attr`\'s [local
 name](https://dom.spec.whatwg.org/#concept-attribute-local-name);
 2. \"`="`\" (U+003D EQUALS SIGN, U+0022 QUOTATION MARK);
 3. The result of [serializing an attribute
 value](#dfn-serializing-an-attribute-value) given `attr`\'s
 [value](https://dom.spec.whatwg.org/#concept-attribute-value)
 and `require well-formed`;
 4. \"`"`\" (U+0022 QUOTATION MARK).
4. Return `result`.

When [serializing an attribute
value] given a string or null
`attribute value` and a boolean
`require well-formed`, run the following steps:

1. If `require well-formed` is true, and
 `attribute value` contains characters that are not
 matched by the XML [Char](#dfn-char) production, then [throw an
 exception](#dfn-throw-an-exception). [The serialization of
 `attribute value` would not be well-formed.]
2. If `attribute value` is null, then return the empty
 string.
3. Otherwise, return `attribute value`, first replacing any
 occurrences of the following:
 1. \"`&`\" with \"`&amp;`\"
 2. \"`"`\" with \"`&quot;`\"
 3. \"`<`\" with \"`&lt;`\"
 4. U+0009 CHARACTER TABULATION with \"`&#9;`\"
 5. U+000A LINE FEED (LF) with \"`&#xA;`\"
 6. U+000D CARRIAGE RETURN (CR) with \"`&#xD;`\"

 ::::
 :::
 Note
 :::

 This matches behavior present in browsers, and goes above and beyond
 the grammar requirement in the XML specification\'s
 [AttValue](#dfn-attvalue) production by also replacing \"`>`\" characters.
 ::::

::: header-wrapper
###### 5.2.1.1.4 Generating namespace prefixes

To [generate a prefix] given a [namespace prefix
map](#dfn-namespace-prefix-map) `map`, a string
`new namespace`, and a mutable reference to an integer
`prefix index`:

1. Let `generated prefix` be the concatenation of \"`ns`\"
 and the current numerical value of `prefix index`.
2. Increment the value of `prefix index` by one.
3. [Add](#dfn-add)
 `generated prefix` to `map` given
 `new namespace`.
4. Return the value of `generated prefix`.

[[Issue
44]](https://github.com/w3c/DOM-Parsing/issues/44)[:
It\'s possible for \'generate a prefix\' algorithm to generate a prefix
conflicting with an existing one
[xml-serialization](https://github.com/w3c/DOM-Parsing/issues/?q=is%3Aissue+is%3Aopen+label%3A%22xml-serialization%22)]

[https://w3c.github.io/DOM-Parsing/#generating-namespace-prefixes](https://w3c.github.io/DOM-Parsing/#generating-namespace-prefixes){rel="nofollow"}

The algorithm just generates \'ns1\', \'ns2\', \... without checking
existence of generated prefixes.\
So, the following example serializes two `xmlns:ns1` on
`child` element if we follow the current specification.
WPT domparsing/XMLSerializer-serializeToString.html already has a test
case
(`"Check if "ns1" is generated even if the element already has xmlns:ns1."`).

``` notranslate
const root = (new DOMParser()).parseFromString('<root xmlns:ns2="uri2"><child xmlns:ns1="uri1" xmlns:a0="uri1" xmlns:NS1="uri1"/></root>', 'text/xml').documentElement;
root.firstChild.setAttributeNS('uri3', 'attr1', 'value1');
console.log((new XMLSerializer()).serializeToString(root));
```

The algorithm should have a loop until a generated prefix is not
[found](https://w3c.github.io/DOM-Parsing/#dfn-found){rel="nofollow"}.

::: header-wrapper
##### 5.2.1.2 XML serializing a Document node

The algorithm for [XML serializing a Document
node], given a
[`Document`](https://dom.spec.whatwg.org/#document) `node`, a string
`namespace`, a [namespace prefix
map](#dfn-namespace-prefix-map) `prefix map`, a mutable reference to an integer
`prefix index`,
and a boolean `require well-formed`, must run the following
steps:

1. If `require well-formed` is true, and `node`\'s [document
 element](https://dom.spec.whatwg.org/#document-element)
 is null, then [throw an
 exception](#dfn-throw-an-exception). [The serialization of
 `node` would not be
 well-formed.]
2. Otherwise:
 1. Let `serialized document` be the empty string.

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate)
 `child` of `node`\'s
 [children](https://dom.spec.whatwg.org/#concept-tree-child):

 1. Append to `serialized document` the result of
 running the [XML serialization
 algorithm](#dfn-xml-serialization-algorithm) given `child`,
 `inherited ns`, `map`,
 `prefix index`, and
 `require well-formed`.

 ::::
 :::
 Note
 :::

 This will serialize any number of
 [`ProcessingInstruction`](https://dom.spec.whatwg.org/#processinginstruction) and
 [`Comment`](https://dom.spec.whatwg.org/#comment) nodes both before and after the [document
 element](https://dom.spec.whatwg.org/#document-element),
 as well as at most one
 [`DocumentType`](https://dom.spec.whatwg.org/#documenttype) node.
 ([`Text`](https://dom.spec.whatwg.org/#text) nodes are not allowed as children of a
 [`Document`](https://dom.spec.whatwg.org/#document).)
 ::::

 3. Return `serialized document`.

::: header-wrapper
##### 5.2.1.3 XML serializing a Comment node

The algorithm for [XML serializing a Comment
node], given a
[`Comment`](https://dom.spec.whatwg.org/#comment) `node`, and a boolean
`require well-formed`, must run the following steps:

1. If `require well-formed` is true, and `node`\'s
 [data](https://dom.spec.whatwg.org/#concept-cd-data)
 contains characters that are not matched by the XML
 [Char](#dfn-char)
 production or contains \"`--`\" (two adjacent U+002D HYPHEN-MINUS
 characters) or ends with a \"`-`\" (U+002D HYPHEN-MINUS) character,
 then [throw an
 exception](#dfn-throw-an-exception). [The serialization of
 `node` would not be
 well-formed.]
2. Otherwise, return the concatenation of \"`<!--`\", `node`\'s
 [data](https://dom.spec.whatwg.org/#concept-cd-data),
 and \"`-->`\".

::: header-wrapper
##### 5.2.1.4 XML serializing a CDATASection node

The algorithm for [XML serializing a CDATASection
node], given a
[`CDATASection`](https://dom.spec.whatwg.org/#cdatasection) `node`, and a
boolean `require well-formed`, must run the following steps:

1. Let `markup` be the concatenation of \"`<![CDATA[`\",
 `node`\'s
 [data](https://dom.spec.whatwg.org/#concept-cd-data),
 and \"`]]>`\".
2. Return `markup`.

::: header-wrapper
##### 5.2.1.5 XML serializing a Text node

The algorithm for [XML serializing a Text
node], given a
[`Text`](https://dom.spec.whatwg.org/#text) `node`, and a boolean
`require well-formed`, must run the following steps:

1. Let `markup` be `node`\'s
 [data](https://dom.spec.whatwg.org/#concept-cd-data).
2. If `require well-formed` is true, and `markup`
 contains characters that are not matched by the XML
 [Char](#dfn-char)
 production, then [throw an
 exception](#dfn-throw-an-exception). [The serialization of
 `node` would not be well-formed.]
3. Replace any occurrences of \"`&`\" in `markup` by
 \"`&amp;`\".
4. Replace any occurrences of \"`<`\" in `markup` by
 \"`&lt;`\".
5. Replace any occurrences of \"`>`\" in `markup` by
 \"`&gt;`\".
6. Return `markup`.

::: header-wrapper
##### 5.2.1.6 XML serializing a DocumentFragment node

The algorithm for [XML serializing a DocumentFragment
node], given a
[`DocumentFragment`](https://dom.spec.whatwg.org/#documentfragment) `node`, a
string `namespace`, a [namespace prefix
map](#dfn-namespace-prefix-map) `prefix map`, a mutable reference to an integer
`prefix index`,
and a boolean `require well-formed`, must run the following
steps:

1. Let `markup` be the empty string.

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate)
 `child` of `node`\'s
 [children](https://dom.spec.whatwg.org/#concept-tree-child):

 1. Append to `markup` the result of running the [XML
 serialization
 algorithm](#dfn-xml-serialization-algorithm) given `child`,
 `inherited ns`, `map`,
 `prefix index`, and
 `require well-formed`.

3. Return `markup`.

::: header-wrapper
##### 5.2.1.7 XML serializing a DocumentType node

The algorithm for [XML serializing a DocumentType
node], given a
[`DocumentType`](https://dom.spec.whatwg.org/#documenttype) `node`, and a
boolean `require well-formed`, must run the following steps:

1. If `require well-formed` is true, and `node`\'s [public
 ID](https://dom.spec.whatwg.org/#concept-doctype-publicid)
 contains characters that are not matched by the XML
 [PubidChar](#dfn-pubidchar) production, then [throw an
 exception](#dfn-throw-an-exception). [The serialization of
 `node` would not be
 well-formed.]
2. If `require well-formed` is true, and `node`\'s [system
 ID](https://dom.spec.whatwg.org/#concept-doctype-systemid)
 contains characters that are not matched by the XML
 [Char](#dfn-char)
 production or that contains both a \"`"`\" (U+0022 QUOTATION MARK)
 and a \"`'`\" (U+0027 APOSTROPHE), then [throw an
 exception](#dfn-throw-an-exception). [The serialization of
 `node` would not be
 well-formed.]
3. Let `markup` be the empty string.
4. Append \"`<!DOCTYPE`\" to `markup`.
5. Append \"` `\" (U+0020 SPACE) to `markup`.
6. Append `node`\'s
 [name](#dfn-name) to `markup`. [For a
 `node` belonging to an [HTML
 document](https://dom.spec.whatwg.org/#html-document),
 the name will be all lowercase.]
7. If `node`\'s [public
 ID](https://dom.spec.whatwg.org/#concept-doctype-publicid)
 is not the empty string, then append the following, in the order
 listed, to `markup`:
 1. \"` `\" (U+0020 SPACE);
 2. \"`PUBLIC`\";
 3. \"` `\" (U+0020 SPACE);
 4. the [serialization of the
 ID](#dfn-serialization-of-the-id) `node`\'s [public
 ID](https://dom.spec.whatwg.org/#concept-doctype-publicid).
8. If `node`\'s [system
 ID](https://dom.spec.whatwg.org/#concept-doctype-systemid)
 is not the empty string and `node`\'s [public
 ID](https://dom.spec.whatwg.org/#concept-doctype-publicid)
 is the empty string, then append the following, in the order listed,
 to `markup`:
 1. \"` `\" (U+0020 SPACE);
 2. \"`SYSTEM`\".
9. If `node`\'s [system
 ID](https://dom.spec.whatwg.org/#concept-doctype-systemid)
 is not the empty string, then append the following, in the order
 listed, to `markup`:
 1. \"` `\" (U+0020 SPACE);
 2. the [serialization of the
 ID](#dfn-serialization-of-the-id) `node`\'s [system
 ID](https://dom.spec.whatwg.org/#concept-doctype-systemid).
10. Append \"`>`\" (U+003E GREATER-THAN SIGN) to `markup`.
11. Return `markup`.

The [serialization of the ID] `id` is the result of the following steps:

1. If `id` contains \"`"`\" (U+0022
 QUOTATION MARK), let `q` be \"`'`\" (U+0027 APOSTROPHE),
 and let `q` be \"`"`\" (U+0022 QUOTATION MARK) otherwise.
2. Return the concatenation of `q`, `id`, and `q`.

::: header-wrapper
##### 5.2.1.8 XML serializing a ProcessingInstruction node

The algorithm for [XML serializing a ProcessingInstruction
node], given a
[`ProcessingInstruction`](https://dom.spec.whatwg.org/#processinginstruction) `node`, and a boolean
`require well-formed`, must run the following steps:

1. If `require well-formed` is true, and `node`\'s
 [target](https://dom.spec.whatwg.org/#concept-pi-target)
 contains a \"`:`\" (U+003A COLON) character or is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
 match for \"`xml`\", then [throw an
 exception](#dfn-throw-an-exception). [The serialization of
 `node` would not be
 well-formed.]
2. If `require well-formed` is true, and `node`\'s
 [data](https://dom.spec.whatwg.org/#concept-cd-data)
 contains characters that are not matched by the XML
 [Char](#dfn-char)
 production or contains \"`?>`\" (U+003F QUESTION MARK, U+003E
 GREATER-THAN SIGN), then [throw an
 exception](#dfn-throw-an-exception). [The serialization of
 `node` would not be
 well-formed.]
3. Let `markup` be the concatenation of the following, in
 the order listed:
 1. \"`<?`\" (U+003C LESS-THAN SIGN, U+003F QUESTION MARK);
 2. `node`\'s
 [target](https://dom.spec.whatwg.org/#concept-pi-target);
 3. \"` `\" (U+0020 SPACE);
 4. `node`\'s
 [data](https://dom.spec.whatwg.org/#concept-cd-data);
 5. \"`?>`\" (U+003F QUESTION MARK, U+003E GREATER-THAN SIGN).
4. Return `markup`.

::: header-wrapper
## A. Dependencies

The HTML specification \[[HTML](#bib-html "HTML Standard")\] defines the following terms used in this document:

- Parsing concepts: [[HTML
 parser](https://www.w3.org/TR/html5/single-page.html#html-parser)]; [[parsing
 XHTML
 documents](https://www.w3.org/TR/html5/single-page.html#parsing-xhtml-documents)]; [[XML
 parser](https://www.w3.org/TR/html5/single-page.html#xml-parser)]
- The
 [`template`](https://html.spec.whatwg.org/multipage/scripting.html#the-template-element)\'s
 [[template
 contents](https://www.w3.org/TR/html5/single-page.html#template-contents)]
- The
 [[innerHTML](https://html.spec.whatwg.org/dynamic-markup-insertion.html#dom-element-innerhtml)] property;
- The
 [[outerHTML](https://html.spec.whatwg.org/dynamic-markup-insertion.html#dom-element-outerhtml)] property;
- The
 [[insertAdjacentHTML](https://html.spec.whatwg.org/dynamic-markup-insertion.html#dom-element-insertadjacenthtml)] method;

The following terms used in this document are defined by
\[[XML10](#bib-xml10 "Extensible Markup Language (XML) 1.0 (Fifth Edition)")\]:

- The
 [[`AttValue`](https://www.w3.org/TR/xml/#NT-AttValue)],
 [[`Char`](https://www.w3.org/TR/xml/#NT-Char)],
 [[`EmptyElemTag`](https://www.w3.org/TR/xml/#NT-EmptyElemTag)],
 [[`Name`](https://www.w3.org/TR/xml/#NT-Name)] and
 [[`PubidChar`](https://www.w3.org/TR/xml/#NT-PubidChar)] productions
- [[empty-element
 tag](https://www.w3.org/TR/xml/#dt-eetag)]

::: header-wrapper
## B. Revision History

The following is an informative summary of the changes since the last
publication of this specification. A complete revision history of the
Editor\'s Drafts of this specification can be found at the [[W3C] Github
Repository](https://github.com/w3c/DOM-Parsing/commits/gh-pages) and
older revisions at the [[W3C]
Mercurial server](https://dvcs.w3.org/hg/innerhtml/summary/).

- 2016-06 WD - Editorial restructuring of the document; monolithic XML
 serialization algorithm factored into sections. Dependencies
 clarified. XML Serialization algorithm updated to get closer to
 interoperable browser behavior.
- [Incorporated non-normative changes from previous Last Call
 document.](https://dvcs.w3.org/hg/innerhtml/raw-file/tip/LC2_comments.html)

::: header-wrapper
## C. Acknowledgements

We acknowledge with gratitude the original work of Ms2ger and others at
the WHATWG, who created and maintained the original DOM Parsing and
Serialization Living Standard upon which this specification is based.

Thanks to C. Scott Ananian, Victor Costan, Aryeh Gregor, Anne van
Kesteren, Arkadiusz Michalski, Simon Pieters, Henri Sivonen, Josh Soref
and Boris Zbarsky, for their useful comments.

Special thanks to Ian Hickson for first defining the
[innerHTML](#dfn-innerhtml) and
[outerHTML](#dfn-outerhtml) attributes, and the
[insertAdjacentHTML](#dfn-insertadjacenthtml) method in
\[[HTML](#bib-html "HTML Standard")\] and
his useful comments.

::: header-wrapper
## D. References

::: header-wrapper
### D.1 Normative references

\[DOM\]
: [DOM Standard](https://dom.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://dom.spec.whatwg.org/>

\[ECMA-262\]
: [ECMAScript Language
 Specification](https://tc39.es/ecma262/multipage/). Ecma
 International. URL: <https://tc39.es/ecma262/multipage/>

\[HTML\]
: [HTML Standard](https://html.spec.whatwg.org/multipage/). Anne van
 Kesteren; Domenic Denicola; Dominic Farolino; Ian Hickson; Philip
 Jägenstedt; Simon Pieters. WHATWG. Living Standard. URL:
 <https://html.spec.whatwg.org/multipage/>

\[INFRA\]
: [Infra Standard](https://infra.spec.whatwg.org/). Anne van Kesteren;
 Domenic Denicola. WHATWG. Living Standard. URL:
 <https://infra.spec.whatwg.org/>

\[WEBIDL\]
: [Web IDL Standard](https://webidl.spec.whatwg.org/). Edgar Chen;
 Timothy Gu. WHATWG. Living Standard. URL:
 <https://webidl.spec.whatwg.org/>

\[XML10\]
: [Extensible Markup Language (XML) 1.0 (Fifth
 Edition)](https://www.w3.org/TR/xml/). Tim Bray; Jean Paoli; Michael
 Sperberg-McQueen; Eve Maler; François Yergeau et al. W3C. 26
 November 2008. W3C Recommendation. URL: <https://www.w3.org/TR/xml/>

[[↑]](#title)

[Permalink](#dfn-applicable-specification)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-parsing)

**Referenced in:**

- [§ 3. Introduction](#ref-for-dfn-parsing-1 "§ 3. Introduction")

[Permalink](#dfn-serializing)

**Referenced in:**

- [§ 3. Introduction](#ref-for-dfn-serializing-1 "§ 3. Introduction")

[Permalink](#dfn-round-tripping)

**Referenced in:**

- [§ 3. Introduction](#ref-for-dfn-round-tripping-1 "§ 3. Introduction")
 [(2)](#ref-for-dfn-round-tripping-2 "Reference 2")
- [§ 5.2.1.1.3 Serializing an Element\'s
 attributes](#ref-for-dfn-round-tripping-3 "§ 5.2.1.1.3 Serializing an Element's attributes")

[Permalink](#dfn-xml-serialization)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-xml-serialization-1 "§ 5.2.1 XML Serialization")
 [(2)](#ref-for-dfn-xml-serialization-2 "Reference 2")
 [(3)](#ref-for-dfn-xml-serialization-3 "Reference 3")
- [§ 5.2.1.1.2 The Namespace Prefix
 Map](#ref-for-dfn-xml-serialization-4 "§ 5.2.1.1.2 The Namespace Prefix Map")

[Permalink](#dfn-throw-an-exception)

**Referenced in:**

- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-throw-an-exception-1 "§ 5.2.1.1 XML serializing an Element node")
 [(2)](#ref-for-dfn-throw-an-exception-2 "Reference 2")
- [§ 5.2.1.1.3 Serializing an Element\'s
 attributes](#ref-for-dfn-throw-an-exception-3 "§ 5.2.1.1.3 Serializing an Element's attributes")
 [(2)](#ref-for-dfn-throw-an-exception-4 "Reference 2")
 [(3)](#ref-for-dfn-throw-an-exception-5 "Reference 3")
 [(4)](#ref-for-dfn-throw-an-exception-6 "Reference 4")
 [(5)](#ref-for-dfn-throw-an-exception-7 "Reference 5")
- [§ 5.2.1.2 XML serializing a Document
 node](#ref-for-dfn-throw-an-exception-8 "§ 5.2.1.2 XML serializing a Document node")
- [§ 5.2.1.3 XML serializing a Comment
 node](#ref-for-dfn-throw-an-exception-9 "§ 5.2.1.3 XML serializing a Comment node")
- [§ 5.2.1.5 XML serializing a Text
 node](#ref-for-dfn-throw-an-exception-10 "§ 5.2.1.5 XML serializing a Text node")
- [§ 5.2.1.7 XML serializing a DocumentType
 node](#ref-for-dfn-throw-an-exception-11 "§ 5.2.1.7 XML serializing a DocumentType node")
 [(2)](#ref-for-dfn-throw-an-exception-12 "Reference 2")
- [§ 5.2.1.8 XML serializing a ProcessingInstruction
 node](#ref-for-dfn-throw-an-exception-13 "§ 5.2.1.8 XML serializing a ProcessingInstruction node")
 [(2)](#ref-for-dfn-throw-an-exception-14 "Reference 2")

[Permalink](#dfn-xml-serialization-algorithm)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-xml-serialization-algorithm-1 "§ 5.2.1 XML Serialization")
- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-xml-serialization-algorithm-2 "§ 5.2.1.1 XML serializing an Element node")
- [§ 5.2.1.2 XML serializing a Document
 node](#ref-for-dfn-xml-serialization-algorithm-3 "§ 5.2.1.2 XML serializing a Document node")
- [§ 5.2.1.6 XML serializing a DocumentFragment
 node](#ref-for-dfn-xml-serialization-algorithm-4 "§ 5.2.1.6 XML serializing a DocumentFragment node")

[Permalink](#dfn-xml-serializing-an-element-node)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-xml-serializing-an-element-node-1 "§ 5.2.1 XML Serialization")

[Permalink](#dfn-found-a-suitable-namespace-prefix)

**Referenced in:**

- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-found-a-suitable-namespace-prefix-1 "§ 5.2.1.1 XML serializing an Element node")

[Permalink](#dfn-recording-the-namespace-information)

**Referenced in:**

- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-recording-the-namespace-information-1 "§ 5.2.1.1 XML serializing an Element node")
- [§ 5.2.1.1.2 The Namespace Prefix
 Map](#ref-for-dfn-recording-the-namespace-information-2 "§ 5.2.1.1.2 The Namespace Prefix Map")

[Permalink](#dfn-namespace-prefix-map)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-namespace-prefix-map-1 "§ 5.2.1 XML Serialization")
 [(2)](#ref-for-dfn-namespace-prefix-map-2 "Reference 2")
- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-namespace-prefix-map-3 "§ 5.2.1.1 XML serializing an Element node")
 [(2)](#ref-for-dfn-namespace-prefix-map-4 "Reference 2")
- [§ 5.2.1.1.1 Recording the
 namespace](#ref-for-dfn-namespace-prefix-map-5 "§ 5.2.1.1.1 Recording the namespace")
 [(2)](#ref-for-dfn-namespace-prefix-map-6 "Reference 2")
- [§ 5.2.1.1.2 The Namespace Prefix
 Map](#ref-for-dfn-namespace-prefix-map-7 "§ 5.2.1.1.2 The Namespace Prefix Map")
 [(2)](#ref-for-dfn-namespace-prefix-map-8 "Reference 2")
 [(3)](#ref-for-dfn-namespace-prefix-map-9 "Reference 3")
 [(4)](#ref-for-dfn-namespace-prefix-map-10 "Reference 4")
 [(5)](#ref-for-dfn-namespace-prefix-map-11 "Reference 5")
- [§ 5.2.1.1.3 Serializing an Element\'s
 attributes](#ref-for-dfn-namespace-prefix-map-12 "§ 5.2.1.1.3 Serializing an Element's attributes")
- [§ 5.2.1.1.4 Generating namespace
 prefixes](#ref-for-dfn-namespace-prefix-map-13 "§ 5.2.1.1.4 Generating namespace prefixes")
- [§ 5.2.1.2 XML serializing a Document
 node](#ref-for-dfn-namespace-prefix-map-14 "§ 5.2.1.2 XML serializing a Document node")
- [§ 5.2.1.6 XML serializing a DocumentFragment
 node](#ref-for-dfn-namespace-prefix-map-15 "§ 5.2.1.6 XML serializing a DocumentFragment node")

[Permalink](#dfn-copy-a-namespace-prefix-map)

**Referenced in:**

- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-copy-a-namespace-prefix-map-1 "§ 5.2.1.1 XML serializing an Element node")
- [§ 5.2.1.1.2 The Namespace Prefix
 Map](#ref-for-dfn-copy-a-namespace-prefix-map-2 "§ 5.2.1.1.2 The Namespace Prefix Map")

[Permalink](#dfn-retrieving-a-preferred-prefix-string)

**Referenced in:**

- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-retrieving-a-preferred-prefix-string-1 "§ 5.2.1.1 XML serializing an Element node")
 [(2)](#ref-for-dfn-retrieving-a-preferred-prefix-string-2 "Reference 2")
- [§ 5.2.1.1.2 The Namespace Prefix
 Map](#ref-for-dfn-retrieving-a-preferred-prefix-string-3 "§ 5.2.1.1.2 The Namespace Prefix Map")
 [(2)](#ref-for-dfn-retrieving-a-preferred-prefix-string-4 "Reference 2")
- [§ 5.2.1.1.3 Serializing an Element\'s
 attributes](#ref-for-dfn-retrieving-a-preferred-prefix-string-5 "§ 5.2.1.1.3 Serializing an Element's attributes")

[Permalink](#dfn-found)

**Referenced in:**

- [§ 5.2.1.1.1 Recording the
 namespace](#ref-for-dfn-found-1 "§ 5.2.1.1.1 Recording the namespace")
- [§ 5.2.1.1.3 Serializing an Element\'s
 attributes](#ref-for-dfn-found-2 "§ 5.2.1.1.3 Serializing an Element's attributes")

[Permalink](#dfn-add)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-add-1 "§ 5.2.1 XML Serialization")
- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-add-2 "§ 5.2.1.1 XML serializing an Element node")
 [(2)](#ref-for-dfn-add-3 "Reference 2")
- [§ 5.2.1.1.1 Recording the
 namespace](#ref-for-dfn-add-4 "§ 5.2.1.1.1 Recording the namespace")
- [§ 5.2.1.1.3 Serializing an Element\'s
 attributes](#ref-for-dfn-add-5 "§ 5.2.1.1.3 Serializing an Element's attributes")
- [§ 5.2.1.1.4 Generating namespace
 prefixes](#ref-for-dfn-add-6 "§ 5.2.1.1.4 Generating namespace prefixes")

[Permalink](#dfn-xml-serialization-of-the-attributes)

**Referenced in:**

- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-xml-serialization-of-the-attributes-1 "§ 5.2.1.1 XML serializing an Element node")
 [(2)](#ref-for-dfn-xml-serialization-of-the-attributes-2 "Reference 2")

[Permalink](#dfn-serializing-an-attribute-value)

**Referenced in:**

- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-serializing-an-attribute-value-1 "§ 5.2.1.1 XML serializing an Element node")
 [(2)](#ref-for-dfn-serializing-an-attribute-value-2 "Reference 2")
- [§ 5.2.1.1.3 Serializing an Element\'s
 attributes](#ref-for-dfn-serializing-an-attribute-value-3 "§ 5.2.1.1.3 Serializing an Element's attributes")
 [(2)](#ref-for-dfn-serializing-an-attribute-value-4 "Reference 2")

[Permalink](#dfn-generating-a-prefix)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-generating-a-prefix-1 "§ 5.2.1 XML Serialization")
- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-generating-a-prefix-2 "§ 5.2.1.1 XML serializing an Element node")
 [(2)](#ref-for-dfn-generating-a-prefix-3 "Reference 2")
 [(3)](#ref-for-dfn-generating-a-prefix-4 "Reference 3")
- [§ 5.2.1.1.3 Serializing an Element\'s
 attributes](#ref-for-dfn-generating-a-prefix-5 "§ 5.2.1.1.3 Serializing an Element's attributes")

[Permalink](#dfn-xml-serializing-a-document-node)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-xml-serializing-a-document-node-1 "§ 5.2.1 XML Serialization")

[Permalink](#dfn-xml-serializing-a-comment-node)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-xml-serializing-a-comment-node-1 "§ 5.2.1 XML Serialization")

[Permalink](#dfn-xml-serializing-a-cdatasection-node)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-xml-serializing-a-cdatasection-node-1 "§ 5.2.1 XML Serialization")

[Permalink](#dfn-xml-serializing-a-text-node)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-xml-serializing-a-text-node-1 "§ 5.2.1 XML Serialization")

[Permalink](#dfn-xml-serializing-a-documentfragment-node)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-xml-serializing-a-documentfragment-node-1 "§ 5.2.1 XML Serialization")
- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-xml-serializing-a-documentfragment-node-2 "§ 5.2.1.1 XML serializing an Element node")

[Permalink](#dfn-xml-serializing-a-documenttype-node)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-xml-serializing-a-documenttype-node-1 "§ 5.2.1 XML Serialization")

[Permalink](#dfn-serialization-of-the-id)

**Referenced in:**

- [§ 5.2.1.7 XML serializing a DocumentType
 node](#ref-for-dfn-serialization-of-the-id-1 "§ 5.2.1.7 XML serializing a DocumentType node")
 [(2)](#ref-for-dfn-serialization-of-the-id-2 "Reference 2")

[Permalink](#dfn-xml-serializing-a-processinginstruction-node)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-xml-serializing-a-processinginstruction-node-1 "§ 5.2.1 XML Serialization")

[Permalink](#dfn-html-parser)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-html-parser-1 "§ 5.2.1 XML Serialization")

[Permalink](#dfn-parsing-xhtml-documents)

**Referenced in:**

- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-parsing-xhtml-documents-1 "§ 5.2.1.1 XML serializing an Element node")

[Permalink](#dfn-xml-parser)

**Referenced in:**

- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-xml-parser-1 "§ 5.2.1.1 XML serializing an Element node")

[Permalink](#dfn-template-content)

**Referenced in:**

- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-template-content-1 "§ 5.2.1.1 XML serializing an Element node")
 [(2)](#ref-for-dfn-template-content-2 "Reference 2")

[Permalink](#dfn-innerhtml)

**Referenced in:**

- [§ 3. Introduction](#ref-for-dfn-innerhtml-1 "§ 3. Introduction")
 [(2)](#ref-for-dfn-innerhtml-2 "Reference 2")
 [(3)](#ref-for-dfn-innerhtml-3 "Reference 3")
- [§ 4.3 The InnerHTML
 mixin](#ref-for-dfn-innerhtml-4 "§ 4.3 The InnerHTML mixin")
- [§ C.
 Acknowledgements](#ref-for-dfn-innerhtml-5 "§ C. Acknowledgements")

[Permalink](#dfn-outerhtml)

**Referenced in:**

- [§ 4.4 Extensions to the Element
 interface](#ref-for-dfn-outerhtml-1 "§ 4.4 Extensions to the Element interface")
- [§ C.
 Acknowledgements](#ref-for-dfn-outerhtml-2 "§ C. Acknowledgements")

[Permalink](#dfn-insertadjacenthtml)

**Referenced in:**

- [§ 4.4 Extensions to the Element
 interface](#ref-for-dfn-insertadjacenthtml-1 "§ 4.4 Extensions to the Element interface")
- [§ C.
 Acknowledgements](#ref-for-dfn-insertadjacenthtml-2 "§ C. Acknowledgements")

[Permalink](#dfn-attvalue)

**Referenced in:**

- [§ 5.2.1.1.3 Serializing an Element\'s
 attributes](#ref-for-dfn-attvalue-1 "§ 5.2.1.1.3 Serializing an Element's attributes")

[Permalink](#dfn-char)

**Referenced in:**

- [§ 5.2.1.1.3 Serializing an Element\'s
 attributes](#ref-for-dfn-char-1 "§ 5.2.1.1.3 Serializing an Element's attributes")
- [§ 5.2.1.3 XML serializing a Comment
 node](#ref-for-dfn-char-2 "§ 5.2.1.3 XML serializing a Comment node")
- [§ 5.2.1.5 XML serializing a Text
 node](#ref-for-dfn-char-3 "§ 5.2.1.5 XML serializing a Text node")
- [§ 5.2.1.7 XML serializing a DocumentType
 node](#ref-for-dfn-char-4 "§ 5.2.1.7 XML serializing a DocumentType node")
- [§ 5.2.1.8 XML serializing a ProcessingInstruction
 node](#ref-for-dfn-char-5 "§ 5.2.1.8 XML serializing a ProcessingInstruction node")

[Permalink](#dfn-emptyelemtag)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-emptyelemtag-1 "§ 5.2.1 XML Serialization")

[Permalink](#dfn-name)

**Referenced in:**

- [§ 5.2.1.1 XML serializing an Element
 node](#ref-for-dfn-name-1 "§ 5.2.1.1 XML serializing an Element node")
- [§ 5.2.1.1.3 Serializing an Element\'s
 attributes](#ref-for-dfn-name-2 "§ 5.2.1.1.3 Serializing an Element's attributes")
- [§ 5.2.1.7 XML serializing a DocumentType
 node](#ref-for-dfn-name-3 "§ 5.2.1.7 XML serializing a DocumentType node")

[Permalink](#dfn-pubidchar)

**Referenced in:**

- [§ 5.2.1.7 XML serializing a DocumentType
 node](#ref-for-dfn-pubidchar-1 "§ 5.2.1.7 XML serializing a DocumentType node")

[Permalink](#dfn-empty-element-tag)

**Referenced in:**

- [§ 5.2.1 XML
 Serialization](#ref-for-dfn-empty-element-tag-1 "§ 5.2.1 XML Serialization")
 [(2)](#ref-for-dfn-empty-element-tag-2 "Reference 2")
