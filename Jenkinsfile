pipeline {
    agent any
    stages {
        stage('git checkout') {
            steps {
                sh 'rm -rf *'
                checkout([$class: 'GitSCM', branches: [[name: '*/main']], userRemoteConfigs: [[url: 'https://github.com/Shrayanshy/3-tier-app-terraform']]])
            }
        }
    stage('terraform') {
      steps {
        sh '''
        terraform init
        TF_CLI_ARGS="-auto-approve" terraform apply -var-file=variables.tfvars
        '''
              }
       }

    }
}
