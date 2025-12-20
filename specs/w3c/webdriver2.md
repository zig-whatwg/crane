
[![W3C](https://www.w3.org/StyleSheets/TR/2021/logos/W3C){crossorigin=""
height="48" width="72"}](https://www.w3.org/)

# WebDriver

[W3C Working Draft](https://www.w3.org/standards/types#WD) 28 October
2025

More details about this document

This version:
: [https://www.w3.org/TR/2025/WD-webdriver2-20251028/](https://www.w3.org/TR/2025/WD-webdriver2-20251028/)

Latest published version:
: <https://www.w3.org/TR/webdriver2/>

Latest editor\'s draft:
: <https://w3c.github.io/webdriver/>

History:
: <https://www.w3.org/standards/history/webdriver2/>
: [Commit history](https://github.com/w3c/webdriver/commits/master)

Test suite:
: <https://wpt.live/webdriver/>

Implementation report:
: <https://wpt.fyi/results/webdriver>

Editors:
: [Simon Stewart](http://www.rocketpoweredjetpants.com/) ([Apple](https://www.apple.com))
: [David Burns](http://www.theautomatedtester.co.uk/) ([BrowserStack](https://www.browserstack.com))

Feedback:
: [GitHub w3c/webdriver](https://github.com/w3c/webdriver/) ([pull
 requests](https://github.com/w3c/webdriver/pulls/), [new
 issue](https://github.com/w3c/webdriver/issues/new/choose), [open
 issues](https://github.com/w3c/webdriver/issues/))

Channel
: [#webdriver on irc.w3.org](https://www.w3.org/wiki/IRC)

[Copyright](https://www.w3.org/policies/#copyright) © 2025 [World Wide
Web Consortium](https://www.w3.org/). [W3C]^®^
[liability](https://www.w3.org/policies/#Legal_Disclaimer),
[trademark](https://www.w3.org/policies/#W3C_Trademarks) and [permissive
document
license](https://www.w3.org/copyright/software-license-2023/ "W3C Software and Document Notice and License"){rel="license"}
rules apply.

------------------------------------------------------------------------

## Abstract

WebDriver is a remote control interface that enables introspection and
control of user agents. It provides a platform- and language-neutral
wire protocol as a way for out-of-process programs to remotely instruct
the behavior of web browsers.

Provided is a set of interfaces to discover and manipulate DOM elements
in web documents and to control the behavior of a user agent. It is
primarily intended to allow web authors to write tests that automate a
user agent from a separate controlling process, but may also be used in
such a way as to allow in-browser scripts to control a --- possibly
separate --- browser.

## Status of This Document

*This section describes the status of this document at the time of its
publication. A list of current [W3C] publications and the latest revision
of this technical report can be found in the [[W3C] standards and drafts
index](https://www.w3.org/TR/).*

This document was published by the [Browser Testing and Tools Working
Group](https://www.w3.org/groups/wg/browser-tools-testing) as a Working
Draft using the [Recommendation
track](https://www.w3.org/policies/process/20250818/#recs-and-notes).

Publication as a Working Draft does not imply endorsement by [W3C] and its Members.

This is a draft document and may be updated, replaced, or obsoleted by
other documents at any time. It is inappropriate to cite this document
as other than a work in progress.

This document was produced by a group operating under the [[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/). [W3C] maintains a [public list of any
patent
disclosures](https://www.w3.org/groups/wg/browser-tools-testing/ipr){rel="disclosure"}
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
3. [1. Design](#design)
 1. [1.1 Compatibility](#compatibility)
 2. [1.2 Simplicity](#simplicity)
 3. [1.3 Extensions](#extensions)
4. [2. Conformance](#conformance)
5. [3. Terminology](#terminology)
6. [4. Interface](#interface)
7. [5. Nodes](#nodes)
8. [6. Protocol](#protocol)
 1. [6.1 Algorithms](#algorithms)
 2. [6.2 Commands](#commands)
 3. [6.3 Processing model](#processing-model)
 4. [6.4 Routing requests](#routing-requests)
 5. [6.5 Endpoints](#endpoints)
 6. [6.6 Errors](#errors)
 7. [6.7 Extensions](#extensions-0)
9. [7. Capabilities](#capabilities)
 1. [7.1 Proxy](#proxy)
 2. [7.2 Processing
 capabilities](#processing-capabilities)
10. [8. Sessions](#sessions)
 1. [8.1 Global State](#global-state)
 2. [8.2 [New
 Session]](#new-session)
 3. [8.3 Delete Session](#delete-session)
 4. [8.4 Status](#status)
11. [9. Timeouts](#timeouts)
 1. [9.1 Get Timeouts](#get-timeouts)
 2. [9.2 Set Timeouts](#set-timeouts)
12. [10. Navigation](#navigation)
 1. [10.1 Navigate To](#navigate-to)
 2. [10.2 Get Current URL](#get-current-url)
 3. [10.3 Back](#back)
 4. [10.4 Forward](#forward)
 5. [10.5 Refresh](#refresh)
 6. [10.6 Get Title](#get-title)
13. [11. Contexts](#contexts)
 1. [11.1 Get Window Handle](#get-window-handle)
 2. [11.2 Close Window](#close-window)
 3. [11.3 Switch To Window](#switch-to-window)
 4. [11.4 Get Window Handles](#get-window-handles)
 5. [11.5 New Window](#new-window)
 6. [11.6 Switch To Frame](#switch-to-frame)
 7. [11.7 Switch To Parent Frame](#switch-to-parent-frame)
 8. [11.8 Resizing and positioning
 windows](#resizing-and-positioning-windows)
 1. [11.8.1 Get Window Rect](#get-window-rect)
 2. [11.8.2 Set Window Rect](#set-window-rect)
 3. [11.8.3 Maximize Window](#maximize-window)
 4. [11.8.4 Minimize Window](#minimize-window)
 5. [11.8.5 Fullscreen Window](#fullscreen-window)
14. [12. Elements](#elements)
 1. [12.1 Interactability](#interactability)
 2. [12.2 Shadow Roots](#shadow-root)
 3. [12.3 Retrieval](#element-retrieval)
 1. [12.3.1 Locator strategies](#locator-strategies)
 1. [12.3.1.1 CSS selectors](#css-selectors)
 2. [12.3.1.2 Link text](#link-text)
 3. [12.3.1.3 Partial link
 text](#partial-link-text)
 4. [12.3.1.4 Tag name](#tag-name)
 5. [12.3.1.5 XPath](#xpath)
 2. [12.3.2 Find Element](#find-element)
 3. [12.3.3 Find Elements](#find-elements)
 4. [12.3.4 Find Element From
 Element](#find-element-from-element)
 5. [12.3.5 Find Elements From
 Element](#find-elements-from-element)
 6. [12.3.6 Find Element From Shadow
 Root](#find-element-from-shadow-root)
 7. [12.3.7 Find Elements From Shadow
 Root](#find-elements-from-shadow-root)
 8. [12.3.8 Get Active Element](#get-active-element)
 9. [12.3.9 Get Element Shadow
 Root](#get-element-shadow-root)
 4. [12.4 State](#state)
 1. [12.4.1 Is Element Selected](#is-element-selected)
 2. [12.4.2 Get Element
 Attribute](#get-element-attribute)
 3. [12.4.3 Get Element
 Property](#get-element-property)
 4. [12.4.4 Get Element CSS
 Value](#get-element-css-value)
 5. [12.4.5 Get Element Text](#get-element-text)
 6. [12.4.6 Get Element Tag
 Name](#get-element-tag-name)
 7. [12.4.7 Get Element Rect](#get-element-rect)
 8. [12.4.8 Is Element Enabled](#is-element-enabled)
 9. [12.4.9 Get Computed Role](#get-computed-role)
 10. [12.4.10 Get Computed Label](#get-computed-label)
 5. [12.5 Interaction](#element-interaction)
 1. [12.5.1 Element Click](#element-click)
 2. [12.5.2 Element Clear](#element-clear)
 3. [12.5.3 Element Send Keys](#element-send-keys)
15. [13. Document](#document)
 1. [13.1 Get Page Source](#get-page-source)
 2. [13.2 Executing Script](#executing-script)
 1. [13.2.1 Execute Script](#execute-script)
 2. [13.2.2 Execute Async
 Script](#execute-async-script)
16. [14. Cookies](#cookies)
 1. [14.1 Get All Cookies](#get-all-cookies)
 2. [14.2 Get Named Cookie](#get-named-cookie)
 3. [14.3 [Add
 Cookie]](#add-cookie)
 4. [14.4 Delete Cookie](#delete-cookie)
 5. [14.5 Delete All Cookies](#delete-all-cookies)
17. [15. Actions](#actions)
 1. [15.1 Actions Options](#actions-options)
 2. [15.2 Input sources](#input-sources)
 1. [15.2.1 Null input source](#null-input-source)
 2. [15.2.2 Key input source](#key-input-source)
 3. [15.2.3 Pointer input
 source](#pointer-input-source)
 4. [15.2.4 Wheel input source](#wheel-input-source)
 3. [15.3 Input state](#input-state)
 4. [15.4 Ticks](#ticks)
 5. [15.5 Processing actions](#processing-actions)
 6. [15.6 Dispatching actions](#dispatching-actions)
 1. [15.6.1 General actions](#general-actions)
 2. [15.6.2 Keyboard actions](#keyboard-actions)
 3. [15.6.3 Pointer actions](#pointer-actions)
 4. [15.6.4 Wheel actions](#wheel-actions)
 7. [15.7 Perform Actions](#perform-actions)
 8. [15.8 Release Actions](#release-actions)
18. [16. User prompts](#user-prompts)
 1. [16.1 User Prompt Handler](#user-prompt-handler)
 2. [16.2 Dismiss Alert](#dismiss-alert)
 3. [16.3 Accept Alert](#accept-alert)
 4. [16.4 Get Alert Text](#get-alert-text)
 5. [16.5 Send Alert Text](#send-alert-text)
19. [17. Screen capture](#screen-capture)
 1. [17.1 Take Screenshot](#take-screenshot)
 2. [17.2 Take Element
 Screenshot](#take-element-screenshot)
20. [18. Print](#print)
 1. [18.1 Print Page](#print-page)
21. [A. Privacy](#privacy)
22. [B. Security](#security)
23. [C. Element displayedness](#element-displayedness)
24. [D. Acknowledgements](#acknowledgements)
25. [E. Index](#index)
 1. [E.1 Terms defined by this
 specification](#index-defined-here)
 2. [E.2 Terms defined by
 reference](#index-defined-elsewhere)
26. [F. References](#references)
 1. [F.1 Normative references](#normative-references)

::: header-wrapper
## 1. Design

*This section is non-normative.*

The WebDriver standard attempts to follow a number of design goals:

::: header-wrapper
### 1.1 Compatibility

This specification is derived from the popular [Selenium
WebDriver](https://selenium.dev) browser automation framework. Selenium
is a long-lived project, and due to its age and breadth of use it has a
wide range of expected functionality. This specification uses these
expectations to inform its design. Where improvements or clarifications
have been made, they have been made with care to allow existing users of
Selenium WebDriver to avoid unexpected breakages.

::: header-wrapper
### 1.2 Simplicity

The largest intended group of users of this specification are software
developers and testers writing automated tests and other tooling, such
as monitoring or load testing, that relies on automating a browser. As
such, care has been taken to provide commands that simplify common tasks
such as [typing
into](#dfn-element-send-keys) and
[clicking](#dfn-element-click) elements.

::: header-wrapper
### 1.3 Extensions

WebDriver provides a mechanism for others to define extensions to the
protocol for the purposes of automating functionality that cannot be
implemented entirely in [ECMAScript](https://tc39.github.io/ecma262/).
This allows other web standards to support the automation of new
platform features. It also allows vendors to expose functionality that
is specific to their browser.

::: header-wrapper
## 2. Conformance

As well as sections marked as non-normative, all authoring guidelines,
diagrams, examples, and notes in this specification are non-normative.
Everything else in this specification is normative.

Conformance requirements phrased as algorithms or specific steps may be
implemented in any manner, so long as the end result is equivalent.
Algorithms in this document are typically written with readability,
rather than performance, in mind.

::: header-wrapper
## 3. Terminology

In equations, all numbers are integers, addition is represented by "+",
subtraction by "−", division by "÷", and bitwise OR by "\|". The
characters "(" and ")" are used to provide logical grouping in these
contexts.

The mathematical function [min](`value`,
`value`\[, `value`\]) returns the smallest item of
two or more values. Conversely, the function [max](`value`,
`value`\[, `value`\]) returns the largest item of
two or more values.

The mathematical function [floor](`value`) produces the
largest integer, closest to positive infinity, that is not larger than
`value`.

A [Universally Unique Identifier (UUID)] is a 128 bits long URN that
requires no central registration process. [Generating a
UUID] means *Creating a UUID From Truly Random or
Pseudo-Random Numbers*, and converting it to the string representation.
\[[RFC4122](#bib-rfc4122 "A Universally Unique IDentifier (UUID) URN Namespace")\]

The [Unix Epoch] is a value that
approximates the number of seconds that have elapsed since the Epoch, as
described by The Open Group Base Specifications Issue 7 [section
4.15](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap04.html#tag_04_15)
(IEEE Std 1003.1).

An [integer] is a [Number](#dfn-number) that is unchanged under the
[ToInteger](#dfn-tointeger) operation.

The [initial value] of an ECMAScript property is the
value defined by the platform for that property, i.e. the value it would
have in the absence of any shadowing by content script.

The [browser chrome] is a non-normative term to refer
to the representation through which the user interacts with the user
agent itself, as distinct from the accessed web content. Examples of
[browser chrome elements] include, but are not limited to,
toolbars (such as the bookmark toolbar), menus (such as the file or
context menu), buttons (such as the back and forward buttons), door
hangers (such as security and certificate indicators), and decorations
(such as operating system widget borders).

MDN[✅]{title="This feature is in all major engines."}

[Navigator/webdriver](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/webdriver "The webdriver read-only property of the navigator interface indicates whether the user agent is controlled by automation.")

This feature is in all major engines.

 ------------------ -------
 Chrome 63+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 60+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 10.1+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -------

::: header-wrapper
## 4. Interface

The [webdriver-active flag] is set to true when the user
agent is under remote control. It is initially false.

```
WebIDLinterface mixin NavigatorAutomationInformation {
 readonly attribute boolean webdriver;
};
Navigator includes NavigatorAutomationInformation;
```

[`NavigatorAutomationInformation`](#dom-navigatorautomationinformation)
interface should not be exposed on
[`WorkerNavigator`](https://html.spec.whatwg.org/multipage/workers.html#workernavigator).

[webdriver]

: Returns true if [webdriver-active
 flag](#dfn-webdriver-active-flag) is set, false otherwise.

[Example 1](#example-1)

For web authors (non-normative):

`navigator`.[`webdriver`](#dfn-webdriver)

: Defines a standard way for co-operating user agents to inform the
 document that it is controlled by WebDriver, for example so that
 alternate code paths can be triggered during automation.

It is acknowledged that this is complementary to the Evil Bit
\[[RFC3514](#bib-rfc3514 "The Security Flag in the IPv4 Header")\].

::: header-wrapper
## 5. Nodes

The WebDriver protocol consists of communication between:

[Local end]

: The local end represents the client side of the protocol, which is
 usually in the form of language-specific libraries providing an API
 on top of the WebDriver [protocol](#protocol). This specification
 does not place any restrictions on the details of those libraries
 above the level of the wire protocol.

[Remote end]
: The remote end hosts the server side of the [protocol](#protocol).
 Defining the behavior of a [remote
 end](#dfn-remote-ends) in response to the WebDriver protocol forms the
 largest part of this specification.

For [remote ends](#dfn-remote-ends) the standard defines two broad conformance
classes, known as [node types]:

[Intermediary node]
: Intermediary nodes are those that act as proxies, implementing both
 the [local end](#dfn-local-ends) and [remote
 end](#dfn-remote-ends) of the [protocol](#protocol). However they are not
 expected to implement [remote end
 steps](#dfn-remote-end-steps) directly. Nodes between a specific
 [intermediary
 node](#dfn-intermediary-nodes) and an [endpoint
 node](#dfn-endpoint-node) are said to be [upstream] of the [endpoint
 node](#dfn-endpoint-node).

[Endpoint node]
: An endpoint node is the final [remote
 end](#dfn-remote-ends) in a chain of nodes that is not an [intermediary
 node](#dfn-intermediary-nodes). The endpoint node is implemented by a
 user agent or a similar program.

All remote end [node types](#dfn-node-type) must be black-box indistinguishable from a
[remote end](#dfn-remote-ends), from the point of view of [local
end](#dfn-local-ends), and so are bound by the requirements on a [remote
end](#dfn-remote-ends) in terms of the wire protocol.

The [readiness state] of a [remote
end](#dfn-remote-ends) indicates whether it is free to accept new connections.
It must be false if the implementation is an [endpoint
node](#dfn-endpoint-node) and the list of [active HTTP
sessions](#dfn-active-http-sessions) is not empty, or otherwise if the [remote
end](#dfn-remote-ends) is known to be in a state in which attempting to create
[new sessions](#dfn-new-sessions) would fail. In all other cases it must be
true.

If the [intermediary
node](#dfn-intermediary-nodes) is a multiplexer that manages multiple
[endpoint nodes](#dfn-endpoint-node), this might indicate
its ability to purvey more
[sessions](#dfn-sessions), for example if it has hit its maximum capacity.

::: header-wrapper
## 6. Protocol

WebDriver [remote ends](#dfn-remote-ends) must provide an [HTTP
compliant](#dfn-http-compliant) wire protocol where the
[endpoints](#dfn-endpoints) map to different
[commands](#dfn-commands).

As this standard only defines the [remote
end](#dfn-remote-ends) protocol, it puts no demands to how [local
ends](#dfn-local-ends) should be implemented. [Local
ends](#dfn-local-ends) are only expected to be compatible to the extent that
they can speak the [remote
end](#dfn-remote-ends)\'s protocol; no requirements are made upon their
exposed user-facing API.

::: header-wrapper
### 6.1 Algorithms

Various parts of this specification are written in terms of step-by-step
algorithms. The details of these algorithms do not have any normative
significance; implementations are free to adopt any implementation
strategy that produces equivalent output to the specification. In
particular, algorithms in this document are optimized for readability
rather than performance.

Where algorithms that return values are fallible, they are written in
terms of returning either [success] or
[error]. A
[success](#dfn-success) value has an associated `data` field which
encapsulates the value returned, whereas an
[error](#dfn-error)
value has an associated [error
code](#dfn-error-code).

When calling a fallible algorithm, the construct "Let
`result` be the result of [trying] to call `algorithm`" is equivalent to

1. Let `temp` be the result of calling
 `algorithm`.

2. If `temp` is an [error](#dfn-error) return `temp`, otherwise
 let `result` be `temp`\'s `data`
 field.

The result of [getting a property] with
`name` from `object` is defined as being the same
as the result of calling
[Object.\[\[GetOwnProperty\]\]](#dfn-getownproperty)(`name`) on `object`.

The result of [getting a property with
default] with arguments
`name` and `default` from `object` is
defined as being the same as the result of calling
[Object.\[\[GetOwnProperty\]\]](#dfn-getownproperty)(`name`) on `object`
if that results in a value other than `undefined` and
`default` otherwise.

[Setting a property] with arguments `name`
and `value` on `object` is defined as being the
same as calling [Object.\[\[Put\]\]](#dfn-put)(`name`, `value`) on
`object`.

The result of [JSON serialization] with
`object` of type JSON
[Object](#dfn-object) is defined as the result of calling
[stringify](#dfn-stringify)(`object`).

The result of [JSON deserialization] with `text` is defined
as the result of calling [parse](#dfn-parse)(`text`).

::: header-wrapper
### 6.2 Commands

The WebDriver protocol is organized into
[commands](#dfn-commands). Each [HTTP
request](#dfn-http-request) with a method and template defined in this
specification represents a single [command], and therefore each command produces a single [HTTP
response](#dfn-http-response).

In response to a [command](#dfn-commands), a [remote
end](#dfn-remote-ends) will run a series of actions known as [remote end
steps]. These provide the sequences of
actions that a [remote
end](#dfn-remote-ends) takes when it receives a particular
[command](#dfn-commands).

::: header-wrapper
### 6.3 Processing model

The [remote end](#dfn-remote-ends) is an HTTP server reading requests from
the client and writing responses, typically over a TCP socket. For the
purposes of this specification we model the data transmission between a
particular [local end](#dfn-local-ends) and [remote
end](#dfn-remote-ends) with a [connection] to which the [remote
end](#dfn-remote-ends) may [write bytes] and [read bytes]. However the
exact details of how this
[connection](#dfn-connection) works and how it is established are out of scope.

After a [connection](#dfn-connection) is established, the [remote
end](#dfn-remote-ends) must run the following steps:

1. [While](https://infra.spec.whatwg.org/#iteration-while) the
 [connection](#dfn-connection) is not closed:

 1. [Read bytes](#dfn-read-bytes) from the
 [connection](#dfn-connection) until a complete [HTTP
 request](#dfn-http-request) can be constructed from the data.
 Let `request` be a
 [request](#dfn-http-request) constructed from the received
 data, according to the requirements of
 \[[RFC7230](#bib-rfc7230 "Hypertext Transfer Protocol (HTTP/1.1): Message Syntax and Routing")\]. If it is not possible to construct a
 complete [HTTP
 request](#dfn-http-request), the [remote
 end](#dfn-remote-ends) must either close the
 [connection](#dfn-connection), return an HTTP response with
 status code 500, or return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [unknown
 error](#dfn-unknown-error).

 2. Let `request match` be the result of the algorithm to
 [match a
 request](#dfn-match-a-request) with `request`\'s
 [method](#dfn-method) and [URL](#dfn-url) as arguments.

 3. If `request match` is of type
 [error](#dfn-error), [send an
 error](#dfn-send-an-error) with `request match`\'s
 [error code](#dfn-error-code) and
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 Otherwise, let `command` and
 `URL variables` be `request match`\'s
 data.

 4. Let `session` be null.

 5. If `URL variables`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`session id"`:

 ::::
 :::
 Note
 :::

 This condition is intended to exclude the [New
 Session](#dfn-new-sessions) and
 [Status](#dfn-status)
 [commands](#dfn-commands) and any [extension
 commands](#dfn-extension-commands) which do not operate on a
 particular [session](#dfn-sessions).
 ::::

 1. Let `session id` be
 `URL variables`\[\"`session id`\"\].

 2. For each `active session` in the list of [active
 sessions](#dfn-active-sessions):

 1. If `active session`\'s [session
 ID](#dfn-session-id) is equal to
 `session id`, then let `session`
 be `active session`, and break.

 3. If the `session` is
 [`null`](#dfn-null) [send an
 error](#dfn-send-an-error) with [error
 code](#dfn-error-code) [invalid session
 id](#dfn-invalid-session-id), then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 6. Enqueue a task on [remote
 end](#dfn-remote-ends)\'s [request
 queue](#dfn-request-queue) to run the following steps:

 1. If [session](#dfn-sessions) is no longer in the list of
 [active
 sessions](#dfn-active-sessions), then [send an
 error](#dfn-send-an-error) with [error
 code](#dfn-error-code) [invalid session
 id](#dfn-invalid-session-id) and return.

 2. Let `parameters` be
 [`null`](#dfn-null).

 3. If `request`\'s
 [method](#dfn-method) is POST:

 1. Let `parse result` be the result of [parsing
 as
 JSON](#dfn-parsing-as-json) with
 `request`\'s
 [body](#dfn-body) as the argument. If this process throws
 an exception, return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument) and jump back to step 1 in
 this overall algorithm.

 2. If `parse result` is not an
 [Object](#dfn-object), [send an
 error](#dfn-send-an-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument) and jump back to step 1 in
 this overall algorithm.

 Otherwise, let `parameters` be
 `parse result`.

 4. Let `navigate result` be the result of [wait for
 navigation to
 complete](#dfn-wait-for-navigation-to-complete) with `session`.

 5. If `navigate result` is an
 [error](#dfn-error), [send an
 error](#dfn-send-an-error) with [error
 code](#dfn-error-code) equal to
 `navigate result`\'s [error
 code](#dfn-error-code) and return.

 6. Let `response result` be the return value
 obtained by running the [remote end
 steps](#dfn-remote-end-steps) for `command` with
 `session`, `URL variables`, and
 `parameters`.

 7. If `response result` is an
 [error](#dfn-error), [send an
 error](#dfn-send-an-error) with [error
 code](#dfn-error-code) equal to
 `response result`\'s [error
 code](#dfn-error-code) and return.

 8. Assert: `response result` is a
 [success](#dfn-success).

 9. Let `response data` be
 `response result`\'s data.

 10. [Send a
 response](#dfn-send-a-response) with status 200 and
 `response data`.

When required to [send an error], with `error code` and
an optional `error data` dictionary, a [remote
end](#dfn-remote-ends) must run the following steps:

1. Let `status` and `name` be the [error response
 data](#dfn-error-response-data) for `error code`.

2. Let `message` be an implementation-defined string
 containing a human-readable description of the reason for the error.

3. Let `stacktrace` be an implementation-defined string
 containing a stack trace report of the active stack frames at the
 time when the error occurred.

 Let `body` be a new JSON
 [Object](#dfn-object) initialized with the following properties:

 \"`error`\"
 : `name`

 \"`message`\"
 : `message`

 \"`stacktrace`\"
 : `stacktrace`

4. If the [error data](#dfn-error-data) dictionary contains any entries, set
 the \"`data`\" field on `body` to a new JSON
 [Object](#dfn-object) populated with the dictionary.

5. [Send a
 response](#dfn-send-a-response) with `status` and
 `body` as arguments.

When required to [send a response], with arguments
`status` and `data`, a [remote
end](#dfn-remote-ends) must run the following steps:

1. Let `response` be a new
 [response](#dfn-http-response).

2. Set `response`\'s [HTTP
 status](#dfn-http-status) to `status`, and [status
 message](#dfn-status-message) to the string corresponding to the
 description of `status` in the [status code
 registry](#dfn-status-code-registry).

3. [Set](#dfn-set-header) the `response`\'s
 [header](#dfn-header) with
 [name](#dfn-header-name) and
 [value](#dfn-header-value) with the following values:

 `Content-Type`
 : \"`application/json; charset=utf-8`\"

 `Cache-Control`
 : \"`no-cache`\"

4. Let `response`\'s [body](#dfn-body) be the [UTF-8
 encoded](#dfn-utf-8-encode) [JSON
 serialization](#dfn-json-serialization) of a JSON
 [Object](#dfn-object) with a key \"`value`\" set to `data`.

5. Let `response bytes` be the byte sequence resulting from
 serializing `response` according to the rules in
 \[[RFC7230](#bib-rfc7230 "Hypertext Transfer Protocol (HTTP/1.1): Message Syntax and Routing")\].

6. [Write](#dfn-write-bytes) `response bytes` to the
 [connection](#dfn-connection).

::: header-wrapper
### 6.4 Routing requests

[Request routing] is the process of going from an
[HTTP request](#dfn-http-request) to the [series of
steps](#dfn-remote-end-steps) needed to implement
the [command](#dfn-commands) represented by that request.

A [remote end](#dfn-remote-ends) has an associated [URL
prefix], which is used as a prefix on all WebDriver-defined URLs
on that [remote end](#dfn-remote-ends). This must either be
[undefined](#dfn-undefined) or a [path-absolute
URL](#dfn-path-absolute-url).

[Example 2](#example-2)

For example a [remote end](#dfn-remote-ends) wishing to run alongside other services on
`example.com` might set its [URL
prefix](#dfn-url-prefix) to `/wd` so that a [new
session](#dfn-new-sessions) [command](#dfn-commands) would be invoked by sending a POST request
to `/wd/session`, rather than `/session`.

In order to [match a request] given a
[`method`](#dfn-method) and [`URL`](#dfn-url), the following steps must be taken:

1. Let `endpoints` be a list containing each row in the
 [table of endpoints](#dfn-endpoints).

2. Remove each entry from `endpoints` for which the
 concatenation of the [URL
 prefix](#dfn-url-prefix) and the entry\'s [URI
 template](#dfn-uri-template) does not have a valid expansion equal
 to `URL`\'s [path](#dfn-path).

3. If there are no entries in `endpoints`, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [unknown
 command](#dfn-unknown-command).

4. Remove each entry in `endpoints` for which the *method*
 column is not equal to `method`.

5. If there are no entries in `endpoints`, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [unknown
 method](#dfn-unknown-method).

6. There is now exactly one entry in `endpoints`; let
 `entry` be this entry.

7. Let `URI template` be the concatenation of [URL
 prefix](#dfn-url-prefix) with `entry`\'s
 `URI template`.

8. Let `command` be `entry`\'s
 [command](#dfn-commands).

9. Let `URL variables` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) with one
 [entry](https://infra.spec.whatwg.org/#map-entry) for each variable defined in
 `URI template`, with the entry name equal to the template
 variable name, and the entry value being the variable value required
 to expand the `URI template` to match `URL`\'s
 [path](#dfn-path).

10. Return [success](#dfn-success) with data `command` and
 `URL variables`.

::: header-wrapper
### 6.5 Endpoints

The following [table of endpoints] lists the [method](#dfn-method) and [URI
template](#dfn-uri-template) for each [endpoint
node](#dfn-endpoint-node) [command](#dfn-commands). [Extension
commands](#dfn-extension-commands) are implicitly appended to this table.

 -------- ------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------
 Method URI Template Command
 POST /session [New Session](#dfn-new-sessions)
 DELETE /session/{`session id`} [Delete Session](#dfn-delete-session)
 GET /status [Status](#dfn-status)
 GET /session/{`session id`}/timeouts [Get Timeouts](#dfn-get-timeouts)
 POST /session/{`session id`}/timeouts [Set Timeouts](#dfn-set-timeouts)
 POST /session/{`session id`}/url [Navigate To](#dfn-navigate-to)
 GET /session/{`session id`}/url [Get Current URL](#dfn-get-current-url)
 POST /session/{`session id`}/back [Back](#dfn-back)
 POST /session/{`session id`}/forward [Forward](#dfn-forward)
 POST /session/{`session id`}/refresh [Refresh](#dfn-refresh)
 GET /session/{`session id`}/title [Get Title](#dfn-get-title)
 GET /session/{`session id`}/window [Get Window Handle](#dfn-get-window-handle)
 DELETE /session/{`session id`}/window [Close Window](#dfn-close-window)
 POST /session/{`session id`}/window [Switch To Window](#dfn-switch-to-window)
 GET /session/{`session id`}/window/handles [Get Window Handles](#dfn-get-window-handles)
 POST /session/{`session id`}/window/new [New Window](#dfn-new-window)
 POST /session/{`session id`}/frame [Switch To Frame](#dfn-switch-to-frame)
 POST /session/{`session id`}/frame/parent [Switch To Parent Frame](#dfn-switch-to-parent-frame)
 GET /session/{`session id`}/window/rect [Get Window Rect](#dfn-get-window-rect)
 POST /session/{`session id`}/window/rect [Set Window Rect](#dfn-set-window-rect)
 POST /session/{`session id`}/window/maximize [Maximize Window](#dfn-maximize-window)
 POST /session/{`session id`}/window/minimize [Minimize Window](#dfn-minimize-window)
 POST /session/{`session id`}/window/fullscreen [Fullscreen Window](#dfn-fullscreen-window)
 GET /session/{`session id`}/element/active [Get Active Element](#dfn-get-active-element)
 GET /session/{`session id`}/element/{`element id`}/shadow [Get Element Shadow Root](#dfn-get-element-shadow-root)
 POST /session/{`session id`}/element [Find Element](#dfn-find-element)
 POST /session/{`session id`}/elements [Find Elements](#dfn-find-elements)
 POST /session/{`session id`}/element/{element id}/element [Find Element From Element](#dfn-find-element-from-element)
 POST /session/{`session id`}/element/{element id}/elements [Find Elements From Element](#dfn-find-elements-from-element)
 POST /session/{`session id`}/shadow/`{shadow id}`/element [Find Element From Shadow Root](#dfn-find-element-from-shadow-root)
 POST /session/{`session id`}/shadow/`{shadow id}`/elements [Find Elements From Shadow Root](#dfn-find-elements-from-shadow-root)
 GET /session/{`session id`}/element/{`element id`}/selected [Is Element Selected](#dfn-is-element-selected)
 GET /session/{`session id`}/element/{`element id`}/attribute/{`name`} [Get Element Attribute](#dfn-get-element-attribute)
 GET /session/{`session id`}/element/{`element id`}/property/{`name`} [Get Element Property](#dfn-get-element-property)
 GET /session/{`session id`}/element/{`element id`}/css/{`property name`} [Get Element CSS Value](#dfn-get-element-css-value)
 GET /session/{`session id`}/element/{`element id`}/text [Get Element Text](#dfn-get-element-text)
 GET /session/{`session id`}/element/{`element id`}/name [Get Element Tag Name](#dfn-get-element-tag-name)
 GET /session/{`session id`}/element/{`element id`}/rect [Get Element Rect](#dfn-get-element-rect)
 GET /session/{`session id`}/element/{`element id`}/enabled [Is Element Enabled](#dfn-is-element-enabled)
 GET /session/{`session id`}/element/{`element id`}/computedrole [Get Computed Role](#dfn-get-computed-role)
 GET /session/{`session id`}/element/{`element id`}/computedlabel [Get Computed Label](#dfn-get-computed-label)
 POST /session/{`session id`}/element/{`element id`}/click [Element Click](#dfn-element-click)
 POST /session/{`session id`}/element/{`element id`}/clear [Element Clear](#dfn-element-clear)
 POST /session/{`session id`}/element/{`element id`}/value [Element Send Keys](#dfn-element-send-keys)
 GET /session/{`session id`}/source [Get Page Source](#dfn-get-page-source)
 POST /session/{`session id`}/execute/sync [Execute Script](#dfn-execute-script)
 POST /session/{`session id`}/execute/async [Execute Async Script](#dfn-execute-async-script)
 GET /session/{`session id`}/cookie [Get All Cookies](#dfn-get-all-cookies)
 GET /session/{`session id`}/cookie/{`name`} [Get Named Cookie](#dfn-get-named-cookie)
 POST /session/{`session id`}/cookie [Add Cookie](#dfn-adding-a-cookie)
 DELETE /session/{`session id`}/cookie/{`name`} [Delete Cookie](#dfn-delete-cookie)
 DELETE /session/{`session id`}/cookie [Delete All Cookies](#dfn-delete-all-cookies)
 POST /session/{`session id`}/actions [Perform Actions](#dfn-perform-actions)
 DELETE /session/{`session id`}/actions [Release Actions](#dfn-release-actions)
 POST /session/{`session id`}/alert/dismiss [Dismiss Alert](#dfn-dismiss-alert)
 POST /session/{`session id`}/alert/accept [Accept Alert](#dfn-accept-alert)
 GET /session/{`session id`}/alert/text [Get Alert Text](#dfn-get-alert-text)
 POST /session/{`session id`}/alert/text [Send Alert Text](#dfn-send-alert-text)
 GET /session/{`session id`}/screenshot [Take Screenshot](#dfn-take-screenshot)
 GET /session/{`session id`}/element/{`element id`}/screenshot [Take Element Screenshot](#dfn-take-element-screenshot)
 POST /session/{`session id`}/print [Print Page](#dfn-print-page)
 -------- ------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------

::: header-wrapper
### 6.6 Errors

[Errors](#dfn-error)
are represented in the WebDriver protocol by an [HTTP
response](#dfn-http-response) with an [HTTP
status](#dfn-http-status) in the 4xx or 5xx range, and a JSON body containing
details of the [error](#dfn-error). The body is a JSON
[Object](#dfn-object) and has a field named \"`value`\" whose value is an
object bearing three, and sometimes four, fields:

- \"`error`\", containing a string indicating the [error
 code](#dfn-error-code).
- \"`message`\", containing an implementation-defined string with a
 human readable description of the kind of error that occurred.
- \"`stacktrace`\", containing an implementation-defined string with a
 stack trace report of the active stack frames at the time when the
 error occurred.
- Optionally \"`data`\", which is a JSON
 [Object](#dfn-object) with additional [error
 data](#dfn-error-data) helpful in diagnosing the error.

[Example 3](#example-3)

A `GET` request to `/session/1234/url`, where `1234` is not the [session
id](#dfn-session-id) of a [session](#dfn-sessions) would return an [HTTP
response](#dfn-http-response) with the status 404 and a body of the form:

```
{
 "value": {
 "error": "invalid session id",
 "message": "No active session with ID 1234",
 "stacktrace": ""
 }
}
```

Certain commands may also annotate
[errors](#dfn-error)
with additional [error data](#dfn-error-data). Notably, this is the case for commands
which invoke the [user prompt
handler](#dfn-user-prompt-handler), where the [user prompt
message](#dfn-user-prompt-message) may be included in a \"`text`\" field:

```
{
 "value": {
 "error": "unexpected alert open",
 "message": "",
 "stacktrace": "",
 "data": {
 "text": "Message from window.alert"
 }
 }
}
```

The following table lists each [error code], its
associated [HTTP status](#dfn-http-status), JSON `error` code, and a non-normative
description of the error. The [error response
data] for a particular [error
code](#dfn-error-code) is the values of the *HTTP Status* and *JSON Error
Code* columns for the row corresponding to that [error
code](#dfn-error-code).

 --------------------------------------------------------------------------------------------------------------------- ------------- ----------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Error Code HTTP Status JSON Error Code Description
 [element click intercepted] 400 `element click intercepted` The [Element Click](#dfn-element-click) [command](#dfn-commands) could not be completed because the [element](https://dom.spec.whatwg.org/#concept-element) receiving the events is [obscuring](#dfn-obscuring) the element that was requested clicked.
 [element not interactable] 400 `element not interactable` A [command](#dfn-commands) could not be completed because the element is not [pointer](#dfn-pointer-interactable)- or [keyboard](#dfn-keyboard-interactable) [interactable](#dfn-interactable).
 [insecure certificate] 400 `insecure certificate` [Navigation](#dfn-navigating) caused the user agent to hit a certificate warning, which is usually the result of an expired or invalid TLS certificate.
 [invalid argument] 400 `invalid argument` The arguments passed to a [command](#dfn-commands) are either invalid or malformed.
 [invalid cookie domain] 400 `invalid cookie domain` An illegal attempt was made to set a cookie under a different domain than the current page.
 [invalid element state] 400 `invalid element state` A [command](#dfn-commands) could not be completed because the element is in an invalid state, e.g. attempting to [clear](#dfn-element-clear) an element that isn\'t both [editable](#dfn-editable) and [resettable](#dfn-resettable-elements).
 [invalid selector] 400 `invalid selector` Argument was an invalid selector.
 [invalid session id] 404 `invalid session id` Occurs if the given [session id](#dfn-session-id) is not in the list of [active sessions](#dfn-active-sessions), meaning the [session](#dfn-sessions) either does not exist or that it\'s not active.
 [javascript error] 500 `javascript error` An error occurred while executing JavaScript supplied by the user.
 [move target out of bounds] 500 `move target out of bounds` The target for mouse interaction is not in the browser\'s viewport and cannot be brought into that viewport.
 [no such alert] 404 `no such alert` An attempt was made to operate on a modal dialog when one was not open.
 [no such cookie] 404 `no such cookie` No cookie matching the given path name was found amongst the [associated cookies](#dfn-associated-cookies) of `session`\'s [current browsing context](#dfn-current-browsing-context)\'s [active document](#dfn-active-document).
 [no such element] 404 `no such element` An element could not be located on the page using the given search parameters.
 [no such frame] 404 `no such frame` A [command](#dfn-commands) to switch to a frame could not be satisfied because the frame could not be found.
 [no such window] 404 `no such window` A [command](#dfn-commands) to switch to a window could not be satisfied because the window could not be found.
 [no such shadow root] 404 `no such shadow root` The element does not have a shadow root.
 [script timeout error] 500 `script timeout` A script did not complete before its timeout expired.
 [session not created] 500 `session not created` A new [session](#dfn-sessions) could not be created.
 [stale element reference] 404 `stale element reference` A [command](#dfn-commands) failed because the referenced [element](https://dom.spec.whatwg.org/#concept-element) is no longer attached to the DOM.
 [detached shadow root] 404 `detached shadow root` A [command](#dfn-commands) failed because the referenced [shadow root](#dfn-shadow-roots) is no longer attached to the DOM.
 [timeout] 500 `timeout` An operation did not complete before its timeout expired.
 [unable to set cookie] 500 `unable to set cookie` A [command](#dfn-commands) to set a cookie\'s value could not be satisfied.
 [unable to capture screen] 500 `unable to capture screen` A screen capture was made impossible.
 [unexpected alert open] 500 `unexpected alert open` A modal dialog was open, blocking this operation.
 [unknown command] 404 `unknown command` A [command](#dfn-commands) could not be executed because the [remote end](#dfn-remote-ends) is not aware of it.
 [unknown error] 500 `unknown error` An unknown error occurred in the [remote end](#dfn-remote-ends) while processing the [command](#dfn-commands).
 [unknown method] 405 `unknown method` The requested [command](#dfn-commands) matched a known URL but did not match any method for that URL.
 [unsupported operation] 500 `unsupported operation` Indicates that a [command](#dfn-commands) that should have executed properly cannot be supported for some reason.
 --------------------------------------------------------------------------------------------------------------------- ------------- ----------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

An [error data] dictionary is a mapping of string keys to JSON
serializable values that can optionally be included with
[error](#dfn-error)
objects.

::: header-wrapper
### 6.7 Extensions

Using the terminology defined in this section, others may define
additional commands that seamlessly integrate with the standard
protocol. This allows vendors to expose functionality that is specific
to their user agent, and it also allows other web standards to define
commands for automating new platform features.

Commands defined in this way are called [extension
commands] and behave no differently than other
[commands](#dfn-commands); each has a dedicated HTTP endpoint and a set of
[remote end
steps](#dfn-remote-end-steps).

Each [extension
command](#dfn-extension-commands) has an associated [extension command URI
Template] that is a [URI
Template](#dfn-uri-template) string, and which should bear some resemblance to what
the command performs. This value, along with the HTTP method and
[extension
command](#dfn-extension-commands), is added to the [table of
endpoints](#dfn-endpoints) and thus follows the same rules for [request
routing](#dfn-routing-requests) as that of other built-in
[commands](#dfn-commands).

In order to avoid potential resource conflicts with other
implementations, vendor-specific [extension command URI
Templates](#dfn-extension-command-uri-template) must
begin with one or more path segments which uniquely identifies the
vendor and UA. It is suggested that vendors use their vendor prefixes
without additional characters as outlined in
\[[CSS21](#bib-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")\], notably in [section 4.1.2.2 on *vendor
keywords*](https://www.w3.org/TR/CSS21/syndata.html#vendor-keywords), as
the name for this path element, and include a vendor-chosen UA
identifier.

If the [extension command URI
Template](#dfn-extension-command-uri-template) includes a variable named
`session id`, the value of this variable will be used to
define the [session](#dfn-sessions) during command processing.

[Example 4](#example-4)

This might lead to a URL of the form
`/session/5d376174-36f0-11e5-9b9a-6bdf200a3f7f/`*`ms`*`/`*`edge`*`/`*`context`*,
where `session/{``session id``}` associates the request with
the specified session, `ms/edge` identifies the command as specific to
the Edge browser distributed by Microsoft, and `context` describes the
functionality that, in the context of Edge, allows a [local
end](#dfn-local-ends) to switch between browser-specific contexts. Requesting
this URL will call the [extension
command](#dfn-extension-commands)\'s [remote end
steps](#dfn-remote-end-steps).

Other specifications may define [additional WebDriver
capabilities]. Each defined capability must
have a [capability name] which is a string
not containing a \"`:`\" (colon) character, an [additional capability
deserialization
algorithm]
which is a set of steps taking a single argument `value`
which has a JSON type, returning either
[success](#dfn-success) wrapping the deserialized capability value or
[error](#dfn-error).

An [additional WebDriver
capability](#dfn-additional-webdriver-capability) may also define a [matched capability
serialization algorithm], which is a set of steps used to determine if a
capability is matched by the current implementation and provide any
computed value to return to the user. This set of steps takes a single
argument `value`, which is the output of the corresponding
[additional capability deserialization
algorithm](#dfn-additional-capability-deserialization-algorithm), and returns either
[`null`](#dfn-null) to
indicate the capability is not matched, or a non-null JSON-serializable
value if the capability is matched.

Other specifications may also define [WebDriver new session
algorithms], which are called just after a
new session is created, and before the [new
session](#dfn-new-sessions) response is sent to the [remote
end](#dfn-remote-ends). These algorithms are called with `session`
representing the WebDriver session that will be established, and
`capabilities`, the capabilities object that will be returned
to the [remote end](#dfn-remote-ends). It is permitted for such an algorithm to
modify any entry in the capabilities object with a name that\'s an
[additional WebDriver
capability](#dfn-additional-webdriver-capability) defined by the same specification.

[Remote ends](#dfn-remote-ends) may also introduce [extension
capabilities] that are extra
[capabilities](#dfn-capabilities) used to provide configuration or fulfill
other vendor-specific needs. Extension capabilities\' key must contain a
\"`:`\" (colon) character, denoting an implementation specific
namespace. The value can be arbitrary JSON types.

As with [extension
commands](#dfn-extension-commands), it is suggested that the key used to
denote the [extension
capability](#dfn-extension-capability) namespace is based on the [vendor
keywords](https://www.w3.org/TR/CSS21/syndata.html#vendor-keywords)
listed in
\[[CSS21](#bib-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")\] and precedes the first \"`:`\" character in the
string.

[Example 5](#example-5)

[Extension
capabilities](#dfn-extension-capability) are typically used to provide UA or
[intermediary
node](#dfn-intermediary-nodes) specific configuration that is not handled
by the [table of standard
capabilities](#dfn-table-of-standard-capabilities).

An example [new session](#dfn-new-sessions) request body might look like this:

``` {aria-busy="false"}
{
 "capabilities": {
 "alwaysMatch": {
 // browser specific configuration
 "<prefix>:browserOptions": {
 "binary": "/usr/bin/browser-binary",
 "args": ["--start-page=https://example.com"],
 }
 }
 }
}
```

::: header-wrapper
## 7. Capabilities

WebDriver [capabilities] are used to
communicate the features supported by a given implementation. The [local
end](#dfn-local-ends) may use capabilities to define which features it
requires the [remote end](#dfn-remote-ends) to satisfy when creating a [new
session](#dfn-new-sessions). Likewise, the [remote
end](#dfn-remote-ends) uses capabilities to describe the full feature set for
a [session](#dfn-sessions).

The following [table of standard
capabilities] enumerates the capabilities each
implementation must support. An implementation may define additional
[extension
capabilities](#dfn-extension-capability).

[Example 6](#example-6)

As an example, Mozilla could elect to hide new features behind
capabilities with a \"`moz:`\" prefix:

``` {aria-busy="false"}
{
 "browserName": "firefox",
 "browserVersion": "1234",
 "moz:experimental-webdriver": true
}
```

 Capability Key Value Type Description
 -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- --------------------------------- -------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Browser name \"`browserName`\" string Identifies the user agent.
 Browser version \"`browserVersion`\" string Identifies the version of the user agent.
 [Platform name] \"`platformName`\" string Identifies the operating system of the [endpoint node](#dfn-endpoint-node).
 [Accept insecure TLS certificates] \"`acceptInsecureCerts`\" boolean Indicates whether untrusted and self-signed TLS certificates are implicitly trusted on [navigation](#dfn-navigating) for the duration of the [session](#dfn-sessions).
 [Page load strategy] \"`pageLoadStrategy`\" string Defines the [session](#dfn-sessions)\'s [page load strategy](#dfn-page-load-strategy).
 Proxy configuration \"`proxy`\" JSON [Object](#dfn-object) Defines the [session](#dfn-sessions)\'s [proxy configuration](#dfn-proxy-configuration).
 [Window dimensioning/positioning] \"`setWindowRect`\" boolean Indicates whether the remote end supports all of the [resizing and repositioning](#resizing-and-positioning-windows) [commands](#dfn-commands).
 [Session timeouts](#dfn-session-timeouts) \"`timeouts`\" JSON [Object](#dfn-object) Describes the [timeouts](#timeouts) imposed on certain session operations.
 [Strict file interactability](#dfn-strict-file-interactability) \"`strictFileInteractability`\" boolean Defines the [session](#dfn-sessions)\'s [strict file interactability](#dfn-strict-file-interactability).
 Unhandled prompt behavior \"`unhandledPromptBehavior`\" string Describes the [session](#dfn-sessions)\'s [user prompt handler](#dfn-user-prompt-handler). Defaults to \"`dismiss and notify`\".
 User Agent \"`userAgent`\" string Identifies the [default User-Agent value](#dfn-default-user-agent-value) of the [endpoint node](#dfn-endpoint-node).

::: header-wrapper
### 7.1 Proxy

The [proxy configuration] capability is a JSON
[Object](#dfn-object) nested within the primary
[capabilities](#dfn-capabilities). Implementations may define additional
proxy configuration options, but they must not alter the semantics of
those listed below.

 Key Value Type Description Valid values
 --------------------------------------------------------------------------------------- ------------ ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 [`proxyType`] string Indicates the type of proxy configuration. \"`pac`\", \"`direct`\", \"`autodetect`\", \"`system`\", or \"`manual`\".
 `proxyAutoconfigUrl` string Defines the URL for a [proxy autoconfiguration](#dfn-proxy-autoconfiguration) file if [`proxyType`](#dfn-proxytype) is equal to \"`pac`\". Any [URL](#dfn-url).
 `httpProxy` string Defines the proxy [host](#dfn-host) for HTTP traffic when the [`proxyType`](#dfn-proxytype) is \"`manual`\". A [host and optional port](#dfn-host-and-optional-port) for scheme \"`http`\".
 `noProxy` array Lists the address for which the proxy should be bypassed when the [`proxyType`](#dfn-proxytype) is \"`manual`\". A [List](#dfn-list) containing any number of [String](#dfn-string)s.
 `sslProxy` string Defines the proxy [host](#dfn-host) for encrypted TLS traffic when the [`proxyType`](#dfn-proxytype) is \"`manual`\". A [host and optional port](#dfn-host-and-optional-port) for scheme \"`https`\".
 `socksProxy` string Defines the proxy [host](#dfn-host) for a [SOCKS proxy](#dfn-socks-proxy) when the [`proxyType`](#dfn-proxytype) is \"`manual`\". A [host and optional port](#dfn-host-and-optional-port) with an [undefined](#dfn-undefined) scheme.
 `socksVersion` number Defines the [SOCKS proxy](#dfn-socks-proxy) version when the [`proxyType`](#dfn-proxytype) is \"`manual`\". Any [integer](#dfn-integer) between 0 and 255 inclusive.

A [host and optional port] for a `scheme` is
defined as being a valid [host](#dfn-host), optionally followed by a colon and a
valid [port](#dfn-port). The [host](#dfn-host) may [include
credentials](#dfn-includes-credentials). If the port is
omitted and `scheme` has a [default
port](#dfn-default-port), this is the implied port. Otherwise, the port is left
undefined.

A [`proxyType`](#dfn-proxytype) of \"`direct`\" indicates that the browser should not
use a proxy at all.

A [`proxyType`](#dfn-proxytype) of \"`system`\" indicates that the browser should use
the various proxies configured for the underlying Operating System.

A [`proxyType`](#dfn-proxytype) of \"`autodetect`\" indicates that the proxy to use
should be detected in an implementation-specific way.

The [remote end](#dfn-remote-ends) steps to [deserialize as a
proxy] argument `parameter`
are:

1. If `parameter` is not a JSON
 [Object](#dfn-object) return an [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

2. Let `proxy` be a new, empty [proxy configuration
 object](#dfn-proxy-configuration-object).

3. For each enumerable [own
 property](#dfn-own-properties) in `parameter` run the
 following substeps:

 1. Let `key` be the name of the property.

 2. Let `value` be the result of [getting a
 property](#dfn-getting-properties) named `name` from
 `parameter`.

 3. If there is no matching `key` for `key` in the [proxy
 configuration](#dfn-proxy-configuration) table return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 4. If `value` is not one of the `valid values` for that
 `key`, return an [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 5. [Set a
 property](#dfn-set-a-property) `key` to
 `value` on `proxy`.

4. If `proxy` does not have an [own
 property](#dfn-own-properties) for \"`proxyType`\" return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

5. If the result of [getting a
 property](#dfn-getting-properties) named \"`proxyType`\" from
 `proxy` equals \"`pac`\", and `proxy` does not
 have an [own
 property](#dfn-own-properties) for \"`proxyAutoconfigUrl`\" return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

6. If `proxy` has an [own
 property](#dfn-own-properties) for \"`socksProxy`\" and does not have
 an [own property](#dfn-own-properties) for \"`socksVersion`\" return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

7. Return [success](#dfn-success) with data `proxy`.

A [proxy configuration object] is a JSON
[Object](#dfn-object) where each of its [own
properties](#dfn-own-properties) matching keys in the [proxy
configuration](#dfn-proxy-configuration) meets the validity criteria for that key.

::: header-wrapper
### 7.2 Processing capabilities

To [process capabilities] given `parameters`,
and [session configuration
flags](#dfn-session-configuration-flags) `flags`, the [endpoint
node](#dfn-endpoint-node) must take the following steps:

1. Let `capabilities request` be the result of [getting the
 property](#dfn-getting-properties) \"`capabilities`\" from
 `parameters`.

 1. If `capabilities request` is not a JSON
 [Object](#dfn-object), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

2. Let `required capabilities` be the result of [getting the
 property](#dfn-getting-properties) \"`alwaysMatch`\" from
 `capabilities request`.

 1. If `required capabilities` is
 [undefined](#dfn-undefined), set the value to an empty JSON
 [Object](#dfn-object).

 2. Let `required capabilities` be the result of
 [trying](#dfn-try) to [validate
 capabilities](#dfn-validate-capabilities) with arguments
 `required capabilities` and `flag`.

3. Let `all first match capabilities` be the result of
 [getting the
 property](#dfn-getting-properties) \"`firstMatch`\" from
 `capabilities request`.

 1. If `all first match capabilities` is
 [undefined](#dfn-undefined), set the value to a
 [List](#dfn-list) with a single entry of an empty JSON
 [Object](#dfn-object).

 2. If `all first match capabilities` is not a
 [List](#dfn-list) with one or more entries, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

4. Let `validated first match capabilities` be an empty
 [List](#dfn-list).

5. For each `first match capabilities` corresponding to an
 indexed property in `all first match capabilities`:

 1. Let `validated capabilities` be the result of
 [trying](#dfn-try) to [validate
 capabilities](#dfn-validate-capabilities) with arguments
 `first match capabilities` and `flags`.

 2. Append `validated capabilities` to
 `validated first match capabilities`.

6. Let `merged capabilities` be an empty
 [List](#dfn-list).

7. For each `first match capabilities` corresponding to an
 indexed property in `validated first match capabilities`:

 1. Let `merged` be the result of
 [trying](#dfn-try) to [merge
 capabilities](#dfn-merging-capabilities) with
 `required capabilities` and
 `first match capabilities` as arguments.

 2. Append `merged` to `merged capabilities`.

8. For each `capabilities` corresponding to an indexed
 property in `merged capabilities`:

 1. Let `matched capabilities` be the result of
 [trying](#dfn-try) to [match
 capabilities](#dfn-matching-capabilities) with
 `capabilities` as an argument.

 2. If `matched capabilities` is not
 [`null`](#dfn-null), return
 [success](#dfn-success) with data `matched capabilities`.

9. Return [success](#dfn-success) with data [`null`](#dfn-null).

When required to [validate capabilities] with argument
`capabilities`:

1. If `capabilities` is not a JSON
 [Object](#dfn-object) return an [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

2. Let `result` be an empty JSON
 [Object](#dfn-object).

3. For each enumerable [own
 property](#dfn-own-properties) in `capabilities`, run the
 following substeps:

 1. Let `name` be the name of the property.

 2. Let `value` be the result of [getting a
 property](#dfn-getting-properties) named `name` from
 `capabilities`.

 3. Run the substeps of the first matching condition:

 `value` is [`null`](#dfn-null)

 : Let `deserialized` be set to
 [`null`](#dfn-null).

 `name` equals \"`acceptInsecureCerts`\"

 : If `value` is not a
 [boolean](#dfn-boolean) return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument). Otherwise, let
 `deserialized` be set to `value`.

 `name` equals \"`browserName`\"\
 `name` equals \"`browserVersion`\"\
 `name` equals \"`platformName`\"

 : If `value` is not a
 [string](#dfn-string) return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument). Otherwise, let
 `deserialized` be set to `value`.

 `name` equals \"`pageLoadStrategy`\"

 : Let `deserialized` be the result of
 [trying](#dfn-try) to [deserialize as a page load
 strategy](#dfn-deserialize-as-a-page-load-strategy) with argument
 `value`.

 `name` equals \"`proxy`\"

 : Let `deserialized` be the result of
 [trying](#dfn-try) to [deserialize as a
 proxy](#dfn-deserialize-as-a-proxy) with argument
 `value`.

 `name` equals \"`strictFileInteractability`\"

 : If `value` is not a
 [boolean](#dfn-boolean) return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument). Otherwise, let
 `deserialized` be set to `value`

 `name` equals \"`timeouts`\"

 : Let `deserialized` be the result of
 [trying](#dfn-try) to [deserialize as timeouts
 configuration](#dfn-deserialize-as-timeouts-configuration) with `value`.

 `name` equals \"`unhandledPromptBehavior`\"

 : Let `deserialized` be the result of
 [trying](#dfn-try) to [deserialize as an unhandled prompt
 behavior](#dfn-deserialize-as-an-unhandled-prompt-behavior) with argument
 `value`.

 `name` is the name of an [additional WebDriver capability](#dfn-additional-webdriver-capability)

 : Let `deserialized` be the result of
 [trying](#dfn-try) to run the [additional capability
 deserialization
 algorithm](#dfn-additional-capability-deserialization-algorithm) for the extension capability
 corresponding to `name`, with argument
 `value`.

 `name` is the key of an [extension capability](#dfn-extension-capability)

 : If `name` is known to the implementation, let
 `deserialized` be the result of
 [trying](#dfn-try) to deserialize `value` in an
 implementation-specific way. Otherwise, let
 `deserialized` be set to `value`.

 The [remote end](#dfn-remote-ends) is an [endpoint node](#dfn-endpoint-node)

 : Return an [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 4. If `deserialized` is not
 [`null`](#dfn-null), [set a
 property](#dfn-set-a-property) on `result` with name
 `name` and value `deserialized`.

4. Return [success](#dfn-success) with data `result`.

When [merging capabilities] with JSON
[Object](#dfn-object) arguments `primary` and
`secondary`, an [endpoint
node](#dfn-endpoint-node) must take the following steps:

1. Let `result` be a new JSON
 [Object](#dfn-object).

2. For each enumerable [own
 property](#dfn-own-properties) in `primary`, run the
 following substeps:

 1. Let `name` be the name of the property.

 2. Let `value` be the result of [getting a
 property](#dfn-getting-properties) named `name` from
 `primary`.

 3. [Set a
 property](#dfn-set-a-property) on `result` with name
 `name` and value `value`.

3. If `secondary` is
 [undefined](#dfn-undefined), return `result`.

4. For each enumerable [own
 property](#dfn-own-properties) in `secondary`, run the
 following substeps:

 1. Let `name` be the name of the property.

 2. Let `value` be the result of [getting a
 property](#dfn-getting-properties) named `name` from
 `secondary`.

 3. Let `primary value` be the result of [getting the
 property](#dfn-getting-properties) `name` from
 `primary`.

 4. If `primary value` is not
 [undefined](#dfn-undefined), return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 5. [Set a
 property](#dfn-set-a-property) on `result` with name
 `name` and value `value`.

5. Return `result`.

The algorithm outlined in [matching
capabilities](#dfn-matching-capabilities) blithely ignores real-world problems that
make implementation less than perfectly straightforward, particularly
since capabilities can interact in unforeseen ways.

As an example, an implementation could have a capability that gives the
path to the browser binary to use. This could cause both `browserName`
and `browserVersion` to be impossible to match against until the browser
process is started.

When [matching capabilities] given JSON
[Object](#dfn-object) `capabilities`, and a [session configuration
flags](#dfn-session-configuration-flags) `flags`, an [endpoint
node](#dfn-endpoint-node) must take the following steps:

1. Let `matched capabilities` be a JSON
 [Object](#dfn-object) with the following entries:

 \"`browserName`\"
 : [ASCII
 Lowercase](https://infra.spec.whatwg.org/#ascii-lowercase) name of the user agent as a
 [string](#dfn-string).

 \"`browserVersion`\"
 : The user agent version, as a
 [string](#dfn-string).

 \"`platformName`\"
 : [ASCII
 Lowercase](https://infra.spec.whatwg.org/#ascii-lowercase) name of the current platform as a
 [string](#dfn-string).

 \"`acceptInsecureCerts`\"
 : [Boolean](#dfn-boolean) initially set to false, indicating the session
 will not implicitly trust untrusted or self-signed TLS
 certificates on
 [navigation](#dfn-navigating).

 \"`strictFileInteractability`\"
 : [Boolean](#dfn-boolean) initially set to false, indicating that
 interactability checks will be applied to \<input type=file\>.

 \"`setWindowRect`\"
 : Boolean indicating whether the [remote
 end](#dfn-remote-ends) supports all of the [resizing and
 positioning](#resizing-and-positioning-windows)
 [commands](#dfn-commands).

 \"`userAgent`\"
 : String containing the [default User-Agent
 value](#dfn-default-user-agent-value).

2. If `flags` contains \"`http`\", add the following entries
 to `matched capabilities`:

 \"`strictFileInteractability`\"
 : [Boolean](#dfn-boolean) initially set to false, indicating that
 interactabilty checks will be applied to \<input type=file\>.

3. Optionally add [extension
 capabilities](#dfn-extension-capability) as entries to
 `matched capabilities`. The values of these may be
 elided, and there is no requirement that all [extension
 capabilities](#dfn-extension-capability) be added.

 ::::
 :::
 Note
 :::

 This allows a [remote
 end](#dfn-remote-ends) to add information that might be useful to a [local
 end](#dfn-local-ends) without unnecessarily bloating the response sent
 back to the user with (e.g.) an entire browser profile.

 For example, an implementation could choose to indicate that a
 screenshot will be taken when returning an error by setting the
 capability `se:screenshot-on-error` to `true`.
 ::::

4. For each `name` and `value` corresponding to
 `capabilities`\'s [own
 properties](#dfn-own-properties):

 1. Let `match value` equal `value`.

 2. Run the substeps of the first matching `name`:

 \"`browserName`\"

 : If `value` is not a string equal to the
 \"`browserName`\" entry in
 `matched capabilities`, return
 [success](#dfn-success) with data
 [`null`](#dfn-null).

 ::::
 :::
 Note
 :::

 There is a chance the [remote
 end](#dfn-remote-ends) will need to start a browser
 process to correctly determine the `browserName`.
 Lightweight checks are preferred before this is done.
 ::::

 \"`browserVersion`\"

 : Compare `value` to the \"`browserVersion`\" entry
 in `matched capabilities` using an
 implementation-defined comparison algorithm. The comparison
 is to accept a `value` that places constraints on
 the version using the \"`<`\", \"`<=`\", \"`>`\", and
 \"`>=`\" operators.

 If the two values do not match, return
 [success](#dfn-success) with data
 [`null`](#dfn-null).

 ::::
 :::
 Note
 :::

 Version comparison is left as an implementation detail since
 each user agent will likely have conflicting methods of
 encoding the user agent version, and standardizing these
 schemes is beyond the scope of this standard.
 ::::

 ::::
 :::
 Note
 :::

 There is a chance the [remote
 end](#dfn-remote-ends) will need to start a browser
 process to correctly determine the `browserVersion`.
 Lightweight checks are preferred before this is done.
 ::::

 \"`platformName`\"

 : If `value` is not a string equal to the
 \"`platformName`\" entry in
 `matched capabilities`, return
 [success](#dfn-success) with data
 [`null`](#dfn-null).

 :::::
 :::
 Note
 :::

 :::
 The following platform names are in common usage with
 well-understood semantics and, when [matching
 capabilities](#dfn-matching-capabilities) for [platform
 name](#dfn-platform-name), greatest interoperability can
 be achieved by honoring them as valid synonyms for
 well-known Operating Systems:

 --------------- --------------------------------------------------------------------------
 Key System
 \"`linux`\" Any server or desktop system based upon the Linux kernel.
 \"`mac`\" Any version of Apple\'s macOS.
 \"`windows`\" Any version of Microsoft Windows, including desktop and mobile versions.
 --------------- --------------------------------------------------------------------------

 This list is not exhaustive.

 When returning
 [capabilities](#dfn-capabilities) from [New
 Session](#dfn-new-sessions), it is valid to return a more
 specific `platformName`, allowing users to correctly
 identify the Operating System the WebDriver implementation
 is running on.
 :::
 :::::

 \"`acceptInsecureCerts`\"

 : If [accept insecure
 TLS](#dfn-accept-insecure-tls) flag is set and not equal to
 `value`, return
 [success](#dfn-success) with data
 [`null`](#dfn-null).

 ::::
 :::
 Note
 :::

 If the [endpoint
 node](#dfn-endpoint-node) does not support [insecure TLS
 certificates](#dfn-insecure-tls-certificates) and this is the reason no
 match is ultimately made, it is useful to provide this
 information to the [local
 end](#dfn-local-ends).
 ::::

 \"`proxy`\"

 : If the [has proxy
 configuration](#dfn-has-proxy-configuration) flag is set, or if the proxy
 configuration defined in `value` is not one that
 passes the [endpoint
 node](#dfn-endpoint-node)\'s implementation-specific
 validity checks, return
 [success](#dfn-success) with data
 [`null`](#dfn-null).

 ::::
 :::
 Note
 :::

 A [local end](#dfn-local-ends) would only send this
 capability if it expected it to be honored and the
 configured proxy used. The intent is that if this is not
 possible a new session will not be established.
 ::::

 \"`unhandledPromptBehavior`\"

 : If [check user prompt handler
 matches](#dfn-check-user-prompt-handler-matches) with `value` is
 false, return
 [success](#dfn-success) with data
 [`null`](#dfn-null).

 **Otherwise**

 : - If `name` is the name of an [additional
 WebDriver
 capability](#dfn-additional-webdriver-capability) which defines a [matched
 capability serialization
 algorithm](#dfn-matched-capability-serialization-algorithm), let
 `match value` be the result of running the
 [matched capability serialization
 algorithm](#dfn-matched-capability-serialization-algorithm) for capability
 `name` with arguments `value`, and
 `flags`.

 - Otherwise, if `name` is the key of an
 [extension
 capability](#dfn-extension-capability), let
 `match value` be the result of
 [trying](#dfn-try) implementation-specific steps to match on
 `name` with `value`. If the match is
 not successful, return
 [success](#dfn-success) with data
 [`null`](#dfn-null).

 3. If `match value` is not null, [set a
 property](#dfn-set-a-property) on
 `matched capabilities` with name `name`
 and value `match value`.

5. Return [success](#dfn-success) with data `matched capabilities`.

::: header-wrapper
## 8. Sessions

A WebDriver [session] represents the
logical connection between a [local
end](#dfn-local-ends) and a specific [remote
end](#dfn-remote-ends). The [session](#dfn-sessions) object holds state specific to that
connection.

An [intermediary
node](#dfn-intermediary-nodes) will maintain an [associated
session] for each active
[session](#dfn-sessions). This is the
[session](#dfn-sessions) on the
[upstream](#dfn-upstream) neighbor that is created when the [intermediary
node](#dfn-intermediary-nodes) executes the [New
Session](#dfn-new-sessions) [command](#dfn-commands). Closing a
[session](#dfn-sessions) on an [intermediary
node](#dfn-intermediary-nodes) will also [close the
session](#dfn-close-the-session) of the [associated
session](#dfn-associated-session).

A [session](#dfn-sessions) has a [session ID], which is the string
representation of a [UUID](#dfn-uuid) used to uniquely identify the session. This is set when
creating the session.

A [session](#dfn-sessions) has a boolean [HTTP flag] which is set when
the session is created. A session with this flag set is an [HTTP
session].

A [remote end](#dfn-remote-ends) has an associated list of [active
sessions], which is a list of all
[session](#dfn-sessions)s that are currently started.

A [remote end](#dfn-remote-ends) has an associated list of [active HTTP
sessions], which is a list of
all [HTTP session](#dfn-http-session)s that are currently started.

The limitation of a single HTTP session for [endpoint
node](#dfn-endpoint-node)s means that the first entry in the list of [active HTTP
sessions](#dfn-active-http-sessions) will be the only entry.

A [HTTP session](#dfn-http-session) has an associated [current browsing
context], which is the [browsing
context](#dfn-browsing-contexts) against which
[commands](#dfn-commands) will run, an associated [current parent browsing
context], which is set to the parent of
the [current browsing
context](#dfn-current-browsing-context) when changing browsing contexts, and an
associated [current top-level browsing
context], which is set to the top-browsing
context ancestor of the [current browsing
context](#dfn-current-browsing-context), when changing browsing contexts.

An [HTTP session](#dfn-http-session) has an associated [session
timeouts] which is a [timeouts
configuration](#dfn-timeouts-configuration). This is initially set to a new [timeouts
configuration](#dfn-timeouts-configuration).

An [HTTP session](#dfn-http-session) has an associated [page loading
strategy], which is one of the keywords
from the [table of page load
strategies](#dfn-table-of-page-load-strategies). This is initially set to
[normal](#dfn-normal-page-loading-strategy).

An [HTTP session](#dfn-http-session) has an associated [strict file
interactability] state which is a boolean. This is
initially set to false.

A [session](#dfn-sessions) has an associated [browsing context input state
map], which is a [weak
map](#dfn-weak-map) with [top-level browsing
contexts](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) as keys, and [input
state](#dfn-input-state) objects as values. This is initially set to an empty
map.

An [HTTP session](#dfn-http-session) has an associated [request
queue] which is a
[queue](https://infra.spec.whatwg.org/#queue) of
[requests](#dfn-http-request) that are currently awaiting processing.

When a session is created, a
[set](https://infra.spec.whatwg.org/#ordered-set) of [session configuration
flags] are provided that define the
features of the session. This specification always creates sessions with
\"`http`\" in [session configuration
flags](#dfn-session-configuration-flags), which corresponds to the [HTTP
flag](#dfn-http-flag). External specifications may define additional flags,
or create sessions without the [HTTP
flag](#dfn-http-flag).

::: header-wrapper
### 8.1 Global State

In addition to per-session state, a [remote
end](#dfn-remote-ends) that is an [endpoint
node](#dfn-endpoint-node) also has additional state that is global across all
sessions.

An [endpoint node](#dfn-endpoint-node) has an associated [accept insecure
TLS] flag that indicates whether untrusted or self-signed TLS
certificates are treated as trusted. The default value of the flag is
false if the endpoint doesn\'t support accepting insecure TLS
connections, or unset otherwise.

An [endpoint node](#dfn-endpoint-node) has an associated [has proxy
configuration] flag that indicates whether the
proxy is already configured. The default value of the flag is true if
the endpoint doesn\'t support proxy configuration, or false otherwise.

To [create a session], given a JSON Object
`capabilites`, and [session configuration
flags](#dfn-session-configuration-flags) `flags`:

1. Let `session id` be the result of [generating a
 UUID](#dfn-generating-a-uuid).

2. Let `session` be a new
 [session](#dfn-sessions) with [session
 ID](#dfn-session-id) `session id`, and [HTTP
 flag](#dfn-http-flag) `flags` contains \"`http`\".

3. Let `proxy` be the result of getting property \"`proxy`\"
 from `capabilities` and run the substeps of the first
 matching statement:

 `proxy` is a [proxy configuration](#dfn-proxy-configuration) object

 : Take implementation-defined steps to set the user agent proxy
 using the extracted `proxy` configuration. If the
 defined proxy cannot be configured return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [session not
 created](#dfn-session-not-created). Otherwise set the [has proxy
 configuration](#dfn-has-proxy-configuration) flag to true.

 Otherwise
 : [Set a
 property](#dfn-set-a-property) of `capabilities` with
 name \"`proxy`\" and a value that is a new JSON
 [Object](#dfn-object).

4. If `capabilites` has a property named
 \"`acceptInsecureCerts`\", set the [endpoint
 node](#dfn-endpoint-node)\'s [accept insecure
 TLS](#dfn-accept-insecure-tls) flag to the result of [getting a
 property](#dfn-getting-properties) named \"`acceptInsecureCerts`\" from
 `capabilities`.

5. Let `user prompt handler capability` be the result of
 getting property \"`unhandledPromptBehavior`\" from
 `capabilities`.

6. If `user prompt handler capability` is not undefined,
 [update the user prompt
 handler](#dfn-update-the-user-prompt-handler) with
 `user prompt handler capability`.

7. Let `serialized user prompt handler` be [serialize the
 user prompt
 handler](#dfn-serialize-the-user-prompt-handler).

8. Set a property on `capabilities` with the name
 \"`unhandledPromptBehavior`\", and the value
 `serialized user prompt handler`.

9. If `flags` `contains` \"`http`\":

 1. Let `strategy` be the result of getting property
 \"`pageLoadStrategy`\" from `capabilities`.

 If `strategy` is a string, set the
 [session](#dfn-sessions)\'s [page loading
 strategy](#dfn-page-loading-strategy) to `strategy`.
 Otherwise, set the [page loading
 strategy](#dfn-page-loading-strategy) to *normal* and [set a
 property](#dfn-set-a-property) of `capabilities` with
 name \"`pageLoadStrategy`\" and value \"`normal`\".

 2. Let `strictFileInteractability` be the result of
 getting property \"`strictFileInteractability`\" from
 `capabilities`. If
 `strictFileInteractability` is a boolean, set
 [session](#dfn-sessions)\'s [strict file
 interactability](#dfn-strict-file-interactability) to
 `strictFileInteractability`.

 3. Let `timeouts` be the result of getting a property
 \"`timeouts`\" from `capabilities`. If
 `timeouts` is not undefined, set
 `session`\'s [session
 timeouts](#dfn-session-timeouts) to `timeouts`.

 4. Set a property on `capabilities` with name
 \"`timeouts`\" and value [serialize the timeouts
 configuration](#dfn-serialize-the-timeouts-configuration) with `session`\'s
 [session
 timeouts](#dfn-session-timeouts).

10. Process any [extension
 capabilities](#dfn-extension-capability) in `capabilities` in an
 implementation-defined manner.

11. Run any [WebDriver new session
 algorithm](#dfn-webdriver-new-session-algorithms) defined in external specifications,
 with arguments `session`, `capabilities`, and
 `flags`.

12. Append `session` to [active
 sessions](#dfn-active-sessions).

13. If `flags` contains \"`http`\", append
 `session` to [active HTTP
 sessions](#dfn-active-http-sessions).

14. Set the [webdriver-active
 flag](#dfn-webdriver-active-flag) to true.

To [close the session], given `session` a
[remote end](#dfn-remote-ends) must take the following steps:

1. If `session`\'s [HTTP
 flag](#dfn-http-flag) is set, remove `session` from [active
 HTTP
 sessions](#dfn-active-http-sessions).

2. Remove `session` from [active
 sessions](#dfn-active-sessions).

3. Perform the following substeps based on the [remote
 end](#dfn-remote-ends)\'s type:

 [Remote end](#dfn-remote-ends) is an [endpoint node](#dfn-endpoint-node)

 : 1. If the list of [active
 sessions](#dfn-active-sessions) is empty:

 1. Set the [webdriver-active
 flag](#dfn-webdriver-active-flag) to false

 2. Set the [user prompt
 handler](#dfn-user-prompt-handler) to null.

 3. Unset the [accept insecure
 TLS](#dfn-accept-insecure-tls) flag.

 4. Reset the [has proxy
 configuration](#dfn-has-proxy-configuration) flag to its default value.

 5. Optionally, [close](#dfn-close) all [top-level browsing
 contexts](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context), without [prompting to
 unload](#dfn-prompting-to-unload).

 [Remote end](#dfn-remote-ends) is an [intermediary node](#dfn-intermediary-nodes)

 : 1. [Close](#dfn-close) the [associated
 session](#dfn-associated-session). If this causes an
 [error](#dfn-error) to occur, complete the remainder of this
 algorithm before returning the
 [error](#dfn-error).

4. Perform any implementation-specific cleanup steps.

5. If an [error](#dfn-error) has occurred in any of the steps above, return the
 [error](#dfn-error), otherwise return
 [success](#dfn-success) with data [`null`](#dfn-null).

Closing a [session](#dfn-sessions) might cause the associated browser process to be
killed. It is assumed that any implementation-specific cleanup steps are
performed *after* the response has been sent back to the client so that
the [connection](#dfn-connection) is not prematurely closed.

::: header-wrapper
### 8.2 [New Session]

------------- --------------
 HTTP Method URI Template
 POST /session
 ------------- --------------

The [New Session](#dfn-new-sessions)
[command](#dfn-commands) creates a new WebDriver
[session](#dfn-sessions) with the [endpoint
node](#dfn-endpoint-node). If the creation fails, a [session not
created](#dfn-session-not-created) [error](#dfn-error) is returned.

If the [remote end](#dfn-remote-ends) is an [intermediary
node](#dfn-intermediary-nodes), it may use the result of the
[capabilities
processing](#dfn-capabilities-processing) algorithm to route the [new
session](#dfn-new-sessions) request to the appropriate [endpoint
node](#dfn-endpoint-node). An [intermediary
node](#dfn-intermediary-nodes) is free to define [extension
capabilities](#dfn-extension-capability) to assist in this process, however, these
specific capabilities must not be forwarded to the [endpoint
node](#dfn-endpoint-node).

If the [intermediary
node](#dfn-intermediary-nodes) requires additional information unrelated
to user agent features, it is recommended that this information be
passed as top-level parameters, and not as part of the requested
[capabilities](#dfn-capabilities). An [intermediary
node](#dfn-intermediary-nodes) must forward custom, top-level parameters
(i.e. non-[capabilities](#dfn-capabilities)) to subsequent [remote
end](#dfn-remote-ends) nodes.

[Example 7](#example-7)

An [intermediary
node](#dfn-intermediary-nodes) might require authentication on [creating
a new session](#dfn-new-sessions). This authentication is an argument to the
[New Session](#dfn-new-sessions) command itself and not the user agent\'s
[capabilities](#dfn-capabilities). Therefore, the authentication should be
passed as a top-level parameter and not embedded in `capabilities`:

``` {aria-busy="false"}
{
 "user": "alice",
 "password": "hunter2",
 "capabilities": {…}
}
```

However, because an [intermediary
node](#dfn-intermediary-nodes) cannot forward [extension
capabilities](#dfn-extension-capability) specific to that implementation to an
[endpoint node](#dfn-endpoint-node), the following is also permitted by this
specification:

``` {aria-busy="false"}
{
 "capabilities": {
 "alwaysMatch": {
 "cloud:user": "alice",
 "cloud:password": "hunter2",
 "platformName": "linux"
 },
 "firstMatch": [
 {"browserName": "chrome"},
 {"browserName": "edge"}
 ]
 }
}
```

Once all [capabilities are
merged](#dfn-merging-capabilities) from this
example, an [endpoint
node](#dfn-endpoint-node) would receive [New
Session](#dfn-new-sessions) capabilities identical to:

``` {aria-busy="false"}
[
 {"browserName": "chrome", "platformName": "linux"},
 {"browserName": "edge", "platformName": "linux"}
]
```

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If the implementation is an [endpoint
 node](#dfn-endpoint-node), and the list of [active HTTP
 sessions](#dfn-active-http-sessions) is not empty, or otherwise if the
 implementation is unable to start an additional session, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [session not
 created](#dfn-session-not-created).

2. If the [remote end](#dfn-remote-ends) is an [intermediary
 node](#dfn-intermediary-nodes), take implementation-defined steps
 that either result in returning an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [session not
 created](#dfn-session-not-created), or in returning a
 [success](#dfn-success) with data that is isomorphic to that returned by
 [remote ends](#dfn-remote-ends) according to the rest of this
 algorithm. If an [error](#dfn-error) is not returned, the [intermediary
 node](#dfn-intermediary-nodes) must retain a reference to the
 [session](#dfn-sessions) created on the
 [upstream](#dfn-upstream) node as the [associated
 session](#dfn-associated-session) such that commands may be forwarded to
 this [associated
 session](#dfn-associated-session) on subsequent commands.

 ::::
 :::
 Note
 :::

 How this is done is entirely up to the implementation, but typically
 the `sessionId`, and [URL](#dfn-url) and [URL
 prefix](#dfn-url-prefix) of the
 [upstream](#dfn-upstream) [remote
 end](#dfn-remote-ends) will need to be tracked.
 ::::

3. Let `flags` be a set containing \"`http`\".

4. Let `capabilities` be the result of
 [trying](#dfn-try)
 to [process
 capabilities](#dfn-capabilities-processing) with `parameters` and
 `flags`.

5. If `capabilities`\'s is
 [`null`](#dfn-null), return [error](#dfn-error) with [error
 code](#dfn-error-code) [session not
 created](#dfn-session-not-created).

6. Let `session` be the result of [create a
 session](#dfn-create-a-session), with `capabilities`, and
 `flags`.

7. Let `body` be a JSON
 [Object](#dfn-object) initialized with:

 \"`sessionId`\"
 : `session`\'s [session
 ID](#dfn-session-id).

 \"`capabilities`\"
 : `capabilities`

8. Set `session`\' [current top-level browsing
 context](#dfn-current-top-level-browsing-context) to one of the [endpoint
 node](#dfn-endpoint-node)\'s [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context)s, preferring the [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) that has [system
 focus](https://html.spec.whatwg.org/#tlbc-system-focus), or
 otherwise preferring any [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) whose [visibility
 state](https://w3c.github.io/page-visibility/#dfn-determine-the-visibility-state)
 is [visible](https://w3c.github.io/page-visibility/#dfn-visible).

 ::::
 :::
 Note
 :::

 WebDriver implementations typically start a completely new browser
 instance, but there is no requirement in this specification (or for
 WebDriver only to be used to automate only web browsers).
 Implementations might choose to use an existing browser instance,
 eg. by selecting the window that currently has focus.
 ::::

9. Set the [request
 queue](#dfn-request-queue) to a new
 [queue](https://infra.spec.whatwg.org/#queue).

10. Return [success](#dfn-success) with data `body`.

::: header-wrapper
### 8.3 [Delete Session]

------------- ------------------------------------
 HTTP Method URI Template
 DELETE /session/{`session id`}
 ------------- ------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session` is an [active HTTP
 session](#dfn-active-http-sessions), [try](#dfn-try) to [close the
 session](#dfn-close-the-session) with `session`.

2. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
### 8.4 [Status]

------------- --------------
 HTTP Method URI Template
 GET /status
 ------------- --------------

[Status](#dfn-status) returns information about whether a [remote
end](#dfn-remote-ends) is in a state in which it can create [new
sessions](#dfn-new-sessions), but may additionally include
arbitrary meta information that is specific to the implementation.

The [remote end](#dfn-remote-ends)\'s [readiness
state](#dfn-readiness-state) is represented by the `ready` property of the body,
which is false if an attempt to [create a
session](#dfn-new-sessions) at the current time would fail.
However, the value true does not guarantee that a [New
Session](#dfn-new-sessions) command will succeed.

Implementations may optionally include additional meta information as
part of the body, but the top-level properties `ready` and `message` are
reserved and must not be overwritten.

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `body` be a new JSON
 [Object](#dfn-object) with the following properties:

 \"`ready`\"

 : The [remote end](#dfn-remote-ends)\'s [readiness
 state](#dfn-readiness-state).

 \"`message`\"

 : An implementation-defined string explaining the [remote
 end](#dfn-remote-ends)\'s [readiness
 state](#dfn-readiness-state).

2. Return [success](#dfn-success) with data `body`.

::: header-wrapper
## 9. Timeouts

A [timer] is a
[struct](https://infra.spec.whatwg.org/#struct). It has a [timeout fired flag], which is a boolean, initially false.

To [start the timer] given `timer` and
`timeout`

1. Assert: `timeout` is not null.

2. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Wait for at least `timeout` milliseconds to pass.

 2. Set `timer`\'s [timeout fired
 flag](#dfn-timeout-fired-flag) to true.

A [timeouts configuration] is a
[struct](https://infra.spec.whatwg.org/#struct) representing the timeouts for [script
evaluation](#executing-script), [navigation](#navigation), and [element
retrieval](#elements). It has a [script timeout]
[item](https://infra.spec.whatwg.org/#struct-item) which is an integer or null and is initially set to
30,000, a [page load timeout]
[item](https://infra.spec.whatwg.org/#struct-item) which is an integer or null and is initially set to
300,000, and an [implicit wait timeout]
[item](https://infra.spec.whatwg.org/#struct-item) which is an integer or null and is initially set to 0.
To [deserialize as timeouts
configuration] given
`timeouts`:

1. Set `timeouts` to the result of [converting a
 JSON-derived JavaScript value to an Infra
 value](#dfn-converting-a-json-derived-javascript-value-to-an-infra-value) with `timeouts`.

2. Let `configuration` be a new [timeouts
 configuration](#dfn-timeouts-configuration).

3. For each `key` → `value` in
 `timeouts`:

 1. If «\"`script`\", \"`pageLoad`\", \"`implicit`\"» does not
 [contain](https://infra.spec.whatwg.org/#list-contain) `key`, then continue.

 2. If `value` is neither null nor a number greater than
 or equal to 0 and less than or equal to the [maximum safe
 integer](#dfn-maximum-safe-integer) return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 3. Run the substeps matching `key`:

 \"`script`\"

 : Set `configuration`\'s [script
 timeout](#dfn-script-timeout) to
 `value`.

 \"`pageLoad`\"

 : Set `configuration`\'s [page load
 timeout](#dfn-page-load-timeout) to
 `value`.

 \"`implicit`\"

 : Set `configuration`\'s [implicit wait
 timeout](#dfn-implicit-wait-timeout) to
 `value`.

4. Return [success](#dfn-success) with data `configuration`.

To [serialize the timeouts
configuration] given
`timeouts`:

1. Let `serialized` be an empty
 [map](https://infra.spec.whatwg.org/#ordered-map).

2. Set `serialized`\[\"`script`\"\] to
 `timeouts`\' [script
 timeout](#dfn-script-timeout).

3. Set `serialized`\[\"`pageLoad`\"\] to
 `timeouts`\' [page load
 timeout](#dfn-page-load-timeout).

4. Set `serialized`\[\"`implicit`\"\] to
 `timeouts`\' [implicit wait
 timeout](#dfn-implicit-wait-timeout).

5. Return [convert an Infra value to a JSON-compatible JavaScript
 value](#dfn-convert-an-infra-value-to-a-json-compatible-javascript-value) with `serialized`.

MDN 

[Commands/GetTimeouts](https://developer.mozilla.org/en-US/docs/Web/WebDriver/Commands/GetTimeouts "The Get Timeouts command of the WebDriver API returns the timeouts associated with the current session. The session timeout durations control such behavior as timeouts on script injection, document navigation, and element retrieval.")

 ------------------ -----
 Chrome 65+
 Chrome Android No
 Edge ?
 Edge Mobile ?
 Firefox 55+
 Firefox Android No
 Opera No
 Opera Android ?
 Safari No
 Safari iOS ?
 Samsung Internet No
 WebView Android ?
 ------------------ -----

::: header-wrapper
### 9.1 [Get Timeouts]

------------- ---------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/timeouts
 ------------- ---------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `timeouts` be [serialize the timeouts
 configuration](#dfn-serialize-the-timeouts-configuration) with
 [session](#dfn-sessions)\'s [timeouts
 configuration](#dfn-timeouts-configuration)

2. Return [success](#dfn-success) with data `timeouts`.

MDN 

[Commands/SetTimeouts](https://developer.mozilla.org/en-US/docs/Web/WebDriver/Commands/SetTimeouts "The Set Timeouts command of the WebDriver API sets the timeouts associated with the current session. The session timeout durations control such behavior as timeouts on script injection, document navigation, and element retrieval.")

 ------------------ -----
 Chrome 65+
 Chrome Android No
 Edge ?
 Edge Mobile ?
 Firefox 55+
 Firefox Android No
 Opera No
 Opera Android ?
 Safari No
 Safari iOS ?
 Samsung Internet No
 WebView Android ?
 ------------------ -----

::: header-wrapper
### 9.2 [Set Timeouts]

------------- ---------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/timeouts
 ------------- ---------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `timeouts` be the result of
 [trying](#dfn-try)
 to [deserialize as timeouts
 configuration](#dfn-deserialize-as-timeouts-configuration) with `parameters`.

2. Set `session`\'s [timeouts
 configuration](#dfn-timeouts-configuration) to `timeouts`.

3. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
## 10. Navigation

The [commands](#dfn-commands) in this section allow navigation of the
[session](#dfn-sessions)\'s [current top-level browsing
context](#dfn-current-top-level-browsing-context) to new URLs and introspection of the
document currently loaded in this [browsing
context](#dfn-browsing-contexts).

For [commands](#dfn-commands) that cause a new document to load, the point at which
the command returns is determined by the session\'s [page loading
strategy](#dfn-page-loading-strategy). The
[normal](#dfn-normal-page-loading-strategy) state causes it to return after the
[`load`](#dfn-load)
[event
fires](https://dom.spec.whatwg.org/#concept-event-fire) on the new page,
[eager](#dfn-eager-page-loading-strategy) causes it to return after the
[`DOMContentLoaded`](#dfn-domcontentloaded) [event
fires](https://dom.spec.whatwg.org/#concept-event-fire), and
[none](#dfn-none-page-loading-strategy) causes it to return immediately.

Navigation actions are also affected by the value of the [page load
timeout](#dfn-page-load-timeout), which determines the maximum
time that commands will block before returning with a
[timeout](#dfn-timeout) [error](#dfn-error).

The following is the [table of page load
strategies] that links the `pageLoadStrategy`
[capability](#dfn-capabilities) keyword to a [page loading
strategy](#dfn-page-loading-strategy) state, and shows which [document
readiness](#dfn-document-readiness) state that corresponds to it:

 -------------- ---------------------------------------------------------------------------------------------------------------------------------------------- --------------------------
 Keyword Page load strategy state Document readiness state
 \"`none`\" [none]
 \"`eager`\" [eager] \"`interactive`\"
 \"`normal`\" [normal] \"`complete`\"
 -------------- ---------------------------------------------------------------------------------------------------------------------------------------------- --------------------------

When asked to [deserialize as a page load
strategy] with argument `value`:

1. If `value` is not a
 [string](#dfn-string) return an [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

2. If there is no entry in the [table of page load
 strategies](#dfn-table-of-page-load-strategies) with `keyword` `value`
 return an [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Return [success](#dfn-success) with data `value`.

To [wait for navigation to
complete], given `session` and
optional `timer` (default null):

1. If `session`\'s [page loading
 strategy](#dfn-page-loading-strategy) is
 [none](#dfn-none-page-loading-strategy), return
 [success](#dfn-success) with data [`null`](#dfn-null).

2. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [success](#dfn-success) with data [`null`](#dfn-null).

3. Let `timeout` be [session
 timeouts](#dfn-session-timeouts)\' [page load
 timeout](#dfn-page-load-timeout).

4. If `timer` is null:

 1. Set `timer` to a new
 [timer](#dfn-timer).

 2. If `timeout` is not null:

 1. [Start the
 timer](#dfn-start-the-timer) with `timer` and
 `timeout`.

5. Run these steps, but [abort
 when](https://infra.spec.whatwg.org/#abort-when) `timer`\'s [timeout fired
 flag](#dfn-timeout-fired-flag) is set:

 1. If there is an ongoing attempt to
 [navigate](#dfn-navigating) `session`\'s [current
 browsing
 context](#dfn-current-browsing-context) that has not yet
 [matured](#dfn-matured), wait for navigation to
 [mature](#dfn-matured).

 2. Let `readiness target` be the [document
 readiness](#dfn-document-readiness) state associated with the
 `session`\'s [page loading
 strategy](#dfn-page-loading-strategy), which can be found in the [table
 of page load
 strategies](#dfn-table-of-page-load-strategies).

 3. Wait for `session`\'s [current browsing
 context](#dfn-current-browsing-context)\'s [document
 readiness](#dfn-document-readiness) state to reach
 `readiness target`.

6. [If
 aborted](https://infra.spec.whatwg.org/#if-aborted) return an [error](#dfn-error) with [error
 code](#dfn-error-code) [timeout](#dfn-timeout).

7. Return [success](#dfn-success) with data [`null`](#dfn-null).

When asked to run the [post-navigation
checks], run the substeps of the first
matching statement:

[response](#dfn-http-response) is a network error

: Return [error](#dfn-error) with [error
 code](#dfn-error-code) [unknown
 error](#dfn-unknown-error).

 ::::
 :::
 Note
 :::

 A \"network error\" in this case is not an HTTP response with a
 status code indicating an unsuccessful result, but could be a
 problem occurring lower in the OSI model, or a failed DNS lookup.
 ::::

[response](#dfn-http-response) is [blocked by content security policy](#dfn-blocked-by-content-security-policy)

: If the [remote end](#dfn-remote-ends)\'s [accept insecure
 TLS](#dfn-accept-insecure-tls) state is true, take implementation
 specific steps to ensure the navigation is not aborted and that the
 untrusted or invalid TLS certificate error that would normally occur
 under these circumstances, are suppressed.

 Otherwise return [error](#dfn-error) with [error
 code](#dfn-error-code) [insecure
 certificate](#dfn-insecure-certificate).

[response](#dfn-http-response)\'s [HTTP status](#dfn-http-status) is 401\
Otherwise

: Irrespective of how a possible authentication challenge is handled,
 return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
### 10.1 [Navigate To]

------------- ----------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/url
 ------------- ----------------------------------------

The command causes the user agent to
[navigate](#dfn-navigating) the [session](#dfn-sessions)\'s [current top-level browsing
context](#dfn-current-top-level-browsing-context) to a new location.

If the [remote end](#dfn-remote-ends)\'s [accept insecure
TLS](#dfn-accept-insecure-tls) flag is true, no certificate errors that
would normally cause the user agent to abort and show a security warning
are to hinder navigation to the requested address.

[Example 8](#example-8)

To navigate the [current top-level browsing
context](#dfn-current-top-level-browsing-context) of the
[session](#dfn-sessions) with ID *1* to `https://example.com`, the [local
end](#dfn-local-ends) would POST to */session/1/url* with the body:

``` {aria-busy="false"}
{"url": "https://example.com"}
```

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `URL` be the result of [getting a
 property](#dfn-getting-properties) named \"`url`\" from
 `parameters`.

2. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

3. If `URL` is not an [absolute
 URL](#dfn-absolute-url) or is not an [absolute URL with
 fragment](#dfn-absolute-url-with-fragment) or not a [local
 scheme](#dfn-local-scheme), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

4. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

5. Let `timeout` be
 [session](#dfn-sessions)\'s [session
 timeouts](#dfn-session-timeouts) [page load
 timeout](#dfn-page-load-timeout).

6. Let `current URL` be `session`\'s [current
 top-level browsing
 context](#dfn-current-top-level-browsing-context)\'s [active
 document](#dfn-active-document)\'s [URL](#dfn-url).

7. If `current URL` and `URL` do not have the
 same [absolute URL](#dfn-absolute-url) and `timeout` is not null:

 1. Set `timer` to a new
 [timer](#dfn-timer).

 2. [Start the
 timer](#dfn-start-the-timer) with `timer` and
 `timeout`.

8. Run these steps, but [abort
 when](https://infra.spec.whatwg.org/#abort-when) `timer`\'s [timeout fired
 flag](#dfn-timeout-fired-flag) is set:

 1. [Navigate](#dfn-navigating) `session`\'s [current
 top-level browsing
 context](#dfn-current-top-level-browsing-context) to `URL`.

 2. If `URL` [is
 special](#dfn-is-special) except for `file` and `current URL`
 and `URL` do not have the same [absolute
 URL](#dfn-absolute-url) :

 1. [Try](#dfn-try) to [wait for navigation to
 complete](#dfn-wait-for-navigation-to-complete) with `session` and
 `timer`.

 2. [Try](#dfn-try) to run the [post-navigation
 checks](#dfn-post-navigation-checks).

 3. [Set the current browsing
 context](#dfn-set-the-current-browsing-context) with `session` and
 [current top-level browsing
 context](#dfn-current-top-level-browsing-context).

 4. While `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) contains a [refresh state pragma
 directive](#dfn-refresh-state-pragma-directive) of `time` 1 second or
 less, run the following steps:

 1. Set `current URL` to `session`\'s
 [current top-level browsing
 context](#dfn-current-top-level-browsing-context)\'s [active
 document](#dfn-active-document)\'s
 [URL](#dfn-url).

 2. Wait until the refresh timeout has elapsed and new
 [navigate](#dfn-navigating) of `session`\'s
 [current top-level browsing
 context](#dfn-current-top-level-browsing-context) has begun.

 3. Set `URL` to the destination URL of
 `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context)\'s [active
 document](#dfn-active-document)\'s ongoing navigation.

 4. If `URL` [is
 special](#dfn-is-special) except for `file` and
 `current URL` and `URL` do not have
 the same [absolute
 URL](#dfn-absolute-url) :

 1. [Try](#dfn-try) to [wait for navigation to
 complete](#dfn-wait-for-navigation-to-complete) with `session`
 and `timer`.

 2. [Try](#dfn-try) to run the [post-navigation
 checks](#dfn-post-navigation-checks).

9. [If
 aborted](https://infra.spec.whatwg.org/#if-aborted) return an [error](#dfn-error) with [error
 code](#dfn-error-code) [timeout](#dfn-timeout).

10. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
### 10.2 [Get Current URL]

------------- ----------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/url
 ------------- ----------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `URL` be the
 [serialization](#dfn-url-serializer) of
 `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context)\'s [active
 document](#dfn-active-document)\'s [URL](#dfn-url).

4. Return [success](#dfn-success) with data `URL`.

::: header-wrapper
### 10.3 [Back]

------------- -----------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/back
 ------------- -----------------------------------------

This command causes the browser to traverse one step backward in the
[joint session
history](#dfn-joint-session-history) of `session`\'s [current
top-level browsing
context](#dfn-current-top-level-browsing-context). This is equivalent to pressing the back
button in the [browser
chrome](#dfn-browser-chrome) or invoking `window.history.back`.

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `timeout` be `session`\' [session
 timeouts](#dfn-session-timeouts) [page load
 timeout](#dfn-page-load-timeout).

4. Let `timer` be a new
 [timer](#dfn-timer).

5. If `timeout` is not null:

 1. [Start the
 timer](#dfn-start-the-timer) with `timer` and
 `timeout`.

6. [Traverse the history by a
 delta](#dfn-traverse-the-history-by-a-delta) --1 for `session`\'s
 [current browsing
 context](#dfn-current-browsing-context).

7. If the previous step completed results in a
 [`pageHide`](#dfn-pagehide) [event
 firing](https://dom.spec.whatwg.org/#concept-event-fire), wait until
 [`pageShow`](#dfn-pageshow) [event
 fires](https://dom.spec.whatwg.org/#concept-event-fire) or `timer`\' [timeout
 fired
 flag](#dfn-timeout-fired-flag) to be set, whichever
 occurs first.

8. If `timer`\' [timeout fired
 flag](#dfn-timeout-fired-flag) is set:

 1. [Handle any user
 prompts](#dfn-handle-any-user-prompts).

 2. Return [error](#dfn-error) with [error
 code](#dfn-error-code) [timeout](#dfn-timeout).

9. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
### 10.4 [Forward]

------------- --------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/forward
 ------------- --------------------------------------------

This command causes the browser to traverse one step forwards in the
[joint session
history](#dfn-joint-session-history) of `session`\'s [current
top-level browsing
context](#dfn-current-top-level-browsing-context). This is equivalent to pressing the
forward button in the [browser
chrome](#dfn-browser-chrome) or invoking `window.history.forward`.

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `timeout` be `session`\' [session
 timeouts](#dfn-session-timeouts) [page load
 timeout](#dfn-page-load-timeout).

4. Let `timer` be a new
 [timer](#dfn-timer).

5. If `timeout` is not null:

 1. [Start the
 timer](#dfn-start-the-timer) with `timer` and
 `timeout`.

6. [Traverse the history by a
 delta](#dfn-traverse-the-history-by-a-delta) 1 for `session`\'s [current
 browsing
 context](#dfn-current-browsing-context).

7. If the previous step completed results in a
 [`pageHide`](#dfn-pagehide)
 [event](https://dom.spec.whatwg.org/#concept-event) firing, wait until
 [`pageShow`](#dfn-pageshow) [event
 fires](https://dom.spec.whatwg.org/#concept-event-fire) or `timer`\' [timeout
 fired
 flag](#dfn-timeout-fired-flag) to be set, whichever
 occurs first.

8. If `timer`\' [timeout fired
 flag](#dfn-timeout-fired-flag) is set:

 1. [Handle any user
 prompts](#dfn-handle-any-user-prompts).

 2. Return [error](#dfn-error) with [error
 code](#dfn-error-code) [timeout](#dfn-timeout).

9. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
### 10.5 [Refresh]

------------- --------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/refresh
 ------------- --------------------------------------------

This command causes the browser to reload the page in
`session`\'s [current top-level browsing
context](#dfn-current-top-level-browsing-context).

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Initiate [an overridden
 reload](#dfn-an-overridden-reload) of `session`\'s [current
 top-level browsing
 context](#dfn-current-top-level-browsing-context)\'s [active
 document](#dfn-active-document).

4. If `URL` [is
 special](#dfn-is-special) except for `file`:

 1. [Try](#dfn-try) to [wait for navigation to
 complete](#dfn-wait-for-navigation-to-complete) with `session`.

 2. [Try](#dfn-try) to run the [post-navigation
 checks](#dfn-post-navigation-checks).

5. [Set the current browsing
 context](#dfn-set-the-current-browsing-context) with `session` and
 `session`\'s[current top-level browsing
 context](#dfn-current-top-level-browsing-context).

6. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
### 10.6 [Get Title]

------------- ------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/title
 ------------- ------------------------------------------

This command returns the document title of `session`\'s
[current top-level browsing
context](#dfn-current-top-level-browsing-context), equivalent to calling `document.title`.

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `title` be the `session`\'s [current
 top-level browsing
 context](#dfn-current-top-level-browsing-context)\'s [active
 document](#dfn-active-document)\'s
 [`title`](https://html.spec.whatwg.org/multipage/dom.html#document.title).

4. Return [success](#dfn-success) with data `title`.

::: header-wrapper
## 11. Contexts

Many WebDriver [commands](#dfn-commands) happen in the context of either
`session`\'s [current browsing
context](#dfn-current-browsing-context) or [current top-level browsing
context](#dfn-current-top-level-browsing-context). `session`\'s [current
top-level browsing
context](#dfn-current-top-level-browsing-context) is represented in the protocol by its
associated [window
handle](#dfn-window-handles). When a [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) is selected using the [Switch To
Window](#dfn-switch-to-window) command, a specific [browsing
context](#dfn-browsing-contexts) can be selected using the [Switch to
Frame](#dfn-switch-to-frame) command.

The use of the term "window" to refer to a [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) is legacy and doesn\'t correspond with either the
operating system notion of a "window" or the DOM
[`Window`](#dfn-window) object.

A [browsing
context](#dfn-browsing-contexts) is said to be [no longer
open] if its
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable) has been destroyed.

Each [browsing
context](#dfn-browsing-contexts) has an associated [window
handle] which uniquely
identifies it. This must be a
[String](#dfn-string) and must not be \"`current`\".

A [web frame] is an abstraction
used to identify a
[frame](https://html.spec.whatwg.org/multipage/obsolete.html#frame) or
[iframe](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) when it is transported via the
[protocol](#protocol), between
[remote](#dfn-remote-ends) and [local](#dfn-local-ends) ends.

The [web frame identifier] is the string constant
\"`frame-075b-4da1-b6ba-e579c2d3230a`\".

An ECMAScript [Object](#dfn-object) [represents a web frame] if it has a
[web frame
identifier](#dfn-web-frame-identifier) [own
property](#dfn-own-properties).

A [web window] is an abstraction
used to identify a [window](#dfn-window) when it is transported via the
[protocol](#protocol), between
[remote](#dfn-remote-ends) and [local](#dfn-local-ends) ends.

The [web window identifier] is the string constant
\"`window-fcc6-11e5-b4f8-330a88ab9d7f`\".

An ECMAScript [Object](#dfn-object) [represents a web window] if it has a
[web window
identifier](#dfn-web-window-identifier) [own
property](#dfn-own-properties).

The [`WindowProxy` reference object] with
[`WindowProxy`](#dfn-windowproxy) object `window` is given by:

1. Let `identifier` be the [web window
 identifier](#dfn-web-window-identifier) if the associated [browsing
 context](#dfn-browsing-contexts) of `window` is a [top-level
 browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context).

 Otherwise let it be the [web frame
 identifier](#dfn-web-frame-identifier).

2. Return a JSON [Object](#dfn-object) initialized with the following
 properties:

 `identifier`

 : Associated [window
 handle](#dfn-window-handles) of the `window`\'s
 [browsing
 context](#dfn-browsing-contexts).

To [deserialize a web frame] by a JSON
[Object](#dfn-object) `object` that [represents a web
frame](#dfn-represents-a-web-frame):

1. If `object` has no [own
 property](#dfn-own-properties) [web frame
 identifier](#dfn-web-frame-identifier), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

2. Let `reference` be the result of
 [getting](#dfn-getting-properties) the [web frame
 identifier](#dfn-web-frame-identifier) property from `object`.

3. If `reference` is not a
 [String](#dfn-string), return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

4. Let `browsing context` be the [browsing
 context](#dfn-browsing-contexts) whose [window
 handle](#dfn-window-handles) is `reference`, or null if
 no such [browsing
 context](#dfn-browsing-contexts) exists.

5. If `browsing context` is null or a [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context), return [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 frame](#dfn-no-such-frame).

6. Return [success](#dfn-success) with data `browsing context`\'s
 associated window.

To [deserialize a web window] by a JSON
[Object](#dfn-object) `object` that [represents a web
window](#dfn-represents-a-web-window):

1. If `object` has no [own
 property](#dfn-own-properties) [web window
 identifier](#dfn-web-window-identifier), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

2. Let `reference` be the result of
 [getting](#dfn-getting-properties) the [web
 window
 identifier](#dfn-web-window-identifier) property from `object`.

3. If `reference` is not a
 [String](#dfn-string), return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

4. Let `browsing context` be the [browsing
 context](#dfn-browsing-contexts) whose [window
 handle](#dfn-window-handles) is `reference`, or null if
 no such [browsing
 context](#dfn-browsing-contexts) exists.

5. If `browsing context` is null or not a [top-level
 browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context), return [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

6. Return [success](#dfn-success) with data `browsing context`\'s
 associated window.

When required to [set the current browsing
context] given `session` and
`context`, an implementation must follow the following steps:

1. Set `session`\'s [current browsing
 context](#dfn-current-browsing-context) to `context`.

2. Set the `session`\'s [current parent browsing
 context](#dfn-current-parent-browsing-context) to the [parent browsing
 context](#dfn-parent-browsing-context) of `context`, if that
 context exists, or [null](#dfn-null) otherwise.

When required to [set the current top-level browsing
context] given
`session` and `context`, an implementation must:

1. Assert: `context` is a [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context).

2. Set `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) to `context`.

3. [Set the current browsing
 context](#dfn-set-the-current-browsing-context) with `session` and
 `context`.

In accordance with the
[focus](https://html.spec.whatwg.org/multipage/interaction.html#focus)
section of the \[[HTML](#bib-html "HTML Standard")\] specification, commands are unaffected by whether
the operating system window has focus or not.

::: header-wrapper
### 11.1 [Get Window Handle]

------------- -------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/window
 ------------- -------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. Return [success](#dfn-success) with data being the [window
 handle](#dfn-window-handles) associated with
 `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context).

MDN 

[Commands/CloseWindow](https://developer.mozilla.org/en-US/docs/Web/WebDriver/Commands/CloseWindow "The Close Window command of the WebDriver API closes the current top-level browsing context (window or tab) and returns with the list of currently open WebWindows. If it is the last window that is being closed, the WebDriver session will implicitly be deleted. Subsequent commands after the session is ended will therefore cause invalid session ID errors.")

 ------------------ -----
 Chrome 65+
 Chrome Android No
 Edge ?
 Edge Mobile ?
 Firefox 55+
 Firefox Android No
 Opera No
 Opera Android ?
 Safari No
 Safari iOS ?
 Samsung Internet No
 WebView Android ?
 ------------------ -----

::: header-wrapper
### 11.2 [Close Window]

------------- -------------------------------------------
 HTTP Method URI Template
 DELETE /session/{`session id`}/window
 ------------- -------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. [Close](#dfn-close) `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context).

4. If there are no more open [top-level browsing
 contexts](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context), then [try](#dfn-try) to [close the
 session](#dfn-close-the-session).

5. Return the result of running the [remote end
 steps](#dfn-remote-end-steps) for the [Get Window
 Handles](#dfn-get-window-handles)
 [command](#dfn-commands), with `session`,
 `URL variables` and `parameters`.

::: header-wrapper
### 11.3 [Switch To Window]

------------- -------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/window
 ------------- -------------------------------------------

Switching window will select `session`\'s [current top-level
browsing
context](#dfn-current-top-level-browsing-context) used as the target for all subsequent
[commands](#dfn-commands). In a tabbed browser, this will typically make the tab
containing the [browsing
context](#dfn-browsing-contexts) the selected tab.

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `handle` be the result of [getting the
 property](#dfn-getting-properties) \"`handle`\" from
 `parameters`.

2. If `handle` is
 [undefined](#dfn-undefined), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. If there is an active [user
 prompt](#dfn-user-prompts), that prevents the focusing of another [top-level
 browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context), return [error](#dfn-error) with [error
 code](#dfn-error-code) [unexpected alert
 open](#dfn-unexpected-alert-open).

4. If `handle` is equal to the associated [window
 handle](#dfn-window-handles) for some [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context), let `context` be the that browsing
 context, and [set the current top-level browsing
 context](#dfn-set-the-current-top-level-browsing-context) with `session` and
 `context`.

 Otherwise, return [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

5. Update any implementation-specific state that would result from the
 user selecting `session`\'s [current browsing
 context](#dfn-current-browsing-context) for interaction, without altering
 OS-level focus.

6. Return [success](#dfn-success) with data [`null`](#dfn-null).

MDN 

[Commands/GetWindowHandles](https://developer.mozilla.org/en-US/docs/Web/WebDriver/Commands/GetWindowHandles "The Get Window Handles command of the WebDriver API returns a list of all WebWindows. Each tab or window, depending on whether you are using a tabbed browser, is associated by a window handle that is used as a reference when switching to the window.")

 ------------------ -----
 Chrome 65+
 Chrome Android No
 Edge ?
 Edge Mobile ?
 Firefox 55+
 Firefox Android No
 Opera No
 Opera Android ?
 Safari No
 Safari iOS ?
 Samsung Internet No
 WebView Android ?
 ------------------ -----

::: header-wrapper
### 11.4 [Get Window Handles]

------------- ---------------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/window/handles
 ------------- ---------------------------------------------------

The order in which the window handles are returned is arbitrary.

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `handles` be a [List](#dfn-list).

2. For each [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) in the [remote
 end](#dfn-remote-ends), push the associated [window
 handle](#dfn-window-handles) onto `handles`.

3. Return [success](#dfn-success) with data `handles`.

[Example 9](#example-9)

In order to determine whether or not a particular interaction with the
browser opens a new window, one can obtain the set of window handles
before the interaction is performed and compare it with the set after
the action is performed.

MDN[🚫]{title="This feature has limited support."}

[Commands/New_Window](https://developer.mozilla.org/en-US/docs/Web/WebDriver/Commands/New_Window "The New Window command of the WebDriver API opens a new top-level browsing context of type window or tab, and returns with a dictionary containing the handle of the new WebWindow and its created type. If the requested type cannot be created by the browser, the alternative type will be tried to create.")

This feature has limited support.

 ------------------ -----
 Chrome No
 Chrome Android ?
 Edge ?
 Edge Mobile ?
 Firefox 66+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari No
 Safari iOS ?
 Samsung Internet No
 WebView Android ?
 ------------------ -----

::: header-wrapper
### 11.5 [New Window]

------------- -----------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/window/new
 ------------- -----------------------------------------------

Create a new [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context).

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If the implementation does not support creating new top-level
 browsing contexts, return [error](#dfn-error) with [error
 code](#dfn-error-code) [unsupported
 operation](#dfn-unsupported-operation).

2. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

3. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

4. Let `type hint` be the result of [getting the
 property](#dfn-getting-properties) \"`type`\" from
 `parameters`.

5. Create a new [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) by running the [window open
 steps](#dfn-window-open-steps) with `URL` set to
 \"`about:blank`\", `target` set to the empty string, and
 `features` set to \"`noopener`\" and the user agent
 configured to create a new browsing context. This must be done
 without invoking the [focusing
 steps](#dfn-focusing-steps) for the created browsing context. If
 `type hint` has the value \"`tab`\", and the
 implementation supports multiple browsing context in the same OS
 window, the new browsing context should share an OS window with
 `session`\'s [current browsing
 context](#dfn-current-browsing-context). If `type hint` is
 \"`window`\", and the implementation supports multiple browsing
 contexts in separate OS windows, the created browsing context should
 be in a new OS window. In all other cases the details of how the
 browsing context is presented to the user are implementation
 defined.

6. Let `handle` be the associated [window
 handle](#dfn-window-handles) of the newly created window.

7. Let `type` be \"`tab`\" if the newly created window
 shares an OS-level window with `session`\'s [current
 browsing
 context](#dfn-current-browsing-context), or \"`window`\" otherwise.

8. Let `result` be a new JSON
 [Object](#dfn-object) initialized with:

 \"`handle`\"
 : The value of `handle`.

 \"`type`\"
 : The value of `type`.

9. Return [success](#dfn-success) with data `result`.

::: header-wrapper
### 11.6 [Switch To Frame]

------------- ------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/frame
 ------------- ------------------------------------------

The [Switch To
Frame](#dfn-switch-to-frame) command is used to select `session`\'s
[current top-level browsing
context](#dfn-current-top-level-browsing-context) or a [child browsing
context](#dfn-child-browsing-context) of `session`\'s [current
browsing
context](#dfn-current-browsing-context) to use as `session`\'s [current
browsing
context](#dfn-current-browsing-context) for subsequent
[commands](#dfn-commands). The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `id` be the result of [getting the
 property](#dfn-getting-properties) \"`id`\" from `parameters`.

2. If `id` is not [`null`](#dfn-null), a `Number` object, or an
 [Object](#dfn-object) that [represents a web
 element](#dfn-represents-a-web-element), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Run the substeps of the first matching condition:

 `id` is [`null`](#dfn-null)

 : 1. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

 2. [Try](#dfn-try) to [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

 3. [Set the current browsing
 context](#dfn-set-the-current-browsing-context) with `session` and
 `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context).

 `id` is a `Number` object

 : 1. If `id` is less than 0 or greater than 2^16^ --
 1, return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 2. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

 3. [Try](#dfn-try) to [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

 4. Let `window` be the [associated
 window](#dfn-associated-window) of `session`\'s
 [current browsing
 context](#dfn-current-browsing-context)\'s [active
 document](#dfn-active-document).

 5. If `id` is not a [supported property
 index](#dfn-supported-property-index) of `window`, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 frame](#dfn-no-such-frame).

 6. Let `child window` be the
 [`WindowProxy`](#dfn-windowproxy) object obtained by calling
 `window`.[`[[GetOwnProperty]]`](#dfn-window-getownproperty) (`id`).

 7. [Set the current browsing
 context](#dfn-set-the-current-browsing-context) with `session` and
 `child window`\'s [browsing
 context](#dfn-browsing-contexts).

 `id` [represents a web element](#dfn-represents-a-web-element)

 : 1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

 2. [Try](#dfn-try) to [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

 3. Let `element` be the result of
 [trying](#dfn-try) to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `id`.

 4. If `element` is not a
 [`frame`](https://html.spec.whatwg.org/multipage/obsolete.html#frame) or
 [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 frame](#dfn-no-such-frame).

 5. [Set the current browsing
 context](#dfn-set-the-current-browsing-context) with `session` and
 `element`\'s [content
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#content-navigable)\'s [active browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-bc).

4. Update any implementation-specific state that would result from the
 user selecting `session`\'s [current browsing
 context](#dfn-current-browsing-context) for interaction, without altering
 OS-level focus.

5. Return [success](#dfn-success) with data [`null`](#dfn-null).

WebDriver is not bound by the same origin policy, so it is always
possible to switch into child browsing contexts, even if they are
different origin to the current browsing context.

::: header-wrapper
### 11.7 [Switch To Parent Frame]

------------- -------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/frame/parent
 ------------- -------------------------------------------------

The [Switch to Parent
Frame](#dfn-switch-to-parent-frame)
[command](#dfn-commands) sets `session`\'s [current browsing
context](#dfn-current-browsing-context) for future
[commands](#dfn-commands) to the parent of `session`\'s [current
browsing
context](#dfn-current-browsing-context).

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is already the [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context):

 1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

 2. Return [success](#dfn-success) with data
 [`null`](#dfn-null).

2. If `session`\'s [current parent browsing
 context](#dfn-current-parent-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

3. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

4. If [session](#dfn-sessions)\'s [current parent browsing
 context](#dfn-current-parent-browsing-context) is not
 [null](#dfn-null), [set the current browsing
 context](#dfn-set-the-current-browsing-context) with `session` and [current
 parent browsing
 context](#dfn-current-parent-browsing-context).

5. Update any implementation-specific state that would result from the
 user selecting `session`\'s [current browsing
 context](#dfn-current-browsing-context) for interaction, without altering
 OS-level focus.

6. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
### 11.8 Resizing and positioning windows

WebDriver provides [commands](#dfn-commands) for interacting with the operating system
window containing `session`\'s [current top-level browsing
context](#dfn-current-top-level-browsing-context). Because different operating systems\'
window managers provide different abilities, not all of the commands in
this section can be supported by all [remote
ends](#dfn-remote-ends). Support for these
[commands](#dfn-commands) is determined by the [window
dimensioning/positioning](#dfn-window-dimensioning-positioning)
[capability](#dfn-capabilities). Where a
[command](#dfn-commands) is not supported, an [unsupported
operation](#dfn-unsupported-operation) [error](#dfn-error) is returned.

The [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) has an associated [window state] which describes what visibility state its OS widget
window is in. It can be in one of the following states:

 ----------------------------------------------------------------------------------------------------------------- ------------------ --------- ------------------------------------
 State Keyword Default Description
 [Maximized window state] \"`maximized`\" The window is maximized.
 [Minimized window state] \"`minimized`\" The window is iconified.
 [Normal window state] \"`normal`\" ✓ The window is shown normally.
 [Fullscreen window state] \"`fullscreen`\" The window is in full screen mode.
 ----------------------------------------------------------------------------------------------------------------- ------------------ --------- ------------------------------------

If for whatever reason the [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context)\'s OS window cannot enter either of the [window
states](#dfn-window-states), or if this concept is not applicable on the current
system, the default state must be
[normal](#dfn-normal-window-state).

The [WindowRect object] for a
[WindowProxy](#dfn-windowproxy), `window` is an
[Object](#dfn-object) initialized with the following properties:

\"`x`\"

: `window`\'s
 [screenX](#dfn-screenx) attribute.

\"`y`\"

: `window`\'s
 [screenY](#dfn-screeny) attribute.

\"`width`\"

: `windows`\'s
 [outerWidth](#dfn-outerwidth) attribute.

\"`height`\"

: `window`\'s
 [outerHeight](#dfn-outerheight) attribute.

To [maximize the window], given an operating system level
window with an associated [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context), run the implementation-specific steps to transition
the operating system level window into the [maximized window
state](#dfn-maximized-window-state). If the window manager supports window
resizing but does not have a concept of window maximization, the window
dimensions must be increased to the maximum available size permitted by
the window manager for the current screen. Return when the window has
completed the transition, or within an implementation-defined timeout.

To [iconify the window], given an operating system level
window with an associated [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context), run implementation-specific steps to transition the
operating system level window into the [minimized window
state](#dfn-minimized-window-state). Do not return from this operation until
the [visibility
state](#dfn-visibility-state) of the [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context)\'s [active
document](#dfn-active-document) has reached the
[hidden](#dfn-visibility-hidden) state, or until the
operation times out.

To [restore the window], given an operating system level
window with an associated [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context), run implementation-specific steps to restore or unhide
the window to the visible screen. Do not return from this operation
until the [visibility
state](#dfn-visibility-state) of the [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context)\'s [active
document](#dfn-active-document) has reached the
[visible](#dfn-visibility-visible) state, or until
the operation times out.

MDN 

[Commands/GetWindowRect](https://developer.mozilla.org/en-US/docs/Web/WebDriver/Commands/GetWindowRect "The Get Window Rect command of the WebDriver API returns the size and position of the given WebElement. Many WebDriver clients present separate API methods for getting an element's location and dimensions, but as an optimization they both use this primitive.")

 ------------------ -----
 Chrome 65+
 Chrome Android No
 Edge ?
 Edge Mobile ?
 Firefox 55+
 Firefox Android No
 Opera No
 Opera Android ?
 Safari No
 Safari iOS ?
 Samsung Internet No
 WebView Android ?
 ------------------ -----

::: header-wrapper
#### 11.8.1 [Get Window Rect]

------------- -----------------------------------
 HTTP Method URI Template
 GET /session/{session id}/window/rect
 ------------- -----------------------------------

The [Get Window
Rect](#dfn-get-window-rect) [command](#dfn-commands) returns the size and position on the
screen of the operating system window corresponding to
`session`\'s [current top-level browsing
context](#dfn-current-top-level-browsing-context).

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Return [success](#dfn-success) with data set to the [WindowRect
 object](#dfn-windowrect-object) for the `session`\'s
 [current top-level browsing
 context](#dfn-current-top-level-browsing-context).

MDN 

[Commands/SetWindowRect](https://developer.mozilla.org/en-US/docs/Web/WebDriver/Commands/SetWindowRect "The Set Window Rect command of the WebDriver API alters the size and position of the operating system window associated with the current window. The command acts as the setter of Get Window Rect, which return object you can pass directly as this command's payload.")

 ------------------ -----
 Chrome 65+
 Chrome Android No
 Edge ?
 Edge Mobile ?
 Firefox 55+
 Firefox Android No
 Opera No
 Opera Android ?
 Safari No
 Safari iOS ?
 Samsung Internet No
 WebView Android ?
 ------------------ -----

::: header-wrapper
#### 11.8.2 [Set Window Rect]

------------- ------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/window/rect
 ------------- ------------------------------------------------

The [Set Window
Rect](#dfn-set-window-rect) [command](#dfn-commands) alters the size and the position of the
operating system window corresponding to `session`\'s
[current top-level browsing
context](#dfn-current-top-level-browsing-context).

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `width` be the result of [getting a
 property](#dfn-getting-properties) named \"`width`\" from
 `parameters`.

2. If `width` is
 [undefined](#dfn-undefined), let `width` be null.

3. Let `height` be the result of [getting a
 property](#dfn-getting-properties) named \"`height`\" from
 `parameters`.

4. If `height` is
 [undefined](#dfn-undefined), let `height` be null.

5. Let `x` be the result of [getting a
 property](#dfn-getting-properties) named \"`x`\" from
 `parameters`.

6. If `x` is
 [undefined](#dfn-undefined), let `x` be null.

7. Let `y` be the result of [getting a
 property](#dfn-getting-properties) named \"`y`\" from
 `parameters`.

8. If `y` is
 [undefined](#dfn-undefined), let `y` be null.

9. If `width` or `height` is neither null, nor a
 [Number](#dfn-number) from 0 to 2^31^ − 1, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

10. If `x` or `y` is neither null, nor a
 [Number](#dfn-number) from −(2^31^) to 2^31^ − 1, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

11. If the [remote end](#dfn-remote-ends) does not support the [Set Window
 Rect](#dfn-set-window-rect)
 [command](#dfn-commands) for `session`\'s [current top-level
 browsing
 context](#dfn-current-top-level-browsing-context) for any reason, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [unsupported
 operation](#dfn-unsupported-operation).

 ::::
 :::
 Note
 :::

 In case the [Set Window
 Rect](#dfn-set-window-rect) command is partially supported (i.e.
 some combinations of arguments are supported but not others), the
 implmentation is expected to continue with the remaining steps.
 ::::

12. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

13. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

14. [Fully exit
 fullscreen](#dfn-fully-exit-fullscreen).

15. [Restore the
 window](#dfn-restore-the-window).

16. Let `window` be the operating system window containing
 `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context)

17. If the implementation is able to set the dimensions of
 `window`:

 1. If `width` is not null, set the width, in [CSS
 pixels](#dfn-css-pixels), of `window`, including any [browser
 chrome](#dfn-browser-chrome) and externally drawn window
 decorations, to a value that is as close as possible to
 `width`.

 2. If `height` is not null, set the height, in [CSS
 pixels](#dfn-css-pixels), of `window`, including any [browser
 chrome](#dfn-browser-chrome) and externally drawn window
 decorations, to a value that is as close as possible to
 `height`.

 ::::
 :::
 Note
 :::

 The specification does not guarantee that the resulting window size
 will exactly match that which was requested. In particular the
 implementation is expected to clamp values that are larger than the
 physical screen dimensions, or smaller than the minimum window size.

 Particular implementations may have other limitations such as not
 being able to resize in single-pixel increments.

 This is intended to mutate the value of `session`\'s
 [current top-level browsing
 context](#dfn-current-top-level-browsing-context)\'s
 [`WindowProxy`](#dfn-windowproxy)\'s
 [outerWidth](#dfn-outerwidth) and
 [outerHeight](#dfn-outerheight) properties. Specifically, the value of
 [outerWidth](#dfn-outerwidth) should be as close as possible to
 `width` and the value of
 [outerHeight](#dfn-outerheight) should be as close as possible to
 `height`.
 ::::

18. If the implementation is able to set the position of
 `window`:

 1. If `x` is not null, set the x-coordinate of the left
 edge of `window` to a value that is as close as
 possible to `x`.

 2. If `y` is not null, set the y-coordinate of the top
 edge of `window` to a value that is as close as
 possible to `y`.

 ::::
 :::
 Note
 :::

 The specification does not guarantee that the resulting window
 position will match that which was requested.

 This step is similar to calling the [moveTo(x,
 y)](#dfn-moveto-x-y) method on the
 [`WindowProxy`](#dfn-windowproxy) object associated with
 `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context), but without the [security
 restrictions](https://developer.mozilla.org/en-US/docs/Web/API/Window/moveTo)
 that you

 a. cannot move a window or tab that was not created by
 `window.open`.
 b. cannot move a window or tab when it is in a window with more
 than one tab.
 ::::

19. Return [success](#dfn-success) with data set to the [WindowRect
 object](#dfn-windowrect-object) for the `session`\'s
 [current top-level browsing
 context](#dfn-current-top-level-browsing-context).

::: header-wrapper
#### 11.8.3 [Maximize Window]

------------- ----------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/window/maximize
 ------------- ----------------------------------------------------

The [Maximize
Window](#dfn-maximize-window) command invokes the window
manager-specific "maximize" operation, if any, on the window containing
`session`\'s [current top-level browsing
context](#dfn-current-top-level-browsing-context). This typically increases the window to
the maximum available size without going full-screen.

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If the [remote end](#dfn-remote-ends) does not support the [Maximize
 Window](#dfn-maximize-window) command for `session`\'s
 [current top-level browsing
 context](#dfn-current-top-level-browsing-context) for any reason, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [unsupported
 operation](#dfn-unsupported-operation).

2. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

3. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

4. [Fully exit
 fullscreen](#dfn-fully-exit-fullscreen).

5. [Restore the
 window](#dfn-restore-the-window).

6. [Maximize the
 window](#dfn-maximize-the-window) of `session`\'s [current
 top-level browsing
 context](#dfn-current-top-level-browsing-context).

7. Return [success](#dfn-success) with data set to the [WindowRect
 object](#dfn-windowrect-object) for the `session`\'s
 [current top-level browsing
 context](#dfn-current-top-level-browsing-context).

::: header-wrapper
#### 11.8.4 [Minimize Window]

------------- ----------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/window/minimize
 ------------- ----------------------------------------------------

The [Minimize
Window](#dfn-minimize-window) command invokes the window
manager-specific "minimize" operation, if any, on the window containing
`session`\'s [current top-level browsing
context](#dfn-current-top-level-browsing-context). This typically hides the window in the
system tray.

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If the [remote end](#dfn-remote-ends) does not support the [Minimize
 Window](#dfn-minimize-window) command for `session`\'s
 [current top-level browsing
 context](#dfn-current-top-level-browsing-context) for any reason, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [unsupported
 operation](#dfn-unsupported-operation).

2. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

3. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

4. [Fully exit
 fullscreen](#dfn-fully-exit-fullscreen).

5. [Iconify the
 window](#dfn-iconify-the-window).

6. Return [success](#dfn-success) with data set to the [WindowRect
 object](#dfn-windowrect-object) for the `session`\'s
 [current top-level browsing
 context](#dfn-current-top-level-browsing-context).

::: header-wrapper
#### 11.8.5 [Fullscreen Window]

------------- ------------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/window/fullscreen
 ------------- ------------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If the [remote end](#dfn-remote-ends) does not [support
 fullscreen](#dfn-support-fullscreen) return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [unsupported
 operation](#dfn-unsupported-operation).

2. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

3. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

4. [Restore the
 window](#dfn-restore-the-window).

5. Call [fullscreen an
 element](#dfn-fullscreen-an-element) with `session`\'s [current
 top-level browsing
 context](#dfn-current-top-level-browsing-context)\'s [active
 document](#dfn-active-document)\'s [document
 element](https://dom.spec.whatwg.org/#document-element).

 ::::
 :::
 Note
 :::

 The window is now in the [Fullscreen window
 state](#dfn-fullscreen-window-state).
 ::::

6. Return [success](#dfn-success) with data set to the [WindowRect
 object](#dfn-windowrect-object) for the `session`\'s
 [current top-level browsing
 context](#dfn-current-top-level-browsing-context).

::: header-wrapper
## 12. Elements

A [web element] is an abstraction
used to identify an
[element](https://dom.spec.whatwg.org/#concept-element) when it is transported via the [protocol](#protocol),
between [remote](#dfn-remote-ends) and
[local](#dfn-local-ends) ends.

The [web element identifier] is the string
constant \"`element-6066-11e4-a52e-4f735466cecf`\".

An ECMAScript [Object](#dfn-object) [represents a web
element] if it has a [web element
identifier](#dfn-web-element-identifier) [own
property](#dfn-own-properties).

The [WebDriver node id] is a globally unique string
representing a handle to a DOM node in a specific WebDriver
[session](#dfn-sessions).

A [weak map] is a
[map](https://infra.spec.whatwg.org/#ordered-map) in which keys are held weakly i.e. items are removed if
the key object is garbaged collected, and presence in the map does not
prevent garbage collection. This acts as an alternative to defining
properties directly on the key objects.

Unlike the ECMAScript
[WeakMap](#dfn-ecmascript-type), a [weak
map](#dfn-weak-map) can participate in the full set of operations available
for a Map.

A WebDriver [session](#dfn-sessions) has a [browsing context group node
map], which is a [weak
map](#dfn-weak-map) between a [browsing context
group](#dfn-browsing-context-group) and a [node id
map](#dfn-node-id-map).

A [node id map] is [weak
map](#dfn-weak-map) between nodes and their corresponding [WebDriver node
id](#dfn-webdriver-node-id).

A WebDriver [session](#dfn-sessions) has a [navigable seen nodes
map] which is a [weak
map](#dfn-weak-map) between a
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable) and a set.

To [get a node] given `session`,
`browsing context`, and `reference`:

1. Let `browsing context group node map` be
 `session`\'s [browsing context group node
 map](#dfn-browsing-context-group-node-map).
2. Let `browsing context group` be
 `browsing context`\'s [browsing context
 group](#dfn-browsing-context-group).
3. If `browsing context group node map` does not contain
 `browsing context group`, return null.
4. Let `node id map` be
 `browsing context group node map`\[`browsing context group`\].
5. Let `node` be the entry in `node id map` whose
 value is `reference`, if such an entry exists, or null
 otherwise.
6. Return `node`.

To [get or create a node reference] given
`session`, `browsing context`, and
`node`:

1. Let `browsing context group node map` be
 `session`\'s [browsing context group node
 map](#dfn-browsing-context-group-node-map).

2. Let `browsing context group` be
 `browsing context`\'s [browsing context
 group](#dfn-browsing-context-group).

3. If `browsing context group node map` does not contain
 `browsing context group`, set
 `browsing context group node map`\[`browsing context group`\]
 to a new [weak map](#dfn-weak-map).

4. Let `node id map` be
 `browsing context group node map`\[`browsing context group`\].

5. If `node id map` does not contain `node`:
 1. Let `node id` be a new globally unique string.
 2. Set `node id map`\[`node`\] to
 `node id`.
 3. Let `navigable` be `browsing context`\'s
 [active
 document](#dfn-active-document)\'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable).
 4. Let `navigable seen nodes map` be
 `session`\'s [navigable seen nodes
 map](#dfn-navigable-seen-nodes-map).
 5. If `navigable seen nodes map` does not contain
 `navigable`, set
 `navigable seen nodes map`\[`navigable`\]
 to an empty set.
 6. Append `node id` to
 `navigable seen nodes map`\[`navigable`\].

6. Return `node id map`\[`node`\].

A [node reference is known] given
`session`, `browsing context`, and
`reference` if the following steps return true:

1. Let `navigable` be `browsing context`\'s
 [active
 document](#dfn-active-document)\'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable).
2. Let `navigable seen nodes map` be `session`\'s
 [navigable seen nodes
 map](#dfn-navigable-seen-nodes-map).
3. If `navigable seen nodes map`
 [contains](https://infra.spec.whatwg.org/#map-exists) `navigable` and
 `navigable seen nodes map`\[`navigable`\]
 [contains](https://infra.spec.whatwg.org/#list-contain) `reference`, return true, otherwise
 return false.

To [get a known element] given `session` and
`reference`:

1. If not [node reference is
 known](#dfn-node-reference-is-known) with `session`,
 `session`\'s [current browsing
 context](#dfn-current-browsing-context), and `reference` return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 element](#dfn-no-such-element).
2. Let `node` be the result of [get a
 node](#dfn-get-a-node) with `session`, `session`\'s
 [current browsing
 context](#dfn-current-browsing-context), and `reference`.
3. If `node` is not null and `node` does not
 implement
 [`Element`](https://dom.spec.whatwg.org/#element) return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 element](#dfn-no-such-element).
4. If `node` is null or `node` [is
 stale](#dfn-is-stale) return [error](#dfn-error) with [error
 code](#dfn-error-code) [stale element
 reference](#dfn-stale-element-reference).
5. Return [success](#dfn-success) with data `node`.

To [get or create a web element
reference] given `session` and
[`element`](https://dom.spec.whatwg.org/#concept-element):

1. Assert: `element` implements
 [`Element`](https://dom.spec.whatwg.org/#element).
2. Return the result of [trying](#dfn-try) to [get or create a node
 reference](#dfn-get-or-create-a-node-reference) given `session`,
 `session`\'s [current browsing
 context](#dfn-current-browsing-context), and `element`.

The [web element reference object] for
`session` and `element` is:

1. Let `identifier` be the [web element
 identifier](#dfn-web-element-identifier).

2. Let `reference` be the result of [get or create a web
 element
 reference](#dfn-get-or-create-a-web-element-reference) with `session` and
 `element`.

3. Return a JSON [Object](#dfn-object) initialized with a property with name
 `identifier` and value `reference`.

To [deserialize a web element] by a JSON
[Object](#dfn-object) `object` that [represents a web
element](#dfn-represents-a-web-element):

1. If `object` has no [own
 property](#dfn-own-properties) [web element
 identifier](#dfn-web-element-identifier), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

2. Let `reference` be the result of
 [getting](#dfn-getting-properties) the [web
 element
 identifier](#dfn-web-element-identifier) property from `object`.

3. If `reference` is not a
 [String](#dfn-string), return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

4. Let `element` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `reference`.

5. Return [success](#dfn-success) with data `element`.

An
[element](https://dom.spec.whatwg.org/#concept-element) [is stale] if its [node
document](https://dom.spec.whatwg.org/#concept-node-document) is not the [active
document](#dfn-active-document) or if it is not
[connected](https://dom.spec.whatwg.org/#connected).

To [scroll into view] an
[`element`](https://dom.spec.whatwg.org/#concept-element) perform the following steps only if the element is not
already [in view](#dfn-in-view):

1. Let `options` be the following
 [`ScrollIntoViewOptions`](#dfn-scrollintoviewoptions):

 \"`behavior`\"
 : \"`instant`\"

 [Logical scroll position \"`block`\"](#dfn-logical-scroll-position-block)
 : \"`end`\"

 [Logical scroll position \"`inline`\"](#dfn-logical-scroll-position-inline)
 : \"`nearest`\"

2. Run [Function.\[\[Call\]\]](#dfn-call)([scrollIntoView](#dfn-scrollintoview), `options`) with
 `element` as the this value.

[Editable]
[elements](https://dom.spec.whatwg.org/#concept-element) are those that can be used for
[typing](#dfn-element-send-keys) and
[clearing](#dfn-element-clear), and they fall into two
subcategories:

[Mutable form control elements]

: Denotes [`input`](#dfn-input) elements that are
 [mutable](#dfn-mutable) (e.g. that are not [read
 only](#dfn-read-only) or
 [disabled](#dfn-disabled)) and whose
 [`type`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type) attribute is in one of the following
 states:

 - [Text and
 Search](#dfn-text-and-search-state)
 - [URL](#dfn-url-state)
 - [Telephone](#dfn-telephone-state)
 - [Email](#dfn-email-state)
 - [Password](#dfn-password-state)
 - [Date](#dfn-date-state)
 - [Month](#dfn-month-state)
 - [Week](#dfn-week-state)
 - [Time](#dfn-time-state)
 - [Local Date and
 Time](#dfn-local-date-and-time-state)
 - [Number](#dfn-number-state)
 - [Range](#dfn-range-state)
 - [Color](#dfn-color-state)
 - [File
 Upload](#dfn-file-upload-state)

 And the
 [`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element) element.

[Mutable elements]

: Denotes elements that are [editing
 hosts](#dfn-editing-hosts) or [content
 editable](#dfn-content-editable).

An
[element](https://dom.spec.whatwg.org/#concept-element) is said to have [pointer events
disabled] if the [resolved
value](#dfn-resolved-value) of its \"`pointer-events`\" style property is
\"`none`\".

An
[element](https://dom.spec.whatwg.org/#concept-element) is to be considered [read only] if it is an
[`input`](#dfn-input) element whose
[`readonly`](https://html.spec.whatwg.org/multipage/input.html#attr-input-readonly) attribute is set.

::: header-wrapper
### 12.1 Interactability

In order to determine if an
[element](https://dom.spec.whatwg.org/#concept-element) can be interacted with using pointer actions, WebDriver
performs hit-testing to find if the interaction will be able to reach
the requested element.

An [interactable element] is an
[element](https://dom.spec.whatwg.org/#concept-element) which is either
[pointer-interactable](#dfn-pointer-interactable) or
[keyboard-interactable](#dfn-keyboard-interactable).

A [pointer-interactable element] is defined to be the first
[element](https://dom.spec.whatwg.org/#concept-element), defined by the [paint
order](#dfn-paint-order) found at the [center
point](#dfn-center-point) of its rectangle that is inside the
[viewport](#dfn-viewport), excluding the size of any rendered scrollbars.

A [keyboard-interactable element] is any
[element](https://dom.spec.whatwg.org/#concept-element) that has a [focusable
area](#dfn-focusable-area), is a [`body`](#dfn-body) element, or is the [document
element](https://dom.spec.whatwg.org/#document-element).

An
[element](https://dom.spec.whatwg.org/#concept-element)\'s [in-view center point] is the origin position of the
rectangle that is the intersection between the element\'s first
[`DOMRect`](https://www.w3.org/TR/geometry-1/#domrect) of
[`getClientRects`](https://www.w3.org/TR/cssom-view-1/#dom-element-getclientrects)`()` and the [initial
viewport](#dfn-viewport). It can be calculated this way:

1. Let `rectangle` be the first object of the
 [`DOMRect`](https://www.w3.org/TR/geometry-1/#domrect) collection returned by calling
 [`getClientRects`](https://www.w3.org/TR/cssom-view-1/#dom-element-getclientrects)`()` on
 [`element`](https://dom.spec.whatwg.org/#concept-element).

2. Let `left` be [max](#dfn-max)(0, [min](#dfn-min)([x
 coordinate](#dfn-x-coordinate), [x
 coordinate](#dfn-x-coordinate) + [width
 dimension](#dfn-width-dimension))).

3. Let `right` be [min](#dfn-min)([innerWidth](#dfn-innerwidth), [max](#dfn-max)([x
 coordinate](#dfn-x-coordinate), [x
 coordinate](#dfn-x-coordinate) + [width
 dimension](#dfn-width-dimension))).

4. Let `top` be [max](#dfn-max)(0, [min](#dfn-min)([y
 coordinate](#dfn-y-coordinate), [y
 coordinate](#dfn-y-coordinate) + [height
 dimension](#dfn-height-dimension))).

5. Let `bottom` be [min](#dfn-min)([innerHeight](#dfn-innerheight), [max](#dfn-max)([y
 coordinate](#dfn-y-coordinate), [y
 coordinate](#dfn-y-coordinate) + [height
 dimension](#dfn-height-dimension))).

6. Let `x` be [floor](#dfn-floor)((`left` +
 `right`) ÷ 2.0).

7. Let `y` be [floor](#dfn-floor)((`top` +
 `bottom`) ÷ 2.0).

8. Return the pair of (`x`, `y`).

An
[element](https://dom.spec.whatwg.org/#concept-element) `element` is [disabled] if the following
steps return true:

1. If `element` is an
 [option](https://html.spec.whatwg.org/multipage/form-elements.html#the-option-element) element or `element` is an
 [optgroup](https://html.spec.whatwg.org/multipage/form-elements.html#the-optgroup-element) element:

 1. For each [inclusive
 ancestor](https://dom.spec.whatwg.org/#concept-tree-inclusive-ancestor) `ancestor` of `element`:

 1. If `ancestor` is an
 [optgroup](https://html.spec.whatwg.org/multipage/form-elements.html#the-optgroup-element) element or `ancestor` is a
 [select](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element) element, and `ancestor` is
 [actually
 disabled](#dfn-actually-disabled), return true.

 2. Return false.

2. Return `element` is [actually
 disabled](#dfn-actually-disabled).

An
[element](https://dom.spec.whatwg.org/#concept-element) is [in view] if it is a member of its own
[pointer-interactable paint
tree](#dfn-pointer-interactable-paint-tree), given the pretense that its [pointer
events are not
disabled](#dfn-pointer-events-are-not-disabled).

An
[element](https://dom.spec.whatwg.org/#concept-element) is [obscured] if the [pointer-interactable paint
tree](#dfn-pointer-interactable-paint-tree) at its [center
point](#dfn-center-point) is empty, or the first element in this tree is not an
[inclusive
descendant](https://dom.spec.whatwg.org/#concept-tree-inclusive-descendant) of itself.

[Example 10](#example-10)

This ascertains if the
[element](https://dom.spec.whatwg.org/#concept-element)\'s [in-view center
point](#dfn-center-point) would be possible to
[interact](#dfn-element-click) with.

For example, the [paint
tree](#dfn-paint-order) at this button\'s [center
point](#dfn-center-point), the red square, is not itself the button or a
[descendant](https://dom.spec.whatwg.org/#concept-tree-descendant) of the button. In other words, it is not an *[inclusive
descendant](https://dom.spec.whatwg.org/#concept-tree-inclusive-descendant)*. This makes the button
*[obscured](#dfn-obscuring)*:

foobar

::: {style="
 position: absolute;
 height: 100px;
 width: 100px;
 background: rgba(255,0,0,.5);
 margin-left: 40px;
 margin-top: -120px;"}

On the other hand, the [center
point](#dfn-center-point) of the following select list is the third
[`option`](https://html.spec.whatwg.org/multipage/form-elements.html#the-option-element) element, because unlike a drop-down list,
`<select multiple>`\'s options are individually visible and painted.
Because the option is a
*[descendant](https://dom.spec.whatwg.org/#concept-tree-descendant)* of the
[`select`](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element) element, it is *not*
[obscured](#dfn-obscuring):

first second third fourth

An
[`element`](https://dom.spec.whatwg.org/#concept-element)\'s [pointer-interactable paint
tree] is produced this way:

1. If `element` is [not in the same
 tree](#dfn-not-in-the-same-tree) as `session`\'s [current
 browsing
 context](#dfn-current-browsing-context)\'s [active
 document](#dfn-active-document), return an empty sequence.

2. Let `rectangles` be the
 [`DOMRect`](https://www.w3.org/TR/geometry-1/#domrect) sequence returned by calling
 [`getClientRects`](https://www.w3.org/TR/cssom-view-1/#dom-element-getclientrects)`()`.

3. If `rectangles` has the length of 0, return an empty
 sequence.

4. Let `center point` be the [in-view center
 point](#dfn-center-point) of the first indexed element in
 `rectangles`.

5. Return the [elements from
 point](#dfn-paint-order) given the coordinates `center point`.

::: header-wrapper
### 12.2 Shadow Roots

A [shadow root] is an abstraction
used to identify a [shadow
root](#dfn-shadow-roots) when it is transported via the [protocol](#protocol),
between [remote](#dfn-remote-ends) and
[local](#dfn-local-ends) ends.

The [shadow root identifier] is the string
constant \"`shadow-6066-11e4-a52e-4f735466cecf`\".

An ECMAScript [Object](#dfn-object) [represents a shadow
root] if it has a [shadow root
identifier](#dfn-shadow-root-identifier) [own
property](#dfn-own-properties).

To [get a known shadow root] given
`session` and `reference`:

1. If not [node reference is
 known](#dfn-node-reference-is-known) with `session`,
 `session`\'s [current browsing
 context](#dfn-current-browsing-context), and `reference` return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such shadow
 root](#dfn-no-such-shadow-root).
2. Let `node` be the result of [get a
 node](#dfn-get-a-node) with `session`, `session`\'s
 [current browsing
 context](#dfn-current-browsing-context), and `reference`.
3. If `node` is not null and `node` does not
 implement
 [`ShadowRoot`](https://dom.spec.whatwg.org/#shadowroot) return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such shadow
 root](#dfn-no-such-shadow-root).
4. If `node` is null or `node` [is
 detached](#dfn-is-detached) return [error](#dfn-error) with [error
 code](#dfn-error-code) [detached shadow
 root](#dfn-detached-shadow-root).
5. Return [success](#dfn-success) with data `node`.

To [get or create a shadow root
reference] given `session` and
`shadow root`:

1. Assert: `element` implements
 [`ShadowRoot`](https://dom.spec.whatwg.org/#shadowroot).
2. Return the result of [trying](#dfn-try) to [get or create a node
 reference](#dfn-get-or-create-a-node-reference) with `session`,
 `session`\'s [current browsing
 context](#dfn-current-browsing-context), and `element`.

The [shadow root reference object] for
`session` and `shadow root` is given by:

1. Let `identifier` be the [shadow root
 identifier](#dfn-shadow-root-identifier).

2. Let `reference` be the result of [get or create a shadow
 root
 reference](#dfn-get-or-create-a-shadow-root-reference) with `session` and
 `shadow root`.

3. Return a JSON [Object](#dfn-object) initialized with a property with name
 `identifier` and value `reference`.

When required to [deserialize a shadow
root] by a JSON
[Object](#dfn-object) `object` that [represents a shadow
root](#dfn-represents-a-shadow-root):

1. If `object` has no [own
 property](#dfn-own-properties) [shadow root
 identifier](#dfn-shadow-root-identifier), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

2. Let `reference` be the result of
 [getting](#dfn-getting-properties) the [shadow
 root
 identifier](#dfn-shadow-root-identifier) property from `object`.

3. If `reference` is not a
 [String](#dfn-string), return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

4. Let `shadow` be the result of
 [trying](#dfn-try)
 to [get a known shadow
 root](#dfn-get-a-known-shadow-root) with `session` and
 `reference`.

5. Return [success](#dfn-success) with data `shadow`.

A [shadow root](#dfn-shadow-roots) [is detached] if its [node
document](https://dom.spec.whatwg.org/#concept-node-document) is not the [active
document](#dfn-active-document) or if the element node referred to as its
[host](#dfn-host) [is
stale](#dfn-is-stale).

::: header-wrapper
### 12.3 Retrieval

The [Find Element](#dfn-find-element), [Find
Elements](#dfn-find-elements), [Find Element From
Element](#dfn-find-element-from-element), [Find Elements From
Element](#dfn-find-elements-from-element), [Find Element From Shadow
Root](#dfn-find-element-from-shadow-root), and [Find Elements From Shadow
Root](#dfn-find-elements-from-shadow-root)
[commands](#dfn-commands) allow lookup of individual elements and collections of
elements. Element retrieval searches are performed using pre-order
traversal of the document\'s nodes that match the provided selector\'s
expression.

When required to [find] given `session`,
`start node`, `using` and `value`, a
[remote end](#dfn-remote-ends) must run the following steps:

1. Let `location strategy` be equal to `using`.

2. Let `selector` be equal to `value`.

3. Let `timeout` be `session`\'s [session
 timeouts](#dfn-session-timeouts)\' [implicit wait
 timeout](#dfn-implicit-wait-timeout).

4. Let `timer` be a new
 [timer](#dfn-timer).

5. If `timeout` is not null:

 1. [Start the
 timer](#dfn-start-the-timer) with `timer` and
 `timeout`.

6. Let `elements returned` be an empty
 [List](#dfn-list).

7. While `elements returned` is empty and
 `timer``'s `[`timeout fired flag`](#dfn-timeout-fired-flag)` is not set: `

 1. Set `elements returned` to the result of
 [trying](#dfn-try) to call the relevant [element location
 strategy](#dfn-strategy) with arguments `start node`, and
 `selector`.

 2. If a
 [`DOMException`](#dfn-domexception),
 [`SyntaxError`](#dfn-syntaxerror),
 [`XPathException`](#dfn-xpathexception), or other error occurs during the
 execution of the [element location
 strategy](#dfn-strategy), return
 [error](#dfn-error) [invalid
 selector](#dfn-invalid-selector).

8. Let `result` be an empty
 [List](#dfn-list).

9. For each `element` in `elements returned`,
 append the [web element reference
 object](#dfn-web-element-reference-object) for `session` and
 `element`, to `result`.

10. Return [success](#dfn-success) with data `result`.

::: header-wrapper
#### 12.3.1 Locator strategies

An [element location strategy] is an [enumerated
attribute](#dfn-enumerated-attribute) deciding what technique should be used to
search for
[elements](https://dom.spec.whatwg.org/#concept-element) in `session`\'s [current browsing
context](#dfn-current-browsing-context). The following [table of location
strategies] lists the keywords and states
defined for this attribute:

 --------------------------------------------------------------------------------------------------------------------------------------- -------------------------
 State Keyword
 [CSS selector](#dfn-css-selector) \"`css selector`\"
 [Link text selector](#dfn-link-text-selector) \"`link text`\"
 [Partial link text selector](#dfn-partial-link-text-selector) \"`partial link text`\"
 [Tag name](#dfn-tag-name) \"`tag name`\"
 [XPath selector](#dfn-xpath-selector) \"`xpath`\"
 --------------------------------------------------------------------------------------------------------------------------------------- -------------------------

::: header-wrapper
##### 12.3.1.1 CSS selectors

To find a [web element](#dfn-web-elements) with the [CSS Selector]
[strategy](#dfn-strategy) the following steps need to be completed:

1. Let `elements` be the result of calling
 [`querySelectorAll`](https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall)`()` with
 `start node` as [this](#dfn-this) and `selector` as the
 argument. If this causes an exception to be thrown, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 selector](#dfn-invalid-selector).

2. Return [success](#dfn-success) with data `elements`.

::: header-wrapper
##### 12.3.1.2 Link text

To find a [web element](#dfn-web-elements) with the [Link
Text]
[strategy](#dfn-strategy) the following steps need to be completed:

1. Let `elements` be the result of calling
 [`querySelectorAll`](https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall)`()` with
 `start node` as [this](#dfn-this) and \"`a`\" as the argument. If this
 throws an exception, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [unknown
 error](#dfn-unknown-error).

2. Let `result` be an empty
 [`NodeList`](https://dom.spec.whatwg.org/#nodelist).

3. For each `element` in `elements`:

 1. Let `rendered text` be the value that would be
 returned via a call to [Get Element
 Text](#dfn-get-element-text) for `element`.

 2. Let `trimmed text` be the result of removing all
 [whitespace](#dfn-whitespace) from the start and end of the
 string `rendered text`.

 3. If `trimmed text` equals `selector`,
 append `element` to `result`.

4. Return [success](#dfn-success) with data `result`.

::: header-wrapper
##### 12.3.1.3 Partial link text

The [Partial link text]
[strategy](#dfn-strategy) is very similar to the [Link
Text](#dfn-link-text-selector)
[strategy](#dfn-strategy), but rather than matching the entire string, only a
substring needs to match. That is, return all
[`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) elements with rendered text that contains the
selector expression.

To find a [web element](#dfn-web-elements) with the [Partial Link
Text](#dfn-partial-link-text-selector)
[strategy](#dfn-strategy) the following steps need to be completed:

1. Let `elements` be the result of calling
 [`querySelectorAll`](https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall)`()` with
 `start node` as [this](#dfn-this) and \"`a`\" as the argument. If this
 throws an exception, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [unknown
 error](#dfn-unknown-error).

2. Let `result` be an empty
 [`NodeList`](https://dom.spec.whatwg.org/#nodelist).

3. For each `element` in `elements`:

 1. Let `rendered text` be the value that would be
 returned via a call to [Get Element
 Text](#dfn-get-element-text) for `element`.

 2. If `rendered text` contains `selector`,
 append `element` to `result`.

4. Return [success](#dfn-success) with data `result`.

::: header-wrapper
##### 12.3.1.4 Tag name

To find a [web element](#dfn-web-elements) with the [Tag Name]
[strategy](#dfn-strategy) return [success](#dfn-success) with data set to the result of calling
[`getElementsByTagName`](https://dom.spec.whatwg.org/#dom-element-getelementsbytagname)`()` with
`start node` as [this](#dfn-this) and `selector` as the argument.

::: header-wrapper
##### 12.3.1.5 XPath

To find a [web element](#dfn-web-elements) with the [XPath
Selector] [strategy](#dfn-strategy) the following steps need to be completed:

1. Let `evaluateResult` be the result of calling
 [`evaluate`](#dfn-evaluate), with arguments `selector`,
 `start node`, [`null`](#dfn-null),
 [ORDERED_NODE_SNAPSHOT_TYPE](#dfn-ordered_node_snapshot_type), and
 [`null`](#dfn-null).

 ::::
 :::
 Note
 :::

 A snapshot is used to promote operation atomicity.
 ::::

2. Let `index` be 0.

3. Let `length` be the result of [getting the
 property](#dfn-getting-properties) \"`snapshotLength`\" from
 `evaluateResult`. If this throws an
 [XPathException](#dfn-xpathexception) return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 selector](#dfn-invalid-selector), otherwise if this throws any other
 exception return [error](#dfn-error) with [error
 code](#dfn-error-code) [unknown
 error](#dfn-unknown-error).

4. Let `result` be an empty
 [`NodeList`](https://dom.spec.whatwg.org/#nodelist).

5. Repeat, while `index` is less than `length`:

 1. Let `node` be the result of calling
 [snapshotItem](#dfn-snapshotitem) with `evaluateResult`
 as [this](#dfn-this) and `index` as the argument.

 2. If `node` is not an
 [element](https://dom.spec.whatwg.org/#concept-element) return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 selector](#dfn-invalid-selector).

 3. Append `node` to `result`.

 4. Increment `index` by 1.

6. Return [success](#dfn-success) with data `result`.

::: header-wrapper
#### 12.3.2 [Find Element]

------------- --------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/element
 ------------- --------------------------------------------

The [Find Element](#dfn-find-element)
[command](#dfn-commands) is used to find an
[element](https://dom.spec.whatwg.org/#concept-element) in `session`\'s [current browsing
context](#dfn-current-browsing-context) that can be used as the [web
element](#dfn-web-elements) context for future element-centric
[commands](#dfn-commands).

For example, consider this pseudo code which retrieves an element with
the `#toremove` ID and uses this as the argument for a script it injects
to remove it from the HTML document:

```
let body = session.find.css("#toremove");
session.execute("arguments[0].remove()", [body]);
```

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `location strategy` be the result of [getting a
 property](#dfn-getting-properties) named \"`using`\" from
 `parameters`.

2. If `location strategy` is not present as a keyword in the
 [table of location
 strategies](#dfn-table-of-location-strategies), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Let `selector` be the result of [getting a
 property](#dfn-getting-properties) named \"`value`\" from
 `parameters`.

4. If `selector` is
 [undefined](#dfn-undefined), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

5. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

6. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

7. Let `start node` be `session`\'s [current
 browsing
 context](#dfn-current-browsing-context)\'s [document
 element](https://dom.spec.whatwg.org/#document-element).

8. If `start node` is
 [`null`](#dfn-null), return [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 element](#dfn-no-such-element).

9. Let `result` be the result of
 [trying](#dfn-try)
 to [Find](#dfn-find) with `session`, `start node`,
 `location strategy`, and `selector`.

10. If `result` is empty, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 element](#dfn-no-such-element). Otherwise, return the first element
 of `result`.

::: header-wrapper
#### 12.3.3 [Find Elements]

------------- ---------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/elements
 ------------- ---------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `location strategy` be the result of [getting a
 property](#dfn-getting-properties) named \"`using`\" from
 `parameters`.

2. If `location strategy` is not present as a keyword in the
 [table of location
 strategies](#dfn-table-of-location-strategies), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Let `selector` be the result of [getting a
 property](#dfn-getting-properties) named \"`value`\" from
 `parameters`.

4. If `selector` is
 [undefined](#dfn-undefined), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

5. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

6. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

7. Let `start node` be `session`\'s [current
 browsing
 context](#dfn-current-browsing-context)\'s [document
 element](https://dom.spec.whatwg.org/#document-element).

8. If `start node` is
 [`null`](#dfn-null), return [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 element](#dfn-no-such-element).

9. Return the result of [trying](#dfn-try) to
 [Find](#dfn-find)
 with `session`, `start node`,
 `location strategy`, and `selector`.

::: header-wrapper
#### 12.3.4 [Find Element From Element]

------------- ------------------------------------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/element/{`element id`}/element
 ------------- ------------------------------------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `location strategy` be the result of [getting a
 property](#dfn-getting-properties) named \"`using`\" from
 `parameters`.

2. If `location strategy` is not present as a keyword in the
 [table of location
 strategies](#dfn-table-of-location-strategies), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Let `selector` be the result of [getting a
 property](#dfn-getting-properties) named \"`value`\" from
 `parameters`.

4. If `selector` is
 [undefined](#dfn-undefined), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

5. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

6. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

7. Let `start node` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `URL variables`\[\"`element id`\"\].

8. Let `result` be the value of
 [trying](#dfn-try)
 to [Find](#dfn-find) with `session`, `start node`,
 `location strategy`, and `selector`.

9. If `result` is empty, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 element](#dfn-no-such-element). Otherwise, return the first element
 of `result`.

::: header-wrapper
#### 12.3.5 [Find Elements From Element]

------------- -------------------------------------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/element/{`element id`}/elements
 ------------- -------------------------------------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `location strategy` be the result of [getting a
 property](#dfn-getting-properties) named \"`using`\" from
 `parameters`.

2. If `location strategy` is not present as a keyword in the
 [table of location
 strategies](#dfn-table-of-location-strategies), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Let `selector` be the result of [getting a
 property](#dfn-getting-properties) named \"`value`\" from
 `parameters`.

4. If `selector` is
 [undefined](#dfn-undefined), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

5. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

6. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

7. Let `start node` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `URL variables`\[\"`element id`\"\].

8. Return the result of [trying](#dfn-try) to
 [Find](#dfn-find)
 with `session`, `start node`,
 `location strategy`, and `selector`.

::: header-wrapper
#### 12.3.6 [Find Element From Shadow Root]

------------- ----------------------------------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/shadow/{`shadow id`}/element
 ------------- ----------------------------------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `location strategy` be the result of [getting a
 property](#dfn-getting-properties) called \"`using`\".

2. If `location strategy` is not present as a keyword in the
 [table of location
 strategies](#dfn-table-of-location-strategies), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Let `selector` be the result of [getting a
 property](#dfn-getting-properties) called \"`value`\".

4. If `selector` is
 [undefined](#dfn-undefined), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

5. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

6. [Handle any user
 prompts](#dfn-handle-any-user-prompts) and return its value if it is an
 [error](#dfn-error).

7. Let `start node` be the result of
 [trying](#dfn-try)
 to [get a known shadow
 root](#dfn-get-a-known-shadow-root) with `session` and
 `URL variables`\[\"`shadow id`\"\].

8. Let `result` be the value of
 [trying](#dfn-try)
 to [Find](#dfn-find) with `session`, `start node`,
 `location strategy`, and `selector`.

9. If `result` is empty, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 element](#dfn-no-such-element). Otherwise, return the first element
 of `result`.

::: header-wrapper
#### 12.3.7 [Find Elements From Shadow Root]

------------- -----------------------------------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/shadow/{`shadow id`}/elements
 ------------- -----------------------------------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `location strategy` be the result of [getting a
 property](#dfn-getting-properties) called \"`using`\".

2. If `location strategy` is not present as a keyword in the
 [table of location
 strategies](#dfn-table-of-location-strategies), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Let `selector` be the result of [getting a
 property](#dfn-getting-properties) called \"`value`\".

4. If `selector` is
 [undefined](#dfn-undefined), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

5. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

6. [Handle any user
 prompts](#dfn-handle-any-user-prompts) and return its value if it is an
 [error](#dfn-error).

7. Let `start node` be the result of
 [trying](#dfn-try)
 to [get a known shadow
 root](#dfn-get-a-known-shadow-root) with `session` and
 `URL variables`\[\"`shadow id`\"\].

8. Return the result of [trying](#dfn-try) to
 [Find](#dfn-find)
 with `session`, `start node`,
 `location strategy`, and `selector`.

::: header-wrapper
#### 12.3.8 [Get Active Element]

------------- ---------------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/element/active
 ------------- ---------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `active element` be the [active
 element](#dfn-active-element) of `session`\'s [current
 browsing
 context](#dfn-current-browsing-context)\'s [document
 element](https://dom.spec.whatwg.org/#document-element).

4. If `active element` is a non-null
 [element](https://dom.spec.whatwg.org/#concept-element), return
 [success](#dfn-success) with data set to [web element reference
 object](#dfn-web-element-reference-object) for `session` and
 `active element`.

 Otherwise, return [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 element](#dfn-no-such-element).

::: header-wrapper
#### 12.3.9 [Get Element Shadow Root]

------------- -----------------------------------------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/element/{`element id`}/shadow
 ------------- -----------------------------------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Handle any user
 prompts](#dfn-handle-any-user-prompts) and return its value if it is an
 [error](#dfn-error).

3. Let `element` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `URL variables`\[`element id`\].

4. Let `shadow root` be `element`\'s [shadow
 root](#dfn-shadow-roots).

5. If `shadow root` is null, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such shadow
 root](#dfn-no-such-shadow-root).

6. Let `serialized` be the [shadow root reference
 object](#dfn-shadow-root-reference-object) for `session` and
 `shadow root`.

7. Return [success](#dfn-success) with data `serialized`.

::: header-wrapper
### 12.4 State

To [calculate the absolute
position] given `session` and
`element`:

1. Let `rect` be the value returned by calling
 [`getBoundingClientRect`](https://www.w3.org/TR/cssom-view-1/#dom-element-getboundingclientrect)`()`.

2. Let `window` be the [associated
 window](#dfn-associated-window) of `session`\'s [current
 top-level browsing
 context](#dfn-current-top-level-browsing-context).

3. Let `x` be
 ([scrollX](#dfn-scrollx) of `window` + `rect`\'s [x
 coordinate](#dfn-x-coordinate)).

4. Let `y` be
 ([scrollY](#dfn-scrolly) of `window` + `rect`\'s [y
 coordinate](#dfn-y-coordinate)).

5. Return a pair of (`x`, `y`).

To determine if
[node](https://dom.spec.whatwg.org/#concept-node) is [not in the same tree] as another
[node](https://dom.spec.whatwg.org/#concept-node), `other`, run the following substeps:

1. If the
 [node](https://dom.spec.whatwg.org/#concept-node)\'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document) is not `other`\'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document), return true.

2. Return true if the result of calling the
 [node](https://dom.spec.whatwg.org/#concept-node)\'s
 [`compareDocumentPosition`](https://dom.spec.whatwg.org/#dom-node-comparedocumentposition)`()` with
 `other` as argument is
 [`DOCUMENT_POSITION_DISCONNECTED`](https://dom.spec.whatwg.org/#dom-node-document_position_disconnected) (1), otherwise return false.

An
[`element`](https://dom.spec.whatwg.org/#concept-element)\'s [container] is:

[`option`](https://html.spec.whatwg.org/multipage/form-elements.html#the-option-element) element in a valid [element context](#dfn-element-context)\
[`optgroup`](https://html.spec.whatwg.org/multipage/form-elements.html#the-optgroup-element) element in a valid [element context](#dfn-element-context)

: The
 [`element`](https://dom.spec.whatwg.org/#concept-element)\'s [element
 context](#dfn-element-context), which is determined by:

 1. Let `datalist parent` be the first
 [`datalist`](https://html.spec.whatwg.org/multipage/form-elements.html#the-datalist-element) element reached by traversing the tree in
 reverse order from `element`, or
 [undefined](#dfn-undefined) if the root of the tree is
 reached.

 2. Let `select parent` be the first
 [`select`](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element) element reached by traversing the tree in
 reverse order from `element`, or
 [undefined](#dfn-undefined) if the root of the tree is
 reached.

 3. If `datalist parent` is
 [undefined](#dfn-undefined), the [element
 context](#dfn-element-context) is `select parent`.
 Otherwise, the [element
 context](#dfn-element-context) is `datalist parent`.

[`option`](https://html.spec.whatwg.org/multipage/form-elements.html#the-option-element) element in an invalid [element context](#dfn-element-context)

: The element does not have a container.

Otherwise

: The container is the
 [element](https://dom.spec.whatwg.org/#concept-element) itself.

::: header-wrapper
#### 12.4.1 [Is Element Selected]

------------- -------------------------------------------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/element/{`element id`}/selected
 ------------- -------------------------------------------------------------------------------

The [Is Element
Selected](#dfn-is-element-selected)
[command](#dfn-commands) determines if the referenced
[element](https://dom.spec.whatwg.org/#concept-element) is selected or not. This operation only makes sense on
[`input`](#dfn-input) elements of the
[Checkbox](#dfn-checkbox)- and [Radio
Button](#dfn-radio-button) states, or on
[`option`](https://html.spec.whatwg.org/multipage/form-elements.html#the-option-element) elements.

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `element` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `URL variables`\[`element id`\].

4. Let `selected` be the value corresponding to the first
 matching statement:

 `element` is an [`input`](#dfn-input) element with a [`type`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type) attribute in the [Checkbox](#dfn-checkbox)- or [Radio Button](#dfn-radio-button) state

 : The result of `element`\'s
 [checkedness](#dfn-checkedness).

 `element` is an [`option`](https://html.spec.whatwg.org/multipage/form-elements.html#the-option-element) element

 : The result of `element`\'s
 [selectedness](#dfn-selectedness).

 Otherwise
 : False.

5. Return [success](#dfn-success) with data `selected`.

MDN 

[Commands/GetElementAttribute](https://developer.mozilla.org/en-US/docs/Web/WebDriver/Commands/GetElementAttribute "The Get Element Attribute command of the WebDriver API returns the attribute of the referenced web element. If for example the element is an <img>, the returned attribute is "//TODO", which is equivalent to calling Element.getAttribute on the element. For XML/XHTML documents it may be cased differently.")

 ------------------ -----
 Chrome 65+
 Chrome Android No
 Edge ?
 Edge Mobile ?
 Firefox 55+
 Firefox Android No
 Opera No
 Opera Android ?
 Safari No
 Safari iOS ?
 Samsung Internet No
 WebView Android ?
 ------------------ -----

::: header-wrapper
#### 12.4.2 [Get Element Attribute]

------------- ----------------------------------------------------------------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/element/{`element id`}/attribute/{`name`}
 ------------- ----------------------------------------------------------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `element` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `URL variables`\' element id.

4. Let `name` be `URL variables`\[\"`name`\"\].

5. Let `result` be the result of the first matching
 condition:

 If `name` is a [boolean attribute](#dfn-boolean-attribute)

 : \"`true`\" (string) if the `element`
 [`hasAttribute`](https://dom.spec.whatwg.org/#dom-element-hasattribute)`()` with
 `name`, otherwise
 [`null`](#dfn-null).

 Otherwise

 : The result of [getting an attribute by
 name](https://dom.spec.whatwg.org/#concept-element-attributes-get-by-name)
 `name`.

6. Return [success](#dfn-success) with data `result`.

Please note that the behavior of this command deviates from the behavior
of
[`getAttribute`](https://dom.spec.whatwg.org/#dom-element-getattribute)`()` in
\[[DOM](#bib-dom "DOM Standard")\], which in
the case of a set [boolean
attribute](#dfn-boolean-attribute) would return an empty string. The reason
this command returns true as a string is because this evaluates to true
in most dynamically typed programming languages, but still preserves the
expected type information.

MDN 

[Commands/GetElementProperty](https://developer.mozilla.org/en-US/docs/Web/WebDriver/Commands/GetElementProperty "The Get Element Property command of the WebDriver API returns the property of the referenced web element. Given <input value=foo> where the user changes the value to bar, the returned property is bar rather than the initial value foo. This is equivalent to calling Element.getProperty on the element.")

 ------------------ -----
 Chrome 65+
 Chrome Android No
 Edge ?
 Edge Mobile ?
 Firefox 55+
 Firefox Android No
 Opera No
 Opera Android ?
 Safari No
 Safari iOS ?
 Samsung Internet No
 WebView Android ?
 ------------------ -----

::: header-wrapper
#### 12.4.3 [Get Element Property]

------------- ---------------------------------------------------------------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/element/{`element id`}/property/{`name`}
 ------------- ---------------------------------------------------------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `element` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `URL variables`\' element id.

4. Let `name` `URL variables`\[\"`name`\"\].

5. Let `property` be the result of calling the
 [Object.\[\[GetProperty\]\]](#dfn-getproperty)(`name`) on
 `element`.

6. Let `result` be the value of `property` if not
 [undefined](#dfn-undefined), or [`null`](#dfn-null).

7. Return [success](#dfn-success) with data `result`.

::: header-wrapper
#### 12.4.4 [Get Element CSS Value]

------------- -------------------------------------------------------------------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/element/{`element id`}/css/{`property name`}
 ------------- -------------------------------------------------------------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `element` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with
 `URL variables`\[\"`element id`\"\].

4. Let `computed value` be the result of the first matching
 condition:

 `session`\'s [current browsing context](#dfn-current-browsing-context)\'s [active document](#dfn-active-document)\'s [type](https://dom.spec.whatwg.org/#concept-document-type) is not \"`xml`\"
 : [computed
 value](#dfn-computed-value) of parameter
 `URL variables`\[\"`property name`\"\] from
 `element`\'s style declarations.

 Otherwise
 : \"\" (empty string)

5. Return [success](#dfn-success) with data `computed value`.

::: header-wrapper
#### 12.4.5 [Get Element Text]

------------- ---------------------------------------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/element/{`element id`}/text
 ------------- ---------------------------------------------------------------------------

The [Get Element
Text](#dfn-get-element-text)
[command](#dfn-commands) intends to return an
[element](https://dom.spec.whatwg.org/#concept-element)\'s text "as rendered". An
[element](https://dom.spec.whatwg.org/#concept-element)\'s rendered text is also used for locating
[`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) elements by their [link
text](#dfn-link-text-selector) and [partial link
text](#dfn-partial-link-text-selector).

One of the major inputs to this specification was the open source
[Selenium project](https://selenium.dev). This was in wide-spread use
before this specification written, and so had set user expectations of
how the [Get Element
Text](#dfn-get-element-text) command should work. As such, the approach
presented here is known to be flawed, but provides the best
compatibility with existing users.

When processing text, [whitespace] is defined as characters from the
Unicode Character Database with the [Unicode character
property](#dfn-unicode-character-property) \"`WSpace=Y`\" or \"`WS`\".
\[[UAX44](#bib-uax44 "Unicode Character Database")\]

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `element` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `URL variables`\[`element id`\].

4. Let `rendered text` be the result of performing
 implementation-specific steps whose result is exactly the same as
 the result of a
 [Function.\[\[Call\]\]](#dfn-call)([`null`](#dfn-null), `element`) with
 [`bot.dom.getVisibleText`](#dfn-bot-dom-getvisibletext) as the this value.

5. Return [success](#dfn-success) with data `rendered text`.

MDN 

[Commands/GetElementTagName](https://developer.mozilla.org/en-US/docs/Web/WebDriver/Commands/GetElementTagName "The Get Element Tag Name command of the WebDriver API returns the tag name of the referenced web element. If for example the element is an <img>, the returned tag name is "IMG", which is equivalent to calling Element.tagName on the element. For XML/XHTML documents it may be cased differently.")

 ------------------ -----
 Chrome 65+
 Chrome Android No
 Edge ?
 Edge Mobile ?
 Firefox 55+
 Firefox Android No
 Opera No
 Opera Android ?
 Safari No
 Safari iOS ?
 Samsung Internet No
 WebView Android ?
 ------------------ -----

::: header-wrapper
#### 12.4.6 [Get Element Tag Name]

------------- ---------------------------------------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/element/{`element id`}/name
 ------------- ---------------------------------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `element` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with
 `URL variables`\[\"`element id`\"\].

4. Let `qualified name` be the result of getting
 `element`\'s
 [`tagName`](https://dom.spec.whatwg.org/#dom-element-tagname) IDL attribute.

5. Return [success](#dfn-success) with data `qualified name`.

::: header-wrapper
#### 12.4.7 [Get Element Rect]

------------- ---------------------------------------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/element/{`element id`}/rect
 ------------- ---------------------------------------------------------------------------

The [Get Element
Rect](#dfn-get-element-rect)
[command](#dfn-commands) returns the dimensions and coordinates of the given
[web element](#dfn-web-elements). The returned value is an object with the
following properties:

\"`x`\"
: X axis position of the top-left corner of the [web
 element](#dfn-web-elements) relative to `session`\'s [current
 browsing
 context](#dfn-current-browsing-context)\'s [document
 element](https://dom.spec.whatwg.org/#document-element) in [CSS
 pixels](#dfn-css-pixels).

\"`y`\"
: Y axis position of the top-left corner of the [web
 element](#dfn-web-elements) relative to `session`\'s [current
 browsing
 context](#dfn-current-browsing-context)\'s [document
 element](https://dom.spec.whatwg.org/#document-element) in [CSS
 pixels](#dfn-css-pixels).

\"`height`\"
: Height of the [web
 element](#dfn-web-elements)\'s [bounding
 rectangle](#dfn-bounding-rectangle) in [CSS
 pixels](#dfn-css-pixels).

\"`width`\"
: Width of the [web
 element](#dfn-web-elements)\'s [bounding
 rectangle](#dfn-bounding-rectangle) in [CSS
 pixels](#dfn-css-pixels).

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `element` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `URL variables`\[\"`element id`\"\].

4. Let `coordinates` be [calculate the absolute
 position](#dfn-calculate-the-absolute-position) with `session` and
 `element`.

5. Let `rect` be `element`\'s [bounding
 rectangle](#dfn-bounding-rectangle).

6. Let `body` be a new JSON
 [Object](#dfn-object) initialized with:

 \"`x`\"
 : The first value of `coordinates`.

 \"`y`\"
 : The second value of `coordinates`.

 \"`width`\"
 : Value of `rect`\'s [width
 dimension](#dfn-width-dimension).

 \"`height`\"
 : Value of `rect`\'s [height
 dimension](#dfn-height-dimension).

7. Return [success](#dfn-success) with data `body`.

::: header-wrapper
#### 12.4.8 [Is Element Enabled]

------------- ------------------------------------------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/element/{`element id`}/enabled
 ------------- ------------------------------------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `element` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `URL variables`\[`element id`\].

4. Let `enabled` be a boolean initially set to true if
 `session`\'s [current browsing
 context](#dfn-current-browsing-context)\'s [active
 document](#dfn-active-document)\'s
 [type](https://dom.spec.whatwg.org/#concept-document-type) is not \"`xml`\".

 Otherwise, let `enabled` to false and jump to the last
 step of this algorithm.

5. Set `enabled` to false if a form control is
 [disabled](#dfn-disabled).

6. Return [success](#dfn-success) with data `enabled`.

::: header-wrapper
#### 12.4.9 [Get Computed Role]

------------- -----------------------------------------------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/element/{`element id`}/computedrole
 ------------- -----------------------------------------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `element` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with
 `URL variables`\[\"`element id`\"\].

4. Let `role` be the result of computing the [WAI-ARIA
 role](#dfn-wai-aria-role) of `element`.

5. Return [success](#dfn-success) with data `role`.

::: header-wrapper
#### 12.4.10 [Get Computed Label]

------------- ------------------------------------------------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/element/{`element id`}/computedlabel
 ------------- ------------------------------------------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `element` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `URL variables`\[\"`element id`\"\].

4. Let `label` be the result of a [Accessible Name and
 Description
 Computation](#dfn-accessible-name-and-description-computation) for the [Accessible
 Name](#dfn-accessible-name) of the `element`.

5. Return [success](#dfn-success) with data `label`.

::: header-wrapper
### 12.5 Interaction

[element](https://dom.spec.whatwg.org/#concept-element) interaction
[commands](#dfn-commands) provide a high-level instruction set for manipulating
form controls. Unlike [Actions](#dfn-actions), they will implicitly [scroll elements
into view](#dfn-scrolls-into-view) and check that it is
an [interactable element](#dfn-interactable).

Some [resettable
elements](#dfn-resettable-elements) define their own [clear
algorithm]. Unlike their associated [reset
algorithms](#dfn-reset-algorithms), changes made to form controls as part of
these algorithms *do* count as changes caused by the user (and thus,
e.g. do cause [`input`](#dfn-input) events to fire). When the [clear
algorithm](#dfn-clear-algorithm) is invoked for an element that does not
define its own [clear
algorithm](#dfn-clear-algorithm), its [reset
algorithm](#dfn-reset-algorithms) must be invoked instead.

The [clear
algorithm](#dfn-clear-algorithm) for
[`input`](#dfn-input) elements is to set the [dirty value
flag](#dfn-dirty-value-flag) and [dirty checkedness
flag](#dfn-dirty-checkedness-flag) back to false, set the
[value](#dfn-value)
of the element to an empty string, set the
[checkedness](#dfn-checkedness) of the element to true if the element has a
[`checked`](#dfn-checked) content attribute and false if it does not,
empty the list of [selected
files](#dfn-selected-files), and then invoke the [value sanitization
algorithm](#dfn-value-sanitization-algorithm) iff the
[`type`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type) attribute\'s current state defines one.

The [clear
algorithm](#dfn-clear-algorithm) for
[`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element) elements is to set the [dirty value
flag](#dfn-dirty-value-flag) back to false, and set the [raw
value](#dfn-raw-value) of element to an empty string.

The [clear
algorithm](#dfn-clear-algorithm) for
[`output`](https://html.spec.whatwg.org/multipage/form-elements.html#the-output-element) elements is set the element\'s [value mode
flag](#dfn-value-mode-flag) to default and then to set the element\'s
[`textContent`](https://dom.spec.whatwg.org/#dom-node-textcontent) IDL attribute to an empty string (thus clearing
the element\'s child nodes).

::: header-wrapper
#### 12.5.1 [Element Click]

------------- ----------------------------------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/element/{`element id`}/click
 ------------- ----------------------------------------------------------------------------

The [Element Click](#dfn-element-click)
[command](#dfn-commands) [scrolls into
view](#dfn-scrolls-into-view) the
[element](https://dom.spec.whatwg.org/#concept-element) if it is not already
[pointer-interactable](#dfn-pointer-interactable), and clicks its [in-view center
point](#dfn-center-point).

If the element\'s [center
point](#dfn-center-point) is [obscured](#dfn-obscuring) by another element, an [element click
intercepted](#dfn-element-click-intercepted) [error](#dfn-error) is returned. If the element is outside the
[viewport](#dfn-viewport), an [element not
interactable](#dfn-element-not-interactable) [error](#dfn-error) is returned.

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `element` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `element id`.

4. If the `element` is an
 [`input`](#dfn-input) element in the [file upload
 state](#dfn-file-upload-state) return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

5. [Scroll into
 view](#dfn-scrolls-into-view) the `element`\'s
 [container](#dfn-container).

6. If `element`\'s
 [container](#dfn-container) is still not [in
 view](#dfn-in-view), return [error](#dfn-error) with [error
 code](#dfn-error-code) [element not
 interactable](#dfn-element-not-interactable).

7. If `element`\'s
 [container](#dfn-container) is
 [obscured](#dfn-obscuring) by another
 [element](https://dom.spec.whatwg.org/#concept-element), return [error](#dfn-error) with [error
 code](#dfn-error-code) [element click
 intercepted](#dfn-element-click-intercepted).

8. Matching on `element`:

 [`option`](https://html.spec.whatwg.org/multipage/form-elements.html#the-option-element) element

 : 1. Let `parent node` be the `element`\'s
 [container](#dfn-container).

 2. [Fire](https://dom.spec.whatwg.org/#concept-event-fire) a [mouseOver
 event](#dfn-mouseover-event) at `parent node`.

 3. [Fire](https://dom.spec.whatwg.org/#concept-event-fire) a [mouseMove
 event](#dfn-mousemove-event) at `parent node`.

 4. [Fire](https://dom.spec.whatwg.org/#concept-event-fire) a [mouseDown
 event](#dfn-mousedown-event) at `parent node`.

 5. Run the [focusing
 steps](#dfn-focusing-steps) on `parent node`.

 6. If `element` is not
 [disabled](#dfn-disabled):

 1. [Fire](https://dom.spec.whatwg.org/#concept-event-fire) an
 [`input`](#dfn-input) event at `parent node`.

 2. Let `previous selectedness` be equal to
 `element`
 [selectedness](#dfn-selectedness).

 3. If `element`\'s
 [container](#dfn-container) has the [`multiple`
 attribute](#dfn-multiple-attribute), toggle the
 `element`\'s
 [selectedness](#dfn-selectedness) state by setting it to the
 opposite value of its current
 [selectedness](#dfn-selectedness).

 Otherwise, set the `element`\'s
 [selectedness](#dfn-selectedness) state to true.

 4. If `previous selectedness` is false,
 [fire](https://dom.spec.whatwg.org/#concept-event-fire) a
 [`change`](#dfn-change) event at
 `parent node`.

 7. [Fire](https://dom.spec.whatwg.org/#concept-event-fire) a [mouseUp
 event](#dfn-mouseup-event) at `parent node`.

 8. [Fire](https://dom.spec.whatwg.org/#concept-event-fire) a [click
 event](#dfn-click-event) at `parent node`.

 Otherwise

 : 1. Let `input state` be the result of [get the input
 state](#dfn-get-the-input-state) given `session` and
 `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context).

 2. Let `actions options` be a new [actions
 options](#dfn-actions-options) with the [is element
 origin](#dfn-is-element-origin) steps set to [represents a web
 element](#dfn-represents-a-web-element), and the [get element
 origin](#dfn-get-element-origin) steps set to [get a WebElement
 origin](#dfn-get-a-webelement-origin).

 3. Let `input id` be a the result of [generating a
 UUID](#dfn-generating-a-uuid).

 4. Let `source` be the result of [create an input
 source](#dfn-create-an-input-source) with `input state`,
 and \"`pointer`\".

 5. [Add an input
 source](#dfn-add-an-input-source) with `input state`,
 `input id` and `source`.

 6. Let `click point` be the `element`\'s
 [in-view center
 point](#dfn-center-point).

 7. Let `pointer move action` be an [action
 object](#dfn-action-object) constructed with arguments
 `input id`, \"`pointer`\", and \"`pointerMove`\".

 8. [Set a
 property](#dfn-set-a-property) `x` to `0` on
 `pointer move action`.

 9. [Set a
 property](#dfn-set-a-property) `y` to `0` on
 `pointer move action`.

 10. [Set a
 property](#dfn-set-a-property) `origin` to
 `element` on `pointer move action`.

 11. Let `pointer down action` be an [action
 object](#dfn-action-object) constructed with arguments
 `input id`, \"`pointer`\", and \"`pointerDown`\".

 12. [Set a
 property](#dfn-set-a-property) `button` to `0` on
 `pointer down action`.

 13. Let `pointer up action` be an [action
 object](#dfn-action-object) constructed with arguments
 `input id`, \"`pointer`\", and \"`pointerUp`\" as
 arguments.

 14. [Set a
 property](#dfn-set-a-property) `button` to `0` on
 `pointer up action`.

 15. Let `actions` be the list
 «`pointer move action`,
 `pointer down action`,
 `pointer up action`».

 16. [Dispatch a list of
 actions](#dfn-dispatch-a-list-of-actions) with `input state`,
 `actions`, `session`\'s [current
 browsing
 context](#dfn-current-browsing-context), and
 `actions options`.

 17. [Remove an input
 source](#dfn-remove-an-input-source) with `input state`
 and `input id`.

9. Wait until the user agent event loop has spun enough times to
 process the DOM events generated by the previous step.

10. Perform implementation-defined steps to allow any
 [navigations](#dfn-navigating) triggered by the click
 to start.

 ::::
 :::
 Note
 :::

 It is not always clear how long this will cause the algorithm to
 wait, and it is acknowledged that some implementations may have
 unavoidable race conditions. The intention is to allow a new attempt
 to [navigate](#dfn-navigating) to begin so that the next step in the
 algorithm is meaningful. It is possible the click does not cause an
 attempt to [navigate](#dfn-navigating), in which case the
 implementation-defined steps can return immediately, and the next
 step will also return immediately.
 ::::

11. [Try](#dfn-try) to
 [wait for navigation to
 complete](#dfn-wait-for-navigation-to-complete) with `session`.

12. [Try](#dfn-try) to
 run the [post-navigation
 checks](#dfn-post-navigation-checks).

13. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
#### 12.5.2 [Element Clear]

------------- ----------------------------------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/element/{`element id`}/clear
 ------------- ----------------------------------------------------------------------------

To [clear a content editable
element]:

1. If `element`\'s [`innerHTML` IDL
 attribute](#dfn-innerhtml-idl-attribute) is an empty string do nothing and
 return.

2. Run the [focusing
 steps](#dfn-focusing-steps) for `element`.

3. Set `element`\'s [`innerHTML` IDL
 attribute](#dfn-innerhtml-idl-attribute) to an empty string.

4. Run the [unfocusing
 steps](#dfn-unfocusing-steps) for the `element`.

To [clear a resettable element]:

1. Let `empty` be the result of the first matching
 condition:

 `element` is an [`input`](#dfn-input) element whose [`type`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type) attribute is in the [File Upload state](#dfn-file-upload-state)
 : True if the list of [selected
 files](#dfn-selected-files) has a length of 0, and false
 otherwise.

 Otherwise
 : True if its [value](#dfn-value) IDL attribute is an empty string,
 and false otherwise.

2. If `element` is a [candidate for constraint
 validation](#dfn-candidate-for-constraint-validation) it [satisfies its
 constraints](#dfn-satisfies-its-constraints), and `empty` is true, abort
 these substeps.

3. Invoke the [focusing
 steps](#dfn-focusing-steps) for `element`.

4. Invoke the [clear
 algorithm](#dfn-clear-algorithm) for `element`.

5. Invoke the [unfocusing
 steps](#dfn-unfocusing-steps) for the `element`.

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `element` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `element id`.

4. If `element` is not
 [editable](#dfn-editable), return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid element
 state](#dfn-invalid-element-state).

5. [Scroll into
 view](#dfn-scrolls-into-view) the `element`.

6. Let `timeout` be `session`\'s [session
 timeouts](#dfn-session-timeouts)\' [implicit wait
 timeout](#dfn-implicit-wait-timeout).

7. Let `timer` be a new
 [timer](#dfn-timer).

8. If `timeout` is not null:

 1. [Start the
 timer](#dfn-start-the-timer) with `timer` and
 `timeout`.

9. Wait for `element` to become
 [interactable](#dfn-interactable), or `timer`\'s [timeout
 fired
 flag](#dfn-timeout-fired-flag) to be set, whichever
 occurs first.

10. If `element` is not
 [interactable](#dfn-interactable), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [element not
 interactable](#dfn-element-not-interactable).

11. Run the substeps of the first matching statement:

 `element` is a [mutable form control element](#dfn-mutable-form-control-element)

 : Invoke the steps to [clear a resettable
 element](#dfn-clear-a-resettable-element).

 `element` is a [mutable element](#dfn-mutable-element)

 : Invoke the steps to [clear a content editable
 element](#dfn-clear-a-content-editable-element).

 Otherwise

 : Return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid element
 state](#dfn-invalid-element-state).

12. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
#### 12.5.3 [Element Send Keys]

------------- ----------------------------------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/element/{`element id`}/value
 ------------- ----------------------------------------------------------------------------

The [Element Send
Keys](#dfn-element-send-keys)
[command](#dfn-commands) [scrolls into
view](#dfn-scrolls-into-view) the form control
[element](https://dom.spec.whatwg.org/#concept-element) and then sends the provided keys to the
[element](https://dom.spec.whatwg.org/#concept-element). In case the
[element](https://dom.spec.whatwg.org/#concept-element) is not
[keyboard-interactable](#dfn-keyboard-interactable), an [element not
interactable](#dfn-element-not-interactable) [error](#dfn-error) is returned.

A [non-typeable form control] is an [`input`](#dfn-input) element whose
[`type`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type) attribute state causes the primary input
mechanism not to be through means of a keyboard, whether virtual or
physical.

[Non-typeable form
controls](#dfn-non-typeable-form-control) means to refer to form control elements
rendered by the user agent as something other than as a text input
control. When targetting an [`input`](#dfn-input) element in the [`color`
state](#dfn-color-state) being presented as a color wheel,
[interaction](#dfn-element-send-keys) with it will be
simulated, rather than typed using key emulation with
[actions](#actions).

Other examples of [non-typeable form
controls](#dfn-non-typeable-form-control) include form controls interacted with via
system-native widgets, such as a scrolled option list for
[`select`](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element) elements and a number keypad for
[`input`](#dfn-input) elements in the [`number`
state](#dfn-number-state) on non-desktop devices.

The [key input
source](#dfn-key-input-source) used for input may be cleared mid-way
through "typing" by sending the [null key], which is U+E000
(NULL).

To [clear the modifier key state] given
`input state`, `input id`, `source`,
`undo actions`, and `browsing context`:

1. If `source` is not a [key input
 source](#dfn-key-input-source) return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

2. Let `actions options` be a new [actions
 options](#dfn-actions-options) with the [is element
 origin](#dfn-is-element-origin) steps set to [represents a web
 element](#dfn-represents-a-web-element), and the [get element
 origin](#dfn-get-element-origin) steps set to [get a WebElement
 origin](#dfn-get-a-webelement-origin).

3. For each `entry key` in the lexically sorted keys of
 `undo actions`:

 1. Let `action` be the value of
 `undo actions` equal to the key
 `entry key`.

 2. If `action` is not an [action
 object](#dfn-action-object) with type \"`key`\" and subtype
 \"`keyUp`\", return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 3. Let `actions` be the list «`action`»

 4. [Dispatch a list of
 actions](#dfn-dispatch-a-list-of-actions) with `input state`,
 `actions`, `browsing context`, and
 [actions
 options](#dfn-actions-options).

An [extended grapheme
cluster](#dfn-grapheme-cluster) is [typeable] if it consists of a
single [unicode code
point](#dfn-unicode-code-point) and the
[code](#dfn-code) is
not [undefined](#dfn-undefined).

The [shifted state] for `keyboard` is the
value of `keyboard`\'s `shift` property.

To [dispatch the events for a typeable
string] given `input state`,
`input id`, `source`, `text`, and
`browsing context`:

1. Let `actions options` be a new [actions
 options](#dfn-actions-options) with the [is element
 origin](#dfn-is-element-origin) steps set to [represents a web
 element](#dfn-represents-a-web-element), and the [get element
 origin](#dfn-get-element-origin) steps set to [get a WebElement
 origin](#dfn-get-a-webelement-origin).

2. For each `char` of `text`:
 1. Let `global key state` be the result of [get the
 global key
 state](#dfn-get-the-global-key-state) with `input state`.

 2. If `char` is a [shifted
 character](#dfn-shifted-character), and the [shifted
 state](#dfn-shifted-state) of `source` is false:

 1. Let `action` be an [action
 object](#dfn-action-object) constructed with
 `input id`, \"`key`\", and \"`keyDown`\", and set
 its `value` property to U+E008 (\"left shift\").

 2. Let `actions` be the list «`action`».

 3. [Dispatch a list of
 actions](#dfn-dispatch-a-list-of-actions) with `input state`,
 `actions`, and `browsing context`.

 3. If `char` is not a [shifted
 character](#dfn-shifted-character) and the [shifted
 state](#dfn-shifted-state) of `source` is true:

 1. Let `action` be an [action
 object](#dfn-action-object) constructed with
 `input id`, \"`key`\", and \"`keyUp`\", and set
 its `value` property to U+E008 (\"left shift\").

 2. Let `tick actions` be the list
 «`action`».

 3. [Dispatch a list of
 actions](#dfn-dispatch-a-list-of-actions) with `input state`,
 `actions`, `browsing context`, and
 `actions options`.

 4. Let `keydown action` be an [action
 object](#dfn-action-object) constructed with arguments
 `input id`, \"`key`\", and \"`keyDown`\".

 5. Set the `value` property of `keydown action` to
 `char`.

 6. Let `keyup action` be a copy of
 `keydown action` with the subtype property changed to
 \"`keyUp`\".

 7. Let `actions` be the list
 «`keydown action`, `keyup action`».

 8. [Dispatch a list of
 actions](#dfn-dispatch-a-list-of-actions) with `input state`,
 `actions`, `browsing context`, and
 `actions options`.

When required to [dispatch a composition
event] given `type` and
`cluster`, and `browsing context`, the [remote
end](#dfn-remote-ends) must [perform implementation-specific action dispatch
steps](#dfn-perform-implementation-specific-action-dispatch-steps) on `browsing context`
equivalent to sending composition events in accordance with the
requirements of \[[UI-EVENTS](#bib-ui-events "UI Events")\], and producing the following event with the
specified properties.

- [`composition event`](https://www.w3.org/TR/uievents/#events-compositionevents)
 with properties:
 ----------- ----------------------
 Attribute Value
 `type` `type`
 `data` `cluster`
 ----------- ----------------------

To [dispatch actions for a string] given
`input state`, `input id`, `source`,
`text`, `browsing context`, and
`actions options`:

1. Let `clusters` be an array created by [breaking
 `text` into extended grapheme
 clusters](#dfn-breaking-text-into-extended-grapheme-clusters).

2. Let `undo actions` be an empty map.

3. Let `current typeable text` be an empty list.

4. For each `cluster` corresponding to an indexed property
 in `clusters` run the substeps of the first matching
 statement:

 `cluster` is the [null key](#dfn-null-key)

 : 1. [Dispatch the events for a typeable
 string](#dfn-dispatch-the-events-for-a-typeable-string) with `input state`,
 `input id`, `source`,
 `current typeable text`, and
 `browsing context`. Empty
 `current typeable text`.

 2. [Try](#dfn-try) to [clear the modifier key
 state](#dfn-clear-the-modifier-key-state) with `input state`,
 `input id`, `source`,
 `undo actions` and `browsing context`.

 3. Clear `undo actions`.

 `cluster` is a [modifier key](#dfn-modifier-key)

 : 1. [Dispatch the events for a typeable
 string](#dfn-dispatch-the-events-for-a-typeable-string) with `input state`,
 `input id`, `source`,
 `current typeable text`, and
 `browsing context`.

 2. Empty`current typeable text`.

 3. Let `keydown action` be an [action
 object](#dfn-action-object) constructed with arguments
 `input id`, \"`key`\", and \"`keyDown`\".

 4. Set the `value` property of `keydown action` to
 `cluster`.

 5. Let `actions` be the list
 «`keydown action`»

 6. [Dispatch a list of
 actions](#dfn-dispatch-a-list-of-actions) with `input state`,
 `actions`, `browsing context`, and
 `actions options`.

 7. Add an entry to `undo actions` with key
 `cluster` and value being a copy of
 `keydown action` with the subtype property
 modified to \"`keyUp`\".

 `cluster` is [typeable](#dfn-typeable)

 : Append `cluster` to
 `current typeable text`.

 Otherwise

 : 1. [Dispatch the events for a typeable
 string](#dfn-dispatch-the-events-for-a-typeable-string) with `input state`,
 `input id`, `source`,
 `current typeable text`, and
 `browsing context`.

 2. Empty `current typeable text`.

 3. [Dispatch a
 `composition event`](#dfn-dispatch-a-composition-event) with arguments
 \"`compositionstart`\",
 [undefined](#dfn-undefined), and
 `browsing context`.

 4. [Dispatch a
 `composition event`](#dfn-dispatch-a-composition-event) with arguments
 \"`compositionupdate`\", `cluster`, and
 `browsing context`.

 5. [Dispatch a
 `composition event`](#dfn-dispatch-a-composition-event) with arguments
 \"`compositionend`\", `cluster`, and
 `browsing context`.

5. [Dispatch the events for a typeable
 string](#dfn-dispatch-the-events-for-a-typeable-string) with `input state`,
 `input id` and `source`,
 `current typeable text`, and
 `browsing context`.

6. [Try](#dfn-try) to
 [clear the modifier key
 state](#dfn-clear-the-modifier-key-state) with `input state`,
 `input id`, `source`,
 `undo actions`, and `browsing context`.

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `text` be the result of [getting a
 property](#dfn-getting-properties) named \"`text`\" from
 `parameters`.

2. If `text` is not a
 [String](#dfn-string), return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

4. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

5. Let `element` be the result of
 [trying](#dfn-try)
 to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `URL variables`\[`element id`\].

6. Let `file` be true if `element` is
 [`input`](#dfn-input) element in the [file upload
 state](#dfn-file-upload-state), or false otherwise.

7. If `file` is false or the
 [session](#dfn-sessions)\'s [strict file
 interactability](#dfn-strict-file-interactability), is true run the following substeps:

 1. [Scroll into
 view](#dfn-scrolls-into-view) the `element`.

 2. Let `timeout` be `session`\'s [session
 timeouts](#dfn-session-timeouts)\' [implicit wait
 timeout](#dfn-implicit-wait-timeout).

 3. Let `timer` be a new
 [timer](#dfn-timer).

 4. If `timeout` is not null:

 1. [Start the
 timer](#dfn-start-the-timer) with `timer` and
 `timeout`.

 5. Wait for `element` to become
 [keyboard-interactable](#dfn-keyboard-interactable), or `timer`\'s [timeout
 fired
 flag](#dfn-timeout-fired-flag) to be set, whichever
 occurs first.

 6. If `element` is not
 [keyboard-interactable](#dfn-keyboard-interactable), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [element not
 interactable](#dfn-element-not-interactable).

 7. If `element` is not the [active
 element](#dfn-active-element) run the [focusing
 steps](#dfn-focusing-steps) for the `element`.

8. Run the substeps of the first matching condition:

 `file` is true

 : 1. Let `files` be the result of splitting
 `text` on the newline (`\n`) character.

 2. If `files` is of 0 length, return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 3. Let `multiple` equal the result of calling
 [`hasAttribute`](https://dom.spec.whatwg.org/#dom-element-hasattribute)`()` with
 \"multiple\" on `element`.

 4. if `multiple` is `false` and the length of
 `files` is not equal to 1, return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 5. Verify that each file given by the user exists. If any do
 not, return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 6. Complete implementation specific steps equivalent to setting
 the [selected
 files](#dfn-selected-files) on the
 [`input`](#dfn-input) element. If `multiple` is
 `true` `files` are be appended to
 `element`\'s [selected
 files](#dfn-selected-files).

 7. [Fire](https://dom.spec.whatwg.org/#concept-event-fire) these events in order on
 `element`:

 1. [`input`](#dfn-input)
 2. [`change`](#dfn-change)

 8. Return [success](#dfn-success) with data
 [`null`](#dfn-null).

 [`element`](https://dom.spec.whatwg.org/#concept-element) is a [non-typeable form control](#dfn-non-typeable-form-control)

 : 1. If `element` does not have an [own
 property](#dfn-own-properties) named `value` return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [element not
 interactable](#dfn-element-not-interactable)

 2. If `element` is not
 [mutable](#dfn-mutable) return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [element not
 interactable](#dfn-element-not-interactable).

 3. [Set a
 property](#dfn-set-a-property) `value` to `text`
 on `element`.

 4. If `element` is [suffering from bad
 input](#dfn-suffering-from-bad-input) return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 5. Return [success](#dfn-success) with data
 [`null`](#dfn-null).

 [`element`](https://dom.spec.whatwg.org/#concept-element) is [content editable](#dfn-content-editable)
 : If
 [`element`](https://dom.spec.whatwg.org/#concept-element) does not currently have focus, set the text
 insertion caret after any child content.

 Otherwise

 : 1. If `element` does not currently have focus, let
 `current text length` be the
 [length](https://infra.spec.whatwg.org/#string-length) of
 [`element`](https://dom.spec.whatwg.org/#concept-element)\'s [API
 value](#dfn-api-value).

 2. Set the text insertion caret using [set selection
 range](#dfn-set-selection-range) using
 `current text length` for both the `start` and
 `end` parameters.

9. Let `input state` be the result of [get the input
 state](#dfn-get-the-input-state) with `session` and
 `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context).

10. Let `input id` be a the result of [generating a
 UUID](#dfn-generating-a-uuid).

11. Let `source` be the result of [create an input
 source](#dfn-create-an-input-source) with `input state`, and
 \"`key`\".

12. [Add an input
 source](#dfn-add-an-input-source) with `input state`,
 `input id` and `source`.

13. [Dispatch actions for a
 string](#dfn-dispatch-actions-for-a-string) with arguments
 `input state`, `input id`, and
 `source`, `text`, and `session`\'s
 [current browsing
 context](#dfn-current-browsing-context).

14. [Remove an input
 source](#dfn-remove-an-input-source) with `input state` and
 `input id`.

15. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
## 13. Document

::: header-wrapper
### 13.1 [Get Page Source]

------------- -------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/source
 ------------- -------------------------------------------

The [Get Page
Source](#dfn-get-page-source)
[command](#dfn-commands) returns a string serialization of the DOM of
`session`\'s [current browsing
context](#dfn-current-browsing-context) [active
document](#dfn-active-document).

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `source` be the result of invoking the [fragment
 serializing
 algorithm](#dfn-fragment-serializing-algorithm) on a fictional node whose only child
 is the [document
 element](https://dom.spec.whatwg.org/#document-element) providing `true` for the `require well-formed`
 flag. If this causes an exception to be thrown, let
 `source` be [`null`](#dfn-null).

4. Let `source` be the result of [serializing to
 string](#dfn-serializing-to-string) `session`\'s [current
 browsing
 context](#dfn-current-browsing-context)\'s [active
 document](#dfn-active-document), if `source` is
 [`null`](#dfn-null).

5. Return [success](#dfn-success) with data `source`.

::: header-wrapper
### 13.2 Executing Script

A [collection] is an [Object](#dfn-object) that implements the
[Iterable](#dfn-iterable) interface, and whose:

- [initial value](#dfn-initial-value) of the `toString` [own
 property](#dfn-own-properties) is \"`Arguments`\"
- instance of [`Array`](#dfn-array)
- instance of
 [`DOMTokenList`](https://dom.spec.whatwg.org/#domtokenlist)
- instance of
 [`FileList`](https://www.w3.org/TR/FileAPI/#dfn-filelist)
- instance of
 [`HTMLAllCollection`](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#htmlallcollection)
- instance of
 [`HTMLCollection`](https://dom.spec.whatwg.org/#htmlcollection)
- instance of
 [`HTMLFormControlsCollection`](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#htmlformcontrolscollection)
- instance of
 [`HTMLOptionsCollection`](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#htmloptionscollection)
- instance of
 [`NodeList`](https://dom.spec.whatwg.org/#nodelist)

To [JSON deserialize] given `session`,
`value` and optional argument `seen`, a [remote
end](#dfn-remote-ends) must run the following steps:

1. If `seen` is not provided, let `seen` be an
 empty [List](#dfn-list).

2. Jump to the first appropriate step below:

3. Matching on `value`:

 [undefined](#dfn-undefined)\
 [`null`](#dfn-null)\
 type [Boolean](#dfn-boolean)\
 type [Number](#dfn-number)\
 type [String](#dfn-string)

 : Return [success](#dfn-success) with data `value`.

 [Object](#dfn-object) that [represents a web element](#dfn-represents-a-web-element)

 : Return the
 [deserialized](#dfn-deserialize-a-web-element)
 [web element](#dfn-web-elements) of `value`.

 [Object](#dfn-object) that [represents a shadow root](#dfn-represents-a-shadow-root)

 : Return the
 [deserialized](#dfn-deserialize-a-shadow-root)
 [shadow root](#dfn-shadow-roots) of `value`.

 [Object](#dfn-object) that [represents a web frame](#dfn-represents-a-web-frame)

 : Return the
 [deserialized](#dfn-deserialize-a-web-frame) [web
 frame](#dfn-web-frames) of `value`.

 [Object](#dfn-object) that [represents a web window](#dfn-represents-a-web-window)

 : Return the
 [deserialized](#dfn-deserialize-a-web-window) [web
 window](#dfn-web-windows) of `value`.

 instance of [Array](#dfn-array)\
 instance of [Object](#dfn-object)

 : Return [clone an
 object](#dfn-clone-an-object) algorithm with
 `session`, `value` and `seen`,
 and the [JSON
 deserialize](#dfn-json-deserialize) algorithm as the clone algorithm.

To [JSON clone] given `session` and `value`,
return the result of [internal JSON
clone](#dfn-internal-json-clone) with `session`,
`value` and an empty [List](#dfn-list).

To [internal JSON clone] given `session`,
`value` and `seen`, return the value of the first
matching statement, matching on `value`:

[undefined](#dfn-undefined)\
[`null`](#dfn-null)

: Return [success](#dfn-success) with data [`null`](#dfn-null).

type [Boolean](#dfn-boolean)\
type [Number](#dfn-number)\
type [String](#dfn-string)

: Return [success](#dfn-success) with data `value`.

instance of [`Element`](https://dom.spec.whatwg.org/#element)

: If the `element` [is
 stale](#dfn-is-stale), return [error](#dfn-error) with [error
 code](#dfn-error-code) [stale element
 reference](#dfn-stale-element-reference).

 Otherwise:

 1. Let `reference` be the [web element reference
 object](#dfn-web-element-reference-object) for `session` and
 `value`.

 2. Return [success](#dfn-success) with data `reference`.

instance of [`ShadowRoot`](https://dom.spec.whatwg.org/#shadowroot)

: If the `shadow root` [is
 detached](#dfn-is-detached), return [error](#dfn-error) with [error
 code](#dfn-error-code) [detached shadow
 root](#dfn-detached-shadow-root).

 Otherwise:

 1. Let `reference` be the [shadow root reference
 object](#dfn-shadow-root-reference-object) for `session` and
 `value`.

 2. Return [success](#dfn-success) with data `reference`.

a [`WindowProxy`](#dfn-windowproxy) object

: If the associated [browsing
 context](#dfn-browsing-contexts) of the
 [`WindowProxy`](#dfn-windowproxy) object in `value` has been
 destroyed, return [error](#dfn-error) with [error
 code](#dfn-error-code) [stale element
 reference](#dfn-stale-element-reference).

 Otherwise:

 1. Let `reference` be the [`WindowProxy` reference
 object](#dfn-windowproxy-reference-object) for `value`.

 2. Return [success](#dfn-success) with data `reference`.

has an [own property](#dfn-own-properties) named \"`toJSON`\" that is a [Function](#dfn-function)
: Return [success](#dfn-success) with the value returned by
 [Function.\[\[Call\]\]](#dfn-call)(`toJSON`) with `value` as the this
 value.

Otherwise

: 1. Let `result` be [clone an
 object](#dfn-clone-an-object) with `session`
 `value` and `seen`, and [internal JSON
 clone](#dfn-internal-json-clone) as the
 `clone algorithm`.

 2. Return [success](#dfn-success) with data `result`.

To [clone an object], given `session`,
`value`, `seen`, and `clone algorithm`:

1. If `value` is in `seen`, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [javascript
 error](#dfn-javascript-error).

2. Append `value` to `seen`.

3. Let `result` be the value of the first matching
 statement, matching on `value`:

 a [collection](#dfn-collection)

 : A new [Array](#dfn-array) which `length` property is equal to the result
 of [getting the
 property](#dfn-getting-properties) `length` of `value`.

 Otherwise

 : A new [Object](#dfn-object).

4. For each enumerable property in `value`, run the
 following substeps:

 1. Let `name` be the name of the property.

 2. Let `source property value` be the result of [getting
 a
 property](#dfn-getting-properties) named `name` from
 `value`. If doing so causes script to be run and that
 script throws an error, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [javascript
 error](#dfn-javascript-error).

 3. Let `cloned property result` be the result of calling
 the `clone algorithm` with `session`,
 `source property value` and `seen`.

 4. If `cloned property result` is a
 [success](#dfn-success), [set a
 property](#dfn-set-a-property) of `result` with name
 `name` and value equal to
 `cloned property result`\'s data.

 5. Otherwise, return `cloned property result`.

5. Remove the last element of `seen`.

6. Return [success](#dfn-success) with data `result`.

When required to [extract the script arguments from a
request] with argument
`parameters` the implementation must:

1. Let `script` be the result of [getting a
 property](#dfn-getting-properties) named \"`script`\" from
 `parameters`.

2. If `script` is not a
 [String](#dfn-string), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Let `args` be the result of [getting a
 property](#dfn-getting-properties) named \"`args`\" from
 `parameters`.

4. If `args` is not an
 [Array](#dfn-array) return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

5. Let `arguments` be [JSON
 deserialize](#dfn-json-deserialize) with `session` and
 `args`.

6. Return [success](#dfn-success) with data `script` and
 `arguments`.

The rules to [execute a function body] are as follows. The
algorithm returns [an ECMAScript completion
record](#dfn-completion).

If at any point during the algorithm a [user
prompt](#dfn-user-prompts) appears, immediately return
[Completion](#dfn-completion) { \[\[Type\]\]: `normal`, \[\[Value\]\]:
[`null`](#dfn-null),
\[\[Target\]\]: `empty` }, but continue to run the other steps of this
algorithm [in
parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

1. Let `window` be the [associated
 window](#dfn-associated-window) of `session`\'s [current
 browsing
 context](#dfn-current-browsing-context)\'s [active
 document](#dfn-active-document).

2. Let `environment settings` be `window`\'s
 [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

3. Let `global scope` be `environment settings`
 [realm](#dfn-realm)\'s [global
 environment](#dfn-global-environment).

4. If `body` is not parsable as a
 [FunctionBody](#dfn-functionbody) or if parsing detects an [early
 error](#dfn-early-error), return
 [Completion](#dfn-completion) { \[\[Type\]\]: `normal`, \[\[Value\]\]:
 [`null`](#dfn-null), \[\[Target\]\]: `empty` }.

5. If `body` begins with a [directive
 prologue](#dfn-directive-prologue) that contains a [use strict
 directive](#dfn-use-strict-directive) then let `strict` be true,
 otherwise let `strict` be false.

6. [Prepare to run
 script](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-script) with `environment settings`.

7. [Prepare to run a
 callback](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-a-callback) with `environment settings`.

8. Let `function` be the result of calling
 [FunctionCreate](#dfn-functioncreate), with arguments:

 `kind`
 : Normal.

 `list`
 : An empty [List](#dfn-list).

 `body`
 : The result of parsing `body` above.

 `global scope`
 : The result of parsing `global scope` above.

 `strict`
 : The result of parsing `strict` above.

9. Let `completion` be
 [Function.\[\[Call\]\]](#dfn-call)(`window`, `parameters`) with
 `function` as the this value.

10. [Clean up after running a
 callback](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-a-callback) with `environment settings`.

11. [Clean up after running
 script](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-script) with `environment settings`.

12. Return `completion`.

The above algorithm is not associated with any particular element, and
is therefore not subject to the document CSP
[directives](#dfn-directives).

::: header-wrapper
#### 13.2.1 [Execute Script]

------------- -------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/execute/sync
 ------------- -------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `body` and `arguments` be the result of
 [trying](#dfn-try)
 to [extract the script arguments from a
 request](#dfn-extract-the-script-arguments-from-a-request) with argument `parameters`.

2. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

3. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

4. Let `timeout` be `session`\'s [session
 timeouts](#dfn-session-timeouts)\' [script
 timeout](#dfn-script-timeout).

5. Let `timer` be a new
 [timer](#dfn-timer).

6. If `timeout` is not null:

 1. [Start the
 timer](#dfn-start-the-timer) with `timer` and
 `timeout`.

7. Let `promise` be [a new
 Promise](https://webidl.spec.whatwg.org/#a-new-promise).

8. Run the following substeps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `scriptPromise` be the result of
 [promise-calling](#dfn-promise-call) [execute a function
 body](#dfn-execute-a-function-body), with arguments `body`
 and `arguments`.

 2. Upon fulfillment of `scriptPromise` with value
 `v`,
 [resolve](https://webidl.spec.whatwg.org/#resolve) `promise` with value `v`.

 3. Upon rejection of `scriptPromise` with value
 `r`,
 [reject](https://webidl.spec.whatwg.org/#reject) `promise` with value `r`.

9. Wait until `promise` is resolved, or
 `timer`\'s [timeout fired
 flag](#dfn-timeout-fired-flag) is set, whichever occurs
 first.

10. If `promise` is still pending and `timer`\'s
 [timeout fired
 flag](#dfn-timeout-fired-flag) is set, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [script
 timeout](#dfn-script-timeout-error).

11. If `promise` is fulfilled with value `v`, let
 `result` be [JSON
 clone](#dfn-json-clone) with `session` and `v`, and
 return [success](#dfn-success) with data `result`.

12. If `promise` is rejected with reason `r`, let
 `result` be [JSON
 clone](#dfn-json-clone) with `session` and `r`, and
 return [error](#dfn-error) with [error
 code](#dfn-error-code) [javascript
 error](#dfn-javascript-error) and data `result`.

::: header-wrapper
#### 13.2.2 [Execute Async Script]

------------- --------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/execute/async
 ------------- --------------------------------------------------

The [Execute Async
Script](#dfn-execute-async-script)
[command](#dfn-commands) causes JavaScript to execute as an anonymous function.
An additional value is provided as the final argument to the function.
This is a function that may be invoked to signal the completion of the
asynchronous operation. The first argument provided to the function will
be serialized to JSON and returned by [Execute Async
Script](#dfn-execute-async-script).

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `body` and `arguments` by the result of
 [trying](#dfn-try)
 to [extract the script arguments from a
 request](#dfn-extract-the-script-arguments-from-a-request) with argument `parameters`.

2. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

3. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

4. Let `timeout` be `session`\'s [session
 timeouts](#dfn-session-timeouts)\' [script
 timeout](#dfn-script-timeout).

5. Let `timer` be a new
 [timer](#dfn-timer).

6. If `timeout` is not null:

 1. [Start the
 timer](#dfn-start-the-timer) with `timer` and
 `timeout`.

7. Let `promise` be [a new
 Promise](https://webidl.spec.whatwg.org/#a-new-promise).

8. Run the following substeps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `resolvingFunctions` be
 [CreateResolvingFunctions](#dfn-createresolvingfunctions)(`promise`).

 2. Append `resolvingFunctions``.[[Resolve]]` to
 `arguments`.

 3. Let `scriptResult` be the result of calling [execute
 a function
 body](#dfn-execute-a-function-body), with arguments `body`
 and `arguments`.

 4. If `scriptResult`.\[\[Type\]\] is not `normal`, then
 [reject](https://webidl.spec.whatwg.org/#reject) `promise` with value
 `scriptResult`.\[\[Value\]\], and abort these steps.

 ::::
 :::
 Note
 :::

 Prior revisions of this specification did not recognize the
 return value of the provided script. In order to preserve legacy
 behavior, the return value only influences the command if it is
 a \"thenable\" object or if determining this produces an
 exception.
 ::::

 5. If [Type](#dfn-ecmascript-type)(`scriptResult`.\[\[Value\]\]) is not
 [Object](#dfn-object), then abort these steps.

 6. Let `then` be [Get](#dfn-get)(`scriptResult`.\[\[Value\]\],
 \"then\").

 7. If `then`.\[\[Type\]\] is not `normal`, then
 [reject](https://webidl.spec.whatwg.org/#reject) `promise` with value
 `then`.\[\[Value\]\], and abort these steps.

 8. If [IsCallable](#dfn-iscallable)(`then`.\[\[Type\]\]) is
 `false`, then abort these steps.

 9. Let `scriptPromise` be
 [PromiseResolve](#dfn-promiseresolve)([Promise](#dfn-promise),
 `scriptResult`.\[\[Value\]\]).

 10. Upon fulfillment of `scriptPromise` with value
 `v`,
 [resolve](https://webidl.spec.whatwg.org/#resolve) `promise` with value `v`.

 11. Upon rejection of `scriptPromise` with value
 `r`,
 [reject](https://webidl.spec.whatwg.org/#reject) `promise` with value `r`.

9. Wait until `promise` is resolved, or
 `timer`\'s [timeout fired
 flag](#dfn-timeout-fired-flag) is set, whichever occurs
 first.

10. If `promise` is still pending and `timer`\'s
 [timeout fired
 flag](#dfn-timeout-fired-flag) is set, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [script
 timeout](#dfn-script-timeout-error).

11. If `promise` is fulfilled with value `v`, let
 `result` be [JSON
 clone](#dfn-json-clone) with `session` and `v`, and
 return [success](#dfn-success) with data `result`.

12. If `promise` is rejected with reason `r`, let
 `result` be [JSON
 clone](#dfn-json-clone) with `session` and `r`, and
 return [error](#dfn-error) with [error
 code](#dfn-error-code) [javascript
 error](#dfn-javascript-error) and data `result`.

::: header-wrapper
## 14. Cookies

This section describes the interaction with
[cookies](#dfn-cookies) as described in
\[[RFC6265](#bib-rfc6265 "HTTP State Management Mechanism")\].

A [cookie](#dfn-cookies) is described in
\[[RFC6265](#bib-rfc6265 "HTTP State Management Mechanism")\] by a name-value pair holding the cookie\'s data,
followed by zero or more attribute-value pairs describing its
characteristics.

The following [table for cookie
conversion] defines the cookie concepts
relevant to WebDriver, how these are referred to in
\[[RFC6265](#bib-rfc6265 "HTTP State Management Mechanism")\], what keys they map to in a [serialized
cookie](#dfn-serialized-cookie), as well as the attribute-value keys
needed when constructing a list of arguments for [creating a
cookie](#dfn-creating-a-cookie).

For informational purposes, the table includes a legend of whether the
field is optional in the [serialized
cookie](#dfn-serialized-cookie) provided to [Add
Cookie](#dfn-adding-a-cookie), and a brief non-normative description of
the field and the expected input type of its associated value.

 ------------------------------------------------------------------------------------------------------- -------------------- ---------------- ---------------- ---------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Concept RFC 6265 Field JSON Key Attribute Key Optional Description
 [Cookie name] `name` \"`name`\" The name of the cookie.
 [Cookie value] `value` \"`value`\" The cookie value.
 [Cookie path] `path` \"`path`\" \"`Path`\" ✓ The cookie path. Defaults to \"`/`\" if omitted when [adding a cookie](#dfn-adding-a-cookie).
 [Cookie domain] `domain` \"`domain`\" \"`Domain`\" ✓ The domain the cookie is visible to. Defaults to `session`\'s [current browsing context](#dfn-current-browsing-context)\'s [active document](#dfn-active-document)\'s [URL](#dfn-url) [domain](#dfn-domains) if omitted when [adding a cookie](#dfn-adding-a-cookie).
 [Cookie secure only] `secure-only-flag` \"`secure`\" \"`Secure`\" ✓ Whether the cookie is a secure cookie. Defaults to false if omitted when [adding a cookie](#dfn-adding-a-cookie).
 [Cookie HTTP only] `http-only-flag` \"`httpOnly`\" \"`HttpOnly`\" ✓ Whether the cookie is an HTTP only cookie. Defaults to false if omitted when [adding a cookie](#dfn-adding-a-cookie).
 [Cookie expiry time] `expiry-time` \"`expiry`\" \"`Max-Age`\" ✓ When the cookie expires, specified in seconds since [Unix Epoch](#dfn-unix-timestamp). Must not be set if omitted when [adding a cookie](#dfn-adding-a-cookie).
 [Cookie same site] `samesite` \"`sameSite`\" \"`SameSite`\" ✓ Whether the cookie applies to a SameSite policy. Defaults to None if omitted when [adding a cookie](#dfn-adding-a-cookie). Can be set to either [`Lax`](#dfn-lax) or [`Strict`](#dfn-strict).
 ------------------------------------------------------------------------------------------------------- -------------------- ---------------- ---------------- ---------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

A [serialized cookie] is a JSON
[Object](#dfn-object) where a [cookie](#dfn-cookies)\'s
\[[RFC6265](#bib-rfc6265 "HTTP State Management Mechanism")\] fields listed in the [table for cookie
conversion](#dfn-table-for-cookie-conversion) are mapped using the *JSON Key* and the
associated field\'s value from the [cookie
store](#dfn-cookie-store). The optional fields may be omitted.

To get [all associated cookies] to a
[document](https://dom.spec.whatwg.org/#concept-document), the user agent must return the enumerated set of
[cookies](#dfn-cookies) that meet the requirements set out in the first step of
the algorithm in
\[[RFC6265](#bib-rfc6265 "HTTP State Management Mechanism")\] to [compute
`cookie-string`](#dfn-compute-cookie-string) for an 'HTTP API\', from the [cookie
store](#dfn-cookie-store) of the given
[document](https://dom.spec.whatwg.org/#concept-document)\'s
[address](https://html.spec.whatwg.org/multipage/sections.html#the-address-element). The returned cookies must include [HttpOnly
cookies](#dfn-cookie-http-only).

When the [remote end](#dfn-remote-ends) is instructed to [create a
cookie], this is synonymous to carrying
out the steps described in
\[[RFC6265](#bib-rfc6265 "HTTP State Management Mechanism")\] [section
5.3](https://tools.ietf.org/html/rfc6265#section-5.3), under [receiving
a cookie](#dfn-receiving-a-cookie), except the user agent may not ignore the
received cookie in its entirety (disregard step 1).

To [delete cookies] given an optional filter argument
`name` that is a string:

1. For each [cookie](#dfn-cookies) among [all associated
 cookies](#dfn-associated-cookies) of `session`\'s [current
 browsing
 context](#dfn-current-browsing-context)\'s [active
 document](#dfn-active-document), run the substeps of the first
 matching condition:

 `name` is [undefined](#dfn-undefined)\
 `name` is equal to [cookie name](#dfn-cookie-name)

 : Set the [cookie expiry
 time](#dfn-cookie-expiry-time) to a [Unix
 timestamp](#dfn-unix-timestamp) in the past.

 Otherwise
 : Do nothing.

::: header-wrapper
### 14.1 [Get All Cookies]

------------- -------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/cookie
 ------------- -------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `cookies` be a new
 [List](#dfn-list).

4. For each `cookie` in [all associated
 cookies](#dfn-associated-cookies) of `session`\'s [current
 browsing
 context](#dfn-current-browsing-context)\'s [active
 document](#dfn-active-document):

 1. Let `serialized cookie` be the result of
 [serializing](#dfn-serialized-cookie)
 `cookie`.

 2. Append `serialized cookie` to `cookies`

5. Return [success](#dfn-success) with data `cookies`.

::: header-wrapper
### 14.2 [Get Named Cookie]

------------- ---------------------------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/cookie/{`name`}
 ------------- ---------------------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. If the `URL variables`\[\"`name`\" is equal to a
 [cookie](#dfn-cookies)\'s [cookie
 name](#dfn-cookie-name) amongst [all associated
 cookies](#dfn-associated-cookies) of `session`\'s [current
 browsing
 context](#dfn-current-browsing-context)\'s [active
 document](#dfn-active-document), return
 [success](#dfn-success) with the [serialized
 cookie](#dfn-serialized-cookie) as data.

 Otherwise, return [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 cookie](#dfn-no-such-cookie).

::: header-wrapper
### 14.3 [Add Cookie]

------------- -------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/cookie
 ------------- -------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `data` be the result of [getting a
 property](#dfn-getting-properties) named \"`cookie`\" from
 `parameters`.

2. If `data` is not a JSON
 [Object](#dfn-object) with all the required (non-optional) JSON keys
 listed in the [table for cookie
 conversion](#dfn-table-for-cookie-conversion), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

4. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

5. If `session`\'s [current browsing
 context](#dfn-current-browsing-context)\'s [document
 element](https://dom.spec.whatwg.org/#document-element) is a [cookie-averse `Document`
 object](#dfn-cookie-averse-document-object), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid cookie
 domain](#dfn-invalid-cookie-domain).

6. If [cookie name](#dfn-cookie-name) or [cookie
 value](#dfn-cookie-value) is [`null`](#dfn-null), [cookie
 domain](#dfn-cookie-domain) is not equal to
 `session`\'s [current browsing
 context](#dfn-current-browsing-context)\'s [active
 document](#dfn-active-document)\'s
 [domain](#dfn-domains), [cookie secure
 only](#dfn-cookie-secure-only) or [cookie HTTP
 only](#dfn-cookie-http-only) are not boolean types, or [cookie
 expiry
 time](#dfn-cookie-expiry-time) is not an integer type, or it less
 than 0 or greater than the [maximum safe
 integer](#dfn-maximum-safe-integer), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

7. [Create a
 cookie](#dfn-creating-a-cookie) in the [cookie
 store](#dfn-cookie-store) associated with the [active
 document](#dfn-active-document)\'s
 [address](https://html.spec.whatwg.org/multipage/sections.html#the-address-element) using [cookie
 name](#dfn-cookie-name) `name`, [cookie
 value](#dfn-cookie-value) `value`, and an attribute-value list of
 the following cookie concepts listed in the [table for cookie
 conversion](#dfn-table-for-cookie-conversion) from `data`:

 [Cookie path](#dfn-cookie-path)

 : The value if the entry exists, otherwise \"`/`\".

 [Cookie domain](#dfn-cookie-domain)

 : The value if the entry exists, otherwise `session`\'s
 [current browsing
 context](#dfn-current-browsing-context)\'s [active
 document](#dfn-active-document)\'s
 [URL](#dfn-url)
 [domain](#dfn-domains).

 [Cookie secure only](#dfn-cookie-secure-only)

 : The value if the entry exists, otherwise false.

 [Cookie HTTP only](#dfn-cookie-http-only)

 : The value if the entry exists, otherwise false.

 [Cookie expiry time](#dfn-cookie-expiry-time)

 : The value if the entry exists, otherwise leave unset to indicate
 that this is a session cookie.

 ::::
 :::
 Note
 :::

 The cookie\'s expiry value might be limited by the remote end in
 accordance with the [Cookie Lifetime
 Limits](#dfn-cookie-lifetime-limits).
 ::::

 [Cookie same site](#dfn-cookie-same-site)

 : The value if the entry exists, otherwise leave unset to indicate
 that no same site policy is defined.

 If there is an [error](#dfn-error) during this step, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [unable to set
 cookie](#dfn-unable-to-set-cookie).

8. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
### 14.4 [Delete Cookie]

------------- ---------------------------------------------------------------
 HTTP Method URI Template
 DELETE /session/{`session id`}/cookie/{`name`}
 ------------- ---------------------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try) to
 [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. [Delete cookies](#dfn-delete-cookies) using the
 `URL variables`\[\"`name`\"\] as the filter argument.

4. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
### 14.5 [Delete All Cookies]

------------- -------------------------------------------
 HTTP Method URI Template
 DELETE /session/{`session id`}/cookie
 ------------- -------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try)
 to [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. [Delete cookies](#dfn-delete-cookies), giving no filtering argument.

4. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
## 15. [Actions]

The Actions API provides a low-level interface for providing virtualized
device input to the web browser. Conceptually, the Actions commands
divide time into a series of [ticks](#dfn-ticks). The [local
end](#dfn-local-ends) sends a series of actions which correspond to the
change in state, if any, of each input device during each
[tick](#dfn-ticks).
For example, pressing a key is represented by an action sequence
consisting of a single key input device and two
[ticks](#dfn-ticks),
the first containing a [keyDown](#dfn-keydown) action, and the second a
[keyUp](#dfn-keyup)
action, whereas a pinch-zoom input is represented by an action sequence
consisting of three [ticks](#dfn-ticks) and two pointer input devices of type
touch, each performing a sequence of actions
[pointerDown](#dfn-pointerdown), followed by
[pointerMove](#dfn-pointermove), and then
[pointerUp](#dfn-pointerup).

[Example 11](#example-11)

Imagine we have two fingers acting on a touchscreen. One finger will
press down on element1 at the same moment that another finger presses
down on element2. Once these actions are done, the first finger will
wait 5 seconds while the other finger moves to element3. Then both
fingers release from the touchscreen.

When the [remote end](#dfn-remote-ends) receives this, it will look at each [input
source](#dfn-input-source)\'s action lists. It will dispatch the first action of
each source together, then the second actions together, and lastly, the
final actions together.

The diagram below displays when each action gets executed. \"Source 1\"
is the first finger, and \"source 2\" is the second.

!(graphics/note1actions.svg)

There is no limit to the number of [input
sources](#dfn-input-source), and there is no restriction regarding the length of
each input\'s action list. This means, there is no requirement that all
action lists have to be the same length. It is possible for one [input
source](#dfn-input-source)\'s action list may have more actions than another.

In this case, the action list for the first finger contains 2 actions
([pointerDown](#dfn-pointerdown), [pointerUp](#dfn-pointerup)), and the action list for the second
finger contains 3
([pointerDown](#dfn-pointerdown),
[pointerMove](#dfn-pointermove), [pointerUp](#dfn-pointerup)).

And the execution of each action will be done as follows:

!(graphics/note4actions.svg)

Specific timing for the actions can also be expressed. The
[pause](#dfn-pause)
action can be used to either (a) indicate a specific amount of time an
[input source](#dfn-input-source) must wait, or (b) can be used to signify
that the current [input
source](#dfn-input-source) must wait until all other actions in the
[tick](#dfn-ticks)
are completed. For the former case, the current
[tick](#dfn-ticks)
being executed must wait for the longest pause to complete. For example,
in this diagram:

!(graphics/note2actions.svg)

The [remote end](#dfn-remote-ends) will dispatch the
[pointerDown](#dfn-pointerdown) action in the first
[tick](#dfn-ticks).
In the second [tick](#dfn-ticks), since source 1 declares a
[pause](#dfn-pause)
of 5 seconds, the [remote
end](#dfn-remote-ends) will dispatch the
[pointerUp](#dfn-pointerup) event for source 2, and will wait 5 seconds before
moving on to executing the third [tick](#dfn-ticks).

In the event that one [tick](#dfn-ticks) contains multiple
[pause](#dfn-pause)
durations, the [remote
end](#dfn-remote-ends) will wait the maximum duration before moving on to
executing the next [tick](#dfn-ticks).

As noted before, [pause](#dfn-pause) can be used to signify inaction during a
[tick](#dfn-ticks).
If [`pause`](#dfn-pause) is declared without a time period, then the [input
source](#dfn-input-source) will not have any actions executed in the containing
[tick](#dfn-ticks).
As an example:

!(graphics/note3actions.svg)

During [tick](#dfn-ticks) 2, source 1 will have its
[pointerMove](#dfn-pointermove) action dispatched, while source 2 will do nothing.

::: header-wrapper
### 15.1 Actions Options

Configuration of actions dispatch is controlled by a [actions
options] object. This is a
[struct](https://infra.spec.whatwg.org/#struct) that has a fields named [is element
origin], which is a set of steps that validate if a protocol
object represents an element origin, and [get element
origin], which is a set of steps used to deserialize an element.

To [get a WebElement origin] given
`session`, `origin` and
`browsing context`:,

1. Assert: `browsing context` is the [current browsing
 context](#dfn-current-browsing-context).

2. Let `element` be equal to the result of
 [trying](#dfn-try) to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `origin`.

3. Return [success](#dfn-success) with data `element`.

::: header-wrapper
### 15.2 Input sources

An [input source] is a virtual device
providing input events. Each input source is represented by an
[struct](https://infra.spec.whatwg.org/#struct) specific to the type of the input source. Each input
source has an [input id] which is stored as a
key in the [input state
map](#dfn-input-state-map).

To [create an input source] given
`input state`, `type` and optional
`subtype`:

1. Run the substeps matching the first matching value of
 `type`:

 \"`none`\"
 : Let `source` be the result of [create a null input
 source](#dfn-create-a-null-input-source).

 \"`key`\"
 : Let `source` be the result of [create a key input
 source](#dfn-create-a-key-input-source).

 \"`pointer`\"
 : Let `source` be the result of [create a pointer input
 source](#dfn-create-a-pointer-input-source) with `input state` and
 `subtype`.

 \"`wheel`\"
 : Let `source` be the result of [create a wheel input
 source](#dfn-create-a-wheel-input-source).

 Otherwise:
 : Return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

2. Return [success](#dfn-success) with data `source`.

::: header-wrapper
#### 15.2.1 Null input source

A [null input source] is an [input
source](#dfn-input-source) that is not associated with a specific physical device.
a [null input
source](#dfn-null-input-source) has no type-specific items, and supports
the following actions:

 ----------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Action Non-normative Description
 [pause] Used with an integer argument to specify the duration of a [tick](#dfn-ticks), or as a placeholder to indicate that an [input source](#dfn-input-source) does nothing during a particular [tick](#dfn-ticks).
 ----------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

To [create a null input source], return a new [null
input source](#dfn-null-input-source).

::: header-wrapper
#### 15.2.2 Key input source

A [key input source] is an [input
source](#dfn-input-source) that is associated with a keyboard-type device.

A [key input
source](#dfn-key-input-source) has the following items:

 --------- --------------------------------------------------------------- ---------------
 Item Non-normative Description Default Value
 pressed A set of strings representing currently pressed keys. Empty set
 alt A boolean indicating whether the alt modifier is depressed. False
 ctrl A boolean indicating whether the ctrl modifier is depressed. False
 meta A boolean indicating whether the meta modifier is depressed. False
 shift A boolean indicating whether the shift modifier is depressed. False
 --------- --------------------------------------------------------------- ---------------

A [key input
source](#dfn-key-input-source) supports the same
[pause](#dfn-pause)
action as a [null input
source](#dfn-null-input-source) plus the following actions:

 --------------------------------------------------------------------------------- -------------------------------------------------------------
 Action Non-normative Description
 [keyDown] Used to indicate that a particular key should be held down.
 [keyUp] Used to indicate that a depressed key should be released.
 --------------------------------------------------------------------------------- -------------------------------------------------------------

To [create a key input source], return a new [key
input source](#dfn-key-input-source) with the items initalized to their default
values.

::: header-wrapper
#### 15.2.3 Pointer input source

A [pointer input source] is an [input
source](#dfn-input-source) that is associated with a pointer-type input device.

A [pointer input
source](#dfn-pointer-input-source) has the following items:

 ----------- ------------------------------------------------------------------------------------------------------------------------------ ---------------
 Item Non-normative Description Default Value
 subtype The type of pointing device. This can be \"`mouse`\", \"`pen`\", or \"`touch`\".
 pointerId The numeric id of the pointing device. This is a positive integer, with the values 0 and 1 reserved for mouse-type pointers.
 pressed A set of unsigned integers representing the pointer buttons that are currently depressed. Empty set
 x An unsigned integer representing the pointer x location in viewport coordinates. 0
 y An unsigned integer representing the pointer y location in viewport coordinates. 0
 ----------- ------------------------------------------------------------------------------------------------------------------------------ ---------------

A [pointer input
source](#dfn-pointer-input-source) supports the same
[pause](#dfn-pause)
action as a [null input
source](#dfn-null-input-source) plus the following actions:

 ---------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Action Non-normative Description
 [pointerDown] Used to indicate that a pointer should be depressed in some way e.g. by holding a button down (for a mouse) or by coming into contact with the active surface (for a touch or pen device).
 [pointerUp] Used to indicate that a pointer should be released in some way e.g. by releasing a mouse button or moving a pen or touch device away from the active surface.
 [pointerMove] Used to indicate a location on the screen that a pointer should move to, either in its active (pressed) or inactive state.
 [pointerCancel] Used to cancel a pointer action.
 ---------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

To [create a pointer input source] object given
`input state`, and `subtype`, return a new
[pointer input
source](#dfn-pointer-input-source) with subtype set to `subtype`,
pointerId set to [get a pointer
id](#dfn-get-a-pointer-id) with `input state` and `subtype`,
and the other items set to their default values.

::: header-wrapper
#### 15.2.4 Wheel input source

A [wheel input source] is an [input
source](#dfn-input-source) that is associated with a wheel-type input device. A
[wheel input
source](#dfn-wheel-input-source) has no type specific items, and supports
the same [pause](#dfn-pause) action as a [null input
source](#dfn-null-input-source) plus the following actions:

 ------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------
 Action Non-normative Description
 [scroll] Used to indicate that the scroll wheel is rolled down, up, right or left to scroll the page down, up, right or left.
 ------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------

To [create a wheel input source] return a new [wheel
input source](#dfn-wheel-input-source).

::: header-wrapper
### 15.3 Input state

An [input state] represents the overall state of a
collection of [input
sources](#dfn-input-source). An [input
state](#dfn-input-state) has the following items:

- A [input state map] which is a map where keys are
 [input ids](#dfn-input-id), and the values are [input
 sources](#dfn-input-source).

- An [input cancel list], which is a list of [action
 objects](#dfn-action-object). This list is used to manage dispatching events when
 resetting the state of the [input
 source](#dfn-input-source)

- An [actions queue] which is a
 [queue](https://infra.spec.whatwg.org/#queue) that ensures that access to the [input
 state](#dfn-input-state) is serialized.

To [get the input state] given `session` and
`browsing context`:

1. Assert: `browsing context` is a [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context).

2. Let `input state map` be `session`\'s
 [browsing context input state
 map](#dfn-browsing-context-input-state-map).

3. If `input state map` does not
 [contain](https://infra.spec.whatwg.org/#map-exists) `browsing context`, set
 `input state map`\[`browsing context`\] to
 [create an input
 state](#dfn-create-an-input-state).

4. Return
 `input state map`\[`browsing context`\].

To [reset the input state] given `session` and
`browsing context`:

1. Assert: `browsing context` is a [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context).

2. Let `input state map` be `session`\'s
 [browsing context input state
 map](#dfn-browsing-context-input-state-map).

3. If `input state map`\[`browsing context`\]
 [exists](https://infra.spec.whatwg.org/#map-exists), then
 [remove](https://dom.spec.whatwg.org/#concept-node-remove)
 `input state map`\[`browsing context`\].

To [create an input state]:

1. Let `input state` be an [input
 state](#dfn-input-state) with the [input state
 map](#dfn-input-state-map) set to an empty map, and the [input
 cancel
 list](#dfn-input-cancel-list) set to an empty list.

2. Return `input state`.

To [add an input source] given `input state`,
`input id`, and `source`:

1. Let `input state map` be `input state`\'s
 [input state
 map](#dfn-input-state-map).

2. Set `input state map`\[`input id`\] to
 `source`.

To [remove an input source] given
`input state`, and `input id`:

1. Assert: None of the items in `input state`\'s [input
 cancel
 list](#dfn-input-cancel-list) has id equal to `input id`.

2. Let `input state map` be `input state`\'s
 [input state
 map](#dfn-input-state-map).

3. Remove `input state map`\[`input id`\].

To [get an input source] given `input state`
and `input id`:

1. Let `input state map` be `input state`\'s
 [input state
 map](#dfn-input-state-map).

2. If `input state map`\[`input id`\] exists,
 return `input state map`\[`input id`\].

3. Return undefined.

To [get or create an input source] given
`input state`, `type`, `input id`, and
optional `subtype`:

1. Let `source` be [get an input
 source](#dfn-get-an-input-source) with `input state` and
 `input id`.

2. If `source` is not undefined and `source`\'s
 type is not equal to `type`, or `source` is a
 [pointer input
 source](#dfn-pointer-input-source), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. If `source` is undefined, set `source` to the
 result of [trying](#dfn-try) to [create an input
 source](#dfn-create-an-input-source) with `input state` and
 `type`.

4. Return success with data `source`.

A [global key state] is a
[struct](https://infra.spec.whatwg.org/#struct) with items pressed, altKey, ctrlKey, metaKey, and
shiftKey.

To [get the global key state] given
`input state`:

1. Let `input state map` be `input state`\'s
 [input state
 map](#dfn-input-state-map).

2. Let `sources` be the result of [getting the
 values](https://infra.spec.whatwg.org/#map-getting-the-values) with `input state map`.

3. Let `key state` be a new [global key
 state](#dfn-global-key-state) with `pressed` set to an empty set,
 `altKey`, `ctrlKey`, `metaKey`, and `shiftKey` set to false.

4. For each `source` in `sources`:

 1. If `source` is not a [key input
 source](#dfn-key-input-source), continue to the first step of
 this loop.

 2. Set `key state`\'s `pressed` item to the union of its
 current value and `source`\'s pressed item.

 3. If `source`\'s `alt` item is true, set
 `key state`\'s `altKey` item to true.

 4. If `source`\'s `ctrl` item is true, set
 `key state`\'s `ctrlKey` item to true.

 5. If `source`\'s `meta` item is true, set
 `key state`\'s `metaKey` item to true.

 6. If `source`\'s `shift` item is true, set
 `key state`\'s `shiftKey` item to true.

5. Return `key state`.

To [get a pointer id] given `input state`
and `subtype`:

1. Let `minimum id` be 0 if `subtype` is
 \"`mouse`\", or 2 otherwise.

2. Let `pointer ids` be an empty set.

3. Let `sources` be the result of [getting the
 values](https://infra.spec.whatwg.org/#map-getting-the-values) with `input state`\'s [input state
 map](#dfn-input-state-map).

4. For each `source` in `sources`.:

 1. If `source` is a [pointer input
 source](#dfn-pointer-input-source), append `source`\'s
 pointerId to `pointer ids`.

5. Return the smallest integer that is greater than or equal to
 `minimum id` and that is not contained in
 `pointer ids`.

::: header-wrapper
### 15.4 Ticks

A [tick] is the basic unit of time over
which actions can be performed. During a
[tick](#dfn-ticks),
each [input source](#dfn-input-source) has an assigned action --- possibly a noop
[pause](#dfn-pause)
action --- which may result in changes to the user agent internal state
and eventually cause DOM events to be
[fired](https://dom.spec.whatwg.org/#concept-event-fire) at the page. The next
[tick](#dfn-ticks)
begins after the user agent has had a chance to process all DOM events
generated in the current [tick](#dfn-ticks).

[Waiting asynchronously] means waiting for
something to occur whilst allowing the browser to continue processing
the [event loop](https://html.spec.whatwg.org/#event-loop).

At the lowest level, the behavior of actions is intended to mimic the
[remote end](#dfn-remote-ends)\'s behavior with an actual input device as closely as
possible, and the implementation strategy may involve e.g. injecting
synthesized events into a browser event loop. Therefore the steps to
dispatch an action will inevitably end up in implementation-specific
territory. However there are certain content observable effects that
must be consistent across implementations. To accommodate this, the
specification requires that [remote
ends](#dfn-remote-ends) [perform implementation-specific action dispatch
steps] on a [browsing
context](#dfn-browsing-contexts) `context`, and a
`list of events` and their properties. These steps must be
equivalent to performing the given input device manipulations on
`context`, such that trusted events corresponding to the
entries in `list of events`are dispatched.

The list of events is not comprehensive; in particular the default
action of the [input
source](#dfn-input-source) may cause additional events to be generated depending
on the implementation and the state of the browser (e.g. input events
relating to key actions when the focus is on an editable
[element](https://dom.spec.whatwg.org/#concept-element), scroll events, etc.).

An [activation
trigger](#dfn-activation-trigger) generated by WebDriver needs to be
indistinguishable from those generated by a real user interacting with
the browser. In particular, the dispatched events will have the
[`isTrusted`](https://dom.spec.whatwg.org/#dom-event-istrusted) attribute set to true.

The most robust way to dispatch these events is by creating them in the
browser implementation itself. Sending operating system specific input
messages to the browser\'s window has the disadvantage that the browser
being automated may not be properly isolated from a user accidentally
modifying an [input
source](#dfn-input-source). Use of an operating system level accessibility API has
the disadvantage that the browser\'s window must be focused, and as a
result, multiple WebDriver instances cannot run in parallel.

The advantage of an operating system level accessibility API is that it
guarantees that inputs correctly mirror user input, and allows
interaction with the host system if necessary. This might, however, have
performance penalties from a machine utilisation perspective.

::: header-wrapper
### 15.5 Processing actions

The algorithm for [extracting an action sequence from a
request](#dfn-extract-an-action-sequence) takes the
JSON [Object](#dfn-object) representing an action sequence, validates the input,
and returns a data structure that is the transpose of the input JSON,
such that the actions to be performed in a single
[tick](#dfn-ticks)
are grouped together.

To [get coordinates relative to an
origin] given `source`,
`x offset`, `y offset`, `origin`,
`browsing context`, and `actions options`:

1. Run the substeps of the first matching value of `origin`

 \"`viewport`\"

 : 1. Let `x` equal `x offset` and
 `y` equal `y offset`.

 \"`pointer`\"

 : 1. Let `start x` be equal to the `x` property of
 `source`.

 2. Let `start y` be equal to the `y` property of
 `source`.

 3. Let `x` equal `start x` +
 `x offset` and `y` equal
 `start y` + `y offset`.

 Otherwise

 : 1. Let `element` be the result of
 [trying](#dfn-try) to run `actions options`\' [get
 element
 origin](#dfn-get-element-origin) steps with `origin`
 and `browsing context`.

 2. If `element` is null, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 element](#dfn-no-such-element).

 3. Let `x element` and `y element` be the
 result of calculating the [in-view center
 point](#dfn-center-point) of `element`.

 4. Let `x` equal `x element` +
 `x offset`, and `y` equal
 `y element` + `y offset`.

2. Return (`x`, `y`)

To [extract an action sequence] given
`input state`, `parameters`, and
`actions options`:

1. Let `actions` be the result of [getting a
 property](#dfn-getting-properties) named \"`actions`\" from
 `parameters`.

2. If `actions` is
 [undefined](#dfn-undefined) or is not an
 [Array](#dfn-array), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Let `actions by tick` be an empty
 [List](#dfn-list).

4. For each value `action sequence` corresponding to an
 indexed property in `actions`:

 1. Let `source actions` be the result of
 [trying](#dfn-try) to [process an input source action
 sequence](#dfn-process-an-input-source-action-sequence) given `input state`,
 `action sequence`, and `actions options`.

 2. For each `action` in `source actions`:

 1. Let `i` be the zero-based index of
 `action` in `source actions`.

 2. If the length of `actions by tick` is less than
 `i` + 1, append a new
 [List](#dfn-list) to `actions by tick`.

 3. Append `action` to the
 [List](#dfn-list) at index `i` in
 `actions by tick`.

5. Return [success](#dfn-success) with data `actions by tick`.

When required to [process an input source action
sequence], given `input state`,
`action sequence`, and `actions options`, a
[remote end](#dfn-remote-ends) must:

1. Let `type` be the result of [getting a
 property](#dfn-getting-properties) named \"`type`\" from
 `action sequence`.

2. If `type` is not \"`key`\", \"`pointer`\", \"`wheel`\",
 or \"`none`\", return an [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Let `id` be the result of [getting the
 property](#dfn-getting-properties) \"`id`\" from
 `action sequence`.

4. If `id` is
 [undefined](#dfn-undefined) or is not a
 [String](#dfn-string), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

5. If `type` is equal to \"`pointer`\", let
 `parameters data` be the result of [getting the
 property](#dfn-getting-properties) \"`parameters`\" from
 `action sequence`. Then let `parameters` be
 the result of [trying](#dfn-try) to [process pointer
 parameters](#dfn-process-pointer-parameters) with argument
 `parameters data`.

6. Let `source` be the result of trying to [get or create an
 input
 source](#dfn-get-or-create-an-input-source) given `input state`,
 `type` and `id`.

7. If `parameters` is not
 [undefined](#dfn-undefined), then if its `pointerType` property is not equal to
 `source`\'s subtype property, return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

8. Let `action items` be the result of [getting a
 property](#dfn-getting-properties) named \"`actions`\" from
 `action sequence`.

9. If `action items` is not an
 [Array](#dfn-array), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

10. Let `actions` be a new list.

11. For each `action item` in `action items`:

 1. If `action item` is not an
 [Object](#dfn-object) return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 2. If `type` is \"`none`\" let `action` be
 the result of [trying](#dfn-try) to [process a null
 action](#dfn-process-a-null-action) with parameters `id`,
 and `action item`.

 3. Otherwise, if `type` is \"`key`\" let
 `action` be the result of
 [trying](#dfn-try) to [process a key
 action](#dfn-process-a-key-action) with parameters `id`,
 and `action item`.

 4. Otherwise, if `type` is \"`pointer`\" let
 `action` be the result of
 [trying](#dfn-try) to [process a pointer
 action](#dfn-process-a-pointer-action) with parameters `id`,
 `parameters`, `action item`, and
 `actions options`.

 5. Otherwise, if `type` is \"`wheel`\" let
 `action` be the result of
 [trying](#dfn-try) to [process a wheel
 action](#dfn-process-a-wheel-action) with parameters `id`,
 and `action item`, and `actions options`.

 6. Append `action` to `actions`.

12. Return [success](#dfn-success) with data `actions`.

The [default pointer parameters] consist of an object
with property `pointerType` set to `mouse`.

To [process pointer parameters] given
`parameters data`:

1. Let `parameters` be the [default pointer
 parameters](#dfn-default-pointer-parameters).

2. If `parameters data` is
 [undefined](#dfn-undefined), return
 [success](#dfn-success) with data `parameters`.

3. If `parameters data` is not an
 [Object](#dfn-object), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

4. Let `pointer type` be the result of [getting a
 property](#dfn-getting-properties) named \"`pointerType`\" from
 `parameters data`.

5. If `pointer type` is not
 [undefined](#dfn-undefined):

 1. If `pointer type` does not have one of the values
 \"`mouse`\", \"`pen`\", or \"`touch`\", return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 2. Set the `pointerType` property of `parameters` to
 `pointer type`.

6. Return [success](#dfn-success) with data `parameters`.

An [action object] constructed with
arguments `id`, `type`, and `subtype`
is an object with property id set to `id`, type set to
`type` and subtype set to `subtype`. Specific
action objects have further properties added by other algorithms in this
specification.

To [process a null action] given `id` and
`action item`:

1. Let `subtype` be the result of [getting a
 property](#dfn-getting-properties) named \"`type`\" from
 `action item`.

2. If `subtype` is not \"`pause`\", return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Let `action` be an [action
 object](#dfn-action-object) constructed with arguments
 `id`, `"none"`, and `subtype`.

4. Let `result` be the result of
 [trying](#dfn-try) to [process a pause
 action](#dfn-process-a-pause-action) with arguments
 `action item` and `action`.

5. Return `result`.

To [process a key action] given `id` and
`action item`:

1. Let `subtype` be the result of [getting a
 property](#dfn-getting-properties) named \"`type`\" from
 `action item`.

2. If `subtype` is not one of the values \"`keyUp`\",
 \"`keyDown`\", or \"`pause`\", return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Let `action` be an [action
 object](#dfn-action-object) constructed with arguments
 `id`, \"`key`\", and `subtype`.

4. If `subtype` is \"`pause`\", let `result` be
 the result of [trying](#dfn-try) to [process a pause
 action](#dfn-process-a-pause-action) with arguments
 `action item` and `action`, and return
 `result`.

5. Let `key` be the result of [getting a
 property](#dfn-getting-properties) named \"`value`\" from
 `action item`.

6. If `key` is not a
 [String](#dfn-string) containing a single [unicode code
 point](#dfn-unicode-code-point) [or grapheme cluster?] return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

7. Set the `value` property on `action` to `key`.

8. Return success with data `action`.

To [process a pointer action] given
`id`, `parameters`, `action item`, and
`action options`:

1. Let `subtype` be the result of [getting a
 property](#dfn-getting-properties) named \"`type`\" from
 `action item`.

2. If `subtype` is not one of the values \"`pause`\",
 \"`pointerUp`\", \"`pointerDown`\", \"`pointerMove`\", or
 \"`pointerCancel`\", return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Let `action` be an [action
 object](#dfn-action-object) constructed with arguments
 `id`, \"`pointer`\", and `subtype`.

4. If `subtype` is \"`pause`\", let `result` be
 the result of [trying](#dfn-try) to [process a pause
 action](#dfn-process-a-pause-action) with arguments
 `action item`, `action`, and
 `actions options`, and return `result`.

5. Set the `pointerType` property of `action` equal to the
 `pointerType` property of `parameters`.

6. If `subtype` is \"`pointerUp`\" or \"`pointerDown`\",
 [process a pointer up or pointer down
 action](#dfn-process-a-pointer-up-or-pointer-down-action) with arguments
 `action item` and `action`. If doing so
 results in an [error](#dfn-error), return that
 [error](#dfn-error).

7. If `subtype` is \"`pointerMove`\" [process a pointer move
 action](#dfn-process-a-pointer-move-action) with arguments
 `action item`, `action`, and
 `actions options`. If doing so results in an
 [error](#dfn-error), return that
 [error](#dfn-error).

8. If `subtype` is \"`pointerCancel`\" [process a pointer
 cancel action]. If doing so results in an
 [error](#dfn-error), return that
 [error](#dfn-error).

9. Return [success](#dfn-success) with data `action`.

To [process a wheel action] given
`id`, `action item`, and
`actions options`:

1. Let `subtype` be the result of [getting a
 property](#dfn-getting-properties) named \"`type`\" from
 `action item`.

2. If `subtype` is not the value \"`pause`\", or
 \"`scroll`\", return an [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Let `action` be an [action
 object](#dfn-action-object) constructed with arguments
 `id`, \"`wheel`\", and `subtype`.

4. If `subtype` is \"`pause`\", let `result` be
 the result of [trying](#dfn-try) to [process a pause
 action](#dfn-process-a-pause-action) with arguments
 `action item` and `action`, and return
 `result`.

5. Let `duration` be the result of [getting a
 property](#dfn-getting-properties) named \"`duration`\" from
 `action item`.

6. If `duration` is not
 [undefined](#dfn-undefined) and `duration` is not an
 [Integer](#dfn-integer) greater than or equal to 0, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

7. Set the `duration` property of `action` to
 `duration`.

8. Let `origin` be the result of [getting the
 property](#dfn-getting-properties) `origin` from
 `action item`.

9. If `origin` is
 [undefined](#dfn-undefined) let `origin` equal \"`viewport`\".

10. If `origin` is not equal to \"`viewport`\", or
 `actions options`\' [is element
 origin](#dfn-is-element-origin) steps given `origin` return
 false, return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

11. Set the `origin` property of `action` to
 `origin`.

12. Let `x` be the result of [getting the
 property](#dfn-getting-properties) `x` from `action item`.

13. If `x` is not an
 [Integer](#dfn-integer), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

14. Set the `x` property of `action` to `x`.

15. Let `y` be the result of [getting the
 property](#dfn-getting-properties) `y` from `action item`.

16. If `y` is not an
 [Integer](#dfn-integer), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

17. Set the `y` property of `action` to `y`.

18. Let `deltaX` be the result of [getting the
 property](#dfn-getting-properties) `deltaX` from
 `action item`.

19. If `deltaX` is not an
 [Integer](#dfn-integer), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

20. Set the `deltaX` property of `action` to
 `deltaX`.

21. Let `deltaY` be the result of [getting the
 property](#dfn-getting-properties) `deltaY` from
 `action item`.

22. If `deltaY` is not an
 [Integer](#dfn-integer), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

23. Set the `deltaY` property of `action` to
 `deltaY`.

24. Return [success](#dfn-success) with data `action`.

To [process a pause action] given
`action item`, and `action`:

1. Let `duration` be the result of [getting the
 property](#dfn-getting-properties) \"`duration`\" from
 `action item`.

2. If `duration` is not
 [undefined](#dfn-undefined) and `duration` is not an
 [Integer](#dfn-integer) greater than or equal to 0, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Set the `duration` property of `action` to
 `duration`.

4. Return success with data `action`.

To [process a pointer up or pointer down
action] given
`action item`, and `action`:

1. Let `button` be the result of getting the property
 `button` from `action item`.

2. If `button` is not an
 [Integer](#dfn-integer) greater than or equal to 0 return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Set the `button` property of `action` to
 `button`.

4. Let `width` be the result of getting the property `width`
 from `action item`.

5. If `width` is not
 [undefined](#dfn-undefined) and `width` is not a
 [Number](#dfn-number) greater than or equal to 0 return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

6. Set the `width` property of `action` to
 `width`.

7. Let `height` be the result of getting the property
 `height` from `action item`.

8. If `height` is not
 [undefined](#dfn-undefined) and `height` is not a
 [Number](#dfn-number) greater than or equal to 0 return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

9. Set the `height` property of `action` to
 `height`.

10. Let `pressure` be the result of getting the property
 `pressure` from `action item`.

11. If `pressure` is not
 [undefined](#dfn-undefined) and `pressure` is not a
 [Number](#dfn-number) greater than or equal to 0 and less than or equal
 to 1 return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

12. Set the `pressure` property of `action` to
 `pressure`.

13. Let `tangentialPressure` be the result of getting the
 property `tangentialPressure` from `action item`.

14. If `tangentialPressure` is not
 [undefined](#dfn-undefined) and `tangentialPressure` is not a
 [Number](#dfn-number) greater than or equal to -1 and less than or equal
 to 1 return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

15. Set the `tangentialPressure` property of `action` to
 `tangentialPressure`.

16. Let `tiltX` be the result of getting the property `tiltX`
 from `action item`.

17. If `tiltX` is not
 [undefined](#dfn-undefined) and `tiltX` is not an
 [Integer](#dfn-integer) greater than or equal to -90 and less than or equal
 to 90 return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

18. Set the `tiltX` property of `action` to
 `tiltX`.

19. Let `tiltY` be the result of getting the property `tiltY`
 from `action item`.

20. If `tiltY` is not
 [undefined](#dfn-undefined) and `tiltY` is not an
 [Integer](#dfn-integer) greater than or equal to -90 and less than or equal
 to 90 return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

21. Set the `tiltY` property of `action` to
 `tiltY`.

22. Let `twist` be the result of getting the property `twist`
 from `action item`.

23. If `twist` is not
 [undefined](#dfn-undefined) and `twist` is not an
 [Integer](#dfn-integer) greater than or equal to 0 and less than or equal
 to 359 return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

24. Set the `twist` property of `action` to
 `twist`.

25. Let `altitudeAngle` be the result of getting the property
 `altitudeAngle` from `action item`.

26. If `altitudeAngle` is not
 [undefined](#dfn-undefined) and `altitudeAngle` is not a
 [Number](#dfn-number) greater than or equal to 0 and less than or equal
 to π/2 return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

27. Set the `altitudeAngle` property of `action` to
 `altitudeAngle`.

28. Let `azimuthAngle` be the result of getting the property
 `azimuthAngle` from `action item`.

29. If `azimuthAngle` is not
 [undefined](#dfn-undefined) and `azimuthAngle` is not a
 [Number](#dfn-number) greater than or equal to 0 and less than or equal
 to 2π return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

30. Set the `azimuthAngle` property of `action` to
 `azimuthAngle`.

31. Return success with data [`null`](#dfn-null).

To [process a pointer move action] given
`action item`, `action`, and
`actions options`:

1. Let `duration` be the result of getting the property
 `duration` from `action item`.

2. If `duration` is not
 [undefined](#dfn-undefined) and `duration` is not an
 [Integer](#dfn-integer) greater than or equal to 0, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. Set the `duration` property of `action` to
 `duration`.

4. Let `origin` be the result of [getting the
 property](#dfn-getting-properties) `origin` from
 `action item`.

5. If `origin` is
 [undefined](#dfn-undefined) let `origin` equal \"`viewport`\".

6. If `origin` is not equal to \"`viewport`\" or
 \"`pointer`\", and `actions options` [is element
 origin](#dfn-is-element-origin) steps given `origin` return
 false, return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

7. Set the `origin` property of `action` to
 `origin`.

8. Let `x` be the result of [getting the
 property](#dfn-getting-properties) `x` from `action item`.

9. If `x` is not a
 [Number](#dfn-number), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

10. Set the `x` property of `action` to `x`.

11. Let `y` be the result of [getting the
 property](#dfn-getting-properties) `y` from `action item`.

12. If `y` is not a
 [Number](#dfn-number), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

13. Set the `y` property of `action` to `y`.

14. Let `width` be the result of getting the property `width`
 from `action item`.

15. If `width` is not
 [undefined](#dfn-undefined) and `width` is not a
 [Number](#dfn-number) greater than or equal to 0 return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

16. Set the `width` property of `action` to
 `width`.

17. Let `height` be the result of getting the property
 `height` from `action item`.

18. If `height` is not
 [undefined](#dfn-undefined) and `height` is not a
 [Number](#dfn-number) greater than or equal to 0 return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

19. Set the `height` property of `action` to
 `height`.

20. Let `pressure` be the result of getting the property
 `pressure` from `action item`.

21. If `pressure` is not
 [undefined](#dfn-undefined) and `pressure` is not a
 [Number](#dfn-number) greater than or equal to 0 and less than or equal
 to 1 return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

22. Set the `pressure` property of `action` to
 `pressure`.

23. Let `tangentialPressure` be the result of getting the
 property `tangentialPressure` from `action item`.

24. If `tangentialPressure` is not
 [undefined](#dfn-undefined) and `tangentialPressure` is not a
 [Number](#dfn-number) greater than or equal to -1 and less than or equal
 to 1 return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

25. Set the `tangentialPressure` property of `action` to
 `tangentialPressure`.

26. Let `tiltX` be the result of getting the property `tiltX`
 from `action item`.

27. If `tiltX` is not
 [undefined](#dfn-undefined) and `tiltX` is not an
 [Integer](#dfn-integer) greater than or equal to -90 and less than or equal
 to 90 return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

28. Set the `tiltX` property of `action` to
 `tiltX`.

29. Let `tiltY` be the result of getting the property `tiltY`
 from `action item`.

30. If `tiltY` is not
 [undefined](#dfn-undefined) and `tiltY` is not an
 [Integer](#dfn-integer) greater than or equal to -90 and less than or equal
 to 90 return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

31. Set the `tiltY` property of `action` to
 `tiltY`.

32. Let `twist` be the result of getting the property `twist`
 from `action item`.

33. If `twist` is not
 [undefined](#dfn-undefined) and `twist` is not an
 [Integer](#dfn-integer) greater than or equal to 0 and less than or equal
 to 359 return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

34. Set the `twist` property of `action` to
 `twist`.

35. Let `altitudeAngle` be the result of getting the property
 `altitudeAngle` from `action item`.

36. If `altitudeAngle` is not
 [undefined](#dfn-undefined) and `altitudeAngle` is not a
 [Number](#dfn-number) greater than or equal to 0 and less than or equal
 to π/2 return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

37. Set the `altitudeAngle` property of `action` to
 `altitudeAngle`.

38. Let `azimuthAngle` be the result of getting the property
 `azimuthAngle` from `action item`.

39. If `azimuthAngle` is not
 [undefined](#dfn-undefined) and `azimuthAngle` is not a
 [Number](#dfn-number) greater than or equal to 0 and less than or equal
 to 2π return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

40. Set the `azimuthAngle` property of `action` to
 `azimuthAngle`.

41. Return success with data [`null`](#dfn-null).

::: header-wrapper
### 15.6 Dispatching actions

The algorithm to [dispatch
actions](#dfn-dispatch-actions) takes a list of actions grouped by
[tick](#dfn-ticks),
and then causes each action to be run at the appropriate point in the
sequence.

To [wait for an action queue token] given
`input state`:

1. Let `token` be a new unique identifier.

2. Enqueue `token` in `input state`\'s [actions
 queue](#dfn-actions-queue).

3. Wait for `token` to be the first item in
 `input state`\'s [actions
 queue](#dfn-actions-queue).

 ::::
 :::
 Note
 :::

 This ensures that only one set of actions can be run at a time, and
 therefore different actions commands using the same underlying state
 don\'t race. In a session that is only a HTTP session only one
 command can run at a time, so this will never block. But other
 session types can allow running multiple commands in parallel, in
 which case this is necessary to ensure sequential access.
 ::::

To [dispatch actions] given `input state`,
`actions by tick`, `browsing context`, and
`actions options`:

1. [Wait for an action queue
 token](#dfn-wait-for-an-action-queue-token) with `input state`.

2. Let `actions result` be the result of [dispatch actions
 inner](#dfn-dispatch-actions-inner) with `input state`,
 `actions by tick`, `browsing context`, and
 `actions options`.

3. Dequeue `input state`\'s [actions
 queue](#dfn-actions-queue).

 Assert: this returns `token`

4. Return `actions result`.

To [dispatch actions inner] given
`input state`, `actions by tick`,
`browsing context`, and `actions options`:

1. For each item `tick actions` in
 `actions by tick`:

 1. If `browsing context` is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

 2. Let `tick duration` be the result of [computing the
 tick
 duration](#dfn-computing-the-tick-duration) with argument
 `tick actions`.

 3. [Try](#dfn-try) to [dispatch tick
 actions](#dfn-dispatch-tick-actions) with `input state`,
 `tick actions`, `tick duration`,
 `browsing context`, and `actions options`.

 4. Wait until the following conditions are all met:

 - There are no pending [asynchronous
 waits](#dfn-asynchronously-wait) arising from the last invocation
 of the [dispatch tick
 actions](#dfn-dispatch-tick-actions) steps.

 - The user agent event loop has spun enough times to process the
 DOM events generated by the last invocation of the [dispatch
 tick
 actions](#dfn-dispatch-tick-actions) steps.

 - At least `tick duration` milliseconds have passed.

2. Return success with data [`null`](#dfn-null).

To [compute the tick duration] given `tick actions`:

1. Let `max duration` be 0.

2. For each `action object` in `tick actions`:

 1. let `duration` be
 [undefined](#dfn-undefined).

 2. If `action object` has subtype property set to
 \"`pause`\" or `action object` has type property set
 to \"`pointer`\" and subtype property set to \"`pointerMove`\",
 or `action object` has type property set to
 \"`wheel`\" and subtype property set to \"`scroll`\", let
 `duration` be equal to the `duration` property of
 `action object`.

 3. If `duration` is not
 [undefined](#dfn-undefined), and `duration` is
 greater than `max duration`, let
 `max duration` be equal to duration.

3. Return `max duration`.

To [dispatch tick actions] given `input state`,
`tick actions`, `tick duration`,
`browsing context`, and `actions options`:

1. For each `action object` in `tick actions`:

 1. Let `input id` be equal to the value of
 `action object`\'s id property.

 2. Let `source type` be equal to the value of
 `action object`\'s type property.

 3. Let `source` be the result of [get an input
 source](#dfn-get-an-input-source) given `input state` and
 `input id`.

 4. Assert: `source` is not undefined.

 5. Let `global key state` be the result of [get the
 global key
 state](#dfn-get-the-global-key-state) with `input state`.

 6. Let `subtype` be `action object`\'s
 subtype.

 7. Let `algorithm` be the value of the column *dispatch
 action algorithm* from the following table where the *source
 type* column is `source type` and the *subtype*
 column is equal to `subtype`.

 --------------- --------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------
 source type subtype Dispatch action algorithm
 \"`none`\" \"`pause`\" [Dispatch a pause action](#dfn-dispatch-a-pause-action)
 \"`key`\" \"`pause`\" [Dispatch a pause action](#dfn-dispatch-a-pause-action)
 \"`key`\" \"`keyDown`\" [Dispatch a keyDown action](#dfn-dispatch-a-keydown-action)
 \"`key`\" \"`keyUp`\" [Dispatch a keyUp action](#dfn-dispatch-a-keyup-action)
 \"`pointer`\" \"`pause`\" [Dispatch a pause action](#dfn-dispatch-a-pause-action)
 \"`pointer`\" \"`pointerDown`\" [Dispatch a pointerDown action](#dfn-dispatch-a-pointerdown-action)
 \"`pointer`\" \"`pointerUp`\" [Dispatch a pointerUp action](#dfn-dispatch-a-pointerup-action)
 \"`pointer`\" \"`pointerMove`\" [Dispatch a pointerMove action](#dfn-dispatch-a-pointermove-action)
 \"`pointer`\" \"`pointerCancel`\" [Dispatch a pointerCancel action](#dfn-dispatch-a-pointercancel-action)
 \"`wheel`\" \"`pause`\" [Dispatch a pause action](#dfn-dispatch-a-pause-action)
 \"`wheel`\" \"`scroll`\" [Dispatch a scroll action](#dfn-dispatch-a-scroll-action)
 --------------- --------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------

 8. [Try](#dfn-try) to run `algorithm` with arguments
 `action object`, `source`,
 `global key state`, `tick duration`,
 `browsing context`, and `actions options`.

 9. If `subtype` is \"`keyDown`\", append a copy of
 `action object` with the `subtype`
 property changed to \"`keyUp`\" to `input state`\'s
 [input cancel
 list](#dfn-input-cancel-list).

 10. If `subtype` is \"`pointerDown`\", append a copy of
 `action object` with the `subtype`
 property changed to \"`pointerUp`\" to
 `input state`\'s [input cancel
 list](#dfn-input-cancel-list).

2. Return [success](#dfn-success) with data [`null`](#dfn-null).

To [dispatch a list of actions] given
`input state`, `actions`,
`browsing context`, and `actions options`:

This is an entry point for other commands that are written in terms of a
sequence of actions of a single input source in a single tick.

1. Let `tick actions` be the list «`actions`»

2. Let `actions by tick` be the list
 «`tick actions`».

3. Return the result of [dispatch
 actions](#dfn-dispatch-actions) with `input state`,
 `actions by tick`, `browsing context`, and
 `actions options`.

::: header-wrapper
#### 15.6.1 General actions

To [dispatch a pause action] given
`action object`, `source`,
`global key state`, `tick duration`,
`browsing context`, and `actions options`:

1. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
#### 15.6.2 Keyboard actions

The [normalized key value] for a raw key `key`
is, if `key` appears in the table below, the string value in
the second column on the row containing `key`\'s [unicode
code point](#dfn-unicode-code-point) in the first column, otherwise it is
`key`.

 ------------------------------- ----------------------
 `key`\'s codepoint Normalized key value
 `\uE000` `"Unidentified"`
 `\uE001` `"Cancel"`
 `\uE002` `"Help"`
 `\uE003` `"Backspace"`
 `\uE004` `"Tab"`
 `\uE005` `"Clear"`
 `\uE006` `"Return"`
 `\uE007` `"Enter"`
 `\uE008` `"Shift"`
 `\uE009` `"Control"`
 `\uE00A` `"Alt"`
 `\uE00B` `"Pause"`
 `\uE00C` `"Escape"`
 `\uE00D` `" "`
 `\uE00E` `"PageUp"`
 `\uE00F` `"PageDown"`
 `\uE010` `"End"`
 `\uE011` `"Home"`
 `\uE012` `"ArrowLeft"`
 `\uE013` `"ArrowUp"`
 `\uE014` `"ArrowRight"`
 `\uE015` `"ArrowDown"`
 `\uE016` `"Insert"`
 `\uE017` `"Delete"`
 `\uE018` `";"`
 `\uE019` `"="`
 `\uE01A` `"0"`
 `\uE01B` `"1"`
 `\uE01C` `"2"`
 `\uE01D` `"3"`
 `\uE01E` `"4"`
 `\uE01F` `"5"`
 `\uE020` `"6"`
 `\uE021` `"7"`
 `\uE022` `"8"`
 `\uE023` `"9"`
 `\uE024` `"*"`
 `\uE025` `"+"`
 `\uE026` `","`
 `\uE027` `"-"`
 `\uE028` `"."`
 `\uE029` `"/"`
 `\uE031` `"F1"`
 `\uE032` `"F2"`
 `\uE033` `"F3"`
 `\uE034` `"F4"`
 `\uE035` `"F5"`
 `\uE036` `"F6"`
 `\uE037` `"F7"`
 `\uE038` `"F8"`
 `\uE039` `"F9"`
 `\uE03A` `"F10"`
 `\uE03B` `"F11"`
 `\uE03C` `"F12"`
 `\uE03D` `"Meta"`
 `\uE040` `"ZenkakuHankaku"`
 `\uE050` `"Shift"`
 `\uE051` `"Control"`
 `\uE052` `"Alt"`
 `\uE053` `"Meta"`
 `\uE054` `"PageUp"`
 `\uE055` `"PageDown"`
 `\uE056` `"End"`
 `\uE057` `"Home"`
 `\uE058` `"ArrowLeft"`
 `\uE059` `"ArrowUp"`
 `\uE05A` `"ArrowRight"`
 `\uE05B` `"ArrowDown"`
 `\uE05C` `"Insert"`
 `\uE05D` `"Delete"`
 ------------------------------- ----------------------

The [code] for `key` is the value in the last column of
the following table on the row with `key` in either the first
or second column, if any such row exists, otherwise it is
[undefined](#dfn-undefined).

A [shifted character] is one that appears in the second
column of the following table.

 ------------ --------------- --------------------
 Key Alternate Key code
 `` "`" `` `"~"` `"Backquote"`
 `"\"` `"|"` `"Backslash"`
 `"\uE003"` `"Backspace"`
 `"["` `"{"` `"BracketLeft"`
 `"]"` `"}"` `"BracketRight"`
 `","` `"<"` `"Comma"`
 `"0"` `")"` `"Digit0"`
 `"1"` `"!"` `"Digit1"`
 `"2"` `"@"` `"Digit2"`
 `"3"` `"#"` `"Digit3"`
 `"4"` `"$"` `"Digit4"`
 `"5"` `"%"` `"Digit5"`
 `"6"` `"^"` `"Digit6"`
 `"7"` `"&"` `"Digit7"`
 `"8"` `"*"` `"Digit8"`
 `"9"` `"("` `"Digit9"`
 `"="` `"+"` `"Equal"`
 `"<"` `">"` `"IntlBackslash"`
 `"a"` `"A"` `"KeyA"`
 `"b"` `"B"` `"KeyB"`
 `"c"` `"C"` `"KeyC"`
 `"d"` `"D"` `"KeyD"`
 `"e"` `"E"` `"KeyE"`
 `"f"` `"F"` `"KeyF"`
 `"g"` `"G"` `"KeyG"`
 `"h"` `"H"` `"KeyH"`
 `"i"` `"I"` `"KeyI"`
 `"j"` `"J"` `"KeyJ"`
 `"k"` `"K"` `"KeyK"`
 `"l"` `"L"` `"KeyL"`
 `"m"` `"M"` `"KeyM"`
 `"n"` `"N"` `"KeyN"`
 `"o"` `"O"` `"KeyO"`
 `"p"` `"P"` `"KeyP"`
 `"q"` `"Q"` `"KeyQ"`
 `"r"` `"R"` `"KeyR"`
 `"s"` `"S"` `"KeyS"`
 `"t"` `"T"` `"KeyT"`
 `"u"` `"U"` `"KeyU"`
 `"v"` `"V"` `"KeyV"`
 `"w"` `"W"` `"KeyW"`
 `"x"` `"X"` `"KeyX"`
 `"y"` `"Y"` `"KeyY"`
 `"z"` `"Z"` `"KeyZ"`
 `"-"` `"_"` `"Minus"`
 `"."` `"."` `"Period"`
 `"'"` `"""` `"Quote"`
 `";"` `":"` `"Semicolon"`
 `"/"` `"?"` `"Slash"`
 `"\uE00A"` `"AltLeft"`
 `"\uE052"` `"AltRight"`
 `"\uE009"` `"ControlLeft"`
 `"\uE051"` `"ControlRight"`
 `"\uE006"` `"Enter"`
 `"\uE00B"` `"Pause"`
 `"\uE03D"` `"MetaLeft"`
 `"\uE053"` `"MetaRight"`
 `"\uE008"` `"ShiftLeft"`
 `"\uE050"` `"ShiftRight"`
 `" "` `"\uE00D"` `"Space"`
 `"\uE004"` `"Tab"`
 `"\uE017"` `"Delete"`
 `"\uE010"` `"End"`
 `"\uE002"` `"Help"`
 `"\uE011"` `"Home"`
 `"\uE016"` `"Insert"`
 `"\uE00F"` `"PageDown"`
 `"\uE00E"` `"PageUp"`
 `"\uE015"` `"ArrowDown"`
 `"\uE012"` `"ArrowLeft"`
 `"\uE014"` `"ArrowRight"`
 `"\uE013"` `"ArrowUp"`
 `"\uE00C"` `"Escape"`
 `"\uE031"` `"F1"`
 `"\uE032"` `"F2"`
 `"\uE033"` `"F3"`
 `"\uE034"` `"F4"`
 `"\uE035"` `"F5"`
 `"\uE036"` `"F6"`
 `"\uE037"` `"F7"`
 `"\uE038"` `"F8"`
 `"\uE039"` `"F9"`
 `"\uE03A"` `"F10"`
 `"\uE03B"` `"F11"`
 `"\uE03C"` `"F12"`
 `"\uE019"` `"NumpadEqual"`
 `"\uE01A"` `"\uE05C"` `"Numpad0"`
 `"\uE01B"` `"\uE056"` `"Numpad1"`
 `"\uE01C"` `"\uE05B"` `"Numpad2"`
 `"\uE01D"` `"\uE055"` `"Numpad3"`
 `"\uE01E"` `"\uE058"` `"Numpad4"`
 `"\uE01F"` `"Numpad5"`
 `"\uE020"` `"\uE05A"` `"Numpad6"`
 `"\uE021"` `"\uE057"` `"Numpad7"`
 `"\uE022"` `"\uE059"` `"Numpad8"`
 `"\uE023"` `"\uE054"` `"Numpad9"`
 `"\uE025"` `"NumpadAdd"`
 `"\uE026"` `"NumpadComma"`
 `"\uE028"` `"\uE05D"` `"NumpadDecimal"`
 `"\uE029"` `"NumpadDivide"`
 `"\uE007"` `"NumpadEnter"`
 `"\uE024"` `"NumpadMultiply"`
 `"\uE027"` `"NumpadSubtract"`
 ------------ --------------- --------------------

The [key location] for `key` is the value
in the last column in the table below on the row with `key`
appears in the first column, if such a row exists, otherwise it is `0`.

 ------------------------------- ------------------- ----------
 `key`\'s codepoint Description Location
 `\uE007` Enter `1`
 `\uE008` Left Shift `1`
 `\uE009` Left Control `1`
 `\uE00A` Left Alt `1`
 `\uE019` Numpad = `3`
 `\uE01A` Numpad 0 `3`
 `\uE01B` Numpad 1 `3`
 `\uE01C` Numpad 2 `3`
 `\uE01D` Numpad 3 `3`
 `\uE01E` Numpad 4 `3`
 `\uE01F` Numpad 5 `3`
 `\uE020` Numpad 6 `3`
 `\uE021` Numpad 7 `3`
 `\uE022` Numpad 8 `3`
 `\uE023` Numpad 9 `3`
 `\uE024` Numpad \* `3`
 `\uE025` Numpad + `3`
 `\uE026` Numpad , `3`
 `\uE027` Numpad - `3`
 `\uE028` Numpad . `3`
 `\uE029` Numpad / `3`
 `\uE03D` Left Meta `1`
 `\uE050` Right Shift `2`
 `\uE051` Right Control `2`
 `\uE052` Right Alt `2`
 `\uE053` Right Meta `2`
 `\uE054` Numpad PageUp `3`
 `\uE055` Numpad PageDown `3`
 `\uE056` Numpad End `3`
 `\uE057` Numpad Home `3`
 `\uE058` Numpad ArrowLeft `3`
 `\uE059` Numpad ArrowUp `3`
 `\uE05A` Numpad ArrowRight `3`
 `\uE05B` Numpad ArrowDown `3`
 `\uE05C` Numpad Insert `3`
 `\uE05D` Numpad Delete `3`
 ------------------------------- ------------------- ----------

To [dispatch a keyDown action] given
`action object`, `source`,
`global key state`, `tick duration`,
`browsing context`, and `actions options`:

1. Let `raw key` be equal to the
 `action object`\'s `value` property.

2. Let `key` be equal to the [normalized key
 value](#dfn-normalized-key-value) for `raw key`.

3. If the `source`\'s `pressed` property contains
 `key`, let `repeat` be true, otherwise let
 `repeat` be false.

4. Let `code` be the [code](#dfn-code) for `raw key`.

5. Let `location` be the [key
 location](#dfn-key-location) for `raw key`.

6. Let `charCode`, `keyCode` and
 `which` be the implementation-specific values of the
 `charCode`, `keyCode` and `which` properties appropriate for a key
 with key `key` and location `location` on a
 102 key US keyboard, following the guidelines in
 \[[UI-EVENTS](#bib-ui-events "UI Events")\].

7. If `key` is `"Alt"`, let `source`\'s `alt`
 property be true.

8. If `key` is `"Shift"`, let `source`\'s `shift`
 property be true.

9. If `key` is `"Control"`, let `source`\'s
 `ctrl` property be true.

10. If `key` is `"Meta"`, let `source`\'s `meta`
 property be true.

11. Add `key` to `source`\'s `pressed` property.

12. [Perform implementation-specific action dispatch
 steps](#dfn-perform-implementation-specific-action-dispatch-steps) on `browsing context`
 equivalent to pressing a key on the keyboard in accordance with the
 requirements of \[[UI-EVENTS](#bib-ui-events "UI Events")\], and producing the following events, as
 appropriate, with the specified properties. This will always produce
 events including at least a `keyDown` event.

 - [`keyDown`](https://w3c.github.io/uievents/#keydown) with
 properties:
 --------------- -----------------------------------------
 Attribute Value
 `key` `key`
 `code` `code`
 `location` `location`
 `altKey` `source`\'s `alt` property
 `shiftKey` `source`\'s `shift` property
 `ctrlKey` `source`\'s `ctrl` property
 `metaKey` `source`\'s `meta` property
 `repeat` `repeat`
 `isComposing` `false`
 `charCode` `charCode`
 `keyCode` `keyCode`
 `which` `which`
 --------------- -----------------------------------------
 - [`keyPress`](https://w3c.github.io/uievents/#keypress) with
 properties:
 --------------- -----------------------------------------
 Attribute Value
 `key` `key`
 `code` `code`
 `location` `location`
 `altKey` `source`\'s `alt` property
 `shiftKey` `source`\'s `shift` property
 `ctrlKey` `source`\'s `ctrl` property
 `metaKey` `source`\'s `meta` property
 `repeat` `repeat`
 `isComposing` `false`
 `charCode` `charCode`
 `keyCode` `keyCode`
 `which` `which`
 --------------- -----------------------------------------

13. Return [success](#dfn-success) with data [`null`](#dfn-null).

A single [keyDown](#dfn-keydown) action produces a single key input, irrespective of how
long the key is held down; there is no implicit key repetition.

To [dispatch a keyUp action] given,
`action object`, `source`,
`global key state`, `tick duration`,
`browsing context`, and `actions options`:

1. Let `raw key` be equal to `action object`\'s
 `value` property.

2. Let `key` be equal to the [normalized key
 value](#dfn-normalized-key-value) for `raw key`.

3. If the `source`\'s `pressed` item does not contain
 `key`, return.

4. Let `code` be the [code](#dfn-code) for `raw key`.

5. Let `location` be the [key
 location](#dfn-key-location) for `raw key`.

6. Let `charCode`, `keyCode` and
 `which` be the implementation-specific values of the
 `charCode`, `keyCode` and `which` properties appropriate for a key
 with key `key` and location `location` on a
 102 key US keyboard, following the guidelines in
 \[[UI-EVENTS](#bib-ui-events "UI Events")\].

7. If `key` is \"`Alt`\", let `source`\'s `alt`
 property be false.

8. If `key` is \"`Shift`\", let `source`\'s
 `shift` property be false.

9. If `key` is `"Control"`, let `source`\'s
 `ctrl` property be false.

10. If `key` is `"Meta"`, let `source`\'s `meta`
 property be false.

11. Remove `key` from `sources`\'s `pressed`
 property.

12. [Perform implementation-specific action dispatch
 steps](#dfn-perform-implementation-specific-action-dispatch-steps) on `browsing context`
 equivalent to releasing a key on the keyboard in accordance with the
 requirements of \[[UI-EVENTS](#bib-ui-events "UI Events")\], and producing at least the following events
 with the specified properties:

 - [`keyup`](https://w3c.github.io/uievents/#keyup), with properties:
 --------------- ------------------------------------------
 Attribute Value
 `key` `key`
 `code` `code`
 `location` `location`
 `altKey` `source`\'s `altKey` property
 `shiftKey` `source`\'s `shift` property
 `ctrlKey` `source`\'s `ctrl` property
 `metaKey` `source`\'s `meta` property
 `repeat` `false`
 `isComposing` `false`
 `charCode` `charCode`
 `keyCode` `keyCode`
 `which` `which`
 --------------- ------------------------------------------

13. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
#### 15.6.3 Pointer actions

To [dispatch a pointerDown action] given
`action object`, `source`,
`global key state`, `tick duration`,
`browsing context`, and `actions options`:

1. Let `pointerType` be equal to
 `action object`\'s `pointerType` property.

2. Let `button` be equal to `action object`\'s
 `button` property.

3. If the `source`\'s `pressed` property contains
 `button` return
 [success](#dfn-success) with data [`null`](#dfn-null).

4. Let `x` be equal to `source`\'s `x` property.

5. Let `y` be equal to `source`\'s `y` property.

6. Add `button` to the set corresponding to
 `source`\'s `pressed` property, and let
 `buttons` be the resulting value of that property.

7. Let `width` be equal to `action object`\'s
 `width` property.

8. Let `height` be equal to `action object`\'s
 `height` property.

9. Let `pressure` be equal to `action object`\'s
 `pressure` property.

10. Let `tangentialPressure` be equal to
 `action object`\'s `tangentialPressure` property.

11. Let `tiltX` be equal to `action object`\'s
 `tiltX` property.

12. Let `tiltY` be equal to `action object`\'s
 `tiltY` property.

13. Let `twist` be equal to `action object`\'s
 `twist` property.

14. Let `altitudeAngle` be equal to
 `action object`\'s `altitudeAngle` property.

15. Let `azimuthAngle` be equal to
 `action object`\'s `azimuthAngle` property.

16. [Perform implementation-specific action dispatch
 steps](#dfn-perform-implementation-specific-action-dispatch-steps) on `browsing context`
 equivalent to pressing the button numbered `button` on
 the pointer with pointerId equal to `source`\'s
 pointerId, having type `pointerType` at viewport x
 coordinate `x`, viewport y coordinate `y`,
 `width`, `height`, `pressure`,
 `tangentialPressure`, `tiltX`,
 `tiltY`, `twist`, `altitudeAngle`,
 `azimuthAngle`, with buttons `buttons`
 depressed in accordance with the requirements of
 \[[UI-EVENTS](#bib-ui-events "UI Events")\] and
 \[[POINTER-EVENTS](#bib-pointer-events "Pointer Events")\]. set `ctrlKey`, `shiftKey`, `altKey`, and
 `metaKey` equal to the corresponding items in
 `global key state`. Type specific properties for the
 pointer that are not exposed through the webdriver API must be set
 to the default value specified for hardware that doesn\'t support
 that property.

17. Return [success](#dfn-success) with data [`null`](#dfn-null).

To [dispatch a pointerUp action] given,
`action object`, `source`,
`global key state`, `tick duration`,
`browsing context`, and `actions options`:

1. Let `pointerType` be equal to
 `action object`\'s `pointerType` property.

2. Let `button` be equal to `action object`\'s
 `button` property.

3. If the `source`\'s `pressed` property does not contain
 `button`, return
 [success](#dfn-success) with data [`null`](#dfn-null).

4. Let `x` be equal to `source`\'s `x` property.

5. Let `y` be equal to `source`\'s `y` property.

6. Remove `button` from the set corresponding to
 `source`\'s `pressed` property, and let
 `buttons` be the resulting value of that property.

7. [Perform implementation-specific action dispatch
 steps](#dfn-perform-implementation-specific-action-dispatch-steps) on `browsing context`
 equivalent to releasing the button numbered `button` on
 the pointer with pointerId equal to `input source`\'s
 pointerId, having type `pointerType` at viewport x
 coordinate `x`, viewport y coordinate `y`,
 with buttons `buttons` depressed, in accordance with the
 requirements of \[[UI-EVENTS](#bib-ui-events "UI Events")\] and
 \[[POINTER-EVENTS](#bib-pointer-events "Pointer Events")\]. The generated events must set `ctrlKey`,
 `shiftKey`, `altKey`, and `metaKey` equal to the corresponding items
 in `global key state`. Type specific properties for the
 pointer that are not exposed through the webdriver API must be set
 to the default value specified for hardware that doesn\'t support
 that property.

8. Return [success](#dfn-success) with data [`null`](#dfn-null).

To [dispatch a pointerMove action] given
`action object`, `source`,
`global key state`, `tick duration`,
`browsing context`, and `actions options`:

1. Let `x offset` be equal to the `x` property of
 `action object`.

2. Let `y offset` be equal to the `y` property of
 `action object`.

3. Let `origin` be equal to the `origin` property of
 `action object`.

4. Let (`x`, `y`) be the result of
 [trying](#dfn-try) to [get coordinates relative to an
 origin](#dfn-get-coordinates-relative-to-an-origin) with `source`,
 `x offset`, `y offset`, `origin`,
 `browsing context`, and `actions options`.

5. If `x` is less than 0 or greater than the width of the
 viewport in [CSS pixels](#dfn-css-pixels), then return
 [error](#dfn-error) with error code [move target out of
 bounds](#dfn-move-target-out-of-bounds).

6. If `y` is less than 0 or greater than the height of the
 viewport in [CSS pixels](#dfn-css-pixels), then return
 [error](#dfn-error) with error code [move target out of
 bounds](#dfn-move-target-out-of-bounds).

7. Let `duration` be equal to `action object`\'s
 `duration` property if it is not
 [undefined](#dfn-undefined), or `tick duration` otherwise.

8. If `duration` is greater than 0 and inside any
 implementation-defined bounds, [asynchronously
 wait](#dfn-asynchronously-wait) for an implementation defined amount
 of time to pass.

 This wait allows the implementation to model the overall pointer
 move as a series of small movements occurring at an implementation
 defined rate (e.g. one movement per vsync).

9. Let `width` be equal to `action object`\'s
 `width` property.

10. Let `height` be equal to `action object`\'s
 `height` property.

11. Let `pressure` be equal to `action object`\'s
 `pressure` property.

12. Let `tangentialPressure` be equal to
 `action object`\'s `tangentialPressure` property.

13. Let `tiltX` be equal to `action object`\'s
 `tiltX` property.

14. Let `tiltY` be equal to `action object`\'s
 `tiltY` property.

15. Let `twist` be equal to `action object`\'s
 `twist` property.

16. Let `altitudeAngle` be equal to
 `action object`\'s `altitudeAngle` property.

17. Let `azimuthAngle` be equal to
 `action object`\'s `azimuthAngle` property.

18. [Perform a pointer
 move](#dfn-perform-a-pointer-move) with arguments `source`,
 `global key state`, `duration`,
 `start x`, `start y`, `x`,
 `y`, `width`, `height`,
 `pressure`, `tangentialPressure`,
 `tiltX`, `tiltY`, `twist`,
 `altitudeAngle`, `azimuthAngle`.

19. Return [success](#dfn-success) with data [`null`](#dfn-null).

To [perform a pointer move] given
`source`, `global key state`,
`duration`, `start x`, `start y`,
`target x`, `target y`, `width`,
`height`, `pressure`,
`tangentialPressure`, `tiltX`, `tiltY`,
`twist`, `altitudeAngle`, and
`azimuthAngle`:

1. Let `time delta` be the time since the beginning of the
 current [tick](#dfn-ticks), measured in milliseconds on a monotonic clock.

2. Let `duration ratio` be the ratio of
 `time delta` and `duration`, if
 `duration` is greater than 0, or 1 otherwise.

3. If `duration ratio` is 1, or close enough to 1 that the
 implementation will not further subdivide the move action, let
 `last` be true. Otherwise let `last` be
 `false`.

4. If `last` is true, let `x` equal
 `target x` and `y` equal
 `target y`.

 Otherwise let `x` equal an approximation to
 `duration ratio` × (`target x` -
 `start x`) + `start x`, and `y`
 equal an approximation to `duration ratio` ×
 (`target y` - `start y`) +
 `start y`.

5. Let `current x` equal the `x` property of
 `input state`.

6. Let `current y` equal the `y` property of
 `input state`.

7. If `x` is not equal to `current x` or
 `y` is not equal to `current y`, run the
 following steps:

 1. Let `buttons` be equal to input state\'s `buttons`
 property.

 2. [Perform implementation-specific action dispatch
 steps](#dfn-perform-implementation-specific-action-dispatch-steps) on `browsing context`
 equivalent to moving the pointer with pointerId equal to
 `input source`\'s pointerId, having type
 `pointerType` from viewport x coordinate
 `current x`, viewport y coordinate
 `current y` to viewport x coordinate `x`
 and viewport y coordinate `y`, `width`,
 `height`, `pressure`,
 `tangentialPressure`, `tiltX`,
 `tiltY`, `twist`,
 `altitudeAngle`, `azimuthAngle`, with
 buttons `buttons` depressed, in accordance with the
 requirements of
 \[[UI-EVENTS](#bib-ui-events "UI Events")\] and
 \[[POINTER-EVENTS](#bib-pointer-events "Pointer Events")\]. The generated events must set `ctrlKey`,
 `shiftKey`, `altKey`, and `metaKey` equal to the corresponding
 items in `global key state`. Type specific properties
 for the pointer that are not exposed through the WebDriver API
 must be set to the default value specified for hardware that
 doesn\'t support that property. In the case where the
 `pointerType` is \"`pen`\" or \"`touch`\", and
 `buttons` is empty, this may be a no-op. For a
 pointer of type \"`mouse`\" this will always produce events
 including at least a `pointerMove` event.

 3. Let `input state`\'s `x` property equal
 `x` and `y` property equal `y`.

8. If `last` is true, return.

9. Run the following substeps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 ::::
 :::
 Note
 :::

 This algorithm may trigger multiple events spread across some
 duration. Parallelism is applied intentionally in order to manage
 the scheduling of these events relative to the events triggered by
 other actions in the same tick.

 The initial pointer movement is performed synchronously. This
 ensures determinism in the sequence of the first event triggered by
 each action in the tick.

 Subsequent movements (if any) are performed asynchronously. This
 allows events from two
 [pointerMove](#dfn-pointermove) actions in the tick to be
 interspersed.
 ::::

 1. [Asynchronously
 wait](#dfn-asynchronously-wait) for an implementation defined
 amount of time to pass.

 This wait allows the implementation to model the overall pointer
 move as a series of small movements occurring at an
 implementation defined rate (e.g. one movement per vsync).

 2. [Perform a pointer
 move](#dfn-perform-a-pointer-move) with arguments
 `input state`, `duration`,
 `start x`, `start y`,
 `target x`, `target y`.

To [dispatch a pointerCancel
action] given `action object`,
`source`, `global key state`,
`tick duration`, `browsing context`, and
`actions options`:

1. [Perform implementation-specific action dispatch
 steps](#dfn-perform-implementation-specific-action-dispatch-steps) on `browsing context`
 equivalent to cancelling the any action of the pointer with
 pointerId equal to `source`\'s pointerId item. having
 type `pointerType`, in accordance with the requirements
 of \[[UI-EVENTS](#bib-ui-events "UI Events")\] and
 \[[POINTER-EVENTS](#bib-pointer-events "Pointer Events")\].

2. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
#### 15.6.4 Wheel actions

To [dispatch a scroll action] given
`action object`, `source`,
`global key state`, `tick duration`,
`browsing context`, and `actions options`:

1. Let `x offset` be equal to the `x` property of
 `action object`.

2. Let `y offset` be equal to the `y` property of
 `action object`.

3. Let `origin` be equal to the `origin` property of
 `action object`.

4. Let (`x`, `y`) be the result of
 [trying](#dfn-try) to [get coordinates relative to an
 origin](#dfn-get-coordinates-relative-to-an-origin) with `source`,
 `x offset`, `y offset`, `origin`,
 `browsing context`, and `actions options`.

5. If `x` is less than 0 or greater than the width of the
 viewport in [CSS pixels](#dfn-css-pixels), then return
 [error](#dfn-error) with error code [move target out of
 bounds](#dfn-move-target-out-of-bounds).

6. If `y` is less than 0 or greater than the height of the
 viewport in [CSS pixels](#dfn-css-pixels), then return
 [error](#dfn-error) with error code [move target out of
 bounds](#dfn-move-target-out-of-bounds).

7. Let `delta x` be equal to the `deltaX` property of
 `action object`.

8. Let `delta y` be equal to the `deltaY` property of
 `action object`.

9. Let `duration` be equal to `action object`\'s
 `duration` property if it is not
 [undefined](#dfn-undefined), or `tick duration` otherwise.

10. If `duration` is greater than 0 and inside any
 implementation-defined bounds, [asynchronously
 wait](#dfn-asynchronously-wait) for an implementation defined amount
 of time to pass.

 This wait allows the implementation to model the overall wheel
 scroll as a series of small scroll occurring at an implementation
 defined rate (e.g. one scroll per vsync).

11. [Perform a
 scroll](#dfn-perform-a-scroll) with arguments
 `global key state`, `duration`,
 `x`, `y`, `delta x`,
 `delta y`, `0`, `0`.

12. Return [success](#dfn-success) with data [`null`](#dfn-null).

To [perform a scroll] given `duration`,
`x`, `y`, `target delta x`,
`target delta y`, `current delta x` and
`current delta y`:

1. Let `time delta` be the time since the beginning of the
 current [tick](#dfn-ticks), measured in milliseconds on a monotonic clock.

2. Let `duration ratio` be the ratio of
 `time delta` and `duration`, if
 `duration` is greater than 0, or 1 otherwise.

3. If `duration ratio` is 1, or close enough to 1 that the
 implementation will not further subdivide the move action, let
 `last` be true. Otherwise let `last` be
 `false`.

4. If `last` is true, let `delta x` equal
 `target delta x` - `current delta x` and
 `delta y` equal `target delta y` -
 `current delta y`.

 Otherwise let `delta x` equal an approximation to
 `duration ratio` × `target delta x` -
 `current delta x`, and `delta y` equal an
 approximation to `duration ratio` ×
 `target delta y` - `current delta y`.

5. If `delta x` is not equal to `0` or
 `delta y` is not equal to `0`, run the
 following steps:

 1. [Perform implementation-specific action dispatch
 steps](#dfn-perform-implementation-specific-action-dispatch-steps) on `browsing context`
 equivalent to wheel scroll at viewport x coordinate
 `x`, viewport y coordinate `y`, deltaX
 value `delta x`, deltaY value `delta y`,
 in accordance with the requirements of
 \[[UI-EVENTS](#bib-ui-events "UI Events")\]. The generated events must set `ctrlKey`,
 `shiftKey`, `altKey`, and `metaKey` equal to the corresponding
 items in `global key state`.

 2. Let `current delta x` property equal `delta x` +
 `current delta x` and `current delta y` property
 equal `delta y` + `current delta y`.

6. If `last` is true, return.

7. Run the following substeps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 ::::
 :::
 Note
 :::

 This algorithm may trigger multiple events spread across some
 duration. Parallelism is applied intentionally in order to manage
 the scheduling of these events relative to the events triggered by
 other actions in the same tick.

 The initial scroll is performed synchronously. This ensures
 determinism in the sequence of the first event triggered by each
 action in the tick.

 Subsequent scrolls (if any) are performed asynchronously. This
 allows events from two [scroll](#dfn-scroll) actions in the tick to be
 interspersed.
 ::::

 1. [Asynchronously
 wait](#dfn-asynchronously-wait) for an implementation defined
 amount of time to pass.

 This wait allows the implementation to model the overall scroll
 as a series of small scrolls occurring at an implementation
 defined rate (e.g. one scroll per vsync).

 2. [Perform a
 scroll](#dfn-perform-a-scroll) with arguments
 `duration`, `x`, `y`,
 `target delta x`, `target delta y`,
 `current delta x`, `current delta y`.

::: header-wrapper
### 15.7 [Perform Actions]

------------- --------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/actions
 ------------- --------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try)
 to [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `input state` be the result of [get the input
 state](#dfn-get-the-input-state) with `session` and
 `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context).

4. Let `actions options` be a new [actions
 options](#dfn-actions-options) with the [is element
 origin](#dfn-is-element-origin) steps set to [represents a web
 element](#dfn-represents-a-web-element), and the [get element
 origin](#dfn-get-element-origin) steps set to [get a WebElement
 origin](#dfn-get-a-webelement-origin).

5. Let `actions by tick` be the result of
 [trying](#dfn-try) to [extract an action
 sequence](#dfn-extract-an-action-sequence) with `input state`,
 `parameters`, and `actions options`.

6. [Dispatch
 actions](#dfn-dispatch-actions) with `input state`,
 `actions by tick`, [current browsing
 context](#dfn-current-browsing-context), and `actions options`. If
 this results in an [error](#dfn-error) return that error.

7. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
### 15.8 [Release Actions]

------------- --------------------------------------------
 HTTP Method URI Template
 DELETE /session/{`session id`}/actions
 ------------- --------------------------------------------

The [Release
Actions](#dfn-release-actions)
[command](#dfn-commands) is used to release all the keys and pointer buttons
that are currently depressed. This causes events to be
[fired](https://dom.spec.whatwg.org/#concept-event-fire) as if the state was released by an
explicit series of actions. It also clears all the internal state of the
virtual devices.

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try)
 to [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `input state` be the result of [get the input
 state](#dfn-get-the-input-state) with
 [session](#dfn-sessions) and [current top-level browsing
 context](#dfn-current-top-level-browsing-context).

4. Let `actions options` be a new [actions
 options](#dfn-actions-options) with the [is element
 origin](#dfn-is-element-origin) steps set to [represents a web
 element](#dfn-represents-a-web-element), and the [get element
 origin](#dfn-get-element-origin) steps set to [get a WebElement
 origin](#dfn-get-a-webelement-origin).

5. [Wait for an action queue
 token](#dfn-wait-for-an-action-queue-token) with `input state`.

6. Let `undo actions` be `input state`\'s [input
 cancel
 list](#dfn-input-cancel-list) in reverse order.

7. [Try](#dfn-try)
 to [dispatch
 actions](#dfn-dispatch-actions) with `input state`,
 `undo actions`, [current browsing
 context](#dfn-current-browsing-context), and `actions options`.

8. [Reset the input
 state](#dfn-reset-the-input-state) with `session` and
 `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context).

9. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
## 16. User prompts

This chapter describes interaction with various types of [user
prompts](#dfn-user-prompts). The common denominator for user prompts is that they
are modal windows requiring users to interact with them before the
[event loop](#dfn-event-loop) is [unpaused](#dfn-unpaused) and control is returned to
`session`\'s [current top-level browsing
context](#dfn-current-top-level-browsing-context).

By default [user prompts](#dfn-user-prompts) are not handled automatically unless a
[user prompt
handler](#dfn-user-prompt-handler) has been defined. When a [user
prompt](#dfn-user-prompts) appears, it is the task of the subsequent
[command](#dfn-commands) to handle it. If the subsequent requested
[command](#dfn-commands) is not one listed in this chapter, an [unexpected alert
open](#dfn-unexpected-alert-open) [error](#dfn-error) will be returned.

Whenever [active
sessions](#dfn-active-sessions) is a list containing exactly one item, and
that item is a [HTTP
session](#dfn-http-session), but is not a [BiDi
session](https://www.w3.org/TR/webdriver-bidi/#bidi-session), then in the [steps to fire
beforeunload](#dfn-steps-to-fire-beforeunload), implementations must act as if showing an
unload prompt is likely to be annoying, deceptive, or pointless.

This means that beforeunload prompts are never shown when there\'s an
active HTTP-only session.

A [user prompt](#dfn-user-prompts) has an associated [user prompt
message] that is the string message shown
to the user, or [`null`](#dfn-null) if the message length is `0`.

To [get the active user prompt] given
`browsing context: `

1. Let `agent` be [browsing
 context](#dfn-browsing-contexts)\'s [active
 document](#dfn-active-document)\'s [relevant
 agent](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-agent).

2. If `agent`\'s [event
 loop](#dfn-event-loop) is not currently
 [paused](https://html.spec.whatwg.org/multipage/webappapis.html#pause), return null.

3. Return the [user
 prompt](#dfn-user-prompts) which handles the input required to meet the
 condition passed when `event loop` was
 [paused](https://html.spec.whatwg.org/multipage/webappapis.html#pause).

The [current user prompt] is the result of [get the active
user
prompt](#dfn-get-the-active-user-prompt) with [current browsing
context](#dfn-current-browsing-context).

To [dismiss] a [user
prompt](#dfn-user-prompts), act as if the user clicked the **Cancel** button on
that prompt, if present, or otherwise
[accept](#dfn-accepting) the prompt.

To [accept] a [user
prompt](#dfn-user-prompts), act as if the user clicked the **OK** button on that
prompt.

::: header-wrapper
### 16.1 User Prompt Handler

A [remote end](#dfn-remote-ends) has a [user prompt
handler] which defines how a WebDriver
session will react when a user prompt is displayed. It is either null or
a
[map](https://infra.spec.whatwg.org/#ordered-map) between strings and [prompt handler
configuration](#dfn-prompt-handler-configuration) values. Initially it is null.

A [prompt handler configuration] is a
[struct](https://infra.spec.whatwg.org/#struct) with two items; a [handler], which is a string, and a
[notify], which is a boolean.

To [serialize a prompt handler
configuration] given
`configuration`:

1. Let `serialized` be `configuration`\'s
 [handler](#dfn-handler).

2. If «\"`dismiss`\", \"`accept`\"»
 [contains](https://infra.spec.whatwg.org/#list-contain) `serialized`, and
 `configuration`\'s
 [notify](#dfn-notify) is true, append \"` and notify`\" to
 `serialized`.

3. Return `serialized`.

The [known prompt handlers] are:

 ----------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 [Handler key] Description (non-normative).
 \"`dismiss`\" All [simple dialogs](#dfn-simple-dialog) encountered should be [dismissed](#dfn-dismissed).
 \"`accept`\" All [simple dialogs](#dfn-simple-dialog) encountered should be [accepted](#dfn-accepting).
 \"`dismiss and notify`\" All [simple dialogs](#dfn-simple-dialog) encountered should be [dismissed](#dfn-dismissed), and an error returned that the dialog was handled.
 \"`accept and notify`\" All [simple dialogs](#dfn-simple-dialog) encountered should be [accepted](#dfn-accepting), and an error returned that the dialog was handled.
 \"`ignore`\" All [simple dialogs](#dfn-simple-dialog) encountered should be left to the user to handle.
 ----------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

The [valid prompt types] are «\"`alert`\",
\"`beforeUnload`\", \"`confirm`\", \"`default`\", \"`file`\",
\"`prompt`\"».

The \"`default`\" type represents a fallback when no specific handler is
defined for a given prompt type, including the \"`beforeUnload`\" prompt
type. It can only be set if the unhandled prompt behavior is a
[map](https://infra.spec.whatwg.org/#ordered-map) which
[contains](https://infra.spec.whatwg.org/#map-exists) \"`default`\". For HTTP-only sessions setting unhandled
prompt behavior as a string value, the value will be assigned to the
internal type \"`fallbackDefault`\". The \"`fallbackDefault`\" value is
not used for the \"`beforeUnload`\" prompt type, instead it falls back
to the \"`accept`\" handler. This is because HTTP-only sessions do not
allow the \"`beforeUnload`\" handler to be customized, and enabling
other protocols isn\'t expected to change the user prompt handling as a
side effect.

The \"`file`\" prompt type is respected only in
\[[WebDriver-BiDi](#bib-webdriver-bidi "WebDriver BiDi")\] sessions.

To [deserialize as an unhandled prompt
behavior] given argument
`value`:

1. Set
 `value to the result of `[`converting a JSON-derived JavaScript value to an Infra value`](#dfn-converting-a-json-derived-javascript-value-to-an-infra-value)` with ``value``. `

2. If `value` is not a string, an implementation that does
 not also support
 \[[WebDriver-BiDi](#bib-webdriver-bidi "WebDriver BiDi")\] may return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 ::::
 :::
 Note
 :::

 This is to avoid
 \[[WebDriver-BiDi](#bib-webdriver-bidi "WebDriver BiDi")\] monkey-patching the current spec.
 ::::

3. Let `is string value` be false.

4. If `value` is a
 [string](#dfn-string) set `value` to the
 [map](https://infra.spec.whatwg.org/#ordered-map) «\[\"`fallbackDefault`\" → `value`\]»
 and set `is string value` to true.

5. If `value` is not a
 [map](https://infra.spec.whatwg.org/#ordered-map) return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

6. Let `user prompt handler` be an empty
 [map](https://infra.spec.whatwg.org/#ordered-map).

7. For each `prompt type` → `handler` in
 `value`:

 1. If `is string value` is false and [valid prompt
 types](#dfn-valid-prompt-types) does not
 [contain](https://infra.spec.whatwg.org/#map-exists) `prompt type` return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 2. If [known prompt
 handlers](#dfn-known-prompt-handlers) does not contain an entry with
 [handler key](#dfn-handler-key) `handler` return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 3. Let `notify` be false.

 4. If `handler` is \"`accept and notify`\", set
 `handler`` to "``accept``" and ``notify`` to true. `

 5. If `handler` is \"`dismiss and notify`\", set
 `handler`` to "``dismiss``" and ``notify`` to true. `

 6. If `handler` is \"`ignore`\", set `notify`
 to true.

 7. Let `configuration` be a [prompt handler
 configuration](#dfn-prompt-handler-configuration) with
 [handler](#dfn-handler) `handler` and
 [notify](#dfn-notify) `notify`.

 8. [Set](https://infra.spec.whatwg.org/#map-set)
 `user prompt handler`\[`prompt type`\] to
 `configuration`.

8. Return [success](#dfn-success) with data `user prompt handler`.

To [check user prompt handler
matches] given
`requested prompt handler`:

1. If the [user prompt
 handler](#dfn-user-prompt-handler) is null, return true.

2. For each `request prompt type` →
 `request handler` in
 `requested prompt handler`:

 1. If the [user prompt
 handler](#dfn-user-prompt-handler)
 [contains](https://infra.spec.whatwg.org/#map-exists) `request prompt type`:

 1. If the `requested prompt handler`\'s
 [handler](#dfn-handler) is not equal to the [user
 prompt
 handler](#dfn-user-prompt-handler)\'s
 [handler](#dfn-handler), return false.

3. Return true

This does not check the `requested prompt handler`\'s
[notify](#dfn-notify) matches the
[handler](#dfn-handler), because the
[notify](#dfn-notify) component only affects the [HTTP
session](#dfn-http-session), if any.

To [update the user prompt handler] given
`requested prompt handler`:

1. If the [user prompt
 handler](#dfn-user-prompt-handler) is null, set the [user prompt
 handler](#dfn-user-prompt-handler) to an empty map.

2. For each `request prompt type` →
 `request handler` in
 `requested prompt handler`:

 1. Set [user prompt
 handler](#dfn-user-prompt-handler)\[`request prompt type`\] to
 `request handler`.

To [serialize the user prompt
handler]:

1. If the [user prompt
 handler](#dfn-user-prompt-handler) is null, return
 \"`dismiss and notify`\".

2. If the [user prompt
 handler](#dfn-user-prompt-handler) has
 [size](https://infra.spec.whatwg.org/#map-size) 1, and [user prompt
 handler](#dfn-user-prompt-handler)
 [contains](https://infra.spec.whatwg.org/#list-contain) \"`fallbackDefault`\", return the result of
 [serialize a prompt handler
 configuration](#dfn-serialize-a-prompt-handler-configuration) with [user prompt
 handler](#dfn-user-prompt-handler)\[\"`fallbackDefault`\"\].

3. Let `serialized` be an empty
 [map](https://infra.spec.whatwg.org/#ordered-map).

4. For each `key` → `value` of [user prompt
 handler](#dfn-user-prompt-handler):

 1. Set `serialized`\[`key`\] to [serialize a
 prompt handler
 configuration](#dfn-serialize-a-prompt-handler-configuration) with `value`.

5. Return [convert an Infra value to a JSON-compatible JavaScript
 value](#dfn-convert-an-infra-value-to-a-json-compatible-javascript-value) with `serialized`.

An [annotated unexpected alert open
error] is an
[error](#dfn-error)
with [error code](#dfn-error-code) [unexpected alert
open](#dfn-unexpected-alert-open) and an optional [error
data](#dfn-error-data) dictionary with the following entries:

\"`text`\"
: The [current user
 prompt](#dfn-current-user-prompt)\'s
 [message](#dfn-user-prompt-message).

To [get the prompt handler]
`type`:

1. If the [user prompt
 handler](#dfn-user-prompt-handler) is null, let `handlers` be
 an empty map. Otherwise let `handlers` be [user prompt
 handler](#dfn-user-prompt-handler).

2. If `handlers` contains `type` return
 `handlers`\[`type`\].

3. If `handlers` contains \"`default`\" return
 `handlers`\[\"`default`\"\].

4. If `type` is \"`beforeUnload`\", return a [prompt handler
 configuration](#dfn-prompt-handler-configuration) with
 [handler](#dfn-handler) \"`accept`\" and
 [notify](#dfn-notify) false.

5. If `handlers` contains \"`fallbackDefault`\" return
 `handlers`\[\"`fallbackDefault`\"\].

6. Return a [prompt handler
 configuration](#dfn-prompt-handler-configuration) with
 [handler](#dfn-handler) \"`dismiss`\" and
 [notify](#dfn-notify) true.

To [handle any user prompts]:

1. If the [current browsing
 context](#dfn-current-browsing-context) is not blocked by a dialog return
 [success](#dfn-success).

2. Let `type` be \"`default`\".

3. If the [current user
 prompt](#dfn-current-user-prompt) is an alert dialog, set
 `type` to \"`alert`\". Otherwise, if the [current user
 prompt](#dfn-current-user-prompt) is a beforeunload dialog, set
 `type` to \"`beforeUnload`\". Otherwise, if the [current
 user
 prompt](#dfn-current-user-prompt) is a confirm dialog, set
 `type` to \"`confirm`\". Otherwise, if the [current user
 prompt](#dfn-current-user-prompt) is a prompt dialog, set
 `type` to \"`prompt`\".

4. Let `handler` be [get the prompt
 handler](#dfn-get-the-prompt-handler) with `type`.

5. Perform the following substeps based on `handler`\'s
 [handler](#dfn-handler):

 \"`accept`\"

 : [Accept](#dfn-accepting) the [current user
 prompt](#dfn-current-user-prompt).

 \"`dismiss`\"

 : [Dismiss](#dfn-dismissed) the [current user
 prompt](#dfn-current-user-prompt).

 \"`ignore`\"

 : Do nothing.

6. If `handler`\'s
 [notify](#dfn-notify) is true, return [annotated unexpected
 alert open
 error](#dfn-annotated-unexpected-alert-open-error).

7. Return [success](#dfn-success).

[Example 12](#example-12)

When returning an [error](#dfn-error) with [unexpected alert
open](#dfn-unexpected-alert-open), a [remote
end](#dfn-remote-ends) may choose to return the [user prompt
message](#dfn-user-prompt-message) as part of an additional \"`data`\"
[Object](#dfn-object) on the [error
representation](#dfn-send-an-error):

```

{
 "error": "unexpected alert open",
 "message": "implementation defined",
 "stacktrace": "",
 "data": {
 "text": "the text from the alert"
 }
}
```

::: header-wrapper
### 16.2 [Dismiss Alert]

------------- --------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/alert/dismiss
 ------------- --------------------------------------------------

The [Dismiss Alert](#dfn-dismiss-alert)
[command](#dfn-commands) [dismisses](#dfn-dismissed) a [simple
dialog](#dfn-simple-dialog) if
[present](#dfn-current-user-prompt). A request to
[dismiss](#dfn-dismissed) an alert [user
prompt](#dfn-user-prompts), which may not necessarily have a dismiss button, has
the same effect as [accepting](#dfn-accepting) it.

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. If the [current user
 prompt](#dfn-current-user-prompt) is null, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 alert](#dfn-no-such-alert).

3. [Dismiss](#dfn-dismissed) the [current user
 prompt](#dfn-current-user-prompt).

4. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
### 16.3 [Accept Alert]

------------- -------------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/alert/accept
 ------------- -------------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. If the [current user
 prompt](#dfn-current-user-prompt) is null, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 alert](#dfn-no-such-alert).

3. [Accept](#dfn-accepting) the [current user
 prompt](#dfn-current-user-prompt).

4. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
### 16.4 [Get Alert Text]

------------- -----------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/alert/text
 ------------- -----------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. If the [current user
 prompt](#dfn-current-user-prompt) is null, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 alert](#dfn-no-such-alert).

3. Let `message` be the text message associated with the
 [current user
 prompt](#dfn-current-user-prompt), or otherwise be
 [`null`](#dfn-null).

4. Return [success](#dfn-success) with data `message`.

::: header-wrapper
### 16.5 [Send Alert Text]

------------- -----------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/alert/text
 ------------- -----------------------------------------------

The [Send Alert
Text](#dfn-send-alert-text) [command](#dfn-commands) sets the text field of a
[window.`prompt`](#dfn-window-prompt) [user
prompt](#dfn-user-prompts) to the given value.

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. Let `text` be the result of [getting the
 property](#dfn-getting-properties) \"`text`\" from
 `parameters`.

2. If `text` is not a
 [String](#dfn-string), return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

3. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

4. If the [current user
 prompt](#dfn-current-user-prompt) is null, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 alert](#dfn-no-such-alert).

5. Run the substeps for the API that created the [current user
 prompt](#dfn-current-user-prompt):

 [`window.alert`](#dfn-window-alert)\
 [`window.confirm`](#dfn-window-confirm)

 : Return [error](#dfn-error) with [error
 code](#dfn-error-code) [element not
 interactable](#dfn-element-not-interactable).

 [`window.prompt`](#dfn-window-prompt)

 : Do nothing.

 Otherwise

 : Return [error](#dfn-error) with [error
 code](#dfn-error-code) [unsupported
 operation](#dfn-unsupported-operation).

6. Perform user agent dependent steps to set the value of [current user
 prompt](#dfn-current-user-prompt)\'s text field to `text`.

7. Return [success](#dfn-success) with data [`null`](#dfn-null).

::: header-wrapper
## 17. Screen capture

Screenshots are a mechanism for providing additional visual diagnostic
information. They work by dumping a snapshot of the [initial
viewport](#dfn-viewport)\'s framebuffer as a lossless PNG image. It is returned
to the [local end](#dfn-local-ends) as a Base64 encoded string.

WebDriver provides the [Take
Screenshot](#dfn-take-screenshot)
[command](#dfn-commands) to capture the [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context)\'s [initial
viewport](#dfn-viewport), and a
[command](#dfn-commands) [Take Element
Screenshot](#dfn-take-element-screenshot) for doing the same with the visible region
of an
[element](https://dom.spec.whatwg.org/#concept-element)\'s [bounding
rectangle](#dfn-bounding-rectangle) after it has been [scrolled into
view](#dfn-scrolls-into-view).

In order to [draw a bounding box from the
framebuffer], given a
[rectangle](#dfn-bounding-rectangle):

1. If either the [initial
 viewport](#dfn-viewport)\'s width or height is 0 [CSS
 pixels](#dfn-css-pixels), return [error](#dfn-error) with [error
 code](#dfn-error-code) [unable to capture
 screen](#dfn-unable-to-capture-screen).

2. Let `paint width` be the [initial
 viewport](#dfn-viewport)\'s width -- [min](#dfn-min)([rectangle x
 coordinate](#dfn-x-coordinate), [rectangle x
 coordinate](#dfn-x-coordinate) + [rectangle width
 dimension](#dfn-width-dimension)).

3. Let `paint height` be the [initial
 viewport](#dfn-viewport)\'s height -- [min](#dfn-min)([rectangle y
 coordinate](#dfn-y-coordinate), [rectangle y
 coordinate](#dfn-y-coordinate) + [rectangle height
 dimension](#dfn-height-dimension)).

4. Let `canvas` be a new
 [`canvas`](https://html.spec.whatwg.org/multipage/canvas.html#canvas) element, and set its
 [`width`](https://html.spec.whatwg.org/multipage/canvas.html#attr-canvas-width) and
 [`height`](https://html.spec.whatwg.org/multipage/canvas.html#attr-canvas-height) to `paint width` and
 `paint height`, respectively.

5. Let `context`, a [canvas context
 mode](#dfn-canvas-context-mode), be the result of invoking the [2D
 context creation
 algorithm](#dfn-2d-context-creation-algorithm) given `canvas` as the
 target.

6. Complete implementation specific steps equivalent to drawing the
 region of the framebuffer specified by the following coordinates
 onto `context`:

 X coordinate
 : [rectangle x
 coordinate](#dfn-x-coordinate)

 Y coordinate
 : [rectangle y
 coordinate](#dfn-y-coordinate)

 Width
 : `paint width`

 Height
 : `paint height`

7. Return [success](#dfn-success) with `canvas`.

To [encode a canvas as Base64 a `canvas`
[element](https://dom.spec.whatwg.org/#concept-element)]:

1. If the
 [`canvas`](https://html.spec.whatwg.org/multipage/canvas.html#canvas) element\'s bitmap\'s
 [origin-clean](#dfn-origin-clean) flag is set to false, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [unable to capture
 screen](#dfn-unable-to-capture-screen).

2. If the
 [`canvas`](https://html.spec.whatwg.org/multipage/canvas.html#canvas) element\'s bitmap has no pixels (i.e. either
 its horizontal dimension or vertical dimension is zero) then return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [unable to capture
 screen](#dfn-unable-to-capture-screen).

3. Let `file` be [a serialization of the `canvas` element\'s
 bitmap as a
 file](#dfn-a-serialization-of-the-bitmap-as-a-file), using \"`image/png`\"
 as an argument.

4. Let `data URL` be a [`data:`
 URL](#dfn-data-url) representing `file`.
 \[[RFC2397](#bib-rfc2397 "The "data" URL scheme")\]

5. Let `index` be the [index
 of](#dfn-index-of) \"`,`\" in `data URL`.

6. Let `encoded string` be a
 [substring](#dfn-substring) of `data URL` using
 (`index` + 1) as the *start* argument.

7. Return [success](#dfn-success) with data `encoded string`.

::: header-wrapper
### 17.1 [Take Screenshot]

------------- -----------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/screenshot
 ------------- -----------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. When the user agent is next to [run the animation frame
 callbacks](#dfn-run-the-animation-frame-callbacks):

 1. Let `root rect` be `session`\'s [current
 top-level browsing
 context](#dfn-current-top-level-browsing-context)\'s [document
 element](https://dom.spec.whatwg.org/#document-element)\'s
 [rectangle](#dfn-bounding-rectangle).

 2. Let `screenshot result` be the result of
 [trying](#dfn-try) to call [draw a bounding box from the
 framebuffer](#dfn-draw-a-bounding-box-from-the-framebuffer), given `root rect` as
 an argument.

 3. Let `canvas` be a
 [`canvas`](https://html.spec.whatwg.org/multipage/canvas.html#canvas) element of
 `screenshot result`\'s data.

 4. Let `encoding result` be the result of
 [trying](#dfn-try) [encoding a canvas as
 Base64](#dfn-encoding-a-canvas-as-base64) `canvas`.

 5. Let `encoded string` be
 `encoding result`\'s data.

3. Return [success](#dfn-success) with data `encoded string`.

::: header-wrapper
### 17.2 [Take Element Screenshot]

------------- ---------------------------------------------------------------------------------
 HTTP Method URI Template
 GET /session/{`session id`}/element/{`element id`}/screenshot
 ------------- ---------------------------------------------------------------------------------

The [Take Element
Screenshot](#dfn-take-element-screenshot)
[command](#dfn-commands) takes a screenshot of the visible region encompassed by
the [bounding
rectangle](#dfn-bounding-rectangle) of an
[element](https://dom.spec.whatwg.org/#concept-element).

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current browsing
 context](#dfn-current-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try)
 to [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `element` be the result of
 [trying](#dfn-try) to [get a known
 element](#dfn-get-a-known-element) with `session` and
 `URL variables`\[\"`element id`\"\].

4. [Scroll into
 view](#dfn-scrolls-into-view) the `element`.

5. When the user agent is next to [run the animation frame
 callbacks](#dfn-run-the-animation-frame-callbacks):

 1. Let `element rect` be `element`\'s
 [rectangle](https://drafts.fxtf.org/geometry/#rectangle).

 2. Let `screenshot result` be the result of
 [trying](#dfn-try) to call [draw a bounding box from the
 framebuffer](#dfn-draw-a-bounding-box-from-the-framebuffer), given `element rect`
 as an argument.

 3. Let `canvas` be a
 [`canvas`](https://html.spec.whatwg.org/multipage/canvas.html#canvas) element of
 `screenshot result`\'s data.

 4. Let `encoding result` be the result of
 [trying](#dfn-try) [encoding a canvas as
 Base64](#dfn-encoding-a-canvas-as-base64) `canvas`.

 5. Let `encoded string` be
 `encoding result`\'s data.

6. Return [success](#dfn-success) with data `encoded string`.

::: header-wrapper
## 18. Print

The print functions are a mechanism to render the document to a
paginated format. It is returned to the [local
end](#dfn-local-ends) as a Base64 encoded string containing a PDF
representation of the paginated document.

When required to [parse a page range] with arguments
`pageRanges` and `totalPages`, an implementation
must:

1. Let `pages` be an empty
 [Set](https://infra.spec.whatwg.org/#ordered-set)
2. For each `range` in `pageRanges`, run the
 following steps:
 1. If `range` is not either a
 [Number](#dfn-number) or a
 [String](#dfn-string), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 2. If `range` is a
 [Number](#dfn-number):

 1. If `range` is not an integer or is less than 0,
 return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument)
 2. Append `range` to `pages`

 Otherwise:

 1. Let `rangeParts` be the result of splitting
 `range` on a \"`-`\" character.

 2. If `rangeParts` has fewer than 1 or more than 2
 elements, return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 3. If rangeParts has one element, append the result of
 [trying](#dfn-try) to [parse as an
 integer](#dfn-parse-as-an-integer) the first element of
 `rangeParts` to `pages`.

 Otherwise:

 1. If the first element of `rangeParts` is
 [equivalent to an empty
 string](#dfn-equivalent-to-an-empty-string), let
 `lowerBound` be `1`. Otherwise let
 `lowerBound` be the result of
 [trying](#dfn-try) to [parse as an
 integer](#dfn-parse-as-an-integer) the first element of
 `rangeParts`.
 2. If the second element of `rangeParts` is
 [equivalent to an empty
 string](#dfn-equivalent-to-an-empty-string) let
 `upperBound` be `totalPages`.
 Otherwise let `upperBound` be the result of
 [trying](#dfn-try) to [parse as an
 integer](#dfn-parse-as-an-integer) the second element of
 `rangeParts`.
 3. If `lowerBound` is greater than
 `upperBound`, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).
 4. Append all integers in the inclusive range
 `lowerBound` to `upperBound` to
 `pages`

 3. Return [success](#dfn-success) with data `pages`.

A [String](#dfn-string) is [equivalent to an empty
string] if it has zero length after
removing all [whitespace](#dfn-whitespace) characters.

When required to [parse as an integer] with argument
`input` an implementation must:

1. Let `stripped` be the result of stripping all leading and
 trailing [whitespace](#dfn-whitespace) characters from `input`.
2. If `stripped` has zero length, return
 [error](#dfn-error) with status [invalid
 argument](#dfn-invalid-argument).
3. If `stripped` contains any characters outside the range
 `U+0030` - `U+0039` (i.e. 0 - 9) inclusive, return
 [error](#dfn-error) with status [invalid
 argument](#dfn-invalid-argument).
4. Let `output` be the result of calling
 [parseInt](#dfn-parseint) with string `stripped` and radix `10`.
5. Return [success](#dfn-success) with data `output`.

::: header-wrapper
### 18.1 [Print Page]

------------- ------------------------------------------
 HTTP Method URI Template
 POST /session/{`session id`}/print
 ------------- ------------------------------------------

The [remote end
steps](#dfn-remote-end-steps), given `session`,
`URL variables` and `parameters` are:

1. If `session`\'s [current top-level browsing
 context](#dfn-current-top-level-browsing-context) is [no longer
 open](#dfn-no-longer-open), return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [no such
 window](#dfn-no-such-window).

2. [Try](#dfn-try)
 to [handle any user
 prompts](#dfn-handle-any-user-prompts) with `session`.

3. Let `orientation` be the result of [getting a property
 with
 default](#dfn-getting-the-property-with-default) named \"`orientation`\" and with
 default \"`portrait`\" from `parameters`.

4. If `orientation` is not a
 [String](#dfn-string) or does not have one of the values \"`landscape`\"
 or \"`portrait`\", return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

5. Let `scale` be the result of [getting a property with
 default](#dfn-getting-the-property-with-default) named \"`scale`\" and with default `1`
 from `parameters`.

6. If `scale` is not a
 [Number](#dfn-number), or is less than `0.1` or greater than `2` return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

7. Let `background` be the result of [getting a property
 with
 default](#dfn-getting-the-property-with-default) named \"`background`\" and with
 default `false` from `parameters`.

8. If `background` is not a
 [Boolean](#dfn-boolean) return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

9. Let `page` be the result of [getting a property with
 default](#dfn-getting-the-property-with-default) named \"`page`\" and with a default of
 an empty [Object](#dfn-object) from `parameters`.

10. Let `pageWidth` be the result of [getting a property with
 default](#dfn-getting-the-property-with-default) named \"`width`\" and with a default
 of `21.59` from `page`.

11. Let `pageHeight` be the result of [getting a property
 with
 default](#dfn-getting-the-property-with-default) named \"`height`\" and with a default
 of `27.94` from `page`.

12. If either of `pageWidth` or `pageHeight` is
 not a [Number](#dfn-number), or is less than `(2.54 / 72)`, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

 ::::
 :::
 Note
 :::

 The minimum page size is `1` point, which is `(2.54 / 72)` as per
 [absolute
 lengths](#dfn-absolute-lengths).
 ::::

13. Let `margin` be the result of [getting a property with
 default](#dfn-getting-the-property-with-default) named \"`margin`\" and with a default
 of an empty [Object](#dfn-object) from `parameters`.

14. Let `marginTop` be the result of [getting a property with
 default](#dfn-getting-the-property-with-default) named \"`top`\" and with a default of
 `1` from `margin`.

15. Let `marginBottom` be the result of [getting a property
 with
 default](#dfn-getting-the-property-with-default) named \"`bottom`\" and with a default
 of `1` from `margin`.

16. Let `marginLeft` be the result of [getting a property
 with
 default](#dfn-getting-the-property-with-default) named \"`left`\" and with a default of
 `1` from `margin`.

17. Let `marginRight` be the result of [getting a property
 with
 default](#dfn-getting-the-property-with-default) named \"`right`\" and with a default
 of `1` from `margin`.

18. If any of `marginTop`, `marginBottom`,
 `marginLeft`, or `marginRight` is not a
 [Number](#dfn-number), or is less then 0, return
 [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

19. Let `shrinkToFit` be the result of [getting a property
 with
 default](#dfn-getting-the-property-with-default) named \"`shrinkToFit`\" and with
 default `true` from `parameters`.

20. If `shrinkToFit` is not a
 [Boolean](#dfn-boolean) return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

21. Let `pageRanges` be the result of [getting a property
 with
 default](#dfn-getting-the-property-with-default) named \"`pageRanges`\" from
 `parameters` with default of an empty
 [Array](#dfn-array).

22. If `pageRanges` is not an
 [Array](#dfn-array) return [error](#dfn-error) with [error
 code](#dfn-error-code) [invalid
 argument](#dfn-invalid-argument).

23. When the user agent is next to [run the animation frame
 callbacks](#dfn-run-the-animation-frame-callbacks), let `pdfData` be the
 result of [trying](#dfn-try) to take UA-specific steps to generate a paginated
 representation of `session`\'s [current browsing
 context](#dfn-current-browsing-context), with the CSS [media
 type](#dfn-media-type) set to `print`, encoded as a PDF, with the
 following paper settings:

 ---------------------- --------------------------------------------------------------------------------------------------------
 Property Value
 Width in cm `pageWidth` if `orientation` is \"`portrait`\" otherwise `pageHeight`
 Height in cm `pageHeight` if `orientation` is \"`portrait`\" otherwise `pageWidth`
 Top margin, in cm `marginTop`
 Bottom margin, in cm `marginBottom`
 Left margin, in cm `marginLeft`
 Right margin, in cm `marginRight`
 ---------------------- --------------------------------------------------------------------------------------------------------

 In addition, the following formatting hints should be applied by the
 UA:

 If `scale` is not equal to `1`
 : Zoom the size of the content by a factor `scale`

 If `background` is `false`
 : Suppress output of background images

 If `shrinkToFit` is `true`
 : Resize the content to match the page width, overriding any page
 width specified in the content

24. If `pageRanges` is not an empty
 [Array](#dfn-array), Let `pages` be the result of
 [trying](#dfn-try) to [parse a page
 range](#dfn-parse-a-page-range) with arguments `pageRanges`
 and the number of pages contained in `pdfData`, then
 remove any pages from `pdfData` whose one-based index is
 not contained in `pages`

25. Let `encoding result` be the result of calling [Base64
 Encode](#dfn-base64-encode) on `pdfData`.

26. Let `encoded string` be `encoding result`\'s
 data.

27. Return [success](#dfn-success) with data `encoded string`

::: header-wrapper
## A. Privacy

It is advisable that [remote
ends](#dfn-remote-ends) create a new profile when [creating a new
session](#dfn-new-sessions). This prevents potentially sensitive
session data from being accessible to new
[sessions](#dfn-sessions), ensuring both privacy and preventing state from
bleeding through to the next session.

::: header-wrapper
## B. Security

A user agent can rely on a command-line flag or a configuration option
to test whether to enable WebDriver, or alternatively make the user
agent initiate or confirm the connection through a privileged content
document or control widget, in case the user agent does not directly
implement the HTTP endpoints.

It is strongly suggested that user agents require users to take explicit
action to enable WebDriver, and that WebDriver remains disabled in
publicly consumed versions of the user agent.

To prevent arbitrary machines on the network from connecting and
creating [sessions](#dfn-sessions), it is suggested that only connections from loopback
devices are allowed by default.

The [remote end](#dfn-remote-ends) can include a configuration option to
limit the accepted IP range allowed to connect and make requests. The
default setting for this might be to limit connections to the IPv4
localhost CIDR range `127.0.0.0/8` and the IPv6 localhost address `::1`.
\[[RFC4632](#bib-rfc4632 "Classless Inter-domain Routing (CIDR): The Internet Address Assignment and Aggregation Plan")\]

It is also suggested that user agents make an effort to visually
distinguish a user agent session that is under control of WebDriver from
those used for normal browsing sessions. This can be done through a
[browser chrome
element](#dfn-browser-chrome-element) such as a "door hanger", colorful
decoration of the OS window, or some widget element that is prevalent in
the window so that it easy to identify automation windows.

::: header-wrapper
## C. Element displayedness

Although WebDriver does not define a primitive to ascertain the
visibility of an
[element](https://dom.spec.whatwg.org/#concept-element) in the
[viewport](#dfn-viewport), we acknowledge that it is an important feature for
many users. Here we include a recommended approach which will give a
simplified approximation of an
[element](https://dom.spec.whatwg.org/#concept-element)\'s visibility, but please note that it relies only on
tree-traversal, and only covers a subset of visibility checks.

The visibility of an
[element](https://dom.spec.whatwg.org/#concept-element) is guided by what is perceptually visible to the human
eye. In this context, an
[element](https://dom.spec.whatwg.org/#concept-element)\'s displayedness does not relate to the
[`visibility`](#dfn-visibility) or [`display`](#dfn-display) style properties.

The approach recommended to implementors to ascertain an
[element](https://dom.spec.whatwg.org/#concept-element)\'s visibility was originally developed by the
[Selenium](https://selenium.dev) project, and is based on crude
approximations about an
[element](https://dom.spec.whatwg.org/#concept-element)\'s nature and relationship in the tree. An
[element](https://dom.spec.whatwg.org/#concept-element) is in general to be considered visible if any part of
it is drawn on the canvas within the boundaries of the viewport.

The [element displayed state] is a boolean
representing whether an element is currently visible.

To get the [element displayed
state](#dfn-element-displayed-state) using the
[`bot.dom.isShown`](#dfn-bot-dom-isshown) Selenium atoms, given
`element`:

1. Let `function` be the
 [`bot.dom.isShown`](#dfn-bot-dom-isshown) function.

2. Let `result` be the result of calling
 `function`\'s
 [\[\[Call\]\]](#dfn-call) internal method with arguments null and
 `element`. If this raises an exception, return an
 [error](#dfn-error) with [error
 code](#dfn-error-code) [unknown
 error](#dfn-unknown-error).

3. Return [success](#dfn-success) with data `result`.

 The [element displayed
 state](#dfn-element-displayed-state) is typically exposed as an endpoint
 for `GET` requests with a [URI
 Template](#dfn-uri-template) of
 `/session/{session id}/element/{element id}/displayed`.

::: header-wrapper
## D. Acknowledgements

There have been a lot of people that have helped make [browser
automation](#abstract) possible over the years and thereby furthered the
goals of this standard. In particular, thanks goes to the
[Selenium](https://selenium.dev) Open Source community, without which
this standard would never have been possible.

This standard is authored by Aleksey Chemakin, [Andreas
Tolfsen](https://sny.no/), Andrey Botalov, Brian Burg, Christian
Bromann, Clayton Martin, Daniel Wagner-Hall, [David
Burns](http://www.theautomatedtester.co.uk/), Dominique Hazael-Massieux,
Eran Messeri, Erik Wilde, Gábor Csárdi, Henrik Skupin, James Graham,
Jason Juang, Jason Leyba, Jim Evans, John Chen, John Jansen, Jonathan
Lipps, Jonathon Kereliuk, Luke Inman-Semerau, [Maja
Frydrychowicz](https://www.erranderr.com/), Malini Das, Manoj Kumar,
Marc Fisher, Mike Pennisi, Ondřej Machulda, Randall Kent, Sam Sneddon,
Seva Lotoshnikov, [Simon
Stewart](http://www.rocketpoweredjetpants.com/), Sri Harsha, Titus
Fortner, and Vangelis Katsikaros. The work is coordinated and edited by
[David Burns](http://www.theautomatedtester.co.uk/) and [Simon
Stewart](http://www.rocketpoweredjetpants.com/).

Thanks to Berge Schwebs Bjørlo, Lukas Tetzlaff, Malcolm Rowe,
Michael\[tm\] Smith, Nathan Bloomfield, Philippe Le Hégaret, Robin
Berjon, Ross Patterson, and Wilhelm Joys Andersen for proofreading and
suggesting areas for improvement.

::: header-wrapper
## E. Index

This specification relies on several other underlying specifications.

ARIA and related specifications

: The following terms are defined in the Accessible Rich Internet
 Applications (WAI-ARIA) 1.2 specification:
 \[[wai-aria-1.2](#bib-wai-aria-1.2 "Accessible Rich Internet Applications (WAI-ARIA) 1.2")\]

 - [[WAI-ARIA
 role](https://w3c.github.io/aria/#introroles)]

: The following terms are defined in the Accessible Name and
 Description Computation 1.1 specification:
 \[[accname-1.1](#bib-accname-1.1 "Accessible Name and Description Computation 1.1")\]

 - [[Accessible
 Name](https://www.w3.org/TR/accname-1.1/#dfn-accessible-name)]
 - [[Accessible Name and Description
 Computation](https://www.w3.org/TR/accname-1.1/#mapping_additional_nd_te)]

Web App Security

: The following terms are defined in the Content Security Policy Level
 3 specification:
 \[[CSP3](#bib-csp3 "Content Security Policy Level 3")\]

 - [[Directives](https://www.w3.org/TR/CSP/#directives)]
 - [[Should block navigation
 response](https://w3c.github.io/webappsec-csp/#should-block-navigation-response)]

Base16, Base32, and Base64 Data Encodings

: The following terms are defined in The Base16, Base32, and Base64
 Data Encodings specification:
 \[[RFC4648](#bib-rfc4648 "The Base16, Base32, and Base64 Data Encodings")\]

 - [[Base64
 Encode](https://tools.ietf.org/html/rfc4648#section-4)]

DOM

: The following terms are defined in the DOM Parsing and Serialization
 specification:
 \[[DOM-PARSING](#bib-dom-parsing "DOM Parsing and Serialization")\]

 - [[fragment serializing
 algorithm](https://w3c.github.io/DOM-Parsing/#dfn-fragment-serializing-algorithm)]
 - [[`innerHTML` IDL
 attribute](https://w3c.github.io/DOM-Parsing/#dom-innerhtml-innerhtml)]
 - [[`serializeToString`
 method](https://w3c.github.io/DOM-Parsing/#dom-xmlserializer-serializetostring)]

: The following attributes are defined in the UI Events specification:
 \[[UI-EVENTS](#bib-ui-events "UI Events")\]

 - [[Activation
 trigger](https://w3c.github.io/uievents/#activation-trigger)]
 - [[click
 event](https://w3c.github.io/uievents/#event-type-click)]
 - [[mouseDown
 event](https://w3c.github.io/uievents/#event-type-mousedown)]
 - [[mouseMove
 event](https://w3c.github.io/uievents/#event-type-mousemove)]
 - [[mouseOver
 event](https://w3c.github.io/uievents/#event-type-mouseover)]
 - [[mouseUp
 event](https://w3c.github.io/uievents/#event-type-mouseup)]

: The following attributes are defined in the UI Events Code
 specification:
 \[[UIEVENTS-KEY](#bib-uievents-key "UI Events KeyboardEvent key Values")\]

 - [[Keyboard modifier
 keys](https://www.w3.org/TR/uievents-key/#keys-modifier)]

ECMAScript

: The following terms are defined in the ECMAScript Language
 Specification:
 \[[ECMA-262](#bib-ecma-262 "ECMAScript Language Specification")\]

 - [[Iterable](https://tc39.github.io/ecma262/#sec-iterable-interface)]
 - [[Completion](https://tc39.github.io/ecma262/#sec-completion-record-specification-type)]
 - [[CreateResolvingFunctions](https://tc39.github.io/ecma262/#sec-createresolvingfunctions)]
 - [[Directive
 prologue](https://www.ecma-international.org/ecma-262/5.1/#sec-14.1)]
 - [[Early
 error](https://www.ecma-international.org/ecma-262/5.1/#sec-16)]
 - [[Function](https://www.ecma-international.org/ecma-262/5.1/#sec-4.3.24)]
 - [[FunctionBody](https://www.ecma-international.org/ecma-262/5.1/#sec-13)]
 - [[FunctionCreate](https://tc39.github.io/ecma262/#sec-functioncreate)]
 - [[Get](https://tc39.github.io/ecma262/#sec-get-o-p)]
 - [[Global
 environment](https://www.ecma-international.org/ecma-262/5.1/#sec-10.2.3)]
 - [[IsCallable](https://tc39.github.io/ecma262/#sec-iscallable)]
 - [[Own
 property](https://www.ecma-international.org/ecma-262/5.1/#sec-4.3.30)]
 - [[Promise](https://tc39.github.io/ecma262/#sec-promise-constructor)]
 - [[PromiseResolve](https://tc39.github.io/ecma262/#sec-promise-resolve)]
 - [[Type](https://tc39.github.io/ecma262/#sec-ecmascript-data-types-and-values)]
 - [[Use strict
 directive](https://www.ecma-international.org/ecma-262/5.1/#sec-14.1)]
 - [[parseInt](https://www.ecma-international.org/ecma-262/5.1/#sec-15.1.2.2)]
 - [[realm](https://tc39.github.io/ecma262/#sec-code-realms)]

: This specification also presumes that you are able to call some of
 the [internal
 methods](https://www.ecma-international.org/ecma-262/5.1/#sec-8.6.2)
 from the ECMAScript Language Specification
 \[[ECMAScript](#bib-ecma-262 "ECMAScript Language Specification")\]:
 - [[\[\[Call\]\]](https://www.ecma-international.org/ecma-262/5.1/#sec-13.2.1)]
 - [[\[\[GetOwnProperty\]\]](https://www.ecma-international.org/ecma-262/5.1/#sec-8.12.1)]
 - [[\[\[GetProperty\]\]](https://www.ecma-international.org/ecma-262/5.1/#sec-8.12.2)]
 - [[Index
 of](https://www.ecma-international.org/ecma-262/5.1/#sec-15.5.4.7)]
 - [[\[\[Put\]\]](https://www.ecma-international.org/ecma-262/5.1/#sec-8.12.5)]
 - [[Substring](https://www.ecma-international.org/ecma-262/5.1/#sec-15.5.4.15)]

: The ECMAScript Language Specification also defines the following
 types, values, and operations that are used throughout this
 specification:
 - [[Array](https://www.ecma-international.org/ecma-262/5.1/#sec-11.1.4)]
 - [[Boolean](https://www.ecma-international.org/ecma-262/5.1/#sec-4.3.14)] type
 - [[List](https://www.ecma-international.org/ecma-262/5.1/#sec-8.8)]
 - [[maximum safe
 integer](https://www.ecma-international.org/ecma-262/6.0/#sec-number.max_safe_integer)]
 - [[`null`](https://www.ecma-international.org/ecma-262/5.1/#sec-4.3.11)]
 - [[Number](https://www.ecma-international.org/ecma-262/5.1/#sec-4.3.19)]
 - [[Object](https://www.ecma-international.org/ecma-262/5.1/#sec-4.2.1)]
 - [[parse](https://www.ecma-international.org/ecma-262/5.1/#sec-15.12.2)]
 - [[String](https://www.ecma-international.org/ecma-262/5.1/#sec-4.3.18)]
 - [[stringify](https://www.ecma-international.org/ecma-262/5.1/#sec-15.12.3)]
 - [[ToInteger](https://www.ecma-international.org/ecma-262/6.0/#sec-tointeger)]
 - [[Undefined](https://www.ecma-international.org/ecma-262/5.1/#sec-4.3.9)]

Encoding

: The following terms are defined in the WHATWG Encoding
 specification:
 \[[ENCODING](#bib-encoding "Encoding Standard")\]

 - [[UTF-8
 Encode](https://encoding.spec.whatwg.org/#utf-8-encode)]

Fetch

: The following terms are defined in the WHATWG Fetch specification:
 \[[FETCH](#bib-fetch "Fetch Standard")\]

 - [[Body](https://fetch.spec.whatwg.org/#concept-request-body)]
 - [[default User-Agent
 value](https://fetch.spec.whatwg.org/#default-user-agent-value)]
 - [[Header](https://fetch.spec.whatwg.org/#concept-header)]
 - [[Header
 Name](https://fetch.spec.whatwg.org/#concept-header-name)]
 - [[Header
 Value](https://fetch.spec.whatwg.org/#concept-header-value)]
 - [[Local
 scheme](https://fetch.spec.whatwg.org/#local-scheme)]
 - [[Method](https://fetch.spec.whatwg.org/#concept-request-method)]
 - [[Response](https://fetch.spec.whatwg.org/#concept-response)]
 - [[Request](https://fetch.spec.whatwg.org/#concept-request)]
 - [[Set
 Header](https://fetch.spec.whatwg.org/#concept-header-list-set)]
 - [[HTTP
 Status](https://fetch.spec.whatwg.org/#concept-response-status)]
 - [[Status
 message](https://fetch.spec.whatwg.org/#concept-response-status-message)]

Fullscreen

: The following terms are defined in the WHATWG Fullscreen
 specification:
 \[[FULLSCREEN](#bib-fullscreen "Fullscreen API Standard")\]

 - [[Fullscreen an
 element](https://fullscreen.spec.whatwg.org/#fullscreen-an-element)]
 - [[Fullscreen is
 supported](https://fullscreen.spec.whatwg.org/#fullscreen-is-supported)]
 - [[fully exit
 fullscreen](https://fullscreen.spec.whatwg.org/#fully-exit-fullscreen)]

HTML

: The following terms are defined in the HTML specification:
 \[[HTML](#bib-html "HTML Standard")\]

 - [[2D context creation
 algorithm](https://html.spec.whatwg.org/#2d-context-creation-algorithm)]
 - [[A serialization of the bitmap as a
 file](https://html.spec.whatwg.org/#a-serialisation-of-the-bitmap-as-a-file)]
 - [[API
 value](https://html.spec.whatwg.org/#concept-fe-api-value)]
 - [[active
 document](https://html.spec.whatwg.org/#active-document)]
 - [Active element] being the
 [`activeElement`](https://html.spec.whatwg.org/#dom-document-activeelement)
 attribute on [`Document`](https://html.spec.whatwg.org/#document)
 - [[Associated
 window](https://html.spec.whatwg.org/#concept-document-window)]
 - [[Boolean
 attribute](https://html.spec.whatwg.org/#boolean-attribute)]
 - [[Browsing
 context](https://html.spec.whatwg.org/#browsing-context)]
 - [[Browsing context
 group](https://html.spec.whatwg.org/#browsing-context-group)]
 - [[Candidate for constraint
 validation](https://html.spec.whatwg.org/#candidate-for-constraint-validation)]
 - [[Canvas context
 mode](https://html.spec.whatwg.org/#concept-canvas-context-mode)]
 - [[Checkbox](https://html.spec.whatwg.org/#checkbox-state-%28type=checkbox%29)] state
 - [[Checkedness](https://html.spec.whatwg.org/#concept-fe-checked)]
 - [[Child browsing
 context](https://html.spec.whatwg.org/#child-browsing-context)]
 - [[Close a browsing
 context](https://html.spec.whatwg.org/#close-a-browsing-context)]
 - [[Cookie-averse `Document`
 object](https://html.spec.whatwg.org/#cookie-averse-document-object)]
 - [[Dirty checkedness
 flag](https://html.spec.whatwg.org/#concept-input-checked-dirty-flag)]
 - [[Dirty value
 flag](https://html.spec.whatwg.org/#concept-fe-dirty)]
 - [[Actually
 disabled](https://html.spec.whatwg.org/#concept-element-disabled)]
 - [[Document
 readiness](https://html.spec.whatwg.org/#current-document-readiness)]
 - [[Element
 contexts](https://html.spec.whatwg.org/#concept-element-contexts)]
 - [[Enumerated
 attribute](https://html.spec.whatwg.org/#enumerated-attribute)]
 - [[Event
 loop](https://html.spec.whatwg.org/#event-loop)]
 - [[File upload
 state](https://html.spec.whatwg.org/#file-upload-state-(type=file))]
 - [[Focusing
 steps](https://html.spec.whatwg.org/#focusing-steps)]
 - [[Focusable
 area](https://html.spec.whatwg.org/#focusable-area)]
 - [[`[[GetOwnProperty]]` of a `Window`
 object](https://html.spec.whatwg.org/#windowproxy-getownproperty)]
 - [[Selected
 Files](https://html.spec.whatwg.org/#concept-input-type-file-selected)]
 - [[Joint session
 history](https://html.spec.whatwg.org/#joint-session-history)]
 - [[Mature](https://html.spec.whatwg.org/#concept-navigate-mature)] navigation.
 - [[Mutable](https://html.spec.whatwg.org/#concept-fe-mutable)]
 - [[Navigate](https://html.spec.whatwg.org/#navigate)]
 - [[Origin-clean](https://html.spec.whatwg.org/#concept-canvas-origin-clean)]
 - [[An overridden
 reload](https://html.spec.whatwg.org/multipage/dom.html#an-overridden-reload)]
 - [[Parent browsing
 context](https://html.spec.whatwg.org/#parent-browsing-context)]
 - [[HTML Pause](https://html.spec.whatwg.org/#pause)]
 - [[Prompt to unload a
 document](https://html.spec.whatwg.org/#prompt-to-unload-a-document)]
 - [[Radio
 Button](https://html.spec.whatwg.org/#radio-button-state-%28type=radio%29)] state
 - [[Raw
 value](https://html.spec.whatwg.org/#concept-textarea-raw-value)]
 - [[Refresh state pragma
 directive](https://html.spec.whatwg.org/#attr-meta-http-equiv-refresh)]
 - [[Reset
 algorithm](https://html.spec.whatwg.org/#concept-form-reset-control)]
 - [[Resettable
 element](https://html.spec.whatwg.org/#category-reset)]
 - [[Run the animation frame
 callbacks](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#run-the-animation-frame-callbacks)]
 - [[Satisfies its
 constraints](https://html.spec.whatwg.org/#concept-fv-valid)]
 - [[Selectedness](https://html.spec.whatwg.org/#concept-option-selectedness)]
 - [[Simple
 dialogs](https://html.spec.whatwg.org/#simple-dialogs)]
 - [[Steps to fire
 beforeunload](https://html.spec.whatwg.org/#steps-to-fire-beforeunload)]
 - [[Suffering from bad
 input](https://html.spec.whatwg.org/#suffering-from-bad-input)]
 - [[Traverse the history by a
 delta](https://html.spec.whatwg.org/#traverse-the-history-by-a-delta)]
 - [[unfocusing
 steps](https://html.spec.whatwg.org/#unfocusing-steps)]
 - [[User
 prompt](https://html.spec.whatwg.org/#user-prompts)]
 - [[Value](https://html.spec.whatwg.org/#concept-fe-value)]
 - [[Value mode
 flag](https://html.spec.whatwg.org/#concept-output-mode)]
 - [[Value sanitization
 algorithm](https://html.spec.whatwg.org/#value-sanitization-algorithm)]
 - [[`Window`](https://html.spec.whatwg.org/#the-window-object)] object
 - [[Window open
 steps](https://html.spec.whatwg.org/#window-open-steps)]
 - [[`WindowProxy`](https://html.spec.whatwg.org/#windowproxy)] exotic
 object
 - [[`setSelectionRange`](https://html.spec.whatwg.org/#dom-textarea/input-setselectionrange)]
 - [window.[`confirm`](https://html.spec.whatwg.org/#dom-confirm)]
 - [window.[`alert`](https://html.spec.whatwg.org/#dom-alert)]
 - [window.[`prompt`](https://html.spec.whatwg.org/#dom-prompt)]

: The HTML specification also defines *states* of the
 [`input`](#dfn-input) element:

 - [[Color
 state](https://html.spec.whatwg.org/#color-state-(type=color))]
 - [[Date
 state](https://html.spec.whatwg.org/#date-state-(type=date))]
 - [[Email
 state](https://html.spec.whatwg.org/#e-mail-state-(type=email))]
 - [[Local Date and Time
 state](https://html.spec.whatwg.org/#local-date-and-time-state-(type=datetime-local))]
 - [[Month
 state](https://html.spec.whatwg.org/#month-state-(type=month))]
 - [[Number
 state](https://html.spec.whatwg.org/#number-state-(type=number))]
 - [[Password
 state](https://html.spec.whatwg.org/#password-state-(type=password))]
 - [[Range
 state](https://html.spec.whatwg.org/#range-state-(type=range))]
 - [[Telephone
 state](https://html.spec.whatwg.org/#telephone-state-(type=tel))]
 - [[Text and Search
 state](https://html.spec.whatwg.org/#text-(type=text)-state-and-search-state-(type=search))]
 - [[Time
 state](https://html.spec.whatwg.org/#time-state-(type=time))]
 - [[URL
 state](https://html.spec.whatwg.org/#url-state-(type=url))]
 - [[Week
 state](https://html.spec.whatwg.org/#week-state-(type=week))]

: The HTML specification also defines a range of different attributes:

 - [[Checked](https://html.spec.whatwg.org/#attr-input-checked)]
 - [[`multiple`
 attribute](https://html.spec.whatwg.org/#attr-input-multiple)]

: The HTML Editing APIs specification defines the following terms:
 \[[EDITING](#bib-editing "HTML Editing APIs")\]

 - [[Content
 editable](https://w3c.github.io/contentEditable)]
 - [[Editing
 host](https://w3c.github.io/editing/execCommand.html#editing-host)]

: The following events are also defined in the HTML specification:

 - [[`change`](https://html.spec.whatwg.org/multipage/indices.html#event-change)]
 - [[`DOMContentLoaded`](https://html.spec.whatwg.org/#event-domcontentloaded)]
 - [[`input`](https://html.spec.whatwg.org/#event-input)]
 - [[`load`](https://html.spec.whatwg.org/multipage/indices.html#event-load)]
 - [[`pageHide`](https://html.spec.whatwg.org/multipage/indices.html#event-pagehide)]
 - [[`pageShow`](https://html.spec.whatwg.org/multipage/indices.html#event-pageshow)]

: The "data" URL scheme specification defines the following terms:
 \[[RFC2397](#bib-rfc2397 "The "data" URL scheme")\]

 - [[`data:`
 URL](https://tools.ietf.org/html/rfc2397#section-2)]

HTTP and related specifications

: To be [HTTP compliant], it is supposed that the
 implementation supports the relevant subsets of
 \[[RFC7230](#bib-rfc7230 "Hypertext Transfer Protocol (HTTP/1.1): Message Syntax and Routing")\],
 \[[RFC7231](#bib-rfc7231 "Hypertext Transfer Protocol (HTTP/1.1): Semantics and Content")\],
 \[[RFC7232](#bib-rfc7232 "Hypertext Transfer Protocol (HTTP/1.1): Conditional Requests")\],
 \[[RFC7234](#bib-rfc7234 "Hypertext Transfer Protocol (HTTP/1.1): Caching")\], and
 \[[RFC7235](#bib-rfc7235 "Hypertext Transfer Protocol (HTTP/1.1): Authentication")\].

: The following terms are defined in the Cookie specification:
 \[[RFC6265](#bib-rfc6265 "HTTP State Management Mechanism")\]

 - [[Compute
 `cookie-string`](https://tools.ietf.org/html/rfc6265#section-5.4)]
 - [[Cookie](https://tools.ietf.org/html/rfc6265#section-5.3)]
 - [[Cookie
 store](https://tools.ietf.org/html/rfc6265#section-5.3)]
 - [[Receives a
 cookie](https://tools.ietf.org/html/rfc6265#section-5.3)]

: The following terms are defined in the Same Site Cookie
 specification:
 \[[RFC6265bis](#bib-rfc6265bis "Cookies: HTTP State Management Mechanism")\]

 - [[Cookie Lifetime
 Limits](https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis-20#cookie-lifetime-limits)]
 - [[`Lax`](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-20#section-4.1.2.7)]
 - [[`Strict`](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-20#section-4.1.2.7)]

: The following terms are defined in the Hypertext Transfer Protocol
 (HTTP) Status Code Registry:

 - [[Status code
 registry](https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml)]

Infra

: The following terms are defined in the Infra specification:
 \[[INFRA](#bib-infra "Infra Standard")\]

 - [[convert an Infra value to a JSON-compatible JavaScript
 value](https://infra.spec.whatwg.org/#convert-an-infra-value-to-a-json-compatible-javascript-value)]
 - [[converting a JSON-derived JavaScript value to an Infra
 value](https://infra.spec.whatwg.org/#convert-a-json-derived-javascript-value-to-an-infra-value)]

: The following terms are defined in the Netscape Navigator Proxy
 Auto-Config File Format:
 - [[Proxy
 autoconfiguration](https://web.archive.org/web/20070602031929/http://wp.netscape.com/eng/mozilla/2.0/relnotes/demo/proxy-live.html)]

: The specification uses [URI Templates].
 \[[URI-TEMPLATE](#bib-uri-template "URI Template")\]

Interaction
: The following terms are defined in the Page Visibility Specification
 \[[PAGE-VISIBILITY](#bib-page-visibility "Page Visibility (Second Edition)")\]
 - [[Visibility state
 `hidden`](https://www.w3.org/TR/page-visibility/#dom-visibilitystate-hidden)]
 - [Visibility state] being the
 [`visibilityState`](https://www.w3.org/TR/page-visibility/#visibility-states-and-the-visibilitystate-enum)
 attribute on
 [Document](https://dom.spec.whatwg.org/#concept-document)
 - [[Visibility state
 `visible`](https://www.w3.org/TR/page-visibility/#dom-visibilitystate-visible)]

Selenium
: The following functions are defined within the
 [Selenium](https://selenium.dev) project, at revision
 `775cfb33b193eb8832cd5488f298006f45254685`.
 - [[`bot.dom.getVisibleText`](https://github.com/SeleniumHQ/selenium/blob/775cfb33b193eb8832cd5488f298006f45254685/javascript/atoms/dom.js#L1005)]
 - [[`bot.dom.isShown`](https://github.com/SeleniumHQ/selenium/blob/775cfb33b193eb8832cd5488f298006f45254685/javascript/atoms/dom.js#L573)]

Styling
: The following terms are defined in the CSS Values and Units Module
 Level 3 specification:
 \[[CSS3-VALUES](#bib-css3-values "CSS Values and Units Module Level 3")\]
 - [[absolute
 lengths](https://www.w3.org/TR/css-values-3/#absolute-lengths)]
 - [[CSS
 pixels](https://www.w3.org/TR/css-values-3/#px)]
: The following properties are defined in the CSS Basic Box Model
 Level 3 specification:
 \[[CSS3-BOX](#bib-css3-box "CSS Box Model Module Level 3")\]
 - The
 [[`visibility`](https://drafts.csswg.org/css-box/#visibility-prop)] property
: The following terms are defined in the CSS Device Adaptation Module
 Level 1 specification:
 \[[CSS-DEVICE-ADAPT](#bib-css-device-adapt "CSS Device Adaptation Module Level 1")\]
 - [[Initial
 viewport](https://drafts.csswg.org/css-device-adapt/#initial-viewport)], sometimes here referred to
 as the *viewport*.
: The following properties are defined in the CSS Display Module Level
 3 specification:
 \[[CSS3-DISPLAY](#bib-css3-display "CSS Display Module Level 3")\]
 - The
 [[`display`](https://drafts.csswg.org/css-display/#the-display-properties)] property
: The following terms are defined in the Geometry Interfaces Module
 Level 1 specification:
 \[[GEOMETRY-1](#bib-geometry-1 "Geometry Interfaces Module Level 1")\]
 - [[Rectangle](https://drafts.fxtf.org/geometry/#rectangle)]
 - [[Rectangle height
 dimension](https://drafts.fxtf.org/geometry/#rectangle-height-dimension)]
 - [[Rectangle width
 dimension](https://drafts.fxtf.org/geometry/#rectangle-width-dimension)]
 - [[Rectangle x
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-x-coordinate)]
 - [[Rectangle y
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-y-coordinate)]
: The following terms are defined in the CSS Cascading and Inheritance
 Level 4 specification:
 \[[CSS-CASCADE-4](#bib-css-cascade-4 "CSS Cascading and Inheritance Level 4")\]
 - [[Computed
 value](https://drafts.csswg.org/css-cascade-4/#computed-value)]
: The following terms are defined in the CSS Object Model:
 \[[CSSOM](#bib-cssom "CSS Object Model (CSSOM)")\]:
 - [[Resolved
 value](https://drafts.csswg.org/cssom/#resolved-value)]
: The following functions are defined in the CSSOM View Module:
 \[[CSSOM-VIEW](#bib-cssom-view "CSSOM View Module")\]:
 - [Elements from point] as
 [elementsFromPoint()](https://drafts.csswg.org/cssom-view/#dom-document-elementsfrompoint)
 - [[innerHeight](https://drafts.csswg.org/cssom-view/#dom-window-innerheight)]
 - [[innerWidth](https://drafts.csswg.org/cssom-view/#dom-window-innerwidth)]
 - [[moveTo(x,
 y)](https://drafts.csswg.org/cssom-view/#dom-window-moveto)]
 - [[outerHeight](https://drafts.csswg.org/cssom-view/#dom-window-outerheight)]
 - [[outerWidth](https://drafts.csswg.org/cssom-view/#dom-window-outerwidth)]
 - [[screenX](https://drafts.csswg.org/cssom-view/#dom-window-screenx)]
 - [[screenY](https://drafts.csswg.org/cssom-view/#dom-window-screeny)]
 - [[scrollX](https://drafts.csswg.org/cssom-view/#dom-window-scrollx)]
 - [[scrollY](https://drafts.csswg.org/cssom-view/#dom-window-scrolly)]
 - [[scrollIntoView](https://drafts.csswg.org/cssom-view/#dom-element-scrollintoview)]
 - [[`ScrollIntoViewOptions`](https://drafts.csswg.org/cssom-view/#dictdef-scrollintoviewoptions)]
 - [[Logical scroll position
 \"`block`\"](https://drafts.csswg.org/cssom-view/#dom-scrollintoviewoptions-block)]
 - [[Logical scroll position
 \"`inline`\"](https://drafts.csswg.org/cssom-view/#dom-scrollintoviewoptions-inline)]
: The following terms are defined in
 \[[mediaqueries-4](#bib-mediaqueries-4 "Media Queries Level 4")\]:
 - [[media
 type](https://www.w3.org/TR/mediaqueries-4/#media-types)]

SOCKS Proxy:

: The following terms are defined in the standard:
 \[[RFC1928](#bib-rfc1928 "SOCKS Protocol Version 5")\]

 - [[SOCKS
 Proxy](https://datatracker.ietf.org/doc/html/rfc1928)]

Unicode
: The following terms are defined in the standard:
 \[[Unicode](#bib-unicode "The Unicode Standard")\]
 - [[Code
 Point](https://www.unicode.org/versions/Unicode9.0.0/ch03.pdf#G2212)]
 - [[Extended grapheme
 cluster](https://www.unicode.org/versions/Unicode9.0.0/ch03.pdf#G2213)]

Unicode Standard Annex #29
: The following terms are defined in the standard:
 \[[UAX29](#bib-uax29 "Unicode Text Segmentation")\]
 - [[Grapheme cluster
 boundaries](https://unicode.org/reports/tr29/#Grapheme_Cluster_Boundaries)]

Unicode Standard Annex #44
: The following terms are defined in the standard:
 \[[UAX44](#bib-uax44 "Unicode Character Database")\]
 - [[Unicode character
 property](https://unicode.org/reports/tr44/#Properties)]

URLs
: The following terms are defined in the WHATWG URL standard:
 \[[URL](#bib-url "URL Standard")\]
 - [[Absolute
 URL](https://url.spec.whatwg.org/#syntax-url-absolute)]
 - [[Absolute URL with
 fragment](https://url.spec.whatwg.org/#syntax-url-absolute-with-fragment)]
 - [[Default
 port](https://url.spec.whatwg.org/#default-port)]
 - [[Domain](https://url.spec.whatwg.org/#concept-domain)]
 - [[Host](https://url.spec.whatwg.org/#concept-host)]
 - [[Includes
 credentials](https://url.spec.whatwg.org/#include-credentials)]
 - [[Is
 special](https://url.spec.whatwg.org/#is-special)]
 - [[Path-absolute
 URL](https://url.spec.whatwg.org/#syntax-url-path-absolute)]
 - [[Path](https://url.spec.whatwg.org/#concept-url-path)]
 - [[Port](https://url.spec.whatwg.org/#concept-url-port)]
 - [[URL](https://url.spec.whatwg.org/#concept-url)]
 - [[URL
 serializer](https://url.spec.whatwg.org/#concept-url-serializer)]

Web IDL

: The IDL fragments in this specification must be interpreted as
 required for conforming IDL fragments, as described in the Web IDL
 specification. \[[WEBIDL](#bib-webidl "Web IDL Standard")\]

 - [[`DOMException`](https://heycam.github.io/webidl/#dfn-DOMException)]
 - [[Supported property
 indices](https://heycam.github.io/webidl/#dfn-supported-property-indices)]
 - [[`SyntaxError`](https://heycam.github.io/webidl/#syntaxerror)]
 - [[this](https://heycam.github.io/webidl/#this)]

Promises Guide

: The following terms are defined in the Promises Guide.
 \[[PROMISES-GUIDE](#bib-promises-guide "Writing Promise-Using Specifications")\]

 - [[Promise-calling](https://www.w3.org/2001/tag/doc/promises-guide#promise-calling)]

XPATH

: The following terms are defined in the Document Object Model XPath
 standard
 \[[XPATH](#bib-xpath "XML Path Language (XPath) Version 1.0")\]

 - [[`evaluate`](https://www.w3.org/TR/DOM-Level-3-XPath/xpath.html#XPathEvaluator-evaluate)]
 - [[`ORDERED_NODE_SNAPSHOT_TYPE`](https://www.w3.org/TR/DOM-Level-3-XPath/xpath.html#XPathResult-ORDERED-NODE-SNAPSHOT-TYPE)]
 - [[`snapshotItem`](https://www.w3.org/TR/DOM-Level-3-XPath/xpath.html#XPathResult-snapshotItem)]
 - [[`XPathException`](https://www.w3.org/TR/DOM-Level-3-XPath/xpath.html#XPathException)]

::: header-wrapper
### E.1 Terms defined by this specification

- [2D context creation
 algorithm](#dfn-2d-context-creation-algorithm)
 [§E.]
- [A serialization of the bitmap as a
 file](#dfn-a-serialization-of-the-bitmap-as-a-file)
 [§E.]
- [absolute lengths](#dfn-absolute-lengths)
 [§E.]
- [Absolute URL](#dfn-absolute-url) [§E.]
- [Absolute URL with
 fragment](#dfn-absolute-url-with-fragment)
 [§E.]
- [accept](#dfn-accepting) [§16.]
- [Accept Alert](#dfn-accept-alert) [§16.3]
- [accept insecure TLS](#dfn-accept-insecure-tls)
 [§8.1]
- [Accept insecure TLS
 certificates](#dfn-insecure-tls-certificates)
 [§7.]
- [Accessible Name](#dfn-accessible-name)
 [§E.]
- [Accessible Name and Description
 Computation](#dfn-accessible-name-and-description-computation)
 [§E.]
- [action object](#dfn-action-object) [§15.5]
- [Actions](#dfn-actions) [§15.]
- [actions options](#dfn-actions-options)
 [§15.1]
- [actions queue](#dfn-actions-queue) [§15.3]
- [Activation trigger](#dfn-activation-trigger)
 [§E.]
- [active document](#dfn-active-document)
 [§E.]
- [Active element](#dfn-active-element) [§E.]
- [active HTTP sessions](#dfn-active-http-sessions)
 [§8.]
- [active sessions](#dfn-active-sessions)
 [§8.]
- [Actually disabled](#dfn-actually-disabled)
 [§E.]
- [add an input source](#dfn-add-an-input-source)
 [§15.3]
- [Add Cookie](#dfn-adding-a-cookie) [§14.3]
- [additional capability deserialization
 algorithm](#dfn-additional-capability-deserialization-algorithm)
 [§6.7]
- [additional WebDriver
 capabilities](#dfn-additional-webdriver-capability)
 [§6.7]
- [all associated cookies](#dfn-associated-cookies)
 [§14.]
- [An overridden reload](#dfn-an-overridden-reload)
 [§E.]
- [annotated unexpected alert open
 error](#dfn-annotated-unexpected-alert-open-error)
 [§16.1]
- [API value](#dfn-api-value) [§E.]
- [Array](#dfn-array) [§E.]
- [associated session](#dfn-associated-session)
 [§8.]
- [Associated window](#dfn-associated-window)
 [§E.]
- [Back](#dfn-back) [§10.3]
- [Base64 Encode](#dfn-base64-encode) [§E.]
- [Body](#dfn-body) [§E.]
- [Boolean](#dfn-boolean) [§E.]
- [Boolean attribute](#dfn-boolean-attribute)
 [§E.]
- [bot.dom.getVisibleText](#dfn-bot-dom-getvisibletext)
 [§E.]
- [bot.dom.isShown](#dfn-bot-dom-isshown)
 [§E.]
- [browser chrome](#dfn-browser-chrome) [§3.]
- [browser chrome elements](#dfn-browser-chrome-element)
 [§3.]
- [Browsing context](#dfn-browsing-contexts)
 [§E.]
- [Browsing context group](#dfn-browsing-context-group)
 [§E.]
- [browsing context group node
 map](#dfn-browsing-context-group-node-map)
 [§12.]
- [browsing context input state
 map](#dfn-browsing-context-input-state-map)
 [§8.]
- [calculate the absolute
 position](#dfn-calculate-the-absolute-position)
 [§12.4]
- [`[[Call]]`](#dfn-call) internal slot for `Function`
 [§E.]
- [Candidate for constraint
 validation](#dfn-candidate-for-constraint-validation)
 [§E.]
- [Canvas context mode](#dfn-canvas-context-mode)
 [§E.]
- [capabilities](#dfn-capabilities) [§7.]
- [capability name](#dfn-capability-name)
 [§6.7]
- [change](#dfn-change) [§E.]
- [check user prompt handler
 matches](#dfn-check-user-prompt-handler-matches)
 [§16.1]
- [Checkbox](#dfn-checkbox) [§E.]
- [Checked](#dfn-checked) [§E.]
- [Checkedness](#dfn-checkedness) [§E.]
- [Child browsing context](#dfn-child-browsing-context)
 [§E.]
- [clear a content editable
 element](#dfn-clear-a-content-editable-element)
 [§12.5.2]
- [clear a resettable
 element](#dfn-clear-a-resettable-element)
 [§12.5.2]
- [clear algorithm](#dfn-clear-algorithm)
 [§12.5]
- [clear the modifier key
 state](#dfn-clear-the-modifier-key-state)
 [§12.5.3]
- [click event](#dfn-click-event) [§E.]
- [clone an object](#dfn-clone-an-object)
 [§13.2]
- [Close a browsing context](#dfn-close) [§E.]
- [close the session](#dfn-close-the-session)
 [§8.1]
- [Close Window](#dfn-close-window) [§11.2]
- [code](#dfn-code) [§15.6.2]
- [Code Point](#dfn-unicode-code-point) [§E.]
- [collection](#dfn-collection) [§13.2]
- [Color state](#dfn-color-state) [§E.]
- [command](#dfn-commands) [§6.2]
- [Completion](#dfn-completion) [§E.]
- [Compute cookie-string](#dfn-compute-cookie-string)
 [§E.]
- [compute the tick
 duration](#dfn-computing-the-tick-duration)
 [§15.6]
- [Computed value](#dfn-computed-value) [§E.]
- [connection](#dfn-connection) [§6.3]
- [container](#dfn-container) [§12.4]
- [Content editable](#dfn-content-editable)
 [§E.]
- [convert an Infra value to a JSON-compatible JavaScript
 value](#dfn-convert-an-infra-value-to-a-json-compatible-javascript-value)
 [§E.]
- [converting a JSON-derived JavaScript value to an Infra
 value](#dfn-converting-a-json-derived-javascript-value-to-an-infra-value)
 [§E.]
- [Cookie](#dfn-cookies) [§E.]
- [Cookie domain](#dfn-cookie-domain) [§14.]
- [Cookie expiry time](#dfn-cookie-expiry-time)
 [§14.]
- [Cookie HTTP only](#dfn-cookie-http-only)
 [§14.]
- [Cookie Lifetime Limits](#dfn-cookie-lifetime-limits)
 [§E.]
- [Cookie name](#dfn-cookie-name) [§14.]
- [Cookie path](#dfn-cookie-path) [§14.]
- [Cookie same site](#dfn-cookie-same-site)
 [§14.]
- [Cookie secure only](#dfn-cookie-secure-only)
 [§14.]
- [Cookie store](#dfn-cookie-store) [§E.]
- [Cookie value](#dfn-cookie-value) [§14.]
- [Cookie-averse Document
 object](#dfn-cookie-averse-document-object)
 [§E.]
- [create a cookie](#dfn-creating-a-cookie)
 [§14.]
- [create a key input
 source](#dfn-create-a-key-input-source)
 [§15.2.2]
- [create a null input
 source](#dfn-create-a-null-input-source)
 [§15.2.1]
- [create a pointer input
 source](#dfn-create-a-pointer-input-source)
 [§15.2.3]
- [create a session](#dfn-create-a-session)
 [§8.1]
- [create a wheel input
 source](#dfn-create-a-wheel-input-source)
 [§15.2.4]
- [create an input source](#dfn-create-an-input-source)
 [§15.2]
- [create an input state](#dfn-create-an-input-state)
 [§15.3]
- [CreateResolvingFunctions](#dfn-createresolvingfunctions)
 [§E.]
- [CSS pixels](#dfn-css-pixels) [§E.]
- [CSS Selector](#dfn-css-selector)
 [§12.3.1.1]
- [current browsing context](#dfn-current-browsing-context)
 [§8.]
- [current parent browsing
 context](#dfn-current-parent-browsing-context)
 [§8.]
- [current top-level browsing
 context](#dfn-current-top-level-browsing-context)
 [§8.]
- [current user prompt](#dfn-current-user-prompt)
 [§16.]
- [data: URL](#dfn-data-url) [§E.]
- [Date state](#dfn-date-state) [§E.]
- [default pointer
 parameters](#dfn-default-pointer-parameters)
 [§15.5]
- [Default port](#dfn-default-port) [§E.]
- [default User-Agent value](#dfn-default-user-agent-value)
 [§E.]
- [Delete All Cookies](#dfn-delete-all-cookies)
 [§14.5]
- [Delete Cookie](#dfn-delete-cookie) [§14.4]
- [delete cookies](#dfn-delete-cookies) [§14.]
- [Delete Session](#dfn-delete-session) [§8.3]
- [deserialize a shadow
 root](#dfn-deserialize-a-shadow-root)
 [§12.2]
- [deserialize a web
 element](#dfn-deserialize-a-web-element)
 [§12.]
- [deserialize a web frame](#dfn-deserialize-a-web-frame)
 [§11.]
- [deserialize a web window](#dfn-deserialize-a-web-window)
 [§11.]
- [deserialize as a page load
 strategy](#dfn-deserialize-as-a-page-load-strategy)
 [§10.]
- [deserialize as a proxy](#dfn-deserialize-as-a-proxy)
 [§7.1]
- [deserialize as an unhandled prompt
 behavior](#dfn-deserialize-as-an-unhandled-prompt-behavior)
 [§16.1]
- [deserialize as timeouts
 configuration](#dfn-deserialize-as-timeouts-configuration)
 [§9.]
- [detached shadow root](#dfn-detached-shadow-root)
 [§6.6]
- [Directive prologue](#dfn-directive-prologue)
 [§E.]
- [Directives](#dfn-directives) [§E.]
- [Dirty checkedness flag](#dfn-dirty-checkedness-flag)
 [§E.]
- [Dirty value flag](#dfn-dirty-value-flag)
 [§E.]
- [disabled](#dfn-disabled) [§12.1]
- [dismiss](#dfn-dismissed) [§16.]
- [Dismiss Alert](#dfn-dismiss-alert) [§16.2]
- [dispatch a composition
 event](#dfn-dispatch-a-composition-event)
 [§12.5.3]
- [dispatch a keyDown
 action](#dfn-dispatch-a-keydown-action)
 [§15.6.2]
- [dispatch a keyUp action](#dfn-dispatch-a-keyup-action)
 [§15.6.2]
- [dispatch a list of
 actions](#dfn-dispatch-a-list-of-actions)
 [§15.6]
- [dispatch a pause action](#dfn-dispatch-a-pause-action)
 [§15.6.1]
- [dispatch a pointerCancel
 action](#dfn-dispatch-a-pointercancel-action)
 [§15.6.3]
- [dispatch a pointerDown
 action](#dfn-dispatch-a-pointerdown-action)
 [§15.6.3]
- [dispatch a pointerMove
 action](#dfn-dispatch-a-pointermove-action)
 [§15.6.3]
- [dispatch a pointerUp
 action](#dfn-dispatch-a-pointerup-action)
 [§15.6.3]
- [dispatch a scroll action](#dfn-dispatch-a-scroll-action)
 [§15.6.4]
- [dispatch actions](#dfn-dispatch-actions)
 [§15.6]
- [dispatch actions for a
 string](#dfn-dispatch-actions-for-a-string)
 [§12.5.3]
- [dispatch actions inner](#dfn-dispatch-actions-inner)
 [§15.6]
- [dispatch the events for a typeable
 string](#dfn-dispatch-the-events-for-a-typeable-string)
 [§12.5.3]
- [dispatch tick actions](#dfn-dispatch-tick-actions)
 [§15.6]
- [display](#dfn-display) [§E.]
- [Document readiness](#dfn-document-readiness)
 [§E.]
- [Domain](#dfn-domains) [§E.]
- [DOMContentLoaded](#dfn-domcontentloaded)
 [§E.]
- [DOMException](#dfn-domexception) [§E.]
- [draw a bounding box from the
 framebuffer](#dfn-draw-a-bounding-box-from-the-framebuffer)
 [§17.]
- [eager](#dfn-eager-page-loading-strategy)
 [§10.]
- [Early error](#dfn-early-error) [§E.]
- [Editable](#dfn-editable) [§12.]
- [Editing host](#dfn-editing-hosts) [§E.]
- [Element Clear](#dfn-element-clear)
 [§12.5.2]
- [Element Click](#dfn-element-click)
 [§12.5.1]
- [element click
 intercepted](#dfn-element-click-intercepted)
 [§6.6]
- [Element contexts](#dfn-element-context)
 [§E.]
- [element displayed state](#dfn-element-displayed-state)
 [§C.]
- [element location strategy](#dfn-strategy)
 [§12.3.1]
- [element not interactable](#dfn-element-not-interactable)
 [§6.6]
- [Element Send Keys](#dfn-element-send-keys)
 [§12.5.3]
- [Elements from point](#dfn-paint-order)
 [§E.]
- [Email state](#dfn-email-state) [§E.]
- [encode a canvas as Base64 a canvas
 element](#dfn-encoding-a-canvas-as-base64)
 [§17.]
- [Endpoint node](#dfn-endpoint-node) [§5.]
- [Enumerated attribute](#dfn-enumerated-attribute)
 [§E.]
- [equivalent to an empty
 string](#dfn-equivalent-to-an-empty-string)
 [§18.]
- [error](#dfn-error) [§6.1]
- [error code](#dfn-error-code) [§6.6]
- [error data](#dfn-error-data) [§6.6]
- [error response data](#dfn-error-response-data)
 [§6.6]
- [evaluate](#dfn-evaluate) [§E.]
- [Event loop](#dfn-event-loop) [§E.]
- [execute a function body](#dfn-execute-a-function-body)
 [§13.2]
- [Execute Async Script](#dfn-execute-async-script)
 [§13.2.2]
- [Execute Script](#dfn-execute-script)
 [§13.2.1]
- [Extended grapheme cluster](#dfn-grapheme-cluster)
 [§E.]
- [extension capabilities](#dfn-extension-capability)
 [§6.7]
- [extension command URI
 Template](#dfn-extension-command-uri-template)
 [§6.7]
- [extension commands](#dfn-extension-commands)
 [§6.7]
- [extract an action
 sequence](#dfn-extract-an-action-sequence)
 [§15.5]
- [extract the script arguments from a
 request](#dfn-extract-the-script-arguments-from-a-request)
 [§13.2]
- [File upload state](#dfn-file-upload-state)
 [§E.]
- [find](#dfn-find) [§12.3]
- [Find Element](#dfn-find-element) [§12.3.2]
- [Find Element From
 Element](#dfn-find-element-from-element)
 [§12.3.4]
- [Find Element From Shadow
 Root](#dfn-find-element-from-shadow-root)
 [§12.3.6]
- [Find Elements](#dfn-find-elements)
 [§12.3.3]
- [Find Elements From
 Element](#dfn-find-elements-from-element)
 [§12.3.5]
- [Find Elements From Shadow
 Root](#dfn-find-elements-from-shadow-root)
 [§12.3.7]
- [floor](#dfn-floor) [§3.]
- [Focusable area](#dfn-focusable-area) [§E.]
- [Focusing steps](#dfn-focusing-steps) [§E.]
- [Forward](#dfn-forward) [§10.4]
- [fragment serializing
 algorithm](#dfn-fragment-serializing-algorithm)
 [§E.]
- [Fullscreen an element](#dfn-fullscreen-an-element)
 [§E.]
- [Fullscreen is supported](#dfn-support-fullscreen)
 [§E.]
- [Fullscreen Window](#dfn-fullscreen-window)
 [§11.8.5]
- [Fullscreen window state](#dfn-fullscreen-window-state)
 [§11.8]
- [fully exit fullscreen](#dfn-fully-exit-fullscreen)
 [§E.]
- [Function](#dfn-function) [§E.]
- [FunctionBody](#dfn-functionbody) [§E.]
- [FunctionCreate](#dfn-functioncreate) [§E.]
- [Generating a UUID](#dfn-generating-a-uuid)
 [§3.]
- [Get](#dfn-get) [§E.]
- [get a known element](#dfn-get-a-known-element)
 [§12.]
- [get a known shadow root](#dfn-get-a-known-shadow-root)
 [§12.2]
- [get a node](#dfn-get-a-node) [§12.]
- [get a pointer id](#dfn-get-a-pointer-id)
 [§15.3]
- [get a WebElement origin](#dfn-get-a-webelement-origin)
 [§15.1]
- [Get Active Element](#dfn-get-active-element)
 [§12.3.8]
- [Get Alert Text](#dfn-get-alert-text)
 [§16.4]
- [Get All Cookies](#dfn-get-all-cookies)
 [§14.1]
- [get an input source](#dfn-get-an-input-source)
 [§15.3]
- [Get Computed Label](#dfn-get-computed-label)
 [§12.4.10]
- [Get Computed Role](#dfn-get-computed-role)
 [§12.4.9]
- [get coordinates relative to an
 origin](#dfn-get-coordinates-relative-to-an-origin)
 [§15.5]
- [Get Current URL](#dfn-get-current-url)
 [§10.2]
- [Get Element Attribute](#dfn-get-element-attribute)
 [§12.4.2]
- [Get Element CSS Value](#dfn-get-element-css-value)
 [§12.4.4]
- [get element origin](#dfn-get-element-origin)
 [§15.1]
- [Get Element Property](#dfn-get-element-property)
 [§12.4.3]
- [Get Element Rect](#dfn-get-element-rect)
 [§12.4.7]
- [Get Element Shadow Root](#dfn-get-element-shadow-root)
 [§12.3.9]
- [Get Element Tag Name](#dfn-get-element-tag-name)
 [§12.4.6]
- [Get Element Text](#dfn-get-element-text)
 [§12.4.5]
- [Get Named Cookie](#dfn-get-named-cookie)
 [§14.2]
- [get or create a node
 reference](#dfn-get-or-create-a-node-reference)
 [§12.]
- [get or create a shadow root
 reference](#dfn-get-or-create-a-shadow-root-reference)
 [§12.2]
- [get or create a web element
 reference](#dfn-get-or-create-a-web-element-reference)
 [§12.]
- [get or create an input
 source](#dfn-get-or-create-an-input-source)
 [§15.3]
- [Get Page Source](#dfn-get-page-source)
 [§13.1]
- [get the active user
 prompt](#dfn-get-the-active-user-prompt)
 [§16.]
- [get the global key state](#dfn-get-the-global-key-state)
 [§15.3]
- [get the input state](#dfn-get-the-input-state)
 [§15.3]
- [get the prompt handler](#dfn-get-the-prompt-handler)
 [§16.1]
- [Get Timeouts](#dfn-get-timeouts) [§9.1]
- [Get Title](#dfn-get-title) [§10.6]
- [Get Window Handle](#dfn-get-window-handle)
 [§11.1]
- [Get Window Handles](#dfn-get-window-handles)
 [§11.4]
- [Get Window Rect](#dfn-get-window-rect)
 [§11.8.1]
- [`[[GetOwnProperty]]`](#dfn-getownproperty) internal slot
 for `Object` [§E.]
- [\[\[GetOwnProperty\]\] of a Window
 object](#dfn-window-getownproperty) internal slot for
 [§E.]
- [`[[GetProperty]]`](#dfn-getproperty) internal slot for
 `Object` [§E.]
- [getting a property](#dfn-getting-properties)
 [§6.1]
- [getting a property with
 default](#dfn-getting-the-property-with-default)
 [§6.1]
- [Global environment](#dfn-global-environment)
 [§E.]
- [global key state](#dfn-global-key-state)
 [§15.3]
- [Grapheme cluster
 boundaries](#dfn-breaking-text-into-extended-grapheme-clusters)
 [§E.]
- [handle any user prompts](#dfn-handle-any-user-prompts)
 [§16.1]
- [handler](#dfn-handler) [§16.1]
- [Handler key](#dfn-handler-key) [§16.1]
- [has proxy configuration](#dfn-has-proxy-configuration)
 [§8.1]
- [Header](#dfn-header) [§E.]
- [Header Name](#dfn-header-name) [§E.]
- [Header Value](#dfn-header-value) [§E.]
- [Host](#dfn-host) [§E.]
- [host and optional port](#dfn-host-and-optional-port)
 [§7.1]
- [HTML Pause](#dfn-unpaused) [§E.]
- [HTTP compliant](#dfn-http-compliant) [§E.]
- [HTTP flag](#dfn-http-flag) [§8.]
- [HTTP session](#dfn-http-session) [§8.]
- [HTTP Status](#dfn-http-status) [§E.]
- [iconify the window](#dfn-iconify-the-window)
 [§11.8]
- [implicit wait timeout](#dfn-implicit-wait-timeout)
 [§9.]
- [in view](#dfn-in-view) [§12.1]
- [in-view center point](#dfn-center-point)
 [§12.1]
- [Includes credentials](#dfn-includes-credentials)
 [§E.]
- [Index of](#dfn-index-of) [§E.]
- [initial value](#dfn-initial-value) [§3.]
- [Initial viewport](#dfn-viewport) [§E.]
- [innerHeight](#dfn-innerheight) [§E.]
- [innerHTML IDL attribute](#dfn-innerhtml-idl-attribute)
 [§E.]
- [innerWidth](#dfn-innerwidth) [§E.]
- [input](#dfn-input) [§E.]
- [input cancel list](#dfn-input-cancel-list)
 [§15.3]
- [input id](#dfn-input-id) [§15.2]
- [input source](#dfn-input-source) [§15.2]
- [input state](#dfn-input-state) [§15.3]
- [input state map](#dfn-input-state-map)
 [§15.3]
- [insecure certificate](#dfn-insecure-certificate)
 [§6.6]
- [integer](#dfn-integer) [§3.]
- [interactable element](#dfn-interactable)
 [§12.1]
- [Intermediary node](#dfn-intermediary-nodes)
 [§5.]
- [internal JSON clone](#dfn-internal-json-clone)
 [§13.2]
- [invalid argument](#dfn-invalid-argument)
 [§6.6]
- [invalid cookie domain](#dfn-invalid-cookie-domain)
 [§6.6]
- [invalid element state](#dfn-invalid-element-state)
 [§6.6]
- [invalid selector](#dfn-invalid-selector)
 [§6.6]
- [invalid session id](#dfn-invalid-session-id)
 [§6.6]
- [is detached](#dfn-is-detached) [§12.2]
- [Is Element Enabled](#dfn-is-element-enabled)
 [§12.4.8]
- [is element origin](#dfn-is-element-origin)
 [§15.1]
- [Is Element Selected](#dfn-is-element-selected)
 [§12.4.1]
- [Is special](#dfn-is-special) [§E.]
- [is stale](#dfn-is-stale) [§12.]
- [IsCallable](#dfn-iscallable) [§E.]
- [Iterable](#dfn-iterable) [§E.]
- [javascript error](#dfn-javascript-error)
 [§6.6]
- [Joint session history](#dfn-joint-session-history)
 [§E.]
- [JSON clone](#dfn-json-clone) [§13.2]
- [JSON deserialization](#dfn-parsing-as-json)
 [§6.1]
- [JSON deserialize](#dfn-json-deserialize)
 [§13.2]
- [JSON serialization](#dfn-json-serialization)
 [§6.1]
- [key input source](#dfn-key-input-source)
 [§15.2.2]
- [key location](#dfn-key-location) [§15.6.2]
- [Keyboard modifier keys](#dfn-modifier-key)
 [§E.]
- [keyboard-interactable
 element](#dfn-keyboard-interactable) [§12.1]
- [keyDown](#dfn-keydown) [§15.2.2]
- [keyUp](#dfn-keyup) [§15.2.2]
- [known prompt handlers](#dfn-known-prompt-handlers)
 [§16.1]
- [Lax](#dfn-lax) [§E.]
- [Link Text](#dfn-link-text-selector)
 [§12.3.1.2]
- [List](#dfn-list) [§E.]
- [load](#dfn-load) [§E.]
- [Local Date and Time
 state](#dfn-local-date-and-time-state) [§E.]
- [Local end](#dfn-local-ends) [§5.]
- [Local scheme](#dfn-local-scheme) [§E.]
- [Logical scroll position
 \"block\"](#dfn-logical-scroll-position-block)
 [§E.]
- [Logical scroll position
 \"inline\"](#dfn-logical-scroll-position-inline)
 [§E.]
- [match a request](#dfn-match-a-request)
 [§6.4]
- [matched capability serialization
 algorithm](#dfn-matched-capability-serialization-algorithm)
 [§6.7]
- [matching capabilities](#dfn-matching-capabilities)
 [§7.2]
- [Mature](#dfn-matured) [§E.]
- [max](#dfn-max) [§3.]
- [maximize the window](#dfn-maximize-the-window)
 [§11.8]
- [Maximize Window](#dfn-maximize-window)
 [§11.8.3]
- [Maximized window state](#dfn-maximized-window-state)
 [§11.8]
- [maximum safe integer](#dfn-maximum-safe-integer)
 [§E.]
- [media type](#dfn-media-type) [§E.]
- [merging capabilities](#dfn-merging-capabilities)
 [§7.2]
- [Method](#dfn-method) [§E.]
- [min](#dfn-min) [§3.]
- [Minimize Window](#dfn-minimize-window)
 [§11.8.4]
- [Minimized window state](#dfn-minimized-window-state)
 [§11.8]
- [Month state](#dfn-month-state) [§E.]
- [mouseDown event](#dfn-mousedown-event)
 [§E.]
- [mouseMove event](#dfn-mousemove-event)
 [§E.]
- [mouseOver event](#dfn-mouseover-event)
 [§E.]
- [mouseUp event](#dfn-mouseup-event) [§E.]
- [move target out of
 bounds](#dfn-move-target-out-of-bounds)
 [§6.6]
- [moveTo(x, y)](#dfn-moveto-x-y) [§E.]
- [multiple attribute](#dfn-multiple-attribute)
 [§E.]
- [Mutable](#dfn-mutable) [§E.]
- [Mutable elements](#dfn-mutable-element)
 [§12.]
- [Mutable form control
 elements](#dfn-mutable-form-control-element)
 [§12.]
- [navigable seen nodes map](#dfn-navigable-seen-nodes-map)
 [§12.]
- [Navigate](#dfn-navigating) [§E.]
- [Navigate To](#dfn-navigate-to) [§10.1]
- [`NavigatorAutomationInformation`](#dom-navigatorautomationinformation)
 interface [§4.]
- [New Session](#dfn-new-sessions) [§8.2]
- [New Window](#dfn-new-window) [§11.5]
- [no longer open](#dfn-no-longer-open) [§11.]
- [no such alert](#dfn-no-such-alert) [§6.6]
- [no such cookie](#dfn-no-such-cookie) [§6.6]
- [no such element](#dfn-no-such-element)
 [§6.6]
- [no such frame](#dfn-no-such-frame) [§6.6]
- [no such shadow root](#dfn-no-such-shadow-root)
 [§6.6]
- [no such window](#dfn-no-such-window) [§6.6]
- [node id map](#dfn-node-id-map) [§12.]
- [node reference is known](#dfn-node-reference-is-known)
 [§12.]
- [node types](#dfn-node-type) [§5.]
- [non-typeable form
 control](#dfn-non-typeable-form-control)
 [§12.5.3]
- [none](#dfn-none-page-loading-strategy)
 [§10.]
- [normal](#dfn-normal-page-loading-strategy)
 [§10.]
- [Normal window state](#dfn-normal-window-state)
 [§11.8]
- [normalized key value](#dfn-normalized-key-value)
 [§15.6.2]
- [not in the same tree](#dfn-not-in-the-same-tree)
 [§12.4]
- [notify](#dfn-notify) [§16.1]
- [null](#dfn-null) [§E.]
- [null input source](#dfn-null-input-source)
 [§15.2.1]
- [null key](#dfn-null-key) [§12.5.3]
- [Number](#dfn-number) [§E.]
- [Number state](#dfn-number-state) [§E.]
- [Object](#dfn-object) [§E.]
- [obscured](#dfn-obscuring) [§12.1]
- [ORDERED_NODE_SNAPSHOT_TYPE](#dfn-ordered_node_snapshot_type)
 [§E.]
- [Origin-clean](#dfn-origin-clean) [§E.]
- [outerHeight](#dfn-outerheight) [§E.]
- [outerWidth](#dfn-outerwidth) [§E.]
- [Own property](#dfn-own-properties) [§E.]
- [Page load strategy](#dfn-page-load-strategy)
 [§7.]
- [page load timeout](#dfn-page-load-timeout)
 [§9.]
- [page loading strategy](#dfn-page-loading-strategy)
 [§8.]
- [pageHide](#dfn-pagehide) [§E.]
- [pageShow](#dfn-pageshow) [§E.]
- [Parent browsing context](#dfn-parent-browsing-context)
 [§E.]
- [parse](#dfn-parse) [§E.]
- [parse a page range](#dfn-parse-a-page-range)
 [§18.]
- [parse as an integer](#dfn-parse-as-an-integer)
 [§18.]
- [parseInt](#dfn-parseint) [§E.]
- [Partial link text](#dfn-partial-link-text-selector)
 [§12.3.1.3]
- [Password state](#dfn-password-state) [§E.]
- [Path](#dfn-path) [§E.]
- [Path-absolute URL](#dfn-path-absolute-url)
 [§E.]
- [pause](#dfn-pause) [§15.2.1]
- [perform a pointer move](#dfn-perform-a-pointer-move)
 [§15.6.3]
- [perform a scroll](#dfn-perform-a-scroll)
 [§15.6.4]
- [Perform Actions](#dfn-perform-actions)
 [§15.7]
- [perform implementation-specific action dispatch
 steps](#dfn-perform-implementation-specific-action-dispatch-steps)
 [§15.4]
- [Platform name](#dfn-platform-name) [§7.]
- [pointer events
 disabled](#dfn-pointer-events-are-not-disabled)
 [§12.]
- [pointer input source](#dfn-pointer-input-source)
 [§15.2.3]
- [pointer-interactable element](#dfn-pointer-interactable)
 [§12.1]
- [pointer-interactable paint
 tree](#dfn-pointer-interactable-paint-tree)
 [§12.1]
- [pointerCancel](#dfn-pointercancel)
 [§15.2.3]
- [pointerDown](#dfn-pointerdown) [§15.2.3]
- [pointerMove](#dfn-pointermove) [§15.2.3]
- [pointerUp](#dfn-pointerup) [§15.2.3]
- [Port](#dfn-port) [§E.]
- [post-navigation checks](#dfn-post-navigation-checks)
 [§10.]
- [Print Page](#dfn-print-page) [§18.1]
- [process a key action](#dfn-process-a-key-action)
 [§15.5]
- [process a null action](#dfn-process-a-null-action)
 [§15.5]
- [process a pause action](#dfn-process-a-pause-action)
 [§15.5]
- [process a pointer action](#dfn-process-a-pointer-action)
 [§15.5]
- [process a pointer move
 action](#dfn-process-a-pointer-move-action)
 [§15.5]
- [process a pointer up or pointer down
 action](#dfn-process-a-pointer-up-or-pointer-down-action)
 [§15.5]
- [process a wheel action](#dfn-process-a-wheel-action)
 [§15.5]
- [process an input source action
 sequence](#dfn-process-an-input-source-action-sequence)
 [§15.5]
- [process capabilities](#dfn-capabilities-processing)
 [§7.2]
- [process pointer
 parameters](#dfn-process-pointer-parameters)
 [§15.5]
- [Promise](#dfn-promise) [§E.]
- [Promise-calling](#dfn-promise-call) [§E.]
- [PromiseResolve](#dfn-promiseresolve) [§E.]
- [prompt handler
 configuration](#dfn-prompt-handler-configuration)
 [§16.1]
- [Prompt to unload a document](#dfn-prompting-to-unload)
 [§E.]
- [Proxy autoconfiguration](#dfn-proxy-autoconfiguration)
 [§E.]
- [proxy configuration](#dfn-proxy-configuration)
 [§7.1]
- [proxy configuration
 object](#dfn-proxy-configuration-object)
 [§7.1]
- [proxyType](#dfn-proxytype) [§7.1]
- [`[[Put]]`](#dfn-put) internal slot for `Object`
 [§E.]
- [Radio Button](#dfn-radio-button) [§E.]
- [Range state](#dfn-range-state) [§E.]
- [Raw value](#dfn-raw-value) [§E.]
- [read bytes](#dfn-read-bytes) [§6.3]
- [read only](#dfn-read-only) [§12.]
- [readiness state](#dfn-readiness-state)
 [§5.]
- [realm](#dfn-realm) [§E.]
- [Receives a cookie](#dfn-receiving-a-cookie)
 [§E.]
- [Rectangle](#dfn-bounding-rectangle) [§E.]
- [Rectangle height dimension](#dfn-height-dimension)
 [§E.]
- [Rectangle width dimension](#dfn-width-dimension)
 [§E.]
- [Rectangle x coordinate](#dfn-x-coordinate)
 [§E.]
- [Rectangle y coordinate](#dfn-y-coordinate)
 [§E.]
- [Refresh](#dfn-refresh) [§10.5]
- [Refresh state pragma
 directive](#dfn-refresh-state-pragma-directive)
 [§E.]
- [Release Actions](#dfn-release-actions)
 [§15.8]
- [Remote end](#dfn-remote-ends) [§5.]
- [remote end steps](#dfn-remote-end-steps)
 [§6.2]
- [remove an input source](#dfn-remove-an-input-source)
 [§15.3]
- [represents a shadow root](#dfn-represents-a-shadow-root)
 [§12.2]
- [represents a web element](#dfn-represents-a-web-element)
 [§12.]
- [represents a web frame](#dfn-represents-a-web-frame)
 [§11.]
- [represents a web window](#dfn-represents-a-web-window)
 [§11.]
- [Request](#dfn-http-request) [§E.]
- [request queue](#dfn-request-queue) [§8.]
- [Request routing](#dfn-routing-requests)
 [§6.4]
- [Reset algorithm](#dfn-reset-algorithms)
 [§E.]
- [reset the input state](#dfn-reset-the-input-state)
 [§15.3]
- [Resettable element](#dfn-resettable-elements)
 [§E.]
- [Resolved value](#dfn-resolved-value) [§E.]
- [Response](#dfn-http-response) [§E.]
- [restore the window](#dfn-restore-the-window)
 [§11.8]
- [Run the animation frame
 callbacks](#dfn-run-the-animation-frame-callbacks)
 [§E.]
- [Satisfies its
 constraints](#dfn-satisfies-its-constraints)
 [§E.]
- [screenX](#dfn-screenx) [§E.]
- [screenY](#dfn-screeny) [§E.]
- [script timeout](#dfn-script-timeout) [§9.]
- [script timeout error](#dfn-script-timeout-error)
 [§6.6]
- [scroll](#dfn-scroll) [§15.2.4]
- [scroll into view](#dfn-scrolls-into-view)
 [§12.]
- [scrollIntoView](#dfn-scrollintoview) [§E.]
- [ScrollIntoViewOptions](#dfn-scrollintoviewoptions)
 [§E.]
- [scrollX](#dfn-scrollx) [§E.]
- [scrollY](#dfn-scrolly) [§E.]
- [Selected Files](#dfn-selected-files) [§E.]
- [Selectedness](#dfn-selectedness) [§E.]
- [send a response](#dfn-send-a-response)
 [§6.3]
- [Send Alert Text](#dfn-send-alert-text)
 [§16.5]
- [send an error](#dfn-send-an-error) [§6.3]
- [serialize a prompt handler
 configuration](#dfn-serialize-a-prompt-handler-configuration)
 [§16.1]
- [serialize the timeouts
 configuration](#dfn-serialize-the-timeouts-configuration)
 [§9.]
- [serialize the user prompt
 handler](#dfn-serialize-the-user-prompt-handler)
 [§16.1]
- [serialized cookie](#dfn-serialized-cookie)
 [§14.]
- [serializeToString method](#dfn-serializing-to-string)
 [§E.]
- [session](#dfn-sessions) [§8.]
- [session configuration
 flags](#dfn-session-configuration-flags)
 [§8.]
- [session ID](#dfn-session-id) [§8.]
- [session not created](#dfn-session-not-created)
 [§6.6]
- [session timeouts](#dfn-session-timeouts)
 [§8.]
- [Set Header](#dfn-set-header) [§E.]
- [set the current browsing
 context](#dfn-set-the-current-browsing-context)
 [§11.]
- [set the current top-level browsing
 context](#dfn-set-the-current-top-level-browsing-context)
 [§11.]
- [Set Timeouts](#dfn-set-timeouts) [§9.2]
- [Set Window Rect](#dfn-set-window-rect)
 [§11.8.2]
- [setSelectionRange](#dfn-set-selection-range)
 [§E.]
- [Setting a property](#dfn-set-a-property)
 [§6.1]
- [shadow root](#dfn-shadow-roots) [§12.2]
- [shadow root identifier](#dfn-shadow-root-identifier)
 [§12.2]
- [shadow root reference
 object](#dfn-shadow-root-reference-object)
 [§12.2]
- [shifted character](#dfn-shifted-character)
 [§15.6.2]
- [shifted state](#dfn-shifted-state)
 [§12.5.3]
- [Should block navigation
 response](#dfn-blocked-by-content-security-policy)
 [§E.]
- [Simple dialogs](#dfn-simple-dialog) [§E.]
- [snapshotItem](#dfn-snapshotitem) [§E.]
- [SOCKS Proxy](#dfn-socks-proxy) [§E.]
- [stale element reference](#dfn-stale-element-reference)
 [§6.6]
- [start the timer](#dfn-start-the-timer)
 [§9.]
- [Status](#dfn-status) [§8.4]
- [Status code registry](#dfn-status-code-registry)
 [§E.]
- [Status message](#dfn-status-message) [§E.]
- [Steps to fire
 beforeunload](#dfn-steps-to-fire-beforeunload)
 [§E.]
- [Strict](#dfn-strict) [§E.]
- [strict file
 interactability](#dfn-strict-file-interactability)
 [§8.]
- [String](#dfn-string) [§E.]
- [stringify](#dfn-stringify) [§E.]
- [Substring](#dfn-substring) [§E.]
- [success](#dfn-success) [§6.1]
- [Suffering from bad input](#dfn-suffering-from-bad-input)
 [§E.]
- [Supported property
 indices](#dfn-supported-property-index)
 [§E.]
- [Switch To Frame](#dfn-switch-to-frame)
 [§11.6]
- [Switch To Parent Frame](#dfn-switch-to-parent-frame)
 [§11.7]
- [Switch To Window](#dfn-switch-to-window)
 [§11.3]
- [SyntaxError](#dfn-syntaxerror) [§E.]
- [table for cookie
 conversion](#dfn-table-for-cookie-conversion)
 [§14.]
- [table of endpoints](#dfn-endpoints) [§6.5]
- [table of location
 strategies](#dfn-table-of-location-strategies)
 [§12.3.1]
- [table of page load
 strategies](#dfn-table-of-page-load-strategies)
 [§10.]
- [table of standard
 capabilities](#dfn-table-of-standard-capabilities)
 [§7.]
- [Tag Name](#dfn-tag-name) [§12.3.1.4]
- [Take Element Screenshot](#dfn-take-element-screenshot)
 [§17.2]
- [Take Screenshot](#dfn-take-screenshot)
 [§17.1]
- [Telephone state](#dfn-telephone-state)
 [§E.]
- [Text and Search state](#dfn-text-and-search-state)
 [§E.]
- [this](#dfn-this) [§E.]
- [tick](#dfn-ticks) [§15.4]
- [Time state](#dfn-time-state) [§E.]
- [timeout](#dfn-timeout) [§6.6]
- [timeout fired flag](#dfn-timeout-fired-flag)
 [§9.]
- [timeouts configuration](#dfn-timeouts-configuration)
 [§9.]
- [timer](#dfn-timer) [§9.]
- [ToInteger](#dfn-tointeger) [§E.]
- [Traverse the history by a
 delta](#dfn-traverse-the-history-by-a-delta)
 [§E.]
- [trying](#dfn-try) [§6.1]
- [Type](#dfn-ecmascript-type) [§E.]
- [typeable](#dfn-typeable) [§12.5.3]
- [unable to capture screen](#dfn-unable-to-capture-screen)
 [§6.6]
- [unable to set cookie](#dfn-unable-to-set-cookie)
 [§6.6]
- [Undefined](#dfn-undefined) [§E.]
- [unexpected alert open](#dfn-unexpected-alert-open)
 [§6.6]
- [unfocusing steps](#dfn-unfocusing-steps)
 [§E.]
- [Unicode character
 property](#dfn-unicode-character-property)
 [§E.]
- [Universally Unique Identifier (UUID)](#dfn-uuid)
 [§3.]
- [Unix Epoch](#dfn-unix-timestamp) [§3.]
- [unknown command](#dfn-unknown-command)
 [§6.6]
- [unknown error](#dfn-unknown-error) [§6.6]
- [unknown method](#dfn-unknown-method) [§6.6]
- [unsupported operation](#dfn-unsupported-operation)
 [§6.6]
- [update the user prompt
 handler](#dfn-update-the-user-prompt-handler)
 [§16.1]
- [upstream](#dfn-upstream) [§5.]
- [URI Templates](#dfn-uri-template) [§E.]
- [URL](#dfn-url) [§E.]
- [URL prefix](#dfn-url-prefix) [§6.4]
- [URL serializer](#dfn-url-serializer) [§E.]
- [URL state](#dfn-url-state) [§E.]
- [Use strict directive](#dfn-use-strict-directive)
 [§E.]
- [User prompt](#dfn-user-prompts) [§E.]
- [user prompt handler](#dfn-user-prompt-handler)
 [§16.1]
- [user prompt message](#dfn-user-prompt-message)
 [§16.]
- [UTF-8 Encode](#dfn-utf-8-encode) [§E.]
- [valid prompt types](#dfn-valid-prompt-types)
 [§16.1]
- [validate capabilities](#dfn-validate-capabilities)
 [§7.2]
- [Value](#dfn-value) [§E.]
- [Value mode flag](#dfn-value-mode-flag)
 [§E.]
- [Value sanitization
 algorithm](#dfn-value-sanitization-algorithm)
 [§E.]
- [visibility](#dfn-visibility) [§E.]
- [Visibility state](#dfn-visibility-state)
 [§E.]
- [Visibility state hidden](#dfn-visibility-hidden)
 [§E.]
- [Visibility state visible](#dfn-visibility-visible)
 [§E.]
- [WAI-ARIA role](#dfn-wai-aria-role) [§E.]
- [wait for an action queue
 token](#dfn-wait-for-an-action-queue-token)
 [§15.6]
- [wait for navigation to
 complete](#dfn-wait-for-navigation-to-complete)
 [§10.]
- [Waiting asynchronously](#dfn-asynchronously-wait)
 [§15.4]
- [weak map](#dfn-weak-map) [§12.]
- [web element](#dfn-web-elements) [§12.]
- [web element identifier](#dfn-web-element-identifier)
 [§12.]
- [web element reference
 object](#dfn-web-element-reference-object)
 [§12.]
- [web frame](#dfn-web-frames) [§11.]
- [web frame identifier](#dfn-web-frame-identifier)
 [§11.]
- [web window](#dfn-web-windows) [§11.]
- [web window identifier](#dfn-web-window-identifier)
 [§11.]
- webdriver
 - [attribute for
 `NavigatorAutomationInformation`](#dom-navigatorautomationinformation-webdriver)
 [§4.]
 - [definition of](#dfn-webdriver) [§4.]
- [WebDriver new session
 algorithms](#dfn-webdriver-new-session-algorithms)
 [§6.7]
- [WebDriver node id](#dfn-webdriver-node-id)
 [§12.]
- [webdriver-active flag](#dfn-webdriver-active-flag)
 [§4.]
- [Week state](#dfn-week-state) [§E.]
- [wheel input source](#dfn-wheel-input-source)
 [§15.2.4]
- [whitespace](#dfn-whitespace) [§12.4.5]
- [Window](#dfn-window) [§E.]
- [Window
 dimensioning/positioning](#dfn-window-dimensioning-positioning)
 [§7.]
- [window handle](#dfn-window-handles) [§11.]
- [Window open steps](#dfn-window-open-steps)
 [§E.]
- [window state](#dfn-window-states) [§11.8]
- [window.alert](#dfn-window-alert) [§E.]
- [window.confirm](#dfn-window-confirm) [§E.]
- [window.prompt](#dfn-window-prompt) [§E.]
- [WindowProxy](#dfn-windowproxy) [§E.]
- [WindowProxy reference
 object](#dfn-windowproxy-reference-object)
 [§11.]
- [WindowRect object](#dfn-windowrect-object)
 [§11.8]
- [write bytes](#dfn-write-bytes) [§6.3]
- [XPath Selector](#dfn-xpath-selector)
 [§12.3.1.5]
- [XPathException](#dfn-xpathexception) [§E.]

::: header-wrapper
### E.2 Terms defined by reference

- \[[CSSOM-VIEW](#bib-cssom-view)\] defines
 the following:
 - [`getBoundingClientRect()` (for
 `Element`)]
 - [`getClientRects()` (for
 `Element`)]
- \[[DOM](#bib-dom)\] defines the following:
 - [`compareDocumentPosition()` (for
 `Node`)]
 - [connected]
 - [descendant (for `tree`)]
 - [document]
 - [document element]
 - [DOCUMENT_POSITION_DISCONNECTED (for
 `Node`)]
 - [`DOMTokenList` interface]
 - [element]
 - [`Element` interface]
 - [event]
 - [fire an event]
 - [get an attribute by name]
 - [`getAttribute()` (for
 `Element`)]
 - [`getElementsByTagName()` (for
 `Element`)]
 - [`hasAttribute()` (for
 `Element`)]
 - [`HTMLCollection` interface]
 - [inclusive ancestor (for
 `tree`)]
 - [inclusive descendant (for
 `tree`)]
 - [`isTrusted` attribute (for
 `Event`)]
 - [node]
 - [node document (for `Node`)]
 - [`NodeList` interface]
 - [`querySelectorAll()` (for
 `ParentNode`)]
 - [remove]
 - [`ShadowRoot` interface]
 - [`tagName` attribute (for
 `Element`)]
 - [`textContent` attribute (for
 `Node`)]
 - [type (for `Document`)]
- \[[FILEAPI](#bib-fileapi)\] defines the
 following:
 - [`FileList` interface]
- \[[GEOMETRY-1](#bib-geometry-1)\] defines
 the following:
 - [`DOMRect` interface]
- \[[HTML](#bib-html)\] defines the
 following:
 - [`a` element]
 - [active browsing context (for
 `navigable`)]
 - [`address` element]
 - [`canvas` element]
 - [Clean up after running a
 callback]
 - [Clean up after running
 script]
 - [content navigable (for navigable
 container)]
 - [`datalist` element]
 - [`frame` element]
 - [`height` attribute (for `canvas`
 element)]
 - [`HTMLAllCollection`
 interface]
 - [`HTMLFormControlsCollection`
 interface]
 - [`HTMLOptionsCollection`
 interface]
 - [`iframe` element]
 - [in parallel]
 - [navigable]
 - [`Navigator` interface]
 - [node navigable]
 - [`optgroup` element]
 - [`option` element]
 - [`output` element]
 - [paused]
 - [Prepare to run a callback]
 - [Prepare to run script]
 - [`readonly` attribute (for `input`
 element)]
 - [relevant agent]
 - [relevant settings object]
 - [`select` element]
 - [`textarea` element]
 - [`title` attribute (for
 `Document`)]
 - [top-level browsing
 contexts]
 - [`type` attribute (for `input`
 element)]
 - [`width` attribute (for `canvas`
 element)]
 - [`WorkerNavigator` interface]
- \[[INFRA](#bib-infra)\] defines the
 following:
 - [abort when]
 - [ASCII Lowercase]
 - [contain (for `list`)]
 - [contains (for `map`)]
 - [continue (for `iteration`)]
 - [entry (for `map`)]
 - [getting the values (for
 `map`)]
 - [If aborted]
 - [item (for `struct`)]
 - [length (for `string`)]
 - [map]
 - [queue]
 - [set]
 - [Set (for `map`)]
 - [size (for `map`)]
 - [struct]
 - [While (for `iteration`)]
- \[[WEBDRIVER-BIDI](#bib-webdriver-bidi)\]
 defines the following:
 - [BiDi session]
- \[[WEBIDL](#bib-webidl)\] defines the
 following:
 - [a new Promise]
 - [reject]
 - [resolve]

::: header-wrapper
## F. References

::: header-wrapper
### F.1 Normative references

\[accname-1.1\]
: [Accessible Name and Description Computation
 1.1](https://www.w3.org/TR/accname-1.1/). Joanmarie Diggs; Bryan
 Garaventa; Michael Cooper. W3C. 18 December 2018. W3C
 Recommendation. URL: <https://www.w3.org/TR/accname-1.1/>

\[CSP3\]
: [Content Security Policy Level 3](https://www.w3.org/TR/CSP3/). Mike
 West; Antonio Sartori. W3C. 11 July 2025. W3C Working Draft. URL:
 <https://www.w3.org/TR/CSP3/>

\[CSS-CASCADE-4\]
: [CSS Cascading and Inheritance Level
 4](https://www.w3.org/TR/css-cascade-4/). Elika Etemad; Tab Atkins
 Jr. W3C. 13 January 2022. W3C Candidate Recommendation. URL:
 <https://www.w3.org/TR/css-cascade-4/>

\[CSS-DEVICE-ADAPT\]
: [CSS Device Adaptation Module Level
 1](https://www.w3.org/TR/css-device-adapt-1/). Rune Lillesveen;
 Florian Rivoal; Matt Rakow. W3C. 29 March 2016. W3C Working Draft.
 URL: <https://www.w3.org/TR/css-device-adapt-1/>

\[CSS21\]
: [Cascading Style Sheets Level 2 Revision 1 (CSS 2.1)
 Specification](https://www.w3.org/TR/CSS2/). Bert Bos; Tantek Çelik;
 Ian Hickson; Håkon Wium Lie. W3C. 7 June 2011. W3C Recommendation.
 URL: <https://www.w3.org/TR/CSS2/>

\[CSS3-BOX\]
: [CSS Box Model Module Level 3](https://www.w3.org/TR/css-box-3/).
 Elika Etemad. W3C. 11 April 2024. W3C Recommendation. URL:
 <https://www.w3.org/TR/css-box-3/>

\[CSS3-DISPLAY\]
: [CSS Display Module Level 3](https://www.w3.org/TR/css-display-3/).
 Elika Etemad; Tab Atkins Jr. W3C. 30 March 2023. W3C Candidate
 Recommendation. URL: <https://www.w3.org/TR/css-display-3/>

\[CSS3-VALUES\]
: [CSS Values and Units Module Level
 3](https://www.w3.org/TR/css-values-3/). Tab Atkins Jr.; Elika
 Etemad. W3C. 22 March 2024. CRD. URL:
 <https://www.w3.org/TR/css-values-3/>

\[CSSOM\]
: [CSS Object Model (CSSOM)](https://www.w3.org/TR/cssom-1/). Daniel
 Glazman; Emilio Cobos Álvarez. W3C. 26 August 2021. W3C Working
 Draft. URL: <https://www.w3.org/TR/cssom-1/>

\[CSSOM-VIEW\]
: [CSSOM View Module](https://www.w3.org/TR/cssom-view-1/). Simon
 Fraser; Emilio Cobos Álvarez. W3C. 16 September 2025. W3C Working
 Draft. URL: <https://www.w3.org/TR/cssom-view-1/>

\[DOM\]
: [DOM Standard](https://dom.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://dom.spec.whatwg.org/>

\[DOM-PARSING\]
: [DOM Parsing and Serialization](https://www.w3.org/TR/DOM-Parsing/).
 Travis Leithead. W3C. 17 May 2016. W3C Working Draft. URL:
 <https://www.w3.org/TR/DOM-Parsing/>

\[ECMA-262\]
: [ECMAScript Language
 Specification](https://tc39.es/ecma262/multipage/). Ecma
 International. URL: <https://tc39.es/ecma262/multipage/>

\[EDITING\]
: [HTML Editing
 APIs](https://dvcs.w3.org/hg/editing/raw-file/tip/editing.html). A.
 Gregor. W3C. URL:
 <https://dvcs.w3.org/hg/editing/raw-file/tip/editing.html>

\[ENCODING\]
: [Encoding Standard](https://encoding.spec.whatwg.org/). Anne van
 Kesteren. WHATWG. Living Standard. URL:
 <https://encoding.spec.whatwg.org/>

\[FETCH\]
: [Fetch Standard](https://fetch.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://fetch.spec.whatwg.org/>

\[fileapi\]
: [File API](https://www.w3.org/TR/FileAPI/). Marijn Kruisselbrink.
 W3C. 4 December 2024. W3C Working Draft. URL:
 <https://www.w3.org/TR/FileAPI/>

\[FULLSCREEN\]
: [Fullscreen API Standard](https://fullscreen.spec.whatwg.org/).
 Philip Jägenstedt. WHATWG. Living Standard. URL:
 <https://fullscreen.spec.whatwg.org/>

\[GEOMETRY-1\]
: [Geometry Interfaces Module Level
 1](https://www.w3.org/TR/geometry-1/). Simon Pieters; Chris
 Harrelson. W3C. 4 December 2018. W3C Candidate Recommendation. URL:
 <https://www.w3.org/TR/geometry-1/>

\[HTML\]
: [HTML Standard](https://html.spec.whatwg.org/multipage/). Anne van
 Kesteren; Domenic Denicola; Dominic Farolino; Ian Hickson; Philip
 Jägenstedt; Simon Pieters. WHATWG. Living Standard. URL:
 <https://html.spec.whatwg.org/multipage/>

\[INFRA\]
: [Infra Standard](https://infra.spec.whatwg.org/). Anne van Kesteren;
 Domenic Denicola. WHATWG. Living Standard. URL:
 <https://infra.spec.whatwg.org/>

\[mediaqueries-4\]
: [Media Queries Level 4](https://www.w3.org/TR/mediaqueries-4/).
 Florian Rivoal; Tab Atkins Jr. W3C. 25 December 2021. CRD. URL:
 <https://www.w3.org/TR/mediaqueries-4/>

\[PAGE-VISIBILITY\]
: [Page Visibility (Second
 Edition)](https://www.w3.org/TR/page-visibility/). Jatinder Mann;
 Arvind Jain. W3C. 29 October 2013. W3C Recommendation. URL:
 <https://www.w3.org/TR/page-visibility/>

\[POINTER-EVENTS\]
: [Pointer Events](https://www.w3.org/TR/pointerevents/). Jacob Rossi;
 Matt Brubeck. W3C. 4 April 2019. W3C Recommendation. URL:
 <https://www.w3.org/TR/pointerevents/>

\[PROMISES-GUIDE\]
: [Writing Promise-Using
 Specifications](https://www.w3.org/2001/tag/doc/promises-guide).
 Domenic Denicola. W3C. 9 November 2018. TAG Finding. URL:
 <https://www.w3.org/2001/tag/doc/promises-guide>

\[RFC1928\]
: [SOCKS Protocol Version
 5](https://www.rfc-editor.org/rfc/rfc1928). M. Leech; M. Ganis; Y.
 Lee; R. Kuris; D. Koblas; L. Jones. IETF. March 1996. Proposed
 Standard. URL: <https://www.rfc-editor.org/rfc/rfc1928>

\[RFC2397\]
: [The \"data\" URL
 scheme](https://www.rfc-editor.org/rfc/rfc2397). L. Masinter. IETF.
 August 1998. Proposed Standard. URL:
 <https://www.rfc-editor.org/rfc/rfc2397>

\[RFC3514\]
: [The Security Flag in the IPv4
 Header](https://www.rfc-editor.org/rfc/rfc3514). S. Bellovin. IETF.
 1 April 2003. Informational. URL:
 <https://www.rfc-editor.org/rfc/rfc3514>

\[RFC4122\]
: [A Universally Unique IDentifier (UUID) URN
 Namespace](https://www.rfc-editor.org/rfc/rfc4122). P. Leach; M.
 Mealling; R. Salz. IETF. July 2005. Proposed Standard. URL:
 <https://www.rfc-editor.org/rfc/rfc4122>

\[RFC4632\]
: [Classless Inter-domain Routing (CIDR): The Internet Address
 Assignment and Aggregation
 Plan](https://www.rfc-editor.org/rfc/rfc4632). V. Fuller; T. Li.
 IETF. August 2006. Best Current Practice. URL:
 <https://www.rfc-editor.org/rfc/rfc4632>

\[RFC4648\]
: [The Base16, Base32, and Base64 Data
 Encodings](https://www.rfc-editor.org/rfc/rfc4648). S. Josefsson.
 IETF. October 2006. Proposed Standard. URL:
 <https://www.rfc-editor.org/rfc/rfc4648>

\[RFC6265\]
: [HTTP State Management
 Mechanism](https://httpwg.org/specs/rfc6265.html). A. Barth. IETF.
 April 2011. Proposed Standard. URL:
 <https://httpwg.org/specs/rfc6265.html>

\[RFC6265bis\]
: [Cookies: HTTP State Management
 Mechanism](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-05). M.
 West; J. Wilander. IETF. Draft. URL:
 <https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-05>

\[RFC7230\]
: [Hypertext Transfer Protocol (HTTP/1.1): Message Syntax and
 Routing](https://httpwg.org/specs/rfc7230.html). R. Fielding,
 Ed.; J. Reschke, Ed. IETF. June 2014. Proposed Standard. URL:
 <https://httpwg.org/specs/rfc7230.html>

\[RFC7231\]
: [Hypertext Transfer Protocol (HTTP/1.1): Semantics and
 Content](https://httpwg.org/specs/rfc7231.html). R. Fielding,
 Ed.; J. Reschke, Ed. IETF. June 2014. Proposed Standard. URL:
 <https://httpwg.org/specs/rfc7231.html>

\[RFC7232\]
: [Hypertext Transfer Protocol (HTTP/1.1): Conditional
 Requests](https://httpwg.org/specs/rfc7232.html). R. Fielding,
 Ed.; J. Reschke, Ed. IETF. June 2014. Proposed Standard. URL:
 <https://httpwg.org/specs/rfc7232.html>

\[RFC7234\]
: [Hypertext Transfer Protocol (HTTP/1.1):
 Caching](https://httpwg.org/specs/rfc7234.html). R. Fielding,
 Ed.; M. Nottingham, Ed.; J. Reschke, Ed. IETF. June 2014. Proposed
 Standard. URL: <https://httpwg.org/specs/rfc7234.html>

\[RFC7235\]
: [Hypertext Transfer Protocol (HTTP/1.1):
 Authentication](https://httpwg.org/specs/rfc7235.html). R. Fielding,
 Ed.; J. Reschke, Ed. IETF. June 2014. Proposed Standard. URL:
 <https://httpwg.org/specs/rfc7235.html>

\[UAX29\]
: [Unicode Text
 Segmentation](https://www.unicode.org/reports/tr29/tr29-47.html).
 Josh Hadley. Unicode Consortium. 17 August 2025. Unicode Standard
 Annex #29. URL: <https://www.unicode.org/reports/tr29/tr29-47.html>

\[UAX44\]
: [Unicode Character
 Database](https://www.unicode.org/reports/tr44/tr44-36.html). Ken
 Whistler. Unicode Consortium. 27 August 2025. Unicode Standard Annex
 #44. URL: <https://www.unicode.org/reports/tr44/tr44-36.html>

\[UI-EVENTS\]
: [UI Events](https://www.w3.org/TR/uievents/). Gary Kacmarcik; Travis
 Leithead. W3C. 7 September 2024. W3C Working Draft. URL:
 <https://www.w3.org/TR/uievents/>

\[UIEVENTS-KEY\]
: [UI Events KeyboardEvent key
 Values](https://www.w3.org/TR/uievents-key/). Travis Leithead; Gary
 Kacmarcik. W3C. 22 April 2025. W3C Recommendation. URL:
 <https://www.w3.org/TR/uievents-key/>

\[Unicode\]
: [The Unicode Standard](https://www.unicode.org/versions/latest/).
 Unicode Consortium. URL: <https://www.unicode.org/versions/latest/>

\[URI-TEMPLATE\]
: [URI Template](https://www.rfc-editor.org/rfc/rfc6570). J.
 Gregorio; R. Fielding; M. Hadley; M. Nottingham; D. Orchard. IETF.
 March 2012. Proposed Standard. URL:
 <https://www.rfc-editor.org/rfc/rfc6570>

\[URL\]
: [URL Standard](https://url.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://url.spec.whatwg.org/>

\[wai-aria-1.2\]
: [Accessible Rich Internet Applications (WAI-ARIA)
 1.2](https://www.w3.org/TR/wai-aria-1.2/). Joanmarie Diggs; James
 Nurthen; Michael Cooper; Carolyn MacLeod. W3C. 6 June 2023. W3C
 Recommendation. URL: <https://www.w3.org/TR/wai-aria-1.2/>

\[WebDriver-BiDi\]
: [WebDriver BiDi](https://www.w3.org/TR/webdriver-bidi/). James
 Graham; Alex Rudenko; Maksim Sadym. W3C. 21 October 2025. W3C
 Working Draft. URL: <https://www.w3.org/TR/webdriver-bidi/>

\[WEBIDL\]
: [Web IDL Standard](https://webidl.spec.whatwg.org/). Edgar Chen;
 Timothy Gu. WHATWG. Living Standard. URL:
 <https://webidl.spec.whatwg.org/>

\[XPATH\]
: [XML Path Language (XPath) Version
 1.0](https://www.w3.org/TR/xpath-10/). James Clark; Steven DeRose.
 W3C. 16 November 1999. W3C Recommendation. URL:
 <https://www.w3.org/TR/xpath-10/>

[[↑]](#title)

[Permalink](#dfn-min)

**Referenced in:**

- [§ 12.1 Interactability](#ref-for-dfn-min-1 "§ 12.1 Interactability")
 [(2)](#ref-for-dfn-min-2 "Reference 2")
 [(3)](#ref-for-dfn-min-3 "Reference 3")
 [(4)](#ref-for-dfn-min-4 "Reference 4")
- [§ 17. Screen capture](#ref-for-dfn-min-5 "§ 17. Screen capture")
 [(2)](#ref-for-dfn-min-6 "Reference 2")

[Permalink](#dfn-max)

**Referenced in:**

- [§ 12.1 Interactability](#ref-for-dfn-max-1 "§ 12.1 Interactability")
 [(2)](#ref-for-dfn-max-2 "Reference 2")
 [(3)](#ref-for-dfn-max-3 "Reference 3")
 [(4)](#ref-for-dfn-max-4 "Reference 4")

[Permalink](#dfn-floor)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-dfn-floor-1 "§ 12.1 Interactability")
 [(2)](#ref-for-dfn-floor-2 "Reference 2")

[Permalink](#dfn-uuid)

**Referenced in:**

- [§ 8. Sessions](#ref-for-dfn-uuid-1 "§ 8. Sessions")

[Permalink](#dfn-generating-a-uuid)

**Referenced in:**

- [§ 8.1 Global
 State](#ref-for-dfn-generating-a-uuid-1 "§ 8.1 Global State")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-generating-a-uuid-2 "§ 12.5.1 Element Click")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-generating-a-uuid-3 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-unix-timestamp)

**Referenced in:**

- [§ 14. Cookies](#ref-for-dfn-unix-timestamp-1 "§ 14. Cookies")
 [(2)](#ref-for-dfn-unix-timestamp-2 "Reference 2")

[Permalink](#dfn-integer)

**Referenced in:**

- [§ 7.1 Proxy](#ref-for-dfn-integer-1 "§ 7.1 Proxy")
- [§ 15.5 Processing
 actions](#ref-for-dfn-integer-2 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-integer-3 "Reference 2")
 [(3)](#ref-for-dfn-integer-4 "Reference 3")
 [(4)](#ref-for-dfn-integer-5 "Reference 4")
 [(5)](#ref-for-dfn-integer-6 "Reference 5")
 [(6)](#ref-for-dfn-integer-7 "Reference 6")
 [(7)](#ref-for-dfn-integer-8 "Reference 7")
 [(8)](#ref-for-dfn-integer-9 "Reference 8")
 [(9)](#ref-for-dfn-integer-10 "Reference 9")
 [(10)](#ref-for-dfn-integer-11 "Reference 10")
 [(11)](#ref-for-dfn-integer-12 "Reference 11")
 [(12)](#ref-for-dfn-integer-13 "Reference 12")
 [(13)](#ref-for-dfn-integer-14 "Reference 13")
 [(14)](#ref-for-dfn-integer-15 "Reference 14")

[Permalink](#dfn-initial-value)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-initial-value-1 "§ 13.2 Executing Script")

[Permalink](#dfn-browser-chrome)

**Referenced in:**

- [§ 10.3 Back](#ref-for-dfn-browser-chrome-1 "§ 10.3 Back")
- [§ 10.4 Forward](#ref-for-dfn-browser-chrome-2 "§ 10.4 Forward")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-browser-chrome-3 "§ 11.8.2 Set Window Rect")
 [(2)](#ref-for-dfn-browser-chrome-4 "Reference 2")

[Permalink](#dfn-browser-chrome-element)

**Referenced in:**

- [§ B. Security](#ref-for-dfn-browser-chrome-element-1 "§ B. Security")

[Permalink](#dfn-webdriver-active-flag)

**Referenced in:**

- [§ 4.
 Interface](#ref-for-dfn-webdriver-active-flag-1 "§ 4. Interface")
- [§ 8.1 Global
 State](#ref-for-dfn-webdriver-active-flag-2 "§ 8.1 Global State")
 [(2)](#ref-for-dfn-webdriver-active-flag-3 "Reference 2")

[Permalink](#dom-navigatorautomationinformation)
[exported]

**Referenced in:**

- [§ 4.
 Interface](#ref-for-dom-navigatorautomationinformation-1 "§ 4. Interface")
 [(2)](#ref-for-dom-navigatorautomationinformation-2 "Reference 2")

[Permalink](#dom-navigatorautomationinformation-webdriver)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-webdriver)

**Referenced in:**

- [§ 4. Interface](#ref-for-dfn-webdriver-1 "§ 4. Interface")

[Permalink](#dfn-local-ends)
[exported]

**Referenced in:**

- [§ 5. Nodes](#ref-for-dfn-local-ends-1 "§ 5. Nodes")
 [(2)](#ref-for-dfn-local-ends-2 "Reference 2")
- [§ 6. Protocol](#ref-for-dfn-local-ends-3 "§ 6. Protocol")
 [(2)](#ref-for-dfn-local-ends-4 "Reference 2")
- [§ 6.3 Processing
 model](#ref-for-dfn-local-ends-5 "§ 6.3 Processing model")
- [§ 6.7 Extensions](#ref-for-dfn-local-ends-6 "§ 6.7 Extensions")
- [§ 7. Capabilities](#ref-for-dfn-local-ends-7 "§ 7. Capabilities")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-local-ends-8 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-local-ends-9 "Reference 2")
 [(3)](#ref-for-dfn-local-ends-10 "Reference 3")
- [§ 8. Sessions](#ref-for-dfn-local-ends-11 "§ 8. Sessions")
- [§ 10.1 Navigate To](#ref-for-dfn-local-ends-12 "§ 10.1 Navigate To")
- [§ 11. Contexts](#ref-for-dfn-local-ends-13 "§ 11. Contexts")
 [(2)](#ref-for-dfn-local-ends-14 "Reference 2")
- [§ 12. Elements](#ref-for-dfn-local-ends-15 "§ 12. Elements")
- [§ 12.2 Shadow
 Roots](#ref-for-dfn-local-ends-16 "§ 12.2 Shadow Roots")
- [§ 15. Actions](#ref-for-dfn-local-ends-17 "§ 15. Actions")
- [§ 17. Screen
 capture](#ref-for-dfn-local-ends-18 "§ 17. Screen capture")
- [§ 18. Print](#ref-for-dfn-local-ends-19 "§ 18. Print")

[Permalink](#dfn-remote-ends)

**Referenced in:**

- [§ 5. Nodes](#ref-for-dfn-remote-ends-1 "§ 5. Nodes")
 [(2)](#ref-for-dfn-remote-ends-2 "Reference 2")
 [(3)](#ref-for-dfn-remote-ends-3 "Reference 3")
 [(4)](#ref-for-dfn-remote-ends-4 "Reference 4")
 [(5)](#ref-for-dfn-remote-ends-5 "Reference 5")
 [(6)](#ref-for-dfn-remote-ends-6 "Reference 6")
 [(7)](#ref-for-dfn-remote-ends-7 "Reference 7")
 [(8)](#ref-for-dfn-remote-ends-8 "Reference 8")
- [§ 6. Protocol](#ref-for-dfn-remote-ends-9 "§ 6. Protocol")
 [(2)](#ref-for-dfn-remote-ends-10 "Reference 2")
 [(3)](#ref-for-dfn-remote-ends-11 "Reference 3")
- [§ 6.2 Commands](#ref-for-dfn-remote-ends-12 "§ 6.2 Commands")
 [(2)](#ref-for-dfn-remote-ends-13 "Reference 2")
- [§ 6.3 Processing
 model](#ref-for-dfn-remote-ends-14 "§ 6.3 Processing model")
 [(2)](#ref-for-dfn-remote-ends-15 "Reference 2")
 [(3)](#ref-for-dfn-remote-ends-16 "Reference 3")
 [(4)](#ref-for-dfn-remote-ends-17 "Reference 4")
 [(5)](#ref-for-dfn-remote-ends-18 "Reference 5")
 [(6)](#ref-for-dfn-remote-ends-19 "Reference 6")
 [(7)](#ref-for-dfn-remote-ends-20 "Reference 7")
 [(8)](#ref-for-dfn-remote-ends-21 "Reference 8")
- [§ 6.4 Routing
 requests](#ref-for-dfn-remote-ends-22 "§ 6.4 Routing requests")
 [(2)](#ref-for-dfn-remote-ends-23 "Reference 2")
 [(3)](#ref-for-dfn-remote-ends-24 "Reference 3")
- [§ 6.6 Errors](#ref-for-dfn-remote-ends-25 "§ 6.6 Errors")
 [(2)](#ref-for-dfn-remote-ends-26 "Reference 2")
- [§ 6.7 Extensions](#ref-for-dfn-remote-ends-27 "§ 6.7 Extensions")
 [(2)](#ref-for-dfn-remote-ends-28 "Reference 2")
 [(3)](#ref-for-dfn-remote-ends-29 "Reference 3")
- [§ 7. Capabilities](#ref-for-dfn-remote-ends-30 "§ 7. Capabilities")
 [(2)](#ref-for-dfn-remote-ends-31 "Reference 2")
- [§ 7.1 Proxy](#ref-for-dfn-remote-ends-32 "§ 7.1 Proxy")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-remote-ends-33 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-remote-ends-34 "Reference 2")
 [(3)](#ref-for-dfn-remote-ends-35 "Reference 3")
 [(4)](#ref-for-dfn-remote-ends-36 "Reference 4")
 [(5)](#ref-for-dfn-remote-ends-37 "Reference 5")
- [§ 8. Sessions](#ref-for-dfn-remote-ends-38 "§ 8. Sessions")
 [(2)](#ref-for-dfn-remote-ends-39 "Reference 2")
 [(3)](#ref-for-dfn-remote-ends-40 "Reference 3")
- [§ 8.1 Global State](#ref-for-dfn-remote-ends-41 "§ 8.1 Global State")
 [(2)](#ref-for-dfn-remote-ends-42 "Reference 2")
 [(3)](#ref-for-dfn-remote-ends-43 "Reference 3")
 [(4)](#ref-for-dfn-remote-ends-44 "Reference 4")
 [(5)](#ref-for-dfn-remote-ends-45 "Reference 5")
- [§ 8.2 New Session](#ref-for-dfn-remote-ends-46 "§ 8.2 New Session")
 [(2)](#ref-for-dfn-remote-ends-47 "Reference 2")
 [(3)](#ref-for-dfn-remote-ends-48 "Reference 3")
 [(4)](#ref-for-dfn-remote-ends-49 "Reference 4")
 [(5)](#ref-for-dfn-remote-ends-50 "Reference 5")
- [§ 8.4 Status](#ref-for-dfn-remote-ends-51 "§ 8.4 Status")
 [(2)](#ref-for-dfn-remote-ends-52 "Reference 2")
 [(3)](#ref-for-dfn-remote-ends-53 "Reference 3")
 [(4)](#ref-for-dfn-remote-ends-54 "Reference 4")
- [§ 10. Navigation](#ref-for-dfn-remote-ends-55 "§ 10. Navigation")
- [§ 10.1 Navigate To](#ref-for-dfn-remote-ends-56 "§ 10.1 Navigate To")
- [§ 11. Contexts](#ref-for-dfn-remote-ends-57 "§ 11. Contexts")
 [(2)](#ref-for-dfn-remote-ends-58 "Reference 2")
- [§ 11.4 Get Window
 Handles](#ref-for-dfn-remote-ends-59 "§ 11.4 Get Window Handles")
- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-remote-ends-60 "§ 11.8 Resizing and positioning windows")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-remote-ends-61 "§ 11.8.2 Set Window Rect")
- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-remote-ends-62 "§ 11.8.3 Maximize Window")
- [§ 11.8.4 Minimize
 Window](#ref-for-dfn-remote-ends-63 "§ 11.8.4 Minimize Window")
- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-remote-ends-64 "§ 11.8.5 Fullscreen Window")
- [§ 12. Elements](#ref-for-dfn-remote-ends-65 "§ 12. Elements")
- [§ 12.2 Shadow
 Roots](#ref-for-dfn-remote-ends-66 "§ 12.2 Shadow Roots")
- [§ 12.3 Retrieval](#ref-for-dfn-remote-ends-67 "§ 12.3 Retrieval")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-remote-ends-68 "§ 12.5.3 Element Send Keys")
- [§ 13.2 Executing
 Script](#ref-for-dfn-remote-ends-69 "§ 13.2 Executing Script")
- [§ 14. Cookies](#ref-for-dfn-remote-ends-70 "§ 14. Cookies")
- [§ 15. Actions](#ref-for-dfn-remote-ends-71 "§ 15. Actions")
 [(2)](#ref-for-dfn-remote-ends-72 "Reference 2")
 [(3)](#ref-for-dfn-remote-ends-73 "Reference 3")
 [(4)](#ref-for-dfn-remote-ends-74 "Reference 4")
- [§ 15.4 Ticks](#ref-for-dfn-remote-ends-75 "§ 15.4 Ticks")
 [(2)](#ref-for-dfn-remote-ends-76 "Reference 2")
- [§ 15.5 Processing
 actions](#ref-for-dfn-remote-ends-77 "§ 15.5 Processing actions")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-remote-ends-78 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-remote-ends-79 "Reference 2")
- [§ A. Privacy](#ref-for-dfn-remote-ends-80 "§ A. Privacy")
- [§ B. Security](#ref-for-dfn-remote-ends-81 "§ B. Security")

[Permalink](#dfn-node-type)

**Referenced in:**

- [§ 5. Nodes](#ref-for-dfn-node-type-1 "§ 5. Nodes")

[Permalink](#dfn-intermediary-nodes)

**Referenced in:**

- [§ 5. Nodes](#ref-for-dfn-intermediary-nodes-1 "§ 5. Nodes")
 [(2)](#ref-for-dfn-intermediary-nodes-2 "Reference 2")
 [(3)](#ref-for-dfn-intermediary-nodes-3 "Reference 3")
- [§ 6.7
 Extensions](#ref-for-dfn-intermediary-nodes-4 "§ 6.7 Extensions")
- [§ 8. Sessions](#ref-for-dfn-intermediary-nodes-5 "§ 8. Sessions")
 [(2)](#ref-for-dfn-intermediary-nodes-6 "Reference 2")
 [(3)](#ref-for-dfn-intermediary-nodes-7 "Reference 3")
- [§ 8.1 Global
 State](#ref-for-dfn-intermediary-nodes-8 "§ 8.1 Global State")
- [§ 8.2 New
 Session](#ref-for-dfn-intermediary-nodes-9 "§ 8.2 New Session")
 [(2)](#ref-for-dfn-intermediary-nodes-10 "Reference 2")
 [(3)](#ref-for-dfn-intermediary-nodes-11 "Reference 3")
 [(4)](#ref-for-dfn-intermediary-nodes-12 "Reference 4")
 [(5)](#ref-for-dfn-intermediary-nodes-13 "Reference 5")
 [(6)](#ref-for-dfn-intermediary-nodes-14 "Reference 6")
 [(7)](#ref-for-dfn-intermediary-nodes-15 "Reference 7")
 [(8)](#ref-for-dfn-intermediary-nodes-16 "Reference 8")

[Permalink](#dfn-upstream)

**Referenced in:**

- [§ 8. Sessions](#ref-for-dfn-upstream-1 "§ 8. Sessions")
- [§ 8.2 New Session](#ref-for-dfn-upstream-2 "§ 8.2 New Session")
 [(2)](#ref-for-dfn-upstream-3 "Reference 2")

[Permalink](#dfn-endpoint-node)

**Referenced in:**

- [§ 5. Nodes](#ref-for-dfn-endpoint-node-1 "§ 5. Nodes")
 [(2)](#ref-for-dfn-endpoint-node-2 "Reference 2")
 [(3)](#ref-for-dfn-endpoint-node-3 "Reference 3")
 [(4)](#ref-for-dfn-endpoint-node-4 "Reference 4")
- [§ 6.5 Endpoints](#ref-for-dfn-endpoint-node-5 "§ 6.5 Endpoints")
- [§ 7. Capabilities](#ref-for-dfn-endpoint-node-6 "§ 7. Capabilities")
 [(2)](#ref-for-dfn-endpoint-node-7 "Reference 2")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-endpoint-node-8 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-endpoint-node-9 "Reference 2")
 [(3)](#ref-for-dfn-endpoint-node-10 "Reference 3")
 [(4)](#ref-for-dfn-endpoint-node-11 "Reference 4")
 [(5)](#ref-for-dfn-endpoint-node-12 "Reference 5")
 [(6)](#ref-for-dfn-endpoint-node-13 "Reference 6")
- [§ 8. Sessions](#ref-for-dfn-endpoint-node-14 "§ 8. Sessions")
- [§ 8.1 Global
 State](#ref-for-dfn-endpoint-node-15 "§ 8.1 Global State")
 [(2)](#ref-for-dfn-endpoint-node-16 "Reference 2")
 [(3)](#ref-for-dfn-endpoint-node-17 "Reference 3")
 [(4)](#ref-for-dfn-endpoint-node-18 "Reference 4")
 [(5)](#ref-for-dfn-endpoint-node-19 "Reference 5")
- [§ 8.2 New Session](#ref-for-dfn-endpoint-node-20 "§ 8.2 New Session")
 [(2)](#ref-for-dfn-endpoint-node-21 "Reference 2")
 [(3)](#ref-for-dfn-endpoint-node-22 "Reference 3")
 [(4)](#ref-for-dfn-endpoint-node-23 "Reference 4")
 [(5)](#ref-for-dfn-endpoint-node-24 "Reference 5")
 [(6)](#ref-for-dfn-endpoint-node-25 "Reference 6")
 [(7)](#ref-for-dfn-endpoint-node-26 "Reference 7")

[Permalink](#dfn-readiness-state)

**Referenced in:**

- [§ 8.4 Status](#ref-for-dfn-readiness-state-1 "§ 8.4 Status")
 [(2)](#ref-for-dfn-readiness-state-2 "Reference 2")
 [(3)](#ref-for-dfn-readiness-state-3 "Reference 3")

[Permalink](#dfn-success)
[exported]

**Referenced in:**

- [§ 6.1 Algorithms](#ref-for-dfn-success-1 "§ 6.1 Algorithms")
- [§ 6.3 Processing
 model](#ref-for-dfn-success-2 "§ 6.3 Processing model")
- [§ 6.4 Routing
 requests](#ref-for-dfn-success-3 "§ 6.4 Routing requests")
- [§ 6.7 Extensions](#ref-for-dfn-success-4 "§ 6.7 Extensions")
- [§ 7.1 Proxy](#ref-for-dfn-success-5 "§ 7.1 Proxy")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-success-6 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-success-7 "Reference 2")
 [(3)](#ref-for-dfn-success-8 "Reference 3")
 [(4)](#ref-for-dfn-success-9 "Reference 4")
 [(5)](#ref-for-dfn-success-10 "Reference 5")
 [(6)](#ref-for-dfn-success-11 "Reference 6")
 [(7)](#ref-for-dfn-success-12 "Reference 7")
 [(8)](#ref-for-dfn-success-13 "Reference 8")
 [(9)](#ref-for-dfn-success-14 "Reference 9")
 [(10)](#ref-for-dfn-success-15 "Reference 10")
 [(11)](#ref-for-dfn-success-16 "Reference 11")
- [§ 8.1 Global State](#ref-for-dfn-success-17 "§ 8.1 Global State")
- [§ 8.2 New Session](#ref-for-dfn-success-18 "§ 8.2 New Session")
 [(2)](#ref-for-dfn-success-19 "Reference 2")
- [§ 8.3 Delete Session](#ref-for-dfn-success-20 "§ 8.3 Delete Session")
- [§ 8.4 Status](#ref-for-dfn-success-21 "§ 8.4 Status")
- [§ 9. Timeouts](#ref-for-dfn-success-22 "§ 9. Timeouts")
- [§ 9.1 Get Timeouts](#ref-for-dfn-success-23 "§ 9.1 Get Timeouts")
- [§ 9.2 Set Timeouts](#ref-for-dfn-success-24 "§ 9.2 Set Timeouts")
- [§ 10. Navigation](#ref-for-dfn-success-25 "§ 10. Navigation")
 [(2)](#ref-for-dfn-success-26 "Reference 2")
 [(3)](#ref-for-dfn-success-27 "Reference 3")
 [(4)](#ref-for-dfn-success-28 "Reference 4")
 [(5)](#ref-for-dfn-success-29 "Reference 5")
- [§ 10.1 Navigate To](#ref-for-dfn-success-30 "§ 10.1 Navigate To")
- [§ 10.2 Get Current
 URL](#ref-for-dfn-success-31 "§ 10.2 Get Current URL")
- [§ 10.3 Back](#ref-for-dfn-success-32 "§ 10.3 Back")
- [§ 10.4 Forward](#ref-for-dfn-success-33 "§ 10.4 Forward")
- [§ 10.5 Refresh](#ref-for-dfn-success-34 "§ 10.5 Refresh")
- [§ 10.6 Get Title](#ref-for-dfn-success-35 "§ 10.6 Get Title")
- [§ 11. Contexts](#ref-for-dfn-success-36 "§ 11. Contexts")
 [(2)](#ref-for-dfn-success-37 "Reference 2")
- [§ 11.1 Get Window
 Handle](#ref-for-dfn-success-38 "§ 11.1 Get Window Handle")
- [§ 11.3 Switch To
 Window](#ref-for-dfn-success-39 "§ 11.3 Switch To Window")
- [§ 11.4 Get Window
 Handles](#ref-for-dfn-success-40 "§ 11.4 Get Window Handles")
- [§ 11.5 New Window](#ref-for-dfn-success-41 "§ 11.5 New Window")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-success-42 "§ 11.6 Switch To Frame")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-dfn-success-43 "§ 11.7 Switch To Parent Frame")
 [(2)](#ref-for-dfn-success-44 "Reference 2")
- [§ 11.8.1 Get Window
 Rect](#ref-for-dfn-success-45 "§ 11.8.1 Get Window Rect")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-success-46 "§ 11.8.2 Set Window Rect")
- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-success-47 "§ 11.8.3 Maximize Window")
- [§ 11.8.4 Minimize
 Window](#ref-for-dfn-success-48 "§ 11.8.4 Minimize Window")
- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-success-49 "§ 11.8.5 Fullscreen Window")
- [§ 12. Elements](#ref-for-dfn-success-50 "§ 12. Elements")
 [(2)](#ref-for-dfn-success-51 "Reference 2")
- [§ 12.2 Shadow Roots](#ref-for-dfn-success-52 "§ 12.2 Shadow Roots")
 [(2)](#ref-for-dfn-success-53 "Reference 2")
- [§ 12.3 Retrieval](#ref-for-dfn-success-54 "§ 12.3 Retrieval")
- [§ 12.3.1.1 CSS
 selectors](#ref-for-dfn-success-55 "§ 12.3.1.1 CSS selectors")
- [§ 12.3.1.2 Link text](#ref-for-dfn-success-56 "§ 12.3.1.2 Link text")
- [§ 12.3.1.3 Partial link
 text](#ref-for-dfn-success-57 "§ 12.3.1.3 Partial link text")
- [§ 12.3.1.4 Tag name](#ref-for-dfn-success-58 "§ 12.3.1.4 Tag name")
- [§ 12.3.1.5 XPath](#ref-for-dfn-success-59 "§ 12.3.1.5 XPath")
- [§ 12.3.8 Get Active
 Element](#ref-for-dfn-success-60 "§ 12.3.8 Get Active Element")
- [§ 12.3.9 Get Element Shadow
 Root](#ref-for-dfn-success-61 "§ 12.3.9 Get Element Shadow Root")
- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-success-62 "§ 12.4.1 Is Element Selected")
- [§ 12.4.2 Get Element
 Attribute](#ref-for-dfn-success-63 "§ 12.4.2 Get Element Attribute")
- [§ 12.4.3 Get Element
 Property](#ref-for-dfn-success-64 "§ 12.4.3 Get Element Property")
- [§ 12.4.4 Get Element CSS
 Value](#ref-for-dfn-success-65 "§ 12.4.4 Get Element CSS Value")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-success-66 "§ 12.4.5 Get Element Text")
- [§ 12.4.6 Get Element Tag
 Name](#ref-for-dfn-success-67 "§ 12.4.6 Get Element Tag Name")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-success-68 "§ 12.4.7 Get Element Rect")
- [§ 12.4.8 Is Element
 Enabled](#ref-for-dfn-success-69 "§ 12.4.8 Is Element Enabled")
- [§ 12.4.9 Get Computed
 Role](#ref-for-dfn-success-70 "§ 12.4.9 Get Computed Role")
- [§ 12.4.10 Get Computed
 Label](#ref-for-dfn-success-71 "§ 12.4.10 Get Computed Label")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-success-72 "§ 12.5.1 Element Click")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-success-73 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-success-74 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-success-75 "Reference 2")
 [(3)](#ref-for-dfn-success-76 "Reference 3")
- [§ 13.1 Get Page
 Source](#ref-for-dfn-success-77 "§ 13.1 Get Page Source")
- [§ 13.2 Executing
 Script](#ref-for-dfn-success-78 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-success-79 "Reference 2")
 [(3)](#ref-for-dfn-success-80 "Reference 3")
 [(4)](#ref-for-dfn-success-81 "Reference 4")
 [(5)](#ref-for-dfn-success-82 "Reference 5")
 [(6)](#ref-for-dfn-success-83 "Reference 6")
 [(7)](#ref-for-dfn-success-84 "Reference 7")
 [(8)](#ref-for-dfn-success-85 "Reference 8")
 [(9)](#ref-for-dfn-success-86 "Reference 9")
 [(10)](#ref-for-dfn-success-87 "Reference 10")
 [(11)](#ref-for-dfn-success-88 "Reference 11")
- [§ 13.2.1 Execute
 Script](#ref-for-dfn-success-89 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-success-90 "§ 13.2.2 Execute Async Script")
- [§ 14.1 Get All
 Cookies](#ref-for-dfn-success-91 "§ 14.1 Get All Cookies")
- [§ 14.2 Get Named
 Cookie](#ref-for-dfn-success-92 "§ 14.2 Get Named Cookie")
- [§ 14.3 Add Cookie](#ref-for-dfn-success-93 "§ 14.3 Add Cookie")
- [§ 14.4 Delete Cookie](#ref-for-dfn-success-94 "§ 14.4 Delete Cookie")
- [§ 14.5 Delete All
 Cookies](#ref-for-dfn-success-95 "§ 14.5 Delete All Cookies")
- [§ 15.1 Actions
 Options](#ref-for-dfn-success-96 "§ 15.1 Actions Options")
- [§ 15.2 Input sources](#ref-for-dfn-success-97 "§ 15.2 Input sources")
- [§ 15.5 Processing
 actions](#ref-for-dfn-success-98 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-success-99 "Reference 2")
 [(3)](#ref-for-dfn-success-100 "Reference 3")
 [(4)](#ref-for-dfn-success-101 "Reference 4")
 [(5)](#ref-for-dfn-success-102 "Reference 5")
 [(6)](#ref-for-dfn-success-103 "Reference 6")
- [§ 15.6 Dispatching
 actions](#ref-for-dfn-success-104 "§ 15.6 Dispatching actions")
- [§ 15.6.1 General
 actions](#ref-for-dfn-success-105 "§ 15.6.1 General actions")
- [§ 15.6.2 Keyboard
 actions](#ref-for-dfn-success-106 "§ 15.6.2 Keyboard actions")
 [(2)](#ref-for-dfn-success-107 "Reference 2")
- [§ 15.6.3 Pointer
 actions](#ref-for-dfn-success-108 "§ 15.6.3 Pointer actions")
 [(2)](#ref-for-dfn-success-109 "Reference 2")
 [(3)](#ref-for-dfn-success-110 "Reference 3")
 [(4)](#ref-for-dfn-success-111 "Reference 4")
 [(5)](#ref-for-dfn-success-112 "Reference 5")
 [(6)](#ref-for-dfn-success-113 "Reference 6")
- [§ 15.6.4 Wheel
 actions](#ref-for-dfn-success-114 "§ 15.6.4 Wheel actions")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-success-115 "§ 15.7 Perform Actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-success-116 "§ 15.8 Release Actions")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-success-117 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-success-118 "Reference 2")
 [(3)](#ref-for-dfn-success-119 "Reference 3")
- [§ 16.2 Dismiss
 Alert](#ref-for-dfn-success-120 "§ 16.2 Dismiss Alert")
- [§ 16.3 Accept Alert](#ref-for-dfn-success-121 "§ 16.3 Accept Alert")
- [§ 16.4 Get Alert
 Text](#ref-for-dfn-success-122 "§ 16.4 Get Alert Text")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-success-123 "§ 16.5 Send Alert Text")
- [§ 17. Screen
 capture](#ref-for-dfn-success-124 "§ 17. Screen capture")
 [(2)](#ref-for-dfn-success-125 "Reference 2")
- [§ 17.1 Take
 Screenshot](#ref-for-dfn-success-126 "§ 17.1 Take Screenshot")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-success-127 "§ 17.2 Take Element Screenshot")
- [§ 18. Print](#ref-for-dfn-success-128 "§ 18. Print")
 [(2)](#ref-for-dfn-success-129 "Reference 2")
- [§ 18.1 Print Page](#ref-for-dfn-success-130 "§ 18.1 Print Page")
- [§ C. Element
 displayedness](#ref-for-dfn-success-131 "§ C. Element displayedness")

[Permalink](#dfn-error)
[exported]

**Referenced in:**

- [§ 6.1 Algorithms](#ref-for-dfn-error-1 "§ 6.1 Algorithms")
 [(2)](#ref-for-dfn-error-2 "Reference 2")
- [§ 6.3 Processing
 model](#ref-for-dfn-error-3 "§ 6.3 Processing model")
 [(2)](#ref-for-dfn-error-4 "Reference 2")
 [(3)](#ref-for-dfn-error-5 "Reference 3")
 [(4)](#ref-for-dfn-error-6 "Reference 4")
 [(5)](#ref-for-dfn-error-7 "Reference 5")
- [§ 6.4 Routing
 requests](#ref-for-dfn-error-8 "§ 6.4 Routing requests")
 [(2)](#ref-for-dfn-error-9 "Reference 2")
- [§ 6.6 Errors](#ref-for-dfn-error-10 "§ 6.6 Errors")
 [(2)](#ref-for-dfn-error-11 "Reference 2")
 [(3)](#ref-for-dfn-error-12 "Reference 3")
 [(4)](#ref-for-dfn-error-13 "Reference 4")
- [§ 6.7 Extensions](#ref-for-dfn-error-14 "§ 6.7 Extensions")
- [§ 7.1 Proxy](#ref-for-dfn-error-15 "§ 7.1 Proxy")
 [(2)](#ref-for-dfn-error-16 "Reference 2")
 [(3)](#ref-for-dfn-error-17 "Reference 3")
 [(4)](#ref-for-dfn-error-18 "Reference 4")
 [(5)](#ref-for-dfn-error-19 "Reference 5")
 [(6)](#ref-for-dfn-error-20 "Reference 6")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-error-21 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-error-22 "Reference 2")
 [(3)](#ref-for-dfn-error-23 "Reference 3")
 [(4)](#ref-for-dfn-error-24 "Reference 4")
 [(5)](#ref-for-dfn-error-25 "Reference 5")
 [(6)](#ref-for-dfn-error-26 "Reference 6")
 [(7)](#ref-for-dfn-error-27 "Reference 7")
 [(8)](#ref-for-dfn-error-28 "Reference 8")
- [§ 8.1 Global State](#ref-for-dfn-error-29 "§ 8.1 Global State")
 [(2)](#ref-for-dfn-error-30 "Reference 2")
 [(3)](#ref-for-dfn-error-31 "Reference 3")
 [(4)](#ref-for-dfn-error-32 "Reference 4")
 [(5)](#ref-for-dfn-error-33 "Reference 5")
- [§ 8.2 New Session](#ref-for-dfn-error-34 "§ 8.2 New Session")
 [(2)](#ref-for-dfn-error-35 "Reference 2")
 [(3)](#ref-for-dfn-error-36 "Reference 3")
 [(4)](#ref-for-dfn-error-37 "Reference 4")
 [(5)](#ref-for-dfn-error-38 "Reference 5")
- [§ 9. Timeouts](#ref-for-dfn-error-39 "§ 9. Timeouts")
- [§ 10. Navigation](#ref-for-dfn-error-40 "§ 10. Navigation")
 [(2)](#ref-for-dfn-error-41 "Reference 2")
 [(3)](#ref-for-dfn-error-42 "Reference 3")
 [(4)](#ref-for-dfn-error-43 "Reference 4")
 [(5)](#ref-for-dfn-error-44 "Reference 5")
 [(6)](#ref-for-dfn-error-45 "Reference 6")
- [§ 10.1 Navigate To](#ref-for-dfn-error-46 "§ 10.1 Navigate To")
 [(2)](#ref-for-dfn-error-47 "Reference 2")
 [(3)](#ref-for-dfn-error-48 "Reference 3")
- [§ 10.2 Get Current
 URL](#ref-for-dfn-error-49 "§ 10.2 Get Current URL")
- [§ 10.3 Back](#ref-for-dfn-error-50 "§ 10.3 Back")
 [(2)](#ref-for-dfn-error-51 "Reference 2")
- [§ 10.4 Forward](#ref-for-dfn-error-52 "§ 10.4 Forward")
 [(2)](#ref-for-dfn-error-53 "Reference 2")
- [§ 10.5 Refresh](#ref-for-dfn-error-54 "§ 10.5 Refresh")
- [§ 10.6 Get Title](#ref-for-dfn-error-55 "§ 10.6 Get Title")
- [§ 11. Contexts](#ref-for-dfn-error-56 "§ 11. Contexts")
 [(2)](#ref-for-dfn-error-57 "Reference 2")
 [(3)](#ref-for-dfn-error-58 "Reference 3")
 [(4)](#ref-for-dfn-error-59 "Reference 4")
 [(5)](#ref-for-dfn-error-60 "Reference 5")
 [(6)](#ref-for-dfn-error-61 "Reference 6")
- [§ 11.1 Get Window
 Handle](#ref-for-dfn-error-62 "§ 11.1 Get Window Handle")
- [§ 11.2 Close Window](#ref-for-dfn-error-63 "§ 11.2 Close Window")
- [§ 11.3 Switch To
 Window](#ref-for-dfn-error-64 "§ 11.3 Switch To Window")
 [(2)](#ref-for-dfn-error-65 "Reference 2")
 [(3)](#ref-for-dfn-error-66 "Reference 3")
- [§ 11.5 New Window](#ref-for-dfn-error-67 "§ 11.5 New Window")
 [(2)](#ref-for-dfn-error-68 "Reference 2")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-error-69 "§ 11.6 Switch To Frame")
 [(2)](#ref-for-dfn-error-70 "Reference 2")
 [(3)](#ref-for-dfn-error-71 "Reference 3")
 [(4)](#ref-for-dfn-error-72 "Reference 4")
 [(5)](#ref-for-dfn-error-73 "Reference 5")
 [(6)](#ref-for-dfn-error-74 "Reference 6")
 [(7)](#ref-for-dfn-error-75 "Reference 7")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-dfn-error-76 "§ 11.7 Switch To Parent Frame")
 [(2)](#ref-for-dfn-error-77 "Reference 2")
- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-error-78 "§ 11.8 Resizing and positioning windows")
- [§ 11.8.1 Get Window
 Rect](#ref-for-dfn-error-79 "§ 11.8.1 Get Window Rect")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-error-80 "§ 11.8.2 Set Window Rect")
 [(2)](#ref-for-dfn-error-81 "Reference 2")
 [(3)](#ref-for-dfn-error-82 "Reference 3")
 [(4)](#ref-for-dfn-error-83 "Reference 4")
- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-error-84 "§ 11.8.3 Maximize Window")
 [(2)](#ref-for-dfn-error-85 "Reference 2")
- [§ 11.8.4 Minimize
 Window](#ref-for-dfn-error-86 "§ 11.8.4 Minimize Window")
 [(2)](#ref-for-dfn-error-87 "Reference 2")
- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-error-88 "§ 11.8.5 Fullscreen Window")
 [(2)](#ref-for-dfn-error-89 "Reference 2")
- [§ 12. Elements](#ref-for-dfn-error-90 "§ 12. Elements")
 [(2)](#ref-for-dfn-error-91 "Reference 2")
 [(3)](#ref-for-dfn-error-92 "Reference 3")
 [(4)](#ref-for-dfn-error-93 "Reference 4")
 [(5)](#ref-for-dfn-error-94 "Reference 5")
- [§ 12.2 Shadow Roots](#ref-for-dfn-error-95 "§ 12.2 Shadow Roots")
 [(2)](#ref-for-dfn-error-96 "Reference 2")
 [(3)](#ref-for-dfn-error-97 "Reference 3")
 [(4)](#ref-for-dfn-error-98 "Reference 4")
 [(5)](#ref-for-dfn-error-99 "Reference 5")
- [§ 12.3 Retrieval](#ref-for-dfn-error-100 "§ 12.3 Retrieval")
- [§ 12.3.1.1 CSS
 selectors](#ref-for-dfn-error-101 "§ 12.3.1.1 CSS selectors")
- [§ 12.3.1.2 Link text](#ref-for-dfn-error-102 "§ 12.3.1.2 Link text")
- [§ 12.3.1.3 Partial link
 text](#ref-for-dfn-error-103 "§ 12.3.1.3 Partial link text")
- [§ 12.3.1.5 XPath](#ref-for-dfn-error-104 "§ 12.3.1.5 XPath")
 [(2)](#ref-for-dfn-error-105 "Reference 2")
 [(3)](#ref-for-dfn-error-106 "Reference 3")
- [§ 12.3.2 Find
 Element](#ref-for-dfn-error-107 "§ 12.3.2 Find Element")
 [(2)](#ref-for-dfn-error-108 "Reference 2")
 [(3)](#ref-for-dfn-error-109 "Reference 3")
 [(4)](#ref-for-dfn-error-110 "Reference 4")
 [(5)](#ref-for-dfn-error-111 "Reference 5")
- [§ 12.3.3 Find
 Elements](#ref-for-dfn-error-112 "§ 12.3.3 Find Elements")
 [(2)](#ref-for-dfn-error-113 "Reference 2")
 [(3)](#ref-for-dfn-error-114 "Reference 3")
 [(4)](#ref-for-dfn-error-115 "Reference 4")
- [§ 12.3.4 Find Element From
 Element](#ref-for-dfn-error-116 "§ 12.3.4 Find Element From Element")
 [(2)](#ref-for-dfn-error-117 "Reference 2")
 [(3)](#ref-for-dfn-error-118 "Reference 3")
 [(4)](#ref-for-dfn-error-119 "Reference 4")
- [§ 12.3.5 Find Elements From
 Element](#ref-for-dfn-error-120 "§ 12.3.5 Find Elements From Element")
 [(2)](#ref-for-dfn-error-121 "Reference 2")
 [(3)](#ref-for-dfn-error-122 "Reference 3")
- [§ 12.3.6 Find Element From Shadow
 Root](#ref-for-dfn-error-123 "§ 12.3.6 Find Element From Shadow Root")
 [(2)](#ref-for-dfn-error-124 "Reference 2")
 [(3)](#ref-for-dfn-error-125 "Reference 3")
 [(4)](#ref-for-dfn-error-126 "Reference 4")
 [(5)](#ref-for-dfn-error-127 "Reference 5")
- [§ 12.3.7 Find Elements From Shadow
 Root](#ref-for-dfn-error-128 "§ 12.3.7 Find Elements From Shadow Root")
 [(2)](#ref-for-dfn-error-129 "Reference 2")
 [(3)](#ref-for-dfn-error-130 "Reference 3")
 [(4)](#ref-for-dfn-error-131 "Reference 4")
- [§ 12.3.8 Get Active
 Element](#ref-for-dfn-error-132 "§ 12.3.8 Get Active Element")
 [(2)](#ref-for-dfn-error-133 "Reference 2")
- [§ 12.3.9 Get Element Shadow
 Root](#ref-for-dfn-error-134 "§ 12.3.9 Get Element Shadow Root")
 [(2)](#ref-for-dfn-error-135 "Reference 2")
 [(3)](#ref-for-dfn-error-136 "Reference 3")
- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-error-137 "§ 12.4.1 Is Element Selected")
- [§ 12.4.2 Get Element
 Attribute](#ref-for-dfn-error-138 "§ 12.4.2 Get Element Attribute")
- [§ 12.4.3 Get Element
 Property](#ref-for-dfn-error-139 "§ 12.4.3 Get Element Property")
- [§ 12.4.4 Get Element CSS
 Value](#ref-for-dfn-error-140 "§ 12.4.4 Get Element CSS Value")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-error-141 "§ 12.4.5 Get Element Text")
- [§ 12.4.6 Get Element Tag
 Name](#ref-for-dfn-error-142 "§ 12.4.6 Get Element Tag Name")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-error-143 "§ 12.4.7 Get Element Rect")
- [§ 12.4.8 Is Element
 Enabled](#ref-for-dfn-error-144 "§ 12.4.8 Is Element Enabled")
- [§ 12.4.9 Get Computed
 Role](#ref-for-dfn-error-145 "§ 12.4.9 Get Computed Role")
- [§ 12.4.10 Get Computed
 Label](#ref-for-dfn-error-146 "§ 12.4.10 Get Computed Label")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-error-147 "§ 12.5.1 Element Click")
 [(2)](#ref-for-dfn-error-148 "Reference 2")
 [(3)](#ref-for-dfn-error-149 "Reference 3")
 [(4)](#ref-for-dfn-error-150 "Reference 4")
 [(5)](#ref-for-dfn-error-151 "Reference 5")
 [(6)](#ref-for-dfn-error-152 "Reference 6")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-error-153 "§ 12.5.2 Element Clear")
 [(2)](#ref-for-dfn-error-154 "Reference 2")
 [(3)](#ref-for-dfn-error-155 "Reference 3")
 [(4)](#ref-for-dfn-error-156 "Reference 4")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-error-157 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-error-158 "Reference 2")
 [(3)](#ref-for-dfn-error-159 "Reference 3")
 [(4)](#ref-for-dfn-error-160 "Reference 4")
 [(5)](#ref-for-dfn-error-161 "Reference 5")
 [(6)](#ref-for-dfn-error-162 "Reference 6")
 [(7)](#ref-for-dfn-error-163 "Reference 7")
 [(8)](#ref-for-dfn-error-164 "Reference 8")
 [(9)](#ref-for-dfn-error-165 "Reference 9")
 [(10)](#ref-for-dfn-error-166 "Reference 10")
 [(11)](#ref-for-dfn-error-167 "Reference 11")
 [(12)](#ref-for-dfn-error-168 "Reference 12")
- [§ 13.1 Get Page
 Source](#ref-for-dfn-error-169 "§ 13.1 Get Page Source")
- [§ 13.2 Executing
 Script](#ref-for-dfn-error-170 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-error-171 "Reference 2")
 [(3)](#ref-for-dfn-error-172 "Reference 3")
 [(4)](#ref-for-dfn-error-173 "Reference 4")
 [(5)](#ref-for-dfn-error-174 "Reference 5")
 [(6)](#ref-for-dfn-error-175 "Reference 6")
 [(7)](#ref-for-dfn-error-176 "Reference 7")
- [§ 13.2.1 Execute
 Script](#ref-for-dfn-error-177 "§ 13.2.1 Execute Script")
 [(2)](#ref-for-dfn-error-178 "Reference 2")
 [(3)](#ref-for-dfn-error-179 "Reference 3")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-error-180 "§ 13.2.2 Execute Async Script")
 [(2)](#ref-for-dfn-error-181 "Reference 2")
 [(3)](#ref-for-dfn-error-182 "Reference 3")
- [§ 14.1 Get All
 Cookies](#ref-for-dfn-error-183 "§ 14.1 Get All Cookies")
- [§ 14.2 Get Named
 Cookie](#ref-for-dfn-error-184 "§ 14.2 Get Named Cookie")
 [(2)](#ref-for-dfn-error-185 "Reference 2")
- [§ 14.3 Add Cookie](#ref-for-dfn-error-186 "§ 14.3 Add Cookie")
 [(2)](#ref-for-dfn-error-187 "Reference 2")
 [(3)](#ref-for-dfn-error-188 "Reference 3")
 [(4)](#ref-for-dfn-error-189 "Reference 4")
 [(5)](#ref-for-dfn-error-190 "Reference 5")
 [(6)](#ref-for-dfn-error-191 "Reference 6")
- [§ 14.4 Delete Cookie](#ref-for-dfn-error-192 "§ 14.4 Delete Cookie")
- [§ 14.5 Delete All
 Cookies](#ref-for-dfn-error-193 "§ 14.5 Delete All Cookies")
- [§ 15.2 Input sources](#ref-for-dfn-error-194 "§ 15.2 Input sources")
- [§ 15.3 Input state](#ref-for-dfn-error-195 "§ 15.3 Input state")
- [§ 15.5 Processing
 actions](#ref-for-dfn-error-196 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-error-197 "Reference 2")
 [(3)](#ref-for-dfn-error-198 "Reference 3")
 [(4)](#ref-for-dfn-error-199 "Reference 4")
 [(5)](#ref-for-dfn-error-200 "Reference 5")
 [(6)](#ref-for-dfn-error-201 "Reference 6")
 [(7)](#ref-for-dfn-error-202 "Reference 7")
 [(8)](#ref-for-dfn-error-203 "Reference 8")
 [(9)](#ref-for-dfn-error-204 "Reference 9")
 [(10)](#ref-for-dfn-error-205 "Reference 10")
 [(11)](#ref-for-dfn-error-206 "Reference 11")
 [(12)](#ref-for-dfn-error-207 "Reference 12")
 [(13)](#ref-for-dfn-error-208 "Reference 13")
 [(14)](#ref-for-dfn-error-209 "Reference 14")
 [(15)](#ref-for-dfn-error-210 "Reference 15")
 [(16)](#ref-for-dfn-error-211 "Reference 16")
 [(17)](#ref-for-dfn-error-212 "Reference 17")
 [(18)](#ref-for-dfn-error-213 "Reference 18")
 [(19)](#ref-for-dfn-error-214 "Reference 19")
 [(20)](#ref-for-dfn-error-215 "Reference 20")
 [(21)](#ref-for-dfn-error-216 "Reference 21")
 [(22)](#ref-for-dfn-error-217 "Reference 22")
 [(23)](#ref-for-dfn-error-218 "Reference 23")
 [(24)](#ref-for-dfn-error-219 "Reference 24")
 [(25)](#ref-for-dfn-error-220 "Reference 25")
 [(26)](#ref-for-dfn-error-221 "Reference 26")
 [(27)](#ref-for-dfn-error-222 "Reference 27")
 [(28)](#ref-for-dfn-error-223 "Reference 28")
 [(29)](#ref-for-dfn-error-224 "Reference 29")
 [(30)](#ref-for-dfn-error-225 "Reference 30")
 [(31)](#ref-for-dfn-error-226 "Reference 31")
 [(32)](#ref-for-dfn-error-227 "Reference 32")
 [(33)](#ref-for-dfn-error-228 "Reference 33")
 [(34)](#ref-for-dfn-error-229 "Reference 34")
 [(35)](#ref-for-dfn-error-230 "Reference 35")
 [(36)](#ref-for-dfn-error-231 "Reference 36")
 [(37)](#ref-for-dfn-error-232 "Reference 37")
 [(38)](#ref-for-dfn-error-233 "Reference 38")
 [(39)](#ref-for-dfn-error-234 "Reference 39")
 [(40)](#ref-for-dfn-error-235 "Reference 40")
 [(41)](#ref-for-dfn-error-236 "Reference 41")
 [(42)](#ref-for-dfn-error-237 "Reference 42")
 [(43)](#ref-for-dfn-error-238 "Reference 43")
 [(44)](#ref-for-dfn-error-239 "Reference 44")
 [(45)](#ref-for-dfn-error-240 "Reference 45")
 [(46)](#ref-for-dfn-error-241 "Reference 46")
 [(47)](#ref-for-dfn-error-242 "Reference 47")
 [(48)](#ref-for-dfn-error-243 "Reference 48")
 [(49)](#ref-for-dfn-error-244 "Reference 49")
 [(50)](#ref-for-dfn-error-245 "Reference 50")
- [§ 15.6 Dispatching
 actions](#ref-for-dfn-error-246 "§ 15.6 Dispatching actions")
- [§ 15.6.3 Pointer
 actions](#ref-for-dfn-error-247 "§ 15.6.3 Pointer actions")
 [(2)](#ref-for-dfn-error-248 "Reference 2")
- [§ 15.6.4 Wheel
 actions](#ref-for-dfn-error-249 "§ 15.6.4 Wheel actions")
 [(2)](#ref-for-dfn-error-250 "Reference 2")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-error-251 "§ 15.7 Perform Actions")
 [(2)](#ref-for-dfn-error-252 "Reference 2")
- [§ 15.8 Release
 Actions](#ref-for-dfn-error-253 "§ 15.8 Release Actions")
- [§ 16. User prompts](#ref-for-dfn-error-254 "§ 16. User prompts")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-error-255 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-error-256 "Reference 2")
 [(3)](#ref-for-dfn-error-257 "Reference 3")
 [(4)](#ref-for-dfn-error-258 "Reference 4")
 [(5)](#ref-for-dfn-error-259 "Reference 5")
 [(6)](#ref-for-dfn-error-260 "Reference 6")
- [§ 16.2 Dismiss Alert](#ref-for-dfn-error-261 "§ 16.2 Dismiss Alert")
 [(2)](#ref-for-dfn-error-262 "Reference 2")
- [§ 16.3 Accept Alert](#ref-for-dfn-error-263 "§ 16.3 Accept Alert")
 [(2)](#ref-for-dfn-error-264 "Reference 2")
- [§ 16.4 Get Alert
 Text](#ref-for-dfn-error-265 "§ 16.4 Get Alert Text")
 [(2)](#ref-for-dfn-error-266 "Reference 2")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-error-267 "§ 16.5 Send Alert Text")
 [(2)](#ref-for-dfn-error-268 "Reference 2")
 [(3)](#ref-for-dfn-error-269 "Reference 3")
 [(4)](#ref-for-dfn-error-270 "Reference 4")
 [(5)](#ref-for-dfn-error-271 "Reference 5")
- [§ 17. Screen capture](#ref-for-dfn-error-272 "§ 17. Screen capture")
 [(2)](#ref-for-dfn-error-273 "Reference 2")
 [(3)](#ref-for-dfn-error-274 "Reference 3")
- [§ 17.1 Take
 Screenshot](#ref-for-dfn-error-275 "§ 17.1 Take Screenshot")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-error-276 "§ 17.2 Take Element Screenshot")
- [§ 18. Print](#ref-for-dfn-error-277 "§ 18. Print")
 [(2)](#ref-for-dfn-error-278 "Reference 2")
 [(3)](#ref-for-dfn-error-279 "Reference 3")
 [(4)](#ref-for-dfn-error-280 "Reference 4")
 [(5)](#ref-for-dfn-error-281 "Reference 5")
 [(6)](#ref-for-dfn-error-282 "Reference 6")
- [§ 18.1 Print Page](#ref-for-dfn-error-283 "§ 18.1 Print Page")
 [(2)](#ref-for-dfn-error-284 "Reference 2")
 [(3)](#ref-for-dfn-error-285 "Reference 3")
 [(4)](#ref-for-dfn-error-286 "Reference 4")
 [(5)](#ref-for-dfn-error-287 "Reference 5")
 [(6)](#ref-for-dfn-error-288 "Reference 6")
 [(7)](#ref-for-dfn-error-289 "Reference 7")
 [(8)](#ref-for-dfn-error-290 "Reference 8")
- [§ C. Element
 displayedness](#ref-for-dfn-error-291 "§ C. Element displayedness")

[Permalink](#dfn-try)
[exported]

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-dfn-try-1 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-try-2 "Reference 2")
 [(3)](#ref-for-dfn-try-3 "Reference 3")
 [(4)](#ref-for-dfn-try-4 "Reference 4")
 [(5)](#ref-for-dfn-try-5 "Reference 5")
 [(6)](#ref-for-dfn-try-6 "Reference 6")
 [(7)](#ref-for-dfn-try-7 "Reference 7")
 [(8)](#ref-for-dfn-try-8 "Reference 8")
 [(9)](#ref-for-dfn-try-9 "Reference 9")
 [(10)](#ref-for-dfn-try-10 "Reference 10")
 [(11)](#ref-for-dfn-try-11 "Reference 11")
- [§ 8.2 New Session](#ref-for-dfn-try-12 "§ 8.2 New Session")
- [§ 8.3 Delete Session](#ref-for-dfn-try-13 "§ 8.3 Delete Session")
- [§ 9.2 Set Timeouts](#ref-for-dfn-try-14 "§ 9.2 Set Timeouts")
- [§ 10.1 Navigate To](#ref-for-dfn-try-15 "§ 10.1 Navigate To")
 [(2)](#ref-for-dfn-try-16 "Reference 2")
 [(3)](#ref-for-dfn-try-17 "Reference 3")
 [(4)](#ref-for-dfn-try-18 "Reference 4")
 [(5)](#ref-for-dfn-try-19 "Reference 5")
- [§ 10.2 Get Current URL](#ref-for-dfn-try-20 "§ 10.2 Get Current URL")
- [§ 10.3 Back](#ref-for-dfn-try-21 "§ 10.3 Back")
- [§ 10.4 Forward](#ref-for-dfn-try-22 "§ 10.4 Forward")
- [§ 10.5 Refresh](#ref-for-dfn-try-23 "§ 10.5 Refresh")
 [(2)](#ref-for-dfn-try-24 "Reference 2")
 [(3)](#ref-for-dfn-try-25 "Reference 3")
- [§ 10.6 Get Title](#ref-for-dfn-try-26 "§ 10.6 Get Title")
- [§ 11.2 Close Window](#ref-for-dfn-try-27 "§ 11.2 Close Window")
 [(2)](#ref-for-dfn-try-28 "Reference 2")
- [§ 11.5 New Window](#ref-for-dfn-try-29 "§ 11.5 New Window")
- [§ 11.6 Switch To Frame](#ref-for-dfn-try-30 "§ 11.6 Switch To Frame")
 [(2)](#ref-for-dfn-try-31 "Reference 2")
 [(3)](#ref-for-dfn-try-32 "Reference 3")
 [(4)](#ref-for-dfn-try-33 "Reference 4")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-dfn-try-34 "§ 11.7 Switch To Parent Frame")
- [§ 11.8.1 Get Window
 Rect](#ref-for-dfn-try-35 "§ 11.8.1 Get Window Rect")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-try-36 "§ 11.8.2 Set Window Rect")
- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-try-37 "§ 11.8.3 Maximize Window")
- [§ 11.8.4 Minimize
 Window](#ref-for-dfn-try-38 "§ 11.8.4 Minimize Window")
- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-try-39 "§ 11.8.5 Fullscreen Window")
- [§ 12. Elements](#ref-for-dfn-try-40 "§ 12. Elements")
 [(2)](#ref-for-dfn-try-41 "Reference 2")
- [§ 12.2 Shadow Roots](#ref-for-dfn-try-42 "§ 12.2 Shadow Roots")
 [(2)](#ref-for-dfn-try-43 "Reference 2")
- [§ 12.3 Retrieval](#ref-for-dfn-try-44 "§ 12.3 Retrieval")
- [§ 12.3.2 Find Element](#ref-for-dfn-try-45 "§ 12.3.2 Find Element")
 [(2)](#ref-for-dfn-try-46 "Reference 2")
- [§ 12.3.3 Find Elements](#ref-for-dfn-try-47 "§ 12.3.3 Find Elements")
 [(2)](#ref-for-dfn-try-48 "Reference 2")
- [§ 12.3.4 Find Element From
 Element](#ref-for-dfn-try-49 "§ 12.3.4 Find Element From Element")
 [(2)](#ref-for-dfn-try-50 "Reference 2")
 [(3)](#ref-for-dfn-try-51 "Reference 3")
- [§ 12.3.5 Find Elements From
 Element](#ref-for-dfn-try-52 "§ 12.3.5 Find Elements From Element")
 [(2)](#ref-for-dfn-try-53 "Reference 2")
 [(3)](#ref-for-dfn-try-54 "Reference 3")
- [§ 12.3.6 Find Element From Shadow
 Root](#ref-for-dfn-try-55 "§ 12.3.6 Find Element From Shadow Root")
 [(2)](#ref-for-dfn-try-56 "Reference 2")
- [§ 12.3.7 Find Elements From Shadow
 Root](#ref-for-dfn-try-57 "§ 12.3.7 Find Elements From Shadow Root")
 [(2)](#ref-for-dfn-try-58 "Reference 2")
- [§ 12.3.8 Get Active
 Element](#ref-for-dfn-try-59 "§ 12.3.8 Get Active Element")
- [§ 12.3.9 Get Element Shadow
 Root](#ref-for-dfn-try-60 "§ 12.3.9 Get Element Shadow Root")
- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-try-61 "§ 12.4.1 Is Element Selected")
 [(2)](#ref-for-dfn-try-62 "Reference 2")
- [§ 12.4.2 Get Element
 Attribute](#ref-for-dfn-try-63 "§ 12.4.2 Get Element Attribute")
 [(2)](#ref-for-dfn-try-64 "Reference 2")
- [§ 12.4.3 Get Element
 Property](#ref-for-dfn-try-65 "§ 12.4.3 Get Element Property")
 [(2)](#ref-for-dfn-try-66 "Reference 2")
- [§ 12.4.4 Get Element CSS
 Value](#ref-for-dfn-try-67 "§ 12.4.4 Get Element CSS Value")
 [(2)](#ref-for-dfn-try-68 "Reference 2")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-try-69 "§ 12.4.5 Get Element Text")
 [(2)](#ref-for-dfn-try-70 "Reference 2")
- [§ 12.4.6 Get Element Tag
 Name](#ref-for-dfn-try-71 "§ 12.4.6 Get Element Tag Name")
 [(2)](#ref-for-dfn-try-72 "Reference 2")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-try-73 "§ 12.4.7 Get Element Rect")
 [(2)](#ref-for-dfn-try-74 "Reference 2")
- [§ 12.4.8 Is Element
 Enabled](#ref-for-dfn-try-75 "§ 12.4.8 Is Element Enabled")
 [(2)](#ref-for-dfn-try-76 "Reference 2")
- [§ 12.4.9 Get Computed
 Role](#ref-for-dfn-try-77 "§ 12.4.9 Get Computed Role")
 [(2)](#ref-for-dfn-try-78 "Reference 2")
- [§ 12.4.10 Get Computed
 Label](#ref-for-dfn-try-79 "§ 12.4.10 Get Computed Label")
 [(2)](#ref-for-dfn-try-80 "Reference 2")
- [§ 12.5.1 Element Click](#ref-for-dfn-try-81 "§ 12.5.1 Element Click")
 [(2)](#ref-for-dfn-try-82 "Reference 2")
 [(3)](#ref-for-dfn-try-83 "Reference 3")
 [(4)](#ref-for-dfn-try-84 "Reference 4")
- [§ 12.5.2 Element Clear](#ref-for-dfn-try-85 "§ 12.5.2 Element Clear")
 [(2)](#ref-for-dfn-try-86 "Reference 2")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-try-87 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-try-88 "Reference 2")
 [(3)](#ref-for-dfn-try-89 "Reference 3")
 [(4)](#ref-for-dfn-try-90 "Reference 4")
- [§ 13.1 Get Page Source](#ref-for-dfn-try-91 "§ 13.1 Get Page Source")
- [§ 13.2.1 Execute
 Script](#ref-for-dfn-try-92 "§ 13.2.1 Execute Script")
 [(2)](#ref-for-dfn-try-93 "Reference 2")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-try-94 "§ 13.2.2 Execute Async Script")
 [(2)](#ref-for-dfn-try-95 "Reference 2")
- [§ 14.1 Get All Cookies](#ref-for-dfn-try-96 "§ 14.1 Get All Cookies")
- [§ 14.2 Get Named
 Cookie](#ref-for-dfn-try-97 "§ 14.2 Get Named Cookie")
- [§ 14.3 Add Cookie](#ref-for-dfn-try-98 "§ 14.3 Add Cookie")
- [§ 14.4 Delete Cookie](#ref-for-dfn-try-99 "§ 14.4 Delete Cookie")
- [§ 14.5 Delete All
 Cookies](#ref-for-dfn-try-100 "§ 14.5 Delete All Cookies")
- [§ 15.1 Actions
 Options](#ref-for-dfn-try-101 "§ 15.1 Actions Options")
- [§ 15.3 Input state](#ref-for-dfn-try-102 "§ 15.3 Input state")
- [§ 15.5 Processing
 actions](#ref-for-dfn-try-103 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-try-104 "Reference 2")
 [(3)](#ref-for-dfn-try-105 "Reference 3")
 [(4)](#ref-for-dfn-try-106 "Reference 4")
 [(5)](#ref-for-dfn-try-107 "Reference 5")
 [(6)](#ref-for-dfn-try-108 "Reference 6")
 [(7)](#ref-for-dfn-try-109 "Reference 7")
 [(8)](#ref-for-dfn-try-110 "Reference 8")
 [(9)](#ref-for-dfn-try-111 "Reference 9")
 [(10)](#ref-for-dfn-try-112 "Reference 10")
 [(11)](#ref-for-dfn-try-113 "Reference 11")
- [§ 15.6 Dispatching
 actions](#ref-for-dfn-try-114 "§ 15.6 Dispatching actions")
 [(2)](#ref-for-dfn-try-115 "Reference 2")
- [§ 15.6.3 Pointer
 actions](#ref-for-dfn-try-116 "§ 15.6.3 Pointer actions")
- [§ 15.6.4 Wheel
 actions](#ref-for-dfn-try-117 "§ 15.6.4 Wheel actions")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-try-118 "§ 15.7 Perform Actions")
 [(2)](#ref-for-dfn-try-119 "Reference 2")
- [§ 15.8 Release
 Actions](#ref-for-dfn-try-120 "§ 15.8 Release Actions")
 [(2)](#ref-for-dfn-try-121 "Reference 2")
- [§ 17.1 Take
 Screenshot](#ref-for-dfn-try-122 "§ 17.1 Take Screenshot")
 [(2)](#ref-for-dfn-try-123 "Reference 2")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-try-124 "§ 17.2 Take Element Screenshot")
 [(2)](#ref-for-dfn-try-125 "Reference 2")
 [(3)](#ref-for-dfn-try-126 "Reference 3")
 [(4)](#ref-for-dfn-try-127 "Reference 4")
- [§ 18. Print](#ref-for-dfn-try-128 "§ 18. Print")
 [(2)](#ref-for-dfn-try-129 "Reference 2")
 [(3)](#ref-for-dfn-try-130 "Reference 3")
- [§ 18.1 Print Page](#ref-for-dfn-try-131 "§ 18.1 Print Page")
 [(2)](#ref-for-dfn-try-132 "Reference 2")
 [(3)](#ref-for-dfn-try-133 "Reference 3")

[Permalink](#dfn-getting-properties)

**Referenced in:**

- [§ 7.1 Proxy](#ref-for-dfn-getting-properties-1 "§ 7.1 Proxy")
 [(2)](#ref-for-dfn-getting-properties-2 "Reference 2")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-getting-properties-3 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-getting-properties-4 "Reference 2")
 [(3)](#ref-for-dfn-getting-properties-5 "Reference 3")
 [(4)](#ref-for-dfn-getting-properties-6 "Reference 4")
 [(5)](#ref-for-dfn-getting-properties-7 "Reference 5")
 [(6)](#ref-for-dfn-getting-properties-8 "Reference 6")
 [(7)](#ref-for-dfn-getting-properties-9 "Reference 7")
- [§ 8.1 Global
 State](#ref-for-dfn-getting-properties-10 "§ 8.1 Global State")
- [§ 10.1 Navigate
 To](#ref-for-dfn-getting-properties-11 "§ 10.1 Navigate To")
- [§ 11. Contexts](#ref-for-dfn-getting-properties-12 "§ 11. Contexts")
 [(2)](#ref-for-dfn-getting-properties-13 "Reference 2")
- [§ 11.3 Switch To
 Window](#ref-for-dfn-getting-properties-14 "§ 11.3 Switch To Window")
- [§ 11.5 New
 Window](#ref-for-dfn-getting-properties-15 "§ 11.5 New Window")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-getting-properties-16 "§ 11.6 Switch To Frame")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-getting-properties-17 "§ 11.8.2 Set Window Rect")
 [(2)](#ref-for-dfn-getting-properties-18 "Reference 2")
 [(3)](#ref-for-dfn-getting-properties-19 "Reference 3")
 [(4)](#ref-for-dfn-getting-properties-20 "Reference 4")
- [§ 12. Elements](#ref-for-dfn-getting-properties-21 "§ 12. Elements")
- [§ 12.2 Shadow
 Roots](#ref-for-dfn-getting-properties-22 "§ 12.2 Shadow Roots")
- [§ 12.3.1.5
 XPath](#ref-for-dfn-getting-properties-23 "§ 12.3.1.5 XPath")
- [§ 12.3.2 Find
 Element](#ref-for-dfn-getting-properties-24 "§ 12.3.2 Find Element")
 [(2)](#ref-for-dfn-getting-properties-25 "Reference 2")
- [§ 12.3.3 Find
 Elements](#ref-for-dfn-getting-properties-26 "§ 12.3.3 Find Elements")
 [(2)](#ref-for-dfn-getting-properties-27 "Reference 2")
- [§ 12.3.4 Find Element From
 Element](#ref-for-dfn-getting-properties-28 "§ 12.3.4 Find Element From Element")
 [(2)](#ref-for-dfn-getting-properties-29 "Reference 2")
- [§ 12.3.5 Find Elements From
 Element](#ref-for-dfn-getting-properties-30 "§ 12.3.5 Find Elements From Element")
 [(2)](#ref-for-dfn-getting-properties-31 "Reference 2")
- [§ 12.3.6 Find Element From Shadow
 Root](#ref-for-dfn-getting-properties-32 "§ 12.3.6 Find Element From Shadow Root")
 [(2)](#ref-for-dfn-getting-properties-33 "Reference 2")
- [§ 12.3.7 Find Elements From Shadow
 Root](#ref-for-dfn-getting-properties-34 "§ 12.3.7 Find Elements From Shadow Root")
 [(2)](#ref-for-dfn-getting-properties-35 "Reference 2")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-getting-properties-36 "§ 12.5.3 Element Send Keys")
- [§ 13.2 Executing
 Script](#ref-for-dfn-getting-properties-37 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-getting-properties-38 "Reference 2")
 [(3)](#ref-for-dfn-getting-properties-39 "Reference 3")
 [(4)](#ref-for-dfn-getting-properties-40 "Reference 4")
- [§ 14.3 Add
 Cookie](#ref-for-dfn-getting-properties-41 "§ 14.3 Add Cookie")
- [§ 15.5 Processing
 actions](#ref-for-dfn-getting-properties-42 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-getting-properties-43 "Reference 2")
 [(3)](#ref-for-dfn-getting-properties-44 "Reference 3")
 [(4)](#ref-for-dfn-getting-properties-45 "Reference 4")
 [(5)](#ref-for-dfn-getting-properties-46 "Reference 5")
 [(6)](#ref-for-dfn-getting-properties-47 "Reference 6")
 [(7)](#ref-for-dfn-getting-properties-48 "Reference 7")
 [(8)](#ref-for-dfn-getting-properties-49 "Reference 8")
 [(9)](#ref-for-dfn-getting-properties-50 "Reference 9")
 [(10)](#ref-for-dfn-getting-properties-51 "Reference 10")
 [(11)](#ref-for-dfn-getting-properties-52 "Reference 11")
 [(12)](#ref-for-dfn-getting-properties-53 "Reference 12")
 [(13)](#ref-for-dfn-getting-properties-54 "Reference 13")
 [(14)](#ref-for-dfn-getting-properties-55 "Reference 14")
 [(15)](#ref-for-dfn-getting-properties-56 "Reference 15")
 [(16)](#ref-for-dfn-getting-properties-57 "Reference 16")
 [(17)](#ref-for-dfn-getting-properties-58 "Reference 17")
 [(18)](#ref-for-dfn-getting-properties-59 "Reference 18")
 [(19)](#ref-for-dfn-getting-properties-60 "Reference 19")
 [(20)](#ref-for-dfn-getting-properties-61 "Reference 20")
 [(21)](#ref-for-dfn-getting-properties-62 "Reference 21")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-getting-properties-63 "§ 16.5 Send Alert Text")

[Permalink](#dfn-getting-the-property-with-default)

**Referenced in:**

- [§ 18.1 Print
 Page](#ref-for-dfn-getting-the-property-with-default-1 "§ 18.1 Print Page")
 [(2)](#ref-for-dfn-getting-the-property-with-default-2 "Reference 2")
 [(3)](#ref-for-dfn-getting-the-property-with-default-3 "Reference 3")
 [(4)](#ref-for-dfn-getting-the-property-with-default-4 "Reference 4")
 [(5)](#ref-for-dfn-getting-the-property-with-default-5 "Reference 5")
 [(6)](#ref-for-dfn-getting-the-property-with-default-6 "Reference 6")
 [(7)](#ref-for-dfn-getting-the-property-with-default-7 "Reference 7")
 [(8)](#ref-for-dfn-getting-the-property-with-default-8 "Reference 8")
 [(9)](#ref-for-dfn-getting-the-property-with-default-9 "Reference 9")
 [(10)](#ref-for-dfn-getting-the-property-with-default-10 "Reference 10")
 [(11)](#ref-for-dfn-getting-the-property-with-default-11 "Reference 11")
 [(12)](#ref-for-dfn-getting-the-property-with-default-12 "Reference 12")
 [(13)](#ref-for-dfn-getting-the-property-with-default-13 "Reference 13")

[Permalink](#dfn-set-a-property)

**Referenced in:**

- [§ 7.1 Proxy](#ref-for-dfn-set-a-property-1 "§ 7.1 Proxy")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-set-a-property-2 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-set-a-property-3 "Reference 2")
 [(3)](#ref-for-dfn-set-a-property-4 "Reference 3")
 [(4)](#ref-for-dfn-set-a-property-5 "Reference 4")
- [§ 8.1 Global
 State](#ref-for-dfn-set-a-property-6 "§ 8.1 Global State")
 [(2)](#ref-for-dfn-set-a-property-7 "Reference 2")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-set-a-property-8 "§ 12.5.1 Element Click")
 [(2)](#ref-for-dfn-set-a-property-9 "Reference 2")
 [(3)](#ref-for-dfn-set-a-property-10 "Reference 3")
 [(4)](#ref-for-dfn-set-a-property-11 "Reference 4")
 [(5)](#ref-for-dfn-set-a-property-12 "Reference 5")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-set-a-property-13 "§ 12.5.3 Element Send Keys")
- [§ 13.2 Executing
 Script](#ref-for-dfn-set-a-property-14 "§ 13.2 Executing Script")

[Permalink](#dfn-json-serialization)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-json-serialization-1 "§ 6.3 Processing model")

[Permalink](#dfn-parsing-as-json)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-parsing-as-json-1 "§ 6.3 Processing model")

[Permalink](#dfn-commands)

**Referenced in:**

- [§ 6. Protocol](#ref-for-dfn-commands-1 "§ 6. Protocol")
- [§ 6.2 Commands](#ref-for-dfn-commands-2 "§ 6.2 Commands")
 [(2)](#ref-for-dfn-commands-3 "Reference 2")
 [(3)](#ref-for-dfn-commands-4 "Reference 3")
- [§ 6.3 Processing
 model](#ref-for-dfn-commands-5 "§ 6.3 Processing model")
- [§ 6.4 Routing
 requests](#ref-for-dfn-commands-6 "§ 6.4 Routing requests")
 [(2)](#ref-for-dfn-commands-7 "Reference 2")
 [(3)](#ref-for-dfn-commands-8 "Reference 3")
- [§ 6.5 Endpoints](#ref-for-dfn-commands-9 "§ 6.5 Endpoints")
- [§ 6.6 Errors](#ref-for-dfn-commands-10 "§ 6.6 Errors")
 [(2)](#ref-for-dfn-commands-11 "Reference 2")
 [(3)](#ref-for-dfn-commands-12 "Reference 3")
 [(4)](#ref-for-dfn-commands-13 "Reference 4")
 [(5)](#ref-for-dfn-commands-14 "Reference 5")
 [(6)](#ref-for-dfn-commands-15 "Reference 6")
 [(7)](#ref-for-dfn-commands-16 "Reference 7")
 [(8)](#ref-for-dfn-commands-17 "Reference 8")
 [(9)](#ref-for-dfn-commands-18 "Reference 9")
 [(10)](#ref-for-dfn-commands-19 "Reference 10")
 [(11)](#ref-for-dfn-commands-20 "Reference 11")
 [(12)](#ref-for-dfn-commands-21 "Reference 12")
 [(13)](#ref-for-dfn-commands-22 "Reference 13")
- [§ 6.7 Extensions](#ref-for-dfn-commands-23 "§ 6.7 Extensions")
 [(2)](#ref-for-dfn-commands-24 "Reference 2")
- [§ 7. Capabilities](#ref-for-dfn-commands-25 "§ 7. Capabilities")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-commands-26 "§ 7.2 Processing capabilities")
- [§ 8. Sessions](#ref-for-dfn-commands-27 "§ 8. Sessions")
 [(2)](#ref-for-dfn-commands-28 "Reference 2")
- [§ 8.2 New Session](#ref-for-dfn-commands-29 "§ 8.2 New Session")
- [§ 10. Navigation](#ref-for-dfn-commands-30 "§ 10. Navigation")
 [(2)](#ref-for-dfn-commands-31 "Reference 2")
- [§ 11. Contexts](#ref-for-dfn-commands-32 "§ 11. Contexts")
- [§ 11.2 Close Window](#ref-for-dfn-commands-33 "§ 11.2 Close Window")
- [§ 11.3 Switch To
 Window](#ref-for-dfn-commands-34 "§ 11.3 Switch To Window")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-commands-35 "§ 11.6 Switch To Frame")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-dfn-commands-36 "§ 11.7 Switch To Parent Frame")
 [(2)](#ref-for-dfn-commands-37 "Reference 2")
- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-commands-38 "§ 11.8 Resizing and positioning windows")
 [(2)](#ref-for-dfn-commands-39 "Reference 2")
 [(3)](#ref-for-dfn-commands-40 "Reference 3")
- [§ 11.8.1 Get Window
 Rect](#ref-for-dfn-commands-41 "§ 11.8.1 Get Window Rect")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-commands-42 "§ 11.8.2 Set Window Rect")
 [(2)](#ref-for-dfn-commands-43 "Reference 2")
- [§ 12.3 Retrieval](#ref-for-dfn-commands-44 "§ 12.3 Retrieval")
- [§ 12.3.2 Find
 Element](#ref-for-dfn-commands-45 "§ 12.3.2 Find Element")
 [(2)](#ref-for-dfn-commands-46 "Reference 2")
- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-commands-47 "§ 12.4.1 Is Element Selected")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-commands-48 "§ 12.4.5 Get Element Text")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-commands-49 "§ 12.4.7 Get Element Rect")
- [§ 12.5 Interaction](#ref-for-dfn-commands-50 "§ 12.5 Interaction")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-commands-51 "§ 12.5.1 Element Click")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-commands-52 "§ 12.5.3 Element Send Keys")
- [§ 13.1 Get Page
 Source](#ref-for-dfn-commands-53 "§ 13.1 Get Page Source")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-commands-54 "§ 13.2.2 Execute Async Script")
- [§ 15.8 Release
 Actions](#ref-for-dfn-commands-55 "§ 15.8 Release Actions")
- [§ 16. User prompts](#ref-for-dfn-commands-56 "§ 16. User prompts")
 [(2)](#ref-for-dfn-commands-57 "Reference 2")
- [§ 16.2 Dismiss
 Alert](#ref-for-dfn-commands-58 "§ 16.2 Dismiss Alert")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-commands-59 "§ 16.5 Send Alert Text")
- [§ 17. Screen
 capture](#ref-for-dfn-commands-60 "§ 17. Screen capture")
 [(2)](#ref-for-dfn-commands-61 "Reference 2")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-commands-62 "§ 17.2 Take Element Screenshot")

[Permalink](#dfn-remote-end-steps)
[exported]

**Referenced in:**

- [§ 5. Nodes](#ref-for-dfn-remote-end-steps-1 "§ 5. Nodes")
- [§ 6.3 Processing
 model](#ref-for-dfn-remote-end-steps-2 "§ 6.3 Processing model")
- [§ 6.4 Routing
 requests](#ref-for-dfn-remote-end-steps-3 "§ 6.4 Routing requests")
- [§ 6.7 Extensions](#ref-for-dfn-remote-end-steps-4 "§ 6.7 Extensions")
 [(2)](#ref-for-dfn-remote-end-steps-5 "Reference 2")
- [§ 8.2 New
 Session](#ref-for-dfn-remote-end-steps-6 "§ 8.2 New Session")
- [§ 8.3 Delete
 Session](#ref-for-dfn-remote-end-steps-7 "§ 8.3 Delete Session")
- [§ 8.4 Status](#ref-for-dfn-remote-end-steps-8 "§ 8.4 Status")
- [§ 9.1 Get
 Timeouts](#ref-for-dfn-remote-end-steps-9 "§ 9.1 Get Timeouts")
- [§ 9.2 Set
 Timeouts](#ref-for-dfn-remote-end-steps-10 "§ 9.2 Set Timeouts")
- [§ 10.1 Navigate
 To](#ref-for-dfn-remote-end-steps-11 "§ 10.1 Navigate To")
- [§ 10.2 Get Current
 URL](#ref-for-dfn-remote-end-steps-12 "§ 10.2 Get Current URL")
- [§ 10.3 Back](#ref-for-dfn-remote-end-steps-13 "§ 10.3 Back")
- [§ 10.4 Forward](#ref-for-dfn-remote-end-steps-14 "§ 10.4 Forward")
- [§ 10.5 Refresh](#ref-for-dfn-remote-end-steps-15 "§ 10.5 Refresh")
- [§ 10.6 Get
 Title](#ref-for-dfn-remote-end-steps-16 "§ 10.6 Get Title")
- [§ 11.1 Get Window
 Handle](#ref-for-dfn-remote-end-steps-17 "§ 11.1 Get Window Handle")
- [§ 11.2 Close
 Window](#ref-for-dfn-remote-end-steps-18 "§ 11.2 Close Window")
 [(2)](#ref-for-dfn-remote-end-steps-19 "Reference 2")
- [§ 11.3 Switch To
 Window](#ref-for-dfn-remote-end-steps-20 "§ 11.3 Switch To Window")
- [§ 11.4 Get Window
 Handles](#ref-for-dfn-remote-end-steps-21 "§ 11.4 Get Window Handles")
- [§ 11.5 New
 Window](#ref-for-dfn-remote-end-steps-22 "§ 11.5 New Window")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-remote-end-steps-23 "§ 11.6 Switch To Frame")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-dfn-remote-end-steps-24 "§ 11.7 Switch To Parent Frame")
- [§ 11.8.1 Get Window
 Rect](#ref-for-dfn-remote-end-steps-25 "§ 11.8.1 Get Window Rect")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-remote-end-steps-26 "§ 11.8.2 Set Window Rect")
- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-remote-end-steps-27 "§ 11.8.3 Maximize Window")
- [§ 11.8.4 Minimize
 Window](#ref-for-dfn-remote-end-steps-28 "§ 11.8.4 Minimize Window")
- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-remote-end-steps-29 "§ 11.8.5 Fullscreen Window")
- [§ 12.3.2 Find
 Element](#ref-for-dfn-remote-end-steps-30 "§ 12.3.2 Find Element")
- [§ 12.3.3 Find
 Elements](#ref-for-dfn-remote-end-steps-31 "§ 12.3.3 Find Elements")
- [§ 12.3.4 Find Element From
 Element](#ref-for-dfn-remote-end-steps-32 "§ 12.3.4 Find Element From Element")
- [§ 12.3.5 Find Elements From
 Element](#ref-for-dfn-remote-end-steps-33 "§ 12.3.5 Find Elements From Element")
- [§ 12.3.6 Find Element From Shadow
 Root](#ref-for-dfn-remote-end-steps-34 "§ 12.3.6 Find Element From Shadow Root")
- [§ 12.3.7 Find Elements From Shadow
 Root](#ref-for-dfn-remote-end-steps-35 "§ 12.3.7 Find Elements From Shadow Root")
- [§ 12.3.8 Get Active
 Element](#ref-for-dfn-remote-end-steps-36 "§ 12.3.8 Get Active Element")
- [§ 12.3.9 Get Element Shadow
 Root](#ref-for-dfn-remote-end-steps-37 "§ 12.3.9 Get Element Shadow Root")
- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-remote-end-steps-38 "§ 12.4.1 Is Element Selected")
- [§ 12.4.2 Get Element
 Attribute](#ref-for-dfn-remote-end-steps-39 "§ 12.4.2 Get Element Attribute")
- [§ 12.4.3 Get Element
 Property](#ref-for-dfn-remote-end-steps-40 "§ 12.4.3 Get Element Property")
- [§ 12.4.4 Get Element CSS
 Value](#ref-for-dfn-remote-end-steps-41 "§ 12.4.4 Get Element CSS Value")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-remote-end-steps-42 "§ 12.4.5 Get Element Text")
- [§ 12.4.6 Get Element Tag
 Name](#ref-for-dfn-remote-end-steps-43 "§ 12.4.6 Get Element Tag Name")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-remote-end-steps-44 "§ 12.4.7 Get Element Rect")
- [§ 12.4.8 Is Element
 Enabled](#ref-for-dfn-remote-end-steps-45 "§ 12.4.8 Is Element Enabled")
- [§ 12.4.9 Get Computed
 Role](#ref-for-dfn-remote-end-steps-46 "§ 12.4.9 Get Computed Role")
- [§ 12.4.10 Get Computed
 Label](#ref-for-dfn-remote-end-steps-47 "§ 12.4.10 Get Computed Label")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-remote-end-steps-48 "§ 12.5.1 Element Click")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-remote-end-steps-49 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-remote-end-steps-50 "§ 12.5.3 Element Send Keys")
- [§ 13.1 Get Page
 Source](#ref-for-dfn-remote-end-steps-51 "§ 13.1 Get Page Source")
- [§ 13.2.1 Execute
 Script](#ref-for-dfn-remote-end-steps-52 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-remote-end-steps-53 "§ 13.2.2 Execute Async Script")
- [§ 14.1 Get All
 Cookies](#ref-for-dfn-remote-end-steps-54 "§ 14.1 Get All Cookies")
- [§ 14.2 Get Named
 Cookie](#ref-for-dfn-remote-end-steps-55 "§ 14.2 Get Named Cookie")
- [§ 14.3 Add
 Cookie](#ref-for-dfn-remote-end-steps-56 "§ 14.3 Add Cookie")
- [§ 14.4 Delete
 Cookie](#ref-for-dfn-remote-end-steps-57 "§ 14.4 Delete Cookie")
- [§ 14.5 Delete All
 Cookies](#ref-for-dfn-remote-end-steps-58 "§ 14.5 Delete All Cookies")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-remote-end-steps-59 "§ 15.7 Perform Actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-remote-end-steps-60 "§ 15.8 Release Actions")
- [§ 16.2 Dismiss
 Alert](#ref-for-dfn-remote-end-steps-61 "§ 16.2 Dismiss Alert")
- [§ 16.3 Accept
 Alert](#ref-for-dfn-remote-end-steps-62 "§ 16.3 Accept Alert")
- [§ 16.4 Get Alert
 Text](#ref-for-dfn-remote-end-steps-63 "§ 16.4 Get Alert Text")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-remote-end-steps-64 "§ 16.5 Send Alert Text")
- [§ 17.1 Take
 Screenshot](#ref-for-dfn-remote-end-steps-65 "§ 17.1 Take Screenshot")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-remote-end-steps-66 "§ 17.2 Take Element Screenshot")
- [§ 18.1 Print
 Page](#ref-for-dfn-remote-end-steps-67 "§ 18.1 Print Page")

[Permalink](#dfn-connection)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-connection-1 "§ 6.3 Processing model")
 [(2)](#ref-for-dfn-connection-2 "Reference 2")
 [(3)](#ref-for-dfn-connection-3 "Reference 3")
 [(4)](#ref-for-dfn-connection-4 "Reference 4")
 [(5)](#ref-for-dfn-connection-5 "Reference 5")
 [(6)](#ref-for-dfn-connection-6 "Reference 6")
- [§ 8.1 Global State](#ref-for-dfn-connection-7 "§ 8.1 Global State")

[Permalink](#dfn-write-bytes)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-write-bytes-1 "§ 6.3 Processing model")

[Permalink](#dfn-read-bytes)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-read-bytes-1 "§ 6.3 Processing model")

[Permalink](#dfn-send-an-error)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-send-an-error-1 "§ 6.3 Processing model")
 [(2)](#ref-for-dfn-send-an-error-2 "Reference 2")
 [(3)](#ref-for-dfn-send-an-error-3 "Reference 3")
 [(4)](#ref-for-dfn-send-an-error-4 "Reference 4")
 [(5)](#ref-for-dfn-send-an-error-5 "Reference 5")
 [(6)](#ref-for-dfn-send-an-error-6 "Reference 6")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-send-an-error-7 "§ 16.1 User Prompt Handler")

[Permalink](#dfn-send-a-response)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-send-a-response-1 "§ 6.3 Processing model")
 [(2)](#ref-for-dfn-send-a-response-2 "Reference 2")

[Permalink](#dfn-routing-requests)

**Referenced in:**

- [§ 6.7 Extensions](#ref-for-dfn-routing-requests-1 "§ 6.7 Extensions")

[Permalink](#dfn-url-prefix)

**Referenced in:**

- [§ 6.4 Routing
 requests](#ref-for-dfn-url-prefix-1 "§ 6.4 Routing requests")
 [(2)](#ref-for-dfn-url-prefix-2 "Reference 2")
 [(3)](#ref-for-dfn-url-prefix-3 "Reference 3")
- [§ 8.2 New Session](#ref-for-dfn-url-prefix-4 "§ 8.2 New Session")

[Permalink](#dfn-match-a-request)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-match-a-request-1 "§ 6.3 Processing model")

[Permalink](#dfn-endpoints)

**Referenced in:**

- [§ 6. Protocol](#ref-for-dfn-endpoints-1 "§ 6. Protocol")
- [§ 6.4 Routing
 requests](#ref-for-dfn-endpoints-2 "§ 6.4 Routing requests")
- [§ 6.7 Extensions](#ref-for-dfn-endpoints-3 "§ 6.7 Extensions")

[Permalink](#dfn-error-code)
[exported]

**Referenced in:**

- [§ 6.1 Algorithms](#ref-for-dfn-error-code-1 "§ 6.1 Algorithms")
- [§ 6.3 Processing
 model](#ref-for-dfn-error-code-2 "§ 6.3 Processing model")
 [(2)](#ref-for-dfn-error-code-3 "Reference 2")
 [(3)](#ref-for-dfn-error-code-4 "Reference 3")
 [(4)](#ref-for-dfn-error-code-5 "Reference 4")
 [(5)](#ref-for-dfn-error-code-6 "Reference 5")
 [(6)](#ref-for-dfn-error-code-7 "Reference 6")
 [(7)](#ref-for-dfn-error-code-8 "Reference 7")
 [(8)](#ref-for-dfn-error-code-9 "Reference 8")
 [(9)](#ref-for-dfn-error-code-10 "Reference 9")
 [(10)](#ref-for-dfn-error-code-11 "Reference 10")
- [§ 6.4 Routing
 requests](#ref-for-dfn-error-code-12 "§ 6.4 Routing requests")
 [(2)](#ref-for-dfn-error-code-13 "Reference 2")
- [§ 6.6 Errors](#ref-for-dfn-error-code-14 "§ 6.6 Errors")
 [(2)](#ref-for-dfn-error-code-15 "Reference 2")
 [(3)](#ref-for-dfn-error-code-16 "Reference 3")
- [§ 7.1 Proxy](#ref-for-dfn-error-code-17 "§ 7.1 Proxy")
 [(2)](#ref-for-dfn-error-code-18 "Reference 2")
 [(3)](#ref-for-dfn-error-code-19 "Reference 3")
 [(4)](#ref-for-dfn-error-code-20 "Reference 4")
 [(5)](#ref-for-dfn-error-code-21 "Reference 5")
 [(6)](#ref-for-dfn-error-code-22 "Reference 6")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-error-code-23 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-error-code-24 "Reference 2")
 [(3)](#ref-for-dfn-error-code-25 "Reference 3")
 [(4)](#ref-for-dfn-error-code-26 "Reference 4")
 [(5)](#ref-for-dfn-error-code-27 "Reference 5")
 [(6)](#ref-for-dfn-error-code-28 "Reference 6")
 [(7)](#ref-for-dfn-error-code-29 "Reference 7")
 [(8)](#ref-for-dfn-error-code-30 "Reference 8")
- [§ 8.1 Global State](#ref-for-dfn-error-code-31 "§ 8.1 Global State")
- [§ 8.2 New Session](#ref-for-dfn-error-code-32 "§ 8.2 New Session")
 [(2)](#ref-for-dfn-error-code-33 "Reference 2")
 [(3)](#ref-for-dfn-error-code-34 "Reference 3")
- [§ 9. Timeouts](#ref-for-dfn-error-code-35 "§ 9. Timeouts")
- [§ 10. Navigation](#ref-for-dfn-error-code-36 "§ 10. Navigation")
 [(2)](#ref-for-dfn-error-code-37 "Reference 2")
 [(3)](#ref-for-dfn-error-code-38 "Reference 3")
 [(4)](#ref-for-dfn-error-code-39 "Reference 4")
 [(5)](#ref-for-dfn-error-code-40 "Reference 5")
- [§ 10.1 Navigate To](#ref-for-dfn-error-code-41 "§ 10.1 Navigate To")
 [(2)](#ref-for-dfn-error-code-42 "Reference 2")
 [(3)](#ref-for-dfn-error-code-43 "Reference 3")
- [§ 10.2 Get Current
 URL](#ref-for-dfn-error-code-44 "§ 10.2 Get Current URL")
- [§ 10.3 Back](#ref-for-dfn-error-code-45 "§ 10.3 Back")
 [(2)](#ref-for-dfn-error-code-46 "Reference 2")
- [§ 10.4 Forward](#ref-for-dfn-error-code-47 "§ 10.4 Forward")
 [(2)](#ref-for-dfn-error-code-48 "Reference 2")
- [§ 10.5 Refresh](#ref-for-dfn-error-code-49 "§ 10.5 Refresh")
- [§ 10.6 Get Title](#ref-for-dfn-error-code-50 "§ 10.6 Get Title")
- [§ 11. Contexts](#ref-for-dfn-error-code-51 "§ 11. Contexts")
 [(2)](#ref-for-dfn-error-code-52 "Reference 2")
 [(3)](#ref-for-dfn-error-code-53 "Reference 3")
 [(4)](#ref-for-dfn-error-code-54 "Reference 4")
 [(5)](#ref-for-dfn-error-code-55 "Reference 5")
 [(6)](#ref-for-dfn-error-code-56 "Reference 6")
- [§ 11.1 Get Window
 Handle](#ref-for-dfn-error-code-57 "§ 11.1 Get Window Handle")
- [§ 11.2 Close
 Window](#ref-for-dfn-error-code-58 "§ 11.2 Close Window")
- [§ 11.3 Switch To
 Window](#ref-for-dfn-error-code-59 "§ 11.3 Switch To Window")
 [(2)](#ref-for-dfn-error-code-60 "Reference 2")
 [(3)](#ref-for-dfn-error-code-61 "Reference 3")
- [§ 11.5 New Window](#ref-for-dfn-error-code-62 "§ 11.5 New Window")
 [(2)](#ref-for-dfn-error-code-63 "Reference 2")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-error-code-64 "§ 11.6 Switch To Frame")
 [(2)](#ref-for-dfn-error-code-65 "Reference 2")
 [(3)](#ref-for-dfn-error-code-66 "Reference 3")
 [(4)](#ref-for-dfn-error-code-67 "Reference 4")
 [(5)](#ref-for-dfn-error-code-68 "Reference 5")
 [(6)](#ref-for-dfn-error-code-69 "Reference 6")
 [(7)](#ref-for-dfn-error-code-70 "Reference 7")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-dfn-error-code-71 "§ 11.7 Switch To Parent Frame")
 [(2)](#ref-for-dfn-error-code-72 "Reference 2")
- [§ 11.8.1 Get Window
 Rect](#ref-for-dfn-error-code-73 "§ 11.8.1 Get Window Rect")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-error-code-74 "§ 11.8.2 Set Window Rect")
 [(2)](#ref-for-dfn-error-code-75 "Reference 2")
 [(3)](#ref-for-dfn-error-code-76 "Reference 3")
 [(4)](#ref-for-dfn-error-code-77 "Reference 4")
- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-error-code-78 "§ 11.8.3 Maximize Window")
 [(2)](#ref-for-dfn-error-code-79 "Reference 2")
- [§ 11.8.4 Minimize
 Window](#ref-for-dfn-error-code-80 "§ 11.8.4 Minimize Window")
 [(2)](#ref-for-dfn-error-code-81 "Reference 2")
- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-error-code-82 "§ 11.8.5 Fullscreen Window")
 [(2)](#ref-for-dfn-error-code-83 "Reference 2")
- [§ 12. Elements](#ref-for-dfn-error-code-84 "§ 12. Elements")
 [(2)](#ref-for-dfn-error-code-85 "Reference 2")
 [(3)](#ref-for-dfn-error-code-86 "Reference 3")
 [(4)](#ref-for-dfn-error-code-87 "Reference 4")
 [(5)](#ref-for-dfn-error-code-88 "Reference 5")
- [§ 12.2 Shadow
 Roots](#ref-for-dfn-error-code-89 "§ 12.2 Shadow Roots")
 [(2)](#ref-for-dfn-error-code-90 "Reference 2")
 [(3)](#ref-for-dfn-error-code-91 "Reference 3")
 [(4)](#ref-for-dfn-error-code-92 "Reference 4")
 [(5)](#ref-for-dfn-error-code-93 "Reference 5")
- [§ 12.3.1.1 CSS
 selectors](#ref-for-dfn-error-code-94 "§ 12.3.1.1 CSS selectors")
- [§ 12.3.1.2 Link
 text](#ref-for-dfn-error-code-95 "§ 12.3.1.2 Link text")
- [§ 12.3.1.3 Partial link
 text](#ref-for-dfn-error-code-96 "§ 12.3.1.3 Partial link text")
- [§ 12.3.1.5 XPath](#ref-for-dfn-error-code-97 "§ 12.3.1.5 XPath")
 [(2)](#ref-for-dfn-error-code-98 "Reference 2")
 [(3)](#ref-for-dfn-error-code-99 "Reference 3")
- [§ 12.3.2 Find
 Element](#ref-for-dfn-error-code-100 "§ 12.3.2 Find Element")
 [(2)](#ref-for-dfn-error-code-101 "Reference 2")
 [(3)](#ref-for-dfn-error-code-102 "Reference 3")
 [(4)](#ref-for-dfn-error-code-103 "Reference 4")
 [(5)](#ref-for-dfn-error-code-104 "Reference 5")
- [§ 12.3.3 Find
 Elements](#ref-for-dfn-error-code-105 "§ 12.3.3 Find Elements")
 [(2)](#ref-for-dfn-error-code-106 "Reference 2")
 [(3)](#ref-for-dfn-error-code-107 "Reference 3")
 [(4)](#ref-for-dfn-error-code-108 "Reference 4")
- [§ 12.3.4 Find Element From
 Element](#ref-for-dfn-error-code-109 "§ 12.3.4 Find Element From Element")
 [(2)](#ref-for-dfn-error-code-110 "Reference 2")
 [(3)](#ref-for-dfn-error-code-111 "Reference 3")
 [(4)](#ref-for-dfn-error-code-112 "Reference 4")
- [§ 12.3.5 Find Elements From
 Element](#ref-for-dfn-error-code-113 "§ 12.3.5 Find Elements From Element")
 [(2)](#ref-for-dfn-error-code-114 "Reference 2")
 [(3)](#ref-for-dfn-error-code-115 "Reference 3")
- [§ 12.3.6 Find Element From Shadow
 Root](#ref-for-dfn-error-code-116 "§ 12.3.6 Find Element From Shadow Root")
 [(2)](#ref-for-dfn-error-code-117 "Reference 2")
 [(3)](#ref-for-dfn-error-code-118 "Reference 3")
 [(4)](#ref-for-dfn-error-code-119 "Reference 4")
- [§ 12.3.7 Find Elements From Shadow
 Root](#ref-for-dfn-error-code-120 "§ 12.3.7 Find Elements From Shadow Root")
 [(2)](#ref-for-dfn-error-code-121 "Reference 2")
 [(3)](#ref-for-dfn-error-code-122 "Reference 3")
- [§ 12.3.8 Get Active
 Element](#ref-for-dfn-error-code-123 "§ 12.3.8 Get Active Element")
 [(2)](#ref-for-dfn-error-code-124 "Reference 2")
- [§ 12.3.9 Get Element Shadow
 Root](#ref-for-dfn-error-code-125 "§ 12.3.9 Get Element Shadow Root")
 [(2)](#ref-for-dfn-error-code-126 "Reference 2")
- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-error-code-127 "§ 12.4.1 Is Element Selected")
- [§ 12.4.2 Get Element
 Attribute](#ref-for-dfn-error-code-128 "§ 12.4.2 Get Element Attribute")
- [§ 12.4.3 Get Element
 Property](#ref-for-dfn-error-code-129 "§ 12.4.3 Get Element Property")
- [§ 12.4.4 Get Element CSS
 Value](#ref-for-dfn-error-code-130 "§ 12.4.4 Get Element CSS Value")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-error-code-131 "§ 12.4.5 Get Element Text")
- [§ 12.4.6 Get Element Tag
 Name](#ref-for-dfn-error-code-132 "§ 12.4.6 Get Element Tag Name")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-error-code-133 "§ 12.4.7 Get Element Rect")
- [§ 12.4.8 Is Element
 Enabled](#ref-for-dfn-error-code-134 "§ 12.4.8 Is Element Enabled")
- [§ 12.4.9 Get Computed
 Role](#ref-for-dfn-error-code-135 "§ 12.4.9 Get Computed Role")
- [§ 12.4.10 Get Computed
 Label](#ref-for-dfn-error-code-136 "§ 12.4.10 Get Computed Label")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-error-code-137 "§ 12.5.1 Element Click")
 [(2)](#ref-for-dfn-error-code-138 "Reference 2")
 [(3)](#ref-for-dfn-error-code-139 "Reference 3")
 [(4)](#ref-for-dfn-error-code-140 "Reference 4")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-error-code-141 "§ 12.5.2 Element Clear")
 [(2)](#ref-for-dfn-error-code-142 "Reference 2")
 [(3)](#ref-for-dfn-error-code-143 "Reference 3")
 [(4)](#ref-for-dfn-error-code-144 "Reference 4")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-error-code-145 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-error-code-146 "Reference 2")
 [(3)](#ref-for-dfn-error-code-147 "Reference 3")
 [(4)](#ref-for-dfn-error-code-148 "Reference 4")
 [(5)](#ref-for-dfn-error-code-149 "Reference 5")
 [(6)](#ref-for-dfn-error-code-150 "Reference 6")
 [(7)](#ref-for-dfn-error-code-151 "Reference 7")
 [(8)](#ref-for-dfn-error-code-152 "Reference 8")
 [(9)](#ref-for-dfn-error-code-153 "Reference 9")
 [(10)](#ref-for-dfn-error-code-154 "Reference 10")
 [(11)](#ref-for-dfn-error-code-155 "Reference 11")
- [§ 13.1 Get Page
 Source](#ref-for-dfn-error-code-156 "§ 13.1 Get Page Source")
- [§ 13.2 Executing
 Script](#ref-for-dfn-error-code-157 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-error-code-158 "Reference 2")
 [(3)](#ref-for-dfn-error-code-159 "Reference 3")
 [(4)](#ref-for-dfn-error-code-160 "Reference 4")
 [(5)](#ref-for-dfn-error-code-161 "Reference 5")
 [(6)](#ref-for-dfn-error-code-162 "Reference 6")
 [(7)](#ref-for-dfn-error-code-163 "Reference 7")
- [§ 13.2.1 Execute
 Script](#ref-for-dfn-error-code-164 "§ 13.2.1 Execute Script")
 [(2)](#ref-for-dfn-error-code-165 "Reference 2")
 [(3)](#ref-for-dfn-error-code-166 "Reference 3")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-error-code-167 "§ 13.2.2 Execute Async Script")
 [(2)](#ref-for-dfn-error-code-168 "Reference 2")
 [(3)](#ref-for-dfn-error-code-169 "Reference 3")
- [§ 14.1 Get All
 Cookies](#ref-for-dfn-error-code-170 "§ 14.1 Get All Cookies")
- [§ 14.2 Get Named
 Cookie](#ref-for-dfn-error-code-171 "§ 14.2 Get Named Cookie")
 [(2)](#ref-for-dfn-error-code-172 "Reference 2")
- [§ 14.3 Add Cookie](#ref-for-dfn-error-code-173 "§ 14.3 Add Cookie")
 [(2)](#ref-for-dfn-error-code-174 "Reference 2")
 [(3)](#ref-for-dfn-error-code-175 "Reference 3")
 [(4)](#ref-for-dfn-error-code-176 "Reference 4")
 [(5)](#ref-for-dfn-error-code-177 "Reference 5")
- [§ 14.4 Delete
 Cookie](#ref-for-dfn-error-code-178 "§ 14.4 Delete Cookie")
- [§ 14.5 Delete All
 Cookies](#ref-for-dfn-error-code-179 "§ 14.5 Delete All Cookies")
- [§ 15.2 Input
 sources](#ref-for-dfn-error-code-180 "§ 15.2 Input sources")
- [§ 15.3 Input state](#ref-for-dfn-error-code-181 "§ 15.3 Input state")
- [§ 15.5 Processing
 actions](#ref-for-dfn-error-code-182 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-error-code-183 "Reference 2")
 [(3)](#ref-for-dfn-error-code-184 "Reference 3")
 [(4)](#ref-for-dfn-error-code-185 "Reference 4")
 [(5)](#ref-for-dfn-error-code-186 "Reference 5")
 [(6)](#ref-for-dfn-error-code-187 "Reference 6")
 [(7)](#ref-for-dfn-error-code-188 "Reference 7")
 [(8)](#ref-for-dfn-error-code-189 "Reference 8")
 [(9)](#ref-for-dfn-error-code-190 "Reference 9")
 [(10)](#ref-for-dfn-error-code-191 "Reference 10")
 [(11)](#ref-for-dfn-error-code-192 "Reference 11")
 [(12)](#ref-for-dfn-error-code-193 "Reference 12")
 [(13)](#ref-for-dfn-error-code-194 "Reference 13")
 [(14)](#ref-for-dfn-error-code-195 "Reference 14")
 [(15)](#ref-for-dfn-error-code-196 "Reference 15")
 [(16)](#ref-for-dfn-error-code-197 "Reference 16")
 [(17)](#ref-for-dfn-error-code-198 "Reference 17")
 [(18)](#ref-for-dfn-error-code-199 "Reference 18")
 [(19)](#ref-for-dfn-error-code-200 "Reference 19")
 [(20)](#ref-for-dfn-error-code-201 "Reference 20")
 [(21)](#ref-for-dfn-error-code-202 "Reference 21")
 [(22)](#ref-for-dfn-error-code-203 "Reference 22")
 [(23)](#ref-for-dfn-error-code-204 "Reference 23")
 [(24)](#ref-for-dfn-error-code-205 "Reference 24")
 [(25)](#ref-for-dfn-error-code-206 "Reference 25")
 [(26)](#ref-for-dfn-error-code-207 "Reference 26")
 [(27)](#ref-for-dfn-error-code-208 "Reference 27")
 [(28)](#ref-for-dfn-error-code-209 "Reference 28")
 [(29)](#ref-for-dfn-error-code-210 "Reference 29")
 [(30)](#ref-for-dfn-error-code-211 "Reference 30")
 [(31)](#ref-for-dfn-error-code-212 "Reference 31")
 [(32)](#ref-for-dfn-error-code-213 "Reference 32")
 [(33)](#ref-for-dfn-error-code-214 "Reference 33")
 [(34)](#ref-for-dfn-error-code-215 "Reference 34")
 [(35)](#ref-for-dfn-error-code-216 "Reference 35")
 [(36)](#ref-for-dfn-error-code-217 "Reference 36")
 [(37)](#ref-for-dfn-error-code-218 "Reference 37")
 [(38)](#ref-for-dfn-error-code-219 "Reference 38")
 [(39)](#ref-for-dfn-error-code-220 "Reference 39")
 [(40)](#ref-for-dfn-error-code-221 "Reference 40")
 [(41)](#ref-for-dfn-error-code-222 "Reference 41")
 [(42)](#ref-for-dfn-error-code-223 "Reference 42")
 [(43)](#ref-for-dfn-error-code-224 "Reference 43")
 [(44)](#ref-for-dfn-error-code-225 "Reference 44")
- [§ 15.6 Dispatching
 actions](#ref-for-dfn-error-code-226 "§ 15.6 Dispatching actions")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-error-code-227 "§ 15.7 Perform Actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-error-code-228 "§ 15.8 Release Actions")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-error-code-229 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-error-code-230 "Reference 2")
 [(3)](#ref-for-dfn-error-code-231 "Reference 3")
 [(4)](#ref-for-dfn-error-code-232 "Reference 4")
 [(5)](#ref-for-dfn-error-code-233 "Reference 5")
- [§ 16.2 Dismiss
 Alert](#ref-for-dfn-error-code-234 "§ 16.2 Dismiss Alert")
 [(2)](#ref-for-dfn-error-code-235 "Reference 2")
- [§ 16.3 Accept
 Alert](#ref-for-dfn-error-code-236 "§ 16.3 Accept Alert")
 [(2)](#ref-for-dfn-error-code-237 "Reference 2")
- [§ 16.4 Get Alert
 Text](#ref-for-dfn-error-code-238 "§ 16.4 Get Alert Text")
 [(2)](#ref-for-dfn-error-code-239 "Reference 2")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-error-code-240 "§ 16.5 Send Alert Text")
 [(2)](#ref-for-dfn-error-code-241 "Reference 2")
 [(3)](#ref-for-dfn-error-code-242 "Reference 3")
 [(4)](#ref-for-dfn-error-code-243 "Reference 4")
 [(5)](#ref-for-dfn-error-code-244 "Reference 5")
- [§ 17. Screen
 capture](#ref-for-dfn-error-code-245 "§ 17. Screen capture")
 [(2)](#ref-for-dfn-error-code-246 "Reference 2")
 [(3)](#ref-for-dfn-error-code-247 "Reference 3")
- [§ 17.1 Take
 Screenshot](#ref-for-dfn-error-code-248 "§ 17.1 Take Screenshot")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-error-code-249 "§ 17.2 Take Element Screenshot")
- [§ 18. Print](#ref-for-dfn-error-code-250 "§ 18. Print")
 [(2)](#ref-for-dfn-error-code-251 "Reference 2")
 [(3)](#ref-for-dfn-error-code-252 "Reference 3")
 [(4)](#ref-for-dfn-error-code-253 "Reference 4")
- [§ 18.1 Print Page](#ref-for-dfn-error-code-254 "§ 18.1 Print Page")
 [(2)](#ref-for-dfn-error-code-255 "Reference 2")
 [(3)](#ref-for-dfn-error-code-256 "Reference 3")
 [(4)](#ref-for-dfn-error-code-257 "Reference 4")
 [(5)](#ref-for-dfn-error-code-258 "Reference 5")
 [(6)](#ref-for-dfn-error-code-259 "Reference 6")
 [(7)](#ref-for-dfn-error-code-260 "Reference 7")
 [(8)](#ref-for-dfn-error-code-261 "Reference 8")
- [§ C. Element
 displayedness](#ref-for-dfn-error-code-262 "§ C. Element displayedness")

[Permalink](#dfn-error-response-data)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-error-response-data-1 "§ 6.3 Processing model")

[Permalink](#dfn-element-click-intercepted)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-element-click-intercepted-1 "§ 12.5.1 Element Click")
 [(2)](#ref-for-dfn-element-click-intercepted-2 "Reference 2")

[Permalink](#dfn-element-not-interactable)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-element-not-interactable-1 "§ 12.5.1 Element Click")
 [(2)](#ref-for-dfn-element-not-interactable-2 "Reference 2")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-element-not-interactable-3 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-element-not-interactable-4 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-element-not-interactable-5 "Reference 2")
 [(3)](#ref-for-dfn-element-not-interactable-6 "Reference 3")
 [(4)](#ref-for-dfn-element-not-interactable-7 "Reference 4")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-element-not-interactable-8 "§ 16.5 Send Alert Text")

[Permalink](#dfn-insecure-certificate)

**Referenced in:**

- [§ 10.
 Navigation](#ref-for-dfn-insecure-certificate-1 "§ 10. Navigation")

[Permalink](#dfn-invalid-argument)
[exported]

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-invalid-argument-1 "§ 6.3 Processing model")
 [(2)](#ref-for-dfn-invalid-argument-2 "Reference 2")
- [§ 7.1 Proxy](#ref-for-dfn-invalid-argument-3 "§ 7.1 Proxy")
 [(2)](#ref-for-dfn-invalid-argument-4 "Reference 2")
 [(3)](#ref-for-dfn-invalid-argument-5 "Reference 3")
 [(4)](#ref-for-dfn-invalid-argument-6 "Reference 4")
 [(5)](#ref-for-dfn-invalid-argument-7 "Reference 5")
 [(6)](#ref-for-dfn-invalid-argument-8 "Reference 6")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-invalid-argument-9 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-invalid-argument-10 "Reference 2")
 [(3)](#ref-for-dfn-invalid-argument-11 "Reference 3")
 [(4)](#ref-for-dfn-invalid-argument-12 "Reference 4")
 [(5)](#ref-for-dfn-invalid-argument-13 "Reference 5")
 [(6)](#ref-for-dfn-invalid-argument-14 "Reference 6")
 [(7)](#ref-for-dfn-invalid-argument-15 "Reference 7")
 [(8)](#ref-for-dfn-invalid-argument-16 "Reference 8")
- [§ 9. Timeouts](#ref-for-dfn-invalid-argument-17 "§ 9. Timeouts")
- [§ 10.
 Navigation](#ref-for-dfn-invalid-argument-18 "§ 10. Navigation")
 [(2)](#ref-for-dfn-invalid-argument-19 "Reference 2")
- [§ 10.1 Navigate
 To](#ref-for-dfn-invalid-argument-20 "§ 10.1 Navigate To")
- [§ 11. Contexts](#ref-for-dfn-invalid-argument-21 "§ 11. Contexts")
 [(2)](#ref-for-dfn-invalid-argument-22 "Reference 2")
 [(3)](#ref-for-dfn-invalid-argument-23 "Reference 3")
 [(4)](#ref-for-dfn-invalid-argument-24 "Reference 4")
- [§ 11.3 Switch To
 Window](#ref-for-dfn-invalid-argument-25 "§ 11.3 Switch To Window")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-invalid-argument-26 "§ 11.6 Switch To Frame")
 [(2)](#ref-for-dfn-invalid-argument-27 "Reference 2")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-invalid-argument-28 "§ 11.8.2 Set Window Rect")
 [(2)](#ref-for-dfn-invalid-argument-29 "Reference 2")
- [§ 12. Elements](#ref-for-dfn-invalid-argument-30 "§ 12. Elements")
 [(2)](#ref-for-dfn-invalid-argument-31 "Reference 2")
- [§ 12.2 Shadow
 Roots](#ref-for-dfn-invalid-argument-32 "§ 12.2 Shadow Roots")
 [(2)](#ref-for-dfn-invalid-argument-33 "Reference 2")
- [§ 12.3.2 Find
 Element](#ref-for-dfn-invalid-argument-34 "§ 12.3.2 Find Element")
 [(2)](#ref-for-dfn-invalid-argument-35 "Reference 2")
- [§ 12.3.3 Find
 Elements](#ref-for-dfn-invalid-argument-36 "§ 12.3.3 Find Elements")
 [(2)](#ref-for-dfn-invalid-argument-37 "Reference 2")
- [§ 12.3.4 Find Element From
 Element](#ref-for-dfn-invalid-argument-38 "§ 12.3.4 Find Element From Element")
 [(2)](#ref-for-dfn-invalid-argument-39 "Reference 2")
- [§ 12.3.5 Find Elements From
 Element](#ref-for-dfn-invalid-argument-40 "§ 12.3.5 Find Elements From Element")
 [(2)](#ref-for-dfn-invalid-argument-41 "Reference 2")
- [§ 12.3.6 Find Element From Shadow
 Root](#ref-for-dfn-invalid-argument-42 "§ 12.3.6 Find Element From Shadow Root")
 [(2)](#ref-for-dfn-invalid-argument-43 "Reference 2")
- [§ 12.3.7 Find Elements From Shadow
 Root](#ref-for-dfn-invalid-argument-44 "§ 12.3.7 Find Elements From Shadow Root")
 [(2)](#ref-for-dfn-invalid-argument-45 "Reference 2")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-invalid-argument-46 "§ 12.5.1 Element Click")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-invalid-argument-47 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-invalid-argument-48 "Reference 2")
 [(3)](#ref-for-dfn-invalid-argument-49 "Reference 3")
 [(4)](#ref-for-dfn-invalid-argument-50 "Reference 4")
 [(5)](#ref-for-dfn-invalid-argument-51 "Reference 5")
 [(6)](#ref-for-dfn-invalid-argument-52 "Reference 6")
 [(7)](#ref-for-dfn-invalid-argument-53 "Reference 7")
- [§ 13.2 Executing
 Script](#ref-for-dfn-invalid-argument-54 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-invalid-argument-55 "Reference 2")
- [§ 14.3 Add
 Cookie](#ref-for-dfn-invalid-argument-56 "§ 14.3 Add Cookie")
 [(2)](#ref-for-dfn-invalid-argument-57 "Reference 2")
- [§ 15.2 Input
 sources](#ref-for-dfn-invalid-argument-58 "§ 15.2 Input sources")
- [§ 15.3 Input
 state](#ref-for-dfn-invalid-argument-59 "§ 15.3 Input state")
- [§ 15.5 Processing
 actions](#ref-for-dfn-invalid-argument-60 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-invalid-argument-61 "Reference 2")
 [(3)](#ref-for-dfn-invalid-argument-62 "Reference 3")
 [(4)](#ref-for-dfn-invalid-argument-63 "Reference 4")
 [(5)](#ref-for-dfn-invalid-argument-64 "Reference 5")
 [(6)](#ref-for-dfn-invalid-argument-65 "Reference 6")
 [(7)](#ref-for-dfn-invalid-argument-66 "Reference 7")
 [(8)](#ref-for-dfn-invalid-argument-67 "Reference 8")
 [(9)](#ref-for-dfn-invalid-argument-68 "Reference 9")
 [(10)](#ref-for-dfn-invalid-argument-69 "Reference 10")
 [(11)](#ref-for-dfn-invalid-argument-70 "Reference 11")
 [(12)](#ref-for-dfn-invalid-argument-71 "Reference 12")
 [(13)](#ref-for-dfn-invalid-argument-72 "Reference 13")
 [(14)](#ref-for-dfn-invalid-argument-73 "Reference 14")
 [(15)](#ref-for-dfn-invalid-argument-74 "Reference 15")
 [(16)](#ref-for-dfn-invalid-argument-75 "Reference 16")
 [(17)](#ref-for-dfn-invalid-argument-76 "Reference 17")
 [(18)](#ref-for-dfn-invalid-argument-77 "Reference 18")
 [(19)](#ref-for-dfn-invalid-argument-78 "Reference 19")
 [(20)](#ref-for-dfn-invalid-argument-79 "Reference 20")
 [(21)](#ref-for-dfn-invalid-argument-80 "Reference 21")
 [(22)](#ref-for-dfn-invalid-argument-81 "Reference 22")
 [(23)](#ref-for-dfn-invalid-argument-82 "Reference 23")
 [(24)](#ref-for-dfn-invalid-argument-83 "Reference 24")
 [(25)](#ref-for-dfn-invalid-argument-84 "Reference 25")
 [(26)](#ref-for-dfn-invalid-argument-85 "Reference 26")
 [(27)](#ref-for-dfn-invalid-argument-86 "Reference 27")
 [(28)](#ref-for-dfn-invalid-argument-87 "Reference 28")
 [(29)](#ref-for-dfn-invalid-argument-88 "Reference 29")
 [(30)](#ref-for-dfn-invalid-argument-89 "Reference 30")
 [(31)](#ref-for-dfn-invalid-argument-90 "Reference 31")
 [(32)](#ref-for-dfn-invalid-argument-91 "Reference 32")
 [(33)](#ref-for-dfn-invalid-argument-92 "Reference 33")
 [(34)](#ref-for-dfn-invalid-argument-93 "Reference 34")
 [(35)](#ref-for-dfn-invalid-argument-94 "Reference 35")
 [(36)](#ref-for-dfn-invalid-argument-95 "Reference 36")
 [(37)](#ref-for-dfn-invalid-argument-96 "Reference 37")
 [(38)](#ref-for-dfn-invalid-argument-97 "Reference 38")
 [(39)](#ref-for-dfn-invalid-argument-98 "Reference 39")
 [(40)](#ref-for-dfn-invalid-argument-99 "Reference 40")
 [(41)](#ref-for-dfn-invalid-argument-100 "Reference 41")
 [(42)](#ref-for-dfn-invalid-argument-101 "Reference 42")
 [(43)](#ref-for-dfn-invalid-argument-102 "Reference 43")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-invalid-argument-103 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-invalid-argument-104 "Reference 2")
 [(3)](#ref-for-dfn-invalid-argument-105 "Reference 3")
 [(4)](#ref-for-dfn-invalid-argument-106 "Reference 4")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-invalid-argument-107 "§ 16.5 Send Alert Text")
- [§ 18. Print](#ref-for-dfn-invalid-argument-108 "§ 18. Print")
 [(2)](#ref-for-dfn-invalid-argument-109 "Reference 2")
 [(3)](#ref-for-dfn-invalid-argument-110 "Reference 3")
 [(4)](#ref-for-dfn-invalid-argument-111 "Reference 4")
 [(5)](#ref-for-dfn-invalid-argument-112 "Reference 5")
 [(6)](#ref-for-dfn-invalid-argument-113 "Reference 6")
- [§ 18.1 Print
 Page](#ref-for-dfn-invalid-argument-114 "§ 18.1 Print Page")
 [(2)](#ref-for-dfn-invalid-argument-115 "Reference 2")
 [(3)](#ref-for-dfn-invalid-argument-116 "Reference 3")
 [(4)](#ref-for-dfn-invalid-argument-117 "Reference 4")
 [(5)](#ref-for-dfn-invalid-argument-118 "Reference 5")
 [(6)](#ref-for-dfn-invalid-argument-119 "Reference 6")
 [(7)](#ref-for-dfn-invalid-argument-120 "Reference 7")

[Permalink](#dfn-invalid-cookie-domain)

**Referenced in:**

- [§ 14.3 Add
 Cookie](#ref-for-dfn-invalid-cookie-domain-1 "§ 14.3 Add Cookie")

[Permalink](#dfn-invalid-element-state)

**Referenced in:**

- [§ 12.5.2 Element
 Clear](#ref-for-dfn-invalid-element-state-1 "§ 12.5.2 Element Clear")
 [(2)](#ref-for-dfn-invalid-element-state-2 "Reference 2")

[Permalink](#dfn-invalid-selector)

**Referenced in:**

- [§ 12.3 Retrieval](#ref-for-dfn-invalid-selector-1 "§ 12.3 Retrieval")
- [§ 12.3.1.1 CSS
 selectors](#ref-for-dfn-invalid-selector-2 "§ 12.3.1.1 CSS selectors")
- [§ 12.3.1.5 XPath](#ref-for-dfn-invalid-selector-3 "§ 12.3.1.5 XPath")
 [(2)](#ref-for-dfn-invalid-selector-4 "Reference 2")

[Permalink](#dfn-invalid-session-id)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-invalid-session-id-1 "§ 6.3 Processing model")
 [(2)](#ref-for-dfn-invalid-session-id-2 "Reference 2")

[Permalink](#dfn-javascript-error)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-javascript-error-1 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-javascript-error-2 "Reference 2")
- [§ 13.2.1 Execute
 Script](#ref-for-dfn-javascript-error-3 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-javascript-error-4 "§ 13.2.2 Execute Async Script")

[Permalink](#dfn-move-target-out-of-bounds)

**Referenced in:**

- [§ 15.6.3 Pointer
 actions](#ref-for-dfn-move-target-out-of-bounds-1 "§ 15.6.3 Pointer actions")
 [(2)](#ref-for-dfn-move-target-out-of-bounds-2 "Reference 2")
- [§ 15.6.4 Wheel
 actions](#ref-for-dfn-move-target-out-of-bounds-3 "§ 15.6.4 Wheel actions")
 [(2)](#ref-for-dfn-move-target-out-of-bounds-4 "Reference 2")

[Permalink](#dfn-no-such-alert)

**Referenced in:**

- [§ 16.2 Dismiss
 Alert](#ref-for-dfn-no-such-alert-1 "§ 16.2 Dismiss Alert")
- [§ 16.3 Accept
 Alert](#ref-for-dfn-no-such-alert-2 "§ 16.3 Accept Alert")
- [§ 16.4 Get Alert
 Text](#ref-for-dfn-no-such-alert-3 "§ 16.4 Get Alert Text")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-no-such-alert-4 "§ 16.5 Send Alert Text")

[Permalink](#dfn-no-such-cookie)

**Referenced in:**

- [§ 14.2 Get Named
 Cookie](#ref-for-dfn-no-such-cookie-1 "§ 14.2 Get Named Cookie")

[Permalink](#dfn-no-such-element)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-no-such-element-1 "§ 12. Elements")
 [(2)](#ref-for-dfn-no-such-element-2 "Reference 2")
- [§ 12.3.2 Find
 Element](#ref-for-dfn-no-such-element-3 "§ 12.3.2 Find Element")
 [(2)](#ref-for-dfn-no-such-element-4 "Reference 2")
- [§ 12.3.3 Find
 Elements](#ref-for-dfn-no-such-element-5 "§ 12.3.3 Find Elements")
- [§ 12.3.4 Find Element From
 Element](#ref-for-dfn-no-such-element-6 "§ 12.3.4 Find Element From Element")
- [§ 12.3.6 Find Element From Shadow
 Root](#ref-for-dfn-no-such-element-7 "§ 12.3.6 Find Element From Shadow Root")
- [§ 12.3.8 Get Active
 Element](#ref-for-dfn-no-such-element-8 "§ 12.3.8 Get Active Element")
- [§ 15.5 Processing
 actions](#ref-for-dfn-no-such-element-9 "§ 15.5 Processing actions")

[Permalink](#dfn-no-such-frame)

**Referenced in:**

- [§ 11. Contexts](#ref-for-dfn-no-such-frame-1 "§ 11. Contexts")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-no-such-frame-2 "§ 11.6 Switch To Frame")
 [(2)](#ref-for-dfn-no-such-frame-3 "Reference 2")

[Permalink](#dfn-no-such-window)

**Referenced in:**

- [§ 10.1 Navigate
 To](#ref-for-dfn-no-such-window-1 "§ 10.1 Navigate To")
- [§ 10.2 Get Current
 URL](#ref-for-dfn-no-such-window-2 "§ 10.2 Get Current URL")
- [§ 10.3 Back](#ref-for-dfn-no-such-window-3 "§ 10.3 Back")
- [§ 10.4 Forward](#ref-for-dfn-no-such-window-4 "§ 10.4 Forward")
- [§ 10.5 Refresh](#ref-for-dfn-no-such-window-5 "§ 10.5 Refresh")
- [§ 10.6 Get Title](#ref-for-dfn-no-such-window-6 "§ 10.6 Get Title")
- [§ 11. Contexts](#ref-for-dfn-no-such-window-7 "§ 11. Contexts")
- [§ 11.1 Get Window
 Handle](#ref-for-dfn-no-such-window-8 "§ 11.1 Get Window Handle")
- [§ 11.2 Close
 Window](#ref-for-dfn-no-such-window-9 "§ 11.2 Close Window")
- [§ 11.3 Switch To
 Window](#ref-for-dfn-no-such-window-10 "§ 11.3 Switch To Window")
- [§ 11.5 New
 Window](#ref-for-dfn-no-such-window-11 "§ 11.5 New Window")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-no-such-window-12 "§ 11.6 Switch To Frame")
 [(2)](#ref-for-dfn-no-such-window-13 "Reference 2")
 [(3)](#ref-for-dfn-no-such-window-14 "Reference 3")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-dfn-no-such-window-15 "§ 11.7 Switch To Parent Frame")
 [(2)](#ref-for-dfn-no-such-window-16 "Reference 2")
- [§ 11.8.1 Get Window
 Rect](#ref-for-dfn-no-such-window-17 "§ 11.8.1 Get Window Rect")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-no-such-window-18 "§ 11.8.2 Set Window Rect")
- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-no-such-window-19 "§ 11.8.3 Maximize Window")
- [§ 11.8.4 Minimize
 Window](#ref-for-dfn-no-such-window-20 "§ 11.8.4 Minimize Window")
- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-no-such-window-21 "§ 11.8.5 Fullscreen Window")
- [§ 12.3.2 Find
 Element](#ref-for-dfn-no-such-window-22 "§ 12.3.2 Find Element")
- [§ 12.3.3 Find
 Elements](#ref-for-dfn-no-such-window-23 "§ 12.3.3 Find Elements")
- [§ 12.3.4 Find Element From
 Element](#ref-for-dfn-no-such-window-24 "§ 12.3.4 Find Element From Element")
- [§ 12.3.5 Find Elements From
 Element](#ref-for-dfn-no-such-window-25 "§ 12.3.5 Find Elements From Element")
- [§ 12.3.6 Find Element From Shadow
 Root](#ref-for-dfn-no-such-window-26 "§ 12.3.6 Find Element From Shadow Root")
- [§ 12.3.7 Find Elements From Shadow
 Root](#ref-for-dfn-no-such-window-27 "§ 12.3.7 Find Elements From Shadow Root")
- [§ 12.3.8 Get Active
 Element](#ref-for-dfn-no-such-window-28 "§ 12.3.8 Get Active Element")
- [§ 12.3.9 Get Element Shadow
 Root](#ref-for-dfn-no-such-window-29 "§ 12.3.9 Get Element Shadow Root")
- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-no-such-window-30 "§ 12.4.1 Is Element Selected")
- [§ 12.4.2 Get Element
 Attribute](#ref-for-dfn-no-such-window-31 "§ 12.4.2 Get Element Attribute")
- [§ 12.4.3 Get Element
 Property](#ref-for-dfn-no-such-window-32 "§ 12.4.3 Get Element Property")
- [§ 12.4.4 Get Element CSS
 Value](#ref-for-dfn-no-such-window-33 "§ 12.4.4 Get Element CSS Value")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-no-such-window-34 "§ 12.4.5 Get Element Text")
- [§ 12.4.6 Get Element Tag
 Name](#ref-for-dfn-no-such-window-35 "§ 12.4.6 Get Element Tag Name")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-no-such-window-36 "§ 12.4.7 Get Element Rect")
- [§ 12.4.8 Is Element
 Enabled](#ref-for-dfn-no-such-window-37 "§ 12.4.8 Is Element Enabled")
- [§ 12.4.9 Get Computed
 Role](#ref-for-dfn-no-such-window-38 "§ 12.4.9 Get Computed Role")
- [§ 12.4.10 Get Computed
 Label](#ref-for-dfn-no-such-window-39 "§ 12.4.10 Get Computed Label")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-no-such-window-40 "§ 12.5.1 Element Click")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-no-such-window-41 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-no-such-window-42 "§ 12.5.3 Element Send Keys")
- [§ 13.1 Get Page
 Source](#ref-for-dfn-no-such-window-43 "§ 13.1 Get Page Source")
- [§ 13.2.1 Execute
 Script](#ref-for-dfn-no-such-window-44 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-no-such-window-45 "§ 13.2.2 Execute Async Script")
- [§ 14.1 Get All
 Cookies](#ref-for-dfn-no-such-window-46 "§ 14.1 Get All Cookies")
- [§ 14.2 Get Named
 Cookie](#ref-for-dfn-no-such-window-47 "§ 14.2 Get Named Cookie")
- [§ 14.3 Add
 Cookie](#ref-for-dfn-no-such-window-48 "§ 14.3 Add Cookie")
- [§ 14.4 Delete
 Cookie](#ref-for-dfn-no-such-window-49 "§ 14.4 Delete Cookie")
- [§ 14.5 Delete All
 Cookies](#ref-for-dfn-no-such-window-50 "§ 14.5 Delete All Cookies")
- [§ 15.6 Dispatching
 actions](#ref-for-dfn-no-such-window-51 "§ 15.6 Dispatching actions")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-no-such-window-52 "§ 15.7 Perform Actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-no-such-window-53 "§ 15.8 Release Actions")
- [§ 16.2 Dismiss
 Alert](#ref-for-dfn-no-such-window-54 "§ 16.2 Dismiss Alert")
- [§ 16.3 Accept
 Alert](#ref-for-dfn-no-such-window-55 "§ 16.3 Accept Alert")
- [§ 16.4 Get Alert
 Text](#ref-for-dfn-no-such-window-56 "§ 16.4 Get Alert Text")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-no-such-window-57 "§ 16.5 Send Alert Text")
- [§ 17.1 Take
 Screenshot](#ref-for-dfn-no-such-window-58 "§ 17.1 Take Screenshot")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-no-such-window-59 "§ 17.2 Take Element Screenshot")
- [§ 18.1 Print
 Page](#ref-for-dfn-no-such-window-60 "§ 18.1 Print Page")

[Permalink](#dfn-no-such-shadow-root)

**Referenced in:**

- [§ 12.2 Shadow
 Roots](#ref-for-dfn-no-such-shadow-root-1 "§ 12.2 Shadow Roots")
 [(2)](#ref-for-dfn-no-such-shadow-root-2 "Reference 2")
- [§ 12.3.9 Get Element Shadow
 Root](#ref-for-dfn-no-such-shadow-root-3 "§ 12.3.9 Get Element Shadow Root")

[Permalink](#dfn-script-timeout-error)

**Referenced in:**

- [§ 13.2.1 Execute
 Script](#ref-for-dfn-script-timeout-error-1 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-script-timeout-error-2 "§ 13.2.2 Execute Async Script")

[Permalink](#dfn-session-not-created)

**Referenced in:**

- [§ 8.1 Global
 State](#ref-for-dfn-session-not-created-1 "§ 8.1 Global State")
- [§ 8.2 New
 Session](#ref-for-dfn-session-not-created-2 "§ 8.2 New Session")
 [(2)](#ref-for-dfn-session-not-created-3 "Reference 2")
 [(3)](#ref-for-dfn-session-not-created-4 "Reference 3")
 [(4)](#ref-for-dfn-session-not-created-5 "Reference 4")

[Permalink](#dfn-stale-element-reference)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-dfn-stale-element-reference-1 "§ 12. Elements")
- [§ 13.2 Executing
 Script](#ref-for-dfn-stale-element-reference-2 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-stale-element-reference-3 "Reference 2")

[Permalink](#dfn-detached-shadow-root)

**Referenced in:**

- [§ 12.2 Shadow
 Roots](#ref-for-dfn-detached-shadow-root-1 "§ 12.2 Shadow Roots")
- [§ 13.2 Executing
 Script](#ref-for-dfn-detached-shadow-root-2 "§ 13.2 Executing Script")

[Permalink](#dfn-timeout)

**Referenced in:**

- [§ 10. Navigation](#ref-for-dfn-timeout-1 "§ 10. Navigation")
 [(2)](#ref-for-dfn-timeout-2 "Reference 2")
- [§ 10.1 Navigate To](#ref-for-dfn-timeout-3 "§ 10.1 Navigate To")
- [§ 10.3 Back](#ref-for-dfn-timeout-4 "§ 10.3 Back")
- [§ 10.4 Forward](#ref-for-dfn-timeout-5 "§ 10.4 Forward")

[Permalink](#dfn-unable-to-set-cookie)

**Referenced in:**

- [§ 14.3 Add
 Cookie](#ref-for-dfn-unable-to-set-cookie-1 "§ 14.3 Add Cookie")

[Permalink](#dfn-unable-to-capture-screen)

**Referenced in:**

- [§ 17. Screen
 capture](#ref-for-dfn-unable-to-capture-screen-1 "§ 17. Screen capture")
 [(2)](#ref-for-dfn-unable-to-capture-screen-2 "Reference 2")
 [(3)](#ref-for-dfn-unable-to-capture-screen-3 "Reference 3")

[Permalink](#dfn-unexpected-alert-open)

**Referenced in:**

- [§ 11.3 Switch To
 Window](#ref-for-dfn-unexpected-alert-open-1 "§ 11.3 Switch To Window")
- [§ 16. User
 prompts](#ref-for-dfn-unexpected-alert-open-2 "§ 16. User prompts")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-unexpected-alert-open-3 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-unexpected-alert-open-4 "Reference 2")

[Permalink](#dfn-unknown-command)

**Referenced in:**

- [§ 6.4 Routing
 requests](#ref-for-dfn-unknown-command-1 "§ 6.4 Routing requests")

[Permalink](#dfn-unknown-error)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-unknown-error-1 "§ 6.3 Processing model")
- [§ 10. Navigation](#ref-for-dfn-unknown-error-2 "§ 10. Navigation")
- [§ 12.3.1.2 Link
 text](#ref-for-dfn-unknown-error-3 "§ 12.3.1.2 Link text")
- [§ 12.3.1.3 Partial link
 text](#ref-for-dfn-unknown-error-4 "§ 12.3.1.3 Partial link text")
- [§ 12.3.1.5 XPath](#ref-for-dfn-unknown-error-5 "§ 12.3.1.5 XPath")
- [§ C. Element
 displayedness](#ref-for-dfn-unknown-error-6 "§ C. Element displayedness")

[Permalink](#dfn-unknown-method)

**Referenced in:**

- [§ 6.4 Routing
 requests](#ref-for-dfn-unknown-method-1 "§ 6.4 Routing requests")

[Permalink](#dfn-unsupported-operation)

**Referenced in:**

- [§ 11.5 New
 Window](#ref-for-dfn-unsupported-operation-1 "§ 11.5 New Window")
- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-unsupported-operation-2 "§ 11.8 Resizing and positioning windows")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-unsupported-operation-3 "§ 11.8.2 Set Window Rect")
- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-unsupported-operation-4 "§ 11.8.3 Maximize Window")
- [§ 11.8.4 Minimize
 Window](#ref-for-dfn-unsupported-operation-5 "§ 11.8.4 Minimize Window")
- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-unsupported-operation-6 "§ 11.8.5 Fullscreen Window")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-unsupported-operation-7 "§ 16.5 Send Alert Text")

[Permalink](#dfn-error-data)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-error-data-1 "§ 6.3 Processing model")
- [§ 6.6 Errors](#ref-for-dfn-error-data-2 "§ 6.6 Errors")
 [(2)](#ref-for-dfn-error-data-3 "Reference 2")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-error-data-4 "§ 16.1 User Prompt Handler")

[Permalink](#dfn-extension-commands)
[exported]

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-extension-commands-1 "§ 6.3 Processing model")
- [§ 6.5 Endpoints](#ref-for-dfn-extension-commands-2 "§ 6.5 Endpoints")
- [§ 6.7
 Extensions](#ref-for-dfn-extension-commands-3 "§ 6.7 Extensions")
 [(2)](#ref-for-dfn-extension-commands-4 "Reference 2")
 [(3)](#ref-for-dfn-extension-commands-5 "Reference 3")
 [(4)](#ref-for-dfn-extension-commands-6 "Reference 4")

[Permalink](#dfn-extension-command-uri-template)
[exported]

**Referenced in:**

- [§ 6.7
 Extensions](#ref-for-dfn-extension-command-uri-template-1 "§ 6.7 Extensions")
 [(2)](#ref-for-dfn-extension-command-uri-template-2 "Reference 2")

[Permalink](#dfn-additional-webdriver-capability)

**Referenced in:**

- [§ 6.7
 Extensions](#ref-for-dfn-additional-webdriver-capability-1 "§ 6.7 Extensions")
 [(2)](#ref-for-dfn-additional-webdriver-capability-2 "Reference 2")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-additional-webdriver-capability-3 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-additional-webdriver-capability-4 "Reference 2")

[Permalink](#dfn-capability-name)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-additional-capability-deserialization-algorithm)
[exported]

**Referenced in:**

- [§ 6.7
 Extensions](#ref-for-dfn-additional-capability-deserialization-algorithm-1 "§ 6.7 Extensions")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-additional-capability-deserialization-algorithm-2 "§ 7.2 Processing capabilities")

[Permalink](#dfn-matched-capability-serialization-algorithm)
[exported]

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-dfn-matched-capability-serialization-algorithm-1 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-matched-capability-serialization-algorithm-2 "Reference 2")

[Permalink](#dfn-webdriver-new-session-algorithms)
[exported]

**Referenced in:**

- [§ 8.1 Global
 State](#ref-for-dfn-webdriver-new-session-algorithms-1 "§ 8.1 Global State")

[Permalink](#dfn-extension-capability)

**Referenced in:**

- [§ 6.7
 Extensions](#ref-for-dfn-extension-capability-1 "§ 6.7 Extensions")
 [(2)](#ref-for-dfn-extension-capability-2 "Reference 2")
- [§ 7.
 Capabilities](#ref-for-dfn-extension-capability-3 "§ 7. Capabilities")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-extension-capability-4 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-extension-capability-5 "Reference 2")
 [(3)](#ref-for-dfn-extension-capability-6 "Reference 3")
 [(4)](#ref-for-dfn-extension-capability-7 "Reference 4")
- [§ 8.1 Global
 State](#ref-for-dfn-extension-capability-8 "§ 8.1 Global State")
- [§ 8.2 New
 Session](#ref-for-dfn-extension-capability-9 "§ 8.2 New Session")
 [(2)](#ref-for-dfn-extension-capability-10 "Reference 2")

[Permalink](#dfn-capabilities)

**Referenced in:**

- [§ 6.7 Extensions](#ref-for-dfn-capabilities-1 "§ 6.7 Extensions")
- [§ 7.1 Proxy](#ref-for-dfn-capabilities-2 "§ 7.1 Proxy")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-capabilities-3 "§ 7.2 Processing capabilities")
- [§ 8.2 New Session](#ref-for-dfn-capabilities-4 "§ 8.2 New Session")
 [(2)](#ref-for-dfn-capabilities-5 "Reference 2")
 [(3)](#ref-for-dfn-capabilities-6 "Reference 3")
- [§ 10. Navigation](#ref-for-dfn-capabilities-7 "§ 10. Navigation")
- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-capabilities-8 "§ 11.8 Resizing and positioning windows")

[Permalink](#dfn-table-of-standard-capabilities)

**Referenced in:**

- [§ 6.7
 Extensions](#ref-for-dfn-table-of-standard-capabilities-1 "§ 6.7 Extensions")

[Permalink](#dfn-platform-name)

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-dfn-platform-name-1 "§ 7.2 Processing capabilities")

[Permalink](#dfn-insecure-tls-certificates)

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-dfn-insecure-tls-certificates-1 "§ 7.2 Processing capabilities")

[Permalink](#dfn-page-load-strategy)

**Referenced in:**

- [§ 7.
 Capabilities](#ref-for-dfn-page-load-strategy-1 "§ 7. Capabilities")

[Permalink](#dfn-window-dimensioning-positioning)

**Referenced in:**

- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-window-dimensioning-positioning-1 "§ 11.8 Resizing and positioning windows")

[Permalink](#dfn-proxy-configuration)

**Referenced in:**

- [§ 7.
 Capabilities](#ref-for-dfn-proxy-configuration-1 "§ 7. Capabilities")
- [§ 7.1 Proxy](#ref-for-dfn-proxy-configuration-2 "§ 7.1 Proxy")
 [(2)](#ref-for-dfn-proxy-configuration-3 "Reference 2")
- [§ 8.1 Global
 State](#ref-for-dfn-proxy-configuration-4 "§ 8.1 Global State")

[Permalink](#dfn-proxytype)

**Referenced in:**

- [§ 7.1 Proxy](#ref-for-dfn-proxytype-1 "§ 7.1 Proxy")
 [(2)](#ref-for-dfn-proxytype-2 "Reference 2")
 [(3)](#ref-for-dfn-proxytype-3 "Reference 3")
 [(4)](#ref-for-dfn-proxytype-4 "Reference 4")
 [(5)](#ref-for-dfn-proxytype-5 "Reference 5")
 [(6)](#ref-for-dfn-proxytype-6 "Reference 6")
 [(7)](#ref-for-dfn-proxytype-7 "Reference 7")
 [(8)](#ref-for-dfn-proxytype-8 "Reference 8")
 [(9)](#ref-for-dfn-proxytype-9 "Reference 9")

[Permalink](#dfn-host-and-optional-port)

**Referenced in:**

- [§ 7.1 Proxy](#ref-for-dfn-host-and-optional-port-1 "§ 7.1 Proxy")
 [(2)](#ref-for-dfn-host-and-optional-port-2 "Reference 2")
 [(3)](#ref-for-dfn-host-and-optional-port-3 "Reference 3")

[Permalink](#dfn-deserialize-as-a-proxy)

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-dfn-deserialize-as-a-proxy-1 "§ 7.2 Processing capabilities")

[Permalink](#dfn-proxy-configuration-object)

**Referenced in:**

- [§ 7.1 Proxy](#ref-for-dfn-proxy-configuration-object-1 "§ 7.1 Proxy")

[Permalink](#dfn-capabilities-processing)

**Referenced in:**

- [§ 8.2 New
 Session](#ref-for-dfn-capabilities-processing-1 "§ 8.2 New Session")
 [(2)](#ref-for-dfn-capabilities-processing-2 "Reference 2")

[Permalink](#dfn-validate-capabilities)

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-dfn-validate-capabilities-1 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-validate-capabilities-2 "Reference 2")

[Permalink](#dfn-merging-capabilities)

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-dfn-merging-capabilities-1 "§ 7.2 Processing capabilities")
- [§ 8.2 New
 Session](#ref-for-dfn-merging-capabilities-2 "§ 8.2 New Session")

[Permalink](#dfn-matching-capabilities)

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-dfn-matching-capabilities-1 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-matching-capabilities-2 "Reference 2")
 [(3)](#ref-for-dfn-matching-capabilities-3 "Reference 3")

[Permalink](#dfn-sessions)

**Referenced in:**

- [§ 5. Nodes](#ref-for-dfn-sessions-1 "§ 5. Nodes")
- [§ 6.3 Processing
 model](#ref-for-dfn-sessions-2 "§ 6.3 Processing model")
 [(2)](#ref-for-dfn-sessions-3 "Reference 2")
- [§ 6.6 Errors](#ref-for-dfn-sessions-4 "§ 6.6 Errors")
 [(2)](#ref-for-dfn-sessions-5 "Reference 2")
 [(3)](#ref-for-dfn-sessions-6 "Reference 3")
- [§ 6.7 Extensions](#ref-for-dfn-sessions-7 "§ 6.7 Extensions")
- [§ 7. Capabilities](#ref-for-dfn-sessions-8 "§ 7. Capabilities")
 [(2)](#ref-for-dfn-sessions-9 "Reference 2")
 [(3)](#ref-for-dfn-sessions-10 "Reference 3")
 [(4)](#ref-for-dfn-sessions-11 "Reference 4")
 [(5)](#ref-for-dfn-sessions-12 "Reference 5")
 [(6)](#ref-for-dfn-sessions-13 "Reference 6")
- [§ 8. Sessions](#ref-for-dfn-sessions-14 "§ 8. Sessions")
 [(2)](#ref-for-dfn-sessions-15 "Reference 2")
 [(3)](#ref-for-dfn-sessions-16 "Reference 3")
 [(4)](#ref-for-dfn-sessions-17 "Reference 4")
 [(5)](#ref-for-dfn-sessions-18 "Reference 5")
 [(6)](#ref-for-dfn-sessions-19 "Reference 6")
 [(7)](#ref-for-dfn-sessions-20 "Reference 7")
 [(8)](#ref-for-dfn-sessions-21 "Reference 8")
- [§ 8.1 Global State](#ref-for-dfn-sessions-22 "§ 8.1 Global State")
 [(2)](#ref-for-dfn-sessions-23 "Reference 2")
 [(3)](#ref-for-dfn-sessions-24 "Reference 3")
 [(4)](#ref-for-dfn-sessions-25 "Reference 4")
- [§ 8.2 New Session](#ref-for-dfn-sessions-26 "§ 8.2 New Session")
 [(2)](#ref-for-dfn-sessions-27 "Reference 2")
- [§ 9.1 Get Timeouts](#ref-for-dfn-sessions-28 "§ 9.1 Get Timeouts")
- [§ 10. Navigation](#ref-for-dfn-sessions-29 "§ 10. Navigation")
- [§ 10.1 Navigate To](#ref-for-dfn-sessions-30 "§ 10.1 Navigate To")
 [(2)](#ref-for-dfn-sessions-31 "Reference 2")
 [(3)](#ref-for-dfn-sessions-32 "Reference 3")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-dfn-sessions-33 "§ 11.7 Switch To Parent Frame")
- [§ 12. Elements](#ref-for-dfn-sessions-34 "§ 12. Elements")
 [(2)](#ref-for-dfn-sessions-35 "Reference 2")
 [(3)](#ref-for-dfn-sessions-36 "Reference 3")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-sessions-37 "§ 12.5.3 Element Send Keys")
- [§ 15.8 Release
 Actions](#ref-for-dfn-sessions-38 "§ 15.8 Release Actions")
- [§ A. Privacy](#ref-for-dfn-sessions-39 "§ A. Privacy")
- [§ B. Security](#ref-for-dfn-sessions-40 "§ B. Security")

[Permalink](#dfn-associated-session)

**Referenced in:**

- [§ 8. Sessions](#ref-for-dfn-associated-session-1 "§ 8. Sessions")
- [§ 8.1 Global
 State](#ref-for-dfn-associated-session-2 "§ 8.1 Global State")
- [§ 8.2 New
 Session](#ref-for-dfn-associated-session-3 "§ 8.2 New Session")
 [(2)](#ref-for-dfn-associated-session-4 "Reference 2")

[Permalink](#dfn-session-id)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-session-id-1 "§ 6.3 Processing model")
- [§ 6.6 Errors](#ref-for-dfn-session-id-2 "§ 6.6 Errors")
 [(2)](#ref-for-dfn-session-id-3 "Reference 2")
- [§ 8.1 Global State](#ref-for-dfn-session-id-4 "§ 8.1 Global State")
- [§ 8.2 New Session](#ref-for-dfn-session-id-5 "§ 8.2 New Session")

[Permalink](#dfn-http-flag)

**Referenced in:**

- [§ 8. Sessions](#ref-for-dfn-http-flag-1 "§ 8. Sessions")
 [(2)](#ref-for-dfn-http-flag-2 "Reference 2")
- [§ 8.1 Global State](#ref-for-dfn-http-flag-3 "§ 8.1 Global State")
 [(2)](#ref-for-dfn-http-flag-4 "Reference 2")

[Permalink](#dfn-http-session)

**Referenced in:**

- [§ 8. Sessions](#ref-for-dfn-http-session-1 "§ 8. Sessions")
 [(2)](#ref-for-dfn-http-session-2 "Reference 2")
 [(3)](#ref-for-dfn-http-session-3 "Reference 3")
 [(4)](#ref-for-dfn-http-session-4 "Reference 4")
 [(5)](#ref-for-dfn-http-session-5 "Reference 5")
 [(6)](#ref-for-dfn-http-session-6 "Reference 6")
- [§ 16. User prompts](#ref-for-dfn-http-session-7 "§ 16. User prompts")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-http-session-8 "§ 16.1 User Prompt Handler")

[Permalink](#dfn-active-sessions)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-active-sessions-1 "§ 6.3 Processing model")
 [(2)](#ref-for-dfn-active-sessions-2 "Reference 2")
- [§ 6.6 Errors](#ref-for-dfn-active-sessions-3 "§ 6.6 Errors")
- [§ 8.1 Global
 State](#ref-for-dfn-active-sessions-4 "§ 8.1 Global State")
 [(2)](#ref-for-dfn-active-sessions-5 "Reference 2")
 [(3)](#ref-for-dfn-active-sessions-6 "Reference 3")
- [§ 16. User
 prompts](#ref-for-dfn-active-sessions-7 "§ 16. User prompts")

[Permalink](#dfn-active-http-sessions)

**Referenced in:**

- [§ 5. Nodes](#ref-for-dfn-active-http-sessions-1 "§ 5. Nodes")
- [§ 8. Sessions](#ref-for-dfn-active-http-sessions-2 "§ 8. Sessions")
- [§ 8.1 Global
 State](#ref-for-dfn-active-http-sessions-3 "§ 8.1 Global State")
 [(2)](#ref-for-dfn-active-http-sessions-4 "Reference 2")
- [§ 8.2 New
 Session](#ref-for-dfn-active-http-sessions-5 "§ 8.2 New Session")
- [§ 8.3 Delete
 Session](#ref-for-dfn-active-http-sessions-6 "§ 8.3 Delete Session")

[Permalink](#dfn-current-browsing-context)

**Referenced in:**

- [§ 6.6 Errors](#ref-for-dfn-current-browsing-context-1 "§ 6.6 Errors")
- [§ 8.
 Sessions](#ref-for-dfn-current-browsing-context-2 "§ 8. Sessions")
 [(2)](#ref-for-dfn-current-browsing-context-3 "Reference 2")
- [§ 10.
 Navigation](#ref-for-dfn-current-browsing-context-4 "§ 10. Navigation")
 [(2)](#ref-for-dfn-current-browsing-context-5 "Reference 2")
 [(3)](#ref-for-dfn-current-browsing-context-6 "Reference 3")
- [§ 10.3 Back](#ref-for-dfn-current-browsing-context-7 "§ 10.3 Back")
- [§ 10.4
 Forward](#ref-for-dfn-current-browsing-context-8 "§ 10.4 Forward")
- [§ 11.
 Contexts](#ref-for-dfn-current-browsing-context-9 "§ 11. Contexts")
 [(2)](#ref-for-dfn-current-browsing-context-10 "Reference 2")
- [§ 11.3 Switch To
 Window](#ref-for-dfn-current-browsing-context-11 "§ 11.3 Switch To Window")
- [§ 11.5 New
 Window](#ref-for-dfn-current-browsing-context-12 "§ 11.5 New Window")
 [(2)](#ref-for-dfn-current-browsing-context-13 "Reference 2")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-current-browsing-context-14 "§ 11.6 Switch To Frame")
 [(2)](#ref-for-dfn-current-browsing-context-15 "Reference 2")
 [(3)](#ref-for-dfn-current-browsing-context-16 "Reference 3")
 [(4)](#ref-for-dfn-current-browsing-context-17 "Reference 4")
 [(5)](#ref-for-dfn-current-browsing-context-18 "Reference 5")
 [(6)](#ref-for-dfn-current-browsing-context-19 "Reference 6")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-dfn-current-browsing-context-20 "§ 11.7 Switch To Parent Frame")
 [(2)](#ref-for-dfn-current-browsing-context-21 "Reference 2")
 [(3)](#ref-for-dfn-current-browsing-context-22 "Reference 3")
 [(4)](#ref-for-dfn-current-browsing-context-23 "Reference 4")
 [(5)](#ref-for-dfn-current-browsing-context-24 "Reference 5")
- [§ 12.
 Elements](#ref-for-dfn-current-browsing-context-25 "§ 12. Elements")
 [(2)](#ref-for-dfn-current-browsing-context-26 "Reference 2")
 [(3)](#ref-for-dfn-current-browsing-context-27 "Reference 3")
- [§ 12.1
 Interactability](#ref-for-dfn-current-browsing-context-28 "§ 12.1 Interactability")
- [§ 12.2 Shadow
 Roots](#ref-for-dfn-current-browsing-context-29 "§ 12.2 Shadow Roots")
 [(2)](#ref-for-dfn-current-browsing-context-30 "Reference 2")
 [(3)](#ref-for-dfn-current-browsing-context-31 "Reference 3")
- [§ 12.3.1 Locator
 strategies](#ref-for-dfn-current-browsing-context-32 "§ 12.3.1 Locator strategies")
- [§ 12.3.2 Find
 Element](#ref-for-dfn-current-browsing-context-33 "§ 12.3.2 Find Element")
 [(2)](#ref-for-dfn-current-browsing-context-34 "Reference 2")
 [(3)](#ref-for-dfn-current-browsing-context-35 "Reference 3")
- [§ 12.3.3 Find
 Elements](#ref-for-dfn-current-browsing-context-36 "§ 12.3.3 Find Elements")
 [(2)](#ref-for-dfn-current-browsing-context-37 "Reference 2")
- [§ 12.3.4 Find Element From
 Element](#ref-for-dfn-current-browsing-context-38 "§ 12.3.4 Find Element From Element")
- [§ 12.3.5 Find Elements From
 Element](#ref-for-dfn-current-browsing-context-39 "§ 12.3.5 Find Elements From Element")
- [§ 12.3.6 Find Element From Shadow
 Root](#ref-for-dfn-current-browsing-context-40 "§ 12.3.6 Find Element From Shadow Root")
- [§ 12.3.7 Find Elements From Shadow
 Root](#ref-for-dfn-current-browsing-context-41 "§ 12.3.7 Find Elements From Shadow Root")
- [§ 12.3.8 Get Active
 Element](#ref-for-dfn-current-browsing-context-42 "§ 12.3.8 Get Active Element")
 [(2)](#ref-for-dfn-current-browsing-context-43 "Reference 2")
- [§ 12.3.9 Get Element Shadow
 Root](#ref-for-dfn-current-browsing-context-44 "§ 12.3.9 Get Element Shadow Root")
- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-current-browsing-context-45 "§ 12.4.1 Is Element Selected")
- [§ 12.4.2 Get Element
 Attribute](#ref-for-dfn-current-browsing-context-46 "§ 12.4.2 Get Element Attribute")
- [§ 12.4.3 Get Element
 Property](#ref-for-dfn-current-browsing-context-47 "§ 12.4.3 Get Element Property")
- [§ 12.4.4 Get Element CSS
 Value](#ref-for-dfn-current-browsing-context-48 "§ 12.4.4 Get Element CSS Value")
 [(2)](#ref-for-dfn-current-browsing-context-49 "Reference 2")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-current-browsing-context-50 "§ 12.4.5 Get Element Text")
- [§ 12.4.6 Get Element Tag
 Name](#ref-for-dfn-current-browsing-context-51 "§ 12.4.6 Get Element Tag Name")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-current-browsing-context-52 "§ 12.4.7 Get Element Rect")
 [(2)](#ref-for-dfn-current-browsing-context-53 "Reference 2")
 [(3)](#ref-for-dfn-current-browsing-context-54 "Reference 3")
- [§ 12.4.8 Is Element
 Enabled](#ref-for-dfn-current-browsing-context-55 "§ 12.4.8 Is Element Enabled")
 [(2)](#ref-for-dfn-current-browsing-context-56 "Reference 2")
- [§ 12.4.9 Get Computed
 Role](#ref-for-dfn-current-browsing-context-57 "§ 12.4.9 Get Computed Role")
- [§ 12.4.10 Get Computed
 Label](#ref-for-dfn-current-browsing-context-58 "§ 12.4.10 Get Computed Label")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-current-browsing-context-59 "§ 12.5.1 Element Click")
 [(2)](#ref-for-dfn-current-browsing-context-60 "Reference 2")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-current-browsing-context-61 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-current-browsing-context-62 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-current-browsing-context-63 "Reference 2")
- [§ 13.1 Get Page
 Source](#ref-for-dfn-current-browsing-context-64 "§ 13.1 Get Page Source")
 [(2)](#ref-for-dfn-current-browsing-context-65 "Reference 2")
 [(3)](#ref-for-dfn-current-browsing-context-66 "Reference 3")
- [§ 13.2 Executing
 Script](#ref-for-dfn-current-browsing-context-67 "§ 13.2 Executing Script")
- [§ 13.2.1 Execute
 Script](#ref-for-dfn-current-browsing-context-68 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-current-browsing-context-69 "§ 13.2.2 Execute Async Script")
- [§ 14.
 Cookies](#ref-for-dfn-current-browsing-context-70 "§ 14. Cookies")
 [(2)](#ref-for-dfn-current-browsing-context-71 "Reference 2")
- [§ 14.1 Get All
 Cookies](#ref-for-dfn-current-browsing-context-72 "§ 14.1 Get All Cookies")
 [(2)](#ref-for-dfn-current-browsing-context-73 "Reference 2")
- [§ 14.2 Get Named
 Cookie](#ref-for-dfn-current-browsing-context-74 "§ 14.2 Get Named Cookie")
 [(2)](#ref-for-dfn-current-browsing-context-75 "Reference 2")
- [§ 14.3 Add
 Cookie](#ref-for-dfn-current-browsing-context-76 "§ 14.3 Add Cookie")
 [(2)](#ref-for-dfn-current-browsing-context-77 "Reference 2")
 [(3)](#ref-for-dfn-current-browsing-context-78 "Reference 3")
 [(4)](#ref-for-dfn-current-browsing-context-79 "Reference 4")
- [§ 14.4 Delete
 Cookie](#ref-for-dfn-current-browsing-context-80 "§ 14.4 Delete Cookie")
- [§ 14.5 Delete All
 Cookies](#ref-for-dfn-current-browsing-context-81 "§ 14.5 Delete All Cookies")
- [§ 15.1 Actions
 Options](#ref-for-dfn-current-browsing-context-82 "§ 15.1 Actions Options")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-current-browsing-context-83 "§ 15.7 Perform Actions")
 [(2)](#ref-for-dfn-current-browsing-context-84 "Reference 2")
- [§ 15.8 Release
 Actions](#ref-for-dfn-current-browsing-context-85 "§ 15.8 Release Actions")
 [(2)](#ref-for-dfn-current-browsing-context-86 "Reference 2")
- [§ 16. User
 prompts](#ref-for-dfn-current-browsing-context-87 "§ 16. User prompts")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-current-browsing-context-88 "§ 16.1 User Prompt Handler")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-current-browsing-context-89 "§ 17.2 Take Element Screenshot")
- [§ 18.1 Print
 Page](#ref-for-dfn-current-browsing-context-90 "§ 18.1 Print Page")

[Permalink](#dfn-current-parent-browsing-context)

**Referenced in:**

- [§ 11.
 Contexts](#ref-for-dfn-current-parent-browsing-context-1 "§ 11. Contexts")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-dfn-current-parent-browsing-context-2 "§ 11.7 Switch To Parent Frame")
 [(2)](#ref-for-dfn-current-parent-browsing-context-3 "Reference 2")
 [(3)](#ref-for-dfn-current-parent-browsing-context-4 "Reference 3")

[Permalink](#dfn-current-top-level-browsing-context)

**Referenced in:**

- [§ 8.2 New
 Session](#ref-for-dfn-current-top-level-browsing-context-1 "§ 8.2 New Session")
- [§ 10.
 Navigation](#ref-for-dfn-current-top-level-browsing-context-2 "§ 10. Navigation")
- [§ 10.1 Navigate
 To](#ref-for-dfn-current-top-level-browsing-context-3 "§ 10.1 Navigate To")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-4 "Reference 2")
 [(3)](#ref-for-dfn-current-top-level-browsing-context-5 "Reference 3")
 [(4)](#ref-for-dfn-current-top-level-browsing-context-6 "Reference 4")
 [(5)](#ref-for-dfn-current-top-level-browsing-context-7 "Reference 5")
 [(6)](#ref-for-dfn-current-top-level-browsing-context-8 "Reference 6")
 [(7)](#ref-for-dfn-current-top-level-browsing-context-9 "Reference 7")
 [(8)](#ref-for-dfn-current-top-level-browsing-context-10 "Reference 8")
 [(9)](#ref-for-dfn-current-top-level-browsing-context-11 "Reference 9")
 [(10)](#ref-for-dfn-current-top-level-browsing-context-12 "Reference 10")
- [§ 10.2 Get Current
 URL](#ref-for-dfn-current-top-level-browsing-context-13 "§ 10.2 Get Current URL")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-14 "Reference 2")
- [§ 10.3
 Back](#ref-for-dfn-current-top-level-browsing-context-15 "§ 10.3 Back")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-16 "Reference 2")
- [§ 10.4
 Forward](#ref-for-dfn-current-top-level-browsing-context-17 "§ 10.4 Forward")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-18 "Reference 2")
- [§ 10.5
 Refresh](#ref-for-dfn-current-top-level-browsing-context-19 "§ 10.5 Refresh")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-20 "Reference 2")
 [(3)](#ref-for-dfn-current-top-level-browsing-context-21 "Reference 3")
 [(4)](#ref-for-dfn-current-top-level-browsing-context-22 "Reference 4")
- [§ 10.6 Get
 Title](#ref-for-dfn-current-top-level-browsing-context-23 "§ 10.6 Get Title")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-24 "Reference 2")
 [(3)](#ref-for-dfn-current-top-level-browsing-context-25 "Reference 3")
- [§ 11.
 Contexts](#ref-for-dfn-current-top-level-browsing-context-26 "§ 11. Contexts")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-27 "Reference 2")
 [(3)](#ref-for-dfn-current-top-level-browsing-context-28 "Reference 3")
- [§ 11.1 Get Window
 Handle](#ref-for-dfn-current-top-level-browsing-context-29 "§ 11.1 Get Window Handle")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-30 "Reference 2")
- [§ 11.2 Close
 Window](#ref-for-dfn-current-top-level-browsing-context-31 "§ 11.2 Close Window")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-32 "Reference 2")
- [§ 11.3 Switch To
 Window](#ref-for-dfn-current-top-level-browsing-context-33 "§ 11.3 Switch To Window")
- [§ 11.5 New
 Window](#ref-for-dfn-current-top-level-browsing-context-34 "§ 11.5 New Window")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-current-top-level-browsing-context-35 "§ 11.6 Switch To Frame")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-36 "Reference 2")
 [(3)](#ref-for-dfn-current-top-level-browsing-context-37 "Reference 3")
- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-current-top-level-browsing-context-38 "§ 11.8 Resizing and positioning windows")
- [§ 11.8.1 Get Window
 Rect](#ref-for-dfn-current-top-level-browsing-context-39 "§ 11.8.1 Get Window Rect")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-40 "Reference 2")
 [(3)](#ref-for-dfn-current-top-level-browsing-context-41 "Reference 3")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-current-top-level-browsing-context-42 "§ 11.8.2 Set Window Rect")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-43 "Reference 2")
 [(3)](#ref-for-dfn-current-top-level-browsing-context-44 "Reference 3")
 [(4)](#ref-for-dfn-current-top-level-browsing-context-45 "Reference 4")
 [(5)](#ref-for-dfn-current-top-level-browsing-context-46 "Reference 5")
 [(6)](#ref-for-dfn-current-top-level-browsing-context-47 "Reference 6")
 [(7)](#ref-for-dfn-current-top-level-browsing-context-48 "Reference 7")
- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-current-top-level-browsing-context-49 "§ 11.8.3 Maximize Window")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-50 "Reference 2")
 [(3)](#ref-for-dfn-current-top-level-browsing-context-51 "Reference 3")
 [(4)](#ref-for-dfn-current-top-level-browsing-context-52 "Reference 4")
 [(5)](#ref-for-dfn-current-top-level-browsing-context-53 "Reference 5")
- [§ 11.8.4 Minimize
 Window](#ref-for-dfn-current-top-level-browsing-context-54 "§ 11.8.4 Minimize Window")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-55 "Reference 2")
 [(3)](#ref-for-dfn-current-top-level-browsing-context-56 "Reference 3")
 [(4)](#ref-for-dfn-current-top-level-browsing-context-57 "Reference 4")
- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-current-top-level-browsing-context-58 "§ 11.8.5 Fullscreen Window")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-59 "Reference 2")
 [(3)](#ref-for-dfn-current-top-level-browsing-context-60 "Reference 3")
- [§ 12.4
 State](#ref-for-dfn-current-top-level-browsing-context-61 "§ 12.4 State")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-current-top-level-browsing-context-62 "§ 12.5.1 Element Click")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-current-top-level-browsing-context-63 "§ 12.5.3 Element Send Keys")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-current-top-level-browsing-context-64 "§ 15.7 Perform Actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-current-top-level-browsing-context-65 "§ 15.8 Release Actions")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-66 "Reference 2")
- [§ 16. User
 prompts](#ref-for-dfn-current-top-level-browsing-context-67 "§ 16. User prompts")
- [§ 16.2 Dismiss
 Alert](#ref-for-dfn-current-top-level-browsing-context-68 "§ 16.2 Dismiss Alert")
- [§ 16.3 Accept
 Alert](#ref-for-dfn-current-top-level-browsing-context-69 "§ 16.3 Accept Alert")
- [§ 16.4 Get Alert
 Text](#ref-for-dfn-current-top-level-browsing-context-70 "§ 16.4 Get Alert Text")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-current-top-level-browsing-context-71 "§ 16.5 Send Alert Text")
- [§ 17.1 Take
 Screenshot](#ref-for-dfn-current-top-level-browsing-context-72 "§ 17.1 Take Screenshot")
 [(2)](#ref-for-dfn-current-top-level-browsing-context-73 "Reference 2")
- [§ 18.1 Print
 Page](#ref-for-dfn-current-top-level-browsing-context-74 "§ 18.1 Print Page")

[Permalink](#dfn-session-timeouts)

**Referenced in:**

- [§ 7.
 Capabilities](#ref-for-dfn-session-timeouts-1 "§ 7. Capabilities")
- [§ 8.1 Global
 State](#ref-for-dfn-session-timeouts-2 "§ 8.1 Global State")
 [(2)](#ref-for-dfn-session-timeouts-3 "Reference 2")
- [§ 10. Navigation](#ref-for-dfn-session-timeouts-4 "§ 10. Navigation")
- [§ 10.1 Navigate
 To](#ref-for-dfn-session-timeouts-5 "§ 10.1 Navigate To")
- [§ 10.3 Back](#ref-for-dfn-session-timeouts-6 "§ 10.3 Back")
- [§ 10.4 Forward](#ref-for-dfn-session-timeouts-7 "§ 10.4 Forward")
- [§ 12.3 Retrieval](#ref-for-dfn-session-timeouts-8 "§ 12.3 Retrieval")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-session-timeouts-9 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-session-timeouts-10 "§ 12.5.3 Element Send Keys")
- [§ 13.2.1 Execute
 Script](#ref-for-dfn-session-timeouts-11 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-session-timeouts-12 "§ 13.2.2 Execute Async Script")

[Permalink](#dfn-page-loading-strategy)

**Referenced in:**

- [§ 8.1 Global
 State](#ref-for-dfn-page-loading-strategy-1 "§ 8.1 Global State")
 [(2)](#ref-for-dfn-page-loading-strategy-2 "Reference 2")
- [§ 10.
 Navigation](#ref-for-dfn-page-loading-strategy-3 "§ 10. Navigation")
 [(2)](#ref-for-dfn-page-loading-strategy-4 "Reference 2")
 [(3)](#ref-for-dfn-page-loading-strategy-5 "Reference 3")
 [(4)](#ref-for-dfn-page-loading-strategy-6 "Reference 4")

[Permalink](#dfn-strict-file-interactability)

**Referenced in:**

- [§ 7.
 Capabilities](#ref-for-dfn-strict-file-interactability-1 "§ 7. Capabilities")
 [(2)](#ref-for-dfn-strict-file-interactability-2 "Reference 2")
- [§ 8.1 Global
 State](#ref-for-dfn-strict-file-interactability-3 "§ 8.1 Global State")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-strict-file-interactability-4 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-browsing-context-input-state-map)

**Referenced in:**

- [§ 15.3 Input
 state](#ref-for-dfn-browsing-context-input-state-map-1 "§ 15.3 Input state")
 [(2)](#ref-for-dfn-browsing-context-input-state-map-2 "Reference 2")

[Permalink](#dfn-request-queue)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-request-queue-1 "§ 6.3 Processing model")
- [§ 8.2 New Session](#ref-for-dfn-request-queue-2 "§ 8.2 New Session")

[Permalink](#dfn-session-configuration-flags)

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-dfn-session-configuration-flags-1 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-session-configuration-flags-2 "Reference 2")
- [§ 8.
 Sessions](#ref-for-dfn-session-configuration-flags-3 "§ 8. Sessions")
- [§ 8.1 Global
 State](#ref-for-dfn-session-configuration-flags-4 "§ 8.1 Global State")

[Permalink](#dfn-accept-insecure-tls)

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-dfn-accept-insecure-tls-1 "§ 7.2 Processing capabilities")
- [§ 8.1 Global
 State](#ref-for-dfn-accept-insecure-tls-2 "§ 8.1 Global State")
 [(2)](#ref-for-dfn-accept-insecure-tls-3 "Reference 2")
- [§ 10.
 Navigation](#ref-for-dfn-accept-insecure-tls-4 "§ 10. Navigation")
- [§ 10.1 Navigate
 To](#ref-for-dfn-accept-insecure-tls-5 "§ 10.1 Navigate To")

[Permalink](#dfn-has-proxy-configuration)

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-dfn-has-proxy-configuration-1 "§ 7.2 Processing capabilities")
- [§ 8.1 Global
 State](#ref-for-dfn-has-proxy-configuration-2 "§ 8.1 Global State")
 [(2)](#ref-for-dfn-has-proxy-configuration-3 "Reference 2")

[Permalink](#dfn-create-a-session)

**Referenced in:**

- [§ 8.2 New
 Session](#ref-for-dfn-create-a-session-1 "§ 8.2 New Session")

[Permalink](#dfn-close-the-session)

**Referenced in:**

- [§ 8. Sessions](#ref-for-dfn-close-the-session-1 "§ 8. Sessions")
- [§ 8.3 Delete
 Session](#ref-for-dfn-close-the-session-2 "§ 8.3 Delete Session")
- [§ 11.2 Close
 Window](#ref-for-dfn-close-the-session-3 "§ 11.2 Close Window")

[Permalink](#dfn-new-sessions)

**Referenced in:**

- [§ 5. Nodes](#ref-for-dfn-new-sessions-1 "§ 5. Nodes")
- [§ 6.3 Processing
 model](#ref-for-dfn-new-sessions-2 "§ 6.3 Processing model")
- [§ 6.4 Routing
 requests](#ref-for-dfn-new-sessions-3 "§ 6.4 Routing requests")
- [§ 6.5 Endpoints](#ref-for-dfn-new-sessions-4 "§ 6.5 Endpoints")
- [§ 6.7 Extensions](#ref-for-dfn-new-sessions-5 "§ 6.7 Extensions")
 [(2)](#ref-for-dfn-new-sessions-6 "Reference 2")
- [§ 7. Capabilities](#ref-for-dfn-new-sessions-7 "§ 7. Capabilities")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-new-sessions-8 "§ 7.2 Processing capabilities")
- [§ 8. Sessions](#ref-for-dfn-new-sessions-9 "§ 8. Sessions")
- [§ 8.2 New Session](#ref-for-dfn-new-sessions-10 "§ 8.2 New Session")
 [(2)](#ref-for-dfn-new-sessions-11 "Reference 2")
 [(3)](#ref-for-dfn-new-sessions-12 "Reference 3")
 [(4)](#ref-for-dfn-new-sessions-13 "Reference 4")
 [(5)](#ref-for-dfn-new-sessions-14 "Reference 5")
- [§ 8.4 Status](#ref-for-dfn-new-sessions-15 "§ 8.4 Status")
 [(2)](#ref-for-dfn-new-sessions-16 "Reference 2")
 [(3)](#ref-for-dfn-new-sessions-17 "Reference 3")
- [§ A. Privacy](#ref-for-dfn-new-sessions-18 "§ A. Privacy")

[Permalink](#dfn-delete-session)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-delete-session-1 "§ 6.5 Endpoints")

[Permalink](#dfn-status)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-status-1 "§ 6.3 Processing model")
- [§ 6.5 Endpoints](#ref-for-dfn-status-2 "§ 6.5 Endpoints")
- [§ 8.4 Status](#ref-for-dfn-status-3 "§ 8.4 Status")

[Permalink](#dfn-timer)

**Referenced in:**

- [§ 10. Navigation](#ref-for-dfn-timer-1 "§ 10. Navigation")
- [§ 10.1 Navigate To](#ref-for-dfn-timer-2 "§ 10.1 Navigate To")
- [§ 10.3 Back](#ref-for-dfn-timer-3 "§ 10.3 Back")
- [§ 10.4 Forward](#ref-for-dfn-timer-4 "§ 10.4 Forward")
- [§ 12.3 Retrieval](#ref-for-dfn-timer-5 "§ 12.3 Retrieval")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-timer-6 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-timer-7 "§ 12.5.3 Element Send Keys")
- [§ 13.2.1 Execute
 Script](#ref-for-dfn-timer-8 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-timer-9 "§ 13.2.2 Execute Async Script")

[Permalink](#dfn-timeout-fired-flag)

**Referenced in:**

- [§ 9. Timeouts](#ref-for-dfn-timeout-fired-flag-1 "§ 9. Timeouts")
- [§ 10.
 Navigation](#ref-for-dfn-timeout-fired-flag-2 "§ 10. Navigation")
- [§ 10.1 Navigate
 To](#ref-for-dfn-timeout-fired-flag-3 "§ 10.1 Navigate To")
- [§ 10.3 Back](#ref-for-dfn-timeout-fired-flag-4 "§ 10.3 Back")
 [(2)](#ref-for-dfn-timeout-fired-flag-5 "Reference 2")
- [§ 10.4 Forward](#ref-for-dfn-timeout-fired-flag-6 "§ 10.4 Forward")
 [(2)](#ref-for-dfn-timeout-fired-flag-7 "Reference 2")
- [§ 12.3
 Retrieval](#ref-for-dfn-timeout-fired-flag-8 "§ 12.3 Retrieval")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-timeout-fired-flag-9 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-timeout-fired-flag-10 "§ 12.5.3 Element Send Keys")
- [§ 13.2.1 Execute
 Script](#ref-for-dfn-timeout-fired-flag-11 "§ 13.2.1 Execute Script")
 [(2)](#ref-for-dfn-timeout-fired-flag-12 "Reference 2")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-timeout-fired-flag-13 "§ 13.2.2 Execute Async Script")
 [(2)](#ref-for-dfn-timeout-fired-flag-14 "Reference 2")

[Permalink](#dfn-start-the-timer)

**Referenced in:**

- [§ 10. Navigation](#ref-for-dfn-start-the-timer-1 "§ 10. Navigation")
- [§ 10.1 Navigate
 To](#ref-for-dfn-start-the-timer-2 "§ 10.1 Navigate To")
- [§ 10.3 Back](#ref-for-dfn-start-the-timer-3 "§ 10.3 Back")
- [§ 10.4 Forward](#ref-for-dfn-start-the-timer-4 "§ 10.4 Forward")
- [§ 12.3 Retrieval](#ref-for-dfn-start-the-timer-5 "§ 12.3 Retrieval")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-start-the-timer-6 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-start-the-timer-7 "§ 12.5.3 Element Send Keys")
- [§ 13.2.1 Execute
 Script](#ref-for-dfn-start-the-timer-8 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-start-the-timer-9 "§ 13.2.2 Execute Async Script")

[Permalink](#dfn-timeouts-configuration)

**Referenced in:**

- [§ 8. Sessions](#ref-for-dfn-timeouts-configuration-1 "§ 8. Sessions")
 [(2)](#ref-for-dfn-timeouts-configuration-2 "Reference 2")
- [§ 9. Timeouts](#ref-for-dfn-timeouts-configuration-3 "§ 9. Timeouts")
- [§ 9.1 Get
 Timeouts](#ref-for-dfn-timeouts-configuration-4 "§ 9.1 Get Timeouts")
- [§ 9.2 Set
 Timeouts](#ref-for-dfn-timeouts-configuration-5 "§ 9.2 Set Timeouts")

[Permalink](#dfn-script-timeout)

**Referenced in:**

- [§ 9. Timeouts](#ref-for-dfn-script-timeout-1 "§ 9. Timeouts")
 [(2)](#ref-for-dfn-script-timeout-2 "Reference 2")
- [§ 13.2.1 Execute
 Script](#ref-for-dfn-script-timeout-3 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-script-timeout-4 "§ 13.2.2 Execute Async Script")

[Permalink](#dfn-page-load-timeout)

**Referenced in:**

- [§ 9. Timeouts](#ref-for-dfn-page-load-timeout-1 "§ 9. Timeouts")
 [(2)](#ref-for-dfn-page-load-timeout-2 "Reference 2")
- [§ 10.
 Navigation](#ref-for-dfn-page-load-timeout-3 "§ 10. Navigation")
 [(2)](#ref-for-dfn-page-load-timeout-4 "Reference 2")
- [§ 10.1 Navigate
 To](#ref-for-dfn-page-load-timeout-5 "§ 10.1 Navigate To")
- [§ 10.3 Back](#ref-for-dfn-page-load-timeout-6 "§ 10.3 Back")
- [§ 10.4 Forward](#ref-for-dfn-page-load-timeout-7 "§ 10.4 Forward")

[Permalink](#dfn-implicit-wait-timeout)

**Referenced in:**

- [§ 9. Timeouts](#ref-for-dfn-implicit-wait-timeout-1 "§ 9. Timeouts")
 [(2)](#ref-for-dfn-implicit-wait-timeout-2 "Reference 2")
- [§ 12.3
 Retrieval](#ref-for-dfn-implicit-wait-timeout-3 "§ 12.3 Retrieval")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-implicit-wait-timeout-4 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-implicit-wait-timeout-5 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-deserialize-as-timeouts-configuration)

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-dfn-deserialize-as-timeouts-configuration-1 "§ 7.2 Processing capabilities")
- [§ 9.2 Set
 Timeouts](#ref-for-dfn-deserialize-as-timeouts-configuration-2 "§ 9.2 Set Timeouts")

[Permalink](#dfn-serialize-the-timeouts-configuration)

**Referenced in:**

- [§ 8.1 Global
 State](#ref-for-dfn-serialize-the-timeouts-configuration-1 "§ 8.1 Global State")
- [§ 9.1 Get
 Timeouts](#ref-for-dfn-serialize-the-timeouts-configuration-2 "§ 9.1 Get Timeouts")

[Permalink](#dfn-get-timeouts)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-get-timeouts-1 "§ 6.5 Endpoints")

[Permalink](#dfn-set-timeouts)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-set-timeouts-1 "§ 6.5 Endpoints")

[Permalink](#dfn-table-of-page-load-strategies)

**Referenced in:**

- [§ 8.
 Sessions](#ref-for-dfn-table-of-page-load-strategies-1 "§ 8. Sessions")
- [§ 10.
 Navigation](#ref-for-dfn-table-of-page-load-strategies-2 "§ 10. Navigation")
 [(2)](#ref-for-dfn-table-of-page-load-strategies-3 "Reference 2")

[Permalink](#dfn-none-page-loading-strategy)

**Referenced in:**

- [§ 10.
 Navigation](#ref-for-dfn-none-page-loading-strategy-1 "§ 10. Navigation")
 [(2)](#ref-for-dfn-none-page-loading-strategy-2 "Reference 2")

[Permalink](#dfn-eager-page-loading-strategy)

**Referenced in:**

- [§ 10.
 Navigation](#ref-for-dfn-eager-page-loading-strategy-1 "§ 10. Navigation")

[Permalink](#dfn-normal-page-loading-strategy)

**Referenced in:**

- [§ 8.
 Sessions](#ref-for-dfn-normal-page-loading-strategy-1 "§ 8. Sessions")
- [§ 10.
 Navigation](#ref-for-dfn-normal-page-loading-strategy-2 "§ 10. Navigation")

[Permalink](#dfn-deserialize-as-a-page-load-strategy)

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-dfn-deserialize-as-a-page-load-strategy-1 "§ 7.2 Processing capabilities")

[Permalink](#dfn-wait-for-navigation-to-complete)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-wait-for-navigation-to-complete-1 "§ 6.3 Processing model")
- [§ 10.1 Navigate
 To](#ref-for-dfn-wait-for-navigation-to-complete-2 "§ 10.1 Navigate To")
 [(2)](#ref-for-dfn-wait-for-navigation-to-complete-3 "Reference 2")
- [§ 10.5
 Refresh](#ref-for-dfn-wait-for-navigation-to-complete-4 "§ 10.5 Refresh")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-wait-for-navigation-to-complete-5 "§ 12.5.1 Element Click")

[Permalink](#dfn-post-navigation-checks)

**Referenced in:**

- [§ 10.1 Navigate
 To](#ref-for-dfn-post-navigation-checks-1 "§ 10.1 Navigate To")
 [(2)](#ref-for-dfn-post-navigation-checks-2 "Reference 2")
- [§ 10.5
 Refresh](#ref-for-dfn-post-navigation-checks-3 "§ 10.5 Refresh")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-post-navigation-checks-4 "§ 12.5.1 Element Click")

[Permalink](#dfn-navigate-to)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-navigate-to-1 "§ 6.5 Endpoints")

[Permalink](#dfn-get-current-url)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-get-current-url-1 "§ 6.5 Endpoints")

[Permalink](#dfn-back)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-back-1 "§ 6.5 Endpoints")

[Permalink](#dfn-forward)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-forward-1 "§ 6.5 Endpoints")

[Permalink](#dfn-refresh)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-refresh-1 "§ 6.5 Endpoints")

[Permalink](#dfn-get-title)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-get-title-1 "§ 6.5 Endpoints")

[Permalink](#dfn-no-longer-open)

**Referenced in:**

- [§ 10. Navigation](#ref-for-dfn-no-longer-open-1 "§ 10. Navigation")
- [§ 10.1 Navigate
 To](#ref-for-dfn-no-longer-open-2 "§ 10.1 Navigate To")
- [§ 10.2 Get Current
 URL](#ref-for-dfn-no-longer-open-3 "§ 10.2 Get Current URL")
- [§ 10.3 Back](#ref-for-dfn-no-longer-open-4 "§ 10.3 Back")
- [§ 10.4 Forward](#ref-for-dfn-no-longer-open-5 "§ 10.4 Forward")
- [§ 10.5 Refresh](#ref-for-dfn-no-longer-open-6 "§ 10.5 Refresh")
- [§ 10.6 Get Title](#ref-for-dfn-no-longer-open-7 "§ 10.6 Get Title")
- [§ 11.1 Get Window
 Handle](#ref-for-dfn-no-longer-open-8 "§ 11.1 Get Window Handle")
- [§ 11.2 Close
 Window](#ref-for-dfn-no-longer-open-9 "§ 11.2 Close Window")
- [§ 11.5 New
 Window](#ref-for-dfn-no-longer-open-10 "§ 11.5 New Window")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-no-longer-open-11 "§ 11.6 Switch To Frame")
 [(2)](#ref-for-dfn-no-longer-open-12 "Reference 2")
 [(3)](#ref-for-dfn-no-longer-open-13 "Reference 3")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-dfn-no-longer-open-14 "§ 11.7 Switch To Parent Frame")
 [(2)](#ref-for-dfn-no-longer-open-15 "Reference 2")
- [§ 11.8.1 Get Window
 Rect](#ref-for-dfn-no-longer-open-16 "§ 11.8.1 Get Window Rect")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-no-longer-open-17 "§ 11.8.2 Set Window Rect")
- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-no-longer-open-18 "§ 11.8.3 Maximize Window")
- [§ 11.8.4 Minimize
 Window](#ref-for-dfn-no-longer-open-19 "§ 11.8.4 Minimize Window")
- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-no-longer-open-20 "§ 11.8.5 Fullscreen Window")
- [§ 12.3.2 Find
 Element](#ref-for-dfn-no-longer-open-21 "§ 12.3.2 Find Element")
- [§ 12.3.3 Find
 Elements](#ref-for-dfn-no-longer-open-22 "§ 12.3.3 Find Elements")
- [§ 12.3.4 Find Element From
 Element](#ref-for-dfn-no-longer-open-23 "§ 12.3.4 Find Element From Element")
- [§ 12.3.5 Find Elements From
 Element](#ref-for-dfn-no-longer-open-24 "§ 12.3.5 Find Elements From Element")
- [§ 12.3.6 Find Element From Shadow
 Root](#ref-for-dfn-no-longer-open-25 "§ 12.3.6 Find Element From Shadow Root")
- [§ 12.3.7 Find Elements From Shadow
 Root](#ref-for-dfn-no-longer-open-26 "§ 12.3.7 Find Elements From Shadow Root")
- [§ 12.3.8 Get Active
 Element](#ref-for-dfn-no-longer-open-27 "§ 12.3.8 Get Active Element")
- [§ 12.3.9 Get Element Shadow
 Root](#ref-for-dfn-no-longer-open-28 "§ 12.3.9 Get Element Shadow Root")
- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-no-longer-open-29 "§ 12.4.1 Is Element Selected")
- [§ 12.4.2 Get Element
 Attribute](#ref-for-dfn-no-longer-open-30 "§ 12.4.2 Get Element Attribute")
- [§ 12.4.3 Get Element
 Property](#ref-for-dfn-no-longer-open-31 "§ 12.4.3 Get Element Property")
- [§ 12.4.4 Get Element CSS
 Value](#ref-for-dfn-no-longer-open-32 "§ 12.4.4 Get Element CSS Value")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-no-longer-open-33 "§ 12.4.5 Get Element Text")
- [§ 12.4.6 Get Element Tag
 Name](#ref-for-dfn-no-longer-open-34 "§ 12.4.6 Get Element Tag Name")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-no-longer-open-35 "§ 12.4.7 Get Element Rect")
- [§ 12.4.8 Is Element
 Enabled](#ref-for-dfn-no-longer-open-36 "§ 12.4.8 Is Element Enabled")
- [§ 12.4.9 Get Computed
 Role](#ref-for-dfn-no-longer-open-37 "§ 12.4.9 Get Computed Role")
- [§ 12.4.10 Get Computed
 Label](#ref-for-dfn-no-longer-open-38 "§ 12.4.10 Get Computed Label")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-no-longer-open-39 "§ 12.5.1 Element Click")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-no-longer-open-40 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-no-longer-open-41 "§ 12.5.3 Element Send Keys")
- [§ 13.1 Get Page
 Source](#ref-for-dfn-no-longer-open-42 "§ 13.1 Get Page Source")
- [§ 13.2.1 Execute
 Script](#ref-for-dfn-no-longer-open-43 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-no-longer-open-44 "§ 13.2.2 Execute Async Script")
- [§ 14.1 Get All
 Cookies](#ref-for-dfn-no-longer-open-45 "§ 14.1 Get All Cookies")
- [§ 14.2 Get Named
 Cookie](#ref-for-dfn-no-longer-open-46 "§ 14.2 Get Named Cookie")
- [§ 14.3 Add
 Cookie](#ref-for-dfn-no-longer-open-47 "§ 14.3 Add Cookie")
- [§ 14.4 Delete
 Cookie](#ref-for-dfn-no-longer-open-48 "§ 14.4 Delete Cookie")
- [§ 14.5 Delete All
 Cookies](#ref-for-dfn-no-longer-open-49 "§ 14.5 Delete All Cookies")
- [§ 15.6 Dispatching
 actions](#ref-for-dfn-no-longer-open-50 "§ 15.6 Dispatching actions")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-no-longer-open-51 "§ 15.7 Perform Actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-no-longer-open-52 "§ 15.8 Release Actions")
- [§ 16.2 Dismiss
 Alert](#ref-for-dfn-no-longer-open-53 "§ 16.2 Dismiss Alert")
- [§ 16.3 Accept
 Alert](#ref-for-dfn-no-longer-open-54 "§ 16.3 Accept Alert")
- [§ 16.4 Get Alert
 Text](#ref-for-dfn-no-longer-open-55 "§ 16.4 Get Alert Text")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-no-longer-open-56 "§ 16.5 Send Alert Text")
- [§ 17.1 Take
 Screenshot](#ref-for-dfn-no-longer-open-57 "§ 17.1 Take Screenshot")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-no-longer-open-58 "§ 17.2 Take Element Screenshot")
- [§ 18.1 Print
 Page](#ref-for-dfn-no-longer-open-59 "§ 18.1 Print Page")

[Permalink](#dfn-window-handles)

**Referenced in:**

- [§ 11. Contexts](#ref-for-dfn-window-handles-1 "§ 11. Contexts")
 [(2)](#ref-for-dfn-window-handles-2 "Reference 2")
 [(3)](#ref-for-dfn-window-handles-3 "Reference 3")
 [(4)](#ref-for-dfn-window-handles-4 "Reference 4")
- [§ 11.1 Get Window
 Handle](#ref-for-dfn-window-handles-5 "§ 11.1 Get Window Handle")
- [§ 11.3 Switch To
 Window](#ref-for-dfn-window-handles-6 "§ 11.3 Switch To Window")
- [§ 11.4 Get Window
 Handles](#ref-for-dfn-window-handles-7 "§ 11.4 Get Window Handles")
- [§ 11.5 New Window](#ref-for-dfn-window-handles-8 "§ 11.5 New Window")

[Permalink](#dfn-web-frames)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-web-frames-1 "§ 13.2 Executing Script")

[Permalink](#dfn-web-frame-identifier)

**Referenced in:**

- [§ 11. Contexts](#ref-for-dfn-web-frame-identifier-1 "§ 11. Contexts")
 [(2)](#ref-for-dfn-web-frame-identifier-2 "Reference 2")
 [(3)](#ref-for-dfn-web-frame-identifier-3 "Reference 3")
 [(4)](#ref-for-dfn-web-frame-identifier-4 "Reference 4")

[Permalink](#dfn-represents-a-web-frame)

**Referenced in:**

- [§ 11.
 Contexts](#ref-for-dfn-represents-a-web-frame-1 "§ 11. Contexts")
- [§ 13.2 Executing
 Script](#ref-for-dfn-represents-a-web-frame-2 "§ 13.2 Executing Script")

[Permalink](#dfn-web-windows)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-web-windows-1 "§ 13.2 Executing Script")

[Permalink](#dfn-web-window-identifier)

**Referenced in:**

- [§ 11.
 Contexts](#ref-for-dfn-web-window-identifier-1 "§ 11. Contexts")
 [(2)](#ref-for-dfn-web-window-identifier-2 "Reference 2")
 [(3)](#ref-for-dfn-web-window-identifier-3 "Reference 3")
 [(4)](#ref-for-dfn-web-window-identifier-4 "Reference 4")

[Permalink](#dfn-represents-a-web-window)

**Referenced in:**

- [§ 11.
 Contexts](#ref-for-dfn-represents-a-web-window-1 "§ 11. Contexts")
- [§ 13.2 Executing
 Script](#ref-for-dfn-represents-a-web-window-2 "§ 13.2 Executing Script")

[Permalink](#dfn-windowproxy-reference-object)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-windowproxy-reference-object-1 "§ 13.2 Executing Script")

[Permalink](#dfn-deserialize-a-web-frame)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-deserialize-a-web-frame-1 "§ 13.2 Executing Script")

[Permalink](#dfn-deserialize-a-web-window)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-deserialize-a-web-window-1 "§ 13.2 Executing Script")

[Permalink](#dfn-set-the-current-browsing-context)

**Referenced in:**

- [§ 10.1 Navigate
 To](#ref-for-dfn-set-the-current-browsing-context-1 "§ 10.1 Navigate To")
- [§ 10.5
 Refresh](#ref-for-dfn-set-the-current-browsing-context-2 "§ 10.5 Refresh")
- [§ 11.
 Contexts](#ref-for-dfn-set-the-current-browsing-context-3 "§ 11. Contexts")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-set-the-current-browsing-context-4 "§ 11.6 Switch To Frame")
 [(2)](#ref-for-dfn-set-the-current-browsing-context-5 "Reference 2")
 [(3)](#ref-for-dfn-set-the-current-browsing-context-6 "Reference 3")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-dfn-set-the-current-browsing-context-7 "§ 11.7 Switch To Parent Frame")

[Permalink](#dfn-set-the-current-top-level-browsing-context)

**Referenced in:**

- [§ 11.3 Switch To
 Window](#ref-for-dfn-set-the-current-top-level-browsing-context-1 "§ 11.3 Switch To Window")

[Permalink](#dfn-get-window-handle)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-get-window-handle-1 "§ 6.5 Endpoints")

[Permalink](#dfn-close-window)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-close-window-1 "§ 6.5 Endpoints")

[Permalink](#dfn-switch-to-window)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-switch-to-window-1 "§ 6.5 Endpoints")
- [§ 11. Contexts](#ref-for-dfn-switch-to-window-2 "§ 11. Contexts")

[Permalink](#dfn-get-window-handles)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-get-window-handles-1 "§ 6.5 Endpoints")
- [§ 11.2 Close
 Window](#ref-for-dfn-get-window-handles-2 "§ 11.2 Close Window")

[Permalink](#dfn-new-window)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-new-window-1 "§ 6.5 Endpoints")

[Permalink](#dfn-switch-to-frame)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-switch-to-frame-1 "§ 6.5 Endpoints")
- [§ 11. Contexts](#ref-for-dfn-switch-to-frame-2 "§ 11. Contexts")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-switch-to-frame-3 "§ 11.6 Switch To Frame")

[Permalink](#dfn-switch-to-parent-frame)

**Referenced in:**

- [§ 6.5
 Endpoints](#ref-for-dfn-switch-to-parent-frame-1 "§ 6.5 Endpoints")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-dfn-switch-to-parent-frame-2 "§ 11.7 Switch To Parent Frame")

[Permalink](#dfn-window-states)

**Referenced in:**

- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-window-states-1 "§ 11.8 Resizing and positioning windows")

[Permalink](#dfn-maximized-window-state)

**Referenced in:**

- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-maximized-window-state-1 "§ 11.8 Resizing and positioning windows")

[Permalink](#dfn-minimized-window-state)

**Referenced in:**

- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-minimized-window-state-1 "§ 11.8 Resizing and positioning windows")

[Permalink](#dfn-normal-window-state)

**Referenced in:**

- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-normal-window-state-1 "§ 11.8 Resizing and positioning windows")

[Permalink](#dfn-fullscreen-window-state)

**Referenced in:**

- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-fullscreen-window-state-1 "§ 11.8.5 Fullscreen Window")

[Permalink](#dfn-windowrect-object)

**Referenced in:**

- [§ 11.8.1 Get Window
 Rect](#ref-for-dfn-windowrect-object-1 "§ 11.8.1 Get Window Rect")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-windowrect-object-2 "§ 11.8.2 Set Window Rect")
- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-windowrect-object-3 "§ 11.8.3 Maximize Window")
- [§ 11.8.4 Minimize
 Window](#ref-for-dfn-windowrect-object-4 "§ 11.8.4 Minimize Window")
- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-windowrect-object-5 "§ 11.8.5 Fullscreen Window")

[Permalink](#dfn-maximize-the-window)

**Referenced in:**

- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-maximize-the-window-1 "§ 11.8.3 Maximize Window")

[Permalink](#dfn-iconify-the-window)

**Referenced in:**

- [§ 11.8.4 Minimize
 Window](#ref-for-dfn-iconify-the-window-1 "§ 11.8.4 Minimize Window")

[Permalink](#dfn-restore-the-window)

**Referenced in:**

- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-restore-the-window-1 "§ 11.8.2 Set Window Rect")
- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-restore-the-window-2 "§ 11.8.3 Maximize Window")
- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-restore-the-window-3 "§ 11.8.5 Fullscreen Window")

[Permalink](#dfn-get-window-rect)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-get-window-rect-1 "§ 6.5 Endpoints")
- [§ 11.8.1 Get Window
 Rect](#ref-for-dfn-get-window-rect-2 "§ 11.8.1 Get Window Rect")

[Permalink](#dfn-set-window-rect)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-set-window-rect-1 "§ 6.5 Endpoints")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-set-window-rect-2 "§ 11.8.2 Set Window Rect")
 [(2)](#ref-for-dfn-set-window-rect-3 "Reference 2")
 [(3)](#ref-for-dfn-set-window-rect-4 "Reference 3")

[Permalink](#dfn-maximize-window)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-maximize-window-1 "§ 6.5 Endpoints")
- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-maximize-window-2 "§ 11.8.3 Maximize Window")
 [(2)](#ref-for-dfn-maximize-window-3 "Reference 2")

[Permalink](#dfn-minimize-window)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-minimize-window-1 "§ 6.5 Endpoints")
- [§ 11.8.4 Minimize
 Window](#ref-for-dfn-minimize-window-2 "§ 11.8.4 Minimize Window")
 [(2)](#ref-for-dfn-minimize-window-3 "Reference 2")

[Permalink](#dfn-fullscreen-window)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-fullscreen-window-1 "§ 6.5 Endpoints")

[Permalink](#dfn-web-elements)

**Referenced in:**

- [§ 12.3.1.1 CSS
 selectors](#ref-for-dfn-web-elements-1 "§ 12.3.1.1 CSS selectors")
- [§ 12.3.1.2 Link
 text](#ref-for-dfn-web-elements-2 "§ 12.3.1.2 Link text")
- [§ 12.3.1.3 Partial link
 text](#ref-for-dfn-web-elements-3 "§ 12.3.1.3 Partial link text")
- [§ 12.3.1.4 Tag
 name](#ref-for-dfn-web-elements-4 "§ 12.3.1.4 Tag name")
- [§ 12.3.1.5 XPath](#ref-for-dfn-web-elements-5 "§ 12.3.1.5 XPath")
- [§ 12.3.2 Find
 Element](#ref-for-dfn-web-elements-6 "§ 12.3.2 Find Element")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-web-elements-7 "§ 12.4.7 Get Element Rect")
 [(2)](#ref-for-dfn-web-elements-8 "Reference 2")
 [(3)](#ref-for-dfn-web-elements-9 "Reference 3")
 [(4)](#ref-for-dfn-web-elements-10 "Reference 4")
 [(5)](#ref-for-dfn-web-elements-11 "Reference 5")
- [§ 13.2 Executing
 Script](#ref-for-dfn-web-elements-12 "§ 13.2 Executing Script")

[Permalink](#dfn-web-element-identifier)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-dfn-web-element-identifier-1 "§ 12. Elements")
 [(2)](#ref-for-dfn-web-element-identifier-2 "Reference 2")
 [(3)](#ref-for-dfn-web-element-identifier-3 "Reference 3")
 [(4)](#ref-for-dfn-web-element-identifier-4 "Reference 4")

[Permalink](#dfn-represents-a-web-element)

**Referenced in:**

- [§ 11.6 Switch To
 Frame](#ref-for-dfn-represents-a-web-element-1 "§ 11.6 Switch To Frame")
 [(2)](#ref-for-dfn-represents-a-web-element-2 "Reference 2")
- [§ 12.
 Elements](#ref-for-dfn-represents-a-web-element-3 "§ 12. Elements")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-represents-a-web-element-4 "§ 12.5.1 Element Click")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-represents-a-web-element-5 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-represents-a-web-element-6 "Reference 2")
- [§ 13.2 Executing
 Script](#ref-for-dfn-represents-a-web-element-7 "§ 13.2 Executing Script")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-represents-a-web-element-8 "§ 15.7 Perform Actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-represents-a-web-element-9 "§ 15.8 Release Actions")

[Permalink](#dfn-webdriver-node-id)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-webdriver-node-id-1 "§ 12. Elements")

[Permalink](#dfn-weak-map)

**Referenced in:**

- [§ 8. Sessions](#ref-for-dfn-weak-map-1 "§ 8. Sessions")
- [§ 12. Elements](#ref-for-dfn-weak-map-2 "§ 12. Elements")
 [(2)](#ref-for-dfn-weak-map-3 "Reference 2")
 [(3)](#ref-for-dfn-weak-map-4 "Reference 3")
 [(4)](#ref-for-dfn-weak-map-5 "Reference 4")
 [(5)](#ref-for-dfn-weak-map-6 "Reference 5")

[Permalink](#dfn-browsing-context-group-node-map)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-dfn-browsing-context-group-node-map-1 "§ 12. Elements")
 [(2)](#ref-for-dfn-browsing-context-group-node-map-2 "Reference 2")

[Permalink](#dfn-node-id-map)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-node-id-map-1 "§ 12. Elements")

[Permalink](#dfn-navigable-seen-nodes-map)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-dfn-navigable-seen-nodes-map-1 "§ 12. Elements")
 [(2)](#ref-for-dfn-navigable-seen-nodes-map-2 "Reference 2")

[Permalink](#dfn-get-a-node)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-get-a-node-1 "§ 12. Elements")
- [§ 12.2 Shadow Roots](#ref-for-dfn-get-a-node-2 "§ 12.2 Shadow Roots")

[Permalink](#dfn-get-or-create-a-node-reference)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-dfn-get-or-create-a-node-reference-1 "§ 12. Elements")
- [§ 12.2 Shadow
 Roots](#ref-for-dfn-get-or-create-a-node-reference-2 "§ 12.2 Shadow Roots")

[Permalink](#dfn-node-reference-is-known)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-dfn-node-reference-is-known-1 "§ 12. Elements")
- [§ 12.2 Shadow
 Roots](#ref-for-dfn-node-reference-is-known-2 "§ 12.2 Shadow Roots")

[Permalink](#dfn-get-a-known-element)

**Referenced in:**

- [§ 11.6 Switch To
 Frame](#ref-for-dfn-get-a-known-element-1 "§ 11.6 Switch To Frame")
- [§ 12. Elements](#ref-for-dfn-get-a-known-element-2 "§ 12. Elements")
- [§ 12.3.4 Find Element From
 Element](#ref-for-dfn-get-a-known-element-3 "§ 12.3.4 Find Element From Element")
- [§ 12.3.5 Find Elements From
 Element](#ref-for-dfn-get-a-known-element-4 "§ 12.3.5 Find Elements From Element")
- [§ 12.3.9 Get Element Shadow
 Root](#ref-for-dfn-get-a-known-element-5 "§ 12.3.9 Get Element Shadow Root")
- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-get-a-known-element-6 "§ 12.4.1 Is Element Selected")
- [§ 12.4.2 Get Element
 Attribute](#ref-for-dfn-get-a-known-element-7 "§ 12.4.2 Get Element Attribute")
- [§ 12.4.3 Get Element
 Property](#ref-for-dfn-get-a-known-element-8 "§ 12.4.3 Get Element Property")
- [§ 12.4.4 Get Element CSS
 Value](#ref-for-dfn-get-a-known-element-9 "§ 12.4.4 Get Element CSS Value")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-get-a-known-element-10 "§ 12.4.5 Get Element Text")
- [§ 12.4.6 Get Element Tag
 Name](#ref-for-dfn-get-a-known-element-11 "§ 12.4.6 Get Element Tag Name")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-get-a-known-element-12 "§ 12.4.7 Get Element Rect")
- [§ 12.4.8 Is Element
 Enabled](#ref-for-dfn-get-a-known-element-13 "§ 12.4.8 Is Element Enabled")
- [§ 12.4.9 Get Computed
 Role](#ref-for-dfn-get-a-known-element-14 "§ 12.4.9 Get Computed Role")
- [§ 12.4.10 Get Computed
 Label](#ref-for-dfn-get-a-known-element-15 "§ 12.4.10 Get Computed Label")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-get-a-known-element-16 "§ 12.5.1 Element Click")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-get-a-known-element-17 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-get-a-known-element-18 "§ 12.5.3 Element Send Keys")
- [§ 15.1 Actions
 Options](#ref-for-dfn-get-a-known-element-19 "§ 15.1 Actions Options")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-get-a-known-element-20 "§ 17.2 Take Element Screenshot")

[Permalink](#dfn-get-or-create-a-web-element-reference)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-dfn-get-or-create-a-web-element-reference-1 "§ 12. Elements")

[Permalink](#dfn-web-element-reference-object)

**Referenced in:**

- [§ 12.3
 Retrieval](#ref-for-dfn-web-element-reference-object-1 "§ 12.3 Retrieval")
- [§ 12.3.8 Get Active
 Element](#ref-for-dfn-web-element-reference-object-2 "§ 12.3.8 Get Active Element")
- [§ 13.2 Executing
 Script](#ref-for-dfn-web-element-reference-object-3 "§ 13.2 Executing Script")

[Permalink](#dfn-deserialize-a-web-element)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-deserialize-a-web-element-1 "§ 13.2 Executing Script")

[Permalink](#dfn-is-stale)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-is-stale-1 "§ 12. Elements")
- [§ 12.2 Shadow Roots](#ref-for-dfn-is-stale-2 "§ 12.2 Shadow Roots")
- [§ 13.2 Executing
 Script](#ref-for-dfn-is-stale-3 "§ 13.2 Executing Script")

[Permalink](#dfn-scrolls-into-view)

**Referenced in:**

- [§ 12.5
 Interaction](#ref-for-dfn-scrolls-into-view-1 "§ 12.5 Interaction")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-scrolls-into-view-2 "§ 12.5.1 Element Click")
 [(2)](#ref-for-dfn-scrolls-into-view-3 "Reference 2")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-scrolls-into-view-4 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-scrolls-into-view-5 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-scrolls-into-view-6 "Reference 2")
- [§ 17. Screen
 capture](#ref-for-dfn-scrolls-into-view-7 "§ 17. Screen capture")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-scrolls-into-view-8 "§ 17.2 Take Element Screenshot")

[Permalink](#dfn-editable)

**Referenced in:**

- [§ 6.6 Errors](#ref-for-dfn-editable-1 "§ 6.6 Errors")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-editable-2 "§ 12.5.2 Element Clear")

[Permalink](#dfn-mutable-form-control-element)

**Referenced in:**

- [§ 12.5.2 Element
 Clear](#ref-for-dfn-mutable-form-control-element-1 "§ 12.5.2 Element Clear")

[Permalink](#dfn-mutable-element)

**Referenced in:**

- [§ 12.5.2 Element
 Clear](#ref-for-dfn-mutable-element-1 "§ 12.5.2 Element Clear")

[Permalink](#dfn-pointer-events-are-not-disabled)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-dfn-pointer-events-are-not-disabled-1 "§ 12.1 Interactability")

[Permalink](#dfn-read-only)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-read-only-1 "§ 12. Elements")

[Permalink](#dfn-interactable)

**Referenced in:**

- [§ 6.6 Errors](#ref-for-dfn-interactable-1 "§ 6.6 Errors")
- [§ 12.5 Interaction](#ref-for-dfn-interactable-2 "§ 12.5 Interaction")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-interactable-3 "§ 12.5.2 Element Clear")
 [(2)](#ref-for-dfn-interactable-4 "Reference 2")

[Permalink](#dfn-pointer-interactable)

**Referenced in:**

- [§ 6.6 Errors](#ref-for-dfn-pointer-interactable-1 "§ 6.6 Errors")
- [§ 12.1
 Interactability](#ref-for-dfn-pointer-interactable-2 "§ 12.1 Interactability")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-pointer-interactable-3 "§ 12.5.1 Element Click")

[Permalink](#dfn-keyboard-interactable)

**Referenced in:**

- [§ 6.6 Errors](#ref-for-dfn-keyboard-interactable-1 "§ 6.6 Errors")
- [§ 12.1
 Interactability](#ref-for-dfn-keyboard-interactable-2 "§ 12.1 Interactability")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-keyboard-interactable-3 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-keyboard-interactable-4 "Reference 2")
 [(3)](#ref-for-dfn-keyboard-interactable-5 "Reference 3")

[Permalink](#dfn-center-point)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-dfn-center-point-1 "§ 12.1 Interactability")
 [(2)](#ref-for-dfn-center-point-2 "Reference 2")
 [(3)](#ref-for-dfn-center-point-3 "Reference 3")
 [(4)](#ref-for-dfn-center-point-4 "Reference 4")
 [(5)](#ref-for-dfn-center-point-5 "Reference 5")
 [(6)](#ref-for-dfn-center-point-6 "Reference 6")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-center-point-7 "§ 12.5.1 Element Click")
 [(2)](#ref-for-dfn-center-point-8 "Reference 2")
 [(3)](#ref-for-dfn-center-point-9 "Reference 3")
- [§ 15.5 Processing
 actions](#ref-for-dfn-center-point-10 "§ 15.5 Processing actions")

[Permalink](#dfn-disabled)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-disabled-1 "§ 12. Elements")
- [§ 12.4.8 Is Element
 Enabled](#ref-for-dfn-disabled-2 "§ 12.4.8 Is Element Enabled")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-disabled-3 "§ 12.5.1 Element Click")

[Permalink](#dfn-in-view)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-in-view-1 "§ 12. Elements")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-in-view-2 "§ 12.5.1 Element Click")

[Permalink](#dfn-obscuring)

**Referenced in:**

- [§ 6.6 Errors](#ref-for-dfn-obscuring-1 "§ 6.6 Errors")
- [§ 12.1
 Interactability](#ref-for-dfn-obscuring-2 "§ 12.1 Interactability")
 [(2)](#ref-for-dfn-obscuring-3 "Reference 2")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-obscuring-4 "§ 12.5.1 Element Click")
 [(2)](#ref-for-dfn-obscuring-5 "Reference 2")

[Permalink](#dfn-pointer-interactable-paint-tree)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-dfn-pointer-interactable-paint-tree-1 "§ 12.1 Interactability")
 [(2)](#ref-for-dfn-pointer-interactable-paint-tree-2 "Reference 2")

[Permalink](#dfn-shadow-roots)

**Referenced in:**

- [§ 6.6 Errors](#ref-for-dfn-shadow-roots-1 "§ 6.6 Errors")
- [§ 12.2 Shadow
 Roots](#ref-for-dfn-shadow-roots-2 "§ 12.2 Shadow Roots")
 [(2)](#ref-for-dfn-shadow-roots-3 "Reference 2")
- [§ 12.3.9 Get Element Shadow
 Root](#ref-for-dfn-shadow-roots-4 "§ 12.3.9 Get Element Shadow Root")
- [§ 13.2 Executing
 Script](#ref-for-dfn-shadow-roots-5 "§ 13.2 Executing Script")

[Permalink](#dfn-shadow-root-identifier)

**Referenced in:**

- [§ 12.2 Shadow
 Roots](#ref-for-dfn-shadow-root-identifier-1 "§ 12.2 Shadow Roots")
 [(2)](#ref-for-dfn-shadow-root-identifier-2 "Reference 2")
 [(3)](#ref-for-dfn-shadow-root-identifier-3 "Reference 3")
 [(4)](#ref-for-dfn-shadow-root-identifier-4 "Reference 4")

[Permalink](#dfn-represents-a-shadow-root)

**Referenced in:**

- [§ 12.2 Shadow
 Roots](#ref-for-dfn-represents-a-shadow-root-1 "§ 12.2 Shadow Roots")
- [§ 13.2 Executing
 Script](#ref-for-dfn-represents-a-shadow-root-2 "§ 13.2 Executing Script")

[Permalink](#dfn-get-a-known-shadow-root)

**Referenced in:**

- [§ 12.2 Shadow
 Roots](#ref-for-dfn-get-a-known-shadow-root-1 "§ 12.2 Shadow Roots")
- [§ 12.3.6 Find Element From Shadow
 Root](#ref-for-dfn-get-a-known-shadow-root-2 "§ 12.3.6 Find Element From Shadow Root")
- [§ 12.3.7 Find Elements From Shadow
 Root](#ref-for-dfn-get-a-known-shadow-root-3 "§ 12.3.7 Find Elements From Shadow Root")

[Permalink](#dfn-get-or-create-a-shadow-root-reference)

**Referenced in:**

- [§ 12.2 Shadow
 Roots](#ref-for-dfn-get-or-create-a-shadow-root-reference-1 "§ 12.2 Shadow Roots")

[Permalink](#dfn-shadow-root-reference-object)

**Referenced in:**

- [§ 12.3.9 Get Element Shadow
 Root](#ref-for-dfn-shadow-root-reference-object-1 "§ 12.3.9 Get Element Shadow Root")
- [§ 13.2 Executing
 Script](#ref-for-dfn-shadow-root-reference-object-2 "§ 13.2 Executing Script")

[Permalink](#dfn-deserialize-a-shadow-root)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-deserialize-a-shadow-root-1 "§ 13.2 Executing Script")

[Permalink](#dfn-is-detached)

**Referenced in:**

- [§ 12.2 Shadow
 Roots](#ref-for-dfn-is-detached-1 "§ 12.2 Shadow Roots")
- [§ 13.2 Executing
 Script](#ref-for-dfn-is-detached-2 "§ 13.2 Executing Script")

[Permalink](#dfn-find)

**Referenced in:**

- [§ 12.3.2 Find Element](#ref-for-dfn-find-1 "§ 12.3.2 Find Element")
- [§ 12.3.3 Find Elements](#ref-for-dfn-find-2 "§ 12.3.3 Find Elements")
- [§ 12.3.4 Find Element From
 Element](#ref-for-dfn-find-3 "§ 12.3.4 Find Element From Element")
- [§ 12.3.5 Find Elements From
 Element](#ref-for-dfn-find-4 "§ 12.3.5 Find Elements From Element")
- [§ 12.3.6 Find Element From Shadow
 Root](#ref-for-dfn-find-5 "§ 12.3.6 Find Element From Shadow Root")
- [§ 12.3.7 Find Elements From Shadow
 Root](#ref-for-dfn-find-6 "§ 12.3.7 Find Elements From Shadow Root")

[Permalink](#dfn-strategy)

**Referenced in:**

- [§ 12.3 Retrieval](#ref-for-dfn-strategy-1 "§ 12.3 Retrieval")
 [(2)](#ref-for-dfn-strategy-2 "Reference 2")
- [§ 12.3.1.1 CSS
 selectors](#ref-for-dfn-strategy-3 "§ 12.3.1.1 CSS selectors")
- [§ 12.3.1.2 Link text](#ref-for-dfn-strategy-4 "§ 12.3.1.2 Link text")
- [§ 12.3.1.3 Partial link
 text](#ref-for-dfn-strategy-5 "§ 12.3.1.3 Partial link text")
 [(2)](#ref-for-dfn-strategy-6 "Reference 2")
 [(3)](#ref-for-dfn-strategy-7 "Reference 3")
- [§ 12.3.1.4 Tag name](#ref-for-dfn-strategy-8 "§ 12.3.1.4 Tag name")
- [§ 12.3.1.5 XPath](#ref-for-dfn-strategy-9 "§ 12.3.1.5 XPath")

[Permalink](#dfn-table-of-location-strategies)

**Referenced in:**

- [§ 12.3.2 Find
 Element](#ref-for-dfn-table-of-location-strategies-1 "§ 12.3.2 Find Element")
- [§ 12.3.3 Find
 Elements](#ref-for-dfn-table-of-location-strategies-2 "§ 12.3.3 Find Elements")
- [§ 12.3.4 Find Element From
 Element](#ref-for-dfn-table-of-location-strategies-3 "§ 12.3.4 Find Element From Element")
- [§ 12.3.5 Find Elements From
 Element](#ref-for-dfn-table-of-location-strategies-4 "§ 12.3.5 Find Elements From Element")
- [§ 12.3.6 Find Element From Shadow
 Root](#ref-for-dfn-table-of-location-strategies-5 "§ 12.3.6 Find Element From Shadow Root")
- [§ 12.3.7 Find Elements From Shadow
 Root](#ref-for-dfn-table-of-location-strategies-6 "§ 12.3.7 Find Elements From Shadow Root")

[Permalink](#dfn-css-selector)

**Referenced in:**

- [§ 12.3.1 Locator
 strategies](#ref-for-dfn-css-selector-1 "§ 12.3.1 Locator strategies")

[Permalink](#dfn-link-text-selector)

**Referenced in:**

- [§ 12.3.1 Locator
 strategies](#ref-for-dfn-link-text-selector-1 "§ 12.3.1 Locator strategies")
- [§ 12.3.1.3 Partial link
 text](#ref-for-dfn-link-text-selector-2 "§ 12.3.1.3 Partial link text")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-link-text-selector-3 "§ 12.4.5 Get Element Text")

[Permalink](#dfn-partial-link-text-selector)

**Referenced in:**

- [§ 12.3.1 Locator
 strategies](#ref-for-dfn-partial-link-text-selector-1 "§ 12.3.1 Locator strategies")
- [§ 12.3.1.3 Partial link
 text](#ref-for-dfn-partial-link-text-selector-2 "§ 12.3.1.3 Partial link text")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-partial-link-text-selector-3 "§ 12.4.5 Get Element Text")

[Permalink](#dfn-tag-name)

**Referenced in:**

- [§ 12.3.1 Locator
 strategies](#ref-for-dfn-tag-name-1 "§ 12.3.1 Locator strategies")

[Permalink](#dfn-xpath-selector)

**Referenced in:**

- [§ 12.3.1 Locator
 strategies](#ref-for-dfn-xpath-selector-1 "§ 12.3.1 Locator strategies")

[Permalink](#dfn-find-element)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-find-element-1 "§ 6.5 Endpoints")
- [§ 12.3 Retrieval](#ref-for-dfn-find-element-2 "§ 12.3 Retrieval")
- [§ 12.3.2 Find
 Element](#ref-for-dfn-find-element-3 "§ 12.3.2 Find Element")

[Permalink](#dfn-find-elements)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-find-elements-1 "§ 6.5 Endpoints")
- [§ 12.3 Retrieval](#ref-for-dfn-find-elements-2 "§ 12.3 Retrieval")

[Permalink](#dfn-find-element-from-element)

**Referenced in:**

- [§ 6.5
 Endpoints](#ref-for-dfn-find-element-from-element-1 "§ 6.5 Endpoints")
- [§ 12.3
 Retrieval](#ref-for-dfn-find-element-from-element-2 "§ 12.3 Retrieval")

[Permalink](#dfn-find-elements-from-element)

**Referenced in:**

- [§ 6.5
 Endpoints](#ref-for-dfn-find-elements-from-element-1 "§ 6.5 Endpoints")
- [§ 12.3
 Retrieval](#ref-for-dfn-find-elements-from-element-2 "§ 12.3 Retrieval")

[Permalink](#dfn-find-element-from-shadow-root)

**Referenced in:**

- [§ 6.5
 Endpoints](#ref-for-dfn-find-element-from-shadow-root-1 "§ 6.5 Endpoints")
- [§ 12.3
 Retrieval](#ref-for-dfn-find-element-from-shadow-root-2 "§ 12.3 Retrieval")

[Permalink](#dfn-find-elements-from-shadow-root)

**Referenced in:**

- [§ 6.5
 Endpoints](#ref-for-dfn-find-elements-from-shadow-root-1 "§ 6.5 Endpoints")
- [§ 12.3
 Retrieval](#ref-for-dfn-find-elements-from-shadow-root-2 "§ 12.3 Retrieval")

[Permalink](#dfn-get-active-element)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-get-active-element-1 "§ 6.5 Endpoints")

[Permalink](#dfn-get-element-shadow-root)

**Referenced in:**

- [§ 6.5
 Endpoints](#ref-for-dfn-get-element-shadow-root-1 "§ 6.5 Endpoints")

[Permalink](#dfn-calculate-the-absolute-position)

**Referenced in:**

- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-calculate-the-absolute-position-1 "§ 12.4.7 Get Element Rect")

[Permalink](#dfn-not-in-the-same-tree)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-dfn-not-in-the-same-tree-1 "§ 12.1 Interactability")

[Permalink](#dfn-container)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-container-1 "§ 12.5.1 Element Click")
 [(2)](#ref-for-dfn-container-2 "Reference 2")
 [(3)](#ref-for-dfn-container-3 "Reference 3")
 [(4)](#ref-for-dfn-container-4 "Reference 4")
 [(5)](#ref-for-dfn-container-5 "Reference 5")

[Permalink](#dfn-is-element-selected)

**Referenced in:**

- [§ 6.5
 Endpoints](#ref-for-dfn-is-element-selected-1 "§ 6.5 Endpoints")
- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-is-element-selected-2 "§ 12.4.1 Is Element Selected")

[Permalink](#dfn-get-element-attribute)

**Referenced in:**

- [§ 6.5
 Endpoints](#ref-for-dfn-get-element-attribute-1 "§ 6.5 Endpoints")

[Permalink](#dfn-get-element-property)

**Referenced in:**

- [§ 6.5
 Endpoints](#ref-for-dfn-get-element-property-1 "§ 6.5 Endpoints")

[Permalink](#dfn-get-element-css-value)

**Referenced in:**

- [§ 6.5
 Endpoints](#ref-for-dfn-get-element-css-value-1 "§ 6.5 Endpoints")

[Permalink](#dfn-get-element-text)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-get-element-text-1 "§ 6.5 Endpoints")
- [§ 12.3.1.2 Link
 text](#ref-for-dfn-get-element-text-2 "§ 12.3.1.2 Link text")
- [§ 12.3.1.3 Partial link
 text](#ref-for-dfn-get-element-text-3 "§ 12.3.1.3 Partial link text")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-get-element-text-4 "§ 12.4.5 Get Element Text")
 [(2)](#ref-for-dfn-get-element-text-5 "Reference 2")

[Permalink](#dfn-whitespace)

**Referenced in:**

- [§ 12.3.1.2 Link
 text](#ref-for-dfn-whitespace-1 "§ 12.3.1.2 Link text")
- [§ 18. Print](#ref-for-dfn-whitespace-2 "§ 18. Print")
 [(2)](#ref-for-dfn-whitespace-3 "Reference 2")

[Permalink](#dfn-get-element-tag-name)

**Referenced in:**

- [§ 6.5
 Endpoints](#ref-for-dfn-get-element-tag-name-1 "§ 6.5 Endpoints")

[Permalink](#dfn-get-element-rect)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-get-element-rect-1 "§ 6.5 Endpoints")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-get-element-rect-2 "§ 12.4.7 Get Element Rect")

[Permalink](#dfn-is-element-enabled)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-is-element-enabled-1 "§ 6.5 Endpoints")

[Permalink](#dfn-get-computed-role)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-get-computed-role-1 "§ 6.5 Endpoints")

[Permalink](#dfn-get-computed-label)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-get-computed-label-1 "§ 6.5 Endpoints")

[Permalink](#dfn-clear-algorithm)

**Referenced in:**

- [§ 12.5
 Interaction](#ref-for-dfn-clear-algorithm-1 "§ 12.5 Interaction")
 [(2)](#ref-for-dfn-clear-algorithm-2 "Reference 2")
 [(3)](#ref-for-dfn-clear-algorithm-3 "Reference 3")
 [(4)](#ref-for-dfn-clear-algorithm-4 "Reference 4")
 [(5)](#ref-for-dfn-clear-algorithm-5 "Reference 5")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-clear-algorithm-6 "§ 12.5.2 Element Clear")

[Permalink](#dfn-element-click)

**Referenced in:**

- [§ 1.2 Simplicity](#ref-for-dfn-element-click-1 "§ 1.2 Simplicity")
- [§ 6.5 Endpoints](#ref-for-dfn-element-click-2 "§ 6.5 Endpoints")
- [§ 6.6 Errors](#ref-for-dfn-element-click-3 "§ 6.6 Errors")
- [§ 12.1
 Interactability](#ref-for-dfn-element-click-4 "§ 12.1 Interactability")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-element-click-5 "§ 12.5.1 Element Click")

[Permalink](#dfn-element-clear)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-element-clear-1 "§ 6.5 Endpoints")
- [§ 6.6 Errors](#ref-for-dfn-element-clear-2 "§ 6.6 Errors")
- [§ 12. Elements](#ref-for-dfn-element-clear-3 "§ 12. Elements")

[Permalink](#dfn-clear-a-content-editable-element)

**Referenced in:**

- [§ 12.5.2 Element
 Clear](#ref-for-dfn-clear-a-content-editable-element-1 "§ 12.5.2 Element Clear")

[Permalink](#dfn-clear-a-resettable-element)

**Referenced in:**

- [§ 12.5.2 Element
 Clear](#ref-for-dfn-clear-a-resettable-element-1 "§ 12.5.2 Element Clear")

[Permalink](#dfn-element-send-keys)

**Referenced in:**

- [§ 1.2
 Simplicity](#ref-for-dfn-element-send-keys-1 "§ 1.2 Simplicity")
- [§ 6.5 Endpoints](#ref-for-dfn-element-send-keys-2 "§ 6.5 Endpoints")
- [§ 12. Elements](#ref-for-dfn-element-send-keys-3 "§ 12. Elements")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-element-send-keys-4 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-element-send-keys-5 "Reference 2")

[Permalink](#dfn-non-typeable-form-control)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-non-typeable-form-control-1 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-non-typeable-form-control-2 "Reference 2")
 [(3)](#ref-for-dfn-non-typeable-form-control-3 "Reference 3")

[Permalink](#dfn-null-key)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-null-key-1 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-clear-the-modifier-key-state)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-clear-the-modifier-key-state-1 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-clear-the-modifier-key-state-2 "Reference 2")

[Permalink](#dfn-typeable)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-typeable-1 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-shifted-state)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-shifted-state-1 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-shifted-state-2 "Reference 2")

[Permalink](#dfn-dispatch-the-events-for-a-typeable-string)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-dispatch-the-events-for-a-typeable-string-1 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-dispatch-the-events-for-a-typeable-string-2 "Reference 2")
 [(3)](#ref-for-dfn-dispatch-the-events-for-a-typeable-string-3 "Reference 3")
 [(4)](#ref-for-dfn-dispatch-the-events-for-a-typeable-string-4 "Reference 4")

[Permalink](#dfn-dispatch-a-composition-event)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-dispatch-a-composition-event-1 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-dispatch-a-composition-event-2 "Reference 2")
 [(3)](#ref-for-dfn-dispatch-a-composition-event-3 "Reference 3")

[Permalink](#dfn-dispatch-actions-for-a-string)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-dispatch-actions-for-a-string-1 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-get-page-source)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-get-page-source-1 "§ 6.5 Endpoints")
- [§ 13.1 Get Page
 Source](#ref-for-dfn-get-page-source-2 "§ 13.1 Get Page Source")

[Permalink](#dfn-collection)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-collection-1 "§ 13.2 Executing Script")

[Permalink](#dfn-json-deserialize)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-json-deserialize-1 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-json-deserialize-2 "Reference 2")

[Permalink](#dfn-json-clone)

**Referenced in:**

- [§ 13.2.1 Execute
 Script](#ref-for-dfn-json-clone-1 "§ 13.2.1 Execute Script")
 [(2)](#ref-for-dfn-json-clone-2 "Reference 2")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-json-clone-3 "§ 13.2.2 Execute Async Script")
 [(2)](#ref-for-dfn-json-clone-4 "Reference 2")

[Permalink](#dfn-internal-json-clone)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-internal-json-clone-1 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-internal-json-clone-2 "Reference 2")

[Permalink](#dfn-clone-an-object)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-clone-an-object-1 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-clone-an-object-2 "Reference 2")

[Permalink](#dfn-extract-the-script-arguments-from-a-request)

**Referenced in:**

- [§ 13.2.1 Execute
 Script](#ref-for-dfn-extract-the-script-arguments-from-a-request-1 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-extract-the-script-arguments-from-a-request-2 "§ 13.2.2 Execute Async Script")

[Permalink](#dfn-execute-a-function-body)

**Referenced in:**

- [§ 13.2.1 Execute
 Script](#ref-for-dfn-execute-a-function-body-1 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-execute-a-function-body-2 "§ 13.2.2 Execute Async Script")

[Permalink](#dfn-execute-script)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-execute-script-1 "§ 6.5 Endpoints")

[Permalink](#dfn-execute-async-script)

**Referenced in:**

- [§ 6.5
 Endpoints](#ref-for-dfn-execute-async-script-1 "§ 6.5 Endpoints")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-execute-async-script-2 "§ 13.2.2 Execute Async Script")
 [(2)](#ref-for-dfn-execute-async-script-3 "Reference 2")

[Permalink](#dfn-table-for-cookie-conversion)

**Referenced in:**

- [§ 14.
 Cookies](#ref-for-dfn-table-for-cookie-conversion-1 "§ 14. Cookies")
- [§ 14.3 Add
 Cookie](#ref-for-dfn-table-for-cookie-conversion-2 "§ 14.3 Add Cookie")
 [(2)](#ref-for-dfn-table-for-cookie-conversion-3 "Reference 2")

[Permalink](#dfn-cookie-name)

**Referenced in:**

- [§ 14. Cookies](#ref-for-dfn-cookie-name-1 "§ 14. Cookies")
- [§ 14.2 Get Named
 Cookie](#ref-for-dfn-cookie-name-2 "§ 14.2 Get Named Cookie")
- [§ 14.3 Add Cookie](#ref-for-dfn-cookie-name-3 "§ 14.3 Add Cookie")
 [(2)](#ref-for-dfn-cookie-name-4 "Reference 2")

[Permalink](#dfn-cookie-value)

**Referenced in:**

- [§ 14.3 Add Cookie](#ref-for-dfn-cookie-value-1 "§ 14.3 Add Cookie")
 [(2)](#ref-for-dfn-cookie-value-2 "Reference 2")

[Permalink](#dfn-cookie-path)

**Referenced in:**

- [§ 14.3 Add Cookie](#ref-for-dfn-cookie-path-1 "§ 14.3 Add Cookie")

[Permalink](#dfn-cookie-domain)

**Referenced in:**

- [§ 14.3 Add Cookie](#ref-for-dfn-cookie-domain-1 "§ 14.3 Add Cookie")
 [(2)](#ref-for-dfn-cookie-domain-2 "Reference 2")

[Permalink](#dfn-cookie-secure-only)

**Referenced in:**

- [§ 14.3 Add
 Cookie](#ref-for-dfn-cookie-secure-only-1 "§ 14.3 Add Cookie")
 [(2)](#ref-for-dfn-cookie-secure-only-2 "Reference 2")

[Permalink](#dfn-cookie-http-only)

**Referenced in:**

- [§ 14. Cookies](#ref-for-dfn-cookie-http-only-1 "§ 14. Cookies")
- [§ 14.3 Add
 Cookie](#ref-for-dfn-cookie-http-only-2 "§ 14.3 Add Cookie")
 [(2)](#ref-for-dfn-cookie-http-only-3 "Reference 2")

[Permalink](#dfn-cookie-expiry-time)

**Referenced in:**

- [§ 14. Cookies](#ref-for-dfn-cookie-expiry-time-1 "§ 14. Cookies")
- [§ 14.3 Add
 Cookie](#ref-for-dfn-cookie-expiry-time-2 "§ 14.3 Add Cookie")
 [(2)](#ref-for-dfn-cookie-expiry-time-3 "Reference 2")

[Permalink](#dfn-cookie-same-site)

**Referenced in:**

- [§ 14.3 Add
 Cookie](#ref-for-dfn-cookie-same-site-1 "§ 14.3 Add Cookie")

[Permalink](#dfn-serialized-cookie)

**Referenced in:**

- [§ 14. Cookies](#ref-for-dfn-serialized-cookie-1 "§ 14. Cookies")
 [(2)](#ref-for-dfn-serialized-cookie-2 "Reference 2")
- [§ 14.1 Get All
 Cookies](#ref-for-dfn-serialized-cookie-3 "§ 14.1 Get All Cookies")
- [§ 14.2 Get Named
 Cookie](#ref-for-dfn-serialized-cookie-4 "§ 14.2 Get Named Cookie")

[Permalink](#dfn-associated-cookies)

**Referenced in:**

- [§ 6.6 Errors](#ref-for-dfn-associated-cookies-1 "§ 6.6 Errors")
- [§ 14. Cookies](#ref-for-dfn-associated-cookies-2 "§ 14. Cookies")
- [§ 14.1 Get All
 Cookies](#ref-for-dfn-associated-cookies-3 "§ 14.1 Get All Cookies")
- [§ 14.2 Get Named
 Cookie](#ref-for-dfn-associated-cookies-4 "§ 14.2 Get Named Cookie")

[Permalink](#dfn-creating-a-cookie)

**Referenced in:**

- [§ 14. Cookies](#ref-for-dfn-creating-a-cookie-1 "§ 14. Cookies")
- [§ 14.3 Add
 Cookie](#ref-for-dfn-creating-a-cookie-2 "§ 14.3 Add Cookie")

[Permalink](#dfn-delete-cookies)

**Referenced in:**

- [§ 14.4 Delete
 Cookie](#ref-for-dfn-delete-cookies-1 "§ 14.4 Delete Cookie")
- [§ 14.5 Delete All
 Cookies](#ref-for-dfn-delete-cookies-2 "§ 14.5 Delete All Cookies")

[Permalink](#dfn-get-all-cookies)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-get-all-cookies-1 "§ 6.5 Endpoints")

[Permalink](#dfn-get-named-cookie)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-get-named-cookie-1 "§ 6.5 Endpoints")

[Permalink](#dfn-adding-a-cookie)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-adding-a-cookie-1 "§ 6.5 Endpoints")
- [§ 14. Cookies](#ref-for-dfn-adding-a-cookie-2 "§ 14. Cookies")
 [(2)](#ref-for-dfn-adding-a-cookie-3 "Reference 2")
 [(3)](#ref-for-dfn-adding-a-cookie-4 "Reference 3")
 [(4)](#ref-for-dfn-adding-a-cookie-5 "Reference 4")
 [(5)](#ref-for-dfn-adding-a-cookie-6 "Reference 5")
 [(6)](#ref-for-dfn-adding-a-cookie-7 "Reference 6")
 [(7)](#ref-for-dfn-adding-a-cookie-8 "Reference 7")

[Permalink](#dfn-delete-cookie)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-delete-cookie-1 "§ 6.5 Endpoints")

[Permalink](#dfn-delete-all-cookies)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-delete-all-cookies-1 "§ 6.5 Endpoints")

[Permalink](#dfn-actions)

**Referenced in:**

- [§ 12.5 Interaction](#ref-for-dfn-actions-1 "§ 12.5 Interaction")

[Permalink](#dfn-actions-options)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-actions-options-1 "§ 12.5.1 Element Click")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-actions-options-2 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-actions-options-3 "Reference 2")
 [(3)](#ref-for-dfn-actions-options-4 "Reference 3")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-actions-options-5 "§ 15.7 Perform Actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-actions-options-6 "§ 15.8 Release Actions")

[Permalink](#dfn-is-element-origin)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-is-element-origin-1 "§ 12.5.1 Element Click")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-is-element-origin-2 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-is-element-origin-3 "Reference 2")
- [§ 15.5 Processing
 actions](#ref-for-dfn-is-element-origin-4 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-is-element-origin-5 "Reference 2")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-is-element-origin-6 "§ 15.7 Perform Actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-is-element-origin-7 "§ 15.8 Release Actions")

[Permalink](#dfn-get-element-origin)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-get-element-origin-1 "§ 12.5.1 Element Click")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-get-element-origin-2 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-get-element-origin-3 "Reference 2")
- [§ 15.5 Processing
 actions](#ref-for-dfn-get-element-origin-4 "§ 15.5 Processing actions")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-get-element-origin-5 "§ 15.7 Perform Actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-get-element-origin-6 "§ 15.8 Release Actions")

[Permalink](#dfn-get-a-webelement-origin)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-get-a-webelement-origin-1 "§ 12.5.1 Element Click")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-get-a-webelement-origin-2 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-get-a-webelement-origin-3 "Reference 2")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-get-a-webelement-origin-4 "§ 15.7 Perform Actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-get-a-webelement-origin-5 "§ 15.8 Release Actions")

[Permalink](#dfn-input-source)

**Referenced in:**

- [§ 15. Actions](#ref-for-dfn-input-source-1 "§ 15. Actions")
 [(2)](#ref-for-dfn-input-source-2 "Reference 2")
 [(3)](#ref-for-dfn-input-source-3 "Reference 3")
 [(4)](#ref-for-dfn-input-source-4 "Reference 4")
 [(5)](#ref-for-dfn-input-source-5 "Reference 5")
 [(6)](#ref-for-dfn-input-source-6 "Reference 6")
- [§ 15.2.1 Null input
 source](#ref-for-dfn-input-source-7 "§ 15.2.1 Null input source")
 [(2)](#ref-for-dfn-input-source-8 "Reference 2")
- [§ 15.2.2 Key input
 source](#ref-for-dfn-input-source-9 "§ 15.2.2 Key input source")
- [§ 15.2.3 Pointer input
 source](#ref-for-dfn-input-source-10 "§ 15.2.3 Pointer input source")
- [§ 15.2.4 Wheel input
 source](#ref-for-dfn-input-source-11 "§ 15.2.4 Wheel input source")
- [§ 15.3 Input
 state](#ref-for-dfn-input-source-12 "§ 15.3 Input state")
 [(2)](#ref-for-dfn-input-source-13 "Reference 2")
 [(3)](#ref-for-dfn-input-source-14 "Reference 3")
- [§ 15.4 Ticks](#ref-for-dfn-input-source-15 "§ 15.4 Ticks")
 [(2)](#ref-for-dfn-input-source-16 "Reference 2")
 [(3)](#ref-for-dfn-input-source-17 "Reference 3")

[Permalink](#dfn-input-id)

**Referenced in:**

- [§ 15.3 Input state](#ref-for-dfn-input-id-1 "§ 15.3 Input state")

[Permalink](#dfn-create-an-input-source)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-create-an-input-source-1 "§ 12.5.1 Element Click")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-create-an-input-source-2 "§ 12.5.3 Element Send Keys")
- [§ 15.3 Input
 state](#ref-for-dfn-create-an-input-source-3 "§ 15.3 Input state")

[Permalink](#dfn-null-input-source)

**Referenced in:**

- [§ 15.2.1 Null input
 source](#ref-for-dfn-null-input-source-1 "§ 15.2.1 Null input source")
 [(2)](#ref-for-dfn-null-input-source-2 "Reference 2")
- [§ 15.2.2 Key input
 source](#ref-for-dfn-null-input-source-3 "§ 15.2.2 Key input source")
- [§ 15.2.3 Pointer input
 source](#ref-for-dfn-null-input-source-4 "§ 15.2.3 Pointer input source")
- [§ 15.2.4 Wheel input
 source](#ref-for-dfn-null-input-source-5 "§ 15.2.4 Wheel input source")

[Permalink](#dfn-pause)

**Referenced in:**

- [§ 15. Actions](#ref-for-dfn-pause-1 "§ 15. Actions")
 [(2)](#ref-for-dfn-pause-2 "Reference 2")
 [(3)](#ref-for-dfn-pause-3 "Reference 3")
 [(4)](#ref-for-dfn-pause-4 "Reference 4")
 [(5)](#ref-for-dfn-pause-5 "Reference 5")
- [§ 15.2.2 Key input
 source](#ref-for-dfn-pause-6 "§ 15.2.2 Key input source")
- [§ 15.2.3 Pointer input
 source](#ref-for-dfn-pause-7 "§ 15.2.3 Pointer input source")
- [§ 15.2.4 Wheel input
 source](#ref-for-dfn-pause-8 "§ 15.2.4 Wheel input source")
- [§ 15.4 Ticks](#ref-for-dfn-pause-9 "§ 15.4 Ticks")

[Permalink](#dfn-create-a-null-input-source)

**Referenced in:**

- [§ 15.2 Input
 sources](#ref-for-dfn-create-a-null-input-source-1 "§ 15.2 Input sources")

[Permalink](#dfn-key-input-source)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-key-input-source-1 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-key-input-source-2 "Reference 2")
- [§ 15.2.2 Key input
 source](#ref-for-dfn-key-input-source-3 "§ 15.2.2 Key input source")
 [(2)](#ref-for-dfn-key-input-source-4 "Reference 2")
 [(3)](#ref-for-dfn-key-input-source-5 "Reference 3")
- [§ 15.3 Input
 state](#ref-for-dfn-key-input-source-6 "§ 15.3 Input state")

[Permalink](#dfn-keydown)

**Referenced in:**

- [§ 15. Actions](#ref-for-dfn-keydown-1 "§ 15. Actions")
- [§ 15.6.2 Keyboard
 actions](#ref-for-dfn-keydown-2 "§ 15.6.2 Keyboard actions")

[Permalink](#dfn-keyup)

**Referenced in:**

- [§ 15. Actions](#ref-for-dfn-keyup-1 "§ 15. Actions")

[Permalink](#dfn-create-a-key-input-source)

**Referenced in:**

- [§ 15.2 Input
 sources](#ref-for-dfn-create-a-key-input-source-1 "§ 15.2 Input sources")

[Permalink](#dfn-pointer-input-source)

**Referenced in:**

- [§ 15.2.3 Pointer input
 source](#ref-for-dfn-pointer-input-source-1 "§ 15.2.3 Pointer input source")
 [(2)](#ref-for-dfn-pointer-input-source-2 "Reference 2")
 [(3)](#ref-for-dfn-pointer-input-source-3 "Reference 3")
- [§ 15.3 Input
 state](#ref-for-dfn-pointer-input-source-4 "§ 15.3 Input state")
 [(2)](#ref-for-dfn-pointer-input-source-5 "Reference 2")

[Permalink](#dfn-pointerdown)

**Referenced in:**

- [§ 15. Actions](#ref-for-dfn-pointerdown-1 "§ 15. Actions")
 [(2)](#ref-for-dfn-pointerdown-2 "Reference 2")
 [(3)](#ref-for-dfn-pointerdown-3 "Reference 3")
 [(4)](#ref-for-dfn-pointerdown-4 "Reference 4")

[Permalink](#dfn-pointerup)

**Referenced in:**

- [§ 15. Actions](#ref-for-dfn-pointerup-1 "§ 15. Actions")
 [(2)](#ref-for-dfn-pointerup-2 "Reference 2")
 [(3)](#ref-for-dfn-pointerup-3 "Reference 3")
 [(4)](#ref-for-dfn-pointerup-4 "Reference 4")

[Permalink](#dfn-pointermove)

**Referenced in:**

- [§ 15. Actions](#ref-for-dfn-pointermove-1 "§ 15. Actions")
 [(2)](#ref-for-dfn-pointermove-2 "Reference 2")
 [(3)](#ref-for-dfn-pointermove-3 "Reference 3")
- [§ 15.6.3 Pointer
 actions](#ref-for-dfn-pointermove-4 "§ 15.6.3 Pointer actions")

[Permalink](#dfn-pointercancel)

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-create-a-pointer-input-source)

**Referenced in:**

- [§ 15.2 Input
 sources](#ref-for-dfn-create-a-pointer-input-source-1 "§ 15.2 Input sources")

[Permalink](#dfn-wheel-input-source)

**Referenced in:**

- [§ 15.2.4 Wheel input
 source](#ref-for-dfn-wheel-input-source-1 "§ 15.2.4 Wheel input source")
 [(2)](#ref-for-dfn-wheel-input-source-2 "Reference 2")

[Permalink](#dfn-scroll)

**Referenced in:**

- [§ 15.6.4 Wheel
 actions](#ref-for-dfn-scroll-1 "§ 15.6.4 Wheel actions")

[Permalink](#dfn-create-a-wheel-input-source)

**Referenced in:**

- [§ 15.2 Input
 sources](#ref-for-dfn-create-a-wheel-input-source-1 "§ 15.2 Input sources")

[Permalink](#dfn-input-state)

**Referenced in:**

- [§ 8. Sessions](#ref-for-dfn-input-state-1 "§ 8. Sessions")
- [§ 15.3 Input state](#ref-for-dfn-input-state-2 "§ 15.3 Input state")
 [(2)](#ref-for-dfn-input-state-3 "Reference 2")
 [(3)](#ref-for-dfn-input-state-4 "Reference 3")

[Permalink](#dfn-input-state-map)

**Referenced in:**

- [§ 15.2 Input
 sources](#ref-for-dfn-input-state-map-1 "§ 15.2 Input sources")
- [§ 15.3 Input
 state](#ref-for-dfn-input-state-map-2 "§ 15.3 Input state")
 [(2)](#ref-for-dfn-input-state-map-3 "Reference 2")
 [(3)](#ref-for-dfn-input-state-map-4 "Reference 3")
 [(4)](#ref-for-dfn-input-state-map-5 "Reference 4")
 [(5)](#ref-for-dfn-input-state-map-6 "Reference 5")
 [(6)](#ref-for-dfn-input-state-map-7 "Reference 6")

[Permalink](#dfn-input-cancel-list)

**Referenced in:**

- [§ 15.3 Input
 state](#ref-for-dfn-input-cancel-list-1 "§ 15.3 Input state")
 [(2)](#ref-for-dfn-input-cancel-list-2 "Reference 2")
- [§ 15.6 Dispatching
 actions](#ref-for-dfn-input-cancel-list-3 "§ 15.6 Dispatching actions")
 [(2)](#ref-for-dfn-input-cancel-list-4 "Reference 2")
- [§ 15.8 Release
 Actions](#ref-for-dfn-input-cancel-list-5 "§ 15.8 Release Actions")

[Permalink](#dfn-actions-queue)

**Referenced in:**

- [§ 15.6 Dispatching
 actions](#ref-for-dfn-actions-queue-1 "§ 15.6 Dispatching actions")
 [(2)](#ref-for-dfn-actions-queue-2 "Reference 2")
 [(3)](#ref-for-dfn-actions-queue-3 "Reference 3")

[Permalink](#dfn-get-the-input-state)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-get-the-input-state-1 "§ 12.5.1 Element Click")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-get-the-input-state-2 "§ 12.5.3 Element Send Keys")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-get-the-input-state-3 "§ 15.7 Perform Actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-get-the-input-state-4 "§ 15.8 Release Actions")

[Permalink](#dfn-reset-the-input-state)

**Referenced in:**

- [§ 15.8 Release
 Actions](#ref-for-dfn-reset-the-input-state-1 "§ 15.8 Release Actions")

[Permalink](#dfn-create-an-input-state)

**Referenced in:**

- [§ 15.3 Input
 state](#ref-for-dfn-create-an-input-state-1 "§ 15.3 Input state")

[Permalink](#dfn-add-an-input-source)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-add-an-input-source-1 "§ 12.5.1 Element Click")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-add-an-input-source-2 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-remove-an-input-source)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-remove-an-input-source-1 "§ 12.5.1 Element Click")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-remove-an-input-source-2 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-get-an-input-source)

**Referenced in:**

- [§ 15.3 Input
 state](#ref-for-dfn-get-an-input-source-1 "§ 15.3 Input state")
- [§ 15.6 Dispatching
 actions](#ref-for-dfn-get-an-input-source-2 "§ 15.6 Dispatching actions")

[Permalink](#dfn-get-or-create-an-input-source)

**Referenced in:**

- [§ 15.5 Processing
 actions](#ref-for-dfn-get-or-create-an-input-source-1 "§ 15.5 Processing actions")

[Permalink](#dfn-global-key-state)

**Referenced in:**

- [§ 15.3 Input
 state](#ref-for-dfn-global-key-state-1 "§ 15.3 Input state")

[Permalink](#dfn-get-the-global-key-state)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-get-the-global-key-state-1 "§ 12.5.3 Element Send Keys")
- [§ 15.6 Dispatching
 actions](#ref-for-dfn-get-the-global-key-state-2 "§ 15.6 Dispatching actions")

[Permalink](#dfn-get-a-pointer-id)

**Referenced in:**

- [§ 15.2.3 Pointer input
 source](#ref-for-dfn-get-a-pointer-id-1 "§ 15.2.3 Pointer input source")

[Permalink](#dfn-ticks)

**Referenced in:**

- [§ 15. Actions](#ref-for-dfn-ticks-1 "§ 15. Actions")
 [(2)](#ref-for-dfn-ticks-2 "Reference 2")
 [(3)](#ref-for-dfn-ticks-3 "Reference 3")
 [(4)](#ref-for-dfn-ticks-4 "Reference 4")
 [(5)](#ref-for-dfn-ticks-5 "Reference 5")
 [(6)](#ref-for-dfn-ticks-6 "Reference 6")
 [(7)](#ref-for-dfn-ticks-7 "Reference 7")
 [(8)](#ref-for-dfn-ticks-8 "Reference 8")
 [(9)](#ref-for-dfn-ticks-9 "Reference 9")
 [(10)](#ref-for-dfn-ticks-10 "Reference 10")
 [(11)](#ref-for-dfn-ticks-11 "Reference 11")
 [(12)](#ref-for-dfn-ticks-12 "Reference 12")
 [(13)](#ref-for-dfn-ticks-13 "Reference 13")
 [(14)](#ref-for-dfn-ticks-14 "Reference 14")
- [§ 15.2.1 Null input
 source](#ref-for-dfn-ticks-15 "§ 15.2.1 Null input source")
 [(2)](#ref-for-dfn-ticks-16 "Reference 2")
- [§ 15.4 Ticks](#ref-for-dfn-ticks-17 "§ 15.4 Ticks")
 [(2)](#ref-for-dfn-ticks-18 "Reference 2")
 [(3)](#ref-for-dfn-ticks-19 "Reference 3")
- [§ 15.5 Processing
 actions](#ref-for-dfn-ticks-20 "§ 15.5 Processing actions")
- [§ 15.6 Dispatching
 actions](#ref-for-dfn-ticks-21 "§ 15.6 Dispatching actions")
- [§ 15.6.3 Pointer
 actions](#ref-for-dfn-ticks-22 "§ 15.6.3 Pointer actions")
- [§ 15.6.4 Wheel
 actions](#ref-for-dfn-ticks-23 "§ 15.6.4 Wheel actions")

[Permalink](#dfn-asynchronously-wait)

**Referenced in:**

- [§ 15.6 Dispatching
 actions](#ref-for-dfn-asynchronously-wait-1 "§ 15.6 Dispatching actions")
- [§ 15.6.3 Pointer
 actions](#ref-for-dfn-asynchronously-wait-2 "§ 15.6.3 Pointer actions")
 [(2)](#ref-for-dfn-asynchronously-wait-3 "Reference 2")
- [§ 15.6.4 Wheel
 actions](#ref-for-dfn-asynchronously-wait-4 "§ 15.6.4 Wheel actions")
 [(2)](#ref-for-dfn-asynchronously-wait-5 "Reference 2")

[Permalink](#dfn-perform-implementation-specific-action-dispatch-steps)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-perform-implementation-specific-action-dispatch-steps-1 "§ 12.5.3 Element Send Keys")
- [§ 15.6.2 Keyboard
 actions](#ref-for-dfn-perform-implementation-specific-action-dispatch-steps-2 "§ 15.6.2 Keyboard actions")
 [(2)](#ref-for-dfn-perform-implementation-specific-action-dispatch-steps-3 "Reference 2")
- [§ 15.6.3 Pointer
 actions](#ref-for-dfn-perform-implementation-specific-action-dispatch-steps-4 "§ 15.6.3 Pointer actions")
 [(2)](#ref-for-dfn-perform-implementation-specific-action-dispatch-steps-5 "Reference 2")
 [(3)](#ref-for-dfn-perform-implementation-specific-action-dispatch-steps-6 "Reference 3")
 [(4)](#ref-for-dfn-perform-implementation-specific-action-dispatch-steps-7 "Reference 4")
- [§ 15.6.4 Wheel
 actions](#ref-for-dfn-perform-implementation-specific-action-dispatch-steps-8 "§ 15.6.4 Wheel actions")

[Permalink](#dfn-get-coordinates-relative-to-an-origin)

**Referenced in:**

- [§ 15.6.3 Pointer
 actions](#ref-for-dfn-get-coordinates-relative-to-an-origin-1 "§ 15.6.3 Pointer actions")
- [§ 15.6.4 Wheel
 actions](#ref-for-dfn-get-coordinates-relative-to-an-origin-2 "§ 15.6.4 Wheel actions")

[Permalink](#dfn-extract-an-action-sequence)

**Referenced in:**

- [§ 15.5 Processing
 actions](#ref-for-dfn-extract-an-action-sequence-1 "§ 15.5 Processing actions")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-extract-an-action-sequence-2 "§ 15.7 Perform Actions")

[Permalink](#dfn-process-an-input-source-action-sequence)

**Referenced in:**

- [§ 15.5 Processing
 actions](#ref-for-dfn-process-an-input-source-action-sequence-1 "§ 15.5 Processing actions")

[Permalink](#dfn-default-pointer-parameters)

**Referenced in:**

- [§ 15.5 Processing
 actions](#ref-for-dfn-default-pointer-parameters-1 "§ 15.5 Processing actions")

[Permalink](#dfn-process-pointer-parameters)

**Referenced in:**

- [§ 15.5 Processing
 actions](#ref-for-dfn-process-pointer-parameters-1 "§ 15.5 Processing actions")

[Permalink](#dfn-action-object)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-action-object-1 "§ 12.5.1 Element Click")
 [(2)](#ref-for-dfn-action-object-2 "Reference 2")
 [(3)](#ref-for-dfn-action-object-3 "Reference 3")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-action-object-4 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-action-object-5 "Reference 2")
 [(3)](#ref-for-dfn-action-object-6 "Reference 3")
 [(4)](#ref-for-dfn-action-object-7 "Reference 4")
 [(5)](#ref-for-dfn-action-object-8 "Reference 5")
- [§ 15.3 Input
 state](#ref-for-dfn-action-object-9 "§ 15.3 Input state")
- [§ 15.5 Processing
 actions](#ref-for-dfn-action-object-10 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-action-object-11 "Reference 2")
 [(3)](#ref-for-dfn-action-object-12 "Reference 3")
 [(4)](#ref-for-dfn-action-object-13 "Reference 4")

[Permalink](#dfn-process-a-null-action)

**Referenced in:**

- [§ 15.5 Processing
 actions](#ref-for-dfn-process-a-null-action-1 "§ 15.5 Processing actions")

[Permalink](#dfn-process-a-key-action)

**Referenced in:**

- [§ 15.5 Processing
 actions](#ref-for-dfn-process-a-key-action-1 "§ 15.5 Processing actions")

[Permalink](#dfn-process-a-pointer-action)

**Referenced in:**

- [§ 15.5 Processing
 actions](#ref-for-dfn-process-a-pointer-action-1 "§ 15.5 Processing actions")

[Permalink](#dfn-process-a-wheel-action)

**Referenced in:**

- [§ 15.5 Processing
 actions](#ref-for-dfn-process-a-wheel-action-1 "§ 15.5 Processing actions")

[Permalink](#dfn-process-a-pause-action)

**Referenced in:**

- [§ 15.5 Processing
 actions](#ref-for-dfn-process-a-pause-action-1 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-process-a-pause-action-2 "Reference 2")
 [(3)](#ref-for-dfn-process-a-pause-action-3 "Reference 3")
 [(4)](#ref-for-dfn-process-a-pause-action-4 "Reference 4")

[Permalink](#dfn-process-a-pointer-up-or-pointer-down-action)

**Referenced in:**

- [§ 15.5 Processing
 actions](#ref-for-dfn-process-a-pointer-up-or-pointer-down-action-1 "§ 15.5 Processing actions")

[Permalink](#dfn-process-a-pointer-move-action)

**Referenced in:**

- [§ 15.5 Processing
 actions](#ref-for-dfn-process-a-pointer-move-action-1 "§ 15.5 Processing actions")

[Permalink](#dfn-wait-for-an-action-queue-token)

**Referenced in:**

- [§ 15.6 Dispatching
 actions](#ref-for-dfn-wait-for-an-action-queue-token-1 "§ 15.6 Dispatching actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-wait-for-an-action-queue-token-2 "§ 15.8 Release Actions")

[Permalink](#dfn-dispatch-actions)

**Referenced in:**

- [§ 15.6 Dispatching
 actions](#ref-for-dfn-dispatch-actions-1 "§ 15.6 Dispatching actions")
 [(2)](#ref-for-dfn-dispatch-actions-2 "Reference 2")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-dispatch-actions-3 "§ 15.7 Perform Actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-dispatch-actions-4 "§ 15.8 Release Actions")

[Permalink](#dfn-dispatch-actions-inner)

**Referenced in:**

- [§ 15.6 Dispatching
 actions](#ref-for-dfn-dispatch-actions-inner-1 "§ 15.6 Dispatching actions")

[Permalink](#dfn-computing-the-tick-duration)

**Referenced in:**

- [§ 15.6 Dispatching
 actions](#ref-for-dfn-computing-the-tick-duration-1 "§ 15.6 Dispatching actions")

[Permalink](#dfn-dispatch-tick-actions)

**Referenced in:**

- [§ 15.6 Dispatching
 actions](#ref-for-dfn-dispatch-tick-actions-1 "§ 15.6 Dispatching actions")
 [(2)](#ref-for-dfn-dispatch-tick-actions-2 "Reference 2")
 [(3)](#ref-for-dfn-dispatch-tick-actions-3 "Reference 3")

[Permalink](#dfn-dispatch-a-list-of-actions)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-dispatch-a-list-of-actions-1 "§ 12.5.1 Element Click")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-dispatch-a-list-of-actions-2 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-dispatch-a-list-of-actions-3 "Reference 2")
 [(3)](#ref-for-dfn-dispatch-a-list-of-actions-4 "Reference 3")
 [(4)](#ref-for-dfn-dispatch-a-list-of-actions-5 "Reference 4")
 [(5)](#ref-for-dfn-dispatch-a-list-of-actions-6 "Reference 5")

[Permalink](#dfn-dispatch-a-pause-action)

**Referenced in:**

- [§ 15.6 Dispatching
 actions](#ref-for-dfn-dispatch-a-pause-action-1 "§ 15.6 Dispatching actions")
 [(2)](#ref-for-dfn-dispatch-a-pause-action-2 "Reference 2")
 [(3)](#ref-for-dfn-dispatch-a-pause-action-3 "Reference 3")
 [(4)](#ref-for-dfn-dispatch-a-pause-action-4 "Reference 4")

[Permalink](#dfn-normalized-key-value)

**Referenced in:**

- [§ 15.6.2 Keyboard
 actions](#ref-for-dfn-normalized-key-value-1 "§ 15.6.2 Keyboard actions")
 [(2)](#ref-for-dfn-normalized-key-value-2 "Reference 2")

[Permalink](#dfn-code)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-code-1 "§ 12.5.3 Element Send Keys")
- [§ 15.6.2 Keyboard
 actions](#ref-for-dfn-code-2 "§ 15.6.2 Keyboard actions")
 [(2)](#ref-for-dfn-code-3 "Reference 2")

[Permalink](#dfn-shifted-character)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-shifted-character-1 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-shifted-character-2 "Reference 2")

[Permalink](#dfn-key-location)

**Referenced in:**

- [§ 15.6.2 Keyboard
 actions](#ref-for-dfn-key-location-1 "§ 15.6.2 Keyboard actions")
 [(2)](#ref-for-dfn-key-location-2 "Reference 2")

[Permalink](#dfn-dispatch-a-keydown-action)

**Referenced in:**

- [§ 15.6 Dispatching
 actions](#ref-for-dfn-dispatch-a-keydown-action-1 "§ 15.6 Dispatching actions")

[Permalink](#dfn-dispatch-a-keyup-action)

**Referenced in:**

- [§ 15.6 Dispatching
 actions](#ref-for-dfn-dispatch-a-keyup-action-1 "§ 15.6 Dispatching actions")

[Permalink](#dfn-dispatch-a-pointerdown-action)

**Referenced in:**

- [§ 15.6 Dispatching
 actions](#ref-for-dfn-dispatch-a-pointerdown-action-1 "§ 15.6 Dispatching actions")

[Permalink](#dfn-dispatch-a-pointerup-action)

**Referenced in:**

- [§ 15.6 Dispatching
 actions](#ref-for-dfn-dispatch-a-pointerup-action-1 "§ 15.6 Dispatching actions")

[Permalink](#dfn-dispatch-a-pointermove-action)

**Referenced in:**

- [§ 15.6 Dispatching
 actions](#ref-for-dfn-dispatch-a-pointermove-action-1 "§ 15.6 Dispatching actions")

[Permalink](#dfn-perform-a-pointer-move)

**Referenced in:**

- [§ 15.6.3 Pointer
 actions](#ref-for-dfn-perform-a-pointer-move-1 "§ 15.6.3 Pointer actions")
 [(2)](#ref-for-dfn-perform-a-pointer-move-2 "Reference 2")

[Permalink](#dfn-dispatch-a-pointercancel-action)

**Referenced in:**

- [§ 15.6 Dispatching
 actions](#ref-for-dfn-dispatch-a-pointercancel-action-1 "§ 15.6 Dispatching actions")

[Permalink](#dfn-dispatch-a-scroll-action)

**Referenced in:**

- [§ 15.6 Dispatching
 actions](#ref-for-dfn-dispatch-a-scroll-action-1 "§ 15.6 Dispatching actions")

[Permalink](#dfn-perform-a-scroll)

**Referenced in:**

- [§ 15.6.4 Wheel
 actions](#ref-for-dfn-perform-a-scroll-1 "§ 15.6.4 Wheel actions")
 [(2)](#ref-for-dfn-perform-a-scroll-2 "Reference 2")

[Permalink](#dfn-perform-actions)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-perform-actions-1 "§ 6.5 Endpoints")

[Permalink](#dfn-release-actions)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-release-actions-1 "§ 6.5 Endpoints")
- [§ 15.8 Release
 Actions](#ref-for-dfn-release-actions-2 "§ 15.8 Release Actions")

[Permalink](#dfn-user-prompt-message)

**Referenced in:**

- [§ 6.6 Errors](#ref-for-dfn-user-prompt-message-1 "§ 6.6 Errors")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-user-prompt-message-2 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-user-prompt-message-3 "Reference 2")

[Permalink](#dfn-get-the-active-user-prompt)

**Referenced in:**

- [§ 16. User
 prompts](#ref-for-dfn-get-the-active-user-prompt-1 "§ 16. User prompts")

[Permalink](#dfn-current-user-prompt)

**Referenced in:**

- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-current-user-prompt-1 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-current-user-prompt-2 "Reference 2")
 [(3)](#ref-for-dfn-current-user-prompt-3 "Reference 3")
 [(4)](#ref-for-dfn-current-user-prompt-4 "Reference 4")
 [(5)](#ref-for-dfn-current-user-prompt-5 "Reference 5")
 [(6)](#ref-for-dfn-current-user-prompt-6 "Reference 6")
 [(7)](#ref-for-dfn-current-user-prompt-7 "Reference 7")
- [§ 16.2 Dismiss
 Alert](#ref-for-dfn-current-user-prompt-8 "§ 16.2 Dismiss Alert")
 [(2)](#ref-for-dfn-current-user-prompt-9 "Reference 2")
 [(3)](#ref-for-dfn-current-user-prompt-10 "Reference 3")
- [§ 16.3 Accept
 Alert](#ref-for-dfn-current-user-prompt-11 "§ 16.3 Accept Alert")
 [(2)](#ref-for-dfn-current-user-prompt-12 "Reference 2")
- [§ 16.4 Get Alert
 Text](#ref-for-dfn-current-user-prompt-13 "§ 16.4 Get Alert Text")
 [(2)](#ref-for-dfn-current-user-prompt-14 "Reference 2")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-current-user-prompt-15 "§ 16.5 Send Alert Text")
 [(2)](#ref-for-dfn-current-user-prompt-16 "Reference 2")
 [(3)](#ref-for-dfn-current-user-prompt-17 "Reference 3")

[Permalink](#dfn-dismissed)

**Referenced in:**

- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-dismissed-1 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-dismissed-2 "Reference 2")
 [(3)](#ref-for-dfn-dismissed-3 "Reference 3")
- [§ 16.2 Dismiss
 Alert](#ref-for-dfn-dismissed-4 "§ 16.2 Dismiss Alert")
 [(2)](#ref-for-dfn-dismissed-5 "Reference 2")
 [(3)](#ref-for-dfn-dismissed-6 "Reference 3")

[Permalink](#dfn-accepting)

**Referenced in:**

- [§ 16. User prompts](#ref-for-dfn-accepting-1 "§ 16. User prompts")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-accepting-2 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-accepting-3 "Reference 2")
 [(3)](#ref-for-dfn-accepting-4 "Reference 3")
- [§ 16.2 Dismiss
 Alert](#ref-for-dfn-accepting-5 "§ 16.2 Dismiss Alert")
- [§ 16.3 Accept Alert](#ref-for-dfn-accepting-6 "§ 16.3 Accept Alert")

[Permalink](#dfn-user-prompt-handler)

**Referenced in:**

- [§ 6.6 Errors](#ref-for-dfn-user-prompt-handler-1 "§ 6.6 Errors")
- [§ 7.
 Capabilities](#ref-for-dfn-user-prompt-handler-2 "§ 7. Capabilities")
- [§ 8.1 Global
 State](#ref-for-dfn-user-prompt-handler-3 "§ 8.1 Global State")
- [§ 16. User
 prompts](#ref-for-dfn-user-prompt-handler-4 "§ 16. User prompts")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-user-prompt-handler-5 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-user-prompt-handler-6 "Reference 2")
 [(3)](#ref-for-dfn-user-prompt-handler-7 "Reference 3")
 [(4)](#ref-for-dfn-user-prompt-handler-8 "Reference 4")
 [(5)](#ref-for-dfn-user-prompt-handler-9 "Reference 5")
 [(6)](#ref-for-dfn-user-prompt-handler-10 "Reference 6")
 [(7)](#ref-for-dfn-user-prompt-handler-11 "Reference 7")
 [(8)](#ref-for-dfn-user-prompt-handler-12 "Reference 8")
 [(9)](#ref-for-dfn-user-prompt-handler-13 "Reference 9")
 [(10)](#ref-for-dfn-user-prompt-handler-14 "Reference 10")
 [(11)](#ref-for-dfn-user-prompt-handler-15 "Reference 11")
 [(12)](#ref-for-dfn-user-prompt-handler-16 "Reference 12")
 [(13)](#ref-for-dfn-user-prompt-handler-17 "Reference 13")

[Permalink](#dfn-prompt-handler-configuration)

**Referenced in:**

- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-prompt-handler-configuration-1 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-prompt-handler-configuration-2 "Reference 2")
 [(3)](#ref-for-dfn-prompt-handler-configuration-3 "Reference 3")
 [(4)](#ref-for-dfn-prompt-handler-configuration-4 "Reference 4")

[Permalink](#dfn-handler)

**Referenced in:**

- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-handler-1 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-handler-2 "Reference 2")
 [(3)](#ref-for-dfn-handler-3 "Reference 3")
 [(4)](#ref-for-dfn-handler-4 "Reference 4")
 [(5)](#ref-for-dfn-handler-5 "Reference 5")
 [(6)](#ref-for-dfn-handler-6 "Reference 6")
 [(7)](#ref-for-dfn-handler-7 "Reference 7")
 [(8)](#ref-for-dfn-handler-8 "Reference 8")

[Permalink](#dfn-notify)

**Referenced in:**

- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-notify-1 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-notify-2 "Reference 2")
 [(3)](#ref-for-dfn-notify-3 "Reference 3")
 [(4)](#ref-for-dfn-notify-4 "Reference 4")
 [(5)](#ref-for-dfn-notify-5 "Reference 5")
 [(6)](#ref-for-dfn-notify-6 "Reference 6")
 [(7)](#ref-for-dfn-notify-7 "Reference 7")

[Permalink](#dfn-serialize-a-prompt-handler-configuration)

**Referenced in:**

- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-serialize-a-prompt-handler-configuration-1 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-serialize-a-prompt-handler-configuration-2 "Reference 2")

[Permalink](#dfn-known-prompt-handlers)

**Referenced in:**

- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-known-prompt-handlers-1 "§ 16.1 User Prompt Handler")

[Permalink](#dfn-handler-key)

**Referenced in:**

- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-handler-key-1 "§ 16.1 User Prompt Handler")

[Permalink](#dfn-valid-prompt-types)

**Referenced in:**

- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-valid-prompt-types-1 "§ 16.1 User Prompt Handler")

[Permalink](#dfn-deserialize-as-an-unhandled-prompt-behavior)

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-dfn-deserialize-as-an-unhandled-prompt-behavior-1 "§ 7.2 Processing capabilities")

[Permalink](#dfn-check-user-prompt-handler-matches)

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-dfn-check-user-prompt-handler-matches-1 "§ 7.2 Processing capabilities")

[Permalink](#dfn-update-the-user-prompt-handler)

**Referenced in:**

- [§ 8.1 Global
 State](#ref-for-dfn-update-the-user-prompt-handler-1 "§ 8.1 Global State")

[Permalink](#dfn-serialize-the-user-prompt-handler)

**Referenced in:**

- [§ 8.1 Global
 State](#ref-for-dfn-serialize-the-user-prompt-handler-1 "§ 8.1 Global State")

[Permalink](#dfn-annotated-unexpected-alert-open-error)

**Referenced in:**

- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-annotated-unexpected-alert-open-error-1 "§ 16.1 User Prompt Handler")

[Permalink](#dfn-get-the-prompt-handler)
[exported]

**Referenced in:**

- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-get-the-prompt-handler-1 "§ 16.1 User Prompt Handler")

[Permalink](#dfn-handle-any-user-prompts)

**Referenced in:**

- [§ 10.1 Navigate
 To](#ref-for-dfn-handle-any-user-prompts-1 "§ 10.1 Navigate To")
- [§ 10.2 Get Current
 URL](#ref-for-dfn-handle-any-user-prompts-2 "§ 10.2 Get Current URL")
- [§ 10.3 Back](#ref-for-dfn-handle-any-user-prompts-3 "§ 10.3 Back")
 [(2)](#ref-for-dfn-handle-any-user-prompts-4 "Reference 2")
- [§ 10.4
 Forward](#ref-for-dfn-handle-any-user-prompts-5 "§ 10.4 Forward")
 [(2)](#ref-for-dfn-handle-any-user-prompts-6 "Reference 2")
- [§ 10.5
 Refresh](#ref-for-dfn-handle-any-user-prompts-7 "§ 10.5 Refresh")
- [§ 10.6 Get
 Title](#ref-for-dfn-handle-any-user-prompts-8 "§ 10.6 Get Title")
- [§ 11.2 Close
 Window](#ref-for-dfn-handle-any-user-prompts-9 "§ 11.2 Close Window")
- [§ 11.5 New
 Window](#ref-for-dfn-handle-any-user-prompts-10 "§ 11.5 New Window")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-handle-any-user-prompts-11 "§ 11.6 Switch To Frame")
 [(2)](#ref-for-dfn-handle-any-user-prompts-12 "Reference 2")
 [(3)](#ref-for-dfn-handle-any-user-prompts-13 "Reference 3")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-dfn-handle-any-user-prompts-14 "§ 11.7 Switch To Parent Frame")
- [§ 11.8.1 Get Window
 Rect](#ref-for-dfn-handle-any-user-prompts-15 "§ 11.8.1 Get Window Rect")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-handle-any-user-prompts-16 "§ 11.8.2 Set Window Rect")
- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-handle-any-user-prompts-17 "§ 11.8.3 Maximize Window")
- [§ 11.8.4 Minimize
 Window](#ref-for-dfn-handle-any-user-prompts-18 "§ 11.8.4 Minimize Window")
- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-handle-any-user-prompts-19 "§ 11.8.5 Fullscreen Window")
- [§ 12.3.2 Find
 Element](#ref-for-dfn-handle-any-user-prompts-20 "§ 12.3.2 Find Element")
- [§ 12.3.3 Find
 Elements](#ref-for-dfn-handle-any-user-prompts-21 "§ 12.3.3 Find Elements")
- [§ 12.3.4 Find Element From
 Element](#ref-for-dfn-handle-any-user-prompts-22 "§ 12.3.4 Find Element From Element")
- [§ 12.3.5 Find Elements From
 Element](#ref-for-dfn-handle-any-user-prompts-23 "§ 12.3.5 Find Elements From Element")
- [§ 12.3.6 Find Element From Shadow
 Root](#ref-for-dfn-handle-any-user-prompts-24 "§ 12.3.6 Find Element From Shadow Root")
- [§ 12.3.7 Find Elements From Shadow
 Root](#ref-for-dfn-handle-any-user-prompts-25 "§ 12.3.7 Find Elements From Shadow Root")
- [§ 12.3.8 Get Active
 Element](#ref-for-dfn-handle-any-user-prompts-26 "§ 12.3.8 Get Active Element")
- [§ 12.3.9 Get Element Shadow
 Root](#ref-for-dfn-handle-any-user-prompts-27 "§ 12.3.9 Get Element Shadow Root")
- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-handle-any-user-prompts-28 "§ 12.4.1 Is Element Selected")
- [§ 12.4.2 Get Element
 Attribute](#ref-for-dfn-handle-any-user-prompts-29 "§ 12.4.2 Get Element Attribute")
- [§ 12.4.3 Get Element
 Property](#ref-for-dfn-handle-any-user-prompts-30 "§ 12.4.3 Get Element Property")
- [§ 12.4.4 Get Element CSS
 Value](#ref-for-dfn-handle-any-user-prompts-31 "§ 12.4.4 Get Element CSS Value")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-handle-any-user-prompts-32 "§ 12.4.5 Get Element Text")
- [§ 12.4.6 Get Element Tag
 Name](#ref-for-dfn-handle-any-user-prompts-33 "§ 12.4.6 Get Element Tag Name")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-handle-any-user-prompts-34 "§ 12.4.7 Get Element Rect")
- [§ 12.4.8 Is Element
 Enabled](#ref-for-dfn-handle-any-user-prompts-35 "§ 12.4.8 Is Element Enabled")
- [§ 12.4.9 Get Computed
 Role](#ref-for-dfn-handle-any-user-prompts-36 "§ 12.4.9 Get Computed Role")
- [§ 12.4.10 Get Computed
 Label](#ref-for-dfn-handle-any-user-prompts-37 "§ 12.4.10 Get Computed Label")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-handle-any-user-prompts-38 "§ 12.5.1 Element Click")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-handle-any-user-prompts-39 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-handle-any-user-prompts-40 "§ 12.5.3 Element Send Keys")
- [§ 13.1 Get Page
 Source](#ref-for-dfn-handle-any-user-prompts-41 "§ 13.1 Get Page Source")
- [§ 13.2.1 Execute
 Script](#ref-for-dfn-handle-any-user-prompts-42 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-handle-any-user-prompts-43 "§ 13.2.2 Execute Async Script")
- [§ 14.1 Get All
 Cookies](#ref-for-dfn-handle-any-user-prompts-44 "§ 14.1 Get All Cookies")
- [§ 14.2 Get Named
 Cookie](#ref-for-dfn-handle-any-user-prompts-45 "§ 14.2 Get Named Cookie")
- [§ 14.3 Add
 Cookie](#ref-for-dfn-handle-any-user-prompts-46 "§ 14.3 Add Cookie")
- [§ 14.4 Delete
 Cookie](#ref-for-dfn-handle-any-user-prompts-47 "§ 14.4 Delete Cookie")
- [§ 14.5 Delete All
 Cookies](#ref-for-dfn-handle-any-user-prompts-48 "§ 14.5 Delete All Cookies")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-handle-any-user-prompts-49 "§ 15.7 Perform Actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-handle-any-user-prompts-50 "§ 15.8 Release Actions")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-handle-any-user-prompts-51 "§ 17.2 Take Element Screenshot")
- [§ 18.1 Print
 Page](#ref-for-dfn-handle-any-user-prompts-52 "§ 18.1 Print Page")

[Permalink](#dfn-dismiss-alert)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-dismiss-alert-1 "§ 6.5 Endpoints")
- [§ 16.2 Dismiss
 Alert](#ref-for-dfn-dismiss-alert-2 "§ 16.2 Dismiss Alert")

[Permalink](#dfn-accept-alert)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-accept-alert-1 "§ 6.5 Endpoints")

[Permalink](#dfn-get-alert-text)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-get-alert-text-1 "§ 6.5 Endpoints")

[Permalink](#dfn-send-alert-text)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-send-alert-text-1 "§ 6.5 Endpoints")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-send-alert-text-2 "§ 16.5 Send Alert Text")

[Permalink](#dfn-draw-a-bounding-box-from-the-framebuffer)

**Referenced in:**

- [§ 17.1 Take
 Screenshot](#ref-for-dfn-draw-a-bounding-box-from-the-framebuffer-1 "§ 17.1 Take Screenshot")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-draw-a-bounding-box-from-the-framebuffer-2 "§ 17.2 Take Element Screenshot")

[Permalink](#dfn-encoding-a-canvas-as-base64)

**Referenced in:**

- [§ 17.1 Take
 Screenshot](#ref-for-dfn-encoding-a-canvas-as-base64-1 "§ 17.1 Take Screenshot")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-encoding-a-canvas-as-base64-2 "§ 17.2 Take Element Screenshot")

[Permalink](#dfn-take-screenshot)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-take-screenshot-1 "§ 6.5 Endpoints")
- [§ 17. Screen
 capture](#ref-for-dfn-take-screenshot-2 "§ 17. Screen capture")

[Permalink](#dfn-take-element-screenshot)

**Referenced in:**

- [§ 6.5
 Endpoints](#ref-for-dfn-take-element-screenshot-1 "§ 6.5 Endpoints")
- [§ 17. Screen
 capture](#ref-for-dfn-take-element-screenshot-2 "§ 17. Screen capture")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-take-element-screenshot-3 "§ 17.2 Take Element Screenshot")

[Permalink](#dfn-parse-a-page-range)

**Referenced in:**

- [§ 18.1 Print
 Page](#ref-for-dfn-parse-a-page-range-1 "§ 18.1 Print Page")

[Permalink](#dfn-equivalent-to-an-empty-string)

**Referenced in:**

- [§ 18.
 Print](#ref-for-dfn-equivalent-to-an-empty-string-1 "§ 18. Print")
 [(2)](#ref-for-dfn-equivalent-to-an-empty-string-2 "Reference 2")

[Permalink](#dfn-parse-as-an-integer)

**Referenced in:**

- [§ 18. Print](#ref-for-dfn-parse-as-an-integer-1 "§ 18. Print")
 [(2)](#ref-for-dfn-parse-as-an-integer-2 "Reference 2")
 [(3)](#ref-for-dfn-parse-as-an-integer-3 "Reference 3")

[Permalink](#dfn-print-page)

**Referenced in:**

- [§ 6.5 Endpoints](#ref-for-dfn-print-page-1 "§ 6.5 Endpoints")

[Permalink](#dfn-element-displayed-state)

**Referenced in:**

- [§ C. Element
 displayedness](#ref-for-dfn-element-displayed-state-1 "§ C. Element displayedness")
 [(2)](#ref-for-dfn-element-displayed-state-2 "Reference 2")

[Permalink](#dfn-wai-aria-role)

**Referenced in:**

- [§ 12.4.9 Get Computed
 Role](#ref-for-dfn-wai-aria-role-1 "§ 12.4.9 Get Computed Role")

[Permalink](#dfn-accessible-name)

**Referenced in:**

- [§ 12.4.10 Get Computed
 Label](#ref-for-dfn-accessible-name-1 "§ 12.4.10 Get Computed Label")

[Permalink](#dfn-accessible-name-and-description-computation)

**Referenced in:**

- [§ 12.4.10 Get Computed
 Label](#ref-for-dfn-accessible-name-and-description-computation-1 "§ 12.4.10 Get Computed Label")

[Permalink](#dfn-directives)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-directives-1 "§ 13.2 Executing Script")

[Permalink](#dfn-blocked-by-content-security-policy)

**Referenced in:**

- [§ 10.
 Navigation](#ref-for-dfn-blocked-by-content-security-policy-1 "§ 10. Navigation")

[Permalink](#dfn-base64-encode)

**Referenced in:**

- [§ 18.1 Print Page](#ref-for-dfn-base64-encode-1 "§ 18.1 Print Page")

[Permalink](#dfn-fragment-serializing-algorithm)

**Referenced in:**

- [§ 13.1 Get Page
 Source](#ref-for-dfn-fragment-serializing-algorithm-1 "§ 13.1 Get Page Source")

[Permalink](#dfn-innerhtml-idl-attribute)

**Referenced in:**

- [§ 12.5.2 Element
 Clear](#ref-for-dfn-innerhtml-idl-attribute-1 "§ 12.5.2 Element Clear")
 [(2)](#ref-for-dfn-innerhtml-idl-attribute-2 "Reference 2")

[Permalink](#dfn-serializing-to-string)

**Referenced in:**

- [§ 13.1 Get Page
 Source](#ref-for-dfn-serializing-to-string-1 "§ 13.1 Get Page Source")

[Permalink](#dfn-activation-trigger)

**Referenced in:**

- [§ 15.4 Ticks](#ref-for-dfn-activation-trigger-1 "§ 15.4 Ticks")

[Permalink](#dfn-click-event)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-click-event-1 "§ 12.5.1 Element Click")

[Permalink](#dfn-mousedown-event)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-mousedown-event-1 "§ 12.5.1 Element Click")

[Permalink](#dfn-mousemove-event)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-mousemove-event-1 "§ 12.5.1 Element Click")

[Permalink](#dfn-mouseover-event)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-mouseover-event-1 "§ 12.5.1 Element Click")

[Permalink](#dfn-mouseup-event)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-mouseup-event-1 "§ 12.5.1 Element Click")

[Permalink](#dfn-modifier-key)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-modifier-key-1 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-iterable)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-iterable-1 "§ 13.2 Executing Script")

[Permalink](#dfn-completion)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-completion-1 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-completion-2 "Reference 2")
 [(3)](#ref-for-dfn-completion-3 "Reference 3")

[Permalink](#dfn-createresolvingfunctions)

**Referenced in:**

- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-createresolvingfunctions-1 "§ 13.2.2 Execute Async Script")

[Permalink](#dfn-directive-prologue)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-directive-prologue-1 "§ 13.2 Executing Script")

[Permalink](#dfn-early-error)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-early-error-1 "§ 13.2 Executing Script")

[Permalink](#dfn-function)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-function-1 "§ 13.2 Executing Script")

[Permalink](#dfn-functionbody)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-functionbody-1 "§ 13.2 Executing Script")

[Permalink](#dfn-functioncreate)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-functioncreate-1 "§ 13.2 Executing Script")

[Permalink](#dfn-get)

**Referenced in:**

- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-get-1 "§ 13.2.2 Execute Async Script")

[Permalink](#dfn-global-environment)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-global-environment-1 "§ 13.2 Executing Script")

[Permalink](#dfn-iscallable)

**Referenced in:**

- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-iscallable-1 "§ 13.2.2 Execute Async Script")

[Permalink](#dfn-own-properties)

**Referenced in:**

- [§ 7.1 Proxy](#ref-for-dfn-own-properties-1 "§ 7.1 Proxy")
 [(2)](#ref-for-dfn-own-properties-2 "Reference 2")
 [(3)](#ref-for-dfn-own-properties-3 "Reference 3")
 [(4)](#ref-for-dfn-own-properties-4 "Reference 4")
 [(5)](#ref-for-dfn-own-properties-5 "Reference 5")
 [(6)](#ref-for-dfn-own-properties-6 "Reference 6")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-own-properties-7 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-own-properties-8 "Reference 2")
 [(3)](#ref-for-dfn-own-properties-9 "Reference 3")
 [(4)](#ref-for-dfn-own-properties-10 "Reference 4")
- [§ 11. Contexts](#ref-for-dfn-own-properties-11 "§ 11. Contexts")
 [(2)](#ref-for-dfn-own-properties-12 "Reference 2")
 [(3)](#ref-for-dfn-own-properties-13 "Reference 3")
 [(4)](#ref-for-dfn-own-properties-14 "Reference 4")
- [§ 12. Elements](#ref-for-dfn-own-properties-15 "§ 12. Elements")
 [(2)](#ref-for-dfn-own-properties-16 "Reference 2")
- [§ 12.2 Shadow
 Roots](#ref-for-dfn-own-properties-17 "§ 12.2 Shadow Roots")
 [(2)](#ref-for-dfn-own-properties-18 "Reference 2")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-own-properties-19 "§ 12.5.3 Element Send Keys")
- [§ 13.2 Executing
 Script](#ref-for-dfn-own-properties-20 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-own-properties-21 "Reference 2")

[Permalink](#dfn-promise)

**Referenced in:**

- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-promise-1 "§ 13.2.2 Execute Async Script")

[Permalink](#dfn-promiseresolve)

**Referenced in:**

- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-promiseresolve-1 "§ 13.2.2 Execute Async Script")

[Permalink](#dfn-ecmascript-type)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-ecmascript-type-1 "§ 12. Elements")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-ecmascript-type-2 "§ 13.2.2 Execute Async Script")

[Permalink](#dfn-use-strict-directive)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-use-strict-directive-1 "§ 13.2 Executing Script")

[Permalink](#dfn-parseint)

**Referenced in:**

- [§ 18. Print](#ref-for-dfn-parseint-1 "§ 18. Print")

[Permalink](#dfn-realm)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-realm-1 "§ 13.2 Executing Script")

[Permalink](#dfn-call)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-call-1 "§ 12. Elements")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-call-2 "§ 12.4.5 Get Element Text")
- [§ 13.2 Executing
 Script](#ref-for-dfn-call-3 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-call-4 "Reference 2")
- [§ C. Element
 displayedness](#ref-for-dfn-call-5 "§ C. Element displayedness")

[Permalink](#dfn-getownproperty)

**Referenced in:**

- [§ 6.1 Algorithms](#ref-for-dfn-getownproperty-1 "§ 6.1 Algorithms")
 [(2)](#ref-for-dfn-getownproperty-2 "Reference 2")

[Permalink](#dfn-getproperty)

**Referenced in:**

- [§ 12.4.3 Get Element
 Property](#ref-for-dfn-getproperty-1 "§ 12.4.3 Get Element Property")

[Permalink](#dfn-index-of)

**Referenced in:**

- [§ 17. Screen capture](#ref-for-dfn-index-of-1 "§ 17. Screen capture")

[Permalink](#dfn-put)

**Referenced in:**

- [§ 6.1 Algorithms](#ref-for-dfn-put-1 "§ 6.1 Algorithms")

[Permalink](#dfn-substring)

**Referenced in:**

- [§ 17. Screen
 capture](#ref-for-dfn-substring-1 "§ 17. Screen capture")

[Permalink](#dfn-array)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-dfn-array-1 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-array-2 "Reference 2")
 [(3)](#ref-for-dfn-array-3 "Reference 3")
 [(4)](#ref-for-dfn-array-4 "Reference 4")
- [§ 15.5 Processing
 actions](#ref-for-dfn-array-5 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-array-6 "Reference 2")
- [§ 18.1 Print Page](#ref-for-dfn-array-7 "§ 18.1 Print Page")
 [(2)](#ref-for-dfn-array-8 "Reference 2")
 [(3)](#ref-for-dfn-array-9 "Reference 3")

[Permalink](#dfn-boolean)

**Referenced in:**

- [§ 4. Interface](#ref-for-dfn-boolean-1 "§ 4. Interface")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-boolean-2 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-boolean-3 "Reference 2")
 [(3)](#ref-for-dfn-boolean-4 "Reference 3")
 [(4)](#ref-for-dfn-boolean-5 "Reference 4")
 [(5)](#ref-for-dfn-boolean-6 "Reference 5")
- [§ 13.2 Executing
 Script](#ref-for-dfn-boolean-7 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-boolean-8 "Reference 2")
- [§ 18.1 Print Page](#ref-for-dfn-boolean-9 "§ 18.1 Print Page")
 [(2)](#ref-for-dfn-boolean-10 "Reference 2")

[Permalink](#dfn-list)

**Referenced in:**

- [§ 7.1 Proxy](#ref-for-dfn-list-1 "§ 7.1 Proxy")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-list-2 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-list-3 "Reference 2")
 [(3)](#ref-for-dfn-list-4 "Reference 3")
 [(4)](#ref-for-dfn-list-5 "Reference 4")
- [§ 11.4 Get Window
 Handles](#ref-for-dfn-list-6 "§ 11.4 Get Window Handles")
- [§ 12.3 Retrieval](#ref-for-dfn-list-7 "§ 12.3 Retrieval")
 [(2)](#ref-for-dfn-list-8 "Reference 2")
- [§ 13.2 Executing
 Script](#ref-for-dfn-list-9 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-list-10 "Reference 2")
 [(3)](#ref-for-dfn-list-11 "Reference 3")
- [§ 14.1 Get All
 Cookies](#ref-for-dfn-list-12 "§ 14.1 Get All Cookies")
- [§ 15.5 Processing
 actions](#ref-for-dfn-list-13 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-list-14 "Reference 2")
 [(3)](#ref-for-dfn-list-15 "Reference 3")

[Permalink](#dfn-maximum-safe-integer)

**Referenced in:**

- [§ 9. Timeouts](#ref-for-dfn-maximum-safe-integer-1 "§ 9. Timeouts")
- [§ 14.3 Add
 Cookie](#ref-for-dfn-maximum-safe-integer-2 "§ 14.3 Add Cookie")

[Permalink](#dfn-null)

**Referenced in:**

- [§ 6.3 Processing model](#ref-for-dfn-null-1 "§ 6.3 Processing model")
 [(2)](#ref-for-dfn-null-2 "Reference 2")
- [§ 6.7 Extensions](#ref-for-dfn-null-3 "§ 6.7 Extensions")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-null-4 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-null-5 "Reference 2")
 [(3)](#ref-for-dfn-null-6 "Reference 3")
 [(4)](#ref-for-dfn-null-7 "Reference 4")
 [(5)](#ref-for-dfn-null-8 "Reference 5")
 [(6)](#ref-for-dfn-null-9 "Reference 6")
 [(7)](#ref-for-dfn-null-10 "Reference 7")
 [(8)](#ref-for-dfn-null-11 "Reference 8")
 [(9)](#ref-for-dfn-null-12 "Reference 9")
 [(10)](#ref-for-dfn-null-13 "Reference 10")
 [(11)](#ref-for-dfn-null-14 "Reference 11")
 [(12)](#ref-for-dfn-null-15 "Reference 12")
- [§ 8.1 Global State](#ref-for-dfn-null-16 "§ 8.1 Global State")
- [§ 8.2 New Session](#ref-for-dfn-null-17 "§ 8.2 New Session")
- [§ 8.3 Delete Session](#ref-for-dfn-null-18 "§ 8.3 Delete Session")
- [§ 9.2 Set Timeouts](#ref-for-dfn-null-19 "§ 9.2 Set Timeouts")
- [§ 10. Navigation](#ref-for-dfn-null-20 "§ 10. Navigation")
 [(2)](#ref-for-dfn-null-21 "Reference 2")
 [(3)](#ref-for-dfn-null-22 "Reference 3")
 [(4)](#ref-for-dfn-null-23 "Reference 4")
- [§ 10.1 Navigate To](#ref-for-dfn-null-24 "§ 10.1 Navigate To")
- [§ 10.3 Back](#ref-for-dfn-null-25 "§ 10.3 Back")
- [§ 10.4 Forward](#ref-for-dfn-null-26 "§ 10.4 Forward")
- [§ 10.5 Refresh](#ref-for-dfn-null-27 "§ 10.5 Refresh")
- [§ 11. Contexts](#ref-for-dfn-null-28 "§ 11. Contexts")
- [§ 11.3 Switch To
 Window](#ref-for-dfn-null-29 "§ 11.3 Switch To Window")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-null-30 "§ 11.6 Switch To Frame")
 [(2)](#ref-for-dfn-null-31 "Reference 2")
 [(3)](#ref-for-dfn-null-32 "Reference 3")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-dfn-null-33 "§ 11.7 Switch To Parent Frame")
 [(2)](#ref-for-dfn-null-34 "Reference 2")
 [(3)](#ref-for-dfn-null-35 "Reference 3")
- [§ 12.3.1.5 XPath](#ref-for-dfn-null-36 "§ 12.3.1.5 XPath")
 [(2)](#ref-for-dfn-null-37 "Reference 2")
- [§ 12.3.2 Find Element](#ref-for-dfn-null-38 "§ 12.3.2 Find Element")
- [§ 12.3.3 Find
 Elements](#ref-for-dfn-null-39 "§ 12.3.3 Find Elements")
- [§ 12.4.2 Get Element
 Attribute](#ref-for-dfn-null-40 "§ 12.4.2 Get Element Attribute")
- [§ 12.4.3 Get Element
 Property](#ref-for-dfn-null-41 "§ 12.4.3 Get Element Property")
- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-null-42 "§ 12.4.5 Get Element Text")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-null-43 "§ 12.5.1 Element Click")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-null-44 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-null-45 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-null-46 "Reference 2")
 [(3)](#ref-for-dfn-null-47 "Reference 3")
- [§ 13.1 Get Page
 Source](#ref-for-dfn-null-48 "§ 13.1 Get Page Source")
 [(2)](#ref-for-dfn-null-49 "Reference 2")
- [§ 13.2 Executing
 Script](#ref-for-dfn-null-50 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-null-51 "Reference 2")
 [(3)](#ref-for-dfn-null-52 "Reference 3")
 [(4)](#ref-for-dfn-null-53 "Reference 4")
 [(5)](#ref-for-dfn-null-54 "Reference 5")
- [§ 14.3 Add Cookie](#ref-for-dfn-null-55 "§ 14.3 Add Cookie")
 [(2)](#ref-for-dfn-null-56 "Reference 2")
- [§ 14.4 Delete Cookie](#ref-for-dfn-null-57 "§ 14.4 Delete Cookie")
- [§ 14.5 Delete All
 Cookies](#ref-for-dfn-null-58 "§ 14.5 Delete All Cookies")
- [§ 15.5 Processing
 actions](#ref-for-dfn-null-59 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-null-60 "Reference 2")
- [§ 15.6 Dispatching
 actions](#ref-for-dfn-null-61 "§ 15.6 Dispatching actions")
 [(2)](#ref-for-dfn-null-62 "Reference 2")
- [§ 15.6.1 General
 actions](#ref-for-dfn-null-63 "§ 15.6.1 General actions")
- [§ 15.6.2 Keyboard
 actions](#ref-for-dfn-null-64 "§ 15.6.2 Keyboard actions")
 [(2)](#ref-for-dfn-null-65 "Reference 2")
- [§ 15.6.3 Pointer
 actions](#ref-for-dfn-null-66 "§ 15.6.3 Pointer actions")
 [(2)](#ref-for-dfn-null-67 "Reference 2")
 [(3)](#ref-for-dfn-null-68 "Reference 3")
 [(4)](#ref-for-dfn-null-69 "Reference 4")
 [(5)](#ref-for-dfn-null-70 "Reference 5")
 [(6)](#ref-for-dfn-null-71 "Reference 6")
- [§ 15.6.4 Wheel
 actions](#ref-for-dfn-null-72 "§ 15.6.4 Wheel actions")
- [§ 15.7 Perform
 Actions](#ref-for-dfn-null-73 "§ 15.7 Perform Actions")
- [§ 15.8 Release
 Actions](#ref-for-dfn-null-74 "§ 15.8 Release Actions")
- [§ 16. User prompts](#ref-for-dfn-null-75 "§ 16. User prompts")
- [§ 16.2 Dismiss Alert](#ref-for-dfn-null-76 "§ 16.2 Dismiss Alert")
- [§ 16.3 Accept Alert](#ref-for-dfn-null-77 "§ 16.3 Accept Alert")
- [§ 16.4 Get Alert Text](#ref-for-dfn-null-78 "§ 16.4 Get Alert Text")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-null-79 "§ 16.5 Send Alert Text")

[Permalink](#dfn-number)

**Referenced in:**

- [§ 3. Terminology](#ref-for-dfn-number-1 "§ 3. Terminology")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-number-2 "§ 11.8.2 Set Window Rect")
 [(2)](#ref-for-dfn-number-3 "Reference 2")
- [§ 13.2 Executing
 Script](#ref-for-dfn-number-4 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-number-5 "Reference 2")
- [§ 15.5 Processing
 actions](#ref-for-dfn-number-6 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-number-7 "Reference 2")
 [(3)](#ref-for-dfn-number-8 "Reference 3")
 [(4)](#ref-for-dfn-number-9 "Reference 4")
 [(5)](#ref-for-dfn-number-10 "Reference 5")
 [(6)](#ref-for-dfn-number-11 "Reference 6")
 [(7)](#ref-for-dfn-number-12 "Reference 7")
 [(8)](#ref-for-dfn-number-13 "Reference 8")
 [(9)](#ref-for-dfn-number-14 "Reference 9")
 [(10)](#ref-for-dfn-number-15 "Reference 10")
 [(11)](#ref-for-dfn-number-16 "Reference 11")
 [(12)](#ref-for-dfn-number-17 "Reference 12")
 [(13)](#ref-for-dfn-number-18 "Reference 13")
 [(14)](#ref-for-dfn-number-19 "Reference 14")
- [§ 18. Print](#ref-for-dfn-number-20 "§ 18. Print")
 [(2)](#ref-for-dfn-number-21 "Reference 2")
- [§ 18.1 Print Page](#ref-for-dfn-number-22 "§ 18.1 Print Page")
 [(2)](#ref-for-dfn-number-23 "Reference 2")
 [(3)](#ref-for-dfn-number-24 "Reference 3")

[Permalink](#dfn-object)

**Referenced in:**

- [§ 6.1 Algorithms](#ref-for-dfn-object-1 "§ 6.1 Algorithms")
- [§ 6.3 Processing
 model](#ref-for-dfn-object-2 "§ 6.3 Processing model")
 [(2)](#ref-for-dfn-object-3 "Reference 2")
 [(3)](#ref-for-dfn-object-4 "Reference 3")
 [(4)](#ref-for-dfn-object-5 "Reference 4")
- [§ 6.6 Errors](#ref-for-dfn-object-6 "§ 6.6 Errors")
 [(2)](#ref-for-dfn-object-7 "Reference 2")
- [§ 7. Capabilities](#ref-for-dfn-object-8 "§ 7. Capabilities")
 [(2)](#ref-for-dfn-object-9 "Reference 2")
- [§ 7.1 Proxy](#ref-for-dfn-object-10 "§ 7.1 Proxy")
 [(2)](#ref-for-dfn-object-11 "Reference 2")
 [(3)](#ref-for-dfn-object-12 "Reference 3")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-object-13 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-object-14 "Reference 2")
 [(3)](#ref-for-dfn-object-15 "Reference 3")
 [(4)](#ref-for-dfn-object-16 "Reference 4")
 [(5)](#ref-for-dfn-object-17 "Reference 5")
 [(6)](#ref-for-dfn-object-18 "Reference 6")
 [(7)](#ref-for-dfn-object-19 "Reference 7")
 [(8)](#ref-for-dfn-object-20 "Reference 8")
 [(9)](#ref-for-dfn-object-21 "Reference 9")
- [§ 8.1 Global State](#ref-for-dfn-object-22 "§ 8.1 Global State")
- [§ 8.2 New Session](#ref-for-dfn-object-23 "§ 8.2 New Session")
- [§ 8.4 Status](#ref-for-dfn-object-24 "§ 8.4 Status")
- [§ 11. Contexts](#ref-for-dfn-object-25 "§ 11. Contexts")
 [(2)](#ref-for-dfn-object-26 "Reference 2")
 [(3)](#ref-for-dfn-object-27 "Reference 3")
 [(4)](#ref-for-dfn-object-28 "Reference 4")
 [(5)](#ref-for-dfn-object-29 "Reference 5")
- [§ 11.5 New Window](#ref-for-dfn-object-30 "§ 11.5 New Window")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-object-31 "§ 11.6 Switch To Frame")
- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-object-32 "§ 11.8 Resizing and positioning windows")
- [§ 12. Elements](#ref-for-dfn-object-33 "§ 12. Elements")
 [(2)](#ref-for-dfn-object-34 "Reference 2")
 [(3)](#ref-for-dfn-object-35 "Reference 3")
- [§ 12.2 Shadow Roots](#ref-for-dfn-object-36 "§ 12.2 Shadow Roots")
 [(2)](#ref-for-dfn-object-37 "Reference 2")
 [(3)](#ref-for-dfn-object-38 "Reference 3")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-object-39 "§ 12.4.7 Get Element Rect")
- [§ 13.2 Executing
 Script](#ref-for-dfn-object-40 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-object-41 "Reference 2")
 [(3)](#ref-for-dfn-object-42 "Reference 3")
 [(4)](#ref-for-dfn-object-43 "Reference 4")
 [(5)](#ref-for-dfn-object-44 "Reference 5")
 [(6)](#ref-for-dfn-object-45 "Reference 6")
 [(7)](#ref-for-dfn-object-46 "Reference 7")
- [§ 13.2.2 Execute Async
 Script](#ref-for-dfn-object-47 "§ 13.2.2 Execute Async Script")
- [§ 14. Cookies](#ref-for-dfn-object-48 "§ 14. Cookies")
- [§ 14.3 Add Cookie](#ref-for-dfn-object-49 "§ 14.3 Add Cookie")
- [§ 15.5 Processing
 actions](#ref-for-dfn-object-50 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-object-51 "Reference 2")
 [(3)](#ref-for-dfn-object-52 "Reference 3")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-object-53 "§ 16.1 User Prompt Handler")
- [§ 18.1 Print Page](#ref-for-dfn-object-54 "§ 18.1 Print Page")
 [(2)](#ref-for-dfn-object-55 "Reference 2")

[Permalink](#dfn-parse)

**Referenced in:**

- [§ 6.1 Algorithms](#ref-for-dfn-parse-1 "§ 6.1 Algorithms")

[Permalink](#dfn-string)

**Referenced in:**

- [§ 7.1 Proxy](#ref-for-dfn-string-1 "§ 7.1 Proxy")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-string-2 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-string-3 "Reference 2")
 [(3)](#ref-for-dfn-string-4 "Reference 3")
 [(4)](#ref-for-dfn-string-5 "Reference 4")
- [§ 10. Navigation](#ref-for-dfn-string-6 "§ 10. Navigation")
- [§ 11. Contexts](#ref-for-dfn-string-7 "§ 11. Contexts")
 [(2)](#ref-for-dfn-string-8 "Reference 2")
 [(3)](#ref-for-dfn-string-9 "Reference 3")
- [§ 12. Elements](#ref-for-dfn-string-10 "§ 12. Elements")
- [§ 12.2 Shadow Roots](#ref-for-dfn-string-11 "§ 12.2 Shadow Roots")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-string-12 "§ 12.5.3 Element Send Keys")
- [§ 13.2 Executing
 Script](#ref-for-dfn-string-13 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-string-14 "Reference 2")
 [(3)](#ref-for-dfn-string-15 "Reference 3")
- [§ 15.5 Processing
 actions](#ref-for-dfn-string-16 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-string-17 "Reference 2")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-string-18 "§ 16.1 User Prompt Handler")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-string-19 "§ 16.5 Send Alert Text")
- [§ 18. Print](#ref-for-dfn-string-20 "§ 18. Print")
 [(2)](#ref-for-dfn-string-21 "Reference 2")
- [§ 18.1 Print Page](#ref-for-dfn-string-22 "§ 18.1 Print Page")

[Permalink](#dfn-stringify)

**Referenced in:**

- [§ 6.1 Algorithms](#ref-for-dfn-stringify-1 "§ 6.1 Algorithms")

[Permalink](#dfn-tointeger)

**Referenced in:**

- [§ 3. Terminology](#ref-for-dfn-tointeger-1 "§ 3. Terminology")

[Permalink](#dfn-undefined)

**Referenced in:**

- [§ 6.4 Routing
 requests](#ref-for-dfn-undefined-1 "§ 6.4 Routing requests")
- [§ 7.1 Proxy](#ref-for-dfn-undefined-2 "§ 7.1 Proxy")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-undefined-3 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-dfn-undefined-4 "Reference 2")
 [(3)](#ref-for-dfn-undefined-5 "Reference 3")
 [(4)](#ref-for-dfn-undefined-6 "Reference 4")
- [§ 11.3 Switch To
 Window](#ref-for-dfn-undefined-7 "§ 11.3 Switch To Window")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-undefined-8 "§ 11.8.2 Set Window Rect")
 [(2)](#ref-for-dfn-undefined-9 "Reference 2")
 [(3)](#ref-for-dfn-undefined-10 "Reference 3")
 [(4)](#ref-for-dfn-undefined-11 "Reference 4")
- [§ 12.3.2 Find
 Element](#ref-for-dfn-undefined-12 "§ 12.3.2 Find Element")
- [§ 12.3.3 Find
 Elements](#ref-for-dfn-undefined-13 "§ 12.3.3 Find Elements")
- [§ 12.3.4 Find Element From
 Element](#ref-for-dfn-undefined-14 "§ 12.3.4 Find Element From Element")
- [§ 12.3.5 Find Elements From
 Element](#ref-for-dfn-undefined-15 "§ 12.3.5 Find Elements From Element")
- [§ 12.3.6 Find Element From Shadow
 Root](#ref-for-dfn-undefined-16 "§ 12.3.6 Find Element From Shadow Root")
- [§ 12.3.7 Find Elements From Shadow
 Root](#ref-for-dfn-undefined-17 "§ 12.3.7 Find Elements From Shadow Root")
- [§ 12.4 State](#ref-for-dfn-undefined-18 "§ 12.4 State")
 [(2)](#ref-for-dfn-undefined-19 "Reference 2")
 [(3)](#ref-for-dfn-undefined-20 "Reference 3")
- [§ 12.4.3 Get Element
 Property](#ref-for-dfn-undefined-21 "§ 12.4.3 Get Element Property")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-undefined-22 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-undefined-23 "Reference 2")
- [§ 13.2 Executing
 Script](#ref-for-dfn-undefined-24 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-undefined-25 "Reference 2")
- [§ 14. Cookies](#ref-for-dfn-undefined-26 "§ 14. Cookies")
- [§ 15.5 Processing
 actions](#ref-for-dfn-undefined-27 "§ 15.5 Processing actions")
 [(2)](#ref-for-dfn-undefined-28 "Reference 2")
 [(3)](#ref-for-dfn-undefined-29 "Reference 3")
 [(4)](#ref-for-dfn-undefined-30 "Reference 4")
 [(5)](#ref-for-dfn-undefined-31 "Reference 5")
 [(6)](#ref-for-dfn-undefined-32 "Reference 6")
 [(7)](#ref-for-dfn-undefined-33 "Reference 7")
 [(8)](#ref-for-dfn-undefined-34 "Reference 8")
 [(9)](#ref-for-dfn-undefined-35 "Reference 9")
 [(10)](#ref-for-dfn-undefined-36 "Reference 10")
 [(11)](#ref-for-dfn-undefined-37 "Reference 11")
 [(12)](#ref-for-dfn-undefined-38 "Reference 12")
 [(13)](#ref-for-dfn-undefined-39 "Reference 13")
 [(14)](#ref-for-dfn-undefined-40 "Reference 14")
 [(15)](#ref-for-dfn-undefined-41 "Reference 15")
 [(16)](#ref-for-dfn-undefined-42 "Reference 16")
 [(17)](#ref-for-dfn-undefined-43 "Reference 17")
 [(18)](#ref-for-dfn-undefined-44 "Reference 18")
 [(19)](#ref-for-dfn-undefined-45 "Reference 19")
 [(20)](#ref-for-dfn-undefined-46 "Reference 20")
 [(21)](#ref-for-dfn-undefined-47 "Reference 21")
 [(22)](#ref-for-dfn-undefined-48 "Reference 22")
 [(23)](#ref-for-dfn-undefined-49 "Reference 23")
 [(24)](#ref-for-dfn-undefined-50 "Reference 24")
 [(25)](#ref-for-dfn-undefined-51 "Reference 25")
 [(26)](#ref-for-dfn-undefined-52 "Reference 26")
 [(27)](#ref-for-dfn-undefined-53 "Reference 27")
 [(28)](#ref-for-dfn-undefined-54 "Reference 28")
- [§ 15.6 Dispatching
 actions](#ref-for-dfn-undefined-55 "§ 15.6 Dispatching actions")
 [(2)](#ref-for-dfn-undefined-56 "Reference 2")
- [§ 15.6.2 Keyboard
 actions](#ref-for-dfn-undefined-57 "§ 15.6.2 Keyboard actions")
- [§ 15.6.3 Pointer
 actions](#ref-for-dfn-undefined-58 "§ 15.6.3 Pointer actions")
- [§ 15.6.4 Wheel
 actions](#ref-for-dfn-undefined-59 "§ 15.6.4 Wheel actions")

[Permalink](#dfn-utf-8-encode)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-utf-8-encode-1 "§ 6.3 Processing model")

[Permalink](#dfn-body)

**Referenced in:**

- [§ 6.3 Processing model](#ref-for-dfn-body-1 "§ 6.3 Processing model")
 [(2)](#ref-for-dfn-body-2 "Reference 2")
- [§ 12.1 Interactability](#ref-for-dfn-body-3 "§ 12.1 Interactability")

[Permalink](#dfn-default-user-agent-value)

**Referenced in:**

- [§ 7.
 Capabilities](#ref-for-dfn-default-user-agent-value-1 "§ 7. Capabilities")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-default-user-agent-value-2 "§ 7.2 Processing capabilities")

[Permalink](#dfn-header)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-header-1 "§ 6.3 Processing model")

[Permalink](#dfn-header-name)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-header-name-1 "§ 6.3 Processing model")

[Permalink](#dfn-header-value)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-header-value-1 "§ 6.3 Processing model")

[Permalink](#dfn-local-scheme)

**Referenced in:**

- [§ 10.1 Navigate To](#ref-for-dfn-local-scheme-1 "§ 10.1 Navigate To")

[Permalink](#dfn-method)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-method-1 "§ 6.3 Processing model")
 [(2)](#ref-for-dfn-method-2 "Reference 2")
- [§ 6.4 Routing
 requests](#ref-for-dfn-method-3 "§ 6.4 Routing requests")
- [§ 6.5 Endpoints](#ref-for-dfn-method-4 "§ 6.5 Endpoints")

[Permalink](#dfn-http-response)

**Referenced in:**

- [§ 6.2 Commands](#ref-for-dfn-http-response-1 "§ 6.2 Commands")
- [§ 6.3 Processing
 model](#ref-for-dfn-http-response-2 "§ 6.3 Processing model")
- [§ 6.6 Errors](#ref-for-dfn-http-response-3 "§ 6.6 Errors")
 [(2)](#ref-for-dfn-http-response-4 "Reference 2")
- [§ 10. Navigation](#ref-for-dfn-http-response-5 "§ 10. Navigation")
 [(2)](#ref-for-dfn-http-response-6 "Reference 2")
 [(3)](#ref-for-dfn-http-response-7 "Reference 3")

[Permalink](#dfn-http-request)

**Referenced in:**

- [§ 6.2 Commands](#ref-for-dfn-http-request-1 "§ 6.2 Commands")
- [§ 6.3 Processing
 model](#ref-for-dfn-http-request-2 "§ 6.3 Processing model")
 [(2)](#ref-for-dfn-http-request-3 "Reference 2")
 [(3)](#ref-for-dfn-http-request-4 "Reference 3")
- [§ 6.4 Routing
 requests](#ref-for-dfn-http-request-5 "§ 6.4 Routing requests")
- [§ 8. Sessions](#ref-for-dfn-http-request-6 "§ 8. Sessions")

[Permalink](#dfn-set-header)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-set-header-1 "§ 6.3 Processing model")

[Permalink](#dfn-http-status)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-http-status-1 "§ 6.3 Processing model")
- [§ 6.6 Errors](#ref-for-dfn-http-status-2 "§ 6.6 Errors")
 [(2)](#ref-for-dfn-http-status-3 "Reference 2")
- [§ 10. Navigation](#ref-for-dfn-http-status-4 "§ 10. Navigation")

[Permalink](#dfn-status-message)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-status-message-1 "§ 6.3 Processing model")

[Permalink](#dfn-fullscreen-an-element)

**Referenced in:**

- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-fullscreen-an-element-1 "§ 11.8.5 Fullscreen Window")

[Permalink](#dfn-support-fullscreen)

**Referenced in:**

- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-support-fullscreen-1 "§ 11.8.5 Fullscreen Window")

[Permalink](#dfn-fully-exit-fullscreen)

**Referenced in:**

- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-fully-exit-fullscreen-1 "§ 11.8.2 Set Window Rect")
- [§ 11.8.3 Maximize
 Window](#ref-for-dfn-fully-exit-fullscreen-2 "§ 11.8.3 Maximize Window")
- [§ 11.8.4 Minimize
 Window](#ref-for-dfn-fully-exit-fullscreen-3 "§ 11.8.4 Minimize Window")

[Permalink](#dfn-2d-context-creation-algorithm)

**Referenced in:**

- [§ 17. Screen
 capture](#ref-for-dfn-2d-context-creation-algorithm-1 "§ 17. Screen capture")

[Permalink](#dfn-a-serialization-of-the-bitmap-as-a-file)

**Referenced in:**

- [§ 17. Screen
 capture](#ref-for-dfn-a-serialization-of-the-bitmap-as-a-file-1 "§ 17. Screen capture")

[Permalink](#dfn-api-value)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-api-value-1 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-active-document)

**Referenced in:**

- [§ 6.6 Errors](#ref-for-dfn-active-document-1 "§ 6.6 Errors")
- [§ 10.1 Navigate
 To](#ref-for-dfn-active-document-2 "§ 10.1 Navigate To")
 [(2)](#ref-for-dfn-active-document-3 "Reference 2")
 [(3)](#ref-for-dfn-active-document-4 "Reference 3")
- [§ 10.2 Get Current
 URL](#ref-for-dfn-active-document-5 "§ 10.2 Get Current URL")
- [§ 10.5 Refresh](#ref-for-dfn-active-document-6 "§ 10.5 Refresh")
- [§ 10.6 Get Title](#ref-for-dfn-active-document-7 "§ 10.6 Get Title")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-active-document-8 "§ 11.6 Switch To Frame")
- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-active-document-9 "§ 11.8 Resizing and positioning windows")
 [(2)](#ref-for-dfn-active-document-10 "Reference 2")
- [§ 11.8.5 Fullscreen
 Window](#ref-for-dfn-active-document-11 "§ 11.8.5 Fullscreen Window")
- [§ 12. Elements](#ref-for-dfn-active-document-12 "§ 12. Elements")
 [(2)](#ref-for-dfn-active-document-13 "Reference 2")
 [(3)](#ref-for-dfn-active-document-14 "Reference 3")
- [§ 12.1
 Interactability](#ref-for-dfn-active-document-15 "§ 12.1 Interactability")
- [§ 12.2 Shadow
 Roots](#ref-for-dfn-active-document-16 "§ 12.2 Shadow Roots")
- [§ 12.4.4 Get Element CSS
 Value](#ref-for-dfn-active-document-17 "§ 12.4.4 Get Element CSS Value")
- [§ 12.4.8 Is Element
 Enabled](#ref-for-dfn-active-document-18 "§ 12.4.8 Is Element Enabled")
- [§ 13.1 Get Page
 Source](#ref-for-dfn-active-document-19 "§ 13.1 Get Page Source")
 [(2)](#ref-for-dfn-active-document-20 "Reference 2")
- [§ 13.2 Executing
 Script](#ref-for-dfn-active-document-21 "§ 13.2 Executing Script")
- [§ 14. Cookies](#ref-for-dfn-active-document-22 "§ 14. Cookies")
 [(2)](#ref-for-dfn-active-document-23 "Reference 2")
- [§ 14.1 Get All
 Cookies](#ref-for-dfn-active-document-24 "§ 14.1 Get All Cookies")
- [§ 14.2 Get Named
 Cookie](#ref-for-dfn-active-document-25 "§ 14.2 Get Named Cookie")
- [§ 14.3 Add
 Cookie](#ref-for-dfn-active-document-26 "§ 14.3 Add Cookie")
 [(2)](#ref-for-dfn-active-document-27 "Reference 2")
 [(3)](#ref-for-dfn-active-document-28 "Reference 3")
- [§ 16. User
 prompts](#ref-for-dfn-active-document-29 "§ 16. User prompts")

[Permalink](#dfn-active-element)

**Referenced in:**

- [§ 12.3.8 Get Active
 Element](#ref-for-dfn-active-element-1 "§ 12.3.8 Get Active Element")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-active-element-2 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-associated-window)

**Referenced in:**

- [§ 11.6 Switch To
 Frame](#ref-for-dfn-associated-window-1 "§ 11.6 Switch To Frame")
- [§ 12.4 State](#ref-for-dfn-associated-window-2 "§ 12.4 State")
- [§ 13.2 Executing
 Script](#ref-for-dfn-associated-window-3 "§ 13.2 Executing Script")

[Permalink](#dfn-boolean-attribute)

**Referenced in:**

- [§ 12.4.2 Get Element
 Attribute](#ref-for-dfn-boolean-attribute-1 "§ 12.4.2 Get Element Attribute")
 [(2)](#ref-for-dfn-boolean-attribute-2 "Reference 2")

[Permalink](#dfn-browsing-contexts)

**Referenced in:**

- [§ 8. Sessions](#ref-for-dfn-browsing-contexts-1 "§ 8. Sessions")
- [§ 10.
 Navigation](#ref-for-dfn-browsing-contexts-2 "§ 10. Navigation")
- [§ 11. Contexts](#ref-for-dfn-browsing-contexts-3 "§ 11. Contexts")
 [(2)](#ref-for-dfn-browsing-contexts-4 "Reference 2")
 [(3)](#ref-for-dfn-browsing-contexts-5 "Reference 3")
 [(4)](#ref-for-dfn-browsing-contexts-6 "Reference 4")
 [(5)](#ref-for-dfn-browsing-contexts-7 "Reference 5")
 [(6)](#ref-for-dfn-browsing-contexts-8 "Reference 6")
 [(7)](#ref-for-dfn-browsing-contexts-9 "Reference 7")
 [(8)](#ref-for-dfn-browsing-contexts-10 "Reference 8")
 [(9)](#ref-for-dfn-browsing-contexts-11 "Reference 9")
- [§ 11.3 Switch To
 Window](#ref-for-dfn-browsing-contexts-12 "§ 11.3 Switch To Window")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-browsing-contexts-13 "§ 11.6 Switch To Frame")
- [§ 13.2 Executing
 Script](#ref-for-dfn-browsing-contexts-14 "§ 13.2 Executing Script")
- [§ 15.4 Ticks](#ref-for-dfn-browsing-contexts-15 "§ 15.4 Ticks")
- [§ 16. User
 prompts](#ref-for-dfn-browsing-contexts-16 "§ 16. User prompts")

[Permalink](#dfn-browsing-context-group)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-dfn-browsing-context-group-1 "§ 12. Elements")
 [(2)](#ref-for-dfn-browsing-context-group-2 "Reference 2")
 [(3)](#ref-for-dfn-browsing-context-group-3 "Reference 3")

[Permalink](#dfn-candidate-for-constraint-validation)

**Referenced in:**

- [§ 12.5.2 Element
 Clear](#ref-for-dfn-candidate-for-constraint-validation-1 "§ 12.5.2 Element Clear")

[Permalink](#dfn-canvas-context-mode)

**Referenced in:**

- [§ 17. Screen
 capture](#ref-for-dfn-canvas-context-mode-1 "§ 17. Screen capture")

[Permalink](#dfn-checkbox)

**Referenced in:**

- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-checkbox-1 "§ 12.4.1 Is Element Selected")
 [(2)](#ref-for-dfn-checkbox-2 "Reference 2")

[Permalink](#dfn-checkedness)

**Referenced in:**

- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-checkedness-1 "§ 12.4.1 Is Element Selected")
- [§ 12.5 Interaction](#ref-for-dfn-checkedness-2 "§ 12.5 Interaction")

[Permalink](#dfn-child-browsing-context)

**Referenced in:**

- [§ 11.6 Switch To
 Frame](#ref-for-dfn-child-browsing-context-1 "§ 11.6 Switch To Frame")

[Permalink](#dfn-close)

**Referenced in:**

- [§ 8.1 Global State](#ref-for-dfn-close-1 "§ 8.1 Global State")
 [(2)](#ref-for-dfn-close-2 "Reference 2")
- [§ 11.2 Close Window](#ref-for-dfn-close-3 "§ 11.2 Close Window")

[Permalink](#dfn-cookie-averse-document-object)

**Referenced in:**

- [§ 14.3 Add
 Cookie](#ref-for-dfn-cookie-averse-document-object-1 "§ 14.3 Add Cookie")

[Permalink](#dfn-dirty-checkedness-flag)

**Referenced in:**

- [§ 12.5
 Interaction](#ref-for-dfn-dirty-checkedness-flag-1 "§ 12.5 Interaction")

[Permalink](#dfn-dirty-value-flag)

**Referenced in:**

- [§ 12.5
 Interaction](#ref-for-dfn-dirty-value-flag-1 "§ 12.5 Interaction")
 [(2)](#ref-for-dfn-dirty-value-flag-2 "Reference 2")

[Permalink](#dfn-actually-disabled)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-dfn-actually-disabled-1 "§ 12.1 Interactability")
 [(2)](#ref-for-dfn-actually-disabled-2 "Reference 2")

[Permalink](#dfn-document-readiness)

**Referenced in:**

- [§ 10.
 Navigation](#ref-for-dfn-document-readiness-1 "§ 10. Navigation")
 [(2)](#ref-for-dfn-document-readiness-2 "Reference 2")
 [(3)](#ref-for-dfn-document-readiness-3 "Reference 3")

[Permalink](#dfn-element-context)

**Referenced in:**

- [§ 12.4 State](#ref-for-dfn-element-context-1 "§ 12.4 State")
 [(2)](#ref-for-dfn-element-context-2 "Reference 2")
 [(3)](#ref-for-dfn-element-context-3 "Reference 3")
 [(4)](#ref-for-dfn-element-context-4 "Reference 4")
 [(5)](#ref-for-dfn-element-context-5 "Reference 5")
 [(6)](#ref-for-dfn-element-context-6 "Reference 6")

[Permalink](#dfn-enumerated-attribute)

**Referenced in:**

- [§ 12.3.1 Locator
 strategies](#ref-for-dfn-enumerated-attribute-1 "§ 12.3.1 Locator strategies")

[Permalink](#dfn-event-loop)

**Referenced in:**

- [§ 16. User prompts](#ref-for-dfn-event-loop-1 "§ 16. User prompts")
 [(2)](#ref-for-dfn-event-loop-2 "Reference 2")

[Permalink](#dfn-file-upload-state)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-file-upload-state-1 "§ 12. Elements")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-file-upload-state-2 "§ 12.5.1 Element Click")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-file-upload-state-3 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-file-upload-state-4 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-focusing-steps)

**Referenced in:**

- [§ 11.5 New Window](#ref-for-dfn-focusing-steps-1 "§ 11.5 New Window")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-focusing-steps-2 "§ 12.5.1 Element Click")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-focusing-steps-3 "§ 12.5.2 Element Clear")
 [(2)](#ref-for-dfn-focusing-steps-4 "Reference 2")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-focusing-steps-5 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-focusable-area)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-dfn-focusable-area-1 "§ 12.1 Interactability")

[Permalink](#dfn-window-getownproperty)

**Referenced in:**

- [§ 11.6 Switch To
 Frame](#ref-for-dfn-window-getownproperty-1 "§ 11.6 Switch To Frame")

[Permalink](#dfn-selected-files)

**Referenced in:**

- [§ 12.5
 Interaction](#ref-for-dfn-selected-files-1 "§ 12.5 Interaction")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-selected-files-2 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-selected-files-3 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-selected-files-4 "Reference 2")

[Permalink](#dfn-joint-session-history)

**Referenced in:**

- [§ 10.3 Back](#ref-for-dfn-joint-session-history-1 "§ 10.3 Back")
- [§ 10.4
 Forward](#ref-for-dfn-joint-session-history-2 "§ 10.4 Forward")

[Permalink](#dfn-matured)

**Referenced in:**

- [§ 10. Navigation](#ref-for-dfn-matured-1 "§ 10. Navigation")
 [(2)](#ref-for-dfn-matured-2 "Reference 2")

[Permalink](#dfn-mutable)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-mutable-1 "§ 12. Elements")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-mutable-2 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-navigating)

**Referenced in:**

- [§ 6.6 Errors](#ref-for-dfn-navigating-1 "§ 6.6 Errors")
- [§ 7. Capabilities](#ref-for-dfn-navigating-2 "§ 7. Capabilities")
- [§ 7.2 Processing
 capabilities](#ref-for-dfn-navigating-3 "§ 7.2 Processing capabilities")
- [§ 10. Navigation](#ref-for-dfn-navigating-4 "§ 10. Navigation")
- [§ 10.1 Navigate To](#ref-for-dfn-navigating-5 "§ 10.1 Navigate To")
 [(2)](#ref-for-dfn-navigating-6 "Reference 2")
 [(3)](#ref-for-dfn-navigating-7 "Reference 3")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-navigating-8 "§ 12.5.1 Element Click")
 [(2)](#ref-for-dfn-navigating-9 "Reference 2")
 [(3)](#ref-for-dfn-navigating-10 "Reference 3")

[Permalink](#dfn-origin-clean)

**Referenced in:**

- [§ 17. Screen
 capture](#ref-for-dfn-origin-clean-1 "§ 17. Screen capture")

[Permalink](#dfn-an-overridden-reload)

**Referenced in:**

- [§ 10.5 Refresh](#ref-for-dfn-an-overridden-reload-1 "§ 10.5 Refresh")

[Permalink](#dfn-parent-browsing-context)

**Referenced in:**

- [§ 11.
 Contexts](#ref-for-dfn-parent-browsing-context-1 "§ 11. Contexts")

[Permalink](#dfn-unpaused)

**Referenced in:**

- [§ 16. User prompts](#ref-for-dfn-unpaused-1 "§ 16. User prompts")

[Permalink](#dfn-prompting-to-unload)

**Referenced in:**

- [§ 8.1 Global
 State](#ref-for-dfn-prompting-to-unload-1 "§ 8.1 Global State")

[Permalink](#dfn-radio-button)

**Referenced in:**

- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-radio-button-1 "§ 12.4.1 Is Element Selected")
 [(2)](#ref-for-dfn-radio-button-2 "Reference 2")

[Permalink](#dfn-raw-value)

**Referenced in:**

- [§ 12.5 Interaction](#ref-for-dfn-raw-value-1 "§ 12.5 Interaction")

[Permalink](#dfn-refresh-state-pragma-directive)

**Referenced in:**

- [§ 10.1 Navigate
 To](#ref-for-dfn-refresh-state-pragma-directive-1 "§ 10.1 Navigate To")

[Permalink](#dfn-reset-algorithms)

**Referenced in:**

- [§ 12.5
 Interaction](#ref-for-dfn-reset-algorithms-1 "§ 12.5 Interaction")
 [(2)](#ref-for-dfn-reset-algorithms-2 "Reference 2")

[Permalink](#dfn-resettable-elements)

**Referenced in:**

- [§ 6.6 Errors](#ref-for-dfn-resettable-elements-1 "§ 6.6 Errors")
- [§ 12.5
 Interaction](#ref-for-dfn-resettable-elements-2 "§ 12.5 Interaction")

[Permalink](#dfn-run-the-animation-frame-callbacks)

**Referenced in:**

- [§ 17.1 Take
 Screenshot](#ref-for-dfn-run-the-animation-frame-callbacks-1 "§ 17.1 Take Screenshot")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-run-the-animation-frame-callbacks-2 "§ 17.2 Take Element Screenshot")
- [§ 18.1 Print
 Page](#ref-for-dfn-run-the-animation-frame-callbacks-3 "§ 18.1 Print Page")

[Permalink](#dfn-satisfies-its-constraints)

**Referenced in:**

- [§ 12.5.2 Element
 Clear](#ref-for-dfn-satisfies-its-constraints-1 "§ 12.5.2 Element Clear")

[Permalink](#dfn-selectedness)

**Referenced in:**

- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-selectedness-1 "§ 12.4.1 Is Element Selected")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-selectedness-2 "§ 12.5.1 Element Click")
 [(2)](#ref-for-dfn-selectedness-3 "Reference 2")
 [(3)](#ref-for-dfn-selectedness-4 "Reference 3")
 [(4)](#ref-for-dfn-selectedness-5 "Reference 4")

[Permalink](#dfn-simple-dialog)

**Referenced in:**

- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-simple-dialog-1 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-dfn-simple-dialog-2 "Reference 2")
 [(3)](#ref-for-dfn-simple-dialog-3 "Reference 3")
 [(4)](#ref-for-dfn-simple-dialog-4 "Reference 4")
 [(5)](#ref-for-dfn-simple-dialog-5 "Reference 5")
- [§ 16.2 Dismiss
 Alert](#ref-for-dfn-simple-dialog-6 "§ 16.2 Dismiss Alert")

[Permalink](#dfn-steps-to-fire-beforeunload)

**Referenced in:**

- [§ 16. User
 prompts](#ref-for-dfn-steps-to-fire-beforeunload-1 "§ 16. User prompts")

[Permalink](#dfn-suffering-from-bad-input)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-suffering-from-bad-input-1 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-traverse-the-history-by-a-delta)

**Referenced in:**

- [§ 10.3
 Back](#ref-for-dfn-traverse-the-history-by-a-delta-1 "§ 10.3 Back")
- [§ 10.4
 Forward](#ref-for-dfn-traverse-the-history-by-a-delta-2 "§ 10.4 Forward")

[Permalink](#dfn-unfocusing-steps)

**Referenced in:**

- [§ 12.5.2 Element
 Clear](#ref-for-dfn-unfocusing-steps-1 "§ 12.5.2 Element Clear")
 [(2)](#ref-for-dfn-unfocusing-steps-2 "Reference 2")

[Permalink](#dfn-user-prompts)

**Referenced in:**

- [§ 11.3 Switch To
 Window](#ref-for-dfn-user-prompts-1 "§ 11.3 Switch To Window")
- [§ 13.2 Executing
 Script](#ref-for-dfn-user-prompts-2 "§ 13.2 Executing Script")
- [§ 16. User prompts](#ref-for-dfn-user-prompts-3 "§ 16. User prompts")
 [(2)](#ref-for-dfn-user-prompts-4 "Reference 2")
 [(3)](#ref-for-dfn-user-prompts-5 "Reference 3")
 [(4)](#ref-for-dfn-user-prompts-6 "Reference 4")
 [(5)](#ref-for-dfn-user-prompts-7 "Reference 5")
 [(6)](#ref-for-dfn-user-prompts-8 "Reference 6")
 [(7)](#ref-for-dfn-user-prompts-9 "Reference 7")
- [§ 16.2 Dismiss
 Alert](#ref-for-dfn-user-prompts-10 "§ 16.2 Dismiss Alert")
- [§ 16.5 Send Alert
 Text](#ref-for-dfn-user-prompts-11 "§ 16.5 Send Alert Text")

[Permalink](#dfn-value)

**Referenced in:**

- [§ 12.5 Interaction](#ref-for-dfn-value-1 "§ 12.5 Interaction")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-value-2 "§ 12.5.2 Element Clear")

[Permalink](#dfn-value-mode-flag)

**Referenced in:**

- [§ 12.5
 Interaction](#ref-for-dfn-value-mode-flag-1 "§ 12.5 Interaction")

[Permalink](#dfn-value-sanitization-algorithm)

**Referenced in:**

- [§ 12.5
 Interaction](#ref-for-dfn-value-sanitization-algorithm-1 "§ 12.5 Interaction")

[Permalink](#dfn-window)

**Referenced in:**

- [§ 11. Contexts](#ref-for-dfn-window-1 "§ 11. Contexts")
 [(2)](#ref-for-dfn-window-2 "Reference 2")

[Permalink](#dfn-window-open-steps)

**Referenced in:**

- [§ 11.5 New
 Window](#ref-for-dfn-window-open-steps-1 "§ 11.5 New Window")

[Permalink](#dfn-windowproxy)

**Referenced in:**

- [§ 11. Contexts](#ref-for-dfn-windowproxy-1 "§ 11. Contexts")
- [§ 11.6 Switch To
 Frame](#ref-for-dfn-windowproxy-2 "§ 11.6 Switch To Frame")
- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-windowproxy-3 "§ 11.8 Resizing and positioning windows")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-windowproxy-4 "§ 11.8.2 Set Window Rect")
 [(2)](#ref-for-dfn-windowproxy-5 "Reference 2")
- [§ 13.2 Executing
 Script](#ref-for-dfn-windowproxy-6 "§ 13.2 Executing Script")
 [(2)](#ref-for-dfn-windowproxy-7 "Reference 2")

[Permalink](#dfn-set-selection-range)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-set-selection-range-1 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-window-confirm)

**Referenced in:**

- [§ 16.5 Send Alert
 Text](#ref-for-dfn-window-confirm-1 "§ 16.5 Send Alert Text")

[Permalink](#dfn-window-alert)

**Referenced in:**

- [§ 16.5 Send Alert
 Text](#ref-for-dfn-window-alert-1 "§ 16.5 Send Alert Text")

[Permalink](#dfn-window-prompt)

**Referenced in:**

- [§ 16.5 Send Alert
 Text](#ref-for-dfn-window-prompt-1 "§ 16.5 Send Alert Text")
 [(2)](#ref-for-dfn-window-prompt-2 "Reference 2")

[Permalink](#dfn-color-state)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-color-state-1 "§ 12. Elements")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-color-state-2 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-date-state)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-date-state-1 "§ 12. Elements")

[Permalink](#dfn-email-state)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-email-state-1 "§ 12. Elements")

[Permalink](#dfn-local-date-and-time-state)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-dfn-local-date-and-time-state-1 "§ 12. Elements")

[Permalink](#dfn-month-state)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-month-state-1 "§ 12. Elements")

[Permalink](#dfn-number-state)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-number-state-1 "§ 12. Elements")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-number-state-2 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-password-state)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-password-state-1 "§ 12. Elements")

[Permalink](#dfn-range-state)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-range-state-1 "§ 12. Elements")

[Permalink](#dfn-telephone-state)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-telephone-state-1 "§ 12. Elements")

[Permalink](#dfn-text-and-search-state)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-dfn-text-and-search-state-1 "§ 12. Elements")

[Permalink](#dfn-time-state)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-time-state-1 "§ 12. Elements")

[Permalink](#dfn-url-state)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-url-state-1 "§ 12. Elements")

[Permalink](#dfn-week-state)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-week-state-1 "§ 12. Elements")

[Permalink](#dfn-checked)

**Referenced in:**

- [§ 12.5 Interaction](#ref-for-dfn-checked-1 "§ 12.5 Interaction")

[Permalink](#dfn-multiple-attribute)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-multiple-attribute-1 "§ 12.5.1 Element Click")

[Permalink](#dfn-content-editable)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-content-editable-1 "§ 12. Elements")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-content-editable-2 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-editing-hosts)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-editing-hosts-1 "§ 12. Elements")

[Permalink](#dfn-change)

**Referenced in:**

- [§ 12.5.1 Element
 Click](#ref-for-dfn-change-1 "§ 12.5.1 Element Click")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-change-2 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-domcontentloaded)

**Referenced in:**

- [§ 10. Navigation](#ref-for-dfn-domcontentloaded-1 "§ 10. Navigation")

[Permalink](#dfn-input)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-input-1 "§ 12. Elements")
 [(2)](#ref-for-dfn-input-2 "Reference 2")
- [§ 12.4.1 Is Element
 Selected](#ref-for-dfn-input-3 "§ 12.4.1 Is Element Selected")
 [(2)](#ref-for-dfn-input-4 "Reference 2")
- [§ 12.5 Interaction](#ref-for-dfn-input-5 "§ 12.5 Interaction")
 [(2)](#ref-for-dfn-input-6 "Reference 2")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-input-7 "§ 12.5.1 Element Click")
 [(2)](#ref-for-dfn-input-8 "Reference 2")
- [§ 12.5.2 Element
 Clear](#ref-for-dfn-input-9 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-input-10 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-dfn-input-11 "Reference 2")
 [(3)](#ref-for-dfn-input-12 "Reference 3")
 [(4)](#ref-for-dfn-input-13 "Reference 4")
 [(5)](#ref-for-dfn-input-14 "Reference 5")
 [(6)](#ref-for-dfn-input-15 "Reference 6")
- [§ E. Index](#ref-for-dfn-input-16 "§ E. Index")

[Permalink](#dfn-load)

**Referenced in:**

- [§ 10. Navigation](#ref-for-dfn-load-1 "§ 10. Navigation")

[Permalink](#dfn-pagehide)

**Referenced in:**

- [§ 10.3 Back](#ref-for-dfn-pagehide-1 "§ 10.3 Back")
- [§ 10.4 Forward](#ref-for-dfn-pagehide-2 "§ 10.4 Forward")

[Permalink](#dfn-pageshow)

**Referenced in:**

- [§ 10.3 Back](#ref-for-dfn-pageshow-1 "§ 10.3 Back")
- [§ 10.4 Forward](#ref-for-dfn-pageshow-2 "§ 10.4 Forward")

[Permalink](#dfn-data-url)

**Referenced in:**

- [§ 17. Screen capture](#ref-for-dfn-data-url-1 "§ 17. Screen capture")

[Permalink](#dfn-http-compliant)

**Referenced in:**

- [§ 6. Protocol](#ref-for-dfn-http-compliant-1 "§ 6. Protocol")

[Permalink](#dfn-compute-cookie-string)

**Referenced in:**

- [§ 14. Cookies](#ref-for-dfn-compute-cookie-string-1 "§ 14. Cookies")

[Permalink](#dfn-cookies)

**Referenced in:**

- [§ 14. Cookies](#ref-for-dfn-cookies-1 "§ 14. Cookies")
 [(2)](#ref-for-dfn-cookies-2 "Reference 2")
 [(3)](#ref-for-dfn-cookies-3 "Reference 3")
 [(4)](#ref-for-dfn-cookies-4 "Reference 4")
 [(5)](#ref-for-dfn-cookies-5 "Reference 5")
- [§ 14.2 Get Named
 Cookie](#ref-for-dfn-cookies-6 "§ 14.2 Get Named Cookie")

[Permalink](#dfn-cookie-store)

**Referenced in:**

- [§ 14. Cookies](#ref-for-dfn-cookie-store-1 "§ 14. Cookies")
 [(2)](#ref-for-dfn-cookie-store-2 "Reference 2")
- [§ 14.3 Add Cookie](#ref-for-dfn-cookie-store-3 "§ 14.3 Add Cookie")

[Permalink](#dfn-receiving-a-cookie)

**Referenced in:**

- [§ 14. Cookies](#ref-for-dfn-receiving-a-cookie-1 "§ 14. Cookies")

[Permalink](#dfn-cookie-lifetime-limits)

**Referenced in:**

- [§ 14.3 Add
 Cookie](#ref-for-dfn-cookie-lifetime-limits-1 "§ 14.3 Add Cookie")

[Permalink](#dfn-lax)

**Referenced in:**

- [§ 14. Cookies](#ref-for-dfn-lax-1 "§ 14. Cookies")

[Permalink](#dfn-strict)

**Referenced in:**

- [§ 14. Cookies](#ref-for-dfn-strict-1 "§ 14. Cookies")

[Permalink](#dfn-status-code-registry)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-dfn-status-code-registry-1 "§ 6.3 Processing model")

[Permalink](#dfn-convert-an-infra-value-to-a-json-compatible-javascript-value)

**Referenced in:**

- [§ 9.
 Timeouts](#ref-for-dfn-convert-an-infra-value-to-a-json-compatible-javascript-value-1 "§ 9. Timeouts")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-convert-an-infra-value-to-a-json-compatible-javascript-value-2 "§ 16.1 User Prompt Handler")

[Permalink](#dfn-converting-a-json-derived-javascript-value-to-an-infra-value)

**Referenced in:**

- [§ 9.
 Timeouts](#ref-for-dfn-converting-a-json-derived-javascript-value-to-an-infra-value-1 "§ 9. Timeouts")
- [§ 16.1 User Prompt
 Handler](#ref-for-dfn-converting-a-json-derived-javascript-value-to-an-infra-value-2 "§ 16.1 User Prompt Handler")

[Permalink](#dfn-proxy-autoconfiguration)

**Referenced in:**

- [§ 7.1 Proxy](#ref-for-dfn-proxy-autoconfiguration-1 "§ 7.1 Proxy")

[Permalink](#dfn-uri-template)

**Referenced in:**

- [§ 6.4 Routing
 requests](#ref-for-dfn-uri-template-1 "§ 6.4 Routing requests")
- [§ 6.5 Endpoints](#ref-for-dfn-uri-template-2 "§ 6.5 Endpoints")
- [§ 6.7 Extensions](#ref-for-dfn-uri-template-3 "§ 6.7 Extensions")
- [§ C. Element
 displayedness](#ref-for-dfn-uri-template-4 "§ C. Element displayedness")

[Permalink](#dfn-visibility-hidden)

**Referenced in:**

- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-visibility-hidden-1 "§ 11.8 Resizing and positioning windows")

[Permalink](#dfn-visibility-state)

**Referenced in:**

- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-visibility-state-1 "§ 11.8 Resizing and positioning windows")
 [(2)](#ref-for-dfn-visibility-state-2 "Reference 2")

[Permalink](#dfn-visibility-visible)

**Referenced in:**

- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-visibility-visible-1 "§ 11.8 Resizing and positioning windows")

[Permalink](#dfn-bot-dom-getvisibletext)

**Referenced in:**

- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-bot-dom-getvisibletext-1 "§ 12.4.5 Get Element Text")

[Permalink](#dfn-bot-dom-isshown)

**Referenced in:**

- [§ C. Element
 displayedness](#ref-for-dfn-bot-dom-isshown-1 "§ C. Element displayedness")
 [(2)](#ref-for-dfn-bot-dom-isshown-2 "Reference 2")

[Permalink](#dfn-absolute-lengths)

**Referenced in:**

- [§ 18.1 Print
 Page](#ref-for-dfn-absolute-lengths-1 "§ 18.1 Print Page")

[Permalink](#dfn-css-pixels)

**Referenced in:**

- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-css-pixels-1 "§ 11.8.2 Set Window Rect")
 [(2)](#ref-for-dfn-css-pixels-2 "Reference 2")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-css-pixels-3 "§ 12.4.7 Get Element Rect")
 [(2)](#ref-for-dfn-css-pixels-4 "Reference 2")
 [(3)](#ref-for-dfn-css-pixels-5 "Reference 3")
 [(4)](#ref-for-dfn-css-pixels-6 "Reference 4")
- [§ 15.6.3 Pointer
 actions](#ref-for-dfn-css-pixels-7 "§ 15.6.3 Pointer actions")
 [(2)](#ref-for-dfn-css-pixels-8 "Reference 2")
- [§ 15.6.4 Wheel
 actions](#ref-for-dfn-css-pixels-9 "§ 15.6.4 Wheel actions")
 [(2)](#ref-for-dfn-css-pixels-10 "Reference 2")
- [§ 17. Screen
 capture](#ref-for-dfn-css-pixels-11 "§ 17. Screen capture")

[Permalink](#dfn-visibility)

**Referenced in:**

- [§ C. Element
 displayedness](#ref-for-dfn-visibility-1 "§ C. Element displayedness")

[Permalink](#dfn-viewport)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-dfn-viewport-1 "§ 12.1 Interactability")
 [(2)](#ref-for-dfn-viewport-2 "Reference 2")
- [§ 12.5.1 Element
 Click](#ref-for-dfn-viewport-3 "§ 12.5.1 Element Click")
- [§ 17. Screen capture](#ref-for-dfn-viewport-4 "§ 17. Screen capture")
 [(2)](#ref-for-dfn-viewport-5 "Reference 2")
 [(3)](#ref-for-dfn-viewport-6 "Reference 3")
 [(4)](#ref-for-dfn-viewport-7 "Reference 4")
 [(5)](#ref-for-dfn-viewport-8 "Reference 5")
- [§ C. Element
 displayedness](#ref-for-dfn-viewport-9 "§ C. Element displayedness")

[Permalink](#dfn-display)

**Referenced in:**

- [§ C. Element
 displayedness](#ref-for-dfn-display-1 "§ C. Element displayedness")

[Permalink](#dfn-bounding-rectangle)

**Referenced in:**

- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-bounding-rectangle-1 "§ 12.4.7 Get Element Rect")
 [(2)](#ref-for-dfn-bounding-rectangle-2 "Reference 2")
 [(3)](#ref-for-dfn-bounding-rectangle-3 "Reference 3")
- [§ 17. Screen
 capture](#ref-for-dfn-bounding-rectangle-4 "§ 17. Screen capture")
 [(2)](#ref-for-dfn-bounding-rectangle-5 "Reference 2")
- [§ 17.1 Take
 Screenshot](#ref-for-dfn-bounding-rectangle-6 "§ 17.1 Take Screenshot")
- [§ 17.2 Take Element
 Screenshot](#ref-for-dfn-bounding-rectangle-7 "§ 17.2 Take Element Screenshot")

[Permalink](#dfn-height-dimension)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-dfn-height-dimension-1 "§ 12.1 Interactability")
 [(2)](#ref-for-dfn-height-dimension-2 "Reference 2")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-height-dimension-3 "§ 12.4.7 Get Element Rect")
- [§ 17. Screen
 capture](#ref-for-dfn-height-dimension-4 "§ 17. Screen capture")

[Permalink](#dfn-width-dimension)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-dfn-width-dimension-1 "§ 12.1 Interactability")
 [(2)](#ref-for-dfn-width-dimension-2 "Reference 2")
- [§ 12.4.7 Get Element
 Rect](#ref-for-dfn-width-dimension-3 "§ 12.4.7 Get Element Rect")
- [§ 17. Screen
 capture](#ref-for-dfn-width-dimension-4 "§ 17. Screen capture")

[Permalink](#dfn-x-coordinate)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-dfn-x-coordinate-1 "§ 12.1 Interactability")
 [(2)](#ref-for-dfn-x-coordinate-2 "Reference 2")
 [(3)](#ref-for-dfn-x-coordinate-3 "Reference 3")
 [(4)](#ref-for-dfn-x-coordinate-4 "Reference 4")
- [§ 12.4 State](#ref-for-dfn-x-coordinate-5 "§ 12.4 State")
- [§ 17. Screen
 capture](#ref-for-dfn-x-coordinate-6 "§ 17. Screen capture")
 [(2)](#ref-for-dfn-x-coordinate-7 "Reference 2")
 [(3)](#ref-for-dfn-x-coordinate-8 "Reference 3")

[Permalink](#dfn-y-coordinate)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-dfn-y-coordinate-1 "§ 12.1 Interactability")
 [(2)](#ref-for-dfn-y-coordinate-2 "Reference 2")
 [(3)](#ref-for-dfn-y-coordinate-3 "Reference 3")
 [(4)](#ref-for-dfn-y-coordinate-4 "Reference 4")
- [§ 12.4 State](#ref-for-dfn-y-coordinate-5 "§ 12.4 State")
- [§ 17. Screen
 capture](#ref-for-dfn-y-coordinate-6 "§ 17. Screen capture")
 [(2)](#ref-for-dfn-y-coordinate-7 "Reference 2")
 [(3)](#ref-for-dfn-y-coordinate-8 "Reference 3")

[Permalink](#dfn-computed-value)

**Referenced in:**

- [§ 12.4.4 Get Element CSS
 Value](#ref-for-dfn-computed-value-1 "§ 12.4.4 Get Element CSS Value")

[Permalink](#dfn-resolved-value)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-resolved-value-1 "§ 12. Elements")

[Permalink](#dfn-paint-order)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-dfn-paint-order-1 "§ 12.1 Interactability")
 [(2)](#ref-for-dfn-paint-order-2 "Reference 2")
 [(3)](#ref-for-dfn-paint-order-3 "Reference 3")

[Permalink](#dfn-innerheight)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-dfn-innerheight-1 "§ 12.1 Interactability")

[Permalink](#dfn-innerwidth)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-dfn-innerwidth-1 "§ 12.1 Interactability")

[Permalink](#dfn-moveto-x-y)

**Referenced in:**

- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-moveto-x-y-1 "§ 11.8.2 Set Window Rect")

[Permalink](#dfn-outerheight)

**Referenced in:**

- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-outerheight-1 "§ 11.8 Resizing and positioning windows")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-outerheight-2 "§ 11.8.2 Set Window Rect")
 [(2)](#ref-for-dfn-outerheight-3 "Reference 2")

[Permalink](#dfn-outerwidth)

**Referenced in:**

- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-outerwidth-1 "§ 11.8 Resizing and positioning windows")
- [§ 11.8.2 Set Window
 Rect](#ref-for-dfn-outerwidth-2 "§ 11.8.2 Set Window Rect")
 [(2)](#ref-for-dfn-outerwidth-3 "Reference 2")

[Permalink](#dfn-screenx)

**Referenced in:**

- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-screenx-1 "§ 11.8 Resizing and positioning windows")

[Permalink](#dfn-screeny)

**Referenced in:**

- [§ 11.8 Resizing and positioning
 windows](#ref-for-dfn-screeny-1 "§ 11.8 Resizing and positioning windows")

[Permalink](#dfn-scrollx)

**Referenced in:**

- [§ 12.4 State](#ref-for-dfn-scrollx-1 "§ 12.4 State")

[Permalink](#dfn-scrolly)

**Referenced in:**

- [§ 12.4 State](#ref-for-dfn-scrolly-1 "§ 12.4 State")

[Permalink](#dfn-scrollintoview)

**Referenced in:**

- [§ 12. Elements](#ref-for-dfn-scrollintoview-1 "§ 12. Elements")

[Permalink](#dfn-scrollintoviewoptions)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-dfn-scrollintoviewoptions-1 "§ 12. Elements")

[Permalink](#dfn-logical-scroll-position-block)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-dfn-logical-scroll-position-block-1 "§ 12. Elements")

[Permalink](#dfn-logical-scroll-position-inline)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-dfn-logical-scroll-position-inline-1 "§ 12. Elements")

[Permalink](#dfn-media-type)

**Referenced in:**

- [§ 18.1 Print Page](#ref-for-dfn-media-type-1 "§ 18.1 Print Page")

[Permalink](#dfn-socks-proxy)

**Referenced in:**

- [§ 7.1 Proxy](#ref-for-dfn-socks-proxy-1 "§ 7.1 Proxy")
 [(2)](#ref-for-dfn-socks-proxy-2 "Reference 2")

[Permalink](#dfn-unicode-code-point)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-unicode-code-point-1 "§ 12.5.3 Element Send Keys")
- [§ 15.5 Processing
 actions](#ref-for-dfn-unicode-code-point-2 "§ 15.5 Processing actions")
- [§ 15.6.2 Keyboard
 actions](#ref-for-dfn-unicode-code-point-3 "§ 15.6.2 Keyboard actions")

[Permalink](#dfn-grapheme-cluster)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-grapheme-cluster-1 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-breaking-text-into-extended-grapheme-clusters)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-dfn-breaking-text-into-extended-grapheme-clusters-1 "§ 12.5.3 Element Send Keys")

[Permalink](#dfn-unicode-character-property)

**Referenced in:**

- [§ 12.4.5 Get Element
 Text](#ref-for-dfn-unicode-character-property-1 "§ 12.4.5 Get Element Text")

[Permalink](#dfn-absolute-url)

**Referenced in:**

- [§ 10.1 Navigate To](#ref-for-dfn-absolute-url-1 "§ 10.1 Navigate To")
 [(2)](#ref-for-dfn-absolute-url-2 "Reference 2")
 [(3)](#ref-for-dfn-absolute-url-3 "Reference 3")
 [(4)](#ref-for-dfn-absolute-url-4 "Reference 4")

[Permalink](#dfn-absolute-url-with-fragment)

**Referenced in:**

- [§ 10.1 Navigate
 To](#ref-for-dfn-absolute-url-with-fragment-1 "§ 10.1 Navigate To")

[Permalink](#dfn-default-port)

**Referenced in:**

- [§ 7.1 Proxy](#ref-for-dfn-default-port-1 "§ 7.1 Proxy")

[Permalink](#dfn-domains)

**Referenced in:**

- [§ 14. Cookies](#ref-for-dfn-domains-1 "§ 14. Cookies")
- [§ 14.3 Add Cookie](#ref-for-dfn-domains-2 "§ 14.3 Add Cookie")
 [(2)](#ref-for-dfn-domains-3 "Reference 2")

[Permalink](#dfn-host)

**Referenced in:**

- [§ 7.1 Proxy](#ref-for-dfn-host-1 "§ 7.1 Proxy")
 [(2)](#ref-for-dfn-host-2 "Reference 2")
 [(3)](#ref-for-dfn-host-3 "Reference 3")
 [(4)](#ref-for-dfn-host-4 "Reference 4")
 [(5)](#ref-for-dfn-host-5 "Reference 5")
- [§ 12.2 Shadow Roots](#ref-for-dfn-host-6 "§ 12.2 Shadow Roots")

[Permalink](#dfn-includes-credentials)

**Referenced in:**

- [§ 7.1 Proxy](#ref-for-dfn-includes-credentials-1 "§ 7.1 Proxy")

[Permalink](#dfn-is-special)

**Referenced in:**

- [§ 10.1 Navigate To](#ref-for-dfn-is-special-1 "§ 10.1 Navigate To")
 [(2)](#ref-for-dfn-is-special-2 "Reference 2")
- [§ 10.5 Refresh](#ref-for-dfn-is-special-3 "§ 10.5 Refresh")

[Permalink](#dfn-path-absolute-url)

**Referenced in:**

- [§ 6.4 Routing
 requests](#ref-for-dfn-path-absolute-url-1 "§ 6.4 Routing requests")

[Permalink](#dfn-path)

**Referenced in:**

- [§ 6.4 Routing requests](#ref-for-dfn-path-1 "§ 6.4 Routing requests")
 [(2)](#ref-for-dfn-path-2 "Reference 2")

[Permalink](#dfn-port)

**Referenced in:**

- [§ 7.1 Proxy](#ref-for-dfn-port-1 "§ 7.1 Proxy")

[Permalink](#dfn-url)

**Referenced in:**

- [§ 6.3 Processing model](#ref-for-dfn-url-1 "§ 6.3 Processing model")
- [§ 6.4 Routing requests](#ref-for-dfn-url-2 "§ 6.4 Routing requests")
- [§ 7.1 Proxy](#ref-for-dfn-url-3 "§ 7.1 Proxy")
- [§ 8.2 New Session](#ref-for-dfn-url-4 "§ 8.2 New Session")
- [§ 10.1 Navigate To](#ref-for-dfn-url-5 "§ 10.1 Navigate To")
 [(2)](#ref-for-dfn-url-6 "Reference 2")
- [§ 10.2 Get Current URL](#ref-for-dfn-url-7 "§ 10.2 Get Current URL")
- [§ 14. Cookies](#ref-for-dfn-url-8 "§ 14. Cookies")
- [§ 14.3 Add Cookie](#ref-for-dfn-url-9 "§ 14.3 Add Cookie")

[Permalink](#dfn-url-serializer)

**Referenced in:**

- [§ 10.2 Get Current
 URL](#ref-for-dfn-url-serializer-1 "§ 10.2 Get Current URL")

[Permalink](#dfn-domexception)

**Referenced in:**

- [§ 12.3 Retrieval](#ref-for-dfn-domexception-1 "§ 12.3 Retrieval")

[Permalink](#dfn-supported-property-index)

**Referenced in:**

- [§ 11.6 Switch To
 Frame](#ref-for-dfn-supported-property-index-1 "§ 11.6 Switch To Frame")

[Permalink](#dfn-syntaxerror)

**Referenced in:**

- [§ 12.3 Retrieval](#ref-for-dfn-syntaxerror-1 "§ 12.3 Retrieval")

[Permalink](#dfn-this)

**Referenced in:**

- [§ 12.3.1.1 CSS
 selectors](#ref-for-dfn-this-1 "§ 12.3.1.1 CSS selectors")
- [§ 12.3.1.2 Link text](#ref-for-dfn-this-2 "§ 12.3.1.2 Link text")
- [§ 12.3.1.3 Partial link
 text](#ref-for-dfn-this-3 "§ 12.3.1.3 Partial link text")
- [§ 12.3.1.4 Tag name](#ref-for-dfn-this-4 "§ 12.3.1.4 Tag name")
- [§ 12.3.1.5 XPath](#ref-for-dfn-this-5 "§ 12.3.1.5 XPath")

[Permalink](#dfn-promise-call)

**Referenced in:**

- [§ 13.2.1 Execute
 Script](#ref-for-dfn-promise-call-1 "§ 13.2.1 Execute Script")

[Permalink](#dfn-evaluate)

**Referenced in:**

- [§ 12.3.1.5 XPath](#ref-for-dfn-evaluate-1 "§ 12.3.1.5 XPath")

[Permalink](#dfn-ordered_node_snapshot_type)

**Referenced in:**

- [§ 12.3.1.5
 XPath](#ref-for-dfn-ordered_node_snapshot_type-1 "§ 12.3.1.5 XPath")

[Permalink](#dfn-snapshotitem)

**Referenced in:**

- [§ 12.3.1.5 XPath](#ref-for-dfn-snapshotitem-1 "§ 12.3.1.5 XPath")

[Permalink](#dfn-xpathexception)

**Referenced in:**

- [§ 12.3 Retrieval](#ref-for-dfn-xpathexception-1 "§ 12.3 Retrieval")
- [§ 12.3.1.5 XPath](#ref-for-dfn-xpathexception-2 "§ 12.3.1.5 XPath")

[Permalink](https://www.w3.org/TR/cssom-view-1/#dom-element-getboundingclientrect)

**Referenced in:**

- [§ 12.4
 State](#ref-for-index-term-getboundingclientrect-for-element-1 "§ 12.4 State")

[Permalink](https://www.w3.org/TR/cssom-view-1/#dom-element-getclientrects)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-index-term-getclientrects-for-element-1 "§ 12.1 Interactability")
 [(2)](#ref-for-index-term-getclientrects-for-element-2 "Reference 2")
 [(3)](#ref-for-index-term-getclientrects-for-element-3 "Reference 3")

[Permalink](https://dom.spec.whatwg.org/#dom-node-comparedocumentposition)

**Referenced in:**

- [§ 12.4
 State](#ref-for-index-term-comparedocumentposition-for-node-1 "§ 12.4 State")

[Permalink](https://dom.spec.whatwg.org/#connected)

**Referenced in:**

- [§ 12. Elements](#ref-for-index-term-connected-1 "§ 12. Elements")

[Permalink](https://dom.spec.whatwg.org/#concept-tree-descendant)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-index-term-descendant-for-tree-1 "§ 12.1 Interactability")
 [(2)](#ref-for-index-term-descendant-for-tree-2 "Reference 2")

[Permalink](https://dom.spec.whatwg.org/#concept-document)

**Referenced in:**

- [§ 14. Cookies](#ref-for-index-term-document-1 "§ 14. Cookies")
 [(2)](#ref-for-index-term-document-2 "Reference 2")
- [§ E. Index](#ref-for-index-term-document-3 "§ E. Index")

[Permalink](https://dom.spec.whatwg.org/#document-element)

**Referenced in:**

- [§ 11.8.5 Fullscreen
 Window](#ref-for-index-term-document-element-1 "§ 11.8.5 Fullscreen Window")
- [§ 12.1
 Interactability](#ref-for-index-term-document-element-2 "§ 12.1 Interactability")
- [§ 12.3.2 Find
 Element](#ref-for-index-term-document-element-3 "§ 12.3.2 Find Element")
- [§ 12.3.3 Find
 Elements](#ref-for-index-term-document-element-4 "§ 12.3.3 Find Elements")
- [§ 12.3.8 Get Active
 Element](#ref-for-index-term-document-element-5 "§ 12.3.8 Get Active Element")
- [§ 12.4.7 Get Element
 Rect](#ref-for-index-term-document-element-6 "§ 12.4.7 Get Element Rect")
 [(2)](#ref-for-index-term-document-element-7 "Reference 2")
- [§ 13.1 Get Page
 Source](#ref-for-index-term-document-element-8 "§ 13.1 Get Page Source")
- [§ 14.3 Add
 Cookie](#ref-for-index-term-document-element-9 "§ 14.3 Add Cookie")
- [§ 17.1 Take
 Screenshot](#ref-for-index-term-document-element-10 "§ 17.1 Take Screenshot")

[Permalink](https://dom.spec.whatwg.org/#dom-node-document_position_disconnected)

**Referenced in:**

- [§ 12.4
 State](#ref-for-index-term-document_position_disconnected-for-node-1 "§ 12.4 State")

[Permalink](https://dom.spec.whatwg.org/#domtokenlist)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-index-term-domtokenlist-interface-1 "§ 13.2 Executing Script")

[Permalink](https://dom.spec.whatwg.org/#concept-element)

**Referenced in:**

- [§ 6.6 Errors](#ref-for-index-term-element-1 "§ 6.6 Errors")
 [(2)](#ref-for-index-term-element-2 "Reference 2")
- [§ 12. Elements](#ref-for-index-term-element-3 "§ 12. Elements")
 [(2)](#ref-for-index-term-element-4 "Reference 2")
 [(3)](#ref-for-index-term-element-5 "Reference 3")
 [(4)](#ref-for-index-term-element-6 "Reference 4")
 [(5)](#ref-for-index-term-element-7 "Reference 5")
 [(6)](#ref-for-index-term-element-8 "Reference 6")
 [(7)](#ref-for-index-term-element-9 "Reference 7")
- [§ 12.1
 Interactability](#ref-for-index-term-element-10 "§ 12.1 Interactability")
 [(2)](#ref-for-index-term-element-11 "Reference 2")
 [(3)](#ref-for-index-term-element-12 "Reference 3")
 [(4)](#ref-for-index-term-element-13 "Reference 4")
 [(5)](#ref-for-index-term-element-14 "Reference 5")
 [(6)](#ref-for-index-term-element-15 "Reference 6")
 [(7)](#ref-for-index-term-element-16 "Reference 7")
 [(8)](#ref-for-index-term-element-17 "Reference 8")
 [(9)](#ref-for-index-term-element-18 "Reference 9")
 [(10)](#ref-for-index-term-element-19 "Reference 10")
 [(11)](#ref-for-index-term-element-20 "Reference 11")
- [§ 12.3.1 Locator
 strategies](#ref-for-index-term-element-21 "§ 12.3.1 Locator strategies")
- [§ 12.3.1.5 XPath](#ref-for-index-term-element-22 "§ 12.3.1.5 XPath")
- [§ 12.3.2 Find
 Element](#ref-for-index-term-element-23 "§ 12.3.2 Find Element")
- [§ 12.3.8 Get Active
 Element](#ref-for-index-term-element-24 "§ 12.3.8 Get Active Element")
- [§ 12.4 State](#ref-for-index-term-element-25 "§ 12.4 State")
 [(2)](#ref-for-index-term-element-26 "Reference 2")
 [(3)](#ref-for-index-term-element-27 "Reference 3")
- [§ 12.4.1 Is Element
 Selected](#ref-for-index-term-element-28 "§ 12.4.1 Is Element Selected")
- [§ 12.4.5 Get Element
 Text](#ref-for-index-term-element-29 "§ 12.4.5 Get Element Text")
 [(2)](#ref-for-index-term-element-30 "Reference 2")
- [§ 12.5
 Interaction](#ref-for-index-term-element-31 "§ 12.5 Interaction")
- [§ 12.5.1 Element
 Click](#ref-for-index-term-element-32 "§ 12.5.1 Element Click")
 [(2)](#ref-for-index-term-element-33 "Reference 2")
- [§ 12.5.3 Element Send
 Keys](#ref-for-index-term-element-34 "§ 12.5.3 Element Send Keys")
 [(2)](#ref-for-index-term-element-35 "Reference 2")
 [(3)](#ref-for-index-term-element-36 "Reference 3")
 [(4)](#ref-for-index-term-element-37 "Reference 4")
 [(5)](#ref-for-index-term-element-38 "Reference 5")
 [(6)](#ref-for-index-term-element-39 "Reference 6")
 [(7)](#ref-for-index-term-element-40 "Reference 7")
- [§ 15.4 Ticks](#ref-for-index-term-element-41 "§ 15.4 Ticks")
- [§ 17. Screen
 capture](#ref-for-index-term-element-42 "§ 17. Screen capture")
 [(2)](#ref-for-index-term-element-43 "Reference 2")
- [§ 17.2 Take Element
 Screenshot](#ref-for-index-term-element-44 "§ 17.2 Take Element Screenshot")
- [§ C. Element
 displayedness](#ref-for-index-term-element-45 "§ C. Element displayedness")
 [(2)](#ref-for-index-term-element-46 "Reference 2")
 [(3)](#ref-for-index-term-element-47 "Reference 3")
 [(4)](#ref-for-index-term-element-48 "Reference 4")
 [(5)](#ref-for-index-term-element-49 "Reference 5")
 [(6)](#ref-for-index-term-element-50 "Reference 6")
 [(7)](#ref-for-index-term-element-51 "Reference 7")

[Permalink](https://dom.spec.whatwg.org/#element)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-index-term-element-interface-1 "§ 12. Elements")
 [(2)](#ref-for-index-term-element-interface-2 "Reference 2")
- [§ 13.2 Executing
 Script](#ref-for-index-term-element-interface-3 "§ 13.2 Executing Script")

[Permalink](https://dom.spec.whatwg.org/#concept-event)

**Referenced in:**

- [§ 10.4 Forward](#ref-for-index-term-event-1 "§ 10.4 Forward")

[Permalink](https://dom.spec.whatwg.org/#concept-event-fire)

**Referenced in:**

- [§ 10.
 Navigation](#ref-for-index-term-fire-an-event-1 "§ 10. Navigation")
 [(2)](#ref-for-index-term-fire-an-event-2 "Reference 2")
- [§ 10.3 Back](#ref-for-index-term-fire-an-event-3 "§ 10.3 Back")
 [(2)](#ref-for-index-term-fire-an-event-4 "Reference 2")
- [§ 10.4 Forward](#ref-for-index-term-fire-an-event-5 "§ 10.4 Forward")
- [§ 12.5.1 Element
 Click](#ref-for-index-term-fire-an-event-6 "§ 12.5.1 Element Click")
 [(2)](#ref-for-index-term-fire-an-event-7 "Reference 2")
 [(3)](#ref-for-index-term-fire-an-event-8 "Reference 3")
 [(4)](#ref-for-index-term-fire-an-event-9 "Reference 4")
 [(5)](#ref-for-index-term-fire-an-event-10 "Reference 5")
 [(6)](#ref-for-index-term-fire-an-event-11 "Reference 6")
 [(7)](#ref-for-index-term-fire-an-event-12 "Reference 7")
- [§ 12.5.3 Element Send
 Keys](#ref-for-index-term-fire-an-event-13 "§ 12.5.3 Element Send Keys")
- [§ 15.4 Ticks](#ref-for-index-term-fire-an-event-14 "§ 15.4 Ticks")
- [§ 15.8 Release
 Actions](#ref-for-index-term-fire-an-event-15 "§ 15.8 Release Actions")

[Permalink](https://dom.spec.whatwg.org/#concept-element-attributes-get-by-name)

**Referenced in:**

- [§ 12.4.2 Get Element
 Attribute](#ref-for-index-term-get-an-attribute-by-name-1 "§ 12.4.2 Get Element Attribute")

[Permalink](https://dom.spec.whatwg.org/#dom-element-getattribute)

**Referenced in:**

- [§ 12.4.2 Get Element
 Attribute](#ref-for-index-term-getattribute-for-element-1 "§ 12.4.2 Get Element Attribute")

[Permalink](https://dom.spec.whatwg.org/#dom-element-getelementsbytagname)

**Referenced in:**

- [§ 12.3.1.4 Tag
 name](#ref-for-index-term-getelementsbytagname-for-element-1 "§ 12.3.1.4 Tag name")

[Permalink](https://dom.spec.whatwg.org/#dom-element-hasattribute)

**Referenced in:**

- [§ 12.4.2 Get Element
 Attribute](#ref-for-index-term-hasattribute-for-element-1 "§ 12.4.2 Get Element Attribute")
- [§ 12.5.3 Element Send
 Keys](#ref-for-index-term-hasattribute-for-element-2 "§ 12.5.3 Element Send Keys")

[Permalink](https://dom.spec.whatwg.org/#htmlcollection)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-index-term-htmlcollection-interface-1 "§ 13.2 Executing Script")

[Permalink](https://dom.spec.whatwg.org/#concept-tree-inclusive-ancestor)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-index-term-inclusive-ancestor-for-tree-1 "§ 12.1 Interactability")

[Permalink](https://dom.spec.whatwg.org/#concept-tree-inclusive-descendant)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-index-term-inclusive-descendant-for-tree-1 "§ 12.1 Interactability")
 [(2)](#ref-for-index-term-inclusive-descendant-for-tree-2 "Reference 2")

[Permalink](https://dom.spec.whatwg.org/#dom-event-istrusted)

**Referenced in:**

- [§ 15.4
 Ticks](#ref-for-index-term-istrusted-attribute-for-event-1 "§ 15.4 Ticks")

[Permalink](https://dom.spec.whatwg.org/#concept-node)

**Referenced in:**

- [§ 12.4 State](#ref-for-index-term-node-1 "§ 12.4 State")
 [(2)](#ref-for-index-term-node-2 "Reference 2")
 [(3)](#ref-for-index-term-node-3 "Reference 3")
 [(4)](#ref-for-index-term-node-4 "Reference 4")

[Permalink](https://dom.spec.whatwg.org/#concept-node-document)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-index-term-node-document-for-node-1 "§ 12. Elements")
- [§ 12.2 Shadow
 Roots](#ref-for-index-term-node-document-for-node-2 "§ 12.2 Shadow Roots")
- [§ 12.4
 State](#ref-for-index-term-node-document-for-node-3 "§ 12.4 State")
 [(2)](#ref-for-index-term-node-document-for-node-4 "Reference 2")

[Permalink](https://dom.spec.whatwg.org/#nodelist)

**Referenced in:**

- [§ 12.3.1.2 Link
 text](#ref-for-index-term-nodelist-interface-1 "§ 12.3.1.2 Link text")
- [§ 12.3.1.3 Partial link
 text](#ref-for-index-term-nodelist-interface-2 "§ 12.3.1.3 Partial link text")
- [§ 12.3.1.5
 XPath](#ref-for-index-term-nodelist-interface-3 "§ 12.3.1.5 XPath")
- [§ 13.2 Executing
 Script](#ref-for-index-term-nodelist-interface-4 "§ 13.2 Executing Script")

[Permalink](https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall)

**Referenced in:**

- [§ 12.3.1.1 CSS
 selectors](#ref-for-index-term-queryselectorall-for-parentnode-1 "§ 12.3.1.1 CSS selectors")
- [§ 12.3.1.2 Link
 text](#ref-for-index-term-queryselectorall-for-parentnode-2 "§ 12.3.1.2 Link text")
- [§ 12.3.1.3 Partial link
 text](#ref-for-index-term-queryselectorall-for-parentnode-3 "§ 12.3.1.3 Partial link text")

[Permalink](https://dom.spec.whatwg.org/#concept-node-remove)

**Referenced in:**

- [§ 15.3 Input
 state](#ref-for-index-term-remove-1 "§ 15.3 Input state")

[Permalink](https://dom.spec.whatwg.org/#shadowroot)

**Referenced in:**

- [§ 12.2 Shadow
 Roots](#ref-for-index-term-shadowroot-interface-1 "§ 12.2 Shadow Roots")
 [(2)](#ref-for-index-term-shadowroot-interface-2 "Reference 2")
- [§ 13.2 Executing
 Script](#ref-for-index-term-shadowroot-interface-3 "§ 13.2 Executing Script")

[Permalink](https://dom.spec.whatwg.org/#dom-element-tagname)

**Referenced in:**

- [§ 12.4.6 Get Element Tag
 Name](#ref-for-index-term-tagname-attribute-for-element-1 "§ 12.4.6 Get Element Tag Name")

[Permalink](https://dom.spec.whatwg.org/#dom-node-textcontent)

**Referenced in:**

- [§ 12.5
 Interaction](#ref-for-index-term-textcontent-attribute-for-node-1 "§ 12.5 Interaction")

[Permalink](https://dom.spec.whatwg.org/#concept-document-type)

**Referenced in:**

- [§ 12.4.4 Get Element CSS
 Value](#ref-for-index-term-type-for-document-1 "§ 12.4.4 Get Element CSS Value")
- [§ 12.4.8 Is Element
 Enabled](#ref-for-index-term-type-for-document-2 "§ 12.4.8 Is Element Enabled")

[Permalink](https://www.w3.org/TR/FileAPI/#dfn-filelist)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-index-term-filelist-interface-1 "§ 13.2 Executing Script")

[Permalink](https://www.w3.org/TR/geometry-1/#domrect)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-index-term-domrect-interface-1 "§ 12.1 Interactability")
 [(2)](#ref-for-index-term-domrect-interface-2 "Reference 2")
 [(3)](#ref-for-index-term-domrect-interface-3 "Reference 3")

[Permalink](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element)

**Referenced in:**

- [§ 12.3.1.3 Partial link
 text](#ref-for-index-term-a-element-1 "§ 12.3.1.3 Partial link text")
- [§ 12.4.5 Get Element
 Text](#ref-for-index-term-a-element-2 "§ 12.4.5 Get Element Text")

[Permalink](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-bc)

**Referenced in:**

- [§ 11.6 Switch To
 Frame](#ref-for-index-term-active-browsing-context-for-navigable-1 "§ 11.6 Switch To Frame")

[Permalink](https://html.spec.whatwg.org/multipage/sections.html#the-address-element)

**Referenced in:**

- [§ 14. Cookies](#ref-for-index-term-address-element-1 "§ 14. Cookies")
- [§ 14.3 Add
 Cookie](#ref-for-index-term-address-element-2 "§ 14.3 Add Cookie")

[Permalink](https://html.spec.whatwg.org/multipage/canvas.html#canvas)

**Referenced in:**

- [§ 17. Screen
 capture](#ref-for-index-term-canvas-element-1 "§ 17. Screen capture")
 [(2)](#ref-for-index-term-canvas-element-2 "Reference 2")
 [(3)](#ref-for-index-term-canvas-element-3 "Reference 3")
- [§ 17.1 Take
 Screenshot](#ref-for-index-term-canvas-element-4 "§ 17.1 Take Screenshot")
- [§ 17.2 Take Element
 Screenshot](#ref-for-index-term-canvas-element-5 "§ 17.2 Take Element Screenshot")

[Permalink](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-a-callback)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-index-term-clean-up-after-running-a-callback-1 "§ 13.2 Executing Script")

[Permalink](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-script)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-index-term-clean-up-after-running-script-1 "§ 13.2 Executing Script")

[Permalink](https://html.spec.whatwg.org/multipage/document-sequences.html#content-navigable)

**Referenced in:**

- [§ 11.6 Switch To
 Frame](#ref-for-index-term-content-navigable-for-navigable-container-1 "§ 11.6 Switch To Frame")

[Permalink](https://html.spec.whatwg.org/multipage/form-elements.html#the-datalist-element)

**Referenced in:**

- [§ 12.4 State](#ref-for-index-term-datalist-element-1 "§ 12.4 State")

[Permalink](https://html.spec.whatwg.org/multipage/obsolete.html#frame)

**Referenced in:**

- [§ 11. Contexts](#ref-for-index-term-frame-element-1 "§ 11. Contexts")
- [§ 11.6 Switch To
 Frame](#ref-for-index-term-frame-element-2 "§ 11.6 Switch To Frame")

[Permalink](https://html.spec.whatwg.org/multipage/canvas.html#attr-canvas-height)

**Referenced in:**

- [§ 17. Screen
 capture](#ref-for-index-term-height-attribute-for-canvas-element-1 "§ 17. Screen capture")

[Permalink](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#htmlallcollection)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-index-term-htmlallcollection-interface-1 "§ 13.2 Executing Script")

[Permalink](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#htmlformcontrolscollection)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-index-term-htmlformcontrolscollection-interface-1 "§ 13.2 Executing Script")

[Permalink](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#htmloptionscollection)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-index-term-htmloptionscollection-interface-1 "§ 13.2 Executing Script")

[Permalink](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)

**Referenced in:**

- [§ 11.
 Contexts](#ref-for-index-term-iframe-element-1 "§ 11. Contexts")
- [§ 11.6 Switch To
 Frame](#ref-for-index-term-iframe-element-2 "§ 11.6 Switch To Frame")

[Permalink](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel)

**Referenced in:**

- [§ 9. Timeouts](#ref-for-index-term-in-parallel-1 "§ 9. Timeouts")
- [§ 13.2 Executing
 Script](#ref-for-index-term-in-parallel-2 "§ 13.2 Executing Script")
- [§ 13.2.1 Execute
 Script](#ref-for-index-term-in-parallel-3 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-index-term-in-parallel-4 "§ 13.2.2 Execute Async Script")
- [§ 15.6.3 Pointer
 actions](#ref-for-index-term-in-parallel-5 "§ 15.6.3 Pointer actions")
- [§ 15.6.4 Wheel
 actions](#ref-for-index-term-in-parallel-6 "§ 15.6.4 Wheel actions")

[Permalink](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable)

**Referenced in:**

- [§ 11. Contexts](#ref-for-index-term-navigable-1 "§ 11. Contexts")
- [§ 12. Elements](#ref-for-index-term-navigable-2 "§ 12. Elements")

[Permalink](https://html.spec.whatwg.org/multipage/system-state.html#navigator)

**Referenced in:**

- [§ 4.
 Interface](#ref-for-index-term-navigator-interface-1 "§ 4. Interface")

[Permalink](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-index-term-node-navigable-1 "§ 12. Elements")
 [(2)](#ref-for-index-term-node-navigable-2 "Reference 2")

[Permalink](https://html.spec.whatwg.org/multipage/form-elements.html#the-optgroup-element)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-index-term-optgroup-element-1 "§ 12.1 Interactability")
 [(2)](#ref-for-index-term-optgroup-element-2 "Reference 2")
- [§ 12.4 State](#ref-for-index-term-optgroup-element-3 "§ 12.4 State")

[Permalink](https://html.spec.whatwg.org/multipage/form-elements.html#the-option-element)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-index-term-option-element-1 "§ 12.1 Interactability")
 [(2)](#ref-for-index-term-option-element-2 "Reference 2")
- [§ 12.4 State](#ref-for-index-term-option-element-3 "§ 12.4 State")
 [(2)](#ref-for-index-term-option-element-4 "Reference 2")
- [§ 12.4.1 Is Element
 Selected](#ref-for-index-term-option-element-5 "§ 12.4.1 Is Element Selected")
 [(2)](#ref-for-index-term-option-element-6 "Reference 2")
- [§ 12.5.1 Element
 Click](#ref-for-index-term-option-element-7 "§ 12.5.1 Element Click")

[Permalink](https://html.spec.whatwg.org/multipage/form-elements.html#the-output-element)

**Referenced in:**

- [§ 12.5
 Interaction](#ref-for-index-term-output-element-1 "§ 12.5 Interaction")

[Permalink](https://html.spec.whatwg.org/multipage/webappapis.html#pause)

**Referenced in:**

- [§ 16. User
 prompts](#ref-for-index-term-paused-1 "§ 16. User prompts")
 [(2)](#ref-for-index-term-paused-2 "Reference 2")

[Permalink](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-a-callback)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-index-term-prepare-to-run-a-callback-1 "§ 13.2 Executing Script")

[Permalink](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-script)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-index-term-prepare-to-run-script-1 "§ 13.2 Executing Script")

[Permalink](https://html.spec.whatwg.org/multipage/input.html#attr-input-readonly)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-index-term-readonly-attribute-for-input-element-1 "§ 12. Elements")

[Permalink](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-agent)

**Referenced in:**

- [§ 16. User
 prompts](#ref-for-index-term-relevant-agent-1 "§ 16. User prompts")

[Permalink](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)

**Referenced in:**

- [§ 13.2 Executing
 Script](#ref-for-index-term-relevant-settings-object-1 "§ 13.2 Executing Script")

[Permalink](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element)

**Referenced in:**

- [§ 12.1
 Interactability](#ref-for-index-term-select-element-1 "§ 12.1 Interactability")
 [(2)](#ref-for-index-term-select-element-2 "Reference 2")
- [§ 12.4 State](#ref-for-index-term-select-element-3 "§ 12.4 State")
- [§ 12.5.3 Element Send
 Keys](#ref-for-index-term-select-element-4 "§ 12.5.3 Element Send Keys")

[Permalink](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-index-term-textarea-element-1 "§ 12. Elements")
- [§ 12.5
 Interaction](#ref-for-index-term-textarea-element-2 "§ 12.5 Interaction")

[Permalink](https://html.spec.whatwg.org/multipage/dom.html#document.title)

**Referenced in:**

- [§ 10.6 Get
 Title](#ref-for-index-term-title-attribute-for-document-1 "§ 10.6 Get Title")

[Permalink](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context)

**Referenced in:**

- [§ 8.
 Sessions](#ref-for-index-term-top-level-browsing-contexts-1 "§ 8. Sessions")
- [§ 8.1 Global
 State](#ref-for-index-term-top-level-browsing-contexts-2 "§ 8.1 Global State")
- [§ 8.2 New
 Session](#ref-for-index-term-top-level-browsing-contexts-3 "§ 8.2 New Session")
 [(2)](#ref-for-index-term-top-level-browsing-contexts-4 "Reference 2")
 [(3)](#ref-for-index-term-top-level-browsing-contexts-5 "Reference 3")
- [§ 11.
 Contexts](#ref-for-index-term-top-level-browsing-contexts-6 "§ 11. Contexts")
 [(2)](#ref-for-index-term-top-level-browsing-contexts-7 "Reference 2")
 [(3)](#ref-for-index-term-top-level-browsing-contexts-8 "Reference 3")
 [(4)](#ref-for-index-term-top-level-browsing-contexts-9 "Reference 4")
 [(5)](#ref-for-index-term-top-level-browsing-contexts-10 "Reference 5")
 [(6)](#ref-for-index-term-top-level-browsing-contexts-11 "Reference 6")
- [§ 11.2 Close
 Window](#ref-for-index-term-top-level-browsing-contexts-12 "§ 11.2 Close Window")
- [§ 11.3 Switch To
 Window](#ref-for-index-term-top-level-browsing-contexts-13 "§ 11.3 Switch To Window")
 [(2)](#ref-for-index-term-top-level-browsing-contexts-14 "Reference 2")
- [§ 11.4 Get Window
 Handles](#ref-for-index-term-top-level-browsing-contexts-15 "§ 11.4 Get Window Handles")
- [§ 11.5 New
 Window](#ref-for-index-term-top-level-browsing-contexts-16 "§ 11.5 New Window")
 [(2)](#ref-for-index-term-top-level-browsing-contexts-17 "Reference 2")
- [§ 11.7 Switch To Parent
 Frame](#ref-for-index-term-top-level-browsing-contexts-18 "§ 11.7 Switch To Parent Frame")
- [§ 11.8 Resizing and positioning
 windows](#ref-for-index-term-top-level-browsing-contexts-19 "§ 11.8 Resizing and positioning windows")
 [(2)](#ref-for-index-term-top-level-browsing-contexts-20 "Reference 2")
 [(3)](#ref-for-index-term-top-level-browsing-contexts-21 "Reference 3")
 [(4)](#ref-for-index-term-top-level-browsing-contexts-22 "Reference 4")
 [(5)](#ref-for-index-term-top-level-browsing-contexts-23 "Reference 5")
 [(6)](#ref-for-index-term-top-level-browsing-contexts-24 "Reference 6")
 [(7)](#ref-for-index-term-top-level-browsing-contexts-25 "Reference 7")
- [§ 15.3 Input
 state](#ref-for-index-term-top-level-browsing-contexts-26 "§ 15.3 Input state")
 [(2)](#ref-for-index-term-top-level-browsing-contexts-27 "Reference 2")
- [§ 17. Screen
 capture](#ref-for-index-term-top-level-browsing-contexts-28 "§ 17. Screen capture")

[Permalink](https://html.spec.whatwg.org/multipage/input.html#attr-input-type)

**Referenced in:**

- [§ 12.
 Elements](#ref-for-index-term-type-attribute-for-input-element-1 "§ 12. Elements")
- [§ 12.4.1 Is Element
 Selected](#ref-for-index-term-type-attribute-for-input-element-2 "§ 12.4.1 Is Element Selected")
- [§ 12.5
 Interaction](#ref-for-index-term-type-attribute-for-input-element-3 "§ 12.5 Interaction")
- [§ 12.5.2 Element
 Clear](#ref-for-index-term-type-attribute-for-input-element-4 "§ 12.5.2 Element Clear")
- [§ 12.5.3 Element Send
 Keys](#ref-for-index-term-type-attribute-for-input-element-5 "§ 12.5.3 Element Send Keys")

[Permalink](https://html.spec.whatwg.org/multipage/canvas.html#attr-canvas-width)

**Referenced in:**

- [§ 17. Screen
 capture](#ref-for-index-term-width-attribute-for-canvas-element-1 "§ 17. Screen capture")

[Permalink](https://html.spec.whatwg.org/multipage/workers.html#workernavigator)

**Referenced in:**

- [§ 4.
 Interface](#ref-for-index-term-workernavigator-interface-1 "§ 4. Interface")

[Permalink](https://infra.spec.whatwg.org/#abort-when)

**Referenced in:**

- [§ 10.
 Navigation](#ref-for-index-term-abort-when-1 "§ 10. Navigation")
- [§ 10.1 Navigate
 To](#ref-for-index-term-abort-when-2 "§ 10.1 Navigate To")

[Permalink](https://infra.spec.whatwg.org/#ascii-lowercase)

**Referenced in:**

- [§ 7.2 Processing
 capabilities](#ref-for-index-term-ascii-lowercase-1 "§ 7.2 Processing capabilities")
 [(2)](#ref-for-index-term-ascii-lowercase-2 "Reference 2")

[Permalink](https://infra.spec.whatwg.org/#list-contain)

**Referenced in:**

- [§ 9.
 Timeouts](#ref-for-index-term-contain-for-list-1 "§ 9. Timeouts")
- [§ 12.
 Elements](#ref-for-index-term-contain-for-list-2 "§ 12. Elements")
- [§ 16.1 User Prompt
 Handler](#ref-for-index-term-contain-for-list-3 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-index-term-contain-for-list-4 "Reference 2")

[Permalink](https://infra.spec.whatwg.org/#map-exists)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-index-term-contains-for-map-1 "§ 6.3 Processing model")
- [§ 12.
 Elements](#ref-for-index-term-contains-for-map-2 "§ 12. Elements")
- [§ 15.3 Input
 state](#ref-for-index-term-contains-for-map-3 "§ 15.3 Input state")
 [(2)](#ref-for-index-term-contains-for-map-4 "Reference 2")
- [§ 16.1 User Prompt
 Handler](#ref-for-index-term-contains-for-map-5 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-index-term-contains-for-map-6 "Reference 2")
 [(3)](#ref-for-index-term-contains-for-map-7 "Reference 3")

[Permalink](https://infra.spec.whatwg.org/#iteration-continue)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-index-term-continue-for-iteration-1 "§ 6.3 Processing model")
 [(2)](#ref-for-index-term-continue-for-iteration-2 "Reference 2")

[Permalink](https://infra.spec.whatwg.org/#map-entry)

**Referenced in:**

- [§ 6.4 Routing
 requests](#ref-for-index-term-entry-for-map-1 "§ 6.4 Routing requests")

[Permalink](https://infra.spec.whatwg.org/#map-getting-the-values)

**Referenced in:**

- [§ 15.3 Input
 state](#ref-for-index-term-getting-the-values-for-map-1 "§ 15.3 Input state")
 [(2)](#ref-for-index-term-getting-the-values-for-map-2 "Reference 2")

[Permalink](https://infra.spec.whatwg.org/#if-aborted)

**Referenced in:**

- [§ 10.
 Navigation](#ref-for-index-term-if-aborted-1 "§ 10. Navigation")
- [§ 10.1 Navigate
 To](#ref-for-index-term-if-aborted-2 "§ 10.1 Navigate To")

[Permalink](https://infra.spec.whatwg.org/#struct-item)

**Referenced in:**

- [§ 9. Timeouts](#ref-for-index-term-item-for-struct-1 "§ 9. Timeouts")
 [(2)](#ref-for-index-term-item-for-struct-2 "Reference 2")
 [(3)](#ref-for-index-term-item-for-struct-3 "Reference 3")

[Permalink](https://infra.spec.whatwg.org/#string-length)

**Referenced in:**

- [§ 12.5.3 Element Send
 Keys](#ref-for-index-term-length-for-string-1 "§ 12.5.3 Element Send Keys")

[Permalink](https://infra.spec.whatwg.org/#ordered-map)

**Referenced in:**

- [§ 6.4 Routing
 requests](#ref-for-index-term-map-1 "§ 6.4 Routing requests")
- [§ 9. Timeouts](#ref-for-index-term-map-2 "§ 9. Timeouts")
- [§ 12. Elements](#ref-for-index-term-map-3 "§ 12. Elements")
- [§ 16.1 User Prompt
 Handler](#ref-for-index-term-map-4 "§ 16.1 User Prompt Handler")
 [(2)](#ref-for-index-term-map-5 "Reference 2")
 [(3)](#ref-for-index-term-map-6 "Reference 3")
 [(4)](#ref-for-index-term-map-7 "Reference 4")
 [(5)](#ref-for-index-term-map-8 "Reference 5")
 [(6)](#ref-for-index-term-map-9 "Reference 6")

[Permalink](https://infra.spec.whatwg.org/#queue)

**Referenced in:**

- [§ 8. Sessions](#ref-for-index-term-queue-1 "§ 8. Sessions")
- [§ 8.2 New Session](#ref-for-index-term-queue-2 "§ 8.2 New Session")
- [§ 15.3 Input state](#ref-for-index-term-queue-3 "§ 15.3 Input state")

[Permalink](https://infra.spec.whatwg.org/#ordered-set)

**Referenced in:**

- [§ 8. Sessions](#ref-for-index-term-set-1 "§ 8. Sessions")
- [§ 18. Print](#ref-for-index-term-set-2 "§ 18. Print")

[Permalink](https://infra.spec.whatwg.org/#map-set)

**Referenced in:**

- [§ 16.1 User Prompt
 Handler](#ref-for-index-term-set-for-map-1 "§ 16.1 User Prompt Handler")

[Permalink](https://infra.spec.whatwg.org/#map-size)

**Referenced in:**

- [§ 16.1 User Prompt
 Handler](#ref-for-index-term-size-for-map-1 "§ 16.1 User Prompt Handler")

[Permalink](https://infra.spec.whatwg.org/#struct)

**Referenced in:**

- [§ 9. Timeouts](#ref-for-index-term-struct-1 "§ 9. Timeouts")
 [(2)](#ref-for-index-term-struct-2 "Reference 2")
- [§ 15.1 Actions
 Options](#ref-for-index-term-struct-3 "§ 15.1 Actions Options")
- [§ 15.2 Input
 sources](#ref-for-index-term-struct-4 "§ 15.2 Input sources")
- [§ 15.3 Input
 state](#ref-for-index-term-struct-5 "§ 15.3 Input state")
- [§ 16.1 User Prompt
 Handler](#ref-for-index-term-struct-6 "§ 16.1 User Prompt Handler")

[Permalink](https://infra.spec.whatwg.org/#iteration-while)

**Referenced in:**

- [§ 6.3 Processing
 model](#ref-for-index-term-while-for-iteration-1 "§ 6.3 Processing model")

[Permalink](https://www.w3.org/TR/webdriver-bidi/#bidi-session)

**Referenced in:**

- [§ 16. User
 prompts](#ref-for-index-term-bidi-session-1 "§ 16. User prompts")

[Permalink](https://webidl.spec.whatwg.org/#a-new-promise)

**Referenced in:**

- [§ 13.2.1 Execute
 Script](#ref-for-index-term-a-new-promise-1 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-index-term-a-new-promise-2 "§ 13.2.2 Execute Async Script")

[Permalink](https://webidl.spec.whatwg.org/#reject)

**Referenced in:**

- [§ 13.2.1 Execute
 Script](#ref-for-index-term-reject-1 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-index-term-reject-2 "§ 13.2.2 Execute Async Script")
 [(2)](#ref-for-index-term-reject-3 "Reference 2")
 [(3)](#ref-for-index-term-reject-4 "Reference 3")

[Permalink](https://webidl.spec.whatwg.org/#resolve)

**Referenced in:**

- [§ 13.2.1 Execute
 Script](#ref-for-index-term-resolve-1 "§ 13.2.1 Execute Script")
- [§ 13.2.2 Execute Async
 Script](#ref-for-index-term-resolve-2 "§ 13.2.2 Execute Async Script")
