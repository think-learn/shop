# ──────────────────────────────────────────────
# Stage 1: Build (optional – ready for future
#           Node/React upgrades)
# ──────────────────────────────────────────────
FROM nginx:1.25-alpine AS production

# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy app source
COPY src/ /usr/share/nginx/html/

# Copy custom nginx config
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Expose port 80
EXPOSE 80

# Health-check so ECS / Docker knows the container is alive
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
