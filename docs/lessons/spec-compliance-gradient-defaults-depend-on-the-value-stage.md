# Spec Compliance: Gradient defaults depend on the value stage

**Date**: 2026-10-23
**Lesson**: Classify the original color graph separately for specified and computed gradient serialization.

**Why**: Resolved color channels do not identify the syntax that determines a gradient's default interpolation space. A relative color and an absolute modern color can resolve to identical components while retaining different classifications.

**What Happened**: Three-browser probes found that currentcolor and relative colors are legacy at both stages, color-mix changes from legacy to modern, and computed light-dark takes its selected branch's class. No one browser implements the entire majority rule: the combined rule uses Chrome's selected branch, Firefox/Safari's relative colors, and Chrome/Firefox's computed mixes. Contrast-color is legacy at both stages in all three.

**Fix**: Query the original Color using a stage argument. Computed classification also receives the ELEMENT's used scheme, before color resolution replaces the original graph. Do not infer syntax by inspecting byte colors or serializing and reparsing them. Test both stages, including a child's scheme differing from its parent and root.

**Takeaway**: **A serialization default can depend on original syntax and the value stage even when the final components are identical.**
