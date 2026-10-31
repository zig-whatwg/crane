//! Generated from: EXT_sRGB.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const EXT_sRGBImpl = @import("impls").EXT_sRGB;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GLenum = @import("typedefs").GLenum;

pub const EXT_sRGB = struct {
    pub const Meta = struct {
        pub const name = "EXT_sRGB";
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
            .{ "SRGB_EXT", "get_SRGB_EXT" },
            .{ "SRGB_ALPHA_EXT", "get_SRGB_ALPHA_EXT" },
            .{ "SRGB8_ALPHA8_EXT", "get_SRGB8_ALPHA8_EXT" },
            .{ "FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT", "get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT" },
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
            _internal: ?*EXT_sRGBImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum SRGB_EXT = 35904;
    pub fn get_SRGB_EXT() GLenum {
        return 35904;
    }

    /// WebIDL constant: const GLenum SRGB_ALPHA_EXT = 35906;
    pub fn get_SRGB_ALPHA_EXT() GLenum {
        return 35906;
    }

    /// WebIDL constant: const GLenum SRGB8_ALPHA8_EXT = 35907;
    pub fn get_SRGB8_ALPHA8_EXT() GLenum {
        return 35907;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT = 33296;
    pub fn get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT() GLenum {
        return 33296;
    }

    const delegates = .{
        .get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT = &get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT,
        .get_SRGB8_ALPHA8_EXT = &get_SRGB8_ALPHA8_EXT,
        .get_SRGB_ALPHA_EXT = &get_SRGB_ALPHA_EXT,
        .get_SRGB_EXT = &get_SRGB_EXT,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("EXT_sRGB has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(EXT_sRGBImpl, "init") and @hasDecl(EXT_sRGBImpl, "initOwn")) @compileError("EXT_sRGBImpl defines both init and initOwn");
        if (comptime @hasDecl(EXT_sRGBImpl, "init")) return EXT_sRGBImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(EXT_sRGBImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try EXT_sRGBImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(EXT_sRGBImpl, "init")) return false;
        if (comptime @hasDecl(EXT_sRGBImpl, "construction_args")) {
            inline for (EXT_sRGBImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(EXT_sRGBImpl, "deinit") and @hasDecl(EXT_sRGBImpl, "deinitOwn")) @compileError("EXT_sRGBImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(EXT_sRGBImpl, "deinit")) return EXT_sRGBImpl.deinit(instance);
        if (comptime @hasDecl(EXT_sRGBImpl, "deinitOwn")) EXT_sRGBImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "EXT_sRGB")) {
            if (comptime @hasDecl(impls.EXT_sRGB, "installHooks")) impls.EXT_sRGB.installHooks();
        }
    }
};
