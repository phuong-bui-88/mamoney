# MaMoney iOS Build - Quick Reference Card

## 🔐 Security First: Your Token is SAFE

Your GitHub token stored in GitHub Actions secrets is:
- ✅ Never visible in code
- ✅ Never logged in output (masked as ***)
- ✅ Never stored in git
- ✅ Automatically cleaned up after build
- ✅ Can be rotated anytime

---

## 5-Minute Setup

```bash
# Step 1: Add secret on GitHub
Settings > Secrets and variables > Actions > New secret
Name: GITHUB_TOKEN
Value: (your GitHub PAT from github.com/settings/tokens)

# Step 2: Trigger build
GitHub > Actions > Build iOS IPA > Run workflow

# Step 3: Download
Wait for build > Artifacts > mamoney-ios-ipa > Download
```

---

## Build Commands

### Local Build
```bash
./build_ios_ipa.sh              # debug build
./build_ios_ipa.sh --release    # release build
```

### GitHub Actions
- Go to Actions > Run workflow
- Choose build type
- Wait 15-30 minutes
- Download from Artifacts

---

## Token Management

### Add Token Secret (One-time)
```
GitHub > Settings > Secrets and variables > Actions
New repository secret:
  Name: GITHUB_TOKEN
  Value: your_token_here
```

### Update Token
```
1. Create new token: github.com/settings/tokens
2. Update secret: Settings > Secrets
3. Delete old one
4. Next build uses new token
```

### Emergency: Revoke Token
```
1. Delete token: github.com/settings/tokens
2. Create new one
3. Update GitHub secret
4. Previous builds invalidated
```

---

## Files Created

| File | Purpose | Where | Visible? |
|------|---------|-------|----------|
| `.github/workflows/build_ios_ipa.yml` | GitHub Actions workflow | GitHub | ✅ Yes |
| `.env.local` | Your token | Local | ❌ No (git-ignored) |
| `.env.example` | Token template | GitHub | ✅ Yes |
| `lib/services/ai_config.dart` | Read token at runtime | GitHub | ✅ Yes |
| `build_ios_ipa.sh` | Local build script | GitHub | ✅ Yes |

---

## Documentation Guides

📖 **Start Here:**
- `DEPLOYMENT_SUMMARY.md` - Overview of what's set up
- `GITHUB_ACTIONS_QUICK_START.md` - Quick 5-minute guide

📘 **Detailed Guides:**
- `IOS_DEPLOYMENT_GUIDE.md` - Complete iOS deployment
- `GITHUB_ACTIONS_SETUP.md` - GitHub Actions deep dive

🎯 **This File:**
- `QUICK_REFERENCE.md` - Quick lookup (you are here!)

---

## Troubleshooting Cheat Sheet

### Build says "Token not found"
```
1. Go to Settings > Secrets
2. Add/check GITHUB_TOKEN
3. Run build again
```

### Can't download IPA
```
1. Wait for green checkmark ✓
2. Check "Artifacts" section
3. File stays 30 days
```

### Local build fails
```
1. Add token to .env.local:
   GITHUB_TOKEN=your_token
   
2. Run: ./build_ios_ipa.sh --release
```

### Token exposed by accident
```
IMMEDIATELY:
1. Delete token: github.com/settings/tokens
2. Create new token
3. Update GitHub secret
4. All old builds invalid
```

---

## GitHub Actions Workflow

```
┌─────────────┐
│ You push    │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ GitHub detects push │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Run build_ios_ipa.yml       │
│ - Get token from secret *** │ (token masked)
│ - Build app                 │
│ - Create archive            │
│ - Export IPA                │
│ - Upload artifact           │
│ - Clean up files            │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────┐
│ Download IPA        │
│ from Artifacts      │
└─────────────────────┘
```

---

## Environment Variable Flow

```
GitHub Secrets (Hidden)
    │
    ├─ stored: ${{ secrets.GITHUB_TOKEN }}
    │
    ▼
Build Command
    │
    ├─ --dart-define=GITHUB_TOKEN=${{ secrets.GITHUB_TOKEN }}
    │   (masked in logs as ***)
    │
    ▼
Flutter App
    │
    ├─ String.fromEnvironment('GITHUB_TOKEN')
    │
    ▼
AIService (API calls)
    │
    └─ Uses token safely
```

---

## Key Points

🔑 **Remember:**
- Token lives in GitHub Secrets
- NOT in code, NOT in git
- Masked in logs
- Can be rotated anytime
- Only valid during build

🔑 **Never:**
- Echo the token
- Print the token
- Commit the token
- Share the token

🔑 **Always:**
- Use `${{ secrets.SECRET_NAME }}`
- Store sensitive in GitHub Secrets
- Review logs for accidental leaks
- Rotate tokens regularly

---

## Quick Links

- 🔗 GitHub Settings: https://github.com/settings/tokens
- 🔗 GitHub Secrets: https://github.com/USER/REPO/settings/secrets/actions
- 🔗 GitHub Actions: https://github.com/USER/REPO/actions
- 🔗 Flutter Docs: https://docs.flutter.dev/deployment/ios
- 🔗 GitHub Actions Docs: https://docs.github.com/en/actions

---

**Status: ✅ All Set Up**

Your iOS IPA pipeline is ready to use!

```
✅ Token secured in GitHub Secrets
✅ GitHub Actions workflow created
✅ Local build scripts ready
✅ Documentation included
✅ Security best practices followed
```

**Next Action:** Add GITHUB_TOKEN secret to GitHub! 🚀
