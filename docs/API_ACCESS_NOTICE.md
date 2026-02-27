# PanelApp Australia API Access Notice

## Current Situation

As of February 2026, PanelApp Australia has implemented access restrictions on automated API clients due to high costs associated with excessive traffic.

You may encounter the following message:
```
Due to high costs associated with excessive traffic, we are placing some restrictions 
on automated access by certain clients. Please contact us if this impacts you.
```

## What This Means

- The API is still available but requires proper identification and potentially authorization
- Anonymous or improperly identified automated clients may be blocked
- Legitimate users can request access by contacting PanelApp Australia

## How to Regain Access

### Step 1: Update Your Configuration

This project now includes proper User-Agent identification. Before running the scripts:

1. Open the extraction scripts:
   - `scripts/extract_PanelList.ps1`
   - `scripts/extract_PanelList.sh`
   - `scripts/extract_Genes.ps1`
   - `scripts/extract_Genes.sh`

2. Find the `$UserAgent` or `USER_AGENT` variable

3. Replace `contact-email-here@example.com` with your actual email:
   ```powershell
   # PowerShell
   $UserAgent = "PanelAppAusDB-Extractor/1.0 (GitHub:ChrisRem85/PanelAppAusDB; your.name@institution.edu)"
   ```
   ```bash
   # Bash
   USER_AGENT="PanelAppAusDB-Extractor/1.0 (GitHub:ChrisRem85/PanelAppAusDB; your.name@institution.edu)"
   ```

### Step 2: Contact PanelApp Australia

If access is still restricted after updating your User-Agent:

1. **Contact Page**: https://panelapp-aus.org/about/contact/

2. **Information to Provide**:
   - Your name and institution/organization
   - Your use case (research, clinical, etc.)
   - Frequency of access needed
   - Whether you've updated the User-Agent string
   - Your contact email

3. **Sample Email Template**:
   ```
   Subject: Request for Automated API Access Authorization
   
   Dear PanelApp Australia Team,
   
   I am using the PanelAppAusDB extractor tool (GitHub:ChrisRem85/PanelAppAusDB) 
   for [describe your use case: clinical genomics research, diagnostic panel 
   maintenance, etc.].
   
   I have configured the tool to properly identify my requests with the following 
   User-Agent:
   PanelAppAusDB-Extractor/1.0 (GitHub:ChrisRem85/PanelAppAusDB; your.email@institution.edu)
   
   I typically need to access the API [frequency: weekly/monthly] to update my 
   local database copy.
   
   Could you please authorize automated access for my use case?
   
   Thank you,
   [Your Name]
   [Institution]
   ```

## Built-in Protections

This project now includes several measures to reduce API load:

### Rate Limiting
- **500ms delay** between API requests by default
- Configurable via `$RequestDelayMs` (PowerShell) or `REQUEST_DELAY` (Bash)
- To increase delay (be more respectful):
  ```powershell
  # PowerShell: 1 second delay
  $RequestDelayMs = 1000
  ```
  ```bash
  # Bash: 1 second delay
  REQUEST_DELAY=1.0
  ```

### Version Tracking
- Only downloads data when panel versions change
- Use `-Force` flag to override (use sparingly)
- Prevents unnecessary repeated downloads

### Proper Identification
- User-Agent header on all requests
- Identifies the tool and provides contact information
- Allows PanelApp to reach you if needed

## Alternative: Request a Data Dump

If you need bulk access to all data at once, consider requesting a complete data dump from PanelApp Australia instead of using automated extraction. This would:
- Reduce load on their API infrastructure
- Give you a complete snapshot at once
- Be more suitable for one-time or infrequent large-scale analyses

## Best Practices

1. **Only run when needed**: Don't schedule frequent automated runs
2. **Use version tracking**: Let the built-in version tracking prevent unnecessary downloads
3. **Increase delays if needed**: If you have time, increase the request delay
4. **Update your contact info**: Keep your User-Agent email current
5. **Consider local caching**: Use the extracted data rather than repeatedly downloading
6. **Be responsive**: If PanelApp contacts you via email, respond promptly

## Troubleshooting

### Still getting blocked after updating User-Agent?
- Wait 24 hours for the change to take effect
- Contact PanelApp Australia directly
- Check if your IP has been rate-limited

### Need immediate access?
- Check if you have a previously cached version in `data/`
- Use the version tracking to minimize new requests
- Contact PanelApp for urgent access

### Checking your current settings
Look for these lines in the extraction scripts:
```powershell
# PowerShell
$UserAgent = "..."
$RequestDelayMs = 500
```
```bash
# Bash
USER_AGENT="..."
REQUEST_DELAY=0.5
```

## Updates to This Project

Changes made to address API restrictions:
- ✅ Added User-Agent headers to all API requests
- ✅ Implemented rate limiting (500ms default delay)
- ✅ Added configuration guidance in README
- ✅ Created this documentation
- ✅ Updated all extraction scripts (PowerShell and Bash)

## Questions?

If you have questions about:
- **This tool**: Open an issue on GitHub (ChrisRem85/PanelAppAusDB)
- **API access**: Contact PanelApp Australia directly
- **Authorization status**: Contact PanelApp Australia at their contact page
