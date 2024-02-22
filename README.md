# Query the starknet airdrop amount by contributors to an organizations

## Screenshot

![Screenshot](./assets/screenshot-2024-02-22-16-16-49.png)

## Download contributors data

Save contributors data of apache to the apache folder, run the following command

```
./get_contributors_for_org.sh apache -t TOKEN
```

where TOKEN must be a valid github access token (this is required in order to prevent being rate-limited).
This command will save all contributors information to the file `apache/contributors.json`.
Note that this will take a while, it may never even finish as there are just too many repos and contributors
to [https://github.com/apache](https://github.com/apache). You may rerun the script a few times.
If any thing goes wrong, then just run the following command to save partial results.

```
jq -c '.[]' apache/*/contributors.*.json apache/contributors.json
```
 
## Query airdrop amount with duckdb

### Show all airdrop amounts along with github id `apache/contributors.json`

```
select * from (select min(a.amount) as amount, a.identity as id from "airdrop.json" a join "apache/contributors.json" c on lower(a.identity) = lower(c.login) group by a.identity) order by amount desc, id limit 10;
```

### Show summed airdrop amounts for contributors in `apache/contributors.json`

```
select sum(amount) from (select min(a.amount) as amount, a.identity as id from "airdrop.json" a join "apache/contributors.json" c on lower(a.identity) = lower(c.login) group by a.identity);
```