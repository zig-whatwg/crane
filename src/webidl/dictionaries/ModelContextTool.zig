//! WebIDL dictionary: ModelContextTool
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ToolAnnotations = @import("ToolAnnotations.zig").ToolAnnotations;
const callbacks = @import("callbacks");

pub const ModelContextTool = struct {
    name: runtime.DOMString,
    title: ?runtime.USVString = null,
    description: runtime.DOMString,
    inputSchema: ?runtime.JSValue = null,
    execute: callbacks.ToolExecuteCallback,
    annotations: ?ToolAnnotations = null,

    /// WebIDL `object` members (or sequences of `object`): a value that is
    /// not an Object throws a TypeError when the dictionary is converted.
    pub const object_members = .{"inputSchema"};
};
