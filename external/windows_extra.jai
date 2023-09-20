// Just extra windows tings that weren't in Windows.jai
// This is one of the downsides of using jai, can't just cave-man include headers, have to port them........

#scope_export

get_refresh_rate :: () -> float
{
	devmode : DEVMODEA;
 EnumDisplaySettingsA(null,  ENUM_CURRENT_SETTINGS, *devmode);
 return xx devmode.dmDisplayFrequency;
}

FreeConsole :: () -> BOOL #foreign kernel32;

// how do we tell if we're actually linking to a function or just shitting the bed??
// this fails silently if the signature doesn't match lol
PtInRect :: (rect: *RECT, p: POINT) -> bool #foreign user32;

/*
  [in]  HANDLE   hSourceProcessHandle,
  [in]  HANDLE   hSourceHandle,
  [in]  HANDLE   hTargetProcessHandle,
  [out] LPHANDLE lpTargetHandle,
  [in]  DWORD    dwDesiredAccess,
  [in]  BOOL     bInheritHandle,
  [in]  DWORD    dwOptions
*/
DuplicateHandle :: (hSourceProcessHandle: HANDLE, hSourceHandle: HANDLE, hTargetProcessHandle: HANDLE, lpTargetHandle: *HANDLE, dwDesiredAccess: DWORD, bInheritHandle: BOOL, dwOptions: DWORD) -> BOOL #foreign kernel32;

/*
BOOL WINAPI SetStdHandle(
  _In_ DWORD  nStdHandle,
  _In_ HANDLE hHandle
);
*/
SetStdHandle :: (nStdHandle: DWORD, nHandle: HANDLE) -> BOOL #foreign kernel32;

kernel32 :: #system_library "kernel32";
user32 :: #system_library "user32";

#scope_file

CCHDEVICENAME :: 32;
CCHFORMNAME :: 32;
DEVMODEA :: struct
{
 dmDeviceName : [CCHDEVICENAME]u8;
 dmSpecVersion : WORD;
 dmDriverVersion : WORD;
 dmSize : WORD;
 dmDriverExtra : WORD;
 dmFields : DWORD;
 
 /*
 union {
   struct {
     short dmOrientation;
     short dmPaperSize;
     short dmPaperLength;
     short dmPaperWidth;
     short dmScale;
     short dmCopies;
     short dmDefaultSource;
     short dmPrintQuality;
   } DUMMYSTRUCTNAME;
   POINTL dmPosition;
   struct {
     POINTL dmPosition;
     DWORD  dmDisplayOrientation;
     DWORD  dmDisplayFixedOutput;
   } DUMMYSTRUCTNAME2;
 } DUMMYUNIONNAME;
 */
 dmOrientation : s16;
 dmPaperSize : s16;
 dmPaperLength : s16;
 dmPaperWidth : s16;
 dmScale : s16;
 dmCopies : s16;
 dmDefaultSource : s16;
 dmPrintQuality : s16;
 
 dmColor : s16;
 dmDuplex : s16;
 dmYResolution : s16;
 dmTTOption : s16;
 dmCollate : s16;
 dmFormName : [CCHFORMNAME]u8;
 dmLogPixels : WORD;
 dmBitsPerPel : DWORD;
 dmPelsWidth : DWORD;
 dmPelsHeight : DWORD;
 
 /*
 union {
   DWORD dmDisplayFlags;
   DWORD dmNup;
 } DUMMYUNIONNAME2;
 */
 dmDisplayFlags : DWORD;
 
 dmDisplayFrequency : DWORD;
 dmICMMethod : DWORD;
 dmICMIntent : DWORD;
 dmMediaType : DWORD;
 dmDitherType : DWORD;
 dmReserved1 : DWORD;
 dmReserved2 : DWORD;
 dmPanningWidth : DWORD;
 dmPanningHeight : DWORD;
}

ENUM_CURRENT_SETTINGS :: U32_MAX-1;
EnumDisplaySettingsA :: (lpszDeviceName : LPCSTR, iModeNum : DWORD, lpDevMode : *DEVMODEA) -> BOOL #foreign user32;

GetCurrentThreadId :: () -> DWORD #foreign kernel32;

#import "Math";
#import "Windows";