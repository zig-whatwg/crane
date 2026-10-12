//! Generated from: service-workers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ClientImpl = @import("impls").Client;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const FrameType = @import("enums").FrameType;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const ClientLifecycleState = @import("enums").ClientLifecycleState;
const ClientType = @import("enums").ClientType;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const Client = struct {
    pub const Meta = struct {
        pub const name = "Client";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "url", "get_url", null },
            .{ "frameType", "get_frameType", null },
            .{ "id", "get_id", null },
            .{ "type", "get_type", null },
            .{ "lifecycleState", "get_lifecycleState", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "postMessage", "call_postMessage", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "postMessage",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "url", "get_url", null },
            .{ "frameType", "get_frameType", null },
            .{ "id", "get_id", null },
            .{ "type", "get_type", null },
            .{ "lifecycleState", "get_lifecycleState", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            url: runtime.USVString = undefined,
            frameType: enums.FrameType = undefined,
            id: typedefs.DOMString = undefined,
            type: enums.ClientType = undefined,
            lifecycleState: enums.ClientLifecycleState = undefined,
            _internal: ?*ClientImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_frameType = &get_frameType,
        .get_id = &get_id,
        .get_lifecycleState = &get_lifecycleState,
        .get_type = &get_type,
        .get_url = &get_url,

        .call_postMessage = &call_postMessage,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Client has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ClientImpl, "init") and @hasDecl(ClientImpl, "initOwn")) @compileError("ClientImpl defines both init and initOwn");
        if (comptime @hasDecl(ClientImpl, "init")) return ClientImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ClientImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ClientImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ClientImpl, "init")) return false;
        if (comptime @hasDecl(ClientImpl, "construction_args")) {
            inline for (ClientImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ClientImpl, "deinit") and @hasDecl(ClientImpl, "deinitOwn")) @compileError("ClientImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ClientImpl, "deinit")) return ClientImpl.deinit(instance);
        if (comptime @hasDecl(ClientImpl, "deinitOwn")) ClientImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Client")) {
            if (comptime @hasDecl(impls.Client, "installHooks")) impls.Client.installHooks();
        }
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ClientImpl.get_url(instance);
    }

    pub fn get_frameType(instance: *runtime.Instance) anyerror!FrameType {
        return try ClientImpl.get_frameType(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try ClientImpl.get_id(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!ClientType {
        return try ClientImpl.get_type(instance);
    }

    pub fn get_lifecycleState(instance: *runtime.Instance) anyerror!ClientLifecycleState {
        return try ClientImpl.get_lifecycleState(instance);
    }

    pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
        return try ClientImpl.call_postMessage(instance, message, transfer);
    }

    pub fn call_postMessage__1(instance: *runtime.Instance, message: runtime.JSValue, options: webidl.Opt(StructuredSerializeOptions)) anyerror!void {
        if (comptime @hasDecl(ClientImpl, "call_postMessage__1")) {
            return try ClientImpl.call_postMessage__1(instance, message, options);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "postMessage", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_postMessage", .args = &.{ .{ .kinds = &.{.any} }, .{ .kinds = &.{.sequence} } } },
            .{ .function = "call_postMessage__1", .implemented = @hasDecl(ClientImpl, "call_postMessage__1"), .args = &.{ .{ .kinds = &.{.any} }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
        } },
    };
};
