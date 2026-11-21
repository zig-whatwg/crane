//! HTML 13.2.8 "Speculative HTML parsing": the speculative HTML parser a
//! document's parser runs while it waits for a pending parsing-blocking
//! script, which reads on through the input and finds the resources the
//! markup there declares - "a series of speculative fetches" - so they are
//! requested before the normal parser reaches their elements.
//!
//! The spec leaves the mechanism open ("not defined in precise detail") and
//! states the rules for interoperability, followed here:
//! - the normal parser's state and the document are not affected: the
//!   scanner has its own copy of the unparsed input, its own tokenizer, and
//!   its own state;
//! - bytes pushed into the parser's input stream are pushed into the
//!   scanner's too (`append`);
//! - only what the normal parser would fetch, "under the assumption that the
//!   script that is blocking the HTML parser does nothing", is found: each
//!   element's attributes go through the rules the element itself applies
//!   (html.link_types, html.image_source_selection,
//!   script_execution.scriptTypeAtPrepare);
//! - a base element, a meta Content-Security-Policy and a meta referrer are
//!   acted on for the later speculative fetches; a meta charset is not
//!   (13.2.6.4.4: "The speculative HTML parser doesn't speculatively apply
//!   character encoding declarations"); a meta viewport has no effect on a
//!   desktop environment's media queries;
//! - nothing is fetched from a template's contents unless the template is a
//!   declarative shadow root.
//!
//! The mechanism is the token scanner two of the three engines use - Blink's
//! TokenPreloadScanner and StartTagScanner (third_party/blink/renderer/core/
//! html/parser/html_preload_scanner.cc, BSD) and WebKit's HTMLPreloadScanner
//! (Source/WebCore/html/parser/HTMLPreloadScanner.cpp, BSD), read and
//! reproduced, not copied: a tokenizer whose state after each start tag is
//! set as the tree builder would set it (Blink HTMLTokenizer::UpdateStateFor),
//! with counters for templates and declarative shadow roots, a stack of
//! foreign content with the tree builder's breakout tags, and the picture
//! element's sources. Gecko speculates with its real tree builder
//! (nsHtml5TreeBuilder in speculative mode; MPL, reference only). Where the
//! token scanners approximate a tree rule, the tree rule is taken - golden
//! rule 2 cannot choose between approximations of one spec rule:
//! - "in body": Blink counts only a body or img start tag; here any start
//!   tag or character the "in head" / "after head" modes send to the body
//!   does, as the tree builder's would - the render-blocking classification
//!   below then matches the element's own (style_sheet_loading
//!   fetchRenderBlocking: a parser-created sheet in the body does not block);
//! - an element's tokenizer state is switched only in the HTML namespace (an
//!   SVG style or title holds markup, as the tree builder's foreign content
//!   rules have it).
//!
//! Render-blocking metadata of each speculative request is Blink's
//! (StartTagScanner::CreatePreloadRequest, CSSPreloadScanner::EmitRule):
//! Chrome alone ships renderBlockingStatus, so its classification is the one
//! a speculative request reports; a render-blocking element that later takes
//! the response over upgrades it (fetch.internal.document_resources.Entry).

const std = @import("std");
const html_core = @import("html_core");
const css = @import("css");
const fetch = @import("fetch");
const Tokenizer = html_core.parser.Tokenizer;
const TagToken = html_core.parser.TagToken;
const TreeBuilder = html_core.parser.TreeBuilder;
const InputStreamManager = html_core.parser.document_write.InputStreamManager;
const speculative_css = @import("speculative_css.zig");
const image_source_selection = @import("image_source_selection.zig");
const link_types = @import("link_types.zig");
const script_request = @import("script_request.zig");

pub const CorsSetting = script_request.CorsSetting;

/// What a speculative mock element would fetch if it was processed normally.
pub const Kind = enum {
    /// An img's selected source; an input in the Image Button state's src;
    /// an SVG image's href.
    image,
    /// A classic script's src (an HTML or SVG script).
    classic_script,
    /// A module script's src.
    module_script,
    /// A stylesheet link's href.
    style_sheet,
    /// A style element's @import (CSS Cascade 5 "fetch an @import").
    import,
    /// A preload link's href, with its `as` destination.
    preload,
    /// A modulepreload link's href.
    modulepreload,
};

/// One speculative fetch the scanner found. Its strings are BORROWED for the
/// sink's call.
pub const Found = struct {
    kind: Kind,
    /// The URL as the element reads it - its attribute's value with leading
    /// and trailing ASCII whitespace stripped, or the selected image source -
    /// not yet encoding-parsed.
    url: []const u8,
    /// The href of the first base element the scan met (the predicted frozen
    /// base URL's input), or null: the document's base URL.
    base: ?[]const u8,
    cors: CorsSetting = .no_cors,
    /// The element's referrerpolicy attribute's state, else a referrer
    /// policy a meta referrer the scan met declared, else empty (the
    /// document's).
    referrer_policy: fetch.internal.ReferrerPolicy = .empty,
    integrity: []const u8 = "",
    nonce: []const u8 = "",
    fetch_priority: fetch.internal.request.Priority = .auto,
    /// A preload's `as` translated (link_types.preloadDestination); a
    /// modulepreload's `as` state, "script" by default.
    destination: fetch.internal.Destination = .empty,
    /// Blink's RenderBlockingBehavior is kBlocking.
    render_blocking: bool = false,
    /// An img whose request is a responsive image's (srcset, or a picture's):
    /// the "imageset" initiator.
    imageset: bool = false,
    /// Resource Timing's initiatorType, as the element's own request has it.
    initiator_type: fetch.internal.InitiatorType = .other,
};

/// Where the scanner reports what it found.
pub const Sink = struct {
    context: *anyopaque,
    found: *const fn (context: *anyopaque, found: *const Found) void,
};

/// The parser's state where the scan starts ("Let speculativeParser be a new
/// speculative HTML parser, with the same state as parser") and the
/// document's facts the scan reads.
pub const Options = struct {
    /// The parser's input after its next input character.
    input: []const u8 = "",
    /// No more input will come (the input stream's end is its EOF).
    complete: bool = true,
    /// The parser's scripting flag (a noscript element's text).
    scripting: bool = true,
    /// The media environment (link and source media, sizes).
    media: css.media_queries.MediaValues = .{},
    /// The parser has inserted the body element, or is past where it would.
    in_body: bool = false,
    /// The document's base URL is already frozen by a base element with an
    /// href: no base the scan meets changes it (the first one wins).
    base_known: bool = false,
};

const Foreign = enum { svg, math };

/// The first eligible source of the picture element the scan is in (HTML
/// 4.8.4.3.9 steps 2-5), OWNED copies.
const PictureSource = struct {
    srcset: []u8,
    sizes: []u8,
};

pub const Scanner = struct {
    allocator: std.mem.Allocator,
    stream: InputStreamManager,
    tokenizer: Tokenizer,
    options: Options,
    css: speculative_css.Scanner,
    in_body: bool,
    /// A start tag switched the tokenizer to the RCDATA, RAWTEXT, script data
    /// or PLAINTEXT state: its text is the element's, not the body's.
    in_raw_text: bool = false,
    in_style: bool = false,
    style_media_matches: bool = true,
    /// Open templates that are not declarative shadow roots (their contents
    /// are inert), and declarative shadow roots outside them.
    template_count: u32 = 0,
    dsd_count: u32 = 0,
    foreign: std.ArrayListUnmanaged(Foreign) = .empty,
    in_picture: bool = false,
    picture_source: ?PictureSource = null,
    /// The first base element's href, OWNED; null until one is met.
    base: ?[]u8 = null,
    base_known: bool,
    /// A meta referrer's policy, for requests whose element has none.
    referrer_policy: fetch.internal.ReferrerPolicy = .empty,
    /// The content of each meta Content-Security-Policy the scan met, in
    /// order, OWNED: the speculative fetches after it obey it.
    policies: std.ArrayListUnmanaged([]u8) = .empty,
    /// How many of `policies` the sink has seen (`newPolicies`).
    policies_seen: usize = 0,

    /// A scanner over `options.input`, copied. Heap-allocated: its tokenizer
    /// reads its own stream through a pointer.
    pub fn create(allocator: std.mem.Allocator, options: Options) !*Scanner {
        const self = try allocator.create(Scanner);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .stream = try InputStreamManager.init(allocator, options.input),
            .tokenizer = undefined,
            .options = options,
            .css = speculative_css.Scanner.init(allocator),
            .in_body = options.in_body,
            .base_known = options.base_known,
        };
        self.options.input = "";
        self.stream.complete = options.complete;
        self.tokenizer = Tokenizer.initWithStreamManager(allocator, &self.stream);
        self.stream.attach(&self.tokenizer);
        return self;
    }

    pub fn destroy(self: *Scanner) void {
        const allocator = self.allocator;
        self.tokenizer.deinit();
        self.stream.deinit();
        self.css.deinit();
        self.foreign.deinit(allocator);
        self.clearPicture();
        if (self.base) |b| allocator.free(b);
        for (self.policies.items) |p| allocator.free(p);
        self.policies.deinit(allocator);
        allocator.destroy(self);
    }

    /// The parser's input stream got `chars` at its end: so does this
    /// scanner's ("Bytes pushed into the HTML parser's input byte stream must
    /// also be pushed into the speculative HTML parser's input byte stream").
    pub fn append(self: *Scanner, chars: []const u8) !void {
        try self.stream.appendToEnd(chars);
    }

    /// The parser's input is complete: the scanner's end is its EOF.
    pub fn complete(self: *Scanner) void {
        self.stream.complete = true;
        self.stream.sync();
    }

    /// Meta policies met since the sink last asked, in order.
    pub fn newPolicies(self: *Scanner) []const []u8 {
        const fresh = self.policies.items[self.policies_seen..];
        self.policies_seen = self.policies.items.len;
        return fresh;
    }

    /// Read every token there is input for, reporting each speculative fetch
    /// to `sink`. Returns at the end of the input so far.
    pub fn scan(self: *Scanner, sink: Sink) !void {
        _ = try self.scanFor(sink, std.math.maxInt(usize));
    }

    /// As `scan`, stopping at the first token boundary after `budget` bytes
    /// of input: true when it stopped there, with input left to read; false
    /// at the end of the input so far.
    pub fn scanFor(self: *Scanner, sink: Sink, budget: usize) !bool {
        const start = self.tokenizer.nextInputPosition();
        while (true) {
            if (self.tokenizer.nextInputPosition() - start >= budget) return true;
            self.tokenizer.allow_cdata = self.foreign.items.len != 0;
            var token = (try self.tokenizer.nextToken()) orelse return false;
            defer token.deinit();
            switch (token) {
                .start_tag => |*tag| try self.startTag(tag, sink),
                .end_tag => |*tag| try self.endTag(tag.getTagName(), sink),
                .text_run => |run| try self.text(run.data),
                .character => |c| {
                    var buffer: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(c, &buffer) catch 0;
                    try self.text(buffer[0..len]);
                },
                .eof => return false,
                else => {},
            }
        }
    }

    fn text(self: *Scanner, data: []const u8) !void {
        if (self.in_style) return self.css.feed(data);
        // "in head" / "after head": a character that is not whitespace is
        // "anything else" - the body starts.
        if (self.in_body or self.in_raw_text or self.template_count != 0 or self.foreign.items.len != 0) return;
        for (data) |c| switch (c) {
            ' ', '\t', '\n', '\r', '\x0c' => {},
            else => {
                self.in_body = true;
                return;
            },
        };
    }

    fn endTag(self: *Scanner, name: []const u8, sink: Sink) !void {
        if (eql(name, "template")) {
            if (self.template_count != 0) {
                self.template_count -= 1;
            } else if (self.dsd_count != 0) self.dsd_count -= 1;
            return;
        }
        if (self.template_count != 0) {
            self.in_raw_text = false;
            return;
        }
        if (eql(name, "svg") or eql(name, "math")) {
            _ = self.foreign.pop();
            return;
        }
        if (eql(name, "style") and self.in_style) {
            self.in_style = false;
            self.in_raw_text = false;
            try self.css.finish();
            try self.emitImports(sink);
            return;
        }
        if (eql(name, "picture")) {
            self.in_picture = false;
            self.clearPicture();
            return;
        }
        if (self.in_raw_text) self.in_raw_text = false;
    }

    fn startTag(self: *Scanner, tag: *const TagToken, sink: Sink) !void {
        var name = tag.getTagName();
        // The tokenizer's state for the element's contents, as the tree
        // builder sets it (Blink HTMLTokenizer::UpdateStateFor) - even inside
        // a template, whose contents tokenize the same way.
        if (self.foreign.items.len == 0) self.updateTokenizerState(name);

        if (eql(name, "template")) {
            const mode = attr(tag, "shadowrootmode");
            const declarative = if (mode) |m| std.ascii.eqlIgnoreCase(m, "open") or std.ascii.eqlIgnoreCase(m, "closed") else false;
            // A declarative shadow root's contents are fetched from; any
            // other template's, and everything inside one, are not (13.2.8,
            // last paragraph; Blink dsd_count_/template_count_, WebKit
            // m_templateCount).
            if (declarative and self.template_count == 0) self.dsd_count += 1 else self.template_count += 1;
        }
        if (self.template_count != 0) return;

        // Foreign content: a breakout tag ends it, as in the tree builder's
        // "in foreign content" rules.
        if (self.foreign.items.len != 0 and (TreeBuilder.isForeignContentHtmlBreakout(name) or
            (eql(name, "font") and TreeBuilder.hasFontBreakoutAttribute(tag.*))))
        {
            self.foreign.clearRetainingCapacity();
            self.updateTokenizerState(name);
        }
        if (eql(name, "svg")) {
            if (!tag.self_closing) try self.foreign.append(self.allocator, .svg);
            self.enterBody(name);
            return;
        }
        if (eql(name, "math")) {
            if (!tag.self_closing) try self.foreign.append(self.allocator, .math);
            self.enterBody(name);
            return;
        }
        if (self.foreign.items.len != 0) {
            // SVG's image and script load from href (or xlink:href); MathML
            // has neither.
            if (self.foreign.items[self.foreign.items.len - 1] != .svg) return;
            if (eql(name, "image")) return self.svgImage(tag, sink);
            if (eql(name, "script")) return self.svgScript(tag, sink);
            return;
        }
        // "in body": an image start tag is an img.
        if (eql(name, "image")) name = "img";

        if (eql(name, "base")) {
            // Not inside a declarative shadow root: its base element does not
            // set the document's base URL.
            if (self.dsd_count != 0 or self.base_known) return;
            const href = attr(tag, "href") orelse return;
            self.base = try self.allocator.dupe(u8, trimHtmlSpace(href));
            self.base_known = true;
            return;
        }
        if (eql(name, "meta")) {
            if (self.dsd_count != 0) return;
            return self.meta(tag);
        }
        self.enterBody(name);

        if (eql(name, "picture")) {
            self.in_picture = true;
            self.clearPicture();
            return;
        }
        // A non-void element may hold the img, which is then not the
        // picture's child (Blink).
        if (!isVoid(name)) {
            self.in_picture = false;
            self.clearPicture();
        }

        if (eql(name, "style")) {
            self.in_style = true;
            self.css.reset();
            self.style_media_matches = if (attr(tag, "media")) |media| self.mediaMatches(media) else true;
            return;
        }
        if (eql(name, "script")) return self.script(tag, sink);
        if (eql(name, "link")) return self.link(tag, sink);
        if (eql(name, "img")) return self.img(tag, sink);
        if (eql(name, "source")) return self.source(tag);
        if (eql(name, "input")) return self.input(tag, sink);
        if (eql(name, "video")) return self.video(tag, sink);
    }

    /// Blink's HTMLTokenizer::UpdateStateFor, the tree builder's choice of
    /// tokenizer state for an HTML element's contents.
    fn updateTokenizerState(self: *Scanner, name: []const u8) void {
        const state: ?html_core.parser.State = if (eql(name, "textarea") or eql(name, "title"))
            .rcdata
        else if (eql(name, "plaintext"))
            .plaintext
        else if (eql(name, "script"))
            .script_data
        else if (eql(name, "style") or eql(name, "iframe") or eql(name, "xmp") or eql(name, "noembed") or eql(name, "noframes") or
            (eql(name, "noscript") and self.options.scripting))
            .rawtext
        else
            null;
        if (state) |s| {
            self.tokenizer.state = s;
            self.in_raw_text = true;
        }
    }

    /// "in head" / "after head": a start tag those modes do not keep in the
    /// head starts the body.
    fn enterBody(self: *Scanner, name: []const u8) void {
        if (self.in_body) return;
        const head_content = [_][]const u8{ "html", "head", "base", "basefont", "bgsound", "link", "meta", "noframes", "script", "style", "template", "title", "noscript" };
        for (head_content) |h| if (eql(name, h)) return;
        self.in_body = true;
    }

    fn meta(self: *Scanner, tag: *const TagToken) !void {
        if (attr(tag, "http-equiv")) |equiv| {
            // HTML 4.2.5.3 "Content security policy state": only a meta in
            // the head is processed (step 1: its parent is the head).
            if (!std.ascii.eqlIgnoreCase(trimHtmlSpace(equiv), "content-security-policy") or self.in_body) return;
            const content = attr(tag, "content") orelse return;
            const copy = try self.allocator.dupe(u8, content);
            errdefer self.allocator.free(copy);
            try self.policies.append(self.allocator, copy);
            return;
        }
        const name = attr(tag, "name") orelse return;
        if (!std.ascii.eqlIgnoreCase(trimHtmlSpace(name), "referrer")) return;
        const content = attr(tag, "content") orelse return;
        // HTML 4.2.5.1 "referrer": an empty or unknown value changes nothing.
        if (fetch.internal.policy_container.referrerPolicyFromMeta(content)) |policy| self.referrer_policy = policy;
    }

    fn found(self: *const Scanner, kind: Kind, url: []const u8) Found {
        return .{ .kind = kind, .url = trimHtmlSpace(url), .base = self.base, .referrer_policy = self.referrer_policy };
    }

    fn referrerPolicyOf(self: *const Scanner, tag: *const TagToken) fetch.internal.ReferrerPolicy {
        const policy = fetch.internal.policy_container.referrerPolicyFromAttribute(attr(tag, "referrerpolicy"));
        return if (policy != .empty) policy else self.referrer_policy;
    }

    fn report(sink: Sink, f: *const Found) void {
        // Never a data: URL, or one that names only a fragment (Blink
        // PreloadRequest::CreateIfNeeded): nothing to fetch ahead of time.
        if (f.url.len == 0 or f.url[0] == '#' or std.ascii.startsWithIgnoreCase(f.url, "data:")) return;
        sink.found(sink.context, f);
    }

    /// HTML "prepare the script element" steps 8-13 and 19-32 as far as the
    /// fetch: a classic or module script with a src.
    fn script(self: *Scanner, tag: *const TagToken, sink: Sink) !void {
        const src = attr(tag, "src") orelse return;
        const script_type = @import("script_execution.zig").scriptTypeAtPrepare(attr(tag, "type"), attr(tag, "language") orelse "");
        const module = switch (script_type) {
            .classic => false,
            .module => true,
            else => return,
        };
        // Step 20: "If el has a nomodule content attribute and its type is
        // "classic", then return."
        if (!module and attr(tag, "nomodule") != null) return;
        var f = self.found(if (module) .module_script else .classic_script, src);
        f.cors = script_request.corsSettingFromAttribute(attr(tag, "crossorigin"));
        f.referrer_policy = self.referrerPolicyOf(tag);
        f.integrity = attr(tag, "integrity") orelse "";
        f.nonce = nonceOf(tag, true);
        f.fetch_priority = priority(attr(tag, "fetchpriority"));
        f.initiator_type = .script;
        const deferred = attr(tag, "async") != null or attr(tag, "defer") != null;
        // Blink CreatePreloadRequest: a module, async or defer script blocks
        // rendering only with blocking=render; a parser-blocking one does
        // outside the body.
        f.render_blocking = if (module or deferred)
            hasRenderToken(attr(tag, "blocking"))
        else
            !self.in_body;
        report(sink, &f);
    }

    /// SVG 2 15.2: an SVG script's href (or xlink:href) is a classic script's
    /// src.
    fn svgScript(self: *Scanner, tag: *const TagToken, sink: Sink) !void {
        const href = attr(tag, "href") orelse attr(tag, "xlink:href") orelse return;
        const script_type = @import("script_execution.zig").scriptTypeAtPrepare(attr(tag, "type"), "");
        if (script_type != .classic) return;
        var f = self.found(.classic_script, href);
        f.cors = script_request.corsSettingFromAttribute(attr(tag, "crossorigin"));
        f.initiator_type = .script;
        f.render_blocking = !self.in_body;
        report(sink, &f);
    }

    fn svgImage(self: *Scanner, tag: *const TagToken, sink: Sink) !void {
        const href = attr(tag, "href") orelse attr(tag, "xlink:href") orelse return;
        var f = self.found(.image, href);
        f.cors = script_request.corsSettingFromAttribute(attr(tag, "crossorigin"));
        f.initiator_type = .image;
        report(sink, &f);
    }

    /// A link's external resource, by the element's own rules (html.link_types,
    /// the link element's "fetch and process the linked resource").
    fn link(self: *Scanner, tag: *const TagToken, sink: Sink) !void {
        const href = attr(tag, "href") orelse return;
        if (href.len == 0) return;
        const rel = attr(tag, "rel");
        var f = self.found(.style_sheet, href);
        f.cors = script_request.corsSettingFromAttribute(attr(tag, "crossorigin"));
        f.referrer_policy = self.referrerPolicyOf(tag);
        f.integrity = attr(tag, "integrity") orelse "";
        f.nonce = nonceOf(tag, false);
        f.fetch_priority = priority(attr(tag, "fetchpriority"));
        f.initiator_type = .link;
        switch (link_types.relLinkType(rel)) {
            .stylesheet => {
                // An alternative style sheet is not applied, nor fetched ahead
                // (Blink: rel.IsAlternate(); WebKit the same).
                if (link_types.hasToken(rel.?, "alternate")) return;
                if (!link_types.supportedType(attr(tag, "type"))) return;
                if (attr(tag, "disabled") != null) return;
                // A sheet whose media does not match is fetched by the element,
                // but not ahead of it (Blink ShouldPreload: matched_).
                if (attr(tag, "media")) |media| if (!self.mediaMatches(media)) return;
                f.render_blocking = !self.in_body;
            },
            .preload => {
                const destination = link_types.preloadDestination(attr(tag, "as")) orelse return;
                if (!link_types.typeMatches(attr(tag, "type"), destination)) return;
                f.kind = .preload;
                f.destination = destination;
                // Blink: a preload never blocks rendering.
                f.render_blocking = false;
            },
            .modulepreload => {
                f.kind = .modulepreload;
                f.destination = link_types.asDestination(attr(tag, "as")) orelse .script;
                if (!f.destination.isScriptLike()) return;
                f.render_blocking = false;
            },
            .prefetch, .icon, .none => return,
        }
        report(sink, &f);
    }

    /// HTML 4.8.4.3.9 steps 2-5: a picture's first source with a usable
    /// source set, matching media and a supported type is its img's.
    fn source(self: *Scanner, tag: *const TagToken) !void {
        if (!self.in_picture or self.picture_source != null) return;
        const srcset = attr(tag, "srcset") orelse return;
        var candidates: image_source_selection.Srcset = .{ .input = srcset };
        if (candidates.next() == null) return;
        if (attr(tag, "media")) |media| if (!self.mediaMatches(media)) return;
        if (attr(tag, "type")) |mime| if (!image_source_selection.sourceTypeSupported(self.allocator, mime)) return;
        const srcset_copy = try self.allocator.dupe(u8, srcset);
        errdefer self.allocator.free(srcset_copy);
        const sizes_copy = try self.allocator.dupe(u8, attr(tag, "sizes") orelse "");
        self.picture_source = .{ .srcset = srcset_copy, .sizes = sizes_copy };
    }

    /// HTML "update the image data" steps 7-23 as far as the request: the
    /// selected source of the img (or of its picture's source).
    fn img(self: *Scanner, tag: *const TagToken, sink: Sink) !void {
        // A lazy image waits for layout, which a speculative one has not
        // (Blink IsLazyLoadImageDeferable, WebKit isLazyloadingImage).
        if (attr(tag, "loading")) |loading| if (std.ascii.eqlIgnoreCase(trimHtmlSpace(loading), "lazy")) return;
        const srcset = attr(tag, "srcset");
        const in_picture = self.in_picture;
        const selected = if (in_picture and self.picture_source != null)
            image_source_selection.selectFromAttributes(self.allocator, "", self.picture_source.?.srcset, self.picture_source.?.sizes, self.options.media)
        else if (srcset != null or in_picture)
            image_source_selection.selectFromAttributes(self.allocator, attr(tag, "src") orelse "", srcset orelse "", attr(tag, "sizes") orelse "", self.options.media)
        else if (attr(tag, "src")) |src| image_source_selection.ImageSource{ .url = src, .density = 1 } else null;
        const chosen = selected orelse return;
        var f = self.found(.image, chosen.url);
        f.cors = script_request.corsSettingFromAttribute(attr(tag, "crossorigin"));
        f.referrer_policy = self.referrerPolicyOf(tag);
        f.initiator_type = .img;
        f.imageset = srcset != null or in_picture;
        report(sink, &f);
    }

    /// An input in the Image Button state fetches its src (HTML 4.10.5.1.19).
    fn input(self: *Scanner, tag: *const TagToken, sink: Sink) !void {
        const input_type = attr(tag, "type") orelse return;
        if (!std.ascii.eqlIgnoreCase(trimHtmlSpace(input_type), "image")) return;
        const src = attr(tag, "src") orelse return;
        var f = self.found(.image, src);
        f.initiator_type = .input;
        report(sink, &f);
    }

    /// HTML 4.8.9 "determine the element's poster frame": the poster's
    /// request has no CORS mode and credentials "include", whatever the
    /// crossorigin attribute says (Blink scans the poster too:
    /// StartTagScanner::ProcessVideoAttribute).
    fn video(self: *Scanner, tag: *const TagToken, sink: Sink) !void {
        const poster = attr(tag, "poster") orelse return;
        var f = self.found(.image, poster);
        f.initiator_type = .video;
        report(sink, &f);
    }

    /// The @import rules of the style element that just ended.
    fn emitImports(self: *Scanner, sink: Sink) !void {
        const urls = try self.css.takeImports();
        defer {
            for (urls) |u| self.allocator.free(u);
            self.allocator.free(urls);
        }
        for (urls) |url| {
            var f = self.found(.import, url);
            f.initiator_type = .css;
            // Blink CSSPreloadScanner::EmitRule: a style element whose media
            // does not match does not block; otherwise one outside the body
            // does.
            f.render_blocking = self.style_media_matches and !self.in_body;
            report(sink, &f);
        }
    }

    fn mediaMatches(self: *const Scanner, media: []const u8) bool {
        return css.media_queries.MediaQueryList.matchesQuery(self.allocator, media, &self.options.media) catch true;
    }

    fn clearPicture(self: *Scanner) void {
        const picked = self.picture_source orelse return;
        self.allocator.free(picked.srcset);
        self.allocator.free(picked.sizes);
        self.picture_source = null;
    }
};

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn attr(tag: *const TagToken, name: []const u8) ?[]const u8 {
    const a = tag.getAttribute(name) orelse return null;
    return a.getValue();
}

fn trimHtmlSpace(value: []const u8) []const u8 {
    return std.mem.trim(u8, value, " \t\n\r\x0c");
}

/// The element's nonce, if CSP 6.7.3.1 "Is element nonceable?" would say
/// Nonceable - as the element's own fetch would use it
/// (dom.csp_violations.nonceableScriptNonce): not after a duplicate-attribute
/// parse error (step 3), and for a script not when an attribute's name or
/// value holds "<script" or "<style" (step 2; Blink's scanner checks the same,
/// StartTagScanner::MaybeClearNonceForDanglingMarkup).
fn nonceOf(tag: *const TagToken, script_element: bool) []const u8 {
    const nonce = attr(tag, "nonce") orelse return "";
    if (nonce.len == 0 or tag.had_duplicate_attribute) return "";
    if (script_element) for (tag.attributes.toSlice()) |*a| {
        for ([_][]const u8{ a.getName(), a.getValue() }) |text| {
            if (containsIgnoreCase(text, "<script") or containsIgnoreCase(text, "<style")) return "";
        }
    };
    return nonce;
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[i..][0..needle.len], needle)) return true;
    }
    return false;
}

fn priority(value: ?[]const u8) fetch.internal.request.Priority {
    const v = value orelse return .auto;
    if (std.ascii.eqlIgnoreCase(v, "high")) return .high;
    if (std.ascii.eqlIgnoreCase(v, "low")) return .low;
    return .auto;
}

fn hasRenderToken(value: ?[]const u8) bool {
    const v = value orelse return false;
    return link_types.hasToken(v, "render");
}

/// HTML's void elements, which hold no img (Blink IsVoidElement).
fn isVoid(name: []const u8) bool {
    const void_elements = [_][]const u8{ "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr" };
    for (void_elements) |v| if (eql(name, v)) return true;
    return false;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// What a scan found, as "kind url" lines.
const Collected = struct {
    lines: std.ArrayListUnmanaged(u8) = .empty,
    blocking: std.ArrayListUnmanaged(bool) = .empty,

    fn sink(self: *Collected) Sink {
        return .{ .context = self, .found = collect };
    }

    fn collect(context: *anyopaque, f: *const Found) void {
        const self: *Collected = @ptrCast(@alignCast(context));
        self.lines.print(testing.allocator, "{s} {s}{s}\n", .{ @tagName(f.kind), f.url, if (f.base) |b| b else "" }) catch {};
        self.blocking.append(testing.allocator, f.render_blocking) catch {};
    }

    fn deinit(self: *Collected) void {
        self.lines.deinit(testing.allocator);
        self.blocking.deinit(testing.allocator);
    }
};

fn expectScan(options: Options, expected: []const u8) !void {
    var collected: Collected = .{};
    defer collected.deinit();
    const scanner = try Scanner.create(testing.allocator, options);
    defer scanner.destroy();
    try scanner.scan(collected.sink());
    try testing.expectEqualStrings(expected, collected.lines.items);
}

test "the speculative parser finds scripts, style sheets, preloads and images, and only what their elements would fetch" {
    try expectScan(.{ .input =
        \\<script src=a.js></script><script src=" m.js " type=module></script>
        \\<script src=no.js type=text/plain></script><script src=nm.js nomodule></script>
        \\<script src=e.js type=application/ecmascript></script>
        \\<link rel=stylesheet href=s.css><link rel="alternate stylesheet" href=alt.css>
        \\<link rel=stylesheet href=dis.css disabled><link rel=stylesheet href=t.css type=text/plain>
        \\<link rel=stylesheet href=p.css media="not all"><link href=norel.css>
        \\<link rel=preload as=style href=pre.css><link rel=preload as=bogus href=bogus>
        \\<link rel=modulepreload href=mp.js>
        \\<img src=i.png><img data-src=d.png><img src=lazy.png loading=lazy><img src="data:image/png,x">
        \\<input type=image src=in.png><video poster=p.png></video>
    }, "classic_script a.js\nmodule_script m.js\nclassic_script e.js\nstyle_sheet s.css\npreload pre.css\nmodulepreload mp.js\nimage i.png\nimage in.png\nimage p.png\n");
}

test "nothing is fetched from a template's contents, except a declarative shadow root's; rawtext hides markup" {
    try expectScan(.{ .input =
        \\<template><script src=t1.js></script><img src=t2.png></template>
        \\<div><template shadowrootmode=closed><script src=dsd.js></script></template></div>
        \\<template><div><template shadowrootmode=open><img src=nested.png></template></div></template>
        \\<template><style></template><img src=in-style.png></style></template>
        \\<xmp><script src=xmp.js></script></xmp><textarea><img src=ta.png></textarea>
        \\<noscript><img src=ns.png></noscript>
    }, "classic_script dsd.js\n");
}

test "SVG's script and image load from href or xlink:href, MathML's script loads nothing, and a breakout tag ends foreign content" {
    try expectScan(.{ .input =
        \\<svg><script href=s1.js></script><script xlink:href=s2.js></script><image href=i1.png></image><image xlink:href=i2.png /></svg>
        \\<math><script src=m.js></script><font><script src=mf.js></script></font></math>
        \\<math><p><script src=after-breakout.js></script></math>
    }, "classic_script s1.js\nclassic_script s2.js\nimage i1.png\nimage i2.png\nclassic_script after-breakout.js\n");
}

test "a picture's first eligible source picks the img's URL; a void element between them keeps the association" {
    try expectScan(.{ .input =
        \\<picture><source srcset=a.png media="not all"><source srcset=b.png type=text/plain><source srcset=c.png><br><img src=fallback.png></picture>
        \\<picture><source srcset=lost.png></picture>
        \\<img srcset="x1.png 1x, x2.png 2x">
    }, "image c.png\nimage x1.png\n");
}

test "the first base element with an href predicts the base URL, unless the document has one already; inside a declarative shadow root it does not count" {
    try expectScan(.{ .input = "<base target=x><div><template shadowrootmode=open><base href=//dsd/></template></div><base href=//one/><base href=//two/><script src=a.js></script>" }, "classic_script a.js//one/\n");
    try expectScan(.{ .input = "<base href=//one/><script src=a.js></script>", .base_known = true }, "classic_script a.js\n");
}

test "a style element's @import rules are fetched, blocking outside the body only, and not when its media does not match" {
    var collected: Collected = .{};
    defer collected.deinit();
    const scanner = try Scanner.create(testing.allocator, .{ .input = "<style>@import url(h.css);</style><style media=print>@import 'print.css';</style><p>x</p><style>@import url(b.css)</style>" });
    defer scanner.destroy();
    try scanner.scan(collected.sink());
    try testing.expectEqualStrings("import h.css\nimport print.css\nimport b.css\n", collected.lines.items);
    try testing.expectEqualSlices(bool, &.{ true, false, false }, collected.blocking.items);
}

test "a parser-blocking script or style sheet blocks rendering until the body starts; async, defer and module scripts only with blocking=render" {
    var collected: Collected = .{};
    defer collected.deinit();
    const scanner = try Scanner.create(testing.allocator, .{ .input = "<script src=a.js></script><link rel=stylesheet href=h.css><script src=d.js defer></script><script src=r.js async blocking=render></script><img src=i.png><link rel=stylesheet href=b.css><script src=s.js></script>" });
    defer scanner.destroy();
    try scanner.scan(collected.sink());
    try testing.expectEqualSlices(bool, &.{ true, true, false, true, false, false, false }, collected.blocking.items);
}

test "input pushed after the scan started is scanned where the last scan stopped, and a tag split across pushes is read whole" {
    var collected: Collected = .{};
    defer collected.deinit();
    const scanner = try Scanner.create(testing.allocator, .{ .input = "<img src=one.png><scr", .complete = false });
    defer scanner.destroy();
    try scanner.scan(collected.sink());
    try testing.expectEqualStrings("image one.png\n", collected.lines.items);
    try scanner.append("ipt src=two.js></script>");
    try scanner.scan(collected.sink());
    scanner.complete();
    try scanner.scan(collected.sink());
    try testing.expectEqualStrings("image one.png\nclassic_script two.js\n", collected.lines.items);
}

test "a meta referrer sets the policy of later requests whose element sets none, and a meta CSP in the head is recorded for them" {
    var collected: Collected = .{};
    defer collected.deinit();
    const scanner = try Scanner.create(testing.allocator, .{ .input = "<meta http-equiv=Content-Security-Policy content=\"img-src 'none'\"><meta name=referrer content=no-referrer><img src=a.png><body><meta http-equiv=content-security-policy content=\"script-src 'none'\">" });
    defer scanner.destroy();
    try scanner.scan(collected.sink());
    try testing.expectEqual(fetch.internal.ReferrerPolicy.no_referrer, scanner.referrer_policy);
    const policies = scanner.newPolicies();
    try testing.expectEqual(@as(usize, 1), policies.len);
    try testing.expectEqualStrings("img-src 'none'", policies[0]);
    try testing.expectEqual(@as(usize, 0), scanner.newPolicies().len);
}

test "a nonce is passed on only where the element would be nonceable" {
    const Nonces = struct {
        list: std.ArrayListUnmanaged(u8) = .empty,
        fn sink(self: *@This()) Sink {
            return .{ .context = self, .found = collect };
        }
        fn collect(context: *anyopaque, f: *const Found) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.list.print(testing.allocator, "{s}={s};", .{ f.url, f.nonce }) catch {};
        }
    };
    var nonces: Nonces = .{};
    defer nonces.list.deinit(testing.allocator);
    const scanner = try Scanner.create(testing.allocator, .{ .input = "<script src=a.js nonce=n1></script><script src=b.js nonce=n2 title=\"<script\"></script><script src=c.js nonce=n3 nonce=dup></script><link rel=stylesheet href=d.css nonce=n4>" });
    defer scanner.destroy();
    try scanner.scan(nonces.sink());
    try testing.expectEqualStrings("a.js=n1;b.js=;c.js=;d.css=n4;", nonces.list.items);
}

test "a scan with a budget stops at a token boundary past it, and the next one goes on from there" {
    var collected: Collected = .{};
    defer collected.deinit();
    const scanner = try Scanner.create(testing.allocator, .{ .input = "<img src=a.png><img src=b.png><img src=c.png>" });
    defer scanner.destroy();
    try testing.expect(try scanner.scanFor(collected.sink(), 10));
    try testing.expectEqualStrings("image a.png\n", collected.lines.items);
    try testing.expect(!try scanner.scanFor(collected.sink(), 1000));
    try testing.expectEqualStrings("image a.png\nimage b.png\nimage c.png\n", collected.lines.items);
}
