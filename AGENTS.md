# AGENTS.md

Posterizer is a single HTML page (`index.html`) plus one PHP script
(`posterize.php`) that runs `pdfposter -p 2x2a4` on an uploaded PDF.
See `README.md` for usage.

## Keep it simple

No frameworks, no JavaScript, no build step, no Composer. Prefer a few lines
of plain PHP/HTML over adding a dependency.

## Deployment

- Every push to `master` deploys automatically to Google Cloud Run
  (https://posterizer.kurmis.com/). Use a branch for anything not ready to go live.
- The container runs PHP's built-in server on port 8080 with
  `PHP_CLI_SERVER_WORKERS=4`.

## Things that are easy to get wrong

- **Everything in `/app` is public.** The built-in server serves the whole
  directory. Any file that is not part of the website (docs, tests, tooling)
  must be listed in `.dockerignore`.
- **PHP settings live in the `Dockerfile`.** The base image has no `php.ini`,
  so PHP defaults apply (2 MB upload limit, `display_errors` on) unless set
  there.
- **The 10 MB upload limit appears in three places:** `posterize.php`
  (message and size check), the `Dockerfile` (`upload_max_filesize`,
  `post_max_size`) and `tests/run.sh`. Change them together.
- Unknown paths fall back to `index.html` with HTTP 200, so a 200 response
  does not prove a file is served.

## Testing

Run before every push:

```bash
tests/run.sh
```

It builds the image, starts a container and tests it over HTTP. Requires
`docker` and `curl`. Add a test there for every bug fixed or behaviour added.
