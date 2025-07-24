#!/usr/bin/env node

const { execSync } = require('child_process');
const path = require('path');

const log = (message) => {
  console.log(`🚀 ${message}`);
};

const error = (message) => {
  console.error(`❌ ${message}`);
  process.exit(1);
};

const execCommand = (command, description) => {
  log(description);
  try {
    execSync(command, { stdio: 'inherit', cwd: __dirname });
  } catch (err) {
    error(`Failed: ${description}`);
  }
};

const deploy = async () => {
  log('Starting Railway deployment...');

  // Check if Railway CLI is installed
  try {
    execSync('railway --version', { stdio: 'pipe' });
  } catch {
    error('Railway CLI not found. Install with: npm install -g @railway/cli');
  }

  // Check if logged in
  try {
    execSync('railway whoami', { stdio: 'pipe' });
  } catch {
    error('Not logged in to Railway. Run: railway login');
  }

  // Deploy the application
  execCommand('railway up', 'Deploying to Railway...');

  // Run database migrations
  log('Waiting 30 seconds for deployment to complete...');
  await new Promise(resolve => setTimeout(resolve, 30000));
  
  execCommand('railway run npm run db:migrate', 'Running database migrations...');

  // Health check
  execCommand('railway run npm run health:check', 'Running health check...');

  log('🎉 Deployment completed successfully!');
  log('Run "npm run railway:logs" to view application logs');
};

// Check if script is run directly
if (require.main === module) {
  deploy().catch(error);
}

module.exports = { deploy }; 