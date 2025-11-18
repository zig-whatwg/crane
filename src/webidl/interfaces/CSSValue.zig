//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSValueImpl = @import("impls").CSSValue;

pub const CSSValue = struct {
    pub const Meta = struct {
        pub const name = "CSSValue";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            cssText: runtime.DOMString = undefined,
            cssValueType: u16 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short CSS_INHERIT = 0;
    pub fn get_CSS_INHERIT() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short CSS_PRIMITIVE_VALUE = 1;
    pub fn get_CSS_PRIMITIVE_VALUE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short CSS_VALUE_LIST = 2;
    pub fn get_CSS_VALUE_LIST() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short CSS_CUSTOM = 3;
    pub fn get_CSS_CUSTOM() u16 {
        return 3;
    }

    pub const vtable = runtime.buildVTable(CSSValue, .{
        .deinit_fn = &deinit_wrapper,

        .get_CSS_CUSTOM = &get_CSS_CUSTOM,
        .get_CSS_INHERIT = &get_CSS_INHERIT,
        .get_CSS_PRIMITIVE_VALUE = &get_CSS_PRIMITIVE_VALUE,
        .get_CSS_VALUE_LIST = &get_CSS_VALUE_LIST,
        .get_cssText = &get_cssText,
        .get_cssValueType = &get_cssValueType,

        .set_cssText = &set_cssText,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSValueImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSValueImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSValueImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSSValueImpl.set_cssText(instance, value);
    }

    pub fn get_cssValueType(instance: *runtime.Instance) anyerror!u16 {
        return try CSSValueImpl.get_cssValueType(instance);
    }

};
