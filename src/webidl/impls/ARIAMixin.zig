//! Implementation for the ARIAMixin mixin (WAI-ARIA §10.2 / HTML §2.6.1):
//! role, the 43 string ARIA attributes, ariaActiveDescendantElement, and the
//! 7 ARIA element-array reflection attributes, shared by Element and
//! ElementInternals.
//!
//! Element reflects string attributes into its content attributes via
//! dom.reflection and element references via its rare-data `.references` block
//! (dom.element_references). ElementInternals reflects into its own internal
//! ARIA maps via dom.element_references.InternalsAria.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const rare_data = dom.node_rare_data;
const ARIAMixin = interfaces.ARIAMixin;

pub const State = ARIAMixin.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    TypeError,
    OutOfMemory,
};

pub const InternalState = struct {};

fn ensureElementReferences(instance: *runtime.Instance) !*dom.element_references.State {
    const a = rare_data.access(instance) orelse return error.InvalidStateError;
    return rare_data.ensureOwn(rare_data.contextOf(instance), a.holder, .references);
}

fn getString(instance: *runtime.Instance, comptime attr: []const u8, comptime idl_name: []const u8) anyerror!?runtime.DOMString {
    if (instance.stateAs(interfaces.Element.State) != null) {
        return dom.reflection.get(?runtime.DOMString, instance, .{ .name = attr });
    }
    if (instance.stateAs(interfaces.ElementInternals.State) != null) {
        return dom.element_references.internalsGetString(instance, idl_name);
    }
    return error.InvalidStateError;
}

fn setString(instance: *runtime.Instance, comptime attr: []const u8, comptime idl_name: []const u8, value: ?runtime.DOMString) anyerror!void {
    if (instance.stateAs(interfaces.Element.State) != null) {
        return dom.reflection.set(?runtime.DOMString, instance, .{ .name = attr }, value);
    }
    if (instance.stateAs(interfaces.ElementInternals.State) != null) {
        return dom.element_references.internalsSetString(instance, idl_name, value);
    }
    return error.InvalidStateError;
}

fn getElements(instance: *runtime.Instance, comptime attr: []const u8, comptime index: usize) anyerror!?runtime.JSValue {
    if (instance.stateAs(interfaces.Element.State) != null) {
        return dom.element_references.getArray(instance, try ensureElementReferences(instance), runtime.allocatorOf(instance), attr);
    }
    if (instance.stateAs(interfaces.ElementInternals.State) != null) {
        return dom.element_references.internalsGetElements(instance, index);
    }
    return error.InvalidStateError;
}

fn setElements(instance: *runtime.Instance, comptime attr: []const u8, comptime index: usize, value: ?runtime.JSValue) anyerror!void {
    if (instance.stateAs(interfaces.Element.State) != null) {
        const input = value orelse {
            dom.element_attributes.remove(instance, null, attr);
            return;
        };
        const weak = dom.custom_elements.KeptInstance.of(instance);
        if (rare_data.access(instance) == null) return error.InvalidStateError;
        const allocator = runtime.allocatorOf(instance);
        var converted = try dom.element_references.Converted.init(engine.currentRealm() orelse instance.ctx, allocator, input);
        defer converted.deinit();
        // Iteration can run script, reenter the setter or close the owner realm.
        _ = weak.get() orelse return error.InvalidStateError;
        try dom.element_references.setArray(instance, try ensureElementReferences(instance), allocator, attr, converted.nodes.toSlice());
        return;
    }
    if (instance.stateAs(interfaces.ElementInternals.State) != null) {
        return dom.element_references.internalsSetElements(instance, index, value);
    }
    return error.InvalidStateError;
}

// =============================================================================
// Element reference attributes (single + 7 arrays)
// =============================================================================

pub fn get_ariaActiveDescendantElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    if (instance.stateAs(interfaces.Element.State) != null) {
        return dom.element_references.getSingle(instance, rare_data.get(rare_data.of(instance), .references));
    }
    if (instance.stateAs(interfaces.ElementInternals.State) != null) {
        return dom.element_references.internalsGetActiveDescendant(instance);
    }
    return error.InvalidStateError;
}

pub fn set_ariaActiveDescendantElement(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    if (instance.stateAs(interfaces.Element.State) != null) {
        const a = rare_data.access(instance) orelse return error.InvalidStateError;
        const target = value orelse {
            if (rare_data.get(a.holder.*, .references)) |refs| refs.single = null;
            dom.element_attributes.remove(instance, null, "aria-activedescendant");
            return;
        };
        if (target.stateAs(interfaces.Element.State) == null) return error.TypeError;
        const refs = try ensureElementReferences(instance);
        try dom.element_attributes.set(instance, "aria-activedescendant", "", .{});
        refs.single = dom.custom_elements.KeptInstance.of(target);
        return;
    }
    if (instance.stateAs(interfaces.ElementInternals.State) != null) {
        return dom.element_references.internalsSetActiveDescendant(instance, value);
    }
    return error.InvalidStateError;
}

pub fn get_ariaControlsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return getElements(instance, "aria-controls", 0);
}
pub fn set_ariaControlsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    return setElements(instance, "aria-controls", 0, value);
}

pub fn get_ariaDescribedByElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return getElements(instance, "aria-describedby", 1);
}
pub fn set_ariaDescribedByElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    return setElements(instance, "aria-describedby", 1, value);
}

pub fn get_ariaDetailsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return getElements(instance, "aria-details", 2);
}
pub fn set_ariaDetailsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    return setElements(instance, "aria-details", 2, value);
}

pub fn get_ariaErrorMessageElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return getElements(instance, "aria-errormessage", 3);
}
pub fn set_ariaErrorMessageElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    return setElements(instance, "aria-errormessage", 3, value);
}

pub fn get_ariaFlowToElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return getElements(instance, "aria-flowto", 4);
}
pub fn set_ariaFlowToElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    return setElements(instance, "aria-flowto", 4, value);
}

pub fn get_ariaLabelledByElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return getElements(instance, "aria-labelledby", 5);
}
pub fn set_ariaLabelledByElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    return setElements(instance, "aria-labelledby", 5, value);
}

pub fn get_ariaOwnsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return getElements(instance, "aria-owns", 6);
}
pub fn set_ariaOwnsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    return setElements(instance, "aria-owns", 6, value);
}

// =============================================================================
// String ARIA attributes (44 pairs)
// =============================================================================

pub fn get_role(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "role", "role");
}
pub fn set_role(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "role", "role", value);
}

pub fn get_ariaAtomic(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-atomic", "ariaAtomic");
}
pub fn set_ariaAtomic(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-atomic", "ariaAtomic", value);
}

pub fn get_ariaAutoComplete(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-autocomplete", "ariaAutoComplete");
}
pub fn set_ariaAutoComplete(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-autocomplete", "ariaAutoComplete", value);
}

pub fn get_ariaBrailleLabel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-braillelabel", "ariaBrailleLabel");
}
pub fn set_ariaBrailleLabel(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-braillelabel", "ariaBrailleLabel", value);
}

pub fn get_ariaBrailleRoleDescription(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-brailleroledescription", "ariaBrailleRoleDescription");
}
pub fn set_ariaBrailleRoleDescription(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-brailleroledescription", "ariaBrailleRoleDescription", value);
}

pub fn get_ariaBusy(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-busy", "ariaBusy");
}
pub fn set_ariaBusy(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-busy", "ariaBusy", value);
}

pub fn get_ariaChecked(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-checked", "ariaChecked");
}
pub fn set_ariaChecked(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-checked", "ariaChecked", value);
}

pub fn get_ariaColCount(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-colcount", "ariaColCount");
}
pub fn set_ariaColCount(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-colcount", "ariaColCount", value);
}

pub fn get_ariaColIndex(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-colindex", "ariaColIndex");
}
pub fn set_ariaColIndex(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-colindex", "ariaColIndex", value);
}

pub fn get_ariaColIndexText(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-colindextext", "ariaColIndexText");
}
pub fn set_ariaColIndexText(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-colindextext", "ariaColIndexText", value);
}

pub fn get_ariaColSpan(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-colspan", "ariaColSpan");
}
pub fn set_ariaColSpan(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-colspan", "ariaColSpan", value);
}

pub fn get_ariaCurrent(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-current", "ariaCurrent");
}
pub fn set_ariaCurrent(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-current", "ariaCurrent", value);
}

pub fn get_ariaDescription(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-description", "ariaDescription");
}
pub fn set_ariaDescription(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-description", "ariaDescription", value);
}

pub fn get_ariaDisabled(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-disabled", "ariaDisabled");
}
pub fn set_ariaDisabled(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-disabled", "ariaDisabled", value);
}

pub fn get_ariaExpanded(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-expanded", "ariaExpanded");
}
pub fn set_ariaExpanded(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-expanded", "ariaExpanded", value);
}

pub fn get_ariaHasPopup(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-haspopup", "ariaHasPopup");
}
pub fn set_ariaHasPopup(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-haspopup", "ariaHasPopup", value);
}

pub fn get_ariaHidden(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-hidden", "ariaHidden");
}
pub fn set_ariaHidden(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-hidden", "ariaHidden", value);
}

pub fn get_ariaInvalid(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-invalid", "ariaInvalid");
}
pub fn set_ariaInvalid(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-invalid", "ariaInvalid", value);
}

pub fn get_ariaKeyShortcuts(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-keyshortcuts", "ariaKeyShortcuts");
}
pub fn set_ariaKeyShortcuts(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-keyshortcuts", "ariaKeyShortcuts", value);
}

pub fn get_ariaLabel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-label", "ariaLabel");
}
pub fn set_ariaLabel(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-label", "ariaLabel", value);
}

pub fn get_ariaLevel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-level", "ariaLevel");
}
pub fn set_ariaLevel(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-level", "ariaLevel", value);
}

pub fn get_ariaLive(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-live", "ariaLive");
}
pub fn set_ariaLive(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-live", "ariaLive", value);
}

pub fn get_ariaModal(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-modal", "ariaModal");
}
pub fn set_ariaModal(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-modal", "ariaModal", value);
}

pub fn get_ariaMultiLine(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-multiline", "ariaMultiLine");
}
pub fn set_ariaMultiLine(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-multiline", "ariaMultiLine", value);
}

pub fn get_ariaMultiSelectable(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-multiselectable", "ariaMultiSelectable");
}
pub fn set_ariaMultiSelectable(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-multiselectable", "ariaMultiSelectable", value);
}

pub fn get_ariaOrientation(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-orientation", "ariaOrientation");
}
pub fn set_ariaOrientation(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-orientation", "ariaOrientation", value);
}

pub fn get_ariaPlaceholder(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-placeholder", "ariaPlaceholder");
}
pub fn set_ariaPlaceholder(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-placeholder", "ariaPlaceholder", value);
}

pub fn get_ariaPosInSet(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-posinset", "ariaPosInSet");
}
pub fn set_ariaPosInSet(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-posinset", "ariaPosInSet", value);
}

pub fn get_ariaPressed(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-pressed", "ariaPressed");
}
pub fn set_ariaPressed(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-pressed", "ariaPressed", value);
}

pub fn get_ariaReadOnly(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-readonly", "ariaReadOnly");
}
pub fn set_ariaReadOnly(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-readonly", "ariaReadOnly", value);
}

pub fn get_ariaRelevant(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-relevant", "ariaRelevant");
}
pub fn set_ariaRelevant(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-relevant", "ariaRelevant", value);
}

pub fn get_ariaRequired(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-required", "ariaRequired");
}
pub fn set_ariaRequired(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-required", "ariaRequired", value);
}

pub fn get_ariaRoleDescription(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-roledescription", "ariaRoleDescription");
}
pub fn set_ariaRoleDescription(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-roledescription", "ariaRoleDescription", value);
}

pub fn get_ariaRowCount(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-rowcount", "ariaRowCount");
}
pub fn set_ariaRowCount(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-rowcount", "ariaRowCount", value);
}

pub fn get_ariaRowIndex(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-rowindex", "ariaRowIndex");
}
pub fn set_ariaRowIndex(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-rowindex", "ariaRowIndex", value);
}

pub fn get_ariaRowIndexText(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-rowindextext", "ariaRowIndexText");
}
pub fn set_ariaRowIndexText(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-rowindextext", "ariaRowIndexText", value);
}

pub fn get_ariaRowSpan(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-rowspan", "ariaRowSpan");
}
pub fn set_ariaRowSpan(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-rowspan", "ariaRowSpan", value);
}

pub fn get_ariaSelected(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-selected", "ariaSelected");
}
pub fn set_ariaSelected(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-selected", "ariaSelected", value);
}

pub fn get_ariaSetSize(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-setsize", "ariaSetSize");
}
pub fn set_ariaSetSize(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-setsize", "ariaSetSize", value);
}

pub fn get_ariaSort(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-sort", "ariaSort");
}
pub fn set_ariaSort(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-sort", "ariaSort", value);
}

pub fn get_ariaValueMax(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-valuemax", "ariaValueMax");
}
pub fn set_ariaValueMax(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-valuemax", "ariaValueMax", value);
}

pub fn get_ariaValueMin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-valuemin", "ariaValueMin");
}
pub fn set_ariaValueMin(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-valuemin", "ariaValueMin", value);
}

pub fn get_ariaValueNow(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-valuenow", "ariaValueNow");
}
pub fn set_ariaValueNow(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-valuenow", "ariaValueNow", value);
}

pub fn get_ariaValueText(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getString(instance, "aria-valuetext", "ariaValueText");
}
pub fn set_ariaValueText(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setString(instance, "aria-valuetext", "ariaValueText", value);
}
