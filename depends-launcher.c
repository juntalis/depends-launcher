#pragma comment(lib, "user32.lib")
#pragma comment(lib, "imagehlp.lib")

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

// Speed up build process with minimal headers.
#define WIN32_LEAN_AND_MEAN
#define VC_EXTRALEAN

#include <windows.h>
#include <imagehlp.h>
#include <stdlib.h>
#include <stdio.h>
#include <io.h>

#ifndef MAX_PATH
#	define MAX_PATH _MAX_PATH
#endif

#define SZ_DEPS_EXE 12
static const wchar_t depsexe[] = L"\\depends.exe";

#define SZ_86_EXE (4 + SZ_DEPS_EXE)
#define SZ_AMD_EXE (6 + SZ_DEPS_EXE)
#define SZ_IA_EXE (5 + SZ_DEPS_EXE)

static const wchar_t x86exe[] = L"\\x86";
static const wchar_t amd64exe[] = L"\\amd64";
static const wchar_t ia64exe[] = L"\\ia64";

#define FatalCall(f) Fatal(0L, f)
static void Fatal(DWORD dw, wchar_t* message, ...) 
{
	void *lpDisplayBuf, *lpMsgBuf;
	
	if(dw == 0) {
		// If no return code was specified, we assume that the message
		// contains a function name that failed. In that case, we retrieve
		// the system error message for the last-error code
		dw = GetLastError();
		
		FormatMessage(
			FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |FORMAT_MESSAGE_IGNORE_INSERTS,
			NULL,
			dw,
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
			dw,
			lpMsgBuf
		);
	} else {
		// Otherwise, we assume that the error message is a format string.
		va_list args = NULL;
		
		// Allocate buffer for our resulting format string.
		lpMsgBuf = (void*)LocalAlloc(
			LMEM_ZEROINIT,
			(lstrlenW((const wchar_t*)message) + 8) * sizeof(wchar_t)
		);
		_snwprintf(
			(wchar_t*)lpMsgBuf,
			LocalSize(lpMsgBuf) / sizeof(wchar_t),
			L"FATAL: %s",
			message
		);
		
		// Might as well use the maximum allowed buffer, since there's no way I know of the
		// get the size of the resulting buff.
		lpDisplayBuf = (void*)LocalAlloc(LMEM_ZEROINIT, 4096 * sizeof(wchar_t));
		memset(lpDisplayBuf, 0, 4096 * sizeof(wchar_t));
		va_start(args, lpMsgBuf);
		_vsnwprintf(
			(wchar_t*)lpDisplayBuf,
			4096,
			lpMsgBuf,
			args
		);
		va_end(args);
	}
	MessageBoxW(NULL, (const wchar_t*)lpDisplayBuf, L"Fatal Error", MB_OK | MB_ICONERROR);
	LocalFree(lpMsgBuf);
	LocalFree(lpDisplayBuf);
	ExitProcess(dw); 
}

BOOL MapAndLoadW(LPWSTR imgPath, PLOADED_IMAGE lpImg)
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

BOOL GetParentDir(LPWSTR parentDir, size_t* lpszParentDir)
{
	wchar_t exePath[MAX_PATH + 1] = L"";
	if(!GetModuleFileNameW(NULL, exePath, MAX_PATH)) return FALSE;
	*(wcsrchr(exePath, L'\\')) = L'\0';
	if((*lpszParentDir = lstrlenW(exePath)) == 0) return FALSE;
	return (lstrcpynW(parentDir, exePath, MAX_PATH) != -1);
}

int WINAPI wWinMain(HINSTANCE hInstance,
	HINSTANCE hPrevInstance,
	LPWSTR lpOriginalCmdLine,
	int nCmdShow)
{
	int i;
	LOADED_IMAGE oImg;
	LPWSTR lpCmdLine;
	wchar_t parentDir[MAX_PATH+1] = L"", exePath[MAX_PATH+1] = L"";
	size_t szParentDir, szExeStr, szCmdLine, szPlatExe;
	PROCESS_INFORMATION pi;
	STARTUPINFO si;
	LPWSTR *argv = __wargv;
	int argc = __argc;

	// Zero out our loaded image struct.
	ZeroMemory(&oImg, sizeof(oImg));

	/* Make sure we have args. */
	if(argc == 1) {
		Fatal(1L, L"No images specified.");
	}
	

	/* Get our exe's parent folder. */
	if(!GetParentDir(parentDir, &szParentDir)) {
		Fatal(1L, L"Could not get parent folder of image, \"%s\". This should not happen ever.", argv[0]);
	}

	/* Iterate through our arguments */
	for(i = 1; i < argc; i++) {
		/* Verify file exists. */
		if(_waccess(argv[i], 00) == -1) {
			Fatal(1L, L"File does not exist.\nFile: %s", argv[i]);
		}

		/* Get the binary type. */
		if(!MapAndLoadW(argv[i], &oImg)) {
			Fatal(1L, L"Unable to get binary type for image.\nImage: %s", argv[i]);
		}

		lstrcpyW(exePath, parentDir);
		switch(oImg.FileHeader->FileHeader.Machine)
		{
			case IMAGE_FILE_MACHINE_I386:
				lstrcatW(exePath, x86exe);
				szPlatExe = SZ_86_EXE;
				break;
			// TODO: Differentiate between x64 platforms.
			case IMAGE_FILE_MACHINE_AMD64:
				lstrcatW(exePath, amd64exe);
				szPlatExe = SZ_AMD_EXE;
				break;
			case IMAGE_FILE_MACHINE_IA64:
				lstrcatW(exePath, ia64exe);
				szPlatExe = SZ_IA_EXE;
				break;
			default:
				Fatal(1L, L"Unknown binary type returned for image.\nImage: %s\n\nBinary Type: %d", argv[i], oImg.FileHeader->FileHeader.Machine);
		}

		if(!UnMapAndLoad(&oImg)) {
			Fatal(1L, L"Failed to unload/unmap image.\nImage: %s", argv[i]);
		}

		/* Calculate the length of the eventual exe path with surrounding quotes. */
		lstrcatW(exePath, depsexe);
		szExeStr = szParentDir + szPlatExe + 2; // +2 for the two "s surrounding the image path.

		/* Allocate our command line string. */
		// szExeStr+         1 +1+wcslen(argv)+1
		// "(path)depends.exe" "argv"
		szCmdLine = szExeStr + lstrlenW(argv[i]) + 3;
		lpCmdLine = (LPWSTR)LocalAlloc(LPTR, sizeof(wchar_t) * (szCmdLine + 1));
		if(lpCmdLine == NULL) {
			Fatal(1L, L"Could not allocate memory.\nMemory required (bytes): %d", sizeof(wchar_t) * (szCmdLine + 1));
		}
		if(swprintf(lpCmdLine, szCmdLine+1, L"\"%s\" \"%s\"", exePath, argv[i]) == -1) {
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
			swprintf(lpCmdLine, szCmdLine+1, L"CreateProcessW - \"%s\" \"%s\"", exePath, argv[i]);
			FatalCall(lpCmdLine);
		}
		LocalFree(lpCmdLine);
	}
	return 0;
}
