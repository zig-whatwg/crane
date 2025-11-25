//! Generated from: html.idl
//! Generated at: 2025-11-25T19:42:23Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageBitmapRenderingContextImpl = @import("impls").ImageBitmapRenderingContext;
const HTMLCanvasElement = @import("interfaces").HTMLCanvasElement;
const OffscreenCanvas = @import("interfaces").OffscreenCanvas;
const ImageBitmap = @import("interfaces").ImageBitmap;

pub const ImageBitmapRenderingContext = struct {
    pub const Meta = struct {
        pub const name = "ImageBitmapRenderingContext";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "canvas", "get_canvas", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "transferFromImageBitmap", "call_transferFromImageBitmap", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "transferFromImageBitmap",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "canvas", "get_canvas", null },
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
            canvas: union(enum) {
                HTMLCanvasElement: HTMLCanvasElement,
                OffscreenCanvas: OffscreenCanvas,
            } = undefined,
            _internal: ?*ImageBitmapRenderingContextImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_canvas = &get_canvas,

        .call_transferFromImageBitmap = &call_transferFromImageBitmap,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ImageBitmapRenderingContextImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ImageBitmapRenderingContextImpl.deinit(instance);
    }

    pub fn get_canvas(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ImageBitmapRenderingContextImpl.get_canvas(instance);
    }

    pub fn call_transferFromImageBitmap(instance: *runtime.Instance, bitmap: *runtime.Instance) anyerror!void {
        
        return try ImageBitmapRenderingContextImpl.call_transferFromImageBitmap(instance, bitmap);
    }

};
