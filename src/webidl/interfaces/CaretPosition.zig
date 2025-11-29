//! Generated from: cssom-view.idl
//! Generated at: 2025-11-29T11:15:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CaretPositionImpl = @import("impls").CaretPosition;
const mixins = @import("mixins");
const DOMRect = @import("interfaces").DOMRect;
const Node = @import("interfaces").Node;

pub const CaretPosition = struct {
    pub const Meta = struct {
        pub const name = "CaretPosition";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "offsetNode", "get_offsetNode", null },
            .{ "offset", "get_offset", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getClientRect", "call_getClientRect", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getClientRect",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "offsetNode", "get_offsetNode", null },
            .{ "offset", "get_offset", null },
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
            offsetNode: *runtime.Instance = undefined,
            offset: u32 = undefined,
            _internal: ?*CaretPositionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_offset = &get_offset,
        .get_offsetNode = &get_offsetNode,

        .call_getClientRect = &call_getClientRect,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CaretPositionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CaretPositionImpl.deinit(instance);
    }

    pub fn get_offsetNode(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CaretPositionImpl.get_offsetNode(instance);
    }

    pub fn get_offset(instance: *runtime.Instance) anyerror!u32 {
        return try CaretPositionImpl.get_offset(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getClientRect(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try CaretPositionImpl.call_getClientRect(instance);
    }

};
