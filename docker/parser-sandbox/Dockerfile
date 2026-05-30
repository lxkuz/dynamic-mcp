FROM ruby:3.2.2-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential && \
    rm -rf /var/lib/apt/lists/*

RUN gem install json -v 2.7.2 && \
    gem install pdf-reader -v 2.14.1 && \
    gem install nokogiri -v 1.18.9 && \
    gem install rexml -v 3.4.1

WORKDIR /data
USER nobody

ENTRYPOINT ["ruby"]
