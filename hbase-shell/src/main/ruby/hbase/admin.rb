#
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include Java
java_import java.util.Arrays
java_import java.util.regex.Pattern
java_import org.apache.hadoop.hbase.util.Pair
java_import org.apache.hadoop.hbase.util.RegionSplitter
java_import org.apache.hadoop.hbase.util.Bytes
java_import org.apache.hadoop.hbase.ServerName
java_import org.apache.hadoop.hbase.TableName

# Wrapper for org.apache.hadoop.hbase.client.HBaseAdmin

module Hbase
  class Admin
    include HBaseConstants

    def initialize(connection)
      @connection = connection
      # Java Admin instance
      @admin = @connection.getAdmin
      @conf = @connection.getConfiguration
    end

    def close
      @admin.close
    end

    #----------------------------------------------------------------------------------------------
    # Returns a list of tables in hbase
    def list(regex = '.*')
      @admin.listTableNames(Pattern.compile(regex)).map(&:getNameAsString)
    end

    #----------------------------------------------------------------------------------------------
    # Requests a table or region flush
    def flush(table_or_region_name)
      @admin.flushRegion(table_or_region_name.to_java_bytes)
    rescue java.lang.IllegalArgumentException => e
      # Unknown region. Try table.
      @admin.flush(TableName.valueOf(table_or_region_name))
    end

    #----------------------------------------------------------------------------------------------
    # Requests a table or region or column family compaction
    def compact(table_or_region_name, family = nil, type = 'NORMAL')
      family_bytes = nil
      family_bytes = family.to_java_bytes unless family.nil?
      compact_type = nil
      if type == 'NORMAL'
        compact_type = org.apache.hadoop.hbase.client.CompactType::NORMAL
      elsif type == 'MOB'
        compact_type = org.apache.hadoop.hbase.client.CompactType::MOB
      else
        raise ArgumentError, 'only NORMAL or MOB accepted for type!'
      end

      begin
        @admin.compactRegion(table_or_region_name.to_java_bytes, family_bytes)
      rescue java.lang.IllegalArgumentException => e
        @admin.compact(TableName.valueOf(table_or_region_name), family_bytes, compact_type)
      end
    end

    #----------------------------------------------------------------------------------------------
    # Gets compaction state for specified table
    def getCompactionState(table_name)
      @admin.getCompactionState(TableName.valueOf(table_name)).name
    end

    # Requests to compact all regions on the regionserver
    def compact_regionserver(servername, major = false)
      @admin.compactRegionServer(ServerName.valueOf(servername), major)
    end

    #----------------------------------------------------------------------------------------------
    # Requests a table or region or column family major compaction
    def major_compact(table_or_region_name, family = nil, type = 'NORMAL')
      family_bytes = nil
      family_bytes = family.to_java_bytes unless family.nil?
      compact_type = nil
      if type == 'NORMAL'
        compact_type = org.apache.hadoop.hbase.client.CompactType::NORMAL
      elsif type == 'MOB'
        compact_type = org.apache.hadoop.hbase.client.CompactType::MOB
      else
        raise ArgumentError, 'only NORMAL or MOB accepted for type!'
      end

      begin
        @admin.majorCompactRegion(table_or_region_name.to_java_bytes, family_bytes)
      rescue java.lang.IllegalArgumentException => e
        @admin.majorCompact(TableName.valueOf(table_or_region_name), family_bytes, compact_type)
      end
    end

    #----------------------------------------------------------------------------------------------
    # Requests a regionserver's WAL roll
    def wal_roll(server_name)
      @admin.rollWALWriter(ServerName.valueOf(server_name))
    end
    # TODO: remove older hlog_roll version
    alias hlog_roll wal_roll

    #----------------------------------------------------------------------------------------------
    # Requests a table or region split
    def split(table_or_region_name, split_point = nil)
      split_point_bytes = nil
      split_point_bytes = split_point.to_java_bytes unless split_point.nil?
      begin
        @admin.splitRegion(table_or_region_name.to_java_bytes, split_point_bytes)
      rescue java.lang.IllegalArgumentException => e
        @admin.split(TableName.valueOf(table_or_region_name), split_point_bytes)
      end
    end

    #----------------------------------------------------------------------------------------------
    # Enable/disable one split or merge switch
    # Returns previous switch setting.
    def splitormerge_switch(type, enabled)
      switch_type = nil
      if type == 'SPLIT'
        switch_type = org.apache.hadoop.hbase.client.Admin::MasterSwitchType::SPLIT
      elsif type == 'MERGE'
        switch_type = org.apache.hadoop.hbase.client.Admin::MasterSwitchType::MERGE
      else
        raise ArgumentError, 'only SPLIT or MERGE accepted for type!'
      end
      @admin.setSplitOrMergeEnabled(
        java.lang.Boolean.valueOf(enabled), java.lang.Boolean.valueOf(false),
        switch_type
      )[0]
    end

    #----------------------------------------------------------------------------------------------
    # Query the current state of the split or merge switch.
    # Returns the switch's state (true is enabled).
    def splitormerge_enabled(type)
      switch_type = nil
      if type == 'SPLIT'
        switch_type = org.apache.hadoop.hbase.client.Admin::MasterSwitchType::SPLIT
      elsif type == 'MERGE'
        switch_type = org.apache.hadoop.hbase.client.Admin::MasterSwitchType::MERGE
      else
        raise ArgumentError, 'only SPLIT or MERGE accepted for type!'
      end
      @admin.isSplitOrMergeEnabled(switch_type)
    end

    def locate_region(table_name, row_key)
      locator = @connection.getRegionLocator(TableName.valueOf(table_name))
      begin
        return locator.getRegionLocation(Bytes.toBytesBinary(row_key))
      ensure
        locator.close
      end
    end

    #----------------------------------------------------------------------------------------------
    # Requests a cluster balance
    # Returns true if balancer ran
    def balancer(force)
      @admin.balancer(java.lang.Boolean.valueOf(force))
    end

    #----------------------------------------------------------------------------------------------
    # Enable/disable balancer
    # Returns previous balancer switch setting.
    def balance_switch(enableDisable)
      @admin.setBalancerRunning(
        java.lang.Boolean.valueOf(enableDisable), java.lang.Boolean.valueOf(false)
      )
    end

    #----------------------------------------------------------------------------------------------
    # Query the current state of the LoadBalancer.
    # Returns the balancer's state (true is enabled).
    def balancer_enabled?
      @admin.isBalancerEnabled
    end

    #----------------------------------------------------------------------------------------------
    # Requests clear block cache for table
    def clear_block_cache(table_name)
      @admin.clearBlockCache(org.apache.hadoop.hbase.TableName.valueOf(table_name)).toString
    end

    #----------------------------------------------------------------------------------------------
    # Requests region normalization for all configured tables in the cluster
    # Returns true if normalizer ran successfully
    def normalize
      @admin.normalize
    end

    #----------------------------------------------------------------------------------------------
    # Enable/disable region normalizer
    # Returns previous normalizer switch setting.
    def normalizer_switch(enableDisable)
      @admin.setNormalizerRunning(java.lang.Boolean.valueOf(enableDisable))
    end

    #----------------------------------------------------------------------------------------------
    # Query the current state of region normalizer.
    # Returns the state of region normalizer (true is enabled).
    def normalizer_enabled?
      @admin.isNormalizerEnabled
    end

    #----------------------------------------------------------------------------------------------
    # Request a scan of the catalog table (for garbage collection)
    # Returns an int signifying the number of entries cleaned
    def catalogjanitor_run
      @admin.runCatalogScan
    end

    #----------------------------------------------------------------------------------------------
    # Enable/disable the catalog janitor
    # Returns previous catalog janitor switch setting.
    def catalogjanitor_switch(enableDisable)
      @admin.enableCatalogJanitor(java.lang.Boolean.valueOf(enableDisable))
    end

    #----------------------------------------------------------------------------------------------
    # Query on the catalog janitor state (enabled/disabled?)
    # Returns catalog janitor state (true signifies enabled).
    def catalogjanitor_enabled
      @admin.isCatalogJanitorEnabled
    end

    #----------------------------------------------------------------------------------------------
    # Request cleaner chore to run (for garbage collection of HFiles and WAL files)
    def cleaner_chore_run
      @admin.runCleanerChore
    end

    #----------------------------------------------------------------------------------------------
    # Enable/disable the cleaner chore
    # Returns previous cleaner switch setting.
    def cleaner_chore_switch(enableDisable)
      @admin.setCleanerChoreRunning(java.lang.Boolean.valueOf(enableDisable))
    end

    #----------------------------------------------------------------------------------------------
    # Query on the cleaner chore state (enabled/disabled?)
    # Returns cleaner state (true signifies enabled).
    def cleaner_chore_enabled
      @admin.isCleanerChoreEnabled
    end

    #----------------------------------------------------------------------------------------------
    # Enables a table
    def enable(table_name)
      tableExists(table_name)
      return if enabled?(table_name)
      @admin.enableTable(TableName.valueOf(table_name))
    end

    #----------------------------------------------------------------------------------------------
    # Enables all tables matching the given regex
    def enable_all(regex)
      regex = regex.to_s
      @admin.enableTables(Pattern.compile(regex))
    end

    #----------------------------------------------------------------------------------------------
    # Disables a table
    def disable(table_name)
      tableExists(table_name)
      return if disabled?(table_name)
      @admin.disableTable(TableName.valueOf(table_name))
    end

    #----------------------------------------------------------------------------------------------
    # Disables all tables matching the given regex
    def disable_all(regex)
      pattern = Pattern.compile(regex.to_s)
      @admin.disableTables(pattern).map { |t| t.getTableName.getNameAsString }
    end

    #---------------------------------------------------------------------------------------------
    # Throw exception if table doesn't exist
    def tableExists(table_name)
      raise ArgumentError, "Table #{table_name} does not exist." unless exists?(table_name)
    end

    #----------------------------------------------------------------------------------------------
    # Is table disabled?
    def disabled?(table_name)
      @admin.isTableDisabled(TableName.valueOf(table_name))
    end

    #----------------------------------------------------------------------------------------------
    # Drops a table
    def drop(table_name)
      tableExists(table_name)
      raise ArgumentError, "Table #{table_name} is enabled. Disable it first." if enabled?(
        table_name
      )

      @admin.deleteTable(org.apache.hadoop.hbase.TableName.valueOf(table_name))
    end

    #----------------------------------------------------------------------------------------------
    # Drops a table
    def drop_all(regex)
      pattern = Pattern.compile(regex.to_s)
      failed = @admin.deleteTables(pattern).map { |t| t.getTableName.getNameAsString }
      failed
    end

    #----------------------------------------------------------------------------------------------
    # Returns ZooKeeper status dump
    def zk_dump
      @zk_wrapper = org.apache.hadoop.hbase.zookeeper.ZKWatcher.new(
        @admin.getConfiguration,
        'admin',
        nil
      )
      zk = @zk_wrapper.getRecoverableZooKeeper.getZooKeeper
      @zk_main = org.apache.zookeeper.ZooKeeperMain.new(zk)
      org.apache.hadoop.hbase.zookeeper.ZKUtil.dump(@zk_wrapper)
    end

    #----------------------------------------------------------------------------------------------
    # Creates a table
    def create(table_name, *args)
      # Fail if table name is not a string
      raise(ArgumentError, 'Table name must be of type String') unless table_name.is_a?(String)

      # Flatten params array
      args = args.flatten.compact
      has_columns = false

      # Start defining the table
      htd = org.apache.hadoop.hbase.HTableDescriptor.new(org.apache.hadoop.hbase.TableName.valueOf(table_name))
      splits = nil
      # Args are either columns or splits, add them to the table definition
      # TODO: add table options support
      args.each do |arg|
        unless arg.is_a?(String) || arg.is_a?(Hash)
          raise(ArgumentError, "#{arg.class} of #{arg.inspect} is not of Hash or String type")
        end

        # First, handle all the cases where arg is a column family.
        if arg.is_a?(String) || arg.key?(NAME)
          # If the arg is a string, default action is to add a column to the table.
          # If arg has a name, it must also be a column descriptor.
          descriptor = hcd(arg, htd)
          # Warn if duplicate columns are added
          if htd.hasFamily(descriptor.getName)
            puts "Family '" + descriptor.getNameAsString + "' already exists, the old one will be replaced"
            htd.modifyFamily(descriptor)
          else
            htd.addFamily(descriptor)
          end
          has_columns = true
          next
        end
        if arg.key?(REGION_REPLICATION)
          region_replication = JInteger.valueOf(arg.delete(REGION_REPLICATION))
          htd.setRegionReplication(region_replication)
        end

        # Get rid of the "METHOD", which is deprecated for create.
        # We'll do whatever it used to do below if it's table_att.
        if (method = arg.delete(METHOD))
          raise(ArgumentError, 'table_att is currently the only supported method') unless method == 'table_att'
        end

        # The hash is not a column family. Figure out what's in it.
        # First, handle splits.
        if arg.key?(SPLITS_FILE)
          splits_file = arg.delete(SPLITS_FILE)
          unless File.exist?(splits_file)
            raise(ArgumentError, "Splits file #{splits_file} doesn't exist")
          end
          arg[SPLITS] = []
          File.foreach(splits_file) do |line|
            arg[SPLITS].push(line.chomp)
          end
          htd.setValue(SPLITS_FILE, arg[SPLITS_FILE])
        end

        if arg.key?(SPLITS)
          splits = Java::byte[][arg[SPLITS].size].new
          idx = 0
          arg.delete(SPLITS).each do |split|
            splits[idx] = org.apache.hadoop.hbase.util.Bytes.toBytesBinary(split)
            idx += 1
          end
        elsif arg.key?(NUMREGIONS) || arg.key?(SPLITALGO)
          # deprecated region pre-split API; if one of the above is specified, will be ignored.
          raise(ArgumentError, 'Number of regions must be specified') unless arg.key?(NUMREGIONS)
          raise(ArgumentError, 'Split algorithm must be specified') unless arg.key?(SPLITALGO)
          raise(ArgumentError, 'Number of regions must be greater than 1') unless arg[NUMREGIONS] > 1
          num_regions = arg.delete(NUMREGIONS)
          split_algo = RegionSplitter.newSplitAlgoInstance(@conf, arg.delete(SPLITALGO))
          splits = split_algo.split(JInteger.valueOf(num_regions))
        end

        # Done with splits; apply formerly-table_att parameters.
        update_htd_from_arg(htd, arg)

        arg.each_key do |ignored_key|
          puts(format('An argument ignored (unknown or overridden): %s', ignored_key))
        end
      end

      # Fail if no column families defined
      raise(ArgumentError, 'Table must have at least one column family') unless has_columns

      if splits.nil?
        # Perform the create table call
        @admin.createTable(htd)
      else
        # Perform the create table call
        @admin.createTable(htd, splits)
      end
    end

    #----------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------
    # Assign a region
    def assign(region_name)
      @admin.assign(region_name.to_java_bytes)
    end

    #----------------------------------------------------------------------------------------------
    # Unassign a region
    def unassign(region_name, force)
      @admin.unassign(region_name.to_java_bytes, java.lang.Boolean.valueOf(force))
    end

    #----------------------------------------------------------------------------------------------
    # Move a region
    def move(encoded_region_name, server = nil)
      @admin.move(encoded_region_name.to_java_bytes, server ? server.to_java_bytes : nil)
    end

    #----------------------------------------------------------------------------------------------
    # Merge two regions
    def merge_region(encoded_region_a_name, encoded_region_b_name, force)
      @admin.mergeRegions(encoded_region_a_name.to_java_bytes, encoded_region_b_name.to_java_bytes, java.lang.Boolean.valueOf(force))
    end

    #----------------------------------------------------------------------------------------------
    # Returns table's structure description
    def describe(table_name)
      tableExists(table_name)
      @admin.getTableDescriptor(TableName.valueOf(table_name)).to_s
    end

    def get_column_families(table_name)
      tableExists(table_name)
      @admin.getTableDescriptor(TableName.valueOf(table_name)).getColumnFamilies
    end

    def get_table_attributes(table_name)
      tableExists(table_name)
      @admin.getTableDescriptor(TableName.valueOf(table_name)).toStringTableAttributes
    end

    #----------------------------------------------------------------------------------------------
    # Truncates table (deletes all records by recreating the table)
    def truncate(table_name_str)
      puts "Truncating '#{table_name_str}' table (it may take a while):"
      table_name = TableName.valueOf(table_name_str)
      table_description = @admin.getTableDescriptor(table_name)
      raise ArgumentError, "Table #{table_name_str} is not enabled. Enable it first." unless
          enabled?(table_name_str)
      puts 'Disabling table...'
      @admin.disableTable(table_name)

      begin
        puts 'Truncating table...'
        @admin.truncateTable(table_name, false)
      rescue => e
        # Handle the compatibility case, where the truncate method doesn't exists on the Master
        raise e unless e.respond_to?(:cause) && !e.cause.nil?
        rootCause = e.cause
        if rootCause.is_a?(org.apache.hadoop.hbase.DoNotRetryIOException)
          # Handle the compatibility case, where the truncate method doesn't exists on the Master
          puts 'Dropping table...'
          @admin.deleteTable(table_name)

          puts 'Creating table...'
          @admin.createTable(table_description)
        else
          raise e
        end
      end
    end

    #----------------------------------------------------------------------------------------------
    # Truncates table while maintaing region boundaries (deletes all records by recreating the table)
    def truncate_preserve(table_name_str, conf = @conf)
      puts "Truncating '#{table_name_str}' table (it may take a while):"
      table_name = TableName.valueOf(table_name_str)
      locator = @connection.getRegionLocator(table_name)
      begin
        splits = locator.getAllRegionLocations
                        .map { |i| Bytes.toStringBinary(i.getRegionInfo.getStartKey) }
                        .delete_if { |k| k == '' }.to_java :String
        splits = org.apache.hadoop.hbase.util.Bytes.toBinaryByteArrays(splits)
      ensure
        locator.close
      end

      table_description = @admin.getTableDescriptor(table_name)
      puts 'Disabling table...'
      disable(table_name_str)

      begin
        puts 'Truncating table...'
        # just for test
        unless conf.getBoolean('hbase.client.truncatetable.support', true)
          raise UnsupportedMethodException, 'truncateTable'
        end
        @admin.truncateTable(table_name, true)
      rescue => e
        # Handle the compatibility case, where the truncate method doesn't exists on the Master
        raise e unless e.respond_to?(:cause) && !e.cause.nil?
        rootCause = e.cause
        if rootCause.is_a?(org.apache.hadoop.hbase.DoNotRetryIOException)
          # Handle the compatibility case, where the truncate method doesn't exists on the Master
          puts 'Dropping table...'
          @admin.deleteTable(table_name)

          puts 'Creating table with region boundaries...'
          @admin.createTable(table_description, splits)
        else
          raise e
        end
      end
    end

    class UnsupportedMethodException < StandardError
      def initialize(name)
        @method_name = name
      end

      def cause
        org.apache.hadoop.hbase.DoNotRetryIOException.new("#{@method_name} is not support")
      end
    end

    #----------------------------------------------------------------------------------------------
    # Check the status of alter command (number of regions reopened)
    def alter_status(table_name)
      # Table name should be a string
      raise(ArgumentError, 'Table name must be of type String') unless table_name.is_a?(String)

      # Table should exist
      raise(ArgumentError, "Can't find a table: #{table_name}") unless exists?(table_name)

      status = Pair.new
      begin
        status = @admin.getAlterStatus(org.apache.hadoop.hbase.TableName.valueOf(table_name))
        if status.getSecond != 0
          puts "#{status.getSecond - status.getFirst}/#{status.getSecond} regions updated."
        else
          puts 'All regions updated.'
        end
        sleep 1
      end while !status.nil? && status.getFirst != 0
      puts 'Done.'
    end

    #----------------------------------------------------------------------------------------------
    # Change table structure or table options
    def alter(table_name_str, wait = true, *args)
      # Table name should be a string
      raise(ArgumentError, 'Table name must be of type String') unless
          table_name_str.is_a?(String)

      # Table should exist
      raise(ArgumentError, "Can't find a table: #{table_name_str}") unless exists?(table_name_str)

      # There should be at least one argument
      raise(ArgumentError, 'There should be at least one argument but the table name') if args.empty?

      table_name = TableName.valueOf(table_name_str)

      # Get table descriptor
      htd = org.apache.hadoop.hbase.HTableDescriptor.new(@admin.getTableDescriptor(table_name))
      hasTableUpdate = false

      # Process all args
      args.each do |arg|
        # Normalize args to support column name only alter specs
        arg = { NAME => arg } if arg.is_a?(String)

        # Normalize args to support shortcut delete syntax
        arg = { METHOD => 'delete', NAME => arg['delete'] } if arg['delete']

        # There are 3 possible options.
        # 1) Column family spec. Distinguished by having a NAME and no METHOD.
        method = arg.delete(METHOD)
        if method.nil? && arg.key?(NAME)
          descriptor = hcd(arg, htd)
          column_name = descriptor.getNameAsString

          # If column already exist, then try to alter it. Create otherwise.
          if htd.hasFamily(column_name.to_java_bytes)
            htd.modifyFamily(descriptor)
          else
            htd.addFamily(descriptor)
          end
          hasTableUpdate = true
          next
        end

        # 2) Method other than table_att, with some args.
        name = arg.delete(NAME)
        if !method.nil? && method != 'table_att'
          # Delete column family
          if method == 'delete'
            raise(ArgumentError, 'NAME parameter missing for delete method') unless name
            htd.removeFamily(name.to_java_bytes)
            hasTableUpdate = true
          # Unset table attributes
          elsif method == 'table_att_unset'
            raise(ArgumentError, 'NAME parameter missing for table_att_unset method') unless name
            if name.is_a?(Array)
              name.each do |key|
                if htd.getValue(key).nil?
                  raise ArgumentError, "Could not find attribute: #{key}"
                end
                htd.remove(key)
              end
            else
              if htd.getValue(name).nil?
                raise ArgumentError, "Could not find attribute: #{name}"
              end
              htd.remove(name)
            end
            hasTableUpdate = true
          # Unset table configuration
          elsif method == 'table_conf_unset'
            raise(ArgumentError, 'NAME parameter missing for table_conf_unset method') unless name
            if name.is_a?(Array)
              name.each do |key|
                if htd.getConfigurationValue(key).nil?
                  raise ArgumentError, "Could not find configuration: #{key}"
                end
                htd.removeConfiguration(key)
              end
            else
              if htd.getConfigurationValue(name).nil?
                raise ArgumentError, "Could not find configuration: #{name}"
              end
              htd.removeConfiguration(name)
            end
            hasTableUpdate = true
          # Unknown method
          else
            raise ArgumentError, "Unknown method: #{method}"
          end

          arg.each_key do |unknown_key|
            puts(format('Unknown argument ignored: %s', unknown_key))
          end

          next
        end

        # 3) Some args for the table, optionally with METHOD => table_att (deprecated)
        update_htd_from_arg(htd, arg)

        # set a coprocessor attribute
        valid_coproc_keys = []
        next unless arg.is_a?(Hash)
        arg.each do |key, value|
          k = String.new(key) # prepare to strip
          k.strip!

          next unless k =~ /coprocessor/i
          v = String.new(value)
          v.strip!
          htd.addCoprocessorWithSpec(v)
          valid_coproc_keys << key
        end

        valid_coproc_keys.each do |key|
          arg.delete(key)
        end

        hasTableUpdate = true

        arg.each_key do |unknown_key|
          puts(format('Unknown argument ignored: %s', unknown_key))
        end

        next
      end

      # Bulk apply all table modifications.
      if hasTableUpdate
        @admin.modifyTable(table_name, htd)

        if wait == true
          puts 'Updating all regions with the new schema...'
          alter_status(table_name_str)
        end
      end
    end

    def status(format, type)
      status = @admin.getClusterStatus
      if format == 'detailed'
        puts(format('version %s', status.getHBaseVersion))
        # Put regions in transition first because usually empty
        puts(format('%d regionsInTransition', status.getRegionStatesInTransition.size))
        for v in status.getRegionStatesInTransition
          puts(format('    %s', v))
        end
        master = status.getMaster
        puts(format('active master:  %s:%d %d', master.getHostname, master.getPort, master.getStartcode))
        puts(format('%d backup masters', status.getBackupMastersSize))
        for server in status.getBackupMasters
          puts(format('    %s:%d %d', server.getHostname, server.getPort, server.getStartcode))
        end

        master_coprocs = java.util.Arrays.toString(@admin.getMasterCoprocessors)
        unless master_coprocs.nil?
          puts(format('master coprocessors: %s', master_coprocs))
        end
        puts(format('%d live servers', status.getServersSize))
        for server in status.getServers
          puts(format('    %s:%d %d', server.getHostname, server.getPort, server.getStartcode))
          puts(format('        %s', status.getLoad(server).toString))
          for name, region in status.getLoad(server).getRegionsLoad
            puts(format('        %s', region.getNameAsString.dump))
            puts(format('            %s', region.toString))
          end
        end
        puts(format('%d dead servers', status.getDeadServersSize))
        for server in status.getDeadServerNames
          puts(format('    %s', server))
        end
      elsif format == 'replication'
        puts(format('version %s', status.getHBaseVersion))
        puts(format('%d live servers', status.getServersSize))
        for server in status.getServers
          sl = status.getLoad(server)
          rSinkString   = '       SINK  :'
          rSourceString = '       SOURCE:'
          rLoadSink = sl.getReplicationLoadSink
          next if rLoadSink.nil?
          rSinkString << ' AgeOfLastAppliedOp=' + rLoadSink.getAgeOfLastAppliedOp.to_s
          rSinkString << ', TimeStampsOfLastAppliedOp=' +
                         java.util.Date.new(rLoadSink.getTimeStampsOfLastAppliedOp).toString
          rLoadSourceList = sl.getReplicationLoadSourceList
          index = 0
          while index < rLoadSourceList.size
            rLoadSource = rLoadSourceList.get(index)
            rSourceString << ' PeerID=' + rLoadSource.getPeerID
            rSourceString << ', AgeOfLastShippedOp=' + rLoadSource.getAgeOfLastShippedOp.to_s
            rSourceString << ', SizeOfLogQueue=' + rLoadSource.getSizeOfLogQueue.to_s
            rSourceString << ', TimeStampsOfLastShippedOp=' +
                             java.util.Date.new(rLoadSource.getTimeStampOfLastShippedOp).toString
            rSourceString << ', Replication Lag=' + rLoadSource.getReplicationLag.to_s
            index += 1
          end
          puts(format('    %s:', server.getHostname))
          if type.casecmp('SOURCE') == 0
            puts(format('%s', rSourceString))
          elsif type.casecmp('SINK') == 0
            puts(format('%s', rSinkString))
          else
            puts(format('%s', rSourceString))
            puts(format('%s', rSinkString))
          end
        end
      elsif format == 'simple'
        load = 0
        regions = 0
        master = status.getMaster
        puts(format('active master:  %s:%d %d', master.getHostname, master.getPort, master.getStartcode))
        puts(format('%d backup masters', status.getBackupMastersSize))
        for server in status.getBackupMasters
          puts(format('    %s:%d %d', server.getHostname, server.getPort, server.getStartcode))
        end
        puts(format('%d live servers', status.getServersSize))
        for server in status.getServers
          puts(format('    %s:%d %d', server.getHostname, server.getPort, server.getStartcode))
          puts(format('        %s', status.getLoad(server).toString))
          load += status.getLoad(server).getNumberOfRequests
          regions += status.getLoad(server).getNumberOfRegions
        end
        puts(format('%d dead servers', status.getDeadServers))
        for server in status.getDeadServerNames
          puts(format('    %s', server))
        end
        puts(format('Aggregate load: %d, regions: %d', load, regions))
      else
        puts "1 active master, #{status.getBackupMastersSize} backup masters, #{status.getServersSize} servers, #{status.getDeadServers} dead, #{format('%.4f', status.getAverageLoad)} average load"
      end
    end

    #----------------------------------------------------------------------------------------------
    #
    # Helper methods
    #

    # Does table exist?
    def exists?(table_name)
      @admin.tableExists(TableName.valueOf(table_name))
    end

    #----------------------------------------------------------------------------------------------
    # Is table enabled
    def enabled?(table_name)
      @admin.isTableEnabled(TableName.valueOf(table_name))
    end

    #----------------------------------------------------------------------------------------------
    # Return a new HColumnDescriptor made of passed args
    def hcd(arg, htd)
      # String arg, single parameter constructor
      return org.apache.hadoop.hbase.HColumnDescriptor.new(arg) if arg.is_a?(String)

      raise(ArgumentError, "Column family #{arg} must have a name") unless name = arg.delete(NAME)

      family = htd.getFamily(name.to_java_bytes)
      # create it if it's a new family
      family ||= org.apache.hadoop.hbase.HColumnDescriptor.new(name.to_java_bytes)

      family.setBlockCacheEnabled(JBoolean.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::BLOCKCACHE))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::BLOCKCACHE)
      family.setScope(JInteger.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::REPLICATION_SCOPE))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::REPLICATION_SCOPE)
      family.setCacheDataOnWrite(JBoolean.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::CACHE_DATA_ON_WRITE))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::CACHE_DATA_ON_WRITE)
      family.setCacheIndexesOnWrite(JBoolean.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::CACHE_INDEX_ON_WRITE))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::CACHE_INDEX_ON_WRITE)
      family.setCacheBloomsOnWrite(JBoolean.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::CACHE_BLOOMS_ON_WRITE))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::CACHE_BLOOMS_ON_WRITE)
      family.setEvictBlocksOnClose(JBoolean.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::EVICT_BLOCKS_ON_CLOSE))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::EVICT_BLOCKS_ON_CLOSE)
      family.setInMemory(JBoolean.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::IN_MEMORY))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::IN_MEMORY)
      if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::IN_MEMORY_COMPACTION)
        family.setInMemoryCompaction(
          org.apache.hadoop.hbase.MemoryCompactionPolicy.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::IN_MEMORY_COMPACTION))
        )
      end
      family.setTimeToLive(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::TTL)) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::TTL)
      family.setDataBlockEncoding(org.apache.hadoop.hbase.io.encoding.DataBlockEncoding.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::DATA_BLOCK_ENCODING))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::DATA_BLOCK_ENCODING)
      family.setBlocksize(JInteger.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::BLOCKSIZE))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::BLOCKSIZE)
      family.setMaxVersions(JInteger.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::VERSIONS))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::VERSIONS)
      family.setMinVersions(JInteger.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::MIN_VERSIONS))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::MIN_VERSIONS)
      family.setKeepDeletedCells(org.apache.hadoop.hbase.KeepDeletedCells.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::KEEP_DELETED_CELLS).to_s.upcase)) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::KEEP_DELETED_CELLS)
      family.setCompressTags(JBoolean.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::COMPRESS_TAGS))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::COMPRESS_TAGS)
      family.setPrefetchBlocksOnOpen(JBoolean.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::PREFETCH_BLOCKS_ON_OPEN))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::PREFETCH_BLOCKS_ON_OPEN)
      family.setMobEnabled(JBoolean.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::IS_MOB))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::IS_MOB)
      family.setMobThreshold(JLong.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::MOB_THRESHOLD))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::MOB_THRESHOLD)
      family.setNewVersionBehavior(JBoolean.valueOf(arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::NEW_VERSION_BEHAVIOR))) if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::NEW_VERSION_BEHAVIOR)
      if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::BLOOMFILTER)
        bloomtype = arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::BLOOMFILTER).upcase.to_sym
        if org.apache.hadoop.hbase.regionserver.BloomType.constants.include?(bloomtype)
          family.setBloomFilterType(org.apache.hadoop.hbase.regionserver.BloomType.valueOf(bloomtype))
        else
          raise(ArgumentError, "BloomFilter type #{bloomtype} is not supported. Use one of " + org.apache.hadoop.hbase.regionserver.StoreFile::BloomType.constants.join(' '))
        end
      end
      if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::COMPRESSION)
        compression = arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::COMPRESSION).upcase.to_sym
        if org.apache.hadoop.hbase.io.compress.Compression::Algorithm.constants.include?(compression)
          family.setCompressionType(org.apache.hadoop.hbase.io.compress.Compression::Algorithm.valueOf(compression))
        else
          raise(ArgumentError, "Compression #{compression} is not supported. Use one of " + org.apache.hadoop.hbase.io.compress.Compression::Algorithm.constants.join(' '))
        end
      end
      if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::ENCRYPTION)
        algorithm = arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::ENCRYPTION).upcase
        family.setEncryptionType(algorithm)
        if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::ENCRYPTION_KEY)
          key = org.apache.hadoop.hbase.io.crypto.Encryption.pbkdf128(
            arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::ENCRYPTION_KEY)
          )
          family.setEncryptionKey(org.apache.hadoop.hbase.security.EncryptionUtil.wrapKey(@conf, key,
                                                                                          algorithm))
        end
      end
      if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::COMPRESSION_COMPACT)
        compression = arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::COMPRESSION_COMPACT).upcase.to_sym
        if org.apache.hadoop.hbase.io.compress.Compression::Algorithm.constants.include?(compression)
          family.setCompactionCompressionType(org.apache.hadoop.hbase.io.compress.Compression::Algorithm.valueOf(compression))
        else
          raise(ArgumentError, "Compression #{compression} is not supported. Use one of " + org.apache.hadoop.hbase.io.compress.Compression::Algorithm.constants.join(' '))
        end
      end
      if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::STORAGE_POLICY)
        storage_policy = arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::STORAGE_POLICY).upcase
        family.setStoragePolicy(storage_policy)
      end
      if arg.include?(org.apache.hadoop.hbase.HColumnDescriptor::MOB_COMPACT_PARTITION_POLICY)
        mob_partition_policy = arg.delete(org.apache.hadoop.hbase.HColumnDescriptor::MOB_COMPACT_PARTITION_POLICY).upcase.to_sym
        if org.apache.hadoop.hbase.client.MobCompactPartitionPolicy.constants.include?(mob_partition_policy)
          family.setMobCompactPartitionPolicy(org.apache.hadoop.hbase.client.MobCompactPartitionPolicy.valueOf(mob_partition_policy))
        else
          raise(ArgumentError, "MOB_COMPACT_PARTITION_POLICY #{mob_partition_policy} is not supported. Use one of " + org.apache.hadoop.hbase.client.MobCompactPartitionPolicy.constants.join(' '))
        end
      end

      set_user_metadata(family, arg.delete(METADATA)) if arg[METADATA]
      set_descriptor_config(family, arg.delete(CONFIGURATION)) if arg[CONFIGURATION]
      if arg.include?(org.apache.hadoop.hbase
        .HColumnDescriptor::DFS_REPLICATION)
        family.setDFSReplication(JInteger.valueOf(arg.delete(org.apache.hadoop.hbase
          .HColumnDescriptor::DFS_REPLICATION)))
      end

      arg.each_key do |unknown_key|
        puts(format('Unknown argument ignored for column family %s: %s', name, unknown_key))
      end

      family
    end

    #----------------------------------------------------------------------------------------------
    # Enables/disables a region by name
    def online(region_name, on_off)
      # Open meta table
      meta = @connection.getTable(org.apache.hadoop.hbase.TableName::META_TABLE_NAME)

      # Read region info
      # FIXME: fail gracefully if can't find the region
      region_bytes = region_name.to_java_bytes
      g = org.apache.hadoop.hbase.client.Get.new(region_bytes)
      g.addColumn(org.apache.hadoop.hbase.HConstants::CATALOG_FAMILY, org.apache.hadoop.hbase.HConstants::REGIONINFO_QUALIFIER)
      hri_bytes = meta.get(g).value

      # Change region status
      hri = org.apache.hadoop.hbase.util.Writables.getWritable(hri_bytes, org.apache.hadoop.hbase.HRegionInfo.new)
      hri.setOffline(on_off)

      # Write it back
      put = org.apache.hadoop.hbase.client.Put.new(region_bytes)
      put.addColumn(org.apache.hadoop.hbase.HConstants::CATALOG_FAMILY,
                    org.apache.hadoop.hbase.HConstants::REGIONINFO_QUALIFIER,
                    org.apache.hadoop.hbase.util.Writables.getBytes(hri))
      meta.put(put)
    end

    # Apply user metadata to table/column descriptor
    def set_user_metadata(descriptor, metadata)
      raise(ArgumentError, "#{METADATA} must be a Hash type") unless metadata.is_a?(Hash)
      for k, v in metadata
        v = v.to_s unless v.nil?
        descriptor.setValue(k, v)
      end
    end

    #----------------------------------------------------------------------------------------------
    # Take a snapshot of specified table
    def snapshot(table, snapshot_name, *args)
      # Table name should be a string
      raise(ArgumentError, 'Table name must be of type String') unless table.is_a?(String)

      # Snapshot name should be a string
      raise(ArgumentError, 'Snapshot name must be of type String') unless
          snapshot_name.is_a?(String)

      table_name = TableName.valueOf(table)
      if args.empty?
        @admin.snapshot(snapshot_name, table_name)
      else
        args.each do |arg|
          if arg[SKIP_FLUSH] == true
            @admin.snapshot(snapshot_name, table_name,
                            org.apache.hadoop.hbase.client.SnapshotType::SKIPFLUSH)
          else
            @admin.snapshot(snapshot_name, table_name)
          end
        end
      end
    end

    #----------------------------------------------------------------------------------------------
    # Restore specified snapshot
    def restore_snapshot(snapshot_name, restore_acl = false)
      conf = @connection.getConfiguration
      take_fail_safe_snapshot = conf.getBoolean('hbase.snapshot.restore.take.failsafe.snapshot', false)
      @admin.restoreSnapshot(snapshot_name, take_fail_safe_snapshot, restore_acl)
    end

    #----------------------------------------------------------------------------------------------
    # Create a new table by cloning the snapshot content
    def clone_snapshot(snapshot_name, table, restore_acl = false)
      @admin.cloneSnapshot(snapshot_name, TableName.valueOf(table), restore_acl)
    end

    #----------------------------------------------------------------------------------------------
    # Delete specified snapshot
    def delete_snapshot(snapshot_name)
      @admin.deleteSnapshot(snapshot_name)
    end

    #----------------------------------------------------------------------------------------------
    # Deletes the snapshots matching the given regex
    def delete_all_snapshot(regex)
      @admin.deleteSnapshots(Pattern.compile(regex)).to_a
    end

    #----------------------------------------------------------------------------------------------
    # Deletes the table snapshots matching the given regex
    def delete_table_snapshots(tableNameRegex, snapshotNameRegex = '.*')
      @admin.deleteTableSnapshots(Pattern.compile(tableNameRegex),
        Pattern.compile(snapshotNameRegex)).to_a
    end

    #----------------------------------------------------------------------------------------------
    # Returns a list of snapshots
    def list_snapshot(regex = '.*')
      @admin.listSnapshots(Pattern.compile(regex)).to_a
    end

    #----------------------------------------------------------------------------------------------
    # Returns a list of table snapshots
    def list_table_snapshots(tableNameRegex, snapshotNameRegex = '.*')
      @admin.listTableSnapshots(Pattern.compile(tableNameRegex),
        Pattern.compile(snapshotNameRegex)).to_a
    end

    #----------------------------------------------------------------------------------------------
    # Returns a list of regionservers
    def getRegionServers
      @admin.getClusterStatus.getServers.map { |serverName| serverName }
    end

    #----------------------------------------------------------------------------------------------
    # Returns a list of servernames
    def getServerNames(servers)
      regionservers = getRegionServers
      servernames = []

      if servers.empty?
        # if no servers were specified as arguments, get a list of all servers
        servernames = regionservers
      else
        # Strings replace with ServerName objects in servers array
        i = 0
        while i < servers.length
          server = servers[i]

          if ServerName.isFullServerName(server)
            servernames.push(ServerName.valueOf(server))
          else
            name_list = server.split(',')
            j = 0
            while j < regionservers.length
              sn = regionservers[j]
              if name_list[0] == sn.hostname && (name_list[1].nil? ? true : (name_list[1] == sn.port.to_s))
                servernames.push(sn)
              end
              j += 1
            end
          end
          i += 1
        end
      end

      servernames
    end

    # Apply config specific to a table/column to its descriptor
    def set_descriptor_config(descriptor, config)
      raise(ArgumentError, "#{CONFIGURATION} must be a Hash type") unless config.is_a?(Hash)
      for k, v in config
        v = v.to_s unless v.nil?
        descriptor.setConfiguration(k, v)
      end
    end

    #----------------------------------------------------------------------------------------------
    # Updates the configuration of one regionserver.
    def update_config(serverName)
      @admin.updateConfiguration(ServerName.valueOf(serverName))
    end

    #----------------------------------------------------------------------------------------------
    # Updates the configuration of all the regionservers.
    def update_all_config
      @admin.updateConfiguration
    end

    #----------------------------------------------------------------------------------------------
    # Returns namespace's structure description
    def describe_namespace(namespace_name)
      namespace = @admin.getNamespaceDescriptor(namespace_name)

      return namespace.to_s unless namespace.nil?

      raise(ArgumentError, "Failed to find namespace named #{namespace_name}")
    end

    #----------------------------------------------------------------------------------------------
    # Returns a list of namespaces in hbase
    def list_namespace(regex = '.*')
      pattern = java.util.regex.Pattern.compile(regex)
      list = @admin.listNamespaceDescriptors.map(&:getName)
      list.select { |s| pattern.match(s) }
    end

    #----------------------------------------------------------------------------------------------
    # Returns a list of tables in namespace
    def list_namespace_tables(namespace_name)
      unless namespace_name.nil?
        return @admin.listTableNamesByNamespace(namespace_name).map(&:getQualifierAsString)
      end

      raise(ArgumentError, "Failed to find namespace named #{namespace_name}")
    end

    #----------------------------------------------------------------------------------------------
    # Creates a namespace
    def create_namespace(namespace_name, *args)
      # Fail if table name is not a string
      raise(ArgumentError, 'Namespace name must be of type String') unless namespace_name.is_a?(String)

      # Flatten params array
      args = args.flatten.compact

      # Start defining the table
      nsb = org.apache.hadoop.hbase.NamespaceDescriptor.create(namespace_name)
      args.each do |arg|
        unless arg.is_a?(Hash)
          raise(ArgumentError, "#{arg.class} of #{arg.inspect} is not of Hash or String type")
        end
        for k, v in arg
          v = v.to_s unless v.nil?
          nsb.addConfiguration(k, v)
        end
      end
      @admin.createNamespace(nsb.build)
    end

    #----------------------------------------------------------------------------------------------
    # modify a namespace
    def alter_namespace(namespace_name, *args)
      # Fail if table name is not a string
      raise(ArgumentError, 'Namespace name must be of type String') unless namespace_name.is_a?(String)

      nsd = @admin.getNamespaceDescriptor(namespace_name)

      raise(ArgumentError, 'Namespace does not exist') unless nsd
      nsb = org.apache.hadoop.hbase.NamespaceDescriptor.create(nsd)

      # Flatten params array
      args = args.flatten.compact

      # Start defining the table
      args.each do |arg|
        unless arg.is_a?(Hash)
          raise(ArgumentError, "#{arg.class} of #{arg.inspect} is not of Hash type")
        end
        method = arg[METHOD]
        if method == 'unset'
          nsb.removeConfiguration(arg[NAME])
        elsif method == 'set'
          arg.delete(METHOD)
          for k, v in arg
            v = v.to_s unless v.nil?

            nsb.addConfiguration(k, v)
          end
        else
          raise(ArgumentError, "Unknown method #{method}")
        end
      end
      @admin.modifyNamespace(nsb.build)
    end

    #----------------------------------------------------------------------------------------------
    # Drops a table
    def drop_namespace(namespace_name)
      @admin.deleteNamespace(namespace_name)
    end

    #----------------------------------------------------------------------------------------------
    # Get security capabilities
    def get_security_capabilities
      @admin.getSecurityCapabilities
    end

    # Abort a procedure
    def abort_procedure?(proc_id, may_interrupt_if_running = nil)
      if may_interrupt_if_running.nil?
        @admin.abortProcedure(proc_id, true)
      else
        @admin.abortProcedure(proc_id, may_interrupt_if_running)
      end
    end

    # List all procedures
    def list_procedures
      @admin.getProcedures
    end

    # List all locks
    def list_locks
      @admin.getLocks
    end

    # Parse arguments and update HTableDescriptor accordingly
    def update_htd_from_arg(htd, arg)
      htd.setOwnerString(arg.delete(org.apache.hadoop.hbase.HTableDescriptor::OWNER)) if arg.include?(org.apache.hadoop.hbase.HTableDescriptor::OWNER)
      htd.setMaxFileSize(JLong.valueOf(arg.delete(org.apache.hadoop.hbase.HTableDescriptor::MAX_FILESIZE))) if arg.include?(org.apache.hadoop.hbase.HTableDescriptor::MAX_FILESIZE)
      htd.setReadOnly(JBoolean.valueOf(arg.delete(org.apache.hadoop.hbase.HTableDescriptor::READONLY))) if arg.include?(org.apache.hadoop.hbase.HTableDescriptor::READONLY)
      htd.setCompactionEnabled(JBoolean.valueOf(arg.delete(org.apache.hadoop.hbase.HTableDescriptor::COMPACTION_ENABLED))) if arg.include?(org.apache.hadoop.hbase.HTableDescriptor::COMPACTION_ENABLED)
      htd.setNormalizationEnabled(JBoolean.valueOf(arg.delete(org.apache.hadoop.hbase.HTableDescriptor::NORMALIZATION_ENABLED))) if arg.include?(org.apache.hadoop.hbase.HTableDescriptor::NORMALIZATION_ENABLED)
      htd.setMemStoreFlushSize(JLong.valueOf(arg.delete(org.apache.hadoop.hbase.HTableDescriptor::MEMSTORE_FLUSHSIZE))) if arg.include?(org.apache.hadoop.hbase.HTableDescriptor::MEMSTORE_FLUSHSIZE)
      htd.setDurability(org.apache.hadoop.hbase.client.Durability.valueOf(arg.delete(org.apache.hadoop.hbase.HTableDescriptor::DURABILITY))) if arg.include?(org.apache.hadoop.hbase.HTableDescriptor::DURABILITY)
      htd.setPriority(JInteger.valueOf(arg.delete(org.apache.hadoop.hbase.HTableDescriptor::PRIORITY))) if arg.include?(org.apache.hadoop.hbase.HTableDescriptor::PRIORITY)
      htd.setFlushPolicyClassName(arg.delete(org.apache.hadoop.hbase.HTableDescriptor::FLUSH_POLICY)) if arg.include?(org.apache.hadoop.hbase.HTableDescriptor::FLUSH_POLICY)
      htd.setRegionMemstoreReplication(JBoolean.valueOf(arg.delete(org.apache.hadoop.hbase.HTableDescriptor::REGION_MEMSTORE_REPLICATION))) if arg.include?(org.apache.hadoop.hbase.HTableDescriptor::REGION_MEMSTORE_REPLICATION)
      htd.setRegionSplitPolicyClassName(arg.delete(org.apache.hadoop.hbase.HTableDescriptor::SPLIT_POLICY)) if arg.include?(org.apache.hadoop.hbase.HTableDescriptor::SPLIT_POLICY)
      htd.setRegionReplication(JInteger.valueOf(arg.delete(org.apache.hadoop.hbase.HTableDescriptor::REGION_REPLICATION))) if arg.include?(org.apache.hadoop.hbase.HTableDescriptor::REGION_REPLICATION)
      set_user_metadata(htd, arg.delete(METADATA)) if arg[METADATA]
      set_descriptor_config(htd, arg.delete(CONFIGURATION)) if arg[CONFIGURATION]
    end

    #----------------------------------------------------------------------------------------------
    # clear compaction queues
    def clear_compaction_queues(server_name, queue_name = nil)
      names = %w[long short]
      queues = java.util.HashSet.new
      if queue_name.nil?
        queues.add('long')
        queues.add('short')
      elsif queue_name.is_a?(String)
        queues.add(queue_name)
        unless names.include?(queue_name)
          raise(ArgumentError, "Unknown queue name #{queue_name}")
        end
      elsif queue_name.is_a?(Array)
        queue_name.each do |s|
          queues.add(s)
          unless names.include?(s)
            raise(ArgumentError, "Unknown queue name #{s}")
          end
        end
      else
        raise(ArgumentError, "Unknown queue name #{queue_name}")
      end
      @admin.clearCompactionQueues(ServerName.valueOf(server_name), queues)
    end

    #----------------------------------------------------------------------------------------------
    # clear dead region servers
    def list_deadservers
      @admin.listDeadServers.to_a
    end

    #----------------------------------------------------------------------------------------------
    # clear dead region servers
    def clear_deadservers(dead_servers)
      # Flatten params array
      dead_servers = dead_servers.flatten.compact
      if dead_servers.empty?
        servers = list_deadservers
      else
        servers = java.util.ArrayList.new
        dead_servers.each do |s|
          servers.add(ServerName.valueOf(s))
        end
      end
      @admin.clearDeadServers(servers).to_a
    end
  end
end
