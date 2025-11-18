//! Generated from: cssom.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ElementCSSInlineStyleImpl = @import("impls").ElementCSSInlineStyle;
const CSSStyleProperties = @import("interfaces").CSSStyleProperties;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const StylePropertyMap = @import("interfaces").StylePropertyMap;

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
        
        // Initialize the instance (Impl receives full instance)
        ElementCSSInlineStyleImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ElementCSSInlineStyleImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=cssText]
    pub fn get_style(instance: *runtime.Instance) anyerror!CSSStyleProperties {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_style) |cached| {
            return cached;
        }
        const value = try ElementCSSInlineStyleImpl.get_style(instance);
        state.cached_style = value;
        return value;
    }

    pub fn get_style(instance: *runtime.Instance) anyerror!CSSStyleDeclaration {
        return try ElementCSSInlineStyleImpl.get_style(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_attributeStyleMap(instance: *runtime.Instance) anyerror!StylePropertyMap {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_attributeStyleMap) |cached| {
            return cached;
        }
        const value = try ElementCSSInlineStyleImpl.get_attributeStyleMap(instance);
        state.cached_attributeStyleMap = value;
        return value;
    }

};
