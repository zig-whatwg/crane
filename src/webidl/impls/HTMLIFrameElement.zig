//! Implementation for HTMLIFrameElement interface
//!
//! Implements the HTMLIFrameElement per HTML Standard §4.8.5.
//! Spec: https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element
//!
//! ## Key Features
//!
//! - contentWindow: Returns the WindowProxy for the nested browsing context
//! - contentDocument: Returns the nested document (same-origin only)
//! - src/srcdoc: URL or inline HTML content
//! - name: Browsing context name for targeting
//! - sandbox: DOMTokenList controlling iframe restrictions
//!
//! ## Architecture
//!
//! HTMLIFrameElement uses IFrameIntegration to manage the nested browsing context.
//! The integration handles lifecycle (insertion/removal) and navigation.

const std = @import("std");
const log = std.log.scoped(.html_iframe);
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLIFrameElement = interfaces.HTMLIFrameElement;
const DOMTokenList = interfaces.DOMTokenList;
const DOMTokenListImpl = @import("DOMTokenList.zig");

// Import html_core for IFrameIntegration (interface-free module)
const html_core = @import("html_core");
const IFrameIntegration = html_core.IFrameIntegration;
const Origin = html_core.Origin;
const SandboxingFlagSet = html_core.SandboxingFlagSet;

// DOM imports for post-connection steps callback
const dom_module = @import("dom");
const OriginRecord = dom_module.origin_record.OriginRecord;
const sandboxing = dom_module.sandboxing;
const instance_bridge = dom_module.instance_bridge;
const NodeBase = dom_module.NodeBase;

// HTML module for scripted parsing with DOM integration
const html_module = @import("html");
const clock = @import("clock");
const scripted_parser = html_module.scripted_parser;
const document_internals = dom_module.document_internals;
const history_documents = @import("history_documents.zig");
const basic_parser = @import("basic_parser");
const url_origin = @import("url").origin;

pub const State = HTMLIFrameElement.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
    InvalidState,
};

/// Internal state for HTMLIFrameElement
/// Tracks the nested browsing context and related state
pub const InternalState = struct {
    /// The iframe integration managing the browsing context lifecycle
    integration: *IFrameIntegration,

    /// Allocator for this instance
    allocator: std.mem.Allocator,

    /// DOMTokenList for the sandbox attribute (lazily created)
    sandbox_token_list: ?*runtime.Instance = null,

    /// Cached attribute values for reflection. `src` and `srcdoc` are not
    /// cached: they reflect their content attributes, which "process the
    /// iframe attributes" reads.
    name_attr: ?[]const u8 = null,
    allow_attr: ?[]const u8 = null,
    width_attr: ?[]const u8 = null,
    height_attr: ?[]const u8 = null,
    referrer_policy_attr: ?[]const u8 = null,
    loading_attr: ?[]const u8 = null,
    csp_attr: ?[]const u8 = null,
    align_attr: ?[]const u8 = null,
    scrolling_attr: ?[]const u8 = null,
    frame_border_attr: ?[]const u8 = null,
    long_desc_attr: ?[]const u8 = null,
    margin_height_attr: ?[]const u8 = null,
    margin_width_attr: ?[]const u8 = null,
    private_token_attr: ?[]const u8 = null,

    /// Boolean attributes
    allow_fullscreen: bool = false,
    credentialless: bool = false,

    /// A new state, its integration from `arena` - its element's Browser's
    /// (runtime.arenaOf). The state's own block is the registry's
    /// (`States.create`, in initOwn).
    pub fn init(allocator: std.mem.Allocator, arena: *runtime.ArenaAllocator) !InternalState {
        const integration = try arena.create(IFrameIntegration);
        integration.* = IFrameIntegration.init(allocator);
        integration.block_arena = arena;

        log.debug("[InternalState.init] Created integration={*}", .{integration});

        return .{
            .integration = integration,
            .allocator = allocator,
        };
    }

    /// What the state owns, without its element (dom.orphan_states): the
    /// cached attribute strings. Its content navigable is the element's to
    /// release (`deinit`, before this): an orphaned iframe's was destroyed by
    /// its removing steps, and its integration is a block of the arena.
    pub fn deinit(self: *InternalState) void {
        // NOTE: Do NOT call DOMTokenList.deinit() on sandbox_token_list here.
        // The [SameObject] DOMTokenList instances are managed by the V8 wrapper cache.
        // During context cleanup, the wrapper cache iterates all instances and calls
        // their deinit. If we also call deinit here, we get a double-free crash.
        // Just clear the pointer to avoid dangling references.
        self.sandbox_token_list = null;

        // Free cached strings
        inline for (@typeInfo(InternalState).@"struct".fields) |field| {
            if (field.type == ?[]const u8) {
                if (@field(self, field.name)) |str| {
                    self.allocator.free(str);
                }
                @field(self, field.name) = null;
            }
        }
    }
};

/// The iframe's state: a block of the Browser's arena, registered, so an
/// iframe no deinit reaches - one removed while script held no wrapper of
/// it - still frees its cached strings at its Browser's end
/// (dom.orphan_states, lane orphanleak).
const States = dom_module.orphan_states.Swept(.html_iframe_element, InternalState);

/// `instance`'s iframe state, or null when it is no HTMLIFrameElement. A
/// checked cast: the DOM's steps reach this with any element whose name is
/// "iframe" - createElementNS(other, "iframe") is a plain Element - and an
/// unchecked read of its state as an iframe's was a wild pointer.
pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // The iframe's removing and post-connection steps (HTML 4.8.5).
    dom_module.mutation.registerRemovingStepsCallback(&iframeRemovingStepsCallback) catch |err| {
        log.warn("iframe removing steps not registered: {}", .{err});
    };
    dom_module.mutation.registerPostConnectionStepsCallback(&iframePostConnectionSteps) catch |err| {
        log.warn("iframe post-connection steps not registered: {}", .{err});
    };
    // The WindowProxy's frames[index] finds a child browsing context before
    // its container made the navigable's Window: the container makes it.
    dom_module.child_navigables.install(.{ .window = &windowOfChildNavigable });
    dom_module.auxiliary_navigables.install(.{ .create = &createAuxiliaryNavigable, .definitely_close = &definitelyCloseTraversable });
    dom_module.content_navigables.install(.{
        .delays_load_event = &iframesDelayLoadEvent,
        .run_load_event_steps = &contentNavigableLoadEventSteps,
        .stop_loading = &stopLoadingDocument,
        .is_navigating = &documentIsNavigating,
        .load_delay_may_have_ended = &childLoadDelayMayHaveEnded,
    });
    dom_module.attribute_change_steps.install("iframe", &iframeAttributeChangeSteps);
    dom_module.navigables.install(.{
        .navigate_by_target = &navigateByTarget,
        .follow_hyperlink = &followHyperlink,
        .download_hyperlink = &downloadHyperlink,
        .traverse_navigable = &traverseNavigable,
        .find_by_name = &frameWindowByName,
        .create_browsing_context_and_document = &createBrowsingContextAndDocument,
        .process_frame_attributes = &processFrameAttributes,
    });
    // The states no deinit reached, at their Browser's end.
    States.installSweep();
}

/// HTMLIFrameElement's own construction steps: the generated chain runs HTMLElement's first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    // Initialize internal state
    const state = instance.getState(State);
    state.own._internal = try States.create(instance, try InternalState.init(allocator, runtime.arenaOf(instance)));
    log.debug("[HTMLIFrameElement.init] instance={*} -> internal={*} -> integration={*}", .{ instance, state.own._internal.?, state.own._internal.?.integration });

    // Set Node's local name for iframe identification during DOM operations
    const NodeImpl = @import("Node.zig");
    try NodeImpl.setLocalName(instance, runtime.DOMString.initInterned("iframe"));
}

/// Deinitialize instance. An iframe keeps a deinit of its own rather than a
/// deinitOwn: a finished teardown is refused here, before any ancestor's part
/// runs again; otherwise its own part, then HTMLElement's chain.
pub fn deinit(instance: *runtime.Instance) void {
    // Guard against double-deinit. Every caller checks that the teardown has
    // not begun: the tree's (deinitNodeByType) marks it begun BEFORE it
    // dispatches here, and the others - the wrapper's finalizer, the realm
    // end's orphaned-iframe phase - skip an iframe whose teardown started. So
    // only a finished one is refused here, and one not yet marked is marked
    // before anything of the iframe is freed.
    log.debug("[HTMLIFrameElement.deinit] Called for instance {*}", .{instance});
    if (runtime.instance_lifecycle.isCleanedUp(instance)) {
        log.debug("[HTMLIFrameElement.deinit] Already cleaned up, skipping", .{});
        return;
    }
    _ = runtime.instance_lifecycle.markCleanupStarted(instance);

    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        log.debug("[HTMLIFrameElement.deinit] instance={*} -> integration={*}", .{ instance, internal.integration });
        // Release the integration, then return ITS block too - `init` takes
        // an arena allocation for it, and releasing only what it points to
        // left the struct held for the life of the process. A navigation
        // step running script with it in hand puts that off until it is
        // done (see `IFrameIntegration.busy`).
        dom_module.navigables.releaseContentNavigable(internal.integration);
        // What the state owns, then its block, and no pointer left to it: a
        // second deinit must find nothing to free.
        state.own._internal = null;
        States.destroy(instance);
    } else {
        log.debug("[HTMLIFrameElement.deinit] instance={*} -> No internal state", .{instance});
    }
    interfaces.HTMLElement.deinitChain(instance);
}

/// Constructor implementation
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try HTMLIFrameElement.init(ctx.allocator, ctx);
    errdefer HTMLIFrameElement.deinit(instance);
    return instance;
}

// ============================================================================
// Content Accessors (§4.8.5)
// ============================================================================

/// IFrameIntegration's `retired_realm_destroy`: a realm retired when its
/// iframe was inserted again, or when a navigation gave the navigable a new
/// Window, ends with the integration. A retired realm whose WindowProxy went
/// on is severed from its Window by the engine (destroyWindowRealm), so a
/// function of it that script still holds finds no Window rather than a
/// freed one; the host keeps no handle of its own (`global` is unused).
fn destroyRetiredRealm(data: *anyopaque, global: ?*anyopaque, allocator: std.mem.Allocator) void {
    _ = global;
    _ = allocator;
    const realm: runtime.Context = @ptrCast(@alignCast(data));
    engine.destroyWindowRealm(realm, .global_detached);
}

/// Cleanup callback for iframe context, run when the integration goes with
/// its element: the navigable's realm, if it still has one, ends
/// (engine.destroyWindowRealm, which ends its frames' realms first) - its
/// page is ending with the element in it. A removed iframe's realm is not
/// here any more: the removal took it (dom.navigables.destroyChildNavigable).
fn iframeContextCleanup(integration: *IFrameIntegration) void {
    if (integration.context_cleanup_data) |data| {
        // Cleared first: nothing re-entered below may reach a realm that is
        // ending. Ending one twice finds nothing the second time.
        integration.context_cleanup_data = null;
        engine.destroyWindowRealm(@ptrCast(@alignCast(data)), .global_detached);
    }
}

/// Document creation callback for iframe navigation
/// Called when navigateToSrcDoc or navigateToSrc needs to create a Document instance.
/// Parameters: (runtime_context, browsing_context) -> document_instance
fn createDocumentForIframe(runtime_ctx_ptr: ?*anyopaque, browsing_ctx_ptr: *html_core.BrowsingContext) ?*anyopaque {
    const runtime_ctx: runtime.Context = @ptrCast(@alignCast(runtime_ctx_ptr orelse {
        return null;
    }));
    const allocator = runtime_ctx.allocator;

    // Create a Document instance using the WebIDL interface, of the origin
    // the navigable was given for it (takeNextOrigin), and with the
    // sandboxing flags it was given ("create a new browsing context and
    // document" step 15: the creation sandboxing flags).
    const origin = takeNextOrigin(browsing_ctx_ptr);
    defer if (origin) |record| record.release();
    const document_instance = interfaces.Document.initWith(allocator, runtime_ctx, .{
        .origin = origin,
        .sandboxing_flags = takeNextSandboxingFlags(browsing_ctx_ptr),
    }) catch {
        return null;
    };
    giveAboutBaseUrl(document_instance, browsing_ctx_ptr);
    givePolicyContainer(document_instance, browsing_ctx_ptr);
    giveReferrer(document_instance, browsing_ctx_ptr);
    // HTML "create a new browsing context and document" step 15: the initial
    // about:blank document's type is "html" and its content type
    // "text/html". Set before the elements below are created, which it makes
    // HTML elements.
    document_internals.setDocumentType(document_instance, .html) catch {};
    document_internals.setContentType(document_instance, "text/html") catch {};

    // HTML 7.3.2.1 step 15 supplies the document's registry before step 22
    // creates descendants, whose registry associations persist after creation.
    _ = dom_module.custom_elements.ensureGlobalRegistry(document_instance) catch {
        dom_module.node_creation.destroyUninserted(document_instance);
        return null;
    };

    // Per HTML spec, about:blank documents must have a basic HTML structure:
    // <html><head></head><body></body></html>
    // This is required because browsers always create these elements for any HTML document.
    const DocumentImpl = @import("Document.zig");
    const NodeImpl = @import("Node.zig");

    // Create html element (HTMLHtmlElement)
    const html_element = DocumentImpl.call_createElement(
        document_instance,
        runtime.DOMString.initInterned("html"),
        webidl.Opt(runtime.JSValue).notPassed(),
    ) catch {
        return document_instance; // Continue with empty document if element creation fails
    };

    // Create head element (HTMLHeadElement)
    const head_element = DocumentImpl.call_createElement(
        document_instance,
        runtime.DOMString.initInterned("head"),
        webidl.Opt(runtime.JSValue).notPassed(),
    ) catch {
        return document_instance;
    };

    // Create body element (HTMLBodyElement)
    const body_element = DocumentImpl.call_createElement(
        document_instance,
        runtime.DOMString.initInterned("body"),
        webidl.Opt(runtime.JSValue).notPassed(),
    ) catch {
        return document_instance;
    };

    // Append head to html
    _ = NodeImpl.call_appendChild(html_element, head_element) catch {
        return document_instance;
    };

    // Append body to html
    _ = NodeImpl.call_appendChild(html_element, body_element) catch {
        return document_instance;
    };

    // Append html to document
    _ = NodeImpl.call_appendChild(document_instance, html_element) catch {
        return document_instance;
    };

    // Set the document element (html) on the Document
    DocumentImpl.setDocumentElement(document_instance, html_element);

    // The Document's wrapper, made now in its own realm (see wrapInOwnRealm).
    if (runtime_ctx.engine_ctx == null) return null;
    wrapInOwnRealm(document_instance);

    // Get the active window for this browsing context to associate with the document
    if (browsing_ctx_ptr.getActiveWindow()) |window_ptr| {
        // Set the document on the browsing context
        browsing_ctx_ptr.setActiveDocument(document_instance, window_ptr);

        // Also set the document on the Window
        const WindowImpl = @import("Window.zig");
        const window_instance: *runtime.Instance = @ptrCast(@alignCast(window_ptr));
        WindowImpl.setDocument(window_instance, document_instance);
        // Set the defaultView on the document (bidirectional Document <-> Window link)
        DocumentImpl.setDefaultView(document_instance, window_instance);
    }

    return document_instance;
}

/// Parse HTML content into a Document for iframe navigation.
/// This uses DomTreeAdapter to properly populate the document with parsed content
/// that JavaScript can access via DOM APIs like getElementById(), querySelector(), etc.
/// Parameters: (runtime_context, browsing_context, html_content, byte_stream)
/// -> document_instance. With `byte_stream`, `html_content` is the
/// response's bytes, which the parser decodes (HTML "determining the
/// character encoding").
fn parseHtmlForIframe(
    runtime_ctx_ptr: ?*anyopaque,
    browsing_ctx_ptr: *html_core.BrowsingContext,
    html_content: []const u8,
    byte_stream: ?html_core.window.iframe_integration.ByteStream,
) ?*anyopaque {
    const time_start = clock.monotonicNanos();
    log.debug("[parseHtmlForIframe] time={d}ns START content_len={d}", .{ time_start, html_content.len });

    const runtime_ctx: runtime.Context = @ptrCast(@alignCast(runtime_ctx_ptr orelse {
        return null;
    }));
    const allocator = runtime_ctx.allocator;

    // Get window BEFORE parsing for nested iframe support
    const window_instance: ?*runtime.Instance = if (browsing_ctx_ptr.getActiveWindow()) |window_ptr|
        @ptrCast(@alignCast(window_ptr))
    else
        null;

    // HTML "create and initialize a Document object" step 9: a new Document
    // whose type is "html" and content type "text/html" ("load an HTML
    // document"); step 10: the window's associated Document becomes it. Both
    // happen before the parser exists, so the page's own scripts - run BY the
    // parser - see the document they are in. Associating it only once
    // parsing finished left those scripts on the frame's initial about:blank
    // document: their getElementsByTagName, createElement and body were that
    // document's.
    const document_instance = createNavigationDocument(allocator, runtime_ctx, browsing_ctx_ptr, window_instance, .html, "text/html") orelse return null;

    // The parser's scripting flag: "scripting is enabled" for the new
    // document - not when its active sandboxing flag set, which the
    // navigation gave it, has the sandboxed scripts browsing context flag.
    const scripting_enabled = dom_module.document_scripts.scriptingEnabled(document_instance);

    // The encoding sniffing algorithm's step 6: the container document's
    // encoding, when it is same origin with the new document.
    var parent_encoding_buf: [32]u8 = undefined;
    const parent_encoding: ?[]const u8 = if (byte_stream) |stream|
        (if (stream.parent_same_origin) containerDocumentEncoding(browsing_ctx_ptr, &parent_encoding_buf) else null)
    else
        null;

    // The scripted parser builds the tree incrementally through the
    // DomTreeAdapter, so scripts can reach nodes already parsed.
    log.debug("[parseHtmlForIframe] time={d}ns calling parseHTMLWithScripting", .{clock.monotonicNanos()});
    var parser_canceled = false;
    _ = scripted_parser.parseHTMLWithScripting(
        allocator,
        runtime_ctx,
        html_content,
        .{
            .scripting_enabled = scripting_enabled,
            .parser_canceled = &parser_canceled,
            .window = window_instance,
            .document = document_instance,
            .script_loader = html_module.embedder_scripts.forRealm(runtime_ctx),
            .byte_stream = if (byte_stream) |stream| .{
                .content_type = stream.content_type,
                .parent_encoding = parent_encoding,
            } else null,
        },
    ) catch |err| {
        // The document stays - with whatever was parsed - as the frame's
        // document: a parse that fails part-way is still the page loaded.
        log.warn("[parseHtmlForIframe] parsing stopped: {}", .{err});
    };
    log.debug("[parseHtmlForIframe] time={d}ns parseHTMLWithScripting DONE", .{clock.monotonicNanos()});
    if (parser_canceled) return document_instance;

    // Initiation may have paused on a stylesheet. Its Document-owned parser
    // runs "the end" only after actual EOF, including srcdoc and popups.

    return document_instance;
}

/// HTML "create and initialize a Document object" for a navigation of
/// `browsing_ctx_ptr`, given `kind` ("html" or "xml") and `content_type`:
/// step 9's new Document with its type and content type, about base URL,
/// policy container and referrer; step 10, the window's associated Document
/// becomes it; step 17, its refresh. Both happen before the parser exists,
/// so the page's own scripts - run BY the parser - see the document they are
/// in. Associating it only once parsing finished left those scripts on the
/// frame's initial about:blank document: their getElementsByTagName,
/// createElement and body were that document's. Its wrapper is made in its
/// relevant realm before a parse can suspend or run lifecycle callbacks.
fn createNavigationDocument(
    allocator: std.mem.Allocator,
    runtime_ctx: runtime.Context,
    browsing_ctx_ptr: *html_core.BrowsingContext,
    window_instance: ?*runtime.Instance,
    kind: document_internals.DocType,
    content_type: []const u8,
) ?*runtime.Instance {
    // An XML document is an XMLDocument, as browsers make one (Blink's
    // DocumentInit::CreateDocument for an XML MIME type), where step 9
    // says Document of type "xml".
    // Step 4's origin: navigationParams's, which the navigable was given
    // for it (takeNextOrigin) - shared with its container document for
    // srcdoc, its initiator's for a javascript: URL's String.
    const origin = takeNextOrigin(browsing_ctx_ptr);
    defer if (origin) |record| record.release();
    // Step 9's active sandboxing flag set: navigationParams's final
    // sandboxing flag set, which the commit gave the navigable for it.
    const sandboxing_flags = takeNextSandboxingFlags(browsing_ctx_ptr);
    const document_instance = (if (kind == .xml)
        interfaces.XMLDocument.initWith(allocator, runtime_ctx, .{ .origin = origin, .sandboxing_flags = sandboxing_flags })
    else
        interfaces.Document.initWith(allocator, runtime_ctx, .{ .origin = origin, .sandboxing_flags = sandboxing_flags })) catch return null;
    document_internals.setDocumentType(document_instance, kind) catch {};
    document_internals.setContentType(document_instance, content_type) catch {};
    giveAboutBaseUrl(document_instance, browsing_ctx_ptr);
    givePolicyContainer(document_instance, browsing_ctx_ptr);
    giveReferrer(document_instance, browsing_ctx_ptr);

    const DocumentImpl = @import("Document.zig");
    if (window_instance) |window_inst| {
        browsing_ctx_ptr.setActiveDocument(document_instance, window_inst);
        const WindowImpl = @import("Window.zig");
        WindowImpl.setDocument(window_inst, document_instance);
        DocumentImpl.setDefaultView(document_instance, window_inst);
    } else {
        log.debug("[createNavigationDocument] BC={*} WARNING: No active window, document {*} will NOT be linked!", .{ browsing_ctx_ptr, document_instance });
    }
    // Step 17, once the document is its window's - its URL, which the
    // header's URL is parsed against, is the navigation's from then on.
    giveRefresh(document_instance, browsing_ctx_ptr);
    // The navigable already owns this document.
    wrapInOwnRealm(document_instance);
    return document_instance;
}

/// HTML §7.5.3 "load an XML document" for iframe navigation: "create and
/// initialize a Document object" given "xml" and the response's computed
/// type, and an XML parser for it. Its encoding is the one the response's
/// bytes and Content-Type determine (xml_document_parser.decodeBytes). XML
/// scripting support is enabled unless the navigable's sandbox blocks
/// scripts. Errors are "reported inline by mutating the Document": the tree
/// up to the first error stays and Chrome's and Safari's message block goes
/// in (xml_document_parser.insertErrorMessageBlock says why that shape). Its
/// "the end" runs once the commit returns (finishParserlessNavigation).
fn parseXmlForIframe(
    runtime_ctx_ptr: ?*anyopaque,
    browsing_ctx_ptr: *html_core.BrowsingContext,
    bytes: []const u8,
    response: html_core.window.iframe_integration.XmlResponse,
) ?*anyopaque {
    const runtime_ctx: runtime.Context = @ptrCast(@alignCast(runtime_ctx_ptr orelse return null));
    const allocator = runtime_ctx.allocator;
    const window_instance: ?*runtime.Instance = if (browsing_ctx_ptr.getActiveWindow()) |window_ptr|
        @ptrCast(@alignCast(window_ptr))
    else
        null;
    const document = createNavigationDocument(allocator, runtime_ctx, browsing_ctx_ptr, window_instance, .xml, response.type) orelse return null;
    const xml_parser = html_module.xml_document_parser;
    const sniffing = html_core.parser.encoding_sniffing;
    const transport = if (response.content_type) |content_type| sniffing.transportEncoding(allocator, content_type) else null;
    const decoded = (xml_parser.decodeBytes(allocator, bytes, transport) catch return document) orelse {
        // An encoding the declaration names that there is none of: libxml2's
        // fatal error at the declaration.
        var failure: xml_parser.Failure = .{ .line = 1, .column = 1 };
        const message = "Unsupported encoding";
        @memcpy(failure.message_buffer[0..message.len], message);
        failure.message_len = message.len;
        xml_parser.insertErrorMessageBlock(document, failure) catch {};
        return document;
    };
    defer allocator.free(decoded.text);
    document_internals.setEncoding(document, sniffing.canonicalName(decoded.encoding)) catch {};
    const loader: ?html_module.script_execution.ParserScriptLoader = if (html_module.embedder_scripts.forRealm(runtime_ctx)) |embedder| .{
        .context = embedder.context,
        .load = embedder.loadScript,
        .allocator = allocator,
    } else null;
    const failure = xml_parser.parseInto(document, decoded.text, .{
        .scripting = dom_module.document_scripts.scriptingEnabled(document),
        .script_loader = loader,
    }) catch |err| {
        log.warn("[parseXmlForIframe] parsing stopped: {}", .{err});
        return document;
    };
    if (failure) |found| xml_parser.insertErrorMessageBlock(document, found) catch {};
    return document;
}

/// The name of the encoding of the frame's container document - the
/// document of the element whose content navigable `browsing_context` is -
/// copied into `buf`; null without a container.
fn containerDocumentEncoding(browsing_context: *html_core.BrowsingContext, buf: []u8) ?[]const u8 {
    const container: *runtime.Instance = @ptrCast(@alignCast(browsing_context.container orelse return null));
    const document = (interfaces.Node.get_ownerDocument(container) catch return null) orelse return null;
    var name = interfaces.Document.get_characterSet(document) catch return null;
    defer name.deinit(document.ctx.allocator);
    const slice = name.asSlice();
    if (slice.len > buf.len) return null;
    @memcpy(buf[0..slice.len], slice);
    return buf[0..slice.len];
}

/// Make `document`'s wrapper now, in its relevant realm - the frame's. The
/// binding still wraps an object in the CURRENT realm, and the first wrapper a
/// node gets is the one every realm is handed from then on
/// (template_registry's bound wrapper), so a parent that read
/// `iframe.contentDocument` first would make the frame's document a wrapper
/// with the parent's prototypes. The protocol wraps in the relevant realm
/// (R28); the value is not kept - the wrapper cache holds the wrapper, and the
/// document is its window's, which keeps it alive.
fn wrapInOwnRealm(document: *runtime.Instance) void {
    const held = engine.retainValue(document.ctx, .{ .instance = document }) catch |err| {
        log.debug("the frame's document was not wrapped in its realm: {}", .{err});
        return;
    };
    held.release();
}

/// Script execution callback for iframes
/// Called by IFrameIntegration.executeScriptsInTree to run a script in the
/// iframe's realm (engine.runClassicScript: prepared to run, then cleaned up
/// - a microtask checkpoint when nothing else is running). What it throws is
/// reported for the frame's window.
/// Parameters: (the realm, script_source) -> void
fn executeIframeScript(realm_ptr: ?*anyopaque, source: []const u8) void {
    const realm: runtime.Context = @ptrCast(@alignCast(realm_ptr orelse return));
    if (source.len == 0) return;
    engine.runClassicScript(realm, .{ .utf8 = source }, "", null, .{ .report = reportException, .host = realm }) catch |err| {
        log.debug("a frame's script did not run: {}", .{err});
    };
}

/// HTML "report an exception" for the global of the realm the engine names,
/// or else the frame's (`host`).
fn reportException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const fallback: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse fallback;
    const global = windowOfRealm(realm) orelse return;
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = html_module.report_exception.reportErrorInfo(global, &extracted, .{});
}

/// `realm`'s global object, when it is a Window: the realm record's.
fn windowOfRealm(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return global;
}

/// Run `steps` with `args` in `realm` (engine.runInRealm): the navigation
/// task already running, switching into the navigable's realm. False when
/// the realm is gone and the steps did not run.
fn inRealm(realm: runtime.Context, comptime steps: anytype, args: anytype) bool {
    const Call = struct {
        args: @TypeOf(args),
        fn run(data: ?*anyopaque) void {
            const call: *@This() = @ptrCast(@alignCast(data.?));
            @call(.auto, steps, call.args);
        }
    };
    var call: Call = .{ .args = args };
    engine.runInRealm(realm, Call.run, &call) catch return false;
    return true;
}

/// HTML "shared attribute processing steps for iframe and frame elements",
/// steps 2-3: the `src` value encoding-parsed relative to the element's node
/// document; the empty string, or a value that does not parse, is
/// about:blank. Owned by the element's context allocator.
///
/// The raw attribute value used to go straight to the fetch, which cannot
/// fetch a relative URL, and the navigation failed silently - so an iframe
/// with `src="resources/x.html"` simply never loaded. That is most of WPT:
/// the 52 moving-between-documents files all waited on such a frame.
fn resolveSrc(instance: *runtime.Instance, src: []const u8) []const u8 {
    const allocator = instance.ctx.allocator;
    const blank = "about:blank";
    if (src.len == 0) return allocator.dupe(u8, blank) catch unreachable;
    const base = interfaces.Node.get_baseURI(instance) catch
        return allocator.dupe(u8, src) catch unreachable;
    defer allocator.free(base);
    const base_arg = if (base.len > 0)
        webidl.Opt(runtime.USVString).passed(base)
    else
        webidl.Opt(runtime.USVString).notPassed();
    const url = (interfaces.URL.call_static_parse(instance, src, base_arg) catch null) orelse
        return allocator.dupe(u8, blank) catch unreachable;
    defer runtime.Instance.deinit(url);
    return interfaces.URL.get_href(url) catch allocator.dupe(u8, blank) catch unreachable;
}

/// Location URL update callback for iframes
/// Called by IFrameIntegration.updateLocationUrl to set the iframe's Location URL.
/// Parameters: (the realm, url) -> void
fn updateIframeLocation(realm_ptr: ?*anyopaque, url: []const u8) void {
    const realm: runtime.Context = @ptrCast(@alignCast(realm_ptr orelse return));

    // The realm's Window.
    const window = windowOfRealm(realm) orelse return;

    // Get Window's Location
    const WindowImpl = @import("Window.zig");
    const internal = WindowImpl.getInternal(window) orelse return;
    const location = internal.location orelse return;

    // Record it as the realm's document URL too - only top-level pages and
    // workers ever did, so `document.URL` inside an iframe was "".
    // Document.get_URL and, through it, Location read this.
    realm.setDocumentUrl(url) catch {};

    // Update Location's URL
    const LocationImpl = @import("Location.zig");
    LocationImpl.setURLFromString(location, url) catch {};
}

// ============================================================================
// Navigating a content or auxiliary navigable (HTML §7.4.2 "navigate")
// ============================================================================
//
// Crane's navigable is an IFrameIntegration: an iframe's content navigable,
// or a window.open() popup, which has no container. "Navigate" runs its
// synchronous steps in the caller and everything the spec does "in parallel"
// as tasks on the navigable's event loop:
//
//   navigate()         steps 1-22: history handling, a fragment navigation
//                      (committed on the spot), the ongoing navigation, and
//                      a javascript: URL, which runs in a task of its own
//   runBeforeUnload    step 24.1: beforeunload at the active document - run
//                      by navigate() itself, as browsers do (see there)
//   (the fetch)        step 24.9: about:, data: and file: answered at once,
//                      http(s) through the event loop's AsyncFetch
//   runCommit          "finalize a cross-document navigation" and the history
//                      step it applies: unload the active document and its
//                      descendants, then make the new document active and
//                      load it
//
// Every step finds its navigation by ID. One that finds another navigation
// ongoing - a later navigate() replaced it - or no record at all - its
// navigable went away - stops there. That is the spec's "ongoing navigation",
// and it is how a second navigation in the same task aborts the first.
//
// The design is Blink's (not its code): FrameLoader::StartNavigation commits
// a same-document navigation synchronously and hands everything else to the
// browser process to fetch; FrameLoader::CommitNavigation then detaches the
// old document - Document::DispatchUnloadEvents, pagehide, visibilitychange
// and unload in that order - before the new DocumentLoader commits.
//
// Deviation, stated: the new document keeps the navigable's Window. HTML
// "create and initialize a Document object" reuses the Window only for the
// initial about:blank document; otherwise it is a new realm. Until contexts
// can be recreated around the same global proxy, a navigated frame keeps its
// realm, and handlers on its window persist into the next document.

const navigate_steps = html_core.navigation.navigate_steps;
const navigation_fetch = html_core.navigation.fetch_integration;
const document_lifecycle = dom_module.document_lifecycle;
const fetch_mod = @import("fetch");

/// "Navigate"'s optional arguments that the callers here pass.
pub const NavigateOptions = struct {
    /// "sourceDocument": the document whose script (or element) navigates.
    source_document: ?*runtime.Instance = null,
    history_behavior: navigate_steps.HistoryBehavior = .auto,
    /// "documentResource" as a string: an iframe srcdoc document's markup.
    srcdoc: ?[]const u8 = null,
    initial_insertion: bool = false,
    /// A history traversal's navigation: the session history entry, by id,
    /// that the new document populates - no entry is added.
    traversal_entry: u64 = 0,
    /// With it, the entry the navigable was on before the traversal (the
    /// entry itself for a reload): the new document's activation names it.
    traversal_from: u64 = 0,
    /// "sourceElement": the hyperlink or form submitter that navigates.
    source_element: ?*runtime.Instance = null,
    user_involvement: dom_module.navigation_api.UserInvolvement = .none,
    /// "navigationAPIState": navigate()'s state. BORROWED.
    navigation_api_state: ?html_core.navigation.joint_history.SerializedState = null,
    /// "documentResource" as a POST resource: a form submitted as an entity
    /// body. BORROWED.
    post_resource: ?dom_module.navigables.PostResource = null,
    /// With it, "formDataEntryList" as a FormData holding it. BORROWED.
    form_data: ?*runtime.Instance = null,
    /// "referrerPolicy": a hyperlink's referrerpolicy attribute (or
    /// no-referrer for noreferrer), an iframe's for "navigate an iframe or
    /// frame". The empty string defers to the initiator's policy container.
    referrer_policy: fetch_mod.internal.ReferrerPolicy = .empty,
    /// "cspNavigationType": "form-submission" for a form's planned
    /// navigation, else "other" (CSP 4.2.4's type).
    csp_navigation_type: @import("csp").navigation_check.NavigationType = .other,
};

/// One navigation, from "navigate" step 19 until its document commits or it
/// is abandoned.
const Navigation = struct {
    id: u64,
    integration: *IFrameIntegration,
    allocator: std.mem.Allocator,
    url: []u8,
    srcdoc: ?[]u8 = null,
    history_handling: navigate_steps.HistoryHandling,
    initial_insertion: bool,
    traversal_entry: u64 = 0,
    traversal_from: u64 = 0,
    /// What the commit decides before the active document unloads, for the
    /// pageswap event and the new document's activation: the entry a push
    /// or replace will make, and the new document's origin (serialized,
    /// owned).
    prepared: ?html_core.navigation.joint_history.Prepared = null,
    target_origin: ?[]u8 = null,
    /// The request's referrer, resolved (Fetch "determine request's
    /// referrer" for the source document): its URL, or null for no
    /// referrer. Owned.
    referrer: ?[]u8 = null,
    /// The user navigated from the browser's UI (userInvolvement "browser
    /// UI"), which no self-referential URL bound applies to.
    browser_initiated: bool = false,
    /// A POST resource's request body and content-type, fetched with POST.
    /// Owned; the fetch borrows the body until it ends.
    post_body: ?[]u8 = null,
    post_content_type: ?[]u8 = null,
    /// A javascript: URL's String result and the URL its document takes,
    /// between evaluating it and committing it. Owned.
    javascript_result: ?[]u8 = null,
    javascript_url: ?[]u8 = null,
    /// "Evaluate a javascript: URL" step 12's policy container: the target
    /// navigable's active document's, cloned before that document unloads,
    /// for the String's document. Owned until the commit hands it over.
    javascript_policy_container: ?fetch_mod.internal.PolicyContainer = null,
    /// Navigate step 5's initiatorBaseURLSnapshot - the source document's
    /// document base URL - which an about:blank or about:srcdoc document the
    /// navigation makes takes as its about base URL. Owned.
    initiator_base_url: ?[]u8 = null,
    /// "Create navigation params by fetching" step 3's referrer policy: the
    /// navigation's referrerPolicy.
    referrer_policy: fetch_mod.internal.ReferrerPolicy = .empty,
    /// Navigate step 4's source snapshot params' source policy container: a
    /// clone of the source document's, taken as the navigation starts - the
    /// request's policy container, and the initiator's a local URL's
    /// document inherits. Owned; null with no source document.
    initiator_policy_container: ?fetch_mod.internal.PolicyContainer = null,
    /// A traversal's (or reload's) navigation with no source document: the
    /// navigable's active document's policy container, cloned as the
    /// traversal starts - "apply the history step" step 12.4: with no source
    /// snapshot params, the navigable "navigated itself". Only the new
    /// document's inheritance reads it (a local URL's, step 3 of
    /// "determining navigation params policy container"); the traversal's
    /// request keeps none. Owned.
    traversal_policy_container: ?fetch_mod.internal.PolicyContainer = null,
    /// What the commit puts in the document state's history policy container
    /// for a document whose URL requires storing it (about:, data:): a clone
    /// of the navigation params' policy container. Owned until recorded.
    history_policy_container: ?fetch_mod.internal.PolicyContainer = null,
    /// CSPEE §2.4: target snapshot's required CSP, owned before enqueue.
    required_csp: ?[]u8 = null,
    /// Mixed Content 4.3 for the source snapshot's fetch client. Captured
    /// by value; a later document must not change this navigation's policy.
    prohibits_mixed_security_contexts: bool = false,
    /// Where the navigation request's CSP violations go: the source
    /// document's global, the request's client's (CSP 2.4.2) - guarded, as
    /// the source document can go while the fetch is in flight. Null with
    /// no source document.
    csp_reporter: ?dom_module.csp_violations.GuardedReporter = null,
    /// "cspNavigationType", which "navigate to a javascript: URL" step 5 asks
    /// CSP 4.2.4 with.
    csp_navigation_type: @import("csp").navigation_check.NavigationType = .other,
    /// Where a container-initiated navigation's request reports its timing:
    /// the container document's global, which gets the frame's 'resource'
    /// entry (HTML "create navigation params by fetching" step 3) - guarded,
    /// as that document can go while the fetch is in flight.
    timing_reporter: ?dom_module.performance_timeline.GuardedTimingReporter = null,
    /// A javascript: URL navigation's initiatorOrigin (navigate step 4's
    /// initiator origin snapshot): the source document's origin record
    /// itself, one reference - "navigate to a javascript: URL" step 4
    /// compares it, as it is when the task runs, with the target's active
    /// document's, and step 8 makes it the String's document's origin. It
    /// outlives the source document. Null with no source document.
    initiator_origin: ?*OriginRecord = null,
    /// The fetch in flight, until it answers.
    fetch: ?*fetch_mod.algorithms.AsyncFetch = null,
    /// What the fetch answered, until the commit takes it.
    response: ?navigation_fetch.NavigationFetchResult = null,
    /// Navigate step 8's target snapshot params' sandboxing flags: "determine
    /// the creation sandboxing flags" for the navigable's active browsing
    /// context given its container, as the navigation starts - the iframe's
    /// sandbox attribute as it is then, united with its container document's
    /// active sandboxing flag set; a popup's popup sandboxing flag set.
    target_sandboxing_flags: SandboxingFlagSet = .empty,
    /// navigationParams's final sandboxing flag set, decided as the response
    /// commits: the target snapshot's flags united with the policy
    /// container's CSP-derived sandboxing flags. The new document's active
    /// sandboxing flag set, and with the sandboxed origin browsing context
    /// flag, its origin is a new opaque one.
    final_sandboxing_flags: SandboxingFlagSet = .empty,

    fn destroy(self: *Navigation) void {
        // Terminating a fetch runs neither `done` nor `gone`.
        if (self.fetch) |f| f.terminate();
        if (self.response) |*r| r.deinit();
        if (self.srcdoc) |s| self.allocator.free(s);
        if (self.javascript_result) |r| self.allocator.free(r);
        if (self.javascript_url) |u| self.allocator.free(u);
        if (self.initiator_base_url) |u| self.allocator.free(u);
        if (self.post_body) |b| self.allocator.free(b);
        if (self.post_content_type) |t| self.allocator.free(t);
        if (self.target_origin) |o| self.allocator.free(o);
        if (self.initiator_origin) |record| record.release();
        if (self.referrer) |r| self.allocator.free(r);
        if (self.initiator_policy_container) |*container| container.deinit();
        if (self.javascript_policy_container) |*container| container.deinit();
        if (self.traversal_policy_container) |*container| container.deinit();
        if (self.history_policy_container) |*container| container.deinit();
        if (self.required_csp) |required| self.allocator.free(required);
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }
};

/// Every navigable this engine made - iframes' and popups' - while it lives:
/// joined when its context is attached, left as its integration is deinited.
threadlocal var live_navigables: std.ArrayListUnmanaged(*IFrameIntegration) = .empty;

/// "Create and initialize a Document object": the about base URL
/// `document`'s navigable was given for it - an about:blank or about:srcdoc
/// document's - set before any of its script runs.
fn giveAboutBaseUrl(document: *runtime.Instance, browsing_context: *html_core.BrowsingContext) void {
    const integration = integrationOfBrowsingContext(browsing_context) orelse return;
    const url = integration.next_about_base_url orelse return;
    dom_module.document_lifecycle.setAboutBaseUrl(document, url);
}

/// "Create and initialize a Document object" step 9's active sandboxing
/// flag set: the one `browsing_context`'s navigable was given for the
/// document about to be made (IFrameIntegration.next_sandboxing_flags) - or
/// the empty set.
fn takeNextSandboxingFlags(browsing_context: *html_core.BrowsingContext) SandboxingFlagSet {
    const integration = integrationOfBrowsingContext(browsing_context) orelse return .empty;
    return integration.takeNextSandboxingFlags();
}

/// "Create and initialize a Document object": the origin record
/// `browsing_context`'s navigable was given for the document about to be
/// made (IFrameIntegration.next_origin), with its reference - or null, for
/// a document of its own origin.
fn takeNextOrigin(browsing_context: *html_core.BrowsingContext) ?*OriginRecord {
    const integration = integrationOfBrowsingContext(browsing_context) orelse return null;
    return integration.takeNextOrigin();
}

/// The live navigable whose browsing context is `browsing_context`.
fn integrationOfBrowsingContext(browsing_context: *html_core.BrowsingContext) ?*IFrameIntegration {
    for (live_navigables.items) |integration| {
        if (integration.browsing_context == browsing_context) return integration;
    }
    return null;
}

fn joinLiveNavigables(integration: *IFrameIntegration) void {
    for (live_navigables.items) |existing| {
        if (existing == integration) return;
    }
    live_navigables.append(std.heap.page_allocator, integration) catch {};
}

/// IFrameIntegration's `deinit_callback`.
fn leaveLiveNavigables(integration: *IFrameIntegration) void {
    for (live_navigables.items, 0..) |existing, i| {
        if (existing == integration) {
            _ = live_navigables.swapRemove(i);
            return;
        }
    }
}

/// The navigable whose active document is `document`, if this engine made
/// it: HTML "node navigable" of a document.
fn navigableOfDocument(document: *runtime.Instance) ?*IFrameIntegration {
    for (live_navigables.items) |integration| {
        if (activeDocumentOf(integration) == document) return integration;
    }
    return null;
}

/// Source of navigation IDs: never reused, never zero.
threadlocal var next_navigation_id: u64 = 1;

/// Every navigation in flight, by ID. A task holds only the ID, so a
/// navigation ended while its task waited is simply not found.
threadlocal var navigations: std.AutoHashMapUnmanaged(u64, *Navigation) = .empty;

fn navigationById(id: u64) ?*Navigation {
    return navigations.get(id);
}

/// End navigation `id`: aborted, superseded, or its navigable gone.
fn endNavigation(id: u64) void {
    const kv = navigations.fetchRemove(id) orelse return;
    kv.value.destroy();
}

/// HTML "set the ongoing navigation" (§7.4.2.5). The navigation it replaces
/// ends here - the spec lets it notice at its next step; ending it now also
/// cancels its fetch.
fn setOngoingNavigation(integration: *IFrameIntegration, value: navigate_steps.OngoingNavigation) void {
    // Step 1: "If navigable's ongoing navigation is equal to newValue, then return."
    if (integration.ongoing_navigation.eql(value)) return;
    // Step 2: "Inform the navigation API about aborting navigation given
    // navigable."
    if (integration.browsing_context) |bc| {
        if (bc.getActiveWindow()) |window| dom_module.navigation_api.informAboutAbortingNavigation(@ptrCast(@alignCast(window)));
    }
    switch (integration.ongoing_navigation) {
        .id => |old| endNavigation(old),
        else => {},
    }
    // Step 3.
    integration.ongoing_navigation = value;
}

/// IFrameIntegration's abandon hook: the navigable is going, and so is its
/// navigation in flight.
fn abandonNavigationsOf(integration: *IFrameIntegration) void {
    setOngoingNavigation(integration, .none);
}

/// The navigable's active document, as its browsing context records it -
/// not `window.document`, which is script's getter and refuses a
/// cross-origin reader.
fn activeDocumentOf(integration: *IFrameIntegration) ?*runtime.Instance {
    const browsing_context = integration.browsing_context orelse return null;
    const document = browsing_context.getActiveDocument() orelse return null;
    return @ptrCast(@alignCast(document));
}

/// `document`'s URL, serialized and owned by `allocator`; "about:blank"
/// when there is no document to ask.
fn documentUrlOf(document: ?*runtime.Instance, allocator: std.mem.Allocator) ![]u8 {
    const doc = document orelse return allocator.dupe(u8, "about:blank");
    const url = interfaces.Document.get_URL(doc) catch return allocator.dupe(u8, "about:blank");
    defer doc.ctx.allocator.free(url);
    if (url.len == 0) return allocator.dupe(u8, "about:blank");
    return allocator.dupe(u8, url);
}

/// The origin of a serialized http(s) URL - "scheme://host[:port]" - or null
/// for any other scheme, whose origin is opaque or inherited.
fn tupleOriginOf(url: []const u8) ?[]const u8 {
    const scheme = navigate_steps.schemeOf(url);
    if (!std.mem.eql(u8, scheme, "http") and !std.mem.eql(u8, scheme, "https")) return null;
    const after = scheme.len + 3; // "://"
    if (url.len < after) return null;
    const end = std.mem.indexOfAnyPos(u8, url, after, "/?#") orelse url.len;
    return url[0..end];
}

/// Whether `source` - navigate's initiator - is same origin with `active`,
/// for step 12.1. Deviation, stated: compared by URL, so a document whose
/// origin is inherited (about:blank, srcdoc) or changed by document.domain
/// counts as same origin.
fn initiatorSameOrigin(source: ?*runtime.Instance, active_url: []const u8, allocator: std.mem.Allocator) bool {
    const doc = source orelse return true;
    const source_url = documentUrlOf(doc, allocator) catch return true;
    defer allocator.free(source_url);
    const a = tupleOriginOf(source_url) orelse return true;
    const b = tupleOriginOf(active_url) orelse return true;
    return std.mem.eql(u8, a, b);
}

/// Navigate step 21's condition: whether `active`'s origin is "same
/// origin-domain" (HTML 7.1.1.2) with `source`'s - navigate's
/// sourceDocument's; true with no source (the user agent's own navigation).
///
/// "1. If A and B are the same opaque origin, then return true. 2. If A and
/// B are both tuple origins, then: 1. If A and B's schemes are identical,
/// and their domains are identical and non-null, then return true. 2.
/// Otherwise, if A and B are same origin and their domains are identical and
/// null, then return true. 3. Return false."
///
/// The documents' origin records decide identity - two documents sharing one
/// origin (an about:blank child and its creator, a sandboxed frame's
/// documents) are the same origin, opaque or not - and their domains.
fn initiatorSameOriginDomain(source: ?*runtime.Instance, active: *runtime.Instance, allocator: std.mem.Allocator) bool {
    const src = source orelse return true;
    const a = documentOriginOf(src, allocator) orelse return false;
    defer allocator.free(a);
    const b = documentOriginOf(active, allocator) orelse return false;
    defer allocator.free(b);
    return dom_module.origin_record.sameOriginDomain(
        .{ .serialized = a, .record = dom_module.document_origin.record(src) },
        .{ .serialized = b, .record = dom_module.document_origin.record(active) },
    );
}

/// `document`'s origin, serialized ("null" for an opaque one) and owned by
/// `allocator`, as its Window reports it - which an about:blank or srcdoc
/// document inherits; null when it has no Window to ask.
fn documentOriginOf(document: *runtime.Instance, allocator: std.mem.Allocator) ?[]u8 {
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return null;
    return originOfWindow(window, allocator) catch null;
}

/// HTML "navigate" `integration`'s navigable to `url` (serialized, absolute).
/// Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate
///
/// Steps not modelled, stated: source snapshot params and sandboxed
/// navigation (1-7), deferred fetch quota (22), WebDriver BiDi, and lazy
/// loading (11). Step 21's navigate event has no form data entry list.
pub fn navigate(integration: *IFrameIntegration, url: []const u8, options: NavigateOptions) void {
    // A navigable that is going, or never came: nothing to navigate.
    if (integration.state == .discarded) return;
    const browsing_context = integration.browsing_context orelse return;
    if (browsing_context.is_closed) return;
    const allocator = integration.allocator;
    const active = activeDocumentOf(integration);

    // Not a spec step: a cross-origin frame without user activation may not
    // navigate its top-level traversable away, as in Firefox and Safari
    // (html.user_activation.topNavigationBlocked states the deviation and
    // its exceptions). Only a navigation a document started: never a
    // traversal or reload, an element's own navigation of its frame, or the
    // browser's.
    if (options.traversal_entry == 0 and !options.initial_insertion and options.user_involvement != .browser_ui and
        html_module.user_activation.topNavigationBlocked(options.source_document, browsing_context, url)) return;

    // Step 6.2: "If sourceDocument's node navigable is not allowed by
    // sandboxing to navigate navigable given sourceSnapshotParams", return
    // (a SecurityError where exceptions are enabled: navigateFromLocation).
    // A traversal's navigation was checked by "apply the history step".
    if (options.traversal_entry == 0 and options.user_involvement != .browser_ui and
        html_module.user_activation.sandboxBlocksNavigation(options.source_document, browsing_context)) return;

    // Step 9: "If navigable's active document's unload counter is greater
    // than 0, then ... return."
    if (active) |doc| {
        if (document_lifecycle.isUnloading(doc)) return;
    }

    // Step 12: "If navigable's allowed to perform a navigation or history
    // update returns blocked, then ... return." Not for the navigations the
    // engine starts itself - an element's insertion, a traversal, the
    // browser's UI - which Blink's limiter does not count either.
    if (!options.initial_insertion and options.traversal_entry == 0 and options.user_involvement != .browser_ui) {
        if (!browsing_context.allowedToNavigateOrUpdateHistory()) return;
    }

    // The navigable's session history has its current entry before anything
    // changes ("initialize the navigable").
    _ = browsing_context.ensureHistoryEntries(&history_documents.infoOf) catch {};

    // Steps 12-13: history handling.
    const active_url = documentUrlOf(active, allocator) catch return;
    defer allocator.free(active_url);
    const history_handling = navigate_steps.resolveHistoryHandling(options.history_behavior, url, .{
        .url = active_url,
        .is_initial_about_blank = if (active) |doc| document_lifecycle.isInitialAboutBlank(doc) else false,
    }, initiatorSameOrigin(options.source_document, active_url, allocator));

    // Step 14: a fragment navigation commits now, in the same document. (A
    // traversal's navigation repopulates a document, and is never one.)
    if (options.traversal_entry == 0 and navigate_steps.isFragmentNavigation(url, active_url, options.srcdoc != null or options.post_resource != null)) {
        navigateToFragment(integration, url, active_url, history_handling, options);
        return;
    }

    // Step 15: "If navigable's parent is non-null, then set navigable's is
    // delaying load events to true." A popup has no parent.
    if (integration.iframe_element != null) integration.delaying_load = true;

    // Step 18: a navigable that is traversing ignores navigations. Nothing
    // traverses yet, so this never holds.
    if (integration.ongoing_navigation == .traversal) return;

    // Step 7's navigation ID, and step 19: set the ongoing navigation - which
    // ends any earlier one.
    const id = next_navigation_id;
    next_navigation_id += 1;
    if (options.traversal_entry != 0) {
        // A traversal's (or reload's) navigation: "apply the history step"
        // sets the navigable's ongoing navigation itself - not through "set
        // the ongoing navigation", so the navigation API is not informed
        // about aborting navigation. The traverse or reload navigate event
        // that led here, and its API method tracker, stay ongoing: a
        // cross-document traversal's promises never settle
        // (navigation-methods/return-value/reload.html, reload-no-args.html).
        switch (integration.ongoing_navigation) {
            .id => |old| endNavigation(old),
            else => {},
        }
        integration.ongoing_navigation = .{ .id = id };
    } else setOngoingNavigation(integration, .{ .id = id });

    const record = allocator.create(Navigation) catch return;
    record.* = .{
        .id = id,
        .integration = integration,
        .allocator = allocator,
        .url = allocator.dupe(u8, url) catch {
            allocator.destroy(record);
            return;
        },
        .history_handling = history_handling,
        .initial_insertion = options.initial_insertion,
        .traversal_entry = options.traversal_entry,
        .traversal_from = options.traversal_from,
        .browser_initiated = options.user_involvement == .browser_ui,
        .csp_navigation_type = options.csp_navigation_type,
        // Step 8: "Let targetSnapshotParams be the result of snapshotting
        // target snapshot params given navigable": its sandboxing flags.
        .target_sandboxing_flags = creationSandboxingFlagsOf(integration),
    };
    record.required_csp = determineRequiredCSP(integration, url) catch {
        record.destroy();
        return;
    };
    if (options.srcdoc) |html| {
        record.srcdoc = allocator.dupe(u8, html) catch {
            record.destroy();
            return;
        };
    }
    if (options.post_resource) |post| {
        record.post_body = allocator.dupe(u8, post.body) catch {
            record.destroy();
            return;
        };
        record.post_content_type = allocator.dupe(u8, post.content_type) catch {
            record.destroy();
            return;
        };
    }
    // "Create navigation params by fetching" step 3's request: its referrer
    // is the document state's request referrer, "client" - the source
    // document, as Fetch resolves it.
    if (options.source_document) |source| record.referrer = requestReferrerOf(source, allocator);
    record.referrer_policy = options.referrer_policy;
    // Step 4: "Let sourceSnapshotParams be the result of snapshotting source
    // snapshot params given sourceDocument" - its source policy container a
    // clone of sourceDocument's policy container.
    if (options.source_document) |source| {
        if (dom_module.policy_containers.of(source)) |container| {
            record.initiator_policy_container = container.clone(allocator) catch null;
        }
        // The source snapshot params' fetch client is sourceDocument's
        // relevant settings object: the request's client, whose global a
        // violation of the request is (CSP 2.4.2).
        record.csp_reporter = dom_module.csp_violations.GuardedReporter.forRealm(source.ctx);
        // Step 4's fetch client: snapshot Mixed Content 4.3 while the
        // source document's settings still describe this navigation.
        if (windowOfRealm(source.ctx)) |global| {
            if (dom_module.global_settings.of(global)) |settings| {
                if (settings.prohibits_mixed_security_contexts) |prohibits| {
                    record.prohibits_mixed_security_contexts = prohibits(global) catch {
                        record.destroy();
                        return;
                    };
                }
            }
        }
    }
    // "Apply the history step" step 12.4 for a traversal or reload no
    // document started: "set it to the result of snapshotting source
    // snapshot params given navigable's active document".
    if (options.traversal_entry != 0 and options.source_document == null) {
        if (active) |doc| {
            if (dom_module.policy_containers.of(doc)) |container| {
                record.traversal_policy_container = container.clone(allocator) catch null;
            }
        }
    }
    // Step 5: "Let initiatorBaseURLSnapshot be sourceDocument's document base
    // URL" - kept only where it can be used, for a document at about:blank
    // or about:srcdoc (navigate step 22.3's document state).
    if (options.srcdoc != null or navigate_steps.matchesAboutBlank(url) or navigate_steps.matchesAboutSrcdoc(url)) {
        if (options.source_document) |source| record.initiator_base_url = documentBaseUrl(source, allocator);
    }
    // Step 4's initiatorOriginSnapshot, for a javascript: URL, whose
    // navigation compares it (step 4 of "navigate to a javascript: URL") and
    // gives it to its document (step 8), and for about:blank, whose document
    // takes it ("determining the origin" step 2): the source document's
    // origin, held.
    if (navigate_steps.isJavascript(url) or (options.srcdoc == null and navigate_steps.matchesAboutBlank(url))) {
        if (options.source_document) |source| {
            if (dom_module.document_origin.shareable(source) catch null) |origin| record.initiator_origin = origin.retain();
        }
    }
    navigations.put(std.heap.page_allocator, id, record) catch {
        record.destroy();
        return;
    };

    // Step 20: a javascript: URL runs in a task, not the caller.
    if (navigate_steps.isJavascript(url)) {
        queueNavigationTask(integration, id, &runJavascriptNavigation);
        return;
    }
    // Step 21: the navigate event - for a navigation from a document same
    // origin(-domain) with the active one, to a fetch scheme, when the
    // active document is not the initial about:blank. (A traversal's
    // navigation fired its event in the traversal.) Canceled, or
    // intercepted - which made it same-document - and it ends here.
    // A srcdoc navigation is one too: its URL is about:srcdoc, and "about"
    // is a fetch scheme (navigate-event/navigate-to-srcdoc).
    if (options.traversal_entry == 0 and active != null and
        options.user_involvement != .browser_ui and
        initiatorSameOriginDomain(options.source_document, active.?, allocator) and
        !document_lifecycle.isInitialAboutBlank(active.?) and
        navigate_steps.isFetchScheme(url))
    {
        if (integration.browsing_context.?.getActiveWindow()) |window| {
            const continue_navigation = dom_module.navigation_api.firePushReplaceReload(@ptrCast(@alignCast(window)), .{
                .navigation_type = if (history_handling == .push) .push else .replace,
                .destination_url = url,
                .is_same_document = false,
                .user_involvement = options.user_involvement,
                .source_element = options.source_element,
                .navigation_api_state = options.navigation_api_state orelse .undefined,
                // Step 20: "Let entryListForFiring be formDataEntryList if
                // documentResource is a POST resource; otherwise, null."
                .form_data = if (options.post_resource != null) options.form_data else null,
            });
            if (!continue_navigation) {
                // "If continue is false, then return." The navigation ends
                // here without informing the navigation API again: its
                // navigate event was canceled, or intercepted - and an
                // intercepted one is still settling, which informing about
                // aborting navigation would abort.
                if (isOngoing(integration, id)) integration.ongoing_navigation = .none;
                endNavigation(id);
                endLoadDelay(integration);
                return;
            }
            // The event's handlers ran script: a later navigation replaces
            // this one, and a navigable taken away ends it.
            if (navigationById(id) == null or !isOngoing(integration, id)) return;
        }
    }
    // Step 24: "In parallel": beforeunload, then the fetch. Deviation,
    // stated: "checking if unloading is canceled" runs now, inside the call
    // that navigates, not from a task - as Blink (FrameLoader::StartNavigation
    // asks the frame's ShouldClose) and Gecko (nsDocShell::InternalLoad's
    // PermitUnload) do, and as WPT expects of a same-agent navigation
    // (unloading-documents/beforeunload-synchronous.html, prompt/001.html,
    // navigation-api/navigation-methods/return-value/*-beforeunload.html:
    // the beforeunload handler has run when location.href= or navigate()
    // returns). A traversal's navigation (and a reload's) has had its
    // beforeunload already: "apply the history step" checks it for every
    // navigable the traversal takes to another document, before their
    // navigate events (History's runTraversal and reload).
    if (options.traversal_entry != 0) return startFetch(navigationById(id) orelse return);
    runBeforeUnload(@ptrFromInt(id));
}

/// Fetch "determine request's referrer" step 2 for a request whose
/// referrer is "client" and whose client is `source`'s: "If document's
/// origin is opaque, return no referrer. While document is an iframe srcdoc
/// document, let document be document's browsing context's container
/// document. Let referrerSource be document's URL." Owned by `allocator`;
/// null for no referrer (main fetch strips and applies the policy).
fn requestReferrerOf(source: *runtime.Instance, allocator: std.mem.Allocator) ?[]u8 {
    const window = (interfaces.Document.get_defaultView(source) catch null) orelse return null;
    const origin = originOfWindow(window, allocator) catch return null;
    defer allocator.free(origin);
    if (std.mem.eql(u8, origin, "null")) return null;
    var document = source;
    var depth: usize = 0;
    while (depth < 64) : (depth += 1) {
        const url = documentUrlOf(document, allocator) catch return null;
        if (!navigate_steps.matchesAboutSrcdoc(url)) return url;
        allocator.free(url);
        const view = (interfaces.Document.get_defaultView(document) catch null) orelse return null;
        const container = dom_module.navigable_container.of(view) orelse return null;
        document = (interfaces.Node.get_ownerDocument(container) catch null) orelse return null;
    }
    return null;
}

/// Queue `callback` for navigation `id` on the navigable's event loop - a
/// global task on the navigation and traversal task source. With no loop (a
/// context built for tests) it runs now.
fn queueNavigationTask(integration: *IFrameIntegration, id: u64, callback: *const fn (?*anyopaque) void) void {
    const context: ?*anyopaque = @ptrFromInt(id);
    const runtime_ctx: runtime.Context = @ptrCast(@alignCast(integration.runtime_context orelse return callback(context)));
    const loop = runtime_ctx.getOptionalEventLoop() orelse return callback(context);
    loop.queueTask(.{ .callback = callback, .context = context });
}

fn idOf(context: ?*anyopaque) u64 {
    return @intFromPtr(context);
}

/// Whether navigation `id` is still `integration`'s ongoing navigation.
fn isOngoing(integration: *IFrameIntegration, id: u64) bool {
    return integration.ongoing_navigation.eql(.{ .id = id });
}

/// The runtime context of `integration`'s content navigable, if it has one.
fn navigableContext(integration: *IFrameIntegration) ?runtime.Context {
    return @ptrCast(@alignCast(integration.runtime_context orelse return null));
}

/// The realm whose agent and Browser a navigation of `integration`'s
/// navigable belongs to: its container's (a frame's realm shares its
/// parent's Browser scope and agent), or the navigable's own.
fn navigationRealmOf(integration: *IFrameIntegration) ?runtime.Context {
    if (integration.parent_realm) |parent| return @ptrCast(@alignCast(parent));
    return navigableContext(integration);
}

/// The fetches a navigation of `integration`'s navigable runs on: its
/// container's realm's agent's - the window agent, whose loop pumps them.
fn agentFetchesOf(integration: *IFrameIntegration) ?*dom_module.agent_fetches.AgentFetches {
    return dom_module.agent_fetches.of(navigationRealmOf(integration) orelse return null);
}

/// The network context a navigation of `integration`'s navigable goes out
/// on: its Browser's.
fn networkOf(integration: *IFrameIntegration) ?*fetch_mod.network.NetworkContext {
    return dom_module.browser_state.networkOf(navigationRealmOf(integration) orelse return null);
}

/// The user agent's blob URL store a navigation of `integration`'s navigable
/// obtains a blob: URL's blob from: its Browser's - the container's realm's
/// (a frame's realm shares its parent's Browser scope).
fn blobURLStoreOf(integration: *IFrameIntegration) ?*anyopaque {
    const realm: runtime.Context = if (integration.parent_realm) |parent|
        @ptrCast(@alignCast(parent))
    else
        navigableContext(integration) orelse return null;
    return @ptrCast(dom_module.browser_state.blobURLStoreOf(realm) orelse return null);
}

/// Step 24.1: "checking if unloading is canceled" for the active document's
/// inclusive descendant navigables - beforeunload at each, parents first.
/// Step 24.2: canceled, or navigated again meanwhile, and this navigation
/// ends. Step 24.3 aborts the active document before the replacement fetch.
fn runBeforeUnload(context: ?*anyopaque) void {
    const id = idOf(context);
    const record = navigationById(id) orelse return;
    const integration = record.integration;
    if (!isOngoing(integration, id)) return endNavigation(id);

    if (activeDocumentOf(integration)) |document| {
        var canceled = false;
        var documents = dom_module.navigables.inclusiveDescendantDocuments(document, integration.allocator);
        defer documents.deinit(integration.allocator);
        for (documents.items) |entry| {
            if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
            if (document_lifecycle.fireBeforeUnload(entry.document).canceled) canceled = true;
        }
        // The handlers ran script: a later navigation replaces this one -
        // and ends its record - and a navigable taken away ends it too.
        const again = navigationById(id) orelse return;
        if (canceled) {
            setOngoingNavigation(again.integration, .none);
            endLoadDelay(again.integration);
            return;
        }
        // Step 24.3: "Queue a global task ... to abort a document and its
        // descendants given navigable's active document." Deviation, stated:
        // done now, not from a task - Crane parses a document in one run, so a
        // task would always find its parser finished; done now, it stops the
        // load of a document whose own script started this navigation while
        // it was being parsed, as browsers do (replace-before-load/*).
        for (documents.items) |entry| {
            if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
            // The explicit provisional path preserves live XHR loaders;
            // a stop/open called by an owner callback remains observable.
            document_lifecycle.abortForNavigation(entry.document);
        }
    }
    startFetch(navigationById(id) orelse return);
}

/// Step 23.9: "attempt to populate the history entry's document" - its fetch.
/// about:blank, srcdoc, data: and file: are answered without the network and
/// committed by a task; http(s) goes to the network through the event loop.
fn startFetch(record: *Navigation) void {
    const allocator = record.allocator;
    const url = record.url;

    if (record.srcdoc) |html| {
        // At about:srcdoc - or, for a traversal to a fragment entry of one,
        // at that entry's URL (about:srcdoc#yo).
        record.response = htmlResponse(allocator, url, html) catch navigation_fetch.networkErrorResult(allocator, url) catch return endNavigation(record.id);
        return queueNavigationTask(record.integration, record.id, &runCommit);
    }
    if (navigate_steps.matchesAboutBlank(url)) {
        record.response = htmlResponse(allocator, url, "") catch navigation_fetch.networkErrorResult(allocator, url) catch return endNavigation(record.id);
        return queueNavigationTask(record.integration, record.id, &runCommit);
    }

    // Deviation, stated: a frame's navigation to a URL that two of its
    // ancestors already show, fragments excluded, is canceled here, as the
    // request would start - the frame keeps the document it has. HTML bounds
    // nesting only for an iframe's src attribute ("shared attribute
    // processing steps" step 3); a navigation script starts in a frame to its
    // own page's URL nests without end in the spec, and no load event above
    // it ever fires. This is Chromium's bound
    // (NavigationRequest::IsSelfReferentialURL, checked in WillStartRequest):
    // one level of self-reference is allowed, about: URLs and navigations
    // from the browser's UI are exempt. Gecko bounds the same pages by frame
    // depth instead (nsFrameLoader::CheckForRecursiveLoad, 10).
    // Chromium also exempts POST, which frame navigations here never are,
    // and checks each redirect's target too (WillRedirectRequest); the fetch
    // here follows redirects itself, so only the URL navigated to is checked.
    if (!record.browser_initiated and isSelfReferential(record.integration, url)) {
        return cancelSelfReferential(record);
    }

    const scheme = navigate_steps.schemeOf(url);
    if (std.mem.eql(u8, scheme, "http") or std.mem.eql(u8, scheme, "https")) {
        // "Create navigation params by fetching" step 10.2: the request's
        // destination is the navigable's container's local name.
        const container_kind: ?dom_module.navigables.ContainerKind = if (record.integration.iframe_element) |element_ptr|
            dom_module.navigables.containerKind(@ptrCast(@alignCast(element_ptr))) orelse .iframe
        else
            null;
        const request = navigation_fetch.navigationRequest(allocator, url, .{
            .destination = if (container_kind) |kind| switch (kind) {
                .iframe => .iframe,
                .frame => .frame,
                .object => .object,
                .embed => .embed,
            } else .document,
            .mode = .navigate,
            .redirect = .follow,
            // "Create navigation params by fetching" step 3: a POST
            // resource's request is a POST.
            .method = if (record.post_body != null) "POST" else "GET",
            // The navigable's cookie jar: a frame's top's, a popup's own
            // (its opener's).
            .cookie_jar = if (record.integration.browsing_context) |bc| bc.cookieJar() else null,
            // The Browser's network: its connections and TLS options.
            .network = networkOf(record.integration),
            // The request's referrer, referrer policy and policy container
            // (the source snapshot params'): main fetch step 8 gives a
            // request whose own policy is empty its container's.
            .referrer = record.referrer,
            .referrer_policy = record.referrer_policy,
            .policy_container = if (record.initiator_policy_container) |*container| container else null,
        }) catch {
            record.response = navigation_fetch.networkErrorResult(allocator, url) catch return endNavigation(record.id);
            return queueNavigationTask(record.integration, record.id, &runCommit);
        };
        // CSPEE §2.4 item 7: set the request header from the target snapshot.
        if (record.required_csp) |required| request.header_list.set("Sec-Required-CSP", required) catch {
            request.deinit();
            record.response = navigation_fetch.networkErrorResult(allocator, url) catch return endNavigation(record.id);
            return queueNavigationTask(record.integration, record.id, &runCommit);
        };
        // Main fetch steps 4 and 7 report the request's CSP violations to its
        // client's global (CSP 2.4.2). The record outlives the fetch: its
        // destroy terminates it.
        if (record.csp_reporter) |*reporter| request.csp_violation_reporter = reporter.reporter();
        request.prohibits_mixed_security_contexts = record.prohibits_mixed_security_contexts;
        // "Create navigation params by fetching" step 3: "If
        // sourceSnapshotParams's fetch client is navigable's container
        // document's relevant settings object, then set request's initiator
        // type to navigable's container's local name" - only a navigation
        // the container started is reported to resource timing, to the
        // container document's global (its fetch client's).
        if (record.csp_reporter) |source| {
            if (record.integration.iframe_element) |element_ptr| {
                const container: *runtime.Instance = @ptrCast(@alignCast(element_ptr));
                if (container.ctx == source.global.ctx) {
                    record.timing_reporter = dom_module.performance_timeline.GuardedTimingReporter.forGlobal(source.global);
                    // Step 10.3: "set request's initiator type to navigable's
                    // container's local name".
                    request.initiator_type = switch (container_kind orelse .iframe) {
                        .iframe => .iframe,
                        .frame => .frame,
                        .object => .object,
                        .embed => .embed,
                    };
                    // The record's own reporter, at its fixed address.
                    if (record.timing_reporter) |*reporter| request.timing_reporter = reporter.reporter();
                }
            }
        }
        // Step 3's POST resource: "set request's body to documentResource's
        // request body" and "Content-Type" to its request content-type. The
        // body is the record's, borrowed for as long as the fetch runs.
        if (record.post_body) |body| {
            request.body = .{ .bytes = body };
            if (record.post_content_type) |content_type| {
                request.header_list.set("Content-Type", content_type) catch {
                    request.deinit();
                    record.response = navigation_fetch.networkErrorResult(allocator, url) catch return endNavigation(record.id);
                    return queueNavigationTask(record.integration, record.id, &runCommit);
                };
            }
        }
        const client: fetch_mod.algorithms.AsyncFetch.Client = .{
            .context = @ptrFromInt(record.id),
            .done = &fetchDone,
            .alive = &fetchAlive,
            .gone = &fetchGone,
        };
        // The request's final referrer comes back with the result, for the
        // new document's referrer (fetchDone frees it with the result).
        record.fetch = fetch_mod.algorithms.AsyncFetch.start(allocator, request, .{ .report_referrer = true }, agentFetchesOf(record.integration), client) catch {
            // The fetch owned the request, and freed it.
            record.response = navigation_fetch.networkErrorResult(allocator, url) catch return endNavigation(record.id);
            return queueNavigationTask(record.integration, record.id, &runCommit);
        };
        return;
    }

    // Everything else this engine can load without the network. Its request's
    // destination is the container's local name, or "document" for a
    // top-level traversable (a popup) - which scheme fetch "blob" reads: a
    // top-level navigation obtains its blob with no partition check.
    const destination: navigation_fetch.NavigationFetchOptions.Destination = if (record.integration.iframe_element) |element_ptr|
        switch (dom_module.navigables.containerKind(@ptrCast(@alignCast(element_ptr))) orelse .iframe) {
            .iframe => .iframe,
            .frame => .frame,
            .object => .object,
            .embed => .embed,
        }
    else
        .document;
    if (std.mem.eql(u8, scheme, "blob")) {
        // A blob: URL is fetched by Fetch (scheme fetch "blob") with the
        // request "create navigation params by fetching" step 3 makes: its
        // policy container the source snapshot params' - main fetch step 7
        // checks it (frame-src: 'self' does not match blob:) - and its
        // violations reported to the source document's global. Fetched now,
        // while the blob URL's entry is the one the navigation was given.
        const request = navigation_fetch.navigationRequest(allocator, url, .{
            .destination = destination,
            .mode = .navigate,
            .redirect = .follow,
            // The blob URL store the entry is in: the Browser's.
            .blob_url_store = blobURLStoreOf(record.integration),
            .referrer = record.referrer,
            .referrer_policy = record.referrer_policy,
            .policy_container = if (record.initiator_policy_container) |*container| container else null,
        }) catch {
            record.response = navigation_fetch.networkErrorResult(allocator, url) catch return endNavigation(record.id);
            return queueNavigationTask(record.integration, record.id, &runCommit);
        };
        if (record.csp_reporter) |*reporter| request.csp_violation_reporter = reporter.reporter();
        record.response = navigation_fetch.fetchRequestNow(allocator, url, request, .{}) catch navigation_fetch.networkErrorResult(allocator, url) catch return endNavigation(record.id);
        return queueNavigationTask(record.integration, record.id, &runCommit);
    }
    record.response = navigation_fetch.fetchNavigationResource(allocator, url, .{
        .destination = destination,
        .mode = .navigate,
        .redirect = .follow,
    }) catch navigation_fetch.networkErrorResult(allocator, url) catch return endNavigation(record.id);
    queueNavigationTask(record.integration, record.id, &runCommit);
}

/// Whether two or more of `integration`'s ancestor navigables show a
/// document whose URL equals `url` with fragments excluded. about: URLs
/// never do. A popup has no ancestors.
fn isSelfReferential(integration: *IFrameIntegration, url: []const u8) bool {
    if (std.mem.eql(u8, navigate_steps.schemeOf(url), "about")) return false;
    const container: *runtime.Instance = @ptrCast(@alignCast(integration.iframe_element orelse return false));
    const NodeImpl = @import("Node.zig");
    const allocator = integration.allocator;
    var document = NodeImpl.getOwnerDocument(container);
    var found = false;
    var depth: usize = 0;
    while (document) |doc| : (depth += 1) {
        if (depth > 64) return false;
        const doc_url = documentUrlOf(doc, allocator) catch return false;
        defer allocator.free(doc_url);
        if (navigate_steps.equalsExcludingFragments(doc_url, url)) {
            if (found) return true;
            found = true;
        }
        const window = (interfaces.Document.get_defaultView(doc) catch null) orelse return false;
        const parent_container = dom_module.navigable_container.of(window) orelse return false;
        document = NodeImpl.getOwnerDocument(parent_container);
    }
    return false;
}

/// A self-referential navigation canceled before its request: no document,
/// as for a 204 - the navigation ends, and with it the delay it put on the
/// container document's load event.
fn cancelSelfReferential(record: *Navigation) void {
    const integration = record.integration;
    log.debug("[navigation] canceled a self-referential frame navigation to {s}", .{record.url});
    if (isOngoing(integration, record.id)) integration.ongoing_navigation = .none;
    endNavigation(record.id);
    endLoadDelay(integration);
}

/// A response made of `html`, as a fetch would have answered it.
fn htmlResponse(allocator: std.mem.Allocator, url: []const u8, html: []const u8) !navigation_fetch.NavigationFetchResult {
    var result = navigation_fetch.NavigationFetchResult.init(allocator);
    errdefer result.deinit();
    result.final_url = try allocator.dupe(u8, url);
    result.content_type = try allocator.dupe(u8, "text/html;charset=utf-8");
    result.body = try allocator.dupe(u8, html);
    result.status = 200;
    result.ok = true;
    result.is_network_error = false;
    return result;
}

/// Whether the navigation that started a fetch is still there to hear it:
/// its record, and the realm of its navigable. A page torn down with the
/// fetch in flight retires its contexts, and Fetch's "terminate a fetch
/// group" ends the fetch at the next sweep.
fn fetchAlive(context: *anyopaque) bool {
    const record = navigationById(@intFromPtr(context)) orelse return false;
    const ctx = navigableContext(record.integration) orelse return false;
    return ctx.engine_ctx != null;
}

/// The fetch was terminated because its navigation's realm went: the
/// navigation ends with it.
fn fetchGone(context: *anyopaque) void {
    const id = @intFromPtr(context);
    const record = navigationById(id) orelse return;
    record.fetch = null;
    endNavigation(id);
}

/// The navigation fetch answered (from the event loop's network step):
/// keep the response and queue the task that commits it.
fn fetchDone(context: *anyopaque, outcome: fetch_mod.algorithms.FetchError!fetch_mod.algorithms.FetchResult) void {
    const id = @intFromPtr(context);
    var result = outcome catch null;
    defer if (result) |*r| r.deinit();
    const record = navigationById(id) orelse return;
    record.fetch = null;
    record.response = if (result) |r|
        navigation_fetch.resultFromResponse(record.allocator, record.url, r.response, .{}) catch null
    else
        null;
    // The request's referrer as main fetch left it, for the new document.
    if (record.response) |*response| {
        if (result) |r| {
            if (r.referrer) |referrer| response.referrer = record.allocator.dupe(u8, referrer) catch null;
        }
    }
    // The fetch's timing info goes with the response, for the new document's
    // navigation timing entry (its redirect count: the URLs past the first).
    if (record.response) |*response| {
        if (result) |*r| {
            response.timing = .{
                .timing_info = r.timing_info,
                // A cross-origin redirect makes the count 0 (HTML "create
                // navigation params by fetching").
                .redirect_count = if (response.has_cross_origin_redirects) 0 else @intCast(@min(r.response.url_list.items.len -| 1, std.math.maxInt(u16))),
                .response_status = r.response.status,
                .content_encoding = r.response.body_info.content_encoding,
            };
            r.timing_info = fetch_mod.internal.FetchTimingInfo.init(r.timing_info.allocator);
        }
    }
    if (record.response == null) {
        record.response = navigation_fetch.networkErrorResult(record.allocator, record.url) catch return endNavigation(id);
    }
    queueNavigationTask(record.integration, id, &runCommit);
}

/// The task that ends a navigation with a response: HTML "finalize a
/// cross-document navigation" and the history step it applies. Unload the
/// active document and its descendants, then create the new document, make
/// it active, and load it.
fn runCommit(context: ?*anyopaque) void {
    const id = idOf(context);
    const kv = navigations.fetchRemove(id) orelse return;
    const record = kv.value;
    defer record.destroy();
    const integration = record.integration;
    if (!isOngoing(integration, id)) return;
    const response = if (record.response) |*r| r else return;

    // HTML "navigate" step 23's process the navigation response: "if should
    // navigation response to navigation request of type in target be blocked
    // by Content Security Policy? returns "Blocked"", the response is a
    // network error - the frame shows an error document, of an opaque
    // origin, and its load event still fires.
    if (frameAncestorsBlock(integration, record, response) or requiredCSPBlocks(integration, record, response)) {
        response.deinit();
        record.response = navigation_fetch.networkErrorResult(integration.allocator, record.url) catch null;
        if (record.response == null) {
            integration.ongoing_navigation = .none;
            return endLoadDelay(integration);
        }
    }

    // A 204, a 205 or a download commits no document: the navigable keeps
    // the one it has, and no load event is owed. Decided before anything is
    // unloaded.
    if (!integration.responseMakesDocument(response)) {
        integration.ongoing_navigation = .none;
        endLoadDelay(integration);
        return;
    }

    // "Create navigation params by fetching" steps 21.9-21.11 (and "create
    // navigation params from a srcdoc resource" steps 4-6): navigationParams's
    // policy container, and its final sandboxing flag set - "the union of
    // targetSnapshotParams's sandboxing flags and policyContainer's CSP
    // list's CSP-derived sandboxing flags". Decided before anything unloads:
    // with the sandboxed origin browsing context flag the new document's
    // origin is a new opaque one ("determining the origin" step 1), which
    // the pageswap event names and the new document's Window is chosen by.
    // A network error's document is "inline content that doesn't have a
    // DOM", whose final sandboxing flag set is empty.
    var params_container = navigationParamsPolicyContainer(integration, record, response);
    var params_container_taken = false;
    defer if (!params_container_taken) {
        if (params_container) |*container| container.deinit();
    };
    record.final_sandboxing_flags = if (response.is_network_error) .empty else record.target_sandboxing_flags.unionWith(
        if (params_container) |*container| sandboxing.cspDerivedSandboxingFlags(&container.csp_list) else .empty,
    );

    // Script runs below and may take the iframe away; the integration stays
    // until this is done with it - and is freed, if it has to be, only after
    // the realm scopes below have been left.
    integration.busy += 1;
    defer finishBusy(integration);

    // "Deactivate a document for a cross-document navigation" step 5.2: the
    // ongoing navigation is null - new navigations may start.
    integration.ongoing_navigation = .none;

    // Step 5.1: the pageswap event the unload fires at the displayed
    // document, naming targetEntry - which "finalize a cross-document
    // navigation" has put in the session history by now, and Crane commits
    // once the document is made: its id and keys are reserved here.
    var swap = pageSwapOf(integration, record, response);
    defer if (swap) |*step| step.deinit();

    // Step 5.3: "Unload a document and its descendants", in its realm. HTML
    // "unload a document" steps 11 and 13 time its unload event for the new
    // document (the unload timing info): the unsafe shared current time
    // around it, made relative to the new document's time origin when its
    // navigation timing entry is created.
    const unload_start = fetch_mod.algorithms.http_fetch.getCurrentTimeMs();
    if (!unloadActiveDocument(integration, if (swap) |*step| step else null)) return endLoadDelay(integration);
    const unload_end = fetch_mod.algorithms.http_fetch.getCurrentTimeMs();
    if (integration.state == .discarded or integration.browsing_context == null) return;

    // "Create and initialize a Document object" steps 5-7: the realm the new
    // document goes in - the active one, or a new Window's around the same
    // WindowProxy - decided with no realm entered.
    const new_origin = if (record.final_sandboxing_flags.origin) Origin.createOpaque() else integration.responseOrigin(record.url, response);
    const old_origin: ?Origin = if (integration.window_proxy) |proxy| proxy.document_origin else null;
    // Navigation Timing: the unload times are the new document's only when
    // the previous document was same origin with it.
    if (response.timing) |*timing| {
        if (old_origin) |old| {
            if (new_origin.isSameOrigin(old)) {
                timing.unload_event_start = unload_start;
                timing.unload_event_end = unload_end;
            }
        }
    }
    // "Create and initialize a Document object" step 7: the keying of the
    // new document's agent cluster, decided before its realm is chosen and
    // any of its script runs.
    obtainAgentCluster(integration, record, response, new_origin);
    integration.realmForDocument(new_origin) catch |err| {
        log.warn("[navigation] no realm for {s}: {s}", .{ record.url, @errorName(err) });
        return endLoadDelay(integration);
    };
    // "Finalize a cross-document navigation" step 4: a top-level
    // traversable - not an auxiliary browsing context whose opener browsing
    // context is non-null - navigated to a document of another origin loses
    // its target name (window.name).
    if (integration.iframe_element == null) {
        if (integration.browsing_context) |bc| {
            const has_opener = bc.opener != null and !bc.disowned;
            const same_origin = if (old_origin) |old| new_origin.isSameOrigin(old) else false;
            if (bc.parent == null and !has_opener and !same_origin) bc.setTargetName("") catch {};
        }
    }
    // The document state's about base URL, for an about:blank or
    // about:srcdoc document: the initiator's base URL snapshot.
    integration.setNextAboutBaseUrl(record.initiator_base_url);
    defer integration.setNextAboutBaseUrl(null);
    // "Create and initialize a Document object" step 9: the document's policy
    // container, waiting for whatever makes the document (decided above).
    // "Populate a session history entry" step 7.2.3: a document whose URL
    // requires storing the policy container in history has its document
    // state keep it (commitInRealm records it).
    if (params_container) |*container| {
        const response_url = if (response.final_url.len > 0) response.final_url else record.url;
        if (navigate_steps.requiresStoringPolicyContainerInHistory(response_url)) {
            record.history_policy_container = container.clone(integration.allocator) catch null;
        }
    }
    integration.setNextPolicyContainer(params_container);
    params_container_taken = true;
    defer integration.setNextPolicyContainer(null);
    // Step 9's active sandboxing flag set, for whatever makes the document.
    integration.setNextSandboxingFlags(record.final_sandboxing_flags);
    defer integration.setNextSandboxingFlags(.empty);
    // Step 14: its referrer, the request's as main fetch left it.
    integration.setNextReferrer(response.referrer);
    defer integration.setNextReferrer(null);
    // Step 17: the response's Refresh header.
    integration.setNextRefresh(if (response.headers) |h| h.get("refresh") else null);
    defer integration.setNextRefresh(null);
    commitNavigation(integration, record, response);
}

/// HTML "create and initialize a Document object" step 7 for the document
/// `record`'s navigation makes from `response`, of origin `new_origin`, in a
/// frame's or a popup's navigable:
///
/// "1. Let oacHeader be the result of getting a structured field value given
/// `Origin-Agent-Cluster` and "item" from navigationParams's response's
/// header list. 2. Let requestsOAC be true if oacHeader is not null and
/// oacHeader[0] is the boolean true; otherwise false. 3. If
/// navigationParams's reserved environment is a non-secure context, then set
/// requestsOAC to false. 4. Let agent be the result of obtaining a
/// similar-origin window agent given navigationParams's origin,
/// browsingContext's group, and requestsOAC."
///
/// What is recorded is the keying of the document's origin in the group's
/// historical agent cluster key map (dom.agent_cluster_keys), which the new
/// window's originAgentCluster and its agent cluster read back. Step 6's
/// document, which keeps the initial about:blank document's Window (the same
/// condition realmForNewDocument decides by), gets the agent that Window was
/// made with: "create a new browsing context and document" step 9 obtained it
/// for the same origin with requestsOAC false.
///
/// An opaque origin is always origin-keyed and recorded nowhere: a network
/// error's document, a data: document, and a navigable sandboxed into an
/// opaque origin ("determining the origin" step 1). An about: document's or
/// a javascript: URL's result's origin is its creator's, decided when that
/// was made.
fn obtainAgentCluster(integration: *IFrameIntegration, record: *Navigation, response: *const navigation_fetch.NavigationFetchResult, new_origin: Origin) void {
    if (new_origin.is_opaque or response.is_network_error) return;
    const browsing_context = integration.browsing_context orelse return;
    if (record.final_sandboxing_flags.origin) return;
    const allocator = integration.allocator;
    const response_url = if (response.final_url.len > 0) response.final_url else record.url;
    const keys = dom_module.agent_cluster_keys;
    const origin = fetch_mod.internal.origins.serializedOriginOf(allocator, response_url) catch return;
    defer allocator.free(origin);
    const reuses_window = blk: {
        // A popup opened with noopener was "created given null" opener: its
        // initial about:blank document's origin was a new opaque one
        // ("create a new browsing context and document" step 7), same origin
        // with no document - not the opener's, which Crane gives it.
        if (browsing_context.parent == null and browsing_context.disowned) break :blk false;
        const old_document = activeDocumentOf(integration) orelse break :blk false;
        const old_origin = if (integration.window_proxy) |proxy| proxy.document_origin else Origin.createOpaque();
        break :blk document_lifecycle.isInitialAboutBlank(old_document) and old_origin.isSameOrigin(new_origin);
    };
    const requests_oac = !reuses_window and keys.requestsOAC(
        allocator,
        if (response.headers) |headers| headers.get("origin-agent-cluster") else null,
        reservedEnvironmentIsSecure(browsing_context, response_url, allocator),
    );
    // The Browser the navigable's documents belong to: its active document's
    // (the initial about:blank one at least), else its container document's.
    const scope: ?*runtime.BrowserScope = if (activeDocumentOf(integration) orelse containerDocumentOf(integration)) |document|
        runtime.BrowserScope.ofInstance(document)
    else
        null;
    _ = keys.obtain(scope, browsing_context.virtual_group_id, origin, requests_oac, browsing_context.isCrossOriginIsolated());
}

/// HTML 8.1.3.5 for a navigation's reserved environment in
/// `browsing_context`'s navigable, fetching `url`: a secure context when its
/// top-level creation URL is potentially trustworthy. A top-level
/// navigable's (a popup's) is `url`; a child navigable's is its parent
/// environment's - the top-level document's creation URL, which its URL
/// stands for.
fn reservedEnvironmentIsSecure(browsing_context: *html_core.BrowsingContext, url: []const u8, allocator: std.mem.Allocator) bool {
    const keys = dom_module.agent_cluster_keys;
    if (browsing_context.parent == null) return keys.isSecureTopLevelCreationUrl(allocator, url);
    const top = browsing_context.getTop();
    const top_document: *runtime.Instance = @ptrCast(@alignCast(top.getActiveDocument() orelse return false));
    const top_url = documentUrlOf(top_document, allocator) catch return false;
    defer allocator.free(top_url);
    return keys.isSecureTopLevelCreationUrl(allocator, top_url);
}

/// HTML "determine navigation params policy container" for the document
/// `record`'s navigation makes from `response`, owned by the caller; null
/// when it could not be made (out of memory: the document keeps a new one).
///
/// Step 1's history policy container is the traversed entry's document
/// state's (about: and data: documents keep one); step 3's initiator is the
/// source document's, or - for a traversal no document started - the
/// navigable's active document's.
fn navigationParamsPolicyContainer(integration: *IFrameIntegration, record: *Navigation, response: *const navigation_fetch.NavigationFetchResult) ?fetch_mod.internal.PolicyContainer {
    const allocator = integration.allocator;
    const PolicyContainer = fetch_mod.internal.PolicyContainer;
    const response_url = if (response.final_url.len > 0) response.final_url else record.url;
    // 1. "If historyPolicyContainer is not null": assert that responseURL
    // requires storing the policy container in history, and return a clone
    // of it.
    if (record.traversal_entry != 0 and navigate_steps.requiresStoringPolicyContainerInHistory(response_url)) {
        if (integration.browsing_context) |bc| {
            if (bc.jointHistory() catch null) |history| {
                if (history.historyPolicyContainer(record.traversal_entry)) |container| {
                    var restored = container.clone(allocator) catch return null;
                    // CSPEE leaves local history unspecified; HTML cloning
                    // intentionally leaves required_csp null. Chrome 154's
                    // RenderFrameHostImpl::TakeNewDocumentPropertiesFromNavigation
                    // (render_frame_host_impl.cc:17120) records the current
                    // requirement separately; ComputeFinalPolicies keeps the
                    // old enforced policies (navigation_policy_container_builder.cc:295-302).
                    if (!response.is_network_error) if (record.required_csp) |required| {
                        restored.required_csp = allocator.dupe(u8, required) catch {
                            restored.deinit();
                            return null;
                        };
                    };
                    return restored;
                }
            }
        }
    }
    const scheme = navigate_steps.schemeOf(response_url);
    const is_local = std.mem.eql(u8, scheme, "about") or std.mem.eql(u8, scheme, "blob") or std.mem.eql(u8, scheme, "data");
    var result = blk: {
        // 2. A srcdoc document inherits its container document's policies.
        if (record.srcdoc != null or navigate_steps.matchesAboutSrcdoc(response_url)) {
            if (containerDocumentOf(integration)) |parent| {
                if (dom_module.policy_containers.of(parent)) |container| break :blk container.clone(allocator) catch return null;
            }
        }
        // 3. A local response inherits its initiator's policy container.
        if (is_local) {
            if (record.initiator_policy_container) |*container| break :blk container.clone(allocator) catch return null;
            if (record.traversal_policy_container) |*container| break :blk container.clone(allocator) catch return null;
        }
        // 4-5. Otherwise use the response's container, or a new one.
        if (!std.mem.eql(u8, scheme, "http") and !std.mem.eql(u8, scheme, "https") and !std.mem.eql(u8, scheme, "data")) break :blk PolicyContainer.init(allocator);
        const headers = response.headers;
        break :blk PolicyContainer.fromResponseHeaders(allocator, .{
            .url = response_url,
            .csp = if (headers) |h| h.get("content-security-policy") else null,
            .csp_report_only = if (headers) |h| h.get("content-security-policy-report-only") else null,
            .referrer_policy = if (headers) |h| h.get("referrer-policy") else null,
            .reporting_endpoints = if (headers) |h| h.get("reporting-endpoints") else null,
            .integrity_policy = if (headers) |h| h.get("integrity-policy") else null,
            .integrity_policy_report_only = if (headers) |h| h.get("integrity-policy-report-only") else null,
        }) catch return null;
    };
    // CSPEE §2.4 items 9-11: after inheritance, apply the target snapshot's
    // requirement. History's stored local policy returned above is unchanged.
    if (record.required_csp != null and !response.is_network_error) {
        const uses_parent_origin = @import("csp").embedded_enforcement.allowsBlanketEnforcement("null", response_url, null);
        const local_origin = if (uses_parent_origin) blk: {
            const parent = containerDocumentOf(integration) orelse break :blk null;
            break :blk documentOriginOf(parent, allocator);
        } else null;
        defer if (local_origin) |origin| allocator.free(origin);
        result.applyRequiredCSP(record.required_csp, if (uses_parent_origin) local_origin orelse "null" else response_url, blanketCSPAcceptance(integration, record, response)) catch {
            result.deinit();
            return null;
        };
    }
    // Upgrade Insecure Requests 3.3: a nested browsing context whose
    // embedding document's insecure requests policy is Upgrade has Upgrade,
    // and so does every Document created in it.
    if (containerDocumentOf(integration)) |parent| {
        if (dom_module.policy_containers.of(parent)) |container| {
            if (container.upgradesInsecureRequests()) result.inherited_upgrade_insecure_requests = true;
        }
    }
    return result;
}

/// CSPEE §2.4.1: snapshot a valid iframe attribute, otherwise the embedding
/// document's requirement. No allocation on the absent-attribute/null path.
fn determineRequiredCSP(integration: *IFrameIntegration, url: []const u8) !?[]u8 {
    const element: *runtime.Instance = @ptrCast(@alignCast(integration.iframe_element orelse return null));
    const parent = (try interfaces.Node.get_ownerDocument(element)) orelse return null;
    const inherited = if (dom_module.policy_containers.of(parent)) |container| container.required_csp else null;
    if (dom_module.navigables.containerKind(element) == .iframe) {
        if (try interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("csp"))) |attribute| {
            var value = attribute;
            defer value.deinit(element.ctx.allocator);
            var origin = if (inherited != null) try fetch_mod.internal.policy_container.selfOriginOf(integration.allocator, url) else null;
            defer if (origin) |*o| o.deinit();
            if (try @import("csp").embedded_enforcement.isValidAttribute(integration.allocator, value.asSlice(), inherited, if (origin) |*o| o else null)) {
                return try integration.allocator.dupe(u8, value.asSlice());
            }
        }
    }
    return if (inherited) |value| try integration.allocator.dupe(u8, value) else null;
}

fn blanketCSPAcceptance(integration: *IFrameIntegration, record: *const Navigation, response: *const navigation_fetch.NavigationFetchResult) bool {
    if (record.required_csp == null) return false;
    const url = if (response.final_url.len > 0) response.final_url else record.url;
    const header = if (response.headers) |headers| headers.get("allow-csp-from") else null;
    const ee = @import("csp").embedded_enforcement;
    if (ee.allowsBlanketEnforcement("null", url, header)) return true;
    const value = header orelse return false;
    // Deviation from CSPEE §4.2's literal serialization comparison:
    // Chrome 154 ParseAllowCSPFromHeader parses a URL and compares its
    // origin, accepting canonical-equivalent URLs with paths too.
    const allowed_origin = fetch_mod.internal.origins.serializedOriginOf(integration.allocator, std.mem.trim(u8, value, " \t")) catch return false;
    defer integration.allocator.free(allowed_origin);
    if (std.mem.eql(u8, allowed_origin, "null")) return false;
    const parent = containerDocumentOf(integration) orelse return false;
    // Chromium 154 NavigationRequest::CheckCSPEmbeddedEnforcement uses the
    // parent frame's committed origin, including self/history navigations.
    const origin = documentOriginOf(parent, integration.allocator) orelse return false;
    defer integration.allocator.free(origin);
    return ee.allowsBlanketEnforcement(origin, url, allowed_origin);
}

/// CSPEE §4.1: explicit acceptance or subsumption, otherwise an error document.
fn requiredCSPBlocks(integration: *IFrameIntegration, record: *const Navigation, response: *const navigation_fetch.NavigationFetchResult) bool {
    const required = record.required_csp orelse return false;
    if (response.is_network_error or blanketCSPAcceptance(integration, record, response)) return false;
    const allocator = integration.allocator;
    const csp = @import("csp");
    const url = if (response.final_url.len > 0) response.final_url else record.url;
    const headers = response.headers;
    var container = fetch_mod.internal.PolicyContainer.fromResponseHeaders(allocator, .{
        .url = url,
        .csp = if (headers) |h| h.get("content-security-policy") else null,
        .csp_report_only = if (headers) |h| h.get("content-security-policy-report-only") else null,
    }) catch return true;
    defer container.deinit();
    var policy = csp.parsing.parseSerializedCSP(allocator, required, .header, .enforce) catch return true;
    defer policy.deinit();
    return !(csp.embedded_enforcement.subsumes(allocator, &policy, &container.csp_list) catch false);
}

/// CSP 4.2.5 for a frame's navigation: whether the response's own
/// frame-ancestors (its CSP headers) rejects one of the target's container
/// documents' origins. The request's own list cannot reject its source in
/// step 3: frame-ancestors is the only navigation-response directive and
/// ignores that type.
fn frameAncestorsBlock(integration: *IFrameIntegration, record: *Navigation, response: *const navigation_fetch.NavigationFetchResult) bool {
    if (integration.iframe_element == null or response.is_network_error) return false;
    const headers = response.headers orelse return false;
    const csp_value = headers.get("content-security-policy");
    const report_only = headers.get("content-security-policy-report-only");
    if (csp_value == null and report_only == null) return false;
    const allocator = integration.allocator;
    const response_url = if (response.final_url.len > 0) response.final_url else record.url;
    var container = fetch_mod.internal.PolicyContainer.fromResponseHeaders(allocator, .{
        .url = response_url,
        .csp = csp_value,
        .csp_report_only = report_only,
        .reporting_endpoints = headers.get("reporting-endpoints"),
        .integrity_policy = headers.get("integrity-policy"),
        .integrity_policy_report_only = headers.get("integrity-policy-report-only"),
    }) catch return false;
    defer container.deinit();
    const scheme = navigate_steps.schemeOf(response_url);
    const is_local = std.mem.eql(u8, scheme, "about") or std.mem.eql(u8, scheme, "blob") or std.mem.eql(u8, scheme, "data");

    // § 6.4.2.1 steps 5-6: the container documents' origins, innermost
    // first, as their ASCII serializations parse.
    const csp = @import("csp");
    const AncestorOrigin = csp.directives.frame_ancestors.AncestorOrigin;
    var ancestors: std.ArrayListUnmanaged(AncestorOrigin) = .empty;
    defer ancestors.deinit(allocator);
    var serialized: std.ArrayListUnmanaged([]u8) = .empty;
    defer {
        for (serialized.items) |bytes| allocator.free(bytes);
        serialized.deinit(allocator);
    }
    var document = containerDocumentOf(integration);
    while (document) |doc| {
        const origin = documentOriginOf(doc, allocator);
        if (origin) |owned| serialized.append(allocator, owned) catch {
            allocator.free(owned);
            return true;
        };
        ancestors.append(allocator, if (origin) |o| ancestorOriginOf(o) else null) catch return true;
        const window = (interfaces.Document.get_defaultView(doc) catch null) orelse break;
        const parent_container = dom_module.navigable_container.of(window) orelse break;
        document = interfaces.Node.get_ownerDocument(parent_container) catch null;
    }
    var report_context: NavigationResponseReporter = .{
        .sender = if (containerDocumentOf(integration)) |parent| windowOfRealm(parent.ctx) else null,
        .url = response_url,
        .response = response,
        .endpoints = container.endpoints,
    };
    return csp.directives.frame_ancestors.checkNavigationResponse(&container.csp_list, is_local, ancestors.items, response_url, .{ .context = &report_context, .report = NavigationResponseReporter.report });
}

/// Borrowed only during the synchronous CSP check; the public reporting
/// helper snapshots all native values before queuing delivery.
const NavigationResponseReporter = struct {
    sender: ?*runtime.Instance,
    url: []const u8,
    response: *const navigation_fetch.NavigationFetchResult,
    endpoints: ?*fetch_mod.internal.policy_container.Endpoints,

    fn report(context: *anyopaque, violation: *const @import("csp").violation_events.Violation) void {
        const self: *NavigationResponseReporter = @ptrCast(@alignCast(context));
        dom_module.csp_violations.reportNavigationResponse(self.sender orelse return, violation, .{
            .url = self.url,
            .referrer = self.response.referrer orelse "",
            .status = self.response.status,
            .endpoints = self.endpoints,
        }) catch {};
    }
};

/// A serialized tuple origin ("scheme://host[:port]") as frame-ancestors
/// matches it; null for "null", an opaque origin.
fn ancestorOriginOf(origin: []const u8) @import("csp").directives.frame_ancestors.AncestorOrigin {
    const sep = std.mem.indexOf(u8, origin, "://") orelse return null;
    const authority = origin[sep + 3 ..];
    const host_end = if (authority.len > 0 and authority[0] == '[')
        (std.mem.indexOfScalar(u8, authority, ']') orelse return null) + 1
    else
        std.mem.indexOfScalar(u8, authority, ':') orelse authority.len;
    const port: ?u16 = if (host_end < authority.len and authority[host_end] == ':')
        std.fmt.parseInt(u16, authority[host_end + 1 ..], 10) catch return null
    else
        null;
    return .{ .scheme = origin[0..sep], .host = authority[0..host_end], .port = port };
}

/// The document `integration`'s iframe element is in - its navigable's
/// embedding document - or null for a popup.
fn containerDocumentOf(integration: *IFrameIntegration) ?*runtime.Instance {
    const element: *runtime.Instance = @ptrCast(@alignCast(integration.iframe_element orelse return null));
    return interfaces.Node.get_ownerDocument(element) catch null;
}

/// HTML "determine the creation sandboxing flags" for `integration`'s
/// navigable's active browsing context, given its container ("embedder"):
/// with one, the container's iframe sandboxing flag set (empty for any other
/// element, which has no sandbox attribute) united with its node document's
/// active sandboxing flag set; with none - a popup - its popup sandboxing
/// flag set.
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#determining-the-creation-sandboxing-flags
fn creationSandboxingFlagsOf(integration: *IFrameIntegration) SandboxingFlagSet {
    if (integration.iframe_element != null) {
        const container_document = containerDocumentOf(integration);
        return sandboxing.creationSandboxingFlags(.{ .embedder = .{
            .iframe_flags = integration.iframe_sandboxing_flags,
            .container_document_flags = if (container_document) |document| dom_module.document_scripts.activeSandboxingFlags(document) else .empty,
        } });
    }
    const browsing_context = integration.browsing_context orelse return .empty;
    return sandboxing.creationSandboxingFlags(.{ .popup = browsing_context.popup_sandboxing_flags });
}

/// "Create and initialize a Document object" step 9: `document`, which
/// `browsing_context`'s navigable just made, takes the policy container its
/// commit chose, if one is waiting.
fn givePolicyContainer(document: *runtime.Instance, browsing_context: *html_core.BrowsingContext) void {
    const integration = integrationOfBrowsingContext(browsing_context) orelse return;
    if (integration.takeNextPolicyContainer()) |container| dom_module.policy_containers.set(document, container);
}

/// HTML "create and initialize a Document object" step 14: the new
/// document's referrer - the navigation request's referrer as main fetch
/// left it, waiting on the navigable (IFrameIntegration.next_referrer). The
/// empty string when there is none, or no request was fetched.
fn giveReferrer(document: *runtime.Instance, browsing_context: *html_core.BrowsingContext) void {
    const integration = integrationOfBrowsingContext(browsing_context) orelse return;
    const referrer = integration.next_referrer orelse return;
    document_internals.setReferrer(document, referrer) catch {};
}

/// HTML "create and initialize a Document object" step 17: "If
/// navigationParams's response has a `Refresh` header", the shared
/// declarative refresh steps with the document and the header's value
/// (isomorphic decoded, waiting on the navigable) - before the parser runs,
/// so a later meta refresh finds "will declaratively refresh" set.
fn giveRefresh(document: *runtime.Instance, browsing_context: *html_core.BrowsingContext) void {
    const integration = integrationOfBrowsingContext(browsing_context) orelse return;
    const value = integration.next_refresh orelse return;
    document_lifecycle.declarativeRefresh(document, value, null);
}

/// `document`'s document base URL, serialized, owned by `allocator`; null
/// when it cannot be read.
fn documentBaseUrl(document: *runtime.Instance, allocator: std.mem.Allocator) ?[]u8 {
    const base = interfaces.Node.get_baseURI(document) catch return null;
    defer document.ctx.allocator.free(base);
    return allocator.dupe(u8, base) catch null;
}

/// Unload the navigable's active document and its descendants, inside its
/// realm - the unload handlers run from the event loop, not from script -
/// with the pageswap event `page_swap` names fired at it first. False when
/// the realm is gone, or the pageswap event's listeners took the navigable
/// or its document away.
fn unloadActiveDocument(integration: *IFrameIntegration, page_swap: ?*const PageSwapStep) bool {
    const ctx = navigableContext(integration) orelse return false;
    var unloaded = true;
    if (!inRealm(ctx, unloadActive, .{ integration, page_swap, &unloaded })) return false;
    return unloaded;
}

fn unloadActive(integration: *IFrameIntegration, page_swap: ?*const PageSwapStep, unloaded: *bool) void {
    if (activeDocumentOf(integration)) |old| unloaded.* = unloadDocumentAndDescendantsSwapping(old, integration, page_swap);
}

/// "Deactivate a document for a cross-document navigation" step 5.1's
/// firePageSwapBeforeUnload: "fire the pageswap event" given the displayed
/// document, targetEntry, the navigation type, and a null viewTransition.
const PageSwapStep = struct {
    allocator: std.mem.Allocator,
    /// targetEntry, owned.
    target: html_core.navigation.joint_history.EntrySnapshot,
    navigation_type: dom_module.navigation_api.Kind,
    has_activation: bool,

    fn deinit(self: *PageSwapStep) void {
        self.target.deinit(self.allocator);
    }
};

/// What `runCommit` fires pageswap with for `record`, deciding - before the
/// displayed document unloads - the new document's origin, and the entry a
/// push or replace will commit (kept on `record` for `recordInHistory`).
/// Null when the navigable has no history to name an entry in.
fn pageSwapOf(integration: *IFrameIntegration, record: *Navigation, response: *const navigation_fetch.NavigationFetchResult) ?PageSwapStep {
    const bc = integration.browsing_context orelse return null;
    const history = bc.ensureHistoryEntries(&history_documents.infoOf) catch return null;
    const allocator = history.allocator;
    const final_url = if (response.final_url.len > 0) response.final_url else record.url;
    const origin = navigationParamsOrigin(integration, record.final_sandboxing_flags, final_url, integration.allocator) catch return null;
    if (record.target_origin) |old| integration.allocator.free(old);
    record.target_origin = origin;

    const kind: dom_module.navigation_api.Kind = if (record.traversal_entry != 0)
        (if (record.traversal_entry == record.traversal_from) .reload else .traverse)
    else if (record.history_handling == .push) .push else .replace;
    const target = if (record.traversal_entry != 0) blk: {
        const entry = history.entryById(record.traversal_entry) orelse return null;
        break :blk history.snapshot(entry) catch return null;
    } else blk: {
        const prepared = history.prepareDocument(bc.id, origin, jointHandling(record.history_handling));
        record.prepared = prepared;
        break :blk history.preparedSnapshot(bc.id, final_url, origin, prepared) catch return null;
    };

    // "Fire the pageswap event" step 4: "targetEntry's document's origin is
    // same origin with displayedDocument's origin; and targetEntry's
    // document's was created via cross-origin redirects is false, or its
    // latest entry is not null" - never, with no bfcache.
    const displayed_window: ?*runtime.Instance = if (bc.getActiveWindow()) |w| @ptrCast(@alignCast(w)) else null;
    const displayed_origin = originOfWindow(displayed_window, integration.allocator) catch null;
    defer if (displayed_origin) |o| integration.allocator.free(o);
    const same_origin = if (displayed_origin) |o| !std.mem.eql(u8, o, "null") and std.mem.eql(u8, o, origin) else false;
    return .{
        .allocator = allocator,
        .target = target,
        .navigation_type = kind,
        .has_activation = same_origin and !response.has_cross_origin_redirects,
    };
}

/// The pageswap step of "unload a document and its descendants" (6.1), at
/// `document` in its realm. False when its listeners took the navigable
/// away, or the document is no longer the one it shows: the unload stops
/// there, as the navigable's removal has unloaded it already.
fn firePageSwapAt(document: *runtime.Instance, generation: u64, integration: *IFrameIntegration, step: *const PageSwapStep) bool {
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return true;
    dom_module.navigation_api.firePageSwap(window, .{
        .navigation_type = step.navigation_type,
        .target = &step.target,
        .has_activation = step.has_activation,
    });
    if (integration.state == .discarded or integration.browsing_context == null) return false;
    if (runtime.SlabAllocator.generationOf(document) != generation) return false;
    return activeDocumentOf(integration) == document;
}

/// `runCommit`'s commit, inside the realm the document goes in.
fn commitNavigation(integration: *IFrameIntegration, record: *Navigation, response: *navigation_fetch.NavigationFetchResult) void {
    const ctx = navigableContext(integration) orelse return endLoadDelay(integration);
    if (!inRealm(ctx, commitInRealm, .{ integration, record, response })) endLoadDelay(integration);
}

fn commitInRealm(integration: *IFrameIntegration, record: *Navigation, response: *navigation_fetch.NavigationFetchResult) void {
    // The entry is in the traversable's history before the new document's
    // parser runs, as "finalize a cross-document navigation" puts it there
    // before any of the document's script: history.length counts it, and a
    // location.reload() from an inline script reloads it, not the entry the
    // navigation left.
    const final_url = if (response.final_url.len > 0) response.final_url else record.url;
    // The origin decided before the displayed document unloaded, as the
    // pageswap event saw it.
    const computed: ?[]u8 = if (record.target_origin == null) navigationParamsOrigin(integration, record.final_sandboxing_flags, final_url, integration.allocator) catch null else null;
    defer if (computed) |o| integration.allocator.free(o);
    const origin: []const u8 = record.target_origin orelse computed orelse "null";
    const document_state = recordInHistory(integration, record, final_url, origin);
    if (record.history_policy_container) |*container| {
        if (document_state) |state| {
            if (integration.browsing_context) |bc| {
                if (bc.jointHistory() catch null) |history| history.setHistoryPolicyContainer(state, container) catch {};
            }
        }
    }
    // "Create and initialize a Document object": Navigation Timing's "create
    // the navigation timing entry" for the document about to be made in the
    // navigable's realm (realmForDocument made or chose it) - which also
    // makes the navigation's start time its time origin - before the
    // document's parser, and any of its script, runs.
    if (response.timing) |*timing| {
        if (navigableContext(integration)) |realm| {
            const report: fetch_mod.internal.TimingReport = .{
                .timing_info = &timing.timing_info,
                .url = final_url,
                .initiator_type = .other,
                .cache_state = "",
                .body_info = .{
                    .encoded_size = if (response.body) |b| b.len else 0,
                    .decoded_size = if (response.body) |b| b.len else 0,
                    .content_encoding = timing.content_encoding,
                },
                .response_status = timing.response_status,
            };
            dom_module.performance_timeline.createNavigationTimingEntry(realm, .{
                .report = &report,
                .unload_event_start = timing.unload_event_start,
                .unload_event_end = timing.unload_event_end,
                .redirect_count = timing.redirect_count,
                // A traversal to the entry it leaves is a reload (as the
                // navigation API's activation reads it), any other is
                // back_forward; a push or replace navigates.
                .navigation_type = if (record.traversal_entry == 0)
                    .navigate
                else if (record.traversal_entry == record.traversal_from)
                    .reload
                else
                    .back_forward,
            }) catch |err| log.debug("[navigation] no navigation timing entry for {s}: {s}", .{ record.url, @errorName(err) });
        }
    }
    // "Create and initialize a Document object" step 4's origin -
    // navigationParams's - for the document the commit makes.
    integration.setNextOrigin(navigationParamsOriginRecord(integration, record, response, final_url, origin));
    defer integration.setNextOrigin(null);
    integration.commitResponse(record.url, response) catch |err| {
        log.debug("[navigation] commit of {s} failed: {s}", .{ record.url, @errorName(err) });
        endLoadDelay(integration);
        return;
    };
    attachDocument(integration, document_state);
    // A push cleared the traversable's forward session history, other
    // navigables' entries with it: their navigation APIs dispose of them.
    if (record.traversal_entry == 0 and record.history_handling == .push) {
        if (integration.browsing_context) |bc| dom_module.navigation_api.entriesRemoved(@ptrCast(bc.getTop()));
    }
    finishParserlessNavigation(integration);
}

/// "Finalize a cross-document navigation" steps 5-10: the new document's
/// entry, pushed or replacing the navigable's current one in the
/// traversable's history - or, for a traversal, the entry it repopulates -
/// recorded as the document is about to be made. Its URL is `url` (the
/// response's) and its document state's origin `origin` (serialized): the
/// navigation params' origin, which exists before the document does. The
/// navigable's active window is still the one the navigation leaves, so its
/// origin is not the new document's. Returns the entry's document state,
/// which `attachDocument` gives the document once it exists; null when
/// nothing was recorded.
fn recordInHistory(integration: *IFrameIntegration, record: *Navigation, url: []const u8, origin: []const u8) ?u64 {
    const bc = integration.browsing_context orelse return null;
    const history = bc.jointHistory() catch return null;
    const joint_history = html_core.navigation.joint_history;
    // "Apply the history step" 12.1: previousEntry - the navigable's active
    // entry before this navigation changes it: the one a traversal leaves,
    // or the current one, which a push leaves and a replace changes in place.
    const previous_entry: ?*joint_history.Entry = if (record.traversal_entry != 0)
        history.entryById(record.traversal_from)
    else
        history.currentEntry(bc.id);
    // An entry whose document is the initial about:blank is never the
    // activation's old entry: step 7.4 requires "previousEntryForActivation's
    // document's is initial about:blank is false", and a navigation away from
    // it is a replace, which leaves it out of the entry list (step 7.3).
    // Asked of the navigable's active document - the previous entry's, for
    // a navigation (a traversal's from-entry may name a document gone since).
    const previous_is_initial = record.traversal_entry == 0 and
        (if (activeDocumentOf(integration)) |doc| document_lifecycle.isInitialAboutBlank(doc) else false);
    var previous: ?joint_history.EntrySnapshot = if (previous_entry) |entry|
        (if (previous_is_initial) null else history.snapshot(entry) catch null)
    else
        null;
    // recordActivation takes it; anything left here goes.
    defer if (previous) |*p| p.deinit(history.allocator);
    if (record.traversal_entry != 0) {
        const entry = history.entryById(record.traversal_entry) orelse return null;
        const kind: joint_history.NavigationType = if (record.traversal_entry == record.traversal_from) .reload else .traverse;
        const state = entry.document_state;
        const taken = previous;
        previous = null;
        history.recordActivation(entry.id, kind, taken) catch {};
        return state;
    }
    const handling = jointHandling(record.history_handling);
    const committed = if (record.prepared) |prepared|
        history.commitPreparedDocument(bc.id, url, null, origin, handling, prepared)
    else
        history.commitDocument(bc.id, url, null, origin, handling);
    committed catch return null;
    // Navigate step 24.4: the document state's resource is documentResource
    // - a srcdoc document's markup, which a traversal back loads again.
    if (record.srcdoc) |markup| history.setCurrentResource(bc.id, markup) catch {};
    const current = history.currentEntry(bc.id) orelse return null;
    // "Update document for history step application" step 7's inputs, for
    // navigation.activation, before any of the document's script runs.
    const taken = previous;
    previous = null;
    history.recordActivation(current.id, if (handling == .push) .push else .replace, taken) catch {};
    return current.document_state;
}

/// The recorded entry's document state takes the document the commit made:
/// every entry of it, pushState's and fragment navigations' made by the
/// document's scripts as it parsed among them.
fn attachDocument(integration: *IFrameIntegration, document_state: ?u64) void {
    const state = document_state orelse return;
    const bc = integration.browsing_context orelse return;
    const history = bc.jointHistory() catch return;
    history.setDocumentOfState(state, bc.getActiveDocument());
}

/// HTML "determining the origin" for the document a navigation to `url`
/// makes - the navigation params' origin - serialized and owned by
/// `allocator`, computed from what exists before the document does:
///
/// 1. "If sandboxFlags has its sandboxed origin browsing context flag set,
///    then return a new opaque origin": "null" when `flags`, the navigation's
///    final sandboxing flag set, has it.
/// 2-3. A URL that matches about:blank, or about:srcdoc, inherits: its
///    container document's origin (a popup's: the window it replaces). This
///    is the origin the new Window reports (IFrameIntegration's
///    parseOriginFromURL gives about: URLs the container origin), where the
///    spec gives about:blank the initiator's.
/// 4. Otherwise `url`'s origin, as the URL Standard serializes it.
fn navigationParamsOrigin(integration: *IFrameIntegration, flags: SandboxingFlagSet, url: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const bc = integration.browsing_context orelse return allocator.dupe(u8, "null");
    if (flags.origin) return allocator.dupe(u8, "null");
    if (navigate_steps.matchesAboutBlank(url) or navigate_steps.matchesAboutSrcdoc(url)) {
        const container_window: ?*runtime.Instance = blk: {
            const element: *runtime.Instance = @ptrCast(@alignCast(integration.iframe_element orelse break :blk null));
            const NodeImpl = @import("Node.zig");
            const container = NodeImpl.getOwnerDocument(element) orelse break :blk null;
            break :blk interfaces.Document.get_defaultView(container) catch null;
        };
        const active: ?*runtime.Instance = if (bc.getActiveWindow()) |w| @ptrCast(@alignCast(w)) else null;
        return originOfWindow(container_window orelse active, allocator);
    }
    var record = basic_parser.parse(allocator, url, null) catch return allocator.dupe(u8, "null");
    defer record.deinit();
    const origin = try url_origin.getOrigin(allocator, &record);
    defer origin.deinit(allocator);
    return origin.serialize(allocator);
}

/// navigationParams's origin as the record the committed document is made
/// with (one reference; null leaves it an origin of its own), following
/// `navigationParamsOrigin`, whose serialization is `serialized`:
///
/// - a network error's document, and any document whose final sandboxing
///   flag set has the sandboxed origin browsing context flag: a new opaque
///   origin;
/// - about:blank and about:srcdoc: the container document's origin record
///   itself (a popup's: its active document's), shared - so a domain set
///   in either document is both documents'
///   (windows/document-domain-nested-navigate.window.js);
/// - otherwise a new origin, `serialized`.
fn navigationParamsOriginRecord(
    integration: *IFrameIntegration,
    record: *const Navigation,
    response: *const navigation_fetch.NavigationFetchResult,
    url: []const u8,
    serialized: []const u8,
) ?*OriginRecord {
    const allocator = integration.allocator;
    if (response.is_network_error) return OriginRecord.create(allocator, "null") catch null;
    // "Determining the origin" step 1, given navigationParams's final
    // sandboxing flag set - the target's sandboxing flags united with the
    // policy container's CSP-derived ones (CSP 4.3 "sandbox"): "If
    // sandboxFlags has its sandboxed origin browsing context flag set, then
    // return a new opaque origin."
    if (record.final_sandboxing_flags.origin) return OriginRecord.create(allocator, "null") catch null;
    if (record.srcdoc == null and navigate_steps.matchesAboutBlank(url)) {
        // "Determining the origin" step 2: about:blank's origin is the
        // initiator's - the source document's, which for a popup the opener
        // navigates is the opener's, not the popup's active document's.
        if (record.initiator_origin) |initiator| return initiator.retain();
    }
    if (record.srcdoc != null or navigate_steps.matchesAboutBlank(url) or navigate_steps.matchesAboutSrcdoc(url)) {
        const container_document: ?*runtime.Instance = if (integration.iframe_element) |element|
            (interfaces.Node.get_ownerDocument(@ptrCast(@alignCast(element))) catch null)
        else
            null;
        const from = container_document orelse activeDocumentOf(integration) orelse return null;
        const shared = (dom_module.document_origin.shareable(from) catch null) orelse return null;
        return shared.retain();
    }
    return OriginRecord.create(allocator, serialized) catch null;
}

/// `window`'s origin, serialized ("null" without one). Owned.
fn originOfWindow(window: ?*runtime.Instance, allocator: std.mem.Allocator) ![]u8 {
    const w = window orelse return allocator.dupe(u8, "null");
    const origin = interfaces.Window.get_origin(w) catch return allocator.dupe(u8, "null");
    defer w.ctx.allocator.free(origin);
    return allocator.dupe(u8, origin);
}

fn jointHandling(handling: navigate_steps.HistoryHandling) html_core.navigation.joint_history.HistoryHandling {
    return switch (handling) {
        .push => .push,
        .replace => .replace,
    };
}

/// dom.navigables: a history traversal navigates `browsing_context_ptr`'s
/// navigable to the entry it traverses to - from its document state's
/// resource, when that is a srcdoc document's markup. The top-level page
/// cannot be replaced, so only a frame or popup can.
fn traverseNavigable(browsing_context_ptr: *anyopaque, entry_id: u64, url: []const u8, resource: ?[]const u8, from_entry_id: u64) void {
    for (live_navigables.items) |integration| {
        const bc = integration.browsing_context orelse continue;
        if (@as(*anyopaque, @ptrCast(bc)) != browsing_context_ptr) continue;
        // A srcdoc entry's document takes its container document's base URL
        // as its about base URL. Deviation, stated: the spec restores the one
        // the entry's document state recorded when it was first navigated to;
        // the container's current one is used instead.
        const source: ?*runtime.Instance = if (resource != null) blk: {
            const element: *runtime.Instance = @ptrCast(@alignCast(integration.iframe_element orelse break :blk null));
            break :blk @import("Node.zig").getOwnerDocument(element);
        } else null;
        navigate(integration, url, .{ .source_document = source, .history_behavior = .replace, .traversal_entry = entry_id, .traversal_from = from_entry_id, .srcdoc = resource });
        return;
    }
}

/// HTML §14.2: XML EOF uses the same "the end" as HTML. The XML parser is
/// not implemented yet, but its received document still needs completion.
/// Loading HTML may instead own a suspended parser; leave its EOF to it.
fn finishParserlessNavigation(integration: *IFrameIntegration) void {
    const content_type = integration.getLoadedContentType() orelse return;
    if (html_module.navigation.document_type.classify(content_type) != .xml) return;
    const document = activeDocumentOf(integration) orelse return endLoadDelay(integration);
    document_lifecycle.finishWithoutParser(document);
}

/// "Unload a document and its descendants": its child navigables' documents
/// first, then `document`. Their navigations in flight end with them, and
/// their windows' timers stop ("unloading document cleanup steps" 4.2).
fn unloadDocumentAndDescendants(document: *runtime.Instance, integration: *IFrameIntegration) void {
    _ = unloadDocumentAndDescendantsSwapping(document, integration, null);
}

/// `unloadDocumentAndDescendants` with firePageSwapSteps: the pageswap event
/// `page_swap` names, fired at `document` after its descendants have
/// unloaded and before it does (step 6.1). False when that event's
/// listeners took the navigable or `document` away before it unloaded.
///
/// `document` is going: a navigation replaces it, or its traversable
/// closes. Unloaded, each document here is destroyed too ("unload" step 20:
/// none is salvageable without a bfcache), and then so are the navigables
/// of `document`'s iframes (`destroyChildNavigables`).
fn unloadDocumentAndDescendantsSwapping(document: *runtime.Instance, integration: *IFrameIntegration, page_swap: ?*const PageSwapStep) bool {
    var documents = dom_module.navigables.inclusiveDescendantDocuments(document, integration.allocator);
    defer documents.deinit(integration.allocator);
    // Children first: the list is parents-first, so walk it backwards.
    var i = documents.items.len;
    while (i > 0) {
        i -= 1;
        const entry = documents.items[i];
        if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
        if (entry.browsing_context) |child_bc| {
            if (integrationOfBrowsingContext(child_bc)) |child| {
                if (child != integration) abandonNavigationsOf(child);
            }
        }
        if (i == 0) if (page_swap) |step| {
            if (!firePageSwapAt(entry.document, entry.generation, integration, step)) return false;
        };
        document_lifecycle.unload(entry.document);
        // Not kept for traversal (no bfcache): an entry that held it will be
        // repopulated by a navigation.
        if (integration.browsing_context) |bc| {
            if (bc.getTop().joint_history) |history| history.forgetDocument(@ptrCast(entry.document));
        }
    }
    if (integration.browsing_context) |bc| dom_module.navigables.destroyWindowDocuments(bc);
    destroyChildNavigables(integration);
    return true;
}

/// The navigables of the iframes in a document that is going - unloaded and
/// destroyed by `unloadDocumentAndDescendantsSwapping` - are destroyed after
/// it, before a new document takes its place. HTML's navigable tree hangs off
/// active documents: a navigable's child navigables are the content
/// navigables of the navigable containers in its active document
/// ("document-tree child navigables"), so once the document is unloaded and
/// destroyed they are nobody's children. Each goes as a removed iframe's
/// does - "destroy a child navigable" step 3, its container's content
/// navigable is null - through the integration that owns it: its browsing
/// context leaves `integration`'s children, closes and lets go of its own
/// (BrowsingContext.discard), and its iframe's contentWindow reads null. The
/// order is Blink's FrameLoader::DetachDocument: the unload event, then
/// LocalFrame::DetachChildren (each child frame's Frame::Detach, which
/// unlinks it from its parent - Frame::RemoveChild), then the old document's
/// shutdown, and only then CommitDocumentLoader for the new one.
///
/// They stayed on the list until the replaced document's iframe elements
/// were collected, which freed their browsing contexts there: "definitely
/// close" walked a freed one (BrowsingContext.collectDescendants, SIGSEGV at
/// 0xaaaa...), and History's traversal made a joint session history on a
/// freed and reused one - a leak, and a write into another object's memory.
///
/// Their session history entries stay: they are the replaced document's
/// nested histories, and the traversable's steps still count them. Their
/// realms end as they did, with their integrations.
fn destroyChildNavigables(integration: *IFrameIntegration) void {
    var i: usize = if (integration.browsing_context) |bc| bc.children.items.len else 0;
    while (i > 0) {
        i -= 1;
        // Read again each time: a child's navigation API hears its
        // navigation abort below, and script can take the navigable, or
        // more of its children, away meanwhile.
        const bc = integration.browsing_context orelse return;
        if (i >= bc.children.items.len) continue;
        const child = bc.children.items[i];
        if (integrationOfBrowsingContext(child)) |owner| {
            owner.onRemovedFromDocument();
        } else {
            // A context whose integration made no realm for it: no navigable
            // to destroy, but not `bc`'s child either.
            child.removeFromParent();
        }
    }
}

/// HTML "navigate to a fragment" (§7.4.2.3.3) - synchronous: the navigate
/// event, then the document's URL changes now, and hashchange is queued if
/// the fragment did. Scrolling (15: no layout) is not modelled, stated.
fn navigateToFragment(integration: *IFrameIntegration, url: []const u8, old_url: []const u8, handling: navigate_steps.HistoryHandling, options: NavigateOptions) void {
    const allocator = integration.allocator;
    // Steps 1-5: the navigate event, with the destination's navigation API
    // state - navigate()'s, else the active entry's. "If continue is false,
    // then return."
    var destination_state: html_core.navigation.joint_history.SerializedState = .undefined;
    defer destination_state.deinit(allocator);
    if (integration.browsing_context) |bc| {
        if (options.navigation_api_state) |state| {
            destination_state = state.clone(allocator) catch .undefined;
        } else if (bc.ensureHistoryEntries(&history_documents.infoOf)) |history| {
            if (history.currentEntry(bc.id)) |entry| destination_state = entry.api_state.clone(allocator) catch .undefined;
        } else |_| {}
        if (bc.getActiveWindow()) |window| {
            if (!dom_module.navigation_api.firePushReplaceReload(@ptrCast(@alignCast(window)), .{
                .navigation_type = if (handling == .push) .push else .replace,
                .destination_url = url,
                .is_same_document = true,
                .user_involvement = options.user_involvement,
                .source_element = options.source_element,
                .navigation_api_state = destination_state,
            })) return;
        }
    }
    // The event's handlers ran script: a navigable taken away is not
    // navigated.
    if (integration.state == .discarded) return;
    // Steps 6-13: the new entry on the same document, with the destination's
    // navigation API state and a null classic history API state; "finalize a
    // same-document navigation" pushes or replaces it in the traversable's
    // history.
    if (integration.browsing_context) |bc| {
        if (bc.ensureHistoryEntries(&history_documents.infoOf)) |history| {
            const api_state = destination_state.clone(allocator) catch null;
            history.commitSameDocument(bc.id, url, .null, jointHandling(handling), api_state) catch {};
        } else |_| {}
    }
    // Step 12: "Set navigable's active document's URL to url."
    integration.setDocumentUrl(url);
    // Step 15, "update document for history step application" 6.4.2:
    // "Update the navigation API entries for a same-document navigation
    // given navigation, historyEntry, and historyHandling."
    if (integration.browsing_context) |bc| {
        if (bc.getActiveWindow()) |window| {
            dom_module.navigation_api.sameDocumentNavigation(@ptrCast(@alignCast(window)), switch (handling) {
                .push => .push,
                .replace => .replace,
            });
        }
    }
    // Step 15, "update document for history step application" step 6.4.3:
    // "Fire an event named popstate at document's relevant global object,
    // using PopStateEvent, with the state attribute initialized to
    // document's history object's state" - null: step 6.3 restored it from
    // the new entry, whose classic history API state is never carried over.
    if (integration.state != .discarded) {
        if (integration.browsing_context) |bc| {
            if (bc.getActiveWindow()) |window| firePopStateNull(@ptrCast(@alignCast(window)));
        }
    }
    // Step 6.4.5: "If oldURL's fragment is not equal to entry's URL's
    // fragment, then queue a global task ... to fire an event named
    // hashchange".
    const old_fragment = navigate_steps.fragmentOf(old_url);
    const new_fragment = navigate_steps.fragmentOf(url);
    const same = if (old_fragment) |a| (if (new_fragment) |b| std.mem.eql(u8, a, b) else false) else new_fragment == null;
    if (!same) queueHashChange(integration, old_url, url);
}

/// "Update document for history step application" step 6.4.3 for a
/// fragment navigation's entry: popstate at `window`, its state null.
fn firePopStateNull(window: *runtime.Instance) void {
    const event = interfaces.PopStateEvent.call_constructor(
        window.ctx,
        runtime.DOMString.initInterned("popstate"),
        webidl.Opt(dictionaries.PopStateEventInit).passed(.{ .base = .{}, .state = runtime.JSValue.jsNull }),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = dom_module.fire_event.dispatchTrusted(window, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// A queued hashchange: the window it fires at, held with its slab
/// generation, and the two URLs, owned.
const HashChange = struct {
    window: *runtime.Instance,
    generation: u64,
    old_url: []u8,
    new_url: []u8,
    allocator: std.mem.Allocator,

    fn destroy(self: *HashChange) void {
        self.allocator.free(self.old_url);
        self.allocator.free(self.new_url);
        self.allocator.destroy(self);
    }
};

fn queueHashChange(integration: *IFrameIntegration, old_url: []const u8, new_url: []const u8) void {
    const browsing_context = integration.browsing_context orelse return;
    const window: *runtime.Instance = @ptrCast(@alignCast(browsing_context.getActiveWindow() orelse return));
    const allocator = integration.allocator;
    const task = allocator.create(HashChange) catch return;
    task.* = .{
        .window = window,
        .generation = runtime.SlabAllocator.generationOf(window),
        .old_url = allocator.dupe(u8, old_url) catch {
            allocator.destroy(task);
            return;
        },
        .new_url = allocator.dupe(u8, new_url) catch {
            allocator.free(task.old_url);
            allocator.destroy(task);
            return;
        },
        .allocator = allocator,
    };
    const loop = window.ctx.getOptionalEventLoop() orelse return runHashChange(task);
    loop.queueTask(.{ .callback = &runHashChange, .context = task, .drop = &dropHashChange });
}

fn dropHashChange(context: ?*anyopaque) void {
    const task: *HashChange = @ptrCast(@alignCast(context orelse return));
    task.destroy();
}

fn runHashChange(context: ?*anyopaque) void {
    const task: *HashChange = @ptrCast(@alignCast(context orelse return));
    defer task.destroy();
    if (runtime.SlabAllocator.generationOf(task.window) != task.generation) return;
    // A global task of the window: it runs in the window's realm.
    engine.runTaskInRealm(task.window.ctx, fireHashChange, task) catch |err| {
        log.debug("hashchange not fired: {}", .{err});
    };
}

fn fireHashChange(data: ?*anyopaque) void {
    const task: *HashChange = @ptrCast(@alignCast(data.?));
    const event = interfaces.HashChangeEvent.call_constructor(
        task.window.ctx,
        runtime.DOMString.initInterned("hashchange"),
        webidl.Opt(dictionaries.HashChangeEventInit).passed(.{ .base = .{}, .oldURL = task.old_url, .newURL = task.new_url }),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = @import("dom").fire_event.dispatchTrusted(task.window, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// HTML "navigate to a javascript: URL" (§7.4.2.3.2), as its task.
///
/// Step 3 (the initiator's origin) is not modelled. Steps 4-5 are: CSP
/// 4.2.4 over the record's initiator policy container, with its
/// cspNavigationType (dom.csp_violations.shouldJavascriptNavigationBeBlocked:
/// require-trusted-types-for's pre-navigation check, whose default policy
/// may rewrite the URL, form-action's for a form submission, and the
/// javascript: URL's inline check). The new document's origin is the
/// container's, not the initiator's - the same when, as in every case this
/// engine reaches, the page navigates its own frame.
fn runJavascriptNavigation(context: ?*anyopaque) void {
    const id = idOf(context);
    const kv = navigations.fetchRemove(id) orelse return;
    const record = kv.value;
    defer record.destroy();
    const integration = record.integration;
    if (!isOngoing(integration, id)) return;
    // Step 2: "Set the ongoing navigation for targetNavigable to null."
    integration.ongoing_navigation = .none;

    // Step 4: "If initiatorOrigin is not same origin-domain with
    // targetNavigable's active document's origin, then return." The
    // initiator's origin as it is now - a domain set since the navigation
    // started counts.
    if (!initiatorSameOriginDomainWithActive(integration, record)) return endLoadDelay(integration);

    // Step 5: the request - url, the initiator policy container - and
    // "should navigation request of type be blocked by Content Security
    // Policy?" given it and cspNavigationType. Its client is the source
    // document's global, the record's reporter's, where its violations go;
    // one that is gone has no default policy, so a javascript: URL under
    // enforced Trusted Types is then Blocked.
    const client: ?*runtime.Instance = if (record.csp_reporter) |reporter| blk: {
        if (runtime.SlabAllocator.generationOf(reporter.global) != reporter.generation) break :blk null;
        if (!reporter.global.ctx.hasEngine()) break :blk null;
        break :blk reporter.global;
    } else null;
    if (record.initiator_policy_container) |*container| {
        const check = dom_module.csp_violations.shouldJavascriptNavigationBeBlocked(record.allocator, &container.csp_list, client, containerElement(integration), record.url, record.csp_navigation_type, &isParsableUrl) catch return endLoadDelay(integration);
        switch (check) {
            .allowed => {},
            .rewritten => |url| {
                record.allocator.free(record.url);
                record.url = url;
            },
            .blocked => return endLoadDelay(integration),
        }
    }
    // Not in the spec, stated (whatwg/html#4651;
    // dom.csp_violations.shouldTargetBlockJavascriptUrl): Chrome and Firefox
    // check the target's CSP too, after the initiator's, and WPT's
    // to-javascript-parent-initiated-child-csp.html asserts it - skipped when
    // the target is the initiator, whose list step 5 just checked.
    if (integration.browsing_context) |bc| {
        if (bc.getActiveWindow()) |active| {
            const target_window: *runtime.Instance = @ptrCast(@alignCast(active));
            if (target_window != client and target_window.ctx.hasEngine() and
                dom_module.csp_violations.shouldTargetBlockJavascriptUrl(target_window, record.url)) return endLoadDelay(integration);
        }
    }

    integration.busy += 1;
    defer finishBusy(integration);
    javascriptNavigation(integration, record);

    // Step 17: "load an HTML document" given the result as its body - in the
    // realm "create and initialize a Document object" picks.
    const html = record.javascript_result orelse return;
    const url = record.javascript_url orelse return;
    if (integration.state == .discarded or integration.browsing_context == null) return;
    integration.realmForDocument(integration.container_origin) catch return endLoadDelay(integration);
    // Step 11: the new document state's about base URL is oldDocState's.
    integration.setNextAboutBaseUrl(record.initiator_base_url);
    defer integration.setNextAboutBaseUrl(null);
    // Step 12: navigationParams's policy container, the replaced document's
    // ("create and initialize a Document object" step 9 gives it the new
    // document before its parser runs).
    integration.setNextPolicyContainer(record.javascript_policy_container);
    record.javascript_policy_container = null;
    defer integration.setNextPolicyContainer(null);
    // Step 8: "initiatorOrigin is newDocument's origin" - the record
    // itself; with no initiator, the replaced document's.
    integration.setNextOrigin(javascriptDocumentOrigin(integration, record));
    defer integration.setNextOrigin(null);
    // Step 16's final sandboxing flag set (taken in javascriptNavigation).
    integration.setNextSandboxingFlags(record.final_sandboxing_flags);
    defer integration.setNextSandboxingFlags(.empty);
    const ctx = navigableContext(integration) orelse return endLoadDelay(integration);
    if (!inRealm(ctx, commitJavascriptResult, .{ integration, record, url, html })) endLoadDelay(integration);
}

fn commitJavascriptResult(integration: *IFrameIntegration, record: *Navigation, url: []const u8, html: []const u8) void {
    // Step 13: finalized as a "replace" - in the history before the new
    // document's scripts run, as for any other document.
    // A javascript: URL's document is of the active document's origin.
    const active: ?*runtime.Instance = if (integration.browsing_context) |bc| (if (bc.getActiveWindow()) |w| @as(*runtime.Instance, @ptrCast(@alignCast(w))) else null) else null;
    const origin = originOfWindow(active, integration.allocator) catch return endLoadDelay(integration);
    defer integration.allocator.free(origin);
    const document_state = recordInHistory(integration, record, url, origin);
    integration.commitHtmlAt(url, html, if (record.final_sandboxing_flags.origin) Origin.createOpaque() else integration.container_origin) catch return endLoadDelay(integration);
    attachDocument(integration, document_state);
}

/// "Navigate to a javascript: URL" step 4 for `record`: whether its
/// initiatorOrigin is same origin-domain with the target navigable's active
/// document's origin. True with no initiator - the user agent's own
/// navigation - and with no active document to compare.
fn initiatorSameOriginDomainWithActive(integration: *IFrameIntegration, record: *const Navigation) bool {
    const initiator = record.initiator_origin orelse return true;
    const active = activeDocumentOf(integration) orelse return true;
    // Unresolved only when no getter could answer it: the record's
    // identity still decides.
    const initiator_serialized = initiator.serialized orelse "null";
    const active_serialized = documentOriginOf(active, integration.allocator) orelse return false;
    defer integration.allocator.free(active_serialized);
    return dom_module.origin_record.sameOriginDomain(
        .{ .serialized = initiator_serialized, .record = initiator },
        .{ .serialized = active_serialized, .record = dom_module.document_origin.record(active) },
    );
}

/// The origin record a javascript: URL's String document is made with (one
/// reference): its initiator's, or with none the replaced document's.
fn javascriptDocumentOrigin(integration: *IFrameIntegration, record: *const Navigation) ?*OriginRecord {
    if (record.initiator_origin) |initiator| return initiator.retain();
    const active = activeDocumentOf(integration) orelse return null;
    const shared = (dom_module.document_origin.shareable(active) catch null) orelse return null;
    return shared.retain();
}

/// The navigable's container element, if it has one (a popup has none).
fn containerElement(integration: *IFrameIntegration) ?*runtime.Instance {
    const element = integration.iframe_element orelse return null;
    return @ptrCast(@alignCast(element));
}

/// `runJavascriptNavigation`'s work, inside the navigable's realm.
fn javascriptNavigation(integration: *IFrameIntegration, record: *Navigation) void {
    const ctx = navigableContext(integration) orelse return endLoadDelay(integration);
    if (!inRealm(ctx, javascriptNavigationInRealm, .{ integration, record })) endLoadDelay(integration);
}

fn javascriptNavigationInRealm(integration: *IFrameIntegration, record: *Navigation) void {
    // Step 6: "evaluate a javascript: URL".
    const result = evaluateJavascriptUrl(integration, record.url);
    const html = result orelse {
        // Step 7: no new document. On initial insertion into an initial
        // about:blank document, the iframe load event steps still run.
        const initial = if (activeDocumentOf(integration)) |doc| document_lifecycle.isInitialAboutBlank(doc) else false;
        if (record.initial_insertion and initial) {
            if (integration.iframe_element) |element| return runIframeLoadEventSteps(@ptrCast(@alignCast(element)));
        }
        endLoadDelay(integration);
        return;
    };
    defer integration.allocator.free(html);
    if (integration.state == .discarded or integration.browsing_context == null) return;
    // Not in the spec, stated: a navigation the script itself started
    // (`javascript:location.href='...'`, whose value is a String) keeps
    // going, and the String makes no document - step 3 left the ongoing
    // navigation null, so one now is the script's. Committing a document
    // here would unload the active one at once, with the tasks its script
    // queued (a violation's event among them), and cancel that navigation.
    // Blink's ScriptController::ExecuteJavaScriptURL ignores the result the
    // same way when a navigation started during the script ("replacing the
    // document would cancel the navigation"); trusted-types/
    // trusted-types-navigation.html's report-only cases depend on it.
    if (integration.ongoing_navigation != .none) return;

    // Steps 9-12: the new document's URL is the active entry's URL - a
    // javascript: URL is never a document's URL.
    const active = activeDocumentOf(integration);
    const url = documentUrlOf(active, integration.allocator) catch return endLoadDelay(integration);
    defer integration.allocator.free(url);
    // Step 11: the new document state's about base URL is oldDocState's -
    // which only an about:blank or about:srcdoc document has, and the new
    // document keeps that URL.
    if (active) |old| {
        if (document_lifecycle.aboutFallbackBaseUrl(old)) |about| {
            record.initiator_base_url = integration.allocator.dupe(u8, about) catch null;
        }
    }
    // Step 12: "Let policyContainer be targetNavigable's active document's
    // policy container" - the String's document keeps the policies of the
    // document it replaces, not its initiator's (whatever navigated it).
    // Taken before that document unloads.
    if (active) |old| {
        if (dom_module.policy_containers.of(old)) |container| {
            record.javascript_policy_container = container.clone(integration.allocator) catch null;
        }
    }
    // Step 13: "Let finalSandboxFlags be policyContainer's CSP list's
    // CSP-derived sandboxing flags". Deviation, stated (golden rule 2): the
    // replaced document's whole active sandboxing flag set, which holds
    // those and its iframe's and container's flags too. The text would let
    // a document sandboxed by its iframe's attribute (with allow-scripts,
    // without allow-same-origin: it can only navigate itself to a
    // javascript: URL) make an unsandboxed one; Blink keeps the frame's
    // sandbox flags for the new document (they are the frame's policy, not
    // the response's), as Gecko does (its docshell's sandbox flags).
    if (active) |old| record.final_sandboxing_flags = dom_module.document_scripts.activeSandboxingFlags(old);
    if (active) |old| unloadDocumentAndDescendants(old, integration);
    if (integration.state == .discarded or integration.browsing_context == null) return;
    // Step 17, handed back to runJavascriptNavigation to commit outside this
    // realm: a new document may need a new one.
    record.javascript_result = integration.allocator.dupe(u8, html) catch return endLoadDelay(integration);
    record.javascript_url = integration.allocator.dupe(u8, url) catch return endLoadDelay(integration);
}

/// Whether the URL parser parses `url` (the pre-navigation check's step 6).
fn isParsableUrl(allocator: std.mem.Allocator, url: []const u8) bool {
    var parsed = basic_parser.parse(allocator, url, null) catch return false;
    parsed.deinit();
    return true;
}

/// HTML "evaluate a javascript: URL" steps 1-10: the script is the URL after
/// "javascript:", percent-decoded, run as a classic script in the navigable's
/// realm. Its completion value, if it is a String, is the new document's
/// markup (owned); anything else - or a throw - is null.
fn evaluateJavascriptUrl(integration: *IFrameIntegration, url: []const u8) ?[]u8 {
    const allocator = integration.allocator;
    const realm = navigableContext(integration) orelse return null;
    // Step 4's settings is "targetNavigable's active document's relevant
    // settings object", and step 7 creates the classic script with it:
    // "create a classic script" step 2, "if scripting is disabled for
    // settings, then set source to the empty string" - a script whose
    // completion is undefined, never a String. So for a document sandboxed
    // without allow-scripts nothing runs and no document is made.
    if (activeDocumentOf(integration)) |active| {
        if (dom_module.document_scripts.scriptsSandboxed(active)) return null;
    }
    // Steps 1-3: strip the scheme, percent-decode.
    const encoded = url["javascript:".len..];
    const source = percentDecode(allocator, encoded) catch return null;
    defer allocator.free(source);

    // Step 7: run it (engine.evaluateClassicScript). A throw is reported, and
    // is not a String.
    const completion = engine.evaluateClassicScript(realm, .{ .utf8 = source }, "", null, .{ .report = reportException, .host = realm }) catch return null;
    defer completion.release();
    // Step 9: only a String replaces the document.
    if (engine.typeOf(realm, completion.value) != .string) return null;
    return engine.convertToDOMString(realm, completion.value, allocator) catch null;
}

fn percentDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            if (std.fmt.parseInt(u8, input[i + 1 .. i + 3], 16)) |byte| {
                try out.append(allocator, byte);
                i += 3;
                continue;
            } else |_| {}
        }
        try out.append(allocator, input[i]);
        i += 1;
    }
    return out.toOwnedSlice(allocator);
}

/// The script behind `integration.busy` is done with the integration; if its
/// element was deinited meanwhile, the deinit it put off happens now.
fn finishBusy(integration: *IFrameIntegration) void {
    integration.busy -= 1;
    if (integration.busy == 0 and integration.deinit_pending) dom_module.navigables.destroyContentNavigable(integration);
}

// ----------------------------------------------------------------------------
// Delaying the container document's load event (HTML §4.8.5)
// ----------------------------------------------------------------------------

/// The navigable stops delaying its container document's load event: its
/// navigation finished (the iframe load event steps ran) or ended without a
/// document. The container document may be waiting on it.
fn endLoadDelay(integration: *IFrameIntegration) void {
    if (!integration.delaying_load) return;
    integration.delaying_load = false;
    const element: *runtime.Instance = @ptrCast(@alignCast(integration.iframe_element orelse return));
    const NodeImpl = @import("Node.zig");
    const document = NodeImpl.getOwnerDocument(element) orelse return;
    document_lifecycle.loadDelayMayHaveEnded(document);
}

/// HTML §4.8.5: a container delays its node document when its active
/// document is not ready for post-load tasks, its navigable is delaying
/// load events, or anything delays its active document's load event.
fn iframesDelayLoadEvent(document: *runtime.Instance) bool {
    var children = dom_module.navigables.childNavigablesOf(document, std.heap.page_allocator);
    defer children.deinit(std.heap.page_allocator);
    for (children.items) |child| {
        const integration = integrationOfBrowsingContext(child.browsing_context) orelse continue;
        if (integration.delaying_load) return true;
        const active = activeDocumentOf(integration) orelse continue;
        if (!document_lifecycle.isReadyForPostLoadTasks(active) or document_lifecycle.delaysLoadEvent(active)) return true;
    }
    return false;
}

/// A resource in an active child document stopped delaying load, possibly
/// without EOF or a new navigation. Its parent rechecks all three iframe
/// delay conditions. Rechecking can run script; nothing is read afterward.
fn childLoadDelayMayHaveEnded(document: *runtime.Instance) void {
    const integration = navigableOfDocument(document) orelse return;
    const element: *runtime.Instance = @ptrCast(@alignCast(integration.iframe_element orelse return));
    const parent = interfaces.Node.get_ownerDocument(element) catch return;
    document_lifecycle.loadDelayMayHaveEnded(parent orelse return);
}

/// dom.content_navigables: `container`'s load event steps - an iframe's
/// "iframe load event steps", and for any other container with a content
/// navigable (an object or embed element) "completely finish loading" step
/// 5's load event, which ends its navigation's delay on its node document
/// (dom.navigables.containerLoadEventSteps). False for an element that has
/// no content navigable; its caller fires the load event itself.
fn contentNavigableLoadEventSteps(container: *runtime.Instance) bool {
    if (container.stateAs(State) != null) {
        runIframeLoadEventSteps(container);
        return true;
    }
    const integration = integrationOfContainer(container) orelse return false;
    dom_module.navigables.containerLoadEventSteps(container, integration);
    return true;
}

/// The live content navigable whose container is `container`.
fn integrationOfContainer(container: *runtime.Instance) ?*IFrameIntegration {
    for (live_navigables.items) |integration| {
        if (integration.iframe_element == @as(?*anyopaque, @ptrCast(container))) return integration;
    }
    return null;
}

/// dom.content_navigables: HTML "stop loading" the content navigable whose
/// active document is `document`. Only step 2's navigation cancellation is
/// conditional on unloading; step 3 always aborts the document and descendants.
fn stopLoadingDocument(document: *runtime.Instance) void {
    const generation = runtime.SlabAllocator.generationOf(document);
    const pin = engine.retainValue(document.ctx, .{ .instance = document }) catch null;
    defer if (pin) |held| held.release();
    if (navigableOfDocument(document)) |integration| {
        // Ending navigation can dispatch events which remove its frame.
        // WebKit FrameLoader::stopAllLoaders retains its frame for this call.
        integration.busy += 1;
        defer finishBusy(integration);
        if (!document_lifecycle.isUnloading(document)) switch (integration.ongoing_navigation) {
            .id => {
                setOngoingNavigation(integration, .none);
                endLoadDelay(integration);
            },
            else => {},
        };
    }
    if (runtime.SlabAllocator.generationOf(document) != generation) return;
    // "Abort a document and its descendants" steps 2-3: snapshot the
    // descendants and queue each document's global task before aborting the
    // root (step 4). Abort listeners may remove or replace descendants.
    var documents = dom_module.navigables.inclusiveDescendantDocuments(document, document.ctx.allocator);
    defer documents.deinit(document.ctx.allocator);
    const descendant_start: usize = if (documents.items.len > 0) 1 else 0;
    for (documents.items[descendant_start..]) |entry| {
        if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
        const descendant = navigableOfDocument(entry.document) orelse continue;
        const context = descendant.browsing_context orelse continue;
        html_module.document_abort.DescendantAbort.queue(document, entry.document, context.id);
    }
    document_lifecycle.abort(document);
}

/// Document.open step 8's condition, independent of Window.stop.
fn documentIsNavigating(document: *runtime.Instance) bool {
    const integration = navigableOfDocument(document) orelse return false;
    return integration.ongoing_navigation == .id;
}

/// HTML "iframe load event steps" (§4.8.5): fire load at the element - and
/// with that, its navigation no longer delays its node document's load
/// event.
///
/// The delay ends before the event and the document hears of it after: a
/// load handler that navigates the frame again sets the delay again, and
/// "that will further delay the load event" (§4.8.5) - the document's load
/// waits for that navigation too, as it does in browsers.
fn runIframeLoadEventSteps(element: *runtime.Instance) void {
    const internal = getInternal(element) orelse return;
    internal.integration.delaying_load = false;
    const realm = element.ctx;
    const had_engine = realm.hasEngine();
    const generation = runtime.SlabAllocator.generationOf(element);
    // Step 2: "Let childDocument be element's content navigable's active
    // document." (Step 1 asserts there is a content navigable; step 4,
    // resource timing, is not modelled.)
    const child_document = activeDocumentOf(internal.integration);
    // Step 3: "If childDocument has its mute iframe load flag set, then
    // return." The document was opened during an earlier load event at this
    // element (the document open steps, step 14). Its load still no longer
    // delays the container document's, below.
    const muted = if (child_document) |child| document_lifecycle.isIframeLoadMuted(child) else false;
    if (!muted) {
        // Step 5: "Set childDocument's iframe load in progress flag."
        const child_generation = if (child_document) |child| runtime.SlabAllocator.generationOf(child) else 0;
        const child_realm = if (child_document) |child| child.ctx else null;
        const child_had_engine = if (child_realm) |child_ctx| child_ctx.hasEngine() else false;
        if (child_document) |child| document_lifecycle.setIframeLoadInProgress(child, true);
        // Step 6: "Fire an event named load at element."
        fireLoadEventOnIframe(element);
        // Step 7: "Unset childDocument's iframe load in progress flag." The
        // handlers may have navigated the frame and dropped the document.
        if (child_document) |child| {
            if ((!child_had_engine or child_realm.?.hasEngine()) and runtime.SlabAllocator.generationOf(child) == child_generation) {
                document_lifecycle.setIframeLoadInProgress(child, false);
            }
        }
    }
    // The handlers may have taken the element away.
    if ((had_engine and !realm.hasEngine()) or runtime.SlabAllocator.generationOf(element) != generation) return;
    // Written resource delays can end with no navigation delay flag set.
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    document_lifecycle.loadDelayMayHaveEnded(document);
}

// ----------------------------------------------------------------------------
// Choosing a navigable by target name, and following hyperlinks
// ----------------------------------------------------------------------------

/// A navigable "the rules for choosing a navigable" can land on.
const Chosen = union(enum) {
    /// A frame's or popup's navigable.
    navigable: *IFrameIntegration,
    /// The top-level page: a document no integration holds.
    page: *runtime.Instance,
    /// None: a new top-level traversable is requested.
    none,
};

/// `document`'s navigable, as a `Chosen`.
fn chosenOf(document: *runtime.Instance) Chosen {
    if (navigableOfDocument(document)) |integration| return .{ .navigable = integration };
    return .{ .page = document };
}

/// The container document of `document`'s navigable - its parent's active
/// document - or null for a top-level one (the page, or a popup).
fn parentDocumentOf(document: *runtime.Instance) ?*runtime.Instance {
    const integration = navigableOfDocument(document) orelse return null;
    const element: *runtime.Instance = @ptrCast(@alignCast(integration.iframe_element orelse return null));
    const NodeImpl = @import("Node.zig");
    return NodeImpl.getOwnerDocument(element);
}

/// The active document of `document`'s top-level traversable.
fn topDocumentOf(document: *runtime.Instance) *runtime.Instance {
    var current = document;
    var depth: usize = 0;
    while (depth < 64) : (depth += 1) {
        current = parentDocumentOf(current) orelse return current;
    }
    return current;
}

/// HTML "find a navigable by target name": a navigable whose target name is
/// `name` among the inclusive descendant navigables of `document`'s
/// top-level traversable (the implementation-defined subtree choice of step
/// 3). Popups are searched by the window open steps, which the caller falls
/// back to.
fn findNavigableByName(document: *runtime.Instance, name: []const u8) ?*IFrameIntegration {
    const top = topDocumentOf(document);
    var documents = dom_module.navigables.inclusiveDescendantDocuments(top, std.heap.page_allocator);
    defer documents.deinit(std.heap.page_allocator);
    for (documents.items) |entry| {
        const browsing_context = entry.browsing_context orelse continue;
        if (!std.mem.eql(u8, browsing_context.target_name, name)) continue;
        if (integrationOfBrowsingContext(browsing_context)) |integration| return integration;
    }
    return null;
}

/// dom.navigables: "find a navigable by target name" among the frames of
/// `current_document`'s page - the active window of the first found, or null.
fn frameWindowByName(current_document: *runtime.Instance, name: []const u8) ?*runtime.Instance {
    const integration = findNavigableByName(current_document, name) orelse return null;
    const browsing_context = integration.browsing_context orelse return null;
    return @ptrCast(@alignCast(browsing_context.getActiveWindow() orelse return null));
}

/// dom.navigables: HTML "the rules for choosing a navigable" given
/// `request.target` for `source_document`'s node navigable, then "navigate"
/// the chosen one to `request.url` using `source_document`.
///
/// A new top-level traversable ("_blank", a name nothing has, noopener) is
/// made by the window open steps, which also find a popup by name. Deviation,
/// stated: the top-level page cannot be replaced - navigating it does only
/// what its Location can (a fragment navigation).
fn navigateByTarget(source_document: *runtime.Instance, request: dom_module.navigables.Request) void {
    navigateByTargetWithReferrerPolicy(source_document, request, if (request.noreferrer) .no_referrer else .empty);
}

/// `navigateByTarget`, with navigate's referrerPolicy - a hyperlink's. It
/// reaches a frame's navigation; a page's top-level navigation and a new
/// popup do not carry it yet (stated).
fn navigateByTargetWithReferrerPolicy(source_document: *runtime.Instance, request: dom_module.navigables.Request, referrer_policy: fetch_mod.internal.ReferrerPolicy) void {
    const name = request.target;
    // "The rules for choosing a navigable" start from currentNavigable: the
    // source document's, unless the caller names another.
    const current = request.current_document orelse source_document;
    // Steps 4-7.
    const chosen: Chosen = blk: {
        if (name.len == 0 or std.ascii.eqlIgnoreCase(name, "_self")) break :blk chosenOf(current);
        if (std.ascii.eqlIgnoreCase(name, "_parent")) {
            break :blk chosenOf(parentDocumentOf(current) orelse current);
        }
        if (std.ascii.eqlIgnoreCase(name, "_top")) break :blk chosenOf(topDocumentOf(current));
        // Step 7: "find a navigable by target name", whatever noopener is
        // (a rel=noreferrer link navigates the frame its target names).
        if (!std.ascii.eqlIgnoreCase(name, "_blank")) {
            if (findNavigableByName(current, name)) |integration| break :blk .{ .navigable = integration };
        }
        break :blk .none;
    };
    switch (chosen) {
        .navigable => |integration| {
            var behavior: navigate_steps.HistoryBehavior = switch (request.history_behavior) {
                .auto => .auto,
                .push => .push,
                .replace => .replace,
            };
            if (request.source_not_completely_loaded and activeDocumentOf(integration) == source_document) behavior = .replace;
            navigate(integration, request.url, .{
                .source_document = source_document,
                .history_behavior = behavior,
                .source_element = request.source_element,
                .user_involvement = request.user_involvement,
                .navigation_api_state = request.navigation_api_state,
                .post_resource = request.post_resource,
                .form_data = request.form_data,
                .referrer_policy = referrer_policy,
                .csp_navigation_type = request.csp_navigation_type,
            });
        },
        .page => |page| {
            const window = (interfaces.Document.get_defaultView(page) catch null) orelse return;
            // The page's Location installs its navigate.
            if (!dom_module.top_level_navigation.isInstalled()) _ = interfaces.Window.get_location(window) catch return;
            var behavior: dom_module.top_level_navigation.HistoryBehavior = switch (request.history_behavior) {
                .auto => .auto,
                .push => .push,
                .replace => .replace,
            };
            if (request.source_not_completely_loaded and page == source_document) behavior = .replace;
            dom_module.top_level_navigation.navigate(window, request.url, .{
                .history_behavior = behavior,
                .source_document = source_document,
                .source_element = request.source_element,
                .user_involvement = request.user_involvement,
                .navigation_api_state = request.navigation_api_state,
                .form_data = if (request.post_resource != null) request.form_data else null,
                .csp_navigation_type = request.csp_navigation_type,
            });
        },
        // Step 7's popups of the page's browsing context group, else step 8:
        // a new top-level traversable - Window keeps both - navigated as the
        // hyperlink or form asks, with its POST resource, referrer policy and
        // source element (a form submitted to "_blank" POSTs to the new
        // window).
        .none => {
            const window = (interfaces.Document.get_defaultView(current) catch null) orelse return;
            const chosen_top = dom_module.auxiliary_navigables.chooseTopLevel(window, name, request.noopener) orelse return;
            const integration: *IFrameIntegration = @ptrCast(@alignCast(chosen_top.integration));
            navigate(integration, request.url, .{
                .source_document = source_document,
                .source_element = request.source_element,
                .user_involvement = request.user_involvement,
                .navigation_api_state = request.navigation_api_state,
                .post_resource = request.post_resource,
                .form_data = request.form_data,
                .referrer_policy = referrer_policy,
                .csp_navigation_type = request.csp_navigation_type,
            });
        },
    }
}

/// dom.navigables: HTML "follow the hyperlink created by" `subject`, an `a`
/// or `area` element (4.6.4), with no hyperlink suffix.
///
/// Not modelled, stated: blob URL entries (step 6's noopener for a blob:
/// URL).
fn followHyperlink(subject: *runtime.Instance, user_involvement: dom_module.navigation_api.UserInvolvement) void {
    const document = (interfaces.Node.get_ownerDocument(subject) catch null) orelse return;
    // Step 1: "If subject cannot navigate, then return": its node document is
    // not fully active (it has no Window), or it is not an a element and not
    // connected.
    if ((interfaces.Document.get_defaultView(document) catch null) == null) return;
    const is_anchor = subject.stateAs(interfaces.HTMLAnchorElement.State) != null;
    if (!is_anchor and !(interfaces.Node.get_isConnected(subject) catch false)) return;

    // Steps 2-3: "get an element's target" - its target attribute, else the
    // document's first base element with one; "if target is not null, and
    // contains an ASCII tab or newline and a U+003C (<), then set target to
    // "_blank"" (dangling markup).
    const target_attr = interfaces.Element.call_getAttribute(subject, runtime.DOMString.initInterned("target")) catch null;
    const given_target: []const u8 = if (target_attr) |t| t.asSlice() else baseTarget(document);
    const dangling = std.mem.indexOfAny(u8, given_target, "\t\n\r") != null and std.mem.indexOfScalar(u8, given_target, '<') != null;
    const target: []const u8 = if (dangling) "_blank" else given_target;

    // Steps 4-5: the URL, encoding-parsed relative to the node document. An
    // SVG a takes it from its href attribute, falling back to the XLink
    // namespace's href only when href is absent (SVG 2) - an empty href
    // still wins.
    const href = (interfaces.Element.call_getAttribute(subject, runtime.DOMString.initInterned("href")) catch null) orelse
        (if (subject.stateAs(interfaces.HTMLElement.State) == null)
            interfaces.Element.call_getAttributeNS(subject, runtime.DOMString.initInterned("http://www.w3.org/1999/xlink"), runtime.DOMString.initInterned("href")) catch null
        else
            null) orelse return;
    const url = parseRelativeToDocument(document, href.asSlice()) orelse return;
    defer document.ctx.allocator.free(url);

    // Step 6: "get an element's noopener".
    const rel = interfaces.Element.call_getAttribute(subject, runtime.DOMString.initInterned("rel")) catch null;
    const rel_value: []const u8 = if (rel) |r| r.asSlice() else "";
    const noopener = hasLinkType(rel_value, "noopener") or hasLinkType(rel_value, "noreferrer") or
        (!hasLinkType(rel_value, "opener") and std.ascii.eqlIgnoreCase(target, "_blank"));

    // Step 11's referrerPolicy: subject's hyperlink referrer policy -
    // "no-referrer" when its link types include noreferrer, else the current
    // state of its referrerpolicy content attribute.
    const referrer_policy: fetch_mod.internal.ReferrerPolicy = if (hasLinkType(rel_value, "noreferrer")) .no_referrer else blk: {
        const attr = interfaces.Element.call_getAttribute(subject, runtime.DOMString.initInterned("referrerpolicy")) catch null;
        break :blk fetch_mod.internal.policy_container.referrerPolicyFromAttribute(if (attr) |a| a.asSlice() else null);
    };

    // Steps 7-11: navigate with the given user involvement.
    navigateByTargetWithReferrerPolicy(document, .{ .target = target, .url = url, .noopener = noopener, .source_element = subject, .user_involvement = user_involvement }, referrer_policy);
}

/// HTML "download the hyperlink" created by `subject` (an `a` or `area`
/// element with a download attribute), with no hyperlink suffix.
fn downloadHyperlink(subject: *runtime.Instance, user_involvement: dom_module.navigation_api.UserInvolvement) void {
    const document = (interfaces.Node.get_ownerDocument(subject) catch null) orelse return;
    // Step 1: "If subject cannot navigate, then return."
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return;
    const is_anchor = subject.stateAs(interfaces.HTMLAnchorElement.State) != null;
    if (!is_anchor and !(interfaces.Node.get_isConnected(subject) catch false)) return;
    // Step 2: "If subject's node document's active sandboxing flag set has
    // the sandboxed downloads browsing context flag set, then return."
    if (dom_module.document_scripts.activeSandboxingFlags(document).downloads) return;
    // Steps 3-4: "Let urlString be the result of encoding-parsing-and-
    // serializing a URL given subject's href attribute value, relative to
    // subject's node document. If urlString is failure, then return."
    const href = (interfaces.Element.call_getAttribute(subject, runtime.DOMString.initInterned("href")) catch null) orelse return;
    const url = parseRelativeToDocument(document, href.asSlice()) orelse return;
    defer document.ctx.allocator.free(url);
    // Step 6: not "browser UI": the download request navigate event, with
    // the download attribute's value as its filename.
    if (user_involvement != .browser_ui) {
        const filename = (interfaces.Element.call_getAttribute(subject, runtime.DOMString.initInterned("download")) catch null) orelse runtime.DOMString.initEmpty();
        // 6.4-6.5: "If continue is false, then return."
        if (!dom_module.navigation_api.fireDownloadRequest(window, url, user_involvement, subject, filename.asSlice())) return;
        // 6.6: "Inform the navigation API about aborting navigation given
        // subject's node navigable."
        dom_module.navigation_api.informAboutAbortingNavigation(window);
    }
    // Steps 7-9 (fetch the URL and "handle as a download") are not modelled,
    // stated: Crane has no download manager, so the request is never made and
    // nothing is saved - the step 7 option ("the user agent may return")
    // taken for every download.
}

/// The target of the first base element in `document`, in tree order, that
/// has a target attribute, or "" (HTML "get an element's target" step 2).
/// BORROWED from the base element's attribute.
fn baseTarget(document: *runtime.Instance) []const u8 {
    const base = (interfaces.Document.call_querySelector(document, runtime.DOMString.initInterned("base[target]")) catch null) orelse return "";
    const value = (interfaces.Element.call_getAttribute(base, runtime.DOMString.initInterned("target")) catch null) orelse return "";
    return value.asSlice();
}

/// Whether the space-separated `value` (a rel attribute) has the link type
/// `keyword`, ASCII case-insensitively.
fn hasLinkType(value: []const u8, keyword: []const u8) bool {
    var tokens = std.mem.tokenizeAny(u8, value, " \t\n\r\x0c");
    while (tokens.next()) |token| {
        if (std.ascii.eqlIgnoreCase(token, keyword)) return true;
    }
    return false;
}

/// `url` parsed relative to `document`'s base URL and serialized, owned by
/// the document's context allocator; null when it does not parse.
fn parseRelativeToDocument(document: *runtime.Instance, url: []const u8) ?[]const u8 {
    const base = interfaces.Node.get_baseURI(document) catch return null;
    defer document.ctx.allocator.free(base);
    const base_arg = if (base.len > 0)
        webidl.Opt(runtime.USVString).passed(base)
    else
        webidl.Opt(runtime.USVString).notPassed();
    const parsed = (interfaces.URL.call_static_parse(document, url, base_arg) catch null) orelse return null;
    defer runtime.Instance.deinit(parsed);
    return interfaces.URL.get_href(parsed) catch null;
}

// ----------------------------------------------------------------------------
// Entry points
// ----------------------------------------------------------------------------

/// IFrameIntegration's navigate hook - window.open()'s navigation of a
/// popup, and any caller without engine access.
fn navigateFromIntegration(integration: *IFrameIntegration, url: []const u8, request: html_core.window.iframe_integration.NavigateRequest) void {
    navigate(integration, url, .{
        .source_document = if (request.source_document) |d| @ptrCast(@alignCast(d)) else null,
        .history_behavior = request.history_behavior,
        .referrer_policy = request.referrer_policy,
    });
}

/// Location's navigate callback: HTML "Location-object navigate" steps 3-4,
/// for a frame's or popup's Location. Step 3 - a relevant document that is
/// not completely loaded makes it a replace - is read here, from the
/// navigable's own record of its document.
fn navigateFromLocation(ctx: ?*anyopaque, url: []const u8, request: html_core.window.iframe_integration.NavigateRequest) bool {
    const integration: *IFrameIntegration = @ptrCast(@alignCast(ctx orelse return false));
    if (integration.browsing_context == null or integration.state == .discarded) return false;
    // A refused top-level navigation (html.user_activation.topNavigationBlocked)
    // throws a SecurityError at script, as WebKit's Location::setLocation and
    // Gecko's do; navigate() would refuse it silently.
    const source: ?*runtime.Instance = if (request.source_document) |d| @ptrCast(@alignCast(d)) else null;
    if (html_module.user_activation.topNavigationBlocked(source, integration.browsing_context.?, url)) return false;
    // Navigate step 6.2.1: "If exceptionsEnabled is true, then throw a
    // SecurityError" - a Location navigation's are.
    if (html_module.user_activation.sandboxBlocksNavigation(source, integration.browsing_context.?)) return false;
    var behavior = request.history_behavior;
    if (activeDocumentOf(integration)) |document| {
        // Step 3: "If location's relevant Document is not yet completely
        // loaded, and the incumbent global object does not have transient
        // activation, then set historyHandling to "replace"."
        if (!document_lifecycle.isCompletelyLoaded(document) and !html_module.user_activation.incumbentHasTransientActivation()) behavior = .replace;
    }
    navigate(integration, url, .{
        .source_document = if (request.source_document) |d| @ptrCast(@alignCast(d)) else null,
        .history_behavior = behavior,
    });
    return true;
}

/// HTML "process the iframe attributes" (§4.8.5).
///
/// Lazy loading (steps 1.1-1.2 and 2.5-2.6) is not modelled: every frame
/// loads eagerly.
fn processIframeAttributes(element: *runtime.Instance, initial_insertion: bool) void {
    const internal = getInternal(element) orelse return;
    const ElementImpl = @import("Element.zig");
    // Step 1: "If element's srcdoc attribute is specified" - navigate to the
    // srcdoc resource.
    if (ElementImpl.call_getAttribute(element, runtime.DOMString.initInterned("srcdoc")) catch null) |srcdoc| {
        const markup = internal.allocator.dupe(u8, srcdoc.asSlice()) catch return;
        defer internal.allocator.free(markup);
        navigateIframeOrFrame(element, "about:srcdoc", markup, initial_insertion);
        return;
    }
    // Step 2.1: the shared attribute processing steps.
    const url = sharedAttributeProcessingSteps(element) orelse return;
    defer element.ctx.allocator.free(url);
    // Step 2.3: a URL that matches about:blank, on initial insertion, is not
    // navigated to: the frame keeps its initial about:blank document - whose
    // window never sees load or pageshow - and only the iframe load event
    // steps run.
    if (navigate_steps.matchesAboutBlank(url) and initial_insertion) {
        runIframeLoadEventSteps(element);
        return;
    }
    // Step 2.7: navigate.
    navigateIframeOrFrame(element, url, null, initial_insertion);
}

/// HTML "shared attribute processing steps for iframe and frame elements":
/// the src URL (owned by the element's context allocator), about:blank when
/// src is absent, empty or does not parse, or null when two inclusive
/// ancestor navigables already show it (step 3: no infinite nesting - see
/// ancestorShows for the one level engines allow).
/// Step 4 (URL and history update steps for about:blank?query) is not
/// modelled.
fn sharedAttributeProcessingSteps(element: *runtime.Instance) ?[]const u8 {
    const ElementImpl = @import("Element.zig");
    const src = ElementImpl.call_getAttribute(element, runtime.DOMString.initInterned("src")) catch null;
    const value: []const u8 = if (src) |s| s.asSlice() else "";
    const url = resolveSrc(element, value);
    if (ancestorShows(element, url)) {
        element.ctx.allocator.free(url);
        return null;
    }
    return url;
}

/// Step 3: whether `url` would nest a document inside itself too deeply -
/// whether TWO navigables among `element`'s node navigable and its
/// ancestors show a document whose URL equals `url` without fragments.
///
/// Deviation, on purpose: the spec refuses the first match (any inclusive
/// ancestor showing `url` returns null). The shipping engines allow one
/// level of self-reference and refuse the second: WebKit's
/// HTMLFrameOwnerElement::isProhibitedSelfReference ("We allow one level of
/// self-reference because some websites depend on that, but we don't allow
/// more than one"), Blink's frame URL check the same way (wpt.fyi's Edge
/// run of src-repeated-in-ancestor.html is 1/4, as Crane's is), and Gecko's
/// nsFrameLoader::CheckForRecursiveLoad (MAX_SAME_URL_CONTENT_FRAMES 2).
/// WPT relies on it - the feature-policy helpers embed the test page in
/// itself, and xhr/xmlhttprequest-sync-default-feature-policy.sub.html hung
/// under the literal rule.
///
/// The known cost: html/semantics/embedded-content/the-iframe-element/
/// src-repeated-in-ancestor.html tests the literal rule, and three of its
/// four subtests (an iframe set to the page's own URL, with or without a
/// fragment, directly or through an intermediate frame) fail here as they
/// do in Blink. No whatwg/html issue on the difference was found
/// (2026-09-29).
fn ancestorShows(element: *runtime.Instance, url: []const u8) bool {
    if (navigate_steps.matchesAboutBlank(url)) return false;
    const NodeImpl = @import("Node.zig");
    var document = NodeImpl.getOwnerDocument(element);
    var depth: usize = 0;
    var found_one_self_reference = false;
    while (document) |doc| : (depth += 1) {
        if (depth > 32) return false;
        const doc_url = documentUrlOf(doc, element.ctx.allocator) catch return false;
        defer element.ctx.allocator.free(doc_url);
        if (navigate_steps.equalsExcludingFragments(doc_url, url)) {
            if (found_one_self_reference) return true;
            found_one_self_reference = true;
        }
        const window = (interfaces.Document.get_defaultView(doc) catch null) orelse return false;
        const container = dom_module.navigable_container.of(window) orelse return false;
        document = NodeImpl.getOwnerDocument(container);
    }
    return false;
}

/// HTML "navigate an iframe or frame" (§4.8.5) for an iframe element.
fn navigateIframeOrFrame(element: *runtime.Instance, url: []const u8, srcdoc: ?[]const u8, initial_insertion: bool) void {
    const internal = getInternal(element) orelse return;
    navigateContainer(element, internal.integration, url, srcdoc, initial_insertion);
}

/// dom.navigables: HTML "process the frame attributes" (16.3.2) for the
/// frame element `element`, whose content navigable is `integration`.
fn processFrameAttributes(element: *runtime.Instance, integration: *IFrameIntegration, initial_insertion: bool) void {
    if (integration.state == .discarded or integration.browsing_context == null) return;
    // Step 1: "Let url be the result of running the shared attribute
    // processing steps for iframe and frame elements given element and
    // initialInsertion." Step 2: "If url is null, then return."
    const url = sharedAttributeProcessingSteps(element) orelse return;
    defer element.ctx.allocator.free(url);
    // Step 3: "If url matches about:blank and initialInsertion is true: fire
    // an event named load at element" - the frame keeps its initial
    // about:blank document, and with the event its navigable no longer
    // delays its node document's load.
    if (navigate_steps.matchesAboutBlank(url) and initial_insertion) {
        dom_module.navigables.containerLoadEventSteps(element, integration);
        return;
    }
    // Step 4: "Navigate an iframe or frame given element, url, the empty
    // string, null, and initialInsertion."
    navigateContainer(element, integration, url, null, initial_insertion);
}

/// HTML "navigate an iframe or frame" (§4.8.5) for `element`, an iframe or
/// frame element whose content navigable is `integration`.
fn navigateContainer(element: *runtime.Instance, integration: *IFrameIntegration, url: []const u8, srcdoc: ?[]const u8, initial_insertion: bool) void {
    // Step 1: "Let historyHandling be "auto"."
    var behavior: navigate_steps.HistoryBehavior = .auto;
    // Step 2: "If element's content navigable's active document is not
    // completely loaded, then set historyHandling to "replace"."
    if (activeDocumentOf(integration)) |document| {
        if (!document_lifecycle.isCompletelyLoaded(document)) behavior = .replace;
    }
    // Deviation, stated, matching Chrome and Safari (crbug.com/1248444;
    // navigate-cross-origin-iframe-to-same-url-with-fragment-fire-load-event):
    // a fragment navigation of a cross-origin frame through its element
    // fires the element's load event, as a cross-document one would - its
    // absence would tell the container that the frame is still on that URL.
    const NodeImpl = @import("Node.zig");
    const container_document = NodeImpl.getOwnerDocument(element);
    const load_for_fragment = crossOriginFragmentNavigation(integration, container_document, url, srcdoc != null);
    // Step 3: "Let referrerPolicy be the current state of element's
    // referrerpolicy content attribute."
    const referrer_attr = interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("referrerpolicy")) catch null;
    const referrer_policy = fetch_mod.internal.policy_container.referrerPolicyFromAttribute(if (referrer_attr) |a| a.asSlice() else null);
    // Step 4: navigate, using element's node document.
    navigate(integration, url, .{
        .source_document = container_document,
        .history_behavior = behavior,
        .srcdoc = srcdoc,
        .initial_insertion = initial_insertion,
        .referrer_policy = referrer_policy,
    });
    if (load_for_fragment) queueIframeLoadEventSteps(element);
}

/// Whether navigating `integration`'s navigable to `url` from its container
/// document is a fragment navigation of a document of another origin.
fn crossOriginFragmentNavigation(integration: *IFrameIntegration, container_document: ?*runtime.Instance, url: []const u8, has_resource: bool) bool {
    const active = activeDocumentOf(integration) orelse return false;
    const container = container_document orelse return false;
    const active_url = documentUrlOf(active, integration.allocator) catch return false;
    defer integration.allocator.free(active_url);
    if (!navigate_steps.isFragmentNavigation(url, active_url, has_resource)) return false;
    const container_url = documentUrlOf(container, integration.allocator) catch return false;
    defer integration.allocator.free(container_url);
    // Only two tuple origins are compared: an about:blank or srcdoc
    // document's is inherited, and counts as its container's.
    const a = tupleOriginOf(active_url) orelse return false;
    const b = tupleOriginOf(container_url) orelse return false;
    return !std.mem.eql(u8, a, b);
}

/// The iframe load event steps for `element`, in a task.
fn queueIframeLoadEventSteps(element: *runtime.Instance) void {
    const timer = element.ctx.getOptionalTimer() orelse return;
    const Task = struct {
        element: *runtime.Instance,
        generation: u64,
        allocator: std.mem.Allocator,
        fn run(data: ?*anyopaque) void {
            const task: *@This() = @ptrCast(@alignCast(data orelse return));
            defer task.allocator.destroy(task);
            if (runtime.SlabAllocator.generationOf(task.element) != task.generation) return;
            runIframeLoadEventSteps(task.element);
        }
    };
    const task = element.ctx.allocator.create(Task) catch return;
    task.* = .{ .element = element, .generation = runtime.SlabAllocator.generationOf(element), .allocator = element.ctx.allocator };
    if (timer.setTimeout(0, Task.run, task) == 0) task.allocator.destroy(task);
}

/// Fire a load event on the iframe element.
/// Per HTML spec §4.8.5, this is the "iframe load event steps" algorithm:
/// 1. Assert: element's content navigable is not null.
/// 2. Let childDocument be element's content navigable's active document.
/// 3. If childDocument has its mute iframe load flag set, then return.
/// 4. Fire an event named "load" at element.
///
/// For about:blank documents, the load event fires synchronously after
/// the document is created since there are no resources to fetch.
fn fireLoadEventOnIframe(instance: *runtime.Instance) void {
    const ctx = instance.ctx;

    // Create the Event instance via constructor (like JavaScript's new Event('load'))
    // Per HTML spec, load events on iframe elements do NOT bubble
    const Event = interfaces.Event;
    const event_type = runtime.DOMString.initInterned("load");

    // EventInit: bubbles=false, cancelable=false
    const event_init = dictionaries.EventInit{
        .bubbles = false,
        .cancelable = false,
        .composed = false,
    };

    const event = Event.call_constructor(ctx, event_type, webidl.Opt(dictionaries.EventInit).passed(event_init)) catch return;
    // Not `defer deinit`: a listener can keep the event -
    // `await new Promise(r => iframe.addEventListener("load", r))` resolves
    // with it - and its wrapper then owns it.
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);

    // Dispatch the event on the iframe element
    // HTMLIFrameElement inherits from HTMLElement -> Element -> Node -> EventTarget
    _ = @import("dom").fire_event.dispatchTrusted(instance, event) catch return;
}

/// Getter for contentWindow
/// HTML "content window": the content navigable's active WindowProxy, or null
/// when the element has no content navigable.
///
/// The navigable is made by the element's post-connection steps. One that
/// never ran them - an element connected before any iframe existed to
/// register them - gets one here, without its attributes processed.
///
/// Phase 4 (Window-as-V8-Global): The Window instance IS bound to the V8 global
/// object, enabling proper cross-realm access:
/// - `iframe.contentWindow.DOMRectReadOnly` returns the constructor
/// - `iframe.contentWindow === iframe.contentWindow.window` is true
/// - Cross-realm toJSON tests pass (result objects use the method's realm)
pub fn get_contentWindow(instance: *runtime.Instance) anyerror!?typedefs.WindowProxy {
    const internal = getInternal(instance) orelse return null;

    // HTML "content window": null when the element has no content
    // navigable. A disconnected element has none - except while its removing
    // steps run: the frame's documents are unloaded before "destroy a child
    // navigable", and their pagehide and unload handlers still reach the
    // frame's window through the element, as in every browser.
    if (internal.integration.state == .discarded) return null;
    const NodeImpl = @import("Node.zig");
    const is_connected = NodeImpl.get_isConnected(instance) catch false;
    if (!is_connected) {
        if (!internal.integration.hasRealmContext()) return null;
        if (navigableContext(internal.integration)) |realm| {
            if (windowOfRealm(realm)) |window| return window;
        }
        return null;
    }

    if (!internal.integration.hasRealmContext()) {
        if (!createChildNavigable(instance)) {
            if (internal.integration.getContentWindow()) |proxy| return @ptrCast(proxy);
            return null;
        }
    }

    // Return the Window of the navigable's realm. The Window IS bound to the
    // realm's global, so accessing properties on it (like DOMRectReadOnly)
    // works correctly for cross-realm scenarios.
    if (navigableContext(internal.integration)) |realm| {
        if (windowOfRealm(realm)) |window| {
            // WindowProxy typedef is *runtime.Instance
            return window;
        }
    }

    // Fall back to old WindowProxy behavior if no Window instance available
    if (internal.integration.getContentWindow()) |proxy| {
        return @ptrCast(proxy);
    }
    return null;
}

/// HTML "create a new child navigable" for `instance` (dom.navigables): a
/// browsing context in its node document's navigable, and a realm with a
/// Window and the initial about:blank document. False when the element's
/// node document has no browsing context - a document made by
/// createHTMLDocument() or DOMParser has no navigable to be the parent - or
/// creation failed.
fn createChildNavigable(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return dom_module.navigables.createChildNavigable(instance, internal.integration);
}

/// dom.navigables' `create_browsing_context_and_document`: "create a new
/// child navigable" step 3 for `container` - any navigable container - whose
/// content navigable is `integration`'s: the browsing context, a child of the
/// container document's, and its realm, Window and initial about:blank
/// document, with `container` as the navigable's container.
fn createBrowsingContextAndDocument(container: *runtime.Instance, integration: *IFrameIntegration) bool {
    const NodeImpl = @import("Node.zig");
    const DocumentImpl = @import("Document.zig");

    // The parent is the window of the element's node document - for a frame
    // nested in another frame's document, that frame's window - and the
    // parent realm is that window's.
    const owner_doc = NodeImpl.getOwnerDocument(container) orelse return false;
    const parent_window: *runtime.Instance = (DocumentImpl.get_defaultView(owner_doc) catch null) orelse return false;
    const WindowImpl = @import("Window.zig");
    const parent_window_internal = WindowImpl.getInternal(parent_window) orelse return false;

    // The container document's origin, for same-origin checks on
    // contentDocument. The Window stores its origin as a string (e.g.,
    // "http://localhost:8000").
    const parent_origin_str = parent_window_internal.origin;
    const parent_origin = dom_module.navigables.parseOriginFromString(parent_origin_str);
    integration.container_origin = parent_origin;

    // The browsing context, a child of the container document's.
    const existing_bc = integration.ensureBrowsingContext(
        @ptrCast(parent_window_internal.browsing_context),
    ) orelse return false;
    // This element is the new navigable's container.
    existing_bc.container = container;

    // This element is the navigable's container: its load event steps run
    // once a navigation completes.
    integration.iframe_element = @ptrCast(container);

    // "Create a new browsing context and document" step 3: "Let sandboxFlags
    // be the result of determining the creation sandboxing flags given
    // browsingContext and embedder" - the element's iframe sandboxing flag
    // set united with its node document's active one, so a frame in a
    // sandboxed document is sandboxed as much. They are the initial
    // about:blank document's active sandboxing flag set (step 15), and with
    // the sandboxed origin browsing context flag its origin is opaque (step
    // 12, "determining the origin") - decided before the context exists,
    // since V8's security token is set as it is created.
    const creation_flags = creationSandboxingFlagsOf(integration);
    const use_opaque_origin = creation_flags.origin;
    integration.setNextSandboxingFlags(creation_flags);
    defer integration.setNextSandboxingFlags(.empty);

    // The navigable's context, Window and initial about:blank document,
    // whose creator is the element's node document.
    _ = attachNavigableContext(
        integration,
        parent_window.ctx,
        existing_bc,
        if (use_opaque_origin) null else parent_origin_str,
        NodeImpl.getOwnerDocument(container),
        integration.allocator,
    ) orelse return false;
    return true;
}

/// A navigable's V8 context, Window and initial about:blank document, wired to
/// `integration`: an iframe's content navigable, or window.open()'s auxiliary
/// one. The Window's origin is `origin`; null leaves it opaque. The realm's
/// parent is `parent`, whose end ends it.
fn attachNavigableContext(
    integration: *IFrameIntegration,
    parent: runtime.Context,
    browsing_context: *html_core.BrowsingContext,
    origin: ?[]const u8,
    creator: ?*runtime.Instance,
    allocator: std.mem.Allocator,
) ?runtime.Context {
    // HTML 8.1.3.5 for the initial about:blank document: its creator's
    // answer - the parent's for a frame, the opener's for a popup (`parent`
    // is the opener's realm then) - as html.secure_context.ofDocument has it.
    const realm = attachRealm(integration, parent, browsing_context, origin, .new_window_proxy, parent.secure_context, allocator) orelse return null;

    // "Create a new browsing context and document" step 4: "If creator is
    // non-null, then set creatorBaseURL to creator's document base URL" -
    // the initial about:blank document's about base URL.
    if (creator) |document| {
        const base = documentBaseUrl(document, allocator);
        defer if (base) |b| allocator.free(b);
        integration.setNextAboutBaseUrl(base);
    }
    defer integration.setNextAboutBaseUrl(null);

    // "Create a new browsing context and document": the initial about:blank
    // document's origin is "the result of determining the origin given
    // about:blank, sandboxFlags, and creatorOrigin" - a new opaque origin
    // when sandboxed (`origin` is null then), else creator's origin itself,
    // shared: a domain set through either document is both documents'
    // (windows/document-domain-nested-set.window.js). With no creator, an
    // origin of its own.
    integration.setNextOrigin(initialDocumentOrigin(origin, creator, allocator));
    defer integration.setNextOrigin(null);

    // Create the initial about:blank Document for the iframe.
    // Per HTML spec §7.5.1, every browsing context has an active document.
    // For about:blank, the document is created immediately when the browsing
    // context is created, not through navigation.
    // HTML "create a new browsing context and document" step 15: this
    // document "is initial about:blank"; step 21 completely finishes loading
    // it.
    if (createDocumentForIframe(@ptrCast(realm), browsing_context)) |document_ptr| {
        const document: *runtime.Instance = @ptrCast(@alignCast(document_ptr));
        dom_module.document_lifecycle.markInitialAboutBlank(document);
        if (creator) |creator_document| {
            // Step 19.1: "Set document's referrer to the serialization of
            // creator's URL."
            if (interfaces.Document.get_URL(creator_document)) |creator_url| {
                defer creator_document.ctx.allocator.free(creator_url);
                document_internals.setReferrer(document, creator_url) catch {};
            } else |_| {}
            // Step 19.2: "Set document's policy container to a clone of
            // creator's policy container."
            inheritPolicyContainer(document, creator_document);
        }
    }
    return realm;
}

/// The origin record an initial about:blank document is made with (one
/// reference, or null for an origin of its own): a new opaque origin for a
/// navigable whose Window is opaque (`window_origin` null: sandboxed without
/// allow-same-origin), else its creator's.
fn initialDocumentOrigin(window_origin: ?[]const u8, creator: ?*runtime.Instance, allocator: std.mem.Allocator) ?*OriginRecord {
    if (window_origin == null) return OriginRecord.create(allocator, "null") catch null;
    const document = creator orelse return null;
    const record = (dom_module.document_origin.shareable(document) catch null) orelse return null;
    return record.retain();
}

/// Give `document` a clone of `from`'s policy container (HTML "clone a
/// policy container"): an initial about:blank document's creator's, a
/// srcdoc document's parent's, a local URL's initiator's.
fn inheritPolicyContainer(document: *runtime.Instance, from: *runtime.Instance) void {
    const source = dom_module.policy_containers.of(from) orelse return;
    const clone = source.clone(document.ctx.allocator) catch return;
    dom_module.policy_containers.set(document, clone);
}

/// A realm for `integration`'s navigable (engine.createWindowRealm with
/// `parent`), with a Window bound to its global - built around the
/// navigable's WindowProxy when `global_this` names the realm a navigation
/// replaces - wired to the integration and made the browsing context's
/// active window. No document: the caller makes that.
fn attachRealm(
    integration: *IFrameIntegration,
    parent: runtime.Context,
    browsing_context: *html_core.BrowsingContext,
    origin: ?[]const u8,
    global_this: engine.GlobalThis,
    secure_context: bool,
    allocator: std.mem.Allocator,
) ?runtime.Context {
    // HTML "create a new realm", made while the parent's script may be
    // running: its timers and event loop are the parent's.
    var frame_window: FrameWindow = .{ .browsing_context = browsing_context, .allocator = allocator };
    const agent = parent.agent orelse return null;
    const realm = engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = allocator,
        .from_snapshot = true,
        .timer = parent.timer,
        .event_loop = parent.event_loop,
        .origin = origin,
        .global_this = global_this,
        .parent = parent,
        // Its Browser is the parent's, recorded before its Window is made.
        .browser_scope = parent.browser_scope,
        .create_global_object = FrameWindow.create,
        // HTML IsPlatformObjectSameOrigin [cross_origin_objects]; it reads no
        // host (this one lives only while the realm is made).
        .is_platform_object_same_origin = if (engine.capabilities.cross_origin_objects != .unsupported) dom_module.cross_origin.isPlatformObjectSameOrigin else null,
        .host = &frame_window,
        // HTML 8.1.3.5, for [SecureContext] exposure (WebIDL 3.3.13): the
        // caller's answer for the document the realm is made for. A realm
        // reused for a later same-origin document keeps it.
        .secure_context = secure_context,
    }) catch |err| {
        log.debug("a frame's realm was not made: {}", .{err});
        return null;
    };
    // Its loop's cross-thread inbox is the parent's too.
    realm.task_sink = parent.task_sink;
    const window_instance = frame_window.window.?;

    // The Window's origin defaults to "null" (opaque), and stays so when
    // `origin` is null. Kept on the integration for the Windows later
    // navigations make.
    const WinImpl = @import("Window.zig");
    if (origin) |o| WinImpl.setOrigin(window_instance, o) catch {};
    integration.setWindowOrigin(origin) catch {};

    // Store the realm in the integration for cleanup on removal
    integration.setRealmContext(
        realm.engine_ctx,
        @ptrCast(realm),
        @ptrCast(realm),
        @ptrCast(realm),
        createDocumentForIframe,
        iframeContextCleanup,
        parseHtmlForIframe,
    );
    integration.parse_xml_callback = &parseXmlForIframe;

    // Set script execution callbacks (for script execution in iframe documents)
    integration.execute_script_callback = &executeIframeScript;
    integration.update_location_callback = &updateIframeLocation;
    // Navigation: this engine's "navigate", the hook that ends a navigation
    // in flight when the navigable goes, and how a retired realm ends.
    integration.navigate_callback = &navigateFromIntegration;
    integration.abandon_navigations_callback = &abandonNavigationsOf;
    integration.retired_realm_destroy = &destroyRetiredRealm;
    integration.deinit_callback = &leaveLiveNavigables;
    joinLiveNavigables(integration);

    // The Window's Location (HTML 7.2.1 - made with the Window, in its
    // realm), and its navigate callback for programmatic navigation
    // (iframe.contentWindow.location = 'url', location.assign()).
    if (interfaces.Window.get_location(window_instance)) |location| {
        const LocationImpl = @import("Location.zig");
        LocationImpl.setWindow(location, window_instance);
        LocationImpl.setNavigateCallback(location, &navigateFromLocation, @ptrCast(integration));
    } else |err| log.debug("a frame's Location was not made: {}", .{err});

    integration.realm_for_document_callback = &realmForNewDocument;
    return realm;
}

/// HTML "create a new realm", the customization for the global object: a
/// frame's Window, in its navigable's browsing context.
const FrameWindow = struct {
    browsing_context: *html_core.BrowsingContext,
    allocator: std.mem.Allocator,
    window: ?*runtime.Instance = null,

    fn create(realm: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        const self: *FrameWindow = @ptrCast(@alignCast(host orelse return null));
        const window = interfaces.Window.init(self.allocator, realm) catch |err| {
            log.debug("a frame's Window was not made: {}", .{err});
            return null;
        };
        // The navigable's browsing context, not the one Window.init made -
        // frames[index] and contentDocument find the Window through it -
        // and this Window its active window.
        @import("Window.zig").replaceBrowsingContext(window, @ptrCast(self.browsing_context));
        // The global the Window is bound to, for cross-realm access: a frame's
        // Window reached from its parent is this global, not a new wrapper.
        switch (global_this) {
            .handle => |h| dom_module.window_globals.bind(window, h.ptr),
            else => {},
        }
        self.window = window;
        return window;
    }
};

/// IFrameIntegration's `realm_for_document_callback`: HTML "create and
/// initialize a Document object" steps 5-7, for a document of `new_origin`
/// about to become the navigable's active document.
///
/// Step 6: the active window is reused when the active document is the
/// initial about:blank one and same origin(-domain) with the new document -
/// both documents then share one Window. Step 7, otherwise: a new realm, whose
/// global object is a new Window and whose global this binding is the
/// browsing context's WindowProxy (`replaceRealm`).
fn realmForNewDocument(integration: *IFrameIntegration, new_origin: html_core.Origin) bool {
    const old_document = activeDocumentOf(integration) orelse return true;
    const old_origin = if (integration.window_proxy) |proxy| proxy.document_origin else html_core.Origin.createOpaque();
    if (document_lifecycle.isInitialAboutBlank(old_document) and old_origin.isSameOrigin(new_origin)) return true;
    return replaceRealm(integration, new_origin);
}

/// Give the navigable a new realm and Window, keeping its WindowProxy: the
/// old context's global proxy is detached and a new context is built around
/// it (Blink's LocalWindowProxy::CreateContext after DisposeContext with
/// kFrameWillBeReused). Every reference to the proxy - iframe.contentWindow,
/// open()'s return value, a window[name] on the parent - now reaches the new
/// Window.
///
/// The old realm is not destroyed: its document was unloaded (runCommit) and
/// is destroyed ("destroy a document": its timers were cleared, its tasks go,
/// its child navigables are destroyed), and its Window and realm live on for
/// as long as script reaches anything of them - its document, its nodes, its
/// functions - and no longer: the engine ends the realm once the collector
/// takes it, or with its page (engine.WindowRealmEnd.global_detached).
/// Kept by the integration until the iframe went, as they once were, 200
/// navigations of one iframe kept 200 realms (crane/td-frame-navigation-
/// churn.html). Code still running in it sees a detached global (V8 gives
/// API callbacks a holder with no Window).
fn replaceRealm(integration: *IFrameIntegration, new_origin: html_core.Origin) bool {
    const old: runtime.Context = @ptrCast(@alignCast(integration.context_cleanup_data orelse return false));
    const browsing_context = integration.browsing_context orelse return false;
    const allocator = integration.allocator;
    // The parent realm: the window of the navigable's parent, or - for a
    // popup - the opener's realm the first realm was made under.
    const parent: runtime.Context = blk: {
        if (browsing_context.parent) |parent_bc| {
            if (parent_bc.getActiveWindow()) |w| break :blk @as(*runtime.Instance, @ptrCast(@alignCast(w))).ctx;
        }
        break :blk @ptrCast(@alignCast(integration.parent_realm orelse return false));
    };

    // The integration's origin string outlives this call's use of it below:
    // attachRealm records it again from a copy.
    const origin_copy: ?[]u8 = if (integration.window_origin) |o| allocator.dupe(u8, o) catch return false else null;
    defer if (origin_copy) |o| allocator.free(o);

    // The old realm leaves the integration with its Window and documents;
    // the new one is built around its WindowProxy (engine: window_proxy_of
    // detaches it).
    const secure_context = newDocumentIsSecureContext(browsing_context.parent != null, parent.secure_context, new_origin, allocator);
    const old_data = integration.releaseCurrentRealm() orelse return false;
    if (attachRealm(integration, parent, browsing_context, origin_copy, .{ .window_proxy_of = old }, secure_context, allocator) == null) {
        // No new realm: the old one ends with the integration, as every
        // replaced realm once did.
        integration.keepRetiredRealm(old_data) catch engine.destroyWindowRealm(old, .global_detached);
        return false;
    }
    // HTML "destroy a document" for the old document: the engine keeps its
    // realm while script reaches it.
    engine.destroyWindowRealm(old, .global_detached);
    return true;
}

/// HTML 8.1.3.5 for the realm of a document of `new_origin` that replaces a
/// navigable's (html.secure_context.ofDocument: its own URL potentially
/// trustworthy, and its parent's answer `upstream` when it has a parent).
/// The new document's URL is not known here, only its origin, so a tuple
/// origin is asked Secure Contexts 3.1 ("Is origin potentially
/// trustworthy?"), and an opaque one - a data: or srcdoc document, a
/// sandboxed one - takes `upstream`, the parent's (or a popup's opener's)
/// answer: a data: or about: URL is potentially trustworthy (3.2), and an
/// insecure sandboxed frame of a secure page is blocked as mixed content
/// before it commits. Out of memory answers not secure: less is exposed,
/// never more.
fn newDocumentIsSecureContext(has_parent: bool, upstream: bool, new_origin: html_core.Origin, allocator: std.mem.Allocator) bool {
    if (has_parent and !upstream) return false;
    if (new_origin.is_opaque) return upstream;
    const serialized = std.fmt.allocPrint(allocator, "{s}://{s}", .{ new_origin.scheme, new_origin.host }) catch return false;
    defer allocator.free(serialized);
    return fetch_mod.mixed_content.isOriginAuthenticated(allocator, serialized) catch false;
}

/// dom.auxiliary_navigables: HTML "definitely close" the top-level
/// traversable whose active window is `window`; false when `window` is not a
/// top-level traversable's.
///
/// "1. Let toUnload be traversable's active document's inclusive descendant
/// navigables. 2. If the result of checking if unloading is canceled for
/// toUnload is not "continue", then return. 3. Append the following session
/// history traversal steps to traversable: 1. Let afterAllUnloads be an
/// algorithm step which destroys traversable. 2. Unload a document and its
/// descendants given traversable's active document, null, and
/// afterAllUnloads." The traversal steps run here, in the same task.
///
/// "Destroy a top-level traversable", for one this machinery made
/// (window.open(), a link's or form's target): its documents are destroyed
/// (no other entry keeps one: there is no bfcache) and its browsing context
/// closed; its realm lives on while its opener's page does, for script that
/// holds the window. The host's own page is unloaded but not destroyed,
/// stated: the host owns it, and it is the host's to take down.
fn definitelyCloseTraversable(window: *runtime.Instance) bool {
    const bc = @import("dom").browser_state.browsingContextOf(window) orelse return false;
    if (bc.parent != null) return false;
    // Null for the host's page.
    const integration = integrationOfBrowsingContext(bc);
    if (integration) |made| {
        if (made.state == .discarded) return true;
        // Script runs below: the integration stays until this is done with
        // it.
        made.busy += 1;
    }
    defer if (integration) |made| finishBusy(made);
    if (bc.is_closed) return true;
    const document: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveDocument() orelse {
        if (integration != null) bc.close();
        return true;
    }));
    const allocator = std.heap.page_allocator;

    // Steps 1-2: beforeunload at each document, parents first. The answer is
    // "continue" unless a prompt was shown and the user stayed; none is
    // shown without sticky activation.
    {
        var documents = dom_module.navigables.inclusiveDescendantDocuments(document, allocator);
        defer documents.deinit(allocator);
        var canceled = false;
        for (documents.items) |entry| {
            if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
            if (document_lifecycle.fireBeforeUnload(entry.document).canceled) canceled = true;
        }
        if (canceled) {
            bc.is_closing = false;
            return true;
        }
    }
    // The handlers ran script: the traversable may have gone meanwhile.
    if (bc.is_closed) return true;
    if (integration) |made| if (made.state == .discarded) return true;

    // Step 3: its navigation in flight ends, then "unload a document and its
    // descendants" - pagehide and unload, children first - and, after all
    // unloads, "destroy" it.
    const active: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveDocument() orelse return true));
    var documents = dom_module.navigables.inclusiveDescendantDocuments(active, allocator);
    defer documents.deinit(allocator);
    const made = integration orelse {
        // The host's page: unloaded, children first, and its windows'
        // timers ended; not destroyed.
        var i = documents.items.len;
        while (i > 0) {
            i -= 1;
            const entry = documents.items[i];
            if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
            if (entry.browsing_context) |child_bc| {
                if (integrationOfBrowsingContext(child_bc)) |child| abandonNavigationsOf(child);
            }
            document_lifecycle.unload(entry.document);
        }
        dom_module.navigables.destroyWindowDocuments(bc);
        return true;
    };
    abandonNavigationsOf(made);
    unloadDocumentAndDescendants(active, made);
    // "Destroy a document and its descendants", children first.
    var i = documents.items.len;
    while (i > 0) {
        i -= 1;
        const entry = documents.items[i];
        if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
        document_lifecycle.destroy(entry.document);
    }
    // "Remove browsingContext": closed, and its descendants with it.
    bc.close();
    return true;
}

/// dom.auxiliary_navigables: window.open()'s new navigable - an auxiliary
/// browsing context opened by `opener_bc_ptr`, whose context, Window and
/// initial about:blank document are made exactly as an iframe's are, minus
/// the container. The integration is the caller's to deinit and destroy.
fn createAuxiliaryNavigable(
    allocator: std.mem.Allocator,
    opener_bc_ptr: *anyopaque,
    opener_origin: []const u8,
    is_popup: bool,
    popup_sandboxing_flags: SandboxingFlagSet,
) ?dom_module.auxiliary_navigables.Created {
    const opener_bc: *html_core.BrowsingContext = @ptrCast(@alignCast(opener_bc_ptr));
    // The opener is the entry global, whose script called open(): its realm
    // is the new realm's parent, so the page that keeps the popup
    // (Window.auxiliary_navigables) is the page that takes it down.
    const opener_realm = engine.entryRealm() orelse return null;

    const integration = allocator.create(IFrameIntegration) catch return null;
    integration.* = IFrameIntegration.init(allocator);
    const browsing_context = html_core.BrowsingContext.initAuxiliary(allocator, opener_bc, is_popup) catch {
        integration.deinit();
        allocator.destroy(integration);
        return null;
    };
    // From here the integration owns the browsing context: its deinit frees it.
    integration.browsing_context = browsing_context;
    // A new top-level context, but the same user agent: the opener's cookie
    // jar (it has no parent to reach one through).
    browsing_context.cookie_jar = opener_bc.cookieJar();
    // "The rules for choosing a navigable" step 8.9: the flags of the
    // document that opened it, when its sandbox propagates. Deviation,
    // stated (golden rule 2): the spec sets them once the new top-level
    // traversable exists, after its initial about:blank document was made
    // with an empty set; every engine gives that document the flags too
    // (Blink's frame policy carries them into the new frame before its
    // first document - crbug.com/1256822), so a popup still on its initial
    // document is sandboxed: html/browsers/sandboxing/popup-from-initial-
    // empty-sandboxed-document.window.js, sandbox-javascript-window-open.html
    // and sandbox-window-open-srcdoc.html ("popup is isolated from an
    // isolated iframe").
    browsing_context.popup_sandboxing_flags = popup_sandboxing_flags;
    // "Create a new auxiliary browsing context and document": its creator is
    // the opener's active document.
    const creator: ?*runtime.Instance = if (opener_bc.getActiveDocument()) |d| @ptrCast(@alignCast(d)) else null;
    // The initial about:blank document's flags: its creation sandboxing
    // flags (the popup sandboxing flag set). Deviation, stated (golden rule
    // 2): also the CSP-derived sandboxing flags of the policy container it
    // inherits from its creator ("create a new browsing context and
    // document" step 19.2), as Chrome 154 and Safari 27 do - they pass
    // the-iframe-element/sandbox-inherit-to-blank-document-unsandboxed.html
    // 4/4 ("The initial empty document inherit sandbox via CSP": a popup
    // that escapes its CSP-sandboxed opener's attribute-free sandbox still
    // starts on a sandboxed, cross-origin about:blank); Firefox 157 2/4.
    // The spec gives the initial document only its creation flags; a later
    // navigation's flags follow the spec (its policy container's
    // CSP-derived flags).
    const inherited_csp_flags = if (creator) |document|
        (if (dom_module.policy_containers.of(document)) |container| sandboxing.cspDerivedSandboxingFlags(&container.csp_list) else SandboxingFlagSet.empty)
    else
        SandboxingFlagSet.empty;
    const creation_flags = sandboxing.creationSandboxingFlags(.{ .popup = popup_sandboxing_flags }).unionWith(inherited_csp_flags);
    integration.container_origin = dom_module.navigables.parseOriginFromString(opener_origin);
    integration.state = .creating_initial_document;
    // Its WindowProxy, whose document origin - the initial about:blank's, the
    // opener's (an opaque one, sandboxed) - decides whether its first
    // navigation keeps its Window.
    integration.window_proxy = html_core.WindowProxy.init(allocator, browsing_context);
    if (integration.window_proxy) |*proxy| proxy.setDocumentOrigin(if (creation_flags.origin) Origin.createOpaque() else integration.container_origin);
    // The initial about:blank document's active sandboxing flag set
    // (createDocumentForIframe takes it). No defer resets it: the error
    // paths below free the integration.
    integration.setNextSandboxingFlags(creation_flags);

    integration.parent_realm = @ptrCast(opener_realm);
    _ = attachNavigableContext(integration, opener_realm, browsing_context, if (creation_flags.origin) null else opener_origin, creator, allocator) orelse {
        integration.deinit();
        allocator.destroy(integration);
        return null;
    };
    integration.setNextSandboxingFlags(.empty);
    const window: *runtime.Instance = @ptrCast(@alignCast(browsing_context.getActiveWindow() orelse {
        integration.deinit();
        allocator.destroy(integration);
        return null;
    }));
    // "Create a new top-level traversable" steps 6-9: its first entry.
    _ = browsing_context.ensureHistoryEntries(&history_documents.infoOf) catch {};
    return .{ .integration = @ptrCast(integration), .window = window };
}

/// Getter for contentDocument
/// Returns the nested document if same-origin, null otherwise.
/// Per HTML Standard §4.8.5: "The contentDocument getter steps are to return
/// this's content navigable's active document if this is same origin-domain;
/// otherwise null."
///
/// IMPORTANT: Per spec, contentDocument returns null if the iframe is not connected
/// (not inserted into the document). The content navigable is only created when
/// the iframe element is inserted into the DOM.
///
/// This getter delegates to contentWindow first to ensure the V8 context and
/// Document are lazily created if needed. Per spec, every browsing context
/// has an active document, so if the iframe is connected to the DOM, it should
/// have a Document.
pub fn get_contentDocument(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;

    // Per HTML spec: If the iframe is not connected (not in the document),
    // there is no content navigable, so contentDocument must return null.
    const is_connected = interfaces.Node.get_isConnected(instance) catch false;
    if (!is_connected) {
        return null;
    }

    // 1. Ensure the V8 context and Document exist by accessing contentWindow.
    //    Per spec, contentWindow triggers lazy creation of the browsing context,
    //    Window, and Document for a connected iframe. This is necessary because
    //    about:blank Documents are created when the context is initialized, not
    //    through navigation.
    _ = try get_contentWindow(instance);

    // 2-3. Compare the active document's current origin-domain with the
    // container's node document's, which need not be the script caller's.
    const document = (interfaces.Node.get_ownerDocument(instance) catch null) orelse return null;
    return dom_module.navigables.contentDocument(internal.integration, document);
}

// ============================================================================
// URL Attributes (§4.8.5)
// ============================================================================

/// Getter for src
/// HTML "reflect" for a USVString URL attribute: the content attribute,
/// encoding-parsed and serialized relative to the node document - or, when
/// that fails, the attribute's value as given; "" without one. Owned: the
/// binding frees what a getter returns.
pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
    return dom_module.reflection.get(runtime.USVString, instance, .{ .name = "src", .url = true });
}

/// Setter for src
/// HTML "reflect": set the src content attribute - whose change steps
/// (`iframeAttributeChangeSteps`) process the iframe attributes.
pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("src"), .{ .domstring = runtime.DOMString.initInterned(value) });
}

/// Getter for srcdoc
/// HTML "reflect": the srcdoc content attribute, or "". A copy - the binding
/// frees what a getter returns, and the attribute can change under it.
pub fn get_srcdoc(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const ElementImpl = @import("Element.zig");
    const value = (try ElementImpl.call_getAttribute(instance, runtime.DOMString.initInterned("srcdoc"))) orelse
        return runtime.DOMString.initInterned("");
    return runtime.DOMString.initDupe(instance.ctx.allocator, value.asSlice());
}

/// Setter for srcdoc
/// HTML "reflect": set the srcdoc content attribute - whose change steps
/// (`iframeAttributeChangeSteps`) process the iframe attributes.
pub fn set_srcdoc(instance: *runtime.Instance, value: typedefs.TrustedHTMLOrDOMString) anyerror!void {
    const allocator = instance.ctx.allocator;
    // 1. "Let compliantString be the result of invoking the get trusted type
    // compliant string algorithm with TrustedHTML, this's relevant global
    // object, the given value, "HTMLIFrameElement srcdoc", and "script"."
    const compliant = try dom_module.trusted_types.compliantStringFor(allocator, .html, instance, value, "HTMLIFrameElement srcdoc");
    defer allocator.free(compliant);
    // 2. "Set an attribute value given this, srcdoc's local name, and
    // compliantString" - DOM's, which runs no Trusted Types check again.
    const attributes = dom_module.element_attributes;
    var index: usize = 0;
    while (attributes.at(instance, index)) |attribute| : (index += 1) {
        if (attribute.namespace == null and std.mem.eql(u8, attribute.local_name, "srcdoc")) {
            return attributes.change(instance, null, "srcdoc", compliant);
        }
    }
    try attributes.append(instance, .{ .namespace = null, .prefix = null, .local_name = "srcdoc", .value = compliant });
}

/// dom.attribute_change_steps for iframe elements (HTML §4.8.5):
///
/// - "Whenever an iframe element with a non-null content navigable has its
///   srcdoc attribute set, changed, or removed, the user agent must process
///   the iframe attributes."
/// - "Similarly, whenever an iframe element with a non-null content navigable
///   but with no srcdoc attribute specified has its src attribute set,
///   changed, or removed, the user agent must process the iframe attributes."
/// - The sandbox attribute's new value is parsed into the element's iframe
///   sandboxing flag set, which the next navigation applies (§4.8.5
///   "When an iframe element's sandbox attribute is set or changed while it
///   has a non-null content navigable, the user agent must parse the
///   sandboxing directive"; removal clears it).
fn iframeAttributeChangeSteps(
    element: *runtime.Instance,
    local_name: []const u8,
    old_value: ?[]const u8,
    value: ?[]const u8,
    namespace: ?[]const u8,
) void {
    _ = old_value;
    if (namespace != null) return;
    const internal = getInternal(element) orelse return;
    if (std.mem.eql(u8, local_name, "sandbox")) {
        if (value) |v| internal.integration.setSandbox(v) else internal.integration.clearSandbox();
        return;
    }
    const is_srcdoc = std.mem.eql(u8, local_name, "srcdoc");
    if (!is_srcdoc and !std.mem.eql(u8, local_name, "src")) return;
    if (!hasContentNavigable(element)) return;
    if (!is_srcdoc) {
        const ElementImpl = @import("Element.zig");
        if (ElementImpl.call_hasAttribute(element, runtime.DOMString.initInterned("srcdoc")) catch false) return;
    }
    processIframeAttributes(element, false);
}

/// Whether the element has a content navigable: it is connected and its
/// post-connection steps made one.
fn hasContentNavigable(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    if (internal.integration.state == .discarded or internal.integration.state == .uninitialized) return false;
    if (internal.integration.browsing_context == null) return false;
    const NodeImpl = @import("Node.zig");
    return NodeImpl.get_isConnected(instance) catch false;
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.name_attr) |name| {
        return runtime.DOMString.initInterned(name);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for name
/// Sets the browsing context name for targeting.
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    // Free old value
    if (internal.name_attr) |old| {
        internal.allocator.free(old);
    }

    // Store new value
    const str = value.asSlice();
    internal.name_attr = try internal.allocator.dupe(u8, str);

    // Update integration (propagates to iframe's browsing context)
    internal.integration.setName(str) catch {};

    // Also propagate to the Window's browsing context if contentWindow exists
    // This ensures iframe.contentWindow.name reflects the updated name
    if (navigableContext(internal.integration)) |realm| {
        if (windowOfRealm(realm)) |window_instance| {
            const WindowImpl = @import("Window.zig");
            if (WindowImpl.getInternal(window_instance)) |window_internal| {
                window_internal.browsing_context.setTargetName(str) catch {};
            }
        }
    }
}

// ============================================================================
// Sandbox Attribute (§4.8.5)
// ============================================================================

/// Getter for sandbox
/// Returns a DOMTokenList for the sandbox attribute.
/// Per spec, this is a [SameObject] attribute - returns the same DOMTokenList each time.
pub fn get_sandbox(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidState;

    // Return cached token list if already created
    if (internal.sandbox_token_list) |token_list| {
        return token_list;
    }

    // Create a new DOMTokenList for the sandbox attribute
    const token_list = DOMTokenList.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer DOMTokenList.deinit(token_list);

    // Set supported tokens for supports() method
    DOMTokenListImpl.setSupportedTokens(token_list, &sandboxing.supported_tokens);

    // Associate with this element and attribute name
    DOMTokenListImpl.setElement(token_list, instance, runtime.DOMString.initInterned("sandbox"));

    // Initialize the token list from the element's current sandbox attribute value.
    // This is critical: the attribute may have been set via Element.setAttribute()
    // before the DOMTokenList was created. Per spec, the DOMTokenList should
    // reflect the current attribute value.
    const ElementImpl = @import("Element.zig");
    const sandbox_attr_name = runtime.DOMString.initInterned("sandbox");
    if (ElementImpl.call_getAttribute(instance, sandbox_attr_name) catch null) |attr_value| {
        const attr_slice = attr_value.asSlice();
        if (attr_slice.len > 0) {
            // Parse the attribute value and populate the token list
            DOMTokenListImpl.set_value(token_list, attr_value) catch {};
        }
    }

    // Cache for future calls (SameObject semantic)
    internal.sandbox_token_list = token_list;

    return token_list;
}

// ============================================================================
// Permissions Policy Attributes (§4.8.5)
// ============================================================================

/// Getter for allow
pub fn get_allow(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.allow_attr) |allow| {
        return runtime.DOMString.initInterned(allow);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for allow
pub fn set_allow(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    if (internal.allow_attr) |old| {
        internal.allocator.free(old);
    }
    internal.allow_attr = try internal.allocator.dupe(u8, value.asSlice());
}

// ============================================================================
// Loading and Security Attributes (§4.8.5)
// ============================================================================

/// Getter for referrerPolicy
pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return dom_module.reflection.getEnumerated(runtime.DOMString, instance, .{
        .name = "referrerpolicy",
        .keywords = dom_module.reflection.referrer_policy_keywords,
    });
}

/// Setter for referrerPolicy
pub fn set_referrerPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try dom_module.reflection.set(runtime.DOMString, instance, .{ .name = "referrerpolicy" }, value);
}

/// Getter for loading
pub fn get_loading(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return dom_module.reflection.getEnumerated(runtime.DOMString, instance, .{
        .name = "loading",
        .keywords = &.{ "eager", "lazy" },
        .missing = "eager",
        .invalid = "eager",
    });
}

/// Setter for loading
pub fn set_loading(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try dom_module.reflection.set(runtime.DOMString, instance, .{ .name = "loading" }, value);
}

/// Getter for csp
pub fn get_csp(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // CSP Embedded Enforcement §2.1: reflect the content attribute.
    return dom_module.reflection.get(runtime.DOMString, instance, .{ .name = "csp" });
}

/// Setter for csp
pub fn set_csp(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try dom_module.reflection.set(runtime.DOMString, instance, .{ .name = "csp" }, value);
}

/// Getter for credentialless
pub fn get_credentialless(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.credentialless;
}

/// Setter for credentialless
pub fn set_credentialless(instance: *runtime.Instance, value: bool) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    internal.credentialless = value;
}

// ============================================================================
// Experimental Attributes
// ============================================================================

/// Getter for privateToken
pub fn get_privateToken(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.private_token_attr) |pt| {
        return runtime.DOMString.initInterned(pt);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for privateToken
pub fn set_privateToken(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    if (internal.private_token_attr) |old| {
        internal.allocator.free(old);
    }
    internal.private_token_attr = try internal.allocator.dupe(u8, value.asSlice());
}

/// Getter for permissionsPolicy
pub fn get_permissionsPolicy(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    // TODO: Implement PermissionsPolicy interface
    return error.NotImplemented;
}

// ============================================================================
// Operations (§4.8.5)
// ============================================================================

/// Operation: getSVGDocument
/// Returns the nested SVG document if applicable.
pub fn call_getSVGDocument(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    // TODO: Implement SVG document retrieval
    return null;
}

// ============================================================================
// Removing Steps Callback for Iframe Cleanup
// ============================================================================

/// Removing steps callback for iframe elements.
/// This callback is registered with the DOM mutation system and is called whenever
/// a node is removed from the document. If the node is an iframe element, this
/// function calls onRemovedFromDocument() on the iframe's integration to clean up
/// the nested browsing context.
///
/// Per HTML spec §4.8.5, when an iframe is removed from the document:
/// 1. The nested browsing context is discarded
/// 2. The browsing context is removed from its parent's children list
/// 3. window.frames.length should reflect the change immediately
fn iframeRemovingStepsCallback(node: *NodeBase, old_parent: ?*NodeBase) void {
    _ = old_parent;

    // Only process ELEMENT_NODE (nodeType == 1)
    if (node.node_type != 1) return;

    // Check if this is an iframe element by looking at the node_name.
    // For HTML elements, node_name is the uppercase tag name (e.g., "IFRAME").
    // We also check for lowercase "iframe" for robustness.
    if (!std.ascii.eqlIgnoreCase(node.node_name, "iframe")) return;

    // Get the runtime.Instance from the NodeBase using the instance bridge
    const instance_ptr = instance_bridge.getInstance(node) orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));

    // HTML "destroy a child navigable" (dom.navigables).
    const internal = getInternal(instance) orelse return;
    dom_module.navigables.destroyChildNavigable(instance, internal.integration);
}

// ============================================================================
// Post-connection steps (HTML §4.8.5)
// ============================================================================

/// The iframe HTML element post-connection steps, given `node`:
/// 1. create a new child navigable for it;
/// 2. parse its sandbox attribute, if it has one;
/// 3. process the iframe attributes, with initialInsertion true.
///
/// Every insertion reaches this - the parsers' as much as script's - once
/// the whole batch is in the tree, so a frame's load event and its scripts
/// never run in the middle of an insertion.
///
/// An element that was removed and is inserted again gets a NEW navigable
/// and a new initial about:blank document; its old context is retired, not
/// destroyed (see `IFrameIntegration.retireRealmContext`).
fn iframePostConnectionSteps(node: *NodeBase) void {
    if (node.node_type != 1) return;
    if (!std.ascii.eqlIgnoreCase(node.node_name, "iframe")) return;
    const instance_ptr = instance_bridge.getInstance(node) orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));
    const internal = getInternal(instance) orelse return;
    const NodeImpl = @import("Node.zig");
    if (!(NodeImpl.get_isConnected(instance) catch false)) return;

    // Inserted again after a removal: the old navigable is gone.
    if (internal.integration.state == .discarded) {
        internal.integration.retireRealmContext() catch return;
    }

    // Step 2 comes first here: the sandboxing flags decide the new context's
    // security token as it is created.
    const ElementImpl = @import("Element.zig");
    if (ElementImpl.call_getAttribute(instance, runtime.DOMString.initInterned("sandbox")) catch null) |sandbox| {
        internal.integration.setSandbox(sandbox.asSlice());
    }

    // Step 1: create a new child navigable.
    if (!internal.integration.hasRealmContext()) {
        if (!createChildNavigable(instance)) return;
    }

    // The navigable's target name is the element's name attribute, and the
    // parent's global reaches it by that name.
    const name: ?[]const u8 = blk: {
        if (internal.name_attr) |n| break :blk n;
        if (ElementImpl.call_getAttribute(instance, runtime.DOMString.initInterned("name")) catch null) |attr| break :blk attr.asSlice();
        break :blk null;
    };
    if (name) |n| {
        if (n.len > 0) {
            const owned = internal.allocator.dupe(u8, n) catch return;
            defer internal.allocator.free(owned);
            internal.integration.setName(owned) catch {};
            dom_module.navigables.registerNamedProperty(internal.integration, owned);
        }
    }

    // Step 3.
    processIframeAttributes(instance, true);
}

/// dom.child_navigables: the Window of `bc_ptr`'s navigable (an html_core
/// BrowsingContext), which its container - an iframe - makes now if it has
/// not yet (get_contentWindow: "create a new child navigable").
fn windowOfChildNavigable(bc_ptr: *anyopaque) ?*runtime.Instance {
    const bc: *html_core.BrowsingContext = @ptrCast(@alignCast(bc_ptr));
    const element: *runtime.Instance = @ptrCast(@alignCast(bc.container orelse return null));
    if (element.stateAs(interfaces.HTMLIFrameElement.State) == null) return null;
    const proxy = (get_contentWindow(element) catch return null) orelse return null;
    return @ptrCast(proxy);
}

/// Getter for connectionAllowlist
pub fn get_connectionAllowlist(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for connectionAllowlist
pub fn set_connectionAllowlist(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}
