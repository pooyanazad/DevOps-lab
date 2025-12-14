import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition

def instance = Jenkins.getInstance()

// Check if the job already exists
def jobName = "test-pipeline-agent1"
def existingJob = instance.getItem(jobName)

if (existingJob == null) {
    // Create a new Pipeline job
    def job = instance.createProject(WorkflowJob.class, jobName)
    
    // Define the pipeline script
    def pipelineScript = """
pipeline {
    agent {
        label 'ubuntu-agent-1'
    }
    
    options {
        ansiColor('xterm')
        timestamps()
        timeout(time: 10, unit: 'MINUTES')
    }
    
    stages {
        stage('System Info') {
            steps {
                echo '🖥️ System Information'
                sh 'echo "======================================" && hostname && whoami && pwd && echo "======================================"'
            }
        }
        
        stage('Environment Check') {
            steps {
                echo '🔧 Environment Check'
                sh 'echo "======================================" && cat /etc/os-release | head -5 && uname -r && uname -m && echo "======================================"'
            }
        }
        
        stage('Docker Check') {
            steps {
                echo '🐳 Docker Availability'
                sh 'echo "======================================" && docker --version || echo "Docker not available" && echo "======================================"'
            }
        }
        
        stage('Available Tools') {
            steps {
                echo '🛠️ Available Tools'
                sh 'echo "======================================" && git --version && python3 --version && java -version 2>&1 | head -1 && echo "======================================"'
            }
        }
        
        stage('Disk Space') {
            steps {
                echo '💾 Disk Space'
                sh 'echo "======================================" && df -h | head -5 && echo "======================================"'
            }
        }
        
        stage('Network Test') {
            steps {
                echo '🌐 Network Connectivity'
                sh 'echo "======================================" && curl -s -o /dev/null -w "%{http_code}" http://jenkins:8080 && echo " - Jenkins reachable" && echo "======================================"'
            }
        }
        
        stage('Simple Test') {
            steps {
                echo '🧮 Running Simple Test'
                sh 'echo "======================================"'
                sh 'echo "Running calculation: 21 * 2 = 42"'
                sh 'test 42 -eq 42 && echo "✅ Test PASSED!"'
                sh 'echo "======================================"'
            }
        }
    }
    
    post {
        success {
            echo '✅ Pipeline completed successfully on ubuntu-agent-1! DevOpsLab is working correctly.'
        }
        failure {
            echo '❌ Pipeline failed! Check the logs above for details.'
        }
    }
}
"""
    
    // Set the pipeline definition
    job.setDefinition(new CpsFlowDefinition(pipelineScript, true))
    
    // Save the job
    job.save()
    
    println "Test pipeline '" + jobName + "' created successfully!"
} else {
    println "Job '" + jobName + "' already exists, skipping creation."
}

instance.save()
println "Jenkins job configuration completed"
