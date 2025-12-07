//! Generated from: anchors.idl
//! Generated at: 2025-12-07T20:02:44Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const XRAnchorImpl = @import("impls").XRAnchor;
const mixins = @import("mixins");
const DOMString = @import("typedefs").DOMString;
const XRSpace = @import("interfaces").XRSpace;

pub const XRAnchor = struct {
    pub const Meta = struct {
        pub const name = "XRAnchor";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "anchorSpace", "get_anchorSpace", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "requestPersistentHandle", "call_requestPersistentHandle", 0 },
            .{ "delete", "call_delete", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestPersistentHandle",
            "delete",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "anchorSpace", "get_anchorSpace", null },
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
            anchorSpace: *runtime.Instance = undefined,
            _internal: ?*XRAnchorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_anchorSpace = &get_anchorSpace,

        .call_delete = &call_delete,
        .call_requestPersistentHandle = &call_requestPersistentHandle,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRAnchorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRAnchorImpl.deinit(instance);
    }

    pub fn get_anchorSpace(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRAnchorImpl.get_anchorSpace(instance);
    }

    pub fn call_delete(instance: *runtime.Instance) anyerror!void {
        return try XRAnchorImpl.call_delete(instance);
    }

    pub fn call_requestPersistentHandle(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRAnchorImpl.call_requestPersistentHandle(instance);
    }

};
