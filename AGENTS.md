# AGENTS.md

## Project

- DJI LUT Studio is a macOS application written in Swift and SwiftUI.
- The Xcode project is `DJILutStudio.xcodeproj`.
- The main application target and scheme are `DJILutStudio`.
- Deployment target: macOS 15.6 or newer.

## Project structure

- `DJILutStudio/Models/`: application data models.
- `DJILutStudio/App/`: SwiftUI application entry and main view.
- `DJILutStudio/UI/DesignComponents.swift`: shared `DS.*` design system, shared SwiftUI components and additional views.
- `DJILutStudioTests/`: unit tests.
- `DJILutStudio/Resources/`: Media resources, LUT library, LUT manifest JSON

## Git Repository, Commit & Working Tree Guidelines

- Before making changes, verify that work/feature or work/bugfix is the active branch. 
- If no work/* branch exists, create and switch to the appropriate branch automatically.
- When commits are requested, commit each logical step separately using sequential identifiers (C001, C002, ...).
- Use concise, change-specific commit subjects; avoid vague or generic wording.
- Preserve unrelated user changes; never discard, stage, or commit them.
- Do not create or amend commits unless explicitly requested.
- No pull-request template is present.

## UI conventions

- Reuse the existing `DS.*` colors, cards, fields, and buttons.
- Every sheet and dialog must use the shared `DS.*` design components and follow the existing `DS.Card` UI pattern.
- New wizards should follow the existing `DS.Card` style.
- Use `String(localized:)` for user-visible text.
- Prefer SF Symbols over new bitmap icons.
- Keep macOS light and dark appearances working.

## Swift conventions

- Preserve the existing MainActor isolation model.
- Use `internal import` where the surrounding source files use it.
- Do not modify generated Core Data source files.
- Avoid force unwraps and destructive persistence operations.
- Preserve backward compatibility when decoding exported configuration files.

## Validation

After Swift changes, build with:

    xcodebuild -project DJILutStudio.xcodeproj \
      -scheme DJILutStudio \
      -configuration Debug \
      -derivedDataPath Build/DerivedData \
      build

Run targeted tests for changed behavior:

    xcodebuild -project DJILutStudio.xcodeproj \
      -scheme DJILutStudio \
      -configuration Debug \
      -derivedDataPath Build/DerivedData \
      test -only-testing:DJILutStudioTests/<TestClass>

## Working tree

- Preserve unrelated user changes.
- Do not revert or overwrite modified files outside the task.
- Do not create commits unless explicitly requested.
