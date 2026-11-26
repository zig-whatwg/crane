//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ElementInternalsImpl = @import("impls").ElementInternals;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ARIAMixin = @import("mixins").ARIAMixin;
const Element = @import("interfaces").Element;
const HTMLElement = @import("interfaces").HTMLElement;
const HTMLFormElement = @import("interfaces").HTMLFormElement;
const ShadowRoot = @import("interfaces").ShadowRoot;
const FileOrUSVStringOrFormData = @import("typedefs").FileOrUSVStringOrFormData;
const ValidityStateFlags = @import("dictionaries").ValidityStateFlags;
const NodeList = @import("interfaces").NodeList;
const ValidityState = @import("interfaces").ValidityState;
const CustomStateSet = @import("interfaces").CustomStateSet;
const DOMString = @import("typedefs").DOMString;

pub const ElementInternals = struct {
    pub const Meta = struct {
        pub const name = "ElementInternals";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            ARIAMixin,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "shadowRoot", "get_shadowRoot", null },
            .{ "form", "get_form", null },
            .{ "willValidate", "get_willValidate", null },
            .{ "validity", "get_validity", null },
            .{ "validationMessage", "get_validationMessage", null },
            .{ "labels", "get_labels", null },
            .{ "states", "get_states", null },
            .{ "role", "get_role", "set_role" },
            .{ "ariaActiveDescendantElement", "get_ariaActiveDescendantElement", "set_ariaActiveDescendantElement" },
            .{ "ariaAtomic", "get_ariaAtomic", "set_ariaAtomic" },
            .{ "ariaAutoComplete", "get_ariaAutoComplete", "set_ariaAutoComplete" },
            .{ "ariaBrailleLabel", "get_ariaBrailleLabel", "set_ariaBrailleLabel" },
            .{ "ariaBrailleRoleDescription", "get_ariaBrailleRoleDescription", "set_ariaBrailleRoleDescription" },
            .{ "ariaBusy", "get_ariaBusy", "set_ariaBusy" },
            .{ "ariaChecked", "get_ariaChecked", "set_ariaChecked" },
            .{ "ariaColCount", "get_ariaColCount", "set_ariaColCount" },
            .{ "ariaColIndex", "get_ariaColIndex", "set_ariaColIndex" },
            .{ "ariaColIndexText", "get_ariaColIndexText", "set_ariaColIndexText" },
            .{ "ariaColSpan", "get_ariaColSpan", "set_ariaColSpan" },
            .{ "ariaControlsElements", "get_ariaControlsElements", "set_ariaControlsElements" },
            .{ "ariaCurrent", "get_ariaCurrent", "set_ariaCurrent" },
            .{ "ariaDescribedByElements", "get_ariaDescribedByElements", "set_ariaDescribedByElements" },
            .{ "ariaDescription", "get_ariaDescription", "set_ariaDescription" },
            .{ "ariaDetailsElements", "get_ariaDetailsElements", "set_ariaDetailsElements" },
            .{ "ariaDisabled", "get_ariaDisabled", "set_ariaDisabled" },
            .{ "ariaErrorMessageElements", "get_ariaErrorMessageElements", "set_ariaErrorMessageElements" },
            .{ "ariaExpanded", "get_ariaExpanded", "set_ariaExpanded" },
            .{ "ariaFlowToElements", "get_ariaFlowToElements", "set_ariaFlowToElements" },
            .{ "ariaHasPopup", "get_ariaHasPopup", "set_ariaHasPopup" },
            .{ "ariaHidden", "get_ariaHidden", "set_ariaHidden" },
            .{ "ariaInvalid", "get_ariaInvalid", "set_ariaInvalid" },
            .{ "ariaKeyShortcuts", "get_ariaKeyShortcuts", "set_ariaKeyShortcuts" },
            .{ "ariaLabel", "get_ariaLabel", "set_ariaLabel" },
            .{ "ariaLabelledByElements", "get_ariaLabelledByElements", "set_ariaLabelledByElements" },
            .{ "ariaLevel", "get_ariaLevel", "set_ariaLevel" },
            .{ "ariaLive", "get_ariaLive", "set_ariaLive" },
            .{ "ariaModal", "get_ariaModal", "set_ariaModal" },
            .{ "ariaMultiLine", "get_ariaMultiLine", "set_ariaMultiLine" },
            .{ "ariaMultiSelectable", "get_ariaMultiSelectable", "set_ariaMultiSelectable" },
            .{ "ariaOrientation", "get_ariaOrientation", "set_ariaOrientation" },
            .{ "ariaOwnsElements", "get_ariaOwnsElements", "set_ariaOwnsElements" },
            .{ "ariaPlaceholder", "get_ariaPlaceholder", "set_ariaPlaceholder" },
            .{ "ariaPosInSet", "get_ariaPosInSet", "set_ariaPosInSet" },
            .{ "ariaPressed", "get_ariaPressed", "set_ariaPressed" },
            .{ "ariaReadOnly", "get_ariaReadOnly", "set_ariaReadOnly" },
            .{ "ariaRelevant", "get_ariaRelevant", "set_ariaRelevant" },
            .{ "ariaRequired", "get_ariaRequired", "set_ariaRequired" },
            .{ "ariaRoleDescription", "get_ariaRoleDescription", "set_ariaRoleDescription" },
            .{ "ariaRowCount", "get_ariaRowCount", "set_ariaRowCount" },
            .{ "ariaRowIndex", "get_ariaRowIndex", "set_ariaRowIndex" },
            .{ "ariaRowIndexText", "get_ariaRowIndexText", "set_ariaRowIndexText" },
            .{ "ariaRowSpan", "get_ariaRowSpan", "set_ariaRowSpan" },
            .{ "ariaSelected", "get_ariaSelected", "set_ariaSelected" },
            .{ "ariaSetSize", "get_ariaSetSize", "set_ariaSetSize" },
            .{ "ariaSort", "get_ariaSort", "set_ariaSort" },
            .{ "ariaValueMax", "get_ariaValueMax", "set_ariaValueMax" },
            .{ "ariaValueMin", "get_ariaValueMin", "set_ariaValueMin" },
            .{ "ariaValueNow", "get_ariaValueNow", "set_ariaValueNow" },
            .{ "ariaValueText", "get_ariaValueText", "set_ariaValueText" },
        };

        /// [SameObject] attributes whose child the owner keeps (in its State, its rare
        /// data or its impl): the binding ties the child's wrapper to the owner's.
        pub const same_object_attributes = .{
            "states",
        };

        /// FrozenArray<T> attributes: their getters return the array as a JSValue, and
        /// the binding gives each isolated world a frozen array of its own.
        pub const frozen_array_attributes = .{
            "ariaControlsElements",
            "ariaDescribedByElements",
            "ariaDetailsElements",
            "ariaErrorMessageElements",
            "ariaFlowToElements",
            "ariaLabelledByElements",
            "ariaOwnsElements",
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setFormValue", "call_setFormValue", 1 },
            .{ "setValidity", "call_setValidity", 0 },
            .{ "checkValidity", "call_checkValidity", 0 },
            .{ "reportValidity", "call_reportValidity", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setFormValue",
            "setValidity",
            "checkValidity",
            "reportValidity",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "shadowRoot", "get_shadowRoot", null },
            .{ "form", "get_form", null },
            .{ "willValidate", "get_willValidate", null },
            .{ "validity", "get_validity", null },
            .{ "validationMessage", "get_validationMessage", null },
            .{ "labels", "get_labels", null },
            .{ "states", "get_states", null },
            .{ "role", "get_role", "set_role" },
            .{ "ariaActiveDescendantElement", "get_ariaActiveDescendantElement", "set_ariaActiveDescendantElement" },
            .{ "ariaAtomic", "get_ariaAtomic", "set_ariaAtomic" },
            .{ "ariaAutoComplete", "get_ariaAutoComplete", "set_ariaAutoComplete" },
            .{ "ariaBrailleLabel", "get_ariaBrailleLabel", "set_ariaBrailleLabel" },
            .{ "ariaBrailleRoleDescription", "get_ariaBrailleRoleDescription", "set_ariaBrailleRoleDescription" },
            .{ "ariaBusy", "get_ariaBusy", "set_ariaBusy" },
            .{ "ariaChecked", "get_ariaChecked", "set_ariaChecked" },
            .{ "ariaColCount", "get_ariaColCount", "set_ariaColCount" },
            .{ "ariaColIndex", "get_ariaColIndex", "set_ariaColIndex" },
            .{ "ariaColIndexText", "get_ariaColIndexText", "set_ariaColIndexText" },
            .{ "ariaColSpan", "get_ariaColSpan", "set_ariaColSpan" },
            .{ "ariaControlsElements", "get_ariaControlsElements", "set_ariaControlsElements" },
            .{ "ariaCurrent", "get_ariaCurrent", "set_ariaCurrent" },
            .{ "ariaDescribedByElements", "get_ariaDescribedByElements", "set_ariaDescribedByElements" },
            .{ "ariaDescription", "get_ariaDescription", "set_ariaDescription" },
            .{ "ariaDetailsElements", "get_ariaDetailsElements", "set_ariaDetailsElements" },
            .{ "ariaDisabled", "get_ariaDisabled", "set_ariaDisabled" },
            .{ "ariaErrorMessageElements", "get_ariaErrorMessageElements", "set_ariaErrorMessageElements" },
            .{ "ariaExpanded", "get_ariaExpanded", "set_ariaExpanded" },
            .{ "ariaFlowToElements", "get_ariaFlowToElements", "set_ariaFlowToElements" },
            .{ "ariaHasPopup", "get_ariaHasPopup", "set_ariaHasPopup" },
            .{ "ariaHidden", "get_ariaHidden", "set_ariaHidden" },
            .{ "ariaInvalid", "get_ariaInvalid", "set_ariaInvalid" },
            .{ "ariaKeyShortcuts", "get_ariaKeyShortcuts", "set_ariaKeyShortcuts" },
            .{ "ariaLabel", "get_ariaLabel", "set_ariaLabel" },
            .{ "ariaLabelledByElements", "get_ariaLabelledByElements", "set_ariaLabelledByElements" },
            .{ "ariaLevel", "get_ariaLevel", "set_ariaLevel" },
            .{ "ariaLive", "get_ariaLive", "set_ariaLive" },
            .{ "ariaModal", "get_ariaModal", "set_ariaModal" },
            .{ "ariaMultiLine", "get_ariaMultiLine", "set_ariaMultiLine" },
            .{ "ariaMultiSelectable", "get_ariaMultiSelectable", "set_ariaMultiSelectable" },
            .{ "ariaOrientation", "get_ariaOrientation", "set_ariaOrientation" },
            .{ "ariaOwnsElements", "get_ariaOwnsElements", "set_ariaOwnsElements" },
            .{ "ariaPlaceholder", "get_ariaPlaceholder", "set_ariaPlaceholder" },
            .{ "ariaPosInSet", "get_ariaPosInSet", "set_ariaPosInSet" },
            .{ "ariaPressed", "get_ariaPressed", "set_ariaPressed" },
            .{ "ariaReadOnly", "get_ariaReadOnly", "set_ariaReadOnly" },
            .{ "ariaRelevant", "get_ariaRelevant", "set_ariaRelevant" },
            .{ "ariaRequired", "get_ariaRequired", "set_ariaRequired" },
            .{ "ariaRoleDescription", "get_ariaRoleDescription", "set_ariaRoleDescription" },
            .{ "ariaRowCount", "get_ariaRowCount", "set_ariaRowCount" },
            .{ "ariaRowIndex", "get_ariaRowIndex", "set_ariaRowIndex" },
            .{ "ariaRowIndexText", "get_ariaRowIndexText", "set_ariaRowIndexText" },
            .{ "ariaRowSpan", "get_ariaRowSpan", "set_ariaRowSpan" },
            .{ "ariaSelected", "get_ariaSelected", "set_ariaSelected" },
            .{ "ariaSetSize", "get_ariaSetSize", "set_ariaSetSize" },
            .{ "ariaSort", "get_ariaSort", "set_ariaSort" },
            .{ "ariaValueMax", "get_ariaValueMax", "set_ariaValueMax" },
            .{ "ariaValueMin", "get_ariaValueMin", "set_ariaValueMin" },
            .{ "ariaValueNow", "get_ariaValueNow", "set_ariaValueNow" },
            .{ "ariaValueText", "get_ariaValueText", "set_ariaValueText" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            role: ?runtime.DOMString = null,
            ariaAtomic: ?runtime.DOMString = null,
            ariaAutoComplete: ?runtime.DOMString = null,
            ariaBrailleLabel: ?runtime.DOMString = null,
            ariaBrailleRoleDescription: ?runtime.DOMString = null,
            ariaBusy: ?runtime.DOMString = null,
            ariaChecked: ?runtime.DOMString = null,
            ariaColCount: ?runtime.DOMString = null,
            ariaColIndex: ?runtime.DOMString = null,
            ariaColIndexText: ?runtime.DOMString = null,
            ariaColSpan: ?runtime.DOMString = null,
            ariaCurrent: ?runtime.DOMString = null,
            ariaDescription: ?runtime.DOMString = null,
            ariaDisabled: ?runtime.DOMString = null,
            ariaExpanded: ?runtime.DOMString = null,
            ariaHasPopup: ?runtime.DOMString = null,
            ariaHidden: ?runtime.DOMString = null,
            ariaInvalid: ?runtime.DOMString = null,
            ariaKeyShortcuts: ?runtime.DOMString = null,
            ariaLabel: ?runtime.DOMString = null,
            ariaLevel: ?runtime.DOMString = null,
            ariaLive: ?runtime.DOMString = null,
            ariaModal: ?runtime.DOMString = null,
            ariaMultiLine: ?runtime.DOMString = null,
            ariaMultiSelectable: ?runtime.DOMString = null,
            ariaOrientation: ?runtime.DOMString = null,
            ariaPlaceholder: ?runtime.DOMString = null,
            ariaPosInSet: ?runtime.DOMString = null,
            ariaPressed: ?runtime.DOMString = null,
            ariaReadOnly: ?runtime.DOMString = null,
            ariaRelevant: ?runtime.DOMString = null,
            ariaRequired: ?runtime.DOMString = null,
            ariaRoleDescription: ?runtime.DOMString = null,
            ariaRowCount: ?runtime.DOMString = null,
            ariaRowIndex: ?runtime.DOMString = null,
            ariaRowIndexText: ?runtime.DOMString = null,
            ariaRowSpan: ?runtime.DOMString = null,
            ariaSelected: ?runtime.DOMString = null,
            ariaSetSize: ?runtime.DOMString = null,
            ariaSort: ?runtime.DOMString = null,
            ariaValueMax: ?runtime.DOMString = null,
            ariaValueMin: ?runtime.DOMString = null,
            ariaValueNow: ?runtime.DOMString = null,
            ariaValueText: ?runtime.DOMString = null,
            cached_states: ?*runtime.Instance = null,
            _internal: ?*ElementInternalsImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_ariaActiveDescendantElement = &get_ariaActiveDescendantElement,
        .get_ariaAtomic = &get_ariaAtomic,
        .get_ariaAutoComplete = &get_ariaAutoComplete,
        .get_ariaBrailleLabel = &get_ariaBrailleLabel,
        .get_ariaBrailleRoleDescription = &get_ariaBrailleRoleDescription,
        .get_ariaBusy = &get_ariaBusy,
        .get_ariaChecked = &get_ariaChecked,
        .get_ariaColCount = &get_ariaColCount,
        .get_ariaColIndex = &get_ariaColIndex,
        .get_ariaColIndexText = &get_ariaColIndexText,
        .get_ariaColSpan = &get_ariaColSpan,
        .get_ariaControlsElements = &get_ariaControlsElements,
        .get_ariaCurrent = &get_ariaCurrent,
        .get_ariaDescribedByElements = &get_ariaDescribedByElements,
        .get_ariaDescription = &get_ariaDescription,
        .get_ariaDetailsElements = &get_ariaDetailsElements,
        .get_ariaDisabled = &get_ariaDisabled,
        .get_ariaErrorMessageElements = &get_ariaErrorMessageElements,
        .get_ariaExpanded = &get_ariaExpanded,
        .get_ariaFlowToElements = &get_ariaFlowToElements,
        .get_ariaHasPopup = &get_ariaHasPopup,
        .get_ariaHidden = &get_ariaHidden,
        .get_ariaInvalid = &get_ariaInvalid,
        .get_ariaKeyShortcuts = &get_ariaKeyShortcuts,
        .get_ariaLabel = &get_ariaLabel,
        .get_ariaLabelledByElements = &get_ariaLabelledByElements,
        .get_ariaLevel = &get_ariaLevel,
        .get_ariaLive = &get_ariaLive,
        .get_ariaModal = &get_ariaModal,
        .get_ariaMultiLine = &get_ariaMultiLine,
        .get_ariaMultiSelectable = &get_ariaMultiSelectable,
        .get_ariaOrientation = &get_ariaOrientation,
        .get_ariaOwnsElements = &get_ariaOwnsElements,
        .get_ariaPlaceholder = &get_ariaPlaceholder,
        .get_ariaPosInSet = &get_ariaPosInSet,
        .get_ariaPressed = &get_ariaPressed,
        .get_ariaReadOnly = &get_ariaReadOnly,
        .get_ariaRelevant = &get_ariaRelevant,
        .get_ariaRequired = &get_ariaRequired,
        .get_ariaRoleDescription = &get_ariaRoleDescription,
        .get_ariaRowCount = &get_ariaRowCount,
        .get_ariaRowIndex = &get_ariaRowIndex,
        .get_ariaRowIndexText = &get_ariaRowIndexText,
        .get_ariaRowSpan = &get_ariaRowSpan,
        .get_ariaSelected = &get_ariaSelected,
        .get_ariaSetSize = &get_ariaSetSize,
        .get_ariaSort = &get_ariaSort,
        .get_ariaValueMax = &get_ariaValueMax,
        .get_ariaValueMin = &get_ariaValueMin,
        .get_ariaValueNow = &get_ariaValueNow,
        .get_ariaValueText = &get_ariaValueText,
        .get_form = &get_form,
        .get_labels = &get_labels,
        .get_role = &get_role,
        .get_shadowRoot = &get_shadowRoot,
        .get_states = &get_states,
        .get_validationMessage = &get_validationMessage,
        .get_validity = &get_validity,
        .get_willValidate = &get_willValidate,

        .set_ariaActiveDescendantElement = &set_ariaActiveDescendantElement,
        .set_ariaAtomic = &set_ariaAtomic,
        .set_ariaAutoComplete = &set_ariaAutoComplete,
        .set_ariaBrailleLabel = &set_ariaBrailleLabel,
        .set_ariaBrailleRoleDescription = &set_ariaBrailleRoleDescription,
        .set_ariaBusy = &set_ariaBusy,
        .set_ariaChecked = &set_ariaChecked,
        .set_ariaColCount = &set_ariaColCount,
        .set_ariaColIndex = &set_ariaColIndex,
        .set_ariaColIndexText = &set_ariaColIndexText,
        .set_ariaColSpan = &set_ariaColSpan,
        .set_ariaControlsElements = &set_ariaControlsElements,
        .set_ariaCurrent = &set_ariaCurrent,
        .set_ariaDescribedByElements = &set_ariaDescribedByElements,
        .set_ariaDescription = &set_ariaDescription,
        .set_ariaDetailsElements = &set_ariaDetailsElements,
        .set_ariaDisabled = &set_ariaDisabled,
        .set_ariaErrorMessageElements = &set_ariaErrorMessageElements,
        .set_ariaExpanded = &set_ariaExpanded,
        .set_ariaFlowToElements = &set_ariaFlowToElements,
        .set_ariaHasPopup = &set_ariaHasPopup,
        .set_ariaHidden = &set_ariaHidden,
        .set_ariaInvalid = &set_ariaInvalid,
        .set_ariaKeyShortcuts = &set_ariaKeyShortcuts,
        .set_ariaLabel = &set_ariaLabel,
        .set_ariaLabelledByElements = &set_ariaLabelledByElements,
        .set_ariaLevel = &set_ariaLevel,
        .set_ariaLive = &set_ariaLive,
        .set_ariaModal = &set_ariaModal,
        .set_ariaMultiLine = &set_ariaMultiLine,
        .set_ariaMultiSelectable = &set_ariaMultiSelectable,
        .set_ariaOrientation = &set_ariaOrientation,
        .set_ariaOwnsElements = &set_ariaOwnsElements,
        .set_ariaPlaceholder = &set_ariaPlaceholder,
        .set_ariaPosInSet = &set_ariaPosInSet,
        .set_ariaPressed = &set_ariaPressed,
        .set_ariaReadOnly = &set_ariaReadOnly,
        .set_ariaRelevant = &set_ariaRelevant,
        .set_ariaRequired = &set_ariaRequired,
        .set_ariaRoleDescription = &set_ariaRoleDescription,
        .set_ariaRowCount = &set_ariaRowCount,
        .set_ariaRowIndex = &set_ariaRowIndex,
        .set_ariaRowIndexText = &set_ariaRowIndexText,
        .set_ariaRowSpan = &set_ariaRowSpan,
        .set_ariaSelected = &set_ariaSelected,
        .set_ariaSetSize = &set_ariaSetSize,
        .set_ariaSort = &set_ariaSort,
        .set_ariaValueMax = &set_ariaValueMax,
        .set_ariaValueMin = &set_ariaValueMin,
        .set_ariaValueNow = &set_ariaValueNow,
        .set_ariaValueText = &set_ariaValueText,
        .set_role = &set_role,

        .call_checkValidity = &call_checkValidity,
        .call_reportValidity = &call_reportValidity,
        .call_setFormValue = &call_setFormValue,
        .call_setValidity = &call_setValidity,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("ElementInternals has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(ElementInternalsImpl, "init") and @hasDecl(ElementInternalsImpl, "initOwn")) @compileError("ElementInternalsImpl defines both init and initOwn");
        if (comptime @hasDecl(ElementInternalsImpl, "init")) return ElementInternalsImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ElementInternalsImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ElementInternalsImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ElementInternalsImpl, "init")) return false;
        if (comptime @hasDecl(ElementInternalsImpl, "construction_args")) {
            inline for (ElementInternalsImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ElementInternalsImpl, "deinit") and @hasDecl(ElementInternalsImpl, "deinitOwn")) @compileError("ElementInternalsImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(ElementInternalsImpl, "deinit")) return ElementInternalsImpl.deinit(instance);
        if (comptime @hasDecl(ElementInternalsImpl, "deinitOwn")) ElementInternalsImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ElementInternals")) {
            if (comptime @hasDecl(impls.ElementInternals, "installHooks")) impls.ElementInternals.installHooks();
        }
    }

    pub fn get_shadowRoot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ElementInternalsImpl.get_shadowRoot(instance);
    }

    pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ElementInternalsImpl.get_form(instance);
    }

    pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
        return try ElementInternalsImpl.get_willValidate(instance);
    }

    pub fn get_validity(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ElementInternalsImpl.get_validity(instance);
    }

    pub fn get_validationMessage(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ElementInternalsImpl.get_validationMessage(instance);
    }

    pub fn get_labels(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ElementInternalsImpl.get_labels(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_states(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_states) |cached| {
            return cached;
        }
        const value = try ElementInternalsImpl.get_states(instance);
        state.own.cached_states = value;
        @import("dom").same_object_cache.made(instance, value, "states");
        return value;
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub const get_role = mixins.ARIAMixin.get_role;
    pub const set_role = mixins.ARIAMixin.set_role;

    /// Extended attributes: [CEReactions], [Reflect="aria-activedescendant"]
    pub const get_ariaActiveDescendantElement = mixins.ARIAMixin.get_ariaActiveDescendantElement;
    pub const set_ariaActiveDescendantElement = mixins.ARIAMixin.set_ariaActiveDescendantElement;

    /// Extended attributes: [CEReactions], [Reflect="aria-atomic"]
    pub const get_ariaAtomic = mixins.ARIAMixin.get_ariaAtomic;
    pub const set_ariaAtomic = mixins.ARIAMixin.set_ariaAtomic;

    /// Extended attributes: [CEReactions], [Reflect="aria-autocomplete"]
    pub const get_ariaAutoComplete = mixins.ARIAMixin.get_ariaAutoComplete;
    pub const set_ariaAutoComplete = mixins.ARIAMixin.set_ariaAutoComplete;

    /// Extended attributes: [CEReactions], [Reflect="aria-braillelabel"]
    pub const get_ariaBrailleLabel = mixins.ARIAMixin.get_ariaBrailleLabel;
    pub const set_ariaBrailleLabel = mixins.ARIAMixin.set_ariaBrailleLabel;

    /// Extended attributes: [CEReactions], [Reflect="aria-brailleroledescription"]
    pub const get_ariaBrailleRoleDescription = mixins.ARIAMixin.get_ariaBrailleRoleDescription;
    pub const set_ariaBrailleRoleDescription = mixins.ARIAMixin.set_ariaBrailleRoleDescription;

    /// Extended attributes: [CEReactions], [Reflect="aria-busy"]
    pub const get_ariaBusy = mixins.ARIAMixin.get_ariaBusy;
    pub const set_ariaBusy = mixins.ARIAMixin.set_ariaBusy;

    /// Extended attributes: [CEReactions], [Reflect="aria-checked"]
    pub const get_ariaChecked = mixins.ARIAMixin.get_ariaChecked;
    pub const set_ariaChecked = mixins.ARIAMixin.set_ariaChecked;

    /// Extended attributes: [CEReactions], [Reflect="aria-colcount"]
    pub const get_ariaColCount = mixins.ARIAMixin.get_ariaColCount;
    pub const set_ariaColCount = mixins.ARIAMixin.set_ariaColCount;

    /// Extended attributes: [CEReactions], [Reflect="aria-colindex"]
    pub const get_ariaColIndex = mixins.ARIAMixin.get_ariaColIndex;
    pub const set_ariaColIndex = mixins.ARIAMixin.set_ariaColIndex;

    /// Extended attributes: [CEReactions], [Reflect="aria-colindextext"]
    pub const get_ariaColIndexText = mixins.ARIAMixin.get_ariaColIndexText;
    pub const set_ariaColIndexText = mixins.ARIAMixin.set_ariaColIndexText;

    /// Extended attributes: [CEReactions], [Reflect="aria-colspan"]
    pub const get_ariaColSpan = mixins.ARIAMixin.get_ariaColSpan;
    pub const set_ariaColSpan = mixins.ARIAMixin.set_ariaColSpan;

    /// Extended attributes: [CEReactions], [Reflect="aria-controls"]
    pub const get_ariaControlsElements = mixins.ARIAMixin.get_ariaControlsElements;
    pub const set_ariaControlsElements = mixins.ARIAMixin.set_ariaControlsElements;

    /// Extended attributes: [CEReactions], [Reflect="aria-current"]
    pub const get_ariaCurrent = mixins.ARIAMixin.get_ariaCurrent;
    pub const set_ariaCurrent = mixins.ARIAMixin.set_ariaCurrent;

    /// Extended attributes: [CEReactions], [Reflect="aria-describedby"]
    pub const get_ariaDescribedByElements = mixins.ARIAMixin.get_ariaDescribedByElements;
    pub const set_ariaDescribedByElements = mixins.ARIAMixin.set_ariaDescribedByElements;

    /// Extended attributes: [CEReactions], [Reflect="aria-description"]
    pub const get_ariaDescription = mixins.ARIAMixin.get_ariaDescription;
    pub const set_ariaDescription = mixins.ARIAMixin.set_ariaDescription;

    /// Extended attributes: [CEReactions], [Reflect="aria-details"]
    pub const get_ariaDetailsElements = mixins.ARIAMixin.get_ariaDetailsElements;
    pub const set_ariaDetailsElements = mixins.ARIAMixin.set_ariaDetailsElements;

    /// Extended attributes: [CEReactions], [Reflect="aria-disabled"]
    pub const get_ariaDisabled = mixins.ARIAMixin.get_ariaDisabled;
    pub const set_ariaDisabled = mixins.ARIAMixin.set_ariaDisabled;

    /// Extended attributes: [CEReactions], [Reflect="aria-errormessage"]
    pub const get_ariaErrorMessageElements = mixins.ARIAMixin.get_ariaErrorMessageElements;
    pub const set_ariaErrorMessageElements = mixins.ARIAMixin.set_ariaErrorMessageElements;

    /// Extended attributes: [CEReactions], [Reflect="aria-expanded"]
    pub const get_ariaExpanded = mixins.ARIAMixin.get_ariaExpanded;
    pub const set_ariaExpanded = mixins.ARIAMixin.set_ariaExpanded;

    /// Extended attributes: [CEReactions], [Reflect="aria-flowto"]
    pub const get_ariaFlowToElements = mixins.ARIAMixin.get_ariaFlowToElements;
    pub const set_ariaFlowToElements = mixins.ARIAMixin.set_ariaFlowToElements;

    /// Extended attributes: [CEReactions], [Reflect="aria-haspopup"]
    pub const get_ariaHasPopup = mixins.ARIAMixin.get_ariaHasPopup;
    pub const set_ariaHasPopup = mixins.ARIAMixin.set_ariaHasPopup;

    /// Extended attributes: [CEReactions], [Reflect="aria-hidden"]
    pub const get_ariaHidden = mixins.ARIAMixin.get_ariaHidden;
    pub const set_ariaHidden = mixins.ARIAMixin.set_ariaHidden;

    /// Extended attributes: [CEReactions], [Reflect="aria-invalid"]
    pub const get_ariaInvalid = mixins.ARIAMixin.get_ariaInvalid;
    pub const set_ariaInvalid = mixins.ARIAMixin.set_ariaInvalid;

    /// Extended attributes: [CEReactions], [Reflect="aria-keyshortcuts"]
    pub const get_ariaKeyShortcuts = mixins.ARIAMixin.get_ariaKeyShortcuts;
    pub const set_ariaKeyShortcuts = mixins.ARIAMixin.set_ariaKeyShortcuts;

    /// Extended attributes: [CEReactions], [Reflect="aria-label"]
    pub const get_ariaLabel = mixins.ARIAMixin.get_ariaLabel;
    pub const set_ariaLabel = mixins.ARIAMixin.set_ariaLabel;

    /// Extended attributes: [CEReactions], [Reflect="aria-labelledby"]
    pub const get_ariaLabelledByElements = mixins.ARIAMixin.get_ariaLabelledByElements;
    pub const set_ariaLabelledByElements = mixins.ARIAMixin.set_ariaLabelledByElements;

    /// Extended attributes: [CEReactions], [Reflect="aria-level"]
    pub const get_ariaLevel = mixins.ARIAMixin.get_ariaLevel;
    pub const set_ariaLevel = mixins.ARIAMixin.set_ariaLevel;

    /// Extended attributes: [CEReactions], [Reflect="aria-live"]
    pub const get_ariaLive = mixins.ARIAMixin.get_ariaLive;
    pub const set_ariaLive = mixins.ARIAMixin.set_ariaLive;

    /// Extended attributes: [CEReactions], [Reflect="aria-modal"]
    pub const get_ariaModal = mixins.ARIAMixin.get_ariaModal;
    pub const set_ariaModal = mixins.ARIAMixin.set_ariaModal;

    /// Extended attributes: [CEReactions], [Reflect="aria-multiline"]
    pub const get_ariaMultiLine = mixins.ARIAMixin.get_ariaMultiLine;
    pub const set_ariaMultiLine = mixins.ARIAMixin.set_ariaMultiLine;

    /// Extended attributes: [CEReactions], [Reflect="aria-multiselectable"]
    pub const get_ariaMultiSelectable = mixins.ARIAMixin.get_ariaMultiSelectable;
    pub const set_ariaMultiSelectable = mixins.ARIAMixin.set_ariaMultiSelectable;

    /// Extended attributes: [CEReactions], [Reflect="aria-orientation"]
    pub const get_ariaOrientation = mixins.ARIAMixin.get_ariaOrientation;
    pub const set_ariaOrientation = mixins.ARIAMixin.set_ariaOrientation;

    /// Extended attributes: [CEReactions], [Reflect="aria-owns"]
    pub const get_ariaOwnsElements = mixins.ARIAMixin.get_ariaOwnsElements;
    pub const set_ariaOwnsElements = mixins.ARIAMixin.set_ariaOwnsElements;

    /// Extended attributes: [CEReactions], [Reflect="aria-placeholder"]
    pub const get_ariaPlaceholder = mixins.ARIAMixin.get_ariaPlaceholder;
    pub const set_ariaPlaceholder = mixins.ARIAMixin.set_ariaPlaceholder;

    /// Extended attributes: [CEReactions], [Reflect="aria-posinset"]
    pub const get_ariaPosInSet = mixins.ARIAMixin.get_ariaPosInSet;
    pub const set_ariaPosInSet = mixins.ARIAMixin.set_ariaPosInSet;

    /// Extended attributes: [CEReactions], [Reflect="aria-pressed"]
    pub const get_ariaPressed = mixins.ARIAMixin.get_ariaPressed;
    pub const set_ariaPressed = mixins.ARIAMixin.set_ariaPressed;

    /// Extended attributes: [CEReactions], [Reflect="aria-readonly"]
    pub const get_ariaReadOnly = mixins.ARIAMixin.get_ariaReadOnly;
    pub const set_ariaReadOnly = mixins.ARIAMixin.set_ariaReadOnly;

    /// Extended attributes: [CEReactions], [Reflect="aria-relevant"]
    pub const get_ariaRelevant = mixins.ARIAMixin.get_ariaRelevant;
    pub const set_ariaRelevant = mixins.ARIAMixin.set_ariaRelevant;

    /// Extended attributes: [CEReactions], [Reflect="aria-required"]
    pub const get_ariaRequired = mixins.ARIAMixin.get_ariaRequired;
    pub const set_ariaRequired = mixins.ARIAMixin.set_ariaRequired;

    /// Extended attributes: [CEReactions], [Reflect="aria-roledescription"]
    pub const get_ariaRoleDescription = mixins.ARIAMixin.get_ariaRoleDescription;
    pub const set_ariaRoleDescription = mixins.ARIAMixin.set_ariaRoleDescription;

    /// Extended attributes: [CEReactions], [Reflect="aria-rowcount"]
    pub const get_ariaRowCount = mixins.ARIAMixin.get_ariaRowCount;
    pub const set_ariaRowCount = mixins.ARIAMixin.set_ariaRowCount;

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindex"]
    pub const get_ariaRowIndex = mixins.ARIAMixin.get_ariaRowIndex;
    pub const set_ariaRowIndex = mixins.ARIAMixin.set_ariaRowIndex;

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindextext"]
    pub const get_ariaRowIndexText = mixins.ARIAMixin.get_ariaRowIndexText;
    pub const set_ariaRowIndexText = mixins.ARIAMixin.set_ariaRowIndexText;

    /// Extended attributes: [CEReactions], [Reflect="aria-rowspan"]
    pub const get_ariaRowSpan = mixins.ARIAMixin.get_ariaRowSpan;
    pub const set_ariaRowSpan = mixins.ARIAMixin.set_ariaRowSpan;

    /// Extended attributes: [CEReactions], [Reflect="aria-selected"]
    pub const get_ariaSelected = mixins.ARIAMixin.get_ariaSelected;
    pub const set_ariaSelected = mixins.ARIAMixin.set_ariaSelected;

    /// Extended attributes: [CEReactions], [Reflect="aria-setsize"]
    pub const get_ariaSetSize = mixins.ARIAMixin.get_ariaSetSize;
    pub const set_ariaSetSize = mixins.ARIAMixin.set_ariaSetSize;

    /// Extended attributes: [CEReactions], [Reflect="aria-sort"]
    pub const get_ariaSort = mixins.ARIAMixin.get_ariaSort;
    pub const set_ariaSort = mixins.ARIAMixin.set_ariaSort;

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemax"]
    pub const get_ariaValueMax = mixins.ARIAMixin.get_ariaValueMax;
    pub const set_ariaValueMax = mixins.ARIAMixin.set_ariaValueMax;

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemin"]
    pub const get_ariaValueMin = mixins.ARIAMixin.get_ariaValueMin;
    pub const set_ariaValueMin = mixins.ARIAMixin.set_ariaValueMin;

    /// Extended attributes: [CEReactions], [Reflect="aria-valuenow"]
    pub const get_ariaValueNow = mixins.ARIAMixin.get_ariaValueNow;
    pub const set_ariaValueNow = mixins.ARIAMixin.set_ariaValueNow;

    /// Extended attributes: [CEReactions], [Reflect="aria-valuetext"]
    pub const get_ariaValueText = mixins.ARIAMixin.get_ariaValueText;
    pub const set_ariaValueText = mixins.ARIAMixin.set_ariaValueText;

    pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
        return try ElementInternalsImpl.call_checkValidity(instance);
    }

    pub fn call_setValidity(instance: *runtime.Instance, flags: webidl.Opt(ValidityStateFlags), message: webidl.Opt(runtime.DOMString), anchor: webidl.Opt(*runtime.Instance)) anyerror!void {
        return try ElementInternalsImpl.call_setValidity(instance, flags, message, anchor);
    }

    pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
        return try ElementInternalsImpl.call_reportValidity(instance);
    }

    pub fn call_setFormValue(instance: *runtime.Instance, value: ?FileOrUSVStringOrFormData, state: webidl.Opt(?FileOrUSVStringOrFormData)) anyerror!void {
        return try ElementInternalsImpl.call_setFormValue(instance, value, state);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "set_ariaActiveDescendantElement", 0, "Element" },
        .{ "set_ariaControlsElements", 0, "Element" },
        .{ "set_ariaDescribedByElements", 0, "Element" },
        .{ "set_ariaDetailsElements", 0, "Element" },
        .{ "set_ariaErrorMessageElements", 0, "Element" },
        .{ "set_ariaFlowToElements", 0, "Element" },
        .{ "set_ariaLabelledByElements", 0, "Element" },
        .{ "set_ariaOwnsElements", 0, "Element" },
        .{ "call_setValidity", 2, "HTMLElement" },
    };

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_role",
        "set_ariaActiveDescendantElement",
        "set_ariaAtomic",
        "set_ariaAutoComplete",
        "set_ariaBrailleLabel",
        "set_ariaBrailleRoleDescription",
        "set_ariaBusy",
        "set_ariaChecked",
        "set_ariaColCount",
        "set_ariaColIndex",
        "set_ariaColIndexText",
        "set_ariaColSpan",
        "set_ariaControlsElements",
        "set_ariaCurrent",
        "set_ariaDescribedByElements",
        "set_ariaDescription",
        "set_ariaDetailsElements",
        "set_ariaDisabled",
        "set_ariaErrorMessageElements",
        "set_ariaExpanded",
        "set_ariaFlowToElements",
        "set_ariaHasPopup",
        "set_ariaHidden",
        "set_ariaInvalid",
        "set_ariaKeyShortcuts",
        "set_ariaLabel",
        "set_ariaLabelledByElements",
        "set_ariaLevel",
        "set_ariaLive",
        "set_ariaModal",
        "set_ariaMultiLine",
        "set_ariaMultiSelectable",
        "set_ariaOrientation",
        "set_ariaOwnsElements",
        "set_ariaPlaceholder",
        "set_ariaPosInSet",
        "set_ariaPressed",
        "set_ariaReadOnly",
        "set_ariaRelevant",
        "set_ariaRequired",
        "set_ariaRoleDescription",
        "set_ariaRowCount",
        "set_ariaRowIndex",
        "set_ariaRowIndexText",
        "set_ariaRowSpan",
        "set_ariaSelected",
        "set_ariaSetSize",
        "set_ariaSort",
        "set_ariaValueMax",
        "set_ariaValueMin",
        "set_ariaValueNow",
        "set_ariaValueText",
    };
};
