//! Generated from: edit-context.idl
//! Generated at: 2025-11-29T11:15:55Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TextFormatImpl = @import("impls").TextFormat;
const mixins = @import("mixins");
const TextFormatInit = @import("dictionaries").TextFormatInit;
const UnderlineThickness = @import("enums").UnderlineThickness;
const UnderlineStyle = @import("enums").UnderlineStyle;

pub const TextFormat = struct {
    pub const Meta = struct {
        pub const name = "TextFormat";
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
            .{ "rangeStart", "get_rangeStart", null },
            .{ "rangeEnd", "get_rangeEnd", null },
            .{ "underlineStyle", "get_underlineStyle", null },
            .{ "underlineThickness", "get_underlineThickness", null },
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
            .{ "rangeStart", "get_rangeStart", null },
            .{ "rangeEnd", "get_rangeEnd", null },
            .{ "underlineStyle", "get_underlineStyle", null },
            .{ "underlineThickness", "get_underlineThickness", null },
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
            rangeStart: u32 = undefined,
            rangeEnd: u32 = undefined,
            underlineStyle: UnderlineStyle = undefined,
            underlineThickness: UnderlineThickness = undefined,
            _internal: ?*TextFormatImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_rangeEnd = &get_rangeEnd,
        .get_rangeStart = &get_rangeStart,
        .get_underlineStyle = &get_underlineStyle,
        .get_underlineThickness = &get_underlineThickness,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TextFormatImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextFormatImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, options: webidl.Opt(TextFormatInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TextFormatImpl.call_constructor(allocator, ctx, options);
    }

    pub fn get_rangeStart(instance: *runtime.Instance) anyerror!u32 {
        return try TextFormatImpl.get_rangeStart(instance);
    }

    pub fn get_rangeEnd(instance: *runtime.Instance) anyerror!u32 {
        return try TextFormatImpl.get_rangeEnd(instance);
    }

    pub fn get_underlineStyle(instance: *runtime.Instance) anyerror!UnderlineStyle {
        return try TextFormatImpl.get_underlineStyle(instance);
    }

    pub fn get_underlineThickness(instance: *runtime.Instance) anyerror!UnderlineThickness {
        return try TextFormatImpl.get_underlineThickness(instance);
    }

};
