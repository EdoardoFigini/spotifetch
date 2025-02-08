$OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding

$apiURL = "https://api.spotify.com/v1"

$clientId =     $null 
$clientSecret = $null 
$refreshToken = $null 
$listenerURL =  $null

$primaryColor = "Gray"
$secondaryColor = "DarkGray"
$accentColor = "Blue"

$image = @(
  " ⠀⠀⠀⠀⠀⠀⠀⢀⣠⣤⣤⣶⣶⣶⣶⣤⣤⣄⡀⠀⠀⠀⠀⠀⠀"
  "⠀⠀⠀⠀⢀⣤⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣤⡀⠀⠀⠀⠀"
  "⠀⠀⠀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⠀⠀⠀"
  "⠀⢀⣾⣿⡿⠿⠛⠛⠛⠉⠉⠉⠉⠛⠛⠛⠿⠿⣿⣿⣿⣿⣿⣷⡀⠀"
  "⠀⣾⣿⣿⣇⠀⣀⣀⣠⣤⣤⣤⣤⣤⣀⣀⠀⠀⠀⠈⠙⠻⣿⣿⣷⠀"
  "⢠⣿⣿⣿⣿⡿⠿⠟⠛⠛⠛⠛⠛⠛⠻⠿⢿⣿⣶⣤⣀⣠⣿⣿⣿⡄"
  "⢸⣿⣿⣿⣿⣇⣀⣀⣤⣤⣤⣤⣤⣄⣀⣀⠀⠀⠉⠛⢿⣿⣿⣿⣿⡇"
  "⠘⣿⣿⣿⣿⣿⠿⠿⠛⠛⠛⠛⠛⠛⠿⠿⣿⣶⣦⣤⣾⣿⣿⣿⣿⠃"
  "⠀⢿⣿⣿⣿⣿⣤⣤⣤⣤⣶⣶⣦⣤⣤⣄⡀⠈⠙⣿⣿⣿⣿⣿⡿⠀"
  "⠀⠈⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣾⣿⣿⣿⣿⡿⠁⠀"
  "⠀⠀⠀⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠀⠀⠀"
  "⠀⠀⠀⠀⠈⠛⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠛⠁⠀⠀⠀⠀"
  "⠀⠀⠀⠀⠀⠀⠀⠈⠙⠛⠛⠿⠿⠿⠿⠛⠛⠋⠁⠀⠀⠀⠀⠀⠀⠀"
)

[System.Collections.Hashtable] $stats = @{
  Username = ""
  CurrentlyPlaying = ""
  Followers = 0
  TopArtist = ""
  TopSong = ""
  TopArtistsYear = @()
  TopSongsYear = @()
};

function Authorize()
{
  try
  {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("$listenerURL/")
    $listener.Start()

    $request = @{
      Uri = 'https://accounts.spotify.com/authorize'
      Method = 'GET'
      Headers = @{
        ContentType = 'application/x-www-form-urlencoded'
      }
      Body = @{
        response_type = 'code'
        client_id = $clientId
        scope = 'user-read-private user-top-read user-read-playback-state'
        redirect_uri = "$listenerURL/callback"
        state = -join ((97..122) | Get-Random -Count 16 | ForEach-Object {[char]$_} )
      }
    }


    $params = (($request.Body.GetEnumerator() | ForEach-Object { "$($_.Key)=$([System.Web.HttpUtility]::UrlEncode($_.Value))" } ) -join '&')
    Start-Process ($request.Uri + '?' + $params)

    while ($true)
    {

      $context = $listener.GetContext()
      $request = $context.Request

      $rawUrl = $request.RawUrl

      $Parameters = @{}
      $rawUrl = $rawUrl.Split("?")
      $rawParameters = $rawUrl[1]
      if ($rawParameters)
      {
        $rawParameters = $rawParameters.Split("&")

        foreach ($rawParameter in $rawParameters)
        {
          $Parameter = $rawParameter.Split("=")

          $Parameters.Add($Parameter[0], $Parameter[1])
        }
      }

      if ($Parameters.keys -contains "code")
      {
        $code = $Parameters["code"]
      } else
      {
        $code = ""
      }

      $output = "<!DOCTYPE HTML><html><h1>Authorization succesful</h1>You can now close this window</html>`n`n"
      $buffer = [System.Text.Encoding]::UTF8.GetBytes($output)


      $response = $context.Response
      $response.statusCode = 200
      $response.ContentLength64 = $buffer.Length
      $out = $response.OutputStream
      $out.Write($buffer, 0, $buffer.Length)
      $out.Close()

      break
    }
  } finally
  {
    $listener.Stop()
  }

  return $code
}

function GetToken($authcode, $mode)
{
  if ($mode -eq 'auth')
  {
    $params = @{
      Uri = 'https://accounts.spotify.com/api/token'
      Method = 'POST'
      Headers = @{
        Authorization = "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($clientId):$($clientSecret)")))"
        ContentType = 'application/x-www-form-urlencoded'
      }
      Body = @{
        grant_type = 'authorization_code'
        code = $authcode
        redirect_uri = 'http://localhost:12001/callback'
      }
    }
  } else 
  {
    $params = @{
      Uri = 'https://accounts.spotify.com/api/token'
      Method = 'POST'
      Headers = @{
        Authorization = "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($clientId):$($clientSecret)")))"
        ContentType = 'application/x-www-form-urlencoded'
      }
      Body = @{
        grant_type = 'refresh_token'
        refresh_token = $authcode
      }
    }
      
  }

  $response = Invoke-RestMethod @params

  if ($mode -eq 'auth')
  {
    $refreshToken = $response.refresh_token
    Write-Output $refreshToken | Out-File .refresh
  }
  return $response.access_token
}

function GetUser($token)
{
  $params = @{
    Uri = "$apiURL/me"
    Method = 'GET'
    Headers = @{
      Authorization = "Bearer $token"
    }

  }

  $response = Invoke-RestMethod @params

  return @{ 
    DisplayName = $response.display_name
    Followers = $response.followers.total
    Country = $response.country
  }
}

function GetTopTracks($token, $range, $limit = 3)
{
  $params = @{
    Uri = "$apiURL/me/top/tracks"
    Method = 'GET'
    Headers = @{
      Authorization = "Bearer $token"
    }
    Body = @{
      limit = $limit
      time_range = $range
    }
  }
  $response = Invoke-RestMethod @params
  
  return $response.items
}

function GetTopArtists($token, $range, $limit = 3)
{
  $params = @{
    Uri = "$apiURL/me/top/artists"
    Method = 'GET'
    Headers = @{
      Authorization = "Bearer $token"
    }
    Body = @{
      limit = $limit
      time_range = $range
    }
  }
  $response = Invoke-RestMethod @params
  
  return $response.items
}

function GetPlayback($token, $country = 'IT')
{
  $params = @{
    Uri = "$apiURL/me/player"
    Method = 'GET'
    Headers = @{
      Authorization = "Bearer $token"
    }
    Body = @{
      market = $country
    }
  }

  return Invoke-RestMethod @params
}

function FormatTrack($track)
{
  return "$(($track.artists | ForEach-Object { $_.name }) -join ', ') - $($track.name)"
}

function Print
{
  $lines = New-Object System.Collections.ArrayList
  $lines.Add(@($stats.Username, $accentColor, $false)) | Out-Null
  $lines.Add(@(("-"*10), $secondaryColor, $false)) | Out-Null
  
  $lines.Add(@("Followers: ", $primaryColor, $true)) | Out-Null
  $lines.Add(@($stats.Followers, $secondaryColor, $false)) | Out-Null
  
  $lines.Add(@("Top Current Song: ", $primaryColor, $true)) | Out-Null
  $lines.Add(@((FormatTrack $stats.TopSong), $secondaryColor, $false)) | Out-Null
  
  $lines.Add(@("Top Current Artist: ", $primaryColor, $true)) | Out-Null
  $lines.Add(@($stats.TopArtist,  $secondaryColor, $false)) | Out-Null
  
  $lines.Add(@("Top Songs Of The Year: ", $primaryColor, $false)) | Out-Null
  $stats.TopSongsYear | ForEach-Object { $lines.Add(@("  $(FormatTrack $_)", $secondaryColor, $false)) | Out-Null }
  $lines.Add(@("Top Artists Of The Year: ", $primaryColor, $false)) | Out-Null
  $stats.TopArtistsYear | ForEach-Object { $lines.Add(@("  $($_.name)", $secondaryColor, $false)) | Out-Null }

  if ($stats.CurrentlyPlaying)
  {
    $lines.Add(@("Currently Playing: ", $primaryColor, $true)) | Out-Null
    $lines.Add(@((FormatTrack $stats.CurrentlyPlaying), $secondaryColor, $false)) | Out-Null
  }

  $rows = ($lines | Where-Object { $_[2] -eq $false } ).Count

  Write-Host ""
  $j = 0
  for ($i = 0; $i -lt ((@($rows, $image.Count) | Measure-Object -Max).Maximum); $i++)
  {
    if ($i -lt $image.Count)
    {
      Write-Host "$($image[$i])`t" -ForegroundColor Green -NoNewline
    } else
    {
      Write-Host "$(' '*$image[0].Length)`t" -NoNewline
    }
    if ($i -lt $rows)
    {
      do
      {
        Write-Host $lines[$j][0] -ForegroundColor $lines[$j][1] -NoNewline:$lines[$j][2]
        $j++
      } while ($lines[($j-1)][2] -eq $true)
    } else
    {
      Write-Host ""
    }
      
  }
  Write-Host ""
}


function main()
{
  try
  {
    .\setup.ps1
    $clientId =     [System.Environment]::GetEnvironmentVariable('SPOTIFY_CLIENT_ID')
    $clientSecret = [System.Environment]::GetEnvironmentVariable("SPOTIFY_CLIENT_SECRET")
    $refreshToken = [System.Environment]::GetEnvironmentVariable("SPOTIFY_REFRESH_TOKEN")
    $listenerURL =  [System.Environment]::GetEnvironmentVariable("SPOTIFY_REDIRECT_URL")


    if (( $null -ne $refreshToken ) -and ( $refreshToken -ne "" ))
    {
      $token = GetToken $refreshToken 'refresh'
    } else
    {
      $authcode = Authorize
      $token = GetToken $authcode 'auth'
    }

    $usrInfo = GetUser $token
    $stats.Username = $usrInfo.DisplayName
    $stats.Followers = $usrInfo.Followers

    $stats.TopSong = (GetTopTracks $token "short_term" 1)[0]
    $stats.TopSongsYear = GetTopTracks $token "long_term"

    $stats.TopArtist = (GetTopArtists $token "short_term" 1)[0].name
    $stats.TopArtistsYear = (GetTopArtists $token "long_term")

    while ($true) {
      $playback = GetPlayback $token $usrInfo.Country
      if ($null -ne $playback.item)
      {
        $stats.CurrentlyPlaying = $playback.item
      }
      
      cls
      Print

      Start-Sleep -Seconds 20
    }
      
  } catch {
    "An Error Occurred"
  }
}

main

