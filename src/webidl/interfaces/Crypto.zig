//! Generated from: webcrypto.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CryptoImpl = @import("impls").Crypto;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const SubtleCrypto = @import("interfaces").SubtleCrypto;
const DOMString = @import("typedefs").DOMString;

pub const Crypto = struct {
    pub const Meta = struct {
        pub const name = "Crypto";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "subtle", "get_subtle", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getRandomValues", "call_getRandomValues", 1 },
            .{ "randomUUID", "call_randomUUID", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getRandomValues",
            "randomUUID",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "subtle", "get_subtle", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// [SecureContext] members - their own, their partial interface's or
        /// their mixin's: hidden in a realm that is not a secure context
        /// (WebIDL 3.3.13).
        pub const secure_context_members = .{
            "subtle",
            "randomUUID",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            subtle: *runtime.Instance = undefined,
            _internal: ?*CryptoImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_subtle = &get_subtle,

        .call_getRandomValues = &call_getRandomValues,
        .call_randomUUID = &call_randomUUID,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("Crypto has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(CryptoImpl, "init") and @hasDecl(CryptoImpl, "initOwn")) @compileError("CryptoImpl defines both init and initOwn");
        if (comptime @hasDecl(CryptoImpl, "init")) return CryptoImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(CryptoImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try CryptoImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CryptoImpl, "init")) return false;
        if (comptime @hasDecl(CryptoImpl, "construction_args")) {
            inline for (CryptoImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CryptoImpl, "deinit") and @hasDecl(CryptoImpl, "deinitOwn")) @compileError("CryptoImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CryptoImpl, "deinit")) return CryptoImpl.deinit(instance);
        if (comptime @hasDecl(CryptoImpl, "deinitOwn")) CryptoImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Crypto")) {
            if (comptime @hasDecl(impls.Crypto, "installHooks")) impls.Crypto.installHooks();
        }
    }

    /// Extended attributes: [SecureContext]
    pub fn get_subtle(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CryptoImpl.get_subtle(instance);
    }

    pub fn call_getRandomValues(instance: *runtime.Instance, array: ArrayBufferView) anyerror!ArrayBufferView {
        return try CryptoImpl.call_getRandomValues(instance, array);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_randomUUID(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try CryptoImpl.call_randomUUID(instance);
    }
};
