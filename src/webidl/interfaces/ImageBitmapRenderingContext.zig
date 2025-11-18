//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageBitmapRenderingContextImpl = @import("impls").ImageBitmapRenderingContext;
const (HTMLCanvasElement or OffscreenCanvas) = @import("interfaces").(HTMLCanvasElement or OffscreenCanvas);
const ImageBitmap = @import("interfaces").ImageBitmap;

pub const ImageBitmapRenderingContext = struct {
    pub const Meta = struct {
        pub const name = "ImageBitmapRenderingContext";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            canvas: (HTMLCanvasElement or OffscreenCanvas) = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ImageBitmapRenderingContext, .{
        .deinit_fn = &deinit_wrapper,

        .get_canvas = &get_canvas,

        .call_transferFromImageBitmap = &call_transferFromImageBitmap,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ImageBitmapRenderingContextImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ImageBitmapRenderingContextImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_canvas(instance: *runtime.Instance) anyerror!anyopaque {
        return try ImageBitmapRenderingContextImpl.get_canvas(instance);
    }

    pub fn call_transferFromImageBitmap(instance: *runtime.Instance, bitmap: anyopaque) anyerror!void {
        
        return try ImageBitmapRenderingContextImpl.call_transferFromImageBitmap(instance, bitmap);
    }

};
