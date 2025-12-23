//! Auto-generated mixin: NavigatorLanguage
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorLanguageImpl = @import("impls").NavigatorLanguage;

// Re-export types from impl
pub const impl = @import("impls").NavigatorLanguage;

pub fn get_language(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return NavigatorLanguageImpl.get_language(instance);
}

pub fn get_languages(instance: *runtime.Instance) anyerror!void {
    return NavigatorLanguageImpl.get_languages(instance);
}

