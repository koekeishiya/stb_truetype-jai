#ifdef WIN32
#define __EXPORT __declspec(dllexport)
#else
#define __EXPORT
#endif

#define STBTT_DEF extern __EXPORT

#define STB_TRUETYPE_IMPLEMENTATION
#include "stb_truetype.h"
