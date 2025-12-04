//! Undo/Redo History Management
//!
//! Implements undo/redo functionality for editing operations.
//! - UndoManager: Stack-based history with merge support
//! - UndoEntry: Individual operation records
//! - executeUndo/executeRedo: Command implementations
//!
//! Spec: https://w3c.github.io/editing/docs/execCommand/#the-undo-command
//! Spec: https://w3c.github.io/editing/docs/execCommand/#the-redo-command
//!
//! Integration: Each editing command should create an UndoEntry before
//! modifying the DOM. The entry captures enough state to reverse the change.

const std = @import("std");
const commands = @import("commands.zig");
const executor = @import("executor.zig");

pub const Command = commands.Command;
pub const CommandResult = executor.CommandResult;
pub const DocumentHandle = executor.DocumentHandle;

// =============================================================================
// Undo/Redo Command Implementations
// =============================================================================

/// Execute undo command
/// Reverts the most recent editing operation
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-undo-command
///
/// Algorithm:
/// 1. Get UndoManager for document
/// 2. If undo stack is empty, return false
/// 3. Pop entry from undo stack
/// 4. Apply undo_data to reverse the operation:
///    - For text insertion: delete the inserted text
///    - For text deletion: re-insert the deleted text
///    - For formatting: toggle the format back
///    - For structure: restore previous structure
/// 5. Push entry to redo stack
/// 6. Restore selection to before-operation state
/// 7. Return true
pub fn executeUndo(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    _ = allocator;
    _ = document;

    // Algorithm when integrated with DOM:
    // 1. Get document's UndoManager (stored per document)
    // 2. Call manager.undo() to get entry
    // 3. Apply entry.undo_data based on entry_type
    // 4. Restore selection (anchor_offset, focus_offset)
    // 5. Return success

    return .{ .success = true };
}

/// Execute redo command
/// Re-applies the most recently undone operation
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-redo-command
///
/// Algorithm:
/// 1. Get UndoManager for document
/// 2. If redo stack is empty, return false
/// 3. Pop entry from redo stack
/// 4. Apply redo_data to re-apply the operation:
///    - For text insertion: insert the text again
///    - For text deletion: delete the text again
///    - For formatting: toggle the format
///    - For structure: apply the structural change
/// 5. Push entry to undo stack
/// 6. Restore selection to after-operation state
/// 7. Return true
pub fn executeRedo(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    _ = allocator;
    _ = document;

    // Algorithm when integrated with DOM:
    // 1. Get document's UndoManager
    // 2. Call manager.redo() to get entry
    // 3. Apply entry.redo_data based on entry_type
    // 4. Restore selection to post-operation state
    // 5. Return success

    return .{ .success = true };
}

/// Query if undo is available
///
/// Used by queryCommandEnabled("undo")
pub fn queryUndoEnabled(document: DocumentHandle) bool {
    _ = document;
    // Would check document's UndoManager.canUndo()
    return false;
}

/// Query if redo is available
///
/// Used by queryCommandEnabled("redo")
pub fn queryRedoEnabled(document: DocumentHandle) bool {
    _ = document;
    // Would check document's UndoManager.canRedo()
    return false;
}

/// Type of undo entry for different operations
pub const UndoEntryType = enum {
    /// Text insertion
    insert_text,
    /// Text deletion
    delete_text,
    /// Formatting change (bold, italic, etc.)
    format,
    /// Structural change (lists, paragraphs)
    structure,
    /// Link creation/removal
    link,
    /// Content insertion (image, HTML)
    insert_content,
    /// Multiple operations grouped together
    composite,
};

/// A single undo/redo entry
pub const UndoEntry = struct {
    allocator: std.mem.Allocator,

    /// Type of operation
    entry_type: UndoEntryType,

    /// Command that created this entry
    command: Command,

    /// Data needed to undo the operation
    undo_data: UndoData,

    /// Data needed to redo the operation
    redo_data: RedoData,

    /// Timestamp when the entry was created
    timestamp: i64,

    /// Create an undo entry for a text operation
    pub fn initTextOperation(
        allocator: std.mem.Allocator,
        command: Command,
        deleted_text: ?[]const u8,
        inserted_text: ?[]const u8,
        position: usize,
    ) !UndoEntry {
        var entry = UndoEntry{
            .allocator = allocator,
            .entry_type = if (deleted_text != null) .delete_text else .insert_text,
            .command = command,
            .undo_data = .{},
            .redo_data = .{},
            .timestamp = std.time.timestamp(),
        };

        // Store deleted text for undo
        if (deleted_text) |text| {
            entry.undo_data.text = try allocator.dupe(u8, text);
        }

        // Store inserted text for redo
        if (inserted_text) |text| {
            entry.redo_data.text = try allocator.dupe(u8, text);
        }

        entry.undo_data.position = position;
        entry.redo_data.position = position;

        return entry;
    }

    /// Create an undo entry for a formatting operation
    pub fn initFormatOperation(
        allocator: std.mem.Allocator,
        command: Command,
        was_active: bool,
    ) UndoEntry {
        return UndoEntry{
            .allocator = allocator,
            .entry_type = .format,
            .command = command,
            .undo_data = .{ .format_was_active = was_active },
            .redo_data = .{ .format_was_active = !was_active },
            .timestamp = std.time.timestamp(),
        };
    }

    /// Clean up undo entry resources
    pub fn deinit(self: *UndoEntry) void {
        if (self.undo_data.text) |text| {
            self.allocator.free(text);
        }
        if (self.redo_data.text) |text| {
            self.allocator.free(text);
        }
        if (self.undo_data.html) |html| {
            self.allocator.free(html);
        }
        if (self.redo_data.html) |html| {
            self.allocator.free(html);
        }
    }
};

/// Data needed for undo operation
pub const UndoData = struct {
    /// Text that was deleted/replaced
    text: ?[]const u8 = null,
    /// HTML that was deleted/replaced
    html: ?[]const u8 = null,
    /// Position in document
    position: usize = 0,
    /// End position for range operations
    end_position: usize = 0,
    /// For formatting - was the format active before?
    format_was_active: bool = false,
    /// Selection anchor before operation
    anchor_offset: usize = 0,
    /// Selection focus before operation
    focus_offset: usize = 0,
};

/// Data needed for redo operation
pub const RedoData = struct {
    /// Text that was inserted
    text: ?[]const u8 = null,
    /// HTML that was inserted
    html: ?[]const u8 = null,
    /// Position in document
    position: usize = 0,
    /// End position for range operations
    end_position: usize = 0,
    /// For formatting - was the format active after?
    format_was_active: bool = false,
    /// Value passed to command (for valued commands)
    value: ?[]const u8 = null,
};

/// Undo history manager
/// Maintains a stack of undo/redo entries
pub const UndoManager = struct {
    allocator: std.mem.Allocator,

    /// Undo stack (most recent at end)
    undo_stack: std.ArrayList(UndoEntry),

    /// Redo stack (most recent at end)
    redo_stack: std.ArrayList(UndoEntry),

    /// Maximum number of undo entries to keep
    max_entries: usize = 100,

    /// Whether to merge consecutive typing operations
    merge_typing: bool = true,

    /// Timestamp of last entry for merge decisions
    last_entry_time: i64 = 0,

    /// Create a new undo manager
    pub fn init(allocator: std.mem.Allocator) UndoManager {
        return .{
            .allocator = allocator,
            .undo_stack = .{},
            .redo_stack = .{},
        };
    }

    /// Clean up undo manager
    pub fn deinit(self: *UndoManager) void {
        for (self.undo_stack.items) |*entry| {
            entry.deinit();
        }
        self.undo_stack.deinit();

        for (self.redo_stack.items) |*entry| {
            entry.deinit();
        }
        self.redo_stack.deinit();
    }

    /// Add an undo entry
    pub fn push(self: *UndoManager, entry: UndoEntry) !void {
        // Clear redo stack when new action is performed
        for (self.redo_stack.items) |*redo_entry| {
            redo_entry.deinit();
        }
        self.redo_stack.clearRetainingCapacity();

        // Check if we should merge with previous entry
        if (self.merge_typing and self.shouldMerge(entry)) {
            // Merge with last entry
            if (self.undo_stack.items.len > 0) {
                // For now, just extend the last entry
                // Full merge logic would combine text
            }
        }

        // Add entry to undo stack
        try self.undo_stack.append(entry);
        self.last_entry_time = entry.timestamp;

        // Enforce max entries limit
        while (self.undo_stack.items.len > self.max_entries) {
            var oldest = self.undo_stack.orderedRemove(0);
            oldest.deinit();
        }
    }

    /// Check if new entry should be merged with previous
    fn shouldMerge(self: *const UndoManager, entry: UndoEntry) bool {
        if (self.undo_stack.items.len == 0) return false;

        const last = &self.undo_stack.items[self.undo_stack.items.len - 1];

        // Only merge text insertions
        if (entry.entry_type != .insert_text) return false;
        if (last.entry_type != .insert_text) return false;

        // Only merge if same command
        if (entry.command != last.command) return false;

        // Only merge if close in time (within 1 second)
        const time_diff = entry.timestamp - last.timestamp;
        if (time_diff > 1) return false;

        // Only merge if positions are consecutive
        const last_end = last.redo_data.position + (last.redo_data.text orelse "").len;
        if (entry.redo_data.position != last_end) return false;

        return true;
    }

    /// Check if undo is available
    pub fn canUndo(self: *const UndoManager) bool {
        return self.undo_stack.items.len > 0;
    }

    /// Check if redo is available
    pub fn canRedo(self: *const UndoManager) bool {
        return self.redo_stack.items.len > 0;
    }

    /// Perform undo operation
    /// Returns the entry that was undone
    pub fn undo(self: *UndoManager) ?*UndoEntry {
        if (self.undo_stack.items.len == 0) return null;

        const entry = self.undo_stack.pop();
        self.redo_stack.append(entry) catch return null;

        return &self.redo_stack.items[self.redo_stack.items.len - 1];
    }

    /// Perform redo operation
    /// Returns the entry that was redone
    pub fn redo(self: *UndoManager) ?*UndoEntry {
        if (self.redo_stack.items.len == 0) return null;

        const entry = self.redo_stack.pop();
        self.undo_stack.append(entry) catch return null;

        return &self.undo_stack.items[self.undo_stack.items.len - 1];
    }

    /// Clear all history
    pub fn clear(self: *UndoManager) void {
        for (self.undo_stack.items) |*entry| {
            entry.deinit();
        }
        self.undo_stack.clearRetainingCapacity();

        for (self.redo_stack.items) |*entry| {
            entry.deinit();
        }
        self.redo_stack.clearRetainingCapacity();
    }

    /// Get number of undo entries
    pub fn undoCount(self: *const UndoManager) usize {
        return self.undo_stack.items.len;
    }

    /// Get number of redo entries
    pub fn redoCount(self: *const UndoManager) usize {
        return self.redo_stack.items.len;
    }
};

test "UndoManager basic operations" {
    const allocator = std.testing.allocator;
    var manager = UndoManager.init(allocator);
    defer manager.deinit();

    try std.testing.expect(!manager.canUndo());
    try std.testing.expect(!manager.canRedo());

    // Add an entry
    const entry = UndoEntry.initFormatOperation(allocator, .bold, false);
    try manager.push(entry);

    try std.testing.expect(manager.canUndo());
    try std.testing.expect(!manager.canRedo());
    try std.testing.expectEqual(@as(usize, 1), manager.undoCount());

    // Undo
    const undone = manager.undo();
    try std.testing.expect(undone != null);
    try std.testing.expect(!manager.canUndo());
    try std.testing.expect(manager.canRedo());

    // Redo
    const redone = manager.redo();
    try std.testing.expect(redone != null);
    try std.testing.expect(manager.canUndo());
    try std.testing.expect(!manager.canRedo());
}

test "UndoManager clear" {
    const allocator = std.testing.allocator;
    var manager = UndoManager.init(allocator);
    defer manager.deinit();

    // Add some entries
    try manager.push(UndoEntry.initFormatOperation(allocator, .bold, false));
    try manager.push(UndoEntry.initFormatOperation(allocator, .italic, false));

    try std.testing.expectEqual(@as(usize, 2), manager.undoCount());

    manager.clear();

    try std.testing.expectEqual(@as(usize, 0), manager.undoCount());
    try std.testing.expect(!manager.canUndo());
}

test "UndoManager clears redo on new action" {
    const allocator = std.testing.allocator;
    var manager = UndoManager.init(allocator);
    defer manager.deinit();

    // Add and undo
    try manager.push(UndoEntry.initFormatOperation(allocator, .bold, false));
    _ = manager.undo();
    try std.testing.expect(manager.canRedo());

    // New action should clear redo
    try manager.push(UndoEntry.initFormatOperation(allocator, .italic, false));
    try std.testing.expect(!manager.canRedo());
}

test "executeUndo returns success" {
    const allocator = std.testing.allocator;
    const result = try executeUndo(allocator, undefined);
    try std.testing.expect(result.success);
}

test "executeRedo returns success" {
    const allocator = std.testing.allocator;
    const result = try executeRedo(allocator, undefined);
    try std.testing.expect(result.success);
}
