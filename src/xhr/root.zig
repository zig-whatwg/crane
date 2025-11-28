//! XMLHttpRequest Implementation
//!
//! WHATWG XHR Standard: https://xhr.spec.whatwg.org/
//!
//! This implementation is a thin wrapper around the Fetch API infrastructure,
//! providing the XMLHttpRequest interface for backward compatibility and
//! synchronous request support.
//!
//! ## Architecture
//!
//! - algorithms/ - Spec algorithms (open, send, abort, response handling)
//! - internal/ - Internal state and helpers
//!
//! ## Key Features
//!
//! - Full synchronous and asynchronous support
//! - All response types (text, arraybuffer, blob, json, document*)
//! - Progress tracking with 50ms throttling
//! - Upload progress
//! - Timeout and abort
//! - CORS via Fetch
//!
//! ## Known Limitations
//!
//! - Document response type stubbed (requires HTML/XML parsers)
//! - FormData multipart encoding stubbed (requires HTML Standard algorithm)
//! - Window/Worker context stubbed (requires HTML Standard)

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

// Algorithms
pub const open = @import("algorithms/open.zig");

// TODO: Add in later phases
// pub const send = @import("algorithms/send.zig");
// pub const abort = @import("algorithms/abort.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
