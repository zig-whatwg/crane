//! Generated from: font-metrics-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FontMetricsImpl = @import("impls").FontMetrics;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Font = @import("interfaces").Font;
const Baseline = @import("interfaces").Baseline;

pub const FontMetrics = struct {
    pub const Meta = struct {
        pub const name = "FontMetrics";
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
            .{ "width", "get_width", null },
            .{ "advances", "get_advances", null },
            .{ "boundingBoxLeft", "get_boundingBoxLeft", null },
            .{ "boundingBoxRight", "get_boundingBoxRight", null },
            .{ "height", "get_height", null },
            .{ "emHeightAscent", "get_emHeightAscent", null },
            .{ "emHeightDescent", "get_emHeightDescent", null },
            .{ "boundingBoxAscent", "get_boundingBoxAscent", null },
            .{ "boundingBoxDescent", "get_boundingBoxDescent", null },
            .{ "fontBoundingBoxAscent", "get_fontBoundingBoxAscent", null },
            .{ "fontBoundingBoxDescent", "get_fontBoundingBoxDescent", null },
            .{ "dominantBaseline", "get_dominantBaseline", null },
            .{ "baselines", "get_baselines", null },
            .{ "fonts", "get_fonts", null },
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
            .{ "advances", "get_advances", null },
            .{ "boundingBoxLeft", "get_boundingBoxLeft", null },
            .{ "boundingBoxRight", "get_boundingBoxRight", null },
            .{ "height", "get_height", null },
            .{ "emHeightAscent", "get_emHeightAscent", null },
            .{ "emHeightDescent", "get_emHeightDescent", null },
            .{ "boundingBoxAscent", "get_boundingBoxAscent", null },
            .{ "boundingBoxDescent", "get_boundingBoxDescent", null },
            .{ "fontBoundingBoxAscent", "get_fontBoundingBoxAscent", null },
            .{ "fontBoundingBoxDescent", "get_fontBoundingBoxDescent", null },
            .{ "dominantBaseline", "get_dominantBaseline", null },
            .{ "baselines", "get_baselines", null },
            .{ "fonts", "get_fonts", null },
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
            advances: runtime.JSValue = undefined,
            boundingBoxLeft: f64 = undefined,
            boundingBoxRight: f64 = undefined,
            height: f64 = undefined,
            emHeightAscent: f64 = undefined,
            emHeightDescent: f64 = undefined,
            boundingBoxAscent: f64 = undefined,
            boundingBoxDescent: f64 = undefined,
            fontBoundingBoxAscent: f64 = undefined,
            fontBoundingBoxDescent: f64 = undefined,
            dominantBaseline: *runtime.Instance = undefined,
            baselines: runtime.JSValue = undefined,
            fonts: runtime.JSValue = undefined,
            _internal: ?*FontMetricsImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_advances = &get_advances,
        .get_baselines = &get_baselines,
        .get_boundingBoxAscent = &get_boundingBoxAscent,
        .get_boundingBoxDescent = &get_boundingBoxDescent,
        .get_boundingBoxLeft = &get_boundingBoxLeft,
        .get_boundingBoxRight = &get_boundingBoxRight,
        .get_dominantBaseline = &get_dominantBaseline,
        .get_emHeightAscent = &get_emHeightAscent,
        .get_emHeightDescent = &get_emHeightDescent,
        .get_fontBoundingBoxAscent = &get_fontBoundingBoxAscent,
        .get_fontBoundingBoxDescent = &get_fontBoundingBoxDescent,
        .get_fonts = &get_fonts,
        .get_height = &get_height,
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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("FontMetrics has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(FontMetricsImpl, "init") and @hasDecl(FontMetricsImpl, "initOwn")) @compileError("FontMetricsImpl defines both init and initOwn");
        if (comptime @hasDecl(FontMetricsImpl, "init")) return FontMetricsImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(FontMetricsImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try FontMetricsImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(FontMetricsImpl, "init")) return false;
        if (comptime @hasDecl(FontMetricsImpl, "construction_args")) {
            inline for (FontMetricsImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(FontMetricsImpl, "deinit") and @hasDecl(FontMetricsImpl, "deinitOwn")) @compileError("FontMetricsImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(FontMetricsImpl, "deinit")) return FontMetricsImpl.deinit(instance);
        if (comptime @hasDecl(FontMetricsImpl, "deinitOwn")) FontMetricsImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "FontMetrics")) {
            if (comptime @hasDecl(impls.FontMetrics, "installHooks")) impls.FontMetrics.installHooks();
        }
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_width(instance);
    }

    pub fn get_advances(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try FontMetricsImpl.get_advances(instance);
    }

    pub fn get_boundingBoxLeft(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_boundingBoxLeft(instance);
    }

    pub fn get_boundingBoxRight(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_boundingBoxRight(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_height(instance);
    }

    pub fn get_emHeightAscent(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_emHeightAscent(instance);
    }

    pub fn get_emHeightDescent(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_emHeightDescent(instance);
    }

    pub fn get_boundingBoxAscent(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_boundingBoxAscent(instance);
    }

    pub fn get_boundingBoxDescent(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_boundingBoxDescent(instance);
    }

    pub fn get_fontBoundingBoxAscent(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_fontBoundingBoxAscent(instance);
    }

    pub fn get_fontBoundingBoxDescent(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_fontBoundingBoxDescent(instance);
    }

    pub fn get_dominantBaseline(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try FontMetricsImpl.get_dominantBaseline(instance);
    }

    pub fn get_baselines(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try FontMetricsImpl.get_baselines(instance);
    }

    pub fn get_fonts(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try FontMetricsImpl.get_fonts(instance);
    }
};
