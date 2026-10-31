//! Generated from: WEBGL_compressed_texture_etc.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WEBGL_compressed_texture_etcImpl = @import("impls").WEBGL_compressed_texture_etc;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GLenum = @import("typedefs").GLenum;

pub const WEBGL_compressed_texture_etc = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_compressed_texture_etc";
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
            .{ "COMPRESSED_R11_EAC", "get_COMPRESSED_R11_EAC" },
            .{ "COMPRESSED_SIGNED_R11_EAC", "get_COMPRESSED_SIGNED_R11_EAC" },
            .{ "COMPRESSED_RG11_EAC", "get_COMPRESSED_RG11_EAC" },
            .{ "COMPRESSED_SIGNED_RG11_EAC", "get_COMPRESSED_SIGNED_RG11_EAC" },
            .{ "COMPRESSED_RGB8_ETC2", "get_COMPRESSED_RGB8_ETC2" },
            .{ "COMPRESSED_SRGB8_ETC2", "get_COMPRESSED_SRGB8_ETC2" },
            .{ "COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2", "get_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2" },
            .{ "COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2", "get_COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2" },
            .{ "COMPRESSED_RGBA8_ETC2_EAC", "get_COMPRESSED_RGBA8_ETC2_EAC" },
            .{ "COMPRESSED_SRGB8_ALPHA8_ETC2_EAC", "get_COMPRESSED_SRGB8_ALPHA8_ETC2_EAC" },
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
            _internal: ?*WEBGL_compressed_texture_etcImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum COMPRESSED_R11_EAC = 37488;
    pub fn get_COMPRESSED_R11_EAC() GLenum {
        return 37488;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SIGNED_R11_EAC = 37489;
    pub fn get_COMPRESSED_SIGNED_R11_EAC() GLenum {
        return 37489;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RG11_EAC = 37490;
    pub fn get_COMPRESSED_RG11_EAC() GLenum {
        return 37490;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SIGNED_RG11_EAC = 37491;
    pub fn get_COMPRESSED_SIGNED_RG11_EAC() GLenum {
        return 37491;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGB8_ETC2 = 37492;
    pub fn get_COMPRESSED_RGB8_ETC2() GLenum {
        return 37492;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ETC2 = 37493;
    pub fn get_COMPRESSED_SRGB8_ETC2() GLenum {
        return 37493;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2 = 37494;
    pub fn get_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2() GLenum {
        return 37494;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2 = 37495;
    pub fn get_COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2() GLenum {
        return 37495;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA8_ETC2_EAC = 37496;
    pub fn get_COMPRESSED_RGBA8_ETC2_EAC() GLenum {
        return 37496;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ETC2_EAC = 37497;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ETC2_EAC() GLenum {
        return 37497;
    }

    const delegates = .{
        .get_COMPRESSED_R11_EAC = &get_COMPRESSED_R11_EAC,
        .get_COMPRESSED_RG11_EAC = &get_COMPRESSED_RG11_EAC,
        .get_COMPRESSED_RGB8_ETC2 = &get_COMPRESSED_RGB8_ETC2,
        .get_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2 = &get_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2,
        .get_COMPRESSED_RGBA8_ETC2_EAC = &get_COMPRESSED_RGBA8_ETC2_EAC,
        .get_COMPRESSED_SIGNED_R11_EAC = &get_COMPRESSED_SIGNED_R11_EAC,
        .get_COMPRESSED_SIGNED_RG11_EAC = &get_COMPRESSED_SIGNED_RG11_EAC,
        .get_COMPRESSED_SRGB8_ALPHA8_ETC2_EAC = &get_COMPRESSED_SRGB8_ALPHA8_ETC2_EAC,
        .get_COMPRESSED_SRGB8_ETC2 = &get_COMPRESSED_SRGB8_ETC2,
        .get_COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2 = &get_COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("WEBGL_compressed_texture_etc has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(WEBGL_compressed_texture_etcImpl, "init") and @hasDecl(WEBGL_compressed_texture_etcImpl, "initOwn")) @compileError("WEBGL_compressed_texture_etcImpl defines both init and initOwn");
        if (comptime @hasDecl(WEBGL_compressed_texture_etcImpl, "init")) return WEBGL_compressed_texture_etcImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(WEBGL_compressed_texture_etcImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try WEBGL_compressed_texture_etcImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WEBGL_compressed_texture_etcImpl, "init")) return false;
        if (comptime @hasDecl(WEBGL_compressed_texture_etcImpl, "construction_args")) {
            inline for (WEBGL_compressed_texture_etcImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(WEBGL_compressed_texture_etcImpl, "deinit") and @hasDecl(WEBGL_compressed_texture_etcImpl, "deinitOwn")) @compileError("WEBGL_compressed_texture_etcImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(WEBGL_compressed_texture_etcImpl, "deinit")) return WEBGL_compressed_texture_etcImpl.deinit(instance);
        if (comptime @hasDecl(WEBGL_compressed_texture_etcImpl, "deinitOwn")) WEBGL_compressed_texture_etcImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "WEBGL_compressed_texture_etc")) {
            if (comptime @hasDecl(impls.WEBGL_compressed_texture_etc, "installHooks")) impls.WEBGL_compressed_texture_etc.installHooks();
        }
    }
};
