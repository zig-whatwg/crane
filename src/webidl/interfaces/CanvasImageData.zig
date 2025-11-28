//! Generated from: html.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasImageDataImpl = @import("impls").CanvasImageData;
const mixins = @import("mixins");
const ImageDataSettings = @import("dictionaries").ImageDataSettings;
const ImageData = @import("interfaces").ImageData;

pub const CanvasImageData = struct {
    pub const Meta = struct {
        pub const name = "CanvasImageData";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createImageData", "call_createImageData", 2 },
            .{ "createImageData", "call_createImageData", 1 },
            .{ "getImageData", "call_getImageData", 4 },
            .{ "putImageData", "call_putImageData", 3 },
            .{ "putImageData", "call_putImageData", 7 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createImageData",
            "createImageData",
            "getImageData",
            "putImageData",
            "putImageData",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*CanvasImageDataImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_createImageData = &call_createImageData,
        .call_getImageData = &call_getImageData,
        .call_putImageData = &call_putImageData,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasImageDataImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasImageDataImpl.deinit(instance);
    }

    pub fn call_getImageData(instance: *runtime.Instance, sx: i32, sy: i32, sw: i32, sh: i32, settings: webidl.Opt(ImageDataSettings)) anyerror!*runtime.Instance {
        // [EnforceRange] on sx
        if (!runtime.isInRange(i32, sx)) return error.TypeError;
        // [EnforceRange] on sy
        if (!runtime.isInRange(i32, sy)) return error.TypeError;
        // [EnforceRange] on sw
        if (!runtime.isInRange(i32, sw)) return error.TypeError;
        // [EnforceRange] on sh
        if (!runtime.isInRange(i32, sh)) return error.TypeError;
        
        return try CanvasImageDataImpl.call_getImageData(instance, sx, sy, sw, sh, settings.value);
    }

    pub fn call_createImageData(instance: *runtime.Instance, sw: i32, sh: i32, settings: webidl.Opt(ImageDataSettings)) anyerror!*runtime.Instance {
        // [EnforceRange] on sw
        if (!runtime.isInRange(i32, sw)) return error.TypeError;
        // [EnforceRange] on sh
        if (!runtime.isInRange(i32, sh)) return error.TypeError;
        
        return try CanvasImageDataImpl.call_createImageData(instance, sw, sh, settings.value);
    }

    pub fn call_putImageData(instance: *runtime.Instance, imageData: *runtime.Instance, dx: i32, dy: i32) anyerror!void {
        // [EnforceRange] on dx
        if (!runtime.isInRange(i32, dx)) return error.TypeError;
        // [EnforceRange] on dy
        if (!runtime.isInRange(i32, dy)) return error.TypeError;
        
        return try CanvasImageDataImpl.call_putImageData(instance, imageData, dx, dy);
    }

};
