/*
============================================================================
= Sobel.c implements the Edge Detection with Sobel Algorithm               =
= ------------------------------------------------------------------------ =
= Inputs (both inputs are hardwired in the source code):                   =
=   - Image: file bmp image                                                =
=   - Desired Threshold: T, integer from 0 to 255                          =
= Output:                                                                  =
=   - Image with Edges Detected: "Output_Sobel_<T>.bmp"                    =
= Run:                                                                     =
=  copy-paste the input image.bmp to _project_name_/_project_name_ folder  =
=  same folder where the .cpp file is located                              =
============================================================================
*/
#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS
#endif

#include <cmath>
#include <string>
#include <cerrno>
#include <sstream>
#include <cstdlib>
#include <fstream>
#include <iostream>

// Input threshold for Sobel Operator.
#define THRESHOLD	90

// BMP file header.
typedef struct tagBitmapFileHeader {
#pragma pack(push, 1)
	unsigned short bfType;
	unsigned int bfSize;
	unsigned short bfReserved1;
	unsigned short bfReserved2;
	unsigned int bfOffBits;
#pragma pack(pop)
} BitmapFileHeader;

// BMP extra file header.
typedef struct tagBitmapInfoHeader {
#pragma pack(push, 1)
	unsigned int biSize;
	int biWidth;
	int biHeight;
	unsigned short biPlanes;
	unsigned short biBitCount;
	unsigned int biCompression;
	unsigned int biSizeImage;
	int biXPelsPerMeter;
	int biYPelsPerMeter;
	unsigned int biClrUsed;
	unsigned int biClrImportant;
#pragma pack(pop)
} BitmapInfoHeader;

// Colormap entry structure.
typedef struct {
	unsigned char  rgbBlue;
	unsigned char  rgbGreen;
	unsigned char  rgbRed;
	unsigned char  rgbReserved;
} RGBQuad;

// Image as input; just use a big table to store the colors
RGBQuad image[2048][2048];
// To store the annotations (output) of the edge detection 
unsigned char ee_image[2048][2048];
// To hold the Grayscale image
int gray_image[2048][2048];

// the following functions must be implemented in assembly
extern "C" int bmptogray_conversion(int, int, RGBQuad input_color[2048][2048], int output_gray[2048][2048]);   // first function to be implemented in assembly 
extern "C" int sobel_detection(int, int, int input_gray_image[2048][2048], unsigned char output_ee_image[2048][2048], double threshold); // second function to be implemented in assembly 
extern "C" int border_pixel_calculation(int, int, unsigned char ee_image[2048][2048]);  // third  function to be implemented in assembly 


int main(int argc, char* argv[])
{
	std::ifstream inputBitmapStream;
	std::ofstream outputBitmapStream;

	unsigned int width, height;
	unsigned int x, y;

	BitmapFileHeader bmfh;
	BitmapInfoHeader bmih;


	// Opening the file: using "rb" mode to read this *binary* file

	inputBitmapStream.open("input.bmp", std::ios::binary);

	if (!inputBitmapStream.is_open())
	{
		std::cerr << "File Error: Bitmap input image not found." << std::endl;
		return EXIT_FAILURE;
	}

	std::cout << "File opened" << std::endl;
	// Reading the file header and any following bitmap information...
	inputBitmapStream.read(reinterpret_cast<char*>(&bmfh), sizeof(BitmapFileHeader));
	inputBitmapStream.read(reinterpret_cast<char*>(&bmih), sizeof(BitmapInfoHeader));

	printf("Header Info\n");
	printf("--------------------\n");
	printf("Size:%i\n", bmfh.bfSize);
	printf("Offset:%i\n", bmfh.bfOffBits);
	printf("--------------------\n");
	printf("Size:%i\n", bmih.biSize);
	printf("biWidth:%i\n", bmih.biWidth);
	printf("biHeight:%i\n", bmih.biHeight);
	printf("biPlanes:%i\n", bmih.biPlanes);
	printf("biBitCount:%i\n", bmih.biBitCount);
	printf("biCompression:%i\n", bmih.biCompression);
	printf("biSizeImage:%i\n", bmih.biSizeImage);
	printf("biXPelsPerMeter:%i\n", bmih.biXPelsPerMeter);
	printf("biYPelsPerMeter:%i\n", bmih.biYPelsPerMeter);
	printf("biClrUsed:%i\n", bmih.biClrUsed);
	printf("biClrImportant:%i\n", bmih.biClrImportant);
	printf("--------------------\n");


	// Extract the width & height from bmp header info.
	width = bmih.biWidth; if (width % 4 != 0) width += (4 - width % 4);
	height = bmih.biHeight;


	// Reading the pixels of input image.
	for (y = 0; y < height; y++)
	{
		for (x = 0; x < width; x++)
		{
			image[x][y].rgbBlue = inputBitmapStream.get();
			image[x][y].rgbGreen = inputBitmapStream.get();
			image[x][y].rgbRed = inputBitmapStream.get();
		}
	}

	inputBitmapStream.close();

	// Not really necessary.
	memset(gray_image, 0, width * height * sizeof(int));

	// Converting the input RGB bmp to grayscale image (not black and white).
	bmptogray_conversion(height, width, image, gray_image);

	// Edge Detection with Sobel Operator.
	sobel_detection(height, width, gray_image, ee_image, (double)THRESHOLD);

	// Calculating the border pixels with replication.
	border_pixel_calculation(height, width, ee_image);

	printf("The edges of the image have been detected with Sobel and a Threshold: %d\n", THRESHOLD);

	//-------------------------------------------------------------
	// Creating the final image in (pseudo)bmp format 
	//-------------------------------------------------------------

	// Constructing output image name
	std::ostringstream outputFileNameBuffer;
	// Converting input threshold to string
	outputFileNameBuffer << "Output_Sobel_" << THRESHOLD << ".bmp";
	// Writing new image.
	outputBitmapStream.open(outputFileNameBuffer.str(), std::ios::binary);

	// Write the file and the bmp information to the file.
	outputBitmapStream.write(reinterpret_cast<const char*>(&bmfh), sizeof(BitmapFileHeader));
	outputBitmapStream.write(reinterpret_cast<const char*>(&bmih), sizeof(BitmapInfoHeader));

	// Write the Sobel annotations pixel-by-pixel.
	for (y = 0; y < height; y++)
	{
		for (x = 0; x < width; x++)
		{
			// Write the same value in all RGB channels.
			outputBitmapStream.put(ee_image[x][y]);
			outputBitmapStream.put(ee_image[x][y]);
			outputBitmapStream.put(ee_image[x][y]);
		}
	}

	// Deallocate Resources
	outputBitmapStream.close();



	return EXIT_SUCCESS;
}
