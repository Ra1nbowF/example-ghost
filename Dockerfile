# Stage 1: Build stage for installing ghost-storage-cloudinary
FROM ghost:5-alpine as cloudinary

# Install necessary build tools (g++, make, python3) and curl for 'n' (Node.js version manager).
# '--no-cache' keeps the image size smaller.
RUN apk add --no-cache curl python3 make g++ && \
    # Download the 'n' script and make it executable.
    curl -L https://raw.githubusercontent.com/tj/n/master/bin/n -o /usr/local/bin/n && \
    chmod +x /usr/local/bin/n

# Install Node.js version 18.20.1 using 'n'. This will override the default Node.js version in the image.
# You can check Node.js's official releases for the latest stable 18.x.x LTS version if needed.
RUN n 18.20.1

# Set the PATH environment variable to prioritize the newly installed Node.js 18.
# This ensures that subsequent commands, especially for the 'node' user, use this specific version.
ENV PATH="/usr/local/n/versions/node/18.20.1/bin:${PATH}"

# Install the ghost-storage-cloudinary package.
# 'su-exec node' ensures the command runs under the 'node' user, which is Ghost's default user.
RUN su-exec node yarn add ghost-storage-cloudinary

# --- Stage 2: Final Ghost Application Image ---
FROM ghost:5-alpine

# Re-install Node.js 18.20.1 in the final image.
# This is crucial because the final running Ghost application also needs Node.js 18.
RUN apk add --no-cache curl python3 make g++ && \
    curl -L https://raw.githubusercontent.com/tj/n/master/bin/n -o /usr/local/bin/n && \
    chmod +x /usr/local/bin/n
RUN n 18.20.1
ENV PATH="/usr/local/n/versions/node/18.20.1/bin:${PATH}"

# Copy the installed node_modules and specifically the ghost-storage-cloudinary adapter
# from the 'cloudinary' build stage to the final image.
# This leverages Docker's multi-stage build caching and avoids redundant installations.
COPY --chown=node:node --from=cloudinary $GHOST_INSTALL/node_modules $GHOST_INSTALL/node_modules
COPY --chown=node:node --from=cloudinary $GHOST_INSTALL/node_modules/ghost-storage-cloudinary $GHOST_INSTALL/content/adapters/storage/ghost-storage-cloudinary

# Configure Ghost settings using the Ghost CLI.
# These commands enable Cloudinary as the storage adapter and configure various upload/fetch options.
# They also set up Mailgun for email transport.
RUN set -ex; \
    su-exec node ghost config storage.active ghost-storage-cloudinary; \
    su-exec node ghost config storage.ghost-storage-cloudinary.upload.use_filename true; \
    su-exec node ghost config storage.ghost-storage-cloudinary.upload.unique_filename false; \
    su-exec node ghost config storage.ghost-storage-cloudinary.upload.overwrite false; \
    su-exec node ghost config storage.ghost-storage-cloudinary.fetch.quality auto; \
    su-exec node ghost config storage.ghost-storage-cloudinary.fetch.cdn_subdomain true; \
    su-exec node ghost config mail.transport "SMTP"; \
    su-exec node ghost config mail.options.service "Mailgun";

# Any other custom configurations or commands you had in your original Dockerfile
# should be added here if they are still required.
