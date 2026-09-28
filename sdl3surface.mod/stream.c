#include <SDL3/SDL.h>
#include <brl.mod/blitz.mod/blitz.h>
#include <stdint.h>

BBLONG sdl3_sdl3surface_stream__StreamSize(BBObject *context);
BBLONG sdl3_sdl3surface_stream__StreamSeek(BBObject *context, BBLONG offset, int whence);
BBLONG sdl3_sdl3surface_stream__StreamTransfer(BBObject *context, void *buffer, BBLONG size, int writing);

static Sint64 SDLCALL streamSize(void *context) {
	return sdl3_sdl3surface_stream__StreamSize(context);
}
static Sint64 SDLCALL streamSeek(void *context, Sint64 offset, SDL_IOWhence whence) {
	Sint64 result = sdl3_sdl3surface_stream__StreamSeek(context, offset, (int)whence);
	if (result < 0) SDL_SetError("BMP requires a seekable stream; seek failed");
	return result;
}
static size_t transfer(void *context, void *buffer, size_t size, SDL_IOStatus *status, int writing) {
	if (size > INT64_MAX) {
		SDL_SetError("BMP stream transfer exceeds BlitzMax Long range");
		*status = SDL_IO_STATUS_ERROR;
		return 0;
	}
	BBLONG result = sdl3_sdl3surface_stream__StreamTransfer(context, buffer, (BBLONG)size, writing);
	if (result < 0 || (writing && (size_t)result != size)) {
		SDL_SetError("BMP stream %s failed", writing ? "write" : "read");
		*status = SDL_IO_STATUS_ERROR;
	} else if ((size_t)result != size) {
		*status = SDL_IO_STATUS_EOF;
	}
	return result < 0 ? 0 : (size_t)result;
}
static size_t SDLCALL streamRead(void *context, void *buffer, size_t size, SDL_IOStatus *status) {
	return transfer(context, buffer, size, status, 0);
}
static size_t SDLCALL streamWrite(void *context, const void *buffer, size_t size, SDL_IOStatus *status) {
	return transfer(context, (void *)buffer, size, status, 1);
}
static SDL_IOStream *openStream(BBObject *context) {
	SDL_IOStreamInterface ioInterface;
	SDL_INIT_INTERFACE(&ioInterface);
	ioInterface.size = streamSize;
	ioInterface.seek = streamSeek;
	ioInterface.read = streamRead;
	ioInterface.write = streamWrite;
	return SDL_OpenIO(&ioInterface, context);
}
SDL_Surface *bmx_SDL3_LoadBMPStream(BBObject *context) {
	bbGCRetain(context);
	SDL_IOStream *io = openStream(context);
	SDL_Surface *surface = io ? SDL_LoadBMP_IO(io, false) : NULL;
	if (io) SDL_CloseIO(io);
	bbGCRelease(context);
	return surface;
}
int bmx_SDL3_SaveBMPStream(SDL_Surface *surface, BBObject *context) {
	bbGCRetain(context);
	SDL_IOStream *io = openStream(context);
	int result = io && SDL_SaveBMP_IO(surface, io, false) ? 1 : 0;
	if (io) SDL_CloseIO(io);
	bbGCRelease(context);
	return result;
}
void bmx_SDL3_BMPStreamOpenError(void) {
	SDL_SetError("Unable to open BMP stream through BRL.Stream");
}

void bmx_SDL3_BMPInvalidSurface(void) {
	SDL_SetError("Cannot save a destroyed SDL surface");
}
