# R53ToBIND PowerShell Toolkit

This toolkit helps you export AWS Route53 DNS zones and convert them to BIND-compatible zone files, and also import BIND zone files back into Route53.  
It uses PowerShell, AWS.Tools modules, and the Microsoft.PowerShell.SecretManagement vault for secure credential handling.

---

## Prerequisites

- PowerShell 7+ (recommended)
- [AWS.Tools.Route53](https://www.powershellgallery.com/packages/AWS.Tools.Route53) and [AWS.Tools.Common](https://www.powershellgallery.com/packages/AWS.Tools.Common)
- [Microsoft.PowerShell.SecretManagement](https://www.powershellgallery.com/packages/Microsoft.PowerShell.SecretManagement)
- AWS credentials (Access Key, Secret Key, Session Token) with Route53 read permissions

---

## Setup

### 1. Install Required Modules

```powershell
Install-Module -Name AWS.Tools.Route53 -Scope CurrentUser
Install-Module -Name AWS.Tools.Common -Scope CurrentUser
Install-Module -Name Microsoft.PowerShell.SecretManagement -Scope CurrentUser
```

### 2. Store Your AWS Credentials Securely

```powershell
Set-Secret -Name "AWSAccessKey"     -Secret "YOUR_ACCESS_KEY"
Set-Secret -Name "AWSSecretKey"     -Secret "YOUR_SECRET_KEY"
Set-Secret -Name "AWSSessionToken"  -Secret "YOUR_SESSION_TOKEN"
```

### 3. Create Your Configuration

Run the config script and answer the prompts:

```powershell
.\create-config.ps1
```

This will generate a `config.json` file with your settings.

### 4. Validate AWS Credentials and Hosted Zone Access

```powershell
.\validate-creds.ps1
```

- This script loads your config and secrets, then verifies access to the specified Route53 hosted zone.
- If successful, you’ll see:  
  `✅ Access granted — Hosted zone: 'domain.com'`
  
---

## Usage

### 1. Export Route53 Zone to BIND Format

```powershell
.\awsToBIND.ps1
```

- This script exports your Route53 zone to a BIND-compatible zone file (e.g. `domain.com.zone.txt`).

### 2. **Manual Audit Step (Required!)**

After running `awsToBIND.ps1`, **manually review and split the output zone file**:

- Open the generated `domain.com.zone.txt`.
- Create two files:
  - `domain.com.zone-pdns.txt` — for records you want to keep for PowerDNS or reference.
  - `domain.com.zone-trimmed.txt` — for records you want to re-import to AWS (remove unwanted or incompatible records).

> **Note:**  
> The `domain.com.zone-trimmed.txt` file will be used as input for the import step.  
> The filename should match what you set as `InputZonePath` in your `config.json`.

### 3. Import BIND Zone Back to Route53

```powershell
.\BINDToAWS.ps1
```

- This script reads your trimmed BIND zone file (`domain.com.zone-trimmed.txt`), compares it with current AWS records, and prepares a change batch.
- If `DryRun` is enabled in your config, no changes will be made and a dry-run file will be created.
- If `DryRun` is `false`, changes will be submitted to Route53.

---

## Example Workflow

```powershell
# 1. Set secrets
Set-Secret -Name "AWSAccessKey"     -Secret "..."
Set-Secret -Name "AWSSecretKey"     -Secret "..."
Set-Secret -Name "AWSSessionToken"  -Secret "..."

# 2. Create config
.\create-config.ps1

# 3. Validate credentials
.\validate-creds.ps1

# 4. Export Route53 zone to BIND
.\awsToBIND.ps1

# 5. MANUAL: Review and split output zone file into domain.com.zone-pdns.txt and domain.com.zone-trimmed.txt

# 6. Import trimmed BIND zone back to Route53
.\BINDToAWS.ps1
```

---

## Troubleshooting

- If you see errors about invalid tokens or missing zones:
  - Ensure your session token is current and matches your access/secret key.
  - Check IAM permissions for `route53:GetHostedZone`.
  - Confirm your `config.json` secret names match those in your vault.
- If you have multiple AWS PowerShell modules, uninstall all but the AWS.Tools.* modules.
- Make sure your `InputZonePath` in `config.json` points to your manually trimmed zone file.

---

## Notes

- All scripts are designed to be run in the current PowerShell session.
- Credentials are never stored in plain text; only secret references are kept in config.
- Manual review of exported zone files is required to ensure only valid records are imported back to AWS.

---

## License

MIT
