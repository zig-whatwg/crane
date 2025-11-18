//! Generated from: contact-picker.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ContactAddressImpl = @import("impls").ContactAddress;
const FrozenArray<DOMString> = @import("interfaces").FrozenArray<DOMString>;

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
        
        // Initialize the instance (Impl receives full instance)
        ContactAddressImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ContactAddressImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_city(instance: *runtime.Instance) anyerror!DOMString {
        return try ContactAddressImpl.get_city(instance);
    }

    pub fn get_country(instance: *runtime.Instance) anyerror!DOMString {
        return try ContactAddressImpl.get_country(instance);
    }

    pub fn get_dependentLocality(instance: *runtime.Instance) anyerror!DOMString {
        return try ContactAddressImpl.get_dependentLocality(instance);
    }

    pub fn get_organization(instance: *runtime.Instance) anyerror!DOMString {
        return try ContactAddressImpl.get_organization(instance);
    }

    pub fn get_phone(instance: *runtime.Instance) anyerror!DOMString {
        return try ContactAddressImpl.get_phone(instance);
    }

    pub fn get_postalCode(instance: *runtime.Instance) anyerror!DOMString {
        return try ContactAddressImpl.get_postalCode(instance);
    }

    pub fn get_recipient(instance: *runtime.Instance) anyerror!DOMString {
        return try ContactAddressImpl.get_recipient(instance);
    }

    pub fn get_region(instance: *runtime.Instance) anyerror!DOMString {
        return try ContactAddressImpl.get_region(instance);
    }

    pub fn get_sortingCode(instance: *runtime.Instance) anyerror!DOMString {
        return try ContactAddressImpl.get_sortingCode(instance);
    }

    pub fn get_addressLine(instance: *runtime.Instance) anyerror!anyopaque {
        return try ContactAddressImpl.get_addressLine(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try ContactAddressImpl.call_toJSON(instance);
    }

};
