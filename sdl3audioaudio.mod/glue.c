#include <SDL3/SDL.h>
#include <math.h>
#include <limits.h>
#include <brl.mod/blitz.mod/blitz.h>

/* All managed-facing calls serialize through gate. Callbacks only use their
   stream's SDL lock and never enter BlitzMax or acquire gate. */
typedef struct Sound {
	SDL_AtomicInt refs;
	float *data;
	int frames, freq, loop;
} Sound;
typedef struct Voice {
	struct Voice *next;
	SDL_AudioStream *stream;
	Sound *sound;
	int cursor, ended, owned, stopped;
	int streaming;
	Uint64 submitted;
	float pan, gain, rate;
} Voice;
/* Retained until process exit: GC channel finalizers may run after shutdown. */
static SDL_Mutex *gate;
static SDL_AudioDeviceID device;
static Voice *voices;

static void retainSound(Sound *sound) { SDL_AddAtomicInt(&sound->refs, 1); }
static void releaseSound(Sound *sound) {
	if (sound && SDL_AddAtomicInt(&sound->refs, -1) == 1) {
		SDL_free(sound->data);
		SDL_free(sound);
	}
}
static void SDLCALL feed(void *userdata, SDL_AudioStream *stream, int additional, int total) {
	(void)total;
	Voice *voice = userdata;
	Sound *sound = voice->sound;
	float buffer[1024];
	while (additional > 0 && !voice->ended) {
		int remaining = sound->frames - voice->cursor;
		int count = SDL_min(remaining, SDL_min(512, additional / 8 + (additional % 8 != 0)));
		float left = voice->pan > 0 ? 1.0f - voice->pan : 1.0f;
		float right = voice->pan < 0 ? 1.0f + voice->pan : 1.0f;
		for (int i = 0; i < count; ++i) {
			buffer[i * 2] = sound->data[(voice->cursor + i) * 2] * left;
			buffer[i * 2 + 1] = sound->data[(voice->cursor + i) * 2 + 1] * right;
		}
		if (!SDL_PutAudioStreamData(stream, buffer, count * 8)) {
			voice->ended = 1;
			return;
		}
		voice->cursor += count;
		additional -= count * 8;
		if (voice->cursor == sound->frames) {
			if (sound->loop) voice->cursor = 0;
			else {
				voice->ended = 1;
				SDL_FlushAudioStream(stream);
			}
		}
	}
}
static void closeVoice(Voice *voice) {
	/* Destroy waits for any callback before releasing callback data. */
	if (voice->stream) SDL_DestroyAudioStream(voice->stream);
	voice->stream = NULL;
	releaseSound(voice->sound);
	voice->sound = NULL;
}
static int finished(Voice *voice) {
	if (!voice->stream) return 1;
	SDL_LockAudioStream(voice->stream);
	int result = voice->ended && SDL_GetAudioStreamQueued(voice->stream) == 0;
	SDL_UnlockAudioStream(voice->stream);
	return result;
}
static void reap(void) {
	Voice **link = &voices;
	while (*link) {
		Voice *voice = *link;
		if (!voice->owned && finished(voice)) {
			*link = voice->next;
			closeVoice(voice);
			SDL_free(voice);
		} else link = &voice->next;
	}
}
int bmx_SDL3_AudioDriverStart(void) {
	/* Startup/shutdown are main-thread operations, as with BRL.Audio. */
	if (!SDL_WasInit(SDL_INIT_AUDIO) && !SDL_InitSubSystem(SDL_INIT_AUDIO)) return 0;
	if (!gate) gate = SDL_CreateMutex();
	if (!gate) return 0;
	SDL_LockMutex(gate);
	if (!device) device = SDL_OpenAudioDevice(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, NULL);
	int result = device != 0;
	SDL_UnlockMutex(gate);
	return result;
}
void bmx_SDL3_AudioDriverStop(void) {
	if (!gate) return;
	SDL_LockMutex(gate);
	for (Voice *voice = voices; voice; voice = voice->next) {
		closeVoice(voice);
		voice->stopped = 1;
	}
	if (device) SDL_CloseAudioDevice(device);
	device = 0;
	reap();
	SDL_UnlockMutex(gate);
}
Sound *bmx_SDL3_AudioSoundCreate(const void *data, int frames, int freq, int format, int channels, int loop) {
	if (!data || frames <= 0 || freq <= 0) return NULL;
	SDL_AudioSpec src = {(SDL_AudioFormat)format, channels, freq};
	SDL_AudioSpec dst = {SDL_AUDIO_F32, 2, freq};
	int frameBytes = SDL_AUDIO_FRAMESIZE(src);
	if (frameBytes <= 0 || frames > INT_MAX / frameBytes || frames > INT_MAX / 8) return NULL;
	Sound *sound = SDL_calloc(1, sizeof(*sound));
	if (!sound) return NULL;
	int bytes;
	if (!SDL_ConvertAudioSamples(&src, data, frames * frameBytes, &dst, (Uint8 **)&sound->data, &bytes)) {
		SDL_free(sound);
		return NULL;
	}
	if (bytes < 8) {
		SDL_free(sound->data);
		SDL_free(sound);
		return NULL;
	}
	sound->frames = bytes / 8;
	sound->freq = freq;
	sound->loop = loop != 0;
	SDL_SetAtomicInt(&sound->refs, 1);
	return sound;
}
void bmx_SDL3_AudioSoundFree(Sound *sound) { releaseSound(sound); }
Voice *bmx_SDL3_AudioChannelCreate(void) {
	if (!gate) return NULL;
	SDL_LockMutex(gate);
	reap();
	Voice *voice = device ? SDL_calloc(1, sizeof(*voice)) : NULL;
	if (voice) {
		voice->owned = 1;
		voice->gain = voice->rate = 1;
		voice->next = voices;
		voices = voice;
	}
	SDL_UnlockMutex(gate);
	return voice;
}
void bmx_SDL3_AudioChannelFree(Voice *voice) {
	if (!voice) return;
	SDL_LockMutex(gate);
	voice->owned = 0;
	reap();
	SDL_UnlockMutex(gate);
}
int bmx_SDL3_AudioChannelPlay(Voice *voice, Sound *sound, int paused) {
	if (!voice || !sound) return 0;
	SDL_LockMutex(gate);
	if (!device || voice->stopped) { SDL_UnlockMutex(gate); return 0; }
	closeVoice(voice);
	voice->cursor = voice->ended = 0;
	voice->streaming = 0;
	retainSound(sound);
	voice->sound = sound;
	SDL_AudioSpec spec = {SDL_AUDIO_F32, 2, sound->freq};
	voice->stream = SDL_OpenAudioDeviceStream(device, &spec, feed, voice);
	int ok = voice->stream != NULL;
	if (ok) ok = SDL_SetAudioStreamGain(voice->stream, voice->gain) && SDL_SetAudioStreamFrequencyRatio(voice->stream, voice->rate);
	if (ok && !paused) ok = SDL_ResumeAudioStreamDevice(voice->stream);
	if (!ok) closeVoice(voice);
	SDL_UnlockMutex(gate);
	return ok;
}
void bmx_SDL3_AudioChannelStop(Voice *voice) {
	if (!voice) return;
	SDL_LockMutex(gate);
	closeVoice(voice);
	voice->stopped = 1;
	SDL_UnlockMutex(gate);
}
/* 0=paused, 1=gain, 2=pan, 3=frequency ratio. */
void bmx_SDL3_AudioChannelSet(Voice *voice, int property, float value) {
	if (!voice || !isfinite(value)) return;
	SDL_LockMutex(gate);
	if (!voice->stopped) {
		switch (property) {
		case 0:
			if (voice->stream) {
				if (value != 0) SDL_PauseAudioStreamDevice(voice->stream);
				else SDL_ResumeAudioStreamDevice(voice->stream);
			}
			break;
		case 1:
			voice->gain = SDL_clamp(value, 0.0f, 1.0f);
			if (voice->stream) SDL_SetAudioStreamGain(voice->stream, voice->gain);
			break;
		case 2:
			if (voice->stream) SDL_LockAudioStream(voice->stream);
			voice->pan = SDL_clamp(value, -1.0f, 1.0f);
			if (voice->stream) SDL_UnlockAudioStream(voice->stream);
			break;
		case 3:
			if (value >= 0.01f && value <= 100.0f) {
				voice->rate = value;
				if (voice->stream) SDL_SetAudioStreamFrequencyRatio(voice->stream, value);
			}
			break;
		}
	}
	SDL_UnlockMutex(gate);
}
int bmx_SDL3_AudioChannelPlaying(Voice *voice) {
	if (!voice) return 0;
	SDL_LockMutex(gate);
	int result = voice->stream && !SDL_AudioStreamDevicePaused(voice->stream) && !finished(voice);
	SDL_UnlockMutex(gate);
	return result;
}
int bmx_SDL3_AudioChannelPosition(Voice *voice) {
	if (!voice) return 0;
	SDL_LockMutex(gate);
	int position = 0;
	if (voice->stream) {
		SDL_LockAudioStream(voice->stream);
		if (voice->streaming) {
			Uint64 queued = (Uint64)SDL_max(0, SDL_GetAudioStreamQueued(voice->stream)) / 8;
			Uint64 played = voice->submitted > queued ? voice->submitted - queued : 0;
			position = played > INT_MAX ? INT_MAX : (int)played;
		} else position = voice->cursor - SDL_GetAudioStreamQueued(voice->stream) / 8;
		if (voice->sound && voice->sound->loop) {
			position %= voice->sound->frames;
			if (position < 0) position += voice->sound->frames;
		} else position = SDL_max(0, position);
		SDL_UnlockAudioStream(voice->stream);
	}
	SDL_UnlockMutex(gate);
	return position;
}

/* Streaming workers only enqueue prepared PCM. No filesystem or managed callback
   runs on the SDL audio thread. At most 16384 stereo input frames are queued. */
int bmx_SDL3_AudioStreamingStart(Voice *voice, int freq) {
	if (!voice || freq <= 0) return 0;
	SDL_LockMutex(gate);
	if (!device || voice->stopped) { SDL_UnlockMutex(gate); return 0; }
	closeVoice(voice);
	voice->streaming = 1;
	voice->submitted = 0;
	voice->ended = 0;
	SDL_AudioSpec spec = {SDL_AUDIO_F32, 2, freq};
	voice->stream = SDL_OpenAudioDeviceStream(device, &spec, NULL, NULL);
	int ok = voice->stream != NULL;
	if (ok) ok = SDL_SetAudioStreamGain(voice->stream, voice->gain) && SDL_SetAudioStreamFrequencyRatio(voice->stream, voice->rate);
	if (!ok) closeVoice(voice);
	SDL_UnlockMutex(gate);
	return ok;
}
int bmx_SDL3_AudioStreamingSpace(Voice *voice) {
	SDL_LockMutex(gate);
	int space = -1;
	if (voice->stream && voice->streaming && !voice->ended) {
		int queued = SDL_GetAudioStreamQueued(voice->stream);
		if (queued >= 0) space = SDL_max(0, 16384 - queued / 8);
	}
	SDL_UnlockMutex(gate);
	return space;
}
int bmx_SDL3_AudioStreamingPut(Voice *voice, const float *data, int frames, int channels) {
	if (!voice || !data || frames < 1 || frames > 2048 || (channels != 1 && channels != 2)) return 0;
	float pcm[4096];
	SDL_LockMutex(gate);
	int ok = voice->stream && voice->streaming && !voice->ended;
	if (ok) {
		int queued = SDL_GetAudioStreamQueued(voice->stream);
		ok = queued >= 0 && queued / 8 <= 16384 - frames;
	}
	if (ok) {
		float left = voice->pan > 0 ? 1.0f - voice->pan : 1.0f;
		float right = voice->pan < 0 ? 1.0f + voice->pan : 1.0f;
		for (int i = 0; i < frames; ++i) {
			pcm[i * 2] = data[i * channels] * left;
			pcm[i * 2 + 1] = data[i * channels + (channels == 2)] * right;
		}
		ok = SDL_PutAudioStreamData(voice->stream, pcm, frames * 8);
		if (ok) voice->submitted += frames;
	}
	SDL_UnlockMutex(gate);
	return ok;
}
void bmx_SDL3_AudioStreamingEnd(Voice *voice, int failure) {
	SDL_LockMutex(gate);
	if (voice->stream && voice->streaming) {
		if (failure) SDL_ClearAudioStream(voice->stream);
		else SDL_FlushAudioStream(voice->stream);
		voice->ended = 1;
	}
	SDL_UnlockMutex(gate);
}
int bmx_SDL3_AudioStreamingFinished(Voice *voice) {
	SDL_LockMutex(gate);
	int result = finished(voice);
	SDL_UnlockMutex(gate);
	return result;
}
void bmx_SDL3_AudioStreamingError(BBString *message) {
	char *text = (char *)bbStringToUTF8String(message);
	SDL_SetError("%s", text);
	bbMemFree(text);
}
