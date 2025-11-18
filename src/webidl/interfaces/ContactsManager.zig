//! Generated from: contact-picker.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ContactsManagerImpl = @import("impls").ContactsManager;
const Promise<sequence<ContactProperty>> = @import("interfaces").Promise<sequence<ContactProperty>>;
const ContactsSelectOptions = @import("dictionaries").ContactsSelectOptions;
const Promise<sequence<ContactInfo>> = @import("interfaces").Promise<sequence<ContactInfo>>;

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
        
        // Initialize the instance (Impl receives full instance)
        ContactsManagerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ContactsManagerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_select(instance: *runtime.Instance, properties: anyopaque, options: ContactsSelectOptions) anyerror!anyopaque {
        
        return try ContactsManagerImpl.call_select(instance, properties, options);
    }

    pub fn call_getProperties(instance: *runtime.Instance) anyerror!anyopaque {
        return try ContactsManagerImpl.call_getProperties(instance);
    }

};
