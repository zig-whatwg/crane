# Codegen: A typedef registered without its type is no type at all

**Date**: 2026-10-04
**Lesson**: The type registry registered every typedef with `underlying_type` null, so the overload tables classified each typedef'd argument as `.other` - a category the overload resolution algorithm never matches.

**Why**: A typedef is only a name. Anything that asks what category a type is in - overload resolution's step 12, distinguishability, a union's flattened member types - must see through it, recursively (CanvasImageSource is a union containing another typedef, HTMLOrSVGImageElement). The writer already recursed through `underlying_type`; nothing set it. An earlier lane set only an `aliases_array` flag beside it, deliberately, because setting the type would change the overload tables - which was the bug.

**What Happened**: drawImage, createImageBitmap, WebGL's bufferData/texImage2D/readPixels/..., WebGPU's setBindGroup/copyBufferToBuffer and MLGraphBuilder.constant had `.other` at a typedef'd index. `bufferData(target, 1024, usage)` found no overload for a number (GLsizeiptr is `long long`): a TypeError for valid calls.

**Fix**: ir.zig sets `underlying_type` when it registers a typedef. The regeneration changed only overload tables (listed in the binding2 merge report). tests/codegen/overload_typedef_kinds_test.zig pins the registry and the tables.

**Takeaway**: **When a generated table classifies types, grep it for the fallback category (`.other`) after every change: each hit is a type the classifier could not see.**
