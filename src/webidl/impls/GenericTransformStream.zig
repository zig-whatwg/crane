//! Implementation for GenericTransformStream mixin
//!
//! Spec: https://streams.spec.whatwg.org/#generictransformstream
//!
//! This mixin provides shared functionality for transform stream types:
//! - TransformStream
//! - TextEncoderStream
//! - TextDecoderStream
//! - CompressionStream
//! - DecompressionStream
//!
//! The mixin exposes the readable and writable sides of a transform stream.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const GenericTransformStream = interfaces.GenericTransformStream;

pub const State = GenericTransformStream.State;

pub const ImplError = error{
    TypeError,
    InvalidState,
    OutOfMemory,
};

/// Internal state for mixin
///
/// Note: Mixins don't typically have their own instances.
/// The state is managed by the concrete transform stream implementations.
/// Each implementation stores its own readable and writable streams.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The readable side of the transform stream
    readable: ?*runtime.Instance,
    /// The writable side of the transform stream
    writable: ?*runtime.Instance,
};

/// Initialize instance
///
/// Note: This mixin is not typically instantiated directly.
/// Use TransformStream or one of the encoding/compression streams instead.
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
    runtime.Instance.deinit(instance);
}

/// Getter for readable
///
/// Spec: "The readable getter steps are to return this's readable side."
///
/// Note: This delegates to the concrete transform stream implementation.
pub fn get_readable(instance: *runtime.Instance) ImplError!*runtime.Instance {
    // Determine which transform stream type this is and delegate
    // Try TransformStream first
    if (instance.vtable == &interfaces.TransformStream.vtable) {
        const TransformStreamImpl = @import("TransformStream.zig");
        return TransformStreamImpl.get_readable(instance) catch |err| {
            return switch (err) {
                error.InvalidState => error.InvalidState,
                else => error.InvalidState,
            };
        };
    }

    // Try TextEncoderStream
    if (instance.vtable == &interfaces.TextEncoderStream.vtable) {
        const TextEncoderStreamImpl = @import("TextEncoderStream.zig");
        return TextEncoderStreamImpl.get_readable(instance) catch |err| {
            return switch (err) {
                error.InvalidState => error.InvalidState,
                else => error.InvalidState,
            };
        };
    }

    // Try TextDecoderStream
    if (instance.vtable == &interfaces.TextDecoderStream.vtable) {
        const TextDecoderStreamImpl = @import("TextDecoderStream.zig");
        return TextDecoderStreamImpl.get_readable(instance) catch |err| {
            return switch (err) {
                error.InvalidState => error.InvalidState,
                else => error.InvalidState,
            };
        };
    }

    // Try CompressionStream
    if (instance.vtable == &interfaces.CompressionStream.vtable) {
        const CompressionStreamImpl = @import("CompressionStream.zig");
        return CompressionStreamImpl.get_readable(instance) catch |err| {
            return switch (err) {
                error.InvalidState => error.InvalidState,
                else => error.InvalidState,
            };
        };
    }

    // Try DecompressionStream
    if (instance.vtable == &interfaces.DecompressionStream.vtable) {
        const DecompressionStreamImpl = @import("DecompressionStream.zig");
        return DecompressionStreamImpl.get_readable(instance) catch |err| {
            return switch (err) {
                error.InvalidState => error.InvalidState,
                else => error.InvalidState,
            };
        };
    }

    return error.TypeError;
}

/// Getter for writable
///
/// Spec: "The writable getter steps are to return this's writable side."
///
/// Note: This delegates to the concrete transform stream implementation.
pub fn get_writable(instance: *runtime.Instance) ImplError!*runtime.Instance {
    // Determine which transform stream type this is and delegate
    // Try TransformStream first
    if (instance.vtable == &interfaces.TransformStream.vtable) {
        const TransformStreamImpl = @import("TransformStream.zig");
        return TransformStreamImpl.get_writable(instance) catch |err| {
            return switch (err) {
                error.InvalidState => error.InvalidState,
                else => error.InvalidState,
            };
        };
    }

    // Try TextEncoderStream
    if (instance.vtable == &interfaces.TextEncoderStream.vtable) {
        const TextEncoderStreamImpl = @import("TextEncoderStream.zig");
        return TextEncoderStreamImpl.get_writable(instance) catch |err| {
            return switch (err) {
                error.InvalidState => error.InvalidState,
                else => error.InvalidState,
            };
        };
    }

    // Try TextDecoderStream
    if (instance.vtable == &interfaces.TextDecoderStream.vtable) {
        const TextDecoderStreamImpl = @import("TextDecoderStream.zig");
        return TextDecoderStreamImpl.get_writable(instance) catch |err| {
            return switch (err) {
                error.InvalidState => error.InvalidState,
                else => error.InvalidState,
            };
        };
    }

    // Try CompressionStream
    if (instance.vtable == &interfaces.CompressionStream.vtable) {
        const CompressionStreamImpl = @import("CompressionStream.zig");
        return CompressionStreamImpl.get_writable(instance) catch |err| {
            return switch (err) {
                error.InvalidState => error.InvalidState,
                else => error.InvalidState,
            };
        };
    }

    // Try DecompressionStream
    if (instance.vtable == &interfaces.DecompressionStream.vtable) {
        const DecompressionStreamImpl = @import("DecompressionStream.zig");
        return DecompressionStreamImpl.get_writable(instance) catch |err| {
            return switch (err) {
                error.InvalidState => error.InvalidState,
                else => error.InvalidState,
            };
        };
    }

    return error.TypeError;
}
