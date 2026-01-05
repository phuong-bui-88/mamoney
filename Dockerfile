FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# -------------------------
# Core paths (ORDER MATTERS)
# -------------------------
ENV ANDROID_HOME=/opt/android-sdk
ENV FLUTTER_HOME=/usr/local/flutter
ENV PUB_CACHE=/pub-cache

ENV PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$ANDROID_HOME/platform-tools:$PATH"

# -------------------------
# ADB → Windows host
# -------------------------
ENV ADB_SERVER_SOCKET=tcp:host.docker.internal:5037

# -------------------------
# System dependencies
# -------------------------
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
    chromium-browser \
    zsh \
 && rm -rf /var/lib/apt/lists/*

# -------------------------
# Android SDK + platform-tools (adb)
# -------------------------
RUN mkdir -p $ANDROID_HOME/cmdline-tools && \
    cd /tmp && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip && \
    unzip commandlinetools-linux-11076708_latest.zip && \
    mv cmdline-tools $ANDROID_HOME/cmdline-tools/latest && \
    rm commandlinetools-linux-11076708_latest.zip && \
    yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses && \
    $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager \
        "platform-tools" \
        "platforms;android-33" \
        "build-tools;33.0.2"

# -------------------------
# Flutter SDK
# -------------------------
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

# -------------------------
# User setup
# -------------------------
RUN mkdir -p $PUB_CACHE && \
    useradd -m -u 1000 flutteruser && \
    chown -R flutteruser:flutteruser \
        $FLUTTER_HOME \
        $ANDROID_HOME \
        $PUB_CACHE && \
    chsh -s /bin/zsh flutteruser

# -------------------------
# Oh My Zsh
# -------------------------
RUN su flutteruser -c \
    'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' && \
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="robbyrussell"/' /home/flutteruser/.zshrc

# -------------------------
# Git safety
# -------------------------
RUN su flutteruser -c \
    "git config --global --add safe.directory /usr/local/flutter"

# -------------------------
# Workspace
# -------------------------
USER flutteruser
WORKDIR /workspace

# -------------------------
# Verify
# -------------------------
RUN flutter --version && adb version

CMD ["/bin/zsh"]
