//! Generated from: css-highlight-api.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HighlightImpl = @import("impls").Highlight;
const HighlightType = @import("enums").HighlightType;
const AbstractRange = @import("interfaces").AbstractRange;

pub const Highlight = struct {
    pub const Meta = struct {
        pub const name = "Highlight";
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
            priority: i32 = undefined,
            type: HighlightType = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const void _skipped = null;
    pub fn get__skipped() void {
        return null;
    }

    pub const vtable = runtime.buildVTable(Highlight, .{
        .deinit_fn = &deinit_wrapper,

        .get__skipped = &get__skipped,
        .get_priority = &get_priority,
        .get_type = &get_type,

        .set_priority = &set_priority,
        .set_type = &set_type,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        HighlightImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HighlightImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, initialRanges: AbstractRange) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try HighlightImpl.constructor(instance, initialRanges);
        
        return instance;
    }

    pub fn get_priority(instance: *runtime.Instance) anyerror!i32 {
        return try HighlightImpl.get_priority(instance);
    }

    pub fn set_priority(instance: *runtime.Instance, value: i32) anyerror!void {
        try HighlightImpl.set_priority(instance, value);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!HighlightType {
        return try HighlightImpl.get_type(instance);
    }

    pub fn set_type(instance: *runtime.Instance, value: HighlightType) anyerror!void {
        try HighlightImpl.set_type(instance, value);
    }

};
