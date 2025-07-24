# Railway Deployment Guide

This guide will help you deploy the Durusuna backend to Railway with PostgreSQL and Redis.

## 🚀 Quick Setup

### 1. Install Railway CLI
```bash
npm install -g @railway/cli
```

### 2. Login to Railway
```bash
railway login
```

### 3. Create a New Project
```bash
# Navigate to backend directory
cd backend

# Initialize Railway project
railway init durusuna-backend
```

### 4. Add Services

#### PostgreSQL Database
```bash
railway add postgresql
```

#### Redis Cache
```bash
railway add redis
```

### 5. Set Environment Variables

Copy the environment variables from `env.railway` and set them in Railway:

```bash
# Generate secure JWT secrets
railway variables set JWT_SECRET=$(openssl rand -base64 64)
railway variables set JWT_REFRESH_SECRET=$(openssl rand -base64 64)
railway variables set SESSION_SECRET=$(openssl rand -base64 32)

# Set CORS origin (replace with your frontend domain)
railway variables set CORS_ORIGIN="https://yourapp.com,https://www.yourapp.com"

# Optional: Cloudinary for file uploads
railway variables set CLOUDINARY_CLOUD_NAME=your_cloud_name
railway variables set CLOUDINARY_API_KEY=your_api_key
railway variables set CLOUDINARY_API_SECRET=your_api_secret

# Optional: SMTP for emails
railway variables set SMTP_HOST=smtp.gmail.com
railway variables set SMTP_USER=your_email@gmail.com
railway variables set SMTP_PASS=your_app_password
railway variables set SMTP_FROM=noreply@yourapp.com
```

### 6. Deploy
```bash
npm run railway:deploy
```

### 7. Run Database Migrations
```bash
npm run railway:migrate
```

### 8. (Optional) Seed Database
```bash
npm run railway:seed
```

## 🔧 Manual Deployment Steps

### Step 1: Connect GitHub Repository

1. Go to [Railway Dashboard](https://railway.app/dashboard)
2. Click "New Project"
3. Select "Deploy from GitHub repo"
4. Choose your repository
5. Set the root directory to `/backend`

### Step 2: Configure Build Settings

Railway will automatically detect your Node.js project. The `railway.toml` and `nixpacks.toml` files are already configured.

### Step 3: Add Services

#### PostgreSQL
1. Click "Add Service" → "Database" → "PostgreSQL"
2. Railway will create a PostgreSQL instance and provide `DATABASE_URL`

#### Redis
1. Click "Add Service" → "Database" → "Redis"
2. Railway will create a Redis instance and provide `REDIS_URL`

### Step 4: Environment Variables

Set these environment variables in Railway dashboard:

| Variable | Value | Description |
|----------|-------|-------------|
| `NODE_ENV` | `production` | Environment |
| `JWT_SECRET` | Generate random | JWT signing secret |
| `JWT_REFRESH_SECRET` | Generate random | Refresh token secret |
| `SESSION_SECRET` | Generate random | Session secret |
| `CORS_ORIGIN` | Your frontend URL | CORS configuration |

### Step 5: Deploy

Railway will automatically deploy when you push to the main branch.

## 🤖 GitHub Actions CI/CD

The GitHub Actions workflow is already configured in `.github/workflows/backend-deploy.yml`.

### Setup GitHub Secrets

Add these secrets to your GitHub repository:

1. Go to your repo → Settings → Secrets and variables → Actions
2. Add the following secrets:

| Secret | Value | How to get |
|--------|-------|------------|
| `RAILWAY_TOKEN` | Your Railway token | Run `railway auth` locally |

### Workflow Features

- ✅ **Testing**: Runs tests with PostgreSQL and Redis
- ✅ **Linting**: Code quality checks
- ✅ **Building**: Validates build process
- ✅ **Deployment**: Auto-deploys to Railway on main branch
- ✅ **Migrations**: Runs database migrations after deployment
- ✅ **Health Check**: Verifies deployment success

## 📋 Available Scripts

| Script | Description |
|--------|-------------|
| `npm run railway:deploy` | Deploy to Railway |
| `npm run railway:migrate` | Run database migrations |
| `npm run railway:seed` | Seed the database |
| `npm run railway:logs` | View application logs |
| `node scripts/deploy.js` | Full deployment script |

## 🔍 Monitoring

### View Logs
```bash
npm run railway:logs
```

### Health Check
```bash
railway run npm run health:check
```

### Database Status
```bash
railway run npx knex migrate:currentVersion
```

## 🌐 Custom Domain

1. Go to Railway Dashboard → Your Service → Settings
2. Click "Generate Domain" for a free Railway domain
3. Or add your custom domain in "Custom Domains"

## 🔐 Production Security Checklist

- [ ] Set strong JWT secrets
- [ ] Configure CORS properly
- [ ] Set up proper SMTP for emails
- [ ] Enable SSL (automatic with Railway)
- [ ] Set up monitoring (Sentry recommended)
- [ ] Configure proper logging
- [ ] Set up database backups
- [ ] Implement rate limiting (already configured)

## 🆘 Troubleshooting

### Common Issues

#### Build Fails
```bash
# Check build logs
railway logs --deployment

# Test build locally
npm run build:check
```

#### Database Connection Issues
```bash
# Check database status
railway variables
railway run node -e "console.log(process.env.DATABASE_URL)"
```

#### Migration Issues
```bash
# Check migration status
railway run npx knex migrate:status

# Rollback if needed
railway run npm run db:rollback
```

### Getting Help

1. Check Railway logs: `railway logs`
2. Check GitHub Actions logs in your repository
3. Review Railway documentation: https://docs.railway.app
4. Join Railway Discord: https://discord.gg/railway

## 📊 Performance Tips

1. **Database**: Railway PostgreSQL is optimized for production
2. **Redis**: Use for session storage and caching
3. **File Uploads**: Use Cloudinary for better performance
4. **Monitoring**: Set up Sentry for error tracking
5. **Scaling**: Railway auto-scales based on usage

## 🚀 Next Steps

After deployment:

1. Update your Flutter app's API endpoints
2. Test all functionality in production
3. Set up monitoring and alerting
4. Configure automatic backups
5. Plan for scaling as needed

Your backend is now running on Railway with PostgreSQL and Redis! 🎉 