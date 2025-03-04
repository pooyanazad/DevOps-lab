FROM nginx:latest

# Install useful packages
RUN apt-get update && apt-get install -y \
    vim \
    curl \
    iputils-ping \
    dnsutils \
    net-tools \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Copy default configuration
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# Create SSL directory
RUN mkdir -p /etc/nginx/ssl

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 CMD curl -f http://localhost/ || exit 1

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]