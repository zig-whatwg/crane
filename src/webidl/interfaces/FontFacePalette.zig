//! Generated from: css-font-loading.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FontFacePaletteImpl = @import("impls").FontFacePalette;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const FontFacePalette = struct {
    pub const Meta = struct {
        pub const name = "FontFacePalette";
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
            .{ "length", "get_length", null },
            .{ "usableWithLightBackground", "get_usableWithLightBackground", null },
            .{ "usableWithDarkBackground", "get_usableWithDarkBackground", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
            .{ "usableWithLightBackground", "get_usableWithLightBackground", null },
            .{ "usableWithDarkBackground", "get_usableWithDarkBackground", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_getter", .implemented = @hasDecl(FontFacePaletteImpl, "call_getter") },
        };

        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "runtime.DOMString",
            .key_type = null,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            usableWithLightBackground: bool = undefined,
            usableWithDarkBackground: bool = undefined,
            _internal: ?*FontFacePaletteImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,
        .get_usableWithDarkBackground = &get_usableWithDarkBackground,
        .get_usableWithLightBackground = &get_usableWithLightBackground,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("FontFacePalette has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(FontFacePaletteImpl, "init") and @hasDecl(FontFacePaletteImpl, "initOwn")) @compileError("FontFacePaletteImpl defines both init and initOwn");
        if (comptime @hasDecl(FontFacePaletteImpl, "init")) return FontFacePaletteImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(FontFacePaletteImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try FontFacePaletteImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(FontFacePaletteImpl, "init")) return false;
        if (comptime @hasDecl(FontFacePaletteImpl, "construction_args")) {
            inline for (FontFacePaletteImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(FontFacePaletteImpl, "deinit") and @hasDecl(FontFacePaletteImpl, "deinitOwn")) @compileError("FontFacePaletteImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(FontFacePaletteImpl, "deinit")) return FontFacePaletteImpl.deinit(instance);
        if (comptime @hasDecl(FontFacePaletteImpl, "deinitOwn")) FontFacePaletteImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "FontFacePalette")) {
            if (comptime @hasDecl(impls.FontFacePalette, "installHooks")) impls.FontFacePalette.installHooks();
        }
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try FontFacePaletteImpl.get_length(instance);
    }

    pub fn get_usableWithLightBackground(instance: *runtime.Instance) anyerror!bool {
        return try FontFacePaletteImpl.get_usableWithLightBackground(instance);
    }

    pub fn get_usableWithDarkBackground(instance: *runtime.Instance) anyerror!bool {
        return try FontFacePaletteImpl.get_usableWithDarkBackground(instance);
    }

    pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!runtime.DOMString {
        if (comptime @hasDecl(FontFacePaletteImpl, "call_getter")) {
            return try FontFacePaletteImpl.call_getter(instance, index);
        } else {
            return error.NotImplemented;
        }
    }
};
