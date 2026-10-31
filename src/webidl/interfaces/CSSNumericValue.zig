//! Generated from: css-typed-om.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSNumericValueImpl = @import("impls").CSSNumericValue;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSUnitValue = @import("interfaces").CSSUnitValue;
const CSSMathSum = @import("interfaces").CSSMathSum;
const CSSNumericType = @import("dictionaries").CSSNumericType;
const CSSNumberish = @import("typedefs").CSSNumberish;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSNumericValue = struct {
    pub const Meta = struct {
        pub const name = "CSSNumericValue";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSStyleValue.State;
        pub const ParentInterface = CSSStyleValue;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "PaintWorklet", "LayoutWorklet" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .PaintWorklet = true,
            .LayoutWorklet = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "add", "call_add", 0 },
            .{ "sub", "call_sub", 0 },
            .{ "mul", "call_mul", 0 },
            .{ "div", "call_div", 0 },
            .{ "min", "call_min", 0 },
            .{ "max", "call_max", 0 },
            .{ "equals", "call_equals", 0 },
            .{ "to", "call_to", 1 },
            .{ "toSum", "call_toSum", 0 },
            .{ "type", "call_type", 0 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "parse", "call_static_parse", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "add",
            "sub",
            "mul",
            "div",
            "min",
            "max",
            "equals",
            "to",
            "toSum",
            "type",
            "parse",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "parseAll",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
        /// Member-level [Exposed] overrides; unlisted members inherit the interface.
        pub const exposed_static_members = .{
            .{ "parse", .{"Window"} },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*CSSNumericValueImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_add = &call_add,
        .call_div = &call_div,
        .call_equals = &call_equals,
        .call_max = &call_max,
        .call_min = &call_min,
        .call_mul = &call_mul,
        .call_sub = &call_sub,
        .call_to = &call_to,
        .call_toSum = &call_toSum,
        .call_type = &call_type,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("CSSNumericValue has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(CSSNumericValueImpl, "init") and @hasDecl(CSSNumericValueImpl, "initOwn")) @compileError("CSSNumericValueImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSNumericValueImpl, "init")) return CSSNumericValueImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CSSNumericValueImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CSSNumericValueImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSNumericValueImpl, "init")) return false;
        if (comptime @hasDecl(CSSNumericValueImpl, "construction_args")) {
            inline for (CSSNumericValueImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(CSSNumericValueImpl, "deinit") and @hasDecl(CSSNumericValueImpl, "deinitOwn")) @compileError("CSSNumericValueImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSNumericValueImpl, "deinit")) return CSSNumericValueImpl.deinit(instance);
        if (comptime @hasDecl(CSSNumericValueImpl, "deinitOwn")) CSSNumericValueImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSNumericValue")) {
            if (comptime @hasDecl(impls.CSSNumericValue, "installHooks")) impls.CSSNumericValue.installHooks();
        }
    }

    pub fn call_toSum(instance: *runtime.Instance, units: []const runtime.USVString) anyerror!*runtime.Instance {
        return try CSSNumericValueImpl.call_toSum(instance, units);
    }

    pub fn call_sub(instance: *runtime.Instance, values: []const CSSNumberish) anyerror!*runtime.Instance {
        return try CSSNumericValueImpl.call_sub(instance, values);
    }

    pub fn call_equals(instance: *runtime.Instance, value: []const CSSNumberish) anyerror!bool {
        return try CSSNumericValueImpl.call_equals(instance, value);
    }

    pub fn call_to(instance: *runtime.Instance, unit: runtime.USVString) anyerror!*runtime.Instance {
        return try CSSNumericValueImpl.call_to(instance, unit);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_static_parse(instance: *runtime.Instance, cssText: runtime.USVString) anyerror!*runtime.Instance {
        return try CSSNumericValueImpl.call_static_parse(instance, cssText);
    }

    pub fn call_min(instance: *runtime.Instance, values: []const CSSNumberish) anyerror!*runtime.Instance {
        return try CSSNumericValueImpl.call_min(instance, values);
    }

    pub fn call_mul(instance: *runtime.Instance, values: []const CSSNumberish) anyerror!*runtime.Instance {
        return try CSSNumericValueImpl.call_mul(instance, values);
    }

    pub fn call_div(instance: *runtime.Instance, values: []const CSSNumberish) anyerror!*runtime.Instance {
        return try CSSNumericValueImpl.call_div(instance, values);
    }

    pub fn call_max(instance: *runtime.Instance, values: []const CSSNumberish) anyerror!*runtime.Instance {
        return try CSSNumericValueImpl.call_max(instance, values);
    }

    pub fn call_type(instance: *runtime.Instance) anyerror!CSSNumericType {
        return try CSSNumericValueImpl.call_type(instance);
    }

    pub fn call_add(instance: *runtime.Instance, values: []const CSSNumberish) anyerror!*runtime.Instance {
        return try CSSNumericValueImpl.call_add(instance, values);
    }
};
