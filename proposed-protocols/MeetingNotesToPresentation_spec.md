# Meeting Notes to Presentation (Text to PPTX Slides)

## Goal

The goal of this subnet is to convert meeting notes into a structured slide deck with properly formatted headings, bullet points, and key insights. The generated slides should be coherent, visually appealing, and logically structured, reducing the manual effort required for presentation creation.

## Evaluation

Responses will be evaluated based on:

✅ Content Accuracy: Extracted points should accurately reflect the meeting notes.
✅ Logical Flow: The slide deck should follow a clear, structured order.
✅ Formatting Consistency: Titles, subtitles, and bullet points should be correctly formatted.
✅ Visual Appeal: Well-balanced slide designs with appropriate font sizes, spacing, and themes.

Additional automated scoring criteria:

- Text Coherence Score (TCS): Measures how well the slides maintain logical consistency.
- Readability Index (RI): Assesses how easy the slides are to read and understand.
- Keyword Coverage (KC): Checks if key points from the meeting notes are included in the slides.

## Actions

### `convertNotesToSlides()`

- **Params**:
  
  - `notes` (string, max 10,000 chars): Raw meeting notes to be converted.
  - `style` (string, optional): Choose from corporate, casual, or minimalist.
  
- **Returns**:

  - **`slides`** (PowerPoint/PDF file): The generated slide deck.
  
### `customizeSlideDesign()`

- **Params**:

  - `theme` (string, optional): Choose from dark, light, or classic.
  - `font_size` (integer, optional): Set the default font size for slides.

- **Returns**:
  - **`custom_slides`** (PowerPoint/PDF file): A restructured version of the slides with updated design.
  
## Performance Requirements

- **Response Times**:
  - `convertNotesToSlides()`: Must return slides within 30 seconds for up to 20 slides.
  - `customizeSlideDesign():` Must apply style changes within 5 seconds.
  
- **Rate Limits**:
  - Minimum of 2 requests per minute.
  - At least 200 API calls per subscription per month.
  