#include <SDL3/SDL.h>
int test_canvas_output(SDL_Renderer *renderer, int *width, int *height) {
	return SDL_GetRenderOutputSize(renderer, width, height) ? 1 : 0;
}
