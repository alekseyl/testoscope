# Testoscope

Inspect in practice how well is your data organized while testing your application! 

## Features
**Finds out of the box:** sequential scans, dummy One-Timer calls to DB, unused indexes.

**Highly customizable:** you can define your own unintended markers, inspect only part of you tables set and so.

May work in a **error mode** raising exception on unintended behaviour, 
that way you can protect from perfomance break-out in production. 

Best suits with high-level testing: **controller tests, integration tests, api tests** and so. 

Output example: 
![alt text](https://github.com/alekseyl/testoscope/raw/master/results.png "results")

## Out of the box inspections
Sequential scans, dummy One-Timer calls to DB, unused indexes

### Sequential scans 
It can happend when you are:
* truly missing an index
* when you are intend to use a partial index but unintentionally miss index condition in a query 

### One-Timers 
Some times ORM can produce dummy query, in Postgres Query Plan they look like this:
 
                  QUERY PLAN
    --------------------------------------------
    Result  (cost=0.00..0.00 rows=0 width=194)
     One-Time Filter: false
    (2 rows)

in SQL query you are looking for some WHERE false:

    SELECT "tags".* 
      FROM "tags" 
      WHERE "tags"."parent_id" = $1 AND 1=0
      
and in ORM it doesn't look alarming:

    sub_tags.where( name: names )
  
So when names is empty, we get a dummy request.

They are not a big deal from a performance perspective, 
but you are occupying DB connection pool and cluttering your channel with empty noise.

So it's better to change the underlying logic other than be OK with it. 

### Unused index

Testoscope can find and warn you about unused index. Possible reasons 
for them are:
* you forgot to remove index after code refactoring, and now you have redundant unused index
* you already have another index more suitable which is preferred by the planner 
* your tests doesn't cover all use-cases 

In either cases you may have a problem, but also may not.

### How it works? 
Testoscope hooks to exec_query of a selected default_adapter, 
for all queries runs them two times one - wrapped in EXPLAIN and analyze it, 
and the second time is for original a caller purpose.

After achieving explain result in a string, it search for an unintended behaviour markers, 
like a Seq Scan substring in Postgres QUERY PLAN explained and collects indexes used by all queries for final summary.

### Unintended Behaviours
By default unintended behaviours are preconfigured for PosgtreSQL EXPLAIN format and all tables:
        
     config.unintened_key_words = ['Seq Scan', 'One-Time Filter']
     config.tables = :all

But you can set any regexp you want to track inside EXPLAIN results, 
and also you can track not all tables, but only specified ones:
    
    config.tables = ['cards', 'users']
  

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'testoscope'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install testoscope

## Usage

In test_helper.rb:

    require 'testoscope'
    
    #since doubling all requests to DB is not free, 
    #you may use ENV variable to run on demand 
    if ENV[:RUN_TESTOSCOPE]
        Testoscope.configure { |c| 
             c.back_trace_paths = [Rails.root.to_s]
             c.back_trace_exclude_paths = ["#{Rails.root.to_s}/test", "#{Rails.root.to_s}/spec"]
             c.unintened_key_words = ['Seq Scan', 'One-Time Filter']
             c.raise_when_unintended = false
             c.analyze = true
             c.tables = :all
        }
        
        MiniTest::Unit.after_tests {
           Testoscope.print_results
        }
    end 



## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/alekseyl/testoscope.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
