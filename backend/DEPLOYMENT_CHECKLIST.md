# 🚀 Railway Deployment Checklist

Use this checklist to ensure a successful deployment to Railway.

## Pre-Deployment Setup

### 1. Railway Account & CLI
- [ ] Create Railway account at [railway.app](https://railway.app)
- [ ] Install Railway CLI: `npm install -g @railway/cli`
- [ ] Login to Railway: `railway login`

### 2. GitHub Repository Setup
- [ ] Push your code to GitHub
- [ ] Ensure the main branch is up to date
- [ ] Verify all tests pass: `npm test`

### 3. Environment Variables Preparation
- [ ] Review `env.railway` file for required variables
- [ ] Prepare Cloudinary credentials (recommended for file uploads)
- [ ] Prepare SMTP credentials for email functionality
- [ ] Have your frontend domain ready for CORS configuration

## Railway Project Setup

### 4. Create Railway Project
- [ ] Navigate to backend directory: `cd backend`
- [ ] Initialize Railway project: `railway init durusuna-backend`
- [ ] Connect to GitHub repository in Railway dashboard

### 5. Add Required Services
- [ ] Add PostgreSQL: `railway add postgresql`
- [ ] Add Redis: `railway add redis`
- [ ] Verify services are running in Railway dashboard

### 6. Configure Environment Variables

#### Required Variables (Set these first)
- [ ] `NODE_ENV=production`
- [ ] `JWT_SECRET` - Generate: `openssl rand -base64 64`
- [ ] `JWT_REFRESH_SECRET` - Generate: `openssl rand -base64 64`
- [ ] `SESSION_SECRET` - Generate: `openssl rand -base64 32`

#### CORS Configuration
- [ ] `CORS_ORIGIN` - Your frontend domain(s), comma-separated

#### File Upload (Cloudinary - Recommended)
- [ ] `CLOUDINARY_CLOUD_NAME`
- [ ] `CLOUDINARY_API_KEY`
- [ ] `CLOUDINARY_API_SECRET`

#### Email Configuration (Optional)
- [ ] `SMTP_HOST`
- [ ] `SMTP_USER`
- [ ] `SMTP_PASS`
- [ ] `SMTP_FROM`

## GitHub Actions Setup

### 7. Configure GitHub Secrets
- [ ] Go to your repo → Settings → Secrets and variables → Actions
- [ ] Add `RAILWAY_TOKEN`:
  - Run `railway auth` in terminal
  - Copy the token displayed
  - Add as GitHub secret

### 8. Test GitHub Actions
- [ ] Push a commit to trigger the workflow
- [ ] Verify all steps pass in Actions tab
- [ ] Check deployment status in Railway dashboard

## Deployment Options

Choose one of these deployment methods:

### Option A: Automated Script (Recommended)
```bash
npm run railway:deploy:full
```

### Option B: Manual Steps
```bash
# Deploy application
npm run railway:deploy

# Run migrations
npm run railway:migrate

# Optional: Seed database
npm run railway:seed

# Check health
railway run npm run health:check
```

### Option C: GitHub Actions (Automatic)
- Push to main branch
- GitHub Actions will handle deployment automatically

## Post-Deployment Verification

### 9. Health Checks
- [ ] Check application status: `npm run railway:status`
- [ ] Verify health endpoint: `railway run npm run health:check`
- [ ] Check logs: `npm run railway:logs`

### 10. Database Verification
- [ ] Verify migrations ran: `railway run npx knex migrate:currentVersion`
- [ ] Check database connectivity in health endpoint
- [ ] Test a few API endpoints

### 11. Redis Verification
- [ ] Verify Redis is healthy in health endpoint
- [ ] Test session functionality if implemented
- [ ] Check Redis connectivity

### 12. Application Testing
- [ ] Test authentication endpoints
- [ ] Test file upload functionality
- [ ] Test real-time features (Socket.io)
- [ ] Test database operations

## Frontend Integration

### 13. Update Frontend Configuration
- [ ] Update API base URL in Flutter app
- [ ] Update Socket.io connection URL
- [ ] Test cross-origin requests
- [ ] Verify SSL/HTTPS functionality

## Production Optimizations

### 14. Security & Performance
- [ ] Verify CORS is properly configured
- [ ] Confirm SSL is working (automatic with Railway)
- [ ] Test rate limiting
- [ ] Verify JWT token functionality

### 15. Monitoring Setup (Optional but Recommended)
- [ ] Set up Sentry for error tracking
- [ ] Configure log aggregation
- [ ] Set up uptime monitoring
- [ ] Configure alerts for critical failures

## Scaling & Maintenance

### 16. Database Management
- [ ] Set up automated backups
- [ ] Plan for database scaling
- [ ] Monitor database performance

### 17. Application Scaling
- [ ] Monitor Railway resource usage
- [ ] Plan for horizontal scaling if needed
- [ ] Consider CDN for static assets

## Troubleshooting Commands

If something goes wrong:

```bash
# Check deployment status
railway status

# View recent logs
railway logs

# Check environment variables
railway variables

# Connect to production database
railway connect postgresql

# Connect to Redis
railway connect redis

# Run migrations manually
railway run npm run db:migrate

# Check health status
railway run npm run health:check

# Restart application
railway up --detach
```

## Emergency Procedures

### Rollback
- [ ] Go to Railway dashboard
- [ ] Select previous deployment
- [ ] Click "Redeploy"

### Database Recovery
- [ ] Check Railway database backups
- [ ] Restore from backup if needed
- [ ] Re-run migrations if necessary

## Success Criteria

✅ **Deployment is successful when:**
- [ ] Application returns 200 on health endpoint
- [ ] Database is connected and healthy
- [ ] Redis is connected (if configured)
- [ ] Frontend can communicate with backend
- [ ] Authentication works
- [ ] File uploads work (if configured)
- [ ] Real-time features work
- [ ] All tests pass in CI/CD

## Next Steps After Deployment

1. **Monitor the application** for the first 24 hours
2. **Update documentation** with the new production URLs
3. **Inform your team** about the new deployment
4. **Set up monitoring alerts**
5. **Plan for regular maintenance windows**

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `npm run railway:deploy:full` | Full deployment with script |
| `npm run railway:logs` | View application logs |
| `npm run railway:status` | Check deployment status |
| `npm run railway:open` | Open app in browser |
| `railway connect postgresql` | Connect to database |
| `railway connect redis` | Connect to Redis |

---

**🎉 Congratulations on your Railway deployment!**

Your Durusuna backend is now running on Railway with PostgreSQL and Redis. The application will automatically scale based on usage and restart if needed. 