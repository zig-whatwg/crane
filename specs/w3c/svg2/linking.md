# Chapter 16: Linking

::: }}
[Overview](Overview.html) · [Previous](interact.html) · [Next](idl.html)
· [Elements](eltindex.html) · [Attributes](attindex.html) ·
[Properties](propidx.html)

## Contents

1. 1. [[16.1.] References](linking.html#URLReference)
 1. [[16.1.1.] Overview](linking.html#HeadOverview)
 2. [[16.1.2.] Definitions](linking.html#definitions)
 3. [[16.1.3.] URLs and URIs](linking.html#URLandURI)
 4. [[16.1.4.] Syntactic forms: URL and
 \<url\>](linking.html#URLforms)
 5. [[16.1.5.] URL reference
 attributes](linking.html#linkRefAttrs)
 6. [[16.1.6.] Deprecated XLink URL reference
 attributes](linking.html#XLinkRefAttrs)
 7. [[16.1.7.] Processing of URL
 references](linking.html#processingURL)
 1. [[16.1.7.1.] Generating the absolute
 URL](linking.html#processingURL-absolute)
 2. [[16.1.7.2.] Fetching the
 document](linking.html#processingURL-fetch)
 3. [[16.1.7.3.] Processing the subresource
 document](linking.html#processingURL-parsing)
 4. [[16.1.7.4.] Identifying the target
 element](linking.html#processingURL-target)
 5. [[16.1.7.5.] Valid URL
 targets](linking.html#processingURL-validity)
 2. [[16.2.] Links out of SVG content: the
 ['a'] element](linking.html#Links)
 3. [[16.3.] Linking into SVG content: URL fragments and SVG
 views](linking.html#LinksIntoSVG)
 1. [[16.3.1.] SVG fragment
 identifiers](linking.html#SVGFragmentIdentifiers)
 2. [[16.3.2.] SVG fragment identifiers
 definitions](linking.html#SVGFragmentIdentifiersDefinitions)
 3. [[16.3.3.] Predefined views: the
 ['view'] element](linking.html#ViewElement)
 4. [[16.4.] DOM interfaces](linking.html#DOMInterfaces)
 1. [[16.4.1.] Interface
 SVGAElement](linking.html#InterfaceSVGAElement)
 2. [[16.4.2.] Interface
 SVGViewElement](linking.html#InterfaceSVGViewElement)

::::: ready-for-WG-review
## 16.1. References
### 16.1.1. Overview
On the Internet, resources are identified using
[URLs](linking.html#TermURLReference) (Internationalized Resource
Identifiers). For example, an SVG file called someDrawing.svg located at
http://example.com might have the following
[URL](linking.html#TermURLReference):

 http://example.com/someDrawing.svg

An [URL](linking.html#TermURLReference) can also address a particular
element within an XML document by including an
[URL](linking.html#TermURLReference) fragment identifier as part of the
[URL](linking.html#TermURLReference). An
[URL](linking.html#TermURLReference) which includes an
[URL](linking.html#TermURLReference) fragment identifier consists of an
optional base [URL](linking.html#TermURLReference), followed by a \"#\"
character, followed by the [URL](linking.html#TermURLReference) fragment
identifier. For example, the following
[URL](linking.html#TermURLReference) can be used to specify the element
whose ID is \"Lamppost\" within file someDrawing.svg:

 http://example.com/someDrawing.svg#Lamppost

### 16.1.2. Definitions
[URL reference]
: An URL reference is an Internationalized Resource Identifier, as
 defined in [Internationalized Resource
 Identifiers](http://www.ietf.org/rfc/rfc3987.txt)
 \[[rfc3987](refs.html#ref-rfc3987)\]. See
 [References](linking.html#URLReference) and [References and the
 ['defs'] element](struct.html#Head).

[URL reference with fragment identifier]
: An Internationalized Resource Identifier
 \[[rfc3987](refs.html#ref-rfc3987)\] that can include an
 \<absoluteURL\> or \<relativeURL\> and a identifier of the fragment
 in that resource. See [References and the ['defs']
 element](struct.html#Head). URL reference with fragment identifiers
 are commonly used to reference [paint servers](pservers.html).

[external file reference]
: A [URL reference](linking.html#TermURLReference) or [URL reference
 with fragment
 identifier](linking.html#TermURLReferenceWithFragmentIdentifier)
 which refers to a resource that is not part of the current document.

[same-document URL reference]
: A [URL reference with fragment
 identifier](linking.html#TermURLReferenceWithFragmentIdentifier)
 where the non-fragment part of the URL refers to the current
 document.

[data URL]
: A [URL reference](linking.html#TermURLReference) to an embedded
 document specified using the [\"data\" URL
 scheme](http://www.ietf.org/rfc/rfc2397.txt)
 \[[rfc2397](refs.html#ref-rfc2397)\]. Data URL references are
 neither [external file
 references](linking.html#TermExternalReference) nor [same-document
 URL references](linking.html#TermSameDocumentURL).

[circular reference]
: [URL references](#TermURLReference) that directly or indirectly
 reference themselves are treated as invalid circular references.
 What constitutes a circular reference will depend on how the
 referenced resource is used, and may include a reference to an
 ancestor of the current element.

[unresolved reference]
: A reference that is still being processed, and has not yet resulted
 in either an error or an identified resource.

[invalid reference]

: Any of the following are invalid references:

 - A circular reference.
 - A [URL reference](#TermURLReference) that results in an error
 during [processing](#processingURL).
 - A [URL reference](#TermURLReference) that cannot be resolved.
 - A [URL references](#TermURLReference) to elements which are
 inappropriate targets for the given reference shall be treated as
 invalid references (see [Valid URL
 targets](#processingURL-validity) for appropriate targets). For
 example, the
 [clip-path](https://drafts.fxtf.org/css-masking-1/#the-clip-path)
 property can only refer to
 ['[clipPath](https://drafts.fxtf.org/css-masking-1/#ClipPathElement)']
 elements. The property setting
 [clip-path:url(#MyElement)] is an invalid reference
 if the referenced element is not a
 ['[clipPath](https://drafts.fxtf.org/css-masking-1/#ClipPathElement)'].

 Invalid references may or may not be an error (see [Error
 processing](conform.html#ErrorProcessing)), depending on whether the
 referencing property or attribute defines fallback behavior.

### 16.1.3. URLs and URIs
Internationalized Resource Identifiers
([URLs](linking.html#TermURLReference)) are a more generalized
complement to Uniform Resource Identifiers (URIs). An
[URL](linking.html#TermURLReference) is a sequence of characters from
the Universal Character Set \[[UNICODE](refs.html#ref-unicode)\]. A URI
is constructed from a much more restricted set of characters. All URIs
are already conformant [URLs](linking.html#TermURLReference). A mapping
from [URLs](linking.html#TermURLReference) to URIs is defined by the
[URL](linking.html#TermURLReference) specification, which means that
URLs can be used instead of URIs in XML documents, to identify
resources. [URLs](linking.html#TermURLReference) can be converted to
URIs for resolution on a network, if the protocol does not support
[URLs](linking.html#TermURLReference) directly.

Previous versions of SVG, following XLink, defined an URL reference type
as a URI *or as a sequence of characters which must result in an URL
after a particular escaping procedure was applied*. The escaping
procedure was repeated in the XLink 1.0 specification
\[[xlink](refs.html#ref-xlink)\], and in the W3C XML Schema Part 2:
Datatypes specification \[[xmlschema-2](refs.html#ref-xmlschema-2)\].
This copying introduced the possibility of error and divergence, but was
done because the [URL](linking.html#TermURLReference) specification was
not yet standardized.

In this specification, the correct term
[URL](linking.html#TermURLReference) is used for this \"URI or sequence
of characters plus an algorithm\" and the escaping method, which turns
URLs into URIs, is defined by reference to the [URL
specification](http://www.ietf.org/rfc/rfc3987.txt)
\[[rfc3987](refs.html#ref-rfc3987)\], which has since become an IETF
Proposed Standard. Other W3C specifications are expected to be revised
over time to remove these duplicate descriptions of the escaping
procedure and to refer to [URL](linking.html#TermURLReference) directly.

### 16.1.4. Syntactic forms: URL and \<url\>
In SVG, most structural relationships between two elements are specified
using a [URL](linking.html#TermURLReference) value in an
[['href']](#linkRefAttrs) attribute.

To describe linking relationships, this specification uses two different
data types in attribute and property values:
[URL](linking.html#TermURLReference) and
[\<url\>](https://www.w3.org/TR/css3-values/#url-value). The linking
guidelines in this chapter apply to URLs specified with either syntax.

The [URL](linking.html#TermURLReference) data type is a simple URL
string. In SVG, most structural relationships between two elements are
specified using a [URL](linking.html#TermURLReference) value in an
[['href']](#linkRefAttrs) attribute.

[\<url\>](https://www.w3.org/TR/css3-values/#url-value) is different
from [URL](linking.html#TermURLReference) and represents a CSS `url()`
function value. (See CSS Values and Units for further details
\[[css-values](refs.html#ref-css-values-3)\]).
[\<url\>](https://www.w3.org/TR/css3-values/#url-value)s may be used for
[presentation attributes](styling.html#TermPresentationAttribute) and
their corresponding CSS properties
\[[css-values](refs.html#ref-css-values-3)\].

[URL](linking.html#TermURLReference) is not a valid value for
[presentation attributes](styling.html#TermPresentationAttribute) for
structural relationships purposes. No non-[presentation
attribute](styling.html#TermPresentationAttribute) allows
[\<url\>](https://www.w3.org/TR/css3-values/#url-value) as value.

SVG makes extensive use of [URL](linking.html#TermURLReference)
references, both absolute and relative, to other objects. For example, a
['[linearGradient](pservers.html#LinearGradientElement)']
element may be based on another gradient element, so that only the
differences between the two need to be specified, by referencing the
source gradient with a URL in the
['[href](pservers.html#LinearGradientElementHrefAttribute)']
attribute:

``` xml
<linearGradient id="SourceGradient">...</linearGradient>
<linearGradient id="MyGradient"
 href="#SourceGradient">...</linearGradient>
```

To fill a rectangle with that gradient, the value of the rectangle\'s
[fill](painting.html#FillProperty) property may be set so as
to include a URL reference to the relevant
['[linearGradient](pservers.html#LinearGradientElement)']
element; here is an example:

``` xml
<rect fill="url(#MyGradient)"/>
```

### 16.1.5. URL reference attributes
[URL references](linking.html#TermURLReference) are normally specified
with an ['href'] attribute. The value of this attribute
forms a reference for the desired resource (or secondary resource, if
there is a fragment identifier). The value of the ['href']
attribute must be a URL.

Because it is impractical for any application to check that a value is
an [URL reference](linking.html#TermURLReference), this specification
follows the lead of the [URL
Specification](http://www.ietf.org/rfc/rfc3986.txt) in this matter and
imposes no such conformance testing requirement on [SVG authoring
tools](conform.html#TermSVGAuthoringTool). An invalid URL does not make
an SVG document non-conforming. SVG user agents are only required to
process URLs when needed, as specified in [Processing of URL
references](#processingURL).

### 16.1.6. Deprecated XLink URL reference attributes
In previous versions of SVG, the ['href'] attribute was
specified in the XLink namespace \[[xlink](refs.html#ref-xlink)\]
namespace. This usage is now deprecated and instead [URL
references](linking.html#TermURLReference) should be specified using the
['href'] attribute without a namespace.

For backwards compatibility, the deprecated
['[xlink:href](linking.html#XLinkHrefAttribute)'] attribute
is defined below along with the
['[xlink:title](linking.html#XLinkTitleAttribute)']
attribute which has also been deprecated.

*Attribute definitions:*

 Name Value Initial value Animatable
 ------------------------------------------------------------------------------------------------------------------------------------------------------------- -------------------------------------------------- --------------- -------------
 [xlink:href] URL [\[URL\]](types.html#attribute-url) (none) (see below)

For backwards compatibility, elements with an ['href']
attribute also recognize an ['href'] attribute in the XLink
namespace \[[xlink](refs.html#ref-xlink)\].

When the ['href'] attribute is present in *both* the XLink
namespace and without a namespace, the value of the attribute without a
namespace shall be used. The attribute in the XLink namespace shall be
ignored.

A [conforming SVG generator](conform.html#ConformingSVGGenerators) must
generate ['href'] attributes without a namespace. However,
it may *also* generate ['href'] attributes in the XLink
namespace to provide backwards compatibility.

This attribute is
[Animatable](https://svgwg.org/specs/animations/#Animatable) if and only
if the corresponding ['href'] attribute is defined to be
animatable.

 Name Value Initial value Animatable
 --------------------------------------------------------------------------------------------------------------------------------------------------------------- -------------- --------------- ------------
 [xlink:title] \<anything\> (none) no

Deprecated attribute to describe the meaning of a link or resource in a
human-readable fashion. New content should use a
[['title']](struct.html#TitleElement) child element
rather than a ['xlink:title'] attribute.

The use of this information is highly dependent on the type of
processing being done. It may be used, for example, to make titles
available to applications used by visually impaired users, or to create
a table of links, or to present help text that appears when a user lets
a mouse pointer hover over a starting resource.

The ['title'] attribute, if used, must be in the XLink
namespace. Refer to the [XML Linking Language
(XLink)](https://www.w3.org/TR/xlink/) \[[xlink](refs.html#ref-xlink)\].

When using the deprecated XLink attributes
['[xlink:href](linking.html#XLinkHrefAttribute)'] or
['[xlink:title](linking.html#XLinkTitleAttribute)'] an
explicit XLink namespace declaration must be provided
\[[xml-names](refs.html#ref-xml-names)\], One simple way to provide such
an XLink namespace declaration is to include an ['xmlns']
attribute for the XLink namespace on the
['[svg](struct.html#SVGElement)'] element for content
that uses XLink attributes. For example:

``` xml

<svg xmlns:xlink="http://www.w3.org/1999/xlink" ...>
 <image xlink:href="foo.png" .../>
</svg>
```

### 16.1.7. Processing of URL references
URLs are processed to identify a resource at the time they are needed,
as follows:

- For the ['[href](linking.html#AElementHrefAttribute)']
 attribute of the ['[a](linking.html#AElement)']
 element, at the time the link is activated by the user.
- For all other ['href'] attributes, at the time the element
 is [connected](https://dom.spec.whatwg.org/#connected) to a document,
 or at the time when the attribute is set, whichever is later.
- For source URLs on embedded HTML media elements, as required based on
 source selection rules [in the HTML
 specification](https://html.spec.whatwg.org/multipage/media.html#media-elements)
 \[[HTML](refs.html#ref-html)\].
- For all presentation attributes and style properties, at the time the
 property is required for rendering an element.

Legacy ['[xlink:href](linking.html#XLinkHrefAttribute)']
attributes are processed at the time a corresponding
['href'] attribute would be processed, but only if no such
['href'] attribute exists on the element.

Processing a URL involves three steps: generating the absolute URL;
fetching the document (if required); identifying the target element (if
required).

A URL reference is [unresolved](linking.html#TermUnresolvedReference)
until processing either results in an [invalid
reference](linking.html#TermInvalidReference) or in the identification
of the target resource. Unresolved references in the non-presentation
attributes of [structurally external
elements](struct.html#TermStructurallyExternalElement) prevent the [load
event](interact.html#LoadEvent) from firing. User agents may place time
limits on the resolution of references that are not [same-document URL
references](linking.html#TermSameDocumentURL), after which the reference
is treated as a network error (and therefore as an [invalid
reference](linking.html#TermInvalidReference)).

For [same-document URL references](linking.html#TermSameDocumentURL) in
a dynamic document, modifications or animations of attributes or
properties, or removal of elements from the DOM, may cause an URL
reference to return to the
[unresolved](linking.html#TermUnresolvedReference) state. The user agent
must once again attempt to resolve the URI to identify the referenced
resource.

#### 16.1.7.1. Generating the absolute URL
If the [URL reference](linking.html#TermURLReference) is relative, its
absolute version must be computed before use. The absolute URL should be
generated using one of the following methods:

- as described in [CSS Values and
 Units](https://drafts.csswg.org/css-values/#local-urls) if the
 reference occurs in a CSS file or in a [presentation
 attribute](styling.html#TermPresentationAttribute)
 \[[css-values](refs.html#ref-css-values-3)\]
- as described in [XML Base](https://www.w3.org/TR/xmlbase/) before use
 \[[xmlbase](refs.html#ref-xmlbase)\] if the reference occurs in any
 other attribute in an XML document
- as described in the [HTML
 specification](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#resolving-urls)
 if the reference occurs in a non-presentation attribute in an HTML
 document that is not an XML document \[[HTML](refs.html#ref-html)\]

The [['xml:base']](https://www.w3.org/TR/xmlbase/#syntax)
attribute will only have an effect in XML documents; this includes SVG
documents and XHTML documents but not HTML documents that are not XML.
In contrast, a
[`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element)
element affects relative URLs in any SVG or HTML document, by altering
the [document base
URL](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#document-base-url).

If the protocol, such as HTTP, does not support
[URLs](linking.html#TermURLReference) directly, the
[URL](linking.html#TermURLReference) must be converted to a URI by the
user agent, as described in section 3.1 of the [URL
specification](http://www.ietf.org/rfc/rfc3987.txt)
\[[rfc3987](refs.html#ref-rfc3987)\].

After generating the absolute URL:

- If the URL is being processed following the activation of a link, the
 user agent must follow the [algorithm for navigating to a
 URL](https://html.spec.whatwg.org/multipage/browsing-the-web.html#browsing-the-web)
 described in the HTML specification \[[HTML](refs.html#ref-html)\].
 The outcome of this algorithm varies depending on the
 ['[target](linking.html#AElementTargetAttribute)']
 browsing context and security restrictions between browsing contexts,
 and on whether the link is to the same document as is currently
 contained in that browsing context (in which case the fragment is
 navigated without reloading the document). If the document that was
 navigated was an SVG document, then adjust the target behavior as
 described in [Linking into SVG content](#LinksIntoSVG).

- If the URL being processed is only [valid](#processingURL-validity) if
 it refers to a complete document file (such as the
 ['href'] attribute of an
 ['[image](embedded.html#ImageElement)'] and
 ['[script](interact.html#ScriptElement)'] element),
 continue as indicated in [Fetching the document](#processingURL-fetch)
 (regardless of whether the URL is to the same document or not).

- In all other cases, the URL is for a resource to be used in this SVG
 document. The user agent must parse the URL to separate out the target
 fragment from the rest of the URL, and compare it with the document
 base URL. If all parts other than the target fragment are equal, this
 is a [same-document URL reference](linking.html#TermSameDocumentURL),
 and processing the URL must continue as indicated in [Identifying the
 target element](#processingURL-target) with the current document as
 the referenced document.

- Otherwise, the URL references a separate document, and the user agent
 must continue processing the URL as indicated in [Fetching the
 document](#processingURL-fetch).

As defined in [CSS Values and
Units](https://drafts.csswg.org/css-values/#local-urls), a fragment-only
URL in a style property must be treated as a [same-document URL
reference](linking.html#TermSameDocumentURL), regardless of the file in
which the property was declared.

#### 16.1.7.2. Fetching the document
SVG properties and attributes may reference other documents. When
processing such a URL, the user agent should fetch the referenced
document as described in this section, except under the following
conditions:

- If the URL reference is from the [href] attribute on [SVG
 animation
 elements](https://svgwg.org/specs/animations/#TargetElement), only
 [same-document URL](linking.html#TermSameDocumentURL) references are
 allowed \[[svg-animation](refs.html#ref-svg-animation)\]. A URL
 referring to a different document is invalid and the document must not
 be fetched.

- If the document containing the reference is being processed in [secure
 static mode](conform.html#secure-static-mode) or [secure animated
 mode](conform.html#secure-animated-mode), [external file
 references](linking.html#TermExternalReference) are disallowed. Unless
 the reference is a [data URL](linking.html#TermDataURL), the user
 agent must treat the reference as if there was a network error, making
 this an [invalid reference](linking.html#TermInvalidReference).

- If any other security restrictions on the browsing context or user
 agent prevent accessing the external file, then the user agent must
 treat the reference as if there was a network error.

When fetching external resources from the Internet, user agents must use
a [potentially CORS-enabled
request](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#create-a-potential-cors-request)
as defined in HTML \[[HTML](refs.html#ref-html)\] with the
*corsAttributeState* as follows:

- For an ['href'] reference on an
 ['[image](embedded.html#ImageElement)'] element or
 ['[script](interact.html#ScriptElement)'] element, the
 CORS state specified by the
 ['[crossorigin](embedded.html#ImageElementCrossoriginAttribute)']
 attribute.
- For a reference from a style property or presentation attribute, the
 \"anonymous\" state.
- For all other references, the \"no-cors\" state.

[`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element)

The request\'s *origin* is computed using the [same rules as
HTML](https://fetch.spec.whatwg.org/#concept-cors-check), with an SVG
['[script](interact.html#ScriptElement)'] element treated
like an HTML `script` element, and an SVG
['[image](embedded.html#ImageElement)'] element treated
like an HTML `img` element. The *default origin behaviour* must be set
to *taint*.

A future SVG specification may enable CORS references on other SVG
elements with ['href'] attributes.

If the fetching algorithm results in an error or an empty response body,
the reference URL is treated as an [invalid
reference](linking.html#TermInvalidReference).

If a valid response is returned, and the [valid URL
targets](#processingURL-validity) for the reference include specific
element types, the user agent must continue by [Processing the
subresource document](#processingURL-parsing). Otherwise (if only
entire-document the URL references are valid), then the fetched document
is the referenced resource.

#### 16.1.7.3. Processing the subresource document
Otherwise, the subresource must be parsed to identify the target
element. If the fetched document is a type that the user agent can parse
to create a document object model, it must process it in [secure static
mode](conform.html#secure-static-mode) (meaning, do not fetch any
additional external resources and do not run scripts or play
animations). The document model generated for an external subresource
reference must be immutable (read-only) and cannot be modified.

If a document object model can be generated from the fetched file,
processing the URL must continue as indicated in [Identifying the target
element](#processingURL-target) with the parsed subresource document as
the referenced document. The user agent may commence the
target-identification process prior to completely parsing the document.

User agents may maintain a list of external resource URLs and their
associated parsed documents, and may re-use the documents for subsequent
references, so long as doing so does not violate the processing mode,
caching, and CORS requirements on the resource.

#### 16.1.7.4. Identifying the target element
For URL references to a specific element, whether the reference is valid
depends on whether the element can be located within the referenced
document and whether it is of an allowed type.

Using the referenced document identified in previous processing steps
(either an external subresource document or the current document), the
target element is identified as follows:

- If the URL does not specify a specific element in a target fragment,
 the target element is the root element of the referenced document.

- Otherwise, the URL targets a specific element. If a matching element
 currently exists in the referenced document, then it is the target
 element.

- Otherwise, there is no currently matching element. If the referenced
 document is immutable, then the URL reference is
 [invalid](types.html#TermInvalidValue). An external subresource
 document is always immutable once fully parsed; the current document
 is also immutable once parsed if it is being processed in any mode
 other than [dynamic interactive
 mode](conform.html#dynamic-interactive-mode).

- Otherwise, observe mutations to the referenced document until the URL
 can be successfully resolved to define a target element, or until the
 document becomes immutable (e.g., a non-dynamic document finishes
 parsing).

The target element provides the referenced resource if (and only if) it
is a [valid URL target](#processingURL-validity) for the reference.

#### 16.1.7.5. Valid URL targets
The valid target element types for ['href'] (or
['[xlink:href](linking.html#XLinkHrefAttribute)'])
attributes are based on the element that has the attribute, as follows:

- the ['[a](linking.html#AElement)'] element can
 reference any local or non-local resource
- the ['[image](embedded.html#ImageElement)'] element
 must reference a document that can be processed as an image
- the
 ['[linearGradient](pservers.html#LinearGradientElement)']
 element must reference a different
 ['[linearGradient](pservers.html#LinearGradientElement)']
 or
 ['[radialGradient](pservers.html#RadialGradientElement)']
 element
- the ['[pattern](pservers.html#PatternElement)'] element
 must reference another
 ['[pattern](pservers.html#PatternElement)'] element
- the
 ['[radialGradient](pservers.html#RadialGradientElement)']
 element must reference a
 ['[linearGradient](pservers.html#LinearGradientElement)']
 or another
 ['[radialGradient](pservers.html#RadialGradientElement)']
 element
- the ['[script](interact.html#ScriptElement)'] element
 must reference an external document that provides the script content
- the ['[textPath](text.html#TextPathElement)'] element
 must reference an element type that implements the
 [SVGGeometryElement](types.html#InterfaceSVGGeometryElement)
 interface
- the ['[use](struct.html#UseElement)'] element must
 reference an SVG-namespaced element

The valid target element types for style properties defined in this
specification are as follows:

- the [fill](painting.html#FillProperty) property (see
 [Specifying paint](painting.html#SpecifyingPaint) for reference rules)
- the [marker](painting.html#MarkerProperty),
 [marker-start](painting.html#MarkerStartProperty),
 [marker-mid](painting.html#MarkerMidProperty) and
 [marker-end](painting.html#MarkerEndProperty) properties
 must reference a
 ['[marker](painting.html#MarkerElement)'] element.
- the [shape-inside](text.html#TextShapeInside) and
 [shape-subtract](text.html#TextShapeSubtract) properties
 must reference an element type that implements the
 [SVGGeometryElement](types.html#InterfaceSVGGeometryElement)
 interface, or a document that can be processed as an image
- the [stroke](painting.html#StrokeProperty) property (see
 [Specifying paint](painting.html#SpecifyingPaint) for reference rules)

For references that allow either a reference to a target element, or to
an image file (such as the
[shape-inside](text.html#TextShapeInside),
[shape-subtract](text.html#TextShapeSubtract), and
[mask](https://drafts.fxtf.org/css-masking-1/#propdef-mask)
properties), the user agent must identify the target element and
determine whether it is a valid target. If the resolved target element
is not an allowed element type, the referenced resource is the entire
document file; the target fragment is used in processing that file as
with any other image.

In all other cases, if the resolved target element type (or document
type) is not allowed for the URL reference, it is an [invalid
reference](linking.html#TermInvalidReference).

## 16.2. Links out of SVG content: the ['a'] element
SVG provides an ['[a](linking.html#AElement)'] element,
to indicate links (also known as *hyperlinks* or *Web links*). An
['[a](linking.html#AElement)'] element forms a link if it
has a ['[href](linking.html#AElementHrefAttribute)'] or
['[xlink:href](linking.html#XLinkHrefAttribute)'] attribute;
without these attributes the
['[a](linking.html#AElement)'] element is an inactive
placeholder for a link.

SVG 1.1 defined links in terms of the XLink specification
(\[[XLink](https://www.w3.org/TR/2001/REC-xlink-20010627/)\]), using
attributes defined in the XLink namespace. SVG 2 uses an alternative set
of attributes in the default namespace that are consistent with HTML
links, and [deprecates the XLink attributes](#XLinkRefAttrs).

The ['[a](linking.html#AElement)'] element may contain
any element that its parent may contain, except for another
['[a](linking.html#AElement)'] element; the same element
is used for both graphical and textual linked content. Links may not be
nested; if an ['[a](linking.html#AElement)'] element is a
descendent of another hyperlink element (whether in the SVG namespace or
another namespace), user agents must ignore its href attribute and treat
it as inactive. The invalid
['[a](linking.html#AElement)'] element must still be
rendered as a generic container element.

The rendering of invalid nested links is at
risk, and will likely be synchronized with any decisions regarding the
rendering of unknown elements.

For pointer events processing, a linked hit region is defined for each
separate rendered element contained within the
['[a](linking.html#AElement)'] element (according to the
value of their
[pointer-events](interact.html#PointerEventsProperty)
property), rather than for the bounding box of the
['[a](linking.html#AElement)'] element itself. User
agents must also ensure that all links are
[focusable](interact.html#TermFocusable) and can be activated by
keyboard commands.

The remote resource (the destination for the link) is defined by a
[URL](linking.html#TermURLReference) specified by the
['[href](linking.html#AElementHrefAttribute)'] attribute on
the ['[a](linking.html#AElement)'] element. The remote
resource may be any Web resource (e.g., an image, a video clip, a sound
bite, a program, another SVG document, an HTML document, an element
within the current document, an element within a different document,
etc.). In response to user activation of a link (by clicking with the
mouse, through keyboard input, voice commands, etc.), user agents should
attempt to fetch the specified resource document and either display it
or make it available as a downloaded file.

[Example link01] assigns a link to an ellipse.

``` xml
<?xml version="1.0" standalone="no"?>
<svg width="5cm" height="3cm" viewBox="0 0 5 3" version="1.1"
 xmlns="http://www.w3.org/2000/svg">
 <desc>Example link01 - a link on an ellipse
 </desc>
 <rect x=".01" y=".01" width="4.98" height="2.98"
 fill="none" stroke="blue" stroke-width=".03"/>
 <a href="http://www.w3.org">
 <ellipse cx="2.5" cy="1.5" rx="2" ry="1"
 fill="red" />
 </a>
</svg>
```

![Example link01 --- a link on an ellipse](images/linking/link01.png)

Example link01

[View this example as SVG (SVG-enabled browsers
only)](images/linking/link01.svg)

If the above SVG file is viewed by a user agent that supports both SVG
and HTML, then clicking on the ellipse will cause the current window or
frame to be replaced by the W3C home page.

:::: element-summary
::: element-summary-name
['[a]']

Categories:
: [Container element](struct.html#TermContainerElement), [renderable
 element](render.html#TermRenderableElement)

Content model:
: Descriptive content, plus any element or text allowed by its
 parent\'s content model, except for another a element. If the parent
 is a switch element, use the content model of the nearest ancestor
 that isn\'t a switch.

Attributes:

: - [aria attributes](struct.html#TermARIAAttribute)[ ---
 ['[aria-activedescendant](https://www.w3.org/TR/wai-aria-1.1/#aria-activedescendant)'],
 ['[aria-atomic](https://www.w3.org/TR/wai-aria-1.1/#aria-atomic)'],
 ['[aria-autocomplete](https://www.w3.org/TR/wai-aria-1.1/#aria-autocomplete)'],
 ['[aria-busy](https://www.w3.org/TR/wai-aria-1.1/#aria-busy)'],
 ['[aria-checked](https://www.w3.org/TR/wai-aria-1.1/#aria-checked)'],
 ['[aria-colcount](https://www.w3.org/TR/wai-aria-1.1/#aria-colcount)'],
 ['[aria-colindex](https://www.w3.org/TR/wai-aria-1.1/#aria-colindex)'],
 ['[aria-colspan](https://www.w3.org/TR/wai-aria-1.1/#aria-colspan)'],
 ['[aria-controls](https://www.w3.org/TR/wai-aria-1.1/#aria-controls)'],
 ['[aria-current](https://www.w3.org/TR/wai-aria-1.1/#aria-current)'],
 ['[aria-describedby](https://www.w3.org/TR/wai-aria-1.1/#aria-describedby)'],
 ['[aria-details](https://www.w3.org/TR/wai-aria-1.1/#aria-details)'],
 ['[aria-disabled](https://www.w3.org/TR/wai-aria-1.1/#aria-disabled)'],
 ['[aria-dropeffect](https://www.w3.org/TR/wai-aria-1.1/#aria-dropeffect)'],
 ['[aria-errormessage](https://www.w3.org/TR/wai-aria-1.1/#aria-errormessage)'],
 ['[aria-expanded](https://www.w3.org/TR/wai-aria-1.1/#aria-expanded)'],
 ['[aria-flowto](https://www.w3.org/TR/wai-aria-1.1/#aria-flowto)'],
 ['[aria-grabbed](https://www.w3.org/TR/wai-aria-1.1/#aria-grabbed)'],
 ['[aria-haspopup](https://www.w3.org/TR/wai-aria-1.1/#aria-haspopup)'],
 ['[aria-hidden](https://www.w3.org/TR/wai-aria-1.1/#aria-hidden)'],
 ['[aria-invalid](https://www.w3.org/TR/wai-aria-1.1/#aria-invalid)'],
 ['[aria-keyshortcuts](https://www.w3.org/TR/wai-aria-1.1/#aria-keyshortcuts)'],
 ['[aria-label](https://www.w3.org/TR/wai-aria-1.1/#aria-label)'],
 ['[aria-labelledby](https://www.w3.org/TR/wai-aria-1.1/#aria-labelledby)'],
 ['[aria-level](https://www.w3.org/TR/wai-aria-1.1/#aria-level)'],
 ['[aria-live](https://www.w3.org/TR/wai-aria-1.1/#aria-live)'],
 ['[aria-modal](https://www.w3.org/TR/wai-aria-1.1/#aria-modal)'],
 ['[aria-multiline](https://www.w3.org/TR/wai-aria-1.1/#aria-multiline)'],
 ['[aria-multiselectable](https://www.w3.org/TR/wai-aria-1.1/#aria-multiselectable)'],
 ['[aria-orientation](https://www.w3.org/TR/wai-aria-1.1/#aria-orientation)'],
 ['[aria-owns](https://www.w3.org/TR/wai-aria-1.1/#aria-owns)'],
 ['[aria-placeholder](https://www.w3.org/TR/wai-aria-1.1/#aria-placeholder)'],
 ['[aria-posinset](https://www.w3.org/TR/wai-aria-1.1/#aria-posinset)'],
 ['[aria-pressed](https://www.w3.org/TR/wai-aria-1.1/#aria-pressed)'],
 ['[aria-readonly](https://www.w3.org/TR/wai-aria-1.1/#aria-readonly)'],
 ['[aria-relevant](https://www.w3.org/TR/wai-aria-1.1/#aria-relevant)'],
 ['[aria-required](https://www.w3.org/TR/wai-aria-1.1/#aria-required)'],
 ['[aria-roledescription](https://www.w3.org/TR/wai-aria-1.1/#aria-roledescription)'],
 ['[aria-rowcount](https://www.w3.org/TR/wai-aria-1.1/#aria-rowcount)'],
 ['[aria-rowindex](https://www.w3.org/TR/wai-aria-1.1/#aria-rowindex)'],
 ['[aria-rowspan](https://www.w3.org/TR/wai-aria-1.1/#aria-rowspan)'],
 ['[aria-selected](https://www.w3.org/TR/wai-aria-1.1/#aria-selected)'],
 ['[aria-setsize](https://www.w3.org/TR/wai-aria-1.1/#aria-setsize)'],
 ['[aria-sort](https://www.w3.org/TR/wai-aria-1.1/#aria-sort)'],
 ['[aria-valuemax](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemax)'],
 ['[aria-valuemin](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemin)'],
 ['[aria-valuenow](https://www.w3.org/TR/wai-aria-1.1/#aria-valuenow)'],
 ['[aria-valuetext](https://www.w3.org/TR/wai-aria-1.1/#aria-valuetext)'],
 ['[role](struct.html#RoleAttribute)']]
 - [conditional processing
 attributes](struct.html#TermConditionalProcessingAttribute)[ ---
 ['[requiredExtensions](struct.html#RequiredExtensionsAttribute)'],
 ['[systemLanguage](struct.html#SystemLanguageAttribute)']]
 - [core attributes](struct.html#TermCoreAttribute)[ ---
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'],
 ['[style](styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 --- ['[oncancel](interact.html#EventAttributes)'],
 ['[oncanplay](interact.html#EventAttributes)'],
 ['[oncanplaythrough](interact.html#EventAttributes)'],
 ['[onchange](interact.html#EventAttributes)'],
 ['[onclick](interact.html#EventAttributes)'],
 ['[onclose](interact.html#EventAttributes)'],
 ['[oncopy](interact.html#EventAttributes)'],
 ['[oncuechange](interact.html#EventAttributes)'],
 ['[oncut](interact.html#EventAttributes)'],
 ['[ondblclick](interact.html#EventAttributes)'],
 ['[ondrag](interact.html#EventAttributes)'],
 ['[ondragend](interact.html#EventAttributes)'],
 ['[ondragenter](interact.html#EventAttributes)'],
 ['[ondragexit](interact.html#EventAttributes)'],
 ['[ondragleave](interact.html#EventAttributes)'],
 ['[ondragover](interact.html#EventAttributes)'],
 ['[ondragstart](interact.html#EventAttributes)'],
 ['[ondrop](interact.html#EventAttributes)'],
 ['[ondurationchange](interact.html#EventAttributes)'],
 ['[onemptied](interact.html#EventAttributes)'],
 ['[onended](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onfocus](interact.html#EventAttributes)'],
 ['[oninput](interact.html#EventAttributes)'],
 ['[oninvalid](interact.html#EventAttributes)'],
 ['[onkeydown](interact.html#EventAttributes)'],
 ['[onkeypress](interact.html#EventAttributes)'],
 ['[onkeyup](interact.html#EventAttributes)'],
 ['[onload](interact.html#EventAttributes)'],
 ['[onloadeddata](interact.html#EventAttributes)'],
 ['[onloadedmetadata](interact.html#EventAttributes)'],
 ['[onloadstart](interact.html#EventAttributes)'],
 ['[onmousedown](interact.html#EventAttributes)'],
 ['[onmouseenter](interact.html#EventAttributes)'],
 ['[onmouseleave](interact.html#EventAttributes)'],
 ['[onmousemove](interact.html#EventAttributes)'],
 ['[onmouseout](interact.html#EventAttributes)'],
 ['[onmouseover](interact.html#EventAttributes)'],
 ['[onmouseup](interact.html#EventAttributes)'],
 ['[onpaste](interact.html#EventAttributes)'],
 ['[onpause](interact.html#EventAttributes)'],
 ['[onplay](interact.html#EventAttributes)'],
 ['[onplaying](interact.html#EventAttributes)'],
 ['[onprogress](interact.html#EventAttributes)'],
 ['[onratechange](interact.html#EventAttributes)'],
 ['[onreset](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)'],
 ['[onseeked](interact.html#EventAttributes)'],
 ['[onseeking](interact.html#EventAttributes)'],
 ['[onselect](interact.html#EventAttributes)'],
 ['[onshow](interact.html#EventAttributes)'],
 ['[onstalled](interact.html#EventAttributes)'],
 ['[onsubmit](interact.html#EventAttributes)'],
 ['[onsuspend](interact.html#EventAttributes)'],
 ['[ontimeupdate](interact.html#EventAttributes)'],
 ['[ontoggle](interact.html#EventAttributes)'],
 ['[onvolumechange](interact.html#EventAttributes)'],
 ['[onwaiting](interact.html#EventAttributes)'],
 ['[onwheel](interact.html#EventAttributes)']]
 - [presentation attributes](styling.html#TermPresentationAttribute)[
 --- ]
 - [deprecated xlink attributes](linking.html#XLinkRefAttrs)[ ---
 ['[xlink:href](linking.html#XLinkHrefAttribute)'],
 ['[xlink:title](linking.html#XLinkTitleAttribute)']]
 - ['[href](linking.html#AElementHrefAttribute)']
 - ['[target](linking.html#AElementTargetAttribute)']
 - ['[download](linking.html#AElementDownloadAttribute)']
 - ['[ping](linking.html#AElementPingAttribute)']
 - ['[rel](linking.html#AElementRelAttribute)']
 - ['[hreflang](linking.html#AElementHreflangAttribute)']
 - ['[type](linking.html#AElementTypeAttribute)']
 - ['[referrerpolicy](linking.html#AElementReferrerpolicyAttribute)']

DOM Interfaces:

: - [SVGAElement](linking.html#InterfaceSVGAElement)

*Attribute definitions:*

 Name Value Initial value Animatable
 ----------------------------------------------------------------------------------- -------------------------------------------------- --------------- ------------
 [href] URL [\[URL\]](types.html#attribute-url) (none) yes

The location of the referenced object, expressed as an [URL
reference](linking.html#TermURLReference). Refer to the common handling
defined for [URL reference attributes](linking.html#linkRefAttrs).

 Name Value Initial value Animatable
 --------------------------------------------------------------------------------------- -------------------------------------------------------- --------------- ------------
 [target] \_self \| \_parent \| \_top \| \_blank \| \<XML-Name\> \_self yes

This attribute should be used when there are multiple possible targets
for the ending resource, such as when the parent document is embedded
within an HTML or XHTML document, or is viewed with a tabbed browser.
This attribute specifies the name of the browsing context (e.g., a
browser tab or an (X)HTML iframe or object element) into which a
document is to be opened when the link is activated:

[\_self]
: The current SVG image is replaced by the linked content in the same
 browsing context as the current SVG image.

[\_parent]
: The immediate parent browsing context of the SVG image is replaced
 by the linked content, if it exists and can be securely accessed
 from this document.

[\_top]
: The content of the full active window or tab is replaced by the
 linked content, if it exists and can be securely accessed from this
 document

[\_blank]
: A new un-named window or tab is requested for the display of the
 linked content, if this document can securely do so. If the user
 agent does not support multiple windows/tabs, the result is the same
 as [\_top].

[\<XML-Name\>]
: Specifies the name of the browsing context (tab, inline frame,
 object, etc.) for display of the linked content. If a context with
 this name already exists, and can be securely accessed from this
 document, it is re-used, replacing the existing content. If it does
 not exist, it is created (the same as [\'\_blank\'],
 except that it now has a name). The name must be a valid XML Name
 \[XML11\], and should not start with an underscore (U+005F LOW LINE
 character), to meet the requirements of a [valid browsing context
 name](https://html.spec.whatwg.org/multipage/browsers.html#valid-browsing-context-name)
 from HTML.

The normative definitions for browsing contexts and security
restrictions on navigation actions between browsing contexts is HTML
\[[HTML](refs.html#ref-html)\], specifically [the chapter on loading web
pages](https://html.spec.whatwg.org/multipage/browsers.html#browsers).

Previous versions of SVG defined the special target value
[\'\_replace\']. It was never well implemented, and the
distinction between [\'\_replace\'] and
[\'\_self\'] has been made redundant by changes in the HTML
definition of browsing contexts. Use [\'\_self\'] to
replace the current SVG document.

The value [\'\_new\'] is *not* a legal value for target.
Use [\'\_blank\'] to open a document in a new tab/window.

 Name Value Initial value Animatable
 ------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------- --------------- ------------
 [download] any value (if non-empty, value represents a suggested file name) (none) no
 [ping] space-separated valid non-empty URL tokens [\[HTML\]](https://html.spec.whatwg.org/multipage/links.html#ping) (none) no
 [rel] space-separated keyword tokens [\[HTML\]](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#set-of-space-separated-tokens) (none) no
 [hreflang] A BCP 47 language tag string [\[HTML\]](https://html.spec.whatwg.org/multipage/links.html#attr-hyperlink-hreflang) (none) no
 [type] A MIME type string [\[HTML\]](https://html.spec.whatwg.org/multipage/infrastructure.html#mime-type) (none) no
 [referrerpolicy] A referrer policy string [\[REFERRERPOLICY\]](https://w3c.github.io/webappsec-referrer-policy/#referrer-policy) (none) no

These attributes further describe the targetted resource and its
relationship to the current document. Allowed values and meaning are [as
defined for the `a` element in
HTML](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element).

## 16.3. Linking into SVG content: URL fragments and SVG views
Because SVG content often represents a picture or drawing of something,
a common need is to link into a particular *view* of the document, where
a view indicates the initial transformations so as to present a closeup
of a particular section of the document.

::::: ready-for-wider-review
### 16.3.1. SVG fragment identifiers
 -------------------- ---------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Merge the SVG 1.1 SE text and the SVG Tiny 1.2 text on fragment identifiers link traversal and add media fragments.
 Resolution: [SVG 2 will have media fragment identifiers.](http://www.w3.org/2012/03/08-svg-irc#T21-05-52)
 Purpose: To align with Media Fragments URI.
 Owner: Cyril ([ACTION-3442](http://www.w3.org/Graphics/SVG/WG/track/actions/3442))
 -------------------- ---------------------------------------------------------------------------------------------------------------------

To link into a particular view of an SVG document, the [URL reference
with fragment identifier](#TermURLReferenceWithFragmentIdentifier) needs
to be a correctly formed [SVG fragment
identifier]. An
SVG fragment identifier defines the meaning of the \"selector\" or
\"fragment identifier\" portion of URLs that locate resources of MIME
media type \"image/svg+xml\".

An SVG fragment identifier can come in the following forms:

- Shorthand *bare name* form of addressing (e.g.,
 [MyDrawing.svg#MyView]). This form of addressing, which
 allows addressing an SVG element by its ID, is compatible with the
 fragment addressing mechanism for older versions of HTML.
- An [SVG view specification] (e.g.,
 [MyDrawing.svg#svgView(viewBox(0,200,1000,1000))]). This
 form of addressing specifies the desired view of the document (e.g.,
 the region of the document to view, the initial zoom level) completely
 within the SVG fragment specification. The contents of the SVG view
 specification are defined in [SVG fragment identifiers
 definitions](#SVGFragmentIdentifiersDefinitions) section.
- [*Basic media fragments identifiers* of type spatial or temporal
 (e.g., [MyDrawing.svg#xywh=0,200,1000,1000 or
 MyAnimation.svg#t=10)]) as defined in \[[Media Fragments
 URI 1.0 (basic)](refs.html#ref-media-frags)\] and possibly combined
 using the & sign (e.g.
 [MyDrawing.svg#xywh=0,200,1000,1000&t=10]).]

### 16.3.2. SVG fragment identifiers definitions
An SVG fragment identifier is defined as follows:

``` grammar

SVGFragmentIdentifier ::= BareName *( "&" timesegment ) |
 SVGViewSpec *( "&" timesegment ) |
 spacesegment *( "&" timesegment ) |
 timesegment *( "&" spacesegment )

BareName ::= XML_Name
SVGViewSpec ::= 'svgView(' SVGViewAttributes ')'
SVGViewAttributes ::= SVGViewAttribute |
 SVGViewAttribute ';' SVGViewAttributes

SVGViewAttribute ::= viewBoxSpec |
 preserveAspectRatioSpec |
 transformSpec
viewBoxSpec ::= 'viewBox(' ViewBoxParams ')'
preserveAspectRatioSpec = 'preserveAspectRatio(' AspectParams ')'
transformSpec ::= 'transform(' TransformParams ')'
```

where:

- *ViewBoxParams* corresponds to the parameter values for the
 ['[viewBox](coords.html#ViewBoxAttribute)'] attribute on
 the ['[view](linking.html#ViewElement)'] element. For
 example, [viewBox(0,0,200,200)].
- *AspectParams* corresponds to the parameter values for the
 ['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
 attribute on the ['[view](linking.html#ViewElement)']
 element. For example, [preserveAspectRatio(xMidYMid)].
- *TransformParams* corresponds to the parameter values for the
 [transform](coords.html#TransformProperty) property that is
 available on many elements. For example,
 [transform(scale(5))]. Currently additional transform
 styles and parameters (e.g. transform-origin, perspective) are not
 supported.

SVG view box parameters are applied in order, as defined in [CSS
Transforms](https://www.w3.org/TR/css3-transforms/) specification (e.g.
SVG view is transformed as defined in *ViewBoxParams*, then as defined
in *TransformParams*).

Spaces are allowed in fragment specifications. Commas are used to
separate numeric values within an SVG view specification (e.g.,
[#svgView(viewBox(0,0,200,200))]) and semicolons are used
to separate attributes (e.g.,
[#svgView(viewBox(0,0,200,200);preserveAspectRatio(none))]).

Fragment identifiers may be url-escaped according to the rules defined
in [CSS Object Model
(CSSOM)](https://www.w3.org/TR/cssom/#common-serializing-idioms)
specification. For example semicolons can be escaped as %3B to allow
animating a (semi-colon separated) list of URLs because otherwise the
semicolon would be interpreted as a list separator.

The four types of *SVGViewAttribute* may occur in any order, but each
type may only occur at most one time in a correctly formed
*SVGViewSpec*.

When a source document performs a link into an SVG document, for example
via an [HTML anchor
element](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element)
(\[[HTML](refs.html#ref-html)\]; i.e., [\<a href=\...\>]
element in HTML) or an XLink specification
\[[xlink](refs.html#ref-xlink)\], then the SVG fragment identifier
specifies the initial view into the SVG document, as follows:

- If no SVG fragment identifier is provided (e.g, the specified URL did
 not contain a \"#\" character, such as [MyDrawing.svg]),
 then the initial view into the SVG document is established using the
 view specification attributes (i.e.,
 ['[viewBox](coords.html#ViewBoxAttribute)'], etc.) on the
 [outermost svg element](struct.html#TermOutermostSVGElement).
- If the SVG fragment identifier addresses a [space
 segment](https://www.w3.org/TR/media-frags/#spacesegment) (e.g.,
 [MyDrawing.svg#xywh=0,0,100,100]),then the initial view
 into the SVG document is established using the view specification
 attributes on the [outermost svg
 element](struct.html#TermOutermostSVGElement) where the \'viewBox\' is
 overriden by the x, y, width and height values provided by the
 fragment identifier.
- Media fragments can be specified as \"pixel:\" (default) and
 \"percent:\". In the latter case the resulting \'viewBox\'
 transformation is calculated against referenced SVG resolved size
 (width and height). When the host document cannot resolve the width
 and height of the SVG document, the used values for width and height
 should be calculated according to CSS rules for [calculating width and
 ratio for inline replaced
 elements](https://www.w3.org/TR/CSS21/visudet.html#inline-replaced-width).
- If the SVG fragment identifier addresses a [time
 segment](https://www.w3.org/TR/media-frags/#timesegment) (e.g.,
 [MyDrawing.svg#t=10]),then the initial view into the SVG
 document is established as if no fragment identifier was provided. The
 rendering of the SVG Document shall be as if the setCurrentTime method
 on the SVG Document element had been called with the begin time value
 from the fragment identifier. Additionally, if an end time value is
 provided in the fragment identifier, the effect is equivalent to
 calling the pauseAnimations method on the SVG Document when the
 document time reaches the end time of the fragment identifier.
- If the SVG fragment identifier addresses a
 ['[view](linking.html#ViewElement)'] element within an
 SVG document (e.g., [MyDrawing.svg#MyView]) then the root
 ['[svg](struct.html#SVGElement)'] element is displayed
 in the SVG viewport. Any view specification attributes included on the
 given ['[view](linking.html#ViewElement)'] element
 override the corresponding view specification attributes on the root
 ['[svg](struct.html#SVGElement)'] element.
- If the SVG fragment identifier addresses specific SVG view (e.g.,
 [MyDrawing.svg#svgView(viewBox(0,200,1000,1000))]), then
 the document fragment defined by the root
 ['[svg](struct.html#SVGElement)'] element is displayed
 in the SVG viewport using the SVG view specification provided by the
 SVG fragment identifier. Parameters of the svgView specification
 override the parameters defined on the root
 ['[svg](struct.html#SVGElement)'] element of the
 referenced document. Unspecified parameters of the svgView
 specification don\'t reset the values defined on the root
 ['[svg](struct.html#SVGElement)'] element of the
 referenced document.
- If the SVG fragment identifier addresses a combination of the above
 non-time related identifiers with a time-related identifier (i.e. a
 timesegment), the behavior of each identifier is applied.

### 16.3.3. Predefined views: the ['view'] element
The ['view'] element is defined as follows:

:::: element-summary
::: element-summary-name
['[view]']

Categories:
: None

Content model:
: Any number of the following elements, in any order:
 - [animation
 elements](https://svgwg.org/specs/animations/#TermAnimationElement)[
 ---
 ['[animate](https://svgwg.org/specs/animations/#AnimateElement)'],
 ['[animateMotion](https://svgwg.org/specs/animations/#AnimateMotionElement)'],
 ['[animateTransform](https://svgwg.org/specs/animations/#AnimateTransformElement)'],
 ['[set](https://svgwg.org/specs/animations/#SetElement)']]
 - [descriptive elements](struct.html#TermDescriptiveElement)[ ---
 ['[desc](struct.html#DescElement)'],
 ['[title](struct.html#TitleElement)'],
 ['[metadata](struct.html#MetadataElement)']]

 [[script](interact.html#ScriptElement)],
 [[style](styling.html#StyleElement)]

Attributes:

: - [aria attributes](struct.html#TermARIAAttribute)[ ---
 ['[aria-activedescendant](https://www.w3.org/TR/wai-aria-1.1/#aria-activedescendant)'],
 ['[aria-atomic](https://www.w3.org/TR/wai-aria-1.1/#aria-atomic)'],
 ['[aria-autocomplete](https://www.w3.org/TR/wai-aria-1.1/#aria-autocomplete)'],
 ['[aria-busy](https://www.w3.org/TR/wai-aria-1.1/#aria-busy)'],
 ['[aria-checked](https://www.w3.org/TR/wai-aria-1.1/#aria-checked)'],
 ['[aria-colcount](https://www.w3.org/TR/wai-aria-1.1/#aria-colcount)'],
 ['[aria-colindex](https://www.w3.org/TR/wai-aria-1.1/#aria-colindex)'],
 ['[aria-colspan](https://www.w3.org/TR/wai-aria-1.1/#aria-colspan)'],
 ['[aria-controls](https://www.w3.org/TR/wai-aria-1.1/#aria-controls)'],
 ['[aria-current](https://www.w3.org/TR/wai-aria-1.1/#aria-current)'],
 ['[aria-describedby](https://www.w3.org/TR/wai-aria-1.1/#aria-describedby)'],
 ['[aria-details](https://www.w3.org/TR/wai-aria-1.1/#aria-details)'],
 ['[aria-disabled](https://www.w3.org/TR/wai-aria-1.1/#aria-disabled)'],
 ['[aria-dropeffect](https://www.w3.org/TR/wai-aria-1.1/#aria-dropeffect)'],
 ['[aria-errormessage](https://www.w3.org/TR/wai-aria-1.1/#aria-errormessage)'],
 ['[aria-expanded](https://www.w3.org/TR/wai-aria-1.1/#aria-expanded)'],
 ['[aria-flowto](https://www.w3.org/TR/wai-aria-1.1/#aria-flowto)'],
 ['[aria-grabbed](https://www.w3.org/TR/wai-aria-1.1/#aria-grabbed)'],
 ['[aria-haspopup](https://www.w3.org/TR/wai-aria-1.1/#aria-haspopup)'],
 ['[aria-hidden](https://www.w3.org/TR/wai-aria-1.1/#aria-hidden)'],
 ['[aria-invalid](https://www.w3.org/TR/wai-aria-1.1/#aria-invalid)'],
 ['[aria-keyshortcuts](https://www.w3.org/TR/wai-aria-1.1/#aria-keyshortcuts)'],
 ['[aria-label](https://www.w3.org/TR/wai-aria-1.1/#aria-label)'],
 ['[aria-labelledby](https://www.w3.org/TR/wai-aria-1.1/#aria-labelledby)'],
 ['[aria-level](https://www.w3.org/TR/wai-aria-1.1/#aria-level)'],
 ['[aria-live](https://www.w3.org/TR/wai-aria-1.1/#aria-live)'],
 ['[aria-modal](https://www.w3.org/TR/wai-aria-1.1/#aria-modal)'],
 ['[aria-multiline](https://www.w3.org/TR/wai-aria-1.1/#aria-multiline)'],
 ['[aria-multiselectable](https://www.w3.org/TR/wai-aria-1.1/#aria-multiselectable)'],
 ['[aria-orientation](https://www.w3.org/TR/wai-aria-1.1/#aria-orientation)'],
 ['[aria-owns](https://www.w3.org/TR/wai-aria-1.1/#aria-owns)'],
 ['[aria-placeholder](https://www.w3.org/TR/wai-aria-1.1/#aria-placeholder)'],
 ['[aria-posinset](https://www.w3.org/TR/wai-aria-1.1/#aria-posinset)'],
 ['[aria-pressed](https://www.w3.org/TR/wai-aria-1.1/#aria-pressed)'],
 ['[aria-readonly](https://www.w3.org/TR/wai-aria-1.1/#aria-readonly)'],
 ['[aria-relevant](https://www.w3.org/TR/wai-aria-1.1/#aria-relevant)'],
 ['[aria-required](https://www.w3.org/TR/wai-aria-1.1/#aria-required)'],
 ['[aria-roledescription](https://www.w3.org/TR/wai-aria-1.1/#aria-roledescription)'],
 ['[aria-rowcount](https://www.w3.org/TR/wai-aria-1.1/#aria-rowcount)'],
 ['[aria-rowindex](https://www.w3.org/TR/wai-aria-1.1/#aria-rowindex)'],
 ['[aria-rowspan](https://www.w3.org/TR/wai-aria-1.1/#aria-rowspan)'],
 ['[aria-selected](https://www.w3.org/TR/wai-aria-1.1/#aria-selected)'],
 ['[aria-setsize](https://www.w3.org/TR/wai-aria-1.1/#aria-setsize)'],
 ['[aria-sort](https://www.w3.org/TR/wai-aria-1.1/#aria-sort)'],
 ['[aria-valuemax](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemax)'],
 ['[aria-valuemin](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemin)'],
 ['[aria-valuenow](https://www.w3.org/TR/wai-aria-1.1/#aria-valuenow)'],
 ['[aria-valuetext](https://www.w3.org/TR/wai-aria-1.1/#aria-valuetext)'],
 ['[role](struct.html#RoleAttribute)']]
 - [core attributes](struct.html#TermCoreAttribute)[ ---
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'],
 ['[style](styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 --- ['[oncancel](interact.html#EventAttributes)'],
 ['[oncanplay](interact.html#EventAttributes)'],
 ['[oncanplaythrough](interact.html#EventAttributes)'],
 ['[onchange](interact.html#EventAttributes)'],
 ['[onclick](interact.html#EventAttributes)'],
 ['[onclose](interact.html#EventAttributes)'],
 ['[oncopy](interact.html#EventAttributes)'],
 ['[oncuechange](interact.html#EventAttributes)'],
 ['[oncut](interact.html#EventAttributes)'],
 ['[ondblclick](interact.html#EventAttributes)'],
 ['[ondrag](interact.html#EventAttributes)'],
 ['[ondragend](interact.html#EventAttributes)'],
 ['[ondragenter](interact.html#EventAttributes)'],
 ['[ondragexit](interact.html#EventAttributes)'],
 ['[ondragleave](interact.html#EventAttributes)'],
 ['[ondragover](interact.html#EventAttributes)'],
 ['[ondragstart](interact.html#EventAttributes)'],
 ['[ondrop](interact.html#EventAttributes)'],
 ['[ondurationchange](interact.html#EventAttributes)'],
 ['[onemptied](interact.html#EventAttributes)'],
 ['[onended](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onfocus](interact.html#EventAttributes)'],
 ['[oninput](interact.html#EventAttributes)'],
 ['[oninvalid](interact.html#EventAttributes)'],
 ['[onkeydown](interact.html#EventAttributes)'],
 ['[onkeypress](interact.html#EventAttributes)'],
 ['[onkeyup](interact.html#EventAttributes)'],
 ['[onload](interact.html#EventAttributes)'],
 ['[onloadeddata](interact.html#EventAttributes)'],
 ['[onloadedmetadata](interact.html#EventAttributes)'],
 ['[onloadstart](interact.html#EventAttributes)'],
 ['[onmousedown](interact.html#EventAttributes)'],
 ['[onmouseenter](interact.html#EventAttributes)'],
 ['[onmouseleave](interact.html#EventAttributes)'],
 ['[onmousemove](interact.html#EventAttributes)'],
 ['[onmouseout](interact.html#EventAttributes)'],
 ['[onmouseover](interact.html#EventAttributes)'],
 ['[onmouseup](interact.html#EventAttributes)'],
 ['[onpaste](interact.html#EventAttributes)'],
 ['[onpause](interact.html#EventAttributes)'],
 ['[onplay](interact.html#EventAttributes)'],
 ['[onplaying](interact.html#EventAttributes)'],
 ['[onprogress](interact.html#EventAttributes)'],
 ['[onratechange](interact.html#EventAttributes)'],
 ['[onreset](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)'],
 ['[onseeked](interact.html#EventAttributes)'],
 ['[onseeking](interact.html#EventAttributes)'],
 ['[onselect](interact.html#EventAttributes)'],
 ['[onshow](interact.html#EventAttributes)'],
 ['[onstalled](interact.html#EventAttributes)'],
 ['[onsubmit](interact.html#EventAttributes)'],
 ['[onsuspend](interact.html#EventAttributes)'],
 ['[ontimeupdate](interact.html#EventAttributes)'],
 ['[ontoggle](interact.html#EventAttributes)'],
 ['[onvolumechange](interact.html#EventAttributes)'],
 ['[onwaiting](interact.html#EventAttributes)'],
 ['[onwheel](interact.html#EventAttributes)']]
 - ['[viewBox](coords.html#ViewBoxAttribute)']
 - ['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']

DOM Interfaces:

: - [SVGViewElement](linking.html#InterfaceSVGViewElement)

We have resolved to remove viewTarget attribute.

Resolution: Paris 2015 F2F Day 3.

Owner: BogdanBrinza.

## 16.4. DOM interfaces
::: ready-for-wider-review
### 16.4.1. Interface SVGAElement
An [SVGElement](types.html#InterfaceSVGElement) object
represents an ['[a](linking.html#AElement)'] element in
the DOM.

``` idl
[Exposed=Window]
interface SVGAElement : SVGGraphicsElement {
 [SameObject] readonly attribute SVGAnimatedString target;
 attribute DOMString download;
 attribute USVString ping;
 attribute DOMString rel;
 [SameObject, PutForwards=value] readonly attribute DOMTokenList relList;
 attribute DOMString hreflang;
 attribute DOMString type;

 attribute DOMString referrerPolicy;
};

SVGAElement includes SVGURIReference;
SVGAElement includes HTMLHyperlinkElementUtils;
```

The **target**, **download**, **ping**, **rel**, **hreflang**, **type**,
IDL attributes [reflect](types.html#TermReflect) the content attributes
of the same name.

The **relList** IDL attribute [reflects](types.html#TermReflect) the
['[rel](linking.html#AElementRelAttribute)'] content
attribute.

The **referrerPolicy** IDL attribute [reflects](types.html#TermReflect)
the
['[referrerpolicy](linking.html#AElementReferrerpolicyAttribute)']
content attribute, [limited to only known
values](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#limited-to-only-known-values).

### 16.4.2. Interface SVGViewElement
An [SVGViewElement](linking.html#InterfaceSVGViewElement)
object represents a ['[view](linking.html#ViewElement)']
element in the DOM.

``` idl
[Exposed=Window]
interface SVGViewElement : SVGElement ;

SVGViewElement includes SVGFitToViewBox;
```
