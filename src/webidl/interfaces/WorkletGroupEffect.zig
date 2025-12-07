//! Generated from: css-animation-worklet.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WorkletGroupEffectImpl = @import("impls").WorkletGroupEffect;
const mixins = @import("mixins");
const WorkletAnimationEffect = @import("interfaces").WorkletAnimationEffect;

pub const WorkletGroupEffect = struct {
    pub const Meta = struct {
        pub const name = "WorkletGroupEffect";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "AnimationWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .AnimationWorklet = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getChildren", "call_getChildren", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getChildren",
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
            _internal: ?*WorkletGroupEffectImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_getChildren = &call_getChildren,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WorkletGroupEffectImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WorkletGroupEffectImpl.deinit(instance);
    }

    pub fn call_getChildren(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WorkletGroupEffectImpl.call_getChildren(instance);
    }

};
