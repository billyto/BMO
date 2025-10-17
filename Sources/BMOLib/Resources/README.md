# Custom Menu Bar Icon

To use a custom icon for the menu bar, place your icon file in this directory with one of these names:

- `menubar-icon.pdf` (recommended - vector format, scales perfectly)
- `menubar-icon.png` (16x16 to 18x18 pixels recommended)

## Icon Requirements

1. **Size**: 16-18 pixels square for PNG, any size for PDF
2. **Color**: Black and transparent only
   - The system will automatically colorize the icon based on the menu bar appearance
   - Do NOT use colors in your icon - they will look wrong in light/dark mode
3. **Style**: Simple, monochromatic silhouette design
   - Think of SF Symbols style - clean, minimal, recognizable at small sizes

## Design Tips

- Keep it simple - complex details won't be visible at menu bar size
- Use solid shapes, not thin lines
- Test in both light and dark mode
- Look at other menu bar icons for inspiration

## Tools for Creating Icons

- **Vector (PDF)**: Sketch, Figma, Adobe Illustrator, Affinity Designer
- **Raster (PNG)**: Preview (built-in), Photoshop, Pixelmator

## If No Icon Is Found

If no custom icon is found in this directory, the app will use the default SF Symbol "service.dog" (🐕‍🦺).
