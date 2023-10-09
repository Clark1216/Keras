# ARG UBUNTU_VERSION=18.04
# ARG ARCH=
# ARG CUDA=10.0
# FROM nvidia/cuda${ARCH:+-$ARCH}:${CUDA}-base-ubuntu${UBUNTU_VERSION} as base
FROM nvcr.io/nvidia/tensorflow:22.11-tf2-py3 as base

# Create a non-root user with low permissions to run container process
RUN groupadd -g 999 sfmt && useradd -r -u 999 -g sfmt sfmt

# Install tools
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    wget \
    unzip \
	git && \
	rm -rf /var/lib/apt/lists/*

# Install gosu for easy step-down from root (https://github.com/tianon/gosu)
ENV GOSU_VERSION 1.14
RUN set -eux; \
# save list of currently installed packages for later so we can clean up
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates wget; \
	if ! command -v gpg; then \
		apt-get install -y --no-install-recommends gnupg2 dirmngr; \
	elif gpg --version | grep -q '^gpg (GnuPG) 1\.'; then \
# "This package provides support for HKPS keyservers." (GnuPG 1.x only)
		apt-get install -y --no-install-recommends gnupg-curl; \
	fi; \
	rm -rf /var/lib/apt/lists/*; \
	\
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	\
# verify the signature
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	command -v gpgconf && gpgconf --kill all || :; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	\
# clean up fetch dependencies
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	\
	chmod +x /usr/local/bin/gosu; \
# verify that the binary works
	gosu --version; \
	gosu nobody true


###############################################################################
#
#							Python
#
###############################################################################

# Create a symbolic link so that both "python" and "python3" link to same binary
RUN ln -s $(which python3) /usr/local/bin/python


###############################################################################
#
#							Python Packages
#
###############################################################################
# Install dependencies for SocketIO and matplotlib
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
	netbase \
	libsm6 \
	libxext6 \
	libfontconfig1 \
	libxrender1 \
	python3-tk \
	xinput \
	libcanberra-gtk-module \
	libcanberra-gtk3-module && \
	rm -rf /var/lib/apt/lists/*

# Install Python packages
COPY requirements.txt /
RUN pip3 install --upgrade pip
RUN pip3 install -r /requirements.txt


###############################################################################
#
#							Container Startup & Command
#
###############################################################################

WORKDIR /Keras

COPY docker-entrypoint.sh /Keras
RUN chmod +x /Keras/docker-entrypoint.sh

#Set time zone
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN echo 'Asia/Shanghai' >/etc/timezone

ENTRYPOINT ["./docker-entrypoint.sh"]
