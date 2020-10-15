library 'magic-butler-catalogue'
def PROJECT_NAME = 'logdna-agent-v2'

pipeline {
    agent any
    options {
        timestamps()
        ansiColor 'xterm'
    }
    triggers {
        cron(env.BRANCH_NAME ==~ /\d\.\d/ ? 'H H 1,15 * *' : '')
    }
    environment {
        RUST_IMAGE_REPO = 'us.gcr.io/logdna-k8s/rust'
        RUST_IMAGE_TAG = 'buster-stable'
        // RUST_IMAGE_TAG = '1.42'
        SCCACHE_BUCKET = 'logdna-sccache-us-west-2'
        SCCACHE_REGION = 'us-west-2'
    }
    stages {
        stage('Pull Build Image') {
            steps {
                sh "docker pull ${RUST_IMAGE_REPO}:${RUST_IMAGE_TAG}"
            }
        }
        stage('Build and Test') {
            stages {
                stage ("Lint and Test"){
                    environment {
                        CREDS_FILE = credentials('pipeline-e2e-creds')
                        LOGDNA_HOST = "logs.use.stage.logdna.net"
                    }
                    steps {
                        script {
                            def creds = readJSON file: CREDS_FILE
                            // Assumes the pipeline-e2e-creds format remains the same. Chase
                            // refer to the e2e tests's README's authorization docs for the
                            // current structure
                            LOGDNA_INGESTION_KEY = creds["packet-stage"]["account"]["ingestionkey"]
                        }
                        withCredentials([[
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        ]]){
                            sh """
                                make lint
                                make test
                                make integration-test LOGDNA_INGESTION_KEY=${LOGDNA_INGESTION_KEY}
                            """
                        }
                    }
                    post {
                        success {
                            sh "make clean"
                        }
                    }
                }
            }
        }
        stage('Check Publish Images') {
            when {
                branch pattern: "\\d\\.\\d", comparator: "REGEXP"
            }
            stages {
                stage('Build Release Image') {
                    steps {
                        sh "make build-image"
                    }
                }
                stage('Publish Images') {
                    input {
                        message "Should we publish the versioned image?"
                        ok "Publish image"
                    }
                    steps {
                        script {
                            withRegistry('https://docker.io', 'dockerhub-username-password') {
                                withRegistry('https://icr.io', 'icr-username-password') {
                                    withCredentials([[
                                        $class: 'AmazonWebServicesCredentialsBinding',
                                        credentialsId: 'aws',
                                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                                    ]]){
                                        sh 'make publish'
                                    }
                                }
                            }
                        }
                    }
                }
            }
            post {
                always {
                    sh 'make clean-all'
                }
            }
        }
    }
}
