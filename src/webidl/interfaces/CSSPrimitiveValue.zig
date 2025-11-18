//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSPrimitiveValueImpl = @import("impls").CSSPrimitiveValue;
const CSSValue = @import("interfaces").CSSValue;
const Counter = @import("interfaces").Counter;
const Rect = @import("interfaces").Rect;
const RGBColor = @import("interfaces").RGBColor;

pub const CSSPrimitiveValue = struct {
    pub const Meta = struct {
        pub const name = "CSSPrimitiveValue";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSValue;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            primitiveType: u16 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short CSS_UNKNOWN = 0;
    pub fn get_CSS_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short CSS_NUMBER = 1;
    pub fn get_CSS_NUMBER() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short CSS_PERCENTAGE = 2;
    pub fn get_CSS_PERCENTAGE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short CSS_EMS = 3;
    pub fn get_CSS_EMS() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short CSS_EXS = 4;
    pub fn get_CSS_EXS() u16 {
        return 4;
    }

    /// WebIDL constant: const unsigned short CSS_PX = 5;
    pub fn get_CSS_PX() u16 {
        return 5;
    }

    /// WebIDL constant: const unsigned short CSS_CM = 6;
    pub fn get_CSS_CM() u16 {
        return 6;
    }

    /// WebIDL constant: const unsigned short CSS_MM = 7;
    pub fn get_CSS_MM() u16 {
        return 7;
    }

    /// WebIDL constant: const unsigned short CSS_IN = 8;
    pub fn get_CSS_IN() u16 {
        return 8;
    }

    /// WebIDL constant: const unsigned short CSS_PT = 9;
    pub fn get_CSS_PT() u16 {
        return 9;
    }

    /// WebIDL constant: const unsigned short CSS_PC = 10;
    pub fn get_CSS_PC() u16 {
        return 10;
    }

    /// WebIDL constant: const unsigned short CSS_DEG = 11;
    pub fn get_CSS_DEG() u16 {
        return 11;
    }

    /// WebIDL constant: const unsigned short CSS_RAD = 12;
    pub fn get_CSS_RAD() u16 {
        return 12;
    }

    /// WebIDL constant: const unsigned short CSS_GRAD = 13;
    pub fn get_CSS_GRAD() u16 {
        return 13;
    }

    /// WebIDL constant: const unsigned short CSS_MS = 14;
    pub fn get_CSS_MS() u16 {
        return 14;
    }

    /// WebIDL constant: const unsigned short CSS_S = 15;
    pub fn get_CSS_S() u16 {
        return 15;
    }

    /// WebIDL constant: const unsigned short CSS_HZ = 16;
    pub fn get_CSS_HZ() u16 {
        return 16;
    }

    /// WebIDL constant: const unsigned short CSS_KHZ = 17;
    pub fn get_CSS_KHZ() u16 {
        return 17;
    }

    /// WebIDL constant: const unsigned short CSS_DIMENSION = 18;
    pub fn get_CSS_DIMENSION() u16 {
        return 18;
    }

    /// WebIDL constant: const unsigned short CSS_STRING = 19;
    pub fn get_CSS_STRING() u16 {
        return 19;
    }

    /// WebIDL constant: const unsigned short CSS_URI = 20;
    pub fn get_CSS_URI() u16 {
        return 20;
    }

    /// WebIDL constant: const unsigned short CSS_IDENT = 21;
    pub fn get_CSS_IDENT() u16 {
        return 21;
    }

    /// WebIDL constant: const unsigned short CSS_ATTR = 22;
    pub fn get_CSS_ATTR() u16 {
        return 22;
    }

    /// WebIDL constant: const unsigned short CSS_COUNTER = 23;
    pub fn get_CSS_COUNTER() u16 {
        return 23;
    }

    /// WebIDL constant: const unsigned short CSS_RECT = 24;
    pub fn get_CSS_RECT() u16 {
        return 24;
    }

    /// WebIDL constant: const unsigned short CSS_RGBCOLOR = 25;
    pub fn get_CSS_RGBCOLOR() u16 {
        return 25;
    }

    pub const vtable = runtime.buildVTable(CSSPrimitiveValue, .{
        .deinit_fn = &deinit_wrapper,

        .get_CSS_ATTR = &get_CSS_ATTR,
        .get_CSS_CM = &get_CSS_CM,
        .get_CSS_COUNTER = &get_CSS_COUNTER,
        .get_CSS_CUSTOM = &CSSValue.get_CSS_CUSTOM,
        .get_CSS_DEG = &get_CSS_DEG,
        .get_CSS_DIMENSION = &get_CSS_DIMENSION,
        .get_CSS_EMS = &get_CSS_EMS,
        .get_CSS_EXS = &get_CSS_EXS,
        .get_CSS_GRAD = &get_CSS_GRAD,
        .get_CSS_HZ = &get_CSS_HZ,
        .get_CSS_IDENT = &get_CSS_IDENT,
        .get_CSS_IN = &get_CSS_IN,
        .get_CSS_INHERIT = &CSSValue.get_CSS_INHERIT,
        .get_CSS_KHZ = &get_CSS_KHZ,
        .get_CSS_MM = &get_CSS_MM,
        .get_CSS_MS = &get_CSS_MS,
        .get_CSS_NUMBER = &get_CSS_NUMBER,
        .get_CSS_PC = &get_CSS_PC,
        .get_CSS_PERCENTAGE = &get_CSS_PERCENTAGE,
        .get_CSS_PRIMITIVE_VALUE = &CSSValue.get_CSS_PRIMITIVE_VALUE,
        .get_CSS_PT = &get_CSS_PT,
        .get_CSS_PX = &get_CSS_PX,
        .get_CSS_RAD = &get_CSS_RAD,
        .get_CSS_RECT = &get_CSS_RECT,
        .get_CSS_RGBCOLOR = &get_CSS_RGBCOLOR,
        .get_CSS_S = &get_CSS_S,
        .get_CSS_STRING = &get_CSS_STRING,
        .get_CSS_UNKNOWN = &get_CSS_UNKNOWN,
        .get_CSS_URI = &get_CSS_URI,
        .get_CSS_VALUE_LIST = &CSSValue.get_CSS_VALUE_LIST,
        .get_cssText = &get_cssText,
        .get_cssValueType = &get_cssValueType,
        .get_primitiveType = &get_primitiveType,

        .set_cssText = &set_cssText,

        .call_getCounterValue = &call_getCounterValue,
        .call_getFloatValue = &call_getFloatValue,
        .call_getRGBColorValue = &call_getRGBColorValue,
        .call_getRectValue = &call_getRectValue,
        .call_getStringValue = &call_getStringValue,
        .call_setFloatValue = &call_setFloatValue,
        .call_setStringValue = &call_setStringValue,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSPrimitiveValueImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSPrimitiveValueImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSPrimitiveValueImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSSPrimitiveValueImpl.set_cssText(instance, value);
    }

    pub fn get_cssValueType(instance: *runtime.Instance) anyerror!u16 {
        return try CSSPrimitiveValueImpl.get_cssValueType(instance);
    }

    pub fn get_primitiveType(instance: *runtime.Instance) anyerror!u16 {
        return try CSSPrimitiveValueImpl.get_primitiveType(instance);
    }

    pub fn call_setStringValue(instance: *runtime.Instance, stringType: u16, stringValue: DOMString) anyerror!void {
        
        return try CSSPrimitiveValueImpl.call_setStringValue(instance, stringType, stringValue);
    }

    pub fn call_getFloatValue(instance: *runtime.Instance, unitType: u16) anyerror!f32 {
        
        return try CSSPrimitiveValueImpl.call_getFloatValue(instance, unitType);
    }

    pub fn call_getRGBColorValue(instance: *runtime.Instance) anyerror!RGBColor {
        return try CSSPrimitiveValueImpl.call_getRGBColorValue(instance);
    }

    pub fn call_setFloatValue(instance: *runtime.Instance, unitType: u16, floatValue: f32) anyerror!void {
        
        return try CSSPrimitiveValueImpl.call_setFloatValue(instance, unitType, floatValue);
    }

    pub fn call_getStringValue(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSPrimitiveValueImpl.call_getStringValue(instance);
    }

    pub fn call_getRectValue(instance: *runtime.Instance) anyerror!Rect {
        return try CSSPrimitiveValueImpl.call_getRectValue(instance);
    }

    pub fn call_getCounterValue(instance: *runtime.Instance) anyerror!Counter {
        return try CSSPrimitiveValueImpl.call_getCounterValue(instance);
    }

};
