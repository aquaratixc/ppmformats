
private
{
	template addProperty(T, string propertyName)
	{
		import std.string : format, toLower;
	 
		const char[] addProperty = format(
			`
			private %2$s %1$s;
	 
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
			propertyName
			);
	}

	auto EnumValue(E)(E e) 
		if(is(E == enum)) 
	{
		import std.traits : OriginalType;
		OriginalType!E tmp = e;
		return tmp; 
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

	alias luminance = luminance709;

	override string toString()
	{
		import std.string : format;
		
		return format("RGBColor(%d, %d, %d, I = %f)", _r, _g, _b, this.luminance);
	}

	RGBColor opBinary(string op, T)(T rhs)
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

class AnyMapImage
{
	mixin(addProperty!(int, "Width"));
	mixin(addProperty!(int, "Height"));
	
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

	this(int width, int height, RGBColor color = new RGBColor(0, 0, 0))
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
}


enum AnyMapFormat : string
{
	PBM_TEXT 	= 	"P1",
	PBM_BINARY 	=  	"P4",
	PGM_TEXT 	= 	"P2",
	PGM_BINARY	=	"P5",
	PPM_TEXT	=	"P3",
	PPM_BINARY	= 	"P6",
}

abstract class ImageFile
{
	protected
	{
		AnyMapImage _image;
		AnyMapFormat _header;
	}

	abstract void load(string filename);
	abstract void save(string filename);	

}

class P6Image : ImageFile
{
	
	this(int width, int height, RGBColor color = new RGBColor(0, 0, 0))
	{
		_image = new AnyMapImage(width, height, color);
		_header = AnyMapFormat.PPM_BINARY;	
	}

	override void load(string filename)
	{
		import std.conv;
		import std.stdio;
		import std.string;

		File file;

		with (file)
		{
			open(filename, "r");

			if (readln.strip == EnumValue(_header))
			{
				auto imageSize = readln.split;
				auto width = imageSize[0].parse!int;
				auto height = imageSize[1].parse!int;

				_image = new AnyMapImage(width, height);
				auto buffer = new ubyte[width * 3];

				readln;

				for (uint i = 0; i < height; i++)
				{
					file.rawRead!ubyte(buffer);
				
					for (uint j = 0; j < width; j++)
					{
							_image[j, i] = new RGBColor(
										buffer[j * 3],
										buffer[j * 3 + 1],
										buffer[j * 3 + 2] 
									);
					}
				}
				
			}
		}
	}

	override void save(string filename)
	{
		import std.conv;
		import std.stdio;
		import std.string;
		
		File file;
				
		with (file)
		{
			enum MAXIMAL_LUMINANCE = 255;
			open(filename, "w");
			writeln(EnumValue(_header));
			writeln(_image.getWidth, " ", _image.getHeight);
			writeln(MAXIMAL_LUMINANCE);
				
			foreach (i; 0.._image.getHeight)
			{
				foreach (j; 0.._image.getWidth)
				{
					auto currentColor = _image[j, i];
					file.write(
						 cast(char) currentColor.getR,
						 cast(char) currentColor.getG,
						 cast(char) currentColor.getB,
								);
				}
			}				
	    }		
	}

	alias _image this;
}  
