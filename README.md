pg_ctl start -D "C:\Program Files\PostgreSQL\16\data"

createdb -U postgres -h localhost -p 5432 Apteka

psql -U postgres -h localhost -p 5432 -d Apteka -f Apteka_dump.sql
