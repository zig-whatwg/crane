//! Generated from: webnn.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MLImpl = @import("impls").ML;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MLContextOptions = @import("dictionaries").MLContextOptions;
const MLContext = @import("interfaces").MLContext;
const GPUDevice = @import("interfaces").GPUDevice;

pub const ML = struct {
    pub const Meta = struct {
        pub const name = "ML";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createContext", "call_createContext", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createContext",
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
            _internal: ?*MLImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_createContext = &call_createContext,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ML has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(MLImpl, "init") and @hasDecl(MLImpl, "initOwn")) @compileError("MLImpl defines both init and initOwn");
        if (comptime @hasDecl(MLImpl, "init")) return MLImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(MLImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try MLImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MLImpl, "init")) return false;
        if (comptime @hasDecl(MLImpl, "construction_args")) {
            inline for (MLImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MLImpl, "deinit") and @hasDecl(MLImpl, "deinitOwn")) @compileError("MLImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MLImpl, "deinit")) return MLImpl.deinit(instance);
        if (comptime @hasDecl(MLImpl, "deinitOwn")) MLImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ML")) {
            if (comptime @hasDecl(impls.ML, "installHooks")) impls.ML.installHooks();
        }
    }

    pub fn call_createContext(instance: *runtime.Instance, options: webidl.Opt(MLContextOptions)) anyerror!runtime.JSValue {
        return try MLImpl.call_createContext(instance, options);
    }

    pub fn call_createContext__1(instance: *runtime.Instance, gpuDevice: *runtime.Instance) anyerror!runtime.JSValue {
        if (comptime @hasDecl(MLImpl, "call_createContext__1")) {
            return try MLImpl.call_createContext__1(instance, gpuDevice);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "createContext", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_createContext", .args = &.{.{ .kinds = &.{.dictionary}, .optionality = .optional }} },
            .{ .function = "call_createContext__1", .implemented = @hasDecl(MLImpl, "call_createContext__1"), .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "GPUDevice")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").GPUDevice.State) } else .other)} }} },
        } },
    };

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_createContext__1", 0, "GPUDevice" },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_createContext",
        "call_createContext__1",
    };
};
