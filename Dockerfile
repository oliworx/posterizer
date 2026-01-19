FROM php:8.4-cli-bookworm
WORKDIR "/app"
EXPOSE 8080
RUN apt-get -y update && apt-get install -y --no-install-recommends pdfposter && rm -rf /var/lib/apt/lists/*
CMD [ "php", "-S", "0.0.0.0:8080" ]
COPY . /app
