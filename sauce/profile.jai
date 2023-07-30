#import "Windows";
#import "Machine_X64";

get_rdtsc_frequency :: () -> u64
{
	frequency: s64 = ---; QueryPerformanceFrequency(*frequency);
	
	qpc_begin: s64 = ---; QueryPerformanceCounter(*qpc_begin);
	tsc_begin:= rdtsc();
	Sleep(2);
	qpc_end: s64 = ---; QueryPerformanceCounter(*qpc_end);
	tsc_end:= rdtsc();
	
	tsc_freq := (tsc_end - tsc_begin) * xx frequency / xx (qpc_end - qpc_begin);
	return tsc_freq;
}

/*

	SPALL_FILE :: "yeet.spall";
	spall_init_file(SPALL_FILE.data, 1000000.0 / get_rdtsc_frequency());
	
	// todo - continue
	// https://github.com/colrdavidson/spall-web/blob/master/examples/manual_tracing/simple_benchmark.c

*/