
- Light
- Dark
- Auto

[draft-ietf-httpbis-layered-cookies-02\
[ None ]](/doc/draft-ietf-httpbis-layered-cookies/)

+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | Title | | Cookies: HTTP State Management Mechanism |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| Document | Document type | | [Active Internet-Draft] ([httpbis WG](/wg/httpbis/about/)) |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | Select version | | - [00](/doc/html/draft-ietf-httpbis-layered-cookies-00) |
| | | | - [01](/doc/html/draft-ietf-httpbis-layered-cookies-01) |
| | | | - [02](/doc/html/draft-ietf-httpbis-layered-cookies-02) |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | Compare | | draft-ietf-httpbis-layered-cookies-02 draft-ietf-httpbis-layered-cookies-01 draft-ietf-httpbis-layered-cookies-00 |
| | versions | | draft-annevk-johannhof-httpbis-cookies-01 draft-annevk-johannhof-httpbis-cookies-00 draft-ietf-httpbis-layered-cookies-02 |
| | | | draft-ietf-httpbis-layered-cookies-01 draft-ietf-httpbis-layered-cookies-00 draft-annevk-johannhof-httpbis-cookies-01 |
| | | | draft-annevk-johannhof-httpbis-cookies-00 |
| | | | |
| | | | Side-by-side |
| | | | |
| | | | Inline |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | Authors | | [Anne van Kesteren](/person/annevk@annevk.nl "Datatracker profile of Anne van Kesteren") |
| | | | (mailto:annevk%40annevk.nl "Compose email to annevk@annevk.nl"){aria-label="Compose email to annevk@annevk.nl"}, [Johann |
| | | | Hofmann](/person/mail@johann-hofmann.com "Datatracker profile of Johann Hofmann") |
| | | | (mailto:mail%40johann-hofmann.com "Compose email to mail@johann-hofmann.com"){aria-label="Compose email to mail@johann-hofmann.com"}\ |
| | | | [Email |
| | | | authors](mailto:draft-ietf-httpbis-layered-cookies@ietf.org?subject=draft-ietf-httpbis-layered-cookies "Send email to the document authors") |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | Replaces | | [draft-annevk-johannhof-httpbis-cookies](/doc/html/draft-annevk-johannhof-httpbis-cookies "Cookies: HTTP State Management Mechanism") |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | RFC stream | | ![IETF Logo](https://static.ietf.org/dt/12.80.0/ietf/images/ietf-logo-nor-white.svg) ![IETF |
| | | | Logo](https://static.ietf.org/dt/12.80.0/ietf/images/ietf-logo-nor.svg) |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | Intended RFC | | Proposed Standard |
| | status | | |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | Other formats | | ::: buttonlist |
| | | | [ txt](https://www.ietf.org/archive/id/draft-ietf-httpbis-layered-cookies-02.txt) [ |
| | | | html](https://www.ietf.org/archive/id/draft-ietf-httpbis-layered-cookies-02.html) [ |
| | | | xml](https://www.ietf.org/archive/id/draft-ietf-httpbis-layered-cookies-02.xml) [ |
| | | | bibtex](/doc/draft-ietf-httpbis-layered-cookies/02/bibtex/) [ |
| | | | bibxml](/doc/bibxml3/draft-ietf-httpbis-layered-cookies-02.xml) |
| | | | ::: |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | Additional | | [Mailing list discussion](http://lists.w3.org/Archives/Public/ietf-http-wg/) |
| | resources | | |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | | | [Report a bug ](https://github.com/ietf-tools/datatracker/issues/new/choose) |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+

\

+------------------------+--------------------------+----------+
| Internet-Draft | Cookies | May 2026 |
+========================+==========================+==========+
| van Kesteren & Hofmann | Expires 22 November 2026 | \[Page\] |
+========================+==========================+==========+

Workgroup:
: HTTP

Internet-Draft:
: draft-ietf-httpbis-layered-cookies-02

Obsoletes:
: [\[6265\]](https://www.rfc-editor.org/rfc/rfc%5B6265%5D) (if
 approved)

Published:
: 21 May 2026

Intended Status:
: Standards Track

Expires:
: 22 November 2026

Authors:

: ::::: author
 ::: author-name
 A. van Kesteren, [Ed.]
 :::

 ::: org
 Apple
 :::
 :::::

 ::::: author
 ::: author-name
 J. Hofmann, [Ed.]
 :::

 ::: org
 Google
 :::
 :::::

# Cookies: HTTP State Management Mechanism

## [Abstract]
This document defines the HTTP `Cookie` and `Set-Cookie` header fields.
These header fields can be used by HTTP servers to store state (called
cookies) at HTTP user agents, letting the servers maintain a stateful
session over the mostly stateless HTTP protocol. Although cookies have
many historical infelicities that degrade their security and privacy,
the `Cookie` and `Set-Cookie` header fields are widely used on the
Internet. This document obsoletes RFC 6265 and
6265bis.[¶](#section-abstract-1)

## [About This Document]
This note is to be removed before publishing as an
RFC.[¶](#section-note.1-1)

Status information for this document may be found at
<https://datatracker.ietf.org/doc/draft-ietf-httpbis-layered-cookies/>.[¶](#section-note.1-2)

Discussion of this document takes place on the HTTP Working Group
mailing list ([mailto:ietf-http-wg@w3.org](mailto:ietf-http-wg@w3.org)),
which is archived at
<https://lists.w3.org/Archives/Public/ietf-http-wg/>. Working Group
information can be found at
<https://httpwg.org/>.[¶](#section-note.1-3)

Source for this draft and an issue tracker can be found at
<https://github.com/httpwg/http-extensions/labels/cookies>.[¶](#section-note.1-4)

## [Status of This Memo]
This Internet-Draft is submitted in full conformance with the provisions
of BCP 78 and BCP 79.[¶](#section-boilerplate.1-1)

Internet-Drafts are working documents of the Internet Engineering Task
Force (IETF). Note that other groups may also distribute working
documents as Internet-Drafts. The list of current Internet-Drafts is at
<https://datatracker.ietf.org/drafts/current/>.[¶](#section-boilerplate.1-2)

Internet-Drafts are draft documents valid for a maximum of six months
and may be updated, replaced, or obsoleted by other documents at any
time. It is inappropriate to use Internet-Drafts as reference material
or to cite them other than as \"work in
progress.\"[¶](#section-boilerplate.1-3)

This Internet-Draft will expire on 22 November
2026.[¶](#section-boilerplate.1-4)

## [Copyright Notice]
Copyright (c) 2026 IETF Trust and the persons identified as the document
authors. All rights reserved.[¶](#section-boilerplate.2-1)

This document is subject to BCP 78 and the IETF Trust\'s Legal
Provisions Relating to IETF Documents
(<https://trustee.ietf.org/license-info>) in effect on the date of
publication of this document. Please review these documents carefully,
as they describe your rights and restrictions with respect to this
document. Code Components extracted from this document must include
Revised BSD License text as described in Section 4.e of the Trust Legal
Provisions and are provided without warranty as described in the Revised
BSD License.[¶](#section-boilerplate.2-2)

This document may contain material from IETF Documents or IETF
Contributions published or made publicly available before November 10,
2008. The person(s) controlling the copyright in some of this material
may not have granted the IETF Trust the right to allow modifications of
such material outside the IETF Standards Process. Without obtaining an
adequate license from the person(s) controlling the copyright in such
materials, this document may not be modified outside the IETF Standards
Process, and derivative works of it may not be created outside the IETF
Standards Process, except to format it for publication as an RFC or to
translate it into languages other than
English.[¶](#section-boilerplate.2-3)

[▲](#)

## [Table of Contents]
- :::
 [1](#section-1).  [Introduction](#name-introduction)

 - :::
 [1.1](#section-1.1).  [Examples](#name-examples)
 :::
 :::

- :::
 [2](#section-2).  [Conventions](#name-conventions)

 - :::
 [2.1](#section-2.1).  [Terminology](#name-terminology)
 :::

 - :::
 [2.2](#section-2.2).  [ABNF](#name-abnf)
 :::
 :::

- :::
 [3](#section-3).  [Which Requirements to
 Implement](#name-which-requirements-to-imple)

 - :::
 [3.1](#section-3.1).  [Cookie Producing
 Implementations](#name-cookie-producing-implementa)
 :::

 - :::
 [3.2](#section-3.2).  [Cookie Consuming
 Implementations](#name-cookie-consuming-implementa)
 :::

 - :::
 [3.3](#section-3.3).  [Programming Languages
 & Software Frameworks](#name-programming-languages-softw)
 :::
 :::

- :::
 [4](#section-4).  [Server
 Requirements](#name-server-requirements)

 - :::
 [4.1](#section-4.1).  [Set-Cookie](#name-set-cookie)

 - :::
 [4.1.1](#section-4.1.1).  [Syntax](#name-syntax)
 :::

 - :::
 [4.1.2](#section-4.1.2).  [Semantics
 (Non-Normative)](#name-semantics-non-normative)
 :::

 - :::
 [4.1.3](#section-4.1.3).  [Cookie Name
 Prefixes](#name-cookie-name-prefixes)
 :::
 :::

 - :::
 [4.2](#section-4.2).  [Cookie](#name-cookie)

 - :::
 [4.2.1](#section-4.2.1).  [Syntax](#name-syntax-2)
 :::

 - :::
 [4.2.2](#section-4.2.2).  [Semantics](#name-semantics)
 :::
 :::
 :::

- :::
 [5](#section-5).  [User Agent
 Requirements](#name-user-agent-requirements)

 - :::
 [5.1](#section-5.1).  [Cookie
 Concepts](#name-cookie-concepts)

 - :::
 [5.1.1](#section-5.1.1).  [Cookie Store And
 Limits](#name-cookie-store-and-limits)
 :::

 - :::
 [5.1.2](#section-5.1.2).  [Cookie
 Struct](#name-cookie-struct)
 :::
 :::

 - :::
 [5.2](#section-5.2).  [Cookie Store
 Eviction](#name-cookie-store-eviction)

 - :::
 [5.2.1](#section-5.2.1).  [Remove Expired
 Cookies](#name-remove-expired-cookies)
 :::

 - :::
 [5.2.2](#section-5.2.2).  [Remove Excess
 Cookies for a Host](#name-remove-excess-cookies-for-a)
 :::

 - :::
 [5.2.3](#section-5.2.3).  [Remove Global
 Excess Cookies](#name-remove-global-excess-cookie)
 :::
 :::

 - :::
 [5.3](#section-5.3).  [Subcomponent
 Algorithms](#name-subcomponent-algorithms)

 - :::
 [5.3.1](#section-5.3.1).  [Parse a
 Date](#name-parse-a-date)
 :::

 - :::
 [5.3.2](#section-5.3.2).  [Domain
 Matching](#name-domain-matching)
 :::

 - :::
 [5.3.3](#section-5.3.3).  [Cookie Default
 Path](#name-cookie-default-path)
 :::

 - :::
 [5.3.4](#section-5.3.4).  [Path
 Matching](#name-path-matching)
 :::
 :::

 - :::
 [5.4](#section-5.4).  [Main
 Algorithms](#name-main-algorithms)

 - :::
 [5.4.1](#section-5.4.1).  [Parse and Store
 a Cookie](#name-parse-and-store-a-cookie)
 :::

 - :::
 [5.4.2](#section-5.4.2).  [Parse a
 Cookie](#name-parse-a-cookie)
 :::

 - :::
 [5.4.3](#section-5.4.3).  [Store a
 Cookie](#name-store-a-cookie)
 :::

 - :::
 [5.4.4](#section-5.4.4).  [Garbage Collect
 Cookies](#name-garbage-collect-cookies)
 :::

 - :::
 [5.4.5](#section-5.4.5).  [Retrieve
 Cookies](#name-retrieve-cookies)
 :::

 - :::
 [5.4.6](#section-5.4.6).  [Serialize
 Cookies](#name-serialize-cookies)
 :::
 :::

 - :::
 [5.5](#section-5.5).  [Requirements Specific
 to Non-Browser User
 Agents](#name-requirements-specific-to-no)

 - :::
 [5.5.1](#section-5.5.1).  [The Set-Cookie
 Header Field](#name-the-set-cookie-header-field)
 :::

 - :::
 [5.5.2](#section-5.5.2).  [The Cookie
 Header Field](#name-the-cookie-header-field)
 :::

 - :::
 [5.5.3](#section-5.5.3).  [Cookie Store
 Eviction for Non-Browser User
 Agents](#name-cookie-store-eviction-for-n)
 :::
 :::

 - :::
 [5.6](#section-5.6).  [Requirements Specific
 to Browser User Agents](#name-requirements-specific-to-br)
 :::
 :::

- :::
 [6](#section-6).  [Implementation
 Considerations](#name-implementation-consideratio)

 - :::
 [6.1](#section-6.1).  [Limits](#name-limits)
 :::

 - :::
 [6.2](#section-6.2).  [Application
 Programming Interfaces](#name-application-programming-int)
 :::
 :::

- :::
 [7](#section-7).  [Privacy
 Considerations](#name-privacy-considerations)

 - :::
 [7.1](#section-7.1).  [Third-Party
 Cookies](#name-third-party-cookies)
 :::

 - :::
 [7.2](#section-7.2).  [Cookie
 Policy](#name-cookie-policy)
 :::

 - :::
 [7.3](#section-7.3).  [User
 Controls](#name-user-controls)
 :::

 - :::
 [7.4](#section-7.4).  [Expiration
 Dates](#name-expiration-dates)
 :::
 :::

- :::
 [8](#section-8).  [Security
 Considerations](#name-security-considerations)

 - :::
 [8.1](#section-8.1).  [Overview](#name-overview)
 :::

 - :::
 [8.2](#section-8.2).  [Ambient
 Authority](#name-ambient-authority)
 :::

 - :::
 [8.3](#section-8.3).  [Clear
 Text](#name-clear-text)
 :::

 - :::
 [8.4](#section-8.4).  [Session
 Identifiers](#name-session-identifiers)
 :::

 - :::
 [8.5](#section-8.5).  [Weak
 Confidentiality](#name-weak-confidentiality)
 :::

 - :::
 [8.6](#section-8.6).  [Weak
 Integrity](#name-weak-integrity)
 :::

 - :::
 [8.7](#section-8.7).  [Reliance on
 DNS](#name-reliance-on-dns)
 :::

 - :::
 [8.8](#section-8.8).  [SameSite
 Cookies](#name-samesite-cookies)
 :::
 :::

- :::
 [9](#section-9).  [IANA
 Considerations](#name-iana-considerations)

 - :::
 [9.1](#section-9.1).  [Cookie](#name-cookie-2)
 :::

 - :::
 [9.2](#section-9.2).  [Set-Cookie](#name-set-cookie-2)
 :::
 :::

- :::
 [10](#section-10). [Changes](#name-changes)
 :::

- :::
 (#section-11)[Acknowledgements](#name-acknowledgements)
 :::

- :::
 (#section-12)[References](#name-references)

 - :::
 (#section-12.1)[Normative
 References](#name-normative-references)
 :::

 - :::
 (#section-12.2)[Informative
 References](#name-informative-references)
 :::
 :::

- :::
 (#appendix-A)[Authors\'
 Addresses](#name-authors-addresses)
 :::

## [1.](#section-1) [Introduction]
This document defines the HTTP `Cookie` and `Set-Cookie` header fields.
Using the `Set-Cookie` header field, an HTTP server can pass name/value
pairs and associated metadata (called cookies) to a user agent. When the
user agent makes subsequent requests to the server, the user agent uses
the metadata and other information to determine whether to return the
name/value pairs in the `Cookie` header
field.[¶](#section-1-1)

Although simple on their surface, cookies have a number of complexities.
For example, the server can scope the maximum amount of time during
which the user agent should return the cookie, the servers to which the
user agent should return the cookie, and whether the cookie can be
accessed through a non-HTTP API, such as JavaScript in a web
browser.[¶](#section-1-2)

For historical reasons, cookies contain a number of security and privacy
infelicities. For example, a server can indicate that a given cookie is
intended for \"secure\" connections, but the cookie\'s Secure attribute
does not provide integrity in the presence of an active network
attacker. Similarly, cookies for a given host are shared across all the
ports on that host, even though the usual \"same-origin policy\" used by
web browsers isolates content retrieved via different
ports.[¶](#section-1-3)

This document specifies the syntax and semantics of these header fields.
Where some existing software differs from the requirements in
significant ways, the document contains a note explaining the
difference.[¶](#section-1-4)

This document obsoletes \[[RFC6265](#RFC6265)\] and
6265bis.[¶](#section-1-5)

### [1.1.](#section-1.1) [Examples]
Using the `Set-Cookie` header field, a server can send the user agent a
short string in an HTTP response that the user agent will return in
future HTTP requests that are within the scope of the cookie. For
example, the server can send the user agent a \"session identifier\"
named SID with the value 31d4d96e407aad42. The user agent then returns
the session identifier in subsequent
requests.[¶](#section-1.1-1)

 == Server -> User Agent ==

 Set-Cookie: SID=31d4d96e407aad42

 == User Agent -> Server ==

 Cookie: SID=31d4d96e407aad42

[¶](#section-1.1-2)

The server can alter the default scope of the cookie using the Path and
Domain attributes. For example, the server can instruct the user agent
to return the cookie to every path and every subdomain of
site.example.[¶](#section-1.1-3)

 == Server -> User Agent ==

 Set-Cookie: SID=31d4d96e407aad42; Path=/; Domain=site.example

 == User Agent -> Server ==

 Cookie: SID=31d4d96e407aad42

[¶](#section-1.1-4)

As shown in the next example, the server can store multiple cookies at
the user agent. For example, the server can store a session identifier
as well as the user\'s preferred language by returning two `Set-Cookie`
header fields. Notice that the server uses the Secure and HttpOnly
attributes to provide additional security protections for the more
sensitive session identifier (see [Section
4.1.2](#sane-set-cookie-semantics)).[¶](#section-1.1-5)

 == Server -> User Agent ==

 Set-Cookie: SID=31d4d96e407aad42; Path=/; Secure; HttpOnly
 Set-Cookie: lang=en-US; Path=/; Domain=site.example

 == User Agent -> Server ==

 Cookie: SID=31d4d96e407aad42; lang=en-US

[¶](#section-1.1-6)

Notice that the `Cookie` header field above contains two cookies, one
named SID and one named lang.[¶](#section-1.1-7)

Cookie names are case-sensitive, meaning that if a server sends the user
agent two Set-Cookie header fields that differ only in their name\'s
case the user agent will store and return both of those cookies in
subsequent requests.[¶](#section-1.1-8)

 == Server -> User Agent ==

 Set-Cookie: SID=31d4d96e407aad42
 Set-Cookie: sid=31d4d96e407aad42

 == User Agent -> Server ==

 Cookie: SID=31d4d96e407aad42; sid=31d4d96e407aad42

[¶](#section-1.1-9)

If the server wishes the user agent to persist the cookie over multiple
\"sessions\" (e.g., user agent restarts), the server can specify an
expiration date in the Expires attribute. Note that the user agent might
delete the cookie before the expiration date if the user agent\'s cookie
store exceeds its quota or if the user manually deletes the server\'s
cookie.[¶](#section-1.1-10)

 == Server -> User Agent ==

 Set-Cookie: lang=en-US; Expires=Wed, 09 Jun 2021 10:18:14 GMT

 == User Agent -> Server ==

 Cookie: SID=31d4d96e407aad42; lang=en-US

[¶](#section-1.1-11)

Finally, to remove a cookie, the server returns a `Set-Cookie` header
field with an expiration date in the past. The server will be successful
in removing the cookie only if the Path and the Domain attribute in the
`Set-Cookie` header field match the values used when the cookie was
created.[¶](#section-1.1-12)

 == Server -> User Agent ==

 Set-Cookie: lang=; Expires=Sun, 06 Nov 1994 08:49:37 GMT

 == User Agent -> Server ==

 Cookie: SID=31d4d96e407aad42

[¶](#section-1.1-13)

## [2.](#section-2) [Conventions]
### [2.1.](#section-2.1) [Terminology]
This specification depends on Infra. \[[INFRA](#INFRA)\][¶](#section-2.1-1)

Some terms used in this specification are defined in the following
standards and specifications:[¶](#section-2.1-2)

- :::
 HTTP \[[RFC9110](#RFC9110)\][¶](#section-2.1-3.1.1)
 :::

- :::
 URL \[[URL](#URL)\][¶](#section-2.1-3.2.1)
 :::

A **non-HTTP API** is a non-HTTP mechanisms used to set and retrieve
cookies, such as a web browser API that exposes cookies to
JavaScript.[¶](#section-2.1-4)

### [2.2.](#section-2.2) [ABNF]
This specification uses the Augmented Backus-Naur Form (ABNF) notation
of \[[RFC5234](#RFC5234)\].[¶](#section-2.2-1)

The following core rules are included by reference, as defined in
\[[RFC5234](#RFC5234)\], Appendix B.1: ALPHA (letters), CR
(carriage return), CRLF (CR LF), CTLs (controls), DIGIT (decimal 0-9),
DQUOTE (double quote), HEXDIG (hexadecimal 0-9/A-F/a-f), LF (line feed),
NUL (null octet), OCTET (any 8-bit sequence of data except NUL), SP
(space), HTAB (horizontal tab), CHAR (any ASCII byte), VCHAR (any
visible ASCII byte), and WSP (whitespace).[¶](#section-2.2-2)

The OWS (optional whitespace) and BWS (bad whitespace) rules are defined
in [Section
5.6.3](https://rfc-editor.org/rfc/rfc9110#section-5.6.3) of
\[[RFC9110](#RFC9110)\].[¶](#section-2.2-3)

## [3.](#section-3) [Which Requirements to Implement]
The upcoming two sections, [Section 4](#server-requirements) and [Section 5](#ua-requirements), discuss the set of requirements for two distinct types of
implementations. This section is meant to help guide implementers in
determining which set of requirements best fits their goals. Choosing
the wrong set of requirements could result in a lack of compatibility
with other cookie implementations.[¶](#section-3-1)

It\'s important to note that being compatible means different things
depending on the implementer\'s goals. These differences have built up
over time due to both intentional and unintentional specification
changes, specification interpretations, and historical implementation
differences.[¶](#section-3-2)

This section roughly divides implementers of this specification into two
types, producers and consumers. These are not official terms and are
only used here to help readers develop an intuitive understanding of the
use cases.[¶](#section-3-3)

### [3.1.](#section-3.1) [Cookie Producing Implementations]
An implementer should choose [Section 4](#server-requirements) whenever cookies are created and will be sent to a user
agent, such as a web browser. These implementations are frequently
referred to as servers by the specification but that term includes
anything which primarily produces cookies. Some potential
examples:[¶](#section-3.1-1)

- :::
 Server applications hosting a website or
 API[¶](#section-3.1-2.1.1)
 :::

- :::
 Programming languages or software frameworks that support
 cookies[¶](#section-3.1-2.2.1)
 :::

- :::
 Integrated third-party web applications, such as a business management
 suite[¶](#section-3.1-2.3.1)
 :::

All these benefit from not only supporting as many user agents as
possible but also supporting other servers. This is useful if a cookie
is produced by a software framework and is later sent back to a server
application which needs to read it. [Section
4](#server-requirements) advises best practices
that help maximize this sense of
compatibility.[¶](#section-3.1-3)

### [3.2.](#section-3.2) [Cookie Consuming Implementations]
An implementer should choose [Section 5](#ua-requirements) whenever cookies are primarily received from another
source. These implementations are referred to as user agents. Some
examples:[¶](#section-3.2-1)

- :::
 Web browsers[¶](#section-3.2-2.1.1)
 :::

- :::
 Tools that support stateful HTTP[¶](#section-3.2-2.2.1)
 :::

- :::
 Programming languages or software frameworks that support
 cookies[¶](#section-3.2-2.3.1)
 :::

Because user agents don\'t know which servers a user will access, and
whether or not that server is following best practices, users agents are
advised to implement a more lenient set of requirements and to accept
some things that servers are warned against producing. [Section
5](#ua-requirements) advises best practices that
help maximize this sense of compatibility.[¶](#section-3.2-3)

### [3.3.](#section-3.3) [Programming Languages & Software Frameworks]
A programming language or software framework with support for cookies
could reasonably be used to create an application that acts as a cookie
producer, cookie consumer, or both. Because a developer may want to
maximize their compatibility as either a producer or consumer, these
languages or frameworks should strongly consider supporting both sets of
requirements, [Section 4](#server-requirements)
and [Section 5](#ua-requirements), behind a
compatibility mode toggle. This toggle should default to [Section
4](#server-requirements)\'s
requirements.[¶](#section-3.3-1)

Doing so will reduce the chances that a developer\'s application can
inadvertently create cookies that cannot be read by other
servers.[¶](#section-3.3-2)

## [4.](#section-4) [Server Requirements]
This section describes the conforming syntax and semantics of the HTTP
`Cookie` and `Set-Cookie` header fields.[¶](#section-4-1)

### [4.1.](#section-4.1) [Set-Cookie]
The `Set-Cookie` HTTP response header field is used to send cookies from
the server to the user agent.[¶](#section-4.1-1)

Origin servers MAY send a `Set-Cookie` response header field with any
response. An origin server can include multiple `Set-Cookie` header
fields in a single response. The presence of a `Cookie` or a
`Set-Cookie` header field does not preclude HTTP caches from storing and
reusing a response.[¶](#section-4.1-2)

Origin servers and intermediaries MUST NOT combine multiple Set-Cookie
header fields into a single header field. The usual mechanism for
combining HTTP headers fields (i.e., as defined in [Section
5.3](https://rfc-editor.org/rfc/rfc9110#section-5.3) of
\[[RFC9110](#RFC9110)\]) might change the semantics of the
Set-Cookie header field because the %x2C (\",\") character is used by
Set-Cookie in a way that conflicts with such
combining.[¶](#section-4.1-3)

For example,[¶](#section-4.1-4)

 Set-Cookie: a=b;path=/c,d=e

[¶](#section-4.1-5)

is ambiguous. It could be intended as two cookies, a=b and d=e, or a
single cookie with a path of /c,d=e.[¶](#section-4.1-6)

#### [4.1.1.](#section-4.1.1) [Syntax]
Informally, the `Set-Cookie` response header field contains a cookie,
which begins with a name-value-pair, followed by zero or more
attribute-value pairs. Servers MUST send `Set-Cookie` header fields that
conform to the following grammar:[¶](#section-4.1.1-1)

 set-cookie = set-cookie-string
 set-cookie-string = BWS cookie-pair *( BWS ";" OWS cookie-av )
 cookie-pair = cookie-name BWS "=" BWS cookie-value
 cookie-name = token
 cookie-value = *cookie-octet / ( DQUOTE *cookie-octet DQUOTE )
 cookie-octet = %x21 / %x23-2B / %x2D-3A / %x3C-5B / %x5D-7E
 ; US-ASCII characters excluding CTLs,
 ; whitespace, DQUOTE, comma, semicolon,
 ; and backslash
 token = <token, defined in [HTTP], Section 5.6.2>

 cookie-av = expires-av / max-age-av / domain-av /
 path-av / secure-av / httponly-av /
 samesite-av / extension-av
 expires-av = "Expires" BWS "=" BWS sane-cookie-date
 sane-cookie-date =
 <IMF-fixdate, defined in [HTTP], Section 5.6.7>
 max-age-av = "Max-Age" BWS "=" BWS 1*DIGIT
 domain-av = "Domain" BWS "=" BWS domain-value
 domain-value = <subdomain>
 ; see details below
 path-av = "Path" BWS "=" BWS path-value
 path-value = *av-octet
 secure-av = "Secure"
 httponly-av = "HttpOnly"
 samesite-av = "SameSite" BWS "=" BWS samesite-value
 samesite-value = "Strict" / "Lax" / "None"
 extension-av = *av-octet
 av-octet = %x20-3A / %x3C-7E
 ; any CHAR except CTLs or ";"

[¶](#section-4.1.1-2)

Note that some of the grammatical terms above reference documents that
use different grammatical notations than this document (which uses ABNF
from \[[RFC5234](#RFC5234)\]).[¶](#section-4.1.1-3)

Per the grammar above, servers MUST NOT produce nameless cookies (i.e.,
an empty cookie-name) as such cookies may be unpredictably serialized by
user agents when sent back to the server.[¶](#section-4.1.1-4)

The semantics of the cookie-value are not defined by this
document.[¶](#section-4.1.1-5)

To maximize compatibility with user agents, servers that wish to store
arbitrary data in a cookie-value SHOULD encode that data, for example,
using Base64 \[[RFC4648](#RFC4648)\].[¶](#section-4.1.1-6)

Per the grammar above, the cookie-value MAY be wrapped in DQUOTE
characters. Note that in this case, the initial and trailing DQUOTE
characters are not stripped. They are part of the cookie-value, and will
be included in `Cookie` header fields sent to the
server.[¶](#section-4.1.1-7)

The domain-value is a subdomain as defined by
\[[RFC1034](#RFC1034)\], Section 3.5, and as enhanced by
\[[RFC1123](#RFC1123)\], Section 2.1. Thus, domain-value is
a byte sequence of ASCII bytes.[¶](#section-4.1.1-8)

The portions of the set-cookie-string produced by the cookie-av term are
known as attributes. To maximize compatibility with user agents, servers
SHOULD NOT produce two attributes with the same name in the same
set-cookie-string.[¶](#section-4.1.1-9)

NOTE: The name of an attribute-value pair is not case-sensitive. So
while they are presented here in CamelCase, such as `HttpOnly` or
`SameSite`, any case is accepted. E.g., `httponly`, `Httponly`,
`hTTPoNLY`, etc.[¶](#section-4.1.1-10)

Servers MUST NOT include more than one `Set-Cookie` header field in the
same response with the same cookie-name. (See [Section
5.5.1](#set-cookie) for how user agents handle
this case.)[¶](#section-4.1.1-11)

If a server sends multiple responses containing `Set-Cookie` header
fields concurrently to the user agent (e.g., when communicating with the
user agent over multiple sockets), these responses create a \"race
condition\" that can lead to unpredictable
behavior.[¶](#section-4.1.1-12)

NOTE: Some existing user agents differ in their interpretation of
two-digit years. To avoid compatibility issues, servers SHOULD use the
rfc1123-date format, which requires a four-digit
year.[¶](#section-4.1.1-13)

NOTE: Some user agents store and process dates in cookies as 32-bit UNIX
time_t values. Implementation bugs in the libraries supporting time_t
processing on some systems might cause such user agents to process dates
after the year 2038 incorrectly.[¶](#section-4.1.1-14)

#### [4.1.2.](#section-4.1.2) [Semantics (Non-Normative)]
This section describes simplified semantics of the `Set-Cookie` header
field. These semantics are detailed enough to be useful for
understanding the most common uses of cookies by servers. The full
semantics are described in [Section 5](#ua-requirements).[¶](#section-4.1.2-1)

When the user agent receives a `Set-Cookie` header field, the user agent
stores the cookie together with its attributes. Subsequently, when the
user agent makes an HTTP request, the user agent includes the
applicable, non-expired cookies in the `Cookie` header
field.[¶](#section-4.1.2-2)

If the user agent receives a new cookie with the same cookie-name,
domain-value, and path-value as a cookie that it has already stored, the
existing cookie is evicted and replaced with the new cookie. Notice that
servers can delete cookies by sending the user agent a new cookie with
an Expires attribute with a value in the
past.[¶](#section-4.1.2-3)

Unless the cookie\'s attributes indicate otherwise, the cookie is
returned only to the origin server (and not, for example, to any
subdomains), and it expires at the end of the current session (as
defined by the user agent). User agents ignore unrecognized cookie
attributes (but not the entire cookie).[¶](#section-4.1.2-4)

##### [4.1.2.1.](#section-4.1.2.1) [The Expires Attribute]
The Expires attribute indicates the maximum lifetime of the cookie,
represented as the date and time at which the cookie expires. The user
agent is not required to retain the cookie until the specified date has
passed. In fact, user agents often evict cookies due to memory pressure
or privacy concerns.[¶](#section-4.1.2.1-1)

##### [4.1.2.2.](#section-4.1.2.2) [The Max-Age Attribute]
The Max-Age attribute indicates the maximum lifetime of the cookie,
represented as the number of seconds until the cookie expires. The user
agent is not required to retain the cookie for the specified duration.
In fact, user agents often evict cookies due to memory pressure or
privacy concerns.[¶](#section-4.1.2.2-1)

If a cookie has both the Max-Age and the Expires attribute, the Max-Age
attribute has precedence and controls the expiration date of the cookie.
If a cookie has neither the Max-Age nor the Expires attribute, the user
agent will retain the cookie until \"the current session is over\" (as
defined by the user agent).[¶](#section-4.1.2.2-2)

##### [4.1.2.3.](#section-4.1.2.3) [The Domain Attribute]
The Domain attribute specifies those hosts to which the cookie will be
sent.[¶](#section-4.1.2.3-1)

If the server includes the Domain attribute, the value applies to both
the specified domain and any subdomains. For example, if the value of
the Domain attribute is \"site.example\", the user agent will include
the cookie in the `Cookie` header field when making HTTP requests to
site.example, www.site.example, and www.corp.site.example. Note that a
leading %x2E (\".\"), if present, is ignored even though that character
is not permitted.[¶](#section-4.1.2.3-2)

If the server omits the Domain attribute, the user agent will return the
cookie only to the origin server and not to any
subdomains.[¶](#section-4.1.2.3-3)

WARNING: Some existing user agents treat an absent Domain attribute as
if the Domain attribute were present and contained the current host
name. For example, if site.example returns a `Set-Cookie` header field
without a Domain attribute, these user agents will erroneously send the
cookie to www.site.example and www.corp.site.example as
well.[¶](#section-4.1.2.3-4)

The user agent will reject cookies unless the Domain attribute specifies
a scope for the cookie that would include the origin server. For
example, the user agent will accept a cookie with a Domain attribute of
\"site.example\" or of \"foo.site.example\" from foo.site.example, but
the user agent will not accept a cookie with a Domain attribute of
\"bar.site.example\" or of
\"baz.foo.site.example\".[¶](#section-4.1.2.3-5)

##### [4.1.2.4.](#section-4.1.2.4) [The Path Attribute]
The scope of each cookie is limited to a set of paths, controlled by the
Path attribute. If the server omits the Path attribute, the user agent
will use the \"directory\" of the request-uri\'s path component as the
default value. (See [Section 5.3.3](#cookie-path)
for more details.)[¶](#section-4.1.2.4-1)

The user agent will include the cookie in an HTTP request only if the
path portion of the request-uri matches (or is a subdirectory of) the
cookie\'s Path attribute, where the %x2F (\"/\") character is
interpreted as a directory separator.[¶](#section-4.1.2.4-2)

Although seemingly useful for isolating cookies between different paths
within a given host, the Path attribute cannot be relied upon for
security (see [Section 8](#security-considerations)).[¶](#section-4.1.2.4-3)

##### [4.1.2.5.](#section-4.1.2.5) [The Secure Attribute]
The Secure attribute limits the scope of the cookie to \"secure\"
channels (where \"secure\" is outside the scope of this document). E.g.,
when a cookie has the Secure attribute, the user agent will include the
cookie in an HTTP request only if the request is transmitted over a
secure channel (typically HTTP over Transport Layer Security (TLS)
\[[TLS13](#RFC8446)\] \[[RFC9110](#RFC9110)\]).[¶](#section-4.1.2.5-1)

##### [4.1.2.6.](#section-4.1.2.6) [The HttpOnly Attribute]
The HttpOnly attribute limits the scope of the cookie to HTTP requests.
In particular, the attribute instructs the user agent to omit the cookie
when providing access to cookies via non-HTTP
APIs.[¶](#section-4.1.2.6-1)

##### [4.1.2.7.](#section-4.1.2.7) [The SameSite Attribute]
The SameSite attribute limits the scope of the cookie upon creation and
delivery with respect to whether the cookie is considered to be
\"same-site\" within a larger context (where \"same-site\" is outside
the scope of this document). The SameSite attribute is particularly
relevant for web browsers and web applications accessible through
them.[¶](#section-4.1.2.7-1)

The SameSite attribute supports Strict, Lax, and None as
values.[¶](#section-4.1.2.7-2)

#### [4.1.3.](#section-4.1.3) [Cookie Name Prefixes]
[Section 8.5](#weak-confidentiality) and [Section
8.6](#weak-integrity) of this document spell out
some of the drawbacks of cookies\' historical implementation. In
particular, it is impossible for a server to have confidence that a
given cookie was set with a particular set of attributes. In order to
provide such confidence in a backwards-compatible way, two common sets
of requirements can be inferred from the first few characters of the
cookie\'s name.[¶](#section-4.1.3-1)

To maximize compatibility with user agents, servers SHOULD use prefixes
as described below.[¶](#section-4.1.3-2)

##### [4.1.3.1.](#section-4.1.3.1) [The \"\_\_Secure-\" Prefix]
If a cookie\'s name begins with a case-sensitive match for the string
`__Secure-`, then the cookie will have been set with a `Secure`
attribute.[¶](#section-4.1.3.1-1)

For example, the following `Set-Cookie` header field would be rejected
by a conformant user agent, as it does not have a `Secure`
attribute.[¶](#section-4.1.3.1-2)

 Set-Cookie: __Secure-SID=12345; Domain=site.example

[¶](#section-4.1.3.1-3)

Whereas the following `Set-Cookie` header field would be accepted if set
from a secure origin (e.g. `https://site.example/`), and rejected
otherwise:[¶](#section-4.1.3.1-4)

 Set-Cookie: __Secure-SID=12345; Domain=site.example; Secure

[¶](#section-4.1.3.1-5)

##### [4.1.3.2.](#section-4.1.3.2) [The \"\_\_Host-\" Prefix]
If a cookie\'s name begins with a case-sensitive match for the string
`__Host-`, then the cookie will have been set with a `Secure` attribute,
a `Path` attribute with a value of `/`, and no `Domain`
attribute.[¶](#section-4.1.3.2-1)

This combination yields a cookie that hews as closely as a cookie can to
treating the origin as a security boundary. The lack of a `Domain`
attribute ensures that cookie\'s host-only is true, locking the cookie
to a particular host, rather than allowing it to span subdomains.
Setting the `Path` to `/` means that the cookie is effective for the
entire host, and won\'t be overridden for specific paths. The `Secure`
attribute ensures that the cookie is unaltered by non-secure origins,
and won\'t span protocols.[¶](#section-4.1.3.2-2)

Ports are the only piece of the same-origin policy that `__Host-`
cookies continue to ignore.[¶](#section-4.1.3.2-3)

For example, the following cookies would always be
rejected:[¶](#section-4.1.3.2-4)

 Set-Cookie: __Host-SID=12345
 Set-Cookie: __Host-SID=12345; Secure
 Set-Cookie: __Host-SID=12345; Domain=site.example
 Set-Cookie: __Host-SID=12345; Domain=site.example; Path=/
 Set-Cookie: __Host-SID=12345; Secure; Domain=site.example; Path=/

[¶](#section-4.1.3.2-5)

While the following would be accepted if set from a secure origin (e.g.
`https://site.example/`), and rejected
otherwise:[¶](#section-4.1.3.2-6)

 Set-Cookie: __Host-SID=12345; Secure; Path=/

[¶](#section-4.1.3.2-7)

##### [4.1.3.3.](#section-4.1.3.3) [The \"\_\_Http-\" Prefix]
If a cookie\'s name begins with a case-sensitive match for the string
`__Http-`, then the cookie will have been set with a `Secure` attribute,
and an `HttpOnly` attribute.[¶](#section-4.1.3.3-1)

This helps developers and server operators to know that the cookie was
set using a `Set-Cookie` header, and is limited in scope to HTTP
requests.[¶](#section-4.1.3.3-2)

##### [4.1.3.4.](#section-4.1.3.4) [The \"\_\_Host-Http-\" prefix]
If a cookie\'s name begins with a case-sensitive match for the string
`__Host-Http-`, then the cookie will have been set with a `Secure`
attribute, an `HttpOnly` attribute, a `Path` attribute with a value of
`/`, and no `Domain` attribute.[¶](#section-4.1.3.4-1)

This helps developers and server operators to know that the cookie was
set using a `Set-Cookie` header, and is limited in scope to HTTP
requests.[¶](#section-4.1.3.4-2)

This combination yields a cookie that hews as closely as a cookie can to
treating the origin as a security boundary, while at the same time
ensuring developers and server operators know that its scope is limited
to HTTP requests. The lack of a `Domain` attribute ensures that
cookie\'s host-only is true, locking the cookie to a particular host,
rather than allowing it to span subdomains. Setting the `Path` to `/`
means that the cookie is effective for the entire host, and won\'t be
overridden for specific paths. The `Secure` attribute ensures that the
cookie is unaltered by non-secure origins, and won\'t span protocols.
The `HttpOnly` attribute ensures that the cookie is not exposed by the
user agent to non-HTTP APIs.[¶](#section-4.1.3.4-3)

### [4.2.](#section-4.2) [Cookie]
#### [4.2.1.](#section-4.2.1) [Syntax]
The user agent sends stored cookies to the origin server in the `Cookie`
header field. If the server conforms to the requirements in [Section
4.1](#sane-set-cookie) (and the user agent
conforms to the requirements in [Section 5](#ua-requirements)), the user agent will send a `Cookie` header field that
conforms to the following grammar:[¶](#section-4.2.1-1)

 cookie = cookie-string
 cookie-string = cookie-pair *( ";" SP cookie-pair )

[¶](#section-4.2.1-2)

While [Section
5.4](https://rfc-editor.org/rfc/rfc9110#section-5.4) of
\[[RFC9110](#RFC9110)\] does not define a length limit for
header fields it is likely that the web server\'s implementation does
impose a limit; many popular implementations have default limits of 8
kibibytes. Servers SHOULD avoid setting a large number of large cookies
such that the final cookie-string would exceed their header field limit.
Not doing so could result in requests to the server
failing.[¶](#section-4.2.1-3)

Servers MUST be tolerant of multiple `Cookie` headers. For example, an
HTTP/2 \[[RFC9113](#RFC9113)\] or HTTP/3
\[[HTTP](#RFC9114)\] client or intermediary might split a
`Cookie` header to improve compression. Servers are free to determine
what form this tolerance takes. For example, the server could process
each `Cookie` header individually or the server could concatenate all
the `Cookie` headers into one and then process that final, single,
header. The server should be mindful of any header field limits when
deciding which approach to take.[¶](#section-4.2.1-4)

Note: Since intermediaries can modify `Cookie` headers they should also
be mindful of common server header field limits in order to avoid
sending servers headers that they cannot process. For example,
concatenating multiple cookie headers into a single header might exceed
a server\'s size limit.[¶](#section-4.2.1-5)

#### [4.2.2.](#section-4.2.2) [Semantics]
Each cookie-pair represents a cookie stored by the user agent. The
cookie-pair contains the cookie-name and cookie-value the user agent
received in the `Set-Cookie` header
field.[¶](#section-4.2.2-1)

Notice that the cookie attributes are not returned. In particular, the
server cannot determine from the `Cookie` field alone when a cookie will
expire, for which hosts the cookie is valid, for which paths the cookie
is valid, or whether the cookie was set with the Secure or HttpOnly
attributes.[¶](#section-4.2.2-2)

The semantics of individual cookies in the `Cookie` header field are not
defined by this document. Servers are expected to imbue these cookies
with application-specific semantics.[¶](#section-4.2.2-3)

Although cookies are serialized linearly in the `Cookie` header field,
servers SHOULD NOT rely upon the serialization order. In particular, if
the `Cookie` header field contains two cookies with the same name (e.g.,
that were set with different Path or Domain attributes), servers SHOULD
NOT rely upon the order in which these cookies appear in the header
field.[¶](#section-4.2.2-4)

## [5.](#section-5) [User Agent Requirements]
This section specifies the processing models associated with the
`Cookie` and `Set-Cookie` header fields in sufficient detail that a user
agent can interoperate with existing servers (even those that do not
conform to the well-behaved profile described in [Section
4](#server-requirements)).[¶](#section-5-1)

A user agent could enforce more restrictions than those specified herein
(e.g., restrictions specified by its cookie policy, described in
[Section 7.2](#cookie-policy)). However, such
additional restrictions may reduce the likelihood that a user agent will
be able to interoperate with existing
servers.[¶](#section-5-2)

### [5.1.](#section-5.1) [Cookie Concepts]
To facilitate the algorithms that follow, a number of pre-requisite
concepts need to be introduced.[¶](#section-5.1-1)

#### [5.1.1.](#section-5.1.1) [Cookie Store And Limits]
A user agent has an associated **cookie store**, which is a list of
cookies. It is initially « ».[¶](#section-5.1.1-1)

A user agent has an associated **total cookies-per-host limit**, which
is an integer. It SHOULD be 50 or more.[¶](#section-5.1.1-2)

A user agent has an associated **total cookies limit**, which is an
integer. It SHOULD be 3000 or more.[¶](#section-5.1.1-3)

A user agent has an associated **cookie age limit**, which is a number
of days. It SHOULD be 400 days or less (see [Section
7.2](#cookie-policy)).[¶](#section-5.1.1-4)

#### [5.1.2.](#section-5.1.2) [Cookie Struct]
A **cookie** is a struct that represents a piece of state to be
transmitted between a client and a
server.[¶](#section-5.1.2-1)

A cookie\'s **name** is a byte sequence. It always needs to be
set.[¶](#section-5.1.2-2)

A cookie\'s **value** is a byte sequence. It always needs to be
set.[¶](#section-5.1.2-3)

A cookie\'s **secure** is a boolean. It is initially
false.[¶](#section-5.1.2-4)

A cookie\'s **host** is a domain, IP address, null, or failure. It is
initially null. Note: Once a cookie is in the user agent\'s cookie store
its host is a domain or IP address.[¶](#section-5.1.2-5)

A cookie\'s **host-only** is a boolean. It is initially
false.[¶](#section-5.1.2-6)

A cookie\'s **path** is a URL path.[¶](#section-5.1.2-7)

A cookie\'s **has-path attribute** is a boolean. It is initially
false.[¶](#section-5.1.2-8)

A cookie\'s **same-site** is \"`strict`\", \"`lax`\", \"`unset`\", or
\"`none`\". It is initially \"`unset`\".[¶](#section-5.1.2-9)

A cookie\'s **http-only** is a boolean. It is initially
false.[¶](#section-5.1.2-10)

A cookie\'s **creation-time** is a time. It is initially the current
time.[¶](#section-5.1.2-11)

A cookie\'s **expiry-time** is null or a time. It is initially null.
Note: A prior version of this specification referred to null with a
distinct \"persistent-flag\" field being
false.[¶](#section-5.1.2-12)

A cookie\'s **last-access-time** is a time. It is initially the current
time.[¶](#section-5.1.2-13)

##### [5.1.2.1.](#section-5.1.2.1) [Cookie Struct Miscellaneous]
A cookie is **expired** if its expiry-time is non-null and its
expiry-time is in the past.[¶](#section-5.1.2.1-1)

A cookie *cookie* is **Host-prefix compatible**
if:[¶](#section-5.1.2.1-2)

1. :::
 *cookie*\'s secure is true;[¶](#section-5.1.2.1-3.1.1)
 :::

2. :::
 *cookie*\'s host-only is true;[¶](#section-5.1.2.1-3.2.1)
 :::

3. :::
 *cookie*\'s has-path attribute is true;
 and[¶](#section-5.1.2.1-3.3.1)
 :::

4. :::
 *cookie*\'s path\'s size is 1 and *cookie*\'s path\[0\] is the empty
 string,[¶](#section-5.1.2.1-3.4.1)
 :::

A cookie *cookie* is **Http-prefix compatible**
if:[¶](#section-5.1.2.1-4)

1. :::
 *cookie*\'s secure is true; and[¶](#section-5.1.2.1-5.1.1)
 :::

2. :::
 *cookie*\'s http-only is false,[¶](#section-5.1.2.1-5.2.1)
 :::

### [5.2.](#section-5.2) [Cookie Store Eviction]
#### [5.2.1.](#section-5.2.1) [Remove Expired Cookies]
1. :::
 Let *expiredCookies* be a list of references to all expired cookies
 in the user agent\'s cookie
 store.[¶](#section-5.2.1-1.1.1)
 :::

2. :::
 For each *cookie* of
 *expiredCookies*:[¶](#section-5.2.1-1.2.1)

 1. :::
 Remove *cookie* from the user agent\'s cookie
 store.[¶](#section-5.2.1-1.2.2.1.1)
 :::
 :::

3. :::
 Return *expiredCookies*.[¶](#section-5.2.1-1.3.1)
 :::

#### [5.2.2.](#section-5.2.2) [Remove Excess Cookies for a Host]
To **Remove Excess Cookies for a Host** given a host
*host*:[¶](#section-5.2.2-1)

1. :::
 Let *insecureCookies* be a list of references to all cookies in the
 user agent\'s cookie store whose host is host-equal to *host* and
 whose secure is false.[¶](#section-5.2.2-2.1.1)
 :::

2. :::
 Sort *insecureCookies* by earliest last-access-time
 first.[¶](#section-5.2.2-2.2.1)
 :::

3. :::
 Let *secureCookies* be a list of references to all cookies in the
 user agent\'s cookie store whose host is host-equal to *host* and
 whose secure is true.[¶](#section-5.2.2-2.3.1)
 :::

4. :::
 Sort *secureCookies* by earliest last-access-time
 first.[¶](#section-5.2.2-2.4.1)
 :::

5. :::
 Let *excessHostCookies* be an empty list of
 cookies.[¶](#section-5.2.2-2.5.1)
 :::

6. :::
 While *insecureCookies*\'s size + *secureCookies*\'s size is greater
 than the user agent\'s total cookies-per-host
 limit:[¶](#section-5.2.2-2.6.1)

 1. :::
 If *insecureCookies* is not
 empty:[¶](#section-5.2.2-2.6.2.1.1)

 1. :::
 Let *cookie* be the first item of
 *insecureCookies*.[¶](#section-5.2.2-2.6.2.1.2.1.1)
 :::

 2. :::
 Remove *cookie* from
 *insecureCookies*.[¶](#section-5.2.2-2.6.2.1.2.2.1)
 :::

 3. :::
 Remove *cookie* from the user agent\'s cookie
 store.[¶](#section-5.2.2-2.6.2.1.2.3.1)
 :::

 4. :::
 Append *cookie* to
 *excessHostCookies*.[¶](#section-5.2.2-2.6.2.1.2.4.1)
 :::
 :::

 2. :::
 Otherwise:[¶](#section-5.2.2-2.6.2.2.1)

 1. :::
 Let *cookie* be the first item of
 *secureCookies*.[¶](#section-5.2.2-2.6.2.2.2.1.1)
 :::

 2. :::
 Remove *cookie* from
 *secureCookies*.[¶](#section-5.2.2-2.6.2.2.2.2.1)
 :::

 3. :::
 Remove *cookie* from the user agent\'s cookie
 store.[¶](#section-5.2.2-2.6.2.2.2.3.1)
 :::

 4. :::
 Append *cookie* to
 *excessHostCookies*.[¶](#section-5.2.2-2.6.2.2.2.4.1)
 :::
 :::
 :::

7. :::
 Return *excessHostCookies*.[¶](#section-5.2.2-2.7.1)
 :::

#### [5.2.3.](#section-5.2.3) [Remove Global Excess Cookies]
To **Remove Global Excess Cookies**:[¶](#section-5.2.3-1)

1. :::
 Let *allCookies* be the result of sorting the user agent\'s cookie
 store by earliest last-access-time
 first.[¶](#section-5.2.3-2.1.1)
 :::

2. :::
 Let *excessGlobalCookies* be an empty list of
 cookies.[¶](#section-5.2.3-2.2.1)
 :::

3. :::
 While *allCookies*\'s size is greater than the user agent\'s total
 cookies limit:[¶](#section-5.2.3-2.3.1)

 1. :::
 Let *cookie* be the first item of
 *allCookies*.[¶](#section-5.2.3-2.3.2.1.1)
 :::

 2. :::
 Remove *cookie* from
 *allCookies*.[¶](#section-5.2.3-2.3.2.2.1)
 :::

 3. :::
 Remove *cookie* from the user agent\'s cookie
 store.[¶](#section-5.2.3-2.3.2.3.1)
 :::

 4. :::
 Append *cookie* to
 *excessGlobalCookies*.[¶](#section-5.2.3-2.3.2.4.1)
 :::
 :::

4. :::
 Return *excessGlobalCookies*.[¶](#section-5.2.3-2.4.1)
 :::

### [5.3.](#section-5.3) [Subcomponent Algorithms]
This section defines some algorithms used by user agents to process
specific subcomponents of the `Cookie` and `Set-Cookie` header
fields.[¶](#section-5.3-1)

#### [5.3.1.](#section-5.3.1) [Parse a Date]
To **Parse a Date** given a byte sequence *input*, run these steps. They
return a date and time or failure.[¶](#section-5.3.1-1)

Note that the various boolean flags defined as a part of the algorithm
(i.e., found-time, found-day-of-month, found-month, found-year) are
initially \"not set\".[¶](#section-5.3.1-2)

1. ::::
 Using the grammar below, divide the cookie-date into
 date-tokens.[¶](#section-5.3.1-3.1.1)

 :::

 cookie-date = *delimiter date-token-list *delimiter
 date-token-list = date-token *( 1*delimiter date-token )
 date-token = 1*non-delimiter

 delimiter = %x09 / %x20-2F / %x3B-40 / %x5B-60 / %x7B-7E
 non-delimiter = %x00-08 / %x0A-1F / DIGIT / ":" / ALPHA
 / %x7F-FF
 non-digit = %x00-2F / %x3A-FF

 day-of-month = 1*2DIGIT [ non-digit *OCTET ]
 month = ( "jan" / "feb" / "mar" / "apr" /
 "may" / "jun" / "jul" / "aug" /
 "sep" / "oct" / "nov" / "dec" ) *OCTET
 year = 2*4DIGIT [ non-digit *OCTET ]
 time = hms-time [ non-digit *OCTET ]
 hms-time = time-field ":" time-field ":" time-field
 time-field = 1*2DIGIT

 [¶](#section-5.3.1-3.1.2)
 :::
 ::::

2. :::
 Process each date-token sequentially in the order the date-tokens
 appear in the cookie-date:[¶](#section-5.3.1-3.2.1)

 1. :::
 If the found-time flag is not set and the token matches the time
 production, set the found-time flag and set the hour-value,
 minute-value, and second-value to the numbers denoted by the
 digits in the date-token, respectively. Skip the remaining
 sub-steps and continue to the next
 date-token.[¶](#section-5.3.1-3.2.2.1.1)
 :::

 2. :::
 If the found-day-of-month flag is not set and the date-token
 matches the day-of-month production, set the found-day-of-month
 flag and set the day-of-month-value to the number denoted by the
 date-token. Skip the remaining sub-steps and continue to the
 next date-token.[¶](#section-5.3.1-3.2.2.2.1)
 :::

 3. :::
 If the found-month flag is not set and the date-token matches
 the month production, set the found-month flag and set the
 month-value to the month denoted by the date-token. Skip the
 remaining sub-steps and continue to the next
 date-token.[¶](#section-5.3.1-3.2.2.3.1)
 :::

 4. :::
 If the found-year flag is not set and the date-token matches the
 year production, set the found-year flag and set the year-value
 to the number denoted by the date-token. Skip the remaining
 sub-steps and continue to the next
 date-token.[¶](#section-5.3.1-3.2.2.4.1)
 :::
 :::

3. :::
 If the year-value is greater than or equal to 70 and less than or
 equal to 99, increment the year-value by
 1900.[¶](#section-5.3.1-3.3.1)
 :::

4. :::
 If the year-value is greater than or equal to 0 and less than or
 equal to 69, increment the year-value by
 2000.[¶](#section-5.3.1-3.4.1)

 1. :::
 NOTE: Some existing user agents interpret two-digit years
 differently.[¶](#section-5.3.1-3.4.2.1.1)
 :::
 :::

5. :::
 If one of the following is true:[¶](#section-5.3.1-3.5.1)

 - :::
 at least one of the found-day-of-month, found-month, found-year,
 or found-time flags is not
 set,[¶](#section-5.3.1-3.5.2.1.1)
 :::

 - :::
 the day-of-month-value is less than 1 or greater than
 31,[¶](#section-5.3.1-3.5.2.2.1)
 :::

 - :::
 the year-value is less than
 1601,[¶](#section-5.3.1-3.5.2.3.1)
 :::

 - :::
 the hour-value is greater than
 23,[¶](#section-5.3.1-3.5.2.4.1)
 :::

 - :::
 the minute-value is greater than 59,
 or[¶](#section-5.3.1-3.5.2.5.1)
 :::

 - :::
 the second-value is greater than
 59,[¶](#section-5.3.1-3.5.2.6.1)
 :::

 then return failure.[¶](#section-5.3.1-3.5.3)

 (Note that leap seconds cannot be represented in this
 syntax.)[¶](#section-5.3.1-3.5.4)
 :::

6. :::
 Let the parsed-cookie-date be the date whose day-of-month, month,
 year, hour, minute, and second (in UTC) are the day-of-month-value,
 the month-value, the year-value, the hour-value, the minute-value,
 and the second-value, respectively. If no such date exists, abort
 these steps and fail to parse the
 cookie-date.[¶](#section-5.3.1-3.6.1)
 :::

7. :::
 Return the parsed-cookie-date as the result of this
 algorithm.[¶](#section-5.3.1-3.7.1)
 :::

#### [5.3.2.](#section-5.3.2) [Domain Matching]
A host *host* **Domain-Matches** a string *domainAttributeValue* if at
least one of the following is true:[¶](#section-5.3.2-1)

- :::
 *host* equals *domainAttributeValue*,
 or[¶](#section-5.3.2-2.1.1)
 :::

- :::
 if all of the following are true:[¶](#section-5.3.2-2.2.1)

 - :::
 *host* is a domain, and[¶](#section-5.3.2-2.2.2.1.1)
 :::

 - :::
 *host* ends with the concatenation of U+002E (.) and
 *domainAttributeValue*.[¶](#section-5.3.2-2.2.2.2.1)
 :::
 :::

#### [5.3.3.](#section-5.3.3) [Cookie Default Path]
To determine the **Cookie Default Path**, given a URL path *path*, run
these steps. They return a URL path.[¶](#section-5.3.3-1)

1. :::
 Assert: *path* is a non-empty
 list.[¶](#section-5.3.3-2.1.1)
 :::

2. :::
 If *path*\'s size is greater than 1, then remove *path*\'s last
 item.[¶](#section-5.3.3-2.2.1)
 :::

3. :::
 Otherwise, set *path*\[0\] to the empty
 string.[¶](#section-5.3.3-2.3.1)
 :::

4. :::
 Return *path*.[¶](#section-5.3.3-2.4.1)
 :::

#### [5.3.4.](#section-5.3.4) [Path Matching]
To determine if a URL path *requestPath* **Path-Matches** a URL path
*cookiePath*, run these steps. They return a
boolean.[¶](#section-5.3.4-1)

1. :::
 Let *serializedRequestPath* be the result of URL path serializing
 *requestPath*.[¶](#section-5.3.4-2.1.1)
 :::

2. :::
 Let *serializedCookiePath* be the result of URL path serializing
 *cookiePath*.[¶](#section-5.3.4-2.2.1)
 :::

3. :::
 If *serializedCookiePath* is *serializedRequestPath*, then return
 true.[¶](#section-5.3.4-2.3.1)
 :::

4. :::
 If *serializedRequestPath* starts with *serializedCookiePath* and
 *serializedCookiePath* ends with a U+002F (/), then return
 true.[¶](#section-5.3.4-2.4.1)
 :::

5. :::
 Return whether the concatenation of *serializedRequestPath* followed
 by U+002F (/) starts with
 *serializedCookiePath*.[¶](#section-5.3.4-2.5.1)
 :::

### [5.4.](#section-5.4) [Main Algorithms]
#### [5.4.1.](#section-5.4.1) [Parse and Store a Cookie]
To **Parse and Store a Cookie** given a byte sequence *input*, boolean
*isSecure*, domain or IP address *host*, URL path *path*, boolean
*httpOnlyAllowed*, boolean *allowNonHostOnlyCookieForPublicSuffix*, and
boolean *sameSiteStrictOrLaxAllowed*:[¶](#section-5.4.1-1)

1. :::
 Let *cookie* be the result of running Parse a Cookie with *input*,
 *isSecure*, *host*, and *path*.[¶](#section-5.4.1-2.1.1)
 :::

2. :::
 If *cookie* is failure, then
 return.[¶](#section-5.4.1-2.2.1)
 :::

3. :::
 Return the result of Store a Cookie given *cookie*, *isSecure*,
 *host*, *path*, *httpOnlyAllowed*,
 *allowNonHostOnlyCookieForPublicSuffix*, and
 *sameSiteStrictOrLaxAllowed*.[¶](#section-5.4.1-2.3.1)
 :::

#### [5.4.2.](#section-5.4.2) [Parse a Cookie]
To **Parse a Cookie** given a byte sequence *input*, boolean *isSecure*,
host *host*, URL path *path*, run these steps. They return a new cookie
or failure:[¶](#section-5.4.2-1)

1. :::
 If *input* contains a byte in the range 0x00 to 0x08, inclusive, the
 range 0x0A to 0x1F inclusive, or 0x7F (CTL bytes excluding HTAB),
 then return failure.[¶](#section-5.4.2-2.1.1)
 :::

2. :::
 Let *nameValueInput* be null.[¶](#section-5.4.2-2.2.1)
 :::

3. :::
 Let *attributesInput* be the empty byte
 sequence.[¶](#section-5.4.2-2.3.1)
 :::

4. :::
 If *input* contains 0x3B (;), then set *nameValueInput* to the bytes
 up to, but not including, the first 0x3B (;), and *attributesInput*
 to the remainder of *input* (including the 0x3B (;) in
 question).[¶](#section-5.4.2-2.4.1)
 :::

5. :::
 Otherwise, set *nameValueInput* to
 *input*.[¶](#section-5.4.2-2.5.1)
 :::

6. :::
 Assert: *nameValueInput* is a byte
 sequence.[¶](#section-5.4.2-2.6.1)
 :::

7. :::
 Let *name* be null.[¶](#section-5.4.2-2.7.1)
 :::

8. :::
 Let *value* be null.[¶](#section-5.4.2-2.8.1)
 :::

9. :::
 If *nameValueInput* does not contain a 0x3D (=) character, then set
 *name* to the empty byte sequence, and *value* to
 *nameValueInput*.[¶](#section-5.4.2-2.9.1)
 :::

10. :::
 Otherwise, set *name* to the bytes up to, but not including, the
 first 0x3D (=), and set *value* to the bytes after the first 0x3D
 (=) (possibly being the empty byte
 sequence).[¶](#section-5.4.2-2.10.1)
 :::

11. :::
 Remove any leading or trailing WSP bytes from *name* and
 *value*.[¶](#section-5.4.2-2.11.1)
 :::

12. :::
 If *name*\'s length + *value*\'s length is 0 or is greater than
 4096, then return failure.[¶](#section-5.4.2-2.12.1)
 :::

13. :::
 Let *cookie* be a new cookie whose name is *name* and value is
 *value*.[¶](#section-5.4.2-2.13.1)
 :::

14. :::
 Set *cookie*\'s path to the result of running Cookie Default Path
 with *path*.[¶](#section-5.4.2-2.14.1)

 Note: A `Path` attribute can override
 this.[¶](#section-5.4.2-2.14.2)
 :::

15. :::
 While *attributesInput* is not an empty byte
 sequence:[¶](#section-5.4.2-2.15.1)

 1. :::
 Let *maxAgeSeen* be
 false.[¶](#section-5.4.2-2.15.2.1.1)
 :::

 2. :::
 Let *char* be the result of consuming the first byte of
 *attributesInput*.[¶](#section-5.4.2-2.15.2.2.1)
 :::

 3. :::
 Assert: *char* is 0x3B
 (;).[¶](#section-5.4.2-2.15.2.3.1)
 :::

 4. :::
 Let *attributeNameValueInput* be
 null.[¶](#section-5.4.2-2.15.2.4.1)
 :::

 5. :::
 If *attributesInput* contains 0x3B (;), then set
 *attributeNameValueInput* to the result of consuming the bytes
 of *attributesInput* up to, but not including, the first 0x3B
 (;).[¶](#section-5.4.2-2.15.2.5.1)
 :::

 6. :::
 Otherwise, set *attributeNameValueInput* to the result of
 consuming the remainder of
 *attributesInput*.[¶](#section-5.4.2-2.15.2.6.1)
 :::

 7. :::
 Let *attributeName* be
 null.[¶](#section-5.4.2-2.15.2.7.1)
 :::

 8. :::
 Let *attributeValue* be the empty
 string.[¶](#section-5.4.2-2.15.2.8.1)
 :::

 9. :::
 If *attributeNameValueInput* contains a 0x3D (=), then set
 *attributeName* to the bytes up to, but not including, the first
 0x3D (=) of *attributeNameValueInput*, and *attributeValue* to
 the bytes after the first 0x3D (=) of
 *attributeNameValueInput*.[¶](#section-5.4.2-2.15.2.9.1)
 :::

 10. :::
 Otherwise, set *attributeName* to
 *attributeNameValueInput*.[¶](#section-5.4.2-2.15.2.10.1)
 :::

 11. :::
 Remove any leading or trailing WSP bytes from *attributeName*
 and *attributeValue*.[¶](#section-5.4.2-2.15.2.11.1)
 :::

 12. :::
 If *attributeValue*\'s length is greater than 1024, then
 continue.[¶](#section-5.4.2-2.15.2.12.1)
 :::

 13. :::
 If *attributeName* is a byte-case-insensitive match for
 `Expires`:[¶](#section-5.4.2-2.15.2.13.1)

 1. :::
 If *maxAgeSeen* is true, then
 continue.[¶](#section-5.4.2-2.15.2.13.2.1.1)
 :::

 2. :::
 Let *expiryTime* be the result of running Parse a Date given
 *attributeValue*.[¶](#section-5.4.2-2.15.2.13.2.2.1)
 :::

 3. :::
 If *attributeValue* is failure, then
 continue.[¶](#section-5.4.2-2.15.2.13.2.3.1)
 :::

 4. :::
 If *expiryTime* is greater than the current time and date +
 the user agent\'s cookie age limit, then set *expiryTime* to
 the user agent\'s cookie age
 limit.[¶](#section-5.4.2-2.15.2.13.2.4.1)
 :::

 5. :::
 If *expiryTime* is earlier than the earliest date the user
 agent can represent, the user agent MAY replace *expiryTime*
 with the earliest representable
 date.[¶](#section-5.4.2-2.15.2.13.2.5.1)
 :::

 6. :::
 Set *cookie*\'s expiry-time to
 *expiryTime*.[¶](#section-5.4.2-2.15.2.13.2.6.1)
 :::
 :::

 14. :::
 If *attributeName* is a byte-case-insensitive match for
 `Max-Age`:[¶](#section-5.4.2-2.15.2.14.1)

 1. :::
 If *attributeValue* is empty,
 continue.[¶](#section-5.4.2-2.15.2.14.2.1.1)
 :::

 2. :::
 If the first byte of *attributeValue* is neither a DIGIT,
 nor 0x2D (-) followed by a DIGIT, then
 continue.[¶](#section-5.4.2-2.15.2.14.2.2.1)
 :::

 3. :::
 If the remainder of *attributeValue* contains a non-DIGIT,
 then continue.[¶](#section-5.4.2-2.15.2.14.2.3.1)
 :::

 4. :::
 Let *deltaSeconds* be *attributeValue*, converted to a base
 10 integer.[¶](#section-5.4.2-2.15.2.14.2.4.1)
 :::

 5. :::
 Set *deltaSeconds* to the smaller of *deltaSeconds* and the
 user agent\'s cookie age limit, in
 seconds.[¶](#section-5.4.2-2.15.2.14.2.5.1)
 :::

 6. :::
 If *deltaSeconds* is less than or equal to 0, let
 *expiryTime* be the earliest representable date and time.
 Otherwise, let *expiryTime* be the current date and time +
 *deltaSeconds*
 seconds.[¶](#section-5.4.2-2.15.2.14.2.6.1)
 :::

 7. :::
 Set *cookie*\'s expiry-time to
 *expiryTime*.[¶](#section-5.4.2-2.15.2.14.2.7.1)
 :::

 8. :::
 Set *maxAgeSeen* to
 true.[¶](#section-5.4.2-2.15.2.14.2.8.1)
 :::
 :::

 15. :::
 If *attributeName* is a byte-case-insensitive match for
 `Domain`:[¶](#section-5.4.2-2.15.2.15.1)

 1. :::
 Let *host* be
 failure.[¶](#section-5.4.2-2.15.2.15.2.1.1)
 :::

 2. :::
 If *attributeValue* contains only ASCII
 bytes:[¶](#section-5.4.2-2.15.2.15.2.2.1)

 1. :::
 Let *hostInput* be *attributeValue*, ASCII
 decoded.[¶](#section-5.4.2-2.15.2.15.2.2.2.1.1)
 :::

 2. :::
 If *hostInput* starts with U+002E (.), then set
 *hostInput* to *hostInput* without its leading U+002E
 (.).[¶](#section-5.4.2-2.15.2.15.2.2.2.2.1)
 :::

 3. :::
 Set *host* to the result of host parsing
 *hostInput*.[¶](#section-5.4.2-2.15.2.15.2.2.2.3.1)
 :::
 :::

 3. :::
 Set *cookie*\'s host to
 *host*.[¶](#section-5.4.2-2.15.2.15.2.3.1)
 :::
 :::

 16. :::
 If *attributeName* is a byte-case-insensitive match for
 `Path`:[¶](#section-5.4.2-2.15.2.16.1)

 1. :::
 If *attributeValue* is not empty and if the first byte of
 *attributeValue* is 0x2F (/),
 then:[¶](#section-5.4.2-2.15.2.16.2.1.1)

 1. :::
 Set *cookie*\'s path to *attributeValue* split on 0x2F
 (/).[¶](#section-5.4.2-2.15.2.16.2.1.2.1.1)
 :::

 2. :::
 Set *cookie*\'s has-path attribute to
 true.[¶](#section-5.4.2-2.15.2.16.2.1.2.2.1)
 :::
 :::
 :::

 17. :::
 If *attributeName* is a byte-case-insensitive match for
 `Secure`:[¶](#section-5.4.2-2.15.2.17.1)

 1. :::
 Set *cookie*\'s secure to
 true.[¶](#section-5.4.2-2.15.2.17.2.1.1)
 :::
 :::

 18. :::
 If *attributeName* is a byte-case-insensitive match for
 `HttpOnly`:[¶](#section-5.4.2-2.15.2.18.1)

 1. :::
 Set *cookie*\'s http-only to
 true.[¶](#section-5.4.2-2.15.2.18.2.1.1)
 :::
 :::

 19. :::
 If *attributeName* is a byte-case-insensitive match for
 `SameSite`:[¶](#section-5.4.2-2.15.2.19.1)

 1. :::
 If *attributeValue* is a byte-case-insensitive match for
 `None`, then set *cookie*\'s same-site to
 \"none\".[¶](#section-5.4.2-2.15.2.19.2.1.1)
 :::

 2. :::
 If *attributeValue* is a byte-case-insensitive match for
 `Strict`, then set *cookie*\'s same-site to
 \"strict\".[¶](#section-5.4.2-2.15.2.19.2.2.1)
 :::

 3. :::
 If *attributeValue* is a byte-case-insensitive match for
 `Lax`, then set *cookie*\'s same-site to
 \"lax\".[¶](#section-5.4.2-2.15.2.19.2.3.1)
 :::
 :::
 :::

16. :::
 Return *cookie*.[¶](#section-5.4.2-2.16.1)
 :::

Note: Attributes with an unrecognized *attributeName* are
ignored.[¶](#section-5.4.2-3)

Note: This intentionally overrides earlier cookie attributes so that
generally the last specified cookie attribute
\"wins\".[¶](#section-5.4.2-4)

#### [5.4.3.](#section-5.4.3) [Store a Cookie]
To **Store a Cookie** given a cookie *cookie*, boolean *isSecure*,
domain or IP address *host*, boolean *httpOnlyAllowed*, boolean
*allowNonHostOnlyCookieForPublicSuffix*, and boolean
*sameSiteStrictOrLaxAllowed*:[¶](#section-5.4.3-1)

1. :::
 Assert: *cookie*\'s name\'s length + *cookie*\'s value\'s length is
 not 0 or greater than 4096.[¶](#section-5.4.3-2.1.1)
 :::

2. :::
 Assert: *cookie*\'s name does not contain a byte in the range 0x00
 to 0x08, inclusive, in the range 0x0A to 0x1F, inclusive, or 0x7F
 (CTL characters excluding HTAB).[¶](#section-5.4.3-2.2.1)
 :::

3. :::
 If *cookie*\'s host is failure, then return
 null.[¶](#section-5.4.3-2.3.1)
 :::

4. :::
 Set *cookie*\'s creation-time and last-access-time to the current
 date and time.[¶](#section-5.4.3-2.4.1)
 :::

5. :::
 If *allowNonHostOnlyCookieForPublicSuffix* is false and *cookie*\'s
 host is a public suffix:[¶](#section-5.4.3-2.5.1)

 1. :::
 If *cookie*\'s host is host-equal to *host*, then set
 *cookie*\'s host to null.[¶](#section-5.4.3-2.5.2.1.1)
 :::

 2. :::
 Otherwise, return null.[¶](#section-5.4.3-2.5.2.2.1)
 :::

 Note: This step prevents `attacker.example` from disrupting the
 integrity of `site.example` by setting a cookie with a `Domain`
 attribute of `example`. In the event the end user navigates directly
 to `example`, a cookie can still be set and will forcibly have its
 host-only set to true.[¶](#section-5.4.3-2.5.3)
 :::

6. :::
 If *cookie*\'s host is null:[¶](#section-5.4.3-2.6.1)

 1. :::
 Set *cookie*\'s host-only to
 true.[¶](#section-5.4.3-2.6.2.1.1)
 :::

 2. :::
 Set *cookie*\'s host to
 *host*.[¶](#section-5.4.3-2.6.2.2.1)
 :::
 :::

7. :::
 Otherwise:[¶](#section-5.4.3-2.7.1)

 1. :::
 If *host* does not Domain-Match *cookie*\'s host, then return
 null.[¶](#section-5.4.3-2.7.2.1.1)
 :::

 2. :::
 Set *cookie*\'s host-only to
 false.[¶](#section-5.4.3-2.7.2.2.1)
 :::
 :::

8. :::
 Assert: *cookie*\'s host is a domain or IP
 address.[¶](#section-5.4.3-2.8.1)
 :::

9. :::
 If *httpOnlyAllowed* is false and *cookie*\'s http-only is true,
 then return null.[¶](#section-5.4.3-2.9.1)
 :::

10. :::
 If *isSecure* is false:[¶](#section-5.4.3-2.10.1)

 1. :::
 If *cookie*\'s secure is true, then return
 null.[¶](#section-5.4.3-2.10.2.1.1)
 :::

 2. :::
 If the user agent\'s cookie store contains at least one cookie
 *existingCookie* that meets all of the following
 criteria:[¶](#section-5.4.3-2.10.2.2.1)

 1. :::
 *existingCookie*\'s name is *cookie*\'s
 name;[¶](#section-5.4.3-2.10.2.2.2.1.1)
 :::

 2. :::
 *existingCookie*\'s secure is
 true;[¶](#section-5.4.3-2.10.2.2.2.2.1)
 :::

 3. :::
 *existingCookie*\'s host Domain-Matches *cookie*\'s host, or
 vice-versa; and[¶](#section-5.4.3-2.10.2.2.2.3.1)
 :::

 4. :::
 *cookie*\'s path Path-Matches *existingCookie*\'s
 path,[¶](#section-5.4.3-2.10.2.2.2.4.1)
 :::

 then return null.[¶](#section-5.4.3-2.10.2.2.3)

 Note: The path comparison is not symmetric, ensuring only that a
 newly-created, non-secure cookie does not overlay an existing
 secure cookie, providing some mitigation against cookie-fixing
 attacks. That is, given an existing secure cookie named \'a\'
 with a path of \'/login\', a non-secure cookie named \'a\' could
 be set for a path of \'/\' or \'/foo\', but not for a path of
 \'/login\' or
 \'/login/en\'.[¶](#section-5.4.3-2.10.2.2.4)
 :::
 :::

11. :::
 If *cookie*\'s same-site is not \"`none`\" and
 *sameSiteStrictOrLaxAllowed* is false, then return
 null.[¶](#section-5.4.3-2.11.1)
 :::

12. :::
 If *cookie*\'s same-site is \"`none`\" and *cookie*\'s secure is
 false, then return null.[¶](#section-5.4.3-2.12.1)
 :::

13. :::
 If *cookie*\'s name, byte-lowercased, starts with `__secure-` and
 *cookie*\'s secure is false, then return
 null.[¶](#section-5.4.3-2.13.1)

 Note: The check here and those below are with a byte-lowercased
 value in order to protect servers that process these values in a
 case-insensitive manner.[¶](#section-5.4.3-2.13.2)
 :::

14. :::
 If *cookie*\'s name, byte-lowercased, starts with `__host-` and
 *cookie* is not Host-prefix compatible, then return
 null.[¶](#section-5.4.3-2.14.1)
 :::

15. :::
 If *cookie*\'s name, byte-lowercased, starts with `__http-` and
 *cookie* is not Http-prefix compatible, then return
 null.[¶](#section-5.4.3-2.15.1)
 :::

16. :::
 If *cookie*\'s name, byte-lowercased, starts with `__host-http-` and
 *cookie* is not both Host-prefix compatible and Http-prefix
 compatible, then return null.[¶](#section-5.4.3-2.16.1)
 :::

17. :::
 If *cookie*\'s name is the empty byte sequence and one of the
 following is true:[¶](#section-5.4.3-2.17.1)

 - :::
 *cookie*\'s value, byte-lowercased, starts with
 `__secure-`,[¶](#section-5.4.3-2.17.2.1.1)
 :::

 - :::
 *cookie*\'s value, byte-lowercased, starts with
 `__host-`,[¶](#section-5.4.3-2.17.2.2.1)
 :::

 - :::
 *cookie*\'s value, byte-lowercased, starts with `__http-`,
 or[¶](#section-5.4.3-2.17.2.3.1)
 :::

 - :::
 *cookie*\'s value, byte-lowercased, starts with
 `__host-http-`,[¶](#section-5.4.3-2.17.2.4.1)
 :::

 then return null.[¶](#section-5.4.3-2.17.3)
 :::

18. :::
 If the user agent\'s cookie store contains a cookie *oldCookie*
 whose name is *cookie*\'s name, host is host-equal to *cookie*\'s
 host, host-only is *cookie*\'s host-only, and path is path-equal to
 *cookie*\'s path:[¶](#section-5.4.3-2.18.1)

 1. :::
 If *httpOnlyAllowed* is false and *oldCookie*\'s http-only is
 true, then return null.[¶](#section-5.4.3-2.18.2.1.1)
 :::

 2. :::
 If *cookie*\'s secure is equal to *oldCookie*\'s secure,
 *cookie*\'s same-site is equal to *oldCookie*\'s same-site, and
 *cookie*\'s expiry-time is equal to *oldCookie*\'s expiry-time,
 then return null.[¶](#section-5.4.3-2.18.2.2.1)
 :::

 3. :::
 Set *cookie*\'s creation-time to *oldCookie*\'s
 creation-time.[¶](#section-5.4.3-2.18.2.3.1)
 :::

 4. :::
 Remove *oldCookie* from the user agent\'s cookie
 store.[¶](#section-5.4.3-2.18.2.4.1)
 :::

 Note: This algorithm maintains the invariant that there is at most
 one such cookie.[¶](#section-5.4.3-2.18.3)
 :::

19. :::
 Insert *cookie* into the user agent\'s cookie
 store.[¶](#section-5.4.3-2.19.1)
 :::

20. :::
 Return *cookie*.[¶](#section-5.4.3-2.20.1)
 :::

#### [5.4.4.](#section-5.4.4) [Garbage Collect Cookies]
To **Garbage Collect Cookies** given a host
*host*:[¶](#section-5.4.4-1)

1. :::
 Let *expiredCookies* be the result of running Remove Expired
 Cookies.[¶](#section-5.4.4-2.1.1)
 :::

2. :::
 Let *excessHostCookies* be the result of running Remove Excess
 Cookies for Host given *host*.[¶](#section-5.4.4-2.2.1)
 :::

3. :::
 Let *excessGlobalCookies* be the result of running Remove Global
 Excess Cookies.[¶](#section-5.4.4-2.3.1)
 :::

4. :::
 Let *removedCookies* be « ».[¶](#section-5.4.4-2.4.1)
 :::

5. :::
 For each *cookieList* of « *expiredCookies*, *excessHostCookies*,
 *excessGlobalCookies* », do the
 following:[¶](#section-5.4.4-2.5.1)

 1. :::
 Extend *removedCookies* with
 *cookieList*.[¶](#section-5.4.4-2.5.2.1.1)
 :::
 :::

6. :::
 Return *removedCookies*[¶](#section-5.4.4-2.6.1)
 :::

#### [5.4.5.](#section-5.4.5) [Retrieve Cookies]
To **Retrieve Cookies** given a boolean *isSecure*, host *host*, URL
path *path*, boolean *httpOnlyAllowed*, and string
*sameSite*:[¶](#section-5.4.5-1)

1. :::
 Assert: *sameSite* is \"`strict-or-less`\", \"`lax-or-less`\",
 \"`unset-or-less`\", or
 \"`none`\".[¶](#section-5.4.5-2.1.1)
 :::

2. :::
 Let *cookies* be all cookies from the user agent\'s cookie store
 that meet these conditions:[¶](#section-5.4.5-2.2.1)

 - :::
 One of the following is
 true:[¶](#section-5.4.5-2.2.2.1.1)

 - :::
 cookie\'s host-only is true and *host* is host-equal to
 cookie\'s host, or[¶](#section-5.4.5-2.2.2.1.2.1.1)
 :::

 - :::
 cookie\'s host-only is false and *host* Domain-Matches cookie\'s
 host.[¶](#section-5.4.5-2.2.2.1.2.2.1)
 :::

 It\'s possible that the public suffix list changed since a cookie
 was created. If this change results in a cookie\'s host becoming a
 public suffix and the cookie\'s host-only is false, then that
 cookie SHOULD NOT be
 returned.[¶](#section-5.4.5-2.2.2.1.3)

 XXX: We should probably move this requirement out-of-bound as this
 invalidation should happen as part of updating the public
 suffixes.[¶](#section-5.4.5-2.2.2.1.4)
 :::

 - :::
 *path* Path-Matches cookie\'s
 path.[¶](#section-5.4.5-2.2.2.2.1)
 :::

 - :::
 One of the following is
 true:[¶](#section-5.4.5-2.2.2.3.1)

 - :::
 cookie\'s secure is true and *isSecure* is true,
 or[¶](#section-5.4.5-2.2.2.3.2.1.1)
 :::

 - :::
 cookie\'s secure is
 false.[¶](#section-5.4.5-2.2.2.3.2.2.1)
 :::
 :::

 - :::
 One of the following is
 true:[¶](#section-5.4.5-2.2.2.4.1)

 - :::
 cookie\'s http-only is true and *httpOnlyAllowed* is true,
 or[¶](#section-5.4.5-2.2.2.4.2.1.1)
 :::

 - :::
 cookie\'s http-only is
 false.[¶](#section-5.4.5-2.2.2.4.2.2.1)
 :::
 :::

 - :::
 One of the following is
 true:[¶](#section-5.4.5-2.2.2.5.1)

 - :::
 cookie\'s same-site is \"`strict`\" and *sameSite* is
 \"`strict-or-less`\";[¶](#section-5.4.5-2.2.2.5.2.1.1)
 :::

 - :::
 cookie\'s same-site is \"`lax`\" and *sameSite* is one of
 \"`strict-or-less`\" or
 \"`lax-or-less`\";[¶](#section-5.4.5-2.2.2.5.2.2.1)
 :::

 - :::
 cookie\'s same-site is \"`unset`\" and *sameSite* is one of
 \"`strict-or-less`\", \"`lax-or-less`\", or \"`unset-or-less`\";
 or[¶](#section-5.4.5-2.2.2.5.2.3.1)
 :::

 - :::
 cookie\'s same-site is
 \"`none`\".[¶](#section-5.4.5-2.2.2.5.2.4.1)
 :::
 :::
 :::

3. :::
 Sort *cookies* in the following
 order:[¶](#section-5.4.5-2.3.1)

 - :::
 Cookies whose path\'s size is greater are listed before cookies
 whose path\'s size is
 smaller.[¶](#section-5.4.5-2.3.2.1.1)
 :::

 - :::
 Among cookies whose path\'s size is equal, cookies whose
 creation-time is earlier are listed before cookies whose
 creation-time is later.[¶](#section-5.4.5-2.3.2.2.1)
 :::
 :::

4. :::
 Set the last-access-time of each cookie of *cookies* to the current
 date and time and reflect these changes in the user agent\'s cookie
 store.[¶](#section-5.4.5-2.4.1)
 :::

5. :::
 Return *cookies*.[¶](#section-5.4.5-2.5.1)
 :::

#### [5.4.6.](#section-5.4.6) [Serialize Cookies]
To **Serialize Cookies** given a list of cookies
*cookies*:[¶](#section-5.4.6-1)

1. :::
 Let *output* be an empty byte
 sequence.[¶](#section-5.4.6-2.1.1)
 :::

2. :::
 For each *cookie* of *cookies*:[¶](#section-5.4.6-2.2.1)

 1. :::
 If *output* is not the empty byte sequence, then append 0x3B (;)
 followed by 0x20 (SP) to
 *output*.[¶](#section-5.4.6-2.2.2.1.1)
 :::

 2. :::
 If *cookie*\'s name is not the empty byte sequence, then append
 *cookie*\'s name followed by 0x3D (=) to
 *output*.[¶](#section-5.4.6-2.2.2.2.1)
 :::

 3. :::
 Append *cookie*\'s value to
 *output*.[¶](#section-5.4.6-2.2.2.3.1)
 :::
 :::

3. :::
 Return *output*.[¶](#section-5.4.6-2.3.1)
 :::

### [5.5.](#section-5.5) [Requirements Specific to Non-Browser User Agents]
#### [5.5.1.](#section-5.5.1) [The Set-Cookie Header Field]
When a user agent receives a `Set-Cookie` header field in an HTTP
response, the user agent MAY ignore the `Set-Cookie` header field in its
entirety as per its cookie policy (see [Section
7.2](#cookie-policy)).[¶](#section-5.5.1-1)

User agents MAY ignore `Set-Cookie` header fields contained in responses
with 100-level status codes.[¶](#section-5.5.1-2)

`Set-Cookie` header fields contained in responses with non-100-level
status codes (including those in responses with 400- and 500-level
status codes) SHOULD be processed as
follows:[¶](#section-5.5.1-3)

1. :::
 Let *isSecure* be a boolean indicating whether request\'s URL\'s
 scheme is deemed secure, in an implementation-defined
 manner.[¶](#section-5.5.1-4.1.1)
 :::

2. :::
 Let *host* be request\'s host.[¶](#section-5.5.1-4.2.1)
 :::

3. :::
 Let *path* be request\'s URL\'s
 path.[¶](#section-5.5.1-4.3.1)
 :::

4. :::
 Let *httpOnlyAllowed* be true.[¶](#section-5.5.1-4.4.1)
 :::

5. :::
 Let *allowNonHostOnlyCookieForPublicSuffix* be a boolean whose value
 is implementation-defined.[¶](#section-5.5.1-4.5.1)
 :::

6. :::
 Let *sameSiteStrictOrLaxAllowed* be a boolean whose value is
 implementation-defined.[¶](#section-5.5.1-4.6.1)
 :::

7. :::
 Let *cookie* be the result of running Parse and Store a Cookie given
 the header field value, *isSecure*, *host*, *path*,
 *httpOnlyAllowed*, *allowNonHostOnlyCookieForPublicSuffix*, and
 *sameSiteStrictOrLaxAllowed*.[¶](#section-5.5.1-4.7.1)
 :::

8. :::
 If *cookie* is null, then return.[¶](#section-5.5.1-4.8.1)
 :::

9. :::
 Run Garbage Collect Cookies given *cookie*\'s
 host.[¶](#section-5.5.1-4.9.1)
 :::

#### [5.5.2.](#section-5.5.2) [The Cookie Header Field]
The user agent includes stored cookies in the `Cookie` request header
field.[¶](#section-5.5.2-1)

When the user agent generates an HTTP request, the user agent MUST NOT
attach more than one `Cookie` header
field.[¶](#section-5.5.2-2)

A user agent MAY omit the `Cookie` header field in its
entirety.[¶](#section-5.5.2-3)

If the user agent does attach a `Cookie` header field to an HTTP
request, the user agent MUST compute its value as
follows:[¶](#section-5.5.2-4)

1. :::
 Let *isSecure* be a boolean indicating whether request\'s URL\'s
 scheme is deemed secure, in an implementation-defined
 manner.[¶](#section-5.5.2-5.1.1)
 :::

2. :::
 Let *host* be request\'s host.[¶](#section-5.5.2-5.2.1)
 :::

3. :::
 Let *path* be request\'s URL\'s
 path.[¶](#section-5.5.2-5.3.1)
 :::

4. :::
 Let *httpOnlyAllowed* be true.[¶](#section-5.5.2-5.4.1)
 :::

5. :::
 Let *sameSite* be a string whose value is implementation-defined,
 but has to be one of \"`strict-or-less`\", \"`lax-or-less`\",
 \"`unset-or-less`\", or
 \"`none`\".[¶](#section-5.5.2-5.5.1)
 :::

6. :::
 Let *cookies* be the result of running Retrieve Cookies given
 *isSecure*, *host*, *path*, *httpOnlyAllowed*, and
 *sameSite*.[¶](#section-5.5.2-5.6.1)
 :::

7. :::
 Return the result of running Serialize Cookies given
 *cookies*.[¶](#section-5.5.2-5.7.1)
 :::

Note: Previous versions of this specification required that only one
Cookie header field be sent in requests. This is no longer a
requirement. While this specification requires that a single
cookie-string be produced, some user agents may split that string across
multiple `Cookie` header fields. For examples, see [Section
8.2.3](https://rfc-editor.org/rfc/rfc9113#section-8.2.3) of
\[[RFC9113](#RFC9113)\] and [Section
4.2.1](https://rfc-editor.org/rfc/rfc9114#section-4.2.1) of
\[[HTTP](#RFC9114)\].[¶](#section-5.5.2-6)

#### [5.5.3.](#section-5.5.3) [Cookie Store Eviction for Non-Browser User Agents]
The user agent SHOULD evict all expired cookies from its cookie store
if, at any time, an expired cookie exists in the cookie store, by
calling Remove Expired Cookies.[¶](#section-5.5.3-1)

When \"the current session is over\" (as defined by the user agent), the
user agent MUST remove from the cookie store all cookies whose
expiry-time is null.[¶](#section-5.5.3-2)

### [5.6.](#section-5.6) [Requirements Specific to Browser User Agents]
While browsers are expected to generally follow the same model as
non-browser user agents, they have additional complexity due to the
document model (and the ability to nest documents) that is considered
out-of-scope for this specification.[¶](#section-5.6-1)

Specifications for such a user agent are expected to build upon the
following algorithms and invoke them appropriately to process `Cookie`
and `Set-Cookie` header fields, as well as manipulating the user
agent\'s cookie store through non-HTTP
APIs:[¶](#section-5.6-2)

- :::
 Parse and Store a Cookie[¶](#section-5.6-3.1.1)
 :::

- :::
 Store a Cookie[¶](#section-5.6-3.2.1)
 :::

- :::
 Remove Expired Cookies[¶](#section-5.6-3.3.1)
 :::

- :::
 Garbage Collect Cookies[¶](#section-5.6-3.4.1)
 :::

- :::
 Retrieve Cookies[¶](#section-5.6-3.5.1)
 :::

- :::
 Serialize Cookies[¶](#section-5.6-3.6.1)
 :::

This provides the flexibility browsers need to detail their requirements
in considerable detail.[¶](#section-5.6-4)

## [6.](#section-6) [Implementation Considerations]
### [6.1.](#section-6.1) [Limits]
Servers SHOULD use as few and as small cookies as possible to avoid
reaching these implementation limits, minimize network bandwidth due to
the `Cookie` header field being included in every request, and to avoid
reaching server header field limits (See [Section
4.2.1](#server-syntax)).[¶](#section-6.1-1)

Servers SHOULD gracefully degrade if the user agent fails to return one
or more cookies in the `Cookie` header field because the user agent
might evict any cookie at any time.[¶](#section-6.1-2)

### [6.2.](#section-6.2) [Application Programming Interfaces]
One reason the `Cookie` and `Set-Cookie` header fields use such esoteric
syntax is that many platforms (both in servers and user agents) provide
a string-based application programming interface (API) to cookies,
requiring application-layer programmers to generate and parse the syntax
used by the `Cookie` and `Set-Cookie` header fields, which many
programmers have done incorrectly, resulting in interoperability
problems.[¶](#section-6.2-1)

Instead of providing string-based APIs to cookies, platforms would be
well-served by providing more semantic APIs. It is beyond the scope of
this document to recommend specific API designs, but there are clear
benefits to accepting an abstract \"Date\" object instead of a
serialized date string.[¶](#section-6.2-2)

## [7.](#section-7) [Privacy Considerations]
Cookies\' primary privacy risk is their ability to correlate user
activity. This can happen on a single site, but is most problematic when
activity is tracked across different, seemingly unconnected Web sites to
build a user profile.[¶](#section-7-1)

Over time, this capability (warned against explicitly in
\[[RFC2109](#RFC2109)\] and all of its successors) has
become widely used for varied reasons
including:[¶](#section-7-2)

- :::
 authenticating users across sites,[¶](#section-7-3.1.1)
 :::

- :::
 assembling information on users,[¶](#section-7-3.2.1)
 :::

- :::
 protecting against fraud and other forms of undesirable
 traffic,[¶](#section-7-3.3.1)
 :::

- :::
 targeting advertisements at specific users or at users with specified
 attributes,[¶](#section-7-3.4.1)
 :::

- :::
 measuring how often ads are shown to users,
 and[¶](#section-7-3.5.1)
 :::

- :::
 recognizing when an ad resulted in a change in user
 behavior.[¶](#section-7-3.6.1)
 :::

While not every use of cookies is necessarily problematic for privacy,
their potential for abuse has become a widespread concern in the
Internet community and broader society. In response to these concerns,
user agents have actively constrained cookie functionality in various
ways (as allowed and encouraged by previous specifications), while
avoiding disruption to features they judge desirable for the health of
the Web.[¶](#section-7-4)

It is too early to declare consensus on which specific mechanism(s)
should be used to mitigate cookies\' privacy impact; user agents\'
ongoing changes to how they are handled are best characterised as
experiments that can provide input into that eventual
consensus.[¶](#section-7-5)

Instead, this document describes limited, general mitigations against
the privacy risks associated with cookies that enjoy wide deployment at
the time of writing. It is expected that implementations will continue
to experiment and impose stricter, more well-defined limitations on
cookies over time. Future versions of this document might codify those
mechanisms based upon deployment experience. If functions that currently
rely on cookies can be supported by separate, targeted mechanisms, they
might be documented in separate specifications and stricter limitations
on cookies might become feasible.[¶](#section-7-6)

Note that cookies are not the only mechanism that can be used to track
users across sites, so while these mitigations are necessary to improve
Web privacy, they are not sufficient on their
own.[¶](#section-7-7)

### [7.1.](#section-7.1) [Third-Party Cookies]
A \"third-party\" or cross-site cookie is one that is associated with
embedded content (such as scripts, images, stylesheets, frames) that is
obtained from a different server than the one that hosts the primary
resource (usually, the Web page that the user is viewing). Third-party
cookies are often used to correlate users\' activity on different
sites.[¶](#section-7.1-1)

Because of their inherent privacy issues, most user agents now limit
third-party cookies in a variety of ways. Some completely block
third-party cookies by refusing to process third-party `Set-Cookie`
header fields and refusing to send third-party `Cookie` header fields.
Some partition cookies based upon the first-party context, so that
different cookies are sent depending on the site being browsed. Some
block cookies based upon user agent cookie policy and/or user
controls.[¶](#section-7.1-2)

While this document does not endorse or require a specific approach, it
is RECOMMENDED that user agents adopt a policy for third-party cookies
that is as restrictive as compatibility constraints permit.
Consequently, resources cannot rely upon third-party cookies being
treated consistently by user agents for the foreseeable
future.[¶](#section-7.1-3)

### [7.2.](#section-7.2) [Cookie Policy]
User agents MAY enforce a cookie policy consisting of restrictions on
how cookies may be used or ignored (see [Section
5.5.1](#set-cookie)).[¶](#section-7.2-1)

A cookie policy may govern which domains or parties, as in first and
third parties (see [Section 7.1](#third-party-cookies)), for which the user agent will allow cookie access. The policy
can also define limits on cookie size, cookie expiry (see [Section
4.1.2.1](#attribute-expires) and [Section
4.1.2.2](#attribute-max-age)), and the number of
cookies per domain or in total.[¶](#section-7.2-2)

The goal of a restrictive cookie policy is often to improve security or
privacy. User agents often allow users to change the cookie policy (see
[Section 7.3](#user-controls)).[¶](#section-7.2-3)

### [7.3.](#section-7.3) [User Controls]
User agents SHOULD provide users with a mechanism for managing the
cookies stored in the cookie store. For example, a user agent might let
users delete all cookies received during a specified time period or all
the cookies related to a particular domain. In addition, many user
agents include a user interface element that lets users examine the
cookies stored in their cookie store.[¶](#section-7.3-1)

User agents SHOULD provide users with a mechanism for disabling cookies.
When cookies are disabled, the user agent MUST NOT include a `Cookie`
header field in outbound HTTP requests and the user agent MUST NOT
process `Set-Cookie` header fields in inbound HTTP
responses.[¶](#section-7.3-2)

User agents MAY offer a way to change the cookie policy (see [Section
7.2](#cookie-policy)).[¶](#section-7.3-3)

User agents MAY provide users the option of preventing persistent
storage of cookies across sessions. When configured thusly, user agents
MUST treat all received cookies as if their expiry-time is
null.[¶](#section-7.3-4)

### [7.4.](#section-7.4) [Expiration Dates]
Although servers can set the expiration date for cookies to the distant
future, most user agents do not actually retain cookies for multiple
decades. Rather than choosing gratuitously long expiration periods,
servers SHOULD promote user privacy by selecting reasonable cookie
expiration periods based on the purpose of the cookie. For example, a
typical session identifier might reasonably be set to expire in two
weeks.[¶](#section-7.4-1)

## [8.](#section-8) [Security Considerations]
### [8.1.](#section-8.1) [Overview]
Cookies have a number of security pitfalls. This section overviews a few
of the more salient issues.[¶](#section-8.1-1)

In particular, cookies encourage developers to rely on ambient authority
for authentication, often becoming vulnerable to attacks such as
cross-site request forgery \[[CSRF](#CSRF)\]. Also, when
storing session identifiers in cookies, developers often create session
fixation vulnerabilities.[¶](#section-8.1-2)

Transport-layer encryption, such as that employed in HTTPS, is
insufficient to prevent a network attacker from obtaining or altering a
victim\'s cookies because the cookie protocol itself has various
vulnerabilities (see \"Weak Confidentiality\" and \"Weak Integrity\",
below). In addition, by default, cookies do not provide confidentiality
or integrity from network attackers, even when used in conjunction with
HTTPS.[¶](#section-8.1-3)

### [8.2.](#section-8.2) [Ambient Authority]
A server that uses cookies to authenticate users can suffer security
vulnerabilities because some user agents let remote parties issue HTTP
requests from the user agent (e.g., via HTTP redirects or HTML forms).
When issuing those requests, user agents attach cookies even if the
remote party does not know the contents of the cookies, potentially
letting the remote party exercise authority at an unwary
server.[¶](#section-8.2-1)

Although this security concern goes by a number of names (e.g.,
cross-site request forgery, confused deputy), the issue stems from
cookies being a form of ambient authority. Cookies encourage server
operators to separate designation (in the form of URLs) from
authorization (in the form of cookies). Consequently, the user agent
might supply the authorization for a resource designated by the
attacker, possibly causing the server or its clients to undertake
actions designated by the attacker as though they were authorized by the
user.[¶](#section-8.2-2)

Instead of using cookies for authorization, server operators might wish
to consider entangling designation and authorization by treating URLs as
capabilities. Instead of storing secrets in cookies, this approach
stores secrets in URLs, requiring the remote entity to supply the secret
itself. Although this approach is not a panacea, judicious application
of these principles can lead to more robust
security.[¶](#section-8.2-3)

### [8.3.](#section-8.3) [Clear Text]
Unless sent over a secure channel (such as TLS \[[TLS13](#RFC8446)\]), the information in the `Cookie` and `Set-Cookie` header
fields is transmitted in the clear.[¶](#section-8.3-1)

1. :::
 All sensitive information conveyed in these header fields is exposed
 to an eavesdropper.[¶](#section-8.3-2.1.1)
 :::

2. :::
 A malicious intermediary could alter the header fields as they
 travel in either direction, with unpredictable
 results.[¶](#section-8.3-2.2.1)
 :::

3. :::
 A malicious client could alter the `Cookie` header fields before
 transmission, with unpredictable
 results.[¶](#section-8.3-2.3.1)
 :::

Servers SHOULD encrypt and sign the contents of cookies (using whatever
format the server desires) when transmitting them to the user agent
(even when sending the cookies over a secure channel). However,
encrypting and signing cookie contents does not prevent an attacker from
transplanting a cookie from one user agent to another or from replaying
the cookie at a later time.[¶](#section-8.3-3)

In addition to encrypting and signing the contents of every cookie,
servers that require a higher level of security SHOULD use the `Cookie`
and `Set-Cookie` header fields only over a secure channel. When using
cookies over a secure channel, servers SHOULD set the Secure attribute
(see [Section 4.1.2.5](#attribute-secure)) for
every cookie. If a server does not set the Secure attribute, the
protection provided by the secure channel will be largely
moot.[¶](#section-8.3-4)

For example, consider a webmail server that stores a session identifier
in a cookie and is typically accessed over HTTPS. If the server does not
set the Secure attribute on its cookies, an active network attacker can
intercept any outbound HTTP request from the user agent and redirect
that request to the webmail server over HTTP. Even if the webmail server
is not listening for HTTP connections, the user agent will still include
cookies in the request. The active network attacker can intercept these
cookies, replay them against the server, and learn the contents of the
user\'s email. If, instead, the server had set the Secure attribute on
its cookies, the user agent would not have included the cookies in the
clear-text request.[¶](#section-8.3-5)

### [8.4.](#section-8.4) [Session Identifiers]
Instead of storing session information directly in a cookie (where it
might be exposed to or replayed by an attacker), servers commonly store
a nonce (or \"session identifier\") in a cookie. When the server
receives an HTTP request with a nonce, the server can look up state
information associated with the cookie using the nonce as a
key.[¶](#section-8.4-1)

Using session identifier cookies limits the damage an attacker can cause
if the attacker learns the contents of a cookie because the nonce is
useful only for interacting with the server (unlike non-nonce cookie
content, which might itself be sensitive). Furthermore, using a single
nonce prevents an attacker from \"splicing\" together cookie content
from two interactions with the server, which could cause the server to
behave unexpectedly.[¶](#section-8.4-2)

Using session identifiers is not without risk. For example, the server
SHOULD take care to avoid \"session fixation\" vulnerabilities. A
session fixation attack proceeds in three steps. First, the attacker
transplants a session identifier from his or her user agent to the
victim\'s user agent. Second, the victim uses that session identifier to
interact with the server, possibly imbuing the session identifier with
the user\'s credentials or confidential information. Third, the attacker
uses the session identifier to interact with server directly, possibly
obtaining the user\'s authority or confidential
information.[¶](#section-8.4-3)

### [8.5.](#section-8.5) [Weak Confidentiality]
Cookies do not provide isolation by port. If a cookie is readable by a
service running on one port, the cookie is also readable by a service
running on another port of the same server. If a cookie is writable by a
service on one port, the cookie is also writable by a service running on
another port of the same server. For this reason, servers SHOULD NOT
both run mutually distrusting services on different ports of the same
host and use cookies to store security-sensitive
information.[¶](#section-8.5-1)

Cookies do not provide isolation by scheme. Although most commonly used
with the http and https schemes, the cookies for a given host might also
be available to other schemes, such as ftp and gopher. Although this
lack of isolation by scheme is most apparent in non-HTTP APIs that
permit access to cookies (e.g., HTML\'s document.cookie API), the lack
of isolation by scheme is actually present in requirements for
processing cookies themselves (e.g., consider retrieving a URI with the
gopher scheme via HTTP).[¶](#section-8.5-2)

Cookies do not always provide isolation by path. Although the
network-level protocol does not send cookies stored for one path to
another, some user agents expose cookies via non-HTTP APIs, such as
HTML\'s document.cookie API. Because some of these user agents (e.g.,
web browsers) do not isolate resources received from different paths, a
resource retrieved from one path might be able to access cookies stored
for another path.[¶](#section-8.5-3)

### [8.6.](#section-8.6) [Weak Integrity]
Cookies do not provide integrity guarantees for sibling domains (and
their subdomains). For example, consider foo.site.example and
bar.site.example. The foo.site.example server can set a cookie with a
Domain attribute of \"site.example\" (possibly overwriting an existing
\"site.example\" cookie set by bar.site.example), and the user agent
will include that cookie in HTTP requests to bar.site.example. In the
worst case, bar.site.example will be unable to distinguish this cookie
from a cookie it set itself. The foo.site.example server might be able
to leverage this ability to mount an attack against
bar.site.example.[¶](#section-8.6-1)

Even though the `Set-Cookie` header field supports the Path attribute,
the Path attribute does not provide any integrity protection because the
user agent will accept an arbitrary Path attribute in a `Set-Cookie`
header field. For example, an HTTP response to a request for
http://site.example/foo/bar can set a cookie with a Path attribute of
\"/qux\". Consequently, servers SHOULD NOT both run mutually distrusting
services on different paths of the same host and use cookies to store
security-sensitive information.[¶](#section-8.6-2)

An active network attacker can also inject cookies into the `Cookie`
header field sent to `https://site.example/` by impersonating a response
from `http://site.example/` and injecting a `Set-Cookie` header field.
The HTTPS server at site.example will be unable to distinguish these
cookies from cookies that it set itself in an HTTPS response. An active
network attacker might be able to leverage this ability to mount an
attack against site.example even if site.example uses HTTPS
exclusively.[¶](#section-8.6-3)

Servers can partially mitigate these attacks by encrypting and signing
the contents of their cookies, or by naming the cookie with the
`__Secure-` prefix. However, using cryptography does not mitigate the
issue completely because an attacker can replay a cookie he or she
received from the authentic site.example server in the user\'s session,
with unpredictable results.[¶](#section-8.6-4)

Finally, an attacker might be able to force the user agent to delete
cookies by storing a large number of cookies. Once the user agent
reaches its storage limit, the user agent will be forced to evict some
cookies. Servers SHOULD NOT rely upon user agents retaining
cookies.[¶](#section-8.6-5)

### [8.7.](#section-8.7) [Reliance on DNS]
Cookies rely upon the Domain Name System (DNS) for security. If the DNS
is partially or fully compromised, the cookie protocol might fail to
provide the security properties required by
applications.[¶](#section-8.7-1)

### [8.8.](#section-8.8) [SameSite Cookies]
SameSite cookies offer a robust defense against CSRF attack when
deployed in strict mode, and when supported by the client. It is,
however, prudent to ensure that this designation is not the extent of a
site\'s defense against CSRF, as same-site navigations and submissions
can certainly be executed in conjunction with other attack vectors such
as cross-site scripting.[¶](#section-8.8-1)

Developers are strongly encouraged to deploy the usual server-side
defenses (CSRF tokens, ensuring that \"safe\" HTTP methods are
idempotent, etc) to mitigate the risk more
fully.[¶](#section-8.8-2)

## [9.](#section-9) [IANA Considerations]
### [9.1.](#section-9.1) [Cookie]
The HTTP Field Name Registry (see
\[[HttpFieldNameRegistry](#HttpFieldNameRegistry)\]) needs
to be updated with the following
registration:[¶](#section-9.1-1)

Header field name:

: Cookie[¶](#section-9.1-2.2.1)

:

Applicable protocol:

: http[¶](#section-9.1-2.4.1)

:

Status:

: standard[¶](#section-9.1-2.6.1)

:

Author/Change controller:

: IETF[¶](#section-9.1-2.8.1)

:

Specification document:

: this specification ([Section 5.5.2](#cookie))[¶](#section-9.1-2.10.1)

:

### [9.2.](#section-9.2) [Set-Cookie]
The HTTP Field Name Registry (see
\[[HttpFieldNameRegistry](#HttpFieldNameRegistry)\]) needs
to be updated with the following
registration:[¶](#section-9.2-1)

Header field name:

: Set-Cookie[¶](#section-9.2-2.2.1)

:

Applicable protocol:

: http[¶](#section-9.2-2.4.1)

:

Status:

: standard[¶](#section-9.2-2.6.1)

:

Author/Change controller:

: IETF[¶](#section-9.2-2.8.1)

:

Specification document:

: this specification ([Section 5.5.1](#set-cookie))[¶](#section-9.2-2.10.1)

:

## [10.](#section-10) [Changes]
Revamped the document to allow for more detailed requirements on
browsers in downstream specifications.[¶](#section-10-1)

## [Acknowledgements]
Many thanks to Adam Barth for laying the groundwork for a modern cookie
specification with RFC 6265.[¶](#section-11-1)

And many thanks to Steven Bingler, Lily Chen, Dylan Cutler, Steven
Englehardt, Yoav Weiss, Mike West, and John Wilander for improving upon
that work.[¶](#section-11-2)

## [References]
### [Normative References]
\[HTML\]
: [Hickson, I.], [Pieters, S.], [van Kesteren,
 A.], [Jägenstedt, P.], and [D.
 Denicola], [\"HTML\"], n.d.,
 \<<https://html.spec.whatwg.org/>\>.
:

\[INFRA\]
: [van Kesteren, A.] and [D. Denicola],
 [\"Infra\"], n.d., \<<https://infra.spec.whatwg.org>\>.
:

\[RFC1034\]
: [Mockapetris, P.], [\"Domain names - concepts and
 facilities\"], [STD 13], [RFC
 1034], [DOI 10.17487/RFC1034], November
 1987, \<<https://www.rfc-editor.org/rfc/rfc1034>\>.
:

\[RFC1123\]
: [Braden, R., Ed.], [\"Requirements for Internet Hosts -
 Application and Support\"], [STD 3], [RFC
 1123], [DOI 10.17487/RFC1123], October
 1989, \<<https://www.rfc-editor.org/rfc/rfc1123>\>.
:

\[RFC2119\]
: [Bradner, S.], [\"Key words for use in RFCs to Indicate
 Requirement Levels\"], [BCP 14], [RFC
 2119], [DOI 10.17487/RFC2119], March 1997,
 \<<https://www.rfc-editor.org/rfc/rfc2119>\>.
:

\[RFC5234\]
: [Crocker, D., Ed.] and [P. Overell],
 [\"Augmented BNF for Syntax Specifications: ABNF\"], [STD
 68], [RFC 5234], [DOI
 10.17487/RFC5234], January 2008,
 \<<https://www.rfc-editor.org/rfc/rfc5234>\>.
:

\[URL\]
: [van Kesteren, A.], [\"URL\"], n.d.,
 \<<https://url.spec.whatwg.org>\>.
:

### [Informative References]
\[CSRF\]
: [Barth, A.], [Jackson, C.], and [J.
 Mitchell], [\"Robust Defenses for Cross-Site Request
 Forgery\"], [DOI 10.1145/1455770.1455782],
 [ISBN 978-1-59593-810-7], [ACM CCS \'08: Proceedings of
 the 15th ACM conference on Computer and communications security
 (pages 75-88)], October 2008,
 \<<http://portal.acm.org/citation.cfm?id=1455770.1455782>\>.
:

\[HTTP\]
: [Bishop, M., Ed.], [\"HTTP/3\"], [RFC
 9114], [DOI 10.17487/RFC9114], June 2022,
 \<<https://www.rfc-editor.org/rfc/rfc9114>\>.
:

\[HttpFieldNameRegistry\]
: [\"Hypertext Transfer Protocol (HTTP) Field Name
 Registry\"], n.d.,
 \<<https://www.iana.org/assignments/http-fields/>\>.
:

\[RFC2109\]
: [Kristol, D.] and [L. Montulli], [\"HTTP
 State Management Mechanism\"], [RFC 2109],
 [DOI 10.17487/RFC2109], February 1997,
 \<<https://www.rfc-editor.org/rfc/rfc2109>\>.
:

\[RFC4648\]
: [Josefsson, S.], [\"The Base16, Base32, and Base64 Data
 Encodings\"], [RFC 4648], [DOI
 10.17487/RFC4648], October 2006,
 \<<https://www.rfc-editor.org/rfc/rfc4648>\>.
:

\[RFC6265\]
: [Barth, A.], [\"HTTP State Management
 Mechanism\"], [RFC 6265], [DOI
 10.17487/RFC6265], April 2011,
 \<<https://www.rfc-editor.org/rfc/rfc6265>\>.
:

\[RFC7034\]
: [Ross, D.] and [T. Gondrom], [\"HTTP Header
 Field X-Frame-Options\"], [RFC 7034], [DOI
 10.17487/RFC7034], October 2013,
 \<<https://www.rfc-editor.org/rfc/rfc7034>\>.
:

\[RFC9110\]
: [Fielding, R., Ed.], [Nottingham, M., Ed.],
 and [J. Reschke, Ed.], [\"HTTP Semantics\"],
 [STD 97], [RFC 9110], [DOI
 10.17487/RFC9110], June 2022,
 \<<https://www.rfc-editor.org/rfc/rfc9110>\>.
:

\[RFC9113\]
: [Thomson, M., Ed.] and [C. Benfield, Ed.],
 [\"HTTP/2\"], [RFC 9113], [DOI
 10.17487/RFC9113], June 2022,
 \<<https://www.rfc-editor.org/rfc/rfc9113>\>.
:

\[TLS13\]
: [Rescorla, E.], [\"The Transport Layer Security (TLS)
 Protocol Version 1.3\"], [RFC 8446], [DOI
 10.17487/RFC8446], August 2018,
 \<<https://www.rfc-editor.org/rfc/rfc8446>\>.
:

## [Authors\' Addresses]
[Anne van Kesteren ([editor])]

[Apple]

Email: <annevk@annevk.nl>

[Johann Hofmann ([editor])]

[Google]

Email: <johannhof@google.com>

[Datatracker](/doc/draft-ietf-httpbis-layered-cookies/)

draft-ietf-httpbis-layered-cookies-02\
[Active Internet-Draft] ([httpbis
WG](/wg/httpbis/about/))

- [Info]
- [Contents]
- [Prefs]

+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| Document | Document type | | [Active Internet-Draft] ([httpbis WG](/wg/httpbis/about/)) |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | Select version | | - [00](/doc/html/draft-ietf-httpbis-layered-cookies-00) |
| | | | - [01](/doc/html/draft-ietf-httpbis-layered-cookies-01) |
| | | | - [02](/doc/html/draft-ietf-httpbis-layered-cookies-02) |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | Compare | | draft-ietf-httpbis-layered-cookies-02 draft-ietf-httpbis-layered-cookies-01 draft-ietf-httpbis-layered-cookies-00 |
| | versions | | draft-annevk-johannhof-httpbis-cookies-01 draft-annevk-johannhof-httpbis-cookies-00 draft-ietf-httpbis-layered-cookies-02 |
| | | | draft-ietf-httpbis-layered-cookies-01 draft-ietf-httpbis-layered-cookies-00 draft-annevk-johannhof-httpbis-cookies-01 |
| | | | draft-annevk-johannhof-httpbis-cookies-00 |
| | | | |
| | | | Side-by-side |
| | | | |
| | | | Inline |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | Authors | | [Anne van Kesteren](/person/annevk@annevk.nl "Datatracker profile of Anne van Kesteren") |
| | | | (mailto:annevk%40annevk.nl "Compose email to annevk@annevk.nl"){aria-label="Compose email to annevk@annevk.nl"}, [Johann |
| | | | Hofmann](/person/mail@johann-hofmann.com "Datatracker profile of Johann Hofmann") |
| | | | (mailto:mail%40johann-hofmann.com "Compose email to mail@johann-hofmann.com"){aria-label="Compose email to mail@johann-hofmann.com"}\ |
| | | | [Email |
| | | | authors](mailto:draft-ietf-httpbis-layered-cookies@ietf.org?subject=draft-ietf-httpbis-layered-cookies "Send email to the document authors") |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | Replaces | | [draft-annevk-johannhof-httpbis-cookies](/doc/html/draft-annevk-johannhof-httpbis-cookies "Cookies: HTTP State Management Mechanism") |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | RFC stream | | ![IETF Logo](https://static.ietf.org/dt/12.80.0/ietf/images/ietf-logo-nor-white.svg) ![IETF |
| | | | Logo](https://static.ietf.org/dt/12.80.0/ietf/images/ietf-logo-nor.svg) |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | Intended RFC | | Proposed Standard |
| | status | | |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | Other formats | | ::: buttonlist |
| | | | [ txt](https://www.ietf.org/archive/id/draft-ietf-httpbis-layered-cookies-02.txt) [ |
| | | | html](https://www.ietf.org/archive/id/draft-ietf-httpbis-layered-cookies-02.html) [ |
| | | | xml](https://www.ietf.org/archive/id/draft-ietf-httpbis-layered-cookies-02.xml) [ |
| | | | bibtex](/doc/draft-ietf-httpbis-layered-cookies/02/bibtex/) [ |
| | | | bibxml](/doc/bibxml3/draft-ietf-httpbis-layered-cookies-02.xml) |
| | | | ::: |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+
| | Additional | | [Mailing list discussion](http://lists.w3.org/Archives/Public/ietf-http-wg/) |
| | resources | | |
+-----------------+-----------------+-----------------+---------------------------------------------------------------------------------------------------------------------------------------------------+

[Report a datatracker bug
](https://github.com/ietf-tools/datatracker/issues/new/choose)

Show sidebar by default

Yes No

Tab to show by default

Info Contents

HTMLization configuration

HTMLize the plaintext Plaintextify the HTML

Maximum font size Page dependencies

Inline Reference

Citation links

Go to reference section Go to linked document

!(//analytics.ietf.org/matomo.php?idsite=7){style="border:0;"}
