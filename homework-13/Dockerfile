FROM ubuntu:kinetic

#
# Update the image to the latest packages
RUN apt-get update && apt-get upgrade -y

#
# Install NGINX to test.
RUN apt-get install nginx -y

#
# Expose port 80
EXPOSE 80

COPY index.html /var/www/html/index.html

#
# Last is the actual command to start up NGINX within our Container
CMD ["nginx", "-g", "daemon off;"]