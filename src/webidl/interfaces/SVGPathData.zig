//! Generated from: svg-paths.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGPathDataImpl = @import("impls").SVGPathData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGPathDataSettings = @import("dictionaries").SVGPathDataSettings;
const SVGPathSegment = @import("interfaces").SVGPathSegment;

pub const SVGPathData = struct {
    pub const Meta = struct {
        pub const name = "SVGPathData";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getPathData", "call_getPathData", 0 },
            .{ "setPathData", "call_setPathData", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getPathData",
            "setPathData",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*SVGPathDataImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SVGPathData")) {
            if (comptime @hasDecl(impls.SVGPathData, "installHooks")) impls.SVGPathData.installHooks();
        }
    }

    pub fn call_setPathData(instance: *runtime.Instance, pathData: runtime.JSValue) anyerror!void {
        return try SVGPathDataImpl.call_setPathData(instance, pathData);
    }

    pub fn call_getPathData(instance: *runtime.Instance, settings: webidl.Opt(SVGPathDataSettings)) anyerror!runtime.JSValue {
        return try SVGPathDataImpl.call_getPathData(instance, settings);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_setPathData", 0, "SVGPathSegment" },
    };
};
