# syntax = docker/dockerfile:1

# ------------------------------
# Base stage
# ------------------------------
ARG RUBY_VERSION=3.3.5
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# ------------------------------
# Build stage
# ------------------------------
FROM base AS build

# Install build dependencies AND Node.js for asset compilation
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      libvips \
      pkg-config \
      nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap for faster boot
RUN bundle exec bootsnap precompile app/ lib/

# Precompile Rails assets without requiring master key
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# ------------------------------
# Final production image
# ------------------------------
FROM base AS final

# Install only runtime dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libvips \
      postgresql-client \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

# Copy built gems and application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Add non-root user
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

# Entrypoint for Rails
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Default Rails server
EXPOSE 3000
CMD ["./bin/rails", "server"]