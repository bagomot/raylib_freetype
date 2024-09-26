import std.stdio;
import raylib;
import bindbc.freetype;
import std.conv;

void main()
{
	FT_Library ft;
	if (FT_Init_FreeType(&ft) != 0)
	{
		writeln("Could not initialize FreeType.");
		return;
	}

	InitWindow(800, 600, "Test");
	SetTargetFPS(60);

	int fontSize = 32;
	Font font = loadFont(ft, "Inter.ttf", fontSize);

	while (!WindowShouldClose())
	{
		BeginDrawing();
		ClearBackground(Colors.RAYWHITE);

		if(IsFontReady(font))
			DrawTextEx(font, "Test 12345", Vector2(50, 50), fontSize, 1, Colors.BLACK);

		EndDrawing();
	}

	UnloadFont(font);
	CloseWindow();
	FT_Done_FreeType(ft);
}

Font loadFont(FT_Library library, string fontPath, uint fontSize)
{
	FT_Face face;

	if (FT_New_Face(library, fontPath.ptr, 0, &face))
	{
		throw new Exception("Freetype font load error for font");
	}

	FT_Set_Pixel_Sizes(face, 0, fontSize);

	// Raylib font
	Font font;
	font.baseSize = fontSize;
	font.glyphCount = 0;
	font.glyphPadding = 1;

	GlyphInfo[] glyphs;

	FT_ULong charcode;
	uint glyphIndex;

	// Get the first character and its index
	charcode = FT_Get_First_Char(face, &glyphIndex);

	while (glyphIndex != 0)
	{
		// Load glyph by index
		if (FT_Load_Glyph(face, glyphIndex, FT_LOAD_DEFAULT) != 0)
		{
			writeln("Failed to load glyph for codepoint: " ~ charcode.to!string);
			charcode = FT_Get_Next_Char(face, charcode, &glyphIndex);
			continue;
		}

		// Glyph rendering (if it not a bitmap, convert it to bitmap)
		if (face.glyph.format != FT_GLYPH_FORMAT_BITMAP)
		{
			if (FT_Render_Glyph(face.glyph, FT_RENDER_MODE_NORMAL) != 0)
			{
				writeln("Failed to render glyph for codepoint: " ~ charcode.to!string);
				charcode = FT_Get_Next_Char(face, charcode, &glyphIndex);
				continue;
			}
		}

		FT_Bitmap bitmap = face.glyph.bitmap;

		GlyphInfo glyphInfo;
		glyphInfo.value = charcode;
		glyphInfo.offsetX = face.glyph.bitmap_left;
		glyphInfo.offsetY = face.glyph.bitmap_top;
		glyphInfo.advanceX = face.glyph.advance.x >> 6;

		// If glyph is empty, create an empty image, or do nothing?
		if (bitmap.width == 0 || bitmap.rows == 0)
		{
			glyphInfo.image = GenImageColor(1, 1, Colors.BLANK);
		}
		else
		{
			// Convert bitmap to image
			glyphInfo.image = bitmapToImage(bitmap);
		}

		glyphs ~= glyphInfo;

		font.glyphCount++;

		charcode = FT_Get_Next_Char(face, charcode, &glyphIndex);
	}

	font.glyphs = glyphs.ptr;

	// Create font atlas
	Image atlas = GenImageFontAtlas(font.glyphs, &font.recs, font.glyphCount, font.baseSize, 2, 0);

	// Load texture from atlas
	font.texture = LoadTextureFromImage(atlas);

	for (int i = 0; i < font.glyphCount; i++)
	{
		if (font.glyphs[i].image.data !is null)
		{
			UnloadImage(glyphs[i].image);
		}

		// Check if rectangle is valid
		Rectangle rec = font.recs[i];
		if (rec.width <= 0 || rec.height <= 0 || rec.x < 0 || rec.y < 0)
		{
			writeln("Invalid rectangle for glyph: " ~ i.to!string);
			continue;
		}

		// Create new glyph image from atlas
		Image newImage = ImageFromImage(atlas, rec);

		// Check if image was created successfully
		if (newImage.data is null || newImage.width <= 0 || newImage.height <= 0)
		{
			writeln("Failed to create image from atlas for glyph: " ~ i.to!string);
			continue;
		}

		// Assign new image to glyph
		font.glyphs[i].image = newImage;
	}

	UnloadImage(atlas);

	// Free original glyphs images
	for (int i = 0; i < font.glyphCount; i++)
	{
		if (glyphs[i].image.data !is null)
		{
			UnloadImage(glyphs[i].image);
		}
	}

	// Free freetype face
	FT_Done_Face(face);

	return font;
}

Image bitmapToImage(FT_Bitmap bitmap)
{
	Image image;

	switch (bitmap.pixel_mode)
	{
		// the pixel model in the test font is exactly like this
	case FT_PIXEL_MODE_GRAY:
		{
			// For 8-bit grayscale (1 byte per pixel)
			ubyte[] pixels = new ubyte[bitmap.width * bitmap.rows];

			foreach (y; 0 .. bitmap.rows)
			{
				foreach (x; 0 .. bitmap.width)
				{
					int index = y * bitmap.width + x;
					ubyte grayValue = bitmap.buffer[y * bitmap.pitch + x];
					pixels[index] = grayValue;
				}
			}

			image.data = cast(void*) pixels.ptr;
			image.width = bitmap.width;
			image.height = bitmap.rows;
			image.mipmaps = 1;
			image.format = PixelFormat.PIXELFORMAT_UNCOMPRESSED_GRAYSCALE;
		}
		break;
	case FT_PIXEL_MODE_NONE:
	default:
		return GenImageColor(1, 1, Colors.BLANK);
	}

	return image;
}