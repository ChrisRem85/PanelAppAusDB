# Scripts Configuration

## API Token Setup

To use these scripts, you need to configure your API token:

### Quick Setup

1. **Copy the template file:**
   ```powershell
   # PowerShell (Windows)
   Copy-Item scripts\config.ps1.template scripts\config.ps1
   ```
   ```bash
   # Bash (Linux/macOS)
   cp scripts/config.sh.template scripts/config.sh
   ```

2. **Edit the config file** and add your API token:
   - Windows: Edit `scripts/config.ps1`
   - Linux/macOS: Edit `scripts/config.sh`
   
3. **Add your token** (received from PanelApp Australia):
   ```powershell
   $APIToken = "your-token-here"
   ```

4. **Update your contact info** (optional but recommended):
   ```powershell
   $UserAgent = "PanelAppAusDB-Extractor/1.0 (GitHub:ChrisRem85/PanelAppAusDB; your.email@example.com)"
   ```

### Security Note

✅ **The config files (`config.ps1` and `config.sh`) are already in `.gitignore`**

This means:
- Your API token will NOT be committed to Git
- Your token stays private and secure
- You can safely work with version control

⚠️ **Never commit files containing your API token to public repositories!**

## Configuration Options

### API Token
- **Required** for accessing the PanelApp Australia API
- Get your token from: https://panelapp-aus.org/

### User-Agent
- **Recommended** to identify your requests
- Include your contact email so PanelApp can reach you if needed

### Request Delay
- **Default:** 500ms (PowerShell) / 0.5s (Bash)
- Controls the delay between API requests
- Increase if you want to be more respectful of API limits
- Examples:
  - Conservative: 1000ms (1 second)
  - Very conservative: 2000ms (2 seconds)

## Files Structure

```
scripts/
├── config.ps1              # Your actual config (NOT in Git)
├── config.ps1.template     # Template for PowerShell (in Git)
├── config.sh               # Your actual config (NOT in Git)
├── config.sh.template      # Template for Bash (in Git)
├── extract_PanelList.ps1   # Loads config.ps1
├── extract_PanelList.sh    # Loads config.sh
├── extract_Genes.ps1       # Loads config.ps1
├── extract_Genes.sh        # Loads config.sh
└── ...
```

## Troubleshooting

### "Config file not found" warning
- The scripts will still run with default values (no token)
- To fix: Copy the template file as shown in Quick Setup

### API access denied
- Make sure your token is correct in the config file
- Verify the config file exists: `scripts/config.ps1` or `scripts/config.sh`
- Check that the file is being loaded (you should see a green success message)

### Updating your token
- Just edit the config file directly
- No need to modify the actual scripts
- Changes take effect immediately on next run
