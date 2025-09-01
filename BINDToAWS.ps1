# LOAD CONFIGURATION
$config = Get-Content "config.json" | ConvertFrom-Json

$zoneFilePath = $config.InputZonePath
$hostedZoneId = $config.HostedZoneId
$dryRun       = $config.DryRun

$auditLog = @()

# LOAD BIND ZONE FILE
$zoneLines = Get-Content $zoneFilePath | Where-Object { $_ -match '^\S+\s+\d+\s+IN\s+\S+' }

# PARSE BIND RECORDS
$bindRecords = @()
foreach ($line in $zoneLines) {
    $parts = $line -split '\s+'
    $name  = $parts[0].TrimEnd(".")
    $ttl   = [int]$parts[1]
    $type  = $parts[3].ToUpper()
    $value = ($parts[4..($parts.Count - 1)] -join ' ').Trim('"')

    if ($type -in @("SOA", "NS")) { continue }  # Skip SOA and NS

    if ($type -eq "TXT") {
        $value = $value.Trim('"')
    }

    $bindRecords += [PSCustomObject]@{
        Name  = $name
        Type  = $type
        TTL   = $ttl
        Value = $value
    }
}

# LOAD SECRETS FROM VAULT
try {
    $accessKey    = Get-Secret -Name $config.AWSAccessKey -AsPlainText
    $secretKey    = Get-Secret -Name $config.AWSSecretKey -AsPlainText
    $sessionToken = Get-Secret -Name $config.AWSSessionToken -AsPlainText
} catch {
    Write-Warning "❌ Could not retrieve AWS secrets. Check vault names and availability."
    exit
}

# FETCH CURRENT AWS RECORDS
$awsRecordsRaw = Get-R53ResourceRecordSet -HostedZoneId $hostedZoneId `
    -AccessKey $accessKey `
    -SecretKey $secretKey `
    -SessionToken $sessionToken `
    -Region "us-east-1"

$awsRecords = @()
foreach ($r in $awsRecordsRaw.ResourceRecordSets) {
    if ($r.Type -in @("SOA", "NS")) { continue }

    foreach ($rr in $r.ResourceRecords) {
        $awsRecords += [PSCustomObject]@{
            Name  = $r.Name.TrimEnd(".")
            Type  = $r.Type
            TTL   = $r.TTL
            Value = $rr.Value.Trim('"')
        }
    }
}

# COMPARE AND BUILD CHANGE SET
$changeBatch = @()
foreach ($bind in $bindRecords) {
    $match = $awsRecords | Where-Object {
        $_.Name -eq $bind.Name -and $_.Type -eq $bind.Type
    }

    if ($match.Count -eq 0) {
        $action = "UPSERT"
        $auditLog += "UPSERT: $($bind.Name) $($bind.Type) $($bind.Value)"
    }
    elseif ($match | Where-Object { $_.Value -eq $bind.Value -and $_.TTL -eq $bind.TTL }) {
        $action = "UNCHANGED"
        $auditLog += "UNCHANGED: $($bind.Name) $($bind.Type) $($bind.Value)"
        continue
    }
    else {
        $action = "UPSERT"
        $auditLog += "MODIFIED: $($bind.Name) $($bind.Type) $($bind.Value)"
    }

    if ($action -eq "UPSERT") {
        $changeBatch += @{
            Action = "UPSERT"
            ResourceRecordSet = @{
                Name = $bind.Name
                Type = $bind.Type
                TTL  = $bind.TTL
                ResourceRecords = @(@{ Value = $bind.Value })
            }
        }
    }
}

# FIND DELETIONS
foreach ($aws in $awsRecords) {
    $exists = $bindRecords | Where-Object {
        $_.Name -eq $aws.Name -and $_.Type -eq $aws.Type -and $_.Value -eq $aws.Value
    }

    if (-not $exists) {
        $auditLog += "DELETE: $($aws.Name) $($aws.Type) $($aws.Value)"
        $changeBatch += @{
            Action = "DELETE"
            ResourceRecordSet = @{
                Name = $aws.Name
                Type = $aws.Type
                TTL  = $aws.TTL
                ResourceRecords = @(@{ Value = $aws.Value })
            }
        }
    }
}

# OUTPUT AUDIT TRAIL
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$logFile = "audit-trail-$timestamp.txt"
$auditLog | Set-Content $logFile
Write-Host "📝 Audit trail saved to $logFile"

# DRY RUN OR EXECUTE
if ($dryRun) {
    Write-Host "🚫 Dry run mode enabled — no changes submitted to AWS"
    $changeBatch | ConvertTo-Json -Depth 5 | Out-File "dry-run-changes-$timestamp.json"
    Write-Host "📦 Change batch saved to dry-run-changes-$timestamp.json"
} else {
    Edit-R53ResourceRecordSet -HostedZoneId $hostedZoneId `
        -AccessKey $accessKey `
        -SecretKey $secretKey `
        -SessionToken $sessionToken `
        -Region "us-east-1" `
        -ChangeBatch_Change $changeBatch
    Write-Host "✅ Changes submitted to Route 53"
}