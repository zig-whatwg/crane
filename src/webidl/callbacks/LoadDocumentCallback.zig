//! WebIDL callback: LoadDocumentCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const LoadDocumentCallback = *const fn (url: runtime.USVString, options: ?runtime.JSValue) runtime.JSValue;
