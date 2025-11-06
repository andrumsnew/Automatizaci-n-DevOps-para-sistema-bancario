pipeline {
    agent any
    
    environment {
        DB_HOST = credentials('db-host')
        DB_USER = credentials('db-user')
        DB_PASSWORD = credentials('db-password')
    }
    
    stages {
        stage('Validación') {
            steps {
                echo 'Validando sintaxis SQL y Terraform...'
                sh 'terraform fmt -check terraform/'
                // Aquí iría validación SQL
            }
        }
        
        stage('Infraestructura') {
            steps {
                echo 'Desplegando infraestructura con Terraform...'
                dir('terraform') {
                    sh 'terraform init'
                    sh 'terraform plan'
                    sh 'terraform apply -auto-approve'
                }
            }
        }
        
        stage('Testing') {
            steps {
                echo 'Ejecutando tests en ambiente QA...'
                sh './deploy.sh'
            }
        }
        
        stage('Aprobación Manual') {
            when {
                branch 'main'
            }
            steps {
                input message: '¿Aprobar despliegue a PRODUCCIÓN?', ok: 'Desplegar'
            }
        }
        
        stage('Producción') {
            when {
                branch 'main'
            }
            steps {
                echo 'Desplegando a PRODUCCIÓN...'
                sh './deploy.sh'
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completado exitosamente'
            // Aquí enviarías notificación a Slack
        }
        failure {
            echo 'Pipeline falló - iniciando rollback'
            // Aquí ejecutarías rollback automático
        }
    }
}