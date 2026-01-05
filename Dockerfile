FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV FLUTTER_HOME=/usr/local/flutter
ENV PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$ANDROID_HOME/platform-tools:$PATH"
ENV PUB_CACHE=/workspace/.pub-cache
ENV ANDROID_HOME=/opt/android-sdk

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    unzip \
    xz-utils \
    zip \
    ca-certificates \
    openjdk-17-jdk \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    libglu1-mesa \
    libxi6 \
    libgconf-2-4 \
    libxss1 \
    libxtst6 \
    libxrandr2 \
    libasound2 \
    libpangocairo-1.0-0 \
    libatk1.0-0 \
    libcairo-gobject2 \
    libgtk-3-0 \
    libgdk-pixbuf2.0-0 \
    zsh \
    netcat-openbsd \
    socat \
    && rm -rf /var/lib/apt/lists/*

# Install Android SDK
ENV ANDROID_HOME=/opt/android-sdk
RUN mkdir -p $ANDROID_HOME/cmdline-tools && \
    cd /tmp && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip && \
    unzip commandlinetools-linux-11076708_latest.zip && \
    mv cmdline-tools $ANDROID_HOME/cmdline-tools/latest && \
    rm commandlinetools-linux-11076708_latest.zip && \
    yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses && \
    $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager \
      "platform-tools" \
      "platforms;android-36" \
      "platforms;android-35" \
      "platforms;android-34" \
      "platforms;android-33" \
      "build-tools;36.0.0" \
      "build-tools;35.0.0" \
      "build-tools;34.0.0" \
      "build-tools;33.0.2" \
      "ndk;27.0.12077973" && \
    chmod -R 777 $ANDROID_HOME

# Download and install Flutter
RUN git clone https://github.com/flutter/flutter.git \
    -b stable \
    $FLUTTER_HOME && \
    flutter config --enable-web && \
    flutter config --enable-linux-desktop

# Note: pub cache directory will be created in /workspace by the user

# Create a non-root user
RUN useradd -m -u 1000 flutteruser && \
    chown -R flutteruser:flutteruser /usr/local/flutter && \
    chown -R flutteruser:flutteruser /opt/android-sdk && \
    chsh -s /bin/zsh flutteruser

# Install Oh-My-Zsh for flutteruser
RUN su flutteruser -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' && \
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="robbyrussell"/' /home/flutteruser/.zshrc && \
    echo 'export FLUTTER_HOME=/usr/local/flutter' >> /home/flutteruser/.zshrc && \
    echo 'export ANDROID_HOME=/opt/android-sdk' >> /home/flutteruser/.zshrc && \
    echo 'export PUB_CACHE=/workspace/.pub-cache' >> /home/flutteruser/.zshrc && \
    echo 'export PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$ANDROID_HOME/platform-tools:$PATH"' >> /home/flutteruser/.zshrc

# Also add to bashrc for compatibility
RUN echo 'export FLUTTER_HOME=/usr/local/flutter' >> /home/flutteruser/.bashrc && \
    echo 'export ANDROID_HOME=/opt/android-sdk' >> /home/flutteruser/.bashrc && \
    echo 'export PUB_CACHE=/workspace/.pub-cache' >> /home/flutteruser/.bashrc && \
    echo 'export PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$ANDROID_HOME/platform-tools:$PATH"' >> /home/flutteruser/.bashrc

# Configure git safe directory for flutteruser
RUN su flutteruser -c "git config --global --add safe.directory /usr/local/flutter"

# Copy and setup entrypoint script for ADB bridge
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    chown flutteruser:flutteruser /usr/local/bin/docker-entrypoint.sh

# Set working directory
WORKDIR /workspace

# Verify Flutter installation
RUN su flutteruser -c "/usr/local/flutter/bin/flutter --version"

# Use entrypoint script to setup ADB bridge
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Default command - use exec form with zsh for the user
CMD ["/bin/zsh"]
