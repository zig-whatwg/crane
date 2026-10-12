//! Generated from: streams.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ReadableByteStreamControllerImpl = @import("impls").ReadableByteStreamController;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const ReadableStreamBYOBRequest = @import("interfaces").ReadableStreamBYOBRequest;

pub const ReadableByteStreamController = struct {
    pub const Meta = struct {
        pub const name = "ReadableByteStreamController";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "byobRequest", "get_byobRequest", null },
            .{ "desiredSize", "get_desiredSize", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "close", "call_close", 0 },
            .{ "enqueue", "call_enqueue", 1 },
            .{ "error", "call_error", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "close",
            "enqueue",
            "error",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "byobRequest", "get_byobRequest", null },
            .{ "desiredSize", "get_desiredSize", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            byobRequest: ?*runtime.Instance = null,
            desiredSize: ?f64 = null,
            _internal: ?*ReadableByteStreamControllerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_byobRequest = &get_byobRequest,
        .get_desiredSize = &get_desiredSize,

        .call_close = &call_close,
        .call_enqueue = &call_enqueue,
        .call_error = &call_error,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ReadableByteStreamController has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ReadableByteStreamControllerImpl, "init") and @hasDecl(ReadableByteStreamControllerImpl, "initOwn")) @compileError("ReadableByteStreamControllerImpl defines both init and initOwn");
        if (comptime @hasDecl(ReadableByteStreamControllerImpl, "init")) return ReadableByteStreamControllerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ReadableByteStreamControllerImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ReadableByteStreamControllerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ReadableByteStreamControllerImpl, "init")) return false;
        if (comptime @hasDecl(ReadableByteStreamControllerImpl, "construction_args")) {
            inline for (ReadableByteStreamControllerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ReadableByteStreamControllerImpl, "deinit") and @hasDecl(ReadableByteStreamControllerImpl, "deinitOwn")) @compileError("ReadableByteStreamControllerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ReadableByteStreamControllerImpl, "deinit")) return ReadableByteStreamControllerImpl.deinit(instance);
        if (comptime @hasDecl(ReadableByteStreamControllerImpl, "deinitOwn")) ReadableByteStreamControllerImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ReadableByteStreamController")) {
            if (comptime @hasDecl(impls.ReadableByteStreamController, "installHooks")) impls.ReadableByteStreamController.installHooks();
        }
    }

    pub fn get_byobRequest(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ReadableByteStreamControllerImpl.get_byobRequest(instance);
    }

    pub fn get_desiredSize(instance: *runtime.Instance) anyerror!?f64 {
        return try ReadableByteStreamControllerImpl.get_desiredSize(instance);
    }

    pub fn call_enqueue(instance: *runtime.Instance, chunk: ArrayBufferView) anyerror!void {
        return try ReadableByteStreamControllerImpl.call_enqueue(instance, chunk);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try ReadableByteStreamControllerImpl.call_close(instance);
    }

    pub fn call_error(instance: *runtime.Instance, e: webidl.Opt(runtime.JSValue)) anyerror!void {
        return try ReadableByteStreamControllerImpl.call_error(instance, e);
    }
};
