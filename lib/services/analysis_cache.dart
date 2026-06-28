import '../services/gemini_service.dart';

/// In-memory cache for Gemini analysis results.
///
/// ── Purpose ────────────────────────────────────────────────────────────────
/// Prevents duplicate Gemini API calls when the user navigates between
/// FoodSelectionScreen, MeasurementScreen, and NutritionResultScreen.
/// A new API call is only made when the user selects a different image.
///
/// ── Cache capacity ─────────────────────────────────────────────────────────
/// Holds exactly one entry — the most recent successful analysis result.
/// The user can only have one active image session at a time, so a
/// multi-entry cache would provide no practical benefit.
///
/// ── Cache key ──────────────────────────────────────────────────────────────
/// Keyed by the original image file path (before compression).
/// The compressed temp file is an implementation detail of
/// [ImageCompressionService] and is never used as a cache key.
///
/// ── Lifecycle ──────────────────────────────────────────────────────────────
/// [invalidate] is called when a new image is selected — before any
/// API call starts. [store] is called only on a successful API response.
/// A failed request therefore never pollutes the cache.
class AnalysisCache {
  // ── Singleton ─────────────────────────────────────────────────────────────

  AnalysisCache._();
  static final AnalysisCache instance = AnalysisCache._();

  // ── State ─────────────────────────────────────────────────────────────────

  _CachedAnalysis? _entry;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the cached [GeminiAnalysisResult] for [imagePath], or
  /// `null` if no valid cache entry exists for that path.
  ///
  /// A `null` return means the caller must perform a fresh Gemini request.
  GeminiAnalysisResult? get(String imagePath) {
    if (_entry == null) return null;
    if (_entry!.imagePath != imagePath) return null;
    return _entry!.result;
  }

  /// Returns `true` if a valid cache entry exists for [imagePath].
  ///
  /// Convenience wrapper around [get] for callers that only need
  /// to check existence without reading the result.
  bool has(String imagePath) => get(imagePath) != null;

  /// Stores [result] for [imagePath], replacing any previous entry.
  ///
  /// Must only be called after a **successful** Gemini response.
  /// Never call this in a catch block or after a partial result.
  void store(String imagePath, GeminiAnalysisResult result) {
    _entry = _CachedAnalysis(imagePath: imagePath, result: result);
  }

  /// Clears the cached entry.
  ///
  /// Call this as soon as a new image is selected — before starting
  /// the Gemini request — so a subsequent [get] cannot return a
  /// result from a previous image.
  void invalidate() {
    _entry = null;
  }

  // ── Debug ─────────────────────────────────────────────────────────────────

  /// Whether a cache entry is currently held (any path).
  /// Intended for debug logging only — use [has] for production logic.
  bool get hasAnyEntry => _entry != null;

  @override
  String toString() => _entry == null
      ? 'AnalysisCache(empty)'
      : 'AnalysisCache(path: ${_entry!.imagePath})';
}

// ── Private cache entry ───────────────────────────────────────────────────────

/// Bundles [imagePath] and [result] to keep the pair always in sync.
class _CachedAnalysis {
  const _CachedAnalysis({
    required this.imagePath,
    required this.result,
  });

  final String imagePath;
  final GeminiAnalysisResult result;
}