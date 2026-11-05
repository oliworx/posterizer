FROM php:8.4-cli-bookworm
WORKDIR "/app"
EXPOSE 8080
ENV PHP_CLI_SERVER_WORKERS=4
RUN apt-get -y update && apt-get install -y --no-install-recommends pdfposter && rm -rf /var/lib/apt/lists/*
RUN printf "upload_max_filesize = 10M\npost_max_size = 11M\n" > "$PHP_INI_DIR/conf.d/uploads.ini"
CMD [ "php", "-S", "0.0.0.0:8080" ]
COPY . /app
