//! WebIDL typedef: ParseHTMLUnsafeOptionsOrTrustedHTMLParserOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const ParseHTMLUnsafeOptionsOrTrustedHTMLParserOptions = union(enum) {
    parse_htmlunsafe_options: dictionaries.ParseHTMLUnsafeOptions,
    trusted_htmlparser_options: *runtime.Instance,
};
