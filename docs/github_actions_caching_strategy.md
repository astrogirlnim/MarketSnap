# GitHub Actions Caching Strategy for MarketSnap

## Overview

This document outlines the comprehensive caching strategy implemented in the MarketSnap GitHub Actions CI/CD pipeline to significantly reduce build times and improve development efficiency.

## Cache Strategy Implementation

### 1. Flutter Dependencies Caching

**Cached Paths:**
- `~/.pub-cache` - Flutter global package cache
- `.dart_tool` - Project-specific Dart tooling cache

**Cache Key:** `flutter-pub-${{ runner.os }}-${{ hashFiles('pubspec.lock') }}`

**Benefits:**
- ✅ Eliminates repeated downloads of Flutter packages
- ✅ Reduces `flutter pub get` time from ~2-3 minutes to ~10-15 seconds
- ✅ Consistent across all jobs (validate, build_android, etc.)

### 2. Gradle Dependencies Caching

**Cached Paths:**
- `~/.gradle/caches` - Gradle global dependency cache
- `~/.gradle/wrapper` - Gradle wrapper cache
- `android/.gradle` - Project-specific Gradle cache

**Cache Key:** `gradle-${{ runner.os }}-${{ hashFiles('android/gradle/wrapper/gradle-wrapper.properties', 'android/build.gradle.kts', 'android/app/build.gradle.kts') }}`

**Benefits:**
- ✅ Eliminates Android dependency downloads
- ✅ Reduces first-time dependency resolution from ~3-5 minutes to ~30 seconds
- ✅ Preserves Gradle daemon state for faster builds

### 3. Gradle Build Cache

**Cached Paths:**
- `android/build` - Android build outputs
- `android/app/build` - App-specific build outputs

**Cache Key:** `gradle-build-${{ runner.os }}-${{ github.sha }}`

**Benefits:**
- ✅ Enables incremental builds
- ✅ Reduces compilation time for unchanged code
- ✅ Preserves intermediate build artifacts

### 4. Node.js Dependencies Caching

**Cached Paths:**
- `functions/node_modules` - Firebase Functions dependencies

**Cache Key:** `node-${{ runner.os }}-${{ hashFiles('functions/package-lock.json', 'functions/package.json') }}`

**Benefits:**
- ✅ Eliminates repeated npm installs
- ✅ Reduces function deployment preparation time
- ✅ Consistent package versions across builds

### 5. Firebase CLI & Tools Caching

**Cached Paths:**
- `~/.cache/firebase` - Firebase CLI cache
- `~/.npm` - Global npm cache

**Cache Key:** `firebase-cli-${{ runner.os }}-${{ hashFiles('functions/package.json') }}`

**Benefits:**
- ✅ Speeds up Firebase CLI operations
- ✅ Reduces global tool installation time
- ✅ Preserves Firebase project configurations

### 6. TypeScript Build Caching

**Cached Paths:**
- `functions/lib` - Compiled TypeScript output

**Cache Key:** `functions-build-${{ runner.os }}-${{ hashFiles('functions/src/**/*.ts', 'functions/tsconfig.json') }}`

**Benefits:**
- ✅ Skips TypeScript compilation for unchanged code
- ✅ Faster Firebase Functions deployment
- ✅ Incremental build support

## Performance Improvements

### Expected Time Savings

| Job Phase | Before Caching | After Caching | Time Saved |
|-----------|----------------|---------------|------------|
| Flutter Dependencies | 2-3 minutes | 10-15 seconds | ~85% |
| Gradle Dependencies | 3-5 minutes | 30-60 seconds | ~80% |
| Android Build | 5-8 minutes | 2-4 minutes | ~50% |
| Firebase Functions | 1-2 minutes | 20-30 seconds | ~75% |
| **Total Pipeline** | **15-20 minutes** | **6-10 minutes** | **~60%** |

### Cache Hit Scenarios

1. **Full Cache Hit:** All dependencies and builds cached
   - Occurs when no dependency files changed
   - Maximum performance benefit

2. **Partial Cache Hit:** Some caches invalidated
   - Occurs when specific dependency files change
   - Still provides significant performance benefits

3. **Cache Miss:** No cache available
   - First run on new branches
   - After cache expiration (7 days)
   - Falls back to full build process

## Build Optimizations

### Gradle Configuration

```bash
# Environment variables set during build
export GRADLE_OPTS="-Dorg.gradle.daemon=true -Dorg.gradle.parallel=true -Dorg.gradle.caching=true"
```

**Optimizations:**
- ✅ Gradle daemon enabled for persistent JVM
- ✅ Parallel builds enabled for multi-module projects
- ✅ Build caching enabled for incremental compilation

### Flutter Build Optimization

- **Skipped `flutter clean`** to preserve cached builds
- **Incremental builds** leveraging cached intermediate files
- **Verbose logging** for debugging and monitoring

### Cache Key Strategy

**Composite Keys:**
- Include OS to prevent cross-platform conflicts
- Hash dependency files for precise invalidation
- Use fallback keys for partial cache hits

**Fallback Keys:**
```yaml
restore-keys: |
  flutter-pub-${{ runner.os }}-
  gradle-${{ runner.os }}-
  node-${{ runner.os }}-
```

## Monitoring & Debugging

### Cache Status Logging

Each job includes logging to verify cache effectiveness:

```bash
# Flutter cache status
if [ -d "~/.pub-cache" ]; then
  echo "✅ Flutter pub cache restored successfully"
fi

# Gradle cache status  
if [ -d "~/.gradle/caches" ]; then
  echo "✅ Gradle dependencies cache restored"
fi

# Node.js cache status
if [ -d "node_modules" ]; then
  echo "✅ Node.js dependencies cache restored"
fi
```

### Cache Invalidation Triggers

1. **Dependency File Changes:**
   - `pubspec.lock` → Flutter cache invalidated
   - `gradle-wrapper.properties`, `build.gradle.kts` → Gradle cache invalidated
   - `package-lock.json`, `package.json` → Node.js cache invalidated

2. **Source Code Changes:**
   - `functions/src/**/*.ts` → TypeScript build cache invalidated
   - New commits → Build cache invalidated (using `github.sha`)

3. **Manual Invalidation:**
   - Repository settings → Actions → Caches
   - Delete specific caches if needed

## Best Practices

### 1. Cache Maintenance
- **Regular monitoring** of cache hit rates
- **Periodic cleanup** of unused caches
- **Version updates** may require cache invalidation

### 2. Dependency Management
- **Lock file commits** ensure consistent caching
- **Dependency updates** should be batched for efficiency
- **Security updates** may require immediate cache invalidation

### 3. Build Configuration
- **Gradle daemon** enabled for performance
- **Parallel builds** for multi-core utilization
- **Incremental compilation** preserved through caching

### 4. Debugging
- **Verbose logging** enabled for build troubleshooting
- **Cache status checks** in each job
- **Retry mechanisms** for transient failures

## Cache Storage Limits

GitHub Actions cache limits:
- **Maximum cache size:** 10GB per repository
- **Cache retention:** 7 days for unused caches
- **Active cache limit:** 10GB across all branches

**Optimization strategies:**
- Use specific cache keys to avoid bloat
- Regular cleanup of unused caches
- Monitor cache usage in repository settings

## Troubleshooting

### Common Issues

1. **Cache Miss Despite No Changes**
   - Check if cache key format changed
   - Verify file paths are correct
   - Ensure fallback keys are properly configured

2. **Build Failures with Cache**
   - Corrupted cache files
   - Solution: Clear cache and rebuild
   - Add retry mechanisms for resilience

3. **Performance Not Improved**
   - Verify cache hit rates in logs
   - Check if build process is optimized
   - Ensure incremental builds are enabled

### Emergency Procedures

If caching causes issues:
1. **Disable specific caches** by commenting out cache steps
2. **Clear all caches** in repository settings
3. **Revert to non-cached build** temporarily
4. **Investigate and fix** caching configuration

## Future Enhancements

### Potential Improvements

1. **Docker Layer Caching**
   - Cache Docker build layers
   - Faster container-based builds

2. **Artifact Caching**
   - Cache built APK/IPA files
   - Reuse for testing phases

3. **Test Result Caching**
   - Skip unchanged test suites
   - Parallel test execution

4. **Cross-Job Dependencies**
   - Share caches between jobs
   - Reduce overall pipeline time

---

*This caching strategy is designed to significantly improve the MarketSnap CI/CD pipeline performance while maintaining build reliability and reproducibility.* 