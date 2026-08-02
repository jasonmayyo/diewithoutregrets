#!/bin/bash
#
# design-lint.sh — keeps the design system honest.
#
# Fails when feature code bypasses SGTheme: hardcoded colors, inline fonts,
# raw haptic generators, or numeric corner radii outside the DesignSystem
# folder. Debug-only files and known legacy files still awaiting migration
# live in the allowlist below; shrink it as phases land, never grow it.
#
# Usage: scripts/design-lint.sh          (report + exit 1 on violations)
#        scripts/design-lint.sh --count  (counts only, always exit 0)

set -uo pipefail
cd "$(dirname "$0")/.."

APP_DIR="diewithoutregrets"
COUNT_ONLY="${1:-}"

# Files allowed to violate, with reasons. Shrink over time.
ALLOWLIST=(
  "$APP_DIR/DesignSystem/"                 # the token/component layer itself
  "$APP_DIR/Resources/ColorExtension.swift" # the Color(hex:) initializer
  "$APP_DIR/ContentView.swift"             # DebugView (DEBUG-only sections)
  "$APP_DIR/DesignSystem/SGPreviewHarness.swift"
  # ---- Sanctioned art palettes (brand tints, life-grid, moon) ----
  "$APP_DIR/Features/Onboarding/Views/OnboardingV2Components.swift" # illustration palettes only; chrome is tokenized
  "$APP_DIR/Features/Onboarding/Views/ProcrastinationStudyView.swift" # moonBlue illustration one-off
  "$APP_DIR/Features/StudyGuard/Views/StudyGuardDebugSection.swift" # debug-only
  "$APP_DIR/NotificationManager.swift"
)

is_allowed() {
  local file="$1"
  for entry in "${ALLOWLIST[@]}"; do
    [[ "$file" == "$entry"* ]] && return 0
  done
  return 1
}

declare -a PATTERNS=(
  'Color(hex:|Hardcoded hex color: use an SGTheme token'
  'Color\(red:|Hardcoded RGB color: use an SGTheme token'
  '\.font\(\.system\(size:|Inline font: use an SGTheme type role'
  'UIImpactFeedbackGenerator|Raw haptic: use the SGTheme haptic grammar'
  'UINotificationFeedbackGenerator|Raw haptic: use the SGTheme haptic grammar'
  'cornerRadius: [0-9]|Numeric radius: use SGTheme.tileRadius/cardRadius/sheetRadius'
  '\.cornerRadius\([0-9]|Deprecated numeric cornerRadius: use a shaped background'
)

violations=0
for entry in "${PATTERNS[@]}"; do
  pattern="${entry%%|*}"
  message="${entry#*|}"
  while IFS= read -r line; do
    file="${line%%:*}"
    is_allowed "$file" && continue
    # Sanctioned numeric radii: 10 (icon tiles) and <=2 (particle art).
    case "$line" in
      *"cornerRadius: 10"*|*"cornerRadius: 2)"*) continue ;;
    esac
    if [[ "$COUNT_ONLY" != "--count" ]]; then
      echo "DESIGN-LINT: $line"
      echo "             ^ $message"
    fi
    violations=$((violations + 1))
  done < <(grep -rEn "$pattern" "$APP_DIR" --include='*.swift' 2>/dev/null)
done

echo "design-lint: $violations violation(s) outside the allowlist"
if [[ "$COUNT_ONLY" == "--count" ]]; then
  exit 0
fi
[[ $violations -eq 0 ]] || exit 1
exit 0
