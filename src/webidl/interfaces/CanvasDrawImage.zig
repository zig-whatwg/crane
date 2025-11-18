//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasDrawImageImpl = @import("impls").CanvasDrawImage;
const CanvasImageSource = @import("typedefs").CanvasImageSource;

pub const CanvasDrawImage = struct {
    pub const Meta = struct {
        pub const name = "CanvasDrawImage";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CanvasDrawImage, .{
        .deinit_fn = &deinit_wrapper,

        .call_drawImage = &call_drawImage,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CanvasDrawImageImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasDrawImageImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Arguments for drawImage (WebIDL overloading)
    pub const DrawImageArgs = union(enum) {
        /// drawImage(image, dx, dy)
        CanvasImageSource_unrestricted double_unrestricted double: struct {
            image: CanvasImageSource,
            dx: f64,
            dy: f64,
        },
        /// drawImage(image, dx, dy, dw, dh)
        CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double: struct {
            image: CanvasImageSource,
            dx: f64,
            dy: f64,
            dw: f64,
            dh: f64,
        },
        /// drawImage(image, sx, sy, sw, sh, dx, dy, dw, dh)
        CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double: struct {
            image: CanvasImageSource,
            sx: f64,
            sy: f64,
            sw: f64,
            sh: f64,
            dx: f64,
            dy: f64,
            dw: f64,
            dh: f64,
        },
    };

    pub fn call_drawImage(instance: *runtime.Instance, args: DrawImageArgs) anyerror!void {
        switch (args) {
            .CanvasImageSource_unrestricted double_unrestricted double => |a| return try CanvasDrawImageImpl.CanvasImageSource_unrestricted double_unrestricted double(instance, a.image, a.dx, a.dy),
            .CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double => |a| return try CanvasDrawImageImpl.CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double(instance, a.image, a.dx, a.dy, a.dw, a.dh),
            .CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double => |a| return try CanvasDrawImageImpl.CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double(instance, a.image, a.sx, a.sy, a.sw, a.sh, a.dx, a.dy, a.dw, a.dh),
        }
    }

};
