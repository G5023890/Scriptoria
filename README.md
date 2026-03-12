# Scriptoria

**A native macOS workspace for notes, tasks, snippets, attachments, and fast capture.**

`Scriptoria` is built for people who collect ideas all day, move between writing and execution, and want one calm place for everything: notes, labels, tasks, code, files, and search.

Current app bundle: `MyNotes`  
Current release: `0.9.9`  
Repository: [G5023890/Scriptoria](https://github.com/G5023890/Scriptoria)

## Hero

Most tools force you to choose one mode of thinking.

- notes app for writing
- task app for planning
- snippets app for code
- file browser for assets
- search tool for finding things again

`Scriptoria` combines those workflows into one native macOS workspace. You can capture an idea, turn part of it into a task, attach files, save code snippets, label it visually, and still find it later with structured search.

## Why It Feels Different

- Native macOS app, not a wrapped web UI
- Three-column workspace optimized for scanning and editing
- Local-first behavior for fast interaction
- Notes, labels, tasks, snippets, and files stay connected
- Quick Capture lets you save ideas without breaking flow
- Search is built for both casual recall and power-user filtering

## Who It's For

- Developers who keep research notes, snippets, todos, and files together
- Founders and operators who need one working inbox for ideas and execution
- Writers and researchers who want labels, search, and structured note history
- Power users who prefer native macOS apps over browser-heavy workflows
- Anyone building a personal knowledge base that needs to stay actionable

## What You Can Do

### Notes

- Create notes instantly from the toolbar or with `Cmd+N`
- Edit title and body
- Switch between `Read`, `Edit`, and `Split` modes
- Keep archived note items grouped in a dedicated bottom `Архив` section
- Pin important notes
- Mark favorites
- Move notes to Trash, restore them, or empty Trash

### Labels

- Create labels while working with a note
- Assign multiple labels to the same note
- Browse notes by label from the sidebar
- Edit label names from the sidebar
- Customize label icons with SF Symbols
- Customize label icon colors with a fixed palette
- See the same label styling in sidebar rows, chips, pickers, and Quick Capture

### Tasks

- Add tasks inside notes
- Edit task text, details, and due dates
- Support due dates with or without time
- Mark tasks complete and reopen them
- Keep completed tasks marked as `Done` while also grouping archived ones inside note detail
- Reorder tasks inside a note
- Soft-delete, restore, or permanently remove tasks
- Review all tasks in global sections: `Overdue`, `Today`, `Upcoming`, `No Date`, `Completed`

### Notifications

- Schedule local reminders for tasks with due dates
- Complete tasks directly from a notification
- Snooze for one hour
- Snooze until tomorrow morning
- Jump from a notification back into the exact note and task

### Attachments

- Import files directly into notes
- Work with images, PDFs, code files, video, audio, and generic files
- Archive attachments out of the active note section without deleting them
- Preview attachments with Quick Look
- Open attachments in the system
- See inline thumbnails for local image attachments

### Code Snippets

- Detect snippets from note content
- Create manual snippets
- Edit, archive, and remove manual snippets
- Preview snippets in a dedicated sheet
- Copy code to clipboard
- Highlight syntax with `Highlightr`
- Switch preview language manually when needed

### Search

- Search across titles, note content, labels, snippets, and attachment names
- Use quick filters for pinned, favorites, tasks, attachments, and code
- Use structured tokens such as `is:pinned`, `has:tasks`, `label:<name>`, `type:code`, `updated:today`, `language:<name>`, `kind:snippet`, `in:attachments`
- Use quoted phrases for more precise results

### Quick Capture

- Open a dedicated Quick Capture window
- Create a note from anywhere in your workflow
- Add title, body, labels, pin state, and favorite state immediately
- Save and jump straight into the created note

## Screenshots

Real screenshots from the current app build.

### Main Workspace

![Main Workspace](docs/screenshots/main-workspace.png)

Three-column workspace with smart collections, labels, note list, and detail view.

### Quick Capture

![Quick Capture](docs/screenshots/quick-capture.png)

Fast note capture window with labels, pin, and favorite controls.

More screenshots for label editing and task-focused flows will be added in the next pass.

## Product Experience

`Scriptoria` is built as a native three-column macOS app:

- sidebar for smart collections and labels
- main list for notes or global tasks
- detail area for reading, editing, and split view

The sidebar currently includes:

- `All Notes`
- `Favorites`
- `Pinned`
- `Recent`
- `Tasks`
- `Attachments`
- `Snippets`
- `Trash`

Each collection shows a live count so the workspace stays scannable as it grows.

## Release 0.9.9

- New bottom `Архив` section inside note detail for archived tasks, snippets, and attachments
- Archive rows are merged into one mixed list and hidden from active note sections
- Completed tasks keep their `Done` status and also participate in archive grouping
- Snippets and attachments now support direct archive actions from note detail
- Archive section opens collapsed by default and scrolls into view when expanded
- Release build and install flow updated for version `0.9.9`

## Roadmap

Near-term priorities:

- Enable real CloudKit transport on top of the existing sync scaffolding
- Improve README visuals with real screenshots and usage examples
- Expand release polish across label editing and detail workflows
- Continue refining the native macOS visual language and interactions

Already present in the codebase:

- sync queue
- CloudKit record mapping
- conflict-resolution scaffolding
- sync status reporting

Current status: CloudKit transport is scaffolded but still disabled by default, so `0.9.9` behaves as a local-first app.

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

## Build And Install

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
