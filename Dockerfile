
# Base image
FROM ubuntu:22.04

# Non-interactive mode
ENV DEBIAN_FRONTEND=noninteractive



RUN apt-get update && apt-get install -y \
    git curl wget unzip xz-utils zip ca-certificates \
    openjdk-17-jdk clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libglu1-mesa libxi6 libgconf-2-4 \
    libxss1 libxtst6 libxrandr2 libasound2 libpangocairo-1.0-0 \
    libatk1.0-0 libcairo-gobject2 libgtk-3-0 libgdk-pixbuf2.0-0 \
    zsh bash netcat-openbsd socat sed coreutils unzip \
    libc6 libc6-dev locales gnupg \
    vim \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/* 




ENV FLUTTER_HOME=/usr/local/flutter
# Install Flutter (stable)
RUN git clone https://github.com/flutter/flutter.git -b stable $FLUTTER_HOME && \
    export PATH="$FLUTTER_HOME/bin:$PATH" && \
    flutter config --enable-web && \
    flutter config --enable-linux-desktop

# Set locale to fix UTF-8 encoding issues
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# Create non-root user
RUN useradd -m -u 1000 flutteruser && \
    chown -R flutteruser:flutteruser /usr/local/flutter && \
    chsh -s /bin/zsh flutteruser

# Install Oh-My-Zsh for flutteruser with proper PATH setup to prevent utility lookup errors
# 1. Ensure essential tools are available and set the PATH globally for the build process
ENV PATH="/usr/local/flutter/bin:/opt/android-sdk/platform-tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"



# 2. Install Oh-My-Zsh as flutteruser correctly
USER flutteruser
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="robbyrussell"/' /home/flutteruser/.zshrc && \
    sed -i 's/^plugins=.*/plugins=(git docker)/' /home/flutteruser/.zshrc && \
    echo 'export PATH="/usr/local/flutter/bin:/opt/android-sdk/platform-tools:$PATH"' >> /home/flutteruser/.zshrc

# Set working directory
WORKDIR /workspace

# Default command - interactive shell
USER flutteruser
CMD ["/bin/zsh"]
