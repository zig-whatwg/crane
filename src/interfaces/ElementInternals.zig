//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ElementInternalsImpl = @import("../impls/ElementInternals.zig");
const ARIAMixin = @import("ARIAMixin.zig");

pub const ElementInternals = struct {
    pub const Meta = struct {
        pub const name = "ElementInternals";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            ARIAMixin,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            shadowRoot: ?ShadowRoot = null,
            form: ?HTMLFormElement = null,
            willValidate: bool = undefined,
            validity: ValidityState = undefined,
            validationMessage: runtime.DOMString = undefined,
            labels: NodeList = undefined,
            states: CustomStateSet = undefined,
            role: ?runtime.DOMString = null,
            ariaActiveDescendantElement: ?Element = null,
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
            ariaControlsElements: ?FrozenArray<Element> = null,
            ariaCurrent: ?runtime.DOMString = null,
            ariaDescribedByElements: ?FrozenArray<Element> = null,
            ariaDescription: ?runtime.DOMString = null,
            ariaDetailsElements: ?FrozenArray<Element> = null,
            ariaDisabled: ?runtime.DOMString = null,
            ariaErrorMessageElements: ?FrozenArray<Element> = null,
            ariaExpanded: ?runtime.DOMString = null,
            ariaFlowToElements: ?FrozenArray<Element> = null,
            ariaHasPopup: ?runtime.DOMString = null,
            ariaHidden: ?runtime.DOMString = null,
            ariaInvalid: ?runtime.DOMString = null,
            ariaKeyShortcuts: ?runtime.DOMString = null,
            ariaLabel: ?runtime.DOMString = null,
            ariaLabelledByElements: ?FrozenArray<Element> = null,
            ariaLevel: ?runtime.DOMString = null,
            ariaLive: ?runtime.DOMString = null,
            ariaModal: ?runtime.DOMString = null,
            ariaMultiLine: ?runtime.DOMString = null,
            ariaMultiSelectable: ?runtime.DOMString = null,
            ariaOrientation: ?runtime.DOMString = null,
            ariaOwnsElements: ?FrozenArray<Element> = null,
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
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ElementInternals, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ElementInternalsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ElementInternalsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_shadowRoot(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_shadowRoot(state);
    }

    pub fn get_form(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_form(state);
    }

    pub fn get_willValidate(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_willValidate(state);
    }

    pub fn get_validity(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_validity(state);
    }

    pub fn get_validationMessage(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_validationMessage(state);
    }

    pub fn get_labels(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_labels(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_states(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_states) |cached| {
            return cached;
        }
        const value = ElementInternalsImpl.get_states(state);
        state.cached_states = value;
        return value;
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_role(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_role(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_role(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_role(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-activedescendant"]
    pub fn get_ariaActiveDescendantElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaActiveDescendantElement(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-activedescendant"]
    pub fn set_ariaActiveDescendantElement(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaActiveDescendantElement(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-atomic"]
    pub fn get_ariaAtomic(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaAtomic(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-atomic"]
    pub fn set_ariaAtomic(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaAtomic(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-autocomplete"]
    pub fn get_ariaAutoComplete(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaAutoComplete(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-autocomplete"]
    pub fn set_ariaAutoComplete(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaAutoComplete(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-braillelabel"]
    pub fn get_ariaBrailleLabel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaBrailleLabel(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-braillelabel"]
    pub fn set_ariaBrailleLabel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaBrailleLabel(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-brailleroledescription"]
    pub fn get_ariaBrailleRoleDescription(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaBrailleRoleDescription(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-brailleroledescription"]
    pub fn set_ariaBrailleRoleDescription(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaBrailleRoleDescription(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-busy"]
    pub fn get_ariaBusy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaBusy(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-busy"]
    pub fn set_ariaBusy(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaBusy(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-checked"]
    pub fn get_ariaChecked(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaChecked(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-checked"]
    pub fn set_ariaChecked(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaChecked(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colcount"]
    pub fn get_ariaColCount(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaColCount(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colcount"]
    pub fn set_ariaColCount(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaColCount(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindex"]
    pub fn get_ariaColIndex(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaColIndex(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindex"]
    pub fn set_ariaColIndex(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaColIndex(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindextext"]
    pub fn get_ariaColIndexText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaColIndexText(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindextext"]
    pub fn set_ariaColIndexText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaColIndexText(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colspan"]
    pub fn get_ariaColSpan(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaColSpan(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colspan"]
    pub fn set_ariaColSpan(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaColSpan(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-controls"]
    pub fn get_ariaControlsElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaControlsElements(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-controls"]
    pub fn set_ariaControlsElements(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaControlsElements(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-current"]
    pub fn get_ariaCurrent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaCurrent(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-current"]
    pub fn set_ariaCurrent(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaCurrent(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-describedby"]
    pub fn get_ariaDescribedByElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaDescribedByElements(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-describedby"]
    pub fn set_ariaDescribedByElements(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaDescribedByElements(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-description"]
    pub fn get_ariaDescription(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaDescription(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-description"]
    pub fn set_ariaDescription(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaDescription(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-details"]
    pub fn get_ariaDetailsElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaDetailsElements(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-details"]
    pub fn set_ariaDetailsElements(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaDetailsElements(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-disabled"]
    pub fn get_ariaDisabled(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaDisabled(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-disabled"]
    pub fn set_ariaDisabled(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaDisabled(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-errormessage"]
    pub fn get_ariaErrorMessageElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaErrorMessageElements(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-errormessage"]
    pub fn set_ariaErrorMessageElements(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaErrorMessageElements(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-expanded"]
    pub fn get_ariaExpanded(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaExpanded(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-expanded"]
    pub fn set_ariaExpanded(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaExpanded(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-flowto"]
    pub fn get_ariaFlowToElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaFlowToElements(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-flowto"]
    pub fn set_ariaFlowToElements(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaFlowToElements(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-haspopup"]
    pub fn get_ariaHasPopup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaHasPopup(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-haspopup"]
    pub fn set_ariaHasPopup(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaHasPopup(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-hidden"]
    pub fn get_ariaHidden(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaHidden(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-hidden"]
    pub fn set_ariaHidden(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaHidden(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-invalid"]
    pub fn get_ariaInvalid(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaInvalid(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-invalid"]
    pub fn set_ariaInvalid(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaInvalid(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-keyshortcuts"]
    pub fn get_ariaKeyShortcuts(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaKeyShortcuts(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-keyshortcuts"]
    pub fn set_ariaKeyShortcuts(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaKeyShortcuts(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-label"]
    pub fn get_ariaLabel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaLabel(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-label"]
    pub fn set_ariaLabel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaLabel(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-labelledby"]
    pub fn get_ariaLabelledByElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaLabelledByElements(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-labelledby"]
    pub fn set_ariaLabelledByElements(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaLabelledByElements(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-level"]
    pub fn get_ariaLevel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaLevel(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-level"]
    pub fn set_ariaLevel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaLevel(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-live"]
    pub fn get_ariaLive(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaLive(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-live"]
    pub fn set_ariaLive(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaLive(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-modal"]
    pub fn get_ariaModal(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaModal(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-modal"]
    pub fn set_ariaModal(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaModal(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiline"]
    pub fn get_ariaMultiLine(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaMultiLine(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiline"]
    pub fn set_ariaMultiLine(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaMultiLine(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiselectable"]
    pub fn get_ariaMultiSelectable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaMultiSelectable(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiselectable"]
    pub fn set_ariaMultiSelectable(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaMultiSelectable(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-orientation"]
    pub fn get_ariaOrientation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaOrientation(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-orientation"]
    pub fn set_ariaOrientation(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaOrientation(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-owns"]
    pub fn get_ariaOwnsElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaOwnsElements(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-owns"]
    pub fn set_ariaOwnsElements(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaOwnsElements(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-placeholder"]
    pub fn get_ariaPlaceholder(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaPlaceholder(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-placeholder"]
    pub fn set_ariaPlaceholder(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaPlaceholder(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-posinset"]
    pub fn get_ariaPosInSet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaPosInSet(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-posinset"]
    pub fn set_ariaPosInSet(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaPosInSet(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-pressed"]
    pub fn get_ariaPressed(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaPressed(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-pressed"]
    pub fn set_ariaPressed(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaPressed(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-readonly"]
    pub fn get_ariaReadOnly(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaReadOnly(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-readonly"]
    pub fn set_ariaReadOnly(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaReadOnly(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-relevant"]
    pub fn get_ariaRelevant(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaRelevant(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-relevant"]
    pub fn set_ariaRelevant(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaRelevant(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-required"]
    pub fn get_ariaRequired(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaRequired(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-required"]
    pub fn set_ariaRequired(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaRequired(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-roledescription"]
    pub fn get_ariaRoleDescription(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaRoleDescription(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-roledescription"]
    pub fn set_ariaRoleDescription(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaRoleDescription(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowcount"]
    pub fn get_ariaRowCount(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaRowCount(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowcount"]
    pub fn set_ariaRowCount(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaRowCount(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindex"]
    pub fn get_ariaRowIndex(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaRowIndex(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindex"]
    pub fn set_ariaRowIndex(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaRowIndex(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindextext"]
    pub fn get_ariaRowIndexText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaRowIndexText(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindextext"]
    pub fn set_ariaRowIndexText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaRowIndexText(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowspan"]
    pub fn get_ariaRowSpan(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaRowSpan(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowspan"]
    pub fn set_ariaRowSpan(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaRowSpan(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-selected"]
    pub fn get_ariaSelected(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaSelected(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-selected"]
    pub fn set_ariaSelected(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaSelected(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-setsize"]
    pub fn get_ariaSetSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaSetSize(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-setsize"]
    pub fn set_ariaSetSize(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaSetSize(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-sort"]
    pub fn get_ariaSort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaSort(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-sort"]
    pub fn set_ariaSort(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaSort(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemax"]
    pub fn get_ariaValueMax(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaValueMax(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemax"]
    pub fn set_ariaValueMax(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaValueMax(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemin"]
    pub fn get_ariaValueMin(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaValueMin(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemin"]
    pub fn set_ariaValueMin(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaValueMin(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuenow"]
    pub fn get_ariaValueNow(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaValueNow(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuenow"]
    pub fn set_ariaValueNow(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaValueNow(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuetext"]
    pub fn get_ariaValueText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ElementInternalsImpl.get_ariaValueText(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuetext"]
    pub fn set_ariaValueText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        ElementInternalsImpl.set_ariaValueText(state, value);
    }

    pub fn call_setValidity(instance: *runtime.Instance, flags: anyopaque, message: runtime.DOMString, anchor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ElementInternalsImpl.call_setValidity(state, flags, message, anchor);
    }

    pub fn call_checkValidity(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ElementInternalsImpl.call_checkValidity(state);
    }

    pub fn call_reportValidity(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ElementInternalsImpl.call_reportValidity(state);
    }

    pub fn call_setFormValue(instance: *runtime.Instance, value: anyopaque, state: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ElementInternalsImpl.call_setFormValue(state, value, state);
    }

};
