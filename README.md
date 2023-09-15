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

- [`neon-local`](Formula/neon-local.rb). Meta-formula that installs all the required dependencies and configures Neon to run locally.
  - [`neon-storage`](Formula/neon-storage.rb). Storage part of Neon. It contains Pageserver, Safekeeper, and other required binaries
  - [`neon-postgres`](Formula/neon-postgres.rb). Compute part of Neon. The formula contains Postgres 14 and 15
  - [`neon-extension`](Formula/neon-extension.rb). Postgres extensions that provide communication between Compute and Storage
- [`pgrx`](Formula/pgrx.rb). Build Postgres Extensions with Rust
- [`pgx@0.7`](Formula/pgx@0.7.rb). Old name (and version) of `pgrx`
- [`tpc-h`](Formula/tpc-h.rb). TPC-H benchmark with patches for MacOS and Postgres support

# Extensions:

In addition, you can try Neon locally with extentions from this tap. To install them run the following command `brew install bayandin/tap/<extension>`:
- [`h3-pg`](Formula/h3-pg.rb) — PostgreSQL bindings for H3, a hierarchical hexagonal geospatial indexing system
- [`hypopg`](Formula/hypopg.rb) — Hypothetical Indexes for PostgreSQL
- [`ip4r`](Formula/ip4r.rb) — IPv4/v6 and IPv4/v6 range index type for PostgreSQL
- [`pg_cron`](Formula/pg_cron.rb) — Run periodic jobs in PostgreSQL
- [`pg_embedding`](Formula/pg_embedding.rb) — HNSW algorithm for vector similarity search in PostgreSQL
- [`pg_hashids`](Formula/pg_hashids.rb) — Short unique id generator for PostgreSQL, using hashids
- [`pg_tiktoken`](Formula/pg_tiktoken.rb) — Tiktoken tokenizer for PostgreSQL
- [`pgjwt`](Formula/pgjwt.rb) — PostgreSQL implementation of JWT (JSON Web Tokens)
- [`pgvector`](Formula/pgvector.rb) — Open-source vector similarity search for Postgres
- [`postgresql-hll`](Formula/postgresql-hll.rb) — PostgreSQL extension adding HyperLogLog data structures as a native data type
- [`rum`](Formula/rum.rb) — Inverted index with additional information in posting lists

_Note: extensions provided by the tap could be different from what's [available in Neon Cloud offering](https://neon.tech/docs/extensions/pg-extensions)._

