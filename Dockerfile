FROM debian:stable-slim

ENV BRANCH_READSB=v3.8.3 \
    BEASTPORT=30005 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    TZ=UTC \
    MLATPORT=30105 \
    DATAPATH=/data

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Copy config files
COPY etc/ /etc/

RUN set -x && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        collectd-core \
        curl \
        file \
        gcc \
        git \
        gnupg2 \
        libc-dev \
        libpython2.7 \
        libpython3.7-minimal \
        make \
        ncurses-dev \
        nginx-light \
        procps \
        python3-minimal \
        rrdtool \
        && \
    # Install readsb
    git clone https://github.com/Mictronics/readsb.git /src/readsb && \
    pushd /src/readsb && \
    git checkout tags/"${BRANCH_READSB}" && \
    echo "readsb ${BRANCH_READSB}" >> /VERSIONS && \
    make OPTIMIZE="-O3" && \
    mv viewadsb /usr/local/bin/ && \
    mv readsb /usr/local/bin/ && \
    mkdir -p /run/readsb && \
    popd && \
    # Deploy graphs1090
    git clone \
        -b master \
        --depth 1 \
        https://github.com/wiedehopf/graphs1090.git \
        /usr/share/graphs1090/git \
        && \
    pushd /usr/share/graphs1090/git && \
    git log | head -1 | tr -s " " "_" | tee /VERSION && \
    git log | head -1 | tr -s " " "_" | cut -c1-14 > /CONTAINER_VERSION && \
    cp -v /usr/share/graphs1090/git/dump1090.db /usr/share/graphs1090/ && \
    cp -v /usr/share/graphs1090/git/dump1090.py /usr/share/graphs1090/ && \
    cp -v /usr/share/graphs1090/git/system_stats.py /usr/share/graphs1090/ && \
    cp -v /usr/share/graphs1090/git/LICENSE /usr/share/graphs1090/ && \
    cp -v /usr/share/graphs1090/git/*.sh /usr/share/graphs1090/ && \
    cp -v /usr/share/graphs1090/git/collectd.conf /etc/collectd/collectd.conf && \
    cp -v /usr/share/graphs1090/git/nginx-graphs1090.conf /usr/share/graphs1090/ && \
    chmod -v a+x /usr/share/graphs1090/*.sh && \
    sed -i -e 's/XFF.*/XFF 0.8/' /etc/collectd/collectd.conf && \
    sed -i -e 's/skyview978/skyaware978/' /etc/collectd/collectd.conf && \
    cp -rv /usr/share/graphs1090/git/html /usr/share/graphs1090/ && \
    sed -i -e "s/__cache_version__/$(date +%s | tail -c5)/g" /usr/share/graphs1090/html/index.html && \
    mkdir -p /usr/share/graphs1090/data-symlink && \
    mkdir -p /var/lib/collectd/rrd/localhost/dump1090-localhost && \
    mkdir -p /data && \
    ln -s /data /usr/share/graphs1090/data-symlink/data && \
    mkdir -p /run/graphs1090 && \
    popd && \
    # Copy nginx config
    cp -Rv /etc/nginx.graphs1090/* /etc/nginx/ && \
    rm -rf /etc/nginx.graphs1090 && \
    # Deploy s6-overlay
    curl -s https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh && \
    # Clean up
    apt-get remove -y \
        curl \
        file \
        gcc \
        git \
        gnupg2 \
        libc-dev \
        make \
        ncurses-dev \
        && \
    apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /src /tmp/* /var/lib/apt/lists/*

ENTRYPOINT [ "/init" ]

EXPOSE 80

# Specify location of rrd files as volume
VOLUME [ "/var/lib/collectd/rrd" ]
