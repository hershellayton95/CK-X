const path = require('path');

class RouteService {
    constructor(publicService, vncService) {
        this.publicService = publicService;
        this.vncService = vncService;
    }

    setupRoutes(app) {
        // Session-aware connection info: which desktop/terminal belongs to the
        // caller. Single-environment deployments get the static config.
        app.get('/api/session-info', async (req, res) => {
            try {
                const vnc = await this.vncService.getVNCInfo(req);
                res.json({
                    ...vnc,
                    terminal: {
                        // The browser terminal is a socket.io connection; the
                        // server resolves the SSH target itself.
                        transport: 'socket.io',
                        namespace: '/ssh',
                        sessionId: vnc.sessionId
                    }
                });
            } catch (error) {
                console.error(`Failed to build session info: ${error.message}`);
                res.status(502).json({
                    error: 'Session lookup failed',
                    message: error.message
                });
            }
        });

        // Backwards-compatible alias used by older frontends.
        app.get('/api/vnc-info', async (req, res) => {
            try {
                res.json(await this.vncService.getVNCInfo(req));
            } catch (error) {
                console.error(`Failed to build VNC info: ${error.message}`);
                res.status(502).json({
                    error: 'Session lookup failed',
                    message: error.message
                });
            }
        });

        // Health check endpoint
        app.get('/health', (req, res) => {
            res.status(200).json({ status: 'ok', message: 'Service is healthy' });
        });

        // Catch-all route to serve index.html for any other requests
        app.get('*', (req, res) => {
            // Special handling for exam page
            if (req.path === '/exam') {
                res.sendFile(path.join(this.publicService.getPublicDir(), 'exam.html'));
            } 
            // Special handling for results page
            else if (req.path === '/results') {
                res.sendFile(path.join(this.publicService.getPublicDir(), 'results.html'));
            }
            else {
                res.sendFile(path.join(this.publicService.getPublicDir(), 'index.html'));
            }
        });

        // Handle errors
        app.use((err, req, res, next) => {
            console.error('Server error:', err);
            res.status(500).sendFile(path.join(this.publicService.getPublicDir(), '50x.html'));
        });
    }
}

module.exports = RouteService;
