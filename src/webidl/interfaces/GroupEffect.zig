//! Generated from: web-animations-2.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GroupEffectImpl = @import("impls").GroupEffect;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AnimationNodeList = @import("interfaces").AnimationNodeList;
const AnimationEffect = @import("interfaces").AnimationEffect;
const EffectTiming = @import("dictionaries").EffectTiming;

pub const GroupEffect = struct {
    pub const Meta = struct {
        pub const name = "GroupEffect";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "children", "get_children", null },
            .{ "firstChild", "get_firstChild", null },
            .{ "lastChild", "get_lastChild", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "clone", "call_clone", 0 },
            .{ "prepend", "call_prepend", 1 },
            .{ "append", "call_append", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "clone",
            "prepend",
            "append",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "children", "get_children", null },
            .{ "firstChild", "get_firstChild", null },
            .{ "lastChild", "get_lastChild", null },
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
            children: *runtime.Instance = undefined,
            firstChild: ?*runtime.Instance = null,
            lastChild: ?*runtime.Instance = null,
            _internal: ?*GroupEffectImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_children = &get_children,
        .get_firstChild = &get_firstChild,
        .get_lastChild = &get_lastChild,

        .call_append = &call_append,
        .call_clone = &call_clone,
        .call_prepend = &call_prepend,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GroupEffectImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return GroupEffectImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GroupEffectImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, children: ?runtime.JSValue, timing: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try GroupEffectImpl.call_constructor(ctx, children, timing);
    }

    pub fn get_children(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try GroupEffectImpl.get_children(instance);
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try GroupEffectImpl.get_firstChild(instance);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try GroupEffectImpl.get_lastChild(instance);
    }

    pub fn call_prepend(instance: *runtime.Instance, effects: []const *runtime.Instance) anyerror!void {
        
        return try GroupEffectImpl.call_prepend(instance, effects);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try GroupEffectImpl.call_clone(instance);
    }

    pub fn call_append(instance: *runtime.Instance, effects: []const *runtime.Instance) anyerror!void {
        
        return try GroupEffectImpl.call_append(instance, effects);
    }

};
