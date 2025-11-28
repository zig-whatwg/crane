//! Generated from: SVG.idl
//! Generated at: 2025-11-28T18:57:55Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGLengthImpl = @import("impls").SVGLength;
const mixins = @import("mixins");
const DOMString = @import("typedefs").DOMString;

pub const SVGLength = struct {
    pub const Meta = struct {
        pub const name = "SVGLength";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "unitType", "get_unitType", null },
            .{ "value", "get_value", "set_value" },
            .{ "valueInSpecifiedUnits", "get_valueInSpecifiedUnits", "set_valueInSpecifiedUnits" },
            .{ "valueAsString", "get_valueAsString", "set_valueAsString" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "newValueSpecifiedUnits", "call_newValueSpecifiedUnits", 2 },
            .{ "convertToSpecifiedUnits", "call_convertToSpecifiedUnits", 1 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "SVG_LENGTHTYPE_UNKNOWN", "get_SVG_LENGTHTYPE_UNKNOWN" },
            .{ "SVG_LENGTHTYPE_NUMBER", "get_SVG_LENGTHTYPE_NUMBER" },
            .{ "SVG_LENGTHTYPE_PERCENTAGE", "get_SVG_LENGTHTYPE_PERCENTAGE" },
            .{ "SVG_LENGTHTYPE_EMS", "get_SVG_LENGTHTYPE_EMS" },
            .{ "SVG_LENGTHTYPE_EXS", "get_SVG_LENGTHTYPE_EXS" },
            .{ "SVG_LENGTHTYPE_PX", "get_SVG_LENGTHTYPE_PX" },
            .{ "SVG_LENGTHTYPE_CM", "get_SVG_LENGTHTYPE_CM" },
            .{ "SVG_LENGTHTYPE_MM", "get_SVG_LENGTHTYPE_MM" },
            .{ "SVG_LENGTHTYPE_IN", "get_SVG_LENGTHTYPE_IN" },
            .{ "SVG_LENGTHTYPE_PT", "get_SVG_LENGTHTYPE_PT" },
            .{ "SVG_LENGTHTYPE_PC", "get_SVG_LENGTHTYPE_PC" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "newValueSpecifiedUnits",
            "convertToSpecifiedUnits",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "unitType", "get_unitType", null },
            .{ "value", "get_value", "set_value" },
            .{ "valueInSpecifiedUnits", "get_valueInSpecifiedUnits", "set_valueInSpecifiedUnits" },
            .{ "valueAsString", "get_valueAsString", "set_valueAsString" },
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
            unitType: u16 = undefined,
            value: f32 = undefined,
            valueInSpecifiedUnits: f32 = undefined,
            valueAsString: runtime.DOMString = undefined,
            _internal: ?*SVGLengthImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short SVG_LENGTHTYPE_UNKNOWN = 0;
    pub fn get_SVG_LENGTHTYPE_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_LENGTHTYPE_NUMBER = 1;
    pub fn get_SVG_LENGTHTYPE_NUMBER() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_LENGTHTYPE_PERCENTAGE = 2;
    pub fn get_SVG_LENGTHTYPE_PERCENTAGE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short SVG_LENGTHTYPE_EMS = 3;
    pub fn get_SVG_LENGTHTYPE_EMS() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short SVG_LENGTHTYPE_EXS = 4;
    pub fn get_SVG_LENGTHTYPE_EXS() u16 {
        return 4;
    }

    /// WebIDL constant: const unsigned short SVG_LENGTHTYPE_PX = 5;
    pub fn get_SVG_LENGTHTYPE_PX() u16 {
        return 5;
    }

    /// WebIDL constant: const unsigned short SVG_LENGTHTYPE_CM = 6;
    pub fn get_SVG_LENGTHTYPE_CM() u16 {
        return 6;
    }

    /// WebIDL constant: const unsigned short SVG_LENGTHTYPE_MM = 7;
    pub fn get_SVG_LENGTHTYPE_MM() u16 {
        return 7;
    }

    /// WebIDL constant: const unsigned short SVG_LENGTHTYPE_IN = 8;
    pub fn get_SVG_LENGTHTYPE_IN() u16 {
        return 8;
    }

    /// WebIDL constant: const unsigned short SVG_LENGTHTYPE_PT = 9;
    pub fn get_SVG_LENGTHTYPE_PT() u16 {
        return 9;
    }

    /// WebIDL constant: const unsigned short SVG_LENGTHTYPE_PC = 10;
    pub fn get_SVG_LENGTHTYPE_PC() u16 {
        return 10;
    }

    const delegates = .{

        .get_SVG_LENGTHTYPE_CM = &get_SVG_LENGTHTYPE_CM,
        .get_SVG_LENGTHTYPE_EMS = &get_SVG_LENGTHTYPE_EMS,
        .get_SVG_LENGTHTYPE_EXS = &get_SVG_LENGTHTYPE_EXS,
        .get_SVG_LENGTHTYPE_IN = &get_SVG_LENGTHTYPE_IN,
        .get_SVG_LENGTHTYPE_MM = &get_SVG_LENGTHTYPE_MM,
        .get_SVG_LENGTHTYPE_NUMBER = &get_SVG_LENGTHTYPE_NUMBER,
        .get_SVG_LENGTHTYPE_PC = &get_SVG_LENGTHTYPE_PC,
        .get_SVG_LENGTHTYPE_PERCENTAGE = &get_SVG_LENGTHTYPE_PERCENTAGE,
        .get_SVG_LENGTHTYPE_PT = &get_SVG_LENGTHTYPE_PT,
        .get_SVG_LENGTHTYPE_PX = &get_SVG_LENGTHTYPE_PX,
        .get_SVG_LENGTHTYPE_UNKNOWN = &get_SVG_LENGTHTYPE_UNKNOWN,
        .get_unitType = &get_unitType,
        .get_value = &get_value,
        .get_valueAsString = &get_valueAsString,
        .get_valueInSpecifiedUnits = &get_valueInSpecifiedUnits,

        .set_value = &set_value,
        .set_valueAsString = &set_valueAsString,
        .set_valueInSpecifiedUnits = &set_valueInSpecifiedUnits,

        .call_convertToSpecifiedUnits = &call_convertToSpecifiedUnits,
        .call_newValueSpecifiedUnits = &call_newValueSpecifiedUnits,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGLengthImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGLengthImpl.deinit(instance);
    }

    pub fn get_unitType(instance: *runtime.Instance) anyerror!u16 {
        return try SVGLengthImpl.get_unitType(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!f32 {
        return try SVGLengthImpl.get_value(instance);
    }

    pub fn set_value(instance: *runtime.Instance, value: f32) anyerror!void {
        try SVGLengthImpl.set_value(instance, value);
    }

    pub fn get_valueInSpecifiedUnits(instance: *runtime.Instance) anyerror!f32 {
        return try SVGLengthImpl.get_valueInSpecifiedUnits(instance);
    }

    pub fn set_valueInSpecifiedUnits(instance: *runtime.Instance, value: f32) anyerror!void {
        try SVGLengthImpl.set_valueInSpecifiedUnits(instance, value);
    }

    pub fn get_valueAsString(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGLengthImpl.get_valueAsString(instance);
    }

    pub fn set_valueAsString(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try SVGLengthImpl.set_valueAsString(instance, value);
    }

    pub fn call_convertToSpecifiedUnits(instance: *runtime.Instance, unitType: u16) anyerror!void {
        
        return try SVGLengthImpl.call_convertToSpecifiedUnits(instance, unitType);
    }

    pub fn call_newValueSpecifiedUnits(instance: *runtime.Instance, unitType: u16, valueInSpecifiedUnits: f32) anyerror!void {
        
        return try SVGLengthImpl.call_newValueSpecifiedUnits(instance, unitType, valueInSpecifiedUnits);
    }

};
