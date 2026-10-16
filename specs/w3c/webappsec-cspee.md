
## 1. Introduction

*This section is not normative.*

Content Security Policy is a great defense against cross-site scripting
attacks, allowing developers to harden their own sites against injection
of malicious script, style, and other resource types. It does not,
however, give developers the ability to apply restrictions to
third-party content loaded in via
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element). Allowing CSP to apply directly to these
third-party contexts would be dangerous; CSP gives quite granular
control over resource loading, and it's very possible to introduce
vulnerabilities into an otherwise secure page by denying it access to
particular scripts. We've seen these kinds of issues in past features
such as `X-XSS-Protection`, so we must be careful to avoid reintroducing
them in a new form.

That said, it would be quite useful to be able to place restrictions
upon widgets, advertisements, and other kinds of third-party content.
This document proposes a mechanism which relies on an explicit opt-in
from the embedded content, which ought to make it possible for widgets
to cooperate with their embedders to negotiate a reasonable set of
restrictions.

In short, the embedder proposes a Content Security Policy by setting an
attribute on an
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element. This policy is transmitted along with the
HTTP request for the framed content in an HTTP request header
(\`[`Sec-Required-CSP`](#http-headerdef-sec-required-csp)\`). If the embedded content can accept that
policy, it can enforce it by returning a
\`[`Content-Security-Policy`](https://w3c.github.io/webappsec-csp/#header-content-security-policy)\` or
\`[`Allow-CSP-From`](#http-headerdef-allow-csp-from)\` header along with the response.

If the response contains a policy at least as strict as the policy which
the embedder requested, or accepts the embedder-provided policy, then
the user agent will render the embedded content. If no such assertion is
present, the response will be blocked.

### 1.1. Examples

MegaCorp Inc. wishes to ensure that the
advertisements that run on its various publications are locked down to
include script from trusted origins that have been audited for safety.
They can do so by including the advertisement via an
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element with a
[`csp`](#element-attrdef-iframe-csp) attribute:

 <iframe src="https://advertisements-r-us.example.com/ad1.cfm"
 csp="script-src https://trusted-cdn.example.com/">
 </iframe>

This will generate a request to `advertisements-r-us.example.com` that
has a
\`[`Sec-Required-CSP`](#http-headerdef-sec-required-csp)\` header, as follows:

 GET / HTTP/1.1
 Host: advertisements-r-us.example.com
 ...
 Sec-Required-CSP: script-src https://trusted-cdn.example.com/
 ...

The advertisement server parses this request header, decides that it's
acceptable, and adds a header to the response, informing the user agent
that it will adhere to the restrictions imposed by its embedder
(`https://example.com`):

 HTTP/1.1 200 OK
 ...
 Allow-CSP-From: https://example.com

The advertisement server in the example above
could also accept the restrictions by emitting its own
\`[`Content-Security-Policy`](https://w3c.github.io/webappsec-csp/#header-content-security-policy)\` header that's at least as strong as the
policy which the embedder requires. For example, it might wish to ensure
that no plugins are loaded, regardless of what the embedder allows. It
can do so by emitting a policy that includes the embedder's
restrictions, and adds more on top:

 HTTP/1.1 200 OK
 ...
 Content-Security-Policy: script-src https://trusted-cdn.example.com/; object-src 'none'

Since the policy asserted by the response allows strictly fewer requests
than the policy required by the request, the frame loads successfully.

Note that the server could also deliver two policies, one which mirrors
the restrictions of the embedder exactly, another which tightens them:

 HTTP/1.1 200 OK
 ...
 Content-Security-Policy: script-src https://trusted-cdn.example.com/, object-src 'none'

The \"`,`\" in the
\`[`Content-Security-Policy`](https://w3c.github.io/webappsec-csp/#header-content-security-policy)\` header's value splits the string into two
serialized policies, each of which is enforced. The user agent verifies
that one of the policies delivered with the response matches the
requirement, and since additional policies can only make the *effective*
policy for the page more restrictive, allows the frame to load
successfully.

## 2. Framework

At a high level, this document describes a mechanism by which an embedee
can opt-into a set of restrictions specified by its embedder. The
mechanism involves a few steps:

1. The embedder specifies a required policy via a
 [`csp`](#element-attrdef-iframe-csp) attribute on an
 [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element. This is described in more detail in
 [§ 2.1 \<iframe\>'s csp attribute](#csp-attribute).

2. That attribute's value will be sent along as a
 \`[`Sec-Required-CSP`](#http-headerdef-sec-required-csp)\` request header with any [navigation
 request](https://fetch.spec.whatwg.org/#navigation-request) that targets the
 [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)'s [child
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable). This header is described in more detail in [§ 2.2
 The Sec-Required-CSP HTTP Request Header](#required-csp-header).

3. The server can examine the
 \`[`Sec-Required-CSP`](#http-headerdef-sec-required-csp)\` header to determine whether it wishes to
 accept the required policy.If so, it can implicitly opt-in by
 sending a
 \`[`Content-Security-Policy`](https://w3c.github.io/webappsec-csp/#header-content-security-policy)\` header in the response that contains a
 policy which is at least as strong as the required policy, or
 explicitly opt-in by sending an
 \`[`Allow-CSP-From`](#http-headerdef-allow-csp-from)\` header in the response that enables the
 embedding origin to set whatever policy it wishes. The explicit
 mechanism is straightforward, described in [§ 2.3 The Allow-CSP-From
 HTTP Response Header](#allow-csp-from-header). The implicit
 mechanism is quite complicated, and comprises the entire [§ 3
 Implicit Policy Acceptance](#implicit-opt-in) section.

 If the server doesn't wish to accept the required policy, it can
 return an explicit error, or simply return the usual data without
 either a matching
 \`[`Content-Security-Policy`](https://w3c.github.io/webappsec-csp/#header-content-security-policy)\` header or an
 \`[`Allow-CSP-From`](#http-headerdef-allow-csp-from)\` header. In this case, the user agent will
 block the response. This integration with HTML's
 [navigate](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate) algorithm is described in [§ 2.4 Integration with
 HTML](#html-integration), and the blocking mechanism is spelled out
 in [§ 4.1 Is response to request blocked by
 requiredCSP?](#process-response).

### 2.1. `<iframe>`'s `csp` attribute

[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) elements have a [`csp`]
attribute, which specifies the policy that an embedded document must
agree to enforce upon itself. For example, the following HTML would load
`https://embedee.example.com/`, and ensure that `object-src 'none'` was
enforced upon it:

<iframe src="https://embedee.example.com/" csp="object-src 'none'">
 </iframe>

A [string](https://infra.spec.whatwg.org/#string) (`value`) is a [valid attribute
value] for a given
[element](https://dom.spec.whatwg.org/#concept-element) (`element`)\'s
[`csp`](#element-attrdef-iframe-csp)
[attribute](https://dom.spec.whatwg.org/#concept-attribute) if all of the following statements are true:

1. `value` is not the empty string.

2. `value`'s
 [length](https://infra.spec.whatwg.org/#string-length) is less than or equal to 4096.

 We enforce a maximum length on the
 [`csp`](#element-attrdef-iframe-csp) attribute's value to protect servers from
 potentially confusing input. See [§ 5.4 Header
 Length](#header-length) below.

3. `value` matches the
 [serialized-policy](https://w3c.github.io/webappsec-csp/#grammardef-serialized-policy) ABNF grammar defined in
 [\[CSP\]](#biblio-csp "Content Security Policy Level 3").

4. One of the following statements is true:

 1. `element`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s [policy
 container](https://fetch.spec.whatwg.org/#concept-request-policy-container)'s [required
 CSP](#policy-container-required-csp) is `null`.

 2. The result of
 [parsing](https://w3c.github.io/webappsec-csp/#abstract-opdef-parse-a-serialized-csp) `value` as \"`enforce`\" is
 [subsumed by] `element`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s [policy
 container](https://fetch.spec.whatwg.org/#concept-request-policy-container)'s [required
 CSP](#policy-container-required-csp).

5. The result of
 [parsing](https://w3c.github.io/webappsec-csp/#abstract-opdef-parse-a-serialized-csp) `value` as \"`enforce`\" has a
 [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set) that does not
 [contain](https://infra.spec.whatwg.org/#list-contain) any of the following directives:

 - [report-uri](https://w3c.github.io/webappsec-csp/#report-uri)

 - [report-to](https://w3c.github.io/webappsec-csp/#report-to)

The following strings are valid values
for the
[`csp`](#element-attrdef-iframe-csp) attribute, as they're valid CSP grammar:

- `script-src 'none'`

- `script-src 'self'; object-src 'none'; sandbox`

- `not-a-directive https://whatever.not-a-tld`

 We consider the last item valid even though it doesn't
express a meaningful policy in order to remain forward-compatible with
future CSP syntax.

The following, on the other hand, do not match the CSP syntax, and would
not be considered valid attribute values:

- `script-src *\nInjected-Header: XSS!`

- `💩`

 We need to be careful about the values we allow in the
[`csp`](#element-attrdef-iframe-csp) attribute, as its contents will end up
reflected as an HTTP request header. This concern is discussed in a
little more detail in (#header-injection).

[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)'s
[`csp`](#element-attrdef-iframe-csp)
[attribute](https://dom.spec.whatwg.org/#concept-attribute) has a corresponding IDL attribute, defined by the
following WebIDL grammar
[\[WEBIDL\]](#biblio-webidl "Web IDL Standard"):

```
partial interface HTMLIFrameElement {
 [CEReactions] attribute DOMString csp;
};
```

The
[`csp`](#dom-htmliframeelement-csp) IDL attribute must
[reflect](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#reflect) the element's
[`csp`](#element-attrdef-iframe-csp)
[attribute](https://dom.spec.whatwg.org/#concept-attribute).

Upstream this to all the HTMLs.

### 2.2. The `Sec-Required-CSP` HTTP Request Header

In order to ensure that the embedded resource can decide whether or not
it is willing to adhere to the embedder's requirements, the policy
expressed in an
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)'s
[`csp`](#element-attrdef-iframe-csp) attribute is communicated along with affected
[navigation
requests](https://fetch.spec.whatwg.org/#navigation-request) via a
\"[`Sec-Required-CSP`]\" HTTP request header.
The header's value is represented by the following ABNF
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"):

 Sec-Required-CSP = serialized-policy

A user agent MUST NOT send more than one HTTP response header field
named \"`Sec-Required-CSP`\", and any such header MUST NOT contain more
than one
[serialized-policy](https://w3c.github.io/webappsec-csp/#grammardef-serialized-policy).

Servers MUST process only the first policy in the first such header
received. As discussed in (#header-reflection), servers SHOULD also
carefully consider the implications of simply reflecting a policy back
to a client. If the server wishes to simply accept an embedder's
requirements, the
\`[`Allow-CSP-From`](#http-headerdef-allow-csp-from)\` header is a safer choice.

This header is set as part of HTML's
[navigate](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate) algorithm (see [§ 2.4 Integration with
HTML](#html-integration) for details on the hook that calls the
following algorithm):

To [set the `Sec-Required-CSP`
header] for a given
[request](https://fetch.spec.whatwg.org/#concept-request) (`request`) and [serialized
CSP](https://w3c.github.io/webappsec-csp/#serialized-csp)-or-null (`requirement`), run the following
steps:

1. If `request` is not a [navigation
 request](https://fetch.spec.whatwg.org/#navigation-request), return.

2. If `requirement` is `null`, return.

3. Assert: `requirement` is a [serialized
 CSP](https://w3c.github.io/webappsec-csp/#serialized-csp), matching the
 [serialized-policy](https://w3c.github.io/webappsec-csp/#grammardef-serialized-policy) grammar defined in
 [\[CSP\]](#biblio-csp "Content Security Policy Level 3").

4. [Append](https://fetch.spec.whatwg.org/#concept-header-list-append) a header named
 \"\`[`Sec-Required-CSP`](#http-headerdef-sec-required-csp)\`\" with a value of
 `requirement` to `request`'s [header
 list](https://fetch.spec.whatwg.org/#concept-request-header-list).

### 2.3. The `Allow-CSP-From` HTTP Response Header

An embedee can opt-into accepting a policy specified by an embedder by
responding with a \"[`Allow-CSP-From`]\" HTTP response
header. The header's value is represented by the following ABNF
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"):

 Allow-CSP-From = origin-or-null / wildcard

### 2.4. Integration with HTML

1. [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) elements have a
 [`csp`](#element-attrdef-iframe-csp) attribute, defined in [§ 2.1 \<iframe\>'s
 csp attribute](#csp-attribute).

2. Add a [required CSP]
 item to the [policy
 container](https://fetch.spec.whatwg.org/#concept-request-policy-container)
 [struct](https://infra.spec.whatwg.org/#struct), which is a [serialized
 CSP](https://w3c.github.io/webappsec-csp/#serialized-csp) or null, and is initially null.

3. Add a [required CSP] item to the [target snapshot
 params](https://html.spec.whatwg.org/multipage/browsing-the-web.html#target-snapshot-params)
 [struct](https://infra.spec.whatwg.org/#struct), which is a [serialized
 CSP](https://w3c.github.io/webappsec-csp/#serialized-csp) or null.

4. Update HTML's [snapshotting target snapshot
 params](https://html.spec.whatwg.org/multipage/browsing-the-web.html#snapshotting-target-snapshot-params) algorithm to set the new [required
 CSP](#target-snapshot-params-required-csp) item to the result of [determine the required
 CSP](#abstract-opdef-determine-the-required-csp) given `targetNavigable`.

5. Add a [required CSP]
 item to the [navigation
 params](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigation-params)
 [struct](https://infra.spec.whatwg.org/#struct), which is a [serialized
 CSP](https://w3c.github.io/webappsec-csp/#serialized-csp) or null.

6. Update the
 [navigate](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate) algorithm to set the [required
 CSP](#navigation-params-required-csp) of the [navigation
 params](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigation-params)
 [struct](https://infra.spec.whatwg.org/#struct) created in step 18.7.7 to
 `targetSnapshotParams`'s [required
 CSP](#target-snapshot-params-required-csp).

7. Add the following step to HTML's [create navigation params by
 fetching](https://html.spec.whatwg.org/multipage/browsing-the-web.html#create-navigation-params-by-fetching) algorithm, after `request` is created:

 1. [set the Sec-Required-CSP
 header](#abstract-opdef-set-the-sec-required-csp-header) for `request` and
 `targetSnapshotParams`'s [required
 CSP](#target-snapshot-params-required-csp).

8. Update [create navigation params by
 fetching](https://html.spec.whatwg.org/multipage/browsing-the-web.html#create-navigation-params-by-fetching) to set the [required
 CSP](#navigation-params-required-csp) of the returned [navigation
 params](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigation-params) to `targetSnapshotParams`'s [required
 CSP](#target-snapshot-params-required-csp).

9. Update [create navigation params from a srcdoc
 resource](https://html.spec.whatwg.org/multipage/browsing-the-web.html#create-navigation-params-from-a-srcdoc-resource) to set the [required
 CSP](#navigation-params-required-csp) of the returned [navigation
 params](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigation-params) to `targetSnapshotParams`'s [required
 CSP](#target-snapshot-params-required-csp).

10. Add an optional `requiredCSP` (a [serialized
 CSP](https://w3c.github.io/webappsec-csp/#serialized-csp) or null, defaulting to null) as an argument to
 HTML's [creating a policy container from a fetch
 response](https://html.spec.whatwg.org/multipage/browsers.html#creating-a-policy-container-from-a-fetch-response) algorithm, and add the following steps:

 1. If `requiredCSP` is not null:

 1. Let `required policy` be the result of
 [parsing](https://w3c.github.io/webappsec-csp/#parse-serialized-csp) `requiredCSP` as \"`enforce`\".

 2. Let `response policies` be the result of
 [parsing](https://w3c.github.io/webappsec-csp/#abstract-opdef-parse-a-responses-content-security-policies) `response`'s Content
 Security Policies.

 3. If [§ 3.2.1 CSP List Subsumption](#subsume-csp-list) returns
 \"`Does Not Subsume`\" when executed upon
 `required policy`, `response`'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url)'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin), `response policies`, and
 `response`'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url)'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin):

 1. [Append](https://infra.spec.whatwg.org/#list-append) `required policy` to
 `result`'s [CSP
 list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list).

 If the response's policies already subsume
 the required policy, we do not append the required policy to
 the policy container. This ensures that if an embedder
 requires a specific nonce (e.g. `nonce-abc`), and the
 embedee provides its own compatible nonce (e.g.
 `nonce-xyz`), the user agent only enforces the embedee's
 nonce. If we were to append both, the document would
 effectively block all scripts, as no script could satisfy
 both nonces simultaneously.

 4. Set `result`'s [required
 CSP](#policy-container-required-csp) to `requiredCSP`.

11. Update [create navigation params by
 fetching](https://html.spec.whatwg.org/multipage/browsing-the-web.html#create-navigation-params-by-fetching) to pass `targetSnapshotParams`'s
 [required
 CSP](#target-snapshot-params-required-csp) to [creating a policy container from a fetch
 response](https://html.spec.whatwg.org/multipage/browsers.html#creating-a-policy-container-from-a-fetch-response).

12. Add the following to the list of conditions in HTML's
 [navigate](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate) algorithm that cause the navigation to be blocked
 (e.g. after the `X-Frame-Options` check):

 - The [§ 4.1 Is response to request blocked by
 requiredCSP?](#process-response) algorithm returns \"`Blocked`\"
 when executed upon `navigationParams`'s
 [response](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigation-params-response), `navigationParams`'s
 [request](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigation-params-request), and `navigationParams`'s [required
 CSP](#navigation-params-required-csp).

#### 2.4.1. Required CSP

To [determine the required
CSP] for a given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable) (`navigable`), run the following steps:

1. If `navigable` is not a [child
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable), return `null`.

2. If `navigable`'s
 [container](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-container) has an
 [`csp`](#element-attrdef-iframe-csp)
 [attribute](https://dom.spec.whatwg.org/#concept-attribute) with a [valid attribute
 value](#iframe-csp-valid-attribute-value) (`value`), return `value`.

3. Return `navigable`'s [container
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-container-document)'s [policy
 container](https://fetch.spec.whatwg.org/#concept-request-policy-container)'s [required
 CSP](#policy-container-required-csp).

Upstream this.

## 3. Implicit Policy Acceptance

An embedee can explicitly accept a policy requirement specified by its
embedder by returning an
\`[`Allow-CSP-From`](#http-headerdef-allow-csp-from)\` header along with a response. The requirement
can also be implicitly accepted by delivering a
\`[`Content-Security-Policy`](https://w3c.github.io/webappsec-csp/#header-content-security-policy)\` header that contains a policy (or set of
policies) whose net effect is at least as strict as the policy required
by the embedder.

\"At least as strict\", however, isn't very precise. Simple cases are
straightforward: if an embedder requires
`object-src https://cdn.example.com`, the embedee can respond with
`object-src 'none'`. Since every possible resource that would be blocked
by the former would also be blocked by the latter (because it allows no
objects at all), we wouldn't block the embedding. CSP's syntactical
complexity makes this a little bit difficult to reason about for more
complicated cases. For instance, given
`script-src 'unsafe-inline' http: 'sha256-abc...def'`, it might appear
that `script-src 'unsafe-inline'` would be a subset of the required
policy. The presence of the
[hash-source](https://w3c.github.io/webappsec-csp/#grammardef-hash-source) expression, however means that `'unsafe-inline'` is
ignored in the required policy, so the latter policy would actually
allow more than the former, despite appearances.

Here, we'll refer to the \"at least as strict\" concept as
\"subsumption\". One [content security policy
object](https://w3c.github.io/webappsec-csp/#content-security-policy-object) (`A`) is said to
[subsume] another (`B`) if everything allowed
by `B` is also allowed by `A`. In this case,
`A`
[subsumes](#content-security-policy-object-subsume) `B`, or `B` is [subsumed
by](#content-security-policy-object-subsume) `A`.

We're not always comparing single policies, though. When multiple
policies are present in a [CSP
list](https://w3c.github.io/webappsec-csp/#csp-list), they have a combined effect which is described in
[\"The effect of multiple
policies\"](https://w3c.github.io/webappsec-csp/#multiple-policies).
Here, we'll talk about the combined effect of a [CSP
list](https://w3c.github.io/webappsec-csp/#csp-list) as their
[intersection](#csp-list-intersection). Details are spelled out in [§ 3.1
Intersection](#intersection) below.

With
[intersection](#csp-list-intersection) defined, we can say that `A`
[subsumes](#content-security-policy-object-subsume) a [CSP
list](https://w3c.github.io/webappsec-csp/#csp-list) iff `A`
[subsumes](#content-security-policy-object-subsume) that list's
[intersection](#csp-list-intersection).

### 3.1. Intersection

#### 3.1.1. CSP List intersection

The [intersection] of a [CSP
list](https://w3c.github.io/webappsec-csp/#csp-list) (`list`) for an
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) (`origin`) is a single [Content Security
Policy
object](https://w3c.github.io/webappsec-csp/#content-security-policy-object) representing their net effect, produced by the
following algorithm:

 It isn't always possible to represent the
[intersection](#csp-list-intersection) of multiple policies as a single policy. Consider
`script-src 'unsafe-inline'` and `script-src 'nonce-abc'`, for instance:
the former allows only inline script, the latter allows only inline or
externalized script with a particular token. The net effect (only inline
script with a particular token) cannot be created with a single policy.
Dealing with such policies is, for the moment, left as an exercise for
the reader.

We shouldn't make the reader do this
exercise. We should also provide guidance on how to handle intersections
that aren't representable as a single policy (e.g. by maintaining a list
of policies).

1. Let `result` be a [content security policy
 object](https://w3c.github.io/webappsec-csp/#content-security-policy-object) with an empty [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set), and a
 [disposition](https://w3c.github.io/webappsec-csp/#content-security-policy-object-disposition) of \"`enforce`\".

2. For each `policy` in `list`:

 1. If `policy`'s
 [disposition](https://w3c.github.io/webappsec-csp/#content-security-policy-object-disposition) is \"`report`\",
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. Set `result` to the
 [intersection](#content-security-policy-object-intersection) of `result` and `policy`
 for `origin`.

3. Return `result`.

The intersection of the policies
created by parsing each item in the following list of [serialized
CSPs](https://w3c.github.io/webappsec-csp/#serialized-csp):

 «
 "default-src 'self' http://example.com http://example.net; connect-src 'none';",
 "connect-src http://example.com/; script-src http://example.com/",
 "style-src 'self'; script-src http://example.com/ http://example.net",
 »

is the policy created by parsing the following [serialized
CSP](https://w3c.github.io/webappsec-csp/#serialized-csp):

 "default-src 'self' http://example.com http://example.net; connect-src 'none'; script-src http://example.com/; style-src 'self'"

Each policy specified in the initial list
[subsumes](#content-security-policy-object-subsume) the intersection.

#### 3.1.2. Policy Intersection

The [intersection] of two [Content Security Policy
objects](https://w3c.github.io/webappsec-csp/#content-security-policy-object) (`A` and `B`) for an
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) (`origin`) is a single [Content Security
Policy
object](https://w3c.github.io/webappsec-csp/#content-security-policy-object) representing their combined effect, produced by the
following algorithm:

1. Assert: `A` and `B` both have a
 [disposition](https://w3c.github.io/webappsec-csp/#content-security-policy-object-disposition) of \"`enforce`\".

2. If `A`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set) [is
 empty](https://infra.spec.whatwg.org/#list-is-empty), return `B`.

3. If `B`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set) [is
 empty](https://infra.spec.whatwg.org/#list-is-empty), return `A`.

4. Let `policy` be a new [content security policy
 object](https://w3c.github.io/webappsec-csp/#content-security-policy-object) with an empty [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set), and a
 [disposition](https://w3c.github.io/webappsec-csp/#content-security-policy-object-disposition) \"`enforce`\".

5. Let `directive names` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

6. For each `directive` in `A`:

 1. [Append](https://infra.spec.whatwg.org/#set-append) `directive`'s
 [name](https://w3c.github.io/webappsec-csp/#directive-name) to `directive names`.

7. For each `directive` in `B`:

 1. [Append](https://infra.spec.whatwg.org/#set-append) `directive`'s
 [name](https://w3c.github.io/webappsec-csp/#directive-name) to `directive names`.

8. For each `directive name` in
 `directive names`:

 1. If `directive name` is \"`report-uri`\",
 \"`report-to`\",
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. Let `directive A` be the [effective directive
 value](#effective-directive-value) for `directive name` and
 `A`.

 3. Let `directive B` be the [effective directive
 value](#effective-directive-value) for `directive name` and
 `B`.

 4. Assert: `directive A` and `directive B`
 are not both `null`, and either both of their
 [values](https://w3c.github.io/webappsec-csp/#directive-value) are [source
 lists](https://w3c.github.io/webappsec-csp/#source-lists), or neither of their
 [values](https://w3c.github.io/webappsec-csp/#directive-value) are [source
 lists](https://w3c.github.io/webappsec-csp/#source-lists).

 5. If either `directive A` or `directive B`
 has a
 [value](https://w3c.github.io/webappsec-csp/#directive-value) which is not a [source
 list](https://w3c.github.io/webappsec-csp/#source-lists),
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 (#issue-5b9d5f29) We need to extend this
 definition to handle things that are not source lists. Also, we
 should be more precise about this, perhaps by defining a term
 like \"source list directive\" that we could check against
 `directive name`.

 6. If `directive A` is `null`:

 1. Let `directive` be a new
 [directive](https://w3c.github.io/webappsec-csp/#directives) with the following properties:

 [name](https://w3c.github.io/webappsec-csp/#directive-name)

 : `directive name`

 [value](https://w3c.github.io/webappsec-csp/#directive-value)

 : `directive B`'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value)

 2. [append](https://infra.spec.whatwg.org/#set-append) a `directive` to
 `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set).

 3. [Continue](https://infra.spec.whatwg.org/#iteration-continue).

 7. If `directive B` is `null`:

 1. Let `directive` be a new
 [directive](https://w3c.github.io/webappsec-csp/#directives) with the following properties:

 [name](https://w3c.github.io/webappsec-csp/#directive-name)

 : `directive name`

 [value](https://w3c.github.io/webappsec-csp/#directive-value)

 : `directive A`'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value)

 2. [append](https://infra.spec.whatwg.org/#set-append) a `directive` to
 `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set).

 3. [Continue](https://infra.spec.whatwg.org/#iteration-continue).

 8. Let `directive value` be the
 [intersection](#source-list-intersection) of `directive A`'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value), `directive B`'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value), `directive name`, and
 `origin`.

 9. Let `directive` be a new
 [directive](https://w3c.github.io/webappsec-csp/#directives) with he following properties:

 [name](https://w3c.github.io/webappsec-csp/#directive-name)

 : `directive name`

 [value](https://w3c.github.io/webappsec-csp/#directive-value)

 : `directive value`

 10. [Append](https://infra.spec.whatwg.org/#set-append) `directive` to `policy`'s
 [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set).

9. Return `policy`.

The intersection of the policies
obtained by parsing the following [serialized
CSPs](https://w3c.github.io/webappsec-csp/#serialized-csp):

 "default-src 'self' http://example.com http://example.net; connect-src 'none';"

 and

 "connect-src http://example.com/; script-src http://example.com/"

is the policy obtained by parsing the following [serialized
CSP](https://w3c.github.io/webappsec-csp/#serialized-csp):

 "default-src 'self' http://example.com http://example.net; connect-src 'none'; script-src http://example.com/;"

Both of the given policies
[subsume](#content-security-policy-object-subsume) the
[intersection](#csp-list-intersection). For example, the
[intersection](#csp-list-intersection)'s \"`script-src http://example.com/`\" is [subsumed
by](#content-security-policy-object-subsume) the first policy's
\"`default-src 'self' http://example.com http://example.net`\" and the
second policy's \"`script-src http://example.com/`\".

#### 3.1.3. Source List Intersection

The [intersection] of two [source
lists](https://w3c.github.io/webappsec-csp/#source-lists) for a [directive
name](https://w3c.github.io/webappsec-csp/#directive-name) (`name`) and an
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) (`origin`) is a [source
list](https://w3c.github.io/webappsec-csp/#source-lists) representing their net effect. If no such [source
list](https://w3c.github.io/webappsec-csp/#source-lists) exists (for example, `https://example.com/` in
`A` and `https://not-example.com` in `B`), then
the intersection will be the list «
[\'none\'](https://w3c.github.io/webappsec-csp/#grammardef-none) ».

1. Let `effective A` be the [effective source
 list](#effective-source-list) for `A`, `name`, and
 `origin`.

2. Let `effective B` be the [effective source
 list](#effective-source-list) for `B`, `name`, and
 `origin`.

3. If either `effective A` or `effective B` is «
 [`'none'`](https://w3c.github.io/webappsec-csp/#grammardef-none) », return «
 [`'none'`](https://w3c.github.io/webappsec-csp/#grammardef-none) ».

4. If `effective A` is empty, return
 `effective B`.

5. If `effective B` is empty, return
 `effective A`.

6. Let `schemes` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

7. Let `intersection` be an empty [source
 list](https://w3c.github.io/webappsec-csp/#source-lists).

8. For each `expression B` in `effective B`:

 1. If `expression B` matches the
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) grammar and `expression B` is
 [contained](https://infra.spec.whatwg.org/#list-contain) in `effective A`, then
 [append](https://infra.spec.whatwg.org/#set-append) `expression B` to
 `schemes`.

 Getting the [effective source
 list](#effective-source-list) above means that tokens matching the
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) grammar have already been normalized such
 that \"`http:`\"/\"`ws:`\" never appears without
 \"`https:`\"/\"`ws:`\" also appearing.

9. For each `expression` in `schemes`:

 1. If `expression` does not match \"`https:`\" or
 `schemes` does not
 [contain](https://infra.spec.whatwg.org/#list-contain) \"`http:`\":

 1. If `expression` does not match \"`wss:`\" or
 `schemes` does not
 [contain](https://infra.spec.whatwg.org/#list-contain) \"`ws:`\",
 [append](https://infra.spec.whatwg.org/#set-append) `expression` to
 `intersection`.

10. For each `expression A` in `effective A`:

 1. If `expression A` matches
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) grammar and `schemes`
 [contains](https://infra.spec.whatwg.org/#list-contain) `expression A`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. For each `expression B` in `effective B`:

 1. If at least one of `expression A` and
 `expression B` does not match
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) or
 [`host-source`](https://w3c.github.io/webappsec-csp/#grammardef-host-source) grammar:

 1. If `expression A` matches
 [`keyword-source`](https://w3c.github.io/webappsec-csp/#grammardef-keyword-source) grammar and is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for `expression B`,
 [append](https://infra.spec.whatwg.org/#set-append) `expression A` to
 `intersection`.

 2. If `expression A` matches
 [`nonce-source`](https://w3c.github.io/webappsec-csp/#grammardef-nonce-source) or
 [`hash-source`](https://w3c.github.io/webappsec-csp/#grammardef-hash-source) grammar and
 [is](https://infra.spec.whatwg.org/#string-is) `expression B`,
 [append](https://infra.spec.whatwg.org/#set-append) `expression A` to
 `intersection`.

 3. [Continue](https://infra.spec.whatwg.org/#iteration-continue) to the next `expression B`.

 2. If `expression B`'s
 [`scheme-part`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-part) matches one of the elements in
 `schemes`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue) to the next `expression B`.

 3. If the
 [intersection](#source-expression-intersection) of `expression A` and
 `expression B` is not `null`,
 [append](https://infra.spec.whatwg.org/#set-append) the result to `intersection`.

11. Return `intersection`.

In these cases, `intersection` is an
[intersection](#source-list-intersection) for `A` and `B`.

 A = wss: http://example.com
 B = https: wss: 'none'
 intersection = wss: https://example.com

The expression \"wss:\" is present in both policies, so it is present in
their intersection. Similarly, \"http://example.com\" is present in the
intersection because it is the only expression subsumed by both
\"http://example.com\" and \"https:\". Note that \"\'none\'\"\" is
ignored, as it is not the only token in `B`.

 A = http://sub.a.com http://*.b.com
 B = https://sub.a.com:* http://*.c.com
 intersection = https://sub.a.com

Only two sources are similar: \"http://sub.a.com\" in `A` is
similar to \"https://sub.a.com:\*\" in `B` so the
intersection of the two source lists is \"https://sub.a.com\".

 A = 'unsafe-inline' http://example.com:443/page1/html 'nonce-abc'
 B = 'unsafe-inline' https://example.com:443/ 'strict-dynamic' 'nonce-abc'
 intersection = 'nonce-abc'

Since \"`strict-dynamic`\" honors only
[`nonce-source`](https://w3c.github.io/webappsec-csp/#grammardef-nonce-source) and
[`hash-source`](https://w3c.github.io/webappsec-csp/#grammardef-hash-source) expressions, `B` is effectively
\"\'strict-dynamic\' \'nonce-abc\'\". That is why the intersection is
\"\'nonce-abc\'\".

#### 3.1.4. Source Expression Intersection

A [source
expression](https://w3c.github.io/webappsec-csp/#source-expression) is said to be an
[intersection] of two other
expressions matching
[`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) or
[`host-source`](https://w3c.github.io/webappsec-csp/#grammardef-host-source) grammar `A` and `B` if it
contains the more restrictive
[`scheme-part`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-part),
[`host-part`](https://w3c.github.io/webappsec-csp/#grammardef-host-part),
[`port-part`](https://w3c.github.io/webappsec-csp/#grammardef-port-part), and
[`path-part`](https://w3c.github.io/webappsec-csp/#grammardef-path-part) of the two.

In these cases, `Intersect` is an
[intersection](#source-expression-intersection) of `A` and `B`.

 A = https:
 B = http:
 Intersect = https:
 // http: allows both http: and https:, so https: is the intersection.

 A = http://*.example.com
 B = https://sub.example.com:*
 Intersect = https://sub.example.com:443
 // A does not specify a port, so only default ports are allowed.

 A = http://example.com:80/page1/html
 B = https://example.com:443/
 Intersect = null
 // A is explicitly locked to port 80, which cannot match B's equally explicit port 443.

 A = https:
 B = http://example.com
 Intersect = https://example.com.

 A = https://sub.example.com:*
 B = http://*.example.com/page.html
 Intersect = https://sub.example.com/page.html

##### 3.1.4.1. `scheme-source` and `host-source` intersections

Given two [source
expressions](https://w3c.github.io/webappsec-csp/#source-expression) matching the
[`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) or
[`host-source`](https://w3c.github.io/webappsec-csp/#grammardef-host-source) grammar (`A` and `B`), return
their[intersection](#source-expression-intersection) if `A` is [source-expression
similar](#source-expression-similar) to `B`. Otherwise, return `null`.

1. If `A` is not [source-expression
 similar](#source-expression-similar) to `B`, return `null`.

2. Let `source` be an empty string.

3. Let `scheme A` be `A`'s
 [`scheme-part`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-part), if present, and `null` otherwise.

4. Let `scheme B` be `B`'s
 [`scheme-part`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-part), if present, and `null` otherwise.

5. Let `more secure scheme B` be `true` if
 `scheme A` does not [`scheme-part`
 match](https://w3c.github.io/webappsec-csp/#scheme-part-match) `scheme B`, and `false` otherwise.

6. Append `scheme A` and \":\" to `source` if
 `scheme A` is not `null` and
 `more secure scheme B` is `false`. Otherwise, append
 `scheme B` and \":\" to `source` if
 `scheme B` is not `null`.

7. If both `A` and `B` match the
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) grammar, return `source`.

8. Append \"//\" to `source` if it is not empty.

9. Let `host A` be `A`'s
 [`host-part`](https://w3c.github.io/webappsec-csp/#grammardef-host-part), if present, and `null` otherwise.

10. Let `host B` be `B`'s
 [`host-part`](https://w3c.github.io/webappsec-csp/#grammardef-host-part), if present, and `null` otherwise.

11. If `host A` is not `null`:

 1. If `host B` is `null`, append `host A` to
 `source`. Continue to the next step in the main
 algorithm.

 2. If `A` doesn't match the
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) grammar and doesn't have a [wildcard
 host](#source-expression-wildcard-host), append `host A` to
 `source`.

 3. Otherwise, append `host B` to `source`.

12. If `host A` is `null`, append `host B` to
 `source`.

13. Let `port A` be `A`'s
 [`port-part`](https://w3c.github.io/webappsec-csp/#grammardef-port-part), if present, and `null` otherwise.

14. Let `port B` be `B`'s
 [`port-part`](https://w3c.github.io/webappsec-csp/#grammardef-port-part), if present, and `null` otherwise.

15. If `port A` is `null`, append \":\" and
 `port B` to `source` if it is not `null`.

16. If `port A` is not `null`:

 1. If `port B` is `null`, append \":\" and
 `port A` to `source`. Continue to the next
 step in the main algorithm.

 2. If `A` doesn't have a [wildcard
 port](#source-expression-wildcard-port) and `more secure scheme B` is
 `false`, append \":\" and `port A` to
 `source`.

 3. Otherwise, append \":\" and `port B` to
 `source`.

17. Let `path A` be `A`'s
 [`path-part`](https://w3c.github.io/webappsec-csp/#grammardef-path-part), if present, and `null` otherwise.

18. Let `path B` be `B`'s
 [`path-part`](https://w3c.github.io/webappsec-csp/#grammardef-path-part), if present, and `null` otherwise.

19. If `path A` is `null`, append `path B` to
 `source` if it is not `null`.

20. If `path A` is not `null`:

 1. If `path B` is `null`, return the result of appending
 `path A` to `source`.

 2. If `path A` [`path-part`
 matches](https://w3c.github.io/webappsec-csp/#path-part-match) `path B`, append `path A`
 to `source`.

 3. Otherwise, append `path B` to `source`.

21. Return `source`.

#### 3.1.5. Intersection Helpers

##### 3.1.5.1. Effective Directive Value

Given a [string](https://infra.spec.whatwg.org/#string) (`name`) and a [content security policy
object](https://w3c.github.io/webappsec-csp/#content-security-policy-object) (`policy`), the [effective directive value
for `name` and
`policy`] is the
[value](https://w3c.github.io/webappsec-csp/#directive-value) resulting from running the following steps:

1. Switch on `name` and execute the associated steps:

 \"`child-src`\"\
 \"`connect-src`\"\
 \"`font-src`\"\
 \"`img-src`\"\
 \"`manifest-src`\"\
 \"`media-src`\"\
 \"`object-src`\"\
 \"`script-src`\"\
 \"`style-src`\"

 : 1. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is `name`, return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 2. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is \"`default-src`\", return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 3. Return `null`.

 \"`script-src-elem`\"\
 \"`script-src-attr`\"

 : 1. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is `name`, return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 2. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is \"`script-src`\", return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 3. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is \"`default-src`\", return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 4. Return `null`.

 \"`style-src-elem`\"\
 \"`style-src-attr`\"

 : 1. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is `name`, return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 2. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is \"`style-src`\", return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 3. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is \"`default-src`\", return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 4. Return `null`.

 \"`frame-src`\"

 : 1. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is `name`, return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 2. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is \"`child-src`\", return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 3. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is \"`default-src`\", return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 4. Return `null`.

 \"`worker-src`\"

 : 1. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is `name`, return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 2. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is \"`child-src`\", return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 3. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is \"`script-src`\", return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 4. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is \"`default-src`\", return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 5. Return `null`.

 \"`base-uri`\"\
 \"`block-all-mixed-content`\"\
 \"`default-src`\"\
 \"`frame-ancestors`\"\
 \"`form-action`\"\
 \"`plugin-types`\"\
 \"`report-uri`\"\
 \"`require-sri-for`\"\
 \"`sandbox`\"\
 \"`upgrade-insecure-requests`\"

 : 1. If `policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [directive](https://w3c.github.io/webappsec-csp/#directives) whose
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is `name`, return that
 [directive](https://w3c.github.io/webappsec-csp/#directives)'s
 [value](https://w3c.github.io/webappsec-csp/#directive-value).

 2. Return `null`.

2. Return `null`.

##### 3.1.5.2. Effective Source List

Given a [source
list](https://w3c.github.io/webappsec-csp/#source-lists) (`list`), a
[string](https://infra.spec.whatwg.org/#string) (`name`), and an
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) (`origin`), the [effective source list for
`list`, `name`, and
`origin`] is a
simplification of `list` that expands complex tokens like
[`'self'`](https://w3c.github.io/webappsec-csp/#grammardef-self) and
[`*`](https://drafts.csswg.org/css-values-4/#mult-zero-plus), and removes ineffective, obviated, or invalid
tokens (for instance,
[`'unsafe-inline'`](https://w3c.github.io/webappsec-csp/#grammardef-unsafe-inline) in the presence of a nonce). The result of running
the following steps will generally be more verbose than
`list`, but will be significantly simpler to compare:

1. If `list` [is
 empty](https://infra.spec.whatwg.org/#list-is-empty) or « \'none\' », return « \'none\' ».

2. Let `result` be an empty [source
 list](https://w3c.github.io/webappsec-csp/#source-lists).

3. For each `expression` in `list`:

 1. If `expression` is
 \"[`'self'`](https://w3c.github.io/webappsec-csp/#grammardef-self)\":

 1. [Append](https://infra.spec.whatwg.org/#set-append) the result of executing [§ 4.2.1 Rewrite
 \'self\' into a host-source expression for
 origin.](#rewrite-self) given `origin` to
 `result`.

 2. [Continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. If `expression` matches the
 [`keyword-source`](https://w3c.github.io/webappsec-csp/#grammardef-keyword-source) grammar, and `name` is not
 \"`script-src`\" or \"`style-src`\",
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. [Continue](https://infra.spec.whatwg.org/#iteration-continue) if any of the following statements are true:

 - `expression` is
 \"[`'none'`](https://w3c.github.io/webappsec-csp/#grammardef-none)\"

 - `expression` is
 \"[`'strict-dynamic'`](https://w3c.github.io/webappsec-csp/#grammardef-strict-dynamic)\" and `name` is not
 \"`script-src`\"

 - `expression` matches either the
 [`nonce-source`](https://w3c.github.io/webappsec-csp/#grammardef-nonce-source) or
 [`hash-source`](https://w3c.github.io/webappsec-csp/#grammardef-hash-source) grammar, and `name` is not
 \"`script-src`\" or \"`style-src`\"

 - `expression` is
 \"[`'unsafe-inline'`](https://w3c.github.io/webappsec-csp/#grammardef-unsafe-inline)\", `name` is \"`script-src`,
 and `list`
 [contains](https://infra.spec.whatwg.org/#list-contain) one or more tokens that match one of the
 [`nonce-source`](https://w3c.github.io/webappsec-csp/#grammardef-nonce-source) grammar, the
 [`hash-source`](https://w3c.github.io/webappsec-csp/#grammardef-hash-source) grammar, or
 \"[`'strict-dynamic'`](https://w3c.github.io/webappsec-csp/#grammardef-strict-dynamic)\"

 - `expression` matches either the
 [`host-source`](https://w3c.github.io/webappsec-csp/#grammardef-host-source) or
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) grammar, `name` is
 \"`script-src`\", amd `list`
 [contains](https://infra.spec.whatwg.org/#list-contain) the token
 \"[`'strict-dynamic'`](https://w3c.github.io/webappsec-csp/#grammardef-strict-dynamic)\"

 - `name` is \"`plugin-types`\", and
 `expression` does not match the
 [`serialized-source-list`](https://w3c.github.io/webappsec-csp/#grammardef-serialized-source-list) grammar

 4. If `expression` is the U+002A ASTERISK character
 (`*`):

 1. For each `scheme` in « \"`ftp:`\", \"`http:`\",
 \"`https:`\", \"`ws:`\", \"`wss:`\" »:

 1. Append `scheme` to `result`.

 2. Append the concatenation of `origin`'s
 [scheme](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-scheme) and \"`:`\" to `result`.

 3. [Continue](https://infra.spec.whatwg.org/#iteration-continue).

 5. If `expression` matches the
 [scheme-source](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) grammar:

 1. If `expression` is \"`http:`\",
 [append](https://infra.spec.whatwg.org/#set-append) \"`https:`\" to `result`.

 2. If `expression` is \"`ws:`\",
 [append](https://infra.spec.whatwg.org/#set-append) \"`wss:`\" to `result`.

 6. If `expression` matches the
 [host-source](https://w3c.github.io/webappsec-csp/#grammardef-host-source) grammar:

 1. If `expression`'s
 [scheme-part](https://w3c.github.io/webappsec-csp/#grammardef-scheme-part) is \"http\", append the result of
 concatenating \"https://\", `expression`'s
 [host-part](https://w3c.github.io/webappsec-csp/#grammardef-host-part), `expression`'s
 [port-part](https://w3c.github.io/webappsec-csp/#grammardef-port-part), and `expression`'s
 [path-part](https://w3c.github.io/webappsec-csp/#grammardef-path-part) to `result`.

 2. If `expression`'s
 [scheme-part](https://w3c.github.io/webappsec-csp/#grammardef-scheme-part) is \"ws\", append the result of
 concatenating \"wss://\", `expression`'s
 [host-part](https://w3c.github.io/webappsec-csp/#grammardef-host-part), `expression`'s
 [port-part](https://w3c.github.io/webappsec-csp/#grammardef-port-part), and `expression`'s
 [path-part](https://w3c.github.io/webappsec-csp/#grammardef-path-part) to `result`.

 7. [Append](https://infra.spec.whatwg.org/#set-append) `expression` to `result`.

4. If `result` [is
 empty](https://infra.spec.whatwg.org/#list-is-empty) or « \'strict-dynamic\' », return « \'none\' ».

5. Return `result`.

For any directive with origin `https://example.test/`:

 https: wss: 'none' 'self'

The effective source list is \"http: wss: https://example.test/\". Note
that \"\'none\'\" is not part of the effective source list because it
has no effect when it is not the only source.

For \"`style-src`\":

 http://example.com 'strict-dynamic' 'nonce-abc'

The effective source list is \"http://example.com \'nonce-abc\'\" since
\"\'strict-dynamic\'\" is ignored in non-\"`script-src`\" directives.

For \"`script-src`\":

 http://example.com 'strict-dynamic' 'nonce-abc'

The effective source list is \"\'strict-dynamic\' \'nonce-abc\'\" since
\"\'strict-dynamic\'\" in \"`script-src`\" case does not honor host and
scheme source expressions.

##### 3.1.5.3. Source Expression Similarity

A [source
expression](https://w3c.github.io/webappsec-csp/#source-expression) (`A`) is said to be [source-expression
similar] to another [source
expression](https://w3c.github.io/webappsec-csp/#source-expression) (`B`) if the `A`
[is](https://infra.spec.whatwg.org/#string-is) `B`, or if the relevant parts of their
grammar match (for example, in the case of
[`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) expressions, the respective
[`scheme-part`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-part)s must [`scheme-part`
match](https://w3c.github.io/webappsec-csp/#scheme-part-match) in one direction or the other.

 This property is symmetric. That is if `A`
is [source-expression
similar](#source-expression-similar) to `B`, then `B` will be
[source-expression
similar](#source-expression-similar) to `A`.

A [source
expression](https://w3c.github.io/webappsec-csp/#source-expression) has a [wildcard host] if the first character of the [source
expression](https://w3c.github.io/webappsec-csp/#source-expression)'s
[`host-part`](https://w3c.github.io/webappsec-csp/#grammardef-host-part) is an U+002A ASTERISK character (`*`).

A [source
expression](https://w3c.github.io/webappsec-csp/#source-expression) has a [wildcard port] if the
[`port-part`](https://w3c.github.io/webappsec-csp/#grammardef-port-part) of the [source
expression](https://w3c.github.io/webappsec-csp/#source-expression) is an U+002A ASTERISK character (`*`).

1. If `A`'s grammar does not match `B`'s grammar,
 return \"`Not Similar`\".

2. If `A` matches the
 [`keyword-source`](https://w3c.github.io/webappsec-csp/#grammardef-keyword-source),
 [`nonce-source`](https://w3c.github.io/webappsec-csp/#grammardef-nonce-source), or
 [`hash-source`](https://w3c.github.io/webappsec-csp/#grammardef-hash-source) grammar:

 1. If `A`
 [is](https://infra.spec.whatwg.org/#string-is) `B`, return \"`Similar`\".

 2. Return \"`Not Similar`\".

3. Let `scheme A` be `A`'s
 [`scheme-part`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-part), if present, and `null` otherwise.

4. Let `scheme B` be `B`'s
 [`scheme-part`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-part), if present, and `null` otherwise.

5. If the `scheme A` does not [scheme-part
 match](https://w3c.github.io/webappsec-csp/#scheme-part-match) `scheme B`, and `scheme B`
 does not [scheme-part
 match](https://w3c.github.io/webappsec-csp/#scheme-part-match) `scheme A`, return \"`Not Similar`\".

6. If `A` or `B` matches
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) grammar, return \"`Similar`\".

7. Let `host A` be `A`'s
 [`host-part`](https://w3c.github.io/webappsec-csp/#grammardef-host-part), if present, and `null` otherwise.

8. Let `host B` be `B`'s
 [`host-part`](https://w3c.github.io/webappsec-csp/#grammardef-host-part), if present, and `null` otherwise.

9. Let `port A` be `A`'s
 [`port-part`](https://w3c.github.io/webappsec-csp/#grammardef-port-part), if present, and `null` otherwise.

10. Let `port B` be `B`'s
 [`port-part`](https://w3c.github.io/webappsec-csp/#grammardef-port-part), if present, and `null` otherwise.

11. Let `path A` be `A`'s
 [`path-part`](https://w3c.github.io/webappsec-csp/#grammardef-path-part), if present, and `null` otherwise.

12. Let `path B` be `B`'s
 [`path-part`](https://w3c.github.io/webappsec-csp/#grammardef-path-part), if present, and `null` otherwise.

13. Return \"`Not Similar`\" if any of the following is true:

 1. Both `A` and `B` have a [wildcard
 host](#source-expression-wildcard-host), but `host A` is not an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match to `host B`.

 2. At most one of `A` and `B` has a [wildcard
 host](#source-expression-wildcard-host), `host A` does not [`host-part`
 match](https://w3c.github.io/webappsec-csp/#host-part-match) `host B`, and `host B`
 does not [`host-part`
 match](https://w3c.github.io/webappsec-csp/#host-part-match) `host A`.

 3. Neither `A` nor `B` has a [wildcard
 port](#source-expression-wildcard-port), `port A` does not [`port-part`
 match](https://w3c.github.io/webappsec-csp/#port-part-matches) `port B`, and `port B`
 does not [`port-part`
 match](https://w3c.github.io/webappsec-csp/#port-part-matches) `port A`.

 4. `path A` does not [`path-part`
 match](https://w3c.github.io/webappsec-csp/#path-part-match) `path B`, and `path B`
 does not [`path-part`
 match](https://w3c.github.io/webappsec-csp/#path-part-match) `path A`.

14. Return \"`Similar`\".

A = 'nonce-ch4hvvbHDpv7xCSvXCs3BrNggHdTzxUA'
 B = 'nonce-ch4hvvbHDpv7xCSvXCs3BrNggHdTzxUA'

Since both `A` and `B` match the
[`nonce-source`](https://w3c.github.io/webappsec-csp/#grammardef-nonce-source) grammar and `A`
[is](https://infra.spec.whatwg.org/#string-is) `B`, `A` is similar to
`B`.

 A = https://inner.example.com/foo/
 B = http://*.example.com/foo/bar/

Since `A` has a [wildcard
host](#source-expression-wildcard-host), it matches any subdomain which in this case is
\"inner\" so that `A` is similar to `B`.

 A = http://*.example.com
 B = https://inner.example.com:*

Even though `A` and `B`'s ports are different,
`A` and `B` are similar because \"http\" matches
both \"http\" and a more secure variant \"https\".

 A = http://example.com:80/page1/html
 B = https://example.com:443/

Since `A` and `B` explicitly specify different
ports, `A` is not similar to `B`.

 A = 'sha256-abc123'
 B = 'sha512-cde456'

Even though both `A` and `B` match the
[`hash-source`](https://w3c.github.io/webappsec-csp/#grammardef-hash-source) grammar, `A` is not a match for
`B` because the hashes don't match.

 A = http://example.com:80
 B = http://example.com:334

In this case, ports of `A` and `B` do not match so
that the two sources are not similar .

 A = http://example.com/page.html
 B = http://example.com/index.html

The two sources are not similar because their paths do not match.

Move the remaining intersection
algorithms into this section.

### 3.2. Subsumption

#### 3.2.1. CSP List Subsumption

Given a [content security policy
object](https://w3c.github.io/webappsec-csp/#content-security-policy-object) `subsuming policy` with an
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) (`subsuming origin`) and a
[list](https://infra.spec.whatwg.org/#list) of [content security policy
object](https://w3c.github.io/webappsec-csp/#content-security-policy-object) objects `policy list` with an
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) (`origin`), this algorithm returns
\"`Subsumes`\" if `subsuming policy`
[subsumes](#content-security-policy-object-subsume) `policy list`, and returns
\"`Does Not Subsume`\" otherwise.

1. If `subsuming policy` is `null`, return \"`Subsumes`\".

2. If `subsuming policy`'s
 [disposition](https://w3c.github.io/webappsec-csp/#content-security-policy-object-disposition) is \"`report`\", return \"`Subsumes`\".

3. If `subsuming policy`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set) [is
 empty](https://infra.spec.whatwg.org/#list-is-empty), return \"`Subsumes`\".

4. If `policy list` is [is
 empty](https://infra.spec.whatwg.org/#list-is-empty) or `null`, return \"`Does Not Subsume`\".

5. Let `effective policy` the result of executing [§ 3.1.1
 CSP List intersection](#intersection-policy-list) given
 `policy list` and `origin`.

6. Return the result of executing [§ 3.2.2 Policy
 Subsumption](#subsume-policy) given `subsuming policy`,
 `subsuming origin`, `effective policy`, and
 `origin`.

#### 3.2.2. Policy Subsumption

Given a [content security policy
object](https://w3c.github.io/webappsec-csp/#content-security-policy-object) `A` with an
[origin](https://fetch.spec.whatwg.org/#concept-request-origin) (`origin A`) and a [content security policy
object](https://w3c.github.io/webappsec-csp/#content-security-policy-object) `B` with an
[origin](https://fetch.spec.whatwg.org/#concept-request-origin) (`origin B`), this algorithm returns
\"`Subsumes`\" if `A`
[subsumes](#content-security-policy-object-subsume) `B`, and returns \"`Does Not Subsume`\"
otherwise.

1. If `A`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set) [is
 empty](https://infra.spec.whatwg.org/#list-is-empty), return \"`Subsumes`\".

2. For each `directive A` in `A`'s [directive
 set](https://w3c.github.io/webappsec-csp/#content-security-policy-object-directive-set):

 1. Let `directive name` be `directive A`'s
 [name](https://w3c.github.io/webappsec-csp/#directive-name).

 2. If `directive name` is \"`default-src`\",
 \"`report-uri`\", \"`report-to`\",
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. Let `effective directive A` be the [effective
 directive
 value](#effective-directive-value) for `directive name` and
 `A`.

 4. Let `effective directive B` be the [effective
 directive
 value](#effective-directive-value) for `directive name` and
 `B`.

 5. If `effective directive A` is `null`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 6. If `effective directive B` is `null`, return
 \"`Does Not Subsume`\".

 7. If `directive A`'s
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is \"`frame-ancestors`\":

 1. If `effective directive B` is « \"`'none'`\" »,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. If `effective directive A` is « \"`'none'`\" »,
 return \"`Does Not Subsume`\".

 3. For each `expression B` in
 `effective directive B`:

 1. Let `found match` be `false`.

 2. For each `expression A` in
 `effective directive A`:

 1. If [§ 3.2.4 Source expression
 subsumption](#subsume-source-expressions) returns
 \"`Subsumes`\" given `expression A` and
 `expression B`, set
 `found match` to `true`. Break out of
 this inner loop.

 3. If `found match` is `false`, return
 \"`Does Not Subsume`\".

 8. If `directive A`'s
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is \"`plugin-types`\":

 1. For each `type B` in
 `effective directive B`:

 1. If `effective directive A` does not
 [contain](https://infra.spec.whatwg.org/#list-contain) `type B`, return
 \"`Does Not Subsume`\".

 9. If `directive A`'s
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is \"`sandbox`\":

 1. Let `flags A` be the result of [parsing a
 sandboxing
 directive](https://html.spec.whatwg.org/multipage/browsers.html#parse-a-sandboxing-directive) given `effective directive A`.

 2. Let `flags B` be the result of [parsing a
 sandboxing
 directive](https://html.spec.whatwg.org/multipage/browsers.html#parse-a-sandboxing-directive) given `effective directive B`.

 3. For each `flag` in `flags A`:

 1. If `flags B` does not
 [contain](https://infra.spec.whatwg.org/#list-contain) `flag`, return
 \"`Does Not Subsume`\".

 A policy \$A\$ subsumes \$B\$ if \$B\$ is more
 restrictive. For sandbox flags, this means every permission
 allowed by \$A\$ must also be allowed by \$B\$. If \$B\$ omits a
 flag that \$A\$ includes, \$B\$ is not at least as restrictive
 as \$A\$ for that specific permission.

 10. If `directive A`'s
 [name](https://w3c.github.io/webappsec-csp/#directive-name) is \"`disown-opener`\",
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 11. Otherwise:

 1. If the result of executing [§ 3.2.3 Source List
 Subsumption](#subsume-source-list) is \"`Does Not Subsume`\"
 given `effective directive A`,
 `origin A`, `directive name`,
 `effective directive B`, `origin B`,
 and `directive name`, return
 \"`Does Not Subsume`\".

3. Return \"`Subsumes`\".

#### 3.2.3. Source List Subsumption

Given a [source
list](https://w3c.github.io/webappsec-csp/#source-lists) `A` with an
[origin](https://fetch.spec.whatwg.org/#concept-request-origin) (`origin A`) and a string
(`directive A`), [source
list](https://w3c.github.io/webappsec-csp/#source-lists) `B` with an
[origin](https://fetch.spec.whatwg.org/#concept-request-origin) (`origin B`) and a string
(`directive B`), this algorithm returns \"`Subsumes`\" if
`A`
[subsumes](#content-security-policy-object-subsume) `B`, and returns \"`Does Not Subsume`\"
otherwise.

A
[directive](https://w3c.github.io/webappsec-csp/#directives) [contains] a given [source
expression](https://w3c.github.io/webappsec-csp/#source-expression) if the expression is
[contained](https://infra.spec.whatwg.org/#list-contain) by its
[value](https://w3c.github.io/webappsec-csp/#directive-value).

1. If `directive A` is not an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match to `directive B`, return
 \"`Does Not Subsume`\".

2. If `A` is empty or `B` is `none`, return
 \"`Subsumes`\".

3. If `B` is empty or `A` is `none`, return
 \"`Does Not Subsume`\".

4. If `directive B` is \"`script-src`\" and `B`
 [contains](#directive-contains) a
 [`keyword-source`](https://w3c.github.io/webappsec-csp/#grammardef-keyword-source) expression \"`strict-dynamic`\" but
 `A` does not contain it, return \"`Does Not Subsume`\".

5. If `directive B` is \"`script-src`\" or \"`style-src`\":

 1. If `B`
 [contains](#directive-contains) a
 [`keyword-source`](https://w3c.github.io/webappsec-csp/#grammardef-keyword-source) expression \"`unsafe-eval`\" but
 `A` does not contain it, return
 \"`Does Not Subsume`\".

 2. If `B`
 [contains](#directive-contains) a
 [`keyword-source`](https://w3c.github.io/webappsec-csp/#grammardef-keyword-source) expression \"`unsafe-hashed-attributes`\"
 but `A` does not contain it, return
 \"`Does Not Subsume`\".

 3. Let `type B` be \"`script`\" if
 `directive B` is \"`script-src`\" and \"`style`\"
 otherwise. Similarly, let `type A` be \"`script`\" if
 `directive A` is \"`script-src`\" and \"`style`\"
 otherwise.

 4. If [Content Security Policy 3 § 6.7.3.2 Does a source list allow
 all inline behavior for
 type?](https://w3c.github.io/webappsec-csp/#allow-all-inline)
 returns \"`Allows`\" given `B` with
 `type B`, but returns \"`Does Not Allow`\" given
 `A` with `type A`, return
 \"`Does Not Subsume`\".

6. Let `list A` and `list B` be empty lists.

7. For each `expression A` in `A`:

 1. If `expression A` is \"`self`\", append a
 [`host-source`](https://w3c.github.io/webappsec-csp/#grammardef-host-source), returned by [§ 4.2.1 Rewrite \'self\' into
 a host-source expression for origin.](#rewrite-self) given
 `origin A` to `list A`.

 2. If `expression A` matches the U+002A ASTERISK
 character (`*`), append to `list A` the following
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) expressions: \"`ftp:`\", \"`http:`\",
 \"`https:`\", \"`ws:`\", \"`wss:`\", and `origin A`'s
 [scheme](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-scheme).

 1. If `directive A` is either \"`img-src`\" or
 \"`media-src`\", append a
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) expression \"`data:`\" to
 `list A`.

 2. If `directive A` is \"`media-src`\", append a
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) expression \"`blob:`\" to
 `list A`.

 3. [Continue](https://infra.spec.whatwg.org/#iteration-continue) to the next `expression A`.

 3. If `expression A` does not match
 [`keyword-source`](https://w3c.github.io/webappsec-csp/#grammardef-keyword-source) grammar, append `expression A`
 to `list A`.

8. For each `expression B` in `B`:

 1. If `expression B` is \"`self`\", append a
 [`host-source`](https://w3c.github.io/webappsec-csp/#grammardef-host-source), returned by [§ 4.2.1 Rewrite \'self\' into
 a host-source expression for origin.](#rewrite-self) given
 `origin B` to `list B`.

 2. If `expression B` matches the U+002A ASTERISK
 character (`*`), append to `list B` the following
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) expressions: \"`ftp:`\", \"`http:`\",
 \"`https:`\", \"`ws:`\", \"`wss:`\", and `origin B`'s
 [scheme](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-scheme).

 1. If `directive B` is either \"`img-src`\" or
 \"`media-src`\", append a
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) expression \"`data:`\" to
 `list B`.

 2. If `directive B` is \"`media-src`\", append a
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) expression \"`blob:`\" to
 `list B`.

 3. [Continue](https://infra.spec.whatwg.org/#iteration-continue) to the next `expression B`.

 3. If `expression B` does not match
 [`keyword-source`](https://w3c.github.io/webappsec-csp/#grammardef-keyword-source) grammar, append `expression B`
 to `list B`.

9. If `list B` is empty, return \"`Subsumes`\".

10. If `list A` is empty, return \"`Does Not Subsume`\".

11. For each `expression B` in `list B`:

 1. If `expression B` matches the
 [`hash-source`](https://w3c.github.io/webappsec-csp/#grammardef-hash-source) gramar, or
 [`nonce-source`](https://w3c.github.io/webappsec-csp/#grammardef-nonce-source) grammar,
 [continue](https://infra.spec.whatwg.org/#iteration-continue) to the next expression unless
 `directive A` is \"`script-src`\" or \"`style-src`\".

 2. Let `found match` be `false`.

 3. For each `expression A` in `list A`:

 1. If [§ 3.2.4 Source expression
 subsumption](#subsume-source-expressions) returns
 \"`Subsumes`\" given `expression A` and
 `expression B`, set `found match` to
 `true`. Break out of this inner loop.

 4. If `found match` is `false`, return
 \"`Does Not Subsume`\".

12. Return \"`Subsumes`\".

Let `directive A` and
`directive B` be \"`script-src`\". Consider the following
examples:

 A = "http://example.com 'sha256-xzi4zkCjuC8'"
 B = "http://example.com"

Since `B` does not allow
[`hash-source`](https://w3c.github.io/webappsec-csp/#grammardef-hash-source) expressions, but its value is found in
`A`, `A` subsumes `B`. It is, however,
not true that `B`
[subsumes](#content-security-policy-object-subsume) `A`.

 A = "https://example.com 'sha256-xzi4zkCjuC8'"
 B = "http://example.com"

In this case, `A` does not subsume `B` since
\"https://example.com\" does not
[subsume](#content-security-policy-object-subsume) \"http://example.com\".

 A = "http://example.com 'sha256-xzi4zkCjuC8'"
 B = "http://example.com 'unsafe-inline'"

Since `B` [allows all inline
behavior](https://w3c.github.io/webappsec-csp/#source-list-allows-all-inline-behavior), but `A` does not, `A` doesn't
[subsume](#content-security-policy-object-subsume) `B`.

 A = "http://example.com 'sha256-xzi4zkCjuC8' 'strict-dynamic'"
 B = "http://example.com 'unsafe-inline' 'strict-dynamic'"

Neither `A` nor `B` [allows all inline
behavior](https://w3c.github.io/webappsec-csp/#source-list-allows-all-inline-behavior). In this case, `A`
[subsumes](#content-security-policy-object-subsume) `B`.

#### 3.2.4. Source expression subsumption

Given two [source
expressions](https://w3c.github.io/webappsec-csp/#source-expression) `A` and `B`, this algorithm
returns \"`Subsumes`\" if `A`
[subsumes](#content-security-policy-object-subsume) `B`, and returns \"`Does Not Subsume`\"
otherwise.

1. Assert: Neither `A` nor `B` match the
 [`keyword-source`](https://w3c.github.io/webappsec-csp/#grammardef-keyword-source) grammar.

2. If both `A` and `B` match either
 [`host-source`](https://w3c.github.io/webappsec-csp/#grammardef-host-source) or
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) grammar:

 1. If [Content Security Policy 3 § 6.7.2.9 scheme-part
 matching](https://w3c.github.io/webappsec-csp/#match-schemes)
 returns \"`Does Not Match`\" given `A`'s
 [`scheme-part`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-part) (or `null` if `A` does not
 contain a
 [`scheme-part`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-part)) and `B`'s
 [`scheme-part`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-part) (or `null` if `B` does not
 contain a
 [`scheme-part`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-part)), return \"`Does Not Subsume`\".

 2. If `A` or `B` matches the
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) grammar:

 1. If `A` matches the
 [`scheme-source`](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) grammar, return \"`Subsumes`\".
 Otherwise, return \"`Does Not Subsume`\".

 3. If `B` has a `wildcard host`:

 1. If `A` doesn't have a `wildcard host`, return
 \"`Does not Subsume`\".

 2. Let `remaining host B` be the result of removing
 the leading (\"\*.\") from `B`'s
 [`host-part`](https://w3c.github.io/webappsec-csp/#grammardef-host-part).

 3. If [Content Security Policy 3 § 6.7.2.10 host-part
 matching](https://w3c.github.io/webappsec-csp/#match-hosts)
 returns \"`Does Not Match`\" given `A`'s
 [`host-part`](https://w3c.github.io/webappsec-csp/#grammardef-host-part) and `remaining host B`,
 return \"`Does Not Subsume`\".

 4. If `B` doesn't have a `wildcard host` and [Content
 Security Policy 3 § 6.7.2.10 host-part
 matching](https://w3c.github.io/webappsec-csp/#match-hosts)
 returns \"`Does Not Match`\" given `A`'s
 [`host-part`](https://w3c.github.io/webappsec-csp/#grammardef-host-part) and `B`'s
 [`host-part`](https://w3c.github.io/webappsec-csp/#grammardef-host-part), return \"`Does Not Subsume`\".

 5. If `B` has a `wildcard port` but `A`
 doesn't have a `wildcard port`, return \"`Does Not Subsume`\".

 6. If `B` doesn't have a `wildcard port` and [Content
 Security Policy 3 § 6.7.2.11 port-part
 matching](https://w3c.github.io/webappsec-csp/#match-ports)
 returns \"`Does Not Match`\" given `A`'s
 [`port-part`](https://w3c.github.io/webappsec-csp/#grammardef-port-part) (or `null` if `A` does not
 contain a
 [`port-part`](https://w3c.github.io/webappsec-csp/#grammardef-port-part)) and `B`'s
 [`port-part`](https://w3c.github.io/webappsec-csp/#grammardef-port-part) (or `null` if `B` does not
 contain a
 [`port-part`](https://w3c.github.io/webappsec-csp/#grammardef-port-part)), return \"`Does Not Subsume`\".

 7. If [Content Security Policy 3 § 6.7.2.12 path-part
 matching](https://w3c.github.io/webappsec-csp/#match-paths)
 returns \"`Does Not Match`\" given `A`'s
 [`path-part`](https://w3c.github.io/webappsec-csp/#grammardef-path-part) (or `null` if `A` does not
 contain a
 [`path-part`](https://w3c.github.io/webappsec-csp/#grammardef-path-part)) and `B`'s
 [`path-part`](https://w3c.github.io/webappsec-csp/#grammardef-path-part) (or `null` if `B` does not
 contain a
 [`path-part`](https://w3c.github.io/webappsec-csp/#grammardef-path-part)), return \"`Does Not Subsume`\".

 8. Return \"`Subsumes`\".

3. If both `A` and `B` match the
 [`hash-source`](https://w3c.github.io/webappsec-csp/#grammardef-hash-source) grammar:

 1. If `A`
 [is](https://infra.spec.whatwg.org/#string-is) `B`, return \"`Subsumes`\".
 Otherwise, return \"`Does Not Subsume`\".

4. If both `A` and `B` match the
 [`nonce-source`](https://w3c.github.io/webappsec-csp/#grammardef-nonce-source) grammar:

 1. Return \"`Subsumes`\".

 Nonce source matching is value-agnostic to prevent
 a malicious embedder from brute forcing the nonce value with an
 attack as described in [§ 6.1 Policy Leakage](#policy-leakage)

5. Return \"`Does Not Subsume`\".

Subsumption for nonces and hashes should
be updated to account for more permissive sources (like \'self\' or
\'\*\' combined with \'unsafe-inline\') logically subsuming them.

## 4. Algorithms

### 4.1. Is `response` to `request` blocked by `requiredCSP`?

Given a
[response](https://fetch.spec.whatwg.org/#concept-response) (`response`), a
[request](https://fetch.spec.whatwg.org/#concept-request) (`request`), and a [serialized
CSP](https://w3c.github.io/webappsec-csp/#serialized-csp)-or-null (`requiredCSP`), this algorithm
returns \"`Allowed`\" or \"`Blocked`\" as appropriate:

1. Return \"`Allowed`\" if `requiredCSP` is `null`.

2. Let `required policy` be the result of
 [parsing](https://w3c.github.io/webappsec-csp/#parse-serialized-csp) `requiredCSP` as \"`enforce`\".

3. If the [§ 4.2 Does response allow blanket enforcement of policy from
 request?](#origin-allowed) algorithm returns \"`Allowed`\" when
 executed upon `response` and `request`, return
 \"`Allowed`\".

4. If the [§ 3.2.1 CSP List Subsumption](#subsume-csp-list) algorithm
 returns \"`Subsumes`\" when executed upon
 `required policy`, `response`'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url)'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin), the result of
 [parsing](https://w3c.github.io/webappsec-csp/#abstract-opdef-parse-a-responses-content-security-policies) `response`'s Content Security
 Policies, and `response`'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url)'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin), return \"`Allowed`\".

5. Return \"`Blocked`\".

### 4.2. Does `response` allow blanket enforcement of policy from `request`?

Given a
[response](https://fetch.spec.whatwg.org/#concept-response) (`response`), and a
[request](https://fetch.spec.whatwg.org/#concept-request) (`request`), this algorithm returns
\"`Allowed`\" if the former allows the latter to enforce arbitrary
policy, and \"`Not Allowed`\" otherwise:

1. If `response`'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url)'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is a [local
 scheme](https://fetch.spec.whatwg.org/#local-scheme), return \"`Allowed`\".

 The [local
 scheme](https://fetch.spec.whatwg.org/#local-scheme) responses already inherit their policy from the
 embedder, so we allow the embedder to tighten that policy via this
 embedding mechanism.

2. If `response`'s [header
 list](https://fetch.spec.whatwg.org/#concept-response-header-list) has a header named
 \`[`Allow-CSP-From`](#http-headerdef-allow-csp-from)\` (`header`):

 1. If `header`'s value is \"`*`\", return \"`Allowed`\".

 2. If `request`'s
 [origin](https://fetch.spec.whatwg.org/#concept-request-origin),
 [serialized](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin) and [UTF-8
 encoded](https://encoding.spec.whatwg.org/#utf-8-encode) is `header`'s value, return
 \"`Allowed`\".

3. Return \"`Not Allowed`\".

#### 4.2.1. Rewrite `'self'` into a host-source expression for `origin`.

Given an origin (`origin`), this algorithm returns a
[`host-source`](https://w3c.github.io/webappsec-csp/#grammardef-host-source) expression that has the same effect as `'self'` for
that origin:

1. If `origin` is an [opaque
 origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque), return the empty string.

2. Return the [ASCII
 serialization](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin) of `origin`.

## 5. Security Considerations

### 5.1. Threat Model

This proposal aims to give documents control over the content used in a
child frame which it embeds. Since frames are generally considered to be
security boundaries in themselves, limiting cross-origin access quite
intentionally, we should be sure to avoid weakening that boundary.

Our goals, then, are to:

- Allow embedders to impose a Content Security Policy requirement upon
 arbitrary documents it embeds.

- Ensure that documents loaded with a given Content Security Policy
 requirement can't trivially escape it (through, for instance, [local
 scheme](https://fetch.spec.whatwg.org/#local-scheme) documents under its control). Putting the requirement
 into each context's [policy
 container](https://fetch.spec.whatwg.org/#concept-request-policy-container) allows us to rely on the same inheritance structure
 as CSP itself, and also provides a clear point from which to continue
 imposing the requirements upon documents which the embedee itself
 might choose to embed.

- Ensure that documents loaded with a given Content Security Policy
 requirement have visibility into the requirements being imposed, and
 opt-into them either explicitly (via the
 \`[`Allow-CSP-From`](#http-headerdef-allow-csp-from)\` header) or implicitly (via the mechanisms
 outlined in [§ 3 Implicit Policy Acceptance](#implicit-opt-in)). This
 protects embedees from malicious policy requirements which might
 disable critical security infrastructure.

- And, of course, to do the above without introducing new
 vulnerabilities or risks.

This proposal does not intend to supplant existing isolation mechanisms
like CSP's `frame-ancestors` or `X-Frame-Options`, nor does it provide
embedees with any protection beyond what
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) elements already represent.

### 5.2. Policy Enforcement

Embedded documents should be careful to evaluate the proposed Content
Security Policy, and not simply to reflect whatever policy an embedder
suggests. Doing so may enable a clever attacker to selectively disable
pieces of a website's code which are essential for its own protection.

In particular, documents which do not expect to be embedded should
continue to respond to any such request with a Content Security Policy
containing an appropriate
[`frame-ancestors`](https://w3c.github.io/webappsec-csp/#frame-ancestors) directive.

### 5.3. Header Reflection

Servers should be cautious about blindly reflecting the
\`[`Sec-Required-CSP`](#http-headerdef-sec-required-csp)\` header into a
\`[`Content-Security-Policy`](https://w3c.github.io/webappsec-csp/#header-content-security-policy)\` response header, as the imposed policy might
restrict the resulting context in unexpected ways, or be weaker than the
policy the server would otherwise apply.

Instead, developers are encouraged to evaluate incoming policies before
accepting them by delivering an
\`[`Allow-CSP-From`](#http-headerdef-allow-csp-from)\` header for trusted origins. This ensures that
policies the page wishes to apply are applied, while layering the
required policy on top. Since multiple policies can only tighten the
restrictions, this will ensure that the server's policy remains a solid
baseline protection.

### 5.4. Header Length

This feature allows an embedder to control the value of the
\`[`Sec-Required-CSP`](#http-headerdef-sec-required-csp)\` HTTP header for cross-origin embedded
document requests. If the server enforces a limit on the length of HTTP
headers, this can cause a network error. This can be abused by an
attacker to force a cache invalidation, see
<https://xsleaks.dev/docs/attacks/cache-probing/#cache-probing-with-error-events>.
Because of this, we limit the maximum length of valid csp attributes to
4 KB.

## 6. Privacy Considerations

### 6.1. Policy Leakage

The enforcement mechanism allows a malicious embedder to read a page's
policy cross-origin by brute-forcing its constraints. This could leak
interesting data about the page or the user loading the page if the
policy contains secret tokens or usernames.

Again, the best defense here is to control the contexts allowed to embed
a given resource via an appropriate
[`frame-ancestors`](https://w3c.github.io/webappsec-csp/#frame-ancestors) directive.

### 6.2. Data Exfiltration

This feature allows an embedder to send information to a third-party
endpoint via the
\`[`Sec-Required-CSP`](#http-headerdef-sec-required-csp)\` HTTP header. This doesn't seem to expose any
information that couldn't be tunneled in the HTTP request itself (via
GET parameters, etc), and embedders remain in control over the endpoints
to which such requests may be made by enforcing a Content Security
Policy with an appropriate `child-src` directive.

## 7. Authoring Considerations

### 7.1. Requiring `'self'`

When processing a [required
CSP](#policy-container-required-csp), the keyword
[`'self'`](https://w3c.github.io/webappsec-csp/#grammardef-self) refers to the
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) of the URL being loaded into the [child
navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable), not to the origin of the document which required the
policy.

MegaCorp Inc. requires a policy
containing
[`'self'`](https://w3c.github.io/webappsec-csp/#grammardef-self) on their page at `https://example.com/page.html`:

 <iframe src="https://advertisements-r-us.example.com/ad1.cfm"
 csp="script-src 'self'">
 </iframe>

If the returned CSP is:

 Content-Security-Policy: script-src 'self'

Then this
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element will be loaded.

If, however, the returned CSP is:

 Content-Security-Policy: script-src "https://example.com/"

Then this
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element will not be loaded.

## 8. IANA Considerations

The permanent message header field registry should be updated with the
following registration for the
\`[`Sec-Required-CSP`](#http-headerdef-sec-required-csp)\` header:
[\[RFC3864\]](#biblio-rfc3864 "Registration Procedures for Message Header Fields")

Header field name

: Sec-Required-CSP

Applicable protocol

: http

Status

: standard

Author/Change controller

: W3C

Specification document

: This specification (See [§ 2.2 The Sec-Required-CSP HTTP Request
 Header](#required-csp-header))

Likewise, the registry should be updated with the following registration
for the
\`[`Allow-CSP-From`](#http-headerdef-allow-csp-from)\` header:
[\[RFC3864\]](#biblio-rfc3864 "Registration Procedures for Message Header Fields")

Header field name

: Allow-CSP-From

Applicable protocol

: http

Status

: standard

Author/Change controller

: W3C

Specification document

: This specification (See [§ 2.3 The Allow-CSP-From HTTP Response
 Header](#allow-csp-from-header))
