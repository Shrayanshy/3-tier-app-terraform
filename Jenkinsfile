pipeline {
    agent any
    stages {
        stage('git checkout ') {
            steps {
                sh 'rm -rf *'
                git 'https://github.com/Shrayanshy/3-tier-app-terraform/.git'
            }
        }
        stage('terraform') {
            steps {
                sh''' cd  3-tier-app-terraform
                terraform init
                terraform apply -var-file=variables.tfvars 
                '''
            }
        }
