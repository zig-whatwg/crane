# Codegen: Nullable dictionary members can need a presence bit

**Date**: 2026-10-06
**Lesson**: A nullable dictionary member without a default must preserve absence separately from an explicit null when the consuming algorithm distinguishes them.

**Why**: A generated nullable pointer initialized to null represents two WebIDL inputs with one value. The implementation cannot recover whether script omitted the member or explicitly supplied null.

**What Happened**: `ShadowRootInit.customElementRegistry` was generated as `?*runtime.Instance = null`. DOM's attachShadow steps choose the document registry when that member is absent, and preserve a supplied null. Implementing the method alone could not honor both cases. The original runner failed both ce2-shadow-null-registry probes; source inspection established that the generated representation also prevented the explicit-null fix.

**Fix**: Preserve this member as `webidl.Opt(?*runtime.Instance)` in dictionary codegen. Its outer presence bit selects the default; its inner nullable value represents explicit null. Use the existing dictionary converter's optional-value handling, add the generated dictionary module's WebIDL import dependency, and regenerate from both IDL sources together. Test the generated representation as well as script-visible behavior.

**Takeaway**: **Before writing an algorithm that branches on member presence, verify that codegen preserves the distinction the algorithm needs.**
