# **Summary to Email (Text to Text)**

## **Goal**

Transform a concise summary (1-2 sentences) into a full-sized, well-structured email tailored to a specified tone and audience.  

---

## **Evaluation**

Emails will be evaluated by human reviewers based on:  
- Relevance to the provided summary.  
- Proper structuring and logical flow.  
- Alignment with the specified tone (business, mentoring, or casual).  
- Clarity and conciseness.  

---

## **Actions**

### `generateEmail()`
- **Params**:  
  - `summary` (string): A concise summary (1-2 sentences) of the content. Max length: 2000 characters.  
  - `tone` (string): Desired tone of the email. Options: `"business"`, `"mentoring"`, `"casual"`.  
  - `emailLength` (int): Desired maximum length of the generated email in characters. Maximum: 5000.  

- **Returns**:  
  - `email` (string): The generated email text based on the provided summary and tone.  

---

## **Performance Requirements**
- Response within 15 seconds for summaries <500 characters.  
- At least 200 API calls per subscription per month.  

---

## **Constraints**
- Emails must adhere to the specified tone and maintain professional or appropriate language.  
- Ensure the generated content aligns with the original intent and does not introduce inaccuracies.  
- Avoid overly verbose or redundant content, adhering to the `emailLength` parameter.  
- Generated emails must avoid harmful, biased, or unethical content.
