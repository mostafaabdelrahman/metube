FROM node:lts-alpine as builder

WORKDIR /metube
COPY ui ./
RUN npm ci && \
    node_modules/.bin/ng build --configuration production


FROM python:3.11-alpine

ENV UID=1000
ENV GID=1000
ENV UMASK=022

ENV DOWNLOAD_DIR=/downloads
ENV STATE_DIR=/downloads/.metube
ENV TEMP_DIR=/downloads

USER ${UID}:${GID}

WORKDIR /app

COPY Pipfile* docker-entrypoint.sh ./

USER root

# Use sed to strip carriage-return characters from the entrypoint script (in case building on Windows)
# Install dependencies
RUN sed -i 's/\r$//g' docker-entrypoint.sh && \
    chmod +x docker-entrypoint.sh && \
    apk add --no-cache --update ffmpeg aria2 coreutils shadow su-exec curl && \
    apk add --no-cache --update --virtual .build-deps gcc g++ musl-dev && \
    pip install --no-cache-dir pipenv && \
    pipenv install --system --deploy --clear && \
    pip uninstall pipenv -y && \
    apk del .build-deps && \
    rm -rf /var/cache/apk/* && \
    mkdir /.cache && chmod 777 /.cache

USER ${UID}:${GID}

COPY app ./app
COPY --from=builder /metube/dist/metube ./ui/dist/metube


VOLUME /downloads
EXPOSE 8081
CMD [ "./docker-entrypoint.sh" ]
