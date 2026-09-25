# --- Stage 1: build the React SPA into public/ ---
FROM node:22-bookworm-slim AS frontend
WORKDIR /app
COPY frontend/package.json frontend/package-lock.json ./frontend/
RUN cd frontend && npm ci
COPY frontend/ ./frontend/
# vite.config.ts writes the build to ../public
RUN cd frontend && npm run build

# --- Stage 2: the Rails app (API + serves the built SPA) ---
FROM ruby:3.4-slim AS app
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential libsqlite3-dev libyaml-dev curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV RAILS_ENV=production \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_PATH=/usr/local/bundle \
    RAILS_LOG_TO_STDOUT=true

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .
COPY --from=frontend /app/public ./public

EXPOSE 3000
# Create/migrate the SQLite schema (fast), bind the server so the platform's
# health check passes promptly, then seed the demo data in the background.
CMD ["sh", "-c", "bin/rails db:create db:migrate && (bin/rails db:seed >/tmp/seed.log 2>&1 &) && bin/rails server -b 0.0.0.0"]
