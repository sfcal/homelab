FROM ubuntu:26.04

RUN apt-get update && apt-get install -y \
    gcc \
    gcc-i686-linux-gnu \
    binutils-i686-linux-gnu \
    make \
    git \
    liblzma-dev \
    mtools \
    genisoimage \
    isolinux \
    perl \
    openssl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/ipxe/ipxe.git /ipxe

COPY boot.ipxe /ipxe/src/boot.ipxe
COPY ipxe-accept-ip-literal.patch /ipxe/ipxe-accept-ip-literal.patch

WORKDIR /ipxe/src

# The Haivision kicker's per-product release scripts hard-code https:// URLs by
# raw IP (https://10.65.0.32/...), but the server cert only has DNS SANs, so
# stock iPXE fails with "Incorrect certificate name". Accept IP-literal URLs;
# hostname URLs are still matched strictly.
RUN git -C /ipxe apply --check ipxe-accept-ip-literal.patch && git -C /ipxe apply ipxe-accept-ip-literal.patch

# Enable HTTPS downloads: the Haivision kicker redirects HTTP to HTTPS and
# serves the boot menu over TLS. Upstream iPXE leaves HTTPS disabled by default.
RUN mkdir -p config/local && echo '#define DOWNLOAD_PROTO_HTTPS' >> config/local/general.h

# Trust the Let's Encrypt root directly (install.mtl.haivision.com chains to
# ISRG Root X1) so iPXE does not need to fetch cross-signed certs from
# ca.ipxe.org at boot time.
ADD https://letsencrypt.org/certs/isrgrootx1.pem /ipxe/src/isrgrootx1.pem

# TRUST= only embeds the fingerprint; CERT= embeds the full certificate. Both are
# needed because the server's chain stops at the "Root YR" intermediate and
# never includes ISRG Root X1 itself.
RUN make -j$(nproc) bin/ipxe.iso EMBED=boot.ipxe TRUST=isrgrootx1.pem CERT=isrgrootx1.pem CROSS=i686-linux-gnu-

CMD ["cp", "/ipxe/src/bin/ipxe.iso", "/output/ipxe.iso"]
