//! Generated from: SVG.idl
//! Generated at: 2025-11-23T14:26:30Z
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
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
            .{ "numberOfItems", "get_numberOfItems", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "clear", "call_clear", 0 },
            .{ "initialize", "call_initialize", 1 },
            .{ "getItem", "call_getItem", 1 },
            .{ "insertItemBefore", "call_insertItemBefore", 2 },
            .{ "replaceItem", "call_replaceItem", 2 },
            .{ "removeItem", "call_removeItem", 1 },
            .{ "appendItem", "call_appendItem", 1 },
            .{ "createSVGTransformFromMatrix", "call_createSVGTransformFromMatrix", 0 },
            .{ "consolidate", "call_consolidate", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "clear",
            "initialize",
            "getItem",
            "insertItemBefore",
            "replaceItem",
            "removeItem",
            "appendItem",
            "createSVGTransformFromMatrix",
            "consolidate",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
            .{ "numberOfItems", "get_numberOfItems", null },
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
            length: u32 = undefined,
            numberOfItems: u32 = undefined,
            _internal: ?*SVGTransformListImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGTransformListImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGTransformListImpl.deinit(instance);
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

    pub fn call_consolidate(instance: *runtime.Instance) anyerror!SVGTransform {
        return try SVGTransformListImpl.call_consolidate(instance);
    }

    pub fn call_appendItem(instance: *runtime.Instance, newItem: SVGTransform) anyerror!SVGTransform {
        
        return try SVGTransformListImpl.call_appendItem(instance, newItem);
    }

};
