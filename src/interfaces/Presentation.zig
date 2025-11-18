//! Generated from: presentation-api.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PresentationImpl = @import("../impls/Presentation.zig");

pub const Presentation = struct {
    pub const Meta = struct {
        pub const name = "Presentation";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            defaultRequest: ?PresentationRequest = null,
            receiver: ?PresentationReceiver = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Presentation, .{
        .deinit_fn = &deinit_wrapper,

        .get_defaultRequest = &get_defaultRequest,
        .get_receiver = &get_receiver,

        .set_defaultRequest = &set_defaultRequest,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        PresentationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PresentationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_defaultRequest(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PresentationImpl.get_defaultRequest(state);
    }

    pub fn set_defaultRequest(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PresentationImpl.set_defaultRequest(state, value);
    }

    pub fn get_receiver(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PresentationImpl.get_receiver(state);
    }

};
