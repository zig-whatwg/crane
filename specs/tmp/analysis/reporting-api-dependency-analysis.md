# Reporting API Dependency Analysis

Generated: 2024-11-27

This document analyzes the W3C Reporting API specification and identifies all dependent specifications required for implementation.

---

## What the Reporting API Provides

The Reporting API provides **generic infrastructure for sending reports from browser to server**:

### Core Components

| Component | Description |
|-----------|-------------|
| **Endpoint** | Named URL where reports are delivered |
| **Report** | Object with `type`, `url`, `body`, `timestamp`, `attempts` |
| **ReportBody** | Base dictionary type that specific report types extend |
| **ReportingObserver** | JavaScript API to observe reports in-page |
| **Reporting-Endpoints header** | HTTP header to configure endpoints |

### WebIDL Definitions

```idl
dictionary ReportBody { };

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

### Key Algorithms

| Algorithm | Purpose |
|-----------|---------|
| `generate a report` | Creates a report object with body, url, type, timestamp |
| `serialize a list of reports to JSON` | Formats reports for HTTP delivery |
| `strip URL for use in reports` | Removes username, password, fragment from URLs |
| `attempt to deliver reports to endpoint` | POSTs reports to endpoint URL |
| `notify reporting observers` | Delivers reports to JS observers |

### Report Delivery

- Media type: `application/reports+json`
- Method: POST
- Credentials: `same-origin` (only for same-origin endpoints)
- Mode: `cors`
- Best-effort delivery (not guaranteed)

---

## Specification References in Reporting API

| Reference | Full Name | Type |
|-----------|-----------|------|
| [FETCH] | Fetch Standard | WHATWG |
| [HTML] | HTML Standard | WHATWG |
| [URL] | URL Standard | WHATWG (implicit) |
| [INFRA] | Infra Standard | WHATWG (implicit) |
| [WEBIDL] | Web IDL | WHATWG (implicit) |
| [SECURE-CONTEXTS] | Secure Contexts | W3C |
| [STRUCTURED-FIELDS] | Structured Field Values | IETF |
| [RFC9110] | HTTP Semantics | IETF |
| [RFC8259] | JSON | IETF |

---

## Already Implemented (in your codebase)

| Spec | Implementation | What Reporting API Uses |
|------|----------------|------------------------|
| **Infra** | `src/infra/` | Lists, ordered sets, byte sequences, JSON serialization |
| **URL** | `src/url/` | URL parsing, serialization, scheme checking |
| **WebIDL** | `src/webidl/` | Dictionary types, interfaces, callbacks |

---

## Dependencies for Reporting API

### 1. Fetch Standard (WHATWG) - HARD BLOCKER

| | |
|---|---|
| **Organization** | WHATWG |
| **URL** | https://fetch.spec.whatwg.org/ |
| **Reference** | [FETCH] |

**What Reporting API Uses:**

- **Request** - Creating report delivery requests
  - `concept-request`
  - `method`, `url`, `origin`, `header list`, `client`, `window`
  - `service-workers mode`, `initiator`, `destination`, `mode`
  - `credentials`, `body`

- **Response** - Processing delivery responses
  - `concept-response`
  - `concept-response-https-state`
  - `concept-response-url`
  - `concept-response-header-list`
  - `ok-status`

- **Header Operations**
  - `concept-header`
  - `concept-header-list`
  - `get-structured-header`

- **Fetch Algorithm**
  - `concept-fetch`
  - `wait-for-a-response`

- **Scheme Concepts**
  - `http-scheme`

**Critical:** Report delivery uses the Fetch algorithm with specific request configuration.

---

### 2. HTML Standard (WHATWG) - HARD BLOCKER

| | |
|---|---|
| **Organization** | WHATWG |
| **URL** | https://html.spec.whatwg.org/ |
| **Reference** | [HTML] |

**What Reporting API Uses:**

- **Global Objects**
  - `WindowOrWorkerGlobalScope` - Reports and observers are scoped to this
  - `Window`
  - `WorkerGlobalScope`

- **Environment Settings Object**
  - `environment-settings-object`
  - `relevant-settings-object`
  - `concept-settings-object-global`
  - `creation-url`

- **Origin**
  - `origin` concept
  - Same-origin checks for credentials

- **Task Queuing**
  - `queue-a-task`
  - `relevant-global-object`

- **Navigator**
  - `navigator.userAgent` - Included in reports

**Critical:** Reports are scoped to `WindowOrWorkerGlobalScope`, delivery uses task queuing.

---

### 3. Structured Field Values (IETF) - SOFT BLOCKER

| | |
|---|---|
| **Organization** | IETF |
| **URL** | https://www.rfc-editor.org/rfc/rfc8941 |
| **Reference** | [STRUCTURED-FIELDS] |

**What Reporting API Uses:**

- Parsing `Reporting-Endpoints` header as structured dictionary

**Can stub:** Simple key-value parsing can work for basic cases.

---

### 4. Secure Contexts (W3C) - SOFT BLOCKER

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/secure-contexts/ |
| **Reference** | [SECURE-CONTEXTS] |

**What Reporting API Uses:**

- `potentially trustworthy origin` concept for endpoint validation

**Can stub:** Can default to HTTPS-only for endpoints.

---

## Dependency Graph

```
Reporting API
│
├── [HARD BLOCKERS]
│   │
│   ├── Fetch Standard
│   │   ├── Request/Response types
│   │   ├── Fetch algorithm (for report delivery)
│   │   ├── Header operations
│   │   └── HTTP scheme checking
│   │
│   └── HTML Standard
│       ├── WindowOrWorkerGlobalScope (report/observer scope)
│       ├── Environment settings object
│       ├── Origin concept
│       ├── Task queuing
│       └── navigator.userAgent
│
├── [ALREADY IMPLEMENTED]
│   │
│   ├── Infra Standard ✅
│   │   ├── Lists, ordered sets
│   │   └── JSON serialization
│   │
│   ├── URL Standard ✅
│   │   ├── URL parsing/serialization
│   │   └── Scheme checking
│   │
│   └── WebIDL ✅
│       ├── Dictionary types
│       └── Interfaces
│
└── [SOFT BLOCKERS]
    │
    ├── Structured Field Values
    │   └── Reporting-Endpoints header parsing
    │
    └── Secure Contexts
        └── Endpoint trustworthiness
```

---

## What CSP Uses from Reporting API

CSP specifically uses:

1. **`ReportBody` dictionary** - CSP's `CSPViolationReportBody` extends this
2. **`generate a report` algorithm** - Called when violations occur
3. **Report types:** `"csp-violation"`, `"csp-hash"`
4. **`visible to ReportingObservers`** - CSP violations are visible
5. **Endpoint concept** - `report-to` directive specifies endpoint name

---

## Is Reporting API a Blocker for CSP?

### NO - Reporting API is NOT a hard blocker for core CSP

**CSP works without Reporting API for:**
- ✅ All policy enforcement (blocking content)
- ✅ All `*-src` directives
- ✅ `sandbox`, `frame-ancestors`
- ✅ `SecurityPolicyViolationEvent` (DOM event, independent)
- ✅ `report-uri` directive (deprecated, simple POST)

**What breaks without Reporting API:**
- ❌ `report-to` directive (modern reporting)
- ❌ `ReportingObserver` for CSP violations
- ❌ CSP hash reports

### Recommendation for CSP Implementation

**Option 1: Skip Reporting API entirely**
- Use deprecated `report-uri` directive (simple fetch POST)
- Fire `SecurityPolicyViolationEvent` for in-page observation
- Skip `report-to` directive

**Option 2: Minimal stub**
```zig
// Minimal ReportBody - empty dictionary
pub const ReportBody = struct {};

// CSPViolationReportBody extends ReportBody
pub const CSPViolationReportBody = struct {
    documentURL: []const u8,
    referrer: ?[]const u8,
    blockedURL: ?[]const u8,
    effectiveDirective: []const u8,
    originalPolicy: []const u8,
    // ... other fields
};

// generate a report - just create the object
pub fn generateReport(data: anytype, report_type: []const u8, destination: []const u8) Report {
    return .{
        .body = data,
        .type = report_type,
        .destination = destination,
        .timestamp = currentTimestamp(),
        .attempts = 0,
    };
}
```

**Option 3: Full implementation (requires Fetch + HTML subset)**

---

## Summary: Reporting API Blockers

| Priority | Spec | Why Blocking |
|----------|------|--------------|
| **1** | **Fetch Standard** | Report delivery via fetch(), request/response types |
| **2** | **HTML Standard** | WindowOrWorkerGlobalScope, task queuing, origin |
| **3** | Structured Fields | Reporting-Endpoints header parsing (can stub) |
| **4** | Secure Contexts | Endpoint validation (can stub) |

### Key Insight

**Reporting API has the same blockers as CSP:**
- Fetch Standard (request/response, delivery)
- HTML Standard (global objects, environment settings, origin)

This means:
1. If you implement Fetch + HTML subset, Reporting API is relatively easy
2. If you skip Fetch + HTML subset, skip Reporting API too and use `report-uri`

---

## Implementation Priority for Reporting API

### If implementing full Reporting API:

1. **Prerequisites (implement first):**
   - Fetch Standard (request/response types, fetch algorithm)
   - HTML Standard subset (WindowOrWorkerGlobalScope, environment settings, task queuing)

2. **Core Reporting API:**
   - Report data structure
   - Endpoint configuration (`Reporting-Endpoints` header parsing)
   - `generate a report` algorithm
   - Report delivery via Fetch

3. **JavaScript API:**
   - `ReportingObserver` interface
   - `observe()`, `disconnect()`, `takeRecords()` methods
   - Report buffer per global scope

### If implementing minimal for CSP only:

1. Stub `ReportBody` as empty dictionary
2. Implement `CSPViolationReportBody`
3. Simple report delivery via basic HTTP POST
4. Skip `ReportingObserver` entirely
