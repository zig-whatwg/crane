//! Generated from: sanitizer-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SanitizerImpl = @import("impls").Sanitizer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SanitizerAttribute = @import("typedefs").SanitizerAttribute;
const SanitizerPresets = @import("enums").SanitizerPresets;
const SanitizerElementWithAttributes = @import("typedefs").SanitizerElementWithAttributes;
const SanitizerConfig = @import("dictionaries").SanitizerConfig;
const SanitizerPI = @import("typedefs").SanitizerPI;
const SanitizerElement = @import("typedefs").SanitizerElement;

pub const Sanitizer = struct {
    pub const Meta = struct {
        pub const name = "Sanitizer";
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
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "get", "call_get", 0 },
            .{ "allowElement", "call_allowElement", 1 },
            .{ "removeElement", "call_removeElement", 1 },
            .{ "replaceElementWithChildren", "call_replaceElementWithChildren", 1 },
            .{ "allowAttribute", "call_allowAttribute", 1 },
            .{ "removeAttribute", "call_removeAttribute", 1 },
            .{ "setComments", "call_setComments", 1 },
            .{ "setDataAttributes", "call_setDataAttributes", 1 },
            .{ "removeUnsafe", "call_removeUnsafe", 0 },
            .{ "allowProcessingInstruction", "call_allowProcessingInstruction", 1 },
            .{ "removeProcessingInstruction", "call_removeProcessingInstruction", 1 },
            .{ "setJavascriptURLs", "call_setJavascriptURLs", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "get",
            "allowElement",
            "removeElement",
            "replaceElementWithChildren",
            "allowAttribute",
            "removeAttribute",
            "setComments",
            "setDataAttributes",
            "removeUnsafe",
            "allowProcessingInstruction",
            "removeProcessingInstruction",
            "setJavascriptURLs",
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
            _internal: ?*SanitizerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_allowAttribute = &call_allowAttribute,
        .call_allowElement = &call_allowElement,
        .call_allowProcessingInstruction = &call_allowProcessingInstruction,
        .call_get = &call_get,
        .call_removeAttribute = &call_removeAttribute,
        .call_removeElement = &call_removeElement,
        .call_removeProcessingInstruction = &call_removeProcessingInstruction,
        .call_removeUnsafe = &call_removeUnsafe,
        .call_replaceElementWithChildren = &call_replaceElementWithChildren,
        .call_setComments = &call_setComments,
        .call_setDataAttributes = &call_setDataAttributes,
        .call_setJavascriptURLs = &call_setJavascriptURLs,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Sanitizer has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SanitizerImpl, "init") and @hasDecl(SanitizerImpl, "initOwn")) @compileError("SanitizerImpl defines both init and initOwn");
        if (comptime @hasDecl(SanitizerImpl, "init")) return SanitizerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(SanitizerImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try SanitizerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SanitizerImpl, "init")) return false;
        if (comptime @hasDecl(SanitizerImpl, "construction_args")) {
            inline for (SanitizerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SanitizerImpl, "deinit") and @hasDecl(SanitizerImpl, "deinitOwn")) @compileError("SanitizerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SanitizerImpl, "deinit")) return SanitizerImpl.deinit(instance);
        if (comptime @hasDecl(SanitizerImpl, "deinitOwn")) SanitizerImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Sanitizer")) {
            if (comptime @hasDecl(impls.Sanitizer, "installHooks")) impls.Sanitizer.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, configuration: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SanitizerImpl.call_constructor(ctx, configuration);
    }

    pub fn call_removeProcessingInstruction(instance: *runtime.Instance, pi: SanitizerPI) anyerror!bool {
        return try SanitizerImpl.call_removeProcessingInstruction(instance, pi);
    }

    pub fn call_replaceElementWithChildren(instance: *runtime.Instance, element: SanitizerElement) anyerror!bool {
        return try SanitizerImpl.call_replaceElementWithChildren(instance, element);
    }

    pub fn call_get(instance: *runtime.Instance) anyerror!SanitizerConfig {
        return try SanitizerImpl.call_get(instance);
    }

    pub fn call_setJavascriptURLs(instance: *runtime.Instance, allow: bool) anyerror!bool {
        return try SanitizerImpl.call_setJavascriptURLs(instance, allow);
    }

    pub fn call_allowElement(instance: *runtime.Instance, element: SanitizerElementWithAttributes) anyerror!bool {
        return try SanitizerImpl.call_allowElement(instance, element);
    }

    pub fn call_allowAttribute(instance: *runtime.Instance, attribute: SanitizerAttribute) anyerror!bool {
        return try SanitizerImpl.call_allowAttribute(instance, attribute);
    }

    pub fn call_setDataAttributes(instance: *runtime.Instance, allow: bool) anyerror!bool {
        return try SanitizerImpl.call_setDataAttributes(instance, allow);
    }

    pub fn call_allowProcessingInstruction(instance: *runtime.Instance, pi: SanitizerPI) anyerror!bool {
        return try SanitizerImpl.call_allowProcessingInstruction(instance, pi);
    }

    pub fn call_setComments(instance: *runtime.Instance, allow: bool) anyerror!bool {
        return try SanitizerImpl.call_setComments(instance, allow);
    }

    pub fn call_removeUnsafe(instance: *runtime.Instance) anyerror!bool {
        return try SanitizerImpl.call_removeUnsafe(instance);
    }

    pub fn call_removeAttribute(instance: *runtime.Instance, attribute: SanitizerAttribute) anyerror!bool {
        return try SanitizerImpl.call_removeAttribute(instance, attribute);
    }

    pub fn call_removeElement(instance: *runtime.Instance, element: SanitizerElement) anyerror!bool {
        return try SanitizerImpl.call_removeElement(instance, element);
    }
};
