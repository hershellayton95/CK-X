const express = require('express');
const examController = require('../controllers/examController');
const { attachSession, requireExamOwnership } = require('../middleware/session');
const { validateCreateExam, validateEvaluateExam, validateExamEvents } = require('../middleware/validators');

const router = express.Router();

/**
 * @route POST /api/v1/exams
 * @desc Create a new exam (multisession: creates/uses the caller's session)
 * @access Public
 */
router.post('/', attachSession, validateCreateExam, examController.createExam);

/**
 * @route GET /api/v1/exams/current
 * @desc Get the current active exam owned by the caller's session
 * @access Public
 */
router.get('/current', attachSession, examController.getCurrentExam);

/**
 * @route GET /api/v1/exams/:examId/assets
 * @desc Get exam assets
 * @access Public
 */
router.get('/:examId/assets', attachSession, requireExamOwnership, examController.getExamAssets);

/**
 * @route GET /api/v1/exams/:examId/questions
 * @desc Get exam questions
 * @access Public
 */
router.get('/:examId/questions', attachSession, requireExamOwnership, examController.getExamQuestions);

/**
 * @route POST /api/v1/exams/:examId/evaluate
 * @desc Evaluate an exam
 * @access Public
 */
router.post('/:examId/evaluate', attachSession, requireExamOwnership, validateEvaluateExam, examController.evaluateExam);

/**
 * @route POST /api/v1/exams/:examId/terminate
 * @desc End an exam
 * @access Public
 */
router.post('/:examId/terminate', attachSession, requireExamOwnership, examController.endExam);

/**
 * @route GET /api/v1/exams/:examId/answers
 * @desc Get exam answers
 * @access Public
 */
router.get('/:examId/answers', attachSession, requireExamOwnership, examController.getExamAnswers);

/**
 * @route GET /api/v1/exams/:examId/status
 * @desc Get exam status
 * @access Public
 */
router.get('/:examId/status', attachSession, requireExamOwnership, examController.getExamStatus);

/**
 * @route GET /api/v1/exams/:examId/result
 * @desc Get exam result
 * @access Public
 */
router.get('/:examId/result', attachSession, requireExamOwnership, examController.getExamResult);

/**
 * @route POST /api/v1/exams/:examId/events
 * @desc Update exam events
 * @access Public
 */
router.post('/:examId/events', attachSession, requireExamOwnership, validateExamEvents, examController.updateExamEvents);

module.exports = router;
