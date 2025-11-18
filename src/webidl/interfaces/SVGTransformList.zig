//! Generated from: SVG.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGTransformListImpl = @import("impls").SVGTransformList;
const DOMMatrix2DInit = @import("dictionaries").DOMMatrix2DInit;
const SVGTransform = @import("interfaces").SVGTransform;

pub const SVGTransformList = struct {
    pub const Meta = struct {
        pub const name = "SVGTransformList";
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
            length: u32 = undefined,
            numberOfItems: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGTransformList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_numberOfItems = &get_numberOfItems,

        .call_appendItem = &call_appendItem,
        .call_clear = &call_clear,
        .call_consolidate = &call_consolidate,
        .call_createSVGTransformFromMatrix = &call_createSVGTransformFromMatrix,
        .call_getItem = &call_getItem,
        .call_initialize = &call_initialize,
        .call_insertItemBefore = &call_insertItemBefore,
        .call_removeItem = &call_removeItem,
        .call_replaceItem = &call_replaceItem,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SVGTransformListImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGTransformListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try SVGTransformListImpl.get_length(instance);
    }

    pub fn get_numberOfItems(instance: *runtime.Instance) anyerror!u32 {
        return try SVGTransformListImpl.get_numberOfItems(instance);
    }

    pub fn call_removeItem(instance: *runtime.Instance, index: u32) anyerror!SVGTransform {
        
        return try SVGTransformListImpl.call_removeItem(instance, index);
    }

    pub fn call_insertItemBefore(instance: *runtime.Instance, newItem: SVGTransform, index: u32) anyerror!SVGTransform {
        
        return try SVGTransformListImpl.call_insertItemBefore(instance, newItem, index);
    }

    pub fn call_createSVGTransformFromMatrix(instance: *runtime.Instance, matrix: DOMMatrix2DInit) anyerror!SVGTransform {
        
        return try SVGTransformListImpl.call_createSVGTransformFromMatrix(instance, matrix);
    }

    pub fn call_getItem(instance: *runtime.Instance, index: u32) anyerror!SVGTransform {
        
        return try SVGTransformListImpl.call_getItem(instance, index);
    }

    pub fn call_replaceItem(instance: *runtime.Instance, newItem: SVGTransform, index: u32) anyerror!SVGTransform {
        
        return try SVGTransformListImpl.call_replaceItem(instance, newItem, index);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try SVGTransformListImpl.call_clear(instance);
    }

    pub fn call_initialize(instance: *runtime.Instance, newItem: SVGTransform) anyerror!SVGTransform {
        
        return try SVGTransformListImpl.call_initialize(instance, newItem);
    }

    pub fn call_consolidate(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGTransformListImpl.call_consolidate(instance);
    }

    pub fn call_appendItem(instance: *runtime.Instance, newItem: SVGTransform) anyerror!SVGTransform {
        
        return try SVGTransformListImpl.call_appendItem(instance, newItem);
    }

};
