SuperStrict
Framework BRL.Max2D
Import BRL.StandardIO

' A synthetic shaping provider makes the glyph-count and cache tests independent
' of font files, native font libraries, and a graphics backend.
Type TReviewGlyph Extends TGlyph
	Field pixmap:TPixmap = CreatePixmap(2, 2, PF_RGBA8888)
	Field advanceValue:Float = 7
	Method Pixels:Object() Override
		Return pixmap
	End Method
	Method Advance:Float() Override
		Return advanceValue
	End Method
	Method GetRect(x:Int Var, y:Int Var, width:Int Var, height:Int Var) Override
		x = 0; y = 0; width = 2; height = 2
	End Method
	Method Index:Int() Override
		Return 0
	End Method
End Type

Type TReviewFont Extends TFont
	Field ligature:Int
	Method Style:Int() Override
		Return KERNFONT
	End Method
	Method Height:Int() Override
		Return 2
	End Method
	Method CountGlyphs:Int() Override
		Return 1
	End Method
	Method CharToGlyph:Int(char:Int) Override
		Return 0
	End Method
	Method LoadGlyph:TGlyph(index:Int) Override
		Local glyph:TReviewGlyph = New TReviewGlyph
		glyph.advanceValue = 10
		Return glyph
	End Method
	Method LoadGlyphs:TGlyph[](text:String) Override
		Local count:Int = text.Length
		If ligature Then count = 1
		Local glyphs:TGlyph[count]
		For Local i:Int = 0 Until count
			glyphs[i] = New TReviewGlyph
		Next
		Return glyphs
	End Method
End Type

Local provider:TReviewFont = New TReviewFont
Local font:TImageFont = New TImageFont
font._src_font = provider
font._style = KERNFONT
font._glyphs = New TImageGlyph[1]

Local first:TImageGlyph[] = font.LoadGlyphs("AV")
Local second:TImageGlyph[] = font.LoadGlyphs("AV")
Print "shaped glyph image reused between calls=" + (first[0]._image = second[0]._image)
Print "shaped glyph image cache populated=" + (font._glyphs[0] <> Null)
Local graphics:TMax2DGraphics = New TMax2DGraphics
graphics.image_font = font
Print "TextWidth unshaped=" + graphics.TextWidth("AV") + " shaped advance=" + (first[0].Advance() + first[1].Advance())

provider.ligature = True
Try
	Local ligature:TImageGlyph[] = font.LoadGlyphs("fi")
	Print "two characters forming one glyph succeeded, count=" + ligature.Length
Catch error:Object
	Print "two characters forming one glyph failed: " + error.ToString()
End Try
