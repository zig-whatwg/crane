
## 1. Introduction

*This section is not normative.*

When a user successfully loads a webpage from `example.com` over a
secure channel (HTTPS, for example), the user is guaranteed that no
entity between the user agent and `example.com` eavesdropped on or
tampered with the data transmitted between them. However, this guarantee
is weakened if the webpage loads subresources such as script or images
over an insecure connection. For example, an insecurely-loaded script
can allow an attacker to read or modify data on behalf of the user. An
insecurely-loaded image can allow an attacker to communicate incorrect
information to the user (e.g., a fabricated stock chart), mutate
client-side state (e.g., set a cookie), or induce the user to take an
unintended action (e.g., changing the label on a button). These requests
are known as mixed content.

[\[mixed-content\]](#biblio-mixed-content) details
how a user agent can mitigate these risks by blocking certain types of
mixed content, and behaving more strictly in some contexts.

However, as implemented in today's web browsers,
[\[mixed-content\]](#biblio-mixed-content) does not
fully protect the confidentiality and integrity of users\' data.
Insecure content such as images, audio, and video can currently be
loaded by default in secure contexts. Secure pages can even initiate
insecure downloads which escape the user agent's sandbox entirely.

Moreover, users do not have a clear security indicator when mixed
content is loaded. When a webpage loads mixed content, browsers display
an \"in-between\" security indicator (such as removing the padlock
icon), which does not give users a clear indication of whether they
should trust the page. This UX has also not proved a sufficient
incentive for developers to avoid mixed content, since it is still
common for webpages to load mixed content. Blocking all mixed content
would provide the user with a simpler mental model \-- the webpage is
either loaded over a secure transport or it isn't \-- and encourage
developers to securely load any mixed content that is necessary for
their webpage to function properly.

Mixed Content Level 2 therefore updates and extends
[\[mixed-content\]](#biblio-mixed-content) to
provide users with better security and privacy guarantees and a better
security UX, while minimizing breakage. Instead of advising browsers to
simply strictly block all mixed content, the core idea of Level 2 is
*mixed content autoupgrading*. That is, mixed content that user agents
are not already blocking should be autoupgraded to a secure transport.
If the request cannot be autoupgraded, it will be blocked. Autoupgrading
avoids loading insecure resources on secure webpages, while minimizing
the amount of developer effort needed to avoid breakage.

This specification (Level 2) only recommends autoupgrading types of
mixed content subresources that are not currently blocked by default,
and does not recommend autougprading types of content that are already
blocked. This is to minimize the amount of web-visible change; we only
want to autoupgrade content if it advances us towards the goal of
blocking all mixed content by default.

This specification also explicitly introduces the concept of *mixed
downloads*. A mixed download is a resource that a user agent handles as
a download, which was initiated by a secure context but is downloaded
over an insecure connection. User agents should block mixed downloads
because they can escape the user agent's sandbox (in the case of an
executable) or contain sensitive information (e.g., a downloaded bank
statement). This is especially misleading because user agents typically
indicates to the user that they are on a secure page while initiating
and completing a mixed download.

## 2. Key Concepts and Terminology

[mixed content]

: A
 [request](https://fetch.spec.whatwg.org/#concept-request) is **mixed content** if its
 [url](https://fetch.spec.whatwg.org/#concept-request-url) is not [*a priori*
 authenticated](#a-priori-authenticated-url), **and** the context responsible for loading it
 prohibits mixed security contexts (see [§ 4.3 Does settings prohibit
 mixed security contexts?](#categorize-settings-object) for a
 normative definition of the latter).

 A
 [response](https://fetch.spec.whatwg.org/#concept-response) is **mixed content** if it is an [unauthenticated
 response](#unauthenticated-response), **and** the context responsible for loading it
 requires prohibits mixed security contexts.

 :::
 (#example-14c50224) Inside a context that restricts
 mixed content (`https://secure.example.com/`, for example):
 1. A request for the script `http://example.com/script.js` is
 **mixed content**. As script
 [requests](https://fetch.spec.whatwg.org/#concept-request) are
 [blockable](#blockable-mixed-content), the user agent will return a network error
 rather than loading the resource.

 2. A request for the image `http://example.com/image.png` is
 **mixed content**. As image
 [requests](https://fetch.spec.whatwg.org/#concept-request) are
 [upgradeable](#upgradeable-mixed-content), the user agent might rewrite the URL as
 `http://example.com/image.png`, otherwise it will block the
 load.
 :::

 Note: \"Mixed content\" was originally defined in [section
 5.3](https://www.w3.org/TR/wsc-ui/#securepage) of
 [\[WSC-UI\]](#biblio-wsc-ui). This document
 updates that initial definition.

 Note: [\[XML\]](#biblio-xml) also defines an
 unrelated [\"mixed
 content\"](https://www.w3.org/TR/2008/REC-xml-20081126/#sec-mixed-content).
 concept. This is potentially confusing, but given the term's near
 ubiquitious usage in a security context across user agents for more
 than a decade, the practical risk of confusion seems low.

[ *a priori* authenticated URL ]
: We know *a priori* that a request to a particular URL
 (`url`) will be delivered in a way that mitigates the
 risks of interception and modifications if either of the following
 statements is true:
 1. `url` is a [potentially trustworthy
 URL](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-url)
 [\[SECURE-CONTEXTS\]](#biblio-secure-contexts).

 2. `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is \"`data`\".

 Note: We special case `data` URLs here, as we don't consider
 them particularly trustworthy, but we also don't wish to block
 them as mixed content, as they never hit the network.

[ unauthenticated response ]
: We know *a posteriori* that a
 [response](https://fetch.spec.whatwg.org/#concept-response) (`response`) is unauthenticated if
 `response`'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url) is not [*a priori*
 authenticated](#a-priori-authenticated-url).

[embedding document]
: Given a
 [`Document`](https://dom.spec.whatwg.org/#document) `A`, the **embedding document** of
 `A` is `A`'s [browsing
 context](https://html.spec.whatwg.org/multipage/browsers.html#browsing-context)\'s [container
 document](https://html.spec.whatwg.org/multipage/browsers.html#bc-container-document) [\[HTML\]](#biblio-html).

[mixed download(#mixed-download)]
: A mixed download is a resource that a user agent handles as a
 download, which was initiated by a secure context but is downloaded
 over an insecure connection.

## 3. Content Categories

In a perfect world, each user agent would be required to block all
[mixed content](#mixed-content)
without exception. Unfortunately, that is impractical on today's
Internet; a user agent needs to be more nuanced in its restrictions to
avoid degrading the experience on a substantial number of websites.

With that in mind, we here split mixed content into two categories:
[§ 3.1 Upgradeable Content](#category-upgradeable) and [§ 3.2 Blockable
Content](#category-blockable).

### 3.1. Upgradeable Content

Upgradeable content was previously referred as optionally-blockable in
[\[mixed-content\]](#biblio-mixed-content)

Mixed content is [upgradeable] when the risk of allowing its usage as
[mixed content](#mixed-content)
is outweighed by the risk of breaking significant portions of the web.
This could be because mixed usage of the resource type is sufficiently
high, and because the resource is low-risk in and of itself. The fact
that these resource types are upgradeable does not mean that they are
*safe*, simply that they're less catastrophically dangerous than other
resource types. For example, images and icons are often the central UI
elements in an application's interface. If an attacker reversed the
\"Delete email\" and \"Reply\" icons, there would be real impact to
users.

This category includes:

- Requests whose
 [initiator](https://fetch.spec.whatwg.org/#concept-request-initiator) is the empty string, and whose
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination) is \"`image`\".

 Note: This corresponds to most images loaded via
 [`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element) (including SVG documents loaded as images, as
 those are blocked from executing script or fetching subresources) and
 CSS
 ([background-image](https://www.w3.org/TR/css3-background/#propdef-background-image),
 [border-image](https://www.w3.org/TR/css3-background/#propdef-border-image), etc). It does not include
 [`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element) elements that [use srcset or
 picture](https://html.spec.whatwg.org/multipage/images.html#use-srcset-or-picture).

- Requests whose
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination) is \"`video`\".

 Note: This corresponds to video loaded via
 [`video`](https://html.spec.whatwg.org/multipage/media.html#video) and
 [`source`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-source-element).

- Requests whose
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination) is \"`audio`\".

 Note: This corresponds to audio loaded via
 [`audio`](https://html.spec.whatwg.org/multipage/media.html#audio) and
 [`source`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-source-element).

We further limit this category in [§ 4.4 Should fetching request be
blocked as mixed content?](#should-block-fetch) by force-failing any
CORS-enabled request. This means, for example, that mixed content images
loaded via `<img crossorigin ...>` will be blocked. This is a good
example of the general principle that content falls into this category
*only* when it is too widely used to be blocked outright. The Working
Group intends to carve out more blockable subsets as time goes on.

### 3.2. Blockable Content

Any mixed content that is not
[upgradeable](#upgradeable-mixed-content) as defined above is considered to be
[blockable]. Typical
examples of this kind of content include scripts,
[plugin](https://html.spec.whatwg.org/multipage/infrastructure.html#plugin) data, data requested via
[`XMLHttpRequest`](https://xhr.spec.whatwg.org/#xmlhttprequest), and so on.

Note: [Navigation
requests](https://fetch.spec.whatwg.org/#navigation-request) might target [top-level browsing
contexts](https://html.spec.whatwg.org/multipage/browsers.html#top-level-browsing-context); these are not considered mixed content. See [§ 4.4
Should fetching request be blocked as mixed
content?](#should-block-fetch) for details.

Note: Note that requests made on behalf of a plugin are blockable. We
recognize, however, that user agents aren't always in a position to
mediate these requests. NPAPI plugins, for instance, often have direct
network access, and can generally bypass the user agent entirely. We
recommend that user agents block these requests when possible, and that
plugin vendors implement mixed content checking themselves to mitigate
the risks outlined in this document.

## 4. Algorithms

### 4.1. Upgrade `request` to an *a priori* authenticated URL as mixed content, if appropriate

Note: The Fetch specification will hook into this algorithm to upgrade
upgradeable mixed content to HTTPS.

Given a
[Request](https://fetch.spec.whatwg.org/#concept-request) `request`, this algorithm will rewrite its
[url](https://fetch.spec.whatwg.org/#concept-request-url) if the request is deemed to be upgradeable mixed
content, via the following algorithm:

1. If one or more of the following conditions is met, return without
 modifying `request`:
 1. `request`'s
 [url](https://fetch.spec.whatwg.org/#concept-request-url) is an [*a priori* authenticated
 URL](#a-priori-authenticated-url)
 2. [§ 4.3 Does settings prohibit mixed security
 contexts?](#categorize-settings-object) returns
 \"`Does Not Restrict Mixed Security Contents`\" when applied to
 `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client).
 3. `request`'s
 [mode](https://fetch.spec.whatwg.org/#concept-request-mode) is `CORS`.
 4. `request`'s
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination) is not \"`image`\", \"`audio`\", or
 \"`video`\".
 5. `request`'s
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination) is \"`image`\" and `request`'s
 [initiator](https://fetch.spec.whatwg.org/#concept-request-initiator) is \"`imageset`\".

2. If `request`'s
 [url](https://fetch.spec.whatwg.org/#concept-request-url)'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is `http`, set `request`'s
 [url](https://fetch.spec.whatwg.org/#concept-request-url)'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) to `https`, and return.

 Note: Per [\[url\]](#biblio-url), we do not
 modify the port because it will be set to null when the scheme is
 `http`, and interpreted as 443 once the scheme is changed to `https`

### 4.2. Existing Mixed Content Algorithms and Modifications

Note: This section specifies modifications to existing mixed content
algorithms to ignore the distinction between optionally-blockable and
blockable mixed content, since all optionally-blockable mixed content
will now be autoupgraded. [Mixed Content
§should-block-fetch](https://www.w3.org/TR/mixed-content/#should-block-fetch)
and [Mixed Content
§should-block-response](https://www.w3.org/TR/mixed-content/#should-block-response)
are replaced by the versions below, while [Mixed Content
§categorize-settings-object](https://www.w3.org/TR/mixed-content/#categorize-settings-object)
is left unmodified (but included below since this will replace the
[\[mixed-content\]](#biblio-mixed-content) spec).

section\>

### 4.3. Does `settings` prohibit mixed security contexts?

Both documents and workers have [environment settings
objects](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) which may be examined according to the following
algorithm in order to determine whether they restrict mixed content.
This algorithm returns \"`Prohibits Mixed Security Contexts`\" or
\"`Does Not Prohibit Mixed Security Contexts`\", as appropriate.

Given an [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) (`settings`):

1. If `settings`'
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin) is [*a priori*
 authenticated](#a-priori-authenticated-url)., then return
 \"`Prohibits Mixed Security Contexts`\".

2. If `settings` has a [responsible
 document](https://html.spec.whatwg.org/multipage/webappapis.html#responsible-document) `document`, then:

 1. While `document` has an [embedding
 document](#embedding-document):

 1. Set `document` to `document`'s
 [embedding
 document](#embedding-document).

 2. Let `embedder settings` be
 `document`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object)\'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

 3. If `embedder settings`'
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin) is [*a priori*
 authenticated](#a-priori-authenticated-url), then return
 \"`Prohibits Mixed Security Contexts`\".

3. Return \"`Does Not Restrict Mixed Security Contexts`\".

If a document has an [embedding
document](#embedding-document), a user agent needs to check not only the document
itself, but also the [top-level browsing
context](https://html.spec.whatwg.org/multipage/browsers.html#top-level-browsing-context) in which the document is nested, as that is the context
which controls the user's expectations regarding the security status of
the resource she's loaded. For example:

`http://a.com` loads
`http://evil.com`. The insecure request will be allowed, as `a.com` was
not loaded over a secure connection.

`https://a.com` loads
`http://evil.com`. The insecure request will be blocked, as `a.com` was
loaded over a secure connection.

`http://a.com` frames `https://b.com`,
which loads `http://evil.com`. In this case, the insecure request to
`evil.com` will be blocked, as `b.com` was loaded over a secure
connection, even though `a.com` was not.

`https://a.com` frames a `data:` URL,
which loads `http://evil.com`. In this case, the insecure request to
`evil.com` will be blocked, as `a.com` was loaded over a secure
connection, even though the framed `data:` URL would not block mixed
content if loaded in a top-level context.

### 4.4. Should fetching `request` be blocked as mixed content?

Note: The Fetch specification hooks into this algorithm to determine
whether a request should be entirely blocked (e.g. because the request
is for
[blockable](#blockable-mixed-content) content, and we can *assume* that it won't be loaded
over a secure connection).

Given a
[Request](https://fetch.spec.whatwg.org/#concept-request) `request`, a user agent determines whether
the
[Request](https://fetch.spec.whatwg.org/#concept-request) `request` should proceed or not via the
following algorithm:

1. Return **allowed** if one or more of the following conditions are
 met:
 1. [§ 4.3 Does settings prohibit mixed security
 contexts?](#categorize-settings-object) returns
 \"`Does Not Restrict Mixed Security Contexts`\" when applied to
 `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client).

 2. `request`'s
 [url](https://fetch.spec.whatwg.org/#concept-request-url) is [*a priori*
 authenticated](#a-priori-authenticated-url).

 3. The user agent has been instructed to allow [mixed
 content](#mixed-content), as described in [§ 7.2 User
 Controls](#requirements-user-controls)).

 4. `request`'s
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination) is \"`document`\", and `request`'s
 [target browsing
 context](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-target-browsing-context) has no [parent browsing
 context](https://html.spec.whatwg.org/multipage/browsers.html#parent-browsing-context).

 Note: We exclude top-level navigations from mixed content
 checks, but user agents MAY choose to enforce mixed content
 checks on insecure form submissions (see [§ 7.1 Form
 Submission](#requirements-forms)).
2. Return **blocked**.

### 4.5. Should `response` to `request` be blocked as mixed content?

Note: [If a request proceeds](#should-block-fetch), we still might want
to block the response based on the state of the connection that
generated the response (e.g. because the request is
[blockable](#blockable-mixed-content), but the connection is
[unauthenticated](#unauthenticated-response)), and we also need to ensure that a Service Worker
doesn't accidentally return an [unauthenticated
response](#unauthenticated-response) for a
[blockable](#blockable-mixed-content) request. This algorithm is used to make that
determination.

Given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and
[response](https://fetch.spec.whatwg.org/#concept-response) `response`, the user agent determines what
response should be returned via the following algorithm:

1. Return **allowed** if one or more of the following conditions are
 met:
 1. [§ 4.3 Does settings prohibit mixed security
 contexts?](#categorize-settings-object) returns
 `Does Not Restrict Mixed Content` when applied to
 `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client).

 2. `response`'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url) is [*a priori*
 authenticated](#a-priori-authenticated-url)

 3. The user agent has been instructed to allow [mixed
 content](#mixed-content), as described in [§ 7.2 User
 Controls](#requirements-user-controls)).

 4. `request`'s
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination) is \"`document`\", and `request`'s
 [target browsing
 context](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-target-browsing-context) has no [parent browsing
 context](https://html.spec.whatwg.org/multipage/browsers.html#parent-browsing-context).

 Note: We exclude top-level navigations from mixed content
 checks, but user agents MAY choose to enforce mixed content
 checks on insecure form submissions (see [§ 7.1 Form
 Submission](#requirements-forms)).
2. Return **blocked**.

## 5. Integrations

### 5.1. Modifications to Fetch

[Fetch Standard §4.1 Main
fetch](https://fetch.spec.whatwg.org/#main-fetch) should be modified to
call [§ 4.1 Upgrade request to an a priori authenticated URL as mixed
content, if appropriate](#upgrade-algorithm) on `request`
between steps 3 and 4. That is, upgradeable mixed content should be
autoupgraded to HTTPS before applying mixed content blocking.

### 5.2. Modifications to HTML

[Process a navigate
response](https://html.spec.whatwg.org/multipage/browsing-the-web.html#process-a-navigate-response) should be modified as follows. Step 3 should abort the
download and return if `source`'s [active
document](https://html.spec.whatwg.org/multipage/browsers.html#active-document)'s
[url](https://dom.spec.whatwg.org/#concept-document-url) is an [*a priori* authenticated
URLs](#a-priori-authenticated-url) and any URL in `response`'s [URL
list](https://fetch.spec.whatwg.org/#concept-response-url-list) is not an [*a priori* authenticated
URLs](#a-priori-authenticated-url).

A similar change should be made to [downloads a
hyperlink](https://html.spec.whatwg.org/multipage/links.html#downloading-hyperlinks). In this algorithm, step 6.2 should be modified to
return (aborting the download) if `subject`'s [node
document](https://dom.spec.whatwg.org/#concept-node-document)'s
[url](https://dom.spec.whatwg.org/#concept-document-url) is an [*a priori* authenticated
URLs](#a-priori-authenticated-url) and any URL in `response`'s [URL
list](https://fetch.spec.whatwg.org/#concept-response-url-list) is not an [*a priori* authenticated
URLs](#a-priori-authenticated-url) (where `response` is the result of fetching
`request`).

Note: Downloads are not autoupgraded like other types of mixed content,
because the user agent does not always know before requesting a resource
that it will be downloaded.

Note: Resources are downloaded before the user agent decides whether to
abort them based on an insecure connection. Sensitive information may
therefore traverse the network even though the user agent eventually
blocks the download. This is generally unavoidable because the user
agent may not know that a resource is to be downloaded until it receives
the final response, but by blocking the resource, user agents will
encourage website operators to serve downloads over secure connections.

## 6. Obsolescences

### 6.1. `Strict Mixed Content Checking`

This specification renders the [Mixed Content
§strict-checking](https://www.w3.org/TR/mixed-content/#strict-checking)
mode and the `block-all-mixed-content` CSP directive obsolete, because
all mixed content is now blocked if it can't be autoupgraded.

Note: The `upgrade-insecure-requests`
([\[upgrade-insecure-requests\]](#biblio-upgrade-insecure-requests))
directive is not obsolete because it allows developers to upgrade
blockable content. This specification only upgrades upgradeable content
by default.

### 6.2. `Mixed Content`

This specification renders the
[\[mixed-content\]](#biblio-mixed-content)
specification obsolete, and replaces it.

## 7. Security and Privacy Considerations

Overall, autoupgrading upgradeable mixed content is expected to be
security- and privacy-positive, by protecting more user traffic from
network eavesdropping and tampering.

There is a risk of introducing a security or privacy issue in a webpage
by loading a resource that the developer did not intend. For example,
suppose that a website includes an innocuous image from
`http://www.example.com/image.jpg`, and for some reason
`https://www.example.com/image.jpg` redirects to a tracking site. The
browser will now have introduced a privacy issue without the developer's
or user's explicit consent. However, these cases are expected to be
exceedingly rare. The risk is mitigated by autoupgrading only
upgradeable content, not blockable content as well. Blockable content
could present more risk, for example the risk of loading an out-of-date
and vulnerable JavaScript library.

### 7.1. Form Submission

If [§ 4.3 Does settings prohibit mixed security
contexts?](#categorize-settings-object) returns
`Restricts Mixed Content` when applied to a
[`Document`](https://dom.spec.whatwg.org/#document)\'s [relevant settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object), then a user agent MAY choose to warn users of the
presence of one or more
[`form`](https://html.spec.whatwg.org/multipage/forms.html#the-form-element) elements with
[action](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#attr-fs-action) attributes whose values are not [*a priori*
authenticated
URLs](#a-priori-authenticated-url)

A user agent MAY choose to warn users on submission of a
[`form`](https://html.spec.whatwg.org/multipage/forms.html#the-form-element) element with
[action](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#attr-fs-action) attributes whose values are not [*a priori*
authenticated
URLs](#a-priori-authenticated-url) and allow users to abort the submission.

Further, a user agent MAY treat form submissions from such a
[`Document`](https://dom.spec.whatwg.org/#document) as a
[blockable](#blockable-mixed-content) request, even if the submission occurs in the
[top-level browsing
context](https://html.spec.whatwg.org/multipage/browsers.html#top-level-browsing-context).

### 7.2. User Controls

A user agent MAY offer users the ability to override its decision to
block
[blockable](#blockable-mixed-content) mixed content on a particular page.

Note: Practically, a user agent probably can't get away with not
offering such a back door. That said, allowing mixed script is in
particular a very dangerous option, and each user agent [REALLY SHOULD
NOT](http://tools.ietf.org/html/rfc6919#section-3)
[\[RFC6919\]](#biblio-rfc6919) present such a choice
to users without careful consideration and communication of the risk
involved.

A user agent MAY offer users the ability to override its decision to
automatically upgrade
[upgradeable](#upgradeable-mixed-content) mixed content on a particular page.

Any such controls offered by a user agent MUST also be offered through
accessibility APIs for users of assistive technologies.

## 8. Acknowledgements

In addition to the wonderful feedback gathered from the WebAppSec WG,
the Chrome security team was invaluable in preparing this specification.
In particular, Chris Palmer, Chris Evans, Ryan Sleevi, Michal Zalewski,
Ken Buchanan, and Tom Sepez gave lots of early feedback. Anne van
Kesteren explained Fetch, helped define the interface to this
specification, and provided valuable feedback on the Level 2 update.
Brian Smith helped keep the spec focused, trim, and sane.
