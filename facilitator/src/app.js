const express = require('express');
const morgan = require('morgan');
const helmet = require('helmet');
const cors = require('cors');
const config = require('./config');
const logger = require('./utils/logger');
const redisClient = require('./utils/redisClient');
const environmentService = require('./services/environmentService');
const sessionService = require('./services/sessionService');
const sessionReaper = require('./services/sessionReaper');
const sessionMetrics = require('./utils/sessionMetrics');
const { validateConfig } = require('./utils/validateConfig');

// Fail before binding the port when multisession secrets are missing/weak in
// production. In development this only logs warnings.
try {
  validateConfig();
} catch (error) {
  logger.error(error.message);
  process.exit(1);
}

// Import routes
const sshRoutes = require('./routes/sshRoutes');
const sessionRoutes = require('./routes/sessionRoutes');
const examRoutes = require('./routes/examRoutes');
const assessmentRoutes = require('./routes/assessmentRoutes');
const remoteDesktopRoutes = require('./routes/remoteDesktopRoutes');

// Initialize Express app
const app = express();

// Apply middleware
app.use(helmet()); // Security headers
app.use(cors()); // Enable CORS for all routes
app.use(express.json()); // Parse JSON request bodies
app.use(express.urlencoded({ extended: true })); // Parse URL-encoded request bodies

// HTTP request logging
app.use(morgan('combined', { 
  stream: { 
    write: message => logger.http(message.trim()) 
  } 
}));

// API routes
app.use('/api/v1', sshRoutes);
app.use('/api/v1/sessions', sessionRoutes);
app.use('/api/v1/exams', examRoutes);
app.use('/api/v1/assements', assessmentRoutes);
app.use('/api/v1/remote-desktop', remoteDesktopRoutes);

// Root route
app.get('/', (req, res) => {
  res.json({
    message: 'Facilitator Service API',
    version: '1.0.0'
  });
});

// 404 Handler
app.use((req, res) => {
  logger.warn(`Route not found: ${req.method} ${req.originalUrl}`);
  res.status(404).json({
    error: 'Not Found',
    message: `The requested resource ${req.originalUrl} was not found`
  });
});

// Error handler
app.use((err, req, res, next) => {
  logger.error('Unhandled error', { error: err.message, stack: err.stack });
  res.status(500).json({
    error: 'Internal Server Error',
    message: config.env === 'development' ? err.message : 'An unexpected error occurred'
  });
});

// Initialize Redis connection
(async () => {
  try {
    await redisClient.connect();
    logger.info('Redis connected successfully');

    // Remove data-plane stacks left behind by a crash/restart. Runs only in
    // multisession mode, where the facilitator owns those stacks.
    if (config.multisession.enabled) {
      try {
        await environmentService.reconcile();
      } catch (error) {
        logger.error(`Environment reconciliation failed: ${error.message}`);
      }

      try {
        sessionMetrics.setActiveSessions(await sessionService.countActiveSessions());
      } catch (error) {
        logger.debug(`Could not initialise active session gauge: ${error.message}`);
      }

      sessionReaper.start();
    }
  } catch (error) {
    logger.error(`Redis connection failed: ${error.message}`);
  }
})();

// Start the server
const PORT = config.port;
app.listen(PORT, () => {
  logger.info(`Server running in ${config.env} mode on port ${PORT}`);
});

module.exports = app; // Export for testing 