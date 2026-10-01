// Insuremonster webui — placeholder/coming-soon build. Mirrors the platform webui pipeline:
// load ENV_FILE_CUSTOM -> build image -> deploy on app-network+edge-network.
def envVarsMap = [:]
def envVarsList = []
def dockerImage = ''
def dockerService = ''
def siteId = ''

// Single-quotes a value for a shell line: nothing inside is expanded or executed, so a value from the
// env file reaches docker literally, whatever characters it holds (`$`, backtick, `"`, `\`, `'`).
def shq(value) {
    "'" + (value == null ? '' : value.toString()).replace("'", "'\\''") + "'"
}

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
                    if (!envFile) {
                        // Webhook/SCM-triggered builds pass no parameters, and Declarative
                        // param-sync wipes the job-config defaultValue after the first run.
                        // The Jenkins job folder is the site hostname, so derive the env file.
                        def jobFolder = env.JOB_NAME?.tokenize('/')?.first()
                        if (jobFolder?.contains('.')) {
                            envFile = "/app/environments/${jobFolder}.env"
                            echo "ENV_FILE_CUSTOM not provided — derived from job folder: ${envFile}"
                        }
                    }
                    if (!envFile) { error "Could not determine environment file path. Provide ENV_FILE_CUSTOM." }
                    def envFileName = envFile.tokenize('/').last()
                    siteId = envFileName.replaceAll('\\.env$', '')
                    def content = sh(script: "cat '${envFile.replace("'", "'\"'\"'")}'", returnStdout: true)
                    envVarsMap = content.split('\n').findAll { it.trim() && !it.trim().startsWith('#') }
                        .collectEntries { def p = it.replace('\r','').split('=', 2); p.size()==2 ? [(p[0].trim()): p[1]?.trim()] : [:] }
                    envVarsList = envVarsMap.collect { k, v -> "${k}=${v}" }
                    dockerImage = envVarsMap['WEBUI_DOCKER_IMAGE'] ?: "${siteId}-webui-service:latest"
                    dockerService = envVarsMap['WEBUI_DOCKER_SERVICE'] ?: "${siteId}-webui-service"
                    // The image and container names go into shell lines unquoted, so only plain names are
                    // allowed: no env-file value may add shell syntax to a command.
                    if (!(dockerImage ==~ /[a-z0-9][A-Za-z0-9._\/:-]*/)) { error "Docker image '${dockerImage}' is not a plain image reference" }
                    if (!(dockerService ==~ /[A-Za-z0-9][A-Za-z0-9_.-]*/)) { error "Docker service '${dockerService}' is not a plain container name" }
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
                      --build-arg NPM_REGISTRY_URL=${shq(reg)} \
                      -t ${dockerImage} .
                    """
                }
            }
        }
        stage('Deploy') {
            steps {
                script {
                    // The container's runtime env reaches docker only through a file in a private directory, never
                    // the docker run command line: Jenkins runs sh with -x, and `-e KEY='value'` printed every value
                    // of the env file into the build console (found on prod, 2026-10-01). post { always } removes
                    // the directory however the build ends.
                    def secretsDir = "${env.WORKSPACE}/.deploy-secrets"
                    sh "rm -rf '${secretsDir}' && mkdir -m 700 '${secretsDir}'"
                    envVarsMap.each { k, v ->
                        if (!(k ==~ /[A-Za-z_][A-Za-z0-9_]*/) || (v ?: '') =~ /[\r\n]/) {
                            error "Env entry '${k}' cannot be passed to docker --env-file"
                        }
                    }
                    def runEnvFile = "${secretsDir}/run.env"
                    writeFile file: runEnvFile, text: envVarsMap.collect { k, v -> "${k}=${v ?: ''}" }.join('\n') + '\n'
                    sh """
                    docker rm -f ${dockerService} || true
                    docker network inspect edge-network >/dev/null 2>&1 || docker network create edge-network
                    docker run -d --name ${dockerService} --network app-network --env-file '${runEnvFile}' \
                      --restart unless-stopped ${dockerImage}
                    docker network connect edge-network ${dockerService} || true
                    docker ps --filter name=${dockerService}
                    """
                }
            }
        }
    }
    post {
        always {
            sh "rm -rf '${env.WORKSPACE}/.deploy-secrets'"
        }
        cleanup { sh 'docker image prune -f || true' }
    }
}
