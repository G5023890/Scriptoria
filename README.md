# Scriptoria

`Scriptoria` is a native macOS notes app focused on fast knowledge capture, structured note management, code snippets, files, and task tracking inside one workspace.

Current app bundle: `MyNotes`  
Current release: `0.9.8`

## Overview

The app is built as a three-column macOS experience with:

- a sidebar for smart collections and labels
- a central list for notes or global tasks
- a detail area with read, edit, and split modes

`Scriptoria` is designed for mixed-content notes: plain text, markdown-like content, snippets, attachments, labels, favorites, pins, and tasks all live together in one note model.

## Main Functionality

### Notes

- Create notes instantly from the main window toolbar or `Cmd+N`
- Edit note title and body
- Switch between `Read`, `Edit`, and `Split` modes
- Render note content in reading mode
- Keep autosaved drafts in the editor flow
- Delete notes to Trash and restore them later
- Empty Trash from the sidebar or command menu
- Pin important notes
- Mark notes as favorites

### Labels

- Create labels directly while assigning labels to a note
- Assign and remove labels from notes
- Browse notes by label from the sidebar
- Edit label name from the sidebar
- Customize label icon with SF Symbols
- Customize label icon color using a fixed palette
- Display label styling consistently in sidebar rows, chips, pickers, and Quick Capture
- Keep legacy label icons visible even if they are outside the current picker whitelist

### Tasks

- Add tasks inside a note
- Edit task title, details, and due date
- Support due dates with or without time component
- Mark tasks complete and reopen them
- Reorder tasks inside a note
- Soft-delete tasks and restore or permanently remove them later
- Show tasks inline inside the note detail screen
- Show a global Tasks collection grouped as:
  - Overdue
  - Today
  - Upcoming
  - No Date
  - Completed

### Task Notifications

- Schedule local reminders for tasks with due dates
- Support notification actions:
  - Complete
  - Snooze 1 Hour
  - Tomorrow Morning
- Rebuild notification schedule on app bootstrap
- Reveal the related note and task when opening from a notification

### Attachments

- Import attachments into a note
- Support attachment categories:
  - image
  - pdf
  - code
  - video
  - audio
  - generic file
- Show inline thumbnails for local image attachments
- Preview attachments with Quick Look
- Open attachments in the system
- Remove attachments from a note
- Browse notes through the `Attachments` smart collection

### Code Snippets

- Detect and extract snippets from note content
- Create manual snippets
- Edit and remove manual snippets
- Preview snippets in a dedicated sheet
- Copy snippet code to clipboard
- Highlight syntax with `Highlightr`
- Switch preview syntax language manually
- Browse notes through the `Snippets` smart collection

### Search

- Search by free text across:
  - title
  - note content
  - labels
  - snippets
  - attachment names
- Use debounced search updates
- Filter with quick filters in the UI:
  - pinned
  - favorite
  - tasks
  - attachments
  - code
- Use query syntax in the search field, including:
  - `is:pinned`
  - `is:favorite`
  - `has:tasks`
  - `has:attachments`
  - `has:snippets`
  - `label:<name>`
  - `type:note`
  - `type:code`
  - `type:image`
  - `type:mixed`
  - `type:file`
  - `updated:today`
  - `updated:week`
  - `language:<name>`
  - `kind:note`
  - `kind:label`
  - `kind:snippet`
  - `kind:attachment`
  - `in:title`
  - `in:content`
  - `in:labels`
  - `in:code`
  - `in:attachments`
- Support quoted phrases in search queries

### Quick Capture

- Open a dedicated Quick Capture window
- Create a new note without leaving the current workflow
- Set title and body
- Assign labels during capture
- Mark the note as pinned or favorite immediately
- Save and jump straight into the created note

## Smart Collections

The sidebar currently includes:

- `All Notes`
- `Favorites`
- `Pinned`
- `Recent`
- `Tasks`
- `Attachments`
- `Snippets`
- `Trash`

Each collection shows a live count in the sidebar.

## Data And Sync

- Local storage is backed by SQLite
- Search uses a local indexed document model
- Labels, notes, attachments, snippets, and task changes are versioned
- A sync queue and CloudKit mapping layer are already present in the codebase
- Sync status is tracked in app state

### Current Sync Status

CloudKit transport is scaffolded but not yet enabled by default. The app currently boots with sync configuration disabled, so local-first behavior is the active mode in release `0.9.8`.

## User Experience Details

- Native macOS windowing with a main workspace window and a dedicated Quick Capture window
- Keyboard shortcut for new notes: `Cmd+N`
- Command menu action for emptying trash: `Shift+Cmd+Delete`
- Context menus in the sidebar for label editing and deletion
- Inline badges and chips for metadata visibility
- Focus-and-reveal flows from tasks and notifications back into their notes

## Technology Stack

- Swift
- SwiftUI
- Observation
- SQLite
- CloudKit scaffolding
- UserNotifications
- Quick Look
- `Highlightr` for syntax highlighting

## Project Structure

- `MyNotes/App` — app bootstrap, routing, scenes, coordinator
- `MyNotes/Features` — UI by product area
- `MyNotes/Domain` — use cases and policies
- `MyNotes/Data` — repositories, local storage, database, sync queue, sync mapping
- `MyNotes/Core` — models, types, services, utilities
- `MyNotes/UI` — design system primitives and shared UI pieces
- `scripts/build_and_install_app.sh` — production build, signing, packaging, and install flow

## Build And Install

Requirements:

- macOS 26 beta or newer
- Xcode toolchain with Swift Package Manager support
- Optional Apple Development signing identity for stable signed installs

Debug build:

```bash
swift build
```

Build, sign, package, and install into `/Applications/MyNotes.app`:

```bash
./scripts/build_and_install_app.sh
```

The install script:

- builds a release binary
- creates a full `.app` bundle
- injects `Info.plist`
- preserves bundle identifier `com.grigorym.MyNotes`
- applies the app icon from `assets/AppIcon.icns`
- signs with an Apple Development identity when available
- installs the app into `/Applications/MyNotes.app`

## Release 0.9.8 Highlights

- Full label appearance editing from the sidebar
- SF Symbols support for label icons
- Fixed color palette for label icon styling
- Consistent label rendering in sidebar, chips, label picker, and Quick Capture
- Release build/version flow updated to `0.9.8`

## Repository

GitHub: [G5023890/Scriptoria](https://github.com/G5023890/Scriptoria)
