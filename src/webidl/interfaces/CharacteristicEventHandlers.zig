//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CharacteristicEventHandlersImpl = @import("impls").CharacteristicEventHandlers;
const EventHandler = @import("typedefs").EventHandler;

pub const CharacteristicEventHandlers = struct {
    pub const Meta = struct {
        pub const name = "CharacteristicEventHandlers";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            oncharacteristicvaluechanged: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CharacteristicEventHandlers, .{
        .deinit_fn = &deinit_wrapper,

        .get_oncharacteristicvaluechanged = &get_oncharacteristicvaluechanged,

        .set_oncharacteristicvaluechanged = &set_oncharacteristicvaluechanged,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CharacteristicEventHandlersImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CharacteristicEventHandlersImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_oncharacteristicvaluechanged(instance: *runtime.Instance) anyerror!EventHandler {
        return try CharacteristicEventHandlersImpl.get_oncharacteristicvaluechanged(instance);
    }

    pub fn set_oncharacteristicvaluechanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try CharacteristicEventHandlersImpl.set_oncharacteristicvaluechanged(instance, value);
    }

};
