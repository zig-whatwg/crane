# XMLHttpRequest Implementation

WHATWG XHR Standard implementation for the whatwg-zig monorepo.

**Spec**: https://xhr.spec.whatwg.org/

## Status

✅ **Complete** - All phases implemented

### Implementation Progress

| Feature | Status | Notes |
|---------|--------|-------|
| State machine | ✅ | UNSENT → OPENED → HEADERS_RECEIVED → LOADING → DONE |
| open() | ✅ | Method validation, URL parsing, forbidden methods |
| send() async | ✅ | Full Fetch integration, progress events |
| send() sync | ✅ | Event loop spinning, exception throwing |
| abort() | ✅ | Request cancellation, event firing |
| Response types | ✅ | text, arraybuffer, blob, json (document stubbed) |
| Headers | ✅ | setRequestHeader, getResponseHeader, forbidden headers |
| Timeout | ✅ | Timer integration, async events, sync exceptions |
| Upload progress | ✅ | 50ms throttled events, complete lifecycle |
| CORS integration | ✅ | withCredentials, upload preflight trigger |
| FormData | ✅ | Entry list, iteration, XHR integration |

### Known Limitations

- **Document response type**: Requires HTML/XML parsers (stubbed)
- **FormData multipart encoding**: Requires HTML Standard algorithm (stubbed)
- **Window/Worker detection**: Requires HTML Standard (stubbed)

## Architecture

```
JavaScript/V8 Layer
       ↓
WebIDL Interfaces (generated)
       ↓
XHR Algorithms (this module)
       ↓
Fetch Internal APIs (reuse existing)
       ↓
Network Backend (reuse existing)
       ↓
Event Loop (for sync XHR spinning)
```

## Directory Structure

```
src/xhr/
├── algorithms/          # WHATWG spec algorithms
│   ├── open.zig        # open() method
│   ├── send.zig        # send() method (async + sync)
│   ├── abort.zig       # abort() method
│   ├── response.zig    # Response type handling
│   ├── headers.zig     # Header processing
│   ├── timeout.zig     # Timeout handling
│   ├── upload.zig      # Upload progress tracking
│   └── fetch_integration.zig  # Fetch API integration
├── internal/           # Internal helpers
│   ├── state_machine.zig     # XHR state machine
│   ├── progress_tracker.zig  # 50ms throttled events
│   ├── event_support.zig     # Event firing helpers
│   └── context.zig           # Global context stub
├── form_data.zig       # FormData implementation
├── multipart_parser.zig # Multipart parsing
└── root.zig            # Module root
```

## Usage

### Basic GET Request

```zig
const allocator = std.testing.allocator;
const xhr = @import("xhr");

var state = xhr.XMLHttpRequestState.init(allocator);
defer state.deinit();

// Open async request
try xhr.open.open(&state, "GET", "https://api.example.com/data", true, null, null);

// Send request
try xhr.send.send(&state, null);

// Check response
if (state.ready_state == .DONE) {
    const response_val = try xhr.response.getResponse(&state);
    // response_val.text contains the response body
}
```

### POST with Body

```zig
var state = xhr.XMLHttpRequestState.init(allocator);
defer state.deinit();

try xhr.open.open(&state, "POST", "https://api.example.com/users", true, null, null);

// Set headers
try xhr.headers.setRequestHeader(&state, "Content-Type", "application/json");

// Send with body
try xhr.send.send(&state, "{\"name\": \"Alice\"}");
```

### Synchronous Request

```zig
var state = xhr.XMLHttpRequestState.init(allocator);
defer state.deinit();

// Open synchronously (async = false)
try xhr.open.open(&state, "GET", "https://api.example.com/data", false, null, null);

// Send blocks until complete
try xhr.send.send(&state, null);

// Response immediately available
const text = try xhr.response.getResponseText(&state);
```

### Response Types

```zig
// Text (default)
state.response_type = .text;
const response = try xhr.response.getResponse(&state);
const text = response.text;

// ArrayBuffer
state.response_type = .arraybuffer;
const response = try xhr.response.getResponse(&state);
defer response.deinit(allocator);
const bytes = response.arraybuffer;

// JSON
state.response_type = .json;
const response = try xhr.response.getResponse(&state);
defer response.deinit(allocator);
if (response.json) |json_str| {
    // Parse JSON string
}
```

## Event Lifecycle

### Successful Request

```
loadstart
readystatechange (OPENED)
readystatechange (HEADERS_RECEIVED)
readystatechange (LOADING)
progress (may fire multiple times, throttled to 50ms)
readystatechange (DONE)
load
loadend
```

### Upload with Body

```
upload:loadstart
upload:progress (throttled)
upload:load
upload:loadend
xhr:loadstart
xhr:progress
xhr:load
xhr:loadend
```

### Error/Abort/Timeout

```
loadstart → progress → error → loadend   (network error)
loadstart → progress → abort → loadend   (abort() called)
loadstart → progress → timeout → loadend (timeout exceeded)
```

## Testing

### Unit Tests (Zig)

```bash
# Run all tests
zig build test

# Run XHR-specific tests
zig build test -- --test-filter "xhr"
```

Test files in `tests/xhr/`:
- `state_machine_test.zig` - State transitions
- `response_types_test.zig` - All response types
- `edge_cases_test.zig` - Boundary conditions
- `send_async_test.zig` - Async flow

### Integration Tests (V8)

Test files in `tests/v8/`:
- `xhr_basic_test.js` - Basic operations
- `xhr_events_test.js` - Event ordering
- `xhr_sync_test.js` - Synchronous behavior
- `xhr_form_data_test.js` - FormData integration

## Dependencies

### Used (Existing in Monorepo)

| Dependency | Usage |
|------------|-------|
| Fetch API (`src/fetch/`) | Network requests |
| Streams (`src/streams/`) | Response body streaming |
| Encoding (`src/encoding/`) | Character encoding |
| Infra (`src/infra/`) | Primitives |
| Event Loop (`src/runtime/event_loop/`) | Sync XHR spinning |

### Stubbed (Future Work)

| Dependency | For |
|------------|-----|
| HTML Parser | Document response type |
| XML Parser | Document response type |
| Window/Worker | Context detection |
| multipart/form-data | FormData encoding |

## Spec Compliance

This implementation follows the WHATWG XHR Standard:
- https://xhr.spec.whatwg.org/

Key sections implemented:
- §4.3 The XMLHttpRequest interface
- §4.4 The XMLHttpRequestUpload interface
- §5 Interface ProgressEvent
- §6 Interface FormData

## Browser Compatibility

The implementation matches browser behavior (Chromium/Firefox/WebKit):
- Sync XHR blocks with event loop spinning
- Progress events throttled to 50ms
- Upload listeners trigger CORS preflight
- 404 responses are not network errors

## Performance Considerations

- **Progress throttling**: 50ms minimum between events
- **Memory**: Uses allocator pattern, no leaks
- **Sync XHR**: Blocks JS but allows network I/O

## Contributing

See `CONTRIBUTING.md` in the repository root.
