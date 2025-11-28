# XMLHttpRequest Implementation

WHATWG XHR Standard implementation for the whatwg-zig monorepo.

## Status

🚧 **In Development** - Phase 1

## Architecture

```
JavaScript/V8
    ↓
WebIDL Interfaces (src/webidl/interfaces/)
    ↓
Implementation Stubs (src/webidl/impls/)
    ↓
XHR Algorithms (src/xhr/algorithms/)
    ↓
Fetch Internal APIs (src/fetch/internal/)
    ↓
Network Backend (src/fetch/network/)
```

## Directory Structure

- `algorithms/` - WHATWG spec algorithms
  - `open.zig` - open() method
  - `send.zig` - send() method (async + sync)
  - `abort.zig` - abort() method
  - `response.zig` - Response handling
  - `headers.zig` - Header processing
  - `timeout.zig` - Timeout handling
  - `upload.zig` - Upload progress
  
- `internal/` - Internal state and helpers
  - `state_machine.zig` - XHR state machine
  - `response_accumulator.zig` - Response body accumulation
  - `progress_tracker.zig` - Progress event throttling (50ms)
  - `context.zig` - Global context abstraction (stubbed)

## Implementation Plan

See: `AGENTS.md` and Beads epic `whatwg-s3ht`

## Testing

- Unit tests: `tests/xhr/*.zig`
- Integration tests: `tests/v8/xhr_*.js`
- Test server: `tools/test_server/`

## Dependencies

**Existing (Reuse):**
- Fetch API (`src/fetch/`)
- Streams API (`src/streams/`)
- DOM Events (`src/dom/event_dispatch.zig`)
- File API (`src/file/`)
- Encoding (`src/encoding/`)
- Event Loop (`src/runtime/event_loop/`)

**Stubbed (Future):**
- HTML Parser (document response type)
- XML Parser (document response type)
- Window/Worker (HTML Standard)
- multipart/form-data encoding (HTML Standard)
