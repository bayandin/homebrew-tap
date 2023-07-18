# Neon Local Homebrew Tap

Homebrew tap that allows to install and run [Neon](http://neon.tech/) locally.

# Quick Start

```bash
brew install bayandin/tap/neon-local
```
The command installs `neon-local` and creates configuration in `"$(brew --prefix)/var/neon"` directory.

Based on examples from [neondatabase/neon](https://github.com/neondatabase/neon#running-neon-database) repository (instead of `cargo neon` from the documentaion, we use `neon-local`).
```bash
neon-local start
neon-local tenant create --set-default
neon-local tenant list
neon-local endpoint list
```

```bash
psql -p55432 -h 127.0.0.1 -U cloud_admin postgres
```

# Formulae in the tap

- [`neon-local`](https://github.com/bayandin/homebrew-tap/blob/main/Formula/neon-local.rb). Meta-formula that installs all the required dependencies and configures Neon to run locally.
- [`neon-postgres`](https://github.com/bayandin/homebrew-tap/blob/main/Formula/neon-postgres.rb). Compute part of Neon. The formula contains Postgres 14 and 15.
- [`neon-storage`](https://github.com/bayandin/homebrew-tap/blob/main/Formula/neon-storage.rb). Storage part of Neon. It contains Pageserver, Safekeeper, and other required binaries.
- [`neon-extension`](https://github.com/bayandin/homebrew-tap/blob/main/Formula/neon-extension.rb). Postgres extensions that provide communication between Compute and Storage.

# Extensions:

In addition, you can try Neon locally with extentions from this tap. To install them run the following command `brew install bayandin/tap/<extension>`:
- [`pg_cron`](Formula/pg_cron.rb) — Run periodic jobs in PostgreSQL
- [`pg_embedding`](https://github.com/bayandin/homebrew-tap/blob/main/Formula/pg_embedding.rb) — HNSW algorithm for vector similarity search in PostgreSQL
- [`pgvector`](Formula/pgvector.rb) — Open-source vector similarity search for Postgres
- [`postgresql-hll`](Formula/postgresql-hll.rb) — PostgreSQL extension adding HyperLogLog data structures as a native data type

_Note: extensions provided by the tap could be different from what's [available in Neon Cloud offering](https://neon.tech/docs/extensions/pg-extensions)._

