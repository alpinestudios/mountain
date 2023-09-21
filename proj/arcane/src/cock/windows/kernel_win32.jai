//========= Copyright © 2023, Alpine Studio, All rights reserved. ============//
 //  $Author: Amélie Heinrich
 //  $Project: Mountain
 //  $Create Time: 20/09/2023 02:24
 //=============================================================================//

ThreadHandle :: struct
{
    id: s32;
    handle: HANDLE;
    working: bool;
    worker: (*void) -> u32;
}

windows_thread_worker :: (data: *void) -> DWORD
{
    thread := cast (*ThreadHandle) data;

    thread.working = true;
    result := thread.worker(thread);
    thread.working = false;
    return result;
}

thread_init :: (handle: *ThreadHandle)
{
    handle.handle = null;
    handle.id = S32_MAX;
    handle.working = false;
    handle.worker = null; 
}

thread_get_current_id :: () -> u32
{
    return GetCurrentThreadId();
}

thread_launch :: (handle: *ThreadHandle, worker: (*void) -> u32)
{
    assert(!handle.working && "Thread is already working!");

    handle.worker = worker;
    handle.working = false;
    handle.handle = CreateThread(null, 0, cast (*void) windows_thread_worker, handle, 0, *handle.id);
}

thread_join :: (handle: *ThreadHandle)
{
    CloseHandle(handle.handle);
}

thread_wait :: (handle: *ThreadHandle, timeout: u32)
{
    result := WaitForSingleObject(handle.handle, timeout);
    if result == WAIT_TIMEOUT {
        assert(false && "Timeout reached on thread_wait!");
    }
}

mem_alloc :: (size: u64) -> *void
{
    return VirtualAlloc(null, size, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
}

mem_free :: (ptr: *void)
{
    VirtualFree(ptr, 0, MEM_RELEASE);
}

mem_reserve :: (size: u64) -> *void
{
    return VirtualAlloc(null, size, MEM_RESERVE, PAGE_READWRITE);
}

mem_commit :: (ptr: *void, size: u64) -> *void
{
    return VirtualAlloc(ptr, size, MEM_COMMIT, PAGE_READWRITE);
}

#import "Basic";
#import "Windows";
