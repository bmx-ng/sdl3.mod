#import <AppKit/AppKit.h>
#include <SDL3/SDL.h>
#include <sdl3.mod/sdl3system.mod/event_observer.h>
#import <QuartzCore/CAMetalLayer.h>

void bmx_SDL3_SetHostedEvents(int enabled);
static SDL_AtomicInt wakePending;

/* Drawing must not intercept native canvas input. */
@interface BMXSDLCanvasView : NSView
@end
@implementation BMXSDLCanvasView
- (NSView *)hitTest:(NSPoint)point { return nil; }
@end

static void wakeHost(void) {
	if (SDL_CompareAndSwapAtomicInt(&wakePending, 0, 1)) {
		@autoreleasepool {
			NSEvent *wake = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
				location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0
				context:nil subtype:0 data1:0 data2:0];
			[NSApp postEvent:wake atStart:NO];
		}
	}
}

/* The poll hook resets this before draining so concurrent arrivals can wake again. */
void bmx_SDL3_GUIResetWake(void) { SDL_SetAtomicInt(&wakePending, 0); }

int bmx_SDL3_GUIStart(void) {
	bmx_SDL3_SetHostedEvents(1);
	bmx_SDL3_SetHostWakeup(wakeHost);
	wakeHost();
	return 1;
}

void bmx_SDL3_GUIStop(void) {
	bmx_SDL3_SetHostWakeup(NULL);
}

static void SDLCALL releaseView(void *userdata, void *value) {
	NSView *view = (NSView *)value;
	[view removeFromSuperview];
	[view release];
}

SDL_Window *bmx_SDL3_GUIAttach(void *widget) {
	NSView *host = (NSView *)widget;
	if (!host || ![host window]) {
		SDL_SetError("The MaxGUI canvas must belong to a window");
		return NULL;
	}
	if (!SDL_WasInit(SDL_INIT_VIDEO) && !SDL_InitSubSystem(SDL_INIT_VIDEO)) return NULL;
	BMXSDLCanvasView *view = [[BMXSDLCanvasView alloc] initWithFrame:[host bounds]];
	[view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[host addSubview:view];
	NSWindow *nativeWindow = [host window];
	NSResponder *windowNext = [nativeWindow nextResponder];
	NSResponder *viewNext = [view nextResponder];
	BOOL movedEvents = [nativeWindow acceptsMouseMovedEvents];
	BOOL releasedWhenClosed = [nativeWindow isReleasedWhenClosed];
	NSView *content = [[nativeWindow contentView] retain];
	SDL_PropertiesID props = SDL_CreateProperties();
	SDL_SetPointerProperty(props, SDL_PROP_WINDOW_CREATE_COCOA_VIEW_POINTER, view);
	SDL_SetBooleanProperty(props, SDL_PROP_WINDOW_CREATE_HIGH_PIXEL_DENSITY_BOOLEAN, true);
	SDL_SetBooleanProperty(props, SDL_PROP_WINDOW_CREATE_HIDDEN_BOOLEAN, true);
	SDL_Window *window = SDL_CreateWindowWithProperties(props);
	SDL_DestroyProperties(props);
	[nativeWindow setContentView:content];
	[content release];
	[host addSubview:view];
	[view setFrame:[host bounds]];
	[nativeWindow setReleasedWhenClosed:releasedWhenClosed];
	/* Keep MaxGUI's responder chain intact. SDL observes window notifications. */
	[nativeWindow setNextResponder:windowNext];
	[view setNextResponder:viewNext];
	[nativeWindow setAcceptsMouseMovedEvents:movedEvents];
	if (!window) {
		releaseView(NULL, view);
		return NULL;
	}
	if (!SDL_SetPointerPropertyWithCleanup(SDL_GetWindowProperties(window), "bmx.maxgui.view", view, releaseView, NULL)) {
		SDL_DestroyWindow(window);
		return NULL;
	}
	return window;
}

void bmx_SDL3_GUISize(SDL_Window *window, int *width, int *height, int pixels) {
	NSView *view = SDL_GetPointerProperty(SDL_GetWindowProperties(window), "bmx.maxgui.view", NULL);
	NSRect bounds = [view bounds];
	/* SDL's Metal view normally updates its drawable on SDL window-size events.
	 * A native child canvas can resize without changing the containing window. */
	SDL_Renderer *renderer = SDL_GetRenderer(window);
	if (renderer) {
		CAMetalLayer *layer = (CAMetalLayer *)SDL_GetRenderMetalLayer(renderer);
		NSRect backing = [view convertRectToBacking:bounds];
		if (layer && bounds.size.width > 0 && bounds.size.height > 0) {
			CGFloat scale = backing.size.width / bounds.size.width;
			if (layer.contentsScale != scale) layer.contentsScale = scale;
			CGSize size = NSSizeToCGSize(backing.size);
			if (!CGSizeEqualToSize(layer.drawableSize, size)) layer.drawableSize = size;
		}
	}
	if (pixels) bounds = [view convertRectToBacking:bounds];
	*width = (int)bounds.size.width;
	*height = (int)bounds.size.height;
}

SDL_Renderer *bmx_SDL3_GUIRenderer(SDL_Window *window) {
	NSView *view = SDL_GetPointerProperty(SDL_GetWindowProperties(window), "bmx.maxgui.view", NULL);
	NSView *host = [view superview];
	NSWindow *nativeWindow = [host window];
	NSView *content = [[nativeWindow contentView] retain];
	/* SDL's Metal renderer locates/creates its view beneath the NSWindow content
	 * view. Temporarily scope that lookup to this canvas, then restore the GUI. */
	[nativeWindow setContentView:view];
	SDL_Renderer *renderer = SDL_CreateRenderer(window, "metal");
	[nativeWindow setContentView:content];
	[content release];
	[host addSubview:view];
	[view setFrame:[host bounds]];
	return renderer;
}
