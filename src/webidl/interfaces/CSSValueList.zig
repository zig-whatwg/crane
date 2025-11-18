//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSValueListImpl = @import("impls").CSSValueList;
const CSSValue = @import("interfaces").CSSValue;

pub const CSSValueList = struct {
    pub const Meta = struct {
        pub const name = "CSSValueList";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSValue;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            length: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSValueList, .{
        .deinit_fn = &deinit_wrapper,

        .get_CSS_CUSTOM = &CSSValue.get_CSS_CUSTOM,
        .get_CSS_INHERIT = &CSSValue.get_CSS_INHERIT,
        .get_CSS_PRIMITIVE_VALUE = &CSSValue.get_CSS_PRIMITIVE_VALUE,
        .get_CSS_VALUE_LIST = &CSSValue.get_CSS_VALUE_LIST,
        .get_cssText = &get_cssText,
        .get_cssValueType = &get_cssValueType,
        .get_length = &get_length,

        .set_cssText = &set_cssText,

        .call_item = &call_item,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSValueListImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSValueListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSValueListImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSSValueListImpl.set_cssText(instance, value);
    }

    pub fn get_cssValueType(instance: *runtime.Instance) anyerror!u16 {
        return try CSSValueListImpl.get_cssValueType(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSValueListImpl.get_length(instance);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!CSSValue {
        
        return try CSSValueListImpl.call_item(instance, index);
    }

};
