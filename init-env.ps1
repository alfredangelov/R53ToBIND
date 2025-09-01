# init-env.ps1
Write-Host "🔧 Initializing environment..."

# Check PowerShell version
$minMajorVersion = 7
$currentVersion = $PSVersionTable.PSVersion

if ($currentVersion.Major -lt $minMajorVersion) {
    Write-Warning "⚠️ PowerShell $($currentVersion.ToString()) detected. Minimum required version is $minMajorVersion.0."
    Write-Host "💡 To install the latest PowerShell:"
    Write-Host "• Windows: https://github.com/PowerShell/PowerShell/releases"
    Write-Host "• macOS / Linux: https://learn.microsoft.com/powershell/scripting/install/installing-powershell"
    Write-Host "🔄 Then rerun: .\init-env.ps1"
    exit
} else {
    Write-Host "✅ PowerShell $($currentVersion.ToString()) meets the requirement."
}

# Install required modules
Install-Module -Name AWSPowerShell.NetCore -Force
Install-Module -Name AWS.Tools.Route53 -Force

# Validate Set-AWSCredential is available
if (Get-Command -Name Set-AWSCredential -ErrorAction SilentlyContinue) {
    Write-Host "✅ AWS credential cmdlet found: Set-AWSCredential"
} else {
    Write-Host "❌ Missing AWS credential cmdlet. Check your module installation."
}

# Load credentials from saved secrets
$accessKey    = Get-Secret -Name AWSAccessKey -AsPlainText
$secretKey    = Get-Secret -Name AWSSecretKey -AsPlainText
$sessionToken = Get-Secret -Name AWSSessionToken -AsPlainText

# Initialize AWS credentials
Set-AWSCredential -AccessKey $accessKey `
                  -SecretKey $secretKey `
                  -SessionToken $sessionToken

Write-Host "✅ AWS credentials loaded and environment is ready"
