#!/usr/bin/env node

const http = require('http');

const healthCheck = () => {
  const options = {
    hostname: 'localhost',
    port: process.env.PORT || 3001,
    path: '/health',
    method: 'GET',
    timeout: 5000
  };

  const req = http.request(options, (res) => {
    console.log(`Health check status: ${res.statusCode}`);
    
    let data = '';
    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      if (res.statusCode === 200) {
        console.log('✅ Health check passed');
        console.log('Response:', data);
        process.exit(0);
      } else {
        console.error('❌ Health check failed');
        console.error('Response:', data);
        process.exit(1);
      }
    });
  });

  req.on('error', (err) => {
    console.error('❌ Health check failed:', err.message);
    process.exit(1);
  });

  req.on('timeout', () => {
    console.error('❌ Health check timeout');
    req.destroy();
    process.exit(1);
  });

  req.end();
};

// Wait for server to start up
setTimeout(healthCheck, 2000); 