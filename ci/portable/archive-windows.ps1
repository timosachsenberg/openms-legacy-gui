# Required: GUI_STAGE GITHUB_WORKSPACE OPENMS_SHORT_SHA GITHUB_OUTPUT
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$artifactName = "OpenMSLegacyGUI-Windows-x64-openms-$env:OPENMS_SHORT_SHA"
$artifactDirectory = Join-Path $env:GITHUB_WORKSPACE "artifacts"
$zip = Join-Path $artifactDirectory "$artifactName.zip"
New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
Compress-Archive -Path $env:GUI_STAGE -DestinationPath $zip -CompressionLevel Optimal
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $artifactName.zip" | Set-Content "$zip.sha256" -Encoding ascii
"artifact_name=$artifactName" | Out-File `
  -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
