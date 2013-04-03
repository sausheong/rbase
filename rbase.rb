require 'date'
require 'thread'

class Table < Array
  
  def to_string(val)
    val.to_s
  end
  
  def to_integer(val)
    val.to_i
  end
  
  def to_time(val)
    DateTime.parse(val.to_s)
  end
  
  def initialize(name, index=0)
    @mutex = Mutex.new
    @name = name
    @index = index # self-incrementing serial number for id
  end
  
  def select_all(attribute, op, val, type='string')
    table = self.compact
    case type
    when 'integer' then value = to_integer(val)
    when 'time' then value = to_time(val)
    else value = val
    end

    case op
      when 'is'   then table.keep_if {|row| row[attribute] == value}
      when 'not'  then table.delete_if {|row| row[attribute] == value}
      when 'gt'   then table.keep_if {|row| self.send("to_#{type}".to_sym, row[attribute]) > value}
      when 'lt'   then table.keep_if {|row| self.send("to_#{type}".to_sym, row[attribute]) < value}
      when 'like' then table.keep_if {|row| row[attribute].include?(value)}
    end
    table
  end
  
  def insert(row)
    @mutex.synchronize {
      @index += 1
    }    
    row.id = @index
    self << row
    @index
  end
  
  def delete(index)
    @mutex.synchronize {
      self.delete_if {|row| row.id == index}
    }
  end
  
  def get(index)
    self.find {|row| row[:id] == index}
  end
  
  def to_json(*a)
    array = Array.new
    self.each { |row| array << Hash[row.each_pair.to_a] }
    array.to_json(*a)
  end
  
  def persist
    @mutex.synchronize {
      File.open("./#{name}.json", "w") {|f| f.write(self.to_json)}
      File.open("./#{name}.index", "w") {|f| f.write(@index)}
    }
  end
end

configure do
  set :database, {}
  # load persisted data on startup
  File.open("./rbase.index", "a+") do |index_file|
    index = index_file.read
    unless index.empty?
      tables = JSON.parse index   
      tables.each do |tablename|
        File.open("./#{tablename}.json", "a+") do |table_file|
          table = table_file.read
          unless table.empty?
            json = JSON.parse table
            struct = Struct.new(tablename, *(json.first.keys))
            Object.const_set(tablename, struct)    
            File.open("./#{tablename}.index", 'a+') do |file|
              index = file.read
              settings.database[tablename] = Table.new(tablename, index)
            end
            json.each do |record|
              row = struct.new
              record.each { |attribute, value| row.send("#{attribute}=".to_sym, value) }
              settings.database[tablename].insert row          
            end
          end
        end
      end
    end
  end  
end

# convenience method to prepare the table
def prepare_table
  @table = settings.database[params[:table]]
  raise 'No such table' unless @table
end

# show the schema
get "/schema" do
  list = {}
  settings.database.each do |schema, table|
    clazz = Object.const_get schema
    list[schema] = clazz.members
  end
  list.to_json
end

# set up schema
# clears existing schema and database if give ?clear=true
post "/schema" do    
  settings.database.clear if params[:clear]
  schema = JSON.parse params[:schema]
  raise 'Schema not provided or wrong schema' unless schema
  schema.each do |tablename, attributes|  
    unless settings.database.keys.include?(tablename)
      struct = Struct.new(tablename, 'id', *attributes)
      Object.const_set(tablename, struct)    
      settings.database[tablename] = Table.new(tablename)
    end
  end
  File.open("./rbase.index", "w") {|f| f.write(settings.database.keys)}
  [200, 'Schema Created']
end

# insert
post "/:table" do 
  prepare_table
  row = Object.const_get(params[:table]).new
  row_data = JSON.parse params[:row]  
  raise 'No insert data provided' unless row_data
  row_data.each do |attribute, value|
    row.send("#{attribute}=".to_sym, value)
  end  
  index = @table.insert(row)
  [200, index.to_s]
end

# update
put "/:table/:id" do
  prepare_table
  row = @table.get(params[:id].to_i)
  row_data = JSON.parse params[:row]  
  raise 'No insert data provided' unless row_data
  
  row_data.each do |attribute, value|
    row.send("#{attribute}=".to_sym, value)
  end
  [200, row.id.to_s]    
end

# get a single row
get "/:table/:id" do
  prepare_table
  row = @table.get(params[:id].to_i)
  raise "Row not found" unless row
  Hash[row.each_pair.to_a].to_json
end

# select
get "/:table/:attribute/:op/:value" do
  prepare_table
  type = params[:type] || 'string'
  selection = @table.select_all(params[:attribute], params[:op], params[:value], type)
  selection.each_with_index.map do |struct, index|
    Hash[struct.each_pair.to_a]
  end.to_json
end

# delete 
delete "/:table/:id" do
  prepare_table
  @table.delete params[:id].to_i
  [200]
end

# persist to file
get "/persist" do
  settings.database.each do |name, db|
    db.persist
  end
  [200]
end