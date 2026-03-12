# Scriptoria

`Scriptoria` is a native macOS knowledge workspace for notes, labels, tasks, code snippets, attachments, and fast capture.

It is built for people who collect ideas all day long and do not want to split their work between a notes app, a snippets manager, a task list, and a scratchpad.

Current app bundle: `MyNotes`  
Current release: `0.9.8`

GitHub: [G5023890/Scriptoria](https://github.com/G5023890/Scriptoria)

## Why Scriptoria

Most note apps are good at one thing and awkward at the rest. `Scriptoria` is designed to keep the whole flow in one native macOS workspace:

- capture ideas quickly
- turn notes into actionable tasks
- keep files and code snippets next to the note they belong to
- organize everything with visual labels
- find anything later with structured search

The result is a workspace that feels closer to a personal knowledge cockpit than a plain text editor.

## What You Can Do

### Write and organize notes

- Create notes instantly from the main window or with `Cmd+N`
- Edit note title and body
- Switch between `Read`, `Edit`, and `Split` modes
- Pin important notes
- Mark notes as favorites
- Move notes to Trash, restore them, or empty Trash when you are done

### Use labels as visual structure

- Create labels directly while working with a note
- Assign multiple labels to the same note
- Browse notes by label from the sidebar
- Edit label names from the sidebar
- Customize label icons with SF Symbols
- Customize label icon colors with a fixed palette
- See the same label styling in the sidebar, chips, pickers, and Quick Capture

### Turn notes into task hubs

- Add tasks inside a note
- Edit task text, details, and due dates
- Support due dates with or without time
- Mark tasks as completed or reopen them
- Reorder tasks inside the note
- Soft-delete tasks, restore them, or remove them permanently
- Review all tasks globally in dedicated sections:
  - Overdue
  - Today
  - Upcoming
  - No Date
  - Completed

### Get reminders that stay connected to the note

- Schedule local notifications for tasks with due dates
- Use notification actions to:
  - complete a task
  - snooze for one hour
  - snooze until tomorrow morning
- Jump from a notification back into the exact note and task

### Keep files and media attached to context

- Import files directly into a note
- Work with images, PDFs, code files, video, audio, and generic files
- Preview attachments with Quick Look
- Open attachments in the system
- See inline thumbnails for local image attachments
- Browse notes through dedicated `Attachments` views

### Save and preview code snippets

- Detect snippets from note content
- Create manual snippets
- Edit and remove manual snippets
- Preview snippets in a dedicated sheet
- Copy code to clipboard in one click
- Highlight syntax with `Highlightr`
- Switch preview language manually when needed

### Search like a power user

- Search across note titles, content, labels, snippets, and attachment names
- Use quick filters for pinned, favorite, tasks, attachments, and code
- Search with structured tokens such as:
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
- Use quoted phrases for more precise results

### Capture without breaking flow

- Open a dedicated Quick Capture window
- Create a note from anywhere in your workflow
- Add title, body, labels, pin state, and favorite state immediately
- Save and jump straight into the created note

## Product Experience

`Scriptoria` is built as a native three-column macOS app:

- sidebar for smart collections and labels
- main list for notes or global tasks
- detail area for reading, editing, and split view

The app is local-first, fast to navigate, and designed to feel at home on modern macOS rather than like a ported web interface.

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

Each collection shows a live count, so the workspace stays scannable even when the dataset grows.

## Release 0.9.8 Highlights

- Full label appearance editing from the sidebar
- SF Symbols support for label icons
- Fixed icon color palette for labels
- Consistent label rendering across sidebar, chips, picker, and Quick Capture
- Release build and install flow updated for version `0.9.8`

## Current Sync Status

The app already includes a sync queue, CloudKit record mapping, conflict-resolution scaffolding, and sync status reporting.

At the moment, CloudKit transport is still scaffolded and disabled by default, so release `0.9.8` behaves as a local-first app.

## Technology

- Swift
- SwiftUI
- Observation
- SQLite
- CloudKit scaffolding
- UserNotifications
- Quick Look
- `Highlightr`

## Project Structure

- `MyNotes/App` — app bootstrap, routing, scenes, coordinator
- `MyNotes/Features` — user-facing features by domain
- `MyNotes/Domain` — use cases and policies
- `MyNotes/Data` — repositories, database, local storage, sync queue, and sync mapping
- `MyNotes/Core` — models, services, types, and utilities
- `MyNotes/UI` — design system primitives and shared components
- `scripts/build_and_install_app.sh` — release build, signing, bundling, and install flow

## Build and Install

Requirements:

- macOS 26 beta or newer
- Xcode toolchain with Swift Package Manager support
- optional Apple Development signing identity for stable signed installs

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
