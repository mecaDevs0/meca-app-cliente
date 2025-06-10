FROM ubuntu:22.04

# Instala dependências necessárias
RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils zip libglu1-mesa openjdk-17-jdk wget && \
    rm -rf /var/lib/apt/lists/*

# Instala Flutter
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter -b stable
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Configura Android SDK
ENV ANDROID_SDK_ROOT="/opt/android-sdk"
ENV ANDROID_HOME="/opt/android-sdk"
ENV PATH="${PATH}:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools"

# Download e instala Android Command Line Tools
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
    cd ${ANDROID_SDK_ROOT} && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip && \
    unzip commandlinetools-linux-10406996_latest.zip && \
    mv cmdline-tools latest && \
    mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
    mv latest ${ANDROID_SDK_ROOT}/cmdline-tools/ && \
    rm commandlinetools-linux-10406996_latest.zip

# Aceita licenças e instala componentes do Android SDK
RUN yes | ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null || true
RUN ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager \
    "platform-tools" \
    "platforms;android-33" \
    "platforms;android-31" \
    "build-tools;33.0.0"

# Aceita licenças do Flutter
RUN yes | flutter doctor --android-licenses || true

# Configura o Gradle para usar caminhos Unix
ENV GRADLE_OPTS="-Dorg.gradle.native=false -Dorg.gradle.daemon=false"

# Configura entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Define diretório de trabalho
WORKDIR /workspace

ENTRYPOINT ["/entrypoint.sh"]

