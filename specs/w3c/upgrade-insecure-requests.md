
## 1. Introduction

*This section is not normative.*

Increasingly, we encourage authors to transition their sites and
applications away from insecure transport, and onto encrypted and
authenticated connections
[\[WEB-HTTPS\]](#biblio-web-https). While this
migration has significant advantages for both authors and users, it
isn't without negative side-effects.

Most notably, mixed content checking
[\[MIX\]](#biblio-mix) has the potential to cause
real headache for administrators tasked with moving substantial amounts
of legacy content onto HTTPS. In particular, going through old content
and rewriting resource URLs manually is a huge undertaking. Moreover,
it's often the case that truly legacy content is difficult or impossible
to update. Consider the BBC's archived websites
[\[BBC-ARCHIVE\]](#biblio-bbc-archive), or the New
York Times\' hard-coded URLs
[\[NYT-HTTPS\]](#biblio-nyt-https).

We should remove this burden from site authors by allowing them to
assert to a user agent that they intend a site to load only secure
resources, and that insecure URLs ought to be treated as though they had
been replaced with equivalent secure URLs.

This document defines a new Content Security Policy directive,
[`upgrade-insecure-requests`](#upgrade-insecure-requests), through which authors can make this assertion. Note:
Delivering the policy as a header allows an administrator to easily opt
a set of pages into the upgrade mechanism without touching their source
code individually. The legacy content examples above would not be
feasible with an approach that inlined the policy into HTML, for
example.

### 1.1. Goals

The overarching goal is to reduce the burden of migrating websites from
insecure origins by reducing the negative side effects of mixed content
blocking [\[MIX\]](#biblio-mix).

If we assume that authors do the server-side legwork (obtaining a
certificate, configuring the server, setting up redirects), and that
authors also ensure that both first- and third-party content is
accessible at *the same
[host](https://url.spec.whatwg.org/#concept-url-host) and
[path](https://url.spec.whatwg.org/#concept-url-path)* on a secure
[scheme](https://url.spec.whatwg.org/#concept-url-scheme), then the following statements ought to hold after
implementing this feature:

1. Authors should be able to ensure that all content requested by a
 given page loads successfully, and securely. Mixed content blocking
 should not break pages as a result of migrating to a secure origin.

 Note: This requirement is *not* met by Mixed Content's [strict
 mode](https://w3c.github.io/webappsec/specs/mixedcontent/#strict-mode), which makes something like the opposite assertion.

2. As a result of #1, the user agent should not degrade any security
 indicators related to requesting mixed content, as no insecure
 content should be requested.

3. Authors should be able to ensure that all internal links correctly
 send users to the site's secure address, and not to its
 pre-migration insecure address.

4. Authors should be able to achieve all these goals without editing a
 site's content. This is particularly important for archived content
 and legacy systems for which maintenance is difficult enough, never
 mind upgrades.

5. Authors should be able to pursue a gradual transition from insecure
 to secure, serving secure resources to clients that support
 upgrades, while retaining insecure resources for clients that don't.

Note: The mechanism defined here does *not* intend to supplant Strict
Transport Security [\[RFC6797\]](#biblio-rfc6797).
See [§ 7.2 Relation to HSTS](#relation-to-hsts) for details.

### 1.2. Examples

#### 1.2.1. Non-navigational Upgrades

Megacorp, Inc. wishes to migrate
`http://example.com/` to `https://example.com`. They set up their
servers to make their own resources available over HTTPS, and work with
partners in order to make third-party widgets available securely as
well.

They quickly realize, however, that the majority of their content is
locked up in a database tied to an old content management system, and it
contains hardcoded links to insecure resources (e.g., http:// URLs to
images and other content). Unfortunately, it's a substantial amount of
work to update it.

As a stopgap measure, Megacorp injects the following header field into
every HTML response that goes out from their servers:

 Content-Security-Policy: upgrade-insecure-requests

This automatically upgrades all insecure resource requests from their
pages to secure variants, allowing a user agent to treat the following
HTML code:

 <img src="http://example.com/image.png">
 <img src="http://not-example.com/image.png">

as though it had been delivered as:

 <img src="https://example.com/image.png">
 <img src="https://not-example.com/image.png">

The URL will be rewritten before the request is made, meaning that no
insecure requests will hit the network. Users will be safer, and
Megacorp's administrators will be happier, as all resource requests will
be transparently upgraded with no effort on their part.

#### 1.2.2. Navigational Upgrades

Megacorp, Inc. isn't quite ready to
deliver Strict Transport Security headers
[\[RFC6797\]](#biblio-rfc6797), but does want to
keep users on secure pages when possible. Happily, this comes for free
with
[`upgrade-insecure-requests`](#upgrade-insecure-requests). That is, they're already delivering pages with the
following header:

 Content-Security-Policy: upgrade-insecure-requests

This allows user agents to treat the following HTML code:

 <a href="http://example.com/">Home</a>

as though it had been delivered as:

 <a href="https://example.com/">Home</a>

Links to third-party sites will not be upgraded. That is, the following
HTML code:

 <a href="http://not-example.com/">Home</a>

won't be upgraded.

#### 1.2.3. Failed Upgrade

Tinycorp, Inc. enabled
[`upgrade-insecure-requests`](#upgrade-insecure-requests) a bit earlier than they should have, as they don't
actually support HTTPS on `http://cdn.example.com/`. Given the following
code:

 <img src="http://cdn.example.com/image.png">

User agents will upgrade requests, as described in [§ 1.2.1
Non-navigational Upgrades](#example-nonnavigational), rewriting the URL
as `https://cdn.example.com/image.png`. As the server doesn't respond to
secure requests, this results in a network error.

There is no fallback in this scenario: the user agent acts just as
though the request had been intentionally made, and the request fails.

### 1.3. Recommendations

We recommend that authors who wish to ensure that user agents which
support
[upgrade-insecure-requests](#upgrade-insecure-requests) are as secure as possible do the following:

1. Redirect insecure, [safely upgradable
 requests](#safely-upgradable-requests) from HTTP to HTTPS by responding with a `Location`
 header and a `307` status code.

 :::
 (#example-bea94d79) In Nginx, this kind of redirection
 might look like this:
 server {
 if ($http_upgrade_insecure_requests = "1") {
 add_header Vary Upgrade-Insecure-Requests;
 return 307 https://$host$request_uri;
 }
 }

 This is, of course, greatly simplified; your configuration will
 likely be significantly more complex.
 :::

2. Respond to [potentially trustworthy
 URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url) [safely upgradable
 requests](#safely-upgradable-requests) with a
 [`upgrade-insecure-requests`](#upgrade-insecure-requests) directive if necessary for the resource being
 requested.

 :::
 (#example-1ea61462) In Nginx, adding this directive
 might look like this:
 server {
 ...

 add_header Content-Security-Policy upgrade-insecure-requests;

 ...
 }

 This is, of course, greatly simplified; your configuration will
 likely be significantly more complex.
 :::

3. If the origin is
 [HSTS-safe](#hsts-safe-origin), then protect against SSL-stripping
 man-in-the-middle attacks by sending a
 [`Strict-Transport-Security`](https://tools.ietf.org/html/rfc6797#section-6.1) header with the `preload` directive, and ensure
 that insecure content is never loaded by enabling Mixed Content's
 [strict
 mode](https://w3c.github.io/webappsec/specs/mixedcontent/#strict-mode).

 :::
 (#example-90559593) In Nginx, adding this header might
 look like this (note the use of the `preloaded` directive, which
 signifies that this origin's HSTS state can be safely imported into
 user agents\' HSTS preload lists):
 server {
 ...

 add_header Strict-Transport-Security "max-age=10886400; preload"
 add_header Content-Security-Policy block-all-mixed-content;

 ...
 }

 This is, of course, greatly simplified; your configuration will
 likely be significantly more complex.
 :::

 Additionally, work with user agent vendors to add the origin to HSTS
 Preload Lists (for example, by submitting the origin to
 [hstspreload.appspot.com](https://hstspreload.appspot.com/)).

4. If the origin is [conditionally
 HSTS-safe](#conditionally-hsts-safe-origin), then opt-into HSTS only in response to [safely
 upgradable
 requests](#safely-upgradable-requests).

 :::
 (#example-359e368a) In Nginx, adding this header
 conditionally might look like this (note the use of `map`, as
 setting headers inside `if` without returning immediately is, well,
 iffy):
 server {
 ...

 map $http_https $sts {
 "1" "max-age=10886400"
 }

 add_header Strict-Transport-Security $sts;

 ...
 }

 This is, of course, greatly simplified; your configuration will
 likely be significantly more complex.
 :::

## 2. Key Concepts and Terminology

[upgrade(#upgrade-a-request)]

: A
 [request](https://fetch.spec.whatwg.org/#concept-request) is said to be **upgraded** if it is rewritten to
 contain a URL with a
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) of `https` or `wss`.

[safely upgradable requests]

: A
 [request](https://fetch.spec.whatwg.org/#concept-request) is said to be **safely upgradable** if the
 [resource
 representation](https://tools.ietf.org/html/rfc7231#section-3) which will be returned does not require the
 [`upgrade-insecure-requests`](#upgrade-insecure-requests) mechanism described in this document to avoid
 breakage, or if the
 [request](https://fetch.spec.whatwg.org/#concept-request)\'s [header
 list](https://fetch.spec.whatwg.org/#concept-request-header-list) contains an [`Upgrade-Insecure-Requests` header
 field](#upgrade-insecure-requests-http-request-header-field) with a value of `1`.

[HSTS-safe origin]

: An
 [origin](https://tools.ietf.org/html/rfc6454#section-3.2) is said to be **HSTS-safe** if no [resource
 representations](https://tools.ietf.org/html/rfc7231#section-3) it returns requires the the
 [`upgrade-insecure-requests`](#upgrade-insecure-requests) mechanism described in this document to avoid
 breakage, and if all [resource
 representations](https://tools.ietf.org/html/rfc7231#section-3) it returns can be served over HTTPS.

 [HSTS-safe origins](#hsts-safe-origin) can safely opt-into
 [`Strict-Transport-Security`](https://tools.ietf.org/html/rfc6797#section-6.1) for all user agents, without risking broken pages
 for user agents which do not support
 [`upgrade-insecure-requests`](#upgrade-insecure-requests).

[conditionally HSTS-safe origin]

: An
 [origin](https://tools.ietf.org/html/rfc6454#section-3.2) is said to be **conditionally HSTS-safe** if one or
 more [resource
 representations](https://tools.ietf.org/html/rfc7231#section-3) it returns requires the
 [`upgrade-insecure-requests`](#upgrade-insecure-requests) mechanism described in this document to avoid
 breakage, and if all [resource
 representations](https://tools.ietf.org/html/rfc7231#section-3) it returns can be served over HTTPS.

 [Conditionally HSTS-safe
 origins](#conditionally-hsts-safe-origin) can safely opt-into
 [`Strict-Transport-Security`](https://tools.ietf.org/html/rfc6797#section-6.1) only for user agents which support
 [`upgrade-insecure-requests`](#upgrade-insecure-requests).

[preloadable HSTS host]

: A
 [host](https://url.spec.whatwg.org/#concept-url-host) `host` is a **preloadable HSTS host**
 if, when performing [Known HSTS Host Domain Name
 Matching](https://tools.ietf.org/html/rfc6797#section-8.2), `host` is a [superdomain
 match](https://tools.ietf.org/html/rfc6797#section-8.2) for a [Known HSTS
 Host](https://tools.ietf.org/html/rfc6797#section-8.1.1) which asserts both the
 [includeSubDomains](https://tools.ietf.org/html/rfc6797#section-6.1.2) directive and the `preload` directive, or
 `host` is a [congruent
 match](https://tools.ietf.org/html/rfc6797#section-8.2)for a [Known HSTS
 Host](https://tools.ietf.org/html/rfc6797#section-8.1.1) which asserts the `preload` directive.

 Note: This is a long way of saying \"any host the user agent has
 pinned with a
 [`Strict-Transport-Security`](https://tools.ietf.org/html/rfc6797#section-6.1) header that contained a `preload` directive\".

The Augmented Backus-Naur Form (ABNF) notation used in [§ 3.1 The
upgrade-insecure-requests Content Security Policy directive](#delivery)
is specified in RFC5234. [\[ABNF\]](#biblio-abnf)

## 3. Upgrading Insecure Resource Requests

In order to allow authors to mitigate the negative side-effects of
migration away from insecure origins, authors may instruct the user
agent to transparently upgrade resource requests to [potentially
trustworthy
URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url) variants of the original request's URL.

To support this instruction:

1. [Environment settings
 objects](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) and [browsing
 contexts](https://html.spec.whatwg.org/multipage/browsers.html#browsing-context) are given an [insecure requests
 policy] which has two potential values [Do Not
 Upgrade] and
 [Upgrade].
 It is set to [Do Not
 Upgrade](#valdef-insecure-requests-policy-do-not-upgrade) unless otherwise specified. This policy is
 checked in [§ 4.1 Upgrade request to a potentially trustworthy URL,
 if appropriate](#upgrade-request) in order
 to determine whether or not non-navigation requests and form
 submissions should be upgraded during
 [fetching](https://fetch.spec.whatwg.org/#concept-fetch).
2. [Environment settings
 objects](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) and [browsing
 contexts](https://html.spec.whatwg.org/multipage/browsers.html#browsing-context) are given an [upgrade insecure navigations
 set] which contains a set of
 ([host](https://url.spec.whatwg.org/#concept-url-host),
 [port](https://url.spec.whatwg.org/#concept-url-port)) tuples to which navigations ought to be upgraded.
 Its value is the empty set unless otherwise specified. This set is
 checked in [§ 4.1 Upgrade request to a potentially trustworthy URL,
 if appropriate](#upgrade-request) in
 order to determine whether or not [navigation
 requests](https://fetch.spec.whatwg.org/#navigation-request) should be upgraded.

### 3.1. The `upgrade-insecure-requests` Content Security Policy directive

**✔**MDN

[Headers/Content-Security-Policy/upgrade-insecure-requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/upgrade-insecure-requests "The HTTP Content-Security-Policy (CSP) upgrade-insecure-requests directive instructs user agents to treat all of a site's insecure URLs (those served over HTTP) as though they have been replaced with secure URLs (those served over HTTPS). This directive is intended for web sites with large numbers of insecure legacy URLs that need to be rewritten.")

In all current engines.

[Firefox42+][Safari10.1+][Chrome43+]

------------------------------------------------------------------------

[Opera?][Edge79+]

------------------------------------------------------------------------

[Edge (Legacy)17+][IENone]

------------------------------------------------------------------------

[Firefox for Android?][iOS Safari?][Chrome for Android?][Android
WebView?][Samsung
Internet?][Opera Mobile?]

A server MAY instruct a user agent to upgrade insecure requests for a
particular [protected
resource](https://www.w3.org/TR/CSP/#protected-resource) by sending a
[`Content-Security-Policy`](https://www.w3.org/TR/CSP/#content-security-policy) header [\[CSP\]](#biblio-csp) that
contains a [upgrade-insecure-requests] directive, defined via the
following ABNF grammar:

 directive-name = "upgrade-insecure-requests"
 directive-value = ""

When [enforcing](https://www.w3.org/TR/CSP/#enforce) the `upgrade-insecure-requests` directive:

1. Let `settings` be the [protected
 resource](https://www.w3.org/TR/CSP/#protected-resource)'s [incumbent settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#incumbent-settings-object).
2. Set `settings`'s [insecure requests
 policy](#insecure-requests-policy) to
 [Upgrade](#valdef-insecure-requests-policy-upgrade).
3. Let `tuple` be a tuple of the [protected
 resource](https://www.w3.org/TR/CSP/#protected-resource)'s
 [URL](https://url.spec.whatwg.org/#concept-url)\'s
 [host](https://url.spec.whatwg.org/#concept-url-host) and
 [port](https://url.spec.whatwg.org/#concept-url-port).
4. Insert `tuple` into `settings`'s [upgrade
 insecure navigations
 set](#upgrade-insecure-navigations-set).

[Monitoring](https://www.w3.org/TR/CSP/#monitor) the `upgrade-insecure-requests` directive has no
effect: the directive is ignored when sent via a
[`Content-Security-Policy-Report-Only`](https://www.w3.org/TR/CSP/#content-security-policy-report-only) header. Authors can determine whether or not upgraded
resources\' original URLs were insecure via
[`Content-Security-Policy-Report-Only`](https://www.w3.org/TR/CSP/#content-security-policy-report-only). For example,
[`Content-Security-Policy-Report-Only`](https://www.w3.org/TR/CSP/#content-security-policy-report-only)`: default-src https:; report-uri /endpoint`. See [§ 3.4
Reporting Upgrades](#reporting-upgrades) for additional detail.

#### 3.1.1. Relation to \"Mixed Content\"

The
[`upgrade-insecure-requests`](#upgrade-insecure-requests) directive results in requests being rewritten at the
top of the
[Fetching](https://fetch.spec.whatwg.org/#concept-fetch) algorithm
[\[FETCH\]](#biblio-fetch), as specified in [§ 4.1
Upgrade request to a potentially trustworthy URL, if
appropriate](#upgrade-request). It's
important to note that the rewrite happens *before* either Mixed Content
[\[MIX\]](#biblio-mix) or Content Security Policy
checks take effect [\[CSP\]](#biblio-csp).

This ordering means that upgraded requests *will not* be flagged as
mixed content. Moreover, it means that
[`upgrade-insecure-requests`](#upgrade-insecure-requests)'s effect takes place before the
[`block-all-mixed-content`](https://w3c.github.io/webappsec/specs/mixedcontent/#block-all-mixed-content) directive would have a chance to block the request. If
the former is set, the latter is effectively a no-op.

We recommend that authors set one directive or the other, as outlined in
[§ 1.3 Recommendations](#recommendations).

### 3.2. Feature Detecting Clients Capable of Upgrading

Sites which require the upgrade mechanism laid out in this document in
order to provide users with a reasonable experience over secure transit
need some way to determine whether or not a particular
[request](https://fetch.spec.whatwg.org/#concept-request) can safely be redirected from HTTP to HTTPS (and
vice-versa). Moreover, [conditionally HSTS-safe
origins](#conditionally-hsts-safe-origin) can only opt-into
[`Strict-Transport-Security`](https://tools.ietf.org/html/rfc6797#section-6.1) for supported user agents, and doing otherwise could
have negative consequences for the site's users.

Rather than relying on user-agent sniffing to make this decision, user
agents can advertise their upgrade capability when making [navigation
requests](https://fetch.spec.whatwg.org/#navigation-request) by including an [`Upgrade-Insecure-Requests` header
field](#upgrade-insecure-requests-http-request-header-field) as described in [§ 3.2.1 The Upgrade-Insecure-Requests
HTTP Request Header Field](#preference).

#### 3.2.1. The `Upgrade-Insecure-Requests` HTTP Request Header Field

**✔**MDN

[Headers/Upgrade-Insecure-Requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Upgrade-Insecure-Requests "The HTTP Upgrade-Insecure-Requests request header sends a signal to the server expressing the client's preference for an encrypted and authenticated response, and that it can successfully handle the upgrade-insecure-requests CSP directive.")

In all current engines.

[Firefox48+][Safari10.1+][Chrome44+]

------------------------------------------------------------------------

[Opera?][Edge79+]

------------------------------------------------------------------------

[Edge (Legacy)17+][IENone]

------------------------------------------------------------------------

[Firefox for Android?][iOS Safari?][Chrome for Android?][Android
WebView?][Samsung
Internet?][Opera Mobile?]

The [ `Upgrade-Insecure-Requests` HTTP request header
field] sends a signal
to the server expressing the client's preference for an encrypted and
authenticated response, and that it can successfully handle the
[`upgrade-insecure-requests`](#upgrade-insecure-requests) directive in order to make that preference as seamless
as possible to provide.

This preference is represented by the following ANBF:

 "Upgrade-Insecure-Requests:" *WSP "1" *WSP

Note: Though the `Upgrade-Insecure-Requests` header expresses a
preference, sending it via the existing
[`Prefer`](https://tools.ietf.org/html/rfc7240#section-2) header is problematic, as we expect the response from
the server to use it as part of the cache key. `Vary: Prefer` is too
broad, as discussed in
[w3/webappsec#216](https://github.com/w3c/webappsec/issues/216).

User agent conformance details are described in step #1 of the the
[§ 4.1 Upgrade request to a potentially trustworthy URL, if
appropriate](#upgrade-request) algorithm.
That step represents the following requirements:

1. User agents MUST send an [`Upgrade-Insecure-Requests` header
 field](#upgrade-insecure-requests-http-request-header-field) along with
 [request](https://fetch.spec.whatwg.org/#concept-request)s for insecure URLs.

 Note: Servers can use this signal to upgrade HTTP requests to HTTPS
 for pages that require
 [`upgrade-insecure-requests`](#upgrade-insecure-requests) support.

2. User agents MUST send an [`Upgrade-Insecure-Requests` header
 field](#upgrade-insecure-requests-http-request-header-field) along with
 [request](https://fetch.spec.whatwg.org/#concept-request)s for [potentially trustworthy
 URLs](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url) whose
 [URL](https://fetch.spec.whatwg.org/#concept-request-url)\'s
 [host](https://url.spec.whatwg.org/#concept-url-host) is *not* a [preloadable HSTS
 host](#preloadable-hsts-host).

 Note: Servers can use the absence of this signal to downgrade HTTPS
 requests to HTTP for pages that require
 [`upgrade-insecure-requests`](#upgrade-insecure-requests) support.

3. User agents SHOULD periodically send an [`Upgrade-Insecure-Requests`
 header
 field](#upgrade-insecure-requests-http-request-header-field) along with
 [request](https://fetch.spec.whatwg.org/#concept-request)s for [potentially trustworthy
 URLs](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url) whose
 [URL](https://fetch.spec.whatwg.org/#concept-request-url)\'s
 [host](https://url.spec.whatwg.org/#concept-url-host) *is* a [preloadable HSTS
 host](#preloadable-hsts-host). For example, user agents could send an
 [`Upgrade-Insecure-Requests` header
 field](#upgrade-insecure-requests-http-request-header-field) only when the asserted `max-age` is a few days from
 expiration, or only for a small percentage of requests.

 Note: [preloadable HSTS
 hosts](#preloadable-hsts-host) have asserted that they are
 [HSTS-safe](#hsts-safe-origin), and therefore don't need a downgrade signal. They
 will need to refresh HSTS status before the asserted `max-age`
 expires, and the [`Upgrade-Insecure-Requests` header
 field](#upgrade-insecure-requests-http-request-header-field) serves as a fine signal that HSTS could be
 refreshed.

When a server encounters this preference in an HTTP request's headers,
it SHOULD redirect the user to a [potentially trustworthy
URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url) variant of the resource being requested.

When a server encounters this preference in an HTTPS request's headers,
it SHOULD include a
[`Strict-Transport-Security`](https://tools.ietf.org/html/rfc6797#section-6.1) header in the response if the request's
[host](https://url.spec.whatwg.org/#concept-url-host) is
[HSTS-safe](#hsts-safe-origin) or [conditionally
HSTS-safe](#conditionally-hsts-safe-origin) [\[RFC6797\]](#biblio-rfc6797).

A client that supports this document's
upgrade mechanism requests `http://example.com/` as follows:

 GET / HTTP/1.1
 Host: example.com
 Upgrade-Insecure-Requests: 1

The server parses the preference, notices that the user's client can
deal well with upgrade requests, and therefore responds to the request
by redirecting the user to a secure version of the resource she's
requesting:

 HTTP/1.1 307 Moved Temporarily
 Location: https://example.com/
 Vary: Upgrade-Insecure-Requests

The [`Upgrade-Insecure-Requests` header
field](#upgrade-insecure-requests-http-request-header-field) is listed in the
[`Vary`](https://tools.ietf.org/html/rfc7231#section-7.1.4) header, as the redirect response might otherwise be
served by caches to clients that don't support the upgrade mechanism
defined here. A similar effect could be achieved by making this redirect
response uncachable via the
[`Cache-Control`](https://tools.ietf.org/html/rfc7234#section-5.2) header:

 HTTP/1.1 307 Moved Temporarily
 Location: https://example.com/
 Cache-Control: no-store

### 3.3. Policy Inheritance

If a
[`Document`](http://www.w3.org/TR/dom/#interface-document)\'s [incumbent settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#incumbent-settings-object)'s [insecure requests
policy](#insecure-requests-policy) is set to
[Upgrade](#valdef-insecure-requests-policy-upgrade), the user agent MUST ensure that all [nested
browsing
contexts](https://html.spec.whatwg.org/multipage/browsers.html#nested-browsing-context) inherit the setting in the following ways:

1. When a [nested browsing
 context](https://html.spec.whatwg.org/multipage/browsers.html#nested-browsing-context) `context` is created:
 1. If `context`'s [embedding
 document](https://w3c.github.io/webappsec-mixed-content/#embedding-document)'s [insecure requests
 policy](#insecure-requests-policy) is
 [Upgrade](#valdef-insecure-requests-policy-upgrade), then:
 1. Set `context`'s [insecure requests
 policy](#insecure-requests-policy) to
 [Upgrade](#valdef-insecure-requests-policy-upgrade).
 2. For each `value` in `context`'s
 [embedding
 document](https://w3c.github.io/webappsec-mixed-content/#embedding-document)'s [upgrade insecure navigations
 set](#upgrade-insecure-navigations-set), add `value` to
 `context`'s [upgrade insecure navigations
 set](#upgrade-insecure-navigations-set).
2. When [creating a new `Document`
 object](https://html.spec.whatwg.org/multipage/browsers.html#create-a-document-object) `document` in a [browsing
 context](https://html.spec.whatwg.org/multipage/browsers.html#browsing-context) `context`:
 1. If `context`'s [insecure requests
 policy](#insecure-requests-policy) is
 [Upgrade](#valdef-insecure-requests-policy-upgrade), then:
 1. Let `settings` be `document`'s
 [incumbent settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#incumbent-settings-object).
 2. Set `settings`' [insecure requests
 policy](#insecure-requests-policy) to
 [Upgrade](#valdef-insecure-requests-policy-upgrade).
 3. For each `value` in `context`'s
 [upgrade insecure navigations
 set](#upgrade-insecure-navigations-set), add `value` to
 `settings`'s [upgrade insecure navigations
 set](#upgrade-insecure-navigations-set).

Likewise, when spinning up a worker, the user agent MUST ensure that it
inherits the setting from the context that created it in the following
ways:

1. When executing the [set up a worker environment settings
 object](http://www.w3.org/TR/workers/#script-settings-for-workers) algorithm, perform the following steps after the
 current step #4:
 5. If `inherited responsible browsing context`'s
 [insecure requests
 policy](#insecure-requests-policy) is
 [Upgrade](#valdef-insecure-requests-policy-upgrade), then:
 1. Set `settings object`'s [insecure requests
 policy](#insecure-requests-policy) to
 [Upgrade](#valdef-insecure-requests-policy-upgrade).
 2. For each `value` in
 `inherited responsible browsing context`'s
 [upgrade insecure navigations
 set](#upgrade-insecure-navigations-set), add `value` to
 `settings object`'s [upgrade insecure navigations
 set](#upgrade-insecure-navigations-set).

### 3.4. Reporting Upgrades

Upgrading insecure requests MUST not interfere with an authors\' ability
to track down requests that would be insecure in a user agent that does
not support upgrades. To that end, upgrades MUST be performed *after*
evaluating `request` against all
[monitored](https://www.w3.org/TR/CSP/#monitor) security policies, but *before* evaluating
`request` against all
[enforced](https://www.w3.org/TR/CSP/#enforce) policies.

Within the context of a [protected
resource](https://www.w3.org/TR/CSP/#protected-resource) which contains the insecure image
`<img src="http://example.com/image.png">`, and delivers the following
HTTP headers:

 Content-Security-Policy: upgrade-insecure-requests; default-src https:
 Content-Security-Policy-Report-Only: default-src https:; report-uri /endpoint

The user agent will fire off a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` that:

1. Violates the policy being
 [monitored](https://www.w3.org/TR/CSP/#monitor), thereby delivering a [violation
 report](https://www.w3.org/TR/CSP/#example-violation-report) to `/endpoint`.
2. Is upgraded from `http://example.com/image.png` to
 `http`**`s`**`://example.com/image.png`.
3. Does not violate the policy being
 [enforced](https://www.w3.org/TR/CSP/#enforce).

Note: This will be significantly clarified once
[\[CSP\]](#biblio-csp) is rewritten in terms of
[\[FETCH\]](#biblio-fetch).

## 4. Processing Algorithms

### [4.1. ][ Upgrade `request` to a [potentially trustworthy URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url), if appropriate ]
Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, this algorithm will rewrite its
[URL](https://fetch.spec.whatwg.org/#concept-request-url) if the
[client](https://fetch.spec.whatwg.org/#concept-request-client) from which the request originates has opted-in to
upgrades. It will also inject an [`Upgrade-Insecure-Requests` header
field](#upgrade-insecure-requests-http-request-header-field) header for insecure [navigation
requests](https://fetch.spec.whatwg.org/#navigation-request) in order to improve a server's ability to
feature-detect a client's upgrade capabilities.

We will not upgrade cross-origin [navigation
requests](https://fetch.spec.whatwg.org/#navigation-request), with the exception of form submissions. Form
submissions will be upgraded to mitigate the risk of data leakage via
plaintext submissions.

Note: This algorithm is called at the top of the [Main
Fetch](https://fetch.spec.whatwg.org/#main-fetch) algorithm.

1. If `request` is a [navigation
 request](https://fetch.spec.whatwg.org/#navigation-request),
 [append](https://fetch.spec.whatwg.org/#concept-header-list-append) a header named `Upgrade-Insecure-Requests` with a
 value of `1` to `request`'s [header
 list](https://fetch.spec.whatwg.org/#concept-request-header-list) if any of the following criteria are met:

 1. `request`'s
 [URL](https://fetch.spec.whatwg.org/#concept-request-url) is not a [potentially trustworthy
 URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url)
 2. `request`'s
 [URL](https://fetch.spec.whatwg.org/#concept-request-url)\'s
 [host](https://url.spec.whatwg.org/#concept-url-host) is *not* a [preloadable HSTS
 host](#preloadable-hsts-host)

 Note: User agents can choose to append the
 [`Upgrade-Insecure-Requests` header
 field](#upgrade-insecure-requests-http-request-header-field) for other requests, as discussed in [§ 3.2.1 The
 Upgrade-Insecure-Requests HTTP Request Header Field](#preference).

2. If `request` is a [navigation
 request](https://fetch.spec.whatwg.org/#navigation-request), then:

 1. If `request` is a form submission, skip the remaining
 substeps, and continue upgrading `request`.
 2. If `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client)\'s [target browsing
 context](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-target-browsing-context) is a [nested browsing
 context](https://html.spec.whatwg.org/multipage/browsers.html#nested-browsing-context), skip the remaining substeps and continue
 upgrading `request`.
 3. Let `tuple` be a tuple of `request`'s
 [URL](https://fetch.spec.whatwg.org/#concept-request-url)\'s
 [host](https://url.spec.whatwg.org/#concept-url-host) and
 [port](https://url.spec.whatwg.org/#concept-url-port).
 4. If `tuple` is contained in
 [client](https://fetch.spec.whatwg.org/#concept-request-client)\'s [upgrade insecure navigations
 set](#upgrade-insecure-navigations-set), then skip the remaining substeps, and continue
 upgrading `request`.
 5. Return without further modifying `request`.

 Note: We only upgrade top-level [navigation
 requests](https://fetch.spec.whatwg.org/#navigation-request) for hosts that have explicitly opted-into the
 behavior for a particular [protected
 resource](https://www.w3.org/TR/CSP/#protected-resource), as described in [§ 1.2 Examples](#examples).
 Performing upgrades for top-level navigations to third-party
 resources brings a significantly higher potential for breakage, so
 we're avoiding it for the moment. Nested navigations (via
 [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element), for example) affect the security status of
 their embedder, so we ensure that they are upgraded if necessary.

3. Let `upgrade state` be the result of executing [§ 4.2
 Should insecure requests be upgraded for
 client?](#should-upgrade-for-client) upon `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client).

4. If `upgrade state` is [Do Not
 Upgrade](#valdef-insecure-requests-policy-do-not-upgrade), return without modifying
 `request`.

5. If `request`'s
 [URL](https://fetch.spec.whatwg.org/#concept-request-url)\'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is \"`http`\", set `request`'s
 [URL](https://fetch.spec.whatwg.org/#concept-request-url)\'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) to \"`https`\", and return.

Note: Due to [\[FETCH\]](#biblio-fetch)\'s recursive
nature, this algorithm will upgrade insecurely-redirected requests as
well as insecure initial requests.

### [4.2. ][ Should insecure [request](https://fetch.spec.whatwg.org/#concept-request)s be upgraded for `client`? ]
Given an
[request](https://fetch.spec.whatwg.org/#concept-request)\'s
[client](https://fetch.spec.whatwg.org/#concept-request-client) `client` (an [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object)), this algorithm returns `Enforced Upgrade` if insecure
requests associated with that client should be upgraded, or [Do Not
Upgrade](#valdef-insecure-requests-policy-do-not-upgrade) otherwise. In short, this will check the client
and return the appropriate [insecure requests
policy](#insecure-requests-policy) set on it or its [browsing
context](https://html.spec.whatwg.org/multipage/browsers.html#browsing-context).

1. If `client` has a [responsible
 document](https://html.spec.whatwg.org/multipage/webappapis.html#responsible-document), return the value of its [insecure requests
 policy](#insecure-requests-policy).

 Note: This catches
 [`Document`](http://www.w3.org/TR/dom/#interface-document)s or
 [`Worker`](http://www.w3.org/TR/workers/#worker)s whose policy is set directly by the
 [`upgrade-insecure-requests`](#upgrade-insecure-requests) directive, or which have inherited the policy from
 an [embedding
 document](https://w3c.github.io/webappsec-mixed-content/#embedding-document).

2. If `client` has a [responsible browsing
 context](https://html.spec.whatwg.org/multipage/webappapis.html#responsible-browsing-context), return the value of its [insecure requests
 policy](#insecure-requests-policy).

 Note: This catches requests triggered from detached
 [client](https://fetch.spec.whatwg.org/#concept-request-client)s. Not sure this is necessary, really, given the
 inheritance structure defined in [§ 3.3 Policy
 Inheritance](#nesting).

3. Return [Do Not
 Upgrade](#valdef-insecure-requests-policy-do-not-upgrade).

## 5. Security Considerations

### 5.1. Interaction with HSTS

The
[`upgrade-insecure-requests`](#upgrade-insecure-requests) directive does not replace the
[`Strict-Transport-Security`](https://tools.ietf.org/html/rfc6797#section-6.1) HTTP response header
[\[RFC6797\]](#biblio-rfc6797). Authors who serve
their site over secure transport SHOULD send that header with an
appropriate `max-age` in order to ensure that users are not subject to
SSL stripping attacks by maliciously active network attackers, or
monitoring by maliciously passive network attackers.

### 5.2. CSP Violation Reports

When sending a violation report for an upgraded resource, user agents
MUST target the
[`Document`](http://www.w3.org/TR/dom/#interface-document) or
[`Worker`](http://www.w3.org/TR/workers/#worker) that triggered the request, rather than the
[`Document`](http://www.w3.org/TR/dom/#interface-document) or
[`Worker`](http://www.w3.org/TR/workers/#worker) on which the
[`upgrade-insecure-requests`](#upgrade-insecure-requests) directive was set. Due to [§ 3.3 Policy
Inheritance](#nesting), the latter might be a cross-origin ancestor of
the former, and sending violation reports to that set of reporting
endpoints could leak data in unexpected ways.

Likewise, the `SecurityPolicyViolationEvent` MUST NOT target any
[`Document`](http://www.w3.org/TR/dom/#interface-document) other than the one which triggered the request, for the
same reasons.

## 6. Performance Considerations

The upgrade mechanism specified here adds
`Upgrade-Insecure-Requests: 1\r\n` to every outgoing [navigation
request](https://fetch.spec.whatwg.org/#navigation-request) to non-[preloadable HSTS
hosts](#preloadable-hsts-host) (as discussed at length on public-webappsec@, and
[w3c/webappsec#216](https://github.com/w3c/webappsec/issues/216)). The
advantages and intent of the header are laid out in [§ 3.2.1 The
Upgrade-Insecure-Requests HTTP Request Header Field](#preference), and
though we've taken some steps to ensure that it won't be a permanent
fixture of the platform (by carving out [preloadable HSTS
hosts](#preloadable-hsts-host)), it's going to be a long, long time before the header
vanishes.

User agents are encouraged to find additional carveouts, and implement
them.

## 7. Authoring Considerations

### 7.1. Legacy Clients

Legacy clients which do support mixed content blocking
[\[MIX\]](#biblio-mix), but do not support the
[`upgrade-insecure-requests`](#upgrade-insecure-requests) directive will continue to have a suboptimal experience
on pages containing insecure URLs. Authors SHOULD ensure that they
collect [violation
reports](https://www.w3.org/TR/CSP/#send-violation-reports) in order to determine which resources are most
problematic for their users, and SHOULD use that information to
prioritize fixes for URLs in legacy content that users will most likely
request.

### 7.2. Relation to HSTS

The mechanism specified here deals only with the security policy for a
specific [protected
resource](https://www.w3.org/TR/CSP/#protected-resource). It does not deprecate, replace, or in any way reduce
the value of the `Strict-Transport-Security` HTTP response header
[\[RFC6797\]](#biblio-rfc6797). Authors can and
should continue to use that header to ensure that their users are not
subject to SSL stripping downgrade attacks, as the
[`upgrade-insecure-requests`](#upgrade-insecure-requests) directive will not ensure that users visiting your site
via links on third-party sites will be upgraded to HTTPS for the
top-level navigation.

Likewise, the `Strict-Transport-Security` header does not imply the
behavior that
[`upgrade-insecure-requests`](#upgrade-insecure-requests) activates. It only ensures that resources requested
from an origin will never hit the network insecurely.

We are intentionally keeping these concepts distinct, as authors may
choose to activate one or the other behavior, but ought not be forced to
bind them together.

## 8. IANA Considerations

### 8.1. Upgrade-Insecure-Requests Header

The permanent message header field registry should be updated with the
following registration:
[\[RFC3864\]](#biblio-rfc3864)

Header field name
: Upgrade-Insecure-Requests

Applicable protocol
: http

Status
: standard

Author/Change controller
: W3C

Specification document
: This specification (See [§ 3.2.1 The Upgrade-Insecure-Requests HTTP
 Request Header Field](#preference))

### 8.2. Upgrade-Insecure-Requests Directive

The Content Security Policy Directive registry should be updated with
the following registration:
[\[RFC7762\]](#biblio-rfc7762)

Directive name
: Upgrade-Insecure-Requests

Reference
: This specification (See [§ 3.1 The upgrade-insecure-requests Content
 Security Policy directive](#delivery))

## 9. Acknowledgements

Anne van Kesteren helped ensure that the initial draft of this document
was sane. Peter Eckersley and Daniel Kahn Gillmor clarified the problem
space, and helped point out the impact.
