#include <SDL3/SDL.h>
#include <brl.mod/blitz.mod/blitz.h>

SDL_Renderer *bmx_SDL3_CreateRenderer(SDL_Window *window, BBString *driver) {
    unsigned char *utf8 = bbStringToUTF8String(driver);
    SDL_Renderer *renderer = SDL_CreateRenderer(window, utf8[0] ? (const char *)utf8 : NULL);
    bbMemFree(utf8);
    return renderer;
}
int bmx_SDL3_SetRenderDrawColor(SDL_Renderer *renderer, int red, int green, int blue, int alpha) {
    return SDL_SetRenderDrawColor(renderer, (Uint8)red, (Uint8)green, (Uint8)blue, (Uint8)alpha) ? 1 : 0;
}
int bmx_SDL3_RenderClear(SDL_Renderer *renderer) { return SDL_RenderClear(renderer) ? 1 : 0; }
int bmx_SDL3_RenderPresent(SDL_Renderer *renderer) { return SDL_RenderPresent(renderer) ? 1 : 0; }
int bmx_SDL3_SetRenderVSync(SDL_Renderer *renderer, int interval) { return SDL_SetRenderVSync(renderer, interval) ? 1 : 0; }
int bmx_SDL3_RenderFillRect(SDL_Renderer *renderer, const SDL_FRect *rect) {
    return SDL_RenderFillRect(renderer, rect) ? 1 : 0;
}
int bmx_SDL3_RenderTexture(SDL_Renderer *renderer, SDL_Texture *texture, const SDL_FRect *destination) {
    return SDL_RenderTexture(renderer, texture, NULL, destination) ? 1 : 0;
}
int bmx_SDL3_RenderTexturePart(SDL_Renderer *renderer, SDL_Texture *texture, const SDL_FRect *source, const SDL_FRect *destination) {
    return SDL_RenderTexture(renderer, texture, source, destination) ? 1 : 0;
}
int bmx_SDL3_GetTextureSize(SDL_Texture *texture, float *width, float *height) {
    return SDL_GetTextureSize(texture, width, height) ? 1 : 0;
}

SDL_Texture *bmx_SDL3_CreateTexture(SDL_Renderer *renderer, Uint32 format, int access, int width, int height) {
	return SDL_CreateTexture(renderer, format ? format : SDL_PIXELFORMAT_RGBA32, (SDL_TextureAccess)access, width, height);
}
int bmx_SDL3_SetRenderTarget(SDL_Renderer *renderer, SDL_Texture *texture) {
	return SDL_SetRenderTarget(renderer, texture) ? 1 : 0;
}
int bmx_SDL3_SetRenderViewport(SDL_Renderer *renderer, const SDL_Rect *rect) {
	return SDL_SetRenderViewport(renderer, rect) ? 1 : 0;
}
int bmx_SDL3_GetRenderViewport(SDL_Renderer *renderer, SDL_Rect *rect) {
	SDL_zero(*rect);
	return SDL_GetRenderViewport(renderer, rect) ? 1 : 0;
}
int bmx_SDL3_ResetRenderViewport(SDL_Renderer *renderer) {
	return SDL_SetRenderViewport(renderer, NULL) ? 1 : 0;
}
int bmx_SDL3_SetRenderClipRect(SDL_Renderer *renderer, const SDL_Rect *rect) {
	return SDL_SetRenderClipRect(renderer, rect) ? 1 : 0;
}
int bmx_SDL3_GetRenderClipRect(SDL_Renderer *renderer, SDL_Rect *rect) {
	SDL_zero(*rect);
	return SDL_GetRenderClipRect(renderer, rect) ? 1 : 0;
}
int bmx_SDL3_ResetRenderClipRect(SDL_Renderer *renderer) {
	return SDL_SetRenderClipRect(renderer, NULL) ? 1 : 0;
}
int bmx_SDL3_RenderViewportSet(SDL_Renderer *renderer) {
	return SDL_RenderViewportSet(renderer) ? 1 : 0;
}
int bmx_SDL3_RenderClipEnabled(SDL_Renderer *renderer) {
	return SDL_RenderClipEnabled(renderer) ? 1 : 0;
}
int bmx_SDL3_SetRenderDrawBlendMode(SDL_Renderer *renderer, int value) {
	return SDL_SetRenderDrawBlendMode(renderer, (SDL_BlendMode)value) ? 1 : 0;
}
int bmx_SDL3_GetRenderDrawBlendMode(SDL_Renderer *renderer, int *value) {
	SDL_BlendMode native = 0;
	int result = SDL_GetRenderDrawBlendMode(renderer, &native) ? 1 : 0;
	*value = (int)native;
	return result;
}
int bmx_SDL3_SetTextureBlendMode(SDL_Texture *texture, int value) {
	return SDL_SetTextureBlendMode(texture, (SDL_BlendMode)value) ? 1 : 0;
}
int bmx_SDL3_GetTextureBlendMode(SDL_Texture *texture, int *value) {
	SDL_BlendMode native = 0;
	int result = SDL_GetTextureBlendMode(texture, &native) ? 1 : 0;
	*value = (int)native;
	return result;
}
int bmx_SDL3_SetTextureScaleMode(SDL_Texture *texture, int value) {
	return SDL_SetTextureScaleMode(texture, (SDL_ScaleMode)value) ? 1 : 0;
}
int bmx_SDL3_GetTextureScaleMode(SDL_Texture *texture, int *value) {
	SDL_ScaleMode native = 0;
	int result = SDL_GetTextureScaleMode(texture, &native) ? 1 : 0;
	*value = (int)native;
	return result;
}
int bmx_SDL3_SetRenderScale(SDL_Renderer *renderer, float x, float y) {
	return SDL_SetRenderScale(renderer, x, y) ? 1 : 0;
}
int bmx_SDL3_GetRenderScale(SDL_Renderer *renderer, float *x, float *y) {
	*x = 0;
	*y = 0;
	return SDL_GetRenderScale(renderer, x, y) ? 1 : 0;
}
int bmx_SDL3_UpdateTexture(SDL_Texture *texture, const SDL_Rect *rect, const void *pixels, int length, int pitch) {
	float width, height;
	if (!SDL_GetTextureSize(texture, &width, &height)) return 0;
	SDL_Rect area = {0, 0, (int)width, (int)height};
	if (rect) area = *rect;
	if (area.x < 0 || area.y < 0 || area.w <= 0 || area.h <= 0 ||
		(Sint64)area.x + area.w > (int)width || (Sint64)area.y + area.h > (int)height) {
		SDL_SetError("Texture upload rectangle is out of bounds");
		return 0;
	}
	SDL_PixelFormat format = texture->format;
	int bytes = SDL_BYTESPERPIXEL(format);
	if (SDL_ISPIXELFORMAT_FOURCC(format) || SDL_ISPIXELFORMAT_INDEXED(format) || bytes <= 0) {
		SDL_SetError("Texture upload requires a packed, non-indexed pixel format");
		return 0;
	}
	Sint64 row = (Sint64)area.w * bytes;
	Sint64 required = (Sint64)(area.h - 1) * pitch + row;
	if (!pixels || pitch < row || length < required) {
		SDL_SetError("Texture upload buffer or pitch is too small");
		return 0;
	}
	return SDL_UpdateTexture(texture, rect, pixels, pitch) ? 1 : 0;
}

int bmx_SDL3_SetTextureColorMod(SDL_Texture *texture, int red, int green, int blue) {
	if (red < 0 || red > 255 || green < 0 || green > 255 || blue < 0 || blue > 255) { SDL_SetError("Modulation channels must be in 0..255"); return 0; }
	return SDL_SetTextureColorMod(texture, (Uint8)red, (Uint8)green, (Uint8)blue) ? 1 : 0;
}
int bmx_SDL3_GetTextureColorMod(SDL_Texture *texture, int *red, int *green, int *blue) {
	Uint8 r = 0;
	Uint8 g = 0;
	Uint8 b = 0;
	int result = SDL_GetTextureColorMod(texture, &r, &g, &b) ? 1 : 0;
	*red = r;
	*green = g;
	*blue = b;
	return result;
}
int bmx_SDL3_SetTextureColorModFloat(SDL_Texture *texture, float red, float green, float blue) {
	return SDL_SetTextureColorModFloat(texture, red, green, blue) ? 1 : 0;
}
int bmx_SDL3_GetTextureColorModFloat(SDL_Texture *texture, float *red, float *green, float *blue) {
	float r = 0;
	float g = 0;
	float b = 0;
	int result = SDL_GetTextureColorModFloat(texture, &r, &g, &b) ? 1 : 0;
	*red = r;
	*green = g;
	*blue = b;
	return result;
}
int bmx_SDL3_SetTextureAlphaMod(SDL_Texture *texture, int alpha) {
	if (alpha < 0 || alpha > 255) { SDL_SetError("Modulation channels must be in 0..255"); return 0; }
	return SDL_SetTextureAlphaMod(texture, (Uint8)alpha) ? 1 : 0;
}
int bmx_SDL3_GetTextureAlphaMod(SDL_Texture *texture, int *alpha) {
	Uint8 a = 0;
	int result = SDL_GetTextureAlphaMod(texture, &a) ? 1 : 0;
	*alpha = a;
	return result;
}
int bmx_SDL3_SetTextureAlphaModFloat(SDL_Texture *texture, float alpha) {
	return SDL_SetTextureAlphaModFloat(texture, alpha) ? 1 : 0;
}
int bmx_SDL3_GetTextureAlphaModFloat(SDL_Texture *texture, float *alpha) {
	float a = 0;
	int result = SDL_GetTextureAlphaModFloat(texture, &a) ? 1 : 0;
	*alpha = a;
	return result;
}
int bmx_SDL3_LockTexture(SDL_Texture *texture, const SDL_Rect *rect, void **pixels, int *pitch, int *width, int *height, int *bytes) {
	float w, h;
	*pixels = NULL;
	*pitch = *width = *height = *bytes = 0;
	if (!SDL_GetTextureSize(texture, &w, &h)) return 0;
	SDL_Rect area = {0, 0, (int)w, (int)h};
	if (rect) area = *rect;
	if (area.x < 0 || area.y < 0 || area.w <= 0 || area.h <= 0 ||
		(Sint64)area.x + area.w > (int)w || (Sint64)area.y + area.h > (int)h) {
		SDL_SetError("Texture lock rectangle is out of bounds");
		return 0;
	}
	int bpp = SDL_BYTESPERPIXEL(texture->format);
	if (SDL_ISPIXELFORMAT_FOURCC(texture->format) || SDL_ISPIXELFORMAT_INDEXED(texture->format) || bpp <= 0) {
		SDL_SetError("Texture lock requires a packed, non-indexed pixel format");
		return 0;
	}
	if (!SDL_LockTexture(texture, rect, pixels, pitch)) return 0;
	*width = area.w;
	*height = area.h;
	*bytes = bpp;
	return 1;
}
void bmx_SDL3_UnlockTexture(SDL_Texture *texture) {
	SDL_UnlockTexture(texture);
}

typedef struct BMX_SDL3_Vertex {
	float x, y;
	SDL_FColor color;
	float u, v;
} BMX_SDL3_Vertex;
SDL_COMPILE_TIME_ASSERT(BMX_SDL3_Vertex_size, sizeof(BMX_SDL3_Vertex) == 8 * sizeof(float));
int bmx_SDL3_RenderGeometry(SDL_Renderer *renderer, SDL_Texture *texture,
	const BMX_SDL3_Vertex *vertices, int count, const int *indices, int indexCount) {
	return SDL_RenderGeometryRaw(renderer, texture, &vertices->x, sizeof(*vertices),
		&vertices->color, sizeof(*vertices), &vertices->u, sizeof(*vertices), count,
		indices, indexCount, sizeof(*indices)) ? 1 : 0;
}
int bmx_SDL3_SetRenderLogicalPresentation(SDL_Renderer *renderer, int width, int height, int mode) {
	return SDL_SetRenderLogicalPresentation(renderer, width, height, (SDL_RendererLogicalPresentation)mode) ? 1 : 0;
}
int bmx_SDL3_GetRenderLogicalPresentation(SDL_Renderer *renderer, int *width, int *height, int *mode) {
	SDL_RendererLogicalPresentation native = SDL_LOGICAL_PRESENTATION_DISABLED;
	*width = *height = 0;
	int result = SDL_GetRenderLogicalPresentation(renderer, width, height, &native) ? 1 : 0;
	*mode = (int)native;
	return result;
}
int bmx_SDL3_GetRenderLogicalPresentationRect(SDL_Renderer *renderer, SDL_FRect *rect) {
	SDL_zero(*rect);
	return SDL_GetRenderLogicalPresentationRect(renderer, rect) ? 1 : 0;
}
int bmx_SDL3_RenderCoordinatesFromWindow(SDL_Renderer *renderer, float x, float y, float *outX, float *outY) {
	*outX = *outY = 0;
	return SDL_RenderCoordinatesFromWindow(renderer, x, y, outX, outY) ? 1 : 0;
}
int bmx_SDL3_RenderCoordinatesToWindow(SDL_Renderer *renderer, float x, float y, float *outX, float *outY) {
	*outX = *outY = 0;
	return SDL_RenderCoordinatesToWindow(renderer, x, y, outX, outY) ? 1 : 0;
}
