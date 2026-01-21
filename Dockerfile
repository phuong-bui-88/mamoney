# Base image
FROM ubuntu:22.04

# Non-interactive mode
ENV DEBIAN_FRONTEND=noninteractive

# Flutter paths
ENV FLUTTER_HOME=/usr/local/flutter
ENV PUB_CACHE=/workspace/.pub-cache
ENV PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"

# Linux Android SDK
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=$ANDROID_HOME
ENV PATH="$PATH:$ANDROID_HOME/cmdline-tools/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"

# Connect to Windows ADB server over TCP (host.docker.internal resolves to Windows host)
ENV ADB_SERVER_SOCKET=tcp:host.docker.internal:5037

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git curl wget unzip xz-utils zip ca-certificates \
    openjdk-17-jdk clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libglu1-mesa libxi6 libgconf-2-4 \
    libxss1 libxtst6 libxrandr2 libasound2 libpangocairo-1.0-0 \
    libatk1.0-0 libcairo-gobject2 libgtk-3-0 libgdk-pixbuf2.0-0 \
    zsh netcat-openbsd socat sed coreutils unzip \
    libc6 libc6-dev locales \
    && rm -rf /var/lib/apt/lists/*

# Install Android SDK cmdline-tools and platform-tools
RUN mkdir -p $ANDROID_HOME/cmdline-tools && \
    cd /tmp && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip && \
    unzip -q commandlinetools-linux-10406996_latest.zip && \
    mv cmdline-tools/* $ANDROID_HOME/cmdline-tools/ && \
    rm -rf cmdline-tools commandlinetools-linux-10406996_latest.zip && \
    chmod -R 777 $ANDROID_HOME

# Install platform-tools
RUN cd $ANDROID_HOME && \
    wget https://dl.google.com/android/repository/platform-tools_r36.0.2-linux.zip && \
    unzip -q platform-tools_r36.0.2-linux.zip && \
    rm platform-tools_r36.0.2-linux.zip && \
    chmod -R 777 $ANDROID_HOME

# Accept Android SDK licenses and install required packages
RUN yes | $ANDROID_HOME/cmdline-tools/bin/sdkmanager --sdk_root=$ANDROID_HOME --licenses || true && \
    $ANDROID_HOME/cmdline-tools/bin/sdkmanager --sdk_root=$ANDROID_HOME \
    "platforms;android-34" \
    "build-tools;34.0.0" \
    "emulator" \
    "platform-tools" || true

# Install Flutter (stable)
RUN git clone https://github.com/flutter/flutter.git -b stable $FLUTTER_HOME && \
    flutter config --enable-web && \
    flutter config --enable-linux-desktop

# Set locale to fix UTF-8 encoding issues
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# Create non-root user
RUN useradd -m -u 1000 flutteruser && \
    chown -R flutteruser:flutteruser /usr/local/flutter /opt/android-sdk && \
    chsh -s /bin/zsh flutteruser

# Install Oh-My-Zsh for flutteruser with proper PATH setup to prevent utility lookup errors
RUN export PATH="/bin:/usr/bin:/usr/local/bin:/usr/sbin:/sbin" && \
    su - flutteruser -c 'export PATH="/bin:/usr/bin:/usr/local/bin:/usr/sbin:/sbin" && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' && \
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="robbyrussell"/' /home/flutteruser/.zshrc && \
    sed -i 's/^plugins=.*/plugins=(git docker)/' /home/flutteruser/.zshrc && \
    echo "" >> /home/flutteruser/.zshrc && \
    echo "# Flutter and Android environment" >> /home/flutteruser/.zshrc && \
    echo "export FLUTTER_HOME=/usr/local/flutter" >> /home/flutteruser/.zshrc && \
    echo "export PUB_CACHE=/workspace/.pub-cache" >> /home/flutteruser/.zshrc && \
    echo "export ANDROID_HOME=/opt/android-sdk" >> /home/flutteruser/.zshrc && \
    echo "export ANDROID_SDK_ROOT=\$ANDROID_HOME" >> /home/flutteruser/.zshrc && \
    echo "export PATH=\$FLUTTER_HOME/bin:\$FLUTTER_HOME/bin/cache/dart-sdk/bin:\$ANDROID_HOME/cmdline-tools/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/emulator:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" >> /home/flutteruser/.zshrc

# Also add to bashrc for compatibility
RUN echo "export FLUTTER_HOME=/usr/local/flutter" >> /home/flutteruser/.bashrc && \
    echo "export PUB_CACHE=/workspace/.pub-cache" >> /home/flutteruser/.bashrc && \
    echo "export ANDROID_HOME=/opt/android-sdk" >> /home/flutteruser/.bashrc && \
    echo "export ANDROID_SDK_ROOT=\$ANDROID_HOME" >> /home/flutteruser/.bashrc && \
    echo "export PATH=\$FLUTTER_HOME/bin:\$FLUTTER_HOME/bin/cache/dart-sdk/bin:\$ANDROID_HOME/cmdline-tools/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/emulator:\$PATH" >> /home/flutteruser/.bashrc

# Configure git safe directory
RUN git config --global --add safe.directory /usr/local/flutter && \
    su flutteruser -c "git config --global --add safe.directory /usr/local/flutter"

# Copy entrypoint script if needed
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    chown flutteruser:flutteruser /usr/local/bin/docker-entrypoint.sh

# Set working directory
WORKDIR /workspace

# Verify Flutter installation
RUN su flutteruser -c "$FLUTTER_HOME/bin/flutter --version" || echo "Warning: Flutter verification skipped"

# Entrypoint for ADB bridge
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Default command - interactive shell
USER flutteruser
CMD ["/bin/zsh"]
