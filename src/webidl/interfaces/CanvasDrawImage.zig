//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasDrawImageImpl = @import("impls").CanvasDrawImage;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CanvasImageSource = @import("typedefs").CanvasImageSource;

pub const CanvasDrawImage = struct {
    pub const Meta = struct {
        pub const name = "CanvasDrawImage";
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
            .{ "drawImage", "call_drawImage", 3 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "drawImage",
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
            _internal: ?*CanvasDrawImageImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_drawImage = &call_drawImage,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasDrawImageImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CanvasDrawImageImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasDrawImageImpl.deinit(instance);
    }

    pub fn call_drawImage(instance: *runtime.Instance, image: CanvasImageSource, dx: f64, dy: f64) anyerror!void {
        return try CanvasDrawImageImpl.call_drawImage(instance, image, dx, dy);
    }

    pub fn call_drawImage__1(instance: *runtime.Instance, image: CanvasImageSource, dx: f64, dy: f64, dw: f64, dh: f64) anyerror!void {
        if (comptime @hasDecl(CanvasDrawImageImpl, "call_drawImage__1")) {
            return try CanvasDrawImageImpl.call_drawImage__1(instance, image, dx, dy, dw, dh);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_drawImage__2(instance: *runtime.Instance, image: CanvasImageSource, sx: f64, sy: f64, sw: f64, sh: f64, dx: f64, dy: f64, dw: f64, dh: f64) anyerror!void {
        if (comptime @hasDecl(CanvasDrawImageImpl, "call_drawImage__2")) {
            return try CanvasDrawImageImpl.call_drawImage__2(instance, image, sx, sy, sw, sh, dx, dy, dw, dh);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "drawImage", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_drawImage", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
            .{ .function = "call_drawImage__1", .implemented = @hasDecl(CanvasDrawImageImpl, "call_drawImage__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
            .{ .function = "call_drawImage__2", .implemented = @hasDecl(CanvasDrawImageImpl, "call_drawImage__2"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        } },
    };
};
