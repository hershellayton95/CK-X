/**
 * Exam Service
 * Handles all business logic for exam operations
 */

const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const logger = require('../utils/logger');
const redisClient = require('../utils/redisClient');
const jumphostService = require('./jumphostService');
const environmentService = require('./environmentService');
const MetricService = require('./metricService');

/**
 * Create a new exam
 * @param {Object} examData - The exam data
 * @param {Object} [options]
 * @param {boolean} [options.multisession=false] - Skip the global
 *   current-exam pointer and allow several exams to coexist
 * @param {string} [options.sessionId] - Owning session; required for a
 *   per-session data plane
 * @returns {Promise<Object>} Result object with success status and data
 */
async function createExam(examData, options = {}) {
  try {
    const multisession = options.multisession === true;

    // In single-environment mode there can be only one active exam at a time.
    // With multisession each exam is owned by a session instead.
    if (!multisession) {
      const currentExamId = await redisClient.getCurrentExamId();

      if (currentExamId) {
        logger.warn(`Attempted to create a new exam while exam ${currentExamId} is still active`);
        return {
          success: false,
          error: 'Exam already exists',
          message: 'Only one exam can be active at a time. End the current exam before creating a new one.',
          currentExamId
        };
      }
    }
    
    const examId = uuidv4();
    
    // fetch exam config from the asset path and append it to the examData
    const examConfig = fs.readFileSync(path.join(process.cwd(),  examData.assetPath, 'config.json'), 'utf8');
    examData.config = JSON.parse(examConfig); 
    delete examData.answers;

    //persist created at time
    examData.createdAt = new Date().toISOString();
    // Store exam information in Redis
    await redisClient.persistExamInfo(examId, examData);
    
    // Set initial exam status
    await redisClient.persistExamStatus(examId, 'CREATED');
    
    // Only the legacy single-environment flow needs the global pointer; in
    // multisession mode the owning session stores the exam ID instead.
    if (!multisession) {
      await redisClient.setCurrentExamId(examId);
    }
    
    logger.info(`Exam created successfully with ID: ${examId}`);
    
    // Multiple-choice exams don't need a Kubernetes cluster: skip environment
    // preparation and mark the exam READY immediately (no warm-up wait)
    if (examData.config.skipClusterSetup) {
      await redisClient.persistExamStatus(examId, 'READY');
      logger.info(`Exam ${examId} marked READY (skipClusterSetup - no cluster needed)`);
    } else {
      // Determine number of nodes required for the exam (default to 1 if not specified)
      const nodeCount = examData.config.workerNodes || 1;
      
      // Set up the exam environment asynchronously
      // This will happen in the background while the response is sent back to the client
      if (multisession && options.sessionId) {
        setupSessionEnvironmentAsync(options.sessionId, examId, nodeCount);
      } else {
        setupExamEnvironmentAsync(examId, nodeCount);
      }
    }
    
    // send metrics to metric server
    MetricService.sendMetrics(examId, {
      category: examData.category,
      labId: examData.config.lab,
      examName: examData.name,
      event: {
        userAgent: examData.userAgent
      }
    });

    return {
      success: true,
      data: {
        id: examId,
        status: 'CREATED',
        message: 'Exam created successfully and environment preparation started'
      }
    };
  } catch (error) {
    logger.error('Error creating exam', { error: error.message });
    return {
      success: false,
      error: 'Failed to create exam',
      message: error.message
    };
  }
}

/**
 * Set up the exam environment asynchronously
 * This function runs in the background and doesn't block the response
 * 
 * @param {string} examId - The exam ID
 * @param {number} nodeCount - Number of nodes to prepare
 */
async function setupExamEnvironmentAsync(examId, nodeCount) {
  try {
    // Call the jumphost service to set up the exam environment
    const result = await jumphostService.setupExamEnvironment(examId, nodeCount);     
    
    if (!result.success) {
      logger.error(`Failed to set up exam environment for exam ${examId}`, {
        error: result.error,
        details: result.details
      });
      // The jumphostService already updates the exam status on failure
      return;
    }
    
    logger.info(`Exam environment set up successfully for exam ${examId}`);
    // The jumphostService already updates the exam status on success
  } catch (error) {
    logger.error(`Unexpected error setting up exam environment for exam ${examId}`, {
      error: error.message
    });
    
    // Update exam status to PREPARATION_FAILED if not already done
    try {
      const currentStatus = await redisClient.getExamStatus(examId);
      if (currentStatus !== 'PREPARATION_FAILED') {
        await redisClient.persistExamStatus(examId, 'PREPARATION_FAILED');
      }
    } catch (statusError) {
      logger.error(`Failed to update exam status for exam ${examId}`, {
        error: statusError.message
      });
    }
  }
}

/**
 * Provision a per-session data plane and prepare the exam on it.
 * Runs in the background so the create-exam response is not blocked.
 *
 * @param {string} sessionId - Owning session
 * @param {string} examId - The exam ID
 * @param {number} nodeCount - Number of worker nodes
 */
async function setupSessionEnvironmentAsync(sessionId, examId, nodeCount) {
  try {
    const result = await environmentService.provisionForExam(sessionId, examId, nodeCount);

    if (!result.success) {
      logger.error(`Failed to set up per-session environment for exam ${examId}`, {
        error: result.error,
        details: result.details
      });
      return;
    }

    logger.info(`Per-session environment ready for exam ${examId}`);
  } catch (error) {
    logger.error(`Unexpected error provisioning environment for exam ${examId}`, {
      error: error.message
    });

    try {
      const currentStatus = await redisClient.getExamStatus(examId);
      if (currentStatus !== 'PREPARATION_FAILED') {
        await redisClient.persistExamStatus(examId, 'PREPARATION_FAILED');
      }
    } catch (statusError) {
      logger.error(`Failed to update exam status for exam ${examId}`, {
        error: statusError.message
      });
    }
  }
}

/**
 * Get the current active exam
 * @param {string} [examId] - Exam owned by the caller's session. When omitted
 *   the legacy global pointer is used.
 * @returns {Promise<Object>} Result object with success status and data
 */
async function getCurrentExam(examId = null) {
  try {
    // In multisession mode the controller passes the session's exam ID.
    const targetExamId = examId || await redisClient.getCurrentExamId();
    
    // based on the path include 
    if (!targetExamId) {
      logger.info('No current exam is set');
      return {
        success: false,
        error: 'Not Found',
        message: 'No current exam is active'
      };
    }
    
    // Get exam information and status
    const examInfo = await redisClient.getExamInfo(targetExamId);
    const examStatus = await redisClient.getExamStatus(targetExamId);
    
    return {
      success: true,
      data: {
        id: targetExamId,
        status: examStatus,
        info: examInfo
      }
    };
  } catch (error) {
    logger.error('Error retrieving current exam', { error: error.message });
    return {
      success: false,
      error: 'Failed to retrieve current exam',
      message: error.message
    };
  }
}

/**
 * Get exam assets
 * @param {string} examId - The exam ID
 * @returns {Promise<Object>} Result object with success status and data
 */
async function getExamAssets(examId) {
  try {
    // Check if exam exists in Redis
    const examInfo = await redisClient.getExamInfo(examId);
    
    if (!examInfo) {
      logger.error(`Exam not found with ID: ${examId}`);
      return {
        success: false,
        error: 'Not Found',
        message: 'Exam not found'
      };
    }
    
    // Placeholder implementation - will be implemented later
    return {
      success: true,
      data: {
        examId,
        assets: []
      }
    };
  } catch (error) {
    logger.error('Error retrieving exam assets', { error: error.message });
    return {
      success: false,
      error: 'Failed to retrieve exam assets',
      message: error.message
    };
  }
}

/**
 * Read the raw assessment questions (including answers) for an asset path
 * Used internally for grading - never expose the result directly to clients
 * @param {string} assetPath - Path to the exam asset directory
 * @returns {Array} Array of question objects
 */
function readRawQuestions(assetPath) {
  const configPath = path.join(process.cwd(), assetPath, 'config.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const questionsFilePath = config.questions || 'assessment.json';
  const fullQuestionsPath = path.join(process.cwd(), assetPath, questionsFilePath);
  const questionsData = fs.readFileSync(fullQuestionsPath, 'utf8');
  return JSON.parse(questionsData).questions || [];
}

/**
 * Get exam questions
 * @param {string} examId - The exam ID
 * @returns {Promise<Object>} Result object with success status and data
 */
async function getExamQuestions(examId) {
  try {
    // Check if exam exists and get status
    const examStatus = await redisClient.getExamStatus(examId);
    const examInfo = await redisClient.getExamInfo(examId);
    
    if (!examStatus || !examInfo) {
      logger.error(`Exam not found with ID: ${examId}`);
      return {
        success: false,
        error: 'Not Found',
        message: 'Exam not found'
      };
    }
    
    // Get asset path from exam info
    const assetPath = examInfo.assetPath;
    if (!assetPath) {
      logger.error(`Asset path not found for exam: ${examId}`);
      return {
        success: false,
        error: 'Configuration Error',
        message: 'Exam asset path not defined'
      };
    }
    
    // Read the config.json file to find the questions.json path
    const configPath = path.join(process.cwd(), assetPath, 'config.json');
    
    if (!fs.existsSync(configPath)) {
      logger.error(`Config file not found at path: ${configPath}`);
      return {
        success: false,
        error: 'File Not Found',
        message: 'Exam configuration file not found'
      };
    }
    
    // Read and parse config.json
    const configData = fs.readFileSync(configPath, 'utf8');
    const config = JSON.parse(configData);
    
    // Get the questions file path from config
    const questionsFilePath = config.questions || 'assessment.json';
    const fullQuestionsPath = path.join(process.cwd(), assetPath, questionsFilePath);
    
    if (!fs.existsSync(fullQuestionsPath)) {
      logger.error(`Questions file not found at path: ${fullQuestionsPath}`);
      return {
        success: false,
        error: 'File Not Found',
        message: 'Exam questions file not found'
      };
    }
    
    // Read the raw questions (including answers - needed for grading)
    const questions = readRawQuestions(assetPath);
    
    // Strip answer-related fields before sending to the browser:
    // multiple-choice labs store `answer` and `explanation` in assessment.json,
    // and students must not be able to read them from the API response
    const sanitizedQuestions = questions.map(q => {
      const safe = { ...q };
      delete safe.answer;
      delete safe.explanation;
      return safe;
    });
    
    logger.info(`Successfully retrieved questions for exam ${examId}`);
    
    return {
      success: true,
      data: {
        questions: sanitizedQuestions
      }
    };
  } catch (error) {
    logger.error('Error retrieving exam questions', { error: error.message });
    return {
      success: false,
      error: 'Failed to retrieve exam questions',
      message: error.message
    };
  }
}

/**
 * Evaluate an exam
 * @param {string} examId - The exam ID
 * @param {Object} evaluationData - The evaluation data
 * @param {Object} [options]
 * @param {Object} [options.session] - Owning session (per-session env)
 * @returns {Promise<Object>} Result object with success status and data
 */
async function evaluateExam(examId, evaluationData, options = {}) {
  const env = options.session && options.session.env ? options.session.env : null;

  try {
    // Playground labs have no questions to grade: "evaluating" one just
    // tears the session down (defensive - the frontend never calls this)
    const examInfo = await redisClient.getExamInfo(examId);
    if (!examInfo) {
      throw new Error(`Exam not found with ID: ${examId}`);
    }
    if (examInfo.config && examInfo.config.labType === 'playground') {
      logger.info(`Playground lab ${examId} evaluated - ending session instead of grading`);
      return await endExam(examId, options);
    }

    // Update exam status to EVALUATING
    await redisClient.updateExamStatus(examId, 'EVALUATING');

    MetricService.sendMetrics(examId, {
      event: {
        examEvaluationState: 'EVALUATING'
      }
    });
    
    // Get assessment path information
    const assetPath = examInfo.assetPath;
    if (!assetPath) {
      throw new Error('Asset path not defined in exam info');
    }
    
    // Get raw questions (including answers) for grading
    const questions = readRawQuestions(assetPath);
    
    // Resolve multiple-choice answers: prefer answers submitted with this
    // evaluation request, otherwise fall back to previously persisted answers
    // (the results page's "Re-evaluate" button posts an empty body)
    let mcqAnswers = (evaluationData && evaluationData.answers) || null;
    if (!mcqAnswers) {
      mcqAnswers = await redisClient.getMcqAnswers(examId);
    }
    mcqAnswers = mcqAnswers || {};
    
    // Persist answers so re-evaluation keeps working after this request
    await redisClient.persistMcqAnswers(examId, mcqAnswers);
    
    // Start evaluation asynchronously using Promise
    // This will happen in the background while the response is sent back to the client
    Promise.resolve().then(async () => {
      try {
        // Call the jumphost service to perform the evaluation
        await jumphostService.evaluateExamOnJumphost(examId, questions, mcqAnswers, env);
      } catch (error) {
        logger.error(`Error in async exam evaluation for exam ${examId}`, { error: error.message });
        // Update exam status to EVALUATION_FAILED
        await redisClient.updateExamStatus(examId, 'EVALUATION_FAILED');
      }
    });
    
    return {
      success: true,
      data: {
        examId,
        status: 'EVALUATING',
        message: 'Exam evaluation started'
      }
    };
  } catch (error) {
    logger.error('Error starting exam evaluation', { error: error.message });
    return {
      success: false,
      error: 'Failed to start exam evaluation',
      message: error.message
    };
  }
}

/**
 * Get exam evaluation result
 * @param {string} examId - The exam ID
 * @returns {Promise<Object>} Result object with success status and data
 */
async function getExamResult(examId) {
  try {
    const result = await redisClient.getExamResult(examId);
    if (!result) {
      logger.warn(`No evaluation result found for exam ${examId}`);
      return {
        success: false,
        error: 'Not Found',
        message: 'Exam evaluation result not found'
      };
    }
    
    return {
      success: true,
      data: result
    };
  } catch (error) {
    logger.error('Error retrieving exam result', { error: error.message });
    return {
      success: false,
      error: 'Failed to retrieve exam result',
      message: error.message
    };
  }
}

/**
 * End an exam
 * @param {string} examId - The exam ID
 * @param {Object} [options]
 * @param {Object} [options.session] - Owning session; when it owns an
 *   environment, the whole per-session stack is destroyed instead of running
 *   the shared jumphost cleanup
 * @returns {Promise<Object>} Result object with success status and data
 */
async function endExam(examId, options = {}) {
  try {
    const session = options.session || null;
    const perSession = !!session;

    // In single-environment mode the exam must be the one pointed to by the
    // global key. In multisession mode the ownership middleware already
    // verified it, and the key is normally unset.
    const currentExamId = await redisClient.getCurrentExamId();
    
    if (currentExamId && currentExamId !== examId) {
      logger.warn(`Attempted to end exam ${examId} but current exam is ${currentExamId}`);
    }

    // Clean up the exam environment
    try {
      if (perSession) {
        // Idempotent: also cleans a partially created stack whose env was
        // never stored on the session.
        await environmentService.destroyForSession(session);
      } else {
        await jumphostService.cleanupExamEnvironment(examId);
      }
      
      // Only clear the global pointer if it still points at this exam.
      if (currentExamId === examId) {
        await redisClient.deleteCurrentExamId();
      }
      await redisClient.deleteAllExamData(examId);
    } catch (cleanupError) {
      logger.error(`Error cleaning up exam environment for exam ${examId}`, {
        error: cleanupError.message
      });
      // Continue with ending the exam even if cleanup fails
    }
    
    logger.info(`Exam ${examId} completed`);
    
    return {
      success: true,
      data: {
        examId,
        status: 'COMPLETED',
        message: 'Exam completed successfully'
      }
    };
  } catch (error) {
    logger.error('Error ending exam', { error: error.message });
    return {
      success: false,
      error: 'Failed to end exam',
      message: error.message
    };
  }
}

module.exports = {
  createExam,
  getCurrentExam,
  getExamAssets,
  getExamQuestions,
  evaluateExam,
  endExam,
  getExamResult
}; 