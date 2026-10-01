#import <AppKit/AppKit.h>
#import <QuartzCore/CAMetalLayer.h>
#include <SDL3/SDL.h>

int test_gpu_layers(NSView *view) {
	int count = [[view layer] isKindOfClass:[CAMetalLayer class]] ? 1 : 0;
	for (NSView *child in [view subviews]) count += test_gpu_layers(child);
	return count;
}

#include "gpu_glue.c"
