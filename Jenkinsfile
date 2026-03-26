// ─────────────────────────────────────────────────────────────
//  LUXE SHOP — Jenkins CI/CD Pipeline
//  Flow: Checkout → Lint → Build Docker → Test → Push ECR/DockerHub → Deploy EC2
// ─────────────────────────────────────────────────────────────

pipeline {
    agent any

    // ── Configurable variables ────────────────────────────────
    environment {
        APP_NAME        = "luxe-shop"
        DOCKER_IMAGE    = "${DOCKERHUB_USERNAME}/${APP_NAME}"   // Change to ECR URL if using AWS ECR
        IMAGE_TAG       = "${BUILD_NUMBER}-${GIT_COMMIT[0..6]}"
        CONTAINER_PORT  = "80"
        HOST_PORT       = "80"
        EC2_USER        = "ubuntu"                              // or "ec2-user" for Amazon Linux
        CONTAINER_NAME  = "luxe-shop-app"
    }

    // ── Build triggers ────────────────────────────────────────
    triggers {
        githubPush()          // trigger on every GitHub push
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    // ═══════════════════════════════════════════════════════════
    stages {

        // ── 1. CHECKOUT ───────────────────────────────────────
        stage('Checkout') {
            steps {
                echo "📥 Checking out source code..."
                checkout scm
                sh 'echo "Branch: $GIT_BRANCH  |  Commit: $GIT_COMMIT"'
            }
        }

        // ── 2. LINT / VALIDATE ────────────────────────────────
        stage('Lint & Validate') {
            steps {
                echo "🔍 Validating HTML and Dockerfile..."
                sh '''
                    # Validate Dockerfile exists
                    [ -f Dockerfile ] && echo "✅ Dockerfile found" || (echo "❌ Dockerfile missing" && exit 1)

                    # Validate index.html exists
                    [ -f src/index.html ] && echo "✅ src/index.html found" || (echo "❌ src/index.html missing" && exit 1)

                    # Validate nginx config exists
                    [ -f nginx/nginx.conf ] && echo "✅ nginx.conf found" || (echo "❌ nginx.conf missing" && exit 1)

                    echo "✅ Validation passed"
                '''
            }
        }

        // ── 3. BUILD DOCKER IMAGE ─────────────────────────────
        stage('Build Docker Image') {
            steps {
                echo "🐳 Building Docker image: ${DOCKER_IMAGE}:${IMAGE_TAG}"
                sh '''
                    docker build \
                        --no-cache \
                        --label "build.number=${BUILD_NUMBER}" \
                        --label "git.commit=${GIT_COMMIT}" \
                        --label "build.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                        -t ${DOCKER_IMAGE}:${IMAGE_TAG} \
                        -t ${DOCKER_IMAGE}:latest \
                        .
                '''
            }
        }

        // ── 4. TEST CONTAINER ─────────────────────────────────
        stage('Test Container') {
            steps {
                echo "🧪 Running container smoke tests..."
                sh '''
                    # Start container on a test port
                    docker run -d \
                        --name ${APP_NAME}-test-${BUILD_NUMBER} \
                        -p 8099:80 \
                        ${DOCKER_IMAGE}:${IMAGE_TAG}

                    # Wait for container to be ready
                    sleep 5

                    # Health check
                    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8099/health)
                    echo "Health endpoint returned: $HTTP_STATUS"

                    # Index check
                    INDEX_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8099/)
                    echo "Index page returned: $INDEX_STATUS"

                    # Assert 200
                    [ "$HTTP_STATUS" = "200" ] && echo "✅ Health check passed" || (echo "❌ Health check FAILED" && exit 1)
                    [ "$INDEX_STATUS" = "200" ] && echo "✅ Index check passed"  || (echo "❌ Index check FAILED"  && exit 1)
                '''
            }
            post {
                always {
                    sh '''
                        docker stop  ${APP_NAME}-test-${BUILD_NUMBER} || true
                        docker rm    ${APP_NAME}-test-${BUILD_NUMBER} || true
                    '''
                }
            }
        }

        // ── 5. PUSH TO REGISTRY ───────────────────────────────
        stage('Push to Registry') {
            steps {
                echo "📦 Pushing image to Docker Hub..."
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DOCKERHUB_USERNAME',
                    passwordVariable: 'DOCKERHUB_PASSWORD'
                )]) {
                    sh '''
                        echo "$DOCKERHUB_PASSWORD" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
                        docker push ${DOCKER_IMAGE}:${IMAGE_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                        echo "✅ Image pushed: ${DOCKER_IMAGE}:${IMAGE_TAG}"
                    '''
                }
            }
        }

        // ── 6. DEPLOY TO EC2 ──────────────────────────────────
        stage('Deploy to EC2') {
            steps {
                echo "🚀 Deploying to EC2..."
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'SSH_KEY'
                    ),
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKERHUB_USERNAME',
                        passwordVariable: 'DOCKERHUB_PASSWORD'
                    )
                ]) {
                    sh '''
                        ssh -i $SSH_KEY \
                            -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} << EOF

                            echo "🐳 Logging into Docker Hub on EC2..."
                            echo "${DOCKERHUB_PASSWORD}" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin

                            echo "📥 Pulling latest image..."
                            docker pull ${DOCKER_IMAGE}:${IMAGE_TAG}

                            echo "🔄 Stopping old container (if running)..."
                            docker stop ${CONTAINER_NAME} || true
                            docker rm   ${CONTAINER_NAME} || true

                            echo "▶️  Starting new container..."
                            docker run -d \
                                --name ${CONTAINER_NAME} \
                                --restart unless-stopped \
                                -p ${HOST_PORT}:${CONTAINER_PORT} \
                                ${DOCKER_IMAGE}:${IMAGE_TAG}

                            echo "🧹 Cleaning up old images..."
                            docker image prune -f

                            echo "✅ Deployment complete!"
                            docker ps | grep ${CONTAINER_NAME}
EOF
                    '''
                }
            }
        }

        // ── 7. SMOKE TEST ON EC2 ──────────────────────────────
        stage('Post-Deploy Smoke Test') {
            steps {
                echo "🔎 Running smoke test on EC2..."
                sh '''
                    sleep 5
                    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://${EC2_HOST}/health)
                    echo "EC2 /health returned: $STATUS"
                    [ "$STATUS" = "200" ] && echo "✅ Production smoke test passed" || (echo "❌ Production smoke test FAILED" && exit 1)
                '''
            }
        }

    }
    // ═══════════════════════════════════════════════════════════

    // ── POST-PIPELINE NOTIFICATIONS ───────────────────────────
    post {
        success {
            echo """
            ╔══════════════════════════════════════╗
            ║  ✅  PIPELINE SUCCEEDED               ║
            ║  App : ${APP_NAME}                   ║
            ║  Tag : ${IMAGE_TAG}                  ║
            ║  URL : http://${EC2_HOST}            ║
            ╚══════════════════════════════════════╝
            """
        }
        failure {
            echo "❌ Pipeline FAILED at stage. Check logs above."
        }
        always {
            // Remove dangling local images to keep Jenkins agent clean
            sh 'docker image prune -f || true'
        }
    }
}
