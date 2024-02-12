## Getting Started

```bash
$ docker-compose up -d
$ direnv allow  # or otherwise set envs defined in .envrc
$ cd 01
$ psql -f main.sql
$ ...
```

## PgAdmin

```bash
$ docker-compose --profile tools up -d
$ chown 5050:5050 .pgadmin-data
$ open http://localhost:9201
```

## Vim

I like to use Tim Pope's [DadBod plugin](https://github.com/tpope/vim-dadbod), which allows me to highlight sections of SQL code and run `:'<,'>DB` to execute, viewing results in a temporary pane.
