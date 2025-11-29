//! Generated from: html.idl
//! Generated at: 2025-11-29T05:01:32Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasCompositingImpl = @import("impls").CanvasCompositing;
const mixins = @import("mixins");
const DOMString = @import("typedefs").DOMString;

pub const CanvasCompositing = struct {
    pub const Meta = struct {
        pub const name = "CanvasCompositing";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "globalAlpha", "get_globalAlpha", "set_globalAlpha" },
            .{ "globalCompositeOperation", "get_globalCompositeOperation", "set_globalCompositeOperation" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "globalAlpha", "get_globalAlpha", "set_globalAlpha" },
            .{ "globalCompositeOperation", "get_globalCompositeOperation", "set_globalCompositeOperation" },
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
            globalAlpha: f64 = undefined,
            globalCompositeOperation: runtime.DOMString = undefined,
            _internal: ?*CanvasCompositingImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_globalAlpha = &get_globalAlpha,
        .get_globalCompositeOperation = &get_globalCompositeOperation,

        .set_globalAlpha = &set_globalAlpha,
        .set_globalCompositeOperation = &set_globalCompositeOperation,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasCompositingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasCompositingImpl.deinit(instance);
    }

    pub fn get_globalAlpha(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasCompositingImpl.get_globalAlpha(instance);
    }

    pub fn set_globalAlpha(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasCompositingImpl.set_globalAlpha(instance, value);
    }

    pub fn get_globalCompositeOperation(instance: *runtime.Instance) anyerror!DOMString {
        return try CanvasCompositingImpl.get_globalCompositeOperation(instance);
    }

    pub fn set_globalCompositeOperation(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CanvasCompositingImpl.set_globalCompositeOperation(instance, value);
    }

};
