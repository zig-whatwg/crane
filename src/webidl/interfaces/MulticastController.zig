//! Generated from: direct-sockets.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MulticastControllerImpl = @import("impls").MulticastController;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MulticastGroupOptions = @import("dictionaries").MulticastGroupOptions;
const DOMString = @import("typedefs").DOMString;

pub const MulticastController = struct {
    pub const Meta = struct {
        pub const name = "MulticastController";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "SecureContext" },
            .{ .name = "IsolatedContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "joinedGroups", "get_joinedGroups", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "joinGroup", "call_joinGroup", 1 },
            .{ "leaveGroup", "call_leaveGroup", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "joinGroup",
            "leaveGroup",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "joinedGroups", "get_joinedGroups", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            joinedGroups: runtime.JSValue = undefined,
            _internal: ?*MulticastControllerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_joinedGroups = &get_joinedGroups,

        .call_joinGroup = &call_joinGroup,
        .call_leaveGroup = &call_leaveGroup,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("MulticastController has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(MulticastControllerImpl, "init") and @hasDecl(MulticastControllerImpl, "initOwn")) @compileError("MulticastControllerImpl defines both init and initOwn");
        if (comptime @hasDecl(MulticastControllerImpl, "init")) return MulticastControllerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(MulticastControllerImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try MulticastControllerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MulticastControllerImpl, "init")) return false;
        if (comptime @hasDecl(MulticastControllerImpl, "construction_args")) {
            inline for (MulticastControllerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MulticastControllerImpl, "deinit") and @hasDecl(MulticastControllerImpl, "deinitOwn")) @compileError("MulticastControllerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MulticastControllerImpl, "deinit")) return MulticastControllerImpl.deinit(instance);
        if (comptime @hasDecl(MulticastControllerImpl, "deinitOwn")) MulticastControllerImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MulticastController")) {
            if (comptime @hasDecl(impls.MulticastController, "installHooks")) impls.MulticastController.installHooks();
        }
    }

    pub fn get_joinedGroups(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MulticastControllerImpl.get_joinedGroups(instance);
    }

    pub fn call_leaveGroup(instance: *runtime.Instance, groupAddress: DOMString, options: webidl.Opt(MulticastGroupOptions)) anyerror!runtime.JSValue {
        return try MulticastControllerImpl.call_leaveGroup(instance, groupAddress, options);
    }

    pub fn call_joinGroup(instance: *runtime.Instance, groupAddress: DOMString, options: webidl.Opt(MulticastGroupOptions)) anyerror!runtime.JSValue {
        return try MulticastControllerImpl.call_joinGroup(instance, groupAddress, options);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_leaveGroup",
        "call_joinGroup",
    };
};
