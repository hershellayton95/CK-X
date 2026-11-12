FROM nginx:1.30-alpine

# Pick up the latest Alpine security patches at build time.
RUN apk upgrade --no-cache

# Remove the default Nginx configuration
RUN rm /etc/nginx/conf.d/default.conf

# Copy our custom configuration
COPY default.conf /etc/nginx/conf.d/

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"] 