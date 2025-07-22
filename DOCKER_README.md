# Durusuna Mobile - Docker Development Setup

This guide will help you set up the Durusuna mobile app backend using Docker for development, testing, and deployment.

## 🚀 Quick Start

### Prerequisites

- [Docker](https://www.docker.com/get-started) (v20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)
- Git

### 1. Clone and Setup

```bash
git clone <your-repository-url>
cd durusuna-mobile
```

### 2. Environment Configuration

Create environment files from examples:

```bash
# Backend environment
cp backend/env.example backend/.env

# Edit the .env file with your preferred settings
nano backend/.env
```

### 3. Start Development Environment

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f backend

# Start specific services only
docker-compose up -d postgres redis backend
```

## 📋 Services Overview

| Service | Port | Description | Admin UI |
|---------|------|-------------|----------|
| **Backend** | 3001 | Node.js API Server | - |
| **PostgreSQL** | 5433 | Database | PgAdmin: http://localhost:5050 |
| **Redis** | 6380 | Cache & Sessions | - |
| **MinIO** | 9000/9001 | S3-compatible storage | http://localhost:9001 |
| **MailHog** | 1025/8025 | Email testing | http://localhost:8025 |
| **PgAdmin** | 5050 | Database admin | http://localhost:5050 |

### Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| PostgreSQL | `postgres` | `postgres123` |
| Redis | - | `redis123` |
| MinIO | `minioadmin` | `minioadmin123` |
| PgAdmin | `admin@durusuna.local` | `admin123` |

## 🛠️ Development Commands

### Docker Compose Commands

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Rebuild and start
docker-compose up --build

# View logs
docker-compose logs -f [service-name]

# Run commands in containers
docker-compose exec backend npm test
docker-compose exec backend npm run db:migrate
docker-compose exec postgres psql -U postgres -d durusuna_dev
```

### Backend Development

```bash
# Install dependencies
docker-compose exec backend npm install

# Run tests
docker-compose exec backend npm test

# Run database migrations
docker-compose exec backend npm run db:migrate

# Seed database
docker-compose exec backend npm run db:seed

# Reset database
docker-compose exec backend npm run db:reset

# Check API health
curl http://localhost:3001/health
```

### Database Management

```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U postgres -d durusuna_dev
# Or connect from host
psql -h localhost -p 5433 -U postgres -d durusuna_dev

# Backup database
docker-compose exec postgres pg_dump -U postgres durusuna_dev > backup.sql

# Restore database
docker-compose exec -T postgres psql -U postgres durusuna_dev < backup.sql

# View database logs
docker-compose logs postgres
```

## 🔧 Environment Variables

Key environment variables for development:

### Required Variables
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` - Database connection
- `JWT_SECRET`, `JWT_REFRESH_SECRET` - Authentication secrets
- `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD` - Redis connection

### Optional Variables
- `S3_ENDPOINT`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` - File storage
- `SMTP_HOST`, `SMTP_PORT` - Email configuration
- `LOG_LEVEL` - Logging level (debug, info, warn, error)

See `backend/env.example` for complete list.

## 📁 Volume Mounts

- `./backend:/app` - Live code reloading
- `backend_uploads:/app/uploads` - File uploads persistence
- `postgres_data:/var/lib/postgresql/data` - Database persistence
- `redis_data:/data` - Redis persistence

## 🧪 Testing

### Run Tests

```bash
# Unit tests
docker-compose exec backend npm test

# Watch mode
docker-compose exec backend npm run test:watch

# Coverage report
docker-compose exec backend npm run test:coverage

# Integration tests
docker-compose exec backend npm run test:ci
```

### Test Database

The test environment uses a separate database (`durusuna_test`) that's automatically created and managed.

## 🌐 Production Configuration

### Production Profile

```bash
# Start with production profile (includes nginx)
docker-compose --profile production up -d

# Start with tools profile (includes pgadmin)
docker-compose --profile tools up -d
```

### Production Environment Variables

Update these for production:

```bash
NODE_ENV=production
JWT_SECRET=<strong-random-secret>
JWT_REFRESH_SECRET=<strong-random-secret>
DB_PASSWORD=<strong-database-password>
REDIS_PASSWORD=<strong-redis-password>
CORS_ORIGIN=https://yourdomain.com
```

## 🔍 Monitoring & Debugging

### Health Checks

All services include health checks:

```bash
# Check service health
docker-compose ps

# View health check logs
docker inspect durusuna_backend | grep -A 5 Health
```

### Logging

```bash
# Follow all logs
docker-compose logs -f

# Backend logs only
docker-compose logs -f backend

# Database logs
docker-compose logs -f postgres

# Real-time log streaming
docker-compose logs --tail=100 -f backend
```

### Performance Monitoring

```bash
# Container stats
docker stats

# Service resource usage
docker-compose top
```

## 🛡️ Security Considerations

### Development
- Default passwords are used for convenience
- CORS is set to allow all origins
- Debug logging is enabled

### Production
- Change all default passwords
- Configure proper CORS origins
- Use environment-specific secrets
- Enable SSL/TLS
- Set up proper logging levels

## 📚 API Documentation

### Health Check
```bash
curl http://localhost:3001/health
```

### Authentication
```bash
# Register
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!","first_name":"Test","last_name":"User","user_type":"student","school_id":"<school-id>"}'

# Login
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!"}'
```

## 🐛 Troubleshooting

### Common Issues

1. **Port conflicts**: Change ports in docker-compose.yml if needed
2. **Permission issues**: Ensure Docker has proper permissions
3. **Database connection**: Check if PostgreSQL is running and accessible
4. **Memory issues**: Increase Docker memory allocation

### Reset Everything

```bash
# Stop and remove all containers
docker-compose down -v

# Remove all volumes (WARNING: This deletes all data)
docker-compose down -v --remove-orphans

# Rebuild from scratch
docker-compose up --build
```

### View Container Status

```bash
# List all containers
docker-compose ps

# Inspect specific container
docker inspect durusuna_backend

# Access container shell
docker-compose exec backend sh
```

## 📞 Support

If you encounter issues:

1. Check the logs: `docker-compose logs -f backend`
2. Verify all services are healthy: `docker-compose ps`
3. Ensure environment variables are set correctly
4. Try rebuilding: `docker-compose up --build`

---

**Happy Development! 🚀** 