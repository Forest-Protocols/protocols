# Blueprint to 3D Model (Sketch to 3D)

## Goal

This subnet aims to convert blueprints, hand-drawn sketches, or simple CAD drawings into detailed 3D models. The goal is to enable quick visualization of architectural, product, or mechanical designs.

## Evaluation

Responses will be evaluated based on:

✅ Structural Accuracy: The 3D model should correctly represent the original sketch.
✅ Rendering Quality: The model should be free of graphical artifacts.
✅ Material & Texture Fidelity: If provided, material properties should be correctly applied.

Additional automated scoring criteria:

- Model Fidelity Score (MFS): Compares the blueprint and 3D model similarity.
- Structural Integrity Index (SII): Ensures realistic structural proportions.
- Rendering Speed (RS): Measures the speed of generating 3D outputs.

## Actions

### `convertBlueprintTo3D()`

- **Params**:
  
  - `blueprint_image` (file, max 10MB): Image file of the blueprint.
  - `format` (string, optional): Choose OBJ, STL, FBX.
  
- **Returns**:

  - **`3d_model`** (file): Downloadable 3D model file.
  
### `applyTextures()`

- **Params**:

  - `texture_type` (string, optional): Choose from metal, wood, plastic, or glass.
  - `textured_3d_model` (file): A 3D model with applied textures.

- **Returns**:
  - **`custom_slides`** (PowerPoint/PDF file): A restructured version of the slides with updated design.
  
## Performance Requirements

- **Response Times**:
  - `convertBlueprintTo3D()`: Must generate a model within 2 minutes.
  
- **Rate Limits**:
  - Minimum 3 requests per minute.
  