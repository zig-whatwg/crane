# Spec Compliance: A union member of a union is flattened into it

**Date**: 2026-10-12
**Lesson**: A WebIDL union whose member is itself a union accepts that member's interfaces too; a conversion that looks only at its own `*runtime.Instance` arms rejects them with a TypeError.

**Why**: WebIDL 2.13.29 defines a union's flattened member types: a union member contributes its members. Codegen keeps such a member as a nested Zig union (CanvasImageSource's first arm is `htmlor_svgimage_element: typedefs.HTMLOrSVGImageElement`), and the V8 adapter's `platformObjectArm` tried only arms typed `*runtime.Instance`.

**What Happened**: With drawImage() implemented (lane imgdec), every `context.drawImage(img, 0, 0)` threw "TypeError: TypeError" before the impl ran: an img implements none of CanvasImageSource's own interface arms (video, canvas, ImageBitmap, OffscreenCanvas, VideoFrame), only HTMLOrSVGImageElement's. The stub that returned NotImplemented had hidden it.

**Fix**: `checkedArm` and `uncheckedArm` (src/runtime/engines/v8/conversions.zig) recurse into any arm whose type is an interface union (`isInterfaceUnion`), in member order, checked arms before unchecked ones; tests/v8/union_arm_interface_test.zig pins that the nested arms map to interfaces.

**Takeaway**: **When a binding conversion handles a union, handle nested unions as their flattened members - and when a newly implemented method throws TypeError before its first line, suspect the argument conversion, not the method.**
