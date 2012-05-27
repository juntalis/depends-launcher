#pragma comment(lib, "user32.lib")
#define _ISOC99_SOURCE

// Use wchar_t
#define _UNICODE 1
#define UNICODE _UNICODE

// Speed up build process with minimal headers.
#define WIN32_LEAN_AND_MEAN
#define VC_EXTRALEAN

#include <windows.h>
#include <stdlib.h>
#include <stdio.h>
#include <io.h>

#define ERRMSG_MAX 1280
#define SZ_EXE 16
static const wchar_t x86exe[] = L"\\x86\\depends.exe";
static const wchar_t x64exe[] = L"\\x64\\depends.exe";


BOOL GetParentDir(LPWSTR parentDir, size_t* lpszParentDir)
{
	wchar_t exePath[_MAX_PATH + 1] = L"";
	if(!GetModuleFileNameW(NULL, exePath, _MAX_PATH)) return FALSE;
	*(wcsrchr(exePath, L'\\')) = L'\0';
	if((*lpszParentDir = wcslen(exePath)) == 0) return FALSE;
	return (wcscpy_s(parentDir, _MAX_PATH, exePath) != -1);
}

int WINAPI wWinMain(HINSTANCE hInstance,
	HINSTANCE hPrevInstance,
	LPWSTR lpOriginalCmdLine,
	int nCmdShow)
{
	int i;
	DWORD lpBinaryType;
	LPWSTR lpCmdLine;
	wchar_t parentDir[_MAX_PATH+1], exePath[_MAX_PATH+1] = L"", errMsg[ERRMSG_MAX];
	size_t szParentDir, szExeStr, szCmdLine;
	PROCESS_INFORMATION pi;
	STARTUPINFO si;
	int dwExitCode = 1;
	LPWSTR *argv = __wargv;
	int argc = __argc;
	
	/* Make sure we have args. */
	if(argc == 1) {
		swprintf(errMsg, ERRMSG_MAX, L"No executables specified.\n");
		MessageBoxW(NULL, errMsg, L"Error", MB_OK | MB_ICONERROR);
		return dwExitCode;
	}
	
	/* Get our exe's parent folder. */
	if(!GetParentDir(parentDir, &szParentDir)) {
		wsprintf(L"Could not get parent folder of executable, \"%s\". This should not happen ever.\n", argv[0]);
		MessageBoxW(NULL, errMsg, L"Error", MB_OK | MB_ICONERROR);
		return dwExitCode;
	}
	
	/* Calculate the length of the eventual exe path with surrounding quotes. */
	szExeStr = szParentDir + SZ_EXE + 2; // +2 for the two "s surrounding the executable path.
	
	/* Iterate through our arguments */
	for(i = 1; i < argc; i++) {
		dwExitCode = 1;
		
		/* Verify file exists. */
		if(_waccess(argv[i], 00) == -1) {
			swprintf(errMsg, ERRMSG_MAX, L"File does not exist.\nFile: %s\n", argv[i]);
			MessageBoxW(NULL, errMsg, L"Error", MB_OK | MB_ICONERROR);
			return dwExitCode;
		}
		
		/* Get the binary type. */
		if(!GetBinaryType((LPCWSTR)argv[i], &lpBinaryType)) {
			swprintf(errMsg, ERRMSG_MAX, L"Unable to get binary type for executable.\nExecutable: %s\n", argv[i]);
			MessageBoxW(NULL, errMsg, L"Error", MB_OK | MB_ICONERROR);
			return dwExitCode;
		}
		
		/* Construct our exe path. */
		wcscpy(exePath, parentDir);
		if(lpBinaryType == SCS_32BIT_BINARY) {
			wcscat(exePath, x86exe);
		} else if(lpBinaryType == SCS_64BIT_BINARY) {
			wcscat(exePath, x64exe);
		} else {
			swprintf(errMsg, ERRMSG_MAX, L"Unknown binary type returned for executable.\nExecutable: %s\n\nBinary Type: %d", argv[i], lpBinaryType);
			MessageBoxW(NULL, errMsg, L"Error", MB_OK | MB_ICONERROR);
			return dwExitCode;
		}
		
		/* Allocate our command line string. */
		// szExeStr+         1 +1+wcslen(argv)+1
		// "(path)depends.exe" "argv"
		szCmdLine = szExeStr + wcslen(argv[i]) + 3;
		lpCmdLine = (LPWSTR)malloc(sizeof(wchar_t) * (szCmdLine + 1));
		if(lpCmdLine == NULL) {
			swprintf(errMsg, ERRMSG_MAX, L"Could not allocate memory.\nMemory required (bytes): %d\n", sizeof(wchar_t) * (szCmdLine + 1));
			MessageBoxW(NULL, errMsg, L"Error", MB_OK | MB_ICONERROR);
			return dwExitCode;
		}
		if(swprintf(lpCmdLine, szCmdLine+1, L"\"%s\" \"%s\"", exePath, argv[i]) == -1) {
			swprintf(errMsg, ERRMSG_MAX, L"Cant sprintf.\n");
			MessageBoxW(NULL, errMsg, L"Error", MB_OK | MB_ICONERROR);
			return dwExitCode;
		}
		
		ZeroMemory(&si, sizeof(si));
		si.cb = sizeof(si);
		ZeroMemory(&pi, sizeof(pi));
		
		/* Depends launching. */
		if (!CreateProcess(
			NULL,	/* No module name (use command line) */
			lpCmdLine,	/* Command line */
			NULL,	/* Process handle not inheritable */
			NULL,	/* Thread handle not inheritable */
			FALSE,	/* Set handle inheritance to FALSE */
			0,	/* No creation flags */
			NULL,	/* Use parent's environment block */
			NULL,	/* Use parent's starting directory */
			&si,	/* Pointer to STARTUPINFO structure */
			&pi	/* Pointer to PROCESS_INFORMATION structure */
		)) {
			swprintf(errMsg, ERRMSG_MAX, L"Failed to run.\nCommand Line: %s\n", lpCmdLine);
			MessageBoxW(NULL, errMsg, L"Error", MB_OK | MB_ICONERROR);
			return dwExitCode;
		}
		dwExitCode = 0;
		free(lpCmdLine);
	}
	return dwExitCode;
}