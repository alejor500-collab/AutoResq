# Design System Strategy: The Kinetic Calm

## 1. Overview & Creative North Star
In the context of emergency automotive assistance in Riobamba, the user is often in a state of high cognitive load and physical stress. Our Creative North Star is **"The Kinetic Calm."** 

This system must feel as authoritative and stable as a premium Swiss timepiece, yet move with the urgent fluidity of a high-end digital concierge. We are moving beyond the "flat app" look by utilizing editorial spacing, intentional asymmetry, and a sophisticated layering of whites and greys. By prioritizing "breathing room" over traditional UI density, we ensure that in a moment of crisis, the user’s eyes are guided instinctively to the solution.

## 2. Colors & Surface Architecture
We do not use color to decorate; we use color to direct. The palette is rooted in a "High-Value Neutral" philosophy.

### The Palette (Material Logic)
*   **Surface:** `#f9f9fb` (The primary canvas)
*   **Primary (Emergency):** `#bb020f` (The focal point for critical action)
*   **On-Surface (Text):** `#1a1c1d` (The authoritative charcoal)
*   **Secondary:** `#5f5e60` (For navigational meta-data)

### The "No-Line" Rule
Explicitly prohibit 1px solid borders for sectioning. Boundaries must be defined solely through background color shifts or subtle tonal transitions.
*   **Example:** A `surface-container-low` button should sit on a `surface` background without a stroke. The distinction is made through value, not lines.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers. 
*   **Level 0 (Background):** `surface` (`#f9f9fb`)
*   **Level 1 (Sections):** `surface-container-low` (`#f3f3f5`)
*   **Level 2 (Active Cards):** `surface-container-highest` (`#e2e2e4`)
*   **Level 3 (Floating Elements):** `surface-container-lowest` (`#ffffff`) with Glassmorphism.

### The Glass & Gradient Rule
To achieve a "signature" feel, floating headers and action sheets must use **Glassmorphism**. Apply a `backdrop-blur(20px)` to semi-transparent versions of `surface-container-lowest`. For the primary `primary-container` (`#e02a25`), use a subtle linear gradient (135°) transitioning to `primary` (`#bb020f`) to give the button a "weighted" feel that flat hex codes lack.

## 3. Typography: Editorial Authority
We utilize **Inter** not just for legibility, but as a structural element. 

*   **Display Scale (Crisis Context):** `display-md` (2.75rem) is used for status updates (e.g., "Help is 8 mins away"). 
*   **Headline/Title:** Use `headline-sm` (1.5rem) for step-by-step instructions. This creates an "Editorial" feel where the app speaks to the user with clarity.
*   **Body:** `body-lg` (1rem) is the workhorse. It must always have a line-height of at least 1.5 to maintain the "Calm" in the North Star.
*   **Labels:** `label-md` (0.75rem) should be used in All Caps with +0.05em tracking for secondary metadata like "LICENSE PLATE" or "LOCATION COORDINATES."

## 4. Elevation & Depth: Tonal Layering
Traditional drop shadows are forbidden. We achieve depth through **Ambient Luminescence.**

*   **The Layering Principle:** Place a `surface-container-lowest` (#ffffff) card on a `surface-container-low` (#f3f3f5) section. This creates a soft, natural lift that feels like physical paper.
*   **Ambient Shadows:** For floating primary actions (e.g., the "Request Tow" pill), use a shadow with a 40px blur, 0px offset, and 6% opacity of the `on-surface` color. It should feel like a glow, not a shadow.
*   **The "Ghost Border" Fallback:** If a border is required for accessibility in input fields, use the `outline-variant` token at **15% opacity**. Never use 100% opaque strokes.

## 5. Components

### Pill-Shaped Buttons
*   **Primary:** `primary` fill, `on-primary` text. Height: 56px. 
*   **Secondary:** `surface-container-high` fill, `on-surface` text.
*   **Interaction:** On press, the button should scale down to 98% rather than changing color, mimicking a physical depress.

### Emergency Step-Cards
*   **Structure:** No dividers. Use `body-lg` for the task and `body-sm` (Secondary color) for the description. 
*   **Spacing:** 24px internal padding. 16px gap between cards.
*   **Visual Cue:** Use a `tertiary` (`#00628b`) small dot or icon to indicate the "Current Step" to differentiate from the "Red" emergency state.

### Input Fields
*   **Style:** `surface-container-low` background. 
*   **Shape:** `md` (1.5rem) corner radius.
*   **Feedback:** The cursor should be the `primary` red. When focused, the background shifts to `surface-container-lowest` (white) to "pop" toward the user.

### Lists & Cards
*   **The No-Divider Rule:** Forbid 1px dividers. Use a 16px vertical gap between list items or shift the background color of alternating items by 2% (Tonal striping).

## 6. Do’s and Don’ts

### Do
*   **Do** use asymmetrical padding in Hero sections (e.g., 32px left, 16px right) to create a modern, editorial look.
*   **Do** use "Optical Rounding" for all corners (Apple-style squircle logic).
*   **Do** prioritize the `primary` red only for the final "Request" action and active "Danger" statuses.

### Don't
*   **Don't** use pure black (#000000) for text. Use `on-surface` (`#1a1c1d`) to maintain visual softness.
*   **Don't** use standard "Modal" popups that cover the whole screen. Use "Bottom Sheets" that allow the background context of the map to remain visible.
*   **Don't** use icons without labels in an emergency context. Clarity over minimalism.