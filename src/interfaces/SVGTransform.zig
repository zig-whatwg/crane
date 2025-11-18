//! Generated from: SVG.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGTransformImpl = @import("../impls/SVGTransform.zig");

pub const SVGTransform = struct {
    pub const Meta = struct {
        pub const name = "SVGTransform";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            type: u16 = undefined,
            matrix: DOMMatrix = undefined,
            angle: f32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short SVG_TRANSFORM_UNKNOWN = 0;
    pub fn get_SVG_TRANSFORM_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_TRANSFORM_MATRIX = 1;
    pub fn get_SVG_TRANSFORM_MATRIX() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_TRANSFORM_TRANSLATE = 2;
    pub fn get_SVG_TRANSFORM_TRANSLATE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short SVG_TRANSFORM_SCALE = 3;
    pub fn get_SVG_TRANSFORM_SCALE() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short SVG_TRANSFORM_ROTATE = 4;
    pub fn get_SVG_TRANSFORM_ROTATE() u16 {
        return 4;
    }

    /// WebIDL constant: const unsigned short SVG_TRANSFORM_SKEWX = 5;
    pub fn get_SVG_TRANSFORM_SKEWX() u16 {
        return 5;
    }

    /// WebIDL constant: const unsigned short SVG_TRANSFORM_SKEWY = 6;
    pub fn get_SVG_TRANSFORM_SKEWY() u16 {
        return 6;
    }

    pub const vtable = runtime.buildVTable(SVGTransform, .{
        .deinit_fn = &deinit_wrapper,

        .get_SVG_TRANSFORM_MATRIX = &get_SVG_TRANSFORM_MATRIX,
        .get_SVG_TRANSFORM_ROTATE = &get_SVG_TRANSFORM_ROTATE,
        .get_SVG_TRANSFORM_SCALE = &get_SVG_TRANSFORM_SCALE,
        .get_SVG_TRANSFORM_SKEWX = &get_SVG_TRANSFORM_SKEWX,
        .get_SVG_TRANSFORM_SKEWY = &get_SVG_TRANSFORM_SKEWY,
        .get_SVG_TRANSFORM_TRANSLATE = &get_SVG_TRANSFORM_TRANSLATE,
        .get_SVG_TRANSFORM_UNKNOWN = &get_SVG_TRANSFORM_UNKNOWN,
        .get_angle = &get_angle,
        .get_matrix = &get_matrix,
        .get_type = &get_type,

        .call_setMatrix = &call_setMatrix,
        .call_setRotate = &call_setRotate,
        .call_setScale = &call_setScale,
        .call_setSkewX = &call_setSkewX,
        .call_setSkewY = &call_setSkewY,
        .call_setTranslate = &call_setTranslate,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SVGTransformImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SVGTransformImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return SVGTransformImpl.get_type(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_matrix(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_matrix) |cached| {
            return cached;
        }
        const value = SVGTransformImpl.get_matrix(state);
        state.cached_matrix = value;
        return value;
    }

    pub fn get_angle(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return SVGTransformImpl.get_angle(state);
    }

    pub fn call_setSkewX(instance: *runtime.Instance, angle: f32) anyopaque {
        const state = instance.getState(State);
        
        return SVGTransformImpl.call_setSkewX(state, angle);
    }

    pub fn call_setMatrix(instance: *runtime.Instance, matrix: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SVGTransformImpl.call_setMatrix(state, matrix);
    }

    pub fn call_setRotate(instance: *runtime.Instance, angle: f32, cx: f32, cy: f32) anyopaque {
        const state = instance.getState(State);
        
        return SVGTransformImpl.call_setRotate(state, angle, cx, cy);
    }

    pub fn call_setSkewY(instance: *runtime.Instance, angle: f32) anyopaque {
        const state = instance.getState(State);
        
        return SVGTransformImpl.call_setSkewY(state, angle);
    }

    pub fn call_setTranslate(instance: *runtime.Instance, tx: f32, ty: f32) anyopaque {
        const state = instance.getState(State);
        
        return SVGTransformImpl.call_setTranslate(state, tx, ty);
    }

    pub fn call_setScale(instance: *runtime.Instance, sx: f32, sy: f32) anyopaque {
        const state = instance.getState(State);
        
        return SVGTransformImpl.call_setScale(state, sx, sy);
    }

};
