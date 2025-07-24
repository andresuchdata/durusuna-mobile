#!/bin/bash

# Railway Deployment Script for Durusuna Backend
# This script automates the deployment process to Railway

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Check if Railway CLI is installed
check_railway_cli() {
    if ! command -v railway &> /dev/null; then
        log_error "Railway CLI not found. Install with: npm install -g @railway/cli"
    fi
    log_success "Railway CLI is installed"
}

# Check if user is logged in
check_railway_auth() {
    if ! railway whoami &> /dev/null; then
        log_error "Not logged in to Railway. Run: railway login"
    fi
    log_success "Railway authentication verified"
}

# Check if project is linked
check_railway_project() {
    if ! railway status &> /dev/null; then
        log_warning "No Railway project linked. Initializing..."
        railway init durusuna-backend
    fi
    log_success "Railway project linked"
}

# Generate secure secrets
generate_secrets() {
    log_info "Generating secure secrets..."
    
    JWT_SECRET=$(openssl rand -base64 64)
    JWT_REFRESH_SECRET=$(openssl rand -base64 64)
    SESSION_SECRET=$(openssl rand -base64 32)
    
    log_info "Setting environment variables..."
    railway variables set JWT_SECRET="$JWT_SECRET"
    railway variables set JWT_REFRESH_SECRET="$JWT_REFRESH_SECRET"
    railway variables set SESSION_SECRET="$SESSION_SECRET"
    
    log_success "Secrets generated and set"
}

# Deploy application
deploy_app() {
    log_info "Deploying application to Railway..."
    railway up --detach
    
    log_info "Waiting for deployment to complete..."
    sleep 30
    
    log_success "Application deployed"
}

# Run database migrations
run_migrations() {
    log_info "Running database migrations..."
    railway run npm run db:migrate
    log_success "Database migrations completed"
}

# Optional: Seed database
seed_database() {
    read -p "Do you want to seed the database? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Seeding database..."
        railway run npm run db:seed
        log_success "Database seeded"
    fi
}

# Health check
health_check() {
    log_info "Running health check..."
    sleep 10
    
    if railway run npm run health:check; then
        log_success "Health check passed"
    else
        log_error "Health check failed"
    fi
}

# Get deployment info
show_deployment_info() {
    log_info "Deployment Information:"
    echo "---"
    railway status
    echo "---"
    log_info "To view logs: railway logs"
    log_info "To open in browser: railway open"
}

# Main deployment process
main() {
    echo "🚂 Railway Deployment Script"
    echo "============================="
    
    # Pre-flight checks
    check_railway_cli
    check_railway_auth
    check_railway_project
    
    # Optional: Generate secrets if first deployment
    read -p "Is this the first deployment? Generate new secrets? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        generate_secrets
    fi
    
    # Deploy
    deploy_app
    
    # Post-deployment tasks
    run_migrations
    seed_database
    health_check
    
    # Show results
    show_deployment_info
    
    log_success "🎉 Deployment completed successfully!"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 