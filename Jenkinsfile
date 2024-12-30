pipeline {
    agent any

    environment {
        CUSTOM_DOCKER_IMAGE = 'my-playwright'
        NETLIFY_SITE_ID = '03d4042d-476c-4668-9ce8-34352dad73e4'
        NETLIFY_AUTH_TOKEN = credentials('netlify-token')
        REACT_APP_VERSION = "1.0.$BUILD_VERSION"
    }

    stages {
        stage('AWS') {
            agent {
                docker {
                    image 'amazon/aws-cli'
                    args "--entrypoint=''"
                }
            }
            environment {
                AWS_S3_BUCKET = 'learn-jenkins-202412290002'
            }
            steps{
                withCredentials([usernamePassword(credentialsId: 'my-aws-access', passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
                    sh '''
                        aws --version
                        echo 'Hello from S3' > index.html
                        aws s3 cp index.html s3://$AWS_S3_BUCKET/
                    '''
                }
            }
        }

        stage('Build App') {
            agent {
                docker {
                    image "$CUSTOM_DOCKER_IMAGE"
                    reuseNode true
                }
            }
            steps {
                sh '''
                    ls -la
                    node --version
                    npm --version
                    npm ci
                    npm run build
                    ls -la
                '''
            }
        }
        
        stage('Local Test') {
            parallel {
                stage('Unit tests') {
                    agent {
                        docker {
                            image "$CUSTOM_DOCKER_IMAGE"
                            reuseNode true
                        }
                    }
                    steps {
                        sh '''
                            ls -la
                            test -f build/index.html
                            npm test
                        '''
                    }
                    post {
                        always {
                            junit 'jest-results/junit.xml'
                        }
                    }
                }
                stage('E2E tests') {
                    agent {
                        docker {
                            image "$CUSTOM_DOCKER_IMAGE"
                            reuseNode true
                        }
                    }
                    steps {
                        sh '''
                            serve -s build &
                            sleep 10
                            npx playwright test --reporter=html
                        '''
                    }
                    post {
                        always {
                            publishHTML([allowMissing: false, alwaysLinkToLastBuild: false, keepAll: false, reportDir: 'playwright-report', reportFiles: 'index.html', reportName: 'Playwright Local Test Report', reportTitles: '', useWrapperFileDirectly: true])
                        }
                    }
                }
            }
        }

        stage('Deploy staging') {
            agent {
                docker {
                    image "$CUSTOM_DOCKER_IMAGE"
                    reuseNode true
                }
            }
            steps {
                sh '''
                    netlify --version
                    echo "${STAGE_NAME} - Site ID: ${NETLIFY_SITE_ID}"
                    netlify status
                    netlify deploy --dir=build --json > deploy-output.json
                    sleep 10
                    export CI_ENVIRONMENT_URL=$(jq -r '.deploy_url' deploy-output.json)
                    npx playwright test --reporter=html
                '''
            }
            post {
                always {
                    publishHTML([allowMissing: false, alwaysLinkToLastBuild: false, keepAll: false, reportDir: 'playwright-report', reportFiles: 'index.html', reportName: 'Playwright Staging Test Report', reportTitles: '', useWrapperFileDirectly: true])
                }
            }
        }

        stage('Deploy prod') {
            agent {
                docker {
                    image "$CUSTOM_DOCKER_IMAGE"
                    reuseNode true
                }
            }
            environment {
                CI_ENVIRONMENT_URL = 'https://peaceful-daffodil-303af5.netlify.app'
            }
            steps {
                sh '''
                    netlify --version
                    echo "${STAGE_NAME} - Site ID: ${NETLIFY_SITE_ID}"
                    netlify status
                    netlify deploy --dir=build --prod
                    sleep 10
                    npx playwright test --reporter=html
                '''
            }
            post {
                always {
                    publishHTML([allowMissing: false, alwaysLinkToLastBuild: false, keepAll: false, reportDir: 'playwright-report', reportFiles: 'index.html', reportName: 'Playwright Prod Test Report', reportTitles: '', useWrapperFileDirectly: true])
                }
            }
        }
    }
}
