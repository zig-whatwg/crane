//! Generated from: contact-picker.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ContactsManagerImpl = @import("impls").ContactsManager;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ContactProperty = @import("enums").ContactProperty;
const ContactsSelectOptions = @import("dictionaries").ContactsSelectOptions;

pub const ContactsManager = struct {
    pub const Meta = struct {
        pub const name = "ContactsManager";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getProperties", "call_getProperties", 0 },
            .{ "select", "call_select", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getProperties",
            "select",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*ContactsManagerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_getProperties = &call_getProperties,
        .call_select = &call_select,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ContactsManagerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ContactsManagerImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ContactsManagerImpl.deinit(instance);
    }

    pub fn call_select(instance: *runtime.Instance, properties: runtime.JSValue, options: webidl.Opt(ContactsSelectOptions)) anyerror!runtime.JSValue {
        
        return try ContactsManagerImpl.call_select(instance, properties, options);
    }

    pub fn call_getProperties(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ContactsManagerImpl.call_getProperties(instance);
    }

};
