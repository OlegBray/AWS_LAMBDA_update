pipeline {
    agent any

    environment {
        AWS_REGION = 'il-central'                  // Use your region
        LAMBDA_NAME = 'oleg-self-updating'         // Use your LAMBDA name
        ZIP_FILE = 'lambda_package.zip'            
    }

    stages {
        stage('Prepare and Install Dependencies') {
            steps {
                sh '''
                    mkdir -p package
                    pip install -r requirements.txt -t package/
                    cp *.py package/
                    cd package
                    zip -r ../$ZIP_FILE .
                '''
            }
        }

        stage('Deploy to AWS Lambda') {
            steps {
                sh '''
                    aws lambda update-function-code \
                      --function-name $LAMBDA_NAME \
                      --zip-file fileb://$ZIP_FILE \
                      --region $AWS_REGION
                '''
            }
        }
    }
}
