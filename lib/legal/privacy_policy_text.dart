/// Approved privacy policy text. Single source for every screen that shows
/// the policy. Line format used by the renderers: ALL-CAPS lines are section
/// headings, lines starting with "* " are bullets, everything else is body text.
const String kPrivacyPolicyText = r'''VENT AI PRIVACY POLICY
Last Updated: November 2026

OVERVIEW
Vent AI is a privacy-first emotional support companion app. We are committed to protecting your privacy. This policy explains how we handle your data.

DATA WE DO NOT COLLECT
Vent AI does not collect, store, or transmit your personal information, including:
* Your name, email, phone number, or location
* Your conversations or emotional support chats
* Your device information or identifiers
* Analytics or usage statistics
* Behavioral data or activity logs
* Health or biometric data. Vent AI does not access health records, wearable or device health data, or biometric sensors. Anything you choose to write in a conversation is treated as conversation content and stays on your device.

The one exception is the information Hugging Face collects during the one-time model download, described under Third-Party Services below.

ALL DATA STAYS ON YOUR DEVICE
* Every conversation you have with Vent AI is stored only on your device.
* No conversation data is sent to Vent AI servers or cloud storage. Vent AI does not operate any servers.
* No conversation data is shared with third parties.
* Conversations and the AI model are not included in cloud backups, including iCloud Backup on Apple devices and Android’s automatic backup.

HOW THE APP WORKS
Vent AI uses an offline AI model (Gemma 4 E2B) that runs entirely on your device:
* The AI model is downloaded once from Hugging Face (about 2.6 GB) on first launch, after you confirm the download. During that download, Hugging Face collects information described under Third-Party Services below.
* After the download, the app works completely offline.
* No internet connection is required after the initial setup.
* Your conversations never leave your device, and no conversation history stored on the device is accessed by anyone but you.

PERMISSIONS WE REQUEST
Vent AI requests only what it needs:
* Network access, used only to download the AI model once on first launch.
* Local storage on your device, used to keep the AI model and your conversations.
* Vent AI does not request access to your contacts, location, or health data.

THIRD-PARTY SERVICES
* Hugging Face hosts the AI model file. During the download, Hugging Face collects your device’s IP address, the date and time of the request, and device and software details, as described in its privacy policy at huggingface.co/privacy. It may share that information with its service providers. No conversation data is sent.
* No analytics, crash reporting, or tracking services are used.
* No advertisements or ad networks.

YOUR RIGHTS
* Your conversations stay on your device, and you decide when to delete them.
* You can delete individual conversations, or all conversations at once with Clear All.
* Uninstalling the app removes the app from this device.
* You are not required to provide any personal information to use Vent AI.

CHANGES TO THIS POLICY
We may update this policy from time to time. The “Last Updated” date at the top shows the most recent version.

CONTACT US
If you have privacy questions or concerns, please contact: resolveera@gmail.com

COMMITMENT
Vent AI is designed with privacy as the foundation. We believe emotional support should be private, secure, and personal. Your data belongs to you, not to us.''';
