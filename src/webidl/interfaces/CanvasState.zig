//! Generated from: html.idl
//! Generated at: 2025-12-07T19:32:59Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const CanvasStateImpl = @import("impls").CanvasState;
const mixins = @import("mixins");

pub const CanvasState = struct {
    pub const Meta = struct {
        pub const name = "CanvasState";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "save", "call_save", 0 },
            .{ "restore", "call_restore", 0 },
            .{ "reset", "call_reset", 0 },
            .{ "isContextLost", "call_isContextLost", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "save",
            "restore",
            "reset",
            "isContextLost",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*CanvasStateImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_isContextLost = &call_isContextLost,
        .call_reset = &call_reset,
        .call_restore = &call_restore,
        .call_save = &call_save,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasStateImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasStateImpl.deinit(instance);
    }

    pub fn call_restore(instance: *runtime.Instance) anyerror!void {
        return try CanvasStateImpl.call_restore(instance);
    }

    pub fn call_isContextLost(instance: *runtime.Instance) anyerror!bool {
        return try CanvasStateImpl.call_isContextLost(instance);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        return try CanvasStateImpl.call_reset(instance);
    }

    pub fn call_save(instance: *runtime.Instance) anyerror!void {
        return try CanvasStateImpl.call_save(instance);
    }

};
