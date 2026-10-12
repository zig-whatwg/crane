//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TextMetricsImpl = @import("impls").TextMetrics;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const TextMetrics = struct {
    pub const Meta = struct {
        pub const name = "TextMetrics";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "width", "get_width", null },
            .{ "actualBoundingBoxLeft", "get_actualBoundingBoxLeft", null },
            .{ "actualBoundingBoxRight", "get_actualBoundingBoxRight", null },
            .{ "fontBoundingBoxAscent", "get_fontBoundingBoxAscent", null },
            .{ "fontBoundingBoxDescent", "get_fontBoundingBoxDescent", null },
            .{ "actualBoundingBoxAscent", "get_actualBoundingBoxAscent", null },
            .{ "actualBoundingBoxDescent", "get_actualBoundingBoxDescent", null },
            .{ "emHeightAscent", "get_emHeightAscent", null },
            .{ "emHeightDescent", "get_emHeightDescent", null },
            .{ "hangingBaseline", "get_hangingBaseline", null },
            .{ "alphabeticBaseline", "get_alphabeticBaseline", null },
            .{ "ideographicBaseline", "get_ideographicBaseline", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "width", "get_width", null },
            .{ "actualBoundingBoxLeft", "get_actualBoundingBoxLeft", null },
            .{ "actualBoundingBoxRight", "get_actualBoundingBoxRight", null },
            .{ "fontBoundingBoxAscent", "get_fontBoundingBoxAscent", null },
            .{ "fontBoundingBoxDescent", "get_fontBoundingBoxDescent", null },
            .{ "actualBoundingBoxAscent", "get_actualBoundingBoxAscent", null },
            .{ "actualBoundingBoxDescent", "get_actualBoundingBoxDescent", null },
            .{ "emHeightAscent", "get_emHeightAscent", null },
            .{ "emHeightDescent", "get_emHeightDescent", null },
            .{ "hangingBaseline", "get_hangingBaseline", null },
            .{ "alphabeticBaseline", "get_alphabeticBaseline", null },
            .{ "ideographicBaseline", "get_ideographicBaseline", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            width: f64 = undefined,
            actualBoundingBoxLeft: f64 = undefined,
            actualBoundingBoxRight: f64 = undefined,
            fontBoundingBoxAscent: f64 = undefined,
            fontBoundingBoxDescent: f64 = undefined,
            actualBoundingBoxAscent: f64 = undefined,
            actualBoundingBoxDescent: f64 = undefined,
            emHeightAscent: f64 = undefined,
            emHeightDescent: f64 = undefined,
            hangingBaseline: f64 = undefined,
            alphabeticBaseline: f64 = undefined,
            ideographicBaseline: f64 = undefined,
            _internal: ?*TextMetricsImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_actualBoundingBoxAscent = &get_actualBoundingBoxAscent,
        .get_actualBoundingBoxDescent = &get_actualBoundingBoxDescent,
        .get_actualBoundingBoxLeft = &get_actualBoundingBoxLeft,
        .get_actualBoundingBoxRight = &get_actualBoundingBoxRight,
        .get_alphabeticBaseline = &get_alphabeticBaseline,
        .get_emHeightAscent = &get_emHeightAscent,
        .get_emHeightDescent = &get_emHeightDescent,
        .get_fontBoundingBoxAscent = &get_fontBoundingBoxAscent,
        .get_fontBoundingBoxDescent = &get_fontBoundingBoxDescent,
        .get_hangingBaseline = &get_hangingBaseline,
        .get_ideographicBaseline = &get_ideographicBaseline,
        .get_width = &get_width,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("TextMetrics has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(TextMetricsImpl, "init") and @hasDecl(TextMetricsImpl, "initOwn")) @compileError("TextMetricsImpl defines both init and initOwn");
        if (comptime @hasDecl(TextMetricsImpl, "init")) return TextMetricsImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(TextMetricsImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try TextMetricsImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TextMetricsImpl, "init")) return false;
        if (comptime @hasDecl(TextMetricsImpl, "construction_args")) {
            inline for (TextMetricsImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(TextMetricsImpl, "deinit") and @hasDecl(TextMetricsImpl, "deinitOwn")) @compileError("TextMetricsImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(TextMetricsImpl, "deinit")) return TextMetricsImpl.deinit(instance);
        if (comptime @hasDecl(TextMetricsImpl, "deinitOwn")) TextMetricsImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "TextMetrics")) {
            if (comptime @hasDecl(impls.TextMetrics, "installHooks")) impls.TextMetrics.installHooks();
        }
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_width(instance);
    }

    pub fn get_actualBoundingBoxLeft(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_actualBoundingBoxLeft(instance);
    }

    pub fn get_actualBoundingBoxRight(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_actualBoundingBoxRight(instance);
    }

    pub fn get_fontBoundingBoxAscent(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_fontBoundingBoxAscent(instance);
    }

    pub fn get_fontBoundingBoxDescent(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_fontBoundingBoxDescent(instance);
    }

    pub fn get_actualBoundingBoxAscent(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_actualBoundingBoxAscent(instance);
    }

    pub fn get_actualBoundingBoxDescent(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_actualBoundingBoxDescent(instance);
    }

    pub fn get_emHeightAscent(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_emHeightAscent(instance);
    }

    pub fn get_emHeightDescent(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_emHeightDescent(instance);
    }

    pub fn get_hangingBaseline(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_hangingBaseline(instance);
    }

    pub fn get_alphabeticBaseline(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_alphabeticBaseline(instance);
    }

    pub fn get_ideographicBaseline(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_ideographicBaseline(instance);
    }
};
