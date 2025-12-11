FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    container=docker

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        systemd \
        systemd-sysv \
        sudo \
        psmisc \
        curl \
        apt-utils \
        rsync \
        lsb-release \
        dbus \
        openssh-client \
        ca-certificates \
        util-linux \
        dialog \
        libterm-readline-perl-perl \
        sshpass \
        systemd-timesyncd \
        xz-utils \
        iproute2 \
        net-tools \
        tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*



VOLUME [ "/sys/fs/cgroup" ]
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
