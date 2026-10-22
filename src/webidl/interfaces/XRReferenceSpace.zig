//! Generated from: webxr.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRReferenceSpaceImpl = @import("impls").XRReferenceSpace;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRSpace = @import("interfaces").XRSpace;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const XRReferenceSpace = struct {
    pub const Meta = struct {
        pub const name = "XRReferenceSpace";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = XRSpace.State;
        pub const ParentInterface = XRSpace;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onreset", "get_onreset", "set_onreset" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getOffsetReferenceSpace", "call_getOffsetReferenceSpace", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getOffsetReferenceSpace",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onreset", "get_onreset", "set_onreset" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onreset: typedefs.EventHandler = undefined,
            _internal: ?*XRReferenceSpaceImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onreset = &get_onreset,

        .set_onreset = &set_onreset,

        .call_getOffsetReferenceSpace = &call_getOffsetReferenceSpace,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XRReferenceSpace has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XRReferenceSpaceImpl, "init") and @hasDecl(XRReferenceSpaceImpl, "initOwn")) @compileError("XRReferenceSpaceImpl defines both init and initOwn");
        if (comptime @hasDecl(XRReferenceSpaceImpl, "init")) return XRReferenceSpaceImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(XRReferenceSpaceImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try XRReferenceSpaceImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRReferenceSpaceImpl, "init")) return false;
        if (comptime @hasDecl(XRReferenceSpaceImpl, "construction_args")) {
            inline for (XRReferenceSpaceImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRReferenceSpaceImpl, "deinit") and @hasDecl(XRReferenceSpaceImpl, "deinitOwn")) @compileError("XRReferenceSpaceImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XRReferenceSpaceImpl, "deinit")) return XRReferenceSpaceImpl.deinit(instance);
        if (comptime @hasDecl(XRReferenceSpaceImpl, "deinitOwn")) XRReferenceSpaceImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRReferenceSpace")) {
            if (comptime @hasDecl(impls.XRReferenceSpace, "installHooks")) impls.XRReferenceSpace.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onreset(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(XRReferenceSpaceImpl, "get_onreset")) return try XRReferenceSpaceImpl.get_onreset(instance);
        return event_handlers.value(EventHandler, instance, "onreset");
    }

    pub fn set_onreset(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(XRReferenceSpaceImpl, "set_onreset")) return try XRReferenceSpaceImpl.set_onreset(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onreset", value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getOffsetReferenceSpace(instance: *runtime.Instance, originOffset: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try XRReferenceSpaceImpl.call_getOffsetReferenceSpace(instance, originOffset);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_onreset"};

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_getOffsetReferenceSpace", 0, "XRRigidTransform" },
    };
};
