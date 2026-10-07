# Yopass Setup

Yopass shares text and files using client-side encryption. The server stores encrypted
payloads in a dedicated Redis instance; the decryption key remains in the URL fragment and
is not sent to the server.

## Deployment

Create an `A` or `CNAME` record for `yopass.<domain>`, set the `yopass` profile in `.env`,
and start the two-service profile:

```dotenv
COMPOSE_PROFILES=yopass
```

```bash
docker compose config --services
docker compose up -d yopass-redis yopass
```

Traefik terminates HTTPS and does not publish the Yopass or Redis container ports on the
host. Redis uses append-only persistence in the `yopass-redis-data` volume.

## Verification

```bash
docker compose ps yopass yopass-redis
docker exec yopass /yopass-server --health-check
curl -fsS https://yopass.<domain>/config
```

Create a one-time test secret in the browser, open its generated link once, and confirm
that a second retrieval fails. Do not put real credentials in test data.

## Operations

The open-source edition has no account requirement for creating secrets, so anyone who
can reach the public route can use it. Monitor resource use and application logs for abuse.
Back up `yopass-redis-data` if active, unexpired links must survive host recovery.

To stop the service without deleting encrypted payloads:

```bash
docker compose stop yopass yopass-redis
```

Never use `docker compose down -v` as a rollback because it deletes the Redis volume.
