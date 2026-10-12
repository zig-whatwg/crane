//! Generated from: WEBGL_clip_cull_distance.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WEBGL_clip_cull_distanceImpl = @import("impls").WEBGL_clip_cull_distance;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GLenum = @import("typedefs").GLenum;

pub const WEBGL_clip_cull_distance = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_clip_cull_distance";
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
            .{ "MAX_CLIP_DISTANCES_WEBGL", "get_MAX_CLIP_DISTANCES_WEBGL" },
            .{ "MAX_CULL_DISTANCES_WEBGL", "get_MAX_CULL_DISTANCES_WEBGL" },
            .{ "MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL", "get_MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL" },
            .{ "CLIP_DISTANCE0_WEBGL", "get_CLIP_DISTANCE0_WEBGL" },
            .{ "CLIP_DISTANCE1_WEBGL", "get_CLIP_DISTANCE1_WEBGL" },
            .{ "CLIP_DISTANCE2_WEBGL", "get_CLIP_DISTANCE2_WEBGL" },
            .{ "CLIP_DISTANCE3_WEBGL", "get_CLIP_DISTANCE3_WEBGL" },
            .{ "CLIP_DISTANCE4_WEBGL", "get_CLIP_DISTANCE4_WEBGL" },
            .{ "CLIP_DISTANCE5_WEBGL", "get_CLIP_DISTANCE5_WEBGL" },
            .{ "CLIP_DISTANCE6_WEBGL", "get_CLIP_DISTANCE6_WEBGL" },
            .{ "CLIP_DISTANCE7_WEBGL", "get_CLIP_DISTANCE7_WEBGL" },
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
            _internal: ?*WEBGL_clip_cull_distanceImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum MAX_CLIP_DISTANCES_WEBGL = 3378;
    pub fn get_MAX_CLIP_DISTANCES_WEBGL() GLenum {
        return 3378;
    }

    /// WebIDL constant: const GLenum MAX_CULL_DISTANCES_WEBGL = 33529;
    pub fn get_MAX_CULL_DISTANCES_WEBGL() GLenum {
        return 33529;
    }

    /// WebIDL constant: const GLenum MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL = 33530;
    pub fn get_MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL() GLenum {
        return 33530;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE0_WEBGL = 12288;
    pub fn get_CLIP_DISTANCE0_WEBGL() GLenum {
        return 12288;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE1_WEBGL = 12289;
    pub fn get_CLIP_DISTANCE1_WEBGL() GLenum {
        return 12289;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE2_WEBGL = 12290;
    pub fn get_CLIP_DISTANCE2_WEBGL() GLenum {
        return 12290;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE3_WEBGL = 12291;
    pub fn get_CLIP_DISTANCE3_WEBGL() GLenum {
        return 12291;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE4_WEBGL = 12292;
    pub fn get_CLIP_DISTANCE4_WEBGL() GLenum {
        return 12292;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE5_WEBGL = 12293;
    pub fn get_CLIP_DISTANCE5_WEBGL() GLenum {
        return 12293;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE6_WEBGL = 12294;
    pub fn get_CLIP_DISTANCE6_WEBGL() GLenum {
        return 12294;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE7_WEBGL = 12295;
    pub fn get_CLIP_DISTANCE7_WEBGL() GLenum {
        return 12295;
    }

    const delegates = .{
        .get_CLIP_DISTANCE0_WEBGL = &get_CLIP_DISTANCE0_WEBGL,
        .get_CLIP_DISTANCE1_WEBGL = &get_CLIP_DISTANCE1_WEBGL,
        .get_CLIP_DISTANCE2_WEBGL = &get_CLIP_DISTANCE2_WEBGL,
        .get_CLIP_DISTANCE3_WEBGL = &get_CLIP_DISTANCE3_WEBGL,
        .get_CLIP_DISTANCE4_WEBGL = &get_CLIP_DISTANCE4_WEBGL,
        .get_CLIP_DISTANCE5_WEBGL = &get_CLIP_DISTANCE5_WEBGL,
        .get_CLIP_DISTANCE6_WEBGL = &get_CLIP_DISTANCE6_WEBGL,
        .get_CLIP_DISTANCE7_WEBGL = &get_CLIP_DISTANCE7_WEBGL,
        .get_MAX_CLIP_DISTANCES_WEBGL = &get_MAX_CLIP_DISTANCES_WEBGL,
        .get_MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL = &get_MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL,
        .get_MAX_CULL_DISTANCES_WEBGL = &get_MAX_CULL_DISTANCES_WEBGL,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("WEBGL_clip_cull_distance has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(WEBGL_clip_cull_distanceImpl, "init") and @hasDecl(WEBGL_clip_cull_distanceImpl, "initOwn")) @compileError("WEBGL_clip_cull_distanceImpl defines both init and initOwn");
        if (comptime @hasDecl(WEBGL_clip_cull_distanceImpl, "init")) return WEBGL_clip_cull_distanceImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(WEBGL_clip_cull_distanceImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try WEBGL_clip_cull_distanceImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WEBGL_clip_cull_distanceImpl, "init")) return false;
        if (comptime @hasDecl(WEBGL_clip_cull_distanceImpl, "construction_args")) {
            inline for (WEBGL_clip_cull_distanceImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(WEBGL_clip_cull_distanceImpl, "deinit") and @hasDecl(WEBGL_clip_cull_distanceImpl, "deinitOwn")) @compileError("WEBGL_clip_cull_distanceImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(WEBGL_clip_cull_distanceImpl, "deinit")) return WEBGL_clip_cull_distanceImpl.deinit(instance);
        if (comptime @hasDecl(WEBGL_clip_cull_distanceImpl, "deinitOwn")) WEBGL_clip_cull_distanceImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "WEBGL_clip_cull_distance")) {
            if (comptime @hasDecl(impls.WEBGL_clip_cull_distance, "installHooks")) impls.WEBGL_clip_cull_distance.installHooks();
        }
    }
};
