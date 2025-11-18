//! Generated from: contact-picker.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ContactsManagerImpl = @import("../impls/ContactsManager.zig");

pub const ContactsManager = struct {
    pub const Meta = struct {
        pub const name = "ContactsManager";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ContactsManager, .{
        .deinit_fn = &deinit_wrapper,

        .call_getProperties = &call_getProperties,
        .call_select = &call_select,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ContactsManagerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ContactsManagerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_select(instance: *runtime.Instance, properties: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ContactsManagerImpl.call_select(state, properties, options);
    }

    pub fn call_getProperties(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ContactsManagerImpl.call_getProperties(state);
    }

};
