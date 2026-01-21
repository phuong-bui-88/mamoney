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
RUN set -x && \
    mkdir -p $ANDROID_HOME && \
    cd /tmp && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip && \
    unzip -q commandlinetools-linux-10406996_latest.zip && \
    echo "=== Contents of /tmp before move ===" && \
    ls -la /tmp/ | grep -E "cmdline|android" && \
    mkdir -p $ANDROID_HOME/cmdline-tools && \
    cp -r cmdline-tools/* $ANDROID_HOME/cmdline-tools/ && \
    echo "=== Contents of $ANDROID_HOME/cmdline-tools ===" && \
    ls -la $ANDROID_HOME/cmdline-tools/ && \
    rm -rf /tmp/cmdline-tools /tmp/commandlinetools-linux-10406996_latest.zip && \
    chmod -R 777 $ANDROID_HOME

# Install platform-tools
RUN cd $ANDROID_HOME && \
    wget https://dl.google.com/android/repository/platform-tools_r36.0.2-linux.zip && \
    unzip -q platform-tools_r36.0.2-linux.zip && \
    rm platform-tools_r36.0.2-linux.zip && \
    chmod -R 777 $ANDROID_HOME

# Accept Android SDK licenses and install required packages  
RUN mkdir -p $ANDROID_HOME/licenses && \
    echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > $ANDROID_HOME/licenses/android-sdk-license && \
    echo "504667f4c0de7973335447fc81aaad5d6d86e633" > $ANDROID_HOME/licenses/android-sdk-preview-license && \
    echo "d56f5187479451eabf01fb78af6dfcb131b33910" > $ANDROID_HOME/licenses/android-googletv-license && \
    echo "33b6a2b64607f11b759f316767f4d0910750cd98" > $ANDROID_HOME/licenses/google-gdk-license && \
    echo "8dab4689e25faec69b3bfc0c1c07b0b5835a33cb" > $ANDROID_HOME/licenses/android-googlexr-license && \
    echo "0c34cefda5db91a3bbd4b34da7346c4d926b4108" > $ANDROID_HOME/licenses/android-sdk-arm-dbt-license && \
    echo "fa00cd5a61e856ea51529a47234efb901d94bbb6" > $ANDROID_HOME/licenses/mips-android-sysimage-license && \
    yes | $ANDROID_HOME/cmdline-tools/bin/sdkmanager --sdk_root=$ANDROID_HOME \
    "platforms;android-34" \
    "platforms;android-36" \
    "build-tools;34.0.0" \
    "build-tools;28.0.3" \
    "platform-tools" 2>&1 | grep -E "^(Installing|Installed)" || true && \
    yes | $ANDROID_HOME/cmdline-tools/bin/sdkmanager --sdk_root=$ANDROID_HOME --licenses 2>&1 | tail -1 && \
    chmod -R 777 $ANDROID_HOME && \
    mkdir -p ~/.android && \
    echo "count=0" > ~/.android/repositories.cfg

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
    chsh -s /bin/zsh flutteruser && \
    mkdir -p /home/flutteruser/.android && \
    echo "count=0" > /home/flutteruser/.android/repositories.cfg && \
    chown -R flutteruser:flutteruser /home/flutteruser/.android && \
    mkdir -p /home/flutteruser/.flutter && \
    echo '{"android-sdk": "/opt/android-sdk"}' > /home/flutteruser/.flutter-settings && \
    chown -R flutteruser:flutteruser /home/flutteruser/.flutter && \
    mkdir -p /home/flutteruser/.gradle && \
    echo 'org.gradle.jvmargs=-Xmx4096m' > /home/flutteruser/.gradle/gradle.properties && \
    chown -R flutteruser:flutteruser /home/flutteruser/.gradle

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
COPY flutter-doctor-wrapper.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/flutter-doctor-wrapper.sh && \
    chown flutteruser:flutteruser /usr/local/bin/docker-entrypoint.sh /usr/local/bin/flutter-doctor-wrapper.sh && \
    ln -sf /opt/android-sdk/cmdline-tools/bin/sdkmanager /usr/local/bin/sdkmanager && \
    ln -sf /opt/android-sdk/cmdline-tools/bin/sdkmanager /usr/bin/sdkmanager

# Pre-accept all licenses for flutter doctor
RUN echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > /opt/android-sdk/licenses/android-sdk-license && \
    echo "d56f5187479451eabf01fb78af6dfcb131b33910" >> /opt/android-sdk/licenses/android-sdk-license && \
    mkdir -p /home/flutteruser/.android && \
    echo "### Android SDK Manager" > /home/flutteruser/.android/repositories.cfg && \
    chown -R flutteruser:flutteruser /home/flutteruser/.android && \
    chown -R flutteruser:flutteruser /opt/android-sdk/licenses

# Create initialization script that pre-accepts licenses on startup
RUN mkdir -p /etc/profile.d && \
    printf '#!/bin/bash\n# Pre-accept Android licenses on any shell startup\nif [ -z "$ANDROID_LICENSES_INITIALIZED" ]; then\n    export ANDROID_LICENSES_INITIALIZED=1\n    export ANDROID_HOME=/opt/android-sdk\n    export ANDROID_SDK_ROOT=/opt/android-sdk\n    yes 2>/dev/null | /opt/android-sdk/cmdline-tools/bin/sdkmanager --sdk_root=/opt/android-sdk --licenses >/dev/null 2>&1 || true\nfi\n' > /etc/profile.d/android-init.sh && \
    chmod +x /etc/profile.d/android-init.sh

# Set working directory
WORKDIR /workspace

# Verify Flutter installation
RUN su flutteruser -c "$FLUTTER_HOME/bin/flutter --version" || echo "Warning: Flutter verification skipped"

# Install Flutter wrapper to handle Android license acceptance
RUN mv /usr/local/flutter/bin/flutter /usr/local/flutter/bin/flutter.real 2>/dev/null || true && \
    cp /usr/local/bin/flutter-doctor-wrapper.sh /usr/local/flutter/bin/flutter && \
    chmod +x /usr/local/flutter/bin/flutter && \
    chown flutteruser:flutteruser /usr/local/flutter/bin/flutter*

# Entrypoint for ADB bridge
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Default command - interactive shell
USER flutteruser
CMD ["/bin/zsh"]
