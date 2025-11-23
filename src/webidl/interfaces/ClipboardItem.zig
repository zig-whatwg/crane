//! Generated from: clipboard-apis.idl
//! Generated at: 2025-11-23T01:18:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ClipboardItemImpl = @import("impls").ClipboardItem;
const ClipboardItemOptions = @import("dictionaries").ClipboardItemOptions;
const PresentationStyle = @import("enums").PresentationStyle;
const Blob = @import("interfaces").Blob;
const DOMString = @import("typedefs").DOMString;

pub const ClipboardItem = struct {
    pub const Meta = struct {
        pub const name = "ClipboardItem";
        pub const is_mixin = false;
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
            .{ "presentationStyle", "get_presentationStyle", null },
            .{ "types", "get_types", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getType", "call_getType", 1 },
            .{ "supports", "call_supports", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getType",
            "supports",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "presentationStyle", "get_presentationStyle", null },
            .{ "types", "get_types", null },
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
            presentationStyle: PresentationStyle = undefined,
            types: runtime.FrozenArray(runtime.DOMString) = undefined,
        },
    );

    const delegates = .{

        .get_presentationStyle = &get_presentationStyle,
        .get_types = &get_types,

        .call_getType = &call_getType,
        .call_supports = &call_supports,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ClipboardItemImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ClipboardItemImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, items: *const anyopaque, options: ClipboardItemOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ClipboardItemImpl.call_constructor(allocator, ctx, items, options);
    }

    pub fn get_presentationStyle(instance: *runtime.Instance) anyerror!PresentationStyle {
        return try ClipboardItemImpl.get_presentationStyle(instance);
    }

    pub fn get_types(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ClipboardItemImpl.get_types(instance);
    }

    pub fn call_getType(instance: *runtime.Instance, @"type": DOMString) anyerror!*const anyopaque {
        
        return try ClipboardItemImpl.call_getType(instance, @"type");
    }

    pub fn call_supports(instance: *runtime.Instance, @"type": DOMString) anyerror!bool {
        
        return try ClipboardItemImpl.call_supports(instance, @"type");
    }

};
