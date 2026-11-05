# Posterizer

Turn any PDF into a poster: upload a page, get back a PDF split into **4 A4 sheets (2×2)** that you print on a regular printer and tape together.

**Live:** https://posterizer.kurmis.com/

## How it works

1. Open the website and choose a PDF file (max. 10 MB).
2. Click **Posterize it**.
3. Your browser downloads `Poster_<yourfile>.pdf`, ready to print on A4.

Under the hood, [`posterize.php`](posterize.php) passes the upload to
[pdfposter](https://pdfposter.readthedocs.io/) (`pdfposter -p 2x2a4`) and
streams the result back. Uploaded and generated files are deleted right after
the download; nothing is stored.

## Run it yourself

### With Docker

```bash
docker build -t posterizer .
docker run --rm -p 8080:8080 posterizer
```

Then open http://localhost:8080.

The image is based on `php:8.4-cli-bookworm`, installs `pdfposter` and serves
the app with PHP's built-in web server on port 8080.

### Without Docker

Requirements: PHP 8.x and `pdfposter` on the `PATH`
(Debian/Ubuntu: `apt install pdfposter`, otherwise `pip install pdftools.pdfposter`).

```bash
php -S localhost:8080
```

## Tests

```bash
tests/run.sh
```

Builds the Docker image, starts a container and checks it over HTTP: PHP
upload limits, poster output (4 A4 pages), error messages for missing,
non-PDF and oversized files, and parallel request handling. Needs only
`docker` and `curl`; set `PORT` if 18080 is taken.

## Project structure

| File | Purpose |
|------|---------|
| `index.html` | Upload form (single page, inline CSS, no JavaScript) |
| `posterize.php` | Validates the upload, runs `pdfposter`, returns the poster PDF |
| `Dockerfile` | Container image for deployment |
| `tests/run.sh` | Test suite against the Docker container |
| `site.webmanifest`, `favicon*`, `*.png` | Icons and web app manifest |

## Limits

- PDF files only, up to 10 MB. PHP's `upload_max_filesize` and
  `post_max_size` must allow this as well.
- Fixed output format: 2×2 A4 sheets.

## Author

Oliver Kurmis – oliver@kurmis.com

## License
MIT License: <https://kurmis.mit-license.org>
