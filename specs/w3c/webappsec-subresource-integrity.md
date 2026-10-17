## 1. Introduction

Sites and applications on the web are rarely composed of resources from
only a single origin. For example, authors pull scripts and styles from
a wide variety of services and content delivery networks, and must trust
that the delivered representation is, in fact, what they expected to
load. If an attacker can trick a user into downloading content from a
hostile server (via DNS
[\[RFC1035\]](#biblio-rfc1035 "Domain names - implementation and specification")
poisoning, or other such means), the author has no recourse. Likewise,
an attacker who can replace the file on the Content Delivery Network
(CDN) server has the ability to inject arbitrary content.

Delivering resources over a secure channel mitigates some of this risk:
with TLS
[\[TLS\]](#biblio-tls "The Transport Layer Security (TLS) Protocol Version 1.3"),
HSTS
[\[RFC6797\]](#biblio-rfc6797 "HTTP Strict Transport Security (HSTS)"),
and pinned public keys
[\[RFC7469\]](#biblio-rfc7469 "Public Key Pinning Extension for HTTP"),
a user agent can be fairly certain that it is indeed speaking with the
server it believes it's talking to. These mechanisms, however,
authenticate *only* the server, *not* the content. An attacker (or
administrator) with access to the server can manipulate content with
impunity. Ideally, authors would not only be able to pin the keys of a
server, but also pin the *content*, ensuring that an exact
representation of a resource, and *only* that representation, loads and
executes.

This document specifies such a validation scheme, extending two HTML
elements with an `integrity` attribute that contains a cryptographic
hash of the representation of the resource the author expects to load.
For instance, an author may wish to load some framework from a shared
server rather than hosting it on their own origin. Specifying that the
*expected* SHA-384 hash of `https://example.com/example-framework.js` is
`Li9vy3DqF8tnTXuiaAJuML3ky+er10rcgNR/VqsVpcw+ThHmYcwiB1pbOxEbzJr7` means
that the user agent can verify that the data it loads from that URL
matches that expected hash before executing the JavaScript it contains.
This integrity verification significantly reduces the risk that an
attacker can substitute malicious content.

This example can be communicated to a user agent by adding the hash to a
`script` element, like so:

``` highlight
<script src="https://example.com/example-framework.js"
 integrity="sha384-Li9vy3DqF8tnTXuiaAJuML3ky+er10rcgNR/VqsVpcw+ThHmYcwiB1pbOxEbzJr7"
 crossorigin="anonymous"></script>
```

Scripts, of course, are not the only response type which would benefit
from integrity validation. The scheme specified here also applies to
`link` and future versions of this specification are likely to expand
this coverage.

Tests

- [subresource-integrity.html](https://wpt.fyi/results/subresource-integrity/subresource-integrity.html "subresource-integrity/subresource-integrity.html")
 [[(live
 test)]](http://wpt.live/subresource-integrity/subresource-integrity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/subresource-integrity/subresource-integrity.html)

### 1.1. Goals

1. Compromise of a third-party service should not automatically mean
 compromise of every site which includes its scripts. Content authors
 will have a mechanism by which they can specify expectations for
 content they load, meaning for example that they could load a
 *specific* script, and not *any* script that happens to have a
 particular URL.

2. The verification mechanism should have error-reporting functionality
 which would inform the author that an invalid response was received.

### 1.2. Use Cases/Examples

#### 1.2.1. Resource Integrity

- An author wishes to use a content delivery network to improve
 performance for globally-distributed users. It is important, however,
 to ensure that the CDN's servers deliver *only* the code the author
 expects them to deliver. To mitigate the risk that a CDN compromise
 (or unexpectedly malicious behavior) would change that site in
 unfortunate ways, the following [integrity
 metadata](#integrity-metadata) is added to the `link` element included on the page:

 :::
 (#example-ed55c3e6)
 ``` highlight
 <link rel="stylesheet" href="https://site53.example.net/style.css"
 integrity="sha384-+/M6kredJcxdsqkczBUjMLvqyHb1K/JThDXWsBVxMEeZHEaMKEOEct339VItX1zB"
 crossorigin="anonymous">
 ```
 :::

- An author wants to include JavaScript provided by a third-party
 analytics service. To ensure that only the code that has been
 carefully reviewed is executed, the author generates [integrity
 metadata](#integrity-metadata) for the script, and adds it to the `script` element:

 :::
 (#example-af0f59ce)
 ``` highlight
 <script src="https://analytics-r-us.example.com/v1.0/include.js"
 integrity="sha384-MBO5IDfYaE6c6Aao94oZrIOiC6CGiSN2n4QUbHNPhzk5Xhm0djZLQqTpL0HzTUxk"
 crossorigin="anonymous"></script>
 ```
 :::

- A user agent wishes to ensure that JavaScript code running in
 high-privilege HTML contexts (for example, a browser's New Tab page)
 aren't manipulated before display. [Integrity
 metadata](#integrity-metadata) mitigates the risk that altered JavaScript will run
 in these pages\' high-privilege contexts.

## 2. Key Concepts and Terminology

This section defines several terms used throughout the document.

The term [digest]
refers to the base64 encoded result of executing a cryptographic hash
function on an arbitrary block of data.

The terms
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) and [same
origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) are defined in HTML.
[\[HTML\]](#biblio-html "HTML Standard")

A [base64 encoding] is defined in [Section 4 of RFC
4648](https://tools.ietf.org/html/rfc4648#section-4).
[\[RFC4648\]](#biblio-rfc4648 "The Base16, Base32, and Base64 Data Encodings")

The
[SHA-256](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#),
[SHA-384](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#), and
[SHA-512](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#) are part of the
[SHA-2](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#) set of cryptographic hash
functions defined by the NIST.
[\[SHA2\]](#biblio-sha2 "FIPS PUB 180-4, Secure Hash Standard")

The [valid SRI hash algorithm token
set] is the [ordered
set](https://infra.spec.whatwg.org/#ordered-set) « \"`sha256`\", \"`sha384`\", \"`sha512`\" »
(corresponding to
[SHA-256](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#),
[SHA-384](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#), and
[SHA-512](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#) respectively). The ordering of
this set is meaningful, with stronger algorithms appearing later in the
set. See [§ 3.2.2 Priority](#priority) and [§ 3.3.3 Get the strongest
metadata from set](#get-the-strongest-metadata) for additional
information.

A string is a [valid SRI hash algorithm
token] if its [ASCII
lowercase](https://infra.spec.whatwg.org/#ascii-lowercase) is
[contained](https://infra.spec.whatwg.org/#list-contain) in the [valid SRI hash algorithm token
set](#valid-sri-hash-algorithm-token-set).

### 2.1. Grammatical Concepts

The Augmented Backus-Naur Form (ABNF) notation used in this document is
specified in RFC5234.
[\[ABNF\]](#biblio-abnf "Augmented BNF for Syntax Specifications: ABNF")

[Appendix
B.1](https://tools.ietf.org/html/rfc5234#appendix-B.1) of
[\[ABNF\]](#biblio-abnf "Augmented BNF for Syntax Specifications: ABNF")
defines the
[VCHAR](https://tools.ietf.org/html/rfc5234#appendix-B.1) (printing characters) and
[WSP](https://tools.ietf.org/html/rfc5234#appendix-B.1) (whitespace) rules.

Content Security Policy defines the
[`base64-value`](https://w3c.github.io/webappsec-csp/#grammardef-base64-value) and
[`hash-algorithm`](https://w3c.github.io/webappsec-csp/#grammardef-hash-algorithm) rules.
[\[CSP\]](#biblio-csp "Content Security Policy Level 3")

## 3. Framework

The integrity verification mechanism specified here boils down to the
process of generating a sufficiently strong cryptographic digest for a
resource, and transmitting that digest to a user agent so that it may be
used to verify the response.

### 3.1. Integrity metadata

To verify the integrity of a response, a user agent requires [integrity
metadata] as part of the
[request](https://fetch.spec.whatwg.org/#concept-request). This metadata consists of the following pieces of
information:

- cryptographic hash function (\"alg\")

- [digest](#digest) (\"val\")

- options (\"opt\")

The hash function and digest MUST be provided in order to validate a
response's integrity.

 At the moment, no options are defined. However, future
versions of the spec may define options, such as MIME types
[\[MIME-TYPES\]](#biblio-mime-types "Multipurpose Internet Mail Extensions (MIME) Part Two: Media Types").

This metadata MUST be encoded in the same format as the `hash-source`
(without the single quotes) in [section 4.2 of the Content Security
Policy Level 2
specification](http://www.w3.org/TR/CSP2/#source-list-syntax).

For example, given a script resource containing only the string
`alert('Hello, world.');`, an author might choose
[SHA-384](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#) as a hash function.
`H8BRh8j48O9oYatfu5AZzq6A9RINhZO5H16dQZngK7T62em8MUt1FLm52t+eX6xO` is
the [base64 encoded](#base64-encoding) digest that results. This can be encoded as follows:

sha384-H8BRh8j48O9oYatfu5AZzq6A9RINhZO5H16dQZngK7T62em8MUt1FLm52t+eX6xO

Digests may be generated using any number of utilities.
[OpenSSL](https://www.openssl.org/), for example, is quite commonly
available. The example in this section is the result of the following
command line:

``` highlight
echo -n "alert('Hello, world.');" | openssl dgst -sha384 -binary | openssl base64 -A
```

### 3.2. Cryptographic hash functions

Conformant user agents MUST support the
[SHA-256](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#),
[SHA-384](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#), and
[SHA-512](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#) cryptographic hash functions for
use as part of a request's [integrity
metadata](#integrity-metadata) and MAY support additional hash functions defined in
future iterations of this document.

[NOTE:] The algorithms supported in this document are
(currently!) believed to be resistent to second-preimage and collision
attacks. Future additions/removals from the set of supported algorithms
would be well-advised to apply similar standard. See [§ 5.2 Hash
collision attacks](#hash-collision-attacks).

#### 3.2.1. Agility

Multiple sets of [integrity
metadata](#integrity-metadata) may be associated with a single resource in order to
provide agility in the face of future cryptographic discoveries. For
example, the resource described in the previous section may be described
by either of the following hash expressions:

sha384-H8BRh8j48O9oYatfu5AZzq6A9RINhZO5H16dQZngK7T62em8MUt1FLm52t+eX6xO
 sha512-Q2bFTOhEALkN8hOms2FKTDLy7eugP2zFZ1T8LCvX42Fp3WoNr3bjZSAHeOsHrbV1Fu9/A0EzCinRE7Af1ofPrw==

Authors may choose to specify both, for example:

``` highlight
<script src="hello_world.js"
 integrity="sha384-H8BRh8j48O9oYatfu5AZzq6A9RINhZO5H16dQZngK7T62em8MUt1FLm52t+eX6xO
 sha512-Q2bFTOhEALkN8hOms2FKTDLy7eugP2zFZ1T8LCvX42Fp3WoNr3bjZSAHeOsHrbV1Fu9/A0EzCinRE7Af1ofPrw=="
 crossorigin="anonymous"></script>
```

In this case, the user agent will choose the strongest hash function in
the list, and use that metadata to validate the response (as described
below in the [§ 3.3.2 Parse metadata](#parse-metadata-section) and
[§ 3.3.3 Get the strongest metadata from
set](#get-the-strongest-metadata) algorithms).

When a hash function is determined to be insecure, user agents SHOULD
deprecate and eventually remove support for integrity validation using
the insecure hash function. User agents MAY check the validity of
responses using a digest based on a deprecated function.

To allow authors to switch to stronger hash functions without being held
back by older user agents, validation using unsupported hash functions
acts like no integrity value was provided (see the [§ 3.3.4 Do bytes
match
metadataList?](#does-response-match-metadatalist)
algorithm below). Authors are encouraged to use strong hash functions,
and to begin migrating to stronger hash functions as they become
available.

#### 3.2.2. Priority

The prioritization of hash algorithms is specified via the ordering of
their respective tokens in the [valid SRI hash algorithm token
set](#valid-sri-hash-algorithm-token-set). Algorithms appearing earlier in that set are weaker
than algorithms appearing later in that set.

As currently specified,
[SHA-256](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#) is weaker than
[SHA-384](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#), which is in turn weaker than
[SHA-512](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#). No other hashing algorithms are
currently supported by this specification.

### 3.3. Response verification algorithms

#### 3.3.1. Apply `algorithm` to `bytes`

1. Let `result` be the result of applying
 `algorithm` to `bytes`.

2. Return the result of [base64
 encoding](#base64-encoding) `result`.

#### 3.3.2. Parse metadata

When asked to [parse metadata] given a string `metadata`, run the
following steps:

 the algorithm returns a set of hash expressions whose
hash functions are understood by the user agent.

1. Let `result` be the empty set.

2. For each `item` returned by
 [splitting](https://infra.spec.whatwg.org/#strictly-split) `metadata` on spaces:

 1. Let `expression-and-options` be the result of
 [splitting](https://infra.spec.whatwg.org/#strictly-split) `item` on U+003F (?).

 2. Let `algorithm-expression` be
 `expression-and-options`\[0\].

 3. Let `base64-value` be the empty string.

 4. Let `algorithm-and-value` be the result of
 [splitting](https://infra.spec.whatwg.org/#strictly-split) `algorithm-expression` on U+002D
 (-).

 5. Let `algorithm` be
 `algorithm-and-value`\[0\].

 6. If `algorithm` is not a [valid SRI hash algorithm
 token](#valid-sri-hash-algorithm-token), then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 7. If `algorithm-and-value`\[1\]
 [exists](https://infra.spec.whatwg.org/#list-contain), set `base64-value` to
 `algorithm-and-value`\[1\].

 8. Let `metadata` be the ordered map «\[\"alg\" →
 `algorithm`, \"val\" → `base64-value`\]».

 Since no `options` are defined (see the [§ 3.1
 Integrity metadata](#integrity-metadata-description)), a
 corresponding entry is not set in `metadata`. If
 `options` are defined in a future version,
 `expression-and-options`\[1\] can be utilized as
 `options`.

 9. [Append](https://infra.spec.whatwg.org/#list-append) `metadata` to `result`.

3. Return `result`.

#### 3.3.3. Get the strongest metadata from `set`

1. Let `result` be the empty set and `strongest`
 be null.

2. For each `item` in `set`:

 1. Assert: `item`\[\"`alg`\"\] is a [valid SRI hash
 algorithm
 token](#valid-sri-hash-algorithm-token).

 2. If `result` is the empty set, then:

 1. [Append](https://infra.spec.whatwg.org/#set-append) `item` to `result`.

 2. Set `strongest` to `item`.

 3. [Continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. Let `currentAlgorithm` be
 `strongest`\[\"`alg`\"\], and
 `currentAlgorithmIndex` be the index of
 `currentAlgorithm` in the [valid SRI hash algorithm
 token
 set](#valid-sri-hash-algorithm-token-set).

 4. Let `newAlgorithm` be the
 `item`\[\"`alg`\"\], and
 `newAlgorithmIndex` be the index of
 `newAlgorithm` in the [valid SRI hash algorithm token
 set](#valid-sri-hash-algorithm-token-set).

 5. If `newAlgorithmIndex` is less than
 `currentAlgorithmIndex`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 6. Otherwise, if `newAlgorithmIndex` is greater than
 `currentAlgorithmIndex`:

 1. Set `strongest` to `item`.

 2. Set `result` to « `item` ».

 7. Otherwise, `newAlgorithmIndex` and
 `currentAlgorithmIndex` are the same value.
 [Append](https://infra.spec.whatwg.org/#set-append) `item` to `result`.

3. Return `result`.

#### 3.3.4. Do `bytes` match `metadataList`?

1. Let `parsedMetadata` be the result of [parsing
 `metadataList`](#parse-metadata).

2. If `parsedMetadata` [is
 empty](https://infra.spec.whatwg.org/#list-is-empty) set, return `true`.

3. Let `metadata` be the result of [getting the strongest
 metadata from
 `parsedMetadata`](#get-the-strongest-metadata).

4. For each `item` in `metadata`:

 1. Let `algorithm` be the `item`\[\"alg\"\].

 2. Let `expectedValue` be the
 `item`\[\"val\"\].

 3. Let `actualValue` be the result of [applying
 `algorithm` to
 `bytes`](#apply-algorithm-to-response) .

 4. If `actualValue` is a case-sensitive match for
 `expectedValue`, return `true`.

5. Return `false`.

This algorithm allows the user agent to accept multiple, valid strong
hash functions. For example, a developer might write a `script` element
such as:

``` highlight
<script src="https://example.com/example-framework.js"
 integrity="sha384-Li9vy3DqF8tnTXuiaAJuML3ky+er10rcgNR/VqsVpcw+ThHmYcwiB1pbOxEbzJr7
 sha384-+/M6kredJcxdsqkczBUjMLvqyHb1K/JThDXWsBVxMEeZHEaMKEOEct339VItX1zB"
 crossorigin="anonymous"></script>
```

which would allow the user agent to accept two different content
payloads, one of which matches the first
[SHA-384](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#) hash value and the other matches
the second
[SHA-384](https://csrc.nist.gov/publications/fips/fips180-4/fips-180-4.pdf#) hash value.

 User agents may allow users to modify the result of
this algorithm via user preferences, bookmarklets, third-party additions
to the user agent, and other such mechanisms. For example, redirects
generated by an extension like [HTTPS
Everywhere](https://www.eff.org/https-everywhere) could load and execute
correctly, even if the HTTPS version of a resource differs from the HTTP
version.

 Subresource Integrity requires CORS and it is a logical
error to attempt to use it without CORS. User agents are encouraged to
report a warning message to the developer console to explain this
failure. [\[Fetch\]](#biblio-fetch "Fetch Standard")

### 3.4. Verification of HTML document subresources

A variety of HTML elements result in requests for resources that are to
be embedded into the document, or executed in its context. To support
integrity metadata for some of these elements, a new `integrity`
attribute is added to the list of content attributes for the `link` and
`script` elements.
[\[HTML\]](#biblio-html "HTML Standard")

 A future revision of this specification is likely to
include integrity support for all possible subresources, i.e., `a`,
`audio`, `embed`, `iframe`, `img`, `link`, `object`, `script`, `source`,
`track`, and `video` elements.

### 3.5. The `integrity` attribute

The `integrity` attribute represents [integrity
metadata](#integrity-metadata) for an element. The value of the attribute MUST be
either the empty string, or at least one valid metadata as described by
the following ABNF grammar:

 integrity-metadata = *WSP hash-with-options *(1*WSP hash-with-options ) *WSP / *WSP
 hash-with-options = hash-expression *("?" option-expression)
 option-expression = *VCHAR
 hash-expression = hash-algorithm "-" base64-value

`option-expression`s are associated on a per `hash-expression` basis and
are applied only to the `hash-expression` that immediately precedes it.

In order for user agents to remain fully forwards compatible with future
options, the user agent MUST ignore all unrecognized
`option-expression`s.

 Note that while the `option-expression` has been
reserved in the syntax, no options have been defined. It is likely that
a future version of the spec will define a more specific syntax for
options, so it is defined here as broadly as possible.

### 3.6. The `integrity` link processing option

[Integrity metadata](#integrity-metadata) can also be specified for
\`[`link`](https://tools.ietf.org/html/rfc8288#link)\` HTTP response headers as an `integrity` link
parameter which MUST be specified using the same
[`integrity-metadata`](#grammardef-integrity-metadata) grammar that applies to `integrity` attributes on
elements. For example:

```
Link: </style.css>; rel=preload; as=style; crossorigin="anonymous"; integrity="sha256-[digest goes here]"
```

### 3.7. Handling integrity violations

The user agent will refuse to render or execute responses that fail an
integrity check, instead returning a network error as defined in Fetch
[\[Fetch\]](#biblio-fetch "Fetch Standard").

 On a failed integrity check, an `error` event is fired.
Developers wishing to provide a canonical fallback resource (e.g., a
resource not served from a CDN, perhaps from a secondary, trusted, but
slower source) can catch this `error` event and provide an appropriate
handler to replace the failed resource with a different one.

### 3.8. Integrity-Policy

The `Integrity-Policy` and `Integrity-Policy-Report-Only` HTTP headers
enable a document to enforce a policy regarding the integrity metadata
requirements on all the subresources it loads of certain
[destinations](https://fetch.spec.whatwg.org/#concept-request-destination).

The headers\' value is a
[Dictionary](https://tools.ietf.org/html/rfc9651#name-dictionaries)
[\[RFC9651\]](#biblio-rfc9651 "Structured Field Values for HTTP"),
with every member-value being an [inner
list](https://tools.ietf.org/html/rfc9651#name-inner-lists) of
[tokens](https://tools.ietf.org/html/rfc9651#name-tokens).

A [source] is a
string. The only possible value for it is \"`inline`\".

A [destination] is a [destination
type](https://fetch.spec.whatwg.org/#destination-type). The possible values for it are \"`script`\" and
\"`style`\".

An [integrity policy], is a
[struct](https://infra.spec.whatwg.org/#struct) that contains the following:

- [sources], a
 list of [source](#source)s, initially
 empty.

- [blocked destinations], a list of
 [destination](#destination)s,
 initially empty.

- [endpoints],
 a [list](https://infra.spec.whatwg.org/#list) of strings, initially empty.

When [processing an integrity policy], with a [header
list](https://fetch.spec.whatwg.org/#concept-header-list) `headers` and a [header
name](https://fetch.spec.whatwg.org/#header-name) `headerName`, do the following:

1. Let `integrityPolicy` be a new [integrity
 policy](#integrity-policy).

2. Let `dictionary` be the result of [getting a structured
 field
 value](https://fetch.spec.whatwg.org/#concept-header-list-get-structured-header) from `headers` given
 `headerName` and \"`dictionary`\".

3. If `dictionary`\[\"`sources`\"\] does not
 [exist](https://infra.spec.whatwg.org/#list-contain) or if its value
 [contains](https://infra.spec.whatwg.org/#list-contain) \"`inline`\",
 [append](https://infra.spec.whatwg.org/#list-append) \"`inline`\" to `integrityPolicy`'s
 [sources](#sources).

4. If `dictionary`\[\"`blocked-destinations`\"\]
 [exists](https://infra.spec.whatwg.org/#list-contain):

 1. If its value
 [contains](https://infra.spec.whatwg.org/#list-contain) \"`script`\",
 [append](https://infra.spec.whatwg.org/#list-append) \"`script`\" to `integrityPolicy`'s
 [blocked
 destinations](#blocked-destinations).

 2. If its value
 [contains](https://infra.spec.whatwg.org/#list-contain) \"`style`\",
 [append](https://infra.spec.whatwg.org/#list-append) \"`style`\" to `integrityPolicy`'s
 [blocked
 destinations](#blocked-destinations).

5. If `dictionary`\[\"`endpoints`\"\]
 [exists](https://infra.spec.whatwg.org/#map-exists):

 1. Set `integrityPolicy`'s
 [endpoints](#endpoints) to
 `dictionary`\[\'endpoints\'\].

6. Return `integrityPolicy`.

The following header block the request
for any external script that's loaded without integrity metadata (or any
no-CORS external script).

```
Integrity-Policy: blocked-destinations=(script), endpoints=(integrity-endpoint)
```

The blocking will also trigger a report to the \"`integrity-endpoint`\"
reporting endpoint (defined by the relevant `Reporting-Endpoints`
header).

Developers can also register a ReportingObserver for
\"`integrity-violation`\" to get JavaScript-based reports.

#### 3.8.1. Parse Integrity-Policy headers

To [parse Integrity-Policy headers], given a
[Response](https://fetch.spec.whatwg.org/#concept-response) `response` and a [policy
container](https://html.spec.whatwg.org/multipage/browsers.html#policy-container) `container`, do the following:

1. Let `headers` be `response`'s [header
 list](https://fetch.spec.whatwg.org/#concept-response-header-list).

2. If `headers`
 [contains](https://fetch.spec.whatwg.org/#header-list-contains) `integrity-policy`, set `container`'s
 [integrity
 policy](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-integrity-policy) be the result of running [processing an integrity
 policy](#processing-an-integrity-policy) with the corresponding [header
 value](https://fetch.spec.whatwg.org/#header-value).

3. If `headers`
 [contains](https://fetch.spec.whatwg.org/#header-list-contains) `integrity-policy-report-only`, set
 `container`'s [report only integrity
 policy](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-report-only-integrity-policy) be the result of running [processing an integrity
 policy](#processing-an-integrity-policy) with the corresponding [header
 value](https://fetch.spec.whatwg.org/#header-value).

#### 3.8.2. Should request be blocked by Integrity Policy

To determine [should request be blocked by integrity
policy], given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, do the following:

1. Let `policyContainer` be `request`'s [policy
 container](https://fetch.spec.whatwg.org/#concept-request-policy-container).

2. Let `parsedMetadata` be the result of calling [parse
 metadata](#parse-metadata)
 with `request`'s [integrity
 metadata](https://fetch.spec.whatwg.org/#concept-request-integrity-metadata).

3. If `parsedMetadata` is not the empty set and
 `request`'s
 [mode](https://fetch.spec.whatwg.org/#concept-request-mode) is either \"`cors`\" or \"`same-origin`\", return
 \"Allowed\".

4. If `request`'s
 [url](https://fetch.spec.whatwg.org/#concept-request-url) is
 [local](https://fetch.spec.whatwg.org/#is-local), return \"Allowed\".

5. Let `policy` be `policyContainer`'s [integrity
 policy](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-integrity-policy).

6. Let `reportPolicy` be `policyContainer`'s
 [report only integrity
 policy](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-report-only-integrity-policy).

7. If both `policy` and `reportPolicy` are empty
 [integrity policy](#integrity-policy)s, return \"Allowed\".

8. Let `global` be `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client)'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global).

9. If `global` is not a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) nor a
 [`WorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope), return \"`Allowed`\".

10. Let `block` be a boolean, initially false.

11. Let `reportBlock` be a boolean, initially false.

12. If `policy`'s [sources](#sources)
 [contains](https://infra.spec.whatwg.org/#list-contain) \"`inline`\" and `policy`'s [blocked
 destinations](#blocked-destinations)
 [contains](https://infra.spec.whatwg.org/#list-contain) `request`'s
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination), set `block` to true.

13. If `reportPolicy`'s [sources](#sources)
 [contains](https://infra.spec.whatwg.org/#list-contain) \"`inline`\" and `reportPolicy`'s
 [blocked
 destinations](#blocked-destinations)
 [contains](https://infra.spec.whatwg.org/#list-contain) `request`'s
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination), set `reportBlock` to true.

14. If `block` is true or `reportBlock` is true,
 then [report violation](#report-violation) with `request`, `block`,
 `reportBlock`, `policy` and
 `reportPolicy`.

15. If `block` is true, then return \"`Blocked`\"; otherwise
 \"`Allowed`\".

#### 3.8.3. Report violations

```
dictionary IntegrityViolationReportBody : ReportBody {
 USVString documentURL;
 USVString blockedURL;
 USVString destination;
 boolean reportOnly;
};
```

To [report violation] given a
[Request](https://fetch.spec.whatwg.org/#concept-request) `request`, a boolean `block`, a
boolean `reportBlock`, an [integrity
policy](#integrity-policy)
`policy`, and an [integrity
policy](#integrity-policy)
`reportPolicy`, do the following:

1. [Assert](https://infra.spec.whatwg.org/#assert): `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client) is not null.

2. Let `settingsObject` be `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client).

3. Let `global` be `settingsObject`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global).

4. [Assert](https://infra.spec.whatwg.org/#assert): `global` is a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) or a
 [`WorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope).

5. Let `url` be null.

6. If `global` is a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window), set `url` to `global`'s
 [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)'s
 [`URL`](https://dom.spec.whatwg.org/#dom-document-url).

7. If `global` is a
 [`WorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope), set `url` to `global`'s
 [URL](https://html.spec.whatwg.org/multipage/workers.html#concept-workerglobalscope-url).

8. [Assert](https://infra.spec.whatwg.org/#assert): `url` is a
 [URL](https://url.spec.whatwg.org/#concept-url).

9. Let `documentURL` be the result of [strip URL for use in
 reports](https://w3c.github.io/reporting/#strip-url-for-use-in-reports) on `url`.

10. Let `blockedURL` be the result of [strip URL for use in
 reports](https://w3c.github.io/reporting/#strip-url-for-use-in-reports) on `request`'s
 [URL](https://fetch.spec.whatwg.org/#concept-request-url).

11. If `block` is true, [for
 each](https://infra.spec.whatwg.org/#list-iterate) `endpoint` in `policy`'s
 [endpoints](#endpoints):

 1. Let `body` be a new
 [`IntegrityViolationReportBody`](#dictdef-integrityviolationreportbody), initialized as follows:

 [`documentURL`](#dom-integrityviolationreportbody-documenturl)

 : `documentURL`

 [`blockedURL`](#dom-integrityviolationreportbody-blockedurl)

 : `blockedURL`

 [`destination`](#dom-integrityviolationreportbody-destination)

 : `request`'s
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination)

 [`reportOnly`](#dom-integrityviolationreportbody-reportonly)

 : false

 2. [Generate and queue a
 report](https://w3c.github.io/reporting/#generate-and-queue-a-report) with the following arguments:

 [*context*](https://w3c.github.io/reporting/#generate-and-queue-a-report-context)

 : `settingsObject`

 [*type*](https://w3c.github.io/reporting/#generate-and-queue-a-report-type)

 : \"`integrity-violation`\"

 [*destination*](https://w3c.github.io/reporting/#generate-and-queue-a-report-destination)

 : `endpoint`

 [*data*](https://w3c.github.io/reporting/#generate-and-queue-a-report-data)

 : `body`

12. If `reportBlock` is true, [for
 each](https://infra.spec.whatwg.org/#list-iterate) `endpoint` in
 `reportPolicy`'s
 [endpoints](#endpoints):

 1. Let `reportBody` be a new
 [`IntegrityViolationReportBody`](#dictdef-integrityviolationreportbody), initialized as follows:

 [`documentURL`](#dom-integrityviolationreportbody-documenturl)

 : `documentURL`

 [`blockedURL`](#dom-integrityviolationreportbody-blockedurl)

 : `blockedURL`

 [`destination`](#dom-integrityviolationreportbody-destination)

 : `request`'s
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination)

 [`reportOnly`](#dom-integrityviolationreportbody-reportonly)

 : true

 2. [Generate and queue a
 report](https://w3c.github.io/reporting/#generate-and-queue-a-report) with the following arguments:

 [*context*](https://w3c.github.io/reporting/#generate-and-queue-a-report-context)

 : `settingsObject`

 [*type*](https://w3c.github.io/reporting/#generate-and-queue-a-report-type)

 : \"`integrity-violation`\"

 [*destination*](https://w3c.github.io/reporting/#generate-and-queue-a-report-destination)

 : `endpoint`

 [*data*](https://w3c.github.io/reporting/#generate-and-queue-a-report-data)

 : `reportBody`

## 4. Proxies

Optimizing proxies and other intermediate servers which modify the
responses MUST ensure that the digest associated with those responses
stays in sync with the new content. One option is to ensure that the
[integrity metadata](#integrity-metadata) associated with resources is updated. Another would be
simply to deliver only the canonical version of resources for which a
page author has requested integrity verification.

To help inform intermediate servers, those serving the resources SHOULD
send along with the resource a
[`Cache-Control`](https://tools.ietf.org/html/rfc7234#section-5.2) header with a value of
[`no-transform`](https://tools.ietf.org/html/rfc7234#section-5.2.1.6).

## 5. Security and Privacy Considerations

*This section is not normative.*

### 5.1. Non-secure contexts remain non-secure

[Integrity metadata](#integrity-metadata) delivered by a context that is not a [Secure
Context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) such as an HTTP page, only protects an origin against a
compromise of the server where an external resources is hosted. Network
attackers can alter the digest in-flight (or remove it entirely, or do
absolutely anything else to the document), just as they could alter the
response the hash is meant to validate. Thus, it is recommended that
authors deliver integrity metadata only to a [Secure
Context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context). See also [Securing the
Web](http://www.w3.org/2001/tag/doc/web-https%20).

### 5.2. Hash collision attacks

Digests are only as strong as the hash function used to generate them.
It is recommended that user agents refuse to support known-weak hashing
functions and limit supported algorithms to those known to be collision
resistant. Examples of hashing functions that are not recommended
include MD5 and SHA-1. At the time of writing, SHA-384 is a good
baseline.

Moreover, it is recommended that user agents re-evaluate their supported
hash functions on a regular basis and deprecate support for those
functions shown to be insecure. Over time, hash functions may be shown
to be much weaker than expected and, in some cases, broken, so it is
important that user agents stay aware of these developments.

### 5.3. Cross-origin data leakage

This specification requires integrity-protected cross-origin requests to
use the [CORS
protocol](https://fetch.spec.whatwg.org/#cors-protocol) to ensure that the resource's content is explicitly
shared with the requestor. If that requirement were omitted, attackers
could violate the [same-origin
policy](http://www.w3.org/Security/wiki/Same_Origin_Policy) and
determine whether a cross-origin resource has certain content.

Attackers would attempt to load the resource with a known digest, and
watch for load failures. If the load fails, the attacker could surmise
that the response didn't match the hash and thereby gain some insight
into its contents. This might reveal, for example, whether or not a user
is logged into a particular service.

Moreover, attackers could brute-force specific values in an otherwise
static resource. Consider a JSON response that looks like this:

``` highlight
{"status": "authenticated", "username": "admin"}
```

An attacker could precompute hashes for the response with a variety of
common usernames, and specify those hashes while repeatedly attempting
to load the document. A successful load would confirm that the attacker
has correctly guessed the username.

## 6. Acknowledgements

Much of the content here is inspired heavily by Gervase Markham's [Link
Fingerprints](http://www.gerv.net/security/link-fingerprints/) concept
as well as WHATWG's [Link
Hashes](https://wiki.whatwg.org/wiki/Link_Hashes).

A special thanks to Mike West for his invaluable contributions to the
initial version of this spec. Thanks to Brad Hill, Anne van Kesteren,
Jonathan Kingston, Fatih Kilic, Mark Nottingham, Sergey Shekyan, Dan
Veditz, Eduardo Vela, Tanvi Vyas, Yoav Weiss, and Michal Zalewski for
providing invaluable feedback.
