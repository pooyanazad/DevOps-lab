import jenkins.model.*
import hudson.slaves.*
import hudson.plugins.sshslaves.*
import hudson.model.*

def instance = Jenkins.getInstance()

// Configure JNLP agent port
instance.setSlaveAgentPort(50000)

// Create permanent agent nodes configuration
def createAgent = { String name, String description ->
    def existingNode = instance.getNode(name)
    if (existingNode == null) {
        def launcher = new JNLPLauncher(true)
        def retentionStrategy = new RetentionStrategy.Always()
        
        def node = new DumbSlave(
            name,
            description,
            "/home/jenkins/agent",
            "2",
            Node.Mode.NORMAL,
            "docker ubuntu",
            launcher,
            retentionStrategy,
            new LinkedList()
        )
        
        instance.addNode(node)
        println "Agent '${name}' configured"
    } else {
        println "Agent '${name}' already exists"
    }
}

createAgent("ubuntu-agent-1", "Ubuntu Docker Agent 1")
createAgent("ubuntu-agent-2", "Ubuntu Docker Agent 2")

instance.save()
println "Jenkins agents configuration completed"
