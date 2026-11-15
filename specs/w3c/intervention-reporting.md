
## 1. Introduction

\[INTRODUCTION GOES HERE\]

### 1.1. Examples

Example, Inc. wants to understand how
often users of its web site are running into browser interventions, in
order to better devote its developer resources to improving site
performance. It can do this by delivering the following header to define
a default reporting endpoint, which will direct intervention reports
there:

 Reporting-Endpoints: defau

## 2. Concepts

### 2.1. Intervention

Interventions are discussed in https://github.com/WICG/interventions.

## 3. Intervention Reports

[Intervention reports] indicate that a user agent has decided not
to honor a request made by the application (e.g. for security,
performance or user annoyance reasons).

[Intervention
reports](#intervention-reports) are a type of
[report](https://w3c.github.io/reporting/#report).

[Intervention
reports](#intervention-reports) have the [report
type](https://w3c.github.io/reporting/#report-type) \"intervention\".

[Intervention
reports](#intervention-reports) are [visible to `ReportingObserver`s].

```
[Exposed=(Window,Worker)]
interface InterventionReportBody : ReportBody {
 [Default] object toJSON();
 readonly attribute DOMString id;
 readonly attribute DOMString message;
 readonly attribute DOMString? sourceFile;
 readonly attribute unsigned long? lineNumber;
 readonly attribute unsigned long? columnNumber;
};
```

An [intervention
report](#intervention-reports)'s
[body](https://w3c.github.io/reporting/#report-body), represented in JavaScript by
[`InterventionReportBody`](#interventionreportbody), contains the following fields:

- [id]: an
 implementation-defined string identifying the specific intervention
 that occurred. This string can be used for grouping and counting
 related reports.

- [message(#interventionreportbody-message)]: A
 human-readable string with details typically matching what would be
 displayed on the developer console. The message is not guaranteed to
 be unique for a given
 [id](#interventionreportbody-id) (e.g. it may contain additional context on what led
 to the intervention).

- [sourceFile]: If
 known, the file which first used the indicated API, or null otherwise.

- [lineNumber(#interventionreportbody-linenumber)]: If
 known, the line number in
 [sourceFile](#interventionreportbody-sourcefile) of the offending behavior (which prompted the
 intervention), or null otherwise.

- [columnNumber(#interventionreportbody-columnnumber)]: If
 known, the column number in
 [sourceFile](#interventionreportbody-sourcefile) of the offending behavior (which prompted the
 intervention), or null otherwise.

Note: Intervention reports are always delivered to the
[endpoint](https://w3c.github.io/reporting/#endpoint) named `default`; there is currently no way to override
this. If you want to receive other kinds of reports, but not
intervention reports, make sure to use a different name for the endpoint
that you choose for those reports.

## 4. Sample Reports

POST /reports HTTP/1.1
 Host: example.com
 ...
 Content-Type: application/reports+json

 [{
 "type": "intervention",
 "age": 27,
 "url": "https://example.com/",
 "user_agent": "Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0",
 "body": {
 "id": "audio-no-gesture",
 "message": "A request to play audio was blocked because it was not triggered by user activation (such as a click).",
 "sourceFile": "https://example.com/index.js",
 "lineNumber": 1234,
 "columnNumber": 42
 }
 }]
 }

## 5. Security Considerations

For a discussion of security considerations surrounding out-of-band
reporting in general, see [Reporting API §9 Security
Considerations](https://w3c.github.io/reporting/#security).

The remainder of this section discusses security considerations for
intervention reporting specifically.

## 6. Privacy Considerations

For a discussion of privacy considerations surrounding out-of-band
reporting in general, see [Reporting API §10 Privacy
Considerations](https://w3c.github.io/reporting/#privacy).

The remainder of this section discusses privacy considerations for
intervention reporting specifically.
