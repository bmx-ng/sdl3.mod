#include <SDL3/SDL.h>
#include <brl.mod/blitz.mod/blitz.h>

/* Marshal fields explicitly instead of depending on SDL enum/struct ABI. */
typedef struct { int format, channels, freq; } BmxAudioSpec;
static SDL_AudioSpec nativeSpec(const BmxAudioSpec *spec) {
	SDL_AudioSpec result = { (SDL_AudioFormat)spec->format, spec->channels, spec->freq };
	return result;
}
static void copySpec(BmxAudioSpec *dst, const SDL_AudioSpec *src) {
	dst->format = (int)src->format;
	dst->channels = src->channels;
	dst->freq = src->freq;
}
void *bmx_SDL3_AudioDevices(int recording, int *count) {
	*count = 0;
	void *ids = recording ? SDL_GetAudioRecordingDevices(count) : SDL_GetAudioPlaybackDevices(count);
	if (!ids) *count = 0;
	return ids;
}
void bmx_SDL3_FreeAudioDevices(void *ids) { SDL_free(ids); }
BBString *bmx_SDL3_AudioDeviceName(Uint32 id) {
	const char *name = SDL_GetAudioDeviceName(id);
	return bbStringFromUTF8String((const unsigned char *)(name ? name : ""));
}
Uint32 bmx_SDL3_OpenAudioDevice(Uint32 id) { return SDL_OpenAudioDevice(id, NULL); }
void bmx_SDL3_CloseAudioDevice(Uint32 id) { SDL_CloseAudioDevice(id); }
int bmx_SDL3_BindAudioStream(Uint32 id, SDL_AudioStream *stream) { return SDL_BindAudioStream(id, stream) ? 1 : 0; }
int bmx_SDL3_GetAudioDeviceFormat(Uint32 id, BmxAudioSpec *spec, int *frames) {
	SDL_AudioSpec native;
	if (!SDL_GetAudioDeviceFormat(id, &native, frames)) return 0;
	copySpec(spec, &native);
	return 1;
}
SDL_AudioStream *bmx_SDL3_CreateAudioStream(BmxAudioSpec *src, BmxAudioSpec *dst) {
	SDL_AudioSpec source = nativeSpec(src), destination = nativeSpec(dst);
	return SDL_CreateAudioStream(&source, &destination);
}
SDL_AudioStream *bmx_SDL3_OpenAudioDeviceStream(Uint32 id, BmxAudioSpec *spec, int playback) {
	if (!!SDL_IsAudioDevicePlayback(id) != !!playback) {
		SDL_SetError("Audio device direction does not match stream request");
		return NULL;
	}
	SDL_AudioSpec native = nativeSpec(spec);
	return SDL_OpenAudioDeviceStream(id, &native, NULL, NULL);
}
void bmx_SDL3_DestroyAudioStream(SDL_AudioStream *stream) { SDL_DestroyAudioStream(stream); }
Uint32 bmx_SDL3_GetAudioStreamDevice(SDL_AudioStream *stream) { return SDL_GetAudioStreamDevice(stream); }
void bmx_SDL3_UnbindAudioStream(SDL_AudioStream *stream) { SDL_UnbindAudioStream(stream); }
int bmx_SDL3_GetAudioStreamFormat(SDL_AudioStream *stream, BmxAudioSpec *src, BmxAudioSpec *dst) {
	SDL_AudioSpec source, destination;
	if (!SDL_GetAudioStreamFormat(stream, &source, &destination)) return 0;
	copySpec(src, &source);
	copySpec(dst, &destination);
	return 1;
}
static int transferSize(SDL_AudioStream *stream, int count, int writing) {
	SDL_AudioSpec src, dst;
	if (!SDL_GetAudioStreamFormat(stream, &src, &dst)) return 0;
	int frame = SDL_AUDIO_FRAMESIZE(writing ? src : dst);
	if (frame <= 0 || count % frame) {
		SDL_SetError("Audio transfer must contain whole sample frames");
		return 0;
	}
	return 1;
}
int bmx_SDL3_PutAudioStreamData(SDL_AudioStream *stream, const Uint8 *data, int offset, int count) {
	if (!transferSize(stream, count, 1)) return 0;
	if (!count) return 1;
	return SDL_PutAudioStreamData(stream, data + offset, count) ? 1 : 0;
}
int bmx_SDL3_GetAudioStreamData(SDL_AudioStream *stream, Uint8 *data, int offset, int count) {
	if (!transferSize(stream, count, 0)) return -1;
	if (!count) return 0;
	return SDL_GetAudioStreamData(stream, data + offset, count);
}
int bmx_SDL3_PauseAudioDevice(Uint32 id) { return SDL_PauseAudioDevice(id) ? 1 : 0; }
int bmx_SDL3_ResumeAudioDevice(Uint32 id) { return SDL_ResumeAudioDevice(id) ? 1 : 0; }
int bmx_SDL3_AudioDevicePaused(Uint32 id) { return SDL_AudioDevicePaused(id) ? 1 : 0; }
float bmx_SDL3_GetAudioDeviceGain(Uint32 id) { return SDL_GetAudioDeviceGain(id); }
int bmx_SDL3_SetAudioDeviceGain(Uint32 id, float value) { return SDL_SetAudioDeviceGain(id, value) ? 1 : 0; }
int bmx_SDL3_GetAudioStreamAvailable(SDL_AudioStream *stream) { return SDL_GetAudioStreamAvailable(stream); }
int bmx_SDL3_GetAudioStreamQueued(SDL_AudioStream *stream) { return SDL_GetAudioStreamQueued(stream); }
int bmx_SDL3_ClearAudioStream(SDL_AudioStream *stream) { return SDL_ClearAudioStream(stream) ? 1 : 0; }
int bmx_SDL3_FlushAudioStream(SDL_AudioStream *stream) { return SDL_FlushAudioStream(stream) ? 1 : 0; }
float bmx_SDL3_GetAudioStreamGain(SDL_AudioStream *stream) { return SDL_GetAudioStreamGain(stream); }
float bmx_SDL3_GetAudioStreamFrequencyRatio(SDL_AudioStream *stream) { return SDL_GetAudioStreamFrequencyRatio(stream); }
int bmx_SDL3_PauseAudioStreamDevice(SDL_AudioStream *stream) { return SDL_PauseAudioStreamDevice(stream) ? 1 : 0; }
int bmx_SDL3_ResumeAudioStreamDevice(SDL_AudioStream *stream) { return SDL_ResumeAudioStreamDevice(stream) ? 1 : 0; }
int bmx_SDL3_AudioStreamDevicePaused(SDL_AudioStream *stream) { return SDL_AudioStreamDevicePaused(stream) ? 1 : 0; }
int bmx_SDL3_SetAudioStreamGain(SDL_AudioStream *stream, float value) { return SDL_SetAudioStreamGain(stream, value) ? 1 : 0; }
int bmx_SDL3_SetAudioStreamFrequencyRatio(SDL_AudioStream *stream, float value) { return SDL_SetAudioStreamFrequencyRatio(stream, value) ? 1 : 0; }
