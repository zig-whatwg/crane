//! Generated from: css-font-loading.idl
//! Generated at: 2025-11-23T19:17:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FontFaceVariationAxisImpl = @import("impls").FontFaceVariationAxis;
const DOMString = @import("typedefs").DOMString;

pub const FontFaceVariationAxis = struct {
    pub const Meta = struct {
        pub const name = "FontFaceVariationAxis";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "axisTag", "get_axisTag", null },
            .{ "minimumValue", "get_minimumValue", null },
            .{ "maximumValue", "get_maximumValue", null },
            .{ "defaultValue", "get_defaultValue", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            .{ "name", "get_name", null },
            .{ "axisTag", "get_axisTag", null },
            .{ "minimumValue", "get_minimumValue", null },
            .{ "maximumValue", "get_maximumValue", null },
            .{ "defaultValue", "get_defaultValue", null },
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
            name: runtime.DOMString = undefined,
            axisTag: runtime.DOMString = undefined,
            minimumValue: f64 = undefined,
            maximumValue: f64 = undefined,
            defaultValue: f64 = undefined,
            _internal: ?*FontFaceVariationAxisImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_axisTag = &get_axisTag,
        .get_defaultValue = &get_defaultValue,
        .get_maximumValue = &get_maximumValue,
        .get_minimumValue = &get_minimumValue,
        .get_name = &get_name,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FontFaceVariationAxisImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FontFaceVariationAxisImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try FontFaceVariationAxisImpl.get_name(instance);
    }

    pub fn get_axisTag(instance: *runtime.Instance) anyerror!DOMString {
        return try FontFaceVariationAxisImpl.get_axisTag(instance);
    }

    pub fn get_minimumValue(instance: *runtime.Instance) anyerror!f64 {
        return try FontFaceVariationAxisImpl.get_minimumValue(instance);
    }

    pub fn get_maximumValue(instance: *runtime.Instance) anyerror!f64 {
        return try FontFaceVariationAxisImpl.get_maximumValue(instance);
    }

    pub fn get_defaultValue(instance: *runtime.Instance) anyerror!f64 {
        return try FontFaceVariationAxisImpl.get_defaultValue(instance);
    }

};
