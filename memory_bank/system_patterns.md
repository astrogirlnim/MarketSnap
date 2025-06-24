# MarketSnap Component Patterns  
*Snapchat‑style UI built with open‑source Flutter libs*

---
## Quick Colour Helpers (Tailwind / NativeWind)
```ts
// tailwind.config.js (excerpt)
module.exports = {
  theme: {
    extend: {
      colors: {
        'market-blue':  '#007AFF',
        'harvest-orange': '#FF9500',
        'leaf-green': '#34C759',
        'sunset-amber': '#FFCC00',
        'apple-red': '#FF3B30',
        cornsilk: '#FFF6D9',
        eggshell: '#FFFCEA',
        'seed-brown': '#C8B185',
      }
    }
  }
}
```

---
## Open‑Source Libraries Referenced
| Purpose | Snapchat Analogue | Flutter Library |
|---------|------------------|-----------------|
| Vector animations | In‑app Ghost loaders, story ring sweep | [`lottie`](https://pub.dev/packages/lottie) |
| Constraint DSL | SnapKit overlay positioning | `flutter_layout_grid` |
| Bottom sheets | SHModal rubber sheet | [`modal_bottom_sheet`](https://pub.dev/packages/modal_bottom_sheet`) |
| Stroke icons | 2 px rounded icon set | [`lucide_icons`](https://pub.dev/packages/lucide_icons) |

---
## Core Components
- **PrimaryButton** – bold Market Blue, rounded‑full, scale‑on‑press.
- **SecondaryButton** – Harvest Orange outline, transparent fill.
- **SnapCard** – feed cell showing photo/video + caption.
- **PendingCard** – queue status overlay + amber pulse.
- **StoryAvatar** – CAShapeLayer‑style ring via CustomPainter.
- **Toast** – bottom fade‑in‑up, Leaf Green success.

---
### Code Snippets
#### Primary Button
```dart
class PrimaryButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const PrimaryButton({required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: 0.97,
          duration: const Duration(milliseconds: 100),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge!
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      );
}
```

#### Story Ring Avatar (CAShapeLayer analogue)
```dart
class StoryAvatar extends StatelessWidget {
  final String imageUrl;
  const StoryAvatar({required this.imageUrl});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 300),
        builder: (context, value, _) => CustomPaint(
          painter: _RingPainter(progress: value,
              ringColor: const Color(0xFF007AFF), strokeWidth: 4),
          child: CircleAvatar(radius: 32, backgroundImage: NetworkImage(imageUrl)),
        ),
      );
}
```

#### Rubber‑Sheet Modal (snap‑points)
```dart
showCupertinoModalBottomSheet(
  context: context,
  expand: false,
  bounce: true,
  backgroundColor: Colors.transparent,
  builder: (_) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCEA),
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: YourSheetContent(),
  ),
);
```

---
## Layout Blueprint – Auth Screen
```dart
SafeArea(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const BasketIcon(),
      const SizedBox(height: 48),
      PrimaryButton(title: 'Sign Up as Vendor', onTap: _handleSignUp),
      const SizedBox(height: 16),
      Text('Start sharing your fresh finds', style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 32),
      SecondaryButton(title: 'Log In', onTap: _handleLogin),
      const SizedBox(height: 8),
      Text('Already have an account?', style: Theme.of(context).textTheme.caption),
      const SizedBox(height: 32),
      GestureDetector(
        onTap: _showAbout,
        child: Text('What is MarketSnap ➜', style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Color(0xFF007AFF))),
      ),
    ],
  ),
);
```

---
## DO ✔︎ / DON’T ✗
✔︎ Use open‑source libraries listed above to emulate Snapchat feel.  
✔︎ Keep Lottie JSON animations under **400 bytes**.  
✔︎ Disable animations automatically on devices < Android 8 / iOS 12.  
✗ Exceed 1 MB video after compression.  
✗ Shrink touch targets below **48 × 48 px**.

