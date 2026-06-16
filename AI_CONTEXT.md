# ArtoKu App - AI Context & Project Documentation

This file serves as the primary technical context for any AI agent working on the ArtoKu App. It details the tech stack, database schema, architecture, core features, and strict coding conventions. **Read and follow these guidelines thoroughly before modifying the codebase.**

## 1. Tech Stack & Environment

- **Framework:** Flutter (Dart SDK `^3.9.2`)
- **Backend & Database:** Firebase
  - *Auth:* `firebase_auth`, `google_sign_in`
  - *Database:* `cloud_firestore` (NoSQL)
  - *Storage:* `firebase_storage`
  - *Config:* `firebase_remote_config`
- **UI & Theming:** Material 3, `google_fonts`
- **Hardware / Device APIs:**
  - Security: `local_auth` (Biometrics / App Lock)
  - Camera/Storage: `image_picker`
  - Voice: `speech_to_text`
  - Notifications: `flutter_local_notifications`, `timezone`
- **Utilities:**
  - Storage/State: `shared_preferences`
  - Security: `flutter_dotenv` (.env loading for API Keys)
  - Logging: `logger` (Structured console logging)
  - Export/Data: `csv`, `pdf`, `printing`
- **AI Integration:** `google_generative_ai` (Gemini API for scanning receipts/invoices and analysis)

## 2. Database & Data Modeling

The app uses Cloud Firestore. All user data is tightly scoped under the root `users` collection to ensure privacy and security.

**Root Schema:** `users/{userId}/`

Under each user document, the following subcollections exist:
- **`wallets`**: Represents financial accounts (e.g., Cash, Bank, E-Wallet).
  - *Model:* `WalletModel`
  - *Fields:* `name`, `balance`, `colorValue`, `isLocked`.
- **`transactions`**: Records of user incomes and expenses.
  - *Fields:* `amount`, `type` ('income' or 'expense'), `date`, `category`, `note`, `walletId`.
  - Adding a transaction mathematically mutates the related `walletId` balance.
- **`goals`**: Savings goals or virtual buckets.
  - *Model:* `GoalModel`
  - *Fields:* `title`, `walletId`, `targetAmount`, `currentAmount`, `deadline`, `status` (active/completed/cancelled).
  - *Subcollection:* `allocations` (tracks `deposit` and `withdraw` activities. Impacts `currentAmount` and real Wallet balances).
- **`patungans`**: Split bill records.
  - *Model:* `PatunganModel`
  - *Mechanism:* Automatically creates `debts` (receivables/payables) and `transactions` based on the bill split logic.
- **`debts`**: Individual debt records linked to manual entry or a Patungan session.
- **`transfers`**: Records mapping the movement of funds from one wallet to another.

## 3. Project Architecture

The app employs a **Feature-First Architecture** (Modular / Layered by Feature).

- **`lib/features/`**: Contains independent modules for each feature (e.g., `auth`, `dashboard`, `transaction`, `wallet`, `goal`, `patungan`, `report`, `analysis`, `app_lock`, `profile`).
  - **`data/`**: Holds Models (e.g., `goal_model.dart`), Services for Firebase operations, and Logic Helpers.
  - **`presentation/`**: Holds Flutter Widgets, Screens, and Bottom Sheets (e.g., `create_goal_sheet.dart`).
- **`lib/core/`**: Shared globally across the app.
  - **`services/`**: Generic app services (`logger_service.dart`, `ui_helper.dart`, `notification_service.dart`, `gemini_service.dart`, `remote_config_service.dart`).
  - **`constants/`**, **`theme/`**, **`utils/`**, **`widgets/`**: Reusable generic UI components and constants.

**State Management Strategy:**
The app deliberately avoids heavy third-party state management libraries like BLoC, Riverpod, or GetX. It relies natively on:
- `StatefulWidget` & `setState` for local UI state.
- `ValueNotifier` / `ValueListenableBuilder` (e.g., Theme switching).
- `StreamBuilder` for real-time reactivity directly from Firestore snapshot streams.

## 4. Core Features Flow

- **Dashboard:** Central hub utilizing `StreamBuilder` to render real-time balances and recent transactions directly from Firestore.
- **Transactions & Wallets Management:** All financial activities require a target wallet. Incomes increase wallet balance; expenses decrease it.
- **AI Receipt Scanner:** A prominent feature via `ai_transaction_helper.dart`. It picks images from the camera/gallery, sends them to Gemini via `google_generative_ai`, and extracts structured data (Amount, Title/Note) to pre-fill the "Add Transaction" sheet.
- **Goals (Savings Goals):** Users allocate money to goals. The allocation logically separates funds within the selected wallet.
- **Patungan (Split Bill):** Facilitates group payments, calculates individual shares, records the total expense, and automatically registers receivables (`debts`).
- **App Lock:** Utilizes `local_auth` to enforce biometric or PIN login when the app is opened or resumed from the background after a certain timeout.

## 5. Coding Conventions & Rules

⚠️ **CRITICAL RULES FOR AI AGENTS:** DO NOT deviate from these standards.

1. **Architecture & File Placement:**
   - Always place new files in the correct feature module (`lib/features/<feature>/data/` or `lib/features/<feature>/presentation/`).
   - Do not mix business logic into generic UI component files; use `data/` services for Firestore manipulations.
2. **State Management Constraint:**
   - **DO NOT** introduce BLoC, Riverpod, GetX, or Provider unless explicitly instructed. Use standard Flutter tools (`setState`, `ValueNotifier`, `StreamBuilder`).
3. **UI & Theming (Dark/Light Mode):**
   - The app dynamically switches between Light and Dark mode.
   - **Never hardcode raw colors** for backgrounds or primary text (e.g., `Colors.white` or `Colors.black`).
   - Use `Theme.of(context)` to resolve colors (e.g., `Theme.of(context).scaffoldBackgroundColor` and `Theme.of(context).textTheme.bodyLarge?.color`).
4. **Dialogs & Overlays:**
   - Use `UIHelper` (`lib/core/services/ui_helper.dart`) exclusively for standard alerts.
   - Success: `UIHelper.showSuccess(context, title, message)`
   - Error: `UIHelper.showError(context, message)`
   - Loading: `UIHelper.showLoading(context)`
   - Currency Formatting: `UIHelper.formatRupiah(amount)`
5. **Logging:**
   - **DO NOT** use `print()`.
   - Use `LoggerService` (`lib/core/services/logger_service.dart`).
   - `LoggerService.info('...')`, `LoggerService.warning('...')`, `LoggerService.error('...', error, stackTrace)`.
6. **Error Handling:**
   - Wrap asynchronous operations in `try-catch` blocks.
   - On error, log technically using `LoggerService.error` and provide user feedback via `UIHelper.showError`.
7. **Models:**
   - Use immutable data classes (`final` fields, `const` constructors).
   - Implement `copyWith`, `fromSnapshot` (for Firestore DocumentSnapshot parsing), and `toMap`.
   - Use Dart Enums with string mapping extensions instead of raw strings for typed fields (e.g., `GoalStatus`, `AllocationType`).