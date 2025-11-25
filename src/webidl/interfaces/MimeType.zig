//! Generated from: html.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MimeTypeImpl = @import("impls").MimeType;
const DOMString = @import("typedefs").DOMString;
const Plugin = @import("interfaces").Plugin;

pub const MimeType = struct {
    pub const Meta = struct {
        pub const name = "MimeType";
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
            .{ "type", "get_type", null },
            .{ "description", "get_description", null },
            .{ "suffixes", "get_suffixes", null },
            .{ "enabledPlugin", "get_enabledPlugin", null },
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
            .{ "type", "get_type", null },
            .{ "description", "get_description", null },
            .{ "suffixes", "get_suffixes", null },
            .{ "enabledPlugin", "get_enabledPlugin", null },
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
            @"type": runtime.DOMString = undefined,
            description: runtime.DOMString = undefined,
            suffixes: runtime.DOMString = undefined,
            enabledPlugin: *runtime.Instance = undefined,
            _internal: ?*MimeTypeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_description = &get_description,
        .get_enabledPlugin = &get_enabledPlugin,
        .get_suffixes = &get_suffixes,
        .get_type = &get_type,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MimeTypeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MimeTypeImpl.deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try MimeTypeImpl.get_type(instance);
    }

    pub fn get_description(instance: *runtime.Instance) anyerror!DOMString {
        return try MimeTypeImpl.get_description(instance);
    }

    pub fn get_suffixes(instance: *runtime.Instance) anyerror!DOMString {
        return try MimeTypeImpl.get_suffixes(instance);
    }

    pub fn get_enabledPlugin(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MimeTypeImpl.get_enabledPlugin(instance);
    }

};
