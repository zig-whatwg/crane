//! Auto-generated mixin: ElementContentEditable
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ElementContentEditableImpl = @import("impls").ElementContentEditable;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").ElementContentEditable;

/// Extended attributes: [CEReactions]
pub fn get_contentEditable(instance: *runtime.Instance) anyerror!DOMString {
    return try ElementContentEditableImpl.get_contentEditable(instance);
}

/// Extended attributes: [CEReactions]
pub fn set_contentEditable(instance: *runtime.Instance, value: DOMString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try ElementContentEditableImpl.set_contentEditable(instance, value);
}

/// Extended attributes: [CEReactions]
pub fn get_enterKeyHint(instance: *runtime.Instance) anyerror!DOMString {
    return try ElementContentEditableImpl.get_enterKeyHint(instance);
}

/// Extended attributes: [CEReactions]
pub fn set_enterKeyHint(instance: *runtime.Instance, value: DOMString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try ElementContentEditableImpl.set_enterKeyHint(instance, value);
}

pub fn get_isContentEditable(instance: *runtime.Instance) anyerror!bool {
    return try ElementContentEditableImpl.get_isContentEditable(instance);
}

/// Extended attributes: [CEReactions]
pub fn get_inputMode(instance: *runtime.Instance) anyerror!DOMString {
    return try ElementContentEditableImpl.get_inputMode(instance);
}

/// Extended attributes: [CEReactions]
pub fn set_inputMode(instance: *runtime.Instance, value: DOMString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try ElementContentEditableImpl.set_inputMode(instance, value);
}

/// Extended attributes: [CEReactions]
pub fn get_virtualKeyboardPolicy(instance: *runtime.Instance) anyerror!DOMString {
    return try ElementContentEditableImpl.get_virtualKeyboardPolicy(instance);
}

/// Extended attributes: [CEReactions]
pub fn set_virtualKeyboardPolicy(instance: *runtime.Instance, value: DOMString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try ElementContentEditableImpl.set_virtualKeyboardPolicy(instance, value);
}
