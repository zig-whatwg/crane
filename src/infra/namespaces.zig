//! WHATWG Infra Namespace Constants
//!
//! Spec: https://infra.spec.whatwg.org/#namespaces
//!
//! Namespace constants used by various web specifications (HTML, SVG, MathML, etc.)

const std = @import("std");

/// The HTML namespace.
/// WHATWG Infra Standard §8
pub const HTML_NAMESPACE = "http://www.w3.org/1999/xhtml";

/// The MathML namespace.
/// WHATWG Infra Standard §8
pub const MATHML_NAMESPACE = "http://www.w3.org/1998/Math/MathML";

/// The SVG namespace.
/// WHATWG Infra Standard §8
pub const SVG_NAMESPACE = "http://www.w3.org/2000/svg";

/// The XLink namespace.
/// WHATWG Infra Standard §8
pub const XLINK_NAMESPACE = "http://www.w3.org/1999/xlink";

/// The XML namespace.
/// WHATWG Infra Standard §8
pub const XML_NAMESPACE = "http://www.w3.org/XML/1998/namespace";

/// The XMLNS namespace.
/// WHATWG Infra Standard §8
pub const XMLNS_NAMESPACE = "http://www.w3.org/2000/xmlns/";

/// Extension: VML namespace (not defined in WHATWG Infra Standard).
/// This is a library-specific extension for VML support.
pub const VML_NAMESPACE = "http://example.org";

test "HTML namespace constant" {
    try std.testing.expectEqualStrings("http://www.w3.org/1999/xhtml", HTML_NAMESPACE);
}

test "MathML namespace constant" {
    try std.testing.expectEqualStrings("http://www.w3.org/1998/Math/MathML", MATHML_NAMESPACE);
}

test "SVG namespace constant" {
    try std.testing.expectEqualStrings("http://www.w3.org/2000/svg", SVG_NAMESPACE);
}

test "XLink namespace constant" {
    try std.testing.expectEqualStrings("http://www.w3.org/1999/xlink", XLINK_NAMESPACE);
}

test "XML namespace constant" {
    try std.testing.expectEqualStrings("http://www.w3.org/XML/1998/namespace", XML_NAMESPACE);
}

test "XMLNS namespace constant" {
    try std.testing.expectEqualStrings("http://www.w3.org/2000/xmlns/", XMLNS_NAMESPACE);
}

test "VML namespace constant" {
    try std.testing.expectEqualStrings("http://example.org", VML_NAMESPACE);
}
