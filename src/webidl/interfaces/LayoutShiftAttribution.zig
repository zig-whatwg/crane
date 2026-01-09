//! Generated from: layout-instability.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const LayoutShiftAttributionImpl = @import("impls").LayoutShiftAttribution;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Node = @import("Node.zig").Node;
const DOMRectReadOnly = @import("DOMRectReadOnly.zig").DOMRectReadOnly;

pub const LayoutShiftAttribution = struct {
    pub const Meta = struct {
        pub const name = "LayoutShiftAttribution";
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
            .{ "node", "get_node", null },
            .{ "previousRect", "get_previousRect", null },
            .{ "currentRect", "get_currentRect", null },
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
            .{ "node", "get_node", null },
            .{ "previousRect", "get_previousRect", null },
            .{ "currentRect", "get_currentRect", null },
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
            node: ?*runtime.Instance = null,
            previousRect: *runtime.Instance = undefined,
            currentRect: *runtime.Instance = undefined,
            _internal: ?*LayoutShiftAttributionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_currentRect = &get_currentRect,
        .get_node = &get_node,
        .get_previousRect = &get_previousRect,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return LayoutShiftAttributionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return LayoutShiftAttributionImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LayoutShiftAttributionImpl.deinit(instance);
    }

    pub fn get_node(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try LayoutShiftAttributionImpl.get_node(instance);
    }

    pub fn get_previousRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try LayoutShiftAttributionImpl.get_previousRect(instance);
    }

    pub fn get_currentRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try LayoutShiftAttributionImpl.get_currentRect(instance);
    }

};
