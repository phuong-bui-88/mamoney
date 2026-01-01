FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV FLUTTER_HOME=/usr/local/flutter
ENV PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$ANDROID_HOME/platform-tools:$PATH"
ENV PUB_CACHE=/pub-cache
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
    chromium-browser \
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
    $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.2"

# Download and install Flutter
RUN mkdir -p $FLUTTER_HOME && \
    cd /tmp && \
    wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.38.5-stable.tar.xz && \
    tar xf flutter_linux_3.38.5-stable.tar.xz && \
    mv flutter/* $FLUTTER_HOME/ && \
    rm -rf flutter flutter_linux_3.38.5-stable.tar.xz && \
    cd $FLUTTER_HOME && \
    git init . && \
    git config user.email "flutter@example.com" && \
    git config user.name "Flutter" && \
    git add -A && \
    git commit -m "Flutter SDK base" && \
    flutter config --enable-web && \
    flutter config --enable-linux-desktop

# Create pub cache directory
RUN mkdir -p $PUB_CACHE

# Set working directory
WORKDIR /workspace

# Verify Flutter installation
RUN flutter --version

# Default command
CMD ["/bin/bash"]
