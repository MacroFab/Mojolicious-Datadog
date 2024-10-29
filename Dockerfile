FROM alpine:3.18

# Install perl and required system dependencies
RUN apk add --no-cache \
    perl \
    perl-dev \
    perl-app-cpanminus \
    make \
    gcc \
    musl-dev \
    gmp-dev

# Install required Perl modules
RUN cpanm --notest \
    Mojo::Base \
    Time::HiRes \
    Crypt::Random \
    Math::Pari

# Set working directory
WORKDIR /app

# Copy application files
COPY . .

# Install module dependencies
RUN perl Makefile.PL && make && make install

# Default command
CMD ["perl", "-MMFab::Plugins::Datadog", "-e1"]
