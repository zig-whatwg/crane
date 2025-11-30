::: head
[![W3C](https://www.w3.org/StyleSheets/TR/2016/logos/W3C){height="48"
width="72"}](https://www.w3.org/)

# Scalable Vector Graphics (SVG) 2 {#pagetitle}

## W3C Editor's Draft *14 September 2025* {#pagesubtitle}

This version:
:   [https://svgwg.org/svg2-draft/](https://svgwg.org/svg2-draft/){.url}

Latest version:
:   [https://www.w3.org/TR/SVG2/](https://www.w3.org/TR/SVG2/){.url}

Previous version:
:   [https://www.w3.org/TR/2018/CR-SVG2-20180807/](https://www.w3.org/TR/2018/CR-SVG2-20180807/){.url}

Single page version:
:   [https://svgwg.org/svg2-draft/single-page.html](single-page.html){.url}

GitHub repository:
:   <https://github.com/w3c/svgwg/>

Public comments:
:   [www-svg@w3.org](mailto:www-svg@w3.org){.url}
    ([archive](http://lists.w3.org/Archives/Public/www-svg/))

Editors:
:   Amelia Bellamy-Royds, Invited Expert
    \<[amelia.bellamy.royds@gmail.com](mailto:amelia.bellamy.royds@gmail.com){.url}\>
:   Tavmjong Bah, Invited Expert
    \<[tavmjong@free.fr](mailto:tavmjong@free.fr){.url}\>
:   Chris Lilley, W3C \<[chris@w3.org](mailto:chris@w3.org){.url}\>
:   Dirk Schulze, Adobe Systems
    \<[dschulze@adobe.com](mailto:dschulze@adobe.com){.url}\>
:   Eric Willigers, Google

Former Editors:
:   Nikos Andronikos, Canon, Inc.
    \<[nikos.andronikos@cisra.canon.com.au](mailto:nikos.andronikos@cisra.canon.com.au){.url}\>
:   Rossen Atanassov, Microsoft Co.
    \<[ratan@microsoft.com](mailto:ratan@microsoft.com){.url}\>
:   Brian Birtles, Mozilla Japan
    \<[bbirtles@mozilla.com](mailto:bbirtles@mozilla.com){.url}\>
:   Bogdan Brinza, Microsoft Co.
    \<[bbrinza@microsoft.com](mailto:bbrinza@microsoft.com){.url}\>
:   Cyril Concolato, Telecom ParisTech
    \<[cyril.concolato@telecom-paristech.fr](mailto:cyril.concolato@telecom-paristech.fr){.url}\>
:   Erik Dahlström, Invited Expert
    \<[erik@dahlström.net](mailto:erik@xn--dahlstrm-t4a.net){.url}\>
:   Cameron McCormack, Mozilla Corporation
    \<[cam@mcc.id.au](mailto:cam@mcc.id.au){.url}\>
:   David Storey, Microsoft Co.
    \<[dstorey@microsoft.com](mailto:dstorey@microsoft.com){.url}\>
:   Doug Schepers, W3C
    \<[schepers@w3.org](mailto:schepers@w3.org){.url}\>
:   Richard Schwerdtfeger, IBM
    \<[schwer@us.ibm.com](mailto:schwer@us.ibm.com){.url}\>
:   Satoru Takagi, KDDI Corporation
    \<[sa-takagi@kddi.com](mailto:sa-takagi@kddi.com){.url}\>
:   Jonathan Watt, Mozilla Corporation
    \<[jwatt@jwatt.org](mailto:jwatt@jwatt.org){.url}\>

[Copyright](http://www.w3.org/Consortium/Legal/ipr-notice#Copyright) ©
2025 [[W3C]{.abbr
title="World Wide Web Consortium"}](http://www.w3.org/)^®^ ([[MIT]{.abbr
title="Massachusetts Institute of Technology"}](http://www.csail.mit.edu/),
[[ERCIM]{.abbr
title="European Research Consortium for Informatics and Mathematics"}](http://www.ercim.eu/),
[Keio](http://www.keio.ac.jp/), [Beihang](http://ev.buaa.edu.cn/)). W3C
[liability](http://www.w3.org/Consortium/Legal/ipr-notice#Legal_Disclaimer),
[trademark](http://www.w3.org/Consortium/Legal/ipr-notice#W3C_Trademarks)
and [document
use](http://www.w3.org/Consortium/Legal/copyright-documents) rules
apply.

------------------------------------------------------------------------
:::

## Abstract

This specification defines the features and syntax for Scalable Vector
Graphics (SVG) Version 2. SVG is a language based on XML for describing
two-dimensional vector and mixed vector/raster graphics. SVG content is
stylable, scalable to different display resolutions, and can be viewed
stand-alone, mixed with HTML content, or embedded using XML namespaces
within other XML languages. SVG also supports dynamic changes; script
can be used to create interactive documents, and animations can be
performed using declarative animation features or by using script.

## Status of This Document {#status}

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
[www-svg@w3.org](mailto:www-svg@w3.org){.url}, the public email list for
issues related to vector graphics on the Web. This list is
[archived](http://lists.w3.org/Archives/Public/www-svg/) and senders
must agree to have their message publicly archived from their first
posting. To subscribe send an email to
[www-svg-request@w3.org](mailto:www-svg-request@w3.org){.url} with the
word `subscribe` in the subject line.

::: note
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
:::

This document has been produced by the [W3C SVG Working
Group](https://www.w3.org/Graphics/SVG/WG/) as part of the [Graphics
Activity](https://www.w3.org/Graphics/Activity) within the [W3C
Interaction Domain](https://www.w3.org/Interaction/). The goals of the
W3C SVG Working Group are discussed in the [W3C SVG
Charter](https://www.w3.org/Graphics/SVG/svg-2019.html). The W3C SVG
Working Group maintains a public Web page,
[https://www.w3.org/Graphics/SVG/](https://www.w3.org/Graphics/SVG/){.url},
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
be found at [https://www.w3.org/TR/](https://www.w3.org/TR/){.url}. W3C
publications may be updated, replaced, or obsoleted by other documents
at any time.

This document is governed by the [1 September 2015 W3C Process
Document](https://www.w3.org/2015/Process-20150901/){#w3c_process_revision}.

All features in this specification depend upon implementation in
browsers or authoring tools. If a feature is not certain to be
implemented, we define that feature as \"at risk\". At-risk features
will be removed from the current specification, and may be included in
future versions of the specification. If an at-risk feature is
particularly important to authors of SVG, those authors are encouraged
to give feedback to implementers regarding its priority. The following
features are at risk, and may be dropped during the CR period:

- More than one ['[title](struct.html#TitleElement)']{.element-name} or
  ['[desc](struct.html#DescElement)']{.element-name} to provide
  localisation
- [Nested links](linking.html#Links)
- [vector-effect](coords.html#VectorEffectProperty){.property} options
  other than [non-scaling-stroke]{.prop-value}
- [stroke-linejoin](painting.html#StrokeLinejoinProperty){.property}
  options [miter-clip]{.prop-value} and [arcs]{.prop-value}
- the [shape-inside](text.html#TextShapeInside){.property} and
  [shape-subtract](text.html#TextShapeSubtract){.property} properties

## Table of Contents {#fulltoc}

1.  [1.]{.secno} [Introduction](intro.html)
    1.  [[1.1.]{.secno} About SVG](intro.html#AboutSVG)
    2.  [[1.2.]{.secno} Compatibility with other standards
        efforts](intro.html#W3CCompatibility)
    3.  [[1.3.]{.secno} Relationship to previous versions of this
        standard](intro.html#RelationshipToPrevious)
    4.  [[1.4.]{.secno} Normative
        Terminology](intro.html#ConformanceTerms)
2.  [2.]{.secno} [Conformance Criteria](conform.html)
    1.  [[2.1.]{.secno} Overview](conform.html#conformance-overview)
    2.  [[2.2.]{.secno} Processing modes](conform.html#processing-modes)
        1.  [[2.2.1.]{.secno} Features](conform.html#features)
        2.  [[2.2.2.]{.secno} Dynamic interactive
            mode](conform.html#dynamic-interactive-mode)
        3.  [[2.2.3.]{.secno} Animated mode](conform.html#animated-mode)
        4.  [[2.2.4.]{.secno} Secure animated
            mode](conform.html#secure-animated-mode)
        5.  [[2.2.5.]{.secno} Static mode](conform.html#static-mode)
        6.  [[2.2.6.]{.secno} Secure static
            mode](conform.html#secure-static-mode)
    3.  [[2.3.]{.secno} Processing modes for SVG sub-resource
        documents](conform.html#referencing-modes)
        1.  [[2.3.1.]{.secno} Examples](conform.html#examples)
    4.  [[2.4.]{.secno} Document Conformance
        Classes](conform.html#DocumentConformanceClasses)
        1.  [[2.4.1.]{.secno} Conforming SVG DOM
            Subtrees](conform.html#ConformingSVGDOMSubtrees)
        2.  [[2.4.2.]{.secno} Conforming SVG Markup
            Fragments](conform.html#ConformingSVGFragments)
        3.  [[2.4.3.]{.secno} Conforming XML-Compatible SVG Markup
            Fragments](conform.html#ConformingSVGXMLFragments)
        4.  [[2.4.4.]{.secno} Conforming XML-Compatible SVG DOM
            Subtrees](conform.html#ConformingSVGXMLDOMSubtrees)
        5.  [[2.4.5.]{.secno} Conforming SVG Stand-Alone
            Files](conform.html#ConformingSVGStandAloneFiles)
        6.  [[2.4.6.]{.secno} Error
            processing](conform.html#ErrorProcessing)
    5.  [[2.5.]{.secno} Software Conformance
        Classes](conform.html#SoftwareConformanceClasses)
        1.  [[2.5.1.]{.secno} Conforming SVG
            Generators](conform.html#ConformingSVGGenerators)
        2.  [[2.5.2.]{.secno} Conforming SVG Authoring
            Tools](conform.html#ConformingSVGAuthoringTools)
        3.  [[2.5.3.]{.secno} Conforming SVG
            Servers](conform.html#ConformingSVGServers)
        4.  [[2.5.4.]{.secno} Conforming SVG
            Interpreters](conform.html#ConformingSVGInterpreters)
        5.  [[2.5.5.]{.secno} Conforming SVG
            Viewers](conform.html#ConformingSVGViewers)
            1.  [[2.5.5.1.]{.secno} Printing implementation
                notes](conform.html#PrintingImplementationNotes)
        6.  [[2.5.6.]{.secno} Conforming High-Quality SVG
            Viewer](conform.html#ConformingHighQualitySVGViewers)
3.  [3.]{.secno} [Rendering Model](render.html)
    1.  [[3.1.]{.secno} Introduction](render.html#Introduction)
    2.  [[3.2.]{.secno} The rendering tree](render.html#RenderingTree)
        1.  [[3.2.1.]{.secno} Definitions](render.html#Definitions)
        2.  [[3.2.2.]{.secno} Rendered versus non-rendered
            elements](render.html#Rendered-vs-NonRendered)
        3.  [[3.2.3.]{.secno} Controlling visibility: the effect of the
            '[display]{.property}' and '[visibility]{.property}'
            properties](render.html#VisibilityControl)
        4.  [[3.2.4.]{.secno} Re-used
            graphics](render.html#ReusedGraphics)
    3.  [[3.3.]{.secno} The painters model](render.html#PaintersModel)
    4.  [[3.4.]{.secno} Rendering order](render.html#RenderingOrder)
        1.  [[3.4.1.]{.secno} Establishing a stacking context in
            SVG](render.html#EstablishingStackingContex)
    5.  [[3.5.]{.secno} How elements are rendered](render.html#Elements)
    6.  [[3.6.]{.secno} How groups are rendered](render.html#Grouping)
        1.  [[3.6.1.]{.secno} Object and group opacity: the effect of
            the '[opacity]{.property}'
            property](render.html#ObjectAndGroupOpacityProperties)
    7.  [[3.7.]{.secno} Types of graphics
        elements](render.html#TypesOfGraphicsElements)
        1.  [[3.7.1.]{.secno} Painting shapes and
            text](render.html#PaintingShapesAndText)
        2.  [[3.7.2.]{.secno} Painting raster
            images](render.html#PaintingRasterImages)
    8.  [[3.8.]{.secno} Filtering painted
        regions](render.html#FilteringPaintRegions)
    9.  [[3.9.]{.secno} Clipping and
        masking](render.html#ClippingAndMasking)
    10. [[3.10.]{.secno} Parent
        compositing](render.html#ParentCompositing)
    11. [[3.11.]{.secno} The effect of the '[overflow]{.property}'
        property](render.html#OverflowAndClipProperties)
4.  [4.]{.secno} [Basic Data Types and Interfaces](types.html)
    1.  [[4.1.]{.secno} Definitions](types.html#definitions)
    2.  [[4.2.]{.secno} Attribute syntax](types.html#syntax)
        1.  [[4.2.1.]{.secno} Real number
            precision](types.html#Precision)
        2.  [[4.2.2.]{.secno} Clamping values which are restricted to a
            particular range](types.html#RangeClamping)
    3.  [[4.3.]{.secno} SVG DOM overview](types.html#SVGDOMOverview)
        1.  [[4.3.1.]{.secno} Dependencies for SVG DOM
            support](types.html#SVGDOMDependencies)
        2.  [[4.3.2.]{.secno} Naming
            conventions](types.html#SVGDOMNamingConventions)
        3.  [[4.3.3.]{.secno} Elements in the SVG
            DOM](types.html#ElementsInTheSVGDOM)
        4.  [[4.3.4.]{.secno} Reflecting content attributes in the
            DOM](types.html#ReflectingAttributes)
        5.  [[4.3.5.]{.secno} Synchronizing reflected
            values](types.html#SynchronizingReflectedValues)
        6.  [[4.3.6.]{.secno} Reflecting an empty initial
            value](types.html#SVGObjectInitialization)
        7.  [[4.3.7.]{.secno} Invalid values](types.html#InvalidValues)
    4.  [[4.4.]{.secno} DOM interfaces for SVG
        elements](types.html#DOMInterfacesForSVGElements)
        1.  [[4.4.1.]{.secno} Interface
            SVGElement](types.html#InterfaceSVGElement)
        2.  [[4.4.2.]{.secno} Interface
            SVGGraphicsElement](types.html#InterfaceSVGGraphicsElement)
        3.  [[4.4.3.]{.secno} Interface
            SVGGeometryElement](types.html#InterfaceSVGGeometryElement)
    5.  [[4.5.]{.secno} DOM interfaces for basic data
        types](types.html#DOMInterfacesForBasicDataTypes)
        1.  [[4.5.1.]{.secno} Interface
            SVGNumber](types.html#InterfaceSVGNumber)
        2.  [[4.5.2.]{.secno} Interface
            SVGLength](types.html#InterfaceSVGLength)
        3.  [[4.5.3.]{.secno} Interface
            SVGAngle](types.html#InterfaceSVGAngle)
        4.  [[4.5.4.]{.secno} List
            interfaces](types.html#ListInterfaces)
        5.  [[4.5.5.]{.secno} Interface
            SVGNumberList](types.html#InterfaceSVGNumberList)
        6.  [[4.5.6.]{.secno} Interface
            SVGLengthList](types.html#InterfaceSVGLengthList)
        7.  [[4.5.7.]{.secno} Interface
            SVGStringList](types.html#InterfaceSVGStringList)
    6.  [[4.6.]{.secno} DOM interfaces for reflecting animatable SVG
        attributes](types.html#DOMInterfacesForReflectingSVGAttributes)
        1.  [[4.6.1.]{.secno} Interface
            SVGAnimatedBoolean](types.html#InterfaceSVGAnimatedBoolean)
        2.  [[4.6.2.]{.secno} Interface
            SVGAnimatedEnumeration](types.html#InterfaceSVGAnimatedEnumeration)
        3.  [[4.6.3.]{.secno} Interface
            SVGAnimatedInteger](types.html#InterfaceSVGAnimatedInteger)
        4.  [[4.6.4.]{.secno} Interface
            SVGAnimatedNumber](types.html#InterfaceSVGAnimatedNumber)
        5.  [[4.6.5.]{.secno} Interface
            SVGAnimatedLength](types.html#InterfaceSVGAnimatedLength)
        6.  [[4.6.6.]{.secno} Interface
            SVGAnimatedAngle](types.html#InterfaceSVGAnimatedAngle)
        7.  [[4.6.7.]{.secno} Interface
            SVGAnimatedString](types.html#InterfaceSVGAnimatedString)
        8.  [[4.6.8.]{.secno} Interface
            SVGAnimatedRect](types.html#InterfaceSVGAnimatedRect)
        9.  [[4.6.9.]{.secno} Interface
            SVGAnimatedNumberList](types.html#InterfaceSVGAnimatedNumberList)
        10. [[4.6.10.]{.secno} Interface
            SVGAnimatedLengthList](types.html#InterfaceSVGAnimatedLengthList)
    7.  [[4.7.]{.secno} Other DOM
        interfaces](types.html#OtherDOMInterfaces)
        1.  [[4.7.1.]{.secno} Interface
            SVGUnitTypes](types.html#InterfaceSVGUnitTypes)
        2.  [[4.7.2.]{.secno} Mixin
            SVGTests](types.html#InterfaceSVGTests)
        3.  [[4.7.3.]{.secno} Mixin
            SVGFitToViewBox](types.html#InterfaceSVGFitToViewBox)
        4.  [[4.7.4.]{.secno} Mixin
            SVGURIReference](types.html#InterfaceSVGURIReference)
5.  [5.]{.secno} [Document Structure](struct.html)
    1.  [[5.1.]{.secno} Defining an SVG document fragment: the
        ['svg']{.element-name} element](struct.html#NewDocument)
        1.  [[5.1.1.]{.secno} Overview](struct.html#NewDocumentOverview)
        2.  [[5.1.2.]{.secno} Namespace](struct.html#Namespace)
        3.  [[5.1.3.]{.secno} Definitions](struct.html#Definitions)
        4.  [[5.1.4.]{.secno} The ['svg']{.element-name}
            element](struct.html#SVGElement)
    2.  [[5.2.]{.secno} Grouping: the ['g']{.element-name}
        element](struct.html#Groups)
        1.  [[5.2.1.]{.secno} Overview](struct.html#GroupsOverview)
        2.  [[5.2.2.]{.secno} The ['g']{.element-name}
            element](struct.html#GElement)
    3.  [[5.3.]{.secno} Defining content for reuse, and the
        ['defs']{.element-name} element](struct.html#Head)
        1.  [[5.3.1.]{.secno} Overview](struct.html#Overview)
        2.  [[5.3.2.]{.secno} The ['defs']{.element-name}
            element](struct.html#DefsElement)
    4.  [[5.4.]{.secno} The ['symbol']{.element-name}
        element](struct.html#SymbolElement)
        1.  [[5.4.1.]{.secno} Attributes](struct.html#SymbolAttributes)
        2.  [[5.4.2.]{.secno} Notes on symbols](struct.html#SymbolNotes)
    5.  [[5.5.]{.secno} The ['use']{.element-name}
        element](struct.html#UseElement)
        1.  [[5.5.1.]{.secno} The use-element shadow
            tree](struct.html#UseShadowTree)
        2.  [[5.5.2.]{.secno} Layout of re-used
            graphics](struct.html#UseLayout)
        3.  [[5.5.3.]{.secno} Style Scoping and
            Inheritance](struct.html#UseStyleInheritance)
        4.  [[5.5.4.]{.secno} Animations in use-element shadow
            trees](struct.html#UseAnimations)
        5.  [[5.5.5.]{.secno} Event handling in use-element shadow
            trees](struct.html#UseEventHandling)
    6.  [[5.6.]{.secno} Conditional
        processing](struct.html#ConditionalProcessing)
        1.  [[5.6.1.]{.secno} Conditional processing
            overview](struct.html#ConditionalProcessingOverview)
        2.  [[5.6.2.]{.secno}
            Definitions](struct.html#ConditionalProcessingDefinitions)
        3.  [[5.6.3.]{.secno} The ['switch']{.element-name}
            element](struct.html#SwitchElement)
        4.  [[5.6.4.]{.secno} The ['requiredExtensions']{.attr-name}
            attribute](struct.html#ConditionalProcessingRequiredExtensionsAttribute)
        5.  [[5.6.5.]{.secno} The ['systemLanguage']{.attr-name}
            attribute](struct.html#ConditionalProcessingSystemLanguageAttribute)
    7.  [[5.7.]{.secno} The ['desc']{.element-name} and
        ['title']{.element-name}
        elements](struct.html#DescriptionAndTitleElements)
        1.  [[5.7.1.]{.secno}
            Definition](struct.html#DescriptionDefinitions)
    8.  [[5.8.]{.secno} The ['metadata']{.element-name}
        element](struct.html#MetadataElement)
    9.  [[5.9.]{.secno} HTML metadata
        elements](struct.html#HTMLMetadataElements)
    10. [[5.10.]{.secno} Foreign namespaces and private
        data](struct.html#ForeignNamespaces)
    11. [[5.11.]{.secno} Common
        attributes](struct.html#CommonAttributes)
        1.  [[5.11.1.]{.secno}
            Definitions](struct.html#CommonAttributeDefinitions)
        2.  [[5.11.2.]{.secno} Attributes common to all elements:
            ['id']{.attr-name}](struct.html#Core.attrib)
        3.  [[5.11.3.]{.secno} The ['lang']{.attr-name} and
            ['xml:lang']{.attr-name}
            attributes](struct.html#LangSpaceAttrs)
        4.  [[5.11.4.]{.secno} The ['xml:space']{.attr-name}
            attribute](struct.html#WhitespaceProcessingXMLSpaceAttribute)
        5.  [[5.11.5.]{.secno} The ['tabindex']{.attr-name}
            attribute](struct.html#tabindexattribute)
        6.  [[5.11.6.]{.secno} The ['autofocus']{.attr-name}
            attribute](struct.html#autofocusattribute)
        7.  [[5.11.7.]{.secno} The ['data-\*']{.attr-name}
            attributes](struct.html#DataAttributes)
    12. [[5.12.]{.secno} WAI-ARIA
        attributes](struct.html#WAIARIAAttributes)
        1.  [[5.12.1.]{.secno}
            Definitions](struct.html#WAIARIA-definitions)
        2.  [[5.12.2.]{.secno} Role
            attribute](struct.html#roleattribute)
        3.  [[5.12.3.]{.secno} State and property attributes (all aria-
            attributes)](struct.html#ARIAStateandPropertyAttributes)
        4.  [[5.12.4.]{.secno} Implicit and Allowed ARIA
            Semantics](struct.html#implicit-aria-semantics)
    13. [[5.13.]{.secno} DOM interfaces](struct.html#DOMInterfaces)
        1.  [[5.13.1.]{.secno} Extensions to the Document
            interface](struct.html#InterfaceDocumentExtensions)
        2.  [[5.13.2.]{.secno} Interface
            SVGSVGElement](struct.html#InterfaceSVGSVGElement)
        3.  [[5.13.3.]{.secno} Interface
            SVGGElement](struct.html#InterfaceSVGGElement)
        4.  [[5.13.4.]{.secno} Interface
            SVGDefsElement](struct.html#InterfaceSVGDefsElement)
        5.  [[5.13.5.]{.secno} Interface
            SVGDescElement](struct.html#InterfaceSVGDescElement)
        6.  [[5.13.6.]{.secno} Interface
            SVGMetadataElement](struct.html#InterfaceSVGMetadataElement)
        7.  [[5.13.7.]{.secno} Interface
            SVGTitleElement](struct.html#InterfaceSVGTitleElement)
        8.  [[5.13.8.]{.secno} Interface
            SVGSymbolElement](struct.html#InterfaceSVGSymbolElement)
        9.  [[5.13.9.]{.secno} Interface
            SVGUseElement](struct.html#InterfaceSVGUseElement)
        10. [[5.13.10.]{.secno} Interface
            SVGUseElementShadowRoot](struct.html#InterfaceSVGUseElementShadowRoot)
        11. [[5.13.11.]{.secno} Mixin
            SVGElementInstance](struct.html#InterfaceSVGElementInstance)
        12. [[5.13.12.]{.secno} Interface
            ShadowAnimation](struct.html#InterfaceShadowAnimation)
        13. [[5.13.13.]{.secno} Interface
            SVGSwitchElement](struct.html#InterfaceSVGSwitchElement)
        14. [[5.13.14.]{.secno} Mixin
            GetSVGDocument](struct.html#InterfaceGetSVGDocument)
6.  [6.]{.secno} [Styling](styling.html)
    1.  [[6.1.]{.secno} Styling SVG content using
        CSS](styling.html#StylingUsingCSS)
    2.  [[6.2.]{.secno} Inline style sheets: the
        ['style']{.element-name} element](styling.html#StyleElement)
    3.  [[6.3.]{.secno} External style sheets: the effect of the HTML
        ['link']{.element-name} element](styling.html#LinkElement)
    4.  [[6.4.]{.secno} Style sheets in HTML
        documents](styling.html#StyleSheetsInHTMLDocuments)
    5.  [[6.5.]{.secno} Element-specific styling: the
        ['class']{.attr-name} and ['style']{.attr-name}
        attributes](styling.html#ElementSpecificStyling)
    6.  [[6.6.]{.secno} Presentation
        attributes](styling.html#PresentationAttributes)
    7.  [[6.7.]{.secno} Required
        properties](styling.html#RequiredProperties)
    8.  [[6.8.]{.secno} User agent style
        sheet](styling.html#UAStyleSheet)
    9.  [[6.9.]{.secno} Required CSS
        features](styling.html#RequiredCSSFeatures)
    10. [[6.10.]{.secno} DOM interfaces](styling.html#DOMInterfaces)
        1.  [[6.10.1.]{.secno} Interface
            SVGStyleElement](styling.html#InterfaceSVGStyleElement)
7.  [7.]{.secno} [Geometry Properties](geometry.html)
    1.  [[7.1.]{.secno} Horizontal center coordinate: The
        '[cx]{.property}' property](geometry.html#CX)
    2.  [[7.2.]{.secno} Vertical center coordinate: The
        '[cy]{.property}' property](geometry.html#CY)
    3.  [[7.3.]{.secno} Radius: The '[r]{.property}'
        property](geometry.html#R)
    4.  [[7.4.]{.secno} Horizontal radius: The '[rx]{.property}'
        property](geometry.html#RX)
    5.  [[7.5.]{.secno} Vertical radius: The '[ry]{.property}'
        property](geometry.html#RY)
    6.  [[7.6.]{.secno} Horizontal coordinate: The '[x]{.property}'
        property](geometry.html#X)
    7.  [[7.7.]{.secno} Vertical coordinate: The '[y]{.property}'
        property](geometry.html#Y)
    8.  [[7.8.]{.secno} Sizing properties: the effect of the
        '[width]{.property}' and '[height]{.property}'
        properties](geometry.html#Sizing)
8.  [8.]{.secno} [Coordinate Systems, Transformations and
    Units](coords.html)
    1.  [[8.1.]{.secno} Introduction](coords.html#Introduction)
    2.  [[8.2.]{.secno} Computing the equivalent transform of an SVG
        viewport](coords.html#ComputingAViewportsTransform)
    3.  [[8.3.]{.secno} The initial viewport](coords.html#ViewportSpace)
    4.  [[8.4.]{.secno} The initial coordinate
        system](coords.html#InitialCoordinateSystem)
    5.  [[8.5.]{.secno} The '[transform]{.property}'
        property](coords.html#TransformProperty)
    6.  [[8.6.]{.secno} The ['viewBox']{.attr-name}
        attribute](coords.html#ViewBoxAttribute)
    7.  [[8.7.]{.secno} The ['preserveAspectRatio']{.attr-name}
        attribute](coords.html#PreserveAspectRatioAttribute)
    8.  [[8.8.]{.secno} Establishing a new SVG
        viewport](coords.html#EstablishingANewSVGViewport)
    9.  [[8.9.]{.secno} Units](coords.html#Units)
    10. [[8.10.]{.secno} Bounding boxes](coords.html#BoundingBoxes)
    11. [[8.11.]{.secno} Object bounding box
        units](coords.html#ObjectBoundingBoxUnits)
    12. [[8.12.]{.secno} Intrinsic sizing properties of SVG
        content](coords.html#SizingSVGInCSS)
    13. [[8.13.]{.secno} Vector effects](coords.html#VectorEffects)
        1.  [[8.13.1.]{.secno} Computing the vector
            effects](coords.html#VectorEffectsCalculation)
        2.  [[8.13.2.]{.secno} Computing the vector effects for nested
            viewport coordinate
            systems](coords.html#NestedVectorEffectsCalculation)
        3.  [[8.13.3.]{.secno} Examples of vector
            effects](coords.html#VectorEffectsExamples)
    14. [[8.14.]{.secno} DOM interfaces](coords.html#DOMInterfaces)
        1.  [[8.14.1.]{.secno} Interface
            SVGTransform](coords.html#InterfaceSVGTransform)
        2.  [[8.14.2.]{.secno} Interface
            SVGTransformList](coords.html#InterfaceSVGTransformList)
        3.  [[8.14.3.]{.secno} Interface
            SVGAnimatedTransformList](coords.html#InterfaceSVGAnimatedTransformList)
        4.  [[8.14.4.]{.secno} Interface
            SVGPreserveAspectRatio](coords.html#InterfaceSVGPreserveAspectRatio)
        5.  [[8.14.5.]{.secno} Interface
            SVGAnimatedPreserveAspectRatio](coords.html#InterfaceSVGAnimatedPreserveAspectRatio)
9.  [9.]{.secno} [Paths](paths.html)
    1.  [[9.1.]{.secno} Introduction](paths.html#Introduction)
    2.  [[9.2.]{.secno} The ['path']{.element-name}
        element](paths.html#PathElement)
    3.  [[9.3.]{.secno} Path data](paths.html#PathData)
        1.  [[9.3.1.]{.secno} General information about path
            data](paths.html#PathDataGeneralInformation)
        2.  [[9.3.2.]{.secno} Specifying path data: the '[d]{.property}'
            property](paths.html#TheDProperty)
        3.  [[9.3.3.]{.secno} The **\"moveto\"**
            commands](paths.html#PathDataMovetoCommands)
        4.  [[9.3.4.]{.secno} The **\"closepath\"**
            command](paths.html#PathDataClosePathCommand)
            1.  [[9.3.4.1.]{.secno} Segment-completing close path
                operation](paths.html#Segment-CompletingClosePath)
        5.  [[9.3.5.]{.secno} The **\"lineto\"**
            commands](paths.html#PathDataLinetoCommands)
        6.  [[9.3.6.]{.secno} The cubic Bézier curve
            commands](paths.html#PathDataCubicBezierCommands)
        7.  [[9.3.7.]{.secno} The quadratic Bézier curve
            commands](paths.html#PathDataQuadraticBezierCommands)
        8.  [[9.3.8.]{.secno} The elliptical arc curve
            commands](paths.html#PathDataEllipticalArcCommands)
        9.  [[9.3.9.]{.secno} The grammar for path
            data](paths.html#PathDataBNF)
    4.  [[9.4.]{.secno} Path
        directionality](paths.html#PathDirectionality)
    5.  [[9.5.]{.secno} Implementation
        notes](paths.html#PathElementImplementationNotes)
        1.  [[9.5.1.]{.secno} Out-of-range elliptical arc
            parameters](paths.html#ArcOutOfRangeParameters)
        2.  [[9.5.2.]{.secno} Reflected control
            points](paths.html#ReflectedControlPoints)
        3.  [[9.5.3.]{.secno} Zero-length path
            segments](paths.html#ZeroLengthSegments)
        4.  [[9.5.4.]{.secno} Error handling in path
            data](paths.html#PathDataErrorHandling)
    6.  [[9.6.]{.secno} Distance along a
        path](paths.html#DistanceAlongAPath)
        1.  [[9.6.1.]{.secno} The ['pathLength']{.attr-name}
            attribute](paths.html#PathLengthAttribute)
    7.  [[9.7.]{.secno} DOM interfaces](paths.html#DOMInterfaces)
        1.  [[9.7.1.]{.secno} Interface
            SVGPathElement](paths.html#InterfaceSVGPathElement)
10. [10.]{.secno} [Basic Shapes](shapes.html)
    1.  [[10.1.]{.secno} Introduction and
        definitions](shapes.html#Introduction)
    2.  [[10.2.]{.secno} The ['rect']{.element-name}
        element](shapes.html#RectElement)
    3.  [[10.3.]{.secno} The ['circle']{.element-name}
        element](shapes.html#CircleElement)
    4.  [[10.4.]{.secno} The ['ellipse']{.element-name}
        element](shapes.html#EllipseElement)
    5.  [[10.5.]{.secno} The ['line']{.element-name}
        element](shapes.html#LineElement)
    6.  [[10.6.]{.secno} The ['polyline']{.element-name}
        element](shapes.html#PolylineElement)
    7.  [[10.7.]{.secno} The ['polygon']{.element-name}
        element](shapes.html#PolygonElement)
    8.  [[10.8.]{.secno} DOM interfaces](shapes.html#DOMInterfaces)
        1.  [[10.8.1.]{.secno} Interface
            SVGRectElement](shapes.html#InterfaceSVGRectElement)
        2.  [[10.8.2.]{.secno} Interface
            SVGCircleElement](shapes.html#InterfaceSVGCircleElement)
        3.  [[10.8.3.]{.secno} Interface
            SVGEllipseElement](shapes.html#InterfaceSVGEllipseElement)
        4.  [[10.8.4.]{.secno} Interface
            SVGLineElement](shapes.html#InterfaceSVGLineElement)
        5.  [[10.8.5.]{.secno} Mixin
            SVGAnimatedPoints](shapes.html#InterfaceSVGAnimatedPoints)
        6.  [[10.8.6.]{.secno} Interface
            SVGPointList](shapes.html#InterfaceSVGPointList)
        7.  [[10.8.7.]{.secno} Interface
            SVGPolylineElement](shapes.html#InterfaceSVGPolylineElement)
        8.  [[10.8.8.]{.secno} Interface
            SVGPolygonElement](shapes.html#InterfaceSVGPolygonElement)
11. [11.]{.secno} [Text](text.html)
    1.  [[11.1.]{.secno} Introduction](text.html#Introduction)
        1.  [[11.1.1.]{.secno} Definitions](text.html#Definitions)
        2.  [[11.1.2.]{.secno} Fonts and glyphs](text.html#FontsGlyphs)
        3.  [[11.1.3.]{.secno} Glyph metrics and
            layout](text.html#GlyphsMetrics)
    2.  [[11.2.]{.secno} The ['text']{.element-name} and
        ['tspan']{.element-name} elements](text.html#TextElement)
        1.  [[11.2.1.]{.secno} Attributes](text.html#TSpanAttributes)
        2.  [[11.2.2.]{.secno} Notes on \'x\', \'y\', \'dx\', \'dy\' and
            \'rotate\'](text.html#TSpanNotes)
    3.  [[11.3.]{.secno} Text layout --
        Introduction](text.html#TextLayout)
    4.  [[11.4.]{.secno} Text layout -- Content
        Area](text.html#TextLayoutContentArea)
        1.  [[11.4.1.]{.secno} The '[inline-size]{.property}'
            property](text.html#InlineSize)
        2.  [[11.4.2.]{.secno} The '[shape-inside]{.property}'
            property](text.html#TextShapeInside)
        3.  [[11.4.3.]{.secno} The '[shape-subtract]{.property}'
            property](text.html#TextShapeSubtract)
        4.  [[11.4.4.]{.secno} The '[shape-image-threshold]{.property}'
            property](text.html#TextShapeImageThreshold)
        5.  [[11.4.5.]{.secno} The '[shape-margin]{.property}'
            property](text.html#TextShapeMargin)
        6.  [[11.4.6.]{.secno} The '[shape-padding]{.property}'
            property](text.html#TextShapePadding)
    5.  [[11.5.]{.secno} Text layout --
        Algorithm](text.html#TextLayoutAlgorithm)
    6.  [[11.6.]{.secno} Pre-formatted text](text.html#TextLayoutPre)
        1.  [[11.6.1.]{.secno} Multi-line text via
            \'white-space\'](text.html#TextLayoutPreMultiline)
        2.  [[11.6.2.]{.secno} Repositioning
            Glyphs](text.html#TextLayoutPreAdjustments)
    7.  [[11.7.]{.secno} Auto-wrapped text](text.html#TextLayoutAuto)
        1.  [[11.7.1.]{.secno} Notes on Text
            Wrapping](text.html#TextLayoutAutoNotes)
            1.  [[11.7.1.1.]{.secno} First Line
                Positioning](text.html#TextLayoutAutoNotesStart)
            2.  [[11.7.1.2.]{.secno} Broken
                Lines](text.html#TextLayoutAutoNotesBrokenLines)
    8.  [[11.8.]{.secno} Text on a path](text.html#TextLayoutPath)
        1.  [[11.8.1.]{.secno} The ['textPath']{.element-name}
            element](text.html#TextPathElement)
        2.  [[11.8.2.]{.secno} Attributes](text.html#TextPathAttributes)
        3.  [[11.8.3.]{.secno} Text on a path layout
            rules](text.html#TextpathLayoutRules)
    9.  [[11.9.]{.secno} Text rendering
        order](text.html#TextRenderingOrder)
    10. [[11.10.]{.secno} Properties and
        pseudo-elements](text.html#TextProperties)
        1.  [[11.10.1.]{.secno} SVG
            properties](text.html#TextPropertiesSVG)
            1.  [[11.10.1.1.]{.secno} Text alignment, the
                '[text-anchor]{.property}'
                property](text.html#TextAnchoringProperties)
            2.  [[11.10.1.2.]{.secno} The
                '[glyph-orientation-horizontal]{.property}'
                property](text.html#GlyphOrientationHorizontalProperty)
            3.  [[11.10.1.3.]{.secno} The
                '[glyph-orientation-vertical]{.property}'
                property](text.html#GlyphOrientationVerticalProperty)
            4.  [[11.10.1.4.]{.secno} The '[kerning]{.property}'
                property](text.html#KerningProperty)
        2.  [[11.10.2.]{.secno} SVG
            adaptions](text.html#TextPropertiesAdaptions)
            1.  [[11.10.2.1.]{.secno} The '[font-variant]{.property}'
                property](text.html#FontVariantProperty)
            2.  [[11.10.2.2.]{.secno} The '[line-height]{.property}'
                property](text.html#LineHeightProperty)
            3.  [[11.10.2.3.]{.secno} The '[writing-mode]{.property}'
                property](text.html#WritingModeProperty)
            4.  [[11.10.2.4.]{.secno} The '[direction]{.property}'
                property](text.html#DirectionProperty)
            5.  [[11.10.2.5.]{.secno} The
                '[dominant-baseline]{.property}'
                property](text.html#DominantBaselineProperty)
            6.  [[11.10.2.6.]{.secno} The
                '[alignment-baseline]{.property}'
                property](text.html#AlignmentBaselineProperty)
            7.  [[11.10.2.7.]{.secno} The '[baseline-shift]{.property}'
                property](text.html#BaselineShiftProperty)
            8.  [[11.10.2.8.]{.secno} The '[letter-spacing]{.property}'
                property](text.html#LetterSpacingProperty)
            9.  [[11.10.2.9.]{.secno} The '[word-spacing]{.property}'
                property](text.html#WordSpacingProperty)
            10. [[11.10.2.10.]{.secno} The '[text-overflow]{.property}'
                property](text.html#TextOverflowProperty)
        3.  [[11.10.3.]{.secno} White space](text.html#WhiteSpace)
            1.  [[11.10.3.1.]{.secno} SVG 2 Preferred white space
                handling, the '[white-space]{.property}'
                property](text.html#TextWhiteSpace)
            2.  [[11.10.3.2.]{.secno} Legacy white-space handling, the
                '[xml:space]{.property}'
                property](text.html#LegacyXMLSpace)
            3.  [[11.10.3.3.]{.secno} Duplicate white-space
                directives](text.html#DuplicateWhiteSpace)
    11. [[11.11.]{.secno} Text
        decoration](text.html#TextDecorationProperties)
    12. [[11.12.]{.secno} Text selection and clipboard
        operations](text.html#TextSelection)
        1.  [[11.12.1.]{.secno} Text selection implementation
            notes](text.html#TextSelectionImplementationNotes)
    13. [[11.13.]{.secno} DOM interfaces](text.html#DOMInterfaces)
        1.  [[11.13.1.]{.secno} Interface
            SVGTextContentElement](text.html#InterfaceSVGTextContentElement)
        2.  [[11.13.2.]{.secno} Interface
            SVGTextPositioningElement](text.html#InterfaceSVGTextPositioningElement)
        3.  [[11.13.3.]{.secno} Interface
            SVGTextElement](text.html#InterfaceSVGTextElement)
        4.  [[11.13.4.]{.secno} Interface
            SVGTSpanElement](text.html#InterfaceSVGTSpanElement)
        5.  [[11.13.5.]{.secno} Interface
            SVGTextPathElement](text.html#InterfaceSVGTextPathElement)
12. [12.]{.secno} [Embedded Content](embedded.html)
    1.  [[12.1.]{.secno} Overview](embedded.html#Overview)
    2.  [[12.2.]{.secno} Placement of the embedded
        content](embedded.html#Placement)
    3.  [[12.3.]{.secno} The ['image']{.element-name}
        element](embedded.html#ImageElement)
    4.  [[12.4.]{.secno} The ['foreignObject']{.element-name}
        element](embedded.html#ForeignObjectElement)
    5.  [[12.5.]{.secno} DOM interfaces](embedded.html#DOMInterfaces)
        1.  [[12.5.1.]{.secno} Interface
            SVGImageElement](embedded.html#InterfaceSVGImageElement)
        2.  [[12.5.2.]{.secno} Interface
            SVGForeignObjectElement](embedded.html#InterfaceSVGForeignObjectElement)
13. [13.]{.secno} [Painting: Filling, Stroking and Marker
    Symbols](painting.html)
    1.  [[13.1.]{.secno} Introduction](painting.html#Introduction)
        1.  [[13.1.1.]{.secno} Definitions](painting.html#Definitions)
    2.  [[13.2.]{.secno} Specifying
        paint](painting.html#SpecifyingPaint)
    3.  [[13.3.]{.secno} The effect of the '[color]{.property}'
        property](painting.html#ColorProperty)
    4.  [[13.4.]{.secno} Fill properties](painting.html#FillProperties)
        1.  [[13.4.1.]{.secno} Specifying fill paint: the
            '[fill]{.property}'
            property](painting.html#SpecifyingFillPaint)
        2.  [[13.4.2.]{.secno} Winding rule: the
            '[fill-rule]{.property}'
            property](painting.html#WindingRule)
        3.  [[13.4.3.]{.secno} Fill paint opacity: the
            '[fill-opacity]{.property}'
            property](painting.html#FillOpacity)
    5.  [[13.5.]{.secno} Stroke
        properties](painting.html#StrokeProperties)
        1.  [[13.5.1.]{.secno} Specifying stroke paint: the
            '[stroke]{.property}'
            property](painting.html#SpecifyingStrokePaint)
        2.  [[13.5.2.]{.secno} Stroke paint opacity: the
            '[stroke-opacity]{.property}'
            property](painting.html#StrokeOpacity)
        3.  [[13.5.3.]{.secno} Stroke width: the
            '[stroke-width]{.property}'
            property](painting.html#StrokeWidth)
        4.  [[13.5.4.]{.secno} Drawing caps at the ends of strokes: the
            '[stroke-linecap]{.property}'
            property](painting.html#LineCaps)
        5.  [[13.5.5.]{.secno} Controlling line joins: the
            '[stroke-linejoin]{.property}' and
            '[stroke-miterlimit]{.property}'
            properties](painting.html#LineJoin)
        6.  [[13.5.6.]{.secno} Dashing strokes: the
            '[stroke-dasharray]{.property}' and
            '[stroke-dashoffset]{.property}'
            properties](painting.html#StrokeDashing)
        7.  [[13.5.7.]{.secno} Computing the shape of the
            stroke](painting.html#StrokeShape)
        8.  [[13.5.8.]{.secno} Computing the circles for the
            [arcs]{.prop-value}
            \'stroke-linejoin\'](painting.html#CurvatureCalculation)
        9.  [[13.5.9.]{.secno} Adjusting the circles for the
            [arcs]{.prop-value} \'stroke-linejoin\' when the initial
            circles do not
            intersect](painting.html#ArcsLinejoinFallback)
    6.  [[13.6.]{.secno} Vector
        effects](painting.html#PaintingVectorEffects)
    7.  [[13.7.]{.secno} Markers](painting.html#Markers)
        1.  [[13.7.1.]{.secno} The ['marker']{.element-name}
            element](painting.html#MarkerElement)
        2.  [[13.7.2.]{.secno} Vertex markers: the
            '[marker-start]{.property}', '[marker-mid]{.property}' and
            '[marker-end]{.property}'
            properties](painting.html#VertexMarkerProperties)
        3.  [[13.7.3.]{.secno} Marker shorthand: the
            '[marker]{.property}'
            property](painting.html#MarkerShorthand)
        4.  [[13.7.4.]{.secno} Rendering
            markers](painting.html#RenderingMarkers)
    8.  [[13.8.]{.secno} Controlling paint operation order: the
        '[paint-order]{.property}' property](painting.html#PaintOrder)
    9.  [[13.9.]{.secno} Color space for interpolation: the
        '[color-interpolation]{.property}'
        property](painting.html#ColorInterpolation)
    10. [[13.10.]{.secno} Rendering hints](painting.html#RenderingHints)
        1.  [[13.10.1.]{.secno} The '[shape-rendering]{.property}'
            property](painting.html#ShapeRendering)
        2.  [[13.10.2.]{.secno} The '[text-rendering]{.property}'
            property](painting.html#TextRendering)
        3.  [[13.10.3.]{.secno} The '[image-rendering]{.property}'
            property](painting.html#ImageRendering)
    11. [[13.11.]{.secno} The effect of the '[will-change]{.property}'
        property](painting.html#WillChange)
    12. [[13.12.]{.secno} DOM interfaces](painting.html#DOMInterfaces)
        1.  [[13.12.1.]{.secno} Interface
            SVGMarkerElement](painting.html#InterfaceSVGMarkerElement)
14. [14.]{.secno} [Paint Servers: Gradients and Patterns](pservers.html)
    1.  [[14.1.]{.secno} Introduction](pservers.html#Introduction)
        1.  [[14.1.1.]{.secno} Using paint servers as
            templates](pservers.html#PaintServerTemplates)
    2.  [[14.2.]{.secno} Gradients](pservers.html#Gradients)
        1.  [[14.2.1.]{.secno} Definitions](pservers.html#Definitions)
        2.  [[14.2.2.]{.secno} Linear
            gradients](pservers.html#LinearGradients)
            1.  [[14.2.2.1.]{.secno}
                Attributes](pservers.html#LinearGradientAttributes)
            2.  [[14.2.2.2.]{.secno} Notes on linear
                gradients](pservers.html#LinearGradientNotes)
        3.  [[14.2.3.]{.secno} Radial
            gradients](pservers.html#RadialGradients)
            1.  [[14.2.3.1.]{.secno}
                Attributes](pservers.html#RadialGradientAttributes)
            2.  [[14.2.3.2.]{.secno} Notes on radial
                gradients](pservers.html#RadialGradientNotes)
        4.  [[14.2.4.]{.secno} Gradient
            stops](pservers.html#GradientStops)
            1.  [[14.2.4.1.]{.secno}
                Attributes](pservers.html#GradientStopAttributes)
            2.  [[14.2.4.2.]{.secno}
                Properties](pservers.html#StopColorProperties)
            3.  [[14.2.4.3.]{.secno} Notes on gradient
                stops](pservers.html#StopNotes)
    3.  [[14.3.]{.secno} Patterns](pservers.html#Patterns)
        1.  [[14.3.1.]{.secno}
            Attributes](pservers.html#PatternElementAttributes)
        2.  [[14.3.2.]{.secno} Notes on
            patterns](pservers.html#PatternNotes)
    4.  [[14.4.]{.secno} DOM interfaces](pservers.html#DOMInterfaces)
        1.  [[14.4.1.]{.secno} Interface
            SVGGradientElement](pservers.html#InterfaceSVGGradientElement)
        2.  [[14.4.2.]{.secno} Interface
            SVGLinearGradientElement](pservers.html#InterfaceSVGLinearGradientElement)
        3.  [[14.4.3.]{.secno} Interface
            SVGRadialGradientElement](pservers.html#InterfaceSVGRadialGradientElement)
        4.  [[14.4.4.]{.secno} Interface
            SVGStopElement](pservers.html#InterfaceSVGStopElement)
        5.  [[14.4.5.]{.secno} Interface
            SVGPatternElement](pservers.html#InterfaceSVGPatternElement)
15. [15.]{.secno} [Scripting and Interactivity](interact.html)
    1.  [[15.1.]{.secno} Introduction](interact.html#Introduction)
    2.  [[15.2.]{.secno} Supported events](interact.html#SVGEvents)
        1.  [[15.2.1.]{.secno} Relationship with UI
            Events](interact.html#RelationshipWithUIEVENTS)
    3.  [[15.3.]{.secno} User interface events](interact.html#UIEvents)
    4.  [[15.4.]{.secno} Pointer events](interact.html#PointerEvents)
    5.  [[15.5.]{.secno} Hit-testing and processing order for user
        interface events](interact.html#pointer-processing)
        1.  [[15.5.1.]{.secno} Hit-testing](interact.html#hit-testing)
        2.  [[15.5.2.]{.secno} Event
            processing](interact.html#event-processing)
    6.  [[15.6.]{.secno} The '[pointer-events]{.property}'
        property](interact.html#PointerEventsProp)
    7.  [[15.7.]{.secno} Focus](interact.html#Focus)
    8.  [[15.8.]{.secno} Event
        attributes](interact.html#EventAttributes)
        1.  [[15.8.1.]{.secno} Animation event
            attributes](interact.html#AnimationEvents)
    9.  [[15.9.]{.secno} The ['script']{.element-name}
        element](interact.html#ScriptElement)
    10. [[15.10.]{.secno} DOM interfaces](interact.html#DOMInterfaces)
        1.  [[15.10.1.]{.secno} Interface
            SVGScriptElement](interact.html#InterfaceSVGScriptElement)
16. [16.]{.secno} [Linking](linking.html)
    1.  [[16.1.]{.secno} References](linking.html#URLReference)
        1.  [[16.1.1.]{.secno} Overview](linking.html#HeadOverview)
        2.  [[16.1.2.]{.secno} Definitions](linking.html#definitions)
        3.  [[16.1.3.]{.secno} URLs and URIs](linking.html#URLandURI)
        4.  [[16.1.4.]{.secno} Syntactic forms: URL and
            \<url\>](linking.html#URLforms)
        5.  [[16.1.5.]{.secno} URL reference
            attributes](linking.html#linkRefAttrs)
        6.  [[16.1.6.]{.secno} Deprecated XLink URL reference
            attributes](linking.html#XLinkRefAttrs)
        7.  [[16.1.7.]{.secno} Processing of URL
            references](linking.html#processingURL)
            1.  [[16.1.7.1.]{.secno} Generating the absolute
                URL](linking.html#processingURL-absolute)
            2.  [[16.1.7.2.]{.secno} Fetching the
                document](linking.html#processingURL-fetch)
            3.  [[16.1.7.3.]{.secno} Processing the subresource
                document](linking.html#processingURL-parsing)
            4.  [[16.1.7.4.]{.secno} Identifying the target
                element](linking.html#processingURL-target)
            5.  [[16.1.7.5.]{.secno} Valid URL
                targets](linking.html#processingURL-validity)
    2.  [[16.2.]{.secno} Links out of SVG content: the
        ['a']{.element-name} element](linking.html#Links)
    3.  [[16.3.]{.secno} Linking into SVG content: URL fragments and SVG
        views](linking.html#LinksIntoSVG)
        1.  [[16.3.1.]{.secno} SVG fragment
            identifiers](linking.html#SVGFragmentIdentifiers)
        2.  [[16.3.2.]{.secno} SVG fragment identifiers
            definitions](linking.html#SVGFragmentIdentifiersDefinitions)
        3.  [[16.3.3.]{.secno} Predefined views: the
            ['view']{.element-name} element](linking.html#ViewElement)
    4.  [[16.4.]{.secno} DOM interfaces](linking.html#DOMInterfaces)
        1.  [[16.4.1.]{.secno} Interface
            SVGAElement](linking.html#InterfaceSVGAElement)
        2.  [[16.4.2.]{.secno} Interface
            SVGViewElement](linking.html#InterfaceSVGViewElement)
17. [Appendix A: IDL Definitions](idl.html)
18. [Appendix B: Implementation Notes](implnote.html)
    1.  [[B.1.]{.secno} Introduction](implnote.html#Introduction)
    2.  [[B.2.]{.secno} Elliptical arc parameter
        conversion](implnote.html#ArcImplementationNotes)
        1.  [[B.2.1.]{.secno} Elliptical arc endpoint
            syntax](implnote.html#ArcSyntax)
        2.  [[B.2.2.]{.secno} Parameterization
            alternatives](implnote.html#ArcParameterizationAlternatives)
        3.  [[B.2.3.]{.secno} Conversion from center to endpoint
            parameterization](implnote.html#ArcConversionCenterToEndpoint)
        4.  [[B.2.4.]{.secno} Conversion from endpoint to center
            parameterization](implnote.html#ArcConversionEndpointToCenter)
        5.  [[B.2.5.]{.secno} Correction of out-of-range
            radii](implnote.html#ArcCorrectionOutOfRangeRadii)
    3.  [[B.3.]{.secno} Notes on generating high-precision
        geometry](implnote.html#NumericPrecisionImplementationNotes)
19. [Appendix C: Accessibility Support](access.html)
    1.  [[C.1.]{.secno} SVG Accessibility
        Features](access.html#AccessibilityAndSVG)
    2.  [[C.2.]{.secno} Supporting SVG Accessibility Specifications and
        Guidelines](access.html#SVGRelatedAccessibilityDocuments)
20. [Appendix D: Animating SVG Documents](animate.html)
21. [Appendix E: References](refs.html)
    1.  [[E.1.]{.secno} Normative
        references](refs.html#NormativeReferences)
    2.  [[E.2.]{.secno} Informative
        references](refs.html#InformativeReferences)
22. [Appendix F: Element Index](eltindex.html)
23. [Appendix G: Attribute Index](attindex.html)
    1.  [[G.1.]{.secno} Regular
        attributes](attindex.html#RegularAttributes)
    2.  [[G.2.]{.secno} Presentation
        attributes](attindex.html#PresentationAttributes)
24. [Appendix H: Property Index](propidx.html)
25. [Appendix I: IDL Index](idlindex.html)
26. [Appendix J: Media Type Registration for
    image/svg+xml](mimereg.html)
    1.  [[J.1.]{.secno} Introduction](mimereg.html#mime-intro)
    2.  [[J.2.]{.secno} Registration of media type
        image/svg+xml](mimereg.html#mime-registration)
27. [Appendix K: Changes from SVG 1.1](changes.html)
    1.  [[K.1.]{.secno} Editorial changes](changes.html#editorial)
    2.  [[K.2.]{.secno} Substantial changes](changes.html#substantial)
        1.  [[K.2.1.]{.secno} Across the whole
            document](changes.html#whole)
        2.  [[K.2.2.]{.secno} Concepts chapter (SVG 1.1
            only)](changes.html#concepts)
        3.  [[K.2.3.]{.secno} Conformance Criteria chapter (Appendix in
            SVG 1.1)](changes.html#conform)
        4.  [[K.2.4.]{.secno} Rendering Model
            chapter](changes.html#rendering)
        5.  [[K.2.5.]{.secno} Basic Data Types and Interfaces
            chapter](changes.html#types)
        6.  [[K.2.6.]{.secno} Document Structure
            chapter](changes.html#structure)
        7.  [[K.2.7.]{.secno} Styling chapter](changes.html#styling)
        8.  [[K.2.8.]{.secno} Geometry Properties chapter (SVG 2
            only)](changes.html#geometry)
        9.  [[K.2.9.]{.secno} Coordinate Systems, Transformations and
            Units chapter](changes.html#coords)
        10. [[K.2.10.]{.secno} Paths chapter](changes.html#paths)
        11. [[K.2.11.]{.secno} Basic Shapes
            chapter](changes.html#shapes)
        12. [[K.2.12.]{.secno} Text chapter](changes.html#text)
        13. [[K.2.13.]{.secno} Embedded Content chapter (SVG 2
            only)](changes.html#embedded)
        14. [[K.2.14.]{.secno} Painting chapter](changes.html#painting)
        15. [[K.2.15.]{.secno} Color chapter (SVG 1.1
            only)](changes.html#color)
        16. [[K.2.16.]{.secno} Paint Servers chapter (called Gradients
            and Patterns in SVG 1.1)](changes.html#pservers)
        17. [[K.2.17.]{.secno} Clipping, Masking and Compositing chapter
            (SVG 1.1 only)](changes.html#masking)
        18. [[K.2.18.]{.secno} Filter Effects chapter (SVG 1.1
            only)](changes.html#filters)
        19. [[K.2.19.]{.secno} Scripting and Interactivity chapter
            (separate chapters in SVG 1.1)](changes.html#interact)
        20. [[K.2.20.]{.secno} Linking chapter](changes.html#linking)
        21. [[K.2.21.]{.secno} Scripting chapter (in SVG
            1.1)](changes.html#script)
        22. [[K.2.22.]{.secno} Animation chapter (SVG 1.1
            only)](changes.html#animate)
        23. [[K.2.23.]{.secno} Fonts chapter (SVG 1.1
            only)](changes.html#fonts)
        24. [[K.2.24.]{.secno} Metadata chapter (SVG 1.1
            only)](changes.html#metadata)
        25. [[K.2.25.]{.secno} Backwards Compatibility chapter (SVG 1.1
            only)](changes.html#backward)
        26. [[K.2.26.]{.secno} Extensibility chapter (SVG 1.1
            only)](changes.html#extend)
        27. [[K.2.27.]{.secno} Document Type Definition appendix (SVG
            1.1 only)](changes.html#svgdtd)
        28. [[K.2.28.]{.secno} SVG Document Object Model (DOM)(SVG 1.1
            Only)](changes.html#svgdom)
        29. [[K.2.29.]{.secno} IDL Definitions
            appendix](changes.html#idl)
        30. [[K.2.30.]{.secno} Java Language Binding appendix (SVG 1.1
            only)](changes.html#java)
        31. [[K.2.31.]{.secno} ECMAScript Language Binding appendix (SVG
            1.1 only)](changes.html#escript)
        32. [[K.2.32.]{.secno} Implementation Notes appendix (was
            Implementation Requirements in SVG
            1.1)](changes.html#impreqs)
        33. [[K.2.33.]{.secno} Accessibility Support
            appendix](changes.html#access)
        34. [[K.2.34.]{.secno} Internationalization Support appendix
            (SVG 1.1 only)](changes.html#i18n)
        35. [[K.2.35.]{.secno} Minimizing SVG File Sizes appendix (SVG
            1.1 only)](changes.html#minimize)
        36. [[K.2.36.]{.secno} Animating SVG Documents appendix (SVG 2
            only)](changes.html#animate-appendix)
        37. [[K.2.37.]{.secno} References appendix](changes.html#refs)
        38. [[K.2.38.]{.secno} Element, Attribute, and Property index
            appendices](changes.html#other-appendix)
        39. [[K.2.39.]{.secno} IDL Index appendix (SVG 2
            only)](changes.html#idlindex)
        40. [[K.2.40.]{.secno} Feature Strings (SVG 1.1
            only)](changes.html#feature)

## Acknowledgments {#Acknowledgments}

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
  Edition)]{.authornote}
- Jon Ferraiolo, ex Adobe Systems [(Versions 1.0 and 1.1 First Edition;
  until 10 May 2006)]{.authornote}
- Anthony Grasso, ex Canon Inc. [(Version 1.1 Second
  Edition)]{.authornote}
- Dean Jackson, ex W3C [(Version 1.1 First Edition; until February
  2007)]{.authornote}
- 藤沢 淳 (FUJISAWA Jun), Canon Inc. [(Version 1.1 First
  Edition)]{.authornote}

Finally, the SVG Working Group would like to acknowledge the great many
people outside of the SVG Working Group who help with the process of
developing the SVG specifications. These people are too numerous to list
individually. They include but are not limited to the early implementers
of the SVG 1.0 and 1.1 languages (including viewers, authoring tools,
and server-side transcoders), developers of SVG content, people who have
contributed on the [www-svg@w3.org]{.url} and
[svg-developers@yahoogroups.com]{.url} email lists, other Working Groups
at the W3C, and the W3C Team. SVG 1.1 is truly a cooperative effort
between the SVG Working Group, the rest of the W3C, and the public and
benefits greatly from the pioneering work of early implementers and
content developers, feedback from the public, and help from the W3C
team.
