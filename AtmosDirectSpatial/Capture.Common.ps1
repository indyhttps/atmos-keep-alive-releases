# Funcoes compartilhadas. Carregar este arquivo nao altera arquivos, registro ou audio.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CaptureRoot {
    Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'AtmosDirectSpatial'
}

function Assert-NoReparsePath([string] $Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Caminho com link/junction recusado: $cursor"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor.TrimEnd('\'))
        if (!$parent -or $parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Get-BytesHash([byte[]] $Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-FileHashValue([string] $Path) {
    Get-BytesHash ([IO.File]::ReadAllBytes($Path))
}

function Get-CaptureBaseConfiguration([byte[]] $OriginalBytes, [byte[]] $ExampleBytes, [bool] $NeutralizeFactoryPreset) {
    if (!$NeutralizeFactoryPreset) {
        return [pscustomobject]@{ Bytes = $OriginalBytes; FactoryNeutralized = $false }
    }
    # Equalizer APO 1.4.2 official factory files, commit bbfcc3e5024cbb9d61ba75fc88d78605cc4c9687.
    # Only this exact unused preset is neutralized; user configuration is never inferred.
    if ((Get-BytesHash $OriginalBytes) -ne '6dccce92c8fe2e244cf7440cf51b4163f87e57bd3dfbf8e2ce7f2636f53aef91' -or
        (Get-BytesHash $ExampleBytes) -ne '83f6d9063a14feb292632b7667c62b763baa52421345a4967f4078cf62385fd8') {
        throw 'A configuracao nao e o preset oficial intacto do Equalizer APO 1.4.2. Neutralizacao recusada; sua configuracao foi preservada.'
    }
    [pscustomobject]@{
        Bytes = [Text.ASCIIEncoding]::new().GetBytes("# Neutral capture input; original factory preset preserved in backup.`r`n")
        FactoryNeutralized = $true
    }
}

function Assert-CaptureAdministrator {
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Aplicar exige PowerShell como administrador. O script nao se eleva automaticamente.'
    }
}

function Assert-X64Pe([string] $Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 64 -or [BitConverter]::ToUInt16($bytes, 0) -ne 0x5a4d) {
        throw "Arquivo PE invalido: $Path"
    }
    $offset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($offset -lt 0 -or $offset -gt $bytes.Length - 6 -or
        [BitConverter]::ToUInt32($bytes, $offset) -ne 0x4550 -or
        [BitConverter]::ToUInt16($bytes, $offset + 4) -ne 0x8664) {
        throw "E necessario binario x64: $Path"
    }
}

function Get-ConfigEncoding([byte[]] $Bytes) {
    # O prefixo original e sempre copiado sem recodificacao. Apenas o sufixo usa esta codificacao.
    if ($Bytes.Length -ge 4 -and
        (($Bytes[0] -eq 0xff -and $Bytes[1] -eq 0xfe -and $Bytes[2] -eq 0 -and $Bytes[3] -eq 0) -or
         ($Bytes[0] -eq 0 -and $Bytes[1] -eq 0 -and $Bytes[2] -eq 0xfe -and $Bytes[3] -eq 0xff))) {
        throw 'config.txt UTF-32 nao e suportado; nenhuma alteracao foi realizada.'
    }
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xff -and $Bytes[1] -eq 0xfe) {
        return [Text.UnicodeEncoding]::new($false, $false, $true)
    }
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xfe -and $Bytes[1] -eq 0xff) {
        return [Text.UnicodeEncoding]::new($true, $false, $true)
    }
    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xef -and $Bytes[1] -eq 0xbb -and $Bytes[2] -eq 0xbf) {
        return [Text.UTF8Encoding]::new($false, $true)
    }
    if ($Bytes -contains 0) { throw 'config.txt sem BOM contem bytes nulos; codificacao ambigua recusada.' }
    # O caminho ProgramData precisa ser ASCII para o sufixo servir tanto a UTF-8 quanto a ANSI.
    return [Text.ASCIIEncoding]::new()
}

function Write-AtomicReplacement([string] $Path, [byte[]] $Bytes, [string] $ExpectedHash) {
    Assert-NoReparsePath $Path
    if ((Get-FileHashValue $Path) -ne $ExpectedHash) {
        throw "Arquivo mudou durante a operacao; preservado sem substituicao: $Path"
    }
    $temporary = $Path + '.AtmosDirectSpatial.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllBytes($temporary, $Bytes)
        if ((Get-FileHashValue $Path) -ne $ExpectedHash) { throw 'Configuracao alterada por outro processo; operacao cancelada.' }
        [IO.File]::Replace($temporary, $Path, [System.Management.Automation.Language.NullString]::Value)
    }
    finally {
        # Remove somente o temporario de nome unico desta operacao; nunca backups ou diretorios.
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function Set-CaptureDirectoryAcl([string] $Path, [string] $UserSid, [bool] $WritableData) {
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetAccessRuleProtection($true, $false)
    $inherit = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    $propagation = [Security.AccessControl.PropagationFlags]::None
    $allow = [Security.AccessControl.AccessControlType]::Allow
    $system = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $admins = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $localService = [Security.Principal.SecurityIdentifier]::new('S-1-5-19')
    $user = [Security.Principal.SecurityIdentifier]::new($UserSid)
    foreach ($identity in @($system, $admins)) {
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
            $identity, [Security.AccessControl.FileSystemRights]::FullControl, $inherit, $propagation, $allow))
    }
    $rights = if ($WritableData) { [Security.AccessControl.FileSystemRights]::Modify }
              else { [Security.AccessControl.FileSystemRights]::ReadAndExecute }
    foreach ($identity in @($localService, $user)) {
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity, $rights, $inherit, $propagation, $allow))
    }
    $acl.SetOwner($admins)
    Set-Acl -LiteralPath $Path -AclObject $acl
}

function Get-EqualizerApoInstallation {
    if (![Environment]::Is64BitOperatingSystem -or ![Environment]::Is64BitProcess) {
        throw 'Use PowerShell de 64 bits no Windows x64.'
    }
    $registry = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Registry64')
    try {
        $key = $registry.OpenSubKey('SOFTWARE\EqualizerAPO')
        if (!$key) { throw 'Equalizer APO ausente. Instale-o e associe a saida fisica no Configurator antes de usar este pacote.' }
        try { $installPath = [string]$key.GetValue('InstallPath'); $configPath = [string]$key.GetValue('ConfigPath') }
        finally { $key.Dispose() }
        if (!$installPath -or !$configPath -or ![IO.Path]::IsPathRooted($configPath)) {
            throw 'Equalizer APO nao tem InstallPath/ConfigPath validos no registro; integracao automatica recusada.'
        }
        $config = [IO.Path]::GetFullPath((Join-Path $configPath 'config.txt'))
        $configurator = Join-Path $installPath 'DeviceSelector.exe'
        if (!(Test-Path -LiteralPath $configurator -PathType Leaf)) { $configurator = Join-Path $installPath 'Configurator.exe' }
        if (!(Test-Path -LiteralPath $config -PathType Leaf) -or !(Test-Path -LiteralPath $configurator -PathType Leaf)) {
            throw 'Instalacao/configuracao do Equalizer APO incompleta. Abra Device Selector/Configurator; o pacote nao instala APO nem driver.'
        }
        $postMixGuid = '{EC1CC9CE-FAED-4822-828A-82A81A6F018F}'
        $class = $registry.OpenSubKey("SOFTWARE\Classes\CLSID\$postMixGuid\InprocServer32")
        if (!$class) { throw 'APO post-mix do Equalizer APO nao esta registrado.' }
        try { $apoDll = ([string]$class.GetValue('')).Trim('"') } finally { $class.Dispose() }
        if (!(Test-Path -LiteralPath $apoDll -PathType Leaf)) { throw 'DLL do APO post-mix registrado nao foi encontrada.' }
        Assert-X64Pe $apoDll
        Assert-NoReparsePath $config
        [pscustomobject]@{ ConfigPath = $config; InstallPath = $installPath; Configurator = $configurator; PostMixGuid = $postMixGuid; ApoDll = $apoDll }
    }
    finally { $registry.Dispose() }
}
