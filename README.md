# Bayandin's Homebrew Tap

A Homebrew tap with miscellaneous formulae, most notable is `neon-local` that allows to run [Neon](http://neon.tech/) locally.

# Quick Start

```bash
brew install bayandin/tap/neon-local
```
The command installs `neon-local` and creates configuration in `"$(brew --prefix)/var/neon"` directory.

Based on examples from [neondatabase/neon](https://github.com/neondatabase/neon#running-neon-database) repository (instead of `cargo neon` from the documentation, we use `neon-local`).
```bash
neon-local start
neon-local tenant create --set-default # use `--pg-version \d+` for a particular Postgres version
neon-local tenant list
neon_local endpoint create main  # use `--pg-version \d+` for a particular Postgres version, should match Postgres version for the tenant
neon-local endpoint start main
neon-local endpoint list
neon-local timeline branch --branch-name test
neon-local timeline list
neon_local endpoint create test --branch-name test
neon-local endpoint start test
```

```bash
psql -p 55432 -h 127.0.0.1 -U cloud_admin postgres
```

# Formulae in the tap

- [`neon-local`](Formula/neon-local.rb). Meta-formula that installs all the required dependencies and configures Neon to run locally.
  - [`neon-storage`](Formula/neon-storage.rb). Storage part of Neon. It contains Pageserver, Safekeeper, and other required binaries
  - [`neon-postgres`](Formula/neon-postgres.rb). Compute part of Neon. The formula contains all supported by Neon Postgres versions
  - [`neon-extension`](Formula/neon-extension.rb). Postgres extensions that provide communication between Compute and Storage
- [`neon-proxy`](Formula/neon-proxy.rb). Proxy for Neon
- [`curl-without-ipv6`](Formula/curl-without-ipv6.rb). Curl formula without IPv6 support
- [`tpc-h`](Formula/tpc-h.rb). TPC-H benchmark with patches for MacOS and Postgres support

# Extensions:

In addition, you can try Neon locally with extensions from this tap. To install them run the following command `brew install bayandin/tap/<extension>`:
- [`h3-pg`](Formula/h3-pg.rb) — PostgreSQL bindings for H3, a hierarchical hexagonal geospatial indexing system
- [`hypopg`](Formula/hypopg.rb) — Hypothetical Indexes for PostgreSQL
- [`ip4r`](Formula/ip4r.rb) — IPv4/v6 and IPv4/v6 range index type for PostgreSQL
- [`pg_cron`](Formula/pg_cron.rb) — Run periodic jobs in PostgreSQL
- [`pg_embedding`](Formula/pg_embedding.rb) — HNSW algorithm for vector similarity search in PostgreSQL
- [`pg_graphql`](Formula/pg_graphql.rb) — GraphQL support for PostgreSQL
- [`pg_hashids`](Formula/pg_hashids.rb) — Short unique id generator for PostgreSQL, using hashids
- [`pg_jsonschema`](Formula/pg_jsonschema.rb) — PostgreSQL extension providing JSON Schema validation
- [`pg_tiktoken`](Formula/pg_tiktoken.rb) — Tiktoken tokenizer for PostgreSQL
- [`pgjwt`](Formula/pgjwt.rb) — PostgreSQL implementation of JWT (JSON Web Tokens)
- [`pgtap`](Formula/pgtap.rb) — PostgreSQL Unit Testing Suite
- [`pgvector`](Formula/pgvector.rb) — Open-source vector similarity search for Postgres
- [`plpgsql_check`](Formula/plpgsql_check.rb) — Plpgsql linter
- [`plv8`](Formula/plv8.rb) — V8 Engine Javascript Procedural Language add-on for PostgreSQL
- [`postgresql-hll`](Formula/postgresql-hll.rb) — PostgreSQL extension adding HyperLogLog data structures as a native data type
- [`postgresql-unit`](Formula/postgresql-unit.rb) — SI Units for PostgreSQL
- [`prefix`](Formula/prefix.rb) — Prefix Range module for PostgreSQL
- [`rum`](Formula/rum.rb) — Inverted index with additional information in posting lists
- [`teleport@16`](Formula/teleport@16.rb) — Modern SSH server for teams managing distributed infrastructure. Version 16
- [`timescaledb`](Formula/timescaledb.rb) — Open-source time-series SQL database optimized for fast ingest and complex queries

_Note: extensions provided by the tap could be different from what's [available in Neon Cloud offering](https://neon.tech/docs/extensions/pg-extensions)._

