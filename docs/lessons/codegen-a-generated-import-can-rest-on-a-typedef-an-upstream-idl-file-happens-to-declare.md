# Codegen: A generated import can rest on a typedef an upstream IDL file happens to declare

**Date**: 2026-10-17
**Lesson**: Every generated interface imported `DOMString` from the typedefs module, and that file existed only because webref's old DOM-Style.idl declared `typedef dom::DOMString DOMString`.

**Why**: writer.zig's `getImportModule` sends DOMString, USVString and ByteString to `typedefs`, on the stated assumption that "they have typedef files that re-export runtime types". Nothing in codegen wrote those files. DOM-Style.idl (DOM Level 2 Style, a long-dead spec webref still crawled) happened to declare one of them, so `typedefs/DOMString.zig` was generated and the assumption held by accident. USVString's and ByteString's imports compiled only because Zig never analyzes an unused declaration.

**What Happened**: The IDL update to webref curated bfbec43f44 dropped DOM-Style.idl. The regeneration was clean and `codegen-check` passed, but the build failed in Element, HTMLIFrameElement, HTMLScriptElement, ShadowRoot and SVGAnimatedString: `root source file struct 'root' has no member named 'DOMString'`. Those are the files whose generated signatures name the bare `DOMString` (the [LegacyNullToEmptyString] and Trusted Types union paths). The other ~1,000 files import it without using it.

**Fix**:
1. `generator.string_typedef_names` lists the three string types. The typedef stage writes a re-export file for each one unless an IDL file declares it (pipeline.zig, after the IR's typedefs).
2. `tests/codegen/string_typedefs_test.zig` generates a fixture that declares none of them and checks each file and its root entry. It was red before the fix.

**Takeaway**: **When a generated file relies on something being generated, codegen must generate it itself. Find out by deleting an upstream file in a test fixture, not by waiting for upstream to delete it.** The same IDL update found a second instance of this. The impls_tmp stub writer names static operations `call_X`, while the binding calls `call_static_X`, so a static stub copied as-is is a lint failure.
