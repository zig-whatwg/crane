//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ErrorEventImpl = @import("impls").ErrorEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("interfaces").Event;
const EventTarget = @import("interfaces").EventTarget;
const ErrorEventInit = @import("dictionaries").ErrorEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const ErrorEvent = struct {
    pub const Meta = struct {
        pub const name = "ErrorEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "message", "get_message", null },
            .{ "filename", "get_filename", null },
            .{ "lineno", "get_lineno", null },
            .{ "colno", "get_colno", null },
            .{ "error", "get_error", null },
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
            .{ "message", "get_message", null },
            .{ "filename", "get_filename", null },
            .{ "lineno", "get_lineno", null },
            .{ "colno", "get_colno", null },
            .{ "error", "get_error", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            message: runtime.DOMString = undefined,
            filename: runtime.USVString = undefined,
            lineno: u32 = undefined,
            colno: u32 = undefined,
            @"error": runtime.JSValue = undefined,
            _internal: ?*ErrorEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_colno = &get_colno,
        .get_error = &get_error,
        .get_filename = &get_filename,
        .get_lineno = &get_lineno,
        .get_message = &get_message,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ErrorEvent has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ErrorEventImpl, "init") and @hasDecl(ErrorEventImpl, "initOwn")) @compileError("ErrorEventImpl defines both init and initOwn");
        if (comptime @hasDecl(ErrorEventImpl, "init")) return ErrorEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(ErrorEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try ErrorEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ErrorEventImpl, "init")) return false;
        if (comptime @hasDecl(ErrorEventImpl, "construction_args")) {
            inline for (ErrorEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ErrorEventImpl, "deinit") and @hasDecl(ErrorEventImpl, "deinitOwn")) @compileError("ErrorEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ErrorEventImpl, "deinit")) return ErrorEventImpl.deinit(instance);
        if (comptime @hasDecl(ErrorEventImpl, "deinitOwn")) ErrorEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ErrorEvent")) {
            if (comptime @hasDecl(impls.ErrorEvent, "installHooks")) impls.ErrorEvent.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(ErrorEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ErrorEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ErrorEventImpl.get_message(instance);
    }

    pub fn get_filename(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ErrorEventImpl.get_filename(instance);
    }

    pub fn get_lineno(instance: *runtime.Instance) anyerror!u32 {
        return try ErrorEventImpl.get_lineno(instance);
    }

    pub fn get_colno(instance: *runtime.Instance) anyerror!u32 {
        return try ErrorEventImpl.get_colno(instance);
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ErrorEventImpl.get_error(instance);
    }
};
