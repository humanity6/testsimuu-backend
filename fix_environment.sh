#!/bin/bash

# Fix Testimus Environment After Re-upload
# Run this script to recreate the virtual environment and fix deployment

set -e  # Exit on any error

echo "???? Fixing Testimus environment after re-upload..."

# Configuration
PROJECT_DIR="/var/www/testimus"
VENV_DIR="$PROJECT_DIR/venv"
USER="testimus"
GROUP="testimus"

# Check if we're running as root
if [ "$EUID" -ne 0 ]; then
    echo "??? Please run this script as root (use sudo)"
    exit 1
fi

# Switch to project directory
cd "$PROJECT_DIR"

echo "???? Setting file permissions..."
chown -R "$USER:$GROUP" "$PROJECT_DIR"

# Make scripts executable
chmod +x update_server.sh
chmod +x fix_environment.sh

# Remove old virtual environment if it exists
if [ -d "$VENV_DIR" ]; then
    echo "??????? Removing old virtual environment..."
    rm -rf "$VENV_DIR"
fi

# Create new virtual environment
echo "???? Creating new Python virtual environment..."
sudo -u "$USER" python3 -m venv "$VENV_DIR"

# Install/upgrade pip and basic packages
echo "???? Installing Python dependencies..."
sudo -u "$USER" bash -c "
    source $VENV_DIR/bin/activate
    pip install --upgrade pip
    pip install wheel setuptools
    pip install -r requirements.txt
"

# Load environment variables and run database migrations
echo "??????? Running database migrations..."
sudo -u "$USER" bash -c "
    source $VENV_DIR/bin/activate
    if [ -f .env ]; then
        export \$(cat .env | grep -v '^#' | xargs)
    fi
    python manage.py migrate
"

# Collect static files
echo "???? Collecting static files..."
sudo -u "$USER" bash -c "
    source $VENV_DIR/bin/activate
    if [ -f .env ]; then
        export \$(cat .env | grep -v '^#' | xargs)
    fi
    export DJANGO_SETTINGS_MODULE=exam_prep_platform.production_settings
    python manage.py collectstatic --noinput
"

# Restart services
echo "???? Restarting services..."
supervisorctl restart testimus || echo "?????? Service restart failed, will try to start..."
sleep 3

# Try to start service if restart failed
supervisorctl start testimus || echo "?????? Service start failed, check configuration"

# Check service status
echo "???? Checking service status..."
echo "Supervisor status:"
supervisorctl status testimus

echo "Nginx status:"
systemctl is-active nginx

# Test application
echo "???? Testing application..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|302\|404"; then
    echo "??? Environment fixed successfully!"
    echo ""
    echo "Your application is now available at:"
    echo "  - Main site: http://188.245.35.46"
    echo "  - Admin panel: http://188.245.35.46/admin/"
    echo "  - API docs: http://188.245.35.46/api/schema/swagger-ui/"
    echo ""
    echo "???? Service status:"
    echo "  - Django: $(supervisorctl status testimus | awk '{print $2}')"
    echo "  - Nginx: $(systemctl is-active nginx)"
    echo ""
    echo "???? You can now use the regular update_server.sh script for future updates"
else
    echo "??? Application is not responding properly. Check the logs:"
    echo "  - Django logs: tail -f /var/log/supervisor/testimus.log"
    echo "  - Nginx logs: tail -f /var/log/nginx/error.log"
    echo "  - Supervisor status: supervisorctl status testimus"
fi

echo ""
echo "??? Environment setup complete! You can now use update_server.sh for future updates." 
