# Paper to Summary (Text to Text)

## Goal

Summarize lengthy scientific papers into concise abstracts while retaining key insights.

## Evaluation

Text responses will be evaluated by human reviewers.

Summaries are assessed for:
  - Coverage of main points.
  - Accuracy and lack of misinterpretation.
  - Coherence and conciseness.
  - Professional tone.

## Actions

### `getSummary()`
- **Params**:
  - `file` (file): File that contains full text of the paper. Max 5MB.
  - `summaryLength` (int): Desired summary length in characters. Max 2000.

- **Returns**:
  - `summary`: Text summary of the paper.

## Performance Requirements
- Response within 60 seconds for files <2 MB.
- At least 200 API calls per subscription per month.

## Constraints
- Summaries must avoid bias and adhere to ethical reporting standards.
- Avoid redundancy or introducing errors in meaning.
- Prohibit processing of files with unsupported formats or encrypted content.
