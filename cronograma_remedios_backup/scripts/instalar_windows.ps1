$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
flutter pub get
New-Item -ItemType Directory -Force build\motor | Out-Null
dart compile exe bin\motor_alarmes.dart -o build\motor\motor_alarmes.exe

# Encontra o mesmo arquivo SQLite que já foi criado pelo Flutter no Windows.
$bancos = @(Get-ChildItem -Path $env:APPDATA, $env:LOCALAPPDATA -Filter cronograma_remedios.db -Recurse -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName -Unique)
if ($bancos.Count -ne 1) {
    Write-Host "Encontrados $($bancos.Count) bancos. Configure manualmente o caminho do banco."
    exit 1
}
$executavel = (Resolve-Path 'build\motor\motor_alarmes.exe').Path
# Reinicia na entrada do usuário; não usa Python nem polling pelo Task Scheduler.
$acao = New-ScheduledTaskAction -Execute $executavel -Argument "--banco `"$($bancos[0])`""
$gatilho = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$config = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Seconds 0) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName 'CronogramaMotor' -Action $acao -Trigger $gatilho -Settings $config -Description 'Alarme de medicamentos' -Force | Out-Null
Start-ScheduledTask -TaskName 'CronogramaMotor'
Write-Host 'Motor instalado. Verifique no Agendador de Tarefas.'
