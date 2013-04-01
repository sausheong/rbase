rbase
=====

rBase is a simple, minimalist, pure-Ruby noSQL database. The whole database is in memory, stored in tables made from Arrays and rows made from Structs that are defined by the user. The database can be persisted to disk through a manual persistence call (otherwise it will remain only in memory).

Features
========

* Interface through HTTP
* Records inserted and updated through JSON
* Records retrieved through JSON
* Multiple tables, schema created by user
* Implements:
  * Single record insert
  * Data types - string, integer and date/time
  * Query with 'is', 'not', 'like', 'gt' and 'lt'
  * Single record retrieval through a record id
  * Single record update

How to install
==============

There is no need to install. Just run 

    thin start
    
to start the web server interface.

How to use
==========

The best way to see how rbase can be used is through the specs in the `spec.rb` file as well as the `rbase.rb` file. Here is a quick summary:

* GET /schema - show the current schema
* POST /schema - with the parameter key `rows` and the value a JSON formatted schema e.g. {'User' => ['name', 'email', 'age'], 'Article' => ['title', 'content', 'author', 'created_at']} where User and Article are the names of the tables, while the arrays contain a list of attributes/columns of the table.
* GET /:table/:id - get a specific record by record id e.g. GET /User/1 will get the User record with id 1.
* POST /:table - insert a single record with the parameter key `rows` and the value a JSON formatted row e.g. { 'name' => 'John Doe', 'email' => 'john@gmail.com', 'age'  => 25 }. :table is the table name. 
* PUT /:table/:id - update a single record given the record id. The updated values are PUT in through the parameter key `rows`, with the value a JSON formatted row. Not all attributes need to be updated.
* DELETE /:table/:id - delete a single record given the record id
* GET /:table/:attribute/:op/:value - query the given table. :attribute is the attribute to query, :op is the operation to perform (one of the list in 'is', 'not', 'like', 'gt' and 'lt') and :value is the value queried. For e.g. to select all Users who have 'John' in their names, you can use GET /User/name/like/John. You can also specify that the value is of a specific type by providing `?type=:type` (where :type is one of 'string', 'integer' or 'time', the default being 'string'). For example, if you want to find Users 20 years of age and above, you can use GET /User/age/gt/20?type=integer
* GET /persist - persists the database to JSON files on the same path as the running server

What's good
===========

* It's  minimalist. The whole implementation is less than 150 lines of code.
* Except for Sinatra and JSON and I only use what's available in Ruby core (1.9.3) and used even the Standard Library on a need-to basis.
* Interface is through standard HTTP. You can curl everything.
* Relatively feature-rich for a small code-base. 

What's bad
==========

* The performance of rbase is terrible for queries though it's relatively decent for single record retrievals and inserts.
* You really shouldn't store more than 10,000 records per database if you want any sort of performance

Tests
=====

The specs for rbase are entirely in the `spec.rb` file.  In addition, I have a `benchmark.rb` file that performs basic benchmarking tests based on 10,000 records for the basic insert and select queries. To run them, just run `rake test`.

    $ rake test
    Run options: --seed 52196

    # Running tests:

    ......

    Finished tests in 0.047068s, 127.4751 tests/s, 616.1299 assertions/s.

    6 tests, 29 assertions, 0 failures, 0 errors, 0 skips

    # Running benchmarks:


    rbase performance test	1	10	100
    bench_find_record_by_id	 0.000619	 0.003926	 0.037895
    bench_find_record_by_query_date_compare	 0.694471	 6.989036	69.585473
    bench_find_record_by_query_integer_compare	 0.269782	 3.235487	30.860456
    bench_find_record_by_query_like	 0.058805	 0.666265	 6.911712
    bench_insert_single_record	 0.000968	 0.005287	 0.054243


    Finished benchmarks in 153.628608s, 0.0325 tests/s, 3.6452 assertions/s.

    5 tests, 560 assertions, 0 failures, 0 errors, 0 skips
    
You can see the run I did on my mid-2012 MacBook Air 4GB RAM, that with 10,000 records in the User table, a get by id returns 100 records in 3/100 of a second. Inserting a 100 records is also very quick, i.e. in 5/100 of a second. 

However, the performance sucked for a query by date (0.7 second for a single query), query by integer (0.3 second for a single query) and query with like (0.05 second per query). This becomes incrementally and linearly worse as the number of records in the table increases. 

Note that this is done almost with no regard to network traffic, so any kind of deployment over a network will necessarily make things worse.

Why is this so?

1. I wrote this for more of an aesthetic reason rather than performance. Some of the more 'elegant' code can be replaced by grittier by higher performing code
2. Ruby is not really meant for this kind of work

