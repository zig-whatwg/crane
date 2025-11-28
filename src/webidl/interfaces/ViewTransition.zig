//! Generated from: css-view-transitions.idl
//! Generated at: 2025-11-28T18:02:25Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ViewTransitionImpl = @import("impls").ViewTransition;
const ViewTransitionTypeSet = @import("interfaces").ViewTransitionTypeSet;
const Element = @import("interfaces").Element;

pub const ViewTransition = struct {
    pub const Meta = struct {
        pub const name = "ViewTransition";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "updateCallbackDone", "get_updateCallbackDone", null },
            .{ "ready", "get_ready", null },
            .{ "finished", "get_finished", null },
            .{ "types", "get_types", "set_types" },
            .{ "transitionRoot", "get_transitionRoot", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "skipTransition", "call_skipTransition", 0 },
            .{ "waitUntil", "call_waitUntil", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "skipTransition",
            "waitUntil",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "updateCallbackDone", "get_updateCallbackDone", null },
            .{ "ready", "get_ready", null },
            .{ "finished", "get_finished", null },
            .{ "types", "get_types", "set_types" },
            .{ "transitionRoot", "get_transitionRoot", null },
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
            updateCallbackDone: runtime.Promise(void) = undefined,
            ready: runtime.Promise(void) = undefined,
            finished: runtime.Promise(void) = undefined,
            types: *runtime.Instance = undefined,
            transitionRoot: *runtime.Instance = undefined,
            _internal: ?*ViewTransitionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_finished = &get_finished,
        .get_ready = &get_ready,
        .get_transitionRoot = &get_transitionRoot,
        .get_types = &get_types,
        .get_updateCallbackDone = &get_updateCallbackDone,

        .set_types = &set_types,

        .call_skipTransition = &call_skipTransition,
        .call_waitUntil = &call_waitUntil,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ViewTransitionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ViewTransitionImpl.deinit(instance);
    }

    pub fn get_updateCallbackDone(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ViewTransitionImpl.get_updateCallbackDone(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ViewTransitionImpl.get_ready(instance);
    }

    pub fn get_finished(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ViewTransitionImpl.get_finished(instance);
    }

    pub fn get_types(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ViewTransitionImpl.get_types(instance);
    }

    pub fn set_types(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try ViewTransitionImpl.set_types(instance, value);
    }

    pub fn get_transitionRoot(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ViewTransitionImpl.get_transitionRoot(instance);
    }

    pub fn call_waitUntil(instance: *runtime.Instance, promise: *const anyopaque) anyerror!void {
        
        return try ViewTransitionImpl.call_waitUntil(instance, promise);
    }

    pub fn call_skipTransition(instance: *runtime.Instance) anyerror!void {
        return try ViewTransitionImpl.call_skipTransition(instance);
    }

};
