//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasTransformImpl = @import("../impls/CanvasTransform.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        CanvasTransformImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CanvasTransformImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_resetTransform(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasTransformImpl.call_resetTransform(state);
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
        DOMMatrix2DInit: anyopaque,
    };

    pub fn call_setTransform(instance: *runtime.Instance, args: SetTransformArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double => |a| return CanvasTransformImpl.unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double(state, a.a, a.b, a.c, a.d, a.e, a.f),
            .DOMMatrix2DInit => |arg| return CanvasTransformImpl.DOMMatrix2DInit(state, arg),
        }
    }

    /// Extended attributes: [NewObject]
    pub fn call_getTransform(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return CanvasTransformImpl.call_getTransform(state);
    }

    pub fn call_transform(instance: *runtime.Instance, a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasTransformImpl.call_transform(state, a, b, c, d, e, f);
    }

    pub fn call_rotate(instance: *runtime.Instance, angle: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasTransformImpl.call_rotate(state, angle);
    }

    pub fn call_scale(instance: *runtime.Instance, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasTransformImpl.call_scale(state, x, y);
    }

    pub fn call_translate(instance: *runtime.Instance, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasTransformImpl.call_translate(state, x, y);
    }

};
