//! Resources named by used style values (CSS Values 4 §4.5.4).
//!
//! A document owns its cache in StyleEngine.Rare. Entries own request
//! metadata, never elements or computed styles. They survive style changes
//! so equivalent pending and completed requests are reused. The document's
//! teardown cancels every outstanding fetch before freeing its entries.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const fetch = @import("fetch");
const interfaces = @import("interfaces");
const css = @import("css");
const hooks = @import("hooks.zig");
const window_documents = @import("../window_documents.zig");
const document_activity = @import("../document_activity.zig");
const instance_bridge = @import("../instance_bridge.zig");
const element_data = @import("../element_data.zig");
const NodeBase = @import("../node_base.zig").NodeBase;
pub const font_loading = @import("font_loading.zig");
pub const svg_resources = @import("svg_resources.zig");

/// Synchronous parse context. The URL resolver points into THIS value only
/// after options() is called on the caller's stable local variable. Parsed
/// URL values retain the immutable source; neither it nor a parsed value
/// retains the element used to resolve the URL.
pub const ParseContext = struct {
    parse: css.properties.ParseOptions,
    source: ?*css.style_values.ResourceSource = null,
    url_context: ?@import("sheet.zig").UrlContext = null,

    pub fn options(self: *const ParseContext) css.properties.ParseOptions {
        var result = self.parse;
        result.resource_source = self.source;
        if (self.url_context) |*context| result.url_resolver = context.resolver();
        return result;
    }

    pub fn deinit(self: *ParseContext) void {
        if (self.source) |source| source.unref();
        self.source = null;
    }

    pub fn forSheet(record: *@import("sheet.zig").SheetRecord, instance: *runtime.Instance, text: []const u8) Allocator.Error!ParseContext {
        return .{
            .parse = .{ .allocator = record.allocator, .quirks = record.mode.quirks },
            .source = try record.resourceSource(text),
            .url_context = record.urlContext(instance),
        };
    }
};

/// CSS Values 4 §4.5.1: an inline URL's base is its element's node-document
/// base, captured at parse time. Its fetch referrer/policy use the client.
/// No source or base string is allocated for resource-free text (Q25).
pub fn inlineParseContext(element: *runtime.Instance, allocator: Allocator, quirks: bool, text: []const u8) Allocator.Error!ParseContext {
    var result: ParseContext = .{ .parse = .{ .allocator = allocator, .quirks = quirks } };
    if (!mayHaveResources(text)) return result;
    const base = interfaces.Node.get_baseURI(element) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => "",
    };
    defer if (base.len != 0) element.ctx.allocator.free(base);
    const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = base });
    result.source = source;
    result.url_context = .{ .instance = element, .base = source.base_url };
    return result;
}

/// HTML rendering §15.3.4 / §15.3.9: precisely these local names have a
/// background presentational hint. Called once before the existing selector
/// attribute scan, so all other elements pay only this bounded name lookup.
pub fn hasBackgroundHint(local_name: []const u8) bool {
    const names = std.StaticStringMap(void).initComptime(.{
        .{ "body", {} },  .{ "table", {} }, .{ "thead", {} }, .{ "tbody", {} },
        .{ "tfoot", {} }, .{ "tr", {} },    .{ "td", {} },    .{ "th", {} },
    });
    return names.has(local_name);
}

fn isBackgroundHintElement(element: *runtime.Instance) bool {
    const data = element_data.of(element) orelse return false;
    return hasBackgroundHint(data.local_name.asSlice()) and
        std.mem.eql(u8, data.namespaceSlice() orelse "", "http://www.w3.org/1999/xhtml");
}

/// The caller already checked the tag and found the attribute during its
/// existing scan. An absent attribute returns without parsing/allocation.
/// The cache owns a copy; no attribute slice survives this synchronous call.
pub fn backgroundHint(element: *runtime.Instance, state: *@import("element_style.zig").ElementStyle, attribute: ?[]const u8) Allocator.Error!?*const css.declarations.DeclarationBlock {
    const input = attribute orelse {
        state.dropBackgroundHint();
        return null;
    };
    if (input.len == 0) {
        state.dropBackgroundHint();
        return null;
    }
    const base = interfaces.Node.get_baseURI(element) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => "",
    };
    defer if (base.len != 0) element.ctx.allocator.free(base);
    // DOM mutations invalidate computed style; checking the captured base
    // here also invalidates the hint after base[href] changes, while an
    // unrelated mutation reuses the already parsed/resolved value.
    if (state.background_hint) |old| {
        if (std.mem.eql(u8, old.input, input) and std.mem.eql(u8, old.source.base_url, base)) return &old.block;
    }
    const allocator = state.allocator;
    const hint = try allocator.create(@import("element_style.zig").BackgroundHint);
    errdefer allocator.destroy(hint);
    const owned_input = try allocator.dupe(u8, input);
    errdefer allocator.free(owned_input);
    const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = base });
    errdefer source.unref();
    var block = css.declarations.DeclarationBlock.init(allocator);
    errdefer block.deinit();
    // HTML's hint algorithm: encoding-parse-and-serialize against the node
    // document, then supply that absolute URL to the normal typed grammar.
    // The latter gets NO resolver: a URL is resolved only once.
    if (try @import("../encoding_parse.zig").encodingParseAndSerialize(element, input)) |url| {
        defer element.ctx.allocator.free(url);
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(allocator);
        try text.appendSlice(allocator, "url(");
        try css.style_values.appendString(url, &text, allocator);
        try text.append(allocator, ')');
        _ = try block.setProperty(.{ .allocator = allocator, .resource_source = source }, "background-image", text.items, "");
    }
    hint.* = .{ .allocator = allocator, .input = owned_input, .source = source, .block = block };
    state.dropBackgroundHint();
    state.background_hint = hint;
    return &hint.block;
}

/// Request equivalence within ONE document/security context. The use, not
/// the URL's spelling, supplies destination/CORS/credentials. Referrer
/// provenance remains significant even for equal absolute URLs.
pub const RequestKey = struct {
    url: []const u8,
    referrer: ?[]const u8 = null,
    referrer_policy: fetch.internal.ReferrerPolicy = .empty,
    destination: fetch.internal.Destination = .image,
    mode: fetch.internal.RequestMode = .no_cors,
    credentials: fetch.internal.CredentialsMode = .include,
    origin_clean: bool = true,

    pub fn eql(self: RequestKey, other: RequestKey) bool {
        return std.mem.eql(u8, self.url, other.url) and
            optionalStringEqual(self.referrer, other.referrer) and
            self.referrer_policy == other.referrer_policy and
            self.destination == other.destination and
            self.mode == other.mode and
            self.credentials == other.credentials and
            self.origin_clean == other.origin_clean;
    }

    pub fn clone(self: RequestKey, allocator: Allocator) Allocator.Error!RequestKey {
        var copy = self;
        copy.url = try allocator.dupe(u8, self.url);
        errdefer allocator.free(copy.url);
        copy.referrer = if (self.referrer) |referrer| try allocator.dupe(u8, referrer) else null;
        return copy;
    }

    pub fn deinit(self: RequestKey, allocator: Allocator) void {
        allocator.free(self.url);
        if (self.referrer) |referrer| allocator.free(referrer);
    }
};

fn optionalStringEqual(a: ?[]const u8, b: ?[]const u8) bool {
    if (a) |left| return if (b) |right| std.mem.eql(u8, left, right) else false;
    return b == null;
}

pub const KeyContext = struct {
    pub fn hash(_: KeyContext, key: RequestKey) u64 {
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHash(&hasher, key.url.len);
        hasher.update(key.url);
        std.hash.autoHash(&hasher, key.referrer != null);
        if (key.referrer) |referrer| {
            std.hash.autoHash(&hasher, referrer.len);
            hasher.update(referrer);
        }
        std.hash.autoHash(&hasher, key.referrer_policy);
        std.hash.autoHash(&hasher, key.destination);
        std.hash.autoHash(&hasher, key.mode);
        std.hash.autoHash(&hasher, key.credentials);
        std.hash.autoHash(&hasher, key.origin_clean);
        return hasher.final();
    }

    pub fn eql(_: KeyContext, a: RequestKey, b: RequestKey) bool {
        return a.eql(b);
    }
};

/// A cache entry is address-stable while an asynchronous fetch refers to it.
pub const Entry = struct {
    key: RequestKey,
    status: enum { pending, complete, failed } = .pending,
    handle: ?*fetch.algorithms.AsyncFetch = null,
    /// Non-owning back link to the document that owns this entry. Its
    /// generation fences forced teardown; no fetch keeps a document alive.
    document: ?*runtime.Instance = null,
    document_generation: u64 = 0,
    abort_marked: bool = false,

    /// CSS Values 4 §4.5.4, fetch a style resource, steps 2–8. URL
    /// resolution (step 1) already happened while computing the value.
    pub fn start(self: *Entry, document: *runtime.Instance, initiator: fetch.internal.InitiatorType) !void {
        self.document = document;
        self.document_generation = runtime.SlabAllocator.generationOf(document);
        errdefer self.status = .failed;
        const allocator = document.ctx.allocator;
        const request = try fetch.internal.InternalRequest.init(allocator, self.key.url);
        var owned = true;
        defer if (owned) request.deinit();
        request.destination = self.key.destination;
        request.mode = self.key.mode;
        request.credentials_mode = self.key.credentials;
        request.use_url_credentials = true;
        request.referrer_policy = self.key.referrer_policy;
        request.initiator_type = if (self.key.origin_clean) initiator else null;
        const realm_record = document.ctx.getRealm() orelse return error.InvalidState;
        const global: *runtime.Instance = @ptrCast(@alignCast(realm_record.global_object orelse return error.InvalidState));
        var client = try @import("../global_settings.zig").requestClient(global);
        defer client.deinit();
        try fetch.internal.populateRequestFromClient(request, client.request);
        // Browser majority (Chrome/Firefox, css-integration/image and
        // font-face): even a no-CORS image uses its declaring external
        // sheet's referrer and response policy. The empty policy defers to
        // the client's policy container, as for stylesheet @imports.
        if (self.key.referrer) |referrer| try request.setReferrerUrl(referrer);
        owned = false;
        self.handle = try fetch.algorithms.AsyncFetch.start(allocator, request, .{}, @import("../agent_fetches.zig").of(document.ctx), .{
            .context = self,
            .done = done,
            .alive = alive,
            .gone = gone,
            .finished = finished,
        });
    }

    fn alive(context: *anyopaque) bool {
        const self: *Entry = @ptrCast(@alignCast(context));
        const document = self.document orelse return false;
        return document_activity.activity(document, self.document_generation) != .gone;
    }

    fn gone(context: *anyopaque) void {
        const self: *Entry = @ptrCast(@alignCast(context));
        self.handle = null;
        self.status = .failed;
    }

    fn done(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *Entry = @ptrCast(@alignCast(context));
        var result = outcome catch {
            self.status = .failed;
            return;
        };
        defer result.deinit();
        self.status = if (result.response.response_type != .@"error" and fetch.internal.isOkStatus(result.response.status)) .complete else .failed;
    }

    fn finished(context: *anyopaque) void {
        const self: *Entry = @ptrCast(@alignCast(context));
        self.handle = null;
    }

    fn cancel(self: *Entry) void {
        self.abort_marked = false;
        if (self.handle) |handle| {
            self.handle = null;
            handle.terminate();
            self.status = .failed;
        }
    }

    fn deinit(self: *Entry, allocator: Allocator) void {
        self.cancel();
        self.key.deinit(allocator);
        allocator.destroy(self);
    }
};

/// Allocated only for a style resource or external SVG reference. This is
/// owned by StyleEngine.Rare; its document pointer is a back link, not a hold.
pub const State = struct {
    allocator: Allocator,
    document: *runtime.Instance,
    document_generation: u64,
    /// Sharing storage with SVG's cache does not establish CSS interest.
    /// Only resource-bearing styles opt into mutation-triggered style walks.
    css_interested: bool = false,
    /// Weak notification link: Document owns its FontFaceSet. A requested
    /// empty set needs one ready turn, but no mutation-driven style walks.
    font_set: ?*runtime.Instance = null,
    font_set_generation: u64 = 0,
    font_interested: bool = false,
    pending: bool = false,
    cache: Cache,
    svg: svg_resources.Cache,
    fonts: ?*font_loading.ResourceCache = null,

    pub fn create(allocator: Allocator, document: *runtime.Instance) Allocator.Error!*State {
        const state = try allocator.create(State);
        state.* = .{
            .allocator = allocator,
            .document = document,
            .document_generation = runtime.SlabAllocator.generationOf(document),
            .cache = Cache.init(allocator),
            .svg = svg_resources.Cache.init(allocator),
        };
        return state;
    }

    pub fn destroy(self: *State) void {
        if (self.fonts) |fonts| {
            fonts.deinit();
            self.allocator.destroy(fonts);
        }
        self.svg.deinit();
        self.cache.deinit();
        self.allocator.destroy(self);
    }

    pub fn ensureFontCache(self: *State) Allocator.Error!*font_loading.ResourceCache {
        if (self.fonts) |fonts| return fonts;
        const fonts = try self.allocator.create(font_loading.ResourceCache);
        fonts.* = font_loading.ResourceCache.init(self.allocator);
        self.fonts = fonts;
        return fonts;
    }

    pub fn invalidate(self: *State) void {
        if ((!self.css_interested and !self.font_interested) or self.pending) return;
        if (document_activity.activity(self.document, self.document_generation) == .gone) return;
        self.pending = true;
        window_documents.requestRendering(self.document);
    }

    pub fn noteInterest(self: *State) void {
        self.css_interested = true;
        self.invalidate();
    }

    pub fn fontSet(self: *State) ?*font_loading.Set {
        const instance = self.font_set orelse return null;
        if (runtime.SlabAllocator.generationOf(instance) != self.font_set_generation) return null;
        return hooks.fontSetOf(instance);
    }
};

/// Font Loading 3 §3.1 environment changes only notify a set that already
/// exists. In particular, releasing a stylesheet never constructs fonts.
pub fn fontEnvironmentChanged(document: *runtime.Instance) void {
    const style = hooks.engineOf(document) orelse return;
    const state = style.resourceState() orelse return;
    const set = state.fontSet() orelse return;
    set.environmentChanged();
}

pub fn installHooks() void {
    @import("../adopting_steps.zig").install(backgroundAdopted);
    @import("../document_fetches.zig").install(.{
        .discard = discardRealm,
        .prepare_abort = prepareAbort,
        .abort = abortDocument,
    });
}

fn backgroundAdopted(element: *runtime.Instance, _: ?*runtime.Instance) void {
    const state = @import("element_style.zig").existingOf(element) orelse return;
    if (state.background_hint == null) return;
    state.dropBackgroundHint();
    state.dropCache();
}

fn discardRealm(_: runtime.Context) void {
    // Document's StyleEngine owns and cancels the cache during its teardown.
}

fn prepareAbort(document: *runtime.Instance) bool {
    const engine = hooks.engineOf(document) orelse return false;
    const state = engine.resourceState() orelse return false;
    var marked = state.svg.markAbort();
    if (state.fonts) |fonts| marked = fonts.markAbort() or marked;
    var entries = state.cache.entries.valueIterator();
    while (entries.next()) |entry| {
        entry.*.abort_marked = entry.*.handle != null;
        marked = marked or entry.*.abort_marked;
    }
    return marked;
}

fn abortDocument(document: *runtime.Instance) void {
    const engine = hooks.engineOf(document) orelse return;
    const state = engine.resourceState() orelse return;
    if (state.fonts) |fonts| fonts.abortMarked();
    state.svg.abortMarked();
    var entries = state.cache.entries.valueIterator();
    while (entries.next()) |entry| if (entry.*.abort_marked) entry.*.cancel();
}

/// An allocation-free interest scan, not a CSS parser or cascade. Escaped
/// function names go through the existing tokenizer's name comparison.
/// Ordinary color/length declarations have neither '(' nor '@' nor '\\'.
pub fn mayHaveResources(text: []const u8) bool {
    if (std.mem.indexOfAny(u8, text, "(@\\") == null) return false;
    var tokens = css.Tokenizer.init(text);
    while (true) {
        const token = tokens.next();
        switch (token.token_type) {
            .eof => return false,
            .url => return true,
            .function => if (css.tokenizer.nameEql(token.value, "url") or
                css.tokenizer.nameEql(token.value, "src") or
                css.tokenizer.nameEql(token.value, "image-set") or
                // CSS Variables 1 §2.1: a url() that var()/env()/random-item()
                // substitutes resolves against THIS declaration's base, so
                // the base is captured for a value that may bring one in.
                css.substitution.functionId(token.value) != null) return true,
            .at_keyword => if (css.tokenizer.nameEql(token.value, "font-face")) return true,
            else => {},
        }
    }
}

/// Select a top-level image URL from an ALREADY parsed value. An occurrence
/// inside image-set(), cross-fade() or image() needs that function's typed
/// candidate selection (liaison Q20); discovering its URL is not permission
/// to fetch every candidate. No CSS validity or URL resolution happens here.
pub fn isSimpleImageOccurrence(text: []const u8, range: css.style_values.ResourceUrl.Range) bool {
    if (range.start >= range.end or range.end > text.len) return false;
    var tokens = css.Tokenizer.init(text[0..range.start]);
    var depth: usize = 0;
    while (true) switch (tokens.next().token_type) {
        .eof => return depth == 0,
        // This tokenizer emits '(' separately from the function name.
        .left_paren, .left_bracket, .left_brace => depth += 1,
        .right_paren, .right_bracket, .right_brace => {
            if (depth == 0) return false;
            depth -= 1;
        },
        else => {},
    };
}

/// Attribute names are checked before their values: arbitrary data-* and
/// class changes on documents without resources never scan a value.
pub fn canCarryResource(local_name: []const u8) bool {
    const names = std.StaticStringMap(void).initComptime(.{
        .{ "style", {} },      .{ "background", {} }, .{ "fill", {} },
        .{ "stroke", {} },     .{ "marker", {} },     .{ "marker-start", {} },
        .{ "marker-mid", {} }, .{ "marker-end", {} }, .{ "clip-path", {} },
        .{ "mask", {} },       .{ "filter", {} },     .{ "cursor", {} },
    });
    return names.has(local_name);
}

fn nodeDocument(node: *NodeBase, instance: *runtime.Instance) ?*runtime.Instance {
    return if (node.node_type == NodeBase.DOCUMENT_NODE) instance else interfaces.Node.get_ownerDocument(instance) catch null;
}

fn attributeMayIntroduce(local_name: []const u8, value: ?[]const u8) bool {
    if (!canCarryResource(local_name)) return false;
    const text = value orelse return false;
    return if (std.mem.eql(u8, local_name, "background")) text.len != 0 else mayHaveResources(text);
}

/// DOM handle-attribute-changes: invalidate, never resolve style or fetch.
pub fn attributeChanged(element: *runtime.Instance, local_name: []const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    if (namespace == null and std.mem.eql(u8, local_name, "background")) {
        if (@import("element_style.zig").existingOf(element)) |state| state.dropBackgroundHint();
    }
    const node = instance_bridge.getNodeBase(element) orelse return;
    if (!node.is_connected) return;
    const document = nodeDocument(node, element) orelse return;
    const engine = hooks.engineOf(document) orelse return;
    if (engine.resourceState()) |state| {
        state.invalidate();
        if (state.css_interested) return;
    }
    if (namespace != null or !attributeMayIntroduce(local_name, value)) return;
    if (std.mem.eql(u8, local_name, "background") and !isBackgroundHintElement(element)) return;
    const state = engine.ensureResourceState(document) catch return;
    state.noteInterest();
}

/// An inserted subtree can bring resource-bearing inline/presentation
/// attributes that were set while detached. Existing mutation traversal
/// calls this once per inserted element.
pub fn insertionSteps(node: *NodeBase) void {
    if (node.node_type != NodeBase.ELEMENT_NODE or !node.is_connected) return;
    const element: *runtime.Instance = @ptrCast(@alignCast(instance_bridge.getInstance(node) orelse return));
    const data = element_data.of(element) orelse return;
    var attributes = data.attributeIterator();
    while (attributes.next()) |attribute| {
        if (attribute.namespace_uri != null) continue;
        if (!attributeMayIntroduce(attribute.local_name, attribute.value)) continue;
        if (std.mem.eql(u8, attribute.local_name, "background") and !isBackgroundHintElement(element)) continue;
        attributeChanged(element, attribute.local_name, attribute.value, null);
        return;
    }
}

/// Sheet creation/CSSOM changes only mark interest. The actual rules and
/// cascade decide which URLs are used at the rendering opportunity.
pub fn sheetMayHaveResources(record: *@import("sheet.zig").SheetRecord) bool {
    if (record.text) |text| if (mayHaveResources(text)) return true;
    if (record.rules) |rules| for (rules.items) |rule| {
        if (ruleMayHaveResources(rule)) return true;
    };
    return false;
}

fn ruleMayHaveResources(rule: *@import("rules.zig").Rule) bool {
    if (rule.data == .font_face) return true;
    if (rule.data == .import) if (rule.data.import.child) |child| {
        if (sheetMayHaveResources(child)) return true;
    };
    if (rule.block()) |block| for (block.entries.items) |entry| switch (entry) {
        .typed => |declaration| switch (declaration.value) {
            .value => |value| switch (value) {
                .text => |text| if (mayHaveResources(text.bytes)) return true,
                .content => |content| if (mayHaveResources(content.serialization)) return true,
                // Values4 §4.5.4: typed values retain their resource URLs
                // after CSSOM parsing discards the sheet's source text.
                .layers, .image => if (value.resourceUrls().len != 0) return true,
                else => {},
            },
            else => {},
        },
        // A custom property's value loads nothing until var() substitutes it.
        .unparsed, .custom => {},
    };
    if (rule.children()) |children| for (children.items) |child| {
        if (ruleMayHaveResources(child)) return true;
    };
    return false;
}

pub fn sheetChanged(record: *@import("sheet.zig").SheetRecord) void {
    var root = record;
    while (root.parentSheet()) |parent| root = parent;
    const document = if (root.owner_node) |owner|
        (interfaces.Node.get_ownerDocument(owner) catch null) orelse return
    else
        root.constructorDocument() orelse return;
    const engine = hooks.engineOf(document) orelse return;
    if (engine.resourceState()) |state| if (state.css_interested) return state.invalidate();
    if (!sheetMayHaveResources(record)) return;
    const state = engine.ensureResourceState(document) catch return;
    state.noteInterest();
}

/// DOM children-changed covers insertion/removal/move and text mutations.
/// A previously discovered resource can start applying after any of them.
pub fn childrenChanged(parent: *NodeBase, _: @import("../mutation.zig").ChildrenChange) void {
    if (!parent.is_connected and parent.node_type != NodeBase.DOCUMENT_NODE) return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_bridge.getInstance(parent) orelse return));
    const document = nodeDocument(parent, instance) orelse return;
    const engine = hooks.engineOf(document) orelse return;
    if (engine.resourceState()) |state| state.invalidate();
}

/// The browser's existing native-rendering scheduler asks this without
/// allocating. A document with no resource interest requests no extra frame.
pub fn hasPending(document: *runtime.Instance) bool {
    const style_engine = hooks.engineOf(document) orelse return false;
    const state = style_engine.resourceState() orelse return false;
    return state.pending;
}

/// HTML update the rendering, after rAF and its microtasks: resolve used
/// values for connected boxes. runInRealm only supplies the current realm;
/// this is not a new task, checkpoint or rendering phase (liaison Q1).
pub fn updateRendering(document: *runtime.Instance) void {
    if (!hasPending(document)) return;
    @import("engine").runInRealm(document.ctx, renderingSteps, document) catch {};
}

fn renderingSteps(context: ?*anyopaque) void {
    const document: *runtime.Instance = @ptrCast(@alignCast(context orelse return));
    const style_engine = hooks.engineOf(document) orelse return;
    const state = style_engine.resourceState() orelse return;
    if (!state.pending or !document_activity.fullyActive(document, state.document_generation)) return;
    state.pending = false;
    if (state.css_interested) selectDocumentResources(state) catch {
        // Allocation failure must not permanently consume the invalidation.
        state.invalidate();
        return;
    };
    selectDocumentFonts(state) catch {
        state.invalidate();
        return;
    };
    // Font selection marks faces loading before the environment can settle.
    if (state.fontSet()) |set| set.environmentReady();
}

fn selectDocumentFonts(state: *State) !void {
    var set = state.fontSet();
    if (set == null and state.css_interested) {
        const Find = struct {
            document: *runtime.Instance,
            found: bool = false,
            pub fn visit(self: *@This(), rule: *@import("rules.zig").Rule, scope: *runtime.Instance) !void {
                if (scope == self.document and rule.data == .font_face and rule.data.font_face.sources != null) self.found = true;
            }
        };
        var find = Find{ .document = state.document };
        try @import("engine.zig").visitFontRules(state.document, &find);
        // A CSS image alone must not allocate a FontFaceSet or promises.
        if (!find.found) return;
        const instance = try interfaces.Document.get_fonts(state.document);
        set = hooks.fontSetOf(instance);
    }
    if (set) |fonts| {
        try fonts.reconcile();
        try font_loading.selectUsedFonts(fonts);
    }
}

/// Q5's browser-majority image policy differs from font eligibility.
fn eligibleOrigin(element: *runtime.Instance) Allocator.Error!bool {
    return @import("engine.zig").isCssImageResourceOrigin(element);
}

fn selectDocumentResources(state: *State) Allocator.Error!void {
    const root = instance_bridge.getNodeBase(state.document) orelse return;
    var nodes = try @import("../tree_helpers.zig").getShadowIncludingInclusiveDescendants(state.allocator, root);
    defer nodes.deinit();
    for (nodes.items()) |node| {
        if (node.node_type != NodeBase.ELEMENT_NODE or !node.is_connected) continue;
        const element: *runtime.Instance = @ptrCast(@alignCast(instance_bridge.getInstance(node) orelse continue));
        if (!try eligibleOrigin(element)) continue;
        const style = (try @import("engine.zig").computedStyle(element, null)) orelse continue;
        if (style.display().box != .contents) try selectStyleResources(state, style);
        // CSS Pseudo 4: before/after generate a box only for non-normal,
        // non-none content. Their originating display:contents element
        // need not generate its own box for a pseudo-element to exist.
        for ([_][]const u8{ "before", "after" }) |pseudo| {
            const generated = (try @import("engine.zig").computedStyle(element, pseudo)) orelse continue;
            if (generated.display().box == .none or generated.display().box == .contents) continue;
            const content = generated.get(.content);
            if (content != .content or content.content.items.len == 0) continue;
            try selectStyleResources(state, generated);
        }
    }
}

/// The serialized text a background-image value's `resourceUrls()` ranges
/// index. Besides plain text, the typed layer list and single typed image
/// (codex row 119's image values) keep that text beside their components.
pub fn backgroundImageText(value: css.style_values.Value) ?[]const u8 {
    return switch (value) {
        .text => |t| t.bytes,
        .layers => |v| v.text.bytes,
        .image => |v| v.text.bytes,
        else => null,
    };
}

fn selectStyleResources(state: *State, style: *const css.computed_style.ComputedStyle) Allocator.Error!void {
    const background = style.get(.background_image);
    if (backgroundImageText(background)) |text| for (background.resourceUrls()) |occurrence| {
        if (isSimpleImageOccurrence(text, occurrence.range)) try fetchImage(state, occurrence);
    };
    const content = style.get(.content);
    if (content == .content) {
        // Content 3: the optional slash-delimited alternative is text for
        // accessibility, not part of the visual replacement sequence.
        const visual_end = content.content.alternate orelse content.content.items.len;
        for (content.content.items[0..visual_end]) |item| {
            if (item.kind != .image) continue;
            for (item.resource_urls) |occurrence| {
                if (isSimpleImageOccurrence(item.text, occurrence.range)) try fetchImage(state, occurrence);
            }
        }
    }
}

fn fetchImage(state: *State, occurrence: css.style_values.ResourceUrl) Allocator.Error!void {
    if (!occurrence.valid or occurrence.local_fragment) return;
    const source = occurrence.source;
    // CSS Values 4 §4.5.4 steps 2–8. Step 1's resolution is already in
    // the parsed occurrence: never resolve against a later document base.
    const cached = try state.cache.getOrPut(.{
        .url = occurrence.url,
        .referrer = if (source) |s| s.referrer else null,
        .referrer_policy = if (source) |s| fetch.internal.policy_container.parseReferrerPolicyHeader(s.referrer_policy) else .empty,
        .origin_clean = if (source) |s| s.origin_clean else true,
    });
    if (cached.found_existing) return;
    cached.entry.start(state.document, .css) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {}, // A failed request stays failed in this document's cache.
    };
}

pub const Cache = struct {
    allocator: Allocator,
    entries: std.HashMapUnmanaged(RequestKey, *Entry, KeyContext, 80) = .empty,

    pub fn init(allocator: Allocator) Cache {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Cache) void {
        var entries = self.entries.valueIterator();
        while (entries.next()) |entry| entry.*.deinit(self.allocator);
        self.entries.deinit(self.allocator);
    }

    pub fn count(self: *const Cache) usize {
        return self.entries.count();
    }

    /// The caller starts a request only when found_existing is false.
    /// Both pending and completed entries are reusable.
    pub fn getOrPut(self: *Cache, key: RequestKey) Allocator.Error!struct { entry: *Entry, found_existing: bool } {
        if (self.entries.get(key)) |entry| return .{ .entry = entry, .found_existing = true };
        const entry = try self.allocator.create(Entry);
        errdefer self.allocator.destroy(entry);
        entry.* = .{ .key = try key.clone(self.allocator) };
        errdefer entry.key.deinit(self.allocator);
        try self.entries.putNoClobber(self.allocator, entry.key, entry);
        return .{ .entry = entry, .found_existing = false };
    }
};
