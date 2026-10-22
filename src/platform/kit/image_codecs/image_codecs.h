#ifndef CRANE_IMAGE_CODECS_H
#define CRANE_IMAGE_CODECS_H
#include <stddef.h>
#include <stdint.h>
enum { CRANE_COMPLETE = 0, CRANE_TRUNCATED = 1, CRANE_CORRUPT = 2, CRANE_OOM = 3 };
struct crane_jpeg;
struct crane_jpeg *crane_jpeg_open(const unsigned char *, size_t, uint32_t *, uint32_t *, int *);
int crane_jpeg_decode(struct crane_jpeg *, unsigned char *, int *);
unsigned char crane_jpeg_orientation(struct crane_jpeg *);
void crane_jpeg_close(struct crane_jpeg *);
struct crane_svg;
struct crane_svg *crane_svg_open(const unsigned char *, size_t, double *, double *, int *);
int crane_svg_render(struct crane_svg *, unsigned char *, int, int);
void crane_svg_close(struct crane_svg *);
#endif
