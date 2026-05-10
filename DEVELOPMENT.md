# ReveEtVoyage iOS — Development Guide

## Prerequisites

- **Xcode 15.0+** (download from App Store or developer.apple.com)
- **XcodeGen 2.35+** (install via Homebrew: `brew install xcodegen`)
- **Swift 5.9+** (included with Xcode)

## Getting Started

### 1. Clone and Install Dependencies

```bash
git clone https://github.com/anthonybellia/reveetvoyage-ios.git
cd ReveEtVoyage
```

### 2. Generate Xcode Project

XcodeGen generates the `.xcodeproj` from `project.yml`:

```bash
xcodegen generate
```

This creates `ReveEtVoyage.xcodeproj/` locally (not committed to Git).

### 3. Open in Xcode

```bash
open ReveEtVoyage.xcodeproj
```

### 4. Configure Development Team

In Xcode, select the ReveEtVoyage target and go to **Signing & Capabilities**:
- Set your Apple Development Team (if signing locally)
- OR use "Automatic" for Ad Hoc signing with free Apple ID

### 5. Build and Run

- Select **ReveEtVoyage** scheme (top of Xcode)
- Choose iPhone simulator or device
- Press **Cmd+R** (Run) or **Cmd+B** (Build)

## Architecture

- **Models:** `ReveEtVoyage/Models/` — Codable data structures (User, Voyage, Devis, Offre, Passenger)
- **Services:** `ReveEtVoyage/Services/` — API client, auth state, domain services (APIClient, AuthService, VoyageService, etc.)
- **Views:** `ReveEtVoyage/Views/` — SwiftUI screens (Auth, Home, Voyages, Settings)
- **ViewModels:** `ReveEtVoyage/ViewModels/` — Observable state (AuthViewModel, HomeViewModel, etc.)
- **Extensions:** `ReveEtVoyage/Extensions/` — Helpers (Color, Date formatting, View modifiers)
- **Config:** `ReveEtVoyage/Config/` — API endpoints and constants

## API Integration

The app connects to `https://reveetvoyage.be/api` using Laravel Sanctum bearer token auth:

1. **Login:** POST `/login` → returns `access_token` + `user_id`
2. **Secured requests:** Header `Authorization: Bearer {access_token}`
3. **Token storage:** Keychain (native iOS secure storage)

See `ReveEtVoyage/Services/APIClient.swift` for implementation.

## Testing

- **Unit Tests:** `ReveEtVoyageTests/` — Test models, services, helpers (test structure defined in project.yml)
- **UI Tests:** `ReveEtVoyageUITests/` — Test screens and flows (test structure defined in project.yml)

Test implementations will be added as the project evolves.

Run tests in Xcode: **Cmd+U** or Product → Test.

## Troubleshooting

### "xcodegen: command not found"
Install: `brew install xcodegen`

### "Missing development team"
Xcode → Settings → Accounts → Add your Apple ID, then select team in project settings.

### "Alamofire not found"
Run `xcodegen generate` again to update SPM dependencies.

### Network errors in simulator
Check backend API is running and accessible from your network.
