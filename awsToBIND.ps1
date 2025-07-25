# Load configuration from JSON
$config = Get-Content "config.json" | ConvertFrom-Json

# Load AWS credentials from secrets
$accessKey    = Get-Secret -Name $config.AWSAccessKey -AsPlainText
$secretKey    = Get-Secret -Name $config.AWSSecretKey -AsPlainText
$sessionToken = Get-Secret -Name $config.AWSSessionToken -AsPlainText

Set-AWSCredential -AccessKey $accessKey `
                  -SecretKey $secretKey `
                  -SessionToken $sessionToken

# Fetch Route 53 records and export to JSON
Get-R53ResourceRecordSet -HostedZoneId $config.HostedZoneId |
    ConvertTo-Json -Depth 10 |
    Out-File $config.RecordDumpPath  # You can add this to config if desired

# Load record data from JSON
$records = Get-Content $config.RecordDumpPath | ConvertFrom-Json

# SOA setup
$soaSerial = (Get-Date -Format "yyyyMMdd") + "01"
$soaRecord = "$($config.Origin) $($config.TTL) IN SOA ns-1316.awsdns-36.org. awsdns-hostmaster.amazon.com. $soaSerial 7200 900 1209600 86400"

# Output header
Set-Content -Path $config.OutputBindPath -Value "; Zone file for $($config.Origin)"
Add-Content -Path $config.OutputBindPath -Value "`$ORIGIN $($config.Origin)"
Add-Content -Path $config.OutputBindPath -Value "`$TTL $($config.TTL)"
Add-Content -Path $config.OutputBindPath -Value $soaRecord
Add-Content -Path $config.OutputBindPath -Value ""

# Process Route 53 records
foreach ($record in $records.ResourceRecordSets) {
    $name = "$($record.Name.TrimEnd('.'))"
    $type = $record.Type.Value
    $ttl  = $record.TTL

    if ($record.ResourceRecords) {
        foreach ($rr in $record.ResourceRecords) {
            $value = $rr.Value

            switch ($type.ToUpper()) {
                "TXT" {
                    $value = '"' + $value.Replace('"', '\"') + '"'
                }
                "SRV" {
                    $parts = $value -split '\s+'
                    if ($parts.Count -eq 4) {
                        $value = "$($parts[0]) $($parts[1]) $($parts[2]) $($parts[3])"
                    }
                }
            }

            $line = "$name $ttl IN $type $value"
            Add-Content -Path $config.OutputBindPath -Value $line
        }
    }

    if ($record.AliasTarget) {
        $alias = "$($record.AliasTarget.DNSName.TrimEnd('.'))"
        $line  = "$name $ttl IN $type $alias"
        Add-Content -Path $config.OutputBindPath -Value $line
    }
}
