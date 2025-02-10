# Code to Cybersecurity Report (Code to Security Check)

## Goal

This subnet analyzes a piece of source code and generates a cybersecurity vulnerability report, highlighting weaknesses and possible fixes.

## Evaluation

Responses will be evaluated based on:

✅ Accuracy in detecting security risks.
✅ Severity ranking for vulnerabilities.
✅ Clarity of explanations and recommendations.

Additional automated scoring criteria:

- Security Risk Index (SRI): Measures the overall risk level of the code.
- False Positive Rate (FPR): Ensures minimal false alarms.
- Exploitability Score (ES): Rates how easily a vulnerability can be exploited.

## Actions

### `codeToSecurityReport()`

- **Params**:
  
  - `code` (string, max 5000 chars): Source code snippet.
  - `language` (string): Choose from Python, JavaScript, etc.
  
- **Returns**:

  - **`report`** (JSON): List of vulnerabilities and recommended fixes.
  
## Performance Requirements

- **Response Times**:
  - `codeToSecurityReport()`: Must return a report within 15 seconds.
  
- **Rate Limits**:
  Minimum 5 requests per minute.
  