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

// Import the WebSocket connection module
const websocket = @import("websocket");
const WebSocketConnection = websocket.WebSocketConnection;

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

    /// The underlying WebSocket connection
    connection: ?*WebSocketConnection,

    /// The WebSocket URL (stored separately for ownership)
    url_string: []const u8,

    /// Binary type preference
    binary_type: enums.BinaryType,

    /// Event handlers
    onopen: typedefs.EventHandler,
    onerror: typedefs.EventHandler,
    onclose: typedefs.EventHandler,
    onmessage: typedefs.EventHandler,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .connection = null,
            .url_string = "",
            .binary_type = ._blob_,
            .onopen = null,
            .onerror = null,
            .onclose = null,
            .onmessage = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.connection) |conn| {
            conn.deinit();
            self.connection = null;
        }
        if (self.url_string.len > 0) {
            self.allocator.free(self.url_string);
        }
    }

    /// Get the current ready state from the connection
    pub fn getReadyState(self: *const InternalState) u16 {
        if (self.connection) |conn| {
            return conn.getReadyState();
        }
        return 3; // CLOSED if no connection
    }

    /// Get the buffered amount from the connection
    pub fn getBufferedAmount(self: *const InternalState) u64 {
        if (self.connection) |conn| {
            return conn.buffered_amount;
        }
        return 0;
    }

    /// Get the negotiated protocol from the connection
    pub fn getProtocol(self: *const InternalState) ?[]const u8 {
        if (self.connection) |conn| {
            return conn.protocol;
        }
        return null;
    }

    /// Get the extensions from the connection
    pub fn getExtensions(self: *const InternalState) ?[]const u8 {
        if (self.connection) |conn| {
            return conn.extensions;
        }
        return null;
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
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
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
    // Validate URL scheme (ws:// or wss://)
    if (!std.mem.startsWith(u8, url, "ws://") and !std.mem.startsWith(u8, url, "wss://")) {
        return error.SyntaxError;
    }

    // Check for fragment identifier (URL with # is invalid)
    if (std.mem.indexOf(u8, url, "#") != null) {
        return error.SyntaxError;
    }

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

    // Create the WebSocket connection (starts in CONNECTING state)
    const connection = try WebSocketConnection.init(allocator, url);
    internal.connection = connection;

    // Store URL (copy for ownership)
    internal.url_string = try allocator.dupe(u8, url);
    state.own.url = internal.url_string;

    // Initialize state from connection
    state.own.readyState = connection.getReadyState();
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

    // TODO: Handle protocols parameter and start connection in parallel
    _ = protocols;

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
    return internal.getReadyState();
}

/// Getter for bufferedAmount
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-bufferedamount
///
/// The bufferedAmount attribute must return the number of bytes of application data
/// (UTF-8 text and binary data) that have been queued using send() but not yet been
/// transmitted to the network.
pub fn get_bufferedAmount(instance: *runtime.Instance) anyerror!u64 {
    const internal = getInternal(instance) orelse return 0;
    return internal.getBufferedAmount();
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
    if (internal.getExtensions()) |ext| {
        return runtime.DOMString.initInterned(ext);
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
    if (internal.getProtocol()) |proto| {
        return runtime.DOMString.initInterned(proto);
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
    const reason_str: ?[]const u8 = if (reason.was_passed) blk: {
        if (reason.value.len > 123) {
            return error.SyntaxError;
        }
        break :blk reason.value;
    } else null;

    // Get the connection
    const connection = internal.connection orelse return;

    // Delegate to the connection's close method
    const close_code: ?u16 = if (code.was_passed) code.value else null;
    try connection.close(close_code, reason_str);

    // Update the state
    const state = instance.getState(State);
    state.own.readyState = connection.getReadyState();
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
    const connection = internal.connection orelse return;

    // Check if connecting
    if (internal.getReadyState() == 0) {
        return error.InvalidState;
    }

    // TODO: Properly determine data type (string, Blob, ArrayBuffer, ArrayBufferView)
    // For now, treat data as a string pointer (this is a simplification)
    // In the real implementation, we'd need to use runtime type info

    // If not OPEN, discard the data
    if (internal.getReadyState() != 1) {
        return;
    }

    // Send as text for now (proper type detection would be needed)
    // This is a placeholder - real implementation needs V8 integration
    _ = data;
    _ = connection;

    // Update bufferedAmount
    const state = instance.getState(State);
    state.own.bufferedAmount = internal.getBufferedAmount();
}

// =============================================================================
// Helper functions for connection management
// =============================================================================

/// Synchronize the WebIDL state with the underlying connection state.
/// Call this after any operation that might change connection state.
pub fn syncState(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    const state = instance.getState(State);

    // Sync readyState
    state.own.readyState = internal.getReadyState();

    // Sync bufferedAmount
    state.own.bufferedAmount = internal.getBufferedAmount();

    // Sync protocol
    if (internal.getProtocol()) |proto| {
        state.own.protocol = runtime.DOMString.initInterned(proto);
    }

    // Sync extensions
    if (internal.getExtensions()) |ext| {
        state.own.extensions = runtime.DOMString.initInterned(ext);
    }
}

/// Get the underlying connection for direct access (for event loop integration)
pub fn getConnection(instance: *runtime.Instance) ?*WebSocketConnection {
    const internal = getInternal(instance) orelse return null;
    return internal.connection;
}
