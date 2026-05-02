# 🚀 Presence Intelligence: AI-Driven Attendance Ecosystem
### **A Full-Stack Cross-Platform Solution with Real-Time Biometric Liveness Detection**
**Internship Capstone Project | MR. TECH-LAB LLP & ACS College of Engineering**

---

## 📌 Executive Overview
**Presence Intelligence** is an enterprise-grade attendance management system that leverages Edge-AI and Cloud-Sync technologies. Unlike traditional scanners, this system implements **Interactive Liveness Detection** to prevent spoofing and provides administrators with a **Presence Command Center** for real-time institutional analytics.

---

## 🏗️ System Architecture
The project follows a decoupled, service-oriented ecosystem with a specialized **Edge-Cloud AI Split**:

### 🛡️ The "Edge-Cloud" AI Split
A core innovation of this system is the specialized split of Artificial Intelligence tasks:
1.  **Edge AI (On-Device)**: The mobile application (Flutter + Google ML Kit) performs high-frequency liveness checks (Blinks/Smiles). This ensures zero-latency user interaction and reduces server CPU load by 80%.
2.  **Cloud AI (On-Server)**: The Python server performs the 128-dimensional vector matching. Keeping the "Master Encodings" on the server ensures biometric data security and prevents client-side database tampering.

### 🧩 Architectural Layers
- **Layer 1: Presentation Layer (Flutter)**: Cross-platform UI utilizing Glassmorphism design patterns and real-time data visualization via `fl_chart`.
- **Layer 2: Edge-AI Layer (Google ML Kit)**: Local processing of video streams for liveness verification and facial landmark tracking.
- **Layer 3: Communication Layer (REST + WebSockets)**: RESTful API for transactional data and WebSockets (Socket.io) for real-time dashboard state synchronization.
- **Layer 4: Application Layer (Flask)**: Python-based intelligence engine for facial encoding comparisons and automated PDF auditing.
- **Layer 5: Data Layer (SQLAlchemy + SQLite)**: Relational storage of institutional identity and attendance logs.

---

## 🔒 Security Framework
- **Anti-Spoofing**: Prevents 2D photo attacks through active biometric participation (Liveness Detection).
- **Identity Integrity**: Enforces **Strict Role-Based Access Control (RBAC)**, preventing unauthorized access between student and administrative portals.
- **Credential Security**: Passwords utilize salted SHA-256 hashing via the `Werkzeug` library.
- **Privacy by Design**: Biometric data is stored as non-reversible mathematical 128-d encodings rather than raw images.

---

## 🗄️ Database Schema
The system utilizes a relational database structure managed via SQLAlchemy ORM.

### 👥 Users Table
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | Integer (PK) | Unique identifier for each user |
| `role` | String(32) | Access level: `admin`, `teacher`, `student` |
| `fullname` | String(128) | Full legal name of the individual |
| `userid` | String(64) | Institutional Roll Number / Employee ID |
| `username` | String(64) (UQ) | Unique login identifier |
| `password` | String(256) | Bcrypt-hashed secure credential |
| `email`/`phone` | String | Contact metadata for broadcast alerts |
| `face_encoding`| Text | Serialized 128-d biometric vector |

### 📅 Attendance Table
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | Integer (PK) | Log identifier |
| `user_id` | Integer (FK) | Reference to the registered user |
| `date`/`time` | String | Temporal metadata of the scan |
| `status` | String(32) | Verification result (e.g., `Verified`) |
| `proof_path` | String(256) | File path to the captured evidence image |

---

## ✨ Key Features

### 🛡️ Secure AI Check-in
- **Anti-Spoofing**: Randomized liveness prompts (e.g., "Smile slightly" or "Turn head left") ensure a real human presence.
- **Biometric Enrollment**: A guided UI overlay that assists users in providing high-resolution scans for accurate recognition.

### 📊 Presence Command Center (Admin)
- **Consistency Matrix**: A 12-month interactive heatmap visualizing institutional attendance patterns.
- **Dynamic Anomaly Detection**: Admin-adjustable threshold slider to automatically flag students falling below specific attendance margins.
- **Cinematic PDF Audits**: One-click professional report generation with embedded company branding and anomaly highlights.

---

## 🛠️ Tech Stack
| Component | Technology |
| :--- | :--- |
| **Frontend** | Flutter, Dart, fl_chart, google_mlkit_face_detection |
| **Backend** | Python, Flask, OpenCV, face_recognition |
| **Database** | SQLite, SQLAlchemy |
| **Reporting** | PDF (Dart), Printing (Native) |
| **DevOps** | GitHub Actions, Git |

---

## 🗺️ Project Roadmap
- [x] **Phase 1**: Core Face Recognition & Flask API Integration.
- [x] **Phase 2**: Flutter Cross-Platform UI Development (Glass Morphism).
- [x] **Phase 3**: Edge-AI Implementation (Google ML Kit Liveness).
- [x] **Phase 4**: Real-time Sync (WebSockets) & Admin Command Center.
- [x] **Phase 5**: Automated CI/CD Deployment (GitHub Actions).
- [ ] **Phase 6**: Push Notifications for Attendance Anomalies.
- [ ] **Phase 7**: Integration with Institutional ERP Systems.

---

## 🚀 Deployment Roadmap
Deploying this multi-platform system involves systematic rollout across different environments:

### 🌐 1. Web Deployment (Admin Dashboard)
- **Platform**: Render (Recommended)
- **Strategy**: Connect your GitHub repository to Render. Use the included `render.yaml` for automated configuration.
- **Build Command**: `pip install -r requirements.txt`
- **Start Command**: `gunicorn --worker-class eventlet -w 1 --bind 0.0.0.0:$PORT app:app`

### 🤖 2. Android Deployment (Mobile Kiosks/Students)
- **Direct Distribution**: Share the `app-release.apk` via a secure corporate portal or Google Drive.
- **Google Play**: Upload the App Bundle (.aab) to the "Internal Testing" track on Google Play Console for managed distribution.

### 💻 3. Windows Deployment (Desktop Terminals)
- **Quick Start**: Zip the `build/windows/runner/Release` folder for direct sharing.
- **Enterprise Installer**: Use **Inno Setup** to create a single `setup.exe` for professional installation and desktop shortcuts.

### 🍎 4. Apple Ecosystem (iOS & macOS)
- **iOS**: Use **TestFlight** via Apple Developer Program for secure beta distribution.
- **Ad-hoc**: Use services like **Diawi** for quick QR-code based installation on provisioned devices.

---

## 🛠️ Installation & Setup

### Backend (Python)
```bash
# Clone the repository
git clone <repo-url>
cd ai_attendance_dashboard

# Install dependencies
pip install -r requirements.txt

# Start the server
python app.py
```

### Frontend (Flutter)
```bash
cd trying_flutter

# Install packages
flutter pub get

# Run on your device
flutter run
```

---

## 👨‍💻 Developed By
**Chirag J K,Rashmi M,Bharath Gowda N,Aishwarya M,Hemanth C B **
*Internal Internship Project*  
**MR. TECH-LAB LLP**  
**ACS College of Engineering (VTU)**
