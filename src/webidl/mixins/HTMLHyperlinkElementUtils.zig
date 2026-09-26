//! Auto-generated mixin: HTMLHyperlinkElementUtils
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLHyperlinkElementUtilsImpl = @import("impls").HTMLHyperlinkElementUtils;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USVString = @import("typedefs").USVString;

pub const impl = @import("impls").HTMLHyperlinkElementUtils;

const reflection = @import("impls").reflection;

/// Extended attributes: [CEReactions], [ReflectSetter], [Stringifier]
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try HTMLHyperlinkElementUtilsImpl.get_href(instance);
}

/// Extended attributes: [CEReactions], [ReflectSetter], [Stringifier]
pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    if (comptime @hasDecl(HTMLHyperlinkElementUtilsImpl, "set_href")) return try HTMLHyperlinkElementUtilsImpl.set_href(instance, value);
    try reflection.set(runtime.USVString, instance, .{ .name = "href" }, value);
}

pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try HTMLHyperlinkElementUtilsImpl.get_origin(instance);
}

/// Extended attributes: [CEReactions]
pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try HTMLHyperlinkElementUtilsImpl.get_protocol(instance);
}

/// Extended attributes: [CEReactions]
pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try HTMLHyperlinkElementUtilsImpl.set_protocol(instance, value);
}

/// Extended attributes: [CEReactions]
pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try HTMLHyperlinkElementUtilsImpl.get_username(instance);
}

/// Extended attributes: [CEReactions]
pub fn set_username(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try HTMLHyperlinkElementUtilsImpl.set_username(instance, value);
}

/// Extended attributes: [CEReactions]
pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try HTMLHyperlinkElementUtilsImpl.get_password(instance);
}

/// Extended attributes: [CEReactions]
pub fn set_password(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try HTMLHyperlinkElementUtilsImpl.set_password(instance, value);
}

/// Extended attributes: [CEReactions]
pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try HTMLHyperlinkElementUtilsImpl.get_host(instance);
}

/// Extended attributes: [CEReactions]
pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try HTMLHyperlinkElementUtilsImpl.set_host(instance, value);
}

/// Extended attributes: [CEReactions]
pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try HTMLHyperlinkElementUtilsImpl.get_hostname(instance);
}

/// Extended attributes: [CEReactions]
pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try HTMLHyperlinkElementUtilsImpl.set_hostname(instance, value);
}

/// Extended attributes: [CEReactions]
pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try HTMLHyperlinkElementUtilsImpl.get_port(instance);
}

/// Extended attributes: [CEReactions]
pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try HTMLHyperlinkElementUtilsImpl.set_port(instance, value);
}

/// Extended attributes: [CEReactions]
pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try HTMLHyperlinkElementUtilsImpl.get_pathname(instance);
}

/// Extended attributes: [CEReactions]
pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try HTMLHyperlinkElementUtilsImpl.set_pathname(instance, value);
}

/// Extended attributes: [CEReactions]
pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try HTMLHyperlinkElementUtilsImpl.get_search(instance);
}

/// Extended attributes: [CEReactions]
pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try HTMLHyperlinkElementUtilsImpl.set_search(instance, value);
}

/// Extended attributes: [CEReactions]
pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try HTMLHyperlinkElementUtilsImpl.get_hash(instance);
}

/// Extended attributes: [CEReactions]
pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try HTMLHyperlinkElementUtilsImpl.set_hash(instance, value);
}
