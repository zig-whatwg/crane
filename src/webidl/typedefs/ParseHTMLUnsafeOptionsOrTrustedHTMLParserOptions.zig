//! WebIDL typedef: ParseHTMLUnsafeOptionsOrTrustedHTMLParserOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const ParseHTMLUnsafeOptionsOrTrustedHTMLParserOptions = union(enum) {
    parse_htmlunsafe_options: dictionaries.ParseHTMLUnsafeOptions,
    trusted_htmlparser_options: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "parse_htmlunsafe_options", .kind = .dictionary },
        .{ .field = "trusted_htmlparser_options", .kind = .{ .interface = "TrustedHTMLParserOptions" } },
    };
};
