FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    openjdk-17-jdk \
    curl \
    wget \
    git \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo \
    openssh-client \
    python3 \
    python3-pip \
    make \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Create jenkins user
RUN groupadd -g 1000 jenkins \
    && useradd -u 1000 -g jenkins -m -d /home/jenkins -s /bin/bash jenkins \
    && groupadd -f docker \
    && usermod -aG docker jenkins \
    && echo "jenkins ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Download Jenkins agent jar
RUN mkdir -p /usr/share/jenkins \
    && curl -fsSL https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/3261.v9c670a_4748a_9/remoting-3261.v9c670a_4748a_9.jar -o /usr/share/jenkins/agent.jar \
    && chmod 644 /usr/share/jenkins/agent.jar

# Create agent directory
RUN mkdir -p /home/jenkins/agent && chown -R jenkins:jenkins /home/jenkins

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER jenkins
WORKDIR /home/jenkins/agent

ENTRYPOINT ["/entrypoint.sh"]
