# Chrome DevTools Protocol (CDP) Implementation Analysis

## Executive Summary

This document provides a comprehensive analysis for adding Chrome DevTools Protocol (CDP) capabilities to this WHATWG specifications library. The analysis is based on deep research into how Chromium, WebKit, and Firefox implement debugging protocols, as well as a thorough examination of this library's architecture.

### Key Findings

1. **This library is well-positioned for CDP integration** - The existing V8 integration, WebIDL code generation, and modular architecture provide excellent foundation
2. **V8 Inspector API is the critical integration point** - V8 already provides most CDP functionality; we need to expose it
3. **Phased implementation recommended** - Start with Runtime/Debugger domains, expand to DOM/Network
4. **Consider WebDriver BiDi future** - Firefox deprecated CDP in favor of W3C standard; plan for both

---

## Table of Contents

1. [Library Architecture Analysis](#1-library-architecture-analysis)
2. [Browser Implementation Research](#2-browser-implementation-research)
3. [CDP Protocol Specification](#3-cdp-protocol-specification)
4. [V8 Inspector API Details](#4-v8-inspector-api-details)
5. [Implementation Recommendations](#5-implementation-recommendations)
6. [Proposed Architecture](#6-proposed-architecture)
7. [Implementation Phases](#7-implementation-phases)
8. [Risk Analysis](#8-risk-analysis)

---

## 1. Library Architecture Analysis

### 1.1 Current Implementation Status

| Component | Directory | Status | CDP Relevance |
|-----------|-----------|--------|---------------|
| **URL** | `src/url/` | Complete | Network domain |
| **Encoding** | `src/encoding/` | Complete | - |
| **Streams** | `src/streams/` | ~80% | Network body handling |
| **DOM** | `src/dom/` | Substantial | **DOM domain (critical)** |
| **Fetch** | `src/fetch/` | Complete | **Network domain (critical)** |
| **Console** | `src/console/` | Complete | **Runtime domain (critical)** |
| **WebIDL** | `src/webidl/` | Complete | Type system |
| **Runtime** | `src/runtime/` | Complete | **All domains (critical)** |

### 1.2 V8 Integration Architecture

The library already has sophisticated V8 integration:

```
┌─────────────────────────────────────────────────────────────┐
│                    src/runtime/engines/v8/                   │
├─────────────────────────────────────────────────────────────┤
│  engine.zig          │ V8 engine interface abstraction       │
│  ffi.zig             │ Complete V8 C API bindings            │
│  context_manager.zig │ V8 context ↔ runtime context mapping  │
│  event_loop.zig      │ Microtask queue + libuv integration   │
└─────────────────────────────────────────────────────────────┘
```

**Key V8 FFI capabilities already present:**
- Isolate, Context, Value, Object, Function management
- Promise creation/resolution
- ArrayBuffer and TypedArray support
- Microtask queue integration
- Weak callbacks for finalizers

### 1.3 Existing Hook Points for CDP

| Hook Point | Location | CDP Domain |
|------------|----------|------------|
| Console logging | `src/runtime/logger.zig` | Runtime.consoleAPICalled |
| Event dispatch | `src/dom/event_dispatch.zig:575` | Debugger (event listener breakpoints) |
| DOM mutations | `src/dom/mutation.zig` | DOM.childNodeInserted/Removed |
| Network requests | `src/fetch/network/backend.zig` | Network.requestWillBeSent |
| Context creation | `src/runtime/context.zig` | Runtime.executionContextCreated |
| GC integration | `src/runtime/gc_integration.zig` | HeapProfiler |

### 1.4 Instance System

The library uses a sophisticated type-erased instance system:

```zig
pub const Instance = struct {
    vtable: *const VTable,    // Method dispatch table (8 bytes)
    state: *anyopaque,        // Interface-specific state (8 bytes)
    ctx: Context,             // Runtime context (8 bytes)
};
```

This 24-byte handle design is highly memory-efficient and provides natural integration points for object tracking required by CDP's RemoteObject system.

---

## 2. Browser Implementation Research

### 2.1 Chromium/Chrome CDP Implementation

**Architecture:**
- CDP is defined in PDL (Protocol Definition Language) files
- `browser_protocol.pdl` - Blink/browser domains (DOM, CSS, Page, Network)
- `js_protocol.pdl` - V8 domains (Runtime, Debugger, Profiler, HeapProfiler)

**Key insight:** V8 already implements the JavaScript debugging domains. Chrome's contribution is primarily the browser-level domains (DOM, Network, Page, CSS).

**Protocol characteristics:**
- JSON-RPC style messaging
- 50+ domains covering all browser functionality
- Session-based multi-target debugging
- WebSocket transport with HTTP discovery endpoints

### 2.2 WebKit Implementation

**Architecture:**
- WebKit Inspector Protocol (similar to CDP but different)
- Inspector agents per domain
- JavaScriptCore (JSC) provides debugging APIs
- Strong separation between JSC and WebKit inspector layers

**Key insight:** WebKit's agent-based architecture is clean and well-documented. Their approach to domain separation could inform our implementation.

### 2.3 Firefox Implementation

**Critical finding:** Firefox **deprecated and removed CDP support** in favor of WebDriver BiDi.

**Native architecture:**
- Firefox Remote Debugging Protocol (RDP) - Actor-based model
- SpiderMonkey Debugger API for JavaScript debugging
- Session data pattern for multi-process synchronization

**Why Firefox moved away from CDP:**
1. CDP is Chrome's internal protocol, not a standard
2. Keeping up with Chrome's changes was unsustainable
3. Architectural mismatch (CDP assumes single-process; Firefox uses multi-process Fission)
4. WebDriver BiDi is a W3C standard that Firefox helped design

**Implication for us:** Consider implementing both CDP (for immediate tooling compatibility) and planning for WebDriver BiDi (future standard).

---

## 3. CDP Protocol Specification

### 3.1 Message Format

**Request:**
```json
{
  "id": 1,
  "method": "Domain.methodName",
  "params": { "paramName": "value" },
  "sessionId": "optional-session-id"
}
```

**Response (success):**
```json
{
  "id": 1,
  "result": { "resultName": "value" },
  "sessionId": "optional-session-id"
}
```

**Response (error):**
```json
{
  "id": 1,
  "error": {
    "code": -32601,
    "message": "Method not found"
  }
}
```

**Event (notification):**
```json
{
  "method": "Domain.eventName",
  "params": { "paramName": "value" },
  "sessionId": "optional-session-id"
}
```

### 3.2 Transport Layer

**HTTP Endpoints (required):**
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/json/version` | GET | Browser version and WebSocket URL |
| `/json/list` | GET | List debuggable targets |
| `/json/protocol` | GET | Full protocol schema |
| `/json/new?{url}` | PUT | Open new page |
| `/json/close/{targetId}` | GET | Close page |

**WebSocket:**
- Primary transport for CDP messages
- URL: `ws://localhost:9222/devtools/page/{targetId}`
- Full-duplex bidirectional communication

### 3.3 Essential CDP Domains

**Tier 1 - Must Have (V8 provides):**
| Domain | Purpose | Complexity |
|--------|---------|------------|
| **Runtime** | JS execution, console, objects | Medium |
| **Debugger** | Breakpoints, stepping, call frames | High |
| **Profiler** | CPU profiling | Medium |
| **HeapProfiler** | Memory profiling | Medium |

**Tier 2 - High Value (We implement):**
| Domain | Purpose | Complexity |
|--------|---------|------------|
| **Target** | Session management | Medium |
| **Page** | Navigation, lifecycle | Medium |
| **Network** | Request/response monitoring | High |
| **DOM** | Tree inspection, mutation | High |

**Tier 3 - Nice to Have:**
| Domain | Purpose | Complexity |
|--------|---------|------------|
| **CSS** | Stylesheet inspection | High |
| **Emulation** | Device emulation | Medium |
| **Input** | Synthetic input events | Low |
| **Console** | Logging (deprecated, use Runtime) | Low |

---

## 4. V8 Inspector API Details

### 4.1 Core Classes

V8 provides a complete Inspector API in `include/v8-inspector.h`:

```cpp
// Main inspector instance
class V8Inspector {
  static std::unique_ptr<V8Inspector> create(v8::Isolate*, V8InspectorClient*);
  
  void contextCreated(const V8ContextInfo&);
  void contextDestroyed(v8::Local<v8::Context>);
  
  std::unique_ptr<V8InspectorSession> connect(
      int contextGroupId, Channel*, StringView state,
      ClientTrustLevel, SessionPauseState);
};

// Per-target debugging session
class V8InspectorSession {
  void dispatchProtocolMessage(StringView message);
  void schedulePauseOnNextStatement(StringView reason, StringView details);
  void resume(bool terminateOnResume = false);
  
  std::unique_ptr<protocol::Runtime::API::RemoteObject> wrapObject(
      v8::Local<v8::Context>, v8::Local<v8::Value>, StringView groupName,
      bool generatePreview);
};

// Embedder callbacks
class V8InspectorClient {
  void runMessageLoopOnPause(int contextGroupId);
  void quitMessageLoopOnPause();
  void consoleAPIMessage(int contextGroupId, int contextId, ...);
};

// Message transport
class Channel {
  void sendResponse(int callId, std::unique_ptr<StringBuffer> message);
  void sendNotification(std::unique_ptr<StringBuffer> message);
  void flushProtocolNotifications();
};
```

### 4.2 What V8 Inspector Handles

V8's Inspector API handles these CDP domains **completely**:
- **Runtime** - evaluate, callFunctionOn, getProperties, releaseObject, consoleAPICalled
- **Debugger** - setBreakpoint*, pause, resume, step*, evaluateOnCallFrame, scriptParsed
- **Profiler** - start, stop, sampling
- **HeapProfiler** - takeHeapSnapshot, startSampling, collectGarbage

### 4.3 What We Must Implement

We need to implement domains that require browser/runtime knowledge:
- **Target** - Session management, target discovery
- **Page** - Navigation (we don't have pages, but contexts)
- **Network** - Request/response interception (integrate with Fetch)
- **DOM** - Node tree (integrate with our DOM implementation)

---

## 5. Implementation Recommendations

### 5.1 Architecture Decision: Direct V8 Inspector Integration

**Recommended approach:** Integrate directly with V8's Inspector API rather than implementing CDP from scratch.

**Rationale:**
1. V8 Inspector already handles the complex Debugger domain
2. Battle-tested by Chrome, Node.js, and other embedders
3. Automatic compatibility with V8 version updates
4. Reduces implementation surface by ~60%

### 5.2 New Directory Structure

```
src/
└── cdp/
    ├── root.zig              # Public API exports
    ├── server.zig            # HTTP + WebSocket server
    ├── session.zig           # CDP session management
    ├── channel.zig           # V8 Inspector Channel implementation
    ├── client.zig            # V8 Inspector Client implementation
    ├── protocol/
    │   ├── types.zig         # CDP message types
    │   ├── parser.zig        # JSON-RPC parsing
    │   └── serializer.zig    # JSON-RPC serialization
    ├── domains/
    │   ├── target.zig        # Target domain
    │   ├── page.zig          # Page domain
    │   ├── network.zig       # Network domain
    │   ├── dom.zig           # DOM domain
    │   └── log.zig           # Log domain
    └── tests/
        ├── protocol_test.zig
        └── integration_test.zig
```

### 5.3 Key Implementation Patterns

**Pattern 1: V8 Inspector Client**

```zig
pub const InspectorClient = struct {
    allocator: std.mem.Allocator,
    inspector: *v8.Inspector,
    sessions: std.AutoHashMap(SessionId, *Session),
    event_emitter: EventEmitter,
    
    // V8InspectorClient callbacks
    pub fn runMessageLoopOnPause(self: *InspectorClient, context_group_id: i32) void {
        // Enter nested event loop for pause
        self.event_loop.runNestedLoop();
    }
    
    pub fn quitMessageLoopOnPause(self: *InspectorClient) void {
        self.event_loop.exitNestedLoop();
    }
    
    pub fn consoleAPIMessage(
        self: *InspectorClient,
        context_group_id: i32,
        level: LogLevel,
        message: StringView,
        url: StringView,
        line: u32,
        column: u32,
        stack_trace: ?*V8StackTrace,
    ) void {
        // Forward to Log domain or custom handler
        self.event_emitter.emit(.console_message, .{
            .level = level,
            .message = message.toString(self.allocator),
            .url = url.toString(self.allocator),
            .line = line,
            .column = column,
        });
    }
};
```

**Pattern 2: Channel for WebSocket Transport**

```zig
pub const WebSocketChannel = struct {
    websocket: *WebSocket,
    session_id: ?[]const u8,
    
    pub fn sendResponse(self: *WebSocketChannel, call_id: i32, message: StringBuffer) void {
        const json = self.wrapWithSessionId(message.string());
        self.websocket.send(json);
    }
    
    pub fn sendNotification(self: *WebSocketChannel, message: StringBuffer) void {
        const json = self.wrapWithSessionId(message.string());
        self.websocket.send(json);
    }
    
    fn wrapWithSessionId(self: *WebSocketChannel, message: []const u8) []const u8 {
        if (self.session_id) |sid| {
            // Inject sessionId into JSON
            return injectSessionId(message, sid);
        }
        return message;
    }
};
```

**Pattern 3: Network Domain Integration**

```zig
pub const NetworkDomain = struct {
    enabled: bool = false,
    request_map: std.AutoHashMap(RequestId, RequestInfo),
    
    pub fn enable(self: *NetworkDomain) void {
        self.enabled = true;
        // Hook into Fetch backend
        FetchBackend.setInterceptor(self.onRequest, self.onResponse);
    }
    
    fn onRequest(self: *NetworkDomain, request: *InternalRequest) void {
        if (!self.enabled) return;
        
        const request_id = self.generateRequestId();
        try self.request_map.put(request_id, .{
            .request = request,
            .timestamp = std.time.milliTimestamp(),
        });
        
        self.emit(.requestWillBeSent, .{
            .requestId = request_id,
            .request = .{
                .url = request.url,
                .method = request.method,
                .headers = request.header_list.toMap(),
            },
            .timestamp = @intToFloat(f64, std.time.milliTimestamp()) / 1000.0,
        });
    }
    
    fn onResponse(self: *NetworkDomain, request_id: RequestId, response: *InternalResponse) void {
        if (!self.enabled) return;
        
        self.emit(.responseReceived, .{
            .requestId = request_id,
            .response = .{
                .url = response.url,
                .status = response.status,
                .statusText = response.status_message,
                .headers = response.header_list.toMap(),
                .mimeType = response.getMimeType(),
            },
        });
    }
};
```

**Pattern 4: DOM Domain Integration**

```zig
pub const DOMDomain = struct {
    enabled: bool = false,
    document: ?*Document,
    node_map: std.AutoHashMap(NodeId, *Node),
    next_node_id: NodeId = 1,
    
    pub fn enable(self: *DOMDomain) void {
        self.enabled = true;
    }
    
    pub fn getDocument(self: *DOMDomain, depth: ?i32, pierce: bool) !DocumentNode {
        const doc = self.document orelse return error.NoDocument;
        return self.serializeNode(doc.asNode(), depth orelse 1, pierce);
    }
    
    pub fn querySelector(self: *DOMDomain, node_id: NodeId, selector: []const u8) !?NodeId {
        const node = self.node_map.get(node_id) orelse return error.NodeNotFound;
        const element = node.asElement() orelse return error.NotAnElement;
        
        const result = try element.querySelector(self.allocator, selector);
        if (result) |found| {
            return self.getOrCreateNodeId(found.asNode());
        }
        return null;
    }
    
    fn serializeNode(self: *DOMDomain, node: *Node, depth: i32, pierce: bool) CDPNode {
        const node_id = self.getOrCreateNodeId(node);
        
        return .{
            .nodeId = node_id,
            .backendNodeId = node_id, // Same for now
            .nodeType = node.node_type,
            .nodeName = node.node_name,
            .localName = node.local_name orelse "",
            .nodeValue = node.node_value orelse "",
            .childNodeCount = if (depth > 0) node.child_count else null,
            .children = if (depth > 0) self.serializeChildren(node, depth - 1, pierce) else null,
            .attributes = if (node.asElement()) |el| el.getAttributeArray() else null,
        };
    }
    
    // Hook for DOM mutations
    pub fn onChildInserted(self: *DOMDomain, parent: *Node, child: *Node, previous: ?*Node) void {
        if (!self.enabled) return;
        
        const parent_id = self.node_map.get(@ptrToInt(parent)) orelse return;
        const child_node = self.serializeNode(child, 0, false);
        
        self.emit(.childNodeInserted, .{
            .parentNodeId = parent_id,
            .previousNodeId = if (previous) |p| self.node_map.get(@ptrToInt(p)) else 0,
            .node = child_node,
        });
    }
};
```

### 5.4 HTTP/WebSocket Server

Recommend using Zig's `std.http.Server` for HTTP and implementing WebSocket upgrade:

```zig
pub const CDPServer = struct {
    http_server: std.http.Server,
    websocket_connections: std.ArrayList(*WebSocketConnection),
    inspector: *InspectorClient,
    port: u16,
    
    pub fn start(self: *CDPServer) !void {
        const address = std.net.Address.parseIp4("127.0.0.1", self.port) catch unreachable;
        try self.http_server.listen(address);
        
        while (true) {
            const conn = try self.http_server.accept();
            try self.handleConnection(conn);
        }
    }
    
    fn handleConnection(self: *CDPServer, conn: std.http.Server.Connection) !void {
        const request = try conn.receiveHead();
        
        if (std.mem.startsWith(u8, request.target, "/json")) {
            try self.handleJsonEndpoint(conn, request);
        } else if (std.mem.startsWith(u8, request.target, "/devtools")) {
            try self.handleWebSocketUpgrade(conn, request);
        } else {
            try conn.respond(.not_found, .{}, "Not Found");
        }
    }
    
    fn handleJsonEndpoint(self: *CDPServer, conn: anytype, request: anytype) !void {
        if (std.mem.eql(u8, request.target, "/json/version")) {
            const version = try std.json.stringifyAlloc(self.allocator, .{
                .Browser = "WHATWG-Zig/1.0.0",
                .@"Protocol-Version" = "1.3",
                .@"V8-Version" = v8.getVersion(),
                .webSocketDebuggerUrl = try std.fmt.allocPrint(
                    self.allocator, 
                    "ws://127.0.0.1:{d}/devtools/browser/{s}",
                    .{ self.port, self.browser_id }
                ),
            }, .{});
            try conn.respond(.ok, .{ .content_type = "application/json" }, version);
        } else if (std.mem.eql(u8, request.target, "/json/list") or 
                   std.mem.eql(u8, request.target, "/json")) {
            const targets = try self.getTargetList();
            try conn.respond(.ok, .{ .content_type = "application/json" }, targets);
        }
    }
};
```

---

## 6. Proposed Architecture

### 6.1 High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            CDP Layer                                      │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                     CDPServer (src/cdp/server.zig)                  │  │
│  │   ┌──────────────┐  ┌──────────────┐  ┌───────────────────────┐   │  │
│  │   │ HTTP Server  │  │ WebSocket    │  │ Session Manager       │   │  │
│  │   │ /json/*      │  │ /devtools/*  │  │ (multi-target)        │   │  │
│  │   └──────────────┘  └──────────────┘  └───────────────────────┘   │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                    │                                      │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                     Domain Handlers                                 │  │
│  │   ┌─────────┐ ┌──────────┐ ┌─────────┐ ┌──────┐ ┌──────┐         │  │
│  │   │ Target  │ │ Network  │ │   DOM   │ │ Page │ │ Log  │         │  │
│  │   └─────────┘ └──────────┘ └─────────┘ └──────┘ └──────┘         │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                    │                                      │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                V8 Inspector Integration                             │  │
│  │   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐   │  │
│  │   │ InspectorClient │  │ InspectorSession│  │ WebSocketChannel│   │  │
│  │   │ (callbacks)     │  │ (per-target)    │  │ (transport)     │   │  │
│  │   └─────────────────┘  └─────────────────┘  └─────────────────┘   │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                         V8 Inspector API                                  │
│   ┌────────────────────────────────────────────────────────────────┐     │
│   │  Runtime │ Debugger │ Profiler │ HeapProfiler                  │     │
│   │  (V8 provides these domains completely)                        │     │
│   └────────────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                      Existing WHATWG Components                           │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐               │
│   │ Runtime  │  │   DOM    │  │  Fetch   │  │ Console  │               │
│   │ Context  │  │  Events  │  │ Network  │  │ Logger   │               │
│   └──────────┘  └──────────┘  └──────────┘  └──────────┘               │
└──────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Data Flow

```
DevTools Client                    CDP Server                    V8/Runtime
      │                                │                              │
      │──── WS Connect ───────────────>│                              │
      │                                │── create InspectorSession ──>│
      │<─── WS Accept ────────────────│                              │
      │                                │                              │
      │──── Runtime.enable ──────────>│                              │
      │                                │── dispatchProtocolMessage ──>│
      │                                │<── executionContextCreated ──│
      │<─── executionContextCreated ──│                              │
      │                                │                              │
      │──── Network.enable ──────────>│                              │
      │                                │── NetworkDomain.enable() ───>│
      │<─── {id: N, result: {}} ─────│                              │
      │                                │                              │
      │──── Page.navigate ───────────>│                              │
      │                                │── handleNavigate() ─────────>│
      │<─── {id: N, result: {...}} ──│                              │
      │                                │                              │
      │                                │<── Network.requestWillBeSent │
      │<─── requestWillBeSent ───────│                              │
      │                                │                              │
```

---

## 7. Implementation Phases

### Phase 1: Foundation (2-3 weeks)

**Goal:** Basic CDP server with V8 Inspector integration

**Deliverables:**
1. HTTP server with `/json/*` endpoints
2. WebSocket server with connection handling
3. V8 Inspector Client/Channel/Session wrappers
4. Target domain (basic session management)

**Success criteria:**
- Chrome DevTools can connect and show Console
- `Runtime.evaluate` works
- `console.log` messages appear in DevTools

### Phase 2: Debugging (2-3 weeks)

**Goal:** Full debugging support

**Deliverables:**
1. Complete Debugger domain integration
2. Source maps support
3. Breakpoint persistence
4. Async stack traces

**Success criteria:**
- Set breakpoints by URL
- Step through code
- Inspect variables in call frames
- Async stack traces visible

### Phase 3: Network (2 weeks)

**Goal:** Network request monitoring

**Deliverables:**
1. Network domain with Fetch integration
2. Request/response interception hooks
3. Timing information
4. Response body retrieval

**Success criteria:**
- All Fetch requests visible in Network panel
- Headers, timing, body inspectable
- Request blocking works

### Phase 4: DOM (3-4 weeks)

**Goal:** DOM inspection and manipulation

**Deliverables:**
1. DOM domain with tree serialization
2. Node ID management
3. Mutation observation integration
4. querySelector support
5. Attribute modification

**Success criteria:**
- Elements panel shows DOM tree
- Can expand/collapse nodes
- Live DOM updates reflected
- Can modify attributes

### Phase 5: Advanced Features (ongoing)

**Potential additions:**
- CSS domain (stylesheet inspection)
- Profiler domain enhancement
- HeapProfiler domain enhancement
- Performance domain
- Emulation domain

---

## 8. Risk Analysis

### 8.1 Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| V8 Inspector API changes | Low | High | Pin V8 version, abstract API |
| WebSocket implementation complexity | Medium | Medium | Use battle-tested library or std.http |
| DOM serialization performance | Medium | Medium | Lazy loading, depth limits |
| Multi-session threading | High | High | Clear threading model, message queues |
| Memory leaks from object tracking | Medium | High | Weak references, session cleanup |

### 8.2 Strategic Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| CDP deprecation (like Firefox) | Medium | High | Plan for WebDriver BiDi |
| Chrome CDP breaking changes | Medium | Medium | Version negotiation, graceful degradation |
| Limited tooling adoption | Low | Medium | Focus on Puppeteer/Playwright compatibility |

### 8.3 Resource Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Underestimated complexity | Medium | High | Phased approach, MVP first |
| DOM domain scope creep | High | Medium | Strict feature boundaries |
| Testing burden | Medium | Medium | Property-based testing, browser comparison |

---

## 9. Recommendations Summary

### Immediate Actions

1. **Create `src/cdp/` directory structure**
2. **Implement V8 Inspector FFI bindings** - Extend `src/runtime/engines/v8/ffi.zig`
3. **Build basic WebSocket server** - Can use std.http for HTTP part
4. **Implement Target domain** - Foundation for session management

### Architecture Principles

1. **V8 Inspector is the source of truth** for Runtime/Debugger/Profiler domains
2. **Domain handlers are stateful** - Each domain maintains enable/disable state
3. **Events are emitted through a central EventEmitter** - Allows subscription
4. **Node IDs are session-scoped** - Different sessions can have different mappings
5. **Graceful degradation** - Unknown methods return error, don't crash

### Future Considerations

1. **WebDriver BiDi compatibility** - Design domain handlers to support both protocols
2. **Protocol versioning** - Implement capability negotiation
3. **Security** - Only bind to localhost by default, add authentication option
4. **Documentation** - Document which CDP features are supported

---

## Appendix A: CDP Domains Reference

### Essential Domains

```
Runtime
├── enable/disable
├── evaluate
├── callFunctionOn
├── getProperties
├── releaseObject
├── awaitPromise
└── Events: executionContextCreated, consoleAPICalled, exceptionThrown

Debugger
├── enable/disable
├── setBreakpointByUrl
├── setBreakpoint
├── removeBreakpoint
├── pause/resume
├── stepInto/stepOver/stepOut
├── evaluateOnCallFrame
├── getScriptSource
└── Events: scriptParsed, paused, resumed

Target
├── getTargets
├── attachToTarget
├── detachFromTarget
├── setAutoAttach
└── Events: targetCreated, targetDestroyed, attachedToTarget

Network
├── enable/disable
├── setCacheDisabled
├── setExtraHTTPHeaders
├── getResponseBody
├── getCookies
└── Events: requestWillBeSent, responseReceived, loadingFinished

DOM
├── enable/disable
├── getDocument
├── querySelector/querySelectorAll
├── requestChildNodes
├── setAttributeValue
├── getOuterHTML
└── Events: documentUpdated, childNodeInserted, childNodeRemoved

Page
├── enable/disable
├── navigate
├── reload
├── getFrameTree
├── captureScreenshot
└── Events: loadEventFired, frameNavigated, lifecycleEvent
```

### Message Examples

**Runtime.evaluate:**
```json
// Request
{"id":1,"method":"Runtime.evaluate","params":{"expression":"1+1","returnByValue":true}}

// Response
{"id":1,"result":{"result":{"type":"number","value":2}}}
```

**Debugger.setBreakpointByUrl:**
```json
// Request
{"id":2,"method":"Debugger.setBreakpointByUrl","params":{"lineNumber":10,"url":"file:///app.js"}}

// Response
{"id":2,"result":{"breakpointId":"1:10:0:file:///app.js","locations":[{"scriptId":"42","lineNumber":10,"columnNumber":0}]}}
```

**Network.requestWillBeSent (event):**
```json
{
  "method": "Network.requestWillBeSent",
  "params": {
    "requestId": "1000",
    "request": {
      "url": "https://api.example.com/data",
      "method": "GET",
      "headers": {"Accept": "application/json"}
    },
    "timestamp": 1234567.89,
    "type": "XHR"
  }
}
```

---

## Appendix B: V8 Inspector FFI Additions

Required additions to `src/runtime/engines/v8/ffi.zig`:

```zig
// V8 Inspector types (opaque pointers)
pub const V8Inspector = opaque {};
pub const V8InspectorSession = opaque {};
pub const V8InspectorClient = opaque {};
pub const V8InspectorChannel = opaque {};
pub const StringView = extern struct {
    characters8: ?[*]const u8,
    characters16: ?[*]const u16,
    length: usize,
    is_8bit: bool,
};
pub const StringBuffer = opaque {};

// V8 Inspector functions
pub extern fn v8_inspector_create(isolate: *Isolate, client: *V8InspectorClient) *V8Inspector;
pub extern fn v8_inspector_destroy(inspector: *V8Inspector) void;
pub extern fn v8_inspector_context_created(inspector: *V8Inspector, context: *Context, group_id: i32, name: StringView) void;
pub extern fn v8_inspector_context_destroyed(inspector: *V8Inspector, context: *Context) void;
pub extern fn v8_inspector_connect(inspector: *V8Inspector, group_id: i32, channel: *V8InspectorChannel, state: StringView) *V8InspectorSession;
pub extern fn v8_inspector_session_dispatch(session: *V8InspectorSession, message: StringView) void;
pub extern fn v8_inspector_session_schedule_pause(session: *V8InspectorSession, reason: StringView, details: StringView) void;
pub extern fn v8_inspector_session_resume(session: *V8InspectorSession, terminate: bool) void;
pub extern fn v8_inspector_session_destroy(session: *V8InspectorSession) void;
```

---

*Document generated: November 2024*
*Based on research into Chromium, WebKit, and Firefox debugging architectures*
