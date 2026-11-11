const { createProxyMiddleware } = require('http-proxy-middleware');
const sessionResolver = require('./session-resolver');

/**
 * VNC proxy.
 *
 * In single-environment mode the target and password come from the container
 * environment. With multisession enabled the target is resolved per request
 * from the caller's signed session cookie (via the facilitator), so two
 * browsers on the same webapp reach different desktops.
 */
class VNCService {
    constructor(config) {
        this.fallback = {
            vncHost: config.host || 'remote-desktop',
            vncPort: config.port || 6901,
            vncPassword: config.password || 'bakku-the-wizard'
        };

        this.vncProxyConfig = {
            target: `http://${this.fallback.vncHost}:${this.fallback.vncPort}`,
            changeOrigin: true,
            ws: true,
            secure: false,
            pathRewrite: {
                '^/vnc-proxy': ''
            },
            router: (req) => this.resolveTarget(req),
            onProxyReq: (proxyReq, req, res) => {
                console.log(`Proxying HTTP request to VNC server: ${req.url}`);
            },
            onProxyReqWs: (proxyReq, req, socket, options, head) => {
                console.log(`WebSocket connection established to VNC server: ${req.url}`);
            },
            onProxyRes: (proxyRes, req, res) => {
                console.log(`Received response from VNC server for: ${req.url}`);
            },
            onError: (err, req, res) => {
                console.error(`Proxy error: ${err.message}`);
                if (res && res.writeHead) {
                    res.writeHead(502, {
                        'Content-Type': 'text/plain'
                    });
                    res.end(`Proxy error: ${err.message}`);
                }
            }
        };
    }

    /**
     * Resolve the proxy target for one request (HTTP or WebSocket upgrade).
     * http-proxy-middleware awaits async routers.
     */
    async resolveTarget(req) {
        const targets = await sessionResolver.resolveTargets(req, this.fallback);
        req._ckxTargets = targets;
        console.log(`VNC proxy target: ${targets.vncHost}:${targets.vncPort} ` +
            `(session ${targets.sessionId || 'single-environment'})`);
        return `http://${targets.vncHost}:${targets.vncPort}`;
    }

    setupVNCProxy(app) {
        app.use('/vnc-proxy', createProxyMiddleware(this.vncProxyConfig));

        // Direct WebSocket proxy for the websockify endpoint
        app.use('/websockify', createProxyMiddleware({
            ...this.vncProxyConfig,
            pathRewrite: {
                '^/websockify': '/websockify'
            },
            ws: true,
            onProxyReqWs: (proxyReq, req, socket, options, head) => {
                console.log(`WebSocket connection to websockify established: ${req.url}`);
                const targets = req._ckxTargets || this.fallback;
                proxyReq.setHeader('Origin', `http://${targets.vncHost}:${targets.vncPort}`);
            },
            onError: (err, req, res) => {
                console.error(`Websockify proxy error: ${err.message}`);
                if (res && res.writeHead) {
                    res.writeHead(502, {
                        'Content-Type': 'text/plain'
                    });
                    res.end(`Websockify proxy error: ${err.message}`);
                }
            }
        }));
    }

    async getVNCInfo(req) {
        const targets = await sessionResolver.resolveTargets(req, this.fallback);
        return {
            host: targets.vncHost,
            port: targets.vncPort,
            wsUrl: `/websockify`,
            defaultPassword: targets.vncPassword,
            sessionId: targets.sessionId,
            multisession: targets.multisession,
            status: 'connected'
        };
    }
}

module.exports = VNCService;
