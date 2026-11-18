//! WebIDL typedef: SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions = union(enum) {
    set_htmlunsafe_options: dictionaries.SetHTMLUnsafeOptions,
    trusted_htmlparser_options: *runtime.Instance,
};
