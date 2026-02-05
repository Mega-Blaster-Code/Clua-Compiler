#ifndef __FILE_READER_H
#define __FILE_READER_H
#include <stdio.h>
#include <stdlib.h>

#ifndef __FILE_READER_FR_MODES
#define __FILE_READER_FR_MODES

#define FR_READ "r"
#define FR_READ_BINARY "rb"

#define FR_READ_WRITE "r+"
#define FR_READ_WRITE_BINARY "rb+"

#define FR_WRITE "w"
#define FR_WRITE_BINARY "wb"
#define FR_WRITE_READ "w+"
#define FR_WRITE_READ_BINARY "wb+"

#define FR_APPEND "a"
#define FR_APPEND_READ "a+"
#define FR_APPEND_BINARY "ab"
#define FR_APPEND_READ_BINARY "ab+"

#endif

char *FRread(const char *file_path, const char *mode, size_t *size);

#endif