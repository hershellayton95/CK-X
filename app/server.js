const express = require('express');
const cors = require('cors');
const path = require('path');
const http = require('http');
const socketio = require('socket.io');
const SSHTerminal = require('./services/ssh-terminal');
const PublicService = require('./services/public-service');
const RouteService = require('./services/route-service');
const VNCService = require('./services/vnc-service');
const sessionResolver = require('./services/session-resolver');

// Server configuration
const PORT = process.env.PORT || 3000;

// Single-environment fallbacks. In multisession mode the target is resolved per
// request from the caller's session cookie (see services/session-resolver.js).
const VNC_SERVICE_HOST = process.env.VNC_SERVICE_HOST || 'remote-desktop-service';
const VNC_SERVICE_PORT = process.env.VNC_SERVICE_PORT || 6901;
const VNC_PASSWORD = process.env.VNC_PASSWORD || 'bakku-the-wizard'; // Default password

const SSH_HOST = process.env.SSH_HOST || 'remote-terminal'; // Use remote-terminal service
const SSH_PORT = process.env.SSH_PORT || 22;
const SSH_USER = process.env.SSH_USER || 'candidate';
const SSH_PASSWORD = process.env.SSH_PASSWORD || 'password';

const FALLBACK_TARGETS = {
    vncHost: VNC_SERVICE_HOST,
    vncPort: VNC_SERVICE_PORT,
    vncPassword: VNC_PASSWORD,
    sshHost: SSH_HOST,
    sshPort: SSH_PORT,
    sshPassword: SSH_PASSWORD
};

const app = express();
const server = http.createServer(app);
const io = socketio(server);

// Initialize SSH Terminal
const sshTerminal = new SSHTerminal({
    host: SSH_HOST,
    port: SSH_PORT,
    username: SSH_USER,
    password: SSH_PASSWORD
});

// Initialize Public Service
const publicService = new PublicService(path.join(__dirname, 'public'));
publicService.initialize();

// CORS is not needed: the webapp is same-origin behind nginx. Keep it opt-in
// for development setups that explicitly set CORS_ORIGIN.
app.use(cors({ origin: process.env.CORS_ORIGIN || false }));


// Initialize VNC Service
const vncService = new VNCService({
    host: VNC_SERVICE_HOST,
    port: VNC_SERVICE_PORT,
    password: VNC_PASSWORD
});

// SSH terminal namespace. The target depends on the caller's session cookie,
// which arrives with the socket.io handshake.
const sshIO = io.of('/ssh');
sshIO.on('connection', async (socket) => {
    try {
        const targets = await sessionResolver.resolveTargets(socket.handshake, FALLBACK_TARGETS);
        sshTerminal.handleConnection(socket, targets);
    } catch (error) {
        console.error('Failed to resolve terminal session:', error.message);
        socket.emit('data', `Cannot resolve terminal session: ${error.message}\r\n`);
        socket.disconnect();
    }
});

// Initialize Route Service
const routeService = new RouteService(publicService, vncService);

// Serve static files from the public directory
app.use(express.static(publicService.getPublicDir()));

// Setup VNC proxy (dynamic per-session target)
vncService.setupVNCProxy(app);

// Setup routes
routeService.setupRoutes(app);

// Start the server
server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`VNC proxy fallback: ${VNC_SERVICE_HOST}:${VNC_SERVICE_PORT}`);
    console.log(`SSH fallback: ${SSH_HOST}:${SSH_PORT}`);
    console.log(`Multisession session lookup: ${process.env.FACILITATOR_URL || 'http://facilitator:3000'}`);
});
