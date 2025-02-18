# PostgreSQL upgrade image
FROM postgres:17-bookworm

LABEL maintainer="jhahn@localhost"

ARG POSTGRES_NEW

RUN apt-get update \
 && apt-get install -qq -y sudo

RUN adduser postgres sudo \
 && echo '%postgres ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
 && mkdir -p /var/log/postgresql

WORKDIR /var/log/postgresql

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
