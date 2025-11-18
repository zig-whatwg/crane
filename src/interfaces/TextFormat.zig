//! Generated from: edit-context.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextFormatImpl = @import("../impls/TextFormat.zig");

pub const TextFormat = struct {
    pub const Meta = struct {
        pub const name = "TextFormat";
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
            rangeStart: u32 = undefined,
            rangeEnd: u32 = undefined,
            underlineStyle: UnderlineStyle = undefined,
            underlineThickness: UnderlineThickness = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TextFormat, .{
        .deinit_fn = &deinit_wrapper,

        .get_rangeEnd = &get_rangeEnd,
        .get_rangeStart = &get_rangeStart,
        .get_underlineStyle = &get_underlineStyle,
        .get_underlineThickness = &get_underlineThickness,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        TextFormatImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TextFormatImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try TextFormatImpl.constructor(state, options);
        
        return instance;
    }

    pub fn get_rangeStart(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return TextFormatImpl.get_rangeStart(state);
    }

    pub fn get_rangeEnd(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return TextFormatImpl.get_rangeEnd(state);
    }

    pub fn get_underlineStyle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TextFormatImpl.get_underlineStyle(state);
    }

    pub fn get_underlineThickness(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TextFormatImpl.get_underlineThickness(state);
    }

};
