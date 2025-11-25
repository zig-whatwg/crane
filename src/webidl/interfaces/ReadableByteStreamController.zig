//! Generated from: streams.idl
//! Generated at: 2025-11-25T13:07:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ReadableByteStreamControllerImpl = @import("impls").ReadableByteStreamController;
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const ReadableStreamBYOBRequest = @import("interfaces").ReadableStreamBYOBRequest;

pub const ReadableByteStreamController = struct {
    pub const Meta = struct {
        pub const name = "ReadableByteStreamController";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "byobRequest", "get_byobRequest", null },
            .{ "desiredSize", "get_desiredSize", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "close", "call_close", 0 },
            .{ "enqueue", "call_enqueue", 1 },
            .{ "error", "call_error", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "close",
            "enqueue",
            "error",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "byobRequest", "get_byobRequest", null },
            .{ "desiredSize", "get_desiredSize", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            byobRequest: ?*runtime.Instance = null,
            desiredSize: ?f64 = null,
            _internal: ?*ReadableByteStreamControllerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_byobRequest = &get_byobRequest,
        .get_desiredSize = &get_desiredSize,

        .call_close = &call_close,
        .call_enqueue = &call_enqueue,
        .call_error = &call_error,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ReadableByteStreamControllerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ReadableByteStreamControllerImpl.deinit(instance);
    }

    pub fn get_byobRequest(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ReadableByteStreamControllerImpl.get_byobRequest(instance);
    }

    pub fn get_desiredSize(instance: *runtime.Instance) anyerror!?f64 {
        return try ReadableByteStreamControllerImpl.get_desiredSize(instance);
    }

    pub fn call_error(instance: *runtime.Instance, e: *const anyopaque) anyerror!void {
        
        return try ReadableByteStreamControllerImpl.call_error(instance, e);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try ReadableByteStreamControllerImpl.call_close(instance);
    }

    pub fn call_enqueue(instance: *runtime.Instance, chunk: ArrayBufferView) anyerror!void {
        
        return try ReadableByteStreamControllerImpl.call_enqueue(instance, chunk);
    }

};
