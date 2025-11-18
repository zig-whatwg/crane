//! Generated from: cssom.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StyleSheetListImpl = @import("../impls/StyleSheetList.zig");

pub const StyleSheetList = struct {
    pub const Meta = struct {
        pub const name = "StyleSheetList";
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
            length: u32 = undefined,
            length: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(StyleSheetList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_length = &get_length,

        .call_item = &call_item,
        .call_item = &call_item,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        StyleSheetListImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        StyleSheetListImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return StyleSheetListImpl.get_length(state);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return StyleSheetListImpl.get_length(state);
    }

    /// Arguments for item (WebIDL overloading)
    pub const ItemArgs = union(enum) {
        /// item(index)
        long: u32,
        /// item(index)
        long: u32,
    };

    pub fn call_item(instance: *runtime.Instance, args: ItemArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .long => |arg| return StyleSheetListImpl.long(state, arg),
            .long => |arg| return StyleSheetListImpl.long(state, arg),
        }
    }

};
