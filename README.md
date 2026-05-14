# 🌌 Nova AI Agent

Nova is a standalone, high-performance Android AI agent that can control your phone UI autonomously. Built with Flutter and powered by the **BigModel (AutoGLM-Phone)** vision-language model, Nova can "see" your screen and execute complex tasks directly via local ADB.

---

## ⚡ Key Features

- **🚀 Standalone Architecture**: No external Python bridge or PC needed. The app communicates directly with the model API and controls the device locally.
- **👁️ Vision-Powered**: Uses multimodal LLMs to understand screen screenshots and plan actions (taps, swipes, typing, etc.).
- **🔧 Local ADB Integration**: Integrated native ADB shell layer for 100% reliable device control without using Accessibility APIs.
- **🔐 Secure-by-Design**: Key credentials are kept in a gitignored `.env` file and persisted securely on-device.
- **🖥️ Terminal-Style UX**: Real-time logging of the agent's thought process and actions in a premium dark theme.

---

## 🧠 How It Works

Nova operates in a **Sense-Think-Act** loop:
1. **Sense**: Captures a high-resolution screenshot using the native ADB bridge.
2. **Think**: Sends the screenshot and past conversation history to **AutoGLM-Phone** to plan the next step.
3. **Act**: Parses the AI's response (e.g., `do(action="tap", coordinate=[0.5, 0.3])`) and executes it instantly via local ADB shell.

---

## 🛠️ Getting Started

### 1. Prerequisites
- **Flutter SDK**: Installed and configured on your machine.
- **Android Device**: With **Wireless Debugging** enabled (Developer Options).
- **BigModel API Key**: Obtain one from [BigModel](https://open.bigmodel.cn/).

### 2. Configuration
Create a `.env` file in the project root:
```env
BIGMODEL_API_KEY=your_api_key_here
```

### 3. Installation & Run
```bash
# Get dependencies
flutter pub get

# Run on your connected device
flutter run
```

### 4. Setup on Device
1. Open the **Nova** app.
2. Tap the **Setup** indicator (top right).
3. Follow the 2-step process to pair and connect to **Wireless Debugging**.
4. Return to the Home screen, enter a task (e.g., *"Open WhatsApp and send 'Hi' to Mom"*), and watch Nova go!

---

## 🏗️ Tech Stack

- **Frontend**: Flutter (Dart)
- **Native Logic**: Kotlin (ADB binary management & execution)
- **AI Brain**: [AutoGLM-Phone](https://open.bigmodel.cn/) via BigModel API
- **Control**: LADB (Local ADB Shell)

---

## ⚠️ Disclaimer
Nova is an experimental AI automation tool. Use it responsibly and ensure you understand the actions the agent is performing on your device.

---

**Developed with ❤️ for GCD4F**
