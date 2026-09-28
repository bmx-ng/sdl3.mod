# Max2D and SDL renderer review

Historical review: the compatibility OpenGL modules mentioned below were removed on 28 September 2026. Current SDL3 Max2D backends live in the separate `max2d.mod` repository.

Reviewed 20 September 2026. Scope: the existing SDL2 renderer Max2D driver, BRL.Max2D, the existing GL2 batching driver, and the implications for the new SDL3 modules.

The inspected source revisions were `sdl.mod d2166b2`, `brl.mod c22ccef`, and `sdl3.mod 76ab77d`. The relevant SDL2 and BRL source files had no local modifications. SDL3 contains 3.4.16. There is currently no SDL3 renderer Max2D driver; the SDL3 Max2D implementation so far is the compatibility OpenGL driver.

**Recommendation:** implement the SDL3 renderer driver around a new, small rendering core, and make targeted changes to Max2D's image, text, and context interfaces. Preserve the familiar drawing functions as an adapter. A wholesale replacement of the public API is not necessary to obtain most of the immediate benefits. A new explicit canvas API would, however, allow capabilities that the current interface cannot express well.

## What was established

Two diagnostic programs accompany this report. They reproduce behavior rather than assert that today's defects should remain. They print observations and catch the expected debug exceptions.

- [SDL driver probe](max2d-review-sdl.bmx): runs the current SDL2 driver with a dummy window and software renderer.
- [Core text probe](max2d-review-core.bmx): uses a synthetic font provider, with no graphics backend or installed fonts, to isolate Max2D's handling of shaped glyphs.

Recorded outputs are in [SDL observations](sdl-observations.txt) and [core observations](core-observations.txt).

Both were built and run with the local BlitzMax-bcc2 compiler in debug mode on macOS arm64. No application frame-rate measurements or GPU captures were made. Performance conclusions below concern visible work in the code and architectural opportunities; they are not measured speedup claims. The software-renderer results establish API behavior, not GPU performance.

From the BlitzMax-bcc2 SDK root:

```sh
./bin/bmk makeapp -o /private/tmp/max2d-review-sdl mod/sdl3.mod/reviews/max2d/max2d-review-sdl.bmx
SDL_VIDEODRIVER=dummy /private/tmp/max2d-review-sdl
./bin/bmk makeapp -o /private/tmp/max2d-review-core mod/sdl3.mod/reviews/max2d/max2d-review-core.bmx
/private/tmp/max2d-review-core
```

The SDL probe deliberately selects the software renderer and clears the default graphics flags. This avoids an existing SDL2 graphics-layer problem where the generic backbuffer flag overlaps SDL's OpenGL window flag. The final probe reselects the same graphics object; its caught exception is an expected finding. Run these as debug programs.

## Defects in the current SDL renderer driver

| Finding | Evidence and consequence | Where to fix |
| --- | --- | --- |
| Selecting an existing graphics object attempts to create another renderer | The probe's second `SetGraphics(g)` fails with a null-object exception. SDL reports that a surface is already associated with the software-rendered window. Other renderer paths also reject duplicate renderer creation. The driver replaces its renderer field without checking success. | Own one renderer per graphics context and reuse it. |
| Clear alpha uses the wrong units | `SetClsColor(..., 1.0)` stores byte alpha 1; clearing a target gives alpha 1, not 255. | Driver conversion and state validation. |
| Line width is ignored | A requested width of 7 draws one row. `SetLineWidth` has no implementation. | Shared line tessellation with defined width and endpoint rules. |
| Image sampling flags are ignored | Filtered and unfiltered images both report nearest sampling in the probe. The image creation method accepts `flags` but does not use them. Mipmap requests have no implementation either. | Configure per-image sampling; explicitly describe unsupported capabilities. |
| `MASKBLEND` is implemented as ordinary alpha blending | Alpha-64 red over black produces red 63 rather than leaving black. Max2D documents an alpha cutoff near 0.5; the GL driver uses `GL_GEQUAL, 0.5`. | A defined compatibility policy and, for exact cutoff behavior, an appropriate shader path. |
| `DrawPixmap` inherits normal image drawing state | A red pixmap becomes black when the current drawing color is green. It also goes through origin, transformation, blend, and automatic image-handle behavior. The GL implementation explicitly draws pixels with solid blending. | A dedicated pixel-transfer operation with documented semantics. |
| `DrawPixmap` creates and uploads a texture for every call | Source tracing shows `LoadImage` → `TImage.Frame` → surface/texture creation on each call. | Reusable streaming/upload resources, or an explicit persistent dynamic image. |
| Render images are blended with an inconsistent alpha representation | Half-alpha red is stored as ARGB `7F7F0000`; drawing that target over black produces RGB `003F0000`. Color has been multiplied by alpha twice. | Define and track alpha representation across upload, rendering, compositing, tinting, and readback. |

Sources: [renderer selection and presentation](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/sdl.mod/sdlrendermax2d.mod/sdlrendermax2d.bmx:162), [blend and state handling](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/sdl.mod/sdlrendermax2d.mod/sdlrendermax2d.bmx:223), [image upload](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/sdl.mod/sdlrendermax2d.mod/sdlrendermax2d.bmx:105), [pixmap drawing](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/sdl.mod/sdlrendermax2d.mod/sdlrendermax2d.bmx:421), [GL pixel-transfer behavior](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/brl.mod/glmax2d.mod/glmax2d.bmx:699).

There are additional issues visible in the source that were not individually exercised:

- `Flip(sync)` ignores its argument. Blend-state caching belongs to the driver singleton and is not reset when the renderer changes.
- Renderer, backbuffer, current target, and saved clip state are held globally. Image frames remember their renderer but drawing goes through the global driver. Resource ownership and context switching need a coherent design.
- `SetViewport` uses the original logical coordinates while saving the already-converted physical coordinates; target switching then reapplies the saved values. This mixes coordinate spaces when virtual resolution differs from output size.
- `CreateRenderImageFrame` does not set its width/height fields, allocates an unused CPU pixmap, and attempts to create an unused surface with depth 4. The matrix/viewport helper is commented out. Target-selection errors are ignored.
- Oval subdivision is capped at 49 segments, uses the untransformed radius, and does not safely define degenerate inputs. Polygon triangulation occurs on each draw unless indices are provided; its vertex scratch storage grows on the stack.
- Frame finalization owns texture destruction, while renderer/window destruction can invalidate those native textures first. The wrappers have no common ownership mechanism to invalidate outstanding handles.

These are reasons to redesign this driver rather than port it line for line. They do not demonstrate that an immediate drawing API is inherently unsuitable.

## Limitations and defects in Max2D itself

### Image lifetime and updates

[TImage.Frame and Lock](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/brl.mod/max2d.mod/image.bmx:23) are built around a single cached driver frame and a global `GraphicsSeq`. A write lock drops the cached frame; the next draw creates a replacement from the CPU pixmap. The probe confirms replacement even when the lock made no changes. [UnlockImage](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/brl.mod/max2d.mod/max2d.bmx:1791) is empty.

There is no driver operation for updating an existing frame, no dirty rectangle, and no explicit synchronization between CPU and GPU copies. A driver could attempt to cache by pixmap identity, but it would have to reconstruct information the framework should supply.

One frame per image index also cannot adequately express renderer-specific copies for multiple windows. [SetGraphics](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/brl.mod/graphics.mod/graphics.bmx:292) does not bump the global sequence on each switch. An image first uploaded for one SDL renderer can therefore retain that frame when another renderer becomes current. Fixing duplicate renderer creation is only the first part of multi-window support.

[LoadAnim](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/brl.mod/max2d.mod/image.bmx:94) copies sprite-sheet cells into separate pixmaps. The current SDL driver then gives each frame its own texture. A texture plus subimage views would preserve sharing and reduce texture switches. The existing public drawing calls can still address those views.

### Render targets need their own contract

`TRenderImage` inherits ordinary image locking, but has no readback override. The probe draws nonzero pixels into a target and receives zero pixels from a read-only `LockImage`. This is not an implemented GPU readback operation. A render target should either support explicit readback or reject unsupported locking instead of returning unrelated CPU pixels.

[SetRenderImage](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/brl.mod/max2d.mod/max2d.bmx:1841) also uses a non-null cached frame directly, bypassing `TRenderImage.Frame`'s generation check. Device recreation, readback, clearing, and target lifetime all need to follow the same rules.

Alpha compositing needs a framework-level definition, even though individual drivers implement the blend equations. Premultiplied alpha is a good internal choice for composited layers, but adopting it requires matching upload conversions, opacity/color modulation, blend modes, and readback conventions. Changing one blend mode alone is insufficient. Ordinary image files and legacy `SOLIDBLEND` behavior also need explicit treatment.

### Text is a substantial framework bottleneck

[The image-font layer](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/brl.mod/max2d.mod/imagefont.bmx:83) has three independently reproduced defects:

1. It allocates and iterates shaped output using the input string length. A provider returning one glyph for two characters triggers an array-bounds exception. Real shaping can also produce more glyphs than input characters, which this loop would truncate.
2. The shaped path looks up cached glyph images but does not populate that cache when it creates a new image. Two identical calls produce different image objects unless another path has already populated the relevant cache.
3. [TextWidth](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/brl.mod/max2d.mod/max2d.bmx:676) measures unshaped character advances. The synthetic provider gives a measured width of 20 but a drawn shaped advance of 14.

This does not mean BlitzMax lacks a shaping backend: [Text.HBFreeTypeFont](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/text.mod/hbfreetypefont.mod/hbfreetypefont.bmx:166) already returns a variable-length shaped glyph array. The Max2D adapter is mishandling that output.

Even the correctly cached unshaped path uses one image per glyph; the default bitmap font splits a common source strip into separate images. With this SDL driver that means separate textures, so adjacent different glyphs cannot share a texture batch. A glyph atlas and cached text layouts would address texture changes and repeated CPU work separately. Shaping positions must be stored per layout, while glyph bitmap/atlas entries are shared.

### Context and coordinate state is fragmented

Max2D stores state on `TMax2DGraphics`, but its methods submit through global `_max2dDriver`. Transform changes also update collision globals. Window dimensions, logical resolution, mouse scaling, clip rectangles, and render-target state do not form one explicit context.

[Validate](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/brl.mod/max2d.mod/max2d.bmx:156) resets logical resolution when the window dimensions change and restores clear color with alpha 1.0 rather than the saved clear alpha. These are fixable behaviors, but show why state restoration should be centralized.

A new context should distinguish window coordinates, physical output pixels, logical canvas coordinates, and target pixels. Input must use the inverse of the same presentation mapping, including letterbox offsets. SDL3 already makes viewport, clipping, scale, and logical presentation specific to each target; its [target documentation](https://wiki.libsdl.org/SDL3/SDL_SetRenderTarget) and [logical-presentation API](https://wiki.libsdl.org/SDL3/SDL_SetRenderLogicalPresentation) provide useful building blocks.

## What is not fundamentally wrong with Max2D

The simple calls—`DrawImage`, `DrawRect`, `SetColor`, and `DrawText`—can remain useful. An immediate API can append commands and vertices to a buffer. It does not require immediate GPU submission.

The existing [GL2SDLMax2D driver](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/sdl.mod/gl2sdlmax2d.mod/main.bmx:1415) already batches compatible geometry behind this API. The older buffered GL driver in the workspace provides another precedent.

SDL3 [always batches its renderer commands](https://wiki.libsdl.org/SDL3/README-migration). Its vendored [Metal backend](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/sdl3.mod/sdl3.mod/SDL3/src/render/metal/SDL_render_metal.m:1868) combines adjacent compatible geometry commands into a GPU draw. Therefore one SDL geometry call per sprite is not automatically one GPU draw per sprite. The current SDL driver also already reuses small static vertex/index arrays for quads; it does not allocate a fresh managed vertex array for every quad.

An application-side geometry buffer can still reduce BlitzMax-to-C calls, repeated validation, and SDL command construction. Its value should be measured against SDL's existing batching. Atlas sharing often matters more than adding a second command queue.

There is a relevant SDL2 caveat: explicitly selecting a renderer, as `SDLSetPreferredRenderer` does, normally disables batching in the vendored [SDL2 creation path](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/sdl.mod/sdl.mod/SDL/src/render/SDL_render.c:940), unless the backend forces it or a hint overrides it. This does not apply to SDL3. Benchmarks must record the actual backend and batching configuration.

Batching must preserve painter's order. Arbitrarily sorting translucent or overlapping sprites by texture changes the result. Merge adjacent compatible work, or allow reordering only inside an explicitly defined layer where the application permits it.

## What a new core could achieve

| Capability | Practical gain | Required change |
| --- | --- | --- |
| Stable texture resources with explicit updates | Updating an image does not allocate and upload a replacement texture every time; dirty regions can reduce transfer volume. | Image resource/version API plus backend upload support. |
| Shared texture views and atlas pages | Animation frames and glyphs can share storage and batches. | Resource/view separation, atlas allocation, padding and sampling policy. |
| Cached text layouts | Drawing unchanged text reuses shaping and positioning; measurement uses the same result. | Text layer redesign, using existing font providers where suitable. |
| Explicit canvas and target state | Correct window switching, nested render targets, clipping, logical resolution, and predictable state restoration. | Context object with save/restore and one owner for native state. |
| Shared triangle geometry | Consistent thick lines, rounded shapes, transformed curves, and reusable polygon meshes across backends. | Common tessellation and geometry submission API. |
| Documented alpha and color rules | Transparent layers compose correctly; assets and render targets no longer depend on accidental backend behavior. | Alpha representation and color-space policy, tested across backends. |
| Materials and effects | Gradients, alpha cutoff, outlines, blur passes, and other effects can be expressed intentionally. | New API and capability reporting; suitable renderer/shader backend. |
| Reusable draw lists or meshes | Static UI and repeated complex geometry can avoid repeated CPU construction. | Optional retained data without requiring a scene graph. |
| Diagnostics | Explain texture uploads, flushes, target switches, draw calls, and frame stalls instead of guessing. | Counters and benchmark hooks designed into the core. |

A sensible structure is:

```text
existing Max2D functions       explicit canvas / text-layout / mesh API
             \                         /
               shared 2D rendering core
             /                         \
 SDL3 Renderer backend          optional direct SDL_GPU backend
```

Some improvements, including atlas-backed image frames and geometry buffering, can initially fit behind the existing driver interface. Framework changes are most important for persistent updates, device ownership, text layouts, and explicit target behavior.

The core owns resource identities, geometry construction, drawing state, and ordering. Backends implement submission and native resource management. The legacy adapter handles existing handles/origins, flags, collision integration, and pixel-transfer semantics.

The new API should expose texture views, affine transforms, nested clipping, and scoped render targets directly. Existing API calls can map onto these. Advanced capabilities should report whether they are supported; silently ignoring flags is not an acceptable fallback.

Keep actual SDL rendering on its required thread. Worker threads could prepare CPU geometry or immutable draw lists, with explicit transfer to the rendering thread. A rewrite does not automatically make window rendering safe from arbitrary threads.

For atlases, define lifetime, eviction, maximum page size, texture borders, filtering bleed, and mipmap handling. Do not put all resources into an ever-growing atlas. Large, dynamic, repeating, and render-target textures often belong outside it.

## SDL3 Renderer versus direct SDL_GPU

SDL3 Renderer is a reasonable first backend. It provides portable triangles, textures, clipping, targets, and backend selection. The current [SDL3 binding](/Users/brucey/000_programming/max_bcc2_ast/BlitzMax-bcc2/mod/sdl3.mod/sdl3render.mod/sdl3render.bmx:1) still needs geometry, blending, sampling, target creation/selection, update, and coordinate-state APIs before implementing this Max2D path. These should retain the established C-bool-to-BlitzMax-Int conversion rule. The existing SDL3 graphics context already owns a renderer; the Max2D layer should reuse it.

A useful change in SDL 3.4 is the GPU renderer's [custom render state](https://wiki.libsdl.org/SDL3/SDL_SetGPURenderState), including a custom fragment shader. This is present in the vendored 3.4.16 headers. Consequently, shaders are not by themselves a reason to abandon SDL Renderer. Alpha cutoff and some effects could use that path, subject to implementation and validation.

This is specific to the GPU renderer, not a capability promised by every renderer backend. A general SDL Renderer backend cannot implement exact sample-time alpha testing using an ordinary blend mode. Thresholding source pixels is only an approximation once filtering, global alpha, or render targets are involved.

Direct [SDL_GPU](https://wiki.libsdl.org/SDL3/CategoryGPU) becomes worthwhile when we need control over vertex shaders, instancing, persistent GPU geometry, buffer layouts, render passes, or compute. It also makes the renderer responsible for more synchronization, resource lifetime, shader assets, and backend validation. Shader formats and platform support need a deliberate distribution plan. A new core should permit this backend without requiring it for the first release.

Neither backend automatically supplies high-quality path antialiasing, correct text layout, a good atlas, or consistent compositing. Those are still library design work. A renderer rewrite alone will not help a workload dominated by CPU application logic, fill rate, heavy shaders, or synchronous readback.

## Suggested implementation sequence and decision criteria

1. **Define observable behavior.** Establish reference cases for transforms, line endpoints/width, blend modes, filtering, transparent render targets, clipping, virtual resolution, pixel transfers, multiple windows, and resizing. Resolve the existing `MASKBLEND` cutoff boundary discrepancy explicitly. Preserve intended behavior, not every historical defect.
2. **Build the SDL3 backend with explicit ownership.** Reuse the graphics context's renderer, use a common triangle path, and implement state/target restoration. Start with SDL's queue; add a compact geometry buffer where it demonstrably reduces CPU cost. This replaces the current SDL driver's structure.
3. **Change the resource and text interfaces.** Add persistent frame updates, resource generations per device, explicit readback, shared image views, glyph atlases, and text layouts. Retain defaults/adapters for other Max2D drivers so a new abstract method does not immediately break all of them.
4. **Expose the new canvas API alongside Max2D.** Add affine transforms, save/restore, reusable geometry, and materials. Keep collision APIs as a separate compatibility service; do not make the renderer maintain unrelated global collision state.
5. **Choose further GPU work from measurements.** Compare SDL Renderer with and without the extra geometry buffer. Consider direct SDL_GPU only for measured limitations or concrete capabilities that the renderer cannot provide.

Measure at least repeated same-texture sprites, alternating textures, stable and changing text, dynamic-image updates, complex geometry, render-target composition, and multiple windows. Separate CPU submission time, GPU execution time, and presentation/vsync. Record upload bytes, resource creation/destruction, allocations, batch sizes, and flush reasons. Test software rendering for deterministic behavior and at least Metal, D3D, and Vulkan or the intended deployed backend for native behavior.

Useful acceptance criteria include: unchanged text causes no new texture creation after warmup; image edits reuse resources where possible; compatible ordered sprites coalesce; translucent layer composition matches direct rendering within defined rounding; context switching retains valid resources; and supported capabilities have consistent behavior.

The largest likely gains are steadier frame times, lower upload/allocation churn, faster text-heavy scenes, and reliable composition and context handling. Their magnitude depends on workload. A ground-up internal rewrite can achieve these while preserving the compact API that makes Max2D convenient.
