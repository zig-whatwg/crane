//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ProcessingInstructionImpl = @import("impls").ProcessingInstruction;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CharacterData = @import("interfaces").CharacterData;
const LinkStyle = @import("mixins").LinkStyle;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const Document = @import("interfaces").Document;
const Node = @import("interfaces").Node;
const NodeList = @import("interfaces").NodeList;
const USVString = @import("typedefs").USVString;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const Element = @import("interfaces").Element;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const DOMString = @import("typedefs").DOMString;

pub const ProcessingInstruction = struct {
    pub const Meta = struct {
        pub const name = "ProcessingInstruction";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CharacterData.State;
        pub const ParentInterface = CharacterData;
        pub const MixinTypes = &.{
            LinkStyle,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "target", "get_target", null },
            .{ "sheet", "get_sheet", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "hasAttributes", "call_hasAttributes", 0 },
            .{ "getAttributeNames", "call_getAttributeNames", 0 },
            .{ "getAttribute", "call_getAttribute", 1 },
            .{ "setAttribute", "call_setAttribute", 2 },
            .{ "removeAttribute", "call_removeAttribute", 1 },
            .{ "toggleAttribute", "call_toggleAttribute", 1 },
            .{ "hasAttribute", "call_hasAttribute", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "hasAttributes",
            "getAttributeNames",
            "getAttribute",
            "setAttribute",
            "removeAttribute",
            "toggleAttribute",
            "hasAttribute",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "getRootNode",
            "hasChildNodes",
            "normalize",
            "cloneNode",
            "isEqualNode",
            "isSameNode",
            "compareDocumentPosition",
            "contains",
            "lookupPrefix",
            "lookupNamespaceURI",
            "isDefaultNamespace",
            "insertBefore",
            "appendChild",
            "replaceChild",
            "removeChild",
            "substringData",
            "appendData",
            "insertData",
            "deleteData",
            "replaceData",
            "before",
            "after",
            "replaceWith",
            "remove",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "target", "get_target", null },
            .{ "sheet", "get_sheet", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            target: runtime.DOMString = undefined,
            sheet: ?*runtime.Instance = null,
            _internal: ?*ProcessingInstructionImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_sheet = &get_sheet,
        .get_target = &get_target,

        .call_getAttribute = &call_getAttribute,
        .call_getAttributeNames = &call_getAttributeNames,
        .call_hasAttribute = &call_hasAttribute,
        .call_hasAttributes = &call_hasAttributes,
        .call_removeAttribute = &call_removeAttribute,
        .call_setAttribute = &call_setAttribute,
        .call_toggleAttribute = &call_toggleAttribute,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ProcessingInstruction has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ProcessingInstructionImpl, "init") and @hasDecl(ProcessingInstructionImpl, "initOwn")) @compileError("ProcessingInstructionImpl defines both init and initOwn");
        if (comptime @hasDecl(ProcessingInstructionImpl, "init")) return ProcessingInstructionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(ProcessingInstructionImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try ProcessingInstructionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ProcessingInstructionImpl, "init")) return false;
        if (comptime @hasDecl(ProcessingInstructionImpl, "construction_args")) {
            inline for (ProcessingInstructionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ProcessingInstructionImpl, "deinit") and @hasDecl(ProcessingInstructionImpl, "deinitOwn")) @compileError("ProcessingInstructionImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ProcessingInstructionImpl, "deinit")) return ProcessingInstructionImpl.deinit(instance);
        if (comptime @hasDecl(ProcessingInstructionImpl, "deinitOwn")) ProcessingInstructionImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ProcessingInstruction")) {
            if (comptime @hasDecl(impls.ProcessingInstruction, "installHooks")) impls.ProcessingInstruction.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, target: runtime.DOMString, data: webidl.Opt(runtime.DOMString)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ProcessingInstructionImpl.call_constructor(ctx, target, data);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ProcessingInstructionImpl.get_target(instance);
    }

    pub fn get_sheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ProcessingInstructionImpl.get_sheet(instance);
    }

    pub fn call_hasAttributes(instance: *runtime.Instance) anyerror!bool {
        return try ProcessingInstructionImpl.call_hasAttributes(instance);
    }

    pub fn call_toggleAttribute(instance: *runtime.Instance, name: runtime.DOMString, force: webidl.Opt(bool)) anyerror!bool {
        return try ProcessingInstructionImpl.call_toggleAttribute(instance, name, force);
    }

    pub fn call_hasAttribute(instance: *runtime.Instance, name: runtime.DOMString) anyerror!bool {
        return try ProcessingInstructionImpl.call_hasAttribute(instance, name);
    }

    pub fn call_getAttribute(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?runtime.DOMString {
        return try ProcessingInstructionImpl.call_getAttribute(instance, name);
    }

    pub fn call_getAttributeNames(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ProcessingInstructionImpl.call_getAttributeNames(instance);
    }

    pub fn call_removeAttribute(instance: *runtime.Instance, name: runtime.DOMString) anyerror!void {
        return try ProcessingInstructionImpl.call_removeAttribute(instance, name);
    }

    pub fn call_setAttribute(instance: *runtime.Instance, name: runtime.DOMString, value: runtime.DOMString) anyerror!void {
        return try ProcessingInstructionImpl.call_setAttribute(instance, name, value);
    }
};
