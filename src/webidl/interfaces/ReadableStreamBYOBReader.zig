//! Generated from: streams.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ReadableStreamBYOBReaderImpl = @import("impls").ReadableStreamBYOBReader;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ReadableStreamGenericReader = @import("mixins").ReadableStreamGenericReader;
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const ReadableStream = @import("interfaces").ReadableStream;
const ReadableStreamBYOBReaderReadOptions = @import("dictionaries").ReadableStreamBYOBReaderReadOptions;
const ReadableStreamReadResult = @import("dictionaries").ReadableStreamReadResult;

pub const ReadableStreamBYOBReader = struct {
    pub const Meta = struct {
        pub const name = "ReadableStreamBYOBReader";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            ReadableStreamGenericReader,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "closed", "get_closed", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "read", "call_read", 1 },
            .{ "releaseLock", "call_releaseLock", 0 },
            .{ "cancel", "call_cancel", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "read",
            "releaseLock",
            "cancel",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "closed", "get_closed", null },
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
            _internal: ?*ReadableStreamBYOBReaderImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_closed = &get_closed,

        .call_cancel = &call_cancel,
        .call_read = &call_read,
        .call_releaseLock = &call_releaseLock,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ReadableStreamBYOBReader has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ReadableStreamBYOBReaderImpl, "init") and @hasDecl(ReadableStreamBYOBReaderImpl, "initOwn")) @compileError("ReadableStreamBYOBReaderImpl defines both init and initOwn");
        if (comptime @hasDecl(ReadableStreamBYOBReaderImpl, "init")) return ReadableStreamBYOBReaderImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ReadableStreamBYOBReaderImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ReadableStreamBYOBReaderImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ReadableStreamBYOBReaderImpl, "init")) return false;
        if (comptime @hasDecl(ReadableStreamBYOBReaderImpl, "construction_args")) {
            inline for (ReadableStreamBYOBReaderImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ReadableStreamBYOBReaderImpl, "deinit") and @hasDecl(ReadableStreamBYOBReaderImpl, "deinitOwn")) @compileError("ReadableStreamBYOBReaderImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ReadableStreamBYOBReaderImpl, "deinit")) return ReadableStreamBYOBReaderImpl.deinit(instance);
        if (comptime @hasDecl(ReadableStreamBYOBReaderImpl, "deinitOwn")) ReadableStreamBYOBReaderImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ReadableStreamBYOBReader")) {
            if (comptime @hasDecl(impls.ReadableStreamBYOBReader, "installHooks")) impls.ReadableStreamBYOBReader.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, stream: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ReadableStreamBYOBReaderImpl.call_constructor(ctx, stream);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "ReadableStream" },
    };

    pub fn get_closed(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ReadableStreamBYOBReaderImpl.get_closed(instance);
    }

    pub fn call_cancel(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try ReadableStreamBYOBReaderImpl.call_cancel(instance, reason);
    }

    pub fn call_read(instance: *runtime.Instance, view: ArrayBufferView, options: webidl.Opt(ReadableStreamBYOBReaderReadOptions)) anyerror!runtime.JSValue {
        return try ReadableStreamBYOBReaderImpl.call_read(instance, view, options);
    }

    pub fn call_releaseLock(instance: *runtime.Instance) anyerror!void {
        return try ReadableStreamBYOBReaderImpl.call_releaseLock(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_cancel",
        "call_read",
    };
};
