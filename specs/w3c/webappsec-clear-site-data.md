
## 1. Introduction

*This section is not normative.*

Web applications store data locally on a user's computer in order to
provide functionality while the user is offline, and to increase
performance when the user is online. These local caches have significant
advantages for both users and developers, but present risks as well.

A user's data is both sensitive and valuable; web developers ought to
take reasonable steps to protect it. One such step would be to encrypt
data before storing it. Another would be to remove data from the user's
machine when it is no longer necessary (for example, when the user signs
out of the application, or deletes their account).

Site authors can remove data from a number of storage mechanisms via
JavaScript, but others are difficult to deal with reliably. Consider
cookies, for instance, which can be partially cleared via JavaScript
access to `document.cookie`. `HttpOnly` cookies, however, can only be
removed via a number of `Set-Cookie` headers in an HTTP response. This,
of course, requires exhaustive knowledge of all the cookies set for a
host, which can be complicated to ascertain. Cache is still harder; no
imperative interface to a browser's network cache exists, period.

This document defines a new mechanism to deal with removing data from
these and other types of local storage, giving web developers the
ability to clear out a user's local cache of data via the
[Clear-Site-Data](#http-headerdef-clear-site-data) HTTP response header.

### 1.1. Examples

#### 1.1.1. Signing Out

A user signs out of Super Secret
Social Network via a CSRF-protected POST to
`https://supersecretsocialnetwork.example.com/logout`, and the site
author wishes to ensure that locally stored data is removed as a result.

They can do so by sending the following HTTP header in the response:

 Clear-Site-Data: "cache", "cookies", "storage", "executionContexts"

#### 1.1.2. Targeted Clearing

A user signs out of Megacorp Inc.\'s
site via a CSRF-protected POST to `https://megacorp.example.com/logout`.
Megacorp has a large number of services available as subdomains, so many
that it's not entirely clear which of them would be safe to clear as a
response to a logout action. One option would be to simply clear
everything, and deal with the fallout. Megacorp's CEO, however, once
lost hours and hours of progress in \"Irate Ibexes\" due to inadvertent
site-data clearing, and so refuses to allow such a sweeping impact to
the site's users.

The developers know, however, that the \"Minus\" application is
certainly safe to clear out. They can target this specific subdomain by
including a request to that subdomain as part of the logout landing page
(ideally as a CORS-enabled, CSRF-protected POST):

 fetch("https://minus.megacorp.example.com/clear-site-data",
 {
 method: "POST",
 mode: "cors",
 headers: new Headers({
 "CSRF": "[insert sekrit token here]"
 })
 });

That endpoint would return proper CORS headers in response to that
request's preflight, and would return the following header for the
actual request:

 Clear-Site-Data: "cache", "cookies", "storage", "executionContexts"

#### 1.1.3. Keep Critical Cookies

A user opts-out of interest-based
advertising via a CSRF-protected POST to
`https://ads-are-awesome.example.com/optout`. The site author wishes to
remove DOM-accessible data which might contain tracking information, but
needs to ensure that the opt-out cookie which the user has just received
isn't wiped along with it.

They can do so by sending the following HTTP header in the response,
which includes all the types except for
\"[cookies](#grammardef-cookies)\":

 Clear-Site-Data: "cache", "storage", "executionContexts"

#### 1.1.4. Kill Switch

Super Secret Social Network's
developers learn that the site was vulnerable to cross-site scripting
attacks which allowed malicious parties to inject arbitrary code into
its origin. They fixed the site, and added a strong Content Security
Policy
[\[CSP\]](#biblio-csp "Content Security Policy Level 3")
to mitigate the risk going forward, but they can't be entirely sure that
clients are really back to a trustworthy state. Perhaps the attackers
found a clever persistence mechanism?

They can reduce the risk of a persistent client-side XSS by sending the
following HTTP header in a response to wipe out local sources of data:

 Clear-Site-Data: "cache", "cookies", "storage", "executionContexts"

 Installing a Service Worker guarantees that a request
will go out to a server every \~24 hours. That update ping would be a
wonderful time to send a header like this one in case of catastrophe.
[\[SERVICE-WORKERS\]](#biblio-service-workers "Service Workers")

### 1.2. Goals

Generally, the goal is to allow web developers more control over the
data stored locally by a user agent for their origins. In particular,
developers should be able to reliably ensure the following:

1. Data stored in an origin's client-side storage mechanisms like
 [\[INDEXEDDB\]](#biblio-indexeddb "Indexed Database API"),
 WebSQL, Filesystem,
 [`localStorage`](https://html.spec.whatwg.org/multipage/webstorage.html#dom-localstorage), and
 [`sessionStorage`](https://html.spec.whatwg.org/multipage/webstorage.html#dom-sessionstorage) is cleared.

2. Cookies for an origin's host are removed
 [\[RFC6265\]](#biblio-rfc6265 "HTTP State Management Mechanism").

3. Web Workers (dedicated and shared) running for an origin are
 terminated.

4. Service Workers registered for an origin are terminated and
 deregistered.

5. Resources from an origin are removed from the user agent's local
 cache.

6. The [Accept-CH
 cache](https://wicg.github.io/client-hints-infrastructure/#accept-ch-cache) for an origin is purged.

7. None of the above can be bypassed by a maliciously active document
 that retains interesting data in memory, and rewrites it if it's
 cleared.

## 2. Infrastructure

This document uses ABNF grammar to specify syntax, as defined in
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF")
and updated in
[\[RFC7405\]](#biblio-rfc7405 "Case-Sensitive String Support in ABNF"),
along with the `#rule` extension defined in [Section
7](https://tools.ietf.org/html/rfc7230#section-7) of
[\[RFC7230\]](#biblio-rfc7230 "HTTP/1.1"), and the
`quoted-string` rule defined in [Section
3.2.6](https://tools.ietf.org/html/rfc7230#section-3.2.6) of the same
document.

This document depends on the Infra Standard for a number of foundational
concepts used in its algorithms and prose
[\[INFRA\]](#biblio-infra "Infra Standard").

## 3. Clearing Site Data

Developers may instruct a user agent to clear various types of relevant
data by delivering a `Clear-Site-Data` HTTP response header in response
to a request.

### 3.1. The `Clear-Site-Data` HTTP Response Header Field

The [`Clear-Site-Data`] HTTP response header
field sends a signal to the user agent that it ought to remove all data
of a certain set of types. The header is represented by the following
grammar:

``` abnf
Clear-Site-Data = 1#( quoted-string )
; #rule is defined in Section 7 of RFC 7230.
```

[§ 3.2 Fetch Integration](#fetch-integration) and [§ 4.1
Parsing](#parsing) describe how the
[Clear-Site-Data](#http-headerdef-clear-site-data) header is processed.

This document defines an initial set of known data types which can be
cleared using this mechanism. See their descriptions below. Future
versions of the header can support additional datatypes, which MUST
comply with the
[quoted-string](https://tools.ietf.org/html/rfc7230https://tools.ietf.org/html/rfc7230#section-3.2.6) grammar. User agents MUST ignore unknown types when
parsing the header.

\"[`cache`]\"

: The \"`cache`\" type indicates that the server wishes to remove
 locally cached data associated with the
 [origin](https://tools.ietf.org/html/rfc6454#section-3.2) of a particular
 [response](https://fetch.spec.whatwg.org/#concept-response)'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url). This includes the [network
 cache](https://tools.ietf.org/html/rfc7234#section-2), of course, but will also remove data from various
 other caches which a user agent implements (prerendered pages,
 script caches, shader caches, [Accept-CH
 cache](https://wicg.github.io/client-hints-infrastructure/#accept-ch-cache), etc.).

 Implementation details are in [§ 4.2.3 Clear cache for
 origin](#clear-cache).

 :::
 (#example-b245894e) When delivered with a response
 from `https://example.com/clear`, the following header will cause
 caches associated with the origin `https://example.com`: to be
 cleared:
 Clear-Site-Data: "cache"
 :::

 Caches are typically not organized by origin, but
 rather by URL and timestamp. This means that in practice, clearing
 cache by origin might have to be implemented using a linear scan.
 For large caches, this makes it a prohibitively expensive operation.

\"[`cookies`]\"

: The \"`cookies`\" type indicates that the server wishes to remove
 cookies associated with the
 [origin](https://tools.ietf.org/html/rfc6454#section-3.2) of a particular
 [response](https://fetch.spec.whatwg.org/#concept-response)'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url). Along with cookies, HTTP authentication
 credentials
 [\[RFC7235\]](#biblio-rfc7235 "HTTP Semantics"),
 and origin-bound tokens such as those defined by Channel ID
 [\[CHANNELID\]](#biblio-channelid "Transport Layer Security (TLS) Channel IDs")
 and Token Binding
 [\[TOKBIND\]](#biblio-tokbind "The Token Binding Protocol Version 1.0")
 are also cleared.

 Implementation details are in [§ 4.2.4 Clear cookies for
 origin](#clear-cookies).

 :::
 (#example-3d4ad502) When delivered with a response
 from `https://example.com/clear`, the following header will cause
 cookies associated with the origin `https://example.com` to be
 cleared, as well as cookies on any origin in the same registered
 domain (e.g. `https://www.example.com/` and
 `https://more.subdomains.example.com/`).
 Clear-Site-Data: "cookies"
 :::

 Clearing cookies should also clear the [Accept-CH
 cache](https://wicg.github.io/client-hints-infrastructure/#accept-ch-cache) for
 [origin](https://tools.ietf.org/html/rfc6454#section-3.2). This is because the cache is also cleared if the
 user manually clears cookies.

\"[`storage`]\"

: The \"`storage`\" type indicates that the server wishes to remove
 locally stored data associated with the
 [origin](https://tools.ietf.org/html/rfc6454#section-3.2) of a particular
 [response](https://fetch.spec.whatwg.org/#concept-response)'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url). This includes storage mechanisms such as
 ([`localStorage`](https://html.spec.whatwg.org/multipage/webstorage.html#dom-localstorage),
 [`sessionStorage`](https://html.spec.whatwg.org/multipage/webstorage.html#dom-sessionstorage),
 [\[INDEXEDDB\]](#biblio-indexeddb "Indexed Database API"),
 [\[WEBDATABASE\]](#biblio-webdatabase "Web SQL Database"),
 etc), as well as tangentially related mechanism such as [service
 worker
 registrations](https://w3c.github.io/ServiceWorker/#dfn-service-worker-registration).

 Implementation details are in [§ 4.2.5 Clear DOM-accessible storage
 for origin](#clear-dom).

 :::
 (#example-b9b200c9) When delivered with a response
 from `https://example.com/clear`, the following header will cause
 DOM-accessible storage for the origin `https://example.com` to be
 cleared:
 Clear-Site-Data: "storage"
 :::

\"[`executionContexts`]\"

: The \"`executionContexts`\" type indicates that the server wishes to
 neuter and reload execution contexts currently rendering the
 [origin](https://tools.ietf.org/html/rfc6454#section-3.2) of a particular
 [response](https://fetch.spec.whatwg.org/#concept-response)'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url).

 :::
 (#example-7718f7d6) When delivered with a response
 from `https://example.com/clear`, the following header will cause
 execution contexts displaying the origin `https://example.com` to be
 neutered and reloaded:
 Clear-Site-Data: "executionContexts"
 :::

\"[`clientHints`]\"

: The \"`clientHints`\" type indicates that the server wishes clear
 the [Accept-CH
 cache](https://wicg.github.io/client-hints-infrastructure/#accept-ch-cache) for the
 [origin](https://tools.ietf.org/html/rfc6454#section-3.2) of a particular
 [response](https://fetch.spec.whatwg.org/#concept-response)'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url).

 :::
 (#example-c284f61c) When delivered with a response
 from `https://example.com/clear`, the following header will cause
 the [Accept-CH
 cache](https://wicg.github.io/client-hints-infrastructure/#accept-ch-cache) for origin `https://example.com` to be cleared:
 Clear-Site-Data: "clientHints"
 :::

 The [Accept-CH
 cache](https://wicg.github.io/client-hints-infrastructure/#accept-ch-cache) is also cleared for the
 [cache](#grammardef-cache) and
 [cookies](#grammardef-cookies) options, so it should be used only when neither
 of the other options (or [\*](#grammardef-)) are applied.

\"[`*`]\"

: The \"`*`\" (wildcard) pseudotype indicates that the server has the
 same effect as specifying all types.

 :::
 (#example-690fcb44) When delivered with a response
 from `https://example.com/clear`, the following header will cause
 all cookies, caches, and DOM-accessible storage associated with the
 origin `https://example.com` to be cleared, as well as execution
 contexts for the same origin to be neutered and reloaded:
 Clear-Site-Data: "*"
 :::

 :::
 Note: The wildcard is forward-compatible in the sense that if more
 datatypes are added in future versions of this header, they will
 also be covered by it.

 DO use the wildcard if the intention is to perform a broad cleanup,
 i.e. clear all data associated with an origin that the header knows
 about.

 DO NOT use the wildcard as a shorthand for the four types listed
 above, as this meaning might change.
 :::

 The syntax defined here is compatible with future
extensions to this document which might add more granular filtering
mechanisms to the types we've defined. For example, it's likely that
\"[`cookies`](#grammardef-cookies)\" will need to grow a mechanism to prevent deletion
of specific cookie values. Wrapping all of the type names in
double-quotes means that we can easily shift from simple
splitting-strings-on-commas processing to something more complicated
(like processing the header value as JSON) without losing backwards
compatibility.

### 3.2. Fetch Integration

Monkey patching! Talk with Anne.

If the
[`Clear-Site-Data`](#http-headerdef-clear-site-data) header is present in an HTTP
[response](https://fetch.spec.whatwg.org/#concept-response) received from the network, then data MUST be cleared
before rendering the response to the user. That is, after step #14 in
the current [HTTP-network
fetch](https://fetch.spec.whatwg.org/#concept-http-network-fetch) algorithm, execute the following step:

15. If `credentials flag` is set, and `response`'s
 [header
 list](https://fetch.spec.whatwg.org/#concept-response-header-list) contains a header named
 [`Clear-Site-Data`](#http-headerdef-clear-site-data), then execute [§ 4.2 Clear data for
 response](#clear-response) on `response`.

 This happens *after* `Set-Cookie` headers are
processed. If we clear cookies, we clear all of them. This is
intentional, as removing only certain cookies might leave an application
in an indeterminate and vulnerable state. Removing specific cookies is
best done via expiration using the `Set-Cookie` header.

 If we clear the [Accept-CH
cache](https://wicg.github.io/client-hints-infrastructure/#accept-ch-cache) via the `Clear-Site-Data` header then any `Accept-CH`
and `Critical-CH` headers in the same request must be ignored.

 While the fetch `credentials flag` is intended to
restrict the modification of cookies,
[`Clear-Site-Data`](#http-headerdef-clear-site-data) applies the same restriction to all types for
the sake of consistency.

## 4. Algorithms

### 4.1. Parsing

Given a
[response](https://fetch.spec.whatwg.org/#concept-response), the user agent can [parse `response`'s
`Clear-Site-Data`
header], returning a list of
types, as follows:

1. Let `types` be an empty list.

2. Let `header` be the result of [extracting header list
 values](https://fetch.spec.whatwg.org/#extract-header-list-values) given `Clear-Site-Data` and `response`'s
 [header
 list](https://fetch.spec.whatwg.org/#concept-response-header-list).

3. If `header` is `null` or failure, return an empty list.

4. For each `type` in `header`, execute the first
 matching statement, if any, switching on `type`:

 \``"cache"`\`

 : Append \"[cache](#grammardef-cache)\" and
 \"[clientHints](#grammardef-clienthints)\" to `types`.

 \``"cookies"`\`

 : Append
 \"[cookies](#grammardef-cookies)\" and
 \"[clientHints](#grammardef-clienthints)\" to `types`.

 \``"storage"`\`

 : Append
 \"[storage](#grammardef-storage)\" to `types`.

 \``"executionContexts"`\`

 : Append
 \"[executionContexts](#grammardef-executioncontexts)\" to `types`.

 \``"clientHints"`\`

 : Append
 \"[clientHints](#grammardef-clienthints)\" to `types`.

 \``"*"`\`

 : Append \"[cache](#grammardef-cache)\",
 \"[cookies](#grammardef-cookies)\",
 \"[storage](#grammardef-storage)\",
 \"[clientHints](#grammardef-clienthints)\", and
 \"[executionContexts](#grammardef-executioncontexts)\" to `types`.

5. Return `types`.

 All of the existing values can be handled with the
simple switch above. If and when more complex type definitions are
created, the parser will likely shift over to JSON entirely.

### 4.2. Clear data for `response`

Given a
[response](https://fetch.spec.whatwg.org/#concept-response) (`response`), the user agent can [clear site
data for
`response`(#abstract-opdef-clear-site-data-for-response)]
as follows:

1. If `response`'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url) is not an [*a priori* authenticated
 URL](https://w3c.github.io/webappsec-mixed-content/#a-priori-authenticated-url), then
 [break](https://infra.spec.whatwg.org/#iteration-break).

2. Let `types` be the result of [parsing
 `response`'s `Clear-Site-Data`
 header](#abstract-opdef-parse-responses-clear-site-data-header).

3. Let `origin` be `response`'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url)\'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin).

4. Let `browsing contexts` be the result of [preparing to
 clear
 data](#abstract-opdef-prepare-to-clear-origins-data) for `origin` and
 `types`.

5. For each `type` in `types`:

 1. Execute the first matching statement, if any, switching on
 `type`:

 \"[`cache`](#grammardef-cache)\"

 : [Clear cache for
 `origin`](#abstract-opdef-clear-cache-for-origin).

 \"[`cookies`](#grammardef-cookies)\"

 : [Clear cookies for
 `origin`](#abstract-opdef-clear-cookies-for-origin).

 \"[`storage`](#grammardef-storage)\"

 : [Clear DOM-accessible storage for
 `origin`](#abstract-opdef-clear-dom-accessible-storage-for-origin).

 \"[`clientHints`](#grammardef-clienthints)\"

 : [Empty](https://infra.spec.whatwg.org/#list-empty) [Accept-CH
 cache](https://wicg.github.io/client-hints-infrastructure/#accept-ch-cache)\[`origin`\].

6. If `types` contains
 \"[executionContexts](#grammardef-executioncontexts)\", then [Reload
 `browsing contexts`](#abstract-opdef-reload-browsing-contexts).

 User agents are are encouraged to give web developers
some mechanism by which the clearing operation can be debugged. This
might take the form of a console message or timeline entry indicating
success.

#### 4.2.1. Prepare to clear `origin`'s data

Given an
[origin](https://tools.ietf.org/html/rfc6454#section-3.2) (`origin`) and a list of types
(`types`), the user agent can [prepare to clear
`origin`'s
data] by executing the
following steps. The algorithm returns a list of [browsing
contexts](https://html.spec.whatwg.org/multipage/document-sequences.html#browsing-context) which have been sandboxed in order to prevent them from
recreating cleared data from in-memory JavaScript variables.

1. Let `sandboxed` be an empty list.

2. If `types` does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 \"[`executionContexts`](#grammardef-executioncontexts)\", return `sandboxed`.

3. For each `context` in the user agent's set of [browsing
 contexts](https://html.spec.whatwg.org/multipage/document-sequences.html#browsing-context):

 1. Let `document` be `context`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

 2. If `document`'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)\'s
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin) is not `origin`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. [Parse a sandboxing
 directive](https://html.spec.whatwg.org/multipage/browsers.html#parse-a-sandboxing-directive) using the empty string as the input, and
 `document`'s [active sandboxing flag
 set] as the output.

 4. [Append](https://infra.spec.whatwg.org/#list-append) `context` to `sandboxed`.

4. Return `sandboxed`.

#### 4.2.2. Reload `browsing contexts`

Given a list of [browsing
contexts](https://html.spec.whatwg.org/multipage/document-sequences.html#browsing-context) (`contexts`), the user agent can [reload
browsing contexts] as
follows:

1. For each `context` in `contexts`:

 1. Execute `context`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document)\'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)\'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global)\'s
 [`Location`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#location) object's
 [`reload()`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-location-reload).

 (#issue-fb0b50ca) This is the simplest thing, but
 it's probably reaching a little too far into the documents and
 mucking with their context. I probably just need to break down
 and copy/paste the relevant bits from HTML.

#### 4.2.3. Clear cache for `origin`

Given an
[origin](https://tools.ietf.org/html/rfc6454#section-3.2) (`origin`), the user agent can [clear cache
for `origin`] as
follows:

1. Let `host` be `origin`'s
 [host](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-host).

2. Let `cache list` be the set of entries from the [network
 cache](https://tools.ietf.org/html/rfc7234#section-2) whose `target URI`
 [host](https://url.spec.whatwg.org/#concept-url-host) is identical to `host`.

3. For each `entry` in `cache list`:

 1. Remove `entry` from the [network
 cache](https://tools.ietf.org/html/rfc7234#section-2).

4. If a user agent implements caches beyond a pure [network
 cache](https://tools.ietf.org/html/rfc7234#section-2), it MUST remove all entries from those caches which
 match `origin`.

 (#issue-f5577029) We're dealing with the network cache
 here, as defined in
 [\[RFC7234\]](#biblio-rfc7234 "HTTP Caching"),
 but that's not nearly everything a user agent caches. How hand-wavey
 with the vendor-specific section can we be? For instance, Chrome
 clears out prerendered pages, script caches, WebGL shader caches,
 WebRTC bits and pieces, address bar suggestion caches, various
 networking bits that aren't representations (HSTS/HPKP, SCDH, etc.).
 Perhaps
 [\[STORAGE\]](#biblio-storage "Storage Standard")
 will make this clearer?

#### 4.2.4. Clear cookies for `origin`

Given an
[origin](https://tools.ietf.org/html/rfc6454#section-3.2) (`origin`), the user agent can [clear
cookies for
`origin`]
as follows:

 We remove all the cookies for an entire [registered
domain](https://publicsuffix.org/list/#), as cookies ignore the same-origin policy, and there's
a distinct risk that we'd leave applications in an ill-defined state if
we only cleared cookies for a particular subdomain. Consider
`accounts.google.com` vs `mail.google.com`, for instance, both of which
have cookies that signal a user's signed-in status.

 This algorithm assumes that the user agent has
implemented a [cookie
store](https://tools.ietf.org/html/rfc6265#section-5.3) (as discussed in Section 5.3 of
[\[RFC6265\]](#biblio-rfc6265 "HTTP State Management Mechanism")),
which offers the ability to retrieve a list of cookies by host, and to
remove individual cookies.

1. Let `registered` be the [registered
 domain](https://publicsuffix.org/list/#) of `origin`'s
 [host](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-host).

2. Let `cookie list` be the set of cookies from the [cookie
 store](https://tools.ietf.org/html/rfc6265#section-5.3) whose `domain` attribute is a
 [domain-match](https://tools.ietf.org/html/rfc6265#section-5.1.3) with `registered`.

3. For each `cookie` in `cookie list`:

 1. Remove `cookie` from the [cookie
 store](https://tools.ietf.org/html/rfc6265#section-5.3).

4. If the user agent supports other forms of cookie-like storage, these
 MUST also be cleared for
 [origins](https://tools.ietf.org/html/rfc6454#section-3.2) whose
 [host](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-host)\'s [registered
 domain](https://publicsuffix.org/list/#) is `registered`.

 For example, if the user agent supports Flash, its
 local stored objects will be cleared via
 [NPP_ClearSiteData](https://wiki.mozilla.org/NPAPI:ClearSiteData).

5. Clear any Channel IDs
 [\[CHANNELID\]](#biblio-channelid "Transport Layer Security (TLS) Channel IDs")
 and bound tokens
 [\[TOKBIND\]](#biblio-tokbind "The Token Binding Protocol Version 1.0")
 associated with
 [origins](https://tools.ietf.org/html/rfc6454#section-3.2) whose
 [host](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-host)\'s [registered
 domain](https://publicsuffix.org/list/#) is `registered`.

6. Clear [authentication
 entries](https://fetch.spec.whatwg.org/#authentication-entry) and [proxy-authentication
 entries](https://fetch.spec.whatwg.org/#proxy-authentication-entry) associated with
 [origins](https://tools.ietf.org/html/rfc6454#section-3.2) whose
 [host](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-host)\'s [registered
 domain](https://publicsuffix.org/list/#) is `registered`.

The process of clearing both bound
tokens/IDs and HTTP authentication is super hand-wavey. [\[Issue
#w3c/webappsec-clear-site-data#2\]](https://github.com/w3c/webappsec-clear-site-data/issues/2)

#### 4.2.5. Clear DOM-accessible storage for `origin`

Given an
[origin](https://tools.ietf.org/html/rfc6454#section-3.2) (`origin`), the user agent can [clear
DOM-accessible storage for
`origin`] as follows:

1. For each `area` in the user agent's set of [local storage
 areas](https://html.spec.whatwg.org/multipage/webstorage.html#dom-localstorage)
 [\[HTML\]](#biblio-html "HTML Standard"):

 1. If `area`'s
 [origin](https://tools.ietf.org/html/rfc6454#section-3.2) is `origin`:

 1. Execute
 [`clear()`](https://html.spec.whatwg.org/multipage/webstorage.html#dom-storage-clear) on the
 [`Storage`](https://html.spec.whatwg.org/multipage/webstorage.html#storage-2) object associated with `area`.

2. For each `area` in the user agent's set of [session
 storage
 areas](https://html.spec.whatwg.org/multipage/webstorage.html#dom-sessionstorage)
 [\[HTML\]](#biblio-html "HTML Standard"):

 1. If `area`'s
 [origin](https://tools.ietf.org/html/rfc6454#section-3.2) is `origin`:

 1. Execute
 [`clear()`](https://html.spec.whatwg.org/multipage/webstorage.html#dom-storage-clear) on the
 [`Storage`](https://html.spec.whatwg.org/multipage/webstorage.html#storage-2) object associated with `area`.

3. For each `database` in the set of
 [databases](https://w3c.github.io/IndexedDB/#database) for `origin`
 [\[INDEXEDDB\]](#biblio-indexeddb "Indexed Database API"):

 1. [Delete](https://w3c.github.io/IndexedDB/#delete-a-database) `database`.

4. For each `registration` in the user agent's set of
 [service worker
 registrations](https://w3c.github.io/ServiceWorker/#dfn-service-worker-registration):

 1. If `registration`'s [scope
 URL](https://w3c.github.io/ServiceWorker/#dfn-scope-url)'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin) is `origin`:

 1. Execute
 [`unregister()`](https://w3c.github.io/ServiceWorker/#dom-serviceworkerregistration-unregister) on `registration`.

5. For each `appcache` in the user agent's set of
 [application caches]:

 1. If `appcache`'s [application cache
 group] is identified by an URL whose
 [origin](https://url.spec.whatwg.org/#concept-url-origin) is `origin`:

 1. Discard `appcache`.

6. For any other script-accessible storage mechanism, the user agent
 MUST delete any data associated with this origin. This includes (but
 is not limited to) the following:

 1. An origin's WebSQL databases
 [\[WEBDATABASE\]](#biblio-webdatabase "Web SQL Database").

 2. An origin's filesystems
 [\[file-system-api\]](#biblio-file-system-api "File API: Directories and System")

 3. Plugin data (e.g. Flash via
 [NPP_ClearSiteData](https://wiki.mozilla.org/NPAPI:ClearSiteData)),

 4. (#issue-b346d876) Moar?

## 5. Security Considerations

### 5.1. Incomplete Clearing

It is possible that an application could be put into an indeterminate
state by clearing only one type of storage. We mitigate that to some
extent by clearing all storage options as a block, and by requiring that
the header be delivered over a secure connection.

### 5.2. Service workers

It is imperative that the Clear-Site-Data header is only respected on
responses fetched over network, and not those served by a service
worker.

This is because service workers can return arbitrary responses for
resource requests in their scope, including third-party requests. Thus,
supporting Clear-Site-Data would give them the ability to clear data for
any origin.

Note that if a request is sent to a service worker, not handled by it,
then restarted with a [service-workers
mode](https://fetch.spec.whatwg.org/#request-service-workers-mode) of \"`none`\" and sent to the network, the
corresponding response is a network response and can be handled. The
previous attempt at obtaining the response from a service worker is
irrelevant.

Note also that a service worker update is a network response, and is
therefore not affected by this restriction. This is important in order
to support the use case in [§ 1.1.4 Kill Switch](#example-killswitch).

## 6. Privacy Considerations

### 6.1. Web developers control the timing.

If triggered at appropriate times,
[`Clear-Site-Data`](#http-headerdef-clear-site-data) can increase a user's privacy and security by
clearing sensitive data from their user agent. However, note that the
web developer (and *not* the user) is in control of when the clearing
event is triggered. Even assuming a non-malicious site author, users
can't rely on data being cleared at any particular point, nor are users
in control of what data types are cleared.

If a user wishes to ensure that site data is indeed cleared at some
specific point, they ought to rely on the data-clearing functionality
offered by their user agent.

At a bare minimum, user agents OUGHT TO (in the
[\[RFC6919\]](#biblio-rfc6919 "Further Key Words for Use in RFCs to Indicate Requirement Levels")
sense of the words) offer the same functionality to users that they
offer to web developers. Ideally, they will offer significantly more
than we can offer at a platform level (clearing browsing history, for
example).

### 6.2. Remnants of data on disk.

While
[`Clear-Site-Data`](#http-headerdef-clear-site-data) triggers a clearing event in a user's agent, it
is difficult to make promises about the state of a user's disk after a
clearing event takes place. In particular, note that it is up to the
user agent to ensure that all traces of a site's date is actually
removed from disk, which can be a herculean task (consider virtual
memory, as a good example of a larger issue).

In short, most user agents implement data clearing as \"best effort\",
but can't promise an exhaustive wipe.

If a user wishes to ensure that site data does not remain on disk, the
best way to do so is to use a browsing mode that promises not to
intentionally write data to disk (Chrome's \"Incognito\", Internet
Explorer's \"InPrivate\", etc). These modes will do a better job of
keeping data off disk, but are still subject to a number of limitations
at the edges.

## 7. IANA Considerations

The permanent message header field registry should be updated with the
following registration:
[\[RFC3864\]](#biblio-rfc3864 "Registration Procedures for Message Header Fields")

### 7.1. Clear-Site-Data

Header field name
: Clear-Site-Data

Applicable protocol
: http

Status
: standard

Author/Change controller
: W3C

Specification document
: This specification (See [§ 3.1 The Clear-Site-Data HTTP Response
 Header Field](#header))

## 8. Acknowledgements

Michal Zalewski proposed a variant of this concept, and Mark Knichel
helped refine the details.
