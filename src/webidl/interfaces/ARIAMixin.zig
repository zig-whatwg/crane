//! Generated from: wai-aria.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ARIAMixinImpl = @import("impls").ARIAMixin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("Element.zig").Element;
const DOMString = @import("typedefs").DOMString;

pub const ARIAMixin = struct {
    pub const Meta = struct {
        pub const name = "ARIAMixin";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            role: ?typedefs.DOMString = null,
            ariaActiveDescendantElement: ?*runtime.Instance = null,
            ariaAtomic: ?typedefs.DOMString = null,
            ariaAutoComplete: ?typedefs.DOMString = null,
            ariaBrailleLabel: ?typedefs.DOMString = null,
            ariaBrailleRoleDescription: ?typedefs.DOMString = null,
            ariaBusy: ?typedefs.DOMString = null,
            ariaChecked: ?typedefs.DOMString = null,
            ariaColCount: ?typedefs.DOMString = null,
            ariaColIndex: ?typedefs.DOMString = null,
            ariaColIndexText: ?typedefs.DOMString = null,
            ariaColSpan: ?typedefs.DOMString = null,
            ariaControlsElements: ?runtime.JSValue = null,
            ariaCurrent: ?typedefs.DOMString = null,
            ariaDescribedByElements: ?runtime.JSValue = null,
            ariaDescription: ?typedefs.DOMString = null,
            ariaDetailsElements: ?runtime.JSValue = null,
            ariaDisabled: ?typedefs.DOMString = null,
            ariaErrorMessageElements: ?runtime.JSValue = null,
            ariaExpanded: ?typedefs.DOMString = null,
            ariaFlowToElements: ?runtime.JSValue = null,
            ariaHasPopup: ?typedefs.DOMString = null,
            ariaHidden: ?typedefs.DOMString = null,
            ariaInvalid: ?typedefs.DOMString = null,
            ariaKeyShortcuts: ?typedefs.DOMString = null,
            ariaLabel: ?typedefs.DOMString = null,
            ariaLabelledByElements: ?runtime.JSValue = null,
            ariaLevel: ?typedefs.DOMString = null,
            ariaLive: ?typedefs.DOMString = null,
            ariaModal: ?typedefs.DOMString = null,
            ariaMultiLine: ?typedefs.DOMString = null,
            ariaMultiSelectable: ?typedefs.DOMString = null,
            ariaOrientation: ?typedefs.DOMString = null,
            ariaOwnsElements: ?runtime.JSValue = null,
            ariaPlaceholder: ?typedefs.DOMString = null,
            ariaPosInSet: ?typedefs.DOMString = null,
            ariaPressed: ?typedefs.DOMString = null,
            ariaReadOnly: ?typedefs.DOMString = null,
            ariaRelevant: ?typedefs.DOMString = null,
            ariaRequired: ?typedefs.DOMString = null,
            ariaRoleDescription: ?typedefs.DOMString = null,
            ariaRowCount: ?typedefs.DOMString = null,
            ariaRowIndex: ?typedefs.DOMString = null,
            ariaRowIndexText: ?typedefs.DOMString = null,
            ariaRowSpan: ?typedefs.DOMString = null,
            ariaSelected: ?typedefs.DOMString = null,
            ariaSetSize: ?typedefs.DOMString = null,
            ariaSort: ?typedefs.DOMString = null,
            ariaValueMax: ?typedefs.DOMString = null,
            ariaValueMin: ?typedefs.DOMString = null,
            ariaValueNow: ?typedefs.DOMString = null,
            ariaValueText: ?typedefs.DOMString = null,
            _internal: ?*ARIAMixinImpl.InternalState = null,
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
        .get_role = &get_role,

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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ARIAMixinImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ARIAMixinImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ARIAMixinImpl.deinit(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_role(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_role(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_role(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_role(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-activedescendant"]
    pub fn get_ariaActiveDescendantElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ARIAMixinImpl.get_ariaActiveDescendantElement(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-activedescendant"]
    pub fn set_ariaActiveDescendantElement(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaActiveDescendantElement(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-atomic"]
    pub fn get_ariaAtomic(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaAtomic(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-atomic"]
    pub fn set_ariaAtomic(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaAtomic(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-autocomplete"]
    pub fn get_ariaAutoComplete(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaAutoComplete(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-autocomplete"]
    pub fn set_ariaAutoComplete(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaAutoComplete(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-braillelabel"]
    pub fn get_ariaBrailleLabel(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaBrailleLabel(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-braillelabel"]
    pub fn set_ariaBrailleLabel(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaBrailleLabel(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-brailleroledescription"]
    pub fn get_ariaBrailleRoleDescription(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaBrailleRoleDescription(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-brailleroledescription"]
    pub fn set_ariaBrailleRoleDescription(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaBrailleRoleDescription(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-busy"]
    pub fn get_ariaBusy(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaBusy(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-busy"]
    pub fn set_ariaBusy(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaBusy(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-checked"]
    pub fn get_ariaChecked(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaChecked(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-checked"]
    pub fn set_ariaChecked(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaChecked(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colcount"]
    pub fn get_ariaColCount(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaColCount(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colcount"]
    pub fn set_ariaColCount(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaColCount(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindex"]
    pub fn get_ariaColIndex(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaColIndex(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindex"]
    pub fn set_ariaColIndex(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaColIndex(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindextext"]
    pub fn get_ariaColIndexText(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaColIndexText(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindextext"]
    pub fn set_ariaColIndexText(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaColIndexText(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colspan"]
    pub fn get_ariaColSpan(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaColSpan(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colspan"]
    pub fn set_ariaColSpan(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaColSpan(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-controls"]
    pub fn get_ariaControlsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ARIAMixinImpl.get_ariaControlsElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-controls"]
    pub fn set_ariaControlsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaControlsElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-current"]
    pub fn get_ariaCurrent(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaCurrent(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-current"]
    pub fn set_ariaCurrent(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaCurrent(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-describedby"]
    pub fn get_ariaDescribedByElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ARIAMixinImpl.get_ariaDescribedByElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-describedby"]
    pub fn set_ariaDescribedByElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaDescribedByElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-description"]
    pub fn get_ariaDescription(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaDescription(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-description"]
    pub fn set_ariaDescription(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaDescription(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-details"]
    pub fn get_ariaDetailsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ARIAMixinImpl.get_ariaDetailsElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-details"]
    pub fn set_ariaDetailsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaDetailsElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-disabled"]
    pub fn get_ariaDisabled(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaDisabled(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-disabled"]
    pub fn set_ariaDisabled(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaDisabled(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-errormessage"]
    pub fn get_ariaErrorMessageElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ARIAMixinImpl.get_ariaErrorMessageElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-errormessage"]
    pub fn set_ariaErrorMessageElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaErrorMessageElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-expanded"]
    pub fn get_ariaExpanded(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaExpanded(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-expanded"]
    pub fn set_ariaExpanded(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaExpanded(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-flowto"]
    pub fn get_ariaFlowToElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ARIAMixinImpl.get_ariaFlowToElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-flowto"]
    pub fn set_ariaFlowToElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaFlowToElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-haspopup"]
    pub fn get_ariaHasPopup(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaHasPopup(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-haspopup"]
    pub fn set_ariaHasPopup(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaHasPopup(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-hidden"]
    pub fn get_ariaHidden(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaHidden(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-hidden"]
    pub fn set_ariaHidden(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaHidden(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-invalid"]
    pub fn get_ariaInvalid(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaInvalid(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-invalid"]
    pub fn set_ariaInvalid(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaInvalid(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-keyshortcuts"]
    pub fn get_ariaKeyShortcuts(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaKeyShortcuts(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-keyshortcuts"]
    pub fn set_ariaKeyShortcuts(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaKeyShortcuts(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-label"]
    pub fn get_ariaLabel(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaLabel(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-label"]
    pub fn set_ariaLabel(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaLabel(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-labelledby"]
    pub fn get_ariaLabelledByElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ARIAMixinImpl.get_ariaLabelledByElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-labelledby"]
    pub fn set_ariaLabelledByElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaLabelledByElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-level"]
    pub fn get_ariaLevel(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaLevel(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-level"]
    pub fn set_ariaLevel(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaLevel(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-live"]
    pub fn get_ariaLive(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaLive(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-live"]
    pub fn set_ariaLive(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaLive(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-modal"]
    pub fn get_ariaModal(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaModal(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-modal"]
    pub fn set_ariaModal(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaModal(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiline"]
    pub fn get_ariaMultiLine(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaMultiLine(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiline"]
    pub fn set_ariaMultiLine(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaMultiLine(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiselectable"]
    pub fn get_ariaMultiSelectable(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaMultiSelectable(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiselectable"]
    pub fn set_ariaMultiSelectable(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaMultiSelectable(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-orientation"]
    pub fn get_ariaOrientation(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaOrientation(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-orientation"]
    pub fn set_ariaOrientation(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaOrientation(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-owns"]
    pub fn get_ariaOwnsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ARIAMixinImpl.get_ariaOwnsElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-owns"]
    pub fn set_ariaOwnsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaOwnsElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-placeholder"]
    pub fn get_ariaPlaceholder(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaPlaceholder(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-placeholder"]
    pub fn set_ariaPlaceholder(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaPlaceholder(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-posinset"]
    pub fn get_ariaPosInSet(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaPosInSet(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-posinset"]
    pub fn set_ariaPosInSet(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaPosInSet(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-pressed"]
    pub fn get_ariaPressed(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaPressed(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-pressed"]
    pub fn set_ariaPressed(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaPressed(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-readonly"]
    pub fn get_ariaReadOnly(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaReadOnly(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-readonly"]
    pub fn set_ariaReadOnly(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaReadOnly(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-relevant"]
    pub fn get_ariaRelevant(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaRelevant(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-relevant"]
    pub fn set_ariaRelevant(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaRelevant(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-required"]
    pub fn get_ariaRequired(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaRequired(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-required"]
    pub fn set_ariaRequired(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaRequired(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-roledescription"]
    pub fn get_ariaRoleDescription(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaRoleDescription(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-roledescription"]
    pub fn set_ariaRoleDescription(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaRoleDescription(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowcount"]
    pub fn get_ariaRowCount(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaRowCount(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowcount"]
    pub fn set_ariaRowCount(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaRowCount(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindex"]
    pub fn get_ariaRowIndex(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaRowIndex(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindex"]
    pub fn set_ariaRowIndex(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaRowIndex(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindextext"]
    pub fn get_ariaRowIndexText(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaRowIndexText(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindextext"]
    pub fn set_ariaRowIndexText(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaRowIndexText(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowspan"]
    pub fn get_ariaRowSpan(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaRowSpan(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowspan"]
    pub fn set_ariaRowSpan(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaRowSpan(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-selected"]
    pub fn get_ariaSelected(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaSelected(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-selected"]
    pub fn set_ariaSelected(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaSelected(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-setsize"]
    pub fn get_ariaSetSize(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaSetSize(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-setsize"]
    pub fn set_ariaSetSize(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaSetSize(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-sort"]
    pub fn get_ariaSort(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaSort(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-sort"]
    pub fn set_ariaSort(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaSort(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemax"]
    pub fn get_ariaValueMax(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaValueMax(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemax"]
    pub fn set_ariaValueMax(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaValueMax(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemin"]
    pub fn get_ariaValueMin(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaValueMin(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemin"]
    pub fn set_ariaValueMin(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaValueMin(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuenow"]
    pub fn get_ariaValueNow(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaValueNow(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuenow"]
    pub fn set_ariaValueNow(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaValueNow(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuetext"]
    pub fn get_ariaValueText(instance: *runtime.Instance) anyerror!?DOMString {
        return try ARIAMixinImpl.get_ariaValueText(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuetext"]
    pub fn set_ariaValueText(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ARIAMixinImpl.set_ariaValueText(instance, value);
    }

};
