/* XML is parsed by Expat; geometry and rasterization by pinned NanoSVG.
 * The private NanoSVG parser entry points are used to feed decoded XML names,
 * attributes and text, avoiding its permissive, non-namespace XML tokenizer. */
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <limits.h>
#include <expat.h>
#define NANOSVG_ALL_COLOR_KEYWORDS
#define NANOSVG_IMPLEMENTATION
#include <nanosvg.h>
#define NANOSVGRAST_IMPLEMENTATION
#include <nanosvgrast.h>
#include "image_codecs.h"

struct crane_svg {
    NSVGparser *svg;
    XML_Parser xml;
    int depth, skip, root, failure;
    char *text;
    size_t text_length;
};

static const char *svg_name(const char *name) {
    static const char prefix[] = "http://www.w3.org/2000/svg\x1f";
    return strncmp(name, prefix, sizeof(prefix) - 1) == 0 ? name + sizeof(prefix) - 1 : NULL;
}

static int absolute_dimension(const char **attr, const char *name) {
    for (size_t i = 0; attr[i]; i += 2) {
        if (!strcmp(attr[i], name)) {
            const char *value = attr[i + 1];
            char *tail;
            double number = strtod(value, &tail);
            if (tail == value || number < 0 || !isfinite(number)) return 0;
            while (*tail == ' ' || *tail == '\t' || *tail == '\r' || *tail == '\n') ++tail;
            return !*tail || !strcmp(tail, "px") || !strcmp(tail, "pt") ||
                !strcmp(tail, "pc") || !strcmp(tail, "mm") || !strcmp(tail, "cm") ||
                !strcmp(tail, "in") || !strcmp(tail, "em") || !strcmp(tail, "ex");
        }
    }
    return 0;
}

static void root_size(NSVGparser *p, const char **attr) {
    /* SVG2 8.12 and CSS Images 3 4.3.1-2. The image protocol has no host
     * viewport, so use the default 300 x 150 CSS-pixel object size. */
    int has_width = absolute_dimension(attr, "width");
    int has_height = absolute_dimension(attr, "height");
    double ratio = p->viewWidth > 0 && p->viewHeight > 0 ? p->viewWidth / p->viewHeight : 0;
    if (!has_width && !has_height) {
        p->image->width = 300;
        p->image->height = 150;
        if (ratio > 0) {
            if (ratio > 2) p->image->height = (float)(300 / ratio);
            else p->image->width = (float)(150 * ratio);
        }
    } else if (!has_width) {
        p->image->width = ratio > 0 ? (float)(p->image->height * ratio) : 300;
    } else if (!has_height) {
        p->image->height = ratio > 0 ? (float)(p->image->width / ratio) : 150;
    }
    /* Percentages in child geometry use the viewport, never shape bounds. */
    if (p->viewWidth <= 0) p->viewWidth = p->image->width;
    if (p->viewHeight <= 0) p->viewHeight = p->image->height;
}

static void start(void *user, const char *qualified, const char **attr) {
    struct crane_svg *self = user;
    const char *name = svg_name(qualified);
    ++self->depth;
    if (self->skip) return;
    if (!self->root) {
        if (!name || strcmp(name, "svg")) {
            self->failure = CRANE_CORRUPT;
            XML_StopParser(self->xml, XML_FALSE);
            return;
        }
        self->root = 1;
    }
    if (!name) { self->skip = self->depth; return; }
    /* NanoSVG treats any svg element as the root. Preserve the outer image's
     * dimensions when it sees a nested viewport, whose common transforms and
     * inherited presentation attributes can still be applied as a group. */
    size_t count = 0;
    int modern_href = 0;
    while (attr[count]) {
        if (!strcmp(attr[count], "href")) modern_href = 1;
        count += 2;
    }
    const char **normalized = malloc((count + 1) * sizeof(*normalized));
    if (!normalized) {
        self->failure = CRANE_OOM;
        XML_StopParser(self->xml, XML_FALSE);
        return;
    }
    size_t used = 0;
    for (size_t i = 0; i < count; i += 2) {
        const char *key = attr[i];
        int xlink = !strcmp(key, "http://www.w3.org/1999/xlink\x1f" "href");
        if (xlink && modern_href) continue;
        normalized[used++] = xlink || !strcmp(key, "href") ? "xlink:href" : key;
        normalized[used++] = attr[i + 1];
    }
    normalized[used] = NULL;
    nsvg__startElement(self->svg, self->depth > 1 && !strcmp(name, "svg") ? "g" : name, normalized);
    if (self->depth == 1) root_size(self->svg, attr);
    free(normalized);
}

static void end(void *user, const char *qualified) {
    struct crane_svg *self = user;
    if (self->skip) {
        if (self->skip == self->depth) self->skip = 0;
    } else {
        const char *name = svg_name(qualified);
        if (name && !strcmp(name, "style") && self->text) {
            nsvg__content(self->svg, self->text);
            free(self->text);
            self->text = NULL;
            self->text_length = 0;
        }
        if (name) nsvg__endElement(self->svg, self->depth > 1 && !strcmp(name, "svg") ? "g" : name);
    }
    --self->depth;
}

static void characters(void *user, const char *data, int length) {
    struct crane_svg *self = user;
    if (self->skip || !self->svg->styleFlag || length <= 0) return;
    if ((size_t)length > SIZE_MAX - self->text_length - 1) goto oom;
    char *text = realloc(self->text, self->text_length + (size_t)length + 1);
    if (!text) goto oom;
    self->text = text;
    memcpy(text + self->text_length, data, (size_t)length);
    self->text_length += (size_t)length;
    text[self->text_length] = 0;
    return;
oom:
    self->failure = CRANE_OOM;
    XML_StopParser(self->xml, XML_FALSE);
}

void crane_svg_close(struct crane_svg *self) {
    if (!self) return;
    if (self->xml) XML_ParserFree(self->xml);
    nsvg__deleteParser(self->svg);
    free(self->text);
    free(self);
}

struct crane_svg *crane_svg_open(const unsigned char *data, size_t length,
                            double *width, double *height, int *result) {
    *result = CRANE_OOM;
    struct crane_svg *self = calloc(1, sizeof(*self));
    if (!self) return NULL;
    self->svg = nsvg__createParser();
    self->xml = XML_ParserCreateNS(NULL, '\x1f');
    if (!self->svg || !self->xml) goto failed;
    self->svg->dpi = 96;
    self->svg->attr[0].fontSize = 16;
    self->svg->alignX = NSVG_ALIGN_MID;
    self->svg->alignY = NSVG_ALIGN_MID;
    self->svg->alignType = NSVG_ALIGN_MEET;
    XML_SetUserData(self->xml, self);
    XML_SetElementHandler(self->xml, start, end);
    XML_SetCharacterDataHandler(self->xml, characters);
    /* There is deliberately no external-entity handler: decoding an image
     * neither starts network requests nor executes script. */
    do {
        int n = length > INT_MAX ? INT_MAX : (int)length;
        int final = length == (size_t)n;
        if (XML_Parse(self->xml, (const char *)data, n, final) == XML_STATUS_ERROR) {
            *result = self->failure ? self->failure :
                XML_GetErrorCode(self->xml) == XML_ERROR_NO_MEMORY ? CRANE_OOM : CRANE_CORRUPT;
            goto failed;
        }
        data += n;
        length -= (size_t)n;
    } while (length);
    if (!self->root) { *result = CRANE_CORRUPT; goto failed; }
    *width = self->svg->image->width;
    *height = self->svg->image->height;
    *result = CRANE_COMPLETE;
    return self;
failed:
    crane_svg_close(self);
    return NULL;
}

/* NanoSVG stores raster edges in signed 22.10 fixed point. Preflight the
 * vendor's flattened edges before it converts floats to int, with headroom
 * for scanline increments. A decode beyond that representation is partial,
 * not a process-terminating C conversion. */
static int raster_number(float value) {
    return isfinite(value) && fabsf(value) <= (float)(INT_MAX / NSVG__FIX / 8);
}

static int raster_paint(const NSVGpaint *paint) {
    if (paint->type != NSVG_PAINT_LINEAR_GRADIENT && paint->type != NSVG_PAINT_RADIAL_GRADIENT) return 1;
    const NSVGgradient *gradient = paint->gradient;
    for (int i = 0; i < 6; ++i) if (!raster_number(gradient->xform[i])) return 0;
    for (int i = 0; i < gradient->nstops; ++i) if (!isfinite(gradient->stops[i].offset)) return 0;
    return 1;
}

static int raster_geometry(NSVGrasterizer *raster, NSVGimage *image) {
    for (NSVGshape *shape = image->shapes; shape; shape = shape->next) {
        if (!(shape->flags & NSVG_FLAGS_VISIBLE)) continue;
        if (!raster_number(shape->strokeWidth) || !raster_number(shape->miterLimit) ||
            !raster_number(shape->strokeDashOffset) || !isfinite(shape->opacity) ||
            !raster_paint(&shape->fill) || !raster_paint(&shape->stroke)) return 0;
        for (int i = 0; i < shape->strokeDashCount; ++i)
            if (!raster_number(shape->strokeDashArray[i])) return 0;
        for (NSVGpath *path = shape->paths; path; path = path->next)
            for (int i = 0; i < path->npts; ++i)
                if (!raster_number(path->pts[2 * i]) || !raster_number(path->pts[2 * i + 1])) return 0;
        for (int stroke = 0; stroke < 2; ++stroke) {
            if (stroke ? shape->stroke.type == NSVG_PAINT_NONE || shape->strokeWidth <= 0.01f : shape->fill.type == NSVG_PAINT_NONE) continue;
            raster->nedges = 0;
            if (stroke) nsvg__flattenShapeStroke(raster, shape, 1);
            else nsvg__flattenShape(raster, shape, 1);
            for (int i = 0; i < raster->nedges; ++i) {
                const NSVGedge *edge = &raster->edges[i];
                if (!raster_number(edge->x0) || !raster_number(edge->x1) ||
                    !raster_number(edge->y0) || !raster_number(edge->y1)) return 0;
                float dy = (edge->y1 - edge->y0) * NSVG__SUBSAMPLES;
                if (dy > 0 && !raster_number((edge->x1 - edge->x0) / dy)) return 0;
            }
        }
    }
    return 1;
}

int crane_svg_render(struct crane_svg *self, unsigned char *pixels, int width, int height) {
    if (!width || !height) return CRANE_COMPLETE;
    nsvg__createGradients(self->svg);
    nsvg__scaleToViewbox(self->svg, "px");
    NSVGrasterizer *raster = nsvgCreateRasterizer();
    if (!raster) return CRANE_OOM;
    if (!raster_geometry(raster, self->svg->image)) {
        nsvgDeleteRasterizer(raster);
        return CRANE_CORRUPT;
    }
    nsvgRasterize(raster, self->svg->image, 0, 0, 1, pixels, width, height, width * 4);
    nsvgDeleteRasterizer(raster);
    return CRANE_COMPLETE;
}
