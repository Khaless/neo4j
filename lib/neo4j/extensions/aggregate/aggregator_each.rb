module Neo4j::Aggregate
  class AggregatorEach
    def initialize(root_node, nodes_or_class)

      if (nodes_or_class.kind_of?(Class) and nodes_or_class.ancestors.include?(Neo4j::NodeMixin))
        Neo4j.event_handler.add(self)
        @filter = nodes_or_class
      end
      @root_node = root_node
      @nodes = nodes_or_class
    end

    # Unregisters this aggregate so that it will not be notified any longer
    # on Neo4j node events. Used when we create an aggregate that is registered
    # with the Neo4j even listener by including a filter in the aggregate method
    #
    # ==== Example
    # agg_reg = my_aggregate.aggregate_each(MyNode).group_by(:something)
    # # add some MyNodes that my_aggregate will aggregate into groups
    # MyNode.new # etc...
    # # we now do not want to add more nodes using the aggregate above - unregister it
    # agg_reg.unregister
    # # no more nodes will be appended /deleted /modified in the my_aggregate.
    #
    def unregister
      Neo4j.event_handler.remove(self)
    end

    # http://www.2paths.com/2009/06/22/visualizing-semantic-data-using-javascript-and-the-html-canvas-element/
    # called from neo4j event handler
    # :api: private
    def on_property_changed(node, prop_key, old_value, new_value) # :nodoc:
      return if node.class != @filter
      return unless @group_by.include?(prop_key.to_sym)

      # for each aggregate the node belongs to delete it
      # we have to first create it and then deleted, otherwise cascade delete will kick in
      group = node.aggregate_groups(@root_node.aggregate_id)
      
      # recreate the aggregate group
      execute([node])

      # delete this aggregate group if it exists
      group.delete if group
    end

    # Specifies which properties we should group on.
    # All those properties can be combined to create a new group.
    #
    # :api: public
    def group_by(*keys)
      @group_by = keys
      self
    end

    def with(prop_key, &proc)
      @with_proc = proc
      @prop_key = prop_key
    end

    def execute(nodes = @nodes)
      return unless nodes
      nodes.each do |node|
        group_node = GroupEachNode.new
        group_node.group_by = @group_by.join(',')
        group_node.aggregate = node
        rel = group_node.relationships.outgoing(:aggregate)[node]
        rel[:aggregate_group] = @root_node.aggregate_id.to_s
        @root_node.groups << group_node
        if @with_proc
          val = group_node.inject(0) {|sum, val| next sum if val.nil?; @with_proc.call(sum, val, 0)}
          group_node[@prop_key.to_s] = val
        end
      end
      @nodes = nil # prevent it to run twice
    end
  end
end