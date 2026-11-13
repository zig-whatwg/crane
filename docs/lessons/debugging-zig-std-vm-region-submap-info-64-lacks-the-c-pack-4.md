# Debugging: Zig's std vm_region_submap_info_64 lacks the C header's pack(4) - read a region's VM tag through VM_REGION_EXTENDED_INFO

**Date**: 2026-11-10
**Lesson**: `std.c.vm_region_submap_info_64` (Zig 0.17.1-dev+77c319a0f0) is a plain `extern struct`, but XNU declares it under `#pragma pack(push, 4)`: its `offset: u64` sits at byte 12 in C and at 16 in Zig, so every field after it - `user_tag` among them - is read 4 bytes off. A tagged region reads tag 0, and nothing fails.

**Why**: Mach's region-info structs are packed to 4 bytes (mach/vm_region.h) so they pass as arrays of `natural_t`. An `extern struct` in Zig uses C's natural alignment, which is right for every struct but the packed ones; the count (`SUBMAP_INFO_COUNT_64`, sizeof / 4) is then also wrong.

**What Happened**: Lane h1's test that the platform's address-space labels reach the OS's tools (tests/platform/h1_address_space_test.zig) read `user_tag` with `mach_vm_region_recurse` and `vm_region_submap_info_64`: "expected 240, found 0" for a range mmap'ed with VM_MAKE_TAG(240), on chat.local. vmmap showed the tag (the oss review's probe P2 had measured it), so the mapping was right and the read was wrong.

**Fix**: `mach_vm_region` with the `VM_REGION_EXTENDED_INFO` flavor (13): `vm_region_extended_info` has only 4-byte fields after `protection`, so its layout is the same packed or not, and it carries `user_tag` too.

```zig
var info: std.c.vm_region_extended_info = undefined;
var count: std.c.mach_msg_type_number_t = std.c.VM.REGION.EXTENDED_INFO_COUNT;
var object_name: std.c.mach_port_t = 0;
_ = std.c.mach_vm_region(std.c.mach_task_self(), &address, &size, std.c.VM.REGION.EXTENDED_INFO, @ptrCast(&info), &count, &object_name);
// info.user_tag
```

**Takeaway**: **A Mach struct declared under `#pragma pack(4)` is not a Zig `extern struct`: check a std transcription's field offsets against the SDK header before trusting a value it reads, or use a flavor whose fields are all 4 bytes.**
