# Contributing Labs to CK-X Simulator

This guide explains how to create and contribute your own practice labs for the CK-X Simulator. By following these steps, you can create custom assessment scenarios for Kubernetes certification preparation (CKAD, CKA, CKS) or other container-related topics.

## Lab Structure Overview

Each lab in CK-X Simulator consists of:

1. **Lab Entry** in the main labs registry
2. **Configuration File** for lab settings
3. **Assessment File** containing questions and verification steps
4. **Setup and Verification Scripts** to prepare environments and validate student solutions
5. **Answers File** with solution documentation

# Considerations Before Creating a Lab
1. The cluster will consist of one control-plane node and multiple worker nodes.
2. SSH access to the nodes is not provided, which may restrict the development of labs that require access to Kubernetes internals or node internals.
3. Setup scripts run sequentially in filename order (only `q*_setup.sh`), so questions should still be independent of each other.
4. Limit the setup to a maximum of two worker nodes to reduce system resource consumption during the exam.
5. When creating files in the cluster, use the /tmp/exam directory. This directory will be created during setup and removed during cleanup.

### Multisession compatibility

Labs must work when 2–5 candidates run concurrently, each with a complete data
plane (own cluster, jumphost, desktop, terminal):

- Use in-cluster resources and internal service names. Do not assume a global
  cluster identity or that you are the only lab running.
- Only nginx is published, at `http://localhost:30080`. Never hardcode
  `localhost:30080` or any host port inside setup/validation scripts; the
  address belongs to the deployment, not the lab. Use `kubectl` and cluster
  service names instead.
- Do not rely on state from another lab or session. Use one namespace per
  question and keep scratch files under `/tmp/exam`.
- Per-session volumes/containers are destroyed with the session; do not depend
  on anything outside the session's own cluster or `/tmp/exam` surviving.


## Step 1: Create Lab Directory Structure

First, create a directory structure for your lab using this pattern:

```
facilitator/
└── assets/
    └── exams/
        └── [category]/
            └── [id]/
                ├── config.json
                ├── assessment.json
                ├── answers.md
                └── scripts/
                    ├── setup/
                    │   └── [setup scripts]
                    └── validation/
                        └── [verification scripts]
```

Where:
- `[category]` is the certification type (e.g., `ckad`, `cka`, `cks`, `other`)
- `[id]` is a numeric identifier (e.g., `001`, `002`)

For example, to create a new CKAD lab with ID 003:
```
facilitator/assets/exams/ckad/003/
```

## Step 2: Create Configuration File

Create a `config.json` file in your lab directory with the following structure:

```json
{
  "lab": "ckad-003",
  "workerNodes": 1,
  "answers": "assets/exams/ckad/003/answers.md",
  "questions": "assessment.json",
  "totalMarks": 100,
  "lowScore": 40,
  "mediumScore": 60,
  "highScore": 90
}
```

Parameters:
- `lab`: Unique identifier for the lab (should match directory structure)
- `workerNodes`: Number of worker nodes required for this lab
- `answers`: Path to answers markdown file
- `questions`: Assessment JSON filename
- `totalMarks`: Maximum possible score
- `lowScore`, `mediumScore`, `highScore`: Score thresholds for result categorization

## Step 3: Create Assessment File

Create an `assessment.json` file that defines questions, namespaces, and verification steps:

```json
{
  "questions": [
    {
      "id": "1",
      "namespace": "default",
      "machineHostname": "node01",
      "question": "Create a deployment named `nginx-deploy` with 3 replicas using the nginx:1.19 image.\n\nEnsure the deployment is created in the `default` namespace.",
      "concepts": ["deployments", "replication"],
      "verification": [
        {
          "id": "1",
          "description": "Deployment exists",
          "verificationScriptFile": "q1_s1_validate_deployment.sh",
          "expectedOutput": "0",
          "weightage": 2
        },
        {
          "id": "2",
          "description": "Deployment has 3 replicas",
          "verificationScriptFile": "q1_s2_validate_replicas.sh",
          "expectedOutput": "0",
          "weightage": 1
        },
        {
          "id": "3",
          "description": "Deployment uses correct image",
          "verificationScriptFile": "q1_s3_validate_image.sh",
          "expectedOutput": "0",
          "weightage": 1
        }
      ]
    }
    // Add more questions...
  ]
}
```

Each question should include:
- `id`: Unique question identifier
- `namespace`: Kubernetes namespace for the question
- `machineHostname`: The hostname to display for SSH connection
- `question`: The actual task description with formatting:
  - Use `\n` for line breaks to improve readability
  - Put code references, commands, or file paths in backtick (e.g., `nginx:1.19`) which will be highlighted in the UI
  - Structure your question with clear paragraphs separated by blank lines
- `concepts`: Array of concepts/topics covered
- `verification`: Array of verification steps

Each verification step includes:
- `id`: Unique step identifier
- `description`: Human-readable description of what's being checked
- `verificationScriptFile`: Script file path to validate the step (present in /scripts/validation directory)
- `expectedOutput`: Expected return code (usually "0" for success)
- `weightage`: Point value for this verification step

## Step 4: Create Setup and Verification Scripts

The CK-X Simulator uses two types of scripts:

### Setup Scripts

Create setup scripts in the `scripts/setup/` directory to prepare the environment for each question. These scripts run before the student starts the exam to ensure the necessary resources are available.

Example setup script (`scripts/setup/q1_setup.sh`):

```bash
#!/bin/bash
# Setup environment for Question 1

# Create namespace if it doesn't exist
kubectl create namespace default --dry-run=client -o yaml | kubectl apply -f -

# Create any prerequisite resources
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: default
data:
  nginx.conf: |
    server {
      listen 80;
      server_name localhost;
      location / {
        root /usr/share/nginx/html;
        index index.html;
      }
    }
EOF

echo "Environment setup complete for Question 1"
exit 0
```

### Verification Scripts

Create verification scripts in the `scripts/validation/` directory to validate student solutions. Each script should:

1. Check a specific aspect of the solution
2. Return exit code 0 for success, non-zero for failure
3. Output useful information for student feedback

Example verification script (`scripts/validation/q1_s1_validate_deployment.sh`):

```bash
#!/bin/bash
# Check if deployment exists

DEPLOYMENT_NAME="nginx-deploy"
NAMESPACE="default"

kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE &> /dev/null
if [ $? -eq 0 ]; then
  echo "✅ Deployment '$DEPLOYMENT_NAME' exists in namespace '$NAMESPACE'"
  exit 0
else
  echo "❌ Deployment '$DEPLOYMENT_NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi
```

## Step 5: Create Answers File

Create an `answers.md` file containing solutions to your questions. This file will be displayed directly to students when they view the exam answers.

Focus on providing clear, educational solutions with detailed explanations. The file is rendered as standard Markdown, so you can use all Markdown formatting features. Include complete solution commands, explanations of why certain approaches work, and any relevant tips or best practices.

For each question, provide the question text as a heading followed by a comprehensive solution that would help someone understand not just what to do but why that approach is correct.

## Step 6: Register Your Lab

Finally, add your lab to the main `labs.json` file:

```json
{
  "labs": [
    // ... existing labs ...
    {
      "id": "ckad-003",
      "assetPath": "assets/exams/ckad/003",
      "name": "CKAD Practice Lab - Advanced Deployments",
      "category": "CKAD",
      "description": "Practice advanced deployment patterns and strategies",
      "warmUpTimeInSeconds": 60,
      "difficulty": "medium"
    }
  ]
}
```

Parameters:
- `id`: Unique identifier (should match directory structure)
- `assetPath`: Path to lab resources
- `name`: Display name for the lab
- `category`: Lab category (CKAD, CKA, CKS, etc.)
- `description`: Brief description of the lab content
- `warmUpTimeInSeconds`: Preparation time before exam starts
- `difficulty`: Difficulty level (easy, medium, hard)

## Multiple-Choice (MCQ) Labs

Labs can also be pure multiple-choice mock exams (like `kcna-001`) that need no cluster, no setup scripts, and no verification scripts. Questions are graded in the facilitator from the answers submitted with the evaluate call.

### config.json

```json
{
  "lab": "kcna-001",
  "skipClusterSetup": true,
  "answers": "assets/exams/kcna/001/answers.md",
  "questions": "assessment.json",
  "totalMarks": 60,
  "lowScore": 45,
  "mediumScore": 52,
  "highScore": 57
}
```

- `skipClusterSetup: true` marks the exam READY immediately - no k3d cluster is created and `warmUpTimeInSeconds` should be small (e.g. `10`).

### assessment.json question format

```json
{
  "id": "1",
  "type": "mcq",
  "domain": "Kubernetes Fundamentals",
  "question": "Which component exposes the Kubernetes API?",
  "options": ["kube-scheduler", "kube-apiserver", "etcd", "kubelet"],
  "answer": "B",
  "explanation": "The kube-apiserver is the control plane entry point.",
  "concepts": ["control-plane", "kube-apiserver"]
}
```

- `answer` is the **letter** of the correct option (A-D).
- `domain` powers the domain-wise performance breakdown on the results page - group questions by exam blueprint area.
- `answer` and `explanation` are **stripped server-side** before questions reach the browser (students can't read them from the API), and explanations are revealed on the results page after grading.
- Each question is worth 1 point; `totalPossibleScore` equals the question count.

### How grading works

The webapp submits the selected options with the evaluate call (`{ answers: { "1": "B", ... } }`). The facilitator grades them locally (no SSH, no jumphost) and merges them into the standard result shape, so the results page shows per-question correctness, explanations, and the domain breakdown. Answers are persisted in Redis so the results page's *Re-evaluate* button keeps working. Results show pass/fail against a 75% pass mark.

## Playground Labs

A playground (like `playground-001`) is a question-free sandbox: a real multi-node cluster with a countdown timer and a full-width terminal. There is no grading and no results page.

### config.json

```json
{
  "lab": "playground-001",
  "workerNodes": 2,
  "labType": "playground",
  "questions": "assessment.json"
}
```

- `labType: "playground"` is the flag everything keys off. The cluster **is** provisioned (that is the point), so do **not** set `skipClusterSetup`.
- `assessment.json` is just `{ "questions": [] }` - the empty list keeps every existing endpoint working.

### How it behaves

- **Registry**: add a `labs.json` entry with its own category (e.g. `Playground`) and `examDurationInMinutes` - this is the hard-stop session length (minutes).
- **Frontend** (`app/public/js/exam.js`): when `labType === 'playground'`, the question panel and divider are hidden, the start/confirm/end modals use session wording, and the timer's 0:00 handler calls `terminateSession` (not `evaluate`) - the cluster is deleted immediately and the end modal offers *Back to Home* instead of *View Results*. The **End Session** button follows the same terminate path.
- **Facilitator**: `evaluateExam` detects a playground and delegates to `endExam` instead of grading - a defensive guard, since the frontend never calls evaluate for a sandbox.

## Best Practices

1. **Realistic Scenarios**: Design questions that mimic real certification exam tasks
2. **Clear Instructions**: Write concise, unambiguous question descriptions
3. **Thorough Verification**: Create scripts that verify all aspects of the solution
4. **Comprehensive Answers**: Provide complete, educational solutions
5. **Progressive Difficulty**: Arrange questions from simple to complex
6. **Namespaces**: Use separate namespaces for different questions to avoid conflicts
7. **Resource Requirements**: Keep resource requirements reasonable

## Testing Your Lab

Before submitting your lab:

1. Build and deploy the simulator with your new lab
2. Go through each question as a student would
3. Verify that all verification scripts work correctly
4. Ensure the answers solve the questions as expected
5. Check that scoring and evaluation work properly

## Contribution Process

1. Fork the CK-X Simulator repository
2. Add your lab following these guidelines
3. Test thoroughly
4. Submit a pull request with a description of your lab

Thank you for contributing to the CK-X community! 