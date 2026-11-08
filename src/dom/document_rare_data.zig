//! A Document's rare data: the state few Documents ever set, kept out of
//! every Document's own state (dom.document_state.InternalState) and made on
//! first use - WebKit's and Blink's NodeRareData pattern for the Document:
//! Blink keeps a document's import map and module map on its Modulator (made
//! with the first module script), its fullscreen, pointer lock and
//! picture-in-picture state in supplements made on first use; WebKit makes
//! its FullscreenManager and its template document on first use
//! (Document::fullscreenManager, Document::ensureTemplateDocument).
//!
//! Lane perf2 batch 7 measured which of a Document's fields its Documents set
//! (tmp/plans/perf2-evidence/batch7/document-field-counts.txt: an
//! instrumented runner over a 1-in-16 sample of the 0.1 worklist, 823 files,
//! 15,601 Documents, each counted at its teardown). Of those Documents the
//! import map was set on 0, the prefetch hints on 1, the pragma language on
//! 0, the frozen base URL on 13, the target element on 0, the pointer states
//! on 15, the fullscreen, pointer lock and picture-in-picture elements on 0,
//! the template contents owner on 548 (3.5%) and the parser's form
//! associations on 3: those are here. What more of them set stays in the
//! state: the back/forward cache's unload record (27%), the about base URL
//! (16%), the module map (14%), the live ranges and iterators (11%).
//!
//! The block is allocated once, from the document's allocator, never moved,
//! and freed with the document's state (InternalState.deinit). Its bytes are
//! counted in the document's Browser's DOM memory while it lives, as a
//! node's rare data is (runtime.BrowserScope.dom_memory: what V8 schedules
//! DOM-driven collections by).
const std = @import("std");
const runtime = @import("runtime");
const same_object = @import("same_object.zig");
const SpeculationEagerness = @import("document_scripts.zig").SpeculationEagerness;
const ParserFormAssociation = @import("document_internals.zig").ParserFormAssociation;

pub const DocumentRareData = struct {
    /// The DOM memory this block is counted in (its document's Browser's),
    /// or null when it is not counted.
    counted_in: ?*runtime.gc.ExternalMemory = null,

    // === Import maps (HTML 8.1.5.2) ===

    /// The import map's imports: bare specifier -> resolved URL. Keys and
    /// values owned.
    import_map_imports: std.StringHashMap([]const u8),
    /// HTML import map's integrity: URL -> metadata. Keys and values owned.
    import_map_integrity: std.StringHashMap([]const u8),
    /// The import map's scopes: scope prefix -> (specifier -> resolved URL).
    /// Every key and value owned.
    import_map_scopes: std.StringHashMap(std.StringHashMap([]const u8)),

    /// Speculation rules: prefetch URL hints (HTML 7.6). Keys owned.
    prefetch_hints: std.StringHashMap(SpeculationEagerness),

    // === Base URL and language ===

    /// HTML's first base[href], resolved when a base mutation occurs. Owned
    /// bytes, independent of later changes to the document's URL. Null
    /// leaves the live fallback effective (including a rejected base).
    frozen_base_url: ?[]u8 = null,
    /// HTML 4.2.5.3: owned pragma-set default language, null before any
    /// content-language pragma. Removing its meta does not clear it.
    pragma_language: ?[]const u8 = null,

    // === Elements few documents designate ===

    /// HTML 7.4.6.4 "target element": what :target matches, set by "scroll
    /// to the fragment"; initially null. A weak link - the element can be
    /// removed and freed while it is the target (dom.target_element).
    target_element: ?same_object.Link = null,
    /// HTML 4.16.3: the elements :hover and :active rest on - designated by
    /// a pointing device, being actively pointed at, in a formal activation
    /// state (dom.pointer_states). Weak links: the element can be removed
    /// and freed while it is designated.
    hovered_element: ?same_object.Link = null,
    pointed_element: ?same_object.Link = null,
    activated_element: ?same_object.Link = null,

    /// The fullscreen element (Fullscreen API), the pointer lock element
    /// (Pointer Lock 2.0) and the picture-in-picture element (Picture-in-
    /// Picture): Blink keeps each in a supplement of its own, made on first
    /// use (Fullscreen, PointerLockController, PictureInPictureController).
    /// None is ever set yet.
    fullscreen_element: ?*runtime.Instance = null,
    pointer_lock_element: ?*runtime.Instance = null,
    picture_in_picture_element: ?*runtime.Instance = null,

    /// HTML 4.12.3: the inert template contents owner document this
    /// document made for its templates, as it was when made (its slab
    /// generation): held counted by the document until its teardown.
    template_owner_document: ?*runtime.Instance = null,
    template_owner_generation: u64 = 0,

    /// The HTML parser's form element pointer associations that differ from
    /// the tree's (a misnested or foster-parented control), kept until
    /// "reset the form owner" undoes them (html/form_associated.zig). Raw
    /// links, generation-checked: they keep nothing alive.
    parser_form_associations: std.ArrayListUnmanaged(ParserFormAssociation) = .empty,

    fn init(allocator: std.mem.Allocator) DocumentRareData {
        return .{
            .import_map_imports = .init(allocator),
            .import_map_integrity = .init(allocator),
            .import_map_scopes = .init(allocator),
            .prefetch_hints = .init(allocator),
        };
    }

    /// Make `document`'s rare data (`allocator` its Browser's), counted in
    /// its Browser's DOM memory.
    pub fn create(allocator: std.mem.Allocator, document: *runtime.Instance) error{OutOfMemory}!*DocumentRareData {
        const rare = try allocator.create(DocumentRareData);
        rare.* = .init(allocator);
        const memory = &runtime.BrowserScope.ofInstance(document).dom_memory;
        memory.add(@sizeOf(DocumentRareData));
        rare.counted_in = memory;
        return rare;
    }

    /// Free what the block owns, then the block (`allocator` the one it was
    /// made with), and uncount it.
    pub fn destroy(self: *DocumentRareData, allocator: std.mem.Allocator) void {
        freeStringMap(allocator, &self.import_map_imports);
        freeStringMap(allocator, &self.import_map_integrity);
        {
            var scope_it = self.import_map_scopes.iterator();
            while (scope_it.next()) |entry| {
                allocator.free(entry.key_ptr.*);
                freeStringMap(allocator, entry.value_ptr);
            }
            self.import_map_scopes.deinit();
        }
        {
            var hint_it = self.prefetch_hints.keyIterator();
            while (hint_it.next()) |key_ptr| allocator.free(key_ptr.*);
            self.prefetch_hints.deinit();
        }
        if (self.frozen_base_url) |url| allocator.free(url);
        if (self.pragma_language) |language| allocator.free(language);
        self.parser_form_associations.deinit(allocator);
        if (self.counted_in) |memory| memory.sub(@sizeOf(DocumentRareData));
        allocator.destroy(self);
    }

    fn freeStringMap(allocator: std.mem.Allocator, map: *std.StringHashMap([]const u8)) void {
        var it = map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        map.deinit();
    }
};
