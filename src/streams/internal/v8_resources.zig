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
const v8 = @import("v8");

// V8 FFI types from v8 module
const V8Object = v8.Object;
const V8Function = v8.Function;
const V8Value = v8.Value;

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
        const obj: *V8Object = @ptrCast(@alignCast(handle));
        v8.v8_Object_Dispose(obj);
    }

    fn functionDispose(handle: *anyopaque) void {
        const func: *V8Function = @ptrCast(@alignCast(handle));
        v8.v8_Function_Dispose(func);
    }

    fn valueDispose(handle: *anyopaque) void {
        const val: *V8Value = @ptrCast(@alignCast(handle));
        v8.v8_Value_Dispose(val);
    }
};
