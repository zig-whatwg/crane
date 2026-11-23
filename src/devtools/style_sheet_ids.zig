//! DevTools style sheet ids: CDP's CSS.StyleSheetId for a CSSStyleSheet,
//! stable while the sheet lives and never reused - Blink's
//! IdentifiersFactory::IdForCSSStyleSheet, "style-sheet-<process>-<n>" over
//! a WeakIdentifierMap<CSSStyleSheet> (third_party/blink/renderer/core/
//! inspector/identifiers_factory.cc at Chrome 157.0.8103.78). The DOM
//! domain names adopted sheets by them (DOM.Node.adoptedStyleSheets,
//! DOM.adoptedStyleSheetsModified); the CSS domain, when it comes (CDP part
//! 2), names every sheet by the same ids (lane cdpd1, main's D3).
//!
//! Like NodeIds (node_ids.zig): one registry per Browser (a supplement of
//! its scope), never a hold - each entry names its sheet by address and slab
//! generation, so a sheet freed or a slot reused answers none. The
//! "process" part is the Browser's devtools token, as Network's request ids
//! (fetch_observer.requestIdText).

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const TombstoneGuard = @import("infra").tombstones.TombstoneGuard;

pub const StyleSheetIds = struct {
    allocator: Allocator,
    by_sheet: std.AutoHashMapUnmanaged(usize, Entry) = .empty,
    by_sheet_guard: TombstoneGuard = .{},
    /// WeakIdentifierMap's first identifier is 1.
    next_id: u64 = 1,

    const Entry = struct {
        id: u64,
        generation: u64,
    };

    pub fn init(allocator: Allocator) StyleSheetIds {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *StyleSheetIds) void {
        self.by_sheet.deinit(self.allocator);
    }

    /// `sheet`'s number, given on first ask.
    pub fn numberOf(self: *StyleSheetIds, sheet: *runtime.Instance) Allocator.Error!u64 {
        const address = @intFromPtr(sheet);
        const generation = runtime.SlabAllocator.generationOf(sheet);
        if (self.by_sheet.get(address)) |entry| {
            if (entry.generation == generation) return entry.id;
        }
        self.by_sheet_guard.beforeInsert(&self.by_sheet);
        try self.by_sheet.put(self.allocator, address, .{ .id = self.next_id, .generation = generation });
        self.next_id += 1;
        return self.next_id - 1;
    }

    /// `sheet`'s id text ("style-sheet-<process>-<n>"), into `arena`.
    pub fn idOf(self: *StyleSheetIds, arena: Allocator, browser_token: u64, sheet: *runtime.Instance) Allocator.Error![]const u8 {
        return std.fmt.allocPrint(arena, "style-sheet-{d}-{d}", .{ browser_token % 100000, try self.numberOf(sheet) });
    }
};
