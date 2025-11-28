//! Generated from: html.idl
//! Generated at: 2025-11-28T19:51:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ImageDataImpl = @import("impls").ImageData;
const mixins = @import("mixins");
const PredefinedColorSpace = @import("enums").PredefinedColorSpace;
const ImageDataArray = @import("typedefs").ImageDataArray;
const ImageDataSettings = @import("dictionaries").ImageDataSettings;
const ImageDataPixelFormat = @import("enums").ImageDataPixelFormat;

pub const ImageData = struct {
    pub const Meta = struct {
        pub const name = "ImageData";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "data", "get_data", null },
            .{ "pixelFormat", "get_pixelFormat", null },
            .{ "colorSpace", "get_colorSpace", null },
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
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "data", "get_data", null },
            .{ "pixelFormat", "get_pixelFormat", null },
            .{ "colorSpace", "get_colorSpace", null },
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
            width: u32 = undefined,
            height: u32 = undefined,
            data: ImageDataArray = undefined,
            pixelFormat: ImageDataPixelFormat = undefined,
            colorSpace: PredefinedColorSpace = undefined,
            _internal: ?*ImageDataImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_colorSpace = &get_colorSpace,
        .get_data = &get_data,
        .get_height = &get_height,
        .get_pixelFormat = &get_pixelFormat,
        .get_width = &get_width,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ImageDataImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ImageDataImpl.deinit(instance);
    }

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor(sw, sh, settings)
        unsigned_long_unsigned_long_ImageDataSettings: struct {
            sw: u32,
            sh: u32,
            settings: webidl.Opt(ImageDataSettings),
        },
        /// constructor(data, sw, sh, settings)
        ImageDataArray_unsigned_long_unsigned_long_ImageDataSettings: struct {
            data: ImageDataArray,
            sw: u32,
            sh: webidl.Opt(u32),
            settings: webidl.Opt(ImageDataSettings),
        },
    };

    /// WebIDL constructor (overloaded)
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try ImageDataImpl.call_constructor(allocator, ctx, args);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
        return try ImageDataImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
        return try ImageDataImpl.get_height(instance);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!ImageDataArray {
        return try ImageDataImpl.get_data(instance);
    }

    pub fn get_pixelFormat(instance: *runtime.Instance) anyerror!ImageDataPixelFormat {
        return try ImageDataImpl.get_pixelFormat(instance);
    }

    pub fn get_colorSpace(instance: *runtime.Instance) anyerror!PredefinedColorSpace {
        return try ImageDataImpl.get_colorSpace(instance);
    }

};
