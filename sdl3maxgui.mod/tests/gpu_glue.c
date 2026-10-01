#include <SDL3/SDL.h>

int test_gpu_output(SDL_GPUDevice *device, SDL_Window *window, int *width, int *height) {
	SDL_GPUCommandBuffer *command = SDL_AcquireGPUCommandBuffer(device);
	if (!command) return 0;
	SDL_GPUTexture *texture = NULL;
	Uint32 w = 0, h = 0;
	if (!SDL_WaitAndAcquireGPUSwapchainTexture(command, window, &texture, &w, &h)) {
		SDL_CancelGPUCommandBuffer(command);
		return 0;
	}
	*width = w;
	*height = h;
	int submitted = SDL_SubmitGPUCommandBuffer(command);
	return submitted && texture != NULL;
}
