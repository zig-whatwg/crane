//! Auto-generated mixin: ARIAMixin
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ARIAMixinImpl = @import("impls").ARIAMixin;

// Re-export types from impl
pub const impl = @import("impls").ARIAMixin;

pub fn get_role(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_role(instance);
}

pub fn set_role(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_role(instance, value);
}

pub fn get_ariaActiveDescendantElement(instance: *runtime.Instance) !?*runtime.Instance {
    return ARIAMixinImpl.get_ariaActiveDescendantElement(instance);
}

pub fn set_ariaActiveDescendantElement(instance: *runtime.Instance, value: *runtime.Instance) !void {
    return ARIAMixinImpl.set_ariaActiveDescendantElement(instance, value);
}

pub fn get_ariaAtomic(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaAtomic(instance);
}

pub fn set_ariaAtomic(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaAtomic(instance, value);
}

pub fn get_ariaAutoComplete(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaAutoComplete(instance);
}

pub fn set_ariaAutoComplete(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaAutoComplete(instance, value);
}

pub fn get_ariaBrailleLabel(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaBrailleLabel(instance);
}

pub fn set_ariaBrailleLabel(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaBrailleLabel(instance, value);
}

pub fn get_ariaBrailleRoleDescription(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaBrailleRoleDescription(instance);
}

pub fn set_ariaBrailleRoleDescription(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaBrailleRoleDescription(instance, value);
}

pub fn get_ariaBusy(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaBusy(instance);
}

pub fn set_ariaBusy(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaBusy(instance, value);
}

pub fn get_ariaChecked(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaChecked(instance);
}

pub fn set_ariaChecked(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaChecked(instance, value);
}

pub fn get_ariaColCount(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaColCount(instance);
}

pub fn set_ariaColCount(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaColCount(instance, value);
}

pub fn get_ariaColIndex(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaColIndex(instance);
}

pub fn set_ariaColIndex(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaColIndex(instance, value);
}

pub fn get_ariaColIndexText(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaColIndexText(instance);
}

pub fn set_ariaColIndexText(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaColIndexText(instance, value);
}

pub fn get_ariaColSpan(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaColSpan(instance);
}

pub fn set_ariaColSpan(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaColSpan(instance, value);
}

pub fn get_ariaControlsElements(instance: *runtime.Instance) anyerror!void {
    return ARIAMixinImpl.get_ariaControlsElements(instance);
}

pub fn set_ariaControlsElements(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return ARIAMixinImpl.set_ariaControlsElements(instance, value);
}

pub fn get_ariaCurrent(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaCurrent(instance);
}

pub fn set_ariaCurrent(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaCurrent(instance, value);
}

pub fn get_ariaDescribedByElements(instance: *runtime.Instance) anyerror!void {
    return ARIAMixinImpl.get_ariaDescribedByElements(instance);
}

pub fn set_ariaDescribedByElements(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return ARIAMixinImpl.set_ariaDescribedByElements(instance, value);
}

pub fn get_ariaDescription(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaDescription(instance);
}

pub fn set_ariaDescription(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaDescription(instance, value);
}

pub fn get_ariaDetailsElements(instance: *runtime.Instance) anyerror!void {
    return ARIAMixinImpl.get_ariaDetailsElements(instance);
}

pub fn set_ariaDetailsElements(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return ARIAMixinImpl.set_ariaDetailsElements(instance, value);
}

pub fn get_ariaDisabled(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaDisabled(instance);
}

pub fn set_ariaDisabled(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaDisabled(instance, value);
}

pub fn get_ariaErrorMessageElements(instance: *runtime.Instance) anyerror!void {
    return ARIAMixinImpl.get_ariaErrorMessageElements(instance);
}

pub fn set_ariaErrorMessageElements(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return ARIAMixinImpl.set_ariaErrorMessageElements(instance, value);
}

pub fn get_ariaExpanded(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaExpanded(instance);
}

pub fn set_ariaExpanded(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaExpanded(instance, value);
}

pub fn get_ariaFlowToElements(instance: *runtime.Instance) anyerror!void {
    return ARIAMixinImpl.get_ariaFlowToElements(instance);
}

pub fn set_ariaFlowToElements(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return ARIAMixinImpl.set_ariaFlowToElements(instance, value);
}

pub fn get_ariaHasPopup(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaHasPopup(instance);
}

pub fn set_ariaHasPopup(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaHasPopup(instance, value);
}

pub fn get_ariaHidden(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaHidden(instance);
}

pub fn set_ariaHidden(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaHidden(instance, value);
}

pub fn get_ariaInvalid(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaInvalid(instance);
}

pub fn set_ariaInvalid(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaInvalid(instance, value);
}

pub fn get_ariaKeyShortcuts(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaKeyShortcuts(instance);
}

pub fn set_ariaKeyShortcuts(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaKeyShortcuts(instance, value);
}

pub fn get_ariaLabel(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaLabel(instance);
}

pub fn set_ariaLabel(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaLabel(instance, value);
}

pub fn get_ariaLabelledByElements(instance: *runtime.Instance) anyerror!void {
    return ARIAMixinImpl.get_ariaLabelledByElements(instance);
}

pub fn set_ariaLabelledByElements(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return ARIAMixinImpl.set_ariaLabelledByElements(instance, value);
}

pub fn get_ariaLevel(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaLevel(instance);
}

pub fn set_ariaLevel(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaLevel(instance, value);
}

pub fn get_ariaLive(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaLive(instance);
}

pub fn set_ariaLive(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaLive(instance, value);
}

pub fn get_ariaModal(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaModal(instance);
}

pub fn set_ariaModal(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaModal(instance, value);
}

pub fn get_ariaMultiLine(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaMultiLine(instance);
}

pub fn set_ariaMultiLine(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaMultiLine(instance, value);
}

pub fn get_ariaMultiSelectable(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaMultiSelectable(instance);
}

pub fn set_ariaMultiSelectable(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaMultiSelectable(instance, value);
}

pub fn get_ariaOrientation(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaOrientation(instance);
}

pub fn set_ariaOrientation(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaOrientation(instance, value);
}

pub fn get_ariaOwnsElements(instance: *runtime.Instance) anyerror!void {
    return ARIAMixinImpl.get_ariaOwnsElements(instance);
}

pub fn set_ariaOwnsElements(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return ARIAMixinImpl.set_ariaOwnsElements(instance, value);
}

pub fn get_ariaPlaceholder(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaPlaceholder(instance);
}

pub fn set_ariaPlaceholder(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaPlaceholder(instance, value);
}

pub fn get_ariaPosInSet(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaPosInSet(instance);
}

pub fn set_ariaPosInSet(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaPosInSet(instance, value);
}

pub fn get_ariaPressed(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaPressed(instance);
}

pub fn set_ariaPressed(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaPressed(instance, value);
}

pub fn get_ariaReadOnly(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaReadOnly(instance);
}

pub fn set_ariaReadOnly(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaReadOnly(instance, value);
}

pub fn get_ariaRelevant(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaRelevant(instance);
}

pub fn set_ariaRelevant(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaRelevant(instance, value);
}

pub fn get_ariaRequired(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaRequired(instance);
}

pub fn set_ariaRequired(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaRequired(instance, value);
}

pub fn get_ariaRoleDescription(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaRoleDescription(instance);
}

pub fn set_ariaRoleDescription(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaRoleDescription(instance, value);
}

pub fn get_ariaRowCount(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaRowCount(instance);
}

pub fn set_ariaRowCount(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaRowCount(instance, value);
}

pub fn get_ariaRowIndex(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaRowIndex(instance);
}

pub fn set_ariaRowIndex(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaRowIndex(instance, value);
}

pub fn get_ariaRowIndexText(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaRowIndexText(instance);
}

pub fn set_ariaRowIndexText(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaRowIndexText(instance, value);
}

pub fn get_ariaRowSpan(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaRowSpan(instance);
}

pub fn set_ariaRowSpan(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaRowSpan(instance, value);
}

pub fn get_ariaSelected(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaSelected(instance);
}

pub fn set_ariaSelected(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaSelected(instance, value);
}

pub fn get_ariaSetSize(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaSetSize(instance);
}

pub fn set_ariaSetSize(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaSetSize(instance, value);
}

pub fn get_ariaSort(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaSort(instance);
}

pub fn set_ariaSort(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaSort(instance, value);
}

pub fn get_ariaValueMax(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaValueMax(instance);
}

pub fn set_ariaValueMax(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaValueMax(instance, value);
}

pub fn get_ariaValueMin(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaValueMin(instance);
}

pub fn set_ariaValueMin(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaValueMin(instance, value);
}

pub fn get_ariaValueNow(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaValueNow(instance);
}

pub fn set_ariaValueNow(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaValueNow(instance, value);
}

pub fn get_ariaValueText(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ARIAMixinImpl.get_ariaValueText(instance);
}

pub fn set_ariaValueText(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ARIAMixinImpl.set_ariaValueText(instance, value);
}

