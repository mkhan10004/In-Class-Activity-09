# Inc09 – Local Storage Part II

This project extends the original Part I SQLite app to a folder-and-card catalogue using a versioned database migration, parent/child tables, and safe UI validation.

## Project overview

- Flutter app: `inc09`
- Primary database helper: `lib/database_helper.dart`
- Models: `lib/models.dart`
- App UI: `lib/main.dart`
- Database file name: `inc09.db` (or a test database when running unit tests)
- Schema version: `2`
- Legacy table preserved: `guests`

## Schema design

The app uses:

- `folders(id, name, created_at)`
- `cards(id, title, suit, notes, image_ref, folder_id)`
- index: `idx_cards_folder_id` on `cards(folder_id)`

The foreign key is defined as:

- `FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE`

This means that deleting a folder also removes that folder's cards. The alternative could be `RESTRICT` or `SET NULL`, which is preferable when data must stay for audit or archival purposes. In this lab, cascade is the correct default because a folder's cards are treated as belonging to it.

## Key implementation notes

- `DatabaseHelper` enables `PRAGMA foreign_keys = ON` in `onConfigure`.
- `openDatabase` bumps the version from `1` to `2` and creates the new tables in `onUpgrade`.
- Existing guest rows are preserved and the original table is kept intact.
- UI layers use model objects and repository methods instead of embedding SQL in widgets.
- `image_ref` is nullable and the UI falls back to a suit symbol when the reference is empty, invalid, or unavailable.

## Verified checks

### Analyzer evidence

The project was run with:

- `flutter analyze`

Result: no issues found.

Saved output:

- `evidence/analysis_output.txt`

### Unit test evidence

The project was run with:

- `flutter test`

Result: `00:27 +5: All tests passed!`

The tests cover:

- fresh schema creation with legacy guest retention
- folder/card relationship creation
- delete cascade behavior
- legacy guest data shape and migration from version 1 to version 2

## Test matrix for T1–T6

| Test | Action | Expected | Observed / status |
| --- | --- | --- | --- |
| T1 | Upgrade existing version-1 database to version 2 | Original guest rows remain and new tables/index exist | Verified in the migration unit tests |
| T2 | Create folders and cards | Distinct IDs and correct folder counts | Covered by database helper tests |
| T3 | Edit one card, cancel another | Only the intended card changes; cancel does nothing | Logic implemented and testable through the helper/UI flow |
| T4 | Restart app without clearing storage | Same records remain available after relaunch | Requires a real device/emulator cold restart for full evidence |
| T5 | Delete one card and delete one folder | Card delete affects one row; folder delete cascades children | Implemented and covered by cascade test |
| T6 | Invalid title/folder/image fallback | Validation errors and placeholder display | Logic implemented in UI and fallback rendering |

## Evidence limitations

This workspace was validated with Flutter analysis and unit tests, but the device-level screenshot evidence required by the assignment (`T1_before.png`, `T2_cards.png`, `T4_after.png`) was not captured in this local environment because no physical Android/iOS device, emulator session, or app cold-restart procedure was run here.

The project is prepared for that workflow, but those artifacts must be produced on the target device/emulator before final submission.

## Required next steps before submission

1. Run the app on a real Android/iOS target.
2. Capture the three required screenshots with the exact file names.
3. Record the actual IDs and counts for T1–T6 in the final README or reflection doc.
4. Build and verify the release APK on the target device.
5. Complete the reflection document and AI Lab answers.

## Files to keep in the repository

- `lib/database_helper.dart`
- `lib/models.dart`
- `lib/main.dart`
- `test/database_helper_test.dart`
- `evidence/analysis_output.txt`
- `github_link.txt`
