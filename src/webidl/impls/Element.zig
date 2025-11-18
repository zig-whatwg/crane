//! Implementation for Element interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const Element = @import("interfaces").Element;

pub const State = Element.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Constructor implementation
pub fn constructor(instance: *runtime.Instance) !void {
    _ = instance;
    // TODO: Implement constructor logic
}

/// Getter for nodeType
pub fn get_nodeType(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for nodeName
pub fn get_nodeName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for baseURI
pub fn get_baseURI(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for isConnected
pub fn get_isConnected(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ownerDocument
pub fn get_ownerDocument(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for parentNode
pub fn get_parentNode(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for parentElement
pub fn get_parentElement(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for childNodes
pub fn get_childNodes(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for firstChild
pub fn get_firstChild(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for lastChild
pub fn get_lastChild(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for previousSibling
pub fn get_previousSibling(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for nextSibling
pub fn get_nextSibling(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for nodeValue
pub fn get_nodeValue(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for textContent
pub fn get_textContent(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for namespaceURI
pub fn get_namespaceURI(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for prefix
pub fn get_prefix(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for localName
pub fn get_localName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for tagName
pub fn get_tagName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for id
pub fn get_id(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for className
pub fn get_className(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for classList
pub fn get_classList(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for slot
pub fn get_slot(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for attributes
pub fn get_attributes(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for shadowRoot
pub fn get_shadowRoot(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for customElementRegistry
pub fn get_customElementRegistry(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for onfullscreenchange
pub fn get_onfullscreenchange(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for onfullscreenerror
pub fn get_onfullscreenerror(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for elementTiming
pub fn get_elementTiming(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for part
pub fn get_part(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for activeViewTransition
pub fn get_activeViewTransition(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for innerHTML
pub fn get_innerHTML(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for outerHTML
pub fn get_outerHTML(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for scrollTop
pub fn get_scrollTop(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for scrollLeft
pub fn get_scrollLeft(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for scrollWidth
pub fn get_scrollWidth(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for scrollHeight
pub fn get_scrollHeight(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for clientTop
pub fn get_clientTop(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for clientLeft
pub fn get_clientLeft(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for clientWidth
pub fn get_clientWidth(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for clientHeight
pub fn get_clientHeight(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for currentCSSZoom
pub fn get_currentCSSZoom(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for role
pub fn get_role(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaActiveDescendantElement
pub fn get_ariaActiveDescendantElement(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaAtomic
pub fn get_ariaAtomic(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaAutoComplete
pub fn get_ariaAutoComplete(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaBrailleLabel
pub fn get_ariaBrailleLabel(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaBrailleRoleDescription
pub fn get_ariaBrailleRoleDescription(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaBusy
pub fn get_ariaBusy(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaChecked
pub fn get_ariaChecked(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaColCount
pub fn get_ariaColCount(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaColIndex
pub fn get_ariaColIndex(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaColIndexText
pub fn get_ariaColIndexText(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaColSpan
pub fn get_ariaColSpan(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaControlsElements
pub fn get_ariaControlsElements(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaCurrent
pub fn get_ariaCurrent(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaDescribedByElements
pub fn get_ariaDescribedByElements(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaDescription
pub fn get_ariaDescription(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaDetailsElements
pub fn get_ariaDetailsElements(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaDisabled
pub fn get_ariaDisabled(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaErrorMessageElements
pub fn get_ariaErrorMessageElements(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaExpanded
pub fn get_ariaExpanded(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaFlowToElements
pub fn get_ariaFlowToElements(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaHasPopup
pub fn get_ariaHasPopup(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaHidden
pub fn get_ariaHidden(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaInvalid
pub fn get_ariaInvalid(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaKeyShortcuts
pub fn get_ariaKeyShortcuts(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaLabel
pub fn get_ariaLabel(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaLabelledByElements
pub fn get_ariaLabelledByElements(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaLevel
pub fn get_ariaLevel(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaLive
pub fn get_ariaLive(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaModal
pub fn get_ariaModal(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaMultiLine
pub fn get_ariaMultiLine(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaMultiSelectable
pub fn get_ariaMultiSelectable(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaOrientation
pub fn get_ariaOrientation(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaOwnsElements
pub fn get_ariaOwnsElements(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaPlaceholder
pub fn get_ariaPlaceholder(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaPosInSet
pub fn get_ariaPosInSet(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaPressed
pub fn get_ariaPressed(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaReadOnly
pub fn get_ariaReadOnly(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaRelevant
pub fn get_ariaRelevant(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaRequired
pub fn get_ariaRequired(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaRoleDescription
pub fn get_ariaRoleDescription(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaRowCount
pub fn get_ariaRowCount(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaRowIndex
pub fn get_ariaRowIndex(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaRowIndexText
pub fn get_ariaRowIndexText(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaRowSpan
pub fn get_ariaRowSpan(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaSelected
pub fn get_ariaSelected(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaSetSize
pub fn get_ariaSetSize(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaSort
pub fn get_ariaSort(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaValueMax
pub fn get_ariaValueMax(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaValueMin
pub fn get_ariaValueMin(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaValueNow
pub fn get_ariaValueNow(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ariaValueText
pub fn get_ariaValueText(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for regionOverset
pub fn get_regionOverset(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for children
pub fn get_children(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for firstElementChild
pub fn get_firstElementChild(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for lastElementChild
pub fn get_lastElementChild(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for childElementCount
pub fn get_childElementCount(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for previousElementSibling
pub fn get_previousElementSibling(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for nextElementSibling
pub fn get_nextElementSibling(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for assignedSlot
pub fn get_assignedSlot(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for nodeValue
pub fn set_nodeValue(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for textContent
pub fn set_textContent(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for id
pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for className
pub fn set_className(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for slot
pub fn set_slot(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for onfullscreenchange
pub fn set_onfullscreenchange(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for onfullscreenerror
pub fn set_onfullscreenerror(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for elementTiming
pub fn set_elementTiming(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for innerHTML
pub fn set_innerHTML(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for outerHTML
pub fn set_outerHTML(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for scrollTop
pub fn set_scrollTop(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for scrollLeft
pub fn set_scrollLeft(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for role
pub fn set_role(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaActiveDescendantElement
pub fn set_ariaActiveDescendantElement(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaAtomic
pub fn set_ariaAtomic(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaAutoComplete
pub fn set_ariaAutoComplete(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaBrailleLabel
pub fn set_ariaBrailleLabel(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaBrailleRoleDescription
pub fn set_ariaBrailleRoleDescription(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaBusy
pub fn set_ariaBusy(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaChecked
pub fn set_ariaChecked(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaColCount
pub fn set_ariaColCount(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaColIndex
pub fn set_ariaColIndex(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaColIndexText
pub fn set_ariaColIndexText(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaColSpan
pub fn set_ariaColSpan(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaControlsElements
pub fn set_ariaControlsElements(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaCurrent
pub fn set_ariaCurrent(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaDescribedByElements
pub fn set_ariaDescribedByElements(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaDescription
pub fn set_ariaDescription(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaDetailsElements
pub fn set_ariaDetailsElements(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaDisabled
pub fn set_ariaDisabled(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaErrorMessageElements
pub fn set_ariaErrorMessageElements(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaExpanded
pub fn set_ariaExpanded(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaFlowToElements
pub fn set_ariaFlowToElements(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaHasPopup
pub fn set_ariaHasPopup(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaHidden
pub fn set_ariaHidden(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaInvalid
pub fn set_ariaInvalid(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaKeyShortcuts
pub fn set_ariaKeyShortcuts(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaLabel
pub fn set_ariaLabel(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaLabelledByElements
pub fn set_ariaLabelledByElements(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaLevel
pub fn set_ariaLevel(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaLive
pub fn set_ariaLive(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaModal
pub fn set_ariaModal(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaMultiLine
pub fn set_ariaMultiLine(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaMultiSelectable
pub fn set_ariaMultiSelectable(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaOrientation
pub fn set_ariaOrientation(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaOwnsElements
pub fn set_ariaOwnsElements(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaPlaceholder
pub fn set_ariaPlaceholder(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaPosInSet
pub fn set_ariaPosInSet(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaPressed
pub fn set_ariaPressed(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaReadOnly
pub fn set_ariaReadOnly(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaRelevant
pub fn set_ariaRelevant(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaRequired
pub fn set_ariaRequired(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaRoleDescription
pub fn set_ariaRoleDescription(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaRowCount
pub fn set_ariaRowCount(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaRowIndex
pub fn set_ariaRowIndex(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaRowIndexText
pub fn set_ariaRowIndexText(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaRowSpan
pub fn set_ariaRowSpan(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaSelected
pub fn set_ariaSelected(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaSetSize
pub fn set_ariaSetSize(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaSort
pub fn set_ariaSort(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaValueMax
pub fn set_ariaValueMax(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaValueMin
pub fn set_ariaValueMin(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaValueNow
pub fn set_ariaValueNow(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ariaValueText
pub fn set_ariaValueText(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: addEventListener
pub fn call_addEventListener(instance: *runtime.Instance, type: runtime.DOMString, callback: anyopaque, options: anyopaque) ImplError!void {
    _ = instance;
    _ = type;
    _ = callback;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeEventListener
pub fn call_removeEventListener(instance: *runtime.Instance, type: runtime.DOMString, callback: anyopaque, options: anyopaque) ImplError!void {
    _ = instance;
    _ = type;
    _ = callback;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dispatchEvent
pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) ImplError!bool {
    _ = instance;
    _ = event;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: when
pub fn call_when(instance: *runtime.Instance, type: runtime.DOMString, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = type;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getRootNode
pub fn call_getRootNode(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: hasChildNodes
pub fn call_hasChildNodes(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: normalize
pub fn call_normalize(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cloneNode
pub fn call_cloneNode(instance: *runtime.Instance, subtree: bool) ImplError!anyopaque {
    _ = instance;
    _ = subtree;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isEqualNode
pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: anyopaque) ImplError!bool {
    _ = instance;
    _ = otherNode;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isSameNode
pub fn call_isSameNode(instance: *runtime.Instance, otherNode: anyopaque) ImplError!bool {
    _ = instance;
    _ = otherNode;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compareDocumentPosition
pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: anyopaque) ImplError!u16 {
    _ = instance;
    _ = other;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: contains
pub fn call_contains(instance: *runtime.Instance, other: anyopaque) ImplError!bool {
    _ = instance;
    _ = other;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: lookupPrefix
pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = namespace;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: lookupNamespaceURI
pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = prefix;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isDefaultNamespace
pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: anyopaque) ImplError!bool {
    _ = instance;
    _ = namespace;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: insertBefore
pub fn call_insertBefore(instance: *runtime.Instance, node: anyopaque, child: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = node;
    _ = child;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: appendChild
pub fn call_appendChild(instance: *runtime.Instance, node: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = node;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: replaceChild
pub fn call_replaceChild(instance: *runtime.Instance, node: anyopaque, child: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = node;
    _ = child;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeChild
pub fn call_removeChild(instance: *runtime.Instance, child: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = child;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: hasAttributes
pub fn call_hasAttributes(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAttributeNames
pub fn call_getAttributeNames(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAttribute
pub fn call_getAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = qualifiedName;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAttributeNS
pub fn call_getAttributeNS(instance: *runtime.Instance, namespace: anyopaque, localName: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = namespace;
    _ = localName;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setAttribute
pub fn call_setAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = qualifiedName;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setAttributeNS
pub fn call_setAttributeNS(instance: *runtime.Instance, namespace: anyopaque, qualifiedName: runtime.DOMString, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = namespace;
    _ = qualifiedName;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeAttribute
pub fn call_removeAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = qualifiedName;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeAttributeNS
pub fn call_removeAttributeNS(instance: *runtime.Instance, namespace: anyopaque, localName: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = namespace;
    _ = localName;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: toggleAttribute
pub fn call_toggleAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, force: bool) ImplError!bool {
    _ = instance;
    _ = qualifiedName;
    _ = force;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: hasAttribute
pub fn call_hasAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = qualifiedName;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: hasAttributeNS
pub fn call_hasAttributeNS(instance: *runtime.Instance, namespace: anyopaque, localName: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = namespace;
    _ = localName;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAttributeNode
pub fn call_getAttributeNode(instance: *runtime.Instance, qualifiedName: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = qualifiedName;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAttributeNodeNS
pub fn call_getAttributeNodeNS(instance: *runtime.Instance, namespace: anyopaque, localName: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = namespace;
    _ = localName;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setAttributeNode
pub fn call_setAttributeNode(instance: *runtime.Instance, attr: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = attr;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setAttributeNodeNS
pub fn call_setAttributeNodeNS(instance: *runtime.Instance, attr: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = attr;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeAttributeNode
pub fn call_removeAttributeNode(instance: *runtime.Instance, attr: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = attr;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: attachShadow
pub fn call_attachShadow(instance: *runtime.Instance, init: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = init;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: closest
pub fn call_closest(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = selectors;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: matches
pub fn call_matches(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = selectors;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: webkitMatchesSelector
pub fn call_webkitMatchesSelector(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = selectors;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getElementsByTagName
pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = qualifiedName;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getElementsByTagNameNS
pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: anyopaque, localName: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = namespace;
    _ = localName;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getElementsByClassName
pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = classNames;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: insertAdjacentElement
pub fn call_insertAdjacentElement(instance: *runtime.Instance, where: runtime.DOMString, element: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = where;
    _ = element;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: insertAdjacentText
pub fn call_insertAdjacentText(instance: *runtime.Instance, where: runtime.DOMString, data: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = where;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getSpatialNavigationContainer
pub fn call_getSpatialNavigationContainer(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: focusableAreas
pub fn call_focusableAreas(instance: *runtime.Instance, option: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = option;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: spatialNavigationSearch
pub fn call_spatialNavigationSearch(instance: *runtime.Instance, dir: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = dir;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: requestFullscreen
pub fn call_requestFullscreen(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: requestPointerLock
pub fn call_requestPointerLock(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setPointerCapture
pub fn call_setPointerCapture(instance: *runtime.Instance, pointerId: i32) ImplError!void {
    _ = instance;
    _ = pointerId;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: releasePointerCapture
pub fn call_releasePointerCapture(instance: *runtime.Instance, pointerId: i32) ImplError!void {
    _ = instance;
    _ = pointerId;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: hasPointerCapture
pub fn call_hasPointerCapture(instance: *runtime.Instance, pointerId: i32) ImplError!bool {
    _ = instance;
    _ = pointerId;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: computedStyleMap
pub fn call_computedStyleMap(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: pseudo
pub fn call_pseudo(instance: *runtime.Instance, type: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = type;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: startViewTransition
pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = callbackOptions;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setHTMLUnsafe
pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: anyopaque) ImplError!void {
    _ = instance;
    _ = html;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getHTML
pub fn call_getHTML(instance: *runtime.Instance, options: anyopaque) ImplError!runtime.DOMString {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: insertAdjacentHTML
pub fn call_insertAdjacentHTML(instance: *runtime.Instance, position: runtime.DOMString, string: anyopaque) ImplError!void {
    _ = instance;
    _ = position;
    _ = string;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getClientRects
pub fn call_getClientRects(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getBoundingClientRect
pub fn call_getBoundingClientRect(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: checkVisibility
pub fn call_checkVisibility(instance: *runtime.Instance, options: anyopaque) ImplError!bool {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: scrollIntoView
pub fn call_scrollIntoView(instance: *runtime.Instance, arg: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = arg;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: scroll
pub fn call_scroll(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: scroll
pub fn call_scroll(instance: *runtime.Instance, x: f64, y: f64) ImplError!anyopaque {
    _ = instance;
    _ = x;
    _ = y;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: scrollTo
pub fn call_scrollTo(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: scrollTo
pub fn call_scrollTo(instance: *runtime.Instance, x: f64, y: f64) ImplError!anyopaque {
    _ = instance;
    _ = x;
    _ = y;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: scrollBy
pub fn call_scrollBy(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: scrollBy
pub fn call_scrollBy(instance: *runtime.Instance, x: f64, y: f64) ImplError!anyopaque {
    _ = instance;
    _ = x;
    _ = y;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: animate
pub fn call_animate(instance: *runtime.Instance, keyframes: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = keyframes;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAnimations
pub fn call_getAnimations(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getRegionFlowRanges
pub fn call_getRegionFlowRanges(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: prepend
pub fn call_prepend(instance: *runtime.Instance, nodes: anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: append
pub fn call_append(instance: *runtime.Instance, nodes: anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: replaceChildren
pub fn call_replaceChildren(instance: *runtime.Instance, nodes: anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: moveBefore
pub fn call_moveBefore(instance: *runtime.Instance, node: anyopaque, child: anyopaque) ImplError!void {
    _ = instance;
    _ = node;
    _ = child;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: querySelector
pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = selectors;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: querySelectorAll
pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = selectors;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: before
pub fn call_before(instance: *runtime.Instance, nodes: anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: after
pub fn call_after(instance: *runtime.Instance, nodes: anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: replaceWith
pub fn call_replaceWith(instance: *runtime.Instance, nodes: anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: remove
pub fn call_remove(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getBoxQuads
pub fn call_getBoxQuads(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: convertQuadFromNode
pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: anyopaque, from: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = quad;
    _ = from;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: convertRectFromNode
pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: anyopaque, from: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = rect;
    _ = from;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: convertPointFromNode
pub fn call_convertPointFromNode(instance: *runtime.Instance, point: anyopaque, from: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = point;
    _ = from;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

