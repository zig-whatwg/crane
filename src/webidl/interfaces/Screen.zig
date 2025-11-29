//! Generated from: cssom-view.idl
//! Generated at: 2025-11-29T02:15:46Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ScreenImpl = @import("impls").Screen;
const mixins = @import("mixins");
const ScreenOrientation = @import("interfaces").ScreenOrientation;
const EventHandler = @import("typedefs").EventHandler;

pub const Screen = struct {
    pub const Meta = struct {
        pub const name = "Screen";
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
            .{ "availWidth", "get_availWidth", null },
            .{ "availHeight", "get_availHeight", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "colorDepth", "get_colorDepth", null },
            .{ "pixelDepth", "get_pixelDepth", null },
            .{ "isExtended", "get_isExtended", null },
            .{ "onchange", "get_onchange", "set_onchange" },
            .{ "orientation", "get_orientation", null },
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
            .{ "availWidth", "get_availWidth", null },
            .{ "availHeight", "get_availHeight", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "colorDepth", "get_colorDepth", null },
            .{ "pixelDepth", "get_pixelDepth", null },
            .{ "isExtended", "get_isExtended", null },
            .{ "onchange", "get_onchange", "set_onchange" },
            .{ "orientation", "get_orientation", null },
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
            availWidth: i32 = undefined,
            availHeight: i32 = undefined,
            width: i32 = undefined,
            height: i32 = undefined,
            colorDepth: u32 = undefined,
            pixelDepth: u32 = undefined,
            isExtended: bool = undefined,
            onchange: EventHandler = undefined,
            orientation: *runtime.Instance = undefined,
            cached_orientation: ?*runtime.Instance = null,
            _internal: ?*ScreenImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_availHeight = &get_availHeight,
        .get_availWidth = &get_availWidth,
        .get_colorDepth = &get_colorDepth,
        .get_height = &get_height,
        .get_isExtended = &get_isExtended,
        .get_onchange = &get_onchange,
        .get_orientation = &get_orientation,
        .get_pixelDepth = &get_pixelDepth,
        .get_width = &get_width,

        .set_onchange = &set_onchange,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ScreenImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ScreenImpl.deinit(instance);
    }

    pub fn get_availWidth(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenImpl.get_availWidth(instance);
    }

    pub fn get_availHeight(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenImpl.get_availHeight(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenImpl.get_height(instance);
    }

    pub fn get_colorDepth(instance: *runtime.Instance) anyerror!u32 {
        return try ScreenImpl.get_colorDepth(instance);
    }

    pub fn get_pixelDepth(instance: *runtime.Instance) anyerror!u32 {
        return try ScreenImpl.get_pixelDepth(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_isExtended(instance: *runtime.Instance) anyerror!bool {
        return try ScreenImpl.get_isExtended(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ScreenImpl.get_onchange(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ScreenImpl.set_onchange(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_orientation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_orientation) |cached| {
            return cached;
        }
        const value = try ScreenImpl.get_orientation(instance);
        state.own.cached_orientation = value;
        return value;
    }

};
