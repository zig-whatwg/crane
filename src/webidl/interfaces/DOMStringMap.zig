//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DOMStringMapImpl = @import("impls").DOMStringMap;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const DOMStringMap = struct {
    pub const Meta = struct {
        pub const name = "DOMStringMap";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "LegacyOverrideBuiltIns" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .named_getter = .{ .function = "call_getter", .implemented = @hasDecl(DOMStringMapImpl, "call_getter") },
            .named_setter = .{ .function = "call_setter", .implemented = @hasDecl(DOMStringMapImpl, "call_setter") },
            .named_deleter = .{ .function = "call_deleter", .implemented = @hasDecl(DOMStringMapImpl, "call_deleter") },
            .legacy_override_built_ins = true,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*DOMStringMapImpl.InternalState = null,
        },
    );

    const delegates = .{
        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DOMStringMapImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return DOMStringMapImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMStringMapImpl.deinit(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "DOMStringMap")) {
            if (comptime @hasDecl(impls.DOMStringMap, "installHooks")) impls.DOMStringMap.installHooks();
        }
    }

    pub fn call_getter(instance: *runtime.Instance, name: DOMString) anyerror!DOMString {
        if (comptime @hasDecl(DOMStringMapImpl, "call_getter")) {
            return try DOMStringMapImpl.call_getter(instance, name);
        } else {
            return error.NotImplemented;
        }
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setter(instance: *runtime.Instance, name: DOMString, value: DOMString) anyerror!void {
        if (comptime @hasDecl(DOMStringMapImpl, "call_setter")) {
            // [CEReactions] - Trigger Custom Element lifecycle callbacks
            const ce_scope = runtime.CEReactions.begin(instance);
            defer runtime.CEReactions.end(ce_scope);

            return try DOMStringMapImpl.call_setter(instance, name, value);
        } else {
            return error.NotImplemented;
        }
    }

    /// Extended attributes: [CEReactions]
    pub fn call_deleter(instance: *runtime.Instance, name: DOMString) anyerror!void {
        if (comptime @hasDecl(DOMStringMapImpl, "call_deleter")) {
            // [CEReactions] - Trigger Custom Element lifecycle callbacks
            const ce_scope = runtime.CEReactions.begin(instance);
            defer runtime.CEReactions.end(ce_scope);

            return try DOMStringMapImpl.call_deleter(instance, name);
        } else {
            return error.NotImplemented;
        }
    }

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "call_setter",
        "call_deleter",
    };

    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return DOMStringMapImpl.getSupportedPropertyNames(instance, allocator);
    }
};
