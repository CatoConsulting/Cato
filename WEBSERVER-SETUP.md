# Simple Web Server Setup Guide

Quick setup scripts for installing and running a simple HTTP web server using Node.js and http-server.

## Overview

These scripts install Node.js and the `http-server` package, which provides a simple, zero-configuration command-line HTTP server for testing static websites, HTML files, and web applications.

## Platform Support

- **Windows** - PowerShell script (`setup-webserver.ps1`)
- **Linux/macOS** - Bash script (`setup-webserver.sh`)

## Quick Start

### Windows

```powershell
# Run as Administrator
.\setup-webserver.ps1

# Or install and start immediately
.\setup-webserver.ps1 -Port 8080 -Start

# Specify a directory to serve
.\setup-webserver.ps1 -Directory "C:\Projects\MyApp" -Port 3000 -Start
```

### Linux/macOS

```bash
# Make executable (first time only)
chmod +x setup-webserver.sh

# Run the setup
./setup-webserver.sh

# Or install and start immediately
./setup-webserver.sh --port 8080 --start

# Specify a directory to serve
./setup-webserver.sh --port 3000 --directory ./public --start
```

## What Gets Installed

1. **Node.js** (LTS version)
   - JavaScript runtime required for http-server
   - Includes npm (Node Package Manager)

2. **http-server**
   - Lightweight HTTP server for static files
   - Zero-configuration
   - Supports various options (CORS, caching, gzip, etc.)

3. **Wrapper Script** (`start-webserver.ps1` or `start-webserver.sh`)
   - Convenience script for starting the server
   - Simplifies common usage patterns

## Installation Details

### Windows Installation

The PowerShell script:
- Requires Administrator privileges
- Installs Chocolatey (if not present)
- Installs Node.js LTS via Chocolatey
- Installs http-server globally via npm
- Creates a convenience wrapper script
- Optionally starts the server

### Linux/macOS Installation

The Bash script:
- Detects your OS automatically
- Uses appropriate package manager:
  - **macOS**: Homebrew (`brew`)
  - **Ubuntu/Debian**: apt
  - **Fedora/RHEL/CentOS**: dnf/yum
- Installs Node.js and npm
- Installs http-server globally
- Creates a convenience wrapper script
- Optionally starts the server

## Usage

### Using the Wrapper Script

After installation, you can use the convenient wrapper script:

#### Windows
```powershell
# Start with default settings (port 8080, current directory)
.\start-webserver.ps1

# Specify port
.\start-webserver.ps1 -Port 3000

# Open browser automatically
.\start-webserver.ps1 -Port 8080 -Open

# Specify directory
.\start-webserver.ps1 -Directory "C:\path\to\files" -Port 8080
```

#### Linux/macOS
```bash
# Start with default settings (port 8080, current directory)
./start-webserver.sh

# Specify port
./start-webserver.sh --port 3000

# Open browser automatically
./start-webserver.sh --port 8080 --open

# Specify directory
./start-webserver.sh --directory ./public --port 8080
```

### Using http-server Directly

You can also use http-server directly from the command line:

```bash
# Basic usage - serves current directory on port 8080
http-server

# Specify port
http-server -p 3000

# Specify directory
http-server ./public

# Open browser automatically
http-server -o

# Disable caching (useful for development)
http-server -c-1

# Enable CORS
http-server --cors

# Enable gzip compression
http-server -g

# Combine options
http-server ./dist -p 8080 -o -c-1 --cors
```

## Common Use Cases

### 1. Testing Static Website

```bash
# Navigate to your project
cd /path/to/your/website

# Start server
http-server -p 8080 -o

# Access at http://localhost:8080
```

### 2. Development with Live Reload

For development, disable caching:

```bash
http-server -p 3000 -c-1 -o
```

### 3. Testing CORS Requests

```bash
http-server --cors -p 8080
```

### 4. Serving Build Output

```bash
# Serve production build
http-server ./dist -p 8080 -g --cors
```

### 5. Quick File Sharing on Local Network

```bash
# Start server accessible on local network
http-server -p 8080

# Then access from other devices using your IP
# http://<your-ip>:8080
```

## Options Reference

### Common Options

| Option | Description |
|--------|-------------|
| `-p <port>` or `--port <port>` | Port to use (default: 8080) |
| `-a <address>` | Address to bind to (default: 0.0.0.0) |
| `-d` | Show directory listings (default: true) |
| `-i` | Display autoIndex (default: true) |
| `-g` or `--gzip` | Enable gzip compression |
| `-e` or `--ext` | Default file extension (default: html) |
| `-s` or `--silent` | Suppress log messages |
| `-o` | Open browser after starting |
| `-c` | Set cache time (in seconds), -c-1 disables caching |
| `--cors` | Enable CORS headers |
| `-U` or `--utc` | Use UTC time format in log messages |
| `-P` or `--proxy` | Proxy requests to specified URL |
| `-S` or `--ssl` | Enable HTTPS |
| `-C` or `--cert` | Path to SSL cert file |
| `-K` or `--key` | Path to SSL key file |

### Security Options

```bash
# Enable basic authentication
http-server --username admin --password "$HTTP_SERVER_PASSWORD"

# HTTPS with SSL certificate
http-server -S -C cert.pem -K key.pem
```

## Troubleshooting

### Port Already in Use

**Error:** `Address already in use`

**Solution:** Use a different port or kill the process using that port

```bash
# Windows
netstat -ano | findstr :8080
taskkill /PID <process-id> /F

# Linux/macOS
lsof -i :8080
kill -9 <process-id>
```

### Permission Denied (Linux/macOS)

**Error:** Permission denied when installing globally

**Solution 1:** Use sudo
```bash
sudo npm install -g http-server
```

**Solution 2:** Configure npm to use a different directory
```bash
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
npm install -g http-server
```

### Command Not Found After Installation

**Solution:** Restart your terminal or refresh PATH

**Windows:**
```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

**Linux/macOS:**
```bash
source ~/.bashrc  # or ~/.zshrc for zsh
```

### Firewall Blocking Access

**Windows:**
- Add exception in Windows Firewall
- Or temporarily disable firewall for testing

**Linux/macOS:**
```bash
# Ubuntu/Debian
sudo ufw allow 8080/tcp

# macOS
# System Preferences > Security & Privacy > Firewall > Firewall Options
```

## Testing Your Server

### Basic Test

1. Create a simple HTML file:

```html
<!-- index.html -->
<!DOCTYPE html>
<html>
<head>
    <title>Test Page</title>
</head>
<body>
    <h1>Web Server is Working!</h1>
    <p>If you can see this, your http-server is running correctly.</p>
</body>
</html>
```

2. Start the server:

```bash
http-server -p 8080 -o
```

3. Your browser should open to `http://localhost:8080` showing the test page

### Network Test

To access from other devices on your network:

1. Find your local IP address:

**Windows:**
```powershell
ipconfig
# Look for "IPv4 Address"
```

**Linux/macOS:**
```bash
ifconfig | grep "inet "
# Or
ip addr show
```

2. Start server:
```bash
http-server -p 8080
```

3. Access from another device:
```
http://<your-ip>:8080
```

## Integration with Development Workflow

### package.json Scripts

Add to your project's `package.json`:

```json
{
  "scripts": {
    "serve": "http-server -p 8080 -c-1",
    "serve:prod": "http-server ./dist -p 8080 -g --cors",
    "serve:open": "http-server -p 8080 -o -c-1"
  }
}
```

Then run:
```bash
npm run serve
```

### Docker Alternative

If you prefer Docker:

```dockerfile
FROM node:lts-alpine
RUN npm install -g http-server
WORKDIR /app
EXPOSE 8080
CMD ["http-server", "-p", "8080"]
```

## Alternatives

While http-server is great for quick testing, consider these alternatives for specific needs:

- **Live reload during development:** `live-server`, `browser-sync`
- **Production servers:** Nginx, Apache, Caddy
- **Node.js development:** Express.js, Koa
- **Static site hosting:** Netlify, Vercel, GitHub Pages
- **Python users:** `python -m http.server 8080`

## Performance Tips

1. **Enable gzip compression:**
   ```bash
   http-server -g
   ```

2. **Adjust cache settings:**
   ```bash
   # Development (no cache)
   http-server -c-1

   # Production (1 hour cache)
   http-server -c3600
   ```

3. **Serve pre-compressed files:**
   - Create `.gz` versions of large files
   - http-server will automatically serve them when available

## Security Notes

⚠️ **Important Security Considerations:**

1. **Not for Production:** http-server is meant for development and testing, not production deployment
2. **Local Network Only:** Be cautious when exposing to your local network
3. **No Built-in Security:** No authentication or encryption by default
4. **Directory Listings:** Enabled by default - use `-d false` to disable
5. **HTTPS:** Use `-S` flag with certificates for sensitive content

For production deployments, use proper web servers like Nginx, Apache, or cloud platforms.

## Uninstallation

### Remove http-server

```bash
npm uninstall -g http-server
```

### Remove Node.js

**Windows (Chocolatey):**
```powershell
choco uninstall nodejs-lts
```

**macOS (Homebrew):**
```bash
brew uninstall node
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get remove nodejs npm
```

## Additional Resources

- [http-server Documentation](https://github.com/http-party/http-server)
- [Node.js Documentation](https://nodejs.org/docs/)
- [npm Documentation](https://docs.npmjs.com/)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review http-server GitHub issues: https://github.com/http-party/http-server/issues
3. Check Node.js installation guides: https://nodejs.org/en/download/

---

**Last Updated:** 2026-09-07  
**Script Version:** 1.0.0
