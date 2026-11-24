# Debugging: A Zig `for ... else` around a bare `if` binds the `else` to the `if`

**Date**: 2026-11-23
**Lesson**: `for (xs) |x| if (match) { ...; break; } else append()` is not a for-else: the `else` belongs to the `if`, so it runs once per non-matching element and never when the list is empty.

**Why**: Zig's `for` takes a single statement body; a bare `if (...) {...} else ...` is that whole statement, so the parser gives the `else` to the nearest `if`. The for-else form needs the body in braces (or a `break :blk value` expression form).

**What Happened**: Lane mcp1's `Headers.update` (src/devtools/mcp/network.zig) merged a header into a list with exactly that shape. With an empty list nothing was appended and every name and value leaked (DebugAllocator: "leaked ... allocLowerString in update"); with entries it appended the new header once per existing one, sharing one allocation - a double free waiting to happen. Every MCP test that loaded a page failed on the leak.

**Fix**: Find, then act:

```zig
const existing: ?*Header = for (self.list.items) |*h| {
    if (std.mem.eql(u8, h.name, name)) break h;
} else null;
if (existing) |h| { ... } else try self.list.append(allocator, .{ ... });
```

**Takeaway**: **Give a for-else's loop body braces - or compute the match as a `for ... else null` expression first; a bare `if` body steals the `else`.**
