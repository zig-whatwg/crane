//! Generated from: edit-context.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TextFormatImpl = @import("impls").TextFormat;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const TextFormatInit = @import("dictionaries").TextFormatInit;
const UnderlineThickness = @import("enums").UnderlineThickness;
const UnderlineStyle = @import("enums").UnderlineStyle;

pub const TextFormat = struct {
    pub const Meta = struct {
        pub const name = "TextFormat";
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
            .{ "rangeStart", "get_rangeStart", null },
            .{ "rangeEnd", "get_rangeEnd", null },
            .{ "underlineStyle", "get_underlineStyle", null },
            .{ "underlineThickness", "get_underlineThickness", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "rangeStart", "get_rangeStart", null },
            .{ "rangeEnd", "get_rangeEnd", null },
            .{ "underlineStyle", "get_underlineStyle", null },
            .{ "underlineThickness", "get_underlineThickness", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            rangeStart: u32 = undefined,
            rangeEnd: u32 = undefined,
            underlineStyle: enums.UnderlineStyle = undefined,
            underlineThickness: enums.UnderlineThickness = undefined,
            _internal: ?*TextFormatImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_rangeEnd = &get_rangeEnd,
        .get_rangeStart = &get_rangeStart,
        .get_underlineStyle = &get_underlineStyle,
        .get_underlineThickness = &get_underlineThickness,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("TextFormat has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(TextFormatImpl, "init") and @hasDecl(TextFormatImpl, "initOwn")) @compileError("TextFormatImpl defines both init and initOwn");
        if (comptime @hasDecl(TextFormatImpl, "init")) return TextFormatImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(TextFormatImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try TextFormatImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TextFormatImpl, "init")) return false;
        if (comptime @hasDecl(TextFormatImpl, "construction_args")) {
            inline for (TextFormatImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(TextFormatImpl, "deinit") and @hasDecl(TextFormatImpl, "deinitOwn")) @compileError("TextFormatImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(TextFormatImpl, "deinit")) return TextFormatImpl.deinit(instance);
        if (comptime @hasDecl(TextFormatImpl, "deinitOwn")) TextFormatImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "TextFormat")) {
            if (comptime @hasDecl(impls.TextFormat, "installHooks")) impls.TextFormat.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, options: webidl.Opt(TextFormatInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TextFormatImpl.call_constructor(ctx, options);
    }

    pub fn get_rangeStart(instance: *runtime.Instance) anyerror!u32 {
        return try TextFormatImpl.get_rangeStart(instance);
    }

    pub fn get_rangeEnd(instance: *runtime.Instance) anyerror!u32 {
        return try TextFormatImpl.get_rangeEnd(instance);
    }

    pub fn get_underlineStyle(instance: *runtime.Instance) anyerror!UnderlineStyle {
        return try TextFormatImpl.get_underlineStyle(instance);
    }

    pub fn get_underlineThickness(instance: *runtime.Instance) anyerror!UnderlineThickness {
        return try TextFormatImpl.get_underlineThickness(instance);
    }
};
