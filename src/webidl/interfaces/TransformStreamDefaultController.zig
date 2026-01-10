//! Generated from: streams.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TransformStreamDefaultControllerImpl = @import("impls").TransformStreamDefaultController;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const TransformStreamDefaultController = struct {
    pub const Meta = struct {
        pub const name = "TransformStreamDefaultController";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "enqueue", "call_enqueue", 0 },
            .{ "error", "call_error", 0 },
            .{ "terminate", "call_terminate", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "enqueue",
            "error",
            "terminate",
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            desiredSize: ?f64 = null,
            _internal: ?*TransformStreamDefaultControllerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_desiredSize = &get_desiredSize,

        .call_enqueue = &call_enqueue,
        .call_error = &call_error,
        .call_terminate = &call_terminate,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TransformStreamDefaultControllerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return TransformStreamDefaultControllerImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TransformStreamDefaultControllerImpl.deinit(instance);
    }

    pub fn get_desiredSize(instance: *runtime.Instance) anyerror!?f64 {
        return try TransformStreamDefaultControllerImpl.get_desiredSize(instance);
    }

    pub fn call_enqueue(instance: *runtime.Instance, chunk: webidl.Opt(runtime.JSValue)) anyerror!void {
        
        return try TransformStreamDefaultControllerImpl.call_enqueue(instance, chunk);
    }

    pub fn call_error(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!void {
        
        return try TransformStreamDefaultControllerImpl.call_error(instance, reason);
    }

    pub fn call_terminate(instance: *runtime.Instance) anyerror!void {
        return try TransformStreamDefaultControllerImpl.call_terminate(instance);
    }

};
