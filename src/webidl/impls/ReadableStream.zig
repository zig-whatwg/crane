//! ReadableStream Implementation
//!
//! WHATWG Streams Standard: https://streams.spec.whatwg.org/#rs-class
//!
//! A readable stream represents a source of data from which you can read.
//! All of its internal state is encapsulated in InternalState.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ReadableStream = interfaces.ReadableStream;

// Import streams infrastructure
const streams_common = @import("streams_common");
const event_loop = @import("streams_event_loop");
const AsyncPromise = @import("streams_async_promise").AsyncPromise;

pub const State = ReadableStream.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    RangeError,
    InvalidState,
    OutOfMemory,
};

/// Stream state enumeration per WHATWG spec
pub const StreamState = enum {
    readable,
    closed,
    errored,
};

/// Reader union type - can be default reader, BYOB reader, or none
pub const Reader = union(enum) {
    none: void,
    default: *runtime.Instance,
    byob: *runtime.Instance,
};

/// Internal state for ReadableStream
///
/// This mirrors the internal slots defined in the WHATWG Streams spec § 4.1
pub const InternalState = struct {
    /// [[controller]]: ReadableStreamDefaultController or ReadableByteStreamController
    controller: *runtime.Instance,

    /// [[reader]]: ReadableStreamReader or undefined
    reader: Reader,

    /// [[state]]: "readable", "closed", or "errored"
    state: StreamState,

    /// [[storedError]]: any - stored error if state is "errored"
    stored_error: ?*anyopaque,

    /// [[detached]]: boolean - transferred via postMessage
    detached: bool,

    /// [[disturbed]]: boolean - ever had a reader
    disturbed: bool,

    /// Event loop for async operations (borrowed from context)
    event_loop: event_loop.EventLoop,

    /// Resource management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Clean up controller
        // Note: controller is a runtime.Instance that manages its own lifecycle

        // Clean up reader if present
        switch (self.reader) {
            .none => {},
            .default, .byob => {
                // Reader instances manage their own lifecycle
            },
        }

        // Free the internal state itself
        allocator.destroy(self);
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, underlyingSource: *const anyopaque, strategy: dictionaries.QueuingStrategy) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &ReadableStream.vtable, ctx);
    errdefer deinit(instance);

    _ = underlyingSource;
    _ = strategy;
    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for locked
pub fn get_locked(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: from
pub fn call_from(instance: *runtime.Instance, asyncIterable: *const anyopaque) ImplError!*runtime.Instance {
    _ = instance;
    _ = asyncIterable;
    return error.NotImplemented;
}

/// Operation: pipeThrough
pub fn call_pipeThrough(instance: *runtime.Instance, transform: dictionaries.ReadableWritablePair, options: dictionaries.StreamPipeOptions) ImplError!*runtime.Instance {
    _ = instance;
    _ = transform;
    _ = options;
    return error.NotImplemented;
}

/// Operation: cancel
pub fn call_cancel(instance: *runtime.Instance, reason: *const anyopaque) ImplError!*const anyopaque {
    _ = instance;
    _ = reason;
    return error.NotImplemented;
}

/// Operation: getReader
pub fn call_getReader(instance: *runtime.Instance, options: dictionaries.ReadableStreamGetReaderOptions) ImplError!typedefs.ReadableStreamReader {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: pipeTo
pub fn call_pipeTo(instance: *runtime.Instance, destination: *runtime.Instance, options: dictionaries.StreamPipeOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = destination;
    _ = options;
    return error.NotImplemented;
}

/// Operation: tee
pub fn call_tee(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: forEach
pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) ImplError!void {
    _ = instance;
    _ = callback;
    return error.NotImplemented;
}
