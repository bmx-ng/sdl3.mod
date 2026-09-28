#include <SDL3/SDL_rect.h>

int bmx_SDL3_RectEmpty(const SDL_Rect *rect) {
    return SDL_RectEmpty(rect) ? 1 : 0;
}

int bmx_SDL3_RectEquals(const SDL_Rect *a, const SDL_Rect *b) {
    return SDL_RectsEqual(a, b) ? 1 : 0;
}

int bmx_SDL3_HasIntersection(const SDL_Rect *a, const SDL_Rect *b) {
    return SDL_HasRectIntersection(a, b) ? 1 : 0;
}

int bmx_SDL3_IntersectRect(const SDL_Rect *a, const SDL_Rect *b, SDL_Rect *result) {
    return SDL_GetRectIntersection(a, b, result) ? 1 : 0;
}

int bmx_SDL3_RectIntersectLine(const SDL_Rect *rect, int *x1, int *y1, int *x2, int *y2) {
    return SDL_GetRectAndLineIntersection(rect, x1, y1, x2, y2) ? 1 : 0;
}

int bmx_SDL3_UnionRect(const SDL_Rect *a, const SDL_Rect *b, SDL_Rect *result) {
    return SDL_GetRectUnion(a, b, result) ? 1 : 0;
}

int bmx_SDL3_FRectEmpty(const SDL_FRect *rect) {
    return SDL_RectEmptyFloat(rect) ? 1 : 0;
}

int bmx_SDL3_FRectEquals(const SDL_FRect *a, const SDL_FRect *b) {
    return SDL_RectsEqualFloat(a, b) ? 1 : 0;
}

int bmx_SDL3_FRectHasIntersection(const SDL_FRect *a, const SDL_FRect *b) {
    return SDL_HasRectIntersectionFloat(a, b) ? 1 : 0;
}

int bmx_SDL3_FRectIntersect(const SDL_FRect *a, const SDL_FRect *b, SDL_FRect *result) {
    return SDL_GetRectIntersectionFloat(a, b, result) ? 1 : 0;
}

int bmx_SDL3_FRectUnion(const SDL_FRect *a, const SDL_FRect *b, SDL_FRect *result) {
    return SDL_GetRectUnionFloat(a, b, result) ? 1 : 0;
}
