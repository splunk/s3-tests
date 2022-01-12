def lastStage = ''
node('node') {
  properties([disableConcurrentBuilds()])
  try {
    currentBuild.result = "SUCCESS"

    stage('Checkout') {
      lastStage = env.STAGE_NAME
      checkout scm

      echo "Current build result: ${currentBuild.result}"
    }

    stage('Build image') {
      lastStage = env.STAGE_NAME
      sh 'make build-image'

      echo "Current build result: ${currentBuild.result}"
    }

    stage('Push image') {
      lastStage = env.STAGE_NAME
      sh 'make push-image'

      echo "Current build result: ${currentBuild.result}"
    }
  }
  catch (err) {
    echo "Caught errors! ${err}"
    echo "Setting build result to FAILURE"
    currentBuild.result = "FAILURE"

    slackSend color: 'danger', channel: '#team-edge', message: "@edge ${env.BRANCH_NAME} build failed during stage ${lastStage} ${env.BUILD_URL}"

    mail from: 'builds@storj.io',
      replyTo: 'builds@storj.io',
      to: 'builds@storj.io',
      subject: "storj/splunk-s3-tests branch ${env.BRANCH_NAME} build failed",
      body: "Project build log: ${env.BUILD_URL}"

    throw err
  }
  finally {
    stage('Cleanup') {
      sh 'make clean-image'
      deleteDir()
    }
  }
}