FROM node:lts-alpine

WORKDIR ./app

COPY . .

RUN apk update && apk add postgresql postgresql-contrib && npm install

RUN npm install mongodb

RUN mkdir -p /var/lib/postgresql/data

RUN chown -R postgres:postgres /var/lib/postgresql/data

RUN mkdir -p /run/postgresql && chown -R postgres:postgres /run/postgresql

RUN su - postgres -c "initdb -D /var/lib/postgresql/data"

EXPOSE 3000


CMD su - postgres -c "pg_ctl start -D /var/lib/postgresql/data -l /var/lib/postgresql/data/logfile" && \
        sleep 5 && \
        psql -U postgres -c "DROP DATABASE IF EXISTS physicaltheraby;" && \
        psql -U postgres -c "CREATE DATABASE physicaltheraby;" && \
        psql -U postgres -d physicaltheraby -f /app/database/physicaltherabydb.sql && \
        npm start
