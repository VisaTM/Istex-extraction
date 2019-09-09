
# FROM ubuntu:18.04
FROM perl:5-slim
LABEL maintainer="Dominique Besagni <dominique.besagni@inist.fr>"

# Install applications and set rights

COPY IstexMetadata.pl /usr/bin/IstexMetadata.pl

RUN chmod 0755 /usr/bin/IstexMetadata.pl
RUN ln -s /usr/bin/IstexMetadata.pl /usr/bin/IstexMetadata

# Install necessary tools and clean up

# RUN apt-get update \
#    && apt-get install -y apt-utils 

ARG cpanm_args

RUN apt-get update \
    && apt-get install -y gcc libc6-dev make openssl libssl-dev zlib1g zlib1g-dev \
    file zip unzip --no-install-recommends \
    && cpanm -q ${cpanm_args} Encode \
    && cpanm -q ${cpanm_args} URI::Encode \
    && cpanm -q ${cpanm_args} -f HTTP::Request HTTP::Response HTTP::Headers HTTP::Status \
    && cpanm -q ${cpanm_args} -f HTTP::Cookies HTTP::Negotiate HTTP::Daemon HTML::HeadParser \
    && cpanm -q ${cpanm_args} -f Net::SSLeay IO::Socket::SSL \
    && cpanm -q ${cpanm_args} LWP::UserAgent \
    && cpanm -q ${cpanm_args} LWP::Protocol::https \
    && cpanm -q ${cpanm_args} HTTP::CookieJar::LWP \
    && cpanm -q ${cpanm_args} JSON \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && apt-get clean \
    && rm -fr /var/cache/apt/* /var/lib/apt/lists/* \
    && rm -fr ./cpanm /root/.cpanm /usr/src/* /tmp/*

# Run IstexMetadata

WORKDIR /tmp
CMD ["/usr/bin/IstexMetadata.pl", "-h"]
