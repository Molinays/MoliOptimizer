#Requires -Version 5.1
<#
    WinOptimizer.ps1 - GUI Moderna Dark Theme
#>

$script:startupLog = Join-Path $env:TEMP "MoliOptimizer-startup.log"
function Write-StartupLog {
    param([string]$Message)
    try { Add-Content -Path $script:startupLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" -ErrorAction SilentlyContinue } catch {}
}
trap {
    $errorText = "ERRORE FATALE: $($_.Exception.Message) | $($_.InvocationInfo.PositionMessage)"
    Write-StartupLog -Message $errorText
    try { [System.Windows.Forms.MessageBox]::Show("MoliOptimizer ha rilevato un errore.`r`n`r`n$($_.Exception.Message)`r`n`r`nDettagli: $script:startupLog", "Errore MoliOptimizer", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null } catch {}
    exit 1
}
Write-StartupLog -Message "Avvio script."

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Write-StartupLog -Message "Assembly WinForms caricate."

# ============================================================
#  ELEVAZIONE AUTOMATICA
# ============================================================
function Test-Admin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-AsAdminIfNeeded {
    $currentPath = $PSCommandPath
    if (-not $currentPath) {
        $currentPath = $MyInvocation.MyCommand.Path
    }

    try {
        if ($currentPath -and $currentPath.EndsWith('.exe', [System.StringComparison]::OrdinalIgnoreCase)) {
            Start-Process -FilePath $currentPath -Verb RunAs -ErrorAction Stop
            exit
        }

        if ($currentPath) {
            Write-StartupLog -Message "Richiesta elevazione da: $currentPath"
            Start-Process powershell.exe -Verb RunAs -ArgumentList @(
                "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$currentPath`""
            ) -WorkingDirectory (Split-Path $currentPath) -ErrorAction Stop
            exit
        }

        throw "Impossibile determinare il percorso del file per l'elevazione amministratore."
    } catch {
        [System.Windows.Forms.MessageBox]::Show("MoliOptimizer non puo' avviarsi come amministratore.`r`n`r`n$($_.Exception.Message)", "Errore di avvio", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        exit 1
    }
}

if (-not (Test-Admin)) {
    Start-AsAdminIfNeeded
}
Write-StartupLog -Message "Esecuzione amministrativa confermata."

# ============================================================
#  P/INVOKE: BLUR ACRILICO
# ============================================================
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.IO;
public static class AcrylicBlur {
    [StructLayout(LayoutKind.Sequential)]
    public struct AccentPolicy {
        public int AccentState;
        public int AccentFlags;
        public int GradientColor;
        public int AnimationId;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct WindowCompositionAttributeData {
        public int Attribute;
        public IntPtr Data;
        public int SizeOfData;
    }
    [DllImport("user32.dll")]
    public static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);
    public static void Enable(IntPtr hwnd, int abgrColor) {
        var accent = new AccentPolicy();
        accent.AccentState = 4;
        accent.GradientColor = abgrColor;
        int size = Marshal.SizeOf(accent);
        IntPtr ptr = Marshal.AllocHGlobal(size);
        Marshal.StructureToPtr(accent, ptr, false);
        var data = new WindowCompositionAttributeData();
        data.Attribute = 19;
        data.SizeOfData = size;
        data.Data = ptr;
        SetWindowCompositionAttribute(hwnd, ref data);
        Marshal.FreeHGlobal(ptr);
    }
}
"@

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.IO;

public static class MemoryNative
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct MEMORYSTATUSEX
    {
        public uint Length;
        public uint MemoryLoad;
        public ulong TotalPhys;
        public ulong AvailPhys;
        public ulong TotalPageFile;
        public ulong AvailPageFile;
        public ulong TotalVirtual;
        public ulong AvailVirtual;
        public ulong AvailExtendedVirtual;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX status);

    [DllImport("ntdll.dll")]
    private static extern int NtSetSystemInformation(int informationClass, IntPtr information, int length);

    [DllImport("psapi.dll", SetLastError = true)]
    private static extern bool EmptyWorkingSet(IntPtr process);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern int RegFlushKey(UIntPtr key);

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool LookupPrivilegeValue(string systemName, string privilegeName, out long luid);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool AdjustTokenPrivileges(IntPtr tokenHandle, bool disableAll, ref TOKEN_PRIVILEGES state, int bufferLength, IntPtr previousState, IntPtr returnLength);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetCurrentProcess();

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetSystemFileCacheSize(IntPtr minimum, IntPtr maximum, int flags);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateFile(string name, uint access, uint share, IntPtr security, uint creation, uint flags, IntPtr template);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool DeviceIoControl(IntPtr device, int code, IntPtr input, int inputLength, IntPtr output, int outputLength, out int returned, IntPtr overlapped);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool FlushFileBuffers(IntPtr file);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    private struct TOKEN_PRIVILEGES { public int Count; public long Luid; public int Attributes; }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    private struct COMBINE_INFORMATION { public IntPtr Handle; public IntPtr PagesCombined; public long Flags; }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    private struct FILE_CACHE_32 { public int Current; public int Peak; public int Faults; public int Minimum; public int Maximum; public int CurrentTransition; public int PeakTransition; public int Repurpose; public int Flags; }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    private struct FILE_CACHE_64 { public long Current; public long Peak; public long Faults; public long Minimum; public long Maximum; public long CurrentTransition; public long PeakTransition; public long Repurpose; public long Flags; }

    private static bool EnablePrivilege(string name)
    {
        long luid;
        if (!LookupPrivilegeValue(null, name, out luid)) return false;
        IntPtr token;
        if (!OpenProcessToken(GetCurrentProcess(), 0x28, out token)) return false;
        var state = new TOKEN_PRIVILEGES { Count = 1, Luid = luid, Attributes = 2 };
        bool result = AdjustTokenPrivileges(token, false, ref state, 0, IntPtr.Zero, IntPtr.Zero);
        CloseHandle(token);
        return result;
    }

    public static ulong TotalPhysicalMemory()
    {
        var status = new MEMORYSTATUSEX();
        status.Length = (uint)Marshal.SizeOf(status);
        return GlobalMemoryStatusEx(ref status) ? status.TotalPhys : 0;
    }

    public static ulong AvailablePhysicalMemory()
    {
        var status = new MEMORYSTATUSEX();
        status.Length = (uint)Marshal.SizeOf(status);
        return GlobalMemoryStatusEx(ref status) ? status.AvailPhys : 0;
    }

    public static int PurgeMemoryList(int command)
    {
        IntPtr buffer = Marshal.AllocHGlobal(sizeof(int));
        try
        {
            Marshal.WriteInt32(buffer, command);
            return NtSetSystemInformation(80, buffer, sizeof(int));
        }
        finally { Marshal.FreeHGlobal(buffer); }
    }

    public static bool EmptyProcessWorkingSet(int processId)
    {
        IntPtr process = System.Diagnostics.Process.GetProcessById(processId).Handle;
        return EmptyWorkingSet(process);
    }

    public static int FlushRegistryCaches()
    {
        int localMachine = RegFlushKey(new UIntPtr(0x80000002u));
        int currentUser = RegFlushKey(new UIntPtr(0x80000001u));
        return localMachine == 0 && currentUser == 0 ? 0 : (localMachine != 0 ? localMachine : currentUser);
    }

    public static int ReconcileRegistryCache()
    {
        return NtSetSystemInformation(155, IntPtr.Zero, 0);
    }

    public static int EmptySystemWorkingSets()
    {
        return PurgeMemoryList(2);
    }

    public static int CombinePhysicalMemory()
    {
        if (!EnablePrivilege("SeProfileSingleProcessPrivilege")) return -1;
        var data = new COMBINE_INFORMATION();
        IntPtr buffer = Marshal.AllocHGlobal(Marshal.SizeOf(data));
        try
        {
            Marshal.StructureToPtr(data, buffer, false);
            return NtSetSystemInformation(130, buffer, Marshal.SizeOf(data));
        }
        finally { Marshal.FreeHGlobal(buffer); }
    }

    public static int OptimizeSystemFileCache()
    {
        if (!EnablePrivilege("SeIncreaseQuotaPrivilege")) return -1;
        int status;
        if (IntPtr.Size == 8)
        {
            var data = new FILE_CACHE_64 { Minimum = -1, Maximum = -1 };
            IntPtr buffer = Marshal.AllocHGlobal(Marshal.SizeOf(data));
            try { Marshal.StructureToPtr(data, buffer, false); status = NtSetSystemInformation(21, buffer, Marshal.SizeOf(data)); }
            finally { Marshal.FreeHGlobal(buffer); }
        }
        else
        {
            var data = new FILE_CACHE_32 { Minimum = -1, Maximum = -1 };
            IntPtr buffer = Marshal.AllocHGlobal(Marshal.SizeOf(data));
            try { Marshal.StructureToPtr(data, buffer, false); status = NtSetSystemInformation(21, buffer, Marshal.SizeOf(data)); }
            finally { Marshal.FreeHGlobal(buffer); }
        }
        if (status != 0) return status;
        return SetSystemFileCacheSize(new IntPtr(-1), new IntPtr(-1), 0) ? 0 : Marshal.GetLastWin32Error();
    }

    public static int FlushModifiedFileCaches()
    {
        int errors = 0;
        foreach (var drive in DriveInfo.GetDrives())
        {
            if (drive.DriveType != DriveType.Fixed || string.IsNullOrWhiteSpace(drive.Name)) continue;
            string volume = @"\\.\" + drive.Name.TrimEnd('\\');
            IntPtr handle = CreateFile(volume, 0xC0000000, 3, IntPtr.Zero, 3, 0x20000000, IntPtr.Zero);
            if (handle == new IntPtr(-1)) continue;
            try
            {
                int returned;
                DeviceIoControl(handle, 589832, IntPtr.Zero, 0, IntPtr.Zero, 0, out returned, IntPtr.Zero);
                DeviceIoControl(handle, 589828, IntPtr.Zero, 0, IntPtr.Zero, 0, out returned, IntPtr.Zero);
                if (!FlushFileBuffers(handle)) errors++;
            }
            finally { CloseHandle(handle); }
        }
        return errors == 0 ? 0 : -1;
    }
}
"@

Add-Type -ReferencedAssemblies @("System.Windows.Forms", "System.Drawing") @"
using System;
using System.Drawing;
using System.Windows.Forms;

public class DarkCheckedListBox : CheckedListBox
{
    public DarkCheckedListBox()
    {
        this.DrawMode = DrawMode.OwnerDrawFixed;
        this.ItemHeight = 26;
        this.BorderStyle = BorderStyle.None;
        this.BackColor = Color.FromArgb(27, 31, 41);
        this.ForeColor = Color.FromArgb(235, 238, 245);
        this.CheckOnClick = true;
        this.IntegralHeight = false;
        this.DoubleBuffered = true;
        this.SelectionMode = SelectionMode.One;
        this.Font = new Font("Segoe UI", 8.8f);
    }

    protected override void OnDrawItem(DrawItemEventArgs e)
    {
        if (e.Index < 0) return;

        e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        e.Graphics.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;

        bool checkedItem = GetItemChecked(e.Index);
        Color bg = checkedItem ? Color.FromArgb(18, 43, 47) : Color.FromArgb(27, 31, 41);
        using (SolidBrush b = new SolidBrush(bg))
            e.Graphics.FillRectangle(b, e.Bounds);

        string itemText = Convert.ToString(Items[e.Index]);
        Color levelColor = Color.FromArgb(0, 220, 190);
        if (itemText.StartsWith("[Massimo]")) levelColor = Color.FromArgb(245, 72, 92);
        else if (itemText.StartsWith("[Avanzato]")) levelColor = Color.FromArgb(255, 160, 60);
        else if (itemText.StartsWith("[Medio]")) levelColor = Color.FromArgb(245, 205, 70);
        int levelStart = itemText.IndexOf("] ");
        if (levelStart > 0) itemText = itemText.Substring(levelStart + 2);

        int dotSize = 8;
        int dotX = e.Bounds.X + 12;
        int dotY = e.Bounds.Y + (e.Bounds.Height - dotSize) / 2;
        using (SolidBrush levelBrush = new SolidBrush(levelColor))
            e.Graphics.FillEllipse(levelBrush, dotX, dotY, dotSize, dotSize);

        int checkSize = 12;
        int checkX = e.Bounds.X + 30;
        int checkY = e.Bounds.Y + (e.Bounds.Height - checkSize) / 2;
        Rectangle checkRect = new Rectangle(checkX, checkY, checkSize, checkSize);

        if (checkedItem)
        {
            using (Pen p = new Pen(Color.FromArgb(0, 220, 190), 2f))
            {
                p.StartCap = System.Drawing.Drawing2D.LineCap.Round;
                p.EndCap = System.Drawing.Drawing2D.LineCap.Round;
                e.Graphics.DrawLine(p, checkRect.X + 2, checkRect.Y + 6, checkRect.X + 5, checkRect.Y + 9);
                e.Graphics.DrawLine(p, checkRect.X + 5, checkRect.Y + 9, checkRect.Right - 2, checkRect.Y + 2);
            }
        }

        RectangleF textBounds = new RectangleF(checkRect.Right + 10, e.Bounds.Y + 1, Math.Max(0, e.Bounds.Width - checkRect.Right - 16), e.Bounds.Height - 2);
        StringFormat sf = new StringFormat();
        sf.LineAlignment = StringAlignment.Center;
        sf.Trimming = StringTrimming.EllipsisCharacter;
        sf.FormatFlags = StringFormatFlags.NoWrap | StringFormatFlags.NoClip;

        using (Brush text = new SolidBrush(Color.FromArgb(235, 238, 245)))
            e.Graphics.DrawString(itemText, this.Font, text, textBounds, sf);
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        this.SelectedIndex = -1;
    }

    protected override bool ShowFocusCues { get { return false; } }
}

public class DarkButton : Button
{
    public DarkButton()
    {
        this.FlatStyle = FlatStyle.Flat;
        this.FlatAppearance.BorderSize = 0;
        this.TabStop = false;
        this.UseVisualStyleBackColor = false;
    }

    protected override bool ShowFocusCues { get { return false; } }
}


"@

# ============================================================
#  PALETTE COLORI
# ============================================================
$script:BgColor        = [System.Drawing.Color]::FromArgb(10, 12, 18)
$script:PanelColor     = [System.Drawing.Color]::FromArgb(22, 26, 36)
$script:PanelColor2    = [System.Drawing.Color]::FromArgb(13, 16, 23)
$script:CardColor      = [System.Drawing.Color]::FromArgb(27, 31, 41)
$script:CardHover      = [System.Drawing.Color]::FromArgb(34, 40, 52)
$script:CardSelected   = [System.Drawing.Color]::FromArgb(17, 65, 63)
$script:AccentColor    = [System.Drawing.Color]::FromArgb(0, 220, 190)
$script:AccentHover    = [System.Drawing.Color]::FromArgb(0, 245, 210)
$script:TextColor      = [System.Drawing.Color]::FromArgb(235, 238, 245)
$script:TextColorDim   = [System.Drawing.Color]::FromArgb(145, 153, 170)
$script:DangerColor    = [System.Drawing.Color]::FromArgb(245, 72, 92)
$script:SuccessColor   = [System.Drawing.Color]::FromArgb(60, 220, 135)

# ============================================================
#  FUNZIONI DI SUPPORTO
# ============================================================

# ============================================================
#  STILE MODERNO / DARK CONTROLS
# ============================================================
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class NativeUI {
    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)]
    public static extern int SetWindowTheme(IntPtr hwnd, string pszSubAppName, string pszSubIdList);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    private static extern bool ReleaseCapture();

    [DllImport("user32.dll")]
    private static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);

    public static void BeginWindowDrag(IntPtr hwnd) {
        ReleaseCapture();
        SendMessage(hwnd, 0xA1, new IntPtr(2), IntPtr.Zero);
    }

    public static void DarkScrollBar(IntPtr hwnd) {
        if (hwnd != IntPtr.Zero) {
            SetWindowTheme(hwnd, "DarkMode_Explorer", null);
        }
    }
}
"@

function Enable-DarkScrollBar {
    param([Parameter(Mandatory)]$Control)

    try {
        if ($Control.IsHandleCreated) {
            [NativeUI]::DarkScrollBar($Control.Handle)
        } else {
            $Control.Add_HandleCreated({
                param($sender, $e)
                try { [NativeUI]::DarkScrollBar($sender.Handle) } catch {}
            }.GetNewClosure())
        }
    } catch {}
}

function Add-SmoothHover {
    param(
        [Parameter(Mandatory)]$Control,
        [Parameter(Mandatory)][System.Drawing.Color]$NormalColor,
        [Parameter(Mandatory)][System.Drawing.Color]$HoverColor
    )

    $state = @{
        Hover = $false
        R = $NormalColor.R
        G = $NormalColor.G
        B = $NormalColor.B
    }

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 15

    $timer.Add_Tick({
        param($sender, $e)

        $target = if ($state.Hover) { $HoverColor } else { $NormalColor }
        $state.R += ($target.R - $state.R) * 0.24
        $state.G += ($target.G - $state.G) * 0.24
        $state.B += ($target.B - $state.B) * 0.24

        $Control.BackColor = [System.Drawing.Color]::FromArgb(
            [int]$state.R,
            [int]$state.G,
            [int]$state.B
        )

        if (
            [Math]::Abs($state.R - $target.R) -lt 1 -and
            [Math]::Abs($state.G - $target.G) -lt 1 -and
            [Math]::Abs($state.B - $target.B) -lt 1
        ) {
            $Control.BackColor = $target
            $sender.Stop()
        }
    }.GetNewClosure())

    $Control.Add_MouseEnter({
        $state.Hover = $true
        if (-not $timer.Enabled) { $timer.Start() }
    }.GetNewClosure())

    $Control.Add_MouseLeave({
        $state.Hover = $false
        if (-not $timer.Enabled) { $timer.Start() }
    }.GetNewClosure())
}

function Style-DarkCheckedListBox {
    param([Parameter(Mandatory)]$List)
    $List.BackColor = $script:CardColor
    $List.ForeColor = $script:TextColor
    $List.BorderStyle = 'None'
    $List.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $List.CheckOnClick = $true
    $List.ScrollAlwaysVisible = $false
    $List.IntegralHeight = $false
    Enable-DarkScrollBar -Control $List
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logBox.Invoke([Action]{
        $logBox.AppendText("[$timestamp] $Message`r`n")
        $logBox.SelectionStart = $logBox.Text.Length
        $logBox.ScrollToCaret()
    })
    [System.Windows.Forms.Application]::DoEvents()
}

function Write-LogDetail {
    param(
        [string]$Operation,
        [string]$Target,
        [string]$Detail = "",
        [string]$Status = "OK",
        [string]$ErrorMsg = ""
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    $icon = if ($Status -eq "OK") { "[OK]" } else { "[ERR]" }
    $msg = "[$timestamp] $icon $Operation"
    if ($Target) { $msg = "$msg | $Target" }
    if ($Detail) { $msg = "$msg | $Detail" }
    if ($ErrorMsg) { $msg = "$msg | ERRORE: $ErrorMsg" }
    
    $logBox.Invoke([Action]{
        $logBox.AppendText("$msg`r`n")
        $logBox.SelectionStart = $logBox.Text.Length
        $logBox.ScrollToCaret()
    })
    [System.Windows.Forms.Application]::DoEvents()
}

function Format-MemorySize {
    param([UInt64]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    return "{0:N0} MB" -f ($Bytes / 1MB)
}

function Update-MemoryDisplay {
    if (-not $script:memoryMeter) { return }
    $total = [MemoryNative]::TotalPhysicalMemory()
    $available = [MemoryNative]::AvailablePhysicalMemory()
    if ($total -le 0) { return }

    $used = $total - [Math]::Min($total, $available)
    $script:memoryTotalLabel.Text = "Fisica totale  $(Format-MemorySize $total)"
    $script:memoryUsedLabel.Text = "Utilizzata  $(Format-MemorySize $used)"
    $script:memoryFreeLabel.Text = "Libera  $(Format-MemorySize $available)"
    $script:memoryMeter.Tag = [double]$used / [double]$total
    $script:memoryMeter.Invalidate()
}

function Invoke-MemoryOptimization {
    Write-Log "=== Ottimizzazione memoria ==="
    $operations = @(
        @{ Name = "Cache del registro"; Action = { [MemoryNative]::ReconcileRegistryCache() } },
        @{ Name = "Flush hive del registro"; Action = { [MemoryNative]::FlushRegistryCaches() } },
        @{ Name = "File modificati"; Action = { [MemoryNative]::FlushModifiedFileCaches() } },
        @{ Name = "Elenco pagine modificate"; Action = { [MemoryNative]::PurgeMemoryList(3) } },
        @{ Name = "Elenco standby"; Action = { [MemoryNative]::PurgeMemoryList(4) } },
        @{ Name = "Elenco inattivo"; Action = { [MemoryNative]::PurgeMemoryList(5) } },
        @{ Name = "Elenco pagine combinate"; Action = { [MemoryNative]::CombinePhysicalMemory() } },
        @{ Name = "Cache file di sistema"; Action = { [MemoryNative]::OptimizeSystemFileCache() } },
        @{ Name = "Set di lavoro globale"; Action = { [MemoryNative]::EmptySystemWorkingSets() } }
    )

    foreach ($operation in $operations) {
        try {
            $status = & $operation.Action
            if ($status -ne 0) { throw "NTSTATUS/Win32: $status" }
            Write-LogDetail -Operation "Memoria" -Target $operation.Name -Status OK
        } catch {
            Write-LogDetail -Operation "Memoria" -Target $operation.Name -Status ERRORE -ErrorMsg $_
        }
    }

    $workingSets = 0
    foreach ($process in Get-Process -ErrorAction SilentlyContinue) {
        try {
            if ([MemoryNative]::EmptyProcessWorkingSet($process.Id)) { $workingSets++ }
        } catch {}
    }
    Write-LogDetail -Operation "Memoria" -Target "Set di lavoro" -Detail "$workingSets processi svuotati" -Status OK
    Update-MemoryDisplay
    Write-Log "=== Ottimizzazione memoria completata ==="
}

function New-SystemRestorePoint {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "MoliOptimizer - pre modifiche" -RestorePointType "MODIFY_SETTINGS"
        Write-Log "Punto di ripristino creato."
    } catch {
        Write-Log "ERRORE: $_"
    }
}

function Set-RegistryValue {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)]$Value,[string]$Type = "DWord")
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}

$script:optimizationBackup = @{
    Registry = @{}
    Services = @{}
    Startup = @{}
    PowerScheme = $null
    Hibernate = $null
}
$script:optimizationBackupFile = Join-Path $env:ProgramData "MoliOptimizer\optimization-backup.xml"

function Save-OptimizationBackup {
    try {
        $backupDirectory = Split-Path $script:optimizationBackupFile -Parent
        if (-not (Test-Path $backupDirectory)) { New-Item -Path $backupDirectory -ItemType Directory -Force | Out-Null }
        $script:optimizationBackup | Export-Clixml -Path $script:optimizationBackupFile -Depth 8 -Force
    } catch { Write-StartupLog -Message "Backup ottimizzazioni non salvato: $($_.Exception.Message)" }
}

function Load-OptimizationBackup {
    try {
        if (-not (Test-Path $script:optimizationBackupFile)) { return }
        $loaded = Import-Clixml -Path $script:optimizationBackupFile -ErrorAction Stop
        if ($loaded.Registry) { $script:optimizationBackup.Registry = $loaded.Registry }
        if ($loaded.Services) { $script:optimizationBackup.Services = $loaded.Services }
        if ($loaded.Startup) { $script:optimizationBackup.Startup = $loaded.Startup }
        if ($null -ne $loaded.PowerScheme) { $script:optimizationBackup.PowerScheme = $loaded.PowerScheme }
        if ($null -ne $loaded.Hibernate) { $script:optimizationBackup.Hibernate = $loaded.Hibernate }
    } catch { Write-StartupLog -Message "Backup ottimizzazioni non caricato: $($_.Exception.Message)" }
}

function Save-RegistryBackup {
    param([string]$Path,[string]$Name)
    $key = "$Path|$Name"
    if ($script:optimizationBackup.Registry.ContainsKey($key)) { return }
    $entry = @{ Path = $Path; Name = $Name; Exists = $false; Value = $null; Type = "DWord" }
    try {
        if (Test-Path $Path) {
            $regKey = Get-Item -Path $Path
            $value = $regKey.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if ($null -ne $value) {
                $entry.Exists = $true
                $entry.Value = $value
                $entry.Type = $regKey.GetValueKind($Name).ToString()
            }
        }
    } catch {}
    $script:optimizationBackup.Registry[$key] = $entry
    Save-OptimizationBackup
}

function Save-TweakBackup {
    param($Tweak)
    if ($Tweak.Path -and $Tweak.RegName) { Save-RegistryBackup -Path $Tweak.Path -Name $Tweak.RegName }
    if ($Tweak.Command) {
        $matches = [regex]::Matches($Tweak.Command, "Set-RegistryValue -Path '([^']+)' -Name '([^']+)'")
        foreach ($match in $matches) { Save-RegistryBackup -Path $match.Groups[1].Value -Name $match.Groups[2].Value }
    }
}

function Restore-OptimizationBackup {
    foreach ($entry in $script:optimizationBackup.Registry.Values) {
        try {
            if ($entry.Exists) {
                if (-not (Test-Path $entry.Path)) { New-Item -Path $entry.Path -Force | Out-Null }
                Set-ItemProperty -Path $entry.Path -Name $entry.Name -Value $entry.Value -Type $entry.Type -Force
            } elseif (Test-Path $entry.Path) {
                Remove-ItemProperty -Path $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue
            }
        } catch { Write-LogDetail -Operation "Ripristino registro" -Target $entry.Name -Status ERRORE -ErrorMsg $_ }
    }
    foreach ($entry in $script:optimizationBackup.Services.Values) {
        try {
            Set-Service -Name $entry.Name -StartupType $entry.StartType -ErrorAction Stop
            if ($entry.Status -eq 'Running') { Start-Service -Name $entry.Name -ErrorAction SilentlyContinue }
            elseif ($entry.Status -eq 'Stopped') { Stop-Service -Name $entry.Name -Force -ErrorAction SilentlyContinue }
        } catch { Write-LogDetail -Operation "Ripristino servizio" -Target $entry.Name -Status ERRORE -ErrorMsg $_ }
    }
    foreach ($entry in $script:optimizationBackup.Startup.Values) {
        try {
            if ($entry.Exists) {
                if (-not (Test-Path $entry.Path)) { New-Item -Path $entry.Path -Force | Out-Null }
                Set-ItemProperty -Path $entry.Path -Name $entry.Name -Value $entry.Value -Type Binary -Force
            } elseif (Test-Path $entry.Path) {
                Remove-ItemProperty -Path $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue
            }
        } catch { Write-LogDetail -Operation "Ripristino avvio" -Target $entry.Name -Status ERRORE -ErrorMsg $_ }
    }
    if ($script:optimizationBackup.PowerScheme) { powercfg -setactive $script:optimizationBackup.PowerScheme | Out-Null }
    if ($script:optimizationBackup.Hibernate -eq $true) { powercfg /hibernate on | Out-Null }
    if ($script:optimizationBackup.Hibernate -eq $false) { powercfg /hibernate off | Out-Null }
    Write-Log "Ripristino completato per tutte le ottimizzazioni registrate. Le app rimosse con Debloat richiedono reinstallazione."
}

function Remove-TweakRegistryValues {
    param($Tweak)
    $targets = @()
    if ($Tweak.Path -and $Tweak.RegName) { $targets += @{ Path = $Tweak.Path; Name = $Tweak.RegName } }
    if ($Tweak.Command) {
        foreach ($match in [regex]::Matches($Tweak.Command, "Set-RegistryValue -Path '([^']+)' -Name '([^']+)'")) {
            $targets += @{ Path = $match.Groups[1].Value; Name = $match.Groups[2].Value }
        }
    }
    foreach ($target in $targets) {
        try {
            if (Test-Path $target.Path) { Remove-ItemProperty -Path $target.Path -Name $target.Name -ErrorAction SilentlyContinue }
            Write-LogDetail -Operation "Default Windows" -Target $target.Name -Detail "valore rimosso" -Status OK
        } catch { Write-LogDetail -Operation "Default Windows" -Target $target.Name -Status ERRORE -ErrorMsg $_ }
    }
}

function Clear-OptimizationBackup {
    $script:optimizationBackup.Registry.Clear()
    $script:optimizationBackup.Services.Clear()
    $script:optimizationBackup.Startup.Clear()
    $script:optimizationBackup.PowerScheme = $null
    $script:optimizationBackup.Hibernate = $null
    try { Remove-Item -Path $script:optimizationBackupFile -Force -ErrorAction SilentlyContinue } catch {}
}

function Restore-WindowsDefaultSettings {
    Write-Log "=== Ripristino impostazioni default Windows ==="
    foreach ($tweak in @($privacyTweaks) + @($perfTweaks)) { Remove-TweakRegistryValues -Tweak $tweak }

    $defaultServiceTypes = @{
        DiagTrack = 'Manual'; dmwappushservice = 'Manual'; WerSvc = 'Manual'; Fax = 'Manual';
        RemoteRegistry = 'Disabled'; MapsBroker = 'Manual'; lfsvc = 'Manual'; TrkWks = 'Automatic';
        WMPNetworkSvc = 'Manual'; RetailDemo = 'Manual'; XblAuthManager = 'Manual';
        XblGameSave = 'Manual'; XboxNetApiSvc = 'Manual'; PhoneSvc = 'Manual'
    }
    foreach ($serviceName in $defaultServiceTypes.Keys) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if (-not $service) { continue }
            Set-Service -Name $serviceName -StartupType $defaultServiceTypes[$serviceName] -ErrorAction Stop
            if ($defaultServiceTypes[$serviceName] -ne 'Disabled') { Start-Service -Name $serviceName -ErrorAction SilentlyContinue }
            Write-LogDetail -Operation "Default Windows" -Target $serviceName -Detail "servizio ripristinato" -Status OK
        } catch { Write-LogDetail -Operation "Default Windows" -Target $serviceName -Status ERRORE -ErrorMsg $_ }
    }

    foreach ($item in Get-StartupApps) {
        try {
            $approvedPath = if ($item.Hive -eq 'HKLM') { "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" } else { "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" }
            if (Test-Path $approvedPath) { Remove-ItemProperty -Path $approvedPath -Name $item.Name -ErrorAction SilentlyContinue }
            Write-LogDetail -Operation "Default Windows" -Target $item.Name -Detail "avvio riabilitato" -Status OK
        } catch { Write-LogDetail -Operation "Default Windows" -Target $item.Name -Status ERRORE -ErrorMsg $_ }
    }

    try { powercfg -setactive SCHEME_BALANCED | Out-Null; powercfg /hibernate on | Out-Null; Write-LogDetail -Operation "Default Windows" -Target "Alimentazione" -Detail "Bilanciato e ibernazione attiva" -Status OK } catch { Write-LogDetail -Operation "Default Windows" -Target "Alimentazione" -Status ERRORE -ErrorMsg $_ }
    Clear-OptimizationBackup
    Write-Log "=== Ripristino impostazioni default completato ==="
}

function Save-PowerBackup {
    if (-not $script:optimizationBackup.PowerScheme) {
        $scheme = powercfg /getactivescheme 2>$null | Select-String -Pattern '([a-f0-9]{8}-[a-f0-9-]{27})'
        if ($scheme -and $scheme.Matches.Count -gt 0) { $script:optimizationBackup.PowerScheme = $scheme.Matches[0].Groups[1].Value }
    }
    if ($null -eq $script:optimizationBackup.Hibernate) {
        Save-RegistryBackup -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -Name 'HibernateEnabled'
        try { $script:optimizationBackup.Hibernate = ([int](Get-ItemPropertyValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -Name 'HibernateEnabled' -ErrorAction Stop) -eq 1) } catch {}
    }
    Save-OptimizationBackup
}

Load-OptimizationBackup

function Show-OptimizationWarning {
    param([string]$Name,[string]$Warning)
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "MoliOptimizer - avviso"
    $dialog.Size = New-Object System.Drawing.Size(400, 185)
    $dialog.StartPosition = 'CenterParent'
    $dialog.FormBorderStyle = 'None'
    $dialog.MinimizeBox = $false
    $dialog.MaximizeBox = $false
    $dialog.ShowInTaskbar = $false
    $dialog.BackColor = $script:PanelColor
    $dialog.ForeColor = $script:TextColor

    $accent = New-Object System.Windows.Forms.Panel
    $accent.BackColor = $script:DangerColor
    $accent.Location = New-Object System.Drawing.Point(0, 0)
    $accent.Size = New-Object System.Drawing.Size(5, 185)
    $icon = New-Object System.Windows.Forms.Label
    $icon.Text = '!'
    $icon.ForeColor = $script:DangerColor
    $icon.Font = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)
    $icon.Location = New-Object System.Drawing.Point(22, 18)
    $icon.Size = New-Object System.Drawing.Size(38, 42)
    $icon.TextAlign = 'MiddleCenter'
    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Attenzione: $Name"
    $title.ForeColor = $script:TextColor
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $title.Location = New-Object System.Drawing.Point(68, 22)
    $title.Size = New-Object System.Drawing.Size(300, 25)
    $body = New-Object System.Windows.Forms.Label
    $body.Text = $Warning
    $body.ForeColor = $script:TextColorDim
    $body.Location = New-Object System.Drawing.Point(68, 52)
    $body.Size = New-Object System.Drawing.Size(300, 55)
    $body.AutoEllipsis = $false
    $ok = New-Object DarkButton
    $ok.Text = 'Ho capito'
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $ok.FlatStyle = 'Flat'
    $ok.FlatAppearance.BorderSize = 0
    $ok.BackColor = $script:AccentColor
    $ok.ForeColor = [System.Drawing.Color]::White
    $ok.Size = New-Object System.Drawing.Size(100, 28)
    $ok.Location = New-Object System.Drawing.Point(268, 120)
    $ok.Font = New-Object System.Drawing.Font('Segoe UI', 8.2, [System.Drawing.FontStyle]::Bold)
    $dialog.AcceptButton = $ok
    $dialog.Controls.AddRange(@($accent, $icon, $title, $body, $ok))
    [void]$dialog.ShowDialog($form)
    $dialog.Dispose()
}

function Get-OptimizationLevel {
    param([string]$Name)
    if ($Name -match 'Disabilita localizzazione|Disabilita ibernazione|Disabilita app in background|Print Spooler|Remote Desktop|Tablet Input') { return 'Massimo' }
    if ($Name -match 'telemetria|PowerThrottling|power throttling|GPU|NTFS|animazioni|trasparenza|sensibilita') { return 'Avanzato' }
    if ($Name -match 'suggerimenti|contenuti|feedback|Game|startup|avvio|Search|riconoscimento vocale') { return 'Medio' }
    return 'Base'
}

$script:shownOptimizationWarnings = @{}
function Show-OptimizationWarningOnce {
    param([string]$Name,[string]$Warning)
    if ((Get-OptimizationLevel $Name) -ne 'Massimo') { return }
    if ($script:shownOptimizationWarnings.ContainsKey($Name)) { return }
    $script:shownOptimizationWarnings[$Name] = $true
    Show-OptimizationWarning -Name $Name -Warning $Warning
}

function Confirm-RestoreAction {
    param([string]$Title, [string]$Message, [string]$ConfirmText)
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "MoliOptimizer - conferma"
    $dialog.Size = New-Object System.Drawing.Size(520, 225)
    $dialog.StartPosition = 'CenterParent'
    $dialog.FormBorderStyle = 'None'
    $dialog.MinimizeBox = $false
    $dialog.MaximizeBox = $false
    $dialog.ShowInTaskbar = $false
    $dialog.BackColor = $script:PanelColor
    $dialog.ForeColor = $script:TextColor

    $accent = New-Object System.Windows.Forms.Panel
    $accent.BackColor = $script:DangerColor
    $accent.Size = New-Object System.Drawing.Size(5, 225)
    $icon = New-Object System.Windows.Forms.Label
    $icon.Text = '!'
    $icon.ForeColor = $script:DangerColor
    $icon.Font = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)
    $icon.Location = New-Object System.Drawing.Point(22, 18)
    $icon.Size = New-Object System.Drawing.Size(38, 42)
    $icon.TextAlign = 'MiddleCenter'
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = $Title
    $titleLabel.ForeColor = $script:TextColor
    $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Location = New-Object System.Drawing.Point(68, 22)
    $titleLabel.Size = New-Object System.Drawing.Size(420, 25)
    $body = New-Object System.Windows.Forms.Label
    $body.Text = $Message
    $body.ForeColor = $script:TextColorDim
    $body.Location = New-Object System.Drawing.Point(68, 55)
    $body.Size = New-Object System.Drawing.Size(420, 72)

    $cancel = New-Object DarkButton
    $cancel.Text = 'Annulla'
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancel.BackColor = $script:PanelColor2
    $cancel.ForeColor = $script:TextColor
    $cancel.Size = New-Object System.Drawing.Size(105, 30)
    $cancel.Location = New-Object System.Drawing.Point(225, 165)
    $confirm = New-Object DarkButton
    $confirm.Text = $ConfirmText
    $confirm.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $confirm.BackColor = $script:DangerColor
    $confirm.ForeColor = [System.Drawing.Color]::White
    $confirm.Size = New-Object System.Drawing.Size(160, 30)
    $confirm.Location = New-Object System.Drawing.Point(340, 165)
    $dialog.CancelButton = $cancel
    $dialog.AcceptButton = $confirm
    $dialog.Controls.AddRange(@($accent, $icon, $titleLabel, $body, $cancel, $confirm))
    $result = $dialog.ShowDialog($form)
    $dialog.Dispose()
    return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Remove-Bloatware {
    param([Parameter(Mandatory)][string]$PackageName)
    Get-AppxPackage -Name $PackageName -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $PackageName } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
}

function Install-WingetApp {
    param([Parameter(Mandatory)][string]$WingetId)
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "winget non trovato." }
    $wargs = @("install","--id",$WingetId,"-e","--silent","--accept-package-agreements","--accept-source-agreements")
    $proc = Start-Process winget -ArgumentList $wargs -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0) { throw "winget ha restituito codice $($proc.ExitCode)" }
}

function Set-ServiceState {
    param([string]$Name,[string]$StartupType)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { throw "Servizio '$Name' non presente." }
    $oldStatus = $svc.Status
    $oldStartup = $svc.StartType
    Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop
    if ($StartupType -eq 'Disabled' -and $svc.Status -eq 'Running') {
        Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
    }
    $newStatus = (Get-Service -Name $Name -ErrorAction SilentlyContinue).Status
    Write-LogDetail -Operation "Servizio" -Target $Name -Detail "impostato su $StartupType (prima: $oldStartup, stato: $oldStatus -> $newStatus)" -Status OK
}

function Enable-UltimatePerformance {
    $output = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
    if ($output -match '([a-f0-9-]{36})') { 
        powercfg -setactive $Matches[1]
        Write-LogDetail -Operation "Piano energetico" -Target "Prestazioni assolute" -Detail "attivato" -Status OK
    }
    else { throw "Impossibile leggere il GUID." }
}

function Get-StartupApps {
    $items = @()
    $paths = @(
        @{Hive='HKCU'; Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'}
        @{Hive='HKLM'; Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'}
    )
    foreach ($p in $paths) {
        if (Test-Path $p.Path) {
            $props = Get-ItemProperty -Path $p.Path
            foreach ($prop in $props.PSObject.Properties) {
                if ($prop.Name -notmatch '^PS(Path|ParentPath|ChildName|Provider)$') {
                    $items += [PSCustomObject]@{ Name = $prop.Name; Hive = $p.Hive }
                }
            }
        }
    }
    return $items
}

function Disable-StartupItem {
    param([string]$Hive,[string]$ValueName)
    $approvedPath = if ($Hive -eq 'HKLM') { "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" } else { "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" }
    if (-not (Test-Path $approvedPath)) { New-Item -Path $approvedPath -Force | Out-Null }
    $bytes = [byte[]](3,0,0,0,0,0,0,0,0,0,0,0)
    Set-ItemProperty -Path $approvedPath -Name $ValueName -Value $bytes -Type Binary -Force
    Write-LogDetail -Operation "Avvio automatico" -Target $ValueName -Detail "disabilitato (Hive: $Hive)" -Status OK
}

function New-TweakAction {
    param($Tweak)
    if ($Tweak.Command) { return [scriptblock]::Create($Tweak.Command) }
    $type = if ($Tweak.Type) { $Tweak.Type } else { "DWord" }
    $valueLiteral = if ($type -eq "String") { "'$($Tweak.Value)'" } else { $Tweak.Value }
    return [scriptblock]::Create("Set-RegistryValue -Path '$($Tweak.Path)' -Name '$($Tweak.RegName)' -Value $valueLiteral -Type '$type'")
}

function New-FallbackIcon {
    param([string]$Text)
    $bmp = New-Object System.Drawing.Bitmap(32,32)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'SingleBitPerPixelGridFit'
    $brush = [System.Drawing.SolidBrush]::new($script:AccentColor)
    $g.FillEllipse($brush, 0, 0, 32, 32)
    $font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $g.DrawString($Text.Substring(0,1).ToUpper(), $font, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0,0,32,32)), $sf)
    $g.Dispose()
    return $bmp
}

function Get-AppIcon {
    param([string]$Domain,[string]$Name)
    $cacheDir = Join-Path $env:TEMP "WinOptimizerIcons"
    if (-not (Test-Path $cacheDir)) { New-Item -Path $cacheDir -ItemType Directory -Force | Out-Null }
    $file = Join-Path $cacheDir "$Domain.png"
    if (-not (Test-Path $file)) {
        try {
            $url = "https://www.google.com/s2/favicons?sz=32&domain=$Domain"
            $req = [System.Net.HttpWebRequest]::Create($url)
            $req.Timeout = 1500
            $resp = $req.GetResponse()
            $stream = $resp.GetResponseStream()
            $fs = [System.IO.File]::Create($file)
            $stream.CopyTo($fs)
            $fs.Close(); $stream.Close(); $resp.Close()
        } catch {
            return New-FallbackIcon -Text $Name
        }
    }
    try { return [System.Drawing.Image]::FromFile($file) }
    catch { return New-FallbackIcon -Text $Name }
}

# ============================================================
#  DATI
# ============================================================
$debloatApps = [ordered]@{
    "3D Builder" = "Microsoft.3DBuilder"
    "Bing News" = "Microsoft.BingNews"
    "Bing Meteo" = "Microsoft.BingWeather"
    "Guida di Windows" = "Microsoft.GetHelp"
    "Introduzione a Windows" = "Microsoft.Getstarted"
    "Office Hub" = "Microsoft.MicrosoftOfficeHub"
    "Solitario Microsoft" = "Microsoft.MicrosoftSolitaireCollection"
    "Mixed Reality Portal" = "Microsoft.MixedReality.Portal"
    "Persone" = "Microsoft.People"
    "Skype" = "Microsoft.SkypeApp"
    "Wallet" = "Microsoft.Wallet"
    "Feedback Hub" = "Microsoft.WindowsFeedbackHub"
    "Mappe di Windows" = "Microsoft.WindowsMaps"
    "Xbox App" = "Microsoft.XboxApp"
    "Xbox Game Overlay" = "Microsoft.XboxGamingOverlay"
    "Xbox Identity Provider" = "Microsoft.XboxIdentityProvider"
    "Il tuo telefono" = "Microsoft.YourPhone"
    "Groove Music" = "Microsoft.ZuneMusic"
    "Film e TV" = "Microsoft.ZuneVideo"
    "Cortana" = "Microsoft.549981C3F5F10"
    "Clipchamp" = "Clipchamp.Clipchamp"
    "Microsoft To Do" = "Microsoft.Todos"
    "Power Automate Desktop" = "Microsoft.PowerAutomateDesktop"
}

$privacyTweaks = @(
    @{Name="Disabilita telemetria"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; RegName="AllowTelemetry"; Value=0}
    @{Name="Disabilita Cortana"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; RegName="AllowCortana"; Value=0}
    @{Name="Disabilita ID pubblicita'"; Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; RegName="Enabled"; Value=0}
    @{Name="Disabilita Timeline"; Command="Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'EnableActivityFeed' -Value 0; Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'PublishUserActivities' -Value 0; Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'UploadUserActivities' -Value 0"}
    @{Name="Disabilita feedback"; Path="HKCU:\SOFTWARE\Microsoft\Siuf\Rules"; RegName="NumberOfSIUFInPeriod"; Value=0}
    @{Name="Disabilita suggerimenti Start"; Command="Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338388Enabled' -Value 0; Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SilentInstalledAppsEnabled' -Value 0; Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SystemPaneSuggestionsEnabled' -Value 0"}
    @{Name="Disabilita consigli Microsoft Store"; Command="Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338389Enabled' -Value 0; Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338393Enabled' -Value 0; Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SoftLandingEnabled' -Value 0"}
    @{Name="Disabilita contenuti consigliati"; Command="Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'RotatingLockScreenEnabled' -Value 0; Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_TrackProgs' -Value 0; Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowFrequent' -Value 0"}
    @{Name="Disabilita localizzazione"; Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"; RegName="Value"; Value="Deny"; Type="String"}
    @{Name="Disabilita cloud content"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; RegName="DisableWindowsConsumerFeatures"; Value=1}
    @{Name="Disattiva accesso a app e suggerimenti"; Command="Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_TrackDocs' -Value 0; Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowCortanaButton' -Value 0"}
    @{Name="Disabilita riconoscimento vocale online"; Path="HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy"; RegName="HasAccepted"; Value=0}
    @{Name="Disabilita pubblicita' personalizzata"; Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; RegName="Enabled"; Value=0}
    @{Name="Disabilita suggerimenti nella schermata di blocco"; Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; RegName="RotatingLockScreenOverlayEnabled"; Value=0}
)

$perfTweaks = @(
    @{Name="Piano Prestazioni assolute"; Command="Enable-UltimatePerformance"}
    @{Name="Disabilita Game Bar"; Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"; RegName="AppCaptureEnabled"; Value=0}
    @{Name="Disabilita Game DVR"; Path="HKCU:\System\GameConfigStore"; RegName="GameDVR_Enabled"; Value=0}
    @{Name="Disabilita ibernazione"; Command="powercfg /hibernate off"}
    @{Name="Effetti visivi: prestazioni"; Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; RegName="VisualFXSetting"; Value=2}
    @{Name="Rimuovi ritardo avvio"; Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize"; RegName="StartupDelayInMSec"; Value=0}
    @{Name="Priorita' processore"; Path="HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"; RegName="Win32PrioritySeparation"; Value=38}
    @{Name="Riduci animazioni"; Path="HKCU:\Control Panel\Desktop\WindowMetrics"; RegName="MinAnimate"; Value="0"; Type="String"}
    @{Name="Disabilita trasparenza"; Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"; RegName="EnableTransparency"; Value=0}
    @{Name="Disattiva startup desktop lenta"; Command="Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Name 'StartupDelayInMSec' -Value 0; Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'LaunchTo' -Value 1"}
    @{Name="Disabilita animazioni shell (sicuro)"; Command="Set-RegistryValue -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask' -Value 62,14,3,128,48,0,0,0 -Type 'Binary'; Set-RegistryValue -Path 'HKCU:\Control Panel\Desktop' -Name 'MinAnimate' -Value 0 -Type 'String'"}
    @{Name="Disattiva suggerimenti di sistema"; Command="Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SystemPaneSuggestionsEnabled' -Value 0; Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SilentInstalledAppsEnabled' -Value 0"}
    @{Name="Disabilita app in background"; Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"; RegName="GlobalUserDisabled"; Value=1}
    @{Name="Blocca background search"; Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; RegName="BackgroundAppGlobalToggle"; Value=0}
    @{Name="Riduci polling di sistema"; Command="Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'ClearPageFileAtShutdown' -Value 0; Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableThumbsDBOnNetworkFolders' -Value 1"}
    @{Name="Disattiva manutenzione pianificata"; Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"; RegName="MaintenanceDisabled"; Value=1}
    @{Name="Disabilita sensibilita' CPU per app in background"; Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Power"; RegName="PowerThrottling"; Value=0}
    @{Name="Abilita pianificazione GPU hardware"; Path="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; RegName="HwSchMode"; Value=2}
    @{Name="Disabilita power throttling"; Path="HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"; RegName="PowerThrottlingOff"; Value=1}
    @{Name="Disabilita ultimo accesso NTFS"; Path="HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; RegName="NtfsDisableLastAccessUpdate"; Value=1}
)

$servicesList = @(
    @{Name="Telemetria"; Service="DiagTrack"; Type="Disabled"}
    @{Name="WAP Push"; Service="dmwappushservice"; Type="Disabled"}
    @{Name="Error Reporting"; Service="WerSvc"; Type="Manual"}
    @{Name="Fax"; Service="Fax"; Type="Disabled"}
    @{Name="Registro remoto"; Service="RemoteRegistry"; Type="Disabled"}
    @{Name="Mappe"; Service="MapsBroker"; Type="Manual"}
    @{Name="Geolocalizzazione"; Service="lfsvc"; Type="Manual"}
    @{Name="Link Tracking"; Service="TrkWks"; Type="Manual"}
    @{Name="WMP Network"; Service="WMPNetworkSvc"; Type="Disabled"}
    @{Name="Retail Demo"; Service="RetailDemo"; Type="Disabled"}
    @{Name="Xbox Auth"; Service="XblAuthManager"; Type="Manual"}
    @{Name="Xbox Save"; Service="XblGameSave"; Type="Manual"}
    @{Name="Xbox Network"; Service="XboxNetApiSvc"; Type="Manual"}
    @{Name="Telefono"; Service="PhoneSvc"; Type="Manual"}
    @{Name="Wallet"; Service="WalletService"; Type="Manual"}
    @{Name="Tablet Input"; Service="TabletInputService"; Type="Manual"}
    @{Name="Windows Search"; Service="WSearch"; Type="Manual"}
    @{Name="Delivery Optimization"; Service="DoSvc"; Type="Manual"}
    @{Name="Print Spooler"; Service="Spooler"; Type="Disabled"}
    @{Name="SysMain"; Service="SysMain"; Type="Disabled"}
    @{Name="Remote Desktop Services"; Service="TermService"; Type="Manual"}
    @{Name="Windows Mobile Hotspot"; Service="icssvc"; Type="Manual"}
    @{Name="Connected User Experiences"; Service="DiagTrack"; Type="Disabled"}
    @{Name="Remote Access Auto Connection"; Service="RasAuto"; Type="Manual"}
    @{Name="Windows Insider"; Service="wlidsvc"; Type="Manual"}
    @{Name="Windows Update Medic"; Service="WaaSMedicSvc"; Type="Manual"}
    @{Name="Device Association Service"; Service="DeviceAssociationService"; Type="Manual"}
    @{Name="Customer Experience Improvement"; Service="diagsvc"; Type="Manual"}
    @{Name="Contact Data"; Service="PhoneSvc"; Type="Manual"}
    @{Name="SysMain (Prefetch)"; Service="SysMain"; Type="Disabled"}
)

$wingetApps = @(
    @{Name="7-Zip"; Id="7zip.7zip"; Domain="7-zip.org"}
    @{Name="VLC"; Id="VideoLAN.VLC"; Domain="videolan.org"}
    @{Name="Chrome"; Id="Google.Chrome"; Domain="google.com"}
    @{Name="Firefox"; Id="Mozilla.Firefox"; Domain="mozilla.org"}
    @{Name="Notepad++"; Id="Notepad++.Notepad++"; Domain="notepad-plus-plus.org"}
    @{Name="PowerToys"; Id="Microsoft.PowerToys"; Domain="microsoft.com"}
    @{Name="VS Code"; Id="Microsoft.VisualStudioCode"; Domain="code.visualstudio.com"}
    @{Name="Git"; Id="Git.Git"; Domain="git-scm.com"}
    @{Name="Discord"; Id="Discord.Discord"; Domain="discord.com"}
    @{Name="Steam"; Id="Valve.Steam"; Domain="steampowered.com"}
    @{Name="qBittorrent"; Id="qBittorrent.qBittorrent"; Domain="qbittorrent.org"}
    @{Name="WinRAR"; Id="RARLab.WinRAR"; Domain="win-rar.com"}
    @{Name="Spotify"; Id="Spotify.Spotify"; Domain="spotify.com"}
    @{Name="Telegram"; Id="Telegram.TelegramDesktop"; Domain="telegram.org"}
    @{Name="Zoom"; Id="Zoom.Zoom"; Domain="zoom.us"}
    @{Name="OBS"; Id="OBSProject.OBSStudio"; Domain="obsproject.com"}
    @{Name="CPU-Z"; Id="CPUID.CPU-Z"; Domain="cpuid.com"}
    @{Name="Malwarebytes"; Id="Malwarebytes.Malwarebytes"; Domain="malwarebytes.com"}
    @{Name="Docker"; Id="Docker.DockerDesktop"; Domain="docker.com"}
    @{Name="Postman"; Id="Postman.Postman"; Domain="postman.com"}
    @{Name="Adobe Reader"; Id="Adobe.Acrobat.Reader.64-bit"; Domain="adobe.com"}
    @{Name="Bitwarden"; Id="Bitwarden.Bitwarden"; Domain="bitwarden.com"}
    @{Name="KeePassXC"; Id="KeePassXCTeam.KeePassXC"; Domain="keepassxc.org"}
    @{Name="Microsoft Teams"; Id="Microsoft.Teams"; Domain="microsoft.com"}
    @{Name="Signal"; Id="Signal.Signal"; Domain="signal.org"}
    @{Name="Slack"; Id="SlackTechnologies.Slack"; Domain="slack.com"}
    @{Name="WhatsApp"; Id="WhatsApp.WhatsApp"; Domain="whatsapp.com"}
    @{Name="Dropbox"; Id="Dropbox.Dropbox"; Domain="dropbox.com"}
    @{Name="Google Drive"; Id="Google.Drive"; Domain="google.com"}
    @{Name="OneDrive"; Id="Microsoft.OneDrive"; Domain="onedrive.live.com"}
    @{Name="LibreOffice"; Id="TheDocumentFoundation.LibreOffice"; Domain="libreoffice.org"}
    @{Name="Microsoft Office"; Id="Microsoft.Office"; Domain="office.com"}
    @{Name="Thunderbird"; Id="Mozilla.Thunderbird"; Domain="mozilla.org"}
    @{Name="GIMP"; Id="GIMP.GIMP"; Domain="gimp.org"}
    @{Name="Inkscape"; Id="Inkscape.Inkscape"; Domain="inkscape.org"}
    @{Name="Audacity"; Id="Audacity.Audacity"; Domain="audacityteam.org"}
    @{Name="OpenShot"; Id="OpenShot.OpenShot"; Domain="openshot.org"}
    @{Name="Blender"; Id="BlenderFoundation.Blender"; Domain="blender.org"}
    @{Name="Kdenlive"; Id="KDE.Kdenlive"; Domain="kdenlive.org"}
    @{Name="ShareX"; Id="ShareX.ShareX"; Domain="getsharex.com"}
    @{Name="TreeSize"; Id="JAMSoftware.TreeSize"; Domain="jam-software.com"}
    @{Name="Everything"; Id="voidtools.Everything"; Domain="voidtools.com"}
    @{Name="Windows Terminal"; Id="Microsoft.WindowsTerminal"; Domain="microsoft.com"}
    @{Name="WSL"; Id="Microsoft.WSL"; Domain="microsoft.com"}
    @{Name="Discord Canary"; Id="Discord.DiscordCanary"; Domain="discord.com"}
    @{Name="Steam Beta"; Id="Valve.Steam.Beta"; Domain="steampowered.com"}
    @{Name="Epic Games"; Id="EpicGames.EpicGamesLauncher"; Domain="epicgames.com"}
    @{Name="Ubisoft Connect"; Id="Ubisoft.Connect"; Domain="ubisoft.com"}
    @{Name="Xbox App"; Id="Microsoft.XboxApp"; Domain="xbox.com"}
    @{Name="EA App"; Id="ElectronicArts.EAApp"; Domain="ea.com"}
    @{Name="GOG Galaxy"; Id="GOG.Galaxy"; Domain="gog.com"}
    @{Name="League of Legends"; Id="RiotGames.LeagueOfLegends"; Domain="leagueoflegends.com"}
    @{Name="AnyDesk"; Id="AnyDesk.AnyDesk"; Domain="anydesk.com"}
    @{Name="Aseprite"; Id="Aseprite.Aseprite"; Domain="aseprite.org"}
    @{Name="Krita"; Id="KDE.Krita"; Domain="krita.org"}
    @{Name="Godot"; Id="GodotEngine.GodotEngine"; Domain="godotengine.org"}
    @{Name="GitHub Desktop"; Id="GitHub.GitHubDesktop"; Domain="github.com"}
    @{Name="Node.js"; Id="OpenJS.NodeJS.LTS"; Domain="nodejs.org"}
    @{Name="PyCharm"; Id="JetBrains.PyCharm.Community"; Domain="jetbrains.com"}
    @{Name="IntelliJ IDEA"; Id="JetBrains.IntelliJIDEA.Community"; Domain="jetbrains.com"}
    @{Name="TeamViewer"; Id="TeamViewer.TeamViewer"; Domain="teamviewer.com"}
    @{Name="RustDesk"; Id="Rustlang.RustDesk"; Domain="rustdesk.com"}
    @{Name="VirtualBox"; Id="Oracle.VirtualBox"; Domain="virtualbox.org"}
    @{Name="VMware Workstation"; Id="VMware.WorkstationPro"; Domain="vmware.com"}
    @{Name="Canon Print"; Id="Canon.Inkjet.Print"; Domain="canon.com"}
    @{Name="Tailscale"; Id="Tailscale.Tailscale"; Domain="tailscale.com"}
    @{Name="NVIDIA App"; Id="NVIDIA.GeForceExperience"; Domain="nvidia.com"}
    @{Name="Rufus"; Id="Rufus.Rufus"; Domain="rufus.ie"}
    @{Name="Ventoy"; Id="Ventoy.Ventoy"; Domain="ventoy.net"}
    @{Name="Heimdall"; Id="HeimdalSecurity.Heimdal"; Domain="heimdalsecurity.com"}
    @{Name="Mullvad"; Id="MullvadVPN.MullvadVPN"; Domain="mullvad.net"}
    @{Name="ProtonVPN"; Id="ProtonVPN.ProtonVPN"; Domain="protonvpn.com"}
    @{Name="1Password"; Id="AgileBits.1Password"; Domain="1password.com"}
    @{Name="Canva"; Id="Canva.Canva"; Domain="canva.com"}
    @{Name="Figma"; Id="Figma.Figma"; Domain="figma.com"}
    @{Name="Notion"; Id="Notion.Notion"; Domain="notion.so"}
    @{Name="Todoist"; Id="Doist.Todoist"; Domain="todoist.com"}
    @{Name="Microsoft To Do"; Id="Microsoft.Todos"; Domain="microsoft.com"}
    @{Name="Spotify for Artists"; Id="Spotify.SpotifyForArtists"; Domain="spotify.com"}
    @{Name="Miro"; Id="Miro.Miro"; Domain="miro.com"}
    @{Name="Perplexity"; Id="Perplexity.Perplexity"; Domain="perplexity.ai"}
    @{Name="Claude"; Id="Anthropic.Claude"; Domain="claude.ai"}
    @{Name="Brave"; Id="Brave.Brave"; Domain="brave.com"}
    @{Name="Opera"; Id="Opera.Opera"; Domain="opera.com"}
    @{Name="Vivaldi"; Id="VivaldiTechnologies.Vivaldi"; Domain="vivaldi.com"}
    @{Name="Arc"; Id="TheBrowserCompany.Arc"; Domain="arc.net"}
    @{Name="Tor Browser"; Id="TorProject.TorBrowser"; Domain="torproject.org"}
    @{Name="LibreWolf"; Id="LibreWolf.LibreWolf"; Domain="librewolf.net"}
    @{Name="Waterfox"; Id="Waterfox.Waterfox"; Domain="waterfox.net"}
    @{Name="Mullvad Browser"; Id="MullvadVPN.MullvadBrowser"; Domain="mullvad.net"}
    @{Name="Chromium"; Id="Hibbiki.Chromium"; Domain="chromium.org"}
    @{Name="DuckDuckGo Browser"; Id="DuckDuckGo.DesktopBrowser"; Domain="duckduckgo.com"}
    @{Name="Yandex Browser"; Id="Yandex.Browser"; Domain="yandex.com"}
    @{Name="Pale Moon"; Id="MoonchildProductions.PaleMoon"; Domain="palemoon.org"}
    @{Name="Floorp"; Id="Ablaze.Floorp"; Domain="floorp.app"}
    @{Name="Visual Studio Community"; Id="Microsoft.VisualStudio.2022.Community"; Domain="visualstudio.microsoft.com"}
    @{Name="WinSCP"; Id="WinSCP.WinSCP"; Domain="winscp.net"}
    @{Name="PuTTY"; Id="PuTTY.PuTTY"; Domain="putty.org"}
    @{Name="FileZilla"; Id="FileZilla.Client"; Domain="filezilla-project.org"}
    @{Name="HandBrake"; Id="HandBrake.HandBrake"; Domain="handbrake.fr"}
    @{Name="KeePass"; Id="KeePass.KeePass"; Domain="keepass.info"}
    @{Name="Joplin"; Id="Joplin.Joplin"; Domain="joplinapp.org"}
    @{Name="Arduino IDE"; Id="ArduinoSA.IDE.stable"; Domain="arduino.cc"}
    @{Name="MongoDB Compass"; Id="MongoDB.Compass.Full"; Domain="mongodb.com"}
)

$isoCatalog = @(
    @{Name='Windows 11'; Publisher='Microsoft'; Category='Desktop'; Detail='ISO ufficiale'; Url='https://www.microsoft.com/software-download/windows11'; Domain='microsoft.com'}
    @{Name='Windows 10'; Publisher='Microsoft'; Category='Desktop'; Detail='ISO ufficiale'; Url='https://www.microsoft.com/software-download/windows10'; Domain='microsoft.com'}
    @{Name='Ubuntu Desktop'; Publisher='Canonical'; Category='Desktop'; Detail='LTS e versioni recenti'; Url='https://ubuntu.com/download/desktop'; Domain='ubuntu.com'}
    @{Name='Linux Mint'; Publisher='Linux Mint'; Category='Desktop'; Detail='Cinnamon, MATE, Xfce'; Url='https://linuxmint.com/download.php'; Domain='linuxmint.com'}
    @{Name='Fedora Workstation'; Publisher='Fedora Project'; Category='Desktop'; Detail='Workstation'; Url='https://fedoraproject.org/workstation/download'; Domain='fedoraproject.org'}
    @{Name='Debian'; Publisher='Debian Project'; Category='Desktop'; Detail='Stable e netinstall'; Url='https://www.debian.org/distrib/'; Domain='debian.org'}
    @{Name='Arch Linux'; Publisher='Arch Linux'; Category='Desktop'; Detail='Rolling release'; Url='https://archlinux.org/download/'; Domain='archlinux.org'}
    @{Name='Kali Linux'; Publisher='Offensive Security'; Category='Security'; Detail='Penetration testing'; Url='https://www.kali.org/get-kali/'; Domain='kali.org'}
    @{Name='openSUSE'; Publisher='SUSE'; Category='Desktop'; Detail='Leap e Tumbleweed'; Url='https://get.opensuse.org/'; Domain='opensuse.org'}
    @{Name='Pop!_OS'; Publisher='System76'; Category='Desktop'; Detail='Desktop e sviluppo'; Url='https://pop.system76.com/'; Domain='system76.com'}
    @{Name='Zorin OS'; Publisher='Zorin Group'; Category='Desktop'; Detail='Semplice per iniziare'; Url='https://zorin.com/os/download/'; Domain='zorin.com'}
    @{Name='elementary OS'; Publisher='elementary'; Category='Desktop'; Detail='Desktop minimale'; Url='https://elementary.io/'; Domain='elementary.io'}
    @{Name='Manjaro'; Publisher='Manjaro Project'; Category='Desktop'; Detail='Arch-based'; Url='https://manjaro.org/products/download/x86'; Domain='manjaro.org'}
    @{Name='MX Linux'; Publisher='MX Linux'; Category='Desktop'; Detail='Leggero e stabile'; Url='https://mxlinux.org/download-links/'; Domain='mxlinux.org'}
    @{Name='Rocky Linux'; Publisher='Rocky Enterprise Software Foundation'; Category='Server'; Detail='Enterprise Linux'; Url='https://rockylinux.org/download'; Domain='rockylinux.org'}
    @{Name='AlmaLinux'; Publisher='AlmaLinux OS Foundation'; Category='Server'; Detail='Enterprise Linux'; Url='https://almalinux.org/get-almalinux/'; Domain='almalinux.org'}
    @{Name='TrueNAS SCALE'; Publisher='iXsystems'; Category='Server'; Detail='NAS e storage'; Url='https://www.truenas.com/download-tn-scale/'; Domain='truenas.com'}
    @{Name='Proxmox VE'; Publisher='Proxmox Server Solutions'; Category='Server'; Detail='Virtualizzazione'; Url='https://www.proxmox.com/en/downloads'; Domain='proxmox.com'}
    @{Name='Rescuezilla'; Publisher='Rescuezilla'; Category='Recovery'; Detail='Backup e recupero'; Url='https://rescuezilla.com/download'; Domain='rescuezilla.com'}
    @{Name='SystemRescue'; Publisher='SystemRescue'; Category='Recovery'; Detail='Diagnostica e recupero'; Url='https://www.system-rescue.org/Download/'; Domain='system-rescue.org'}
)

# ============================================================
#  COSTRUZIONE GUI
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "MoliOptimizer"
$form.Size = New-Object System.Drawing.Size(820, 560)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'None'
$form.ShowInTaskbar = $true
$form.BackColor = $script:BgColor
$form.Opacity = 0
$form.MinimumSize = New-Object System.Drawing.Size(700, 470)
$form.AutoScaleMode = 'Dpi'
$form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# ---- Titlebar ----
$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Dock = 'Top'
$titleBar.Height = 46
$titleBar.BackColor = $script:PanelColor2

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "MoliOptimizer"
$titleLabel.ForeColor = $script:TextColor
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(16, 12)
$titleLabel.AutoSize = $true

# Panel per i bottoni a destra (fisso)
$btnPanel = New-Object System.Windows.Forms.Panel
$btnPanel.Dock = 'Right'
$btnPanel.Width = 86
$btnPanel.BackColor = $script:PanelColor2
$btnPanel.Height = 46

# Pulsante minimizza (-)
$btnMin = New-Object DarkButton
$btnMin.Text = "-"
$btnMin.FlatStyle = 'Flat'
$btnMin.FlatAppearance.BorderSize = 0
$btnMin.ForeColor = $script:TextColor
$btnMin.BackColor = $script:PanelColor2
$btnMin.Size = New-Object System.Drawing.Size(43, 46)
$btnMin.Location = New-Object System.Drawing.Point(0, 0)
$btnMin.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$btnMin.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnMin.Add_MouseEnter({
    $btnMin.BackColor = $script:PanelColor
})
$btnMin.Add_MouseLeave({
    $btnMin.BackColor = $script:PanelColor2
})
$btnMin.Add_Click({ $form.WindowState = 'Minimized' })

# Pulsante di uscita (X) - ROSSO in hover
$btnExit = New-Object DarkButton
$btnExit.Text = "X"
$btnExit.FlatStyle = 'Flat'
$btnExit.FlatAppearance.BorderSize = 0
$btnExit.ForeColor = $script:TextColor
$btnExit.BackColor = $script:PanelColor2
$btnExit.Size = New-Object System.Drawing.Size(43, 46)
$btnExit.Location = New-Object System.Drawing.Point(43, 0)
$btnExit.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$btnExit.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnExit.Add_MouseEnter({
    $btnExit.BackColor = $script:DangerColor
    $btnExit.ForeColor = [System.Drawing.Color]::White
})
$btnExit.Add_MouseLeave({
    $btnExit.BackColor = $script:PanelColor2
    $btnExit.ForeColor = $script:TextColor
})
$btnExit.Add_Click({ $form.Close() })

$btnPanel.Controls.AddRange(@($btnMin, $btnExit))
$titleBar.Controls.Add($titleLabel)
$titleBar.Controls.Add($btnPanel)

# ---- TRASCINAMENTO ----
$script:dragging = $false
$script:dragCursor = $null
$script:dragForm = $null

# Funzione che crea gli eventi di drag per un controllo
function Add-DragEvents {
    param($control)
    $control.Add_MouseDown({
        param($sender, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            [NativeUI]::BeginWindowDrag($form.Handle)
        }
    }.GetNewClosure())
}

# Applica il trascinamento a titlebar e btnPanel
Add-DragEvents -control $titleBar
Add-DragEvents -control $btnPanel

# ---- Barra di navigazione ----
$navBar = New-Object System.Windows.Forms.Panel
$navBar.Dock = 'Top'
$navBar.Height = 62
$navBar.BackColor = $script:PanelColor2
$navBar.Padding = New-Object System.Windows.Forms.Padding(18, 10, 18, 10)

$btnNavOptim = New-Object DarkButton
$btnNavOptim.Text = "Ottimizzazioni"
$btnNavOptim.FlatStyle = 'Flat'
$btnNavOptim.FlatAppearance.BorderSize = 0
$btnNavOptim.FlatAppearance.MouseDownBackColor = $script:CardColor
$btnNavOptim.FlatAppearance.MouseOverBackColor = $script:CardHover
$btnNavOptim.UseVisualStyleBackColor = $false
$btnNavOptim.TabStop = $false
$btnNavOptim.ForeColor = $script:TextColor
$btnNavOptim.BackColor = $script:AccentColor
$btnNavOptim.Size = New-Object System.Drawing.Size(150, 32)
$btnNavOptim.Location = New-Object System.Drawing.Point(18, 14)
$btnNavOptim.Font = New-Object System.Drawing.Font("Segoe UI", 8.3, [System.Drawing.FontStyle]::Bold)
$btnNavOptim.Cursor = [System.Windows.Forms.Cursors]::Hand

$btnNavApps = New-Object DarkButton
$btnNavApps.Text = "App Store"
$btnNavApps.FlatStyle = 'Flat'
$btnNavApps.FlatAppearance.BorderSize = 0
$btnNavApps.FlatAppearance.MouseDownBackColor = $script:CardColor
$btnNavApps.FlatAppearance.MouseOverBackColor = $script:CardHover
$btnNavApps.UseVisualStyleBackColor = $false
$btnNavApps.TabStop = $false
$btnNavApps.ForeColor = $script:TextColorDim
$btnNavApps.BackColor = $script:CardColor
$btnNavApps.Size = New-Object System.Drawing.Size(150, 32)
$btnNavApps.Location = New-Object System.Drawing.Point(174, 14)
$btnNavApps.Font = New-Object System.Drawing.Font("Segoe UI", 8.3, [System.Drawing.FontStyle]::Bold)
$btnNavApps.Cursor = [System.Windows.Forms.Cursors]::Hand

$btnNavIso = New-Object DarkButton
$btnNavIso.Text = "ISO sistemi"
$btnNavIso.FlatStyle = 'Flat'
$btnNavIso.FlatAppearance.BorderSize = 0
$btnNavIso.FlatAppearance.MouseDownBackColor = $script:CardColor
$btnNavIso.FlatAppearance.MouseOverBackColor = $script:CardHover
$btnNavIso.UseVisualStyleBackColor = $false
$btnNavIso.TabStop = $false
$btnNavIso.ForeColor = $script:TextColorDim
$btnNavIso.BackColor = $script:CardColor
$btnNavIso.Size = New-Object System.Drawing.Size(150, 32)
$btnNavIso.Location = New-Object System.Drawing.Point(330, 14)
$btnNavIso.Font = New-Object System.Drawing.Font("Segoe UI", 8.3, [System.Drawing.FontStyle]::Bold)
$btnNavIso.Cursor = [System.Windows.Forms.Cursors]::Hand

$btnNavMemory = New-Object DarkButton
$btnNavMemory.Text = "Memoria"
$btnNavMemory.FlatStyle = 'Flat'
$btnNavMemory.FlatAppearance.BorderSize = 0
$btnNavMemory.FlatAppearance.MouseDownBackColor = $script:CardColor
$btnNavMemory.FlatAppearance.MouseOverBackColor = $script:CardHover
$btnNavMemory.UseVisualStyleBackColor = $false
$btnNavMemory.TabStop = $false
$btnNavMemory.ForeColor = $script:TextColorDim
$btnNavMemory.BackColor = $script:CardColor
$btnNavMemory.Size = New-Object System.Drawing.Size(150, 32)
$btnNavMemory.Location = New-Object System.Drawing.Point(486, 14)
$btnNavMemory.Font = New-Object System.Drawing.Font("Segoe UI", 8.3, [System.Drawing.FontStyle]::Bold)
$btnNavMemory.Cursor = [System.Windows.Forms.Cursors]::Hand

$navBar.Controls.AddRange(@($btnNavOptim, $btnNavApps, $btnNavIso, $btnNavMemory))

# ---- Contenitore principale ----
$contentSplit = New-Object System.Windows.Forms.SplitContainer
$contentSplit.Dock = 'Fill'
$contentSplit.Orientation = 'Horizontal'
$contentSplit.SplitterDistance = 360
$contentSplit.BackColor = $script:BgColor
$contentSplit.SplitterWidth = 2
$contentSplit.Panel1.BackColor = $script:BgColor
$contentSplit.Panel2.BackColor = $script:BgColor

$panelOptim = New-Object System.Windows.Forms.Panel
$panelOptim.Dock = 'Fill'
$panelOptim.BackColor = $script:BgColor
$panelOptim.Visible = $true
$panelOptim.Padding = New-Object System.Windows.Forms.Padding(10)

$panelApps = New-Object System.Windows.Forms.Panel
$panelApps.Dock = 'Fill'
$panelApps.BackColor = $script:BgColor
$panelApps.Visible = $false
$panelApps.Padding = New-Object System.Windows.Forms.Padding(10)

$panelIso = New-Object System.Windows.Forms.Panel
$panelIso.Dock = 'Fill'
$panelIso.BackColor = $script:BgColor
$panelIso.Visible = $false
$panelIso.Padding = New-Object System.Windows.Forms.Padding(10)

$panelMemory = New-Object System.Windows.Forms.Panel
$panelMemory.Dock = 'Fill'
$panelMemory.BackColor = $script:BgColor
$panelMemory.Visible = $false
$panelMemory.Padding = New-Object System.Windows.Forms.Padding(10)

function Set-ActiveNavigation {
    param([ValidateSet('Optim','Apps','Iso','Memory')][string]$Section)
    $script:navOptimActive = ($Section -eq 'Optim')
    $script:navAppsActive = ($Section -eq 'Apps')
    $script:navIsoActive = ($Section -eq 'Iso')
    $script:navMemoryActive = ($Section -eq 'Memory')
    $btnNavOptim.BackColor = if ($script:navOptimActive) { $script:AccentColor } else { $script:CardColor }
    $btnNavOptim.ForeColor = if ($script:navOptimActive) { $script:TextColor } else { $script:TextColorDim }
    $btnNavApps.BackColor = if ($script:navAppsActive) { $script:AccentColor } else { $script:CardColor }
    $btnNavApps.ForeColor = if ($script:navAppsActive) { $script:TextColor } else { $script:TextColorDim }
    $btnNavIso.BackColor = if ($script:navIsoActive) { $script:AccentColor } else { $script:CardColor }
    $btnNavIso.ForeColor = if ($script:navIsoActive) { $script:TextColor } else { $script:TextColorDim }
    $btnNavMemory.BackColor = if ($script:navMemoryActive) { $script:AccentColor } else { $script:CardColor }
    $btnNavMemory.ForeColor = if ($script:navMemoryActive) { $script:TextColor } else { $script:TextColorDim }
}

function Refresh-NavigationColors {
    $activeSection = if ($panelOptim.Visible) { 'Optim' } elseif ($panelApps.Visible) { 'Apps' } elseif ($panelIso.Visible) { 'Iso' } else { 'Memory' }
    Set-ActiveNavigation -Section $activeSection
}

$btnNavOptim.Add_Click({ 
    $panelOptim.Visible = $true
    $panelApps.Visible = $false
    $panelIso.Visible = $false
    $panelMemory.Visible = $false
    Refresh-NavigationColors
})

$btnNavApps.Add_Click({ 
    $panelOptim.Visible = $false
    $panelApps.Visible = $true
    $panelIso.Visible = $false
    $panelMemory.Visible = $false
    Refresh-NavigationColors
})

$btnNavIso.Add_Click({
    $panelOptim.Visible = $false
    $panelApps.Visible = $false
    $panelIso.Visible = $true
    $panelMemory.Visible = $false
    Refresh-NavigationColors
})

$btnNavMemory.Add_Click({
    $panelOptim.Visible = $false
    $panelApps.Visible = $false
    $panelIso.Visible = $false
    $panelMemory.Visible = $true
    Refresh-NavigationColors
})

# ---- TAB BAR + CONTENUTO ----
# Barra tab custom: niente TabControl nativo = niente area bianca di WinForms.
$tabHost = New-Object System.Windows.Forms.Panel
$tabHost.Dock = 'Fill'
$tabHost.BackColor = $script:BgColor
$tabHost.Padding = New-Object System.Windows.Forms.Padding(22, 0, 22, 0)

$tabHeader = New-Object System.Windows.Forms.Panel
$tabHeader.Dock = 'Top'
$tabHeader.Height = 40
$tabHeader.BackColor = $script:PanelColor

$tabContent = New-Object System.Windows.Forms.Panel
$tabContent.Dock = 'Fill'
$tabContent.BackColor = $script:CardColor

$script:currentListBox = $null
$script:currentTabName = "Debloat"

function New-TabButton {
    param([string]$Text,[int]$Index)
    $btn = New-Object DarkButton
    $btn.Text = $Text
    $btn.Tag = $Index
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 0
    $btn.FlatAppearance.MouseDownBackColor = $script:CardColor
    $btn.FlatAppearance.MouseOverBackColor = $script:CardHover
    $btn.UseVisualStyleBackColor = $false
    $btn.TabStop = $false
    $btn.BackColor = $script:PanelColor
    $btn.ForeColor = $script:TextColorDim
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn
}

$tabButtons = @(
    (New-TabButton "Debloat" 0),
    (New-TabButton "Privacy" 1),
    (New-TabButton "Prestazioni" 2),
    (New-TabButton "Servizi" 3),
    (New-TabButton "Avvio" 4),
    (New-TabButton "Ripristino" 5)
)

$script:tabButtons = $tabButtons

function Update-TabButtonLayout {
    $available = [Math]::Max(500, $tabHeader.ClientSize.Width)
    $width = [Math]::Floor($available / 6)
    for ($i=0; $i -lt 6; $i++) {
        $tabButtons[$i].Size = New-Object System.Drawing.Size($width,40)
        $tabButtons[$i].Location = New-Object System.Drawing.Point(($i*$width),0)
        $tabButtons[$i].Font = New-Object System.Drawing.Font("Segoe UI", 8.2, [System.Drawing.FontStyle]::Bold)
    }
    if ($script:tabIndicator) {
        $script:tabIndicator.Width = $width
        $script:tabIndicator.Location = New-Object System.Drawing.Point($script:tabIndicator.Left, ($tabHeader.ClientSize.Height - $script:tabIndicator.Height))
    }
}

foreach ($btn in $tabButtons) { $tabHeader.Controls.Add($btn) }

$script:tabIndicator = New-Object System.Windows.Forms.Panel
$script:tabIndicator.Height = 3
$script:tabIndicator.BackColor = $script:AccentColor
$tabHeader.Controls.Add($script:tabIndicator)
$script:tabIndicator.BringToFront()

# Pannelli contenuto
$tabDebloat = New-Object System.Windows.Forms.Panel
$tabDebloat.Dock = 'Fill'
$tabDebloat.BackColor = $script:CardColor

$listDebloat = New-Object DarkCheckedListBox
$listDebloat.Dock = 'Fill'
$listDebloat.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$listDebloat.CheckOnClick = $true
$listDebloat.ScrollAlwaysVisible = $false
$listDebloat.IntegralHeight = $false
Style-DarkCheckedListBox -List $listDebloat
foreach ($name in $debloatApps.Keys) { [void]$listDebloat.Items.Add($name) }
$tabDebloat.Controls.Add($listDebloat)

$tabPrivacy = New-Object System.Windows.Forms.Panel
$tabPrivacy.Dock = 'Fill'
$tabPrivacy.BackColor = $script:CardColor
$tabPrivacy.Visible = $false

$listPrivacy = New-Object DarkCheckedListBox
$listPrivacy.Dock = 'Fill'
$listPrivacy.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$listPrivacy.CheckOnClick = $true
$listPrivacy.ScrollAlwaysVisible = $false
$listPrivacy.IntegralHeight = $false
Style-DarkCheckedListBox -List $listPrivacy
$script:privacyTweakData = @()
foreach ($t in $privacyTweaks) {
    [void]$listPrivacy.Items.Add("[$(Get-OptimizationLevel $t.Name)] $($t.Name)")
    $script:privacyTweakData += $t
}
$tabPrivacy.Controls.Add($listPrivacy)

$tabPerf = New-Object System.Windows.Forms.Panel
$tabPerf.Dock = 'Fill'
$tabPerf.BackColor = $script:CardColor
$tabPerf.Visible = $false

$listPerf = New-Object DarkCheckedListBox
$listPerf.Dock = 'Fill'
$listPerf.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$listPerf.CheckOnClick = $true
$listPerf.ScrollAlwaysVisible = $false
$listPerf.IntegralHeight = $false
Style-DarkCheckedListBox -List $listPerf
$script:perfTweakData = @()
foreach ($t in $perfTweaks) {
    [void]$listPerf.Items.Add("[$(Get-OptimizationLevel $t.Name)] $($t.Name)")
    $script:perfTweakData += $t
}
$tabPerf.Controls.Add($listPerf)

$tabServices = New-Object System.Windows.Forms.Panel
$tabServices.Dock = 'Fill'
$tabServices.BackColor = $script:CardColor
$tabServices.Visible = $false

$listServices = New-Object DarkCheckedListBox
$listServices.Dock = 'Fill'
$listServices.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$listServices.CheckOnClick = $true
$listServices.ScrollAlwaysVisible = $false
$listServices.IntegralHeight = $false
Style-DarkCheckedListBox -List $listServices
$script:servicesData = @()
foreach ($svc in $servicesList) {
    [void]$listServices.Items.Add("[$(Get-OptimizationLevel $svc.Name)] $($svc.Name)")
    $script:servicesData += $svc
}

$listPrivacy.Add_ItemCheck({
    param($sender, $e)
    if ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked) {
        $name = $script:privacyTweakData[$e.Index].Name
        if ($name -eq "Disabilita localizzazione") { Show-OptimizationWarningOnce -Name $name -Warning "Mappe e funzioni basate sulla posizione potrebbero smettere di funzionare." }
    }
})
$listPerf.Add_ItemCheck({
    param($sender, $e)
    if ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked) {
        $name = $script:perfTweakData[$e.Index].Name
        if ($name -eq "Disabilita app in background") { Show-OptimizationWarningOnce -Name $name -Warning "Le app potrebbero aggiornarsi o notificare solo quando sono in primo piano." }
        if ($name -eq "Blocca background search") { Show-OptimizationWarningOnce -Name $name -Warning "La ricerca di Windows potrebbe essere incompleta o meno aggiornata." }
        if ($name -eq "Disabilita ibernazione") { Save-PowerBackup }
        if ($name -eq "Piano Prestazioni assolute") { Save-PowerBackup }
    }
})
$listServices.Add_ItemCheck({
    param($sender, $e)
    if ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked) {
        $name = $script:servicesData[$e.Index].Name
        if ($name -eq "Print Spooler") { Show-OptimizationWarningOnce -Name $name -Warning "La stampa non funzionera' finche' il servizio resta disabilitato." }
        if ($name -eq "Windows Search") { Show-OptimizationWarningOnce -Name $name -Warning "La ricerca indicizzata potrebbe essere lenta o incompleta." }
        if ($name -eq "Tablet Input") { Show-OptimizationWarningOnce -Name $name -Warning "Tastiera touch, penna e alcune funzioni di input potrebbero non funzionare." }
    }
})
$tabServices.Controls.Add($listServices)

$tabStartup = New-Object System.Windows.Forms.Panel
$tabStartup.Dock = 'Fill'
$tabStartup.BackColor = $script:CardColor
$tabStartup.Visible = $false

$listStartup = New-Object DarkCheckedListBox
$listStartup.Dock = 'Fill'
$listStartup.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$listStartup.CheckOnClick = $true
$listStartup.ScrollAlwaysVisible = $false
$listStartup.IntegralHeight = $false
Style-DarkCheckedListBox -List $listStartup
$script:startupData = @()
$startupApps = Get-StartupApps
if ($startupApps.Count -eq 0) {
    [void]$listStartup.Items.Add("Nessuna voce trovata")
    $listStartup.Enabled = $false
} else {
    foreach ($item in $startupApps) {
        [void]$listStartup.Items.Add("$($item.Name) [$($item.Hive)]")
        $script:startupData += $item
    }
}
$tabStartup.Controls.Add($listStartup)

$tabRestore = New-Object System.Windows.Forms.Panel
$tabRestore.Dock = 'Fill'
$tabRestore.BackColor = $script:CardColor
$restoreInfo = New-Object System.Windows.Forms.Label
$restoreInfo.Text = "Ripristina tutte le ottimizzazioni di registro, servizi, avvio e alimentazione salvate da MoliOptimizer.`r`nLe app rimosse con Debloat richiedono reinstallazione."
$restoreInfo.ForeColor = $script:TextColorDim
$restoreInfo.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$restoreInfo.Location = New-Object System.Drawing.Point(24, 28)
$restoreInfo.Size = New-Object System.Drawing.Size(500, 52)
$restoreButton = New-Object DarkButton
$restoreButton.Text = "Ripristina tutte le ottimizzazioni"
$restoreButton.FlatStyle = 'Flat'
$restoreButton.FlatAppearance.BorderSize = 0
$restoreButton.ForeColor = [System.Drawing.Color]::White
$restoreButton.BackColor = $script:DangerColor
$restoreButton.Size = New-Object System.Drawing.Size(260, 34)
$restoreButton.Location = New-Object System.Drawing.Point(24, 96)
$restoreButton.Font = New-Object System.Drawing.Font("Segoe UI", 8.2, [System.Drawing.FontStyle]::Bold)
$restoreButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$restoreButton.Add_Click({
    if (Confirm-RestoreAction -Title "Ripristina tutte le ottimizzazioni" -Message "Riportare registro, servizi, avvio e alimentazione allo stato salvato prima dei tweak?" -ConfirmText "Ripristina") { Restore-OptimizationBackup }
})
$defaultButton = New-Object DarkButton
$defaultButton.Text = "Ripristina impostazioni default"
$defaultButton.FlatStyle = 'Flat'
$defaultButton.FlatAppearance.BorderSize = 0
$defaultButton.ForeColor = $script:TextColor
$defaultButton.BackColor = $script:PanelColor
$defaultButton.Size = New-Object System.Drawing.Size(260, 34)
$defaultButton.Location = New-Object System.Drawing.Point(294, 96)
$defaultButton.Font = New-Object System.Drawing.Font("Segoe UI", 8.2, [System.Drawing.FontStyle]::Bold)
$defaultButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$defaultButton.Add_Click({
    if (Confirm-RestoreAction -Title "Ripristina impostazioni default" -Message "Questa operazione annulla i tweak e puo' rimuovere personalizzazioni manuali. Continuare?" -ConfirmText "Ripristina default") { Restore-WindowsDefaultSettings }
})
$tabRestore.Controls.AddRange(@($restoreInfo, $restoreButton, $defaultButton))

$tabMemory = New-Object System.Windows.Forms.Panel
$tabMemory.Dock = 'Fill'
$tabMemory.BackColor = $script:CardColor
$tabMemory.Visible = $false

$memoryTitle = New-Object System.Windows.Forms.Label
$memoryTitle.Text = "Memoria fisica"
$memoryTitle.ForeColor = $script:TextColor
$memoryTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$memoryTitle.Location = New-Object System.Drawing.Point(24, 22)
$memoryTitle.Size = New-Object System.Drawing.Size(300, 28)

$memorySubtitle = New-Object System.Windows.Forms.Label
$memorySubtitle.Text = "Panoramica della RAM fisica e pulizia delle aree temporanee di Windows"
$memorySubtitle.ForeColor = $script:TextColorDim
$memorySubtitle.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$memorySubtitle.Location = New-Object System.Drawing.Point(24, 50)
$memorySubtitle.Size = New-Object System.Drawing.Size(620, 22)

$script:memoryTotalLabel = New-Object System.Windows.Forms.Label
$script:memoryTotalLabel.ForeColor = $script:TextColorDim
$script:memoryTotalLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8.8)
$script:memoryTotalLabel.Location = New-Object System.Drawing.Point(24, 84)
$script:memoryTotalLabel.Size = New-Object System.Drawing.Size(190, 24)

$script:memoryUsedLabel = New-Object System.Windows.Forms.Label
$script:memoryUsedLabel.ForeColor = $script:DangerColor
$script:memoryUsedLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8.8, [System.Drawing.FontStyle]::Bold)
$script:memoryUsedLabel.Location = New-Object System.Drawing.Point(225, 84)
$script:memoryUsedLabel.Size = New-Object System.Drawing.Size(190, 24)

$script:memoryFreeLabel = New-Object System.Windows.Forms.Label
$script:memoryFreeLabel.ForeColor = $script:AccentColor
$script:memoryFreeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8.8, [System.Drawing.FontStyle]::Bold)
$script:memoryFreeLabel.Location = New-Object System.Drawing.Point(426, 84)
$script:memoryFreeLabel.Size = New-Object System.Drawing.Size(190, 24)

$script:memoryMeter = New-Object System.Windows.Forms.Panel
$script:memoryMeter.BackColor = $script:AccentColor
$script:memoryMeter.Location = New-Object System.Drawing.Point(24, 116)
$script:memoryMeter.Size = New-Object System.Drawing.Size(592, 22)
$script:memoryMeter.Tag = 0.0
$script:memoryMeter.Add_Paint({
    param($sender, $e)
    $ratio = [Math]::Max(0.0, [Math]::Min(1.0, [double]$sender.Tag))
    $usedWidth = [int]($sender.ClientSize.Width * $ratio)
    $freeBrush = New-Object System.Drawing.SolidBrush($script:AccentColor)
    $e.Graphics.FillRectangle($freeBrush, 0, 0, $sender.ClientSize.Width, $sender.ClientSize.Height)
    $freeBrush.Dispose()
    if ($usedWidth -gt 0) {
        $usedBrush = New-Object System.Drawing.SolidBrush($script:DangerColor)
        $e.Graphics.FillRectangle($usedBrush, 0, 0, $usedWidth, $sender.ClientSize.Height)
        $usedBrush.Dispose()
    }
})

$tabMemory.Add_Resize({
    $width = [Math]::Max(240, $tabMemory.ClientSize.Width - 48)
    $script:memoryMeter.Width = $width
    $script:memoryFreeLabel.Left = [Math]::Max(426, $width - 190)
}.GetNewClosure())


$memoryScope = New-Object System.Windows.Forms.Label
$memoryScope.Text = "Pulisce cache registro, file modificati, standby, pagine combinate, cache file di sistema e working set."
$memoryScope.ForeColor = $script:TextColorDim
$memoryScope.Font = New-Object System.Drawing.Font("Segoe UI", 8.2)
$memoryScope.Location = New-Object System.Drawing.Point(24, 218)
$memoryScope.Size = New-Object System.Drawing.Size(600, 38)

$memoryButton = New-Object DarkButton
$memoryButton.Text = "Ottimizza"
$memoryButton.FlatStyle = 'Flat'
$memoryButton.FlatAppearance.BorderSize = 0
$memoryButton.ForeColor = [System.Drawing.Color]::White
$memoryButton.BackColor = $script:AccentColor
$memoryButton.Size = New-Object System.Drawing.Size(150, 34)
$memoryButton.Location = New-Object System.Drawing.Point(24, 176)
$memoryButton.Font = New-Object System.Drawing.Font("Segoe UI", 8.8, [System.Drawing.FontStyle]::Bold)
$memoryButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$memoryButton.Add_Click({ Invoke-MemoryOptimization })
$tabMemory.Controls.AddRange(@($memoryTitle, $memorySubtitle, $script:memoryTotalLabel, $script:memoryUsedLabel, $script:memoryFreeLabel, $script:memoryMeter, $memoryLegend, $memoryButton, $memoryScope))
$tabMemory.Dock = 'Fill'
$tabMemory.Visible = $true
$panelMemory.Controls.Add($tabMemory)

$script:tabPanels = @($tabDebloat,$tabPrivacy,$tabPerf,$tabServices,$tabStartup,$tabRestore)
$script:tabLists = @($listDebloat,$listPrivacy,$listPerf,$listServices,$listStartup,$null)
$script:tabNames = @("Debloat","Privacy","Prestazioni","Servizi","Avvio","Ripristino")

$tabContent.Controls.AddRange(@($tabDebloat,$tabPrivacy,$tabPerf,$tabServices,$tabStartup,$tabRestore))
$tabHost.Controls.Add($tabContent)
$tabHost.Controls.Add($tabHeader)

function Set-ActiveTab {
    param([int]$Index)
    for ($i=0; $i -lt 6; $i++) {
        $active = ($i -eq $Index)
        $script:tabPanels[$i].Visible = $active
        $script:tabButtons[$i].BackColor = if ($active) { $script:CardColor } else { $script:PanelColor }
        $script:tabButtons[$i].ForeColor = if ($active) { $script:AccentColor } else { $script:TextColorDim }
        $script:tabButtons[$i].Font = if ($active) {
            New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        } else {
            New-Object System.Drawing.Font("Segoe UI", 10)
        }
    }
    $script:currentListBox = $script:tabLists[$Index]
    $script:currentTabName = $script:tabNames[$Index]
    if ($btnApplyOptim -and $btnDeselectOptim -and $btnSelectOptim -and $optimBottom) {
        $optimBottom.Visible = ($Index -ne 5)
        $btnApplyOptim.Visible = ($Index -ne 5)
        $btnDeselectOptim.Visible = ($Index -ne 5)
        $btnSelectOptim.Visible = ($Index -ne 5)
    }
    $script:tabIndicator.Width = $script:tabButtons[$Index].Width
    $script:tabIndicator.Left = $script:tabButtons[$Index].Left
    $script:tabIndicator.Top = $tabHeader.ClientSize.Height - $script:tabIndicator.Height
    $script:tabIndicator.BringToFront()
}

for ($i=0; $i -lt 6; $i++) {
    $index = $i
    $script:tabButtons[$i].Add_Click({
        Set-ActiveTab -Index ([int]$this.Tag)
    }.GetNewClosure())
}

$tabHeader.Add_Resize({
    Update-TabButtonLayout
}.GetNewClosure())

Update-TabButtonLayout
Set-ActiveTab -Index 0

# ---- PULSANTI BOTTOM - OTTIMIZZAZIONI ----
$optimBottom = New-Object System.Windows.Forms.Panel
$optimBottom.Dock = 'Bottom'
$optimBottom.Height = 54
$optimBottom.BackColor = $script:BgColor
$optimBottom.Padding = New-Object System.Windows.Forms.Padding(16, 8, 16, 8)

function Clear-OptimizationSelections {
    foreach ($listBox in $script:tabLists) {
        if (-not $listBox) { continue }
        $count = $listBox.Items.Count
        for ($i = 0; $i -lt $count; $i++) {
            try { $listBox.SetItemChecked($i, $false) } catch {}
        }
    }
}

$btnApplyOptim = New-Object DarkButton
$btnApplyOptim.Text = "Applica selezionati"
$btnApplyOptim.FlatStyle = 'Flat'
$btnApplyOptim.FlatAppearance.BorderSize = 0
$btnApplyOptim.ForeColor = [System.Drawing.Color]::White
$btnApplyOptim.BackColor = $script:AccentColor
$btnApplyOptim.Size = New-Object System.Drawing.Size(150, 30)
$btnApplyOptim.Location = New-Object System.Drawing.Point(16, 10)
$btnApplyOptim.Font = New-Object System.Drawing.Font("Segoe UI", 8.2, [System.Drawing.FontStyle]::Bold)
$btnApplyOptim.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnApplyOptim.Add_Click({
    Write-Log "=== Applico ottimizzazioni ==="
    
    # Debloat
    foreach ($index in $listDebloat.CheckedIndices) {
        $name = $listDebloat.Items[$index]
        $package = $debloatApps[$name]
        try { 
            Remove-Bloatware -PackageName $package
            Write-LogDetail -Operation "Rimozione app" -Target $name -Detail "Package: $package" -Status OK
        } catch { 
            Write-LogDetail -Operation "Rimozione app" -Target $name -Detail "Package: $package" -Status ERRORE -ErrorMsg $_
        }
    }
    
    # Privacy
    foreach ($index in $listPrivacy.CheckedIndices) {
        $name = $listPrivacy.Items[$index]
        $tweak = $script:privacyTweakData[$index]
        try { 
            Save-TweakBackup -Tweak $tweak
            $action = New-TweakAction -Tweak $tweak
            & $action
            $detail = if ($tweak.Path) { "Path: $($tweak.Path), RegName: $($tweak.RegName), Value: $($tweak.Value)" } else { "Comando eseguito" }
            Write-LogDetail -Operation "Privacy" -Target $name -Detail $detail -Status OK
        } catch { 
            Write-LogDetail -Operation "Privacy" -Target $name -Status ERRORE -ErrorMsg $_
        }
    }
    
    # Prestazioni
    foreach ($index in $listPerf.CheckedIndices) {
        $name = $listPerf.Items[$index]
        $tweak = $script:perfTweakData[$index]
        try { 
            Save-TweakBackup -Tweak $tweak
            if ($name -eq "Piano Prestazioni assolute" -or $name -eq "Disabilita ibernazione") { Save-PowerBackup }
            $action = New-TweakAction -Tweak $tweak
            & $action
            $detail = if ($tweak.Path) { "Path: $($tweak.Path), RegName: $($tweak.RegName), Value: $($tweak.Value)" } else { "Comando eseguito" }
            Write-LogDetail -Operation "Prestazioni" -Target $name -Detail $detail -Status OK
        } catch { 
            Write-LogDetail -Operation "Prestazioni" -Target $name -Status ERRORE -ErrorMsg $_
        }
    }
    
    # Servizi
    foreach ($index in $listServices.CheckedIndices) {
        $name = $listServices.Items[$index]
        $svcData = $script:servicesData[$index]
        try { 
            $svc = Get-Service -Name $svcData.Service -ErrorAction SilentlyContinue
            if ($svc) {
                if (-not $script:optimizationBackup.Services.ContainsKey($svcData.Service)) {
                    $script:optimizationBackup.Services[$svcData.Service] = @{ Name = $svcData.Service; StartType = $svc.StartType; Status = $svc.Status.ToString() }
                    Save-OptimizationBackup
                }
                $oldStatus = $svc.Status
                $oldStartup = $svc.StartType
                Set-Service -Name $svcData.Service -StartupType $svcData.Type -ErrorAction Stop
                if ($svcData.Type -eq 'Disabled' -and $svc.Status -eq 'Running') {
                    Stop-Service -Name $svcData.Service -Force -ErrorAction SilentlyContinue
                }
                $newStatus = (Get-Service -Name $svcData.Service -ErrorAction SilentlyContinue).Status
                Write-LogDetail -Operation "Servizio" -Target $name -Detail "impostato su $($svcData.Type) (prima: $oldStartup, stato: $oldStatus -> $newStatus)" -Status OK
            } else {
                Write-LogDetail -Operation "Servizio" -Target $name -Status ERRORE -ErrorMsg "Servizio non trovato"
            }
        } catch { 
            Write-LogDetail -Operation "Servizio" -Target $name -Status ERRORE -ErrorMsg $_
        }
    }
    
    # Avvio
    foreach ($index in $listStartup.CheckedIndices) {
        $item = $script:startupData[$index]
        try { 
            $approvedPath = if ($item.Hive -eq 'HKLM') { "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" } else { "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" }
            if (-not $script:optimizationBackup.Startup.ContainsKey("$($item.Hive)|$($item.Name)")) {
                $approvedValue = $null
                if (Test-Path $approvedPath) { $approvedValue = (Get-ItemProperty -Path $approvedPath -Name $item.Name -ErrorAction SilentlyContinue).$($item.Name) }
                $script:optimizationBackup.Startup["$($item.Hive)|$($item.Name)"] = @{ Path = $approvedPath; Name = $item.Name; Value = $approvedValue; Exists = ($null -ne $approvedValue) }
                Save-OptimizationBackup
            }
            Disable-StartupItem -Hive $item.Hive -ValueName $item.Name
        } catch { 
            Write-LogDetail -Operation "Avvio automatico" -Target $item.Name -Status ERRORE -ErrorMsg $_
        }
    }
    
    Write-Log "=== Completato ==="
    Clear-OptimizationSelections
    Write-Log "Selezione azzerata: puoi riapplicare nuove ottimizzazioni."
})

$btnDeselectOptim = New-Object DarkButton
$btnDeselectOptim.Text = "Deseleziona tutto"
$btnDeselectOptim.FlatStyle = 'Flat'
$btnDeselectOptim.FlatAppearance.BorderSize = 0
$btnDeselectOptim.ForeColor = $script:TextColor
$btnDeselectOptim.BackColor = $script:PanelColor
$btnDeselectOptim.Size = New-Object System.Drawing.Size(150, 30)
$btnDeselectOptim.Location = New-Object System.Drawing.Point(176, 10)
$btnDeselectOptim.Font = New-Object System.Drawing.Font("Segoe UI", 8.2, [System.Drawing.FontStyle]::Bold)
$btnDeselectOptim.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnDeselectOptim.Add_Click({
    $listBox = $script:currentListBox
    if ($listBox) {
        $count = $listBox.Items.Count
        for ($i = 0; $i -lt $count; $i++) {
            $listBox.SetItemChecked($i, $false)
        }
        Write-Log "Deselezionati tutti gli elementi in '$($script:currentTabName)'"
    }
})

$btnSelectOptim = New-Object DarkButton
$btnSelectOptim.Text = "Seleziona tutto"
$btnSelectOptim.FlatStyle = 'Flat'
$btnSelectOptim.FlatAppearance.BorderSize = 0
$btnSelectOptim.ForeColor = $script:TextColor
$btnSelectOptim.BackColor = $script:PanelColor
$btnSelectOptim.Size = New-Object System.Drawing.Size(150, 30)
$btnSelectOptim.Location = New-Object System.Drawing.Point(336, 10)
$btnSelectOptim.Font = New-Object System.Drawing.Font("Segoe UI", 8.2, [System.Drawing.FontStyle]::Bold)
$btnSelectOptim.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnSelectOptim.Add_Click({
    $listBox = $script:currentListBox
    if ($listBox) {
        $count = $listBox.Items.Count
        for ($i = 0; $i -lt $count; $i++) {
            $listBox.SetItemChecked($i, $true)
        }
        Write-Log "Selezionati tutti gli elementi in '$($script:currentTabName)'"
    }
})

$optimBottom.Controls.AddRange(@($btnApplyOptim, $btnDeselectOptim, $btnSelectOptim))
$panelOptim.Controls.Add($tabHost)
$panelOptim.Controls.Add($optimBottom)

$memoryTimer = New-Object System.Windows.Forms.Timer
$memoryTimer.Interval = 1000
$memoryTimer.Add_Tick({ Update-MemoryDisplay }.GetNewClosure())
Update-MemoryDisplay


# ---- FINITURE / ANIMAZIONI ----

$script:navOptimActive = $true
$script:navAppsActive = $false
$script:navIsoActive = $false
$script:navMemoryActive = $false
$btnNavOptim.Add_MouseEnter({ if (-not $panelOptim.Visible) { $btnNavOptim.BackColor = $script:CardHover } })
$btnNavOptim.Add_MouseLeave({ Refresh-NavigationColors })
$btnNavApps.Add_MouseEnter({ if (-not $panelApps.Visible) { $btnNavApps.BackColor = $script:CardHover } })
$btnNavApps.Add_MouseLeave({ Refresh-NavigationColors })
$btnNavIso.Add_MouseEnter({ if (-not $panelIso.Visible) { $btnNavIso.BackColor = $script:CardHover } })
$btnNavIso.Add_MouseLeave({ Refresh-NavigationColors })
$btnNavMemory.Add_MouseEnter({ if (-not $panelMemory.Visible) { $btnNavMemory.BackColor = $script:CardHover } })
$btnNavMemory.Add_MouseLeave({ Refresh-NavigationColors })
Add-SmoothHover -Control $btnApplyOptim -NormalColor $script:AccentColor -HoverColor $script:AccentHover
Add-SmoothHover -Control $btnDeselectOptim -NormalColor $script:PanelColor -HoverColor $script:CardHover
Add-SmoothHover -Control $btnSelectOptim -NormalColor $script:PanelColor -HoverColor $script:CardHover

# ---- APP STORE ----
$appsFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$appsFlow.Dock = 'Fill'
$appsFlow.AutoScroll = $true
$appsFlow.BackColor = $script:BgColor
$appsFlow.Padding = New-Object System.Windows.Forms.Padding(10)
$appsFlow.FlowDirection = 'TopDown'
$appsFlow.WrapContents = $false
Enable-DarkScrollBar -Control $appsFlow

$script:selectedApps = @{}

function Get-AppCategory {
    param([string]$AppName)
    switch ($AppName) {
        "VS Code" { return "Code" }
        "Git" { return "Code" }
        "Notepad++" { return "Code" }
        "PowerToys" { return "Code" }
        "Docker" { return "Code" }
        "Postman" { return "Code" }
        "Windows Terminal" { return "Code" }
        "WSL" { return "Code" }
        "Visual Studio" { return "Code" }
        "Visual Studio 2022" { return "Code" }
        "PyCharm" { return "Code" }
        "IntelliJ IDEA" { return "Code" }
        "Visual Studio Community" { return "Code" }
        "GitHub Desktop" { return "Code" }
        "Node.js" { return "Code" }
        "Godot" { return "Code" }
        "Godot Engine" { return "Code" }
        "Aseprite" { return "Code" }
        "Krita" { return "Code" }
        "VLC" { return "Video" }
        "OBS" { return "Video" }
        "qBittorrent" { return "Video" }
        "Kdenlive" { return "Video" }
        "OpenShot" { return "Video" }
        "Audacity" { return "Video" }
        "HandBrake" { return "Video" }
        "GIMP" { return "Video" }
        "Inkscape" { return "Video" }
        "Discord" { return "Social" }
        "Telegram" { return "Social" }
        "Zoom" { return "Social" }
        "Microsoft Teams" { return "Social" }
        "Slack" { return "Social" }
        "Signal" { return "Social" }
        "WhatsApp" { return "Social" }
        "Chrome" { return "Browser" }
        "Firefox" { return "Browser" }
        "Microsoft Edge" { return "Browser" }
        "Brave" { return "Browser" }
        "Opera" { return "Browser" }
        "Vivaldi" { return "Browser" }
        "Arc" { return "Browser" }
        "Tor Browser" { return "Browser" }
        "LibreWolf" { return "Browser" }
        "Waterfox" { return "Browser" }
        "Mullvad Browser" { return "Browser" }
        "Chromium" { return "Browser" }
        "DuckDuckGo Browser" { return "Browser" }
        "Yandex Browser" { return "Browser" }
        "Pale Moon" { return "Browser" }
        "Floorp" { return "Browser" }
        "7-Zip" { return "Utility" }
        "WinRAR" { return "Utility" }
        "CPU-Z" { return "Utility" }
        "Malwarebytes" { return "Utility" }
        "Everything" { return "Utility" }
        "TreeSize" { return "Utility" }
        "Rufus" { return "Utility" }
        "Ventoy" { return "Utility" }
        "ShareX" { return "Utility" }
        "WinSCP" { return "Utility" }
        "PuTTY" { return "Utility" }
        "FileZilla" { return "Utility" }
        "Steam" { return "Gaming" }
        "Steam Beta" { return "Gaming" }
        "Epic Games" { return "Gaming" }
        "Ubisoft Connect" { return "Gaming" }
        "EA App" { return "Gaming" }
        "GOG Galaxy" { return "Gaming" }
        "League of Legends" { return "Gaming" }
        "Xbox App" { return "Gaming" }
        "Spotify" { return "Media" }
        "Canva" { return "Productivity" }
        "Notion" { return "Productivity" }
        "Todoist" { return "Productivity" }
        "Microsoft To Do" { return "Productivity" }
        "LibreOffice" { return "Productivity" }
        "Joplin" { return "Productivity" }
        "OneDrive" { return "Cloud" }
        "Dropbox" { return "Cloud" }
        "Google Drive" { return "Cloud" }
        "Tailscale" { return "Network" }
        "AnyDesk" { return "Network" }
        "TeamViewer" { return "Network" }
        "RustDesk" { return "Network" }
        "Mullvad" { return "Security" }
        "ProtonVPN" { return "Security" }
        "Bitwarden" { return "Security" }
        "KeePassXC" { return "Security" }
        "KeePass" { return "Security" }
        "1Password" { return "Security" }
        "Arduino IDE" { return "Code" }
        "MongoDB Compass" { return "Code" }
        default { return "" }
    }
}

function Get-ShortAppName {
    param([string]$Name)
    if (-not $Name) { return "" }
    $trimmed = $Name.Trim()
    if ($trimmed.Length -le 12) { return $trimmed }
    $parts = $trimmed -split '\s+'
    if ($parts.Count -gt 1) {
        $first = $parts[0]
        if ($first.Length -gt 10) { return $first.Substring(0, 10) }
        return $first
    }
    return $trimmed.Substring(0, [Math]::Min(12, $trimmed.Length))
}

function Set-AppCardSelectionState {
    param($Card, [bool]$Selected)
    if (-not $Card -or -not $Card.Tag) { return }
    $tag = $Card.Tag
    $tag.IsSelected = $Selected
    $Card.BackColor = if ($Selected) { [System.Drawing.Color]::FromArgb(18, 41, 44) } else { $script:CardColor }
    $Card.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    
    if ($tag.CheckMark) {
        $tag.CheckMark.Visible = $Selected
        $tag.CheckMark.ForeColor = if ($Selected) { $script:AccentColor } else { [System.Drawing.Color]::FromArgb(0, 220, 190) }
    }
    
    # Aggiorna anche il colore del TextBox
    if ($tag.TextLabel) {
        $tag.TextLabel.BackColor = if ($Selected) { [System.Drawing.Color]::FromArgb(18, 41, 44) } else { $script:CardColor }
        $tag.TextLabel.ForeColor = $script:TextColorDim  # Mantieni sempre lo stesso colore testo
    }
    
    if ($tag.StatusLabel) {
        $tag.StatusLabel.Text = ""
        $tag.StatusLabel.Visible = $false
    }
    $script:selectedApps[$tag.AppId] = $Selected
}

function New-AppCard {
    param($App, $Parent)

    $card = New-Object System.Windows.Forms.Panel
    $card.Size = New-Object System.Drawing.Size(82, 82)
    $card.Margin = New-Object System.Windows.Forms.Padding(4)
    $card.BackColor = $script:CardColor
    $card.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $card.Cursor = [System.Windows.Forms.Cursors]::Hand

    $pic = New-Object System.Windows.Forms.PictureBox
    $pic.Size = New-Object System.Drawing.Size(28, 28)
    $pic.Location = New-Object System.Drawing.Point(27, 8)
    $pic.SizeMode = 'Zoom'
    $pic.Image = Get-AppIcon -Domain $App.Domain -Name $App.Name
    $pic.BackColor = [System.Drawing.Color]::Transparent
    $pic.Enabled = $false

    $checkMark = New-Object System.Windows.Forms.Label
    $checkMark.Text = "✓"
    $checkMark.ForeColor = $script:AccentColor
    $checkMark.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $checkMark.Size = New-Object System.Drawing.Size(16, 16)
    $checkMark.Location = New-Object System.Drawing.Point(57, 4)
    $checkMark.TextAlign = 'MiddleCenter'
    $checkMark.Visible = $false

    # Usa un TextBox readonly invece di Label per evitare problemi di rendering
    $lbl = New-Object System.Windows.Forms.TextBox
    $lbl.Text = (Get-ShortAppName -Name $App.Name)
    $lbl.ForeColor = $script:TextColorDim
    $lbl.BackColor = $script:CardColor  # Stesso colore della card
    $lbl.TextAlign = 'Center'
    $lbl.Location = New-Object System.Drawing.Point(3, 37)
    $lbl.Size = New-Object System.Drawing.Size(76, 18)
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 6.5, [System.Drawing.FontStyle]::Regular)
    $lbl.BorderStyle = 'None'
    $lbl.ReadOnly = $true
    $lbl.Enabled = $false
    $lbl.TabStop = $false
    $lbl.Multiline = $false
    $lbl.Cursor = [System.Windows.Forms.Cursors]::Default

    $statusLbl = New-Object System.Windows.Forms.Label
    $statusLbl.Text = ""
    $statusLbl.ForeColor = $script:AccentColor
    $statusLbl.TextAlign = 'MiddleCenter'
    $statusLbl.Location = New-Object System.Drawing.Point(3, 57)
    $statusLbl.Size = New-Object System.Drawing.Size(76, 10)
    $statusLbl.Font = New-Object System.Drawing.Font("Segoe UI", 5.4)
    $statusLbl.Enabled = $false
    $statusLbl.Visible = $false

    $card.Tag = @{
        AppId = $App.Id
        IsSelected = $false
        StatusLabel = $statusLbl
        CheckMark = $checkMark
        TextLabel = $lbl  # Aggiungi riferimento al label per aggiornamenti futuri
    }

    $card.Add_Click({
        param($sender, $e)
        $tag = $sender.Tag
        $newState = -not $tag.IsSelected
        Set-AppCardSelectionState -Card $sender -Selected $newState
    })

    # Aggiungi anche il click sul label stesso
    $lbl.Add_Click({
        param($sender, $e)
        $card = $sender.Parent
        $tag = $card.Tag
        $newState = -not $tag.IsSelected
        Set-AppCardSelectionState -Card $card -Selected $newState
    })

    $card.Controls.AddRange(@($pic, $checkMark, $lbl, $statusLbl))
    $Parent.Controls.Add($card)
    $script:selectedApps[$App.Id] = $false
}

$categoryOrder = @("Code", "Video", "Social", "Browser", "Utility", "Gaming", "Media", "Productivity", "Cloud", "Network", "Security")

$groupedApps = @{}
foreach ($app in $wingetApps) {
    $category = Get-AppCategory -AppName $app.Name
    if (-not $category) { continue }
    if (-not $groupedApps.ContainsKey($category)) { $groupedApps[$category] = @() }
    $groupedApps[$category] += $app
}

foreach ($category in $categoryOrder) {
    if (-not $groupedApps.ContainsKey($category)) { continue }
    $section = New-Object System.Windows.Forms.FlowLayoutPanel
    $section.FlowDirection = 'TopDown'
    $section.WrapContents = $false
    $section.AutoSize = $true
    $section.AutoSizeMode = 'GrowAndShrink'
    $section.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)

    $header = New-Object System.Windows.Forms.Label
    $header.Text = $category
    $header.ForeColor = $script:TextColorDim
    $header.Font = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Bold)
    $header.AutoSize = $true
    $header.Margin = New-Object System.Windows.Forms.Padding(2, 0, 0, 4)

    $cardRow = New-Object System.Windows.Forms.FlowLayoutPanel
    $cardRow.FlowDirection = 'LeftToRight'
    $cardRow.WrapContents = $true
    $cardRow.AutoSize = $true
    $cardRow.Margin = New-Object System.Windows.Forms.Padding(0)
    $cardRow.Padding = New-Object System.Windows.Forms.Padding(0)

    foreach ($app in $groupedApps[$category]) { New-AppCard -App $app -Parent $cardRow }

    $section.Controls.Add($header)
    $section.Controls.Add($cardRow)
    $appsFlow.Controls.Add($section)
}

# ---- PULSANTI BOTTOM - APP STORE ----
$appsBottom = New-Object System.Windows.Forms.Panel
$appsBottom.Dock = 'Bottom'
$appsBottom.Height = 52
$appsBottom.BackColor = $script:BgColor
$appsBottom.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)

$btnApplyApps = New-Object DarkButton
$btnApplyApps.Text = "Installa selezionate"
$btnApplyApps.FlatStyle = 'Flat'
$btnApplyApps.FlatAppearance.BorderSize = 0
$btnApplyApps.ForeColor = [System.Drawing.Color]::White
$btnApplyApps.BackColor = $script:AccentColor
$btnApplyApps.Size = New-Object System.Drawing.Size(150, 30)
$btnApplyApps.Location = New-Object System.Drawing.Point(16, 10)
$btnApplyApps.Font = New-Object System.Drawing.Font("Segoe UI", 8.2, [System.Drawing.FontStyle]::Bold)
$btnApplyApps.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnApplyApps.Add_Click({
    $selected = $script:selectedApps.GetEnumerator() | Where-Object { $_.Value -eq $true }
    if (-not $selected -or $selected.Count -eq 0) { 
        Write-Log "Nessuna app selezionata." 
        return 
    }
    Write-Log "=== Installazione app ==="
    foreach ($app in $selected) {
        $appId = $app.Key
        $appName = ($wingetApps | Where-Object { $_.Id -eq $appId }).Name
        try { 
            Install-WingetApp -WingetId $appId
            Write-LogDetail -Operation "Installazione app" -Target $appName -Detail "ID: $appId" -Status OK
        } catch { 
            Write-LogDetail -Operation "Installazione app" -Target $appName -Detail "ID: $appId" -Status ERRORE -ErrorMsg $_
        }
    }
    Write-Log "=== Completato ==="
})

$btnDeselectApps = New-Object DarkButton
$btnDeselectApps.Text = "Deseleziona tutto"
$btnDeselectApps.FlatStyle = 'Flat'
$btnDeselectApps.FlatAppearance.BorderSize = 0
$btnDeselectApps.ForeColor = $script:TextColor
$btnDeselectApps.BackColor = $script:PanelColor
$btnDeselectApps.Size = New-Object System.Drawing.Size(150, 30)
$btnDeselectApps.Location = New-Object System.Drawing.Point(176, 10)
$btnDeselectApps.Font = New-Object System.Drawing.Font("Segoe UI", 8.2, [System.Drawing.FontStyle]::Bold)
$btnDeselectApps.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnDeselectApps.Add_Click({
    try {
        $controlsCopy = New-Object System.Collections.Generic.List[object]
        $stack = New-Object System.Collections.Generic.Stack[object]
        $stack.Push($appsFlow)

        while ($stack.Count -gt 0) {
            $container = $stack.Pop()
            foreach ($control in @($container.Controls)) {
                if ($control -is [System.Windows.Forms.Panel] -and $control.Tag) {
                    [void]$controlsCopy.Add($control)
                }
                if ($control.Controls.Count -gt 0) {
                    [void]$stack.Push($control)
                }
            }
        }

        foreach ($control in $controlsCopy) {
            try { Set-AppCardSelectionState -Card $control -Selected $false } catch {}
        }
        foreach ($key in @($script:selectedApps.Keys)) {
            $script:selectedApps[$key] = $false
        }
        Write-Log "Deselezionate tutte le app"
    } catch {
        Write-Log "ERRORE durante deselezione: $_"
    }
})

$btnSelectApps = New-Object DarkButton
$btnSelectApps.Text = "Seleziona tutto"
$btnSelectApps.FlatStyle = 'Flat'
$btnSelectApps.FlatAppearance.BorderSize = 0
$btnSelectApps.ForeColor = $script:TextColor
$btnSelectApps.BackColor = $script:PanelColor
$btnSelectApps.Size = New-Object System.Drawing.Size(150, 30)
$btnSelectApps.Location = New-Object System.Drawing.Point(336, 10)
$btnSelectApps.Font = New-Object System.Drawing.Font("Segoe UI", 8.2, [System.Drawing.FontStyle]::Bold)
$btnSelectApps.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnSelectApps.Add_Click({
    try {
        $controlsCopy = New-Object System.Collections.Generic.List[object]
        $stack = New-Object System.Collections.Generic.Stack[object]
        $stack.Push($appsFlow)

        while ($stack.Count -gt 0) {
            $container = $stack.Pop()
            foreach ($control in @($container.Controls)) {
                if ($control -is [System.Windows.Forms.Panel] -and $control.Tag) {
                    [void]$controlsCopy.Add($control)
                }
                if ($control.Controls.Count -gt 0) {
                    [void]$stack.Push($control)
                }
            }
        }

        foreach ($control in $controlsCopy) {
            try { Set-AppCardSelectionState -Card $control -Selected $true } catch {}
        }
        foreach ($key in @($script:selectedApps.Keys)) {
            $script:selectedApps[$key] = $true
        }
        Write-Log "Selezionate tutte le app"
    } catch {
        Write-Log "ERRORE durante selezione: $_"
    }
})

$appsBottom.Controls.AddRange(@($btnApplyApps, $btnDeselectApps, $btnSelectApps))
Add-SmoothHover -Control $btnApplyApps -NormalColor $script:AccentColor -HoverColor $script:AccentHover
Add-SmoothHover -Control $btnDeselectApps -NormalColor $script:PanelColor -HoverColor $script:CardHover
Add-SmoothHover -Control $btnSelectApps -NormalColor $script:PanelColor -HoverColor $script:CardHover
$panelApps.Controls.Add($appsFlow)
$panelApps.Controls.Add($appsBottom)

# ---- ISO SISTEMI OPERATIVI ----
$isoFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$isoFlow.Dock = 'Fill'
$isoFlow.AutoScroll = $true
$isoFlow.WrapContents = $true
$isoFlow.BackColor = $script:BgColor
$isoFlow.Padding = New-Object System.Windows.Forms.Padding(14, 10, 14, 14)
$isoFlow.Margin = New-Object System.Windows.Forms.Padding(0)
Enable-DarkScrollBar -Control $isoFlow

$isoHeader = New-Object System.Windows.Forms.Panel
$isoHeader.Dock = 'Top'
$isoHeader.Height = 58
$isoHeader.BackColor = $script:PanelColor2

$isoTitle = New-Object System.Windows.Forms.Label
$isoTitle.Text = 'ISO e sistemi operativi'
$isoTitle.ForeColor = $script:TextColor
$isoTitle.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$isoTitle.Location = New-Object System.Drawing.Point(14, 8)
$isoTitle.Size = New-Object System.Drawing.Size(300, 26)

$isoSubtitle = New-Object System.Windows.Forms.Label
$isoSubtitle.Text = 'Download ufficiali per installazione, recovery e virtualizzazione.'
$isoSubtitle.ForeColor = $script:TextColorDim
$isoSubtitle.Font = New-Object System.Drawing.Font('Segoe UI', 8.2)
$isoSubtitle.Location = New-Object System.Drawing.Point(14, 34)
$isoSubtitle.Size = New-Object System.Drawing.Size(430, 20)
$isoHeader.Controls.AddRange(@($isoTitle, $isoSubtitle))
$panelIso.Controls.Add($isoFlow)
$panelIso.Controls.Add($isoHeader)

foreach ($iso in $isoCatalog) {
    $isoCard = New-Object System.Windows.Forms.Panel
    $isoCard.Size = New-Object System.Drawing.Size(224, 132)
    $isoCard.Margin = New-Object System.Windows.Forms.Padding(5, 5, 7, 7)
    $isoCard.BackColor = $script:CardColor
    $isoCard.Tag = $iso

    $isoIcon = New-Object System.Windows.Forms.PictureBox
    $isoIcon.Size = New-Object System.Drawing.Size(34, 34)
    $isoIcon.Location = New-Object System.Drawing.Point(14, 10)
    $isoIcon.SizeMode = 'Zoom'
    $isoIcon.BackColor = [System.Drawing.Color]::Transparent
    $isoIcon.Image = Get-AppIcon -Domain $iso.Domain -Name $iso.Name
    $isoIcon.Enabled = $false

    $isoName = New-Object System.Windows.Forms.Label
    $isoName.Text = $iso.Name
    $isoName.ForeColor = $script:TextColor
    $isoName.Font = New-Object System.Drawing.Font('Segoe UI', 9.2, [System.Drawing.FontStyle]::Bold)
    $isoName.Location = New-Object System.Drawing.Point(57, 11)
    $isoName.Size = New-Object System.Drawing.Size(153, 24)
    $isoPublisher = New-Object System.Windows.Forms.Label
    $isoPublisher.Text = "$($iso.Publisher)  |  $($iso.Category)"
    $isoPublisher.ForeColor = $script:TextColorDim
    $isoPublisher.Font = New-Object System.Drawing.Font('Segoe UI', 7.5)
    $isoPublisher.Location = New-Object System.Drawing.Point(14, 49)
    $isoPublisher.Size = New-Object System.Drawing.Size(196, 18)
    $isoDetail = New-Object System.Windows.Forms.Label
    $isoDetail.Text = $iso.Detail
    $isoDetail.ForeColor = $script:AccentColor
    $isoDetail.Font = New-Object System.Drawing.Font('Segoe UI', 7.5)
    $isoDetail.Location = New-Object System.Drawing.Point(14, 70)
    $isoDetail.Size = New-Object System.Drawing.Size(196, 18)
    $isoButton = New-Object DarkButton
    $isoButton.Text = 'Apri download ufficiale'
    $isoButton.Tag = $iso.Url
    $isoButton.FlatStyle = 'Flat'
    $isoButton.FlatAppearance.BorderSize = 0
    $isoButton.BackColor = $script:PanelColor
    $isoButton.ForeColor = $script:AccentColor
    $isoButton.Font = New-Object System.Drawing.Font('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)
    $isoButton.Size = New-Object System.Drawing.Size(196, 28)
    $isoButton.Location = New-Object System.Drawing.Point(14, 96)
    $isoButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $isoButton.Add_Click({ Start-Process $this.Tag })
    $isoCard.Controls.AddRange(@($isoIcon, $isoName, $isoPublisher, $isoDetail, $isoButton))
    $isoFlow.Controls.Add($isoCard)
}

$contentSplit.Panel1.Controls.Add($panelOptim)
$contentSplit.Panel1.Controls.Add($panelApps)
$contentSplit.Panel1.Controls.Add($panelIso)
$contentSplit.Panel1.Controls.Add($panelMemory)

# ---- CONSOLE ----
$logContainer = New-Object System.Windows.Forms.Panel
$logContainer.Dock = 'Fill'
$logContainer.BackColor = $script:CardColor
$logContainer.Padding = New-Object System.Windows.Forms.Padding(1)

$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Text = "Console"
$logLabel.Dock = 'Top'
$logLabel.Height = 42
$logLabel.BackColor = $script:PanelColor2
$logLabel.ForeColor = $script:AccentColor
$logLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$logLabel.TextAlign = 'MiddleLeft'
$logLabel.Padding = New-Object System.Windows.Forms.Padding(16, 0, 0, 0)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = 'Vertical'
$logBox.ReadOnly = $true
$logBox.Dock = 'Fill'
$logBox.Font = New-Object System.Drawing.Font("Cascadia Mono", 8.5)
$logBox.BackColor = [System.Drawing.Color]::FromArgb(10, 12, 17)
$logBox.ForeColor = $script:AccentColor
$logBox.BorderStyle = 'None'

$logContainer.Controls.Add($logBox)
$logContainer.Controls.Add($logLabel)
Enable-DarkScrollBar -Control $logBox
$contentSplit.Panel2.Controls.Add($logContainer)

$form.Controls.Add($contentSplit)
$form.Controls.Add($navBar)
$form.Controls.Add($titleBar)

# ---- ANIMAZIONE ----
$form.Add_Resize({
})

$form.Add_Shown({
    $form.Activate()
    $form.BringToFront()
    try {
        $alpha = 200
        $r = $script:BgColor.R
        $g = $script:BgColor.G
        $b = $script:BgColor.B
        $colorAbgr = ($alpha -shl 24) -bor ($b -shl 16) -bor ($g -shl 8) -bor $r
        [AcrylicBlur]::Enable($form.Handle, $colorAbgr)
    } catch {
        Write-Log "Blur non disponibile"
    }

    $fadeTimer = New-Object System.Windows.Forms.Timer
    $fadeTimer.Interval = 20
    $fadeTimer.Add_Tick({
        if ($form.Opacity -lt 1) { 
            $form.Opacity += 0.1
        } else { 
            $form.Opacity = 1
            $fadeTimer.Stop() 
        }
    }.GetNewClosure())
    $fadeTimer.Start()

    # Applica il tema scuro anche alle barre di scorrimento native.
    Enable-DarkScrollBar -Control $listDebloat
    Enable-DarkScrollBar -Control $listPrivacy
    Enable-DarkScrollBar -Control $listPerf
    Enable-DarkScrollBar -Control $listServices
    Enable-DarkScrollBar -Control $listStartup
    Enable-DarkScrollBar -Control $appsFlow
    Enable-DarkScrollBar -Control $logBox
    $memoryTimer.Start()

    Write-Log "MoliOptimizer avviato."
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log "ATTENZIONE: winget non installato."
    }
})

[void]$form.ShowDialog()
