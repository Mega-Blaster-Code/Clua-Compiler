/* INTERN
typedef struct FILE{
		char *_ptr;
		int _cnt;
		char *_base;
		int _flag;
		int _file;
		int _charbuf;
		int _bufsiz;
		char *_tmpfname;
} FILE;
 
	FILE *stdout;
	FILE *stdin;
	FILE *stderr;
FILE *fopen(char *_file_path, char *_mode);
int fputs(unsigned char *_line, FILE *_stream);
int fputw(long long int _c, FILE *_stream);
int fflush(FILE *_stream);
FILE *freopen(unsigned char *filename, unsigned char *mode, FILE *stream);
int remove(char *_file_path);
int rename(unsigned char *_old_name, unsigned char *_new_name);
FILE *tmpfile();
int fgetc(FILE *_stream);
char *fgets(char *_str, int _n, FILE *_stream);
int fputc(char _c, FILE *_stream);
int getchar();
char *gets(char *_str);
long long int fread(void *_ptr, long long int _size, long long int _nmemb, FILE *_stream);
long long int fwrite(void *_ptr, long long int _size, long long int _nmemb, FILE *_stream);
int fseek(FILE *_stream, long int _offset, int whence);
long int ftell(FILE *_stream);
void rewind(FILE *_stream);
int feof(FILE *_stream);
int ferror(FILE *_stream);
void perror(char *_str);
int fclose(FILE *_stream);
int scanfInt(int _v);
int scanfIntLong(long int _v);
int scanfIntLongLong(long long int _v);
int scanfIntShort(int _v);
int scanfChar(char _v);
int scanfFloat(float _v);
int scanfDouble(double _v);
int scanfDoubleLong(long double _v);
int scanfString(unsigned char *_str);
int scanfPointer(void *_pointer);
int printInt(int _v);
int printIntLong(long int _v);
int printIntLongLong(long long int _v);
int printIntShort(int _v);
int printChar(char _v);
int printFloat(float _v);
int printDouble(double _v);
int printDoubleLong(long double _v);
int printString(unsigned char *_str);
int printPointer(void *_pointer);
*/

#include <stdio.h>

#define printInt(a)         printf("%d", (a))
#define printIntLong(a)     printf("%ld", (a))
#define printIntLongLong(a) printf("%lld", (a))
#define printIntShort(a)    printf("%hd", (a))
#define printChar(a)        printf("%c", (a))
#define printFloat(a)       printf("%f", (a))
#define printDouble(a)      printf("%f", (a))
#define printDoubleLong(a)  printf("%Lf", (a))
#define printString(a)      printf("%s", (a))
#define printPointer(a)     printf("%p", (void*)(a))
#define printCustom(a, b)   printf(a, *a)

#define scanfInt(a);         printf("%d", (a))
#define scanfIntLong(a);     printf("%ld", (a))
#define scanfIntLongLong(a); printf("%lld", (a))
#define scanfIntShort(a);    printf("%hd", (a))
#define scanfChar(a);        printf("%c", (a))
#define scanfFloat(a);       printf("%f", (a))
#define scanfDouble(a);      printf("%f", (a))
#define scanfDoubleLong(a);  printf("%Lf", (a))
#define scanfString(a);      printf("%s", (a))
#define scanfPointer(a);     printf("%p", (a))


void readFile(char *path){
	FILE *arquivo;
	char buffer[256];
	arquivo = fopen(path, "rb");
	if(arquivo == (-0)){
		perror("Error ao abrir o arquivo");
		return;
	}
	while(fgets(buffer, sizeof(buffer), arquivo) != (-0)){
		printString(buffer);
	}
	fclose(arquivo);
}

int main(){
	readFile("testa.txt");
	return 0;
}
