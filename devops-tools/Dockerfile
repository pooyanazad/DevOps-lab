FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    iputils-ping \
    python3 \
    python3-pip \
    openssh-client \
    gnupg \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && apt-get install -y terraform && \
    rm -rf /var/lib/apt/lists/*

# Install Ansible
RUN add-apt-repository --yes --update ppa:ansible/ansible && \
    apt-get update && apt-get install -y ansible && \
    rm -rf /var/lib/apt/lists/*

# Create project directory
RUN mkdir -p /projects

WORKDIR /projects

# Health check: Check if ansible and terraform are installed
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 CMD ansible --version > /dev/null && terraform --version > /dev/null || exit 1

CMD ["tail", "-f", "/dev/null"]