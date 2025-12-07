//! WebIDL callback: LoadDocumentCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const LoadDocumentCallback = *const fn (url: runtime.USVString, options: webidl.Opt(?*const anyopaque)) *const anyopaque;
