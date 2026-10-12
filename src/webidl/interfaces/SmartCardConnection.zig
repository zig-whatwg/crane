//! Generated from: web-smart-card.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SmartCardConnectionImpl = @import("impls").SmartCardConnection;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SmartCardTransactionOptions = @import("dictionaries").SmartCardTransactionOptions;
const SmartCardTransactionCallback = @import("callbacks").SmartCardTransactionCallback;
const SmartCardDisposition = @import("enums").SmartCardDisposition;
const BufferSource = @import("typedefs").BufferSource;
const SmartCardConnectionStatus = @import("dictionaries").SmartCardConnectionStatus;
const SmartCardTransmitOptions = @import("dictionaries").SmartCardTransmitOptions;

pub const SmartCardConnection = struct {
    pub const Meta = struct {
        pub const name = "SmartCardConnection";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "SharedWorker", "Window" } } },
            .{ .name = "SecureContext" },
            .{ .name = "IsolatedContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .SharedWorker = true,
            .Window = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "disconnect", "call_disconnect", 0 },
            .{ "transmit", "call_transmit", 1 },
            .{ "startTransaction", "call_startTransaction", 1 },
            .{ "status", "call_status", 0 },
            .{ "control", "call_control", 2 },
            .{ "getAttribute", "call_getAttribute", 1 },
            .{ "setAttribute", "call_setAttribute", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "disconnect",
            "transmit",
            "startTransaction",
            "status",
            "control",
            "getAttribute",
            "setAttribute",
        };

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
            _internal: ?*SmartCardConnectionImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_control = &call_control,
        .call_disconnect = &call_disconnect,
        .call_getAttribute = &call_getAttribute,
        .call_setAttribute = &call_setAttribute,
        .call_startTransaction = &call_startTransaction,
        .call_status = &call_status,
        .call_transmit = &call_transmit,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SmartCardConnection has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SmartCardConnectionImpl, "init") and @hasDecl(SmartCardConnectionImpl, "initOwn")) @compileError("SmartCardConnectionImpl defines both init and initOwn");
        if (comptime @hasDecl(SmartCardConnectionImpl, "init")) return SmartCardConnectionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(SmartCardConnectionImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try SmartCardConnectionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SmartCardConnectionImpl, "init")) return false;
        if (comptime @hasDecl(SmartCardConnectionImpl, "construction_args")) {
            inline for (SmartCardConnectionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SmartCardConnectionImpl, "deinit") and @hasDecl(SmartCardConnectionImpl, "deinitOwn")) @compileError("SmartCardConnectionImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SmartCardConnectionImpl, "deinit")) return SmartCardConnectionImpl.deinit(instance);
        if (comptime @hasDecl(SmartCardConnectionImpl, "deinitOwn")) SmartCardConnectionImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SmartCardConnection")) {
            if (comptime @hasDecl(impls.SmartCardConnection, "installHooks")) impls.SmartCardConnection.installHooks();
        }
    }

    pub fn call_status(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try SmartCardConnectionImpl.call_status(instance);
    }

    pub fn call_control(instance: *runtime.Instance, controlCode: u32, data: BufferSource) anyerror!runtime.JSValue {
        return try SmartCardConnectionImpl.call_control(instance, controlCode, data);
    }

    pub fn call_getAttribute(instance: *runtime.Instance, tag: u32) anyerror!runtime.JSValue {
        return try SmartCardConnectionImpl.call_getAttribute(instance, tag);
    }

    pub fn call_disconnect(instance: *runtime.Instance, disposition: webidl.Opt(SmartCardDisposition)) anyerror!runtime.JSValue {
        return try SmartCardConnectionImpl.call_disconnect(instance, disposition);
    }

    pub fn call_transmit(instance: *runtime.Instance, sendBuffer: BufferSource, options: webidl.Opt(SmartCardTransmitOptions)) anyerror!runtime.JSValue {
        return try SmartCardConnectionImpl.call_transmit(instance, sendBuffer, options);
    }

    pub fn call_setAttribute(instance: *runtime.Instance, tag: u32, value: BufferSource) anyerror!runtime.JSValue {
        return try SmartCardConnectionImpl.call_setAttribute(instance, tag, value);
    }

    pub fn call_startTransaction(instance: *runtime.Instance, transaction: SmartCardTransactionCallback, options: webidl.Opt(SmartCardTransactionOptions)) anyerror!runtime.JSValue {
        return try SmartCardConnectionImpl.call_startTransaction(instance, transaction, options);
    }

    /// WebIDL [EnforceRange]: the integer arguments and attribute values
    /// whose conversion takes that branch of ConvertToInt (bit i = argument i;
    /// an attribute setter's value is bit 0).
    pub const enforce_range = .{
        .{ "call_control", 0b1 },
        .{ "call_getAttribute", 0b1 },
        .{ "call_setAttribute", 0b1 },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_status",
        "call_control",
        "call_getAttribute",
        "call_disconnect",
        "call_transmit",
        "call_setAttribute",
        "call_startTransaction",
    };
};
