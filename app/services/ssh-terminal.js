const { Client } = require('ssh2');

/**
 * Browser terminal.
 *
 * One SSH connection per browser socket. In multisession mode the webapp
 * passes the target and credentials resolved from the caller's session, so
 * each browser lands in its own session's terminal container.
 */
class SSHTerminal {
    constructor(config) {
        this.defaultConfig = {
            host: config.host || 'remote-terminal',
            port: config.port || 22,
            username: config.username || 'candidate',
            password: config.password || 'password',
            readyTimeout: 30000,
            keepaliveInterval: 10000
        };
    }

    /**
     * @param {Object} socket - socket.io socket
     * @param {Object} [targets] - { sshHost, sshPort, sshPassword } from the session
     */
    handleConnection(socket, targets = {}) {
        const config = {
            ...this.defaultConfig,
            host: targets.sshHost || this.defaultConfig.host,
            port: targets.sshPort || this.defaultConfig.port,
            password: targets.sshPassword || this.defaultConfig.password
        };

        console.log(`New SSH terminal connection for ${config.host}:${config.port}` +
            (targets.sessionId ? ` (session ${targets.sessionId})` : ''));

        let ssh = new Client();

        ssh.on('ready', () => {
            console.log('SSH connection established');
            this.createShellSession(ssh, socket);
        });

        ssh.on('error', (err) => {
            console.error('SSH connection error:', err);
            socket.emit('data', `SSH connection error: ${err.message}\r\n`);
            socket.disconnect();
        });

        ssh.connect(config);
    }

    createShellSession(ssh, socket) {
        ssh.shell((err, stream) => {
            if (err) {
                console.error('SSH shell error:', err);
                socket.emit('data', `Error: ${err.message}\r\n`);
                socket.disconnect();
                return;
            }

            this.setupStreamHandlers(stream, socket, ssh);
        });
    }

    setupStreamHandlers(stream, socket, ssh) {
        stream.on('data', (data) => {
            socket.emit('data', data.toString('utf-8'));
        });

        stream.on('close', () => {
            console.log('SSH stream closed');
            ssh.end();
            socket.disconnect();
        });

        stream.on('error', (err) => {
            console.error('SSH stream error:', err);
            socket.emit('data', `Error: ${err.message}\r\n`);
        });

        socket.on('data', (data) => {
            stream.write(data);
        });

        socket.on('resize', (dimensions) => {
            if (dimensions && dimensions.cols && dimensions.rows) {
                stream.setWindow(dimensions.rows, dimensions.cols, 0, 0);
            }
        });

        socket.on('disconnect', () => {
            console.log('Client disconnected from SSH terminal');
            stream.close();
            ssh.end();
        });
    }
}

module.exports = SSHTerminal;
