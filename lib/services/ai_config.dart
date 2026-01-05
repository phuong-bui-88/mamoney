/// AI Configuration for GitHub Models (Azure OpenAI GPT-4.1)
///
/// Uses GitHub's AI Model Marketplace to access Azure OpenAI models
class AIConfig {
  // GitHub Personal Access Token (PAT)
  // Get yours from: https://github.com/settings/tokens
  // Make sure to enable 'read:model-garden' scope
  static const String githubToken =
      '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';

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
