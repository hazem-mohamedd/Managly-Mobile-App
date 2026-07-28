# 👔 Managely - Enterprise Workflow & HR Management App

Managely is a modern, comprehensive, and feature-rich Flutter application designed to streamline workplace operations, automate HR management, and enhance team productivity. It offers tools for attendance tracking, task management, leave requests, payslip generation, performance monitoring, and more.

---

## 🌟 Key Features

### 1. 🔑 Authentication & Security
- **Secure Login**: Secure access utilizing persistent token storage (`shared_preferences`) with `Provider`-based state management.
- **Session Persistence**: Automated login feature ("Remember Me") to keep sessions active across launches.

### 2. 📅 Attendance Tracking (QR & Geolocation)
- **Smart Check-in/out**: Features barcode/QR code scanning using `mobile_scanner`.
- **GPS Verification**: Incorporates geographic location checks via `geolocator` to ensure employees check in from authorized work sites.

### 3. 📝 Leave & Permission Management
- **Leave Requests**: Employees can submit requests for vacation, sick leaves, or personal time off.
- **HR Approval Portal**: Dedicated workspace for HR administrators to review, approve, or reject pending leave requests with real-time balance calculations.

### 4. 📊 HR & Performance Dashboard
- **Admin Insights**: High-level visual statistics regarding attendance rates, active leaves, pending tasks, and payroll metrics.
- **Performance Monitoring**: KPI tracking, completion rates, and performance reports to measure team efficiency.

### 5. 🛠️ Task & Assignment Management
- **Task Board**: Interactive task lists showing pending, ongoing, and completed assignments.
- **Task Assignment**: Managers can assign new tasks directly to specific employees, attach deadlines, and monitor progression.

### 6. 💵 Salary & Payslip Generation
- **Salary Summaries**: Detailed breakdown of basic salary, allowances, and deductions.
- **PDF Generation**: Generates and prints digital payslips locally utilizing `pdf` and `printing` packages.

### 7. 📁 Document & File Operations
- **File Picker & Saver**: Integration of `file_picker` and `file_saver` for downloading and storing reports and documents locally.
- **PDF Viewer**: Embedded PDF viewer using `syncfusion_flutter_pdfviewer` to preview official documents directly inside the application.

---

## 🏗️ Project Directory Structure

```text
lib/
├── Auth/
│   └── auth_provider.dart        # Authentication & State Management
├── Modle/
│   └── deduction_modle.dart      # Salary/Deduction Data Models
├── View/
│   ├── assign_task_screen.dart   # Task Assignment Screen for managers
│   ├── attendance_screen.dart    # QR/GPS Check-in & Attendance log
│   ├── file_viewer_screen.dart   # Screen to read/preview PDFs
│   ├── home_screen.dart          # Primary User dashboard
│   ├── home_tab.dart             # Main bottom navigation tab shell
│   ├── hr_dashboard_screen.dart  # Dedicated dashboard for HR management
│   ├── leave_approval_screen.dart# Leave approvals panel (HR view)
│   ├── leave_screen.dart         # Employee Leave Request & History
│   ├── login_screen.dart         # Security credentials screen
│   ├── notifications_screen.dart # Notification logs
│   ├── payslip_screen.dart       # Interactive payslip & salary details
│   ├── performance_monitoring_screen.dart # KPI / Employee metrics
│   ├── profile_screen.dart       # User Profile settings & info
│   ├── reports_screen.dart       # Reports generation
│   ├── task_management_screen.dart # Employee task tracking
│   ├── tasks_screen.dart         # Simple tasks overview
│   └── team_directory_screen.dart# Employee list & contact details
├── Widget/
│   ├── attendance_card_widget.dart
│   ├── deduction_card.dart
│   ├── leave_balance_widget.dart
│   ├── leave_history_card.dart
│   ├── loading_widget.dart
│   ├── payslip_card_widget.dart
│   ├── profile_item_widget.dart
│   ├── quick_actions_widget.dart
│   ├── salary_card.dart
│   ├── summary_attendance_widget.dart
│   └── tasks_card_widget.dart
└── main.dart                     # Application entry point & Splash Screen
```

---

## 🛠️ Technology Stack & Dependencies

The application leverages modern Dart packages and plugins to guarantee high performance and stability:

- **State Management**: `provider` (ChangeNotifier pattern)
- **Local Storage**: `shared_preferences`
- **Location & Scanning**: `geolocator`, `mobile_scanner`
- **PDF & Printing**: `pdf`, `printing`, `syncfusion_flutter_pdfviewer`
- **Utility / Helpers**: `intl`, `http`, `url_launcher`, `flutter_inappwebview`
- **UI Elements**: `lottie` animations, Google Material Icons, and Cupertino Icons

---

## 🚀 Getting Started

### Prerequisites
Make sure you have Flutter SDK installed on your machine.
- Flutter version: `^3.9.2` (Dart SDK compatible)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/managely.git
   cd managely
   ```

2. **Install the dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Assets & App Launcher Icons:**
   To generate app icons for Android and iOS using the asset `assets/app_icon/icon.jpeg`:
   ```bash
   flutter pub run flutter_launcher_icons
   ```

4. **Run the Application:**
   To launch the app on your connected device/emulator:
   ```bash
   flutter run
   ```
