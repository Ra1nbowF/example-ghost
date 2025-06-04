# Stage 1: Build stage for installing ghost-storage-cloudinary
FROM ghost:5-alpine as cloudinary

# Install necessary build tools (g++, make, python3) and curl.
# '--no-cache' keeps the image size smaller.
RUN apk add --no-cache curl python3 make g++

# Download and install Node.js 18.20.1 directly from nodejs.org.
# It extracts the Node.js binaries to /usr/local, which is typically in the system's PATH.
RUN curl -SLO "https://nodejs.org/dist/v18.20.1/node-v18.20.1-linux-x64.tar.gz" \
    && tar -xzf "node-v18.20.1-linux-x64.tar.gz" -C /usr/local --strip-components=1 \
    && rm "node-v18.20.1-linux-x64.tar.gz"

# --- IMPORTANT FIX: Set PATH immediately after Node.js installation ---
# Explicitly set the PATH to include /usr/local/bin, ensuring 'node' is found for subsequent commands.
ENV PATH="/usr/local/bin:${PATH}"

# Verify that Node.js 18.20.1 is now correctly installed and accessible for the root user.
RUN node -v

# Verify that Node.js 18.20.1 is also accessible for the 'node' user.
# This is crucial for 'yarn' and 'ghost-storage-cloudinary' to function correctly.
RUN su-exec node node -v

# Install the ghost-storage-cloudinary package using yarn.
# 'su-exec node' ensures the command runs under the 'node' user, which is Ghost's default user.
RUN su-exec node yarn add ghost-storage-cloudinary

# --- Stage 2: Final Ghost Application Image ---
FROM ghost:5-alpine

# Install necessary build tools in the final image.
RUN apk add --no-cache curl python3 make g++

# Download and install Node.js 18.20.1 directly in the final image as well.
# This ensures the running Ghost application uses the correct Node.js version.
RUN curl -SLO "https://nodejs.org/dist/v18.20.1/node-v18.20.1-linux-x64.tar.gz" \
    && tar -xzf "node-v18.20.1-linux-x64.tar.gz" -C /usr/local --strip-components=1 \
    && rm "node-v18.20.1-linux-x64.tar.gz"

# --- IMPORTANT FIX: Set PATH immediately after Node.js installation in the final stage ---
# Explicitly set the PATH to include /usr/local/bin in the final stage.
ENV PATH="/usr/local/bin:${PATH}"

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
