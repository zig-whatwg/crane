//! WebIDL dictionary: LanguageModelTool
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");

pub const LanguageModelTool = struct {
    name: runtime.DOMString,
    description: runtime.DOMString,
    inputSchema: runtime.JSValue,
    execute: callbacks.LanguageModelToolFunction,

    /// WebIDL `object` members (or sequences of `object`): a value that is
    /// not an Object throws a TypeError when the dictionary is converted.
    pub const object_members = .{"inputSchema"};
};
