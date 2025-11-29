//! Generated from: html.idl
//! Generated at: 2025-11-29T02:15:46Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MimeTypeArrayImpl = @import("impls").MimeTypeArray;
const mixins = @import("mixins");
const MimeType = @import("interfaces").MimeType;
const DOMString = @import("typedefs").DOMString;

pub const MimeTypeArray = struct {
    pub const Meta = struct {
        pub const name = "MimeTypeArray";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "LegacyUnenumerableNamedProperties" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "item", "call_item", 1 },
            .{ "namedItem", "call_namedItem", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "item",
            "namedItem",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
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
            length: u32 = undefined,
            _internal: ?*MimeTypeArrayImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,

        .call_item = &call_item,
        .call_namedItem = &call_namedItem,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MimeTypeArrayImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MimeTypeArrayImpl.deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try MimeTypeArrayImpl.get_length(instance);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
        
        return try MimeTypeArrayImpl.call_item(instance, index);
    }

    pub fn call_namedItem(instance: *runtime.Instance, name: DOMString) anyerror!?*runtime.Instance {
        
        return try MimeTypeArrayImpl.call_namedItem(instance, name);
    }

};
