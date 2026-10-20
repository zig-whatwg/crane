# Spec Compliance: Dataset writes use the null namespace

**Date**: 2026-10-20
**Lesson**: Resolve a dataset setter's browser split against the specification's history before choosing the attribute operation.

**Why**: `setAttribute` finds the first attribute with a matching qualified name, including namespaced attributes. DOM's “set an attribute value” instead uses a namespace/local-name pair, defaulting the namespace to null. These operations are observably different even when both receive the same string.

**What Happened**: `html/dom/elements/global-attributes/custom-attrs.html` created two namespaced `data-my-custom-attr` attributes, then assigned `dataset.myCustomAttr`. Crane changed the first attribute and retained two attributes, instead of creating a third with no namespace. Chrome and Safari also failed the test; Firefox passed it (aligned stable runs 6244794098778112, 5917475882663936, 5156841570172928).

The [HTML change of 2016-05-19](https://github.com/whatwg/html/commit/177b8a506931a51ecaeae71d4518431ee01ce783) replaced the old setter prose with the explicit DOM attribute-value algorithm. [Blink's SetItem](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/dom/dataset_dom_string_map.cc) and [WebKit's setNamedItem](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/DatasetDOMStringMap.cpp) still use setAttribute. This is a newer-spec case implemented by one browser: golden rule 2 chooses that specification over the browser majority.

**Fix**: After the existing property-name conversion and validation, invoke `dom.element_attributes.set` with default options. Element's existing hook changes the null-namespace attribute and emits mutation records and custom-element reactions. Keep the getter and deleter's separately specified behavior. Test same-name attributes in multiple namespaces and the mutation records' namespace/oldValue.

**Takeaway**: **A browser majority is insufficient evidence when a specification change explains the split and one browser implements the newer algorithm.**
