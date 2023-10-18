## BUILD
FROM perl:5.34.1-threaded AS build

ARG ASSP_VERSION="2.8.1 23131"

RUN mkdir -p /opt/assp/tmpDB/files

RUN export ASSP_VERSION=$(echo $ASSP_VERSION|sed -e 's/ /%20/g') \
	&& curl -o /tmp/assp.zip -L https://jaist.dl.sourceforge.net/project/assp/ASSP%20V2%20multithreading/${ASSP_VERSION}/ASSP_${ASSP_VERSION}install.zip \
	&& unzip /tmp/assp.zip -d /opt \
	&& mv /opt/assp/assp.cfg.rename_on_new_install /opt/assp/assp.cfg

RUN curl -o /tmp/assp.mod.zip -L https://jaist.dl.sourceforge.net/project/assp/ASSP%20V2%20multithreading/ASSP%20V2%20module%20installation/assp.mod.zip \
	&& unzip /tmp/assp.mod.zip -d /tmp \
	&& perl /tmp/assp.mod/install/mod_inst.pl /opt/assp

# Install perl modules
RUN cpan-outdated -p | cpanm -n
RUN cpanm Mail::SPF::Query --force --notest --quiet
RUN cpanm IO::Socket::INET6 --force --quiet
RUN cpanm IO::Compress::Lzma --force --quiet
RUN cpanm IO::Compress::Xz --force --quiet
RUN cpanm IO::Compress::Zip --force --quiet
RUN cpanm Archive::Libarchive --force --quiet
RUN cpanm Alien::Libarchive --force --quiet
RUN cpanm DVEEDEN/DBD-mysql-4.051.tar.gz --force

## 
FROM perl:5.34.1-threaded as final

RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get -y install \
		ca-certificates \
		net-tools \
		procps \
		curl \
		mariadb-client \
		clamav-daemon \
		supervisor \
	&& apt-get -y clean all \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/lib/perl5 /usr/local/lib/perl5
COPY --from=build /opt/assp /opt/assp

#COPY files /opt/assp/files
COPY assp.cfg /opt/assp/
RUN chown -R nobody:nogroup /opt/assp

RUN mkdir -p /var/run/clamav \
	&& chown clamav:clamav /var/run/clamav \
	&& /usr/bin/freshclam

COPY supervisord.conf /etc/supervisor/supervisord.conf

EXPOSE 25/tcp 55555/tcp 

CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
