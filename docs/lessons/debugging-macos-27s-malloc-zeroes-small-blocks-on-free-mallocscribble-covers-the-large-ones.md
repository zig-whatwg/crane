# Debugging: macOS 27's malloc zeroes a small block when it is freed; MallocScribble poisons only the large ones

**Date**: 2026-11-05
**Lesson**: On the pool's macOS 27, a read after `free` (or a C++ `delete`) of a block of up to at least 4 KiB returns zeros past the allocator's free-list header, with or without `MallocScribble=1`. A block of 16 KiB or more keeps its old bytes unless the scribble fills it with 0x55. The scribble also fills every new block with 0xaa.

**Why**: macOS 27's default malloc clears small blocks as it frees them, a hardening of its own. The documented `MallocScribble` (malloc(3): 0x55 on free, 0xaa on allocation) changes what a freed large block holds, and what a fresh block holds at any size. A freed small block it leaves at 0. So a C++ use-after-free of a small object reads null pointers and zero counts. That faults near address 0, or passes a null check, rather than reading stale fields or 0x55.

**What Happened**: Lane poison2 set `MallocScribble=1` for every test child (tools/test_launcher/child.zig, `malloc_scribble`), so that libc memory - v8_wrapper.cpp's new and delete, `std.heap.c_allocator` - is poisoned the way Zig memory is. The fixture freed a 64-byte `c_allocator` block and expected byte 40 to read 0x55. It read 0. A probe on chat.local (macOS 27.0.1) wrote 0x11 into blocks of 16 B to 64 KiB, freed each, and read them back:

| Block size | Default | `MallocScribble=1` |
|---|---|---|
| 16 B, 64 B, 256 B | header at [0] and [8], 0 past it | the same |
| 1 KiB, 4 KiB | 0 | 0 |
| 16 KiB | still 0x11 past the header | 0x55 |
| 64 KiB | still 0x11 | 0x55 |
| a fresh 64 B block | 0 | 0xaa |

**Fix**: The fixture's libc case frees a 64 KiB block. tests/AGENTS.md and the `malloc_scribble` doc say what the scribble adds on these hosts: 0x55 in freed blocks of 16 KiB and up, and 0xaa in every new block, so a read before the first write reads 0xaa, not 0.

**Takeaway**: **On macOS 27, a crash at a small offset from 0 in C++ or `c_allocator` memory can be a use-after-free of a small block: its allocator zeroed the block on free. Only large blocks keep stale bytes, and MallocScribble turns those into 0x55.**
