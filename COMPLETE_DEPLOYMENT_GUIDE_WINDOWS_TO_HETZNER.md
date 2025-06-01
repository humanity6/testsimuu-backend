# Complete Windows to Hetzner Cloud Deployment Guide
## Deploy Testimus Django App from Windows to Ubuntu Server

### 🖥️ What You'll Need:
- Your Windows computer with the Testimus project
- Hetzner Cloud server: **188.245.35.46** (Ubuntu CX22)
- SSH client (we'll use Windows PowerShell or install PuTTY)
- File transfer tool (we'll use WinSCP or command line)

---

## 📋 PART 1: PREPARE YOUR WINDOWS COMPUTER

### Step 1.1: Install Required Tools

#### Option A: Use Built-in Windows Tools (Recommended for beginners)
1. **Open PowerShell as Administrator**
   - Press `Windows + X`
   - Click "Windows PowerShell (Admin)" or "Terminal (Admin)"

2. **Install OpenSSH (if not already installed)**
   ```powershell
   # Check if SSH is available
   ssh -V
   
   # If not found, install it
   Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
   ```

#### Option B: Install PuTTY and WinSCP (Alternative)
1. Download and install **PuTTY**: https://putty.org/
2. Download and install **WinSCP**: https://winscp.net/

### Step 1.2: Prepare Your Project Files
1. **Open Command Prompt or PowerShell** in your project directory
   - Navigate to your `testimus` folder (where `manage.py` is located)
   - Right-click in the folder and select "Open PowerShell window here"

2. **Create a zip file of your project** (easier for uploading)
   ```powershell
   # Create a zip file excluding unnecessary files
   Compress-Archive -Path . -DestinationPath testimus-project.zip -Force
   ```

---

## 📋 PART 2: CONNECT TO YOUR HETZNER SERVER

### Step 2.1: First Connection Test
1. **Open PowerShell** (as regular user, not admin)

2. **Connect to your server**
   ```powershell
   ssh root@188.245.35.46
   ```
   
3. **If prompted about authenticity**, type `yes` and press Enter

4. **Enter your root password** when prompted

5. **You should now see a command prompt like this:**
   ```
   root@your-server-name:~#
   ```

**🎉 Success!** You're now connected to your Ubuntu server.

### Step 2.2: Update Your Server
Run these commands **one by one** (copy, paste, press Enter, wait for completion):

```bash
# Update package list
apt update

# Upgrade installed packages (this might take a few minutes)
apt upgrade -y
```

---

## 📋 PART 3: SETUP YOUR SERVER

### Step 3.1: Run the Server Setup Script

1. **Download the setup script** (copy and paste this entire block):
   ```bash
   cat > server_setup.sh << 'EOF'
   #!/bin/bash
   
   # Server Setup Script for Hetzner Cloud - Testimus Project
   set -e
   
   echo "🚀 Setting up server for Testimus deployment..."
   
   # Update system
   echo "📦 Updating system packages..."
   apt update
   apt upgrade -y
   
   # Install essential packages
   echo "📦 Installing essential packages..."
   apt install -y \
       python3 \
       python3-pip \
       python3-venv \
       python3-dev \
       git \
       nginx \
       supervisor \
       curl \
       wget \
       unzip \
       build-essential \
       libssl-dev \
       libffi-dev \
       libsqlite3-dev
   
   # Create application directory
   echo "📁 Creating application directories..."
   mkdir -p /var/www/testimus
   mkdir -p /var/log/django
   mkdir -p /var/log/supervisor
   
   # Install UFW firewall
   echo "🔒 Setting up firewall..."
   apt install -y ufw
   
   # Configure firewall
   ufw allow ssh
   ufw allow 80
   ufw allow 443
   echo "y" | ufw enable
   
   # Configure supervisor
   echo "⚙️  Configuring supervisor..."
   systemctl enable supervisor
   systemctl start supervisor
   
   # Create swap file (for better performance)
   echo "💾 Creating swap file..."
   if [ ! -f /swapfile ]; then
       fallocate -l 1G /swapfile
       chmod 600 /swapfile
       mkswap /swapfile
       swapon /swapfile
       echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
   fi
   
   echo "✅ Server setup completed!"
   echo "📋 Next step: Upload your project files to /var/www/testimus"
   EOF
   ```

2. **Make the script executable and run it**:
   ```bash
   chmod +x server_setup.sh
   ./server_setup.sh
   ```

**⏰ This will take 5-10 minutes.** Wait for it to complete.

---

## 📋 PART 4: UPLOAD YOUR PROJECT FILES

### Method A: Using SCP (Command Line - Recommended)

1. **Open a NEW PowerShell window** on your Windows computer (keep the SSH connection open in the other window)

2. **Navigate to your project directory**:
   ```powershell
   cd C:\path\to\your\testimus\project
   # Replace with your actual path, for example:
   # cd C:\Users\YourName\Documents\testimus
   ```

3. **Upload your project files**:
   ```powershell
   # Upload all files to the server
   scp -r * root@188.245.35.46:/var/www/testimus/
   ```

4. **Enter your password** when prompted

### Method B: Using WinSCP (GUI - Easier for beginners)

1. **Open WinSCP**

2. **Create a new connection**:
   - **File protocol**: SFTP
   - **Host name**: 188.245.35.46
   - **User name**: root
   - **Password**: (your root password)

3. **Click Login**

4. **Navigate to `/var/www/testimus/`** in the right panel

5. **Select all your project files** in the left panel and drag them to the right panel

### Method C: Using Git (if your project is on GitHub)

1. **Go back to your SSH connection** (the terminal where you're connected to the server)

2. **Navigate to the project directory**:
   ```bash
   cd /var/www/testimus
   ```

3. **Clone your repository**:
   ```bash
   # If your project is on GitHub, replace with your repository URL
   git clone https://github.com/yourusername/testimus.git .
   
   # If not using git, skip this method and use Method A or B above
   ```

---

## 📋 PART 5: DEPLOY YOUR APPLICATION

### Step 5.1: Create the Deployment Script

**In your SSH connection** (server terminal), run:

```bash
cd /var/www/testimus

cat > deploy.sh << 'EOF'
#!/bin/bash

# Testimus Deployment Script
set -e

echo "Starting Testimus deployment..."

# Configuration
PROJECT_DIR="/var/www/testimus"
VENV_DIR="$PROJECT_DIR/venv"
USER="testimus"
GROUP="testimus"

# Create application user
if ! id "$USER" &>/dev/null; then
    echo "Creating application user..."
    adduser --system --group --home "$PROJECT_DIR" "$USER"
fi

# Set ownership
echo "Setting ownership..."
chown -R "$USER:$GROUP" "$PROJECT_DIR"

# Create virtual environment
echo "Creating virtual environment..."
if [ ! -d "$VENV_DIR" ]; then
    sudo -u "$USER" python3 -m venv "$VENV_DIR"
fi

# Install dependencies
echo "Installing dependencies..."
sudo -u "$USER" bash -c "
    source $VENV_DIR/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
"

# Run migrations
echo "Running database migrations..."
sudo -u "$USER" bash -c "
    source $VENV_DIR/bin/activate
    python manage.py migrate
"

# Collect static files
echo "Collecting static files..."
sudo -u "$USER" bash -c "
    source $VENV_DIR/bin/activate
    export DJANGO_SETTINGS_MODULE=exam_prep_platform.production_settings
    python manage.py collectstatic --noinput
"

# Create directories
mkdir -p /var/log/django /var/log/supervisor
chown -R "$USER:$GROUP" /var/log/django

# Create gunicorn config
cat > "$PROJECT_DIR/gunicorn.conf.py" << EOG
bind = "127.0.0.1:8000"
workers = 3
user = "$USER"
group = "$GROUP"
chdir = "$PROJECT_DIR"
max_requests = 1000
timeout = 30
keepalive = 2
preload_app = True
EOG

chown "$USER:$GROUP" "$PROJECT_DIR/gunicorn.conf.py"

# Create supervisor config
cat > /etc/supervisor/conf.d/testimus.conf << EOS
[program:testimus]
command=$VENV_DIR/bin/gunicorn exam_prep_platform.wsgi:application -c $PROJECT_DIR/gunicorn.conf.py
directory=$PROJECT_DIR
user=$USER
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/supervisor/testimus.log
environment=DJANGO_SETTINGS_MODULE="exam_prep_platform.production_settings"
EOS

# Create nginx config
cat > /etc/nginx/sites-available/testimus << EON
server {
    listen 80;
    server_name 188.245.35.46 _;
    client_max_body_size 100M;
    
    location /static/ {
        alias $PROJECT_DIR/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias $PROJECT_DIR/media/;
        expires 1y;
        add_header Cache-Control "public";
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EON

# Enable nginx site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/testimus /etc/nginx/sites-enabled/

# Test nginx config
nginx -t

# Start services
supervisorctl reread
supervisorctl update
supervisorctl restart testimus 2>/dev/null || supervisorctl start testimus
systemctl restart nginx

sleep 5

echo "🚀 Deployment completed!"
echo "Your app is available at: http://188.245.35.46"
EOF

chmod +x deploy.sh
```

### Step 5.2: Run the Deployment

```bash
./deploy.sh
```

**⏰ This will take 3-5 minutes.** Wait for completion.

---

## 📋 PART 6: TEST YOUR APPLICATION

### Step 6.1: Check if Everything is Running

```bash
# Check supervisor status
supervisorctl status testimus

# Check nginx status
systemctl status nginx

# Check if the app responds
curl -I http://localhost
```

### Step 6.2: Test in Your Browser

1. **Open your web browser** on your Windows computer

2. **Go to these URLs**:
   - **Main site**: http://188.245.35.46
   - **Admin panel**: http://188.245.35.46/admin/
   - **API docs**: http://188.245.35.46/api/schema/swagger-ui/

### Step 6.3: Create Admin User (Optional)

```bash
# Connect to your server (if not already connected)
ssh root@188.245.35.46

# Switch to project directory
cd /var/www/testimus

# Create superuser
sudo -u testimus bash -c "
    source venv/bin/activate
    export DJANGO_SETTINGS_MODULE=exam_prep_platform.production_settings
    python manage.py createsuperuser
"
```

---

## 🔧 TROUBLESHOOTING

### If the website doesn't load:

1. **Check logs**:
   ```bash
   # Application logs
   tail -f /var/log/supervisor/testimus.log
   
   # Nginx logs
   tail -f /var/log/nginx/error.log
   ```

2. **Check service status**:
   ```bash
   supervisorctl status testimus
   systemctl status nginx
   ```

3. **Restart services**:
   ```bash
   supervisorctl restart testimus
   systemctl restart nginx
   ```

### If you get permission errors:
```bash
chown -R testimus:testimus /var/www/testimus
```

### If static files don't load:
```bash
cd /var/www/testimus
sudo -u testimus bash -c "
    source venv/bin/activate
    export DJANGO_SETTINGS_MODULE=exam_prep_platform.production_settings
    python manage.py collectstatic --noinput
"
```

---

## 🎉 SUCCESS!

If everything worked, your Testimus app should now be running at:
- **http://188.245.35.46**

### 📱 For Your Flutter App:
Update your Flutter app's API base URL to point to:
- **http://188.245.35.46/api/**

### 🔄 For Future Updates:
1. Upload new files using SCP or WinSCP
2. Run: `supervisorctl restart testimus`

### 📊 Useful Management Commands:
```bash
# Check status
supervisorctl status testimus

# View logs
tail -f /var/log/supervisor/testimus.log

# Restart application
supervisorctl restart testimus

# Restart nginx
systemctl restart nginx
```

---

## 🆘 NEED HELP?

If you encounter any issues:

1. **Check the logs** first (commands above)
2. **Make sure all files were uploaded** correctly
3. **Verify your database file** `exam_prep_db.sqlite3` was uploaded
4. **Check if the server has enough memory**: `free -h`
5. **Restart everything**: 
   ```bash
   supervisorctl restart testimus
   systemctl restart nginx
   ```

**Remember**: Your app is now live on the internet! 🌐 