// Action Step 5: Build, Test, Deploy pipeline for a small Flask app
pipeline {
    agent any

    environment {
        IMAGE_NAME = "jenkins-demo"
        IMAGE_TAG  = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Build') {
            steps {
                echo "Building image ${IMAGE_NAME}:${IMAGE_TAG}"
                sh 'docker build -t $IMAGE_NAME:$IMAGE_TAG .'
            }
        }

        stage('Test') {
            steps {
                echo "Running unit tests inside the new image"
                sh 'docker run --rm $IMAGE_NAME:$IMAGE_TAG python -m pytest -v'
            }
        }

        stage('Deploy') {
            steps {
                echo "Replacing the running app container"
                sh '''
                    docker rm -f jenkins-demo-app || true
                    docker run -d --name jenkins-demo-app -p 80:5000 $IMAGE_NAME:$IMAGE_TAG
                '''
            }
        }
    }

        post {
        success {
            sh 'echo "Deployed. Browse to http://$(curl -s https://checkip.amazonaws.com)/"'
        }
        failure {
            echo "Pipeline failed. Check the stage logs above."
        }
    }
}
