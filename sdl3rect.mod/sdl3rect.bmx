SuperStrict

Module SDL3.SDL3Rect

ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

Import SDL3.SDL3
Import "glue.c"

' void SDL_RectToFRect(const SDL_Rect *rect, SDL_FRect *frect);                                                         // Convert an SDL_Rect to SDL_FRect
' bool SDL_PointInRect(const SDL_Point *p, const SDL_Rect *r);                                                          // Determine whether a point resides inside a rectangle.
' bool SDL_RectEmpty(const SDL_Rect *r);                                                                                // Determine whether a rectangle has no area.
' bool SDL_RectsEqual(const SDL_Rect *a, const SDL_Rect *b);                                                            // Determine whether two rectangles are equal.
' bool SDL_HasRectIntersection(const SDL_Rect *A, const SDL_Rect *B);                                                   // Determine whether two rectangles intersect.
' bool SDL_GetRectIntersection(const SDL_Rect *A, const SDL_Rect *B, SDL_Rect *result);                                 // Calculate the intersection of two rectangles.
' bool SDL_GetRectUnion(const SDL_Rect *A, const SDL_Rect *B, SDL_Rect *result);                                        // Calculate the union of two rectangles.
' bool SDL_GetRectEnclosingPoints(const SDL_Point *points, int count, const SDL_Rect *clip, SDL_Rect *result);          // Calculate a minimal rectangle enclosing a set of points.
' bool SDL_GetRectAndLineIntersection(const SDL_Rect *rect, int *X1, int *Y1, int *X2, int *Y2);                        // Calculate the intersection of a rectangle and line segment.
' bool SDL_PointInRectFloat(const SDL_FPoint *p, const SDL_FRect *r);                                                   // Determine whether a point resides inside a floating point rectangle.
' bool SDL_RectEmptyFloat(const SDL_FRect *r);                                                                          // Determine whether a floating point rectangle takes no space.
' bool SDL_RectsEqualEpsilon(const SDL_FRect *a, const SDL_FRect *b, float epsilon);                                    // Determine whether two floating point rectangles are equal, within some given epsilon.
' bool SDL_RectsEqualFloat(const SDL_FRect *a, const SDL_FRect *b);                                                     // Determine whether two floating point rectangles are equal, within a default epsilon.
' bool SDL_HasRectIntersectionFloat(const SDL_FRect *A, const SDL_FRect *B);                                            // Determine whether two rectangles intersect with float precision.
' bool SDL_GetRectIntersectionFloat(const SDL_FRect *A, const SDL_FRect *B, SDL_FRect *result);                         // Calculate the intersection of two rectangles with float precision.
' bool SDL_GetRectUnionFloat(const SDL_FRect *A, const SDL_FRect *B, SDL_FRect *result);                                // Calculate the union of two rectangles with float precision.
' bool SDL_GetRectEnclosingPointsFloat(const SDL_FPoint *points, int count, const SDL_FRect *clip, SDL_FRect *result);  // Calculate a minimal rectangle enclosing a set of points with float precision.
' bool SDL_GetRectAndLineIntersectionFloat(const SDL_FRect *rect, float *X1, float *Y1, float *X2, float *Y2);          // Calculate the intersection of a rectangle and line segment with float precision.


Rem
bbdoc: A rectangle, with the origin at the upper left (integer).
End Rem
Struct SSDLRect
	Field x:Int
	Field y:Int
	Field w:Int
	Field h:Int

	Method New(x:Int, y:Int, w:Int, h:Int)
		Self.x = x
		Self.y = y
		Self.w = w
		Self.h = h
	End Method

	Rem
	bbdoc: 
	End Rem
	Method Empty:Int()
		Return bmx_SDL3_RectEmpty(Self)
	End Method

	Rem
	bbdoc: Returns #True if the two rectangles are equal.
	End Rem
	Method Equals:Int(rect:SSDLRect Var)
		Return bmx_SDL3_RectEquals(Self, rect)
	End Method

	Rem
	bbdoc: Determines whether two rectangles intersect.
	End Rem
	Method HasIntersection:Int(rect:SSDLRect Var)
		Return bmx_SDL3_HasIntersection(Self, rect)
	End Method

	Method IntersectRect:Int(rect:SSDLRect Var, result:SSDLRect Var)
		Return bmx_SDL3_IntersectRect(Self, rect, result)
	End Method

	Method IntersectRectAndLine:Int(x1:Int Var, y1:Int Var, x2:Int Var, y2:Int Var)
		Return bmx_SDL3_RectIntersectLine(Self, x1, y1, x2, y2)
	End Method

	Rem
	bbdoc: 
	End Rem
	Method UnionRect:Int(rect:SSDLRect Var, result:SSDLRect Var)
		Return bmx_SDL3_UnionRect(Self, rect, result)
	End Method

End Struct

Struct SSDLFRect
	Field x:Float
	Field y:Float
	Field w:Float
	Field h:Float

	Method New(x:Float, y:Float, w:Float, h:Float)
		Self.x = x
		Self.y = y
		Self.w = w
		Self.h = h
	End Method

	Rem
	bbdoc: 
	End Rem
	Method Empty:Int()
		Return bmx_SDL3_FRectEmpty(Self)
	End Method

	Method Equals:Int(rect:SSDLFRect Var)
		Return bmx_SDL3_FRectEquals(Self, rect)
	End Method

	Method HasIntersection:Int(rect:SSDLFRect Var)
		Return bmx_SDL3_FRectHasIntersection(Self, rect)
	End Method

	Method IntersectRect:Int(rect:SSDLFRect Var, result:SSDLFRect Var)
		Return bmx_SDL3_FRectIntersect(Self, rect, result)
	End Method

	Method UnionRect:Int(rect:SSDLFRect Var, result:SSDLFRect Var)
		Return bmx_SDL3_FRectUnion(Self, rect, result)
	End Method

End Struct

Rem
bbdoc: 
End Rem
Struct SSDLPoint
	Field x:Int
	Field y:Int

	Method New(x:Int, y:Int)
		Self.x = x
		Self.y = y
	End Method
End Struct

Rem
bbdoc: 
End Rem
Struct SSDLFPoint
	Field x:Float
	Field y:Float

	Method New(x:Float, y:Float)
		Self.x = x
		Self.y = y
	End Method
End Struct


Private
Extern
	Function bmx_SDL3_RectEmpty:Int(rect:SSDLRect Var)
	Function bmx_SDL3_RectEquals:Int(a:SSDLRect Var, b:SSDLRect Var)
	Function bmx_SDL3_HasIntersection:Int(a:SSDLRect Var, b:SSDLRect Var)
	Function bmx_SDL3_IntersectRect:Int(a:SSDLRect Var, b:SSDLRect Var, result:SSDLRect Var)
	Function bmx_SDL3_RectIntersectLine:Int(rect:SSDLRect Var, x1:Int Var, y1:Int Var, x2:Int Var, y2:Int Var)
	Function bmx_SDL3_UnionRect:Int(a:SSDLRect Var, b:SSDLRect Var, result:SSDLRect Var)
	Function bmx_SDL3_FRectEmpty:Int(rect:SSDLFRect Var)
	Function bmx_SDL3_FRectEquals:Int(a:SSDLFRect Var, b:SSDLFRect Var)
	Function bmx_SDL3_FRectHasIntersection:Int(a:SSDLFRect Var, b:SSDLFRect Var)
	Function bmx_SDL3_FRectIntersect:Int(a:SSDLFRect Var, b:SSDLFRect Var, result:SSDLFRect Var)
	Function bmx_SDL3_FRectUnion:Int(a:SSDLFRect Var, b:SSDLFRect Var, result:SSDLFRect Var)
End Extern
