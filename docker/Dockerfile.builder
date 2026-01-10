FROM debian:13

LABEL maintainer="ZoneMinder"
LABEL description="ZoneMinder package builder for Debian Trixie"

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV TZ=UTC

# Enable deb-src repositories
RUN if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
        sed -i 's/^Types: deb$/Types: deb deb-src/g' /etc/apt/sources.list.d/debian.sources; \
    fi && \
    apt-get update

# Install build tools
RUN apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    devscripts \
    debhelper \
    equivs \
    fakeroot \
    cmake \
    pkg-config \
    ccache \
    curl \
    bash

# Install ZoneMinder build dependencies
RUN apt-get install -y --no-install-recommends \
    dh-linktree \
    dh-apache2 \
    sphinx-doc \
    python3-sphinx \
    python3-sphinx-rtd-theme \
    libavcodec-dev \
    libavdevice-dev \
    libavformat-dev \
    libavutil-dev \
    libswresample-dev \
    libswscale-dev \
    libbz2-dev \
    libturbojpeg0-dev \
    default-libmysqlclient-dev \
    libpolkit-gobject-1-dev \
    libv4l-dev \
    libvlc-dev \
    libssl-dev \
    libvncserver-dev \
    libjwt-gnutls-dev \
    libgsoap-dev \
    gsoap \
    libmosquittopp-dev \
    libpcre2-dev \
    libcurl4-gnutls-dev \
    ffmpeg \
    arp-scan \
    net-tools \
    iproute2 \
    libdate-manip-perl \
    libdbd-mysql-perl \
    libphp-serialization-perl \
    libsys-mmap-perl \
    libdata-uuid-perl \
    libcrypt-eksblowfish-perl \
    libdata-entropy-perl \
    nlohmann-json3-dev

# Clean up apt cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy source code
COPY . /build/zoneminder

# Build script
RUN echo '#!/bin/bash\n\
set -e\n\
cd /build/zoneminder\n\
\n\
# Link debian packaging files\n\
ln -sf distros/ubuntu2004 debian\n\
\n\
# Install any additional build deps from debian/control\n\
mk-build-deps -ir -t "apt-get -y --no-install-recommends" debian/control || true\n\
\n\
# Build packages\n\
DEB_BUILD_OPTIONS="parallel=$(nproc)" dpkg-buildpackage -us -uc -b\n\
\n\
# Move artifacts to output directory\n\
mkdir -p /output\n\
mv /build/*.deb /output/ 2>/dev/null || true\n\
mv /build/*.buildinfo /output/ 2>/dev/null || true\n\
mv /build/*.changes /output/ 2>/dev/null || true\n\
\n\
echo "Build complete. Packages in /output:"\n\
ls -la /output/\n\
' > /build/build.sh && chmod +x /build/build.sh

CMD ["/build/build.sh"]
