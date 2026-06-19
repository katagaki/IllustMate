# Sort Intelligently — Entity-Based Album Recommendations

## Overview

A feature that analyzes an album's pictures, builds a semantic model of the
**entities** present in each album, and uses it to recommend which album a pic
should be moved to — an entity-aware similarity search rather than a
pixel/color/hash one.

It lives as a **"Sort Intelligently"** menu item in the same filter menu as
*Find Duplicates*, kept deliberately separate and non-imposing. Sorting always
requires confirmation: the user sees the suggested album for each pic, can pick
ranked alternatives, can skip, and can undo after committing. Album models are
generated **on demand** when the user taps the option, then cached and reused.

## Why Vision feature prints (not Vision over hashes/color)

The app already does pixel-level similarity for duplicate detection
(`DHash` → Hamming distance). Entity-level similarity needs semantic
understanding of the subject. iOS ships the right on-device primitives — free,
no model download:

- **`VNGenerateAttentionBasedSaliencyImageRequest`** — locates the dominant
  subject region, used to isolate the *primary entity* and de-weight
  background.
- **`VNGenerateImageFeaturePrintRequest`** → **`VNFeaturePrintObservation`** —
  a semantic feature vector per image. This vector **is** the entity's visual
  model.
- **`VNClassifyImageRequest`** — kept *optional and secondary* (see Domain
  notes); generic classifiers underperform on illustration content.

## Domain notes (this is an illustration manager)

These shape the v1 defaults and are the non-obvious decisions:

1. **De-emphasize text labels.** `VNClassifyImageRequest` is trained on
   photographic/ImageNet-style content and is frequently wrong on
   anime/illustration/character art. A wrong "Looks like: cat" erodes trust in
   the whole feature. Labels are secondary/optional; feature-print similarity is
   the engine.
2. **Visual justification over labels.** When clustering an album's prints,
   keep each cluster's **medoid** (the member pic closest to the cluster
   centroid) and store its pic ID in the album model. The confirmation UI shows
   "matches these →" with 1–3 real member thumbnails. For an art app this is far
   more convincing than any label, and is essentially free given the clustering.
3. **Conditional saliency cropping.** Full-bleed character/scene art is often
   *entirely* salient; cropping to a "subject" can remove context and hurt
   matching. Only apply the saliency crop when the salient region is meaningfully
   smaller than the frame (≈ <60% area) with sufficient confidence; otherwise
   feed the whole image.
4. **Honest framing.** This is semantic *visual* similarity focused on the main
   subject, **not** character/face identity recognition. The UI says "Suggested
   album," never "This is character X."

## Scope rules

The source pics and target albums depend on where the option is invoked,
walking the existing `parentAlbumID` hierarchy:

- **In an album A** — source = pics with `containingAlbumID == A` (directly in
  A, not in any sub-album of A). Targets = **all descendants of A**, recursively.
  A itself is not a target (those pics already live there).
- **At root** — source = pics with no `containingAlbumID`. Targets = **all
  albums**, recursively (the entire hierarchy).

Requires a recursive descendant-gathering helper in `DataActor` (collect child
album IDs by `parentAlbumID`, depth-first).

An album model's `member_signature` reflects only that album's **direct** pics,
so a deep album's cached model is not invalidated when an unrelated cousin album
changes.

## Per-pic entity-print pipeline

1. **Always analyze the cached thumbnail** (`Pic.thumbnailData`, ~120px JPEG in
   SQLite), never the original. With iCloud library support the original is
   often not on-device, and loading it would trigger an iCloud download (slow,
   data/battery cost, fails offline). The thumbnail is always present and synced.
   Using a uniform input size for every pic also keeps the resulting feature
   vectors directly comparable — mixing originals and thumbnails would produce
   vectors at different scales that don't compare cleanly. Videos use the
   existing video thumbnail frame. Pics with no thumbnail data are skipped and
   marked unanalyzable.
2. **One decode, batched requests:** run saliency + feature-print (+ optional
   classify) through a single `VNImageRequestHandler.perform([…])`.
3. Apply the conditional saliency crop (Domain note 3), with a **minimum crop
   size floor**: because the source is only ~120px, never feed a tiny sliver to
   the feature-print pass — skip the crop (use the whole thumbnail) when the
   salient region would fall below the floor, and upscale the crop to the floor
   otherwise.
4. Convert the `VNFeaturePrintObservation` to a raw `Float32` vector at the
   actor boundary (the observation is **not** `Sendable`; the vector is).

## Album model

An album may hold multiple entities, so a single centroid is too lossy. The
model is a small set of cluster prototypes:

- Gather member prints, cluster with lightweight agglomerative clustering by a
  distance threshold, capped at K prototypes.
- Each prototype stores: centroid vector + the **medoid pic ID** (for visual
  justification) + optional dominant labels.
- Distance(pic → album) = **min** distance over the album's prototypes, so an
  album of "cats + dogs" matches either kind of pic.
- Albums with too few pics are flagged "limited data" rather than excluded.

## Recommendation flow

`IntelligentSortManager` (`@MainActor @Observable`, modeled on
`DuplicateScanManager`) drives the existing `StatusView` progress UI via a
`SortPhase` enum (`.idle`, `.buildingAlbumModels`, `.analyzingPics`,
`.matching`, `.done`).

1. **Build/refresh album models** — recompute an album only if its
   `member_signature` changed; otherwise reuse the cache.
2. **Analyze source pics** — compute or load the cached entity print per pic.
3. **Match** — rank target albums by min-prototype distance; produce top-N
   suggestions per pic with a confidence score. Below threshold → "No
   suggestion," left unselected, never force-moved.

**Shared-cache invariant:** a pic's entity print is identical whether it is an
album *member* (model build) or a *candidate* (matching). It is computed once
into `FeaturePrintActor` and reused for both — this is what makes repeat runs
cheap.

## Persistence & caching (mirrors `HashActor` / `PColorActor`)

- **`FeaturePrintActor`** backed by **`FeaturePrints.db`**:
  `pic_feature_prints(pic_id PK, feature_data BLOB, labels TEXT, vector_len INT, vision_revision INT, print_version INT)`.
  Stores the raw `Float32` vector (~768 floats ≈ 3 KB/pic; 10k pics ≈ 30 MB).
  We **do not** archive the whole `VNFeaturePrintObservation` (brittle across
  OS/Vision revisions, can't be averaged into centroids). Distance is computed
  ourselves via cosine similarity (vDSP/Accelerate). Invalidate on
  `vision_revision` / `vector_len` / `print_version` mismatch.
- **`AlbumModelActor`** backed by **`AlbumModels.db`**:
  `album_models(album_id PK, model_data BLOB, member_signature TEXT, print_version INT)`.
  `member_signature` = hash of direct member pic IDs + count; recompute only on
  change.

## Performance

- **Bounded parallelism:** compute prints in a `TaskGroup` capped at
  ≈`activeProcessorCount` (never unbounded — that risks jetsam on large
  libraries). Each image wrapped in an autorelease scope.
- **Thumbnail-only input** (above) means no full-res decode, no disk I/O, and
  no iCloud downloads — analysis works whether or not originals are on-device.
- **Cheap matching:** candidates × albums × ≤K prototypes of cosine sims is
  trivial even for thousands of pics.
- **First-run vs warm-run:** the first invocation computes everything (slow —
  communicated in UI); later runs hit cache and feel near-instant.
- **Opportunistic precompute (opt-in, default off):** prints could piggyback on
  the existing color/hash analysis pass to make the first run fast, but this is
  off by default to honor the "as and when tapped / non-imposing" requirement.

## UX

- **Group results by destination album** ("12 pics → Album X") with per-group
  *Accept all*, plus a global **Accept all strong matches** that leaves weak/no
  matches for manual review. Row-by-row confirmation does not scale.
- **Qualitative confidence** (Strong / Likely / Weak), not raw distances; below
  threshold → "No suggestion," not preselected. Conveyed with text + icon, not
  color alone (accessibility). Optional match-strictness control mirroring the
  duplicate scanner's sensitivity slider, with a sane default.
- **Undo.** Moving pics reorganizes the library; record the moves and offer a
  single Undo after committing (resetting `containingAlbumID` is sync-safe via
  the existing tombstone/dirty machinery). Plus a pre-commit summary ("Move 24
  pics into 5 albums?").
- **Cancel + cheap resume.** Runs are cancellable (`Task` cancellation);
  because prints are cached, re-running resumes nearly free. Interactive dismiss
  stays disabled mid-run (like the scanner), with an explicit Cancel.
- **Degenerate states, explicit:** no target albums (root with no albums / album
  with no sub-albums), empty source set, albums with too few pics ("limited
  data"), and pics with no identifiable subject ("Couldn't identify a subject,"
  left unsorted). Near-ties surfaced as "close call" rather than silently picked.
- **Visual justification** in each suggestion: representative member thumbnails
  ("matches these →") from the album's matched prototype medoid.

## Concurrency (Swift 6)

Vision runs off-main inside the new actors / detached tasks. Only
`[Float]` / `Data` / IDs cross isolation boundaries — never
`VNFeaturePrintObservation` or `UIImage`. The manager stays `@MainActor`. In
actor `init`s, assign stored properties via locals only (per CLAUDE.md).

## Files

**New**
- `Shared/Data Actor/FeaturePrintActor.swift`
- `Shared/Data Actor/AlbumModelActor.swift`
- `App/Classes/IntelligentSortManager.swift`
- `App/Utilities/EntityVision.swift` (saliency crop + batched feature-print/classify helpers)
- `App/Views/Sort/IntelligentSortView.swift` (config + run)
- `App/Views/Sort/IntelligentSortResultsView.swift` (grouped confirmation + alternatives + undo)
- New `StatusTitle` cases + localized strings

**Edited**
- `App/Views/Album/AlbumView/AlbumView+Toolbar.swift` (menu item + sheet state, beside *Find Duplicates*, system image `wand.and.stars`)
- `App/Views/Photos/PhotosAlbumContentView.swift` (same menu item)
- `Shared/Data Actor/DataActor.swift` (register new DBs; recursive descendant-album helper)
- Reuse the existing move-pic path in `Shared/Data Actor/DataActor+Pics.swift`

## Deferred (phase 2)

- **Per-pic suggestion in the existing "Move To" context menu** — once album
  models are cached, pin a single suggested album to the top of *Move To* (which
  already shows last-used album, per #120). Reuses cached models with no new
  modal flow; the highest day-to-day value, deferred to a later PR.
- **Larger cached analysis thumbnail (opportunistic).** The ~120px thumbnail is
  the guaranteed baseline (always available, always comparable). If real-world
  testing shows 120px is marginal for distinguishing similar entities, generate
  a slightly larger analysis thumbnail (e.g. ~256px) once and cache it in
  `FeaturePrints.db`. This is only derivable when an original happens to be
  on-device, so it can never be the universal path — it stays an opportunistic
  enhancement layered on top of the 120px baseline, not a replacement for it.
