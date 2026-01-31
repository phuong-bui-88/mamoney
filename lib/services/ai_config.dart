/// AI Configuration for GitHub Models (Azure OpenAI GPT-4.1)
///
/// Uses GitHub's AI Model Marketplace to access Azure OpenAI models
class AIConfig {
  // GitHub Personal Access Token (PAT)
  // Set via --dart-define=GITHUB_TOKEN=<your_token> at build time
  // Note: String.fromEnvironment reads values at compile time, not runtime
  // Get your token from: https://github.com/settings/tokens
  // Ensure 'read:model-garden' scope is enabled

  static const String githubToken = String.fromEnvironment(
    'GITHUB_TOKEN',
    defaultValue: '',
  );

  // GitHub Models endpoint
  static const String endpoint = 'https://models.github.ai/inference';

  // Model name from GitHub Marketplace
  static const String model = 'openai/gpt-4.1';

  // Alternative models available:
  // 'openai/gpt-4'
  // 'openai/gpt-3.5-turbo'
  // 'meta/llama-2-7b'
  // 'meta/llama-2-70b'

  /// Get full API endpoint for chat completions
  static String getApiUrl() {
    return '$endpoint/chat/completions';
  }
}
