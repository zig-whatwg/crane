//! XML 1.0 (Fifth Edition) and Namespaces in XML 1.0 (Third Edition): the
//! parser behind HTML's "XML parser" (HTML §14.2).
//!
//! Engine-free and DOM-free: it reports a document's events to a sink. The
//! tree builder that turns them into a Document is HTML's
//! (src/html/xml_document_parser.zig).

pub const chars = @import("chars.zig");
pub const parser = @import("parser.zig");

pub const Parser = parser.Parser;
pub const Options = parser.Options;
pub const Name = parser.Name;
pub const Attribute = parser.Attribute;
pub const XmlDeclaration = parser.XmlDeclaration;
pub const Position = parser.Position;
pub const Failure = parser.Failure;
pub const declaredEncoding = parser.declaredEncoding;
pub const xml_namespace = parser.xml_namespace;
pub const xmlns_namespace = parser.xmlns_namespace;

test {
    _ = chars;
    _ = parser;
}
