//! The meta charset scan: how Chrome, Firefox and Safari find a document's
//! encoding declaration, in place of the byte scan of HTML §13.2.3.2's
//! "prescan a byte stream to determine its encoding".
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#prescan-a-byte-stream-to-determine-its-encoding
//!
//! Browser deviation, stated (golden rule 2: no newer spec involved, all
//! three browsers agree). The spec's prescan skips over tags byte by byte,
//! stops at the first 1024 bytes and decodes no character references. The
//! browsers instead run the HTML tokenizer over the bytes read as
//! windows-1252, so that:
//! - the contents of script, style, title, textarea, xmp, iframe, noframes
//!   and plaintext are text, not tags (html/syntax/charset/in-script.html,
//!   in-style.html, in-title.html: mismatch - no meta);
//! - attribute values have their character references decoded (ncr.html:
//!   `charset="&#119;indows-1251"` declares windows-1251);
//! - the scan goes on while it has seen only tags that may be in a head
//!   (script, noscript, style, link, meta, object, title, base, and html and
//!   head start tags) however far that is (after-1kb.html: a meta in the
//!   head after byte 1024 counts), and otherwise until 1024 characters are
//!   consumed (after-head-in-1kb.html counts; after-head-after-1kb.html,
//!   after-bogus-after-1kb.html, in-template-after-1kb.html do not);
//! - a CDATA section is a bogus comment: the scan does not know foreign
//!   content (in-svg-in-cdata.html: mismatch).
//! wpt.fyi at 2358bd4835 (Chrome 157 4786307730243584, Firefox 160
//! 4877168468033536, Safari 27.2 6479119966273536): with-inheritance.html and
//! xhr.html pass in all three, without-inheritance.html in Chrome and Firefox
//! (Safari fails it on another assertion). The tests' README: the behaviour
//! WebKit and Blink share with whatwg/html#6962 (open; Firefox's model).
//!
//! The algorithm is Blink's HTMLMetaCharsetParser::CheckForMetaCharset
//! (third_party/blink/renderer/core/html/parser/html_meta_charset_parser.cc)
//! and WebKit's identical HTMLMetaCharsetParser::checkForMetaCharset
//! (Source/WebCore/html/parser/HTMLMetaCharsetParser.cpp), reproduced here
//! over Crane's own tokenizer; a meta element's attributes are taken with the
//! spec's prescan steps (encoding_sniffing.MetaAttributes), which Crane's
//! meta tests already hold to all three browsers.

const std = @import("std");
const Allocator = std.mem.Allocator;

const encoding_sniffing = @import("html_encoding_sniffing");
const Encoding = encoding_sniffing.Encoding;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const TagToken = @import("tokens.zig").TagToken;
const InputStreamManager = @import("document_write.zig").InputStreamManager;

/// Blink's kBytesToCheckUnconditionally: the scan reads at least this many
/// characters (one a byte: the bytes are read as windows-1252) even after
/// the head section has ended.
pub const characters_to_check_unconditionally = 1024;

/// What a scan has found so far.
pub const Outcome = union(enum) {
    /// A meta element declares this encoding.
    found: Encoding,
    /// The scan is over and found none.
    none,
    /// The scan needs more bytes to decide.
    need_more,
};

/// A scan over a byte stream that arrives in pieces (`feed`), keeping the
/// tokenizer's state between them as Blink's checker keeps its tokenizer.
/// It holds its tokenizer, which reads its own input stream by address:
/// `create` it, never copy it.
pub const Scanner = struct {
    allocator: Allocator,
    input: InputStreamManager,
    tokenizer: Tokenizer,
    decoder: encoding_sniffing.StreamDecoder,
    /// Blink's in_head_section_: only tags that may be in a head seen so far.
    in_head_section: bool = true,
    /// The characters before `counted_to` in the input (one a byte of the
    /// original stream, however many UTF-8 bytes the input holds for it).
    consumed: usize = 0,
    counted_to: usize = 0,
    outcome: Outcome = .need_more,

    pub fn create(allocator: Allocator) !*Scanner {
        const self = try allocator.create(Scanner);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .input = .{ .allocator = allocator, .complete = false },
            .tokenizer = undefined,
            .decoder = encoding_sniffing.StreamDecoder.init(encoding_sniffing.windows_1252),
        };
        self.tokenizer = Tokenizer.initWithStreamManager(allocator, &self.input);
        self.input.attach(&self.tokenizer);
        return self;
    }

    pub fn destroy(self: *Scanner) void {
        self.tokenizer.deinit();
        self.input.deinit();
        self.allocator.destroy(self);
    }

    /// The stream's next `bytes` (`last`: it ends with them): what the scan
    /// has found once it has read them. Once it has decided, further bytes
    /// change nothing.
    pub fn feed(self: *Scanner, bytes: []const u8, last: bool) !Outcome {
        if (self.outcome != .need_more) return self.outcome;
        var text: std.ArrayListUnmanaged(u8) = .empty;
        defer text.deinit(self.allocator);
        try self.decoder.decodeInto(self.allocator, &text, bytes, last);
        try self.input.appendToEnd(text.items);
        if (last) {
            self.input.complete = true;
            self.input.sync();
        }
        self.outcome = try self.run();
        // Out of bytes at the end of the stream: there is no meta.
        if (last and self.outcome == .need_more) self.outcome = .none;
        return self.outcome;
    }

    /// Blink's CheckForMetaCharset loop over the tokens the input has.
    fn run(self: *Scanner) !Outcome {
        while (try self.tokenizer.nextToken()) |token_value| {
            var token = token_value;
            defer token.deinit();
            switch (token) {
                .start_tag => |*tag| {
                    const name = tag.getTagName();
                    self.updateStateFor(name);
                    if (std.mem.eql(u8, name, "meta")) {
                        if (declaredEncoding(tag)) |found| return .{ .found = found };
                    }
                    if (!mayBeInHead(name, false)) self.in_head_section = false;
                },
                .end_tag => |*tag| {
                    if (!mayBeInHead(tag.getTagName(), true)) self.in_head_section = false;
                },
                // The end of the input in any state but data: the tokenizer
                // emits an end-of-file token, and again at every call after.
                .eof => return .need_more,
                else => {},
            }
            if (!self.in_head_section and self.charactersConsumed() >= characters_to_check_unconditionally) return .none;
        }
        return .need_more;
    }

    /// Blink's NumberOfCharactersConsumed: the characters the tokenizer has
    /// read, each one byte of the stream.
    fn charactersConsumed(self: *Scanner) usize {
        const data = self.input.buffer.items;
        const to = @min(self.tokenizer.nextInputPosition(), data.len);
        for (data[self.counted_to..to]) |byte| {
            // A UTF-8 continuation byte belongs to the character before it.
            if (byte & 0xC0 != 0x80) self.consumed += 1;
        }
        self.counted_to = @max(self.counted_to, to);
        return self.consumed;
    }

    /// Blink's HTMLTokenizer::UpdateStateFor, for a scan with no document:
    /// neither the scripting flag nor plugins are enabled, so noscript and
    /// noembed stay in the data state.
    fn updateStateFor(self: *Scanner, name: []const u8) void {
        if (eql(name, "textarea") or eql(name, "title")) {
            self.tokenizer.state = .rcdata;
        } else if (eql(name, "plaintext")) {
            self.tokenizer.state = .plaintext;
        } else if (eql(name, "script")) {
            self.tokenizer.state = .script_data;
        } else if (eql(name, "style") or eql(name, "iframe") or eql(name, "xmp") or eql(name, "noframes")) {
            self.tokenizer.state = .rawtext;
        }
    }
};

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

/// Whether a tag named `name` leaves the scan in the head section: the tags
/// Blink lets through, and the html and head start tags.
fn mayBeInHead(name: []const u8, end: bool) bool {
    const head_tags = [_][]const u8{ "script", "noscript", "style", "link", "meta", "object", "title", "base" };
    for (head_tags) |head_tag| if (eql(name, head_tag)) return true;
    return !end and (eql(name, "html") or eql(name, "head"));
}

/// The encoding a meta start tag declares (the prescan's meta steps over the
/// token's attributes), or null.
fn declaredEncoding(tag: *const TagToken) ?Encoding {
    var attributes: encoding_sniffing.MetaAttributes = .{};
    for (tag.attributes.toSlice()) |*attribute| attributes.add(attribute.getName(), attribute.getValue());
    return attributes.encoding();
}

/// The prescan's result once a scan of `bytes`, the stream's first, has
/// decided with `outcome`: the UTF-16 XML declaration prefixes (the
/// prescan's step 2), else the meta the scan found, else "get an XML
/// encoding" of the bytes (Blink checks the XML declaration first and lets a
/// meta found after it win: the same).
pub fn prescanResult(bytes: []const u8, outcome: Outcome) ?Encoding {
    if (encoding_sniffing.utf16XmlDeclaration(bytes)) |found| return found;
    return switch (outcome) {
        .found => |found| found,
        .none, .need_more => encoding_sniffing.getXmlEncoding(bytes),
    };
}

/// The prescan of `bytes`, all of a document's bytes.
pub fn prescan(allocator: Allocator, bytes: []const u8) !?Encoding {
    if (encoding_sniffing.utf16XmlDeclaration(bytes)) |found| return found;
    const scanner = try Scanner.create(allocator);
    defer scanner.destroy();
    return prescanResult(bytes, try scanner.feed(bytes, true));
}

/// HTML §13.2.3.2's encoding sniffing algorithm over `bytes`, all of a
/// document's bytes, with the meta scan as its step 5 - run only when no BOM
/// and no transport-layer encoding decide first.
pub fn sniff(allocator: Allocator, bytes: []const u8, inputs: encoding_sniffing.Inputs) !encoding_sniffing.Result {
    var with_prescan = inputs;
    if (encoding_sniffing.bomLength(bytes) == 0 and inputs.transport == null) {
        with_prescan.prescanned = try prescan(allocator, bytes);
    }
    return encoding_sniffing.sniff(bytes, with_prescan);
}
