//! Generated from: cssom.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ElementCSSInlineStyleImpl = @import("../impls/ElementCSSInlineStyle.zig");

pub const ElementCSSInlineStyle = struct {
    pub const Meta = struct {
        pub const name = "ElementCSSInlineStyle";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            style: CSSStyleProperties = undefined,
            style: CSSStyleDeclaration = undefined,
            attributeStyleMap: StylePropertyMap = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ElementCSSInlineStyle, .{
        .deinit_fn = &deinit_wrapper,

        .get_attributeStyleMap = &get_attributeStyleMap,
        .get_style = &get_style,
        .get_style = &get_style,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ElementCSSInlineStyleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ElementCSSInlineStyleImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=cssText]
    pub fn get_style(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_style) |cached| {
            return cached;
        }
        const value = ElementCSSInlineStyleImpl.get_style(state);
        state.cached_style = value;
        return value;
    }

    pub fn get_style(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementCSSInlineStyleImpl.get_style(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_attributeStyleMap(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_attributeStyleMap) |cached| {
            return cached;
        }
        const value = ElementCSSInlineStyleImpl.get_attributeStyleMap(state);
        state.cached_attributeStyleMap = value;
        return value;
    }

};
