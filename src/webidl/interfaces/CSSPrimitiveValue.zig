//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-23T14:26:30Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSPrimitiveValueImpl = @import("impls").CSSPrimitiveValue;
const CSSValue = @import("interfaces").CSSValue;
const Counter = @import("interfaces").Counter;
const Rect = @import("interfaces").Rect;
const RGBColor = @import("interfaces").RGBColor;
const DOMString = @import("typedefs").DOMString;

pub const CSSPrimitiveValue = struct {
    pub const Meta = struct {
        pub const name = "CSSPrimitiveValue";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSValue;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "primitiveType", "get_primitiveType", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "setFloatValue", "call_setFloatValue", 2 },
            .{ "getFloatValue", "call_getFloatValue", 1 },
            .{ "setStringValue", "call_setStringValue", 2 },
            .{ "getStringValue", "call_getStringValue", 0 },
            .{ "getCounterValue", "call_getCounterValue", 0 },
            .{ "getRectValue", "call_getRectValue", 0 },
            .{ "getRGBColorValue", "call_getRGBColorValue", 0 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "CSS_UNKNOWN", "get_CSS_UNKNOWN" },
            .{ "CSS_NUMBER", "get_CSS_NUMBER" },
            .{ "CSS_PERCENTAGE", "get_CSS_PERCENTAGE" },
            .{ "CSS_EMS", "get_CSS_EMS" },
            .{ "CSS_EXS", "get_CSS_EXS" },
            .{ "CSS_PX", "get_CSS_PX" },
            .{ "CSS_CM", "get_CSS_CM" },
            .{ "CSS_MM", "get_CSS_MM" },
            .{ "CSS_IN", "get_CSS_IN" },
            .{ "CSS_PT", "get_CSS_PT" },
            .{ "CSS_PC", "get_CSS_PC" },
            .{ "CSS_DEG", "get_CSS_DEG" },
            .{ "CSS_RAD", "get_CSS_RAD" },
            .{ "CSS_GRAD", "get_CSS_GRAD" },
            .{ "CSS_MS", "get_CSS_MS" },
            .{ "CSS_S", "get_CSS_S" },
            .{ "CSS_HZ", "get_CSS_HZ" },
            .{ "CSS_KHZ", "get_CSS_KHZ" },
            .{ "CSS_DIMENSION", "get_CSS_DIMENSION" },
            .{ "CSS_STRING", "get_CSS_STRING" },
            .{ "CSS_URI", "get_CSS_URI" },
            .{ "CSS_IDENT", "get_CSS_IDENT" },
            .{ "CSS_ATTR", "get_CSS_ATTR" },
            .{ "CSS_COUNTER", "get_CSS_COUNTER" },
            .{ "CSS_RECT", "get_CSS_RECT" },
            .{ "CSS_RGBCOLOR", "get_CSS_RGBCOLOR" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setFloatValue",
            "getFloatValue",
            "setStringValue",
            "getStringValue",
            "getCounterValue",
            "getRectValue",
            "getRGBColorValue",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "primitiveType", "get_primitiveType", null },
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
            primitiveType: u16 = undefined,
            _internal: ?*CSSPrimitiveValueImpl.InternalState = null,
        },
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

    const delegates = .{

        .get_CSS_ATTR = &get_CSS_ATTR,
        .get_CSS_CM = &get_CSS_CM,
        .get_CSS_COUNTER = &get_CSS_COUNTER,
        .get_CSS_DEG = &get_CSS_DEG,
        .get_CSS_DIMENSION = &get_CSS_DIMENSION,
        .get_CSS_EMS = &get_CSS_EMS,
        .get_CSS_EXS = &get_CSS_EXS,
        .get_CSS_GRAD = &get_CSS_GRAD,
        .get_CSS_HZ = &get_CSS_HZ,
        .get_CSS_IDENT = &get_CSS_IDENT,
        .get_CSS_IN = &get_CSS_IN,
        .get_CSS_KHZ = &get_CSS_KHZ,
        .get_CSS_MM = &get_CSS_MM,
        .get_CSS_MS = &get_CSS_MS,
        .get_CSS_NUMBER = &get_CSS_NUMBER,
        .get_CSS_PC = &get_CSS_PC,
        .get_CSS_PERCENTAGE = &get_CSS_PERCENTAGE,
        .get_CSS_PT = &get_CSS_PT,
        .get_CSS_PX = &get_CSS_PX,
        .get_CSS_RAD = &get_CSS_RAD,
        .get_CSS_RECT = &get_CSS_RECT,
        .get_CSS_RGBCOLOR = &get_CSS_RGBCOLOR,
        .get_CSS_S = &get_CSS_S,
        .get_CSS_STRING = &get_CSS_STRING,
        .get_CSS_UNKNOWN = &get_CSS_UNKNOWN,
        .get_CSS_URI = &get_CSS_URI,
        .get_primitiveType = &get_primitiveType,

        .call_getCounterValue = &call_getCounterValue,
        .call_getFloatValue = &call_getFloatValue,
        .call_getRGBColorValue = &call_getRGBColorValue,
        .call_getRectValue = &call_getRectValue,
        .call_getStringValue = &call_getStringValue,
        .call_setFloatValue = &call_setFloatValue,
        .call_setStringValue = &call_setStringValue,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSPrimitiveValueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSPrimitiveValueImpl.deinit(instance);
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
