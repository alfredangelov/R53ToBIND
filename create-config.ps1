# Load template
$configPath   = "config.json"

Write-Host "🛠️ Creating config.json from template..."

# Prompt user for each field
$hostedZoneId   = Read-Host "Enter your HostedZoneId"
$accessKeyName  = Read-Host "Enter name of your AWSAccessKey secret"
$secretKeyName  = Read-Host "Enter name of your AWSSecretKey secret"
$sessionToken   = Read-Host "Enter name of your AWSSessionToken secret"
$dumpFile       = Read-Host "Enter desired RecordDumpPath (e.g. domain.com-records.json)"
$inputZonePath  = Read-Host "Enter InputZonePath (e.g. domain.com.zone-trimmed.txt)"
$outputBindPath = Read-Host "Enter OutputBindPath (e.g. domain.com.zone.txt)"
$origin         = Read-Host "Enter \$ORIGIN value (e.g. domain.com.)"
$ttl            = Read-Host "Enter default TTL (e.g. 900)"
$dryRun         = Read-Host "Enable dry-run mode? (true/false)"

# Build config object
$configObject = @{
    HostedZoneId     = $hostedZoneId
    AWSAccessKey     = $accessKeyName
    AWSSecretKey     = $secretKeyName
    AWSSessionToken  = $sessionToken
    RecordDumpPath   = $dumpFile
    InputZonePath    = $inputZonePath
    OutputBindPath   = $outputBindPath
    Origin           = $origin
    TTL              = [int]$ttl
    DryRun           = [bool]::Parse($dryRun)
}

# Save to config.json
$configObject | ConvertTo-Json -Depth 3 | Set-Content $configPath

Write-Host "✅ Config saved to $configPath"
Write-Host "You should now set:"
Write-Host "• AWSAccessKey, AWSSecretKey, AWSSessionToken in your vault"
Write-Host " by running: "
Write-Host 'Set-Secret -Name "AWSAccessKey"     -Secret "YOUR_ACCESS_KEY"'
Write-Host 'Set-Secret -Name "AWSSecretKey"     -Secret "YOUR_SECRET_KEY"'
Write-Host 'Set-Secret -Name "AWSSessionToken"  -Secret "YOUR_SESSION_TOKEN"'
