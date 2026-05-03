# Add macOS Service to BMO Translator App

## Context
BMO is a macOS menu bar translator app (Danish ↔ English) built with Swift/SwiftUI using DeepL API. The app currently lives in the menu bar. We need to add a macOS Service that allows users to right-click selected text anywhere in macOS and translate it via the Services menu.

## Requirements
1. Create a macOS Service extension that appears in right-click context menus when text is selected
2. The service should capture the selected text and send it to BMO for translation
3. Display the translation result in a non-intrusive way (notification or small floating window)
4. Service should be bidirectional (auto-detect language or allow user preference)
5. Keep the existing menu bar functionality intact

## Tasks

### Task 1: Update Package.swift structure
- Modify `Package.swift` to support an app bundle structure that can include a Service extension
- Research if SPM supports Service extensions directly, or if we need to transition to an Xcode project
- Document any limitations and recommend the best approach

### Task 2: Create Service Extension
- Create a new Service extension target (may require Xcode project instead of SPM)
- Configure the extension's Info.plist to register as a text service
- Set appropriate service menu title: "Translate with BMO"
- Configure the service to accept NSStringPboardType or plain text

### Task 3: Implement Service Handler
- Create a service handler class that receives selected text
- Extract the selected text from the pasteboard
- Implement logic to send text to the main BMO app for translation
- Use XPC or distributed notifications for communication between service and main app

### Task 4: Refactor Translation Service
- Ensure `TranslationService.swift` can be shared between main app and service extension
- Make the translation service accessible from both contexts
- Consider creating a shared framework/library target if needed

### Task 5: Implement Translation Result Display
- Create a floating window or use NSUserNotification to show translation results
- Design should be minimal and non-intrusive
- Include both source and translated text
- Add a "Copy" button for the translated text
- Window should auto-dismiss after a timeout or when user clicks away

### Task 6: Handle Language Detection
- Auto-detect if input is Danish or English
- If detection is uncertain, default to a preferred direction (configurable)
- Reuse existing language detection logic from the main app

### Task 7: Update Build Scripts
- Update `build-app.sh` to include the Service extension in the app bundle
- Ensure the service is properly signed and bundled
- Test that the service appears in System Settings → Keyboard → Services after installation

### Task 8: Update Documentation
- Update README.md with instructions on how to enable/use the service
- Add screenshots showing the right-click menu with the service
- Document how to enable the service in System Settings if it doesn't appear automatically
- Add troubleshooting section for common service issues

### Task 9: Test the Service
- Test selecting text in Safari, Chrome, TextEdit, and other apps
- Verify the service appears in right-click menu
- Test translation in both directions
- Test error handling (no internet, invalid API key, etc.)
- Verify the service doesn't interfere with existing menu bar functionality

### Task 10: Handle Edge Cases
- Handle empty or very long text selections gracefully
- Add rate limiting if needed to avoid API abuse
- Handle service being called when app is not running (launch app if needed)
- Add error notifications for API failures

## Technical Notes
- macOS Services are registered via `NSServices` in Info.plist
- Service extensions must be part of an app bundle, not standalone executables
- Consider using `NSXPCConnection` for inter-process communication
- The service may need to be in a separate target with its own Info.plist
- Users may need to enable the service in System Settings → Keyboard → Services

## Deliverables
1. Working Service extension integrated into BMO app
2. Updated build scripts and documentation
3. Service appears in right-click context menus system-wide
4. Translation results displayed in a user-friendly way
5. All existing functionality remains intact
