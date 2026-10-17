//! Generated from: streams.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WritableStreamDefaultWriterImpl = @import("impls").WritableStreamDefaultWriter;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const WritableStream = @import("interfaces").WritableStream;

pub const WritableStreamDefaultWriter = struct {
    pub const Meta = struct {
        pub const name = "WritableStreamDefaultWriter";
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
            .{ "closed", "get_closed", null },
            .{ "desiredSize", "get_desiredSize", null },
            .{ "ready", "get_ready", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "abort", "call_abort", 0 },
            .{ "close", "call_close", 0 },
            .{ "releaseLock", "call_releaseLock", 0 },
            .{ "write", "call_write", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "abort",
            "close",
            "releaseLock",
            "write",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "closed", "get_closed", null },
            .{ "desiredSize", "get_desiredSize", null },
            .{ "ready", "get_ready", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            closed: runtime.JSValue = undefined,
            desiredSize: ?f64 = null,
            ready: runtime.JSValue = undefined,
            _internal: ?*WritableStreamDefaultWriterImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_closed = &get_closed,
        .get_desiredSize = &get_desiredSize,
        .get_ready = &get_ready,

        .call_abort = &call_abort,
        .call_close = &call_close,
        .call_releaseLock = &call_releaseLock,
        .call_write = &call_write,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("WritableStreamDefaultWriter has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(WritableStreamDefaultWriterImpl, "init") and @hasDecl(WritableStreamDefaultWriterImpl, "initOwn")) @compileError("WritableStreamDefaultWriterImpl defines both init and initOwn");
        if (comptime @hasDecl(WritableStreamDefaultWriterImpl, "init")) return WritableStreamDefaultWriterImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(WritableStreamDefaultWriterImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try WritableStreamDefaultWriterImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WritableStreamDefaultWriterImpl, "init")) return false;
        if (comptime @hasDecl(WritableStreamDefaultWriterImpl, "construction_args")) {
            inline for (WritableStreamDefaultWriterImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(WritableStreamDefaultWriterImpl, "deinit") and @hasDecl(WritableStreamDefaultWriterImpl, "deinitOwn")) @compileError("WritableStreamDefaultWriterImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(WritableStreamDefaultWriterImpl, "deinit")) return WritableStreamDefaultWriterImpl.deinit(instance);
        if (comptime @hasDecl(WritableStreamDefaultWriterImpl, "deinitOwn")) WritableStreamDefaultWriterImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "WritableStreamDefaultWriter")) {
            if (comptime @hasDecl(impls.WritableStreamDefaultWriter, "installHooks")) impls.WritableStreamDefaultWriter.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, stream: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try WritableStreamDefaultWriterImpl.call_constructor(ctx, stream);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "WritableStream" },
    };

    pub fn get_closed(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try WritableStreamDefaultWriterImpl.get_closed(instance);
    }

    pub fn get_desiredSize(instance: *runtime.Instance) anyerror!?f64 {
        return try WritableStreamDefaultWriterImpl.get_desiredSize(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try WritableStreamDefaultWriterImpl.get_ready(instance);
    }

    pub fn call_abort(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try WritableStreamDefaultWriterImpl.call_abort(instance, reason);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try WritableStreamDefaultWriterImpl.call_close(instance);
    }

    pub fn call_write(instance: *runtime.Instance, chunk: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try WritableStreamDefaultWriterImpl.call_write(instance, chunk);
    }

    pub fn call_releaseLock(instance: *runtime.Instance) anyerror!void {
        return try WritableStreamDefaultWriterImpl.call_releaseLock(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_abort",
        "call_close",
        "call_write",
    };
};
