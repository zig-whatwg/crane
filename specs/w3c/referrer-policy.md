
## 1. Introduction

*This section is not normative.*

Requests made from a document, and for navigations away from that
document are associated with a
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header. While the header can be suppressed for links
with the
[`noreferrer`](https://html.spec.whatwg.org/multipage/semantics.html#link-type-noreferrer) link type, authors might wish to control the
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header more directly for a number of reasons:

### 1.1. Privacy

A social networking site has a profile page for each of its users, and
users add hyperlinks from their profile page to their favorite bands.
The social networking site might not wish to leak the user's profile URL
to the band web sites when other users follow those hyperlinks (because
the profile URLs might reveal the identity of the owner of the profile).

Some social networking sites, however, might wish to inform the band web
sites that the links originated from the social networking site but not
reveal which specific user's profile contained the links.

### 1.2. Security

A web application uses HTTPS and a URL-based session identifier. The web
application might wish to link to HTTPS resources on other web sites
without leaking the user's session identifier in the URL.

Alternatively, a web application may use URLs which themselves grant
some capability. Controlling the referrer can help prevent these
capability URLs from leaking via referrer headers.
[\[CAPABILITY-URLS\]](#biblio-capability-urls "Good Practices for Capability URLs")

Note that there are other ways for capability URLs to leak, and
controlling the referrer is not enough to control all those potential
leaks.

### 1.3. Trackback

A blog hosted over HTTPS might wish to link to a blog hosted over HTTP
and receive trackback links.

## 2. Key Concepts and Terminology

[referrer policy](#referrer-policy)

: A [referrer policy](#referrer-policy) modifies the algorithm used to populate the
 [`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header when
 [fetching](https://fetch.spec.whatwg.org/#concept-fetch) subresources, prefetching, or performing
 navigations. This document defines the various behaviors for each
 [referrer policy](#referrer-policy).

 Every [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) has an algorithm for obtaining a [referrer
 policy](#referrer-policy), which is used by default for all
 [requests](https://fetch.spec.whatwg.org/#concept-request) with that [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) as their
 [client](https://fetch.spec.whatwg.org/#concept-request-client).

[same-origin-referrer request]
: A
 [`Request`](https://fetch.spec.whatwg.org/#request) `request` is a **same-origin-referrer
 request** if the
 [origin](https://url.spec.whatwg.org/#concept-url-origin) of `request`'s
 [referrerURL](#referrerurl)
 and the
 [origin](https://url.spec.whatwg.org/#concept-url-origin) of `request`'s [current
 URL](https://fetch.spec.whatwg.org/#concept-request-current-url) are [the
 same](https://html.spec.whatwg.org/multipage/browsers.html#same-origin).

[cross-origin-referrer request]
: A
 [`Request`](https://fetch.spec.whatwg.org/#request) is a **cross-origin-referrer request** if it is
 *not* a [same-origin-referrer
 request](#same-origin-referrer-request).

## 3. Referrer Policies

A [referrer policy] is the empty string, \"`no-referrer`\",
\"`no-referrer-when-downgrade`\", \"`same-origin`\", \"`origin`\",
\"`strict-origin`\", \"`origin-when-cross-origin`\",
\"`strict-origin-when-cross-origin`\", or \"`unsafe-url`\".

```
enum ReferrerPolicy {
 "",
 "no-referrer",
 "no-referrer-when-downgrade",
 "same-origin",
 "origin",
 "strict-origin",
 "origin-when-cross-origin",
 "strict-origin-when-cross-origin",
 "unsafe-url"
};
```

Each possible [referrer
policy](#referrer-policy) is
explained below. A detailed algorithm for evaluating their effect is
given in the [§ 5 Integration with Fetch](#integration-with-fetch) and
[§ 8 Algorithms](#algorithms) sections.

 The referrer policy for an [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) provides a default baseline policy for requests when
that [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) is used as a [request
client](https://fetch.spec.whatwg.org/#concept-request-client). This policy may be tightened for specific requests via
mechanisms like the
[`noreferrer`](https://html.spec.whatwg.org/multipage/semantics.html#link-type-noreferrer) link type.

The [default referrer policy] is
[\"`strict-origin-when-cross-origin`\"](#referrer-policy-strict-origin-when-cross-origin).

### 3.1. \"`no-referrer`\"

The simplest policy is
[\"`no-referrer`\"](#referrer-policy-no-referrer), which specifies that no referrer information is to be
sent along with requests to any
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin). The header
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) will be omitted entirely.

If a document at
`https://example.com/page.html` sets a policy of
[\"`no-referrer`\"](#referrer-policy-no-referrer), then navigations to `https://example.com/` (or any
other URL) would send no
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header.

### 3.2. \"`no-referrer-when-downgrade`\"

The
[\"`no-referrer-when-downgrade`\"](#referrer-policy-no-referrer-when-downgrade) policy sends a request's full
[referrerURL](#referrerurl)
[stripped for use as a referrer](#strip-url) for requests:

- whose [referrerURL](#referrerurl) and [current
 URL](https://fetch.spec.whatwg.org/#concept-request-current-url) are both [potentially trustworthy
 URLs](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url), or
- whose [referrerURL](#referrerurl) is a non-[potentially trustworthy
 URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url).

Requests whose [referrerURL](#referrerurl) is a [potentially trustworthy
URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url) and whose [current
URL](https://fetch.spec.whatwg.org/#concept-request-current-url) is a non-[potentially trustworthy
URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url) on the other hand, will contain no referrer
information. A
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) HTTP header will not be sent.

If a document at
`https://example.com/page.html` sets a policy of
[\"`no-referrer-when-downgrade`\"](#referrer-policy-no-referrer-when-downgrade), then navigations to `https://not.example.com/` would
send a
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) HTTP header with a value of
`https://example.com/page.html`, as neither resource's origin is a
non-[potentially trustworthy
URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url).

Navigations from that same page to **`http`**`://not.example.com/` would
send no
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header.

### 3.3. \"`same-origin`\"

The
[\"`same-origin`\"](#referrer-policy-same-origin) policy specifies that a request's full
[referrerURL](#referrerurl) is
sent as referrer information when making [same-origin-referrer
requests](#same-origin-referrer-request).

[Cross-origin-referrer
requests](#cross-origin-referrer-request), on the other hand, will contain no referrer
information. A
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) HTTP header will not be sent.

If a document at
`https://example.com/page.html` sets a policy of
[\"`same-origin`\"](#referrer-policy-same-origin), then navigations to
`https://example.com/not-page.html` would send a
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header with a value of `https://example.com/page.html`.

Navigations from that same page to `https://`**`not`**`.example.com/`
would send no
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header.

If a document at
`https://example.com/page.html` sets a policy of
[\"`same-origin`\"](#referrer-policy-same-origin), and fetches a module script at
`https://script.example.com`, which then fetches a descendant script at
`https://example.com/descendant.js`, the request for the descendant
script would send no
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header.

This is because the descendant script request's [current
URL](https://fetch.spec.whatwg.org/#concept-request-current-url) is `https://example.com/descendant.js`, while its
[referrerURL](#referrerurl) is
`https://script.example.com`, making the request
[cross-origin-referrer](#cross-origin-referrer-request).

### 3.4. \"`origin`\"

The
[\"`origin`\"](#referrer-policy-origin) policy specifies that only the [ASCII
serialization](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin) of the request's
[referrerURL](#referrerurl) is
sent as referrer information when making both [same-origin-referrer
requests](#same-origin-referrer-request) and [cross-origin-referrer
requests](#cross-origin-referrer-request).

 The serialization of an origin looks like
`https://example.com`. To ensure that a valid URL is sent in the
\``Referer`\` header, user agents will append a U+002F SOLIDUS (\"`/`\")
character to the origin (e.g. `https://example.com/`).

 The
[\"`origin`\"](#referrer-policy-origin) policy allows the origin of HTTPS referrers to be sent
over the network as part of unencrypted HTTP requests. The
[\"`strict-origin`\"](#referrer-policy-strict-origin) policy addresses this concern.

If a document at
`https://example.com/page.html` sets a policy of
[\"`origin`\"](#referrer-policy-origin), then navigations to any
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) would send a
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header with a value of `https://example.com/`, even to
URLs that are not [potentially trustworthy
URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url).

If a document at
`https://example.com/page.html` sets a policy of
[\"`origin`\"](#referrer-policy-origin), and fetches a module script at
`https://script.example.com`, which fetches a descendant script at
`https://descendant.example.com`, the request for the descendant script
will send a
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header with a value of `https://script.example.com/`.

### 3.5. \"`strict-origin`\"

The
[\"`strict-origin`\"](#referrer-policy-strict-origin) policy sends the [ASCII
serialization](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin) of the
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) of the
[referrerURL](#referrerurl) for
requests:

- whose [referrerURL](#referrerurl) and [current
 URL](https://fetch.spec.whatwg.org/#concept-request-current-url) are both [potentially trustworthy
 URLs](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url), or
- whose [referrerURL](#referrerurl) is a non-[potentially trustworthy
 URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url).

Requests whose [referrerURL](#referrerurl) is a [potentially trustworthy
URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url) and whose [current
URL](https://fetch.spec.whatwg.org/#concept-request-current-url) is a non-[potentially trustworthy
URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url) on the other hand, will contain no referrer
information. A
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) HTTP header will not be sent.

If a document at
`https://example.com/page.html` sets a policy of
[\"`strict-origin`\"](#referrer-policy-strict-origin), then navigations to `https://`**`not`**`.example.com`
would send a
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header with a value of `https://example.com/`.

Navigations from that same page to **`http://`**`not.example.com` would
send no
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header.

If a document at
`http://example.com/page.html` sets a policy of
[\"`strict-origin`\"](#referrer-policy-strict-origin), then navigations to `http://`**`not`**`.example.com`
or **`https`**`://example.com` would send a
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header with a value of `http://example.com/`.

If a document at
`http://example.com/page.html` sets a policy of
[\"`strict-origin`\"](#referrer-policy-strict-origin), and fetches a module script at
**`https`**`://script.example.com`, which then fetches a descendant
script at **`http`**`://descendant.example.com`, the request to the
descendant script would not send a
[`Referrer`](https://html.spec.whatwg.org/multipage/semantics.html#meta-referrer) header.

### 3.6. \"`origin-when-cross-origin`\"

The
[\"`origin-when-cross-origin`\"](#referrer-policy-origin-when-cross-origin) policy specifies that a request's full
[referrerURL](#referrerurl) is
sent as referrer information when making [same-origin-referrer
requests](#same-origin-referrer-request), and only the [ASCII
serialization](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin) of the
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) of the request's
[referrerURL](#referrerurl) is
sent as referrer information when making [cross-origin-referrer
requests](#cross-origin-referrer-request).

 For the
[\"`origin-when-cross-origin`\"](#referrer-policy-origin-when-cross-origin) policy, we also consider protocol upgrades, e.g.
requests from `http://example.com/` to `https://example.com/`, to be
[cross-origin-referrer
requests](#cross-origin-referrer-request).

 The
[\"`origin-when-cross-origin`\"](#referrer-policy-origin-when-cross-origin) policy allows the origin of HTTPS referrers to be sent
over the network as part of unencrypted HTTP requests. The
[\"`strict-origin-when-cross-origin`\"](#referrer-policy-strict-origin-when-cross-origin) policy addresses this concern.

If a document at
`https://example.com/page.html` sets a policy of
[\"`origin-when-cross-origin`\"](#referrer-policy-origin-when-cross-origin), then navigations to
`https://example.com/not-page.html` would send a
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header with a value of `https://example.com/page.html`.

Navigations from that same page to `https://not.example.com/` would send
a
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header with a value of `https://example.com/`, even to
URLs that are not [potentially trustworthy
URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url)s.

If a document at
`https://example-1.com` sets a policy of
[\"`origin-when-cross-origin`\"](#referrer-policy-origin-when-cross-origin), and fetches a module script at
`https://example-2.com/module.js`, which then fetches a descendant
script at `https://example-1.com/descendant.js`, the request to the
descendant script would send a
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header with a value of `https://example-2.com/`.

If a document at
`https://example-1.com` sets a policy of
[\"`origin-when-cross-origin`\"](#referrer-policy-origin-when-cross-origin), and fetches a module script at
`https://example-2.com/module.js`, which then fetches a descendant
script at `https://example-2.com/descendant.js`, the request to the
descendant script would send a
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header with a value of
`https://example-2.com/module.js`.

### 3.7. \"`strict-origin-when-cross-origin`\"

The
[\"`strict-origin-when-cross-origin`\"](#referrer-policy-strict-origin-when-cross-origin) policy specifies that a request's full
[referrerURL](#referrerurl) is
sent as referrer information when making [same-origin-referrer
requests](#same-origin-referrer-request), and only the [ASCII
serialization](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin) of the
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) of the request's
[referrerURL](#referrerurl) when
making [cross-origin-referrer
requests](#cross-origin-referrer-request):

- whose [referrerURL](#referrerurl) and [current
 URL](https://fetch.spec.whatwg.org/#concept-request-current-url) are both [potentially trustworthy
 URLs](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url), or
- whose [referrerURL](#referrerurl) is a non-[potentially trustworthy
 URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url).

Requests whose [referrerURL](#referrerurl) is a [potentially trustworthy
URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url) and whose [current
URL](https://fetch.spec.whatwg.org/#concept-request-current-url) is a non-[potentially trustworthy
URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url) on the other hand, will contain no referrer
information. A
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) HTTP header will not be sent.

If a document at
`https://example.com/page.html` sets a policy of
[\"`strict-origin-when-cross-origin`\"](#referrer-policy-strict-origin-when-cross-origin), then navigations to
`https://example.com/not-page.html` would send a
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header with a value of `https://example.com/page.html`.

Navigations from that same page to `https://not.example.com/` would send
a
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header with a value of `https://example.com/`.

Navigations from that same page to **`http`**`://not.example.com/` would
send no
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header.

If a document at
`https://example.com/page.html` sets a policy of
[\"`strict-origin-when-cross-origin`\"](#referrer-policy-strict-origin-when-cross-origin), and fetches a module script at
`https://script.example.com` which then fetches a descendant script at
**`http`**`://descendant.example.com`, the request to the descendant
script would send no
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) header.

This policy is the user agent's
[default](#default-referrer-policy), and will be applied if no policy is otherwise
specified.

### 3.8. \"`unsafe-url`\"

The
[\"`unsafe-url`\"](#referrer-policy-unsafe-url) policy specifies that a request's full
[referrerURL](#referrerurl) is
sent along for both [same-origin-referrer
requests](#same-origin-referrer-request) and [cross-origin-referrer
requests](#cross-origin-referrer-request).

If a document at
`https://example.com/sekrit.html` sets a policy of
[\"`unsafe-url`\"](#referrer-policy-unsafe-url), then navigations to `http://not.example.com/` (and
every other origin) would send a
[`Referer`](https://httpwg.org/specs/rfc9110.html#rfc.section.10.1.3) HTTP header with a value of
`https://example.com/sekrit.html`.

 The policy's name doesn't lie; it is unsafe. This
policy will leak origins and paths from secure resources to insecure
origins. Carefully consider the impact of setting such a policy for
potentially sensitive documents.

### 3.9. The empty string

The empty string \"\" corresponds to no [referrer
policy](#referrer-policy),
causing a fallback to a [referrer
policy](#referrer-policy)
defined elsewhere, or in the case where no such higher-level policy is
available, falling back to the [default referrer
policy](#default-referrer-policy). This happens in Fetch's main fetch algorithm, for
example.

Given a HTML
[`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) element without any declared
[`referrerpolicy`](https://html.spec.whatwg.org/multipage/semantics.html#attr-hyperlink-referrerpolicy) attribute, its referrer policy is the empty
string. Thus, navigation requests initiated by clicking on that
[`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) element will be sent with the
[`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) element's [node
document](https://dom.spec.whatwg.org/#concept-node-document)'s [policy
container](https://html.spec.whatwg.org/multipage/dom.html#concept-document-policy-container)'s [referrer
policy](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-referrer-policy). If that
[`Document`](https://html.spec.whatwg.org/multipage/dom.html#document) has the empty string as its referrer policy, the [§ 8.3
Determine request's
Referrer](#determine-requests-referrer)
algorithm will treat the empty string the same as
[\"`strict-origin-when-cross-origin`\"](#referrer-policy-strict-origin-when-cross-origin).

## 4. Referrer Policy Delivery

A
[request](https://fetch.spec.whatwg.org/#concept-request)'s [referrer
policy](https://fetch.spec.whatwg.org/#concept-request-referrer-policy) is delivered in one of five ways:

- Via the `Referrer-Policy` HTTP header (defined in [§ 4.1 Delivery via
 Referrer-Policy header](#referrer-policy-header)).
- Via a
 [`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) element with a
 [`name`](https://html.spec.whatwg.org/multipage/semantics.html#attr-meta-name) of
 [`referrer`](https://html.spec.whatwg.org/multipage/semantics.html#meta-referrer).
- Via a `referrerpolicy` content attribute on an
 [`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element),
 [`area`](https://html.spec.whatwg.org/multipage/image-maps.html#the-area-element),
 [`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element),
 [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element),
 [`link`](https://html.spec.whatwg.org/multipage/semantics.html#the-link-element), or
 [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script) element.
- Via the
 [`noreferrer`](https://html.spec.whatwg.org/multipage/semantics.html#link-type-noreferrer) link relation on an
 [`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element), or
 [`area`](https://html.spec.whatwg.org/multipage/image-maps.html#the-area-element) element.
- Implicitly, via inheritance.

### 4.1. Delivery via Referrer-Policy header

The [`Referrer-Policy`] HTTP
header specifies the referrer policy that the user agent applies when
determining what referrer information should be included with requests
made, and with [browsing
contexts](https://html.spec.whatwg.org/multipage/browsers.html#browsing-context) created from the context of the protected resource.

The syntax for the name and value of the header are described by the
following ABNF grammar. ABNF is defined in
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"),
and the `#rule` ABNF extension used below is defined in [Section
5.6.1](https://httpwg.org/specs/rfc9110.html#abnf.extension) of
[\[RFC9110\]](#biblio-rfc9110 "HTTP Semantics").

 "Referrer-Policy:" 1#(policy-token / extension-token)

 policy-token = "no-referrer" / "no-referrer-when-downgrade" / "strict-origin" / "strict-origin-when-cross-origin" / "same-origin" / "origin" / "origin-when-cross-origin" / "unsafe-url"
 extension-token = 1*( ALPHA / "-" )

 The header name does not share the HTTP Referer
header's misspelling.

 The purpose of
[extension-token](#grammardef-extension-token) is so that browsers do not fail to parse the entire
header field if it includes an unknown policy value. [§ 11.1 Unknown
Policy Values](#unknown-policy-values) describes in greater detail how
new policy values can be deployed.

 The quotes in the ABNF above are used to indicate
literal strings. Referrer-Policy header values should not be quoted.

[§ 5 Integration with Fetch](#integration-with-fetch) and [§ 6
Integration with HTML](#integration-with-html) describe how the
`Referrer-Policy` header is processed.

#### 4.1.1. Usage

*This section is not normative.*

A protected resource can prevent referrer leakage by specifying
`no-referrer` as the value of its `Referrer-Policy` header:

 Referrer-Policy: no-referrer

This will cause all requests made from the protected resource's context
to have an empty `Referer` \[sic\] header.

### [4.2. ][Delivery via [`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta)]
*This section is not normative.*

The HTML Standard defines the
[`referrer`](https://html.spec.whatwg.org/multipage/semantics.html#meta-referrer) keyword for the
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) element, which allows setting the [referrer
policy](#referrer-policy) via
markup.

### 4.3. Delivery via a `referrerpolicy` content attribute

*This section is not normative.*

The HTML Standard defines the concept of [referrer policy
attributes](https://html.spec.whatwg.org/multipage/infrastructure.html#referrer-policy-attribute) which applies to several of its elements, for example:

```
<a href="http://example.com" referrerpolicy="origin">
```

### 4.4. [Referrer Policy Inheritance]
*This section is not normative.*

Referrer policy is inherited following the inheritance mechanism of
[policy
containers](https://html.spec.whatwg.org/multipage/browsers.html#policy-container), as defined by HTML.

## 5. Integration with Fetch

*This section is not normative.*

The Fetch specification calls out to [§ 8.2 Set request's referrer
policy on
redirect](#set-requests-referrer-policy-on-redirect)
before [Step 19 of the HTTP-redirect
fetch](https://fetch.spec.whatwg.org/#http-redirect-fetch), so that a
request's referrer policy can be updated before following a redirect.

The Fetch specification calls out to [§ 8.3 Determine request's
Referrer](#determine-requests-referrer)
as [Step 8 of the Main fetch
algorithm](https://fetch.spec.whatwg.org/#main-fetch), and uses the
result to set the `request`'s `referrer` property. Fetch is
responsible for serializing the URL provided, and setting the
\``Referer`\` header on `request`.

## 6. Integration with HTML

*This section is not normative.*

The HTML Standard determines the [referrer
policy](#referrer-policy) of
any response received during
[navigation](https://html.spec.whatwg.org/multipage/browsers.html#navigate) or while [running a
worker](https://html.spec.whatwg.org/multipage/workers.html#run-a-worker), and uses the result to set the resulting
[`Document`](https://html.spec.whatwg.org/multipage/dom.html#document)'s [policy
container](https://html.spec.whatwg.org/multipage/dom.html#concept-document-policy-container)'s or
[`WorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope)'s [policy
container](https://html.spec.whatwg.org/multipage/workers.html#concept-workerglobalscope-policy-container)'s [referrer
policy](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-referrer-policy).

## 7. Integration with CSS

The CSS Standard does not specify how it fetches resources referenced
from stylesheets. However, implementations should be sure to set the
referrer-related properties of any
[requests](https://fetch.spec.whatwg.org/#concept-request) initiated by stylesheets as follows:

1. If a [CSS style
 sheet](https://drafts.csswg.org/cssom-1/#css-style-sheet) is responsible for the request, and its
 [location](https://drafts.csswg.org/cssom-1/#concept-css-style-sheet-location) is non-null, set the
 [referrer](https://fetch.spec.whatwg.org/#concept-request-referrer) to its
 [location](https://drafts.csswg.org/cssom-1/#concept-css-style-sheet-location), and the [referrer
 policy](https://fetch.spec.whatwg.org/#concept-request-referrer-policy) to its [referrer
 policy](#cssstylesheet-referrer-policy).

 (#issue-a01fbbf2) This requires that CSS style sheets
 process \`Referrer-Policy\` headers, and store a [referrer
 policy] in the same way
 that [Documents
 do](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-referrer-policy).

2. If a [CSS style
 sheet](https://drafts.csswg.org/cssom-1/#css-style-sheet) with a null
 [location](https://drafts.csswg.org/cssom-1/#concept-css-style-sheet-location) is responsible for the request, set the
 [referrer](https://fetch.spec.whatwg.org/#concept-request-referrer) to its [owner
 node](https://drafts.csswg.org/cssom-1/#concept-css-style-sheet-owner-node)'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s
 [URL](https://dom.spec.whatwg.org/#concept-document-url), and the [referrer
 policy](https://fetch.spec.whatwg.org/#concept-request-referrer-policy) to its [owner
 node](https://drafts.csswg.org/cssom-1/#concept-css-style-sheet-owner-node)'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s [policy
 container](https://html.spec.whatwg.org/multipage/dom.html#concept-document-policy-container)'s [referrer
 policy](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-referrer-policy).

3. Otherwise, a [CSS declaration
 block](https://drafts.csswg.org/cssom-1/#css-declaration-block) that was created by the embedder is responsible for
 the request - either from parsing of an element's [style
 attribute](https://html.spec.whatwg.org/multipage/dom.html#the-style-attribute), or to implement an [presentational
 hint](https://html.spec.whatwg.org/multipage/rendering.html#presentational-hints) for an element. We assume that in this case the
 [CSS declaration
 block](https://drafts.csswg.org/cssom-1/#css-declaration-block)'s [owner
 node](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-owner-node) points to that element, and set the
 [referrer](https://fetch.spec.whatwg.org/#concept-request-referrer) to the block's [owner
 node](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-owner-node)'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s
 [URL](https://dom.spec.whatwg.org/#concept-document-url), and the [referrer
 policy](https://fetch.spec.whatwg.org/#concept-request-referrer-policy) to the block's [owner
 node](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-owner-node)'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s [policy
 container](https://html.spec.whatwg.org/multipage/dom.html#concept-document-policy-container)'s [referrer
 policy](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-referrer-policy).

 Both the value of the
[request](https://fetch.spec.whatwg.org/#concept-request)'s
[referrer](https://fetch.spec.whatwg.org/#concept-request-referrer) and [referrer
policy](https://fetch.spec.whatwg.org/#concept-request-referrer-policy) are set based on the values at the time a given
[request](https://fetch.spec.whatwg.org/#concept-request) is created. If a document's referrer policy changes
during its lifetime, the policy associated with inline stylesheet
requests will also change.

## 8. Algorithms

### 8.1. Parse a referrer policy from a [`Referrer-Policy` header ]
Given a
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, the following steps return a
[referrer policy](#referrer-policy) according to `response`'s
\``Referrer-Policy`\` header:

1. Let `policy-tokens` be the result of [extracting header
 list
 values](https://fetch.spec.whatwg.org/#extract-header-list-values) given \``Referrer-Policy`\` and
 `response`'s [header
 list](https://fetch.spec.whatwg.org/#concept-response-header-list).

2. Let `policy` be the empty string.

3. For each `token` in `policy-tokens`, if
 `token` is a [referrer
 policy](#referrer-policy) and `token` is not the empty string,
 then set `policy` to `token`.

 This algorithm loops over multiple policy values to
 allow deployment of new policy values with fallbacks for older user
 agents, as described in [§ 11.1 Unknown Policy
 Values](#unknown-policy-values).

4. Return `policy`.

### 8.2. Set `request`'s referrer policy on redirect

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and a
[response](https://fetch.spec.whatwg.org/#concept-response) `actualResponse`, this algorithm updates
`request`'s [referrer
policy](https://fetch.spec.whatwg.org/#concept-request-referrer-policy) according to the Referrer-Policy header (if any) in
`actualResponse`.

1. Let `policy` be the result of executing [§ 8.1 Parse a
 referrer policy from a Referrer-Policy
 header](#parse-referrer-policy-from-header) on
 `actualResponse`.
2. If `policy` is not the empty string, then set
 `request`'s [referrer
 policy](https://fetch.spec.whatwg.org/#concept-request-referrer-policy) to `policy`.

### 8.3. Determine `request`'s Referrer

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, we can determine the correct
referrer information to send by examining its [referrer
policy](https://fetch.spec.whatwg.org/#concept-request-referrer-policy) as detailed in the following steps, which return either
`no referrer` or a URL:

1. Let `policy` be `request`'s [referrer
 policy](https://fetch.spec.whatwg.org/#concept-request-referrer-policy).

2. Let `environment` be `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client).

3. Switch on `request`'s
 [referrer](https://fetch.spec.whatwg.org/#concept-request-referrer):

 \"`client`\"

 : 1. If `environment` is null, then return
 `no referrer`.
 2. If `environment`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global) is a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object, then
 1. Let `document` be the [associated
 `Document`](https://html.spec.whatwg.org/multipage/browsers.html#concept-document-window) of `environment`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global).
 2. If `document`'s
 [origin](https://dom.spec.whatwg.org/#concept-document-origin) is an [opaque
 origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque), return `no referrer`.
 3. While `document` is [an `iframe srcdoc`
 document](https://html.spec.whatwg.org/multipage/embedded-content.html#an-iframe-srcdoc-document), let `document` be
 `document`'s [browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#concept-document-bc)'s [browsing context
 container](https://html.spec.whatwg.org/multipage/browsers.html#browsing-context-container)'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document).
 4. Let `referrerSource` be
 `document`'s
 [URL](https://dom.spec.whatwg.org/#concept-document-url).
 3. Otherwise, let `referrerSource` be
 `environment`'s [creation
 URL](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-creation-url).

 a [URL](https://url.spec.whatwg.org/#concept-url)
 : Let `referrerSource` be `request`'s
 [referrer](https://fetch.spec.whatwg.org/#concept-request-referrer).

 If `request`'s
 [referrer](https://fetch.spec.whatwg.org/#concept-request-referrer) is \"`no-referrer`\", Fetch will not call into this
 algorithm.

4. Let request's [referrerURL] be the result of [stripping
 `referrerSource` for use as a referrer.](#strip-url)

5. Let `referrerOrigin` be the result of [stripping
 `referrerSource` for use as a referrer](#strip-url), with
 the
 [`origin-only flag`](#origin-only-flag) set to `true`.

6. If the result of
 [serializing](https://url.spec.whatwg.org/#concept-url-serializer) [referrerURL](#referrerurl) is a string whose
 [length](https://infra.spec.whatwg.org/#string-length) is greater than 4096, set referrerURL to
 `referrerOrigin`.

7. The user agent MAY alter
 [referrerURL](#referrerurl)
 or `referrerOrigin` at this point to enforce arbitrary
 policy considerations in the interests of minimizing data leakage.
 For example, the user agent could strip the URL down to an origin,
 modify its
 [host](https://url.spec.whatwg.org/#concept-url-host), replace it with an empty string, etc.

8. Execute the statements corresponding to the value of
 `policy`:\
 Note: If `request`'s [referrer
 policy](https://fetch.spec.whatwg.org/#concept-request-referrer-policy) is the empty string, Fetch will not call into this
 algorithm.

 [\"`no-referrer`\"](#referrer-policy-no-referrer)
 : Return `no referrer`

 [\"`origin`\"](#referrer-policy-origin)
 : Return `referrerOrigin`

 [\"`unsafe-url`\"](#referrer-policy-unsafe-url)
 : Return [referrerURL](#referrerurl).

 [\"`strict-origin`\"](#referrer-policy-strict-origin)

 : 1. If [referrerURL](#referrerurl) is a [potentially trustworthy
 URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url) and `request`'s [current
 URL](https://fetch.spec.whatwg.org/#concept-request-current-url) is not a [potentially trustworthy
 URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url), then return `no referrer`.
 2. Return `referrerOrigin`.

 [\"`strict-origin-when-cross-origin`\"](#referrer-policy-strict-origin-when-cross-origin)

 : 1. If the
 [origin](https://url.spec.whatwg.org/#concept-url-origin) of
 [referrerURL](#referrerurl) and the
 [origin](https://url.spec.whatwg.org/#concept-url-origin) of `request`'s [current
 URL](https://fetch.spec.whatwg.org/#concept-request-current-url) are [the
 same](https://html.spec.whatwg.org/multipage/browsers.html#same-origin), then return
 [referrerURL](#referrerurl).
 2. If [referrerURL](#referrerurl) is a [potentially trustworthy
 URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url) and `request`'s [current
 URL](https://fetch.spec.whatwg.org/#concept-request-current-url) is not a [potentially trustworthy
 URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url), then return `no referrer`.
 3. Return `referrerOrigin`.

 [\"`same-origin`\"](#referrer-policy-same-origin)

 : 1. If the
 [origin](https://url.spec.whatwg.org/#concept-url-origin) of
 [referrerURL](#referrerurl) and the
 [origin](https://url.spec.whatwg.org/#concept-url-origin) of `request`'s [current
 URL](https://fetch.spec.whatwg.org/#concept-request-current-url) are [the
 same](https://html.spec.whatwg.org/multipage/browsers.html#same-origin), then return
 [referrerURL](#referrerurl).

 This same-origin check determines whether
 or not the request is
 [same-origin-referrer](#same-origin-referrer-request).

 2. Return `no referrer`.

 [\"`origin-when-cross-origin`\"](#referrer-policy-origin-when-cross-origin)

 : 1. If the
 [origin](https://url.spec.whatwg.org/#concept-url-origin) of
 [referrerURL](#referrerurl) and the
 [origin](https://url.spec.whatwg.org/#concept-url-origin) of `request`'s [current
 URL](https://fetch.spec.whatwg.org/#concept-request-current-url) are [the
 same](https://html.spec.whatwg.org/multipage/browsers.html#same-origin), then return
 [referrerURL](#referrerurl).
 2. Return `referrerOrigin`.

 [\"`no-referrer-when-downgrade`\"](#referrer-policy-no-referrer-when-downgrade)

 : 1. If [referrerURL](#referrerurl) is a [potentially trustworthy
 URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url) and `request`'s [current
 URL](https://fetch.spec.whatwg.org/#concept-request-current-url) is not a [potentially trustworthy
 URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url), then return `no referrer`.
 2. Return [referrerURL](#referrerurl).

### 8.4. Strip `url` for use as a referrer

Certain portions of URLs must not be included when sending a URL as the
value of a \``Referer`\` header: a URLs fragment, username, and password
components must be stripped from the URL before it's sent out. This
algorithm accepts a [`origin-only flag`], which defaults to `false`. If
set to `true`, the algorithm will additionally remove the URL's path and
query components, leaving only the scheme, host, and port.

1. [Assert](https://infra.spec.whatwg.org/#assert): `url` is a
 [URL](https://url.spec.whatwg.org/#concept-url).
2. If `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is a [local
 scheme](https://fetch.spec.whatwg.org/#local-scheme), then return `no referrer`.
3. Set `url`'s
 [username](https://url.spec.whatwg.org/#concept-url-username) to the empty string.
4. Set `url`'s
 [password](https://url.spec.whatwg.org/#concept-url-password) to the empty string.
5. Set `url`'s
 [fragment](https://url.spec.whatwg.org/#concept-url-fragment) to `null`.
6. If the
 [`origin-only flag`](#origin-only-flag) is `true`, then:
 1. Set `url`'s
 [path](https://url.spec.whatwg.org/#concept-url-path) to « the empty string ».
 2. Set `url`'s
 [query](https://url.spec.whatwg.org/#concept-url-query) to `null`.
7. Return `url`.

## 9. Privacy Considerations

### 9.1. User Controls

Nothing in this specification should be interpreted as preventing user
agents from offering options to users which would change the information
sent out via a \``Referer`\` header. For instance, user agents MAY allow
users to suppress the referrer header entirely, regardless of the active
[referrer policy](#referrer-policy) on a page.

## 10. Security Considerations

### 10.1. Information Leakage

The [referrer policies](#referrer-policy)
[\"`origin`\"](#referrer-policy-origin),
[\"`origin-when-cross-origin`\"](#referrer-policy-origin-when-cross-origin) and
[\"`unsafe-url`\"](#referrer-policy-unsafe-url) might leak the origin and the URL of a secure site
respectively via insecure transport.

Those three policies are included in the spec nevertheless to lower the
friction of sites adopting secure transport.

Authors wanting to ensure that they do not leak any more information
than the default policy should instead use the policy states
[\"`same-origin`\"](#referrer-policy-same-origin),
[\"`strict-origin`\"](#referrer-policy-strict-origin), or
[\"`no-referrer`\"](#referrer-policy-no-referrer).

### 10.2. Downgrade to less strict policies

The spec does not forbid downgrading to less strict policies, e.g., from
[\"`no-referrer`\"](#referrer-policy-no-referrer) to
[\"`unsafe-url`\"](#referrer-policy-unsafe-url).

On the one hand, it is not clear which policy is more strict for all
possible pairs of policies: While
[\"`no-referrer-when-downgrade`\"](#referrer-policy-no-referrer-when-downgrade) will not leak any information over insecure transport,
and
[\"`origin`\"](#referrer-policy-origin) will, the latter reveals less information across
cross-origin navigations.

On the other hand, allowing for setting less strict policies enables
authors to define safe fallbacks as described in [§ 11.1 Unknown Policy
Values](#unknown-policy-values).

## 11. Authoring Considerations

### 11.1. Unknown Policy Values

As described in [§ 8.1 Parse a referrer policy from a Referrer-Policy
header](#parse-referrer-policy-from-header) and in the
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta)
[`referrer`](https://html.spec.whatwg.org/multipage/semantics.html#meta-referrer) algorithm, unknown policy values will be ignored, and
when multiple sources specify a referrer policy, the value of the latest
one will be used. This makes it possible to deploy new policy values.

Suppose older user agents don't
understand the
[\"`unsafe-url`\"](#referrer-policy-unsafe-url) policy. A site can specify an
[\"`origin`\"](#referrer-policy-origin) policy followed by an
[\"`unsafe-url`\"](#referrer-policy-unsafe-url) policy: older user agents will ignore the unknown
[\"`unsafe-url`\"](#referrer-policy-unsafe-url) value and use
[\"`origin`\"](#referrer-policy-origin), while newer user agents will use
[\"`unsafe-url`\"](#referrer-policy-unsafe-url) because it is the last to be processed.

To specify multiple policy values in
the Referrer-Policy header, a site can send multiple Referrer-Policy
headers:

 Referrer-Policy: no-referrer
 Referrer-Policy: unsafe-url

or, equivalently, multiple comma-separated header values:

 Referrer-Policy: no-referrer,unsafe-url

This behavior does not, however, apply to the `referrerpolicy`
attribute. Authors may dynamically set and get the `referrerpolicy`
attribute to detect whether a particular policy value is supported.

## 12. Acknowledgements

This specification is based in large part on Adam Barth and Jochen
Eisinger's [Meta referrer](https://wiki.whatwg.org/wiki/Meta_referrer)
document.

Francois Marier
[contributed](https://lists.w3.org/Archives/Public/public-webappsec/2016Mar/0085.html)
the `same-origin`, `strict-origin`, and
`strict-origin-when-cross-origin` policies.
