FROM ruby:2.5

RUN mkdir ghtorrent
COPY Gemfile ghtorrent.gemspec ./ghtorrent/
COPY lib/ ./ghtorrent/lib/
COPY bin/ ./ghtorrent/bin
RUN cd ghtorrent && bundle install --without development test
RUN cd ghtorrent && gem install sqlite3

CMD /usr/bin/env bash
#ENTRYPOINT ["/usr/local/bin/ruby", "-I/ghtorrent/lib", "/ghtorrent/bin/ght-retrieve-repo"]
