// TODO: Remove dependency on imagehlp by parsing the PE header myself
#pragma comment(lib, "Imagehlp.lib")

// Suppress warnings
#ifndef _CRT_SECURE_NO_WARNINGS
#	define _CRT_SECURE_NO_WARNINGS
#endif

// Use wchar_t
#ifdef _MBCS
#	undef MBCS
#endif

#ifndef _UNICODE
#	define _UNICODE 1
#endif

#ifndef UNICODE
#	define UNICODE _UNICODE
#endif

#if defined(_M_IA64)
#	define BUILD_ARCH_IA64
#elif (defined(_M_AMD64) || defined(_WIN64))
#	define BUILD_ARCH_AMD64
#elif defined(_M_IX86)
#	define BUILD_ARCH_X86
#endif

// Speed up build process with minimal headers.
#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN

#include <windows.h>
#include <imagehlp.h>
#include <winnt.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <errno.h>
#include <string.h>
#include <assert.h>

#include <io.h>

#ifndef MAX_PATH
#	define MAX_PATH _MAX_PATH
#endif

#ifdef inline
#	undef inline
#endif

#ifdef INLINE
#	undef INLINE
#endif
#define inline __forceinline

#define INLINE inline
#define STATIC static

#define SIZEOF_EXE (sizeof("depends.exe") - 1)
#define SIZEOF_EXE_X86 ( SIZEOF_EXE + sizeof("\\x86") - 1 )
#define SIZEOF_EXE_IA64 ( SIZEOF_EXE + sizeof("\\ia64") - 1 )
#define SIZEOF_EXE_AMD64 ( SIZEOF_EXE + sizeof("\\amd64") - 1 )

STATIC CONST WCHAR depsexe[] = L"\\depends.exe";

STATIC CONST WCHAR x86exe[] = L"\\x86";
STATIC CONST WCHAR amd64exe[] = L"\\amd64";
STATIC CONST WCHAR ia64exe[] = L"\\ia64";

STATIC VOID ShowErrorMessage(DWORD dwError, LPCWSTR message, ...);

#define Fatal(dwError,...) \
	do { \
		ShowErrorMessage(dwError, __VA_ARGS__ ); \
		ExitProcess(dwError); \
	} while(0)

STATIC INT DynMessageBoxW(HWND hwnd, LPCWSTR lpText, LPCWSTR lpCaption, UINT uType)
{
	STATIC INT(WINAPI* MessageBoxW_Proc)(HWND hwnd, LPCWSTR lpText, LPCWSTR lpCaption, UINT uType) = NULL;
	if(MessageBoxW_Proc == NULL) {
		HMODULE hUser32 = LoadLibraryW(L"user32.dll");
		assert(hUser32 != NULL);
		*((FARPROC*)(&MessageBoxW_Proc)) = GetProcAddress(hUser32, "MessageBoxW");
		if(MessageBoxW_Proc == NULL) {
			abort();
		}
	}
	return MessageBoxW_Proc(hwnd, lpText, lpCaption, uType);
}

STATIC LPWSTR vswprintf_allocl(LPCWSTR prefix, LPCWSTR format, va_list args)
{
	SIZE_T szCount = 0, szPrefix = 0;
	LPWSTR lpWorking = NULL, lpResult = NULL;
	va_list argscopy;
	
	// Check the resulting size of the buffer.
	va_copy(argscopy, args);
	szCount = (SIZE_T)_vscwprintf(format, argscopy) + 1;
	va_end(argscopy);
	
	// Add additional space for the prefix
	if(prefix != NULL) {
		szPrefix = (SIZE_T)lstrlenW(prefix);
		szCount += szPrefix;
	}
	
	// Allocate our buffer.
	lpResult = (LPWSTR)LocalAlloc(LPTR, szCount * sizeof(WCHAR));
	if(lpResult == NULL) {
		return NULL;
	}

	// Finally, fill in the message.
	lstrcpynW(lpResult, prefix, (int)szPrefix + 1);
	lpWorking = lpResult + szPrefix;
	_vsnwprintf(lpWorking, szCount - szPrefix, format, args);
	return lpResult;
}

STATIC LPWSTR wsprintf_alloc(LPCWSTR prefix, LPCWSTR format, ...)
{
	LPWSTR lpResult = NULL;
	va_list args;
	va_start(args, format);
	lpResult = vswprintf_allocl(prefix, format, args);
	va_end(args);
	return lpResult;
}

STATIC INLINE VOID FatalCall(LPCWSTR pName)
{
	Fatal(ERROR_SUCCESS, pName);
}

STATIC VOID ShowErrorMessage(DWORD dwError, LPCWSTR message, ...)
{
	LPVOID lpMsgBuf = NULL, lpDisplayBuf = NULL;
	if(dwError == 0) {
		// If no return code was specified, we assume that the message
		// contains a function name that failed. In that case, we retrieve
		// the system error message for the last-error code
		dwError = GetLastError();
		
		FormatMessage(
			FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |FORMAT_MESSAGE_IGNORE_INSERTS,
			NULL,
			dwError,
			MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
			(wchar_t*) &lpMsgBuf,
			0,
			NULL
		);

		// Allocate our buffer for the error message.
		lpDisplayBuf = (void*)LocalAlloc(
			LMEM_ZEROINIT,
			(lstrlenW((const wchar_t*)lpMsgBuf) + lstrlenW((const wchar_t*)message) + 47) * sizeof(wchar_t)
		);
		_snwprintf(
			(wchar_t*)lpDisplayBuf,
			LocalSize(lpDisplayBuf) / sizeof(wchar_t),
			L"FATAL: %s failed with error %d: %s",
			message,
			dwError,
			(LPWSTR)lpMsgBuf
		);
	} else {
		// Otherwise, we assume that the error message is a format string.
		va_list args;
		va_start(args, message);
		lpDisplayBuf = (LPVOID)vswprintf_allocl(L"FATAL: ", message, args);
		va_end(args);
	}
	
	DynMessageBoxW(NULL, (LPCWSTR)lpDisplayBuf, L"Fatal Error", MB_OK | MB_ICONERROR);
	if(lpMsgBuf != NULL) LocalFree(lpMsgBuf);
	LocalFree(lpDisplayBuf);
}

STATIC INLINE VOID DebugMessage(LPCWSTR message, ...)
{
	LPWSTR lpDisplayBuf = NULL;
	va_list args;
	va_start(args, message);
	lpDisplayBuf = vswprintf_allocl(NULL, message, args);
	va_end(args);
	
	DynMessageBoxW(NULL, (LPCWSTR)lpDisplayBuf, L"Debug Message", MB_OK | MB_ICONINFORMATION);
	LocalFree(lpDisplayBuf);
}

STATIC BOOL MapAndLoadW(LPWSTR imgPath, PLOADED_IMAGE lpImg)
{
	wchar_t lpImgPathW[MAX_PATH+1] = L"";
	char lpImgPathA[MAX_PATH+1] = "",
	lpImgNameA[MAX_PATH+1] = "",
	lpImgDirA[MAX_PATH+1] = "";
	size_t szDllPathW;

	if(_wfullpath(lpImgPathW, (LPCWSTR)imgPath, MAX_PATH) == NULL) return FALSE;
	if((szDllPathW = wcslen(lpImgPathW)) == 0) return FALSE;
	if(wcstombs(lpImgPathA, (LPCWSTR)lpImgPathW, szDllPathW) == -1) return FALSE;
	strcpy(lpImgNameA ,(LPCSTR)(strrchr(lpImgPathA, '\\') + 1));
	*(strrchr(lpImgPathA, '\\')) = '\0';
	strcpy(lpImgDirA, (LPCSTR)lpImgPathA);
	return MapAndLoad(lpImgNameA, lpImgDirA, lpImg, FALSE, TRUE);
}

STATIC BOOL GetParentDir(LPWSTR lpDirBuffer, SIZE_T* lpszParentDir)
{
	WCHAR modulePath[MAX_PATH + 1] = L"";
	SIZE_T bufferLen = *lpszParentDir;
	*lpszParentDir = (SIZE_T)GetModuleFileNameW(NULL, modulePath, MAX_PATH);
	if(*lpszParentDir == 0) return FALSE;
	while(modulePath[--*lpszParentDir] != L'\\' && *lpszParentDir) modulePath[*lpszParentDir] = L'\0';
	if( (*lpszParentDir == 0) || (++*lpszParentDir > bufferLen) ) return FALSE;
	return lstrcpynW(lpDirBuffer, modulePath, *lpszParentDir) != NULL;
}

int WINAPI wWinMain(HINSTANCE hInstance,
	HINSTANCE hPrevInstance,
	LPWSTR lpOriginalCmdLine,
	int nCmdShow)
{
	SIZE_T szParentDir = MAX_PATH+1;
	WCHAR parentDir[MAX_PATH+1] = L"";
	
	// Already dependent on msvcrt - might as well use this instead of CommandLineToArgvW
	int i, argc = __argc;
	LPWSTR *wargv = __wargv;
	
	DebugMessage(L"lpOriginalCmdLine = %s", lpOriginalCmdLine);
	
	/* Make sure we have args. */
	if(argc == 1) {
		Fatal(ERROR_INVALID_FUNCTION, L"No images specified.");
	}
	
	
	/* Get our exe's parent folder. */
	if(!GetParentDir(parentDir, &szParentDir)) {
		Fatal(ERROR_PATH_NOT_FOUND, L"Could not get parent folder of image, \"%s\". This should not happen ever.", wargv[0]);
	}
	
	
	DebugMessage(L"%s (%zu chars)", parentDir, szParentDir);

	/* Iterate through our arguments */
	for(i = 1; i < argc; i++) {
		LPWSTR lpCmdLine;
		LOADED_IMAGE oImg = {0};
		WCHAR exePath[MAX_PATH+1] = L"";
		PROCESS_INFORMATION pi = { NULL };
		STARTUPINFO si = { sizeof(si), NULL };
		SIZE_T szExeStr, szCmdLine, szPlatExe;
		
		/* Verify file exists. */
		if(_waccess(wargv[i], 0) == -1) {
			ShowErrorMessage(ERROR_FILE_NOT_FOUND, L"File does not exist.\nFile: %s", wargv[i]);
			continue;
		}

		/* Get the binary type. */
		if(!MapAndLoadW(wargv[i], &oImg)) {
			ShowErrorMessage(GetLastError(), L"Unable to get binary type for image.\nImage: %s", wargv[i]);
			continue;
		}

		lstrcpyW(exePath, parentDir);
		switch(oImg.FileHeader->FileHeader.Machine)
		{
			case IMAGE_FILE_MACHINE_I386:
				lstrcatW(exePath, x86exe);
				szPlatExe = SIZEOF_EXE_X86;
				break;
			// TODO: Differentiate between x64 platforms.
			case IMAGE_FILE_MACHINE_AMD64:
				lstrcatW(exePath, amd64exe);
				szPlatExe = SIZEOF_EXE_AMD64;
				break;
			case IMAGE_FILE_MACHINE_IA64:
				lstrcatW(exePath, ia64exe);
				szPlatExe = SIZEOF_EXE_IA64;
				break;
			default:
				Fatal(1L, L"Unknown binary type returned for image.\nImage: %s\n\nBinary Type: %d", wargv[i], oImg.FileHeader->FileHeader.Machine);
		}

		if(!UnMapAndLoad(&oImg)) {
			ShowErrorMessage(1L, L"Failed to unload/unmap image.\nImage: %s", wargv[i]);
			continue;
		}

		// TODO: This shit never changes - should've done it in the initial scope.
		/* Calculate the length of the eventual exe path with surrounding quotes. */
		lstrcatW(exePath, depsexe);
		szExeStr = szParentDir + szPlatExe + 2; // +2 for the two "s surrounding the image path.

		/* Allocate our command line string. */
		// szExeStr+         1 +1+wcslen(wargv)+1
		// "(path)depends.exe" "wargv"
		szCmdLine = szExeStr + lstrlenW(wargv[i]) + 3;
		lpCmdLine = (LPWSTR)LocalAlloc(LPTR, sizeof(wchar_t) * (szCmdLine + 1));
		if(lpCmdLine == NULL) {
			Fatal(1L, L"Could not allocate memory.\nMemory required (bytes): %d", sizeof(wchar_t) * (szCmdLine + 1));
		}
		
		if(swprintf(lpCmdLine, szCmdLine+1, L"\"%s\" \"%s\"", exePath, wargv[i]) == -1) {
			LocalFree(lpCmdLine);
			FatalCall(L"swprintf");
		}

		ZeroMemory(&si, sizeof(si));
		si.cb = sizeof(si);
		ZeroMemory(&pi, sizeof(pi));

		/* Depends launching. */
		if (!CreateProcessW(
			NULL,		/* No module name (use command line) */
			lpCmdLine,	/* Command line */
			NULL,		/* Process handle not inheritable */
			NULL,		/* Thread handle not inheritable */
			FALSE,		/* Set handle inheritance to FALSE */
			0,			/* No creation flags */
			NULL,		/* Use parent's environment block */
			NULL,		/* Use parent's starting directory */
			&si,		/* Pointer to STARTUPINFO structure */
			&pi			/* Pointer to PROCESS_INFORMATION structure */
		)) {
			// len("CreateProcessW") + len(" - ") + len(cmdline)
			szCmdLine += 17;
			LocalFree(lpCmdLine);
			lpCmdLine = (LPWSTR)LocalAlloc(LPTR, sizeof(wchar_t) * (szCmdLine + 1));
			swprintf(lpCmdLine, szCmdLine+1, L"CreateProcessW - \"%s\" \"%s\"", exePath, wargv[i]);
			FatalCall(lpCmdLine);
		}
		LocalFree(lpCmdLine);
	}
	return 0;
}
