module ppmformats;

private
{
	import std.conv;
	import std.stdio;
	import std.string;
	
	template addProperty(T, string propertyName, string defaultValue = T.init.to!string)
	{
		import std.string : format, toLower;
	 
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

	auto EnumValue(E)(E e) 
		if(is(E == enum)) 
	{
		import std.traits : OriginalType;
		OriginalType!E tmp = e;
		return tmp; 
	}
	
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

class RGBColor
{
	mixin(addProperty!(int, "R"));
	mixin(addProperty!(int, "G"));
	mixin(addProperty!(int, "B"));

	this(int R = 0, int G = 0, int B = 0)
	{
		this._r = R;
		this._g = G;
		this._b = B;
	}

	const float luminance709()
	{
	   return (_r  * 0.2126f + _g  * 0.7152f + _b  * 0.0722f);
	}
	
	const float luminance601()
	{
	   return (_r * 0.3f + _g * 0.59f + _b * 0.11f);
	}
	
	const float luminanceAverage()
	{
	   return (_r + _g + _b) / 3.0;
	}

	alias luminance = luminance709;

	override string toString()
	{
		import std.string : format;
		
		return format("RGBColor(%d, %d, %d, I = %f)", _r, _g, _b, this.luminance);
	}

	RGBColor opBinary(string op, T)(auto ref T rhs)
	{
		import std.algorithm : clamp;
		import std.string : format;

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

	RGBColor opBinary(string op)(RGBColor rhs)
	{
		import std.algorithm : clamp;
		import std.string : format;

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

class PixMapImage
{
	mixin(addProperty!(size_t, "Width"));
	mixin(addProperty!(size_t, "Height"));
	
	private
	{
		RGBColor[] _image;

		import std.algorithm : clamp;

		auto actualIndex(size_t i)
		{
			auto S = _width * _height;
		
			return clamp(i, 0, S);
		}

		auto actualIndex(size_t i, size_t j)
		{
			auto W = cast(size_t) clamp(i, 0, _width - 1);
			auto H = cast(size_t) clamp(j, 0, _height - 1);
			auto S = _width * _height;
		
			return clamp(W + H * _width, 0, S);
		}
	}

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

	RGBColor opIndexAssign(RGBColor color, size_t x, size_t y)
	{
		_image[actualIndex(x, y)] = color;
		return color;
	}

	RGBColor opIndexAssign(RGBColor color, size_t x)
	{
		_image[actualIndex(x)] = color;
		return color;
	}

	RGBColor opIndex(size_t x, size_t y)
	{
		return _image[actualIndex(x, y)];
	}

	RGBColor opIndex(size_t x)
	{
		return _image[actualIndex(x)];
	}

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

	alias width = getWidth;
	alias height = getHeight;

	final RGBColor[] array()
	{
		return _image;
	}

	// experimental feature (!)
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


enum PixMapFormat : string
{
	PBM_TEXT 	= 	"P1",
	PBM_BINARY 	=  	"P4",
	PGM_TEXT 	= 	"P2",
	PGM_BINARY	=	"P5",
	PPM_TEXT	=	"P3",
	PPM_BINARY	= 	"P6",
}

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
		// set i/o mode (actual for windows system)
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

	final bool isBinaryFormat()
	{
		return 
				( 
				  (_header == PixMapFormat.PBM_BINARY) |
				  (_header == PixMapFormat.PGM_BINARY) |
				  (_header == PixMapFormat.PPM_BINARY)
				);
	}

	final bool isTextFormat()
	{
		return 
				( 
				  (_header == PixMapFormat.PBM_TEXT) |
				  (_header == PixMapFormat.PGM_TEXT) |
				  (_header == PixMapFormat.PPM_TEXT)
				);
	}	

	final PixMapImage image() 
	{ 
		return _image; 
	}

	alias image this;
}


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
		 	auto row  = line.replace(" ", "");
		
		 	foreach (i, e; row)
		 	{
		 		_image[i, index] = (e.to!string == "0") ? BLACK : WHITE;  						
		 	}					
		 	index++;
		 }					
	}

	override void saver()
	{
		import std.algorithm;
		import std.range : chunks;
		
		foreach (rows; _image.array.chunks(_image.width))
		{
		 	_file.writeln(
		 		rows
		 			.map!(a => (a.luminance < 255) ? "0" : "1")
		 			.join("")
		 	);
		}
	}
}


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

	    import std.algorithm;
	    import std.range : chunks;
	    		
	   	foreach (rows; _image.array.chunks(_image.width))
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

	override void loader()
	{
		auto imageSize = width * height;
		auto buffer = new ubyte[imageSize];
		_file.rawRead!ubyte(buffer);

		int index;

		auto BLACK = new RGBColor(0, 0, 0);
		auto WHITE = new RGBColor(255, 255, 255);

		foreach (e; buffer)
		{
			if (index < imageSize)
			{
				foreach (i; 0..8)
				{
					auto I = getBit(cast(int) e, i);
					//_image[index] = (I == 0) ? BLACK : WHITE;
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
		int[] bytes;
		bytes ~= new int[width * height];
		
		while ((bytes.length % 8) != 0)
		{
			bytes ~= 0;
		}

		int bytesCount;
		int shiftCount;

		foreach (e; _image.array)
		{
			// auto I = (e.luminance == 0) ? 0 : 1;
			auto I = (e.luminance) ? 0 : 1;
			auto currentByte = bytes[bytesCount];
			
			if (I == 0)
			{
				currentByte = clearBit(currentByte, shiftCount);
			}
			else
			{
				currentByte = setBit(currentByte, shiftCount);
			}
			bytes[bytesCount] = currentByte;
			shiftCount++;
			
			if (shiftCount > 7)
			{
				shiftCount = 0;
				bytesCount++;
			}
		}

		foreach (e; bytes)
		{
			_file.write(
				cast(char) e
			);
		}
	}
}


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
	}

	return pixmap;
}

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
		default:
			assert(0);
	}

	return pixmap;
}


