const fs = require('fs');
let code = fs.readFileSync('index.js', 'utf8');

// Ensure generationConfig is passed
code = code.replace(
  /model: "gemini-1.5-flash",\n\s*systemInstruction: AGENT_SYSTEM_PROMPT,\n\s*\}\);/,
  'model: "gemini-1.5-flash",\n        systemInstruction: AGENT_SYSTEM_PROMPT,\n        generationConfig: { maxOutputTokens: 8192, temperature: 0.2 }\n      });'
);

fs.writeFileSync('index.js', code);
