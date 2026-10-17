//! Generated from: CSP.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SecurityPolicyViolationEventImpl = @import("impls").SecurityPolicyViolationEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("interfaces").Event;
const SecurityPolicyViolationEventDisposition = @import("enums").SecurityPolicyViolationEventDisposition;
const SecurityPolicyViolationEventInit = @import("dictionaries").SecurityPolicyViolationEventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const SecurityPolicyViolationEvent = struct {
    pub const Meta = struct {
        pub const name = "SecurityPolicyViolationEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
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
            .{ "documentURI", "get_documentURI", null },
            .{ "referrer", "get_referrer", null },
            .{ "blockedURI", "get_blockedURI", null },
            .{ "effectiveDirective", "get_effectiveDirective", null },
            .{ "violatedDirective", "get_violatedDirective", null },
            .{ "originalPolicy", "get_originalPolicy", null },
            .{ "sourceFile", "get_sourceFile", null },
            .{ "sample", "get_sample", null },
            .{ "disposition", "get_disposition", null },
            .{ "statusCode", "get_statusCode", null },
            .{ "lineNumber", "get_lineNumber", null },
            .{ "columnNumber", "get_columnNumber", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "documentURI", "get_documentURI", null },
            .{ "referrer", "get_referrer", null },
            .{ "blockedURI", "get_blockedURI", null },
            .{ "effectiveDirective", "get_effectiveDirective", null },
            .{ "violatedDirective", "get_violatedDirective", null },
            .{ "originalPolicy", "get_originalPolicy", null },
            .{ "sourceFile", "get_sourceFile", null },
            .{ "sample", "get_sample", null },
            .{ "disposition", "get_disposition", null },
            .{ "statusCode", "get_statusCode", null },
            .{ "lineNumber", "get_lineNumber", null },
            .{ "columnNumber", "get_columnNumber", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            documentURI: runtime.USVString = undefined,
            referrer: runtime.USVString = undefined,
            blockedURI: runtime.USVString = undefined,
            effectiveDirective: runtime.DOMString = undefined,
            violatedDirective: runtime.DOMString = undefined,
            originalPolicy: runtime.DOMString = undefined,
            sourceFile: runtime.USVString = undefined,
            sample: runtime.DOMString = undefined,
            disposition: enums.SecurityPolicyViolationEventDisposition = undefined,
            statusCode: u16 = undefined,
            lineNumber: u32 = undefined,
            columnNumber: u32 = undefined,
            _internal: ?*SecurityPolicyViolationEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_blockedURI = &get_blockedURI,
        .get_columnNumber = &get_columnNumber,
        .get_disposition = &get_disposition,
        .get_documentURI = &get_documentURI,
        .get_effectiveDirective = &get_effectiveDirective,
        .get_lineNumber = &get_lineNumber,
        .get_originalPolicy = &get_originalPolicy,
        .get_referrer = &get_referrer,
        .get_sample = &get_sample,
        .get_sourceFile = &get_sourceFile,
        .get_statusCode = &get_statusCode,
        .get_violatedDirective = &get_violatedDirective,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SecurityPolicyViolationEvent has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SecurityPolicyViolationEventImpl, "init") and @hasDecl(SecurityPolicyViolationEventImpl, "initOwn")) @compileError("SecurityPolicyViolationEventImpl defines both init and initOwn");
        if (comptime @hasDecl(SecurityPolicyViolationEventImpl, "init")) return SecurityPolicyViolationEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SecurityPolicyViolationEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SecurityPolicyViolationEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SecurityPolicyViolationEventImpl, "init")) return false;
        if (comptime @hasDecl(SecurityPolicyViolationEventImpl, "construction_args")) {
            inline for (SecurityPolicyViolationEventImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(SecurityPolicyViolationEventImpl, "deinit") and @hasDecl(SecurityPolicyViolationEventImpl, "deinitOwn")) @compileError("SecurityPolicyViolationEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SecurityPolicyViolationEventImpl, "deinit")) return SecurityPolicyViolationEventImpl.deinit(instance);
        if (comptime @hasDecl(SecurityPolicyViolationEventImpl, "deinitOwn")) SecurityPolicyViolationEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SecurityPolicyViolationEvent")) {
            if (comptime @hasDecl(impls.SecurityPolicyViolationEvent, "installHooks")) impls.SecurityPolicyViolationEvent.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(SecurityPolicyViolationEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SecurityPolicyViolationEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_documentURI(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SecurityPolicyViolationEventImpl.get_documentURI(instance);
    }

    pub fn get_referrer(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SecurityPolicyViolationEventImpl.get_referrer(instance);
    }

    pub fn get_blockedURI(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SecurityPolicyViolationEventImpl.get_blockedURI(instance);
    }

    pub fn get_effectiveDirective(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try SecurityPolicyViolationEventImpl.get_effectiveDirective(instance);
    }

    pub fn get_violatedDirective(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try SecurityPolicyViolationEventImpl.get_violatedDirective(instance);
    }

    pub fn get_originalPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try SecurityPolicyViolationEventImpl.get_originalPolicy(instance);
    }

    pub fn get_sourceFile(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SecurityPolicyViolationEventImpl.get_sourceFile(instance);
    }

    pub fn get_sample(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try SecurityPolicyViolationEventImpl.get_sample(instance);
    }

    pub fn get_disposition(instance: *runtime.Instance) anyerror!SecurityPolicyViolationEventDisposition {
        return try SecurityPolicyViolationEventImpl.get_disposition(instance);
    }

    pub fn get_statusCode(instance: *runtime.Instance) anyerror!u16 {
        return try SecurityPolicyViolationEventImpl.get_statusCode(instance);
    }

    pub fn get_lineNumber(instance: *runtime.Instance) anyerror!u32 {
        return try SecurityPolicyViolationEventImpl.get_lineNumber(instance);
    }

    pub fn get_columnNumber(instance: *runtime.Instance) anyerror!u32 {
        return try SecurityPolicyViolationEventImpl.get_columnNumber(instance);
    }
};
