//! Generated from: dom.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SlottableImpl = @import("impls").Slottable;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;

pub const Slottable = struct {
    pub const Meta = struct {
        pub const name = "Slottable";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            assignedSlot: ?HTMLSlotElement = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Slottable, .{
        .deinit_fn = &deinit_wrapper,

        .get_assignedSlot = &get_assignedSlot,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return SlottableImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SlottableImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_assignedSlot(instance: *runtime.Instance) anyerror!HTMLSlotElement {
        return try SlottableImpl.get_assignedSlot(instance);
    }

};
