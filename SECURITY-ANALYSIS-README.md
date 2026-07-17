# Security Analysis — iOS Custom Keyboard Projects

**Scope:** Comparative security review of three iOS keyboard codebases.
**Date:** 2026-07-17

| Folder | What it actually is | Language | "Secure"? |
|--------|--------------------|----------|-----------|
| `Custom-iOS-Keyboards-master` | Punjabi **language** input view (QWERTY-style) | Objective-C (2012) | Not a security product — never claimed to be |
| `securekeyboad-ios-lite` | Numeric keypad ("Kona Secure Keyboard") | Objective-C (2017) | **Marketed as secure, but is NOT** |
| `keyboard-master` | Secure PIN entry keyboard + SPM package | Swift (2026) | **Yes — genuinely hardened** |

**Bottom line:** `keyboard-master` is the only one of the three that is actually secure. `securekeyboad-ios-lite` calls itself a "Secure Keyboard" but its core protection (randomized layout) is **disabled in code**, and it routes the PIN through a normal, non-masked `UITextField`. `Custom-iOS-Keyboards-master` is an unrelated language keyboard and is the ancestor that the "lite" project was forked from.

---

## 1. Are `Custom-iOS-Keyboards-master` and `securekeyboad-ios-lite` the same implementation?

**No — but the "lite" project is a fork/derivative of `Custom-iOS-Keyboards-master`.** They are not the same, yet they share a common ancestor. The evidence is concrete:

**Shared DNA (proves the fork):**
- `securekeyboad-ios-lite`'s `KonaCustomKeyboard.m` still carries the header **`Copyright © 2017 Kulpreet Chilana`** — Kulpreet Chilana is the original author of `Custom-iOS-Keyboards-master` (2012).
- The `+ (UIImage *) imageFromColor:(UIColor *)color` helper is **copied verbatim** into `KonaCustomKeyboard.m` (`KonaCustomKeyboard.m:264`) from `PMCustomKeyboard.m:371`.
- Identical patterns: nib loading via `loadNibNamed:owner:options:`, `enableInputClicksWhenVisible`, `[[UIDevice currentDevice] playInputClick]`, the `setTextView` / `insertText:` / `deleteBackward` input plumbing, and the `UIInputViewAudioFeedback` conformance.

**How they differ:**

| | `Custom-iOS-Keyboards-master` (`PMCustomKeyboard`) | `securekeyboad-ios-lite` (`KonaCustomKeyboard`) |
|---|---|---|
| Purpose | Full **Punjabi alphabet** keyboard (shift / alt / diacritics) | 12-key **numeric** keypad (0–9, Del, Done) |
| Keys | 30 character keys + shift/alt/space/return | Digits + Del + Done |
| "Security" intent | None — it's a language IME | Claims to be a "Secure Keyboard" |
| Extra code | Custom key-pop drawing, gradients | `NSMutableArray+Shuffle` category, `KeyboardConfiguration` |

**Conclusion:** Different implementations serving different purposes, but `securekeyboad-ios-lite` was clearly built by stripping `Custom-iOS-Keyboards-master` down to a numeric keypad and bolting on a (disabled) shuffle feature. They are **not identical**, and `Custom-iOS-Keyboards-master` itself has **no security features** — it was never designed as a secure keyboard.

---

## 2. Is `securekeyboad-ios-lite` really secure?

**No. Despite the name "Secure Keyboard," it provides essentially no meaningful security.** The one feature that could make it secure is turned off in source, and the PIN is handled through the standard visible text path.

### Critical findings

**2.1 — The randomized layout is HARD-DISABLED.**
The entire security premise of this keyboard (per its own developer guide: *"layout changes randomly each time a keyboard pops up"*) depends on shuffling. But in `KonaCustomKeyboard.m:18`:

```objc
bool doShuffle = NO;
```

And the only place it is read (`KonaCustomKeyboard.m:338`):

```objc
if (doShuffle ){
    [numberKeypadChars shuffle];
}
```

`doShuffle` is **never set to `YES` anywhere in the codebase.** The keypad therefore always renders in fixed order `1 2 3 4 5 6 7 8 9 Del 0 Done`. The advertised anti-shoulder-surfing / anti-smudge protection **does not run**. The `shuffle` method exists but is dead code.

**2.2 — The PIN goes into a normal, non-masked `UITextField` in plaintext.**
Digits are inserted with `[self.textView insertText:character]` (`KonaCustomKeyboard.m:233`) into a standard `UITextField`. The demo storyboard fields have **no `isSecureTextEntry`**, so the typed digits are displayed on screen as clear numbers and stored in the field's `NSString`. There is:
- No dot masking.
- No secure byte buffer — the value lives in a Swift/Obj-C `String`/`NSString`, which is copied and lingers in memory.
- No memory zeroing / clearing.

**2.3 — Digit value is stored in `UIButton.tag` and shown as the button title.**
`[keyboardButton setTag:[element intValue]]` (`KonaCustomKeyboard.m:371`). Storing the secret digit in the tag is exactly the anti-pattern the secure project (`keyboard-master`) explicitly avoids.

**2.4 — No screen-capture, screenshot, or lifecycle protection.**
There is no handling of `UIScreen.capturedDidChangeNotification`, `userDidTakeScreenshotNotification`, backgrounding, or device lock. Nothing hides or clears input during capture.

**2.5 — Verbose logging of input state.**
15 `NSLog` calls remain, including `NSLog(@"Clicked %d", i)` on every key press (`KonaCustomKeyboard.m:190`) and button-title logging. These leak UI/interaction detail to the device console and should never ship in a "secure" component.

**2.6 — A functional bug that also reveals the design.**
Digit insertion is gated on `selectedTextFieldDelegate != NULL` (`KonaCustomKeyboard.m:226`). The shipped demo registers fields with the single-argument `registerTextField:` (`ViewController.m:33`), which sets `selectedTextFieldDelegate = NULL` (`KonaCustomKeyboard.m:392`). As wired, **typing a digit does nothing** — confirming this code is a rough prototype, not a vetted secure product.

### Verdict
`securekeyboad-ios-lite` is **not secure**. Its only real property is "does not use the iOS system keyboard." Every other claimed protection is either disabled (`doShuffle = NO`), absent (masking, clearing, capture protection), or actively counter to good practice (digit in `tag`, plaintext field, console logging).

---

## 3. `securekeyboad-ios-lite` vs `keyboard-master` — which is secure?

**`keyboard-master` wins decisively.** It implements the exact protections that `securekeyboad-ios-lite` only advertises.

| Security property | `securekeyboad-ios-lite` | `keyboard-master` |
|---|---|---|
| Avoids system keyboard (no 3rd-party keylogger) | ✅ Yes | ✅ Yes |
| Randomized digit layout | ❌ **Disabled** (`doShuffle = NO`) | ✅ On appear **and** after every tap (`shuffle()`) |
| CSPRNG for shuffle | — (never runs) | ✅ `SystemRandomNumberGenerator` |
| PIN masked on screen (dots, never digits) | ❌ Shown in plaintext field | ✅ `PinInputView` renders dots only |
| PIN kept out of `UITextField`/`String` | ❌ Stored in `UITextField.text` | ✅ Fixed-size `[UInt8]` `SecurePinBuffer` |
| Memory zeroed after use | ❌ No | ✅ `memset` zeroize + `deinit` clear |
| Constant-time PIN comparison | ❌ No | ✅ `constantTimeEquals` |
| Digit NOT stored in `UIButton.tag` | ❌ Stored in tag | ✅ Uses `ObjectIdentifier` map; `tag = -1` |
| Identical pressed-state (no visual key feedback) | ❌ Highlight color set | ✅ `.custom` button, same normal/highlighted |
| Digit hidden from accessibility metadata | ❌ No | ✅ `isAccessibilityElement = false` on keys |
| Screenshot / screen-recording protection | ❌ None | ✅ `ScreenCaptureProtectedView` + notifications |
| Clears on screenshot / capture / lock / background | ❌ None | ✅ Full lifecycle observers |
| Console logging of input | ❌ 15× `NSLog`, logs every tap | ✅ None |
| Code maturity | Prototype (input path broken as shipped) | Production-shaped, documented, SPM-packaged |

**Winner: `keyboard-master`.** It is the genuinely secure implementation. `securekeyboad-ios-lite` is secure in name only.

---

## 4. Security issues in `keyboard-master`

`keyboard-master` is well-built and follows sound practices. It has **no critical vulnerabilities**, but the review surfaced **residual risks and minor issues** worth addressing. (Note the project ships in two copies: the SPM package under `Sources/SecurePINKeyboard/` and an app copy under `keyboard/keyboard/` — keep them in sync.)

### Medium

**4.1 — Screenshot protection relies on undocumented `UITextField` internals and fails open silently.**
`ScreenCaptureProtectedView` obtains its protected render surface via `secureTextField.subviews.first` (`ScreenCaptureProtectedView.swift:52`) — the private view backing `isSecureTextEntry`. Apple does not guarantee this subview's existence or position; a future iOS release can change it. When that happens the code calls `installUnprotectedFallback()` and **content is hosted with no capture protection, with no signal to the app or user.** Recommendation: detect the fallback path and surface it (e.g., disable secure entry, warn, or refuse) rather than degrading silently.

**4.2 — The completed PIN is handed off as a non-zeroed `[UInt8]`.**
`copyPINBytes()` returns a plain `[UInt8]` (`SecurePINBuffer.swift:45`) to `didCompleteWith:`. The internal buffer is zeroed, but this returned array's lifetime and clearing are entirely the caller's responsibility, and a Swift `Array` is not zeroed on release. The README notes "do not log/store," but the memory-hygiene guarantee ends at the boundary. Recommendation: document explicitly that the caller must zero the array, or hand back a self-clearing wrapper.

### Low / hardening

**4.3 — Screenshot clearing is inherently after-the-fact (iOS limitation).**
`userDidTakeScreenshotNotification` fires *after* the screenshot is captured. `clearsOnScreenshot` clears input post-capture, so a PIN mid-entry can be in the screenshot. This is an OS constraint, not a code defect — the `ScreenCaptureProtectedView` surface is the real mitigation, which is why 4.1 matters. The README does disclose this honestly.

**4.4 — App-copy vs package-copy drift.**
`keyboard/keyboard/` (the demo app) and `Sources/SecurePINKeyboard/` contain near-duplicate files (`SecurePinBuffer` vs `SecurePINBuffer`, `SecureKeyboardView` vs `SecurePINKeyboardView`, etc.) that have already diverged slightly (e.g., `capacity < 256` in the app vs `<= 12` in the package). Duplicated security code risks fixing a bug in one copy but not the other. Recommendation: have the app depend on the package instead of vendoring copies.

**4.5 — `capacity < 256` allows unbounded-ish buffers in the app copy.**
`SecurePinBuffer.init` in the app uses `precondition(capacity > 0 && capacity < 256)` (`keyboard/keyboard/SecurePinBuffer.swift:19`), while the package correctly clamps to `<= 12`. Not exploitable (callers pass 4), but the package's tighter bound is the better invariant; align them.

### Confirmed good (no action needed)
- CSPRNG-based shuffle, per-tap re-randomization.
- Constant-time comparison with length mixed in.
- No `print`/`NSLog` of PIN or taps anywhere in the Swift sources.
- Digit→button mapping via `ObjectIdentifier`, not `tag`; keys excluded from accessibility.
- Buffer zeroed on `removeAll`/`deinit`; PIN never enters a `String` or `UITextField`.
- Privacy observers for capture, screenshot, protected-data, resign-active, with an input-locking privacy shield.

---

## Recommendations

1. **Do not ship `securekeyboad-ios-lite` as a security control.** At minimum, if it must be used: set `doShuffle = YES`, enable `isSecureTextEntry` on its fields (or mask input), strip all `NSLog` calls, stop storing digits in `UIButton.tag`, and add capture/lifecycle clearing. Realistically, prefer `keyboard-master`.
2. **Standardize on `keyboard-master`** for any PIN/secure entry. It already implements what the "lite" project only promises.
3. In `keyboard-master`, address 4.1 (fail-closed on lost screenshot protection) and 4.4/4.5 (de-duplicate the app and package copies), and document the caller's obligation to zero the returned PIN bytes (4.2).
4. Treat `Custom-iOS-Keyboards-master` purely as a language-input keyboard; it has no place in a secure-entry flow.

---

*Files reviewed: `PMCustomKeyboard.{h,m}`; `KonaCustomKeyboard.{h,m}`, `NSMutableArray+NSMutableArray_Shuffle.m`, `KeyboardConfiguration.{h,m}`, `ViewController.m`; `SecurePIN*.swift`, `SecureKeyboardView.swift`, `PinInputView.swift`, `SecurePinBuffer.swift`, `ScreenCaptureProtectedView.swift`, `DashboardViewController.swift`, plus both projects' documentation.*
