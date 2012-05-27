#pragma comment(lib, "user32.lib")
#pragma comment(lib, "imagehlp.lib")
#define _ISOC99_SOURCE

// Use wchar_t
#define _UNICODE 1
#define UNICODE _UNICODE

// Speed up build process with minimal headers.
#define WIN32_LEAN_AND_MEAN
#define VC_EXTRALEAN

#include <windows.h>
#include <imagehlp.h>
#include <stdlib.h>
#include <stdio.h>
#include <io.h>

#define ERRMSG_MAX 1280
#define SZ_EXE 16
static const wchar_t x86exe[] = L"\\x86\\depends.exe";
static const wchar_t x64exe[] = L"\\x64\\depends.exe";

BOOL MapAndLoadW(LPWSTR imgPath, PLOADED_IMAGE lpImg)
{
	wchar_t lpImgPathW[_MAX_PATH+1] = L"";
	char lpImgPathA[_MAX_PATH+1] = "",
	lpImgNameA[_MAX_PATH+1] = "",
	lpImgDirA[_MAX_PATH+1] = "";
	size_t szDllPathW;
	
	if(_wfullpath(lpImgPathW, (LPCWSTR)imgPath, _MAX_PATH) == NULL) return FALSE;
	if((szDllPathW = wcslen(lpImgPathW)) == 0) return FALSE;
	if(wcstombs(lpImgPathA, (LPCWSTR)lpImgPathW, szDllPathW) == -1) return FALSE;
	strcpy(lpImgNameA ,(LPCSTR)(strrchr(lpImgPathA, '\\') + 1));
	*(strrchr(lpImgPathA, '\\')) = '\0';
	strcpy(lpImgDirA, (LPCSTR)lpImgPathA);
	return MapAndLoad(lpImgNameA, lpImgDirA, lpImg, FALSE, TRUE);
}


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
	LOADED_IMAGE oImg;
	LPWSTR lpCmdLine;
	wchar_t parentDir[_MAX_PATH+1], exePath[_MAX_PATH+1] = L"", errMsg[ERRMSG_MAX];
	size_t szParentDir, szExeStr, szCmdLine;
	PROCESS_INFORMATION pi;
	STARTUPINFO si;
	int dwExitCode = 1;
	LPWSTR *argv = __wargv;
	int argc = __argc;
	
	// Zero out our loaded image struct.
	ZeroMemory(&oImg, sizeof(oImg));
	
	/* Make sure we have args. */
	if(argc == 1) {
		swprintf(errMsg, ERRMSG_MAX, L"No images specified.\n");
		MessageBoxW(NULL, errMsg, L"Error", MB_OK | MB_ICONERROR);
		return dwExitCode;
	}
	
	/* Get our exe's parent folder. */
	if(!GetParentDir(parentDir, &szParentDir)) {
		wsprintf(L"Could not get parent folder of image, \"%s\". This should not happen ever.\n", argv[0]);
		MessageBoxW(NULL, errMsg, L"Error", MB_OK | MB_ICONERROR);
		return dwExitCode;
	}
	
	/* Calculate the length of the eventual exe path with surrounding quotes. */
	szExeStr = szParentDir + SZ_EXE + 2; // +2 for the two "s surrounding the image path.
	
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
		if(!MapAndLoadW(argv[i], &oImg)) {
			swprintf(errMsg, ERRMSG_MAX, L"Unable to get binary type for image.\nImage: %s\n", argv[i]);
			MessageBoxW(NULL, errMsg, L"Error", MB_OK | MB_ICONERROR);
			return dwExitCode;
		}
		
		wcscpy(exePath, parentDir);
		switch(oImg.FileHeader->FileHeader.Machine)
		{
			case IMAGE_FILE_MACHINE_I386:
				wcscat(exePath, x86exe);
				break;
			// TODO: Differentiate between x64 platforms.
			case IMAGE_FILE_MACHINE_AMD64:
			case IMAGE_FILE_MACHINE_IA64:
				wcscat(exePath, x64exe);
				break;
			default:
				swprintf(errMsg, ERRMSG_MAX, L"Unknown binary type returned for image.\nImage: %s\n\nBinary Type: %d", argv[i], oImg.FileHeader->FileHeader.Machine);
				MessageBoxW(NULL, errMsg, L"Error", MB_OK | MB_ICONERROR);
				return dwExitCode;
		}

		if(!UnMapAndLoad(&oImg)) {
			swprintf(errMsg, ERRMSG_MAX, L"Failed to unload/unmap image.\nImage: %s\n", argv[i]);
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