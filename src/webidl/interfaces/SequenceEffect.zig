//! Generated from: web-animations-2.idl
//! Generated at: 2025-12-07T19:33:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const SequenceEffectImpl = @import("impls").SequenceEffect;
const mixins = @import("mixins");
const GroupEffect = @import("interfaces").GroupEffect;
const AnimationEffect = @import("interfaces").AnimationEffect;
const AnimationNodeList = @import("interfaces").AnimationNodeList;
const EffectTiming = @import("dictionaries").EffectTiming;

pub const SequenceEffect = struct {
    pub const Meta = struct {
        pub const name = "SequenceEffect";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = GroupEffect.State;
        pub const ParentInterface = GroupEffect;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "clone", "call_clone", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "clone",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "prepend",
            "append",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*SequenceEffectImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_clone = &call_clone,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SequenceEffectImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SequenceEffectImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, children: ?*const anyopaque, timing: webidl.Opt(*const anyopaque)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SequenceEffectImpl.call_constructor(allocator, ctx, children, timing);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SequenceEffectImpl.call_clone(instance);
    }

};
