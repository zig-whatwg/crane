//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasUserInterfaceImpl = @import("impls").CanvasUserInterface;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;
const Path2D = @import("interfaces").Path2D;

pub const CanvasUserInterface = struct {
    pub const Meta = struct {
        pub const name = "CanvasUserInterface";
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
            .{ "drawFocusIfNeeded", "call_drawFocusIfNeeded", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "drawFocusIfNeeded",
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
            _internal: ?*CanvasUserInterfaceImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CanvasUserInterface")) {
            if (comptime @hasDecl(impls.CanvasUserInterface, "installHooks")) impls.CanvasUserInterface.installHooks();
        }
    }

    pub fn call_drawFocusIfNeeded(instance: *runtime.Instance, element: *runtime.Instance) anyerror!void {
        return try CanvasUserInterfaceImpl.call_drawFocusIfNeeded(instance, element);
    }

    pub fn call_drawFocusIfNeeded__1(instance: *runtime.Instance, path: *runtime.Instance, element: *runtime.Instance) anyerror!void {
        if (comptime @hasDecl(CanvasUserInterfaceImpl, "call_drawFocusIfNeeded__1")) {
            return try CanvasUserInterfaceImpl.call_drawFocusIfNeeded__1(instance, path, element);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "drawFocusIfNeeded", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_drawFocusIfNeeded", .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Element")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Element.State) } else .other)} }} },
            .{ .function = "call_drawFocusIfNeeded__1", .implemented = @hasDecl(CanvasUserInterfaceImpl, "call_drawFocusIfNeeded__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Path2D")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Path2D.State) } else .other)} }, .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Element")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Element.State) } else .other)} } } },
        } },
    };

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_drawFocusIfNeeded", 0, "Element" },
        .{ "call_drawFocusIfNeeded__1", 0, "Path2D" },
        .{ "call_drawFocusIfNeeded__1", 1, "Element" },
    };
};
