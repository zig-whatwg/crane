//! Generated from: SVG.idl
//! Generated at: 2025-11-25T19:42:24Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGAngleImpl = @import("impls").SVGAngle;
const DOMString = @import("typedefs").DOMString;

pub const SVGAngle = struct {
    pub const Meta = struct {
        pub const name = "SVGAngle";
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
            .{ "SVG_ANGLETYPE_UNKNOWN", "get_SVG_ANGLETYPE_UNKNOWN" },
            .{ "SVG_ANGLETYPE_UNSPECIFIED", "get_SVG_ANGLETYPE_UNSPECIFIED" },
            .{ "SVG_ANGLETYPE_DEG", "get_SVG_ANGLETYPE_DEG" },
            .{ "SVG_ANGLETYPE_RAD", "get_SVG_ANGLETYPE_RAD" },
            .{ "SVG_ANGLETYPE_GRAD", "get_SVG_ANGLETYPE_GRAD" },
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
            _internal: ?*SVGAngleImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short SVG_ANGLETYPE_UNKNOWN = 0;
    pub fn get_SVG_ANGLETYPE_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_ANGLETYPE_UNSPECIFIED = 1;
    pub fn get_SVG_ANGLETYPE_UNSPECIFIED() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_ANGLETYPE_DEG = 2;
    pub fn get_SVG_ANGLETYPE_DEG() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short SVG_ANGLETYPE_RAD = 3;
    pub fn get_SVG_ANGLETYPE_RAD() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short SVG_ANGLETYPE_GRAD = 4;
    pub fn get_SVG_ANGLETYPE_GRAD() u16 {
        return 4;
    }

    const delegates = .{

        .get_SVG_ANGLETYPE_DEG = &get_SVG_ANGLETYPE_DEG,
        .get_SVG_ANGLETYPE_GRAD = &get_SVG_ANGLETYPE_GRAD,
        .get_SVG_ANGLETYPE_RAD = &get_SVG_ANGLETYPE_RAD,
        .get_SVG_ANGLETYPE_UNKNOWN = &get_SVG_ANGLETYPE_UNKNOWN,
        .get_SVG_ANGLETYPE_UNSPECIFIED = &get_SVG_ANGLETYPE_UNSPECIFIED,
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
        return SVGAngleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGAngleImpl.deinit(instance);
    }

    pub fn get_unitType(instance: *runtime.Instance) anyerror!u16 {
        return try SVGAngleImpl.get_unitType(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!f32 {
        return try SVGAngleImpl.get_value(instance);
    }

    pub fn set_value(instance: *runtime.Instance, value: f32) anyerror!void {
        try SVGAngleImpl.set_value(instance, value);
    }

    pub fn get_valueInSpecifiedUnits(instance: *runtime.Instance) anyerror!f32 {
        return try SVGAngleImpl.get_valueInSpecifiedUnits(instance);
    }

    pub fn set_valueInSpecifiedUnits(instance: *runtime.Instance, value: f32) anyerror!void {
        try SVGAngleImpl.set_valueInSpecifiedUnits(instance, value);
    }

    pub fn get_valueAsString(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGAngleImpl.get_valueAsString(instance);
    }

    pub fn set_valueAsString(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try SVGAngleImpl.set_valueAsString(instance, value);
    }

    pub fn call_convertToSpecifiedUnits(instance: *runtime.Instance, unitType: u16) anyerror!void {
        
        return try SVGAngleImpl.call_convertToSpecifiedUnits(instance, unitType);
    }

    pub fn call_newValueSpecifiedUnits(instance: *runtime.Instance, unitType: u16, valueInSpecifiedUnits: f32) anyerror!void {
        
        return try SVGAngleImpl.call_newValueSpecifiedUnits(instance, unitType, valueInSpecifiedUnits);
    }

};
