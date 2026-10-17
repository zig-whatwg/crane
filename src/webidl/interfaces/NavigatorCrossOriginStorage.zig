//! Generated from: cross-origin-storage.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorCrossOriginStorageImpl = @import("impls").NavigatorCrossOriginStorage;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CrossOriginStorageManager = @import("interfaces").CrossOriginStorageManager;

pub const NavigatorCrossOriginStorage = struct {
    pub const Meta = struct {
        pub const name = "NavigatorCrossOriginStorage";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "crossOriginStorage", "get_crossOriginStorage", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "crossOriginStorage", "get_crossOriginStorage", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// [SecureContext] members - their own, their partial interface's or
        /// their mixin's: hidden in a realm that is not a secure context
        /// (WebIDL 3.3.13).
        pub const secure_context_members = .{
            "crossOriginStorage",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            crossOriginStorage: *runtime.Instance = undefined,
            cached_crossOriginStorage: ?*runtime.Instance = null,
            _internal: ?*NavigatorCrossOriginStorageImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "NavigatorCrossOriginStorage")) {
            if (comptime @hasDecl(impls.NavigatorCrossOriginStorage, "installHooks")) impls.NavigatorCrossOriginStorage.installHooks();
        }
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_crossOriginStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_crossOriginStorage) |cached| {
            return cached;
        }
        const value = try NavigatorCrossOriginStorageImpl.get_crossOriginStorage(instance);
        state.own.cached_crossOriginStorage = value;
        @import("dom").same_object_cache.made(instance, value, "crossOriginStorage");
        return value;
    }
};
