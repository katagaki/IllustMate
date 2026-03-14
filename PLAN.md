# Performance Optimization Plan for IllustMate

## 1. Parallelize Duplicate Hash Computation
**File:** `App/Classes/DuplicateScanManager.swift` (lines 70-78)

**Problem:** Hashes are computed one pic at a time in a sequential `for` loop. Each iteration loads image data from the DB, decodes it, computes the dHash, and stores it — all serially. For a collection of 1,000 uncached pics, this takes ~1,000x longer than necessary.

**Fix:** Replace the sequential loop with a `withTaskGroup` that processes 8 pics concurrently. Each child task loads data, decodes, and computes the hash. The main task collects results and updates progress on `@MainActor`.

---

## 2. Parallelize Duplicate Hash Comparison (O(n²) Loop)
**File:** `App/Classes/DuplicateScanManager.swift` (lines 151-158)

**Problem:** The `findDuplicateGroups` method compares every pair of hashes in a nested loop — O(n²). For 1,000 pics that's ~500K comparisons done on the main actor, blocking the UI.

**Fix:** Move the comparison to a nonisolated/detached context and split the outer loop across multiple concurrent tasks (e.g., partition the outer range into chunks processed in parallel). Union-Find mutations are lightweight and can be synchronized with a simple lock or collected and merged after.

---

## 3. Fetch Only Scoped Hashes from HashActor
**File:** `App/Classes/DuplicateScanManager.swift` (lines 83-85)

**Problem:** `allCachedHashes()` loads the entire hash table into memory, then filters it down to the scoped IDs. For large collections this is wasteful.

**Fix:** Add a `cachedHashes(forPicIDs:)` method to `HashActor` that accepts the scoped ID set and queries only those rows. Eliminates the full-table load and the follow-up filter allocation.

---

## 4. Use JPEG for Image `data()` Instead of PNG-First
**File:** `App/Utilities/UIImage.swift` (lines 13-22)

**Problem:** `data()` tries PNG encoding first. PNG encoding is slow (lossless compression) and produces large files. For most photos, it succeeds but wastes CPU. If the image has no alpha channel (the common case for photos), JPEG is a much better default.

**Fix:** Reorder to try JPEG first (with quality 1.0 for lossless-equivalent), then PNG as fallback for images with transparency, then HEIC.

---

## 5. Avoid Duplicate PHAsset Fetches in AsyncPhotosAlbumCover
**File:** `App/Views/Shared/AlbumCover.swift` (lines 266-301)

**Problem:** Two separate `PHAsset.fetchAssets()` calls are made — one with `fetchLimit: 3` for thumbnails, and another without a limit just to get `.count`. The second fetch scans the entire album just for a count.

**Fix:** Use a single fetch without `fetchLimit` to get both the count (`.count`) and the first 3 objects. Or better: use `PHAssetCollection`'s `estimatedAssetCount` property for the count when available, falling back to a count-only fetch.

---

## 6. Evict Stale Entries from ViewerManager Image Cache
**File:** `App/Classes/ViewerManager.swift` (line 26)

**Problem:** `imageCache: [String: UIImage]` grows unboundedly. Full-resolution `UIImage` objects (prepared for display) can be 20-50MB each. After browsing 20 images, that's potentially 400MB-1GB of cached images that are never released.

**Fix:** Add an `NSCache`-backed store (like `ThumbnailCache`) with a reasonable byte limit, or manually evict entries that are more than ~3 positions away from `currentIndex` after each navigation.

---

## 7. Cancel Stale Prefetch Tasks in ViewerManager
**File:** `App/Classes/ViewerManager.swift` (lines 113-128)

**Problem:** When the user swipes quickly through images, `prefetchAdjacentImages()` fires for every navigation. Previous prefetch tasks for now-irrelevant images continue running, wasting CPU and memory.

**Fix:** Track prefetch `Task` handles and cancel them when navigation moves past their target index before starting new prefetches.

---

## Summary

| # | Area | Impact | Effort |
|---|------|--------|--------|
| 1 | Parallel hash computation | High — 4-8x faster duplicate scanning | Medium |
| 2 | Parallel hash comparison | High — unblocks UI during comparison phase | Medium |
| 3 | Scoped hash fetch | Medium — reduces memory spike | Low |
| 4 | JPEG-first encoding | Medium — faster image saves | Low |
| 5 | Single PHAsset fetch | Low-Medium — fewer Photos framework round-trips | Low |
| 6 | Viewer cache eviction | High — prevents memory pressure / OOM | Low |
| 7 | Cancel stale prefetches | Medium — reduces wasted work during fast swiping | Low |
