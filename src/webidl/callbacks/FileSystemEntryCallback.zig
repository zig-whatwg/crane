//! WebIDL callback: FileSystemEntryCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const FileSystemEntryCallback = *const fn (entry: runtime.JSValue) void;
