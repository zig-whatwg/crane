//! Auto-generated mixin: NavigatorLanguage
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorLanguageImpl = @import("impls").NavigatorLanguage;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").NavigatorLanguage;

pub fn get_language(instance: *runtime.Instance) anyerror!DOMString {
    return try NavigatorLanguageImpl.get_language(instance);
}

pub fn get_languages(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return try NavigatorLanguageImpl.get_languages(instance);
}
