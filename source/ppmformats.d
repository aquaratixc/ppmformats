// Written in the D programming language.

/**
Minimalistic library for working with Netpbm image formats. Currently, work with formats from P1 to P6 is supported.
An overview of the internal structure of the library, its interfaces and applications is available at the link (in Russian): https://lhs-blog.info/programming/dlang/ppmformats-library/

Copyright: LightHouse Software, 2020 - 2022
Authors:   Oleg Bakharev,
		   Ilya Pertsev
*/
module ppmformats;

private
{
	import std.algorithm;
	import std.conv;
	import std.range;
	import std.stdio;
	import std.string;
	import std.traits;
	
	/**
	A handy template for creating setters and getters for properties. For internal use only.
	See_Also:
		https://lhs-blog.info/programming/dlang/udobnoe-sozdanie-svoystv-v-klassah-i-strukturah/ (in Russian)
	*/
	template addProperty(T, string propertyName, string defaultValue = T.init.to!string)
	{	 
		const char[] addProperty = format(
			`
			private %2$s %1$s = %4$s;
	 
			void set%3$s(%2$s %1$s)
			{
				this.%1$s = %1$s;
			}
	 
			%2$s get%3$s()
			{
				return %1$s;
			}
			`,
			"_" ~ propertyName.toLower,
			T.stringof,
			propertyName,
			defaultValue
			);
	}

	/// Extract type value from enum. For internal use.
	auto EnumValue(E)(E e) 
		if(is(E == enum)) 
	{
		OriginalType!E tmp = e;
		return tmp; 
	}
	
	/// Add basic constructor for all image filetypes. For internal use.
	mixin template addConstructor(alias pmf)
	{
		this(size_t width = 0, size_t height = 0, RGBColor color = new RGBColor(0, 0, 0))
		{
			_image  = new PixMapImage(width, height, color);
			_header = pmf; 
		}
	
		alias image this;
	}
}

/**
	Class for representing color in RGB format.
*/
class RGBColor
{
	mixin(addProperty!(int, "R"));
	mixin(addProperty!(int, "G"));
	mixin(addProperty!(int, "B"));
	
	
	/**
	Constructor for creating colors in RGB format. 
	If called without parameters, then all three values ​​of the channels R, G and B take the value 0, which corresponds to black.
    Params:
    R = 32-bit value for red channel. The value ranges from 0 (minimum value) to 255 (maximum value).
    G = 32-bit value for green channel. The value ranges from 0 (minimum value) to 255 (maximum value).
    B = 32-bit value for blue channel. The value ranges from 0 (minimum value) to 255 (maximum value).
    
    Typical usage:
    ----
    // Black color
    RGBColor color = new RGBColor;
    
    // Red color	
    RGBColor color = new RGBColor(255, 0, 0);
    
    // White color
    RGBColor color = new RGBColor(255, 255, 255); 
    ----
    */
	this(int R = 0, int G = 0, int B = 0)
	{
		this._r = R;
		this._g = G;
		this._b = B;
	}

	/**
	Luminance according to ITU 709 standard.
	Returns:
	Luminance for a specific color as a floating point value.
    
    Typical usage:
    ----
    import std.stdio : writeln;
    
    // Red color
    RGBColor color = new RGBColor(255, 0, 0); 
	color.luminance709.writeln;
    ----
    */
	const float luminance709()
	{
	   return (_r  * 0.2126f + _g  * 0.7152f + _b  * 0.0722f);
	}
	
	/**
	Luminance according to ITU 601 standard.
	Returns:
	Luminance for a specific color as a floating point value.
    
    Typical usage:
    ----
    import std.stdio : writeln;
    
    // Red color
    RGBColor color = new RGBColor(255, 0, 0); 
	color.luminance601.writeln;
    ----
    */
	const float luminance601()
	{
	   return (_r * 0.3f + _g * 0.59f + _b * 0.11f);
	}
	
	/**
	Average luminance.
	Returns:
	Luminance for a specific color as a floating point value.
    
    Typical usage:
    ----
    import std.stdio : writeln;
    
    // Red color
    RGBColor color = new RGBColor(255, 0, 0); 
	color.luminanceAverage.writeln;
    ----
    */
	const float luminanceAverage()
	{
	   return (_r + _g + _b) / 3.0;
	}

	/// Alias for standard (default) luminance calculation. Value is the same as luminance709.
	alias luminance = luminance709;

	/**
	A string representation of a color.
	The color is output as a string in the following format: RGBColor(R=<value>, G=<value>, B=<value>, I=<value>), where R,G,B are the values ​​of the three color channels, and I is color brightness according to ITU 709.
	Returns:
	String color representation.
    
    Typical usage:
    ----
    import std.stdio : writeln;
    
    // Red color
    RGBColor color = new RGBColor(255, 0, 0); 
	color.writeln;
    ----
    */
	override string toString()
	{		
		return format("RGBColor(%d, %d, %d, I = %f)", _r, _g, _b, this.luminance);
	}

	/**
	Basic arithmetic for color operations. The value on the right can be a value of any numeric type.
    
    Typical usage:
    ----
    // Red color
    RGBColor color = new RGBColor(255, 0, 0);
       	
	// Add two for all channels in color
	auto newColor = color + 2;	
	// Divide all channels by two					
	color = color / 2;								
    ----
    */
	RGBColor opBinary(string op, T)(auto ref T rhs)
	{
		return mixin(
			format(`new RGBColor( 
				clamp(cast(int) (_r  %1$s rhs), 0, 255),
				clamp(cast(int) (_g  %1$s rhs), 0, 255),
				clamp(cast(int) (_b  %1$s rhs), 0, 255)
				)
			`,
			op
			)
		);
	}

	/**
	Basic arithmetic for color operations. Only the RGBColor type can be used as the value on the right.
    
    Typical usage:
    ----
    // Red color
    RGBColor color  = new RGBColor(255, 0, 0);
    // Blue color  	
	RGBColor color2 = new RGBColor(0, 0, 255); 		
	
	// mix two colors
	auto mix = color + color2;
	// difference between color
	auto diff = color - color2;
    ----
    */
	RGBColor opBinary(string op)(RGBColor rhs)
	{
		return mixin(
			format(`new RGBColor( 
				clamp(cast(int) (_r  %1$s rhs.getR), 0, 255),
				clamp(cast(int) (_g  %1$s rhs.getG), 0, 255),
				clamp(cast(int) (_b  %1$s rhs.getB), 0, 255)
				)
			`,
			op
			)
		);
	}
}

/**
	A class that provides a convenient interface for working with images. Represents a one-dimensional array.
*/
class PixMapImage
{
	mixin(addProperty!(size_t, "Width"));
	mixin(addProperty!(size_t, "Height"));
	
	private
	{
		RGBColor[] _image;

		/**
		Calculation of the real index in the internal one-dimensional array storing pixels.
		The real length of the internal array is taken into account, therefore it is allowed to specify an index value greater than the actual length of the array.
		
		Internal use only for implementing class object accessor methods through indexing operators.
		*/
		auto actualIndex(size_t i)
		{
			auto S = _width * _height;
		
			return clamp(i, 0, S - 1);
		}

		/**
		Calculation of the real index in a one-dimensional array through two indexes. 
		Thus, the possibility of referring to the internal array as a two-dimensional one is realized. 
		As in the previous method, the binding to the actual length of the internal array is taken into account, so both indexes can be greater than the actual values ​​of the length and width of the image.
		
		Internal use only for implementing class object accessor methods through indexing operators.
		*/
		auto actualIndex(size_t i, size_t j)
		{
			auto W = cast(size_t) clamp(i, 0, _width - 1);
			auto H = cast(size_t) clamp(j, 0, _height - 1);
			auto S = _width * _height;
		
			return clamp(W + H * _width, 0, S);
		}
	}

	/**
	A constructor for creating an image with given dimensions (length and width) and starting color for pixels. 
	By default, all values ​​are zero, and black (i.e: RGBColor(0, 0, 0)) is used as the starting color.
    Params:
    width = Width of image as size_t value. 
    height = Height of image as size_t value.
    color = Initial color for pixels in image.
    
    Typical usage:
    ----
    // creating of empty image
    PixMapImage pmi = new PixMapImage;  									
    
    // creating image of size 20x20, all pixels are black
    PixMapImage pmi2 = new PixMapImage(20, 20);								
    
    // creating image of size 20x20, all pixels are red
    PixMapImage pmi3 = new PixMapImage(20, 20, new RGBColor(255, 0, 255));	
    ----
    */	
	this(size_t width = 0, size_t height = 0, RGBColor color = new RGBColor(0, 0, 0))
	{
		this._width = width;
		this._height = height;

		foreach (x; 0.._width)
		{
			foreach (y; 0.._height)
			{
				_image ~= color;
			}	
		}
	}

	/**
	Assigning a color value to an individual pixel through a two-index indexing operation.
	Note: It is allowed to use as indices values ​​greater than the length and width (or less than 0) as indices, since the values ​​will be converted to the actual length of the image array.
    
    Typical usage:
    ----
    // creating image of size 20x20, all pixels are black
    auto pmi = new PixMapImage(20, 20);   
    // pixel at coords (5;5) now are green
    pmi[5, 5] = new RGBColor(0, 255, 0);  
    ----
	*/	
	RGBColor opIndexAssign(RGBColor color, size_t x, size_t y)
	{
		_image[actualIndex(x, y)] = color;
		return color;
	}

	/**
	Assigning a color value to an individual pixel through a one-index indexing operation.
	Note: It is allowed to use an index greater than the actual length of the array or less than 0, since it is bound to the real length of the internal array of the image.
    
    Typical usage:
    ----
    // creating image of size 20x20, all pixels are black
    auto pmi = new PixMapImage(20, 20);   
    // 6th pixel now are green
    pmi[5] = new RGBColor(0, 255, 0);  	  
    ----
	*/	
	RGBColor opIndexAssign(RGBColor color, size_t x)
	{
		_image[actualIndex(x)] = color;
		return color;
	}

	/**
	Getting a color value from an individual pixel through a two-index indexing operation.
	Note: It is allowed to use as indices values ​​greater than the length and width (or less than 0) as indices, since the values ​​will be converted to the actual length of the image array.
    
    Typical usage:
    ----
    // creating image of size 20x20, all pixels are black
    auto pmi = new PixMapImage(20, 20);   
    // get pixel color at coords (5;5)
    pmi[5, 5].writeln;  				  
    ----
	*/	
	RGBColor opIndex(size_t x, size_t y)
	{
		return _image[actualIndex(x, y)];
	}

	/**
	Assigning a color value to an individual pixel through a one-index indexing operation.
	Note: It is allowed to use an index greater than the actual length of the array or less than 0, since it is bound to the real length of the internal array of the image.
    
    Typical usage:
    ----
    // creating image of size 20x20, all pixels are black
    auto pmi = new PixMapImage(20, 20);   
    // getting color of 6th pixel
    pmi[5].writeln;  	  				  
    ----
	*/	
	RGBColor opIndex(size_t x)
	{
		return _image[actualIndex(x)];
	}

	/**
	The string representation of the image. Returns a string representing the image as a two-dimensional array of RGBColor objects.
	*/	
	override string toString()
	{
		string accumulator = "[";

		foreach (x; 0.._width)
		{
			string tmp = "[";
			foreach (y; 0.._height)
			{
				tmp ~= _image[actualIndex(x, y)].toString ~ ", ";				
			}
			tmp = tmp[0..$-2] ~ "], ";
			accumulator ~= tmp;
		}
		return accumulator[0..$-2] ~ "]";
	}

	/// Returns actual width of image as size_t value
	alias width = getWidth;
	/// Returns actual height of image as size_t value
	alias height = getHeight;

	/**
	Returns the entire internal one-dimensional pixel array of the image.
	Returns:
	One-dimensional array of RGBColor objects.
    
    Typical usage:
    ----
    PixMapImage pmi = new PixMapFile(10, 10);
    // get all pixels 
	RGBColor[] pixels = pmi.array;	
    ----
    */
	final RGBColor[] array()
	{
		return _image;
	}
	
	/**
	Sets the inner pixel array of the image by feeding the outer array. 
	The size of the array must be equal to the actual size of the image (i.e. the size of the given one-dimensional array must be equal to the product of the length of the image and its width)
	Throws:
	Exception if the length of the supplied array does not match the actual length of the internal array, as above.
    
    Typical usage:
    ----
    PixMapImage pmi = new PixMapFile(2);
	RGBColor[] pixels = [new RGBColor(255, 255, 255), new RGBColor(255, 255, 255)];
	// set all pixels as white
	pmi.array(pixels);	
    ----
    */
	final void array(RGBColor[] image)
	{
		if (image.length == _image.length) 
		{
			this._image = image;
		}
		else
		{
			throw new Exception("Lengths must be the same");
		}
	}
	
	/**
	Resizing an image according to its given length and width. 
	Note:
	If the length and/or width are smaller than the original values, then a literal cropping to the desired dimensions will be performed (not interpolation or approximation, but real cropping!). 
	If the size parameters are larger than the original ones, then the image size will be increased by adding the default color to the end of the image (real array addition will be performed, not interpolation).
    
    WARNING:
		The method is highly controversial and experimental. We strongly discourage its use in real projects.
    */
	final void changeCapacity(size_t x, size_t y)
	{
		long newLength = (x * y);
		
		if (newLength > _image.length)
		{
			auto restLength = cast(long) newLength - _image.length;
			_image.length += cast(size_t) restLength;
		}
		else
		{
			if (newLength < _image.length)
			{
				auto restLength = cast(long) _image.length - newLength;
				_image.length -= cast(size_t) restLength;
			}
		}
		_width = x;
		_height = y;
	}
}

/**
	All possible types of Portable Anymap Image formats in the form of a convenient division into binary and text image formats.
*/
enum PixMapFormat : string
{
	PBM_TEXT 	= 	"P1",
	PBM_BINARY 	=  	"P4",
	PGM_TEXT 	= 	"P2",
	PGM_BINARY	=	"P5",
	PPM_TEXT	=	"P3",
	PPM_BINARY	= 	"P6",
	PF_RGB_BINARY = "PF",
}

/**
	Common ancestor for all subsequent image types.
	Implements a generic way to load/save images by providing generic load/save methods. 
	Also, inheritance from this class allows descendant classes to have methods for working with images: indexing, assigning values ​​to pixels and accessing them without the need to create an object of the PixMapImage class to manipulate images.
	
	Implementation Note: The specific loading method is already implemented by descendant classes by overriding the abstract loader/saver methods in their implementations.
*/
class PixMapFile
{
	mixin(addProperty!(PixMapImage, "Image"));
	
	protected
	{
		File _file;
		PixMapFormat _header;
		
		abstract void loader();
		abstract void saver();
	}

	private
	{
		/// Set i/o mode for reading/writing Portable Anymap Images. Actual for OS Windows. For internal use.
		auto IOMode(string mode)
		{
			
			if (isBinaryFormat) 
			{
				return mode ~ `b`;
			}
			else
			{
				return mode;
			}
		}
	}

	/// Basic file loading procedure
	void load(string filename)
	{
		with (_file)
		{
			open(filename, IOMode(`r`));

			if (readln.strip == EnumValue(_header))
			{
				auto imageSize = readln.split;
				auto width = imageSize[0].parse!int;
				auto height = imageSize[1].parse!int;

				_image = new PixMapImage(width, height);

				loader;
			}
		}
	}
	
	/// Basic file saving procedure
	void save(string filename)
	{
		with (_file)
		{
			open(filename, IOMode("w"));
			writeln(EnumValue(_header));
			writeln(_image.width, " ", _image.height);

			saver;
		}
	}

	/// Is raw format ?
	final bool isBinaryFormat()
	{
		return 
				( 
				  (_header == PixMapFormat.PBM_BINARY) |
				  (_header == PixMapFormat.PGM_BINARY) |
				  (_header == PixMapFormat.PPM_BINARY) |
				  (_header == PixMapFormat.PF_RGB_BINARY)
				);
	}

	/// Is text format ?
	final bool isTextFormat()
	{
		return 
				( 
				  (_header == PixMapFormat.PBM_TEXT) |
				  (_header == PixMapFormat.PGM_TEXT) |
				  (_header == PixMapFormat.PPM_TEXT)
				);
	}	

	/// Get image object as PixMapImage object
	final PixMapImage image() 
	{ 
		return this.getImage; 
	}
	
	/// Set image object as PixMapImage object
	final void image(PixMapImage image)
	{
		this.setImage(image);
	}

	/// Convenient alias for working with PixMapFile same as PixMapImage
	alias image this;
}

/**
	A class that provides the ability to work with color images in P6 format. 
	NB: The format is raw binary. 
	
	Note: 
		This class supports indexing and assigning values ​​to specific pixels via 1D or 2D indexing, and provides P6 file loading/saving capabilities. 
		According to the accepted convention, in the original description of the format inside the Netpbm package, the extension of these files should be `*.ppm`.
		
	Typical usage:
    ----
    // creating of empty image
    auto img = new P6Image;  					
    // load image from file `Lenna.ppm`
    img.load(`Lenna.ppm`);   					
    // change pixel at coords (10; 10), now are white
    img[10, 10] = new RGBColor(255, 255, 255); 	
    // get color of 11th pixel
    img[10].writeln;							
    // save file as `Lenna2.ppm`
    img.save(`Lenna2.ppm`);						
    
    // creating image of 10x10, all pixels are red
    auto img2 = new P6Image(10, 10, new RGBColor(255, 0, 255)); 
    // increasing luminance by two
    img2[10] = img2[10] * 2; 									
    // save as `test.ppm`
    img2.save(`test.ppm`);										
    ----
*/
class P6Image : PixMapFile
{
	mixin(addProperty!(int, "Intensity", "255"));
	mixin addConstructor!(PixMapFormat.PPM_BINARY);

	override void loader()
	{
		auto data = _file.readln;
		_intensity = data.parse!int;

		auto buffer = new ubyte[width * 3];
		
		for (uint i = 0; i < height; i++)
		{
		 	_file.rawRead!ubyte(buffer);
						
		    for (uint j = 0; j < width; j++)
		    {
				auto R = buffer[j * 3];
				auto G = buffer[j * 3 + 1];
				auto B = buffer[j * 3 + 2];
		 	 	_image[j, i] = new RGBColor(
					(R > _intensity) ? _intensity : R,
					(G > _intensity) ? _intensity : G,
					(B > _intensity) ? _intensity : B
				);
		    } 
		}
	}

	override void saver()
	{
		_file.writeln(_intensity);

		foreach (e; _image.array)
		{
			auto R = e.getR;
			auto G = e.getG;
			auto B = e.getB;

			auto rr = (R > _intensity) ? _intensity : R;
			auto gg = (G > _intensity) ? _intensity : G;
			auto bb = (B > _intensity) ? _intensity : B;

			_file.write(
				cast(char) rr,
				cast(char) gg,
				cast(char) bb
		    );
	    }
	}
}

/**
	A class that provides the ability to work with color images in P3 format. 
	NB: The format is raw text. 
	
	Note: 
		This class supports indexing and assigning values ​​to specific pixels via 1D or 2D indexing, and provides P3 file loading/saving capabilities. 
		According to the accepted convention, in the original description of the format inside the Netpbm package, the extension of these files should be `*.ppm`.
		
	Typical usage:
    ----
    // creating of empty image
    auto img = new P3Image;  					
    // load image from file `Lenna.ppm`
    img.load(`Lenna.ppm`);   					
    // change pixel at coords (10; 10), now are white
    img[10, 10] = new RGBColor(255, 255, 255); 	
    // get color of 11th pixel
    img[10].writeln;							
    // save file as `Lenna2.ppm`
    img.save(`Lenna2.ppm`);						
    
    // creating image of 10x10, all pixels are red
    auto img2 = new P3Image(10, 10, new RGBColor(255, 0, 255)); 
    // increasing luminance by two
    img2[10] = img2[10] * 2; 									
    // save as `test.ppm`
    img2.save(`test.ppm`);										
    ----
*/
class P3Image : PixMapFile
{
	mixin(addProperty!(int, "Intensity", "255"));
	mixin addConstructor!(PixMapFormat.PPM_TEXT);

	override void loader()
	{
		// skip maximal intensity description
		auto data = _file.readln;
		_intensity = data.parse!int;
		
		string triplet;
		int index = 0;
						
		while ((triplet = _file.readln) !is null)
		{				
			auto rgb = triplet.split;
			auto R = rgb[0].parse!int;
		    auto G = rgb[1].parse!int;
		    auto B = rgb[2].parse!int;

			_image[index] = new RGBColor(
		 		(R > _intensity) ? _intensity : R,
		        (G > _intensity) ? _intensity : G,
		        (B > _intensity) ? _intensity : B		
 			);
		 	index++;
		}
	}

	override void saver()
	{
		_file.writeln(_intensity);

		foreach (e; _image.array)
		{
			auto R = e.getR;
			auto G = e.getG;
			auto B = e.getB;

			_file.writefln(
				"%d %d %d",
				(R > _intensity) ? _intensity : R,
				(G > _intensity) ? _intensity : G,
				(B > _intensity) ? _intensity : B
		    );
	    }
     }
}

/**
	A class that provides the ability to work with color images in P1 format. 
	NB: The format is raw text. 
	
	Note: 
		This class supports indexing and assigning values ​​to specific pixels via 1D or 2D indexing, and provides P1 file loading/saving capabilities. 
		According to the accepted convention, in the original description of the format inside the Netpbm package, the extension of these files should be `*.pbm`.
		
	Typical usage:
    ----
    // creating of empty image
    auto img = new P1Image;  					
    // load image from file `Lenna.pbm`
    img.load(`Lenna.pbm`);   					
    // change pixel at coords (10; 10), now are white
    img[10, 10] = new RGBColor(255, 255, 255); 	
    // get color of 11th pixel
    img[10].writeln;							
    // save file as `Lenna2.pbm`
    mg.save(`Lenna2.pbm`);						
    
    // creating image of 10x10, all pixels are black
    auto img2 = new P1Image(10, 10, new RGBColor(0, 0, 0)); 
    // increasing luminance by two
    img2[10] = img2[10] * 2; 									
    // save as `test.pbm`
    img2.save(`test.pbm`);										
    ----
*/
class P1Image : PixMapFile
{
	mixin addConstructor!(PixMapFormat.PBM_TEXT);

	override void loader()
	{
		 string line;
		 int index;
		
		 auto WHITE = new RGBColor(255, 255, 255);
		 auto BLACK = new RGBColor(0, 0, 0);
						
		 while ((line = _file.readln) !is null)
		 {
		 	auto row  = line.replace(" ", "").replace("\n", "");
		
		 	foreach (i, e; row)
		 	{
		 		_image[i, index] = (e.to!string == "0") ? WHITE : BLACK; 			
		 	}					
		 	index++;
		 }				
	}

	override void saver()
	{
		foreach (rows; _image.array.chunks(width))
		{
		 	_file.writeln(
		 		rows
		 			.map!(a => (a.luminance < 255) ? "1" : "0")
		 			.join(" ")
		 	);
		}
	}
}

/**
	A class that provides the ability to work with color images in P2 format. 
	NB: The format is raw text. 
	
	Note: 
		This class supports indexing and assigning values ​​to specific pixels via 1D or 2D indexing, and provides P2 file loading/saving capabilities. 
		According to the accepted convention, in the original description of the format inside the Netpbm package, the extension of these files should be `*.pgm`.
		
	Typical usage:
    ----
    // creating of empty image
    auto img = new P2Image;  					
    // load image from file `Lenna.pgm`
    img.load(`Lenna.pgm`);   					
    // change pixel at coords (10; 10), now are white
    img[10, 10] = new RGBColor(255, 255, 255); 	
    // get color of 11th pixel
    img[10].writeln;							
    // save file as `Lenna2.pgm`
    img.save(`Lenna2.pgm`);						
    
    // creating image of 10x10, pixels are black
    auto img2 = new P2Image(10, 10, new RGBColor(0, 0, 0)); 
    // increasing luminance by two
    img2[10] = img2[10] * 2; 									
    // save as `test.pgm`
    img2.save(`test.pgm`);										
    ----
*/
class P2Image : PixMapFile
{
	mixin(addProperty!(int, "Intensity", "255"));
	mixin addConstructor!(PixMapFormat.PGM_TEXT);

	override void loader()
	{
		 // skip maximal intensity description
		 auto data = _file.readln;
		 _intensity = data.parse!int;
		
	     string line;
		 int index;
		
		 while ((line = _file.readln) !is null)
		 {
		 	auto row  = line.split;
		
		 	foreach (i, e; row)
		 	{
		 		auto l = e.parse!int;
				auto I = (l > _intensity) ? _intensity : l;
		 		_image[i, index] = new RGBColor(I, I, I);  						
		 	}					
		 	index++;
		 } 
	}

	override void saver()
	{
		_file.writeln(_intensity);
	
	   	foreach (rows; _image.array.chunks(width))
	    {
			auto toIntensity(RGBColor color)
			{
				int I;
				if ((color.getR == color.getG) && (color.getG == color.getB) && (color.getR == color.getB))
				{
					I = color.getR;
				}
				else
				{
					I = color.luminance601.to!int;
				}
				return (I > _intensity) ? _intensity : I;				
			}
			
	    	_file.writeln(
	    		 rows
	    		 	.map!(a => toIntensity(a).to!string)
	    		 	.join(" ")
	    	);
	    }
     }
}

/**
	A class that provides the ability to work with color images in P5 format. 
	NB: The format is raw binary. 
	
	Note: 
		This class supports indexing and assigning values ​​to specific pixels via 1D or 2D indexing, and provides P5 file loading/saving capabilities. 
		According to the accepted convention, in the original description of the format inside the Netpbm package, the extension of these files should be `*.pgm`.
		
	Typical usage:
    ----
    // create empty image
    auto img = new P5Image;
    // load from file  					
    img.load(`Lenna.pgm`);   					
    // set pixel at (10;10) to white color
    img[10, 10] = new RGBColor(255, 255, 255);
    // get color of 11th pixel 	
    img[10].writeln;							
    // save to file
    img.save(`Lenna2.pgm`);						
    
    // creating image of size 10x10, all pixels black
    auto img2 = new P5Image(10, 10, new RGBColor(0, 0, 0)); 
    // increase luminance twice
    img2[10] = img2[10] * 2;
    // save as pgm file 									
    img2.save(`test.pgm`);										
    ----
*/
class P5Image : PixMapFile
{
	mixin(addProperty!(int, "Intensity", "255"));
	mixin addConstructor!(PixMapFormat.PGM_BINARY);

	override void loader()
	{
		// skip maximal intensity description
		auto data = _file.readln;
		_intensity = data.to!int;

		auto buffer = new ubyte[width * height];
		_file.rawRead!ubyte(buffer);

		foreach (i, e; buffer)
		{
			auto I =  (e > _intensity) ? _intensity : e;
			_image[i] = new RGBColor(I, I, I);
		}
	}

	override void saver()
	{
		_file.writeln(_intensity);

		foreach (e; _image.array)
		{
			ubyte I;
			if ((e.getR == e.getG) && (e.getG == e.getB) && (e.getR == e.getB))
			{
				I = e.getR.to!ubyte;
			}
			else
			{
				I = e.luminance601.to!ubyte;
			}

			_file.write(
				cast(char) I
			);
		}
     }
}

/**
	A class that provides the ability to work with color images in P4 format. 
	NB: The format is raw binary. 
	
	Note: 
		This class supports indexing and assigning values ​​to specific pixels via 1D or 2D indexing, and provides P4 file loading/saving capabilities. 
		According to the accepted convention, in the original description of the format inside the Netpbm package, the extension of these files should be `*.pbm`.
		
	Typical usage:
    ----
    // create empty P4 image
    auto img = new P4Image; 
    // load from file 					
    img.load(`Lenna.pbm`);   					
    // set pixel at (10; 10) as white
    img[10, 10] = new RGBColor(255, 255, 255); 	
    // get 11th pixel
    img[10].writeln;							
    // save to file
    img.save(`Lenna2.pbm`);						
    
    // new P4 image, size is 10x10, all pixels black
    auto img2 = new P4Image(10, 10, new RGBColor(0, 0, 0)); 
    // increase two times
    img2[10] = img2[10] * 2; 									
    // save as pbm file
    img2.save(`test.pbm`);										
    ----
*/
class P4Image : PixMapFile
{
	mixin addConstructor!(PixMapFormat.PBM_BINARY);

	auto setBit(int value, int n)
	{
		return (value | (1 << n));
	}

	auto getBit(int value, int n)
	{
		return ((value >> n) & 1);
	}

	auto clearBit(int value, int n)
	{
		return (value & ~(1 << n));
	}
	
	auto BLACK = new RGBColor(0, 0, 0);
	auto WHITE = new RGBColor(255, 255, 255);

	override void loader()
	{
		auto imageSize = width * height;
		auto buffer = new ubyte[imageSize];
		_file.rawRead!ubyte(buffer);

		int index;

		foreach (e; buffer)
		{
			if (index < imageSize)
			{
				foreach (i; 0..8)
				{
					auto I = getBit(cast(int) e, 7 - i);
					_image[index] = I ? BLACK : WHITE;
					index++;
				}
			}
			else
			{
				break;
			}
		}				
	}

	override void saver()
	{	    
	    foreach (e; _image.array.chunks(width))
	    {
			foreach (r; e.chunks(8))
			{
				auto bits = 0x00;
				
				foreach (i, b; r)
				{
					auto I = (b.luminance == 0) ? 1 : 0;
					
					if (I == 1)
					{
						bits = setBit(bits, cast(int) (7 - i));
					}
				}
				_file.write(
					cast(char) bits
				);
			}
		}
	}
}

/// Endianess (i.e byte-order)
enum BYTE_ORDER
{
	/// Little-endian byte-order
	LITTLE_ENDIAN,
	/// Big-endian byte-order
	BIG_ENDIAN
}


/**
	A class that provides the ability to work with color images in PF (portable floatmap image) format. 
	NB: The format is raw binary. Support of this format is EXPERIMENTAL (!!!).
	
	Note: 
		This class supports indexing and assigning values ​​to specific pixels via 1D or 2D indexing, and provides PF file loading/saving capabilities. 
		According to the accepted convention, in the original description of the format inside the Netpbm package, the extension of these files should be `*.pfm`.
		
	Typical usage:
    ----
    // create empty PF image
    auto img = new PFImage; 
    // load from file 					
    img.load(`Lenna.pfm`);   					
    // set pixel at (10; 10) as white
    img[10, 10] = new RGBColor(255, 255, 255); 	
    // get 11th pixel
    img[10].writeln;							
    // save to file
    img.save(`Lenna2.pfm`);						
    
    // new PF image, size is 10x10, all pixels black
    auto img2 = new PFImage(10, 10, new RGBColor(0, 0, 0)); 
    // increase two times
    img2[10] = img2[10] * 2; 
    // select byte order for saving (by default, little-endian, i.e BYTE_ORDER.LITTLE_ENDIAN)
    img2.setOrder(BYTE_ORDER.BIG_ENDIAN);									
    // save as pfm file
    img2.save(`test.pfm`);										
    ----
*/
class PFImage : PixMapFile
{
	mixin(addProperty!(uint, "Intensity", "255"));
	mixin(addProperty!(uint, "Order", "BYTE_ORDER.LITTLE_ENDIAN"));
	
	mixin addConstructor!(PixMapFormat.PF_RGB_BINARY);
	
	private 
	{
		/// reconstruct unsigned integer value from unsigned bytes (little-endian order)
		static uint fromLEBytes(ubyte[] bytes)
		{
			return ((bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | bytes[0]);
		}
		
		/// reconstruct unsigned integer value from unsigned bytes (big-endian order)
		static uint fromBEBytes(ubyte[] bytes)
		{
			return ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]);
		}
		
		static ubyte[] toBEBytes(uint value)
		{
			ubyte[] bytes;
			
			bytes ~= (value & 0xff000000) >> 24;
			bytes ~= (value & 0x00ff0000) >> 16;
			bytes ~= (value & 0x0000ff00) >> 8;
			bytes ~= (value & 0x000000ff);
			
			return bytes;
		}
		
		static ubyte[] toLEBytes(uint value)
		{
			ubyte[] bytes;
		
			bytes ~= (value & 0x000000ff);
			bytes ~= (value & 0x0000ff00) >> 8;
			bytes ~= (value & 0x00ff0000) >> 16;
			bytes ~= (value & 0xff000000) >> 24;
			
			return bytes;
		}
	}
	
	override void loader()
	{
		auto data = _file.readln;
		auto ef = data.parse!float;
		
		uint function(ubyte[]) byteLoader;
		
		if (ef < 0)
		{
			_order = BYTE_ORDER.LITTLE_ENDIAN;
			byteLoader = &fromLEBytes;
		}
		else
		{
			_order = BYTE_ORDER.BIG_ENDIAN;
			byteLoader = &fromBEBytes;
		}
		
		float bytes2float(ubyte[] bytes)
		{
			uint tmp = byteLoader(bytes);
			float value = *(cast(float*) &tmp);
			return value;
		}
		
		auto blockSize = 3 * float.sizeof;
		auto buffer = new ubyte[_width * blockSize];
	
		foreach (i; 0.._height)
		{
			_file.rawRead!ubyte(buffer);
			
			foreach (j; 0.._width)
			{
				auto wq = buffer[(j * blockSize)..(j * blockSize + blockSize)];
				
				_image[j, _height - i] = new RGBColor(
					cast(int) (_intensity * bytes2float(wq[0..4])),
					cast(int) (_intensity * bytes2float(wq[4..8])),
					cast(int) (_intensity * bytes2float(wq[8..12]))
				);
			}
		}
	}
	
	override void saver()
	{
		ubyte[] function(uint) byteSaver;
		
		final switch (_order) with (BYTE_ORDER) {
			case LITTLE_ENDIAN:
				_file.writeln(-1.0);
				byteSaver = &toLEBytes;
				break;
			case BIG_ENDIAN:
				_file.writeln(1.0);
				byteSaver = &toBEBytes;
				break;
		}
		
		ubyte[] int2bytes(int value)
		{
			float I = float(value) / float(_intensity);
			uint tmp = *(cast(uint*) &I);
			return byteSaver(tmp);
		}
		
		foreach (i; 0.._height)
		{
			foreach (j; 0.._width)
			{
				auto color = _image[j, _height - i];
				
				_file.write(
					cast(char[]) int2bytes(color.getR),
					cast(char[]) int2bytes(color.getG),
					cast(char[]) int2bytes(color.getB)
				);
			}
		}
	}
}

/**
A constructor function that creates an image with the given length, width, and format. 
By default, all parameters are 0, and the format is represented by the PixMapFormat.PPM_BINARY value, which corresponds to an image with a P6 format.
Params:
width = Width of image as size_t value. 
height = Height of image as size_t value.
pmFormat = Image format as enum PixMapFormat

Typical usage:
----
auto img = image(20, 20, PixMapFormat.PPM_TEXT); 	// creates image with P3 format type
----
*/
PixMapFile image(size_t width = 0, size_t height = 0, PixMapFormat pmFormat = PixMapFormat.PPM_BINARY)
{
	PixMapFile pixmap;

	final switch (pmFormat) with (PixMapFormat)
	{
		case PBM_TEXT:
			pixmap = new P1Image(width, height);
			break;
		case PBM_BINARY:
			pixmap = new P4Image(width, height);
			break;
		case PGM_TEXT:
			pixmap = new P2Image(width, height);
			break;
		case PGM_BINARY:
			pixmap = new P5Image(width, height);
			break;
		case PPM_TEXT:
			pixmap = new P3Image(width, height);
			break;
		case PPM_BINARY:
			pixmap = new P6Image(width, height);
			break;
		case PF_RGB_BINARY:
			pixmap = new PFImage(width, height);
			break;
	}

	return pixmap;
}

/**
A constructor function that creates an image with the given length, width, and format. 
By default, all parameters are 0, and the format is represented by the "P6" value, which corresponds to an image with a P6 format.
Params:
width = Width of image as size_t value. 
height = Height of image as size_t value.
pmFormat = Image format as string

Typical usage:
----
auto img = image(20, 20, "P3"); 	// creates image with P3 format type
----
*/
PixMapFile image(size_t width = 0, size_t height = 0, string pmFormat = "P6")
{
	PixMapFile pixmap;

	switch (pmFormat) 
	{
		case "P1":
			pixmap = new P1Image(width, height);
			break;
		case "P4":
			pixmap = new P4Image(width, height);
			break;
		case "P2":
			pixmap = new P2Image(width, height);
			break;
		case "P5":
			pixmap = new P5Image(width, height);
			break;
		case "P3":
			pixmap = new P3Image(width, height);
			break;
		case "P6":
			pixmap = new P6Image(width, height);
			break;
		case "PF":
			pixmap = new PFImage(width, height);
			break;
		default:
			assert(0);
	}

	return pixmap;
}
