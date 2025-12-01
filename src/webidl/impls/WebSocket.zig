//! Implementation for WebSocket interface
//!
//! The WebSocket interface enables bidirectional communication with a server
//! over a WebSocket connection.
//!
//! Spec: https://websockets.spec.whatwg.org/#the-websocket-interface
//!
//! ## Connection States
//!
//! - CONNECTING (0): Connection not yet established
//! - OPEN (1): Connection established, communication possible
//! - CLOSING (2): Close handshake in progress
//! - CLOSED (3): Connection closed or could not be opened
//!
//! ## Events
//!
//! - open: Fired when connection is established
//! - message: Fired when data is received
//! - error: Fired when error occurs
//! - close: Fired when connection is closed

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const WebSocket = interfaces.WebSocket;

pub const State = WebSocket.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    SyntaxError,
    InvalidAccessError,
};

/// Internal state for WebSocket implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The WebSocket URL (stored separately for ownership)
    url_string: []const u8,

    /// The negotiated protocol
    protocol_string: []const u8,

    /// The negotiated extensions
    extensions_string: []const u8,

    /// Binary type preference
    binary_type: enums.BinaryType,

    /// Event handlers
    onopen: typedefs.EventHandler,
    onerror: typedefs.EventHandler,
    onclose: typedefs.EventHandler,
    onmessage: typedefs.EventHandler,

    /// Send buffer for tracking bufferedAmount
    buffered_amount: u64,

    /// Current ready state
    ready_state: u16,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .url_string = "",
            .protocol_string = "",
            .extensions_string = "",
            .binary_type = ._blob_,
            .onopen = null,
            .onerror = null,
            .onclose = null,
            .onmessage = null,
            .buffered_amount = 0,
            .ready_state = 0, // CONNECTING
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.url_string.len > 0) {
            self.allocator.free(self.url_string);
        }
        if (self.protocol_string.len > 0) {
            self.allocator.free(self.protocol_string);
        }
        if (self.extensions_string.len > 0) {
            self.allocator.free(self.extensions_string);
        }
    }
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-websocket
///
/// The WebSocket(url, protocols) constructor steps are:
/// 1. Let baseURL be this's relevant settings object's API base URL.
/// 2. Let urlRecord be the result of applying the URL parser to url with baseURL.
/// 3. If urlRecord is failure, throw a "SyntaxError" DOMException.
/// 4. If urlRecord's scheme is not "ws" or "wss", throw a "SyntaxError" DOMException.
/// 5. If urlRecord's fragment is non-null, throw a "SyntaxError" DOMException.
/// 6. If protocols is a string, set protocols to a sequence consisting of just that string.
/// 7. If any of the values in protocols occur more than once or contain illegal values,
///    throw a "SyntaxError" DOMException.
/// 8. Set this's url to urlRecord.
/// 9. Let client be this's relevant settings object.
/// 10. Run this step in parallel: Establish a WebSocket connection given urlRecord, protocols...
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, url: runtime.USVString, protocols: webidl.Opt(*const anyopaque)) !*runtime.Instance {
    // Create instance
    const instance = try init(allocator, State, &WebSocket.vtable, ctx);
    errdefer deinit(instance);

    // Get state
    const state = instance.getState(State);

    // Create internal state
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    // Store URL (copy for ownership)
    internal.url_string = try allocator.dupe(u8, url);
    state.own.url = internal.url_string;

    // Initialize state
    state.own.readyState = 0; // CONNECTING
    internal.ready_state = 0;
    state.own.bufferedAmount = 0;
    state.own.extensions = runtime.DOMString.initEmpty();
    state.own.protocol = runtime.DOMString.initEmpty();
    state.own.binaryType = ._blob_;
    internal.binary_type = ._blob_;

    // Initialize event handlers to null
    state.own.onopen = null;
    state.own.onerror = null;
    state.own.onclose = null;
    state.own.onmessage = null;

    // TODO: Validate URL scheme (ws:// or wss://)
    // TODO: Check for fragment identifier
    // TODO: Validate protocols
    // TODO: In parallel, establish WebSocket connection

    _ = protocols; // TODO: Handle protocols parameter

    return instance;
}

/// Getter for url
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-url
///
/// The url attribute must return this's url, serialized.
pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    return state.own.url;
}

/// Getter for readyState
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-readystate
///
/// The readyState attribute represents the state of the connection.
pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
    const internal = getInternal(instance) orelse return 3; // CLOSED
    return internal.ready_state;
}

/// Getter for bufferedAmount
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-bufferedamount
///
/// The bufferedAmount attribute must return the number of bytes of application data
/// (UTF-8 text and binary data) that have been queued using send() but not yet been
/// transmitted to the network.
pub fn get_bufferedAmount(instance: *runtime.Instance) anyerror!u64 {
    const internal = getInternal(instance) orelse return 0;
    return internal.buffered_amount;
}

/// Getter for onopen
pub fn get_onopen(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    return internal.onopen;
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    return internal.onerror;
}

/// Getter for onclose
pub fn get_onclose(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    return internal.onclose;
}

/// Getter for extensions
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-extensions
///
/// The extensions attribute must initially return the empty string.
/// After the WebSocket connection is established, its value might change.
pub fn get_extensions(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    if (internal.extensions_string.len > 0) {
        return runtime.DOMString.initInterned(internal.extensions_string);
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for protocol
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-protocol
///
/// The protocol attribute must initially return the empty string.
/// After the WebSocket connection is established, its value might change.
pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    if (internal.protocol_string.len > 0) {
        return runtime.DOMString.initInterned(internal.protocol_string);
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for onmessage
pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    return internal.onmessage;
}

/// Getter for binaryType
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-binarytype
///
/// The binaryType IDL attribute, on getting, must return the IDL value
/// corresponding to the binaryType attribute of the WebSocket object.
pub fn get_binaryType(instance: *runtime.Instance) anyerror!enums.BinaryType {
    const internal = getInternal(instance) orelse return ._blob_;
    return internal.binary_type;
}

/// Setter for onopen
pub fn set_onopen(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance) orelse return;
    internal.onopen = value;
    const state = instance.getState(State);
    state.own.onopen = value;
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance) orelse return;
    internal.onerror = value;
    const state = instance.getState(State);
    state.own.onerror = value;
}

/// Setter for onclose
pub fn set_onclose(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance) orelse return;
    internal.onclose = value;
    const state = instance.getState(State);
    state.own.onclose = value;
}

/// Setter for onmessage
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance) orelse return;
    internal.onmessage = value;
    const state = instance.getState(State);
    state.own.onmessage = value;
}

/// Setter for binaryType
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-binarytype
///
/// The binaryType IDL attribute, on setting, must set the binaryType attribute
/// of the WebSocket object to the new value.
pub fn set_binaryType(instance: *runtime.Instance, value: enums.BinaryType) anyerror!void {
    const internal = getInternal(instance) orelse return;
    internal.binary_type = value;
    const state = instance.getState(State);
    state.own.binaryType = value;
}

/// Operation: close
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-close
///
/// The close(code, reason) method steps are:
/// 1. If code is present but not 1000 or 3000-4999, throw an "InvalidAccessError" DOMException.
/// 2. If reason is present and UTF-8 encoded is longer than 123 bytes, throw a "SyntaxError" DOMException.
/// 3. Run the first matching steps from the following list:
///    - If this's ready state is CLOSING or CLOSED: Do nothing.
///    - If the WebSocket connection is not yet established: Fail the WebSocket connection.
///    - If the WebSocket closing handshake has not yet been started: Start the WebSocket closing handshake.
///    - Otherwise: The WebSocket closing handshake is started.
pub fn call_close(instance: *runtime.Instance, code: webidl.Opt(u16), reason: webidl.Opt(runtime.USVString)) anyerror!void {
    const internal = getInternal(instance) orelse return;

    // Validate code if present
    if (code.was_passed) {
        const c = code.value;
        // Code must be either 1000 or in range 3000-4999
        if (c != 1000 and (c < 3000 or c > 4999)) {
            return error.InvalidAccessError;
        }
    }

    // Validate reason length if present
    if (reason.was_passed) {
        if (reason.value.len > 123) {
            return error.SyntaxError;
        }
    }

    // Check ready state
    switch (internal.ready_state) {
        2, 3 => {
            // CLOSING or CLOSED - do nothing
            return;
        },
        0 => {
            // CONNECTING - fail the connection
            internal.ready_state = 3; // CLOSED
            const state = instance.getState(State);
            state.own.readyState = 3;
            // TODO: Fire error event, then close event
        },
        1 => {
            // OPEN - start closing handshake
            internal.ready_state = 2; // CLOSING
            const state = instance.getState(State);
            state.own.readyState = 2;
            // TODO: Send close frame via backend
        },
        else => {},
    }
}

/// Operation: send
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-send
///
/// The send(data) method steps are:
/// 1. If this's ready state is CONNECTING, throw an "InvalidStateError" DOMException.
/// 2. Run the appropriate set of steps from the following list:
///    - If data is a string: Let data be the result of converting data to a sequence of Unicode scalar values.
///    - If data is a Blob: Let data be the raw data represented by data.
///    - If data is an ArrayBuffer: Let data be the data stored in data.
///    - If data is an ArrayBufferView: Let data be the data stored in the buffer described by data.
/// 3. If the WebSocket connection is established and this's ready state is OPEN,
///    then send data using the WebSocket.
/// 4. Otherwise, discard data.
/// 5. Increase this's bufferedAmount by the byte length of data.
pub fn call_send(instance: *runtime.Instance, data: *const anyopaque) anyerror!void {
    const internal = getInternal(instance) orelse return;

    // Check if connecting
    if (internal.ready_state == 0) {
        return error.InvalidState;
    }

    // TODO: Determine data type and send appropriately
    // For now, just acknowledge the call
    _ = data;

    // TODO: Update bufferedAmount based on data size
    // TODO: Send data via WebSocket backend
}

// =============================================================================
// Helper functions for connection management
// =============================================================================

/// Update the ready state (called by connection code)
pub fn setReadyState(instance: *runtime.Instance, ready_state: u16) void {
    const internal = getInternal(instance) orelse return;
    internal.ready_state = ready_state;
    const state = instance.getState(State);
    state.own.readyState = ready_state;
}

/// Set the protocol after handshake completes
pub fn setProtocol(instance: *runtime.Instance, protocol: []const u8) !void {
    const internal = getInternal(instance) orelse return;
    if (internal.protocol_string.len > 0) {
        internal.allocator.free(internal.protocol_string);
    }
    internal.protocol_string = try internal.allocator.dupe(u8, protocol);
}

/// Set extensions after handshake completes
pub fn setExtensions(instance: *runtime.Instance, extensions: []const u8) !void {
    const internal = getInternal(instance) orelse return;
    if (internal.extensions_string.len > 0) {
        internal.allocator.free(internal.extensions_string);
    }
    internal.extensions_string = try internal.allocator.dupe(u8, extensions);
}

/// Update buffered amount
pub fn updateBufferedAmount(instance: *runtime.Instance, amount: u64) void {
    const internal = getInternal(instance) orelse return;
    internal.buffered_amount = amount;
    const state = instance.getState(State);
    state.own.bufferedAmount = amount;
}
