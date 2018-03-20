require "testoscope/version"

module Testoscope
  class Config
    attr_accessor :analyze, :back_trace_paths, :back_trace_exclude_paths,
                  :unintened_key_words, :analyze, :tables, :raise_when_unintended, :pp_class

    def initialize
      self.back_trace_paths = [Rails.root.to_s]
      self.back_trace_exclude_paths = ["#{Rails.root.to_s}/test", "#{Rails.root.to_s}/spec"]
      self.unintened_key_words = ['Seq Scan', 'One-Time Filter']
      self.raise_when_unintended = false
      self.analyze = true
      self.pp_class = "::ActiveRecord::ConnectionAdapters::#{::ActiveRecord::Base.connection.adapter_name}::ExplainPrettyPrinter".constantize
      self.tables = :all
    end
  end
  def self.config; @@config ||= Config.new end

  def self.configure
    yield(config) if block_given?

    ::ActiveRecord::Base.connection.class.include(AdapterUpgrade)

    # since test table is small planner may want to just deal with Seq scans and skip all the index fuss
    ::ActiveRecord::Base.connection.execute( 'SET enable_seqscan=off;' ) if ::ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'


    config.tables.map!{|table| /.*[ "]#{table}[ "].*/ } if config.tables != :all
  end

  def self.results
    @results ||= {
      unintended_behaviour: {},
      indexes: {},
    }
  end

  def self.add_unintended_behaviour( sql, explain, backtrace )
    results[:unintended_behaviour][sql] ||= {}
    results[:unintended_behaviour][sql][:explain] = explain
    results[:unintended_behaviour][sql][:backtrace] ||= []
    results[:unintended_behaviour][sql][:backtrace] << backtrace.to_a unless results[:unintended_behaviour][sql][:backtrace].include?(backtrace)
  end


  def self.add_index_used( sql, explain, index_used )
    results[:indexes][index_used] ||= []
    results[:indexes][index_used] << { explain: explain, sql: sql }
  end


# Alternative way to get index names "without" ActiveRecord
#"SELECT i.relname as indname FROM pg_index as idx JOIN pg_class as i ON i.oid = idx.indexrelid
# WHERE idx.indrelid::regclass = ANY( ARRAY['#{(ActiveRecord::Base.connection.tables).join("','")}']::regclass[] )")
#     .to_a.map(&:values).flatten
  def self.get_all_indexes
    ActiveRecord::Base.connection.tables.map { |table|
      [table, ActiveRecord::Base.connection.indexes(table).map(&:name)]
    }.to_h
  end

  def self.print_results
    return yield(results) if block_given?

    puts "\n<UNINTENDED BEHAVIOUR>\n" unless results[:unintended_behaviour].blank?

    results[:unintended_behaviour].each do |sql, values|
      puts "\nSQL:\n\n"
      puts Niceql::Prettifier.prettify_sql( sql )
      puts "\n\nAPP BACKTRACE:\n\n"
      puts values[:backtrace].map{|arr| arr.join("\n")}.uniq.join("\n            _____________________\n\n")
      puts ''
      puts values[:explain]
      puts "\n++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"
    end

    filtered_unused_indexes = []

    get_all_indexes.each do |table, indexes|
      unused_indexes = indexes - results[:indexes].keys
      next if unused_indexes.blank? || !sql_has_analyzing_tables?(" #{table} ")
      filtered_unused_indexes << "\n-----#{table}------\n"
      filtered_unused_indexes << unused_indexes
    end
    if !filtered_unused_indexes.blank?
      puts "\n<UNUSED INDEXES>\n"
      puts filtered_unused_indexes.join("\n")
    end
  end

  def self.sql_has_analyzing_tables?(sql)
    config.tables == :all || config.tables.any?{ |table| sql[table] }
  end

  def self.analyze( sql )
    if config.analyze && sql_has_analyzing_tables?(sql)

      explain = yield

      explain = config.pp_class.method(:pp).arity.abs == 1 ? config.pp_class.new.pp( explain ) : config.pp_class.new.pp( explain, 0 )

      app_trace = caller_locations( 2 ).map(&:to_s).select { |st|
        self.config.back_trace_paths.any?{|pth| st[pth]} && !self.config.back_trace_exclude_paths.any?{|epth| st[epth]}
      }
      # this is the case when we for example making query from test files,
      # we may omit some params for where clause and so.
      return if app_trace.length == 0

      unintended_found = self.config.unintened_key_words.select{|ukw| explain[ukw] }

      if unintended_found.length > 0
        raise StandardError.new("#{unintended_found.join(', ')} found!\n #{explain}") if config.raise_when_unintended
        self.add_unintended_behaviour( sql, explain, app_trace )
      end

      explain.scan(/Index Scan using \w+/).each{|found| add_index_used(sql, explain, found[17..-1]) }
    end
  end

  def self.suspend_global_analyze( analyze )
    was, config.analyze = config.analyze, analyze
    yield
    config.analyze = was
  end

  module AdapterUpgrade
    def exec_query(sql, name = "SQL", binds = [], prepare: false)
      Testoscope.analyze(sql) {
        super( 'EXPLAIN ' + sql, "EXPLAIN", binds, prepare: false)
      }
      super( sql, name, binds, prepare: prepare )
    end
  end

end
