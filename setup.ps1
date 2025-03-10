
$spotifetchPath = (Split-Path -Parent $PSCommandPath)

if (!(Test-Path "$spotifetchPath\config.json")) {
  Write-Host "Coult not find config file"
  exit 1
}

$config = ( cat "$spotifetchPath\config.json" | ConvertFrom-Json )

[System.Environment]::SetEnvironmentVariable("SPOTIFY_CLIENT_ID",     $config.client_id,     "Process")
[System.Environment]::SetEnvironmentVariable("SPOTIFY_CLIENT_SECRET", $config.client_secret, "Process")
[System.Environment]::SetEnvironmentVariable("SPOTIFY_REDIRECT_URL",  $config.redirect_url,  "Process")

if (Test-Path "$spotifetchPath\.refresh") {
  [System.Environment]::SetEnvironmentVariable("SPOTIFY_REFRESH_TOKEN", $(cat "$spotifetchPath\.refresh"), "Process")
}
