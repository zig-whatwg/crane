//! Generated from: contact-picker.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ContactAddressImpl = @import("../impls/ContactAddress.zig");

pub const ContactAddress = struct {
    pub const Meta = struct {
        pub const name = "ContactAddress";
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
            city: runtime.DOMString = undefined,
            country: runtime.DOMString = undefined,
            dependentLocality: runtime.DOMString = undefined,
            organization: runtime.DOMString = undefined,
            phone: runtime.DOMString = undefined,
            postalCode: runtime.DOMString = undefined,
            recipient: runtime.DOMString = undefined,
            region: runtime.DOMString = undefined,
            sortingCode: runtime.DOMString = undefined,
            addressLine: FrozenArray<DOMString> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ContactAddress, .{
        .deinit_fn = &deinit_wrapper,

        .get_addressLine = &get_addressLine,
        .get_city = &get_city,
        .get_country = &get_country,
        .get_dependentLocality = &get_dependentLocality,
        .get_organization = &get_organization,
        .get_phone = &get_phone,
        .get_postalCode = &get_postalCode,
        .get_recipient = &get_recipient,
        .get_region = &get_region,
        .get_sortingCode = &get_sortingCode,

        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ContactAddressImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ContactAddressImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_city(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return ContactAddressImpl.get_city(state);
    }

    pub fn get_country(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return ContactAddressImpl.get_country(state);
    }

    pub fn get_dependentLocality(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return ContactAddressImpl.get_dependentLocality(state);
    }

    pub fn get_organization(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return ContactAddressImpl.get_organization(state);
    }

    pub fn get_phone(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return ContactAddressImpl.get_phone(state);
    }

    pub fn get_postalCode(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return ContactAddressImpl.get_postalCode(state);
    }

    pub fn get_recipient(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return ContactAddressImpl.get_recipient(state);
    }

    pub fn get_region(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return ContactAddressImpl.get_region(state);
    }

    pub fn get_sortingCode(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return ContactAddressImpl.get_sortingCode(state);
    }

    pub fn get_addressLine(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ContactAddressImpl.get_addressLine(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ContactAddressImpl.call_toJSON(state);
    }

};
