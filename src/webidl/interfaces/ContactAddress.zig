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
        pub const inherited_methods = .{};

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
        pub const lazy_properties = .{};

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

        pub const default_to_json = true;
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
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("ContactAddress has no construction argument '" ++ field_name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(ContactAddressImpl, "init") and @hasDecl(ContactAddressImpl, "initOwn")) @compileError("ContactAddressImpl defines both init and initOwn");
        if (comptime @hasDecl(ContactAddressImpl, "init")) return ContactAddressImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ContactAddressImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ContactAddressImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ContactAddressImpl, "init")) return false;
        if (comptime @hasDecl(ContactAddressImpl, "construction_args")) {
            inline for (ContactAddressImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(ContactAddressImpl, "deinit") and @hasDecl(ContactAddressImpl, "deinitOwn")) @compileError("ContactAddressImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ContactAddressImpl, "deinit")) return ContactAddressImpl.deinit(instance);
        if (comptime @hasDecl(ContactAddressImpl, "deinitOwn")) ContactAddressImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ContactAddress")) {
            if (comptime @hasDecl(impls.ContactAddress, "installHooks")) impls.ContactAddress.installHooks();
        }
    }

    pub fn get_city(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ContactAddressImpl.get_city(instance);
    }

    pub fn get_country(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ContactAddressImpl.get_country(instance);
    }

    pub fn get_dependentLocality(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ContactAddressImpl.get_dependentLocality(instance);
    }

    pub fn get_organization(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ContactAddressImpl.get_organization(instance);
    }

    pub fn get_phone(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ContactAddressImpl.get_phone(instance);
    }

    pub fn get_postalCode(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ContactAddressImpl.get_postalCode(instance);
    }

    pub fn get_recipient(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ContactAddressImpl.get_recipient(instance);
    }

    pub fn get_region(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ContactAddressImpl.get_region(instance);
    }

    pub fn get_sortingCode(instance: *runtime.Instance) anyerror!runtime.DOMString {
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
