//! Generated from: presentation-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PresentationImpl = @import("impls").Presentation;
const PresentationRequest = @import("interfaces").PresentationRequest;
const PresentationReceiver = @import("interfaces").PresentationReceiver;

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
        
        // Initialize the instance (Impl receives full instance)
        PresentationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PresentationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_defaultRequest(instance: *runtime.Instance) anyerror!anyopaque {
        return try PresentationImpl.get_defaultRequest(instance);
    }

    pub fn set_defaultRequest(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try PresentationImpl.set_defaultRequest(instance, value);
    }

    pub fn get_receiver(instance: *runtime.Instance) anyerror!anyopaque {
        return try PresentationImpl.get_receiver(instance);
    }

};
