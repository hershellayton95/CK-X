/**
 * Exam API Service
 * Handles all API interactions for the exam functionality
 */

// Function to get exam ID from URL
function getExamId() {
    // Extract exam ID from URL parameters
    const urlParams = new URLSearchParams(window.location.search);
    const examId = urlParams.get('id');
    
    if (!examId) {
        console.error('No exam ID found in URL');
        alert('Error: No exam ID provided. Please return to the dashboard.');
        // redirect to dashboard
        window.location.href = '/';
    }
    
    return examId;
}

// Build an Error that keeps the HTTP status so callers can distinguish
// "another session owns this exam" (403) from "exam gone / no session" (404).
function httpError(response) {
    const error = new Error(`HTTP error! Status: ${response.status}`);
    error.status = response.status;
    return error;
}

// Function to check exam status
function checkExamStatus(examId) {
    return fetch(`/facilitator/api/v1/exams/${examId}/status`)
        .then(response => {
            if (!response.ok) {
                throw httpError(response);
            }
            return response.json();
        })
        .then(data => {
            return data.status || null;
        });
}

// Function to fetch exam data
function fetchExamData(examId) {
    const apiUrl = `/facilitator/api/v1/exams/${examId}/questions`;
    
    return fetch(apiUrl)
        .then(response => {
            if (!response.ok) {
                throw httpError(response);
            }
            return response.json();
        })
        .then(data => {
            return data;
        })
        .catch(error => {
            console.error('Error loading exam questions:', error);
            throw error; // Re-throw to be handled by the calling function
        });
}

// Function to fetch current exam information
function fetchCurrentExamInfo() {
    return fetch('/facilitator/api/v1/exams/current')
        .then(response => {
            if (!response.ok) {
                throw httpError(response);
            }
            return response.json();
        })
        .then(data => {
            return data;
        });
}

// Function to evaluate exam
// answers is optional: multiple-choice exams submit their selected options
// (e.g. { "1": "B", "2": "D" }); hands-on labs post an empty body
function evaluateExam(examId, answers = {}) {
    return fetch(`/facilitator/api/v1/exams/${examId}/evaluate`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ answers })
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`HTTP error! Status: ${response.status}`);
        }
        return response.json();
    });
}

// Function to terminate session
function terminateSession(examId) {
    return fetch(`/facilitator/api/v1/exams/${examId}/terminate`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`HTTP error! Status: ${response.status}`);
        }
        return response.json();
    });
}

// Function to get session-aware connection info (desktop + terminal)
function getSessionInfo() {
    return fetch('/api/session-info')
        .then(response => {
            if (!response.ok) {
                throw new Error(`HTTP error! Status: ${response.status}`);
            }
            return response.json();
        })
        .catch(error => {
            console.error('Error fetching session info:', error);
            throw error;
        });
}

// Function to get VNC info (legacy alias)
function getVncInfo() {
    return getSessionInfo();
}

// Session info (desktop/terminal targets for this browser's signed session)
function fetchSessionInfo() {
    return getSessionInfo();
}

// Function to track exam events
function trackExamEvent(examId, events) {
    return fetch(`/facilitator/api/v1/exams/${examId}/events`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ events })
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`HTTP error! Status: ${response.status}`);
        }
        return response.json();
    })
    .catch(error => {
        console.error('Error tracking exam event:', error);
        // Don't throw error to avoid disrupting exam flow
        // But still log it for debugging
    });
}

// Export the API functions
export {
    getExamId,
    checkExamStatus,
    fetchExamData,
    fetchCurrentExamInfo,
    evaluateExam,
    terminateSession,
    getVncInfo,
    getSessionInfo,
    fetchSessionInfo,
    trackExamEvent
}; 