//! Generated from: web-animations-2.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SequenceEffectImpl = @import("impls").SequenceEffect;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GroupEffect = @import("GroupEffect.zig").GroupEffect;
const AnimationEffect = @import("AnimationEffect.zig").AnimationEffect;
const AnimationNodeList = @import("AnimationNodeList.zig").AnimationNodeList;
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
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

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SequenceEffectImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SequenceEffectImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, children: ?runtime.JSValue, timing: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SequenceEffectImpl.call_constructor(ctx, children, timing);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SequenceEffectImpl.call_clone(instance);
    }

};
