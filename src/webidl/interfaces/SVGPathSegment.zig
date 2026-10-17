//! Generated from: svg-paths.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGPathSegmentImpl = @import("impls").SVGPathSegment;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const SVGPathSegment = struct {
    pub const Meta = struct {
        pub const name = "SVGPathSegment";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "LegacyNoInterfaceObject" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", "set_type" },
            .{ "values", "get_values", "set_values" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", "set_type" },
            .{ "values", "get_values", "set_values" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            type: runtime.DOMString = undefined,
            values: runtime.JSValue = undefined,
            _internal: ?*SVGPathSegmentImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_type = &get_type,
        .get_values = &get_values,

        .set_type = &set_type,
        .set_values = &set_values,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SVGPathSegment has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SVGPathSegmentImpl, "init") and @hasDecl(SVGPathSegmentImpl, "initOwn")) @compileError("SVGPathSegmentImpl defines both init and initOwn");
        if (comptime @hasDecl(SVGPathSegmentImpl, "init")) return SVGPathSegmentImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(SVGPathSegmentImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try SVGPathSegmentImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SVGPathSegmentImpl, "init")) return false;
        if (comptime @hasDecl(SVGPathSegmentImpl, "construction_args")) {
            inline for (SVGPathSegmentImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SVGPathSegmentImpl, "deinit") and @hasDecl(SVGPathSegmentImpl, "deinitOwn")) @compileError("SVGPathSegmentImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SVGPathSegmentImpl, "deinit")) return SVGPathSegmentImpl.deinit(instance);
        if (comptime @hasDecl(SVGPathSegmentImpl, "deinitOwn")) SVGPathSegmentImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SVGPathSegment")) {
            if (comptime @hasDecl(impls.SVGPathSegment, "installHooks")) impls.SVGPathSegment.installHooks();
        }
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try SVGPathSegmentImpl.get_type(instance);
    }

    pub fn set_type(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try SVGPathSegmentImpl.set_type(instance, value);
    }

    pub fn get_values(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try SVGPathSegmentImpl.get_values(instance);
    }

    pub fn set_values(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try SVGPathSegmentImpl.set_values(instance, value);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_values", 0b1 },
    };
};
