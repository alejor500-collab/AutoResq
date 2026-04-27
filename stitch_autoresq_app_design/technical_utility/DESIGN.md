---
name: Technical Utility
colors:
  surface: '#fff8f7'
  surface-dim: '#f1d3d0'
  surface-bright: '#fff8f7'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#fff0ee'
  surface-container: '#ffe9e6'
  surface-container-high: '#ffe2de'
  surface-container-highest: '#fadcd8'
  on-surface: '#271716'
  on-surface-variant: '#5b403d'
  inverse-surface: '#3e2c2a'
  inverse-on-surface: '#ffedea'
  outline: '#906f6c'
  outline-variant: '#e4beb9'
  surface-tint: '#bb171c'
  primary: '#b7131a'
  on-primary: '#ffffff'
  primary-container: '#db322f'
  on-primary-container: '#fffbff'
  inverse-primary: '#ffb4ac'
  secondary: '#0060a8'
  on-secondary: '#ffffff'
  secondary-container: '#47a1ff'
  on-secondary-container: '#003663'
  tertiary: '#006578'
  on-tertiary: '#ffffff'
  tertiary-container: '#008097'
  on-tertiary-container: '#f9fdff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdad6'
  primary-fixed-dim: '#ffb4ac'
  on-primary-fixed: '#410002'
  on-primary-fixed-variant: '#93000d'
  secondary-fixed: '#d3e4ff'
  secondary-fixed-dim: '#a2c9ff'
  on-secondary-fixed: '#001c38'
  on-secondary-fixed-variant: '#004881'
  tertiary-fixed: '#afecff'
  tertiary-fixed-dim: '#72d4ef'
  on-tertiary-fixed: '#001f27'
  on-tertiary-fixed-variant: '#004e5d'
  background: '#fff8f7'
  on-background: '#271716'
  surface-variant: '#fadcd8'
typography:
  display-lg:
    fontFamily: Poppins
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.5px
  headline-md:
    fontFamily: Poppins
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: 0px
  title-lg:
    fontFamily: Poppins
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: 0px
  body-lg:
    fontFamily: Poppins
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0.15px
  body-md:
    fontFamily: Poppins
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.25px
  label-lg:
    fontFamily: Poppins
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-sm:
    fontFamily: Poppins
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.4px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  page_padding: 24px
  gutter: 16px
  app_bar_height: 64px
  bottom_bar_height: 80px
  stack_sm: 8px
  stack_md: 16px
  stack_lg: 24px
---

## Brand & Style
The design system is engineered for precision, speed, and reliability. Designed specifically for technical roles in the automotive assistance sector, the aesthetic balances the urgency of roadside rescue with the methodical nature of mechanical repair.

The style is **Corporate Modern** with a strong emphasis on utility and clarity. It utilizes high-contrast action colors against a clean, structured background to ensure legibility in high-stress or outdoor environments. Every interface element is designed to minimize cognitive load, allowing technicians to focus on the task at hand through a familiar, Flutter-inspired mobile language.

## Colors
The palette is functional and semantic. **Primary Red (#E53935)** is reserved for critical actions, branding, and emergency status indicators, demanding immediate attention. **Secondary Blue (#1E88E5)** serves as the technical anchor, used for navigation, information highlights, and secondary interactions to convey trust and expertise.

The background uses a pure white for maximum contrast, while the surface color provides subtle containment for cards and grouped content. A neutral grayscale is utilized for hierarchical text and structural borders to maintain a professional, de-cluttered environment.

## Typography
Poppins is the sole typeface for this design system, chosen for its geometric clarity and modern friendliness. 

- **Headlines** utilize heavier weights (600-700) to anchor pages and sections.
- **Body text** maintains a balanced 400 weight for readability in long-form technical logs.
- **Labels** leverage medium and semi-bold weights to ensure that even at small sizes (12px), metadata and status tags remain legible.
- **Line heights** are generous to accommodate rapid scanning on mobile devices.

## Layout & Spacing
This design system follows a strict **8px base grid** to ensure mathematical harmony across all screen sizes. The layout is fluid within the bounds of a **24px horizontal page padding**, providing a comfortable "breathable" margin for handheld use.

Structural components follow fixed vertical heights to maintain consistency:
- **AppBar:** 64px, featuring centered or start-aligned titles and prominent back actions.
- **BottomBar:** 80px, providing a large hit area for primary navigation icons and labels.
- Elements are stacked using increments of 8px (8, 16, 24) to create a clear vertical rhythm.

## Elevation & Depth
Depth in this design system is achieved through **Tonal Layers** and **Ambient Shadows**, mirroring the Material/Flutter behavior. 

- **Level 0 (Background):** #FFFFFF, used for the primary canvas.
- **Level 1 (Surface):** #F5F5F5, used for subtle grouping of content or background segments.
- **Level 2 (Cards):** Uses a very soft, diffused shadow (Y: 2px, Blur: 8px, Opacity: 8% Black) to lift content off the background without creating visual noise.
- **Level 3 (Overlays/FABs):** Uses a more pronounced shadow (Y: 4px, Blur: 12px, Opacity: 12% Black) to indicate high-priority interactive layers.

## Shapes
The shape language is distinct and purposeful, using varying radii to categorize component types:

- **Cards & Containers:** 16px radius. This provides a soft, professional look that frames content comfortably.
- **Inputs & Text Fields:** 24px radius. These "stadium-lite" shapes make form fields highly visible and distinct from structural cards.
- **Buttons:** Pill-shaped (9999px). This maximum roundness denotes high interactivity and follows modern mobile patterns for primary actions.

## Components

### Buttons
- **Primary:** Pill-shaped, Primary Red background, White text. High-emphasis for "Start Service" or "Accept."
- **Secondary:** Pill-shaped, Secondary Blue background or outline. Used for "Call Customer" or "Directions."
- **Tertiary:** Text-only with medium weight for low-priority actions like "Cancel" or "More Info."

### Cards
- White background with 16px corners and Level 2 elevation.
- 16px internal padding.
- Used for Service Requests, Vehicle Details, and Technical Logs.

### Inputs
- 24px corner radius with a #F5F5F5 fill and a 1px #E0E0E0 border.
- On focus, the border transitions to 2px Secondary Blue.
- Includes clear prefix/suffix icons for data types (e.g., VIN, License Plate).

### Status Chips
- Small, 12px rounded or pill shapes.
- Color-coded: Red (Urgent), Blue (In Progress), Gray (Pending).

### Lists
- Clean, edge-to-edge or inset cards with 16px vertical spacing.
- Use 24px leading icons or avatars for vehicle/tool identification.

### Technical Elements
- **Progress Steppers:** Thin 2px lines with Blue circular nodes to track repair stages.
- **Data Pairs:** Label (Secondary Text, Sm) stacked above Value (Primary Text, Md) for quick technical spec reading.