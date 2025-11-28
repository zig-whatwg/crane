::::: section
## [1. ]{.secno}[Introduction]{.content}[](#intro){.self-link} {#intro .heading .settled level="1"}

This document provides three pieces of infrastructure for generic
reporting, which may be used or extended by other specifications:

1.  A generic framework for defining report types and reporting
    endpoints, and a document format for sending reports to endpoints
    over HTTP.

2.  A specific mechanism for configuring reporting endpoints in a
    document or worker, and for delivering reports whose lifetime is
    tied to that document or worker.

3.  A JavaScript interface for observing reports generated within a
    document or worker.

Other specifications may extend or make use of these pieces, for
instance by defining concrete report types, or alternative configuration
or delivery mechanisms for non-document-based reports.

### [1.1. ]{.secno}[Guarantees]{.content}[](#guarantees){.self-link} {#guarantees .heading .settled level="1.1"}

This specification aims to provide a best-effort report delivery system
that executes out-of-band with website activity. The user agent will be
able to do a better job prioritizing and scheduling delivery of reports,
as it has an overview of cross-origin activity that individual websites
do not, and can deliver reports based on error conditions that would
prevent a website from loading in the first place.

The delivery is not, however, guaranteed in any way, and reporting is
not intended to be used as a reliable communications channel. Network
conditions may prevent reports from reaching their destination at all,
and user agents are permitted to reject and not deliver a report for any
reason.

### [1.2. ]{.secno}[Examples]{.content}[](#examples){.self-link} {#examples .heading .settled level="1.2"}

::: {#example-bd21f0f9 .example}
[](#example-bd21f0f9){.self-link} MegaCorp Inc. wants to collect Content
Security Policy and Key Pinning violation reports. It can do so by
delivering the following header to define a set of reporting endpoints
named \"`endpoint-1`\":

    Reporting-Endpoints: endpoint-1="https://example.com/reports"

And the following headers, which direct CSP and HPKP reports to that
endpoint:

    Content-Security-Policy: ...; report-to endpoint-1
    Public-Key-Pins: ...; report-to=endpoint-1
:::

::: {#example-b1cea891 .example}
[](#example-b1cea891){.self-link} After processing reports for a little
while, MegaCorp Inc. decides to split the processing of these two types
of reports out into two distinct endpoints in order to make the
processing scripts simpler. It can do so by delivering the following
header to define two reporting endpoints:

    Reporting-Endpoints: csp-endpoint="https://example.com/csp-reports",
                         hpkp-endpoint="https://example.com/hpkp-reports"

And the following headers, which direct CSP and HPKP reports to those
named endpoints:

    Content-Security-Policy: ...; report-to csp-endpoint
    Public-Key-Pins: ...; report-to=hpkp-endpoint
:::
:::::

::: section
## [2. ]{.secno}[Generic Reporting Framework]{.content}[](#generic-reporting){.self-link} {#generic-reporting .heading .settled level="2"}

This section defines the generic concepts of reports and endpoints, and
how reports are serialized into the
[`application/reports+json`](#media-type) format.

### [2.1. ]{.secno}[Concepts]{.content}[](#concept){.self-link} {#concept .heading .settled level="2.1"}

#### [2.1.1. ]{.secno}[Endpoints]{.content}[](#concept-endpoints){.self-link} {#concept-endpoints .heading .settled level="2.1.1"}

An [endpoint]{#endpoint .dfn .dfn-paneled dfn-type="dfn" export=""} is
location to which
[reports](#windoworworkerglobalscope-reports){#ref-for-windoworworkerglobalscope-reports
link-type="dfn"} for a particular
[origin](https://html.spec.whatwg.org/multipage/browsers.html#origin){#ref-for-origin
link-type="dfn"} may be sent.

Each [endpoint](#endpoint){#ref-for-endpoint link-type="dfn"} has a
[`name`]{#dom-endpoint-name .dfn .dfn-paneled .idl-code
dfn-for="endpoint" dfn-type="attribute" export=""}, which is an ASCII
string.

Each [endpoint](#endpoint){#ref-for-endpoint① link-type="dfn"} has a
[`url`]{#dom-endpoint-url .dfn .dfn-paneled .idl-code dfn-for="endpoint"
dfn-type="attribute" export=""}, which is a
[`URL`{.idl}](https://url.spec.whatwg.org/#concept-url){#ref-for-concept-url
link-type="idl"}.

Each [endpoint](#endpoint){#ref-for-endpoint② link-type="dfn"} has a
[`failures`]{#dom-endpoint-failures .dfn .dfn-paneled .idl-code
dfn-for="endpoint" dfn-type="attribute" export=""}, which is a
non-negative integer representing the number of consecutive times this
endpoint has failed to respond to a request.

#### [2.1.2. ]{.secno}[Report Type]{.content}[](#concept-report-type){.self-link} {#concept-report-type .heading .settled level="2.1.2"}

A [report type]{#report-type .dfn .dfn-paneled dfn-type="dfn" export=""}
is a non-empty string that specifies the set of data that is contained
in the [body](#report-body){#ref-for-report-body link-type="dfn"} of a
[report](#report){#ref-for-report link-type="dfn"}.

When a [report type](#report-type){#ref-for-report-type link-type="dfn"}
is defined (in this spec or others), it can be specified to be [visible
to `ReportingObserver`s]{#visible-to-reportingobservers .dfn
.dfn-paneled dfn-type="dfn" export=""}, meaning that
[reports](#windoworworkerglobalscope-reports){#ref-for-windoworworkerglobalscope-reports①
link-type="dfn"} of that type can be observed by a [reporting
observer](#reporting-observer){#ref-for-reporting-observer
link-type="dfn"}. By default, [report
types](#report-type){#ref-for-report-type① link-type="dfn"} are not
[visible to
`ReportingObserver`s](#visible-to-reportingobservers){#ref-for-visible-to-reportingobservers
link-type="dfn"}.

#### [2.1.3. ]{.secno}[Reports]{.content}[](#concept-reports){.self-link} {#concept-reports .heading .settled level="2.1.3"}

A [report]{#report .dfn .dfn-paneled dfn-type="dfn" export=""} is a
collection of arbitrary data which the user agent is expected to deliver
to a specified endpoint.

Each [report](#report){#ref-for-report① link-type="dfn"} has a
[body]{#report-body .dfn .dfn-paneled dfn-for="report" dfn-type="dfn"
export=""}, which is either `null` or an object which can be serialized
into a [JSON
text](https://tools.ietf.org/html/rfc8259#section-2){#ref-for-section-2
link-type="dfn"}. The fields contained in a
[report](#report){#ref-for-report② link-type="dfn"}'s
[body](#report-body){#ref-for-report-body① link-type="dfn"} are
determined by the [report](#report){#ref-for-report③ link-type="dfn"}'s
[type](#report-reporttype){#ref-for-report-reporttype link-type="dfn"}.

Each [report](#report){#ref-for-report④ link-type="dfn"} has a
[url]{#report-url .dfn .dfn-paneled dfn-for="report" dfn-type="dfn"
export=""}, which is typically the address of the `Document` or `Worker`
from which the report was generated.

[Note:]{.marker} We strip the username, password, and fragment from this
serialized URL. See [§ 8.1 Capability URLs](#capability-urls).

Each [report](#report){#ref-for-report⑤ link-type="dfn"} has a [user
agent]{#report-user-agent .dfn .dfn-paneled dfn-for="report"
dfn-type="dfn" export=""}, which is the value of the `User-Agent`
[header](https://fetch.spec.whatwg.org/#concept-header){#ref-for-concept-header
link-type="dfn"} of the
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request
link-type="dfn"} from which the report was generated.

[Note:]{.marker} The [user
agent](#report-user-agent){#ref-for-report-user-agent link-type="dfn"}
of a [report](#report){#ref-for-report⑥ link-type="dfn"} represents the
`User-Agent` sent by the browser for the page which generated the
[report](#report){#ref-for-report⑦ link-type="dfn"}. This is potentially
distinct from the `User-Agent` sent in the HTTP headers when uploading
the report to a collector --- for instance, where the browser has chosen
to use a non-default `User-Agent` string such as the \"request desktop
site\" feature.

Each [report](#report){#ref-for-report⑧ link-type="dfn"} has a
[destination]{#report-destination .dfn .dfn-paneled dfn-for="report"
dfn-type="dfn" export=""}, which is a string representing the
[`name`{.idl}](#dom-endpoint-name){#ref-for-dom-endpoint-name
link-type="idl"} of the [endpoint](#endpoint){#ref-for-endpoint③
link-type="dfn"} that the report will be sent to.

Each [report](#report){#ref-for-report⑨ link-type="dfn"} has a
[type]{#report-reporttype .dfn .dfn-paneled dfn-for="report"
dfn-type="dfn" export=""}, which is a [report
type](#report-type){#ref-for-report-type② link-type="dfn"}.

Each [report](#report){#ref-for-report①⓪ link-type="dfn"} has a
[timestamp]{#report-timestamp .dfn .dfn-paneled dfn-for="report"
dfn-type="dfn" export=""}, which records the time at which the report
was generated, in milliseconds since the unix epoch.

Each [report](#report){#ref-for-report①① link-type="dfn"} has an
[attempts]{#report-attempts .dfn .dfn-paneled dfn-for="report"
dfn-type="dfn" export=""} counter, which is a non-negative integer
representing the number of times the user agent attempted to deliver the
report.

### [2.2. ]{.secno}[Media Type]{.content}[](#media-type){.self-link} {#media-type .heading .settled level="2.2"}

The media type used when POSTing reports to a specified endpoint is
`application/reports+json`.

### [2.3. ]{.secno}[ Queue `data`{.variable} as `type`{.variable} for `destination`{.variable} ]{.content}[](#queue-report){.self-link} {#queue-report .heading .settled .algorithm algorithm="Queue data as type for destination" level="2.3"}

To [generate a report]{#generate-a-report .dfn .dfn-paneled
dfn-type="dfn" noexport=""} given a serializable object
(`data`{.variable}), a string (`type`{.variable}), another string
(`destination`{.variable}), an optional [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object){#ref-for-environment-settings-object
link-type="dfn"} (`settings`{.variable}), and an optional
[`URL`{.idl}](https://url.spec.whatwg.org/#concept-url){#ref-for-concept-url①
link-type="idl"} (`url`{.variable}):

1.  Let `report`{.variable} be a new [report](#report){#ref-for-report①②
    link-type="dfn"} object with its values initialized as follows:

    [body](#report-body){#ref-for-report-body② link-type="dfn"}

    :   `data`{.variable}

    [user agent](#report-user-agent){#ref-for-report-user-agent① link-type="dfn"}

    :   The current value of
        [`navigator.userAgent`](https://html.spec.whatwg.org/multipage/system-state.html#dom-navigator-useragent){#ref-for-dom-navigator-useragent
        link-type="dfn"}

    [destination](#report-destination){#ref-for-report-destination link-type="dfn"}

    :   `destination`{.variable}

    [type](#report-reporttype){#ref-for-report-reporttype① link-type="dfn"}

    :   `type`{.variable}

    [timestamp](#report-timestamp){#ref-for-report-timestamp link-type="dfn"}

    :   The current timestamp.

    [attempts](#report-attempts){#ref-for-report-attempts link-type="dfn"}

    :   0

2.  If `url`{.variable} was not provided by the caller, let
    `url`{.variable} be `settings`{.variable}'s [creation
    URL](https://html.spec.whatwg.org/multipage/webappapis.html#creation-url){#ref-for-creation-url
    link-type="dfn"}.

3.  Set `url`{.variable}'s
    [`username`{.idl}](https://url.spec.whatwg.org/#dom-url-username){#ref-for-dom-url-username
    link-type="idl"} to the empty string, and its
    [`password`{.idl}](https://url.spec.whatwg.org/#dom-url-password){#ref-for-dom-url-password
    link-type="idl"} to `null`.

4.  Set `report`{.variable}'s [url](#report-url){#ref-for-report-url
    link-type="dfn"} to the result of executing the [URL
    serializer](https://url.spec.whatwg.org/#concept-url-serializer){#ref-for-concept-url-serializer
    link-type="dfn"} on `url`{.variable} with the *exclude fragment
    flag* set.

5.  Return `report`{.variable}.

[Note:]{.marker} [reporting
observers](#reporting-observer){#ref-for-reporting-observer①
link-type="dfn"} can only observe reports from the same [environment
settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object){#ref-for-environment-settings-object①
link-type="dfn"}.

[Note:]{.marker} We strip the username, password, and fragment from the
serialized URL in the report. See [§ 8.1 Capability
URLs](#capability-urls).

[Note:]{.marker} The user agent MAY reject reports for any reason. This
API does not guarantee delivery of arbitrary amounts of data, for
instance.

[Note:]{.marker} Non user agent clients (with no JavaScript engine)
should not interact with [reporting
observers](#reporting-observer){#ref-for-reporting-observer②
link-type="dfn"}, and thus should return in step 6.

### [2.4. ]{.secno}[Serialize Reports]{.content}[](#serialize-reports){.self-link} {#serialize-reports .heading .settled .algorithm algorithm="Serialize Reports" level="2.4"}

To [serialize a list of `reports`{.variable} to
JSON]{#serialize-a-list-of-reports-to-json .dfn .dfn-paneled
dfn-type="dfn" noexport=""},

1.  Let `collection`{.variable} be an empty list.

2.  For each `report`{.variable} in `reports`{.variable}:

    1.  Let `data`{.variable} be a map with the following key/value
        pairs:

        `age`

        :   The number of milliseconds between `report`{.variable}'s
            [timestamp](#report-timestamp){#ref-for-report-timestamp①
            link-type="dfn"} and the current time.

        `type`

        :   `report`{.variable}'s
            [type](#report-reporttype){#ref-for-report-reporttype②
            link-type="dfn"}

        `url`

        :   `report`{.variable}'s
            [url](#report-url){#ref-for-report-url① link-type="dfn"}

        `user_agent`

        :   `report`{.variable}'s [user
            agent](#report-user-agent){#ref-for-report-user-agent②
            link-type="dfn"}

        `body`

        :   `report`{.variable}'s
            [body](#report-body){#ref-for-report-body③ link-type="dfn"}

        [Note:]{.marker} Client clocks are unreliable and subject to
        skew. We therefore deliver an `age` attribute rather than an
        absolute timestamp. See also [§ 9.2 Clock
        Skew](#fingerprinting-clock-skew)

    2.  Increment `report`{.variable}'s
        [attempts](#report-attempts){#ref-for-report-attempts①
        link-type="dfn"}.

    3.  Append `data`{.variable} to `collection`{.variable}.

3.  Return the [byte
    sequence](https://infra.spec.whatwg.org/#byte-sequence){#ref-for-byte-sequence
    link-type="dfn"} resulting from executing [serialize an Infra value
    to JSON
    bytes](https://infra.spec.whatwg.org/#serialize-an-infra-value-to-json-bytes){#ref-for-serialize-an-infra-value-to-json-bytes
    link-type="dfn"} on `collection`{.variable}.
:::

::: section
## [3. ]{.secno}[Document Centered Reporting]{.content}[](#document-reporting){.self-link} {#document-reporting .heading .settled level="3"}

This section defines the mechanism for configuring reporting endpoints
for reports generated by actions in a document (or in a worker script).
Such reports have a lifetime which is tied to that of the document or
worker where they were generated.

### [3.1. ]{.secno}[Document configuration]{.content}[](#document-configuration){.self-link} {#document-configuration .heading .settled level="3.1"}

Each object implementing
[`WindowOrWorkerGlobalScope`{.idl}](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope){#ref-for-windoworworkerglobalscope
link-type="idl"} has an [endpoints]{#windoworworkerglobalscope-endpoints
.dfn .dfn-paneled dfn-for="WindowOrWorkerGlobalScope" dfn-type="dfn"
export=""} list, which is a list of
[endpoints](#endpoint){#ref-for-endpoint④ link-type="dfn"}, each of
which MUST have a distinct
[`name`{.idl}](#dom-endpoint-name){#ref-for-dom-endpoint-name①
link-type="idl"}. (Uniqueness is guaranteed by the algorithm in [§ 3.3
Process reporting endpoints for response](#process-header).)

Each object implementing
[`WindowOrWorkerGlobalScope`{.idl}](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope){#ref-for-windoworworkerglobalscope①
link-type="idl"} has an [reports]{#windoworworkerglobalscope-reports
.dfn .dfn-paneled dfn-for="WindowOrWorkerGlobalScope" dfn-type="dfn"
export=""} list, which is a list of [reports](#report){#ref-for-report①③
link-type="dfn"}.

To [initialize a global's endpoint
list]{#initialize-a-globals-endpoint-list .dfn .dfn-paneled
dfn-type="dfn" export=""}, given a
[`WindowOrWorkerGlobalScope`{.idl}](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope){#ref-for-windoworworkerglobalscope②
link-type="idl"} (`scope`{.variable}) and a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response
link-type="dfn"} (`response`{.variable}), set `scope`{.variable}'s
[endpoints](#windoworworkerglobalscope-endpoints){#ref-for-windoworworkerglobalscope-endpoints
link-type="dfn"} to the result of executing [§ 3.3 Process reporting
endpoints for response](#process-header) given `response`{.variable}.

### [3.2. ]{.secno}[The `Reporting-Endpoints` HTTP Response Header Field]{.content}[](#header){.self-link} {#header .heading .settled level="3.2"}

A server MAY define a set of reporting endpoints for a document or a
worker script resource it returns, via the
[`Reporting-Endpoints`](#reporting-endpoints){#ref-for-reporting-endpoints②
link-type="dfn"} HTTP response header field. This mechanism is defined
in [§ 3.2 The Reporting-Endpoints HTTP Response Header Field](#header),
and its processing in [§ 3.3 Process reporting endpoints for
response](#process-header).

The value of the [`Reporting-Endpoints`]{#reporting-endpoints .dfn
.dfn-paneled dfn-type="dfn" export=""} HTTP response header field is
used to construct the reporting configuration for a resource.

[`Reporting-Endpoints`](#reporting-endpoints){#ref-for-reporting-endpoints③
link-type="dfn"} is a Dictionary Structured Field
[\[STRUCTURED-FIELDS\]](#biblio-structured-fields "Structured Field Values for HTTP"){link-type="biblio"}.
Each entry in the dictionary defines an
[endpoint](#endpoint){#ref-for-endpoint⑤ link-type="dfn"} to which
reports may be delivered. The entry value MUST be a string.

Each [endpoint](#endpoint){#ref-for-endpoint⑥ link-type="dfn"} is
defined by a String Item, which is interpreted as a URI-reference. If
its value is not a valid URI-reference, that
[endpoint](#endpoint){#ref-for-endpoint⑦ link-type="dfn"} member MUST be
ignored.

Moreover, the URL that the member's value represents MUST be
[potentially
trustworthy](https://w3c.github.io/webappsec-secure-contexts/#is-origin-trustworthy){#ref-for-is-origin-trustworthy
link-type="dfn"}
[\[SECURE-CONTEXTS\]](#biblio-secure-contexts "Secure Contexts"){link-type="biblio"}.
Non-secure endpoints will be ignored.

No parameters are defined for [endpoints](#endpoint){#ref-for-endpoint⑧
link-type="dfn"}, and any parameters which are specified will be
silently ignored.

The header is represented by the following ABNF grammar
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"){link-type="biblio"}:

``` abnf
Reporting-Endpoints = sf-dictionary
```

### [3.3. ]{.secno}[ Process reporting endpoints for `response`{.variable} ]{.content}[](#process-header){.self-link} {#process-header .heading .settled .algorithm algorithm="Process reporting endpoints for response" level="3.3"}

Given a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response①
link-type="dfn"} (`response`{.variable}), this algorithm extracts and
returns a list of [endpoints](#endpoint){#ref-for-endpoint⑨
link-type="dfn"}.

1.  Abort these steps if `response`{.variable}'s [HTTPS
    state](https://fetch.spec.whatwg.org/#concept-response-https-state){#ref-for-concept-response-https-state
    .idl-code link-type="attribute"} is not \"`modern`\", and the
    [origin](https://url.spec.whatwg.org/#concept-url-origin){#ref-for-concept-url-origin
    link-type="dfn"} of `response`{.variable}'s
    [url](https://fetch.spec.whatwg.org/#concept-response-url){#ref-for-concept-response-url
    .idl-code link-type="attribute"} is not [potentially
    trustworthy](https://w3c.github.io/webappsec-secure-contexts/#is-origin-trustworthy){#ref-for-is-origin-trustworthy①
    link-type="dfn"}.

2.  Let `parsed header`{.variable} be the result of executing [get a
    structured field
    value](https://fetch.spec.whatwg.org/#concept-header-list-get-structured-header){#ref-for-concept-header-list-get-structured-header
    link-type="dfn"} given \"Reporting-Endpoints\" and \"dictionary\"
    from `response`{.variable}'s [header
    list](https://fetch.spec.whatwg.org/#concept-response-header-list){#ref-for-concept-response-header-list
    .idl-code link-type="attribute"}.

3.  If `parsed header`{.variable} is null, abort these steps.

4.  Let `endpoints`{.variable} be an empty list.

5.  For each `name`{.variable} → `value_and_parameters`{.variable} of
    `parsed header`{.variable}:

    1.  Let `endpoint url string`{.variable} be the first element of the
        tuple `value_and_parameters`{.variable}. If
        `endpoint url string`{.variable} is not a string, then
        [continue](https://infra.spec.whatwg.org/#iteration-continue){#ref-for-iteration-continue
        link-type="dfn"}.

    2.  Let `endpoint url`{.variable} be the result of executing the
        [URL
        parser](https://url.spec.whatwg.org/#concept-url-parser){#ref-for-concept-url-parser
        link-type="dfn"} on `endpoint url string`{.variable}, with [base
        URL](https://url.spec.whatwg.org/#concept-base-url){#ref-for-concept-base-url
        link-type="dfn"} set to `response`{.variable}'s
        [url](https://fetch.spec.whatwg.org/#concept-response-url){#ref-for-concept-response-url①
        .idl-code link-type="attribute"}. If `endpoint url`{.variable}
        is failure, then
        [continue](https://infra.spec.whatwg.org/#iteration-continue){#ref-for-iteration-continue①
        link-type="dfn"}.

    3.  If `endpoint url`{.variable}'s
        [origin](https://html.spec.whatwg.org/multipage/browsers.html#origin){#ref-for-origin①
        link-type="dfn"} is not [potentially
        trustworthy](https://w3c.github.io/webappsec-secure-contexts/#is-origin-trustworthy){#ref-for-is-origin-trustworthy②
        link-type="dfn"}, then
        [continue](https://infra.spec.whatwg.org/#iteration-continue){#ref-for-iteration-continue②
        link-type="dfn"}.

    4.  Let `endpoint`{.variable} be a new
        [endpoint](#endpoint){#ref-for-endpoint①⓪ link-type="dfn"} whose
        properties are set as follows:

        [`name`{.idl}](#dom-endpoint-name){#ref-for-dom-endpoint-name② link-type="idl"}

        :   `name`{.variable}

        [`url`{.idl}](#dom-endpoint-url){#ref-for-dom-endpoint-url link-type="idl"}

        :   `endpoint url`{.variable}

        [`failures`{.idl}](#dom-endpoint-failures){#ref-for-dom-endpoint-failures link-type="idl"}

        :   0

    5.  Add `endpoint`{.variable} to `endpoints`{.variable}.

6.  Return `endpoints`{.variable}.

### [3.4. ]{.secno}[Report Generation]{.content}[](#report-generation){.self-link} {#report-generation .heading .settled level="3.4"}

#### [3.4.1. ]{.secno}[Generate report of `type`{.variable} with `data`{.variable}]{.content}[](#generate-report){.self-link} {#generate-report .heading .settled .algorithm algorithm="Generate report of type with
  data" export="" level="3.4.1"}

When the user agent is to [generate and queue a
report]{#generate-and-queue-a-report .dfn .dfn-paneled dfn-type="dfn"
export=""} for a
[`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document
link-type="idl"} or
[`WorkerGlobalScope`{.idl}](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope){#ref-for-workerglobalscope
link-type="idl"} object
([`context`{.variable}]{#generate-and-queue-a-report-context .dfn
.dfn-paneled dfn-for="generate and queue a report" dfn-type="dfn"
export=""}), given a string
([`type`{.variable}]{#generate-and-queue-a-report-type .dfn .dfn-paneled
dfn-for="generate and queue a report" dfn-type="dfn" export=""}), a
string
([`destination`{.variable}]{#generate-and-queue-a-report-destination
.dfn .dfn-paneled dfn-for="generate and queue a report" dfn-type="dfn"
export=""}), and a serializable object
([`data`{.variable}]{#generate-and-queue-a-report-data .dfn .dfn-paneled
dfn-for="generate and queue a report" dfn-type="dfn" export=""}), it
must run the following steps:

1.  Let `settings`{.variable} be `context`{.variable}'s [relevant
    settings
    object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object){#ref-for-relevant-settings-object
    link-type="dfn"}.

2.  Let `report`{.variable} be the result of running [generate a
    report](#generate-a-report){#ref-for-generate-a-report
    link-type="dfn"} with `data`{.variable}, `type`{.variable},
    `destination`{.variable} and `settings`{.variable}.

3.  If `settings`{.variable} is given, then

    1.  Let `scope`{.variable} be `settings`{.variable}'s [global
        object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global){#ref-for-concept-settings-object-global
        link-type="dfn"}.

    2.  If `scope`{.variable} is an object implementing
        [`WindowOrWorkerGlobalScope`{.idl}](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope){#ref-for-windoworworkerglobalscope③
        link-type="idl"}, then execute [§ 4.2 Notify reporting observers
        on scope with report](#notify-observers) with `scope`{.variable}
        and `report`{.variable}.

4.  Append `report`{.variable} to `context`{.variable}'s
    [reports](#windoworworkerglobalscope-reports){#ref-for-windoworworkerglobalscope-reports②
    link-type="dfn"}.

### [3.5. ]{.secno}[Report Delivery]{.content}[](#report-delivery){.self-link} {#report-delivery .heading .settled level="3.5"}

Over time, various features will queue up a list of
[reports](#windoworworkerglobalscope-reports){#ref-for-windoworworkerglobalscope-reports③
link-type="dfn"} in documents and workers. The user agent will
periodically grab the list of currently queued reports, and deliver them
to the associated endpoints. This document does not define a schedule
for the user agent to follow, and assumes that the user agent will have
enough contextual information to deliver reports in a timely manner,
balanced against impacting a user's experience.

That said, a user agent SHOULD make an effort to deliver reports as soon
as possible after queuing, as a report's data might be significantly
more useful in the period directly after its generation than it would be
a day or a week later.

#### [3.5.1. ]{.secno}[Send reports]{.content}[](#send-reports){.self-link} {#send-reports .heading .settled .algorithm algorithm="Send reports" level="3.5.1"}

A user agent sends a list of
[reports](#windoworworkerglobalscope-reports){#ref-for-windoworworkerglobalscope-reports④
link-type="dfn"} (`reports`{.variable}) for
[`WindowOrWorkerGlobalScope`{.idl}](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope){#ref-for-windoworworkerglobalscope④
link-type="idl"} object (`context`{.variable}) by executing the
following steps:

1.  Let `endpoint map`{.variable} be an empty map of
    [endpoint](#endpoint){#ref-for-endpoint①① link-type="dfn"} objects
    to lists of [report](#report){#ref-for-report①④ link-type="dfn"}
    objects.

2.  For each `report`{.variable} in `reports`{.variable}:

    1.  If there exists an [endpoint](#endpoint){#ref-for-endpoint①②
        link-type="dfn"} (`endpoint`{.variable}) in
        `context`{.variable}'s
        [endpoints](#windoworworkerglobalscope-endpoints){#ref-for-windoworworkerglobalscope-endpoints①
        link-type="dfn"} list whose
        [`name`{.idl}](#dom-endpoint-name){#ref-for-dom-endpoint-name③
        link-type="idl"} is `report`{.variable}'s
        [destination](#report-destination){#ref-for-report-destination①
        link-type="dfn"}:

        1.  Append `report`{.variable} to `endpoint map`{.variable}'s
            list of reports for `endpoint`{.variable}.

        2.  Otherwise, remove `report`{.variable} from
            `reports`{.variable}.

3.  For each (`endpoint`{.variable}, `report list`{.variable}) pair in
    `endpoint map`{.variable}:

    1.  Let `origin map`{.variable} be an empty map of
        [origins](https://html.spec.whatwg.org/multipage/browsers.html#origin){#ref-for-origin②
        link-type="dfn"} to lists of [report](#report){#ref-for-report①⑤
        link-type="dfn"} objects.

    2.  For each `report`{.variable} in `report list`{.variable}:

        1.  Let `origin`{.variable} be the
            [origin](https://html.spec.whatwg.org/multipage/browsers.html#origin){#ref-for-origin③
            link-type="dfn"} of `report`{.variable}'s
            [url](#report-url){#ref-for-report-url② link-type="dfn"}.

        2.  Append `report`{.variable} to `origin map`{.variable}'s list
            of reports for `origin`{.variable}.

    3.  For each (`origin`{.variable}, `per-origin reports`{.variable})
        pair in `origin map`{.variable}, execute the following steps
        asynchronously:

        1.  Let `result`{.variable} be the result of executing [§ 3.5.2
            Attempt to deliver reports to endpoint](#try-delivery) on
            `endpoint`{.variable}, `origin`{.variable}, and
            `per-origin reports`{.variable}.

        2.  If `result`{.variable} is \"`Failure`\":

            1.  Increment `endpoint`{.variable}'s
                [`failures`{.idl}](#dom-endpoint-failures){#ref-for-dom-endpoint-failures①
                link-type="idl"}.

        3.  If `result`{.variable} is \"`Remove Endpoint`\":

            1.  Remove `endpoint`{.variable} from `context`{.variable}'s
                [endpoints](#windoworworkerglobalscope-endpoints){#ref-for-windoworworkerglobalscope-endpoints②
                link-type="dfn"} list.

        4.  Remove each [report](#report){#ref-for-report①⑥
            link-type="dfn"} from `reports`{.variable}.

        [](#issue-7f6dd3bd){.self-link} We don't specify any retry
        mechanism here for failed reports. We may want to add one here,
        or provide some indication that the delivery failed.

[Note:]{.marker} User agents MAY decide to attempt delivery for only a
subset of the collected reports or endpoints (because, for example,
sending all the reports at once would consume an unreasonable amount of
bandwidth, etc). As reports are only removed from the cache after
delivery has been attempted, skipped reports will simply be delivered
later.

#### [3.5.2. ]{.secno}[ Attempt to deliver `reports`{.variable} to `endpoint`{.variable} ]{.content}[](#try-delivery){.self-link} {#try-delivery .heading .settled .algorithm algorithm="Attempt to deliver reports to endpoint" level="3.5.2"}

Given an [endpoint](#endpoint){#ref-for-endpoint①③ link-type="dfn"}
(`endpoint`{.variable}), an
[origin](https://html.spec.whatwg.org/multipage/browsers.html#origin){#ref-for-origin④
link-type="dfn"} (`origin`{.variable}), and a list of
[reports](#windoworworkerglobalscope-reports){#ref-for-windoworworkerglobalscope-reports⑤
link-type="dfn"} (`reports`{.variable}), this algorithm will construct a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request①
link-type="dfn"}, and attempt to deliver it to `endpoint`{.variable}. It
returns \"`Success`\" if that delivery succeeds, \"`Remove Endpoint`\"
if the endpoint explicitly removes itself as a reporting endpoint by
sending a 410 response, and \"`Failure`\" otherwise.

1.  Let `body`{.variable} be the result of executing [serialize a list
    of reports to
    JSON](#serialize-a-list-of-reports-to-json){#ref-for-serialize-a-list-of-reports-to-json
    link-type="dfn"} on `reports`{.variable}.

2.  Let `request`{.variable} be a new
    [request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request②
    link-type="dfn"} with the following properties
    [\[FETCH\]](#biblio-fetch "Fetch Standard"){link-type="biblio"}:

    `method`

    :   \"`POST`\"

    `url`

    :   `endpoint`{.variable}'s
        [`url`{.idl}](#dom-endpoint-url){#ref-for-dom-endpoint-url①
        link-type="idl"}

    `origin`

    :   `origin`{.variable}

    `header list`

    :   A new [header
        list](https://fetch.spec.whatwg.org/#concept-header-list){#ref-for-concept-header-list
        link-type="dfn"} containing a
        [header](https://fetch.spec.whatwg.org/#concept-header){#ref-for-concept-header①
        link-type="dfn"} named \``Content-Type`\` whose value is
        \``application/reports+json`\`

    `client`

    :   `null`

    `window`

    :   \"`no-window`\"

    `service-workers mode`

    :   \"`none`\"

    `initiator`

    :   \"\"

    `destination`

    :   \"`report`\"

    `mode`

    :   \"`cors`\"

    `unsafe-request` flag

    :   set

    `credentials`

    :   \"`same-origin`\"

    `body`

    :   A
        [body](https://fetch.spec.whatwg.org/#concept-body){#ref-for-concept-body
        link-type="dfn"} whose
        [source](https://fetch.spec.whatwg.org/#concept-body-source){#ref-for-concept-body-source
        link-type="dfn"} is `body`{.variable}.

    [Note:]{.marker} Reports are sent with credentials set to
    `same-origin`. This allows reporting endpoints which are same-origin
    with the reporting page to get extra context about the nature of the
    report: for example, to understand whether a given user's account is
    triggering errors consistently, or if a certain sequence of actions
    taken on other pages is triggering a report on this page. This does
    not leak any new information to the reporting endpoint that it could
    not obtain in other ways. That is not the case for cross-origin
    reporting endpoints, so they do not receive credentials.

3.  [Queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){#ref-for-queue-a-task
    link-type="dfn"} to
    [fetch](https://fetch.spec.whatwg.org/#concept-fetch){#ref-for-concept-fetch
    link-type="dfn"} `request`{.variable}.

4.  [Wait for a
    response](https://fetch.spec.whatwg.org/#wait-for-a-response){#ref-for-wait-for-a-response
    link-type="dfn"} (`response`{.variable}).

5.  If `response`{.variable}'s `status` is an [OK
    status](https://fetch.spec.whatwg.org/#ok-status){#ref-for-ok-status
    link-type="dfn"} (200-299), return \"`Success`\".

6.  If `response`{.variable}'s `status` is `410 Gone`
    [\[RFC9110\]](#biblio-rfc9110 "HTTP Semantics"){link-type="biblio"},
    return \"`Remove Endpoint`\".

7.  Return \"`Failure`\".

### [3.6. ]{.secno}[Strip URL for use in reports]{.content}[](#strip-url-for-use-in-reports-heading){.self-link} {#strip-url-for-use-in-reports-heading .heading .settled level="3.6"}

To [strip URL for use in reports]{#strip-url-for-use-in-reports .dfn
.dfn-paneled .algorithm algorithm="strip URL for use in reports"
dfn-type="dfn" export=""} given a
[URL](https://url.spec.whatwg.org/#concept-url){#ref-for-concept-url②
link-type="dfn" refhint-key="https://url.spec.whatwg.org/#concept-url"}
`url`{.variable}, perform the following steps. They return a string
representing the URL for use in reports.

1.  If `url`{.variable}'s
    [scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme
    link-type="dfn"} is not an [HTTP(S)
    scheme](https://fetch.spec.whatwg.org/#http-scheme){#ref-for-http-scheme
    link-type="dfn"}, then return `url`{.variable}'s
    [scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme①
    link-type="dfn"}.

2.  Set `url`{.variable}'s
    [fragment](https://url.spec.whatwg.org/#concept-url-fragment){#ref-for-concept-url-fragment
    link-type="dfn"} to the empty string.

3.  Set `url`{.variable}'s
    [username](https://url.spec.whatwg.org/#concept-url-username){#ref-for-concept-url-username
    link-type="dfn"} to the empty string.

4.  Set `url`{.variable}'s
    [password](https://url.spec.whatwg.org/#concept-url-password){#ref-for-concept-url-password
    link-type="dfn"} to the empty string.

5.  Return the result of executing the [URL
    serializer](https://url.spec.whatwg.org/#concept-url-serializer){#ref-for-concept-url-serializer①
    link-type="dfn"} on `url`{.variable}.
:::

::: section
## [4. ]{.secno}[Reporting Observers]{.content}[](#observers){.self-link} {#observers .heading .settled level="4"}

A [reporting observer]{#reporting-observer .dfn .dfn-paneled
dfn-type="dfn" noexport=""} observes some types of
[reports](#windoworworkerglobalscope-reports){#ref-for-windoworworkerglobalscope-reports⑥
link-type="dfn"} from JavaScript, and is represented in JavaScript by
the
[`ReportingObserver`{.idl}](#reportingobserver){#ref-for-reportingobserver
link-type="idl"} object.

Each object implementing
[`WindowOrWorkerGlobalScope`{.idl}](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope){#ref-for-windoworworkerglobalscope⑤
link-type="idl"} has a [registered reporting observer
list]{#windoworworkerglobalscope-registered-reporting-observer-list .dfn
.dfn-paneled dfn-for="WindowOrWorkerGlobalScope" dfn-type="dfn"
noexport=""}, which is an [ordered
set](https://infra.spec.whatwg.org/#ordered-set){#ref-for-ordered-set
link-type="dfn"} of [reporting
observers](#reporting-observer){#ref-for-reporting-observer③
link-type="dfn"}.

Any [reporting
observer](#reporting-observer){#ref-for-reporting-observer④
link-type="dfn"} that is in a [registered reporting observer
list](#windoworworkerglobalscope-registered-reporting-observer-list){#ref-for-windoworworkerglobalscope-registered-reporting-observer-list
link-type="dfn"} is considered [registered]{#registered .dfn
.dfn-paneled dfn-type="dfn" noexport=""}.

Each object implementing
[`WindowOrWorkerGlobalScope`{.idl}](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope){#ref-for-windoworworkerglobalscope⑥
link-type="idl"} has a [report
buffer]{#windoworworkerglobalscope-report-buffer .dfn .dfn-paneled
dfn-for="WindowOrWorkerGlobalScope" dfn-type="dfn" noexport=""}, which
is a [list](https://infra.spec.whatwg.org/#list){#ref-for-list
link-type="dfn"} of
[reports](#windoworworkerglobalscope-reports){#ref-for-windoworworkerglobalscope-reports⑦
link-type="dfn"} that have been generated in that
[`WindowOrWorkerGlobalScope`{.idl}](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope){#ref-for-windoworworkerglobalscope⑦
link-type="idl"}. This list is initially empty, and the reports are
stored in the same order in which they are generated.

[Note:]{.marker} The purpose of the [report
buffer](#windoworworkerglobalscope-report-buffer){#ref-for-windoworworkerglobalscope-report-buffer
link-type="dfn"} is to allow [reporting
observers](#reporting-observer){#ref-for-reporting-observer⑤
link-type="dfn"} to observe reports that were generated earlier than
that observer could be created (via the
[`buffered`{.idl}](#dom-reportingobserveroptions-buffered){#ref-for-dom-reportingobserveroptions-buffered
link-type="idl"} option). For example, some reports might be generated
during an earlier stage of page loading than when an observer could
first be created, or before a JavaScript library is loaded that wishes
to observe these reports.

[Note:]{.marker} [Reporting
observers](#reporting-observer){#ref-for-reporting-observer⑥
link-type="dfn"} are only relevant for user agents with JavaScript
engines.

### [4.1. ]{.secno}[Interface [`ReportingObserver`{.idl}](#reportingobserver){#ref-for-reportingobserver① link-type="idl"}]{.content}[](#interface-reporting-observer){.self-link} {#interface-reporting-observer .heading .settled level="4.1"}

``` {.idl .highlight .def}
dictionary ReportBody {
};

dictionary Report {
  DOMString type;
  DOMString url;
  ReportBody? body;
};

[Exposed=(Window,Worker)]
interface ReportingObserver {
  constructor(ReportingObserverCallback callback, optional ReportingObserverOptions options = {});
  undefined observe();
  undefined disconnect();
  ReportList takeRecords();
};

callback ReportingObserverCallback = undefined (sequence<Report> reports, ReportingObserver observer);

dictionary ReportingObserverOptions {
  sequence<DOMString> types;
  boolean buffered = false;
};

typedef sequence<Report> ReportList;
```

A [`Report`]{#dom-report .dfn .dfn-paneled .idl-code
dfn-type="dictionary" export=""} is the application-exposed
representation of a [report](#report){#ref-for-report①⑦
link-type="dfn"}.

[`ReportBody`]{#reportbody .dfn .dfn-paneled .idl-code
dfn-type="dictionary" export=""} is an abstract
[dictionary](https://webidl.spec.whatwg.org/#dfn-dictionary){#ref-for-dfn-dictionary
link-type="dfn"} type from which specific report types should
[inherit](https://webidl.spec.whatwg.org/#dfn-inherit-dictionary){#ref-for-dfn-inherit-dictionary
link-type="dfn"}.

Each
[`ReportingObserver`{.idl}](#reportingobserver){#ref-for-reportingobserver③
link-type="idl"} object has these associated concepts:

- A [callback]{#reportingobserver-callback .dfn .dfn-paneled
  dfn-for="ReportingObserver" dfn-type="dfn" noexport=""} function set
  on creation.

- A
  [`ReportingObserverOptions`{.idl}](#dictdef-reportingobserveroptions){#ref-for-dictdef-reportingobserveroptions①
  link-type="idl"} dictionary called
  [options]{#reportingobserver-options .dfn .dfn-paneled
  dfn-for="ReportingObserver" dfn-type="dfn" noexport=""}.

- A list of [`Report`{.idl}](#dom-report){#ref-for-dom-report③
  link-type="idl"} objects called the [report
  queue]{#reportingobserver-report-queue .dfn .dfn-paneled
  dfn-for="ReportingObserver" dfn-type="dfn" lt="report queue"
  noexport=""}, which is initially empty.

A
[`ReportList`{.idl}](#typedefdef-reportlist){#ref-for-typedefdef-reportlist①
link-type="idl"} represents a sequence of
[`Report`{.idl}](#dom-report){#ref-for-dom-report④ link-type="idl"}s,
providing developers with all the convenience methods found on
JavaScript arrays.

The
[` ReportingObserver(``callback`{.variable}`, ``options`{.variable}`)`]{#dom-reportingobserver-reportingobserver
.dfn .dfn-paneled .idl-code dfn-for="ReportingObserver"
dfn-type="constructor" export=""
lt="ReportingObserver(callback, options)|constructor(callback, options)|ReportingObserver(callback)|constructor(callback)"}
constructor, when invoked, must run these steps:

1.  Create a new
    [`ReportingObserver`{.idl}](#reportingobserver){#ref-for-reportingobserver④
    link-type="idl"} object `observer`{.variable}.

2.  Set `observer`{.variable}'s
    [callback](#reportingobserver-callback){#ref-for-reportingobserver-callback
    link-type="dfn"} to `callback`{.variable}.

3.  Set `observer`{.variable}'s
    [options](#reportingobserver-options){#ref-for-reportingobserver-options
    link-type="dfn"} to `options`{.variable}.

4.  Return `observer`{.variable}.

The [`observe()`]{#dom-reportingobserver-observe .dfn .dfn-paneled
.idl-code dfn-for="ReportingObserver" dfn-type="method" export=""}
method, when invoked, must run these steps:

1.  Let `global`{.variable} be the be the [relevant global
    object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global){#ref-for-concept-relevant-global
    link-type="dfn"} of
    [this](https://webidl.spec.whatwg.org/#this){#ref-for-this
    link-type="dfn"}.

2.  Append [this](https://webidl.spec.whatwg.org/#this){#ref-for-this①
    link-type="dfn"} to the `global`{.variable}'s [registered reporting
    observer
    list](#windoworworkerglobalscope-registered-reporting-observer-list){#ref-for-windoworworkerglobalscope-registered-reporting-observer-list①
    link-type="dfn"}.

3.  If [this](https://webidl.spec.whatwg.org/#this){#ref-for-this②
    link-type="dfn"}'s
    [`buffered`{.idl}](#dom-reportingobserveroptions-buffered){#ref-for-dom-reportingobserveroptions-buffered①
    link-type="idl"}
    [option](#reportingobserver-options){#ref-for-reportingobserver-options①
    link-type="dfn"} is false, return.

4.  Set [this](https://webidl.spec.whatwg.org/#this){#ref-for-this③
    link-type="dfn"}'s
    [`buffered`{.idl}](#dom-reportingobserveroptions-buffered){#ref-for-dom-reportingobserveroptions-buffered②
    link-type="idl"}
    [option](#reportingobserver-options){#ref-for-reportingobserver-options②
    link-type="dfn"} to false.

5.  For each `report`{.variable} in `global`{.variable}'s [report
    buffer](#windoworworkerglobalscope-report-buffer){#ref-for-windoworworkerglobalscope-report-buffer①
    link-type="dfn"}, [queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){#ref-for-queue-a-task①
    link-type="dfn"} to execute [§ 4.3 Add report to
    observer](#add-report) with `report`{.variable} and
    [this](https://webidl.spec.whatwg.org/#this){#ref-for-this④
    link-type="dfn"}.

The [`disconnect()`]{#dom-reportingobserver-disconnect .dfn .dfn-paneled
.idl-code dfn-for="ReportingObserver" dfn-type="method" export=""}
method, when invoked, must run these steps:

1.  If [this](https://webidl.spec.whatwg.org/#this){#ref-for-this⑤
    link-type="dfn"} is not
    [registered](#registered){#ref-for-registered link-type="dfn"},
    return.

2.  Let `global`{.variable} be the [relevant global
    object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global){#ref-for-concept-relevant-global①
    link-type="dfn"} of
    [this](https://webidl.spec.whatwg.org/#this){#ref-for-this⑥
    link-type="dfn"}.

3.  Remove [this](https://webidl.spec.whatwg.org/#this){#ref-for-this⑦
    link-type="dfn"} from `global`{.variable}'s [registered reporting
    observer
    list](#windoworworkerglobalscope-registered-reporting-observer-list){#ref-for-windoworworkerglobalscope-registered-reporting-observer-list②
    link-type="dfn"}.

The [`takeRecords()`]{#dom-reportingobserver-takerecords .dfn
.dfn-paneled .idl-code dfn-for="ReportingObserver" dfn-type="method"
export=""} method, when invoked, must run these steps:

1.  Let `reports`{.variable} be a copy of
    [this](https://webidl.spec.whatwg.org/#this){#ref-for-this⑧
    link-type="dfn"}'s [report
    queue](#reportingobserver-report-queue){#ref-for-reportingobserver-report-queue
    link-type="dfn"}.

2.  Empty [this](https://webidl.spec.whatwg.org/#this){#ref-for-this⑨
    link-type="dfn"}'s [report
    queue](#reportingobserver-report-queue){#ref-for-reportingobserver-report-queue①
    link-type="dfn"}.

3.  Return `reports`{.variable}.

### [4.2. ]{.secno}[ Notify reporting observers on `scope`{.variable} with `report`{.variable} ]{.content}[](#notify-observers){.self-link} {#notify-observers .heading .settled .algorithm algorithm="Notify reporting observers on scope with report" level="4.2"}

This algorithm makes `report`{.variable}'s contents available to any
[registered](#registered){#ref-for-registered① link-type="dfn"}
[reporting observers](#reporting-observer){#ref-for-reporting-observer⑦
link-type="dfn"} on the provided
[`WindowOrWorkerGlobalScope`{.idl}](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope){#ref-for-windoworworkerglobalscope⑧
link-type="idl"}.

1.  For each
    [`ReportingObserver`{.idl}](#reportingobserver){#ref-for-reportingobserver⑤
    link-type="idl"} `observer`{.variable}
    [registered](#registered){#ref-for-registered② link-type="dfn"} with
    `scope`{.variable}, execute [§ 4.3 Add report to
    observer](#add-report) on `report`{.variable} and
    `observer`{.variable}.

2.  Append `report`{.variable} to `scope`{.variable}'s [report
    buffer](#windoworworkerglobalscope-report-buffer){#ref-for-windoworworkerglobalscope-report-buffer②
    link-type="dfn"}.

3.  Let `type`{.variable} be `report`{.variable}'s
    [type](#report-reporttype){#ref-for-report-reporttype③
    link-type="dfn"}.

4.  If `scope`{.variable}'s [report
    buffer](#windoworworkerglobalscope-report-buffer){#ref-for-windoworworkerglobalscope-report-buffer③
    link-type="dfn"} now contains more than 100 reports with
    [type](#report-reporttype){#ref-for-report-reporttype④
    link-type="dfn"} equal to `type`{.variable}, remove the earliest
    item with [type](#report-reporttype){#ref-for-report-reporttype⑤
    link-type="dfn"} equal to `type`{.variable} in the [report
    buffer](#windoworworkerglobalscope-report-buffer){#ref-for-windoworworkerglobalscope-report-buffer④
    link-type="dfn"}.

### [4.3. ]{.secno}[ Add `report`{.variable} to `observer`{.variable} ]{.content}[](#add-report){.self-link} {#add-report .heading .settled .algorithm algorithm="Add report to observer" level="4.3"}

Given a [report](#report){#ref-for-report①⑧ link-type="dfn"}
`report`{.variable} and a
[`ReportingObserver`{.idl}](#reportingobserver){#ref-for-reportingobserver⑥
link-type="idl"} `observer`{.variable}, this algorithm adds
`report`{.variable} to `observer`{.variable}'s [report
queue](#reportingobserver-report-queue){#ref-for-reportingobserver-report-queue②
link-type="dfn"}, so long as `report`{.variable}'s
[type](#report-reporttype){#ref-for-report-reporttype⑥ link-type="dfn"}
is observable by `observer`{.variable}.

1.  If `report`{.variable}'s
    [type](#report-reporttype){#ref-for-report-reporttype⑦
    link-type="dfn"} is not [visible to
    `ReportingObserver`s](#visible-to-reportingobservers){#ref-for-visible-to-reportingobservers①
    link-type="dfn"}, return.

2.  If `observer`{.variable}'s
    [options](#reportingobserver-options){#ref-for-reportingobserver-options③
    link-type="dfn"} has a non-empty
    [`types`{.idl}](#dom-reportingobserveroptions-types){#ref-for-dom-reportingobserveroptions-types
    link-type="idl"} member which does not contain `report`{.variable}'s
    [type](#report-reporttype){#ref-for-report-reporttype⑧
    link-type="dfn"}, return.

3.  Create a new [`Report`{.idl}](#dom-report){#ref-for-dom-report⑤
    link-type="idl"} `r`{.variable} with
    [`type`{.idl}](#dom-report-type){#ref-for-dom-report-type
    link-type="idl"} initialized to `report`{.variable}'s
    [type](#report-reporttype){#ref-for-report-reporttype⑨
    link-type="dfn"},
    [`url`{.idl}](#dom-report-url){#ref-for-dom-report-url
    link-type="idl"} initialized to `report`{.variable}'s
    [url](#report-url){#ref-for-report-url③ link-type="dfn"}, and
    [`body`{.idl}](#dom-report-body){#ref-for-dom-report-body
    link-type="idl"} initialized to `report`{.variable}'s
    [body](#report-body){#ref-for-report-body④ link-type="dfn"}.

[](#issue-6311d126){.self-link} how to polymorphically initialize body?

3.  Append `r`{.variable} to `observer`{.variable}'s [report
    queue](#reportingobserver-report-queue){#ref-for-reportingobserver-report-queue③
    link-type="dfn"}.

4.  If the size of `observer`{.variable}'s [report
    queue](#reportingobserver-report-queue){#ref-for-reportingobserver-report-queue④
    link-type="dfn"} is 1:

    1.  Let `global`{.variable} be `observer`{.variable}'s [relevant
        global
        object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global){#ref-for-concept-relevant-global②
        link-type="dfn"}.

    2.  [Queue a
        task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){#ref-for-queue-a-task②
        link-type="dfn"} to [§ 4.4 Invoke reporting observers with
        notify list](#invoke-observers) with a copy of
        `global`{.variable}'s [registered reporting observer
        list](#windoworworkerglobalscope-registered-reporting-observer-list){#ref-for-windoworworkerglobalscope-registered-reporting-observer-list③
        link-type="dfn"}.

### [4.4. ]{.secno}[ Invoke reporting observers with `notify list`{.variable} ]{.content}[](#invoke-observers){.self-link} {#invoke-observers .heading .settled .algorithm algorithm="Invoke reporting observers with notify list" level="4.4"}

This algorithm invokes observer callback functions for reports of
previously observed behavior.

1.  For each
    [`ReportingObserver`{.idl}](#reportingobserver){#ref-for-reportingobserver⑦
    link-type="idl"} `observer`{.variable} in `notify list`{.variable}:

    1.  If `observer`{.variable}'s [report
        queue](#reportingobserver-report-queue){#ref-for-reportingobserver-report-queue⑤
        link-type="dfn"} is empty, then continue.

    2.  Let `reports`{.variable} be a copy of `observer`{.variable}'s
        [report
        queue](#reportingobserver-report-queue){#ref-for-reportingobserver-report-queue⑥
        link-type="dfn"}

    3.  Empty `observer`{.variable}'s [report
        queue](#reportingobserver-report-queue){#ref-for-reportingobserver-report-queue⑦
        link-type="dfn"}

    4.  [Invoke](https://webidl.spec.whatwg.org/#invoke-a-callback-function){#ref-for-invoke-a-callback-function
        link-type="dfn"} `observer`{.variable}'s
        [callback](#reportingobserver-callback){#ref-for-reportingobserver-callback①
        link-type="dfn"} with « `reports`{.variable},
        `observer`{.variable} » and \"`report`\", and with
        `observer`{.variable} as the [callback this
        value](https://webidl.spec.whatwg.org/#dfn-callback-this-value){#ref-for-dfn-callback-this-value
        link-type="dfn"}.
:::

::: section
## [5. ]{.secno}[Implementation Considerations]{.content}[](#implementation){.self-link} {#implementation .heading .settled level="5"}

### [5.1. ]{.secno}[Delivery]{.content}[](#delivery){.self-link} {#delivery .heading .settled level="5.1"}

The user agent SHOULD attempt to deliver reports as soon as possible to
provide feedback to developers as quickly as possible. However, when
this desire is balanced against the impact on the user, the user wins.
With that in mind, the user agent MAY delay delivery of reports based on
its knowledge of the user's activities and context.

For instance, the user agent SHOULD prioritize the transmission of
reporting data lower than other network traffic. The user's explicit
activities on a website should preempt reporting traffic.

The user agent MAY choose to withhold report delivery entirely until the
user is on a fast, cheap network in order to prevent unnecessary data
cost.

The user agent MAY choose to prioritize reports from particular origins
over others (perhaps those that the user visits most often?)

### [5.2. ]{.secno}[Garbage Collection]{.content}[](#gc){.self-link} {#gc .heading .settled level="5.2"}

Periodically, the user agent SHOULD walk through the cached
[reports](#report){#ref-for-report①⑨ link-type="dfn"} and
[endpoints](#endpoint){#ref-for-endpoint①④ link-type="dfn"}, and discard
those that are no longer relevant. These include:

- [endpoints](#endpoint){#ref-for-endpoint①⑤ link-type="dfn"} whose
  [`failures`{.idl}](#dom-endpoint-failures){#ref-for-dom-endpoint-failures②
  link-type="idl"} exceed some user-agent-defined threshold (\~5 seems
  reasonable)

- [reports](#report){#ref-for-report②⓪ link-type="dfn"} which have not
  been delivered in some arbitrary period of time (perhaps \~2 days?)

For any [reports](#report){#ref-for-report②① link-type="dfn"} that are
discarded, these
[reports](#windoworworkerglobalscope-reports){#ref-for-windoworworkerglobalscope-reports⑧
link-type="dfn"} should also be removed from the [report
buffer](#windoworworkerglobalscope-report-buffer){#ref-for-windoworworkerglobalscope-report-buffer⑤
link-type="dfn"} of any [reporting
observer](#reporting-observer){#ref-for-reporting-observer⑧
link-type="dfn"}.
:::

:::: {.section .non-normative}
## [6. ]{.secno}[Sample Reports]{.content}[](#sample-reports){.self-link} {#sample-reports .heading .settled level="6"}

*This section is non-normative.*

This example shows the format in which reports are sent by the user
agent to the reporting endpoint. The sample submission contains three
reports which have been bundled together and sent in a single HTTP
request. (The report types and bodies themselves are not intended to be
representative of any actual feature, as those are outside of the scope
of this specification).

::: {#example-3cfcdab2 .example}
[](#example-3cfcdab2){.self-link}

    POST / HTTP/1.1
    Host: example.com
    ...
    Content-Type: application/reports+json

    [{
      "type": "security-violation",
      "age": 10,
      "url": "https://example.com/vulnerable-page/",
      "user_agent": "Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0",
      "body": {
        "blocked": "https://evil.com/evil.js",
        "policy": "bad-behavior 'none'",
        "status": 200,
        "referrer": "https://evil.com/"
      }
    }, {
      "type": "certificate-issue",
      "age": 32,
      "url": "https://www.example.com/",
      "user_agent": "Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0",
      "body": {
        "date-time": "2014-04-06T13:00:50Z",
        "hostname": "www.example.com",
        "port": 443,
        "effective-expiration-date": "2014-05-01T12:40:50Z",
        "served-certificate-chain": [
          "-----BEGIN CERTIFICATE-----\n
          MIIEBDCCAuygAwIBAgIDAjppMA0GCSqGSIb3DQEBBQUAMEIxCzAJBgNVBAYTAlVT\n
          ...
          HFa9llF7b1cq26KqltyMdMKVvvBulRP/F/A8rLIQjcxz++iPAsbw+zOzlTvjwsto\n
          WHPbqCRiOwY1nQ2pM714A5AuTHhdUDqB1O6gyHA43LL5Z/qHQF1hwFGPa4NrzQU6\n
          yuGnBXj8ytqU0CwIPX4WecigUCAkVDNx\n
          -----END CERTIFICATE-----",
          ...
        ]
      }
    }, {
      "type": "cpu-on-fire",
      "age": 29,
      "url": "https://example.com/thing.js",
      "user_agent": "Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0",
      "body": {
        "temperature": 614.0
      }
    }]
:::
::::

::: section
## [7. ]{.secno}[Automation]{.content}[](#automation){.self-link} {#automation .heading .settled level="7"}

For the purposes of user-agent automation and application testing, this
document defines a number of [extension
commands](https://w3c.github.io/webdriver/#dfn-extension-command){#ref-for-dfn-extension-command
link-type="dfn"} for the
[\[WebDriver\]](#biblio-webdriver "WebDriver"){link-type="biblio"}
specification.

### [7.1. ]{.secno}[Generate Test Report]{.content}[](#generate-test-report-command){.self-link} {#generate-test-report-command .heading .settled level="7.1"}

The [Generate Test Report]{#generate-test-report .dfn .dfn-paneled
dfn-type="dfn" export=""} [extension
command](https://w3c.github.io/webdriver/#dfn-extension-command){#ref-for-dfn-extension-command①
link-type="dfn"} simulates the generation of a
[report](#report){#ref-for-report②② link-type="dfn"} for the purposes of
testing. This report will be observed by any
[registered](#registered){#ref-for-registered③ link-type="dfn"}
[reporting observers](#reporting-observer){#ref-for-reporting-observer⑨
link-type="dfn"}.

The [extension
command](https://w3c.github.io/webdriver/#dfn-extension-command){#ref-for-dfn-extension-command②
link-type="dfn"} is defined as follows:

``` {.idl .highlight .def}
dictionary GenerateTestReportParameters {
  required DOMString message;
  DOMString group = "default";
};
```

HTTP Method

[URI
Template](https://w3c.github.io/webdriver/#dfn-extension-command-uri-template){#ref-for-dfn-extension-command-uri-template
link-type="dfn"}

`POST`

`/session/{session id}/reporting/generate_test_report`

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps){#ref-for-dfn-remote-end-steps
link-type="dfn"} are:

1.  If `parameters`{.variable} is not a JSON
    [Object](https://www.w3.org/TR/rdf12-concepts/#dfn-object){#ref-for-dfn-object
    link-type="dfn"}, return a [WebDriver
    error](https://w3c.github.io/webdriver/#dfn-error){#ref-for-dfn-error
    link-type="dfn"} with [WebDriver error
    code](https://w3c.github.io/webdriver/#dfn-error-code){#ref-for-dfn-error-code
    link-type="dfn"} [invalid
    argument](https://w3c.github.io/webdriver/#dfn-invalid-argument){#ref-for-dfn-invalid-argument
    link-type="dfn"}.

2.  Let `message`{.variable} be the result of
    [trying](https://w3c.github.io/webdriver/#dfn-try){#ref-for-dfn-try
    link-type="dfn"} to get `parameters`{.variable}'s
    [`message`{.idl}](#dom-generatetestreportparameters-message){#ref-for-dom-generatetestreportparameters-message
    link-type="idl"} property.

3.  If `message`{.variable} is not present, return a [WebDriver
    error](https://w3c.github.io/webdriver/#dfn-error){#ref-for-dfn-error①
    link-type="dfn"} with [WebDriver error
    code](https://w3c.github.io/webdriver/#dfn-error-code){#ref-for-dfn-error-code①
    link-type="dfn"} [invalid
    argument](https://w3c.github.io/webdriver/#dfn-invalid-argument){#ref-for-dfn-invalid-argument①
    link-type="dfn"}.

4.  If the [current browsing
    context](https://w3c.github.io/webdriver/#dfn-current-browsing-context){#ref-for-dfn-current-browsing-context
    link-type="dfn"} is no longer open, return a [WebDriver
    error](https://w3c.github.io/webdriver/#dfn-error){#ref-for-dfn-error②
    link-type="dfn"} with [WebDriver error
    code](https://w3c.github.io/webdriver/#dfn-error-code){#ref-for-dfn-error-code②
    link-type="dfn"} [no such
    window](https://w3c.github.io/webdriver/#dfn-no-such-window){#ref-for-dfn-no-such-window
    link-type="dfn"}.

5.  [Handle any user
    prompts](https://w3c.github.io/webdriver/#dfn-handle-any-user-prompts){#ref-for-dfn-handle-any-user-prompts
    link-type="dfn"} and return its value if it is a [WebDriver
    error](https://w3c.github.io/webdriver/#dfn-error){#ref-for-dfn-error③
    link-type="dfn"}.

6.  Let `group`{.variable} be `parameters`{.variable}'s
    [`group`{.idl}](#dom-generatetestreportparameters-group){#ref-for-dom-generatetestreportparameters-group
    link-type="idl"} property.

7.  Let `body`{.variable} be a new object that can be serialized into a
    [JSON
    text](https://tools.ietf.org/html/rfc8259#section-2){#ref-for-section-2①
    link-type="dfn"}, containing a single string field,
    `body_message`{.variable}.

8.  Set `body_message`{.variable} to `message`{.variable}.

9.  Let `settings`{.variable} be the [environment settings
    object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object){#ref-for-environment-settings-object②
    link-type="dfn"} of the [current browsing
    context](https://w3c.github.io/webdriver/#dfn-current-browsing-context){#ref-for-dfn-current-browsing-context①
    link-type="dfn"}'s [active
    document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document){#ref-for-nav-document
    link-type="dfn"}.

10. Execute [generate and queue a
    report](#generate-and-queue-a-report){#ref-for-generate-and-queue-a-report
    link-type="dfn"} with `body`{.variable}, \"test\",
    `group`{.variable}, and `settings`{.variable}.

11. Return
    [success](https://w3c.github.io/webdriver/#dfn-success){#ref-for-dfn-success
    link-type="dfn"} with data null.
:::

::: section
## [8. ]{.secno}[Security Considerations]{.content}[](#security){.self-link} {#security .heading .settled level="8"}

### [8.1. ]{.secno}[Capability URLs]{.content}[](#capability-urls){.self-link} {#capability-urls .heading .settled level="8.1"}

Some URLs are valuable in and of themselves. They may contain explicit
credentials in the username and password portion of the URL, or may
grant access to some resource to anyone with knowledge of the URL path.
Additionally, they may contain information which was never intended
leave the user's browser in the URL fragment. See
[\[CAPABILITY-URLS\]](#biblio-capability-urls "Good Practices for Capability URLs"){link-type="biblio"}
for more information.

To mitigate the possibility that such URLs will be leaked via this
reporting mechanism, the algorithms here strip out credential
information and fragment data from the URL sent as a
[report](#report){#ref-for-report②③ link-type="dfn"}'s originator. It is
still possible, however, for sensitive information in the URL's path to
be leaked this way. Sites which use such URLs may need to operate their
own reporting endpoints.

Additionally, such URLs may be present in a report's
[body](#report-body){#ref-for-report-body⑤ link-type="dfn"}.
Specifications which extend this API and which include any URLs in a
report's [body](#report-body){#ref-for-report-body⑥ link-type="dfn"}
SHOULD require that they be similarly stripped.
:::

::: section
## [9. ]{.secno}[Privacy Considerations]{.content}[](#privacy){.self-link} {#privacy .heading .settled level="9"}

### [9.1. ]{.secno}[Network Leakage]{.content}[](#network-leakage){.self-link} {#network-leakage .heading .settled level="9.1"}

Because there is a delay between a page being loaded and a report being
generated and sent, it's entirely possible for a report generated while
a user is on one network to be sent while the user is on another
network.

This behaviour is limited to the lifetime of the document which
generated the reports, though, and such a document could be generating
traffic on the new network through other means in any case, even after
the document is closed, through mechanisms such as
`navigator.sendBeacon`.

[](#issue-acba119f){.self-link} Consider mitigations. For example, we
could drop reports if we change from one network to another.
[\[WICG/background-sync Issue
#107\]](https://github.com/WICG/background-sync/issues/107)

### [9.2. ]{.secno}[Clock Skew]{.content}[](#fingerprinting-clock-skew){.self-link} {#fingerprinting-clock-skew .heading .settled level="9.2"}

Each report is delivered along with an `age` property, rather than the
timestamp at which it was generated. We do this because each user's
local clock will be skewed from the clock on the server by an arbitrary
amount. The difference between the time the report was generated and the
time it was sent will be stable, regardless of clock skew, and we can
avoid the fingerprinting risk of exposing the clock skew via this API.

### [9.3. ]{.secno}[Cross-origin correlation]{.content}[](#correlation){.self-link} {#correlation .heading .settled level="9.3"}

If multiple origins all use the same reporting endpoint, that endpoint
may learn that a particular user has interacted with a certain set of
websites, as it will receive origin-tagged reports from each. This
doesn't seem worse than the status quo ability to track the same
information from cooperative origins, and doesn't grant any new tracking
ability above and beyond what's possible with `<img>` today.

### [9.4. ]{.secno}[Disabling Reporting]{.content}[](#disable){.self-link} {#disable .heading .settled level="9.4"}

Reporting is, to some extent, a question of commons. In the aggregate,
it seems useful for everyone for reports to be delivered. There is
direct benefit to developers, as they can fix bugs, which means there's
indirect benefit to users, as the sites they enjoy will be more stable
and enjoyable. As a concrete example, Content Security Policy grants
something like herd immunity to cross-site scripting attacks by alerting
developers about potential holes in their sites\' defenses. Fixing those
bugs helps every user, even those whose user agents don't support
Content Security Policy.

The calculus, of course, depends on the nature of data that's being
delivered, and the relative maliciousness of the reporting endpoints,
but that's the value proposition in broad strokes.

That said, it can't be the case that this general benefit be allowed to
take priority over the ability of a user to individually opt-out of such
a system. Sending reports costs bandwidth, and potentially could reveal
some small amount of additional information above and beyond what a
website can obtain in-band
([\[NETWORK-ERROR-LOGGING\]](#biblio-network-error-logging "Network Error Logging"){link-type="biblio"},
for instance). User agents MUST allow users to disable reporting with
some reasonable amount of granularity in order to maintain the priority
of constituencies espoused in
[\[HTML-DESIGN-PRINCIPLES\]](#biblio-html-design-principles "HTML Design Principles"){link-type="biblio"}.
:::

::: section
## [10. ]{.secno}[IANA Considerations]{.content}[](#iana-considerations){.self-link} {#iana-considerations .heading .settled level="10"}

### [10.1. ]{.secno}[The `Reporting-Endpoints` Header]{.content}[](#header-field-registration){.self-link} {#header-field-registration .heading .settled level="10.1"}

The permanent message header field registry should be updated with the
following registration:
[\[RFC3864\]](#biblio-rfc3864 "Registration Procedures for Message Header Fields"){link-type="biblio"}

Header field name

:   `Reporting-Endpoints`

Applicable protocol

:   http

Status

:   standard

Author/Change controller

:   W3C

Specification document

:   This specification (see [§ 3.2 The Reporting-Endpoints HTTP Response
    Header Field](#header))

### [10.2. ]{.secno}[The `application/reports+json` Media Type]{.content}[](#media-type-registration){.self-link} {#media-type-registration .heading .settled level="10.2"}

Type name

:   application

Subtype name

:   reports+json

Required parameters

:   N/A

Optional parameters

:   N/A

Encoding considerations

:   Encoding considerations are identical to those specified for the
    \"application/json\" media type. See
    [\[RFC8259\]](#biblio-rfc8259 "The JavaScript Object Notation (JSON) Data Interchange Format"){link-type="biblio"}.

Security considerations

:   See [§ 8 Security Considerations](#security).

Interoperability considerations

:   This document specifies the format of conforming messages and the
    interpretation thereof.

Published specification

:   [§ 2.2 Media Type](#media-type)

Applications that use this media type\
Fragment identifier considerations\
Additional information

:   N/A

Person and email address to contact for further information

:   This document's editors.

Intended usage:

:   COMMON

Restrictions on usage:

:   N/A

Author

:   This document's editors.

Change controller

:   W3C

Provisional registration?

:   Yes.
:::
