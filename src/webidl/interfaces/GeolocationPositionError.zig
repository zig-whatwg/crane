//! Generated from: geolocation.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GeolocationPositionErrorImpl = @import("impls").GeolocationPositionError;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const GeolocationPositionError = struct {
    pub const Meta = struct {
        pub const name = "GeolocationPositionError";
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
            .{ "code", "get_code", null },
            .{ "message", "get_message", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "PERMISSION_DENIED", "get_PERMISSION_DENIED" },
            .{ "POSITION_UNAVAILABLE", "get_POSITION_UNAVAILABLE" },
            .{ "TIMEOUT", "get_TIMEOUT" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "code", "get_code", null },
            .{ "message", "get_message", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            code: u16 = undefined,
            message: runtime.DOMString = undefined,
            _internal: ?*GeolocationPositionErrorImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short PERMISSION_DENIED = 1;
    pub fn get_PERMISSION_DENIED() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short POSITION_UNAVAILABLE = 2;
    pub fn get_POSITION_UNAVAILABLE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short TIMEOUT = 3;
    pub fn get_TIMEOUT() u16 {
        return 3;
    }

    const delegates = .{
        .get_PERMISSION_DENIED = &get_PERMISSION_DENIED,
        .get_POSITION_UNAVAILABLE = &get_POSITION_UNAVAILABLE,
        .get_TIMEOUT = &get_TIMEOUT,
        .get_code = &get_code,
        .get_message = &get_message,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("GeolocationPositionError has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(GeolocationPositionErrorImpl, "init") and @hasDecl(GeolocationPositionErrorImpl, "initOwn")) @compileError("GeolocationPositionErrorImpl defines both init and initOwn");
        if (comptime @hasDecl(GeolocationPositionErrorImpl, "init")) return GeolocationPositionErrorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GeolocationPositionErrorImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GeolocationPositionErrorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GeolocationPositionErrorImpl, "init")) return false;
        if (comptime @hasDecl(GeolocationPositionErrorImpl, "construction_args")) {
            inline for (GeolocationPositionErrorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GeolocationPositionErrorImpl, "deinit") and @hasDecl(GeolocationPositionErrorImpl, "deinitOwn")) @compileError("GeolocationPositionErrorImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(GeolocationPositionErrorImpl, "deinit")) return GeolocationPositionErrorImpl.deinit(instance);
        if (comptime @hasDecl(GeolocationPositionErrorImpl, "deinitOwn")) GeolocationPositionErrorImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GeolocationPositionError")) {
            if (comptime @hasDecl(impls.GeolocationPositionError, "installHooks")) impls.GeolocationPositionError.installHooks();
        }
    }

    pub fn get_code(instance: *runtime.Instance) anyerror!u16 {
        return try GeolocationPositionErrorImpl.get_code(instance);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try GeolocationPositionErrorImpl.get_message(instance);
    }
};
