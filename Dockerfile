FROM php:8.3-cli-bookworm
COPY . /app
WORKDIR "/app"
EXPOSE 8080
RUN apt-get -y update && apt-get install -y --no-install-recommends pdfposter
CMD [ "php", "-S", "0.0.0.0:8080" ]
