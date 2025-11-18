//! Generated from: cssom-view.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GeometryUtilsImpl = @import("impls").GeometryUtils;
const DOMPoint = @import("interfaces").DOMPoint;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;

pub const GeometryUtils = struct {
    pub const Meta = struct {
        pub const name = "GeometryUtils";
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

    pub const vtable = runtime.buildVTable(GeometryUtils, .{
        .deinit_fn = &deinit_wrapper,

        .call_convertPointFromNode = &call_convertPointFromNode,
        .call_convertQuadFromNode = &call_convertQuadFromNode,
        .call_convertRectFromNode = &call_convertRectFromNode,
        .call_getBoxQuads = &call_getBoxQuads,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GeometryUtilsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GeometryUtilsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: DOMQuadInit, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!DOMQuad {
        
        return try GeometryUtilsImpl.call_convertQuadFromNode(instance, quad, from, options);
    }

    pub fn call_convertPointFromNode(instance: *runtime.Instance, point: DOMPointInit, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!DOMPoint {
        
        return try GeometryUtilsImpl.call_convertPointFromNode(instance, point, from, options);
    }

    pub fn call_getBoxQuads(instance: *runtime.Instance, options: BoxQuadOptions) anyerror!anyopaque {
        
        return try GeometryUtilsImpl.call_getBoxQuads(instance, options);
    }

    pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: DOMRectReadOnly, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!DOMQuad {
        
        return try GeometryUtilsImpl.call_convertRectFromNode(instance, rect, from, options);
    }

};
