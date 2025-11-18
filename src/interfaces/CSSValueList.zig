//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSValueListImpl = @import("../impls/CSSValueList.zig");
const CSSValue = @import("CSSValue.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        CSSValueListImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSValueListImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSValueListImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CSSValueListImpl.set_cssText(state, value);
    }

    pub fn get_cssValueType(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return CSSValueListImpl.get_cssValueType(state);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return CSSValueListImpl.get_length(state);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyopaque {
        const state = instance.getState(State);
        
        return CSSValueListImpl.call_item(state, index);
    }

};
