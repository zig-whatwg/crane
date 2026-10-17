//! WebIDL dictionary: ShareData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ShareData = struct {
    files: ?[]const *runtime.Instance = null,
    title: ?runtime.USVString = null,
    text: ?runtime.USVString = null,
    url: ?runtime.USVString = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "files", "File" },
    };
};
