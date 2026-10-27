
## 1. Introduction

The web platform provides an ever-expanding set of features and APIs,
offering richer functionality, better developer ergonomics, and improved
performance. However, a missing piece is the ability for the developer
to selectively enable, disable, or modify the behavior of some of these
browser features and APIs within their application:

1. The developer may want to selectively *disable* access to certain
 browser features and APIs to \"lock down\" their application, as a
 security or performance precaution, to prevent own and third-party
 content executing within their application from introducing unwanted
 or unexpected behaviors within their application.
2. The developer may want to selectively *enable* access to certain
 browser features and APIs which may be disabled by default - e.g.
 some features may be disabled by default in embedded context unless
 explicitly enabled; some features may be subject to other policy
 requirements.
3. The developer may want to use the policy to assert a promise to a
 client or an embedder about the use---or lack of thereof---of
 certain features and APIs. For example, to enable certain types of
 \"fast path\" optimizations in the browser, or to assert a promise
 about conformance with some requirements set by other embedders -
 e.g. various social networks, search engines, and so on.

This specification defines a policy mechanism that addresses the above
use cases.

This specification used to be named Feature Policy.

## 2. Examples

SecureCorp Inc. wants to disable use of Fullscreen and Geolocation APIs
within their application. It can do so by delivering the following HTTP
response header to define a permissions policy:

 Permissions-Policy: fullscreen=(), geolocation=()

By specifying an empty origin list, the specified features will be
disabled for all documents, including nested documents, regardless of
their origin.

Geolocation is disabled by default in all cross-origin frames. FastCorp
Inc. has a specific cross-origin iframe on their site for which it wants
to enable geolocation. It can do so by including an \"`allow`\"
attribute on the iframe element:

 <iframe src="https://other.com/map" allow="geolocation"></iframe>

Iframe attributes can selectively enable features in certain frames, and
not in others, even if those contain documents from the same origin.

SecureCorp Inc. wants to completely disable use of the Geolocation API
within all [descendant
navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#descendant-navigables) except for its own origin and those whose origin is
\"`https://example.com`\", even in the presence of an attacker who can
embed their own iframes on SecureCorp's pages. It can do this by
delivering the following HTTP response header to define a restricted
permissions policy for Geolocation:

 Permissions-Policy: geolocation=(self "https://example.com")

The [allowlist](#allowlist) is a
list of one or more origins, which can include the application's origin,
optionally with the keyword \"`self`\", and any third-party origin.

With this policy in effect, it can then use the \"`allow`\" iframe
attribute as usual to grant geolocation to certain frames, but only
those frames hosting content from http://example.com or SecureCorp
itself will actually be granted the ability to use that API.

SecureCorp Inc. restructured its domains and now needs to delegate use
of the Geolocation API to its origin (\"`https://example.com`\") as well
as three subdomains (\"`https://geo.example.com`\",
\"`https://geo2.example.com`\", and \"`https://new.geo2.example.com`\").
This needs to be accomplished while still disabling the use of the
Geolocation API within all other browsing contexts. It can do this by
delivering the following HTTP response header:

 Permissions-Policy: geolocation=(self "https://example.com" "https://geo.example.com" "https://geo2.example.com" "https://new.geo2.example.com")

This works, but if SecureCorp Inc. feels safe delegating to any
subdomains on \"`https://example.com`\" the HTTP response header could
instead be:

 Permissions-Policy: geolocation=(self "https://example.com" "https://*.example.com")

Not only would the above header permit \"`https://geo.example.com`\",
\"`https://geo2.example.com`\", and \"`https://new.geo2.example.com`\"
to use the Geolocation API, but any other subdomains of
\"`https://example.com`\" could use it too. Note that
\"`https://example.com`\" is not covered by the
[allowlist](#allowlist) entry
\"`https://*.example.com`\" and must also be added.

SecureCorp Inc. restructured its services and now needs to needs to
delegate use of the Geolocation API to its origin
(\"`https://example.com`\") as well as three non-default ports
(\"`https://example.com:444`\", \"`https://example.com:445`\", and
\"`https://example.com:446`\"). This needs to be accomplished while
still disabling the use of the Geolocation API within all other browsing
contexts. It can do this by delivering the following HTTP response
header:

 Permissions-Policy: geolocation=(self "https://example.com" "https://example.com:444" "https://example.com:445" "https://example.com:446")

This works, but if SecureCorp Inc. feels safe delegating to any ports on
\"`https://example.com`\" the HTTP response header could instead be:

 Permissions-Policy: geolocation=(self "https://example.com:*")

Not only would the above header permit \"`https://example.com:444`\",
\"`https://example.com:444`\", and \"`https://example.com:445`\" to use
the Geolocation API, but any other ports on \"`https://example.com`\"
could use it too.

JSPlaygroundCorp Inc. wants to host user-generated web applications, but
wants the browser to manage their permissions to use [powerful
features](https://w3c.github.io/permissions/#dfn-powerful-feature) in isolation of each other. This can be accomplished by
creating discrete subdomains for each piece of web-content or
web-content creator, and navigating them as top-level documents
(framework and user-content can still be separated using same-origin
iframes).

This is necessary since users grant permissions to the domain they
perceive they are interacting with in the browser, which is the
top-level domain.

JSPlaygroundCorp should avoid iframing user-generated web applications
using the
[`allow`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allow) attribute from its own domain in this case, as
this would grant its domain permissions to all of them.

PlatformCorp Inc. wants to offer a marketplace of embeddable third-party
components to build from or games to play under its top-level domain. It
wants to delegate the use of [powerful
features](https://w3c.github.io/permissions/#dfn-powerful-feature) like the
[`getUserMedia()`](https://w3c.github.io/mediacapture-main/#dom-mediadevices-getusermedia) API responsibly. It accepts responsibility for tracking
which of its component applications need a feature, using bespoke
\"install\" UX to keep end-users in charge.

Camera and microphone are disabled by default in all cross-origin
frames. Each third-party component has a subdomain, and can be embedded
in a cross-origin iframe. PlatformCorp can use the
[`allow`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allow) attribute on the
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element to control whether to delegate camera or
microphone access or not to each subdomain.

An iframe where the component \"app1\" should have camera access,
\"app2\" should have microphone access, and \"app3\" should have both
might look like this:

 <iframe
 allow="camera https://app1.site.com https://app3.site.com;
 microphone https://app2.site.com https://app3.site.com"
 src="https://doc1.site.com"
 sandbox="allow-same-origin allow-scripts">
 </iframe>

Iframe attributes can selectively enable features in certain frames, and
not in others, even if those contain documents from the [same
origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin). The list of sandbox tokens might be longer in
practice.

Since browsers generally ask users to grant permissions to the top-level
domain, there might not be any additional permission prompt for the
components to request camera or microphone access if the user already
trusts PlatformCorp.

## 3. Other and related mechanisms

[\[HTML5\]](#biblio-html5 "HTML5") defines a
[`sandbox`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-sandbox) attribute for
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) elements that allows developers to reduce the risk
of including potentially untrusted content by imposing restrictions on
content's abilities - e.g. prevent it from submitting forms, running
scripts and plugins, and more. The
[sandbox](https://w3c.github.io/webappsec-csp/#sandbox) directive defined by
[\[CSP2\]](#biblio-csp2 "Content Security Policy Level 2")
extends this capability to any resource, framed or not, to ask for the
same set of restrictions - e.g. via an HTTP response header
(`Content-Security-Policy: sandbox`). These mechanisms enable the
developer to:

- Set and customize a sandbox policy on any resource via CSP.
- Set and customize individual sandbox policies on each `iframe` element
 within their application.

However, there are several limitations to the above mechanism: the
developer cannot automatically apply a policy across all contexts, which
makes it hard or impossible to enforce consistently in some cases (e.g.
due to third-party content injecting frames, which the developer does
not control); there is no mechanism to selectively enable features that
may be off by default; the sandbox mechanism automatically disables all
sandbox features, and requires the developer to opt back in to each of
them, so it is impossible to extend the set of sandbox features without
significant compatibility risk.

Permissions Policy is intended to be used in combination with the
sandbox mechanism (i.e. it does not duplicate feature controls already
covered by sandbox), and provides an extensible mechanism that addresses
the above limitations.

## 4. Framework

### 4.1. Policy-controlled Features

A [policy-controlled feature] is an API or behaviour which can
be enabled or disabled in a document by referring to it in a
[permissions policy](#permissions-policy).

For brevity, policy-controlled features will often be referred to in
this document simply as \"Features\". Unless otherwise indicated, the
term \"feature\" refers to [policy-controlled
features](#policy-controlled-feature). Other specifications, defining such features, should
use the longer term to avoid any ambiguity.

This spec currently only deals with
features defined in Documents. We should figure out how to word this to
include the possibility of features and permissions policies in Workers
and Worklets as well.

[Policy-controlled
features](#policy-controlled-feature) are identified by
[tokens], which are
character strings used in [policy
directives](#policy-directive).

Each [policy-controlled
feature](#policy-controlled-feature) has a [default
allowlist](#policy-controlled-feature-default-allowlist), which defines whether that feature is available in
documents in top-level traversables, and how access to that feature is
inherited in child navigables.

A user agent has a set of [supported features], which is the set of
[features](#policy-controlled-feature) which it allows to be controlled through policies. User
agents are not required to support every
[feature](#policy-controlled-feature).

The [policy-controlled
features](#policy-controlled-feature) themselves are not themselves part of this framework. A
non-normative list of currently-defined features is maintained as a
[companion
document](https://github.com/w3c/webappsec-permissions-policy/blob/master/features.md)
alongside this specification.

### 4.2. Policies

A [declared policy] is a
[struct](https://infra.spec.whatwg.org/#struct) with the following
[items](https://infra.spec.whatwg.org/#struct-item):

[declarations]

: an [ordered
 map](https://infra.spec.whatwg.org/#ordered-map) from
 [features](#policy-controlled-feature) to [allowlists](#allowlist)

[reporting configuration]

: an [ordered
 map](https://infra.spec.whatwg.org/#ordered-map) from
 [features](#policy-controlled-feature) to
 [strings](https://infra.spec.whatwg.org/#string)

A [permissions policy] is a
[struct](https://infra.spec.whatwg.org/#struct) with the following
[items](https://infra.spec.whatwg.org/#struct-item):

[inherited policy]

: an [ordered
 map](https://infra.spec.whatwg.org/#ordered-map) from
 [features](#policy-controlled-feature) to \"`Enabled`\" or \"`Disabled`\"

[declared policy]

: a [declared policy](#declared-policy)

An [empty permissions policy] is a [permissions
policy](#permissions-policy) that has an [inherited
policy](#permissions-policy-inherited-policy) which contains \"`Enabled`\" for every [supported
feature](#supported-features), a [declared
policy](#permissions-policy-declared-policy) whose
[declarations](#declared-policy-declarations) and [reporting
configuration](#declared-policy-reporting-configuration) are both empty [ordered
maps](https://infra.spec.whatwg.org/#ordered-map).

### 4.3. Inherited policies

The [inherited policy for a feature] `feature` is the
value in the [inherited
policy](#permissions-policy-inherited-policy) whose key is `feature`. After a [permissions
policy](#permissions-policy) has been initialized, its [inherited
policy](#permissions-policy-inherited-policy) will contain a value for each [supported
feature](#supported-features).

Upon both creation and navigation, Each
[`Document`](https://dom.spec.whatwg.org/#document) inherits a set of policies from its parent frame, or in
the case of the
[`Document`](https://dom.spec.whatwg.org/#document) in a [top-level
traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable), from the defined defaults for each [policy-controlled
feature](#policy-controlled-feature). This inherited policy determines the initial state
(\"`Enabled`\" or \"`Disabled`\") of each feature, and whether it can be
controlled by a [declared
policy](#permissions-policy-declared-policy) in the
[`Document`](https://dom.spec.whatwg.org/#document).

In a
[`Document`](https://dom.spec.whatwg.org/#document) in a [top-level
traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable), the inherited policy is based on defined defaults for
each feature.

In a
[`Document`](https://dom.spec.whatwg.org/#document) in a [child
navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable), the inherited policy is based on the parent document's
permissions policy, as well as the [child
navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable)'s [container
policy](#container-policy).

### 4.4. Header policies

A [header policy] is a list of [policy
directives](#policy-directive) delivered via an HTTP header with a document. This
forms the document's [permissions
policy](#permissions-policy)'s [declared
policy](#permissions-policy-declared-policy).

### 4.5. Container policies

In addition to the [header
policy](#header-policy), each
[child
navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable) has a [container policy], which is a [policy
directive](#policy-directive), which may be empty. The [container
policy](#container-policy)
can be set by attributes on the [navigable
container](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable-container).

The [container policy](#container-policy) for a [child
navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable) influences the [inherited
policy](#permissions-policy-inherited-policy) of any
[`Document`](https://dom.spec.whatwg.org/#document) loaded into that navigable. (See [§ 9.7 Define an
inherited policy for feature in container at
origin](#algo-define-inherited-policy-in-container)).

Currently, the [container
policy](#container-policy)
cannot be set directly, but is indirectly set by the
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)
[`allowfullscreen`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allowfullscreen), and
[`allow`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allow) attributes. Future revisions to this spec may
introduce a mechanism to explicitly declare the full [container
policy](#container-policy).

### 4.6. Policy directives

A [policy directive] is an [ordered
map](https://infra.spec.whatwg.org/#ordered-map), mapping [policy-controlled
features](#policy-controlled-feature) to corresponding
[allowlists](#allowlist) of
origins.

A [policy directive](#policy-directive) is represented in HTTP headers as the serialization of
an
[sf-dictionary](https://datatracker.ietf.org/doc/html/rfc8941#dictionary) structure, and in HTML attributes as its ASCII
serialization.

### 4.7. Allowlists

A permissions policy [allowlist] is conceptually a
set of
[origins](https://url.spec.whatwg.org/#concept-url-origin). An [allowlist](#allowlist) may be either:

- [The special value `*`], which represents every origin, or
- A struct containing:
 - [expressions], which is an ordered set of
 [permissions-source-expression](#permissions-source-expression)
 - [self-origin], which is an
 [origin](https://url.spec.whatwg.org/#concept-url-origin) or `null`
 - [src-origin], which is an
 [origin](https://url.spec.whatwg.org/#concept-url-origin) or `null`

A [permissions-source-expression] is a
[scheme-source](https://w3c.github.io/webappsec-csp/#grammardef-scheme-source) or a
[host-source](https://w3c.github.io/webappsec-csp/#grammardef-host-source).

The keywords `'self'`, `'src'`, and `'none'` can appear in the text
representation of allowlists in headers and attribute strings. These
keywords are always interpreted in context during parsing, and only the
origins which they refer to are stored in the allowlist. The keywords
themselves are not part of the allowlist.

To determine whether an [allowlist](#allowlist) [matches] an origin `origin`, run these steps:

1. If the [allowlist](#allowlist)
 is [the special value
 `*`](#the-special-value), then return true.

 We are not using the CSP variant of wildcard matching
as it requires the HTTPS scheme.

1. If the [allowlist](#allowlist)'s [self-origin](#self-origin) is not null and it is [same
 origin-domain](https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain) with `origin`, then return true.

2. If the [allowlist](#allowlist)'s [src-origin](#src-origin) is not null and it is [same
 origin-domain](https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain) with `origin`, then return true.

3. If `origin` is an [opaque
 origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque), return false.

4. Let `url` be the result of calling the [url
 parser](https://url.spec.whatwg.org/#concept-url-parser) on the
 [serialization](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin) of `origin`.

5. [For
 each](https://infra.spec.whatwg.org/#list-iterate)
 [permissions-source-expression](#permissions-source-expression) `item` in the
 [allowlist](#allowlist)'s
 [expressions](#expressions):

 1. If the result of running [Does url match expression in origin
 with redirect
 count?](https://w3c.github.io/webappsec-csp/#match-url-to-source-expression) on `url`, `item`,
 `origin`, and 0 is true then return true.

6. Return false.

### 4.8. Default Allowlists

Every [policy-controlled
feature](#policy-controlled-feature) has a [default
allowlist]. The [default
allowlist](#policy-controlled-feature-default-allowlist) determines whether the feature is allowed in a
[`Document`](https://dom.spec.whatwg.org/#document) with no [declared
policy](#permissions-policy-declared-policy) in a [top-level
traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable), and also whether access to the feature is
automatically delegated to documents in [child
navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable).

The [default
allowlist](#policy-controlled-feature-default-allowlist) for a
[feature](#policy-controlled-feature) is one of these values:

[`*`]
: The feature is allowed in
 [`Document`](https://dom.spec.whatwg.org/#document)s in [top-level
 traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) by default, as well as those in all [child
 navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable). It can be disallowed in [child
 navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable) by explicitly supplying a [container
 policy](#container-policy) on the [navigable
 container](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable-container) that overrides this default (or in any
 [navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable), by delivering the
 [`Document`](https://dom.spec.whatwg.org/#document) with a suitable
 [`Permissions-Policy`](#permissions-policy-header) header).

[`'self'`]
: The feature is allowed in
 [documents](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document) in [top-level
 traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) by default, as well as those in [child
 navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable) whose
 [document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document) is [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) with its
 [parent](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-parent)'s
 [document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document), when allowed in that
 [`Document`](https://dom.spec.whatwg.org/#document). It is disallowed by default in [child
 navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable) whose
 [document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document) is cross-origin with its
 [parent](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-parent)'s
 [document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

## 5. Permissions Policy Serialization

### 5.1. HTML attribute serialization

A [serialized permissions policy] is a string made of entries separated by U+003B (;). After
[stripping leading and trailing ASCII
whitespace](https://infra.spec.whatwg.org/#strip-leading-and-trailing-ascii-whitespace), each entry must be one of:

- empty;
- the
 [token](#policy-controlled-feature-tokens) of a [policy-controlled
 feature](#policy-controlled-feature);
- the
 [token](#policy-controlled-feature-tokens) of a [policy-controlled
 feature](#policy-controlled-feature), followed by one or more [ASCII
 whitespace](https://infra.spec.whatwg.org/#ascii-whitespace) and \"`'none'`\";
- the
 [token](#policy-controlled-feature-tokens) of a [policy-controlled
 feature](#policy-controlled-feature), followed by one or more [ASCII
 whitespace](https://infra.spec.whatwg.org/#ascii-whitespace) and one or more allowlist values separated by one or
 more [ASCII
 whitespace](https://infra.spec.whatwg.org/#ascii-whitespace).

The same token must not appear in more than one entry.

Each allowlist value must be one of:

- \"`*`\";
- \"`'self'`\", which refers to the
 [origin](https://dom.spec.whatwg.org/#concept-document-origin) of the
 [`Document`](https://dom.spec.whatwg.org/#document) that contains the element;
- \"`'src'`\", which refers to the element's [declared
 origin](#declared-origin);
- the
 [serialization](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin) of an origin that is not an [opaque
 origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque) and whose
 [host](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-host) does not contain U+002A (\*), optionally followed by
 U+002F (/).

User agents process the attribute with [§ 9.3 Parse policy
directive](#algo-parse-policy-directive), which also accepts values that
do not follow these rules.

### 5.2. Structured header serialization

[Policy Directives](#policy-directive) in HTTP headers are represented as Structured Fields.
[\[RFC8941\]](#biblio-rfc8941 "Structured Field Values for HTTP")

In this representation, a [policy
directive](#policy-directive) is represented by a Dictionary.

Each Dictionary Member associates a
[feature](#policy-controlled-feature) with an [allowlist](#allowlist). The Member Names must be
[Tokens](https://datatracker.ietf.org/doc/html/rfc8941#token). If a
[token](https://datatracker.ietf.org/doc/html/rfc8941#token) does not name one of the user agent's [supported
features](#supported-features), then the Dictionary Member will be ignored by the
processing steps.

The Member Values represent
[allowlists](#allowlist), and must
be one of:

- a String containing the ASCII
 [permissions-source-expression](#permissions-source-expression)

- the
 [Token](https://datatracker.ietf.org/doc/html/rfc8941#token) `*`

- the
 [Token](https://datatracker.ietf.org/doc/html/rfc8941#token) `self`

- an Inner List containing zero or more of the above items.

Member Values may have a Parameter named `"report-to"`, whose value must
be a
[Token](https://datatracker.ietf.org/doc/html/rfc8941#token). Any other parameters will be ignored.

Any other items inside of an Inner List will be ignored by the
processing steps, and the Member Value will be processed as if they were
not present. Member Values of any other form will cause the entire
Dictionary Member to be ignored by the processing steps.

## 6. Delivery

### 6.1. \``Permissions-Policy`\` HTTP Header Field

The \`[`Permissions-Policy`]\` HTTP header field can
be used in the
[response](https://fetch.spec.whatwg.org/#concept-response-response) (server to client) to communicate the [permissions
policy](#permissions-policy) that should be enforced by the client.

\`[`Permissions-Policy`](#permissions-policy-header)\` is a structured header. Its value must be a
dictionary. It's ABNF is:

``` abnf
PermissionsPolicy = sf-dictionary
```

The semantics of the dictionary are defined in [§ 5.2 Structured header
serialization](#structured-header-serialization).

The processing steps are defined in [§ 9.2 Construct policy from
dictionary and origin](#algo-construct-policy).

### 6.2. The `allow` attribute of the `iframe` element

[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) elements have an
[`allow`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allow) attribute, whose value must be a [serialized
permissions
policy](#serialized-permissions-policy).

The [allowlist](#allowlist) for
the features named in the attribute may be empty; in that case, the
default value for the allowlist is `'src'`, which represents the origin
of the URL in the iframe's
[`src`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-src) attribute.

When not empty, the
[`allow`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allow) attribute will result in adding an
[allowlist](#allowlist) for each
recognized
[feature](#policy-controlled-feature) to the
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element's [content
navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#content-navigable)'s [container
policy](#container-policy),
when it is constructed.

### 6.3. Additional attributes to support legacy features

Some
[features](#policy-controlled-feature) controlled by Permissions Policy have existing iframe
attributes defined. This specification redefines these attributes to
influence the
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)'s [content
navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#content-navigable)'s [container
policy](#container-policy).

#### 6.3.1. allowfullscreen

The
[`allowfullscreen`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allowfullscreen)
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) attribute controls access to
[`requestFullscreen()`](https://fullscreen.spec.whatwg.org/#dom-element-requestfullscreen).

If the iframe element has an
[`allow`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allow) attribute whose value contains the token
\"`fullscreen`\", then the
[`allowfullscreen`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allowfullscreen) attribute must have no effect.

Otherwise, the presence of an
[`allowfullscreen`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allowfullscreen) attribute on an
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) will result in adding an
[allowlist](#allowlist) of `*` for
the \"`fullscreen`\" feature to the
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element's [content
navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#content-navigable)'s [container
policy](#container-policy),
when it is constructed.

This is different from the behaviour of `<iframe allow="fullscreen">`,
and is for compatibility with existing uses of `allowfullscreen`. If
`allow="fullscreen"` and `allowfullscreen` are both present on an iframe
element, then the more restrictive allowlist of `allow="fullscreen"`
will be used.

## 7. Policy Introspection from Scripts

### 7.1. Overview

The current policy which is in effect in a document can be observed by
scripts. This can be used to make decisions, for instance, about what
user interface to display, in cases where it is not possible to
determine otherwise whether a feature is enabled or not. (Some features
may not have any observable failure mode, or may have unwanted side
effects to feature detection.)

Documents and iframes both provide a
[`PermissionsPolicy`](#permissionspolicy) object which can be used to inspect the permissions
policies which apply to them.

#### 7.1.1. Document policies

To retreive the currently effective policy, use
`document.permissionsPolicy`. This returns a
[`PermissionsPolicy`](#permissionspolicy) object, which can be used to:

- query the state (allowed or denied) in the current document for a
 given feature,

- get a list of all available features (allowed or not) in the current
 document,

- get a list of all allowed features in the current document, or

- get the allowlist for a given feature in the current document.

<!doctype html>
 <script>
 const policy = document.permissionsPolicy;

 // This will be true if this document can use WebUSB.
 const can_use_usb = policy.allowsFeature('usb');

 // True if a new frame at https://example.com will be allowed to use WebXR.
 if (policy.allowsFeature('xr-spatial-tracking', 'https://example.com')) {
 // Show UI to create frame at https://example.com.
 } else {
 // Show an alternative UI.
 }

 // Get the list of origins which are allowed to request payment. The result
 // will be a list of explicit origins, or the single element ['*'] if all
 // origins are allowed.
 const allowed_payment_origins = policy.getAllowlistForFeature('payment');

 // Get the list of all features supported in this document (even those
 // which are not allowed). The result will be an array of strings, each
 // representing a feature.
 const all_features = policy.features();
 if (all_features.includes('geolocation')) {
 // Append a child frame to a third-party map service.
 }
 </script>

#### 7.1.2. Frame policies

It is also possible to inspect the policy on an iframe element, from the
document which contains it. The policy object in this case represents
the [observable policy](#observable-policy) for the frame, which depends only on the current
document and the attributes of the iframe element. It does not reveal
whether a feature is actually currently allowed in the frame, as the
document in the frame may have applied its own policy via an HTTP
header, or may have navigated away from its initial location to a new
origin. Revealing the effective policy in the iframe element's nested
navigable in that case could leak information about the behaviour of a
cross-origin document.

<!doctype html>
 <iframe id="frame" allow="fullscreen; xr-spatial-tracking"></iframe>
 <script>
 const iframe_element = document.getElementById("frame");
 const iframe_policy = iframe_element.permissionsPolicy;

 // True if the framed document will be allowed to use WebXR
 if (iframe_policy.allowsFeature('xr-spatial-tracking')) {
 // display virtual reality controls
 }
 </script>

The [observable policy](#observable-policy) on an iframe element is independent of any actual
content loaded into the frame (to avoid cross-origin information
leakage,) or even whether it is in a document tree.

<!doctype html>
 <!-- this frame should not be allowed to use fullscreen when the document
 in its src attribute is loaded in it -->
 <iframe id="frame" allow="fullscreen https://example.com" src="https://example.net/" ></iframe>
 <script>
 const iframe_element = document.getElementById("frame");
 const iframe_policy = iframe_element.permissionsPolicy;
 // This will be false, as the URL listed in the src attribute is not allowed
 // by policy to use fullscreen.
 const is_fullscreen_allowed_in_frame = iframe_policy.allowsFeature('fullscreen');

 const new_frame = document.createElement('iframe');
 new_frame.allow = 'sync-xhr';
 // This will be true, as the iframe is allowed to use sync-xhr at whatever URL is
 // mentioned in its src attribute, even though that attribute is not yet set.
 const is_sync_xhr_allowed = new_frame.permissionsPolicy.allowsFeature('sync-xhr');
 </script>

### 7.2. The permissionsPolicy object

```
[Exposed=Window]
interface PermissionsPolicy {
 boolean allowsFeature(DOMString feature, optional DOMString origin);
 sequence<DOMString> features();
 sequence<DOMString> allowedFeatures();
 sequence<DOMString> getAllowlistForFeature(DOMString feature);
};

partial interface Document {
 [SameObject] readonly attribute PermissionsPolicy permissionsPolicy;
};

partial interface HTMLIFrameElement {
 [SameObject] readonly attribute PermissionsPolicy permissionsPolicy;
};
```

A
[`PermissionsPolicy`](#permissionspolicy) object has an [associated node], which is a
[`Node`](https://dom.spec.whatwg.org/#node). The [associated
node](#associated-node) is set
when the
[`PermissionsPolicy`](#permissionspolicy) object is created.

A
[`PermissionsPolicy`](#permissionspolicy) object has a [default origin], which is an
[origin](https://url.spec.whatwg.org/#concept-url-origin), whose value depends on the state of the
[`PermissionsPolicy`](#permissionspolicy) object's [associated
node](#associated-node):

- If the
 [`PermissionsPolicy`](#permissionspolicy) object's [associated
 node](#associated-node) is
 a
 [`Document`](https://dom.spec.whatwg.org/#document), then its [default
 origin](#default-origin) is
 the
 [`Document`](https://dom.spec.whatwg.org/#document)'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin).

- If the
 [`PermissionsPolicy`](#permissionspolicy) object's [associated
 node](#associated-node) is
 an
 [`Element`](https://dom.spec.whatwg.org/#element), then its [default
 origin](#default-origin) is
 the
 [`Element`](https://dom.spec.whatwg.org/#element)'s [declared
 origin](#declared-origin).

Each
[`Document`](https://dom.spec.whatwg.org/#document) has a [policy object], which is a
[`PermissionsPolicy`](#permissionspolicy) instance whose [associated
node](#associated-node) is
that
[`Document`](https://dom.spec.whatwg.org/#document).

A
[`Document`](https://dom.spec.whatwg.org/#document)'s
[`permissionsPolicy`](#dom-document-permissionspolicy) IDL attribute, on getting, must return the
[`Document`](https://dom.spec.whatwg.org/#document)'s [policy
object](#document-policy-object).

Each
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element has a [policy object], which is
a
[`PermissionsPolicy`](#permissionspolicy) instance whose [associated
node](#associated-node) is
that element.

An
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)'s
[`permissionsPolicy`](#dom-htmliframeelement-permissionspolicy) IDL attribute, on getting, must return the
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)'s [policy
object](#iframe-policy-object).

The
[`allowsFeature(feature, origin)`](#dom-permissionspolicy-allowsfeature) method must run the following steps:

1. If `origin` is omitted, set `origin` to this
 [`PermissionsPolicy`](#permissionspolicy) object's [default
 origin](#default-origin).

2. Let `policy` be the [observable
 policy](#observable-policy) for this
 [`PermissionsPolicy`](#permissionspolicy) object's [associated
 node](#associated-node).

3. If `feature` is allowed by `policy` for
 `origin`, return true.

4. Otherwise, return false.

The
[`features()`](#dom-permissionspolicy-features) method must run the following steps:

1. Set `result` to an empty ordered set.

2. For each [supported
 feature](#supported-features) `feature`:

 1. Append `feature` to `result`.

3. return result

The
[`allowedFeatures()`](#dom-permissionspolicy-allowedfeatures) method must run the following steps:

1. Set `result` to an empty ordered set.

2. Let `origin` be this
 [`PermissionsPolicy`](#permissionspolicy) object's [default
 origin](#default-origin).

3. Let `policy` be the [observable
 policy](#observable-policy) for this
 [`PermissionsPolicy`](#permissionspolicy) object's [associated
 node](#associated-node).

4. For each [supported
 feature](#supported-features) `feature`:

 1. If `feature` is allowed by `policy` for
 `origin`, append `feature` to
 `result`.

5. return result

The
[`getAllowlistForFeature(feature)`](#dom-permissionspolicy-getallowlistforfeature) method must run the following steps:

1. Set `result` to an empty list.

2. Let `origin` be this
 [`PermissionsPolicy`](#permissionspolicy) object's [default
 origin](#default-origin).

3. Let `policy` be the [observable
 policy](#observable-policy) for this
 [`PermissionsPolicy`](#permissionspolicy) object's [associated
 node](#associated-node).

4. If `feature` is not allowed in `policy` for
 `origin`, return `result`

5. Let `allowlist` be `policy`'s [declared
 policy](#declared-policy)\[`feature`\]\'s
 [declarations](#declared-policy-declarations).

6. If `allowlist` is the special value `*`:

 1. Append \"`*`\" to `result`

 2. Return `result`.

7. If the [allowlist](#allowlist)'s [self-origin](#self-origin) is not null, append the
 [serialization](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin) of it to `result`.

8. If the [allowlist](#allowlist)'s [src-origin](#src-origin) is not null, append the
 [serialization](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin) of it to `result`.

9. Otherwise, for each
 [permissions-source-expression](#permissions-source-expression) `item` in `allowlist`'s
 [expressions](#expressions):

 1. Append `item` to `result`

10. Return `result`.

The [observable policy] for any Node is a [permissions
policy](#permissions-policy), which contains the information about the policy in the
navigable represented by that Node which is visible from the current
document.

To get the [observable
policy](#observable-policy)
for a Document `document`, return `document`'s
permissions policy.

To get the [observable
policy](#observable-policy)
for an Element `node`, run the following steps:

1. Let `inherited policy` be an empty [ordered
 map](https://infra.spec.whatwg.org/#ordered-map).

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) [supported
 feature](#supported-features) `feature`:

 1. Let `isInherited` be the result of running [Define an
 inherited policy for feature in container at
 origin](#define-inherited-policy-in-container) on `feature`,
 `node` and `node`'s [declared
 origin](#declared-origin).

 2. Set `inherited policy`\[`feature`\] to
 `isInherited`.

3. Return a new [permissions
 policy](#permissions-policy) with [inherited
 policy](#permissions-policy-inherited-policy) `inherited policy`, [declared
 policy](#permissions-policy-declared-policy) a
 [struct](https://infra.spec.whatwg.org/#struct) with both
 [declarations](#declared-policy-declarations) and [reporting
 configuration](#declared-policy-reporting-configuration) new [ordered
 maps](https://infra.spec.whatwg.org/#ordered-map).

To get the [declared origin] for an Element `node`, run the
following steps:

1. If `node`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s [sandboxed origin browsing context
 flag](https://html.spec.whatwg.org/multipage/browsers.html#sandboxed-origin-browsing-context-flag) is set, then return a new [opaque
 origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque).

2. If `node`'s
 [`sandbox`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-sandbox) attribute is set, and does not contain the
 `allow-same-origin` keyword, then return a new [opaque
 origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque).

3. If `node`'s
 [`srcdoc`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-srcdoc) attribute is set, then return
 `node`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s origin.

4. If `node`'s
 [`src`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-src) attribute is set:

 1. Let `url` be the result of parsing
 `node`'s src attribute, relative to
 `node`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

 2. If `url` is not failure, return `url`'s
 origin.

5. Return `node`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s origin.

The [declared origin](#declared-origin) concept is intended to represent the origin of the
document which the embedding page intends to load into a frame. This
means, for instance, that if the browser does not support the `sandbox`
or `srcdoc` attributes, it should not take those attributes into account
when computing the declared origin.

## 8. Reporting

[Permissions policy violation
reports] indicate that some behavior of the
[Document](https://dom.spec.whatwg.org/#clone-a-node-document) has [violated](#violate) a permissions policy. It is up to the specification of
each individual policy-controlled feature to define what it means to
[violate] that policy, and how to
determine when such a violation has occurred.

[Permissions policy violation
reports](#permissions-policy-violation-reports) have the [report
type](https://w3c.github.io/reporting/#report-type) \"permissions-policy-violation\".

[Permissions policy violation
reports](#permissions-policy-violation-reports) are [visible to
`ReportingObserver`s](https://w3c.github.io/reporting/#visible-to-reportingobservers).

```
[Exposed=Window]
interface PermissionsPolicyViolationReportBody : ReportBody {
 [Default] object toJSON();
 readonly attribute DOMString featureId;
 readonly attribute DOMString? sourceFile;
 readonly attribute long? lineNumber;
 readonly attribute long? columnNumber;
 readonly attribute DOMString disposition;
 readonly attribute DOMString? allowAttribute;
 readonly attribute DOMString? srcAttribute;
};
```

A [permissions policy violation
report](#permissions-policy-violation-reports)'s
[body](https://w3c.github.io/reporting/#report-body), represented in JavaScript by
[`PermissionsPolicyViolationReportBody`](#permissionspolicyviolationreportbody), contains the following fields:

- [featureId]: The string identifying the
 [policy-controlled
 feature](#policy-controlled-feature) whose policy has been
 [violated](#violate). This string
 can be used for grouping and counting related reports.

- [sourceFile]: If known, the file where the
 [violation](#violate) occured, or
 null otherwise.

- [lineNumber]: If known, the line number in
 [sourceFile](#permissionspolicyviolationreportbody-sourcefile) where the [violation](#violate) occured, or null otherwise.

- [columnNumber]: If known, the column number in
 [sourceFile](#permissionspolicyviolationreportbody-sourcefile) where the [violation](#violate) occured, or null otherwise.

- [disposition]: A string indicating whether the
 [violated](#violate) permissions
 policy was enforced in this case.
 [disposition](#permissionspolicyviolationreportbody-disposition) will be set to \"enforce\" if the policy was
 enforced, or \"report\" if the [violation](#violate) resulted only in this report being generated (with no
 further action taken by the user agent in response to the violation).

- [allowAttribute]: For reports of potential violations,
 which can be attributed to a specific
 [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element, the value of the
 [`allow`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allow) attribute of that element, or omitted
 otherwise.

- [srcAttribute]: For reports of potential violations,
 which can be attributed to a specific
 [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element, the value of the
 [`src`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-src) attribute of that element, or omitted
 otherwise.

### 8.1. \``Permissions-Policy-Report-Only`\` HTTP Header Field

The
\`[`Permissions-Policy-Report-Only`]\` HTTP header field
can be used in the
[response](https://fetch.spec.whatwg.org/#concept-response-response) (server to client) to communicate a [permissions
policy](#permissions-policy) that should not be enforced by the client, but instead
should be used to trigger reports to be sent if any policy declared
within it *would* have been violated, had the policy been active.

\`[`Permissions-Policy-Report-Only`](#permissions-policy-report-only-header)\` is a structured header. Its value must be a
dictionary.

The semantics of the dictionary are defined in [§ 5.2 Structured header
serialization](#structured-header-serialization).

The processing steps are defined in [§ 9.2 Construct policy from
dictionary and origin](#algo-construct-policy).

## 9. Algorithms

### [9.1. ][[Process response policy]]
Given a
[response](https://fetch.spec.whatwg.org/#concept-response-response) (`response`), an
[origin](https://url.spec.whatwg.org/#concept-url-origin) (`origin`), and a boolean
(`report-only`), this algorithm returns a [declared
policy](#declared-policy).

1. Let `header name` be \"`Permissions-Policy-Report-Only`\"
 if `report-only` is True, or \"`Permissions-Policy`\"
 otherwise.

2. Let `parsed header` be the result of executing [get a
 structured field
 value](https://fetch.spec.whatwg.org/#concept-header-list-get-structured-header) given `header name` and \"dictionary\"
 from `response`'s [header
 list](https://fetch.spec.whatwg.org/#concept-response-header-list).

3. If `parsed header` is null, return an empty [ordered
 map](https://infra.spec.whatwg.org/#ordered-map).

4. Let `policy` be the result of executing [Construct policy
 from dictionary and
 origin](#construct-policy) on `parsed header` and
 `origin`.

5. Return `policy`.

### [9.2. ][[Construct policy from dictionary and origin]]
Given an [ordered
map](https://infra.spec.whatwg.org/#ordered-map) (`dictionary`) and an
[origin](https://url.spec.whatwg.org/#concept-url-origin) (`origin`), this algorithm will return a
[declared policy](#declared-policy).

1. Let `declarations` be an empty [ordered
 map](https://infra.spec.whatwg.org/#ordered-map).

2. Let `reporting-config` be an empty [ordered
 map](https://infra.spec.whatwg.org/#ordered-map).

3. [For
 each](https://infra.spec.whatwg.org/#map-iterate) `feature-name` → (`value`,
 `params`) of `dictionary`:

 1. If `feature-name` does not identify any recognized
 [policy-controlled
 feature](#policy-controlled-feature), then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. Let `feature` be the [policy-controlled
 feature](#policy-controlled-feature) identified by `feature-name`.

 3. If `params`\[\"report-to\"\] exists, and is a
 [token](https://datatracker.ietf.org/doc/html/rfc8941#token), then set
 `reporting-config`\[`feature`\] to
 `params`\[\"report-to\"\].

 4. Let `allowlist` be a new
 [allowlist](#allowlist).

 5. If `value` is the
 [token](https://datatracker.ietf.org/doc/html/rfc8941#token) `*`, or if `value` is a list which
 contains the
 [token](https://datatracker.ietf.org/doc/html/rfc8941#token) `*`, set `allowlist` to [the special
 value `*`](#the-special-value).

 6. Otherwise:

 1. If `value` is the
 [token](https://datatracker.ietf.org/doc/html/rfc8941#token) `self`, let `allowlist`'s
 [self-origin](#self-origin) be `origin`.

 2. Otherwise if `value` is a
 [list](https://infra.spec.whatwg.org/#list), then [for
 each](https://infra.spec.whatwg.org/#list-iterate) `element` in `value`:

 1. If `element` is the
 [token](https://datatracker.ietf.org/doc/html/rfc8941#token) `self`, let `allowlist`'s
 [self-origin](#self-origin) be `origin`.

 2. If `element` is a valid
 [permissions-source-expression](#permissions-source-expression),
 [append](https://infra.spec.whatwg.org/#list-append) `element` to
 `allowlist`'s
 [expressions](#expressions).

 7. Set `declarations`\[`feature`\] to
 `allowlist`.

4. Return «`declarations`, `reporting-config`».

### [9.3. ][[Parse policy directive]]
Given a string (`value`), an
[origin](https://url.spec.whatwg.org/#concept-url-origin) (`container origin`), and an optional
[origin](https://url.spec.whatwg.org/#concept-url-origin) (`target origin`), this algorithm returns a
[policy directive](#policy-directive).

1. Let `directive` be an empty [ordered
 map](https://infra.spec.whatwg.org/#ordered-map).

2. For each `serialized-declaration` returned by [strictly
 splitting `value` on the delimiter U+003B
 (;)](https://infra.spec.whatwg.org/#strictly-split):

 1. Let `tokens` be the result of [splitting
 `serialized-declaration` on ASCII
 whitespace.](https://infra.spec.whatwg.org/#split-on-ascii-whitespace)

 2. If `tokens` is an empty list, then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. Let `feature-name` be the first element of
 `tokens`.

 4. If `feature-name` does not identify any recognized
 [policy-controlled
 feature](#policy-controlled-feature), then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 5. Let `feature` be the [policy-controlled
 feature](#policy-controlled-feature) identified by `feature-name`.

 6. If `directive`\[`feature`\]
 [exists](https://infra.spec.whatwg.org/#map-exists), then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 7. Let `targetlist` be the remaining elements, if any,
 of `tokens`.

 8. Let `allowlist` be a new
 [allowlist](#allowlist).

 9. If any element of `targetlist` is the string \"`*`\",
 set `allowlist` to [the special value
 `*`](#the-special-value).

 10. Otherwise:

 1. If `targetlist` is empty and
 `target origin` is given, let
 `allowlist`'s
 [src-origin](#src-origin) be `target origin`.

 2. For each `element` in `targetlist`:

 1. If `element` is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"`'self'`\":

 1. Let `allowlist`'s
 [self-origin](#self-origin) be `container origin`.

 2. Continue to the next `element`.

 2. If `target origin` is given, and
 `element` is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"`'src'`\":

 1. Let `allowlist`'s
 [src-origin](#src-origin) be `target origin`.

 2. Continue to the next `element`.

 3. Let `result` be the result of executing the
 [URL
 parser](https://url.spec.whatwg.org/#concept-url-parser) on `element`.

 4. If `result` is failure, then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 5. If `result`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is \"`blob`\", `result`'s
 [username](https://url.spec.whatwg.org/#concept-url-username) is not the empty string, or
 `result`'s
 [password](https://url.spec.whatwg.org/#concept-url-password) is not the empty string, then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 6. Let `origin` be the
 [origin](https://url.spec.whatwg.org/#concept-url-origin) of `result`.

 7. If `origin` is not an [opaque
 origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque),
 [append](https://infra.spec.whatwg.org/#list-append) the
 [serialization](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin) of `origin` to
 `allowlist`'s
 [expressions](#expressions).

 11. Set `directive`\[`feature`\] to
 `allowlist`.

3. Return `directive`

### [9.4. ][[Process permissions policy attributes]]
Given an element (`element`), this algorithm returns a
[container policy](#container-policy), which may be empty.

1. If `element` is not an
 [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element, then return an empty [policy
 directive](#policy-directive).

2. Let `container policy` be the result of running [Parse
 policy
 directive](#parse-policy-directive) given the value of `element`'s
 [`allow`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allow) attribute, the
 [origin](https://dom.spec.whatwg.org/#concept-document-origin) of `element`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document), and `element`'s [declared
 origin](#declared-origin).

3. If `element`'s
 [`allowfullscreen`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allowfullscreen) attribute is specified, and
 `container policy` does not
 [contain](https://infra.spec.whatwg.org/#map-exists) an entry for the `fullscreen`
 [feature](#policy-controlled-feature).

 1. [Set](https://infra.spec.whatwg.org/#map-set) `container policy`\[`fullscreen`\] =
 [the special value
 `*`](#the-special-value).

4. Return `container policy`.

### [9.5. ][[Create a Permissions Policy for a navigable]]
Given null or an
[element](https://dom.spec.whatwg.org/#concept-element) (`container`) and an
[origin](https://url.spec.whatwg.org/#concept-url-origin) (`origin`) this algorithm returns a new
[Permissions Policy](#permissions-policy).

1. Assert: If not null, `container` is a [navigable
 container](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable-container).

2. Let `inherited policy` be a new [ordered
 map](https://infra.spec.whatwg.org/#ordered-map).

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `feature`
 [supported](#supported-features),

 1. Let `isInherited` be the result of running [Define an
 inherited policy for feature in container at
 origin](#define-inherited-policy-in-container) on `feature`,
 `container` and `origin`.

 2. Set `inherited policy`\[`feature`\] to
 `isInherited`.

4. Let `policy` be a new [permissions
 policy](#permissions-policy), with [inherited
 policy](#permissions-policy-inherited-policy) `inherited policy` and [declared
 policy](#permissions-policy-declared-policy) «\[\], \[\]».

5. Return `policy`.

### [9.6. ][[Create a Permissions Policy for a navigable from response]]
Given null or a [navigable
container](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable-container) (`container`), an
[origin](https://url.spec.whatwg.org/#concept-url-origin) (`origin`), a
[response](https://fetch.spec.whatwg.org/#concept-response-response) (`response`), and an optional boolean
(`report-only`), with a default value of False, this
algorithm returns a new [permissions
policy](#permissions-policy).

1. Let `policy` be the result of running [Create a
 Permissions Policy for a
 navigable](#create-for-navigable) given `container` and
 `origin`.

2. Let `d` be the result of running [Process response
 policy](#process-response-policy) given `response`,
 `origin` and `report-only`.

3. For each `feature` → `allowlist` of
 `d`'s
 [declarations](#declared-policy-declarations):

 1. If `policy`'s [inherited
 policy](#permissions-policy-inherited-policy)\[`feature`\] is true, then set
 `policy`'s [declared
 policy](#permissions-policy-declared-policy)'s
 [declarations](#declared-policy-declarations)\[`feature`\] to
 `allowlist`.

4. Set `policy`'s [declared
 policy](#permissions-policy-declared-policy)\[`feature`\]\'s [reporting
 configuration](#declared-policy-reporting-configuration) to `d`'s [reporting
 configuration](#declared-policy-reporting-configuration).

5. Return `policy`.

### [9.7. ][[Define an inherited policy for feature in container at origin]]
Given a
[feature](#policy-controlled-feature) (`feature`), null or a [navigable
container](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable-container) (`container`), an
[origin](https://dom.spec.whatwg.org/#concept-document-origin) for a
[`Document`](https://dom.spec.whatwg.org/#document) in that container (`origin`), and an
optional boolean (`report-only`), with a default value of
False, this algorithm returns the [inherited policy
value](#inherited-policy-for-a-feature) for `feature`.

1. If `container` is null, return \"`Enabled`\".

2. If the result of executing [Get feature value for
 origin](#get-feature-value-for-origin) on `feature`,
 `container`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document), `container`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s origin, and `report-only` is
 \"`Disabled`\", return \"`Disabled`\".

3. If the result of executing [Get feature value for
 origin](#get-feature-value-for-origin) on `feature`,
 `container`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document), `origin`, and `report-only`
 is \"`Disabled`\", return \"`Disabled`\".

4. Let `container policy` be the result of running [Process
 permissions policy
 attributes](#process-policy-attributes) on `container`.

5. If `feature`
 [exists](https://infra.spec.whatwg.org/#map-exists) in `container policy`:

 1. If the [allowlist](#allowlist) for `feature` in
 `container policy`
 [matches](#matches)
 `origin`, return \"`Enabled`\".

 2. Otherwise return \"`Disabled`\".

6. If `feature`'s [default
 allowlist](#policy-controlled-feature-default-allowlist) is `*`, return \"`Enabled`\".

7. If `feature`'s [default
 allowlist](#policy-controlled-feature-default-allowlist) is `'self'`, and `origin` is [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) with `container`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s
 [origin](https://dom.spec.whatwg.org/#concept-document-origin), return \"`Enabled`\".

8. Otherwise return \"`Disabled`\".

### [9.8. ][[Get feature value for origin]]
Given a
[feature](#policy-controlled-feature) (`feature`), a
[`Document`](https://dom.spec.whatwg.org/#document) object (`document`), an
[origin](https://url.spec.whatwg.org/#concept-url-origin) (`origin`), and a boolean
(`report-only`), this algorithm returns \"`Disabled`\" if
`feature` should be considered disabled, and \"`Enabled`\"
otherwise.

1. Let `policy` be `document`'s [report-only
 permissions
 policy](#document-report-only-permissions-policy) if `report-only` is True, or
 `document`'s [permissions
 policy](https://html.spec.whatwg.org/multipage/dom.html#concept-document-permissions-policy) otherwise.

2. If `policy`'s [inherited
 policy](#permissions-policy-inherited-policy) for `feature` is \"`Disabled`\", return
 \"`Disabled`\".

3. If `feature` is present in `policy`'s
 [declared
 policy](#permissions-policy-declared-policy):

 1. If `policy`'s [declared
 policy](#permissions-policy-declared-policy)'s
 [declarations](#declared-policy-declarations)\[`feature`\]
 [matches](#matches)
 `origin`, then return \"`Enabled`\".

 2. Otherwise return \"`Disabled`\".

4. Return \"`Enabled`\".

### [9.9. ][[Check permissions policy]]
To check a permissions policy, given [permissions
policy](#permissions-policy) (`policy`), a
[feature](#policy-controlled-feature) (`feature`), an
[origin](https://url.spec.whatwg.org/#concept-url-origin) (`origin`) and another
[origin](https://url.spec.whatwg.org/#concept-url-origin) (`document origin`), this algorithm returns
\"`Disabled`\" if `feature` should be considered disabled,
and \"`Enabled`\" otherwise.

1. If `policy`'s [inherited
 policy](#permissions-policy-inherited-policy) for `feature` is \"`Disabled`\", return
 \"`Disabled`\".

2. If `feature` is present in `policy`'s
 [declared
 policy](#permissions-policy-declared-policy):

 1. If `policy`'s [declared
 policy](#permissions-policy-declared-policy)'s
 [declarations](#declared-policy-declarations)\[`feature`\]
 [matches](#matches)
 `origin`, then return \"`Enabled`\".

 2. Otherwise return \"`Disabled`\".

3. If `feature`'s [default
 allowlist](#policy-controlled-feature-default-allowlist) is `*`, return \"`Enabled`\".

4. If `feature`'s [default
 allowlist](#policy-controlled-feature-default-allowlist) is `'self'`, and `origin` is [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) with `document origin`, return
 \"`Enabled`\".

5. Return \"`Disabled`\".

### [9.10. ][[Is feature enabled in document for origin?]]
Given a
[feature](#policy-controlled-feature) (`feature`), a
[`Document`](https://dom.spec.whatwg.org/#document) object (`document`), an
[origin](https://url.spec.whatwg.org/#concept-url-origin) (`origin`), and an optional boolean
(`report`), with a default value of True, this algorithm
returns \"`Disabled`\" if `feature` should be considered
disabled, and \"`Enabled`\" otherwise. If `report` is True,
then it will also [generate and queue a
report](https://w3c.github.io/reporting/#generate-and-queue-a-report) if the feature is not enabled in either
`document`'s [permissions
policy](https://html.spec.whatwg.org/multipage/dom.html#concept-document-permissions-policy) or `document`'s [report-only permissions
policy](#document-report-only-permissions-policy).

 The default value of True for `report` means
that most permissions policy checks will generate a violation report if
the feature is not enabled. This is the expected result, as most checks
are for an actual attempted use of the feature. If a call to this
algorithm is performed just to query the state of a feature, and does
not represent an actual attempt to use the feature, then
`report` should be set to False.

1. Let `policy` be `document`'s [permissions
 policy](https://html.spec.whatwg.org/multipage/dom.html#concept-document-permissions-policy).

2. Let `report-only policy` be `document`'s
 [report-only permissions
 policy](#document-report-only-permissions-policy).

3. Let `result` be the result of calling [Check permissions
 policy](#check-permissions-policy), given `policy`,
 `feature`, `origin`, and
 `document`'s
 [origin](https://dom.spec.whatwg.org/#concept-document-origin).

4. Let `report-only result` be the result of calling [Check
 permissions
 policy](#check-permissions-policy), given `report-only policy`,
 `feature`, `origin`, and
 `document`'s
 [origin](https://dom.spec.whatwg.org/#concept-document-origin).

5. If `report` is True:

 1. Let `settings` be `document`'s
 [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object).

 2. If `result` is \"`Disabled`\":

 1. Let `endpoint` be the result of calling [Get the
 reporting endpoint for a
 feature](#get-reporting-endpoint) given `feature` and
 `policy`.

 2. Call [Generate report for violation of permissions policy on
 settings](#report-permissions-policy-violation) given `feature`,
 `settings`, \"`Enforce`\", and
 `endpoint`.

 3. Else, if `report-only result` is \"`Disabled`\":

 1. Let `report-only endpoint` be the result of
 calling [Get the reporting endpoint for a
 feature](#get-reporting-endpoint) given `feature` and
 `report-only policy`.

 2. Call [Generate report for violation of permissions policy on
 settings](#report-permissions-policy-violation) given `feature`,
 `settings`, \"`Report`\", and
 `report-only endpoint`.

6. Return result

### [9.11. ][[Get the reporting endpoint for a feature]]
Given a
[feature](#policy-controlled-feature) (`feature`) and a [permissions
policy](#permissions-policy) (`policy`), this algorithm returns a string
naming the endpoint to send violation reports to, or null if no such
endpoint has been declared in `policy`.

1. Let `config` be `policy`'s [declared
 policy](#permissions-policy-declared-policy)'s [reporting
 configuration](#declared-policy-reporting-configuration).

2. If `config`\[`feature`\] exists, return
 `config`\[`feature`\].

3. Return null.

### [9.12. ][[Check potential violation of permissions policy in container]]
Given a [navigable
container](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable-container) (`container`), a string-or-null
(`allowAttribute`), and a string-or-null
(`srcAttribute`), this algorithm sends potential violation
reports.

1. Let `document` be `container`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

2. Let `settings` be `document`'s [environment
 settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object).

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) [supported
 feature](#supported-features) `feature`:

 1. If the result of running [Define an inherited policy for feature
 in container at
 origin](#define-inherited-policy-in-container) on `feature`,
 `container` and `container`'s [declared
 origin](#declared-origin) is \"`Disabled`\":

 1. Let `endpoint` be the result of calling [Get the
 reporting endpoint for a
 feature](#get-reporting-endpoint) given `feature` and
 `document`'s [permissions
 policy](https://html.spec.whatwg.org/multipage/dom.html#concept-document-permissions-policy).

 2. Call [Generate report for potential violation of permissions
 policy on
 settings](#report-potential-permissions-policy-violation) given `feature`,
 `settings`, \"`Enforce`\", `endpoint`,
 `allowAttribute`, and `srcAttribute`.

 2. Else, if the result of running [Define an inherited policy for
 feature in container at
 origin](#define-inherited-policy-in-container) on `feature`,
 `container`, `container`'s [declared
 origin](#declared-origin) and True is \"`Disabled`\":

 1. Let `report-only endpoint` be the result of
 calling [Get the reporting endpoint for a
 feature](#get-reporting-endpoint) given `feature` and
 `document`'s [report-only permissions
 policy](#document-report-only-permissions-policy).

 2. Call [Generate report for potential violation of permissions
 policy on
 settings](#report-potential-permissions-policy-violation) given `feature`,
 `settings`, \"`Report`\",
 `report-only endpoint`,
 `allowAttribute`, and `srcAttribute`.

### [9.13. ][[Generate report for violation of permissions policy on settings]]
Given a
[feature](#policy-controlled-feature) (`feature`), an [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) (`settings`), a string
(`disposition`), and a string-or-null
(`endpoint`), this algorithm generates a
[report](https://w3c.github.io/reporting/#report) about the [violation](#violate) of the policy for `feature`.

1. Let `body` be a new
 [`PermissionsPolicyViolationReportBody`](#permissionspolicyviolationreportbody), initialized as follows:

 [featureId](#permissionspolicyviolationreportbody-featureid)

 : `feature`'s string representation.

 [sourceFile](#permissionspolicyviolationreportbody-sourcefile)

 : null

 [lineNumber](#permissionspolicyviolationreportbody-linenumber)

 : null

 [columnNumber](#permissionspolicyviolationreportbody-columnnumber)

 : null

 [disposition](#permissionspolicyviolationreportbody-disposition)

 : `disposition`

2. If the user agent is currently executing script, and can extract the
 source file's URL, line number, and column number from
 `settings`, then set `body`'s
 [sourceFile](#permissionspolicyviolationreportbody-sourcefile),
 [lineNumber](#permissionspolicyviolationreportbody-linenumber), and
 [columnNumber](#permissionspolicyviolationreportbody-columnnumber) accordingly.

3. Execute [generate and queue a
 report](https://w3c.github.io/reporting/#generate-and-queue-a-report) with `body`,
 \"permissions-policy-violation\", `endpoint`, and
 `settings`.

### [9.14. ][[Generate report for potential violation of permissions policy on settings]]
Given a
[feature](#policy-controlled-feature) (`feature`), an [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) (`settings`), a string
(`disposition`), a string-or-null (`endpoint`), a
string-or-null (`allowAttribute`), and a string-or-null
(`srcAttribute`), this algorithm generates a
[report](https://w3c.github.io/reporting/#report) about the [violation](#violate) of the policy for `feature`.

1. Let `body` be a new
 [`PermissionsPolicyViolationReportBody`](#permissionspolicyviolationreportbody), initialized as follows:

 [featureId](#permissionspolicyviolationreportbody-featureid)

 : `feature`'s string representation.

 [sourceFile](#permissionspolicyviolationreportbody-sourcefile)

 : null

 [lineNumber](#permissionspolicyviolationreportbody-linenumber)

 : null

 [columnNumber](#permissionspolicyviolationreportbody-columnnumber)

 : null

 [disposition](#permissionspolicyviolationreportbody-disposition)

 : `disposition`

 [allowAttribute](#permissionspolicyviolationreportbody-allowattribute)

 : `allowAttribute`

 [srcAttribute](#permissionspolicyviolationreportbody-srcattribute)

 : `srcAttribute`

2. If the user agent is currently executing script, and can extract the
 source file's URL, line number, and column number from
 `settings`, then set `body`'s
 [sourceFile](#permissionspolicyviolationreportbody-sourcefile),
 [lineNumber](#permissionspolicyviolationreportbody-linenumber), and
 [columnNumber](#permissionspolicyviolationreportbody-columnnumber) accordingly.

3. Execute [generate and queue a
 report](https://w3c.github.io/reporting/#generate-and-queue-a-report) with `body`,
 \"potential-permissions-policy-violation\", `endpoint`,
 and `settings`.

### [9.15. ][[Should request be allowed to use feature?]]
Given a
[feature](#policy-controlled-feature) (`feature`) and a
[request](https://fetch.spec.whatwg.org/#concept-request) (`request`), this algorithm returns `true`
if the request should be allowed to use `feature`, and
`false` otherwise.

1. Let `client` be `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client).

2. If `client` is null, return `false`.

3. If `client`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global) is not a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window), return `false`.

 :::
 (#issue-154a63d1)Permissions Policy within non-Window
 contexts
 ([`WorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope) or
 [`WorkletGlobalScope`](https://html.spec.whatwg.org/multipage/worklets.html#workletglobalscope)) is being figured out in [issue
 #207](https://github.com/w3c/webappsec-permissions-policy/issues/207).
 After that's resolved, update this algorithm to allow fetches
 initiated within these contexts to use policy-controlled features.
 *Until* that's resolved, disallow all policy-controlled features
 (e.g., sending Client Hints to third parties) in these contexts.
 :::

4. Set `document` to `client`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global)'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

5. Let `origin` be `request`'s
 [origin](https://fetch.spec.whatwg.org/#concept-request-origin).

6. Let `result` be the result of executing [Is feature
 enabled in document for
 origin?](#is-feature-enabled) on `feature`,
 `document`, and `origin`.

7. If `result` is \"`Enabled`\", return `true`.

8. Otherwise, return `false`.

## 10. Changes to other specifications

### 10.1. Changes to the HTML specification

Every
[`Document`](https://dom.spec.whatwg.org/#document) has a [report-only permissions
policy], which is a [permissions
policy](#permissions-policy), which is initially empty.

In [7.5.1 Shared document creation
infrastructure](https://html.spec.whatwg.org/#shared-document-creation-infrastructure),
after step 3, insert the following step:

4. Let `reportOnlyPermissionsPolicy` be the result of
 calling [Create a Permissions Policy for a navigable from
 response](#create-from-response) given navigationParams's navigable's
 container, navigationParams's origin, navigationParams's response,
 and True.

And in the same section, in step 10, set the new
[`Document`](https://dom.spec.whatwg.org/#document)'s [report-only permissions
policy](#document-report-only-permissions-policy) to `reportOnlyPermissionsPolicy`.

In [iframe load event
steps](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#iframe-load-event-steps),
after step 6, insert the following step:

7. Call [Check potential violation of permissions policy in
 container](#check-potential-violation-in-container) given `element`,
 `element`'s allow attribute, and `element`'s
 src attribute.

## 11. IANA Considerations

The permanent message header field registry should be updated with the
following registration
[\[RFC3864\]](#biblio-rfc3864 "Registration Procedures for Message Header Fields"):

Header field name
: Permissions-Policy

Applicable protocol
: http

Status
: standard

Author/Change controller
: W3C

Specification document
: https://www.w3.org/TR/permissions-policy/

## 12. Privacy and Security

This specification standardizes a mechanism for an embedding page to set
a policy which will be enforced on an embedded page. Similar to iframe
[`sandbox`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-sandbox), this can be done without the express
permission of the embedded page, which means that behaviors of existing
features can be changed in published web sites, by embedding them in
another document with an appropriate container policy.

As such, the biggest privacy and security concerns are:

- Exposure of behavior in a cross-origin subframe to its embedder
- Unanticipated behavior changes in subframes controlled by the embedder

To a degree, these concerns are already present in the web platform, and
this specification attempts to at least not make them needlessly worse.

Security and privacy issues may also be caused by the design of
individual features, so care must be taken when integrating with this
specification. This section attempts to provide some guidance as to what
kinds of behaviors could cause such issues.

### 12.1. Exposure of cross-origin behavior

Features should be designed such that a
[violation](#violate) of the policy
in a framed document is not observable by documents in other frames. For
instance, a hypothetical feature which caused a event to be fired in the
embedding document if it is used while disabled by policy, could be used
to extract information about the state of an embedded document. If the
feature is known only to be used while a user is logged in to the site,
for instance, then the embedder could disable that feature for the
frame, and then listen for the resulting events to determine whether or
not the user is logged in.

The introspection API is designed to only show information about a
subframe's policy which could already be deduced by the embedding
document. This [observable
policy](#observable-policy)
is not affected by any HTTP headers delivered with the framed document,
and does not change when the frame navigates itself, even if such
navigation is to a different origin, where a different policy applies.
Only navigations caused by setting the `src` attribute of the `<iframe>`
element will cause the [observable
policy](#observable-policy)
to be updated.

### 12.2. Unanticipated behavior changes

The Permissions Policy mechanism grants a document the ability to
control which features will and will not be availble in a subframe at
the time it is loaded. When a feature represents an existing,
long-standing behavior of the web platform, this may mean that existing
published content on the web was not written with the expectation that a
particular API could fail.

As a practical (though contrived) example, consider a document which
uses synchronous XMLHttpRequest to determine whether a user has
sufficient privileges to access the page:

 <!DOCTYPE html>
 <h1>Welcome to SecureCorp!</h1>
 <script>
 var req = new XMLHttpRequest();
 req.open("GET", "/api/security_check.json", false);
 req.send();
 if (req.response == "untrusted user") {
 // User is not logged in; redirect to a safe page
 location.href = "/security_check_failed.html";
 }
 </script>
 <!-- Page continues with assumption that user is logged in -->

If this document is embedded by a page which disables the \"`sync-xhr`\"
feature, the call to `XMLHttpRequest.open()` would fail, and the
security check would be bypassed.

Note that this sort of behavior forcing is already possible on the web:
some features are only allowed in top-level documents, and not in any
iframes, and iframe sandboxing can be used in a similar way to embed a
frame without access to features which it may be depending on.

In general, this concern is mitigated in two ways:

- The vulnerable page may be served with an `X-Frame-Options` HTTP
 header which does not allow it to be framed by an attacker.
- Sites should use feature detection to determine whether an API or
 behavior is available before attempting to use it, and should handle
 any documented errors returned or exceptions thrown by the APIs they
 call.
- In the case where feature detection is not possible, new web content
 can be written to use the `policy` object to inspect the permissions
 policy which is currently enforced, and adjust behaviour or user
 interface accordingly.

Authors integrating their features with Permissions Policy can decide
when and how the feature will fail when a document attempts to use it
while it is disabled. Authors should attempt to make use of existing
failure modes, when they exist, to increase the chance that existing
content will already be correctly handling such failures.

### 12.3. Exposure of embedding policy

Care has been taken to limit the information which an page can infer
about the behavior of cross-origin pages which it embeds. It may be
possible in some scenarios however, for the embedded page to infer
information about its embedder, by examining the policy which the
embedder has enforced on it.

This is similar to the existing `document.fullscreenEnabled` property,
which can be used by the embedded document to infer whether its embedder
has granted it the ability to use the Fullscreen API. If this is only
granted in certain cases --- when the user is logged in to the embedding
site, for instance --- then the embedded site can learn something about
the state of its embedder.

## 13. Change log

### 13.1. Changes since FPWD

- Expose new algorithms to create a Feature Policy before document is
 created.
 [Link](https://github.com/w3c/webappsec-permissions-policy/pull/324)

- Remove algorithms no longer needed.
 [Link](https://github.com/w3c/webappsec-permissions-policy/pull/325)

- Change same-origin-domain check to same-origin.
 [Link](https://github.com/w3c/webappsec-permissions-policy/pull/326)

- Change Header and attribute combination from OR to AND semantics.
 [Link](https://github.com/w3c/webappsec-permissions-policy/pull/378)

- Rename to \"Permissions Policy\".
 [Link](https://github.com/w3c/webappsec-permissions-policy/pull/379)

- Define \"Permissions-Policy\" as a structured header.
 [Link](https://github.com/w3c/webappsec-permissions-policy/pull/383)

- Editorial fixes.

- The `allowpaymentrequest` attribute was removed due to deprecation by
 Payment Request API and HTML.
 [Link](https://github.com/w3c/webappsec-feature-policy/pull/)
