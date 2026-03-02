pipeline {
    agent any

    environment {
        AWS_REGION        = 'us-east-1'
        ECR_REGISTRY      = '851725642392.dkr.ecr.us-east-1.amazonaws.com'
        BACKEND_IMAGE     = "${ECR_REGISTRY}/task-platform-backend"
        FRONTEND_IMAGE    = "${ECR_REGISTRY}/task-platform-frontend"
        IMAGE_TAG         = "${env.GIT_COMMIT[0..6]}"   // short commit hash
        CLUSTER_NAME      = 'task-platform-dev'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Lint & Test - Backend') {
            steps {
                dir('app/backend') {
                    sh 'npm install'
                    sh 'npm run lint --if-present'
                    sh 'npm test --if-present'
                }
            }
        }

        stage('Lint & Test - Frontend') {
            steps {
                dir('app/frontend') {
                    sh 'npm install'
                    sh 'npm run lint --if-present'
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                sh """
                    docker build -t ${BACKEND_IMAGE}:${IMAGE_TAG} \
                      -t ${BACKEND_IMAGE}:latest \
                      ./app/backend

                    docker build \
                      --build-arg VITE_API_URL=http://k8s-taskplatform-ee21592120-448541293.us-east-1.elb.amazonaws.com/api \
                      -t ${FRONTEND_IMAGE}:${IMAGE_TAG} \
                      -t ${FRONTEND_IMAGE}:latest \
                      ./app/frontend
                """
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]
                ]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                          docker login --username AWS --password-stdin ${ECR_REGISTRY}

                        docker push ${BACKEND_IMAGE}:${IMAGE_TAG}
                        docker push ${BACKEND_IMAGE}:latest

                        docker push ${FRONTEND_IMAGE}:${IMAGE_TAG}
                        docker push ${FRONTEND_IMAGE}:latest
                    """
                }
            }
        }

        stage('Update Helm Image Tag') {
            steps {
                sh """
                    sed -i 's/tag: .*/tag: ${IMAGE_TAG}/' helm/backend/values.yaml
                    sed -i 's/tag: .*/tag: ${IMAGE_TAG}/' helm/frontend/values.yaml
                """
                sh """
                    git config user.email "jenkins@task-platform.io"
                    git config user.name "Jenkins"
                    git add helm/backend/values.yaml helm/frontend/values.yaml
                    git commit -m "ci: update image tag to ${IMAGE_TAG} [skip ci]"
                    git push origin develop
                """
            }
        }

        stage('Deploy to EKS') {
            steps {
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]
                ]) {
                    sh """
                        aws eks update-kubeconfig \
                          --region ${AWS_REGION} \
                          --name ${CLUSTER_NAME}

                        helm upgrade backend ./helm/backend --namespace dev
                        helm upgrade frontend ./helm/frontend --namespace dev
                    """
                }
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline succeeded — app deployed to dev'
        }
        failure {
            echo '❌ Pipeline failed — check logs above'
        }
        always {
            // Clean up local docker images to save disk space
            sh 'docker image prune -f'
        }
    }
}
