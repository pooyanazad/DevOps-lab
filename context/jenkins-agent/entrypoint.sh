#!/bin/bash

# Wait for Jenkins to be ready
echo "Waiting for Jenkins master to be ready..."
until curl -s -o /dev/null -w "%{http_code}" "${JENKINS_URL}/login" | grep -q "200\|403"; do
    echo "Jenkins not ready yet, waiting..."
    sleep 5
done

echo "Jenkins is ready! Starting agent..."

# Get the agent secret from Jenkins
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # Try to get the secret for this agent
    AGENT_SECRET=$(curl -s -u "${JENKINS_ADMIN_USER:-admin}:${JENKINS_ADMIN_PASSWORD:-admin}" \
        "${JENKINS_URL}/computer/${JENKINS_AGENT_NAME}/slave-agent.jnlp" 2>/dev/null | \
        grep -oP '(?<=<argument>)[a-f0-9]{64}(?=</argument>)' | head -1)
    
    if [ -n "$AGENT_SECRET" ]; then
        echo "Got agent secret from Jenkins"
        break
    fi
    
    echo "Waiting for agent configuration in Jenkins... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 10
done

if [ -z "$AGENT_SECRET" ]; then
    echo "Could not get agent secret, using environment variable"
    AGENT_SECRET="${JENKINS_SECRET}"
fi

# Start the agent
exec java -jar /usr/share/jenkins/agent.jar \
    -url "${JENKINS_URL}" \
    -name "${JENKINS_AGENT_NAME}" \
    -secret "${AGENT_SECRET}" \
    -workDir "${JENKINS_AGENT_WORKDIR}"
