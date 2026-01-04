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
    zsh \
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

# Create a non-root user
RUN useradd -m -u 1000 flutteruser && \
    chown -R flutteruser:flutteruser /usr/local/flutter && \
    chown -R flutteruser:flutteruser /opt/android-sdk && \
    chown -R flutteruser:flutteruser $PUB_CACHE && \
    chsh -s /bin/zsh flutteruser

# Install Oh-My-Zsh for flutteruser
RUN su flutteruser -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' && \
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="robbyrussell"/' /home/flutteruser/.zshrc

# Configure git safe directory for flutteruser
RUN su flutteruser -c "git config --global --add safe.directory /usr/local/flutter"

# Set working directory
WORKDIR /workspace

# Verify Flutter installation
RUN su flutteruser -c "/usr/local/flutter/bin/flutter --version"

# Default command - use exec form with zsh for the user
CMD ["/bin/zsh"]
