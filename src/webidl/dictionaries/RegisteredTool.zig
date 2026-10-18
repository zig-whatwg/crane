//! WebIDL dictionary: RegisteredTool
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ToolAnnotations = @import("ToolAnnotations.zig").ToolAnnotations;

pub const RegisteredTool = struct {
    name: runtime.DOMString,
    title: ?runtime.DOMString = null,
    description: runtime.DOMString,
    inputSchema: ?runtime.JSValue = null,
    window: *runtime.Instance,
    origin: runtime.USVString,
    annotations: ?ToolAnnotations = null,

    /// WebIDL `object` members (or sequences of `object`): a value that is
    /// not an Object throws a TypeError when the dictionary is converted.
    pub const object_members = .{"inputSchema"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "window", "Window" },
    };
};
