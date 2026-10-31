//! Generated from: encrypted-media.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaKeyStatusMapImpl = @import("impls").MediaKeyStatusMap;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MediaKeyStatus = @import("enums").MediaKeyStatus;
const BufferSource = @import("typedefs").BufferSource;

pub const MediaKeyStatusMap = struct {
    pub const Meta = struct {
        pub const name = "MediaKeyStatusMap";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "size", "get_size", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "has", "call_has", 1 },
            .{ "get", "call_get", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "has",
            "get",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "size", "get_size", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "MediaKeyStatus",
            .key_type = "BufferSource",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            size: u32 = undefined,
            _internal: ?*MediaKeyStatusMapImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_size = &get_size,

        .call_get = &call_get,
        .call_has = &call_has,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("MediaKeyStatusMap has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(MediaKeyStatusMapImpl, "init") and @hasDecl(MediaKeyStatusMapImpl, "initOwn")) @compileError("MediaKeyStatusMapImpl defines both init and initOwn");
        if (comptime @hasDecl(MediaKeyStatusMapImpl, "init")) return MediaKeyStatusMapImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(MediaKeyStatusMapImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try MediaKeyStatusMapImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MediaKeyStatusMapImpl, "init")) return false;
        if (comptime @hasDecl(MediaKeyStatusMapImpl, "construction_args")) {
            inline for (MediaKeyStatusMapImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MediaKeyStatusMapImpl, "deinit") and @hasDecl(MediaKeyStatusMapImpl, "deinitOwn")) @compileError("MediaKeyStatusMapImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MediaKeyStatusMapImpl, "deinit")) return MediaKeyStatusMapImpl.deinit(instance);
        if (comptime @hasDecl(MediaKeyStatusMapImpl, "deinitOwn")) MediaKeyStatusMapImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MediaKeyStatusMap")) {
            if (comptime @hasDecl(impls.MediaKeyStatusMap, "installHooks")) impls.MediaKeyStatusMap.installHooks();
        }
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try MediaKeyStatusMapImpl.get_size(instance);
    }

    pub fn call_has(instance: *runtime.Instance, keyId: BufferSource) anyerror!bool {
        return try MediaKeyStatusMapImpl.call_has(instance, keyId);
    }

    pub fn call_get(instance: *runtime.Instance, keyId: BufferSource) anyerror!runtime.JSValue {
        return try MediaKeyStatusMapImpl.call_get(instance, keyId);
    }

    /// Get entries for pair iterable support (used by V8 for iteration)
    /// Returns slice of entries with .name and .value fields
    pub fn getEntriesForIterable(instance: *runtime.Instance) ?[]const MediaKeyStatusMapImpl.IterableEntry {
        return MediaKeyStatusMapImpl.getEntriesInternal(instance);
    }
};
