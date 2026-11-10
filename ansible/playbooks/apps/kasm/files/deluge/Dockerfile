# Deluge that zips each finished torrent into ~/Downloads, so Kasm's download
# panel can fetch it as one file. Keep the base at the Kasm server's version
# (kasm_image in site_ldn/app_kasm/vars.yml), not newer.
FROM kasmweb/deluge:1.18.0-rolling-weekly
USER root

RUN apt-get update \
 && apt-get install -y --no-install-recommends zip \
 && rm -rf /var/lib/apt/lists/*

# Kasm copies /home/kasm-default-profile into each new session's
# /home/kasm-user. Don't map ~/.config to a host folder for this workspace:
# that copy would overwrite whatever is saved there.
ENV HOME=/home/kasm-default-profile
WORKDIR $HOME

# No COPY --chmod: the work VM's Kasm Docker builds with the classic builder (no buildx)
COPY torrent-archive /usr/local/bin/torrent-archive
COPY core.conf execute.conf $HOME/.config/deluge/
RUN chmod 755 /usr/local/bin/torrent-archive \
 && mkdir -p $HOME/torrents \
 && chown -R 1000:0 $HOME/.config/deluge $HOME/torrents

ENV HOME=/home/kasm-user
WORKDIR $HOME
USER 1000
