# Text to Image Generation (Text to Image)

## Goal

Given a textual description, the model should generate a high-quality image that accurately represents the provided text. The goal is to maximize visual fidelity, creativity, and relevance to the text prompt.

## Evaluation

Image responses will be evaluated by human reviewers for relevance, visual quality, and creativity. The image should accurately reflect the text description, be visually appealing, and demonstrate creative interpretation of the prompt.

Additional automated scoring criteria:
- Image resolution and clarity
- Adherence to the specified dimensions and file size
- Originality and absence of artifacts

## Actions

### `generateImage()`
- **Params**:
  - `prompt` (string): Description of the image to be generated. Max 3000 characters.
  - `format` (**ImageFormat**) – The desired image format. Allowed values:
    - `"PNG"`
    - `"JPEG"`

- **Returns**:
  - `image`: A generated image as a single file.
    - Image must be in PNG or JPEG format.
    - Image must be <1MB in size.
    - Image must be 1024 x 1024 pixels. 

## Performance Requirements
- Query response within 60 seconds.
- Rate limit of at least 2 requests per minute.
- Minimum 200 API calls per subscription per month.

## Constraints
- The generated images must not contain explicit, harmful, or inappropriate content.
- All images must be original and not contain plagiarized elements.
