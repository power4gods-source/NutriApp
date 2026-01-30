# Ejecuta flutter pub get en la carpeta nutri_track.
# Ejecuta desde la raíz del repo (NutriApp) o desde nutri_track:
#   .\nutri_track\run_pub_get.ps1
# o desde nutri_track:
#   .\run_pub_get.ps1

Set-Location $PSScriptRoot
$result = & flutter pub get 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "Si 'flutter' no se reconoce, asegúrate de tener Flutter en el PATH"
  Write-Host "o ejecuta: flutter pub get"
  Write-Host "desde la carpeta nutri_track en tu terminal."
  exit 1
}
Write-Host ""
Write-Host "Dependencias instaladas. Si el IDE sigue mostrando error, reinícialo o"
Write-Host "abre la carpeta nutri_track como raíz del proyecto."
exit 0
