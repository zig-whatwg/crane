//! Generated from: SVG.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGUnitTypesImpl = @import("../impls/SVGUnitTypes.zig");

pub const SVGUnitTypes = struct {
    pub const Meta = struct {
        pub const name = "SVGUnitTypes";
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short SVG_UNIT_TYPE_UNKNOWN = 0;
    pub fn get_SVG_UNIT_TYPE_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_UNIT_TYPE_USERSPACEONUSE = 1;
    pub fn get_SVG_UNIT_TYPE_USERSPACEONUSE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_UNIT_TYPE_OBJECTBOUNDINGBOX = 2;
    pub fn get_SVG_UNIT_TYPE_OBJECTBOUNDINGBOX() u16 {
        return 2;
    }

    pub const vtable = runtime.buildVTable(SVGUnitTypes, .{
        .deinit_fn = &deinit_wrapper,

        .get_SVG_UNIT_TYPE_OBJECTBOUNDINGBOX = &get_SVG_UNIT_TYPE_OBJECTBOUNDINGBOX,
        .get_SVG_UNIT_TYPE_UNKNOWN = &get_SVG_UNIT_TYPE_UNKNOWN,
        .get_SVG_UNIT_TYPE_USERSPACEONUSE = &get_SVG_UNIT_TYPE_USERSPACEONUSE,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SVGUnitTypesImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SVGUnitTypesImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
