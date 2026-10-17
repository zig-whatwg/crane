//! Generated from: SVG.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGAngleImpl = @import("impls").SVGAngle;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const SVGAngle = struct {
    pub const Meta = struct {
        pub const name = "SVGAngle";
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
            .{ "unitType", "get_unitType", null },
            .{ "value", "get_value", "set_value" },
            .{ "valueInSpecifiedUnits", "get_valueInSpecifiedUnits", "set_valueInSpecifiedUnits" },
            .{ "valueAsString", "get_valueAsString", "set_valueAsString" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "newValueSpecifiedUnits", "call_newValueSpecifiedUnits", 2 },
            .{ "convertToSpecifiedUnits", "call_convertToSpecifiedUnits", 1 },
        };

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "SVG_ANGLETYPE_UNKNOWN", "get_SVG_ANGLETYPE_UNKNOWN" },
            .{ "SVG_ANGLETYPE_UNSPECIFIED", "get_SVG_ANGLETYPE_UNSPECIFIED" },
            .{ "SVG_ANGLETYPE_DEG", "get_SVG_ANGLETYPE_DEG" },
            .{ "SVG_ANGLETYPE_RAD", "get_SVG_ANGLETYPE_RAD" },
            .{ "SVG_ANGLETYPE_GRAD", "get_SVG_ANGLETYPE_GRAD" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "newValueSpecifiedUnits",
            "convertToSpecifiedUnits",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "unitType", "get_unitType", null },
            .{ "value", "get_value", "set_value" },
            .{ "valueInSpecifiedUnits", "get_valueInSpecifiedUnits", "set_valueInSpecifiedUnits" },
            .{ "valueAsString", "get_valueAsString", "set_valueAsString" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            unitType: u16 = undefined,
            value: f32 = undefined,
            valueInSpecifiedUnits: f32 = undefined,
            valueAsString: runtime.DOMString = undefined,
            _internal: ?*SVGAngleImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short SVG_ANGLETYPE_UNKNOWN = 0;
    pub fn get_SVG_ANGLETYPE_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_ANGLETYPE_UNSPECIFIED = 1;
    pub fn get_SVG_ANGLETYPE_UNSPECIFIED() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_ANGLETYPE_DEG = 2;
    pub fn get_SVG_ANGLETYPE_DEG() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short SVG_ANGLETYPE_RAD = 3;
    pub fn get_SVG_ANGLETYPE_RAD() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short SVG_ANGLETYPE_GRAD = 4;
    pub fn get_SVG_ANGLETYPE_GRAD() u16 {
        return 4;
    }

    const delegates = .{
        .get_SVG_ANGLETYPE_DEG = &get_SVG_ANGLETYPE_DEG,
        .get_SVG_ANGLETYPE_GRAD = &get_SVG_ANGLETYPE_GRAD,
        .get_SVG_ANGLETYPE_RAD = &get_SVG_ANGLETYPE_RAD,
        .get_SVG_ANGLETYPE_UNKNOWN = &get_SVG_ANGLETYPE_UNKNOWN,
        .get_SVG_ANGLETYPE_UNSPECIFIED = &get_SVG_ANGLETYPE_UNSPECIFIED,
        .get_unitType = &get_unitType,
        .get_value = &get_value,
        .get_valueAsString = &get_valueAsString,
        .get_valueInSpecifiedUnits = &get_valueInSpecifiedUnits,

        .set_value = &set_value,
        .set_valueAsString = &set_valueAsString,
        .set_valueInSpecifiedUnits = &set_valueInSpecifiedUnits,

        .call_convertToSpecifiedUnits = &call_convertToSpecifiedUnits,
        .call_newValueSpecifiedUnits = &call_newValueSpecifiedUnits,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("SVGAngle has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SVGAngleImpl, "init") and @hasDecl(SVGAngleImpl, "initOwn")) @compileError("SVGAngleImpl defines both init and initOwn");
        if (comptime @hasDecl(SVGAngleImpl, "init")) return SVGAngleImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(SVGAngleImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try SVGAngleImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SVGAngleImpl, "init")) return false;
        if (comptime @hasDecl(SVGAngleImpl, "construction_args")) {
            inline for (SVGAngleImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SVGAngleImpl, "deinit") and @hasDecl(SVGAngleImpl, "deinitOwn")) @compileError("SVGAngleImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SVGAngleImpl, "deinit")) return SVGAngleImpl.deinit(instance);
        if (comptime @hasDecl(SVGAngleImpl, "deinitOwn")) SVGAngleImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SVGAngle")) {
            if (comptime @hasDecl(impls.SVGAngle, "installHooks")) impls.SVGAngle.installHooks();
        }
    }

    pub fn get_unitType(instance: *runtime.Instance) anyerror!u16 {
        return try SVGAngleImpl.get_unitType(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!f32 {
        return try SVGAngleImpl.get_value(instance);
    }

    pub fn set_value(instance: *runtime.Instance, value: f32) anyerror!void {
        try SVGAngleImpl.set_value(instance, value);
    }

    pub fn get_valueInSpecifiedUnits(instance: *runtime.Instance) anyerror!f32 {
        return try SVGAngleImpl.get_valueInSpecifiedUnits(instance);
    }

    pub fn set_valueInSpecifiedUnits(instance: *runtime.Instance, value: f32) anyerror!void {
        try SVGAngleImpl.set_valueInSpecifiedUnits(instance, value);
    }

    pub fn get_valueAsString(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try SVGAngleImpl.get_valueAsString(instance);
    }

    pub fn set_valueAsString(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try SVGAngleImpl.set_valueAsString(instance, value);
    }

    pub fn call_newValueSpecifiedUnits(instance: *runtime.Instance, unitType: u16, valueInSpecifiedUnits: f32) anyerror!void {
        return try SVGAngleImpl.call_newValueSpecifiedUnits(instance, unitType, valueInSpecifiedUnits);
    }

    pub fn call_convertToSpecifiedUnits(instance: *runtime.Instance, unitType: u16) anyerror!void {
        return try SVGAngleImpl.call_convertToSpecifiedUnits(instance, unitType);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_value", 0b1 },
        .{ "set_valueInSpecifiedUnits", 0b1 },
        .{ "call_newValueSpecifiedUnits", 0b10 },
    };
};
