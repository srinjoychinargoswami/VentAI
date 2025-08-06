# 🧠 VentAI - Offline Emotional Support Companion

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Gemma](https://img.shields.io/badge/Gemma_3n-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev/gemma)

**VentAI is a privacy-first emotional support companion powered by Google's Gemma 3n models. It provides compassionate, real-time support — completely offline.**

---

## 🌟 Key Features

### 🔄 Auto-Install System
- 🖥️ **Zero setup** — Downloads and installs Ollama automatically on first run
- 🔐 **Uses signed installers** — No permission issues or manual config
- 🧠 **Smart detection** — Reuses existing installations if found
- 💻 **Universal compatibility** — Works on Windows 10/11 systems

### 🔒 Privacy-First Design
- ✅ **Offline-only** — No internet required after setup
- 🔐 **Local AI processing** — Conversations never leave your device
- 🛡️ **No data transmission** — No cloud sync, no tracking
- 🧘 **Safe for emotional support** — Designed with privacy as a core feature

### 🧠 Advanced AI Support
- 🤖 **Powered by Gemma 3n** — Multimodal, state-of-the-art emotional AI
- 💬 **Empathetic responses** — Based on therapeutic best practices
- 🚨 **Crisis-aware** — Detects signs of distress, offers immediate resources
- 🧩 **Context understanding** — Responds appropriately to emotion and tone

### 💾 Smart Model Caching
- 📦 **One-time model download**
- ⚡ **Fast launch after setup**
- 🌍 **Fully functional offline — even in airplane mode**

---

## 🎯 Problem Solved

Over **1.3 billion people** lack access to basic mental health support due to:
- 🌐 Poor internet connectivity
- 🌍 Geographic isolation
- 💸 High therapy costs
- 🔓 Privacy concerns with cloud-based AI

**VentAI bridges this gap** by offering a secure, on-device AI assistant for emotional well-being — anywhere, anytime.

---

## 🛠️ Technical Innovation

### 🧠 Auto-Download Architecture
```dart
static Future<bool> initialize() async {
  if (await _isOllamaInstalled()) {
    _ollamaPath = await _findOllamaExecutablePath();
  } else {
    final installSuccess = await _autoInstallOllama();
    if (!installSuccess) return false;
  }
  return await startPersistentService();
}
