//! Generated from: EXT_color_buffer_half_float.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const EXT_color_buffer_half_floatImpl = @import("impls").EXT_color_buffer_half_float;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GLenum = @import("typedefs").GLenum;

pub const EXT_color_buffer_half_float = struct {
    pub const Meta = struct {
        pub const name = "EXT_color_buffer_half_float";
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
            .{ "RGBA16F_EXT", "get_RGBA16F_EXT" },
            .{ "RGB16F_EXT", "get_RGB16F_EXT" },
            .{ "FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT", "get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT" },
            .{ "UNSIGNED_NORMALIZED_EXT", "get_UNSIGNED_NORMALIZED_EXT" },
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
            _internal: ?*EXT_color_buffer_half_floatImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum RGBA16F_EXT = 34842;
    pub fn get_RGBA16F_EXT() GLenum {
        return 34842;
    }

    /// WebIDL constant: const GLenum RGB16F_EXT = 34843;
    pub fn get_RGB16F_EXT() GLenum {
        return 34843;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT = 33297;
    pub fn get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT() GLenum {
        return 33297;
    }

    /// WebIDL constant: const GLenum UNSIGNED_NORMALIZED_EXT = 35863;
    pub fn get_UNSIGNED_NORMALIZED_EXT() GLenum {
        return 35863;
    }

    const delegates = .{
        .get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT = &get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT,
        .get_RGB16F_EXT = &get_RGB16F_EXT,
        .get_RGBA16F_EXT = &get_RGBA16F_EXT,
        .get_UNSIGNED_NORMALIZED_EXT = &get_UNSIGNED_NORMALIZED_EXT,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("EXT_color_buffer_half_float has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(EXT_color_buffer_half_floatImpl, "init") and @hasDecl(EXT_color_buffer_half_floatImpl, "initOwn")) @compileError("EXT_color_buffer_half_floatImpl defines both init and initOwn");
        if (comptime @hasDecl(EXT_color_buffer_half_floatImpl, "init")) return EXT_color_buffer_half_floatImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(EXT_color_buffer_half_floatImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try EXT_color_buffer_half_floatImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(EXT_color_buffer_half_floatImpl, "init")) return false;
        if (comptime @hasDecl(EXT_color_buffer_half_floatImpl, "construction_args")) {
            inline for (EXT_color_buffer_half_floatImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(EXT_color_buffer_half_floatImpl, "deinit") and @hasDecl(EXT_color_buffer_half_floatImpl, "deinitOwn")) @compileError("EXT_color_buffer_half_floatImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(EXT_color_buffer_half_floatImpl, "deinit")) return EXT_color_buffer_half_floatImpl.deinit(instance);
        if (comptime @hasDecl(EXT_color_buffer_half_floatImpl, "deinitOwn")) EXT_color_buffer_half_floatImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "EXT_color_buffer_half_float")) {
            if (comptime @hasDecl(impls.EXT_color_buffer_half_float, "installHooks")) impls.EXT_color_buffer_half_float.installHooks();
        }
    }
};
