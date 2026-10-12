//! Generated from: EXT_blend_minmax.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const EXT_blend_minmaxImpl = @import("impls").EXT_blend_minmax;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GLenum = @import("typedefs").GLenum;

pub const EXT_blend_minmax = struct {
    pub const Meta = struct {
        pub const name = "EXT_blend_minmax";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "MIN_EXT", "get_MIN_EXT" },
            .{ "MAX_EXT", "get_MAX_EXT" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

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
            _internal: ?*EXT_blend_minmaxImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum MIN_EXT = 32775;
    pub fn get_MIN_EXT() GLenum {
        return 32775;
    }

    /// WebIDL constant: const GLenum MAX_EXT = 32776;
    pub fn get_MAX_EXT() GLenum {
        return 32776;
    }

    const delegates = .{
        .get_MAX_EXT = &get_MAX_EXT,
        .get_MIN_EXT = &get_MIN_EXT,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("EXT_blend_minmax has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(EXT_blend_minmaxImpl, "init") and @hasDecl(EXT_blend_minmaxImpl, "initOwn")) @compileError("EXT_blend_minmaxImpl defines both init and initOwn");
        if (comptime @hasDecl(EXT_blend_minmaxImpl, "init")) return EXT_blend_minmaxImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(EXT_blend_minmaxImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try EXT_blend_minmaxImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(EXT_blend_minmaxImpl, "init")) return false;
        if (comptime @hasDecl(EXT_blend_minmaxImpl, "construction_args")) {
            inline for (EXT_blend_minmaxImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(EXT_blend_minmaxImpl, "deinit") and @hasDecl(EXT_blend_minmaxImpl, "deinitOwn")) @compileError("EXT_blend_minmaxImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(EXT_blend_minmaxImpl, "deinit")) return EXT_blend_minmaxImpl.deinit(instance);
        if (comptime @hasDecl(EXT_blend_minmaxImpl, "deinitOwn")) EXT_blend_minmaxImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "EXT_blend_minmax")) {
            if (comptime @hasDecl(impls.EXT_blend_minmax, "installHooks")) impls.EXT_blend_minmax.installHooks();
        }
    }
};
