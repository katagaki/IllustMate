# Migration to Photos Library Integration

## Summary

This update migrates IllustMate from a custom SwiftData-based album and photo management system to using the iOS Photos library (PHPhotoLibrary) for storing and organizing photos. This change allows users to manage their photos using Apple's built-in Photos app while still benefiting from IllustMate's organizational features.

## Key Changes

### 1. Photos Library Access

- **Added permissions** in `Info.plist`:
  - `NSPhotoLibraryUsageDescription`: Read access to photos
  - `NSPhotoLibraryAddUsageDescription`: Write access to add photos

### 2. New Manager and Actor Classes

#### PhotosLibraryManager
Location: `Shared/PhotosLibraryManager.swift`

Handles all interactions with the iOS Photos library:
- Request and check authorization status
- Fetch user albums and folders
- Fetch photos (PHAssets) from collections
- Create/delete albums and photos
- Detect special case: albums with same name as parent folder

#### PhotosDataActor
Location: `Shared/PhotosDataActor.swift`

Actor for thread-safe Photos library operations:
- Provides async/await interface for Photos operations
- Handles album sorting
- Manages photo and album lifecycle

### 3. New Model Wrappers

#### PhotoAlbum
Location: `Shared/Data Models/PhotoAlbum.swift`

Wraps PHAssetCollection (albums) and PHCollectionList (folders):
- Unified interface for both albums and folders
- **Special Feature**: Detects when a folder contains an album with the same name
  - When detected, photos in that same-name album are treated as being in the folder directly
  - The same-name album is hidden from the child albums list
- Provides child albums/folders
- Fetches photos in the album/folder
- Generates cover images and representative photos

#### PhotoIllustration
Location: `Shared/Data Models/PhotoIllustration.swift`

Wraps PHAsset (individual photos):
- Async methods to load thumbnails and full images
- Provides photo metadata (name, date added)

### 4. Updated Views

All views have been updated to use PhotoAlbum and PhotoIllustration instead of the old Album and Illustration models:

- `AlbumView` and `AlbumView+Functions`
- `AlbumsView`
- `IllustrationsView`
- `CollectionView`
- `ImporterView`
- `NewAlbumView`
- `RenameAlbumView` (Note: Renaming albums not supported by PhotoKit)
- `MainSplitView`
- `AlbumNavigationStack`
- All label and grid components
- All menu components

### 5. ViewerManager Updates

Updated to work with PhotoIllustration:
- Loads images asynchronously from Photos library
- Maintains image cache for performance

### 6. Authorization Flow

Added Photos library authorization request on app launch in `App.swift`

## Limitations and Known Issues

### PhotoKit Limitations

1. **Album Renaming**: PhotoKit doesn't support programmatic album renaming
   - RenameAlbumView attempts this but will fail gracefully

2. **Moving Albums Between Folders**: Not supported by PhotoKit
   - AlbumMoveMenu is disabled with appropriate messaging

3. **Custom Album Covers**: PhotoKit generates covers automatically
   - "Set as Cover" feature is commented out in IllustrationsGrid

4. **Nested Album Management**: Complex folder hierarchies have limited support
   - The special "same name album" feature helps work around this limitation

### Temporarily Disabled Features

The following features are temporarily disabled pending full migration:
- Troubleshooting tools (export, rebuild thumbnails, consistency checks)
- Some orphan file management features

These features were specific to the old file-based storage system and need to be redesigned for Photos library integration.

## Special Feature: Same-Name Album Detection

This is a key feature that allows folders to contain both albums and photos simultaneously:

**How it works:**
1. When a folder is accessed, the system checks if it contains an album with the same name
2. If found, photos in that same-name album are treated as being in the folder directly
3. The same-name album is hidden from the list of child albums
4. This allows the Photos library's structure (where collections can only contain assets, not other collections) to appear as if folders can contain both photos and sub-albums

**Example:**
```
📁 Vacation (folder)
   📷 photo1.jpg    <- From "Vacation" album (same name as folder)
   📷 photo2.jpg    <- From "Vacation" album
   📁 Beach (sub-album)
   📁 Mountains (sub-album)
```

## Testing Recommendations

1. **Authorization**: Test the Photos library authorization flow on first launch
2. **Album Display**: Verify that albums and folders display correctly
3. **Photo Loading**: Check that thumbnails and full images load properly
4. **Special Case**: Test folders with same-name albums to ensure photos appear correctly
5. **Photo Import**: Test adding new photos through ImporterView
6. **Navigation**: Verify navigation between albums and folders works correctly

## Migration Notes for Users

Users migrating from the old system should note:
- Photos are now stored in the iOS Photos library instead of app storage
- Existing app data is not automatically migrated
- The app now works with the user's existing Photos library structure
- Changes made in IllustMate are reflected in the Photos app and vice versa

## Future Enhancements

Potential improvements for future releases:
1. Add migration tool to move old app photos to Photos library
2. Re-enable troubleshooting features adapted for Photos library
3. Add more PhotoKit features (favorites, shared albums, etc.)
4. Improve performance with better caching strategies
5. Add batch operations for managing multiple photos
