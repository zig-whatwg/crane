//! XMLHttpRequest Implementation
//!
//! WHATWG XHR Standard: https://xhr.spec.whatwg.org/
//!
//! This module implements the XMLHttpRequest (XHR) API following the WHATWG
//! XHR Standard. XHR provides a way to make HTTP requests from JavaScript
//! without refreshing the page, enabling AJAX functionality.
//!
//! ## Overview
//!
//! XMLHttpRequest is a thin wrapper around the Fetch API infrastructure,
//! providing the classic XHR interface for backward compatibility and
//! synchronous request support (not available with Fetch).
//!
//! ## Architecture
//!
//! ```
//! JavaScript/V8 Layer
//!        ↓
//! WebIDL Interfaces (generated)
//!        ↓
//! XHR Implementation (this module)
//!        ↓
//! Fetch Internal APIs (reuse)
//!        ↓
//! Network Backend (reuse)
//! ```
//!
//! ### Directory Structure
//!
//! - `algorithms/` - Spec algorithms (open, send, abort, headers, etc.)
//! - `internal/` - Internal state, progress tracking, context abstraction
//!
//! ## Key Features
//!
//! ### Request Methods
//!
//! - `open()` - Initialize a request
//! - `send()` - Send the request (async or sync)
//! - `abort()` - Cancel an active request
//! - `setRequestHeader()` - Set request headers
//!
//! ### Response Properties
//!
//! - `status` / `statusText` - HTTP status
//! - `responseType` - Control response format (text, arraybuffer, blob, json)
//! - `response` / `responseText` - Access response body
//! - `getResponseHeader()` / `getAllResponseHeaders()` - Response headers
//!
//! ### Event Lifecycle
//!
//! ```
//! loadstart → progress → load → loadend (success)
//! loadstart → progress → error → loadend (error)
//! loadstart → progress → abort → loadend (abort)
//! loadstart → progress → timeout → loadend (timeout)
//! ```
//!
//! ### Synchronous vs Asynchronous
//!
//! - **Async (default)**: Returns immediately, fires events as response arrives
//! - **Sync**: Blocks until response complete, throws on errors
//!
//! Note: Sync XHR is deprecated in modern browsers but still required for
//! backward compatibility.
//!
//! ## Usage Example
//!
//! ```zig
//! const allocator = std.testing.allocator;
//!
//! // Create state
//! var state = XMLHttpRequestState.init(allocator);
//! defer state.deinit();
//!
//! // Open request
//! try open.open(&state, "GET", "https://api.example.com/data", true, null, null);
//!
//! // Send request (async)
//! try send.send(&state, null);
//!
//! // After completion, access response
//! if (state.ready_state == .DONE) {
//!     const response_val = try response.getResponse(&state);
//!     // Use response_val.text, response_val.arraybuffer, etc.
//! }
//! ```
//!
//! ## Response Types
//!
//! | Type | Description | Available When |
//! |------|-------------|----------------|
//! | "" (empty) | Text or document based on MIME | DONE |
//! | "text" | Decoded text string | LOADING, DONE |
//! | "arraybuffer" | ArrayBuffer with raw bytes | DONE |
//! | "blob" | Blob object | DONE |
//! | "json" | Parsed JSON (null on error) | DONE |
//! | "document" | DOM Document (stubbed) | DONE |
//!
//! ## Progress Events
//!
//! Progress events are throttled to 50ms to avoid overwhelming the event loop.
//! Each event includes:
//! - `lengthComputable` - true if total size is known
//! - `loaded` - bytes received so far
//! - `total` - total bytes (if known)
//!
//! ## CORS Integration
//!
//! XHR uses CORS mode by default. Key points:
//! - `withCredentials` controls whether credentials are sent
//! - Upload listeners trigger CORS preflight (even for simple requests)
//!
//! ## Known Limitations
//!
//! - **Document response type**: Stubbed (requires HTML/XML parsers)
//! - **FormData multipart encoding**: Stubbed (requires HTML Standard algorithm)
//! - **Window/Worker context detection**: Stubbed (requires HTML Standard)
//!
//! ## Spec References
//!
//! - XHR Standard: https://xhr.spec.whatwg.org/
//! - Fetch Standard: https://fetch.spec.whatwg.org/
//! - HTML Standard (events): https://html.spec.whatwg.org/

const std = @import("std");

// Re-export public APIs (will be added in later phases)
// pub const XMLHttpRequest = @import("webidl/interfaces/XMLHttpRequest.zig").XMLHttpRequest;
// pub const FormData = @import("webidl/interfaces/FormData.zig").FormData;
// pub const ProgressEvent = @import("webidl/interfaces/ProgressEvent.zig").ProgressEvent;

// Internal
pub const context = @import("internal/context.zig");
pub const GlobalContext = context.GlobalContext;
pub const state_machine = @import("internal/state_machine.zig");
pub const XMLHttpRequestState = state_machine.XMLHttpRequestState;
pub const ReadyState = state_machine.ReadyState;
pub const progress_tracker = @import("internal/progress_tracker.zig");
pub const ProgressTracker = progress_tracker.ProgressTracker;

// Algorithms
pub const open = @import("algorithms/open.zig");
pub const send = @import("algorithms/send.zig");
pub const response = @import("algorithms/response.zig");
pub const upload = @import("algorithms/upload.zig");
pub const headers = @import("algorithms/headers.zig");
pub const abort = @import("algorithms/abort.zig");
pub const timeout = @import("algorithms/timeout.zig");

// FormData implementation
pub const form_data = @import("form_data.zig");

// Multipart parser (for FormData)
pub const multipart_parser = @import("multipart_parser.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
