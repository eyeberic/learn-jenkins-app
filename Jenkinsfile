pipeline {
    agent any
    parameters {
        booleanParam(name: 'skip_netlify', defaultValue: true, description: 'Set to true to skip the stages with Netlify')
        booleanParam(name: 'skip_aws', defaultValue: true, description: 'Set to true to skip the stages with AWS')
    }

    environment {
        MY_APP_NAME = "LearnJenkinsApp"
        MY_APP_ENV = "Prod"
        CUSTOM_PLAYWRIGHT_IMAGE = 'my-playwright'
        CUSTOM_APP_IMAGE = ''
        NETLIFY_SITE_ID = '03d4042d-476c-4668-9ce8-34352dad73e4'
        NETLIFY_AUTH_TOKEN = credentials('netlify-token')
        REACT_APP_VERSION = "1.0.$BUILD_VERSION"
    }

    stages {
        stage('Build App') {
            agent {
                docker {
                    image "$CUSTOM_PLAYWRIGHT_IMAGE"
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
                            image "$CUSTOM_PLAYWRIGHT_IMAGE"
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
                            image "$CUSTOM_PLAYWRIGHT_IMAGE"
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
                    image "$CUSTOM_PLAYWRIGHT_IMAGE"
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
                    image "$CUSTOM_PLAYWRIGHT_IMAGE"
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

        stage('Build the Docker image for AWS') {
            agent {
                docker {
                    image 'my-aws-cli'
                    args '-u root -v /var/run/docker.sock:/var/run/docker.sock --entrypoint=""'
                    reuseNode true
                }
            }
            steps {
                sh '''
                    docker build -t $(echo $MY_APP_NAME | tr '[:upper:]' '[:lower:]') .
                '''
                script{
                    env.CUSTOM_APP_IMAGE = sh(script: "echo $MY_APP_NAME | tr '[:upper:]' '[:lower:]'", returnStdout: true)
                }
            }
        }

        stage('Deploy to AWS S3 Bucket Site') {
            when {
                expression {
                    params.skip_aws != true 
                }
            }
            agent {
                docker {
                    image "$CUSTOM_PLAYWRIGHT_IMAGE"
                    reuseNode true
                }
            }
            environment {
                AWS_S3_BUCKET = "$MY_APP_NAME-202412290002"
                CI_ENVIRONMENT_URL = "http://$AWS_S3_BUCKET.s3-website-us-east-1.amazonaws.com"
            }
            steps{
                withCredentials([usernamePassword(credentialsId: 'my-aws-access', passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
                    sh 'npx playwright test --reporter=html'
                }
            }
        }

        stage('Test the AWS S3 Bucket Site') {
            when {
                expression {
                    params.skip_aws != true 
                }
            }
            agent {
                docker {
                    image 'my-aws-cli'
                    reuseNode true
                }
            }
            environment {
                AWS_S3_BUCKET = "$MY_APP_NAME-202412290002"
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
            when {
                expression {
                    params.skip_aws != true 
                }
            }
            agent {
                docker {
                    image 'my-aws-cli'
                    args '--entrypoint=""'
                    reuseNode true
                }
            }
            environment {
                AWS_ECS_CLUSTER = "$MY_APP_NAME-Cluster-$MY_APP_ENV"
                AWS_ECS_TASKDEF = "$MY_APP_NAME-TaskDefinition-$MY_APP_ENV"
                AWS_ECS_SERVICE = "$MY_APP_NAME-Service-$MY_APP_ENV"
            }
            steps{
                withCredentials([usernamePassword(credentialsId: 'my-aws-access', passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
                    sh '''
                        aws --version
                        LATEST_TD_REVISION = $(aws ecs register-task-definition --cli-input-json file://task-definition-prod.json | jq '.taskDefinition.revision')
                        echo "Latest taskDefition is: ${LATEST_TD_REVISION}"
                        aws ecs update-service --cluster $AWS_ECS_CLUSTER --service $AWS_ECS_SERVICE --task-definition "${AWS_ECS_TASKDEF}:${LATEST_TD_REVISION}"
                        aws ecs wait services-stable --cluster $AWS_ECS_CLUSTER --services $AWS_ECS_SERVICE
                    '''
                }
            }
        }
    }
}
