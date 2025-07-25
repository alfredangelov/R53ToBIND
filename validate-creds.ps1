# Load configuration
Write-Host "🔍 Loading configuration from config.json..."
$config = Get-Content "config.json" | ConvertFrom-Json

# Display essential config values
Write-Host "ℹ️  HostedZoneId     → $($config.HostedZoneId)"
Write-Host "ℹ️  AWS region       → Using default: us-east-1"
Write-Host "ℹ️  Secret references:"
Write-Host "     AccessKey      → $($config.AWSAccessKey)"
Write-Host "     SecretKey      → $($config.AWSSecretKey)"
Write-Host "     SessionToken   → $($config.AWSSessionToken)"

# Load secrets
try {
    Write-Host "🔑 Fetching secrets from vault..."
    $accessKey    = Get-Secret -Name $config.AWSAccessKey -AsPlainText
    $secretKey    = Get-Secret -Name $config.AWSSecretKey -AsPlainText
    $sessionToken = Get-Secret -Name $config.AWSSessionToken -AsPlainText
    Write-Host "✅ Secrets retrieved"
} catch {
    Write-Warning "❌ Could not retrieve secrets. Check vault names and availability."
    exit
}

# Verify hosted zone access
try {
    Write-Host "🌐 Attempting to access hosted zone ID: $($config.HostedZoneId)..."
    $zoneResponse = Get-R53HostedZone -Id $config.HostedZoneId `
        -AccessKey $accessKey `
        -SecretKey $secretKey `
        -SessionToken $sessionToken `
        -Region "us-east-1"

    if (-not $zoneResponse.HostedZone) {
        Write-Warning "⚠️ No hosted zone found with ID: $($config.HostedZoneId)"
        return
    }

    Write-Host "✅ Access granted — Hosted zone: '$($zoneResponse.HostedZone.Name.TrimEnd('.'))'"
} catch {
    Write-Warning "❌ Unable to access HostedZoneId '$($config.HostedZoneId)'"
    Write-Host "🔍 Suggested Checks:"
    Write-Host "   • Is the session token still valid?"
    Write-Host "   • Are IAM permissions correctly scoped for 'route53:GetHostedZone'?"
    Write-Host "   • Double-check the HostedZoneId and region context"
}
