#ifndef __STDIO__
#define __STDIO__

#include "stddef.h"
typedef int FILE;

int printf(const char *format, ...);

int snprintf(char *str, size_t size, const char *format, ...);

int fprintf(FILE *stream, const char *format, ...);


#endif