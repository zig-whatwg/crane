//! Generated from: text-detection-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TextDetectorImpl = @import("impls").TextDetector;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Availability = @import("enums").Availability;
const TextDetectorOptions = @import("dictionaries").TextDetectorOptions;
const TextDetectorCreateOptions = @import("dictionaries").TextDetectorCreateOptions;
const ImageBitmapSource = @import("typedefs").ImageBitmapSource;

pub const TextDetector = struct {
    pub const Meta = struct {
        pub const name = "TextDetector";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
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
            .{ "detect", "call_detect", 1 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "availability", "call_static_availability", 1 },
            .{ "create", "call_static_create", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "availability",
            "create",
            "detect",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*TextDetectorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_detect = &call_detect,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("TextDetector has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(TextDetectorImpl, "init") and @hasDecl(TextDetectorImpl, "initOwn")) @compileError("TextDetectorImpl defines both init and initOwn");
        if (comptime @hasDecl(TextDetectorImpl, "init")) return TextDetectorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(TextDetectorImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try TextDetectorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TextDetectorImpl, "init")) return false;
        if (comptime @hasDecl(TextDetectorImpl, "construction_args")) {
            inline for (TextDetectorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(TextDetectorImpl, "deinit") and @hasDecl(TextDetectorImpl, "deinitOwn")) @compileError("TextDetectorImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(TextDetectorImpl, "deinit")) return TextDetectorImpl.deinit(instance);
        if (comptime @hasDecl(TextDetectorImpl, "deinitOwn")) TextDetectorImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "TextDetector")) {
            if (comptime @hasDecl(impls.TextDetector, "installHooks")) impls.TextDetector.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TextDetectorImpl.call_constructor(ctx);
    }

    pub fn call_static_availability(instance: *runtime.Instance, options: TextDetectorOptions) anyerror!runtime.JSValue {
        return try TextDetectorImpl.call_static_availability(instance, options);
    }

    pub fn call_static_create(instance: *runtime.Instance, options: webidl.Opt(TextDetectorCreateOptions)) anyerror!runtime.JSValue {
        return try TextDetectorImpl.call_static_create(instance, options);
    }

    pub fn call_detect(instance: *runtime.Instance, image: ImageBitmapSource) anyerror!runtime.JSValue {
        return try TextDetectorImpl.call_detect(instance, image);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_static_availability",
        "call_static_create",
        "call_detect",
    };
};
