#if OS == .WINDOWS {
    #load "windows.jai";
} 
else #if OS == .LINUX {
	#load "linux.jai";
}