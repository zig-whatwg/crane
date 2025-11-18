//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasDrawPathImpl = @import("../impls/CanvasDrawPath.zig");

pub const CanvasDrawPath = struct {
    pub const Meta = struct {
        pub const name = "CanvasDrawPath";
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

    pub const vtable = runtime.buildVTable(CanvasDrawPath, .{
        .deinit_fn = &deinit_wrapper,

        .call_beginPath = &call_beginPath,
        .call_clip = &call_clip,
        .call_clip = &call_clip,
        .call_fill = &call_fill,
        .call_fill = &call_fill,
        .call_isPointInPath = &call_isPointInPath,
        .call_isPointInPath = &call_isPointInPath,
        .call_isPointInStroke = &call_isPointInStroke,
        .call_isPointInStroke = &call_isPointInStroke,
        .call_stroke = &call_stroke,
        .call_stroke = &call_stroke,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CanvasDrawPathImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CanvasDrawPathImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Arguments for isPointInPath (WebIDL overloading)
    pub const IsPointInPathArgs = union(enum) {
        /// isPointInPath(x, y, fillRule)
        unrestricted double_unrestricted double_CanvasFillRule: struct {
            x: f64,
            y: f64,
            fillRule: anyopaque,
        },
        /// isPointInPath(path, x, y, fillRule)
        Path2D_unrestricted double_unrestricted double_CanvasFillRule: struct {
            path: anyopaque,
            x: f64,
            y: f64,
            fillRule: anyopaque,
        },
    };

    pub fn call_isPointInPath(instance: *runtime.Instance, args: IsPointInPathArgs) bool {
        const state = instance.getState(State);
        switch (args) {
            .unrestricted double_unrestricted double_CanvasFillRule => |a| return CanvasDrawPathImpl.unrestricted double_unrestricted double_CanvasFillRule(state, a.x, a.y, a.fillRule),
            .Path2D_unrestricted double_unrestricted double_CanvasFillRule => |a| return CanvasDrawPathImpl.Path2D_unrestricted double_unrestricted double_CanvasFillRule(state, a.path, a.x, a.y, a.fillRule),
        }
    }

    pub fn call_beginPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasDrawPathImpl.call_beginPath(state);
    }

    /// Arguments for clip (WebIDL overloading)
    pub const ClipArgs = union(enum) {
        /// clip(fillRule)
        CanvasFillRule: anyopaque,
        /// clip(path, fillRule)
        Path2D_CanvasFillRule: struct {
            path: anyopaque,
            fillRule: anyopaque,
        },
    };

    pub fn call_clip(instance: *runtime.Instance, args: ClipArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CanvasFillRule => |arg| return CanvasDrawPathImpl.CanvasFillRule(state, arg),
            .Path2D_CanvasFillRule => |a| return CanvasDrawPathImpl.Path2D_CanvasFillRule(state, a.path, a.fillRule),
        }
    }

    /// Arguments for isPointInStroke (WebIDL overloading)
    pub const IsPointInStrokeArgs = union(enum) {
        /// isPointInStroke(x, y)
        unrestricted double_unrestricted double: struct {
            x: f64,
            y: f64,
        },
        /// isPointInStroke(path, x, y)
        Path2D_unrestricted double_unrestricted double: struct {
            path: anyopaque,
            x: f64,
            y: f64,
        },
    };

    pub fn call_isPointInStroke(instance: *runtime.Instance, args: IsPointInStrokeArgs) bool {
        const state = instance.getState(State);
        switch (args) {
            .unrestricted double_unrestricted double => |a| return CanvasDrawPathImpl.unrestricted double_unrestricted double(state, a.x, a.y),
            .Path2D_unrestricted double_unrestricted double => |a| return CanvasDrawPathImpl.Path2D_unrestricted double_unrestricted double(state, a.path, a.x, a.y),
        }
    }

    /// Arguments for fill (WebIDL overloading)
    pub const FillArgs = union(enum) {
        /// fill(fillRule)
        CanvasFillRule: anyopaque,
        /// fill(path, fillRule)
        Path2D_CanvasFillRule: struct {
            path: anyopaque,
            fillRule: anyopaque,
        },
    };

    pub fn call_fill(instance: *runtime.Instance, args: FillArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CanvasFillRule => |arg| return CanvasDrawPathImpl.CanvasFillRule(state, arg),
            .Path2D_CanvasFillRule => |a| return CanvasDrawPathImpl.Path2D_CanvasFillRule(state, a.path, a.fillRule),
        }
    }

    /// Arguments for stroke (WebIDL overloading)
    pub const StrokeArgs = union(enum) {
        /// stroke()
        no_params: void,
        /// stroke(path)
        Path2D: anyopaque,
    };

    pub fn call_stroke(instance: *runtime.Instance, args: StrokeArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .no_params => return CanvasDrawPathImpl.no_params(state),
            .Path2D => |arg| return CanvasDrawPathImpl.Path2D(state, arg),
        }
    }

};
