// Speed up build process with minimal headers.
#define WIN32_LEAN_AND_MEAN
#define VC_EXTRALEAN
#include <windows.h>
#include <stdlib.h>
#include <stdio.h>

int main()
{
	char lpExecutable[_MAX_PATH + 1];
	if(!GetModuleFileNameA(NULL, lpExecutable, _MAX_PATH)) return 1;
	printf("Executable: %1\n", lpExecutable);
	return 0;
}