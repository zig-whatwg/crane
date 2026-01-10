//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigationTransitionImpl = @import("impls").NavigationTransition;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const NavigationDestination = @import("NavigationDestination.zig").NavigationDestination;
const NavigationType = @import("enums").NavigationType;
const NavigationHistoryEntry = @import("NavigationHistoryEntry.zig").NavigationHistoryEntry;

pub const NavigationTransition = struct {
    pub const Meta = struct {
        pub const name = "NavigationTransition";
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
            .{ "navigationType", "get_navigationType", null },
            .{ "from", "get_from", null },
            .{ "to", "get_to", null },
            .{ "committed", "get_committed", null },
            .{ "finished", "get_finished", null },
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
            .{ "navigationType", "get_navigationType", null },
            .{ "from", "get_from", null },
            .{ "to", "get_to", null },
            .{ "committed", "get_committed", null },
            .{ "finished", "get_finished", null },
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
            navigationType: enums.NavigationType = undefined,
            from: *runtime.Instance = undefined,
            to: *runtime.Instance = undefined,
            committed: runtime.JSValue = undefined,
            finished: runtime.JSValue = undefined,
            _internal: ?*NavigationTransitionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_committed = &get_committed,
        .get_finished = &get_finished,
        .get_from = &get_from,
        .get_navigationType = &get_navigationType,
        .get_to = &get_to,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigationTransitionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return NavigationTransitionImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigationTransitionImpl.deinit(instance);
    }

    pub fn get_navigationType(instance: *runtime.Instance) anyerror!NavigationType {
        return try NavigationTransitionImpl.get_navigationType(instance);
    }

    pub fn get_from(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NavigationTransitionImpl.get_from(instance);
    }

    pub fn get_to(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NavigationTransitionImpl.get_to(instance);
    }

    pub fn get_committed(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigationTransitionImpl.get_committed(instance);
    }

    pub fn get_finished(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigationTransitionImpl.get_finished(instance);
    }

};
