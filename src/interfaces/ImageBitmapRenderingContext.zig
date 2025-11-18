//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageBitmapRenderingContextImpl = @import("../impls/ImageBitmapRenderingContext.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        ImageBitmapRenderingContextImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ImageBitmapRenderingContextImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_canvas(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ImageBitmapRenderingContextImpl.get_canvas(state);
    }

    pub fn call_transferFromImageBitmap(instance: *runtime.Instance, bitmap: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ImageBitmapRenderingContextImpl.call_transferFromImageBitmap(state, bitmap);
    }

};
