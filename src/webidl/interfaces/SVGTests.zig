//! Generated from: SVG.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGTestsImpl = @import("impls").SVGTests;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGStringList = @import("interfaces").SVGStringList;

pub const SVGTests = struct {
    pub const Meta = struct {
        pub const name = "SVGTests";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "requiredExtensions", "get_requiredExtensions", null },
            .{ "systemLanguage", "get_systemLanguage", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "requiredExtensions", "get_requiredExtensions", null },
            .{ "systemLanguage", "get_systemLanguage", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            requiredExtensions: *runtime.Instance = undefined,
            systemLanguage: *runtime.Instance = undefined,
            cached_requiredExtensions: ?*runtime.Instance = null,
            cached_systemLanguage: ?*runtime.Instance = null,
            _internal: ?*SVGTestsImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SVGTests")) {
            if (comptime @hasDecl(impls.SVGTests, "installHooks")) impls.SVGTests.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_requiredExtensions(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_requiredExtensions) |cached| {
            return cached;
        }
        const value = try SVGTestsImpl.get_requiredExtensions(instance);
        state.own.cached_requiredExtensions = value;
        @import("dom").same_object_cache.made(instance, value, "requiredExtensions");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_systemLanguage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_systemLanguage) |cached| {
            return cached;
        }
        const value = try SVGTestsImpl.get_systemLanguage(instance);
        state.own.cached_systemLanguage = value;
        @import("dom").same_object_cache.made(instance, value, "systemLanguage");
        return value;
    }
};
