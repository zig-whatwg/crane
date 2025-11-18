//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasTransformImpl = @import("impls").CanvasTransform;
const DOMMatrix2DInit = @import("dictionaries").DOMMatrix2DInit;
const DOMMatrix = @import("interfaces").DOMMatrix;

pub const CanvasTransform = struct {
    pub const Meta = struct {
        pub const name = "CanvasTransform";
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

    pub const vtable = runtime.buildVTable(CanvasTransform, .{
        .deinit_fn = &deinit_wrapper,

        .call_getTransform = &call_getTransform,
        .call_resetTransform = &call_resetTransform,
        .call_rotate = &call_rotate,
        .call_scale = &call_scale,
        .call_setTransform = &call_setTransform,
        .call_transform = &call_transform,
        .call_translate = &call_translate,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CanvasTransformImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasTransformImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_resetTransform(instance: *runtime.Instance) anyerror!void {
        return try CanvasTransformImpl.call_resetTransform(instance);
    }

    /// Arguments for setTransform (WebIDL overloading)
    pub const SetTransformArgs = union(enum) {
        /// setTransform(a, b, c, d, e, f)
        unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double: struct {
            a: f64,
            b: f64,
            c: f64,
            d: f64,
            e: f64,
            f: f64,
        },
        /// setTransform(transform)
        DOMMatrix2DInit: DOMMatrix2DInit,
    };

    pub fn call_setTransform(instance: *runtime.Instance, args: SetTransformArgs) anyerror!void {
        switch (args) {
            .unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double => |a| return try CanvasTransformImpl.unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double(instance, a.a, a.b, a.c, a.d, a.e, a.f),
            .DOMMatrix2DInit => |arg| return try CanvasTransformImpl.DOMMatrix2DInit(instance, arg),
        }
    }

    /// Extended attributes: [NewObject]
    pub fn call_getTransform(instance: *runtime.Instance) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        return try CanvasTransformImpl.call_getTransform(instance);
    }

    pub fn call_transform(instance: *runtime.Instance, a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) anyerror!void {
        
        return try CanvasTransformImpl.call_transform(instance, a, b, c, d, e, f);
    }

    pub fn call_rotate(instance: *runtime.Instance, angle: f64) anyerror!void {
        
        return try CanvasTransformImpl.call_rotate(instance, angle);
    }

    pub fn call_scale(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try CanvasTransformImpl.call_scale(instance, x, y);
    }

    pub fn call_translate(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try CanvasTransformImpl.call_translate(instance, x, y);
    }

};
