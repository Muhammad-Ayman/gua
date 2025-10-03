# Use a base image that includes Tomcat for the Guacamole web app
FROM guacamole/guacamole:1.6.0

# Switch to the root user to install dependencies
USER root

# Install PostgreSQL client for connecting to the database
RUN apt-get update && apt-get install -y postgresql-client

# Install Supervisor to manage multiple processes (guacamole, guacd, postgres)
RUN apt-get install -y supervisor

# Install the Guacamole PostgreSQL extension
RUN curl -L https://dl.apache.org/guacamole/1.6.0/binary/guacamole-auth-jdbc-postgresql-1.6.0.tar.gz | tar -xz -C /etc/guacamole/extensions

# Expose the database and Tomcat ports
EXPOSE 5432 8080

# The rest of the Dockerfile will add the database and startup scripts.
# For simplicity, we can use a second stage or scripts to set this up.
# Since a single container is not the recommended approach, this example
# demonstrates the concept of using Supervisor to manage the components.

# Use a multi-stage build to include the database or use a supervisor.
# For this simplified single-Dockerfile, we'll embed the setup.

# Copy database schema to initialize PostgreSQL
COPY --from=guacamole/guacamole:1.6.0 /opt/guacamole/bin/initdb.sh /initdb.sh
RUN /initdb.sh --postgresql > /docker-entrypoint-initdb.d/initdb.sql

# Use the official PostgreSQL image as a multi-stage build to get the database setup
FROM postgres:16 AS postgres-setup
COPY --from=0 /docker-entrypoint-initdb.d/initdb.sql /docker-entrypoint-initdb.d/

# Final image
FROM ubuntu:22.04

# Install Tomcat and other dependencies
RUN apt-get update && apt-get install -y openjdk-11-jre-headless tomcat9 postgresql postgresql-client supervisor curl

# Create Guacamole directories
RUN mkdir /etc/guacamole
RUN mkdir /etc/guacamole/extensions

# Copy extensions and WAR file from the official image
COPY --from=guacamole/guacamole:1.6.0 /opt/guacamole/extensions /etc/guacamole/extensions
COPY --from=guacamole/guacamole:1.6.0 /usr/local/tomcat/webapps/guacamole.war /var/lib/tomcat9/webapps/

# Copy the guacd executable
COPY --from=guacamole/guacd:1.6.0 /usr/local/sbin/guacd /usr/sbin/guacd

# Add supervisord configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Add entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Run the entrypoint script
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
