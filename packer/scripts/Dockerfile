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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/ipxe/ipxe.git /ipxe

COPY boot.ipxe /ipxe/src/boot.ipxe

WORKDIR /ipxe/src

RUN make -j$(nproc) bin/ipxe.iso EMBED=boot.ipxe CROSS=i686-linux-gnu-

CMD ["cp", "/ipxe/src/bin/ipxe.iso", "/output/ipxe.iso"]
