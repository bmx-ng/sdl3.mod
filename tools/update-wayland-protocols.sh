#!/bin/sh
# Maintainer tool: regenerate bindings after updating bundled SDL protocol XML.
# Normal module builds use the checked-in results and do not run this script.
set -eu
module=$(CDPATH= cd -- "$(dirname -- "$0")/../sdl3.mod" && pwd)
for xml in "$module"/SDL3/wayland-protocols/*.xml; do
	name=$(basename "$xml" .xml)
	wayland-scanner client-header "$xml" "$module/wayland-generated-protocols/$name-client-protocol.h"
	wayland-scanner private-code "$xml" "$module/wayland-generated-protocols/$name-protocol.c"
done
