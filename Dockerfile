FROM alpine:3.20

# Install perl and required system dependencies
RUN apk add --no-cache \
    perl \
    perl-dev \
    perl-app-cpanminus \
    make \
    gcc \
    musl-dev \
    gmp-dev

# Set working directory
WORKDIR /app

# Copy application files
COPY . .

# Install dependencies
RUN cpanm --installdeps .

# Build Module
RUN perl Makefile.PL && make && make install

# Default command
CMD ["perl", "-MMFab::Plugins::Datadog", "-e1"]
