# Quality Check: Accessibility

## Your Task

You are an AI code editor tasked with auditing and fixing accessibility across the Plank Challenge iOS app. Your goal is to ensure the app is fully usable with VoiceOver, respects the user's motion and display preferences, meets WCAG AA colour contrast standards, and works correctly at all Dynamic Type sizes — including the largest accessibility sizes.

Work through this document top to bottom. For each section, search the codebase, identify the problems, implement the fixes, and move on. Do not skip sections.

---

## Project Context

**App**: Plank Challenge — a social fitness iOS app where users log a daily plank and maintain a streak.

**Platform**: iOS, SwiftUI, Swift 5.9+, `@Observable`, Swift Concurrency.

**Key architectural facts you need to know:**
- Screen views live at `PlankChallenge/` top level; reusable components at `PlankChallenge/Components/`; design system at `PlankChallenge/DesignSystem/`
- The app uses a custom colour palette defined as `Color` extensions — likely in `PlankChallenge/Constants.swift` or a dedicated colour file
- The main plank screen (`PlankTimerView.swift`) uses a "Shazam-inspired deep blue" dark background with animated components: `ActivePlankRing`, `LavaBubblesView`, `CelebrationOverlayView`, `CountdownOverlayView`
- All other screens use an Apple Health-inspired soft blue theme
- Custom `ViewModifier`s exist for pulsing glow and card styles
- The timer state machine drives the UI through states: `ready`, `countdown(Int)`, `active`, `celebration`, `completedToday`
- Components: `ActivePlankRing`, `AvatarView`, `LeaderboardRowView`, `StreakCalendarView`, `StreakHeroView`, `StreakStatsRow`, `UserRowView`, `CelebrationOverlayView`, `CountdownOverlayView`, `LavaBubblesView`
- No third-party accessibility libraries — everything is native SwiftUI and UIKit accessibility APIs

---

## Step 1 — Audit Reduced Motion Support

The app contains several animated components that must respect the system's "Reduce Motion" accessibility setting. Users who are sensitive to motion (vestibular disorders, epilepsy) rely on this setting.

**Read `@Environment(\.accessibilityReduceMotion)`** — this is the SwiftUI environment value that reflects the user's Reduce Motion preference.

Search all files in `PlankChallenge/` for `withAnimation`, `animation(`, `.animation(`, `Animation.`, `LavaBubblesView`, `CelebrationOverlayView`, `CountdownOverlayView`, `ActivePlankRing` — these are all candidates for reduce-motion treatment.

For each animated component or view, apply one of these strategies:

**Strategy A — Replace with a static alternative:**
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var body: some View {
    if reduceMotion {
        // Static version: simple opacity or scale, no continuous animation
        Circle()
            .stroke(Color.appAccent, lineWidth: 4)
            .frame(width: 200, height: 200)
    } else {
        ActivePlankRing(progress: progress)
    }
}
```

**Strategy B — Reduce the animation (shorter duration, no looping):**
```swift
var body: some View {
    Circle()
        .scaleEffect(isActive ? 1.05 : 1.0)
        .animation(
            reduceMotion ? .easeInOut(duration: 0.1) : .easeInOut(duration: 0.8).repeatForever(),
            value: isActive
        )
}
```

**Strategy C — Disable decorative animations entirely:**
```swift
// For LavaBubblesView — purely decorative, should disappear entirely with reduce motion
var body: some View {
    if !reduceMotion {
        LavaBubblesView()
    }
    // else: render nothing — the background colour alone is sufficient
}
```

Apply these strategies specifically to:

1. **`LavaBubblesView.swift`** — decorative only; use Strategy C (hide entirely when reduce motion is on)
2. **`ActivePlankRing.swift`** — functional (shows timer progress); use Strategy B (keep it, remove pulsing/looping animation, keep the progress arc)
3. **`CelebrationOverlayView.swift`** — decorative; use Strategy C or a simple fade-in (Strategy A)
4. **`CountdownOverlayView.swift`** — functional (user needs to see the countdown); use Strategy B (keep the number, remove scale/bounce animations)
5. **Pulsing glow `ViewModifier`** — find this modifier and gate the pulse animation behind `reduceMotion`
6. **Any `withAnimation { }` calls in `PlankTimerView.swift`** — wrap in `if !reduceMotion { withAnimation { } } else { /* direct state change */ }`

---

## Step 2 — Audit VoiceOver Labels on Custom Components

SwiftUI's default VoiceOver behaviour reads button labels and text from the view tree. However, custom-drawn components (rings, bubbles, calendar cells) have no inherent VoiceOver representation and will be ignored or read nonsensically.

Audit every file in `PlankChallenge/Components/` and apply `.accessibilityLabel()`, `.accessibilityHint()`, and `.accessibilityValue()` as appropriate:

**`ActivePlankRing.swift`**:
```swift
ActivePlankRing(progress: 0.6, elapsedSeconds: 62)
    .accessibilityLabel("Plank timer")
    .accessibilityValue("\(elapsedSeconds) seconds elapsed")
    .accessibilityHint("Double tap to stop the timer")
```

**`StreakCalendarView.swift`** — each calendar cell:
```swift
// Each day cell should be accessible
CalendarDayCell(date: date, hasPlank: true, isToday: true)
    .accessibilityLabel(
        isToday ? "Today" : date.formatted(.dateTime.weekday(.wide).day().month())
    )
    .accessibilityValue(hasPlank ? "Plank completed" : "No plank")
    .accessibilityAddTraits(hasPlank ? [.isSelected] : [])
```

**`StreakHeroView.swift`**:
```swift
// The streak number and label should read as a single meaningful unit
StreakHeroView(streak: 14)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Current streak: 14 days")
```

**`AvatarView.swift`**:
```swift
// If the avatar is decorative (e.g. in a list row where the name is also shown), hide it
AvatarView(url: url, size: 40)
    .accessibilityHidden(true) // decorative — the row's label already includes the name

// If the avatar is the primary identifier (e.g. tappable profile photo), label it
AvatarView(url: url, size: 80)
    .accessibilityLabel("\(userName)'s profile photo")
    .accessibilityHint("Double tap to change photo")
    .accessibilityAddTraits(.isButton)
```

**`LeaderboardRowView.swift`**:
```swift
// The whole row should read as a single accessible element
LeaderboardRowView(entry: entry)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("#\(entry.rank) \(entry.displayName), streak: \(entry.score) days")
    .accessibilityAddTraits(entry.isCurrentUser ? [.isSelected] : [])
```

**`UserRowView.swift`**:
```swift
UserRowView(user: user)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(user.displayName), \(user.location ?? "")")
```

**`StreakStatsRow.swift`** — each stat box:
```swift
// Each stat box (current streak, longest streak, freeze tokens) should be a distinct accessible element
StatBox(label: "Current Streak", value: "14")
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Current streak: 14 days")
```

**`CelebrationOverlayView.swift`**:
```swift
// Announce the celebration to VoiceOver users who can't see the animation
CelebrationOverlayView()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Plank complete! Great work.")
    .accessibilityAddTraits(.updatesFrequently)
```

---

## Step 3 — Audit VoiceOver on Screen Views

After fixing components, audit the screen views themselves. Pay attention to:

**`PlankTimerView.swift`** — the most critical screen:

1. The main plank button must have a label that changes with state:
```swift
Button(action: handleTap) {
    // ... visual content
}
.accessibilityLabel(accessibilityLabelForCurrentState)
.accessibilityHint(accessibilityHintForCurrentState)

private var accessibilityLabelForCurrentState: String {
    switch timerState {
    case .ready: return "Start plank"
    case .countdown(let n): return "Starting in \(n)"
    case .active: return "Plank in progress. \(formattedElapsedTime) elapsed"
    case .celebration: return "Plank complete"
    case .completedToday: return "Today's plank done. Tap to log another"
    }
}

private var accessibilityHintForCurrentState: String {
    switch timerState {
    case .ready: return "Double tap to begin your plank"
    case .active: return "Double tap to stop the timer"
    default: return ""
    }
}
```

2. The elapsed time display during an active plank should use `.accessibilityValue()` and post a VoiceOver announcement at key milestones (e.g. every 30 seconds) using `UIAccessibility.post(notification: .announcement, argument: "30 seconds")`:

```swift
.onChange(of: elapsedSeconds) { _, newValue in
    if newValue % 30 == 0 && newValue > 0 {
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(newValue) seconds"
        )
    }
}
```

3. The freeze token indicators on `ProfileView` should read meaningfully:
```swift
// Instead of just rendering N circles, provide context
HStack { /* freeze token circles */ }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Streak freeze tokens: \(freezeTokens) of 2 available")
```

**`StreakCalendarView` integration** — ensure the calendar as a whole has an accessibility label:
```swift
StreakCalendarView(activity: recentActivity)
    .accessibilityLabel("Plank activity calendar for \(currentMonthName)")
```

**`BadgesView.swift`** — each badge:
```swift
BadgeCell(badge: badge, isEarned: true)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(badge.displayName) badge, earned \(badge.dateEarned.formatted(.dateTime.day().month().year()))")

// Unearned badge:
BadgeCell(badge: badge, isEarned: false, progress: 0.6)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(badge.displayName) badge, 60% complete")
```

**`GroupDetailView.swift`** — member count and join button:
```swift
Button("Join Group") { ... }
    .accessibilityLabel("Join \(group.name)")
    .accessibilityHint("Double tap to request membership")
```

---

## Step 4 — Audit Minimum Tap Target Sizes

Apple's Human Interface Guidelines require interactive elements to have a minimum tap target of **44×44 points**. Custom components that are visually small but interactive must be expanded using `.contentShape()`.

Search for these patterns — small interactive elements that may be undersized:

1. **Avatar tap targets** in list rows — avatars are often 32–40pt visually but must be 44pt tappable
2. **Badge cells** in horizontal scroll views — visually compact but must be tappable
3. **Calendar day cells** in `StreakCalendarView` — often small grid cells
4. **Freeze token indicators** if they are tappable
5. **Close/dismiss buttons** on overlays (`CelebrationOverlayView`, `CountdownOverlayView`)
6. **Navigation chevrons** or secondary action buttons in list rows

For each undersized element, apply `.contentShape()` and ensure the frame is at least 44×44:

```swift
// Small visual element, expanded tap target
Image(systemName: "xmark")
    .frame(width: 24, height: 24)  // visual size
    .contentShape(Rectangle().size(CGSize(width: 44, height: 44)))  // tap target
    // or more simply:
    .frame(width: 44, height: 44)  // just make the frame 44×44 and center the content
```

For list rows in `LeaderboardRowView` and `UserRowView`, verify the row height is at least 44pt.

---

## Step 5 — Audit Dynamic Type Support

The app must remain usable at all Dynamic Type sizes, including the largest accessibility sizes (AX1–AX5). At large sizes, fixed-height containers clip text, horizontal layouts overflow, and icon-only buttons lose their labels.

**Search for fixed heights applied to containers that hold text:**

Search for `.frame(height:` in all view files. For each instance, determine whether the container holds text that could grow:
- If yes: replace with a minimum height using `.frame(minHeight:)` or remove the fixed height entirely
- If no (e.g. a decorative divider): leave as-is but add a comment

**Search for `HStack` layouts that may overflow at large sizes:**

In particular, audit:
- `StreakStatsRow.swift` — three stat boxes side by side; at AX5 sizes these may overflow or clip
- `LeaderboardRowView.swift` — rank + avatar + name + score in one row
- `UserRowView.swift` — avatar + name + location in one row
- `BadgesView.swift` — badge grid or scroll

For rows with multiple text elements side by side, consider using `ViewThatFits` to switch to a vertical layout at large sizes:

```swift
ViewThatFits(in: .horizontal) {
    // Preferred horizontal layout
    HStack {
        Text(displayName).font(.body)
        Spacer()
        Text("\(streak) days").font(.body)
    }
    // Fallback vertical layout for very large text
    VStack(alignment: .leading) {
        Text(displayName).font(.body)
        Text("\(streak) days").font(.caption)
    }
}
```

**Use `@ScaledMetric` for spacing and icon sizes** that should grow proportionally with text:

```swift
@ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 40
@ScaledMetric(relativeTo: .body) private var rowSpacing: CGFloat = 12
```

Apply `@ScaledMetric` to fixed sizes in `AvatarView`, `LeaderboardRowView`, and `UserRowView`.

---

## Step 6 — Audit Colour Contrast

The custom colour palette must meet WCAG AA contrast ratios:
- **Normal text** (below 18pt / 14pt bold): minimum **4.5:1** contrast ratio
- **Large text** (18pt+ / 14pt+ bold): minimum **3:1** contrast ratio
- **Interactive elements** (button borders, focus rings): minimum **3:1**

The areas most at risk in this app's palette:

1. **Deep blue plank screen** (`PlankTimerView`) — secondary text, the elapsed time display, and the "completed today" sub-text on the dark background
2. **Disabled state colours** — disabled buttons often use reduced-opacity text that falls below 4.5:1
3. **Streak calendar** — completed day cells vs. their background, and empty day cells vs. the calendar background
4. **Badge progress bars** — the progress fill colour against the track background
5. **Leaderboard** — the rank number colour against the row background, and the current-user highlighted row

**How to check**: open Xcode's Accessibility Inspector (`Xcode > Open Developer Tool > Accessibility Inspector`), navigate to the Colour Contrast calculator, and test each colour pair. Alternatively, derive the hex values from the `Color` extensions and check at [https://webaim.org/resources/contrastchecker/](https://webaim.org/resources/contrastchecker/).

For each failing colour pair, either:
- Darken the background or lighten the foreground text until the ratio passes
- Or switch to a higher-contrast system colour (e.g. `.primary`, `.secondary` which automatically adjust for light/dark mode and accessibility)

Document each colour pair you test and its result in a comment in the colour definition file.

---

## Step 7 — Audit Dark Mode & High Contrast Support

SwiftUI's adaptive system colours (`.primary`, `.secondary`, `Color(.systemBackground)`, etc.) handle dark mode automatically. Custom colour literals (`Color(#colorLiteral(...))` or `Color(red:green:blue:)`) do not.

Search the codebase for:
- `Color(red:` — static colour that does not adapt
- `Color(#colorLiteral` — static colour literal
- `UIColor(red:` — UIKit static colour

For each, replace with an adaptive colour defined using asset catalogue colour sets (which support light/dark variants) or a computed property that checks `colorScheme`:

```swift
// In Color+Extensions.swift or similar
extension Color {
    static var appPrimaryText: Color {
        Color("AppPrimaryText") // defined in Assets.xcassets with light/dark variants
    }
}
```

Also search for `.foregroundColor(.white)` and `.foregroundColor(.black)` — these do not adapt to dark mode. Replace with `.foregroundColor(.primary)` or a semantic custom colour.

**High Contrast**: SwiftUI does not automatically increase contrast for custom colours. Check `@Environment(\.colorSchemeContrast)` in components that use custom colours and provide higher-contrast alternatives where needed:

```swift
@Environment(\.colorSchemeContrast) var contrast

var textColor: Color {
    contrast == .increased ? .primary : .appSecondaryText
}
```

---

## Step 8 — Add Accessibility to the Design System Catalog

The Design System Catalog (`PlankChallenge/DesignSystem/`) should include an accessibility showcase that demonstrates every component in its accessible state. Add a new showcase file `PlankChallenge/DesignSystem/Showcases/AccessibilityShowcase.swift`:

```swift
#if DEBUG
import SwiftUI

struct AccessibilityShowcase: View {
    var body: some View {
        List {
            Section("Reduce Motion") {
                Text("Toggle Reduce Motion in Settings > Accessibility > Motion to see the static versions of animated components.")
                ActivePlankRingShowcase()
                LavaBubblesShowcase()
            }
            Section("VoiceOver Labels") {
                Text("Enable VoiceOver and navigate these elements to verify labels are meaningful.")
                LeaderboardRowView(entry: .mock)
                UserRowView(user: .mock)
                StreakHeroView(streak: 14)
            }
            Section("Dynamic Type") {
                Text("Change text size in Settings > Accessibility > Display & Text Size > Larger Text.")
                StreakStatsRow(current: 14, longest: 30, freezeTokens: 2)
            }
            Section("Colour Contrast") {
                // Show each colour pair with its contrast ratio documented
                ContrastSwatch(
                    foreground: .appPrimaryText,
                    background: .appBackground,
                    ratio: "12.4:1",
                    label: "Primary text on background"
                )
            }
        }
        .navigationTitle("Accessibility")
    }
}
#endif
```

---

## Step 9 — Final Verification Checklist

Before considering this quality check complete, confirm each of the following:

- [ ] `@Environment(\.accessibilityReduceMotion)` is read in `PlankTimerView`, `LavaBubblesView`, `CelebrationOverlayView`, `CountdownOverlayView`, `ActivePlankRing`, and any `ViewModifier` that applies looping/pulsing animations
- [ ] `LavaBubblesView` and `CelebrationOverlayView` are hidden entirely when Reduce Motion is on
- [ ] `ActivePlankRing` removes its pulsing animation but retains its progress arc when Reduce Motion is on
- [ ] `CountdownOverlayView` removes bounce/scale animations but retains the countdown number when Reduce Motion is on
- [ ] All custom components in `PlankChallenge/Components/` have `.accessibilityLabel()` set
- [ ] `ActivePlankRing` announces elapsed time milestones (every 30s) via `UIAccessibility.post(notification: .announcement)`
- [ ] The plank timer button label changes with timer state (ready / counting down / active / complete)
- [ ] Freeze token indicators on `ProfileView` read as "X of 2 tokens available"
- [ ] All interactive elements have a minimum 44×44pt tap target
- [ ] `StreakStatsRow` and `LeaderboardRowView` use `ViewThatFits` or `@ScaledMetric` to handle large Dynamic Type sizes without clipping
- [ ] `AvatarView` and icon sizes use `@ScaledMetric`
- [ ] Fixed-height containers that hold text use `minHeight` rather than exact height
- [ ] All custom colour pairs pass WCAG AA contrast ratios (4.5:1 for normal text, 3:1 for large text)
- [ ] No `.foregroundColor(.white)` or `.foregroundColor(.black)` on text outside of explicitly dark/light-only contexts
- [ ] Static `Color(red:green:blue:)` literals are replaced with adaptive colours
- [ ] Accessibility showcase added to the Design System Catalog
