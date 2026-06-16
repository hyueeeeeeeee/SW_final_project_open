const https = require('https');

const data = JSON.stringify({
  data: {
    externalCalendar: []
  }
});

const req = https.request({
  hostname: 'asia-east1-fretwise-6ceb6.cloudfunctions.net',
  path: '/updatePlan',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
}, (res) => {
  let body = '';
  res.on('data', (d) => body += d);
  res.on('end', () => console.log('Response:', res.statusCode, body));
});

req.on('error', console.error);
req.write(data);
req.end();
