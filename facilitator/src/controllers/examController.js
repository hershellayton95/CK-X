const logger = require('../utils/logger');
const examService = require('../services/examService');
const sessionService = require('../services/sessionService');
const sessionCookie = require('../utils/sessionCookie');
const config = require('../config');
const fs = require('fs');
const path = require('path');
const redisClient = require('../utils/redisClient');
const MetricService = require('../services/metricService');

/**
 * Create a new exam
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function createExam(req, res) {
  logger.info('Received request to create a new exam', { examData: req.body });
  
  const multisession = config.multisession.enabled;
  let session = req.session || null;

  try {
    if (multisession) {
      // A session can own only one exam. Let the UI resume or terminate it.
      if (session && session.examId) {
        return res.status(409).json({
          error: 'Exam already exists',
          message: 'Your session already has an active exam. Resume or terminate it before starting a new one.',
          currentExamId: session.examId,
          sessionId: session.id
        });
      }

      // Only new sessions consume a slot; retries of a failed create reuse
      // the already-counted session.
      if (!session) {
        const admission = await sessionService.admitSession();
        if (!admission.admitted) {
          logger.warn(`Refusing new session: ${admission.active}/${admission.max} active`);
          res.setHeader('Retry-After', '30');
          return res.status(429).json({
            error: 'Too Many Requests',
            message: `Server busy: ${admission.active}/${admission.max} lab sessions are active. Try again shortly.`,
            activeSessions: admission.active,
            maxSessions: admission.max
          });
        }

        session = await sessionService.createSession({
          status: 'CREATED',
          labId: req.body.id || null,
          labName: req.body.name || null,
          category: req.body.category || null
        });
      } else {
        session = await sessionService.updateSession(session.id, {
          status: 'CREATED',
          labId: req.body.id || null,
          labName: req.body.name || null,
          category: req.body.category || null
        }) || session;
      }
    }

    const result = await examService.createExam(req.body, {
      multisession,
      sessionId: session ? session.id : undefined
    });

    if (!result.success) {
      // Do not leave an empty session behind when provisioning never started.
      if (multisession && session && !session.examId) {
        await sessionService.deleteSession(session.id);
      }

      // Handle the specific case of an exam already existing
      if (result.error === 'Exam already exists') {
        return res.status(409).json({
          error: result.error,
          message: result.message,
          currentExamId: result.currentExamId
        });
      }

      // Handle other errors
      return res.status(500).json({
        error: result.error,
        message: result.message
      });
    }

    if (multisession) {
      const updated = await sessionService.updateSession(session.id, {
        examId: result.data.id,
        status: result.data.status
      });
      session = updated || session;
      req.session = session;
      sessionCookie.setSessionCookie(req, res, session.id);

      return res.status(201).json({
        ...result.data,
        sessionId: session.id
      });
    }

    return res.status(201).json(result.data);
  } catch (error) {
    logger.error('Error creating exam', { error: error.message });

    if (multisession && session && !session.examId) {
      try {
        await sessionService.deleteSession(session.id);
      } catch (cleanupError) {
        logger.error(`Failed to roll back session ${session.id}`, { error: cleanupError.message });
      }
    }

    return res.status(500).json({
      error: 'Failed to create exam',
      message: error.message
    });
  }
}

/**
 * Get the current exam
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function getCurrentExam(req, res) {
  logger.info('Received request to get current exam');
  
  let result;
  if (config.multisession.enabled) {
    // The current exam is whatever the caller's session owns. No cookie (or a
    // session without an exam) behaves like "no current exam" for the UI.
    if (!req.session || !req.session.examId) {
      return res.status(404).json({ message: 'No current exam is active' });
    }

    result = await examService.getCurrentExam(req.session.examId);
    if (result.success) {
      result.data.sessionId = req.session.id;
    }
  } else {
    result = await examService.getCurrentExam();
  }
  
  if (!result.success) {
    if (result.error === 'Not Found') {
      return res.status(404).json({ message: result.message });
    }
    return res.status(500).json({ 
      error: result.error,
      message: result.message
    });
  }
  
  return res.status(200).json(result.data);
}

/**
 * Get exam assets
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function getExamAssets(req, res) {
  const examId = req.params.examId;
  
  logger.info('Received request to get exam assets', { examId });
  
  try {
    // Check if exam exists
    const examInfo = await redisClient.getExamInfo(examId);
    
    if (!examInfo) {
      logger.error(`Exam not found with ID: ${examId}`);
      return res.status(404).json({ 
        error: 'Not Found',
        message: 'Exam not found' 
      });
    }
    
    // Get asset path from exam info
    const assetPath = examInfo.assetPath;
    if (!assetPath) {
      logger.error(`Asset path not found for exam: ${examId}`);
      return res.status(500).json({ 
        error: 'Configuration Error',
        message: 'Exam asset path not defined'
      });
    }
    
    // Construct the path to the assets.zip file (actually a tar archive)
    const assetsZipPath = path.join(process.cwd(), assetPath, 'assets.tar.gz');
    
    if (!fs.existsSync(assetsZipPath)) {
      logger.error(`Assets file not found at path: ${assetsZipPath}`);
      return res.status(500).json({ 
        error: 'File Not Found',
        message: 'Exam assets file not found'
      });
    }
    
    logger.info(`Sending assets file for exam ${examId} from path ${assetsZipPath}`);
    
    // Set the content type for tar.gz file and send it
    res.setHeader('Content-Type', 'application/gzip');
    res.setHeader('Content-Disposition', `attachment; filename="assets-${examId}.tar.gz"`);
    return res.sendFile(assetsZipPath);
  } catch (error) {
    logger.error('Error retrieving exam assets', { error: error.message });
    return res.status(500).json({ 
      error: 'Failed to retrieve exam assets',
      message: error.message
    });
  }
}

/**
 * Get exam questions
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function getExamQuestions(req, res) {
  const examId = req.params.examId;
  
  logger.info('Received request to get exam questions', { examId });
  
  const result = await examService.getExamQuestions(examId);
  
  if (!result.success) {
    if (result.error === 'Not Found') {
      return res.status(404).json({ error: 'Exam not found' });
    }
    return res.status(500).json({ 
      error: result.error,
      message: result.message
    });
  }
  
  return res.status(200).json(result.data);
}

/**
 * Evaluate an exam
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function evaluateExam(req, res) {
  const examId = req.params.examId;
  
  logger.info('Received request to evaluate exam', { examId, data: req.body });
  
  const result = await examService.evaluateExam(examId, req.body, { session: req.session });
  
  if (!result.success) {
    return res.status(500).json({ 
      error: result.error,
      message: result.message
    });
  }
  
  return res.status(200).json(result.data);
}

/**
 * End an exam
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function endExam(req, res) {
  const examId = req.params.examId;
  
  logger.info('Received request to end exam', { examId });

  // Multisession: destroying a session stack removes its Docker network, and
  // that resets the HTTP connection this response is travelling on (clients
  // see an empty reply). Free the session, answer, then tear the environment
  // down in the background; startup reconciliation handles stacks left behind
  // by a crash.
  if (config.multisession.enabled && req.session) {
    try {
      await sessionService.deleteSession(req.session.id);
      sessionCookie.clearSessionCookie(req, res);
    } catch (error) {
      logger.error(`Exam ${examId} ended but session ${req.session.id} could not be removed`, {
        error: error.message
      });
    }

    res.status(200).json({
      examId,
      status: 'COMPLETED',
      message: 'Exam completed successfully'
    });

    examService.endExam(examId, { session: req.session })
      .then(result => {
        if (!result.success) {
          logger.error(`Background cleanup failed for exam ${examId}`, { error: result.error });
        }
      })
      .catch(error => {
        logger.error(`Background cleanup failed for exam ${examId}`, { error: error.message });
      });
    return;
  }

  const result = await examService.endExam(examId, { session: req.session });
  
  if (!result.success) {
    return res.status(500).json({ 
      error: result.error,
      message: result.message
    });
  }

  return res.status(200).json(result.data);
}

/**
 * Get exam answers
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function getExamAnswers(req, res) {
  const examId = req.params.examId;
  
  logger.info('Received request to get exam answers', { examId });
  
  try {
    // Check if exam exists
    const examInfo = await redisClient.getExamInfo(examId);
    
    if (!examInfo) {
      logger.error(`Exam not found with ID: ${examId}`);
      return res.status(404).json({ 
        error: 'Not Found',
        message: 'Exam not found' 
      });
    }
    
    // Get answers path directly from the exam info config
    if (!examInfo.config || !examInfo.config.answers) {
      logger.error(`Answers path not found in config for exam: ${examId}`);
      return res.status(500).json({ 
        error: 'Configuration Error',
        message: 'Answers path not defined in exam configuration'
      });
    }
    
    const answersFilePath = examInfo.config.answers;
    const fullAnswersPath = path.join(process.cwd(), answersFilePath);
    
    if (!fs.existsSync(fullAnswersPath)) {
      logger.error(`Answers file not found at path: ${fullAnswersPath}`);
      return res.status(500).json({ 
        error: 'File Not Found',
        message: 'Exam answers file not found'
      });
    }
    
    logger.info(`Sending answers file for exam ${examId} from path ${fullAnswersPath}`);
    
    // Send the file directly instead of a JSON response
    return res.sendFile(fullAnswersPath);
  } catch (error) {
    logger.error('Error retrieving exam answers', { error: error.message });
    return res.status(500).json({ 
      error: 'Failed to retrieve exam answers',
      message: error.message
    });
  }
}

/**
 * Get exam status
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function getExamStatus(req, res) {
  const examId = req.params.examId;
  
  logger.info('Received request to get exam status', { examId });
  
  try {
    // Check if exam exists
    const examInfo = await redisClient.getExamInfo(examId);
    //get exam status form redis
    const examStatus = await redisClient.getExamStatus(examId);
    
    if (!examInfo) {
      logger.error(`Exam not found with ID: ${examId}`);
      return res.status(404).json({ 
        error: 'Not Found',
        message: 'Exam not found' 
      });
    }

    // Return the exam status and any additional info
    return res.status(200).json({
      id: examId,
      status: examStatus || 'UNKNOWN',
      warmUpTimeInSeconds: examInfo.warmUpTimeInSeconds || 30,
      message: examStatus === 'READY' ? 'Exam environment is ready' : 'Exam environment is being prepared'
    });
  } catch (error) {
    logger.error('Error retrieving exam status', { error: error.message });
    return res.status(500).json({ 
      error: 'Failed to retrieve exam status',
      message: error.message
    });
  }
}

/**
 * Get exam result
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function getExamResult(req, res) {
  const examId = req.params.examId;
  
  logger.info('Received request to get exam result', { examId });
  
  const result = await examService.getExamResult(examId);
  
  if (!result.success) {
    // Handle the case when result isn't found
    if (result.error === 'Not Found') {
      return res.status(404).json({
        error: result.error,
        message: result.message
      });
    }
    
    // Handle other errors
    return res.status(500).json({
      error: result.error,
      message: result.message
    });
  }
  
  return res.status(200).json(result);
}

/**
 * Update exam events
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function updateExamEvents(req, res) {
  const examId = req.params.examId;
  const { events } = req.body;
  
  logger.info('Received request to update exam events', { examId, events });
  
  try {
    // Get the current exam info
    const examInfo = await redisClient.getExamInfo(examId);
    
    if (!examInfo) {
      logger.error(`Exam not found with ID: ${examId}`);
      return res.status(404).json({ 
        error: 'Not Found',
        message: 'Exam not found' 
      });
    }
    
    // Update the events in the exam info
    if (!examInfo.events) {
      examInfo.events = {};
    }
    
    // Merge the events from the request with existing events
    examInfo.events = {
      ...examInfo.events,
      ...events
    };
    
    // send metrics to metric server
    MetricService.sendMetrics(examId, {
      event: {
        ...examInfo.events
      }
    });

    // Update the exam info in Redis
    await redisClient.updateExamInfo(examId, examInfo);
    
    // Return success response with the same structure as other endpoints
    return res.status(200).json({
      success: true,
      data: {
        id: examId,
        message: 'Exam events updated successfully'
      }
    });
  } catch (error) {
    logger.error('Error updating exam events', { error: error.message });
    return res.status(500).json({ 
      success: false,
      error: 'Failed to update exam events',
      message: error.message
    });
  }
}

/**
 * Submit feedback metrics for an exam
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function submitMetrics(req, res) {
  const examId = req.params.examId;
  const feedbackData = req.body;
  
  logger.info('Received feedback metrics submission', { examId, type: feedbackData.type });
  
  try {
    // Send the feedback data to the metric service
    const result = await MetricService.sendMetrics(examId, { event: { ...feedbackData } });
    
    return res.status(200).json({ 
      success: true,
      message: 'Feedback submitted successfully'
    });
  } catch (error) {
    logger.error('Error submitting feedback metrics', { error: error.message });
    return res.status(500).json({ 
      error: 'Failed to submit feedback',
      message: error.message
    });
  }
}

module.exports = {
  createExam,
  getCurrentExam,
  getExamAssets,
  getExamQuestions,
  evaluateExam,
  endExam,
  getExamAnswers,
  getExamStatus,
  getExamResult,
  updateExamEvents,
  submitMetrics
}; 