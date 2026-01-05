# AI Transaction Message Feature Setup

## Overview
This feature uses **GitHub Models** (powered by Azure OpenAI **GPT-4.1**) to parse natural language transaction messages and automatically extract the description and amount for creating transactions.

## Features
- **Natural Language Input**: Type transaction messages like "Bought lunch for 50 dollars"
- **AI Parsing**: Uses GitHub Models API to intelligently extract transaction details
- **Auto-fill**: Automatically populates description and amount fields
- **Error Handling**: Graceful fallback with user-friendly messages
- **Free to Use**: GitHub Models provides free access to GPT-4.1 with reasonable rate limits

## Setup Instructions

### 1. Get GitHub Personal Access Token (PAT)

1. Go to [GitHub Settings → Personal access tokens](https://github.com/settings/tokens)
2. Click **"Generate new token (classic)"**
3. Set token name: `MaMoney AI` (or similar)
4. Select scopes:
   - ✅ `read:model-garden` (required for model access)
   - Leave other scopes unchecked for security
5. Click **"Generate token"**
6. **Copy and save the token** (you won't see it again!)

### 2. Configure the Application

Edit [lib/services/ai_config.dart](lib/services/ai_config.dart) and replace:

```dart
static const String githubToken = 'github_pat_YOUR_TOKEN_HERE';
```

**Example:**
```dart
static const String githubToken = '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';
```

### 3. Install Dependencies

```bash
flutter pub get
```

## Usage

1. **Navigate to "Add Transaction" screen**
2. **Enter a natural language message** in the "AI Message" field
   - Examples:
     - "Bought groceries for $75"
     - "Lunch expenses 25 dollars"
     - "Freelance income 500"
     - "Gas 45.50"

3. **Click "Parse" button** - The AI will process your message
4. **Description and Amount** will auto-fill
5. **Adjust other details** as needed (type, category, date)
6. **Click "Add Transaction"** to save

## How It Works

- The app sends your message to GitHub Models API endpoint: `https://models.github.ai/inference`
- Uses the **GPT-4.1** model via Bearer token authentication
- AI receives system prompt instructing it to extract description and amount
- It returns structured data in the format: `DESCRIPTION: [description] | AMOUNT: [amount]`
- The app parses this response and populates the fields
- If the standard format is not recognized, the app attempts alternative parsing

## Available Models

GitHub Models supports several models. Update `AIConfig.model` to switch:

```dart
// Current (recommended)
static const String model = 'openai/gpt-4.1';

// Alternative options:
// static const String model = 'openai/gpt-4';
// static const String model = 'openai/gpt-3.5-turbo';
// static const String model = 'meta/llama-2-7b';
// static const String model = 'meta/llama-2-70b';
```

See [GitHub Marketplace Models](https://github.com/marketplace/models) for full list.

## Example Transactions

| Message | Description | Amount |
|---------|-------------|--------|
| "Bought lunch for 50 dollars" | Bought lunch | 50 |
| "Freelance work earned 500" | Freelance work | 500 |
| "Gas expenses $35.75" | Gas expenses | 35.75 |
| "Movie tickets $20" | Movie tickets | 20 |
| "Monthly salary 3000" | Monthly salary | 3000 |

## API Endpoint Details

**Endpoint**: `https://models.github.ai/inference`

**HTTP Method**: `POST`

**Headers**:
```
Content-Type: application/json
Authorization: Bearer <GITHUB_TOKEN>
```

**Request Body**:
```json
{
  "messages": [
    {
      "role": "system",
      "content": "You are a financial assistant..."
    },
    {
      "role": "user",
      "content": "User message here"
    }
  ],
  "temperature": 0.7,
  "max_tokens": 100,
  "model": "openai/gpt-4.1"
}
```

## Troubleshooting

### "API Error 401" or "Unauthorized"
- Check your GitHub PAT is correct
- Verify you selected `read:model-garden` scope
- Ensure token hasn't expired

### "API Error 429" (Rate Limited)
- GitHub Models has rate limits per account
- Wait a few seconds before trying again
- Consider implementing request throttling

### "Network error" Message
- Check internet connection
- Verify GitHub Models API is accessible
- Check firewall/VPN settings

### Fields Not Populating
- Check the AI response format matches expected pattern
- Try rephrasing your message more clearly
- Check GitHub Models status at [status.github.com](https://status.github.com)

## Cost & Rate Limits

**GitHub Models Pricing**: **FREE TIER** with reasonable limits
- Uses GitHub's infrastructure
- No credit card required
- Rate limited per account (adjust refresh limits as needed)
- Monitor usage at [github.com/models](https://github.com/models)

## Security Notes

⚠️ **Important**: Never commit your GitHub PAT to version control!

### Best Practices:
- Use environment variables or secure configuration management
- Rotate tokens periodically
- Use minimal required scopes (`read:model-garden` only)
- Consider using GitHub Actions secrets for CI/CD

### For Production:
- Use environment variables instead of hardcoding
- Implement rate limiting to prevent excessive API calls
- Add authentication to ensure only authorized users can parse messages
- Consider proxying through your backend server for additional control

### Example with Environment Variable:
```dart
static const String githubToken = String.fromEnvironment('GITHUB_TOKEN');
```

## Reference Links

- [GitHub Models Documentation](https://docs.github.com/en/models)
- [GitHub Personal Access Tokens](https://github.com/settings/tokens)
- [GitHub Marketplace Models](https://github.com/marketplace/models)
- [Playground & API Code Examples](https://github.com/marketplace/models/azure-openai/gpt-4-1/playground/code)
- [Flutter HTTP Package](https://pub.dev/packages/http)

## Support

For issues with:
- **GitHub Models**: Check [GitHub Docs](https://docs.github.com/en/models)
- **Flutter/HTTP**: Review [pub.dev http package](https://pub.dev/packages/http)
- **App-specific**: Review [lib/services/ai_service.dart](lib/services/ai_service.dart)

