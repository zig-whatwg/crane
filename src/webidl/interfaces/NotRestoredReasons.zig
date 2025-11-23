//! Generated from: html.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NotRestoredReasonsImpl = @import("impls").NotRestoredReasons;
const NotRestoredReasonDetails = @import("interfaces").NotRestoredReasonDetails;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const NotRestoredReasons = struct {
    pub const Meta = struct {
        pub const name = "NotRestoredReasons";
        pub const is_mixin = false;
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
            .{ "src", "get_src", null },
            .{ "id", "get_id", null },
            .{ "name", "get_name", null },
            .{ "url", "get_url", null },
            .{ "reasons", "get_reasons", null },
            .{ "children", "get_children", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "src", "get_src", null },
            .{ "id", "get_id", null },
            .{ "name", "get_name", null },
            .{ "url", "get_url", null },
            .{ "reasons", "get_reasons", null },
            .{ "children", "get_children", null },
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
            src: ?runtime.USVString = null,
            id: ?runtime.DOMString = null,
            name: ?runtime.DOMString = null,
            url: ?runtime.USVString = null,
            reasons: ?runtime.FrozenArray(NotRestoredReasonDetails) = null,
            children: ?runtime.FrozenArray(NotRestoredReasons) = null,
            _internal: ?*NotRestoredReasonsImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_children = &get_children,
        .get_id = &get_id,
        .get_name = &get_name,
        .get_reasons = &get_reasons,
        .get_src = &get_src,
        .get_url = &get_url,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NotRestoredReasonsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NotRestoredReasonsImpl.deinit(instance);
    }

    pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try NotRestoredReasonsImpl.get_src(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try NotRestoredReasonsImpl.get_id(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try NotRestoredReasonsImpl.get_name(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try NotRestoredReasonsImpl.get_url(instance);
    }

    pub fn get_reasons(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NotRestoredReasonsImpl.get_reasons(instance);
    }

    pub fn get_children(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NotRestoredReasonsImpl.get_children(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NotRestoredReasonsImpl.call_toJSON(instance);
    }

};
