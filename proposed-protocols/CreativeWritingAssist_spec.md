# Creative Writing Companion (Text to Text)

## Goal

Given a prompt describing a story, theme, or concept, the model should generate a high-quality, engaging short story or narrative piece. The goal is to maximize creativity, coherence, and entertainment value while staying true to the prompt's context and tone.

## Evaluation

Responses will be evaluated by human reviewers for creativity, coherence, and adherence to the given prompt. The story should be engaging and well-written, with logical progression and consistent tone. Stories deviating significantly from the prompt or containing factual errors that contradict the provided context will receive lower scores.

Additional automated scoring criteria:
- Grammar and spelling accuracy
- Unique and compelling narrative structure
- Adherence to the specified word count

## Actions

### `generateStory()`
- **Params**:
  - `prompt` (string): Description of the story idea, theme, or concept. Max 3000 characters.
  - `length` (integer): Approximate word count for the story. Min 300, Max 5000.
- **Returns**:
   - `text`: A well-structured story as a single string.
   - The response must adhere to the specified word count within a margin of ±10%.
   - Text must be UTF-8 encoded and <1MB in size.

### `refineStory()`
- **Params**:
  - `draft` (string): A draft story provided by the user for improvement. Max 5000 words.
  - `instructions` (string): Specific guidance for refining the draft (e.g., improve pacing, add dialogue, fix plot inconsistencies).
- **Returns**:
   - `text`: A revised version of the draft with improvements based on the instructions.

## Performance Requirements
- Query response within 60 seconds for `GenerateStory()` and 90 seconds for `RefineStory()`.
- Rate limit of at least 2 requests per minute.
- Minimum 200 API calls per subscription per month.

## Constraints
- The generated stories must not exceed a PG-13 rating in terms of content.
- All stories must be original and not contain plagiarized text.