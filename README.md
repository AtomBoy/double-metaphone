# double-metaphone
Python and MySQL implementations of the double metaphone algorithm which is useful for matching different spellings of names.

See [Wikipedia](https://en.wikipedia.org/wiki/Metaphone) for a good explanation of the algorithm.

There is a more recent version of Metaphone called Metaphone 3. It is a commercial product available at http://www.amorphics.com/ (which I am not affiliated with).

## MySQL Usage
To create the command from your command line:

`mysql yourDataBaseName -u root -p < metaphone.sql`

Then, from a mysql command line you can test it with:

```sql
mysql> USE yourDataBaseName;
Database changed
mysql> SELECT dm('collins');
+---------------+
| dm('collins') |
+---------------+
| KLNS          |
+---------------+
1 row in set (0.01 sec)
```

Normally you'll want to pre-compute the metaphone values for names in your database and put them into an indexed column:

```sql
INSERT INTO people (lastName, lastNameDM) VALUES (${lastName}, dm(${lastName}))
```

Then query for matches against the `latNameDM` column computing only the name to find:

```sql
SELECT * FROM people WHERE lastNameDM = db(${inputLastName})
```
