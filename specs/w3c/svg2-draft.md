
[![W3C](https://www.w3.org/StyleSheets/TR/2016/logos/W3C){height="48"
width="72"}](https://www.w3.org/)

# Scalable Vector Graphics (SVG) 2

## W3C Editor's Draft *14 September 2025*

This version:
: [https://svgwg.org/svg2-draft/](https://svgwg.org/svg2-draft/)

Latest version:
: [https://www.w3.org/TR/SVG2/](https://www.w3.org/TR/SVG2/)

Previous version:
: [https://www.w3.org/TR/2018/CR-SVG2-20180807/](https://www.w3.org/TR/2018/CR-SVG2-20180807/)

Single page version:
: [https://svgwg.org/svg2-draft/single-page.html](single-page.html)

GitHub repository:
: <https://github.com/w3c/svgwg/>

Public comments:
: [www-svg@w3.org](mailto:www-svg@w3.org)
 ([archive](http://lists.w3.org/Archives/Public/www-svg/))

Editors:
: Amelia Bellamy-Royds, Invited Expert
 \<[amelia.bellamy.royds@gmail.com](mailto:amelia.bellamy.royds@gmail.com)\>
: Tavmjong Bah, Invited Expert
 \<[tavmjong@free.fr](mailto:tavmjong@free.fr)\>
: Chris Lilley, W3C \<[chris@w3.org](mailto:chris@w3.org)\>
: Dirk Schulze, Adobe Systems
 \<[dschulze@adobe.com](mailto:dschulze@adobe.com)\>
: Eric Willigers, Google

Former Editors:
: Nikos Andronikos, Canon, Inc.
 \<[nikos.andronikos@cisra.canon.com.au](mailto:nikos.andronikos@cisra.canon.com.au)\>
: Rossen Atanassov, Microsoft Co.
 \<[ratan@microsoft.com](mailto:ratan@microsoft.com)\>
: Brian Birtles, Mozilla Japan
 \<[bbirtles@mozilla.com](mailto:bbirtles@mozilla.com)\>
: Bogdan Brinza, Microsoft Co.
 \<[bbrinza@microsoft.com](mailto:bbrinza@microsoft.com)\>
: Cyril Concolato, Telecom ParisTech
 \<[cyril.concolato@telecom-paristech.fr](mailto:cyril.concolato@telecom-paristech.fr)\>
: Erik Dahlström, Invited Expert
 \<[erik@dahlström.net](mailto:erik@xn--dahlstrm-t4a.net)\>
: Cameron McCormack, Mozilla Corporation
 \<[cam@mcc.id.au](mailto:cam@mcc.id.au)\>
: David Storey, Microsoft Co.
 \<[dstorey@microsoft.com](mailto:dstorey@microsoft.com)\>
: Doug Schepers, W3C
 \<[schepers@w3.org](mailto:schepers@w3.org)\>
: Richard Schwerdtfeger, IBM
 \<[schwer@us.ibm.com](mailto:schwer@us.ibm.com)\>
: Satoru Takagi, KDDI Corporation
 \<[sa-takagi@kddi.com](mailto:sa-takagi@kddi.com)\>
: Jonathan Watt, Mozilla Corporation
 \<[jwatt@jwatt.org](mailto:jwatt@jwatt.org)\>

[Copyright](http://www.w3.org/Consortium/Legal/ipr-notice#Copyright) ©
2025 [[W3C]](http://www.w3.org/)^®^ ([[MIT]](http://www.csail.mit.edu/),
[[ERCIM]](http://www.ercim.eu/),
[Keio](http://www.keio.ac.jp/), [Beihang](http://ev.buaa.edu.cn/)). W3C
[liability](http://www.w3.org/Consortium/Legal/ipr-notice#Legal_Disclaimer),
[trademark](http://www.w3.org/Consortium/Legal/ipr-notice#W3C_Trademarks)
and [document
use](http://www.w3.org/Consortium/Legal/copyright-documents) rules
apply.

------------------------------------------------------------------------

## Abstract

This specification defines the features and syntax for Scalable Vector
Graphics (SVG) Version 2. SVG is a language based on XML for describing
two-dimensional vector and mixed vector/raster graphics. SVG content is
stylable, scalable to different display resolutions, and can be viewed
stand-alone, mixed with HTML content, or embedded using XML namespaces
within other XML languages. SVG also supports dynamic changes; script
can be used to create interactive documents, and animations can be
performed using declarative animation features or by using script.

## Status of This Document

*This section describes the status of this document at the time of its
publication. Other documents may supersede this document. A list of
current W3C publications and the latest revision of this technical
report can be found in the [W3C technical reports
index](https://www.w3.org/TR/) at https://www.w3.org/TR/*.

This document is the 14 September 2025 **Editor's Draft** of SVG 2. This
version of SVG builds upon [SVG 1.1 Second
Edition](https://www.w3.org/TR/2011/REC-SVG11-20110816/) by improving
the usability of the language and by adding new features commonly
requested by authors. The [Changes](changes.html) appendix lists all of
the changes that have been made since SVG 1.1 Second Edition.

Comments on this Editor's Draft are welcome. Comments can be sent to
[www-svg@w3.org](mailto:www-svg@w3.org), the public email list for
issues related to vector graphics on the Web. This list is
[archived](http://lists.w3.org/Archives/Public/www-svg/) and senders
must agree to have their message publicly archived from their first
posting. To subscribe send an email to
[www-svg-request@w3.org](mailto:www-svg-request@w3.org) with the
word `subscribe` in the subject line.

The specification includes a number of annotations that the Working
Group is using to record links to meeting minutes and resolutions where
specific decisions about SVG features have been made. Different coloring
is also used to mark the maturity of different sections of the
specification:

- a red background indicates a section that is either unchanged since
 SVG 1.1 (and which therefore still requires review and possible
 rewriting for SVG 2), or a section that is new but still requires
 substantial work
- a yellow background indicates a section from SVG 1.1 that has been
 reviewed and rewritten if necessary, or a new section that is complete
 and ready for the rest of the Working Group to review
- a white background indicates a section, either from SVG 1.1 or new for
 SVG 2, that has been reviewed by the Working Group and which is ready
 for wider review

This document has been produced by the [W3C SVG Working
Group](https://www.w3.org/Graphics/SVG/WG/) as part of the [Graphics
Activity](https://www.w3.org/Graphics/Activity) within the [W3C
Interaction Domain](https://www.w3.org/Interaction/). The goals of the
W3C SVG Working Group are discussed in the [W3C SVG
Charter](https://www.w3.org/Graphics/SVG/svg-2019.html). The W3C SVG
Working Group maintains a public Web page,
[https://www.w3.org/Graphics/SVG/](https://www.w3.org/Graphics/SVG/),
that contains further background information. The authors of this
document are the SVG Working Group participants.

This document was produced by a group operating under the [5 February
2004 W3C Patent
Policy](https://www.w3.org/Consortium/Patent-Policy-20040205/). W3C
maintains a [public list of any patent
disclosures](https://www.w3.org/2004/01/pp-impl/19480/status){rel="disclosure"}
made in connection with the deliverables of the group; that page also
includes instructions for disclosing a patent. An individual who has
actual knowledge of a patent which the individual believes contains
[Essential
Claim(s)](https://www.w3.org/Consortium/Patent-Policy-20040205/#def-essential)
must disclose the information in accordance with [section 6 of the W3C
Patent
Policy](https://www.w3.org/Consortium/Patent-Policy-20040205/#sec-Disclosure).

Publication as a Working Draft does not imply endorsement by the W3C
Membership. This is a draft document and may be updated, replaced or
obsoleted by other documents at any time. It is inappropriate to cite
this document as other than work in progress.

A list of current W3C Recommendations and other technical documents can
be found at [https://www.w3.org/TR/](https://www.w3.org/TR/). W3C
publications may be updated, replaced, or obsoleted by other documents
at any time.

This document is governed by the [1 September 2015 W3C Process
Document](https://www.w3.org/2015/Process-20150901/).

All features in this specification depend upon implementation in
browsers or authoring tools. If a feature is not certain to be
implemented, we define that feature as \"at risk\". At-risk features
will be removed from the current specification, and may be included in
future versions of the specification. If an at-risk feature is
particularly important to authors of SVG, those authors are encouraged
to give feedback to implementers regarding its priority. The following
features are at risk, and may be dropped during the CR period:

- More than one ['[title](struct.html#TitleElement)'] or
 ['[desc](struct.html#DescElement)'] to provide
 localisation
- [Nested links](linking.html#Links)
- [vector-effect](coords.html#VectorEffectProperty) options
 other than [non-scaling-stroke]
- [stroke-linejoin](painting.html#StrokeLinejoinProperty)
 options [miter-clip] and [arcs]
- the [shape-inside](text.html#TextShapeInside) and
 [shape-subtract](text.html#TextShapeSubtract) properties

## Table of Contents

1. [1.] [Introduction](intro.html)
 1. [[1.1.] About SVG](intro.html#AboutSVG)
 2. [[1.2.] Compatibility with other standards
 efforts](intro.html#W3CCompatibility)
 3. [[1.3.] Relationship to previous versions of this
 standard](intro.html#RelationshipToPrevious)
 4. [[1.4.] Normative
 Terminology](intro.html#ConformanceTerms)
2. [2.] [Conformance Criteria](conform.html)
 1. [[2.1.] Overview](conform.html#conformance-overview)
 2. [[2.2.] Processing modes](conform.html#processing-modes)
 1. [[2.2.1.] Features](conform.html#features)
 2. [[2.2.2.] Dynamic interactive
 mode](conform.html#dynamic-interactive-mode)
 3. [[2.2.3.] Animated mode](conform.html#animated-mode)
 4. [[2.2.4.] Secure animated
 mode](conform.html#secure-animated-mode)
 5. [[2.2.5.] Static mode](conform.html#static-mode)
 6. [[2.2.6.] Secure static
 mode](conform.html#secure-static-mode)
 3. [[2.3.] Processing modes for SVG sub-resource
 documents](conform.html#referencing-modes)
 1. [[2.3.1.] Examples](conform.html#examples)
 4. [[2.4.] Document Conformance
 Classes](conform.html#DocumentConformanceClasses)
 1. [[2.4.1.] Conforming SVG DOM
 Subtrees](conform.html#ConformingSVGDOMSubtrees)
 2. [[2.4.2.] Conforming SVG Markup
 Fragments](conform.html#ConformingSVGFragments)
 3. [[2.4.3.] Conforming XML-Compatible SVG Markup
 Fragments](conform.html#ConformingSVGXMLFragments)
 4. [[2.4.4.] Conforming XML-Compatible SVG DOM
 Subtrees](conform.html#ConformingSVGXMLDOMSubtrees)
 5. [[2.4.5.] Conforming SVG Stand-Alone
 Files](conform.html#ConformingSVGStandAloneFiles)
 6. [[2.4.6.] Error
 processing](conform.html#ErrorProcessing)
 5. [[2.5.] Software Conformance
 Classes](conform.html#SoftwareConformanceClasses)
 1. [[2.5.1.] Conforming SVG
 Generators](conform.html#ConformingSVGGenerators)
 2. [[2.5.2.] Conforming SVG Authoring
 Tools](conform.html#ConformingSVGAuthoringTools)
 3. [[2.5.3.] Conforming SVG
 Servers](conform.html#ConformingSVGServers)
 4. [[2.5.4.] Conforming SVG
 Interpreters](conform.html#ConformingSVGInterpreters)
 5. [[2.5.5.] Conforming SVG
 Viewers](conform.html#ConformingSVGViewers)
 1. [[2.5.5.1.] Printing implementation
 notes](conform.html#PrintingImplementationNotes)
 6. [[2.5.6.] Conforming High-Quality SVG
 Viewer](conform.html#ConformingHighQualitySVGViewers)
3. [3.] [Rendering Model](render.html)
 1. [[3.1.] Introduction](render.html#Introduction)
 2. [[3.2.] The rendering tree](render.html#RenderingTree)
 1. [[3.2.1.] Definitions](render.html#Definitions)
 2. [[3.2.2.] Rendered versus non-rendered
 elements](render.html#Rendered-vs-NonRendered)
 3. [[3.2.3.] Controlling visibility: the effect of the
 '[display]' and '[visibility]'
 properties](render.html#VisibilityControl)
 4. [[3.2.4.] Re-used
 graphics](render.html#ReusedGraphics)
 3. [[3.3.] The painters model](render.html#PaintersModel)
 4. [[3.4.] Rendering order](render.html#RenderingOrder)
 1. [[3.4.1.] Establishing a stacking context in
 SVG](render.html#EstablishingStackingContex)
 5. [[3.5.] How elements are rendered](render.html#Elements)
 6. [[3.6.] How groups are rendered](render.html#Grouping)
 1. [[3.6.1.] Object and group opacity: the effect of
 the '[opacity]'
 property](render.html#ObjectAndGroupOpacityProperties)
 7. [[3.7.] Types of graphics
 elements](render.html#TypesOfGraphicsElements)
 1. [[3.7.1.] Painting shapes and
 text](render.html#PaintingShapesAndText)
 2. [[3.7.2.] Painting raster
 images](render.html#PaintingRasterImages)
 8. [[3.8.] Filtering painted
 regions](render.html#FilteringPaintRegions)
 9. [[3.9.] Clipping and
 masking](render.html#ClippingAndMasking)
 10. [[3.10.] Parent
 compositing](render.html#ParentCompositing)
 11. [[3.11.] The effect of the '[overflow]'
 property](render.html#OverflowAndClipProperties)
4. [4.] [Basic Data Types and Interfaces](types.html)
 1. [[4.1.] Definitions](types.html#definitions)
 2. [[4.2.] Attribute syntax](types.html#syntax)
 1. [[4.2.1.] Real number
 precision](types.html#Precision)
 2. [[4.2.2.] Clamping values which are restricted to a
 particular range](types.html#RangeClamping)
 3. [[4.3.] SVG DOM overview](types.html#SVGDOMOverview)
 1. [[4.3.1.] Dependencies for SVG DOM
 support](types.html#SVGDOMDependencies)
 2. [[4.3.2.] Naming
 conventions](types.html#SVGDOMNamingConventions)
 3. [[4.3.3.] Elements in the SVG
 DOM](types.html#ElementsInTheSVGDOM)
 4. [[4.3.4.] Reflecting content attributes in the
 DOM](types.html#ReflectingAttributes)
 5. [[4.3.5.] Synchronizing reflected
 values](types.html#SynchronizingReflectedValues)
 6. [[4.3.6.] Reflecting an empty initial
 value](types.html#SVGObjectInitialization)
 7. [[4.3.7.] Invalid values](types.html#InvalidValues)
 4. [[4.4.] DOM interfaces for SVG
 elements](types.html#DOMInterfacesForSVGElements)
 1. [[4.4.1.] Interface
 SVGElement](types.html#InterfaceSVGElement)
 2. [[4.4.2.] Interface
 SVGGraphicsElement](types.html#InterfaceSVGGraphicsElement)
 3. [[4.4.3.] Interface
 SVGGeometryElement](types.html#InterfaceSVGGeometryElement)
 5. [[4.5.] DOM interfaces for basic data
 types](types.html#DOMInterfacesForBasicDataTypes)
 1. [[4.5.1.] Interface
 SVGNumber](types.html#InterfaceSVGNumber)
 2. [[4.5.2.] Interface
 SVGLength](types.html#InterfaceSVGLength)
 3. [[4.5.3.] Interface
 SVGAngle](types.html#InterfaceSVGAngle)
 4. [[4.5.4.] List
 interfaces](types.html#ListInterfaces)
 5. [[4.5.5.] Interface
 SVGNumberList](types.html#InterfaceSVGNumberList)
 6. [[4.5.6.] Interface
 SVGLengthList](types.html#InterfaceSVGLengthList)
 7. [[4.5.7.] Interface
 SVGStringList](types.html#InterfaceSVGStringList)
 6. [[4.6.] DOM interfaces for reflecting animatable SVG
 attributes](types.html#DOMInterfacesForReflectingSVGAttributes)
 1. [[4.6.1.] Interface
 SVGAnimatedBoolean](types.html#InterfaceSVGAnimatedBoolean)
 2. [[4.6.2.] Interface
 SVGAnimatedEnumeration](types.html#InterfaceSVGAnimatedEnumeration)
 3. [[4.6.3.] Interface
 SVGAnimatedInteger](types.html#InterfaceSVGAnimatedInteger)
 4. [[4.6.4.] Interface
 SVGAnimatedNumber](types.html#InterfaceSVGAnimatedNumber)
 5. [[4.6.5.] Interface
 SVGAnimatedLength](types.html#InterfaceSVGAnimatedLength)
 6. [[4.6.6.] Interface
 SVGAnimatedAngle](types.html#InterfaceSVGAnimatedAngle)
 7. [[4.6.7.] Interface
 SVGAnimatedString](types.html#InterfaceSVGAnimatedString)
 8. [[4.6.8.] Interface
 SVGAnimatedRect](types.html#InterfaceSVGAnimatedRect)
 9. [[4.6.9.] Interface
 SVGAnimatedNumberList](types.html#InterfaceSVGAnimatedNumberList)
 10. [[4.6.10.] Interface
 SVGAnimatedLengthList](types.html#InterfaceSVGAnimatedLengthList)
 7. [[4.7.] Other DOM
 interfaces](types.html#OtherDOMInterfaces)
 1. [[4.7.1.] Interface
 SVGUnitTypes](types.html#InterfaceSVGUnitTypes)
 2. [[4.7.2.] Mixin
 SVGTests](types.html#InterfaceSVGTests)
 3. [[4.7.3.] Mixin
 SVGFitToViewBox](types.html#InterfaceSVGFitToViewBox)
 4. [[4.7.4.] Mixin
 SVGURIReference](types.html#InterfaceSVGURIReference)
5. [5.] [Document Structure](struct.html)
 1. [[5.1.] Defining an SVG document fragment: the
 ['svg'] element](struct.html#NewDocument)
 1. [[5.1.1.] Overview](struct.html#NewDocumentOverview)
 2. [[5.1.2.] Namespace](struct.html#Namespace)
 3. [[5.1.3.] Definitions](struct.html#Definitions)
 4. [[5.1.4.] The ['svg']
 element](struct.html#SVGElement)
 2. [[5.2.] Grouping: the ['g']
 element](struct.html#Groups)
 1. [[5.2.1.] Overview](struct.html#GroupsOverview)
 2. [[5.2.2.] The ['g']
 element](struct.html#GElement)
 3. [[5.3.] Defining content for reuse, and the
 ['defs'] element](struct.html#Head)
 1. [[5.3.1.] Overview](struct.html#Overview)
 2. [[5.3.2.] The ['defs']
 element](struct.html#DefsElement)
 4. [[5.4.] The ['symbol']
 element](struct.html#SymbolElement)
 1. [[5.4.1.] Attributes](struct.html#SymbolAttributes)
 2. [[5.4.2.] Notes on symbols](struct.html#SymbolNotes)
 5. [[5.5.] The ['use']
 element](struct.html#UseElement)
 1. [[5.5.1.] The use-element shadow
 tree](struct.html#UseShadowTree)
 2. [[5.5.2.] Layout of re-used
 graphics](struct.html#UseLayout)
 3. [[5.5.3.] Style Scoping and
 Inheritance](struct.html#UseStyleInheritance)
 4. [[5.5.4.] Animations in use-element shadow
 trees](struct.html#UseAnimations)
 5. [[5.5.5.] Event handling in use-element shadow
 trees](struct.html#UseEventHandling)
 6. [[5.6.] Conditional
 processing](struct.html#ConditionalProcessing)
 1. [[5.6.1.] Conditional processing
 overview](struct.html#ConditionalProcessingOverview)
 2. [[5.6.2.]
 Definitions](struct.html#ConditionalProcessingDefinitions)
 3. [[5.6.3.] The ['switch']
 element](struct.html#SwitchElement)
 4. [[5.6.4.] The ['requiredExtensions']
 attribute](struct.html#ConditionalProcessingRequiredExtensionsAttribute)
 5. [[5.6.5.] The ['systemLanguage']
 attribute](struct.html#ConditionalProcessingSystemLanguageAttribute)
 7. [[5.7.] The ['desc'] and
 ['title']
 elements](struct.html#DescriptionAndTitleElements)
 1. [[5.7.1.]
 Definition](struct.html#DescriptionDefinitions)
 8. [[5.8.] The ['metadata']
 element](struct.html#MetadataElement)
 9. [[5.9.] HTML metadata
 elements](struct.html#HTMLMetadataElements)
 10. [[5.10.] Foreign namespaces and private
 data](struct.html#ForeignNamespaces)
 11. [[5.11.] Common
 attributes](struct.html#CommonAttributes)
 1. [[5.11.1.]
 Definitions](struct.html#CommonAttributeDefinitions)
 2. [[5.11.2.] Attributes common to all elements:
 ['id']](struct.html#Core.attrib)
 3. [[5.11.3.] The ['lang'] and
 ['xml:lang']
 attributes](struct.html#LangSpaceAttrs)
 4. [[5.11.4.] The ['xml:space']
 attribute](struct.html#WhitespaceProcessingXMLSpaceAttribute)
 5. [[5.11.5.] The ['tabindex']
 attribute](struct.html#tabindexattribute)
 6. [[5.11.6.] The ['autofocus']
 attribute](struct.html#autofocusattribute)
 7. [[5.11.7.] The ['data-\*']
 attributes](struct.html#DataAttributes)
 12. [[5.12.] WAI-ARIA
 attributes](struct.html#WAIARIAAttributes)
 1. [[5.12.1.]
 Definitions](struct.html#WAIARIA-definitions)
 2. [[5.12.2.] Role
 attribute](struct.html#roleattribute)
 3. [[5.12.3.] State and property attributes (all aria-
 attributes)](struct.html#ARIAStateandPropertyAttributes)
 4. [[5.12.4.] Implicit and Allowed ARIA
 Semantics](struct.html#implicit-aria-semantics)
 13. [[5.13.] DOM interfaces](struct.html#DOMInterfaces)
 1. [[5.13.1.] Extensions to the Document
 interface](struct.html#InterfaceDocumentExtensions)
 2. [[5.13.2.] Interface
 SVGSVGElement](struct.html#InterfaceSVGSVGElement)
 3. [[5.13.3.] Interface
 SVGGElement](struct.html#InterfaceSVGGElement)
 4. [[5.13.4.] Interface
 SVGDefsElement](struct.html#InterfaceSVGDefsElement)
 5. [[5.13.5.] Interface
 SVGDescElement](struct.html#InterfaceSVGDescElement)
 6. [[5.13.6.] Interface
 SVGMetadataElement](struct.html#InterfaceSVGMetadataElement)
 7. [[5.13.7.] Interface
 SVGTitleElement](struct.html#InterfaceSVGTitleElement)
 8. [[5.13.8.] Interface
 SVGSymbolElement](struct.html#InterfaceSVGSymbolElement)
 9. [[5.13.9.] Interface
 SVGUseElement](struct.html#InterfaceSVGUseElement)
 10. [[5.13.10.] Interface
 SVGUseElementShadowRoot](struct.html#InterfaceSVGUseElementShadowRoot)
 11. [[5.13.11.] Mixin
 SVGElementInstance](struct.html#InterfaceSVGElementInstance)
 12. [[5.13.12.] Interface
 ShadowAnimation](struct.html#InterfaceShadowAnimation)
 13. [[5.13.13.] Interface
 SVGSwitchElement](struct.html#InterfaceSVGSwitchElement)
 14. [[5.13.14.] Mixin
 GetSVGDocument](struct.html#InterfaceGetSVGDocument)
6. [6.] [Styling](styling.html)
 1. [[6.1.] Styling SVG content using
 CSS](styling.html#StylingUsingCSS)
 2. [[6.2.] Inline style sheets: the
 ['style'] element](styling.html#StyleElement)
 3. [[6.3.] External style sheets: the effect of the HTML
 ['link'] element](styling.html#LinkElement)
 4. [[6.4.] Style sheets in HTML
 documents](styling.html#StyleSheetsInHTMLDocuments)
 5. [[6.5.] Element-specific styling: the
 ['class'] and ['style']
 attributes](styling.html#ElementSpecificStyling)
 6. [[6.6.] Presentation
 attributes](styling.html#PresentationAttributes)
 7. [[6.7.] Required
 properties](styling.html#RequiredProperties)
 8. [[6.8.] User agent style
 sheet](styling.html#UAStyleSheet)
 9. [[6.9.] Required CSS
 features](styling.html#RequiredCSSFeatures)
 10. [[6.10.] DOM interfaces](styling.html#DOMInterfaces)
 1. [[6.10.1.] Interface
 SVGStyleElement](styling.html#InterfaceSVGStyleElement)
7. [7.] [Geometry Properties](geometry.html)
 1. [[7.1.] Horizontal center coordinate: The
 '[cx]' property](geometry.html#CX)
 2. [[7.2.] Vertical center coordinate: The
 '[cy]' property](geometry.html#CY)
 3. [[7.3.] Radius: The '[r]'
 property](geometry.html#R)
 4. [[7.4.] Horizontal radius: The '[rx]'
 property](geometry.html#RX)
 5. [[7.5.] Vertical radius: The '[ry]'
 property](geometry.html#RY)
 6. [[7.6.] Horizontal coordinate: The '[x]'
 property](geometry.html#X)
 7. [[7.7.] Vertical coordinate: The '[y]'
 property](geometry.html#Y)
 8. [[7.8.] Sizing properties: the effect of the
 '[width]' and '[height]'
 properties](geometry.html#Sizing)
8. [8.] [Coordinate Systems, Transformations and
 Units](coords.html)
 1. [[8.1.] Introduction](coords.html#Introduction)
 2. [[8.2.] Computing the equivalent transform of an SVG
 viewport](coords.html#ComputingAViewportsTransform)
 3. [[8.3.] The initial viewport](coords.html#ViewportSpace)
 4. [[8.4.] The initial coordinate
 system](coords.html#InitialCoordinateSystem)
 5. [[8.5.] The '[transform]'
 property](coords.html#TransformProperty)
 6. [[8.6.] The ['viewBox']
 attribute](coords.html#ViewBoxAttribute)
 7. [[8.7.] The ['preserveAspectRatio']
 attribute](coords.html#PreserveAspectRatioAttribute)
 8. [[8.8.] Establishing a new SVG
 viewport](coords.html#EstablishingANewSVGViewport)
 9. [[8.9.] Units](coords.html#Units)
 10. [[8.10.] Bounding boxes](coords.html#BoundingBoxes)
 11. [[8.11.] Object bounding box
 units](coords.html#ObjectBoundingBoxUnits)
 12. [[8.12.] Intrinsic sizing properties of SVG
 content](coords.html#SizingSVGInCSS)
 13. [[8.13.] Vector effects](coords.html#VectorEffects)
 1. [[8.13.1.] Computing the vector
 effects](coords.html#VectorEffectsCalculation)
 2. [[8.13.2.] Computing the vector effects for nested
 viewport coordinate
 systems](coords.html#NestedVectorEffectsCalculation)
 3. [[8.13.3.] Examples of vector
 effects](coords.html#VectorEffectsExamples)
 14. [[8.14.] DOM interfaces](coords.html#DOMInterfaces)
 1. [[8.14.1.] Interface
 SVGTransform](coords.html#InterfaceSVGTransform)
 2. [[8.14.2.] Interface
 SVGTransformList](coords.html#InterfaceSVGTransformList)
 3. [[8.14.3.] Interface
 SVGAnimatedTransformList](coords.html#InterfaceSVGAnimatedTransformList)
 4. [[8.14.4.] Interface
 SVGPreserveAspectRatio](coords.html#InterfaceSVGPreserveAspectRatio)
 5. [[8.14.5.] Interface
 SVGAnimatedPreserveAspectRatio](coords.html#InterfaceSVGAnimatedPreserveAspectRatio)
9. [9.] [Paths](paths.html)
 1. [[9.1.] Introduction](paths.html#Introduction)
 2. [[9.2.] The ['path']
 element](paths.html#PathElement)
 3. [[9.3.] Path data](paths.html#PathData)
 1. [[9.3.1.] General information about path
 data](paths.html#PathDataGeneralInformation)
 2. [[9.3.2.] Specifying path data: the '[d]'
 property](paths.html#TheDProperty)
 3. [[9.3.3.] The **\"moveto\"**
 commands](paths.html#PathDataMovetoCommands)
 4. [[9.3.4.] The **\"closepath\"**
 command](paths.html#PathDataClosePathCommand)
 1. [[9.3.4.1.] Segment-completing close path
 operation](paths.html#Segment-CompletingClosePath)
 5. [[9.3.5.] The **\"lineto\"**
 commands](paths.html#PathDataLinetoCommands)
 6. [[9.3.6.] The cubic Bézier curve
 commands](paths.html#PathDataCubicBezierCommands)
 7. [[9.3.7.] The quadratic Bézier curve
 commands](paths.html#PathDataQuadraticBezierCommands)
 8. [[9.3.8.] The elliptical arc curve
 commands](paths.html#PathDataEllipticalArcCommands)
 9. [[9.3.9.] The grammar for path
 data](paths.html#PathDataBNF)
 4. [[9.4.] Path
 directionality](paths.html#PathDirectionality)
 5. [[9.5.] Implementation
 notes](paths.html#PathElementImplementationNotes)
 1. [[9.5.1.] Out-of-range elliptical arc
 parameters](paths.html#ArcOutOfRangeParameters)
 2. [[9.5.2.] Reflected control
 points](paths.html#ReflectedControlPoints)
 3. [[9.5.3.] Zero-length path
 segments](paths.html#ZeroLengthSegments)
 4. [[9.5.4.] Error handling in path
 data](paths.html#PathDataErrorHandling)
 6. [[9.6.] Distance along a
 path](paths.html#DistanceAlongAPath)
 1. [[9.6.1.] The ['pathLength']
 attribute](paths.html#PathLengthAttribute)
 7. [[9.7.] DOM interfaces](paths.html#DOMInterfaces)
 1. [[9.7.1.] Interface
 SVGPathElement](paths.html#InterfaceSVGPathElement)
10. [10.] [Basic Shapes](shapes.html)
 1. [[10.1.] Introduction and
 definitions](shapes.html#Introduction)
 2. [[10.2.] The ['rect']
 element](shapes.html#RectElement)
 3. [[10.3.] The ['circle']
 element](shapes.html#CircleElement)
 4. [[10.4.] The ['ellipse']
 element](shapes.html#EllipseElement)
 5. [[10.5.] The ['line']
 element](shapes.html#LineElement)
 6. [[10.6.] The ['polyline']
 element](shapes.html#PolylineElement)
 7. [[10.7.] The ['polygon']
 element](shapes.html#PolygonElement)
 8. [[10.8.] DOM interfaces](shapes.html#DOMInterfaces)
 1. [[10.8.1.] Interface
 SVGRectElement](shapes.html#InterfaceSVGRectElement)
 2. [[10.8.2.] Interface
 SVGCircleElement](shapes.html#InterfaceSVGCircleElement)
 3. [[10.8.3.] Interface
 SVGEllipseElement](shapes.html#InterfaceSVGEllipseElement)
 4. [[10.8.4.] Interface
 SVGLineElement](shapes.html#InterfaceSVGLineElement)
 5. [[10.8.5.] Mixin
 SVGAnimatedPoints](shapes.html#InterfaceSVGAnimatedPoints)
 6. [[10.8.6.] Interface
 SVGPointList](shapes.html#InterfaceSVGPointList)
 7. [[10.8.7.] Interface
 SVGPolylineElement](shapes.html#InterfaceSVGPolylineElement)
 8. [[10.8.8.] Interface
 SVGPolygonElement](shapes.html#InterfaceSVGPolygonElement)
11. [11.] [Text](text.html)
 1. [[11.1.] Introduction](text.html#Introduction)
 1. [[11.1.1.] Definitions](text.html#Definitions)
 2. [[11.1.2.] Fonts and glyphs](text.html#FontsGlyphs)
 3. [[11.1.3.] Glyph metrics and
 layout](text.html#GlyphsMetrics)
 2. [[11.2.] The ['text'] and
 ['tspan'] elements](text.html#TextElement)
 1. [[11.2.1.] Attributes](text.html#TSpanAttributes)
 2. [[11.2.2.] Notes on \'x\', \'y\', \'dx\', \'dy\' and
 \'rotate\'](text.html#TSpanNotes)
 3. [[11.3.] Text layout --
 Introduction](text.html#TextLayout)
 4. [[11.4.] Text layout -- Content
 Area](text.html#TextLayoutContentArea)
 1. [[11.4.1.] The '[inline-size]'
 property](text.html#InlineSize)
 2. [[11.4.2.] The '[shape-inside]'
 property](text.html#TextShapeInside)
 3. [[11.4.3.] The '[shape-subtract]'
 property](text.html#TextShapeSubtract)
 4. [[11.4.4.] The '[shape-image-threshold]'
 property](text.html#TextShapeImageThreshold)
 5. [[11.4.5.] The '[shape-margin]'
 property](text.html#TextShapeMargin)
 6. [[11.4.6.] The '[shape-padding]'
 property](text.html#TextShapePadding)
 5. [[11.5.] Text layout --
 Algorithm](text.html#TextLayoutAlgorithm)
 6. [[11.6.] Pre-formatted text](text.html#TextLayoutPre)
 1. [[11.6.1.] Multi-line text via
 \'white-space\'](text.html#TextLayoutPreMultiline)
 2. [[11.6.2.] Repositioning
 Glyphs](text.html#TextLayoutPreAdjustments)
 7. [[11.7.] Auto-wrapped text](text.html#TextLayoutAuto)
 1. [[11.7.1.] Notes on Text
 Wrapping](text.html#TextLayoutAutoNotes)
 1. [[11.7.1.1.] First Line
 Positioning](text.html#TextLayoutAutoNotesStart)
 2. [[11.7.1.2.] Broken
 Lines](text.html#TextLayoutAutoNotesBrokenLines)
 8. [[11.8.] Text on a path](text.html#TextLayoutPath)
 1. [[11.8.1.] The ['textPath']
 element](text.html#TextPathElement)
 2. [[11.8.2.] Attributes](text.html#TextPathAttributes)
 3. [[11.8.3.] Text on a path layout
 rules](text.html#TextpathLayoutRules)
 9. [[11.9.] Text rendering
 order](text.html#TextRenderingOrder)
 10. [[11.10.] Properties and
 pseudo-elements](text.html#TextProperties)
 1. [[11.10.1.] SVG
 properties](text.html#TextPropertiesSVG)
 1. [[11.10.1.1.] Text alignment, the
 '[text-anchor]'
 property](text.html#TextAnchoringProperties)
 2. [[11.10.1.2.] The
 '[glyph-orientation-horizontal]'
 property](text.html#GlyphOrientationHorizontalProperty)
 3. [[11.10.1.3.] The
 '[glyph-orientation-vertical]'
 property](text.html#GlyphOrientationVerticalProperty)
 4. [[11.10.1.4.] The '[kerning]'
 property](text.html#KerningProperty)
 2. [[11.10.2.] SVG
 adaptions](text.html#TextPropertiesAdaptions)
 1. [[11.10.2.1.] The '[font-variant]'
 property](text.html#FontVariantProperty)
 2. [[11.10.2.2.] The '[line-height]'
 property](text.html#LineHeightProperty)
 3. [[11.10.2.3.] The '[writing-mode]'
 property](text.html#WritingModeProperty)
 4. [[11.10.2.4.] The '[direction]'
 property](text.html#DirectionProperty)
 5. [[11.10.2.5.] The
 '[dominant-baseline]'
 property](text.html#DominantBaselineProperty)
 6. [[11.10.2.6.] The
 '[alignment-baseline]'
 property](text.html#AlignmentBaselineProperty)
 7. [[11.10.2.7.] The '[baseline-shift]'
 property](text.html#BaselineShiftProperty)
 8. [[11.10.2.8.] The '[letter-spacing]'
 property](text.html#LetterSpacingProperty)
 9. [[11.10.2.9.] The '[word-spacing]'
 property](text.html#WordSpacingProperty)
 10. [[11.10.2.10.] The '[text-overflow]'
 property](text.html#TextOverflowProperty)
 3. [[11.10.3.] White space](text.html#WhiteSpace)
 1. [[11.10.3.1.] SVG 2 Preferred white space
 handling, the '[white-space]'
 property](text.html#TextWhiteSpace)
 2. [[11.10.3.2.] Legacy white-space handling, the
 '[xml:space]'
 property](text.html#LegacyXMLSpace)
 3. [[11.10.3.3.] Duplicate white-space
 directives](text.html#DuplicateWhiteSpace)
 11. [[11.11.] Text
 decoration](text.html#TextDecorationProperties)
 12. [[11.12.] Text selection and clipboard
 operations](text.html#TextSelection)
 1. [[11.12.1.] Text selection implementation
 notes](text.html#TextSelectionImplementationNotes)
 13. [[11.13.] DOM interfaces](text.html#DOMInterfaces)
 1. [[11.13.1.] Interface
 SVGTextContentElement](text.html#InterfaceSVGTextContentElement)
 2. [[11.13.2.] Interface
 SVGTextPositioningElement](text.html#InterfaceSVGTextPositioningElement)
 3. [[11.13.3.] Interface
 SVGTextElement](text.html#InterfaceSVGTextElement)
 4. [[11.13.4.] Interface
 SVGTSpanElement](text.html#InterfaceSVGTSpanElement)
 5. [[11.13.5.] Interface
 SVGTextPathElement](text.html#InterfaceSVGTextPathElement)
12. [12.] [Embedded Content](embedded.html)
 1. [[12.1.] Overview](embedded.html#Overview)
 2. [[12.2.] Placement of the embedded
 content](embedded.html#Placement)
 3. [[12.3.] The ['image']
 element](embedded.html#ImageElement)
 4. [[12.4.] The ['foreignObject']
 element](embedded.html#ForeignObjectElement)
 5. [[12.5.] DOM interfaces](embedded.html#DOMInterfaces)
 1. [[12.5.1.] Interface
 SVGImageElement](embedded.html#InterfaceSVGImageElement)
 2. [[12.5.2.] Interface
 SVGForeignObjectElement](embedded.html#InterfaceSVGForeignObjectElement)
13. [13.] [Painting: Filling, Stroking and Marker
 Symbols](painting.html)
 1. [[13.1.] Introduction](painting.html#Introduction)
 1. [[13.1.1.] Definitions](painting.html#Definitions)
 2. [[13.2.] Specifying
 paint](painting.html#SpecifyingPaint)
 3. [[13.3.] The effect of the '[color]'
 property](painting.html#ColorProperty)
 4. [[13.4.] Fill properties](painting.html#FillProperties)
 1. [[13.4.1.] Specifying fill paint: the
 '[fill]'
 property](painting.html#SpecifyingFillPaint)
 2. [[13.4.2.] Winding rule: the
 '[fill-rule]'
 property](painting.html#WindingRule)
 3. [[13.4.3.] Fill paint opacity: the
 '[fill-opacity]'
 property](painting.html#FillOpacity)
 5. [[13.5.] Stroke
 properties](painting.html#StrokeProperties)
 1. [[13.5.1.] Specifying stroke paint: the
 '[stroke]'
 property](painting.html#SpecifyingStrokePaint)
 2. [[13.5.2.] Stroke paint opacity: the
 '[stroke-opacity]'
 property](painting.html#StrokeOpacity)
 3. [[13.5.3.] Stroke width: the
 '[stroke-width]'
 property](painting.html#StrokeWidth)
 4. [[13.5.4.] Drawing caps at the ends of strokes: the
 '[stroke-linecap]'
 property](painting.html#LineCaps)
 5. [[13.5.5.] Controlling line joins: the
 '[stroke-linejoin]' and
 '[stroke-miterlimit]'
 properties](painting.html#LineJoin)
 6. [[13.5.6.] Dashing strokes: the
 '[stroke-dasharray]' and
 '[stroke-dashoffset]'
 properties](painting.html#StrokeDashing)
 7. [[13.5.7.] Computing the shape of the
 stroke](painting.html#StrokeShape)
 8. [[13.5.8.] Computing the circles for the
 [arcs]
 \'stroke-linejoin\'](painting.html#CurvatureCalculation)
 9. [[13.5.9.] Adjusting the circles for the
 [arcs] \'stroke-linejoin\' when the initial
 circles do not
 intersect](painting.html#ArcsLinejoinFallback)
 6. [[13.6.] Vector
 effects](painting.html#PaintingVectorEffects)
 7. [[13.7.] Markers](painting.html#Markers)
 1. [[13.7.1.] The ['marker']
 element](painting.html#MarkerElement)
 2. [[13.7.2.] Vertex markers: the
 '[marker-start]', '[marker-mid]' and
 '[marker-end]'
 properties](painting.html#VertexMarkerProperties)
 3. [[13.7.3.] Marker shorthand: the
 '[marker]'
 property](painting.html#MarkerShorthand)
 4. [[13.7.4.] Rendering
 markers](painting.html#RenderingMarkers)
 8. [[13.8.] Controlling paint operation order: the
 '[paint-order]' property](painting.html#PaintOrder)
 9. [[13.9.] Color space for interpolation: the
 '[color-interpolation]'
 property](painting.html#ColorInterpolation)
 10. [[13.10.] Rendering hints](painting.html#RenderingHints)
 1. [[13.10.1.] The '[shape-rendering]'
 property](painting.html#ShapeRendering)
 2. [[13.10.2.] The '[text-rendering]'
 property](painting.html#TextRendering)
 3. [[13.10.3.] The '[image-rendering]'
 property](painting.html#ImageRendering)
 11. [[13.11.] The effect of the '[will-change]'
 property](painting.html#WillChange)
 12. [[13.12.] DOM interfaces](painting.html#DOMInterfaces)
 1. [[13.12.1.] Interface
 SVGMarkerElement](painting.html#InterfaceSVGMarkerElement)
14. [14.] [Paint Servers: Gradients and Patterns](pservers.html)
 1. [[14.1.] Introduction](pservers.html#Introduction)
 1. [[14.1.1.] Using paint servers as
 templates](pservers.html#PaintServerTemplates)
 2. [[14.2.] Gradients](pservers.html#Gradients)
 1. [[14.2.1.] Definitions](pservers.html#Definitions)
 2. [[14.2.2.] Linear
 gradients](pservers.html#LinearGradients)
 1. [[14.2.2.1.]
 Attributes](pservers.html#LinearGradientAttributes)
 2. [[14.2.2.2.] Notes on linear
 gradients](pservers.html#LinearGradientNotes)
 3. [[14.2.3.] Radial
 gradients](pservers.html#RadialGradients)
 1. [[14.2.3.1.]
 Attributes](pservers.html#RadialGradientAttributes)
 2. [[14.2.3.2.] Notes on radial
 gradients](pservers.html#RadialGradientNotes)
 4. [[14.2.4.] Gradient
 stops](pservers.html#GradientStops)
 1. [[14.2.4.1.]
 Attributes](pservers.html#GradientStopAttributes)
 2. [[14.2.4.2.]
 Properties](pservers.html#StopColorProperties)
 3. [[14.2.4.3.] Notes on gradient
 stops](pservers.html#StopNotes)
 3. [[14.3.] Patterns](pservers.html#Patterns)
 1. [[14.3.1.]
 Attributes](pservers.html#PatternElementAttributes)
 2. [[14.3.2.] Notes on
 patterns](pservers.html#PatternNotes)
 4. [[14.4.] DOM interfaces](pservers.html#DOMInterfaces)
 1. [[14.4.1.] Interface
 SVGGradientElement](pservers.html#InterfaceSVGGradientElement)
 2. [[14.4.2.] Interface
 SVGLinearGradientElement](pservers.html#InterfaceSVGLinearGradientElement)
 3. [[14.4.3.] Interface
 SVGRadialGradientElement](pservers.html#InterfaceSVGRadialGradientElement)
 4. [[14.4.4.] Interface
 SVGStopElement](pservers.html#InterfaceSVGStopElement)
 5. [[14.4.5.] Interface
 SVGPatternElement](pservers.html#InterfaceSVGPatternElement)
15. [15.] [Scripting and Interactivity](interact.html)
 1. [[15.1.] Introduction](interact.html#Introduction)
 2. [[15.2.] Supported events](interact.html#SVGEvents)
 1. [[15.2.1.] Relationship with UI
 Events](interact.html#RelationshipWithUIEVENTS)
 3. [[15.3.] User interface events](interact.html#UIEvents)
 4. [[15.4.] Pointer events](interact.html#PointerEvents)
 5. [[15.5.] Hit-testing and processing order for user
 interface events](interact.html#pointer-processing)
 1. [[15.5.1.] Hit-testing](interact.html#hit-testing)
 2. [[15.5.2.] Event
 processing](interact.html#event-processing)
 6. [[15.6.] The '[pointer-events]'
 property](interact.html#PointerEventsProp)
 7. [[15.7.] Focus](interact.html#Focus)
 8. [[15.8.] Event
 attributes](interact.html#EventAttributes)
 1. [[15.8.1.] Animation event
 attributes](interact.html#AnimationEvents)
 9. [[15.9.] The ['script']
 element](interact.html#ScriptElement)
 10. [[15.10.] DOM interfaces](interact.html#DOMInterfaces)
 1. [[15.10.1.] Interface
 SVGScriptElement](interact.html#InterfaceSVGScriptElement)
16. [16.] [Linking](linking.html)
 1. [[16.1.] References](linking.html#URLReference)
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
17. [Appendix A: IDL Definitions](idl.html)
18. [Appendix B: Implementation Notes](implnote.html)
 1. [[B.1.] Introduction](implnote.html#Introduction)
 2. [[B.2.] Elliptical arc parameter
 conversion](implnote.html#ArcImplementationNotes)
 1. [[B.2.1.] Elliptical arc endpoint
 syntax](implnote.html#ArcSyntax)
 2. [[B.2.2.] Parameterization
 alternatives](implnote.html#ArcParameterizationAlternatives)
 3. [[B.2.3.] Conversion from center to endpoint
 parameterization](implnote.html#ArcConversionCenterToEndpoint)
 4. [[B.2.4.] Conversion from endpoint to center
 parameterization](implnote.html#ArcConversionEndpointToCenter)
 5. [[B.2.5.] Correction of out-of-range
 radii](implnote.html#ArcCorrectionOutOfRangeRadii)
 3. [[B.3.] Notes on generating high-precision
 geometry](implnote.html#NumericPrecisionImplementationNotes)
19. [Appendix C: Accessibility Support](access.html)
 1. [[C.1.] SVG Accessibility
 Features](access.html#AccessibilityAndSVG)
 2. [[C.2.] Supporting SVG Accessibility Specifications and
 Guidelines](access.html#SVGRelatedAccessibilityDocuments)
20. [Appendix D: Animating SVG Documents](animate.html)
21. [Appendix E: References](refs.html)
 1. [[E.1.] Normative
 references](refs.html#NormativeReferences)
 2. [[E.2.] Informative
 references](refs.html#InformativeReferences)
22. [Appendix F: Element Index](eltindex.html)
23. [Appendix G: Attribute Index](attindex.html)
 1. [[G.1.] Regular
 attributes](attindex.html#RegularAttributes)
 2. [[G.2.] Presentation
 attributes](attindex.html#PresentationAttributes)
24. [Appendix H: Property Index](propidx.html)
25. [Appendix I: IDL Index](idlindex.html)
26. [Appendix J: Media Type Registration for
 image/svg+xml](mimereg.html)
 1. [[J.1.] Introduction](mimereg.html#mime-intro)
 2. [[J.2.] Registration of media type
 image/svg+xml](mimereg.html#mime-registration)
27. [Appendix K: Changes from SVG 1.1](changes.html)
 1. [[K.1.] Editorial changes](changes.html#editorial)
 2. [[K.2.] Substantial changes](changes.html#substantial)
 1. [[K.2.1.] Across the whole
 document](changes.html#whole)
 2. [[K.2.2.] Concepts chapter (SVG 1.1
 only)](changes.html#concepts)
 3. [[K.2.3.] Conformance Criteria chapter (Appendix in
 SVG 1.1)](changes.html#conform)
 4. [[K.2.4.] Rendering Model
 chapter](changes.html#rendering)
 5. [[K.2.5.] Basic Data Types and Interfaces
 chapter](changes.html#types)
 6. [[K.2.6.] Document Structure
 chapter](changes.html#structure)
 7. [[K.2.7.] Styling chapter](changes.html#styling)
 8. [[K.2.8.] Geometry Properties chapter (SVG 2
 only)](changes.html#geometry)
 9. [[K.2.9.] Coordinate Systems, Transformations and
 Units chapter](changes.html#coords)
 10. [[K.2.10.] Paths chapter](changes.html#paths)
 11. [[K.2.11.] Basic Shapes
 chapter](changes.html#shapes)
 12. [[K.2.12.] Text chapter](changes.html#text)
 13. [[K.2.13.] Embedded Content chapter (SVG 2
 only)](changes.html#embedded)
 14. [[K.2.14.] Painting chapter](changes.html#painting)
 15. [[K.2.15.] Color chapter (SVG 1.1
 only)](changes.html#color)
 16. [[K.2.16.] Paint Servers chapter (called Gradients
 and Patterns in SVG 1.1)](changes.html#pservers)
 17. [[K.2.17.] Clipping, Masking and Compositing chapter
 (SVG 1.1 only)](changes.html#masking)
 18. [[K.2.18.] Filter Effects chapter (SVG 1.1
 only)](changes.html#filters)
 19. [[K.2.19.] Scripting and Interactivity chapter
 (separate chapters in SVG 1.1)](changes.html#interact)
 20. [[K.2.20.] Linking chapter](changes.html#linking)
 21. [[K.2.21.] Scripting chapter (in SVG
 1.1)](changes.html#script)
 22. [[K.2.22.] Animation chapter (SVG 1.1
 only)](changes.html#animate)
 23. [[K.2.23.] Fonts chapter (SVG 1.1
 only)](changes.html#fonts)
 24. [[K.2.24.] Metadata chapter (SVG 1.1
 only)](changes.html#metadata)
 25. [[K.2.25.] Backwards Compatibility chapter (SVG 1.1
 only)](changes.html#backward)
 26. [[K.2.26.] Extensibility chapter (SVG 1.1
 only)](changes.html#extend)
 27. [[K.2.27.] Document Type Definition appendix (SVG
 1.1 only)](changes.html#svgdtd)
 28. [[K.2.28.] SVG Document Object Model (DOM)(SVG 1.1
 Only)](changes.html#svgdom)
 29. [[K.2.29.] IDL Definitions
 appendix](changes.html#idl)
 30. [[K.2.30.] Java Language Binding appendix (SVG 1.1
 only)](changes.html#java)
 31. [[K.2.31.] ECMAScript Language Binding appendix (SVG
 1.1 only)](changes.html#escript)
 32. [[K.2.32.] Implementation Notes appendix (was
 Implementation Requirements in SVG
 1.1)](changes.html#impreqs)
 33. [[K.2.33.] Accessibility Support
 appendix](changes.html#access)
 34. [[K.2.34.] Internationalization Support appendix
 (SVG 1.1 only)](changes.html#i18n)
 35. [[K.2.35.] Minimizing SVG File Sizes appendix (SVG
 1.1 only)](changes.html#minimize)
 36. [[K.2.36.] Animating SVG Documents appendix (SVG 2
 only)](changes.html#animate-appendix)
 37. [[K.2.37.] References appendix](changes.html#refs)
 38. [[K.2.38.] Element, Attribute, and Property index
 appendices](changes.html#other-appendix)
 39. [[K.2.39.] IDL Index appendix (SVG 2
 only)](changes.html#idlindex)
 40. [[K.2.40.] Feature Strings (SVG 1.1
 only)](changes.html#feature)

## Acknowledgments

The SVG Working Group would like to thank the following people for
contributing to this specification with patches or by participating in
discussions that resulted in changes to the document: David Dailey, Eric
Eastwood, Jarek Foksa, Daniel Holbert, Paul LeBeau, Robert Longson,
Henri Manson, Ms2ger, Kari Pihkala, Philip Rogers, David Zbarsky.

In addition, the SVG Working Group would like to acknowledge the
contributions of the editors and authors of the previous versions of SVG
-- as much of the text in this document derives from these earlier
specifications -- including:

- Patrick Dengler, Microsoft Corporation [(Version 1.1 Second
 Edition)]
- Jon Ferraiolo, ex Adobe Systems [(Versions 1.0 and 1.1 First Edition;
 until 10 May 2006)]
- Anthony Grasso, ex Canon Inc. [(Version 1.1 Second
 Edition)]
- Dean Jackson, ex W3C [(Version 1.1 First Edition; until February
 2007)]
- 藤沢 淳 (FUJISAWA Jun), Canon Inc. [(Version 1.1 First
 Edition)]

Finally, the SVG Working Group would like to acknowledge the great many
people outside of the SVG Working Group who help with the process of
developing the SVG specifications. These people are too numerous to list
individually. They include but are not limited to the early implementers
of the SVG 1.0 and 1.1 languages (including viewers, authoring tools,
and server-side transcoders), developers of SVG content, people who have
contributed on the [www-svg@w3.org] and
[svg-developers@yahoogroups.com] email lists, other Working Groups
at the W3C, and the W3C Team. SVG 1.1 is truly a cooperative effort
between the SVG Working Group, the rest of the W3C, and the public and
benefits greatly from the pioneering work of early implementers and
content developers, feedback from the public, and help from the W3C
team.
