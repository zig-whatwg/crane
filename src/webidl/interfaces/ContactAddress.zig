//! Generated from: contact-picker.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ContactAddressImpl = @import("impls").ContactAddress;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const ContactAddress = struct {
    pub const Meta = struct {
        pub const name = "ContactAddress";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            city: typedefs.DOMString = undefined,
            country: typedefs.DOMString = undefined,
            dependentLocality: typedefs.DOMString = undefined,
            organization: typedefs.DOMString = undefined,
            phone: typedefs.DOMString = undefined,
            postalCode: typedefs.DOMString = undefined,
            recipient: typedefs.DOMString = undefined,
            region: typedefs.DOMString = undefined,
            sortingCode: typedefs.DOMString = undefined,
            addressLine: runtime.JSValue = undefined,
            _internal: ?*ContactAddressImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for ContactAddress
    /// Generated from [Default] toJSON extended attribute
    pub const ContactAddressToJSON = struct {
        city: runtime.DOMString,
        country: runtime.DOMString,
        dependentLocality: runtime.DOMString,
        organization: runtime.DOMString,
        phone: runtime.DOMString,
        postalCode: runtime.DOMString,
        recipient: runtime.DOMString,
        region: runtime.DOMString,
        sortingCode: runtime.DOMString,
        addressLine: runtime.JSValue,
    };

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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ContactAddressImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ContactAddressImpl.init(allocator, StateType, vtable_ptr, ctx);
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

    pub fn get_addressLine(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ContactAddressImpl.get_addressLine(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!ContactAddressToJSON {
        return try ContactAddressImpl.call_toJSON(instance);
    }

};
