#include <stdio.h>
#include <stdlib.h>
#include "filereader.h"

char *FRread(const char *file_path, const char *mode, size_t *size){
	FILE *file_ptr = fopen(file_path, mode);
	if(file_ptr == NULL){
		return NULL;
	}

	if (fseek(file_ptr, 0, SEEK_END) != 0) {
        fclose(file_ptr);
        return NULL;
    }

	long file_size = ftell(file_ptr);
    if (file_size < 0) {
        fclose(file_ptr);
        return NULL;
    }
	
	rewind(file_ptr);

	char *buffer = malloc((size_t)file_size + 1);
    if (!buffer) {
        fclose(file_ptr);
        return NULL;
    }

    size_t read = fread(buffer, 1, (size_t)file_size, file_ptr);
    fclose(file_ptr);
	
    if (read != (size_t)file_size) {
		free(buffer);
        return NULL;
    }
	
    buffer[file_size] = '\0';
    *size = (size_t)file_size;
	
    return buffer;
}
