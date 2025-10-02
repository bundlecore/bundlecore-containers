# Setting up Personal Access Token for Package Access

If the workflow continues to fail with the default `GITHUB_TOKEN`, you can create a Personal Access Token (PAT) as an alternative.

## Steps to Create PAT

1. **Go to GitHub Settings**
   - Click your profile picture → Settings
   - Or go to: https://github.com/settings/tokens

2. **Create New Token**
   - Click "Developer settings" (left sidebar)
   - Click "Personal access tokens" → "Tokens (classic)"
   - Click "Generate new token" → "Generate new token (classic)"

3. **Configure Token**
   - **Note**: "Trivy Security Scan - Package Access"
   - **Expiration**: Choose appropriate duration (90 days recommended)
   - **Scopes**: Select these permissions:
     - ✅ `read:packages` - Read packages and their metadata
     - ✅ `repo` - Full control of private repositories (if packages are private)
     - ✅ `read:org` - Read org and team membership (if needed)

4. **Copy Token**
   - Click "Generate token"
   - **Important**: Copy the token immediately (you won't see it again)

## Add Token to Repository

1. **Go to Repository Settings**
   - Navigate to your repository
   - Click "Settings" tab
   - Click "Secrets and variables" → "Actions"

2. **Add New Secret**
   - Click "New repository secret"
   - **Name**: `PACKAGES_TOKEN`
   - **Secret**: Paste your PAT token
   - Click "Add secret"

## How It Works

The workflow will automatically detect if `PACKAGES_TOKEN` exists and use it instead of the default `GITHUB_TOKEN`:

```yaml
# The workflow checks for PACKAGES_TOKEN first
if [ -n "${{ secrets.PACKAGES_TOKEN }}" ]; then
  echo "🔑 Using PACKAGES_TOKEN (Personal Access Token)"
  AUTH_TOKEN="${{ secrets.PACKAGES_TOKEN }}"
else
  echo "🔑 Using GITHUB_TOKEN (default)"
  AUTH_TOKEN="${{ secrets.GITHUB_TOKEN }}"
fi
```

## Verification

After adding the token, run the workflow again. You should see:
- `🔑 Using PACKAGES_TOKEN (Personal Access Token)`
- `✓ Basic API access successful`
- Package discovery should work

## Security Notes

- PATs have broader permissions than `GITHUB_TOKEN`
- Set appropriate expiration dates
- Rotate tokens regularly
- Only grant minimum required permissions
- Consider using fine-grained PATs for better security (beta feature)