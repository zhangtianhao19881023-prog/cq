param([Parameter(Mandatory=$true)][string]$DllPath)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
try {
    [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
} catch {}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class DmNativeLoader
{
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern IntPtr LoadLibraryW(string lpFileName);

    [DllImport("kernel32.dll", CharSet=CharSet.Ansi, SetLastError=true)]
    private static extern IntPtr GetProcAddress(IntPtr hModule, string procName);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int DllGetClassObjectDelegate(ref Guid rclsid, ref Guid riid, out IntPtr ppv);

    [ComImport, Guid("00000001-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IClassFactory
    {
        [PreserveSig]
        int CreateInstance([MarshalAs(UnmanagedType.IUnknown)] object pUnkOuter, ref Guid riid, out IntPtr ppv);

        [PreserveSig]
        int LockServer([MarshalAs(UnmanagedType.Bool)] bool fLock);
    }

    public static object Create(string dllPath, string clsidText)
    {
        IntPtr module = LoadLibraryW(dllPath);
        if (module == IntPtr.Zero)
            throw new Exception("LoadLibrary failed: " + Marshal.GetLastWin32Error());

        IntPtr proc = GetProcAddress(module, "DllGetClassObject");
        if (proc == IntPtr.Zero)
            throw new Exception("DllGetClassObject not found");

        DllGetClassObjectDelegate fn = (DllGetClassObjectDelegate)Marshal.GetDelegateForFunctionPointer(
            proc, typeof(DllGetClassObjectDelegate));
        Guid clsid = new Guid(clsidText);
        Guid iidFactory = new Guid("00000001-0000-0000-C000-000000000046");
        IntPtr factoryPtr;
        int hr = fn(ref clsid, ref iidFactory, out factoryPtr);
        if (hr < 0)
            Marshal.ThrowExceptionForHR(hr);

        IClassFactory factory = (IClassFactory)Marshal.GetObjectForIUnknown(factoryPtr);
        Guid iidDispatch = new Guid("00020400-0000-0000-C000-000000000046");
        IntPtr dispatchPtr;
        hr = factory.CreateInstance(null, ref iidDispatch, out dispatchPtr);
        if (hr < 0)
            Marshal.ThrowExceptionForHR(hr);

        return Marshal.GetObjectForIUnknown(dispatchPtr);
    }
}
"@

function Send-DmResponse($response) {
    [Console]::Out.WriteLine(($response | ConvertTo-Json -Compress))
    [Console]::Out.Flush()
}

function Get-DmError {
    try { return [int]$global:dm.GetLastError() } catch { return -9999 }
}

$global:dm = [DmNativeLoader]::Create($DllPath, "26037A0E-7CBD-4FFF-9C63-56F2D0770214")
Send-DmResponse ([ordered]@{ id = 0; ok = $true; event = "ready"; version = [string]$global:dm.Ver() })

$global:readTask = [Console]::In.ReadLineAsync()
$global:formHost = New-Object System.Windows.Forms.Form
$global:formHost.ShowInTaskbar = $false
$global:formHost.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$global:formHost.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$global:formHost.Left = -32000
$global:formHost.Top = -32000
$global:formHost.Opacity = 0
$global:formHost.Width = 1
$global:formHost.Height = 1
$global:timer = New-Object System.Windows.Forms.Timer
$global:timer.Interval = 10

$global:timer.Add_Tick({
    if (-not $global:readTask.IsCompleted) { return }

    $line = $global:readTask.Result
    if ($null -eq $line) {
        $global:timer.Stop()
        $global:formHost.Close()
        return
    }

    if ($line.Length -gt 0) {
        $id = 0
        $op = ""
        try {
            $request = $line | ConvertFrom-Json
            $id = [int]$request.id
            $op = [string]$request.cmd
            $response = [ordered]@{ id = $id; ok = $true; cmd = $op }

            switch ($op) {
                "status" {
                    $response["version"] = [string]$global:dm.Ver()
                    $response["bind_hwnd"] = [int]$global:dm.GetBindWindow()
                }
                "setpath" {
                    $response["result"] = [int]$global:dm.SetPath([string]$request.path)
                }
                "reg" {
                    $response["result"] = [int]$global:dm.Reg([string]$request.code, [string]$request.extra)
                    $response["last_error"] = Get-DmError
                }
                "bind" {
                    try { [void]$global:dm.UnBindWindow() } catch {}
                    $response["result"] = [int]$global:dm.BindWindow(
                        [int]$request.hwnd,
                        [string]$request.display,
                        [string]$request.mouse,
                        [string]$request.keyboard,
                        [int]$request.mode)
                    $response["bind_hwnd"] = [int]$global:dm.GetBindWindow()
                    $response["last_error"] = Get-DmError
                }
                "unbind" {
                    try { [void]$global:dm.UnBindWindow() } catch {}
                    $response["result"] = 1
                    $response["bind_hwnd"] = 0
                }
                "keypress" {
                    $response["result"] = [int]$global:dm.KeyPress([int]$request.vk)
                    if ([int]$request.delay -gt 0) {
                        Start-Sleep -Milliseconds ([int]$request.delay)
                    }
                    $response["last_error"] = Get-DmError
                }
                "keydown" {
                    $response["result"] = [int]$global:dm.KeyDown([int]$request.vk)
                    $response["last_error"] = Get-DmError
                }
                "keyup" {
                    $response["result"] = [int]$global:dm.KeyUp([int]$request.vk)
                    $response["last_error"] = Get-DmError
                }
                "move" {
                    $response["result"] = [int]$global:dm.MoveTo([int]$request.x, [int]$request.y)
                    $response["last_error"] = Get-DmError
                }
                "click" {
                    $button = ([string]$request.button).ToLowerInvariant()
                    $response["move_result"] = [int]$global:dm.MoveTo([int]$request.x, [int]$request.y)
                    if ($button -eq "right") {
                        $response["result"] = [int]$global:dm.RightClick()
                    } elseif ($button -eq "middle") {
                        $response["result"] = [int]$global:dm.MiddleClick()
                    } else {
                        $response["result"] = [int]$global:dm.LeftClick()
                    }
                    $response["last_error"] = Get-DmError
                }
                "down" {
                    $button = ([string]$request.button).ToLowerInvariant()
                    if ($button -eq "right") { $response["result"] = [int]$global:dm.RightDown() }
                    elseif ($button -eq "middle") { $response["result"] = [int]$global:dm.MiddleDown() }
                    else { $response["result"] = [int]$global:dm.LeftDown() }
                    $response["last_error"] = Get-DmError
                }
                "up" {
                    $button = ([string]$request.button).ToLowerInvariant()
                    if ($button -eq "right") { $response["result"] = [int]$global:dm.RightUp() }
                    elseif ($button -eq "middle") { $response["result"] = [int]$global:dm.MiddleUp() }
                    else { $response["result"] = [int]$global:dm.LeftUp() }
                    $response["last_error"] = Get-DmError
                }
                "quit" {
                    $response["result"] = 1
                    $global:timer.Stop()
                    $global:formHost.Close()
                }
                default {
                    $response["ok"] = $false
                    $response["error"] = "unknown command"
                }
            }
        } catch {
            $response = [ordered]@{ id = $id; ok = $false; cmd = $op; error = [string]$_.Exception.Message }
        }

        Send-DmResponse $response
    }

    if ($global:timer.Enabled) {
        $global:readTask = [Console]::In.ReadLineAsync()
    }
})

$global:timer.Start()
$global:formHost.Show()
[System.Windows.Forms.Application]::Run($global:formHost)

try { [void]$global:dm.UnBindWindow() } catch {}
try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($global:dm) } catch {}
