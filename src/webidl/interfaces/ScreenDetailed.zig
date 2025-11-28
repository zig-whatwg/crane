//! Generated from: window-management.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ScreenDetailedImpl = @import("impls").ScreenDetailed;
const mixins = @import("mixins");
const Screen = @import("interfaces").Screen;
const EventHandler = @import("typedefs").EventHandler;
const ScreenOrientation = @import("interfaces").ScreenOrientation;
const DOMString = @import("typedefs").DOMString;

pub const ScreenDetailed = struct {
    pub const Meta = struct {
        pub const name = "ScreenDetailed";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Screen;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "availLeft", "get_availLeft", null },
            .{ "availTop", "get_availTop", null },
            .{ "left", "get_left", null },
            .{ "top", "get_top", null },
            .{ "isPrimary", "get_isPrimary", null },
            .{ "isInternal", "get_isInternal", null },
            .{ "devicePixelRatio", "get_devicePixelRatio", null },
            .{ "label", "get_label", null },
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
            .{ "availLeft", "get_availLeft", null },
            .{ "availTop", "get_availTop", null },
            .{ "left", "get_left", null },
            .{ "top", "get_top", null },
            .{ "isPrimary", "get_isPrimary", null },
            .{ "isInternal", "get_isInternal", null },
            .{ "devicePixelRatio", "get_devicePixelRatio", null },
            .{ "label", "get_label", null },
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
            availLeft: i32 = undefined,
            availTop: i32 = undefined,
            left: i32 = undefined,
            top: i32 = undefined,
            isPrimary: bool = undefined,
            isInternal: bool = undefined,
            devicePixelRatio: f32 = undefined,
            label: runtime.DOMString = undefined,
            _internal: ?*ScreenDetailedImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_availLeft = &get_availLeft,
        .get_availTop = &get_availTop,
        .get_devicePixelRatio = &get_devicePixelRatio,
        .get_isInternal = &get_isInternal,
        .get_isPrimary = &get_isPrimary,
        .get_label = &get_label,
        .get_left = &get_left,
        .get_top = &get_top,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ScreenDetailedImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ScreenDetailedImpl.deinit(instance);
    }

    pub fn get_availLeft(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_availLeft(instance);
    }

    pub fn get_availTop(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_availTop(instance);
    }

    pub fn get_left(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_left(instance);
    }

    pub fn get_top(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_top(instance);
    }

    pub fn get_isPrimary(instance: *runtime.Instance) anyerror!bool {
        return try ScreenDetailedImpl.get_isPrimary(instance);
    }

    pub fn get_isInternal(instance: *runtime.Instance) anyerror!bool {
        return try ScreenDetailedImpl.get_isInternal(instance);
    }

    pub fn get_devicePixelRatio(instance: *runtime.Instance) anyerror!f32 {
        return try ScreenDetailedImpl.get_devicePixelRatio(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!DOMString {
        return try ScreenDetailedImpl.get_label(instance);
    }

};
