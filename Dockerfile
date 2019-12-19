FROM ruby:2.5

RUN mkdir ghtorrent
COPY Gemfile ghtorrent.gemspec ./ghtorrent/
COPY lib/ ./ghtorrent/lib/
COPY bin/ ./ghtorrent/bin
RUN cd ghtorrent && bundle install --without development test

ENTRYPOINT ["/ghtorrent/bin/docker-init.sh"]
