//! WebIDL callback: LoadDocumentCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const LoadDocumentCallback = *const fn (url: runtime.USVString, options: webidl.Opt(?runtime.JSValue)) runtime.JSValue;
