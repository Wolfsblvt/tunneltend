using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Linq;
using System.Text;

// GUI entry point for Task Scheduler. WindowStyle alone does not suppress
// console creation; CreateNoWindow must be set by the actual process creator.
internal static class HiddenTaskLauncher {
    private static string Quote(string value) {
        var result = new StringBuilder("\"");
        int slashes = 0;
        foreach (char character in value) {
            if (character == '\\') { slashes++; continue; }
            result.Append('\\', character == '"' ? slashes * 2 + 1 : slashes);
            result.Append(character);
            slashes = 0;
        }
        result.Append('\\', slashes * 2);
        return result.Append('"').ToString();
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct StartupInfo {
        public int cb; public string reserved, desktop, title;
        public int x, y, width, height, xChars, yChars, fill, flags;
        public short show, reservedBytes;
        public IntPtr reservedPointer, stdin, stdout, stderr;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct ProcessInfo { public IntPtr process, thread; public uint pid, tid; }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CreateProcess(string app, StringBuilder command, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr environment, string cwd, ref StartupInfo startup, out ProcessInfo child);
    [DllImport("kernel32.dll")] private static extern IntPtr GetStdHandle(int id);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll")] private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
    [DllImport("kernel32.dll")] private static extern bool GetExitCodeProcess(IntPtr handle, out uint code);
    [DllImport("kernel32.dll")] private static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll")] private static extern bool TerminateProcess(IntPtr process, uint code);
    private static int Main(string[] args) {
        try { return Run(args); }
        catch (Win32Exception error) { Console.Error.WriteLine(error.Message); return error.NativeErrorCode; }
    }
    private static int Run(string[] args) {
        if (args.Length < 3 || !args.Contains("-NoProfile") || !args.Contains("-NonInteractive")) return 64;
        var startup = new StartupInfo { cb = Marshal.SizeOf(typeof(StartupInfo)), flags = 0x101, show = 0,
            stdin = GetStdHandle(-10), stdout = GetStdHandle(-11), stderr = GetStdHandle(-12) };
        ProcessInfo child;
        // Inherit the caller's streams directly. Reading redirected pipes here can
        // keep a scheduled task alive after its script detached a background child.
        using (var lifetime = new PowerShellChildLifetime()) {
            if (!CreateProcess(args[0], new StringBuilder(String.Join(" ", args.Select(Quote))), IntPtr.Zero, IntPtr.Zero, true,
                0x08000004, IntPtr.Zero, null, ref startup, out child)) return Marshal.GetLastWin32Error();
            bool resumed = false;
            try {
                lifetime.Attach(child.process);
                if (ResumeThread(child.thread) == UInt32.MaxValue) return Marshal.GetLastWin32Error();
                resumed = true;
                WaitForSingleObject(child.process, 0xffffffff);
                uint code;
                return GetExitCodeProcess(child.process, out code) ? unchecked((int)code) : 1;
            } finally {
                if (!resumed) TerminateProcess(child.process, 1);
                CloseHandle(child.thread); CloseHandle(child.process);
            }
        }
    }

}

// Match Task Scheduler's original direct-PowerShell cancellation: stop the script,
// while detached services retain their independent lifetime.
internal sealed class PowerShellChildLifetime : IDisposable {
    [StructLayout(LayoutKind.Sequential)] private struct BasicLimits {
        public long processTime, jobTime; public uint flags;
        public UIntPtr minimumWorkingSet, maximumWorkingSet; public uint activeProcessLimit;
        public UIntPtr affinity; public uint priorityClass, schedulingClass;
    }
    [StructLayout(LayoutKind.Sequential)] private struct IoCounters {
        public ulong readOperations, writeOperations, otherOperations, readBytes, writeBytes, otherBytes;
    }
    [StructLayout(LayoutKind.Sequential)] private struct ExtendedLimits {
        public BasicLimits basic; public IoCounters io;
        public UIntPtr processMemory, jobMemory, peakProcessMemory, peakJobMemory;
    }
    [DllImport("kernel32.dll", SetLastError = true)] private static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool SetInformationJobObject(IntPtr job, int infoClass, ref ExtendedLimits limits, uint size);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);
    private readonly IntPtr handle;
    public PowerShellChildLifetime() {
        handle = CreateJobObject(IntPtr.Zero, null);
        if (handle == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        var limits = new ExtendedLimits();
        limits.basic.flags = 0x2000 | 0x1000; // KILL_ON_JOB_CLOSE | SILENT_BREAKAWAY_OK
        if (!SetInformationJobObject(handle, 9, ref limits, (uint)Marshal.SizeOf(typeof(ExtendedLimits)))) {
            int error = Marshal.GetLastWin32Error(); CloseHandle(handle); throw new Win32Exception(error);
        }
    }
    public void Attach(IntPtr process) {
        if (!AssignProcessToJobObject(handle, process)) throw new Win32Exception(Marshal.GetLastWin32Error());
    }
    public void Dispose() { CloseHandle(handle); }
}
