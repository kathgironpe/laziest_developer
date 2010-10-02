require 'fileutils'
namespace :db do
  
  namespace :migrate do
    
    desc "Uses schema.rb to build a new base migration with the timestamp of the current migration. Other migrations are   moved to a backup folder."
    task :compact => [:abort_if_pending_migrations, :environment] do 
      
      file = File.read("#{Rails.root}/db/schema.rb")
      
      main_content_regex = /ActiveRecord::Schema.define\(:version => (.*)\) do(.*)^end/m
      main_content_regex.match file
      create_part = $2 # the second group holds what I want.
       
      lines = file.split("\n")     
     
      index_regex = /add_index "(.*)", (.*):name => "(.*)"/
      table_regex = /create_table (.*),(.*)/
      
      tables = lines.collect{|line| "  drop_table #{$1}" if line =~ table_regex }
      indexes = lines.collect{|line| "  remove_index :#{$1}, :name => :#{$3}" if line =~ index_regex}
      
      # hack to correct spacing so it "looks pretty"
      create_part.gsub!("\n", "\n  ")
      
      # reverse the order so the indexes get taken out in the opposite order
      # they were added. Also add two spaces to the start of each line
      drop_tables =  tables.compact.reverse.join("\n  ")
      drop_indexes = indexes.compact.reverse.join("\n  ")
      
      new_migration = %Q{# Migration created #{Time.now.to_s} by lazy_developer
class InitialMigration < ActiveRecord::Migration
  def self.up
    #{create_part}
  end
  
  def self.down
  #{drop_indexes}
  
  #{drop_tables}
  end
end
}
    version =  ActiveRecord::Migrator.current_version
    backups = Rails.root+"/db/migrate_#{version}"
    
    svn=File.exist?(Rails.root+"/db/migrate/.svn")
    if svn
      `svn mkdir #{backups}`
      Dir.glob(Rails.root+"/db/migrate/*").each do |migration|
        puts "moving #{migration}"
        `svn mv #{migration} #{backups}`
      end
    else
      FileUtils.mv(Rails.root+"/db/migrate", backups)
      FileUtils.mkdir(Rails.root+"/db/migrate")
    end
    
    new_file = Rails.root+"/db/migrate/#{version}_initial_migration.rb"

    File.open(new_file, "w") do |f|
      f << new_migration
    end

    `svn add #{new_file}` if svn
    
    puts "Created #{new_file}."
    puts "Previous migrations are in #{backups}"
    end
  
  end
  
end
