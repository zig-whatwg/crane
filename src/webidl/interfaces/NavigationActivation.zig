//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigationActivationImpl = @import("impls").NavigationActivation;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const NavigationHistoryEntry = @import("NavigationHistoryEntry.zig").NavigationHistoryEntry;
const NavigationType = @import("enums").NavigationType;

pub const NavigationActivation = struct {
    pub const Meta = struct {
        pub const name = "NavigationActivation";
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
            .{ "from", "get_from", null },
            .{ "entry", "get_entry", null },
            .{ "navigationType", "get_navigationType", null },
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
            .{ "from", "get_from", null },
            .{ "entry", "get_entry", null },
            .{ "navigationType", "get_navigationType", null },
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
            from: ?*runtime.Instance = null,
            entry: *runtime.Instance = undefined,
            navigationType: enums.NavigationType = undefined,
            _internal: ?*NavigationActivationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_entry = &get_entry,
        .get_from = &get_from,
        .get_navigationType = &get_navigationType,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigationActivationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return NavigationActivationImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigationActivationImpl.deinit(instance);
    }

    pub fn get_from(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try NavigationActivationImpl.get_from(instance);
    }

    pub fn get_entry(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NavigationActivationImpl.get_entry(instance);
    }

    pub fn get_navigationType(instance: *runtime.Instance) anyerror!NavigationType {
        return try NavigationActivationImpl.get_navigationType(instance);
    }

};
