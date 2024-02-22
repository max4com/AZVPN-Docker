FROM alpine:latest as builder
# Docker cant unpack remote archives via ADD command :(
# Lets use multistage build to download and unpack remote archive.
# https://antizapret.prostovpn.org/container-images/az-vpn/rootfs.tar.xz
RUN wget https://raw.githubusercontent.com/max4com/AZVPN/main/container-images/az-vpn/rootfs.tar.xz --no-check-certificate  \
    && mkdir /rootfs-dir  \
    && tar -xf /rootfs.tar.xz -C /rootfs-dir/

FROM scratch
COPY --from=builder /rootfs-dir /
RUN wget https://secure.nic.cz/files/knot-resolver/knot-resolver-release.deb --no-check-certificate \
    && dpkg --force-confnew -i knot-resolver-release.deb \
    && rm knot-resolver-release.deb \
    && chmod 1777 /tmp \
    && apt update -y \
    && apt upgrade -y -o Dpkg::Options::="--force-confold" \
    && apt autoremove -y && apt clean

RUN cd /root/antizapret/ \
    && git pull \
    # fix invalid domains
    # https://ntc.party/t/129/636
    && sed -i -E "s/(CHARSET=UTF-8 idn)/\1 --no-tld | grep -Fv 'xn--'/g" /root/antizapret/parse.sh \
    # fix apple.com \
    # https://ntc.party/t/129/372
    && echo "\n\
-- Resolve Apple \n\
policy.add(\n\
    policy.suffix(\n\
        policy.FORWARD(\n\
            {'77.88.8.8'}\n\
        ),\n\
        policy.todnames({'apple.com.', 'mzstatic.com.', 'akamaiedge.net.', 'edgekey.net.', 'aaplimg.com.'})\n\
    )\n\
)\
    " >> /etc/knot-resolver/kresd.conf

COPY ./init.sh /
ENTRYPOINT ["/init.sh"]
