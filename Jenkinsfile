pipeline {
    agent any
    parameters {
        booleanParam(name: 'skip_netlify', defaultValue: true, description: 'Set to true to skip the stages with Netlify')
    }

    environment {
        CUSTOM_DOCKER_IMAGE = 'my-playwright'
        NETLIFY_SITE_ID = '03d4042d-476c-4668-9ce8-34352dad73e4'
        NETLIFY_AUTH_TOKEN = credentials('netlify-token')
        REACT_APP_VERSION = "1.0.$BUILD_VERSION"
    }

    stages {
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

        stage('Deploy to staging on Netlify') {
            when {
                expression {
                    params.skip_netlify != true 
                }
            }
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

        stage('Deploy to prod on Netlify') {
            when {
                expression {
                    params.skip_netlify != true 
                }
            }
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

        stage('Deploy to AWS S3 Bucket Site') {
            agent {
                docker {
                    image "$CUSTOM_DOCKER_IMAGE"
                    reuseNode true
                }
            }
            environment {
                AWS_S3_BUCKET = 'learn-jenkins-202412290002'
                CI_ENVIRONMENT_URL = "http://$AWS_S3_BUCKET.s3-website-us-east-1.amazonaws.com"
            }
            steps{
                withCredentials([usernamePassword(credentialsId: 'my-aws-access', passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
                    sh '''
                        aws --version
                        aws s3 sync build s3://$AWS_S3_BUCKET/
                        sleep 10
                        npx playwright test --reporter=html
                    '''
                }
            }
        }

        stage('Deploy to AWS ECS') {
            agent {
                docker {
                    image "$CUSTOM_DOCKER_IMAGE"
                    reuseNode true
                }
            }
            environment {
                AWS_S3_BUCKET = 'learn-jenkins-202412290002'
                CI_ENVIRONMENT_URL = "http://$AWS_S3_BUCKET.s3-website-us-east-1.amazonaws.com"
            }
            steps{
                withCredentials([usernamePassword(credentialsId: 'my-aws-access', passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
                    sh '''
                        aws --version
                        aws ecs register-task-definition --cli-input-json file://task-definition-prod.json
                    '''
                }
            }
        }
    }
}
