[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateSet('install','update','uninstall')][string]$Action,
      [Parameter(Mandatory=$true)][string]$UserSid,[string]$EndpointGuid)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$package=Split-Path -Parent $PSScriptRoot
. (Join-Path $package 'Capture.Common.ps1')
. (Join-Path $PSScriptRoot 'Lifecycle.Core.ps1')
$root=Get-CaptureRoot
$uninstallKey='SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AtmosDirectSpatial'
$programs=Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'Atmos Direct Spatial'
$log=Join-Path ([IO.Path]::GetTempPath()) ('AtmosDirectSpatial-Setup-'+[Guid]::NewGuid().ToString('N')+'.log')
$transcript=$false
$lifecycleMutex=$null;$lifecycleOwned=$false
function Assert-Endpoint([string]$GuidText) {
    $guid=([Guid]$GuidText).ToString('B')
    $reg=[Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine','Registry64');$device=$null;$fx=$null
    try {
        $device=$reg.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\$guid")
        if (!$device -or ([int]$device.GetValue('DeviceState',0) -band 1) -eq 0) { throw 'Saida fisica ausente ou desconectada.' }
        $props=$device.OpenSubKey('Properties')
        try { $name=[string]$props.GetValue('{b3f8fa53-0004-438e-9003-51a46e139bfc},6','')+' '+[string]$props.GetValue('{a45c254e-df1c-4efd-8020-67d146a850e0},2','') } finally { if ($props) { $props.Dispose() } }
        if ($name -match '(?i)CABLE|VB-Audio|Virtual') { throw 'Selecione uma saida fisica; dispositivo virtual recusado.' }
        $fx=$device.OpenSubKey('FxProperties')
        if (!$fx -or [int]$fx.GetValue('{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5',0) -ne 0) { throw 'Ative os aprimoramentos da saida e associe-a no Device Selector do Equalizer APO.' }
        $found=$false
        foreach ($key in @('{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},2','{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},7','{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},15')) {
            foreach ($value in @($fx.GetValue($key,@()))) { if ([string]$value -eq '{EC1CC9CE-FAED-4822-828A-82A81A6F018F}') { $found=$true } }
        }
        if (!$found) { throw 'Equalizer APO precisa estar associado em GFX/EFX nesta saida. Abra Device Selector e configure primeiro.' }
    } finally { if ($fx) { $fx.Dispose() };if ($device) { $device.Dispose() };$reg.Dispose() }
}
function Stop-Controllers($Context,[string]$ExpectedHash) {
    Assert-AdsHash (Join-Path $Context.Root 'AtmosDirectSpatial.exe') $ExpectedHash
    foreach ($process in @(Get-CimInstance Win32_Process -Filter "Name='AtmosDirectSpatial.exe'" -ErrorAction Stop)) {
        if ($process.ExecutablePath -ne (Join-Path $Context.Root 'AtmosDirectSpatial.exe')) { continue }
        $handle=Get-Process -Id $process.ProcessId -ErrorAction Stop
        if (!$handle.CloseMainWindow() -or !$handle.WaitForExit(10000)) { $handle.Dispose();throw 'Feche a janela do Atmos Direct Spatial antes de continuar. Nenhum processo sera forcado.' }
        $handle.Dispose()
    }
}
function Check-Stopped($Context) {
    $path=Join-Path $Context.Root 'data\capture.bin';Assert-NoReparsePath $path
    if ((Get-Item -LiteralPath $path).Length -ne 3148224) { throw 'Mapping IPC desconhecido; nao sera recriado.' }
    $stream=[IO.FileStream]::new($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);$map=$null;$view=$null
    try {
        $map=[IO.MemoryMappedFiles.MemoryMappedFile]::CreateFromFile($stream,[System.Management.Automation.Language.NullString]::Value,0,[IO.MemoryMappedFiles.MemoryMappedFileAccess]::Read,[IO.HandleInheritability]::None,$true)
        $view=$map.CreateViewAccessor(0,448,[IO.MemoryMappedFiles.MemoryMappedFileAccess]::Read)
        foreach ($entry in @{0=[uint64]1;8=[uint64]0x4144534350543031;16=[uint64]2;24=[uint64]3148224;264=[uint64]0;272=[uint64]1;400=[uint64]0}.GetEnumerator()) { if ($view.ReadUInt64([int64]$entry.Key) -ne $entry.Value) { throw 'O mecanismo ainda esta ativo ou a ponte e desconhecida. Aguarde e tente novamente.' } }
    } finally { if ($view) { $view.Dispose() };if ($map) { $map.Dispose() };$stream.Dispose() }
}
function Prepare-Mapping([string]$Exe) {
    $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$Exe;$start.Arguments='--prepare';$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    $process=[Diagnostics.Process]::Start($start)
    try { if (!$process.WaitForExit(10000)) { $process.Kill();$process.WaitForExit(10000)|Out-Null;throw '--prepare nao terminou em 10 segundos.' };if ($process.ExitCode -ne 0) { throw "--prepare falhou: $($process.ExitCode)" } } finally { $process.Dispose() }
}
function Register-Product($Context,$Manifest) {
    [IO.Directory]::CreateDirectory($programs)|Out-Null
    $shell=New-Object -ComObject WScript.Shell
    try {
        $link=$shell.CreateShortcut((Join-Path $programs 'Atmos Direct Spatial.lnk'));$link.TargetPath=Join-Path $Context.Root 'AtmosDirectSpatial.exe';$link.WorkingDirectory=$Context.Root;$link.Save()
        $link=$shell.CreateShortcut((Join-Path $programs 'Desinstalar Atmos Direct Spatial.lnk'));$link.TargetPath=Join-Path $Context.Root 'AtmosDirectSpatialSetup.exe';$link.Arguments='--uninstall';$link.Save()
    } finally { [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)|Out-Null }
    $reg=[Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine','Registry64');$key=$null
    try {
        $existing=$reg.OpenSubKey($uninstallKey)
        if ($existing) { try { if ([string]$existing.GetValue('InstallLocation','') -ne $Context.Root) { throw 'Registro de outro produto com mesmo nome; preservado.' } } finally { $existing.Dispose() } }
        $key=$reg.CreateSubKey($uninstallKey)
        $key.SetValue('DisplayName','Atmos Direct Spatial');$key.SetValue('DisplayVersion',$Context.Version);$key.SetValue('Publisher','Atmos Direct Spatial');$key.SetValue('InstallLocation',$Context.Root)
        $key.SetValue('DisplayIcon',(Join-Path $Context.Root 'AtmosDirectSpatial.exe'));$key.SetValue('UninstallString','"'+(Join-Path $Context.Root 'AtmosDirectSpatialSetup.exe')+'" --uninstall')
        $key.SetValue('NoModify',1,[Microsoft.Win32.RegistryValueKind]::DWord);$key.SetValue('NoRepair',1,[Microsoft.Win32.RegistryValueKind]::DWord)
    } finally { if ($key) { $key.Dispose() };$reg.Dispose() }
}
function Unregister-Product($Context) {
    $reg=[Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine','Registry64')
    try { $key=$reg.OpenSubKey($uninstallKey);if ($key) { try { if ([string]$key.GetValue('InstallLocation','') -ne $Context.Root) { throw 'Registro de outro produto preservado.' } } finally { $key.Dispose() };$reg.DeleteSubKey($uninstallKey,$false) } } finally { $reg.Dispose() }
    foreach ($name in @('Atmos Direct Spatial.lnk','Desinstalar Atmos Direct Spatial.lnk')) { $path=Join-Path $programs $name;Assert-NoReparsePath $path;if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force } }
    if ((Test-Path -LiteralPath $programs) -and @(Get-ChildItem -LiteralPath $programs -Force).Count -eq 0) { [IO.Directory]::Delete($programs,$false) }
}
try {
    Assert-CaptureAdministrator
    $lifecycleMutex=[Threading.Mutex]::new($false,'Global\AtmosDirectSpatialSetup-v1')
    try { $lifecycleOwned=$lifecycleMutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $lifecycleOwned=$true }
    if (!$lifecycleOwned) { throw 'Outra instalacao/remocao esta em andamento. Aguarde seu resultado.' }
    if ($UserSid -notmatch '^S-1-(5-21|12-1)-[0-9-]+$') { throw 'Conta de usuario invalida.' }
    [Security.Principal.SecurityIdentifier]::new($UserSid)|Out-Null
    Start-Transcript -LiteralPath $log -Force|Out-Null;$transcript=$true
    $eapo=Get-EqualizerApoInstallation
    $files=@('Capture.Common.ps1','Restore-Capture.ps1','LEIA-ME.txt','installer\Lifecycle.ps1','installer\Lifecycle.Core.ps1','installer\payload.json')
    if ($Action -ne 'uninstall') {
        $payload=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'payload.json') -Raw|ConvertFrom-Json
        if ($payload.schema -ne 1 -or $payload.version -ne '1.0.0') { throw 'Pacote de instalacao desconhecido.' }
        foreach ($entry in $payload.files) { $path=[IO.Path]::GetFullPath((Join-Path $package $entry.file));if (!$path.StartsWith($package.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Arquivo fora do pacote.' };Assert-AdsHash $path $entry.sha256 }
        Assert-X64Pe (Join-Path $package 'AtmosDirectSpatial.exe');Assert-X64Pe (Join-Path $package 'AtmosDirectSpatialCapture.dll')
    }
    $ctx=@{Root=$root;Package=$package;UserSid=$UserSid;EndpointGuid=$EndpointGuid;ConfigPath=$eapo.ConfigPath;Version='1.0.0';SetupSource=(Join-Path $package 'AtmosDirectSpatialSetup.exe');InstallFiles=$files;Ops=@{
        CheckEndpoint={param($guid) Assert-Endpoint $guid};ProtectDirectory={param($path,$writable,$sid) Set-CaptureDirectoryAcl $path $sid $writable};Prepare={param($exe) Prepare-Mapping $exe}
        StopControllers={param($context,$hash) Stop-Controllers $context $hash};CheckStopped={param($context) Check-Stopped $context};Register={param($context,$manifest) Register-Product $context $manifest};Unregister={param($context) Unregister-Product $context}
    }}
    switch ($Action) { 'install' { $result=Install-AdsProduct $ctx };'update' { $result=Update-AdsProduct $ctx };'uninstall' { $result=Uninstall-AdsProduct $ctx } }
    if ($Action -eq 'uninstall' -and @($result.retained_files).Count) { throw ('Captura removida e backups preservados. Alguns arquivos ocupados permanecem: '+($result.retained_files -join ', ')) }
    Write-Output 'Operacao concluida. Nenhum dispositivo virtual criado, servico reiniciado ou teste de audio executado.'
    $exitCode=0
} catch { Write-Error $_ -ErrorAction Continue;$exitCode=1 } finally { if ($transcript) { Stop-Transcript|Out-Null };if ($lifecycleOwned) { $lifecycleMutex.ReleaseMutex() };if ($lifecycleMutex) { $lifecycleMutex.Dispose() } }
exit $exitCode
