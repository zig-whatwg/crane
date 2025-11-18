//! Generated from: SVG.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGLengthImpl = @import("../impls/SVGLength.zig");

pub const SVGLength = struct {
    pub const Meta = struct {
        pub const name = "SVGLength";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            unitType: u16 = undefined,
            value: f32 = undefined,
            valueInSpecifiedUnits: f32 = undefined,
            valueAsString: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
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

    pub const vtable = runtime.buildVTable(SVGLength, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SVGLengthImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SVGLengthImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_unitType(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return SVGLengthImpl.get_unitType(state);
    }

    pub fn get_value(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return SVGLengthImpl.get_value(state);
    }

    pub fn set_value(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        SVGLengthImpl.set_value(state, value);
    }

    pub fn get_valueInSpecifiedUnits(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return SVGLengthImpl.get_valueInSpecifiedUnits(state);
    }

    pub fn set_valueInSpecifiedUnits(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        SVGLengthImpl.set_valueInSpecifiedUnits(state, value);
    }

    pub fn get_valueAsString(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SVGLengthImpl.get_valueAsString(state);
    }

    pub fn set_valueAsString(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        SVGLengthImpl.set_valueAsString(state, value);
    }

    pub fn call_convertToSpecifiedUnits(instance: *runtime.Instance, unitType: u16) anyopaque {
        const state = instance.getState(State);
        
        return SVGLengthImpl.call_convertToSpecifiedUnits(state, unitType);
    }

    pub fn call_newValueSpecifiedUnits(instance: *runtime.Instance, unitType: u16, valueInSpecifiedUnits: f32) anyopaque {
        const state = instance.getState(State);
        
        return SVGLengthImpl.call_newValueSpecifiedUnits(state, unitType, valueInSpecifiedUnits);
    }

};
