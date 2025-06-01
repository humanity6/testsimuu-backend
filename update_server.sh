#!/bin/bash

# Testimus Server Update Script for Hetzner Cloud
# Run this script on your server after uploading updated project files
# Use this for updates after initial deployment

set -e  # Exit on any error

echo "???? Starting Testimus server update..."

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

# Set ownership for uploaded files
echo "???? Setting file permissions..."
chown -R "$USER:$GROUP" "$PROJECT_DIR"

# Make scripts executable
chmod +x update_server.sh

# Activate virtual environment and install/update dependencies
echo "???? Updating dependencies..."
sudo -u "$USER" bash -c "
    source $VENV_DIR/bin/activate
    pip install --upgrade pip
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
supervisorctl restart testimus
sleep 3

# Check service status
echo "???? Checking service status..."
echo "Supervisor status:"
supervisorctl status testimus

echo "Nginx status:"
systemctl is-active nginx

# Test application
echo "???? Testing application..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|302\|404"; then
    echo "??? Application update completed successfully!"
    echo ""
    echo "Your updated application is now available at:"
    echo "  - Main site: http://188.245.35.46"
    echo "  - Admin panel: http://188.245.35.46/admin/"
    echo "  - API docs: http://188.245.35.46/api/schema/swagger-ui/"
    echo ""
    echo "???? Service status:"
    echo "  - Django: $(supervisorctl status testimus | awk '{print $2}')"
    echo "  - Nginx: $(systemctl is-active nginx)"
    echo ""
    echo "???? Useful commands:"
    echo "  - View Django logs: tail -f /var/log/supervisor/testimus.log"
    echo "  - View Nginx logs: tail -f /var/log/nginx/error.log"
    echo "  - Restart Django: supervisorctl restart testimus"
    echo "  - Check status: supervisorctl status testimus"
else
    echo "??? Application is not responding properly. Check the logs:"
    echo "  - Django logs: tail -f /var/log/supervisor/testimus.log"
    echo "  - Nginx logs: tail -f /var/log/nginx/error.log"
    echo "  - Supervisor status: supervisorctl status testimus"
    exit 1
fi
