//! Generated from: edit-context.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextFormatImpl = @import("impls").TextFormat;
const TextFormatInit = @import("dictionaries").TextFormatInit;
const UnderlineThickness = @import("enums").UnderlineThickness;
const UnderlineStyle = @import("enums").UnderlineStyle;

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
        
        // Initialize the instance (Impl receives full instance)
        TextFormatImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextFormatImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: TextFormatInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try TextFormatImpl.constructor(instance, options);
        
        return instance;
    }

    pub fn get_rangeStart(instance: *runtime.Instance) anyerror!u32 {
        return try TextFormatImpl.get_rangeStart(instance);
    }

    pub fn get_rangeEnd(instance: *runtime.Instance) anyerror!u32 {
        return try TextFormatImpl.get_rangeEnd(instance);
    }

    pub fn get_underlineStyle(instance: *runtime.Instance) anyerror!UnderlineStyle {
        return try TextFormatImpl.get_underlineStyle(instance);
    }

    pub fn get_underlineThickness(instance: *runtime.Instance) anyerror!UnderlineThickness {
        return try TextFormatImpl.get_underlineThickness(instance);
    }

};
