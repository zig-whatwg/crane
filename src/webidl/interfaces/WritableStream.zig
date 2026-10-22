//! Generated from: streams.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WritableStreamImpl = @import("impls").WritableStream;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const WritableStreamDefaultWriter = @import("interfaces").WritableStreamDefaultWriter;
const QueuingStrategy = @import("dictionaries").QueuingStrategy;

pub const WritableStream = struct {
    pub const Meta = struct {
        pub const name = "WritableStream";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
            .{ .name = "Transferable" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "locked", "get_locked", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "abort", "call_abort", 0 },
            .{ "close", "call_close", 0 },
            .{ "getWriter", "call_getWriter", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "abort",
            "close",
            "getWriter",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "locked", "get_locked", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            locked: bool = undefined,
            _internal: ?*WritableStreamImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_locked = &get_locked,

        .call_abort = &call_abort,
        .call_close = &call_close,
        .call_getWriter = &call_getWriter,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("WritableStream has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(WritableStreamImpl, "init") and @hasDecl(WritableStreamImpl, "initOwn")) @compileError("WritableStreamImpl defines both init and initOwn");
        if (comptime @hasDecl(WritableStreamImpl, "init")) return WritableStreamImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(WritableStreamImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try WritableStreamImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WritableStreamImpl, "init")) return false;
        if (comptime @hasDecl(WritableStreamImpl, "construction_args")) {
            inline for (WritableStreamImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(WritableStreamImpl, "deinit") and @hasDecl(WritableStreamImpl, "deinitOwn")) @compileError("WritableStreamImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(WritableStreamImpl, "deinit")) return WritableStreamImpl.deinit(instance);
        if (comptime @hasDecl(WritableStreamImpl, "deinitOwn")) WritableStreamImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "WritableStream")) {
            if (comptime @hasDecl(impls.WritableStream, "installHooks")) impls.WritableStream.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, underlyingSink: webidl.Opt(runtime.JSValue), strategy: webidl.Opt(QueuingStrategy)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try WritableStreamImpl.call_constructor(ctx, underlyingSink, strategy);
    }

    pub fn get_locked(instance: *runtime.Instance) anyerror!bool {
        return try WritableStreamImpl.get_locked(instance);
    }

    pub fn call_abort(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try WritableStreamImpl.call_abort(instance, reason);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try WritableStreamImpl.call_close(instance);
    }

    pub fn call_getWriter(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WritableStreamImpl.call_getWriter(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_abort",
        "call_close",
    };
};
