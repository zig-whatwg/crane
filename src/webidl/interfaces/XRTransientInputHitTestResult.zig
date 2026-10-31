//! Generated from: webxr-hit-test.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRTransientInputHitTestResultImpl = @import("impls").XRTransientInputHitTestResult;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRInputSource = @import("interfaces").XRInputSource;
const XRHitTestResult = @import("interfaces").XRHitTestResult;

pub const XRTransientInputHitTestResult = struct {
    pub const Meta = struct {
        pub const name = "XRTransientInputHitTestResult";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "inputSource", "get_inputSource", null },
            .{ "results", "get_results", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "inputSource", "get_inputSource", null },
            .{ "results", "get_results", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            inputSource: *runtime.Instance = undefined,
            results: runtime.JSValue = undefined,
            cached_inputSource: ?*runtime.Instance = null,
            _internal: ?*XRTransientInputHitTestResultImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_inputSource = &get_inputSource,
        .get_results = &get_results,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("XRTransientInputHitTestResult has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(XRTransientInputHitTestResultImpl, "init") and @hasDecl(XRTransientInputHitTestResultImpl, "initOwn")) @compileError("XRTransientInputHitTestResultImpl defines both init and initOwn");
        if (comptime @hasDecl(XRTransientInputHitTestResultImpl, "init")) return XRTransientInputHitTestResultImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(XRTransientInputHitTestResultImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try XRTransientInputHitTestResultImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRTransientInputHitTestResultImpl, "init")) return false;
        if (comptime @hasDecl(XRTransientInputHitTestResultImpl, "construction_args")) {
            inline for (XRTransientInputHitTestResultImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRTransientInputHitTestResultImpl, "deinit") and @hasDecl(XRTransientInputHitTestResultImpl, "deinitOwn")) @compileError("XRTransientInputHitTestResultImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(XRTransientInputHitTestResultImpl, "deinit")) return XRTransientInputHitTestResultImpl.deinit(instance);
        if (comptime @hasDecl(XRTransientInputHitTestResultImpl, "deinitOwn")) XRTransientInputHitTestResultImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRTransientInputHitTestResult")) {
            if (comptime @hasDecl(impls.XRTransientInputHitTestResult, "installHooks")) impls.XRTransientInputHitTestResult.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_inputSource(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_inputSource) |cached| {
            return cached;
        }
        const value = try XRTransientInputHitTestResultImpl.get_inputSource(instance);
        state.own.cached_inputSource = value;
        @import("dom").same_object_cache.made(instance, value, "inputSource");
        return value;
    }

    pub fn get_results(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try XRTransientInputHitTestResultImpl.get_results(instance);
    }
};
