//! Generated from: webrtc-identity.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCIdentityAssertionImpl = @import("impls").RTCIdentityAssertion;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const RTCIdentityAssertion = struct {
    pub const Meta = struct {
        pub const name = "RTCIdentityAssertion";
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
            .{ "idp", "get_idp", "set_idp" },
            .{ "name", "get_name", "set_name" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "idp", "get_idp", "set_idp" },
            .{ "name", "get_name", "set_name" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            idp: runtime.DOMString = undefined,
            name: runtime.DOMString = undefined,
            _internal: ?*RTCIdentityAssertionImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_idp = &get_idp,
        .get_name = &get_name,

        .set_idp = &set_idp,
        .set_name = &set_name,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("RTCIdentityAssertion has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(RTCIdentityAssertionImpl, "init") and @hasDecl(RTCIdentityAssertionImpl, "initOwn")) @compileError("RTCIdentityAssertionImpl defines both init and initOwn");
        if (comptime @hasDecl(RTCIdentityAssertionImpl, "init")) return RTCIdentityAssertionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(RTCIdentityAssertionImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try RTCIdentityAssertionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(RTCIdentityAssertionImpl, "init")) return false;
        if (comptime @hasDecl(RTCIdentityAssertionImpl, "construction_args")) {
            inline for (RTCIdentityAssertionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(RTCIdentityAssertionImpl, "deinit") and @hasDecl(RTCIdentityAssertionImpl, "deinitOwn")) @compileError("RTCIdentityAssertionImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(RTCIdentityAssertionImpl, "deinit")) return RTCIdentityAssertionImpl.deinit(instance);
        if (comptime @hasDecl(RTCIdentityAssertionImpl, "deinitOwn")) RTCIdentityAssertionImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "RTCIdentityAssertion")) {
            if (comptime @hasDecl(impls.RTCIdentityAssertion, "installHooks")) impls.RTCIdentityAssertion.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 2;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, idp: runtime.DOMString, name: runtime.DOMString) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCIdentityAssertionImpl.call_constructor(ctx, idp, name);
    }

    pub fn get_idp(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try RTCIdentityAssertionImpl.get_idp(instance);
    }

    pub fn set_idp(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try RTCIdentityAssertionImpl.set_idp(instance, value);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try RTCIdentityAssertionImpl.get_name(instance);
    }

    pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try RTCIdentityAssertionImpl.set_name(instance, value);
    }
};
