# Text to Summary (Text to Text)

## Goal

Summarize lengthy block of text (scientific papers, emails, articles) into concise abstracts while retaining key insights.

## Evaluation

Text responses will be evaluated by human reviewers.

Summaries are assessed for:
  - Coverage of main points.
  - Accuracy and lack of misinterpretation.
  - Coherence and conciseness.

## Actions

### `summarize()`
- **Params**:
  - `text` (string): Full text of the paper. Max 30,000 characters.
  - `summaryLength` (int): Desired summary length in words.

- **Returns**:
  - `summary`: Text summary of the paper.

## Performance Requirements
- Response within 60 seconds for papers <10,000 words.
- At least 200 API calls per subscription per month.

## Constraints
- Summaries must avoid bias and adhere to ethical reporting standards.
- Avoid redundancy or introducing errors in meaning.