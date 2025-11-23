//! Generated from: contact-picker.idl
//! Generated at: 2025-11-23T16:59:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ContactAddressImpl = @import("impls").ContactAddress;
const DOMString = @import("typedefs").DOMString;

pub const ContactAddress = struct {
    pub const Meta = struct {
        pub const name = "ContactAddress";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "city", "get_city", null },
            .{ "country", "get_country", null },
            .{ "dependentLocality", "get_dependentLocality", null },
            .{ "organization", "get_organization", null },
            .{ "phone", "get_phone", null },
            .{ "postalCode", "get_postalCode", null },
            .{ "recipient", "get_recipient", null },
            .{ "region", "get_region", null },
            .{ "sortingCode", "get_sortingCode", null },
            .{ "addressLine", "get_addressLine", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "city", "get_city", null },
            .{ "country", "get_country", null },
            .{ "dependentLocality", "get_dependentLocality", null },
            .{ "organization", "get_organization", null },
            .{ "phone", "get_phone", null },
            .{ "postalCode", "get_postalCode", null },
            .{ "recipient", "get_recipient", null },
            .{ "region", "get_region", null },
            .{ "sortingCode", "get_sortingCode", null },
            .{ "addressLine", "get_addressLine", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
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
            addressLine: runtime.FrozenArray(runtime.DOMString) = undefined,
            _internal: ?*ContactAddressImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ContactAddressImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ContactAddressImpl.deinit(instance);
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

    pub fn get_addressLine(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ContactAddressImpl.get_addressLine(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ContactAddressImpl.call_toJSON(instance);
    }

};
