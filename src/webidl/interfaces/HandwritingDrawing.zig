//! Generated from: handwriting-recognition.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HandwritingDrawingImpl = @import("impls").HandwritingDrawing;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HandwritingStroke = @import("interfaces").HandwritingStroke;

pub const HandwritingDrawing = struct {
    pub const Meta = struct {
        pub const name = "HandwritingDrawing";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "addStroke", "call_addStroke", 1 },
            .{ "removeStroke", "call_removeStroke", 1 },
            .{ "clear", "call_clear", 0 },
            .{ "getStrokes", "call_getStrokes", 0 },
            .{ "getPrediction", "call_getPrediction", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "addStroke",
            "removeStroke",
            "clear",
            "getStrokes",
            "getPrediction",
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
            _internal: ?*HandwritingDrawingImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_addStroke = &call_addStroke,
        .call_clear = &call_clear,
        .call_getPrediction = &call_getPrediction,
        .call_getStrokes = &call_getStrokes,
        .call_removeStroke = &call_removeStroke,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("HandwritingDrawing has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(HandwritingDrawingImpl, "init") and @hasDecl(HandwritingDrawingImpl, "initOwn")) @compileError("HandwritingDrawingImpl defines both init and initOwn");
        if (comptime @hasDecl(HandwritingDrawingImpl, "init")) return HandwritingDrawingImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(HandwritingDrawingImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try HandwritingDrawingImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(HandwritingDrawingImpl, "init")) return false;
        if (comptime @hasDecl(HandwritingDrawingImpl, "construction_args")) {
            inline for (HandwritingDrawingImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(HandwritingDrawingImpl, "deinit") and @hasDecl(HandwritingDrawingImpl, "deinitOwn")) @compileError("HandwritingDrawingImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(HandwritingDrawingImpl, "deinit")) return HandwritingDrawingImpl.deinit(instance);
        if (comptime @hasDecl(HandwritingDrawingImpl, "deinitOwn")) HandwritingDrawingImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "HandwritingDrawing")) {
            if (comptime @hasDecl(impls.HandwritingDrawing, "installHooks")) impls.HandwritingDrawing.installHooks();
        }
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try HandwritingDrawingImpl.call_clear(instance);
    }

    pub fn call_addStroke(instance: *runtime.Instance, stroke: *runtime.Instance) anyerror!void {
        return try HandwritingDrawingImpl.call_addStroke(instance, stroke);
    }

    pub fn call_getStrokes(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try HandwritingDrawingImpl.call_getStrokes(instance);
    }

    pub fn call_getPrediction(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try HandwritingDrawingImpl.call_getPrediction(instance);
    }

    pub fn call_removeStroke(instance: *runtime.Instance, stroke: *runtime.Instance) anyerror!void {
        return try HandwritingDrawingImpl.call_removeStroke(instance, stroke);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_addStroke", 0, "HandwritingStroke" },
        .{ "call_removeStroke", 0, "HandwritingStroke" },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_getPrediction",
    };
};
