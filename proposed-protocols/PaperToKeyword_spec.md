# **Paper to Keywords (Text to Text)**

## **Goal**

Extract relevant keywords from lengthy scientific papers to highlight the main topics and key areas of focus.

---

## **Evaluation**

Keywords will be evaluated by human reviewers based on:  
- Relevance to the text.  
- Accuracy in capturing core topics and concepts.  
- Usefulness for understanding the paper's content.  

---

## **Actions**

### `getKeywords()`
- **Params**:  
  - `file` (file): File that contains the full text of the paper. Max size: 5MB.  
  - `keywordsCount` (int): Desired number of keywords. Maximum: 50.  

- **Returns**:  
  - `keywords` (array): An array of extracted keywords or phrases that represent the paper's main topics.  

---

## **Performance Requirements**
- Response within 60 seconds for files <2 MB.
- At least 200 API calls per subscription per month.

---

## **Constraints**
- Extracted keywords must be non-redundant and accurately reflect the paper's content.
- Prohibit processing of files with unsupported formats or encrypted content.
- Ensure keywords are generated in a language consistent with the paper's text.
