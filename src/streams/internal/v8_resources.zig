//! V8 Resource Management for Streams
//!
//! Manages V8 Global<> handles that must persist across multiple
//! stream operations (e.g., iterator objects, methods, callbacks).
//!
//! Design:
//! - Attaches V8 resources to stream/controller lifecycle
//! - Automatic cleanup on stream close/error/cancel
//! - Type-safe disposal functions

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");

// V8 FFI types - will be properly imported when we integrate with V8
// For now, use opaque types as placeholders
const V8Object = opaque {};
const V8Function = opaque {};
const V8Value = opaque {};

/// V8 Resource Container
/// Stores V8 Global<> handles and ensures proper disposal
pub const V8Resources = struct {
    resources: infra.List(Resource),
    allocator: Allocator,

    const Resource = struct {
        handle: *anyopaque, // Global<T>* from V8
        dispose_fn: *const fn (*anyopaque) void,
    };

    pub fn init(allocator: Allocator) V8Resources {
        return .{
            .resources = infra.List(Resource).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *V8Resources) void {
        // Dispose all V8 handles
        for (0..self.resources.len) |i| {
            const resource = self.resources.get(i) orelse continue;
            resource.dispose_fn(resource.handle);
        }
        self.resources.deinit();
    }

    /// Add a V8 Object handle
    pub fn addObject(self: *V8Resources, obj: *V8Object) !void {
        try self.resources.append(.{
            .handle = @ptrCast(obj),
            .dispose_fn = objectDispose,
        });
    }

    /// Add a V8 Function handle
    pub fn addFunction(self: *V8Resources, func: *V8Function) !void {
        try self.resources.append(.{
            .handle = @ptrCast(func),
            .dispose_fn = functionDispose,
        });
    }

    /// Add a V8 Value handle
    pub fn addValue(self: *V8Resources, val: *V8Value) !void {
        try self.resources.append(.{
            .handle = @ptrCast(val),
            .dispose_fn = valueDispose,
        });
    }

    fn objectDispose(handle: *anyopaque) void {
        _ = handle;
        // TODO: Call v8_Object_Dispose(obj) when V8 FFI is available
    }

    fn functionDispose(handle: *anyopaque) void {
        _ = handle;
        // TODO: Call v8_Function_Dispose(func) when V8 FFI is available
    }

    fn valueDispose(handle: *anyopaque) void {
        _ = handle;
        // TODO: Call v8_Value_Dispose(val) when V8 FFI is available
    }
};
