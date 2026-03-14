# Performance Optimization Plan for IllustMate

## 1. Use JPEG for Image `data()` Instead of PNG-First
**File:** `App/Utilities/UIImage.swift` (lines 13-22)

**Problem:** `data()` tries PNG encoding first. PNG encoding is slow (lossless compression) and produces large files. For most photos, it succeeds but wastes CPU. If the image has no alpha channel (the common case for photos), JPEG is a much better default.

**Fix:** Reorder to try JPEG first (with quality 1.0 for lossless-equivalent), then PNG as fallback for images with transparency, then HEIC.

---

## 2. Avoid Duplicate PHAsset Fetches in AsyncPhotosAlbumCover
**File:** `App/Views/Shared/AlbumCover.swift` (lines 266-301)

**Problem:** Two separate `PHAsset.fetchAssets()` calls are made — one with `fetchLimit: 3` for thumbnails, and another without a limit just to get `.count`. The second fetch scans the entire album just for a count.

**Fix:** Use a single fetch without `fetchLimit` to get both the count (`.count`) and the first 3 objects. Or better: use `PHAssetCollection`'s `estimatedAssetCount` property for the count when available, falling back to a count-only fetch.

---

## 3. Evict Stale Entries from ViewerManager Image Cache
**File:** `App/Classes/ViewerManager.swift` (line 26)

**Problem:** `imageCache: [String: UIImage]` grows unboundedly. Full-resolution `UIImage` objects (prepared for display) can be 20-50MB each. After browsing 20 images, that's potentially 400MB-1GB of cached images that are never released.

**Fix:** Add an `NSCache`-backed store (like `ThumbnailCache`) with a reasonable byte limit, or manually evict entries that are more than ~3 positions away from `currentIndex` after each navigation.

---

## 4. Cancel Stale Prefetch Tasks in ViewerManager
**File:** `App/Classes/ViewerManager.swift` (lines 113-128)

**Problem:** When the user swipes quickly through images, `prefetchAdjacentImages()` fires for every navigation. Previous prefetch tasks for now-irrelevant images continue running, wasting CPU and memory.

**Fix:** Track prefetch `Task` handles and cancel them when navigation moves past their target index before starting new prefetches.

---

## 5. Parallelize Prominent Color Calculation
**File:** `App/Views/Collection/AlbumView+Functions.swift` (lines 221-228)

**Problem:** `sortPicsByProminentColor()` computes colors sequentially — one pic at a time in a `for` loop. Each call to `ProminentColor.calculate(from:)` downsamples and quantizes the image, which is CPU-bound work. It also calls `allCachedColors()` which loads the entire color table even when only the current album's pics are needed.

**Fix:** Use `withTaskGroup` to compute colors for uncached pics concurrently (e.g., 8 at a time). Also add a scoped query to `PColorActor` (e.g., `cachedColors(forPicIDs:)`) so only relevant rows are fetched instead of the full table.

---

## Summary

| # | Area | Impact | Effort |
|---|------|--------|--------|
| 1 | JPEG-first encoding | Medium — faster image saves | Low |
| 2 | Single PHAsset fetch | Low-Medium — fewer Photos framework round-trips | Low |
| 3 | Viewer cache eviction | High — prevents memory pressure / OOM | Low |
| 4 | Cancel stale prefetches | Medium — reduces wasted work during fast swiping | Low |
| 5 | Parallel color calculation | Medium-High — faster "sort by color" for large albums | Medium |
