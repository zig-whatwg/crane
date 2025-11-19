//! Generated from: dom.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StaticRangeImpl = @import("impls").StaticRange;
const AbstractRange = @import("interfaces").AbstractRange;
const Node = @import("interfaces").Node;
const StaticRangeInit = @import("dictionaries").StaticRangeInit;

pub const StaticRange = struct {
    pub const Meta = struct {
        pub const name = "StaticRange";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AbstractRange;
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

    pub const vtable = runtime.buildVTable(StaticRange, .{
        .deinit_fn = &deinit_wrapper,

        .get_collapsed = &get_collapsed,
        .get_endContainer = &get_endContainer,
        .get_endOffset = &get_endOffset,
        .get_startContainer = &get_startContainer,
        .get_startOffset = &get_startOffset,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return StaticRangeImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StaticRangeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init_data: StaticRangeInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try StaticRangeImpl.constructor(instance, init_data);
        
        return instance;
    }

    pub fn get_startContainer(instance: *runtime.Instance) anyerror!Node {
        return try StaticRangeImpl.get_startContainer(instance);
    }

    pub fn get_startOffset(instance: *runtime.Instance) anyerror!u32 {
        return try StaticRangeImpl.get_startOffset(instance);
    }

    pub fn get_endContainer(instance: *runtime.Instance) anyerror!Node {
        return try StaticRangeImpl.get_endContainer(instance);
    }

    pub fn get_endOffset(instance: *runtime.Instance) anyerror!u32 {
        return try StaticRangeImpl.get_endOffset(instance);
    }

    pub fn get_collapsed(instance: *runtime.Instance) anyerror!bool {
        return try StaticRangeImpl.get_collapsed(instance);
    }

};
