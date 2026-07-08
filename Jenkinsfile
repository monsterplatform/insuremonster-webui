// Insuremonster webui — placeholder/coming-soon build. Mirrors the platform webui pipeline:
// load ENV_FILE_CUSTOM -> build image -> deploy on app-network+edge-network.
def envVarsMap = [:]
def envVarsList = []
def dockerImage = ''
def dockerService = ''
def siteId = ''

pipeline {
    agent any
    parameters {
        booleanParam(name: 'FETCH_FROM_GITHUB', defaultValue: true, description: 'Fetch from Git.')
        string(name: 'ENV_FILE_CUSTOM', defaultValue: '', description: 'Path to the env file on the agent')
    }
    environment { ENV_FILE_CUSTOM = "${params.ENV_FILE_CUSTOM}" }

    stages {
        stage('Load Environment Variables') {
            steps {
                script {
                    def envFile = params.ENV_FILE_CUSTOM?.trim()
                    if (!envFile) { error "ENV_FILE_CUSTOM is required" }
                    def envFileName = envFile.tokenize('/').last()
                    siteId = envFileName.replaceAll('\\.env$', '')
                    def content = sh(script: "cat '${envFile.replace("'", "'\"'\"'")}'", returnStdout: true)
                    envVarsMap = content.split('\n').findAll { it.trim() && !it.trim().startsWith('#') }
                        .collectEntries { def p = it.replace('\r','').split('=', 2); p.size()==2 ? [(p[0].trim()): p[1]?.trim()] : [:] }
                    envVarsList = envVarsMap.collect { k, v -> "${k}=${v}" }
                    dockerImage = envVarsMap['WEBUI_DOCKER_IMAGE'] ?: "${siteId}-webui-service:latest"
                    dockerService = envVarsMap['WEBUI_DOCKER_SERVICE'] ?: "${siteId}-webui-service"
                    echo "Site=${siteId} Image=${dockerImage} Service=${dockerService}"
                }
            }
        }
        stage('Checkout') {
            when { expression { params.FETCH_FROM_GITHUB } }
            steps { checkout scm }
        }
        stage('Build Docker Image') {
            steps {
                script {
                    def reg = envVarsMap['NPM_REGISTRY_URL'] ?: 'http://verdaccio:4873'
                    sh """
                    docker network inspect app-network >/dev/null 2>&1 || docker network create app-network
                    DOCKER_BUILDKIT=0 docker build --no-cache \
                      --network=app-network \
                      --build-arg NPM_REGISTRY_URL='${reg}' \
                      -t ${dockerImage} .
                    """
                }
            }
        }
        stage('Deploy') {
            steps {
                script {
                    def envFlags = envVarsMap.collect { k, v -> "-e ${k}='${v}'" }.join(' ')
                    sh """
                    docker rm -f ${dockerService} || true
                    docker network inspect edge-network >/dev/null 2>&1 || docker network create edge-network
                    docker run -d --name ${dockerService} --network app-network ${envFlags} \
                      --restart unless-stopped ${dockerImage}
                    docker network connect edge-network ${dockerService} || true
                    docker ps --filter name=${dockerService}
                    """
                }
            }
        }
    }
    post {
        cleanup { sh 'docker image prune -f || true' }
    }
}
