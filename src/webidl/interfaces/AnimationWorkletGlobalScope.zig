//! Generated from: css-animation-worklet.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AnimationWorkletGlobalScopeImpl = @import("impls").AnimationWorkletGlobalScope;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const WorkletGlobalScope = @import("interfaces").WorkletGlobalScope;
const AnimatorInstanceConstructor = @import("callbacks").AnimatorInstanceConstructor;
const DOMString = @import("typedefs").DOMString;

pub const AnimationWorkletGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "AnimationWorkletGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = WorkletGlobalScope.State;
        pub const ParentInterface = WorkletGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worklet", "AnimationWorklet" } } },
            .{ .name = "Exposed", .value = .{ .identifier = "AnimationWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .AnimationWorklet = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "registerAnimator", "call_registerAnimator", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "registerAnimator",
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
            _internal: ?*AnimationWorkletGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_registerAnimator = &call_registerAnimator,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AnimationWorkletGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return AnimationWorkletGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AnimationWorkletGlobalScopeImpl.deinit(instance);
    }

    pub fn call_registerAnimator(instance: *runtime.Instance, name: DOMString, animatorCtor: AnimatorInstanceConstructor) anyerror!void {
        
        return try AnimationWorkletGlobalScopeImpl.call_registerAnimator(instance, name, animatorCtor);
    }

};
