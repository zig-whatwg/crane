//! Generated from: streams.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ReadableStreamDefaultControllerImpl = @import("impls").ReadableStreamDefaultController;

pub const ReadableStreamDefaultController = struct {
    pub const Meta = struct {
        pub const name = "ReadableStreamDefaultController";
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
            .{ "desiredSize", "get_desiredSize", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "close", "call_close", 0 },
            .{ "enqueue", "call_enqueue", 0 },
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
            desiredSize: ?f64 = null,
            _internal: ?*ReadableStreamDefaultControllerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_desiredSize = &get_desiredSize,

        .call_close = &call_close,
        .call_enqueue = &call_enqueue,
        .call_error = &call_error,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ReadableStreamDefaultControllerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ReadableStreamDefaultControllerImpl.deinit(instance);
    }

    pub fn get_desiredSize(instance: *runtime.Instance) anyerror!f64 {
        return try ReadableStreamDefaultControllerImpl.get_desiredSize(instance);
    }

    pub fn call_error(instance: *runtime.Instance, e: *const anyopaque) anyerror!void {
        
        return try ReadableStreamDefaultControllerImpl.call_error(instance, e);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try ReadableStreamDefaultControllerImpl.call_close(instance);
    }

    pub fn call_enqueue(instance: *runtime.Instance, chunk: *const anyopaque) anyerror!void {
        
        return try ReadableStreamDefaultControllerImpl.call_enqueue(instance, chunk);
    }

};
