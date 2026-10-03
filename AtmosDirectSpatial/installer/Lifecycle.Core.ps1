# Dot-source only: defines lifecycle functions; does not execute them.
Set-StrictMode -Version Latest

function Assert-AdsRoot($Context) {
    $root = [IO.Path]::GetFullPath($Context.Root).TrimEnd('\')
    if (!$root -or ![IO.Path]::IsPathRooted($root)) { throw 'Destino de instalacao invalido.' }
    if ($root -match '[^\x20-\x7e]' -or $root.Contains('"') -or $root -match '[\r\n]') { throw 'Destino precisa ser ASCII, sem aspas ou quebra de linha.' }
    Assert-NoReparsePath $root
    return $root
}
function Assert-AdsHash([string]$Path,[string]$Hash) {
    Assert-NoReparsePath $Path
    if ($Hash -notmatch '^[a-fA-F0-9]{64}$' -or (Get-FileHashValue $Path) -ne $Hash) { throw "Arquivo diferente do esperado: $Path" }
}
function Get-AdsBlock([string]$Root) {
    return "`r`n# AtmosDirectSpatial - bloco reversivel, backup byte a byte preservado.`r`nDevice: all`r`nStage: post-mix`r`nChannel: all`r`nInclude: $Root\capture.txt`r`n"
}
function Find-AdsBytes([byte[]]$Bytes,[byte[]]$Needle) {
    $found = [Collections.Generic.List[int]]::new()
    for ($i=0;$i -le $Bytes.Length-$Needle.Length;$i++) {
        if ($Bytes[$i] -ne $Needle[0]) { continue }
        $same=$true
        for ($j=1;$j -lt $Needle.Length;$j++) { if ($Bytes[$i+$j] -ne $Needle[$j]) { $same=$false;break } }
        if ($same) { $found.Add($i) }
    }
    return $found.ToArray()
}
function Get-AdsUninstallConfiguration([byte[]]$Current,[byte[]]$Original,$Manifest) {
    if ((Get-BytesHash $Original) -ne $Manifest.config_before_sha256 -or $Original.Length -ne $Manifest.original_byte_count) { throw 'Backup original nao confere.' }
    if ((Get-BytesHash $Current) -eq $Manifest.config_after_sha256) { return ,$Original }
    $encoding=Get-ConfigEncoding $Current
    $block=$encoding.GetBytes((Get-AdsBlock $Manifest.install_root))
    $positions=@(Find-AdsBytes $Current $block)
    if ($positions.Count -ne 1) { throw 'O bloco de captura foi editado ou duplicado. Remocao automatica recusada para preservar sua configuracao.' }
    $result=[byte[]]::new($Current.Length-$block.Length)
    [Array]::Copy($Current,0,$result,0,$positions[0])
    [Array]::Copy($Current,$positions[0]+$block.Length,$result,$positions[0],$Current.Length-$positions[0]-$block.Length)
    $remaining=$encoding.GetString($result)
    if ($remaining -match '(?i)^\s*(Include|VSTPlugin)\s*:.*AtmosDirectSpatial' -or
        $remaining -match '(?im)^\s*(Include|VSTPlugin)\s*:.*AtmosDirectSpatial') { throw 'Outra referencia ativa ao plugin permanece. Revise a configuracao antes de remover os arquivos.' }
    return ,$result
}
function Read-AdsInstallation($Context,[bool]$RequireConfigMatch=$true) {
    $root=Assert-AdsRoot $Context
    $path=Join-Path $root 'installation.json';Assert-NoReparsePath $path
    $m=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($m.schema -ne 1 -or [IO.Path]::GetFullPath($m.install_root).TrimEnd('\') -ne $root -or $m.config_path -ne $Context.ConfigPath) { throw 'Instalacao ou configuracao desconhecida.' }
    if ($m.user_sid -ne $Context.UserSid) { throw 'Esta instalacao pertence a outra conta do Windows. Use a conta que a instalou.' }
    $backup=[IO.Path]::GetFullPath($m.backup_path)
    if (!$backup.StartsWith($root+'\backups\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Caminho de backup invalido.' }
    Assert-AdsHash $backup $m.config_before_sha256
    if ((Get-Item -LiteralPath $backup).Length -ne $m.original_byte_count) { throw 'Tamanho do backup original diferente.' }
    if ($m.snippet_path -ne (Join-Path $root 'capture.txt')) { throw 'Caminho do snippet diferente.' }
    Assert-AdsHash $m.snippet_path $m.snippet_sha256
    Assert-AdsHash (Join-Path $root 'AtmosDirectSpatial.exe') $m.exe_sha256
    Assert-AdsHash (Join-Path $root 'AtmosDirectSpatialCapture.dll') $m.dll_sha256
    if ($RequireConfigMatch) { Assert-AdsHash $Context.ConfigPath $m.config_after_sha256 }
    return $m
}
function Write-AdsMetadata($Context,$Manifest) {
    $root=Assert-AdsRoot $Context
    $ini="[Installation]`r`nSchema=1`r`nEndpointId=$($Manifest.endpoint_id)`r`nConfigPath=$($Manifest.config_path)`r`nConfigSha256=$($Manifest.config_after_sha256)`r`nDllSha256=$($Manifest.dll_sha256)`r`nExeSha256=$($Manifest.exe_sha256)`r`nSnippetPath=$($Manifest.snippet_path)`r`nSnippetSha256=$($Manifest.snippet_sha256)`r`n"
    [IO.File]::WriteAllText((Join-Path $root 'installation.json'),($Manifest|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $root 'installation.ini'),$ini,[Text.UnicodeEncoding]::new($false,$true))
}
function Copy-AdsSupport($Context) {
    $hashes=@{}
    foreach ($relative in $Context.InstallFiles) {
        $source=Join-Path $Context.Package $relative;$target=Join-Path $Context.Root $relative
        Assert-NoReparsePath $source;Assert-NoReparsePath $target
        $hash=Get-FileHashValue $source
        if ((Test-Path -LiteralPath $target) -and (Get-FileHashValue $target) -eq $hash) { $hashes[$relative]=$hash;continue }
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))|Out-Null
        [IO.File]::Copy($source,$target,$true);Assert-AdsHash $target $hash;$hashes[$relative]=$hash
    }
    $setupTarget=Join-Path $Context.Root 'AtmosDirectSpatialSetup.exe'
    $setupHash=Get-FileHashValue $Context.SetupSource
    if (!(Test-Path -LiteralPath $setupTarget) -or (Get-FileHashValue $setupTarget) -ne $setupHash) {
        [IO.File]::Copy($Context.SetupSource,$setupTarget,$true);Assert-AdsHash $setupTarget $setupHash
    }
    $hashes['AtmosDirectSpatialSetup.exe']=$setupHash
    return $hashes
}
function Set-AdsDisabled($Context,[string]$EndpointId) {
    $path=Join-Path $Context.Root 'data\AtmosDirectSpatial.ini';Assert-NoReparsePath $path
    [IO.File]::WriteAllText($path,"[Control]`r`nEndpoint=$EndpointId`r`nEnabled=0`r`nHeartbeat=0`r`nRequest=0`r`nAdaptive=1`r`n",[Text.UnicodeEncoding]::new($false,$true))
}
function Install-AdsProduct($Context) {
    $root=Assert-AdsRoot $Context
    if (Test-Path -LiteralPath $root) {
        $entries=@(Get-ChildItem -LiteralPath $root -Force)
        if ($entries.Count -ne 1 -or !$entries[0].PSIsContainer -or $entries[0].Name -ne 'backups') { throw 'Pasta existente desconhecida. Use Atualizar para uma instalacao valida; nenhum arquivo sera sobrescrito.' }
        $recordPath=Join-Path $root 'backups\uninstallation.json';Assert-NoReparsePath $recordPath
        $record=Get-Content -LiteralPath $recordPath -Raw|ConvertFrom-Json
        if ($record.schema -ne 1 -or $record.install_root -ne $root -or $record.user_sid -ne $Context.UserSid) { throw 'Registro de desinstalacao desconhecido.' }
        $backupRoot=Join-Path $root 'backups'
        $expected=@($record.backup_files_sha256.PSObject.Properties)
        $actual=@(Get-ChildItem -LiteralPath $backupRoot -File -Recurse -Force)
        if ($actual.Count -ne $expected.Count+1) { throw 'Arquivos de backup nao registrados; pasta preservada sem reinstalar.' }
        foreach ($entry in $expected) {
            $path=[IO.Path]::GetFullPath((Join-Path $backupRoot $entry.Name))
            if (!$path.StartsWith($backupRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Backup fora da pasta conhecida.' }
            Assert-AdsHash $path $entry.Value
        }
    }
    & $Context.Ops.CheckEndpoint $Context.EndpointGuid
    $before=[IO.File]::ReadAllBytes($Context.ConfigPath);$beforeHash=Get-BytesHash $before
    $encoding=Get-ConfigEncoding $before
    $text=$encoding.GetString($before)
    if ($text -match '(?i)AtmosDirectSpatial') { throw 'A configuracao ja contem uma referencia ao produto.' }
    $depth=0
    foreach ($line in ($text -split '\r?\n')) { if ($line -match '^\s*If\s*:') { ++$depth };if ($line -match '^\s*EndIf\s*:') { --$depth };if ($depth -lt 0) { throw 'EndIf sem If na configuracao.' } }
    if ($depth) { throw 'If nao encerrado na configuracao.' }
    $neutral=$false;$base=$before
    $examplePath=Join-Path ([IO.Path]::GetDirectoryName($Context.ConfigPath)) 'example.txt'
    if ($beforeHash -eq '6dccce92c8fe2e244cf7440cf51b4163f87e57bd3dfbf8e2ce7f2636f53aef91' -and
        (Test-Path -LiteralPath $examplePath) -and (Get-FileHashValue $examplePath) -eq '83f6d9063a14feb292632b7667c62b763baa52421345a4967f4078cf62385fd8') {
        $preset=Get-CaptureBaseConfiguration $before ([IO.File]::ReadAllBytes($examplePath)) $true;$base=[byte[]]$preset.Bytes;$neutral=$true
    }
    $suffix=$encoding.GetBytes((Get-AdsBlock $root));$after=[byte[]]::new($base.Length+$suffix.Length)
    [Array]::Copy($base,0,$after,0,$base.Length);[Array]::Copy($suffix,0,$after,$base.Length,$suffix.Length)
    $guid=([Guid]$Context.EndpointGuid).ToString('B').ToUpperInvariant();$endpoint='{0.0.0.00000000}.'+$guid.ToLowerInvariant()
    $snippet="# AtmosDirectSpatial: restrito a esta saida fisica.`r`nDevice: $guid`r`nStage: post-mix`r`nChannel: all`r`nVSTPlugin: Library `"$root\AtmosDirectSpatialCapture.dll`"`r`n"
    Assert-AdsHash $Context.ConfigPath $beforeHash
    [IO.Directory]::CreateDirectory($root)|Out-Null;& $Context.Ops.ProtectDirectory $root $false $Context.UserSid
    foreach ($directory in @('data','backups','installer')) { [IO.Directory]::CreateDirectory((Join-Path $root $directory))|Out-Null }
    & $Context.Ops.ProtectDirectory (Join-Path $root 'data') $true $Context.UserSid
    $backup=Join-Path $root ('backups\'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')+'-'+[Guid]::NewGuid().ToString('N')+'-config.original.bin')
    [IO.File]::WriteAllBytes($backup,$before);Assert-AdsHash $backup $beforeHash
    foreach ($name in @('AtmosDirectSpatial.exe','AtmosDirectSpatialCapture.dll')) { [IO.File]::Copy((Join-Path $Context.Package $name),(Join-Path $root $name),$false) }
    $support=Copy-AdsSupport $Context
    [IO.File]::WriteAllText((Join-Path $root 'capture.txt'),$snippet,[Text.UTF8Encoding]::new($false))
    Set-AdsDisabled $Context $endpoint;& $Context.Ops.Prepare (Join-Path $root 'AtmosDirectSpatial.exe')
    $m=[pscustomobject]@{schema=1;created_utc=[DateTime]::UtcNow.ToString('o');install_root=$root;user_sid=$Context.UserSid;endpoint_guid=$guid;endpoint_id=$endpoint;config_path=$Context.ConfigPath;config_before_sha256=$beforeHash;config_after_sha256=(Get-BytesHash $after);backup_path=$backup;original_byte_count=$before.Length;snippet_path=(Join-Path $root 'capture.txt');preflight_path=(Join-Path $root 'installation.ini');factory_preset_neutralized=$neutral;snippet_sha256=(Get-FileHashValue (Join-Path $root 'capture.txt'));dll_sha256=(Get-FileHashValue (Join-Path $root 'AtmosDirectSpatialCapture.dll'));exe_sha256=(Get-FileHashValue (Join-Path $root 'AtmosDirectSpatial.exe'));support_files_sha256=$support;product_version=$Context.Version}
    Write-AdsMetadata $Context $m;Write-AtomicReplacement $Context.ConfigPath $after $beforeHash
    Assert-AdsHash $Context.ConfigPath $m.config_after_sha256;& $Context.Ops.Register $Context $m
    return $m
}
function Update-AdsProduct($Context) {
    $m=Read-AdsInstallation $Context $true
    if (([Guid]$Context.EndpointGuid) -ne ([Guid]$m.endpoint_guid)) { throw 'Para mudar a saida de captura, remova e instale novamente na nova saida associada.' }
    & $Context.Ops.CheckEndpoint $m.endpoint_guid
    & $Context.Ops.StopControllers $Context $m.exe_sha256
    Set-AdsDisabled $Context $m.endpoint_id;& $Context.Ops.CheckStopped $Context
    $current=[IO.File]::ReadAllBytes($Context.ConfigPath);$currentHash=Get-BytesHash $current
    Assert-AdsHash $Context.ConfigPath $m.config_after_sha256
    $changed=@()
    foreach ($name in @('AtmosDirectSpatial.exe','AtmosDirectSpatialCapture.dll')) {
        $source=Join-Path $Context.Package $name;$target=Join-Path $Context.Root $name
        if ((Get-FileHashValue $source) -ne (Get-FileHashValue $target)) { $changed+=$name }
    }
    $detached=$false;$detachedHash=$null;$rollback=$null
    if ($changed.Count) {
        $original=[IO.File]::ReadAllBytes($m.backup_path)
        # Use removal of the exact managed suffix, not restoration of the factory preset, during upgrade.
        $copy=$m|ConvertTo-Json -Depth 8|ConvertFrom-Json;$copy.config_after_sha256='0'*64
        $without=Get-AdsUninstallConfiguration $current $original $copy
        Write-AtomicReplacement $Context.ConfigPath $without $currentHash;$detached=$true;$detachedHash=Get-BytesHash $without
    }
    try {
        foreach ($name in $changed) {
            $target=Join-Path $Context.Root $name
            $deadline=[DateTime]::UtcNow.AddSeconds(10);$handle=$null
            do { try { $handle=[IO.File]::Open($target,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) } catch { if ([DateTime]::UtcNow -ge $deadline) { throw 'Arquivo de audio ainda carregado. Feche os aplicativos de audio e tente novamente; nenhum servico sera reiniciado.' };Start-Sleep -Milliseconds 100 } } while (!$handle)
            $handle.Dispose()
        }
        if ($changed.Count) { $rollback=Join-Path $Context.Root ('backups\upgrade-'+[Guid]::NewGuid().ToString('N'));[IO.Directory]::CreateDirectory($rollback)|Out-Null }
        foreach ($name in $changed) {
            $target=Join-Path $Context.Root $name;[IO.File]::Copy($target,(Join-Path $rollback $name),$false)
            Write-AtomicReplacement $target ([IO.File]::ReadAllBytes((Join-Path $Context.Package $name))) (Get-FileHashValue $target)
        }
        if ($changed.Count) { & $Context.Ops.Prepare (Join-Path $Context.Root 'AtmosDirectSpatial.exe') }
        $support=Copy-AdsSupport $Context
        $m.exe_sha256=Get-FileHashValue (Join-Path $Context.Root 'AtmosDirectSpatial.exe');$m.dll_sha256=Get-FileHashValue (Join-Path $Context.Root 'AtmosDirectSpatialCapture.dll')
        $m.support_files_sha256=$support
        $m|Add-Member -NotePropertyName product_version -NotePropertyValue $Context.Version -Force
        Write-AdsMetadata $Context $m
        if ($detached) { Write-AtomicReplacement $Context.ConfigPath $current $detachedHash }
        Assert-AdsHash $Context.ConfigPath $currentHash
        & $Context.Ops.Register $Context $m
        return $m
    } catch {
        # If binary replacement did not begin, restore only the unchanged detached config.
        # Otherwise leave capture detached and preserve upgrade backups for explicit recovery.
        if ($detached -and !$rollback -and (Get-FileHashValue $Context.ConfigPath) -eq $detachedHash) { Write-AtomicReplacement $Context.ConfigPath $current $detachedHash }
        throw
    }
}
function Uninstall-AdsProduct($Context) {
    $m=Read-AdsInstallation $Context $false
    $current=[IO.File]::ReadAllBytes($Context.ConfigPath);$currentHash=Get-BytesHash $current
    $original=[IO.File]::ReadAllBytes($m.backup_path)
    $after=Get-AdsUninstallConfiguration $current $original $m
    & $Context.Ops.StopControllers $Context $m.exe_sha256
    Set-AdsDisabled $Context $m.endpoint_id;& $Context.Ops.CheckStopped $Context
    $uninstallBackup=Join-Path $Context.Root ('backups\'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')+'-config.before-uninstall.bin')
    [IO.File]::WriteAllBytes($uninstallBackup,$current);Assert-AdsHash $uninstallBackup $currentHash
    Write-AtomicReplacement $Context.ConfigPath $after $currentHash
    # A host can keep the VST DLL/mapping alive after config reload. Detect that
    # before removing metadata or registration so retry remains possible.
    $detachedHash=Get-BytesHash $after
    try {
        $deadline=[DateTime]::UtcNow.AddSeconds(10)
        foreach ($relative in @('AtmosDirectSpatialCapture.dll','data\capture.bin')) {
            $path=Join-Path $Context.Root $relative;Assert-NoReparsePath $path
            $handle=$null
            do {
                try { $handle=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) }
                catch { if ([DateTime]::UtcNow -ge $deadline) { throw 'Captura ainda carregada. Feche os aplicativos de audio e tente remover novamente; arquivos e registro foram preservados.' };Start-Sleep -Milliseconds 100 }
            } while (!$handle)
            $handle.Dispose()
        }
    } catch {
        Write-AtomicReplacement $Context.ConfigPath $current $detachedHash
        Assert-AdsHash $Context.ConfigPath $currentHash
        throw
    }
    & $Context.Ops.Unregister $Context
    $owned=@('AtmosDirectSpatial.exe','AtmosDirectSpatialCapture.dll','AtmosDirectSpatialSetup.exe','Capture.Common.ps1','Restore-Capture.ps1','LEIA-ME.txt','PROVENIENCIA.md','VALIDACAO.md','VALIDACAO.txt','capture.txt','installation.ini','installation.json','installer\Lifecycle.ps1','installer\Lifecycle.Core.ps1','installer\payload.json','data\capture.bin','data\AtmosDirectSpatial.ini','data\AtmosDirectSpatial.status.ini','data\AtmosDirectSpatial.status.ini.tmp','data\AtmosDirectSpatial.ini.tmp')
    $retained=[Collections.Generic.List[string]]::new()
    foreach ($relative in $owned) {
        $path=Join-Path $Context.Root $relative;Assert-NoReparsePath $path
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $deadline=[DateTime]::UtcNow.AddSeconds(10)
        do { try { Remove-Item -LiteralPath $path -Force -ErrorAction Stop;break } catch { if ([DateTime]::UtcNow -ge $deadline) { $retained.Add($relative);break };Start-Sleep -Milliseconds 100 } } while ($true)
    }
    foreach ($name in @('data','installer')) { $path=Join-Path $Context.Root $name;if ((Test-Path -LiteralPath $path) -and @(Get-ChildItem -LiteralPath $path -Force).Count -eq 0) { [IO.Directory]::Delete($path,$false) } }
    $recordPath=Join-Path $Context.Root 'backups\uninstallation.json'
    if (Test-Path -LiteralPath $recordPath) { [IO.File]::Copy($recordPath,(Join-Path $Context.Root ('backups\uninstallation-'+[Guid]::NewGuid().ToString('N')+'.json')),$false) }
    $backupHashes=@{};$backupRoot=Join-Path $Context.Root 'backups'
    foreach ($file in @(Get-ChildItem -LiteralPath $backupRoot -File -Recurse -Force)) { if ($file.FullName -ne $recordPath) { Assert-NoReparsePath $file.FullName;$backupHashes[$file.FullName.Substring($backupRoot.Length+1)]=Get-FileHashValue $file.FullName } }
    $record=[ordered]@{schema=1;install_root=$Context.Root;user_sid=$Context.UserSid;removed_utc=[DateTime]::UtcNow.ToString('o');original_backup=$m.backup_path;config_before_uninstall_backup=$uninstallBackup;config_after_uninstall_sha256=(Get-BytesHash $after);backup_files_sha256=$backupHashes;retained_files=$retained.ToArray();note='Equalizer APO, associacoes FX e outros dispositivos foram preservados. Backups nunca sao apagados pelo desinstalador.'}
    [IO.File]::WriteAllText($recordPath,($record|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    return [pscustomobject]$record
}
