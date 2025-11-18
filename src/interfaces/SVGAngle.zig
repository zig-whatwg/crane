//! Generated from: SVG.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGAngleImpl = @import("../impls/SVGAngle.zig");

pub const SVGAngle = struct {
    pub const Meta = struct {
        pub const name = "SVGAngle";
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

    pub const vtable = runtime.buildVTable(SVGAngle, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SVGAngleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SVGAngleImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_unitType(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return SVGAngleImpl.get_unitType(state);
    }

    pub fn get_value(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return SVGAngleImpl.get_value(state);
    }

    pub fn set_value(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        SVGAngleImpl.set_value(state, value);
    }

    pub fn get_valueInSpecifiedUnits(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return SVGAngleImpl.get_valueInSpecifiedUnits(state);
    }

    pub fn set_valueInSpecifiedUnits(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        SVGAngleImpl.set_valueInSpecifiedUnits(state, value);
    }

    pub fn get_valueAsString(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SVGAngleImpl.get_valueAsString(state);
    }

    pub fn set_valueAsString(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        SVGAngleImpl.set_valueAsString(state, value);
    }

    pub fn call_convertToSpecifiedUnits(instance: *runtime.Instance, unitType: u16) anyopaque {
        const state = instance.getState(State);
        
        return SVGAngleImpl.call_convertToSpecifiedUnits(state, unitType);
    }

    pub fn call_newValueSpecifiedUnits(instance: *runtime.Instance, unitType: u16, valueInSpecifiedUnits: f32) anyopaque {
        const state = instance.getState(State);
        
        return SVGAngleImpl.call_newValueSpecifiedUnits(state, unitType, valueInSpecifiedUnits);
    }

};
