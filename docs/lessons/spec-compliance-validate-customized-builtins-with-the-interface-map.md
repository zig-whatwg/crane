# Spec Compliance: Validate customized built-ins with the interface map

**Date**: 2026-10-18
**Lesson**: Custom-element extends validation must use HTML's element-interface lookup, including obsolete recognized elements.

**Why**: HTML's define algorithm rejects an extends value when its interface is HTMLUnknownElement. This is different from accepting only a separately maintained list of modern tags.

**What Happened**: CustomElementRegistry maintained its own list, which omitted `param` and other recognized obsolete tags. `customElements.define(name, Constructor, {extends: 'param'})` threw NotSupportedError even though Crane already constructed HTMLParamElement and exposed its reflected members. The isolated native regression failed with `param: NotSupportedError`; the upstream HTMLParamElement reaction file passed none of its four subtests.

**Fix**: Keep define step 7.2's valid-custom-element-name rejection, then use `html_core.element_interface.forLocalName` for step 7.3. Test obsolete recognized interfaces, uppercase names, unknown tags, and custom names. Blink's [CustomElementRegistry::DefineInternal](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/custom/custom_element_registry.cc) uses the same design: validate through its element-interface classification.

**Takeaway**: **Use the owning subsystem's classification instead of maintaining a second acceptance list.**
