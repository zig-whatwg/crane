# Debugging: A Module Bench Attributes What a Page Profile Cannot

**Date**: 2026-10-25
**Lesson**: A page-level cost regression in one module is attributed fastest by a standalone, optimized bench of that module alone, built twice from the two trees and bisected by edits.

**Why**: A whole-page profile of an optimized runner mixes every subsystem, folds inlined frames and loses the arguments that would say which property or path is slow. An optimizer effect - a recursion that stops inlining - spreads its cost over every caller, so no single frame grows enough to name it.

**What Happened**: Codex row 119's e1+e2 (14 inherited font longhands) cost ci1-image-font-cost's image_computed +0.750 ms (Q212). The page profile showed only that the cascade's compute frames grew 52% while slots grew 7.5%; an allocation probe found no allocation difference; the cost was accepted as "structural per-longhand". Lane cascadefast1 built `src/css` alone (it depends only on `quirks`) into a ReleaseSafe executable - `zig build-exe -O ReleaseSafe -lc --dep css -Mroot=bench.zig --dep quirks -Mcss=<tree>/src/css/root.zig -Mquirks=<tree>/src/quirks/root.zig` - that cascades the page's 1,000 spans, from main and from `git archive lane/integrate src/css src/quirks`. It reproduced the cost (+0.86 ms per 1,000 cascades) in seconds, and one-line edits to the scratch copy split it: about 0.24 ms was the 14 new slots, and about 0.6 ms was one line, `.unavailable => self.compute(l, self.unset(l))` inside computeValue, which made compute and computeValue mutually recursive. LLVM stopped inlining compute and specified into computeAndStore, so every longhand of every element got slower.

**Fix**: Keep the bench in the lane's scratch, build each variant from an exported tree (never edit the real one to experiment), compare medians of many batches, and confirm a mechanism by removing it. Then fix in the real tree, red first. Here: the cascade's fast path (untouched longhands default without the compute walk) and a non-recursive inherit for that arm.

**Takeaway**: **Before calling a cost structural, rebuild the module alone in the release mode and bisect the two trees with one-line edits; a recursion or lost inline costs every caller and shows in no single frame.**
