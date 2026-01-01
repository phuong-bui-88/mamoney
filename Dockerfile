FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV FLUTTER_HOME=/usr/local/flutter
ENV PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"
ENV PUB_CACHE=/pub-cache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    unzip \
    xz-utils \
    zip \
    ca-certificates \
    openjdk-11-jdk \
    && rm -rf /var/lib/apt/lists/*

# Download and install Flutter
RUN mkdir -p $FLUTTER_HOME && \
    cd /tmp && \
    wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz && \
    tar xf flutter_linux_3.24.5-stable.tar.xz && \
    mv flutter/* $FLUTTER_HOME/ && \
    rm -rf flutter flutter_linux_3.24.5-stable.tar.xz && \
    cd $FLUTTER_HOME && \
    git init . && \
    git config user.email "flutter@example.com" && \
    git config user.name "Flutter"

# Create pub cache directory
RUN mkdir -p $PUB_CACHE

# Set working directory
WORKDIR /workspace

# Verify Flutter installation
RUN flutter --version

# Default command
CMD ["/bin/bash"]
