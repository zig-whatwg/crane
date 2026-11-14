
## 1. Introduction

\[INTRODUCTION GOES HERE\]

### 1.1. Examples

Example, Inc. wants to keep track of
when users are using Web APIs on its site which are going to be removed
in upcoming browser versions. It can do this by delivering the following
header to define a default reporting endpoint, which will direct
deprecation reports there:

 Reporting-Endpoints: defau

## 2. Deprecation Reports

[Deprecation reports] indicate that a browser API or feature has
been used which is expected to stop working in a future update to the
browser.

[Deprecation reports](#deprecation-reports) are a type of
[report](https://w3c.github.io/reporting/#report).

[Deprecation
reports](#deprecation-reports) have the [report
type](https://w3c.github.io/reporting/#report-type) \"deprecation\".

[Deprecation
reports](#deprecation-reports) are [visible to `ReportingObserver`s].

```
[Exposed=(Window,Worker)]
interface DeprecationReportBody : ReportBody {
 [Default] object toJSON();
 readonly attribute DOMString id;
 readonly attribute object? anticipatedRemoval;
 readonly attribute DOMString message;
 readonly attribute DOMString? sourceFile;
 readonly attribute unsigned long? lineNumber;
 readonly attribute unsigned long? columnNumber;
};
```

A [deprecation
report](#deprecation-reports)'s
[body](https://w3c.github.io/reporting/#report-body), represented in JavaScript by
[`DeprecationReportBody`](#deprecationreportbody), contains the following fields:

- [id]: an
 implementation-defined string identifying the feature or API that will
 be removed. This string can be used for grouping and counting related
 reports.

- [anticipatedRemoval(#deprecationreportbody-anticipatedremoval)]: A
 JavaScript [Date
 object](https://tc39.github.io/ecma262/#sec-date-objects) (rendered as an ISO 8601 string) indicating roughly
 when the browser version without the specified API will be generally
 available (excluding \"beta\" or other pre-release channels). This
 value should be used to sort or prioritize warnings. If unknown, this
 field should be null, and the deprecation should be considered low
 priority (removal may not actually occur).

- [message(#deprecationreportbody-message)]: A
 human-readable string with details typically matching what would be
 displayed on the developer console. The message is not guaranteed to
 be unique for a given
 [id](#deprecationreportbody-id) (eg. it may contain additional context on how the API
 was used).

- [sourceFile]: If known,
 the file which first used the indicated API, or null otherwise.

- [lineNumber(#deprecationreportbody-linenumber)]: If
 known, the line number in
 [sourceFile](#deprecationreportbody-sourcefile) where the indicated API was first used, or null
 otherwise.

- [columnNumber(#deprecationreportbody-columnnumber)]: If
 known, the column number in
 [sourceFile](#deprecationreportbody-sourcefile) where the indicated API was first used, or null
 otherwise.

Note: Deprecation reports are always delivered to the
[endpoint](https://w3c.github.io/reporting/#endpoint) named `default`; there is currently no way to override
this. If you want to receive other kinds of reports, but not deprecation
reports, make sure to use a different name for the endpoint that you
choose for those reports.

## 3. Sample Reports

POST /reports HTTP/1.1
 Host: example.com
 ...
 Content-Type: application/reports+json

 [{
 "type": "deprecation",
 "age": 32,
 "url": "https://example.com/",
 "user_agent": "Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0",
 "body": {
 "id": "websql",
 "anticipatedRemoval": "2020-01-01",
 "message": "WebSQL is deprecated and will be removed in Chrome 97 around January 2020",
 "sourceFile": "https://example.com/index.js",
 "lineNumber": 1234,
 "columnNumber": 42
 }
 }]
 }

## 4. Security Considerations

For a discussion of security considerations surrounding out-of-band
reporting in general, see [Reporting API §8 Security
Considerations](https://w3c.github.io/reporting/#security).

The remainder of this section discusses security considerations for
deprecation reporting specifically.

## 5. Privacy Considerations

For a discussion of privacy considerations surrounding out-of-band
reporting in general, see [Reporting API §9 Privacy
Considerations](https://w3c.github.io/reporting/#privacy).

The remainder of this section discusses privacy considerations for
deprecation reporting specifically.
