<#
.SYNOPSIS
Restaura config.txt byte a byte somente se ele ainda coincide com a versao instalada.
.DESCRIPTION
Sem -Apply, apenas le e mostra a comparacao. -Apply -WhatIf nao modifica nada.
Preserva binarios, data, manifesto e todos os backups. Nao altera FX, servicos, drivers
ou VB-CABLE. Se alguem editou a configuracao apos a instalacao, a restauracao e recusada
para preservar essas alteracoes: revise o bloco final manualmente usando o backup.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param([switch] $Apply)
. (Join-Path $PSScriptRoot 'Capture.Common.ps1')
$root = Get-CaptureRoot
Assert-NoReparsePath $root
$manifestPath = Join-Path $root 'installation.json'
if (!(Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Manifesto nao encontrado: $manifestPath" }
Assert-NoReparsePath $manifestPath
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schema -ne 1 -or [IO.Path]::GetFullPath($manifest.install_root) -ne [IO.Path]::GetFullPath($root)) {
    throw 'Manifesto desconhecido ou destino incompativel; restauracao recusada.'
}
$backupPath = [IO.Path]::GetFullPath($manifest.backup_path)
$backupRoot = [IO.Path]::GetFullPath((Join-Path $root 'backups')).TrimEnd('\') + '\'
if (!$backupPath.StartsWith($backupRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'O backup deve estar dentro da pasta backups desta instalacao.'
}
$configPath = [IO.Path]::GetFullPath($manifest.config_path)
Assert-NoReparsePath $backupPath
Assert-NoReparsePath $configPath
$original = [IO.File]::ReadAllBytes($backupPath)
if ($original.Length -ne $manifest.original_byte_count -or
    (Get-BytesHash $original) -ne $manifest.config_before_sha256) {
    throw 'Backup nao coincide com o tamanho/SHA-256 registrado; nao foi restaurado.'
}
$currentHash = Get-FileHashValue $configPath
if ($currentHash -eq $manifest.config_before_sha256) {
    Write-Output 'config.txt ja coincide byte a byte com o backup original. Nenhuma alteracao necessaria; todos os arquivos foram preservados.'
    return
}
if ($currentHash -ne $manifest.config_after_sha256) {
    throw "config.txt mudou desde a instalacao. Restauracao automatica recusada para preservar essas mudancas. Revise manualmente o bloco AtmosDirectSpatial em $configPath usando $backupPath."
}
Write-Output "Plano: restaurar $configPath a partir de $backupPath ($($original.Length) bytes; SHA-256 $($manifest.config_before_sha256))."
Write-Output 'O Include deixara de carregar a captura; a configuracao anterior do Equalizer APO volta integralmente. Backups, binarios e data permanecem.'
Write-Output 'Feche o controlador AtmosDirectSpatial antes de aplicar. O script nao encerra processos nem reinicia servicos.'
if (!$Apply) { Write-Output 'Somente previa. Nenhuma alteracao. Use -Apply apos aprovar; -Apply -WhatIf tambem permanece previa.'; return }
if (!$PSCmdlet.ShouldProcess($configPath, 'Restaurar configuracao original com protecao SHA-256')) { return }
Assert-CaptureAdministrator
if (@(Get-Process -Name 'AtmosDirectSpatial' -ErrorAction SilentlyContinue).Count -gt 0) {
    throw 'O controlador AtmosDirectSpatial esta aberto. Feche-o antes da restauracao; nenhum processo foi encerrado.'
}
Write-AtomicReplacement $configPath $original $manifest.config_after_sha256
if ((Get-FileHashValue $configPath) -ne $manifest.config_before_sha256) {
    throw 'A configuracao mudou durante/depois da restauracao; arquivos e backups foram preservados.'
}
Write-Output 'Restaurado e verificado byte a byte pelo tamanho/SHA-256 original. Todos os backups foram preservados.'
